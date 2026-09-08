variable "project_name" {
  description = "Naziv projekta, koristi se u konvenciji imenovanja i tagovima."
  type        = string
  default     = "techsprint"
}

variable "environment" {
  description = "Naziv okoline, koristi se u konvenciji imenovanja i tagovima."
  type        = string
  default     = "testing"
}

variable "location" {
  description = "Azure regija za HUB (jump host + DevOps Lead). Ograničeno Azure Policy-jem subscriptiona (Allowed resource deployment regions) na: polandcentral, francecentral, germanywestcentral, spaincentral, swedencentral. Svaki developer ima SVOJU regiju (vidi var.developers) – razlog: 6 vCPU total-regional kvota po regiji na ovoj subscription ne dozvoljava hub + puni HA par u istoj regiji, pa se opterećenje razdvaja preko regija."
  type        = string
  default     = "polandcentral"
}

variable "location_abbr" {
  description = "Kratica HUB regije za konvenciju imenovanja shared resursa (npr. plc za Poland Central)."
  type        = string
  default     = "plc"
}

variable "region_abbr" {
  description = "Mapiranje Azure regije -> kratica za konvenciju imenovanja, koristi se za developer-specific resurse (koji mogu biti u drugoj regiji od huba)."
  type        = map(string)
  default = {
    polandcentral      = "plc"
    francecentral      = "fc"
    germanywestcentral = "gwc"
    spaincentral       = "spc"
    swedencentral      = "sc"
  }
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
  description = "Popis developera. 'id' se koristi u imenovanju resursa (npr. dev01), 'name' za owner tag, 'location' je regija u kojoj se kreira NJEGOVA cijela okolina (VNet, Moodle VM-ovi, storage, LB) – zasebno od huba i zasebno od drugih developera, zbog vCPU kvote po regiji. U produkciji ovu listu generira CSV provisioning skripta."
  type = list(object({
    id       = string
    name     = string
    location = string
  }))
  default = [
    { id = "dev01", name = "Luka Lukic", location = "francecentral" },
    { id = "dev02", name = "Ivan Ivic", location = "swedencentral" },
  ]
}

variable "moodle_instances_per_dev" {
  description = "Broj Moodle VM instanci po developeru (2 = HA par po zahtjevu zadatka, puni default). Smanji na 1 preko -var jedino ako i multi-region raspored (svaki developer u svojoj regiji) ne stane u kvotu."
  type        = number
  default     = 2
}

variable "vm_size" {
  description = "Veličina VM-a za aplikacijske (Moodle) instance (2 vCPU / 4 GiB RAM po zahtjevu zadatka). Standard_B2s nema kapaciteta u Poland Central, koristi se B2s_v2 (isti profil, novija generacija, bez restrikcija)."
  type        = string
  default     = "Standard_B2s_v2"
}

variable "shared_vm_size" {
  description = "Veličina VM-a za jump host i DevOps Lead. Probano: B1ms/B1s (SkuNotAvailable), A1_v2 (ne podržava Gen2 image koji Rocky Linux 9 zahtijeva). Koristi se ista B2s_v2 kao za Moodle, jedina veličina s potvrđenim radom u ovoj regiji."
  type        = string
  default     = "Standard_B2s_v2"
}

variable "os_disk_size_gb" {
  description = "Veličina OS diska u GB."
  type        = number
  default     = 32
}

variable "data_disk_size_gb" {
  description = "Veličina data diska u GB (Moodle VM-ovi)."
  type        = number
  default     = 64
}

variable "admin_username" {
  description = "Admin korisničko ime za sve Linux VM-ove."
  type        = string
  default     = "azureuser"
}

variable "admin_ssh_public_key" {
  description = "Javni SSH ključ za pristup VM-ovima. Nema default vrijednost namjerno – mora se proslijediti kroz terraform.tfvars ili -var, npr. file(\"~/.ssh/id_rsa.pub\")."
  type        = string
}

variable "jump_host_allowed_ssh_cidr" {
  description = "CIDR raspon s kojeg je dopušten SSH na jump host. Ograniči na svoju javnu IP adresu (npr. \"203.0.113.4/32\") prije stvarnog deploymenta."
  type        = string
  default     = "*"
}

variable "hub_vnet_cidr" {
  description = "CIDR blok hub VNet-a (jump host + DevOps Lead)."
  type        = string
  default     = "10.20.0.0/24"
}

variable "spoke_vnet_cidr_prefix" {
  description = "Prefiks za CIDR spoke VNet-ova po developeru. Treći oktet se popunjava indeksom developera (10.21.<index>.0/24)."
  type        = string
  default     = "10.21"
}

# Rocky Linux 9 (RESF marketplace image). PROVJERI prije prvog apply-a:
#   az vm image list --publisher resf --all -o table
# i po potrebi jednom prihvati uvjete marketplacea:
#   az vm image terms accept --urn resf:rockylinux-x86_64:9-base:latest
variable "image_publisher" {
  description = "Marketplace publisher OS image-a."
  type        = string
  default     = "resf"
}

variable "image_offer" {
  description = "Marketplace offer OS image-a."
  type        = string
  default     = "rockylinux-x86_64"
}

variable "image_sku" {
  description = "Marketplace SKU OS image-a."
  type        = string
  default     = "9-base"
}

variable "image_version" {
  description = "Verzija OS image-a."
  type        = string
  default     = "latest"
}
