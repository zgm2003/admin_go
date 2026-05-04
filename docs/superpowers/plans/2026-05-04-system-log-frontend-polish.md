# System Log Frontend Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把系统日志页从“单文件能用版”打磨成组件边界清晰、交互更像日志控制台、仍然保持 Go REST 契约不变的作品级页面。

**Architecture:** 后端 API 不动，前端只在 `admin_front_ts/src/views/Main/system/log` 内做 feature-folder 拆分。`index.vue` 只负责组装；`useSystemLog.ts` 持有状态、加载、副作用和安全 highlight；展示组件只通过 typed props/emits 通信。

**Tech Stack:** Vue 3 `<script setup lang="ts">`、Element Plus、TypeScript、现有 `SystemLogApi`。

---

## Scope

本次只做方案 A：结构性中改。

- 不改 Go API。
- 不引入新依赖。
- 不做 live tail / WebSocket tail。
- 不引入虚拟列表；当前最多 2000 行，普通渲染足够。
- 不使用 `v-html`。
- 不新增 `any/as any/Record<string, any>`。

## File Map

- Modify: `admin_front_ts/src/views/Main/system/log/index.vue`
  - 页面组合层，只负责移动端侧栏开关和组件拼装。
- Create: `admin_front_ts/src/views/Main/system/log/composables/useSystemLog.ts`
  - 负责 init/files/lines 加载、筛选状态、当前文件、自动滚底、highlight segments、复制文本。
- Create: `admin_front_ts/src/views/Main/system/log/components/SystemLogFileList.vue`
  - 左侧日志文件列表、本地搜索、刷新、选中文件态。
- Create: `admin_front_ts/src/views/Main/system/log/components/SystemLogToolbar.vue`
  - 关键字、级别、tail、查询、刷新、自动滚底、meta 状态。
- Create: `admin_front_ts/src/views/Main/system/log/components/SystemLogViewer.vue`
  - 日志内容、安全高亮、级别行样式、复制行/复制筛选结果。
- Modify: `admin_front_ts/src/i18n/locales/zh-CN.ts`
  - 补齐新增交互文案。
- Modify: `admin_front_ts/src/i18n/locales/en-US.ts`
  - 补齐英文文案，保持 typecheck。

## Tasks

### Task 1: Write the plan artifact

- [ ] Create this file at `docs/superpowers/plans/2026-05-04-system-log-frontend-polish.md`.
- [ ] Keep the plan narrow: frontend structure and interaction only.

### Task 2: Extract feature state into a composable

- [ ] Create `useSystemLog.ts` with explicit state and actions.
- [ ] Keep API calls inside the composable, not presentational components.
- [ ] Use `computed` for current file meta and filtered state labels.
- [ ] Keep keyword highlight as escaped Vue text segments.

### Task 3: Split presentational components

- [ ] Create `SystemLogFileList.vue`.
- [ ] Create `SystemLogToolbar.vue`.
- [ ] Create `SystemLogViewer.vue`.
- [ ] Use props down / events up only.

### Task 4: Slim down route page

- [ ] Replace the previous monolithic template with component composition.
- [ ] Keep mobile sidebar toggle behavior.
- [ ] Ensure `index.vue` falls below the eslint max-lines threshold.

### Task 5: Polish copy and verify

- [ ] Add i18n keys for search, selected file meta, copy actions, empty states.
- [ ] Run `npx vue-tsc -b --pretty false` from `admin_front_ts`.
- [ ] Run targeted eslint for the touched files.

## Verification Commands

Run from `E:/admin_go/admin_front_ts`:

```powershell
npx vue-tsc -b --pretty false
npx eslint src/api/system/log.ts src/views/Main/system/log/index.vue src/views/Main/system/log/components/*.vue src/views/Main/system/log/composables/*.ts src/i18n/locales/zh-CN.ts src/i18n/locales/en-US.ts
```

Backend verification is not required for this polish because the REST contract and Go code are unchanged.
