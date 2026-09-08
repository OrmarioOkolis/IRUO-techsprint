# ---------------------------------------------------------------------------
# Interni Standard Load Balancer po developeru – balansira HA par Moodle VM-ova.
# Nema javnog IP-a (frontend je privatna adresa unutar spoke mreže) – jedini
# javno dostupan resurs u cijeloj okolini je jump host.
# ---------------------------------------------------------------------------
resource "azurerm_lb" "moodle" {
  for_each = local.developers_indexed

  name                = "${local.dev_name_prefix[each.key]}-lb-${each.key}"
  location            = each.value.location
  resource_group_name = azurerm_resource_group.dev[each.key].name
  sku                 = "Standard"
  tags                = merge(local.common_tags, { "dev-id" = each.key })

  frontend_ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.moodle[each.key].id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_lb_backend_address_pool" "moodle" {
  for_each = local.developers_indexed

  name            = "moodle-backend-${each.key}"
  loadbalancer_id = azurerm_lb.moodle[each.key].id
}

resource "azurerm_lb_probe" "moodle_http" {
  for_each = local.developers_indexed

  name                = "http-probe"
  loadbalancer_id     = azurerm_lb.moodle[each.key].id
  protocol            = "Tcp"
  port                = 80
  interval_in_seconds = 15
  number_of_probes    = 2
}

resource "azurerm_lb_rule" "moodle_http" {
  for_each = local.developers_indexed

  name                           = "http-rule"
  loadbalancer_id                = azurerm_lb.moodle[each.key].id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "internal"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.moodle[each.key].id]
  probe_id                       = azurerm_lb_probe.moodle_http[each.key].id
}

# Povezivanje svakog Moodle NIC-a s backend poolom njegovog developera
resource "azurerm_network_interface_backend_address_pool_association" "moodle" {
  for_each = local.moodle_instances

  network_interface_id    = azurerm_network_interface.moodle[each.key].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.moodle[each.value.dev_id].id
}
