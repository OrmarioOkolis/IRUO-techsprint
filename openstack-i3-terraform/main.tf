terraform {
  required_version = ">= 1.5.0"

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "openstack" {
  # Autentikacija preko OS_* env varijabli (source ~/admin-rc prije terraform apply
  # na workstationu) - namjerno bez hardkodiranih kredencijala u kodu, isti obrazac
  # kao openrc koji RHA vec generira.
}

locals {
  # Keystone nema data source za domenu - "default" je poznati/staticki ID
  # Default domene (Keystone konvencija), ne treba lookup.
  domain_id = "default"

  name_prefix = "${var.project_name}-${var.environment}"

  developers_indexed = {
    for idx, dev in var.developers :
    dev.id => merge(dev, { index = idx + 1 })
  }
}
