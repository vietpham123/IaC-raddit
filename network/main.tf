terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Create virtual network
resource "azurerm_virtual_network" "hashinet" {
  name                = "vpVnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.hashiregion
  resource_group_name = var.hashirg

  tags = {
    environment = "Terraform Demo"
  }
}

# Create subnet
resource "azurerm_subnet" "hashisubnet" {
  name                 = "vpSubnet"
  resource_group_name  = var.hashirg
  virtual_network_name = azurerm_virtual_network.hashinet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create Network Security Group and Rule
resource "azurerm_network_security_group" "hashinsg" {
  name                = "vpNetworkSecurityGroup"
  location            = var.hashiregion
  resource_group_name = var.hashirg

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "raddit"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9292"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

output "virtual_network" {
    value = azurerm_virtual_network.hashinet.name
}

output "subnet_name" {
    value = azurerm.subnet.hashisubnet.name
}

output "nsg" {
    value = azurerm_network_security_group.name
}
