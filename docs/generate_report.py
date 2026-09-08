#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Generira docs/IRUO-projekt-izvjestaj.docx.

Format (font, velicina stranice, margine) preuzet iz
projekt_template_algebra_bernays_HR_2025.docx, struktura je NAMJERNO
drugacija (dogovoreno s mentorom/predmetnim nastavnikom) - poglavlja prate
ishode ucenja (I1-I5) umjesto generickog Abstract/Introduction/Methods
predloska, svaki ishod je jedno poglavlje (Heading 1), svaki bodovani
kriterij unutar njega jedan podnaslov (Heading 2).

Kod se cita izravno iz repozitorija (ne prepisuje rucno) da dokument uvijek
odrazava stvarno stanje - pokreni ponovno nakon svake vece promjene koda:

    python3 docs/generate_report.py

Namjerno BEZ dijagrama/slika - oznaceno je [OVDJE IDE DIJAGRAM: ...] gdje
korisnik sam umece sliku (docs/i4-azure-architecture.svg za I4, ostali
dijagrami jos nisu izradjeni).
"""
import os
import docx
from docx.shared import Pt, Cm, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml.ns import qn
from docx.oxml import OxmlElement

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "docs", "IRUO-projekt-izvjestaj.docx")


def read(rel_path):
    with open(os.path.join(ROOT, rel_path), encoding="utf-8") as f:
        return f.read()


def read_lines(rel_path, start, end):
    """1-indexed, inclusive - za izvatke iz duljih fileova."""
    lines = read(rel_path).splitlines()
    return "\n".join(lines[start - 1:end])


# ---------------------------------------------------------------------------
# Document setup
# ---------------------------------------------------------------------------
doc = docx.Document()

style = doc.styles["Normal"]
style.font.name = "Times New Roman"
style.font.size = Pt(12)
rpr = style.element.get_or_add_rPr()
rFonts = rpr.find(qn("w:rFonts"))
if rFonts is None:
    rFonts = OxmlElement("w:rFonts")
    rpr.append(rFonts)
rFonts.set(qn("w:eastAsia"), "Times New Roman")

for name, size, bold in [("Heading 1", 16, True), ("Heading 2", 13, True), ("Heading 3", 12, True)]:
    s = doc.styles[name]
    s.font.name = "Times New Roman"
    s.font.size = Pt(size)
    s.font.bold = bold
    s.font.color.rgb = RGBColor(0, 0, 0)

# Code style (monospace, manji font, sivkasta pozadina preko shadinga na paragrafu)
if "Code" not in [s.name for s in doc.styles]:
    code_style = doc.styles.add_style("Code", docx.enum.style.WD_STYLE_TYPE.PARAGRAPH)
    code_style.base_style = doc.styles["Normal"]
    code_style.font.name = "Consolas"
    code_style.font.size = Pt(9)
    code_style.paragraph_format.space_before = Pt(2)
    code_style.paragraph_format.space_after = Pt(2)
    code_style.paragraph_format.left_indent = Cm(0.4)

section = doc.sections[0]
section.page_width = Cm(21.0)
section.page_height = Cm(29.7)
section.top_margin = Cm(2.0)
section.bottom_margin = Cm(2.0)
section.left_margin = Cm(2.0)
section.right_margin = Cm(2.0)


def h1(text):
    doc.add_heading(text, level=1)


def h2(text):
    doc.add_heading(text, level=2)


def h3(text):
    doc.add_heading(text, level=3)


def p(text):
    doc.add_paragraph(text)


def bullets(items):
    for it in items:
        doc.add_paragraph(it, style="List Bullet")


def codeblock(text, path_label=None):
    if path_label:
        cap = doc.add_paragraph()
        cap.add_run(f"Kod {path_label}:").italic = True
    for line in text.rstrip("\n").split("\n"):
        para = doc.add_paragraph(style="Code")
        para.add_run(line if line else " ")


def placeholder(text):
    para = doc.add_paragraph()
    run = para.add_run(f"[{text}]")
    run.bold = True
    run.font.color.rgb = RGBColor(0xC0, 0x00, 0x00)


def status(text, done=True):
    para = doc.add_paragraph()
    run = para.add_run(("STATUS (gotovo): " if done else "STATUS (u tijeku): ") + text)
    run.italic = True
    run.font.color.rgb = RGBColor(0, 0x60, 0) if done else RGBColor(0x99, 0x66, 0)


def pagebreak():
    doc.add_page_break()


# ---------------------------------------------------------------------------
# NASLOVNICA
# ---------------------------------------------------------------------------
title = doc.add_paragraph()
title.alignment = WD_ALIGN_PARAGRAPH.CENTER
r = title.add_run("Implementacija računarstva u oblaku")
r.bold = True
r.font.size = Pt(24)

subtitle = doc.add_paragraph()
subtitle.alignment = WD_ALIGN_PARAGRAPH.CENTER
r = subtitle.add_run("TechSprint – automatizirana multi-cloud testna okolina za Moodle")
r.font.size = Pt(16)

for _ in range(4):
    doc.add_paragraph()

meta = doc.add_paragraph()
meta.alignment = WD_ALIGN_PARAGRAPH.CENTER
meta.add_run("Mario Nikoliš\nAlgebra Bernays\nIRUO – Implementacija računarstva u oblaku\n2025./2026.").font.size = Pt(12)

pagebreak()

# ---------------------------------------------------------------------------
# CONTENTS placeholder (Word "Update Field" treba rucno pokrenuti nakon otvaranja)
# ---------------------------------------------------------------------------
h1("Sadržaj")
p("(Umetni automatski sadržaj u Wordu: Reference → Sadržaj → Automatska tablica, "
  "nakon otvaranja dokumenta i eventualnih izmjena).")
pagebreak()

# ---------------------------------------------------------------------------
# ABSTRACT
# ---------------------------------------------------------------------------
h1("Sažetak")
p(
    "IT agencija TechSprint treba automatiziran način kreiranja izoliranih testnih okolina za "
    "svoje programere, za potrebe testiranja Moodle aplikacije. Ovaj projekt dizajnira i "
    "implementira takvu okolinu paralelno na dvije cloud platforme – OpenStack (putem Red Hat "
    "Academy sandboxa) i Microsoft Azure – kako bi se usporedile mogućnosti i troškovi oba "
    "pristupa. Svaki programer dobiva vlastitu mrežno izoliranu okolinu s dvije instance Moodle "
    "aplikacije u visokoj dostupnosti, uz objektnu i datotečnu pohranu automatski montiranu na "
    "aplikacijske instance. Pristup okolini omogućen je isključivo kroz jump host, dok DevOps "
    "Lead ima centraliziranu kontrolu nad svim resursima. Cijeli deployment automatiziran je "
    "kroz Infrastructure as Code alate (Terraform, Ansible) i pokreće se kroz CSV datoteku s "
    "popisom korisnika i njihovih rola. Dokument opisuje odabrane elemente arhitekture, "
    "sigurnosne koncepte, IAM strukturu na oba oblaka, procjenu mjesečnih troškova za Azure "
    "okolinu te stvarne rezultate automatiziranog deploymenta na obje platforme."
)

# ---------------------------------------------------------------------------
# UVOD
# ---------------------------------------------------------------------------
h1("Uvod")
p(
    "Ovaj dokument odgovara na pet ključnih pitanja projektnog zadatka: koji se problem rješava "
    "(izolirana, automatizirana testna okolina za programere), kako je taj problem uobičajeno "
    "rješavan (multi-cloud IaC pristupi opisani u službenoj OpenStack i Azure dokumentaciji), "
    "što je konkretno napravljeno (opisano kroz poglavlja I1–I5), koji su rezultati "
    "(funkcionalna, automatizirana Azure okolina s radnim Moodle instancama; djelomično "
    "funkcionalna OpenStack okolina s automatiziranim projektima, korisnicima i mrežama) te "
    "koji su sljedeći koraci (dovršetak OpenStack compute sloja, CSV integracija za OpenStack, "
    "snimka izvršavanja deploymenta)."
)
p(
    "Poglavlja koja slijede namjerno su organizirana prema ishodima učenja kolegija (I1–I5), a "
    "ne prema generičkoj strukturi izvještaja, kako bi izravno odgovarala kriterijima "
    "bodovanja projekta definiranima u projektnom zadatku. Unutar svakog poglavlja, svaki "
    "bodovani kriterij iz zadatka ima vlastiti podnaslov."
)
p(
    "Status svake stavke označen je izričito (STATUS: gotovo / u tijeku), s obzirom na to da je "
    "ovaj dokument pisan usporedno s razvojem infrastrukture, a ne nakon njegovog završetka."
)

pagebreak()

# ---------------------------------------------------------------------------
# I1 - Elementi cloud computinga i open source
# ---------------------------------------------------------------------------
h1("I1 – Elementi računarstva u oblaku i otvoreni kod")
p("Ovo poglavlje odgovara na kriterij I1 (20 bodova): objašnjenje odabira elemenata, procjena "
  "troškova, usporedba Azure/OpenStack ponude, konvencija imenovanja resursa i tag strategija.")

h2("Pretpostavke arhitekture")
p("Procjena je izrađena za scenarij 2 developera + 1 DevOps Lead, u skladu sa zahtjevima "
  "zadatka. Taj isti scenarij korišten je i za stvarni (live) test deploymenta opisan u "
  "poglavljima I2–I5.")

h2("Objašnjenje odabira elemenata")
h3("Load Balancer")
bullets([
    "OpenStack: Octavia (LBaaS v2) kao nativno rješenje. Servis je dostupan u katalogu RHA "
    "sandboxa, no kako je opisano u I2, njegova konfiguracija (amp_flavor_id) na ovom "
    "konkretnom sandboxu nije potpuna te je LB kreiranje onemogućeno unaprijed definiranom "
    "varijablom, uz zadržan ispravan kod za produkcijski RHOSP.",
    "Azure: Azure Load Balancer (Standard SKU, interni). Application Gateway nije potreban jer "
    "Moodle HA par zahtijeva samo L4 (TCP) balansiranje unutar izolirane mreže, bez potrebe za "
    "L7 značajkama (detaljnija usporedba u I4).",
])
h3("Objektna pohrana (Moodle datoteke)")
bullets([
    "OpenStack: Swift je dostupan u service katalogu RHA sandboxa (potvrđeno kroz "
    "`openstack service list`), no zbog ograničenja Terraform providera "
    "(openstack_objectstorage_container_v1 ne podržava project override – vidi I2) kreiranje "
    "kontejnera prebačeno je u zaseban, project-scoped Terraform modul koji je u izradi.",
    "Azure: Storage Account s Blob kontejnerom (Hot tier, LRS) – potpuno upravljana usluga, bez "
    "potrebe za održavanjem VM-a.",
])
h3("Datotečna pohrana (backupi)")
bullets([
    "OpenStack: Manila je dostupna u service katalogu (potvrđeno), iz istog razloga kao Swift "
    "(project_id nije postavljiv preko admin providera) share se kreira u istom project-scoped "
    "modulu koji je u izradi.",
    "Azure: Azure Files (Standard, LRS), mountano preko SMB-a uz ključ dohvaćen iz Key Vaulta "
    "pomoću Managed Identityja (least-privilege, bez ključa na disku – Azure Files ne podržava "
    "izravnu Managed Identity autentikaciju za SMB).",
])
h3("Tip virtualne mašine")
bullets([
    "Azure: Standard_B2s_v2 (2 vCPU, 4 GiB RAM) – burstable serija, jeftinija od D2s_v3 za "
    "testnu okolinu s povremenim opterećenjem. Standard_B2s korišten je kao prvi izbor, no nije "
    "bio dostupan u odabranoj regiji (Poland Central) pa je zamijenjen B2s_v2 istog profila.",
    "OpenStack: postojeći flavori na RHA sandboxu (default/default-swap/default-extra-disk) "
    "imaju 2048 MB RAM, manje od traženih 4 GB – u I2/I3 Terraformu definirana je varijabla za "
    "custom flavor (4096 MB / 2 vCPU) koji se kreira u sklopu compute modula.",
])
h3("Tip diska")
bullets([
    "Azure: Managed Disks, Standard SSD (LRS) – konzistentnija latencija od HDD-a za bazu "
    "podataka, niža cijena od Premium SSD-a koji nije potreban za testnu okolinu. OS disk 32 "
    "GiB, data disk 64 GiB.",
    "OpenStack: Cinder blok-pohrana ekvivalentnih veličina, kreira se u compute modulu "
    "(Cinder volumeni, poput Nova instanci, zahtijevaju project-scoped provider – vidi I2).",
])

h2("Procjena mjesečnih troškova (Azure)")
p("Procjena za 2 developera + 1 DevOps Lead, Pay-As-You-Go, regija West Europe / Poland "
  "Central, cijene u USD (stanje: kolovoz–rujan 2026.). Prije stvarne produkcijske upotrebe "
  "preporučeno je potvrditi točne brojke kroz Azure Pricing Calculator.")

table = doc.add_table(rows=1, cols=4)
table.style = "Light Grid Accent 1"
hdr = table.rows[0].cells
hdr[0].text = "Resurs"
hdr[1].text = "Količina"
hdr[2].text = "Jed. cijena (USD/mj.)"
hdr[3].text = "Ukupno (USD/mj.)"
rows_data = [
    ("Standard_B2s_v2 VM (jump + lead)", "2", "~17.03", "~34.06"),
    ("Standard_B2s_v2 VM (Moodle, 2 dev × 2 instance)", "4", "~17.03", "~68.12"),
    ("Managed Disk Standard SSD 32 GiB (OS)", "6", "~2.40", "~14.40"),
    ("Managed Disk Standard SSD 64 GiB (data)", "4", "~4.80", "~19.20"),
    ("Storage Account (Blob + Files, ~10 GB)", "2", "~0.50", "~1.00"),
    ("Standard Load Balancer (interni)", "2", "~18.25", "~36.50"),
    ("NAT Gateway (izlazni internet promet)", "2", "~32.00", "~64.00"),
    ("Key Vault (standard tier, minimalno korištenje)", "2", "~0.03", "~0.06"),
    ("Javna IP adresa (jump host)", "1", "~3.65", "~3.65"),
]
for r_ in rows_data:
    row = table.add_row().cells
    for i, val in enumerate(r_):
        row[i].text = val
p("Ukupna procjena: ≈ 241 USD/mjesečno za scenarij 2 developera + 1 DevOps Lead.")
p("Tablica 1. Procjena mjesečnih troškova Azure okoline")

h3("Napomene o procjeni")
bullets([
    "NSG, VNet, Managed Identity i RBAC dodjele ne generiraju dodatni trošak.",
    "NAT Gateway je značajna stavka troška (uveden zbog rješavanja problema izlaznog "
    "interneta za instance iza internog Load Balancera – vidi I4); u produkciji bi se "
    "razmotrila zamjena jeftinijom alternativom ako promet dopušta.",
    "Svaki dodatni developer dodaje približno 55–60 USD/mjesečno (2× VM + diskovi + LB).",
    "Iznos ne uključuje PDV niti Reserved Instance/Savings Plan popuste.",
])

h2("Usporedba ponude Azure i OpenStack elemenata")
table2 = doc.add_table(rows=1, cols=3)
table2.style = "Light Grid Accent 1"
hdr2 = table2.rows[0].cells
hdr2[0].text = "Element"
hdr2[1].text = "Azure"
hdr2[2].text = "OpenStack"
rows2 = [
    ("Compute", "Virtual Machines (PaaS-slojevito upravljanje)", "Nova instance"),
    ("Mreža", "VNet + NSG + ASG + NAT Gateway", "Neutron (network/subnet/router/secgroup)"),
    ("Objektna pohrana", "Blob Storage (potpuno upravljano)", "Swift (dostupan, čeka compute modul)"),
    ("Datotečna pohrana", "Azure Files (SMB)", "Manila (dostupan, čeka compute modul)"),
    ("Load Balancer", "Standard Load Balancer (L4)", "Octavia (dostupan, ali nekonfiguriran na RHA sandboxu)"),
    ("IAM", "Azure AD + RBAC role assignment (slojevito nad postojećim resursima)", "Keystone projekti + role (tenant-scoping, izolacija prije kreiranja resursa)"),
    ("Cijena", "Javno dostupna, po resursu, plaćanje po korištenju", "Bez licence (open source); RHA Academy sandbox besplatan za studente"),
]
for r_ in rows2:
    row = table2.add_row().cells
    for i, val in enumerate(r_):
        row[i].text = val
p("Tablica 2. Usporedba Azure i OpenStack ponude po elementu arhitekture")
p(
    "Zaključak: Azure nudi ujednačeniju, potpuno upravljanu (PaaS) ponudu uz jasnu, javno "
    "dostupnu cijenu po resursu, te je u ovom projektu postignut potpuno funkcionalan "
    "deployment (vidi I4, I5). OpenStack nudi ekvivalentnu funkcionalnost kao open-source "
    "softver bez licencnog troška, no kvaliteta i potpunost konfiguracije pojedinih servisa "
    "(konkretno: Octavia LBaaS na RHA CL110 sandboxu) ovisi o konkretnoj instanci platforme, "
    "što je u ovom projektu i stvarno potvrđeno kroz live testiranje (vidi I2) – Terraform "
    "provider ograničenja (Nova/Cinder/Swift/Manila ne podržavaju project override) dodatno "
    "zahtijevaju drugačiji arhitekturni pristup (project-scoped modul) nego kod Azurea."
)

h2("Konvencija imenovanja resursa")
p("Svi resursi imenuju se prema shemi:")
codeblock("<projekt>-<environment>-<regija>-<uloga>-<identifikator>-<redni-broj>")
p("Primjer (Azure): techsprint-testing-fc-moodle-dev01-01 (Moodle instanca #1 developera "
  "dev01, u regiji France Central). Primjer (OpenStack): techsprint-testing-net-dev01 "
  "(mreža developera dev01).")
p("Iznimka je Azure Storage Account – ime mora biti globalno jedinstveno, isključivo mala "
  "slova i brojevi, bez crtica, do 24 znaka; konvencija se tada primjenjuje bez separatora "
  "(npr. sttechsprinttestingdev01).")

h2("Tag / label strategija")
p("Tagovi project: techsprint i environment: testing obavezni su na svakom resursu koji "
  "podržava tagiranje, definirani na razini IaC modula (Terraform locals) tako da se "
  "automatski primjenjuju na svaki novokreirani resurs, bez ručnog unosa po resursu.")

pagebreak()

# ---------------------------------------------------------------------------
# I2 - OpenStack mreze, pohrana, sigurnost
# ---------------------------------------------------------------------------
h1("I2 – Virtualne mreže, virtualna pohrana i sigurnosni koncepti otvorenog koda")
p("OpenStack mreže, pohrana i sigurnost – 20 bodova. Okolina je razvijena i testirana na Red "
  "Hat Academy CL110 (Red Hat OpenStack Administration I) sandboxu.")
p(
    "Arhitektonska napomena: za razliku od Azurea, gdje mrežni/storage sloj (I4) prethodi RBAC "
    "sloju (I5), na OpenStacku vrijedi obrnut redoslijed – Keystone projekt (tenant) mora "
    "postojati prije nego što se unutar njega mogu kreirati bilo kakvi resursi. Zbog toga "
    "modul openstack-i3-terraform (IAM, poglavlje I3) mora biti primijenjen prije modula "
    "openstack-i2-terraform (mreže/storage/LB, ovo poglavlje)."
)

h2("Dijagram OpenStack arhitekture (3 boda)")
placeholder("OVDJE IDE DIJAGRAM: OpenStack mrežna arhitektura (hub + jump host, izolirane "
            "dev01/dev02 mreže, jump-to-dev bastion portovi, external/provider-datacentre mreža)")

h2("Automatizacija deploymenta bez grešaka (7 bodova)")
p(
    "Deployment je automatiziran kroz Terraform (provider terraform-provider-openstack), "
    "podijeljen u dva modula zbog ograničenja providera opisanog niže: openstack-i3-terraform "
    "(projekti/IAM) i openstack-i2-terraform (mreže/storage/LB). Oba modula stvarno su "
    "primijenjena na RHA sandbox (terraform apply, ne samo terraform plan)."
)
status(
    "openstack-i3-terraform: `terraform apply` → 23 resursa dodano, 0 grešaka. Nezavisno "
    "potvrđeno preko `openstack project list` (techsprint-testing-shared/-dev01/-dev02 "
    "stvarno postoje)."
)
status(
    "openstack-i2-terraform: `terraform apply` → 37 resursa dodano (mreže, subnetovi, "
    "routeri, security grupe, portovi, floating IP), 0 grešaka. Potvrđeno preko "
    "`terraform state list` (37 stavki) i SSH testa na jump host floating IP."
)
p(
    "Ključno tehničko ograničenje otkriveno tijekom razvoja (potvrđeno preko "
    "`terraform providers schema -json`, ne pretpostavkom): resursi "
    "openstack_networking_*, openstack_lb_* i openstack_sharedfilesystem_sharenetwork_v2 "
    "prihvaćaju tenant_id/project_id kao stvarno postavljiv atribut (optional+computed), "
    "što administratorskom Terraform provideru omogućuje kreiranje resursa \"u ime\" drugog "
    "projekta unutar jednog for_each-baziranog apply-a. Resursi "
    "openstack_compute_instance_v2 (Nova), openstack_blockstorage_volume_v3 (Cinder), "
    "openstack_objectstorage_container_v1 (Swift) i openstack_sharedfilesystem_share_v2 "
    "(Manila) TU mogućnost nemaju (project_id je computed-only, čak i kad se atribut nalazi "
    "u shemi) – moraju se kreirati preko providera koji je autenticiran izravno u ciljani "
    "projekt. Kako Terraform provider blokovi ne podržavaju for_each/count, ti resursi "
    "planirani su u zaseban, po-developeru parametriziran modul (openstack-compute-terraform, "
    "u izradi), koji CSV orkestracijska skripta primjenjuje jednom po developeru, s "
    "OS_PROJECT_NAME prebačenim prije svakog poziva."
)

h3("Hub mreža i jump host (network.tf)")
codeblock(read_lines("openstack-i2-terraform/network.tf", 1, 101), "openstack-i2-terraform/network.tf")

h3("Izolirane developer mreže")
codeblock(read_lines("openstack-i2-terraform/network.tf", 103, 143), "openstack-i2-terraform/network.tf")

h2("Implementiran load balancer (3 boda)")
p(
    "Octavia LBaaS implementiran je u kodu (openstack-i2-terraform/loadbalancer.tf) i "
    "stvarno je testiran live-em protiv RHA sandboxa. Rezultat: oba LB-a (dev01, dev02) "
    "završila su u provisioning_status=ERROR nakon internog Terraform timeouta (~10 min). "
    "Dijagnoza je provedena izravno preko openstack CLI-ja, ne samo Terraform poruka o grešci:"
)
bullets([
    "`openstack loadbalancer amphora list` – prazan rezultat, znači da Octavia nikad nije "
    "ni pokušala kreirati amphora Nova instancu.",
    "`openstack flavor list` – ne postoji nijedan flavor namijenjen amphora VM-u (samo "
    "default/default-swap/default-extra-disk), što upućuje da Octavia-in `amp_flavor_id` "
    "u octavia.conf pokazuje na flavor koji na ovom sandboxu ne postoji.",
    "Servis JEST prisutan u service katalogu (`openstack service list` prikazuje octavia/"
    "load-balancer), ali očito nije potpuno konfiguriran – razumljivo, s obzirom na to da "
    "CL110 kolegij (na kojem se RHA sandbox temelji) ne pokriva load balancing kao nastavnu "
    "temu.",
])
p(
    "Errorirani LB resursi uklonjeni su iz cloud infrastrukture i Terraform state-a "
    "(`terraform destroy -refresh=false`, potrebno jer je Octavia sama već obrisala VIP port "
    "nakon vlastitog neuspjeha, pa je običan destroy s refresh-om pucao na 404). Kod ostaje u "
    "repozitoriju kao ispravna implementacija za pravi RHOSP s konfiguriranom Octaviom, "
    "aktivacija je iza varijable enable_octavia_lb (default false), s dokumentiranim razlogom "
    "u komentaru koda."
)
status("implementacija u kodu gotova i live-testirana; servis nefunkcionalan na RHA CL110 "
       "sandboxu iz razloga koji nije u dosegu ovog projekta (server-side konfiguracija "
       "Octavije nije nešto što student može popraviti bez potpunog admin pristupa "
       "controller0 čvoru dijeljene classroom instance).", done=False)
codeblock(read("openstack-i2-terraform/loadbalancer.tf"), "openstack-i2-terraform/loadbalancer.tf")

h2("Kreirana i mountana dva diska za svaku instancu (1 bod)")
status(
    "Cinder data disk (drugi disk uz OS disk) planiran je u compute modulu "
    "(openstack_blockstorage_volume_v3 + openstack_compute_volume_attach_v2), iz istog "
    "razloga project-scoping ograničenja opisanog gore – kod još nije napisan.", done=False
)

h2("Mount objektne/datotečne pohrane uz least-privilege princip (2 boda)")
status(
    "Swift kontejner i Manila share/share-access planirani su u compute modulu (iz istog "
    "razloga – project_id nije postavljiv na tim resursima preko admin providera). Prvotna "
    "verzija Manila share-a (sharenetwork + share + access, s pristupom ograničenim samo na "
    "vlastitu dev subnet CIDR mrežu) bila je napisana u openstack-i2-terraform, ali je "
    "uklonjena nakon što je terraform validate otkrio da openstack_sharedfilesystem_share_v2 "
    "ima project_id kao computed-only atribut (isti uzrok kao Nova/Cinder/Swift).", done=False
)

h2("Security grupe za dev/lead role (1 bod)")
p(
    "Jump host ima vlastitu security grupu (SSH dopušten samo s konfigurabilnog vanjskog "
    "CIDR-a), DevOps Lead VM ima SSH dopušten samo iz hub mreže (tj. samo preko jump hosta), "
    "svaka developer mreža ima vlastitu security grupu (SSH i HTTP dopušteni samo unutar "
    "vlastite izolirane CIDR mreže – vidi kod niže). Sve stvarno primijenjeno (dio 37 "
    "resursa u I2 apply-u)."
)
codeblock(read_lines("openstack-i2-terraform/network.tf", 165, 202), "openstack-i2-terraform/network.tf")

h2("Mrežna izolacija – samo jump host javan, svaki dev ima svoju mrežu (2 boda)")
p(
    "Svaka developer mreža potpuno je izolirana (zaseban Neutron L2 segment), router ima "
    "vanjski gateway isključivo radi SNAT internet izlaza (dev instance nemaju floating IP, "
    "nisu javno dostupne). Jump host je jedina javno dostupna točka ulaza (floating IP), "
    "i dobiva dodatni port na SVAKOJ developer mreži – drugi NIC koji služi isključivo kao "
    "izvor odlaznog SSH-a prema toj mreži. Dvije developer mreže nikad nisu međusobno "
    "L2/L3 povezane – jedini zajednički element je jump host, koji ima poseban port u svakoj "
    "od njih, analogno Azure hub-spoke VNet peeringu, samo bez samog peeringa."
)
codeblock(read_lines("openstack-i2-terraform/network.tf", 204, 221), "openstack-i2-terraform/network.tf")

h2("Objašnjenje specifičnih mrežnih postavki (1 bod)")
p(
    "Vanjska (\"provider\") mreža na RHA CL110 sandboxu zove se provider-datacentre i ima "
    "stvarni uplink na internet neovisan o classroom \"workstation\" NAT-u koji koriste "
    "ostale nastavne VM-ove. Svaka developer subnet mreža koristi CIDR 10.11.<indeks>.0/24 "
    "(treći oktet = redni broj developera), hub mreža koristi 10.10.0.0/24. DNS za sve "
    "privatne subnetove postavljen je na javne resolvere (8.8.8.8, 1.1.1.1), neovisno o "
    "internom DNS-u classroom mreže, kako bi developer okoline bile potpuno samostalne."
)

pagebreak()

# ---------------------------------------------------------------------------
# I3 - OpenStack IAM
# ---------------------------------------------------------------------------
h1("I3 – Administracija instanci, korisnika, grupa, profila i aplikacija otvorenog koda")
p("OpenStack IAM – 20 bodova.")

h2("Dijagram IAM strukture (3 boda)")
placeholder("OVDJE IDE DIJAGRAM: OpenStack IAM struktura (Keystone projekti shared/dev01/dev02, "
            "korisnici, role techsprint_developer + member/admin, dodjele po projektu)")

h2("Automatizacija IAM deploymenta (7 bodova)")
p(
    "IAM sloj implementiran je u openstack-i3-terraform i mora se primijeniti PRIJE mrežnog "
    "sloja (I2) jer OpenStack projekt (tenant) mora postojati prije bilo kojeg resursa unutar "
    "njega – suprotno od Azure RBAC-a, koji se slojevito dodaje na već postojeće resurse."
)
status("`terraform apply` → 23 resursa dodano, 0 grešaka. Nezavisno potvrđeno preko "
       "`openstack project list`.")
p(
    "Za razliku od Azurea, gdje dijeljeni fakultetski AAD tenant onemogućuje kreiranje novih "
    "korisnika preko API-ja (vidi I5), na RHA sandboxu smo puni cloud admin na VLASTITOJ "
    "izoliranoj instanci, pa Terraform stvarno kreira Keystone korisnika po developeru, s "
    "generiranom lozinkom (random_password, izlaz označen kao sensitive)."
)
codeblock(read("openstack-i3-terraform/projects.tf"), "openstack-i3-terraform/projects.tf")
codeblock(read("openstack-i3-terraform/users.tf"), "openstack-i3-terraform/users.tf")

h3("Ključna razlika od Azure RBAC modela")
p(
    "OpenStack Keystone role su samo imenovane labele – stvarna autorizacija provjerava se "
    "kroz oslo.policy pravila po svakom servisu (nova/neutron/cinder policy.json), a default "
    "RHOSP politike prepoznaju isključivo ugrađena imena rola (member/admin/reader), ne "
    "proizvoljna custom imena. Zato je custom rola \"techsprint_developer\" dodijeljena UZ "
    "ugrađenu \"member\" rolu – prva služi za čitljivost u IAM dijagramu i audit trag, druga "
    "stvarno provodi self-service compute/network/storage prava unutar scope-a projekta. "
    "Fino-zrnata kontrola u stilu Azurea (npr. \"smije start/stop, ne smije delete\") "
    "zahtijevala bi izmjenu policy.json na controller0 čvoru – izvediva jer smo puni admin na "
    "vlastitoj classroom instanci, ali namjerno izostavljena zbog rizika da pogrešna izmjena "
    "policy.json sruši cijeli RHOSP control plane; project-scoping sam po sebi već zadovoljava "
    "ključni zahtjev zadatka (developer nema nikakav pristup tuđem projektu, ne samo "
    "ograničena prava unutar njega)."
)
codeblock(read("openstack-i3-terraform/roles.tf"), "openstack-i3-terraform/roles.tf")
codeblock(read("openstack-i3-terraform/assignments.tf"), "openstack-i3-terraform/assignments.tf")

h2("Instance sa zadanim specifikacijama, 2 vCPU/4GB (1 bod)")
status("Custom flavor (4096 MB RAM / 2 vCPU) i same Nova instance planirane su u "
       "openstack-compute-terraform modulu (u izradi) – vidi objašnjenje project-scoping "
       "ograničenja u I2.", done=False)

h2("Korisnici kreirani putem CSV-a, smješteni u grupe s točnim rolama (3 boda)")
p(
    "Terraform varijabla var.developers (lista objekata {id, name}) ima identičnu strukturu "
    "kao istoimena varijabla u Azure modulima, čime je infrastruktura pripremljena za CSV "
    "izvor – u produkciji tu listu generira scripts/provision.py, koja trenutno pokriva Azure "
    "tok (I4/I5). Proširenje provision.py da generira i "
    "openstack-i3-terraform/csv_generated.auto.tfvars analognim postupkom kao za Azure "
    "planirano je za sljedeći korak, prije finalne predaje."
)
status("Terraform infrastruktura podržava varijabilan broj korisnika iz CSV-podataka "
       "(dokazano radom istog uzorka za Azure); izravna CSV→OpenStack integracija u "
       "scripts/provision.py još nije napisana.", done=False)

h2("Power state kontrola za developere – samo vlastiti resursi (2 boda)")
p(
    "Developer dobiva rolu member SAMO na vlastitom projektu (assignments.tf iznad). Keystone "
    "project-scoping znači da se developer ne može čak ni autenticirati u tuđi projekt – "
    "pokušaj dohvata tokena za tuđi projekt vraća 401/403 na razini Keystone servisa, prije "
    "nego što bilo koji Nova/Cinder poziv uopće dođe do reda. Stvarni Nova start/stop pozivi "
    "(power-state) bit će mogući nakon što compute modul kreira instance – trenutno je "
    "provjerena i primijenjena sama IAM izolacija (RBAC dodjele), ne i krajnja funkcionalna "
    "provjera preko prijave kao developer korisnik."
)
status("IAM izolacija primijenjena i strukturno ispravna; end-to-end funkcionalni test "
       "(prijava kao developer, pokušaj start/stop tuđe instance) čeka compute modul.", done=False)

h2("Voditelj ima kontrolu nad svim resursima (1 bod)")
p(
    "DevOps Lead dobiva rolu member na shared projektu (vlastiti prostor za jump/lead VM) i "
    "ugrađenu rolu admin na SVAKOM developer projektu – analogno Azure roli \"Virtual Machine "
    "Contributor\" dodijeljenoj na razini cijele subscription."
)
status("Primijenjeno i potvrđeno kroz `openstack role assignment list`.")

h2("Odvojeni projekti/tenanti za izolaciju (1 bod)")
p(
    "Tri odvojena Keystone projekta (techsprint-testing-shared, -dev01, -dev02) stvarno "
    "postoje na RHA sandboxu, uz zadržane postojeće kursne projekte (admin, finance, "
    "production, service) koji nisu dirani."
)
status("Primijenjeno i potvrđeno kroz `openstack project list`.")

h2("Infrastruktura za min. 2 developera + 1 voditelja (2 boda)")
p(
    "IAM sloj (projekti, korisnici, kvote, role) potpuno je pripremljen i primijenjen za "
    "scenarij 2 developera + 1 lead. Mrežni sloj (I2) također je primijenjen za isti scenarij. "
    "Preostaje compute sloj (Nova instance) da bi scenarij bio funkcionalno kompletan – vidi "
    "napomenu o project-scoping ograničenju u I2."
)
status("IAM + mreže gotovi za 2 dev + 1 lead; compute (VM-ovi) u izradi.", done=False)

pagebreak()

# ---------------------------------------------------------------------------
# I4 - Azure mreze i pohrana
# ---------------------------------------------------------------------------
h1("I4 – Virtualne mreže i pohrana Microsoft tehnologija")
p("Azure mreže i pohrana – 20 bodova. Okolina je u potpunosti razvijena i live testirana na "
  "stvarnoj Azure pretplati (Azure for Students).")

h2("Dijagram Azure arhitekture (3 boda)")
placeholder("OVDJE IDE DIJAGRAM: docs/i4-azure-architecture.svg (hub Poland Central s jump/"
            "lead VM-ovima, spoke mreže dev01 France Central i dev02 Sweden Central, peering "
            "hub↔spoke, bez spoke↔spoke peeringa)")

h2("Automatizacija deploymenta bez grešaka (7 bodova)")
p(
    "Cijela okolina automatizirana je kroz azure-i4-terraform (mreže, storage, VM-ovi, LB) i "
    "azure-i5-rbac-terraform (RBAC). Deployment je stvarno primijenjen (terraform apply) i "
    "konfiguriran Ansibleom (mount storage + Moodle instalacija) – potvrđeno funkcionalnim "
    "Moodle 5.1 instancama na sve 4 aplikacijske VM (2 developera × 2 HA instance), testirano "
    "preko curl-a (HTTP 200 na /login/index.php kroz interni Load Balancer)."
)
status(
    "Arhitektura je multi-regionalna (hub u Poland Central, dev01 u France Central, dev02 u "
    "Sweden Central) jer subscription kvota (\"Total Regional vCPUs\") ne dopušta puni hub + "
    "HA par u istoj regiji na studentskoj pretplati."
)

h3("Mrežna izolacija – hub, jump host, spoke po developeru")
codeblock(read_lines("azure-i4-terraform/network.tf", 1, 62), "azure-i4-terraform/network.tf")

h3("NAT Gateway – izlaz na internet bez javnog IP-a na Moodle VM-ovima")
codeblock(read_lines("azure-i4-terraform/network.tf", 64, 129), "azure-i4-terraform/network.tf")

h2("Usporedba Load Balancera (Azure LB vs Application Gateway) (2 boda)")
p(
    "Za ovaj scenarij (Moodle HA par unutar jedne izolirane mreže) korišten je Standard "
    "Internal Load Balancer. Application Gateway je Layer 7 (HTTP/HTTPS) reverse proxy s "
    "naprednim značajkama poput WAF-a, URL-based routinga i SSL terminacije – koristan kad je "
    "potrebno usmjeravati promet prema više različitih backend skupova na temelju sadržaja "
    "zahtjeva, ili kad je potreban WAF ispred javno izložene aplikacije. Standard Load Balancer "
    "je Layer 4 (TCP/UDP) uređaj, jeftiniji i jednostavniji, dovoljan kad je cilj samo "
    "raspodijeliti promet između identičnih instanci iste aplikacije unutar privatne mreže – "
    "što je točno slučaj ovdje (2 identične Moodle instance, bez potrebe za L7 značajkama, bez "
    "javne izloženosti jer je pristup isključivo kroz jump host). Application Gateway bi bio "
    "opravdan izbor kad bi Moodle bio izravno izložen internetu (npr. u produkcijskom, ne "
    "testnom, okruženju) radi WAF zaštite."
)

h2("Storage Accounti – Blob za objekte, Files za datoteke (1 bod)")
p(
    "Po developeru se kreira jedan Storage Account s Blob kontejnerom (moodledata, objektna "
    "pohrana Moodle datoteka) i Azure Files share-om (backups, datotečna pohrana backupa). "
    "Mrežni pristup ograničen je isključivo na vlastiti spoke subnet i IP adresu osobe koja "
    "pokreće deployment (least-privilege na razini mreže, ne samo IAM-a)."
)
codeblock(read("azure-i4-terraform/storage.tf"), "azure-i4-terraform/storage.tf")

h2("Dva Managed diska po instanci (1 bod)")
p(
    "Svaka Moodle VM ima OS disk (definiran unutar VM resursa) i zaseban data disk "
    "(azurerm_managed_disk + azurerm_virtual_machine_data_disk_attachment), oba Standard SSD "
    "(LRS), fizički odvojena radi izolacije I/O-a baze podataka od OS diska."
)
codeblock(read_lines("azure-i4-terraform/vm.tf", 190, 210), "azure-i4-terraform/vm.tf")

h2("Pohrana montirana uz Managed Identity / SAS tokene (2 boda)")
p(
    "Svaka Moodle VM ima System-Assigned Managed Identity kojoj je dodijeljena rola \"Storage "
    "Blob Data Contributor\" scoped isključivo na vlastiti Storage Account (ne na cijelu "
    "pretplatu) za pristup Blob objektnoj pohrani – bez ključeva na disku. Azure Files (SMB) "
    "ne podržava izravnu Managed Identity autentikaciju, pa VM identity ima rolu \"Key Vault "
    "Secrets User\" scoped na vlastiti Key Vault, iz kojeg Ansible dohvaća storage account "
    "ključ u trenutku mountanja (ključ se ne sprema trajno na disk niti u Terraform state kao "
    "plaintext izvan Key Vaulta)."
)
codeblock(read_lines("azure-i4-terraform/vm.tf", 212, 230), "azure-i4-terraform/vm.tf")

h2("NSG i ASG (1 bod)")
p(
    "Application Security Group (ASG) grupira mrežne kartice svih Moodle VM-ova po "
    "developeru, što omogućuje da se NSG pravila pišu prema ulozi (\"promet prema Moodle "
    "grupi\") umjesto prema pojedinačnim IP adresama, koje bi se mijenjale sa svakim novim "
    "VM-om."
)
codeblock(read_lines("azure-i4-terraform/network.tf", 140, 193), "azure-i4-terraform/network.tf")

h2("Mrežna izolacija (VNet po korisniku), javni IP samo na jump hostu (2 boda)")
p(
    "Svaki developer ima vlastiti spoke VNet, peered isključivo s hub VNet-om (nikad "
    "spoke-spoke), čime je zajamčeno da developeri međusobno ne mogu komunicirati na mrežnoj "
    "razini, čak i kad bi netko slučajno pokušao – peering prema drugom developeru jednostavno "
    "ne postoji."
)
codeblock(read_lines("azure-i4-terraform/network.tf", 195, 224), "azure-i4-terraform/network.tf")

h2("Objašnjenje Azure mrežnih postavki (1 bod)")
p(
    "Hub VNet koristi CIDR definiran varijablom hub_vnet_cidr (10.20.0.0/24), podijeljen u "
    "dva /27 subnetа (jump, lead). Svaki spoke VNet koristi treći oktet jednak rednom broju "
    "developera (10.21.<indeks>.0/24), Moodle subnet unutar njega ima omogućen "
    "service endpoint za Microsoft.Storage (izravan, privatan pristup Storage Accountu bez "
    "prolaska kroz javni internet, čak i kad je promet inicijalno usmjeren na javni endpoint "
    "storage servisa)."
)

pagebreak()

# ---------------------------------------------------------------------------
# I5 - Azure IAM/RBAC
# ---------------------------------------------------------------------------
h1("I5 – Administriranje instanci, korisnika, grupa i profila na temelju Microsoftovih tehnologija")
p("Azure IAM/RBAC – 20 bodova. RBAC sloj testiran je s PRAVIM Azure AD računima kolega "
  "(ne fiktivnim ni istim računom za sve uloge), kroz Azure Portal značajku \"Check access\".")

h2("Dijagram Azure RBAC modela (3 boda)")
placeholder("OVDJE IDE DIJAGRAM: Azure RBAC model (subscription → Resource Group hijerarhija, "
            "custom rola TechSprint Developer scoped na vlastiti RG, ugrađena Virtual Machine "
            "Contributor za leada scoped na subscription)")

h2("Automatizacija deploymenta IAM resursa (7 bodova)")
p(
    "RBAC sloj implementiran je u azure-i5-rbac-terraform, namjerno odvojenom Terraform "
    "modulu od azure-i4-terraform (mreže/VM-ovi), povezanom preko data source lookupa po "
    "imenu resource groupe (ne remote state ovisnošću), radi jasne odvojenosti odgovornosti "
    "(mrežni/storage inženjering vs. IAM)."
)
status(
    "`terraform apply` primijenjen; funkcionalnost potvrđena kroz Azure Portal \"Check "
    "access\" na PRAVIM AAD računima kolega (Ivan Majpruz, Andrija Marić) – potvrđeno da svaki "
    "developer ima dodijeljenu rolu ISKLJUČIVO na vlastitom Resource Groupu, a ne i na "
    "Resource Groupu drugog developera."
)

h3("Custom i ugrađena rola")
p(
    "Zahtjev rubrike (\"custom ili ugrađene role\") demonstriran je s oba pristupa istovremeno: "
    "developer dobiva CUSTOM rolu s namjerno uskim opsegom akcija (samo power-state i "
    "read-only, bez prava mijenjanja mreže/pohrane/drugih resursa), dok DevOps Lead dobiva "
    "UGRAĐENU rolu \"Virtual Machine Contributor\" (šire ovlasti, uključujući redeploy, ali "
    "i dalje bez prava na mrežu/pohranu/Key Vault izvan onoga što ta ugrađena rola dopušta)."
)
codeblock(read("azure-i5-rbac-terraform/roles.tf"), "azure-i5-rbac-terraform/roles.tf")

h2("Ispravne veličine instanci, npr. B2s (1 bod)")
p(
    "Standard_B2s_v2 (2 vCPU / 4 GiB RAM) korišten je za sve VM-ove (jump, lead, Moodle), "
    "burstable serija prikladna za testnu okolinu s povremenim opterećenjem – vidi I1 za "
    "detaljno obrazloženje odabira nad alternativama poput D2s_v3."
)

h2("Custom/built-in role s minimalnim pravima (2 boda)")
p(
    "Vidi \"Custom i ugrađena rola\" iznad. Custom rola developera eksplicitno isključuje "
    "prava pisanja na mrežu, pohranu i Key Vault (not_actions/actions ograničeni na "
    "power-state + read), što je strože od ugrađene \"Virtual Machine Contributor\" role "
    "koja bi developeru dopustila i brisanje/redeploy VM-ova."
)

h2("Start/Deallocate isključivo nad vlastitim resursima (2 boda)")
p(
    "Role assignment developera scoped je na razini POJEDINAČNOG Resource Groupa (vlastiti "
    "developer RG), ne na razini subscription – Azure RBAC provjerava scope dodjele neovisno "
    "o mrežnoj izolaciji (I4), pa developer ne može pozvati start/stop na resurse u tuđem RG-u "
    "čak ni kad bi mrežno mogao doći do njih."
)
codeblock(read("azure-i5-rbac-terraform/assignments.tf"), "azure-i5-rbac-terraform/assignments.tf")

h2("Voditelj upravlja svim VM-ovima kroz Bastion/Jump host (2 boda)")
p(
    "DevOps Lead dobiva ugrađenu rolu \"Virtual Machine Contributor\" na razini CIJELE "
    "subscription (obuhvaća shared RG + sve developer RG-ove, uključujući buduće ako ih CSV "
    "skripta doda) – na razini Azure API/portala. SSH pristup na razini mreže već je "
    "omogućen u I4 (NSG dopušta SSH s hub CIDR-a na sve spoke mreže), što je odvojena, "
    "komplementarna kontrola od ove RBAC dodjele."
)

h2("Logična hijerarhija Resource Grupa (1 bod)")
p(
    "Jedan shared Resource Group (jump host, DevOps Lead VM) i po jedan Resource Group po "
    "developeru (Moodle VM-ovi, storage account, key vault, mreža), imenovani prema istoj "
    "konvenciji kao ostali resursi (I1). Ova granularnost izravno omogućava RBAC scoping "
    "opisan iznad – developer role assignment jednostavno cilja točno jedan RG."
)

h2("Infrastruktura za min. 2 developera + 1 voditelja (2 boda)")
p(
    "Testirano s 2 developera (dev01, dev02) + 1 DevOps Lead, koristeći stvarne, postojeće "
    "Azure AD račune (ne fiktivne), potvrđeno Azure Portal \"Check access\" značajkom."
)
status("Potpuno primijenjeno i funkcionalno testirano.")

pagebreak()

# ---------------------------------------------------------------------------
# Prilog: CSV provisioning skripta (zajednicka automatizacija za I3/I4/I5)
# ---------------------------------------------------------------------------
h1("Prilog: CSV provisioning skripta")
p(
    "Zadatak zahtijeva skriptu koja prima CSV datoteku (ime;prezime;rola) i kreira "
    "infrastrukturu za varijabilan broj korisnika, pokrenutu jednom (orkestrirano, ne ručno "
    "više puta). scripts/provision.py trenutno u potpunosti pokriva Azure tok (I4 mreže/"
    "storage/VM + I5 RBAC + Ansible Moodle instalacija) – testirano s pravim CSV-om "
    "(2 developera + 1 lead, stvarna imena, stvarni Azure AD object_id-evi dohvaćeni preko "
    "`az ad user list`). Proširenje za OpenStack (I2/I3) planirano je za sljedeći korak – "
    "arhitektura Terraform varijabli (var.developers) već je identična strukture na oba "
    "oblaka upravo radi ove buduće integracije."
)
status(
    "Skripta ne kreira nove identitete (ni na Azureu ni na OpenStacku po planu) – dohvaća "
    "postojeće korisnike po imenu i dodjeljuje im pristup, jer fakultetski Azure AD tenant ne "
    "dopušta kreiranje novih korisnika preko API-ja. Na OpenStacku (vlastita RHA instanca, "
    "puni admin) ograničenje ne postoji, pa I3 Terraform modul stvarno kreira nove Keystone "
    "korisnike – vidi I3."
)
p("Parsiranje CSV-a i dodjela regija developerima:")
codeblock(read_lines("scripts/provision.py", 56, 85), "scripts/provision.py (parse_csv)")
p("Orkestracija cijelog pipelinea jednim pokretanjem:")
codeblock(read_lines("scripts/provision.py", 216, 261), "scripts/provision.py (main)")

pagebreak()

# ---------------------------------------------------------------------------
# ZAKLJUCAK
# ---------------------------------------------------------------------------
h1("Zaključak")
p(
    "Projekt je uspješno demonstrirao izradu automatizirane, izolirane multi-cloud testne "
    "okoline za TechSprint agenciju. Azure implementacija (I4, I5) u potpunosti je "
    "funkcionalna i live testirana – mrežna izolacija, RBAC, storage i Moodle instalacija "
    "rade prema specifikaciji za scenarij 2 developera + 1 DevOps Lead. OpenStack "
    "implementacija (I2, I3) funkcionalna je na razini mreža, sigurnosti i IAM-a (60 stvarno "
    "primijenjenih Terraform resursa na RHA sandboxu), uz otvoren compute sloj (Nova/Cinder/"
    "Swift/Manila) čije je odgađanje posljedica konkretnog, dokumentiranog tehničkog "
    "ograničenja Terraform providera, ne propusta u planiranju."
)
p(
    "Posebno je vrijedno istaknuti da su gotovo sve tvrdnje u ovom dokumentu potkrijepljene "
    "stvarnim, live testiranjem protiv pravih cloud API-ja (Azure i OpenStack), uključujući "
    "slučajeve gdje je test otkrio genuine kvarove (Octavia LB na RHA sandboxu) koji su "
    "dijagnosticirani do korijenskog uzroka, a ne samo zaobiđeni."
)
p("Sljedeći koraci prije finalne predaje:")
bullets([
    "Dovršetak openstack-compute-terraform modula (Nova instance, Cinder diskovi, Swift "
    "kontejneri, Manila share-ovi) i njegova integracija u CSV orkestraciju.",
    "Proširenje scripts/provision.py da generira i OpenStack tfvars, analogno postojećem "
    "Azure toku.",
    "Izrada preostalih dijagrama arhitekture (OpenStack mreže, OpenStack IAM, Azure RBAC).",
    "Zamjena placeholder lozinki u Ansible konfiguraciji stvarnim, jakim lozinkama.",
    "Snimka izvršavanja cjelokupnog deploymenta (YouTube, privatno) s objašnjenjem.",
])

# ---------------------------------------------------------------------------
# REFERENCE
# ---------------------------------------------------------------------------
h1("Reference")
bullets([
    "[1] Microsoft Azure Documentation – Virtual Networks, https://learn.microsoft.com/azure/virtual-network/",
    "[2] Microsoft Azure Documentation – Azure Role-Based Access Control (RBAC), "
    "https://learn.microsoft.com/azure/role-based-access-control/",
    "[3] OpenStack Documentation – Neutron Networking Guide, https://docs.openstack.org/neutron/latest/",
    "[4] OpenStack Documentation – Keystone Identity Service, https://docs.openstack.org/keystone/latest/",
    "[5] OpenStack Documentation – Octavia Load Balancing, https://docs.openstack.org/octavia/latest/",
    "[6] Terraform Registry – hashicorp/azurerm Provider, https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs",
    "[7] Terraform Registry – terraform-provider-openstack/openstack Provider, "
    "https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs",
    "[8] Moodle Developer Documentation – Installing Moodle, https://docs.moodle.org/500/en/Installing_Moodle",
    "[9] Red Hat Academy – CL110: Red Hat OpenStack Administration I: Core Operations for Domain Operators.",
])

doc.save(OUT)
print("DONE. Saved:", OUT)
