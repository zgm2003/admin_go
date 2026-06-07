# AI Workspace Prompt Asset Convergence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把图片工作台、提示词库、素材库收敛成 AI module 下的一套领域模型，Admin/Canvas 只保留 platform transport 差异。

**Architecture:** 后端新增 `internal/module/ai/prompt` 与 `internal/module/ai/asset`，迁移 `canvas_prompts/canvas_assets` 到 `ai_prompts/ai_assets`，Canvas 旧 URL 由 AI module 的 canvas transport 接管。Admin 图片工作台改成 Canvas 同款交互，删除收藏/审核/后台筛选语义；Canvas 素材改成后端持久化；403 区分 auth/RBAC 和 provider/business。

**Tech Stack:** Go + Gin + GORM + MySQL migration；Vue 3 + TypeScript + Element Plus + vue-i18n；Next.js + React + Ant Design + Zustand；Go tests、Vitest、vue-tsc、root governance。

---

## Scope check

这是大切片，必须按顺序拆成 9 个可提交任务执行。不要一次性全改。

执行顺序：

1. 后端 schema/ownership guard。
2. `ai/prompt` capability + Canvas `/api/canvas/v1/prompts` 保持不变。
3. `ai/asset` capability + Canvas `/api/canvas/v1/assets` 保持不变。
4. Admin prompt/asset API + RBAC metadata。
5. 后端退休 Admin image favorite public surface。
6. Admin prompt/asset 前端页面。
7. Admin image workspace 对齐 Canvas 交互。
8. Canvas asset 后端持久化 + image 403 分流。
9. 全量验证、文档、generated artifacts。

## File responsibility map

Backend:

- `admin_back_go/database/migrations/20260607_ai_prompt_asset_convergence.sql` — 建 `ai_prompts/ai_assets`，迁移旧表，seed Admin prompt/asset permissions。
- `admin_back_go/internal/architecture/ai_prompt_asset_convergence_test.go` — 防止 prompt/asset 继续归 `canvas` module。
- `admin_back_go/internal/module/ai/prompt/*` — AI prompt model/repository/service + admin/canvas transports。
- `admin_back_go/internal/module/ai/asset/*` — AI asset model/repository/service + admin/canvas transports。
- `admin_back_go/internal/module/canvas/*` — 只保留 Canvas settings，移除 prompt/asset ownership。
- `admin_back_go/internal/server/router.go`、`routes_canvas.go`、`routes_admin_ai.go` — 注册 AI prompt/asset services/routes。
- `admin_back_go/internal/bootstrap/app.go`、`route_meta.go` — 构造 services，添加 Admin mutation permission rules。

Admin frontend:

- `admin_front_ts/src/api/ai/prompts.ts`、`admin_front_ts/src/api/ai/assets.ts` — typed REST clients。
- `admin_front_ts/src/views/Main/ai/prompts/index.vue`、`admin_front_ts/src/views/Main/ai/assets/index.vue` — Admin CRUD pages。
- `admin_front_ts/src/views/Main/ai/image-playground/**` — 图片工作台改成 Canvas 同款记录/生成/结果交互。
- `admin_front_ts/src/i18n/locales/zh-CN.ts`、`en-US.ts` — 新增可见文案。
- `admin_front_ts/tests/shared/ai/*` — API/source guards。

Canvas frontend:

- `canvas_front_next/src/services/api/assets.ts` — Canvas asset backend API。
- `canvas_front_next/src/stores/use-asset-store.ts` — 从 browser-primary store 改成 backend-backed state。
- `canvas_front_next/src/app/(user)/assets/page.tsx`、`image/page.tsx`、`prompts/page.tsx` — 使用 backend asset actions。
- `canvas_front_next/src/services/api/image.ts`、`request.ts`、`components/layout/canvas-auth-guard.tsx` — 403 分流。
- `canvas_front_next/tests/shared/*` — persisted asset 与 403 guards。

---

### Task 1: Backend schema and ownership guard goes RED

**Files:**
- Create: `admin_back_go/internal/architecture/ai_prompt_asset_convergence_test.go`

