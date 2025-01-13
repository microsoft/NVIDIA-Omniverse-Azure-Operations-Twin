@description('The name of the API Management service instance')
param apiManagementServiceName string = 'apiservice${uniqueString(resourceGroup().id)}'

@description('The email address of the owner of the service')
@minLength(1)
param publisherEmail string

@description('The name of the owner of the service')
@minLength(1)
param publisherName string

@description('The pricing tier of this API Management service')
@allowed([
  'Consumption'
  'Developer'
  'Basic'
  'Basicv2'
  'Standard'
  'Standardv2'
  'Premium'
])
param sku string = 'Developer'

@description('The instance size of this API Management service.')
@allowed([
  0
  1
  2
])
param skuCount int = 1

@description('Location for all resources.')
param location string = resourceGroup().location

param subnetId string
param hostNameConfigurations array = []
// param serviceUrl string

#disable-next-line BCP081
resource apiManagementService 'Microsoft.ApiManagement/service@2024-06-01-preview' = {
  name: apiManagementServiceName
  location: location
  sku: {
    name: sku
    capacity: skuCount
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
    virtualNetworkConfiguration: {
      subnetResourceId: subnetId
    }
    virtualNetworkType: 'Internal'
    hostnameConfigurations: hostNameConfigurations
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
    serviceUrl: 'https://api.beckerobrien.com'
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
    method: 'DEL'
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
    method: 'OPT'
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

output principalId string = apiManagementService.identity.principalId
