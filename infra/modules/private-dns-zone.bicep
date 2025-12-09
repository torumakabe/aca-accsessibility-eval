// =============================================================================
// private-dns-zone.bicep - Private DNS Zone for Container Apps Environment
// =============================================================================

@description('DNS Zone名（Container Apps Environmentのdefault domain）')
param zoneName string

@description('リンクするVNetのリソースID')
param vnetId string

@description('VNetリンク名')
param vnetLinkName string = 'link-vnet'

@description('Private EndpointのプライベートIPアドレス')
param privateEndpointIp string

// -----------------------------------------------------------------------------
// Private DNS Zone
// -----------------------------------------------------------------------------
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: zoneName
  location: 'global'
}

// -----------------------------------------------------------------------------
// VNet Link
// -----------------------------------------------------------------------------
resource vnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: privateDnsZone
  name: vnetLinkName
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnetId
    }
    registrationEnabled: false
  }
}

// -----------------------------------------------------------------------------
// DNS Records
// Container Apps環境へのアクセスにはワイルドカードレコードとルートレコードが必要
// -----------------------------------------------------------------------------
resource wildcardRecord 'Microsoft.Network/privateDnsZones/A@2024-06-01' = {
  parent: privateDnsZone
  name: '*'
  properties: {
    ttl: 3600
    aRecords: [
      {
        ipv4Address: privateEndpointIp
      }
    ]
  }
}

resource rootRecord 'Microsoft.Network/privateDnsZones/A@2024-06-01' = {
  parent: privateDnsZone
  name: '@'
  properties: {
    ttl: 3600
    aRecords: [
      {
        ipv4Address: privateEndpointIp
      }
    ]
  }
}

// -----------------------------------------------------------------------------
// Outputs
// -----------------------------------------------------------------------------
@description('Private DNS ZoneのリソースID')
output id string = privateDnsZone.id

@description('Private DNS Zoneの名前')
output name string = privateDnsZone.name
