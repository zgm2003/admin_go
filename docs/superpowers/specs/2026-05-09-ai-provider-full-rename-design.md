# AI Provider Full Rename Design

状态日期：2026-05-09

## 目标

把第一版 AI 供应商配置从旧的 engine connection 命名彻底收口为 provider 命名，避免新项目继续携带 Dify/sidecar/engine 时代的误导性概念。

## Linus 三问

1. 这是真问题吗？是。当前产品菜单叫“供应商配置”，但主表、Go 模块、REST 路径、前端 API 仍叫 engine connections，后续智能体/知识库/运行监控会继续被错误命名污染。
2. 有更简单的方法吗？只改文案不改表名最省事，但会留下 `ai_engine_connections` / `engine_connection_id` / `ai-engine-connections` 三套坏味道。这个项目还在迁移期，应该趁现在做干净。
3. 会破坏什么？会破坏 DB 表名、外键字段名、Go import/package、REST endpoint、前端 API、smoke、契约文档和本地实库。必须一次性改完并跑验证，不做半截兼容。

## 范围

本次做全量 provider rename：

- `ai_engine_connections` -> `ai_providers`
- `engine_connection_id` -> `provider_id`
- Go module `internal/module/aiengine` -> `internal/module/aiprovider`
- Go package `aiengine` -> `aiprovider`
- REST `/api/admin/v1/ai-engine-connections` -> `/api/admin/v1/ai-providers`
- Frontend API `src/api/ai/engineConnections.ts` -> `src/api/ai/providers.ts`
- Frontend names `AiEngineConnection*` -> `AiProvider*`
- Permission/operation metadata prefix `ai_engine_*` -> `ai_provider_*`
- Docs/smoke/tests update to provider terminology

## 不改范围

- `src/views/Main/ai/providers` 保持不变，它已经是正确产品目录。
- `ai_provider_models.provider_id` 已经正确，不需要改名。
- 不改 AI apps/knowledge/tools/chat 的产品能力，只改它们引用供应商的字段和查询命名。
- 不保留 `/ai-engine-connections` 兼容路由；当前项目还未正式上线，干净优先。

## 数据库策略

新增 destructive rename migration：

1. 备份实库两类表：供应商主表、模型快照、引用供应商的 AI 表。
2. `RENAME TABLE ai_engine_connections TO ai_providers`。
3. 修改引用字段：
   - `ai_apps.engine_connection_id` -> `provider_id`
   - `ai_knowledge_maps.engine_connection_id` -> `provider_id`
   - `ai_tool_maps.engine_connection_id` -> `provider_id`
   - `ai_runs.engine_connection_id` -> `provider_id`
4. 重建相关索引名：`idx_ai_*_provider` / `uk_ai_providers_*`。
5. 更新 rebuild/rollback SQL，避免新装库继续生成旧名字。

## 代码策略

后端：

- 目录移动到 `internal/module/aiprovider`。
- package/import 全部更新。
- 模型 `Provider.TableName()` 返回 `ai_providers`。
- aiapp/aiknowledgemap/aitoolmap/aichat/airun 中的轻量 provider projection 同步改 TableName 和字段。
- server/router/bootstrap 依赖名改为 `AiProviderService`。
- route group 改 `/api/admin/v1/ai-providers`。

前端：

- API 文件改为 `providers.ts`。
- 类型和对象改为 `AiProviderApi` / `AiProviderItem` / `AiProviderModelItem` 等。
- provider 页面 import 全部改新文件和新类型。
- 共享测试锁定新 REST 路径，不允许旧 `engineConnections` 和 `/ai-engine-connections` 回潮。

## 验证

必须跑：

```powershell
cd E:\admin_go\admin_back_go
$env:GOMAXPROCS='2'
go test -p=1 ./internal/module/aiprovider ./internal/module/aiapp ./internal/module/aiknowledgemap ./internal/module/aitoolmap ./internal/module/aichat ./internal/module/airun ./internal/server ./internal/bootstrap -count=1
```

```powershell
cd E:\admin_go\admin_front_ts
npx vitest run tests/shared/ai/ai-provider-api.test.ts
npx vue-tsc -b --pretty false
```

```powershell
rg -n "ai_engine_connections|engine_connection_id|ai-engine-connections|engineConnections|aiengine|AiEngineConnection|ai_engine_" admin_back_go/internal admin_back_go/scripts admin_front_ts/src admin_front_ts/tests docs/contracts docs/testing docs/migration
```

实库验证：

```sql
SHOW TABLES LIKE 'ai_providers';
SHOW TABLES LIKE 'ai_engine_connections';
SHOW COLUMNS FROM ai_apps LIKE 'provider_id';
SHOW COLUMNS FROM ai_apps LIKE 'engine_connection_id';
```
