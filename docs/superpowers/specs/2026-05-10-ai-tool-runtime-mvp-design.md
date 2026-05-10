# AI Tool Runtime MVP Design

> 目标：开始 tool 模块核心流程。先把真实 tool runtime 的表入库，再按这个合同实现一个只读测试工具 `admin_user_count`：查询当前用户量。所有字段必须现在就用，不做“未来字段”。

## 1. Linus 三问

1. 这是真问题吗？
   - 是。当前 `/ai/tools` 页面和 `aitoolmap` 代码还停留在旧的“工具映射/参考”概念，live DB 没有 `ai_tool_maps`，更没有可执行 tool。聊天、运行监控已经落地，现在要让智能体真正能调用本地工具。
2. 有更简单的方法吗？
   - 有。不要在 `ai_agents` 塞 `tool_ids_json` 或 `tools_enabled` 这种重复状态。用 `ai_tools` 定义工具，用 `ai_agent_tools` 绑定智能体，用 `ai_tool_calls` 记录每次调用。
3. 会破坏什么吗？
   - 不破坏对话表、不破坏运行监控 token 统计、不破坏供应商/智能体配置。`ai_agents` 不加字段，避免和绑定表产生双真相。

## 2. 运行时证据

当前 live DB 已确认：

```text
存在：ai_agents, ai_runs, ai_run_events, users
不存在：ai_tools, ai_agent_tools, ai_tool_calls, ai_tool_maps
```

当前 AI 菜单已有 `/ai/tools` 页面和按钮权限：

```text
PAGE: /ai/tools, permission id=94, i18n_key=menu.ai_tools
BUTTON: ai_tool_add / ai_tool_edit / ai_tool_status / ai_tool_del
```

当前测试智能体：

```text
ai_agents.id=3 name=测试 scenes=[chat] status=1
ai_agents.id=4 name=测试二 scenes=[chat] status=1
```

当前 `users` 统计事实：

```sql
SELECT COUNT(*) AS total_users,
       SUM(CASE WHEN status = 1 THEN 1 ELSE 0 END) AS enabled_users,
       SUM(CASE WHEN status = 2 THEN 1 ELSE 0 END) AS disabled_users
FROM users
WHERE is_del = 2;
```

测试环境当前结果：`total_users=1015, enabled_users=1015, disabled_users=0`。

## 3. OpenAI 对齐

OpenAI 官方当前方向是 Responses API / Agents SDK，但本项目当前运行时已经是 `internal/platform/ai/openaicompat` 的 OpenAI-compatible Chat Completions streaming 客户端，浏览器体验走 WebSocket，不走 SSE。

本 slice 的取舍：

```text
不引 OpenAI Go SDK。
不把 tool 写进 prompt 文本。
先在 platform/ai 边界扩展结构化 tool definition / tool call / tool output。
Chat Completions-compatible provider 先做 tools/tool_calls 的最小闭环。
未来切 Responses API 时复用 ai_tools / ai_agent_tools / ai_tool_calls 三张表，不重做业务表。
```

理由很简单：官方 Go SDK 存在，但现在引 SDK 会强迫改 provider boundary 和 streaming 链路，风险大于收益。表和执行器先按 OpenAI 函数调用语义设计即可。

## 4. 范围

### In

- 新增并已入库：`ai_tools`、`ai_agent_tools`、`ai_tool_calls`。
- Seed 一个本地只读工具：`admin_user_count`。
- 默认绑定所有已启用 chat 场景智能体，保证测试工具马上可用。
- 后端新增 `internal/module/aitool` 取代旧 `aitoolmap` active 路由。
- 后端新增 tool executor registry 和 `admin_user_count` executor。
- `aichat` 执行回复时加载当前智能体启用工具，传给 provider；模型请求 tool 时执行并写 `ai_tool_calls`。
- 运行监控详情展示 tool calls。
- 前端 `/ai/tools` 改为工具定义 + 智能体绑定，不再展示旧 `engine_tool_id` / `permission_code` / `config_json`。

### Out

