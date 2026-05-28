# AI Aggregation Map Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` for Plan 13 itself. This plan is docs-only. Do not edit production Go/Vue code while executing this map. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert the nine flat AI modules into a verified dependency map and produce safe follow-up execution slices for aggregating them under `internal/module/ai/*` without changing admin behavior.

**Architecture:** Keep AI as one backend capability with subdomain packages, not one giant package. Target shape is `internal/module/ai/{provider,agent,tool,image,knowledge,conversation,message,chat,run}` with each subdomain retaining its own `transport/admin` where it has HTTP routes. Existing admin routes, DB tables, queue task types, realtime envelope events, permissions, and response payloads are preserved.

**Tech Stack:** Go, Gin, GORM, taskqueue, realtime Redis publisher, backend architecture tests, admin route snapshot, root governance checker.

---

## Current verified baseline

```text
Plan 11 shared package migration: done.
Plan 12a profile/userquickentry aggregation: merged to backend master and pushed.
Plan 12b notification task aggregation: merged to backend master and pushed.
Plan 12c exporttask directory rename: merged to backend master and pushed.
Plan 12d authplatform directory rename: merged to backend master and pushed.
Root docs record the 12a-12d wave.
```

Current root/backend heads verified before writing this map:

```text
E:\admin_go master == origin/master @ 8b8ac1c
E:\admin_go\admin_back_go master == origin/master @ 3e88c30
```

Remaining Phase 2 aggregation scope:

```text
AI flat modules -> internal/module/ai/*
wallet/payment ownership decision -> later Plan 16
Phase 2 final guard/docs/spec closure -> later Plan 17
```

## Target AI directory shape

```text
internal/module/ai/
  provider/       # was aiprovider; keeps ai_providers + ai_provider_models contracts
  agent/          # was aiagent; keeps ai_agents and provider/model option contracts
  tool/           # was aitool; keeps ai_tools + ai_agent_tools + ai_tool_calls and runtime ToolRuntime
  image/          # was aiimage; keeps image task/asset queue contracts
  knowledge/      # was aiknowledge; keeps knowledge CRUD and chat retrieval runtime
  conversation/   # was aiconversation; keeps conversation list/create/delete/update contracts
  message/        # was aimessage; keeps send/cancel/list and reply dispatcher contract
  chat/           # was aichat; keeps reply runtime, run writes, websocket events, queue task types
  run/            # was airun; keeps monitor/stat/detail read contracts
```

Initial implementation slices may keep Go package identifiers such as `package aiprovider`, `package aiagent`, `package aitool`, `package aiimage`, and `package aiknowledge` to reduce churn. Import aliases must keep call sites readable, for example:

```go
aiprovider "admin_back_go/internal/module/ai/provider"
aiagent "admin_back_go/internal/module/ai/agent"
aitool "admin_back_go/internal/module/ai/tool"
```

A later cleanup may rename package identifiers only after the aggregation is stable. Do not combine package renaming with directory aggregation.

## Dependency map

### Provider / Agent / Tool core

| Subdomain | Current module | Tables | Admin routes | Permissions / operation contracts | Runtime dependency |
|---|---|---|---|---|---|
| provider | `internal/module/aiprovider` | `ai_providers`, `ai_provider_models` | `/api/admin/v1/ai-providers*` | `ai_provider_add`, `ai_provider_edit`, `ai_provider_test`, `ai_provider_status`, `ai_provider_del` | `infra/ai`, `secretbox`, provider model preview/sync |
| agent | `internal/module/aiagent` | `ai_agents`, reads `ai_providers`, `ai_provider_models` | `/api/admin/v1/ai-agents*` | `ai_agent_add`, `ai_agent_edit`, `ai_agent_test`, `ai_agent_status`, `ai_agent_del` | provider runtime validation and decrypted provider API key |
| tool | `internal/module/aitool` | `ai_tools`, `ai_agent_tools`, `ai_tool_calls`, reads `ai_agents`, reads `users` for built-in executor | `/api/admin/v1/ai-tools*`, `/api/admin/v1/ai-agents/:id/tools` | `ai_tool_generate`, `ai_tool_add`, `ai_tool_edit`, `ai_tool_status`, `ai_tool_del`, `ai_agent_edit` on tool binding | `aichat` imports tool runtime DTO/interface and invokes `ToolRuntime` |

