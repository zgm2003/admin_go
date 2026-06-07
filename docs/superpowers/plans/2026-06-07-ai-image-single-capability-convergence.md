# AI Image Single Capability Convergence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Collapse Admin/Canvas image generation into one `internal/module/ai/image` capability backed by `ai_image_tasks` and `ai_image_files`, and make Canvas history backend-owned.

**Architecture:** Keep external Admin and Canvas routes stable. Internally restore one AI image service with `transport/admin` and `transport/canvas`; `platform` is the explicit data dimension. Remove the split `ai/adminimage` and `canvas/image` modules and their four split tables.

**Tech Stack:** Go, Gin, GORM, MySQL migrations, Asynq, Vue 3/Vitest, Next.js/Vitest, root PowerShell governance.

---

## File map

### Backend

- Restore/modify: `admin_back_go/internal/module/ai/image/**`
- Delete: `admin_back_go/internal/module/ai/adminimage/**`
- Delete: `admin_back_go/internal/module/canvas/image/**`
- Modify: `admin_back_go/internal/bootstrap/app.go`
- Modify: `admin_back_go/internal/bootstrap/worker.go`
- Modify: `admin_back_go/internal/jobs/noop.go`
- Modify: `admin_back_go/internal/server/router.go`
- Modify: `admin_back_go/internal/server/routes_admin_ai.go`
- Modify: `admin_back_go/internal/server/routes_canvas.go`
- Modify: `admin_back_go/internal/server/router_test.go`
- Modify: `admin_back_go/internal/bootstrap/route_meta.go`
- Modify: `admin_back_go/internal/shared/enum/ai.go`
- Replace: `admin_back_go/database/migrations/20260607_canvas_admin_image_complete_split.sql` with convergence migration or delete it and add `20260607_ai_image_single_capability_convergence.sql`
- Modify backend architecture guard tests under `admin_back_go/internal/architecture`

### Admin Vue

- Modify: `admin_front_ts/src/api/ai/images.ts`
- Modify: `admin_front_ts/src/api/ai/runs.ts`
- Modify: `admin_front_ts/tests/shared/ai/ai-image-complete-split.test.ts`
- Modify: `admin_front_ts/tests/shared/ai/ai-run-unified-records.test.ts`

### Canvas Next

- Modify: `canvas_front_next/src/services/api/image.ts`
- Modify: `canvas_front_next/src/services/api/image.test.ts`
- Replace: `canvas_front_next/src/services/api/image-complete-split.test.ts`
- Modify: `canvas_front_next/src/app/(user)/image/page.tsx`

### Root docs

- Modify: `docs/status/current-status.md`
- Modify: `docs/status/module-matrix.md`
- Modify: `docs/contracts/admin-api-v1.md`
- Modify generated knowledge artifacts after runtime inventory refresh

---

## Task 1: Backend RED guards for single owner

**Files:**
- Modify: `admin_back_go/internal/architecture/ai_image_aggregation_test.go`
- Modify: `admin_back_go/internal/architecture/image_split_schema_test.go`
- Modify: `admin_back_go/internal/architecture/platform_route_line_test.go`

- [ ] **Step 1: Replace split-owner guard with single-owner guard**

`ai_image_aggregation_test.go` must assert:

```go
func TestImageGenerationOwnedBySingleAICapability(t *testing.T) {
	root := backendRoot(t)
	mustExist(t, root, "internal/module/ai/image/transport/admin/route.go")
	mustExist(t, root, "internal/module/ai/image/transport/canvas/route.go")
	mustExist(t, root, "internal/module/ai/image/jobs.go")
	mustNotExist(t, root, "internal/module/ai/adminimage")
	mustNotExist(t, root, "internal/module/canvas/image")
}
```

- [ ] **Step 2: Replace schema guard**

Schema guard must assert migration/source contains:

```text
ai_image_tasks
ai_image_files
platform
```

and does not create:

```text
admin_ai_image_tasks
admin_ai_image_files
canvas_image_tasks
canvas_image_files
```

- [ ] **Step 3: Replace route owner guard**

`platform_route_line_test.go` must assert:

```text
aiimagecanvas "admin_back_go/internal/module/ai/image/transport/canvas"
aiimagecanvas.RegisterRoutes(router, deps.AiImageService)
```

and no `canvasimagecanvas`.

