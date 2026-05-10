# AI Knowledge Base RAG Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the admin_go knowledge base module so agents can read configured knowledge bases during chat and run monitor can show retrieval details.

**Architecture:** Use a local MySQL-backed RAG MVP: knowledge base -> document -> chunk -> agent binding -> runtime retrieval -> run monitor detail. Keep provider calls behind existing `internal/platform/ai` and inject retrieved context into the user message before the first model call. Do not introduce an external vector database or provider-hosted file search in this slice.

**Tech Stack:** Go 1.21+, Gin modular monolith, Gorm/MySQL, Vue 3 + `<script setup lang="ts">`, Element Plus, existing AppTable/AppDialog/Search, current WebSocket AI chat runtime.

**Execution status 2026-05-10:** implemented in the working tree and live DB. Six knowledge tables are present in MySQL, seed base `admin_go_project_architecture` has six active documents and six active chunks, backend active wiring uses `internal/module/aiknowledge`, frontend active API uses `src/api/ai/knowledge.ts`, and retired `aiknowledgemap` / `knowledgeMaps.ts` active code has been removed. Per-task commit steps in this plan are intentionally not executed by Codex; commit/push remains a maintainer action.

Fresh verification run on 2026-05-10:

```powershell
cd E:\admin_go\admin_back_go
$env:GOMAXPROCS='2'
go test -p=1 ./internal/module/aiknowledge ./internal/module/aichat ./internal/module/airun ./internal/server ./internal/bootstrap -count=1
go vet -p=1 ./...

cd E:\admin_go\admin_front_ts
.\node_modules\.bin\vitest.cmd run tests/shared/ai/ai-knowledge-api.test.ts tests/shared/ai/ai-agent-api.test.ts tests/shared/ai/ai-run-api.test.ts --maxWorkers=1
npx vue-tsc -b --pretty false
npm run build:check

cd E:\admin_go\admin_back_go
powershell -NoProfile -Command '$null = [scriptblock]::Create((Get-Content -Raw .\scripts\full-admin-smoke.ps1)); "syntax ok"'

cd E:\admin_go
git diff --check
git -C admin_back_go diff --check
git -C admin_front_ts diff --check
```

---

## File structure

### Backend create

- `admin_back_go/database/migrations/20260510_ai_knowledge_rag.sql` — create six knowledge tables and seed `admin_go_project_architecture` content.
- `admin_back_go/internal/module/aiknowledge/model.go` — Gorm models for all six tables.
- `admin_back_go/internal/module/aiknowledge/dto.go` — REST DTOs, runtime DTOs, repository and service interfaces.
- `admin_back_go/internal/module/aiknowledge/request.go` — Gin binding request structs.
- `admin_back_go/internal/module/aiknowledge/chunker.go` — deterministic text chunking pure functions.
- `admin_back_go/internal/module/aiknowledge/retriever.go` — deterministic scoring, hit selection, context building pure functions.
- `admin_back_go/internal/module/aiknowledge/repository.go` — Gorm implementation.
- `admin_back_go/internal/module/aiknowledge/service.go` — CRUD, document reindex, retrieval test, agent binding, runtime retrieval.
- `admin_back_go/internal/module/aiknowledge/handler.go` — HTTP handlers.
- `admin_back_go/internal/module/aiknowledge/route.go` — REST route registration.
- `admin_back_go/internal/module/aiknowledge/chunker_test.go` — chunking tests.
- `admin_back_go/internal/module/aiknowledge/retriever_test.go` — retrieval scoring and selection tests.
- `admin_back_go/internal/module/aiknowledge/service_test.go` — service behavior tests.

### Backend modify

- `admin_back_go/internal/bootstrap/app.go` — wire `aiknowledge.NewService`, pass runtime to `aichat`, remove active `aiknowledgemap` wiring.
- `admin_back_go/internal/bootstrap/route_meta.go` — replace `ai_knowledge_map_*` route metadata with `ai_knowledge_*` permission codes.
- `admin_back_go/internal/bootstrap/route_meta_test.go` — update route key assertions.
- `admin_back_go/internal/server/router.go` — register new knowledge routes and remove active map route dependency.
- `admin_back_go/internal/server/router_test.go` — update route tests from `/ai-knowledge-maps` to `/ai-knowledge-bases`.
- `admin_back_go/internal/module/aichat/dto.go` — add `KnowledgeRuntime` interface and context result input types.
- `admin_back_go/internal/module/aichat/service.go` — execute retrieval before provider call and inject context into user content.
- `admin_back_go/internal/module/aichat/service_test.go` — test bound knowledge context is injected and failed retrieval does not block model call.
- `admin_back_go/internal/module/airun/dto.go` — add knowledge retrieval DTOs.
- `admin_back_go/internal/module/airun/repository.go` — query retrieval records and hits.
- `admin_back_go/internal/module/airun/service.go` — include retrievals in detail response.
- `admin_back_go/internal/module/airun/service_test.go` — assert detail includes retrievals.
- `admin_back_go/scripts/full-admin-smoke.ps1` — add read-only knowledge page-init/list and seed presence checks.

### Frontend create

- `admin_front_ts/src/api/ai/knowledge.ts` — typed REST client for knowledge base/document/chunk/retrieval-test APIs.
- `admin_front_ts/src/views/Main/ai/knowledge/components/KnowledgeBaseList/index.vue` — base list and actions.
- `admin_front_ts/src/views/Main/ai/knowledge/components/KnowledgeBaseFormDialog/index.vue` — base add/edit dialog.
- `admin_front_ts/src/views/Main/ai/knowledge/components/KnowledgeDocumentPanel/index.vue` — document list for selected base.
- `admin_front_ts/src/views/Main/ai/knowledge/components/KnowledgeDocumentFormDialog/index.vue` — document add/edit dialog.
- `admin_front_ts/src/views/Main/ai/knowledge/components/KnowledgeChunkDialog/index.vue` — chunk viewer.
- `admin_front_ts/src/views/Main/ai/knowledge/components/RetrievalTestDialog/index.vue` — retrieval test dialog.
- `admin_front_ts/src/views/Main/ai/agents/components/AgentKnowledgeDialog/index.vue` — agent knowledge binding dialog.
- `admin_front_ts/tests/shared/ai/ai-knowledge-api.test.ts` — API client contract tests.

