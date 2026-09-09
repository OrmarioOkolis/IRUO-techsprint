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
# LIVE TESTIRANO 9.9.2026, dva ispravljena nalaza redom:
# 1. `share_proto = "NFS"` je pukao - "Invalid share protocol provided: NFS.
#    Available protocols: ['CEPHFS']". Ovaj RHA CL110 sandbox ima Manila
#    backend konfiguriran SAMO za CephFS (native driver, provjereno preko
#    `manila pool-list --detail`: storage_protocol=CEPHFS, vendor=Ceph,
#    driver_handles_share_servers=False). Ispravljeno na "CEPHFS".
# 2. Prvi pokusaj je JOS uvijek pukao s praznim `host` (scheduler nije
#    dodijelio backend) - uzrok: na sandboxu NIJE postojao NIJEDAN share type
#    (`manila type-list` prazan), pa scheduler nema kriterij za usmjeravanje.
#    Kreiran administrativno preko `manila type-create techsprint-cephfs False`
#    (DHSS=False, mora se poklapati s poolom) - proslijedjen kao
#    var.manila_share_type. NAPOMENA za CSV/provision.py: ovaj share type MORA
#    postojati PRIJE prvog apply-a ovog modula (jednokratni admin setup, kao
#    custom flavor - trenutno rucno kreiran, kandidat da se prebaci u
#    openstack-compute-terraform kao openstack_sharedfilesystem_sharetype_v2
#    ako provider tu resource podrzava).
# 3. S ispravnim protokolom i share_type-om, JOS uvijek je pukao -
#    "Driver does not expect share-network to be provided with current
#    configuration" - jer je driver_handles_share_servers=False (CephFS native
#    driver NE koristi share network uopce, za razliku od DHSS=True drivera
#    poput generic NFS). Sharenetwork resurs je zato UKLONJEN (ne samo
#    neiskoristen - aktivno je uzrokovao grešku ako se proslijedi).
#
# VAZNO za buduci Ansible mount zadatak: CephFS se NE mounta kao obican NFS
# (`mount -t nfs`) - treba ceph-fuse ili kernel cephfs client + ceph kljuc,
# razlicito od standardnog NFS mounta. To je odvojen (buduci) Ansible zadatak.
# ---------------------------------------------------------------------------
resource "openstack_sharedfilesystem_share_v2" "backups" {
  name        = "${local.name_prefix}-backups-${var.dev_id}"
  share_proto = "CEPHFS"
  size        = var.manila_share_size_gb
  share_type  = var.manila_share_type != "" ? var.manila_share_type : null
}

# ---------------------------------------------------------------------------
# Access rule - bez ovoga NIJEDAN klijent ne moze mountati share (Manila
# default-deny, za razliku od Neutron security grupa gdje je pristup network-
# scoped). CephFS native driver koristi "cephx" access_type - Ceph-ova vlastita
# autentikacija, ne IP-based kao NFS. access_key je computed (Manila ga sam
# generira) - Ansible ga cita preko `terraform output` pri mountanju, ne ide u
# git (isto nacelo kao Azure Files kljuc iz Key Vaulta - kredencijal se ne
# hardkodira, dohvaca se programski).
# ---------------------------------------------------------------------------
resource "openstack_sharedfilesystem_share_access_v2" "backups" {
  share_id     = openstack_sharedfilesystem_share_v2.backups.id
  access_type  = "cephx"
  access_to    = "${local.name_prefix}-${var.dev_id}"
  access_level = "rw"
}
