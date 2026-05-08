# AI Core P1 Config Migration Design

状态：P1 design handoff after AI goods/cine prune。
日期：2026-05-08

本文只定义 AI core 的第一段 Go 迁移：`ai_models`、`ai_tools`、`ai_prompts` 三个配置/字典型能力。它不是聊天运行时，不做 RAG，不做 agent 执行，不做 WebSocket streaming。

## Linus 三问

1. 真问题：是。模型、工具、提示词是 AI 运行时的配置事实源。如果这三块还挂在 legacy PHP 上，后面的 agent、chat、run 迁移都会继续猜字段。
2. 更简单做法：先迁读写配置，不碰执行链路。用现有 DB 表和前端页面契约，做最小 Go REST，拒绝 `/api/admin/AiModels/*` 这种 PHP 风格续命。
3. 会破坏什么：不能破坏现有 AI core 页面入口，不能重新引入 `/ai/goods` 或 `/ai/cine`，不能暴露模型 `api_key_enc` 明文，不能删除 `ai_prompt` 旧表数据。

## 当前运行事实

### 已完成前置

```text
Phase 0 prune 已完成：goods、cine_projects、cine_assets 表已删除；/ai/goods 和 /ai/cine 菜单权限已删除；frontend goods/cine 页面/API 已删除。
```

### P1 当前 legacy 前端入口

```text
admin_front_ts/src/api/ai/models.ts  -> legacyRequest /api/admin/AiModels/init|list|add|edit|del|status
admin_front_ts/src/api/ai/tools.ts   -> legacyRequest /api/admin/AiTools/init|list|add|edit|del|status|bindTools|getAgentTools
admin_front_ts/src/api/ai/prompts.ts -> legacyRequest /api/admin/AiPrompts/list|detail|add|edit|del|toggleFavorite|use
```

P1 只切换这些 API client 到 Go REST。页面 UI 不重做。

### P1 DB 事实

```text
ai_models  total=15 active=8
ai_tools   total=8  active=1
ai_prompts total=11 active=6
ai_prompt  total=5  active=5  # old compatibility table, P1 不删除
```

`ai_prompts` 与 `ai_prompt` 字段高度相似，但 `ai_prompt` 仍有 5 行 active 数据。P1 先以 `ai_prompts` 为 canonical，因为当前 legacy `AiPrompts` API 与前端类型都对齐 `ai_prompts` 形态；是否合并/删除 `ai_prompt` 必须先做数据 diff，不夹在 P1 实现里偷删。

## P1 范围

### 必须做

```text
Go modules:
- internal/module/aimodel
- internal/module/aitool
- internal/module/aiprompt

REST endpoints:
- GET    /api/admin/v1/ai-models/page-init
- GET    /api/admin/v1/ai-models
- POST   /api/admin/v1/ai-models
- PUT    /api/admin/v1/ai-models/:id
- PATCH  /api/admin/v1/ai-models/:id/status
- DELETE /api/admin/v1/ai-models/:id

- GET    /api/admin/v1/ai-tools/page-init
- GET    /api/admin/v1/ai-tools
- POST   /api/admin/v1/ai-tools
- PUT    /api/admin/v1/ai-tools/:id
- PATCH  /api/admin/v1/ai-tools/:id/status
- DELETE /api/admin/v1/ai-tools/:id
- GET    /api/admin/v1/ai-tools/agent-options?agent_id=<id>
- PUT    /api/admin/v1/ai-tools/agent-bindings/:agent_id

- GET    /api/admin/v1/ai-prompts
- GET    /api/admin/v1/ai-prompts/:id
- POST   /api/admin/v1/ai-prompts
- PUT    /api/admin/v1/ai-prompts/:id
- DELETE /api/admin/v1/ai-prompts/:id
- PATCH  /api/admin/v1/ai-prompts/:id/favorite
- POST   /api/admin/v1/ai-prompts/:id/use

Frontend:
- src/api/ai/models.ts use request + Go REST
- src/api/ai/tools.ts use request + Go REST
- src/api/ai/prompts.ts use request + Go REST

Docs/tests:
- docs/contracts/admin-api-v1.md documents endpoint list, request/response fields, secret masking
- docs/migration/current-status.md marks only P1 config implemented after verification
- docs/testing/smoke-matrix.md adds read-only list/page-init/detail probes
- frontend contract Vitest for three clients
- backend tests for service validation, secret masking, canonical prompt behavior
```