### Frontend modify

- `admin_front_ts/src/views/Main/ai/knowledge/index.vue` — route-level composition only.
- `admin_front_ts/src/api/ai/agents.ts` — add knowledge binding APIs and types.
- `admin_front_ts/src/views/Main/ai/agents/index.vue` — add knowledge button and dialog wiring.
- `admin_front_ts/src/api/ai/runs.ts` — add knowledge retrieval response types.
- `admin_front_ts/src/views/Main/ai/runs/*` — render retrieval block in run detail.
- `admin_front_ts/src/i18n/locales/zh-CN.ts` — add knowledge labels.
- `admin_front_ts/src/i18n/locales/en-US.ts` — add English fallback labels.
- `admin_front_ts/tests/shared/ai/ai-agent-api.test.ts` — add knowledge binding client assertions.
- `admin_front_ts/tests/shared/ai/ai-run-api.test.ts` — assert run detail accepts `knowledge_retrievals`.

### Docs modify

- `docs/contracts/admin-api-v1.md` — add AI Knowledge Base RAG contract and run detail response fields.
- `docs/migration/current-status.md` — mark knowledge module implemented only after verification passes.
- `docs/testing/smoke-matrix.md` — add smoke assertions.
- `admin_back_go/docs/architecture.md` — mention local RAG runtime dependency if this file has AI runtime section.

---

## Task 1: Schema migration and seed data

**Files:**
- Create: `admin_back_go/database/migrations/20260510_ai_knowledge_rag.sql`

- [ ] **Step 1: Write the schema and seed SQL**

Create `admin_back_go/database/migrations/20260510_ai_knowledge_rag.sql` with the six DDL blocks from `docs/superpowers/specs/2026-05-10-ai-knowledge-rag-design.md` and these seed inserts:

```sql
INSERT INTO ai_knowledge_bases
  (name, code, description, chunk_size_chars, chunk_overlap_chars, default_top_k, default_min_score, default_max_context_chars, status, is_del)
VALUES
  ('admin_go 项目架构知识库', 'admin_go_project_architecture', 'admin_go 后端、前端、AI 模块和迁移规范的项目内知识库，用于智能体回答项目架构相关问题。', 1200, 120, 5, 0.1000, 6000, 1, 2)
ON DUPLICATE KEY UPDATE
  name = VALUES(name),
  description = VALUES(description),
  chunk_size_chars = VALUES(chunk_size_chars),
  chunk_overlap_chars = VALUES(chunk_overlap_chars),
  default_top_k = VALUES(default_top_k),
  default_min_score = VALUES(default_min_score),
  default_max_context_chars = VALUES(default_max_context_chars),
  status = VALUES(status),
  updated_at = CURRENT_TIMESTAMP;
```

Then insert six seed documents using this pattern:

```sql
SET @kb_id := (SELECT id FROM ai_knowledge_bases WHERE code = 'admin_go_project_architecture' AND is_del = 2 LIMIT 1);

INSERT INTO ai_knowledge_documents
  (knowledge_base_id, title, source_type, source_ref, content, index_status, status, is_del)
VALUES
  (@kb_id, '项目总原则', 'markdown', 'docs/architecture/00-open-source-first.md', 'admin_go 是 open-source-first admin rewrite workspace。处理任务先读当前状态，不靠聊天记录猜进度；再读架构、契约、测试文档；再按 agent 角色接手一个窄切片；最后才改代码、跑验证、同步文档。架构、RBAC、菜单、API 契约和项目前端权限默认先参考成熟开源和当前运行事实，不凭感觉发明。', 'indexed', 1, 2),
  (@kb_id, 'Go 后端架构', 'markdown', 'docs/architecture/04-go-backend-framework.md', 'admin_back_go 采用 Gin modular monolith。顶层调用链是 cmd -> bootstrap -> server -> module -> platform。业务模块内部默认是 route -> handler -> service -> repository -> model。handler 不直接查数据库，service 不依赖 gin.Context，repository 不写业务决策，model 不写业务方法。', 'indexed', 1, 2),
  (@kb_id, '开发质量规则', 'markdown', 'docs/architecture/05-development-quality-rules.md', '项目禁止兜底字段、兼容猜测、全 POST、any TypeScript 和未验证声明。新增接口必须使用 /api/admin/v1/<resource> REST 风格。字段必须有真实用途，文档与运行时冲突时以运行时为准并修正文档。', 'indexed', 1, 2),
  (@kb_id, 'AI 模块当前事实', 'markdown', 'docs/migration/current-status.md#ai', '当前 AI 产品面包括供应商配置、智能体配置、知识库、AI 工具管理、运行监控、AI 对话。供应商配置保存 provider 和 provider models，智能体配置保存 ai_agents 并选择 provider-owned model，工具管理只定义 ai_tools，智能体配置页通过 ai_agent_tools 决定可用工具。', 'indexed', 1, 2),
  (@kb_id, 'AI 对话运行链路', 'text', 'admin_back_go/internal/module/aichat/service.go', '浏览器通过 WebSocket 接收 ai.response.start.v1、ai.response.delta.v1、ai.response.completed.v1、ai.response.failed.v1。发送消息后，aimessage 保存用户消息，aichat 创建 ai_runs，加载智能体、历史消息、工具绑定，调用 provider stream，保存助手消息并完成 run。', 'indexed', 1, 2),
  (@kb_id, 'Vue 前端 AI 页面结构', 'text', 'admin_front_ts/src/views/Main/ai', 'admin_front_ts 使用 Vue 3、Composition API、script setup lang=ts 和 typed API client。AI 页面位于 src/views/Main/ai，当前子模块包含 providers、agents、knowledge、tools、runs、chat。按钮权限通过 userStore.can(code) 控制，表格和弹窗优先复用 AppTable、AppDialog、Search 等项目组件。', 'indexed', 1, 2)
ON DUPLICATE KEY UPDATE
  content = VALUES(content),
  index_status = VALUES(index_status),
  status = VALUES(status),
  updated_at = CURRENT_TIMESTAMP;
```

