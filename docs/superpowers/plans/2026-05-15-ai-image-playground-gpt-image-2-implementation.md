# AI Image Playground（gpt-image-2）Implementation Plan

> **For agentic workers:** 这份计划按任务切片执行。先做后端合同和表，再做执行链路，再做前端，最后验证。

**Goal:** 把 gpt-image-2 图像 playground 变成 admin 原生能力：账号配置复用现有 `ai_providers`，任务和资产入库，前端提供真实可用的生成 / 历史 / 复用工作台。

**Architecture:** `ai_providers` / `ai_provider_models` 继续做账号与模型事实源；`ai_image_tasks`、`ai_image_assets`、`ai_image_task_assets` 负责图像业务事实；前端只负责交互和展示，不再保留任何 IndexedDB 主存储；worker 负责 OpenAI-compatible Images API 调用和对象存储落库。

**Tech Stack:** Go + Gin + GORM + MySQL 8 + existing secretbox / upload / COS / queue / realtime foundation; Vue 3 + TypeScript + existing admin frontend conventions.

---

## Scope lock

只做：

```text
gpt-image-2
OpenAI-compatible Images API
task history + detail + favorite + delete + reuse
reference image upload + mask editing
output image persistence
```

不做：

```text
fal / custom provider / ZIP import-export / prompt gallery / PWA / SSE
```

---

## Task 1: Schema and contract

**Files:**

- Create: `admin_back_go/database/migrations/20260515_ai_image_playground.sql`
- Modify: `docs/contracts/admin-api-v1.md`
- Modify: `docs/status/current-status.md`
- Modify: `admin_back_go/internal/bootstrap/route_meta.go`
- Modify: `admin_back_go/internal/bootstrap/route_meta_test.go`

- [ ] **Step 1: Add image playground tables**

Create the three tables from the spec:

```text
ai_image_tasks
ai_image_assets
ai_image_task_assets
```

Rules:

```text
tasks store provider/model snapshots and task state
assets store COS-backed files only
task_assets store ordering and per-output metadata
```

- [ ] **Step 2: Define enums/dicts**

Add explicit status / role / format / quality / moderation dicts only for the image playground.

Keep the values narrow:

```text
status: running/success/failed/canceled/timeout
asset role: input/mask/output
storage_provider: cos
```

- [ ] **Step 3: Extend route metadata**

Add the new route keys and operation log rules for:

```text
ai_image_playground_page
ai_image_task_add
ai_image_task_favorite
ai_image_task_del
```

- [ ] **Step 4: Update contract docs**

Document:

```text
new endpoints
task ownership
asset persistence rules
gpt-image-2 only
no plaintext API key exposure
```

---

## Task 2: Backend module and image execution

**Files:**

- Create: `admin_back_go/internal/module/aiimage/model.go`
- Create: `admin_back_go/internal/module/aiimage/dto.go`
- Create: `admin_back_go/internal/module/aiimage/request.go`
- Create: `admin_back_go/internal/module/aiimage/repository.go`
- Create: `admin_back_go/internal/module/aiimage/service.go`
- Create: `admin_back_go/internal/module/aiimage/handler.go`
- Create: `admin_back_go/internal/module/aiimage/route.go`
- Create: `admin_back_go/internal/platform/ai/imagecompat/client.go`
- Create: `admin_back_go/internal/platform/ai/imagecompat/client_test.go`
- Test: `admin_back_go/internal/module/aiimage/service_test.go`

- [ ] **Step 1: Model the task and asset rows**

Add read/write models for:

```text
ai_image_tasks
ai_image_assets
ai_image_task_assets
```

Do not add any “config_json” dumping ground columns.

- [ ] **Step 2: Add request/response contracts**

The create request should carry:

```text
prompt
provider_id
model_id
params
reference images
mask asset
```

The detail response should return:

```text
task metadata
provider/model snapshots
task assets grouped by role
actual params
revised prompt
```

- [ ] **Step 3: Implement repository**

Repository needs:

```text
List / Get / Create / UpdateStatus / UpdateFavorite / SoftDelete
InsertAssets / InsertTaskAssets / LoadTaskAssets
FindProviderWithModel / LoadProviderSecret
DeleteOrphanAssets
```

Delete must clean orphan objects, but only when no other task_asset row still references them.

- [ ] **Step 4: Add OpenAI Images adapter**

`internal/platform/ai/imagecompat` must:

