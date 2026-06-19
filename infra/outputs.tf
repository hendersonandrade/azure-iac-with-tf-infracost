# =============================================================================
#  infra/outputs.tf
# =============================================================================

output "resource_group_name" {
  description = "Resource group que contém a stack."
  value       = azurerm_resource_group.this.name
}

output "storage_account_name" {
  description = "Nome da Storage Account do workload."
  value       = module.storage.storage_account_name
}

output "app_service_default_hostname" {
  description = "Hostname público do App Service."
  value       = module.app_service.default_hostname
}

output "subscription_id" {
  description = "Subscription corrente (via data source)."
  value       = data.azurerm_subscription.current.subscription_id
}