Seed one chunk per seed document:

```sql
INSERT INTO ai_knowledge_chunks
  (knowledge_base_id, document_id, chunk_index, title, content, content_chars, status, is_del)
SELECT knowledge_base_id, id, 1, title, content, CHAR_LENGTH(content), 1, 2
FROM ai_knowledge_documents
WHERE knowledge_base_id = @kb_id AND is_del = 2
ON DUPLICATE KEY UPDATE
  title = VALUES(title),
  content = VALUES(content),
  content_chars = VALUES(content_chars),
  status = VALUES(status),
  updated_at = CURRENT_TIMESTAMP;
```

- [ ] **Step 2: Apply migration to local DB**

Run:

```powershell
cd E:\admin_go\admin_back_go
Get-Content .\database\migrations\20260510_ai_knowledge_rag.sql | mysql -u root -p admin
```

Expected: no SQL error. If this project uses a configured migration command in the current environment, use that command but still verify the SQL file above is the source applied.

- [ ] **Step 3: Verify tables and seed rows are in live DB**

Run:

```sql
SELECT COUNT(*) AS knowledge_tables
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME IN ('ai_knowledge_bases','ai_knowledge_documents','ai_knowledge_chunks','ai_agent_knowledge_bases','ai_knowledge_retrievals','ai_knowledge_retrieval_hits');

SELECT id, name, code, status, is_del
FROM ai_knowledge_bases
WHERE code = 'admin_go_project_architecture';

SELECT d.title, COUNT(c.id) AS chunks
FROM ai_knowledge_documents d
LEFT JOIN ai_knowledge_chunks c ON c.document_id = d.id AND c.is_del = 2
WHERE d.knowledge_base_id = (SELECT id FROM ai_knowledge_bases WHERE code='admin_go_project_architecture' AND is_del=2 LIMIT 1)
GROUP BY d.id, d.title
ORDER BY d.id;
```

Expected:

```text
knowledge_tables = 6
one ai_knowledge_bases row with code admin_go_project_architecture, status=1, is_del=2
six document rows, each with chunks=1
```

- [ ] **Step 4: Commit schema work**

```powershell
git add admin_back_go/database/migrations/20260510_ai_knowledge_rag.sql
git commit -m "feat: add ai knowledge rag schema"
```

---

## Task 2: Backend domain models and pure retrieval functions

**Files:**
- Create: `admin_back_go/internal/module/aiknowledge/model.go`
- Create: `admin_back_go/internal/module/aiknowledge/dto.go`
- Create: `admin_back_go/internal/module/aiknowledge/chunker.go`
- Create: `admin_back_go/internal/module/aiknowledge/retriever.go`
- Create: `admin_back_go/internal/module/aiknowledge/chunker_test.go`
- Create: `admin_back_go/internal/module/aiknowledge/retriever_test.go`

- [ ] **Step 1: Write chunker tests first**

Create `chunker_test.go`:

```go
package aiknowledge

import (
	"strings"
	"testing"
)

func TestChunkTextUsesSizeAndOverlap(t *testing.T) {
	text := strings.Repeat("a", 300) + strings.Repeat("b", 300) + strings.Repeat("c", 300)
	chunks, err := chunkText(text, ChunkOptions{SizeChars: 400, OverlapChars: 100})
	if err != nil {
		t.Fatalf("chunkText returned error: %v", err)
	}
	if len(chunks) != 3 {
		t.Fatalf("chunk count = %d, want 3: %#v", len(chunks), chunks)
	}
	if chunks[0].Index != 1 || chunks[1].Index != 2 || chunks[2].Index != 3 {
		t.Fatalf("unexpected indexes: %#v", chunks)
	}
	if chunks[0].Chars != 400 || chunks[1].Chars != 400 || chunks[2].Chars != 300 {
		t.Fatalf("unexpected chunk sizes: %#v", chunks)
	}
}

func TestChunkTextRejectsInvalidOptions(t *testing.T) {
	_, err := chunkText("hello", ChunkOptions{SizeChars: 10, OverlapChars: 10})
	if err == nil {
		t.Fatal("expected error for overlap >= size")
	}
}
```

- [ ] **Step 2: Implement `model.go`, `dto.go`, and `chunker.go`**

Create models matching the spec. Implement `ChunkText` with production validation and `chunkText` for pure tests:

```go
func ChunkText(content string, options ChunkOptions) ([]TextChunk, error) {
	if options.SizeChars < 300 {
		return nil, fmt.Errorf("chunk size must be at least 300")
	}
	if options.SizeChars > 8000 {
		return nil, fmt.Errorf("chunk size must be at most 8000")
	}
	return chunkText(content, options)
}

func chunkText(content string, options ChunkOptions) ([]TextChunk, error) {
	text := strings.TrimSpace(content)
	if text == "" {
		return nil, fmt.Errorf("content is empty")
	}
	if options.SizeChars == 0 {
		return nil, fmt.Errorf("chunk size is required")
	}
	if options.OverlapChars >= options.SizeChars {
		return nil, fmt.Errorf("chunk overlap must be smaller than chunk size")
	}
	runes := []rune(text)
	if uint(len(runes)) <= options.SizeChars {
		return []TextChunk{{Index: 1, Content: text, Chars: uint(len(runes))}}, nil
	}
	step := int(options.SizeChars - options.OverlapChars)
	size := int(options.SizeChars)
	chunks := make([]TextChunk, 0, len(runes)/step+1)
	for start := 0; start < len(runes); start += step {
		end := start + size
		if end > len(runes) {
			end = len(runes)
		}
		part := strings.TrimSpace(string(runes[start:end]))
		if part != "" {
			chunks = append(chunks, TextChunk{Index: uint(len(chunks) + 1), Content: part, Chars: uint(len([]rune(part)))})
		}
		if end == len(runes) {
			break
		}
	}
	return chunks, nil
}
```

