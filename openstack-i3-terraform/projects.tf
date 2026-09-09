# ---------------------------------------------------------------------------
# Odvojeni projekti/tenanti (I3 zahtjev) - stvarna Keystone tenant izolacija,
# ne samo mrezna (koja je zasebno u openstack-i2-terraform). Developer koji
# nema role assignment na tudjem projektu se NE MOZE ni autenticirati u njega
# (potpuno drugaciji model izolacije od Azure RBAC-a koji je scope-based nad
# vec postojecim resursima - ovdje projekt mora postojati PRIJE resursa unutar
# njega, zato I3 ide prije I2 za OpenStack, obrnuto od Azure I4->I5 redoslijeda).
# ---------------------------------------------------------------------------

resource "openstack_identity_project_v3" "shared" {
  name        = "${local.name_prefix}-shared"
  description = "TechSprint - shared (jump host + DevOps Lead)"
  domain_id   = local.domain_id
}

resource "openstack_identity_project_v3" "dev" {
  for_each = local.developers_indexed

  name        = "${local.name_prefix}-${each.key}"
  description = "TechSprint - izolirani projekt developera ${each.value.name} (${each.key})"
  domain_id   = local.domain_id
}

# ---------------------------------------------------------------------------
# Kvote po projektu - RHA default projekt kvote (nasljedjene iz nova.conf/
# neutron.conf) su generalne; eksplicitno postavljamo dovoljno za HA par
# Moodle instanci (2x4GB/2vCPU) + prostora za rast, umjesto oslanjanja na
# nepoznat globalni default.
# ---------------------------------------------------------------------------
resource "openstack_compute_quotaset_v2" "dev" {
  for_each = local.developers_indexed

  project_id = openstack_identity_project_v3.dev[each.key].id
  instances  = 4
  cores      = 8
  ram        = 16384
}

resource "openstack_networking_quota_v2" "dev" {
  for_each = local.developers_indexed

  project_id          = openstack_identity_project_v3.dev[each.key].id
  network             = 2
  subnet              = 2
  router              = 1
  port                = 10
  floatingip          = 0 # dev projekti namjerno bez floating IP-a - pristup samo preko jump hosta
  security_group      = 5
  security_group_rule = 40
}

resource "openstack_blockstorage_quotaset_v3" "dev" {
  for_each = local.developers_indexed

  project_id = openstack_identity_project_v3.dev[each.key].id
  volumes    = 4
  gigabytes  = 100
}
