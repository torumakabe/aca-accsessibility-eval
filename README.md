# Azure Container Apps + Application Gateway アクセス制御検証

Azure Container Apps の External VIP 環境で `public network access` を無効化し、Application Gateway 経由のみでアクセス可能な構成を検証するプロジェクトです。

## 概要

このプロジェクトは以下の検証シナリオを実現します：

1. **Application Gateway 経由のアクセス許可**: public network access を無効化した状態でも、Application Gateway から Container App にアクセスできることを確認
2. **インターネット直接アクセス拒否**: Container App の FQDN への直接アクセスが拒否されることを確認
3. **移行シナリオ検証**: 既存 External 環境から public network access を無効化する移行手順を検証

## アーキテクチャ

```
Internet → Application Gateway → Private Endpoint → Container Apps Environment
                                      ↑
                               Private DNS Zone
```

詳細は [docs/architecture.md](docs/architecture.md) を参照してください。

## 前提条件

- Azure サブスクリプション
- Azure CLI
- Bicep CLI（Azure CLI 同梱版で可）
- bash または zsh

### 動作確認環境

- OS: Linux (WSL2)
- Shell: zsh 5.8.1
- Azure CLI: 2.81.0
- Bicep CLI: 0.39.26

## クイックスタート

### 1. 環境変数の設定

```bash
export RESOURCE_GROUP="rg-aca-accessibility-eval"
export LOCATION="japaneast"
```

### 2. デプロイ

```bash
# リソースグループ作成とインフラデプロイ（public network access: Enabled）
./scripts/deploy.sh Enabled
```

### 3. 検証

```bash
# Application Gateway 経由のアクセステスト
./scripts/test-access.sh appgw

# 直接アクセステスト（Enabled時は成功）
./scripts/test-access.sh direct-enabled
```

### 4. public network access を無効化

> **重要**: Azure Container Apps では Private Endpoint を作成するには `publicNetworkAccess = Disabled` が必須です。
> そのため、Disabled への変更時に Private Endpoint と Private DNS Zone が追加でデプロイされます。

```bash
# Disabled に変更（Private Endpoint と Private DNS Zone が追加デプロイされる）
./scripts/deploy.sh Disabled

# 再度テスト
./scripts/test-access.sh appgw   # 成功するはず
./scripts/test-access.sh direct  # 拒否されるはず
```

### 5. クリーンアップ

```bash
./scripts/cleanup.sh
```

## プロジェクト構成

```
.
├── infra/                    # Bicep インフラコード
│   ├── main.bicep           # メインオーケストレーション
│   ├── main.bicepparam      # パラメータファイル
│   └── modules/             # 個別モジュール
│       ├── vnet.bicep
│       ├── container-apps-env.bicep
│       ├── container-app.bicep
│       ├── private-endpoint.bicep
│       ├── private-dns-zone.bicep
│       └── application-gateway.bicep
├── scripts/                  # 操作スクリプト
│   ├── deploy.sh            # デプロイ
│   ├── cleanup.sh           # クリーンアップ
│   └── test-access.sh       # アクセス検証
├── docs/                     # ドキュメント
│   ├── architecture.md      # アーキテクチャ説明
│   └── test-procedures.md   # テスト手順
└── specs/                    # 仕様書（SpecKit）
    └── 001-aca-accessibility-control/
```

## 検証結果

| テスト項目 | public network access: Enabled | public network access: Disabled |
|-----------|--------------------------------|---------------------------------|
| AppGW 経由アクセス | ✅ 成功 (HTTP 200) | ✅ 成功 (HTTP 200) |
| 直接 FQDN アクセス | ✅ 成功 (HTTP 200) | ❌ 拒否 (接続失敗) |

## 技術的なポイント

- **External VIP + public network access Disabled = Private Endpoint 必須**
  - public network access を Disabled にすると、プライベートエンドポイント経由のみでアクセス可能
  - 同一 VNet 内からのアクセスでもプライベートエンドポイントが必要

- **Private DNS Zone の正しい構成が重要**
  - Container Apps 環境のデフォルトドメインで DNS Zone を作成
  - ワイルドカード (`*`) とルート (`@`) の両方の A レコードが必要

- **Application Gateway Backend 設定**
  - バックエンドターゲットは Container App の FQDN を使用
  - `Pick host name from backend address` を有効化
  - プロトコルは HTTPS (443)

- **DNS キャッシュによるプローブ成功までの待機時間**
  - Application Gateway はバックエンド FQDN の DNS 解決結果をキャッシュする
  - Private DNS Zone を作成・リンクしても、AppGW は DNS TTL が切れるまで旧 IP を参照し続ける
  - 検証では `publicNetworkAccess=Disabled` 設定後、ヘルスプローブが成功するまで約10分程度を要した
  - AppGW の再起動は不要。TTL 経過後に自動的に Private Endpoint IP へ切り替わる

## 関連ドキュメント

- [Azure Container Apps ネットワーキング](https://learn.microsoft.com/azure/container-apps/networking)
- [Azure Container Apps プライベートエンドポイント](https://learn.microsoft.com/azure/container-apps/private-endpoint-with-dns)
- [Application Gateway + Container Apps 統合](https://learn.microsoft.com/azure/container-apps/waf-app-gateway)

## ライセンス

MIT
