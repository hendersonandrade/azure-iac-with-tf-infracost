// =============================================================================
//  bootstrap/main.bicep
//  Provisiona o BACKEND REMOTO de state do Terraform.
//
//  Por que Bicep e não Terraform?
//  O Terraform precisa de um backend (Storage Account + container) para guardar
//  o tfstate ANTES de poder rodar. Criar esse backend com o próprio Terraform é
//  um problema de "ovo e galinha": o state que descreveria o backend teria de
//  morar... no backend que ainda não existe. Bicep é nativo do Azure, é
//  idempotente e NÃO guarda state local — perfeito para o bootstrap único.
//
//  Escopo: subscription (cria o resource group + os recursos dentro dele).
//  Deploy: ver bootstrap/deploy.sh
// =============================================================================

targetScope = 'subscription'

@description('Região do Azure para o backend de state.')
param location string = 'brazilsouth'

@description('Nome do resource group que hospeda o backend de state.')
param resourceGroupName string = 'rg-tfstate-prod'

@description('Nome da Storage Account do state. Deve ser globalmente único, 3-24 chars minúsculos.')
@minLength(3)
@maxLength(24)
param storageAccountName string

@description('Nome do container de blobs que guarda os arquivos .tfstate.')
param containerName string = 'tfstate'

@description('Tags aplicadas a todos os recursos.')
param tags object = {
  workload: 'terraform-backend'
  managedBy: 'bicep-bootstrap'
  environment: 'shared'
}

// ---- Resource group do backend -------------------------------------------
resource stateRg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

// ---- Storage Account + container (módulo no escopo do RG) ----------------
module backend 'modules/state-storage.bicep' = {
  name: 'tfstate-backend'
  scope: stateRg
  params: {
    location: location
    storageAccountName: storageAccountName
    containerName: containerName
    tags: tags
  }
}

output resourceGroupName string = stateRg.name
output storageAccountName string = storageAccountName
output containerName string = containerName
