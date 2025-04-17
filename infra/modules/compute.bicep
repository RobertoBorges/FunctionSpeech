@description('The name of the function app to create')
param functionAppName string

@description('The name of the App Service Plan')
param appServicePlanName string

@description('The location to deploy the resources to')
param location string

@description('The runtime stack of the function app')
param runtime string = 'python'

@description('App Service Plan SKU')
param appServicePlanSku string = 'B3'

@description('Storage account name for function app')
param storageAccountName string

@description('Application Insights instrumentation key')
param appInsightsInstrumentationKey string

// Application settings for the Function App
param appSettings array = []

// App Service Plan
resource appServicePlan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: appServicePlanName
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
      appSettings: concat([
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
        {
          name: 'IngestAccount__queueServiceUri'
          value: 'https://${storageAccountName}.queue.core.windows.net'
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
          value: appInsightsInstrumentationKey
        }
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: '1'
        }
        {
          name: 'ENABLE_ORYX_BUILD'
          value: 'true'
        }
      ], appSettings)
    }
  }
}

// Outputs
output functionAppId string = functionApp.id
output functionAppName string = functionApp.name
output functionAppUrl string = 'https://${functionApp.properties.defaultHostName}'
output appServicePlanId string = appServicePlan.id
output appServicePlanName string = appServicePlan.name
output functionAppIdentityPrincipalId string = functionApp.identity.principalId