Provider/agent/tool are safe as one implementation slice. They share bootstrap/server injection and the tool runtime import consumed by chat; splitting them into separate worktrees would create more merge conflicts than time savings.

### Image / Knowledge side branches

| Subdomain | Current module | Tables | Admin routes | Queue/runtime | Parallel safety |
|---|---|---|---|---|
| image | `internal/module/aiimage` | `ai_image_tasks`, `ai_image_assets`, `ai_image_task_assets`; reads `ai_agents`, `ai_providers`, `ai_provider_models` | `/api/admin/v1/ai-images*` | `ai:image-generate:v1`, low queue | Can run in parallel with Plan 14a; merge shared route/bootstrap edits sequentially |
| knowledge | `internal/module/aiknowledge` | `ai_knowledge_bases`, `ai_knowledge_documents`, `ai_knowledge_chunks`, `ai_agent_knowledge_bases`, `ai_knowledge_retrievals`, `ai_knowledge_retrieval_hits` | `/api/admin/v1/ai-knowledge-*`, `/api/admin/v1/ai-agents/:id/knowledge-bases` | `aichat` runtime adapter retrieves context before provider call | Management CRUD can move in parallel; runtime adapter must be verified with chat tests |

### Conversation runtime chain

| Subdomain | Current module | Tables | Routes/events/tasks | Coupling |
|---|---|---|---|---|
| conversation | `internal/module/aiconversation` | `ai_conversations`, soft-deletes `ai_messages` | `/api/admin/v1/ai-conversations*` | Owns list/detail/create/update/delete of current user's conversations |
| message | `internal/module/aimessage` | `ai_messages`, `ai_conversations` | `GET/POST /api/admin/v1/ai-conversations/:id/messages`, `POST /cancel` | `Send` writes user message then invokes reply enqueuer/dispatcher; `Cancel` invokes reply canceler |
| chat | `internal/module/aichat` | `ai_conversations`, `ai_messages`, `ai_runs`, `ai_run_events`; reads `ai_agents`, `ai_providers` | no active HTTP route; queue `ai:conversation-reply:v1`, `ai:run-timeout:v1`; realtime `ai.response.start/delta/completed/failed.v1` | Highest-risk chain: reply execution, run lifecycle, assistant message persistence, realtime publish |
| run | `internal/module/airun` | `ai_runs`, `ai_run_events`; reads `ai_tool_calls`, `ai_knowledge_retrievals`, `ai_knowledge_retrieval_hits`, `ai_conversations`, `ai_messages`, `ai_agents`, `users` | `/api/admin/v1/ai-runs*`; cron `ai_run_timeout -> ai:run-timeout:v1` | Read monitor depends on chat/tool/knowledge audit semantics |

This chain must be one serial plan after 14a/14b/14c are merged, because the decisive admin feature is the end-to-end chat flow:

```text
aimessage.Send -> reply enqueuer/dispatcher -> aichat.ExecuteConversationReply -> realtime.Publish -> ai_messages/ai_runs -> airun monitor
```

## Non-negotiable external contracts

Do not change these while aggregating directories:

```text
HTTP routes:
  /api/admin/v1/ai-providers*
  /api/admin/v1/ai-agents*
  /api/admin/v1/ai-tools*
  /api/admin/v1/ai-agents/:id/tools
  /api/admin/v1/ai-images*
  /api/admin/v1/ai-knowledge-bases*
  /api/admin/v1/ai-knowledge-documents*
  /api/admin/v1/ai-agents/:id/knowledge-bases
  /api/admin/v1/ai-conversations*
  /api/admin/v1/ai-conversations/:id/messages*
  /api/admin/v1/ai-runs*

Queue task types:
  ai:conversation-reply:v1
  ai:run-timeout:v1
  ai:image-generate:v1

Realtime envelope events:
  ai.response.start.v1
  ai.response.delta.v1
  ai.response.completed.v1
  ai.response.failed.v1

DB table names and semantics:
  ai_providers, ai_provider_models, ai_agents
  ai_tools, ai_agent_tools, ai_tool_calls
  ai_image_tasks, ai_image_assets, ai_image_task_assets
  ai_knowledge_bases, ai_knowledge_documents, ai_knowledge_chunks
  ai_agent_knowledge_bases, ai_knowledge_retrievals, ai_knowledge_retrieval_hits
  ai_conversations, ai_messages, ai_runs, ai_run_events

Runtime semantics:
  ai_runs represents one reply attempt.
  ai_run_events stores lifecycle events, not stream deltas.
  final assistant content is persisted in ai_messages.
  request_id remains the cancellation/routing key for chat replies.
  worker local realtime publisher remains noop; cross-process fan-out depends on REALTIME_PUBLISHER=redis.
```

