// =============================================================================
// private-endpoint.bicep - Private Endpoint for Container Apps Environment
// =============================================================================

@description('Private Endpoint名')
param name string

@description('リージョン')
param location string

@description('Private Endpointを配置するサブネットID')
param subnetId string

@description('ターゲットリソースID（Container Apps Environment）')
param targetResourceId string

@description('グループID')
param groupIds array = ['managedEnvironments']

// -----------------------------------------------------------------------------
// Private Endpoint
// -----------------------------------------------------------------------------
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: name
  location: location
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'plsc-${name}'
        properties: {
          privateLinkServiceId: targetResourceId
          groupIds: groupIds
        }
      }
    ]
  }
}

// -----------------------------------------------------------------------------
// Outputs
// -----------------------------------------------------------------------------
@description('Private EndpointのリソースID')
output id string = privateEndpoint.id

@description('Private Endpointの名前')
output name string = privateEndpoint.name

@description('Private EndpointのプライベートIPアドレス')
output privateIpAddress string = privateEndpoint.properties.customDnsConfigs[0].ipAddresses[0]
