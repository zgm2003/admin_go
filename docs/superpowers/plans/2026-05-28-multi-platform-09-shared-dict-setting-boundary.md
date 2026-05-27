# Shared Dict Setting Boundary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Introduce `internal/shared/dict` and `internal/shared/setting` boundaries without breaking admin page-init, login verification, upload token, mail, or SMS behavior.

**Architecture:** This plan is sequential because dict/setting imports span many modules. Start with compatibility boundaries, migrate selected high-value call sites, then add guards for migrated keys only.

**Tech Stack:** Go, Redis setting cache tests, admin page-init tests.

---

## Scope Check

In scope:

```text
internal/shared/dict compatibility boundary
internal/shared/setting typed boundary for selected keys
selected migration: systemsetting page-init, auth verify/captcha TTL, uploadtoken TTL, mail/sms TTL write path
active docs update
```

Out of scope: transport shell moves, `internal/platform -> internal/infra`, DB schema changes, frontend UI redesign, pagination unification.

## Task 1: Inventory direct dict/setting usage

```powershell
cd E:\admin_go\admin_back_go
rg -n "internal/dict|dict\.|system_settings|SystemSetting|settingRepo|SettingByKey|auth\.verify_code|auth\.captcha|upload\.token" internal cmd
```

Record output in the task record. Do not modify code in this task.

## Task 2: Create `internal/shared/dict` compatibility package

Create `internal/shared/dict` with a service/registry façade while preserving current option payloads. Keep existing `internal/dict` functions working during the transition.

First provider names:

```text
common_status
common_yes_no
platform
system_setting_value_type
```

Verification:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/dict ./internal/shared/dict -count=1
go test ./internal/module/systemsetting -count=1
```

Expected: PASS.

## Task 3: Create `internal/shared/setting` typed boundary

Create typed functions for:

```text
AuthCaptchaTTLMinutes
AuthVerifyCodeTTLMinutes
UploadTokenTTLMinutes
```

Each function must preserve current default value and range behavior. It may wrap the existing `systemsetting.Repository` at first; do not delete admin CRUD.

Verification:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/shared/setting ./internal/module/auth ./internal/module/uploadtoken ./internal/module/systemsetting -count=1
```

Expected: PASS.

## Task 4: Migrate selected call sites only

Migrate:

```text
auth captcha TTL read
auth verify-code TTL read
uploadtoken TTL read
mail/sms verify-code TTL write/invalidate path
systemsetting page-init value type dict read
```

Do not migrate every module in one pass.

Verification:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/auth ./internal/module/mail ./internal/module/sms ./internal/module/uploadtoken ./internal/module/systemsetting ./internal/shared/dict ./internal/shared/setting -count=1
go test ./... -count=1
```

Expected: PASS.

## Task 5: Guards, docs, commit

Add architecture guard only for migrated keys so old unmigrated code does not block unrelated work.

Update active docs:

```text
shared/dict exists and migration is incremental
shared/setting owns migrated typed keys
systemsetting remains admin CRUD, not cross-module read boundary for migrated keys
```

Commit:

```powershell
cd E:\admin_go\admin_back_go
git add internal/shared internal/module/auth internal/module/mail internal/module/sms internal/module/uploadtoken internal/module/systemsetting internal/architecture
git commit -m "refactor: add shared dict setting boundaries"

cd E:\admin_go
git add docs/status/current-status.md docs/architecture admin_back_go/docs/architecture.md
git commit -m "docs: record shared dict setting boundary"
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected: commits created and governance PASS.
