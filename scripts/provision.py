#!/usr/bin/env python3
"""
CSV-driven provisioning orkestracija za TechSprint multi-cloud testnu okolinu (I3).

Cita CSV (";"-odvojen, kolone ime;prezime;rola - rola je "devops_lead" ili
"developer") i orkestrira CIJELI deployment JEDNIM pokretanjem, na jedan od
dva oblaka preko --cloud:

    python3 scripts/provision.py --cloud azure --csv scripts/users.csv
    python3 scripts/provision.py --cloud openstack --csv scripts/users.csv

=== --cloud azure (default, radi lokalno/WSL protiv Azure API-ja) ===
Za svaku osobu dohvaca POSTOJECI Azure AD object_id preko `az ad user list`
(skripta NE kreira nove identitete - fakultetski tenant ne dopusta kreiranje
AAD korisnika preko API-ja), generira Terraform *.auto.tfvars za
azure-i4-terraform i azure-i5-rbac-terraform (regije se rotiraju preko
DEV_REGION_POOL), pa apply I4 -> I5 -> Ansible.

Preduvjeti: `az login` u ispravan (fakultetski) Azure AD tenant; terraform,
ansible-playbook, ansible-galaxy na PATH-u (WSL); azure-i4-terraform/
terraform.tfvars s admin_ssh_public_key (rucno, ne CSV).

=== --cloud openstack (MORA se pokretati NA RHA workstationu, ne lokalno -
nema mrezne rute izvana do Keystone endpointa, vidi CLAUDE.md) ===
Ne treba identity lookup (I3 SAM kreira Keystone korisnike, za razliku od
dijeljenog Azure AD tenanta). Generira *.auto.tfvars za openstack-i3-terraform,
openstack-i2-terraform i openstack-compute-terraform (developers/lead),
pa orkestrira: I3 -> I2 -> (jednokratni Manila share-type setup) ->
openstack-compute-terraform (shared: jump+lead, JEDNOM) ->
openstack-compute-dev-terraform (JEDNOM PO DEVELOPERU, mijenja OS_PROJECT_NAME
i -state fajl prije svakog apply-a - vidi CLAUDE.md "KRITICNO OGRANICENJE
PROVIDERA" zasto se ovo ne moze raditi u jednom for_each-based apply-u).

Preduvjeti: MORA se pokretati u shell-u gdje je vec `source ~/admin-rc`
izvrsen (skripta samo mijenja OS_PROJECT_NAME/OS_PROJECT_DOMAIN_NAME po
koraku, ne postavlja bazne kredencijale); `openstack-i2-terraform/
terraform.tfvars` mora vec postojati s `admin_ssh_public_key` (rucno, ne CSV -
isti obrazac kao Azureov admin_ssh_public_key, dijeli se preko -var-file s
compute modulima); `manila` i `terraform` na PATH-u. Ansible dio (Moodle
instalacija na OpenStack VM-ovima) JOS NIJE napisan - skripta zavrsava na
infrastrukturi.

Koristi --dry-run da provjeris parsiranje CSV-a (i, za Azure, AAD lookup) BEZ
diranja infrastrukture (korisno za snimanje videa/debug prije pravog apply-a).
"""
import argparse
import csv
import json
import os
import subprocess
import sys
import unicodedata
from pathlib import Path


_DJ_TRANSLATION = str.maketrans({"đ": "d", "Đ": "D"})  # dj/Dj nije NFKD-dekomponibilan


def strip_diacritics(s: str) -> str:
    """Skida dijakritike (č/ć/š/ž/đ...) radi usporedbe imena neovisno o tome
    pise li ih CSV ili AAD displayName s njima ili bez njih."""
    s = s.translate(_DJ_TRANSLATION)
    return "".join(c for c in unicodedata.normalize("NFKD", s) if not unicodedata.combining(c))

REPO_ROOT = Path(__file__).resolve().parent.parent
I4_DIR = REPO_ROOT / "azure-i4-terraform"
I5_DIR = REPO_ROOT / "azure-i5-rbac-terraform"
ANSIBLE_DIR = REPO_ROOT / "ansible"

OS_I3_DIR = REPO_ROOT / "openstack-i3-terraform"
OS_I2_DIR = REPO_ROOT / "openstack-i2-terraform"
OS_COMPUTE_SHARED_DIR = REPO_ROOT / "openstack-compute-terraform"
OS_COMPUTE_DEV_DIR = REPO_ROOT / "openstack-compute-dev-terraform"

