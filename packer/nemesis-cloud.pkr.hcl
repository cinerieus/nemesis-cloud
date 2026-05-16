packer {
  required_plugins {
    qemu = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

variable "arch_cloud_image_url" {
  type    = string
  default = "https://geo.mirror.pkgbuild.com/images/latest/Arch-Linux-x86_64-cloudimg.qcow2"
}

variable "arch_cloud_image_checksum" {
  type    = string
  default = "none"
}

variable "output_directory" {
  type    = string
  default = "output/nemesis-cloud"
}

variable "disk_size" {
  type    = string
  default = "40G"
}

variable "memory" {
  type    = number
  default = 8192
}

variable "cpus" {
  type    = number
  default = 4
}

variable "ssh_username" {
  type    = string
  default = "packer"
}

variable "ssh_password" {
  type      = string
  default   = "packer"
  sensitive = true
}

source "qemu" "arch_cloud" {
  iso_url      = var.arch_cloud_image_url
  iso_checksum = var.arch_cloud_image_checksum

  disk_image       = true
  format           = "qcow2"
  output_directory = var.output_directory
  vm_name          = "nemesis-cloud.qcow2"
  disk_size        = var.disk_size

  accelerator = "kvm"
  headless    = true
  memory      = var.memory
  cpus        = var.cpus

  ssh_username = var.ssh_username
  ssh_password = var.ssh_password
  ssh_timeout  = "30m"

  cd_label = "cidata"
  cd_content = {
    "meta-data" = <<-EOF
      instance-id: nemesis-packer
      local-hostname: nemesis-packer
    EOF
    "user-data" = <<-EOF
      #cloud-config
      preserve_hostname: false
      hostname: nemesis-packer
      ssh_pwauth: true
      users:
        - default
        - name: ${var.ssh_username}
          groups: [wheel]
          shell: /bin/bash
          sudo: ["ALL=(ALL) NOPASSWD:ALL"]
          lock_passwd: false
      chpasswd:
        expire: false
        users:
          - name: ${var.ssh_username}
            password: ${var.ssh_password}
            type: text
    EOF
  }

  qemuargs = [
    ["-serial", "mon:stdio"],
    ["-device", "virtio-net,netdev=user.0"],
  ]
}

build {
  name    = "nemesis-cloud"
  sources = ["source.qemu.arch_cloud"]

  provisioner "shell" {
    inline = [
      "sudo pacman -Sy --noconfirm --needed rsync cloud-init",
      "rm -rf /tmp/nemesis-cloud",
      "mkdir -p /tmp/nemesis-cloud",
    ]
  }

  provisioner "file" {
    source      = "../"
    destination = "/tmp/nemesis-cloud/"
  }

  provisioner "shell" {
    environment_vars = [
      "NEMESIS_REPO_URL=",
      "NEMESIS_REPO_REF=main",
    ]
    inline = [
      "cd /tmp/nemesis-cloud",
      "sudo ./init.sh --force-config --install-only",
      "sudo /usr/local/share/nemesis-cloud/scripts/nemesis-firstboot",
    ]
    expect_disconnect = false
    timeout           = "90m"
  }

  provisioner "shell" {
    inline = [
      "sudo systemctl disable gdm.service gnome-remote-desktop.service || true",
      "sudo rm -rf /tmp/nemesis-cloud",
      "sudo passwd -l ${var.ssh_username} || true",
      "sudo rm -f /etc/ssh/ssh_host_*",
      "sudo truncate -s 0 /etc/machine-id || true",
      "sudo rm -f /etc/hostname /etc/machine-info",
      "sudo rm -f /var/lib/systemd/random-seed",
      "sudo cloud-init clean --logs --machine-id",
      "sudo rm -rf /var/lib/cloud/instances/* /var/lib/cloud/instance",
      "sudo rm -f /etc/cloud/cloud-init.disabled",
      "for unit in cloud-init-local.service cloud-init.service cloud-config.service cloud-final.service; do if systemctl list-unit-files \"$unit\" --no-legend >/dev/null 2>&1; then sudo systemctl enable \"$unit\"; fi; done",
      "sudo rm -f /root/.bash_history /home/*/.bash_history || true",
      "sudo rm -rf /tmp/* /var/tmp/*",
      "sudo rm -f /var/log/pacman.log",
      "sudo journalctl --rotate || true",
      "sudo journalctl --vacuum-time=1s || true",
      "sudo pacman -Scc --noconfirm || true",
      "nohup sudo sh -c 'sleep 3; userdel -f -r ${var.ssh_username} || true' >/dev/null 2>&1 &",
      "sudo sync",
    ]
    timeout = "15m"
  }
}
