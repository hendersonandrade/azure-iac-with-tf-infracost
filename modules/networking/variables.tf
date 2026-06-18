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

variable "address_space" {
  description = "CIDR da VNet."
  type        = string
}

variable "subnet_prefix" {
  description = "CIDR da subnet do workload."
  type        = string
}

variable "tags" {
  description = "Tags comuns."
  type        = map(string)
  default     = {}
}
