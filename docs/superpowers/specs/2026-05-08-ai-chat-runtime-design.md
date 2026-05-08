# AI Chat Runtime Design

状态：implemented first slice on 2026-05-08。本文定义并记录 AI P3/P4 chat、conversation、message、run、worker、realtime 迁移；当前 Go REST、Go worker、ai_run_timeout 注册、versioned WebSocket envelope、REST catch-up、docs、smoke、focused gates 已完成。真实外部 LLM provider、RAG/vector sidecar、tool execution 仍是凭证/后续工作，不包含在本次完成口径里。
日期：2026-05-08

## Linus 三问

1. 真问题：是。AI 管理态迁到 Go 后，最后还剩真正运行链路：会话、消息、run、worker、超时补偿和 streaming。如果这块继续留在 PHP，所谓 AI 迁移就是假的。
2. 更简单做法：第一版做最小可运行文本 chat runtime：创建 run、写 user message、worker 生成 assistant message、发布 versioned WebSocket events、REST 补拉 run events。不要引入 Python sidecar、向量库、复杂 agent framework。
3. 会破坏什么：不能破坏 AI chat UI 的流式体验；不能复活已删除 admin chat；不能直接操作 WebSocket connection；不能把 `ai_run_timeout` 说成 Go-owned，直到 worker 注册和 smoke 证明它确实跑 Go task type。

## 当前运行事实

### 当前 Go REST 前端入口

```text
admin_front_ts/src/api/ai/conversations.ts
  GET    /api/admin/v1/ai-conversations
  GET    /api/admin/v1/ai-conversations/:id
  POST   /api/admin/v1/ai-conversations
  PUT    /api/admin/v1/ai-conversations/:id
  PATCH  /api/admin/v1/ai-conversations/:id/status
  DELETE /api/admin/v1/ai-conversations/:id

admin_front_ts/src/api/ai/messages.ts
  GET    /api/admin/v1/ai-messages
  PATCH  /api/admin/v1/ai-messages/:id/content
  PATCH  /api/admin/v1/ai-messages/:id/feedback
  DELETE /api/admin/v1/ai-messages/:id
  DELETE /api/admin/v1/ai-messages

admin_front_ts/src/api/ai/runs.ts
  GET    /api/admin/v1/ai-runs/page-init
  GET    /api/admin/v1/ai-runs
  GET    /api/admin/v1/ai-runs/:id
  GET    /api/admin/v1/ai-runs/stats
  GET    /api/admin/v1/ai-runs/stats/by-date
  GET    /api/admin/v1/ai-runs/stats/by-agent
  GET    /api/admin/v1/ai-runs/stats/by-user

admin_front_ts/src/api/ai/chat.ts
  POST   /api/admin/v1/ai-chat/runs
  GET    /api/admin/v1/ai-chat/runs/:run_id/events
  POST   /api/admin/v1/ai-chat/messages
  POST   /api/admin/v1/ai-chat/runs/:run_id/cancel
```

旧 `/api/admin/AiConversations/*`、`/api/admin/AiMessages/*`、`/api/admin/AiRuns/*`、`/api/admin/AiChat/*` 只作为迁移前事实保留在历史 plan/spec，不是当前 active contract。

### Current frontend realtime contract

`docs/contracts/admin-realtime-v1.md` 和当前前端 message bus 使用 versioned AI events：

```text
ai.response.start.v1
ai.response.delta.v1
ai.response.completed.v1
ai.response.failed.v1
ai.response.cancel.v1
```

当前 active frontend code 不再监听旧 `ai_run_event`；事件统一进入 `ai.response.*.v1` envelope。

### Existing Go realtime boundary

Go 已有边界：

```text
internal/platform/realtime.Publisher
internal/platform/realtime.Publication
internal/platform/realtime.NewEnvelope
LocalPublisher / RedisPublisher / NoopPublisher
```

AI runtime 只能依赖 `realtime.Publisher`。禁止业务模块直接拿 gorilla websocket connection、Manager、Redis Pub/Sub client。

### Live DB facts

```text
ai_conversations: 55
ai_messages: 264
ai_runs: 154
ai_run_steps: 401
```

当前 active AI cron：

```text
cron_task.name = ai_run_timeout
handler/task type = ai:run-timeout:v1
status = 1
is_del = 2
```

这仍是 PHP handler。P4 完成前，不准写“Go owns ai_run_timeout”。

## Scope

### P3 必须迁 Go

```text
Conversation/message management:
ai_conversations
ai_messages

Chat runtime:
POST /api/admin/v1/ai-chat/runs
GET  /api/admin/v1/ai-chat/runs/:run_id/events
POST /api/admin/v1/ai-chat/messages
POST /api/admin/v1/ai-chat/runs/:run_id/cancel

Worker:
ai:run-execute:v1

Realtime:
ai.response.start.v1
ai.response.delta.v1
ai.response.completed.v1
ai.response.failed.v1
ai.response.cancel.v1
```

