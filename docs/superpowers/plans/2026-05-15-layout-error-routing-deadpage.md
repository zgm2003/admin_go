# Layout Error Routing and DeadPage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把前端路由错误语义拆清楚：路由树未命中时进 Layout 内的 404，路由树命中但组件解析失败时进 Layout 内的 DeadPage；两者都保留统一壳，但不污染正常菜单/标签页。

**Architecture:** Layout 继续做薄壳，`el-main` 仍然是唯一视图出口。404 不再是裸 public page，而是 Layout 的静态子路由；DeadPage 不再靠 toast 后丢弃路由，而是给原始 route path 挂一个 fallback 组件。页面外壳靠 `route.meta.pageLayout` 决定：普通内容页走 `card`，home 和错误页走 `plain` / `centered`，不要再用 `route.path === '/home'` 这种脆分支。401/403 不动。

**Tech Stack:** Vue 3 + vue-router + Pinia + vue-i18n + Vitest + TypeScript.

---

## Scope and non-goals

必须收：

```text
路由树未命中 => 404。
组件未对上 => DeadPage。
404 和 DeadPage 都在 Layout 的 main 里渲染。
404 不污染菜单/标签页；DeadPage 保留原始 route.path 和 menu 绑定。
Layout 外壳从路径判断改成 route meta 判断。
401 / 403 这次不做。
```

不在本次收：

```text
后端鉴权语义改造。
登录态刷新逻辑。
菜单树协议改动。
数据库结构改动。
把 404 做成新的 public 裸页。
把 DeadPage 做成跳转页。
```

---

## File map

### Frontend

```text
admin_front_ts/src/router/routes.ts
admin_front_ts/src/router/index.ts
admin_front_ts/src/router/runtime-route-tree.ts
admin_front_ts/src/router/guard-helpers.ts
admin_front_ts/src/types/vue-router.d.ts
admin_front_ts/src/views/Layout/index.vue
admin_front_ts/src/views/Layout/utils/page-layout.ts
admin_front_ts/src/views/Error/404.vue
admin_front_ts/src/views/Error/DeadPage.vue
admin_front_ts/src/views/Error/components/ErrorStatePanel.vue
admin_front_ts/src/i18n/locales/zh-CN.ts
admin_front_ts/src/i18n/locales/en-US.ts
```

### Tests

```text
admin_front_ts/tests/shared/router/error-routes.test.ts
admin_front_ts/tests/shared/router/runtime-route-tree.test.ts
admin_front_ts/tests/shared/layout/page-layout.test.ts
```

---

## Task 1: 把 404 变成 Layout 子路由，并把页面外壳切换成 meta 驱动

**Files:**

- Modify: `admin_front_ts/src/router/index.ts`
- Modify: `admin_front_ts/src/router/routes.ts`
- Create: `admin_front_ts/src/types/vue-router.d.ts`
- Create: `admin_front_ts/src/views/Layout/utils/page-layout.ts`
- Modify: `admin_front_ts/src/views/Layout/index.vue`
- Create: `admin_front_ts/tests/shared/router/error-routes.test.ts`
- Create: `admin_front_ts/tests/shared/layout/page-layout.test.ts`

- [ ] **Step 1: 写失败测试，先把规则钉死**

`admin_front_ts/tests/shared/router/error-routes.test.ts`：

```ts
import { describe, expect, it } from 'vitest'
import { createCatchAllRoute, createMainRoute, publicRoutes } from '../../../src/router/routes'

describe('error route shell', () => {
  it('keeps 404 under the Layout shell and keeps login as the only public route', () => {
    expect(publicRoutes.map((route) => route.name)).toEqual(['login'])

    const mainRoute = createMainRoute()
    const childNames = (mainRoute.children ?? []).map((route) => route.name)

    expect(childNames).toContain('home')
    expect(childNames).toContain('404')

    const notFound = (mainRoute.children ?? []).find((route) => route.name === '404')
    expect(notFound?.path).toBe('/404')
    expect(notFound?.meta?.pageLayout).toBe('centered')
    expect(notFound?.meta?.errorKind).toBe('not-found')

    expect(createCatchAllRoute().redirect).toBe('/404')
  })
})
```

`admin_front_ts/tests/shared/layout/page-layout.test.ts`：

