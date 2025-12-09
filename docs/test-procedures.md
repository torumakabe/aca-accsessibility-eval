# テスト手順書

Azure Container Apps + Application Gateway アクセス制御検証のテスト手順を定義します。

## 前提条件

- Azure CLIがインストールされていること
- Azureサブスクリプションにログイン済みであること
- curlコマンドが利用可能であること

## テスト環境情報

| 項目 | 値 |
|------|-----|
| リソースグループ | rg-aca-accessibility-eval |
| リージョン | Japan East |
| Container Apps SKU | Workload Profiles |
| Application Gateway SKU | Standard_v2 |

---

## User Story 1: Application Gateway経由のアクセス許可検証

### 目的

External VIP環境でpublic network accessを無効化した状態で、Application Gateway経由でコンテナアプリにアクセスできることを確認する。

### テストケース 1.1: Enabled状態でのAppGW経由アクセス

**前提条件**: 
- インフラストラクチャがデプロイ済み
- public network access: Enabled

**手順**:

```bash
# 1. デプロイ出力からApplication Gateway IPを取得
AGW_IP=$(az deployment group show \
  --resource-group rg-aca-accessibility-eval \
  --name <deployment-name> \
  --query "properties.outputs.appGatewayPublicIp.value" \
  --output tsv)

# 2. Application Gateway経由でアクセス
curl -s -o /dev/null -w "%{http_code}" http://$AGW_IP
```

**期待結果**: HTTP 200

### テストケース 1.2: Disabled状態でのAppGW経由アクセス

**前提条件**:
- public network access: Disabled
- Private Endpoint、Private DNS Zoneが構成済み

**手順**:

```bash
# 1. public network accessをDisabledに変更
./scripts/deploy.sh Disabled

# 2. デプロイ完了後、Application Gateway経由でアクセス
curl -s -o /dev/null -w "%{http_code}" http://$AGW_IP
```

**期待結果**: HTTP 200

> **重要**: デプロイ直後はヘルスプローブが失敗する場合があります。これは Application Gateway の DNS キャッシュが原因です。
> Private DNS Zone の作成・リンク後、DNS TTL が切れるまで約10分程度待機が必要な場合があります。
> 詳細は「トラブルシューティング」セクションを参照してください。

**検証ポイント**:
- Application GatewayはPrivate DNS Zone経由でContainer Apps FQDNを解決
- Application Gatewayはバックエンド（Container App）にHTTPSで接続
- ヘルスプローブが正常に動作していること

### テストケース 1.3: AppGWヘルスプローブ確認

**手順**:

```bash
# Application Gatewayのバックエンドヘルス状態を確認
az network application-gateway show-backend-health \
  --resource-group rg-aca-accessibility-eval \
  --name agw-acaeval \
  --query "backendAddressPools[0].backendHttpSettingsCollection[0].servers[0].health" \
  --output tsv
```

**期待結果**: Healthy

---

## User Story 2: インターネット直接アクセス拒否検証

### 目的

public network accessを無効化したContainer Apps環境に対して、インターネットから直接アクセスが拒否されることを確認する。

### テストケース 2.1: Enabled状態での直接アクセス

**前提条件**:
- public network access: Enabled

**手順**:

```bash
# Container App FQDNを取得
CA_FQDN=$(az deployment group show \
  --resource-group rg-aca-accessibility-eval \
  --name <deployment-name> \
  --query "properties.outputs.containerAppFqdn.value" \
  --output tsv)

# 直接アクセス
curl -s -o /dev/null -w "%{http_code}" https://$CA_FQDN
```

**期待結果**: HTTP 200（Enabled時は成功）

### テストケース 2.2: Disabled状態での直接アクセス拒否

**前提条件**:
- public network access: Disabled

**手順**:

```bash
# 直接アクセス（タイムアウト設定付き）
curl -s -o /dev/null -w "%{http_code}" --max-time 10 https://$CA_FQDN
```

**期待結果**: 
- HTTP 000（接続拒否/タイムアウト）
- または HTTP 403（アクセス拒否）

### テストケース 2.3: 同時アクセステスト

**手順**:

```bash
# 並列でAppGW経由と直接アクセスを実行
echo "AppGW経由: $(curl -s -o /dev/null -w '%{http_code}' http://$AGW_IP)"
echo "直接アクセス: $(curl -s -o /dev/null -w '%{http_code}' --max-time 10 https://$CA_FQDN)"
```

**期待結果**:
- AppGW経由: 200
- 直接アクセス: 000/403

