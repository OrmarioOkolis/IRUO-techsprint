variable "project_name" {
  description = "Naziv projekta (mora se poklapati s openstack-i2-terraform/openstack-i3-terraform)."
  type        = string
  default     = "techsprint"
}

variable "environment" {
  description = "Naziv okoline (mora se poklapati s openstack-i2-terraform/openstack-i3-terraform)."
  type        = string
  default     = "testing"
}

variable "developers" {
  description = "Popis developera - koristi se SAMO za enumeraciju jump_to_dev portova (drugi NIC jump hosta prema svakoj dev mrezi). Mora se poklapati s openstack-i2-terraform var.developers."
  type = list(object({
    id   = string
    name = string
  }))
  default = [
    { id = "dev01", name = "Luka Lukic" },
    { id = "dev02", name = "Ivan Ivic" },
  ]
}

variable "image_name" {
  description = "OS image (mora se poklapati s openstack-i2-terraform var.image_name)."
  type        = string
  default     = "rhel8"
}

variable "admin_username" {
  description = "Cloud-init default korisnik na image-u. PROVJERI stvarnog korisnika prije apply-a (RHEL cloud image obicno 'cloud-user', ali nije verificirano na ovom sandboxu)."
  type        = string
  default     = "cloud-user"
}

variable "admin_ssh_public_key" {
  description = "Javni SSH kljuc za pristup VM-ovima - isti kao openstack-i2-terraform var.admin_ssh_public_key (kopiraj iz istog terraform.tfvars)."
  type        = string
}

variable "vm_flavor_vcpus" {
  description = "vCPU za jump/lead VM-ove."
  type        = number
  default     = 2
}

variable "vm_flavor_ram_mb" {
  description = "RAM (MB) za jump/lead VM-ove (4096 = 4GB po zahtjevu zadatka)."
  type        = number
  default     = 4096
}

variable "vm_flavor_disk_gb" {
  description = "OS disk (GB), dio flavora. Jump/lead ne trebaju 2. disk (taj zahtjev vrijedi za aplikacijske/Moodle VM-ove, ne za jump/lead)."
  type        = number
  default     = 20
}
