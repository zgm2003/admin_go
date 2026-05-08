# PHP Legacy Migration Closure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the remaining active PHP legacy admin module calls so the project can enter full testing with truthful docs and reproducible gates.

**Architecture:** Treat the closure as three narrow slices, not one giant rewrite: User closure and AI agent/knowledge were landed/finalized first; AI chat/runtime/runs was the last large implementation slice and is now closed as the first Go runtime slice. New Go endpoints use `/api/admin/v1/*`; no PHP action-path adapters are created.

**Tech Stack:** Go/Gin/GORM/MySQL/Asynq-style taskqueue, existing realtime `Publisher`, Vue 3 + TypeScript, Vitest source-contract tests, repo smoke scripts.

---

## Execution status

当前收口状态：implemented and verified on 2026-05-08。User closure、AI agent/knowledge、AI chat/runtime/runs 三个窄切片已落到 Go REST/worker/realtime/docs/smoke；`forgetPassword` 是显式保留的 account-security legacy 例外。最终验证命令见 Task 8。

Earlier focused verification already run in this session:

```powershell
cd E:\admin_go\admin_back_go
$env:GOMAXPROCS='2'
go test -p=1 ./internal/enum ./internal/dict ./internal/module/aiagent ./internal/module/aiknowledge ./internal/module/session ./internal/module/userquickentry ./internal/module/userloginlog ./internal/module/usersession ./internal/server ./internal/bootstrap -count=1
```

Result: pass.

```powershell
cd E:\admin_go\admin_front_ts
npx vitest run tests/shared/ai/ai-agent-api.test.ts tests/shared/ai/ai-knowledge-api.test.ts --pool=threads
```

Result: pass.

Original active code gap before execution, now closed by this plan:

```text
admin_back_go/internal/module/aiconversation  absent before execution
admin_back_go/internal/module/aimessage       absent before execution
admin_back_go/internal/module/airun           absent before execution
admin_back_go/internal/module/aichat          absent before execution

admin_front_ts/src/api/ai/conversations.ts    legacy-backed before execution
admin_front_ts/src/api/ai/messages.ts         legacy-backed before execution
admin_front_ts/src/api/ai/runs.ts             legacy-backed before execution
admin_front_ts/src/api/ai/chat.ts             legacy-backed before execution + ai_run_event
```

## Master rules

```text
Do not reset the dirty workspace.
Do not touch admin.sql unless explicitly requested.
Do not migrate PHP action paths into Go.
Do not mark a doc row implemented until focused tests and at least the documented release gate are true.
Do not say "zero legacy" while /api/Users/forgetPassword remains allowed.
```

## File map

### Existing slice specs/plans

```text
docs/superpowers/specs/2026-05-08-user-legacy-closure-design.md
docs/superpowers/plans/2026-05-08-user-legacy-closure.md
docs/superpowers/specs/2026-05-08-ai-agent-knowledge-management-design.md
docs/superpowers/plans/2026-05-08-ai-agent-knowledge-management.md
docs/superpowers/specs/2026-05-08-ai-chat-runtime-design.md
docs/superpowers/plans/2026-05-08-ai-chat-runtime.md
```

### Create for AI runtime

```text
admin_back_go/internal/module/aiconversation/dto.go
admin_back_go/internal/module/aiconversation/model.go
admin_back_go/internal/module/aiconversation/request.go
admin_back_go/internal/module/aiconversation/repository.go
admin_back_go/internal/module/aiconversation/service.go
admin_back_go/internal/module/aiconversation/service_test.go
admin_back_go/internal/module/aiconversation/handler.go
admin_back_go/internal/module/aiconversation/route.go

admin_back_go/internal/module/aimessage/dto.go
admin_back_go/internal/module/aimessage/model.go
admin_back_go/internal/module/aimessage/request.go
admin_back_go/internal/module/aimessage/repository.go
admin_back_go/internal/module/aimessage/service.go
admin_back_go/internal/module/aimessage/service_test.go
admin_back_go/internal/module/aimessage/handler.go
admin_back_go/internal/module/aimessage/route.go

admin_back_go/internal/module/airun/dto.go
admin_back_go/internal/module/airun/model.go
admin_back_go/internal/module/airun/request.go
admin_back_go/internal/module/airun/repository.go
admin_back_go/internal/module/airun/service.go
admin_back_go/internal/module/airun/service_test.go
admin_back_go/internal/module/airun/handler.go
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
admin_back_go/internal/module/aichat/route.go

admin_front_ts/tests/shared/ai/ai-conversation-api.test.ts
admin_front_ts/tests/shared/ai/ai-message-api.test.ts
admin_front_ts/tests/shared/ai/ai-run-api.test.ts
```

