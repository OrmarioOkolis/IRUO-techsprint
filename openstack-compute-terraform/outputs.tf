output "jump_instance_id" {
  value = openstack_compute_instance_v2.jump.id
}

output "lead_instance_id" {
  value = openstack_compute_instance_v2.lead.id
}

output "jump_fixed_ip" {
  description = "Interni IP jump hosta na hub mrezi. Javni (floating) IP je vec poznat iz openstack-i2-terraform outputa jump_floating_ip - port je preuzet gotov, nije ovdje ponovno kreiran."
  value       = data.openstack_networking_port_v2.jump.all_fixed_ips
}

output "flavor_id" {
  value = openstack_compute_flavor_v2.app.id
}

output "keypair_name" {
  value = openstack_compute_keypair_v2.admin.name
}
