# Canvas Front Next Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 新增 `canvas_front_next`，并把 infinite-canvas 的画布、提示词/素材库、文本/图片/视频生成接入 `admin_go` 的 auth/RBAC/wallet/AI billing 基线。

**Architecture:** `canvas_front_next` 是独立 Next.js 前端；所有安全、钱包、provider、billing、公共库 API 都由 `admin_back_go` 提供 `/api/canvas/v1/*` 和 admin 管理接口。余额唯一事实源是 `user_wallets + wallet_transactions`，AI 扣费唯一审计锚点是 `ai_billing_records(platform=canvas)`。

**Tech Stack:** Go + Gin + GORM + MySQL；Next.js App Router + React + TypeScript + Tailwind + Ant Design；Vitest + Go tests + root governance checker。

---

## Scope Gates

- 只新增 `canvas_front_next`，不把 `E:\GitDownload\infinite-canvas` 后端作为长期 runtime。
- 不新增 `canvas_users`、`canvas_credit_logs`、`canvas_settings`、`canvas_model_channels`、`canvas_projects`。
- 不改已收敛的 admin 支付菜单；canvas 充值通过新的 canvas transport 复用 payment service。
- 不让 canvas 前端保存 provider API key / base_url。
- 不新增 Grok/xAI 配置表；优先复用 `ai_providers(engine_type=openai, driver=openai)`。

## File Structure Map

### Root docs
- Create: `docs/superpowers/specs/2026-05-31-canvas-front-next-integration-design.md`
- Create: `docs/superpowers/plans/2026-05-31-canvas-front-next-integration.md`
- Modify after implementation: `docs/status/module-matrix.md`, `docs/contracts/admin-api-v1.md`, `docs/testing/smoke-matrix.md`

### Backend: `admin_back_go`
- Create: `database/migrations/20260531_canvas_front_next_integration.sql`
- Create: `internal/architecture/canvas_front_next_integration_test.go`
- Create: `internal/module/auth/transport/canvas/{handler.go,request.go,route.go,handler_test.go}`
- Create: `internal/module/payment/wallet/transport/canvas/{handler.go,request.go,route.go,handler_test.go}`
- Create: `internal/module/payment/transport/canvas/{handler.go,request.go,route.go,handler_test.go}`
- Create: `internal/module/canvas/{dto.go,model.go,repository.go,repository_test.go,service.go,service_test.go}`
- Create: `internal/module/canvas/transport/admin/{handler.go,request.go,route.go,handler_test.go}`
- Create: `internal/module/canvas/transport/canvas/{handler.go,request.go,route.go,handler_test.go}`
- Modify: `internal/server/router.go`, `internal/server/routes_admin_commerce_rbac.go`, `internal/bootstrap/app.go`, `internal/bootstrap/route_meta.go`, `internal/bootstrap/route_meta_test.go`
- Modify/Create i18n: `internal/shared/i18n/locales/{zh-CN,en-US}/canvas.yaml`
- Modify AI infra only if video requires it: `internal/infra/ai/{types.go,openaicompat|imagecompat|provider}`

### Frontend: `canvas_front_next`
- Create project from `E:\GitDownload\infinite-canvas\web`
- Modify/delete old API clients under `src/services/api/*`
- Delete old admin pages under `src/app/(admin)`
- Modify auth/user/config stores under `src/stores/*`
- Modify canvas generation callers under `src/app/(user)/canvas/**`, `src/app/(user)/image/**`, `src/app/(user)/video/**`
- Add tests under `tests/shared/**` or colocated `*.test.ts(x)`

---

### Task 1: Contract tests first

**Files:**
- Create: `admin_back_go/internal/architecture/canvas_front_next_integration_test.go`
- Create: `canvas_front_next/tests/shared/canvas-api-boundary.test.ts`

- [ ] **Step 1: Write backend architecture test**

Assert the migration and routes contain required facts:

```go
for _, want := range []string{
  "auth_platforms", "canvas", "无限画布",
  "canvas_prompts", "canvas_assets",
  "/api/canvas/v1/auth/login", "/api/canvas/v1/wallet/summary",
  "/api/canvas/v1/ai/videos", "platform=canvas",
} { assertContains(source, want) }
```

