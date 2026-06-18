// =============================================================================
//  bootstrap/modules/state-storage.bicep
//  Storage Account endurecida para guardar o tfstate, com:
//    - versionamento de blob  (recupera state corrompido/sobrescrito)
//    - soft delete            (janela de recuperação)
//    - TLS 1.2 + sem acesso público de blob
//    - container privado "tfstate"
//  Escopo: resourceGroup
// =============================================================================

@description('Região do Azure.')
param location string

@description('Nome globalmente único da Storage Account (3-24 chars minúsculos).')
@minLength(3)
@maxLength(24)
param storageAccountName string

@description('Nome do container que guarda os arquivos de state.')
param containerName string

@description('Tags.')
param tags object

resource sa 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true // o backend azurerm usa a access key do storage
    supportsHttpsTrafficOnly: true
    networkAcls: {
      defaultAction: 'Allow' // restrinja para 'Deny' + regras de IP em produção real
    }
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: sa
  name: 'default'
  properties: {
    isVersioningEnabled: true
    deleteRetentionPolicy: {
      enabled: true
      days: 30
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 30
    }
  }
}

resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: containerName
  properties: {
    publicAccess: 'None'
  }
}

output storageAccountId string = sa.id
