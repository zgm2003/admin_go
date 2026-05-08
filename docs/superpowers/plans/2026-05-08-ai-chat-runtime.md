# AI Chat Runtime Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move AI conversations, messages, runs, chat streaming, and `ai_run_timeout` from PHP legacy to Go REST + Go worker + versioned WebSocket events.

**Architecture:** Build small Go modules for read/write state (`aiconversation`, `aimessage`, `airun`) and one runtime module (`aichat`) that owns run creation, event replay, cancel, worker execution, and realtime publication through `platform/realtime.Publisher`. Frontend API clients move to `/api/admin/v1/*`; WebSocket acceleration switches from unversioned `ai_run_event` to `ai.response.*.v1`.

**Tech Stack:** Go/Gin/GORM/MySQL/Asynq-style taskqueue, existing realtime Publisher, existing AI config modules, Vue 3 + TypeScript, Vitest, full-admin smoke.

---

## Master rules

```text
Migrate: ai_conversations, ai_messages, ai_runs, ai_run_steps, AiChat start/events/send/cancel, ai_run_timeout.
Do not migrate: deleted admin chat, SSE, Python sidecar, vector DB, new agent framework.
Business modules publish realtime envelopes through realtime.Publisher only.
No active frontend code may listen to ai_run_event after this plan.
```

## File map

### Create

```text
admin_back_go/internal/enum/ai_runtime_test.go

admin_back_go/internal/module/aiconversation/dto.go
admin_back_go/internal/module/aiconversation/model.go
admin_back_go/internal/module/aiconversation/request.go
admin_back_go/internal/module/aiconversation/repository.go
admin_back_go/internal/module/aiconversation/service.go
admin_back_go/internal/module/aiconversation/service_test.go
admin_back_go/internal/module/aiconversation/handler.go
admin_back_go/internal/module/aiconversation/handler_test.go
admin_back_go/internal/module/aiconversation/route.go

admin_back_go/internal/module/aimessage/dto.go
admin_back_go/internal/module/aimessage/model.go
admin_back_go/internal/module/aimessage/request.go
admin_back_go/internal/module/aimessage/repository.go
admin_back_go/internal/module/aimessage/service.go
admin_back_go/internal/module/aimessage/service_test.go
admin_back_go/internal/module/aimessage/handler.go
admin_back_go/internal/module/aimessage/handler_test.go
admin_back_go/internal/module/aimessage/route.go

admin_back_go/internal/module/airun/dto.go
admin_back_go/internal/module/airun/model.go
admin_back_go/internal/module/airun/request.go
admin_back_go/internal/module/airun/repository.go
admin_back_go/internal/module/airun/service.go
admin_back_go/internal/module/airun/service_test.go
admin_back_go/internal/module/airun/handler.go
admin_back_go/internal/module/airun/handler_test.go
admin_back_go/internal/module/airun/route.go

admin_back_go/internal/module/aichat/dto.go
admin_back_go/internal/module/aichat/model.go
admin_back_go/internal/module/aichat/request.go
admin_back_go/internal/module/aichat/events.go
admin_back_go/internal/module/aichat/events_test.go
admin_back_go/internal/module/aichat/repository.go
admin_back_go/internal/module/aichat/service.go
admin_back_go/internal/module/aichat/service_test.go
admin_back_go/internal/module/aichat/jobs.go
admin_back_go/internal/module/aichat/jobs_test.go
admin_back_go/internal/module/aichat/handler.go
admin_back_go/internal/module/aichat/handler_test.go
admin_back_go/internal/module/aichat/route.go

admin_front_ts/tests/shared/ai/ai-conversation-api.test.ts
admin_front_ts/tests/shared/ai/ai-message-api.test.ts
admin_front_ts/tests/shared/ai/ai-run-api.test.ts
```

### Modify

