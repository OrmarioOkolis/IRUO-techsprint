# ---------------------------------------------------------------------------
# HUB mreza (shared projekt) - jump host (javni pristup preko floating IP-a)
# + DevOps Lead (bez floating IP-a, dostupan samo preko jump hosta).
# ---------------------------------------------------------------------------
resource "openstack_networking_network_v2" "hub" {
  name           = "${local.name_prefix}-net-shared"
  tenant_id      = data.openstack_identity_project_v3.shared.id
  admin_state_up = true
}

resource "openstack_networking_subnet_v2" "hub" {
  name            = "${local.name_prefix}-subnet-shared"
  tenant_id       = data.openstack_identity_project_v3.shared.id
  network_id      = openstack_networking_network_v2.hub.id
  cidr            = var.hub_network_cidr
  ip_version      = 4
  dns_nameservers = var.dns_nameservers
}

resource "openstack_networking_router_v2" "hub" {
  name                = "${local.name_prefix}-router-shared"
  tenant_id           = data.openstack_identity_project_v3.shared.id
  admin_state_up      = true
  external_network_id = data.openstack_networking_network_v2.external.id
}

resource "openstack_networking_router_interface_v2" "hub" {
  router_id = openstack_networking_router_v2.hub.id
  subnet_id = openstack_networking_subnet_v2.hub.id
}

# Jump host: SSH dopusten s vanjskog CIDR-a (floating IP) - jedina javno
# dostupna tocka ulaza, po zahtjevu zadatka ("jump host / bastion").
resource "openstack_networking_secgroup_v2" "jump" {
  name        = "${local.name_prefix}-sg-jump"
  description = "Jump host: SSH s vanjske mreze"
  tenant_id   = data.openstack_identity_project_v3.shared.id
}

resource "openstack_networking_secgroup_rule_v2" "jump_ssh" {
  security_group_id = openstack_networking_secgroup_v2.jump.id
  tenant_id          = data.openstack_identity_project_v3.shared.id
  direction          = "ingress"
  ethertype          = "IPv4"
  protocol           = "tcp"
  port_range_min     = 22
  port_range_max     = 22
  remote_ip_prefix   = var.jump_host_allowed_ssh_cidr
}

# Lead VM: SSH dopusten SAMO iz hub mreze (tj. s jump hosta) - lead nema
# floating IP, nije javno dostupan izravno.
resource "openstack_networking_secgroup_v2" "lead" {
  name        = "${local.name_prefix}-sg-lead"
  description = "DevOps Lead VM: SSH samo iz hub mreze (preko jump hosta)"
  tenant_id   = data.openstack_identity_project_v3.shared.id
}

resource "openstack_networking_secgroup_rule_v2" "lead_ssh" {
  security_group_id = openstack_networking_secgroup_v2.lead.id
  tenant_id          = data.openstack_identity_project_v3.shared.id
  direction          = "ingress"
  ethertype          = "IPv4"
  protocol           = "tcp"
  port_range_min     = 22
  port_range_max     = 22
  remote_ip_prefix   = var.hub_network_cidr
}

# Portovi za jump/lead na hub mrezi - eksplicitno kreirani ovdje (mrezni sloj)
# da bi floating IP mogao biti unaprijed pridruzen, a compute.tf (posebna
# petlja po projektu - vidi napomenu ondje) samo prikaci VM na gotov port.
resource "openstack_networking_port_v2" "jump" {
  name               = "${local.name_prefix}-port-jump"
  tenant_id          = data.openstack_identity_project_v3.shared.id
  network_id         = openstack_networking_network_v2.hub.id
  admin_state_up     = true
  security_group_ids = [openstack_networking_secgroup_v2.jump.id]

  depends_on = [openstack_networking_router_interface_v2.hub]
}

resource "openstack_networking_port_v2" "lead" {
  name               = "${local.name_prefix}-port-lead"
  tenant_id          = data.openstack_identity_project_v3.shared.id
  network_id         = openstack_networking_network_v2.hub.id
  admin_state_up     = true
  security_group_ids = [openstack_networking_secgroup_v2.lead.id]

  depends_on = [openstack_networking_router_interface_v2.hub]
}

resource "openstack_networking_floatingip_v2" "jump" {
  pool      = var.external_network_name
  tenant_id = data.openstack_identity_project_v3.shared.id
}

resource "openstack_networking_floatingip_associate_v2" "jump" {
  floating_ip = openstack_networking_floatingip_v2.jump.address
  port_id     = openstack_networking_port_v2.jump.id
}

# ---------------------------------------------------------------------------
# Developer mreze - potpuno izolirane jedna od druge (odvojeni Neutron L2
# segmenti, nikad medjusobno L3-povezani), po jedna po developeru. Router ima
# vanjski gateway ISKLJUCIVO radi SNAT internet izlaza - dev instance nemaju
# floating IP, nisu javno dostupne (zahtjev zadatka: "izlaz na Internet za sve
# VM-ove" + "pristup iskljucivo kroz jump host").
# ---------------------------------------------------------------------------
resource "openstack_networking_network_v2" "dev" {
  for_each = local.developers_indexed

  name           = "${local.name_prefix}-net-${each.key}"
  tenant_id      = data.openstack_identity_project_v3.dev[each.key].id
  admin_state_up = true
}

