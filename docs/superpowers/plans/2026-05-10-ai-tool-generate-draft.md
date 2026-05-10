# AI Tool Generate Draft Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** 在 AI 工具管理页增加“AI生成”按钮，让管理员用已配置的 `agent_generate` 场景智能体生成 AI 工具草稿，人工确认后复用现有新增工具接口入库。

**Architecture:** 第一版不新增业务表、不新增 `ai_tools` 字段、不直接写库。后端只生成严格对齐现有 `ai_tools` 表单的草稿；保存仍走 `POST /api/admin/v1/ai-tools`，继续由现有服务校验 code 唯一、JSON Schema 合法、启用时服务端 executor 已注册。权限新增 `ai_tool_generate`，生成路由挂同一权限。

**Tech Stack:** Go + Gin + GORM + existing `platform/ai` OpenAI-compatible engine, Vue 3 + TypeScript + Element Plus, MySQL permissions table.

---

## System Prompt for the `agent_generate` Agent

把下面整段复制到你创建好的“智能体生成”场景智能体的系统提示词里：

```text
你是 admin_go 的 AI 工具定义生成专家。你的唯一任务：根据管理员描述，生成一个可进入“AI工具管理”新增表单的工具草稿。

你必须遵守当前系统的真实工具契约：
- 工具只包含这些字段：name、code、description、parameters_json、result_schema_json、risk_level、timeout_ms、status。
- 不要输出 executor、tool_type、provider_id、agent_id、permission_code、config_json、runtime_config、created_by、updated_by 或任何未定义字段。
- code 是服务端工具唯一编码和 function name，必须使用 snake_case，只能包含小写字母、数字、下划线，长度 3 到 64，例如 admin_user_count。
- name 不超过 128 个字符。
- description 不超过 1024 个字符，必须清楚说明工具做什么、边界是什么、不会返回什么敏感信息。
- parameters_json 必须是 JSON Schema 对象，根节点必须是 {"type":"object"}，必须包含 properties，必须包含 additionalProperties:false。
- result_schema_json 必须是 JSON Schema 对象，根节点必须是 {"type":"object"}，必须包含 properties，必须包含 additionalProperties:false。
- required 只列真正必填的参数；如果没有入参，parameters_json 使用空 properties 和 additionalProperties:false。
- risk_level 只能是 low、medium、high：只读统计/查询为 low；可能读取敏感数据或影响较大为 medium；写操作、删除、资金、权限、外部副作用为 high。
- timeout_ms 必须在 100 到 30000 之间；普通只读查询默认 3000。
- status 默认 2，除非管理员明确说明这是已有服务端实现的工具编码。AI 不能假装服务端已经实现了某个工具。

你必须先判断描述是否足够清楚：
- 如果缺少工具用途、输入、输出、边界中的关键内容，返回 ok=false，并给出 clarifying_questions。
- 如果描述足够清楚，返回 ok=true 和 draft。

你必须只输出合法 JSON，不要输出 Markdown，不要输出解释文字，不要用代码块包裹。

输出格式固定如下：
{
  "ok": true,
  "draft": {
    "name": "工具名称",
    "code": "tool_code",
    "description": "工具说明",
    "parameters_json": {
      "type": "object",
      "properties": {},
      "required": [],
      "additionalProperties": false
    },
    "result_schema_json": {
      "type": "object",
      "properties": {},
      "required": [],
      "additionalProperties": false
    },
    "risk_level": "low",
    "timeout_ms": 3000,
    "status": 2
  },
  "warnings": [],
  "clarifying_questions": []
}

如果需求不清楚，输出：
{
  "ok": false,
  "draft": null,
  "warnings": ["需求不足，暂不生成工具草稿"],
  "clarifying_questions": ["请说明这个工具具体查询或执行什么？", "请说明入参和返回字段？"]
}
```

## Scope Decisions

- 不做：AI 直接写入 `ai_tools`。
- 不做：生成服务端 executor 代码。工具定义和服务端实现是两个不同问题，不能假装 code 一存在工具就能执行。
- 不做：新增 `ai_tools` 字段。当前字段足够承载草稿。
- 本 slice 不泛化 `ai_runs`。生成接口可把本次 token usage 返回给前端展示，但不持久化到运行监控。若后续要把管理类 AI 任务也纳入运行监控，单独做 `ai_runs.run_type` 泛化，不在这个小闭环里偷塞。

## File Map

### Backend

- Create: `admin_back_go/database/migrations/20260510_ai_tool_generate_permission.sql`
  - 新增 `ai_tool_generate` BUTTON 权限。
  - 默认授权给已有 `ai_tool_add` 的角色。

- Modify: `admin_back_go/internal/bootstrap/route_meta.go`
  - `POST /api/admin/v1/ai-tools/generate-draft -> ai_tool_generate`。
  - 增加 OperationLog metadata：module=`ai_tool`, action=`generate_draft`, title=`AI生成工具草稿`。

