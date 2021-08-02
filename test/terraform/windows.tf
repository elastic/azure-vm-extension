resource "azurerm_windows_virtual_machine" "main" {
  count                           = var.isWindows ? 1 : 0
  name                            = var.vmName
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  size                            = "Standard_F2"
  admin_username                  = "adminuser"
  admin_password                  = "P@ssw0rd1234!"
  network_interface_ids = [
    azurerm_network_interface.main.id,
  ]

  source_image_reference {
    publisher = var.publisher
    offer     = var.offer
    sku       = var.sku
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }
}

resource "azurerm_virtual_machine_extension" "windows" {
  count                = (var.isWindows && var.isExtension) ? 1 : 0
  name                 = "ElasticAgent.windows"
  virtual_machine_id   = azurerm_windows_virtual_machine.main[count.index].id
  publisher            = "Elastic"
  type                 = "ElasticAgent.windows"
  type_handler_version = "1.1"

  protected_settings = <<PROTECTED_SETTINGS
    {
        "password": "${var.password}"
    }
PROTECTED_SETTINGS

  settings = <<SETTINGS
    {
        "username": "${var.username}",
        "cloudId": "${var.cloudId}"
    }
SETTINGS
}

