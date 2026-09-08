locals {
  # Storage account: mala slova/brojevi, bez crtica, <=24 znaka (Azure ogranicenje).
  # "st" + "techsprint" + "testing" + "dev01" = tocno 24 znaka.
  storage_account_names = {
    for k, v in local.developers_indexed :
    k => lower("st${var.project_name}${var.environment}${k}")
  }
}

# ---------------------------------------------------------------------------
# Storage Account po developeru – Blob (objektna pohrana) + Files (backup)
# Mrezni pristup ogranicen samo na vlastiti spoke subnet (least-privilege).
# ---------------------------------------------------------------------------
resource "azurerm_storage_account" "dev" {
  for_each = local.developers_indexed

  name                       = local.storage_account_names[each.key]
  resource_group_name        = azurerm_resource_group.dev[each.key].name
  location                   = each.value.location
  account_tier               = "Standard"
  account_replication_type   = "LRS"
  min_tls_version            = "TLS1_2"
  https_traffic_only_enabled = true

  network_rules {
    default_action             = "Deny"
    virtual_network_subnet_ids = [azurerm_subnet.moodle[each.key].id]
    ip_rules                   = [chomp(data.http.deployer_ip.response_body)]
    bypass                     = ["AzureServices"]
  }

  tags = merge(local.common_tags, { "dev-id" = each.key, owner = each.value.name })
}

resource "azurerm_storage_container" "moodledata" {
  for_each = local.developers_indexed

  name                  = "moodledata"
  storage_account_name  = azurerm_storage_account.dev[each.key].name
  container_access_type = "private"
}

resource "azurerm_storage_share" "backups" {
  for_each = local.developers_indexed

  name                 = "backups"
  storage_account_name = azurerm_storage_account.dev[each.key].name
  quota                = 100
}

# ---------------------------------------------------------------------------
# Key Vault po developeru – cuva storage account kljuc za SMB mount
# datotecne pohrane (Azure Files ne podrzava Managed Identity za SMB).
# ---------------------------------------------------------------------------
resource "azurerm_key_vault" "dev" {
  for_each = local.developers_indexed

  name                      = "kv-${substr(var.project_name, 0, 6)}-${each.key}"
  location                  = each.value.location
  resource_group_name       = azurerm_resource_group.dev[each.key].name
  tenant_id                 = data.azurerm_client_config.current.tenant_id
  sku_name                  = "standard"
  enable_rbac_authorization = true
  purge_protection_enabled  = false

  tags = merge(local.common_tags, { "dev-id" = each.key })
}

# Terraform (trenutni principal) treba pravo pisanja secreta u RBAC-based Key Vault
resource "azurerm_role_assignment" "kv_admin_current" {
  for_each = local.developers_indexed

  scope                = azurerm_key_vault.dev[each.key].id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_key_vault_secret" "storage_account_key" {
  for_each = local.developers_indexed

  name         = "storage-account-key"
  value        = azurerm_storage_account.dev[each.key].primary_access_key
  key_vault_id = azurerm_key_vault.dev[each.key].id

  depends_on = [azurerm_role_assignment.kv_admin_current]
}
