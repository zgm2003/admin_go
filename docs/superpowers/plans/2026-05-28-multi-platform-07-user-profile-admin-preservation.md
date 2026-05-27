# User Profile Admin Preservation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split the overloaded `user`/`userquickentry` HTTP surface into explicit user/profile transports while preserving existing admin behavior.

**Architecture:** This is serial because user/profile is the highest admin UX risk. Admin user-management URLs and current-user profile URLs must remain unchanged. App routes only need to compile unless admin behavior depends on them.

**Tech Stack:** Go, Gin, admin_front_ts user API tests, route snapshot test.

---

## Scope Check

In scope:

```text
internal/module/user
internal/module/userquickentry
new internal/module/profile
internal/server/routes_admin_user.go
admin_front_ts user API contract tests if admin path expectations need updates
```

Out of scope: changing admin user URLs, DB schema, RBAC permission codes, or app UX.

## Task 1: Add RED guard for user/profile shape

Add `TestUserProfileTransportShape` requiring:

```text
internal/module/user/transport/admin/route.go
internal/module/profile/transport/admin/route.go
```

If app compile requires explicit app transport, also require:

```text
internal/module/profile/transport/app/route.go
```

Forbid after completion:

```text
internal/module/user/route.go
internal/module/user/handler.go
internal/module/user/app_handler.go
internal/module/user/app_dto.go
internal/module/userquickentry/route.go
internal/module/userquickentry/handler.go
```

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture -run TestUserProfileTransportShape -count=1
```

Expected: FAIL before migration.

## Task 2: Preserve admin user-management under `user/transport/admin`

Move admin user-management routes into `internal/module/user/transport/admin` and preserve:

```text
GET    /api/admin/v1/users/init
GET    /api/admin/v1/users/me
GET    /api/admin/v1/users/page-init
GET    /api/admin/v1/users/:id/profile
GET    /api/admin/v1/users
POST   /api/admin/v1/users/export
PUT    /api/admin/v1/users/:id
PATCH  /api/admin/v1/users/:id/status
PATCH  /api/admin/v1/users
DELETE /api/admin/v1/users/:id
DELETE /api/admin/v1/users
```

Run:

```powershell
cd E:\admin_go\admin_back_go
gofmt -w .\internal\module\user .\internal\server\routes_admin_user.go
go test ./internal/module/user ./internal/module/user/transport/admin ./internal/server -run "TestRouterInstallsUsers|TestRouterInstallsUserManagement|TestRouterInstallsUsersInit" -count=1
go test ./internal/server -run TestAdminRouteSnapshot -count=1
```

Expected: PASS.

## Task 3: Move admin current-user profile + quick-entry into `profile/transport/admin`

Create `internal/module/profile` and preserve these URLs:

```text
GET /api/admin/v1/profile
PUT /api/admin/v1/profile
PUT /api/admin/v1/profile/security/password
PUT /api/admin/v1/profile/security/email
PUT /api/admin/v1/profile/security/phone
PUT /api/admin/v1/users/me/quick-entries
```

Implementation rules:

- If extracting repositories is too large, keep minimal duplicated repository reads/writes against the same tables rather than importing `user.Repository` directly.
- Preserve route metadata and current-user authorization behavior.

Run:

```powershell
cd E:\admin_go\admin_back_go
gofmt -w .\internal\module\profile .\internal\module\user .\internal\server\routes_admin_user.go
go test ./internal/module/profile ./internal/module/user ./internal/server -run "TestRouterInstallsUsersMe|TestRouterInstallsUserLegacyClosure|TestRouterInstallsAppProfile" -count=1
go test ./internal/server -run TestAdminRouteSnapshot -count=1
```

Expected: PASS.

## Task 4: App compile cleanup

Move remaining app profile/user HTTP files to `profile/transport/app` or keep a compile-only app registration that calls profile service. App behavior is secondary, but backend must compile.

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/profile ./internal/module/user ./internal/server -count=1
go test ./... -count=1
```

Expected: PASS.

## Task 5: Frontend admin preservation

```powershell
cd E:\admin_go\admin_front_ts
npm run typecheck
npm run test -- tests/shared/user/users-api.test.ts
```

Expected: PASS.

## Task 6: Docs and commit

Update active docs to say:

```text
user = admin user-management capability
profile = current-user self-service capability
admin URLs preserved
app compile is best-effort in this slice
```

Commit:

```powershell
cd E:\admin_go\admin_back_go
git add internal/module/user internal/module/userquickentry internal/module/profile internal/server/routes_admin_user.go internal/architecture/multiplatform_boundary_test.go
git commit -m "refactor: split user profile transports while preserving admin routes"

cd E:\admin_go
git add docs/status/current-status.md docs/contracts/admin-api-v1.md admin_back_go/docs/architecture.md
git commit -m "docs: record user profile ownership split"
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected: commits created and governance PASS.
