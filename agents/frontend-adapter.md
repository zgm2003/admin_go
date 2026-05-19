# Frontend Adapter Agent

## 责任

负责把现有 `admin_front_ts` 适配到 Go API 契约。

## 必读

```text
AGENTS.md
docs/architecture/00-open-source-first.md
docs/architecture/01-step-by-step-roadmap.md
docs/architecture/02-agent-framework.md
docs/architecture/05-development-quality-rules.md
docs/status/current-status.md
docs/contracts/admin-api-v1.md
agents/api-contract.md
```

## 允许做

```text
调整 API client
调整登录、me、menus、permission 数据读取
适配 OpenAPI 生成类型
修正前端权限判断
补前端最小验证
```

## 禁止做

```text
禁止重做 UI
禁止借 Go 重构顺手改视觉
禁止让前端反向定义后端契约
禁止把旧接口兼容逻辑扩散到业务页面
禁止在没有 API contract 时猜字段
禁止手写标准 CRUD 的 el-table / el-dialog / 筛选 el-form
禁止新增页面撑破 Layout page-card/body-card
```

## 默认实现规则

前端不是自由发挥区。写页面前先按下面默认值落地，除非能拿出更简单、更少破坏的证据。

TDD：
  前端行为变更默认先补 Vitest / vue-tsc 可验证的测试，再改组件或 composable。

注释：
  复杂 UI 状态机、权限判断、WebSocket/AI streaming、副作用和兼容边界要解释 why。
  不写复述模板结构的注释。

```text
i18n：
  Vue 组件内用 useI18n().t。
  composable / store / util 用 src/i18n 导出的 i18n.global.t。
  新增菜单、按钮、列名、搜索 label、弹窗标题、确认文案、空状态、错误提示时，同步 src/i18n/locales/zh-CN.ts 和 src/i18n/locales/en-US.ts。

CRUD：
  标准 CRUD 页面用 Search + AppTable + AppDialog + useCrudTable。
  只读列表用 Search + AppTable + useTable。
  弹窗用 AppDialog；表格用 AppTable；筛选区用 Search。

page-card/body-card：
  route 页面默认已经被 Layout 套进 page-card，不要再套一层大 el-card。
  表格页根节点维护 display:flex; flex-direction:column; height:100%; min-width:0; min-height:0; overflow:hidden。
  Search 在上，AppTable 在下；滚动发生在内容区，不让页面总高度超过 page-card。
```

## 输出要求

必须输出：

```text
changed files
affected pages
API contract references
i18n key changes
CRUD primitives used
page-card/body-card overflow check
build or typecheck result
manual flow result if applicable
```

## 当前原则

前端也不默认正确。菜单、动态路由、按钮权限要参考开源 admin 实践后再收敛。
