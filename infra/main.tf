# =============================================================================
#  infra/main.tf
#  Composição da stack: um resource group + os quatro módulos.
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

# ---- Rede mínima que suporta a VM ----------------------------------------
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

# ---- 1 VM Linux -----------------------------------------------------------
module "vm" {
  source = "../modules/virtual-machine"

  name_suffix         = local.name_suffix
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = module.networking.subnet_id
  vm_size             = var.vm_size
  admin_username      = var.vm_admin_username
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
