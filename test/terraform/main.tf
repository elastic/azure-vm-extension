provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "main" {
  name     = format("%s-%s", var.prefix, var.name)
  location = "Central US"
}

resource "azurerm_virtual_network" "main" {
  name                = format("%s-%s", var.prefix, var.name)
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet" "internal" {
  name                 = format("%s-%s", var.prefix, var.name)
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_network_interface" "main" {
  name                = format("%s-%s", var.prefix, var.name)
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  ip_configuration {
    name                          = format("%s-%s", var.prefix, var.name)
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_storage_account" "main" {
  count                    = (var.isExtension) ? 0 : 1
  name                     = "azvmext"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "main" {
  count                 = (var.isExtension) ? 0 : 1
  name                  = format("%s-%s", var.prefix, var.name)
  storage_account_name  = azurerm_storage_account.main[count.index].name
  container_access_type = "private"
}
