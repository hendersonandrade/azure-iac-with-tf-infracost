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

variable "subnet_id" {
  description = "ID da subnet onde a NIC da VM é criada."
  type        = string
}

variable "vm_size" {
  description = "SKU/tamanho da VM."
  type        = string
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "Usuário admin."
  type        = string
  default     = "azureuser"
}

variable "tags" {
  description = "Tags comuns."
  type        = map(string)
  default     = {}
}
