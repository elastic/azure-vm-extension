provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "main" {
  name     = format("%s-%s", var.prefix, "az-vm-ext")
  location = "Central US"
}

resource "azurerm_virtual_network" "main" {
  name                = format("%s-%s", var.prefix, "az-vm-ext")
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet" "internal" {
  name                 = format("%s-%s", var.prefix, "az-vm-ext")
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_network_interface" "main" {
  name                = format("%s-%s", var.prefix, "az-vm-ext")
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  ip_configuration {
    name                          = format("%s-%s", var.prefix, "az-vm-ext")
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "main" {
  name                            = format("%s-%s", var.prefix, "az-vm-ext")
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  size                            = "Standard_F2"
  admin_username                  = "adminuser"
  admin_password                  = "P@ssw0rd1234!"
  network_interface_ids = [
    azurerm_network_interface.main.id,
  ]

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }
}

resource "azurerm_virtual_machine_extension" "main" {
  name                 = "ElasticAgent.windows"
  virtual_machine_id   = azurerm_windows_virtual_machine.main.id
  publisher            = "Elastic"
  type                 = "ElasticAgent.windows"
  type_handler_version = "1.0"

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
