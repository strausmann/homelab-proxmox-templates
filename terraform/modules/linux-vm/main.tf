terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.66.0"
    }
  }
}

resource "proxmox_virtual_environment_vm" "linux" {
  name        = var.vm_name
  description = var.vm_description
  tags        = var.vm_tags
  node_name   = var.proxmox_node
  vm_id       = var.vm_id

  clone {
    vm_id = var.template_id
    full  = true
  }

  # CPU
  cpu {
    cores = var.cpu_cores
    type  = "host"
  }

  # RAM
  memory {
    dedicated = var.memory
  }

  # Netzwerk
  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  # Disk vergroessern (Template hat 20G, hier optional erweitern)
  dynamic "disk" {
    for_each = var.disk_size != null ? [1] : []
    content {
      interface    = "scsi0"
      size         = var.disk_size
      datastore_id = var.storage_pool
      file_format  = "raw"
      iothread     = true
      discard      = "on"
    }
  }

  # Cloud-Init
  initialization {
    ip_config {
      ipv4 {
        address = var.ip_address
        gateway = var.gateway
      }
    }

    dns {
      servers = var.dns_servers
      domain  = var.search_domain
    }

    user_account {
      username = var.ci_user
      keys     = var.ssh_keys
      password = var.ci_password
    }
  }

  # QEMU Guest Agent
  agent {
    enabled = true
  }

  # Lifecycle
  lifecycle {
    ignore_changes = [
      initialization[0].user_account[0].password,
    ]
  }
}
