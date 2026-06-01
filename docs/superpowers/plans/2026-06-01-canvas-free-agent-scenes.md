# Canvas Free Agent Scenes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 Canvas 文本/图片/视频生成改成免费运行时，并把可用模型来源收敛到智能体上的三个 Canvas 专属场景。

**Architecture:** 删除 AI billing 主动运行链路和活跃表；`ai_agents.scenes_json` 新增 `canvas_text_generate` / `canvas_video_generate` / `canvas_image_generate`；Canvas settings 只从这些场景取 agent；视频使用新的 `canvas_video_tasks` 保存异步任务事实。支付/钱包基础域保留，但 Canvas 前端不再展示收费入口。

**Tech Stack:** Go + Gin + GORM + MySQL migrations；Vue 3 + TypeScript；Next.js + React + Vitest。

---

## File map

Root docs：

- Create: `docs/superpowers/specs/2026-06-01-canvas-free-agent-scenes-design.md`
- Create: `docs/superpowers/plans/2026-06-01-canvas-free-agent-scenes.md`
- Modify during implementation: `docs/contracts/admin-api-v1.md`
- Modify during implementation: `docs/status/current-status.md`
- Modify during implementation: `docs/status/module-matrix.md`
- Modify during implementation: `docs/testing/smoke-matrix.md`

Backend：

- Create: `admin_back_go/database/migrations/20260601_canvas_free_agent_scenes.sql`
- Create: `admin_back_go/internal/architecture/canvas_free_agent_scenes_test.go`
- Modify: `admin_back_go/internal/module/ai/agent/service.go`
- Modify: `admin_back_go/internal/module/ai/agent/service_test.go`
- Modify: `admin_back_go/internal/module/ai/image/dto.go`
- Modify: `admin_back_go/internal/module/ai/image/model.go`
- Modify: `admin_back_go/internal/module/ai/image/service.go`
- Modify: `admin_back_go/internal/module/ai/image/service_test.go`
- Modify: `admin_back_go/internal/module/canvas/dto.go`
- Modify: `admin_back_go/internal/module/canvas/model.go`
- Modify: `admin_back_go/internal/module/canvas/repository.go`
- Modify: `admin_back_go/internal/module/canvas/video_repository.go`
- Modify: `admin_back_go/internal/module/canvas/service.go`
- Modify: `admin_back_go/internal/module/canvas/service_test.go`
- Modify: `admin_back_go/internal/module/canvas/text_runtime.go`
- Modify: `admin_back_go/internal/module/canvas/text_runtime_test.go`
- Modify: `admin_back_go/internal/module/canvas/video_runtime.go`
- Modify: `admin_back_go/internal/module/canvas/video_runtime_test.go`
- Modify: `admin_back_go/internal/module/canvas/transport/canvas/handler_test.go`
- Modify: `admin_back_go/internal/bootstrap/app.go`
- Modify: `admin_back_go/internal/bootstrap/route_meta.go`
- Modify: `admin_back_go/internal/bootstrap/route_meta_test.go`
- Modify: `admin_back_go/internal/server/router.go`
- Modify: `admin_back_go/internal/server/routes_admin_ai.go`
- Modify: `admin_back_go/internal/server/router_test.go`
- Delete: `admin_back_go/internal/module/ai/billing/**`
- Delete: `admin_back_go/internal/shared/i18n/locales/zh-CN/aibilling.yaml`
- Delete: `admin_back_go/internal/shared/i18n/locales/en-US/aibilling.yaml`

Canvas Next：