VALID_ROLES = {"devops_lead", "developer"}

# HUB (jump host + DevOps Lead) je uvijek u HUB_REGION (vidi azure-i4-terraform/
# variables.tf var.location). Developeri rotiraju kroz DEV_REGION_POOL da izbjegnu
# "Total Regional vCPUs" kvotu (6) u istoj regiji kao hub - vidi opis u istom fileu.
HUB_REGION = "polandcentral"
DEV_REGION_POOL = ["francecentral", "swedencentral", "germanywestcentral", "spaincentral"]

# Mora se poklapati s default project_name/environment u openstack-i3-terraform,
# openstack-i2-terraform, openstack-compute-terraform i openstack-compute-dev-terraform
# variables.tf (var.project_name/var.environment) - nije CSV-driven, pa nema smisla
# izlagati kao CLI flag dok stvarno ne zatreba drugi naziv.
OS_PROJECT_NAME_PREFIX = "techsprint-testing"

# Rucno kreiran preko `manila type-create techsprint-cephfs False` 9.9.2026 na RHA
# CL110 sandboxu - vidi CLAUDE.md STATUS 9.9.2026 (Manila dio). Sandbox nije imao
# NIJEDAN share type po defaultu, a CephFS native driver (jedini dostupan protokol
# ovdje) treba DHSS=False tip. Skripta ovo sad radi automatski, idempotentno
# (provjeri postoji li prije nego kreira) - vidi ensure_manila_share_type().
OS_MANILA_SHARE_TYPE = "techsprint-cephfs"


def parse_csv(path: Path):
    with open(path, newline="", encoding="utf-8-sig") as f:
        rows = [r for r in csv.reader(f, delimiter=";") if r and any(c.strip() for c in r)]
    if not rows:
        sys.exit(f"Prazan CSV: {path}")

    header = [c.strip().lower() for c in rows[0]]
    data_rows = rows[1:] if header[:3] == ["ime", "prezime", "rola"] else rows
    if not data_rows:
        sys.exit("CSV nema ni jedan redak s podacima (samo header).")

    leads, developers = [], []
    for lineno, row in enumerate(data_rows, start=1):
        if len(row) < 3:
            sys.exit(f"Redak {lineno}: ocekivano 'ime;prezime;rola', dobiveno: {row!r}")
        ime, prezime, rola = (c.strip() for c in row[:3])
        rola = rola.lower()
        if not ime or not prezime:
            sys.exit(f"Redak {lineno}: ime/prezime ne smiju biti prazni")
        if rola not in VALID_ROLES:
            sys.exit(f"Redak {lineno}: nepoznata rola '{rola}' (ocekuje se 'devops_lead' ili 'developer')")
        entry = {"ime": ime, "prezime": prezime, "full_name": f"{ime} {prezime}"}
        (leads if rola == "devops_lead" else developers).append(entry)

    if len(leads) != 1:
        sys.exit(f"Ocekivan tocno 1 redak s rolom 'devops_lead', pronadjeno {len(leads)}.")
    if not developers:
        sys.exit("Potreban je barem 1 redak s rolom 'developer'.")
    return leads[0], developers


def assign_dev_ids_and_regions(developers):
    for idx, dev in enumerate(developers):
        dev["id"] = f"dev{idx + 1:02d}"
        dev["location"] = DEV_REGION_POOL[idx % len(DEV_REGION_POOL)]
    if len(developers) > len(DEV_REGION_POOL):
        print(
            f"UPOZORENJE: {len(developers)} developera, samo {len(DEV_REGION_POOL)} regija "
            f"u poolu - neke regije ce se dijeliti izmedju vise developera. Provjeri "
            f"'Total Regional vCPUs' kvotu po regiji prije apply-a.",
            file=sys.stderr,
        )


def assign_dev_ids(developers):
    """OpenStack varijanta - nema regija (jedan RHA sandbox, ne multi-region kao Azure)."""
    for idx, dev in enumerate(developers):
        dev["id"] = f"dev{idx + 1:02d}"


