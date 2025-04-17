@description('The resource ID of the Storage Account')
param storageAccountId string

@description('The Principal ID of the Function App managed identity')
param functionAppPrincipalId string

@description('Optional: Existing Cognitive Services account resource ID for role assignment')
param existingCognitiveServicesMSIId string = ''

@description('The Resource Group ID for generating unique GUIDs')
param resourceGroupId string

// Role assignment for function app to access storage as a contributor
resource roleAssignmentContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroupId, functionAppPrincipalId, 'StorageBlobDataContributor')
  scope: resourceGroup()
  properties: {
    principalId: functionAppPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe') // Storage Blob Data Contributor
    principalType: 'ServicePrincipal'
  }
}

// Role assignment for function app to access storage as an owner
resource roleAssignmentOwner 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroupId, functionAppPrincipalId, 'StorageBlobDataOwner')
  scope: resourceGroup()
  properties: {
    principalId: functionAppPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b') // Storage Blob Data Owner
    principalType: 'ServicePrincipal'
  }
}

// Assign Contributor role to the Cognitive Services account on the storage account
resource cognitiveServicesStorageContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(existingCognitiveServicesMSIId)) {
  name: guid(resourceGroupId, storageAccountId, existingCognitiveServicesMSIId, 'StorageBlobDataContributor')
  scope: resourceGroup()
  properties: {
    principalId: existingCognitiveServicesMSIId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe') // Storage Blob Data Contributor
    principalType: 'ServicePrincipal'
  }
}

// No outputs needed for this module
