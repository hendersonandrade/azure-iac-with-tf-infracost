variable "name_suffix" {
  description = "Sufixo de nomes (<workload>-<environment>)."
  type        = string
}

variable "location" {
  description = "Região do Azure."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group de destino."
  type        = string
}

variable "sku_name" {
  description = "SKU do App Service Plan (B1, P1v3, ...)."
  type        = string
  default     = "B1"
}

variable "tags" {
  description = "Tags comuns."
  type        = map(string)
  default     = {}
}