### Modify

```text
admin_back_go/internal/jobs/noop.go
admin_back_go/internal/module/crontask/registry.go
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

## Task 1: Freeze baseline and do not expand scope

- [x] **Step 1: Capture dirty workspace**

Run:

```powershell
cd E:\admin_go
git status --short
git -C admin_back_go status --short
git -C admin_front_ts status --short
```

Expected:

```text
Existing uncommitted docs/code remain visible.
admin.sql remains untracked and untouched.
```

- [x] **Step 2: Re-run focused landed-slice gates**

Run:

```powershell
cd E:\admin_go\admin_back_go
$env:GOMAXPROCS='2'
go test -p=1 ./internal/enum ./internal/dict ./internal/module/aiagent ./internal/module/aiknowledge ./internal/module/session ./internal/module/userquickentry ./internal/module/userloginlog ./internal/module/usersession ./internal/server ./internal/bootstrap -count=1

cd E:\admin_go\admin_front_ts
npx vitest run tests/shared/ai/ai-agent-api.test.ts tests/shared/ai/ai-knowledge-api.test.ts --pool=threads
```

Expected: both exit 0. If either fails, stop and fix before AI runtime.

---

## Task 2: Finalize User closure as already landed

- [x] **Step 1: Re-run user frontend contract**

Run:

```powershell
cd E:\admin_go\admin_front_ts
npx vitest run tests/shared/user/users-api.test.ts --pool=threads
```

Expected:

```text
usersQuickEntry.ts contains no legacyRequest.
usersLoginLog.ts contains no legacyRequest.
users.ts does not call /api/admin/UserSession/kick or batchKick.
users.ts may still contain /api/Users/forgetPassword as the explicit account-security exception.
```

- [x] **Step 2: Keep docs honest**

Confirm:

```powershell
cd E:\admin_go
rg -n "user legacy closure|forgetPassword|quick-entries|users/login-logs|user-sessions/.+:id/revoke|user-sessions/revoke" docs/migration/current-status.md docs/contracts/admin-api-v1.md docs/testing/smoke-matrix.md
```

Expected: user closure is documented as implemented, and `forgetPassword` is not hidden.

---

## Task 3: Finalize AI agent/knowledge management docs and smoke

- [x] **Step 1: Sync API contract**

Update `docs/contracts/admin-api-v1.md` so AI P2 has a dedicated section with these exact endpoint groups:

```text
AI Agent Management:
GET/GET/POST/PUT/PATCH/DELETE /api/admin/v1/ai-agents...

AI Knowledge Management:
GET/GET/GET/POST/PUT/PATCH/DELETE /api/admin/v1/ai-knowledge-bases...
documents/chunks/retrieval-test nested routes
```

Required wording:

```text
goods_script, cine_project, cine_keyframe are retired and must not appear in active selectable scene options.
Knowledge source types are manual/text only.
retrieval-test is deterministic MySQL keyword scoring, not vector search.
```

- [x] **Step 2: Sync current status**

Update `docs/migration/current-status.md` with a separate row:

```text
Module: AI agent / knowledge management
Go backend status: implemented focused, routes registered under /api/admin/v1/ai-agents and /api/admin/v1/ai-knowledge-bases
Frontend status: adapted, agents.ts and knowledge.ts use request not legacyRequest
Tests: enum/dict + aiagent + aiknowledge + server/bootstrap + Vitest API tests
Smoke: pending until full-admin-smoke includes read probes
Remaining risk: no vector search; chat/runtime/runs still separate
```

- [x] **Step 3: Add smoke probes**

Modify `admin_back_go/scripts/full-admin-smoke.ps1` to probe:

```text
GET /api/admin/v1/ai-agents/page-init
GET /api/admin/v1/ai-agents?current_page=1&page_size=10
GET /api/admin/v1/ai-knowledge-bases/page-init
GET /api/admin/v1/ai-knowledge-bases?current_page=1&page_size=10
POST /api/admin/v1/ai-knowledge-bases/:id/retrieval-test when a row with chunks exists
```

Summary keys:

```text
ai_agent_init_code
ai_agent_list_code
ai_agent_retired_scene_present
ai_knowledge_init_code
ai_knowledge_list_code
ai_knowledge_retrieval_code
```

- [x] **Step 4: Verify landed P2 slice**

Run:

```powershell
cd E:\admin_go\admin_back_go
$env:GOMAXPROCS='2'
go test -p=1 ./internal/enum ./internal/dict ./internal/module/aiagent ./internal/module/aiknowledge ./internal/server ./internal/bootstrap -count=1