def az_lookup_object_id(ime: str, prezime: str):
    """Dohvati (object_id, upn, displayName) postojeceg AAD korisnika. Filtrira po
    prefiksu imena preko Azure AD API-ja, pa lokalno provjerava da prezime bude
    sadrzano u displayName (neovisno o redoslijedu ime/prezime u stvarnom displayName).
    Usporedba ignorira dijakritike na obje strane - CSV moze pisati "Nikolis", a
    pravi AAD displayName "Nikolis" (bez, npr. ako je "Nikolis" doslovno) ILI s
    dijakritikom (npr. "Nikoliš") i i dalje ce se poklopiti."""
    result = subprocess.run(
        [
            "az", "ad", "user", "list",
            "--filter", f"startswith(displayName,'{ime}')",
            "--query", "[].{id:id, displayName:displayName, upn:userPrincipalName}",
            "-o", "json",
        ],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, encoding="utf-8",
    )
    if result.returncode != 0:
        sys.exit(f"'az ad user list' nije uspio za '{ime} {prezime}':\n{result.stderr}")

    candidates = json.loads(result.stdout or "[]")
    prezime_l = strip_diacritics(prezime).lower()
    matches = [
        c for c in candidates
        if prezime_l in strip_diacritics(c.get("displayName") or "").lower()
    ]

    if not matches:
        sys.exit(
            f"Nema Azure AD korisnika '{ime} {prezime}' u trenutnom tenantu.\n"
            f"Skripta NE kreira nove korisnike - provjeri ime/prezime u CSV-u (mora "
            f"odgovarati AAD displayName) i da si prijavljen ('az login') u ispravan tenant."
        )
    if len(matches) > 1:
        sys.exit(f"Vise od jednog AAD korisnika odgovara '{ime} {prezime}': {matches}")

    m = matches[0]
    return m["id"], m["upn"], m["displayName"]


def hcl_string(s: str) -> str:
    return json.dumps(s)


def write_i4_tfvars(lead, developers, out_path: Path):
    lines = [
        "# AUTO-GENERIRANO iz CSV-a (scripts/provision.py) - NE UREDJUJ RUCNO.",
        "# Rucne postavke (admin_ssh_public_key, jump_host_allowed_ssh_cidr, ...) idu u terraform.tfvars.",
        "",
        "lead = {",
        f"  name = {hcl_string(lead['full_name'])}",
        "}",
        "",
        "developers = [",
    ]
    for dev in developers:
        lines += [
            "  {",
            f"    id       = {hcl_string(dev['id'])}",
            f"    name     = {hcl_string(dev['full_name'])}",
            f"    location = {hcl_string(dev['location'])}",
            "  },",
        ]
    lines.append("]")
    out_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_i5_tfvars(lead, developers, out_path: Path):
    lines = [
        "# AUTO-GENERIRANO iz CSV-a (scripts/provision.py) - NE UREDJUJ RUCNO.",
        "",
        "developers = [",
    ]
    for dev in developers:
        lines += [
            "  {",
            f"    id       = {hcl_string(dev['id'])}",
            f"    name     = {hcl_string(dev['full_name'])}",
            f"    location = {hcl_string(dev['location'])}",
            "  },",
        ]
    lines += ["]", "", "developer_principal_ids = {"]
    for dev in developers:
        lines.append(f"  {dev['id']} = {hcl_string(dev['object_id'])} # {dev['upn']}")
    lines += ["}", "", f"lead_principal_id = {hcl_string(lead['object_id'])} # {lead['upn']}"]
    out_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_openstack_devlist_tfvars(developers, out_path: Path, lead=None):
    """I3/I2 trebaju i 'lead' i 'developers'; openstack-compute-terraform (shared)
    treba SAMO 'developers' (nema var.lead - vidi CLAUDE.md/variables.tf) - otud
    opcionalni `lead` parametar umjesto tri gotovo identicne funkcije."""
    lines = []
    if lead is not None:
        lines += ["lead = {", f"  name = {hcl_string(lead['full_name'])}", "}", ""]
    lines.append("developers = [")
    for dev in developers:
        lines += [
            "  {",
            f"    id   = {hcl_string(dev['id'])}",
            f"    name = {hcl_string(dev['full_name'])}",
            "  },",
        ]
    lines.append("]")
    out_path.write_text(
        "# AUTO-GENERIRANO iz CSV-a (scripts/provision.py) - NE UREDJUJ RUCNO.\n"
        + "\n".join(lines) + "\n",
        encoding="utf-8",
    )


