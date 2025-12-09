#!/bin/bash
set -euo pipefail

# =============================================================================
# test-access.sh - アクセス検証スクリプト
# =============================================================================
# Usage:
#   ./test-access.sh                    # 全テスト実行
#   ./test-access.sh appgw              # Application Gateway経由のみ
#   ./test-access.sh direct             # 直接アクセスのみ
#   ./test-access.sh migration          # 移行シナリオテスト
# =============================================================================

RESOURCE_GROUP="${RESOURCE_GROUP:-rg-aca-accessibility-eval}"
TEST_MODE="${1:-all}"

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Azure Container Apps アクセス検証"
echo "=========================================="
echo ""
echo "Resource Group: $RESOURCE_GROUP"
echo "Test Mode: $TEST_MODE"
echo ""

# -----------------------------------------------------------------------------
# デプロイ出力の取得
# -----------------------------------------------------------------------------
get_deployment_outputs() {
  echo ">>> デプロイ出力を取得しています..."

  # 最新のmain-*デプロイメントを取得
  DEPLOYMENT_NAME=$(az deployment group list \
    --resource-group "$RESOURCE_GROUP" \
    --query "[?starts_with(name, 'main-')] | sort_by(@, &properties.timestamp) | [-1].name" \
    --output tsv 2>/dev/null || echo "")

  if [ -z "$DEPLOYMENT_NAME" ]; then
    echo -e "${RED}エラー: デプロイメントが見つかりません${NC}"
    echo "先に ./scripts/deploy.sh を実行してください"
    exit 1
  fi

  echo "デプロイメント名: $DEPLOYMENT_NAME"

  AGW_IP=$(az deployment group show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DEPLOYMENT_NAME" \
    --query "properties.outputs.appGatewayPublicIp.value" \
    --output tsv 2>/dev/null || echo "")

  CA_FQDN=$(az deployment group show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DEPLOYMENT_NAME" \
    --query "properties.outputs.containerAppFqdn.value" \
    --output tsv 2>/dev/null || echo "")

  PE_IP=$(az deployment group show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DEPLOYMENT_NAME" \
    --query "properties.outputs.privateEndpointIp.value" \
    --output tsv 2>/dev/null || echo "")

  echo ""
  echo "Application Gateway IP: $AGW_IP"
  echo "Container App FQDN: $CA_FQDN"
  echo "Private Endpoint IP: $PE_IP"
  echo ""
}

# -----------------------------------------------------------------------------
# テスト結果の表示
# -----------------------------------------------------------------------------
print_result() {
  local test_name="$1"
  local expected="$2"
  local actual="$3"
  local pass="$4"

  if [ "$pass" = "true" ]; then
    echo -e "${GREEN}✓ PASS${NC} - $test_name"
    echo "  期待値: $expected, 実際: $actual"
  else
    echo -e "${RED}✗ FAIL${NC} - $test_name"
    echo "  期待値: $expected, 実際: $actual"
  fi
  echo ""
}

# -----------------------------------------------------------------------------
# User Story 1: Application Gateway経由のアクセス検証
# -----------------------------------------------------------------------------
test_appgw_access() {
  echo "=========================================="
  echo "User Story 1: Application Gateway経由アクセス"
  echo "=========================================="
  echo ""

  if [ -z "$AGW_IP" ]; then
    echo -e "${RED}エラー: Application Gateway IPが取得できません${NC}"
    return 1
  fi

  echo ">>> Application Gateway経由でアクセスしています..."
  echo "    URL: http://$AGW_IP"
  echo ""

  # HTTP 200レスポンスを期待
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 30 "http://$AGW_IP" 2>/dev/null || echo "000")

  if [ "$HTTP_CODE" = "200" ]; then
    print_result "AppGW経由アクセス" "200" "$HTTP_CODE" "true"
    return 0
  else
    print_result "AppGW経由アクセス" "200" "$HTTP_CODE" "false"
    return 1
  fi
}

# -----------------------------------------------------------------------------
# User Story 2: 直接アクセス拒否検証
# -----------------------------------------------------------------------------
test_direct_access_denial() {
  echo "=========================================="
  echo "User Story 2: 直接アクセス拒否"
  echo "=========================================="
  echo ""

  if [ -z "$CA_FQDN" ]; then
    echo -e "${RED}エラー: Container App FQDNが取得できません${NC}"
    return 1
  fi

  echo ">>> Container Appに直接アクセスしています..."
  echo "    URL: https://$CA_FQDN"
  echo ""

  # public network access Disabled時は接続拒否またはタイムアウトを期待
  # curl が失敗しても継続するため set +e を使用
  set +e
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "https://$CA_FQDN" 2>/dev/null)
  CURL_EXIT=$?
  set -e

  # curl 自体が失敗した場合（接続エラー等）
  if [ -z "$HTTP_CODE" ] || [ "$CURL_EXIT" -ne 0 ] && [ "$HTTP_CODE" = "000" ]; then
    HTTP_CODE="000"
  fi

  # 000 (接続失敗), 403 (アクセス拒否), または 502/503 (バックエンドエラー) を期待
  if [[ "$HTTP_CODE" =~ ^0+$ ]] || [ "$HTTP_CODE" = "403" ] || [ "$HTTP_CODE" = "502" ] || [ "$HTTP_CODE" = "503" ]; then
    print_result "直接アクセス拒否" "000/403/502/503" "$HTTP_CODE" "true"
    return 0
  elif [ "$HTTP_CODE" = "200" ]; then
    echo -e "${YELLOW}注意: public network accessがEnabledの可能性があります${NC}"
    print_result "直接アクセス拒否" "000/403/502/503" "$HTTP_CODE" "false"
    return 1
  else
    print_result "直接アクセス拒否" "000/403/502/503" "$HTTP_CODE" "false"
    return 1
  fi
}

# -----------------------------------------------------------------------------
# User Story 2: public network access Enabled時の直接アクセス成功検証
# -----------------------------------------------------------------------------
test_direct_access_enabled() {
  echo "=========================================="
  echo "直接アクセス (public network access: Enabled)"
  echo "=========================================="
  echo ""

  if [ -z "$CA_FQDN" ]; then
    echo -e "${RED}エラー: Container App FQDNが取得できません${NC}"
    return 1
  fi

  echo ">>> Container Appに直接アクセスしています..."
  echo "    URL: https://$CA_FQDN"
  echo ""

  # HTTP 200レスポンスを期待
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 30 "https://$CA_FQDN" 2>/dev/null || echo "000")

  if [ "$HTTP_CODE" = "200" ]; then
    print_result "直接アクセス (Enabled時)" "200" "$HTTP_CODE" "true"
    return 0
  else
    print_result "直接アクセス (Enabled時)" "200" "$HTTP_CODE" "false"
    return 1
  fi
}

