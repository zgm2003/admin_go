# Progressive Code Quality Hardening Design

状态日期：2026-06-06

主角色：`agents/reviewer.md`

本 spec 定义 Go/Vue/Canvas 三个 active runtime 的递进式代码质量提升方式。它不声明任何 runtime 已完成；真正事实仍以 `docs/status/current-status.md`、smoke、tests 和 live runtime 为准。

## Linus 三问

1. **这是真问题还是假问题？**
   真问题。全链路已经跑通后，继续放任 `any`、字段 alias、`?? []`、`|| ""`、巨型组件和本地默认值，会把后端契约漂移、权限数据缺失、i18n 漏项和迁移错误吞掉。

2. **有更简单的做法吗？**
   有。不要全仓 regex 替换。按数据 owner 和公共基础件递进：先修公共组件类型和 API 契约边界，再清业务页面，再按 Go module 处理错误/i18n。

3. **会破坏什么？**
   会破坏登录、权限、表格页、Canvas 生成链路，如果把合法业务默认值也删掉。因此每个改动必须先有 RED guard，证明当前兜底掩盖了非法状态，而不是合法空态。

4. **为什么这些状态会出现？**
   早期为了“先跑通”允许前端宽类型、组件吞未知字段、页面自造默认值。现在 current-user DTO、REST contract、Canvas free-generation、i18n 和 CRUD 规则已经明确，继续兜底就是架构债。

## 需求判断

目标不是“清空所有 `||` 和 `??`”。目标是让数据结构和契约清楚：

```text
非法状态：失败、抛错、测试红灯
合法空态：写成业务规则，有 owner，有测试
组件默认值：只存在于组件自己的 UI 行为，不污染 API/DTO
```

## 范围

Active runtime：

```text
E:\admin_go\admin_back_go
E:\admin_go\admin_front_ts
E:\admin_go\canvas_front_next
```

治理文档位置：

```text
E:\admin_go\docs\superpowers\specs
E:\admin_go\docs\superpowers\plans
```

第一阶段只进入 `admin_front_ts` 公共基础件：

```text
src/components/Table
src/components/Search
src/types/common.ts
tests/shared/table
src/i18n/locales/zh-CN.ts
src/i18n/locales/en-US.ts
```

## 非目标

- 不批量格式化三仓。
- 不重写 UI 视觉。
- 不改变 Go API 路由、DTO、数据库语义。
- 不把所有 optional chaining 当 bug。
- 不删除合法业务默认值，例如表格无分页时 `pagination = null`、新增根菜单 `parent_id = 0`。
- 不一次拆完 Canvas 2647 行大页面。

## 设计方案比较

### 方案 A：全仓 regex 扫描后批量替换

优点：看起来快。

缺点：会把合法 UI 默认值、浏览器边界、用户空输入和业务空态一起删掉。风险最高，最没有品味。

结论：不采用。

### 方案 B：先修业务模块页面

优点：能直接减少部分页面里的坏味道。

缺点：公共 `AppTable` / `Search` 仍然吞类型，业务页会继续围着坏基础件打补丁。特殊情况没有被消灭，只是迁移位置。

结论：暂不作为第一刀。

### 方案 C：公共基础件先行，再按模块递进

优点：从数据结构消灭特殊情况。`AppTable`、`Search`、`RemoteSelect`、HTTP client 是业务页面的入口；这里类型收紧后，后续模块改动会自然变小。

缺点：需要写更精确的类型和 guard，不能图快。

结论：采用。

## 核心设计

### 1. Fallback 分类

每个 `||`、`??`、`?.`、默认空数组、默认空对象只能落入下面一类：

| 分类 | 允许吗 | 例子 | 要求 |
| --- | --- | --- | --- |
| contract-hiding | 不允许 | `payload.msg || '请求失败'` | 改成 fail closed |
| field-alias | 不允许 | `user.user_id ?? user.id` | 统一 DTO |
| component-owned default | 允许 | `showRefresh = true` | 只在组件 props 默认值里 |
| legal empty UI state | 允许 | 空搜索表单、空表格数据 | 有明确组件语义 |
| browser boundary | 允许 | `matchMedia?.(...)` | 只在浏览器 API 不存在时降级 |
| user input normalization | 允许 | `input.trim()` 后空字符串 | 业务或 UI 明确 |
| runtime config default | 谨慎允许 | `VITE_*` 缺失直接 fail | 默认值必须有部署文档 |