---

## User Story 3: 移行シナリオ検証

### 目的

既存External VIP環境からpublic network accessを無効化する移行手順を検証する。

### テストケース 3.1: Enabled → Disabled移行

**前提条件**:
- public network access: Enabled で稼働中

**手順**:

```bash
# 1. 初期状態確認（両方成功）
./scripts/test-access.sh appgw          # 期待: PASS
./scripts/test-access.sh direct-enabled # 期待: PASS

# 2. public network accessをDisabledに変更
./scripts/deploy.sh Disabled

# 3. 最終状態確認
./scripts/test-access.sh appgw   # 期待: PASS
./scripts/test-access.sh direct  # 期待: PASS（拒否されること）
```

**期待結果**:
- 設定変更が正常に完了
- AppGW経由のアクセスは継続して成功
- 直接アクセスは拒否される

### テストケース 3.2: ダウンタイム確認

**手順**:

```bash
# 移行中のアクセス監視（別ターミナルで実行）
while true; do
  echo "$(date +%H:%M:%S) - $(curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://$AGW_IP)"
  sleep 5
done
```

**期待結果**:
- 移行中に短時間のダウンタイムが発生する可能性あり
- 最終的にはすべてのリクエストが成功

---

## スクリプトによる自動テスト

### 全テスト実行

```bash
./scripts/test-access.sh all
```

### 個別テスト実行

```bash
# Application Gateway経由のみ
./scripts/test-access.sh appgw

# 直接アクセス拒否のみ
./scripts/test-access.sh direct

# 直接アクセス成功（Enabled時）
./scripts/test-access.sh direct-enabled

# 移行シナリオ説明
./scripts/test-access.sh migration
```

---

## トラブルシューティング

### Application Gatewayヘルスプローブが失敗する場合

#### DNS キャッシュ更新待ち

`publicNetworkAccess=Disabled` への変更直後、Private DNS Zone を作成・リンクしても、Application Gateway のヘルスプローブが一時的に失敗することがあります。

**原因**: Application Gateway はバックエンド FQDN の DNS 解決結果をキャッシュしており、TTL が切れるまで旧パブリック IP を参照し続けます。

**対処法**:
- **待機する**: DNS TTL 経過後（約10分程度）に自動的に解決されます
- **確認コマンド**:
  ```bash
  # バックエンドヘルス状態を定期的に確認
  az network application-gateway show-backend-health \
    --resource-group rg-aca-accessibility-eval \
    --name agw-acaeval \
    --query "backendAddressPools[0].backendHttpSettingsCollection[0].servers[0].health" \
    --output tsv
  ```

> **注意**: Application Gateway の再起動は不要です。

#### その他の確認事項

1. **Private DNS Zone確認**:
   ```bash
   az network private-dns record-set a list \
     --resource-group rg-aca-accessibility-eval \
     --zone-name <default-domain> \
     --output table
   ```

2. **VNetリンク確認**:
   ```bash
   az network private-dns link vnet list \
     --resource-group rg-aca-accessibility-eval \
     --zone-name <default-domain> \
     --output table
   ```

3. **Private Endpoint確認**:
   ```bash
   az network private-endpoint show \
     --resource-group rg-aca-accessibility-eval \
     --name pe-acaeval \
     --query "provisioningState" \
     --output tsv
   ```

### Container Appにアクセスできない場合

1. **Container Apps環境の状態確認**:
   ```bash
   az containerapp env show \
     --resource-group rg-aca-accessibility-eval \
     --name cae-acaeval \
     --query "{publicNetworkAccess:properties.publicNetworkAccess, provisioningState:properties.provisioningState}"
   ```

2. **Container Appのログ確認**:
   ```bash
   az containerapp logs show \
     --resource-group rg-aca-accessibility-eval \
     --name ca-acaeval \
     --follow
   ```

---

## 検証結果記録テンプレート

| テスト項目 | 期待値 | 実際の結果 | 日時 | Pass/Fail | 備考 |
|-----------|-------|-----------|------|-----------|------|
| US1-1: AppGW経由 (Enabled) | 200 | | | | |
| US1-2: AppGW経由 (Disabled) | 200 | | | | |
| US1-3: ヘルスプローブ | Healthy | | | | |
| US2-1: 直接 (Enabled) | 200 | | | | |
| US2-2: 直接 (Disabled) | 000/403 | | | | |
| US3-1: 移行後AppGW | 200 | | | | |
| US3-2: 移行後直接 | 000/403 | | | | |
