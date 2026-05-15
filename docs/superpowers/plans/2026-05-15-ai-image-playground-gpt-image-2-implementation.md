# AI Image Playground（Agent-Driven, gpt-image-2）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. This plan is for an agent-driven image slice, not a standalone provider platform.

**Goal:** 把图片工作台接到现有 `ai_agents` 配置上：管理员只要建一个 `image_generate` 智能体，前端就能做参考图、遮罩、历史、复用、下载，任务和资产都入库。

**Architecture:** `ai_agents` 继续做唯一配置入口；图片工作台只消费 `scene=image_generate` 的 agent，并把 provider/model 快照写进任务表。`ai_image_tasks` / `ai_image_assets` / `ai_image_task_assets` 记录图片业务事实，后端通过专用 image adapter 调 OpenAI-compatible Images API，前端只做交互和预览，不再用 IndexedDB 当主存储。生成是 Redis-backed Asynq 异步任务：HTTP 只落库并入队，worker 负责真正生成和资产归档。

**Tech Stack:** Go + Gin + GORM + MySQL 8 + existing secretbox / COS upload runtime / operation log / route meta; Vue 3 + TypeScript + Element Plus + existing admin frontend conventions.

**Status:** implemented（automated verification passed；manual provider/worker smoke pending）

**Automated verification（2026-05-15）:**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/aiagent ./internal/module/aiimage ./internal/platform/ai/imagecompat ./internal/platform/storage/cos ./internal/bootstrap ./internal/jobs ./internal/server -count=1
```

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/ai/ai-agent-api.test.ts tests/shared/ai/ai-image-api.test.ts
npm run typecheck
npm run build:check
```

```powershell
cd E:\admin_go\admin_back_go
[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path scripts/full-admin-smoke.ps1), [ref]$tokens, [ref]$errors)
```

**Known whole-tree caveat（2026-05-15）:** `go test ./... -count=1 -p 1` still fails in
`internal/i18n` on non-image legacy fallback gaps, for example
`legacy.2974f5e2335c` / `"无效的支付方式"`. The image playground fallback messages
introduced by this slice are covered in `internal/i18n/locales/*/legacy.yaml`.

---

## Scope lock

只做：

```text
ai_agents.scene=image_generate
agent_id 驱动的图片工作台
task history + detail + favorite + delete + reuse + download
reference asset upload + mask editing
output asset persistence
gpt-image-2 only
```

不做：

```text
新 provider 配置面
fal / custom provider
多模型自由切换
chat / tool / knowledge 语义改造
SSE / streamable
IndexedDB 主存储
PWA / 导入导出
```

---

## Task 1: Agent scene + log boundary + permission plumbing

**Files:**
- Modify: `admin_back_go/internal/module/aiagent/service.go`
- Modify: `admin_back_go/internal/module/aiagent/dto.go`
- Modify: `admin_back_go/internal/module/aiagent/request.go`
- Modify: `admin_back_go/internal/module/aiagent/repository.go`
- Modify: `admin_back_go/internal/middleware/operation_log.go`
- Modify: `admin_back_go/internal/bootstrap/route_meta.go`
- Modify: `admin_back_go/internal/bootstrap/route_meta_test.go`
- Create: `admin_back_go/database/migrations/20260515_ai_image_playground_permission.sql`
- Modify: `admin_front_ts/src/api/ai/agents.ts`
- Modify: `admin_front_ts/src/views/Main/ai/agents/index.vue`
- Modify: `admin_front_ts/src/i18n/locales/zh-CN.ts`
- Modify: `admin_front_ts/src/i18n/locales/en-US.ts`
- Test: `admin_back_go/internal/module/aiagent/service_test.go`
- Test: `admin_front_ts/tests/shared/ai/ai-agent-api.test.ts`

- [x] **Step 1: Make `image_generate` a first-class agent scene**

Add the new scene constant and label in `aiagent`:

```go
const (
    sceneChat          = "chat"
    sceneAgentGenerate = "agent_generate"
    sceneImageGenerate = "image_generate"
)

var sceneLabels = map[string]string{
    sceneChat:          "对话",
    sceneAgentGenerate: "智能体生成",
    sceneImageGenerate: "图片生成",
}
```