Assert forbidden duplicate facts are absent:

```go
for _, forbidden := range []string{
  "canvas_users", "canvas_credit_logs", "canvas_settings", "canvas_model_channels", "canvas_projects",
  "credit_logs", "users.credits", "wallet_consume_add",
} { assertNotContains(source, forbidden) }
```

- [ ] **Step 2: Write frontend boundary test**

After `canvas_front_next` exists, assert:

```ts
expect(allSource).toContain('/api/canvas/v1/auth/login')
expect(allSource).toContain('/api/canvas/v1/ai/videos')
expect(allSource).not.toContain('/api/auth/login')
expect(allSource).not.toContain('/api/v1/chat/completions')
expect(allSource).not.toContain('/api/admin/users')
expect(allSource).not.toContain('credit_logs')
expect(allSource).not.toContain('apiKey')
expect(allSource).not.toContain('baseUrl')
```

- [ ] **Step 3: Run RED**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture -run CanvasFrontNextIntegration -count=1
```

Expected: fail because migration/routes do not exist yet.

---

### Task 2: Add migration for canvas platform and only-used tables

**Files:**
- Create: `admin_back_go/database/migrations/20260531_canvas_front_next_integration.sql`

- [ ] **Step 1: Add `auth_platforms.canvas` seed**

Use guarded SQL. Required row:

```sql
code='canvas', name='无限画布', captcha_type='slide', status=1, is_del=2
```

Do not make `admin` deletable or touch existing `app`/`admin` rows.

- [ ] **Step 2: Add canvas RBAC permissions**

Seed platform `canvas` permissions:

```text
canvas_access
canvas_prompt_read
canvas_asset_read
canvas_ai_text_generate
canvas_ai_image_generate
canvas_ai_video_generate
canvas_wallet_read
canvas_recharge_add
canvas_recharge_pay
```

- [ ] **Step 3: Create `canvas_prompts`**

Create the table exactly with useful fields from the spec. Include:

```sql
UNIQUE KEY uk_canvas_prompts_slug(slug),
KEY idx_canvas_prompts_category_status(category, status, is_del, updated_at, id),
KEY idx_canvas_prompts_status_updated(status, is_del, updated_at, id)
```

- [ ] **Step 4: Create `canvas_assets`**

Create the table exactly with useful fields from the spec. Include:

```sql
UNIQUE KEY uk_canvas_assets_slug(slug),
KEY idx_canvas_assets_type_status(type, status, is_del, updated_at, id),
KEY idx_canvas_assets_status_updated(status, is_del, updated_at, id)
```

- [ ] **Step 5: Run architecture test GREEN for migration facts**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture -run CanvasFrontNextIntegration -count=1
```

Expected: backend architecture test passes for migration content after routes are stubbed or test scope is temporarily migration-only.

---

### Task 3: Add canvas auth transport

**Files:**
- Create: `admin_back_go/internal/module/auth/transport/canvas/{handler.go,request.go,route.go,handler_test.go}`
- Modify: `admin_back_go/internal/server/router.go`

- [ ] **Step 1: Write handler tests**

Cases:

```text
GET /api/canvas/v1/auth/login-config calls auth service with platform canvas
POST /api/canvas/v1/auth/login issues token with platform canvas
POST /api/canvas/v1/auth/register uses platform canvas
GET /api/canvas/v1/users/me rejects admin-platform token
```

- [ ] **Step 2: Implement thin transport**

The handler must not reimplement auth logic. It only maps request fields and passes `platform="canvas"` into the existing auth/session service.

- [ ] **Step 3: Register routes**

```go
canvas := router.Group("/api/canvas/v1")
canvasauth.RegisterRoutes(canvas, deps.AuthService)
```

- [ ] **Step 4: Verify**

```powershell
go test ./internal/module/auth/transport/canvas ./internal/server -count=1
```

Expected: pass.

---

### Task 4: Add canvas wallet and recharge transport

