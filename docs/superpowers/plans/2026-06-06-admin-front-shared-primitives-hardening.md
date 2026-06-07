# Admin Front Shared Primitives Quality Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `admin_front_ts` shared table/search primitives typed and fail-closed, without changing existing CRUD page behavior.

**Architecture:** Add source-level RED guards first, then introduce narrow shared types for `AppTable`, `ColumnSetting`, `Search`, and remote list fetches. Keep Element Plus prop passthrough inside component-owned types; do not let open-ended DTOs leak into API wrappers or business pages.

**Tech Stack:** Vue 3 `<script setup>`, TypeScript strict mode, Element Plus, vue-i18n, Vitest source guards, `vue-tsc`.

---

## Scope check

This plan implements only Batch 1 from `docs/superpowers/specs/2026-06-06-progressive-quality-hardening-design.md`.

Out of scope for this plan:

```text
canvas_front_next page-state cleanup
admin_back_go apperror/i18n migration
admin_front_ts business page refactors
API wrapper positiveID cleanup outside files touched by shared primitives
```

## File map

- Create: `E:/admin_go/admin_front_ts/tests/shared/table/shared-primitives-quality.test.ts`
  - Owns source guards for shared primitive `any` and contract-hiding fallback.
- Create: `E:/admin_go/admin_front_ts/src/components/Table/src/types.ts`
  - Owns `TableRow`, `TableColumn`, `TablePaginationState`, and column key helpers.
- Modify: `E:/admin_go/admin_front_ts/src/components/Table/src/index.vue`
  - Replace runtime object props and `any` casts with typed props/emits.
- Modify: `E:/admin_go/admin_front_ts/src/components/Table/src/components/ColumnSetting.vue`
  - Consume `TableColumn`, `TableColumnKey`, typed modelValue, and i18n text.
- Modify: `E:/admin_go/admin_front_ts/src/components/Search/types.ts`
  - Remove broad field index signature and keep supported field props explicit.
- Modify: `E:/admin_go/admin_front_ts/src/components/Search/src/index.vue`
  - Replace `Record<string, any>`, `value || {}`, and `as any[]` with typed helpers.
- Modify: `E:/admin_go/admin_front_ts/src/types/common.ts`
  - Replace `RemoteListFetchMethod(params: any)` with generic typed params.
- Modify: `E:/admin_go/admin_front_ts/src/i18n/locales/zh-CN.ts`
  - Add `common.actions.columnSetting`.
- Modify: `E:/admin_go/admin_front_ts/src/i18n/locales/en-US.ts`
  - Add `common.actions.columnSetting`.

---

## Task 1: Add RED source guards

**Files:**

- Create: `E:/admin_go/admin_front_ts/tests/shared/table/shared-primitives-quality.test.ts`

- [ ] **Step 1: Write the failing source guard test**

Create `tests/shared/table/shared-primitives-quality.test.ts`:

```ts
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { describe, expect, it } from 'vitest'

const read = (path: string) => readFileSync(resolve(process.cwd(), path), 'utf8')

describe('shared table/search primitive quality', () => {
  it('keeps shared primitives free of any casts', () => {
    const files = [
      'src/components/Table/src/index.vue',
      'src/components/Table/src/components/ColumnSetting.vue',
      'src/components/Search/src/index.vue',
      'src/components/Search/types.ts',
      'src/types/common.ts',
    ]

    for (const file of files) {
      const source = read(file)

      expect(source, `${file} must not use explicit any`).not.toMatch(/\bany\b/)
      expect(source, `${file} must not cast as any`).not.toContain('as any')
      expect(source, `${file} must not use Record<string, any>`).not.toContain('Record<string, any>')
    }
  })

  it('does not hide invalid parent input or empty option contracts', () => {
    const search = read('src/components/Search/src/index.vue')
    const table = read('src/components/Table/src/index.vue')
    const commonTypes = read('src/types/common.ts')

    expect(search).not.toContain('Object.assign(form, value || {})')
    expect(search).not.toContain('(field.options ?? []) as any[]')
    expect(table).not.toContain('page as any')
    expect(commonTypes).not.toContain('params: any')
  })
})
```

