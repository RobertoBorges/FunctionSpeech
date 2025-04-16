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
param appServicePlanSku string = 'Y1' // Consumption plan

@description('Storage account name for recordings')
param recordingsStorageName string

@description('Container name for audio files')
param recordingsContainer string = 'audio-recordings'

@description('Container name for transcription output')
param transcriptionOutputContainer string = 'transcriptions'

@description('Speech service subscription key')
@secure()
param speechSubscriptionKey string

@description('Speech service region')
param speechRegion string = 'westus2'

@description('SAS token for storage account used by Speech service')
@secure()
param saOutputSas string

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

@description('Storage account name for redacted results')
param redactedStorageAccountName string

@description('Container name for redacted transcriptions')
param outputRedactedContainer string = 'redacted-transcriptions'

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

// Application Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${functionAppName}-insights'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Request_Source: 'rest'
    WorkspaceResourceId: null
  }
}

// App Service Plan
resource appServicePlan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: '${functionAppName}-plan'
  location: location
  kind: 'functionapp'
  sku: {
    name: appServicePlanSku
  }
  properties: {}
}

// Function App
resource functionApp 'Microsoft.Web/sites@2024-04-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      pythonVersion: '3.11'
      minTlsVersion: '1.2'
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
          value: recordingsStorageName
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
          value: saOutputSas
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
          value: redactedStorageAccountName
        }
      ]
    }
  }
}

// Outputs
output functionAppName string = functionApp.name
output functionAppUrl string = 'https://${functionApp.properties.defaultHostName}'
output storageAccountName string = storageAccount.name
output appInsightsName string = appInsights.name
output appServicePlanName string = appServicePlan.name
output functionAppIdentityPrincipalId string = functionApp.identity.principalId