Then make `sceneOptions()` include the new value and keep `encodeScenes` / `decodeScenes` strict.

- [x] **Step 2: Make agent options scene-filterable**

Extend the options query so the image page can ask for `scene=image_generate` without inventing a new provider endpoint:

```go
type OptionQuery struct {
    UserID int64
    Scene  string
}
```

Default stays chat for the existing chat runtime. The image playground passes `image_generate`.

- [x] **Step 3: Stop operation logs from swallowing prompt/image payloads**

Extend `OperationRule` with skip flags, not capture flags, so old routes keep their current behavior:

```go
type OperationRule struct {
    Module string
    Action string
    Title  string

    SkipRequestPayload  bool
    SkipResponsePayload bool
}
```

Set the new image routes to skip payload capture. We want metadata only, not prompt text, bytes, or URLs.

- [x] **Step 4: Add the menu/button permission seed**

Create a new migration that inserts the image playground page and its action permissions. Use the page/component path that will be created in Task 4.

Recommended permission codes:

```text
ai_image_playground_page
ai_image_asset_add
ai_image_task_add
ai_image_task_favorite
ai_image_task_del
```

- [x] **Step 5: Update frontend agent labels and the AI agent selector contract**

Update `AiAgentScene` and the scene dropdown so the agent form can create dedicated image agents. The UI should show `图片生成` in the scene picker, but the page itself still works from the selected agent, not from provider/model selectors.

---

## Task 2: Database schema + image adapter primitives

**Files:**
- Create: `admin_back_go/database/migrations/20260515_ai_image_playground.sql`
- Create: `admin_back_go/internal/platform/ai/image.go`
- Create: `admin_back_go/internal/platform/ai/imagecompat/client.go`
- Create: `admin_back_go/internal/platform/ai/imagecompat/client_test.go`
- Create: `admin_back_go/internal/platform/storage/cos/object_reader.go`
- Create: `admin_back_go/internal/platform/storage/cos/object_reader_test.go`

- [x] **Step 1: Add the three image tables**

Create the image task / asset schema from the spec:

