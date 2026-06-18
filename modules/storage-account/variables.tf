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

variable "account_tier" {
  description = "Tier da Storage Account."
  type        = string
  default     = "Standard"
}

variable "replication_type" {
  description = "Tipo de replicação (LRS, GRS, ...)."
  type        = string
  default     = "LRS"
}

variable "tags" {
  description = "Tags comuns."
  type        = map(string)
  default     = {}
}
