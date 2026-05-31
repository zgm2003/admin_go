# Canvas Front Next Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 新增 `canvas_front_next`，并把 infinite-canvas 的画布、提示词/素材库、文本/图片/视频生成接入 `admin_go` 的 auth/RBAC/wallet/AI billing 基线。

**Architecture:** `canvas_front_next` 是独立 Next.js 前端；所有安全、钱包、provider、billing、公共库 API 都由 `admin_back_go` 提供 `/api/canvas/v1/*`。当前 Go 后端已经有可复用的 `auth/transport/app` Prefix+Platform 模式、current-user wallet/recharge handlers、以及 `ai_billing_records.platform/provider_task_id`，本计划优先复用这些真实结构，不复制 auth/payment/wallet 业务逻辑。余额唯一事实源是 `user_wallets + wallet_transactions`，AI 扣费唯一审计锚点是 `ai_billing_records(platform=canvas)`。

**Tech Stack:** Go + Gin + GORM + MySQL；Next.js App Router + React + TypeScript + Tailwind + Ant Design；Vitest + Go tests + root governance checker。

---

## Scope Gates

- 只新增 `canvas_front_next`，不把 `E:\GitDownload\infinite-canvas` 后端作为长期 runtime。
- 不新增 `canvas_users`、`canvas_credit_logs`、`canvas_settings`、`canvas_model_channels`、`canvas_projects`。
- 不改已收敛的 admin 支付菜单；canvas 充值复用现有 payment service/current-user 语义，只换 `/api/canvas/v1` 暴露面。
- 不让 canvas 前端保存 provider API key / base_url。
- 不新增 Grok/xAI 配置表；优先复用 `ai_providers(engine_type=openai, driver=openai)`。
- 本轮 **不做 `admin_front_ts` Canvas 提示词/素材 CRUD 页面**；只做 backend admin REST 预留和 canvas public list。后台 UI 另开窄切片，避免把 Next 迁移、Go API、Vue CRUD 三件事混成一锅。

## File Structure Map

### Root docs
- Create: `docs/superpowers/specs/2026-05-31-canvas-front-next-integration-design.md`
- Create: `docs/superpowers/plans/2026-05-31-canvas-front-next-integration.md`
- Modify after implementation: `docs/status/module-matrix.md`, `docs/contracts/admin-api-v1.md`, `docs/testing/smoke-matrix.md`

### Backend: `admin_back_go`
- Create: `database/migrations/20260531_canvas_front_next_integration.sql`
- Create: `internal/architecture/canvas_front_next_integration_test.go`
- Modify: `internal/server/routes_auth.go` to register `authapp.Register(... Prefix: "/api/canvas/v1/auth", Platform: "canvas")`; do **not** create duplicate `auth/transport/canvas` unless the existing Prefix+Platform handler proves insufficient in tests.
- Modify: `internal/middleware/auth_token.go` to add canvas public auth skip paths and default platform for `/api/canvas/v1/*` bearer requests.
- Modify: `internal/bootstrap/app.go` / permission service wiring so allowed platforms include `canvas` in addition to current `admin/app`.
- Create or reuse current-user route files for `GET /api/canvas/v1/users/me`; prefer the existing app current-user pattern over an admin handler call.
- Create: thin canvas route registration for wallet/recharge under `/api/canvas/v1/wallet` and `/api/canvas/v1/payment/recharges`; reuse existing payment/wallet services and current-user handler logic, do not duplicate business code.
- Create: `internal/module/canvas/{dto.go,model.go,repository.go,repository_test.go,service.go,service_test.go}`
- Create: `internal/module/canvas/transport/canvas/{handler.go,request.go,route.go,handler_test.go}` for public settings/prompts/assets/AI generation.
- Optional backend-only admin REST: `internal/module/canvas/transport/admin/{handler.go,request.go,route.go,handler_test.go}` for prompt/asset CRUD API only. Do not add `admin_front_ts` pages in this plan.
- Modify: `internal/server/router.go`, `internal/server/testdata/admin_routes_golden.txt` only if admin REST is actually mounted; modify `internal/bootstrap/route_meta.go` and `internal/bootstrap/route_meta_test.go` only for admin platform write routes.
- Modify/Create i18n: `internal/shared/i18n/locales/{zh-CN,en-US}/canvas.yaml`
- Modify AI infra only if video requires a real non-OpenAI-compatible adapter: `internal/infra/ai/...`

