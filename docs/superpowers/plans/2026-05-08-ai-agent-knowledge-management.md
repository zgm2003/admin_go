# AI Agent and Knowledge Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate AI agent and knowledge-base management from PHP legacy endpoints to Go REST while keeping chat/runtime/model execution out of scope.

**Architecture:** Extend the AI enum/dict foundation, then add two focused Go modules: `aiagent` owns agent rows plus tool/knowledge/scene bindings; `aiknowledge` owns knowledge bases, documents, deterministic MySQL chunks, and keyword retrieval tests. Frontend changes are limited to `src/api/ai/agents.ts` and `src/api/ai/knowledge.ts` plus source-contract tests.

**Tech Stack:** Go/Gin/GORM/MySQL, existing enum/dict/validate/response/operationlog middleware, Vue 3 + TypeScript, existing `request` HTTP client, Vitest, full-admin smoke.

---

## Master rules

```text
Migrate: ai_agents, ai_agent_scenes, ai_assistant_tools, ai_agent_knowledge_bases, ai_knowledge_bases, ai_knowledge_documents, ai_knowledge_chunks.
Do not migrate: ai_conversations, ai_messages, ai_runs, ai_run_steps, AiChat runtime, model execution, WebSocket streaming.
Never return retired goods/cine scenes as active selectable options.
Never create /api/admin/AiAgents/* or /api/admin/AiKnowledgeBases/* Go adapters.
```

## File map

### Create

```text
admin_back_go/internal/module/aiagent/dto.go
admin_back_go/internal/module/aiagent/model.go
admin_back_go/internal/module/aiagent/request.go
admin_back_go/internal/module/aiagent/repository.go
admin_back_go/internal/module/aiagent/service.go
admin_back_go/internal/module/aiagent/service_test.go
admin_back_go/internal/module/aiagent/handler.go
admin_back_go/internal/module/aiagent/handler_test.go
admin_back_go/internal/module/aiagent/route.go

admin_back_go/internal/module/aiknowledge/dto.go
admin_back_go/internal/module/aiknowledge/model.go
admin_back_go/internal/module/aiknowledge/request.go
admin_back_go/internal/module/aiknowledge/chunker.go
admin_back_go/internal/module/aiknowledge/chunker_test.go
admin_back_go/internal/module/aiknowledge/retrieval.go
admin_back_go/internal/module/aiknowledge/retrieval_test.go
admin_back_go/internal/module/aiknowledge/repository.go
admin_back_go/internal/module/aiknowledge/service.go
admin_back_go/internal/module/aiknowledge/service_test.go
admin_back_go/internal/module/aiknowledge/handler.go
admin_back_go/internal/module/aiknowledge/handler_test.go
admin_back_go/internal/module/aiknowledge/route.go

admin_front_ts/tests/shared/ai/ai-agent-api.test.ts
admin_front_ts/tests/shared/ai/ai-knowledge-api.test.ts
```

### Modify

```text
admin_back_go/internal/enum/ai.go
admin_back_go/internal/enum/ai_test.go
admin_back_go/internal/dict/dict.go
admin_back_go/internal/dict/ai_test.go
admin_back_go/internal/server/router.go
admin_back_go/internal/server/router_test.go
admin_back_go/internal/bootstrap/app.go
admin_back_go/internal/bootstrap/route_meta.go
admin_back_go/internal/bootstrap/route_meta_test.go
admin_back_go/scripts/full-admin-smoke.ps1

admin_front_ts/src/api/ai/agents.ts
admin_front_ts/src/api/ai/knowledge.ts

docs/contracts/admin-api-v1.md
docs/migration/current-status.md
docs/testing/smoke-matrix.md
admin_back_go/docs/architecture.md
```

---

## Task 1: Extend AI enum/dict for P2

**Files:**
- Modify: `admin_back_go/internal/enum/ai.go`
- Modify: `admin_back_go/internal/enum/ai_test.go`
- Modify: `admin_back_go/internal/dict/dict.go`
- Modify: `admin_back_go/internal/dict/ai_test.go`

- [x] **Step 1: Add failing enum tests**

Extend `ai_test.go`:

