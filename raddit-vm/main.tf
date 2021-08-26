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

data "terraform_remote_state" "network" {
  backend = "remote"
  
  config = {
    organization = "Hashi-Demo"
    workspaces = {
      name = "Raddit-Network"
    }
  }
}

# Locate existing Packer Image
data "azurerm_image" "search" {
  name                = "raddit-base-ISO"
  resource_group_name = var.hashirg
}

output "image_id" {
  value = "/subscriptions/32cf0621-e31e-4501-b524-31a57248104a/resourceGroups/HashiDemo/providers/Microsoft.Compute/images/raddit-base-ISO"
}

# Create Public IPs
resource "azurerm_public_ip" "hashipubip" {
  name                = "vpPublicIP"
  location            = var.hashiregion
  resource_group_name = var.hashirg
  allocation_method   = "Dynamic"
}

# Create Network Interface
resource "azurerm_network_interface" "hashinic" {
  name                = "vpNIC"
  location            = var.hashiregion
  resource_group_name = var.hashirg
  ip_configuration {
    name                          = "vpNicConfiguration"
    subnet_id                     = data.terraform_remote_state.network.outputs.subnet_name
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.hashipubip.id
  }
}

resource "azurerm_network_interface_security_group_association" "hashinicsgass" {
  network_interface_id      = azurerm_network_interface.hashinic.id
  network_security_group_id = data.terraform_remote_state.network.outputs.nsg
}

# Create virtual machine
resource "azurerm_virtual_machine" "radditvm" {
  name                  = "raddit-instance"
  location              = var.hashiregion
  resource_group_name   = var.hashirg
  network_interface_ids = azurerm_network_interface.hashinic.id
  vm_size               = "Standard_DS1_v2"

  delete_os_disk_on_termination    = "true"
  delete_data_disks_on_termination = "true"

  storage_image_reference {
    id = data.azurerm_image.search.id
  }

  storage_os_disk {
    name              = "raddit-instance"
    caching           = "ReadWrite"
    managed_disk_type = "Standard_LRS"
    create_option     = "FromImage"
  }

  os_profile {
    computer_name  = "raddit-instance"
    admin_username = var.user_name
    admin_password = var.user_password
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
}  

output "public_ip" {
 value = azurerm_public_ip.hashipubip.ip_address
}
