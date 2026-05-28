# AI Conversation Runtime Aggregation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` in the assigned backend worktree. Steps use checkbox (`- [ ]`) syntax for tracking. This plan is serial and must start only after Plans 14a, 14b, and 14c have been merged to backend `master` and pushed.

**Goal:** Move `aiconversation`, `aimessage`, `aichat`, and `airun` into `internal/module/ai/{conversation,message,chat,run}` while preserving the admin chat flow, realtime events, run monitor, and queue task contracts.

**Architecture:** This is the high-coupling AI runtime chain. Move the four subdomains together in one backend branch so `Send -> dispatch -> chat reply -> realtime -> messages/runs -> run monitor` can be verified end-to-end at code level. Keep package identifiers stable for this slice and use explicit import aliases.

**Tech Stack:** Go, Gin, GORM, taskqueue, realtime publisher, infra/ai, backend architecture tests, admin route snapshot, bootstrap dispatcher tests.

---

## Preconditions

Before starting this plan, verify backend master contains Plan 14a, 14b, and 14c:

```powershell
cd E:\admin_go\admin_back_go
git switch master
git pull --ff-only
git log --oneline -8
```

Expected recent commits include:

```text
refactor: aggregate AI provider agent tool modules
refactor: aggregate AI image module
refactor: aggregate AI knowledge module
```

If any of those commits is missing, stop and merge the missing plan first.

## Assigned worktree

```text
E:\admin_go_parallel\p15-ai-runtime
branch: work/p15-ai-runtime
```

Create it from current backend master after the preconditions pass:

```powershell
cd E:\admin_go\admin_back_go
git fetch origin
git switch master
git pull --ff-only
git worktree add E:\admin_go_parallel\p15-ai-runtime -b work/p15-ai-runtime master
```

Run all backend commands from `E:\admin_go_parallel\p15-ai-runtime`.

## Files

- Move directory: `internal/module/aiconversation` -> `internal/module/ai/conversation`
- Move directory: `internal/module/aimessage` -> `internal/module/ai/message`
- Move directory: `internal/module/aichat` -> `internal/module/ai/chat`
- Move directory: `internal/module/airun` -> `internal/module/ai/run`
- Modify: `internal/bootstrap/app.go`
- Modify: `internal/bootstrap/ai_reply_dispatcher.go`
- Modify: `internal/bootstrap/ai_reply_dispatcher_test.go`
- Modify: `internal/bootstrap/ai_openai_test.go`
- Modify: `internal/bootstrap/worker.go`
- Modify: `internal/jobs/noop.go`
- Modify: `internal/jobs/noop_test.go`
- Modify: `internal/module/crontask/registry.go`
- Modify: `internal/server/router.go`
- Modify: `internal/server/router_test.go`
- Modify: `internal/server/routes_admin_ai.go`
- Create: `internal/architecture/ai_runtime_aggregation_test.go`
- Do not modify root docs from this backend worktree.

## Non-negotiable behavior

```text
No DB schema changes.
No frontend changes.
No route URL changes.
No permission code changes.
No operation log rule changes.
Keep ai_conversations, ai_messages, ai_runs, ai_run_events table names.
Keep ai:conversation-reply:v1 and ai:run-timeout:v1 task types.
Keep realtime envelope events ai.response.start.v1, ai.response.delta.v1, ai.response.completed.v1, ai.response.failed.v1.
Keep /api/admin/v1/ai-conversations*, /api/admin/v1/ai-conversations/:id/messages*, and /api/admin/v1/ai-runs*.
Keep request_id as the cancellation/routing key.
Keep worker local realtime publisher noop semantics.
```

## Task 1: Add RED architecture guard

- [ ] Create `internal/architecture/ai_runtime_aggregation_test.go`:

```go
package architecture

import "testing"

func TestAIConversationRuntimeOwnedByAIModule(t *testing.T) {
	root := backendRoot(t)
	for _, rel := range []string{
		"internal/module/aiconversation",
		"internal/module/aimessage",
		"internal/module/aichat",
		"internal/module/airun",
	} {
		mustNotExist(t, root, rel)
	}
	for _, rel := range []string{
		"internal/module/ai/conversation/transport/admin/route.go",
		"internal/module/ai/message/transport/admin/route.go",
		"internal/module/ai/chat/transport/admin/route.go",
		"internal/module/ai/chat/jobs.go",
		"internal/module/ai/chat/events.go",
		"internal/module/ai/run/transport/admin/route.go",
	} {
		mustExist(t, root, rel)
	}
}
```

- [ ] Run RED:

```powershell
cd E:\admin_go_parallel\p15-ai-runtime
go test ./internal/architecture -run TestAIConversationRuntimeOwnedByAIModule -count=1
```

Expected before moving directories: FAIL because old top-level runtime directories still exist and new paths do not.

## Task 2: Move runtime directories with history

