terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.0"
    }
  }
}
# variables
provider "azurerm" {
  features {}
}

variable "user_name" {
  type = string
  default = ""
}

variable "user_password" {
  type = string
  default = ""
}

variable "hashirg" {
  type = string
  default = ""
}

variable "hashiregion" {
  type = string
  default = ""
}

# Locate existing Packer Image
data "azurerm_image" "search" {
  name                = "raddit-base-ISO"
  resource_group_name = var.hashirg
}

output "image_id" {
  value = "/subscriptions/32cf0621-e31e-4501-b524-31a57248104a/resourceGroups/HashiDemo/providers/Microsoft.Compute/images/raddit-base-ISO"
}

# Create virtual network
resource "azurerm_virtual_network" "myterraformnetwork" {
  name                = "myVnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.hashiregion
  resource_group_name = var.hashirg

  tags = {
    environment = "Terraform Demo"
  }
}

# Create subnet
resource "azurerm_subnet" "myterraformsubnet" {
  name                 = "mySubnet"
  resource_group_name  = var.hashirg
  virtual_network_name = azurerm_virtual_network.myterraformnetwork.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create Public IPs
resource "azurerm_public_ip" "myterraformpublicip" {
  name                = "myPublicIP"
  location            = var.hashiregion
  resource_group_name = var.hashirg
  allocation_method   = "Dynamic"
}



# Create Network Security Group and Rule
resource "azurerm_network_security_group" "myterraformnsg" {
  name                = "MyNetworkSecurityGroup"
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

# Create Network Interface
resource "azurerm_network_interface" "hashinic" {
  name                = "HashiNIC"
  location            = var.hashiregion
  resource_group_name = var.hashirg
  ip_configuration {
    name                          = "HashiNicConfiguration"
    subnet_id                     = azurerm_subnet.myterraformsubnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.myterraformpublicip.id
  }
  depends_on = [
    azurerm_subnet.myterraformsubnet
  ]
}

resource "azurerm_network_interface_security_group_association" "myterraformnicsgass" {
  network_interface_id      = azurerm_network_interface.hashinic.id
  network_security_group_id = azurerm_network_security_group.myterraformnsg.id
}

# Create virtual machine
resource "azurerm_virtual_machine" "radditvm" {
  name                  = "raddit-instance"
  location              = var.hashiregion
  resource_group_name   = var.hashirg
  network_interface_ids = [azurerm_network_interface.hashinic.id]
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

  #  admin_ssh_key {
  #    username   = "raddit-user"
  #    public_key = file("~/.ssh/raddit-user.pub")
  #  }

  provisioner "remote-exec" {
    inline = [
      "echo #!/bin/bash >> /home/raddit-user/deploy.sh",
      "echo set -e >> /home/raddit-user/deploy.sh",
      "echo ---- clone application repository ---- >> /home/raddit-user/deploy.sh",
      "echo git clone https://github.com/Artemmkin/raddit.git >> /home/raddit-user/deploy.sh",
      "echo ---- install dependent gems ---- >> /home/raddit-user/deploy.sh",
      "echo cd ./raddit >> /home/raddit-user/deploy.sh",
      "echo sudo bundle install" >> /home/raddit-user/deploy.sh",
      "echo ---- start the application ---- >> /home/raddit-user/deploy.sh",
      "echo sudo systemctl start raddit >> /home/raddit-user/deploy.sh",
      "echo sudo systemctl enable raddit >> /home/raddit-user/deploy.sh",
      "chmod +x /home/raddit-user/deploy.sh",
      "sudo /home/raddit-user/deploy.sh"
    ]
  }
}

output "public_ip" {
  value = azurerm_public_ip.myterraformpublicip.ip_address
}
