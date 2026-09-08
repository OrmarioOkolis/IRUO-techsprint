output "jump_host_public_ip" {
  description = "Javni IP jump hosta – jedina ulazna točka u okolinu."
  value       = azurerm_public_ip.jump.ip_address
}

output "jump_host_private_ip" {
  value = azurerm_network_interface.jump.private_ip_address
}

output "lead_vm_private_ip" {
  value = azurerm_network_interface.lead.private_ip_address
}

output "moodle_vm_private_ips" {
  description = "Privatne IP adrese svih Moodle instanci, po developeru."
  value = {
    for k, v in azurerm_network_interface.moodle : k => v.private_ip_address
  }
}

output "moodle_lb_frontend_ips" {
  description = "Privatne IP adrese internih load balancera, po developeru."
  value = {
    for k, v in azurerm_lb.moodle : k => v.frontend_ip_configuration[0].private_ip_address
  }
}

output "storage_account_names" {
  value = local.storage_account_names
}

output "key_vault_names" {
  value = { for k, v in azurerm_key_vault.dev : k => v.name }
}

output "resource_group_names" {
  value = merge(
    { shared = azurerm_resource_group.shared.name },
    { for k, v in azurerm_resource_group.dev : k => v.name }
  )
}

output "developer_regions" {
  description = "Azure regija po developeru (multi-region raspored zbog vCPU kvote po regiji)."
  value       = { for k, v in local.developers_indexed : k => v.location }
}

output "hub_region" {
  value = var.location
}