- [ ] **Step 3: Run chunker test**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/aiknowledge -run TestChunkText -count=1
```

Expected: PASS.

- [ ] **Step 4: Write retriever tests first**

Create `retriever_test.go`:

```go
package aiknowledge

import (
	"strings"
	"testing"
)

func TestSelectHitsAppliesScoreAndContextLimit(t *testing.T) {
	candidates := []RetrievalCandidate{
		{KnowledgeBaseID: 1, KnowledgeBaseName: "架构库", DocumentID: 10, DocumentTitle: "Go 后端架构", ChunkID: 100, ChunkIndex: 1, Title: "Go 后端架构", Content: "admin_back_go 采用 Gin modular monolith，调用链是 route handler service repository model。", ContentChars: 80},
		{KnowledgeBaseID: 1, KnowledgeBaseName: "架构库", DocumentID: 11, DocumentTitle: "无关", ChunkID: 101, ChunkIndex: 1, Title: "无关", Content: "天气很好。", ContentChars: 5},
	}
	result := SelectHits("Go 后端架构 route service", candidates, RetrievalOptions{TopK: 5, MinScore: 0.1, MaxContextChars: 60})
	if result.TotalHits != 2 || result.SelectedHits != 1 {
		t.Fatalf("unexpected totals: %#v", result)
	}
	if len(result.Hits) != 2 {
		t.Fatalf("hit count = %d", len(result.Hits))
	}
	if result.Hits[0].Status != HitStatusSelected || result.Hits[0].RankNo != 1 || result.Hits[0].Score <= 0 {
		t.Fatalf("first hit not selected with score: %#v", result.Hits[0])
	}
	if result.Hits[1].Status != HitStatusSkipped || result.Hits[1].SkipReason != SkipReasonLowScore {
		t.Fatalf("second hit should be low score skipped: %#v", result.Hits[1])
	}
}

func TestBuildKnowledgeContextUsesSelectedHitsOnly(t *testing.T) {
	contextText := BuildKnowledgeContext([]SelectedHit{
		{Ref: "K1", KnowledgeBaseName: "架构库", DocumentTitle: "Go 后端架构", ChunkIndex: 1, Content: "Gin modular monolith"},
	})
	for _, part := range []string{"[K1]", "架构库", "Go 后端架构", "Gin modular monolith"} {
		if !strings.Contains(contextText, part) {
			t.Fatalf("context missing %q: %q", part, contextText)
		}
	}
}
```

- [ ] **Step 5: Implement `retriever.go`**

Define constants and types from the spec:

```go
const (
	RetrievalStatusSuccess = "success"
	RetrievalStatusFailed  = "failed"
	RetrievalStatusSkipped = "skipped"

	HitStatusSelected = 1
	HitStatusSkipped  = 2

	SkipReasonLowScore     = "low_score"
	SkipReasonContextLimit = "context_limit"
)
```

`SelectHits` must sort by score desc and chunk id asc, mark hits below min score as skipped, and mark hits exceeding context budget as `context_limit`. `BuildKnowledgeContext` must output the exact format in the spec.

- [ ] **Step 6: Run pure function tests**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/aiknowledge -run "TestChunkText|TestSelectHits|TestBuildKnowledgeContext" -count=1
```

Expected: PASS.

- [ ] **Step 7: Commit pure domain code**

```powershell
git add admin_back_go/internal/module/aiknowledge/model.go admin_back_go/internal/module/aiknowledge/dto.go admin_back_go/internal/module/aiknowledge/chunker.go admin_back_go/internal/module/aiknowledge/retriever.go admin_back_go/internal/module/aiknowledge/chunker_test.go admin_back_go/internal/module/aiknowledge/retriever_test.go
git commit -m "feat: add ai knowledge retrieval domain"
```

---

## Task 3: Backend REST service, repository, routes, and route metadata

**Files:**
- Create: `admin_back_go/internal/module/aiknowledge/request.go`
- Create: `admin_back_go/internal/module/aiknowledge/repository.go`
- Create: `admin_back_go/internal/module/aiknowledge/service.go`
- Create: `admin_back_go/internal/module/aiknowledge/handler.go`
- Create: `admin_back_go/internal/module/aiknowledge/route.go`
- Modify: `admin_back_go/internal/server/router.go`
- Modify: `admin_back_go/internal/server/router_test.go`
- Modify: `admin_back_go/internal/bootstrap/route_meta.go`
- Modify: `admin_back_go/internal/bootstrap/route_meta_test.go`
- Modify: `admin_back_go/internal/bootstrap/app.go`

- [ ] **Step 1: Write service tests**

`service_test.go` must cover:

```go
func TestCreateKnowledgeBaseStoresAllFields(t *testing.T)
func TestReindexDocumentReplacesChunksAndMarksIndexed(t *testing.T)
func TestRetrievalTestReturnsSelectedHits(t *testing.T)
func TestUpdateAgentKnowledgeBasesNormalizesBindings(t *testing.T)
func TestRuntimeRetrieveSkipsWhenAgentHasNoBindings(t *testing.T)
```

