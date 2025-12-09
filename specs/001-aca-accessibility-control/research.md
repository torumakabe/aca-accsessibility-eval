# Research: Azure Container Apps + Application Gateway アクセス制御

**Date**: 2025-12-09  
**Feature**: 001-aca-accessibility-control

## Research Questions

1. External環境でpublic network accessを無効化した場合、Application Gatewayからアクセスできるか？
2. 必要なネットワーク構成は何か？
3. プライベートエンドポイントは必要か？

## Key Findings

### Finding 1: Public Network Access の動作

**Decision**: External VIP環境でpublic network accessをDisabledにすると、**プライベートエンドポイント経由のみ**でアクセス可能になる

**Rationale**: 
- Microsoft Docs: "In order to create private endpoints on your Azure Container App environment, public network access must be set to `Disabled`"
- public network accessをDisabledにすると、パブリックFQDNへの直接アクセスは `ERR_CONNECTION_CLOSED` となる
- 同一VNet内からのアクセスでも、プライベートエンドポイントが必要

**Alternatives considered**:
- VNet統合のみ（プライベートエンドポイントなし）→ public network access Disabledでは不十分
- Internal VIP環境 → 最初からパブリックエンドポイントがないため、今回の検証シナリオ（既存External環境からの移行）には適さない

**Source**: https://learn.microsoft.com/en-us/azure/container-apps/networking#public-network-access

### Finding 2: Application Gateway + Container Apps 統合アーキテクチャ

**Decision**: Application GatewayからContainer Appsにアクセスするには、以下の2つのパターンがある

| パターン | 説明 | 適用ケース |
|---------|------|-----------|
| **Internal環境 + Private DNS** | Internal VIPでContainer Apps環境を作成し、Private DNSで名前解決 | 新規構築、セキュリティ重視 |
| **External環境 + Private Endpoint** | External VIPで作成後、public network accessをDisabledにしてPrivate Endpointを作成 | 既存環境からの移行 |

**Rationale**:
- Microsoft公式チュートリアルでは**Internal環境**を推奨している
- ただし、今回の検証シナリオは「既存External環境からの移行」のため、External + Private Endpointパターンを検証

**Source**: https://learn.microsoft.com/en-us/azure/container-apps/waf-app-gateway

### Finding 3: 必要なリソース構成

**Decision**: 以下のリソースが必要

```
┌─────────────────────────────────────────────────────────────────┐
│ Virtual Network (10.0.0.0/16)                                   │
│ ┌─────────────────────┐  ┌─────────────────────┐                │
│ │ AppGW Subnet        │  │ Private Endpoint    │                │
│ │ 10.0.1.0/24         │  │ Subnet 10.0.2.0/24  │                │
│ │ ┌─────────────────┐ │  │ ┌─────────────────┐ │                │
│ │ │Application      │ │  │ │Private Endpoint │ │                │
│ │ │Gateway          │─┼──┼─│→ Container Apps │ │                │
│ │ │(Standard_v2)    │ │  │ └─────────────────┘ │                │
│ └─────────────────────┘  └─────────────────────┘                │
│                                                                  │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ Container Apps Subnet 10.0.16.0/23 (Workload Profiles)      │ │
│ │ ┌─────────────────────────────────────────────────────────┐ │ │
│ │ │ Container Apps Environment (External VIP)               │ │ │
│ │ │ - public network access: Disabled                       │ │ │
│ │ │ ┌─────────────────┐                                     │ │ │
│ │ │ │ Container App   │                                     │ │ │
│ │ │ │ (hello-world)   │                                     │ │ │
│ │ │ └─────────────────┘                                     │ │ │
│ │ └─────────────────────────────────────────────────────────┘ │ │
│ └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ Private DNS Zone                                                │
│ - Zone: <environment-default-domain>                            │
│ - A Record: * → Private Endpoint IP                             │
│ - A Record: @ → Private Endpoint IP                             │
│ - VNet Link → Virtual Network                                   │
└─────────────────────────────────────────────────────────────────┘
```

**Rationale**:
- Workload Profiles環境が必要（プライベートエンドポイントはConsumption-only環境ではサポートされない）
- Container Apps環境用サブネットは最小 /27（Workload Profiles）
- Private DNSゾーンでContainer Apps環境のFQDNを解決
- Application GatewayのバックエンドはContainer AppのFQDNを指定

### Finding 4: Application Gateway バックエンド設定

**Decision**: バックエンドプールにはContainer AppのFQDN（`https://`プレフィックスなし）を設定

**Rationale**:
- FQDNを使用することで、Container Appsの内部IPアドレス変更に影響されない
- HTTPSバックエンドプロトコルを使用し、`Pick host name from backend target`を有効化
- Private DNS Zoneにより、Application GatewayがFQDNをPrivate Endpoint IPに解決

**Configuration**:
```
Backend Pool:
  - Target type: FQDN
  - Target: <app-name>.<environment-default-domain>

Backend Settings:
  - Protocol: HTTPS
  - Port: 443
  - Use well known CA certificate: Yes
  - Override with new host name: Yes
  - Host name override: Pick host name from backend target
```

### Finding 5: プライベートエンドポイントの課金

**Decision**: プライベートエンドポイント使用時は追加料金が発生

**Rationale**:
- Azure Private Linkの課金
- Azure Container Appsの「Dedicated Plan Management」課金（ConsumptionプランでもDedicatedプランでも発生）

**Source**: https://learn.microsoft.com/en-us/azure/container-apps/private-endpoints-with-dns

## Unresolved Questions

すべての技術的な疑問が解決されました。

## Implementation Recommendations

1. **Workload Profiles環境を使用** - プライベートエンドポイントサポートに必須
2. **Private DNS Zoneを正しく構成** - `*` と `@` の両方のAレコードが必要
3. **Application GatewayのX-Forwarded-Host設定** - オリジナルホストヘッダーを保持
4. **ヘルスプローブの確認** - public network access無効化後もヘルスプローブが成功することを確認