- [ ] **Step 1: Write failing architecture test**

Create tests that assert:

```text
database/migrations/20260607_ai_prompt_asset_convergence.sql contains:
- CREATE TABLE IF NOT EXISTS `ai_prompts`
- CREATE TABLE IF NOT EXISTS `ai_assets`
- INSERT IGNORE INTO `ai_prompts`
- INSERT IGNORE INTO `ai_assets`
- DROP TABLE IF EXISTS `canvas_prompts`
- DROP TABLE IF EXISTS `canvas_assets`

internal/module/ai/prompt/model.go contains:
- func (Prompt) TableName() string { return "ai_prompts" }

internal/module/ai/asset/model.go contains:
- func (Asset) TableName() string { return "ai_assets" }

internal/module/canvas/*.go does not contain:
- type Prompt struct
- type Asset struct
- canvas_prompts
- canvas_assets
- PublicPrompts(
- PublicAssets(
```

- [ ] **Step 2: Verify RED**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture -run TestAIPromptAsset -count=1
```

Expected: FAIL because migration and AI prompt/asset modules do not exist.

- [ ] **Step 3: Commit failing guard**

```powershell
git add internal/architecture/ai_prompt_asset_convergence_test.go
git commit -m "test: guard AI prompt asset ownership"
```

---

### Task 2: Add `ai/prompt` capability and keep Canvas prompt URL

**Files:**
- Create: `admin_back_go/internal/module/ai/prompt/model.go`
- Create: `admin_back_go/internal/module/ai/prompt/dto.go`
- Create: `admin_back_go/internal/module/ai/prompt/repository.go`
- Create: `admin_back_go/internal/module/ai/prompt/service.go`
- Create: `admin_back_go/internal/module/ai/prompt/service_test.go`
- Create: `admin_back_go/internal/module/ai/prompt/repository_test.go`
- Create: `admin_back_go/internal/module/ai/prompt/transport/canvas/{request.go,handler.go,route.go,handler_test.go}`
- Modify: `admin_back_go/internal/module/canvas/{dto.go,model.go,repository.go,service.go}`
- Modify: `admin_back_go/internal/module/canvas/transport/canvas/{handler.go,route.go}`
- Modify: `admin_back_go/internal/server/{router.go,routes_canvas.go}`
- Modify: `admin_back_go/internal/bootstrap/app.go`

- [ ] **Step 1: Write failing service tests**

`service_test.go` must verify:

```text
PublicList() forces StatusEnabled and IsDelActive.
Create() rejects empty slug/title/prompt with CodeBadRequest.
Repository errors surface as CodeInternal.
```

- [ ] **Step 2: Write failing Canvas handler test**

`handler_test.go` must verify:

```text
GET /api/canvas/v1/prompts?keyword=cat&category=style&tag=poster&current_page=2&page_size=5
calls prompt service PublicList with:
- Keyword = cat
- Category = style
- Tags = [poster]
- CurrentPage = 2
- PageSize = 5
```

- [ ] **Step 3: Verify RED**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/ai/prompt/... -count=1
```

Expected: FAIL because `ai/prompt` package is missing.

- [ ] **Step 4: Implement prompt model**

Use current `canvas.Prompt` fields exactly, but change table ownership:

```go
func (Prompt) TableName() string { return "ai_prompts" }
```

Copy current Canvas prompt query/list/create logic into `internal/module/ai/prompt`, renaming package to `prompt`.

- [ ] **Step 5: Wire Canvas prompt route from AI module**

`routes_canvas.go` must register:

```go
aipromptcanvas.RegisterRoutes(router, deps.AiPromptService)
```

`internal/module/canvas/transport/canvas` must keep only `/api/canvas/v1/settings`.

