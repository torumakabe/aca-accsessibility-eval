using 'main.bicep'

// デプロイ先のAzureリージョン
param location = 'japaneast'

// リソース名のプレフィックス
param prefix = 'acaeval'

// Container Apps環境のpublic network access設定
// 初回デプロイ時は'Enabled'、Private Endpoint設定後に'Disabled'に変更
param publicNetworkAccess = 'Enabled'