- [ ] **Step 2: Run the guard and verify it fails**

Run:

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/table/shared-primitives-quality.test.ts
```

Expected result before implementation:

```text
FAIL tests/shared/table/shared-primitives-quality.test.ts
src/components/Table/src/index.vue must not use explicit any
```

- [ ] **Step 3: Commit the RED guard**

Commit only the test if the project workflow requires checkpoint commits:

```powershell
cd E:\admin_go\admin_front_ts
git add tests/shared/table/shared-primitives-quality.test.ts
git commit -m "test: guard shared primitives against any fallbacks"
```

If working without commits, leave the file unstaged and continue. Do not claim completion until GREEN verification passes.

---

## Task 2: Type AppTable and ColumnSetting

**Files:**

- Create: `E:/admin_go/admin_front_ts/src/components/Table/src/types.ts`
- Modify: `E:/admin_go/admin_front_ts/src/components/Table/src/index.vue`
- Modify: `E:/admin_go/admin_front_ts/src/components/Table/src/components/ColumnSetting.vue`

- [ ] **Step 1: Add table primitive types**

Create `src/components/Table/src/types.ts`:

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

export function tableColumnKey(column: Pick<TableColumn, 'key' | 'prop'>): TableColumnKey {
  const key = column.key ?? column.prop

  if (typeof key !== 'string' || key.trim() === '') {
    throw new Error('AppTable column key or prop is required')
  }

  return key
}

export function tableColumnProp(column: Pick<TableColumn, 'key' | 'prop'>): string {
  return column.prop ?? tableColumnKey(column)
}
```

- [ ] **Step 2: Rewrite AppTable script with typed props**

Modify the `<script setup lang="ts">` block in `src/components/Table/src/index.vue` to this shape:

```vue
<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useIsMobile } from '@/hooks/useResponsive'
import { ElPagination, ElSpace, ElTable, ElTableColumn } from 'element-plus'
import { useI18n } from 'vue-i18n'
import ColumnSetting from './components/ColumnSetting.vue'
import TableActions from './components/TableActions.vue'
import {
  tableColumnKey,
  tableColumnProp,
  type TableColumn,
  type TableColumnKey,
  type TablePaginationState,
  type TableRow,
} from './types'

interface AppTableProps {
  columns: TableColumn[]
  data: TableRow[]
  loading?: boolean
  rowKey?: string
  selectable?: boolean
  rowClickSelect?: boolean
  pagination?: TablePaginationState | null
  tableProps?: Record<string, unknown>
  autoOverflowTooltip?: boolean
  showRefresh?: boolean
  showColumnSetting?: boolean
  refreshLoading?: boolean
  showIndex?: boolean
  fixedFooter?: boolean
}

const props = withDefaults(defineProps<AppTableProps>(), {
  columns: () => [],
  data: () => [],
  loading: false,
  rowKey: 'id',
  selectable: false,
  rowClickSelect: true,
  pagination: null,
  tableProps: () => ({}),
  autoOverflowTooltip: true,
  showRefresh: true,
  showColumnSetting: true,
  refreshLoading: false,
  showIndex: false,
  fixedFooter: true,
})

const emit = defineEmits<{
  refresh: []
  'selection-change': [selection: TableRow[]]
  'update:pagination': [pagination: TablePaginationState]
  'column-change': [keys: TableColumnKey[]]
}>()

const { t } = useI18n()
const selectedColumnKeys = ref<TableColumnKey[]>([])
const tableRef = ref<InstanceType<typeof ElTable> | null>(null)
const page = ref<TablePaginationState | null>(props.pagination ? { ...props.pagination } : null)
const isMobile = useIsMobile()

const getColumnKey = (column: TableColumn) => tableColumnKey(column)
const getCellValue = (row: TableRow, column: TableColumn) => row[tableColumnProp(column)]

const getColumnBindings = (column: TableColumn): Record<string, unknown> => {
  const { key, prop, label, hidden, overflowTooltip, formatter, ...rest } = column
  return { align: 'center', prop: prop ?? key, ...rest }
}

const formatCellValue = (row: TableRow, column: TableColumn, index: number) => {
  const value = getCellValue(row, column)

  if (typeof column.formatter === 'function') {
    return column.formatter(row, { property: tableColumnProp(column) }, value, index)
  }

  return value
}

watch(
  () => props.columns,
  (columns) => {
    selectedColumnKeys.value = columns
      .filter((column) => !column.hidden)
      .map((column) => getColumnKey(column))
  },
  { immediate: true }
)

watch(
  () => selectedColumnKeys.value,
  (keys) => {
    emit('column-change', keys)
  }
)

watch(
  () => props.pagination,
  (pagination) => {
    page.value = pagination ? { ...pagination } : null
  },
  { immediate: true, deep: true }
)

const visibleColumns = computed(() =>
  props.columns.filter((column) => selectedColumnKeys.value.includes(getColumnKey(column)))
)
const paginationLayout = computed(() =>
  isMobile.value ? 'total, prev, pager, next' : 'total, sizes, prev, pager, next, jumper'
)
const pageSizes = computed(() => (isMobile.value ? [10, 20] : [10, 20, 30, 40, 50]))
const mergedTableProps = computed(() =>
  props.fixedFooter ? { height: '100%', ...props.tableProps } : props.tableProps
)

const onSizeChange = (size: number) => {
  if (!page.value) {
    return
  }

  page.value = { ...page.value, page_size: size, current_page: 1 }
  emit('update:pagination', { ...page.value })
}

const onCurrentChange = (currentPage: number) => {
  if (!page.value) {
    return
  }

  page.value = { ...page.value, current_page: currentPage }
  emit('update:pagination', { ...page.value })
}

const onRowClick = (row: TableRow) => {
  if (!props.selectable || props.rowClickSelect === false) {
    return
  }

  tableRef.value?.toggleRowSelection(row)
}
</script>
```

