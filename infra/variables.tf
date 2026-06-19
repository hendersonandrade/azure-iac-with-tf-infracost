# =============================================================================
#  infra/variables.tf
#  Entradas da stack. Valores concretos por ambiente em dev.tfvars / prod.tfvars.
# =============================================================================

variable "environment" {
  description = "Nome curto do ambiente (dev, prod). Compõe o naming dos recursos."
  type        = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment deve ser 'dev' ou 'prod'."
  }
}

variable "location" {
  description = "Região do Azure onde os recursos são criados."
  type        = string
  default     = "brazilsouth"
}

variable "workload" {
  description = "Nome curto do workload — entra na convenção de nomes."
  type        = string
  default     = "iacdemo"
}

variable "address_space" {
  description = "CIDR da VNet do workload."
  type        = string
  default     = "10.40.0.0/16"
}

variable "subnet_prefix" {
  description = "CIDR da subnet do workload."
  type        = string
  default     = "10.40.1.0/24"
}

variable "app_service_sku" {
  description = "SKU do App Service Plan."
  type        = string
  default     = "B1"
}

variable "tags" {
  description = "Tags comuns aplicadas a todos os recursos."
  type        = map(string)
  default     = {}
}
