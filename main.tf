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

# Create Public IPs
resource "azurerm_public_ip" "hashipubip" {
  name                = "vpPublicIP"
  location            = var.hashiregion
  resource_group_name = var.hashirg
  allocation_method   = "Dynamic"
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

# Create Network Interface
resource "azurerm_network_interface" "hashinic" {
  name                = "vpNIC"
  location            = var.hashiregion
  resource_group_name = var.hashirg
  ip_configuration {
    name                          = "vpNicConfiguration"
    subnet_id                     = azurerm_subnet.hashisubnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.hashipubip.id
  }
  depends_on = [
    azurerm_subnet.hashisubnet
  ]
}

resource "azurerm_network_interface_security_group_association" "hashinicsgass" {
  network_interface_id      = azurerm_network_interface.hashinic.id
  network_security_group_id = azurerm_network_security_group.hashinsg.id
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
}

output "public_ip" {
 value = azurerm_public_ip.hashipubip.ip_address
}


resource "null_resource" "fileupload" {
  provisioner "file" {
    source = "https://github.com/vietpham123/IaC-raddit/blob/a964fee4c6f5b70d0aacd8986e3231f6c00e3c5c/deploy.sh"
    destination = "/home/raddit-user/deploy.sh"
  }

  connection {
    host = "${azurerm_public_ip.hashipubip.ip_address}"
    type = "ssh"
    user = "${var.user_name}"
    password = "${var.user_password}"
    agent = "false"
  }
}
