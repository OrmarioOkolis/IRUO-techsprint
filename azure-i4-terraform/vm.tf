# ---------------------------------------------------------------------------
# Jump host / Bastion – jedini javno dostupan resurs
# ---------------------------------------------------------------------------
resource "azurerm_public_ip" "jump" {
  name                = "${local.name_prefix}-pip-jump-shared-01"
  location            = var.location
  resource_group_name = azurerm_resource_group.shared.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = merge(local.common_tags, { role = "jump" })
}

resource "azurerm_network_interface" "jump" {
  name                = "${local.name_prefix}-nic-jump-shared-01"
  location            = var.location
  resource_group_name = azurerm_resource_group.shared.name
  tags                = merge(local.common_tags, { role = "jump" })

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.jump.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.jump.id
  }
}

resource "azurerm_linux_virtual_machine" "jump" {
  name                  = "${local.name_prefix}-jump-shared-01"
  location              = var.location
  resource_group_name   = azurerm_resource_group.shared.name
  size                  = var.shared_vm_size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.jump.id]
  tags                  = merge(local.common_tags, { role = "jump" })

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = var.os_disk_size_gb
  }

  source_image_reference {
    publisher = var.image_publisher
    offer     = var.image_offer
    sku       = var.image_sku
    version   = var.image_version
  }

  plan {
    name      = var.image_sku
    product   = var.image_offer
    publisher = var.image_publisher
  }

  disable_password_authentication = true
}

# ---------------------------------------------------------------------------
# DevOps Lead VM – centralni admin, bez javnog IP-a, SSH kroz hub mrežu
# ---------------------------------------------------------------------------
resource "azurerm_network_interface" "lead" {
  name                = "${local.name_prefix}-nic-lead-shared-01"
  location            = var.location
  resource_group_name = azurerm_resource_group.shared.name
  tags                = merge(local.common_tags, { role = "lead" })

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.lead.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "lead" {
  name                  = "${local.name_prefix}-lead-shared-01"
  location              = var.location
  resource_group_name   = azurerm_resource_group.shared.name
  size                  = var.shared_vm_size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.lead.id]
  tags                  = merge(local.common_tags, { role = "lead" })

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = var.os_disk_size_gb
  }

  source_image_reference {
    publisher = var.image_publisher
    offer     = var.image_offer
    sku       = var.image_sku
    version   = var.image_version
  }

  plan {
    name      = var.image_sku
    product   = var.image_offer
    publisher = var.image_publisher
  }

  disable_password_authentication = true

  identity {
    type = "SystemAssigned"
  }
}

# ---------------------------------------------------------------------------
# Moodle VM-ovi – HA par po developeru (2 vCPU / 4 GiB, 2 diska)
# ---------------------------------------------------------------------------
resource "azurerm_network_interface" "moodle" {
  for_each = local.moodle_instances

  name                = "${local.dev_name_prefix[each.value.dev_id]}-nic-moodle-${each.key}"
  location            = each.value.dev_location
  resource_group_name = azurerm_resource_group.dev[each.value.dev_id].name
  tags                = merge(local.common_tags, { role = "moodle", "dev-id" = each.value.dev_id })

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.moodle[each.value.dev_id].id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface_application_security_group_association" "moodle" {
  for_each = local.moodle_instances

  network_interface_id          = azurerm_network_interface.moodle[each.key].id
  application_security_group_id = azurerm_application_security_group.moodle[each.value.dev_id].id
}

resource "azurerm_linux_virtual_machine" "moodle" {
  for_each = local.moodle_instances

  name                  = "${local.dev_name_prefix[each.value.dev_id]}-moodle-${each.key}"
  location              = each.value.dev_location
  resource_group_name   = azurerm_resource_group.dev[each.value.dev_id].name
  size                  = var.vm_size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.moodle[each.key].id]
  tags = merge(local.common_tags, {
    role     = "moodle"
    "dev-id" = each.value.dev_id
    owner    = each.value.dev_name
  })

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = var.os_disk_size_gb
  }

  source_image_reference {
    publisher = var.image_publisher
    offer     = var.image_offer
    sku       = var.image_sku
    version   = var.image_version
  }

  plan {
    name      = var.image_sku
    product   = var.image_offer
    publisher = var.image_publisher
  }

  disable_password_authentication = true

  identity {
    type = "SystemAssigned"
  }
}

# Data disk (drugi disk po zahtjevu zadatka) – Moodle podaci prije prelijevanja na objektnu pohranu
resource "azurerm_managed_disk" "moodle_data" {
  for_each = local.moodle_instances

  name                 = "${local.dev_name_prefix[each.value.dev_id]}-disk-moodle-${each.key}"
  location             = each.value.dev_location
  resource_group_name  = azurerm_resource_group.dev[each.value.dev_id].name
  storage_account_type = "StandardSSD_LRS"
  create_option        = "Empty"
  disk_size_gb         = var.data_disk_size_gb
  tags                 = merge(local.common_tags, { role = "moodle-data", "dev-id" = each.value.dev_id })
}

resource "azurerm_virtual_machine_data_disk_attachment" "moodle_data" {
  for_each = local.moodle_instances

  managed_disk_id    = azurerm_managed_disk.moodle_data[each.key].id
  virtual_machine_id = azurerm_linux_virtual_machine.moodle[each.key].id
  lun                = 0
  caching            = "ReadWrite"
}

# ---------------------------------------------------------------------------
# RBAC za Managed Identity Moodle VM-ova – least-privilege pristup pohrani
# (samo na vlastiti storage account / key vault, ne na cijelu pretplatu)
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "moodle_blob_access" {
  for_each = local.moodle_instances

  scope                = azurerm_storage_account.dev[each.value.dev_id].id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_virtual_machine.moodle[each.key].identity[0].principal_id
}

resource "azurerm_role_assignment" "moodle_keyvault_access" {
  for_each = local.moodle_instances

  scope                = azurerm_key_vault.dev[each.value.dev_id].id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_virtual_machine.moodle[each.key].identity[0].principal_id
}
