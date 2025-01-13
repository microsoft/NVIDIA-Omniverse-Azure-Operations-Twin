@description('Application Gateway name')
param applicationGatewayName string = 'applicationGatewayV2'

@description('Minimum instance count for Application Gateway')
param minCapacity int = 2

@description('Maximum instance count for Application Gateway')
param maxCapacity int = 10

@description('Application Gateway Frontend port')
param frontendPort int = 80

@description('Application gateway Backend port')
param backendPort int = 443

param subnetId string

@description('Cookie based affinity')
@allowed([
  'Enabled'
  'Disabled'
])
param cookieBasedAffinity string = 'Disabled'

@description('Location for all resources.')
param location string = resourceGroup().location

var appGwPublicIpName = '${applicationGatewayName}-pip'
var appGwSize = 'Standard_v2'


resource publicIP 'Microsoft.Network/publicIPAddresses@2020-06-01' = {
  name: appGwPublicIpName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource applicationGateway 'Microsoft.Network/applicationGateways@2020-06-01' = {
  name: applicationGatewayName
  location: location
  zones: [
    '1'
    '2'
    '3'
  ]
  properties: {
    sku: {
      name: appGwSize
      tier: 'Standard_v2'
    }
    autoscaleConfiguration: {
      minCapacity: minCapacity
      maxCapacity: maxCapacity
    }
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: subnetId
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appGatewayFrontendIP'
        properties: {
          publicIPAddress: {
            id: publicIP.id
          }
          privateIPAddress: '10.2.1.10'
        }
      }
    ]
    frontendPorts: [
      {
        name: 'appGatewayFrontendPort'
        properties: {
          port: frontendPort
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'appGatewayBackendPool'
        properties: {
          
          backendAddresses: [
            {
              fqdn: 'apim-gw.beckerobrien.com'
            }
          ]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'appGatewayBackendHttpSettings'
        properties: {
          port: backendPort
          protocol: 'Https'
          cookieBasedAffinity: cookieBasedAffinity
          requestTimeout: 20
          pickHostNameFromBackendAddress: true
          probe: { 
            id: resourceId('Microsoft.Network/applicationGateways/probes', applicationGatewayName, 'appGatewayProbe')
          }
        }
      }
    ]
    httpListeners: [
      {
        name: 'appGatewayHttpListener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', applicationGatewayName, 'appGatewayFrontendIP')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', applicationGatewayName, 'appGatewayFrontendPort')
          }
          protocol: 'Http'
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'waf-to-apim-internal'
        properties: {
          ruleType: 'Basic'
          priority: 100
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', applicationGatewayName, 'appGatewayHttpListener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', applicationGatewayName, 'appGatewayBackendPool')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', applicationGatewayName, 'appGatewayBackendHttpSettings')
          }
        }
      }
    ]
    probes: [
      {
        name: 'appGatewayProbe'
        properties: {
          protocol: 'Https'
          path: '/'
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
          minServers: 1
          pickHostNameFromBackendHttpSettings: true
          match: {
            statusCodes: [
              '200-399'
            ]
          }
        }
      }
    ]
  }
}
