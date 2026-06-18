output "app_service_name" {
  description = "Nome do Linux Web App."
  value       = azurerm_linux_web_app.this.name
}

output "default_hostname" {
  description = "Hostname público padrão do Web App."
  value       = azurerm_linux_web_app.this.default_hostname
}

output "principal_id" {
  description = "Object ID da managed identity do Web App."
  value       = azurerm_linux_web_app.this.identity[0].principal_id
}
