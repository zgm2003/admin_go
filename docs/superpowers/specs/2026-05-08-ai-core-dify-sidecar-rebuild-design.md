# AI Core Dify Sidecar Rebuild Design

状态：spec/plan ready；active docs audit synced on 2026-05-09。本文是 AI 模块全量重构设计、开源取舍、当前执行检查点和验收边界；live Dify E2E 仍需显式 sidecar 凭证验证。
日期：2026-05-08；当前审计补充：2026-05-09

## Linus 三问

1. 真问题：是。当前 AI 模块已经有 Go-owned config / agent / knowledge / chat / run 第一片，但旧表和旧产品面无法干净覆盖供应商、智能体、知识库、工具、对话、运行监控。继续在旧表上补洞，只会把 Dify sidecar、运行镜像和后台权限揉成一坨。
2. 更简单做法：不要自己造完整 AI 平台。采用 `admin_go + Dify sidecar + Go AIEngine adapter`：Dify 先承接模型、RAG、workflow、工具编排和运行细节；`admin_go` 只保留后台产品壳、RBAC、审计、运行镜像和 Vue 页面。
3. 会破坏什么：不能破坏现有登录、菜单、RBAC、前端 `/ai/*` 使用路径、WebSocket envelope 和当前用户会话边界。表可以删重建，但必须先备份，且 REST/前端入口要按阶段迁移，不能让 Vue 直连 Dify。

## Current runtime facts

当前仓库事实以 2026-05-09 工作区为准：

```text
Active backend route surface:
  new sidecar routes are mounted:
    /api/admin/v1/ai-engine-connections
    /api/admin/v1/ai-apps
    /api/admin/v1/ai-knowledge-maps
    /api/admin/v1/ai-knowledge-documents
    /api/admin/v1/ai-tool-maps
    /api/admin/v1/ai-conversations
    /api/admin/v1/ai-messages
    /api/admin/v1/ai-chat
    /api/admin/v1/ai-runs

  retired old routes have been removed from active runtime:
    /api/admin/v1/ai-models
    /api/admin/v1/ai-tools
    /api/admin/v1/ai-prompts
    /api/admin/v1/ai-agents
    /api/admin/v1/ai-knowledge-bases

Active production bootstrap:
  aichat is wired through internal/platform/ai.EngineFactory.
  bootstrap does not inject deterministicProvider.
  production aichat source no longer contains deterministicProvider / legacy Provider / GenerateInput / GenerateResult / executeWithLegacyProvider residue.
  no active app/engine config must fail explicitly; it must not fake success.

Final cleanup already done in the current dirty tree:
  admin_back_go/internal/module/aichat/service.go production fake provider residue was removed.
  tests use internal/platform/ai fake engines instead of a production Provider seam.

Remaining final-audit risk:
  full-admin-smoke currently reaches the AI checks but can still be blocked later by stale non-AI payment/wallet probes. Treat that as a full-smoke maintenance issue, not an AI architecture failure.
  live Dify-enabled E2E remains credential-gated; do not claim it is complete without configured sidecar smoke evidence.
```

当前模块切片：

```text
Go backend active AI modules:
  aiengine / aiapp / aiknowledgemap / aitoolmap
  aiconversation / aimessage / airun / aichat
  internal/platform/ai and internal/platform/ai/dify

Retired module directories may still exist on disk during this dirty-tree pass:
  aimodel / aitool / aiprompt / aiagent / aiknowledge
  They must not be imported by server/bootstrap/route metadata, and they are deletion candidates after final residue scan.

Vue AI target pages/API:
  admin_front_ts/src/views/Main/ai/{providers,apps,chat,knowledge,runs,tools}
  admin_front_ts/src/api/ai/{engineConnections,apps,knowledgeMaps,toolMaps,conversations,messages,runs,chat}.ts
```

这说明当前问题不是“缺几个页面”，而是要把旧 AI 配置模型从 active runtime、文档和 smoke 里彻底摘掉，让六个产品入口围绕 sidecar engine schema 运转。

## Open-source decision

调研记录在：

```text
docs/open-source/05-ai-platform-candidates.md
```

本次采用：

```text
Primary: admin_go + Dify sidecar + Go AIEngine adapter
Future: add EinoEngine behind the same interface if we need Go-native embedded workflows
Optional future: RAGFlow sidecar only when Dify knowledge/doc processing is insufficient
```

来源与关键事实：

- Dify 官方站点描述其提供 agentic workflows、RAG pipelines、integrations、observability，并支持模型访问/切换/比较。它正好覆盖供应商配置、智能体/应用、知识库、工具、对话、监控这些产品能力。
- Dify Chat Service API 使用 `POST /chat-messages`，请求含 `query`、`user`、`inputs`、`response_mode`、`conversation_id`；流式返回 `task_id`、`message_id`、`conversation_id`、`answer`、`metadata.usage` 等。Dify 文档强调 API key 应放在服务端，不能暴露给客户端。
- Dify 支持 `POST /chat-messages/{task_id}/stop` 停止流式生成；`user` 必须与发送消息一致。
- Dify knowledge API 支持 dataset/document，例如创建空知识库、按文本创建 document、查询 document/indexing status。这足够作为第一版知识库 sidecar 映射。
- Eino 是 Go-native LLM app framework，有 ChatModel、Tool、Retriever、Embedding、graph/workflow、stream processing、callbacks/tracing/metrics。它适合作为未来 `EinoEngine`，但不该阻塞 Dify 第一版。
- RAGFlow 是更重的 RAG/document understanding 引擎，适合未来复杂文档，不适合第一阶段同时引入。
- OpenAI Go SDK 可作为 direct provider，但不替代 AI 平台；它只能放在 `internal/platform/ai` 边界内，不能塞进业务 module。

