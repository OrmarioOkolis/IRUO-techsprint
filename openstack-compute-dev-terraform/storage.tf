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
# Datotecna pohrana (Manila share) - backupi, dijeljeni preko obje Moodle
# instance developera preko iste dev mreze (mount na obje instance - Ansible
# zadatak).
#
# LIVE TESTIRANO 9.9.2026: prvi pokusaj s NFS protokolom je pukao -
# `Error creating share: badRequest (400): Invalid share protocol provided:
# NFS. It is either disabled or unsupported. Available protocols: ['CEPHFS']`
# - ovaj RHA CL110 sandbox ima Manila backend konfiguriran SAMO za CephFS, ne
# NFS (ocekivano razlicito od produkcijskog RHOSP-a, ali ovo je stvarno stanje
# sandboxa). sharenetwork (driver_handles_share_servers) je uspjesno kreiran
# PRIJE ovog erora, pa ostaje - CephFS native driver ga prihvaca iako ga
# tipicno ne koristi za DHSS (RHA specificna konfiguracija).
#
# VAZNO za buduci Ansible mount zadatak: CephFS se NE mounta kao obican NFS
# (`mount -t nfs`) - treba ceph-fuse ili kernel cephfs client + ceph kljuc,
# razlicito od standardnog NFS mounta. To je odvojen (buduci) Ansible zadatak.
# ---------------------------------------------------------------------------
resource "openstack_sharedfilesystem_sharenetwork_v2" "dev" {
  name              = "${local.name_prefix}-sharenet-${var.dev_id}"
  neutron_net_id    = data.openstack_networking_network_v2.dev.id
  neutron_subnet_id = data.openstack_networking_subnet_v2.dev.id
}

resource "openstack_sharedfilesystem_share_v2" "backups" {
  name             = "${local.name_prefix}-backups-${var.dev_id}"
  share_proto      = "CEPHFS"
  size             = var.manila_share_size_gb
  share_network_id = openstack_sharedfilesystem_sharenetwork_v2.dev.id
  share_type       = var.manila_share_type != "" ? var.manila_share_type : null
}
