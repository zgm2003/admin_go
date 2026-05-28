# Auth Platform Rename Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` in the assigned backend worktree. Steps use checkbox (`- [ ]`) syntax for tracking. This plan may run in parallel with 12a/12b/12c only in an isolated worktree.

**Goal:** Rename backend capability directory `internal/module/authplatform` to `internal/module/auth_platform` without changing auth policy behavior, admin URLs, DB table, permission codes, validation tags, or i18n message keys.

**Architecture:** Capability names use lowercase snake_case. `auth_platform` owns auth platform policy management for `auth_platforms`; it is not a general multi-platform config center. This is a package path rename and package-name cleanup only.

**Tech Stack:** Go, Gin transport, auth policy service, backend architecture tests, route snapshot.

---

## Assigned worktree

```text
E:\admin_go_parallel\p12d-auth-platform
branch: work/p12d-auth-platform
```

## Files

- Move: `internal/module/authplatform` -> `internal/module/auth_platform`
- Modify imports in `internal/bootstrap`, `internal/server`, and tests.
- Modify docs inside backend repo if needed: `docs/architecture.md`, `internal/module/README.md`, `internal/middleware/README.md`
- Modify `internal/architecture/multiplatform_boundary_test.go`
- Do not modify root docs/status.

## Non-negotiable behavior

```text
/api/admin/v1/auth-platforms URLs unchanged.
auth_platforms DB table unchanged.
permission_authPlatform_* permission codes unchanged.
auth_platform_login_type validator tag unchanged.
message IDs stay authplatform.*.
auth login/session policy behavior unchanged.
No frontend change.
No DB migration.
```

## Task 1: Add architecture guard for snake_case module

- [ ] Add/extend an architecture test so `internal/module/authplatform` is rejected and `internal/module/auth_platform` is required.

Expected assertion intent:

```go
if _, err := os.Stat(filepath.Join(root, "internal", "module", "authplatform")); !os.IsNotExist(err) {
    t.Fatalf("authplatform must be renamed to internal/module/auth_platform")
}
if _, err := os.Stat(filepath.Join(root, "internal", "module", "auth_platform")); err != nil {
    t.Fatalf("internal/module/auth_platform must exist: %v", err)
}
```

- [ ] Run:

```powershell
go test ./internal/architecture -run AuthPlatform -count=1
```

Expected before implementation: FAIL.

## Task 2: Move directory and rename package

- [ ] Move directory:

```powershell
git mv .\internal\module\authplatform .\internal\module\auth_platform
```

- [ ] Change package names under `internal/module/auth_platform` from `package authplatform` to `package authplatform` only if keeping package name avoids churn? No: final package name should be `authplatform` or `auth_platform`?

Use Go compile truth:

```text
Directory: internal/module/auth_platform
Preferred package name: authplatform (Go package names should not contain underscore unless needed)
Import alias: authplatform "admin_back_go/internal/module/auth_platform"
```

This gives snake_case directory while keeping idiomatic package identifier.

## Task 3: Update imports and route registration

- [ ] Replace import path:

```powershell
rg -l 'admin_back_go/internal/module/authplatform' internal cmd | ForEach-Object {
  (Get-Content -LiteralPath $_ -Raw).Replace('admin_back_go/internal/module/authplatform','admin_back_go/internal/module/auth_platform') | Set-Content -LiteralPath $_ -NoNewline
}
```

- [ ] Keep import aliases readable:

```go
authplatform "admin_back_go/internal/module/auth_platform"
authplatformadmin "admin_back_go/internal/module/auth_platform/transport/admin"
```

- [ ] Preserve route prefix in `transport/admin/route.go`:

```go
v1 := router.Group("/api/admin/v1/auth-platforms")
```

- [ ] Do not change `authplatform.*` i18n keys.

## Task 4: Verification

- [ ] Format:

```powershell
gofmt -w .\internal\module\auth_platform .\internal\bootstrap .\internal\server .\internal\architecture
```

- [ ] Confirm old path is gone:

```powershell
if (Test-Path .\internal\module\authplatform) { throw 'internal/module/authplatform still exists' }
rg -n 'admin_back_go/internal/module/authplatform' internal cmd
```

Expected: no matches.

- [ ] Run focused tests:

```powershell
go test ./internal/module/auth_platform/... -count=1
go test ./internal/bootstrap ./internal/server -count=1
go test ./internal/architecture -count=1
go test ./internal/server -run TestAdminRouteSnapshot -count=1
```

- [ ] Run full backend suite:

```powershell
go test ./... -count=1
```

## Task 5: Commit

```powershell
git status --short
git add internal docs
git commit -m "refactor: rename auth platform module directory"
```

Final report must include commit SHA, changed paths, verification output summary, and unresolved risks.