cd E:\admin_go\admin_front_ts
npx vitest run tests/shared/ai/ai-agent-api.test.ts tests/shared/ai/ai-knowledge-api.test.ts --pool=threads
```

Expected: exit 0.

---

## Task 4: Implement AI runtime backend modules

Use `docs/superpowers/plans/2026-05-08-ai-chat-runtime.md` as the implementation sub-plan.

- [x] **Step 1: Implement `aiconversation`**

Endpoints:

```text
GET    /api/admin/v1/ai-conversations
GET    /api/admin/v1/ai-conversations/:id
POST   /api/admin/v1/ai-conversations
PUT    /api/admin/v1/ai-conversations/:id
PATCH  /api/admin/v1/ai-conversations/:id/status
DELETE /api/admin/v1/ai-conversations/:id
```

Must prove:

```text
default list scopes to current user
detail/update/status/delete reject conversations owned by another user
create validates active agent id
delete is soft delete
```

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/aiconversation -count=1
```

- [x] **Step 2: Implement `aimessage`**

Endpoints:

```text
GET    /api/admin/v1/ai-conversations/:conversation_id/messages
PATCH  /api/admin/v1/ai-messages/:id/content
PATCH  /api/admin/v1/ai-messages/:id/feedback
DELETE /api/admin/v1/ai-messages/:id
DELETE /api/admin/v1/ai-messages
```

Must prove:

```text
message list checks conversation ownership
edit content checks ownership
feedback writes/removes meta_json.feedback
batch delete max 100, deduplicates ids, and only affects owned conversations
```

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/aimessage -count=1
```

- [x] **Step 3: Implement `airun` monitor**

Endpoints:

```text
GET /api/admin/v1/ai-runs/page-init
GET /api/admin/v1/ai-runs
GET /api/admin/v1/ai-runs/:id
GET /api/admin/v1/ai-runs/stats
GET /api/admin/v1/ai-runs/stats/by-date
GET /api/admin/v1/ai-runs/stats/by-agent
GET /api/admin/v1/ai-runs/stats/by-user
```

Must prove:

```text
dicts come from enum/dict
detail returns run + user_message + assistant_message + steps ordered by step_no asc
stats filters use date_start/date_end
monitor routes are read-only
```

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/airun -count=1
```

- [x] **Step 4: Implement `aichat` runtime**

Endpoints:

```text
POST /api/admin/v1/ai-chat/runs
GET  /api/admin/v1/ai-chat/runs/:run_id/events
POST /api/admin/v1/ai-chat/messages
POST /api/admin/v1/ai-chat/runs/:run_id/cancel
```

Task types:

```text
ai:run-execute:v1
ai:run-timeout:v1
```

Must prove:

```text
start creates conversation when absent
start validates existing conversation owner when present
start writes user message and running run in one DB transaction
execute worker writes assistant message and completed event
cancel marks running run canceled and publishes ai.response.cancel.v1
events endpoint returns versioned event names
```

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/aichat -count=1
```

---

## Task 5: Wire runtime into Go app, worker, cron, and metadata

- [x] **Step 1: Register routes**

Modify `admin_back_go/internal/server/router.go` and tests so these route families install:

```text
/api/admin/v1/ai-conversations
/api/admin/v1/ai-messages
/api/admin/v1/ai-runs
/api/admin/v1/ai-chat
```

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/server -run TestRouterInstalls -count=1
```

- [x] **Step 2: Register bootstrap services**

Modify `admin_back_go/internal/bootstrap/app.go` so services are constructed once and passed through `server.Dependencies`.

Expected dependency boundary:

```text
aichat depends on repositories, taskqueue producer, and realtime.Publisher
aichat does not depend on websocket manager or gin.Context
```

- [x] **Step 3: Register jobs and cron**

Modify:

```text
admin_back_go/internal/jobs/noop.go
admin_back_go/internal/module/crontask/registry.go
admin_back_go/internal/module/crontask/registry_test.go
```

Required mappings:

