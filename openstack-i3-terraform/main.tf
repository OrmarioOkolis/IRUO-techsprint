terraform {
  required_version = ">= 1.5.0"

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "openstack" {
  # Autentikacija preko OS_* env varijabli (source ~/admin-rc prije terraform apply
  # na workstationu) - namjerno bez hardkodiranih kredencijala u kodu, isti obrazac
  # kao openrc koji RHA vec generira.
}

locals {
  # Keystone nema data source za domenu - "default" je poznati/staticki ID
  # Default domene (Keystone konvencija), ne treba lookup.
  domain_id = "default"

  name_prefix = "${var.project_name}-${var.environment}"

  developers_indexed = {
    for idx, dev in var.developers :
    dev.id => merge(dev, { index = idx + 1 })
  }
}

# ---------------------------------------------------------------------------
# Postojeci "admin" Keystone korisnik (iz admin-rc, RHA bootstrap) - NIJE
# nas resurs, samo lookup po imenu. Treba nam eksplicitan role assignment
# na shared/dev projektima (vidi assignments.tf) jer admin PO DEFAULTU nema
# rolu tamo (potvrdjeno live: `openstack role assignment list --user admin`
# pokazuje samo admin@admin, member@finance, member@production, plus
# domain/system-scoped admin - nijedan od njih ne dopusta project-scoped
# token na techsprint-testing-* projektima). Bez ovoga, openstack-compute-terraform
# (Nova instance - zahtijeva project-scoped provider, vidi CLAUDE.md) ne moze
# dobiti token scope-an na shared/dev projekt -> "HTTP 401" na `openstack
# token issue`, potvrdjeno live 9.9.2026.
# ---------------------------------------------------------------------------
data "openstack_identity_user_v3" "admin_operator" {
  name      = "admin"
  domain_id = local.domain_id
}
