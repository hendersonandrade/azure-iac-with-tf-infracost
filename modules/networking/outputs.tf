output "vnet_id" {
  description = "ID da VNet."
  value       = azurerm_virtual_network.this.id
}

output "subnet_id" {
  description = "ID da subnet do workload (consumida pela VM)."
  value       = azurerm_subnet.workload.id
}
