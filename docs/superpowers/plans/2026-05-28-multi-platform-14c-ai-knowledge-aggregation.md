# AI Knowledge Aggregation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` in the assigned backend worktree. Steps use checkbox (`- [ ]`) syntax for tracking. This plan may run in parallel with 14a and 14b, but integration to `master` must be sequential.

**Goal:** Move `aiknowledge` from a flat top-level module into `internal/module/ai/knowledge` while preserving knowledge-base admin APIs and the chat retrieval runtime adapter.

**Architecture:** This is a directory/package-boundary refactor only. Keep `package aiknowledge` for this slice and update imports with alias `aiknowledge "admin_back_go/internal/module/ai/knowledge"`. The management CRUD surface and the runtime retrieval interface move together so `aichat` retrieval stays wired.

**Tech Stack:** Go, Gin, GORM, knowledge retrieval service, backend bootstrap runtime adapter, backend architecture tests, admin route snapshot.

---

## Assigned worktree

```text
E:\admin_go_parallel\p14c-ai-knowledge
branch: work/p14c-ai-knowledge
```

Create it from current backend master:

```powershell
cd E:\admin_go\admin_back_go
git fetch origin
git switch master
git pull --ff-only
git worktree add E:\admin_go_parallel\p14c-ai-knowledge -b work/p14c-ai-knowledge master
```

Run all backend commands from `E:\admin_go_parallel\p14c-ai-knowledge`.

## Files

- Move directory: `internal/module/aiknowledge` -> `internal/module/ai/knowledge`
- Modify: `internal/bootstrap/app.go`
- Modify: `internal/server/router.go`
- Modify: `internal/server/router_test.go`
- Modify: `internal/server/routes_admin_ai.go`
- Create: `internal/architecture/ai_knowledge_aggregation_test.go`
- Do not modify root docs from this backend worktree.

## Non-negotiable behavior

```text
No DB schema changes.
No frontend changes.
No route URL changes.
No permission code changes.
No operation log rule changes.
Keep ai_knowledge_bases, ai_knowledge_documents, ai_knowledge_chunks, ai_agent_knowledge_bases, ai_knowledge_retrievals, ai_knowledge_retrieval_hits table names.
Keep /api/admin/v1/ai-knowledge-bases*, /api/admin/v1/ai-knowledge-documents*, and /api/admin/v1/ai-agents/:id/knowledge-bases.
Keep chat retrieval runtime before provider call.
```

## Task 1: Add RED architecture guard

- [ ] Create `internal/architecture/ai_knowledge_aggregation_test.go`:

```go
package architecture

import "testing"

func TestAIKnowledgeOwnedByAIModule(t *testing.T) {
	root := backendRoot(t)
	mustNotExist(t, root, "internal/module/aiknowledge")
	mustExist(t, root, "internal/module/ai/knowledge/transport/admin/route.go")
	mustExist(t, root, "internal/module/ai/knowledge/retriever.go")
}
```

- [ ] Run RED:

```powershell
cd E:\admin_go_parallel\p14c-ai-knowledge
go test ./internal/architecture -run TestAIKnowledgeOwnedByAIModule -count=1
```

Expected before moving directories: FAIL because `internal/module/aiknowledge` exists and `internal/module/ai/knowledge` does not.

## Task 2: Move directory with history

- [ ] Run:

```powershell
cd E:\admin_go_parallel\p14c-ai-knowledge
New-Item -ItemType Directory -Force .\internal\module\ai | Out-Null
git mv .\internal\module\aiknowledge .\internal\module\ai\knowledge
```

- [ ] Keep moved Go files as `package aiknowledge` for this slice.

## Task 3: Update imports and runtime adapter wiring

- [ ] Replace old import paths:

```powershell
cd E:\admin_go_parallel\p14c-ai-knowledge
rg -l 'admin_back_go/internal/module/aiknowledge' internal cmd | ForEach-Object {
  (Get-Content $_ -Raw) -replace 'admin_back_go/internal/module/aiknowledge', 'admin_back_go/internal/module/ai/knowledge' | Set-Content -Encoding UTF8 $_
}
```

- [ ] Ensure imports use the explicit alias where needed:

```go
aiknowledge "admin_back_go/internal/module/ai/knowledge"
```

- [ ] Verify `internal/bootstrap/app.go` still constructs the service and runtime adapter:

```go
aiKnowledgeService := aiknowledge.NewService(aiknowledge.NewGormRepository(resources.DB))
KnowledgeRuntime: aiKnowledgeRuntimeAdapter{service: aiKnowledgeService},
```

- [ ] Verify `internal/server/routes_admin_ai.go` still calls:

```go
aiknowledgeadmin.Register(router, deps.AiKnowledgeService)
```

## Task 4: Verify old path is gone and knowledge behavior tests pass

- [ ] Format touched Go files:

```powershell
cd E:\admin_go_parallel\p14c-ai-knowledge
gofmt -w .\internal\module\ai\knowledge .\internal\bootstrap .\internal\server .\internal\architecture
```

- [ ] Confirm old imports and directory are gone:

```powershell
cd E:\admin_go_parallel\p14c-ai-knowledge
if (Test-Path .\internal\module\aiknowledge) { throw 'internal/module/aiknowledge still exists' }
rg -n 'admin_back_go/internal/module/aiknowledge' internal cmd
```

Expected: `rg` returns no matches.

- [ ] Run focused tests:

```powershell
cd E:\admin_go_parallel\p14c-ai-knowledge
go test ./internal/module/ai/knowledge/... -count=1
go test ./internal/bootstrap -run 'AI|New' -count=1
go test ./internal/server -run TestAdminRouteSnapshot -count=1
go test ./internal/architecture -run TestAIKnowledgeOwnedByAIModule -count=1
```

## Task 5: Run full backend gate

- [ ] Run:

```powershell
cd E:\admin_go_parallel\p14c-ai-knowledge
go test ./internal/bootstrap ./internal/server ./internal/architecture -count=1
go test ./... -count=1
go build ./...
git diff --check
powershell -ExecutionPolicy Bypass -File E:\admin_go\scripts\check-agent-governance.ps1 -Mode working
```

## Task 6: Commit backend slice

- [ ] Review diff:

```powershell
cd E:\admin_go_parallel\p14c-ai-knowledge
git status --short
git diff --stat
```

- [ ] Commit:

```powershell
cd E:\admin_go_parallel\p14c-ai-knowledge
git add internal docs
git commit -m "refactor: aggregate AI knowledge module"
```

- [ ] Final worker report must include changed files, commit SHA, verification commands, and remaining risks.
