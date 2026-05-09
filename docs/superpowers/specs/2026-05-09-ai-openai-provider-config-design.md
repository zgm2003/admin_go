# AI OpenAI 供应商配置设计

状态：Implemented in working tree; final verification pending
日期：2026-05-09
范围：只做 AI 菜单的第 1 个页面：供应商配置。OpenAI only。

## Linus 三问

1. 这是个真问题吗？
   - 是。当前 AI 供应商配置仍带 Dify / Eino / Direct / RAGFlow 旧概念，不能支撑用户自己配置 OpenAI 供应商并选择可用模型。
2. 有更简单的方法吗？
   - 有。第一版只支持 `openai` driver，不引入 Eino / LangChainGo / OpenAI SDK，直接用 `net/http` 调 OpenAI 官方 `/models`。
3. 会破坏什么吗？
   - 不能破坏现有 AI 菜单、RBAC、OperationLog、前端路由和后续智能体/对话编译。物理表 `ai_engine_connections` 先作为兼容锚点保留，本轮把它的产品语义收口成“供应商配置”；真正全量重命名等 6 个 AI 菜单落地后统一清理。

## 用户已经拍板的决策

- AI 菜单顺序固定：供应商配置、智能体配置、知识库、工具管理、运行监控、AI对话。
- 先只做“供应商配置”。这个没有完全落地之前，不做智能体/知识库/工具/运行监控/AI对话。
- 第一版只支持 OpenAI：`driver = openai`。
- 模型选择语义：拉取模型后，本地支持启用/禁用、自定义显示名、默认模型；后续智能体只能选已启用模型。
- Key 策略：UI 先只配一个 API Key，但表结构不阻塞未来拆 `ai_provider_credentials` 做 key 池。
- 模型单独拆表：`ai_provider_models`。
- `base_url` 允许为空；为空时运行时使用 OpenAI 官方默认 `https://api.openai.com/v1`。
- 每张新表必须有 `is_del`、`created_at`、`updated_at`。

## 目标

做成一个真正可用的 OpenAI 供应商配置页面：

- 管理员能新增 / 编辑 / 删除 / 启停 OpenAI 供应商。
- 管理员输入 API Key 后可以拉取 OpenAI 模型列表。
- 管理员必须选择至少一个模型作为本系统可用模型。
- 管理员可以设置默认模型、模型显示名、模型启用状态。
- 列表展示健康状态、最近检测时间、模型同步状态。
- 后端不向前端泄露明文 API Key 或加密密文。
- 不引入 Dify / Workflow / Eino / LangChainGo 概念。

## 非目标

本轮不做：Gemini、阿里百炼、Anthropic、Azure OpenAI、CLIProxyAPI、多 Key 池、智能体配置、知识库、工具调用、AI 对话 runtime 切换、依赖清理。

## OpenAI 外部合同

使用 OpenAI 官方 REST 合同：

- 默认 base URL：`https://api.openai.com/v1`。
- 模型列表：`GET /models`。官方 OpenAPI 描述为列出当前可用模型，并返回基本信息如 owner / availability。
- 鉴权：`Authorization: Bearer <api_key>`。
- 后续对话可继续使用 `/chat/completions`，但本轮只实现供应商配置和模型发现。

参考：

- https://platform.openai.com/docs/api-reference/models/list
- https://platform.openai.com/docs/api-reference/chat/create

## 表结构设计

### 兼容原则

当前代码已有 `ai_engine_connections`，多个 AI 模块仍依赖 `engine_connection_id`。为避免第一步就牵连所有菜单，本轮不改物理主表名，不做大重命名。

本轮约定：

- `ai_engine_connections` 的产品语义就是“供应商配置”。
- `engine_type` 在本轮等价于 `driver`，第一版只允许值 `openai`。
- 前端展示统一叫“驱动”，不展示“引擎”。
- 后续 6 个菜单全部落地后，再统一清理物理表名 / 字段名 / 包名。

### `ai_engine_connections` 调整

现有表保留，做以下语义和字段调整：

```sql
ALTER TABLE ai_engine_connections
  MODIFY engine_type VARCHAR(32) NOT NULL,
  MODIFY base_url VARCHAR(512) NOT NULL DEFAULT '',
  ADD COLUMN last_check_error VARCHAR(1024) NOT NULL DEFAULT '' AFTER last_checked_at,
  ADD COLUMN last_model_sync_at DATETIME NULL AFTER last_check_error,
  ADD COLUMN last_model_sync_status VARCHAR(32) NOT NULL DEFAULT 'unknown' AFTER last_model_sync_at,
  ADD COLUMN last_model_sync_error VARCHAR(1024) NOT NULL DEFAULT '' AFTER last_model_sync_status;
```

字段语义：

