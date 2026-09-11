#!/usr/bin/env python3
"""
Generira Ansible inventory (YAML) iz Terraform outputa OpenStack modula
(openstack-i2-terraform + openstack-compute-terraform). MORA se pokretati NA
RHA workstationu (isti razlog kao terraform sam - vidi CLAUDE.md), nakon
uspjesnog `scripts/provision.py --cloud openstack` (ili rucnih apply-a):

    python3 inventory/generate_inventory_openstack.py

Cita `terraform output -json` iz oba direktorija i pise
inventory/hosts-openstack.yml (ODVOJENO od Azureovog inventory/hosts.yml, da
se dva oblaka ne miksaju u istom fajlu). Moodle i Lead VM-ovi nemaju floating
IP pa se za njih postavlja ProxyJump preko jump hosta (jedini javno dostupan
resurs) - isti obrazac kao Azure inventory generator.
"""
import json
import subprocess
import sys
import os

REPO_ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
I3_DIR = os.path.join(REPO_ROOT, "openstack-i3-terraform")
I2_DIR = os.path.join(REPO_ROOT, "openstack-i2-terraform")
COMPUTE_SHARED_DIR = os.path.join(REPO_ROOT, "openstack-compute-terraform")
COMPUTE_DEV_DIR = os.path.join(REPO_ROOT, "openstack-compute-dev-terraform")
OUT_FILE = os.path.join(os.path.dirname(__file__), "hosts-openstack.yml")


def get_terraform_outputs(cwd, hint, extra_args=None):
    cmd = ["terraform", "output", "-json"] + (extra_args or [])
    result = subprocess.run(
        cmd, cwd=cwd,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True,
    )
    if result.returncode != 0:
        print(f"Greska pri citanju terraform outputa iz {cwd}:", result.stderr, file=sys.stderr)
        print(hint, file=sys.stderr)
        sys.exit(1)
    raw = json.loads(result.stdout)
    return {k: v["value"] for k, v in raw.items()}


def get_dev_credentials(i3_out, dev_id):
    """Developerova vlastita Keystone lozinka (least-privilege Swift pristup -
    VM u dev projektu koristi TOG developera identitet, ne admin/lead - isto
    nacelo kao Azure Managed Identity scoped na vlastiti storage account)."""
    return i3_out["developer_usernames"][dev_id], i3_out["developer_passwords"][dev_id]


def get_dev_compute_outputs(dev_id):
    """Cita openstack-compute-dev-terraform output iz ZASEBNOG state fajla po
    developeru (-state=terraform-<dev_id>.tfstate - isti fajl koji
    scripts/provision.py koristi pri apply-u, vidi main_openstack())."""
    return get_terraform_outputs(
        COMPUTE_DEV_DIR,
        f"Provjeri da je terraform apply za {dev_id} uspio u openstack-compute-dev-terraform/",
        extra_args=[f"-state=terraform-{dev_id}.tfstate"],
    )