```text
ai:run-execute:v1
ai:run-timeout:v1
cron_task.name=ai_run_timeout -> ai:run-timeout:v1
```

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/jobs ./internal/module/crontask ./internal/bootstrap -run "AI|Register|Route" -count=1
```

- [x] **Step 4: Add route metadata**

Modify `admin_back_go/internal/bootstrap/route_meta.go`.

Rules:

```text
Current-user conversation/message/chat routes are bearer-auth scoped.
Run monitor read routes are read-only; do not invent missing permission codes.
Mutating chat runtime routes get OperationLog metadata only if they represent user-visible actions worth auditing.
```

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/bootstrap -run "PermissionRouteRules|OperationRouteRules|AuthOnly" -count=1
```

---

## Task 6: Switch AI runtime frontend clients

- [x] **Step 1: Add source-contract tests**

Create or update:

```text
admin_front_ts/tests/shared/ai/ai-conversation-api.test.ts
admin_front_ts/tests/shared/ai/ai-message-api.test.ts
admin_front_ts/tests/shared/ai/ai-run-api.test.ts
admin_front_ts/tests/shared/http/ai-stream-contract.test.ts
admin_front_ts/tests/shared/http/ai-stream-websocket-contract.test.ts
```

Required assertions:

```text
No /api/admin/AiConversations
No /api/admin/AiMessages
No /api/admin/AiRuns
No /api/admin/AiChat
No ai_run_event
No legacyRequest in active ai runtime API clients
Uses /api/admin/v1/ai-conversations
Uses /api/admin/v1/ai-chat/runs
Uses ai.response.start.v1/delta/completed/failed/cancel
```

- [x] **Step 2: Rewrite API clients**

Modify:

```text
admin_front_ts/src/api/ai/conversations.ts
admin_front_ts/src/api/ai/messages.ts
admin_front_ts/src/api/ai/runs.ts
admin_front_ts/src/api/ai/chat.ts
admin_front_ts/src/lib/realtime/message-bus.ts
```

Required mapping:

```text
AiConversationApi.list    -> GET /api/admin/v1/ai-conversations
AiConversationApi.detail  -> GET /api/admin/v1/ai-conversations/:id
AiConversationApi.add     -> POST /api/admin/v1/ai-conversations
AiConversationApi.edit    -> PUT /api/admin/v1/ai-conversations/:id
AiConversationApi.status  -> PATCH /api/admin/v1/ai-conversations/:id/status
AiConversationApi.del     -> DELETE /api/admin/v1/ai-conversations/:id

AiMessageApi.list         -> GET /api/admin/v1/ai-conversations/:conversation_id/messages
AiMessageApi.editContent  -> PATCH /api/admin/v1/ai-messages/:id/content
AiMessageApi.feedback     -> PATCH /api/admin/v1/ai-messages/:id/feedback
AiMessageApi.del          -> DELETE /api/admin/v1/ai-messages/:id or DELETE /api/admin/v1/ai-messages

AiRunApi.init             -> GET /api/admin/v1/ai-runs/page-init
AiRunApi.list             -> GET /api/admin/v1/ai-runs
AiRunApi.detail           -> GET /api/admin/v1/ai-runs/:id
AiRunApi.stats            -> GET /api/admin/v1/ai-runs/stats
AiRunApi.statsByDate      -> GET /api/admin/v1/ai-runs/stats/by-date
AiRunApi.statsByAgent     -> GET /api/admin/v1/ai-runs/stats/by-agent
AiRunApi.statsByUser      -> GET /api/admin/v1/ai-runs/stats/by-user

AiChatApi.stream start    -> POST /api/admin/v1/ai-chat/runs
AiChatApi.poll events     -> GET /api/admin/v1/ai-chat/runs/:run_id/events
AiChatApi.send            -> POST /api/admin/v1/ai-chat/messages
AiChatApi.cancel          -> POST /api/admin/v1/ai-chat/runs/:run_id/cancel
```

- [x] **Step 3: Verify frontend runtime clients**

Run:

```powershell
cd E:\admin_go\admin_front_ts
npx vitest run tests/shared/ai/ai-conversation-api.test.ts tests/shared/ai/ai-message-api.test.ts tests/shared/ai/ai-run-api.test.ts tests/shared/http/ai-stream-contract.test.ts tests/shared/http/ai-stream-websocket-contract.test.ts --pool=threads
npx vue-tsc -b --pretty false
```

Expected: exit 0.

---

## Task 7: Sync docs and smoke after AI runtime