```text
admin_back_go/internal/enum/ai.go
admin_back_go/internal/dict/dict.go
admin_back_go/internal/dict/ai_test.go
admin_back_go/internal/jobs/noop.go
admin_back_go/internal/module/crontask/registry.go
admin_back_go/internal/module/crontask/registry_test.go
admin_back_go/internal/server/router.go
admin_back_go/internal/server/router_test.go
admin_back_go/internal/bootstrap/app.go
admin_back_go/internal/bootstrap/route_meta.go
admin_back_go/internal/bootstrap/route_meta_test.go
admin_back_go/scripts/full-admin-smoke.ps1

admin_front_ts/src/api/ai/conversations.ts
admin_front_ts/src/api/ai/messages.ts
admin_front_ts/src/api/ai/runs.ts
admin_front_ts/src/api/ai/chat.ts
admin_front_ts/src/lib/realtime/message-bus.ts
admin_front_ts/tests/shared/http/ai-stream-contract.test.ts
admin_front_ts/tests/shared/http/ai-stream-websocket-contract.test.ts

docs/contracts/admin-api-v1.md
docs/contracts/admin-realtime-v1.md
docs/migration/current-status.md
docs/testing/smoke-matrix.md
admin_back_go/docs/architecture.md
```

---

## Task 1: Extend runtime enums/dicts

**Files:**
- Modify: `admin_back_go/internal/enum/ai.go`
- Create: `admin_back_go/internal/enum/ai_runtime_test.go`
- Modify: `admin_back_go/internal/dict/dict.go`
- Modify: `admin_back_go/internal/dict/ai_test.go`

- [x] **Step 1: Add failing enum tests**

Create `ai_runtime_test.go`:

