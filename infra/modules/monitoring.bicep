@description('The name of the Application Insights resource')
param appInsightsName string

@description('The location to deploy the resources to')
param location string

// Application Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Request_Source: 'rest'
  }
}

// Outputs
output appInsightsId string = appInsights.id
output appInsightsName string = appInsights.name
output instrumentationKey string = appInsights.properties.InstrumentationKey