Assertions must verify `chunk_size_chars`, `chunk_overlap_chars`, `default_top_k`, `default_min_score`, `default_max_context_chars`, `status`, `is_del`, and binding options.

- [ ] **Step 2: Implement repository interface**

Add methods with explicit names in `dto.go`:

```go
type Repository interface {
	ListBases(ctx context.Context, query BaseListQuery) ([]KnowledgeBase, int64, error)
	GetBase(ctx context.Context, id uint64) (*KnowledgeBase, error)
	CreateBase(ctx context.Context, row KnowledgeBase) (uint64, error)
	UpdateBase(ctx context.Context, id uint64, fields map[string]any) error
	ChangeBaseStatus(ctx context.Context, id uint64, status int) error
	DeleteBase(ctx context.Context, id uint64) error
	ListDocuments(ctx context.Context, baseID uint64, query DocumentListQuery) ([]KnowledgeDocument, int64, error)
	GetDocument(ctx context.Context, id uint64) (*KnowledgeDocument, error)
	CreateDocument(ctx context.Context, row KnowledgeDocument) (uint64, error)
	UpdateDocument(ctx context.Context, id uint64, fields map[string]any) error
	ChangeDocumentStatus(ctx context.Context, id uint64, status int) error
	DeleteDocument(ctx context.Context, id uint64) error
	ReplaceChunks(ctx context.Context, document KnowledgeDocument, chunks []TextChunk, indexedAt time.Time) error
	ListChunks(ctx context.Context, documentID uint64) ([]KnowledgeChunk, error)
	ListActiveBaseOptions(ctx context.Context) ([]KnowledgeBaseOptionRow, error)
	ListAgentKnowledgeBindings(ctx context.Context, agentID uint64) ([]AgentKnowledgeBindingRow, error)
	ReplaceAgentKnowledgeBindings(ctx context.Context, agentID uint64, rows []AgentKnowledgeBindingInput) error
	ListRuntimeBindings(ctx context.Context, agentID uint64) ([]RuntimeBindingRow, error)
	ListCandidates(ctx context.Context, baseIDs []uint64, limit int) ([]RetrievalCandidate, error)
	CreateRetrieval(ctx context.Context, input CreateRetrievalInput) (uint64, error)
	FinishRetrieval(ctx context.Context, input FinishRetrievalInput) error
	InsertRetrievalHits(ctx context.Context, retrievalID uint64, hits []ScoredHit) error
}
```

- [ ] **Step 3: Implement validation**

Service validation rules:

```text
name: required, <=128 chars
code: required, <=128 chars, lowercase letters/numbers/underscore/hyphen only
chunk_size_chars: 300..8000
chunk_overlap_chars: < chunk_size_chars, <=1000
default_top_k: 1..20
default_min_score: 0..100
default_max_context_chars: 1000..30000
status: enum.CommonYes or enum.CommonNo
content: required for documents, <= 2MB
```

Use concrete Chinese errors: `AI知识库名称不能为空`、`AI知识库编码不能为空`、`分块重叠必须小于分块大小`、`AI知识库文档内容不能为空`.

- [ ] **Step 4: Register routes**

`route.go` must register exactly the REST paths from the spec. Do not mount `/ai-knowledge-maps`.

- [ ] **Step 5: Update route metadata**

Use existing live permission codes:

```text
ai_knowledge_add
ai_knowledge_edit
ai_knowledge_status
ai_knowledge_del
ai_knowledge_reindex
ai_knowledge_retrieval_test
ai_knowledge_document_add
ai_knowledge_document_edit
ai_knowledge_document_status
ai_knowledge_document_del
```

- [ ] **Step 6: Run backend route and service tests**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/aiknowledge ./internal/server ./internal/bootstrap -count=1
```

Expected: PASS.

- [ ] **Step 7: Commit REST slice**

```powershell
git add admin_back_go/internal/module/aiknowledge admin_back_go/internal/server/router.go admin_back_go/internal/server/router_test.go admin_back_go/internal/bootstrap/app.go admin_back_go/internal/bootstrap/route_meta.go admin_back_go/internal/bootstrap/route_meta_test.go
git commit -m "feat: add ai knowledge rest api"
```

---

## Task 4: Chat runtime RAG integration

**Files:**
- Modify: `admin_back_go/internal/module/aichat/dto.go`
- Modify: `admin_back_go/internal/module/aichat/service.go`
- Modify: `admin_back_go/internal/module/aichat/service_test.go`
- Modify: `admin_back_go/internal/bootstrap/app.go`

- [ ] **Step 1: Add failing tests**

Add tests:

```go
func TestExecuteConversationReplyInjectsKnowledgeContext(t *testing.T)
func TestExecuteConversationReplyContinuesWhenKnowledgeRetrievalFails(t *testing.T)
```

The first test must use a fake `KnowledgeRuntime` returning context containing `Gin modular monolith`, then assert the fake engine receives both that context and the original user message.

The second test must return an error from `KnowledgeRuntime.RetrieveForRun`; assert `StreamChat` is still called with the original user message and the run completes.

- [ ] **Step 2: Add runtime interface**

In `aichat/dto.go` add:

```go
type KnowledgeRuntime interface {
	RetrieveForRun(ctx context.Context, input KnowledgeRuntimeInput) (*KnowledgeContextResult, *apperror.Error)
}

type KnowledgeRuntimeInput struct {
	RunID          uint64
	AgentID        uint64
	ConversationID int64
	UserMessageID  int64
	Query          string
	StartedAt      time.Time
}