- Modify: `admin_back_go/internal/module/aitool/dto.go`
  - 增加 `GeneratePageInitResponse`、`GenerateDraftInput`、`GenerateDraftResponse`、`GeneratedToolDraft`。
  - 扩展 `HTTPService` 接口。

- Modify: `admin_back_go/internal/module/aitool/route.go`
  - 增加 `GET /api/admin/v1/ai-tools/generate/page-init`。
  - 增加 `POST /api/admin/v1/ai-tools/generate-draft`。

- Modify: `admin_back_go/internal/module/aitool/handler.go`
  - 绑定生成请求，读取当前 user id，调用 service。

- Modify: `admin_back_go/internal/module/aitool/repository.go`
  - 增加 `ListGenerateAgents(ctx)`。
  - 增加 `GetGenerateAgentConfig(ctx, agentID)`，必须校验 `agent_generate` 场景、agent/provider 启用、未删除。

- Modify: `admin_back_go/internal/module/aitool/service.go`
  - 增加 `GeneratePageInit` 和 `GenerateDraft`。
  - 增加 optional dependencies：`secretbox.Box`、`EngineFactory`。
  - 调用模型后只解析 JSON 草稿，不入库。
  - 用现有 schema/risk/status 规则校验草稿。
  - 如果 generated code 未注册 executor，强制 draft.status=2，并追加 warning。

- Modify: `admin_back_go/internal/bootstrap/app.go`
  - 给 `aitool.NewService` 注入 secretbox 和 tool-generate engine factory。

### Frontend

- Modify: `admin_front_ts/src/api/ai/tools.ts`
  - 增加 generate page-init 和 generate-draft 类型与 API。

- Modify: `admin_front_ts/src/views/Main/ai/tools/index.vue`
  - 管理 `ToolGenerateDialog` 状态。
  - 接收 generated draft 后打开现有 `ToolFormDialog` 新增模式。

- Modify: `admin_front_ts/src/views/Main/ai/tools/components/ToolList/index.vue`
  - toolbar 增加 `AI生成` 按钮。
  - 按 `userStore.can('ai_tool_generate')` 控制显隐。

- Modify: `admin_front_ts/src/views/Main/ai/tools/components/ToolFormDialog/index.vue`
  - 增加 `draft` prop；新增模式优先填入 draft。

- Create: `admin_front_ts/src/views/Main/ai/tools/components/ToolGenerateDialog/index.vue`
  - 选择生成智能体。
  - 输入工具描述和 code hint。
  - 展示 warnings / clarifying questions。
  - 生成成功后 emit draft。

- Modify: `admin_front_ts/src/i18n/locales/zh-CN.ts`
- Modify: `admin_front_ts/src/i18n/locales/en-US.ts`
  - 增加按钮、弹窗、提示文案。

### Tests / Docs

- Modify: `admin_back_go/internal/module/aitool/service_test.go`
- Modify: `admin_back_go/internal/server/router_test.go`
- Modify: `admin_front_ts/tests/shared/ai/ai-tools-api.test.ts`
- Modify: `docs/contracts/admin-api-v1.md`
- Modify: `docs/migration/current-status.md`
- Modify: `docs/testing/smoke-matrix.md`

---

## Task 1: Permission Migration and Route Metadata

**Files:**
- Create: `admin_back_go/database/migrations/20260510_ai_tool_generate_permission.sql`
- Modify: `admin_back_go/internal/bootstrap/route_meta.go`
- Test: `admin_back_go/internal/server/router_test.go`

- [x] **Step 1: Add failing router/permission expectation**

Add expectations in the AI tool router test that `POST /api/admin/v1/ai-tools/generate-draft` is installed and protected by `ai_tool_generate`.

- [x] **Step 2: Create idempotent permission migration**

Use `/ai/tools` page as parent, not hardcoded id:

```sql
SET @ai_tools_page_id := (
  SELECT id FROM permissions
  WHERE path = '/ai/tools' AND type = 2 AND platform = 'admin' AND is_del = 2
  LIMIT 1
);

INSERT INTO permissions (name, path, icon, parent_id, component, platform, type, sort, code, i18n_key, show_menu, status, is_del)
SELECT 'AI生成', '', '', @ai_tools_page_id, NULL, 'admin', 3, 5, 'ai_tool_generate', '', 2, 1, 2
WHERE @ai_tools_page_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM permissions WHERE code = 'ai_tool_generate' AND platform = 'admin' AND is_del = 2
  );

SET @ai_tool_generate_id := (
  SELECT id FROM permissions
  WHERE code = 'ai_tool_generate' AND platform = 'admin' AND is_del = 2
  LIMIT 1
);

INSERT INTO role_permissions (role_id, permission_id, is_del)
SELECT DISTINCT rp.role_id, @ai_tool_generate_id, 2
FROM role_permissions rp
JOIN permissions p ON p.id = rp.permission_id
WHERE @ai_tool_generate_id IS NOT NULL
  AND p.code = 'ai_tool_add'
  AND rp.is_del = 2
  AND NOT EXISTS (
    SELECT 1 FROM role_permissions existing
    WHERE existing.role_id = rp.role_id
      AND existing.permission_id = @ai_tool_generate_id
      AND existing.is_del = 2
  );
```

