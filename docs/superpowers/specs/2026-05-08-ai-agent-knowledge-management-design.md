# AI Agent and Knowledge Management Design

状态：implemented on 2026-05-08。本文定义并记录 AI P2 管理面迁移；当前 Go REST、前端 typed clients、docs、smoke、focused gates 已完成。
日期：2026-05-08

## Linus 三问

1. 真问题：是。AI P1 已把 `ai_models`、`ai_tools`、`ai_prompts` 迁到 Go；但智能体和知识库仍由 PHP 提供。后续 chat runtime 如果继续读取 PHP 管理态，就是把新运行时建在旧地基上。
2. 更简单做法：先迁管理态，不碰模型调用、不碰 WebSocket streaming。Agent 只管理配置和绑定；Knowledge 只做 MySQL 文本切片和关键词召回测试，不引入向量库或 Python sidecar。
3. 会破坏什么：不能把已删除的 goods/cine 场景重新放回可选项；不能误删历史 run/message/conversation；不能改 AI chat 页面行为；不能把 `/api/admin/AiAgents/add` 这种 PHP action path 搬进 Go。

## 当前运行事实

### 已完成前置

```text
AI Phase 0 prune: goods/cine 产品模块删除，/ai/goods 与 /ai/cine 菜单删除，retired goods/cine agents/tools soft-delete。
AI P1 config: ai_models、ai_tools、ai_prompts 已由 Go REST 负责。
```

### 当前 Go REST 前端入口

```text
admin_front_ts/src/api/ai/agents.ts
  GET    /api/admin/v1/ai-agents/page-init
  GET    /api/admin/v1/ai-agents
  POST   /api/admin/v1/ai-agents
  PUT    /api/admin/v1/ai-agents/:id
  PATCH  /api/admin/v1/ai-agents/:id/status
  DELETE /api/admin/v1/ai-agents/:id

admin_front_ts/src/api/ai/knowledge.ts
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
  POST   /api/admin/v1/ai-knowledge-bases/retrieval-test
```

旧 `/api/admin/AiAgents/*` 和 `/api/admin/AiKnowledgeBases/*` 只作为迁移前事实保留在历史 plan/spec，不是当前 active contract。

### Live DB 事实

```text
ai_agents: 11
ai_agent_scenes: 4
ai_agent_knowledge_bases: 2
ai_knowledge_bases: 2
ai_knowledge_documents: 6
ai_knowledge_chunks: 7
```

Retired scene 状态：

```text
ai_agents goods_script/cine_project/cine_keyframe rows are is_del=1,status=2.
ai_agent_scenes goods_script/cine_project/cine_keyframe rows are is_del=1,status=2.
```

当前 active AI 页面权限：

```text
/ai/agents id=48
/ai/knowledge id=122
```

当前 active knowledge button codes：

```text
ai_knowledge_add
ai_knowledge_edit
ai_knowledge_del
ai_knowledge_status
ai_knowledge_document_add
ai_knowledge_document_edit
ai_knowledge_document_del
ai_knowledge_reindex
ai_knowledge_retrieval_test
```

当前 DB 没有 `ai_agent_*` button codes；如果要给 agent 新增按钮权限，必须写 migration seed，不准前端硬编码不存在的权限码。

## Scope

### 必须迁 Go

Agent management:

```text
ai_agents
ai_agent_scenes
ai_assistant_tools
ai_agent_knowledge_bases
```

Knowledge management:

```text
ai_knowledge_bases
ai_knowledge_documents
ai_knowledge_chunks
```

Frontend:

```text
admin_front_ts/src/api/ai/agents.ts -> request + Go REST
admin_front_ts/src/api/ai/knowledge.ts -> request + Go REST
```

### 明确不做

```text
不做 chat runtime。
不调用 LLM。
不执行 tool。
不把 agent 运行状态写入 runs。
不做向量库、不做 embedding worker、不做 Python sidecar。
不做文件上传解析；P2 文档内容只接受 manual/text。
不恢复 goods_script、cine_project、cine_keyframe active options。
不改 ai_conversations、ai_messages、ai_runs、ai_run_steps。
```

## Go enum/dict foundation

当前 Go `internal/enum/ai.go` 只有 driver/executor。P2 必须补上并测试：

