# ---------------------------------------------------------------------------
# Custom flavor - postojeci RHA flavori (default/default-swap/default-extra-disk)
# su svi 2048MB RAM / 2 vCPU, task zahtjeva 4GB RAM / 2 vCPU (vidi
# openstack-i2-terraform/variables.tf, ista napomena tamo gdje su ovi varovi
# prvi put deklarirani unaprijed). Flavor je globalni/admin resurs (nije
# projektno-skopiran), pa flavor:create policy treba samo admin rolu na
# tokenu - RADI i kad je token scope-an na shared projekt umjesto na admin
# projekt (nije bilo potrebno posebno prebacivati na plain admin-rc).
# ---------------------------------------------------------------------------
resource "openstack_compute_flavor_v2" "app" {
  name      = "${local.name_prefix}-app"
  ram       = var.vm_flavor_ram_mb
  vcpus     = var.vm_flavor_vcpus
  disk      = var.vm_flavor_disk_gb
  is_public = true
}
