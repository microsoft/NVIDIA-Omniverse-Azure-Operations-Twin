param virtualNetworkName string
param location string
param addressPrefixes array
param subnets array

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: addressPrefixes
    }
    subnets: subnets
  }
}

output id string = virtualNetwork.id
