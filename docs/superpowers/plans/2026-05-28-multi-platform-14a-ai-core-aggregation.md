# AI Provider Agent Tool Aggregation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` in the assigned backend worktree. Steps use checkbox (`- [ ]`) syntax for tracking. This plan may run in parallel with 14b and 14c, but integration to `master` must be sequential.

**Goal:** Move `aiprovider`, `aiagent`, and `aitool` from flat top-level modules into `internal/module/ai/{provider,agent,tool}` while preserving all admin AI provider/agent/tool behavior.

**Architecture:** This is a directory/package-boundary refactor only. Keep package identifiers stable in the first slice and use import aliases at call sites. Keep `aichat` tool runtime behavior working by updating its import from the old `aitool` path to the new `ai/tool` path.

**Tech Stack:** Go, Gin, GORM, secretbox, infra/ai, backend architecture tests, admin route snapshot.

---

## Assigned worktree

```text
E:\admin_go_parallel\p14a-ai-core
branch: work/p14a-ai-core
```

Create it from current backend master:

```powershell
cd E:\admin_go\admin_back_go
git fetch origin
git switch master
git pull --ff-only
git worktree add E:\admin_go_parallel\p14a-ai-core -b work/p14a-ai-core master
```

Run all backend commands from `E:\admin_go_parallel\p14a-ai-core`.

## Files

- Move directory: `internal/module/aiprovider` -> `internal/module/ai/provider`
- Move directory: `internal/module/aiagent` -> `internal/module/ai/agent`
- Move directory: `internal/module/aitool` -> `internal/module/ai/tool`
- Modify: `internal/bootstrap/app.go`
- Modify: `internal/bootstrap/ai_openai_test.go`
- Modify: `internal/module/aichat/dto.go`
- Modify: `internal/server/router.go`
- Modify: `internal/server/router_test.go`
- Modify: `internal/server/routes_admin_ai.go`
- Create: `internal/architecture/ai_core_aggregation_test.go`
- Modify backend docs only if present and directly naming old AI module paths: `docs/architecture.md`, `internal/module/README.md`
- Do not modify root docs from this backend worktree.

## Non-negotiable behavior

```text
No DB schema changes.
No frontend changes.
No route URL changes.
No permission code changes.
No operation log rule changes.
No i18n key/text changes in this slice.
Keep ai_providers, ai_provider_models, ai_agents, ai_tools, ai_agent_tools, ai_tool_calls table names.
Keep /api/admin/v1/ai-providers*, /api/admin/v1/ai-agents*, /api/admin/v1/ai-tools*, and /api/admin/v1/ai-agents/:id/tools.
```

## Task 1: Add RED architecture guard

- [ ] Create `internal/architecture/ai_core_aggregation_test.go`:

```go
package architecture

import "testing"

func TestAICoreModulesOwnedByAIModule(t *testing.T) {
	root := backendRoot(t)
	for _, rel := range []string{
		"internal/module/aiprovider",
		"internal/module/aiagent",
		"internal/module/aitool",
	} {
		mustNotExist(t, root, rel)
	}
	for _, rel := range []string{
		"internal/module/ai/provider/transport/admin/route.go",
		"internal/module/ai/agent/transport/admin/route.go",
		"internal/module/ai/tool/transport/admin/route.go",
	} {
		mustExist(t, root, rel)
	}
}
```

- [ ] Run RED:

```powershell
cd E:\admin_go_parallel\p14a-ai-core
go test ./internal/architecture -run TestAICoreModulesOwnedByAIModule -count=1
```

Expected before moving directories: FAIL because the old top-level directories still exist and the new paths do not exist.

## Task 2: Move directories with history

- [ ] Run:

```powershell
cd E:\admin_go_parallel\p14a-ai-core
New-Item -ItemType Directory -Force .\internal\module\ai | Out-Null
git mv .\internal\module\aiprovider .\internal\module\ai\provider
git mv .\internal\module\aiagent .\internal\module\ai\agent
git mv .\internal\module\aitool .\internal\module\ai\tool
```

