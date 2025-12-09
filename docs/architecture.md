# アーキテクチャ

Azure Container Apps + Application Gateway アクセス制御検証のアーキテクチャを説明します。

## 構成の違い

> **重要**: Azure Container Apps では Private Endpoint を作成するには `publicNetworkAccess = Disabled` が必須です。

| publicNetworkAccess | Private Endpoint | Private DNS Zone | AppGW→CA 通信経路 |
|--------------------|------------------|------------------|-------------------|
| Enabled | なし | なし | パブリック FQDN 経由 |
| Disabled | あり | あり | Private Endpoint 経由 |

以下の図は `publicNetworkAccess = Disabled` の最終状態を示しています。

## システム構成図

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              Internet                                        │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ HTTP/80
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Application Gateway                                  │
│                         (Standard_v2)                                        │
│                         Public IP: pip-agw-acaeval                          │
│                                                                              │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────────────────────┐ │
│  │  Listener   │───▶│  Routing    │───▶│  Backend Pool                   │ │
│  │  HTTP:80    │    │  Rule       │    │  Target: ca-acaeval.<domain>    │ │
│  └─────────────┘    └─────────────┘    │  Protocol: HTTPS:443            │ │
│                                         │  Pick hostname: true            │ │
│                                         └─────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ HTTPS/443 (via Private DNS)
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Virtual Network (10.0.0.0/16)                        │
│                         vnet-acaeval                                         │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ Application Gateway Subnet (10.0.1.0/24)                                ││
│  │ snet-appgw                                                              ││
│  │ ┌───────────────────────────────────────────────────────────────────┐  ││
│  │ │ Application Gateway (agw-acaeval)                                 │  ││
│  │ └───────────────────────────────────────────────────────────────────┘  ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                    │                                         │
│                                    │ DNS Query: ca-acaeval.<domain>         │
│                                    ▼                                         │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ Private DNS Zone                                                        ││
│  │ Zone: <environment-default-domain>                                      ││
│  │ Records:                                                                ││
│  │   * → Private Endpoint IP                                               ││
│  │   @ → Private Endpoint IP                                               ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                    │                                         │
│                                    │ Resolved to Private Endpoint IP        │
│                                    ▼                                         │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ Private Endpoint Subnet (10.0.2.0/24)                                   ││
│  │ snet-pe                                                                 ││
│  │ ┌───────────────────────────────────────────────────────────────────┐  ││
│  │ │ Private Endpoint (pe-acaeval)                                     │  ││
│  │ │ Target: Container Apps Environment                                │  ││
│  │ │ Group ID: managedEnvironments                                     │  ││
│  │ └───────────────────────────────────────────────────────────────────┘  ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                    │                                         │
│                                    │ Private Link Connection                │
│                                    ▼                                         │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ Container Apps Environment Subnet (10.0.16.0/23)                        ││
│  │ snet-cae                                                                ││
│  │ Delegation: Microsoft.App/environments                                  ││
│  │                                                                         ││
│  │ ┌───────────────────────────────────────────────────────────────────┐  ││
│  │ │ Container Apps Environment (cae-acaeval)                          │  ││
│  │ │ Type: Workload Profiles                                           │  ││
│  │ │ VIP: External                                                     │  ││
│  │ │ Public Network Access: Disabled                                   │  ││
│  │ │                                                                   │  ││
│  │ │ ┌───────────────────────────────────────────────────────────────┐│  ││
│  │ │ │ Container App (ca-acaeval)                                    ││  ││
│  │ │ │ Image: mcr.microsoft.com/k8se/quickstart:latest               ││  ││
│  │ │ │ Ingress: external, port 80                                    ││  ││
│  │ │ │ FQDN: ca-acaeval.<environment-default-domain>                 ││  ││
│  │ │ └───────────────────────────────────────────────────────────────┘│  ││
│  │ └───────────────────────────────────────────────────────────────────┘  ││
│  └─────────────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────────────┘
```

## コンポーネント説明

### 1. Application Gateway (Standard_v2)

インターネット境界として機能するL7ロードバランサー。

| 設定項目 | 値 |
|---------|-----|
| SKU | Standard_v2 |
| Autoscale | 1-2インスタンス |
| Frontend | Public IP (Static) |
| Listener | HTTP:80 |
| Backend Protocol | HTTPS:443 |
| Backend Target | Container App FQDN |
| Host Header | Pick from backend |

### 2. Virtual Network

3つのサブネットで構成されるネットワーク基盤。

| サブネット | アドレス範囲 | 用途 |
|-----------|-------------|------|
| snet-appgw | 10.0.1.0/24 | Application Gateway |
| snet-pe | 10.0.2.0/24 | Private Endpoint |
| snet-cae | 10.0.16.0/23 | Container Apps Environment |

### 3. Container Apps Environment

コンテナアプリをホストするマネージド環境。

| 設定項目 | 値 |
|---------|-----|
| Type | Workload Profiles |
| VIP Type | External |
| Public Network Access | Disabled |
| Zone Redundancy | 無効 |

### 4. Private Endpoint

Container Apps環境へのプライベート接続ポイント。

| 設定項目 | 値 |
|---------|-----|
| Group ID | managedEnvironments |
| Subnet | snet-pe |
| Target | Container Apps Environment |

### 5. Private DNS Zone

Container Apps FQDNをPrivate Endpoint IPに解決。

| レコード | タイプ | 値 |
|---------|--------|-----|
| * | A | Private Endpoint IP |
| @ | A | Private Endpoint IP |

## 通信フロー

### Application Gateway経由のアクセス（成功）

1. クライアントがApplication Gateway Public IPにHTTPリクエスト
2. Application GatewayがBackend Pool設定からContainer App FQDNを参照
3. Private DNS ZoneによりFQDNがPrivate Endpoint IPに解決
4. Application GatewayがPrivate Endpoint経由でContainer Appに接続
5. Container AppがHTTPSレスポンスを返却
6. Application Gatewayがクライアントにレスポンス転送

### インターネット直接アクセス（拒否）

1. クライアントがContainer App FQDNに直接HTTPSリクエスト
2. パブリックDNSによりFQDNがContainer Apps環境のパブリックIPに解決
3. public network access = Disabled により接続拒否

## 重要な動作特性

### Application Gateway の DNS キャッシュ

Application Gateway はバックエンドターゲット FQDN の DNS 解決結果をキャッシュします。`publicNetworkAccess=Disabled` に変更し Private DNS Zone を作成・VNet リンクしても、**即座に Private Endpoint IP への切り替えは行われません**。

| 状態 | DNS 解決先 | ヘルスプローブ結果 |
|------|-----------|-------------------|
| デプロイ直後 | 旧パブリック IP（キャッシュ） | Unhealthy (403) |
| TTL 経過後 | Private Endpoint IP | Healthy (200) |

**観測された動作**:
- Private DNS Zone 作成・リンク後、ヘルスプローブが成功するまで約10分程度を要した
- Application Gateway の再起動は不要
- DNS TTL が切れると自動的に Private Endpoint IP に解決される

> **注意**: 本番環境での移行時は、この DNS キャッシュ更新待ち時間を考慮した計画が必要です。

## セキュリティ考慮事項

### 実装済み

- ✅ public network accessによるインターネット直接アクセス拒否
- ✅ Private Endpointによるプライベート通信
- ✅ Application Gateway経由の集約アクセス

### 本番環境で追加推奨

- WAF (Web Application Firewall) の有効化
- NSG (Network Security Group) によるサブネット間通信制御
- Application Gatewayリスナーへの HTTPS/TLS設定
- Container Appsへの認証設定 (Easy Auth等)
- 診断ログの有効化とLog Analytics統合

## リソース命名規則

| リソースタイプ | 命名パターン | 例 |
|--------------|-------------|-----|
| Resource Group | rg-{purpose} | rg-aca-accessibility-eval |
| Virtual Network | vnet-{prefix} | vnet-acaeval |
| Subnet | snet-{purpose} | snet-appgw |
| Container Apps Env | cae-{prefix} | cae-acaeval |
| Container App | ca-{prefix} | ca-acaeval |
| Private Endpoint | pe-{prefix} | pe-acaeval |
| Application Gateway | agw-{prefix} | agw-acaeval |
| Public IP | {resource}-pip | agw-acaeval-pip |