- [ ] **Step 6: Verify GREEN**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/ai/prompt/... -count=1
go test ./internal/module/canvas/... -count=1
go test ./internal/server -run "TestRouter.*Canvas.*Prompt" -count=1
```

Expected: PASS.

- [ ] **Step 7: Commit**

```powershell
git add internal/module/ai/prompt internal/module/canvas internal/server internal/bootstrap
git commit -m "feat: move canvas prompts to AI prompt capability"
```

---

### Task 3: Add `ai/asset` capability and schema migration

**Files:**
- Create: `admin_back_go/internal/module/ai/asset/model.go`
- Create: `admin_back_go/internal/module/ai/asset/dto.go`
- Create: `admin_back_go/internal/module/ai/asset/repository.go`
- Create: `admin_back_go/internal/module/ai/asset/service.go`
- Create: `admin_back_go/internal/module/ai/asset/service_test.go`
- Create: `admin_back_go/internal/module/ai/asset/repository_test.go`
- Create: `admin_back_go/internal/module/ai/asset/transport/canvas/{request.go,handler.go,route.go,handler_test.go}`
- Create: `admin_back_go/database/migrations/20260607_ai_prompt_asset_convergence.sql`
- Modify: `admin_back_go/internal/server/{router.go,routes_canvas.go}`
- Modify: `admin_back_go/internal/bootstrap/app.go`

- [ ] **Step 1: Write failing asset tests**

Tests must verify:

```text
PublicList() forces StatusEnabled and IsDelActive.
Create() rejects empty slug/type/title.
Create() accepts type text/image/video only.
GET /api/canvas/v1/assets keeps current list URL.
POST /api/canvas/v1/assets creates backend asset.
```

- [ ] **Step 2: Verify RED**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/ai/asset/... -count=1
```

Expected: FAIL because package is missing.

- [ ] **Step 3: Implement asset model**

Use current `canvas.Asset` fields, add video as a valid type, and change table ownership:

```go
const (
    AssetTypeText  = "text"
    AssetTypeImage = "image"
    AssetTypeVideo = "video"
)

func (Asset) TableName() string { return "ai_assets" }
```

- [ ] **Step 4: Implement migration**

Migration must:

```text
CREATE TABLE IF NOT EXISTS `ai_prompts`
CREATE TABLE IF NOT EXISTS `ai_assets`
INSERT IGNORE INTO `ai_prompts` SELECT from `canvas_prompts`
INSERT IGNORE INTO `ai_assets` SELECT from `canvas_assets`
DROP TABLE IF EXISTS `canvas_prompts`
DROP TABLE IF EXISTS `canvas_assets`
```

Stop if duplicate slug data appears in live DB. Do not add slug fallback logic in Go.

- [ ] **Step 5: Wire Canvas asset route**

`routes_canvas.go` must register:

```go
aiassetcanvas.RegisterRoutes(router, deps.AiAssetService)
```

- [ ] **Step 6: Verify GREEN**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/ai/prompt/... -count=1
go test ./internal/module/ai/asset/... -count=1
go test ./internal/module/canvas/... -count=1
go test ./internal/architecture -run TestAIPromptAsset -count=1
go test ./internal/server -run "TestRouter.*Canvas.*(Prompt|Asset)" -count=1
```

Expected: PASS.

- [ ] **Step 7: Commit**

```powershell
git add database/migrations/20260607_ai_prompt_asset_convergence.sql internal/module/ai/asset internal/module/ai/prompt internal/module/canvas internal/server internal/bootstrap internal/architecture
git commit -m "feat: move canvas assets to AI asset capability"
```

---

### Task 4: Add Admin prompt/asset backend APIs and permissions

**Files:**
- Create: `admin_back_go/internal/module/ai/prompt/transport/admin/{request.go,handler.go,route.go,handler_test.go}`
- Create: `admin_back_go/internal/module/ai/asset/transport/admin/{request.go,handler.go,route.go,handler_test.go}`
- Modify: `admin_back_go/internal/server/routes_admin_ai.go`
- Modify: `admin_back_go/internal/bootstrap/{route_meta.go,route_meta_test.go}`
- Modify: `admin_back_go/database/migrations/20260607_ai_prompt_asset_convergence.sql`

- [ ] **Step 1: Write failing Admin transport tests**

Tests must verify these REST paths:

```text
GET    /api/admin/v1/ai-prompts/page-init
GET    /api/admin/v1/ai-prompts
POST   /api/admin/v1/ai-prompts
GET    /api/admin/v1/ai-prompts/:id
PUT    /api/admin/v1/ai-prompts/:id
PATCH  /api/admin/v1/ai-prompts/:id/status
DELETE /api/admin/v1/ai-prompts/:id
DELETE /api/admin/v1/ai-prompts

