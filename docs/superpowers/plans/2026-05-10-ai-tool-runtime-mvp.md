# AI Tool Runtime MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** 落地第一版真实 AI tool runtime：工具定义、智能体绑定、工具调用审计，以及只读测试工具 `admin_user_count`。

**Architecture:** `ai_tools` 定义工具，`ai_agent_tools` 绑定智能体，`ai_tool_calls` 记录每次调用。`aichat` 负责编排模型 tool call，`aitool` 负责管理 API + executor registry，provider 只接收结构化 tools，不拼 prompt。

**Tech Stack:** Go + Gin + GORM + MySQL 8 + existing OpenAI-compatible streaming client; Vue 3 + TypeScript + Element Plus.

---

## Scope Lock

只做：

```text
local function tool runtime
admin_user_count read-only executor
agent-tool binding
run-monitor tool call visibility
```

不做：

```text
external HTTP tools / MCP / RAG / write-operation tools
manual execute button / billing / ai_agents tool_ids_json / ai_tool_maps resurrection
```

迁移已经写入并应用到 live DB：

```text
admin_back_go/database/migrations/20260510_ai_tool_runtime_mvp.sql
```

---

## Task 1: Backend `aitool` management module

**Files:**
- Create: `admin_back_go/internal/module/aitool/model.go`
- Create: `admin_back_go/internal/module/aitool/dto.go`
- Create: `admin_back_go/internal/module/aitool/request.go`
- Create: `admin_back_go/internal/module/aitool/repository.go`
- Create: `admin_back_go/internal/module/aitool/executor.go`
- Create: `admin_back_go/internal/module/aitool/service.go`
- Create: `admin_back_go/internal/module/aitool/handler.go`
- Create: `admin_back_go/internal/module/aitool/route.go`
- Test: `admin_back_go/internal/module/aitool/service_test.go`

- [x] **Step 1: Add models**

Create models for `ai_tools`, `ai_agent_tools`, `ai_tool_calls`, and minimal `ai_agents` read model. No `ai_tool_maps`.

- [x] **Step 2: Add DTO contracts**

Expose:

```text
Init/List/Create/Update/Status/Delete
AgentTools
UpdateAgentTools
RuntimeTool
ToolCallStart/Finish
Executor
```

The DTO must include only fields in the three live tables. No `engine_tool_id`, `permission_code`, `config_json`, `tool_type`.

- [x] **Step 3: Add strict requests**

`mutationRequest` accepts:

```json
{
  "name": "查询当前用户量",
  "code": "admin_user_count",
  "description": "查询后台当前用户数量，只返回数量。",
  "executor": "admin_user_count",
  "parameters_json": {"type":"object","properties":{},"additionalProperties":false},
  "result_schema_json": {"type":"object","properties":{},"additionalProperties":false},
  "risk_level": "low",
  "timeout_ms": 3000,
  "status": 1
}
```

Rules:

```text
parameters_json/result_schema_json must be JSON object
timeout_ms range: 100..30000
risk_level: low/medium/high
status: 1/2
```

- [x] **Step 4: Implement repository**

Repository must support:

```text
List/GetRaw/ExistsByCode/Create/Update/ChangeStatus/Delete
AgentExists/ListAllActiveToolIDs/ListBoundToolIDs/ReplaceAgentTools
ListRuntimeTools/StartToolCall/FinishToolCall/CountUsers
```

`ReplaceAgentTools` must verify agent exists and every tool id is active, then update bindings in one transaction.

- [x] **Step 5: Implement executor registry**

`executor.go`:

```go
func DefaultExecutors(repo Repository) map[string]Executor {
	return map[string]Executor{
		"admin_user_count": NewAdminUserCountExecutor(repo),
	}
}
```

`admin_user_count` executor returns:

```json
{"total_users":1015,"enabled_users":1015,"disabled_users":0}
```

It must only run:

```sql
SELECT COUNT(*) AS total_users,
       SUM(CASE WHEN status = 1 THEN 1 ELSE 0 END) AS enabled_users,
       SUM(CASE WHEN status = 2 THEN 1 ELSE 0 END) AS disabled_users
FROM users
WHERE is_del = 2;
```

- [x] **Step 6: Implement service**

Service rules:

```text
Create/Update trim strings and reject invalid JSON object
duplicate code rejected
Delete soft-deletes tool and disables related agent bindings
Runtime ListRuntimeTools loads only enabled binding + enabled tool
Execute rejects unknown executor
```

- [x] **Step 7: Add handlers/routes**

Routes:

