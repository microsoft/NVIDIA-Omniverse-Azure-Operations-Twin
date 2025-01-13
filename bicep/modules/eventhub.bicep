@description('Specifies a project name that is used to generate the Event Hub name and the Namespace name.')
@minLength(6)
param eventhubNamespaceName string = 'ehns-nvidia'
param eventhubName string = ''

@description('Specifies the Azure location for all resources.')
param location string = resourceGroup().location

@description('Specifies the messaging tier for Event Hub Namespace.')
@allowed([
  'Basic'
  'Standard'
])
param eventHubSku string = 'Standard'

resource eventHubNamespace 'Microsoft.EventHub/namespaces@2021-11-01' = {
  name: eventhubNamespaceName
  location: location
  sku: {
    name: eventHubSku
    tier: eventHubSku
    capacity: 1
  }
  properties: {
    isAutoInflateEnabled: false
    maximumThroughputUnits: 0
  }
}

resource eventHub 'Microsoft.EventHub/namespaces/eventhubs@2021-11-01' = {
  parent: eventHubNamespace
  name: eventhubName
  properties: {
    messageRetentionInDays: 7
    partitionCount: 1
  }
}
