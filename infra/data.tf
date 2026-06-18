# =============================================================================
#  infra/data.tf
#  Data sources — leem o que já existe em vez de criar. Aqui:
#    - azurerm_client_config: tenant/subscription/object id do identity logado,
#      útil para policies, Key Vault access, diagnósticos.
#    - azurerm_subscription:  metadados da subscription corrente (nome, id).
# =============================================================================

data "azurerm_client_config" "current" {}

data "azurerm_subscription" "current" {}
