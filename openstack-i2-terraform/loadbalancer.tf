# ---------------------------------------------------------------------------
# Octavia LB (potvrdjeno dostupan servis na RHA sandboxu) po developeru -
# prava LBaaS umjesto rucnog HAProxy-a, HA raspodjela preko 2 Moodle instance.
# openstack_lb_* resursi podrzavaju tenant_id, pa idu ovdje (admin-scoped,
# for_each), isto kao mrezni sloj - ne treba project-scoped provider.
# ---------------------------------------------------------------------------
resource "openstack_lb_loadbalancer_v2" "moodle" {
  for_each = local.developers_indexed

  name          = "${local.name_prefix}-lb-${each.key}"
  tenant_id     = data.openstack_identity_project_v3.dev[each.key].id
  vip_subnet_id = openstack_networking_subnet_v2.dev[each.key].id
}

resource "openstack_lb_listener_v2" "moodle" {
  for_each = local.developers_indexed

  name            = "${local.name_prefix}-listener-${each.key}"
  tenant_id       = data.openstack_identity_project_v3.dev[each.key].id
  loadbalancer_id = openstack_lb_loadbalancer_v2.moodle[each.key].id
  protocol        = "HTTP"
  protocol_port   = 80
}

resource "openstack_lb_pool_v2" "moodle" {
  for_each = local.developers_indexed

  name        = "${local.name_prefix}-pool-${each.key}"
  tenant_id   = data.openstack_identity_project_v3.dev[each.key].id
  listener_id = openstack_lb_listener_v2.moodle[each.key].id
  protocol    = "HTTP"
  lb_method   = "ROUND_ROBIN"
}

resource "openstack_lb_monitor_v2" "moodle" {
  for_each = local.developers_indexed

  tenant_id      = data.openstack_identity_project_v3.dev[each.key].id
  pool_id        = openstack_lb_pool_v2.moodle[each.key].id
  type           = "HTTP"
  url_path       = "/"
  http_method    = "GET"
  expected_codes = "200,303"
  delay          = 10
  timeout        = 5
  max_retries    = 3
}

# Clanovi pool-a - fixna IP se cita s unaprijed kreiranog porta (network.tf),
# ne s Nova instance (koja jos ne postoji u ovom apply-u - vidi compute.tf).
resource "openstack_lb_member_v2" "moodle" {
  for_each = local.moodle_instances

  tenant_id     = data.openstack_identity_project_v3.dev[each.value.dev_id].id
  pool_id       = openstack_lb_pool_v2.moodle[each.value.dev_id].id
  address       = openstack_networking_port_v2.moodle[each.key].all_fixed_ips[0]
  protocol_port = 80
  subnet_id     = openstack_networking_subnet_v2.dev[each.value.dev_id].id
}
