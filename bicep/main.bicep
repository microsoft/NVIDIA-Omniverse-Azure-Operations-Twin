targetScope='subscription'

param resourceGroupName string
param location string
param vnetAddressPrefix string
param aksSubnetAddressPrefix string
param wafSubnetAddressPrefix string
param apimSubnetAddressPrefix string
param nsgName string
param clusterName string
param dnsPrefix string
param agentPoolVMSize string
param cachePoolVMSize string
param gpuPoolVMSize string
param apimPublisherName string
param apimPublisherEmail string
param apimGwHostName string
param apimMgmtHostName string
param customDomainHostNameSslCertKeyVaultId string

resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
    name: resourceGroupName
    location: location
}

module keyVault 'modules/keyvault.bicep' = {
    scope: resourceGroup
    name: 'keyVaultDeploy'
    params: {
        keyVaultName: 'kv-nvidia'
        location: location
    }
}

module nsg 'modules/nsg.bicep' = {
    scope: resourceGroup
    name: 'nsgDeploy'
    params: {
        nsgName: nsgName
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
        virtualNetworkName: 'vnet-nvidia'
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
                        id: nsg.outputs.id
                    }
                }
            }
            {
                name: 'subnet-waf'
                properties: {
                    addressPrefix: wafSubnetAddressPrefix
                }
            }
            {
                name: 'subnet-apim'
                properties: {
                    addressPrefix: apimSubnetAddressPrefix
                    networkSecurityGroup: {
                        id: nsg.outputs.id
                    }
                }
            }
        ]
    }
}

module aks 'modules/aks.bicep' = {
    scope: resourceGroup
    name: 'aksDeploy'
    params: {
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
        subnetId: '${vnet.outputs.id}/subnets/subnet-aks'
    }
}

module apim 'modules/apim.bicep' = {
    scope: resourceGroup
    name: 'apimDeploy'
    params: {
        apiManagementServiceName: 'apim-nvidia'
        location: location
        publisherName: apimPublisherName
        publisherEmail: apimPublisherEmail
        subnetId: '${vnet.outputs.id}/subnets/subnet-apim'
        // serviceUrl: 'https://${apimGwHostName}'
        hostNameConfigurations: [
            {
                type: 'Proxy'
                hostName: apimGwHostName
                defaultSslBinding: true
                negotiateClientCertificate: false
                certificateSource: 'KeyVault'
                keyVaultId: customDomainHostNameSslCertKeyVaultId
            }
            {
                type: 'Management'
                hostName: apimMgmtHostName
                certificateSource: 'KeyVault'
                keyVaultId: customDomainHostNameSslCertKeyVaultId
            }
        ]
    }
}

module appgw 'modules/appgateway.bicep' = {
    scope: resourceGroup
    name: 'appGatewayDeploy'
    params: {
        applicationGatewayName: 'appgw-nvidia'
        location: location
        subnetId: '${vnet.outputs.id}/subnets/subnet-waf'
        minCapacity: 2
        maxCapacity: 3
        cookieBasedAffinity: 'Disabled'
    }
}

module acr 'modules/acr.bicep' = {
    scope: resourceGroup
    name: 'acrDeploy'
    params: {
        acrName: 'acrnvidia'
        location: location
    }
}

// module apimCustomDomains 'modules/apim.bicep' = {
//     scope: resourceGroup
//     name: 'apimCustomDomainsDeploy'
//     dependsOn: [
//         apim
//     ]
//     params: {
//         apiManagementServiceName: 'apim-nvidia'
//         location: location
//         publisherName: apimPublisherName
//         publisherEmail: apimPublisherEmail
//         subnetId: '${vnet.outputs.id}/subnets/subnet-aks'
//         hostNameConfigurations: [
//             {
//                 type: 'Proxy'
//                 hostName: apimGwHostName
//                 defaultSslBinding: true
//                 negotiateClientCertificate: false
//                 certificateSource: 'KeyVault'
//                 keyVaultId: customDomainHostNameSslCertKeyVaultId
//             }
//             {
//                 type: 'Management'
//                 hostName: apimMgmtHostName
//                 defaultSslBinding: true
//                 negotiateClientCertificate: false
//                 certificateSource: 'KeyVault'
//                 keyVaultId: customDomainHostNameSslCertKeyVaultId
//             }
//         ]
//     }
// }

// resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
//     name: 'apimSecretsUserRbacDeploy'
//     properties: {
//       roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', guid(apim.outputs.principalId, '4633458b-17de-408a-b874-0445c86b69e6', resourceGroup.id))
//       principalId: apim.outputs.principalId
//     }
//   }
