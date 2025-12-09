# Quickstart: Azure Container Apps + Application Gateway アクセス制御検証

## 前提条件

- Azure サブスクリプション
- Azure CLI
- Bicep CLI（Azure CLI同梱版で可）
- bash または zsh

### 動作確認環境

- OS: Linux (WSL2)
- Shell: zsh 5.8.1
- Azure CLI: 2.81.0
- Bicep CLI: 0.39.26

## 環境変数の設定

```bash
export RESOURCE_GROUP="rg-aca-accessibility-eval"
export LOCATION="japaneast"
export PREFIX="acaeval"
```

## Step 1: リソースグループの作成

```bash
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION
```

## Step 2: 初期デプロイ（public network access: Enabled）

> **重要**: Azure Container Apps では、Private Endpoint を作成するには `publicNetworkAccess = Disabled` が必須です。
> そのため、このプロジェクトでは：
> - `publicNetworkAccess = Enabled` の場合：VNet、Container Apps Environment、Container App、Application Gateway のみデプロイ
> - `publicNetworkAccess = Disabled` の場合：上記に加えて Private Endpoint と Private DNS Zone をデプロイ

```bash
cd infra

# パラメータを確認
cat main.bicepparam

# デプロイ実行（最初はpublic network access有効で、Private Endpointなし）
az deployment group create \
  --resource-group $RESOURCE_GROUP \
  --template-file main.bicep \
  --parameters main.bicepparam \
  --parameters publicNetworkAccess=Enabled
```

## Step 3: 初期状態の検証

### 3.1 Container App FQDN の取得

```bash
CA_FQDN=$(az deployment group show \
  --resource-group $RESOURCE_GROUP \
  --name main \
  --query properties.outputs.containerAppFqdn.value \
  --output tsv)

echo "Container App FQDN: $CA_FQDN"
```

### 3.2 直接アクセスの確認（成功するはず）

```bash
curl -s -o /dev/null -w "%{http_code}" https://$CA_FQDN
# Expected: 200
```

### 3.3 Application Gateway 経由のアクセス確認

```bash
AGW_IP=$(az deployment group show \
  --resource-group $RESOURCE_GROUP \
  --name main \
  --query properties.outputs.appGatewayPublicIp.value \
  --output tsv)

echo "Application Gateway IP: $AGW_IP"

curl -s -o /dev/null -w "%{http_code}" http://$AGW_IP
# Expected: 200
```

## Step 4: public network access を無効化

> **このステップで Private Endpoint と Private DNS Zone が追加デプロイされます**

```bash
# Container Apps 環境のpublic network accessを無効化
# → Private Endpoint と Private DNS Zone が作成される
az deployment group create \
  --resource-group $RESOURCE_GROUP \
  --template-file main.bicep \
  --parameters main.bicepparam \
  --parameters publicNetworkAccess=Disabled
```

## Step 5: 最終状態の検証

### 5.1 直接アクセスの確認（拒否されるはず）

```bash
curl -s -o /dev/null -w "%{http_code}" --max-time 10 https://$CA_FQDN
# Expected: 000 (connection refused/timeout) または 403
```

### 5.2 Application Gateway 経由のアクセス確認（成功するはず）

```bash
curl -s -o /dev/null -w "%{http_code}" http://$AGW_IP
# Expected: 200
```

## 検証結果の記録

| テスト項目 | 期待値 | 実際の結果 | Pass/Fail |
|-----------|-------|-----------|-----------|
| Step 3.2: 直接アクセス（Enabled時） | 200 | | |
| Step 3.3: AppGW経由（Enabled時） | 200 | | |
| Step 5.1: 直接アクセス（Disabled時） | 拒否/タイムアウト | | |
| Step 5.2: AppGW経由（Disabled時） | 200 | | |

## クリーンアップ

```bash
az group delete --name $RESOURCE_GROUP --yes --no-wait
```

## トラブルシューティング

### Application Gateway ヘルスプローブが失敗する場合

1. Private DNS Zone のレコードが正しく設定されているか確認
   ```bash
   az network private-dns record-set a list \
     --resource-group $RESOURCE_GROUP \
     --zone-name <default-domain> \
     --output table
   ```

2. VNet リンクが有効か確認
   ```bash
   az network private-dns link vnet list \
     --resource-group $RESOURCE_GROUP \
     --zone-name <default-domain> \
     --output table
   ```

### Container App にアクセスできない場合

1. Private Endpoint の状態を確認
   ```bash
   az network private-endpoint show \
     --resource-group $RESOURCE_GROUP \
     --name pe-cae-$PREFIX \
     --query 'provisioningState' \
     --output tsv
   ```

2. Container Apps 環境の状態を確認
   ```bash
   az containerapp env show \
     --resource-group $RESOURCE_GROUP \
     --name cae-$PREFIX \
     --query '{publicNetworkAccess:properties.publicNetworkAccess, provisioningState:properties.provisioningState}'
   ```
