# Canvas 免费生成与智能体场景设计规格

状态：approved-for-implementation
日期：2026-06-01
主角色：architect
范围：`admin_back_go` + `canvas_front_next` + `admin_front_ts` + root docs

## 需求分析

【需求判断】

是真问题。当前 Canvas 已经走后端托管 provider，但仍把 AI 生成和 `ai_billing_rules` / `ai_billing_records` / 钱包扣费绑在一起；同时 Canvas 文本、图片、视频可选模型来自通用场景或计费场景，而不是来自智能体上的 Canvas 专属场景。用户已明确确认要全局删除旧 AI billing；本切片不是保留计费兼容层，而是把运行时模型选择和旧收费体系彻底拆开。

【核心问题】

1. 智能体新增三个 Canvas 专属运行场景：
   - `canvas_text_generate`：无限画布-文本
   - `canvas_video_generate`：无限画布-视频
   - `canvas_image_generate`：无限画布-图片
2. Canvas text/image/video 只从对应 `ai_agents.scenes_json` 场景取 agent、model、provider。
3. AI 生成免费：不扣费、不退款、不查余额、不展示单价/余额/充值/算力点。
4. 删除当前 AI billing 活跃运行链路和活跃表。

【复杂度检查】

只隐藏前端价格是坏修复，因为后端仍会 Charge/Refund，视频仍会借 `ai_billing_records.id` 当 task id，失败仍可能冒出“余额不足”。正确做法是把 AI billing 从生成路径里删掉。

也不需要新建泛化的 `canvas_generation_tasks`。当前只有视频异步状态依赖 billing record；图片已有 `ai_image_tasks`，文本同步返回。最小正确结构是新增 `canvas_video_tasks`。

【破坏性分析】

预期删除/退休：

- `ai_billing_rules`
- `ai_billing_records`
- `ai_image_tasks.billing_record_id`
- `/api/admin/v1/ai-billing-rules*`
- `ai_billing_rule_edit`
- Admin Vue 的 `AgentBillingDialog` / `AiBillingRuleApi`
- Canvas Next 的余额、充值、费用、算力点、扣费文案和钱包/充值入口

不能破坏：

- Admin AI 对话继续使用 `chat`
- Admin 工具生成继续使用 `agent_generate`
- Admin 图片工作台继续使用 `image_generate`，但不再扣费
- Canvas AI API 路径保持不变
- 支付/钱包/充值基础域不在本切片删除；它们保留给非 AI 生成能力和未来会员时间制模型

## 代码分析

【数据结构】

### 智能体场景

`ai_agents.scenes_json` 新增：

| 内部值 | 展示名 | 用途 |
| --- | --- | --- |
| `canvas_text_generate` | 无限画布-文本 | Canvas 文本生成 |
| `canvas_video_generate` | 无限画布-视频 | Canvas 视频生成 |
| `canvas_image_generate` | 无限画布-图片 | Canvas 图片生成 |

现有 `chat`、`agent_generate`、`image_generate` 保留，分别服务 Admin 对话、工具生成、Admin 图片工作台。Canvas 不再复用 `chat` 或 `image_generate`。

### 视频任务表

