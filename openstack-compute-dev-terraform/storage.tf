# ---------------------------------------------------------------------------
# 2. disk (data disk) po Moodle instanci - zaseban Cinder volume + attachment.
# Prvi disk (OS) je dio flavora (openstack-compute-terraform/flavor.tf).
# ---------------------------------------------------------------------------
resource "openstack_blockstorage_volume_v3" "moodle_data" {
  for_each = toset(local.moodle_keys)

  name = "${local.name_prefix}-data-${each.key}"
  size = var.data_disk_size_gb
}

resource "openstack_compute_volume_attach_v2" "moodle_data" {
  for_each = toset(local.moodle_keys)

  instance_id = openstack_compute_instance_v2.moodle[each.key].id
  volume_id   = openstack_blockstorage_volume_v3.moodle_data[each.key].id
}

# ---------------------------------------------------------------------------
# Objektna pohrana (Swift) - jedan kontejner po developeru, dijele ga obje
# Moodle instance (Moodle "moodledata" file storage preko Swift API-ja, ili
# rucni backup upload - konkretna Moodle konfiguracija je Ansible zadatak,
# ne Terraform). Least-privilege pristup (2 boda rubrike) rjesava se preko
# EC2 credentials/application credential ogranicenih na ovaj kontejner -
# vidi napomenu uz buduci Ansible role.
# ---------------------------------------------------------------------------
resource "openstack_objectstorage_container_v1" "moodle_objects" {
  name = "${local.name_prefix}-${var.object_container_name_suffix}-${var.dev_id}"
}

# ---------------------------------------------------------------------------
# Datotecna pohrana (Manila NFS share) - backupi, dijeljeni preko obje Moodle
# instance developera preko iste dev mreze (mount na obje instance - Ansible
# zadatak). NIJE JOS LIVE TESTIRANO na RHA sandboxu (za razliku od Octavia LB
# gdje smo unaprijed znali da ne radi - ovdje jednostavno ne znamo dok se ne
# proba). Ako sharenetwork/share pukne (npr. driver ne podrzava
# driver_handles_share_servers ili share_type nije ispravan), provjeri
# `openstack share type list` i `openstack share network list` pa prilagodi
# var.manila_share_type.
# ---------------------------------------------------------------------------
resource "openstack_sharedfilesystem_sharenetwork_v2" "dev" {
  name              = "${local.name_prefix}-sharenet-${var.dev_id}"
  neutron_net_id    = data.openstack_networking_network_v2.dev.id
  neutron_subnet_id = data.openstack_networking_subnet_v2.dev.id
}

resource "openstack_sharedfilesystem_share_v2" "backups" {
  name             = "${local.name_prefix}-backups-${var.dev_id}"
  share_proto      = "NFS"
  size             = var.manila_share_size_gb
  share_network_id = openstack_sharedfilesystem_sharenetwork_v2.dev.id
  share_type       = var.manila_share_type != "" ? var.manila_share_type : null
}
