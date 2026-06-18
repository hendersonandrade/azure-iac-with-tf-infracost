# =============================================================================
#  modules/storage-account — 1 Storage Account endurecida (workload)
#  Sufixo aleatório garante unicidade global do nome.
# =============================================================================

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

locals {
  # Storage account: 3-24 chars, só minúsculas/dígitos. Removemos hifens.
  sa_name = substr(
    lower(replace("st${var.name_suffix}${random_string.suffix.result}", "-", "")),
    0,
    24,
  )
}

resource "azurerm_storage_account" "this" {
  name                            = local.sa_name
  resource_group_name             = var.resource_group_name
  location                        = var.location
  account_tier                    = var.account_tier
  account_replication_type        = var.replication_type
  account_kind                    = "StorageV2"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  https_traffic_only_enabled      = true
  tags                            = var.tags

  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = 7
    }
  }
}

resource "azurerm_storage_container" "data" {
  name                  = "data"
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "private"
}
