# Infra Rename Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename backend runtime technical resources from `internal/platform` to `internal/infra` after admin route transport and shared boundary work are stable.

**Architecture:** This is a final serial import rename. It should be one backend commit plus one docs commit, with no business behavior changes.

**Tech Stack:** Go imports, `gofmt`, `go test ./...`, route snapshot, governance checker.

---

## Scope Check

In scope:

```text
admin_back_go/internal/platform -> admin_back_go/internal/infra
Go import path updates
active docs vocabulary/path updates
architecture guard that internal/platform no longer exists
```

Out of scope: renaming business platform enum/fields, API routes, payment/storage/AI behavior, deploy env names unless they literally reference Go import paths.

## Task 1: Inventory current platform imports

```powershell
cd E:\admin_go\admin_back_go
Get-ChildItem .\internal\platform -Directory | Select-Object -ExpandProperty Name
rg -n "admin_back_go/internal/platform" internal cmd
```

Record output in the task record. Do not modify code in Task 1.

## Task 2: Move directory and update imports mechanically

```powershell
cd E:\admin_go\admin_back_go
Move-Item -LiteralPath .\internal\platform -Destination .\internal\infra
rg -l "admin_back_go/internal/platform" internal cmd | ForEach-Object {
  (Get-Content -LiteralPath $_ -Raw).Replace('admin_back_go/internal/platform','admin_back_go/internal/infra') | Set-Content -LiteralPath $_ -NoNewline
}
gofmt -w .\internal .\cmd
```

Expected: `internal/platform` no longer exists and Go imports point to `internal/infra`.

## Task 3: Fix code comments and active docs references

```powershell
cd E:\admin_go\admin_back_go
rg -n "internal/platform|platform/" internal cmd docs
```

For Go code and active backend docs, update runtime technical resource wording to `infra`. Do **not** change business `platform` enum, DB field names, `auth_platforms`, API `platform` query/input fields, or user-facing platform labels.

## Task 4: Add architecture guard

Add `TestInfraRenameComplete` requiring:

```text
internal/platform does not exist
internal/infra exists
no Go file imports admin_back_go/internal/platform
```

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture -run TestInfraRenameComplete -count=1
```

Expected: PASS.

## Task 5: Full verification

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture -count=1
go test ./internal/server -run TestAdminRouteSnapshot -count=1
go test ./... -count=1
go build ./...
```

Expected: all PASS.

## Task 6: Active docs and commit

Update active root/backend docs to say technical runtime resources are now in `internal/infra`. Keep business platform wording intact.

```powershell
cd E:\admin_go\admin_back_go
git add internal cmd docs
git commit -m "refactor: rename runtime platform layer to infra"

cd E:\admin_go
git add AGENTS.md docs/architecture docs/status/current-status.md admin_back_go/docs/architecture.md
git commit -m "docs: align infra runtime layer naming"
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected: commits created and governance PASS.

## Plan self-review

- This plan is intentionally not parallelizable.
- It must run after transport/shared work to avoid massive merge conflicts.
- It does not change business platform concepts such as `admin/app` or `auth_platforms`.

## Execution record 2026-05-28

- [x] Task 1 inventory:
  - `internal/platform` directories before move: `accesstoken`, `ai`, `database`, `logging`, `logstore`, `mail`, `payment`, `realtime`, `redisclient`, `redislock`, `scheduler`, `secretbox`, `secretkey`, `sms`, `storage`, `taskqueue`.
  - Legacy imports existed across `cmd/admin-api`, `cmd/admin-worker`, `internal/bootstrap`, `internal/jobs`, `internal/server`, old `internal/platform/*` packages, and module repositories/services.
- [x] Task 2 mechanical move:
  - Moved backend technical resources to `internal/infra`.
  - Updated Go imports from `admin_back_go/internal/platform` to `admin_back_go/internal/infra`.
  - Renamed technical import aliases such as `platformai` / `platformrealtime` to `infraai` / `infrarealtime`.
- [x] Task 3 docs/comments:
  - Updated active backend/root docs to use `internal/infra` for technical resources.
  - Preserved business platform terms: `admin/app/openapi/merchant`, `auth_platforms`, request `platform`, and API route prefixes.
- [x] Task 4 guard:
  - Added `TestInfraRenameComplete`.
  - Verified: `go test ./internal/architecture -run TestInfraRenameComplete -count=1`.
- [x] Task 5 backend verification:
  - Verified: `go test ./internal/architecture -count=1`.
  - Verified: `go test ./internal/server -run TestAdminRouteSnapshot -count=1`.
  - Verified: `go test ./... -count=1`.
  - Verified: `go build ./...`.
- [x] Task 6 commits/governance:
  - Backend commit created: `a27a728` (`refactor: rename runtime platform layer to infra`).
  - Root docs commit created and amended with this execution record: `docs: align infra runtime layer naming`.
  - Fast-forward merged both isolated worktree branches back to the original `master` worktrees.
  - Verified final original worktrees with `git diff --check` and `powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working`.
