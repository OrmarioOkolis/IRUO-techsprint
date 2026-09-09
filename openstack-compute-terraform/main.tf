terraform {
  required_version = ">= 1.5.0"

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 3.0"
    }
  }
}

# ---------------------------------------------------------------------------
# VAZNO - ovaj modul se MORA pokretati s providerom scope-anim na
# techsprint-testing-shared projekt (ne na "admin" projekt kao I2/I3).
# Razlog (vidi CLAUDE.md "KRITICNO OGRANICENJE PROVIDERA"): Nova instanca
# (openstack_compute_instance_v2) nema settable tenant_id/project_id -
# instanca uvijek nastaje u projektu na koji je trenutni token scope-an.
# I2/I3 su mogli ostati na plain admin-rc (project=admin) jer Neutron/Keystone
# resursi tamo DOPUSTAJU eksplicitni tenant_id/project_id override ("kreiraj
# u ime drugog projekta") - Nova to ne dopusta.
#
# Prije terraform apply, na workstationu:
#   source ~/admin-rc
#   export OS_PROJECT_NAME=techsprint-testing-shared
#   export OS_PROJECT_DOMAIN_NAME=Default
#   unset OS_PROJECT_ID  # ako je admin-rc export-ao ID admin projekta
#
# Admin korisnik i dalje ostaje isti (admin/redhat) - samo je token scope
# promijenjen na drugi projekt. Ako admin korisnik NEMA rolu na shared
# projektu (nije testirano unaprijed - vidi napomenu u CLAUDE.md), token
# issue ce pući s 401/403 i treba dodati eksplicitni role assignment u
# openstack-i3-terraform (assignments.tf) za admin identitet na shared
# projektu, analogno kako lead dobiva admin rolu na dev projektima.
# ---------------------------------------------------------------------------
provider "openstack" {
  # Autentikacija preko OS_* env varijabli, VEC SCOPE-ANIH na
  # techsprint-testing-shared (vidi napomenu iznad).
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  developers_indexed = {
    for idx, dev in var.developers :
    dev.id => merge(dev, { index = idx + 1 })
  }
}

# ---------------------------------------------------------------------------
# Image i portovi kreirani u openstack-i2-terraform - dohvaceni preko data
# source-a po imenu (isti obrazac kao I2 -> I3, namjerno odvojeni state/moduli,
# bez remote state - vidi CLAUDE.md).
# ---------------------------------------------------------------------------
data "openstack_images_image_v2" "base" {
  name        = var.image_name
  most_recent = true
}

data "openstack_networking_port_v2" "jump" {
  name = "${local.name_prefix}-port-jump"
}

data "openstack_networking_port_v2" "lead" {
  name = "${local.name_prefix}-port-lead"
}

data "openstack_networking_port_v2" "jump_to_dev" {
  for_each = local.developers_indexed

  name = "${local.name_prefix}-port-jump-to-${each.key}"
}
