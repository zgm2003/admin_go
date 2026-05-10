# AI Run Monitor MVP Design

> 目标：把“运行监控”从旧的半残留结构收口成可入库、可查询、可统计 token 的最小闭环。只统计 token，不计费，不做工具/RAG，不把流式 delta 打进 MySQL。

## 1. Linus 三问

1. 这是真问题吗？
   - 是。对话已经落在 `ai_conversations` / `ai_messages`，但运行监控当前只有旧 `ai_runs` 残表，字段和代码不一致，助手回复也没有稳定写 run 记录。
2. 有更简单的方法吗？
   - 有。只保留 `ai_runs` 和 `ai_run_events`。`ai_runs` 记录一轮回复的最终状态和 token；`ai_run_events` 记录 start/completed/failed/canceled/timeout 时间线。
3. 会破坏什么吗？
   - 会重建当前 0 行 `ai_runs`。live DB 已确认 `ai_runs` 为 0 行；`ai_run_events` 原本不存在。所以这是干净切换，不破坏用户对话消息。

## 2. 范围

### In

- 每次 `POST /api/admin/v1/ai-conversations/:id/messages` 入队回复后，运行执行器创建一条 `ai_runs`。
- 成功时写入 `assistant_message_id`、token、耗时、`status=success`。
- 失败时写入 `status=failed` 和错误信息。
- 用户停止时写入 `status=canceled`。
- 超时 worker 写入 `status=timeout`。
- 运行监控列表、详情、统计按新字段读取。
- 前端运行监控页只展示运行、状态、token、耗时、错误和事件。

### Out

- 不计费，不保留 `cost`。
- 不保留 `usage_json`、`meta_json`、`input_snapshot_json`、`output_snapshot_json`。
- 不保留 provider 任务 ID：`engine_task_id`、`engine_run_id`。
- 不做 `ai_usage_daily` 聚合表。
- 不记录每个 WebSocket delta 到 `ai_run_events`。
- 不做 tool / RAG / run steps。

## 3. 表设计

### `ai_runs`