Keep the existing template and styles, but replace the typed casts:

```vue
<ColumnSetting
  v-if="props.showColumnSetting"
  v-model="selectedColumnKeys"
  :columns="props.columns"
/>
```

and replace pagination bindings:

```vue
<ElPagination
  v-if="page"
  v-model:current-page="page.current_page"
  v-model:page-size="page.page_size"
  :layout="paginationLayout"
  :small="isMobile"
  :pager-count="isMobile ? 5 : 7"
  :page-sizes="pageSizes"
  :total="page.total"
  @size-change="onSizeChange"
  @current-change="onCurrentChange"
/>
```

- [ ] **Step 3: Rewrite ColumnSetting with typed model and i18n**

Replace `src/components/Table/src/components/ColumnSetting.vue` with:

```vue
<script setup lang="ts">
import { computed } from 'vue'
import { ElButton, ElCheckbox, ElCheckboxGroup, ElPopover } from 'element-plus'
import { Setting } from '@element-plus/icons-vue'
import { useI18n } from 'vue-i18n'
import { tableColumnKey, type TableColumn, type TableColumnKey } from '../types'

const props = defineProps<{
  columns: TableColumn[]
  modelValue: TableColumnKey[]
}>()

const emit = defineEmits<{
  'update:modelValue': [value: TableColumnKey[]]
}>()

const { t } = useI18n()

const options = computed(() =>
  props.columns.map((column) => ({
    label: column.label,
    value: tableColumnKey(column),
  }))
)

const value = computed({
  get: () => props.modelValue,
  set: (nextValue: TableColumnKey[]) => emit('update:modelValue', nextValue),
})
</script>

<template>
  <ElPopover placement="bottom" trigger="click" :width="200">
    <template #reference>
      <ElButton :icon="Setting">{{ t('common.actions.columnSetting') }}</ElButton>
    </template>
    <div style="max-height: 400px; overflow-y: auto;">
      <ElCheckboxGroup v-model="value">
        <div v-for="opt in options" :key="opt.value" style="margin-bottom: 8px;">
          <ElCheckbox :label="opt.value">
            <span :title="opt.label" style="display: inline-block; max-width: 140px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; vertical-align: middle;">
              {{ opt.label }}
            </span>
          </ElCheckbox>
        </div>
      </ElCheckboxGroup>
    </div>
  </ElPopover>
</template>

<style scoped>
.el-checkbox {
  width: 100%;
  margin-right: 0;
}
</style>
```

