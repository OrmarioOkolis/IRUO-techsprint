variable "project_name" {
  description = "Naziv projekta (mora se poklapati s ostalim OpenStack modulima)."
  type        = string
  default     = "techsprint"
}

variable "environment" {
  description = "Naziv okoline (mora se poklapati s ostalim OpenStack modulima)."
  type        = string
  default     = "testing"
}

variable "dev_id" {
  description = "ID developera za KOJEG se ovaj apply pokrece (npr. 'dev01'). Nema default namjerno - mora se eksplicitno proslijediti (-var dev_id=devXX) da se sprijeci slucajna primjena na krivi projekt."
  type        = string
}

variable "moodle_instances_per_dev" {
  description = "Broj Moodle VM instanci (mora se poklapati s openstack-i2-terraform var.moodle_instances_per_dev - koristi se za enumeraciju vec kreiranih portova)."
  type        = number
  default     = 2
}

variable "image_name" {
  description = "OS image (mora se poklapati s ostalim OpenStack modulima)."
  type        = string
  default     = "rhel8"
}

variable "admin_username" {
  description = "Cloud-init default korisnik na image-u (potvrdjeno live 9.9.2026: 'cloud-user' na rhel8 RHA image-u)."
  type        = string
  default     = "cloud-user"
}

variable "data_disk_size_gb" {
  description = "Velicina 2. diska (GB) po Moodle instanci - zaseban Cinder volume (prvi disk je OS disk, dio flavora)."
  type        = number
  default     = 20
}

variable "object_container_name_suffix" {
  description = "Sufiks imena Swift kontejnera (objektna pohrana Moodle datoteka) - puno ime je '<name_prefix>-object-<dev_id>'."
  type        = string
  default     = "object"
}

variable "manila_share_size_gb" {
  description = "Velicina Manila share-a (GB) - datotecna pohrana za backupe, dijeljena preko obje Moodle instance developera (NFS)."
  type        = number
  default     = 10
}

variable "manila_share_type" {
  description = "Manila share type. Prazan string = koristi default share type sandboxa (nije unaprijed poznat - provjeri `openstack share type list` prije prve primjene)."
  type        = string
  default     = ""
}