- [x] **Step 1: Update contracts**

Modify:

```text
docs/contracts/admin-api-v1.md
docs/contracts/admin-realtime-v1.md
```

Required status:

```text
AI agent/knowledge management: implemented
AI chat/runtime/runs: implemented only after backend/frontend/runtime gates pass
AI streaming events: implemented with ai.response.*.v1
SSE/EventSource: not supported
```

- [x] **Step 2: Update current status and backend architecture**

Modify:

```text
docs/migration/current-status.md
admin_back_go/docs/architecture.md
```

Required wording:

```text
ai_run_timeout is Go-owned only after cron registry and smoke prove ai:run-timeout:v1.
AI runtime is Go REST + worker + realtime Publisher boundary.
No Python sidecar/vector DB in this slice.
```

- [x] **Step 3: Extend full smoke**

Modify `admin_back_go/scripts/full-admin-smoke.ps1` to include read/runtime probes:

```text
GET /api/admin/v1/ai-conversations?current_page=1&page_size=10
GET /api/admin/v1/ai-runs/page-init
GET /api/admin/v1/ai-runs?current_page=1&page_size=10
GET /api/admin/v1/ai-runs/stats
cron registry gate for ai_run_timeout -> ai:run-timeout:v1
```

Do not make default smoke call a real paid/external model provider. Runtime provider E2E must be explicit and credential-gated.

---

## Task 8: Final gates before entering full testing

- [x] **Step 1: Backend gate**

Run:

```powershell
cd E:\admin_go\admin_back_go
$env:GOMAXPROCS='2'
go test -p=1 ./...
go vet -p=1 ./...
powershell -ExecutionPolicy Bypass -File .\scripts\check-contract.ps1
git diff --check
```

Expected: exit 0.

- [x] **Step 2: Frontend gate**

Run:

```powershell
cd E:\admin_go\admin_front_ts
npx vitest run tests/shared/ai/ai-agent-api.test.ts tests/shared/ai/ai-knowledge-api.test.ts tests/shared/ai/ai-conversation-api.test.ts tests/shared/ai/ai-message-api.test.ts tests/shared/ai/ai-run-api.test.ts tests/shared/http/ai-stream-contract.test.ts tests/shared/http/ai-stream-websocket-contract.test.ts tests/shared/user/users-api.test.ts --pool=threads
npx vue-tsc -b --pretty false
npm run build
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
ai_agent_init_code=0
ai_agent_list_code=0
ai_agent_retired_scene_present=false
ai_knowledge_init_code=0
ai_knowledge_list_code=0
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
rg -n "legacyRequest|/api/admin/AiAgents|/api/admin/AiKnowledgeBases|/api/admin/AiConversations|/api/admin/AiMessages|/api/admin/AiRuns|/api/admin/AiChat|ai_run_event|text/event-stream|EventSource" admin_front_ts/src/api/ai admin_front_ts/src/lib/realtime admin_back_go/internal docs/contracts docs/migration docs/testing
rg -n "legacyRequest" admin_front_ts/src/api
```

Expected:

```text
First command returns no active AI legacy path.
Second command may return only src/api/user/users.ts /api/Users/forgetPassword unless a separate forgot-password slice is implemented.
```

---

## Task 9: Optional absolute-zero legacy decision

Only run this if the product requirement is literally no `legacyRequest` anywhere in `admin_front_ts/src/api`.

- [ ] **Step 1: Open separate account-security forgot-password spec**

Create:

```text
docs/superpowers/specs/2026-05-08-forgot-password-go-migration-design.md
docs/superpowers/plans/2026-05-08-forgot-password-go-migration.md
```

Minimum contract:

```text
POST /api/admin/v1/auth/forgot-password
```

Required checks:

```text
does not weaken captcha/code validation
does not break password login
does not expose whether account exists unless current product already does
does not change profile/security password flow
```

- [x] **Step 2: Do not hide it inside AI runtime**

If this slice is not implemented today, final status must say:

```text
AI/admin PHP legacy migration is closed; forgot-password remains the explicit public auth legacy exception.
```

## Self-review

```text
Spec coverage: user closure, AI agent/knowledge, AI chat/runtime/runs, docs/smoke/final gates, and residue handling are covered.
No placeholder remains: every task names files, endpoints, commands, and expected outcomes.
Scope stayed narrow: existing landed slices were finalized first; runtime modules are now implemented; absolute-zero legacy remains isolated behind the optional forgot-password decision.
```