```text
GET    /api/admin/v1/ai-tools/page-init
GET    /api/admin/v1/ai-tools
POST   /api/admin/v1/ai-tools
PUT    /api/admin/v1/ai-tools/:id
PATCH  /api/admin/v1/ai-tools/:id/status
DELETE /api/admin/v1/ai-tools/:id
GET    /api/admin/v1/ai-agents/:id/tools
PUT    /api/admin/v1/ai-agents/:id/tools
```

- [x] **Step 8: Unit tests**

Test:

```text
Create rejects array/string/null schemas
Create stores tool fields exactly
UpdateAgentTools replaces bindings
ListRuntimeTools filters disabled bindings/tools
admin_user_count returns counts and no personal fields
```

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/aitool -count=1
```

---

## Task 2: Wire router, bootstrap, permissions

**Files:**
- Modify: `admin_back_go/internal/server/router.go`
- Modify: `admin_back_go/internal/server/router_test.go`
- Modify: `admin_back_go/internal/bootstrap/app.go`
- Modify: `admin_back_go/internal/bootstrap/route_meta.go`
- Modify: `admin_back_go/internal/bootstrap/route_meta_test.go`

- [x] Replace `AiToolMapService` with `AiToolService aitool.HTTPService`.
- [x] Register `aitool.RegisterRoutes(router, deps.AiToolService)`.
- [x] Remove active `aitoolmap.RegisterRoutes`.
- [x] Bootstrap:

```go
aiToolRepo := aitool.NewGormRepository(resources.Database)
aiToolService := aitool.NewService(aiToolRepo, aitool.DefaultExecutors(aiToolRepo))
```

- [x] Route permissions:

```text
POST   /api/admin/v1/ai-tools -> ai_tool_add
PUT    /api/admin/v1/ai-tools/:id -> ai_tool_edit
PATCH  /api/admin/v1/ai-tools/:id/status -> ai_tool_status
DELETE /api/admin/v1/ai-tools/:id -> ai_tool_del
PUT    /api/admin/v1/ai-agents/:id/tools -> ai_agent_edit
```

- [x] Read routes require only bearer token.
- [x] OperationLog modules:

```text
ai_tool: create/update/change_status/delete
ai_agent_tool: update_binding
```

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/server ./internal/bootstrap -count=1
```

---

## Task 3: Extend `platform/ai` tool contract

**Files:**
- Modify: `admin_back_go/internal/platform/ai/types.go`
- Modify: `admin_back_go/internal/platform/ai/fake.go`
- Modify: `admin_back_go/internal/platform/ai/openaicompat/client.go`
- Modify: `admin_back_go/internal/platform/ai/openaicompat/client_test.go`

- [x] Add:

```go
type ToolDefinition struct {
	Name        string
	Description string
	Parameters  map[string]any
}

type ToolCall struct {
	ID        string
	Name      string
	Arguments string
}

type ToolOutput struct {
	CallID string
	Name   string
	Output string
}
```

- [x] Extend `ChatInput`:

```go
Tools       []ToolDefinition
ToolOutputs []ToolOutput
```

- [x] Extend `ChatResult`:

```go
ToolCalls []ToolCall
```

- [x] OpenAI-compatible client sends Chat Completions `tools`:

```json
{
  "type": "function",
  "function": {
    "name": "admin_user_count",
    "description": "...",
    "parameters": {"type":"object","properties":{},"additionalProperties":false}
  }
}
```

- [x] Stream parser accumulates `delta.tool_calls[].function.arguments`.
- [x] If a stream returns tool calls, return `ChatResult.ToolCalls` instead of final answer.
- [x] A second model call with `ToolOutputs` must include tool output messages.
- [x] MVP allows one tool round; more rounds are rejected in `aichat`.

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/platform/ai ./internal/platform/ai/openaicompat -count=1
```

---

## Task 4: Execute tools inside `aichat`

**Files:**
- Modify: `admin_back_go/internal/module/aichat/dto.go`
- Modify: `admin_back_go/internal/module/aichat/service.go`
- Modify: `admin_back_go/internal/module/aichat/service_test.go`
- Modify: `admin_back_go/internal/bootstrap/app.go`

- [x] Add `ToolRuntime` dependency to `aichat.Dependencies`.
- [x] After `CreateRun`, load `ListRuntimeTools(agent_id)`.
- [x] Convert runtime tools to `platformai.ToolDefinition`.
- [x] First `engine.StreamChat` may return `ToolCalls`.
- [x] For each call:

```text
find bound tool by call.Name == tool.Code
reject unbound/unknown
reject risk_level != low
StartToolCall(running)
context.WithTimeout(timeout_ms)
Execute executor
FinishToolCall(success/failed/timeout)
return output JSON to provider
```

- [x] Call model a second time with `ToolOutputs`.
- [x] If second call returns tool calls, fail run with `工具调用轮次超过MVP限制`.
- [x] Existing WebSocket delta flow stays unchanged.

Tests:

```text
bound tool is passed as structured tool definition
admin_user_count tool call records success
unknown tool records run failure
timeout records ai_tool_calls.status=timeout
second tool-call round is rejected
```

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/aichat -count=1
```