新增 `canvas_video_tasks`，替代 `ai_billing_records` 的任务身份职责：

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
```

不加金额、单价、套餐、余额、通用 payload、原始大响应。每个字段都要服务任务状态、所有权校验、provider 查询或排障。

【特殊情况】

旧特殊情况：

1. Canvas `settings.scenes` 是 billing scenes，却被前端误当模型来源。
2. Canvas video 没有任务表，所以借用 billing record。
3. 成功/失败后有 MarkSuccess/Refund，这只服务收费，不服务生成。

新设计消灭这些特殊情况：

- settings 的模型来源只有 `agents.text|image|video`
- video status/content 只读 `canvas_video_tasks`
- 生成失败只返回 provider/runtime 错误，不再出现退款二次错误

【复杂度】

运行时保持三条简单路径：

- Text：校验 `canvas_text_generate` 智能体 -> 调 provider -> 返回文本
- Image：校验 `canvas_image_generate` 智能体 -> 创建 `ai_image_tasks` -> worker 生成
- Video：校验 `canvas_video_generate` 智能体 -> 创建 `canvas_video_tasks` -> 调 provider -> status/content 查任务表

【兼容性】

- Canvas 前后端同步升级，移除 Canvas UI 的 wallet/recharge/cost 展示和入口。
- Admin payment/wallet 基础域暂不删除，避免误伤充值支付域。
- 历史 `wallet_transactions` 中 AI source type 不在本切片清洗；新生成不再写入。
- 现有 agent 不自动获得 `canvas_video_generate`，因为图片模型不等于视频模型能力；视频要人工绑定新场景。
- 迁移可自动给已有 `chat` agent 追加 `canvas_text_generate`，给已有 `image_generate` agent 追加 `canvas_image_generate`，但不自动追加视频场景。

【结论】

值得做。正确边界是：删掉 AI billing 主动运行链路，把 Canvas 模型选择收敛到智能体场景，把视频任务从 billing record 迁到自己的任务表。

## 目标行为

1. Admin 智能体场景下拉包含 `canvas_text_generate`、`canvas_video_generate`、`canvas_image_generate`。
2. `/api/canvas/v1/settings` 的 `agents.text` 只查 `canvas_text_generate`，`agents.video` 只查 `canvas_video_generate`，`agents.image` 只查 `canvas_image_generate`。
3. Canvas AI 请求继续只提交 `agent_id`；provider/model 仍由后端从智能体读取。
4. Text/image/video 生成不调用 Charge/Refund/MarkSuccess，不会余额不足。
5. Admin 图片工作台不要求 AI billing rule，不写 `ai_billing_records`。
6. Canvas video create 返回 `canvas_video_tasks.id`。
7. Canvas Next 不显示算力点、余额、充值、单价、费用、扣费、收费、钱包入口。
8. Admin Vue 不显示 AI Billing Rules / AI计费规则入口。

## 非目标

- 不删除 `payment_orders`、`payment_recharges`、`user_wallets`、`wallet_transactions`。
- 不新增 `canvas_users`、`canvas_wallets`、`canvas_credit_logs`、`canvas_settings`。
- 不做免费额度、会员、订阅、套餐、限流计费；未来会员按时间无限用是新模型，不在旧 AI billing 删除切片实现。
- 不改名旧 `chat` / `agent_generate` / `image_generate`。

## 验证标准

Backend：

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture ./internal/module/ai/agent ./internal/module/ai/image ./internal/module/canvas ./internal/server ./internal/bootstrap -count=1
go test ./... -count=1
go vet ./...
```

Frontend：

```powershell
cd E:\admin_go\canvas_front_next
npm run test
npm run typecheck
npm run build

cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/ai/ai-agent-scenes-free.test.ts
npm run typecheck
```

Root：

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

DB：

```sql
SHOW TABLES LIKE 'ai_billing_rules';
SHOW TABLES LIKE 'ai_billing_records';
SHOW COLUMNS FROM ai_image_tasks LIKE 'billing_record_id';
SHOW TABLES LIKE 'canvas_video_tasks';
SELECT id, name, scenes_json
FROM ai_agents
WHERE JSON_CONTAINS(scenes_json, JSON_QUOTE('canvas_text_generate'))
   OR JSON_CONTAINS(scenes_json, JSON_QUOTE('canvas_image_generate'))
   OR JSON_CONTAINS(scenes_json, JSON_QUOTE('canvas_video_generate'));
```

期望：AI billing 表/列不存在，`canvas_video_tasks` 存在，文本/图片 Canvas 场景能筛到 agent；视频 agent 由人工绑定决定。

## Spec 自检

- 没把 `scenes` 继续定义成 billing scenes。
- 没把 `image_generate` 继续复用成 Canvas 视频场景。
- 没新增过度泛化任务表。
- 没删除全局 payment/wallet 基础域，只删除旧 AI billing。
- 没用余额不足兜底掩盖免费生成路径错误。
