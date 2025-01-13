param nsgName string
param location string
param securityRules array

resource nsg 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: securityRules
  }
}

output id string = nsg.id