- [x] **Step 3: Add route metadata**

Add in `permissionRouteRules()`:

```go
middleware.NewRouteKey(http.MethodPost, "/api/admin/v1/ai-tools/generate-draft"): "ai_tool_generate",
```

Add in `operationLogRouteRules()`:

```go
middleware.NewRouteKey(http.MethodPost, "/api/admin/v1/ai-tools/generate-draft"): {Module: "ai_tool", Action: "generate_draft", Title: "AI生成工具草稿"},
```

- [x] **Step 4: Verify backend route tests**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/server -count=1
```

Expected: PASS.

---

## Task 2: Backend Generate Draft Contract

**Files:**
- Modify: `admin_back_go/internal/module/aitool/dto.go`
- Modify: `admin_back_go/internal/module/aitool/handler.go`
- Modify: `admin_back_go/internal/module/aitool/route.go`
- Modify: `admin_back_go/internal/module/aitool/repository.go`
- Modify: `admin_back_go/internal/module/aitool/service.go`
- Modify: `admin_back_go/internal/bootstrap/app.go`
- Test: `admin_back_go/internal/module/aitool/service_test.go`

- [x] **Step 1: Write failing service tests**

Cover these cases:

```text
GenerateDraft rejects missing agent_generate agent
GenerateDraft rejects blank requirement
GenerateDraft parses strict JSON draft
GenerateDraft returns clarifying_questions when ok=false
GenerateDraft forces status=2 when generated code has no executor
GenerateDraft can return status=1 only when generated code is registered
```

- [x] **Step 2: Add DTOs**

Add request/response types matching frontend needs:

```go
type GenerateDraftInput struct {
    AgentID     uint64
    UserID      uint64
    Requirement string
    CodeHint    string
}

type GeneratedToolDraft struct {
    Name             string          `json:"name"`
    Code             string          `json:"code"`
    Description      string          `json:"description"`
    ParametersJSON   json.RawMessage `json:"parameters_json"`
    ResultSchemaJSON json.RawMessage `json:"result_schema_json"`
    RiskLevel        string          `json:"risk_level"`
    TimeoutMS        uint            `json:"timeout_ms"`
    Status           int             `json:"status"`
}

type GenerateDraftResponse struct {
    OK                  bool                `json:"ok"`
    Draft               *GeneratedToolDraft `json:"draft"`
    Warnings            []string            `json:"warnings"`
    ClarifyingQuestions []string            `json:"clarifying_questions"`
    Usage               *GenerateUsage      `json:"usage,omitempty"`
}
```

- [x] **Step 3: Add repository queries**

`GetGenerateAgentConfig` must join `ai_agents` and `ai_providers`, and require:

```sql
a.status = 1
p.status = 1
a.is_del = 2
p.is_del = 2
JSON_CONTAINS(a.scenes_json, JSON_QUOTE('agent_generate'))
```

- [x] **Step 4: Add service generation logic**

Use existing OpenAI-compatible engine through a tiny `EngineFactory` interface. Build `platformai.ChatInput`:

```go
platformai.ChatInput{
    AgentID: agent.ID,
    UserID: input.UserID,
    Content: buildToolGenerateUserPrompt(input.Requirement, input.CodeHint),
    Inputs: map[string]any{
        "model_id": agent.ModelID,
        "system_prompt": agent.SystemPrompt,
    },
}
```

Use a discard event sink because this API returns one final JSON object, not streaming UI deltas.

- [x] **Step 5: Validate generated draft before returning**

Use the same field rules as normal tool create. Important difference: do not require executor to exist for draft. Instead:

```text
if !executorRegistered(draft.code): draft.status = 2; warnings append "该工具编码暂未注册服务端实现，已默认禁用"
```

- [x] **Step 6: Verify backend module tests**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/aitool ./internal/server ./internal/bootstrap -count=1
go vet -p=1 ./...
```

Expected: PASS.

---

## Task 3: Frontend Generate Dialog and Draft Handoff