### P4 必须迁 Go

```text
Run monitor:
ai_runs
ai_run_steps

Cron:
ai_run_timeout -> ai:run-timeout:v1
```

P3/P4 可以连续实现，但文档口径必须分清：runtime worker 没落地前，runs 页面只读迁移不能冒充 chat runtime 完成。

### 明确不做

```text
不引入 Python sidecar。
不引入向量库。
不做 embedding worker。
不做多 agent 编排框架。
不重做 UI。
不恢复 admin chat/chat_* 表。
不支持 SSE；AI 回复统一走 WebSocket versioned envelope + REST 补拉。
不在 WebSocket handler 里跑模型或长任务。
```

## API Contract

### Conversations

```text
GET    /api/admin/v1/ai-conversations
GET    /api/admin/v1/ai-conversations/:id
POST   /api/admin/v1/ai-conversations
PUT    /api/admin/v1/ai-conversations/:id
PATCH  /api/admin/v1/ai-conversations/:id/status
DELETE /api/admin/v1/ai-conversations/:id
```

Rules:

```text
Default list scopes to current auth user unless admin monitor page explicitly sends user_id and has future permission.
P3 chat page uses current-user conversations only.
status accepts 1/2.
delete is soft delete.
```

### Messages

```text
GET    /api/admin/v1/ai-conversations/:conversation_id/messages
PATCH  /api/admin/v1/ai-messages/:id/content
PATCH  /api/admin/v1/ai-messages/:id/feedback
DELETE /api/admin/v1/ai-messages/:id
DELETE /api/admin/v1/ai-messages
```

Rules:

```text
Message role enum: 1=user, 2=assistant, 3=system.
List is scoped by conversation owner.
Edit content only for messages owned through current user's conversation.
Feedback updates meta_json.feedback to 1/2 or removes feedback when null.
Delete is soft delete.
Batch delete accepts { ids: number[] }, max 100.
```

### Runs monitor

```text
GET /api/admin/v1/ai-runs/page-init
GET /api/admin/v1/ai-runs
GET /api/admin/v1/ai-runs/:id
GET /api/admin/v1/ai-runs/stats
GET /api/admin/v1/ai-runs/stats/by-date
GET /api/admin/v1/ai-runs/stats/by-agent
GET /api/admin/v1/ai-runs/stats/by-user
```

Rules:

```text
Run status: 1 running, 2 success, 3 fail, 4 canceled.
Step type: 1 prompt, 2 RAG, 3 LLM, 4 tool_call, 5 tool_result, 6 finalize, 7 image.
Step status: 1 success, 2 fail.
Read-only monitor; no mutation endpoints here.
Stats date filters use date_start/date_end.
Detail returns run row, user_message, assistant_message, and steps ordered by step_no asc.
```

### Chat runtime

#### Start run

`POST /api/admin/v1/ai-chat/runs`

Request:

```ts
interface AiChatRunCreateRequest {
  content: string
  conversation_id?: number
  agent_id?: number
  max_history?: number
  attachments?: Array<{ type: 'image'; url: string; name: string; size: number }>
  temperature?: number
  max_tokens?: number
}
```

Response:

```ts
interface AiChatRunCreateResponse {
  conversation_id: number
  run_id: number
  request_id: string
  user_message_id: number
  agent_id: number
  is_new: boolean
}
```

Rules:

```text
content non-empty, max 10000 chars.
agent_id must reference active ai_agents.
If conversation_id absent, create ai_conversations for current user.
If conversation_id present, it must belong to current user and active.
Create user ai_messages row and ai_runs row in one DB transaction.
run_status starts as 1 running.
Enqueue ai:run-execute:v1 with run_id.
Publish ai.response.start.v1 to current user through realtime.Publisher.
```

#### Poll events

`GET /api/admin/v1/ai-chat/runs/:run_id/events?last_id=0-0&timeout_ms=50`

Response keeps current frontend polling shape for compatibility, but event names must align with versioned stream mapping:

```ts
interface AiChatRunEventsResponse {
  events: Array<{ id: string; event: string; data: Record<string, unknown> }>
  last_id: string
  run_status: number
  terminal: boolean
  error_msg: string
}
```

Rules:

```text
Events are reconstructed from persisted run/steps/messages or a small ai_run_events table if implementation adds it.
Do not depend on Redis stream as the only source of truth.
last_id format remains numeric-seq string, e.g. 1700000000000-0.
```

#### Send non-streaming message

`POST /api/admin/v1/ai-chat/messages`

First version can be a wrapper over run creation + wait-for-completion with a short timeout, or return the created run metadata. It must not call legacy PHP.

#### Cancel run