## Final architecture

```text
Vue AI pages
  -> admin_go REST / WebSocket
    -> internal/module/ai*
      -> internal/platform/ai.Engine
        -> DifyEngine
          -> Dify Service API
```

硬边界：

```text
Vue 不直接请求 Dify。
Dify API key 不进入浏览器、不进入 localStorage、不进入前端构建产物。
业务 module 不直接 import Dify/OpenAI/Eino SDK/client。
Dify 不接管 admin_go 用户、RBAC、菜单、路由、operation logs。
admin_go 本地 MySQL 保留会话、消息、run、event、usage 镜像。
WebSocket 对浏览器仍是 admin_go 的 ai.response.*.v1 envelope，不暴露 Dify SSE。
```

这不是“把后台换成 Dify”。这是把 Dify 当 AI engine sidecar。

## Product modules

本次不是修一个聊天框，是重建完整 AI 产品面。六个模块必须同时在表、接口、权限、页面里有位置：

| Product module | Local table/source | Engine sidecar mapping | Page route |
| --- | --- | --- | --- |
| 供应商配置 | `ai_engine_connections` | Dify base URL / workspace / health / encrypted service key | `/ai/providers` |
| 智能体配置 | `ai_apps`, `ai_app_bindings` | Dify chat app / workflow app / app API key | `/ai/apps` |
| AI 对话 | `ai_conversations`, `ai_messages`, `ai_runs`, `ai_run_events` | Dify conversation/message/task ids | `/ai/chat` |
| 知识库 | `ai_knowledge_maps`, `ai_knowledge_documents` | Dify dataset/document/batch/indexing status | `/ai/knowledge` |
| 运行监控 | `ai_runs`, `ai_run_events`, `ai_usage_daily` | Dify task id + usage metadata | `/ai/runs` |
| AI 工具管理 | `ai_tool_maps` | Dify tool/workflow/node references; future gateway whitelist | `/ai/tools` |

`ai_models`、`ai_prompts` 这类旧页面不再作为第一版产品模块保留。模型和 prompt 是 Dify app/workflow 内部配置，`admin_go` 只保存需要审计、授权和选择的映射事实。否则就是把 Dify 的控制台复制一遍，复杂且没品味。

## Retired AI surface

这些旧资源在 Dify sidecar 产品面里已经不是 active runtime contract：

```text
API:
  /api/admin/v1/ai-models
  /api/admin/v1/ai-tools
  /api/admin/v1/ai-prompts
  /api/admin/v1/ai-agents
  /api/admin/v1/ai-knowledge-bases

Vue routes/pages/API:
  /ai/models
  /ai/agents
  /ai/prompts
  src/api/ai/{models,agents,prompts,knowledge,tools}.ts old clients

Tables dropped by rebuild migration after backup:
  ai_models
  ai_tools
  ai_prompts
  ai_agents
  ai_agent_scenes
  ai_assistant_tools
  ai_agent_knowledge_bases
  ai_knowledge_bases
  ai_knowledge_documents
  ai_knowledge_chunks
  ai_run_steps
```

允许保留旧名字的地方必须是“证据”而不是“运行入口”：

```text
backup / rollback SQL
historical docs under docs/superpowers/specs or docs/superpowers/plans
negative router tests that assert retired routes return 404
one-pass legacy JSON alias fields such as agent_id -> app_id
```

禁止：

```text
server/router.go 挂载旧 route。
bootstrap/app.go 初始化旧 service。
bootstrap/route_meta.go 注册旧 route metadata。
smoke 脚本继续请求旧 API 或要求 /ai/models、/ai/prompts 存在。
current-status / smoke-matrix / backend architecture 把旧模块写成 active implemented。
Vue 新页面通过旧 API client 访问 Dify sidecar 产品面。
```

## Engine boundary

新边界建议放在：

```text
admin_back_go/internal/platform/ai
```

核心接口必须小，避免一开始把 Dify 的全部概念泄漏到业务层。

```go
package ai

import (
	"context"
	"encoding/json"
)

type EngineType string

const (
	EngineTypeDify   EngineType = "dify"
	EngineTypeEino   EngineType = "eino"
	EngineTypeDirect EngineType = "direct"
)

type Engine interface {
	TestConnection(ctx context.Context, input TestConnectionInput) (*TestConnectionResult, error)
	StreamChat(ctx context.Context, input ChatInput, sink EventSink) (*ChatResult, error)
	StopChat(ctx context.Context, input StopChatInput) error
	SyncKnowledge(ctx context.Context, input KnowledgeSyncInput) (*KnowledgeSyncResult, error)
}

type EventSink interface {
	Emit(ctx context.Context, event Event) error
}

type ChatInput struct {
	AppID                uint64
	RunID                uint64
	UserID               uint64
	UserKey              string
	Content              string
	ConversationEngineID string
	InputsJSON           json.RawMessage
	FilesJSON            json.RawMessage
}

type Event struct {
	Type        string
	DeltaText   string
	PayloadJSON json.RawMessage
}
```

