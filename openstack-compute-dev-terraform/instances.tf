# ---------------------------------------------------------------------------
# Moodle instance (2x po developeru, HA simulacija) - jedan NIC na vlastitoj
# dev mrezi, BEZ floating IP-a (nije javno dostupna - zahtjev zadatka: pristup
# iskljucivo kroz jump host). Security grupa (SSH+HTTP samo unutar vlastite
# subnet CIDR) je vec vezana na port u openstack-i2-terraform/network.tf.
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
}
