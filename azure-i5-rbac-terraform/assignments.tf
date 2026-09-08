# ---------------------------------------------------------------------------
# Developer: custom rola, scoped ISKLJUCIVO na vlastiti Resource Group.
# Developer dev01 ne moze pozvati start/stop na resurse u dev02 RG-u (ili
# obrnuto) - to Azure RBAC provjerava na razini scope-a dodjele, neovisno o
# mreznoj izolaciji koju vec imamo u I4.
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "developer" {
  for_each = local.developers_indexed

  scope              = data.azurerm_resource_group.dev[each.key].id
  role_definition_id = azurerm_role_definition.developer.role_definition_resource_id
  principal_id       = local.developer_principal_ids[each.key]
}

# ---------------------------------------------------------------------------
# Lead: ugradjena "Virtual Machine Contributor" na razini CIJELE subscription
# (obuhvaca shared RG + sve developer RG-ove, ukljucujuci buduce ako ih CSV
# skripta doda) - "Voditelj tima moze upravljati stanjem svih virtualki".
# SSH pristup kroz Bastion/Jump host je vec omogucen na mreznoj razini u
# azure-i4-terraform (NSG dopusta SSH s hub CIDR-a na sve spoke mreze); ovo
# je Azure API/portal razina kontrole (RBAC), odvojena od SSH pristupa.
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "lead_all_vms" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = local.lead_principal_id
}