- [ ] **Step 4: Run the guard and typecheck for table files**

Run:

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/table/shared-primitives-quality.test.ts tests/shared/table/useTable.test.ts tests/shared/table/useCrudTable.test.ts
npx vue-tsc -b --pretty false
```

Expected after Task 2:

```text
shared-primitives-quality still fails on Search/common types
useTable/useCrudTable pass
vue-tsc may still fail on Search/common types until Task 3
```

Do not claim completion after this task.

---

## Task 3: Type Search and remote list fetch params

**Files:**

- Modify: `E:/admin_go/admin_front_ts/src/types/common.ts`
- Modify: `E:/admin_go/admin_front_ts/src/components/Search/types.ts`
- Modify: `E:/admin_go/admin_front_ts/src/components/Search/src/index.vue`

- [ ] **Step 1: Replace RemoteListFetchMethod any**

Modify `src/types/common.ts`:

```ts
export type RemoteListParams = Record<string, string | number | boolean | null | undefined>

export type RemoteListFetchMethod<
  Item = object,
  Params extends RemoteListParams = RemoteListParams,
> = {
  bivarianceHack(params: Params): Promise<RemoteListResponse<Item>>
}['bivarianceHack']
```

Keep `RequestPayload = Record<string, unknown>` unchanged because it is a request payload boundary, not an `any` escape hatch.

- [ ] **Step 2: Make Search field props explicit**

Modify `src/components/Search/types.ts` to this shape:

```ts
import type { RemoteListFetchMethod, RemoteListParams } from '@/types/common'

type SearchLabelResolver<Item extends object = object> = {
  bivarianceHack(item: Item): string
}['bivarianceHack']

export type SearchFormValue = string | number | boolean | string[] | number[] | null | undefined
export type SearchFormModel = Record<string, SearchFormValue>

interface SearchFieldBase {
  key: string
  label?: string
  placeholder?: string
  width?: number | string
  disabled?: boolean
  clearable?: boolean
}

interface InputSearchField extends SearchFieldBase {
  type: 'input'
}

interface SelectSearchField<Option = unknown> extends SearchFieldBase {
  type: 'select-v2'
  options: Option[]
}

interface CascaderSearchField<Option = unknown> extends SearchFieldBase {
  type: 'cascader'
  options: Option[]
  cascaderProps?: Record<string, unknown>
}

interface DateRangeSearchField extends SearchFieldBase {
  type: 'date-range'
}

interface DateSearchField extends SearchFieldBase {
  type: 'date'
}

interface SlotSearchField extends SearchFieldBase {
  type: 'slot'
}

export interface RemoteSelectSearchField<
  Item extends object = object,
  Params extends RemoteListParams = RemoteListParams,
> extends SearchFieldBase {
  type: 'remote-select'
  fetchMethod: RemoteListFetchMethod<Item, Params>
  labelField?: string | SearchLabelResolver<Item>
  valueField?: string
  keywordField?: string
}

export type SearchField<
  Option = unknown,
  Item extends object = object,
  Params extends RemoteListParams = RemoteListParams,
> =
  | InputSearchField
  | SelectSearchField<Option>
  | CascaderSearchField<Option>
  | DateRangeSearchField
  | DateSearchField
  | SlotSearchField
  | RemoteSelectSearchField<Item, Params>