type KnowledgeContextResult struct {
	RetrievalID uint64
	Context     string
}
```

- [ ] **Step 3: Wire service dependency**

Add `KnowledgeRuntime KnowledgeRuntime` to `aichat.Dependencies` and `knowledgeRuntime KnowledgeRuntime` to `Service`.

- [ ] **Step 4: Inject context before `StreamChat`**

After `userContent` is found and after run is created:

```go
if s.knowledgeRuntime != nil {
	knowledge, knowledgeErr := s.knowledgeRuntime.RetrieveForRun(ctx, KnowledgeRuntimeInput{
		RunID:          uint64(runID),
		AgentID:        uint64(input.AgentID),
		ConversationID: input.ConversationID,
		UserMessageID:  input.UserMessageID,
		Query:          userContent,
		StartedAt:      startedAt,
	})
	if knowledgeErr == nil && knowledge != nil && strings.TrimSpace(knowledge.Context) != "" {
		userContent = knowledge.Context + "\n\n用户问题：\n" + userContent
	}
	if knowledgeErr != nil {
		_ = repo.AppendRunEvent(context.Background(), runID, "knowledge_failed", knowledgeErr.Message)
	}
}
```

If repository does not yet expose `AppendRunEvent`, add a narrowly named method and implement it using the same event sequence logic as current run events. Do not fail the chat when retrieval fails.

- [ ] **Step 5: Run chat tests**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/aichat -run "Knowledge|ExecuteConversationReply" -count=1
```

Expected: PASS.

- [ ] **Step 6: Commit runtime integration**

```powershell
git add admin_back_go/internal/module/aichat admin_back_go/internal/bootstrap/app.go
git commit -m "feat: add ai chat knowledge retrieval"
```

---

## Task 5: Run monitor retrieval detail backend

**Files:**
- Modify: `admin_back_go/internal/module/airun/dto.go`
- Modify: `admin_back_go/internal/module/airun/repository.go`
- Modify: `admin_back_go/internal/module/airun/service.go`
- Modify: `admin_back_go/internal/module/airun/service_test.go`

- [ ] **Step 1: Add failing service test**

Extend detail test coverage with retrieval data:

```go
func TestDetailIncludesKnowledgeRetrievals(t *testing.T) {
	startedAt := time.Date(2026, 5, 10, 20, 0, 0, 0, time.UTC)
	repo := &fakeRepository{
		detail: &RunDetailRow{ID: 1, Status: "success", CreatedAt: startedAt, UpdatedAt: startedAt},
		knowledgeRetrievals: []KnowledgeRetrievalRow{{ID: 7, RunID: 1, Query: "项目架构", Status: "success", TotalHits: 2, SelectedHits: 1, DurationMS: ptrUint(8), CreatedAt: startedAt}},
		knowledgeHits: map[int64][]KnowledgeHitRow{7: {{ID: 8, RetrievalID: 7, KnowledgeBaseID: 1, KnowledgeBaseName: "架构库", DocumentID: 2, DocumentTitle: "Go 后端架构", ChunkID: 3, ChunkIndex: 1, Score: 0.82, RankNo: 1, ContentSnapshot: "Gin modular monolith", Status: 1, CreatedAt: startedAt}}},
	}
	res, appErr := NewService(repo).Detail(context.Background(), 1)
	if appErr != nil {
		t.Fatalf("Detail returned error: %v", appErr)
	}
	if len(res.KnowledgeRetrievals) != 1 || len(res.KnowledgeRetrievals[0].Hits) != 1 {
		t.Fatalf("missing knowledge retrievals: %#v", res.KnowledgeRetrievals)
	}
}
```

- [ ] **Step 2: Add DTOs**

Add `KnowledgeRetrievalItem`, `KnowledgeHitItem`, row types, and `KnowledgeRetrievals []KnowledgeRetrievalItem json:"knowledge_retrievals"` to `DetailResponse`.

- [ ] **Step 3: Implement repository queries**

Add:

```go
KnowledgeRetrievals(ctx context.Context, runID int64) ([]KnowledgeRetrievalRow, error)
KnowledgeRetrievalHits(ctx context.Context, retrievalID int64) ([]KnowledgeHitRow, error)
```

Queries must filter `is_del=2` and order retrievals by `created_at ASC, id ASC`, hits by `rank_no ASC, id ASC`.