### 2. `admin_front_ts` 公共表格数据结构

当前 `AppTable` 是标准 CRUD 页面的核心组件。第一阶段要把它从“任意数组 + any”改成显式数据结构：

```ts
export type TableRow = Record<string, unknown>
export type TableColumnKey = string

export interface TableColumn<Row extends TableRow = TableRow> {
  key?: TableColumnKey
  prop?: keyof Row & string
  label: string
  hidden?: boolean
  width?: string | number
  minWidth?: string | number
  fixed?: boolean | 'left' | 'right'
  overflowTooltip?: boolean
  formatter?: (
    row: Row,
    column: { property: string },
    value: unknown,
    index: number
  ) => unknown
  [elementTableColumnProp: string]: unknown
}

export interface TablePaginationState {
  current_page: number
  page_size: number
  total: number
  total_page?: number
}
```

`[elementTableColumnProp: string]: unknown` 是 Element Plus table-column 透传边界，不是 API DTO。它必须只留在公共组件层，不能扩散到业务 API 类型。

### 3. `Search` 数据结构

`Search` 的职责是渲染筛选字段并把表单值原样交还给调用方。它不应该吞 `any`，也不应该把父级 `modelValue` 缺失偷偷改成 `{}`。

第一阶段规则：

```text
modelValue 必须是 SearchFormModel。
watch props.modelValue 时只接受对象；非法值抛错。
select/cascader options 类型留在 SearchField 泛型，不 cast any[]。
RemoteSelect label/value/keyword 默认值是组件输入配置默认，不是 API fallback。
```

### 4. i18n 规则

触碰 `ColumnSetting` 的可见文案时同步 locale：

```text
common.actions.columnSetting
```

中文：

```text
列设置
```

英文：

```text
Column settings
```

### 5. 后续递进顺序

#### Batch 1：Admin shared primitives

目标：公共表格和搜索组件无 `any`、无契约隐藏兜底，保留现有 API 和视觉。

#### Batch 2：Admin API wrappers and high-traffic pages

目标：`src/api/**/*.ts` 继续收紧 `positiveID(params.id ?? 0)` 这类“先兜成 0 再报错”的写法，改成显式 `requirePositiveID(params.id, label)`。业务页只处理自己拥有的空态。

#### Batch 3：Canvas config and generation state

目标：把 Canvas 生成配置从大页面里抽成纯函数，测试区分“用户配置默认值”和“契约缺字段”。不重写画布视觉。

#### Batch 4：Backend per-module app error/i18n

目标：按 touched module 把 raw `apperror.BadRequest("中文")` 迁到 keyed error，并同步 zh-CN/en-US catalog。不得全局机械替换。

## 兼容性要求

第一阶段不得改变：

```text
AppTable prop 名称
AppTable slot 名称：cell-<key> / toolbar-left / toolbar-right
Search v-model / query / reset 事件
useTable / useCrudTable public API
现有 CRUD 页面布局高度链
现有 route / permission / API wrapper behavior
```

允许改变：

```text
公共组件内部类型
非法 column 配置从静默空字符串变成明确错误
测试增加 source guard
列设置文案改为 i18n key
```

## 验证策略

第一阶段最小验证：

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/table/shared-primitives-quality.test.ts tests/shared/table/useTable.test.ts tests/shared/table/useCrudTable.test.ts tests/shared/i18n/literal-i18n-keys.test.ts
npx vue-tsc -b --pretty false
```

root docs-only / governance 验证：

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

## 成功标准

- `AppTable`、`ColumnSetting`、`Search`、`src/types/common.ts` 的 touched code 不再出现 `any` / `as any` / `Record<string, any>`。
- `Search` 不再用 `value || {}` 吞掉非法输入。
- `AppTable` 不再用 `col: any`、`row: any`、`page as any`。
- i18n key 对齐测试通过。
- `vue-tsc` 通过。
- 没有变更 Go runtime、Canvas runtime、API contract 或 current-status。

## 风险

- Element Plus table-column props 很宽，完全精确类型会引入大量无意义类型体操。第一阶段只把透传边界收敛在 `TableColumn`，不让它污染 API DTO。
- 某些业务页可能传入没有 `label` 的 action column。如果测试暴露出来，不应在业务页到处兜底，而应要求 column 定义补齐 `label` 或用明确 slot-only column 类型。
- 这不是 fallback 总清算。后续 Canvas 和 Go 模块必须各自写独立 plan。