```

- [ ] **Step 3: Replace Search runtime any and fallback**

In `src/components/Search/src/index.vue`, use typed form state:

```ts
const form = reactive<SearchFormModel>({ ...props.modelValue })
```

Add a helper:

```ts
function assignSearchForm(value: SearchFormModel) {
  for (const key of Object.keys(form)) {
    if (!Object.prototype.hasOwnProperty.call(value, key)) {
      delete form[key]
    }
  }

  Object.assign(form, value)
}
```

Replace the watcher with:

```ts
watch(
  () => props.modelValue,
  (value) => {
    assignSearchForm(value)
  },
  { deep: true }
)
```

Replace `getFieldBindings` return type:

```ts
const getFieldBindings = (field: SearchField): Record<string, unknown> => {
  const {
    key,
    type,
    label,
    placeholder,
    width,
    options,
    cascaderProps,
    fetchMethod,
    labelField,
    valueField,
    keywordField,
    ...rest
  } = field

  return rest
}
```

Replace template option casts:

```vue
<el-select-v2
  v-model="form[field.key]"
  :options="field.options"
  filterable
  clearable
  :placeholder="field.placeholder"
  :style="{ width: resolveWidth(field.width, 150) }"
  v-bind="getFieldBindings(field)"
/>
```

and:

```vue
<el-cascader
  v-model="form[field.key]"
  :options="field.options"
  :props="field.cascaderProps"
  clearable
  filterable
  :placeholder="field.placeholder"
  :style="{ width: resolveWidth(field.width, 150) }"
  v-bind="getFieldBindings(field)"
/>
```

Do not replace `field.labelField || 'label'`, `field.valueField || 'value'`, or `field.keywordField || 'keyword'` in this task. Those are component-owned defaults for `RemoteSelect`, not API fallback.

- [ ] **Step 4: Run targeted tests**

Run:

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/table/shared-primitives-quality.test.ts tests/shared/table/remote-select-contract.test.ts
```

Expected:

```text
PASS tests/shared/table/shared-primitives-quality.test.ts
PASS tests/shared/table/remote-select-contract.test.ts
```

---

## Task 4: Add i18n keys for touched visible text

**Files:**

- Modify: `E:/admin_go/admin_front_ts/src/i18n/locales/zh-CN.ts`
- Modify: `E:/admin_go/admin_front_ts/src/i18n/locales/en-US.ts`

- [ ] **Step 1: Add Chinese key**

In `src/i18n/locales/zh-CN.ts`, inside `common.actions`, add:

```ts
columnSetting: '列设置',
```

If `common.actions` is not directly visible near the top, use `rg -n "actions:" src/i18n/locales/zh-CN.ts` and add it to the existing common actions object. Do not create a second `common` object.

- [ ] **Step 2: Add English key**

In `src/i18n/locales/en-US.ts`, inside `common.actions`, add:

```ts
columnSetting: 'Column settings',
```

- [ ] **Step 3: Verify i18n alignment**

Run:

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/i18n/literal-i18n-keys.test.ts
```

Expected:

```text
PASS tests/shared/i18n/literal-i18n-keys.test.ts
```

---

## Task 5: Full first-slice verification

**Files:**

- Verify only; no source changes.

- [ ] **Step 1: Run targeted frontend tests**

Run:

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/table/shared-primitives-quality.test.ts tests/shared/table/useTable.test.ts tests/shared/table/useCrudTable.test.ts tests/shared/table/remote-select-contract.test.ts tests/shared/i18n/literal-i18n-keys.test.ts
```

Expected:

```text
Test Files 5 passed
```

- [ ] **Step 2: Run Vue typecheck**

Run:

```powershell
cd E:\admin_go\admin_front_ts
npx vue-tsc -b --pretty false
```

Expected:

```text
exit code 0
```

- [ ] **Step 3: Run root governance checks**

Run:

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected:

```text
PASS: no blocking governance violations found.
```

- [ ] **Step 4: Report without overclaiming**

Final report must include:

```text
Outcome:
Changed files:
Key evidence:
Verification:
Known risks:
Next step:
```

Do not say full frontend build, backend tests, Canvas tests, or smoke passed unless those commands were actually run.

---

## Self-review checklist

- [ ] Every changed runtime file has a matching test or typecheck gate.
- [ ] The plan does not modify backend or Canvas code.
- [ ] The plan does not introduce a second Superpowers location inside subrepos.
- [ ] No step asks the worker to “clean up any remaining issues” without exact files and commands.
- [ ] No completed status is claimed until RED guard, GREEN implementation, i18n test, `vue-tsc`, `git diff --check`, and root governance all pass.
