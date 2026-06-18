# =============================================================================
#  modules/app-service — 1 App Service Plan (Linux) + 1 Linux Web App.
#  System-assigned identity habilitada; HTTPS-only; runtime Node por padrão.
# =============================================================================

resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
}

resource "azurerm_service_plan" "this" {
  name                = "asp-${var.name_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  sku_name            = var.sku_name
  tags                = var.tags
}

resource "azurerm_linux_web_app" "this" {
  name                = "app-${var.name_suffix}-${random_string.suffix.result}"
  location            = var.location
  resource_group_name = var.resource_group_name
  service_plan_id     = azurerm_service_plan.this.id
  https_only          = true
  tags                = var.tags

  identity {
    type = "SystemAssigned"
  }

  site_config {
    minimum_tls_version = "1.2"
    application_stack {
      node_version = "20-lts"
    }
  }

  app_settings = {
    WEBSITE_RUN_FROM_PACKAGE = "1"
  }
}
