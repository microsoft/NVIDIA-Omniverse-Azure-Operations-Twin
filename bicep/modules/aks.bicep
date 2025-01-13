param clusterName string
param location string
param dnsPrefix string

@minValue(0)
@maxValue(1023)
param osDiskSizeGB int = 0

@minValue(1)
@maxValue(50)
param agentNodeCount int = 3

param cacheNodeCount int

param gpuNodeCount int

param agentMaxPods int

param agentVMSize string
param cacheVMSize string
param gpuVMSize string

param subnetId string

param virtualNetworkName string

@description('User name for the Linux Virtual Machines.')
// param linuxAdminUsername string

// @description('Configure all linux machines with the SSH RSA public key string. Your key should include three parts, for example \'ssh-rsa AAAAB...snip...UcyupgH azureuser@linuxvm\'')
// param sshRSAPublicKey string

resource aks 'Microsoft.ContainerService/managedClusters@2024-06-02-preview' = {
  name: clusterName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    aadProfile: {
      managed: true
      enableAzureRBAC: true
    }
    dnsPrefix: dnsPrefix
    agentPoolProfiles: [
      {
        name: 'agentpoolds'
        count: agentNodeCount
        vmSize: agentVMSize
        osType: 'Linux'
        mode: 'System'
        maxPods: agentMaxPods
        enableAutoScaling: false
        vnetSubnetID: subnetId
      }
      {
        name: 'cachepool'
        count: cacheNodeCount
        vmSize: cacheVMSize
        osType: 'Linux'
        mode: 'User'
        enableAutoScaling: false
        vnetSubnetID: subnetId
      }
      {
        name: 'gpupool'
        count: gpuNodeCount
        vmSize: gpuVMSize
        osType: 'Linux'
        mode: 'User'
        enableAutoScaling: false
        vnetSubnetID: subnetId
      }
    ]
    networkProfile: {
      serviceCidr: '10.0.0.0/16'
      dnsServiceIP: '10.0.0.10'
      networkPolicy: 'none'
    }
  //   linuxProfile: {
  //     adminUsername: linuxAdminUsername
  //     ssh: {
  //       publicKeys: [
  //         {
  //           keyData: sshRSAPublicKey
  //         }
  //       ]
  //     }
  //   }
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' existing = {
  name: virtualNetworkName
  scope: resourceGroup()
}

var roleDefinitionID = '4d97b98b-1d4f-4787-a291-c67834d212e7'
var roleAssignmentName = guid(clusterName, roleDefinitionID, resourceGroup().id)

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: roleAssignmentName
  scope: vnet
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionID)
    principalId: aks.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output controlPlaneFQDN string = aks.properties.fqdn
output principalId string = aks.identity.principalId