GET    /api/admin/v1/ai-assets/page-init
GET    /api/admin/v1/ai-assets
POST   /api/admin/v1/ai-assets
GET    /api/admin/v1/ai-assets/:id
PUT    /api/admin/v1/ai-assets/:id
DELETE /api/admin/v1/ai-assets/:id
DELETE /api/admin/v1/ai-assets
```

- [ ] **Step 2: Verify RED**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/ai/prompt/transport/admin -count=1
go test ./internal/module/ai/asset/transport/admin -count=1
```

Expected: FAIL because Admin transports are missing.

- [ ] **Step 3: Implement Admin routes**

Use standard method names:

```text
pageInit/list/detail/create/update/changeStatus/deleteOne/deleteBatch
```

Do not add `add/edit/del/init` aliases.

- [ ] **Step 4: Add permission rules**

Add route metadata for mutation routes:

```text
ai_prompt_add
ai_prompt_edit
ai_prompt_status
ai_prompt_del
ai_asset_add
ai_asset_edit
ai_asset_del
```

Do not add:

```text
ai_image_task_favorite
ai_image_task_audit
```

- [ ] **Step 5: Verify GREEN**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/ai/prompt/transport/admin -count=1
go test ./internal/module/ai/asset/transport/admin -count=1
go test ./internal/bootstrap -run TestPermissionRouteRules -count=1
go test ./internal/server -run "TestRouter.*AI.*(Prompt|Asset)" -count=1
```

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
git add internal/module/ai/prompt internal/module/ai/asset internal/server internal/bootstrap database/migrations/20260607_ai_prompt_asset_convergence.sql
git commit -m "feat: add admin AI prompt asset APIs"
```

---

### Task 5: Retire Admin image favorite public surface

**Files:**
- Modify: `admin_back_go/internal/module/ai/image/{dto.go,service.go,repository.go,service_test.go,model_split_test.go}`
- Modify: `admin_back_go/internal/module/ai/image/transport/admin/{route.go,request.go,handler.go}`
- Modify: `admin_back_go/internal/bootstrap/route_meta_test.go`

- [ ] **Step 1: Write failing source guard**

Add a test in `model_split_test.go` asserting these tokens are absent from Admin image public API files:

```text
/favorite
Favorite(
favoriteRequest
is_favorite
FavoriteArr
```