- `name`：供应商名称，必填。
- `engine_type`：驱动，第一版只允许 `openai`。
- `base_url`：可空字符串；空字符串表示 OpenAI 官方默认地址。
- `api_key_enc`：加密后的 API Key，永不返回前端。
- `api_key_hint`：脱敏提示。
- `config_json`：保留扩展字段，不塞核心模型选择。
- `health_status`：`unknown` / `ok` / `failed`。
- `last_checked_at`：最近测试连接时间。
- `last_check_error`：最近测试连接失败原因，必须截断到 1024 字符。
- `last_model_sync_at`：最近模型同步时间。
- `last_model_sync_status`：`unknown` / `ok` / `failed`。
- `last_model_sync_error`：最近模型同步失败原因，必须截断到 1024 字符。
- `status`：1 启用，2 禁用。
- `is_del`：1 删除，2 正常，沿用当前项目 common yes/no 语义。
- `created_at` / `updated_at`：必备时间字段。

唯一约束继续按驱动 + 名称 + 删除态：

```sql
UNIQUE KEY uk_ai_engine_connections_type_name (engine_type, name, is_del)
```

### `ai_provider_models` 新表

模型不能塞 JSON。模型是后续智能体选择、默认模型、启停控制的真实数据源。

```sql
CREATE TABLE ai_provider_models (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  provider_id BIGINT UNSIGNED NOT NULL,
  model_id VARCHAR(191) NOT NULL,
  display_name VARCHAR(191) NOT NULL DEFAULT '',
  is_default TINYINT UNSIGNED NOT NULL DEFAULT 2,
  source VARCHAR(32) NOT NULL DEFAULT 'remote',
  raw_json JSON NULL,
  status TINYINT UNSIGNED NOT NULL DEFAULT 1,
  is_del TINYINT UNSIGNED NOT NULL DEFAULT 2,
  created_by BIGINT UNSIGNED NOT NULL DEFAULT 0,
  updated_by BIGINT UNSIGNED NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_ai_provider_models_provider_model (provider_id, model_id, is_del),
  KEY idx_ai_provider_models_provider_status (provider_id, status, is_del),
  KEY idx_ai_provider_models_provider_default (provider_id, is_default, is_del)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI provider enabled model catalog';
```

字段语义：

- `provider_id`：逻辑上是供应商 ID，对应 `ai_engine_connections.id`。
- `model_id`：OpenAI 返回的模型标识。
- `display_name`：用户自定义显示名；为空时前端显示 `model_id`。
- `is_default`：1 是默认，2 不是默认。每个 provider 只能有一个默认模型，由 service 事务保证。
- `source`：第一版固定 `remote`。
- `raw_json`：保存 OpenAI `/models` 返回的单个模型原始 JSON，用于后续排障，不参与业务判断。
- `status`：1 启用，2 禁用。后续智能体只能选启用模型。
- `is_del` / `created_at` / `updated_at`：每张表必备。

## 后端设计

### Driver 边界

新增轻量 provider driver，不引入重 SDK：

```go
type Driver interface {
    Name() string
    DefaultBaseURL() string
    ListModels(ctx context.Context, cfg Config) ([]Model, error)
    TestConnection(ctx context.Context, cfg Config) (*TestResult, error)
}
```

第一版只注册 `openai`。OpenAI driver 使用标准库 `net/http`、`context.Context`、`encoding/json`，不要新增 OpenAI SDK 依赖。

### OpenAI driver 行为

`base_url` 解析：

- 空字符串：使用 `https://api.openai.com/v1`。
- 非空：trim space + trim trailing slash。
- 非 http/https：返回配置错误。

`ListModels`：

- 请求：`GET {baseURL}/models`
- Header：`Authorization: Bearer <api_key>`
- 解析：`data[].id`, `data[].object`, `data[].created`, `data[].owned_by`
- 返回按 `id` 升序排序，方便 UI 稳定。

`TestConnection`：

- 复用 `ListModels`。
- 成功：`ok=true`，message 包含模型数量。
- 失败：`ok=false`，错误信息截断，不包含 API Key。

### API 合同

本轮建议保留现有路由前缀，降低迁移风险：

```text
GET    /api/admin/v1/ai-engine-connections/page-init
GET    /api/admin/v1/ai-engine-connections
POST   /api/admin/v1/ai-engine-connections/model-options
POST   /api/admin/v1/ai-engine-connections
PUT    /api/admin/v1/ai-engine-connections/:id
PATCH  /api/admin/v1/ai-engine-connections/:id/status
POST   /api/admin/v1/ai-engine-connections/:id/test
POST   /api/admin/v1/ai-engine-connections/:id/sync-models
GET    /api/admin/v1/ai-engine-connections/:id/models
PUT    /api/admin/v1/ai-engine-connections/:id/models
DELETE /api/admin/v1/ai-engine-connections/:id
```

前端产品文案统一叫“供应商配置”。路由名以后统一清理为 `/ai-providers`，但不在本轮做大范围 URL 破坏。

### 请求/响应核心字段

列表项返回：