```text
Agent mode:
  chat -> 对话
  rag -> RAG
  tool -> 工具
  workflow -> 工作流

Agent capability:
  tools -> 工具调用
  rag -> RAG知识库
  workflow -> 工作流编排

Knowledge visibility:
  private -> 私有
  team -> 团队
  public -> 公开

Knowledge index status:
  1 -> 已索引
  2 -> 索引失败

Knowledge source type:
  manual -> 手动录入
  text -> 文本
```

P2 active scene options：

```text
第一版不提供 goods/cine retired scene。
如果 live DB 只有 retired scene rows，则 ai_scene_arr 返回空数组。
普通对话 scene 允许 null/empty。
```

## API Contract

### Agent page-init

`GET /api/admin/v1/ai-agents/page-init`

Response:

```ts
interface AiAgentInitResponse {
  dict: {
    ai_mode_arr: Array<{ label: string; value: string }>
    ai_capability_arr: Array<{ label: string; value: string }>
    ai_scene_arr: Array<{ label: string; value: string }>
    common_status_arr: Array<{ label: string; value: number }>
    model_list: Array<{ label: string; value: number }>
    knowledge_base_list: Array<{ label: string; value: number }>
  }
}
```

Rules:

```text
model_list comes from active ai_models is_del=2,status=1.
knowledge_base_list comes from active ai_knowledge_bases is_del=2,status=1.
ai_scene_arr comes from active ai_agent_scenes is_del=2,status=1, excluding goods_script/cine_project/cine_keyframe.
```

### Agent CRUD

```text
GET    /api/admin/v1/ai-agents
POST   /api/admin/v1/ai-agents
PUT    /api/admin/v1/ai-agents/:id
PATCH  /api/admin/v1/ai-agents/:id/status
DELETE /api/admin/v1/ai-agents/:id
```

List query:

```ts
interface AiAgentListQuery {
  current_page?: number
  page_size?: number
  name?: string
  model_id?: number
  mode?: 'chat' | 'rag' | 'tool' | 'workflow'
  status?: number
}
```

Mutation request:

```ts
interface AiAgentMutationRequest {
  name: string
  model_id: number
  avatar?: string | null
  system_prompt?: string | null
  mode?: 'chat' | 'rag' | 'tool' | 'workflow'
  scene?: string | null
  capabilities?: { chat?: boolean; tools?: boolean; rag?: boolean; workflow?: boolean }
  scene_codes?: string[]
  runtime_config?: Record<string, unknown> | null
  policy?: Record<string, unknown> | null
  status?: number
  tool_ids?: number[]
  knowledge_base_ids?: number[]
}
```

Rules:

```text
name length 1..50.
model_id must reference ai_models is_del=2,status=1.
mode defaults to chat.
scene empty/null is allowed.
scene and scene_codes must not include goods_script/cine_project/cine_keyframe.
capabilities is JSON object; normalize missing chat to true in response only, not as a fake stored key unless existing convention requires it.
runtime_config/policy must be JSON object or null.
tool_ids must reference ai_tools is_del=2,status=1.
knowledge_base_ids must reference ai_knowledge_bases is_del=2,status=1.
Create/update of agent plus tool/knowledge bindings must be one DB transaction.
Delete is soft delete of ai_agents and associated active binding rows.
List includes model_name/model_deleted, driver/driver_name/model_code, scene_names, knowledge_base_names and status_name.
```

### Knowledge base CRUD

```text
GET    /api/admin/v1/ai-knowledge-bases/page-init
GET    /api/admin/v1/ai-knowledge-bases
GET    /api/admin/v1/ai-knowledge-bases/:id
POST   /api/admin/v1/ai-knowledge-bases
PUT    /api/admin/v1/ai-knowledge-bases/:id
PATCH  /api/admin/v1/ai-knowledge-bases/:id/status
DELETE /api/admin/v1/ai-knowledge-bases/:id
```

Rules:

```text
name length 1..80.
visibility in private/team/public.
permission_json JSON object or null.
chunk_size 100..4000, default DB 800.
chunk_overlap 0..1000, and must be smaller than chunk_size.
top_k 1..20.
score_threshold 0..100.
Delete soft-deletes knowledge base, documents, chunks, and ai_agent_knowledge_bases bindings in one transaction.
```

### Knowledge documents/chunks/retrieval

