data "terraform_remote_state" "vm" {
  backend = "remote"
  
  config = {
    organization = "Hashi-Demo"
    workspaces = {
      name = "Raddit-VM"
    }
  }
}

resource "null_resource" "one" {
  provisioner "remote-exec" {
    inline = "sudo apt update"
    
    connection {
      host        = data.terraform_remote_state.vm.outputs.public_ip
      type        = "ssh"
      user        = var.user_name
      password    = var.user_password
    }
  }
}

resource "null_resource" "two" {
  provisioner "remote_exec" {
    inline = "sudo apt install python3 -y"
    
    connection {
      host        = data.terraform_remote_state.vm.outputs.public_ip
      type        = "ssh"
      user        = var.user_name
      password    = var.user_password
    }
  depends on = [
    null_resource.one
  ]
  }
}
