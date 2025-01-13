targetScope='subscription'

param resourceGroupName string
param location string
param keyVaultName string = 'kv-nvidia'

resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
}

module keyVault 'modules/keyvault.bicep' = {
  scope: resourceGroup
  name: 'keyVaultDeploy'
  params: {
      keyVaultName: keyVaultName
      location: location
  }
}
