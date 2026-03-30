terraform {
  required_version = ">= 1.8.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.66.0"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox_url
  username = var.proxmox_username
  api_token = var.proxmox_token
  insecure = var.proxmox_skip_tls

  ssh {
    agent = true
  }
}