```sql
CREATE TABLE `ai_runs` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT COMMENT '运行ID',
  `conversation_id` int unsigned NOT NULL COMMENT 'ai_conversations.id',
  `request_id` varchar(64) NOT NULL COMMENT '客户端本轮请求ID',
  `user_message_id` bigint unsigned NOT NULL COMMENT '本轮用户消息ID',
  `assistant_message_id` bigint unsigned NULL DEFAULT NULL COMMENT '完成后写入的助手消息ID',
  `user_id` int unsigned NOT NULL COMMENT '发起用户ID',
  `agent_id` bigint unsigned NOT NULL COMMENT 'ai_agents.id',
  `provider_id` bigint unsigned NOT NULL COMMENT 'ai_providers.id',
  `model_id` varchar(191) NOT NULL COMMENT '实际调用模型ID',
  `model_display_name` varchar(191) NOT NULL DEFAULT '' COMMENT '实际调用模型展示名',
  `status` varchar(16) NOT NULL COMMENT 'running/success/failed/canceled/timeout',
  `prompt_tokens` int unsigned NOT NULL DEFAULT 0 COMMENT '输入token',
  `completion_tokens` int unsigned NOT NULL DEFAULT 0 COMMENT '输出token',
  `total_tokens` int unsigned NOT NULL DEFAULT 0 COMMENT '总token',
  `duration_ms` int unsigned NULL DEFAULT NULL COMMENT '运行耗时毫秒，终态后写入',
  `error_message` varchar(1024) NOT NULL DEFAULT '' COMMENT '失败/取消/超时原因',
  `started_at` datetime NULL DEFAULT NULL COMMENT '开始调用模型时间',
  `finished_at` datetime NULL DEFAULT NULL COMMENT '进入终态时间',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_ai_runs_conversation_request` (`conversation_id`, `request_id`),
  UNIQUE KEY `uk_ai_runs_user_message` (`user_message_id`),
  KEY `idx_ai_runs_created` (`created_at`, `id`),
  KEY `idx_ai_runs_status_created` (`status`, `created_at`, `id`),
  KEY `idx_ai_runs_user_created` (`user_id`, `created_at`, `id`),
  KEY `idx_ai_runs_agent_created` (`agent_id`, `created_at`, `id`),
  KEY `idx_ai_runs_provider_created` (`provider_id`, `created_at`, `id`),
  KEY `idx_ai_runs_conversation_created` (`conversation_id`, `created_at`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='AI运行监控记录';
```

字段使用说明：

| 字段 | 用途 |
| --- | --- |
| `id` | 运行详情主键。 |
| `conversation_id` | 关联会话，支持按会话定位本轮运行。 |
| `request_id` | 对齐前端本轮发送、WebSocket 和取消请求。 |
| `user_message_id` | 关联本轮用户消息，详情页展示问题。 |
| `assistant_message_id` | 成功后关联助手消息，详情页展示回答。 |
| `user_id` | 按用户筛选/统计。 |
| `agent_id` | 按智能体筛选/统计。 |
| `provider_id` | 按供应商筛选/统计。 |
| `model_id` | 记录当时真实调用模型，避免 agent 后续修改导致历史失真。 |
| `model_display_name` | 列表展示模型名；没有 display name 时用空串，不额外查旧快照。 |
| `status` | 当前运行状态；字符串避免 tinyint 魔法数字。 |
| `prompt_tokens` | 输入 token 统计。 |
| `completion_tokens` | 输出 token 统计。 |
| `total_tokens` | 总 token 统计。 |
| `duration_ms` | 运行耗时，用于监控体验和性能判断。 |
| `error_message` | 失败/取消/超时原因。 |
| `started_at` | 真正开始调用模型的时间。 |
| `finished_at` | 进入终态的时间。 |
| `created_at` | 创建时间，用于列表和统计时间范围。 |
| `updated_at` | 行更新时间。 |

### `ai_run_events`

```sql
CREATE TABLE `ai_run_events` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT COMMENT '事件ID',
  `run_id` bigint unsigned NOT NULL COMMENT 'ai_runs.id',
  `seq` int unsigned NOT NULL COMMENT '同一run内事件序号',
  `event_type` varchar(32) NOT NULL COMMENT 'start/completed/failed/canceled/timeout',
  `message` varchar(1024) NOT NULL DEFAULT '' COMMENT '事件说明或错误原因',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '事件时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_ai_run_events_run_seq` (`run_id`, `seq`),
  KEY `idx_ai_run_events_run_id` (`run_id`, `id`),
  KEY `idx_ai_run_events_type_created` (`event_type`, `created_at`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='AI运行监控事件';
```

字段使用说明：

| 字段 | 用途 |
| --- | --- |
| `id` | 事件主键。 |
| `run_id` | 归属运行。 |
| `seq` | 同一运行内稳定排序。 |
| `event_type` | 运行生命周期事件类型。 |
| `message` | 事件说明或错误原因。 |
| `created_at` | 事件发生时间。 |

## 4. 状态合同

运行状态只允许：

```text
running   模型调用中
success   已完成
failed    调用失败或保存失败
canceled  用户主动停止
timeout   超时 worker 标记
```

没有 `queued`：当前实现是 API 进程内 dispatcher，入队后马上执行。没有真实队列排队状态，就不建假状态。

事件类型只允许：

```text
start
completed
failed
canceled
timeout
```

不记录 `delta`，因为 delta 属于 WebSocket 即时体验，最终回答已经在 `ai_messages`。

## 5. 运行链路

```text
用户发送消息
  -> aimessage 写 ai_messages 用户消息
  -> dispatcher 调 aichat.ExecuteConversationReply
  -> aichat 创建 ai_runs running + ai_run_events start
  -> engine.StreamChat 持续发 WebSocket delta
  -> 成功：写助手消息，更新 ai_runs token/duration/status，写 completed 事件
  -> 失败：更新 ai_runs failed，写 failed 事件，发 WebSocket failed
  -> 取消：dispatcher cancel context，更新 ai_runs canceled，写 canceled 事件
  -> 超时：worker 扫 running 旧记录，更新 timeout，写 timeout 事件
```

## 6. API 合同

继续使用现有路径，不增加新路由：

```text
GET /api/admin/v1/ai-runs/page-init
GET /api/admin/v1/ai-runs
GET /api/admin/v1/ai-runs/:id
GET /api/admin/v1/ai-runs/stats
GET /api/admin/v1/ai-runs/stats/by-date
GET /api/admin/v1/ai-runs/stats/by-agent
GET /api/admin/v1/ai-runs/stats/by-user
```

查询参数把 `run_status` 改成 `status`。为避免前端残留，后端不同时接受两个名字。

列表项字段：

```json
{
  "id": 1,
  "request_id": "uuid",
  "user_id": 7,
  "agent_id": 3,
  "agent_name": "客服",
  "provider_id": 2,
  "provider_name": "OpenAI",
  "conversation_id": 4,
  "conversation_title": "你好",
  "status": "success",
  "status_name": "成功",
  "model_id": "gpt-5.4",
  "model_display_name": "GPT-5.4",
  "prompt_tokens": 12,
  "completion_tokens": 20,
  "total_tokens": 32,
  "duration_ms": 1530,
  "duration_text": "1.53s",
  "error_message": "",
  "created_at": "2026-05-10 12:00:00"
}
```

详情额外返回：

```json
{
  "user_message": {"id": 10, "role": 1, "content_type": "text", "content": "你好", "meta_json": {}, "created_at": "..."},
  "assistant_message": {"id": 11, "role": 2, "content_type": "text", "content": "你好，有什么可以帮你", "meta_json": {}, "created_at": "..."},
  "events": [
    {"id": 1, "seq": 1, "event_type": "start", "message": "开始生成", "created_at": "..."},
    {"id": 2, "seq": 2, "event_type": "completed", "message": "生成完成", "created_at": "..."}
  ]
}
```

统计仍然只聚合 `ai_runs`：

- 总运行数
- 成功率
- 失败数：`failed + canceled + timeout`
- 总 token / 输入 token / 输出 token
- 平均耗时

## 7. 文件边界

后端：

```text
admin_back_go/database/migrations/20260510_ai_run_monitor_mvp.sql
admin_back_go/internal/enum/ai.go
admin_back_go/internal/dict/dict.go
admin_back_go/internal/module/aichat/*
admin_back_go/internal/module/airun/*
admin_back_go/internal/bootstrap/ai_reply_dispatcher.go
```

前端：

```text
admin_front_ts/src/api/ai/runs.ts
admin_front_ts/src/views/Main/ai/runs/index.vue
admin_front_ts/src/views/Main/ai/runs/components/RunList/index.vue
admin_front_ts/src/views/Main/ai/runs/components/RunStats/index.vue
```

文档：

```text
docs/contracts/admin-api-v1.md
docs/testing/smoke-matrix.md
docs/migration/current-status.md
admin_back_go/docs/architecture.md
```

## 8. 验收

必须验证：

```powershell
go test ./internal/enum ./internal/dict ./internal/module/aichat ./internal/module/airun ./internal/server ./internal/bootstrap -count=1
cd E:\admin_go\admin_front_ts
npx vue-tsc -b --pretty false
npx vitest run tests/shared/ai/ai-runs-api.test.ts
```

DB 验证：

```sql
SELECT table_name
FROM information_schema.tables
WHERE table_schema = DATABASE()
  AND table_name IN ('ai_runs', 'ai_run_events', 'ai_usage_daily');
```

必须只返回：

```text
ai_run_events
ai_runs
```

字段残留扫描：

```powershell
rg -n "usage_json|input_snapshot_json|output_snapshot_json|engine_task_id|engine_run_id|model_snapshot|run_status|latency_ms|error_msg" admin_back_go/internal/module/aichat admin_back_go/internal/module/airun admin_front_ts/src/api/ai/runs.ts admin_front_ts/src/views/Main/ai/runs docs/contracts/admin-api-v1.md
```

这些旧字段不能出现在 active 运行监控合同里。
