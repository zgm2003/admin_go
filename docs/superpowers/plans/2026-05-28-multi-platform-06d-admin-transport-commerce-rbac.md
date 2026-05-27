# Commerce RBAC Admin Transport Shells Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move payment/wallet/RBAC/auth-platform admin HTTP surfaces into `transport/admin` while preserving all admin URLs, permissions, and OperationLog metadata.

**Architecture:** This lane owns `payment`, `wallet`, `permission`, `role`, `authplatform`, plus `internal/server/routes_admin_commerce_rbac.go`. It is higher risk because it touches money and permissions; URL and metadata stability are mandatory.

**Tech Stack:** Go, Gin, route snapshot test, focused payment/RBAC tests.

---

## Scope Check

Modules in scope:

```text
authplatform
permission
role
wallet
payment
```

Out of scope: payment business behavior, Alipay callback semantics, wallet ledger semantics, RBAC model changes, menu/button code changes.

## Task 1: Add RED guard

Add `TestCommerceRBACAdminTransportShells` to `admin_back_go/internal/architecture/multiplatform_boundary_test.go` requiring `transport/admin/route.go` for each in-scope module and forbidding root `route.go` / `handler.go`.

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture -run TestCommerceRBACAdminTransportShells -count=1
```

Expected: FAIL before migration.

## Task 2: Move modules in risk order

Process exactly:

```text
authplatform -> permission -> role -> wallet -> payment
```

For each module:

1. Create `internal/module/<module>/transport/admin`.
2. Move only HTTP files (`route.go`, `handler.go`, `request.go`, route/handler tests as needed) into `transport/admin`.
3. Change package to `admin` and import root as `<module>module "admin_back_go/internal/module/<module>"`.
4. Preserve service/repository/model files at module root.
5. Update `internal/server/routes_admin_commerce_rbac.go` to use `<module>admin.Register(...)`.
6. Keep every route path exactly the same.
7. Run:

```powershell
cd E:\admin_go\admin_back_go
gofmt -w .\internal\module\<module> .\internal\server\routes_admin_commerce_rbac.go
go test ./internal/module/<module> ./internal/module/<module>/transport/admin ./internal/server -count=1
go test ./internal/server -run TestAdminRouteSnapshot -count=1
```

Expected: PASS before moving to the next module.

Special payment rule: public callback routes stay in payment. If callback-specific files block root handler deletion, create `transport/callback` and preserve `POST /api/payment/callbacks/alipay` exactly.

## Task 3: Permission and payment verification

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture -run TestCommerceRBACAdminTransportShells -count=1
go test ./internal/server -run TestAdminRouteSnapshot -count=1
go test ./internal/module/authplatform ./internal/module/permission ./internal/module/role ./internal/module/wallet ./internal/module/payment ./internal/server ./internal/bootstrap -count=1
go test ./... -count=1
rg -n "payment_|wallet_|permission_|role_|authPlatform|auth_platform|OperationLog|RouteMeta" internal\bootstrap internal\server internal\module
```

Expected: tests PASS and route metadata still contains existing permission/meta bindings.

## Task 4: Docs and commit

Update active docs only if path ownership text changes.

```powershell
cd E:\admin_go\admin_back_go
git add internal/module/payment internal/module/wallet internal/module/permission internal/module/role internal/module/authplatform internal/server/routes_admin_commerce_rbac.go internal/architecture/multiplatform_boundary_test.go
git commit -m "refactor: move commerce rbac admin routes to transport shells"

cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected: backend commit created and governance PASS.
