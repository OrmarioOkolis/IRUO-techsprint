# ---------------------------------------------------------------------------
# Hub VNet: jump host (javno dostupan) + DevOps Lead (interno)
# ---------------------------------------------------------------------------
resource "azurerm_virtual_network" "hub" {
  name                = "${local.name_prefix}-net-shared"
  location            = var.location
  resource_group_name = azurerm_resource_group.shared.name
  address_space       = [var.hub_vnet_cidr]
  tags                = local.common_tags
}

resource "azurerm_subnet" "jump" {
  name                 = "snet-jump"
  resource_group_name  = azurerm_resource_group.shared.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [cidrsubnet(var.hub_vnet_cidr, 3, 0)] # .0/27
}

resource "azurerm_subnet" "lead" {
  name                 = "snet-lead"
  resource_group_name  = azurerm_resource_group.shared.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [cidrsubnet(var.hub_vnet_cidr, 3, 1)] # .32/27
}

resource "azurerm_network_security_group" "jump" {
  name                = "${local.name_prefix}-nsg-jump"
  location            = var.location
  resource_group_name = azurerm_resource_group.shared.name
  tags                = local.common_tags

  security_rule {
    name                       = "AllowSSHInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.jump_host_allowed_ssh_cidr
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "lead" {
  name                = "${local.name_prefix}-nsg-lead"
  location            = var.location
  resource_group_name = azurerm_resource_group.shared.name
  tags                = local.common_tags
  # Nema dodatnih inbound pravila – Lead VM inicira SSH prema developer mrežama,
  # ne prima nikakav promet izvana (default NSG DenyAllInbound je dovoljan).
}

resource "azurerm_subnet_network_security_group_association" "jump" {
  subnet_id                 = azurerm_subnet.jump.id
  network_security_group_id = azurerm_network_security_group.jump.id
}

resource "azurerm_subnet_network_security_group_association" "lead" {
  subnet_id                 = azurerm_subnet.lead.id
  network_security_group_id = azurerm_network_security_group.lead.id
}

# ---------------------------------------------------------------------------
# Spoke VNet po developeru – izolirana mreža, peering samo prema hubu
# ---------------------------------------------------------------------------
resource "azurerm_virtual_network" "spoke" {
  for_each = local.developers_indexed

  name                = "${local.dev_name_prefix[each.key]}-net-${each.key}"
  location            = each.value.location
  resource_group_name = azurerm_resource_group.dev[each.key].name
  address_space       = ["${var.spoke_vnet_cidr_prefix}.${each.value.index}.0/24"]
  tags                = merge(local.common_tags, { "dev-id" = each.key, owner = each.value.name, region = each.value.location })
}

resource "azurerm_subnet" "moodle" {
  for_each = local.developers_indexed

  name                 = "snet-moodle-${each.key}"
  resource_group_name  = azurerm_resource_group.dev[each.key].name
  virtual_network_name = azurerm_virtual_network.spoke[each.key].name
  address_prefixes     = ["${var.spoke_vnet_cidr_prefix}.${each.value.index}.0/24"]
  service_endpoints    = ["Microsoft.Storage"]
}

# ---------------------------------------------------------------------------
# NAT Gateway po developeru – JEDINI izlaz na Internet za Moodle VM-ove.
# Standard interni LB ne pruza outbound konektivnost, a VM-ovi nemaju javni
# IP (zahtjev: "nema izravnog javnog pristupa ostalim instancama"). NAT
# Gateway je outbound-only – ima javni IP, ali NIKAD ne prima dolazni promet,
# pa ne krsi taj zahtjev, a istovremeno zadovoljava "izlaz na Internet radi
# preuzimanja paketa".
# ---------------------------------------------------------------------------
resource "azurerm_public_ip" "nat" {
  for_each = local.developers_indexed

  name                = "${local.dev_name_prefix[each.key]}-pip-nat-${each.key}"
  location            = each.value.location
  resource_group_name = azurerm_resource_group.dev[each.key].name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = merge(local.common_tags, { "dev-id" = each.key, role = "nat-outbound" })
}

resource "azurerm_nat_gateway" "dev" {
  for_each = local.developers_indexed

  name                = "${local.dev_name_prefix[each.key]}-nat-${each.key}"
  location            = each.value.location
  resource_group_name = azurerm_resource_group.dev[each.key].name
  sku_name            = "Standard"
  tags                = merge(local.common_tags, { "dev-id" = each.key })
}

resource "azurerm_nat_gateway_public_ip_association" "dev" {
  for_each = local.developers_indexed

  nat_gateway_id       = azurerm_nat_gateway.dev[each.key].id
  public_ip_address_id = azurerm_public_ip.nat[each.key].id
}

resource "azurerm_subnet_nat_gateway_association" "moodle" {
  for_each = local.developers_indexed

  subnet_id      = azurerm_subnet.moodle[each.key].id
  nat_gateway_id = azurerm_nat_gateway.dev[each.key].id
}

# Application Security Group za grupiranje Moodle NIC-ova (asocijacija se radi u vm.tf)
resource "azurerm_application_security_group" "moodle" {
  for_each = local.developers_indexed

  name                = "${local.dev_name_prefix[each.key]}-asg-moodle-${each.key}"
  location            = each.value.location
  resource_group_name = azurerm_resource_group.dev[each.key].name
  tags                = merge(local.common_tags, { "dev-id" = each.key })
}

resource "azurerm_network_security_group" "spoke" {
  for_each = local.developers_indexed

  name                = "${local.dev_name_prefix[each.key]}-nsg-${each.key}"
  location            = each.value.location
  resource_group_name = azurerm_resource_group.dev[each.key].name
  tags                = merge(local.common_tags, { "dev-id" = each.key })

  # SSH dopušten isključivo iz hub mreže (jump host + Lead VM) – least privilege
  security_rule {
    name                       = "AllowSSHFromHub"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.hub_vnet_cidr
    destination_address_prefix = "*"
  }

  # HTTP interno, samo unutar vlastite spoke mreže (Moodle-Moodle + LB health probe)
  security_rule {
    name                                       = "AllowHTTPWithinSpoke"
    priority                                   = 110
    direction                                  = "Inbound"
    access                                     = "Allow"
    protocol                                   = "Tcp"
    source_port_range                          = "*"
    destination_port_range                     = "80"
    source_address_prefix                      = "${var.spoke_vnet_cidr_prefix}.${each.value.index}.0/24"
    destination_application_security_group_ids = [azurerm_application_security_group.moodle[each.key].id]
  }

  # Azure LB health probe dolazi s ove service tag adrese
  security_rule {
    name                                       = "AllowAzureLBProbe"
    priority                                   = 120
    direction                                  = "Inbound"
    access                                     = "Allow"
    protocol                                   = "Tcp"
    source_port_range                          = "*"
    destination_port_range                     = "80"
    source_address_prefix                      = "AzureLoadBalancer"
    destination_application_security_group_ids = [azurerm_application_security_group.moodle[each.key].id]
  }
}

resource "azurerm_subnet_network_security_group_association" "spoke" {
  for_each = local.developers_indexed

  subnet_id                 = azurerm_subnet.moodle[each.key].id
  network_security_group_id = azurerm_network_security_group.spoke[each.key].id
}

# ---------------------------------------------------------------------------
# VNet peering: hub <-> svaki spoke. Spoke-spoke peering NE postoji (izolacija).
# ---------------------------------------------------------------------------
resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  for_each = local.developers_indexed

  name                      = "peer-shared-to-${each.key}"
  resource_group_name       = azurerm_resource_group.shared.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke[each.key].id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  for_each = local.developers_indexed

  name                      = "peer-${each.key}-to-shared"
  resource_group_name       = azurerm_resource_group.dev[each.key].name
  virtual_network_name      = azurerm_virtual_network.spoke[each.key].name
  remote_virtual_network_id = azurerm_virtual_network.hub.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
  allow_gateway_transit        = false
  use_remote_gateways          = false
}
