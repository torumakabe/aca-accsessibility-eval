// =============================================================================
// vnet.bicep - Virtual Network with subnets for ACA accessibility evaluation
// =============================================================================

@description('VNet名')
param name string

@description('リージョン')
param location string

@description('VNetのアドレス空間')
param addressPrefix string = '10.0.0.0/16'

@description('Application Gatewayサブネットのアドレスプレフィックス')
param appGwSubnetPrefix string = '10.0.1.0/24'

@description('Private Endpointサブネットのアドレスプレフィックス')
param peSubnetPrefix string = '10.0.2.0/24'

@description('Container Apps Environmentサブネットのアドレスプレフィックス')
param caeSubnetPrefix string = '10.0.16.0/23'

// -----------------------------------------------------------------------------
// Virtual Network
// -----------------------------------------------------------------------------
resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [
      {
        name: 'snet-appgw'
        properties: {
          addressPrefix: appGwSubnetPrefix
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: 'snet-pe'
        properties: {
          addressPrefix: peSubnetPrefix
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: 'snet-cae'
        properties: {
          addressPrefix: caeSubnetPrefix
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          delegations: [
            {
              name: 'Microsoft.App.environments'
              properties: {
                serviceName: 'Microsoft.App/environments'
              }
            }
          ]
        }
      }
    ]
  }
}

// -----------------------------------------------------------------------------
// Outputs
// -----------------------------------------------------------------------------
@description('VNetのリソースID')
output vnetId string = vnet.id

@description('VNetの名前')
output vnetName string = vnet.name

@description('Application Gatewayサブネットのリソースid')
output appGwSubnetId string = vnet.properties.subnets[0].id

@description('Private EndpointサブネットのリソースID')
output peSubnetId string = vnet.properties.subnets[1].id

@description('Container Apps EnvironmentサブネットのリソースID')
output caeSubnetId string = vnet.properties.subnets[2].id
