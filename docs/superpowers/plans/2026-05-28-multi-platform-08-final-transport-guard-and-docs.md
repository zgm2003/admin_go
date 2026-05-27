# Final Transport Guard and Docs Reconciliation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** After transport-shell lanes and user/profile split complete, enforce the no-root-route/handler rule and reconcile active docs with verified runtime truth.

**Architecture:** This is a serial review/guard plan. It does not move features; it proves that previous plans achieved the admin transport boundary.

**Tech Stack:** Go architecture tests, rg, PowerShell, governance checker.

---

## Prerequisites

Plans 05, 06a, 06b, 06c, 06d, and 07 must be merged.

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/server -run TestAdminRouteSnapshot -count=1
```

Expected: PASS.

## Task 1: Add final no-root HTTP guard

Add `TestNoModuleRootHTTPSurface` to architecture tests. It must fail on active module root HTTP files:

```text
internal/module/*/route.go
internal/module/*/handler.go
internal/module/*/app_handler.go
internal/module/*/platform_handler.go
internal/module/*/app_route_test.go
internal/module/*/platform_route.go
```

Allow only explicit non-HTTP exceptions in a small local allowlist with comments and expiration plan.

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture -run TestNoModuleRootHTTPSurface -count=1
```

Expected: PASS only after previous plans moved root HTTP files.

## Task 2: Active docs scan and reconciliation

```powershell
cd E:\admin_go
rg -n "internal/module/.*/route.go|root route.go|platform_.*go|app_.*go|/api/Users|internal/platform/" docs/status docs/contracts docs/testing admin_back_go\docs AGENTS.md docs\architecture
```

Classify every hit:

```text
current truth to update
historical/provenance to leave alone
planned infra rename still pending
```

Update only active truth docs. Do not rewrite historical specs/plans/archive.

## Task 3: Full verification

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture -count=1
go test ./internal/server -run TestAdminRouteSnapshot -count=1
go test ./... -count=1

cd E:\admin_go\admin_front_ts
npm run typecheck
npm run test -- tests/shared/user/users-api.test.ts

cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected: all PASS.

## Task 4: Commit

```powershell
cd E:\admin_go\admin_back_go
git add internal/architecture admin_back_go/docs/architecture.md
git commit -m "test: enforce final admin transport boundary"

cd E:\admin_go
git add AGENTS.md docs/status/current-status.md docs/contracts docs/testing docs/architecture admin_back_go/docs/architecture.md
git commit -m "docs: reconcile transport boundary runtime truth"
```

If a path is unchanged, omit it from `git add` rather than forcing an empty commit.
