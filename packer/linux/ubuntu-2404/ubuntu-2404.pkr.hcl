packer {
  required_version = ">= 1.9.0"
  required_plugins {
    proxmox = {
      version = ">= 1.2.0"
      source  = "github.com/hashicorp/proxmox"
    }
    ansible = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/ansible"
    }
  }
}

variable "proxmox_url" { type = string }
variable "proxmox_username" { type = string }
variable "proxmox_token" {
  type      = string
  sensitive = true
}
variable "proxmox_node" { type = string }
variable "proxmox_skip_tls" {
  type    = bool
  default = false
}
variable "vm_id" {
  type    = string
  default = "9000"
}
variable "vm_name" {
  type    = string
  default = "ubuntu-2404-packer"
}
variable "template_name" {
  type    = string
  default = "tmpl-ubuntu-2404"
}
variable "vm_cpu_cores" {
  type    = number
  default = 2
}
variable "vm_memory" {
  type    = number
  default = 2048
}
variable "vm_disk_size" {
  type    = string
  default = "20G"
}
variable "vm_storage_pool" {
  type    = string
  default = "local-lvm"
}
variable "vm_bridge" {
  type    = string
  default = "vmbr0"
}
variable "iso_file" {
  type        = string
  description = "Proxmox Storage-Pfad zur ISO (z.B. datacenter:iso/ubuntu-24.04.4-live-server-amd64.iso)"
}
variable "ssh_username" {
  type    = string
  default = "packer"
}
variable "ssh_password" {
  type      = string
  sensitive = true
  default   = "packer-build-only"
}

# Build-Metadaten (werden von CI/CD Pipeline gesetzt)
variable "ci_pipeline_id" {
  type        = string
  default     = "manual"
  description = "GitLab CI Pipeline ID"
}
variable "ci_pipeline_source" {
  type        = string
  default     = "manual"
  description = "Trigger-Quelle (manual, schedule, push, web)"
}
variable "ci_commit_sha" {
  type        = string
  default     = "unknown"
  description = "Git Commit SHA"
}
variable "ci_commit_ref" {
  type        = string
  default     = "main"
  description = "Git Branch oder Tag"
}
variable "git_release_tag" {
  type        = string
  default     = "unreleased"
  description = "Semantic Release Version (z.B. ubuntu-2404/v1.0.0)"
}

source "proxmox-iso" "ubuntu" {
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_username
  token                    = var.proxmox_token
  insecure_skip_tls_verify = var.proxmox_skip_tls
  node                     = var.proxmox_node

  vm_id   = var.vm_id
  vm_name = var.vm_name

  # ISO — neues boot_iso Block-Format (kein Deprecation Warning)
  boot_iso {
    iso_file = var.iso_file
    unmount  = true
  }

  # Hardware
  cpu_type        = "host"
  cores           = var.vm_cpu_cores
  memory          = var.vm_memory
  os              = "l26"
  scsi_controller = "virtio-scsi-single"

  disks {
    disk_size    = var.vm_disk_size
    storage_pool = var.vm_storage_pool
    type         = "scsi"
    io_thread    = true
    discard      = true
    format       = "raw"
  }

  network_adapters {
    model    = "virtio"
    bridge   = var.vm_bridge
    firewall = false
  }

  # Cloud-Init Drive
  cloud_init              = true
  cloud_init_storage_pool = var.vm_storage_pool

  # VGA: std fuer ISO-Installation (GRUB braucht normalen Display)
  vga {
    type   = "std"
    memory = 32
  }

  qemu_agent = true

  # Autoinstall via HTTP-Server
  http_directory    = "http"
  http_bind_address = "0.0.0.0"
  http_port_min     = 8000
  http_port_max     = 8100
  boot_wait         = "10s"

  # Boot-Command: GRUB-Eintrag editieren und Autoinstall-Parameter anhaengen
  boot_command = [
    "<esc><esc><esc><esc>e<wait>",
    "<down><down><down><end>",
    " autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/",
    "<f10>"
  ]

  # SSH
  communicator           = "ssh"
  ssh_username           = var.ssh_username
  ssh_password           = var.ssh_password
  ssh_timeout            = "30m"
  ssh_handshake_attempts = 20

  # Template
  template_name        = var.template_name
  template_description = join("\n", [
    "Ubuntu 24.04 LTS Cloud-Init Template",
    "=====================================",
    "Build-Datum:     ${formatdate("YYYY-MM-DD HH:mm", timestamp())}",
    "Packer Version:  ${packer.version}",
    "ISO:             ${var.iso_file}",
    "Git Commit:      ${var.ci_commit_sha}",
    "Git Branch/Tag:  ${var.ci_commit_ref}",
    "Release Tag:     ${var.git_release_tag}",
    "Pipeline ID:     ${var.ci_pipeline_id}",
    "Trigger:         ${var.ci_pipeline_source}",
    "Proxmox Node:    ${var.proxmox_node}",
    "Storage:         ${var.vm_storage_pool}",
    "Netzwerk:        ${var.vm_bridge}",
    "CPU:             ${var.vm_cpu_cores} Cores",
    "RAM:             ${var.vm_memory} MB",
    "Disk:            ${var.vm_disk_size}",
    "Cloud-Init:      Ja",
    "QEMU Agent:      Ja",
    "Repo:            https://github.com/strausmann/homelab-proxmox-templates",
    "GitLab Release:  https://git.strausmann.de/strausmann/proxmox-templates/-/releases/${var.git_release_tag}",
    "GitLab Pipeline: https://git.strausmann.de/strausmann/proxmox-templates/-/pipelines/${var.ci_pipeline_id}",
  ])
  tags = "latest;os-ubuntu;v-2404;packer;build-${formatdate("YYYYMMDD", timestamp())}"
}

build {
  name    = "ubuntu-2404"
  sources = ["source.proxmox-iso.ubuntu"]

  # Warten bis Cloud-Init abgeschlossen
  provisioner "shell" {
    inline = [
      "echo Warte auf Cloud-Init...",
      "cloud-init status --wait",
      "echo Cloud-Init abgeschlossen."
    ]
  }

  # Cleanup vor Template-Erstellung
  provisioner "shell" {
    inline = [
      "sudo cloud-init clean --logs",
      "sudo truncate -s 0 /etc/machine-id",
      "sudo rm -f /var/lib/dbus/machine-id",
      "sudo ln -s /etc/machine-id /var/lib/dbus/machine-id",
      "sudo rm -f /etc/ssh/ssh_host_*",
      "sudo truncate -s 0 /root/.bash_history",
      "truncate -s 0 ~/.bash_history",
      "sudo rm -f /etc/sudoers.d/packer",
      "sudo apt-get clean",
      "sudo apt-get autoremove -y",
      "sudo rm -rf /tmp/* /var/tmp/*",
      "sudo fstrim --all || true",
      "sync"
    ]
  }
}
