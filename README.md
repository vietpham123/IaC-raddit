# IaC-raddit

This is a Project to create an example website where you can make posts using Infrastructure as Code within Azure using Terraform/Terraform Cloud.  The project has been divided up into 3 distinct modules, so that deleting VMs does not remove network infrastructure that has been created that could affect other VMs

1) network folder - creates virtual network, subnet, and network security group
2) raddit-vm folder - creates Ubuntu VM, public IP, network interface, network securit group association using a pre-created image from Packer
3) configuration - runs commands with remote exec to do configuration management

all components are linked into Terraform Cloud and each run triggers the next piece of the full IaC flow.