- [ ] **Step 4: Run airun tests**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/airun -count=1
```

Expected: PASS.

- [ ] **Step 5: Commit run monitor backend**

```powershell
git add admin_back_go/internal/module/airun
git commit -m "feat: show knowledge retrievals in ai runs"
```

---

## Task 6: Frontend knowledge API and page components

**Files:**
- Create: `admin_front_ts/src/api/ai/knowledge.ts`
- Create: `admin_front_ts/tests/shared/ai/ai-knowledge-api.test.ts`
- Create component files under `admin_front_ts/src/views/Main/ai/knowledge/components/*`
- Modify: `admin_front_ts/src/views/Main/ai/knowledge/index.vue`
- Modify: `admin_front_ts/src/i18n/locales/zh-CN.ts`
- Modify: `admin_front_ts/src/i18n/locales/en-US.ts`

- [ ] **Step 1: Write API client test first**

`ai-knowledge-api.test.ts` must assert:

```text
AiKnowledgeApi.list -> GET /api/admin/v1/ai-knowledge-bases
AiKnowledgeApi.add -> POST /api/admin/v1/ai-knowledge-bases
AiKnowledgeApi.documents -> GET /api/admin/v1/ai-knowledge-bases/1/documents
AiKnowledgeApi.reindexDocument -> POST /api/admin/v1/ai-knowledge-documents/2/reindex
AiKnowledgeApi.retrievalTest -> POST /api/admin/v1/ai-knowledge-bases/1/retrieval-tests
```

Use the existing helper style from `tests/shared/ai/ai-tools-api.test.ts`.

- [ ] **Step 2: Implement typed API client**

Create `knowledge.ts` with no `legacyRequest` and no `/ai-knowledge-maps` strings. Export:

```ts
export const AiKnowledgeApi = {
  init,
  list,
  detail,
  add,
  edit,
  status,
  del,
  documents,
  documentDetail,
  addDocument,
  editDocument,
  documentStatus,
  deleteDocument,
  reindexDocument,
  chunks,
  retrievalTest,
}
```

- [ ] **Step 3: Implement component split**

Keep `knowledge/index.vue` as a composition surface:

```vue
<script setup lang="ts">
import { ref } from 'vue'
import KnowledgeBaseList from './components/KnowledgeBaseList/index.vue'
import KnowledgeDocumentPanel from './components/KnowledgeDocumentPanel/index.vue'
import type { AiKnowledgeBaseItem } from '@/api/ai/knowledge'

const selectedBase = ref<AiKnowledgeBaseItem | null>(null)
</script>

<template>
  <div class="ai-knowledge-page">
    <KnowledgeBaseList v-model:selected-base="selectedBase" />
    <KnowledgeDocumentPanel :knowledge-base="selectedBase" />
  </div>
</template>
```

Children own their own loading state and emit focused events.

- [ ] **Step 4: Run frontend API tests and typecheck**

```powershell
cd E:\admin_go\admin_front_ts
.\node_modules\.bin\vitest.cmd run tests/shared/ai/ai-knowledge-api.test.ts --maxWorkers=1
npx vue-tsc -b --pretty false
```

Expected: PASS.

- [ ] **Step 5: Commit knowledge frontend page**

```powershell
git add admin_front_ts/src/api/ai/knowledge.ts admin_front_ts/tests/shared/ai/ai-knowledge-api.test.ts admin_front_ts/src/views/Main/ai/knowledge admin_front_ts/src/i18n/locales/zh-CN.ts admin_front_ts/src/i18n/locales/en-US.ts
git commit -m "feat: add ai knowledge management page"
```

---

## Task 7: Agent knowledge binding frontend and API

**Files:**
- Modify: `admin_front_ts/src/api/ai/agents.ts`
- Create: `admin_front_ts/src/views/Main/ai/agents/components/AgentKnowledgeDialog/index.vue`
- Modify: `admin_front_ts/src/views/Main/ai/agents/index.vue`
- Modify: `admin_front_ts/tests/shared/ai/ai-agent-api.test.ts`

- [ ] **Step 1: Add API tests**

Assert endpoints:

```text
AiAgentApi.knowledgeBases({ agent_id: 3 }) -> GET /api/admin/v1/ai-agents/3/knowledge-bases
AiAgentApi.updateKnowledgeBases({ agent_id: 3, bindings: [...] }) -> PUT /api/admin/v1/ai-agents/3/knowledge-bases
```

Expected request body:

```json
{
  "bindings": [
    {
      "knowledge_base_id": 1,
      "top_k": 5,
      "min_score": 0.1,
      "max_context_chars": 6000,
      "status": 1
    }
  ]
}
```

- [ ] **Step 2: Implement agent API methods**

Add types:

```ts
export interface AiAgentKnowledgeBindingItem {
  id?: number
  knowledge_base_id: number
  knowledge_base_name: string
  top_k: number
  min_score: number
  max_context_chars: number
  status: number
}

export interface AiAgentKnowledgeBindingResponse {
  agent_id: number
  bindings: AiAgentKnowledgeBindingItem[]
  base_options: Array<{ label: string; value: number; description: string; default_top_k: number; default_min_score: number; default_max_context_chars: number }>
}
```

- [ ] **Step 3: Implement `AgentKnowledgeDialog`**

Mirror `AgentToolDialog` but use editable rows, not only multi-select. Each row has knowledge base selector, top_k, min_score, max_context_chars, status.

Use `AppDialog` width `760px` and height `60vh`. Do not put this into the main agent add/edit form.

- [ ] **Step 4: Add button in agent list actions**

Add beside Tools:

```vue
<el-button type="success" text @click="openKnowledge(row)">{{ t('aiAgents.actions.knowledge') }}</el-button>
```

If there is a permission guard pattern in the page, use existing `userStore.can('ai_agent_binding_add')` for save action inside dialog.

- [ ] **Step 5: Run agent frontend tests**

```powershell
cd E:\admin_go\admin_front_ts
.\node_modules\.bin\vitest.cmd run tests/shared/ai/ai-agent-api.test.ts --maxWorkers=1
npx vue-tsc -b --pretty false
```

Expected: PASS.

- [ ] **Step 6: Commit agent binding frontend**

```powershell
git add admin_front_ts/src/api/ai/agents.ts admin_front_ts/src/views/Main/ai/agents admin_front_ts/tests/shared/ai/ai-agent-api.test.ts
git commit -m "feat: configure agent knowledge bases"
```

---

## Task 8: Run monitor frontend retrieval block

**Files:**
- Modify: `admin_front_ts/src/api/ai/runs.ts`
- Modify: `admin_front_ts/src/views/Main/ai/runs/*`
- Modify: `admin_front_ts/tests/shared/ai/ai-run-api.test.ts`

- [ ] **Step 1: Add run API type test**

Use a mocked detail response containing one `knowledge_retrievals` item with one hit. Assert client preserves `knowledge_retrievals`, `hits`, `score`, `content_snapshot`, and `skip_reason`.

- [ ] **Step 2: Add types in `runs.ts`**

Add `AiRunKnowledgeRetrievalItem` and `AiRunKnowledgeHitItem` matching backend DTO.

- [ ] **Step 3: Render retrieval block**

In run detail UI, place sections in this order:

```text
运行事件
知识库检索
工具调用
消息内容
```

For each retrieval show query, status_name, selected_hits, total_hits, duration_ms, and error_message. For hits show rank_no, score, knowledge_base_name, document_title, chunk_index, status_name, and skip_reason. Collapse `content_snapshot` by default.

- [ ] **Step 4: Run run API test and typecheck**

```powershell
cd E:\admin_go\admin_front_ts
.\node_modules\.bin\vitest.cmd run tests/shared/ai/ai-run-api.test.ts --maxWorkers=1
npx vue-tsc -b --pretty false
```

Expected: PASS.

- [ ] **Step 5: Commit monitor frontend**

```powershell
git add admin_front_ts/src/api/ai/runs.ts admin_front_ts/src/views/Main/ai/runs admin_front_ts/tests/shared/ai/ai-run-api.test.ts
git commit -m "feat: display ai knowledge retrievals"
```

---

## Task 9: Docs, smoke, and final verification

**Files:**
- Modify: `docs/contracts/admin-api-v1.md`
- Modify: `docs/migration/current-status.md`
- Modify: `docs/testing/smoke-matrix.md`
- Modify: `admin_back_go/scripts/full-admin-smoke.ps1`
- Modify: `admin_back_go/docs/architecture.md` if AI runtime section exists

- [ ] **Step 1: Update API contract**

Add an `AI Knowledge Bases` section with endpoints, table names, field rules, permissions, runtime flow, and run detail response shape from the spec.

Add to `AI Runs Monitor` section:

```text
Detail response includes knowledge_retrievals when the run attempted local knowledge retrieval. This is separate from tool_calls. Retrieval records are written before the model call and hit records snapshot the chunks used or skipped.
```

- [ ] **Step 2: Update smoke script**

Add read-only checks:

```powershell
$aiKnowledgeInit = Invoke-AdminApi GET "$BaseUrl/api/admin/v1/ai-knowledge-bases/page-init" $headers
$aiKnowledgeList = Invoke-AdminApi GET "$BaseUrl/api/admin/v1/ai-knowledge-bases?current_page=1&page_size=20" $headers
$aiKnowledgeSeed = $aiKnowledgeList.data.list | Where-Object { $_.code -eq 'admin_go_project_architecture' } | Select-Object -First 1

Write-SmokeResult "ai_knowledge_init_code" $aiKnowledgeInit.code
Write-SmokeResult "ai_knowledge_list_code" $aiKnowledgeList.code
Write-SmokeResult "ai_knowledge_seed_present" ([bool]$aiKnowledgeSeed)
```

If the smoke helper has different local names, keep the same style as nearby AI provider/tool checks and write the same three result names.

- [ ] **Step 3: Run backend verification**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/aiknowledge ./internal/module/aichat ./internal/module/airun ./internal/server ./internal/bootstrap -count=1
go vet -p=1 ./...
```

Expected: PASS.

- [ ] **Step 4: Run frontend verification**

```powershell
cd E:\admin_go\admin_front_ts
.\node_modules\.bin\vitest.cmd run tests/shared/ai/ai-knowledge-api.test.ts tests/shared/ai/ai-agent-api.test.ts tests/shared/ai/ai-run-api.test.ts --maxWorkers=1
npx vue-tsc -b --pretty false
npm run build:check
```

Expected: PASS.

- [ ] **Step 5: Run smoke syntax check**

```powershell
cd E:\admin_go\admin_back_go
powershell -NoProfile -Command '$null = [scriptblock]::Create((Get-Content -Raw .\scripts\full-admin-smoke.ps1)); "syntax ok"'
```

Expected:

```text
syntax ok
```

- [ ] **Step 6: Run diff hygiene**

```powershell
cd E:\admin_go
git diff --check
git -C admin_back_go diff --check
git -C admin_front_ts diff --check
```

Expected: no whitespace errors. CRLF/LF warnings are acceptable only if they already exist and do not point to new malformed whitespace.

- [ ] **Step 7: Update current status only after verification**

In `docs/migration/current-status.md`, add or replace the knowledge row only after Steps 3-6 pass. Use wording:

```text
AI knowledge base RAG MVP | implemented: active tables are ai_knowledge_bases, ai_knowledge_documents, ai_knowledge_chunks, ai_agent_knowledge_bases, ai_knowledge_retrievals, ai_knowledge_retrieval_hits; /ai/knowledge manages local bases/documents/chunks/retrieval tests; /ai/agents owns knowledge-base binding; aichat retrieves bound knowledge before model call and airun detail displays retrievals/hits | adapted | tests... | smoke... | contract... | no vector DB, no hosted file_search, no Dify/RAGFlow dataset sync in this slice
```

- [ ] **Step 8: Commit docs and smoke**

```powershell
git add docs/contracts/admin-api-v1.md docs/migration/current-status.md docs/testing/smoke-matrix.md admin_back_go/scripts/full-admin-smoke.ps1 admin_back_go/docs/architecture.md
git commit -m "docs: record ai knowledge rag runtime"
```

---

## Final acceptance checklist

- [ ] Live DB has all six knowledge tables.
- [ ] `admin_go_project_architecture` exists in `ai_knowledge_bases`.
- [ ] Seed documents and chunks are inserted.
- [ ] `/api/admin/v1/ai-knowledge-bases/page-init` returns dictionaries and no legacy map fields.
- [ ] `/api/admin/v1/ai-knowledge-bases` lists the seed knowledge base.
- [ ] Agent knowledge binding is stored in `ai_agent_knowledge_bases`, not `ai_agents` JSON.
- [ ] Chat without bound knowledge behaves as before.
- [ ] Chat with bound knowledge writes `ai_knowledge_retrievals` and `ai_knowledge_retrieval_hits`.
- [ ] Run detail includes `knowledge_retrievals` and existing `tool_calls` still work.
- [ ] Frontend uses `src/api/ai/knowledge.ts`, not `knowledgeMaps.ts`.
- [ ] `aiknowledgemap` active route wiring is removed or left unreachable with tests proving old `/ai-knowledge-maps` is not the active contract.
- [ ] Backend tests, frontend tests, typecheck, build check, and smoke syntax check pass.
