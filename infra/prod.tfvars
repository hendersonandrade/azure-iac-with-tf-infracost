# =============================================================================
#  infra/prod.tfvars — ambiente de produção (SKUs maiores)
# =============================================================================
environment     = "prod"
location        = "brazilsouth"
workload        = "iacdemo"
address_space   = "10.50.0.0/16"
subnet_prefix   = "10.50.1.0/24"
app_service_sku = "P1v3"

tags = {
  owner = "henderson"
  tier  = "prod"
}