```json
{
  "id": 1,
  "name": "OpenAI 主账号",
  "driver": "openai",
  "driver_name": "OpenAI",
  "base_url": "",
  "base_url_effective": "https://api.openai.com/v1",
  "api_key_masked": "sk-***abcd",
  "health_status": "ok",
  "last_checked_at": "2026-05-09 10:00:00",
  "last_check_error": "",
  "last_model_sync_at": "2026-05-09 10:00:00",
  "last_model_sync_status": "ok",
  "last_model_sync_error": "",
  "enabled_model_count": 3,
  "default_model_id": "gpt-4.1-mini",
  "status": 1,
  "status_name": "启用",
  "created_at": "2026-05-09 10:00:00",
  "updated_at": "2026-05-09 10:00:00"
}
```

创建请求：

```json
{
  "name": "OpenAI 主账号",
  "driver": "openai",
  "base_url": "",
  "api_key": "sk-...",
  "model_ids": ["gpt-4.1-mini", "gpt-4.1"],
  "default_model_id": "gpt-4.1-mini",
  "model_display_names": {
    "gpt-4.1-mini": "默认轻量模型"
  },
  "status": 1
}
```

编辑请求：

- `api_key` 为空或缺失：保留原 API Key。
- `api_key` 非空：重新加密保存并重新计算 `api_key_hint`。
- `model_ids` 必须至少一个。
- `default_model_id` 必须在 `model_ids` 内。

预览模型请求，不持久化 API Key：

```json
{
  "driver": "openai",
  "base_url": "",
  "api_key": "sk-..."
}
```

响应：

```json
{
  "list": [
    {
      "model_id": "gpt-4.1-mini",
      "display_name": "gpt-4.1-mini",
      "owned_by": "openai",
      "raw": { "id": "gpt-4.1-mini" }
    }
  ]
}
```

## 前端设计

### 页面位置

菜单：`/ai/providers`，名称“供应商配置”。

### 表单字段

用户口径固定为：

- 供应商名称：input，必填。
- 驱动：select-v2，必填，第一版只有 OpenAI。
- 模型标识：select-v2，多选，必填。
- baseurl：input，可选，不填走 OpenAI 官方默认。
- API key：input password，新增必填，编辑时为空表示不修改。
- 状态：select-v2，默认启用。

### 组件边界

当前 `src/views/Main/ai/providers/index.vue` 太容易继续膨胀。本轮按 Vue 规则拆小：

```text
src/views/Main/ai/providers/index.vue
  只负责页面装配、列表刷新、打开弹窗。

src/views/Main/ai/providers/components/ProviderFormDialog.vue
  负责新增/编辑表单、临时拉取模型、模型多选、默认模型选择。

src/views/Main/ai/providers/components/ProviderModelList.vue
  负责展示已启用模型、默认模型 tag、显示名。

src/views/Main/ai/providers/composables/useProviderForm.ts
  负责表单默认值、校验规则、模型预览状态。
```

Vue 约束：Vue 3 + `<script setup lang="ts">`；props down / emits up；route view 只做组合；基础 state 用 `shallowRef` / `reactive`，派生数据用 `computed`；不用 `v-html`。

## 错误处理和安全

- API Key 明文只出现在创建/编辑/模型预览请求体里，后端不落日志、不返回。
- OperationLog 必须脱敏 `api_key`。
- OpenAI 失败响应保存到 `last_check_error` / `last_model_sync_error` 前必须截断，且不能包含 API Key。
- 创建供应商时没有 API Key 直接拒绝。
- 创建/编辑时没有模型直接拒绝。
- 默认模型不在选中模型里直接拒绝。
- 禁用供应商时不删除模型，只影响后续智能体选择和调用。

## 测试设计

后端：

- OpenAI driver `httptest.Server`：base_url 默认、`/models` 成功解析、非 2xx 失败不泄露 API Key、空 API Key 返回配置错误。
- 供应商 service：`page-init` 只有 `openai`；创建要求 API Key；创建要求至少一个模型；默认模型必须属于选中模型；创建后写入 `ai_provider_models`；DTO 不包含 `api_key_enc` / 明文 `api_key`。
- Router / route meta：新增 `model-options`、`sync-models`、models 读写路由；mutation 路由有 RBAC code 和 OperationLog metadata。

前端：

- API 静态契约测试：driver union 只包含 `openai`；health status 为 `unknown | ok | failed`；mutation body 包含 `model_ids` / `default_model_id`；不再出现 `dify` / `eino` / `direct` / `ragflow`。
- Vue 类型检查：`npm run build:check`。

Smoke：

- full smoke read-only 检查：page-init driver 只返回 openai；list 不泄露密钥；menu 顺序符合 6 个固定项。

## 落地完成标准

供应商配置菜单完全落地必须同时满足：

- DB migration 有表和字段。
- 后端接口可用，测试通过。
- 前端页面可新增/编辑 OpenAI 供应商并选择模型。
- API Key 不泄露。
- 菜单顺序正确。
- 文档 / smoke matrix 同步。
- `go test ./...` 通过。
- 前端 targeted Vitest + `npm run build:check` 通过。