```go
func TestAIAgentKnowledgeEnumsAreStable(t *testing.T) {
	if !IsAIMode(AIModeChat) || !IsAIMode(AIModeRAG) || IsAIMode("goods") { t.Fatalf("unexpected ai mode validation") }
	if !IsAICapability(AICapabilityTools) || IsAICapability("cine") { t.Fatalf("unexpected ai capability validation") }
	if !IsKnowledgeVisibility(KnowledgeVisibilityPrivate) || !IsKnowledgeVisibility(KnowledgeVisibilityPublic) || IsKnowledgeVisibility("world") { t.Fatalf("unexpected visibility validation") }
	if !IsKnowledgeSourceType(KnowledgeSourceManual) || !IsKnowledgeSourceType(KnowledgeSourceText) || IsKnowledgeSourceType("file") { t.Fatalf("P2 source type must only accept manual/text") }
	if !IsKnowledgeIndexStatus(KnowledgeIndexIndexed) || !IsKnowledgeIndexStatus(KnowledgeIndexFailed) || IsKnowledgeIndexStatus(9) { t.Fatalf("unexpected index status validation") }
	if IsRetiredAIScene("goods_script") != true || IsRetiredAIScene("code_gen") != false { t.Fatalf("retired scene validation mismatch") }
}
```

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/enum -run TestAIAgentKnowledgeEnumsAreStable
```

Expected: fail because constants/helpers are missing.

- [x] **Step 2: Implement enum additions**

Add constants and helpers:

```text
AIModeChat/RAG/Tool/Workflow
AICapabilityTools/RAG/Workflow
Retired scenes: goods_script, cine_project, cine_keyframe
KnowledgeVisibilityPrivate/Team/Public
KnowledgeSourceManual/Text
KnowledgeIndexIndexed/Failed
```

Do not include file/url in `KnowledgeSourceTypes` for P2 active validation.

- [x] **Step 3: Add dict tests and options**

Extend `dict/ai_test.go` to assert:

```text
AIModeOptions first is chat.
AICapabilityOptions excludes chat because chat is implicit.
KnowledgeVisibilityOptions includes private/team/public.
KnowledgeSourceTypeOptions includes only manual/text.
KnowledgeIndexStatusOptions includes 1/2.
```

Implement matching `dict` functions.

- [x] **Step 4: Verify enum/dict**

Run:

```powershell
go test ./internal/enum ./internal/dict -count=1
```

Expected: pass.

---

## Task 2: Implement `aiagent` service and repository

**Files:**
- Create: `admin_back_go/internal/module/aiagent/*`

- [x] **Step 1: Write failing service tests**

Create `service_test.go` with tests proving:

```text
Init returns mode/capability/status options, active model_list, active knowledge_base_list, and excludes retired scenes.
Create validates active model/tool/knowledge ids.
Create rejects retired scenes in scene or scene_codes.
Create writes agent + tool bindings + knowledge bindings in one repository transaction.
Update keeps same validation and replaces bindings.
Delete soft-deletes agent and binding rows.
List maps model_name/model_deleted, driver labels, capabilities, scene_names, knowledge_base_names.
ChangeStatus validates status 1/2.
```

Run:

```powershell
go test ./internal/module/aiagent -count=1
```

Expected: fail because package does not exist.

- [x] **Step 2: Implement DTO/model/request**

Required route service interface:

```go
type HTTPService interface {
	Init(ctx context.Context) (*InitResponse, *apperror.Error)
	List(ctx context.Context, query ListQuery) (*ListResponse, *apperror.Error)
	Create(ctx context.Context, input MutationInput) (int64, *apperror.Error)
	Update(ctx context.Context, id int64, input MutationInput) *apperror.Error
	ChangeStatus(ctx context.Context, id int64, status int) *apperror.Error
	Delete(ctx context.Context, id int64) *apperror.Error
}
```

Use `map[string]bool` or a named struct for capabilities internally; JSON response must keep existing frontend `AiAgentCapabilities` shape.

- [x] **Step 3: Implement repository**

Required tables:

```text
ai_agents
ai_agent_scenes
ai_assistant_tools
ai_agent_knowledge_bases
ai_models for model list/join
ai_tools for active tool validation
ai_knowledge_bases for active knowledge validation
```

Required transaction methods:

```go
WithTx(ctx context.Context, fn func(Repository) error) error
CreateAgent(ctx context.Context, row Agent) (int64, error)
UpdateAgent(ctx context.Context, id int64, fields map[string]any) error
SyncToolBindings(ctx context.Context, agentID int64, toolIDs []int64) error
SyncKnowledgeBindings(ctx context.Context, agentID int64, knowledgeIDs []int64) error
SyncSceneBindings(ctx context.Context, agentID int64, sceneCodes []string) error
SoftDeleteAgentAndBindings(ctx context.Context, id int64) error
```

Soft-delete bindings before recreating/restoring so duplicate active bindings cannot accumulate.

- [x] **Step 4: Implement handler/routes**

Routes:

```text
GET    /api/admin/v1/ai-agents/page-init
GET    /api/admin/v1/ai-agents
POST   /api/admin/v1/ai-agents
PUT    /api/admin/v1/ai-agents/:id
PATCH  /api/admin/v1/ai-agents/:id/status
DELETE /api/admin/v1/ai-agents/:id
```

Use query params for list and JSON body for mutations.

- [x] **Step 5: Verify `aiagent`**

Run:

```powershell
go test ./internal/module/aiagent -count=1
```

Expected: pass.

---

## Task 3: Implement deterministic knowledge chunking and retrieval helpers

**Files:**
- Create: `admin_back_go/internal/module/aiknowledge/chunker.go`
- Create: `admin_back_go/internal/module/aiknowledge/chunker_test.go`
- Create: `admin_back_go/internal/module/aiknowledge/retrieval.go`
- Create: `admin_back_go/internal/module/aiknowledge/retrieval_test.go`

- [x] **Step 1: Write chunker tests**

Test requirements:

```text
ChunkText splits by rune length, not byte length.
chunk_size must be 100..4000 in service, but helper supports small test sizes.
chunk_overlap must be less than chunk_size.
chunk_no starts at 1.
token_estimate is at least 1 and roughly len(runes)/2.
```

- [x] **Step 2: Implement `ChunkText`**

Function shape:

```go
type Chunk struct { ChunkNo int; Content string; TokenEstimate int }
func ChunkText(content string, chunkSize int, overlap int) ([]Chunk, error)
```

No external tokenizer.

- [x] **Step 3: Write retrieval tests**

Test requirements:

```text
ScoreKeywordChunk returns higher score when more query terms are present.
BuildContextPrompt joins chunks in score order with document title and chunk number.
Empty query returns validation error.
```

- [x] **Step 4: Implement retrieval helpers**

No vector/embedding calls. Simple deterministic term scoring is enough for P2.

- [x] **Step 5: Verify helpers**

Run:

```powershell
go test ./internal/module/aiknowledge -run 'TestChunk|TestRetrieval' -count=1
```

Expected: pass.

---

## Task 4: Implement `aiknowledge` service and repository

**Files:**
- Create/modify: `admin_back_go/internal/module/aiknowledge/*`

- [x] **Step 1: Write failing service tests**

Create service tests proving:

```text
Init returns common_status_arr, ai_knowledge_visibility_arr, ai_knowledge_index_status_arr, ai_knowledge_source_type_arr.
Create validates chunk_overlap < chunk_size and score_threshold 0..100.
Delete knowledge base soft-deletes base, documents, chunks, and ai_agent_knowledge_bases.
AddDocument creates document then chunks in one transaction and sets chunk_count/index_status.
UpdateDocument replaces chunks when content changes.
ReindexDocument deletes old chunks and recreates deterministic chunks.
RetrievalTest uses active chunks from one knowledge base and returns chunks/context_prompt.
Document operations reject document_id not under base id.
```

Run:

```powershell
go test ./internal/module/aiknowledge -count=1
```

Expected: fail until module is implemented.

- [x] **Step 2: Implement DTO/model/request**

Keep frontend exported shapes compatible with current `knowledge.ts`:

```text
AiKnowledgeInitResponse
AiKnowledgeBaseItem
AiKnowledgeDocumentItem
AiKnowledgeChunkItem
AiKnowledgeRetrievalResponse
```

- [x] **Step 3: Implement repository**

Required behavior:

```text
List bases: is_del=2, filters name prefix, visibility exact, status exact, order id DESC.
Detail: active base by id.
Documents: base_id exact, is_del=2, optional title prefix/status, order id DESC.
Chunks: base_id exact, optional document_id, is_del=2, order document_id ASC, chunk_no ASC.
Soft delete uses is_del=1 and updated_at=now.
```

- [x] **Step 4: Implement routes**

Routes:

```text
GET    /api/admin/v1/ai-knowledge-bases/page-init
GET    /api/admin/v1/ai-knowledge-bases
GET    /api/admin/v1/ai-knowledge-bases/:id
POST   /api/admin/v1/ai-knowledge-bases
PUT    /api/admin/v1/ai-knowledge-bases/:id
PATCH  /api/admin/v1/ai-knowledge-bases/:id/status
DELETE /api/admin/v1/ai-knowledge-bases/:id
GET    /api/admin/v1/ai-knowledge-bases/:id/documents
GET    /api/admin/v1/ai-knowledge-bases/:id/documents/:document_id
POST   /api/admin/v1/ai-knowledge-bases/:id/documents
PUT    /api/admin/v1/ai-knowledge-bases/:id/documents/:document_id
DELETE /api/admin/v1/ai-knowledge-bases/:id/documents/:document_id
POST   /api/admin/v1/ai-knowledge-bases/:id/documents/:document_id/reindex
GET    /api/admin/v1/ai-knowledge-bases/:id/chunks
POST   /api/admin/v1/ai-knowledge-bases/:id/retrieval-tests
```

- [x] **Step 5: Verify `aiknowledge`**

Run:

```powershell
go test ./internal/module/aiknowledge -count=1
```

Expected: pass.

---

## Task 5: Wire routes, permissions, and operation logs

**Files:**
- Modify: `admin_back_go/internal/server/router.go`
- Modify: `admin_back_go/internal/server/router_test.go`
- Modify: `admin_back_go/internal/bootstrap/app.go`
- Modify: `admin_back_go/internal/bootstrap/route_meta.go`
- Modify: `admin_back_go/internal/bootstrap/route_meta_test.go`

- [x] **Step 1: Add router tests**

Assert these route groups exist:

```text
GET /api/admin/v1/ai-agents/page-init
GET /api/admin/v1/ai-agents
GET /api/admin/v1/ai-knowledge-bases/page-init
GET /api/admin/v1/ai-knowledge-bases
GET /api/admin/v1/ai-knowledge-bases/1/documents
POST /api/admin/v1/ai-knowledge-bases/1/retrieval-tests
```

- [x] **Step 2: Wire bootstrap services**

Create services with GORM repository:

```go
aiAgentService := aiagent.NewService(aiagent.NewGormRepository(resources.DB))
aiKnowledgeService := aiknowledge.NewService(aiknowledge.NewGormRepository(resources.DB))
```

Pass them to router dependencies.

- [x] **Step 3: Wire knowledge permission rules**

Add exact rules from the spec:

```go
POST /api/admin/v1/ai-knowledge-bases -> ai_knowledge_add
PUT /api/admin/v1/ai-knowledge-bases/:id -> ai_knowledge_edit
PATCH /api/admin/v1/ai-knowledge-bases/:id/status -> ai_knowledge_status
DELETE /api/admin/v1/ai-knowledge-bases/:id -> ai_knowledge_del
POST /api/admin/v1/ai-knowledge-bases/:id/documents -> ai_knowledge_document_add
PUT /api/admin/v1/ai-knowledge-bases/:id/documents/:document_id -> ai_knowledge_document_edit
DELETE /api/admin/v1/ai-knowledge-bases/:id/documents/:document_id -> ai_knowledge_document_del
POST /api/admin/v1/ai-knowledge-bases/:id/documents/:document_id/reindex -> ai_knowledge_reindex
POST /api/admin/v1/ai-knowledge-bases/:id/retrieval-tests -> ai_knowledge_retrieval_test
```

Agent permissions: if this task includes DB migration seed for `ai_agent_add/edit/del/status`, wire them. If not, do not invent route rules that fail closed at runtime; leave auth-only plus OperationLog and document the gap.

- [x] **Step 4: Wire operation logs**

Add operation rules for all POST/PUT/PATCH/DELETE agent and knowledge routes.

- [x] **Step 5: Verify wiring**

Run:

```powershell
go test ./internal/server ./internal/bootstrap -count=1
```

Expected: pass.

---

## Task 6: Switch frontend API clients

**Files:**
- Create: `admin_front_ts/tests/shared/ai/ai-agent-api.test.ts`
- Create: `admin_front_ts/tests/shared/ai/ai-knowledge-api.test.ts`
- Modify: `admin_front_ts/src/api/ai/agents.ts`
- Modify: `admin_front_ts/src/api/ai/knowledge.ts`

- [x] **Step 1: Write failing source-contract tests**

Tests must assert:

```text
agents.ts imports request and ADMIN_API_PREFIX, not legacyRequest.
agents.ts uses /ai-agents REST endpoints and no /api/admin/AiAgents.
knowledge.ts imports request and ADMIN_API_PREFIX, not legacyRequest.
knowledge.ts uses nested /ai-knowledge-bases REST endpoints and no /api/admin/AiKnowledgeBases.
DELETE uses path params, not body /del.
No any/as any/Record<string, any> in touched API files.
```

Run:

```powershell
cd E:\admin_go\admin_front_ts
npx vitest run tests/shared/ai/ai-agent-api.test.ts tests/shared/ai/ai-knowledge-api.test.ts
```

Expected: fail before rewrite.

- [x] **Step 2: Rewrite `agents.ts`**

Mapping:

```text
init -> GET /ai-agents/page-init
list -> GET /ai-agents with query params
add -> POST /ai-agents
edit -> PUT /ai-agents/:id, body excludes id
status -> PATCH /ai-agents/:id/status
single del -> DELETE /ai-agents/:id
batch del -> Promise.all(ids.map(id => DELETE /ai-agents/:id)) because P2 REST delete is single-resource
```

Keep existing exported type names.

- [x] **Step 3: Rewrite `knowledge.ts`**

Mapping:

```text
init -> GET /ai-knowledge-bases/page-init
list -> GET /ai-knowledge-bases
detail -> GET /ai-knowledge-bases/:id
add -> POST /ai-knowledge-bases
edit -> PUT /ai-knowledge-bases/:id
status -> PATCH /ai-knowledge-bases/:id/status
del -> DELETE /ai-knowledge-bases/:id or Promise.all for arrays
documents -> GET /ai-knowledge-bases/:id/documents
documentDetail -> GET /ai-knowledge-bases/:id/documents/:document_id
addDocument -> POST /ai-knowledge-bases/:id/documents
editDocument -> PUT /ai-knowledge-bases/:id/documents/:document_id
delDocument -> DELETE /ai-knowledge-bases/:id/documents/:document_id
reindexDocument -> POST /ai-knowledge-bases/:id/documents/:document_id/reindex
chunks -> GET /ai-knowledge-bases/:id/chunks
retrievalTest -> POST /ai-knowledge-bases/:id/retrieval-tests
```

Normalize positive ids before path interpolation.

- [x] **Step 4: Verify frontend clients**

Run:

```powershell
npx vitest run tests/shared/ai/ai-agent-api.test.ts tests/shared/ai/ai-knowledge-api.test.ts
npx vue-tsc -b --pretty false
```

Expected: pass.

---

## Task 7: Smoke and docs

**Files:**
- Modify: `admin_back_go/scripts/full-admin-smoke.ps1`
- Modify: `docs/contracts/admin-api-v1.md`
- Modify: `docs/migration/current-status.md`
- Modify: `docs/testing/smoke-matrix.md`
- Modify: `admin_back_go/docs/architecture.md`

- [x] **Step 1: Add smoke probes**

Read probes:

```text
GET /api/admin/v1/ai-agents/page-init
GET /api/admin/v1/ai-agents?current_page=1&page_size=10
GET /api/admin/v1/ai-knowledge-bases/page-init
GET /api/admin/v1/ai-knowledge-bases?current_page=1&page_size=10
GET /api/admin/v1/ai-knowledge-bases/:id when one exists
GET /api/admin/v1/ai-knowledge-bases/:id/documents?current_page=1&page_size=10
GET /api/admin/v1/ai-knowledge-bases/:id/chunks?current_page=1&page_size=10
POST /api/admin/v1/ai-knowledge-bases/:id/retrieval-tests with query from an existing chunk only when one exists
```

Assertions:

```text
ai_scene_arr excludes goods_script/cine_project/cine_keyframe.
knowledge dict arrays exist.
retrieval response has chunks array and context_prompt string.
```

Default smoke should not mutate knowledge documents unless `-EnableAiKnowledgeMutationProbe` is added.

- [x] **Step 2: Update API contract**

Add Agent Management and Knowledge Management sections with endpoint lists, request/response fields, non-goals, and retired scene rule.

- [x] **Step 3: Update status/smoke/architecture docs**

`current-status.md` wording:

```text
AI agent/knowledge management implemented in Go REST; chat/runtime/runs were intentionally out of scope for this slice and are covered by the AI chat runtime closure plan.
```

Only write that after verification passes.

- [x] **Step 4: Verify docs are not lying**

Run:

```powershell
cd E:\admin_go
rg -n "AI core migrated|AI runtime migrated|ai_run_timeout.*Go-owned|/api/admin/AiAgents|/api/admin/AiKnowledgeBases" docs admin_front_ts/src/api/ai
```

Expected:

```text
No false claim that AI runtime is migrated.
No active frontend API references to /api/admin/AiAgents or /api/admin/AiKnowledgeBases.
Legacy paths may appear only in migration history/spec text.
```

---

## Task 8: Final verification

**Files:** no source changes unless verification finds a real bug.

- [x] **Step 1: Backend verification**

Run:

```powershell
cd E:\admin_go\admin_back_go
$env:GOMAXPROCS='2'
go test -p=1 ./internal/enum ./internal/dict ./internal/module/aiagent ./internal/module/aiknowledge ./internal/server ./internal/bootstrap
go vet -p=1 ./internal/module/aiagent ./internal/module/aiknowledge
powershell -ExecutionPolicy Bypass -File .\scripts\check-contract.ps1
git diff --check
```

Expected: exit 0.

- [x] **Step 2: Frontend verification**

Run:

```powershell
cd E:\admin_go\admin_front_ts
npx vitest run tests/shared/ai/ai-agent-api.test.ts tests/shared/ai/ai-knowledge-api.test.ts
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
ai_agent_init_code=0
ai_agent_list_code=0
ai_agent_retired_scene_present=false
ai_knowledge_init_code=0
ai_knowledge_list_code=0
ai_knowledge_retrieval_code=0 when chunks exist
```

- [x] **Step 4: Residue sweep**

Run:

```powershell
cd E:\admin_go
rg -n "legacyRequest|/api/admin/AiAgents|/api/admin/AiKnowledgeBases|goods_script|cine_project|cine_keyframe" admin_front_ts/src/api/ai admin_back_go/internal/module/aiagent admin_back_go/internal/module/aiknowledge
```

Expected:

```text
No legacyRequest in agents.ts/knowledge.ts.
Retired scene strings may exist only in backend exclusion constants/tests, not in active frontend selectable options.
```

## Commit plan

If asked to commit:

```powershell
git -C E:\admin_go\admin_back_go add internal/enum internal/dict internal/module/aiagent internal/module/aiknowledge internal/server internal/bootstrap scripts/full-admin-smoke.ps1 docs/architecture.md
git -C E:\admin_go\admin_back_go commit -m "feat: migrate ai agent knowledge management"

git -C E:\admin_go\admin_front_ts add src/api/ai/agents.ts src/api/ai/knowledge.ts tests/shared/ai
git -C E:\admin_go\admin_front_ts commit -m "feat: switch ai agent knowledge clients to go rest"

git -C E:\admin_go add docs/contracts/admin-api-v1.md docs/migration/current-status.md docs/testing/smoke-matrix.md docs/superpowers/specs/2026-05-08-ai-agent-knowledge-management-design.md docs/superpowers/plans/2026-05-08-ai-agent-knowledge-management.md
git -C E:\admin_go commit -m "docs: plan ai agent knowledge migration"
```

## Self-review

```text
Spec coverage: enum/dict, agent CRUD/bindings, knowledge CRUD/doc/chunks/retrieval, frontend switch, docs/smoke are all covered.
No placeholder text remains.
Plan explicitly avoids chat/runtime/vector/Python sidecar and retired goods/cine resurrection.
```
