# PHP Legacy Migration Closure Design

状态：implemented first closure on 2026-05-08。本文记录今天 PHP legacy 模块迁移收口的总 spec；User closure、AI agent/knowledge、AI chat/runtime/runs 已完成第一版 Go REST/worker/realtime/docs/smoke 闭环。`forgetPassword` 是显式 account-security legacy 例外；真实外部 LLM provider、RAG/vector sidecar、tool execution 仍是后续凭证/专项工作。

## Linus 三问

1. 真问题：是。迁移前 active legacy scan 显示 AI conversations/messages/runs/chat 走 PHP action path；当前 active scan 必须只允许 `users.forgetPassword` 作为显式非 AI 例外。
2. 更简单做法：只收口仍被当前前端调用的 PHP API。已迁的 User closure 和 AI agent/knowledge 不重写，直接补齐文档、smoke、最终门禁。
3. 会破坏什么：不能破坏登录、菜单、RBAC、AI chat 流式体验；不能复活已删除 admin chat；不能把 PHP `/list` `/add` `/edit` `/del` 风格搬进 Go REST。

## Source of truth

按冲突优先级：

```text
1. live code / focused tests
2. current-status / contract / smoke docs
3. slice specs/plans
4. legacy PHP source as business reference only
```

关联切片：

```text
docs/superpowers/specs/2026-05-08-user-legacy-closure-design.md
docs/superpowers/plans/2026-05-08-user-legacy-closure.md

docs/superpowers/specs/2026-05-08-ai-agent-knowledge-management-design.md
docs/superpowers/plans/2026-05-08-ai-agent-knowledge-management.md

docs/superpowers/specs/2026-05-08-ai-chat-runtime-design.md
docs/superpowers/plans/2026-05-08-ai-chat-runtime.md
```

## Current closure map

| Slice | Current state | Remaining boundary / release gate |
| --- | --- | --- |
| User legacy closure | Code implemented for quick-entry, login-log, session revoke; focused backend tests pass in current run. `forgetPassword` is the only deliberate account-security legacy exception. | Re-run final user frontend/API gates during release verification. |
| AI agent + knowledge management | Code implemented for Go modules and frontend clients; focused backend and Vitest gates pass in current run. | Sync contract/current-status/smoke wording and include in final release gates. |
| AI chat/runtime/runs | Implemented first slice in Go: backend modules `aiconversation`, `aimessage`, `airun`, `aichat`, worker jobs, `ai_run_timeout -> ai:run-timeout:v1`, frontend typed clients, and versioned WebSocket events are active. | Keep real LLM provider/RAG/vector/tool execution as separate credential-gated future work. |
| Residue sweep | Active AI legacy scan returns no active AI PHP path, no `ai_run_event`, no SSE/EventSource. | `users.forgetPassword` remains the explicit public auth legacy exception unless a separate account-security slice is approved. |

Current decisive residue:

```text
active AI residue gate: no /api/admin/Ai* action paths, no ai_run_event, no text/event-stream/EventSource in active AI code.
explicit non-AI exception: admin_front_ts/src/api/user/users.ts keeps /api/Users/forgetPassword until account-security slice.
```

## Acceptance boundary for "all PHP module migration"

今天的默认闭环是：

```text
Go-owned admin modules:
User closure
AI config P1
AI agent/knowledge P2
AI chat/runtime/runs P3/P4
```

不把下面内容混进 AI runtime：

```text
Public forgot-password flow: /api/Users/forgetPassword
```

原因：它是 auth/account-security 公共入口，不是 AI/PHP module 收口的一部分。最终 residue 报告必须把它显式列为 allowed legacy exception；如果产品口径改成“绝对零 legacyRequest”，它必须单独开一个 account-security forgot-password spec/plan，不能藏在 AI runtime 里顺手改。

## API shape that must exist after closure

AI management:

```text
GET    /api/admin/v1/ai-agents/page-init
GET    /api/admin/v1/ai-agents
POST   /api/admin/v1/ai-agents
PUT    /api/admin/v1/ai-agents/:id
PATCH  /api/admin/v1/ai-agents/:id/status
DELETE /api/admin/v1/ai-agents/:id

GET    /api/admin/v1/ai-knowledge-bases/page-init
GET    /api/admin/v1/ai-knowledge-bases
GET    /api/admin/v1/ai-knowledge-bases/:id
POST   /api/admin/v1/ai-knowledge-bases
PUT    /api/admin/v1/ai-knowledge-bases/:id
PATCH  /api/admin/v1/ai-knowledge-bases/:id/status
DELETE /api/admin/v1/ai-knowledge-bases/:id
GET    /api/admin/v1/ai-knowledge-bases/:id/documents
POST   /api/admin/v1/ai-knowledge-bases/:id/documents
GET    /api/admin/v1/ai-knowledge-bases/:id/documents/:document_id
PUT    /api/admin/v1/ai-knowledge-bases/:id/documents/:document_id
DELETE /api/admin/v1/ai-knowledge-bases/:id/documents/:document_id
POST   /api/admin/v1/ai-knowledge-bases/:id/documents/:document_id/reindex
GET    /api/admin/v1/ai-knowledge-bases/:id/chunks
POST   /api/admin/v1/ai-knowledge-bases/:id/retrieval-test
```