`POST /api/admin/v1/ai-chat/runs/:run_id/cancel`

Response:

```ts
interface AiChatCancelResponse { run_id: number; status: 'canceled' }
```

Rules:

```text
Run must belong to current user.
Only running run can transition to canceled.
Set run_status=4 and error_msg='用户取消'.
Publish ai.response.cancel.v1.
Worker must check cancel state before finalizing.
```

## Worker design

### `ai:run-execute:v1`

Payload:

```json
{ "run_id": 123 }
```

Minimal execution algorithm:

```text
1. Claim run where run_status=1.
2. Load conversation, active agent, active model.
3. Build prompt from system_prompt + recent messages + current user content.
4. Write run step: prompt.
5. If capabilities.rag and knowledge_base_ids exist, run MySQL keyword retrieval from P2 chunks; write RAG step.
6. Call provider through a small internal platform boundary; P3 can implement only one OpenAI-compatible text provider path if config exists.
7. Stream deltas through realtime.Publisher as ai.response.delta.v1 and persist enough event facts for polling replay.
8. Create assistant ai_messages row.
9. Mark run success with token/latency/model_snapshot and assistant_message_id.
10. Publish ai.response.completed.v1.
```

Failure algorithm:

```text
On validation/provider/tool error, mark run_status=3, write failed step if applicable, publish ai.response.failed.v1.
Never mark success when provider failed.
No goroutine without context cancellation.
```

### `ai:run-timeout:v1`

Rules:

```text
Replaces cron_task ai_run_timeout PHP handler.
Find ai_runs run_status=1 older than configured timeout, mark run_status=3 with timeout error.
Publish ai.response.failed.v1 to affected users when possible.
Register in crontask registry name ai_run_timeout -> task type ai:run-timeout:v1.
Only after this registration and smoke pass may docs say ai_run_timeout is Go-owned.
```

## Realtime event mapping

Backend publishes envelopes:

```text
ai.response.start.v1      data: { conversation_id, run_id, user_message_id, agent_id, is_new }
ai.response.delta.v1      data: { run_id, event_id, delta }
ai.response.completed.v1  data: { conversation_id, run_id, user_message_id, assistant_message_id, usage }
ai.response.failed.v1     data: { run_id, code, msg }
ai.response.cancel.v1     data: { run_id, status }
```

Frontend mapping to existing callbacks:

```text
start -> onConversation + onRun
delta -> onContent
completed -> onDone
failed -> onError
cancel -> onDone or onError depending current UX, but terminal=true either way
```

Old `ai_run_event` must be removed from active frontend code/tests.

## Verification gates

```powershell
cd E:\admin_go\admin_back_go
$env:GOMAXPROCS='2'
go test -p=1 ./internal/module/aiconversation ./internal/module/aimessage ./internal/module/airun ./internal/module/aichat ./internal/jobs ./internal/module/crontask ./internal/platform/realtime ./internal/server ./internal/bootstrap
go vet -p=1 ./internal/module/aiconversation ./internal/module/aimessage ./internal/module/airun ./internal/module/aichat ./internal/jobs
powershell -ExecutionPolicy Bypass -File .\scripts\check-contract.ps1

cd E:\admin_go\admin_front_ts
npx vitest run tests/shared/ai/ai-conversation-api.test.ts tests/shared/ai/ai-message-api.test.ts tests/shared/ai/ai-run-api.test.ts tests/shared/http/ai-stream-contract.test.ts tests/shared/http/ai-stream-websocket-contract.test.ts
npx vue-tsc -b --pretty false

cd E:\admin_go\admin_back_go
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account 15671628271 -Password 123456
```

Smoke 必须证明：

```text
Conversation/message/runs read endpoints return Go REST envelopes.
AiChat start/events/cancel endpoints use /api/admin/v1/ai-chat/*.
Frontend src/api/ai/conversations.ts/messages.ts/runs.ts/chat.ts contain no legacyRequest.
Frontend no longer listens to ai_run_event.
WebSocket event contract uses ai.response.*.v1.
cron registry shows ai_run_timeout registered as ai:run-timeout:v1 after P4.
```

## Status wording after implementation

P3 完成但 P4 未完成时，只能说：

```text
AI chat runtime first Go slice implemented; run monitor/timeout cron still pending.
```

P3+P4 全部验证后才允许说：

```text
AI chat/runtime/runs migrated to Go REST and Go worker.
```

禁止说：

```text
AI sidecar/vector/advanced RAG implemented.
All AI features complete if provider smoke did not actually run.
```

## Self-review

```text
Scope covers final live AI legacy APIs: conversations/messages/runs/chat.
No placeholder remains: endpoints, event names, worker task types, cron migration, and verification gates are explicit.
Runtime uses existing Publisher boundary and does not touch WebSocket internals.
```