**Files:**
- Create: `admin_back_go/internal/module/payment/wallet/transport/canvas/{handler.go,request.go,route.go,handler_test.go}`
- Create: `admin_back_go/internal/module/payment/transport/canvas/{handler.go,request.go,route.go,handler_test.go}`
- Modify: `admin_back_go/internal/server/router.go`

- [ ] **Step 1: Write wallet route tests**

Cases:

```text
GET /api/canvas/v1/wallet/summary reads only token user
GET /api/canvas/v1/wallet/transactions forces token user_id
POST /api/canvas/v1/wallet/consumptions is not mounted
```

- [ ] **Step 2: Write recharge route tests**

Cases:

```text
GET /api/canvas/v1/payment/recharges/page-init works for current user
POST /api/canvas/v1/payment/recharges creates current-user recharge
POST /api/canvas/v1/payment/recharges/:id/pay continues pay
POST /api/canvas/v1/payment/recharges/:id/sync is not mounted
PATCH /api/canvas/v1/payment/recharges/:id/close is not mounted
```

- [ ] **Step 3: Implement transports by reusing services**

Do not copy wallet/payment business code. Reuse existing service methods and force current token user.

- [ ] **Step 4: Verify**

```powershell
go test ./internal/module/payment/wallet/transport/canvas ./internal/module/payment/transport/canvas ./internal/server -count=1
```

Expected: pass.

---

### Task 5: Add canvas prompt/asset backend module

**Files:**
- Create: `admin_back_go/internal/module/canvas/{dto.go,model.go,repository.go,repository_test.go,service.go,service_test.go}`
- Create: `admin_back_go/internal/module/canvas/transport/admin/{handler.go,request.go,route.go,handler_test.go}`
- Create: `admin_back_go/internal/module/canvas/transport/canvas/{handler.go,request.go,route.go,handler_test.go}`

- [ ] **Step 1: Write repository tests**

Prove:

```text
prompt list filters keyword/category/status/is_del and orders updated_at,id desc
asset list filters keyword/type/status/is_del and orders updated_at,id desc
delete is soft delete by is_del=1
slug is unique
```

- [ ] **Step 2: Write service tests**

Prove:

```text
prompt create requires title/prompt/slug
asset create requires title/type/slug
asset type only text/image
public list returns only status=1 and is_del=2
admin list can filter disabled rows
```

- [ ] **Step 3: Implement models**

Use table names:

```go
func (Prompt) TableName() string { return "canvas_prompts" }
func (Asset) TableName() string { return "canvas_assets" }
```

- [ ] **Step 4: Implement admin REST**

```text
/api/admin/v1/canvas/prompts/page-init
/api/admin/v1/canvas/prompts
/api/admin/v1/canvas/assets/page-init
/api/admin/v1/canvas/assets
```

Use admin route metadata permissions such as `canvas_prompt_manage` and `canvas_asset_manage` only if the admin menu is actually added.

- [ ] **Step 5: Implement canvas public REST**

```text
GET /api/canvas/v1/prompts
GET /api/canvas/v1/assets
```

- [ ] **Step 6: Verify**

```powershell
go test ./internal/module/canvas ./internal/module/canvas/transport/admin ./internal/module/canvas/transport/canvas ./internal/server -count=1
```

Expected: pass.

---

### Task 6: Add canvas settings facade

**Files:**
- Create or extend: `admin_back_go/internal/module/canvas/transport/canvas/handler.go`
- Test: `admin_back_go/internal/module/canvas/transport/canvas/handler_test.go`

- [ ] **Step 1: Write test for public settings**

Expected response contains only:

```json
{
  "allow_register": true,
  "scenes": ["canvas_text_generate", "canvas_image_generate", "canvas_video_generate"],
  "billing": [{"scene":"canvas_image_generate","unit":"image","unit_price_cents":100}],
  "wallet": {"balance_cents": 0}
}
```

Assert it does not contain:

```text
api_key
api_key_enc
base_url
system_prompt
provider raw config
```

- [ ] **Step 2: Implement facade**

Read auth platform policy, enabled billing rules, enabled canvas agents/model display names, and current wallet summary if authenticated.

- [ ] **Step 3: Verify**