```text
call /images/generations for text-to-image
call /images/edits for reference-image edits
accept url or b64_json results
normalize output images into stored assets
```

Keep this client image-only. Do not fold it into chat code.

- [ ] **Step 5: Implement service orchestration**

Service rules:

```text
only current-user tasks
only gpt-image-2 model_id accepted
provider/model must exist and be enabled
reference image count limited
mask must be validated before submit
status transitions explicit
raw provider payload stored only on parse failure or hard error
```

- [ ] **Step 6: Register routes**

Routes:

```text
GET    /api/admin/v1/ai-image-tasks/page-init
GET    /api/admin/v1/ai-image-tasks
POST   /api/admin/v1/ai-image-tasks
GET    /api/admin/v1/ai-image-tasks/:id
PATCH  /api/admin/v1/ai-image-tasks/:id/favorite
DELETE /api/admin/v1/ai-image-tasks/:id
```

Maybe no separate asset CRUD in v1. Assets are task-owned records created through task submit.

---

## Task 3: Worker and storage integration

**Files:**

- Modify: `admin_back_go/internal/bootstrap/app.go`
- Modify: `admin_back_go/internal/bootstrap/worker.go`
- Modify: `admin_back_go/internal/jobs/*` as needed
- Modify: `admin_back_go/internal/platform/storage/*` if a small helper is missing
- Test: queue / service tests for the new task execution path

- [ ] **Step 1: Wire the task into the worker boundary**

The task should be enqueued after create and executed out of request path.

No browser polling the provider directly.

- [ ] **Step 2: Fetch uploaded inputs and store outputs**

Worker flow:

```text
load provider secret
fetch COS input assets
call provider
store output assets to COS
write asset/link rows
finalize task state
```

- [ ] **Step 3: Handle failures explicitly**

Required failure cases:

```text
missing provider
missing gpt-image-2 model
provider timeout
provider parse failure
mask validation failure
asset fetch failure
storage write failure
```

Each case must end in a visible task error, not a silent retry loop.

- [ ] **Step 4: Keep operation log small**

Operation log should only see task request metadata, not image bytes.

---

## Task 4: Frontend image playground page

**Files:**

- Create: `admin_front_ts/src/api/ai/images.ts`
- Create: `admin_front_ts/src/views/Main/ai/image-playground/index.vue`
- Create: `admin_front_ts/src/views/Main/ai/image-playground/components/*`
- Modify: `admin_front_ts/src/router/*` or menu registration files as needed
- Modify: `admin_front_ts/src/types/*` if shared types are needed

- [ ] **Step 1: Build the page shell**

Page parts:

```text
provider selector
prompt editor
reference image area
parameter bar
submit button
history grid
detail modal
lightbox
mask editor modal
```

- [ ] **Step 2: Reuse existing upload runtime**

Use the current `upload-tokens` flow for reference images.

Frontend must not store API keys and must not own COS credentials.

- [ ] **Step 3: Keep composer behavior simple**

First version composer rules:

```text
one task at a time
one provider selected from admin config
model fixed to gpt-image-2
reference image order preserved
mask edit confirms full-image coverage
```

- [ ] **Step 4: Implement history interactions**

Must support:

```text
list / search / favorite / delete / detail / reuse / download
```

Defer batch selection and bulk download if the page starts to bloat.

- [ ] **Step 5: Remove local-storage thinking**

No `IndexedDB` task store, no local provider profile store, no front-end secret persistence.

---

## Task 5: Verification and docs closure

**Files:**

- Modify: `docs/status/current-status.md`
- Modify: `docs/contracts/admin-api-v1.md`
- Add/adjust tests in backend and frontend

- [ ] **Step 1: Backend unit tests**

Test:

```text
provider/model gate
task create
asset persistence
orphan cleanup
favorite toggle
task delete
OpenAI Images adapter happy path and failure path
```

- [ ] **Step 2: Frontend build / typecheck**

Run:

```powershell
cd E:\admin_go\admin_front_ts
npm run test
npm run build
```

- [ ] **Step 3: Backend tests**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./... -count=1
```

If that is too broad, at least run the new module + adapter packages explicitly.

- [ ] **Step 4: Manual smoke**

Prove this one path:

```text
pick enabled provider -> submit prompt -> finish one task -> refresh -> task still there -> output preview works -> reuse works
```

- [ ] **Step 5: Update runtime truth docs**

Mark image playground as implemented only after the smoke and tests pass.
