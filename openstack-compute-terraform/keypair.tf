resource "openstack_compute_keypair_v2" "admin" {
  name       = "${local.name_prefix}-keypair"
  public_key = var.admin_ssh_public_key
}
