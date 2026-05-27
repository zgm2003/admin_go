# Foundation Admin Transport Shells Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move foundation/admin-runtime modules into `internal/module/{capability}/transport/admin` while preserving every admin URL and route behavior.

**Architecture:** This lane owns only foundation modules and `internal/server/routes_admin_foundation.go`. It can run in parallel with 06b/06c/06d after plan-05.

**Tech Stack:** Go, Gin, PowerShell, route snapshot test.

---

## Scope Check

Modules in scope:

```text
system
systemsetting
systemlog
operationlog
crontask
queuemonitor
clientversion
exporttask
realtime
```

Preserve URLs. Do not rename `exporttask` to `export` in this plan.

## Task 1: Add RED guard for foundation modules

- [ ] **Step 1: Extend `internal/architecture/multiplatform_boundary_test.go`**

Add `TestFoundationAdminTransportShells` that requires these files:

```text
internal/module/system/transport/admin/route.go
internal/module/systemsetting/transport/admin/route.go
internal/module/systemlog/transport/admin/route.go
internal/module/operationlog/transport/admin/route.go
internal/module/crontask/transport/admin/route.go
internal/module/queuemonitor/transport/admin/route.go
internal/module/clientversion/transport/admin/route.go
internal/module/exporttask/transport/admin/route.go
internal/module/realtime/transport/admin/route.go
```

and forbids each matching root `route.go` / `handler.go`.

- [ ] **Step 2: Run RED**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture -run TestFoundationAdminTransportShells -count=1
```

Expected: FAIL because transport/admin files do not exist yet.

## Task 2: Move modules one by one

Process exactly:

```text
system -> systemsetting -> systemlog -> operationlog -> crontask -> queuemonitor -> clientversion -> exporttask -> realtime
```

For each module:

1. Create `internal/module/<module>/transport/admin`.
2. Move root HTTP files into that package:
   - `route.go`
   - `handler.go`
   - `request.go` when present
   - handler/route tests when they use package-local HTTP types
3. Change package name to `admin`.
4. Import root module as `<module>module "admin_back_go/internal/module/<module>"` for service DTOs/interfaces.
5. Keep service/repository/model/dto files at module root unless a type is strictly HTTP-only.
6. Update `internal/server/routes_admin_foundation.go` to import `<module>admin "admin_back_go/internal/module/<module>/transport/admin"` and call `<module>admin.Register(...)`.
7. For `queuemonitor`, preserve the UI handler parameter: `queuemonitoradmin.Register(router, deps.QueueMonitorService, deps.QueueMonitorUI)`.
8. Run after each module:

```powershell
cd E:\admin_go\admin_back_go
gofmt -w .\internal\module\<module> .\internal\server\routes_admin_foundation.go
go test ./internal/module/<module> ./internal/module/<module>/transport/admin ./internal/server -count=1
go test ./internal/server -run TestAdminRouteSnapshot -count=1
```

Expected: PASS before moving to the next module.

## Task 3: Lane final verification

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture -run TestFoundationAdminTransportShells -count=1
go test ./internal/server -run TestAdminRouteSnapshot -count=1
go test ./internal/server ./internal/architecture -count=1
go test ./... -count=1
```

Expected: all PASS.

## Task 4: Docs and commit

Update active docs only if they list root route ownership for modules in this lane.

```powershell
cd E:\admin_go\admin_back_go
git add internal/module/system internal/module/systemsetting internal/module/systemlog internal/module/operationlog internal/module/crontask internal/module/queuemonitor internal/module/clientversion internal/module/exporttask internal/module/realtime internal/server/routes_admin_foundation.go internal/architecture/multiplatform_boundary_test.go
git commit -m "refactor: move foundation admin routes to transport shells"

cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected: backend commit created and governance PASS.