### Frontend: `canvas_front_next`
- Create project from `E:\GitDownload\infinite-canvas\web`, excluding `.next/`, `node_modules/`, `.env*`, `tsconfig.tsbuildinfo`, and generated output/cache files.
- Keep existing `package.json` stack from the source frontend unless a real install/build failure forces a narrow version adjustment; do not run `create-next-app` just to chase newer versions.
- Modify/delete old API clients under `src/services/api/*`
- Delete old admin pages under `src/app/(admin)` from `canvas_front_next`; do not create replacement admin pages in `admin_front_ts` in this plan
- Modify auth/user/config stores under `src/stores/*`
- Modify canvas generation callers under `src/app/(user)/canvas/**`, `src/app/(user)/image/**`, `src/app/(user)/video/**`
- Add tests under `tests/shared/**` or colocated `*.test.ts(x)`

---

### Task 1: Contract tests first, scoped to real runtime files

**Files:**
- Create: `admin_back_go/internal/architecture/canvas_front_next_integration_test.go`
- Create after scaffold: `canvas_front_next/tests/shared/canvas-api-boundary.test.ts`

- [ ] **Step 1: Write backend migration guard test**

Create a Go test that reads only `admin_back_go/database/migrations/20260531_canvas_front_next_integration.sql`. Do not scan docs/spec/plan, because forbidden words intentionally appear there as design constraints.

Required assertions:

```go
migration := readFile(t, "database/migrations/20260531_canvas_front_next_integration.sql")
for _, want := range []string{
  "auth_platforms", "'canvas'", "无限画布",
  "canvas_prompts", "canvas_assets",
  "uk_canvas_prompts_slug", "uk_canvas_assets_slug",
} {
  assertContains(t, migration, want)
}
for _, forbidden := range []string{
  "CREATE TABLE `canvas_users`",
  "CREATE TABLE `canvas_credit_logs`",
  "CREATE TABLE `canvas_settings`",
  "CREATE TABLE `canvas_model_channels`",
  "CREATE TABLE `canvas_projects`",
  "CREATE TABLE `canvas_wallets`",
} {
  assertNotContains(t, migration, forbidden)
}
```

- [ ] **Step 2: Write backend route/config guard test**

Read only runtime Go files, not docs:

```go
routesAuth := readFile(t, "internal/server/routes_auth.go")
authToken := readFile(t, "internal/middleware/auth_token.go")
permissionService := readFile(t, "internal/module/permission/service.go")

assertContains(t, routesAuth, `Prefix:         "/api/canvas/v1/auth"`)
assertContains(t, routesAuth, `Platform:       "canvas"`)
assertContains(t, authToken, `"/api/canvas/v1/auth/login-config"`)
assertContains(t, authToken, `strings.HasPrefix(path, "/api/canvas/v1/")`)
assertContains(t, permissionService, `"canvas"`)
```

Also assert the bad duplicate packages are absent:

```go
assertPathMissing(t, "internal/module/auth/transport/canvas")
```

Only remove this assertion if implementation proves the existing `auth/transport/app` cannot support canvas with Prefix+Platform, and document the proof in the test comment.

- [ ] **Step 3: Write frontend boundary test after `canvas_front_next` exists**

The frontend test must scan only `canvas_front_next/src/**/*.{ts,tsx}` and exclude `tests/`, docs, lockfiles, and generated output. Required checks:

```ts
expect(allSource).toContain('/api/canvas/v1/auth/login')
expect(allSource).toContain('/api/canvas/v1/ai/videos')
expect(allSource).not.toContain('/api/auth/login')
expect(allSource).not.toContain('/api/v1/chat/completions')
expect(allSource).not.toContain('/api/admin/users')
expect(allSource).not.toContain('/api/admin/credit-logs')
expect(allSource).not.toContain('credit_logs')
expect(allSource).not.toMatch(/Authorization:\s*`Bearer \$\{config\.apiKey\}`/)
expect(allSource).not.toContain('allowCustomChannel')
expect(allSource).not.toContain('channelMode === "local"')
```

Do not globally forbid the strings `apiKey` or `baseUrl`; generic HTTP clients and type names may legitimately contain those words. Forbid user-editable provider secret behavior instead.

