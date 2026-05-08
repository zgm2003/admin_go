# AI Core P1 Config Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate AI model/tool/prompt configuration from legacy PHP POST APIs to Go REST without touching AI chat/runtime/agents/knowledge execution.

**Architecture:** Add three small Go modules (`aimodel`, `aitool`, `aiprompt`) following existing `route -> handler -> service -> repository -> model` style. Keep model API keys encrypted and masked, keep prompts scoped to current user, keep tool binding as a configuration-only endpoint, and switch only the three frontend API clients to `request` + `/api/admin/v1/*`.

**Tech Stack:** Go/Gin/Gorm/secretbox, MySQL `ai_models` / `ai_tools` / `ai_assistant_tools` / `ai_prompts`, Vue 3 + TypeScript, existing `request` HTTP client, Vitest source-contract tests, repo smoke scripts.

---

## Master rule

P1 means config only:

```text
Migrate: ai_models, ai_tools, ai_prompts.
Do not migrate: agents, knowledge, chat, runs, streaming, model execution, RAG.
Never reintroduce goods/cine adapters.
```

## File map

### Create

- `admin_back_go/internal/enum/ai.go`
- `admin_back_go/internal/enum/ai_test.go`
- `admin_back_go/internal/dict/ai_test.go`
- `admin_back_go/internal/module/aimodel/{model.go,dto.go,request.go,handler.go,route.go,repository.go,service.go,service_test.go}`
- `admin_back_go/internal/module/aitool/{model.go,dto.go,request.go,handler.go,route.go,repository.go,service.go,service_test.go}`
- `admin_back_go/internal/module/aiprompt/{model.go,dto.go,request.go,handler.go,route.go,repository.go,service.go,service_test.go}`
- `admin_front_ts/tests/shared/ai/ai-model-api.test.ts`
- `admin_front_ts/tests/shared/ai/ai-tool-api.test.ts`
- `admin_front_ts/tests/shared/ai/ai-prompt-api.test.ts`

### Modify

- `admin_back_go/internal/dict/dict.go`
- `admin_back_go/internal/server/router.go`
- `admin_back_go/internal/server/router_test.go`
- `admin_back_go/internal/bootstrap/app.go`
- `admin_back_go/internal/bootstrap/route_meta.go`
- `admin_back_go/internal/bootstrap/route_meta_test.go`
- `admin_back_go/scripts/full-admin-smoke.ps1`
- `admin_front_ts/src/api/ai/models.ts`
- `admin_front_ts/src/api/ai/tools.ts`
- `admin_front_ts/src/api/ai/prompts.ts`
- `docs/contracts/admin-api-v1.md`
- `docs/migration/current-status.md`
- `docs/testing/smoke-matrix.md`
- `admin_back_go/docs/architecture.md`

---

## Task 1: Add AI enum/dict foundation first

**Files:**
- Create: `admin_back_go/internal/enum/ai.go`
- Create: `admin_back_go/internal/enum/ai_test.go`
- Modify: `admin_back_go/internal/dict/dict.go`
- Create: `admin_back_go/internal/dict/ai_test.go`

- [ ] **Step 1: Write failing enum tests**

Create `admin_back_go/internal/enum/ai_test.go`:

```go
package enum

import "testing"

func TestAIDriverAndExecutorEnums(t *testing.T) {
	if !IsAIDriver(AIDriverOpenAI) || !IsAIDriver(AIDriverQwen) || IsAIDriver("goods") {
		t.Fatalf("unexpected AI driver validation")
	}
	if !IsAIExecutorType(AIExecutorInternal) || !IsAIExecutorType(AIExecutorHTTPWhitelist) || !IsAIExecutorType(AIExecutorSQLReadonly) || IsAIExecutorType(9) {
		t.Fatalf("unexpected AI executor validation")
	}
}
```

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/enum -run TestAIDriverAndExecutorEnums
```

Expected: fail because `AIDriverOpenAI` and helpers do not exist.

- [ ] **Step 2: Implement enum**

Create `admin_back_go/internal/enum/ai.go` with:

```go
package enum

