# Pfad B: Tang-Binding aus Template entfernt (Issue #213, 2026-04-14)
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
  default = "9050"
}
variable "vm_name" {
  type    = string
  default = "ubuntu-2404-luks-packer"
}
variable "template_name" {
  type    = string
  default = "tmpl-ubuntu-2404-luks"
}
variable "vm_cpu_cores" {
  type    = number
  default = 4
}
variable "vm_memory" {
  type    = number
  default = 4096
}
variable "vm_disk_size" {
  type    = string
  default = "50G"
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
variable "tang_url" {
  type        = string
  description = "Tang-Server URL fuer Clevis LUKS Auto-Unlock (z.B. http://172.16.60.20:7500)"
}
variable "luks_passphrase" {
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
  description = "Semantic Release Version (z.B. ubuntu-2404-luks/v1.0.0)"
}

source "proxmox-iso" "ubuntu-luks" {
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
  ballooning_minimum = 0
  numa               = true
  os                 = "l26"
  machine            = "q35"
  bios               = "ovmf"
  scsi_controller    = "virtio-scsi-single"

  # EFI Disk (UEFI benötigt EFI-Partition auf Storage)
  efi_config {
    efi_storage_pool  = var.vm_storage_pool
    efi_type          = "4m"
    pre_enrolled_keys = true
  }

  # TPM 2.0
  tpm_config {
    tpm_storage_pool = var.vm_storage_pool
    tpm_version      = "v2.0"
  }

  disks {
    disk_size    = var.vm_disk_size
    storage_pool = var.vm_storage_pool
    type         = "scsi"
    io_thread    = true
    discard      = true
    format       = "raw"
  }

  # Hinweis: Autonomer Boot via KEYFILE_PATTERN (Issue #214 Defekt #1).
  # Keyfile liegt als File in /etc/cryptsetup-keys.d/luks-keyfile.key und wird
  # durch cryptsetup-initramfs ins initramfs eingebettet. Keine Zweit-Disk noetig.
  # Grund: Ubuntu 24.04 cryptsetup-initramfs unterstuetzt keine Block-Device-Keyfiles
  # ohne Custom-Hooks — daher File-basiert (Recherche:
  # docs/research/2026-04-14-packer-luks-keyfile-reencrypt-workflow.md).
  # Post-Deployment (Ansible clevis-tang-bind):
  #   1. cryptsetup reencrypt → neuer Master Key
  #   2. clevis luks bind → Tang-Keyslot 3
  #   3. cryptsetup luksKillSlot 4 → Keyfile-Slot entfernen
  #   4. rm /etc/cryptsetup-keys.d/luks-keyfile.key
  #   5. update-initramfs -u -k all → Keyfile aus initramfs entfernt
  # → Produktiv-VM hat weder Keyfile-File noch Keyslot-4 noch Keyfile im initramfs.

  network_adapters {
    model    = "virtio"
    bridge   = var.vm_bridge
    firewall = false
    mtu      = 1500
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
    "# Ubuntu 24.04 LTS LUKS Cloud-Init Template",
    "",
    "| Eigenschaft | Wert |",
    "|---|---|",
    "| **Build-Datum** | ${formatdate("YYYY-MM-DD HH:mm", timestamp())} |",
    "| **Packer Version** | ${packer.version} |",
    "| **ISO** | ${var.iso_file} |",
    "| **Git Commit** | ${var.ci_commit_sha} |",
    "| **Git Branch/Tag** | ${var.ci_commit_ref} |",
    "| **Release Tag** | ${var.git_release_tag} |",
    "| **Pipeline ID** | ${var.ci_pipeline_id} |",
    "| **Trigger** | ${var.ci_pipeline_source} |",
    "| **Proxmox Node** | ${var.proxmox_node} |",
    "| **Storage** | ${var.vm_storage_pool} |",
    "| **Netzwerk** | ${var.vm_bridge} |",
    "| **CPU** | ${var.vm_cpu_cores} Cores |",
    "| **RAM** | ${var.vm_memory} MB |",
    "| **Disk** | ${var.vm_disk_size} |",
    "| **Cloud-Init** | Ja |",
    "| **QEMU Agent** | Ja |",
    "| **LUKS** | Ja (Clevis/Tang) |",
    "| **Tang** | ${var.tang_url} |",
    "",
    "## Links",
    "",
    "- [Repository](https://github.com/strausmann/homelab-proxmox-templates)",
    "- [GitLab Release](https://git.strausmann.de/strausmann/proxmox-templates/-/releases/${var.git_release_tag})",
    "- [GitLab Pipeline](https://git.strausmann.de/strausmann/proxmox-templates/-/pipelines/${var.ci_pipeline_id})",
  ])
  tags = "os-ubuntu-luks;v-2404;packer;building;build-${formatdate("YYYYMMDD", timestamp())}"
}

