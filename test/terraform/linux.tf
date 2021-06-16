
## See https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine
resource "azurerm_linux_virtual_machine" "main" {
  count                           = var.isWindows ? 0 : 1
  name                            = var.vmName
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  size                            = "Standard_F2"
  admin_username                  = "adminuser"
  admin_password                  = "P@ssw0rd1234!"
  disable_password_authentication = false
  network_interface_ids = [
    azurerm_network_interface.main.id,
  ]

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
}

## See https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_machine_extension
resource "azurerm_virtual_machine_extension" "linux" {
  count                = var.isWindows ? 0 : 1
  name                 = "ElasticAgent.linux"
  virtual_machine_id   = azurerm_linux_virtual_machine.main.id
  publisher            = "Elastic"
  type                 = "ElasticAgent.linux"
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