```ts
import { describe, expect, it } from 'vitest'
import { resolvePageLayout } from '../../../src/views/Layout/utils/page-layout'

describe('page layout resolver', () => {
  it('treats home as plain, normal pages as card, and error pages as centered', () => {
    expect(resolvePageLayout({ pageLayout: 'plain' })).toBe('plain')
    expect(resolvePageLayout({ pageLayout: 'centered' })).toBe('centered')
    expect(resolvePageLayout({})).toBe('card')
  })
})
```

- [ ] **Step 2: 跑测试，确认它们先红起来**

Run:

```powershell
cd E:/admin_go/admin_front_ts
npm run test -- tests/shared/router/error-routes.test.ts tests/shared/layout/page-layout.test.ts
```

Expected: fail，原因是 `404` 还没进 Layout 子路由，`pageLayout` 还没落地。

- [ ] **Step 3: 落最小实现**

把 `src/router/routes.ts` 改成：

- `publicRoutes` 只保留 `login`
- 新增 `404` 子路由到 `createMainRoute()` 的 children
- `home` 标 `meta.pageLayout = 'plain'`
- `404` 标 `meta.pageLayout = 'centered'`
- `404` 标 `meta.errorKind = 'not-found'`
- `createCatchAllRoute()` 继续 redirect 到 `/404`
- `src/router/index.ts` 的初始 routes 里带上 `mainRoute`，让 `/404` 在 `setupDynamicRoutes()` 之前也能先命中 Layout 壳

在 `src/types/vue-router.d.ts` 里补：

```ts
import 'vue-router'

declare module 'vue-router' {
  interface RouteMeta {
    menuId?: string
    pageLayout?: 'card' | 'plain' | 'centered'
    errorKind?: 'not-found' | 'dead'
    deadRoutePath?: string
    deadViewKey?: string
  }
}
```

在 `src/views/Layout/utils/page-layout.ts` 里只做一件事：读取 `route.meta.pageLayout`，默认返回 `'card'`。

`src/router/index.ts` 里要把 `mainRoute` 作为初始路由的一部分注册进去，而不是等 `setupDynamicRoutes()` 之后才出现。这样 `/404` 在登录前直访也能先命中 Layout 壳，不会先被当成未知路由踢回登录。

`setupDynamicRoutes()` 继续负责把后端动态路由补到 `mainRoute.children` 里，但它只做替换，不再把缺组件的路由静默丢掉。

`src/views/Layout/index.vue` 里把：

```ts
const isPlainPage = computed(() => route.path === '/home')
```

换成：

```ts
const pageLayout = computed(() => resolvePageLayout(route.meta))
```

然后 `layout-view` 的 class 依据 `pageLayout` 切：

- `card` => 继续用 `page-card`
- `plain` => 不包卡片
- `centered` => 让内容在 main 里居中显示

- [ ] **Step 4: 重跑测试**

Run:

```powershell
npm run test -- tests/shared/router/error-routes.test.ts tests/shared/layout/page-layout.test.ts
```

Expected: 2 files pass.

---

## Task 2: 给组件缺失的动态路由挂 DeadPage fallback

**Files:**

- Create: `admin_front_ts/src/router/runtime-route-tree.ts`
- Modify: `admin_front_ts/src/router/index.ts`
- Create: `admin_front_ts/src/views/Error/DeadPage.vue`
- Create: `admin_front_ts/src/views/Error/components/ErrorStatePanel.vue`
- Modify: `admin_front_ts/src/i18n/locales/zh-CN.ts`
- Modify: `admin_front_ts/src/i18n/locales/en-US.ts`
- Create: `admin_front_ts/tests/shared/router/runtime-route-tree.test.ts`

- [ ] **Step 1: 写失败测试，先确认“路径存在但组件不存在”不会被吞掉**

`admin_front_ts/tests/shared/router/runtime-route-tree.test.ts`：

```ts
import { describe, expect, it, vi } from 'vitest'
import { buildRuntimeRouteTree } from '../../../src/router/runtime-route-tree'

describe('runtime route tree', () => {
  it('keeps the original path and swaps in DeadPage when view_key is missing', () => {
    const modules = {
      '../views/Main/payment/channel/index.vue': vi.fn(),
    }

    const tree = buildRuntimeRouteTree([
      {
        path: '/payment/order',
        name: 'payment-order',
        view_key: 'payment/order',
        meta: { menuId: '88' },
      },
    ], modules)

    const deadRoute = tree.find((route) => route.path === '/payment/order')

    expect(deadRoute?.name).toBe('payment-order')
    expect(deadRoute?.meta?.errorKind).toBe('dead')
    expect(deadRoute?.meta?.deadRoutePath).toBe('/payment/order')
    expect(deadRoute?.meta?.deadViewKey).toBe('payment/order')
  })
})
```

