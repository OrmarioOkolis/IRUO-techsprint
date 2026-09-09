# ---------------------------------------------------------------------------
# Jump host - visestruki NIC: prvi (hub port, ima floating IP iz I2) je
# primarni/default-route interface, po jedan dodatni NIC prema SVAKOJ dev
# mrezi (jump_to_dev port iz I2) - jedini most za SSH u izolirane dev mreze.
# Redoslijed "network" blokova odredjuje redoslijed eth0/eth1/... sucelja.
# ---------------------------------------------------------------------------
resource "openstack_compute_instance_v2" "jump" {
  name         = "${local.name_prefix}-jump"
  image_id     = data.openstack_images_image_v2.base.id
  flavor_id    = openstack_compute_flavor_v2.app.id
  key_pair     = openstack_compute_keypair_v2.admin.name
  config_drive = true

  network {
    port = data.openstack_networking_port_v2.jump.id
  }

  dynamic "network" {
    for_each = local.developers_indexed
    content {
      port = data.openstack_networking_port_v2.jump_to_dev[network.key].id
    }
  }
}

# ---------------------------------------------------------------------------
# DevOps Lead VM - jedan NIC na hub mrezi, bez floating IP-a (dostupan samo
# preko jump hosta - vidi sg-lead u openstack-i2-terraform/network.tf).
# ---------------------------------------------------------------------------
resource "openstack_compute_instance_v2" "lead" {
  name         = "${local.name_prefix}-lead"
  image_id     = data.openstack_images_image_v2.base.id
  flavor_id    = openstack_compute_flavor_v2.app.id
  key_pair     = openstack_compute_keypair_v2.admin.name
  config_drive = true

  network {
    port = data.openstack_networking_port_v2.lead.id
  }
}
