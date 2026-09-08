output "shared_project_id" {
  description = "ID shared projekta (jump host + lead)."
  value       = openstack_identity_project_v3.shared.id
}

output "dev_project_ids" {
  description = "Mapa dev_id -> OpenStack project ID (koristi ih openstack-i2-terraform preko data source-a)."
  value       = { for k, p in openstack_identity_project_v3.dev : k => p.id }
}

output "dev_project_names" {
  description = "Mapa dev_id -> OpenStack project name."
  value       = { for k, p in openstack_identity_project_v3.dev : k => p.name }
}

output "developer_usernames" {
  description = "Mapa dev_id -> Keystone username."
  value       = { for k, u in openstack_identity_user_v3.developer : k => u.name }
}

output "developer_passwords" {
  description = "Mapa dev_id -> generirana lozinka (CSV provisioning distribuira developerima)."
  value       = { for k, p in random_password.developer : k => p.result }
  sensitive   = true
}

output "lead_username" {
  description = "Keystone username DevOps Leada."
  value       = openstack_identity_user_v3.lead.name
}

output "lead_password" {
  description = "Generirana lozinka DevOps Leada."
  value       = random_password.lead.result
  sensitive   = true
}
