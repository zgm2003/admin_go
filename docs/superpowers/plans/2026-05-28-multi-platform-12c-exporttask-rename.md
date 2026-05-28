# Export Task Rename Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` in the assigned backend worktree. Steps use checkbox (`- [ ]`) syntax for tracking. This plan may run in parallel with 12a/12b/12d only in an isolated worktree.

**Goal:** Rename backend capability `internal/module/exporttask` to `internal/module/export` while preserving export-task admin URLs, DB table, queue task type, permission codes, and API payloads.

**Architecture:** The business capability name should be `export`; `exporttask` is an implementation/table naming detail. This is a directory/import-path rename, not a route, schema, or package-identifier change.

**Tech Stack:** Go, Gin transport, Asynq jobs, COS uploader boundary, backend architecture tests, route snapshot.

---

## Assigned worktree

```text
E:\admin_go_parallel\p12c-export
branch: work/p12c-export
```

## Files

- Move: `internal/module/exporttask` -> `internal/module/export`
- Modify imports in `internal/jobs`, `internal/bootstrap`, `internal/module/user`, `internal/server`, and tests.
- Modify `internal/architecture/multiplatform_boundary_test.go`
- Backend docs only if needed: `docs/architecture.md`
- Do not modify root docs/status.

## Non-negotiable behavior

```text
/api/admin/v1/export-tasks URLs unchanged.
export_tasks DB table unchanged.
Asynq task type export:run:v1 unchanged.
permission code user_userManager_export unchanged.
message IDs may remain exporttask.* unless a separate i18n migration is planned; do not rename them here.
No frontend change.
No DB migration.
```

## Task 1: Add architecture guard for export module name

- [ ] Add/extend an architecture test so `internal/module/exporttask` is rejected and `internal/module/export` is required.

Expected assertion intent:

```go
if _, err := os.Stat(filepath.Join(root, "internal", "module", "exporttask")); !os.IsNotExist(err) {
    t.Fatalf("exporttask must be renamed to internal/module/export")
}
if _, err := os.Stat(filepath.Join(root, "internal", "module", "export")); err != nil {
    t.Fatalf("internal/module/export must exist: %v", err)
}
```

- [ ] Run:

```powershell
go test ./internal/architecture -run Export -count=1
```

Expected before implementation: FAIL.

## Task 2: Move directory and rename package

- [ ] Move directory:

```powershell
git mv .\internal\module\exporttask .\internal\module\export
```

- [ ] Keep Go package name `exporttask` inside `internal/module/export`; `export` is a Go keyword, so this slice renames the module directory/path only. External imports may continue to alias the package as `exporttask` while using path `admin_back_go/internal/module/export`.

## Task 3: Update imports and aliases

- [ ] Replace import path:

```powershell
rg -l 'admin_back_go/internal/module/exporttask' internal cmd | ForEach-Object {
  (Get-Content -LiteralPath $_ -Raw).Replace('admin_back_go/internal/module/exporttask','admin_back_go/internal/module/export') | Set-Content -LiteralPath $_ -NoNewline
}
```

- [ ] Update aliases in touched files. Examples:

```go
exporttask "admin_back_go/internal/module/export"
exporttaskadmin "admin_back_go/internal/module/export/transport/admin"
```

- [ ] Update `internal/module/export/transport/admin/aliases.go` to import the new package path as `exporttaskmodule` or similar.
- [ ] Preserve route prefix in `transport/admin/route.go`:

```go
v1 := router.Group("/api/admin/v1/export-tasks")
```

## Task 4: Verification

- [ ] Format:

```powershell
gofmt -w .\internal\module\export .\internal\jobs .\internal\bootstrap .\internal\module\user .\internal\server .\internal\architecture
```

- [ ] Confirm old import/path is gone:

```powershell
if (Test-Path .\internal\module\exporttask) { throw 'internal/module/exporttask still exists' }
rg -n 'admin_back_go/internal/module/exporttask' internal cmd
```

Expected: no matches.

- [ ] Run focused tests:

```powershell
go test ./internal/module/export/... -count=1
go test ./internal/jobs ./internal/bootstrap ./internal/module/user ./internal/server -count=1
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
git commit -m "refactor: rename export task module to export"
```

Final report must include commit SHA, changed paths, verification output summary, and unresolved risks.
