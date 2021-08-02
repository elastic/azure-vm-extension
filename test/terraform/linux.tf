
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
    publisher = var.publisher
    offer     = var.offer
    sku       = var.sku
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  ## TODO: while no debug file are provided let's mock one
  provisioner "file" {
    content     = "I'm a file, let's debug it"
    destination = var.debugFile
  }

  ## Cat the content for debugging purposes
  provisioner "remote-exec" {
    inline = [
      "cat ${var.debugFile}"
    ]
  }
}

## See https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_machine_extension
resource "azurerm_virtual_machine_extension" "linux" {
  count                = (var.isWindows && var.isExtension) ? 0 : 1
  name                 = "ElasticAgent.linux"
  virtual_machine_id   = azurerm_linux_virtual_machine.main[count.index].id
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