- [ ] **Step 2: Verify RED**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/ai/image -run TestAdminImageWorkspaceDoesNotExposeFavoriteSurface -count=1
```

Expected: FAIL because favorite route/request/DTO still exists.

- [ ] **Step 3: Remove public favorite API**

Remove:

```text
PATCH /api/admin/v1/ai-images/:id/favorite
favoriteRequest
Handler.Favorite
Service.Favorite
Repository.UpdateFavorite
favorite_arr from page-init
is_favorite from Admin list filter and public DTO
```

Keep DB column until live schema migration is verified. Do not hide it with a default.

- [ ] **Step 4: Verify GREEN**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/ai/image/... -count=1
go test ./internal/bootstrap -run TestRouteMeta -count=1
```

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add internal/module/ai/image internal/bootstrap
git commit -m "refactor: retire admin image favorite surface"
```

---

### Task 6: Add Admin prompt/asset frontend API clients and CRUD pages

**Files:**
- Create: `admin_front_ts/src/api/ai/prompts.ts`
- Create: `admin_front_ts/src/api/ai/assets.ts`
- Create: `admin_front_ts/src/views/Main/ai/prompts/index.vue`
- Create: `admin_front_ts/src/views/Main/ai/assets/index.vue`
- Create: `admin_front_ts/tests/shared/ai/ai-prompt-asset-api.test.ts`
- Modify: `admin_front_ts/src/i18n/locales/zh-CN.ts`
- Modify: `admin_front_ts/src/i18n/locales/en-US.ts`
- Modify: Admin route view registry located by `rg -n "image-playground|view_key|setupDynamicRoutes" admin_front_ts/src`

- [ ] **Step 1: Write failing API/source guard**

Test must assert:

```text
src/api/ai/prompts.ts uses `${ADMIN_API_PREFIX}/ai-prompts`
src/api/ai/assets.ts uses `${ADMIN_API_PREFIX}/ai-assets`
both expose pageInit/list/detail/create/update/deleteOne/deleteBatch
prompt exposes changeStatus
neither contains add/edit/del aliases
neither contains any/as any/Record<string, any>
prompt/assets pages contain Search + AppTable + AppDialog + useCrudTable
prompt/assets pages do not contain raw <el-table or <el-dialog
```

- [ ] **Step 2: Verify RED**

```powershell
cd E:\admin_go\admin_front_ts
npm test -- tests/shared/ai/ai-prompt-asset-api.test.ts
```

Expected: FAIL because files are missing.

- [ ] **Step 3: Implement typed API clients**

Use explicit DTO interfaces. Do not use `any`, `as any`, or browser storage fallback.

- [ ] **Step 4: Implement CRUD pages**

Use:

```text
Search + AppTable + AppDialog + useCrudTable
```

Add all visible labels to `zh-CN.ts` and `en-US.ts`.

- [ ] **Step 5: Verify GREEN**

```powershell
cd E:\admin_go\admin_front_ts
npm test -- tests/shared/ai/ai-prompt-asset-api.test.ts tests/shared/i18n/no-visible-chinese.test.ts
npm run typecheck
```

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
git add src/api/ai/prompts.ts src/api/ai/assets.ts src/views/Main/ai/prompts src/views/Main/ai/assets src/i18n/locales tests/shared/ai/ai-prompt-asset-api.test.ts
git commit -m "feat: add admin AI prompt asset pages"
```

---

### Task 7: Align Admin image workspace with Canvas interactions

**Files:**
- Modify: `admin_front_ts/src/api/ai/images.ts`
- Modify: `admin_front_ts/src/views/Main/ai/image-playground/index.vue`
- Modify: `admin_front_ts/src/views/Main/ai/image-playground/types.ts`
- Modify: `admin_front_ts/src/views/Main/ai/image-playground/components/ImageHistoryGrid/index.vue`
- Modify: `admin_front_ts/src/views/Main/ai/image-playground/components/ImageComposer/index.vue`
- Modify: `admin_front_ts/src/views/Main/ai/image-playground/components/ImageResultPanel/index.vue`
- Create: `admin_front_ts/src/views/Main/ai/image-playground/components/ImagePromptDialog/index.vue`
- Create: `admin_front_ts/src/views/Main/ai/image-playground/components/ImageAssetPicker/index.vue`
- Create: `admin_front_ts/tests/shared/ai/ai-workspace-convergence.test.ts`
- Modify: `admin_front_ts/src/i18n/locales/zh-CN.ts`
- Modify: `admin_front_ts/src/i18n/locales/en-US.ts`

- [ ] **Step 1: Write failing workspace guard**

Guard must assert:

```text
image workspace sources do not contain:
- favorite
- is_favorite
- ai_image_task_favorite
- audit
- 审核
- moderation
- output_compression
- output_format_arr

image workspace sources contain:
- ImagePromptDialog
- ImageAssetPicker
- deleteSelected
- retry
- saveAsset
- addReference
- addToAssets i18n key
- addToReferences i18n key
- pending result i18n key
```

- [ ] **Step 2: Verify RED**

```powershell
cd E:\admin_go\admin_front_ts
npm test -- tests/shared/ai/ai-workspace-convergence.test.ts
```

Expected: FAIL because current workspace still exposes favorite/moderation and lacks Canvas-style result actions.

