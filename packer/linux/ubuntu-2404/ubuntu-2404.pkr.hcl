packer {
  required_version = ">= 1.9.0"
  required_plugins {
    proxmox = {
      version = ">= 1.1.8"
      source  = "github.com/hashicorp/proxmox"
    }
    ansible = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/ansible"
    }
  }
}

# --- Variablen ---

variable "proxmox_url" {
  type        = string
  description = "Proxmox API URL (z.B. https://hhpve01:8006/api2/json)"
}

variable "proxmox_username" {
  type        = string
  description = "Proxmox API User (z.B. terraform@pve)"
}

variable "proxmox_token" {
  type        = string
  sensitive   = true
  description = "Proxmox API Token"
}

variable "proxmox_node" {
  type        = string
  description = "Proxmox Node Name (z.B. hhpve01)"
}

variable "proxmox_skip_tls" {
  type        = bool
  default     = false
  description = "TLS-Verifikation ueberspringen (nur fuer Self-Signed Certs)"
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

variable "iso_url" {
  type    = string
  default = "https://releases.ubuntu.com/24.04/ubuntu-24.04.2-live-server-amd64.iso"
}

variable "iso_checksum" {
  type    = string
  default = "sha256:d6dab0c01a3a0bb4daaef8f33527b9bf91bf4ed9b97e516dc4ce8e8c3193c625"
}

variable "iso_storage_pool" {
  type    = string
  default = "local"
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

# --- Source ---

source "proxmox-iso" "ubuntu" {
  # Proxmox Verbindung
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_username
  token                    = var.proxmox_token
  insecure_skip_tls_verify = var.proxmox_skip_tls
  node                     = var.proxmox_node

  # VM Konfiguration
  vm_id   = var.vm_id
  vm_name = var.vm_name

  # ISO
  iso_url          = var.iso_url
  iso_checksum     = var.iso_checksum
  iso_storage_pool = var.iso_storage_pool
  unmount_iso      = true

  # Hardware
  cpu_type = "host"
  cores    = var.vm_cpu_cores
  memory   = var.vm_memory
  os       = "l26"

  # SCSI Controller
  scsi_controller = "virtio-scsi-single"

  # Disk
  disks {
    disk_size    = var.vm_disk_size
    storage_pool = var.vm_storage_pool
    type         = "scsi"
    io_thread    = true
    discard      = true
    format       = "raw"
  }

  # Netzwerk
  network_adapters {
    model    = "virtio"
    bridge   = var.vm_bridge
    firewall = false
  }

  # Cloud-Init Drive
  cloud_init              = true
  cloud_init_storage_pool = var.vm_storage_pool

  # Serial Console
  serials = ["socket"]
  vga {
    type = "serial0"
  }

  # QEMU Guest Agent
  qemu_agent = true

  # Autoinstall via HTTP-Server
  http_directory = "http"
  boot_wait      = "5s"
  boot_command = [
    "c<wait>",
    "linux /casper/vmlinuz --- autoinstall ds=nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ <enter><wait>",
    "initrd /casper/initrd<enter><wait>",
    "boot<enter><wait10>"
  ]

  # SSH
  communicator           = "ssh"
  ssh_username           = var.ssh_username
  ssh_password           = var.ssh_password
  ssh_timeout            = "30m"
  ssh_handshake_attempts = 10

  # Template
  template_name        = var.template_name
  template_description = "Ubuntu 24.04 LTS Cloud-Init Template — Packer ${formatdate("YYYY-MM-DD", timestamp())}"
}

# --- Build ---

build {
  name    = "ubuntu-2404"
  sources = ["source.proxmox-iso.ubuntu"]

  # Warten bis Cloud-Init abgeschlossen
  provisioner "shell" {
    inline = [
      "echo 'Warte auf Cloud-Init...'",
      "cloud-init status --wait",
      "echo 'Cloud-Init abgeschlossen.'"
    ]
  }

  # Ansible Provisioner fuer Hardening
  provisioner "ansible" {
    playbook_file = "../../../ansible/playbooks/packer-hardening.yml"
    extra_arguments = [
      "--extra-vars", "packer_build=true"
    ]
  }

  # Cleanup vor Template-Erstellung
  provisioner "shell" {
    inline = [
      # Cloud-Init zuruecksetzen
      "sudo cloud-init clean",
      # Machine-ID entfernen (wird beim naechsten Start neu generiert)
      "sudo truncate -s 0 /etc/machine-id",
      "sudo rm -f /var/lib/dbus/machine-id",
      "sudo ln -s /etc/machine-id /var/lib/dbus/machine-id",
      # SSH Host Keys entfernen
      "sudo rm -f /etc/ssh/ssh_host_*",
      # Bash History leeren
      "sudo truncate -s 0 /root/.bash_history",
      "truncate -s 0 ~/.bash_history",
      # Packer User Sudoers entfernen (wird nicht mehr benoetigt)
      "sudo rm -f /etc/sudoers.d/packer",
      # APT Cache leeren
      "sudo apt-get clean",
      "sudo apt-get autoremove -y",
      # Temp-Dateien
      "sudo rm -rf /tmp/* /var/tmp/*",
      # Disk zeroing fuer bessere Kompression
      "sudo dd if=/dev/zero of=/EMPTY bs=1M 2>/dev/null || true",
      "sudo rm -f /EMPTY",
      "sync"
    ]
  }
}
