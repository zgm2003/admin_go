# Profile UserQuickEntry Ownership Closure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` in the assigned backend worktree. Steps use checkbox (`- [ ]`) syntax for tracking. This plan is safe to run in parallel with 12b/12c/12d only when each worker uses its own `admin_back_go` worktree branch.

**Goal:** Move the current-user quick-entry business implementation from standalone `internal/module/userquickentry` into the existing `internal/module/profile` capability without changing admin quick-entry URLs or payloads.

**Architecture:** `profile` owns current-user self-service. The admin HTTP route already lives under `profile/transport/admin`; this slice moves the remaining service/model/repository code into `profile` and removes the standalone module directory. Keep i18n message keys as `userquickentry.*` to avoid response message drift.

**Tech Stack:** Go, Gin transport, GORM repository, backend architecture tests, admin route snapshot.

---

## Assigned worktree

```text
E:\admin_go_parallel\p12a-profile
branch: work/p12a-profile
```

Run all backend commands from that directory.

## Files

- Move: `internal/module/userquickentry/{dto.go,model.go,repository.go,service.go,service_test.go}` into `internal/module/profile/` with `quickentry_*.go` names.
- Modify: `internal/module/profile/http.go`
- Modify: `internal/module/profile/transport/admin/handler.go`
- Modify: `internal/module/profile/transport/admin/handler_test.go`
- Modify: `internal/bootstrap/app.go`
- Modify: `internal/server/router.go`
- Modify: `internal/server/router_test.go`
- Modify: `internal/architecture/multiplatform_boundary_test.go`
- Modify docs only inside backend repo if needed: `docs/architecture.md`, `internal/module/README.md`
- Do not modify root docs/status in this worktree.

## Non-negotiable behavior

```text
PUT /api/admin/v1/users/me/quick-entries remains unchanged.
response shape remains { code, data, msg }.
quick_entry payload remains unchanged.
message IDs remain userquickentry.*.
No DB schema change.
No frontend change.
```

## Task 1: Add guard for standalone userquickentry removal

- [ ] Add/extend an architecture test in `internal/architecture/multiplatform_boundary_test.go` or a new focused test so it fails while `internal/module/userquickentry` exists and passes after the move.

Expected assertion intent:

```go
if _, err := os.Stat(filepath.Join(root, "internal", "module", "userquickentry")); !os.IsNotExist(err) {
    t.Fatalf("userquickentry must be owned by internal/module/profile, not a standalone module")
}
```

- [ ] Run:

```powershell
go test ./internal/architecture -run UserQuickEntry -count=1
```

Expected before implementation: FAIL because `internal/module/userquickentry` exists.

## Task 2: Move quick-entry implementation into profile

- [ ] Use `git mv` so history is preserved:

```powershell
git mv .\internal\module\userquickentry\dto.go .\internal\module\profile\quickentry_dto.go
git mv .\internal\module\userquickentry\model.go .\internal\module\profile\quickentry_model.go
git mv .\internal\module\userquickentry\repository.go .\internal\module\profile\quickentry_repository.go
git mv .\internal\module\userquickentry\service.go .\internal\module\profile\quickentry_service.go
git mv .\internal\module\userquickentry\service_test.go .\internal\module\profile\quickentry_service_test.go
```

- [ ] Change moved files from `package userquickentry` to `package profile`.
- [ ] Keep exported type/function names stable where useful: `SaveInput`, `SaveResponse`, `QuickEntry`, `HTTPService`, `NewService`, `NewGormRepository` may be reused inside `profile`; if names collide, prefix only the quick-entry service constructor as `NewQuickEntryService` and update callers.
- [ ] Remove the empty `internal/module/userquickentry` directory.

## Task 3: Update profile transport and bootstrap imports

- [ ] Remove imports of `admin_back_go/internal/module/userquickentry`.
- [ ] Update `profile/http.go` so quick-entry HTTP service interfaces refer to local profile types.
- [ ] Update `profile/transport/admin/handler.go` and tests so `SaveInput`, `SaveResponse`, and `QuickEntry` resolve through `profile`.
- [ ] Update `internal/bootstrap/app.go`:

```go
quickEntryService := profile.NewQuickEntryService(profile.NewGormQuickEntryRepository(resources.DB))
```

Use the actual constructor names chosen in Task 2.

- [ ] Update `internal/server/router.go` dependency type so `UserQuickEntryService` no longer imports the old module.
- [ ] Update `internal/server/router_test.go` fake service types to use `profile` quick-entry types.

## Task 4: Verification

- [ ] Format:

```powershell
gofmt -w .\internal\module\profile .\internal\bootstrap .\internal\server .\internal\architecture
```

- [ ] Confirm old module/imports are gone:

```powershell
if (Test-Path .\internal\module\userquickentry) { throw 'internal/module/userquickentry still exists' }
rg -n 'admin_back_go/internal/module/userquickentry|package userquickentry' internal cmd
```

Expected: `rg` returns no matches.

- [ ] Run focused tests:

```powershell
go test ./internal/module/profile/... -count=1
go test ./internal/bootstrap ./internal/server -count=1
go test ./internal/architecture -count=1
go test ./internal/server -run TestAdminRouteSnapshot -count=1
```

- [ ] Run full backend suite:

```powershell
go test ./... -count=1
```

## Task 5: Commit

- [ ] Commit only backend worktree changes:

```powershell
git status --short
git add internal docs
git commit -m "refactor: fold quick entries into profile module"
```

- [ ] Final report must include changed files, commit SHA, commands run, and any risk.
