# =============================================================================
#  infra/providers.tf
#  Versões fixadas + backend REMOTO no Azure Storage criado pelo bootstrap Bicep.
#
#  Os valores do bloco `backend` NÃO podem usar variáveis — por isso o backend
#  é parcialmente configurado aqui e o restante é passado em tempo de init com
#  `-backend-config` (ver .github/workflows/terraform.yml e o README).
# =============================================================================

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  backend "azurerm" {
    # resource_group_name  = "rg-tfstate-prod"          -> via -backend-config
    # storage_account_name = "sttfstateprod0001"        -> via -backend-config
    container_name = "tfstate"
    key            = "azure-iac-with-tf-infracost.tfstate"
    use_oidc       = true # autentica o backend com o token OIDC do GitHub Actions
  }
}

provider "azurerm" {
  features {}
  use_oidc = true # sem secrets: o login é via Workload Identity Federation
}
