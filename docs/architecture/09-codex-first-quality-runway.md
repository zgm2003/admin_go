# Codex-first Quality Runway

日期：2026-06-08

本文回答一个问题：后续 Codex 继续做质量提升时，应该按什么顺序推进，才不会把 Go/Vue/Next/DB 写成互相漂移的几套系统。

它不是完成证明。完成证明仍看：

```text
docs/status/current-status.md
docs/knowledge/current-runtime-knowledge.md
docs/knowledge/runtime-source-map.md
docs/db/mysql-live-schema-2026-06-08.md
docs/knowledge/admin-front-source-quality-inventory-2026-06-08.md
scripts/check-runtime-doc-facts.ps1
```

## 需求分析

【需求判断】
是真问题。项目已经有 Go 后端、Admin Vue、Canvas Next、live MySQL schema、route/API/source-quality inventories，但后续 agent 如果只看单个 inventory，容易横向乱扫、把 planned 写成 implemented，或者用 fallback 掩盖数据结构问题。

【核心问题】
需要一条从证据到行动的路线：每轮只选一个窄切片，先证明当前坏状态，再最小改动，再把知识库和 checker 同步。

【复杂度检查】
不引入新框架、不改目录结构、不新增 agent 层级。用现有 facts、scripts、agents 和 Superpowers 工作流串起来。

【破坏性分析】
这是文档治理切片，不改变 API、DB、路由、UI 或 runtime 行为。唯一影响是冷启动阅读顺序和 runtime fact checker 多检查一个路线图入口。

## 当前事实基线

| 面 | 当前事实 | 证据 |
| --- | --- | --- |
| Go backend routes | `286` route registrations，contract drift 当前无 undocumented/source-docs-only 阻断 | `docs/knowledge/backend-route-inventory-2026-06-08.md`, `docs/knowledge/backend-route-contract-drift-2026-06-08.md` |
| Frontend/backend API drift | `265` exact frontend backend calls compared，`265` route-match，owner-decision-required = `0` | `docs/knowledge/frontend-backend-api-drift-2026-06-08.md`, `docs/knowledge/api-source-only-route-review-2026-06-08.md` |
| Live MySQL | live base tables = `55`，schema artifact 来自 MySQL live 查验 | `docs/db/mysql-live-schema-2026-06-08.md`, `docs/db/mysql-live-schema-2026-06-08.sql` |
| DB ownership | `55` live tables reviewed，`55` go-model，`0` live-schema-only tables | `docs/knowledge/db-schema-ownership-map-2026-06-08.md` |
| Admin Vue source quality | `274` source files，`0` any，`0` as-any，`0` catch-any，`511` fallback，`0` direct external HTTP | `docs/knowledge/admin-front-source-quality-inventory-2026-06-08.md` |
| Canvas Next route/RBAC facts | `/assets` 是唯一资产页；`canvas_ai_text_generate` 是 soft-deleted orphan；logout 先 revoke backend | `docs/knowledge/canvas-asset-route-contract-review-2026-06-07.md`, `docs/knowledge/canvas-rbac-permission-contract-review-2026-06-07.md`, `docs/knowledge/canvas-auth-logout-contract-review-2026-06-07.md` |

## 递进规则

每一轮只允许推进一个主切片：

```text
1. docs drift：只修文档/checker，不碰 runtime
2. source-quality debt：先 source guard，再最小改代码，再刷新 inventory
3. API/route drift：先 frontend/backend inventory，再 owner decision，再 contract/status/checker
4. DB/schema drift：必须 live MySQL 查验，不准用 migration 猜当前表
5. runtime bug：先复现和失败测试，不准写兜底掩盖
```

如果一个切片同时跨 Go/Vue/Next/DB，必须先证明跨边界数据结构：

```text
backend DTO / route metadata
frontend API wrapper / page action
RBAC PAGE/BUTTON code
live DB table / permission row
knowledge artifact / checker assertion
```

## Agent 选择