- Create: `canvas_front_next/tests/shared/canvas-free-generation.test.ts`
- Modify: `canvas_front_next/src/services/api/settings.ts`
- Modify: `canvas_front_next/src/stores/use-config-store.ts`
- Modify: `canvas_front_next/src/stores/use-config-store.test.ts`
- Modify: `canvas_front_next/src/components/layout/app-config-modal.tsx`
- Modify: `canvas_front_next/src/components/layout/user-status-actions.tsx`
- Modify: `canvas_front_next/src/features/rbac/canvas-permissions.ts`
- Modify: `canvas_front_next/src/app/(user)/canvas/components/canvas-assistant-panel.tsx`
- Modify: `canvas_front_next/src/app/(user)/canvas/components/canvas-config-node-panel.tsx`
- Modify: `canvas_front_next/src/app/(user)/canvas/components/canvas-node-prompt-panel.tsx`
- Delete if unused: `canvas_front_next/src/constant/wallet.tsx`
- Delete from Canvas UI: `canvas_front_next/src/app/(user)/wallet/page.tsx`
- Delete from Canvas UI: `canvas_front_next/src/app/(user)/recharge/page.tsx`

Admin Vue：

- Create: `admin_front_ts/tests/shared/ai/ai-agent-scenes-free.test.ts`
- Modify: `admin_front_ts/src/api/ai/agents.ts`
- Modify: `admin_front_ts/src/views/Main/ai/agents/index.vue`
- Modify: `admin_front_ts/src/i18n/locales/zh-CN.ts`
- Modify: `admin_front_ts/src/i18n/locales/en-US.ts`
- Delete: `admin_front_ts/src/api/ai/billingRules.ts`
- Delete: `admin_front_ts/src/views/Main/ai/agents/components/AgentBillingDialog/index.vue`
- Delete: `admin_front_ts/tests/shared/ai/ai-billing-rule-api.test.ts`

---

## Task 0: Dirty workspace guard

- [ ] Run:

```powershell
cd E:\admin_go
git status --short --branch
git -C admin_back_go status --short --branch
git -C canvas_front_next status --short --branch
git -C admin_front_ts status --short --branch
```

Expected: there may be existing dirty Canvas agent-selector changes. Do not reset or overwrite them.

---

## Task 1: Add Canvas-specific AI agent scenes

- [ ] Add backend test in `admin_back_go/internal/module/ai/agent/service_test.go`:

```go
func TestPageInitIncludesCanvasAgentScenes(t *testing.T) {
	service := NewService(&fakeRepository{}, nil, nil)
	result, appErr := service.PageInit(context.Background())
	if appErr != nil {
		t.Fatalf("PageInit returned error: %#v", appErr)
	}
	values := map[string]string{}
	for _, item := range result.Dict.SceneArr {
		values[item.Value] = item.Label
	}
	expected := map[string]string{
		"chat":                  "对话",
		"agent_generate":        "智能体生成",
		"image_generate":        "图片生成",
		"canvas_text_generate":  "无限画布-文本",
		"canvas_video_generate": "无限画布-视频",
		"canvas_image_generate": "无限画布-图片",
	}
	for value, label := range expected {
		if values[value] != label {
			t.Fatalf("scene %s label=%q want=%q all=%#v", value, values[value], label, result.Dict.SceneArr)
		}
	}
}
```

- [ ] Confirm RED:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/ai/agent -run TestPageInitIncludesCanvasAgentScenes -count=1
```

- [ ] In `admin_back_go/internal/module/ai/agent/service.go`, add constants and labels:

```go
const (
	sceneChat                = "chat"
	sceneAgentGenerate       = "agent_generate"
	sceneImageGenerate       = "image_generate"
	sceneCanvasTextGenerate  = "canvas_text_generate"
	sceneCanvasVideoGenerate = "canvas_video_generate"
	sceneCanvasImageGenerate = "canvas_image_generate"
)
```

Use labels `无限画布-文本` / `无限画布-视频` / `无限画布-图片` and return all six scene options.

- [ ] Update `admin_front_ts/src/api/ai/agents.ts`:

```ts
export type AiAgentScene =
  | 'chat'
  | 'agent_generate'
  | 'image_generate'
  | 'canvas_text_generate'
  | 'canvas_video_generate'
  | 'canvas_image_generate'
