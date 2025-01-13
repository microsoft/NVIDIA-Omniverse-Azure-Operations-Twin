targetScope='resourceGroup'

param location string
param apimPublisherName string
param apimPublisherEmail string
param apimGwHostName string
param apimMgmtHostName string
param virtualNetworkName string
param serviceUrl string
param apiManagementServiceName string
param applicationGatewayName string
param apimSku string = 'Developer'
param apimSkuCount int = 1
param appGwPublicIpName string = 'pip-${applicationGatewayName}'
@description('Minimum instance count for Application Gateway')
param minCapacity int = 2

@description('Maximum instance count for Application Gateway')
param maxCapacity int = 3
param cookieBasedAffinity string = 'Disabled'
param appGwSslCertName string 
param apimSslCertName string 
param appGwHostName string 
param keyVaultName string

param aksClusterName string
param aksDnsPrefix string
param agentNodeCount int = 3

param cacheNodeCount int = 1

param gpuNodeCount int = 1

param agentMaxPods int = 30

param agentPoolName string
param cachePoolName string
param gpuPoolName string

param agentVMSize string
param cacheVMSize string
param gpuVMSize string
param logAnalyticsName string

param aksRbacAssignments array = []

param frontendDnsZoneName string
param backendDnsZoneName string

param staticWebAppName string
param webAppCNAME string

param externalDnsManagedIdentityName string

var appGwSslCertSecretName = replace(appGwSslCertName, '.', '-')
var apimSslCertSecretName = replace(apimSslCertName, '.', '-')

var appgwResourceId = resourceId('Microsoft.Network/applicationGateways', '${applicationGatewayName}')
var frontendAgwCertificateId = '${appgwResourceId}/sslCertificates/${appGwSslCertName}'

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: logAnalyticsName
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' existing = {
  name: virtualNetworkName
}

resource appGwMsi 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' existing = {
  name: 'msi-appgw'
}

resource apimMsi 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' existing = {
  name: 'msi-apim'
}

resource keyVault 'Microsoft.KeyVault/vaults@2024-04-01-preview' existing = {
  name: keyVaultName
} 

resource staticWebApp 'Microsoft.Web/staticSites@2023-12-01' = {
  name: staticWebAppName
  location: location
  properties: {}
  sku: {
      name: 'Standard'
  }
}

resource cnameRecord 'Microsoft.Network/dnsZones/CNAME@2018-05-01' = {
  parent: publicDnsZone
  name: webAppCNAME
  properties: {
    TTL: 300
    CNAMERecord: {
      cname: staticWebApp.properties.defaultHostname
    }
  }
}

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

resource firewallPolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2021-03-01' = {
  name: 'default'
  location: location
  properties: {
    customRules: []
    policySettings: {
      requestBodyCheck: true
      maxRequestBodySizeInKb: 128
      fileUploadLimitInMb: 100
      mode: 'Detection'
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'OWASP'
          ruleSetVersion: '3.2'
          ruleGroupOverrides: []
        }
      ]
      exclusions: []
    }
  }
}