def build_inventory(i2_out, shared_out, i3_out, admin_user, ssh_key_path, os_auth_url):
    jump_ip = i2_out["jump_floating_ip"]
    lead_ip = shared_out["lead_fixed_ip"][0]
    # "dev01-01" -> "10.11.1.54" - vec raspakiran plain string u
    # openstack-i2-terraform/outputs.tf (`all_fixed_ips[0]`), NE lista - za
    # razliku od lead_fixed_ip/jump_fixed_ip koji vracaju cijelu listu.
    moodle_ips = i2_out["moodle_port_fixed_ips"]

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
        dev_compute_out = get_dev_compute_outputs(dev_id)
        dev_username, dev_password = get_dev_credentials(i3_out, dev_id)

        hosts = {}
        for key, ip in moodle_ips.items():
            if key.startswith(dev_id + "-"):
                # Svaka Moodle instanca gleda SAMA SEBE kao wwwroot (bez pravog
                # LB frontenda - Octavia je iskljucena na ovom sandboxu, vidi
                # CLAUDE.md "Octavia LB - GENUINSKI NE RADI"). Za razliku od
                # Azure I4 HA para (isti wwwroot preko internal LB-a), ovdje su
                # dvije neovisno dostupne instance, ne pravi HA par iza LB-a -
                # posteno stanje, ne pretvaranje da LB postoji.
                hosts[f"moodle-{key}"] = {
                    "ansible_host": ip,
                    "ansible_ssh_common_args": proxy,
                    "moodle_wwwroot": f"http://{ip}",
                }
        inventory["all"]["children"]["moodle"]["children"][dev_id] = {
            "hosts": hosts,
            "vars": {
                "dev_id": dev_id,
                # Swift (objektna pohrana) - developerov VLASTITI Keystone
                # identitet, least-privilege (vidi get_dev_credentials).
                "os_auth_url": os_auth_url,
                "os_project_name": f"techsprint-testing-{dev_id}",
                "swift_username": dev_username,
                "swift_password": dev_password,
                "swift_container_name": dev_compute_out["object_container_name"],
                # Manila/CephFS (datotecna pohrana - backupi).
                "manila_export_path": dev_compute_out["manila_share_export_locations"][0]["path"],
                "manila_access_to": dev_compute_out["manila_access_to"],
                "manila_access_key": dev_compute_out["manila_access_key"],
            },
        }

    return inventory


def to_yaml(data, indent=0):
    # Rucni, ovisnost-slobodan YAML writer (bez potrebe za PyYAML paketom) -
    # isti kao u generate_inventory.py (Azure), namjerno duplicirano ovdje da
    # ovaj skript ostane samostalan i lako prenosiv na workstation.
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
    # UVIJEK quote-aj stringove (json.dumps je valjan YAML flow scalar) -
    # live otkriveno 11.9.2026: generirane Keystone lozinke (random_password
    # u Terraformu) mogu sadrzavati YAML specijalne znakove ([](){}*&!|>'"%
    # itd.) koje ranija "quote samo ako sadrzi : # ili \"" heuristika nije
    # hvatala (npr. "[Y8(0dZcXn]5qP7oGX*P") - takav string pokvari CIJELI
    # YAML parse (Ansible je prijavio "Invalid host pattern 'all:'" jer je
    # ostatak fajla nakon te linije bio krivo strukturiran), a
    # ansible-playbook svejedno vrati exit 0 (0 hostova = "nista za odraditi",
    # ne greska) pa je provision.py tiho "uspio" bez ijednog izvrsenog taska.
    if isinstance(v, str):
        return json.dumps(v)
    if isinstance(v, bool):
        return "true" if v else "false"
    return str(v)


if __name__ == "__main__":
    admin_user = os.environ.get("OS_ADMIN_USERNAME", "cloud-user")
    ssh_key_path = os.environ.get("ANSIBLE_SSH_KEY_OPENSTACK", "~/.ssh/example-keypair")
    # OS_AUTH_URL mora vec biti u environmentu (izvor: `source ~/admin-rc` prije
    # pokretanja ovog skripta) - isti Keystone endpoint koji koriste developerski
    # korisnici za Swift auth na Moodle VM-u, ne ide u kod hardkodirano.
    os_auth_url = os.environ.get("OS_AUTH_URL")
    if not os_auth_url:
        sys.exit("OS_AUTH_URL nije postavljen - pokreni 'source ~/admin-rc' prije ovog skripta.")

    i2_out = get_terraform_outputs(I2_DIR, "Provjeri da si pokrenuo 'terraform apply' u openstack-i2-terraform/")
    shared_out = get_terraform_outputs(
        COMPUTE_SHARED_DIR, "Provjeri da si pokrenuo 'terraform apply' u openstack-compute-terraform/"
    )
    i3_out = get_terraform_outputs(I3_DIR, "Provjeri da si pokrenuo 'terraform apply' u openstack-i3-terraform/")
    inventory = build_inventory(i2_out, shared_out, i3_out, admin_user, ssh_key_path, os_auth_url)

    with open(OUT_FILE, "w", encoding="utf-8") as f:
        f.write("\n".join(to_yaml(inventory)) + "\n")

    print(f"Inventory zapisan u {OUT_FILE}")
