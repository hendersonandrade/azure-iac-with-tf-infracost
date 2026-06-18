output "storage_account_name" {
  description = "Nome da Storage Account criada."
  value       = azurerm_storage_account.this.name
}

output "storage_account_id" {
  description = "ID da Storage Account criada."
  value       = azurerm_storage_account.this.id
}

output "primary_blob_endpoint" {
  description = "Endpoint primário de blob."
  value       = azurerm_storage_account.this.primary_blob_endpoint
}
