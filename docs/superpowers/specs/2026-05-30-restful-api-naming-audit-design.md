# RESTful API Naming Standard and Audit Design

状态：accepted governance spec。硬规则已固化到 `docs/architecture/05-development-quality-rules.md`；后续触碰 route 或 frontend API wrapper 的 feature plan 必须显式引用本规范或根治理文档的 RESTful API 规则。

本文只定义后续审查和迁移边界，不在本轮扫描全仓、不修改后端或前端 runtime。当前有另一个 Codex 正在写代码，本 spec 必须避免制造并发冲突。

## Problem

项目已经确定 Go/Vue 新系统必须走 RESTful resource contract，但当前历史代码和前端 wrapper 里仍可能混有旧 action 命名，例如：

```text
URL path: /list /add /edit /del
frontend API: init/add/edit/del/status
```

这类命名的问题不是“看着不舒服”，而是会让新模块继续复制旧系统动作式 API，最后每个页面各写一套猜测契约。那是垃圾复杂度。

## Goals

1. 固化一套 RESTful API 命名标准，后续新模块直接照抄。
2. 后续单独做一次审查，列出当前项目中不符合标准的 route、handler、service、frontend API wrapper。
3. 审查先产出报告和分级，不直接批量重命名。
4. 迁移必须保护已有 admin 行为、权限码、页面调用和公共 CRUD hook。

## Non-goals

本 spec 不做：

```text
不修改 admin_back_go runtime 代码
不修改 admin_front_ts runtime 代码
不全仓替换 add/edit/del/init/status
不改变现有已验证 API URL
不碰数据库、权限、菜单、i18n 或 smoke 逻辑
```

## Source of truth

审查和后续迁移必须以这些文件为准：

```text
docs/architecture/05-development-quality-rules.md
docs/contracts/admin-api-v1.md
agents/api-contract.md
admin_back_go/internal/module/**/transport/**/route.go
admin_front_ts/src/api/**/*.ts
admin_front_ts/src/hooks/useCrudTable.ts
admin_front_ts/src/components/Table/src/useTable.ts
```

文档规则优先定义新标准；runtime 代码只用于判断现状和兼容风险。

## Standard naming

标准 CRUD contract 只允许一套命名：

```text
GET    /api/admin/v1/<resources>/page-init    page dictionaries/options, optional
GET    /api/admin/v1/<resources>              list/query
GET    /api/admin/v1/<resources>/:id          detail
POST   /api/admin/v1/<resources>              create
PUT    /api/admin/v1/<resources>/:id          update
PATCH  /api/admin/v1/<resources>/:id/status   changeStatus, only when status is a first-class state
DELETE /api/admin/v1/<resources>/:id          deleteOne
DELETE /api/admin/v1/<resources>              deleteBatch, body: { ids: number[] }
```

代码命名：

```text
Go handler/service: List / Detail / Create / Update / ChangeStatus / DeleteOne / DeleteBatch / PageInit
Frontend API:       list / detail / create / update / changeStatus / deleteOne / deleteBatch / pageInit
```

`init` 只允许表示明确 bootstrap contract，例如 `GET /api/admin/v1/users/init`。普通页面的字典、筛选枚举、下拉选项统一叫 `page-init` / `pageInit()`。

## Audit categories

后续细审时每个发现都必须分级，不许见到名字就乱改。

### P0: URL contract violation

新 Go route 里出现动作式 path：

```text
/list
/add
/edit
/del
```

处理原则：优先修 contract。若已被前端使用，必须先列影响面，再设计兼容或迁移步骤。

### P1: frontend wrapper naming drift

`admin_front_ts/src/api/**/*.ts` 中新增或仍暴露：

```text
add()
edit()
del()
init()
status()
```

处理原则：不直接删。先判断是否被公共组件或页面使用，再按模块加标准方法名，旧名作为临时 alias 或后续删除对象。

### P2: handler/service naming drift

Go handler/service 仍叫 `Init/Add/Edit/Del/Status`，但 route 本身已经 RESTful。

处理原则：低风险时随 touched code 迁移；不要为命名洁癖打断正在进行的业务任务。

### P3: intentional exception

允许少数业务动作不是 CRUD，例如：

```text
auth/login
auth/logout
auth/send-code
users/export
ai-conversations/:id/messages/cancel
realtime/ws
```

处理原则：动作必须是业务命令，不是 CRUD 的伪装。需要在 contract 中说明用途、鉴权和 response。

## Proposed audit flow

后续单独调用细审时，按这个顺序做：

1. 只读扫描 backend route：找动作式 path 和 init/page-init 分布。
2. 只读扫描 frontend API wrapper：找 add/edit/del/init/status 方法名。
3. 生成报告，不改代码。
4. 每个问题标记 P0/P1/P2/P3，并列出文件、行号、当前调用方、建议动作。
5. 用户确认后，再写实施 plan。
6. 实施时一次只迁一个模块，先加标准名，再改调用方，最后移除旧 alias。

## Migration policy

默认推荐渐进迁移：

```text
新增模块：只允许标准名。
touched module：优先补标准名，并把页面调用切过去。
旧模块：先报告，等模块被触碰或用户确认后再迁。
公共组件：优先让 useCrudTable/useTable 支持标准名，而不是逼新模块回到 del/status。
```

禁止全仓一次性重命名。那会破坏现有用户空间，也会和并发 Codex WIP 冲突。

## Verification strategy

spec-only 阶段：

```powershell
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

后续只读审查阶段：

```text
rg backend route patterns
rg frontend API wrapper names
人工分类 P0/P1/P2/P3
不跑 backend/frontend runtime tests，因为不改 runtime
```

后续迁移阶段：

```text
触碰 backend module -> targeted go test
触碰 frontend API/page -> targeted npm test or typecheck
触碰 contract/docs -> git diff --check + governance check
触碰 verified runtime behavior -> smoke 或对应 contract gate
```

## Open decision for later review

后续细审报告需要用户确认一个迁移节奏：

```text
Conservative: 只禁止新增，旧代码不动
Balanced: touched module 迁移，旧 alias 临时保留
Strict: 批量迁移标准名，并补公共组件适配
```

推荐默认是 Balanced。它解决真实问题，不做无意义大扫除，也不破坏已有页面。
