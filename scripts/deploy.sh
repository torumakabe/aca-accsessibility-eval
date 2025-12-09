#!/bin/bash
set -euo pipefail

# デプロイスクリプト
# Usage: ./deploy.sh [Enabled|Disabled]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$SCRIPT_DIR/../infra"

# 環境変数のデフォルト値
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-aca-accessibility-eval}"
LOCATION="${LOCATION:-japaneast}"
PUBLIC_NETWORK_ACCESS="${1:-Enabled}"

echo "=========================================="
echo "Azure Container Apps + Application Gateway"
echo "アクセス制御検証 デプロイスクリプト"
echo "=========================================="
echo ""
echo "Resource Group: $RESOURCE_GROUP"
echo "Location: $LOCATION"
echo "Public Network Access: $PUBLIC_NETWORK_ACCESS"
echo ""

# リソースグループの作成
echo ">>> リソースグループを作成しています..."
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --output none

echo ">>> リソースグループを作成しました: $RESOURCE_GROUP"

# Bicepデプロイ
echo ""
echo ">>> インフラストラクチャをデプロイしています..."
echo "    (このプロセスは10-15分かかる場合があります)"
echo ""

az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file "$INFRA_DIR/main.bicep" \
  --parameters "$INFRA_DIR/main.bicepparam" \
  --parameters publicNetworkAccess="$PUBLIC_NETWORK_ACCESS" \
  --name "main-$(date +%Y%m%d%H%M%S)"

echo ""
echo ">>> デプロイが完了しました"
echo ""

# 出力の取得
echo ">>> デプロイ出力を取得しています..."
DEPLOYMENT_NAME=$(az deployment group list \
  --resource-group "$RESOURCE_GROUP" \
  --query "[?starts_with(name, 'main-')] | [0].name" \
  --output tsv)

APP_GW_IP=$(az deployment group show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$DEPLOYMENT_NAME" \
  --query "properties.outputs.appGatewayPublicIp.value" \
  --output tsv 2>/dev/null || echo "N/A")

CA_FQDN=$(az deployment group show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$DEPLOYMENT_NAME" \
  --query "properties.outputs.containerAppFqdn.value" \
  --output tsv 2>/dev/null || echo "N/A")

PE_IP=$(az deployment group show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$DEPLOYMENT_NAME" \
  --query "properties.outputs.privateEndpointIp.value" \
  --output tsv 2>/dev/null || echo "N/A")

echo ""
echo "=========================================="
echo "デプロイ結果"
echo "=========================================="
echo "Application Gateway Public IP: $APP_GW_IP"
echo "Container App FQDN: $CA_FQDN"
echo "Private Endpoint IP: $PE_IP"
echo ""
echo "次のステップ:"
echo "  1. Application Gateway経由でアクセス: curl http://$APP_GW_IP"
echo "  2. Container Appに直接アクセス: curl https://$CA_FQDN"
echo "  3. テストスクリプト実行: ./scripts/test-access.sh"
echo ""
