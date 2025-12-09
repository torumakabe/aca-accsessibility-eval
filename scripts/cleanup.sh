#!/bin/bash
set -euo pipefail

# クリーンアップスクリプト
# Usage: ./cleanup.sh [--force]

RESOURCE_GROUP="${RESOURCE_GROUP:-rg-aca-accessibility-eval}"
FORCE="${1:-}"

echo "=========================================="
echo "リソースクリーンアップ"
echo "=========================================="
echo ""
echo "削除対象リソースグループ: $RESOURCE_GROUP"
echo ""

# リソースグループの存在確認
if ! az group show --name "$RESOURCE_GROUP" &>/dev/null; then
  echo "リソースグループ '$RESOURCE_GROUP' は存在しません。"
  exit 0
fi

# 確認プロンプト（--forceオプションがない場合）
if [ "$FORCE" != "--force" ]; then
  echo "警告: この操作はリソースグループ内のすべてのリソースを削除します。"
  echo ""
  read -p "続行しますか？ (yes/no): " CONFIRM
  if [ "$CONFIRM" != "yes" ]; then
    echo "キャンセルしました。"
    exit 0
  fi
fi

echo ""
echo ">>> リソースグループを削除しています..."
echo "    (バックグラウンドで実行中、完了まで数分かかります)"

az group delete \
  --name "$RESOURCE_GROUP" \
  --yes \
  --no-wait

echo ""
echo ">>> 削除リクエストを送信しました"
echo ""
echo "削除状況を確認するには:"
echo "  az group show --name $RESOURCE_GROUP --query properties.provisioningState -o tsv"
echo ""
echo "リソースグループが存在するか確認するには:"
echo "  az group exists --name $RESOURCE_GROUP"
echo ""
