data "terraform_remote_state" "vm" {
  backend = "remote"
  
  config = {
    organization = "Hashi-Demo"
    workspaces = {
      name = "Raddit-VM"
    }
  }
}

provisioner "remote-exec" {
    inline = ["sudo apt update", "sudo apt install python3 -y", "echo Done!"]

    connection {
      host        = data.terraform_remote_state.vm.outputs.public_ip
      type        = "ssh"
      user        = var.user_name
      password    = var.user_password
    }
  }
