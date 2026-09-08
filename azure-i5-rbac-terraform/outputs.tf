output "developer_role_id" {
  value = azurerm_role_definition.developer.role_definition_resource_id
}

output "developer_role_assignments" {
  description = "Scope (RG) na koji je svaki developer dobio TechSprint Developer rolu."
  value = {
    for k, v in azurerm_role_assignment.developer : k => {
      scope        = v.scope
      principal_id = v.principal_id
    }
  }
}

output "lead_role_assignment" {
  value = {
    scope        = azurerm_role_assignment.lead_all_vms.scope
    principal_id = azurerm_role_assignment.lead_all_vms.principal_id
    role         = "Virtual Machine Contributor"
  }
}
