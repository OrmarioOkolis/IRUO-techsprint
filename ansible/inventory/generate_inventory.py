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

    proxy = f"-o ProxyJump={admin_user}@{jump_ip} -o StrictHostKeyChecking=no"

    dev_ids = sorted({k.rsplit("-", 1)[0] for k in moodle_ips.keys()})

    inventory = {
        "all": {
            "vars": {
                "ansible_user": admin_user,
                "ansible_ssh_private_key_file": ssh_key_path,
                "ansible_ssh_extra_args": "-o StrictHostKeyChecking=no",
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
        for key, ip in moodle_ips.items():
            if key.startswith(dev_id + "-"):
                hosts[f"moodle-{key}"] = {
                    "ansible_host": ip,
                    "ansible_ssh_common_args": proxy,
                }
        inventory["all"]["children"]["moodle"]["children"][group_name] = {
            "hosts": hosts,
            "vars": {
                "dev_id": dev_id,
                "storage_account_name": storage_names[dev_id],
                "key_vault_name": kv_names[dev_id],
                "moodle_wwwroot": f"http://{lb_ips[dev_id]}",
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
    ssh_key_path = os.environ.get("ANSIBLE_SSH_KEY", "~/.ssh/techsprint")

    outputs = get_terraform_outputs()
    inventory = build_inventory(outputs, admin_user, ssh_key_path)

    with open(OUT_FILE, "w", encoding="utf-8") as f:
        f.write("\n".join(to_yaml(inventory)) + "\n")

    print(f"Inventory zapisan u {OUT_FILE}")