- [ ] Run:

```powershell
cd E:\admin_go_parallel\p15-ai-runtime
New-Item -ItemType Directory -Force .\internal\module\ai | Out-Null
git mv .\internal\module\aiconversation .\internal\module\ai\conversation
git mv .\internal\module\aimessage .\internal\module\ai\message
git mv .\internal\module\aichat .\internal\module\ai\chat
git mv .\internal\module\airun .\internal\module\ai\run
```

- [ ] Keep moved Go files as their existing package identifiers for this slice:

```text
conversation package remains aiconversation
message package remains aimessage
chat package remains aichat
run package remains airun
```

## Task 3: Update imports across runtime chain

- [ ] Replace old import paths:

```powershell
cd E:\admin_go_parallel\p15-ai-runtime
rg -l 'admin_back_go/internal/module/(aiconversation|aimessage|aichat|airun)' internal cmd | ForEach-Object {
  (Get-Content $_ -Raw) `
    -replace 'admin_back_go/internal/module/aiconversation', 'admin_back_go/internal/module/ai/conversation' `
    -replace 'admin_back_go/internal/module/aimessage', 'admin_back_go/internal/module/ai/message' `
    -replace 'admin_back_go/internal/module/aichat', 'admin_back_go/internal/module/ai/chat' `
    -replace 'admin_back_go/internal/module/airun', 'admin_back_go/internal/module/ai/run' |
    Set-Content -Encoding UTF8 $_
}
```

- [ ] Use explicit aliases where package identifiers differ from directory names:

```go
aiconversation "admin_back_go/internal/module/ai/conversation"
aimessage "admin_back_go/internal/module/ai/message"
aichat "admin_back_go/internal/module/ai/chat"
airun "admin_back_go/internal/module/ai/run"
```

- [ ] Verify `internal/bootstrap/ai_reply_dispatcher.go` still accepts `aimessage.ReplyPayload` and calls `aichat.ConversationReplyService`.

- [ ] Verify `internal/module/crontask/registry.go` still registers `ai_run_timeout` to enqueue `aichat.TypeRunTimeoutV1`.

## Task 4: Verify route and runtime contracts still compile

- [ ] Format touched Go files:

```powershell
cd E:\admin_go_parallel\p15-ai-runtime
gofmt -w .\internal\module\ai\conversation .\internal\module\ai\message .\internal\module\ai\chat .\internal\module\ai\run .\internal\bootstrap .\internal\jobs .\internal\module\crontask .\internal\server .\internal\architecture
```

- [ ] Confirm old imports and directories are gone:

```powershell
cd E:\admin_go_parallel\p15-ai-runtime
foreach ($p in @('aiconversation','aimessage','aichat','airun')) { if (Test-Path ".\internal\module\$p") { throw "internal/module/$p still exists" } }
rg -n 'admin_back_go/internal/module/(aiconversation|aimessage|aichat|airun)' internal cmd
```

Expected: `rg` returns no matches.

- [ ] Run focused runtime tests:

```powershell
cd E:\admin_go_parallel\p15-ai-runtime
go test ./internal/module/ai/conversation/... ./internal/module/ai/message/... ./internal/module/ai/chat/... ./internal/module/ai/run/... -count=1
go test ./internal/bootstrap -run 'AI|Reply|OpenAI' -count=1
go test ./internal/module/crontask -count=1
go test ./internal/jobs -count=1
go test ./internal/server -run TestAdminRouteSnapshot -count=1
go test ./internal/architecture -run TestAIConversationRuntimeOwnedByAIModule -count=1
```

## Task 5: Run full backend gate

- [ ] Run:

```powershell
cd E:\admin_go_parallel\p15-ai-runtime
go test ./internal/bootstrap ./internal/server ./internal/architecture -count=1
go test ./... -count=1
go build ./...
git diff --check
powershell -ExecutionPolicy Bypass -File E:\admin_go\scripts\check-agent-governance.ps1 -Mode working
```

## Task 6: Optional frontend AI contract check

- [ ] Run only from the frontend repo after backend focused tests pass:

```powershell
cd E:\admin_go\admin_front_ts
npm run typecheck
if (Test-Path .\tests\shared\ai) { npm run test -- tests/shared/ai } else { Write-Host 'tests/shared/ai not present; backend route snapshot is the route contract gate for this slice' }
```

- [ ] Record the exact result in the worker report.

## Task 7: Commit backend slice

- [ ] Review diff:

```powershell
cd E:\admin_go_parallel\p15-ai-runtime
git status --short
git diff --stat
```

- [ ] Commit:

```powershell
cd E:\admin_go_parallel\p15-ai-runtime
git add internal docs
git commit -m "refactor: aggregate AI conversation runtime modules"
```

- [ ] Final worker report must include changed files, commit SHA, verification commands, frontend check result, and remaining risks.
