output "jump_floating_ip" {
  description = "Javna (floating) IP jump hosta - jedina javno dostupna tocka ulaza."
  value       = openstack_networking_floatingip_v2.jump.address
}

output "jump_port_id" {
  description = "ID hub-mreznog porta jump hosta - koristi compute modul za attach VM-a."
  value       = openstack_networking_port_v2.jump.id
}

output "lead_port_id" {
  description = "ID hub-mreznog porta DevOps Lead VM-a - koristi compute modul za attach VM-a."
  value       = openstack_networking_port_v2.lead.id
}

output "jump_to_dev_port_ids" {
  description = "Mapa dev_id -> ID jump hostovog dodatnog porta na toj dev mrezi (drugi NIC jump hosta, koristi compute modul)."
  value       = { for k, p in openstack_networking_port_v2.jump_to_dev : k => p.id }
}

output "moodle_port_ids" {
  description = "Mapa 'dev01-01' -> ID porta te Moodle instance (koristi compute modul za attach VM-a)."
  value       = { for k, p in openstack_networking_port_v2.moodle : k => p.id }
}

output "moodle_port_fixed_ips" {
  description = "Mapa 'dev01-01' -> fixna privatna IP te Moodle instance."
  value       = { for k, p in openstack_networking_port_v2.moodle : k => p.all_fixed_ips[0] }
}

output "moodle_lb_vip_ips" {
  description = "Mapa dev_id -> VIP adresa Octavia LB-a (wwwroot za Moodle config)."
  value       = { for k, lb in openstack_lb_loadbalancer_v2.moodle : k => lb.vip_address }
}

output "moodle_storage_port_ids" {
  description = "Mapa 'dev01-01' -> ID drugog NIC porta (storage mreza, Ceph mon pristup za Manila) te Moodle instance."
  value       = { for k, p in openstack_networking_port_v2.moodle_storage : k => p.id }
}

output "dev_network_ids" {
  description = "Mapa dev_id -> ID Neutron mreze developera (koristi compute modul)."
  value       = { for k, n in openstack_networking_network_v2.dev : k => n.id }
}

output "dev_security_group_ids" {
  description = "Mapa dev_id -> ID security grupe za Moodle instance (koristi compute modul)."
  value       = { for k, sg in openstack_networking_secgroup_v2.moodle : k => sg.id }
}
