output "vm_id" {
  description = "ID da VM."
  value       = azurerm_linux_virtual_machine.this.id
}

output "private_ip_address" {
  description = "IP privado da VM."
  value       = azurerm_network_interface.this.private_ip_address
}

output "ssh_private_key_pem" {
  description = "Chave SSH privada gerada (apenas para o lab — proteja em produção)."
  value       = tls_private_key.ssh.private_key_pem
  sensitive   = true
}
