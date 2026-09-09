output "moodle_instance_ids" {
  value = { for k, i in openstack_compute_instance_v2.moodle : k => i.id }
}

output "moodle_fixed_ips" {
  value = { for k, p in data.openstack_networking_port_v2.moodle : k => p.all_fixed_ips }
}

output "data_volume_ids" {
  value = { for k, v in openstack_blockstorage_volume_v3.moodle_data : k => v.id }
}

output "object_container_name" {
  value = openstack_objectstorage_container_v1.moodle_objects.name
}

output "manila_share_id" {
  value = openstack_sharedfilesystem_share_v2.backups.id
}

output "manila_share_export_locations" {
  description = "NFS export putanje - koriste se za mount na Moodle instancama (Ansible)."
  value       = openstack_sharedfilesystem_share_v2.backups.export_locations
}
