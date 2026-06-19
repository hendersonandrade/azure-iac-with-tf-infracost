# =============================================================================
#  infra/main.tf
#  Composição da stack: um resource group + os três módulos.
#  Convenção de nomes: <recurso>-<workload>-<environment> (ex.: vnet-iacdemo-dev).
# =============================================================================

locals {
  name_suffix = "${var.workload}-${var.environment}"

  common_tags = merge(
    {
      workload    = var.workload
      environment = var.environment
      managedBy   = "terraform"
      costCenter  = "finops-lab"
    },
    var.tags,
  )
}

resource "azurerm_resource_group" "this" {
  name     = "rg-${local.name_suffix}"
  location = var.location
  tags     = local.common_tags
}

# ---- Rede base (VNet + subnet + NSG) -------------------------------------
module "networking" {
  source = "../modules/networking"

  name_suffix         = local.name_suffix
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = var.address_space
  subnet_prefix       = var.subnet_prefix
  tags                = local.common_tags
}

# ---- 1 Storage Account ----------------------------------------------------
module "storage" {
  source = "../modules/storage-account"

  name_suffix         = local.name_suffix
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.common_tags
}

# ---- 1 App Service --------------------------------------------------------
module "app_service" {
  source = "../modules/app-service"

  name_suffix         = local.name_suffix
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  sku_name            = var.app_service_sku
  tags                = local.common_tags
}