def ensure_manila_share_type(env):
    """Idempotentno: kreira OS_MANILA_SHARE_TYPE preko `manila type-create` ako jos
    ne postoji. Vidi napomenu uz OS_MANILA_SHARE_TYPE i CLAUDE.md STATUS 9.9.2026 -
    sandbox nije imao NIJEDAN share type po defaultu, scheduler bez toga ne moze
    dodijeliti Manila backend (host ostaje prazan, share zavrsi u error statusu)."""
    result = subprocess.run(
        ["manila", "type-list", "--columns", "Name"],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True, env=env,
    )
    if result.returncode != 0:
        sys.exit(f"'manila type-list' nije uspio:\n{result.stderr}")
    if OS_MANILA_SHARE_TYPE in result.stdout:
        print(f"Manila share type '{OS_MANILA_SHARE_TYPE}' vec postoji, preskacem.")
        return
    print(f"Manila share type '{OS_MANILA_SHARE_TYPE}' ne postoji - kreiram (DHSS=False)...")
    run(["manila", "type-create", OS_MANILA_SHARE_TYPE, "False"], env=env)


def scoped_env(project_name: str) -> dict:
    """Kopija trenutnog environmenta s OS_PROJECT_NAME prebacenim na drugi projekt -
    isti obrazac kao rucni `export OS_PROJECT_NAME=... && unset OS_PROJECT_ID` koraci
    tijekom rucnog testiranja. Admin korisnik/lozinka ostaju isti (OS_USERNAME/
    OS_PASSWORD iz vec sourceanog admin-rc) - samo je scope tokena drukciji projekt.
    Nova/Cinder/Swift/Manila TRAZE project-scoped token (project_id je computed-only
    u Terraform provideru) - vidi CLAUDE.md "KRITICNO OGRANICENJE PROVIDERA"."""
    env = os.environ.copy()
    env["OS_PROJECT_NAME"] = project_name
    env["OS_PROJECT_DOMAIN_NAME"] = "Default"
    env.pop("OS_PROJECT_ID", None)
    return env


def run(cmd, cwd=None, env=None):
    print(f"\n$ {' '.join(cmd)}  (u {cwd or Path.cwd()})")
    result = subprocess.run(cmd, cwd=cwd, env=env)
    if result.returncode != 0:
        sys.exit(f"Naredba nije uspjela (exit {result.returncode}): {' '.join(cmd)}")


def main_azure(args, lead, developers):
    assign_dev_ids_and_regions(developers)

    print(f"DevOps Lead: {lead['full_name']}")
    print(f"Developeri ({len(developers)}):")
    for dev in developers:
        print(f"  {dev['id']}: {dev['full_name']} -> {dev['location']}")

    print("\nDohvacam Azure AD object_id-eve (az ad user list)...")
    lead["object_id"], lead["upn"], _ = az_lookup_object_id(lead["ime"], lead["prezime"])
    print(f"  {lead['full_name']} -> {lead['upn']} ({lead['object_id']})")
    for dev in developers:
        dev["object_id"], dev["upn"], _ = az_lookup_object_id(dev["ime"], dev["prezime"])
        print(f"  {dev['full_name']} -> {dev['upn']} ({dev['object_id']})")

    i4_tfvars = I4_DIR / "csv_generated.auto.tfvars"
    i5_tfvars = I5_DIR / "csv_generated.auto.tfvars"
    write_i4_tfvars(lead, developers, i4_tfvars)
    write_i5_tfvars(lead, developers, i5_tfvars)
    print(f"\nGenerirano: {i4_tfvars}")
    print(f"Generirano: {i5_tfvars}")

    if args.dry_run:
        print("\n--dry-run: gotovo (tfvars generirani, infrastruktura NIJE dirana).")
        return

    approve = ["-auto-approve"] if args.auto_approve else []

    # 1) I4: mreza, VM-ovi, storage, LB - preduvjet za sve ostalo.
    run(["terraform", "init", "-input=false"], cwd=I4_DIR)
    run(["terraform", "apply", *approve], cwd=I4_DIR)

    # 2) I5: RBAC dodjele - ovisi o Resource Groupovima iz koraka 1 (data source po imenu).
    run(["terraform", "init", "-input=false"], cwd=I5_DIR)
    run(["terraform", "apply", *approve], cwd=I5_DIR)

    if args.skip_ansible:
        print("\n--skip-ansible: infrastruktura gotova, Moodle NIJE instaliran.")
        return

    # 3) Ansible inventory iz I4 outputa, pa playbook (mount storage + Moodle instalacija).
    #    ANSIBLE_CONFIG eksplicitno - ansible.cfg se tiho ignorira kad je repo na
    #    world-writable putanji (WSL /mnt/d), pa bi bez ovoga pipelining/host key
    #    postavke pale na default. --forks 2 - jump host default MaxStartups +
    #    visi forks povremeno daju "timeout during banner exchange" na ProxyJumpu
    #    (vidi memory ansible-jump-host-maxstartups).
    ansible_env = {**os.environ, "ANSIBLE_CONFIG": str(ANSIBLE_DIR / "ansible.cfg")}
    run([sys.executable, str(ANSIBLE_DIR / "inventory" / "generate_inventory.py")], cwd=ANSIBLE_DIR)
    run(["ansible-galaxy", "collection", "install", "-r", "requirements.yml"], cwd=ANSIBLE_DIR, env=ansible_env)
    run(["ansible-playbook", "-i", "inventory/hosts.yml", "site.yml", "--forks", "2"],
        cwd=ANSIBLE_DIR, env=ansible_env)

    print("\nGotovo - infrastruktura na Azureu + Moodle instaliran za sve osobe iz CSV-a.")


