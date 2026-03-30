# --- Proxmox Verbindung ---

variable "proxmox_url" {
  type        = string
  description = "Proxmox API URL"
}

variable "proxmox_username" {
  type        = string
  description = "Proxmox API User"
}

variable "proxmox_token" {
  type        = string
  sensitive   = true
  description = "Proxmox API Token"
}

variable "proxmox_skip_tls" {
  type    = bool
  default = true
}

# --- SSH ---

variable "ssh_public_key" {
  type        = string
  description = "SSH Public Key fuer VMs"
}
