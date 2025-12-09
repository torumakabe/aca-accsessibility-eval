# Implementation Plan: Azure Container Apps + Application Gateway アクセス制御検証

**Branch**: `001-aca-accessibility-control` | **Date**: 2025-12-09 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-aca-accessibility-control/spec.md`

## Summary

Azure Container AppsのExternal VIP環境でpublic network accessを無効化し、Application Gateway経由のみでアクセス可能な構成を検証する。Bicepでインフラストラクチャコードを作成し、アクセス制御の動作を確認する。

**重要な発見**: リサーチの結果、External環境でpublic network accessを無効化すると**プライベートエンドポイント経由のみ**のアクセスとなる。Application Gatewayからの通信には、**プライベートエンドポイント**が必要であることが判明。

## Technical Context

**Language/Version**: Bicep (Azure Resource Manager)  
**Primary Dependencies**: Azure Container Apps, Application Gateway (Standard_v2), Virtual Network, Private Endpoint, Private DNS Zone  
**Storage**: N/A  
**Testing**: Azure CLI (az containerapp, curl)  
**Target Platform**: Azure (Japan East)  
**Project Type**: Infrastructure as Code (IaC) 検証プロジェクト  
**Performance Goals**: N/A (検証プロジェクト)  
**Constraints**: Workload Profiles環境が必要（プライベートエンドポイントサポートのため）  
**Scale/Scope**: 単一環境、単一コンテナアプリ

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Pre-Phase 0 Check ✅
プロジェクト憲法が未定義のため、デフォルトのベストプラクティスに従う：
- Bicepベストプラクティスに準拠
- Azureセキュリティベストプラクティスに準拠
- マネージドIDを使用（キーベース認証を避ける）

### Post-Phase 1 Check ✅
設計完了後の再評価：
- [x] Bicepモジュール構成がベストプラクティスに準拠
- [x] 親リソース参照に`parent`プロパティを使用
- [x] User-defined typesでパラメータを型定義
- [x] セキュリティ上機密情報を含むパラメータに`@secure()`を使用
- [x] Workload Profiles環境を使用（プライベートエンドポイントサポート）
- [x] プライベートDNSゾーンで適切な名前解決を構成

## Project Structure

### Documentation (this feature)

\`\`\`text
specs/001-aca-accessibility-control/
├── plan.md              # This file
├── research.md          # Phase 0 output - リサーチ結果
├── data-model.md        # Phase 1 output - Azureリソースモデル
├── quickstart.md        # Phase 1 output - デプロイ・検証手順
├── contracts/           # Phase 1 output - Bicepモジュール定義
└── tasks.md             # Phase 2 output (/speckit.tasks)
\`\`\`

### Source Code (repository root)

\`\`\`text
infra/
├── main.bicep           # メインデプロイメントファイル
├── main.bicepparam      # パラメータファイル
└── modules/
    ├── vnet.bicep                   # VNet + サブネット
    ├── container-apps-env.bicep     # Container Apps環境
    ├── container-app.bicep          # コンテナアプリ
    ├── private-endpoint.bicep       # プライベートエンドポイント
    ├── private-dns-zone.bicep       # プライベートDNSゾーン
    └── application-gateway.bicep    # Application Gateway

docs/
├── architecture.md      # アーキテクチャ図と説明
└── test-procedures.md   # 検証手順

scripts/
├── deploy.sh            # デプロイスクリプト
├── test-access.sh       # アクセス検証スクリプト
└── cleanup.sh           # リソースクリーンアップ
\`\`\`

**Structure Decision**: IaCプロジェクトとして、Bicepモジュール構成を採用。各Azureリソースを独立したモジュールとして管理し、再利用性と可読性を確保。

## Complexity Tracking

> 違反なし - 標準的なIaC構成