---

## Task 5: Run monitor detail includes tool calls

**Files:**
- Modify: `admin_back_go/internal/module/airun/dto.go`
- Modify: `admin_back_go/internal/module/airun/repository.go`
- Modify: `admin_back_go/internal/module/airun/service.go`
- Modify: `admin_front_ts/src/api/ai/runs.ts`
- Modify: `admin_front_ts/src/views/Main/ai/runs/*`

- [x] Add detail field:

```json
"tool_calls": [
  {
    "id": 1,
    "tool_id": 1,
    "tool_code": "admin_user_count",
    "tool_name": "查询当前用户量",
    "call_id": "call_xxx",
    "status": "success",
    "arguments_json": {},
    "result_json": {"total_users":1015,"enabled_users":1015,"disabled_users":0},
    "error_message": "",
    "duration_ms": 5,
    "started_at": "2026-05-10 12:00:00",
    "finished_at": "2026-05-10 12:00:00"
  }
]
```

- [x] Query `ai_tool_calls WHERE run_id = ? ORDER BY id ASC`.
- [x] Frontend detail dialog renders arguments/result pretty JSON.
- [x] Do not reintroduce fake execution steps.

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/airun -count=1
```

---

## Task 6: Frontend `/ai/tools` real tool UI

**Files:**
- Create: `admin_front_ts/src/api/ai/tools.ts`
- Modify: `admin_front_ts/src/api/ai/agents.ts`
- Rewrite: `admin_front_ts/src/views/Main/ai/tools/index.vue`
- Modify: `admin_front_ts/src/views/Main/ai/agents/index.vue`
- Create: `admin_front_ts/src/views/Main/ai/tools/components/ToolList/index.vue`
- Create: `admin_front_ts/src/views/Main/ai/tools/components/ToolFormDialog/index.vue`
- Create: `admin_front_ts/src/views/Main/ai/agents/components/AgentToolDialog/index.vue`
- Modify: `admin_front_ts/src/i18n/locales/zh-CN.ts`
- Modify: `admin_front_ts/src/i18n/locales/en-US.ts`

- [x] `tools.ts` must use typed DTOs, no `any`, no old aliases.
- [x] Route-level `index.vue` only composes state/dialogs.
- [x] `ToolList` owns search/table/actions.
- [x] `ToolFormDialog` owns create/edit form.
- [x] `/ai/tools` only owns tool definition UI.
- [x] `AgentToolDialog` under `/ai/agents` owns tool usage configuration for the selected agent.
- [x] Remove UI fields:

```text
tool_type
engine_tool_id
permission_code
config_json
provider_id on tool row
agent_id on tool row
```

Run:

```powershell
cd E:\admin_go\admin_front_ts
npx vue-tsc -b --pretty false
```

---

## Task 7: Docs, smoke, residue cleanup

**Files:**
- Modify: `docs/contracts/admin-api-v1.md`
- Modify: `docs/testing/smoke-matrix.md`
- Modify: `docs/migration/current-status.md`
- Modify: `admin_back_go/docs/architecture.md`
- Modify: `admin_back_go/scripts/full-admin-smoke.ps1`

- [x] Replace old `AI Tool Maps` active contract with:

```text
AI Tools Runtime MVP
Tables: ai_tools, ai_agent_tools, ai_tool_calls
First executor: admin_user_count
No active ai_tool_maps table
```

- [x] Smoke asserts:

```text
GET /ai-tools/page-init shape
GET /ai-tools contains admin_user_count
GET /ai-agents/options returns active chat agents
GET /ai-agents/:id/tools includes admin_user_count for seeded agents
GET /ai-runs/:id includes tool_calls field
```

- [x] Residue scan:

```powershell
rg -n "ai-tool-maps|ai_tool_maps|AiToolMap|toolMaps|engine_tool_id|permission_code|dify_tool|workflow_node|admin_action_gateway|http_reference" admin_back_go/internal admin_front_ts/src docs/contracts/admin-api-v1.md docs/migration/current-status.md admin_back_go/docs/architecture.md
```

Expected: no active runtime/contract references.

- [x] Full verification:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/aitool ./internal/module/aichat ./internal/module/airun ./internal/platform/ai ./internal/platform/ai/openaicompat ./internal/server ./internal/bootstrap -count=1

cd E:\admin_go\admin_front_ts
npx vue-tsc -b --pretty false
```

Expected: all pass.
