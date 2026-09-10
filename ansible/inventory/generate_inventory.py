#!/usr/bin/env python3
"""
Generira Ansible inventory (YAML) iz Terraform outputa azure-i4-terraform modula.
Pokreni iz ansible/ foldera nakon uspješnog `terraform apply`:

    python3 inventory/generate_inventory.py

Cita `terraform output -json` iz ../azure-i4-terraform i pise inventory/hosts.yml.
Moodle i Lead VM-ovi nemaju javni IP pa se za njih postavlja ProxyJump preko
jump hosta (jedini javno dostupan resurs).
"""
import json
import subprocess
import sys
import os

TF_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "azure-i4-terraform")
OUT_FILE = os.path.join(os.path.dirname(__file__), "hosts.yml")


def get_terraform_outputs():
    result = subprocess.run(
        ["terraform", "output", "-json"],
        cwd=TF_DIR,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        print("Greska pri citanju terraform outputa:", result.stderr, file=sys.stderr)
        print("Provjeri da si pokrenuo 'terraform apply' u azure-i4-terraform/", file=sys.stderr)
        sys.exit(1)
    raw = json.loads(result.stdout)
    return {k: v["value"] for k, v in raw.items()}


def build_inventory(outputs, admin_user, ssh_key_path):
    jump_ip = outputs["jump_host_public_ip"]
    lead_ip = outputs["lead_vm_private_ip"]
    moodle_ips = outputs["moodle_vm_private_ips"]
    storage_names = outputs["storage_account_names"]
    kv_names = outputs["key_vault_names"]
    lb_ips = outputs["moodle_lb_frontend_ips"]

    # ProxyCommand (ne ProxyJump) s EKSPLICITNIM -i kljucem: OpenSSH kod
    # "-o ProxyJump=host" NE prosljedjuje "-i" iz glavne komande na skok prema
    # jump hostu - taj hop koristi vlastito rjesavanje kljuca (~/.ssh/id_rsa +
    # agent). Ako kljuc nije u agentu ni na default putanji, jump odbija auth i
    # veza se zatvori s "Connection closed by UNKNOWN port 65535" (live
    # otkriveno 10.9.2026 nakon clean rebuilda - ranije je "radilo" samo jer je
    # kljuc bio u ssh-agentu). ProxyCommand s "-i" rjesava to trajno.
    # UserKnownHostsFile=/dev/null na jump hopu izbjegava i problem zastarjelih
    # host kljuceva za javni IP jump hosta nakon rebuilda.
    key = os.path.expanduser(ssh_key_path)
    proxy = (
        f'-o ProxyCommand="ssh -i {key} -W %h:%p '
        f'-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null '
        f'{admin_user}@{jump_ip}"'
    )

    dev_ids = sorted({k.rsplit("-", 1)[0] for k in moodle_ips.keys()})

    inventory = {
        "all": {
            "vars": {
                "ansible_user": admin_user,
                "ansible_ssh_private_key_file": ssh_key_path,
                "ansible_ssh_extra_args": "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null",
            },
            "children": {
                "jump": {
                    "hosts": {
                        "jump-shared-01": {"ansible_host": jump_ip}
                    }
                },
                "lead": {
                    "hosts": {
                        "lead-shared-01": {
                            "ansible_host": lead_ip,
                            "ansible_ssh_common_args": proxy,
                        }
                    }
                },
                "moodle": {"children": {}},
            },
        }
    }

    for dev_id in dev_ids:
        group_name = dev_id
        hosts = {}
        # HA par dijeli JEDNU MariaDB bazu (vidi azure-i4-terraform NSG
        # "AllowMySQLWithinSpoke" i moodle rolu): prva instanca po abecedi
        # (npr. dev01-01) je DB primary i hosta MariaDB, ostale se spajaju na
        # nju preko privatnog IP-a. Bez toga svaka instanca ima svoju bazu/
        # sesije pa login puca iza LB-a (token generira jedna, provjerava druga).
        dev_host_keys = sorted(k for k in moodle_ips if k.startswith(dev_id + "-"))
        primary_key = dev_host_keys[0]
        primary_ip = moodle_ips[primary_key]
        for key in dev_host_keys:
            hosts[f"moodle-{key}"] = {
                "ansible_host": moodle_ips[key],
                "ansible_ssh_common_args": proxy,
                "moodle_db_primary": key == primary_key,
            }
        inventory["all"]["children"]["moodle"]["children"][group_name] = {
            "hosts": hosts,
            "vars": {
                "dev_id": dev_id,
                "storage_account_name": storage_names[dev_id],
                "key_vault_name": kv_names[dev_id],
                "moodle_wwwroot": f"http://{lb_ips[dev_id]}",
                "moodle_db_host": primary_ip,
            },
        }

    return inventory


def to_yaml(data, indent=0):
    # Rucni, ovisnost-slobodan YAML writer (bez potrebe za PyYAML paketom).
    lines = []
    pad = "  " * indent
    if isinstance(data, dict):
        for k, v in data.items():
            if isinstance(v, (dict, list)) and v:
                lines.append(f"{pad}{k}:")
                lines.extend(to_yaml(v, indent + 1))
            else:
                lines.append(f"{pad}{k}: {yaml_scalar(v)}")
    elif isinstance(data, list):
        for item in data:
            lines.append(f"{pad}- {yaml_scalar(item)}")
    return lines


def yaml_scalar(v):
    if isinstance(v, str):
        if any(c in v for c in [":", "#", '"']) or v == "":
            return json.dumps(v)
        return v
    if isinstance(v, bool):
        return "true" if v else "false"
    return str(v)


if __name__ == "__main__":
    admin_user = os.environ.get("TF_VAR_admin_username", "azureuser")
    ssh_key_path = os.environ.get("ANSIBLE_SSH_KEY", "~/.ssh/techsprint_rsa")

    outputs = get_terraform_outputs()
    inventory = build_inventory(outputs, admin_user, ssh_key_path)

    with open(OUT_FILE, "w", encoding="utf-8") as f:
        f.write("\n".join(to_yaml(inventory)) + "\n")

    print(f"Inventory zapisan u {OUT_FILE}")
