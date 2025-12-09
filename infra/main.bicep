// =============================================================================
// main.bicep - Azure Container Apps + Application Gateway アクセス制御検証
// =============================================================================
// このBicepファイルは、External VIP構成のContainer Apps環境に対して
// Application Gateway経由のアクセス制御を検証するためのインフラを構築します。
//
// 主要コンポーネント:
// - Virtual Network (3サブネット: AppGW, Private Endpoint, Container Apps)
// - Container Apps Environment (Workload Profiles, External VIP)
// - Container App (検証用サンプルアプリ)
// - Private Endpoint (Container Apps環境へのプライベート接続)
// - Private DNS Zone (FQDN解決)
// - Application Gateway (Standard_v2)
// =============================================================================

targetScope = 'resourceGroup'

// -----------------------------------------------------------------------------
// Parameters
// -----------------------------------------------------------------------------
@description('デプロイ先のAzureリージョン')
param location string = 'japaneast'

@description('リソース名のプレフィックス')
param prefix string = 'acaeval'

@description('Container Apps環境のpublic network access設定')
@allowed(['Enabled', 'Disabled'])
param publicNetworkAccess string = 'Enabled'

// -----------------------------------------------------------------------------
// Variables
// -----------------------------------------------------------------------------
var vnetName = 'vnet-${prefix}'
var caeName = 'cae-${prefix}'
var caName = 'ca-${prefix}'
var peName = 'pe-${prefix}'
var agwName = 'agw-${prefix}'

// -----------------------------------------------------------------------------
// Virtual Network
// -----------------------------------------------------------------------------
module vnet 'modules/vnet.bicep' = {
  name: 'vnet-deployment'
  params: {
    name: vnetName
    location: location
  }
}

// -----------------------------------------------------------------------------
// Container Apps Environment
// Workload Profiles環境を使用（Private Endpointサポートに必須）
// -----------------------------------------------------------------------------
module containerAppsEnv 'modules/container-apps-env.bicep' = {
  name: 'cae-deployment'
  params: {
    name: caeName
    location: location
    infrastructureSubnetId: vnet.outputs.caeSubnetId
    publicNetworkAccess: publicNetworkAccess
  }
}

// -----------------------------------------------------------------------------
// Container App
// 検証用サンプルアプリ（mcr.microsoft.com/k8se/quickstart:latest）
// -----------------------------------------------------------------------------
module containerApp 'modules/container-app.bicep' = {
  name: 'ca-deployment'
  params: {
    name: caName
    location: location
    environmentId: containerAppsEnv.outputs.id
  }
}

// -----------------------------------------------------------------------------
// Private Endpoint
// Container Apps環境へのプライベート接続
// 重要: Private Endpointを作成するには publicNetworkAccess = Disabled が必須
// https://learn.microsoft.com/ja-jp/azure/container-apps/networking#private-endpoint
// -----------------------------------------------------------------------------
module privateEndpoint 'modules/private-endpoint.bicep' = if (publicNetworkAccess == 'Disabled') {
  name: 'pe-deployment'
  params: {
    name: peName
    location: location
    subnetId: vnet.outputs.peSubnetId
    targetResourceId: containerAppsEnv.outputs.id
  }
}

// -----------------------------------------------------------------------------
// Private DNS Zone
// Container Apps環境のFQDNをPrivate Endpoint IPに解決
// publicNetworkAccess = Disabled の場合のみデプロイ
// -----------------------------------------------------------------------------
module privateDnsZone 'modules/private-dns-zone.bicep' = if (publicNetworkAccess == 'Disabled') {
  name: 'pdns-deployment'
  params: {
    zoneName: containerAppsEnv.outputs.defaultDomain
    vnetId: vnet.outputs.vnetId
    vnetLinkName: 'link-${vnetName}'
    // privateEndpointは同じ条件(publicNetworkAccess == 'Disabled')でデプロイされるため、
    // このモジュールが実行される時点では必ず存在する
    privateEndpointIp: privateEndpoint!.outputs.privateIpAddress
  }
}

// -----------------------------------------------------------------------------
// Application Gateway
// インターネット境界として機能するL7ロードバランサー
// バックエンドにContainer AppのFQDNを設定
// publicNetworkAccess = Disabled の場合はPrivate DNS Zone経由で解決
// publicNetworkAccess = Enabled の場合はパブリックFQDNで直接解決
// -----------------------------------------------------------------------------
module applicationGateway 'modules/application-gateway.bicep' = {
  name: 'agw-deployment'
  params: {
    name: agwName
    location: location
    subnetId: vnet.outputs.appGwSubnetId
    backendFqdn: containerApp.outputs.fqdn
  }
  dependsOn: [
    // publicNetworkAccess = Disabled の場合、Private DNS Zoneが先に必要
    // Enabled の場合は privateDnsZone モジュールはデプロイされないが、
    // Bicepは条件付きモジュールへのdependsOnを自動的に無視する
    privateDnsZone
  ]
}

// -----------------------------------------------------------------------------
// Outputs
// -----------------------------------------------------------------------------
@description('Application GatewayのパブリックIP')
output appGatewayPublicIp string = applicationGateway.outputs.publicIpAddress

@description('Container AppのFQDN')
output containerAppFqdn string = containerApp.outputs.fqdn

@description('Private EndpointのプライベートIP (publicNetworkAccess=Disabledの場合のみ)')
output privateEndpointIp string = privateEndpoint.?outputs.?privateIpAddress ?? ''

@description('Container Apps Environmentのデフォルトドメイン')
output containerAppsEnvDefaultDomain string = containerAppsEnv.outputs.defaultDomain

@description('VNet名')
output vnetName string = vnet.outputs.vnetName