resource applicationGateway 'Microsoft.Network/applicationGateways@2020-06-01' = {
  name: applicationGatewayName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${appGwMsi.id}': {}
    }
  }
  zones: [
    '1'
    '2'
    '3'
  ]
  properties: {
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
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
            id: '${vnet.id}/subnets/subnet-waf'
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
        name: 'httpPort'
        properties: {
          port: 80
        }
      }
      {
        name: 'httpsPort'
        properties: {
          port: 443
        }
      }      
    ]
    backendAddressPools: [
      {
        name: 'appGatewayBackendPool'
        properties: {
          
          backendAddresses: [
            {
              fqdn: apimGwHostName
            }
          ]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'https'
        properties: {
          port: 443
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

    sslCertificates: [
      {
        name: appGwSslCertName
        properties: {
          keyVaultSecretId: '${keyVault.properties.vaultUri}secrets/${appGwSslCertSecretName}'
        }
      }
    ]

    httpListeners: [
      {
        name: 'http'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', applicationGatewayName, 'appGatewayFrontendIP')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', applicationGatewayName, 'httpPort')
          }
          protocol: 'Http'
        }
      }
      {
        name: 'https'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', applicationGatewayName, 'appGatewayFrontendIP')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', applicationGatewayName, 'httpsPort')
          }
          protocol: 'Https'
          sslCertificate: {
            #disable-next-line use-resource-id-functions
            id: frontendAgwCertificateId
          }
          hostNames: [
            appGwHostName
            '*.${appGwHostName}'
          ]
          requireServerNameIndication: true
          customErrorConfigurations: []
        }
      }      
    ]
    redirectConfigurations: [
      {
        name: 'redirectConfig'
        properties: {
          redirectType: 'Permanent'
          targetListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', applicationGatewayName, 'https')
          }
          includePath: true
          includeQueryString: true
          requestRoutingRules: [
            {
              id: resourceId('Microsoft.Network/applicationGateways/requestRoutingRules', applicationGatewayName, 'http')
            }
          ]
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'http'
        properties: {
          ruleType: 'Basic'
          priority: 20
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', applicationGatewayName, 'http')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', applicationGatewayName, 'appGatewayBackendPool')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', applicationGatewayName, 'https')
          }
        }
      } 
      {
        name: 'https'
        properties: {
          ruleType: 'Basic'
          priority: 10
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', applicationGatewayName, 'https')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', applicationGatewayName, 'appGatewayBackendPool')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', applicationGatewayName, 'https')
          }
        }
      }      
    ]
    probes: [
      {
        name: 'appGatewayProbe'
        properties: {
          protocol: 'Https'
          path: '/status-0123456789abcdef'
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
    firewallPolicy: {
      id: firewallPolicy.id
    }
  }
}

resource appgwDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'Log Analytics'
  scope: applicationGateway
  properties: {
    workspaceId: logAnalytics.id
    logs: [
      {
        category: 'ApplicationGatewayAccessLog'
        enabled: true
      }
      {
        category: 'ApplicationGatewayPerformanceLog'
        enabled: true
      }
      {
        category: 'ApplicationGatewayFirewallLog'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

#disable-next-line BCP081
resource apiManagementService 'Microsoft.ApiManagement/service@2024-06-01-preview' = {
  name: apiManagementServiceName
  location: location
  sku: {
    name: apimSku
    capacity: apimSkuCount
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${apimMsi.id}': {}
    }
  }
  properties: {
    publisherEmail: apimPublisherEmail
    publisherName: apimPublisherName
    virtualNetworkConfiguration: {
      subnetResourceId: '${vnet.id}/subnets/subnet-apim'
    }
    virtualNetworkType: 'Internal'
    hostnameConfigurations: [
      {
          type: 'Proxy'
          hostName: apimGwHostName
          defaultSslBinding: true
          negotiateClientCertificate: false
          certificateSource: 'KeyVault'
          identityClientId: apimMsi.properties.clientId
          keyVaultId:  '${keyVault.properties.vaultUri}secrets/${apimSslCertSecretName}'
      }
      {
          type: 'Management'
          hostName: apimMgmtHostName
          certificateSource: 'KeyVault'
          identityClientId: apimMsi.properties.clientId
          keyVaultId:  '${keyVault.properties.vaultUri}secrets/${apimSslCertSecretName}'
      }
    ]
  }
}

resource apimwDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'Log Analytics'
  scope: apiManagementService
  properties: {
    workspaceId: logAnalytics.id
    logs: [
      {
        category: 'GatewayLogs'
        enabled: true
      }
      {
        category: 'WebSocketConnectionLogs'
        enabled: true
      }
      {
        category: 'DeveloperPortalAuditLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

#disable-next-line BCP081
resource httpApi 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  parent: apiManagementService
  name: 'http'
  properties: {
    apiType: 'http'
    displayName: 'http'
    apiRevision: '1'
    isCurrent: true
    path: ''
    protocols: [
      'https'
    ]
    serviceUrl: serviceUrl
    type: 'http'
    subscriptionRequired: false
  }
}

#disable-next-line BCP081
resource httpApiGet 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = {
  parent: httpApi
  name: 'httpApiGetDeploy'
  properties: {
    displayName: 'Get'
    method: 'GET'
    urlTemplate: '/*'
    request: {
      queryParameters: []
    }
    responses: [
      {
        statusCode: 200
        description: 'Success'
        representations: []
      }
    ]
  }
}

#disable-next-line BCP081
resource httpApiPost 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = {
  parent: httpApi
  name: 'httpApiPostDeploy'
  properties: {
    displayName: 'Post'
    method: 'POST'
    urlTemplate: '/*'
    request: {
      queryParameters: []
    }
    responses: [
      {
        statusCode: 200
        description: 'Success'
        representations: []
      }
    ]
  }
}

#disable-next-line BCP081
resource httpApiPut 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = {
  parent: httpApi
  name: 'httpApiPutDeploy'
  properties: {
    displayName: 'Put'
    method: 'PUT'
    urlTemplate: '/*'
    request: {
      queryParameters: []
    }
    responses: [
      {
        statusCode: 200
        description: 'Success'
        representations: []
      }
    ]
  }
}

#disable-next-line BCP081
resource httpApiDelete 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = {
  parent: httpApi
  name: 'httpApiDeleteDeploy'
  properties: {
    displayName: 'Delete'
    method: 'DELETE'
    urlTemplate: '/*'
    request: {
      queryParameters: []
    }
    responses: [
      {
        statusCode: 200
        description: 'Success'
        representations: []
      }
    ]
  }
}

#disable-next-line BCP081
resource httpApiOptions 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = {
  parent: httpApi
  name: 'httpApiOptionsDeploy'
  properties: {
    displayName: 'Options'
    method: 'OPTIONS'
    urlTemplate: '/*'
    request: {
      queryParameters: []
    }
    responses: [
      {
        statusCode: 200
        description: 'Success'
        representations: []
      }
    ]
  }
}

resource aks 'Microsoft.ContainerService/managedClusters@2024-06-02-preview' = {
  name: aksClusterName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    aadProfile: {
      managed: true
      enableAzureRBAC: true
    }
    dnsPrefix: aksDnsPrefix
    agentPoolProfiles: [
      {
        name: agentPoolName
        count: agentNodeCount
        vmSize: agentVMSize
        osType: 'Linux'
        mode: 'System'
        maxPods: agentMaxPods
        enableAutoScaling: false
        vnetSubnetID: '${vnet.id}/subnets/subnet-aks'
      }
      {
        name: cachePoolName
        count: cacheNodeCount
        vmSize: cacheVMSize
        osType: 'Linux'
        mode: 'User'
        enableAutoScaling: false
        vnetSubnetID: '${vnet.id}/subnets/subnet-aks'
      }
      {
        name: gpuPoolName
        count: gpuNodeCount
        vmSize: gpuVMSize
        osType: 'Linux'
        mode: 'User'
        enableAutoScaling: false
        vnetSubnetID: '${vnet.id}/subnets/subnet-aks'
      }
    ]
    networkProfile: {
      serviceCidr: '10.0.0.0/16'
      dnsServiceIP: '10.0.0.10'
      networkPolicy: 'none'
    }
    securityProfile: {
      workloadIdentity: {
        enabled: true
      }
    }
    oidcIssuerProfile: {
      enabled: true
    }
  }
}

resource aksDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'Log Analytics'
  scope: aks
  properties: {
    workspaceId: logAnalytics.id
    logs: [
      {
        category: 'kube-apiserver'
        enabled: true
      }
      {
        category: 'kube-audit'
        enabled: true
      }
      {
        category: 'kube-audit-admin'
        enabled: true
      }
      {
        category: 'kube-controller-manager'
        enabled: true
      }
      {
        category: 'kube-scheduler'
        enabled: true
      }
      {
        category: 'cluster-autoscaler'
        enabled: true
      }
      {
        category: 'cloud-controller-manager'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  name: backendDnsZoneName
}

resource apimRecord 'Microsoft.Network/privateDnsZones/A@2024-06-01' = {
  parent: privateDnsZone
  name: 'apim-gw'
  properties: {
    ttl: 300
    aRecords: [
      {
        ipv4Address: apiManagementService.properties.privateIPAddresses[0]
      }
    ]
  }
}

resource privateDnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: privateDnsZone
  location: 'Global'
  name: 'link-${vnet.name}'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

resource publicDnsZone 'Microsoft.Network/dnsZones@2018-05-01' = {
  name: frontendDnsZoneName
  location: 'global'
}

resource appgwRecord 'Microsoft.Network/dnsZones/A@2018-05-01' = {
  parent: publicDnsZone
  name: 'appgw'
  properties: {
    TTL: 300
    ARecords: [
      {
        ipv4Address: publicIP.properties.ipAddress
      }
    ]
  }
}

resource aksRbacAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' =  [for rbacAssignment in aksRbacAssignments: {
  name: guid(aksClusterName, rbacAssignment.roleDefinitionID, rbacAssignment.principalId, resourceGroup().id)
  scope: aks
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', rbacAssignment.roleDefinitionID)
    principalId: rbacAssignment.principalId
    principalType: rbacAssignment.principalType
  }
} ]

var networkContribRoleDefinitionID = '4d97b98b-1d4f-4787-a291-c67834d212e7'
var roleAssignmentName = guid(aksClusterName, networkContribRoleDefinitionID, resourceGroup().id)

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: roleAssignmentName
  scope: vnet
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', networkContribRoleDefinitionID)
    principalId: aks.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource aksMsi 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' = {
  location: location
  name: externalDnsManagedIdentityName
}

var dnsZoneRoleAssignmentId = 'befefa01-2a29-4197-83a8-272ff33ce314'
var dnsZoneRoleAssignmentName = guid(aksMsi.name, dnsZoneRoleAssignmentId, resourceGroup().id)

resource dnsRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: dnsZoneRoleAssignmentName
  scope: publicDnsZone
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', dnsZoneRoleAssignmentId)
    principalId: aksMsi.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

var readerRoleAssignmentId = 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
var readerRoleAssignmentName = guid(aksMsi.name, readerRoleAssignmentId, resourceGroup().id)

resource readerRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: readerRoleAssignmentName
  scope: resourceGroup()
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', readerRoleAssignmentId)
    principalId: aksMsi.properties.principalId
    principalType: 'ServicePrincipal'
  }
}


