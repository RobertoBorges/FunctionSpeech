@description('The name of the function app to create')
param functionAppName string = 'speech${uniqueString(resourceGroup().id)}'

@description('The name of the storage account to create')
param storageAccountName string = 'stor${uniqueString(resourceGroup().id)}'

@description('The location to deploy the resources to')
param location string = resourceGroup().location

@description('The runtime stack of the function app')
param runtime string = 'python'

@description('The SKU of the storage account')
param storageAccountSku string = 'Standard_LRS'

@description('App Service Plan SKU')
param appServicePlanSku string = 'B3'

@description('Container name for audio files')
param recordingsContainer string = 'audio-recordings'

@description('Container name for transcription output')
param transcriptionOutputContainer string = 'transcriptions'

@description('Speech service subscription key')
@secure()
param speechSubscriptionKey string

@description('Speech service region')
param speechRegion string = 'westus2'

@description('OpenAI completions endpoint')
param openaiCompletionsEndpoint string

@description('OpenAI completions subscription key')
@secure()
param completionsSubscriptionKey string

@description('OpenAI model name')
param openaiCompletionsModel string = 'gpt-35-turbo'

@description('Language service subscription key')
@secure()
param languageSubscriptionKey string

@description('Language service endpoint')
param languageEndpoint string

@description('Container name for redacted transcriptions')
param outputRedactedContainer string = 'redacted-transcriptions'

@description('SAS token expiry in days from now')
param sasExpiryDays int = 365 // 1 year

@description('SAS token expiry in days from now')
param currentDayForSASGenaration string = utcNow()

// Format the expiry date using dateTimeAdd to add 365 days to current UTC time
var sasExpiryDate = dateTimeAdd(currentDayForSASGenaration, 'P${sasExpiryDays}D')

var currentDayForSASGenarationUTC = dateTimeAdd(currentDayForSASGenaration, 'P0D')

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

// Application Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${functionAppName}-insights'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Request_Source: 'rest'
  }
}

// App Service Plan
resource appServicePlan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: '${functionAppName}-plan'
  location: location
  kind: 'app,linux'
  sku: {
    name: appServicePlanSku
  }
  properties: {
    perSiteScaling: false
    reserved: true // Linux
    isXenon: false
    isSpot: false
    hyperV: false
    targetWorkerCount: 0
    targetWorkerSizeId: 0
    hostingEnvironmentProfile: null
    elasticScaleEnabled: false
    maximumElasticWorkerCount: 1
  }
}

// Function App
resource functionApp 'Microsoft.Web/sites@2024-04-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      pythonVersion: '3.12'
      minTlsVersion: '1.2'
      linuxFxVersion: 'Python|3.12'
      alwaysOn: true
      appSettings: [
        // Storage account connection using managed identity
        {
          name: 'AzureWebJobsStorage__accountName'
          value: storageAccountName
        }
        {
          name: 'AzureWebJobsStorage__credential'
          value: 'managedidentity'
        }
        {
          name: 'IngestAccount__blobServiceUri'
          value: 'https://${storageAccountName}.blob.core.windows.net'
        }
        // Function settings
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: runtime
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: '1'
        }
        {
          name: 'ENABLE_ORYX_BUILD'
          value: 'true'
        }
        // Application specific settings
        {
          name: 'RECORDINGS_STORAGE_ACCOUNT_NAME'
          value: storageAccountName
        }
        {
          name: 'RECORDINGS_CONTAINER'
          value: recordingsContainer
        }
        {
          name: 'TRANSCRIPTION_OUTPUT_CONTAINER'
          value: transcriptionOutputContainer
        }
        {
          name: 'SPEECH_SUBSCRIPTION_KEY'
          value: speechSubscriptionKey
        }
        {
          name: 'SPEECH_TO_TEXT_ENDPOINT'
          value: 'https://${speechRegion}.api.cognitive.microsoft.com'
        }
        {
          name: 'SA_OUTPUT_SAS'
          value: storageAccount.listServiceSas('2023-05-01', {
            canonicalizedResource: '/blob/${storageAccount.name}/${transcriptionOutputContainer}'
            signedResource: 'sco'
            signedPermission: 'rwdlacu'
            signedProtocol: 'https'
            signedExpiry: sasExpiryDate
          }).serviceSasToken
        }
        {
          name: 'OPENAI_COMPLETIONS_ENDPOINT'
          value: openaiCompletionsEndpoint
        }
        {
          name: 'COMPLETIONS_SUBSCRIPTION_KEY'
          value: completionsSubscriptionKey
        }
        {
          name: 'OPENAI_COMPLETIONS_MODEL'
          value: openaiCompletionsModel
        }
        {
          name: 'LANGUAGE_SUBSCRIPTION_KEY'
          value: languageSubscriptionKey
        }
        {
          name: 'LANGUAGE_ENDPOINT'
          value: languageEndpoint
        }
        {
          name: 'OUTPUT_REDACTED_CONTAINER'
          value: outputRedactedContainer
        }
        {
          name: 'REDACTED_STORAGE_ACCOUNT_NAME'
          value: storageAccountName
        }
      ]
    }
  }
  dependsOn: [
    recordingsContainerResource
    redactedContainerResource
  ]
}

// Role assignment for function app to access storage
resource roleAssignmentContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, functionApp.id, 'StorageBlobDataContributor')
  scope: storageAccount
  properties: {
    principalId: functionApp.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe') // Storage Blob Data Contributor
    principalType: 'ServicePrincipal'
  }
}

resource roleAssignmentOwner 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, functionApp.id, 'StorageBlobDataOwner')
  scope: storageAccount
  properties: {
    principalId: functionApp.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b') // Storage Blob Data Owner
    principalType: 'ServicePrincipal'
  }
}

// Outputs
output functionAppName string = functionApp.name
output functionAppUrl string = 'https://${functionApp.properties.defaultHostName}'
output storageAccountName string = storageAccount.name
output appInsightsName string = appInsights.name
output appServicePlanName string = appServicePlan.name
output functionAppIdentityPrincipalId string = functionApp.identity.principalId
