# Tasks: Azure Container Apps + Application Gateway アクセス制御検証

**Input**: Design documents from `/specs/001-aca-accessibility-control/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/ ✅, quickstart.md ✅

**Tests**: このプロジェクトはインフラ検証プロジェクトのため、ユニットテストは不要。検証はスクリプトベースで実施。

**Organization**: タスクはユーザーストーリー別に整理され、各ストーリーを独立して実装・検証可能。

## Format: `[ID] [P?] [Story] Description`

- **[P]**: 並列実行可能（異なるファイル、依存関係なし）
- **[Story]**: 所属するユーザーストーリー (US1, US2, US3)
- 説明には正確なファイルパスを含む

---

## Phase 1: Setup (プロジェクト初期化)

**Purpose**: プロジェクト構造とBicep基盤の作成

- [x] T001 Create project directory structure: `infra/`, `infra/modules/`, `scripts/`, `docs/`
- [x] T002 [P] Create main Bicep parameter file in `infra/main.bicepparam`
- [x] T003 [P] Create deployment script in `scripts/deploy.sh`
- [x] T004 [P] Create cleanup script in `scripts/cleanup.sh`

---

## Phase 2: Foundational (ネットワーク・環境基盤)

**Purpose**: すべてのユーザーストーリーに必要な基盤リソースのBicepモジュール作成

**⚠️ CRITICAL**: ユーザーストーリーの実装前にこのフェーズを完了する必要あり

- [x] T005 Create VNet module with 3 subnets (AppGW, PE, CAE) in `infra/modules/vnet.bicep`
- [x] T006 Create Container Apps Environment module (Workload Profiles) in `infra/modules/container-apps-env.bicep`
- [x] T007 [P] Create Container App module in `infra/modules/container-app.bicep`
- [x] T008 [P] Create Private Endpoint module in `infra/modules/private-endpoint.bicep`
- [x] T009 [P] Create Private DNS Zone module with VNet link in `infra/modules/private-dns-zone.bicep`
- [x] T010 Create Application Gateway module (Standard_v2) in `infra/modules/application-gateway.bicep`
- [x] T011 Create main orchestration Bicep in `infra/main.bicep` (integrates all modules)

**Checkpoint**: 基盤完了 - ユーザーストーリーの検証開始可能

---

## Phase 3: User Story 1 - Application Gateway経由のアクセス許可検証 (Priority: P1) 🎯 MVP

**Goal**: External VIP環境でpublic network access無効化時、Application Gateway経由でアクセス可能なことを検証

**Independent Test**: Application Gateway経由でHTTP 200レスポンスが返ることを確認

### Implementation for User Story 1

- [x] T012 [US1] Create access verification script in `scripts/test-access.sh`
- [x] T013 [US1] Document AppGW backend configuration verification steps in `docs/test-procedures.md`
- [ ] T014 [US1] Deploy infrastructure with `publicNetworkAccess=Enabled` and verify AppGW→CA connectivity
- [ ] T015 [US1] Update infrastructure to `publicNetworkAccess=Disabled` and verify AppGW→CA connectivity via Private Endpoint

**Checkpoint**: User Story 1完了 - AppGW経由のアクセスが動作確認済み

---

## Phase 4: User Story 2 - インターネット直接アクセス拒否検証 (Priority: P1)

**Goal**: public network access無効化時、Container Apps FQDNへの直接アクセスが拒否されることを検証

**Independent Test**: Container AppのFQDNに直接curlでアクセスして拒否されることを確認

### Implementation for User Story 2

- [ ] T016 [US2] Add direct access denial test to `scripts/test-access.sh`
- [ ] T017 [US2] Document direct access denial verification steps in `docs/test-procedures.md`
- [ ] T018 [US2] Execute direct FQDN access test (expect HTTP 403 or connection timeout)

**Checkpoint**: User Story 2完了 - 直接アクセス拒否が動作確認済み

---

## Phase 5: User Story 3 - 既存External環境からの移行検証 (Priority: P2)

**Goal**: 既存External VIP環境からpublic network accessを無効化する移行手順を検証

**Independent Test**: public network access設定変更後もApplication Gateway経由のアクセスが維持されることを確認

### Implementation for User Story 3

- [ ] T019 [US3] Document migration procedure (Enabled → Disabled transition) in `docs/test-procedures.md`
- [ ] T020 [US3] Add migration validation test to `scripts/test-access.sh`
- [ ] T021 [US3] Execute migration scenario: deploy with Enabled, add PE/DNS, then switch to Disabled

**Checkpoint**: User Story 3完了 - 移行手順が動作確認済み

---

## Phase 6: Polish & ドキュメント整備

**Purpose**: ドキュメント完成と最終検証

- [x] T022 [P] Create architecture diagram and explanation in `docs/architecture.md`
- [ ] T023 [P] Consolidate all verification results in `docs/test-procedures.md`
- [ ] T024 Run quickstart.md full validation and document results
- [x] T025 Update README.md with project overview and usage instructions

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: 依存なし - 即時開始可能
- **Foundational (Phase 2)**: Setup完了後 - すべてのユーザーストーリーをブロック
- **User Stories (Phase 3-5)**: Foundational完了後 - 優先順位順に実行 (P1 → P1 → P2)
- **Polish (Phase 6)**: すべてのユーザーストーリー完了後

### User Story Dependencies

```
Phase 1 (Setup)
    ↓
Phase 2 (Foundational) ← すべてのBicepモジュール作成
    ↓
Phase 3 (US1: AppGW Access) [P1] ← 最優先、MVP
    ↓
Phase 4 (US2: Direct Denial) [P1] ← US1と同優先度だが、US1の成功前提
    ↓
Phase 5 (US3: Migration) [P2] ← US1, US2成功後
    ↓
Phase 6 (Polish)
```

### Parallel Opportunities

**Phase 1内**:
- T002, T003, T004 は並列実行可能

**Phase 2内**:
- T007, T008, T009 は並列実行可能（T005, T006 完了後）

**Phase 6内**:
- T022, T023 は並列実行可能

---

## Parallel Example: Phase 2

```bash
# Step 1: Network foundation (sequential - VNet required first)
T005: vnet.bicep

# Step 2: Environment (depends on VNet)
T006: container-apps-env.bicep

# Step 3: Parallel resources (can run together after T006)
T007: container-app.bicep       # [P]
T008: private-endpoint.bicep    # [P]
T009: private-dns-zone.bicep    # [P]

# Step 4: Application Gateway (depends on T005 for subnet)
T010: application-gateway.bicep

# Step 5: Main orchestration (depends on all modules)
T011: main.bicep
```

---

## Implementation Strategy

### MVP (Minimum Viable Product)

**User Story 1 のみ完了で検証目的は達成可能**

MVP Scope:
- Phase 1: Setup (T001-T004)
- Phase 2: Foundational (T005-T011)
- Phase 3: User Story 1 (T012-T015)

MVP完了時の成果物:
- すべてのBicepモジュール
- デプロイ/クリーンアップスクリプト
- AppGW経由アクセス検証スクリプト
- 基本的なテスト手順ドキュメント

### Incremental Delivery

| マイルストーン | 含まれるフェーズ | 成果物 |
|--------------|----------------|--------|
| MVP | Phase 1-3 | 基本検証完了 |
| +セキュリティ検証 | + Phase 4 | 直接アクセス拒否確認 |
| +移行手順 | + Phase 5 | 移行シナリオ検証 |
| 完成版 | + Phase 6 | 全ドキュメント整備 |
