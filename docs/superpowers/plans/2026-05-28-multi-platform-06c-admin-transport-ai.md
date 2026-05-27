# AI Admin Transport Shells Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move current AI admin HTTP surfaces into `transport/admin` without changing AI admin URLs, queue jobs, provider runtime, or frontend contracts.

**Architecture:** This lane owns only AI modules and `internal/server/routes_admin_ai.go`. It does not aggregate AI modules into `module/ai` yet; it only removes root `route.go`/`handler.go` from current AI modules.

**Tech Stack:** Go, Gin, PowerShell, route snapshot test.

---

## Scope Check

Modules in scope:

```text
aiprovider
aiagent
aitool
aiknowledge
aiconversation
aimessage
airun
aichat
aiimage
```

Out of scope: module/ai aggregation, provider/model behavior changes, OpenAI request format changes, queue/job semantic changes, frontend AI redesign.

## Task 1: Add RED guard

Add `TestAIAdminTransportShells` to `admin_back_go/internal/architecture/multiplatform_boundary_test.go` requiring `transport/admin/route.go` for each AI module and forbidding root `route.go` / `handler.go`.

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture -run TestAIAdminTransportShells -count=1
```

Expected: FAIL before migration.

## Task 2: Move AI modules one by one

Process exactly:

```text
aiprovider -> aiagent -> aitool -> aiknowledge -> aiconversation -> aimessage -> airun -> aichat -> aiimage
```

For each module:

1. Create `internal/module/<module>/transport/admin`.
2. Move `route.go`, `handler.go`, `request.go`, and route/handler tests as needed into `transport/admin`.
3. Change package to `admin`.
4. Import root module as `<module>module "admin_back_go/internal/module/<module>"`.
5. Keep service/repository/model/jobs at root.
6. Update `internal/server/routes_admin_ai.go` to import `<module>admin "admin_back_go/internal/module/<module>/transport/admin"` and call `<module>admin.Register(...)`.
7. Preserve every `/api/admin/v1/ai-*` URL.
8. Run:

```powershell
cd E:\admin_go\admin_back_go
gofmt -w .\internal\module\<module> .\internal\server\routes_admin_ai.go
go test ./internal/module/<module> ./internal/module/<module>/transport/admin ./internal/server -count=1
go test ./internal/server -run TestAdminRouteSnapshot -count=1
```

Expected: PASS before moving to the next module.

## Task 3: AI verification

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture -run TestAIAdminTransportShells -count=1
go test ./internal/server -run TestAdminRouteSnapshot -count=1
go test ./internal/module/aiprovider ./internal/module/aiagent ./internal/module/aitool ./internal/module/aiknowledge ./internal/module/aiconversation ./internal/module/aimessage ./internal/module/airun ./internal/module/aichat ./internal/module/aiimage ./internal/server -count=1
go test ./... -count=1
```

Expected: all PASS.

If frontend AI API tests exist for touched modules, list and run matching files:

```powershell
cd E:\admin_go\admin_front_ts
Get-ChildItem .\tests\shared\ai -Filter "*.test.ts" | Select-Object -ExpandProperty FullName
```

## Task 4: Docs and commit

Update active docs only for path ownership truth.

```powershell
cd E:\admin_go\admin_back_go
git add internal/module/aiagent internal/module/aiprovider internal/module/aitool internal/module/aiknowledge internal/module/aiconversation internal/module/aimessage internal/module/airun internal/module/aichat internal/module/aiimage internal/server/routes_admin_ai.go internal/architecture/multiplatform_boundary_test.go
git commit -m "refactor: move ai admin routes to transport shells"

cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected: backend commit created and governance PASS.