```text
GET    /api/admin/v1/ai-knowledge-bases/:id/documents
GET    /api/admin/v1/ai-knowledge-bases/:id/documents/:document_id
POST   /api/admin/v1/ai-knowledge-bases/:id/documents
PUT    /api/admin/v1/ai-knowledge-bases/:id/documents/:document_id
DELETE /api/admin/v1/ai-knowledge-bases/:id/documents/:document_id
POST   /api/admin/v1/ai-knowledge-bases/:id/documents/:document_id/reindex
GET    /api/admin/v1/ai-knowledge-bases/:id/chunks
POST   /api/admin/v1/ai-knowledge-bases/:id/retrieval-tests
```

Document mutation request:

```ts
interface AiKnowledgeDocumentMutationRequest {
  title: string
  source_type?: 'manual' | 'text'
  content: string
  status?: number
}
```

Rules:

```text
title length 1..120.
source_type only manual/text in P2, even if enum keeps file/url reserved for future.
content must be non-empty.
Reindex deletes old chunks for document then creates deterministic chunks from content.
Chunking uses knowledge_base.chunk_size and chunk_overlap.
index_status=1 after successful reindex, index_status=2 on validation/index error.
chunk_count equals active chunks count.
chunks list filters by optional document_id and returns only active chunks.
retrieval-tests uses MySQL keyword scoring only: no vector, no embedding_json, no external service.
retrieval response returns chunks and context_prompt.
```

## RBAC and OperationLog

Knowledge existing permission codes must be wired:

```text
POST   /api/admin/v1/ai-knowledge-bases                       -> ai_knowledge_add
PUT    /api/admin/v1/ai-knowledge-bases/:id                   -> ai_knowledge_edit
PATCH  /api/admin/v1/ai-knowledge-bases/:id/status            -> ai_knowledge_status
DELETE /api/admin/v1/ai-knowledge-bases/:id                   -> ai_knowledge_del
POST   /api/admin/v1/ai-knowledge-bases/:id/documents         -> ai_knowledge_document_add
PUT    /api/admin/v1/ai-knowledge-bases/:id/documents/:doc_id -> ai_knowledge_document_edit
DELETE /api/admin/v1/ai-knowledge-bases/:id/documents/:doc_id -> ai_knowledge_document_del
POST   /api/admin/v1/ai-knowledge-bases/:id/documents/:doc_id/reindex -> ai_knowledge_reindex
POST   /api/admin/v1/ai-knowledge-bases/:id/retrieval-tests   -> ai_knowledge_retrieval_test
```

Agent mutation permission decision:

```text
Preferred: add DB migration for ai_agent_add/edit/del/status and wire route_meta.
Fallback only if no UI permission gating exists yet: auth + OperationLog without button permission, but document the gap in current-status.
```

All mutating routes must have OperationLog metadata. Read routes must not.

## Verification gates

```powershell
cd E:\admin_go\admin_back_go
$env:GOMAXPROCS='2'
go test -p=1 ./internal/enum ./internal/dict ./internal/module/aiagent ./internal/module/aiknowledge ./internal/server ./internal/bootstrap
go vet -p=1 ./internal/module/aiagent ./internal/module/aiknowledge
powershell -ExecutionPolicy Bypass -File .\scripts\check-contract.ps1

cd E:\admin_go\admin_front_ts
npx vitest run tests/shared/ai/ai-agent-api.test.ts tests/shared/ai/ai-knowledge-api.test.ts
npx vue-tsc -b --pretty false

cd E:\admin_go\admin_back_go
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account 15671628271 -Password 123456
```

Smoke 必须证明：

```text
GET /api/admin/v1/ai-agents/page-init/list works.
GET /api/admin/v1/ai-agents/page-init ai_scene_arr does not include goods_script/cine_project/cine_keyframe.
GET /api/admin/v1/ai-knowledge-bases/page-init/list/detail works.
Document reindex can rebuild chunks for a controlled test document when mutation probe is enabled.
Retrieval test returns deterministic MySQL keyword results.
Frontend agents.ts/knowledge.ts contain no legacyRequest and no /api/admin/AiAgents or /api/admin/AiKnowledgeBases paths.
```

## Status wording after implementation

允许说：

```text
AI agent and knowledge management migrated to Go REST.
```

禁止说：

```text
AI chat migrated.
AI runtime migrated.
AI streaming migrated.
RAG/vector search implemented.
```

## Self-review

```text
Scope is one management slice: agent config + knowledge CRUD/chunk/retrieval-test.
No placeholder remains: endpoints, table ownership, enum additions, permission rules, and verification gates are explicit.
Runtime is deliberately excluded; this prevents building chat on mixed PHP/Go management truth.
```