@minLength(5)
@maxLength(50)
@description('Name of the azure container registry (must be globally unique)')
param acrName string

@description('Enable an admin user that has push/pull permission to the registry.')
param acrAdminUserEnabled bool = false

@allowed([
  'Basic'
  'Standard'
  'Premium'
])
@description('Tier of your Azure Container Registry.')
param acrSku string = 'Basic'

// azure container registry
resource acr 'Microsoft.ContainerRegistry/registries@2021-09-01' = {
  name: acrName
  location: location
  tags: {
    displayName: 'Container Registry'
    'container.registry': acrName
  }
  sku: {
    name: acrSku
  }
  properties: {
    adminUserEnabled: acrAdminUserEnabled
  }
}

output acrLoginServer string = acr.properties.loginServer

resource acrDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'Log Analytics'
  scope: acr
  properties: {
    workspaceId: logAnalytics.id
    logs: [
      {
        category: 'ContainerRegistryRepositoryEvents'
        enabled: true
      }
      {
        category: 'ContainerRegistryLoginEvents'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

resource staticWebAppCustomDomain 'Microsoft.Web/staticSites/customDomains@2023-12-01' = {
  parent: staticWebApp
  dependsOn: [
    cnameRecord
  ]
  name: '${webAppCNAME}.${frontendDnsZoneName}'
  properties: {}
}
