data "terraform_remote_state" "vm" {
  backend = "remote"
  
  config = {
    organization = "Hashi-Demo"
    workspaces = {
      name = "Raddit-VM"
    }
  }
}

resource "null_resource" "raddit" {
  provisioner "remote-exec" {
    inline = [
      "git clone https://github.com/Artemmkin/raddit.git",
      "cd ./raddit",
      "sudo bundle install",
      "sudo systemctl start raddit",
      "sudo systemctl enable raddit"
    ]

    connection {
      type        = "ssh"
      host        = data.terraform_remote_state.vm.outputs.public_ip
      user        = var.user_name
      password    = var.user_password
      timeout     = "1m"
    }
  }
}