```go
package enum

import "testing"

func TestAIRuntimeEnumsAreStable(t *testing.T) {
	if !IsAIMessageRole(AIMessageRoleUser) || !IsAIMessageRole(AIMessageRoleAssistant) || !IsAIMessageRole(AIMessageRoleSystem) || IsAIMessageRole(9) { t.Fatalf("message role enum mismatch") }
	if !IsAIRunStatus(AIRunStatusRunning) || !IsAIRunStatus(AIRunStatusCanceled) || IsAIRunStatus(9) { t.Fatalf("run status enum mismatch") }
	if !IsAIRunStepType(AIRunStepTypePrompt) || !IsAIRunStepType(AIRunStepTypeFinalize) || IsAIRunStepType(99) { t.Fatalf("step type enum mismatch") }
	if !IsAIRunStepStatus(AIRunStepStatusSuccess) || !IsAIRunStepStatus(AIRunStepStatusFail) || IsAIRunStepStatus(9) { t.Fatalf("step status enum mismatch") }
}
```

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/enum -run TestAIRuntimeEnumsAreStable
```

Expected: fail before constants exist.

- [x] **Step 2: Implement constants/helpers**

Add:

```text
AIMessageRoleUser=1 Assistant=2 System=3
AIRunStatusRunning=1 Success=2 Fail=3 Canceled=4
AIRunStepTypePrompt=1 RAG=2 LLM=3 ToolCall=4 ToolResult=5 Finalize=6 Image=7
AIRunStepStatusSuccess=1 Fail=2
```

- [x] **Step 3: Add dict options tests and functions**

Add dict functions:

```text
AIMessageRoleOptions
AIRunStatusOptions
AIRunStepTypeOptions
AIRunStepStatusOptions
```

Verify:

```powershell
go test ./internal/enum ./internal/dict -count=1
```

Expected: pass.

---

## Task 2: Implement `aiconversation`

**Files:**
- Create: `admin_back_go/internal/module/aiconversation/*`

- [x] **Step 1: Write failing service tests**

Tests must prove:

```text
List scopes to current user by default.
Detail rejects conversation not owned by current user.
Create validates active agent id and sets current user.
Update title only for owner.
ChangeStatus validates 1/2 and owner.
Delete soft-deletes owner conversation.
```

Run:

```powershell
go test ./internal/module/aiconversation -count=1
```

Expected: fail.

- [x] **Step 2: Implement module**

Routes:

```text
GET    /api/admin/v1/ai-conversations
GET    /api/admin/v1/ai-conversations/:id
POST   /api/admin/v1/ai-conversations
PUT    /api/admin/v1/ai-conversations/:id
PATCH  /api/admin/v1/ai-conversations/:id/status
DELETE /api/admin/v1/ai-conversations/:id
```

List query supports `current_page/page_size/status/agent_id/title`.

- [x] **Step 3: Verify**

Run:

```powershell
go test ./internal/module/aiconversation -count=1
```

Expected: pass.

---

## Task 3: Implement `aimessage`

**Files:**
- Create: `admin_back_go/internal/module/aimessage/*`

- [x] **Step 1: Write failing service tests**

Tests must prove:

```text
List checks conversation ownership and supports role filter.
EditContent checks ownership and updates content only.
Feedback writes meta_json.feedback=1/2 and removes it when feedback is nil.
Delete one and batch delete soft-delete only messages under current user's conversations.
Batch ids max 100 and deduplicated.
```

Run:

```powershell
go test ./internal/module/aimessage -count=1
```

Expected: fail.

- [x] **Step 2: Implement module**

Routes:

```text
GET    /api/admin/v1/ai-conversations/:conversation_id/messages
PATCH  /api/admin/v1/ai-messages/:id/content
PATCH  /api/admin/v1/ai-messages/:id/feedback
DELETE /api/admin/v1/ai-messages/:id
DELETE /api/admin/v1/ai-messages
```

- [x] **Step 3: Verify**

Run:

```powershell
go test ./internal/module/aimessage -count=1
```

Expected: pass.

---

## Task 4: Implement `airun` read-only monitor

**Files:**
- Create: `admin_back_go/internal/module/airun/*`

- [x] **Step 1: Write failing service tests**

Tests must prove:

```text
Init returns run_status_arr and agentArr.
List filters run_status/user_id/request_id/agent_id/date_start/date_end and maps latency_str.
Detail returns user_message, assistant_message, and steps ordered by step_no asc.
Stats summary computes total_runs/success_rate/fail_runs/tokens/avg_latency.
Stats by date/agent/user are paginated and sorted.
```

Run:

```powershell
go test ./internal/module/airun -count=1
```

Expected: fail.

- [x] **Step 2: Implement routes**

Routes:

```text
GET /api/admin/v1/ai-runs/page-init
GET /api/admin/v1/ai-runs
GET /api/admin/v1/ai-runs/:id
GET /api/admin/v1/ai-runs/stats
GET /api/admin/v1/ai-runs/stats/by-date
GET /api/admin/v1/ai-runs/stats/by-agent
GET /api/admin/v1/ai-runs/stats/by-user
```

- [x] **Step 3: Verify**

Run:

```powershell
go test ./internal/module/airun -count=1
```

Expected: pass.

---

## Task 5: Implement `aichat` event model and runtime service

**Files:**
- Create: `admin_back_go/internal/module/aichat/*`

- [x] **Step 1: Write event tests**

Tests for `events.go` must prove:

```text
NewStreamEvent creates monotonic ids.
Start/Delta/Completed/Failed/Cancel envelope builders emit ai.response.*.v1.
Envelope data contains run_id and callback-required fields.
No builder emits ai_run_event.
```

Run:

```powershell
go test ./internal/module/aichat -run Test.*Event -count=1
```

Expected: fail.

- [x] **Step 2: Implement event builders**

Use `realtime.NewEnvelope` and define constants:

```go
EventAIResponseStart = "ai.response.start.v1"
EventAIResponseDelta = "ai.response.delta.v1"
EventAIResponseCompleted = "ai.response.completed.v1"
EventAIResponseFailed = "ai.response.failed.v1"
EventAIResponseCancel = "ai.response.cancel.v1"
```

- [x] **Step 3: Write service tests**

Tests must prove:

```text
CreateRun validates current user/content/agent.
CreateRun creates conversation when missing.
CreateRun creates user message + run in one transaction and enqueues ai:run-execute:v1.
CreateRun publishes start event through Publisher.
Events rejects run not owned by current user and returns replay events after last_id.
Cancel only cancels running owner run and publishes cancel event.
ExecuteRun marks success and creates assistant message in happy path with fake provider.
ExecuteRun marks fail and publishes failed event on provider error.
TimeoutRuns marks old running runs failed.
```

- [x] **Step 4: Implement repository/service**

Repository owns:

```text
ai_conversations
ai_messages
ai_runs
ai_run_steps
optional ai_run_events table only if repo already has migration pattern approved; otherwise reconstruct polling events from run state.
```

If adding `ai_run_events`, create migration with explicit table and indexes:

```text
run_id, event_id, event_type, payload_json, created_at
UNIQUE(run_id,event_id)
INDEX(run_id,id)
```

- [x] **Step 5: Implement jobs**

Constants:

```go
TypeRunExecuteV1 = "ai:run-execute:v1"
TypeRunTimeoutV1 = "ai:run-timeout:v1"
```

Task builders:

```go
NewRunExecuteTask(RunExecutePayload{RunID int64})
NewRunTimeoutTask(RunTimeoutPayload{Limit int})
```

Handlers call service methods and log summary.

- [x] **Step 6: Implement handler/routes**

Routes:

```text
POST /api/admin/v1/ai-chat/runs
GET  /api/admin/v1/ai-chat/runs/:run_id/events
POST /api/admin/v1/ai-chat/messages
POST /api/admin/v1/ai-chat/runs/:run_id/cancel
```

`POST /ai-chat/messages` may call CreateRun and return run metadata in first version; do not call legacy PHP.

- [x] **Step 7: Verify aichat**

Run:

```powershell
go test ./internal/module/aichat -count=1
```

Expected: pass.

---

## Task 6: Wire worker, cron registry, routes, and metadata

**Files:**
- Modify: `admin_back_go/internal/jobs/noop.go`
- Modify: `admin_back_go/internal/module/crontask/registry.go`
- Modify: `admin_back_go/internal/module/crontask/registry_test.go`
- Modify: `admin_back_go/internal/server/router.go`
- Modify: `admin_back_go/internal/server/router_test.go`
- Modify: `admin_back_go/internal/bootstrap/app.go`
- Modify: `admin_back_go/internal/bootstrap/route_meta.go`
- Modify: `admin_back_go/internal/bootstrap/route_meta_test.go`

- [x] **Step 1: Add route tests**

Assert routes exist:

```text
GET /api/admin/v1/ai-conversations
GET /api/admin/v1/ai-conversations/1/messages
GET /api/admin/v1/ai-runs/page-init
POST /api/admin/v1/ai-chat/runs
GET /api/admin/v1/ai-chat/runs/1/events
POST /api/admin/v1/ai-chat/runs/1/cancel
```

- [x] **Step 2: Wire bootstrap services**

Create repositories/services and pass:

```text
AiConversationService
AiMessageService
AiRunService
AiChatService
```

Inject `realtime.Publisher` and task enqueuer into `aichat.Service`.

- [x] **Step 3: Register jobs**

In `jobs.Register`, call:

```go
aichat.RegisterHandlers(mux, deps.AIChatService, logger)
```

Extend `jobs.Dependencies` with `AIChatService aichat.JobService`.

- [x] **Step 4: Register cron**

In `crontask.NewDefaultRegistry`, add:

```text
Name: ai_run_timeout
TaskType: ai:run-timeout:v1
Description: 标记超时 AI 运行失败
BuildTask: aichat.NewRunTimeoutTask(aichat.RunTimeoutPayload{})
```

Add registry test asserting lookup of `ai_run_timeout` returns `ai:run-timeout:v1`.

- [x] **Step 5: Route metadata**

Operation log rules:

```text
conversation create/update/status/delete
message edit/feedback/delete/batch_delete
chat create_run/send_message/cancel
```

Run monitor GET routes do not log operations. Chat run execute worker does not go through HTTP route meta.

Permission rules: leave current-user chat/conversation/message endpoints auth-scoped in P3 unless DB has button codes. Runs monitor read is page-level access via `/ai/runs`; do not invent missing button codes.

- [x] **Step 6: Verify backend wiring**

Run:

```powershell
go test ./internal/jobs ./internal/module/crontask ./internal/server ./internal/bootstrap -count=1
```

Expected: pass.

---

## Task 7: Switch frontend conversation/message/run/chat clients

**Files:**
- Create: `admin_front_ts/tests/shared/ai/ai-conversation-api.test.ts`
- Create: `admin_front_ts/tests/shared/ai/ai-message-api.test.ts`
- Create: `admin_front_ts/tests/shared/ai/ai-run-api.test.ts`
- Modify: `admin_front_ts/src/api/ai/conversations.ts`
- Modify: `admin_front_ts/src/api/ai/messages.ts`
- Modify: `admin_front_ts/src/api/ai/runs.ts`
- Modify: `admin_front_ts/src/api/ai/chat.ts`
- Modify: `admin_front_ts/src/lib/realtime/message-bus.ts`
- Modify: `admin_front_ts/tests/shared/http/ai-stream-contract.test.ts`
- Modify: `admin_front_ts/tests/shared/http/ai-stream-websocket-contract.test.ts`

- [x] **Step 1: Write failing source-contract tests**

Tests must assert:

```text
conversations.ts uses request + /ai-conversations REST and no legacyRequest.
messages.ts uses request + nested /ai-conversations/:id/messages and /ai-messages routes and no legacyRequest.
runs.ts uses request + /ai-runs REST and no legacyRequest.
chat.ts uses request + /ai-chat/runs endpoints and no legacyRequest.
chat.ts listens to ai.response.start.v1/delta/completed/failed/cancel, not ai_run_event.
message-bus MessageType includes ai.response.cancel.v1.
No touched API file contains /api/admin/AiConversations, /AiMessages, /AiRuns, /AiChat.
No any/as any/Record<string, any> in touched API files.
```

- [x] **Step 2: Rewrite conversations client**

Mapping:

```text
list -> GET /ai-conversations
detail -> GET /ai-conversations/:id
add -> POST /ai-conversations
edit -> PUT /ai-conversations/:id
status -> PATCH /ai-conversations/:id/status
del -> DELETE /ai-conversations/:id or Promise.all for array
```

- [x] **Step 3: Rewrite messages client**

Mapping:

```text
list -> GET /ai-conversations/:conversation_id/messages
editContent -> PATCH /ai-messages/:id/content
feedback -> PATCH /ai-messages/:id/feedback
del single -> DELETE /ai-messages/:id
del array -> DELETE /ai-messages body {ids}
```

- [x] **Step 4: Rewrite runs client**

Mapping:

```text
init -> GET /ai-runs/page-init
list -> GET /ai-runs
detail -> GET /ai-runs/:id
stats -> GET /ai-runs/stats
statsByDate -> GET /ai-runs/stats/by-date
statsByAgent -> GET /ai-runs/stats/by-agent
statsByUser -> GET /ai-runs/stats/by-user
```

- [x] **Step 5: Rewrite chat client**

Mapping:

```text
start -> POST /ai-chat/runs
events -> GET /ai-chat/runs/:run_id/events with params last_id/timeout_ms
send -> POST /ai-chat/messages
cancel -> POST /ai-chat/runs/:run_id/cancel
```

WebSocket subscriptions:

```text
ai.response.start.v1
ai.response.delta.v1
ai.response.completed.v1
ai.response.failed.v1
ai.response.cancel.v1
```

Update callback dispatch:

```text
delta.data.delta -> onContent
completed.data -> onDone
failed.data.msg -> onError
cancel.data -> terminal
```

- [x] **Step 6: Verify frontend**

Run:

```powershell
cd E:\admin_go\admin_front_ts
npx vitest run tests/shared/ai/ai-conversation-api.test.ts tests/shared/ai/ai-message-api.test.ts tests/shared/ai/ai-run-api.test.ts tests/shared/http/ai-stream-contract.test.ts tests/shared/http/ai-stream-websocket-contract.test.ts
npx vue-tsc -b --pretty false
```

Expected: pass.

---

## Task 8: Smoke and docs

**Files:**
- Modify: `admin_back_go/scripts/full-admin-smoke.ps1`
- Modify: `docs/contracts/admin-api-v1.md`
- Modify: `docs/contracts/admin-realtime-v1.md`
- Modify: `docs/migration/current-status.md`
- Modify: `docs/testing/smoke-matrix.md`
- Modify: `admin_back_go/docs/architecture.md`

- [x] **Step 1: Add read/runtime smoke probes**

Default smoke probes:

```text
GET /api/admin/v1/ai-conversations?current_page=1&page_size=5
GET /api/admin/v1/ai-runs/page-init
GET /api/admin/v1/ai-runs?current_page=1&page_size=5
GET /api/admin/v1/ai-runs/stats
cron registry status contains ai_run_timeout -> ai:run-timeout:v1
frontend contract residue checked by tests, not by smoke
```

Optional mutation probe behind `-EnableAiChatRuntimeProbe`:

```text
POST /api/admin/v1/ai-chat/runs with a controlled active agent
GET /api/admin/v1/ai-chat/runs/:run_id/events
POST /api/admin/v1/ai-chat/runs/:run_id/cancel if still running
```

Do not call real paid/provider model by default unless environment explicitly enables it.

- [x] **Step 2: Update API contract**

Add sections for:

```text
AI Conversations
AI Messages
AI Runs Monitor
AI Chat Runtime
AI Run Timeout Worker
```

State provider smoke boundary honestly.

- [x] **Step 3: Update realtime contract**

Change AI streaming status from design state to implemented only after frontend/backend tests pass. Document data shapes for start/delta/completed/failed/cancel and state that `ai_run_event` is removed.

- [x] **Step 4: Update current status and architecture**

Allowed final row:

```text
AI chat/runtime/runs: implemented Go REST for conversations/messages/runs/chat, worker task ai:run-execute:v1, timeout cron ai:run-timeout:v1; provider e2e is optional smoke depending on configured model credentials.
```

Do not claim vector RAG or sidecar.

---

## Task 9: Final verification

**Files:** no source changes unless a real verification failure is found.

- [x] **Step 1: Backend full focused verification**

Run:

```powershell
cd E:\admin_go\admin_back_go
$env:GOMAXPROCS='2'
go test -p=1 ./internal/enum ./internal/dict ./internal/module/aiconversation ./internal/module/aimessage ./internal/module/airun ./internal/module/aichat ./internal/jobs ./internal/module/crontask ./internal/platform/realtime ./internal/server ./internal/bootstrap
go vet -p=1 ./internal/module/aiconversation ./internal/module/aimessage ./internal/module/airun ./internal/module/aichat ./internal/jobs
powershell -ExecutionPolicy Bypass -File .\scripts\check-contract.ps1
git diff --check
```

Expected: exit 0.

- [x] **Step 2: Frontend verification**

Run:

```powershell
cd E:\admin_go\admin_front_ts
npx vitest run tests/shared/ai/ai-conversation-api.test.ts tests/shared/ai/ai-message-api.test.ts tests/shared/ai/ai-run-api.test.ts tests/shared/http/ai-stream-contract.test.ts tests/shared/http/ai-stream-websocket-contract.test.ts
npx vue-tsc -b --pretty false
git diff --check
```

Expected: exit 0.

- [x] **Step 3: Full smoke**

Run:

```powershell
cd E:\admin_go\admin_back_go
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account 15671628271 -Password 123456
```

Expected summary includes:

```text
ai_conversation_list_code=0
ai_run_init_code=0
ai_run_list_code=0
ai_run_stats_code=0
cron_task_ai_run_timeout_registered=true
cron_task_ai_run_timeout_type=ai:run-timeout:v1
```

- [x] **Step 4: Residue sweep**

Run:

```powershell
cd E:\admin_go
rg -n "legacyRequest|/api/admin/AiConversations|/api/admin/AiMessages|/api/admin/AiRuns|/api/admin/AiChat|ai_run_event|text/event-stream|EventSource" admin_front_ts/src/api/ai admin_front_ts/src/lib/realtime admin_back_go/internal docs/contracts
```

Expected:

```text
No active frontend API or realtime code uses legacy AI chat/runs paths.
No active contract advertises ai_run_event or SSE.
Historical docs/specs may mention old names only as migration notes.
```

## Commit plan

If asked to commit:

```powershell
git -C E:\admin_go\admin_back_go add internal/enum internal/dict internal/module/aiconversation internal/module/aimessage internal/module/airun internal/module/aichat internal/jobs internal/module/crontask internal/server internal/bootstrap scripts/full-admin-smoke.ps1 docs/architecture.md
git -C E:\admin_go\admin_back_go commit -m "feat: migrate ai chat runtime to go"

git -C E:\admin_go\admin_front_ts add src/api/ai/conversations.ts src/api/ai/messages.ts src/api/ai/runs.ts src/api/ai/chat.ts src/lib/realtime/message-bus.ts tests/shared/ai tests/shared/http/ai-stream-contract.test.ts tests/shared/http/ai-stream-websocket-contract.test.ts
git -C E:\admin_go\admin_front_ts commit -m "feat: switch ai runtime clients to go rest"

git -C E:\admin_go add docs/contracts/admin-api-v1.md docs/contracts/admin-realtime-v1.md docs/migration/current-status.md docs/testing/smoke-matrix.md docs/superpowers/specs/2026-05-08-ai-chat-runtime-design.md docs/superpowers/plans/2026-05-08-ai-chat-runtime.md
git -C E:\admin_go commit -m "docs: plan ai chat runtime migration"
```

## Self-review

```text
Spec coverage: conversations, messages, runs, chat start/events/send/cancel, worker execute, timeout cron, realtime events, frontend switch, smoke/docs are all mapped.
No placeholder text remains.
Plan keeps provider e2e optional and does not fake success without credentials.
```