- [ ] **Step 3: Refactor history panel**

History panel must support:

```text
new
select all / cancel
delete selected
record card click
pagination
```

No favorite/status filter UI.

- [ ] **Step 4: Refactor composer**

Composer must support:

```text
prompt textarea
prompt library
asset library
clipboard reference
upload reference
model/size/quality/count
start generation
```

No visible moderation/output format/output compression controls.

- [ ] **Step 5: Refactor result panel**

Result panel card states:

```text
pending: 生成中
success: image + dimensions + bytes + duration + 添加到素材 + 加入参考图 + 下载
failed: error + retry
empty: 还没有生成图片
```

Delete task detail card and favorite action row.

- [ ] **Step 6: Verify GREEN**

```powershell
cd E:\admin_go\admin_front_ts
npm test -- tests/shared/ai/ai-workspace-convergence.test.ts tests/shared/ai/ai-image-api.test.ts tests/shared/ai/ai-image-complete-split.test.ts tests/shared/i18n/no-visible-chinese.test.ts
npm run typecheck
```

Expected: PASS.

- [ ] **Step 7: Commit**

```powershell
git add src/api/ai/images.ts src/views/Main/ai/image-playground src/i18n/locales tests/shared/ai/ai-workspace-convergence.test.ts
git commit -m "refactor: align admin image workspace with canvas"
```

---

### Task 8: Persist Canvas assets through backend and split image 403 handling

**Files:**
- Create: `canvas_front_next/src/services/api/assets.ts`
- Modify: `canvas_front_next/src/stores/use-asset-store.ts`
- Modify: `canvas_front_next/src/app/(user)/assets/page.tsx`
- Modify: `canvas_front_next/src/app/(user)/image/page.tsx`
- Modify: `canvas_front_next/src/app/(user)/prompts/page.tsx`
- Modify: `canvas_front_next/src/services/api/image.ts`
- Modify: `canvas_front_next/src/services/api/request.ts`
- Create: `canvas_front_next/tests/shared/ai-asset-backend-persistence.test.ts`
- Create: `canvas_front_next/tests/shared/canvas-image-403.test.ts`

- [ ] **Step 1: Write failing asset persistence guard**

Guard must assert:

```text
use-asset-store.ts contains fetchAssets/createAsset/updateAsset/deleteAsset
use-asset-store.ts does not contain persist(
use-asset-store.ts does not contain createJSONStorage
use-asset-store.ts does not contain localStorage
assets page does not treat readAssetPackage as primary persistence
```

- [ ] **Step 2: Write failing 403 guard**

Guard must assert:

```text
image.ts contains readImageAxiosError
image.ts contains isAuthPermissionError
image.ts does not notifyAuthError for every axios 403
request.ts still dispatches auth/RBAC errors to CanvasAuthGuard
```

- [ ] **Step 3: Verify RED**

```powershell
cd E:\admin_go\canvas_front_next
npm run test -- tests/shared/ai-asset-backend-persistence.test.ts tests/shared/canvas-image-403.test.ts
```

Expected: FAIL.

- [ ] **Step 4: Implement Canvas asset API/store**

Create `services/api/assets.ts` for:

```text
GET    /api/canvas/v1/assets
POST   /api/canvas/v1/assets
PUT    /api/canvas/v1/assets/:id
DELETE /api/canvas/v1/assets/:id
```

Change Zustand store to in-memory UI state backed by these calls. Do not silently import old localStorage data.

- [ ] **Step 5: Update Canvas pages**

`assets/page.tsx`, `image/page.tsx`, and `prompts/page.tsx` must call async backend store actions. Import/export can stay only if imported assets are persisted through backend `POST /api/canvas/v1/assets`.

- [ ] **Step 6: Split 403 behavior**

`image.ts` must only call `notifyAuthError` when error is auth/RBAC. Provider/business 403 remains a local image workflow error.

- [ ] **Step 7: Verify GREEN**