- [ ] **Step 4: Run RED**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture -run CanvasFrontNextIntegration -count=1
```

Expected: fail because migration/routes/config do not exist yet.

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

Seed platform `canvas` permissions as capability gates, not admin menu nodes:

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

Use `platform='canvas'`. These are for canvas API gate and feature switches, not `admin_front_ts` left-menu routes.

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

- [ ] **Step 5: Run migration guard GREEN only**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture -run CanvasFrontNextIntegration/Migration -count=1
```

Expected: migration subtest passes. Route/config subtests should still fail until Task 3. Do not weaken the route/config tests just to make the whole architecture package green early.

---

### Task 3: Add canvas auth and platform wiring by reusing existing app transport

**Files:**
- Modify: `admin_back_go/internal/server/routes_auth.go`
- Modify: `admin_back_go/internal/middleware/auth_token.go`
- Modify: `admin_back_go/internal/module/permission/service.go` or `admin_back_go/internal/bootstrap/app.go` permission-service construction
- Modify/Create current-user route registration for `GET /api/canvas/v1/users/me` following the existing `/api/app/v1/users/me` pattern
- Test: `admin_back_go/internal/server/router_test.go`
- Test: `admin_back_go/internal/middleware/auth_token_test.go`

- [ ] **Step 1: Write router test for canvas auth reuse**

Add cases beside the existing app-platform tests in `internal/server/router_test.go`:

```text
GET /api/canvas/v1/auth/login-config calls auth service with platform canvas
POST /api/canvas/v1/auth/login issues token with platform canvas and calls user init with platform canvas
GET /api/canvas/v1/users/me authenticates token with platform canvas
POST /api/canvas/v1/auth/logout exists and logs out the bearer token
```

The test should prove `auth/transport/app` Prefix+Platform is reused. It must not require a new `internal/module/auth/transport/canvas` package.

- [ ] **Step 2: Write auth-token middleware tests**

Add cases in `internal/middleware/auth_token_test.go`:

```text
DefaultAuthSkipPaths contains /api/canvas/v1/auth/captcha
DefaultAuthSkipPaths contains /api/canvas/v1/auth/login-config
DefaultAuthSkipPaths contains /api/canvas/v1/auth/send-code
DefaultAuthSkipPaths contains /api/canvas/v1/auth/login
Bearer request to /api/canvas/v1/users/me defaults platform to canvas when platform header is absent
```

- [ ] **Step 3: Register canvas auth with existing app transport**

In `internal/server/routes_auth.go`, add a second `authapp.Register` call:

```go
authapp.Register(router, authapp.RouteOptions{
  Prefix:         "/api/canvas/v1/auth",
  Platform:       "canvas",
  AuthService:    deps.AuthService,
  CaptchaService: deps.CaptchaService,
  UserService:    deps.UserService,
})
```

Do not call admin auth handler from canvas routes.

- [ ] **Step 4: Add canvas auth skip paths and default platform**

In `internal/middleware/auth_token.go`, add public canvas auth endpoints to `DefaultAuthSkipPaths()` and update `defaultPlatformForPath`:

```go
if strings.HasPrefix(path, "/api/canvas/v1/") || path == "/api/canvas/v1" {
  return "canvas"
}
```

- [ ] **Step 5: Allow canvas in permission platform validation**

Current permission service defaults to `admin/app`. Add `canvas` to the allowed platform list at construction or default list, then add a focused test that `BuildContextByRole(..., "canvas")` is accepted and filters `permissions.platform = canvas`.

- [ ] **Step 6: Register `/api/canvas/v1/users/me`**

Follow the existing app current-user route pattern. The handler must call user init/current-user service with `Platform: "canvas"` and reject non-canvas tokens through the platform-bound token authentication path.

