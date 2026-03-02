output "vm_id" {
  description = "The ID of the created VM"
  value       = proxmox_virtual_environment_vm.vm.id
}

output "vm_name" {
  description = "The name of the created VM"
  value       = proxmox_virtual_environment_vm.vm.name
}

output "node_name" {
  description = "The Proxmox node where the VM is deployed"
  value       = proxmox_virtual_environment_vm.vm.node_name
}

output "ipv4_addresses" {
  description = "IPv4 addresses of the VM"
  value       = proxmox_virtual_environment_vm.vm.ipv4_addresses
}

output "ipv6_addresses" {
  description = "IPv6 addresses of the VM"
  value       = proxmox_virtual_environment_vm.vm.ipv6_addresses
}

output "mac_addresses" {
  description = "MAC addresses of the VM"
  value       = proxmox_virtual_environment_vm.vm.mac_addresses
}