**Files:**
- Modify: `admin_front_ts/src/api/ai/tools.ts`
- Modify: `admin_front_ts/src/views/Main/ai/tools/index.vue`
- Modify: `admin_front_ts/src/views/Main/ai/tools/components/ToolList/index.vue`
- Modify: `admin_front_ts/src/views/Main/ai/tools/components/ToolFormDialog/index.vue`
- Create: `admin_front_ts/src/views/Main/ai/tools/components/ToolGenerateDialog/index.vue`
- Modify: `admin_front_ts/src/i18n/locales/zh-CN.ts`
- Modify: `admin_front_ts/src/i18n/locales/en-US.ts`
- Test: `admin_front_ts/tests/shared/ai/ai-tools-api.test.ts`

- [x] **Step 1: Add frontend API types and tests**

Extend `AiToolApi`:

```ts
generateInit: () => request.get<AiToolGenerateInitResponse>(`${ADMIN_API_PREFIX}/ai-tools/generate/page-init`),
generateDraft: (params: AiToolGenerateDraftParams) => request.post<AiToolGenerateDraftResponse, AiToolGenerateDraftBody>(`${ADMIN_API_PREFIX}/ai-tools/generate-draft`, generateDraftBody(params)),
```

- [x] **Step 2: Add AI生成 toolbar button**

In `ToolList`, import user store and gate:

```vue
<el-button v-if="userStore.can('ai_tool_generate')" type="primary" @click="emit('generate')">
  {{ t('aiTools.actions.generate') }}
</el-button>
```

- [x] **Step 3: Add ToolGenerateDialog**

Fields:

```text
agent_id: select-v2, required
requirement: textarea, required, min clear description
code_hint: input, optional
```

Behavior:

```text
ok=false -> show clarifying_questions and keep dialog open
ok=true -> emit generated draft, close dialog
warnings -> show warning block
```

- [x] **Step 4: Let ToolFormDialog accept generated draft**

Add prop:

```ts
draft: AiToolMutationParams | null
```

In add mode, `resetForm()` uses draft if present, otherwise `defaultForm()`.

- [x] **Step 5: Verify frontend tests and typecheck**

Run:

```powershell
cd E:\admin_go\admin_front_ts
.\node_modules\.bin\vitest.cmd run tests/shared/ai/ai-tools-api.test.ts --maxWorkers=1
npx vue-tsc -b --pretty false
npm run build:check
```

Expected: PASS.

---

## Task 4: Docs, Smoke, and DB Verification

**Files:**
- Modify: `docs/contracts/admin-api-v1.md`
- Modify: `docs/migration/current-status.md`
- Modify: `docs/testing/smoke-matrix.md`
- Modify: `admin_back_go/scripts/full-admin-smoke.ps1`

- [x] **Step 1: Contract docs**

Document:

```text
GET  /api/admin/v1/ai-tools/generate/page-init -> ai_tool_generate
POST /api/admin/v1/ai-tools/generate-draft -> ai_tool_generate
```

Rules:

```text
generate-draft returns draft only; it never inserts ai_tools
save still uses POST /api/admin/v1/ai-tools
unregistered generated code defaults to disabled
```

- [x] **Step 2: Smoke check permission exists**

Extend full smoke AI tool read gate:

```text
users/init buttonCodes includes ai_tool_generate when role has ai_tool_add
ai-tools generate page-init returns agent options array
```

Do not run live generate-draft in default smoke because it requires real provider credentials.

- [x] **Step 3: Verify migration in live DB after user approves execution**

Run after applying migration:

```sql
SELECT id,parent_id,name,code,type,status,is_del,sort
FROM permissions
WHERE code='ai_tool_generate';
```

Expected: one enabled BUTTON row under `/ai/tools`.

---

## Final Verification Commands

Backend:

```powershell
cd E:\admin_go\admin_back_go
gofmt -w internal\module\aitool internal\bootstrap internal\server
go test ./internal/module/aitool ./internal/module/aichat ./internal/module/airun ./internal/server ./internal/bootstrap -count=1
go vet -p=1 ./...
powershell -NoProfile -Command '$null = [scriptblock]::Create((Get-Content -Raw .\scripts\full-admin-smoke.ps1)); "syntax ok"'
```

Frontend:

```powershell
cd E:\admin_go\admin_front_ts
.\node_modules\.bin\vitest.cmd run tests/shared/ai/ai-tools-api.test.ts tests/shared/ai/ai-agent-api.test.ts tests/shared/ai/ai-run-api.test.ts --maxWorkers=1
npx vue-tsc -b --pretty false
npm run build:check
```

Diff hygiene:

```powershell
cd E:\admin_go
git diff --check
git -C admin_back_go diff --check
git -C admin_front_ts diff --check
```

## Self-Review

- Spec coverage: permission, frontend button, generate dialog, backend draft generation, human-confirmed save, docs, smoke are covered.
- No extra DB table or `ai_tools` field is introduced.
- Existing tool runtime rule remains intact: enabled tool code must map to a registered Go executor.
- Persistent run monitor for admin generation tasks is intentionally excluded from this slice; do it later only if we decide to generalize `ai_runs` beyond chat.
