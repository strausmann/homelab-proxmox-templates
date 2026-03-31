# =============================================================================
# Windows 11 Pro Packer Template fuer Proxmox VE
# =============================================================================
#
# Erstellt ein vollautomatisiertes Windows 11 Pro Template mit:
# - UEFI (OVMF) + TPM 2.0
# - VirtIO-Treiber (Netzwerk, Storage, Balloon)
# - Cloudbase-Init fuer Proxmox Cloud-Init Integration
# - Tailscale Client (vorinstalliert, nicht verbunden)
# - Windows Updates
# - Sysprep Generalisierung
#
# Build-Dauer: ~60-90 Minuten (abhaengig von Windows Updates)
# =============================================================================

packer {
  required_version = ">= 1.9.0"
  required_plugins {
    proxmox = {
      version = ">= 1.2.0"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

# =============================================================================
# Variablen
# =============================================================================

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
  default = "9300"
}
variable "vm_name" {
  type    = string
  default = "windows-11-packer"
}
variable "template_name" {
  type    = string
  default = "tmpl-windows-11"
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
  description = "Proxmox Storage-Pfad zur Windows ISO (z.B. datacenter:iso/Win11_DE_x64.iso)"
}
variable "virtio_iso_file" {
  type        = string
  default     = "datacenter:iso/virtio-win.iso"
  description = "Proxmox Storage-Pfad zur VirtIO-Treiber ISO"
}
variable "winrm_username" {
  type    = string
  default = "Administrator"
}
variable "winrm_password" {
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
  description = "Semantic Release Version (z.B. windows-11/v1.0.0)"
}

# =============================================================================
# Source: Proxmox ISO Builder fuer Windows 11
# =============================================================================

source "proxmox-iso" "windows" {
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_username
  token                    = var.proxmox_token
  insecure_skip_tls_verify = var.proxmox_skip_tls
  node                     = var.proxmox_node

  vm_id   = var.vm_id
  vm_name = var.vm_name

  # Boot-ISO: Windows 11 Installationsmedium
  boot_iso {
    iso_file = var.iso_file
    unmount  = true
  }

  # Zusaetzliche ISOs: VirtIO-Treiber und Autounattend
  additional_iso_files {
    iso_file     = var.virtio_iso_file
    unmount      = true
    type         = "sata"
    index        = "0"
    iso_checksum = "none"
  }

  additional_iso_files {
    cd_files = [
      "autounattend/Autounattend.xml",
      "scripts/enable-winrm.ps1"
    ]
    cd_label         = "OEMDRV"
    unmount          = true
    type             = "sata"
    index            = "1"
    iso_checksum     = "none"
    iso_storage_pool = "datacenter"
  }

  # Hardware
  cpu_type           = "host"
  cores              = var.vm_cpu_cores
  memory             = var.vm_memory
  ballooning_minimum = 0
  numa               = true
  os                 = "win11"
  machine            = "q35"
  bios               = "ovmf"
  scsi_controller    = "virtio-scsi-single"

  # EFI Disk (UEFI benoetigt EFI-Partition auf Storage)
  efi_config {
    efi_storage_pool  = var.vm_storage_pool
    efi_type          = "4m"
    pre_enrolled_keys = true
  }

  # TPM 2.0 (Windows 11 Pflicht)
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

  network_adapters {
    model    = "virtio"
    bridge   = var.vm_bridge
    firewall = false
    mtu      = 1500
  }

  # Cloud-Init Drive (fuer Cloudbase-Init nach Template-Erstellung)
  cloud_init              = true
  cloud_init_storage_pool = var.vm_storage_pool

  # VGA: std fuer Windows-Installation
  vga {
    type   = "std"
    memory = 64
  }

  qemu_agent = true

  # Boot-Konfiguration
  # Windows-Installer findet Autounattend.xml automatisch auf den gemounteten ISOs
  # UEFI Boot: "Press any key to boot from CD" erfordert Tastendruck
  # boot_wait muss lang genug sein damit die Meldung erscheint
  boot_wait = "3s"
  boot_command = [
    "<spacebar><wait><spacebar><wait><spacebar><wait><spacebar><wait><spacebar>"
  ]

  # WinRM Communicator (statt SSH)
  communicator   = "winrm"
  winrm_username = var.winrm_username
  winrm_password = var.winrm_password
  winrm_timeout  = "60m"
  winrm_use_ssl  = false
  winrm_insecure = true
  winrm_port     = 5985

  # Template
  template_name        = var.template_name
  template_description = join("\n", [
    "# Windows 11 Pro Cloud-Init Template",
    "",
    "| Eigenschaft | Wert |",
    "|---|---|",
    "| **Build-Datum** | ${formatdate("YYYY-MM-DD HH:mm", timestamp())} |",
    "| **Packer Version** | ${packer.version} |",
    "| **Windows ISO** | ${var.iso_file} |",
    "| **VirtIO ISO** | ${var.virtio_iso_file} |",
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
    "| **Cloud-Init** | Ja (Cloudbase-Init) |",
    "| **QEMU Agent** | Ja |",
    "| **Tailscale** | Vorinstalliert |",
    "",
    "## Links",
    "",
    "- [Repository](https://github.com/strausmann/homelab-proxmox-templates)",
    "- [GitLab Release](https://git.strausmann.de/strausmann/proxmox-templates/-/releases/${var.git_release_tag})",
    "- [GitLab Pipeline](https://git.strausmann.de/strausmann/proxmox-templates/-/pipelines/${var.ci_pipeline_id})",
  ])
  tags = "os-windows;v-11;packer;building;build-${formatdate("YYYYMMDD", timestamp())}"
}

# =============================================================================
# Build: Provisioner-Kette
# =============================================================================

build {
  name    = "windows-11"
  sources = ["source.proxmox-iso.windows"]

  # 1. VirtIO Guest Tools installieren (QEMU Guest Agent)
  provisioner "powershell" {
    script = "scripts/install-virtio-guest.ps1"
  }

  # 2. Windows Updates einspielen
  provisioner "powershell" {
    script = "scripts/install-updates.ps1"
  }

  # Neustart nach Windows Updates
  provisioner "windows-restart" {
    restart_timeout = "30m"
  }

  # Zweiter Update-Durchlauf (manche Updates erfordern Neustart + erneuten Scan)
  provisioner "powershell" {
    script = "scripts/install-updates.ps1"
  }

  # Neustart nach zweitem Update-Durchlauf
  provisioner "windows-restart" {
    restart_timeout = "15m"
  }

  # 3. Tailscale installieren
  provisioner "powershell" {
    script = "scripts/install-tailscale.ps1"
  }

  # 4. Cloudbase-Init installieren
  provisioner "powershell" {
    script = "scripts/install-cloudbase-init.ps1"
  }

  # 5. Template optimieren und aufraeumen
  provisioner "powershell" {
    script = "scripts/optimize-template.ps1"
  }

  # 6. Sysprep-Antwortdatei auf die VM kopieren
  provisioner "file" {
    source      = "scripts/sysprep-unattend.xml"
    destination = "C:\\Windows\\Temp\\sysprep-unattend.xml"
  }

  # 7. Sysprep ausfuehren (letzter Schritt — faehrt VM herunter)
  provisioner "powershell" {
    script = "scripts/sysprep.ps1"
  }
}
