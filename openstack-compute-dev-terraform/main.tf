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
# VAZNO - ovaj modul se MORA pokretati JEDNOM PO DEVELOPERU, s providerom
# scope-anim na TOG developera projekt (techsprint-testing-devXX), ne na
# "admin" ili "shared" projekt. Isti razlog kao openstack-compute-terraform
# (jump/lead) - Nova/Cinder/Swift/Manila project_id je computed-only, pa
# instanca/volume/kontejner/share uvijek nastaje u projektu na koji je token
# scope-an (vidi CLAUDE.md "KRITICNO OGRANICENJE PROVIDERA").
#
# Prije terraform apply, na workstationu (primjer za dev01):
#   source ~/admin-rc
#   export OS_PROJECT_NAME=techsprint-testing-dev01
#   export OS_PROJECT_DOMAIN_NAME=Default
#   unset OS_PROJECT_ID
#   terraform apply -auto-approve -var dev_id=dev01
#
# Admin operater vec ima "admin" rolu na SVAKOM dev projektu (vidi
# openstack-i3-terraform/assignments.tf: admin_operator_dev) - isti fix koji
# je bio potreban za shared projekt (openstack-compute-terraform), pa se ovdje
# ne treba ponovno rjesavati.
#
# Za drugog developera: promijeni OS_PROJECT_NAME i -var dev_id, koristi
# ZASEBAN state file (npr. -state=terraform-dev02.tfstate) da se stateovi
# razlicitih developera ne miksaju u istom direktoriju. scripts/provision.py
# (buduce prosirenje za OpenStack) automatizira ovu petlju.
# ---------------------------------------------------------------------------
provider "openstack" {
  # Autentikacija preko OS_* env varijabli, VEC SCOPE-ANIH na
  # techsprint-testing-<dev_id> (vidi napomenu iznad).
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  # "dev01-01", "dev01-02", ... - isti obrazac kao local.moodle_instances u
  # openstack-i2-terraform/main.tf, ali samo za JEDNOG developera (var.dev_id).
  moodle_keys = [
    for n in range(1, var.moodle_instances_per_dev + 1) :
    "${var.dev_id}-${format("%02d", n)}"
  ]
}

# ---------------------------------------------------------------------------
# Resursi vec kreirani u openstack-i2-terraform (portovi/mreza) i
# openstack-compute-terraform (image/flavor/keypair - flavor i keypair su
# globalni/Nova-vlasnik-scoped resursi, vidljivi neovisno o trenutnom project
# scope-u) - dohvaceni preko data source-a po imenu, isti obrazac kao ostali
# moduli (bez remote state).
# ---------------------------------------------------------------------------
data "openstack_images_image_v2" "base" {
  name        = var.image_name
  most_recent = true
}

data "openstack_compute_flavor_v2" "app" {
  name = "${local.name_prefix}-app"
}

data "openstack_compute_keypair_v2" "admin" {
  name = "${local.name_prefix}-keypair"
}

data "openstack_networking_port_v2" "moodle" {
  for_each = toset(local.moodle_keys)

  name = "${local.name_prefix}-port-moodle-${each.key}"
}