设计原则：

```text
不要返回裸 channel，避免无主 goroutine 和调用方忘记 drain。
所有外部请求都带 context deadline。
外部 engine 错误只在 platform 层解析，module 层只看稳定 error category。
engine event 是内部稳定结构，不是 Dify SSE JSON 原样透传。
EventSink 不接收裸 map；外部 payload 先压成 json.RawMessage，module 层只读稳定字段。这样能避免 map[string]any 在业务代码里扩散，前端也不会被迫吞未知结构。

当前代码里 `internal/platform/ai` 仍有 `map[string]any`，这是可接受的外部边界临时形态，但不能继续往 `internal/module/*` DTO 和 Vue API 类型扩散。Task 9/10 收口时优先把 module response 和前端类型改成 `json.RawMessage` / `Record<string, unknown>` / 明确结构。
```

## DifyEngine contract

第一版只接 Dify Service API，不接 Dify console internal API。

### Chat

Dify request 映射：

```text
POST {base_url}/chat-messages
Authorization: Bearer {app_api_key}

query           <- user message content
user            <- admin_go stable user key, e.g. admin:{user_id}
inputs          <- app/runtime variables from ai_apps.runtime_config_json
response_mode   <- streaming
conversation_id <- ai_conversations.engine_conversation_id when continuing
files           <- future; first rebuild can reject attachments explicitly
```

Dify Service API facts:

```text
POST /chat-messages accepts blocking or streaming response_mode.
For phase one admin_go always sends response_mode=streaming.
Streaming response is SSE text/event-stream; browser never sees this SSE directly.
```

Dify response/event 映射：

```text
task_id          -> ai_runs.engine_task_id
message_id       -> ai_messages.engine_message_id
conversation_id  -> ai_conversations.engine_conversation_id
answer/delta     -> ai_run_events + ai_messages.content
metadata.usage   -> ai_runs token/price/latency fields + ai_usage_daily aggregation
```

admin_go 对浏览器发布：

```text
ai.response.start.v1
ai.response.delta.v1
ai.response.completed.v1
ai.response.failed.v1
ai.response.cancel.v1
```

Dify SSE 只存在于 Go 后端到 Dify 的内部链路；浏览器仍走 admin_go WebSocket + REST catch-up。

### Stop

Dify stop 映射：

```text
POST {base_url}/chat-messages/{task_id}/stop
Authorization: Bearer {app_api_key}
Body: { "user": "admin:{user_id}" }
```

规则：

```text
只有 running run 才允许 stop。
本地先标记 cancel_requested_at，再调用 Dify stop。
Dify stop 失败不能伪装成功；本地 run 保留失败原因和 raw status。
Stop applies to streaming task_id only; blocking responses have no cancel path in this design.
```

### Knowledge

第一版知识库采用“映射 + 同步状态”，不把 Dify dataset 全量 UI 复制过来。

```text
admin_go local knowledge map -> Dify dataset
admin_go document map        -> Dify document
admin_go indexing state      -> Dify indexing_status mirror
```

必要能力：

```text
create/link dataset
create document by text
store Dify returned batch id when available
poll document indexing status
store indexing_status transitions locally
disable/unlink document
record error message and external ids
```

不做：

```text
不在第一版实现自己的 vector DB。
不实现复杂 chunk editor。
不承诺 Dify Console 的所有 dataset feature 都能在 admin_go 页面操作。
```

### Tools

第一版工具管理是“本地工具目录 + Dify workflow/tool 引用映射”。

```text
admin_go 记录工具名称、类型、可见范围、权限、Dify 引用 ID、风险等级。
真正的 tool execution 先由 Dify workflow 承接。
admin_go 不允许 Dify 直接调用任意内部管理接口；如需调用，必须走显式 tool gateway + 权限白名单。
```

## Proposed schema rebuild

用户已明确接受 AI 表全删重建，但工程上必须先备份。重建目标不是把 Dify 表复制进来，而是保存 admin_go 需要控制和审计的事实。

### Tables

| Table | Owner | Purpose |
| --- | --- | --- |
| `ai_engine_connections` | admin_go | Dify/OpenAI/Eino/RAGFlow connection config; encrypted secrets; health state |
| `ai_apps` | admin_go | Local AI app/agent entry; maps to Dify app/workflow/chat app |
| `ai_app_bindings` | admin_go | Bind AI app to menu/scene/platform/permission/user scope |
| `ai_conversations` | admin_go | Local conversation index; user ownership; engine conversation id |
| `ai_messages` | admin_go | Local message mirror/audit; engine message id; feedback |
| `ai_runs` | admin_go | Local execution record; engine task id; status/tokens/cost/latency |
| `ai_run_events` | admin_go | Durable event stream mirror; start/delta/completed/failed/cancel |
| `ai_knowledge_maps` | admin_go | Local knowledge base to Dify dataset mapping |
| `ai_knowledge_documents` | admin_go | Local document to engine document mapping and indexing status |
| `ai_tool_maps` | admin_go | Local tool catalog to Dify tool/workflow/node mapping |
| `ai_usage_daily` | admin_go | Daily token/cost/latency aggregation by app/engine/user |

### Field rules

通用字段：

```text
id BIGINT unsigned primary key
status TINYINT NOT NULL DEFAULT 1       -- 1 enabled/running/success depending enum, 2 disabled where applicable
is_del TINYINT NOT NULL DEFAULT 2       -- 1 deleted, 2 active, consistent with current repo
created_at DATETIME NOT NULL
updated_at DATETIME NOT NULL
```

状态枚举不能复用同一个字段随便表达不同意思：

```text
config tables: status=1 enabled, status=2 disabled
soft delete: is_del=1 deleted, is_del=2 active
run status: pending/running/success/failed/canceled/timeout as VARCHAR, not TINYINT magic
indexing status: pending/indexing/completed/error as VARCHAR, mirrors engine state
```

秘密字段：

```text
api_key_enc VARBINARY/TEXT only, encrypted by existing secretbox/VAULT_KEY pattern.
Never return api_key_enc or plaintext api_key in response or operation logs.
OperationLog must mask api_key, apiKey, api_key_enc, engine_app_api_key, Authorization-like headers, and raw request fields that may carry credentials. base_url itself is not secret, but do not log full headers or bearer values.
```

Engine IDs：

```text
engine_type: dify/eino/direct/ragflow
engine_app_id: Dify app id or workflow id
engine_dataset_id: Dify dataset id
engine_conversation_id: Dify conversation_id
engine_message_id: Dify message_id
engine_task_id: Dify task_id
```

不要在业务层散落 Dify 字段名；字段统一以 `engine_*` 表达。

Index rules:

```text
Unique keys include is_del only for soft-delete-friendly config tables.
Hot list filters get composite indexes in WHERE order: user/status/time, app/status/is_del, map/status/is_del.
Large text and raw payloads stay in LONGTEXT/JSON fields and are never used for normal list filters.
No foreign keys in this migration, matching current repo style; repository/service must enforce existence and delete guards explicitly.
```

## Existing table cleanup strategy

### Backup first

实施前必须生成备份 SQL 或迁移内备份表：

```sql
CREATE TABLE ai_models_backup_20260508 AS SELECT * FROM ai_models;
CREATE TABLE ai_tools_backup_20260508 AS SELECT * FROM ai_tools;
CREATE TABLE ai_prompts_backup_20260508 AS SELECT * FROM ai_prompts;
CREATE TABLE ai_prompt_backup_20260508 AS SELECT * FROM ai_prompt;
CREATE TABLE ai_agents_backup_20260508 AS SELECT * FROM ai_agents;
CREATE TABLE ai_agent_scenes_backup_20260508 AS SELECT * FROM ai_agent_scenes;
CREATE TABLE ai_assistant_tools_backup_20260508 AS SELECT * FROM ai_assistant_tools;
CREATE TABLE ai_agent_knowledge_bases_backup_20260508 AS SELECT * FROM ai_agent_knowledge_bases;
CREATE TABLE ai_knowledge_bases_backup_20260508 AS SELECT * FROM ai_knowledge_bases;
CREATE TABLE ai_knowledge_documents_backup_20260508 AS SELECT * FROM ai_knowledge_documents;
CREATE TABLE ai_knowledge_chunks_backup_20260508 AS SELECT * FROM ai_knowledge_chunks;
CREATE TABLE ai_conversations_backup_20260508 AS SELECT * FROM ai_conversations;
CREATE TABLE ai_messages_backup_20260508 AS SELECT * FROM ai_messages;
CREATE TABLE ai_runs_backup_20260508 AS SELECT * FROM ai_runs;
CREATE TABLE ai_run_steps_backup_20260508 AS SELECT * FROM ai_run_steps;
CREATE TABLE ai_permissions_backup_20260508 AS SELECT * FROM permissions WHERE platform='admin' AND (...AI menu/button predicate...);
CREATE TABLE ai_role_permissions_backup_20260508 AS SELECT rp.* FROM role_permissions rp JOIN permissions p ON p.id=rp.permission_id WHERE p.platform='admin' AND (...AI menu/button predicate...);
```

如果生产环境数据量大，用 `mysqldump` 代替 `CREATE TABLE AS SELECT`，但必须有可回滚 artifact 路径。

### Drop/rebuild boundary

允许删除/替换：

```text
ai_models / ai_tools / ai_prompts / ai_prompt
ai_agents / ai_agent_scenes / ai_assistant_tools / ai_agent_knowledge_bases
ai_knowledge_bases / ai_knowledge_documents / ai_knowledge_chunks
ai_conversations / ai_messages / ai_runs / ai_run_steps
old AI menu/button permissions and role grants
```

新结构不再保留 `ai_run_steps` 作为主事件表；用 `ai_run_events` 持久化 streaming/event，step 详情后续可由 event 或 engine trace 扩展。

保留或迁移菜单入口：

```text
/ai/models    -> removed/replaced by /ai/providers
/ai/prompts   -> removed; prompts move into Dify app/workflow config instead of standalone admin table
/ai/agents    -> removed/replaced by /ai/apps
/ai/providers -> ai_engine_connections page
/ai/apps      -> ai_apps page
/ai/knowledge -> ai_knowledge_maps page
/ai/tools     -> ai_tool_maps page
/ai/chat      -> current-user chat page, implementation changes to DifyEngine
/ai/runs      -> ai_runs + ai_run_events monitor
```

## REST contract direction

新管理 API：

```text
GET    /api/admin/v1/ai-engine-connections/page-init
GET    /api/admin/v1/ai-engine-connections
POST   /api/admin/v1/ai-engine-connections
PUT    /api/admin/v1/ai-engine-connections/:id
PATCH  /api/admin/v1/ai-engine-connections/:id/status
POST   /api/admin/v1/ai-engine-connections/:id/test
DELETE /api/admin/v1/ai-engine-connections/:id

GET    /api/admin/v1/ai-apps/page-init
GET    /api/admin/v1/ai-apps
GET    /api/admin/v1/ai-apps/options
GET    /api/admin/v1/ai-apps/:id
POST   /api/admin/v1/ai-apps
PUT    /api/admin/v1/ai-apps/:id
PATCH  /api/admin/v1/ai-apps/:id/status
POST   /api/admin/v1/ai-apps/:id/test
DELETE /api/admin/v1/ai-apps/:id
GET    /api/admin/v1/ai-apps/:id/bindings
POST   /api/admin/v1/ai-apps/:id/bindings
DELETE /api/admin/v1/ai-app-bindings/:id

GET    /api/admin/v1/ai-knowledge-maps/page-init
GET    /api/admin/v1/ai-knowledge-maps
POST   /api/admin/v1/ai-knowledge-maps
PUT    /api/admin/v1/ai-knowledge-maps/:id
PATCH  /api/admin/v1/ai-knowledge-maps/:id/status
POST   /api/admin/v1/ai-knowledge-maps/:id/sync
DELETE /api/admin/v1/ai-knowledge-maps/:id
GET    /api/admin/v1/ai-knowledge-maps/:id/documents
POST   /api/admin/v1/ai-knowledge-maps/:id/documents
PATCH  /api/admin/v1/ai-knowledge-documents/:id/status
POST   /api/admin/v1/ai-knowledge-documents/:id/refresh-status
DELETE /api/admin/v1/ai-knowledge-documents/:id

GET    /api/admin/v1/ai-tool-maps/page-init
GET    /api/admin/v1/ai-tool-maps
GET    /api/admin/v1/ai-tool-maps/:id
POST   /api/admin/v1/ai-tool-maps
PUT    /api/admin/v1/ai-tool-maps/:id
PATCH  /api/admin/v1/ai-tool-maps/:id/status
DELETE /api/admin/v1/ai-tool-maps/:id
```

运行 API 尽量保持现有前端入口不破：

```text
GET    /api/admin/v1/ai-conversations
POST   /api/admin/v1/ai-conversations
GET    /api/admin/v1/ai-conversations/:id
PUT    /api/admin/v1/ai-conversations/:id
PATCH  /api/admin/v1/ai-conversations/:id/status
DELETE /api/admin/v1/ai-conversations/:id

GET    /api/admin/v1/ai-messages
PATCH  /api/admin/v1/ai-messages/:id/content
PATCH  /api/admin/v1/ai-messages/:id/feedback
DELETE /api/admin/v1/ai-messages/:id

POST   /api/admin/v1/ai-chat/runs
GET    /api/admin/v1/ai-chat/runs/:run_id/events
POST   /api/admin/v1/ai-chat/runs/:run_id/cancel

GET    /api/admin/v1/ai-runs/page-init
GET    /api/admin/v1/ai-runs
GET    /api/admin/v1/ai-runs/:id
GET    /api/admin/v1/ai-runs/stats
GET    /api/admin/v1/ai-runs/stats/by-date
GET    /api/admin/v1/ai-runs/stats/by-agent   -- legacy response name may remain, backed by app_id/app_name
GET    /api/admin/v1/ai-runs/stats/by-user
```

兼容策略：

```text
第一阶段不强行改 Vue route path：/ai/chat、/ai/knowledge、/ai/runs、/ai/tools 保持用户入口稳定。
旧 ai-models/ai-tools/ai-prompts/ai-agents/ai-knowledge-bases REST 不再作为 active adapter；当前验收目标是从 server/bootstrap/smoke/active docs 摘掉。
agent_id / agent_name 只允许作为一次性 JSON/form alias 映射到 app_id/app_name，不能驱动新查询、权限或页面主字段。
GET /api/admin/v1/ai-apps/options is a read helper for chat page; it has auth but no OperationLog and no button-level RBAC rule.
```

## Vue design

采用 Vue 3 + `<script setup lang="ts">` + typed API clients。页面只做 composition，不把 Dify concepts 和后端字段猜测塞进模板。

建议前端结构：

```text
admin_front_ts/src/api/ai/engineConnections.ts
admin_front_ts/src/api/ai/apps.ts
admin_front_ts/src/api/ai/knowledgeMaps.ts
admin_front_ts/src/api/ai/toolMaps.ts

admin_front_ts/src/views/Main/ai/providers/index.vue
admin_front_ts/src/views/Main/ai/apps/index.vue
admin_front_ts/src/views/Main/ai/knowledge/index.vue
admin_front_ts/src/views/Main/ai/tools/index.vue
admin_front_ts/src/views/Main/ai/chat/index.vue
admin_front_ts/src/views/Main/ai/runs/index.vue

admin_front_ts/src/views/Main/ai/*/components/*.vue
admin_front_ts/src/views/Main/ai/*/composables/use*.ts
```

前端路由事实：

```text
当前仓库没有 src/router/routes/modules/ai.ts。
动态路由来自 DB permissions.component + src/router/view-registry.ts。
因此菜单 migration 必须把 component 写成 ai/providers、ai/apps、ai/chat、ai/knowledge、ai/runs、ai/tools，并确保这些 view key 对应 index.vue 存在。
```

组件边界：

```text
Provider/engine page: connection list + edit/test dialog + status switch.
Apps page: app list + Dify app mapping dialog + binding panel.
Knowledge page: dataset map list + document sync/index status panel.
Tools page: tool map list + risk/permission display.
Chat page: current app selector + conversation list + message panel + streaming state.
Runs page: filters + run table + event drawer + usage stats cards.
```

前端收口顺序：

```text
1. 先补 typed clients：engineConnections/apps/knowledgeMaps/toolMaps。
2. 再补两个新入口页面：providers/apps。
3. 再把 chat/runs 从 agent_id 心智迁到 app_id，新代码只发 app_id。
4. 最后把 knowledge/tools 的主 API 从旧 ai-knowledge-bases/ai-tools 配置页迁到 map API；如果旧页面需要短期保留，必须作为兼容入口写明删除计划。
```

兼容规则：

```text
agent_id / agent_name 只作为一次迁移期 alias，不能成为新页面、新 API client、新测试的主字段。
模型和 prompt 不再是核心产品入口；不要在 Vue 里重新复制 Dify Console 的模型/prompt 编辑器。
供应商密钥、Dify app key、Authorization-like header 都不能在浏览器构造或展示。
```

Vue 规则：

```text
source state minimal; derived filter/status label via computed.
API DTO typed; no `any` / `Record<string, any>`; use explicit interfaces or `Record<string, unknown>` for raw JSON payloads.
props down/events up for child components.
large logic goes to composables such as useAiRunStream, useAiConnectionTest, useKnowledgeSync.
No direct Dify request, no Dify API key in frontend.
```

## Runtime flow

### Start chat run

```text
1. Vue calls POST /api/admin/v1/ai-chat/runs with app_id/conversation_id/content.
2. handler validates current user and app visibility.
3. service creates local conversation if needed.
4. service writes user message.
5. service creates ai_runs row: run_status=running, app_id, engine_connection_id, request_id, started_at.
6. service enqueues existing ai:run-execute:v1 task; do not invent v2 unless the queue contract is explicitly migrated.
7. worker loads app + engine connection + encrypted secret.
8. worker calls platform/ai.DifyEngine.StreamChat.
9. EventSink persists ai_run_events and publishes ai.response.*.v1.
10. on complete, service writes assistant message, updates run tokens/cost/latency, aggregates ai_usage_daily.
```

### Cancel chat run

```text
1. Vue calls POST /api/admin/v1/ai-chat/runs/:run_id/cancel.
2. service verifies owner or future monitor permission.
3. service verifies the run is running, calls engine stop when engine_task_id exists, then marks canceled_at/completed_at locally.
4. engine StopChat calls Dify stop API with task_id + same user key.
5. service appends cancel event and publishes ai.response.cancel.v1.
```

### Knowledge sync

```text
1. Admin creates/links knowledge map.
2. Admin adds document text/file reference.
3. backend calls Dify document create API.
4. backend stores engine_document_id + batch/indexing status.
5. refresh-status route and a future worker/cron can poll Dify document status; first slice must at least support explicit refresh.
6. UI shows indexing/completed/error from local mirror.
```

## Observability

本地运行镜像是必须的，不是可选项：

```text
ai_runs: run_status, duration, token/cost, app_id, engine_connection_id, engine IDs, error category/message.
ai_run_events: durable ordered event stream for REST catch-up and debugging.
ai_usage_daily: day/app/engine/user aggregates; upsert on success, failure, timeout, and cancel exactly once per terminal run.
operation_logs: config/app/knowledge/tool mutations.
system logs: external engine request id, latency, status, no secret payload.
```

不接受的坏味道：

```text
只查 Dify 作为唯一运行记录。
只靠 WebSocket 内存事件，不落 ai_run_events。
把 Dify raw API key、request body、response body 整包写 operation_logs。
用 deterministic provider 冒充真实 AI runtime。
```


## Current handoff state for 2026-05-09 execution

这份 spec 现在是验收用工作文档，不是空想设计。当前执行状态必须写清楚，避免后续 agent 重复踩坑：

```text
已经完成并在当前工作区复核通过的主体切片：
- Task 1 schema/menu SQL: backup/rebuild/rollback files exist.
- Task 2 internal/platform/ai boundary exists.
- Task 3 Dify adapter exists.
- Task 4 aiengine exists.
- Task 5 aiapp exists.
- Task 6 aiknowledgemap exists.
- Task 7 aitoolmap exists.
- Task 8 aichat runtime is wired through AIEngine; duplicate bootstrap factory has been removed.
- Task 9 airun monitor reads ai_runs + ai_apps + ai_engine_connections + ai_run_events, not old ai_agents/ai_run_steps.
- Task 10 aiconversation now reads/writes ai_conversations.app_id, joins ai_apps, and keeps agent_id only as a legacy JSON/form alias.
- Task 11 Vue typed API/page adaptation has been materially implemented in the dirty frontend tree:
  engineConnections/apps/knowledgeMaps/toolMaps typed clients exist;
  providers/apps pages exist;
  chat/knowledge/runs/tools pages were adapted;
  old models/agents/prompts API and page folders were deleted.