| 任务类型 | 主 agent | 必读证据 | 禁止 |
| --- | --- | --- | --- |
| Go capability / route / service | `agents/backend-go.md` 或 backend/API contract agent | `backend-capability-manifest`, route inventory, contracts, Go tests | handler 直连 DB/Redis；service 依赖 `gin.Context`；无 context 的阻塞操作 |
| Admin Vue 页面/组件 | frontend/admin agent | Admin source-quality inventory, Vue tests, i18n catalog | touched code 新增 `any/as any/Record<string, any>`；手写标准 CRUD primitives |
| Canvas Next page/API | Canvas/React agent | Canvas route/RBAC/auth/AI reviews, Next service source | module-level mutable request state；大 barrel import；客户端 provider/model 覆盖 |
| DB/schema | DB/backend agent | live MySQL snapshot + ownership map | 用 migration 当当前表结构；不跑 `-LiveSchema` 就声称 DB 匹配 |
| Codex governance | docs/governance agent | `docs/README.md`, `02-agent-framework`, hooks docs, checker scripts | 完整冷启动清单复制到第二处；planned 写 implemented |

## Quality runway

### Runway A: Admin Vue fallback 债务

当前 `any/as any/catch-any/direct external HTTP` 已清零，下一步只能按 fallback inventory 逐类处理。

优先顺序：

```text
1. API payload fallback：例如 `payload.size || undefined`，必须追问空值是否合法
2. i18n/error message fallback：错误消息必须 fail-closed，业务允许时才 fallback
3. component display fallback：如空 icon、空 fileName，区分合法空态和 bug
4. boolean predicate logical-or：大量是条件判断，不要机械清理
```

完成一个 fallback 切片的最低证据：

```text
RED source/behavior guard
最小实现，不新增 any
admin-front-source-quality inventory refresh
review/spec/plan/status/checker 同步
npm run typecheck
```

### Runway B: Go capability hardening

Go 侧后续优先从 capability manifest 选一个 capability，不横扫全后端。

每轮检查：

```text
transport/{platform}/route.go 是否只注册 HTTP 表面
handler 是否只做 bind/response/auth edge，不做业务状态机
service 是否接收 context.Context
repository 是否拥有 DB query，错误是否向上包装
route_meta 是否与权限/operation log 同步
```

验证优先级：

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/<capability>/...
# 触碰跨模块或 infra 时再扩大到 go test ./...
```

不要为了“架构完整”新增接口。只有第二个真实实现出现时，才抽 interface。

### Runway C: Canvas Next performance / contract hardening

Canvas Next 后续按 Vercel 规则优先处理真实性能/契约边界：

```text
independent requests start early / await late
no module-level mutable request state in RSC/SSR/proxy paths
direct imports for heavy UI paths; avoid large barrel imports
provider/model/api_key/base_url 永远由 backend agent/provider 选择，浏览器不覆盖
```

每轮证据：

```text
source guard or unit test
Next route/service source evidence
frontend API inventory if API call changed
runtime-source-map / current-runtime-knowledge if route/page fact changed
```

### Runway D: DB/schema ownership

任何表结构结论都必须从 live MySQL snapshot 开始：

```powershell
cd E:\admin_go
powershell -ExecutionPolicy Bypass -File .\scripts\export-live-mysql-schema.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\export-db-schema-ownership-map.ps1 -OutputDate 2026-06-08
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1 -LiveSchema
```

禁止事项：

```text
不准从 migration 推断当前表
不准把 backup/live-schema-only 表写成 active module
不准改字段语义后只改前端
```

## 每轮收口门槛

| 变更类型 | 最低验证 |
| --- | --- |
| docs only | `git diff --check`; `scripts/check-agent-governance.ps1 -Mode working` |
| knowledge/checker | docs only gates + `scripts/check-runtime-doc-facts.ps1`；涉及 DB fact 加 `-LiveSchema` |
| Admin Vue source | targeted Vitest + `npm run typecheck` + inventory refresh + root gates |
| Canvas Next source | targeted tests/typecheck/build 按触碰面选择 + frontend API inventory if API changed + root gates |
| Go source | targeted `go test`；触碰 shared/infra/route metadata 时扩大验证；root gates |

## 不准提前宣布完成

下面这些只能写成 next runway，不能写成已完成：

```text
Admin Vue fallback = 511 尚未逐条审查
Canvas Next 全量 performance hardening 尚未完成
Go 每个 capability 的 service/repository/context/error hardening 尚未逐一完成
live MySQL schema 已有 2026-06-08 snapshot，但未来 schema 变更必须重新查 live
```

好路线图不是多写文档，而是让下一个 Codex 无法把坏状态藏起来。
