variable "project_name" {
  description = "Naziv projekta, koristi se u konvenciji imenovanja (mora se poklapati s openstack-i2-terraform)."
  type        = string
  default     = "techsprint"
}

variable "environment" {
  description = "Naziv okoline (mora se poklapati s openstack-i2-terraform)."
  type        = string
  default     = "testing"
}

variable "domain_name" {
  description = "Keystone domena u kojoj se kreiraju projekti/korisnici (Default domena na RHA CL110 sandboxu)."
  type        = string
  default     = "Default"
}

variable "lead" {
  description = "Podaci o DevOps Lead korisniku (mora se poklapati s openstack-i2-terraform var.lead)."
  type = object({
    name = string
  })
  default = {
    name = "Ana Anic"
  }
}

variable "developers" {
  description = "Popis developera (mora se poklapati s openstack-i2-terraform var.developers - isti id/name)."
  type = list(object({
    id   = string
    name = string
  }))
  default = [
    { id = "dev01", name = "Luka Lukic" },
    { id = "dev02", name = "Ivan Ivic" },
  ]
}

# ---------------------------------------------------------------------------
# Za razliku od Azurea (dijeljeni fakultetski AAD tenant, nije dozvoljeno
# kreirati nove korisnike preko API-ja - vidi azure-i5-rbac-terraform), ovdje
# smo puni cloud admin na VLASTITOJ izoliranoj RHA classroom instanci, pa
# Terraform stvarno kreira Keystone korisnika po developeru (openstack_identity_user_v3)
# umjesto da reciklira admin identitet. Lozinke se generiraju (random_password)
# i izlaze kao sensitive Terraform output - CSV provisioning skripta (buduce
# prosirenje scripts/provision.py za OpenStack) bi ih distribuirala developerima.
# ---------------------------------------------------------------------------
variable "create_developer_users" {
  description = "Kreiraj stvarne Keystone korisnike po developeru. Iskljuci (false) samo ako se namjerno zeli koristiti postojece korisnike umjesto kreiranja novih."
  type        = bool
  default     = true
}