- [ ] **Step 7: Verify**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/middleware ./internal/module/permission ./internal/server -run "Canvas|AppPlatform|DefaultAuthSkipPaths|Permission" -count=1
go test ./internal/architecture -run CanvasFrontNextIntegration -count=1
```

Expected: canvas auth/platform guard passes without creating `internal/module/auth/transport/canvas`.

---

### Task 4: Add canvas wallet and recharge routes without duplicating business code

**Files:**
- Create thin route registration under `/api/canvas/v1/wallet` and `/api/canvas/v1/payment/recharges` using existing wallet/payment services
- Prefer extracting shared current-user handler helpers from:
  - `admin_back_go/internal/module/payment/wallet/transport/admin/handler.go`
  - `admin_back_go/internal/module/payment/transport/admin/recharge_handler.go`
- Modify: `admin_back_go/internal/server/router.go` or a new `admin_back_go/internal/server/routes_canvas.go`
- Test: `admin_back_go/internal/server/router_test.go`

- [ ] **Step 1: Write wallet route tests**

Cases:

```text
GET /api/canvas/v1/wallet/summary reads only token user
GET /api/canvas/v1/wallet/transactions forces token user_id
GET /api/canvas/v1/payment/ledger is not mounted
GET /api/canvas/v1/payment/wallets is not mounted
POST /api/canvas/v1/wallet/consumptions is not mounted
```

- [ ] **Step 2: Write recharge route tests**

Cases:

```text
GET /api/canvas/v1/payment/recharges/page-init works for current user
GET /api/canvas/v1/payment/recharges lists only current user recharges
POST /api/canvas/v1/payment/recharges creates current-user recharge
POST /api/canvas/v1/payment/recharges/:id/pay continues pay for current user
POST /api/canvas/v1/payment/recharges/:id/sync is not mounted
PATCH /api/canvas/v1/payment/recharges/:id/close is not mounted
```

- [ ] **Step 3: Implement thin routes**

Reuse existing `wallet.Service` and `payment.Service` interfaces. If code sharing requires extraction, extract only current-user request parsing and response helpers; do not copy ledger/admin wallet management endpoints into canvas.

- [ ] **Step 4: Verify**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/payment ./internal/module/payment/wallet ./internal/server -run "Canvas|Recharge|Wallet" -count=1
```

Expected: canvas wallet/recharge routes pass and retired sync/close/consume/admin-ledger routes remain absent.

---

### Task 5: Add canvas prompt/asset backend module

**Files:**
- Create: `admin_back_go/internal/module/canvas/{dto.go,model.go,repository.go,repository_test.go,service.go,service_test.go}`
- Optional backend-only Create: `admin_back_go/internal/module/canvas/transport/admin/{handler.go,request.go,route.go,handler_test.go}`; do not add Vue admin pages in this plan
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

- [ ] **Step 4: Implement optional backend-only admin REST, not Vue UI**

If this task keeps admin management API in scope, mount only RESTful backend endpoints:

```text
GET    /api/admin/v1/canvas/prompts/page-init
GET    /api/admin/v1/canvas/prompts
POST   /api/admin/v1/canvas/prompts
PUT    /api/admin/v1/canvas/prompts/:id
PATCH  /api/admin/v1/canvas/prompts/:id/status
DELETE /api/admin/v1/canvas/prompts/:id
GET    /api/admin/v1/canvas/assets/page-init
GET    /api/admin/v1/canvas/assets
POST   /api/admin/v1/canvas/assets
PUT    /api/admin/v1/canvas/assets/:id
PATCH  /api/admin/v1/canvas/assets/:id/status
DELETE /api/admin/v1/canvas/assets/:id
```

These are `platform='admin'` management permissions, for example `canvas_prompt_list/edit` and `canvas_asset_list/edit`; they are separate from `platform='canvas'` user capability gates. Do not seed an admin left-menu or add `admin_front_ts` pages in this plan. If product wants the Vue CRUD UI now, split a new plan that includes `Search + AppTable + AppDialog + useCrudTable`, route metadata, admin menu migration, zh-CN/en-US locale entries, and frontend tests.

- [ ] **Step 5: Implement canvas public REST**

```text
GET /api/canvas/v1/prompts
GET /api/canvas/v1/assets
```

- [ ] **Step 6: Verify**

```powershell
go test ./internal/module/canvas ./internal/module/canvas/transport/canvas ./internal/server -count=1
# If optional backend admin REST was added, also run:
go test ./internal/module/canvas/transport/admin ./internal/bootstrap -count=1
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

- [ ] **Step 3: Implement video task binding and ownership contract**

Use `ai_billing_records.id` as the first-pass `:id` for:

```text
GET /api/canvas/v1/ai/videos/:id
GET /api/canvas/v1/ai/videos/:id/content
```

Every read must query by `id + user_id + platform='canvas' + scene='canvas_video_generate'`; never trust provider task ID or request query fields for ownership. Bind provider task ID to `ai_billing_records.provider_task_id` after provider create succeeds. Do not create `canvas_video_tasks` unless tests prove `ai_billing_records` cannot store the required state.

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
$src = 'E:/GitDownload/infinite-canvas/web'
$dst = 'E:/admin_go/canvas_front_next'
robocopy $src $dst /E /XD node_modules .next dist out coverage /XF .env .env.local .env.production tsconfig.tsbuildinfo package-lock.json npm-debug.log yarn-error.log
if ($LASTEXITCODE -le 7) { $global:LASTEXITCODE = 0 }
```

