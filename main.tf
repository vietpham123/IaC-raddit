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

# Locate existing Packer Image
data "azurerm_image" "search" {
  name                = "raddit-base-ISO"
  resource_group_name = "HashiDemo"
}

output "image_id" {
  value = "/subscriptions/32cf0621-e31e-4501-b524-31a57248104a/resourceGroups/HashiDemo/providers/Microsoft.Compute/images/raddit-base-ISO"
}

# Create virtual network
resource "azurerm_virtual_network" "myterraformnetwork" {
  name                = "myVnet"
  address_space       = ["10.0.0.0/16"]
  location            = "centralus"
  resource_group_name = "HashiDemo"

  tags = {
    environment = "Terraform Demo"
  }
}

# Create subnet
resource "azurerm_subnet" "myterraformsubnet" {
  name                 = "mySubnet"
  resource_group_name  = "HashiDemo"
  virtual_network_name = azurerm_virtual_network.myterraformnetwork.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create Public IPs
resource "azurerm_public_ip" "myterraformpublicip" {
  name                = "myPublicIP"
  location            = "centralus"
  resource_group_name = "HashiDemo"
  allocation_method   = "Dynamic"
}



# Create Network Security Group and Rule
resource "azurerm_network_security_group" "myterraformnsg" {
  name                = "MyNetworkSecurityGroup"
  location            = "centralus"
  resource_group_name = "HashiDemo"

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
  location            = "centralus"
  resource_group_name = "HashiDemo"
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
  location              = "centralus"
  resource_group_name   = "HashiDemo"
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
    admin_username = "raddit-user"
    admin_password = "Hash!123"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  #  admin_ssh_key {
  #    username   = "raddit-user"
  #    public_key = file("~/.ssh/raddit-user.pub")
  #  }

  # Copy bash script to execute
  provisioner "file" {
    source = "https://github.com/vietpham123/IaC-raddit/blob/806412da1d56564dc1923eb8e3a1bbf1e1c22710/deploy.sh"
    destination = "/home/raddit-user"
    
    connection {
      type = "ssh"
      user = "raddit-user"
      password = "Hash!123"
      host = "azurerm_public_ip.myterraformpublicip.ip_address"
      port = "22"
      timeout = "1m"
    }
  }
  
  # change permission of bash script and execute
  provisioner "remote-exec" {
  inline = [
    "chmod +x /home/raddit-user/deploy.sh",
    "sudo /home/raddit-user/deploy.sh",
  ]
  }
}
output "public_ip" {
  value = azurerm_public_ip.myterraformpublicip.ip_address
}
