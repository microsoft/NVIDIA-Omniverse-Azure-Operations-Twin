targetScope='subscription'

param resourceGroupName string
param location string
param virtualNetworkName string
param clusterName string
param dnsPrefix string
param agentPoolVMSize string
param cachePoolVMSize string
param gpuPoolVMSize string

resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' existing = {
  name: virtualNetworkName
  scope: resourceGroup
}

module aks 'modules/aks.bicep' = {
  scope: resourceGroup
  name: 'aksDeploy'
  params: {
      virtualNetworkName: virtualNetworkName
      clusterName: clusterName
      location: location
      agentVMSize: agentPoolVMSize
      agentNodeCount: 2
      agentMaxPods: 30
      cacheNodeCount: 1
      cacheVMSize: cachePoolVMSize
      gpuNodeCount: 1
      gpuVMSize: gpuPoolVMSize
      dnsPrefix: dnsPrefix
      subnetId: '${vnet.id}/subnets/subnet-aks'
  }
}