- 不做写操作工具。
- 不做外部 HTTP tool。
- 不做 MCP。
- 不做 RAG。
- 不做计费。
- 不做前端手动执行工具按钮。
- 不在 `ai_agents` 加 `tools_enabled` 或 `tool_ids_json`。
- 不复活 `ai_tool_maps`。

## 5. 表设计（已入库）

迁移文件：`admin_back_go/database/migrations/20260510_ai_tool_runtime_mvp.sql`

### 5.1 `ai_tools`

```sql
CREATE TABLE IF NOT EXISTS `ai_tools` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT COMMENT '工具ID',
  `name` varchar(128) NOT NULL COMMENT '工具名称，管理页和运行监控展示',
  `code` varchar(128) NOT NULL COMMENT '工具唯一编码，传给模型作为function name',
  `description` varchar(1024) NOT NULL DEFAULT '' COMMENT '工具说明，传给模型作为function description',
  `executor` varchar(64) NOT NULL COMMENT '本地执行器编码，用于Go executor registry路由',
  `parameters_json` json NOT NULL COMMENT '工具参数JSON Schema，传给模型并用于入参校验',
  `result_schema_json` json NOT NULL COMMENT '工具返回JSON Schema，用于结果校验和运行监控展示',
  `risk_level` varchar(16) NOT NULL COMMENT '风险等级：low/medium/high',
  `timeout_ms` int unsigned NOT NULL DEFAULT 3000 COMMENT '执行超时毫秒，运行时context timeout',
  `status` tinyint unsigned NOT NULL DEFAULT 1 COMMENT '1启用 2禁用',
  `is_del` tinyint unsigned NOT NULL DEFAULT 2 COMMENT '1删除 2正常',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_ai_tools_code` (`code`),
  KEY `idx_ai_tools_status_del` (`status`, `is_del`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='AI工具定义';
```

字段用途：

| 字段 | 当前用途 |
| --- | --- |
| `id` | 工具主键；绑定表和调用表引用。 |
| `name` | 工具管理页列表/表单；运行监控 tool call 展示快照来源。 |
| `code` | 唯一工具编码；传给模型作为 function name；执行结果回传时定位工具。 |
| `description` | 传给模型作为 function description；管理页编辑。 |
| `executor` | Go executor registry 路由键；`admin_user_count` 指向同名 executor。 |
| `parameters_json` | 模型工具参数 JSON Schema；后端执行前校验参数。 |
| `result_schema_json` | 运行监控展示返回结构；后续测试校验 executor 输出。 |
| `risk_level` | 管理页风险标签；运行时首期只允许 `low` 自动执行。 |
| `timeout_ms` | 每次执行 `context.WithTimeout`。 |
| `status` | 管理页启停；运行时只加载启用工具。 |
| `is_del` | 软删除；列表和运行时过滤。 |
| `created_at` | 管理页展示和排序。 |
| `updated_at` | 管理页展示和排序。 |

### 5.2 `ai_agent_tools`

```sql
CREATE TABLE IF NOT EXISTS `ai_agent_tools` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT COMMENT '绑定ID',
  `agent_id` bigint unsigned NOT NULL COMMENT 'ai_agents.id',
  `tool_id` bigint unsigned NOT NULL COMMENT 'ai_tools.id',
  `status` tinyint unsigned NOT NULL DEFAULT 1 COMMENT '1启用 2禁用；运行时只加载启用绑定',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_ai_agent_tools_agent_tool` (`agent_id`, `tool_id`),
  KEY `idx_ai_agent_tools_agent_status` (`agent_id`, `status`, `id`),
  KEY `idx_ai_agent_tools_tool_status` (`tool_id`, `status`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='AI智能体工具绑定';
```

字段用途：

| 字段 | 当前用途 |
| --- | --- |
| `id` | 绑定主键。 |
| `agent_id` | 智能体配置页/工具页绑定对象；运行时按当前 agent 加载工具。 |
| `tool_id` | 绑定的工具。 |
| `status` | 单条绑定启停；运行时只加载启用绑定。 |
| `created_at` | 绑定管理展示/审计。 |
| `updated_at` | 绑定管理展示/审计。 |

为什么不加 `ai_agents.tools_enabled`：绑定存在性就是能力开关，额外字段会制造双真相。

### 5.3 `ai_tool_calls`

```sql
CREATE TABLE IF NOT EXISTS `ai_tool_calls` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT COMMENT '工具调用ID',
  `run_id` bigint unsigned NOT NULL COMMENT 'ai_runs.id',
  `tool_id` bigint unsigned NOT NULL COMMENT 'ai_tools.id',
  `tool_code` varchar(128) NOT NULL COMMENT '调用时工具编码快照',
  `tool_name` varchar(128) NOT NULL COMMENT '调用时工具名称快照',
  `call_id` varchar(128) NULL DEFAULT NULL COMMENT '模型返回的tool_call_id/call_id，用于回传工具结果',
  `status` varchar(16) NOT NULL COMMENT 'running/success/failed/timeout',
  `arguments_json` json NOT NULL COMMENT '模型传入参数',
  `result_json` json NULL COMMENT '工具返回结果',
  `error_message` varchar(1024) NOT NULL DEFAULT '' COMMENT '失败或超时原因',
  `duration_ms` int unsigned NULL DEFAULT NULL COMMENT '执行耗时毫秒，终态后写入',
  `started_at` datetime NOT NULL COMMENT '开始执行时间',
  `finished_at` datetime NULL DEFAULT NULL COMMENT '结束时间',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_ai_tool_calls_run_call` (`run_id`, `call_id`),
  KEY `idx_ai_tool_calls_run_id` (`run_id`, `id`),
  KEY `idx_ai_tool_calls_tool_created` (`tool_id`, `created_at`, `id`),
  KEY `idx_ai_tool_calls_status_created` (`status`, `created_at`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='AI工具调用记录';
```

字段用途：

| 字段 | 当前用途 |
| --- | --- |
| `id` | 调用记录主键。 |
| `run_id` | 归属运行；运行监控详情按 run 查询 tool calls。 |
| `tool_id` | 关联当前工具定义；删除工具时限制历史调用完整性。 |
| `tool_code` | 调用时工具编码快照；即使工具后续改名，历史仍能展示。 |
| `tool_name` | 调用时工具名快照；运行监控无需额外 join 才能展示。 |
| `call_id` | OpenAI tool_call_id / Responses call_id；回传工具结果时必须关联。 |
| `status` | 调用状态：running/success/failed/timeout。 |
| `arguments_json` | 模型传入参数；运行监控展示和问题复现。 |
| `result_json` | executor 输出；运行监控展示和二次提交给模型。 |
| `error_message` | 失败/超时原因。 |
| `duration_ms` | 工具执行耗时。 |
| `started_at` | 工具开始执行时间。 |
| `finished_at` | 工具进入终态时间。 |
| `created_at` | 创建时间；筛选/排序。 |
| `updated_at` | 更新时间；排障。 |

不额外存 `conversation_id/user_id/agent_id`：这些已经可从 `ai_runs` 唯一获得，重复存会污染事实源。

## 6. Seed 工具：`admin_user_count`

Seed 已入库：

```text
name: 查询当前用户量
code: admin_user_count
executor: admin_user_count
risk_level: low
timeout_ms: 3000
status: 1
```

参数 schema：

```json
{"type":"object","properties":{},"additionalProperties":false}
```

返回 schema：

```json
{
  "type": "object",
  "required": ["total_users", "enabled_users", "disabled_users"],
  "properties": {
    "total_users": {"type": "integer", "minimum": 0},
    "enabled_users": {"type": "integer", "minimum": 0},
    "disabled_users": {"type": "integer", "minimum": 0}
  },
  "additionalProperties": false
}
```

executor SQL：

```sql
SELECT COUNT(*) AS total_users,
       SUM(CASE WHEN status = 1 THEN 1 ELSE 0 END) AS enabled_users,
       SUM(CASE WHEN status = 2 THEN 1 ELSE 0 END) AS disabled_users
FROM users
WHERE is_del = 2;
```

安全边界：只返回数量，不返回 `username/email/phone/password`，不返回用户列表。

## 7. 后端 API 合同

旧 active 页面 `/ai/tools` 保留为工具定义管理；智能体使用哪些工具由 `/ai/agents` 配置：

```text
GET    /api/admin/v1/ai-tools/page-init
GET    /api/admin/v1/ai-tools
POST   /api/admin/v1/ai-tools
PUT    /api/admin/v1/ai-tools/:id
PATCH  /api/admin/v1/ai-tools/:id/status
DELETE /api/admin/v1/ai-tools/:id
GET    /api/admin/v1/ai-agents/:id/tools
PUT    /api/admin/v1/ai-agents/:id/tools
```

权限沿用现有按钮：

```text
create: ai_tool_add
update: ai_tool_edit
status: ai_tool_status
delete: ai_tool_del
agent tool config: ai_agent_edit
```

智能体工具配置挂 `ai_agent_edit`，因为它改变的是智能体能力配置，不新增 `ai_tool_execute` 假按钮。

## 8. 运行链路

```text
用户发送消息
  -> aimessage 写用户消息
  -> aichat 创建 ai_runs
  -> aichat 按 agent_id 查询 ai_agent_tools + ai_tools
  -> platform/ai 把 tools 结构化传给 provider
  -> provider 返回 tool_calls
  -> aichat 对每个 tool_call：
       创建 ai_tool_calls running
       context.WithTimeout(timeout_ms)
       registry.Execute(executor, arguments)
       成功写 success/result_json/duration
       失败写 failed/error_message/duration
       超时写 timeout/error_message/duration
  -> tool outputs 回传 provider
  -> provider 继续流式输出最终回答
  -> assistant message + ai_runs success
```

MVP 限制：第一版只允许低风险只读 executor 自动执行；`admin_user_count` 满足这个条件。

## 9. 前端组件边界

`/ai/tools/index.vue` 不能继续当旧 tool map 大杂烩。后续按 Vue 规则拆：

```text
src/api/ai/tools.ts
  - typed REST client; no any, no old aliases

src/views/Main/ai/tools/index.vue
  - route-level composition only

src/views/Main/ai/tools/components/ToolList/index.vue
  - 工具列表、筛选、启停、删除

src/views/Main/ai/tools/components/ToolFormDialog/index.vue
  - 工具新增/编辑表单

src/views/Main/ai/agents/components/AgentToolDialog/index.vue
  - 从智能体页面给当前智能体配置可用工具
```

Vue 约束：`<script setup lang="ts">`，props down/events up；表格筛选用 `computed` 派生；不要 `any` / `Record<string, any>`。

## 10. 验收

DB 已验证：

```sql
SELECT table_name
FROM information_schema.tables
WHERE table_schema = DATABASE()
  AND table_name IN ('ai_tools','ai_agent_tools','ai_tool_calls');
```

返回：

```text
ai_agent_tools
ai_tool_calls
ai_tools
```

Seed 已验证：

```text
ai_tools: id=1, code=admin_user_count, executor=admin_user_count, timeout_ms=3000
ai_agent_tools: agent_id=3 -> admin_user_count, agent_id=4 -> admin_user_count
```

实现完成后必须跑：

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/aitool ./internal/module/aichat ./internal/module/airun ./internal/platform/ai/openaicompat ./internal/server ./internal/bootstrap -count=1

cd E:\admin_go\admin_front_ts
npx vue-tsc -b --pretty false
npx vitest run tests/shared/ai/ai-tools-api.test.ts
```

残留扫描：

```powershell
rg -n "ai-tool-maps|ai_tool_maps|engine_tool_id|permission_code|config_json|dify_tool|workflow_node|admin_action_gateway|http_reference" admin_back_go/internal admin_front_ts/src docs/contracts/admin-api-v1.md docs/migration/current-status.md admin_back_go/docs/architecture.md
```

允许出现在历史 spec/plan/backup，不允许出现在 active contract/runtime。