### 必须保留

```text
AI core routes: /ai/models, /ai/agents, /ai/knowledge, /ai/chat, /ai/runs, /ai/prompts, /ai/tools
AI core history: ai_conversations, ai_messages, ai_runs, ai_run_steps
ai_prompt old table data until explicit diff/merge/drop decision
ai_run_timeout legacy cron fact until P4 worker migration
```

### 明确不做

```text
不做 chat runtime，不调用模型，不发 WebSocket streaming。
不做 agent execution，不绑定 knowledge runtime，不跑 RAG。
不创建 /api/admin/Goods、/api/admin/Cine 或任何 goods/cine adapter。
不删除 ai_prompt。
不把 API key 明文返回给前端。
不让前端继续用 legacyRequest 调 P1 三块。
```

## 数据与安全规则

### ai_models

```text
api_key_enc 是密文事实，Go 写入必须使用现有 secretbox/VAULT_KEY 体系。
响应只返回 api_key_hint，不返回 api_key_enc，也不返回明文 api_key。
编辑时 api_key 为空表示不改密钥；非空才重新加密并刷新 hint。
driver/model_code/name/status 必须服务端校验，不能靠前端 select。
```

### ai_tools

```text
schema_json 和 executor_config 必须是 JSON object，不接受数组、字符串或无结构垃圾。
executor_type 用 enum/dict 暴露给前端，后端做数值校验。
删除 tool 前必须检查 active ai_assistant_tools 绑定；有绑定时禁止硬删，或明确软删并同步绑定状态。P1 推荐禁止删除绑定中的 tool。
retired code=cine_generate_keyframe 不能作为 active option 返回。
```

### ai_prompts

```text
canonical table: ai_prompts。
tags 旧库是 varchar，前端类型是 string[]；Go API 必须稳定返回 string[]，写入时规范化成可逆格式。
variables 是 JSON，必须稳定返回 string[]。
use 接口只递增 use_count 并返回 content，不触发模型调用。
toggle favorite 只切 is_favorite 1/2，不做用户级收藏表扩展。
```

## RBAC 和菜单边界

P1 复用现有菜单页面：

```text
/ai/models
/ai/tools
/ai/prompts
```

按钮权限优先复用当前 DB 里已有 code；如果 code 命名不稳定，先写 migration canonicalize，再改前端 permission check。禁止在前端硬编码新权限后等后端追。

## 验证门禁

P1 不能靠“页面能打开”收工。必须同时过：

```powershell
cd E:\admin_go\admin_back_go
$env:GOMAXPROCS='2'
go test -p=1 ./internal/module/aimodel ./internal/module/aitool ./internal/module/aiprompt ./internal/server ./internal/bootstrap
go vet -p=1 ./internal/module/aimodel ./internal/module/aitool ./internal/module/aiprompt
powershell -ExecutionPolicy Bypass -File .\scripts\check-contract.ps1

cd E:\admin_go\admin_front_ts
$env:NODE_OPTIONS='--max-old-space-size=2048'
npx vitest run tests/shared/ai/ai-model-api.test.ts tests/shared/ai/ai-tool-api.test.ts tests/shared/ai/ai-prompt-api.test.ts
npx vue-tsc -b --pretty false

cd E:\admin_go\admin_back_go
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account 15671628271 -Password 123456
```

Smoke 至少要证明：

```text
GET /api/admin/v1/ai-models/page-init/list works and never returns api_key_enc/api_key
GET /api/admin/v1/ai-tools/page-init/list works and retired cine tool is absent from active options
GET /api/admin/v1/ai-prompts/list/detail works and returns tags/variables as arrays
users/init still has /ai/models, /ai/tools, /ai/prompts
users/init still does not have /ai/goods or /ai/cine
```

## P1 输出口径

完成后只能说：

```text
AI P1 config migration implemented: models/tools/prompts use Go REST.
```

不能说：

```text
AI core migrated
AI chat migrated
AI streaming migrated
AI agents migrated
AI runtime migrated
```
