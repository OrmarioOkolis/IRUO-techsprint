# ---------------------------------------------------------------------------
# Moodle instance (2x po developeru, HA simulacija) - PRVI NIC na vlastitoj
# dev mrezi (primarni/default-route interface, BEZ floating IP-a - nije javno
# dostupna, pristup iskljucivo kroz jump host), DRUGI NIC izravno na storage
# mrezi (Ceph mon pristup za Manila CephFS mount - vidi opsirnu napomenu uz
# openstack_networking_port_v2.moodle_storage u openstack-i2-terraform/network.tf;
# redoslijed "network" blokova odredjuje redoslijed eth0/eth1, isti obrazac
# kao jump host u openstack-compute-terraform/instances.tf). Security grupa
# (SSH+HTTP samo unutar vlastite subnet CIDR) je vec vezana na prvi port u
# openstack-i2-terraform/network.tf.
# ---------------------------------------------------------------------------
resource "openstack_compute_instance_v2" "moodle" {
  for_each = toset(local.moodle_keys)

  name         = "${local.name_prefix}-moodle-${each.key}"
  image_id     = data.openstack_images_image_v2.base.id
  flavor_id    = data.openstack_compute_flavor_v2.app.id
  key_pair     = data.openstack_compute_keypair_v2.admin.name
  config_drive = true

  network {
    port = data.openstack_networking_port_v2.moodle[each.key].id
  }

  network {
    port = data.openstack_networking_port_v2.moodle_storage[each.key].id
  }
}
