# AI Image Aggregation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` in the assigned backend worktree. Steps use checkbox (`- [ ]`) syntax for tracking. This plan may run in parallel with 14a and 14c, but integration to `master` must be sequential.

**Goal:** Move `aiimage` from a flat top-level module into `internal/module/ai/image` while preserving the AI image playground admin API, queue task type, COS asset behavior, and i18n keys.

**Architecture:** This is a directory/package-boundary refactor only. Keep `package aiimage` for this slice and update imports with alias `aiimage "admin_back_go/internal/module/ai/image"`. Do not alter image task persistence, queue payloads, COS read/write behavior, or `aiimage.*` message keys.

**Tech Stack:** Go, Gin, GORM, taskqueue, infra/ai imagecompat, COS storage adapter, backend architecture tests, admin route snapshot.

---

## Assigned worktree

```text
E:\admin_go_parallel\p14b-ai-image
branch: work/p14b-ai-image
```

Create it from current backend master:

```powershell
cd E:\admin_go\admin_back_go
git fetch origin
git switch master
git pull --ff-only
git worktree add E:\admin_go_parallel\p14b-ai-image -b work/p14b-ai-image master
```

Run all backend commands from `E:\admin_go_parallel\p14b-ai-image`.

## Files

- Move directory: `internal/module/aiimage` -> `internal/module/ai/image`
- Modify: `internal/bootstrap/app.go`
- Modify: `internal/bootstrap/worker.go`
- Modify: `internal/jobs/noop.go`
- Modify: `internal/jobs/noop_test.go`
- Modify: `internal/server/router.go`
- Modify: `internal/server/router_test.go`
- Modify: `internal/server/routes_admin_ai.go`
- Create: `internal/architecture/ai_image_aggregation_test.go`
- Do not modify root docs from this backend worktree.

## Non-negotiable behavior

```text
No DB schema changes.
No frontend changes.
No route URL changes.
No permission code changes.
No i18n key/text changes.
Keep ai_image_tasks, ai_image_assets, ai_image_task_assets table names.
Keep ai:image-generate:v1 task type and QueueLow routing.
Keep /api/admin/v1/ai-images/page-init, list, detail, asset register, create, favorite, delete routes.
Keep aiimage.* zh-CN/en-US catalog keys unchanged.
```

## Task 1: Add RED architecture guard

- [ ] Create `internal/architecture/ai_image_aggregation_test.go`:

```go
package architecture

import "testing"

func TestAIImageOwnedByAIModule(t *testing.T) {
	root := backendRoot(t)
	mustNotExist(t, root, "internal/module/aiimage")
	mustExist(t, root, "internal/module/ai/image/transport/admin/route.go")
	mustExist(t, root, "internal/module/ai/image/jobs.go")
}
```

- [ ] Run RED:

```powershell
cd E:\admin_go_parallel\p14b-ai-image
go test ./internal/architecture -run TestAIImageOwnedByAIModule -count=1
```

Expected before moving directories: FAIL because `internal/module/aiimage` exists and `internal/module/ai/image` does not.

## Task 2: Move directory with history

- [ ] Run:

```powershell
cd E:\admin_go_parallel\p14b-ai-image
New-Item -ItemType Directory -Force .\internal\module\ai | Out-Null
git mv .\internal\module\aiimage .\internal\module\ai\image
```

- [ ] Keep moved Go files as `package aiimage` for this slice.

## Task 3: Update imports and central registration

- [ ] Replace old import paths:

```powershell
cd E:\admin_go_parallel\p14b-ai-image
rg -l 'admin_back_go/internal/module/aiimage' internal cmd | ForEach-Object {
  (Get-Content $_ -Raw) -replace 'admin_back_go/internal/module/aiimage', 'admin_back_go/internal/module/ai/image' | Set-Content -Encoding UTF8 $_
}
```

- [ ] Ensure imports use the explicit alias where needed:

```go
aiimage "admin_back_go/internal/module/ai/image"
```

- [ ] Ensure `internal/server/routes_admin_ai.go` still calls:

```go
aiimageadmin.Register(router, deps.AiImageService)
```

- [ ] Ensure `internal/jobs/noop.go` still registers image handlers with the moved package:

```go
aiimage.RegisterHandlers(mux, deps.AIImageService, logger)
```

## Task 4: Verify old path is gone and image behavior tests pass

- [ ] Format touched Go files:

```powershell
cd E:\admin_go_parallel\p14b-ai-image
gofmt -w .\internal\module\ai\image .\internal\bootstrap .\internal\jobs .\internal\server .\internal\architecture
```

- [ ] Confirm old imports and directory are gone:

```powershell
cd E:\admin_go_parallel\p14b-ai-image
if (Test-Path .\internal\module\aiimage) { throw 'internal/module/aiimage still exists' }
rg -n 'admin_back_go/internal/module/aiimage' internal cmd
```

Expected: `rg` returns no matches.

- [ ] Run focused tests:

```powershell
cd E:\admin_go_parallel\p14b-ai-image
go test ./internal/module/ai/image/... -count=1
go test ./internal/jobs ./internal/bootstrap ./internal/server -count=1
go test ./internal/server -run TestAdminRouteSnapshot -count=1
go test ./internal/architecture -run TestAIImageOwnedByAIModule -count=1
```

## Task 5: Run full backend gate

- [ ] Run:

```powershell
cd E:\admin_go_parallel\p14b-ai-image
go test ./internal/architecture -count=1
go test ./... -count=1
go build ./...
git diff --check
powershell -ExecutionPolicy Bypass -File E:\admin_go\scripts\check-agent-governance.ps1 -Mode working
```

## Task 6: Commit backend slice

- [ ] Review diff:

```powershell
cd E:\admin_go_parallel\p14b-ai-image
git status --short
git diff --stat
```

- [ ] Commit:

```powershell
cd E:\admin_go_parallel\p14b-ai-image
git add internal docs
git commit -m "refactor: aggregate AI image module"
```

- [ ] Final worker report must include changed files, commit SHA, verification commands, and remaining risks.