```

- [ ] Update Admin Vue locale scene labels in both `zh-CN.ts` and `en-US.ts`.

- [ ] Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/ai/agent -count=1
```

Expected: PASS.

---

## Task 2: Create migration and architecture guard

- [ ] Create `admin_back_go/internal/architecture/canvas_free_agent_scenes_test.go` that asserts:
  - active backend source does not import `internal/module/ai/billing`
  - active backend source does not contain `aibilling.`, `Charge(`, `Refund(`, `MarkSuccess(` in Canvas/image runtime files
  - migration contains `CREATE TABLE IF NOT EXISTS \`canvas_video_tasks\``
  - migration contains `DROP TABLE IF EXISTS \`ai_billing_records\`` and `DROP TABLE IF EXISTS \`ai_billing_rules\``
  - migration drops `ai_image_tasks.billing_record_id`
  - migration does not blindly append `canvas_video_generate` to existing agents

- [ ] Confirm RED:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture -run TestCanvasFreeGeneration -count=1
```

- [ ] Create `admin_back_go/database/migrations/20260601_canvas_free_agent_scenes.sql` with:

```sql
CREATE TABLE IF NOT EXISTS `canvas_video_tasks` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` BIGINT UNSIGNED NOT NULL,
  `agent_id` BIGINT UNSIGNED NOT NULL,
  `provider_id` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `model_id` VARCHAR(191) NOT NULL DEFAULT '',
  `prompt` TEXT NOT NULL,
  `duration_seconds` INT NOT NULL DEFAULT 0,
  `size` VARCHAR(64) NOT NULL DEFAULT '',
  `resolution_name` VARCHAR(64) NOT NULL DEFAULT '',
  `provider_task_id` VARCHAR(191) NOT NULL DEFAULT '',
  `status` VARCHAR(32) NOT NULL DEFAULT 'pending',
  `error_message` VARCHAR(1024) NOT NULL DEFAULT '',
  `is_del` TINYINT NOT NULL DEFAULT 2,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `finished_at` DATETIME NULL,
  PRIMARY KEY (`id`),
  KEY `idx_canvas_video_tasks_user_status` (`user_id`, `status`, `is_del`, `created_at`, `id`),
  KEY `idx_canvas_video_tasks_provider_task` (`provider_id`, `provider_task_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='无限画布视频生成任务';

UPDATE `ai_agents`
SET `scenes_json` = JSON_ARRAY_APPEND(CAST(`scenes_json` AS JSON), '$', 'canvas_text_generate'),
    `updated_at` = NOW()
WHERE `is_del` = 2
  AND JSON_VALID(`scenes_json`)
  AND JSON_CONTAINS(CAST(`scenes_json` AS JSON), JSON_QUOTE('chat'))
  AND NOT JSON_CONTAINS(CAST(`scenes_json` AS JSON), JSON_QUOTE('canvas_text_generate'));

UPDATE `ai_agents`
SET `scenes_json` = JSON_ARRAY_APPEND(CAST(`scenes_json` AS JSON), '$', 'canvas_image_generate'),
    `updated_at` = NOW()
WHERE `is_del` = 2
  AND JSON_VALID(`scenes_json`)
  AND JSON_CONTAINS(CAST(`scenes_json` AS JSON), JSON_QUOTE('image_generate'))
  AND NOT JSON_CONTAINS(CAST(`scenes_json` AS JSON), JSON_QUOTE('canvas_image_generate'));
