variable "vm_name" {
  type        = string
  description = "VM Hostname"
}

variable "vm_description" {
  type        = string
  default     = "Managed by Terraform"
}

variable "vm_tags" {
  type        = list(string)
  default     = ["terraform", "linux"]
}

variable "vm_id" {
  type        = number
  default     = null
  description = "VM ID (null = automatisch)"
}

variable "proxmox_node" {
  type        = string
  description = "Proxmox Node (z.B. PVE1)"
}

variable "template_id" {
  type        = number
  description = "VM ID des Cloud-Init Templates"
}

variable "cpu_cores" {
  type    = number
  default = 2
}

variable "memory" {
  type    = number
  default = 2048
  description = "RAM in MB"
}

variable "disk_size" {
  type    = number
  default = null
  description = "Disk-Groesse in GB (null = Template-Groesse beibehalten)"
}

variable "storage_pool" {
  type    = string
  default = "local-lvm"
}

variable "network_bridge" {
  type    = string
  default = "vnet60"
}

variable "ip_address" {
  type        = string
  description = "IP-Adresse mit CIDR (z.B. 10.0.1.10/24) oder 'dhcp'"
}

variable "gateway" {
  type    = string
  default = null
}

variable "dns_servers" {
  type    = list(string)
  default = ["1.1.1.1", "8.8.8.8"]
}

variable "search_domain" {
  type    = string
  default = "home.lab"
}

variable "ci_user" {
  type    = string
  default = "ubuntu"
}

variable "ci_password" {
  type      = string
  default   = null
  sensitive = true
}

variable "ssh_keys" {
  type        = list(string)
  description = "SSH Public Keys fuer Cloud-Init"
}
