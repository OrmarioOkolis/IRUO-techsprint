# CSV provisioning (I3)

Jedna skripta, jedno pokretanje, cijeli deployment: `provision.py` čita CSV
popis osoba, generira Terraform ulaze za `azure-i4-terraform` i
`azure-i5-rbac-terraform`, i orkestrira `terraform apply` (× 2) + Ansible
inventory + `ansible-playbook`.

## CSV format

```
ime;prezime;rola
```

`rola` je `devops_lead` (točno jedan redak) ili `developer` (jedan ili više).
Primjer: [users.csv.example](users.csv.example).

Stvarni `users.csv` (pravi ljudi) je namjerno u `.gitignore` — kopiraj primjer:

```bash
cp scripts/users.csv.example scripts/users.csv
```

i uredi imena/prezimena tako da odgovaraju **postojećim** Azure AD korisnicima
u fakultetskom tenantu (skripta ne kreira nove korisnike, samo dohvaća njihov
`object_id` preko `az ad user list` i dodjeljuje im RBAC role u I5 modulu).

## Pokretanje

Preduvjeti: `az login` (ispravan tenant), `terraform`, `ansible-playbook`,
`ansible-galaxy` na PATH-u (WSL — vidi `CLAUDE.md`), i ručno popunjen
`azure-i4-terraform/terraform.tfvars` (SSH ključ — ne dolazi iz CSV-a).

```bash
# Provjeri parsiranje CSV-a + AAD lookup, bez diranja infrastrukture:
python3 scripts/provision.py --csv scripts/users.csv --dry-run

# Pravi deployment (interaktivna potvrda za svaki terraform apply):
python3 scripts/provision.py --csv scripts/users.csv

# Isto, bez interaktivne potvrde (korisno za snimanje videa):
python3 scripts/provision.py --csv scripts/users.csv --auto-approve

# Samo infrastruktura, bez instalacije Moodlea:
python3 scripts/provision.py --csv scripts/users.csv --skip-ansible
```

Broj developera je varijabilan — `dev01`, `dev02`, ... prema redoslijedu u
CSV-u, regije se rotiraju preko `DEV_REGION_POOL` u `provision.py` (izbjegava
"Total Regional vCPUs" kvotu dijeljenu s hub regijom).

Testirano s 2 developera + 1 lead.
