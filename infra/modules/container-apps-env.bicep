// =============================================================================
// container-apps-env.bicep - Container Apps Environment (Workload Profiles)
// =============================================================================

@description('環境名')
param name string

@description('リージョン')
param location string

@description('インフラストラクチャサブネットID')
param infrastructureSubnetId string

@description('public network access設定')
@allowed(['Enabled', 'Disabled'])
param publicNetworkAccess string = 'Enabled'

// -----------------------------------------------------------------------------
// Container Apps Environment (Workload Profiles)
// Private Endpointサポートのため、Workload Profiles環境を使用
// -----------------------------------------------------------------------------
resource containerAppsEnv 'Microsoft.App/managedEnvironments@2024-10-02-preview' = {
  name: name
  location: location
  properties: {
    // External VIP - インターネットからアクセス可能な構成
    vnetConfiguration: {
      infrastructureSubnetId: infrastructureSubnetId
      internal: false
    }
    // Workload Profiles - Private Endpointサポートに必須
    workloadProfiles: [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
    ]
    // public network access設定
    publicNetworkAccess: publicNetworkAccess
    // ゾーン冗長は検証環境では無効
    zoneRedundant: false
  }
}

// -----------------------------------------------------------------------------
// Outputs
// -----------------------------------------------------------------------------
@description('Container Apps EnvironmentのリソースID')
output id string = containerAppsEnv.id

@description('Container Apps Environmentの名前')
output name string = containerAppsEnv.name

@description('デフォルトドメイン')
output defaultDomain string = containerAppsEnv.properties.defaultDomain

@description('静的IP')
output staticIp string = containerAppsEnv.properties.staticIp