build {
  name    = "ubuntu-2404-luks"
  sources = ["source.proxmox-iso.ubuntu-luks"]

  # Warten bis Cloud-Init und unattended-upgrades abgeschlossen
  # WICHTIG: Alle Waits mit timeout — der Live-Installer hat gelegentlich
  # unattended-upgrades die auf shutdown-signal warten → Deadlock mit --wait.
  # Nach 60s hart weitermachen — Packer kommt sonst im Live-Installer in
  # ein SSH-idle-timeout (exakt 5 Min: Error uploading script / Exit 254).
  provisioner "shell" {
    inline = [
      "echo 'Warte auf Cloud-Init (max 60s)...'",
      "timeout 60 sudo cloud-init status --wait || echo '  cloud-init timeout oder error, fahre fort'",
      "echo 'Cloud-Init-Wait abgeschlossen.'",
      "echo 'Warte bis apt-Lock frei ist (max 120s)...'",
      "timeout 120 sh -c 'while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do echo \"  apt dpkg-lock gehalten, warte 10s...\"; sleep 10; done' || echo '  apt-Lock timeout, fahre trotzdem fort'",
      "timeout 60 sh -c 'while sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do echo \"  apt-lists gesperrt, warte 10s...\"; sleep 10; done' || echo '  apt-lists-Lock timeout, fahre trotzdem fort'",
      "echo 'apt-Lock-Wait abgeschlossen.'"
    ]
  }

  # Ansible Provisioner für Base-Setup
  #
  # ansible_remote_tmp explizit auf /tmp/.ansible-packer setzen:
  # Packer's Ansible-Provisioner nutzt ansonsten eine Konfiguration vom Runner-Host
  # (hhbuild01) die '~gitlab-runner/.ansible/tmp' als absoluten Pfad sendet —
  # existiert nicht auf der Target-VM und Gathering Facts schlaegt fehl.
  # /tmp ist auf jedem System vorhanden und packer-user hat Schreibrechte.
  provisioner "ansible" {
    playbook_file = "../../../ansible/playbooks/packer-hardening.yml"
    extra_arguments = [
      "--extra-vars", "packer_build=true",
      "-e", "ansible_remote_tmp=/tmp/.ansible-packer"
    ]
  }

  # LUKS-Verifikation + Template-Status (Pfad B: kein Clevis-Binding im Template)
  # Tang-Binding erfolgt post-deployment via Ansible-Role clevis-tang-bind
  provisioner "shell" {
    inline = [
      "echo '=== LUKS-Verifikation ==='",
      "sudo cryptsetup isLuks /dev/sda3 && echo 'LUKS2 auf /dev/sda3 verifiziert' || { echo 'FEHLER: /dev/sda3 ist kein LUKS-Volume'; exit 1; }",
      "sudo cryptsetup luksDump /dev/sda3 | grep -E 'Version|LUKS'",
      "echo '=== Template-Status: Keyslot-Belegung ==='",
      "sudo cryptsetup luksDump /dev/sda3 | grep -E '^  [0-9]+: luks2'",
      "echo 'Keyslots: 0=packer-build-only, 4=/dev/sdb Keyfile (Auto-Unlock beim Boot)'",
      "echo 'Post-Deployment (Ansible): Tang → Keyslot 3, Keyslot 4 removed, /dev/sdb detached'",
      "echo '=== LUKS-Verifikation abgeschlossen ==='"
    ]
  }

  # Fix: SSH Terminal ANSI Escape-Sequenzen bei Mausklick/Paste (Windows Terminal)
  # Deaktiviert SGR Mouse Tracking und Bracketed Paste systemweit
  provisioner "shell" {
    inline = [
      "echo 'set enable-bracketed-paste off' | sudo tee -a /etc/inputrc",
      "printf '%s\\n' \"printf '\\\\e[?1000l\\\\e[?1002l\\\\e[?1003l\\\\e[?1004l\\\\e[?1006l'\" | sudo tee -a /etc/bash.bashrc"
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
      "sudo userdel -r packer || true",
      "sudo apt-get clean",
      "sudo apt-get autoremove -y",
      "sudo rm -rf /tmp/* /var/tmp/*",
      "sudo fstrim --all || true",
      "sync"
    ]
  }
}
