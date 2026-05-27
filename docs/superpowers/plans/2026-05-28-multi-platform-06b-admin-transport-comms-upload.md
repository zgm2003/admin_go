# Comms Upload Admin Transport Shells Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move communication, notification, and upload modules into `transport/admin` while preserving admin URLs and upload behavior.

**Architecture:** This lane owns `mail`, `sms`, `notification`, `notificationtask`, `uploadconfig`, `uploadtoken`, plus `internal/server/routes_admin_comms.go`. It can run in parallel with 06a/06c/06d after plan-05.

**Tech Stack:** Go, Gin, PowerShell, route snapshot test.

---

## Scope Check

Modules in scope:

```text
mail
sms
notification
notificationtask
uploadconfig
uploadtoken
```

Preserve current admin URLs and public response shapes. App upload-token route may compile but app behavior is not allowed to block admin preservation.

## Task 1: Add RED guard

Add `TestCommsUploadAdminTransportShells` to `admin_back_go/internal/architecture/multiplatform_boundary_test.go` requiring `transport/admin/route.go` for each in-scope module and forbidding each root `route.go` / `handler.go`.

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture -run TestCommsUploadAdminTransportShells -count=1
```

Expected: FAIL before migration.

## Task 2: Move modules one by one

Process exactly:

```text
mail -> sms -> notification -> notificationtask -> uploadconfig -> uploadtoken
```

For each module:

1. Create `internal/module/<module>/transport/admin`.
2. Move root HTTP files (`route.go`, `handler.go`, `request.go`, route/handler tests as needed) into `transport/admin`.
3. Change package to `admin`.
4. Import root module as `<module>module "admin_back_go/internal/module/<module>"`.
5. Update `internal/server/routes_admin_comms.go` to import `<module>admin "admin_back_go/internal/module/<module>/transport/admin"` and call `<module>admin.Register(...)`.
6. Keep public admin URLs identical.
7. Run:

```powershell
cd E:\admin_go\admin_back_go
gofmt -w .\internal\module\<module> .\internal\server\routes_admin_comms.go
go test ./internal/module/<module> ./internal/module/<module>/transport/admin ./internal/server -count=1
go test ./internal/server -run TestAdminRouteSnapshot -count=1
```

Expected: PASS before moving to the next module.

Special rule for `uploadtoken`: it has app HTTP surface. Move admin surface first; if app files block compilation, place app HTTP files under `transport/app` in the same module without changing `POST /api/app/v1/upload-tokens`.

## Task 3: Lane final verification

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture -run TestCommsUploadAdminTransportShells -count=1
go test ./internal/server -run TestAdminRouteSnapshot -count=1
go test ./internal/module/mail ./internal/module/sms ./internal/module/notification ./internal/module/notificationtask ./internal/module/uploadconfig ./internal/module/uploadtoken ./internal/server -count=1
go test ./... -count=1
```

Expected: all PASS.

## Task 4: Docs and commit

Update active docs only for verified ownership/path truth.

```powershell
cd E:\admin_go\admin_back_go
git add internal/module/mail internal/module/sms internal/module/notification internal/module/notificationtask internal/module/uploadconfig internal/module/uploadtoken internal/server/routes_admin_comms.go internal/architecture/multiplatform_boundary_test.go
git commit -m "refactor: move comms upload admin routes to transport shells"

cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected: backend commit created and governance PASS.