## Follow-up execution slices

Run after this map is reviewed:

```text
Plan 14a: provider + agent + tool aggregation into internal/module/ai/{provider,agent,tool}
Plan 14b: image aggregation into internal/module/ai/image
Plan 14c: knowledge aggregation into internal/module/ai/knowledge
Plan 15: conversation + message + chat + run serial aggregation into internal/module/ai/{conversation,message,chat,run}
Plan 16: wallet/payment ownership decision and first safe slice
Plan 17: final Phase 2 guard/docs/spec closure review
```

## Parallel worktree policy

Plans 14a/14b/14c may be executed in parallel worktrees, but merge them to backend `master` one at a time and run the full backend gate after each merge. They all touch at least one central file such as `internal/bootstrap/app.go`, `internal/server/router.go`, or `internal/server/routes_admin_ai.go`, so parallel execution saves implementation time but not integration verification.

Recommended worktrees:

```powershell
cd E:\admin_go\admin_back_go
git fetch origin
git switch master
git pull --ff-only
git worktree add E:\admin_go_parallel\p14a-ai-core -b work/p14a-ai-core master
git worktree add E:\admin_go_parallel\p14b-ai-image -b work/p14b-ai-image master
git worktree add E:\admin_go_parallel\p14c-ai-knowledge -b work/p14c-ai-knowledge master
```

If any target path already exists, do not delete it blindly. Run `git worktree list`, inspect the path, and either reuse it only when it is clean and on the intended branch or choose a new path with a clear suffix.

## Required gates after every AI aggregation slice

```powershell
cd <assigned backend worktree>
go test ./internal/architecture -count=1
go test ./internal/server -run TestAdminRouteSnapshot -count=1
go test ./internal/bootstrap ./internal/server -count=1
go test ./... -count=1
go build ./...
git diff --check
powershell -ExecutionPolicy Bypass -File E:\admin_go\scripts\check-agent-governance.ps1 -Mode working
```

When a slice touches chat/send/cancel/realtime behavior, also run:

```powershell
cd <assigned backend worktree>
go test ./internal/module/ai/chat/... ./internal/module/ai/message/... ./internal/module/ai/run/... -count=1
go test ./internal/bootstrap -run AI -count=1
```

When a slice changes a route binding, also run frontend AI contract tests if the files exist:

```powershell
cd E:\admin_go\admin_front_ts
npm run typecheck
npm run test -- tests/shared/ai
```

If `tests/shared/ai` does not exist in the frontend repo, record that fact in the worker report and rely on backend route snapshot plus typecheck for that slice.

## Task 1: Confirm map against code before implementation

- [ ] From `E:\admin_go\admin_back_go`, run:

```powershell
rg -n 'admin_back_go/internal/module/(aiprovider|aiagent|aitool|aiimage|aiknowledge|aiconversation|aimessage|aichat|airun)' internal cmd
rg -n 'ai:conversation-reply:v1|ai:run-timeout:v1|ai:image-generate:v1|ai.response.' internal
rg -n '/api/admin/v1/ai-' internal/module internal/server internal/bootstrap
```

- [ ] Compare the output with the tables above. If a new runtime dependency appears, update this plan before writing code.

## Task 2: Execute follow-up plan files only after this map is committed

- [ ] Start with Plan 14a/14b/14c in separate backend worktrees.
- [ ] Merge each completed backend branch into `admin_back_go/master` one at a time.
- [ ] Push backend master only after the required gates pass on master.
- [ ] Update root Phase 2 docs only from `E:\admin_go`, then commit and push root docs.