# -----------------------------------------------------------------------------
# User Story 3: 移行シナリオテスト
# -----------------------------------------------------------------------------
test_migration_scenario() {
  echo "=========================================="
  echo "User Story 3: 移行シナリオテスト"
  echo "=========================================="
  echo ""

  echo "移行シナリオテストは手動で実行してください:"
  echo ""
  echo "1. public network access: Enabled でデプロイ"
  echo "   ./scripts/deploy.sh Enabled"
  echo ""
  echo "2. 初期状態を確認"
  echo "   ./scripts/test-access.sh appgw    # 成功するはず"
  echo "   ./scripts/test-access.sh direct   # 成功するはず (Enabled時)"
  echo ""
  echo "3. public network access: Disabled に変更"
  echo "   ./scripts/deploy.sh Disabled"
  echo ""
  echo "4. 最終状態を確認"
  echo "   ./scripts/test-access.sh appgw    # 成功するはず"
  echo "   ./scripts/test-access.sh direct   # 失敗するはず (Disabled時)"
  echo ""
}

# -----------------------------------------------------------------------------
# メイン処理
# -----------------------------------------------------------------------------
get_deployment_outputs

case "$TEST_MODE" in
  "appgw")
    test_appgw_access
    ;;
  "direct")
    test_direct_access_denial
    ;;
  "direct-enabled")
    test_direct_access_enabled
    ;;
  "migration")
    test_migration_scenario
    ;;
  "all")
    echo ">>> 全テストを実行しています..."
    echo ""

    APPGW_RESULT=0
    DIRECT_RESULT=0

    test_appgw_access || APPGW_RESULT=1
    test_direct_access_denial || DIRECT_RESULT=1

    echo "=========================================="
    echo "テスト結果サマリー"
    echo "=========================================="

    if [ "$APPGW_RESULT" -eq 0 ]; then
      echo -e "${GREEN}✓${NC} AppGW経由アクセス: PASS"
    else
      echo -e "${RED}✗${NC} AppGW経由アクセス: FAIL"
    fi

    if [ "$DIRECT_RESULT" -eq 0 ]; then
      echo -e "${GREEN}✓${NC} 直接アクセス拒否: PASS"
    else
      echo -e "${RED}✗${NC} 直接アクセス拒否: FAIL"
    fi

    echo ""

    if [ "$APPGW_RESULT" -eq 0 ] && [ "$DIRECT_RESULT" -eq 0 ]; then
      echo -e "${GREEN}全テストPASS${NC}"
      exit 0
    else
      echo -e "${RED}一部テストFAIL${NC}"
      exit 1
    fi
    ;;
  *)
    echo "Usage: $0 [appgw|direct|direct-enabled|migration|all]"
    exit 1
    ;;
esac