def main_openstack(args, lead, developers):
    assign_dev_ids(developers)

    print(f"DevOps Lead: {lead['full_name']}")
    print(f"Developeri ({len(developers)}):")
    for dev in developers:
        print(f"  {dev['id']}: {dev['full_name']}")

    i3_tfvars = OS_I3_DIR / "csv_generated.auto.tfvars"
    i2_tfvars = OS_I2_DIR / "csv_generated.auto.tfvars"
    shared_tfvars = OS_COMPUTE_SHARED_DIR / "csv_generated.auto.tfvars"
    write_openstack_devlist_tfvars(developers, i3_tfvars, lead=lead)
    write_openstack_devlist_tfvars(developers, i2_tfvars, lead=lead)
    write_openstack_devlist_tfvars(developers, shared_tfvars)  # nema var.lead ovdje
    print(f"\nGenerirano: {i3_tfvars}")
    print(f"Generirano: {i2_tfvars}")
    print(f"Generirano: {shared_tfvars}")

    if args.dry_run:
        print("\n--dry-run: gotovo (tfvars generirani, infrastruktura NIJE dirana).")
        return

    ssh_key_tfvars = OS_I2_DIR / "terraform.tfvars"
    if not ssh_key_tfvars.exists():
        sys.exit(
            f"Nedostaje {ssh_key_tfvars} (admin_ssh_public_key) - rucni jednokratni "
            f"korak, ne generira se iz CSV-a. Vidi {OS_I2_DIR / 'terraform.tfvars.example'}."
        )

    approve = ["-auto-approve"] if args.auto_approve else []
    admin_env = os.environ.copy()  # I3/I2 rade kao plain admin (default admin-rc scope).

    # 1) I3: Keystone projekti/korisnici/role/kvote - MORA ici prije I2 (obrnuto od
    #    Azure I4->I5 redoslijeda - vidi CLAUDE.md "OpenStack Terraform arhitektura").
    run(["terraform", "init", "-input=false"], cwd=OS_I3_DIR, env=admin_env)
    run(["terraform", "apply", *approve], cwd=OS_I3_DIR, env=admin_env)

    # 2) I2: mreze/security grupe/floating IP - data source lookup I3-inih projekata po imenu.
    run(["terraform", "init", "-input=false"], cwd=OS_I2_DIR, env=admin_env)
    run(["terraform", "apply", *approve], cwd=OS_I2_DIR, env=admin_env)

    # 3) Jednokratni admin setup preduvjet za Manila (vidi ensure_manila_share_type()).
    ensure_manila_share_type(admin_env)

    # 4) Jump host + DevOps Lead VM - JEDNOM, scope-ano na shared projekt (Nova/Cinder/
    #    Swift/Manila TRAZE project-scoped provider - ne mogu ici u I2-in admin-scoped
    #    for_each apply, vidi CLAUDE.md "KRITICNO OGRANICENJE PROVIDERA").
    shared_env = scoped_env(f"{OS_PROJECT_NAME_PREFIX}-shared")
    run(["terraform", "init", "-input=false"], cwd=OS_COMPUTE_SHARED_DIR, env=shared_env)
    run(
        ["terraform", "apply", *approve, f"-var-file={ssh_key_tfvars}"],
        cwd=OS_COMPUTE_SHARED_DIR, env=shared_env,
    )

    # 5) Moodle instance + Cinder/Swift/Manila - JEDNOM PO DEVELOPERU, zaseban state
    #    fajl po developeru (isti modul/kod, drugi project scope svaki put).
    for dev in developers:
        dev_env = scoped_env(f"{OS_PROJECT_NAME_PREFIX}-{dev['id']}")
        state_file = f"terraform-{dev['id']}.tfstate"
        run(["terraform", "init", "-input=false"], cwd=OS_COMPUTE_DEV_DIR, env=dev_env)
        run(
            [
                "terraform", "apply", *approve,
                f"-state={state_file}",
                f"-var-file={ssh_key_tfvars}",
                f"-var=dev_id={dev['id']}",
                f"-var=manila_share_type={OS_MANILA_SHARE_TYPE}",
            ],
            cwd=OS_COMPUTE_DEV_DIR, env=dev_env,
        )

    print("\nOpenStack infrastruktura gore. Nastavljam s Ansibleom (Moodle instalacija)...")

    if args.skip_ansible:
        print("--skip-ansible: infrastruktura gotova, Moodle NIJE instaliran.")
        return

    # 6) Ansible: inventory iz OpenStack Terraform outputa, pa playbook.
    #    ANSIBLE_CONFIG eksplicitno (ansible.cfg se ignorira na world-writable
    #    putanji); --forks 2 zbog jump host MaxStartups (kao Azure). OS_* env
    #    varijable (OS_AUTH_URL...) iz vec sourceanog admin-rc idu dalje kroz
    #    os.environ - generate_inventory_openstack.py ih treba za Swift auth.
    ansible_env = {**os.environ, "ANSIBLE_CONFIG": str(ANSIBLE_DIR / "ansible.cfg")}
    ansible_env.pop("OS_PROJECT_NAME", None)   # inventory skripta sama scope-a po devu
    ansible_env.pop("OS_PROJECT_ID", None)
    run([sys.executable, str(ANSIBLE_DIR / "inventory" / "generate_inventory_openstack.py")],
        cwd=ANSIBLE_DIR, env=ansible_env)
    run(["ansible-galaxy", "collection", "install", "-r", "requirements.yml"],
        cwd=ANSIBLE_DIR, env=ansible_env)
    run(["ansible-playbook", "-i", "inventory/hosts-openstack.yml", "site-openstack.yml", "--forks", "2"],
        cwd=ANSIBLE_DIR, env=ansible_env)

    print("\nGotovo - OpenStack infrastruktura + Moodle instaliran za sve osobe iz CSV-a.")