const (
	AIDriverOpenAI      = "openai"
	AIDriverClaude      = "claude"
	AIDriverDeepSeek    = "deepseek"
	AIDriverGemini      = "gemini"
	AIDriverMistral     = "mistral"
	AIDriverCohere      = "cohere"
	AIDriverGrok        = "grok"
	AIDriverOllama      = "ollama"
	AIDriverHuggingFace = "huggingface"
	AIDriverQwen        = "qwen"
	AIDriverMoonshot    = "moonshot"
	AIDriverZhipu       = "zhipu"
	AIDriverHunyuan     = "hunyuan"
	AIDriverWenxin      = "wenxin"
)

var AIDrivers = []string{AIDriverOpenAI, AIDriverClaude, AIDriverDeepSeek, AIDriverGemini, AIDriverMistral, AIDriverCohere, AIDriverGrok, AIDriverOllama, AIDriverHuggingFace, AIDriverQwen, AIDriverMoonshot, AIDriverZhipu, AIDriverHunyuan, AIDriverWenxin}

var AIDriverLabels = map[string]string{AIDriverOpenAI: "OpenAI", AIDriverClaude: "Claude", AIDriverDeepSeek: "DeepSeek", AIDriverGemini: "Gemini", AIDriverMistral: "Mistral", AIDriverCohere: "Cohere", AIDriverGrok: "Grok (xAI)", AIDriverOllama: "Ollama (本地)", AIDriverHuggingFace: "HuggingFace", AIDriverQwen: "通义千问", AIDriverMoonshot: "Moonshot", AIDriverZhipu: "智谱", AIDriverHunyuan: "混元", AIDriverWenxin: "文心一言"}

const (
	AIExecutorInternal      = 1
	AIExecutorHTTPWhitelist = 2
	AIExecutorSQLReadonly   = 3
)

var AIExecutorTypes = []int{AIExecutorInternal, AIExecutorHTTPWhitelist, AIExecutorSQLReadonly}
var AIExecutorTypeLabels = map[int]string{AIExecutorInternal: "内置函数", AIExecutorHTTPWhitelist: "HTTP白名单", AIExecutorSQLReadonly: "只读SQL"}

func IsAIDriver(value string) bool {
	for _, item := range AIDrivers {
		if item == value { return true }
	}
	return false
}

func IsAIExecutorType(value int) bool {
	for _, item := range AIExecutorTypes {
		if item == value { return true }
	}
	return false
}
```

- [ ] **Step 3: Write failing dict tests**

Create `admin_back_go/internal/dict/ai_test.go`:

```go
package dict

import (
	"testing"
	"admin_back_go/internal/enum"
)

func TestAIOptionsUseEnumOrder(t *testing.T) {
	drivers := AIDriverOptions()
	if len(drivers) != len(enum.AIDrivers) || drivers[0].Value != enum.AIDriverOpenAI || drivers[0].Label != "OpenAI" {
		t.Fatalf("unexpected driver options: %#v", drivers)
	}
	executors := AIExecutorTypeOptions()
	if len(executors) != 3 || executors[0].Value != enum.AIExecutorInternal || executors[0].Label != "内置函数" {
		t.Fatalf("unexpected executor options: %#v", executors)
	}
}
```

Run:

```powershell
go test ./internal/dict -run TestAIOptionsUseEnumOrder
```

Expected: fail because `AIDriverOptions` and `AIExecutorTypeOptions` do not exist.

- [ ] **Step 4: Implement dict options**

Append to `admin_back_go/internal/dict/dict.go`:

```go
func AIDriverOptions() []Option[string] {
	options := make([]Option[string], 0, len(enum.AIDrivers))
	for _, value := range enum.AIDrivers {
		options = append(options, Option[string]{Label: enum.AIDriverLabels[value], Value: value})
	}
	return options
}

