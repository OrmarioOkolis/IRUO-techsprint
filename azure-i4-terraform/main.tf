terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.116"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

# Javna IP adresa stroja koji pokreće Terraform – dodaje se na storage account
# allowlist (uz VNet subnet) da Terraform sam smije kreirati container/share.
data "http" "deployer_ip" {
  url = "https://api.ipify.org?format=text"
}

# ---------------------------------------------------------------------------
# Konvencija imenovanja: <projekt>-<environment>-<regija>-<uloga>-<identifikator>[-<redni-broj>]
# vidi docs/I1-elementi-i-troskovi.md
# ---------------------------------------------------------------------------
locals {
  # naming prefix za HUB resurse (jump, lead, shared RG) – uvijek u var.location
  name_prefix = "${var.project_name}-${var.environment}-${var.location_abbr}"

  common_tags = {
    project      = var.project_name
    environment  = var.environment
    "managed-by" = "terraform"
  }

  # developeri indeksirani od 1 (koristi se za treći oktet spoke CIDR-a)
  developers_indexed = {
    for idx, dev in var.developers :
    dev.id => merge(dev, { index = idx + 1 })
  }

  # naming prefix po developeru – koristi NJEGOVU regiju, ne hub regiju
  # (multi-region: svaki developer je u svojoj regiji zbog vCPU kvote po regiji)
  dev_name_prefix = {
    for dev_id, dev in local.developers_indexed :
    dev_id => "${var.project_name}-${var.environment}-${lookup(var.region_abbr, dev.location, dev.location)}"
  }

  # flattened mapa "dev01-01", "dev01-02", "dev02-01", ... za HA par Moodle VM-ova
  moodle_instances = merge([
    for dev_id, dev in local.developers_indexed : {
      for n in range(1, var.moodle_instances_per_dev + 1) :
      "${dev_id}-${format("%02d", n)}" => {
        dev_id       = dev_id
        dev_index    = dev.index
        dev_name     = dev.name
        dev_location = dev.location
        instance_n   = n
      }
    }
  ]...)
}

# ---------------------------------------------------------------------------
# Resource Group hijerarhija (I5): jedan shared RG + jedan RG po developeru
# ---------------------------------------------------------------------------
resource "azurerm_resource_group" "shared" {
  name     = "${local.name_prefix}-rg-shared"
  location = var.location
  tags     = merge(local.common_tags, { role = "shared" })
}

resource "azurerm_resource_group" "dev" {
  for_each = local.developers_indexed

  name     = "${local.dev_name_prefix[each.key]}-rg-${each.key}"
  location = each.value.location
  tags     = merge(local.common_tags, { role = "developer", owner = each.value.name, "dev-id" = each.key })
}
