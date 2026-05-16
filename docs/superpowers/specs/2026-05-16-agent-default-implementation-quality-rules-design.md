# Agent Default Implementation Quality Rules Design

日期：2026-05-16
状态：accepted / implemented in this docs cut
范围：`E:\admin_go` root agent framework 文档。本文只固化默认实现规则，不修改 `admin_back_go` / `admin_front_ts` runtime 代码。

## 1. 结论

要把默认实现规则写进 agent 冷启动层，而不是只写在某个模块计划里。

这三个问题已经反复出现，继续靠口头提醒就是坏设计：

```text
新模块写完再补 i18n
CRUD 页面绕过项目公共组件手搓 el-table / el-dialog / 筛选 form
前端页面内容撑破 Layout 的 page-card/body-card
```

正确做法不是再造一个自动修复机器人，而是把规则放到 agent 每次都会读的位置：

```text
AGENTS.md
agents/frontend-adapter.md
agents/backend-worker.md
agents/reviewer.md
docs/architecture/02-agent-framework.md
docs/architecture/05-development-quality-rules.md
```

`05-development-quality-rules.md` 是细则真相源；`AGENTS.md` 和角色文档只放冷启动硬规则和执行口径。

## 2. Linus 三问

### 2.1 这是真问题吗？

是。用户明确指出：每次页面写完再改 i18n、CRUD 公共组件和 body-card 溢出，很痛苦。这是工程规则没有进入 agent 默认路径导致的重复返工。

### 2.2 有更简单的方法吗？

有。只做文档规则固化，不做代码改造，不做复杂检测器。

第一版只落三条：

```text
Full-stack i18n 默认做
Frontend CRUD 默认用公共组件
Frontend page-card/body-card 默认不溢出
```

以后如果要做机器检查，再在 `scripts/check-agent-governance.ps1` 或 frontend quality test 里加窄规则。现在先别过度设计。

### 2.3 会破坏什么吗？

不会。这个切片只改 root docs 和 agent role docs，不碰：

```text
admin_back_go runtime
admin_front_ts runtime
数据库 schema
API contract
菜单 / RBAC
smoke 脚本语义
```

## 3. 当前事实

### 3.1 后端 i18n

```text
middleware 顺序：CORS -> I18n -> AuthToken
语言来源：Accept-Language
支持语言：zh-CN / en-US
HTTP msg 本地化边界：response
错误消息：apperror.*Key
成功消息：response.OKWithMessageKey
catalog：internal/i18n/locales/{lang}/{module}.yaml
coverage：internal/i18n/source_coverage_test.go
```

### 3.2 前端 i18n

```text
运行时：vue-i18n
语言状态：lang Cookie
HTTP：根据 lang Cookie 自动设置 Accept-Language
locale 文件：src/i18n/locales/zh-CN.ts / src/i18n/locales/en-US.ts
守卫测试：literal-i18n-keys.test.ts / no-visible-chinese.test.ts
```

### 3.3 CRUD 公共组件

```text
Search：src/components/Search
AppTable / useTable：src/components/Table
AppDialog：src/components/AppDialog
useCrudTable：src/hooks/useCrudTable.ts
```

标准 CRUD 页面默认组合：

```text
Search + AppTable + AppDialog + useCrudTable
```

只读列表默认组合：

```text
Search + AppTable + useTable
```

### 3.4 page-card / body-card

用户说的 body-card，在当前 Vue shell 里对应 Layout 的 `page-card`。

```text
route meta 默认 pageLayout: card
Layout 给 route view 套 page-card
桌面 page-card height: 100%
AppTable fixedFooter=true 时表格 height: 100%
```

因此表格页必须维护高度链：

```text
display:flex
flex-direction:column
height:100%
min-width:0
min-height:0
overflow:hidden
```

## 4. 规则落位

### 4.1 `AGENTS.md`

放最短硬规则：

```text
i18n 默认前后端都做
CRUD 默认用 Search/AppTable/AppDialog/useCrudTable
页面默认待在 Layout page-card/body-card 内，不撑破 shell
```

### 4.2 `docs/architecture/05-development-quality-rules.md`

放完整细则：

```text
Full-stack i18n 默认规则
Frontend CRUD 公共组件规则
Frontend page-card / body-card 布局规则
验收门槛同步三条规则
```

### 4.3 `docs/architecture/02-agent-framework.md`

告诉 agent：这些是默认实现质量规则，不是单个模块的临时偏好。

### 4.4 `agents/frontend-adapter.md`

前端 agent 必须默认输出：

```text
i18n key changes
CRUD primitives used
page-card/body-card overflow check
```

### 4.5 `agents/backend-worker.md`

后端 agent 必须默认输出：

```text
i18n catalog and key coverage if response msg changed
```

### 4.6 `agents/reviewer.md`

Reviewer 必须把漏 i18n、绕过 CRUD 公共组件、撑破 page-card/body-card 当作审查项。

## 5. 非目标

```text
不改业务代码
不迁移旧页面
不写自动重构脚本
不新增依赖
不把 pre-push 变成 frontend build/full smoke
不把所有历史裸中文一次性清掉
```

旧问题可以分批收，新写和 touched code 不准继续扩大问题。