```powershell
cd E:\admin_go\canvas_front_next
npm run test -- tests/shared/ai-asset-backend-persistence.test.ts tests/shared/canvas-image-403.test.ts src/services/api/image.test.ts src/services/api/request.test.ts
npm run typecheck
```

Expected: PASS.

- [ ] **Step 8: Commit**

```powershell
git add src/services/api/assets.ts src/stores/use-asset-store.ts "src/app/(user)/assets/page.tsx" "src/app/(user)/image/page.tsx" "src/app/(user)/prompts/page.tsx" src/services/api/image.ts src/services/api/request.ts tests/shared/ai-asset-backend-persistence.test.ts tests/shared/canvas-image-403.test.ts
git commit -m "feat: persist canvas assets through AI asset API"
```

---

### Task 9: Update docs, generated inventories, and run full gates

**Files:**
- Modify: `docs/status/current-status.md`
- Modify: `docs/status/module-matrix.md`
- Regenerate: `docs/knowledge/backend-capability-manifest-2026-06-07.md`
- Regenerate: `docs/knowledge/frontend-api-inventory-2026-06-07.md`
- Regenerate: `docs/knowledge/frontend-backend-api-drift-2026-06-07.md`
- Regenerate: `docs/knowledge/full-stack-module-map-2026-06-07.md`
- Refresh when DB is reachable: `docs/db/mysql-live-schema-2026-06-07.md`
- Refresh when DB is reachable: `docs/db/mysql-live-schema-2026-06-07.sql`

- [ ] **Step 1: Backend full tests**

```powershell
cd E:\admin_go\admin_back_go
$env:GOMAXPROCS='2'
go test ./... -count=1 -p=1
```

Expected: PASS.

- [ ] **Step 2: Admin frontend full tests**

```powershell
cd E:\admin_go\admin_front_ts
npm test
npm run typecheck
```

Expected: PASS.

- [ ] **Step 3: Canvas frontend full tests**

```powershell
cd E:\admin_go\canvas_front_next
npm run test
npm run typecheck
```

Expected: PASS.

- [ ] **Step 4: Backend contract and smoke**

```powershell
cd E:\admin_go\admin_back_go
powershell -ExecutionPolicy Bypass -File .\scripts\check-contract.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\basic-admin-smoke.ps1 -Account 15671628271 -Password 123456
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account 15671628271 -Password 123456
```

Expected: PASS.

- [ ] **Step 5: Regenerate inventories**

```powershell
cd E:\admin_go
powershell -ExecutionPolicy Bypass -File .\scripts\export-backend-capability-manifest.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\export-frontend-api-inventory.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\export-frontend-backend-api-drift.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\export-full-stack-module-map.ps1
```

Expected: prompt/asset ownership reports under AI, with no owner-decision-required API rows.

- [ ] **Step 6: Refresh live schema when DB is reachable**

```powershell
cd E:\admin_go
powershell -ExecutionPolicy Bypass -File .\scripts\export-live-mysql-schema.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1 -LiveSchema
```

Expected: `ai_prompts` and `ai_assets` exist. If old tables remain for a migration window, record that as a verification gap instead of claiming table retirement.

- [ ] **Step 7: Update status docs**

Only after previous gates pass, update current status with exact passed commands. Do not write WIP as verified.

- [ ] **Step 8: Root governance**

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1
```

Expected: PASS.

- [ ] **Step 9: Commit docs/generated artifacts**

```powershell
git add docs/status docs/knowledge docs/db
git commit -m "docs: record AI prompt asset convergence"
```

---

## Self-review

Spec coverage:

- 图片统一能力：Tasks 5 and 7.
- 提示词归 AI module：Tasks 1, 2, 4, 6, 9.
- 素材归 AI module：Tasks 1, 3, 4, 6, 8, 9.
- Canvas URL 不破坏：Tasks 2, 3, 8.
- Admin/Canvas 交互一致：Task 7.
- 403 分流：Task 8.
- 验证与文档：Task 9.

Execution requirements:

- 每个实现任务先 RED，再 GREEN。
- 每个任务单独提交。
- 完成前必须跑 Task 9 的 full gates。
