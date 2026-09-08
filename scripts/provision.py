#!/usr/bin/env python3
"""
CSV-driven provisioning orkestracija za TechSprint multi-cloud testnu okolinu (I3).

Cita CSV (";"-odvojen, kolone ime;prezime;rola - rola je "devops_lead" ili
"developer"), za svaku osobu dohvaca POSTOJECI Azure AD object_id preko
`az ad user list` (skripta NE kreira nove identitete - fakultetski tenant ne
dopusta kreiranje AAD korisnika preko API-ja, isto ogranicenje kao i ranije
rucno testirano preko Azure Portala), generira Terraform *.auto.tfvars za
azure-i4-terraform i azure-i5-rbac-terraform (broj developera je varijabilan -
dev01, dev02, ... prema redoslijedu u CSV-u, regije se rotiraju preko
DEV_REGION_POOL), i orkestrira CIJELI deployment JEDNIM pokretanjem:

    python3 scripts/provision.py --csv scripts/users.csv

Preduvjeti (isti kao i do sad, skripta ih ne instalira):
  - `az login` u ispravan (fakultetski) Azure AD tenant
  - terraform, ansible-playbook, ansible-galaxy na PATH-u (WSL - vidi CLAUDE.md)
  - azure-i4-terraform/terraform.tfvars s admin_ssh_public_key (rucno, ne CSV)

Koristi --dry-run da provjeris parsiranje CSV-a i AAD lookup BEZ diranja
infrastrukture (korisno za snimanje videa/debug prije pravog apply-a).
"""
import argparse
import csv
import json
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

VALID_ROLES = {"devops_lead", "developer"}

# HUB (jump host + DevOps Lead) je uvijek u HUB_REGION (vidi azure-i4-terraform/
# variables.tf var.location). Developeri rotiraju kroz DEV_REGION_POOL da izbjegnu
# "Total Regional vCPUs" kvotu (6) u istoj regiji kao hub - vidi opis u istom fileu.
HUB_REGION = "polandcentral"
DEV_REGION_POOL = ["francecentral", "swedencentral", "germanywestcentral", "spaincentral"]


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
        capture_output=True, text=True, encoding="utf-8",
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


def run(cmd, cwd=None):
    print(f"\n$ {' '.join(cmd)}  (u {cwd or Path.cwd()})")
    result = subprocess.run(cmd, cwd=cwd)
    if result.returncode != 0:
        sys.exit(f"Naredba nije uspjela (exit {result.returncode}): {' '.join(cmd)}")


def main():
    p = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    p.add_argument("--csv", required=True, type=Path, help="Put do CSV-a (ime;prezime;rola)")
    p.add_argument(
        "--dry-run", action="store_true",
        help="Samo parsiraj CSV, dohvati AAD id-ove i generiraj tfvars - bez terraform/ansible koraka.",
    )
    p.add_argument(
        "--skip-ansible", action="store_true",
        help="Preskoci Ansible korak (samo infrastruktura, bez instalacije Moodlea).",
    )
    p.add_argument(
        "--auto-approve", action="store_true",
        help="Prosljedi -auto-approve terraformu (bez interaktivne potvrde po modulu).",
    )
    args = p.parse_args()

    if not args.csv.exists():
        sys.exit(f"CSV ne postoji: {args.csv}")

    lead, developers = parse_csv(args.csv)
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
    run([sys.executable, str(ANSIBLE_DIR / "inventory" / "generate_inventory.py")], cwd=ANSIBLE_DIR)
    run(["ansible-galaxy", "collection", "install", "-r", "requirements.yml"], cwd=ANSIBLE_DIR)
    run(["ansible-playbook", "-i", "inventory/hosts.yml", "site.yml"], cwd=ANSIBLE_DIR)

    print("\nGotovo - infrastruktura na Azureu + Moodle instaliran za sve osobe iz CSV-a.")


if __name__ == "__main__":
    main()