```

Then add prepared-statement checks to drop `idx_ai_image_tasks_billing_record_id`, drop column `ai_image_tasks.billing_record_id`, soft-delete `ai_billing_rule_edit`, and drop `ai_billing_records` / `ai_billing_rules`.

Do not auto-append `canvas_video_generate`.

---

## Task 3: Remove backend AI billing runtime

- [ ] Remove `aibilling` construction and dependency injection from `admin_back_go/internal/bootstrap/app.go`.
- [ ] Remove `AiBillingService` from `admin_back_go/internal/server/router.go`.
- [ ] Remove `aibillingadmin.Register(...)` from `admin_back_go/internal/server/routes_admin_ai.go`.
- [ ] Remove `/api/admin/v1/ai-billing-rules*` entries from `route_meta.go` and matching tests.
- [ ] Delete `admin_back_go/internal/module/ai/billing/**` and `aibilling.yaml` locale files.

Run:

```powershell
cd E:\admin_go\admin_back_go
rg -n "aibilling|ai_billing|/ai-billing-rules|AiBillingService" internal
```

Expected: no active backend source matches, except failing tests being updated in this task.

---

## Task 4: Make image/text generation free

- [ ] In `admin_back_go/internal/module/ai/image/dto.go`, remove `BillingService`, `Billing` dependency, and `BillingScene` input.
- [ ] In `admin_back_go/internal/module/ai/image/model.go`, remove `BillingRecordID`.
- [ ] In `admin_back_go/internal/module/ai/image/service.go`, remove charge/refund/mark-success functions and calls.
- [ ] Change image scene validation:
  - admin/default platform requires `image_generate`
  - `platform=canvas` requires `canvas_image_generate`
- [ ] In `admin_back_go/internal/module/canvas/text_runtime.go`, remove billing dependency and Charge/Refund/MarkSuccess calls.
- [ ] Change text scene validation from `chat` to `canvas_text_generate`.
- [ ] Update tests in `ai/image` and `canvas` so no fake billing service exists.

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/ai/image ./internal/module/canvas -count=1
```

Expected: PASS.

---

## Task 5: Move Canvas video task identity to `canvas_video_tasks`

- [ ] Add `VideoTask` model in `admin_back_go/internal/module/canvas/model.go`.
- [ ] In `dto.go`, replace `VideoStatusInput.BillingRecord` and `VideoContentInput.BillingRecord` with `Task *VideoTask`.
- [ ] Add repository methods:
  - `CreateVideoTask(ctx, task) (int64, error)`
  - `UpdateVideoTask(ctx, userID, id, fields) error`
  - `GetVideoTask(ctx, userID, id) (*VideoTask, error)`
- [ ] In `video_runtime.go`, replace `engineForRecord` with `engineForTask`, use `task.ProviderTaskID`, and require `canvas_video_generate`.
- [ ] In `service.go`, replace `canvasVideoRecord` with task lookup by `id + user_id + is_del=2`.
- [ ] `GenerateVideo` flow:
  1. create pending `canvas_video_tasks` row
  2. call provider
  3. update provider_task_id/provider_id/model_id/status
  4. return `canvas_video_tasks.id`
  5. on provider failure, mark task failed and return provider error
- [ ] `VideoStatus` and `VideoContent` load task, call provider, update task status/finished_at.

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/canvas -run "TestGenerateVideo|TestVideoStatus|TestVideoContent|TestVideoRuntime" -count=1
```

Expected: PASS.

---

## Task 6: Update Canvas settings contract

- [ ] In `admin_back_go/internal/module/canvas/dto.go`, remove `Billing []BillingRule` and delete `BillingRule` if unused.
- [ ] In `service.go`, define local constants:

```go
const (
	canvasTextAgentScene  = "canvas_text_generate"
	canvasImageAgentScene = "canvas_image_generate"
	canvasVideoAgentScene = "canvas_video_generate"
)
```

- [ ] `PublicSettings` returns `allow_register`, `scenes`, and `agents`; no billing lookup.
- [ ] `canvasAgentGroups` queries text/image/video separately; do not copy image agents into video.
- [ ] Update settings tests to assert response JSON does not contain `"billing"`.

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/canvas -run "TestPublicSettings|TestSettings" -count=1
```

Expected: PASS.

---

## Task 7: Remove frontend billing concepts

Canvas Next：

- [ ] Add `canvas_front_next/tests/shared/canvas-free-generation.test.ts` asserting active source does not contain:
  - `billingCostText`
  - `WalletSymbol`
  - `publicSettings?.billing`
  - `算力`
  - `余额`
  - `充值`
  - `扣费`
  - `收费`
  - `单价`
  - `费用`
- [ ] Remove `CanvasBillingRule` and `billing` from `src/services/api/settings.ts`.
- [ ] Remove cost calculation/display from Canvas assistant/config/prompt panels.
- [ ] Remove balance badge and wallet/recharge menu from `user-status-actions.tsx`.
- [ ] Replace app config modal wording “扣费和审计” with “由已启用智能体决定模型和 Provider 调度”。
- [ ] Delete wallet/recharge pages from Canvas UI; old AI billing is globally retired and Canvas is free.

Admin Vue：

- [ ] Add `admin_front_ts/tests/shared/ai/ai-agent-scenes-free.test.ts`.
- [ ] Remove `AgentBillingDialog` import/state/button/mount from `src/views/Main/ai/agents/index.vue`.
- [ ] Delete `src/api/ai/billingRules.ts`.
- [ ] Delete `src/views/Main/ai/agents/components/AgentBillingDialog/index.vue`.
- [ ] Delete `tests/shared/ai/ai-billing-rule-api.test.ts`.
- [ ] Remove `aiBilling` locale objects.

Run:

```powershell
cd E:\admin_go\canvas_front_next
npm run test -- tests/shared/canvas-free-generation.test.ts tests/shared/canvas-api-boundary.test.ts src/stores/use-config-store.test.ts
npm run typecheck

cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/ai/ai-agent-scenes-free.test.ts
npm run typecheck
```

Expected: PASS.

---

## Task 8: Update docs and smoke matrix

- [ ] `docs/contracts/admin-api-v1.md`:
  - Canvas settings no longer exposes billing rules
  - Canvas agent option scene values are the three `canvas_*` scenes
  - video task id is `canvas_video_tasks.id`
  - AI billing rules section is retired; no active `/api/admin/v1/ai-billing-rules`
- [ ] `docs/status/current-status.md` and `docs/status/module-matrix.md`:
  - replace `ai_billing_records(platform=canvas)` claims
  - record free runtime and video task table
  - do not claim live DB migration applied until verified
- [ ] `docs/testing/smoke-matrix.md`:
  - remove AI billing rules read smoke
  - add ai-agent page-init scene assertions for the three Canvas scenes
  - Canvas live generation fixtures require provider/agent, not billing/wallet

Run:

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected: PASS.

---

## Task 9: Final verification

- [ ] Backend:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture ./internal/module/ai/agent ./internal/module/ai/image ./internal/module/canvas ./internal/server ./internal/bootstrap -count=1
go test ./... -count=1
go vet ./...
```

- [ ] Canvas Next:

```powershell
cd E:\admin_go\canvas_front_next
npm run test
npm run typecheck
npm run build
```

- [ ] Admin Vue:

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/ai/ai-agent-scenes-free.test.ts
npm run typecheck
```

- [ ] Root governance:

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

- [ ] Live DB:

```sql
SHOW TABLES LIKE 'ai_billing_rules';
SHOW TABLES LIKE 'ai_billing_records';
SHOW COLUMNS FROM ai_image_tasks LIKE 'billing_record_id';
SHOW TABLES LIKE 'canvas_video_tasks';
```

Expected: all commands PASS; AI billing tables/column are gone; `canvas_video_tasks` exists.

## Self-review

- Spec coverage: scene additions, free generation, billing deletion, video task replacement, frontend cleanup, docs and verification covered.
- Data structure: only video gets a new task table.
- Compatibility: admin chat/tool/image scenes remain; payment/wallet base domain remains; Canvas AI paths remain.
- No placeholders: every task has exact files, commands, and expected outcomes.