- Active backend runtime no longer mounts old aimodel/aitool/aiprompt/aiagent/aiknowledge routes.

Current verification evidence on 2026-05-09:
- go test ./internal/platform/ai ./internal/platform/ai/dify ./internal/module/aiengine ./internal/module/aiapp ./internal/module/aiknowledgemap ./internal/module/aitoolmap ./internal/module/aichat ./internal/module/airun ./internal/server ./internal/bootstrap -count=1 => PASS
- PowerShell parser check for admin_back_go/scripts/full-admin-smoke.ps1 => ps-parse-ok
- go test ./internal/module/aiconversation -count=1 => PASS
- rg -n "ai_agents|c\.agent_id|column:agent_id|ActiveAgentExists|AgentName\(" internal/module/aiconversation internal/server/router_test.go -S => no active aiconversation runtime residue
- go test ./internal/module/aiconversation ./internal/module/aimessage ./internal/module/aichat ./internal/module/airun ./internal/server ./internal/bootstrap -count=1 => PASS
- go test ./internal/server -run 'TestRouterInstallsAIConfigRESTRoutes|TestRouterInstallsAIAgentKnowledgeRESTRoutes|TestRouterDoesNotInstallRetiredAIRoutes|TestRouterInstallsAIRuntimeRESTRoutes' -count=1 => PASS
- go test ./internal/bootstrap -run 'TestPermissionRouteRulesUseExplicitRESTPatterns|TestOperationRouteRulesUseExplicitRESTPatterns' -count=1 => PASS
- rg -n "internal/module/(aimodel|aitool\b|aiagent|aiknowledge\b|aiprompt)|\baimodel\.|\baitool\.|\baiagent\.|\baiknowledge\.|\baiprompt\." internal/server internal/bootstrap -S => no output
- frontend targeted tests and build:check were reported green before this final docs/smoke audit:
  npm run test -- tests/shared/ai/ai-engine-connection-api.test.ts tests/shared/ai/ai-app-api.test.ts tests/shared/ai/ai-knowledge-map-api.test.ts tests/shared/ai/ai-tool-map-api.test.ts tests/shared/ai/ai-conversation-api.test.ts tests/shared/http/ai-stream-contract.test.ts tests/shared/http/ai-stream-websocket-contract.test.ts
  npm run build:check
