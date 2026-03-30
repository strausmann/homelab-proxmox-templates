output "vm_id" {
  value       = proxmox_virtual_environment_vm.linux.vm_id
  description = "Proxmox VM ID"
}

output "vm_name" {
  value       = proxmox_virtual_environment_vm.linux.name
  description = "VM Hostname"
}

output "ipv4_address" {
  value       = try(proxmox_virtual_environment_vm.linux.ipv4_addresses[1][0], "pending")
  description = "IPv4 Adresse der VM"
}
