# =============================================================================
#  infra/dev.tfvars — ambiente de desenvolvimento (barato, descartável)
# =============================================================================
environment     = "dev"
location        = "brazilsouth"
workload        = "iacdemo"
address_space   = "10.40.0.0/16"
subnet_prefix   = "10.40.1.0/24"
vm_size         = "Standard_B2s"
app_service_sku = "B1"

tags = {
  owner = "henderson"
  tier  = "nonprod"
}