- [ ] **Step 2: 跑测试，确认它先红**

Run:

```powershell
cd E:/admin_go/admin_front_ts
npm run test -- tests/shared/router/runtime-route-tree.test.ts
```

Expected: fail，原因是 `buildRuntimeRouteTree()` 还不存在。

- [ ] **Step 3: 落运行时路由树**

新增 `src/router/runtime-route-tree.ts`，职责只做一件事：

- 输入 backend 的 `DynamicRouteItem[]`
- 用 `resolveViewComponent()` 找真实页面
- 找不到时，不要 `continue`
- 直接把同一路径注册成 `DeadPage` 组件
- 原始 `path` / `name` / `menuId` 保留
- `meta.errorKind = 'dead'`
- `meta.pageLayout = 'centered'`
- `meta.deadRoutePath` / `meta.deadViewKey` 用来喂给 DeadPage

`src/router/index.ts` 里改成用这个 helper 构建 children，不再把缺组件的路由静默丢掉。

`DeadPage.vue` 只负责展示：

- 标题：`error.deadPage.title`
- 说明：`error.deadPage.description`
- 路径信息：`deadRoutePath`
- `view_key` 信息：`deadViewKey`
- 操作按钮：返回上一页 / 返回首页

`ErrorStatePanel.vue` 只负责视觉，不碰路由逻辑。

同时在 `zh-CN.ts` / `en-US.ts` 里补这几个键，别再写裸中文：

- `error.deadPage.title`
- `error.deadPage.description`
- `error.deadPage.back`
- `error.deadPage.home`
- `error.deadPage.detailPath`
- `error.deadPage.detailViewKey`

- [ ] **Step 4: 重跑测试和类型检查**

Run:

```powershell
npm run test -- tests/shared/router/runtime-route-tree.test.ts
npm run typecheck
```

Expected: pass。

---

## Task 3: 让 404 / DeadPage 真正舒服地躺在 Layout main 里

**Files:**

- Modify: `admin_front_ts/src/views/Layout/index.vue`
- Modify: `admin_front_ts/src/views/Error/404.vue`
- Modify: `admin_front_ts/src/views/Error/DeadPage.vue`
- Modify: `admin_front_ts/src/views/Error/components/ErrorStatePanel.vue`

- [ ] **Step 1: 写一个 source test，防止又退回 100vh 裸页**

`admin_front_ts/tests/shared/router/error-routes.test.ts` 里再加一条对源码的硬断言：

```ts
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, it } from 'vitest'

describe('error view shell', () => {
  it('does not use viewport-sized self centering in the error views', () => {
    const source404 = readFileSync(join(process.cwd(), 'src/views/Error/404.vue'), 'utf8')
    const sourceDead = readFileSync(join(process.cwd(), 'src/views/Error/DeadPage.vue'), 'utf8')

    expect(source404).not.toContain('100vh')
    expect(sourceDead).not.toContain('100vh')
  })
})
```

- [ ] **Step 2: 把居中和留白收口到 Layout**

`src/views/Layout/index.vue` 里加一个 `layout-view--centered` class：

- `display: flex`
- `align-items: center`
- `justify-content: center`
- `padding: 24px`

这样 404 / DeadPage 在 main 里直接居中，不需要自己搞 viewport 级 wrapper。

`ErrorStatePanel.vue` 只保留面板本体：标题、描述、详情、按钮。

`404.vue` 和 `DeadPage.vue` 都变成薄壳：

- 拿 i18n 文案
- 组装按钮动作
- 把内容喂给 `ErrorStatePanel`

`404.vue` 继续保持 `route.name === '404'` 的 public 语义，但不再单独抢出 Layout。

- [ ] **Step 3: 跑完整验证**

Run:

```powershell
cd E:/admin_go/admin_front_ts
npm run test
npm run build
git diff --check
```

Expected: all pass，且 404 / DeadPage 都在 Layout main 中显示，不破坏标签页、侧边栏和菜单状态。

---

## Final acceptance

- 路由树未命中 => 404。
- 组件未对上 => DeadPage。
- 404 / DeadPage 都在 Layout main 内显示。
- 404 不污染 tab / menu。
- DeadPage 保留原始 path 和 `view_key`。
- `Layout` 不再靠 `route.path === '/home'` 判断页面壳。
