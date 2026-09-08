terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.116"
    }
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}
data "azurerm_subscription" "current" {}

locals {
  name_prefix = "${var.project_name}-${var.environment}-${var.location_abbr}"

  developers_indexed = {
    for idx, dev in var.developers :
    dev.id => merge(dev, { index = idx + 1 })
  }

  dev_name_prefix = {
    for dev_id, dev in local.developers_indexed :
    dev_id => "${var.project_name}-${var.environment}-${lookup(var.region_abbr, dev.location, dev.location)}"
  }

  # Ako nije eksplicitno zadan principal_id za developera/leada, koristi
  # trenutno prijavljeni principal (demo/test mod - vidi opis varijable).
  developer_principal_ids = {
    for dev_id, dev in local.developers_indexed :
    dev_id => lookup(var.developer_principal_ids, dev_id, data.azurerm_client_config.current.object_id)
  }

  lead_principal_id = var.lead_principal_id != "" ? var.lead_principal_id : data.azurerm_client_config.current.object_id
}

# ---------------------------------------------------------------------------
# Postojeci Resource Groupovi (kreirani u azure-i4-terraform) - dohvaceni
# preko data source-a po imenu, ne remote-state ovisnoscu (namjerno odvojen
# Terraform modul/state).
# ---------------------------------------------------------------------------
data "azurerm_resource_group" "shared" {
  name = "${local.name_prefix}-rg-shared"
}

data "azurerm_resource_group" "dev" {
  for_each = local.developers_indexed

  name = "${local.dev_name_prefix[each.key]}-rg-${each.key}"
}