```powershell
go test ./internal/module/canvas/transport/canvas -count=1
```

Expected: pass.

---

### Task 7: Add canvas AI generation billing flow

**Files:**
- Create/modify: `admin_back_go/internal/module/canvas/service.go`
- Create/modify: `admin_back_go/internal/module/canvas/transport/canvas/handler.go`
- Modify AI infra only if needed for video adapter.

- [ ] **Step 1: Write service tests**

Cases:

```text
text generation charges scene canvas_text_generate with unit_count=1
image generation charges scene canvas_image_generate with unit_count=n
video generation charges scene canvas_video_generate with unit_count=duration_seconds
insufficient balance returns before provider call
provider create failure refunds once
video failed/cancelled poll refunds once
video poll uses provider_id/model_id/provider_task_id from ai_billing_records, not request query trust
```

- [ ] **Step 2: Implement charge before provider call**

Call existing AI billing service:

```go
billing.Charge(ctx, billing.ChargeInput{Platform:"canvas", Scene: scene, UserID: userID, AgentID: agentID, ProviderID: providerID, ModelID: modelID, UnitCount: unitCount})
```

- [ ] **Step 3: Implement video task binding**

Bind provider task ID to `ai_billing_records.provider_task_id`. Do not create `canvas_video_tasks` unless `ai_billing_records` proves insufficient in tests.

- [ ] **Step 4: Register routes**

```text
POST /api/canvas/v1/ai/chat/completions
POST /api/canvas/v1/ai/images/generations
POST /api/canvas/v1/ai/images/edits
POST /api/canvas/v1/ai/videos
GET  /api/canvas/v1/ai/videos/:id
GET  /api/canvas/v1/ai/videos/:id/content
```

- [ ] **Step 5: Verify**

```powershell
go test ./internal/module/canvas ./internal/infra/ai/... -count=1
```

Expected: pass.

---

### Task 8: Scaffold `canvas_front_next`

**Files:**
- Create: `E:\admin_go\canvas_front_next\...`

- [ ] **Step 1: Copy frontend only**

Copy from:

```powershell
E:\GitDownload\infinite-canvas\web
```

Do not copy Go backend, `.env` secrets, output files, or old admin runtime.

- [ ] **Step 2: Verify package baseline**

```powershell
cd E:\admin_go\canvas_front_next
npm install
npm run typecheck
npm run test
```

Expected: baseline status recorded. If copied tests fail because old API is still present, keep them as RED for the next task instead of deleting them blindly.

- [ ] **Step 3: Add boundary tests**

Create `tests/shared/canvas-api-boundary.test.ts` from Task 1 and run it RED.

---

### Task 9: Replace auth/settings/credits clients in `canvas_front_next`

**Files:**
- Modify: `canvas_front_next/src/services/api/auth.ts`
- Modify: `canvas_front_next/src/services/api/request.ts`
- Modify/Delete: `canvas_front_next/src/services/api/admin.ts`
- Modify: `canvas_front_next/src/stores/use-user-store.ts`
- Modify: `canvas_front_next/src/stores/use-config-store.ts`
- Modify UI components that render credits/API key/base URL.

- [ ] **Step 1: Replace auth endpoints**

Use:

```text
/api/canvas/v1/auth/login
/api/canvas/v1/auth/register
/api/canvas/v1/users/me
/api/canvas/v1/auth/login-config
```

- [ ] **Step 2: Replace settings endpoint**

Use:

```text
/api/canvas/v1/settings
```

Delete user-editable provider config from UI state. Keep only UI preferences like theme or generation params.

- [ ] **Step 3: Replace credits display with wallet**

Use:

```text
/api/canvas/v1/wallet/summary
/api/canvas/v1/wallet/transactions
```

Remove `credits` as a data field from user store. If the UI text still wants a short label, render wallet balance text.

- [ ] **Step 4: Verify frontend boundary**

```powershell
cd E:\admin_go\canvas_front_next
npm run test -- --run tests/shared/canvas-api-boundary.test.ts
npm run typecheck
```

Expected: pass.

---

### Task 10: Replace AI generation clients