Do not copy Go backend, `.env*` secrets, `.next`, `node_modules`, build output, caches, or old admin runtime state. Keep the existing source frontend package versions unless install/build proves a narrow change is necessary.

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
- Modify UI components that render credits/API key/base URL, especially `src/components/layout/app-config-modal.tsx`, `src/components/layout/user-status-actions.tsx`, and canvas prompt/config panels found by `rg "credits|apiKey|baseUrl|channelMode" canvas_front_next/src`.

- [ ] **Step 1: Replace auth endpoints**

Use:

```text
/api/canvas/v1/auth/login
/api/canvas/v1/users/me
/api/canvas/v1/auth/login-config
/api/canvas/v1/auth/captcha
/api/canvas/v1/auth/send-code
```

Do not create or call `/api/canvas/v1/auth/register`. Canvas login UI must read `login-config`, render the returned email/phone/password login-type tabs, call `/api/canvas/v1/auth/send-code` for code login, and open slide captcha only after password-login submit; `allow_register` only controls code-login auto-registration.

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
- If optional backend admin REST is skipped, explicitly document that Canvas prompt/asset admin UI is a future narrow slice, not implemented.

- [ ] **Step 1: Update docs**

Document:

```text
canvas auth platform = canvas
canvas_front_next is a separate frontend
no infinite-canvas backend runtime
wallet/billing reuse admin payment baseline
canvas prompts/assets are the only new canvas business tables
canvas auth reuses existing auth/transport/app Prefix+Platform pattern
admin_front_ts Canvas CRUD UI is not part of this implementation unless a separate plan is created
```

- [ ] **Step 2: Run backend verification**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture ./internal/middleware ./internal/server ./internal/bootstrap ./internal/module/auth/... ./internal/module/permission ./internal/module/payment/... ./internal/module/canvas ./internal/module/ai/billing -count=1
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
SHOW TABLES LIKE 'canvas_projects';
SHOW TABLES LIKE 'canvas_wallets';
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

- Spec coverage: auth platform, RBAC, wallet/recharge, billing, Grok provider boundary, prompt/asset tables, Next frontend migration, docs and verification are covered. Admin Vue CRUD is deliberately excluded from this plan and must be handled by a separate frontend-adapter slice if needed.
- No duplicate money source: no canvas credits table, no original credit logs, no wallet clone.
- No duplicate settings source: no canvas settings/model channel table; AI provider/agent/billing stay in admin.
- No unused project table: `canvas_projects` remains out until cloud sync is explicitly requested.
- TDD path: every backend/frontend slice starts with a failing contract/unit test.


---

## Execution status snapshot (2026-05-31)

Current code progress:

- Implemented backend canvas auth/platform wiring, current-user profile route, wallet/recharge thin routes, public settings/prompts/assets, and AI text/image/video routes.
- Implemented `canvas_front_next` as an independent Next.js repo on branch `master` with origin `https://github.com/zgm2003/canvas_front_next.git`.
- Removed old admin UI and local/custom provider API-key channel behavior from `canvas_front_next`; frontend generation clients now call `/api/canvas/v1/*`.
- Implemented backend-managed Canvas text generation and OpenAI-compatible video create/status/content adapter. Video uses `ai_billing_records.id` as canvas task id and binds upstream task id to `ai_billing_records.provider_task_id`.
- The only new canvas business tables in the migration are `canvas_prompts` and `canvas_assets`.

Verified:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/infra/ai ./internal/infra/ai/openaicompat ./internal/module/canvas ./internal/module/canvas/transport/canvas ./internal/server ./internal/bootstrap -count=1
go test ./... -count=1
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account 15671628271 -Password 123456

cd E:\admin_go\canvas_front_next
npm run test
npm run typecheck
npm run build

cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Live DB query result:

- existing canvas business tables: `canvas_assets`, `canvas_prompts`
- absent duplicate tables: `canvas_credit_logs`, `canvas_settings`, `canvas_users`, `canvas_projects`, `canvas_wallets`
- `auth_platforms.canvas` is active, and the expected canvas capability permissions exist.

Final user report must explicitly list newly added tables.