```

当前剩余真实阻塞不是继续发明 AI 架构，而是收口两个脏点：

```text
1. Full-smoke maintenance：AI 专项 gate 已经改为六入口和新 API，但完整 full smoke 可能继续被非 AI 的旧 payment/wallet 探针阻断。
2. Live Dify-enabled probe：只有配置了测试 sidecar/app 后，才能把真实 engine E2E 从 credential-gated 提升为 verified。
```

`aimessage` 只通过 `ai_conversations.id/user_id/is_del` 做归属校验，不依赖 agent/app 字段；它不需要重构为单独模块，只需要跟随 conversation contract 测试。

新的运行监控主轴已经固定为：

```text
ai_runs.app_id
ai_runs.engine_connection_id
ai_apps.name as app_name
ai_engine_connections.name/type as provider_name/engine_type
ai_run_events seq/event_type/payload_json
ai_usage_daily aggregated counters
```

兼容字段可以短期保留在 JSON 响应里，但语义必须转成 app：`agent_id` 仅作为 legacy alias，不能再驱动新查询和页面。后端 `aiconversation` 已经读写 `ai_conversations.app_id` 并 join `ai_apps`；Vue 新代码必须优先使用 `app_id` / `app_name`，旧 `agent_id` 只允许在兼容层和一次性迁移测试里出现。

## Migration phases

### Phase A: backup and schema rebuild

产出：AI 表备份、重建 SQL、rollback SQL、contract update。

成功标准：

```text
迁移前后可列出所有被 drop/rebuild 的表。
备份表或 dump artifact 存在。
新表能 migrate on clean DB。
旧菜单入口不丢。
```

### Phase B: platform AI interface + fake engine

产出：`internal/platform/ai` 小接口、fake engine tests、no direct Dify imports in modules。

成功标准：

```text
go test ./internal/platform/ai ./internal/module/aichat -count=1
rg "dify|openai|eino" admin_back_go/internal/module -S returns no SDK/client imports.
```

### Phase C: Dify connection/app mapping

产出：engine connection CRUD/test、ai_apps CRUD/test、secret masking、operation logs。

成功标准：

```text
connection test can hit configured Dify base URL with timeout.
API key never appears in REST response or OperationLog payload.
```

### Phase D: Dify chat runtime

产出：aichat runs through AIEngine/DifyEngine, ai_run_events persisted, WebSocket envelopes unchanged。

成功标准：

```text
With Dify test credentials: chat produces non-deterministic provider output and stores engine ids.
Without Dify credentials: route returns explicit engine config error, not fake success.
Existing frontend chat route still loads.
```

### Phase E: knowledge/tool maps

产出：knowledge map/document sync first slice、tool map first slice。

成功标准：

```text
Dify dataset/document ids are mirrored.
Indexing status can be refreshed.
Tool map is visible and permission-bound but does not expose arbitrary internal API execution.
```

### Phase F: Conversation app cleanup + Vue adaptation + smoke/docs

产出：`aiconversation` 从 `agent_id/ai_agents` 迁到 `app_id/ai_apps`，typed API clients、pages adapted、contract/current-status/smoke updated。

成功标准：

```text
go test ./internal/module/aiconversation ./internal/module/aimessage ./internal/module/aichat ./internal/module/airun ./internal/server ./internal/bootstrap -count=1 passes.
npm run test -- targeted AI contract tests pass.
npm run build:check passes or targeted vue-tsc gate passes.
full-admin-smoke adds Dify-disabled and optional Dify-enabled probes.
```

## Rollback

Rollback is boring by design:

```text
1. Disable active Dify engine connection: status=2.
2. Set AI runtime mode to disabled or deterministic-dev-only; production must fail explicit if no engine.
3. Restore old AI tables from backup if schema migration must be reverted.
4. Revert Vue API clients to previous commit if route contract changed.
5. Keep Dify sidecar data untouched; only unlink engine ids locally.
```

Rollback constraints:

```text
Do not silently fall back to fake provider in production.
Do not drop backup tables until one release after successful migration.
Do not delete Dify datasets/apps from rollback SQL; external sidecar cleanup is an operator step.
```

## Non-goals

```text
不把 Dify Console 当最终后台。
不让 Dify 接管 admin_go RBAC/menus/users.
不让 Vue 直接调用 Dify。
不在第一版同时引入 RAGFlow。
不在第一版实现自研 vector DB。
不把 OpenAI SDK calls 直接写进 aichat service。
不承诺所有 Dify feature 都映射到 admin_go 页面。
不继续让 deterministic provider 作为生产默认成功路径；如果保留，只能在 test 文件或显式 dev-only 构造里出现。
```

## Acceptance checklist

```text
[x] AI 表有备份和 rollback 文件：`20260508_ai_core_backup.sql`、`20260508_ai_core_rebuild.sql`、`20260508_ai_core_rollback.sql`。
[x] schema rebuild defines ai_engine_connections, ai_apps, ai_app_bindings, ai_conversations, ai_messages, ai_runs, ai_run_events, ai_knowledge_maps, ai_knowledge_documents, ai_tool_maps, ai_usage_daily。
[x] Dify connection/app secrets are encrypted at write boundary and masked in DTOs.
[x] aiconversation active code uses ai_conversations.app_id and ai_apps; no ai_agents/c.agent_id runtime dependency remains in active aiconversation code.
[x] `internal/platform/ai` is the only engine boundary used by active runtime.
[x] bootstrap no longer injects deterministicProvider into production app/worker.
[x] production `aichat` source no longer contains deterministicProvider / go-deterministic-provider / legacy Provider success path outside tests.
[x] backend old AI routes are unmounted and covered by negative router tests.
[x] airun no longer queries ai_agents/ai_run_steps as its primary monitor source.
[x] WebSocket event names remain ai.response.*.v1。
[x] Vue target pages/typed clients exist for providers/apps/chat/knowledge/runs/tools.
[x] smoke scripts probe new AI sidecar routes and stop probing old ai-models/ai-tools/ai-prompts/ai-agents/ai-knowledge-bases as active endpoints.
[x] docs/contracts/current-status/smoke matrix/backend architecture no longer describe retired AI routes/tables as active.
[x] final backend target tests pass after docs/smoke edits.
[x] final frontend targeted tests + build:check pass after docs/smoke edits.
[x] final residue scan shows old AI route strings only in historical docs, rollback/backup SQL, or negative tests.
[x] Dify-disabled smoke fails explicitly in default full smoke; Dify-enabled smoke remains credential-gated and must be run separately when sidecar config exists.
```