func AIExecutorTypeOptions() []Option[int] {
	options := make([]Option[int], 0, len(enum.AIExecutorTypes))
	for _, value := range enum.AIExecutorTypes {
		options = append(options, Option[int]{Label: enum.AIExecutorTypeLabels[value], Value: value})
	}
	return options
}
```

- [ ] **Step 5: Verify foundation**

Run:

```powershell
go test ./internal/enum ./internal/dict
```

Expected: pass.

---

## Task 2: Implement `aimodel` with secret masking

**Files:**
- Create: `admin_back_go/internal/module/aimodel/*`

- [ ] **Step 1: Write failing service tests**

Create `admin_back_go/internal/module/aimodel/service_test.go` with tests that prove:

```text
Init returns ai_driver_arr + common_status_arr.
Create trims fields, validates driver/status, rejects duplicate driver+name, encrypts api_key and stores only api_key_hint.
Update with blank api_key does not touch api_key_enc/api_key_hint.
List returns api_key_hint but JSON never contains api_key_enc or plaintext api_key.
Delete and ChangeStatus reject invalid IDs/status.
```

Use a fake repository like `paychannel/service_test.go` and `secretbox.New("vault-key")`.

Run:

```powershell
go test ./internal/module/aimodel
```

Expected: fail because module does not exist.

- [ ] **Step 2: Implement model/dto/request/handler/route/repository/service**

Required behavior:

```text
Table: ai_models.
List filters: name prefix, driver exact, status exact, is_del=2.
Order: id DESC.
Create unique: driver + name + is_del=2.
Soft delete: set is_del=1.
Status: status must be 1/2.
No response field may expose api_key_enc or api_key.
```

REST mapping:

```text
GET    /api/admin/v1/ai-models/page-init
GET    /api/admin/v1/ai-models
POST   /api/admin/v1/ai-models
PUT    /api/admin/v1/ai-models/:id
PATCH  /api/admin/v1/ai-models/:id/status
DELETE /api/admin/v1/ai-models/:id
```

- [ ] **Step 3: Verify aimodel**

Run:

```powershell
go test ./internal/module/aimodel
```

Expected: pass.

---

## Task 3: Implement `aitool` including binding options

**Files:**
- Create: `admin_back_go/internal/module/aitool/*`

- [ ] **Step 1: Write failing service tests**

Create `admin_back_go/internal/module/aitool/service_test.go` with tests that prove:

```text
Init returns ai_executor_type_arr + common_status_arr.
Create rejects bad code, duplicate code, invalid executor_type, invalid HTTP config without https URL, invalid SQL config not starting SELECT.
Create and Update accept schema_json/executor_config only as JSON objects.
Delete rejects active ai_assistant_tools references.
AgentOptions returns active tools only and never returns retired cine_generate_keyframe.
BindAgentTools diffs bindings in a transaction and validates agent_id/tool_ids.
```

Run:

```powershell
go test ./internal/module/aitool
```

Expected: fail because module does not exist.

- [ ] **Step 2: Implement module**

Required behavior:

```text
Table: ai_tools.
Binding table: ai_assistant_tools.
List filters: name prefix, status exact, executor_type exact, is_del=2.
Order: id DESC.
Code regex: ^[a-z][a-z0-9_]{0,59}$.
Delete: if active binding exists, return BadRequest; otherwise soft-delete and poison code with __del_<id> within length 60.
Agent options: all active tools with status=1/is_del=2 and code != cine_generate_keyframe.
Bind: replace active bindings for one agent using soft-delete for removed rows and restore/create for added rows.
```

REST mapping:

```text
GET    /api/admin/v1/ai-tools/page-init
GET    /api/admin/v1/ai-tools
POST   /api/admin/v1/ai-tools
PUT    /api/admin/v1/ai-tools/:id
PATCH  /api/admin/v1/ai-tools/:id/status
DELETE /api/admin/v1/ai-tools/:id
GET    /api/admin/v1/ai-tools/agent-options?agent_id=<id>
PUT    /api/admin/v1/ai-tools/agent-bindings/:agent_id
```

- [ ] **Step 3: Verify aitool**

Run:

```powershell
go test ./internal/module/aitool
```

Expected: pass.

---

## Task 4: Implement `aiprompt` scoped to current user

**Files:**
- Create: `admin_back_go/internal/module/aiprompt/*`

- [ ] **Step 1: Write failing service tests**

Create `admin_back_go/internal/module/aiprompt/service_test.go` with tests that prove:

```text
List scopes to current user and returns tags/variables as []string.
Detail rejects records owned by another user.
Create sets user_id from token user, is_favorite=2, use_count=0, sort=0.
Update only permits owner and serializes tags/variables.
Delete only permits owner.
ToggleFavorite flips 1 <-> 2.
Use increments use_count and returns content only.
ai_prompt old table is never referenced by repository/model names.
```

Run:

```powershell
go test ./internal/module/aiprompt
```

Expected: fail because module does not exist.

- [ ] **Step 2: Implement module**

Required behavior:

```text
Table: ai_prompts only.
List filters: title contains, category exact, is_favorite=1 only when requested, user_id from auth.
Order: is_favorite DESC, sort DESC, use_count DESC, id DESC.
Tags storage: JSON string in varchar; response always []string.
Variables storage: JSON; response always []string.
Delete: soft delete is_del=1.
Use: increment then return original content.
```

REST mapping:

```text
GET    /api/admin/v1/ai-prompts
GET    /api/admin/v1/ai-prompts/:id
POST   /api/admin/v1/ai-prompts
PUT    /api/admin/v1/ai-prompts/:id
DELETE /api/admin/v1/ai-prompts/:id
PATCH  /api/admin/v1/ai-prompts/:id/favorite
POST   /api/admin/v1/ai-prompts/:id/use
```

- [ ] **Step 3: Verify aiprompt**

Run:

```powershell
go test ./internal/module/aiprompt
```

Expected: pass.

---

## Task 5: Wire Go modules into router/bootstrap/RBAC/operation logs

**Files:**
- Modify: `admin_back_go/internal/server/router.go`
- Modify: `admin_back_go/internal/server/router_test.go`
- Modify: `admin_back_go/internal/bootstrap/app.go`
- Modify: `admin_back_go/internal/bootstrap/route_meta.go`
- Modify: `admin_back_go/internal/bootstrap/route_meta_test.go`

- [ ] **Step 1: Add router tests first**

Extend `router_test.go` with fake services and route tests for:

```text
GET /api/admin/v1/ai-models/page-init
GET /api/admin/v1/ai-tools/page-init
GET /api/admin/v1/ai-prompts
```

Run:

```powershell
go test ./internal/server -run 'AI|Router'
```

Expected: fail because deps/routes are missing.

- [ ] **Step 2: Wire dependencies and routes**

Modify `server.Dependencies` to include `AiModelService`, `AiToolService`, `AiPromptService`; register routes after existing admin module registrations. In `bootstrap.New`, instantiate repositories/services:

```go
aimodel.NewService(aimodel.NewGormRepository(resources.DB), secretBox)
aitool.NewService(aitool.NewGormRepository(resources.DB))
aiprompt.NewService(aiprompt.NewGormRepository(resources.DB))
```

- [ ] **Step 3: Add permission route metadata**

Use existing DB button codes where they exist:

```text
ai_prompt_add  -> POST /api/admin/v1/ai-prompts
ai_prompt_edit -> PUT /api/admin/v1/ai-prompts/:id and PATCH /favorite
ai_prompt_del  -> DELETE /api/admin/v1/ai-prompts/:id
```

Do not invent model/tool button codes until DB permission rows exist. Read routes remain protected by page permission through existing menu/bootstrap; mutating model/tool endpoints remain authenticated and operation-logged but not button-gated in P1 unless DB migration adds canonical codes.

- [ ] **Step 4: Add operation log rules for mutating endpoints**

Add explicit rules:

```text
ai_model create/update/change_status/delete
ai_tool create/update/change_status/delete/bind_agent_tools
ai_prompt create/update/delete/toggle_favorite/use
```

- [ ] **Step 5: Verify wiring**

Run:

```powershell
go test ./internal/server ./internal/bootstrap
```

Expected: pass.

---

## Task 6: Switch frontend API clients to Go REST

**Files:**
- Create: `admin_front_ts/tests/shared/ai/ai-model-api.test.ts`
- Create: `admin_front_ts/tests/shared/ai/ai-tool-api.test.ts`
- Create: `admin_front_ts/tests/shared/ai/ai-prompt-api.test.ts`
- Modify: `admin_front_ts/src/api/ai/models.ts`
- Modify: `admin_front_ts/src/api/ai/tools.ts`
- Modify: `admin_front_ts/src/api/ai/prompts.ts`

- [ ] **Step 1: Write failing frontend contract tests**

Each test must assert:

```text
imports request from '@/lib/http'
imports ADMIN_API_PREFIX
uses /ai-models, /ai-tools, /ai-prompts REST endpoints
contains no legacyRequest
contains no /api/admin/AiModels, /api/admin/AiTools, /api/admin/AiPrompts
uses positive integer IDs for path params
has no any/as any/Record<string, any>
```

Run:

```powershell
cd E:\admin_go\admin_front_ts
npx vitest run tests/shared/ai/ai-model-api.test.ts tests/shared/ai/ai-tool-api.test.ts tests/shared/ai/ai-prompt-api.test.ts
```

Expected: fail because clients still use legacyRequest.

- [ ] **Step 2: Rewrite `models.ts`**

Use `request` and `ADMIN_API_PREFIX`:

```text
init -> GET /ai-models/page-init
list -> GET /ai-models with query params
add -> POST /ai-models
edit -> PUT /ai-models/:id
status -> PATCH /ai-models/:id/status
single del -> DELETE /ai-models/:id
batch del -> Promise.all(ids.map(delete)) because Go REST is single-delete in P1
```

Keep the existing exported type names so pages do not need UI changes.

- [ ] **Step 3: Rewrite `tools.ts`**

Use REST:

```text
init/list/add/edit/status/del -> /ai-tools
getAgentTools -> GET /ai-tools/agent-options?agent_id=<id>
bindTools -> PUT /ai-tools/agent-bindings/:agent_id
```

Keep `AiAgentToolsResponse` shape `{ bound_tool_ids, all_tools }`.

- [ ] **Step 4: Rewrite `prompts.ts`**

Use REST:

```text
list -> GET /ai-prompts
detail -> GET /ai-prompts/:id
add -> POST /ai-prompts
edit -> PUT /ai-prompts/:id
del -> DELETE /ai-prompts/:id or Promise.all for array
toggleFavorite -> PATCH /ai-prompts/:id/favorite
use -> POST /ai-prompts/:id/use
```

- [ ] **Step 5: Verify frontend clients**

Run:

```powershell
npx vitest run tests/shared/ai/ai-model-api.test.ts tests/shared/ai/ai-tool-api.test.ts tests/shared/ai/ai-prompt-api.test.ts tests/shared/ai/agent-helpers.test.ts
npx vue-tsc -b --pretty false
```

Expected: pass.

---

## Task 7: Add smoke coverage and docs

**Files:**
- Modify: `admin_back_go/scripts/full-admin-smoke.ps1`
- Modify: `docs/contracts/admin-api-v1.md`
- Modify: `docs/migration/current-status.md`
- Modify: `docs/testing/smoke-matrix.md`
- Modify: `admin_back_go/docs/architecture.md`

- [ ] **Step 1: Add full smoke read probes**

In `full-admin-smoke.ps1`, after login and existing core reads, probe:

```text
GET /api/admin/v1/ai-models/page-init
GET /api/admin/v1/ai-models?current_page=1&page_size=10
GET /api/admin/v1/ai-tools/page-init
GET /api/admin/v1/ai-tools?current_page=1&page_size=10
GET /api/admin/v1/ai-prompts?current_page=1&page_size=10
GET /api/admin/v1/ai-prompts/:id when a prompt row exists
```

Assertions:

```text
ai model list JSON must not contain api_key_enc or api_key.
ai tool list must not include active code cine_generate_keyframe.
ai prompt list/detail tags and variables must be JSON arrays.
```

- [ ] **Step 2: Update API contract**

Document endpoints, request fields, response fields, and non-goals. Include explicit note: `ai_prompt` old table is not touched in P1.

- [ ] **Step 3: Update current status and smoke matrix**

`current-status.md` should say:

```text
AI P1 config migration implemented: models/tools/prompts use Go REST. agents/knowledge/chat/runs remain legacy-backed.
```

`smoke-matrix.md` should include one AI P1 row with read-only probes and secret-leak checks.

- [ ] **Step 4: Update backend architecture**

Record:

```text
Go owns AI config facts for models/tools/prompts. Go does not own AI runtime yet. ai_run_timeout remains legacy until P4.
```

---

## Task 8: Final verification and commits

**Files:** no source changes

- [ ] **Step 1: Backend full verification**

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

- [ ] **Step 2: Frontend full verification**

Run:

```powershell
cd E:\admin_go\admin_front_ts
$env:NODE_OPTIONS='--max-old-space-size=2048'
npx vitest run tests/shared/ai/ai-model-api.test.ts tests/shared/ai/ai-tool-api.test.ts tests/shared/ai/ai-prompt-api.test.ts tests/shared/ai/agent-helpers.test.ts tests/shared/http/ai-stream-contract.test.ts tests/shared/http/ai-stream-websocket-contract.test.ts
npx vue-tsc -b --pretty false
git diff --check
```

Expected: exit 0.

- [ ] **Step 3: Full smoke**

Run:

```powershell
cd E:\admin_go\admin_back_go
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account 15671628271 -Password 123456
```

Expected summary includes:

```text
ai_model_init_code=0
ai_model_list_code=0
ai_model_secret_leak=false
ai_tool_init_code=0
ai_tool_list_code=0
ai_tool_retired_cine_present=false
ai_prompt_list_code=0
ai_prompt_tags_arrays=true
ai_prompt_variables_arrays=true
ai_goods_route_present=false
ai_cine_route_present=false
```

- [ ] **Step 4: Residue sweep**

Run:

```powershell
rg -n "legacyRequest|/api/admin/AiModels|/api/admin/AiTools|/api/admin/AiPrompts|cine_generate_keyframe|/ai/goods|/ai/cine" E:\admin_go\admin_front_ts\src\api\ai E:\admin_go\admin_back_go\internal E:\admin_go\docs -g "!docs/superpowers/**" -g "!admin_back_go/database/migrations/**"
```

Expected: no P1 active legacy client hits; historical docs may mention as migration notes only outside active client code.

- [ ] **Step 5: Commit**

Use separated commits:

```powershell
git -C E:\admin_go\admin_back_go add internal enum? docs scripts as appropriate
git -C E:\admin_go\admin_back_go commit -m "feat: migrate AI config APIs to Go REST"

git -C E:\admin_go\admin_front_ts add -A src/api/ai tests/shared/ai
git -C E:\admin_go\admin_front_ts commit -m "feat: switch AI config clients to Go REST"

git -C E:\admin_go add docs/contracts/admin-api-v1.md docs/migration/current-status.md docs/testing/smoke-matrix.md docs/superpowers/plans/2026-05-08-ai-core-p1-config.md
git -C E:\admin_go commit -m "docs: record AI P1 config migration"
```

Expected: three clean worktrees after commit.

## Self-review

- Spec coverage: models/tools/prompts REST, secret masking, prompt canonical table, frontend switch, docs, smoke, and non-goals are covered.
- Open-marker scan: none remain; exact files and commands are named.
- Compatibility: goods/cine stays deleted; chat/runtime/agents/knowledge stay out of P1.