- [ ] **Step 4: Run RED**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture -run "Image|CanvasAIImage|PlatformRouteLine" -count=1
```

Expected: fail while split modules still exist and routes still point to `canvas/image`.

---

## Task 2: Restore one backend `ai/image` module

**Files:**
- Restore/modify: `admin_back_go/internal/module/ai/image/**`
- Delete: `admin_back_go/internal/module/ai/adminimage/**`
- Delete: `admin_back_go/internal/module/canvas/image/**`

- [ ] **Step 1: Restore `internal/module/ai/image`**

Restore the deleted package from current `HEAD`, then adapt it. The target package name remains:

```go
package aiimage
```

- [ ] **Step 2: Replace old asset model with task-owned file model**

`model.go` must contain:

```go
func (ImageTask) TableName() string { return "ai_image_tasks" }
func (ImageFile) TableName() string { return "ai_image_files" }
```

and no active `ImageAsset` or `ImageTaskAsset` model.

- [ ] **Step 3: Keep one service API**

`HTTPService` must include:

```go
PageInit(ctx context.Context) (*PageInitResponse, *apperror.Error)
List(ctx context.Context, userID uint64, query ListQuery) (*ListResponse, *apperror.Error)
Detail(ctx context.Context, userID uint64, taskID uint64) (*DetailResponse, *apperror.Error)
Create(ctx context.Context, input CreateInput) (*CreateTaskResponse, *apperror.Error)
CreateWithUploadedFiles(ctx context.Context, input CreateWithUploadedFilesInput) (*CreateTaskResponse, *apperror.Error)
Favorite(ctx context.Context, input FavoriteInput) (*TaskDTO, *apperror.Error)
Delete(ctx context.Context, userID uint64, taskID uint64) *apperror.Error
```

- [ ] **Step 4: Platform rules**

Admin transport passes `Platform: enum.PlatformAdmin`.
Canvas transport passes `Platform: enum.PlatformCanvas`.
Repository list/detail/update/delete queries include `platform`.

- [ ] **Step 5: Agent scene rules**

```go
func requiredImageScene(platform string) string {
	if platform == enum.PlatformCanvas {
		return SceneCanvasImageGenerate
	}
	return SceneImageGenerate
}
```

- [ ] **Step 6: Remove split packages**

Delete:

```text
admin_back_go/internal/module/ai/adminimage
admin_back_go/internal/module/canvas/image
```

- [ ] **Step 7: Run module tests**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/ai/image -count=1
```

Expected: pass.

---

## Task 3: Rewire backend bootstrap, routes, jobs, enum, migration

**Files:**
- Modify: `admin_back_go/internal/bootstrap/app.go`
- Modify: `admin_back_go/internal/bootstrap/worker.go`
- Modify: `admin_back_go/internal/jobs/noop.go`
- Modify: `admin_back_go/internal/server/router.go`
- Modify: `admin_back_go/internal/server/routes_admin_ai.go`
- Modify: `admin_back_go/internal/server/routes_canvas.go`
- Modify: `admin_back_go/internal/shared/enum/ai.go`
- Modify/add migration under `admin_back_go/database/migrations`

- [ ] **Step 1: Use one dependency**

Replace:

```go
AdminImageService
CanvasImageService
```

with:

```go
AiImageService aiimage.HTTPService
```

and for jobs:

```go
AiImageService aiimage.JobService
```

- [ ] **Step 2: Route registration**

Admin:

```go
aiimageadmin.Register(router, deps.AiImageService)
```

Canvas:

```go
aiimagecanvas.RegisterRoutes(router, deps.AiImageService)
```

- [ ] **Step 3: Jobs**

Register only one image task handler from `internal/module/ai/image`.

- [ ] **Step 4: Run source type**

Use:

```go
AIRunSourceImageTask = "ai_image_task"
```

Remove `admin_ai_image_task` and `canvas_image_task` from active enum values.

- [ ] **Step 5: Migration**

Create or replace a migration that converges to:

```text
ai_image_tasks
ai_image_files
```

It must drop split tables if present:

```text
admin_ai_image_files
admin_ai_image_tasks
canvas_image_files
canvas_image_tasks
```

It must not create those split tables.

- [ ] **Step 6: Run backend focused tests**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture ./internal/server ./internal/bootstrap ./internal/jobs ./internal/module/ai/image ./internal/module/ai/run -count=1
```

Expected: pass.

---

## Task 4: Canvas Next backend-owned image history

**Files:**
- Modify: `canvas_front_next/src/services/api/image.ts`
- Modify: `canvas_front_next/src/services/api/image.test.ts`
- Replace: `canvas_front_next/src/services/api/image-complete-split.test.ts`
- Modify: `canvas_front_next/src/app/(user)/image/page.tsx`

- [ ] **Step 1: Add RED test**

Canvas test must fail until localforage history is removed:

```ts
expect(pageSource).not.toContain('localforage')
expect(pageSource).not.toContain('image_generation_logs')
expect(pageSource).toContain('listImageTasks')
expect(pageSource).toContain('deleteImageTask')
```

- [ ] **Step 2: Add typed API methods**

`image.ts` exports:

```ts
export type CanvasImageTaskStatus = 'pending' | 'running' | 'success' | 'failed'
export interface CanvasImageTaskItem { id: number; prompt: string; status: CanvasImageTaskStatus; created_at: string; /* plus display fields */ }
export interface CanvasImageFileItem { id: number; task_id: number; role: 'input' | 'mask' | 'output'; storage_url: string; storage_key: string; mime_type: string; width: number; height: number; size_bytes: number }
export interface CanvasImageTaskDetail { task: CanvasImageTaskItem; inputs: CanvasImageFileItem[]; mask?: CanvasImageFileItem | null; outputs: CanvasImageFileItem[] }
export function listImageTasks(params: { page?: number; page_size?: number; status?: CanvasImageTaskStatus | '' })
export function getImageTask(id: number)
export function deleteImageTask(id: number)
```

- [ ] **Step 3: Replace local log store**

Remove `localforage`, `logStore`, `readStoredLogs`, `serializeLog`, and browser history delete code.

Use backend list for `logs`.

- [ ] **Step 4: Generation completion**

After generation succeeds, call backend list refresh. Do not `setItem` browser history.

- [ ] **Step 5: Run Canvas tests**

```powershell
cd E:\admin_go\canvas_front_next
npm test -- src/services/api/image.test.ts src/services/api/image-complete-split.test.ts
npm run typecheck
```

Expected: pass.

---

## Task 5: Admin Vue source type and API guards

**Files:**
- Modify: `admin_front_ts/src/api/ai/runs.ts`
- Modify: `admin_front_ts/tests/shared/ai/ai-run-unified-records.test.ts`
- Modify: `admin_front_ts/tests/shared/ai/ai-image-complete-split.test.ts`

- [ ] **Step 1: RED test for run source type**

The run monitor source type union must contain:

```text
ai_image_task
```

and not contain:

```text
admin_ai_image_task
canvas_image_task
```

- [ ] **Step 2: Update API type guard**

`isAiRunSourceType` accepts `ai_image_task` once.

- [ ] **Step 3: Replace split image guard**

Admin image guard must assert Admin API stays `/api/admin/v1/ai-images` and no `/ai-images/assets`, but must not assert `admin_ai_image_*`.

- [ ] **Step 4: Run Admin Vue tests**

```powershell
cd E:\admin_go\admin_front_ts
npm test -- tests/shared/ai/ai-run-unified-records.test.ts tests/shared/ai/ai-image-complete-split.test.ts tests/shared/ai/ai-image-api.test.ts
npm run typecheck -- --noEmit
```

Expected: pass.

---

## Task 6: Root docs and generated inventory sync

**Files:**
- Modify: `docs/status/current-status.md`
- Modify: `docs/status/module-matrix.md`
- Modify: `docs/contracts/admin-api-v1.md`
- Modify generated `docs/knowledge/*2026-06-07.md`
- Modify: `admin_back_go/docs/architecture.md`

- [ ] **Step 1: Replace split wording**

Docs must say:

```text
AI image generation is owned by internal/module/ai/image.
Admin and Canvas are platform transports.
Active tables are ai_image_tasks and ai_image_files.
Canvas image history is backend-owned.
```

- [ ] **Step 2: Remove wrong active claims**

Docs must not claim these are active:

```text
admin_ai_image_tasks
admin_ai_image_files
canvas_image_tasks
canvas_image_files
internal/module/canvas/image
internal/module/ai/adminimage
```

- [ ] **Step 3: Regenerate inventories**

```powershell
cd E:\admin_go
powershell -ExecutionPolicy Bypass -File .\scripts\export-runtime-inventory.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\export-backend-route-inventory.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\export-backend-route-contract-drift.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\export-frontend-api-inventory.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\export-frontend-backend-api-drift.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\export-api-source-only-route-review.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\export-db-schema-ownership-map.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\export-full-stack-module-map.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\export-backend-capability-manifest.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\export-admin-front-source-quality-inventory.ps1 -OutputDate 2026-06-07
```

- [ ] **Step 4: Run root checks**

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected: pass.

---

## Final verification

Run:

```powershell
cd E:\admin_go\admin_back_go
$env:GOMAXPROCS='2'; go test ./... -count=1 -p=1

cd E:\admin_go\admin_front_ts
npm test
npm run typecheck -- --noEmit

cd E:\admin_go\canvas_front_next
npm test
npm run typecheck

cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```
