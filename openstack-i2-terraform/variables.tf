variable "project_name" {
  description = "Naziv projekta, koristi se u konvenciji imenovanja i tagovima (isto kao Azure I4/I5)."
  type        = string
  default     = "techsprint"
}

# ---------------------------------------------------------------------------
# Octavia servis JE prisutan u katalogu (potvrdjeno service list), ali na RHA
# CL110 sandboxu nije potpuno konfiguriran - LB kreiranje zavrsava u ERROR
# statusu jer se nikad ne pokrene ni jedna amphora Nova instanca (potvrdjeno:
# `openstack server list --all-projects | grep amphora` prazno, `openstack
# flavor list` nema amphora flavor - Octavia-in amp_flavor_id u octavia.conf
# vjerojatno pokazuje na obrisan/nepostojeci flavor). Ocekivano, jer CL110
# kolegij uopce ne pokriva load balancing kao temu. Kod ostaje ispravan i
# spreman za pravi RHOSP s ispravno konfiguriranom Octaviom - samo je default
# iskljucen da apply ne pukne na ovom sandboxu. Vidi CLAUDE.md za puni nalaz.
# ---------------------------------------------------------------------------
variable "enable_octavia_lb" {
  description = "Kreiraj Octavia LB (loadbalancer.tf). Default false - vidi napomenu iznad (potvrdjeno ERROR na RHA CL110 sandboxu, amp_flavor_id nedostaje)."
  type        = bool
  default     = false
}

variable "environment" {
  description = "Naziv okoline."
  type        = string
  default     = "testing"
}

variable "external_network_name" {
  description = "Vanjska/provider mreza s izlazom na internet (RHA CL110 lab: 'provider-datacentre')."
  type        = string
  default     = "provider-datacentre"
}

# ---------------------------------------------------------------------------
# Postojeca RHA "provider" (fizicki mapirana) mreza na kojoj sjedi Ceph mon
# backend (172.24.3.0/24, potvrdjeno live 9.9.2026: `openstack network show`
# -> shared=True, router:external=False). Manila CephFS kernel klijent na
# Moodle instancama treba DIREKTAN L2 pristup ovoj mrezi - vidi napomenu uz
# openstack_networking_port_v2.moodle_storage u network.tf zasto obicno
# rutiranje kroz dev router ne radi (asimetricna ruta).
# ---------------------------------------------------------------------------
variable "storage_network_name" {
  description = "Naziv postojece RHA storage/Ceph mreze (provider-storage) - Moodle instance dobivaju drugi NIC izravno na ovu mrezu radi Manila CephFS mounta."
  type        = string
  default     = "provider-storage"
}

variable "image_name" {
  description = "OS image za sve VM-ove. Rocky Linux/CentOS nije dostupan na RHA CL110 sandboxu - koristi se rhel8 (dostupan, cloud-specijalizirana distribucija po zahtjevu zadatka)."
  type        = string
  default     = "rhel8"
}

variable "lead" {
  description = "Podaci o DevOps Lead korisniku."
  type = object({
    name = string
  })
  default = {
    name = "Ana Anic"
  }
}

variable "developers" {
  description = "Popis developera. 'id' se koristi u imenovanju resursa i OpenStack projektu (npr. techsprint-dev01), 'name' za owner tag. U produkciji ovu listu generira CSV provisioning skripta (scripts/provision.py, isto kao za Azure)."
  type = list(object({
    id   = string
    name = string
  }))
  default = [
    { id = "dev01", name = "Luka Lukic" },
    { id = "dev02", name = "Ivan Ivic" },
  ]
}

variable "moodle_instances_per_dev" {
  description = "Broj Moodle VM instanci po developeru (2 = HA par po zahtjevu zadatka)."
  type        = number
  default     = 2
}

variable "admin_username" {
  description = "Admin korisnicko ime za sve Linux VM-ove (RHEL8 cloud image - obicno koristi cloud-init generic user, provjeri stvarni default korisnika image-a prije apply-a)."
  type        = string
  default     = "cloud-user"
}

variable "admin_ssh_public_key" {
  description = "Javni SSH kljuc za pristup VM-ovima. Nema default vrijednost namjerno - mora se proslijediti kroz terraform.tfvars."
  type        = string
}

variable "jump_host_allowed_ssh_cidr" {
  description = "CIDR raspon s kojeg je dopusten SSH na jump host (vanjski floating IP). Ogranici na svoju javnu IP adresu prije stvarnog deploymenta - ali napomena: unutar RHA lab-a jedini put do jump hosta je preko workstation VNC-a, pa '0.0.0.0/0' moze ostati ako se pristupa iskljucivo iz classroom mreze."
  type        = string
  default     = "0.0.0.0/0"
}

variable "hub_network_cidr" {
  description = "CIDR bloka hub mreze (jump host + DevOps Lead)."
  type        = string
  default     = "10.10.0.0/24"
}

variable "dev_network_cidr_prefix" {
  description = "Prefiks za CIDR mreza po developeru. Treci oktet se popunjava indeksom developera (10.11.<index>.0/24)."
  type        = string
  default     = "10.11"
}

variable "dns_nameservers" {
  description = "DNS serveri za sve privatne subnetove (javni resolveri, neovisno o RHA classroom internom DNS-u)."
  type        = list(string)
  default     = ["8.8.8.8", "1.1.1.1"]
}

# ---------------------------------------------------------------------------
# Custom flavor - postojeci RHA flavori (default/default-swap/default-extra-disk)
# su svi 2048MB RAM / 2 vCPU, task zahtjeva 4GB RAM / 2 vCPU. OS disk ide kroz
# flavor 'disk', data disk je zaseban Cinder volume (vidi compute.tf).
# ---------------------------------------------------------------------------
variable "vm_flavor_vcpus" {
  description = "vCPU za aplikacijske (Moodle), jump i lead VM-ove."
  type        = number
  default     = 2
}

variable "vm_flavor_ram_mb" {
  description = "RAM (MB) za sve VM-ove (4096 = 4GB po zahtjevu zadatka)."
  type        = number
  default     = 4096
}

variable "vm_flavor_disk_gb" {
  description = "OS disk (GB) - dio flavora, prvi od 2 diska po zahtjevu zadatka."
  type        = number
  default     = 20
}

variable "data_disk_size_gb" {
  description = "Velicina data diska (GB) - zaseban Cinder volume, drugi od 2 diska po zahtjevu zadatka (Moodle VM-ovi)."
  type        = number
  default     = 20
}