```sql
CREATE TABLE `ai_image_tasks` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint unsigned NOT NULL,
  `agent_id` bigint unsigned NOT NULL,
  `agent_name_snapshot` varchar(128) NOT NULL,
  `provider_id_snapshot` bigint unsigned NOT NULL,
  `provider_name_snapshot` varchar(128) NOT NULL,
  `model_id_snapshot` varchar(191) NOT NULL,
  `model_display_name_snapshot` varchar(191) NOT NULL,
  `prompt` text NOT NULL,
  `size` varchar(32) NOT NULL,
  `quality` varchar(16) NOT NULL,
  `output_format` varchar(16) NOT NULL,
  `output_compression` int unsigned NULL,
  `moderation` varchar(16) NOT NULL,
  `n` int unsigned NOT NULL,
  `status` varchar(16) NOT NULL,
  `error_message` varchar(1000) NOT NULL DEFAULT '',
  `actual_params_json` json NULL,
  `raw_response_json` json NULL,
  `is_favorite` tinyint unsigned NOT NULL DEFAULT 2,
  `finished_at` datetime NULL,
  `elapsed_ms` int unsigned NOT NULL DEFAULT 0,
  `is_del` tinyint unsigned NOT NULL DEFAULT 2,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`)
);
```

Then add `ai_image_assets` and `ai_image_task_assets` with the same `is_del` / timestamp conventions.

- [x] **Step 2: Add image-only platform types**

Keep the image boundary separate from chat. Add an interface like this:

```go
type ImageEngine interface {
    GenerateImages(ctx context.Context, input ImageInput) (*ImageResult, error)
}
```

`ImageInput` should carry `Model`, `Prompt`, `InputAssets`, `MaskAsset`, and the request params needed by gpt-image-2.

- [x] **Step 3: Add a COS object reader**

The image task service must be able to load existing input assets again when it reuses an old task or runs an edit request. A writer alone is not enough.

Add a reader helper beside the existing writer so the service can download stored COS objects by key and re-upload them to the provider in the right format.

- [x] **Step 4: Implement the OpenAI-compatible image client**

`internal/platform/ai/imagecompat` should stay image-only and call only the Images API:

- `POST /images/generations` for text-to-image
- `POST /images/edits` for reference-image edits
- accept both `url` and `b64_json`
- normalize output into a small result struct the service can persist

Do not pull chat logic into this client.

- [x] **Step 5: Lock adapter tests first**

Write the tests so they pin the request shape before the service depends on it:

```text
text-to-image request shape
action/edit request shape
b64_json parse path
url parse path
error path when provider returns garbage
```

---

## Task 3: Backend `aiimage` module and route registration

**Files:**
- Create: `admin_back_go/internal/module/aiimage/model.go`
- Create: `admin_back_go/internal/module/aiimage/dto.go`
- Create: `admin_back_go/internal/module/aiimage/request.go`
- Create: `admin_back_go/internal/module/aiimage/repository.go`
- Create: `admin_back_go/internal/module/aiimage/service.go`
- Create: `admin_back_go/internal/module/aiimage/handler.go`
- Create: `admin_back_go/internal/module/aiimage/route.go`
- Test: `admin_back_go/internal/module/aiimage/service_test.go`
- Modify: `admin_back_go/internal/bootstrap/app.go`
- Modify: `admin_back_go/internal/server/router.go`
- Modify: `admin_back_go/internal/bootstrap/route_meta.go`
- Modify: `admin_back_go/internal/bootstrap/route_meta_test.go`

- [x] **Step 1: Model the image task graph**

Add read/write models for:

```text
ai_image_tasks
ai_image_assets
ai_image_task_assets
```

Keep the structs focused:
- task = request snapshot + status
- asset = storage facts
- task_asset = relation / role / ordering / revised prompt

- [x] **Step 2: Define the request and DTO layer**

The create request should be agent-first:

```go
type CreateInput struct {
    AgentID          uint64
    Prompt           string
    Size             string
    Quality          string
    OutputFormat     string
    OutputCompression *int
    Moderation       string
    N                int
    InputAssetIDs    []uint64
    MaskAssetID      uint64
    MaskTargetAssetID uint64
}
```

The detail response should return task metadata plus grouped assets so the frontend can render history and reuse the same data.

- [x] **Step 3: Implement repository queries**

Repository responsibilities:

```text
List / Get / CreateTask / CreateAsset / CreateTaskAsset
UpdateFavorite / SoftDeleteTask
LoadAgentConfig / LoadProviderConfig / LoadProviderModel
LoadTaskAssets / LoadAssetsByIDs
DeleteOrphanAssets
```

Do not let the service query raw tables directly.

- [x] **Step 4: Implement the service flow**

The service should enforce this exact order:

1. load the agent by `agent_id`
2. require `scene=image_generate`
3. require enabled provider + enabled model
4. require `model_id == gpt-image-2`
5. validate input asset ownership and count
6. create the task row first
7. enqueue `ai:image-generate:v1`
8. return `pending` immediately

Worker execution then does the actual image generation:

1. claim `pending` task to `running`
2. reload agent / provider / model / assets runtime facts
3. call the image adapter
4. write output assets and task-asset links
5. finalize status and elapsed time

That keeps failures visible in DB instead of disappearing in the browser.

- [x] **Step 5: Register routes and wire bootstrap**

Expose the resource under `ai-images`:

```text
GET    /api/admin/v1/ai-images/page-init
GET    /api/admin/v1/ai-images
GET    /api/admin/v1/ai-images/:id
POST   /api/admin/v1/ai-images/assets
POST   /api/admin/v1/ai-images
PATCH  /api/admin/v1/ai-images/:id/favorite
DELETE /api/admin/v1/ai-images/:id
```

Wire the module in `app.go` and `server/router.go`, then add the route meta keys from Task 1.

- [x] **Step 6: Make the service tests prove the boundary**

Tests must prove:

```text
scene gate is enforced
provider/model snapshot is loaded from the agent
current-user ownership is enforced
asset validation rejects foreign assets
favorite toggle is idempotent enough
delete does not leak orphan references
adapter failure becomes a task failure
```

---

## Task 4: Frontend image playground page

**Files:**
- Create: `admin_front_ts/src/api/ai/images.ts`
- Create: `admin_front_ts/src/views/Main/ai/image-playground/index.vue`
- Create: `admin_front_ts/src/views/Main/ai/image-playground/components/ImageComposer/index.vue`
- Create: `admin_front_ts/src/views/Main/ai/image-playground/components/ImageAssetList/index.vue`
- Create: `admin_front_ts/src/views/Main/ai/image-playground/components/ImageHistoryGrid/index.vue`
- Create: `admin_front_ts/src/views/Main/ai/image-playground/components/ImageTaskDetailDialog/index.vue`
- Create: `admin_front_ts/src/views/Main/ai/image-playground/components/ImageMaskDialog/index.vue`
- Modify: `admin_front_ts/src/i18n/locales/zh-CN.ts`
- Modify: `admin_front_ts/src/i18n/locales/en-US.ts`
- Test: `admin_front_ts/tests/shared/ai/ai-image-api.test.ts`

- [x] **Step 1: Build the API contract first**

The frontend API should match the agent-first backend:

```ts
export const AiImageApi = {
  init,
  list,
  detail,
  addAsset,
  addTask,
  favorite,
  del,
}
```

`init()` should load the image task dicts and the `scene=image_generate` agent options.

- [x] **Step 2: Build the composer around agent selection**

The image page must select an agent, not a provider.

Use the existing upload runtime (`UpMedia` / `UpMediaList`) to bring images in, then register them through `AiImageApi.addAsset()` so the backend gets real asset rows.

- [x] **Step 3: Build history / detail / reuse**

History should be server-backed only:

- list tasks
- open detail
- reuse the same prompt + params + asset IDs
- download output from stored URLs
- toggle favorite
- delete task

Reuse should just hydrate the composer from task detail. No local store is the source of truth.

- [x] **Step 4: Build mask editing as a first-class dialog**

The mask dialog must preserve the target asset order and send `mask_target_asset_id` explicitly. That avoids the usual “mask is attached to the wrong reference image” mess.

- [x] **Step 5: Add page copy and labels**

Add page-level i18n for:

```text
AI 图片工作台
选择智能体
参考图
遮罩编辑
历史任务
复用
收藏
删除
下载
```

The scene label in the agent page stays `图片生成`.

- [x] **Step 6: Remove local-storage thinking**

No IndexedDB main store, no provider profile store, no hidden browser secret persistence.

---

## Task 5: Docs, smoke, and closure

**Files:**
- Modify: `docs/contracts/admin-api-v1.md`
- Modify: `docs/status/current-status.md`
- Modify: `docs/testing/smoke-matrix.md`
- Modify: `admin_back_go/scripts/full-admin-smoke.ps1`
- Modify: `admin_back_go/internal/module/aiagent/service_test.go`
- Modify: `admin_back_go/internal/module/aiimage/service_test.go`
- Modify: `admin_back_go/internal/platform/ai/imagecompat/client_test.go`
- Modify: `admin_front_ts/tests/shared/ai/ai-image-api.test.ts`

- [x] **Step 1: Update contract docs only after code is in place**

Add the new image playground section to the contract and mark `image_generate` as an allowed agent scene. Only do this after the route and service tests pass.

- [x] **Step 2: Extend smoke coverage**

Add smoke probes for:

```text
ai-agents page-init / list / options with scene=image_generate
ai-images page-init / list / detail / create / favorite / delete
image asset registration
```

- [x] **Step 3: Run backend and frontend verification**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./... -count=1
```

```powershell
cd E:\admin_go\admin_front_ts
npm run test
npm run build:check
```

If the whole tree is noisy, at least run the new module / adapter / API contract tests explicitly.

- [ ] **Step 4: Manual smoke path**

Prove one narrow end-to-end flow from clean state:

```text
create image_generate agent -> register one asset -> submit image task -> refresh -> history still there -> detail opens -> reuse works -> favorite toggles -> delete works
```

- [ ] **Step 5: Close the docs only after manual smoke**

Only after the live provider/worker smoke passes, keep `docs/status/current-status.md` as implemented with real E2E evidence rather than only automated evidence.