- [ ] Keep the moved package declarations unchanged for this slice:

```text
internal/module/ai/provider/*.go remains package aiprovider
internal/module/ai/agent/*.go remains package aiagent
internal/module/ai/tool/*.go remains package aitool
```

## Task 3: Update imports and central registration

- [ ] Replace old import paths:

```powershell
cd E:\admin_go_parallel\p14a-ai-core
rg -l 'admin_back_go/internal/module/aiprovider|admin_back_go/internal/module/aiagent|admin_back_go/internal/module/aitool' internal cmd | ForEach-Object {
  (Get-Content $_ -Raw) `
    -replace 'admin_back_go/internal/module/aiprovider', 'admin_back_go/internal/module/ai/provider' `
    -replace 'admin_back_go/internal/module/aiagent', 'admin_back_go/internal/module/ai/agent' `
    -replace 'admin_back_go/internal/module/aitool', 'admin_back_go/internal/module/ai/tool' |
    Set-Content -Encoding UTF8 $_
}
```

- [ ] In files that import these packages, keep aliases explicit when the package name no longer matches the final directory segment:

```go
aiprovider "admin_back_go/internal/module/ai/provider"
aiagent "admin_back_go/internal/module/ai/agent"
aitool "admin_back_go/internal/module/ai/tool"
```

- [ ] Verify `internal/server/routes_admin_ai.go` still registers the same routes in this order:

```go
aiprovideradmin.Register(router, deps.AiProviderService)
aiagentadmin.Register(router, deps.AiAgentService)
aitooladmin.Register(router, deps.AiToolService)
```

- [ ] Verify `internal/module/aichat/dto.go` imports tool runtime types from:

```go
aitool "admin_back_go/internal/module/ai/tool"
```

## Task 4: Verify old paths are gone and focused packages pass

- [ ] Format touched Go files:

```powershell
cd E:\admin_go_parallel\p14a-ai-core
gofmt -w .\internal\module\ai\provider .\internal\module\ai\agent .\internal\module\ai\tool .\internal\module\aichat .\internal\bootstrap .\internal\server .\internal\architecture
```

- [ ] Confirm old imports and directories are gone:

```powershell
cd E:\admin_go_parallel\p14a-ai-core
if (Test-Path .\internal\module\aiprovider) { throw 'internal/module/aiprovider still exists' }
if (Test-Path .\internal\module\aiagent) { throw 'internal/module/aiagent still exists' }
if (Test-Path .\internal\module\aitool) { throw 'internal/module/aitool still exists' }
rg -n 'admin_back_go/internal/module/(aiprovider|aiagent|aitool)' internal cmd
```

Expected: `rg` returns no matches.

- [ ] Run focused tests:

```powershell
cd E:\admin_go_parallel\p14a-ai-core
go test ./internal/module/ai/provider/... ./internal/module/ai/agent/... ./internal/module/ai/tool/... -count=1
go test ./internal/module/aichat/... -count=1
go test ./internal/bootstrap -run AI -count=1
go test ./internal/server -run TestAdminRouteSnapshot -count=1
go test ./internal/architecture -run TestAICoreModulesOwnedByAIModule -count=1
```

## Task 5: Run full backend gate

- [ ] Run:

```powershell
cd E:\admin_go_parallel\p14a-ai-core
go test ./internal/bootstrap ./internal/server ./internal/architecture -count=1
go test ./... -count=1
go build ./...
git diff --check
powershell -ExecutionPolicy Bypass -File E:\admin_go\scripts\check-agent-governance.ps1 -Mode working
```

## Task 6: Commit backend slice

- [ ] Review diff:

```powershell
cd E:\admin_go_parallel\p14a-ai-core
git status --short
git diff --stat
```

- [ ] Commit:

```powershell
cd E:\admin_go_parallel\p14a-ai-core
git add internal docs
git commit -m "refactor: aggregate AI provider agent tool modules"
```

- [ ] Final worker report must include changed files, commit SHA, verification commands, and remaining risks.
