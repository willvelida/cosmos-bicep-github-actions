@description('The location to deploy the Cosmos DB account to. Default value is the location of the resource group.')
param location string = resourceGroup().location

@description('Name of our application')
param applicationName string = uniqueString((resourceGroup().id))

@description('The secondary replica region for the Cosmos DB account')
param secondaryRegion string = 'australiasoutheast'

@description('Name of our Cosmos DB account that will be deployed')
@maxLength(44)
param cosmosDbAccountName string = '${applicationName}db'

@description('The default consistency level of the Cosmos DB account.')
@allowed([
  'Eventual'
  'ConsistentPrefix'
  'Session'
  'BoundedStaleness'
  'Strong'
])
param defaultConsistencyLevel string = 'Session'

@description('Enable automatic failover for this account')
param enableAutomaticFailover bool = true

@description('Enable Analytical storage for this account')
param enableAnalyticalStorage bool = true

@description('Enable Full Text Query capabilities for this account')
@allowed([
  'True'
  'False'
  'None'
])
param enableFullTextQuery string = 'True'

@description('The name for the database')
param databaseName string = 'OrdersDB'

@description('The name for the container')
param containerName string = 'orders'

@description('The maximum amount of throughput to provision on this container')
@minValue(4000)
@maxValue(10000)
param maxThroughput int = 4000

@description('The name of the Log Analytics workspace that the account will send logs to')
param logAnalyticsWorkspaceName string = '${applicationName}law'

@description('The SKU to use for the Log Analytics workspace')
@allowed([
  'PerGB2018'
  'Free'
  'PerNode'
  'Standard'
  'Standalone'
])
param logAnalyticsWorkspaceSKU string = 'PerGB2018'

@description('Enable or disable public access for Log Analytics workspace')
@allowed([
  'Enabled'
  'Disabled'
])
param enablePublicAccessOnWorkspace string = 'Enabled'

@description('The name of the key vault that we will create')
param keyVaultName string = '${applicationName}kv'

@description('The name of our storage account that the Function will use')
param storageAccountName string = '${replace(applicationName, '-', '')}fnstor'

@description('The SKU that our storage account will use')
param storageAccountSKU string = 'Standard_LRS'

@description('The name of our Application Insights workspace')
param appInsightsName string = '${applicationName}ai'

@description('The name of the App Service Plan')
param appServicePlanName string = '${applicationName}asp'

@description('The name of our Function App')
param functionAppName string = '${applicationName}func'

@description('The time that this deployment was initiated')
param deploymentTime string = utcNow('u')

var tags = {
  DeployedAt: deploymentTime
}

resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2022-05-15-preview' = {
  name: cosmosDbAccountName
  kind: 'GlobalDocumentDB'
  tags: tags
  location: location
  properties: {
    enableAnalyticalStorage: enableAnalyticalStorage
    analyticalStorageConfiguration: {
      schemaType: 'WellDefined'
    }
    backupPolicy: {
      type: 'Periodic'
      periodicModeProperties: {
        backupIntervalInMinutes: 60
        backupRetentionIntervalInHours: 8
        backupStorageRedundancy: 'Geo'
      }
    }
    consistencyPolicy: {
      defaultConsistencyLevel: defaultConsistencyLevel
    }
    enableAutomaticFailover: enableAutomaticFailover
    databaseAccountOfferType: 'Standard'
    diagnosticLogSettings: {
      enableFullTextQuery: enableFullTextQuery
    } 
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: true
      }
      {
        locationName: secondaryRegion
        failoverPriority: 1
        isZoneRedundant: false
      }
    ]
  }
  identity: {
    type: 'SystemAssigned'
  }
}

resource db 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2022-05-15-preview' = {
  name: databaseName
  parent: cosmosDbAccount
  properties: {
    resource: {
      id: databaseName
    }
  }  
}

resource container 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2022-05-15-preview' = {
  name:containerName
  parent: db
  properties: {
    resource: {
      id: containerName
      partitionKey: {
        paths: [
          '/id'
        ]
        kind: 'Hash'
      }
      indexingPolicy: {
        indexingMode: 'consistent'
        includedPaths: [
          {
            path: '/*'
          }
        ]
      }
    }
    options: {
      autoscaleSettings: {
        maxThroughput: maxThroughput
      }
    }
  }
}

module logAnalyticsWorkspace 'modules/logAnalytics.bicep' = {
  name: 'logAnalyticsWorkspace'
  params: {
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    logAnalyticsWorkspaceSKU: logAnalyticsWorkspaceSKU
    enablePublicAccessOnWorkspace: enablePublicAccessOnWorkspace
    location: location
  }
}

resource diagnosticLogs 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: cosmosDbAccount.name
  scope: cosmosDbAccount
  properties: {
    workspaceId: logAnalyticsWorkspace.outputs.logAnalyticsWorkspaceId
    logs: [
      {
        category: 'ControlPlaneRequests'
        enabled: true
        retentionPolicy: {
          days: 30
          enabled: true 
        }
      }
      {
        category: 'PartitionKeyStatistics'
        enabled: true
        retentionPolicy: {
          days: 30
          enabled: true 
        }
      }
      {
        category: 'QueryRuntimeStatistics'
        enabled: true
        retentionPolicy: {
          days: 30
          enabled: true 
        }
      }
      {
        category: 'PartitionKeyRUConsumption'
        enabled: true
        retentionPolicy: {
          days: 30
          enabled: true 
        }
      }
      {
        category: 'DataPlaneRequests'
        enabled: true
        retentionPolicy: {
          days: 30
          enabled: true 
        }
      }
    ]
    metrics: [
      {
        category: 'Requests'
        enabled: true
        retentionPolicy: {
          days: 30
          enabled: true 
        }
      }
    ]
  } 
}
