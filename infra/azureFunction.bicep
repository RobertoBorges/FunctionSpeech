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
param transcriptionOutputContainer string = 'transcribed'

@description('Speech service subscription key')
@secure()
param speechSubscriptionKey string

@description('Speech service region')
param speechRegion string = 'westus2'

@description('OpenAI completions endpoint')
param openaiCompletionsEndpoint string

@description('OpenAI model name')
param openaiCompletionsModel string = 'gpt-35-turbo'

@description('Optional: Existing Open AI Key not required if using Managed Identity to access OpenAI')
@secure()
param openaiCompletionsKey string = ''

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
param currentDayForSASGeneration string = utcNow()

@description('Optional: Existing Cognitive Services account resource ID for role assignment')
param existingCognitiveServicesMSIId string = ''

// Deploy Storage Module
module storageModule './modules/storage.bicep' = {
  name: 'storageDeployment'
  params: {
    storageAccountName: storageAccountName
    location: location
    storageAccountSku: storageAccountSku
    recordingsContainer: recordingsContainer
    transcriptionOutputContainer: transcriptionOutputContainer
    outputRedactedContainer: outputRedactedContainer
    sasExpiryDays: sasExpiryDays
    currentDayForSASGeneration: currentDayForSASGeneration
  }
}

// Deploy Monitoring Module (Application Insights)
module monitoringModule './modules/monitoring.bicep' = {
  name: 'monitoringDeployment'
  params: {
    appInsightsName: '${functionAppName}-insights'
    location: location
  }
}

// Prepare application settings for Function App
var functionAppSettings = [
  // Application specific settings
  {
    name: 'RECORDINGS_STORAGE_ACCOUNT_NAME'
    value: storageModule.outputs.storageAccountName
  }
  {
    name: 'RECORDINGS_CONTAINER'
    value: storageModule.outputs.recordingsContainerName
  }
  {
    name: 'TRANSCRIPTION_OUTPUT_CONTAINER'
    value: storageModule.outputs.transcriptionOutputContainerName
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
    value: storageModule.outputs.sasToken
  }
  {
    name: 'OPENAI_COMPLETIONS_ENDPOINT'
    value: openaiCompletionsEndpoint
  }
  {
    name: 'OPENAI_COMPLETIONS_MODEL'
    value: openaiCompletionsModel
  }
  {
    name: 'OPENAI_COMPLETIONS_KEY'
    value: openaiCompletionsKey
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
    value: storageModule.outputs.outputRedactedContainerName
  }
  {
    name: 'REDACTED_STORAGE_ACCOUNT_NAME'
    value: storageModule.outputs.storageAccountName
  }
]

// Deploy Compute Module (App Service Plan + Function App)
module computeModule './modules/compute.bicep' = {
  name: 'computeDeployment'
  params: {
    functionAppName: functionAppName
    appServicePlanName: '${functionAppName}-plan'
    location: location
    runtime: runtime
    appServicePlanSku: appServicePlanSku
    storageAccountName: storageModule.outputs.storageAccountName
    appInsightsInstrumentationKey: monitoringModule.outputs.instrumentationKey
    appSettings: functionAppSettings
  }
}

// Deploy Security Module (Role Assignments)
module securityModule './modules/security.bicep' = {
  name: 'securityDeployment'
  params: {
    storageAccountId: storageModule.outputs.storageAccountId
    functionAppPrincipalId: computeModule.outputs.functionAppIdentityPrincipalId
    existingCognitiveServicesMSIId: existingCognitiveServicesMSIId
    resourceGroupId: resourceGroup().id
  }
}

// Outputs
output functionAppName string = computeModule.outputs.functionAppName
output functionAppUrl string = computeModule.outputs.functionAppUrl
output storageAccountName string = storageModule.outputs.storageAccountName
output appInsightsName string = monitoringModule.outputs.appInsightsName
output appServicePlanName string = computeModule.outputs.appServicePlanName
output functionAppIdentityPrincipalId string = computeModule.outputs.functionAppIdentityPrincipalId
