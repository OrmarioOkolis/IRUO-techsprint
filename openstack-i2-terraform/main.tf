terraform {
  required_version = ">= 1.5.0"

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 3.0"
    }
  }
}

provider "openstack" {
  # Autentikacija preko OS_* env varijabli (source ~/admin-rc prije terraform apply
  # na workstationu) - admin scope, potreban da bi resursi mogli biti kreirani
  # "u ime" developer projekata preko tenant_id/project_id argumenta (vidi
  # napomenu u compute.tf zasto to NE vrijedi za Nova/Cinder/Swift resurse).
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  developers_indexed = {
    for idx, dev in var.developers :
    dev.id => merge(dev, { index = idx + 1 })
  }

  # Flatten: "dev01-01", "dev01-02", "dev02-01", ... -> { dev_id = "dev01" }
  moodle_instances = merge([
    for dev_id, dev in local.developers_indexed : {
      for n in range(1, var.moodle_instances_per_dev + 1) :
      "${dev_id}-${format("%02d", n)}" => { dev_id = dev_id }
    }
  ]...)
}

# ---------------------------------------------------------------------------
# Projekti kreirani u openstack-i3-terraform - dohvaceni preko data source-a
# po imenu (namjerno odvojen Terraform state/modul, isti obrazac kao Azure
# azure-i5-rbac-terraform -> azure-i4-terraform, samo obrnutim redoslijedom
# ovisnosti: ovdje I2 OVISI o I3, jer OpenStack projekt mora postojati PRIJE
# resursa unutar njega - I3 se MORA primijeniti prvi).
# ---------------------------------------------------------------------------
data "openstack_identity_project_v3" "shared" {
  name = "${local.name_prefix}-shared"
}

data "openstack_identity_project_v3" "dev" {
  for_each = local.developers_indexed

  name = "${local.name_prefix}-${each.key}"
}

data "openstack_networking_network_v2" "external" {
  name = var.external_network_name
}

data "openstack_images_image_v2" "base" {
  name        = var.image_name
  most_recent = true
}
