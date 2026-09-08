# IRUO Projekt 2025/2026 — Implementacija računarstva u oblaku

Kontekst za nastavak rada u novoj sesiji (lokalnoj ili cloud). Ovo je handoff sažetak dogovora iz prethodne sesije — pročitaj prije nego što nastaviš.

## Zadatak (izvor: IRUO_Projekt_2025_2026.pdf, kolegij Algebra Bernays)

IT agencija TechSprint treba automatiziranu, izoliranu testnu okolinu za programere, za testiranje Moodle aplikacije. Implementirati **dvostruko**: i na OpenStacku i na Azureu (multi-cloud).

Zahtjevi okoline:
- Moodle app, **2 instance** (simulacija HA)
- Pristup isključivo kroz **jump host / bastion** — nema izravnog javnog pristupa ostalim instancama
- Aplikacijske VM: 2 vCPU, 4 GB RAM, 2 diska (OS + data)
- OS: Rocky Linux / CentOS Stream ili cloud-specijalizirana distribucija
- **Mrežna izolacija**: svaki programer ima svoju izoliranu virtualnu mrežu, međusobno ne komuniciraju
- Izlaz na Internet za sve VM-ove (preuzimanje paketa)
- Programeri smiju upravljati (start/stop/restart) **isključivo svojim** VM-ovima
- **DevOps Lead**: centralni VM, SSH pristup na sve ostale VM-ove, pravo paljenja/gašenja svih instanci
- **Pohrana po programeru**: instanca za objektnu pohranu (Moodle datoteke) + instanca za datotečnu pohranu (backupi), obje **auto-mount** na aplikacijske instance
- **Automatizacija**: cijeli deployment kroz IaC (Terraform/Bicep/Ansible/ARM)
- Dijagrami arhitekture za obje okoline + precizna procjena mjesečnih troškova za Azure
- **CSV-driven provisioning**: skripta prima .csv (`ime;prezime;rola`, role npr. `devops_lead`/`developer`) i kreira infrastrukturu za varijabilan broj korisnika. Testirati s **2 developera + 1 lead**. Skripta se pokreće **jednom** (idempotentno/orkestrirano, ne ručno više puta).
- OpenStack: vlastiti deployment ili **Red Hat Academy** (RHA)
- Predaja: dokument (standardni template), snimljen video izvršavanja deploymenta (YouTube, privatno) s objašnjenjem, git repo s redovitim commitovima

### Bodovanje (5×20 = 100 bodova)
- I1: Elementi cloud computinga i open source (izbor elemenata, cost, usporedba Azure/OpenStack, naming konvencija, tagovi `project: techsprint`, `environment: testing`)
- I2: OpenStack mreže/pohrana/sigurnost (dijagram, automatizacija, LB, diskovi, least-privilege mount, security grupe, izolacija)
- I3: OpenStack IAM (dijagram, automatizacija IAM-a, CSV provisioning, power-state kontrola po roli, odvojeni projekti/tenanti)
- I4: Azure mreže/pohrana (dijagram, automatizacija, LB usporedba, Storage Accounts, managed diskovi, Managed Identity/SAS, NSG/ASG, VNet izolacija)
- I5: Azure IAM/RBAC (dijagram RBAC, automatizacija, veličine instanci npr. B2s/D2s_v3, custom/built-in role, Start/Deallocate po roli, Resource Group hijerarhija)

**Rok predaje: 12.9.2026. 23:59:59** (Infoedu). Nema usmene obrane — samo predaja dokumenta + video + git pristup.

## Dogovorena strategija (bitno!)

1. **OpenStack preko RHA (Red Hat Academy)**, ne self-hosted — korisnik već ima pristup. Ovo eliminira najveći rizik/trošak vremena (deployment same platforme).
2. Ako RHA sandbox nema Swift/Manila kao core servise: zamjena je **VM instanca s MinIO** (objektna pohrana) i **VM instanca s NFS/Samba** (datotečna pohrana) po developeru, umjesto dizanja tih OpenStack servisa.
3. Podjela rada: **Claude piše sav kod** (Terraform za OpenStack i Azure, Ansible playbookovi za Moodle i mount storage-a, CSV, dijagrami, dokumentacija, cost assessment). **Korisnik pokreće** protiv svog RHA/Azure pristupa (Claude nema kredencijale), verificira, i vraća Claude-u output/greške za popravke.
4. Prije pisanja koda treba od korisnika: `clouds.yaml`/`openrc` (RHA), potvrda Azure subscription, provjera dostupnih OpenStack servisa (`openstack service list`) i kvota resursa (treba ~8 instanci: jump host + lead VM + 2×(Moodle VM + object storage VM + file storage VM)).

## Procjena vremena (dogovoreno s korisnikom)

- Ukupno hands-on vrijeme korisnika: **~15–26h** kroz 2–3 tjedna (ili stisnuto u 5 intenzivnih dana ~18–23h, bez buffera)
- Najveći rizik nije više OpenStack platforma (riješeno RHA-om) nego RHA kvota/vrijeme sesije i normalan debug ciklus (pisanje IaC koda protiv stvarnog API-ja gotovo nikad ne prođe iz prve — treba računati 10-15h na to, nije opcionalno)

## Status repozitorija (na dan pisanja ovog fajla)

Repo je u startu bio prazan/nepovezan sa zadatkom — sadržavao je samo `Picture1-3.jpg` (nepovezani logotipi/pečati) i `vm_control.sh` (skripta za lokalni libvirt lab, nepovezana s ovim projektom). **Još ništa od stvarnog IaC koda, Ansible playbookova, CSV-a, dijagrama ni dokumentacije nije napisano.**

## Sljedeći koraci

1. Dobiti od korisnika RHA kredencijale (`clouds.yaml`/`openrc`) i potvrdu Azure pristupa
2. Provjeriti dostupne OpenStack servise i kvote na RHA sandboxu
3. Postaviti strukturu repozitorija: `openstack/`, `azure/`, `ansible/`, `scripts/` (CSV provisioning), `docs/`
4. Pisati Terraform skelet za OpenStack (mreže, jump host, security grupe) — prvi konkretan korak
5. Paralelno: Terraform/Bicep za Azure, Ansible za Moodle, CSV skripta, dijagrami, dokumentacija, cost assessment

## Napomena o jeziku

Korisnik komunicira na hrvatskom/srpskom (neformalno). Projekt je hrvatski fakultetski kolegij — dokumentacija treba biti pisana bez gramatičkih grešaka (eksplicitno se boduje/oduzima).