resource "openstack_networking_subnet_v2" "dev" {
  for_each = local.developers_indexed

  name            = "${local.name_prefix}-subnet-${each.key}"
  tenant_id       = data.openstack_identity_project_v3.dev[each.key].id
  network_id      = openstack_networking_network_v2.dev[each.key].id
  cidr            = "${var.dev_network_cidr_prefix}.${each.value.index}.0/24"
  ip_version      = 4
  dns_nameservers = var.dns_nameservers
}

resource "openstack_networking_router_v2" "dev" {
  for_each = local.developers_indexed

  name                = "${local.name_prefix}-router-${each.key}"
  tenant_id           = data.openstack_identity_project_v3.dev[each.key].id
  admin_state_up      = true
  external_network_id = data.openstack_networking_network_v2.external.id
}

resource "openstack_networking_router_interface_v2" "dev" {
  for_each = local.developers_indexed

  router_id = openstack_networking_router_v2.dev[each.key].id
  subnet_id = openstack_networking_subnet_v2.dev[each.key].id
}

# Portovi za Moodle VM-ove - kreirani ovdje (mrezni sloj) kako bi Octavia LB
# pool member (loadbalancer.tf) mogao referencirati poznatu fixed IP PRIJE
# nego instance uopce postoje (nastaju u odvojenom compute modulu - vidi
# napomenu u compute.tf zasto Nova instance zahtijevaju project-scoped
# provider, pa se kreiraju u posebnoj petlji, ne ovdje). Security grupa se
# definira nize (openstack_networking_secgroup_v2.moodle) pa je port resurs
# svejedno mora referencirati unaprijed - Terraform to rjesava preko graf
# ovisnosti, redoslijed definicija u fileu nije bitan.
resource "openstack_networking_port_v2" "moodle" {
  for_each = local.moodle_instances

  name               = "${local.name_prefix}-port-moodle-${each.key}"
  tenant_id          = data.openstack_identity_project_v3.dev[each.value.dev_id].id
  network_id         = openstack_networking_network_v2.dev[each.value.dev_id].id
  admin_state_up     = true
  security_group_ids = [openstack_networking_secgroup_v2.moodle[each.value.dev_id].id]

  depends_on = [openstack_networking_router_interface_v2.dev]
}

# Moodle instance: SSH samo iz vlastite dev subnet CIDR (odakle dolazi jump
# hostov "dev-facing" port - vidi jump_to_dev port nize), HTTP unutar vlastite
# subnet CIDR (Octavia amphora dobiva port UNUTAR iste member subnet, pa health
# probe/promet stize s te iste CIDR mreze - nema posebnog "AzureLoadBalancer"
# ekvivalenta, provjera je preko izvorne IP mreze).
resource "openstack_networking_secgroup_v2" "moodle" {
  for_each = local.developers_indexed

  name        = "${local.name_prefix}-sg-moodle-${each.key}"
  description = "Moodle VM (${each.key}): SSH+HTTP samo unutar vlastite izolirane mreze"
  tenant_id   = data.openstack_identity_project_v3.dev[each.key].id
}

resource "openstack_networking_secgroup_rule_v2" "moodle_ssh" {
  for_each = local.developers_indexed

  security_group_id = openstack_networking_secgroup_v2.moodle[each.key].id
  tenant_id          = data.openstack_identity_project_v3.dev[each.key].id
  direction          = "ingress"
  ethertype          = "IPv4"
  protocol           = "tcp"
  port_range_min     = 22
  port_range_max     = 22
  remote_ip_prefix   = openstack_networking_subnet_v2.dev[each.key].cidr
}

resource "openstack_networking_secgroup_rule_v2" "moodle_http" {
  for_each = local.developers_indexed

  security_group_id = openstack_networking_secgroup_v2.moodle[each.key].id
  tenant_id          = data.openstack_identity_project_v3.dev[each.key].id
  direction          = "ingress"
  ethertype          = "IPv4"
  protocol           = "tcp"
  port_range_min     = 80
  port_range_max     = 80
  remote_ip_prefix   = openstack_networking_subnet_v2.dev[each.key].cidr
}

# Jump hostov dodatni port NA SVAKOJ dev mrezi - jedini most preko kojeg jump
# host (fizicki u shared projektu) moze SSH-ati u izolirane dev mreze, bez da
# se dev mreze ikad medjusobno L2/L3 povezu (svaka je spojena SAMO s jump
# hostom, nikad jedna s drugom). Analogno Azure hub-spoke VNet peeringu, samo
# bez peeringa - ovdje je to doslovno drugi NIC na istom hostu.
resource "openstack_networking_port_v2" "jump_to_dev" {
  for_each = local.developers_indexed

  name           = "${local.name_prefix}-port-jump-to-${each.key}"
  tenant_id      = data.openstack_identity_project_v3.shared.id
  network_id     = openstack_networking_network_v2.dev[each.key].id
  admin_state_up = true
  # Bez security_group_ids - ovaj port je SAMO izvor odlaznog SSH-a prema
  # Moodle VM-ovima, ne prima nikakav dolazni promet (default deny-all ingress
  # dovoljan je, izlazni promet Neutron po defaultu ne blokira).

  depends_on = [openstack_networking_router_interface_v2.dev]
}