def main():
    p = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    p.add_argument("--csv", required=True, type=Path, help="Put do CSV-a (ime;prezime;rola)")
    p.add_argument(
        "--cloud", choices=["azure", "openstack"], default="azure",
        help="Koji oblak orkestrirati (default: azure). --cloud openstack MORA se "
        "pokretati NA RHA workstationu s vec sourceanim ~/admin-rc - vidi docstring.",
    )
    p.add_argument(
        "--dry-run", action="store_true",
        help="Samo parsiraj CSV (Azure: i dohvati AAD id-ove) i generiraj tfvars - "
        "bez terraform/ansible koraka.",
    )
    p.add_argument(
        "--skip-ansible", action="store_true",
        help="Preskoci Ansible korak (samo infrastruktura, bez instalacije Moodlea). "
        "Nema efekta za --cloud openstack (Ansible dio tamo jos ne postoji).",
    )
    p.add_argument(
        "--auto-approve", action="store_true",
        help="Prosljedi -auto-approve terraformu (bez interaktivne potvrde po modulu).",
    )
    args = p.parse_args()

    if not args.csv.exists():
        sys.exit(f"CSV ne postoji: {args.csv}")

    lead, developers = parse_csv(args.csv)

    if args.cloud == "azure":
        main_azure(args, lead, developers)
    else:
        main_openstack(args, lead, developers)


if __name__ == "__main__":
    main()
