# Ponavlja naming konvenciju iz azure-i4-terraform (namjerno odvojen modul,
# vidi variables.tf ondje za detaljne opise) da bismo mogli izracunati imena
# postojecih Resource Groupa i dohvatiti ih preko data source-a, bez cvrste
# ovisnosti (remote state) o I4 modulu.

variable "project_name" {
  type    = string
  default = "techsprint"
}

variable "environment" {
  type    = string
  default = "testing"
}

variable "location_abbr" {
  description = "Kratica HUB regije (mora se poklapati s azure-i4-terraform var.location_abbr)."
  type        = string
  default     = "plc"
}

variable "region_abbr" {
  type = map(string)
  default = {
    polandcentral      = "plc"
    francecentral      = "fc"
    germanywestcentral = "gwc"
    spaincentral       = "spc"
    swedencentral      = "sc"
  }
}

variable "developers" {
  description = "Mora se poklapati s azure-i4-terraform var.developers (isti id/location) da se ispravno pronadju postojeci Resource Groupovi."
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

variable "developer_principal_ids" {
  description = "Mapa dev_id -> Azure AD object_id developera kojem se dodjeljuje custom role. Prazno (default) = koristi trenutno prijavljeni principal (az account show) za demo/testiranje, jer u ovom (fakultetskom) tenantu nemamo prava kreirati zasebne AAD korisnike po developeru. U punoj produkcijskoj verziji ovu mapu generira CSV provisioning skripta iz stvarnih korisnika."
  type        = map(string)
  default     = {}
}

variable "lead_principal_id" {
  description = "Azure AD object_id DevOps Leada. Prazno (default) = koristi trenutno prijavljeni principal (isti razlog kao developer_principal_ids)."
  type        = string
  default     = ""
}