**Files:**
- Modify: `canvas_front_next/src/services/api/image.ts`
- Modify: `canvas_front_next/src/services/api/video.ts`
- Modify/create: `canvas_front_next/src/services/api/chat.ts`
- Modify canvas/image/video pages that call old `/api/v1/*`.

- [ ] **Step 1: Route all text generation through canvas API**

```text
POST /api/canvas/v1/ai/chat/completions
```

- [ ] **Step 2: Route image generation/edit through canvas API**

```text
POST /api/canvas/v1/ai/images/generations
POST /api/canvas/v1/ai/images/edits
```

- [ ] **Step 3: Route video generation/poll/content through canvas API**

```text
POST /api/canvas/v1/ai/videos
GET  /api/canvas/v1/ai/videos/:id
GET  /api/canvas/v1/ai/videos/:id/content
```

- [ ] **Step 4: Remove local/custom channel mode**

Delete branches that call user-provided `baseUrl` directly. If tests expect local mode, rewrite them to expect server-managed canvas mode.

- [ ] **Step 5: Verify**

```powershell
npm run test -- --run src/services/api/image.test.ts src/services/api/video.test.ts tests/shared/canvas-api-boundary.test.ts
npm run typecheck
```

Expected: pass.

---

### Task 11: Remove old admin UI from `canvas_front_next`

**Files:**
- Delete: `canvas_front_next/src/app/(admin)/**`
- Delete old admin API calls in `src/services/api/admin.ts` if no user-facing code imports them.

- [ ] **Step 1: Write import guard test**

Assert no source imports old admin API module and no route links to `/admin/settings`, `/admin/users`, `/admin/credit-logs`.

- [ ] **Step 2: Delete admin pages**

Remove old user/settings/credit-log admin pages. These functions now live in `admin_front_ts` + `admin_back_go`.

- [ ] **Step 3: Verify**

```powershell
npm run test
npm run typecheck
```

Expected: pass.

---

### Task 12: Docs, live DB, and smoke

**Files:**
- Modify: `docs/status/module-matrix.md`
- Modify: `docs/contracts/admin-api-v1.md`
- Modify: `docs/testing/smoke-matrix.md`

- [ ] **Step 1: Update docs**

Document:

```text
canvas auth platform = canvas
canvas_front_next is a separate frontend
no infinite-canvas backend runtime
wallet/billing reuse admin payment baseline
canvas prompts/assets are the only new canvas business tables
```

- [ ] **Step 2: Run backend verification**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture ./internal/server ./internal/bootstrap ./internal/module/auth/... ./internal/module/payment/... ./internal/module/canvas ./internal/module/ai/billing -count=1
go test ./... -count=1
```

- [ ] **Step 3: Run frontend verification**

```powershell
cd E:\admin_go\canvas_front_next
npm run test
npm run typecheck
npm run build
```

- [ ] **Step 4: Query live DB**

Verify tables and absence of bad tables:

```sql
SHOW TABLES LIKE 'canvas_%';
SHOW TABLES LIKE 'canvas_credit_logs';
SHOW TABLES LIKE 'canvas_settings';
SHOW TABLES LIKE 'canvas_users';
SELECT code,name,status,is_del FROM auth_platforms WHERE code='canvas';
SELECT code,platform,is_del FROM permissions WHERE platform='canvas';
```

Expected:

```text
canvas_prompts and canvas_assets exist
canvas_users/canvas_credit_logs/canvas_settings/canvas_projects do not exist
auth_platforms.canvas exists and active
canvas permissions exist for current capability gates
```

- [ ] **Step 5: Root governance**

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected: no blocking governance violations.

---

## Plan Self-Review

- Spec coverage: auth platform, RBAC, wallet/recharge, billing, Grok provider boundary, prompt/asset tables, Next frontend migration, docs and verification are covered.
- No duplicate money source: no canvas credits table, no original credit logs, no wallet clone.
- No duplicate settings source: no canvas settings/model channel table; AI provider/agent/billing stay in admin.
- No unused project table: `canvas_projects` remains out until cloud sync is explicitly requested.
- TDD path: every backend/frontend slice starts with a failing contract/unit test.
