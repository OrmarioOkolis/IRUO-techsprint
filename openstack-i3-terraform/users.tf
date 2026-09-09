# ---------------------------------------------------------------------------
# Stvarni Keystone korisnici po developeru - moguce jer smo puni admin na
# VLASTITOJ izoliranoj RHA classroom instanci (za razliku od Azurea, gdje je
# dijeljeni fakultetski AAD tenant zabranjivao kreiranje novih korisnika -
# vidi azure-i5-rbac-terraform). Lozinke generira Terraform (random_password),
# izlaze kao sensitive output - buduce prosirenje scripts/provision.py za
# OpenStack bi ih upisalo u CSV-generirani izvjestaj za distribuciju.
# ---------------------------------------------------------------------------

resource "random_password" "developer" {
  for_each = local.developers_indexed

  length  = 20
  special = true
}

resource "openstack_identity_user_v3" "developer" {
  for_each = local.developers_indexed

  name               = each.key
  description        = "TechSprint developer: ${each.value.name}"
  domain_id          = local.domain_id
  default_project_id = openstack_identity_project_v3.dev[each.key].id
  password           = random_password.developer[each.key].result
  enabled            = true
}

resource "random_password" "lead" {
  length  = 20
  special = true
}

resource "openstack_identity_user_v3" "lead" {
  name               = "lead"
  description        = "TechSprint DevOps Lead: ${var.lead.name}"
  domain_id          = local.domain_id
  default_project_id = openstack_identity_project_v3.shared.id
  password           = random_password.lead.result
  enabled            = true
}
