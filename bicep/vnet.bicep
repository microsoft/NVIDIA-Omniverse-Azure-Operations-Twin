targetScope='subscription'

param resourceGroupName string
param location string
param virtualNetworkName string
param nsgNameInternal string
param nsgNameExternal string
param vnetAddressPrefix string
param aksSubnetAddressPrefix string
param wafSubnetAddressPrefix string
param apimSubnetAddressPrefix string

resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
}

module nsgInternal 'modules/nsg.bicep' = {
  scope: resourceGroup
  name: 'nsgDeployInternal'
  params: {
      nsgName: nsgNameInternal
      location: location
      securityRules: [
          {
              name: 'AllowCidrBlockCustom80'
              properties: {
                  protocol: 'Tcp'
                  sourceAddressPrefix: '*'
                  sourcePortRange: '*'
                  destinationAddressPrefix: '*'
                  destinationPortRange: '80'
                  direction: 'Inbound'
                  access: 'Allow'
                  priority: 100
              }
          }
          {
              name: 'AllowCidrBlockCustom443'
              properties: {
                  protocol: 'Tcp'
                  sourceAddressPrefix: '*'
                  sourcePortRange: '*'
                  destinationAddressPrefix: '*'
                  destinationPortRange: '110'
                  direction: 'Inbound'
                  access: 'Allow'
                  priority: 110
              }
          }
      ]
  }
}

module nsgExternal 'modules/nsg.bicep' = {
  scope: resourceGroup
  name: 'nsgDeployExternal'
  params: {
      nsgName: nsgNameExternal
      location: location
      securityRules: [
          {
              name: 'AllowCidrBlockCustom80'
              properties: {
                  protocol: 'Tcp'
                  sourceAddressPrefix: '10.0.0.0/8'
                  sourcePortRange: '*'
                  destinationAddressPrefix: '*'
                  destinationPortRange: '80'
                  direction: 'Inbound'
                  access: 'Allow'
                  priority: 100
              }
          }
          {
              name: 'AllowCidrBlockCustom443'
              properties: {
                  protocol: 'Tcp'
                  sourceAddressPrefix: '10.0.0.0/8'
                  sourcePortRange: '*'
                  destinationAddressPrefix: '*'
                  destinationPortRange: '110'
                  direction: 'Inbound'
                  access: 'Allow'
                  priority: 110
              }
          }
          {
              name: 'AllowTagCustom3443Inbound'
              properties: {
                  protocol: 'Tcp'
                  sourceAddressPrefix: 'ApiManagement'
                  sourcePortRange: '*'
                  destinationAddressPrefix: 'VirtualNetwork'
                  destinationPortRange: '3443'
                  direction: 'Inbound'
                  access: 'Allow'
                  priority: 120
              }
          }            
          {
              name: 'AllowCidrBlockCustom31000-31002Inbound'
              properties: {
                  protocol: 'Tcp'
                  sourceAddressPrefix: '10.0.0.0/8'
                  sourcePortRange: '*'
                  destinationAddressPrefix: '*'
                  destinationPortRange: '31000-31002'
                  direction: 'Inbound'
                  access: 'Allow'
                  priority: 130
              }
          }
          {
              name: 'AllowCidrBlockCustom31000-31002InboundUdp'
              properties: {
                  protocol: 'Udp'
                  sourceAddressPrefix: '10.0.0.0/8'
                  sourcePortRange: '*'
                  destinationAddressPrefix: '*'
                  destinationPortRange: '31000-31002'
                  direction: 'Inbound'
                  access: 'Allow'
                  priority: 140
              }
          }
      ]
  }
}

module vnet 'modules/vnet.bicep' = {
  scope: resourceGroup
  name: 'vnetDeploy'
  params: {
      virtualNetworkName: virtualNetworkName
      location: location
      addressPrefixes: [
          vnetAddressPrefix
      ]
      subnets: [
          {
              name: 'subnet-aks'
              properties: {
                  addressPrefix: aksSubnetAddressPrefix
                  networkSecurityGroup: {
                      id: nsgInternal.outputs.id
                  }
              }
          }
          {
              name: 'subnet-appgw'
              properties: {
                  addressPrefix: wafSubnetAddressPrefix
                  networkSecurityGroup: {
                    id: nsgExternal.outputs.id
                }
              }
          }
          {
              name: 'subnet-apim'
              properties: {
                  addressPrefix: apimSubnetAddressPrefix
                  networkSecurityGroup: {
                      id: nsgInternal.outputs.id
                  }
              }
          }
      ]
  }
}