AI runtime:

```text
GET    /api/admin/v1/ai-conversations
GET    /api/admin/v1/ai-conversations/:id
POST   /api/admin/v1/ai-conversations
PUT    /api/admin/v1/ai-conversations/:id
PATCH  /api/admin/v1/ai-conversations/:id/status
DELETE /api/admin/v1/ai-conversations/:id

GET    /api/admin/v1/ai-conversations/:conversation_id/messages
PATCH  /api/admin/v1/ai-messages/:id/content
PATCH  /api/admin/v1/ai-messages/:id/feedback
DELETE /api/admin/v1/ai-messages/:id
DELETE /api/admin/v1/ai-messages

GET    /api/admin/v1/ai-runs/page-init
GET    /api/admin/v1/ai-runs
GET    /api/admin/v1/ai-runs/:id
GET    /api/admin/v1/ai-runs/stats
GET    /api/admin/v1/ai-runs/stats/by-date
GET    /api/admin/v1/ai-runs/stats/by-agent
GET    /api/admin/v1/ai-runs/stats/by-user

POST   /api/admin/v1/ai-chat/runs
GET    /api/admin/v1/ai-chat/runs/:run_id/events
POST   /api/admin/v1/ai-chat/messages
POST   /api/admin/v1/ai-chat/runs/:run_id/cancel
```

Worker and realtime:

```text
ai:run-execute:v1
ai:run-timeout:v1
cron_task.name=ai_run_timeout -> ai:run-timeout:v1

ai.response.start.v1
ai.response.delta.v1
ai.response.completed.v1
ai.response.failed.v1
ai.response.cancel.v1
```

## Non-goals

```text
No SSE.
No EventSource.
No Python sidecar in this closure.
No vector DB or embedding worker.
No restored admin chat/chat_* tables.
No WeChat/refund payment runtime.
No silent PHP-compatible Go adapter for /api/admin/AiChat/*.
```

## Verification contract

Focused backend:

```powershell
cd E:\admin_go\admin_back_go
$env:GOMAXPROCS='2'
go test -p=1 ./internal/enum ./internal/dict ./internal/module/aiagent ./internal/module/aiknowledge ./internal/module/aiconversation ./internal/module/aimessage ./internal/module/airun ./internal/module/aichat ./internal/jobs ./internal/module/crontask ./internal/platform/realtime ./internal/server ./internal/bootstrap -count=1
go vet -p=1 ./internal/module/aiagent ./internal/module/aiknowledge ./internal/module/aiconversation ./internal/module/aimessage ./internal/module/airun ./internal/module/aichat ./internal/jobs
powershell -ExecutionPolicy Bypass -File .\scripts\check-contract.ps1
git diff --check
```

Focused frontend:

```powershell
cd E:\admin_go\admin_front_ts
npx vitest run tests/shared/ai/ai-agent-api.test.ts tests/shared/ai/ai-knowledge-api.test.ts tests/shared/ai/ai-conversation-api.test.ts tests/shared/ai/ai-message-api.test.ts tests/shared/ai/ai-run-api.test.ts tests/shared/http/ai-stream-contract.test.ts tests/shared/http/ai-stream-websocket-contract.test.ts --pool=threads
npx vue-tsc -b --pretty false
npm run build
git diff --check
```

Residue:

```powershell
cd E:\admin_go
rg -n "legacyRequest|/api/admin/AiAgents|/api/admin/AiKnowledgeBases|/api/admin/AiConversations|/api/admin/AiMessages|/api/admin/AiRuns|/api/admin/AiChat|ai_run_event|text/event-stream|EventSource" admin_front_ts/src/api/ai admin_front_ts/src/lib/realtime admin_back_go/internal docs/contracts docs/migration docs/testing
```

Expected:

```text
No active AI PHP path.
No active ai_run_event.
No active SSE/EventSource contract.
Only allowed non-AI legacy exception, if not separately migrated: /api/Users/forgetPassword.
```

## Status wording

迁移前/门禁未通过时只允许说：

```text
AI agent/knowledge focused migration is landed; AI chat/runtime is still pending.
```

After all gates pass, say:

```text
Admin AI PHP legacy runtime paths are migrated to Go REST + Go worker + versioned WebSocket events.
```

Do not say:

```text
全部测试通过
AI sidecar/vector/RAG fully implemented
zero legacyRequest
```

unless the exact commands and residue sweep prove it.
