# Feature Specification: Azure Container Apps + Application Gateway アクセス制御検証

**Feature Branch**: `001-aca-accessibility-control`  
**Created**: 2025-12-09  
**Status**: Draft  
**Input**: User description: "Azure Container Appsのアクセシビリティレベル制御機能を確認するプロジェクト"

## Clarifications

### Session 2025-12-09

- Q: 検証シナリオの範囲 → A: External環境 + Application Gateway + public network access無効化の構成に絞る
- Q: Application Gatewayバックエンド設定方式 → A: FQDN（コンテナアプリの完全修飾ドメイン名）を使用
- Q: インフラストラクチャコードツール → A: Bicep
- Q: Application Gatewayヘルスプローブのパス → A: `/`（ルートパス）
- Q: デプロイ先リージョン → A: Japan East（東日本）

## 背景・コンテキスト

既存のExternal VIP構成のContainer Apps環境に対して、Azure Application Gatewayをインターネット境界として追加導入する際のアクセス制御を検証する。目的は、Application Gatewayからの通信のみを許可し、インターネットからの直接アクセスを拒否する構成が実現可能かを確認すること。

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Application Gateway経由のアクセス許可検証 (Priority: P1)

インフラ担当者として、External VIPのContainer Apps環境でpublic network accessを無効化した状態で、Application Gatewayからコンテナアプリにアクセスできることを確認したい。これにより、Application Gateway経由のセキュアなインターネット公開構成が実現可能かを判断できる。

**Why this priority**: これがプロジェクトの主目的であり、この検証結果によってアーキテクチャの採用可否が決まる

**Independent Test**: External環境にApplication Gatewayを接続し、public network accessを無効化した状態でApplication Gateway経由のアクセスが成功することを確認

**Acceptance Scenarios**:

1. **Given** External VIPのContainer Apps環境とApplication Gatewayが同一VNetに存在する, **When** public network accessをDisabledに設定しApplication Gateway経由でリクエストする, **Then** コンテナアプリからHTTP 200レスポンスが返される
2. **Given** 上記構成が完了している, **When** Application GatewayのパブリックIPにHTTPリクエストを送信する, **Then** バックエンドのコンテナアプリのレスポンスが返される

---

### User Story 2 - インターネット直接アクセス拒否検証 (Priority: P1)

インフラ担当者として、public network accessを無効化したContainer Apps環境に対して、インターネットから直接アクセスが拒否されることを確認したい。これにより、Application Gatewayを迂回した不正アクセスが防止できることを確認する。

**Why this priority**: セキュリティ要件として、Application Gatewayを経由しない直接アクセスの遮断は必須

**Independent Test**: public network access無効化後、コンテナアプリのパブリックFQDNに直接アクセスして拒否されることを確認

**Acceptance Scenarios**:

1. **Given** public network accessがDisabledのExternal VIP環境がある, **When** コンテナアプリのFQDNに直接curlでアクセスする, **Then** 接続が拒否される（HTTP 403またはタイムアウト）
2. **Given** 上記構成でApplication Gateway経由のアクセスは成功している, **When** 同時にFQDN直接アクセスを試みる, **Then** 直接アクセスのみが拒否される

---

### User Story 3 - 既存External環境からの移行検証 (Priority: P2)

インフラ担当者として、既存のExternal VIP環境（public network access有効）からpublic network accessを無効化する移行手順を確認したい。これにより、本番環境への適用手順を事前に検証できる。

**Why this priority**: 既存環境からの移行パスの確認は重要だが、まず新規構成での動作確認が優先

**Independent Test**: External環境を作成後、public network accessの設定変更を行い、Application Gateway経由のアクセスが維持されることを確認

**Acceptance Scenarios**:

1. **Given** public network accessがEnabledのExternal環境で稼働中のアプリがある, **When** public network accessをDisabledに変更する, **Then** 設定変更が正常に完了する
2. **Given** 設定変更後の環境, **When** Application Gateway経由でアクセスする, **Then** サービス中断なくアクセスが継続できる

### Edge Cases

- public network access無効化後、Application Gatewayのヘルスプローブが失敗する可能性
- Container Apps環境とApplication Gatewayが異なるVNetにある場合のVNetピアリング要件
- Application Gatewayのバックエンドプール設定（FQDN vs プライベートIP）による挙動の違い
- public network access無効化時にプライベートエンドポイントが必要かどうか

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: プロジェクトは、External VIPのContainer Apps環境をデプロイするインフラストラクチャコードを提供しなければならない
- **FR-002**: プロジェクトは、Container Apps環境と同一VNetにApplication Gatewayをデプロイするインフラストラクチャコードを提供しなければならない
- **FR-003**: プロジェクトは、検証用のサンプルコンテナアプリ（HTTPレスポンスを返すシンプルなアプリ）を含まなければならない
- **FR-004**: public network accessを無効化した状態で、Application Gateway経由のアクセスが成功しなければならない
- **FR-005**: public network accessを無効化した状態で、コンテナアプリFQDNへの直接アクセスが拒否されなければならない
- **FR-006**: プロジェクトは、各構成のアクセス可否を検証するためのテスト手順を含まなければならない

### Key Entities

- **Container Apps Environment**: コンテナアプリをホストする論理的な境界。External VIPで作成し、public network access設定で外部アクセスを制御
- **Container App**: 環境内で稼働するアプリケーション。ingress設定（external）とターゲットポートを持つ
- **Application Gateway**: インターネット境界として機能するL7ロードバランサー。WAF機能を提供し、バックエンドとしてContainer Appsを設定
- **Virtual Network**: Container Apps環境とApplication Gatewayを接続するネットワーク。それぞれ専用サブネットが必要

## Assumptions

- Azure サブスクリプションとリソース作成権限が利用可能である
- Container Apps環境はExternal VIP（外部向け）で作成済みまたは新規作成する
- Application GatewayはContainer Apps環境と同一VNet内に配置する
- Application GatewayのバックエンドプールにはコンテナアプリのFQDNを設定する
- Application Gatewayのヘルスプローブは `/` パスを使用する
- 検証にはシンプルなHTTPレスポンスを返すコンテナイメージ（例：nginx、mcr.microsoft.com/azuredocs/containerapps-helloworld）を使用する
- インフラストラクチャコードはBicepで記述する
- デプロイ先リージョンはJapan East（東日本）を使用する
- 検証はAzure CLIまたはcurlコマンドで実行する

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Application Gateway経由でコンテナアプリにアクセスし、5秒以内にHTTP 200レスポンスが返される
- **SC-002**: public network access無効化後、コンテナアプリFQDNへの直接アクセスがHTTP 403または接続拒否で失敗する
- **SC-003**: public network access無効化後も、Application Gateway経由のアクセスは継続して成功する
- **SC-004**: すべての検証シナリオについて、再現可能なテスト手順が文書化されている
