@description('The name of the Log Analytics Workspace to deploy')
param logAnalyticsWorkspaceName string

@description('The location to deploy the workspace to.')
param location string

@description('The SKU to use for the Log Analytics workspace')
param logAnalyticsWorkspaceSKU string

@description('Enable public access on workspace')
param enablePublicAccessOnWorkspace string

@description('The time that this deployment was initiated')
param deploymentTime string = utcNow('u')

var tags = {
  DeployedAt: deploymentTime
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' = {
  name: logAnalyticsWorkspaceName
  tags: tags
  location: location
  properties: {
   sku: {
    name: logAnalyticsWorkspaceSKU
   }
   publicNetworkAccessForIngestion: enablePublicAccessOnWorkspace
   publicNetworkAccessForQuery: enablePublicAccessOnWorkspace
  }
}

output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
