@description('The name of the storage account to create')
param storageAccountName string

@description('The location to deploy the resources to')
param location string

@description('The SKU of the storage account')
param storageAccountSku string = 'Standard_LRS'

@description('Container name for audio files')
param recordingsContainer string = 'audio-recordings'

@description('Container name for transcription output')
param transcriptionOutputContainer string = 'transcriptions'

@description('Container name for redacted transcriptions')
param outputRedactedContainer string = 'redacted-transcriptions'

@description('SAS token expiry in days from now')
param sasExpiryDays int = 365 // 1 year

@description('Current day for SAS generation')
param currentDayForSASGeneration string = utcNow()

// Format the expiry date
var sasExpiryDate = dateTimeAdd(currentDayForSASGeneration, 'P${sasExpiryDays}D')

// Storage Account for function app
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: storageAccountSku
  }
  properties: {
    supportsHttpsTrafficOnly: true
    encryption: {
      services: {
        blob: {
          enabled: true
        }
        file: {
          enabled: true
        }
        queue: {
          enabled: true
        }
        table: {
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
  }
}

// Define the blobServices resource
resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  name: 'default'
  parent: storageAccount
}

// Create containers in the storage account
resource recordingsContainerResource 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  name: recordingsContainer
  parent: blobServices
  properties: {
    publicAccess: 'None'
  }
}

resource transcriptionsContainerResource 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  name: transcriptionOutputContainer
  parent: blobServices
  properties: {
    publicAccess: 'None'
  }
}

resource redactedContainerResource 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  name: outputRedactedContainer
  parent: blobServices
  properties: {
    publicAccess: 'None'
  }
}

// Generate SAS token for transcription output container
var sasToken = storageAccount.listServiceSas('2023-05-01', {
  canonicalizedResource: '/blob/${storageAccount.name}/${transcriptionOutputContainer}'
  signedResource: 'c'
  signedPermission: 'racwdl'
  signedProtocol: 'https'
  signedExpiry: sasExpiryDate
}).serviceSasToken

// Outputs
output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
output sasToken string = sasToken
output recordingsContainerName string = recordingsContainer
output transcriptionOutputContainerName string = transcriptionOutputContainer
output outputRedactedContainerName string = outputRedactedContainer
