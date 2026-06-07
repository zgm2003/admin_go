# Admin User Status Contract Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:test-driven-development for code behavior changes and superpowers:verification-before-completion before reporting completion. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the Admin user status owner decision by making `PATCH /api/admin/v1/users/:id/status` an active Admin Vue frontend call.

**Architecture:** Keep the Go backend route/service unchanged. Add one dedicated `UsersListApi.changeStatus` wrapper and wire the existing user list page to the existing `useCrudTable.toggleStatus` flow. Do not hide status mutation behind batch-edit or profile update.

**Tech Stack:** Vue 3 `<script setup lang="ts">`, TypeScript, Vite/Vitest, Element Plus, Go/Gin route evidence, PowerShell generated docs/fact guards.

---

### Task 1: Confirm route ownership

**Files:**
- Read: `admin_back_go/internal/module/user/transport/admin/route.go`
- Read: `admin_back_go/internal/module/user/transport/admin/handler.go`
- Read: `admin_back_go/internal/module/user/service.go`
- Read: `admin_back_go/internal/bootstrap/route_meta.go`
- Read: `admin_front_ts/src/api/user/users.ts`
- Read: `admin_front_ts/src/views/Main/user/userManager/components/UserList/index.vue`

- [ ] **Step 1: Confirm backend route exists**

Expected source facts:

```text
users.PATCH("/:id/status", handler.ChangeStatus)
handler.ChangeStatus binds { status } and calls service.ChangeStatus(ctx, id, status)
service.ChangeStatus validates id and enum.IsCommonStatus(status)
route_meta.go maps PATCH /api/admin/v1/users/:id/status to user_userManager_edit
```

- [ ] **Step 2: Confirm frontend gap exists**

Expected source facts before implementation:

```text
UsersListApi has update and batchEdit, but no changeStatus wrapper.
UserList/index.vue has UserListItem.status available but no status column.
UserList/index.vue does not destructure useCrudTable.toggleStatus.
```

### Task 2: Red guard test

**Files:**
- Modify: `admin_front_ts/tests/shared/user/user-list.test.ts`

- [ ] **Step 1: Add failing source guards**

Add a test:

```ts
it('uses the dedicated Go REST status route for user enable and disable', () => {
  const apiSource = readFrontendSource('src/api/user/users.ts')
  const pageSource = readUserListSource()

  expect(apiSource).toContain('type UserStatusBody = { status: number }')
  expect(apiSource).toContain('changeStatus: (params: { id: Id; status: number }) => {')
  expect(apiSource).toContain('request.patch<void, UserStatusBody>(`${ADMIN_API_PREFIX}/users/${ids[0]}/status`, body)')
  expect(apiSource).not.toContain('batchEdit: (params: UserBatchEditParams & { status')

  expect(pageSource).toContain("import { CommonEnum } from '@/enums'")
  expect(pageSource).toContain('toggleStatus,')
  expect(pageSource).toContain("{ key: 'status', label: t('user.table.status'), width: 110 }")
  expect(pageSource).toContain('<template #cell-status="{ row }">')
  expect(pageSource).toContain("row.status === CommonEnum.YES ? 'success' : 'danger'")
  expect(pageSource).toContain("userStore.can('user_userManager_edit') && row.status === CommonEnum.NO")
  expect(pageSource).toContain('@click="toggleStatus(row, CommonEnum.YES)"')
  expect(pageSource).toContain("userStore.can('user_userManager_edit') && row.status === CommonEnum.YES")
  expect(pageSource).toContain('@click="toggleStatus(row, CommonEnum.NO)"')
})
```

- [ ] **Step 2: Run RED**

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/user/user-list.test.ts
```

Expected before implementation:

```text
FAIL because UsersListApi.changeStatus and UserList status column/actions are missing.
```

### Task 3: Minimal API/type implementation

**Files:**
- Modify: `admin_front_ts/src/api/user/users.ts`
- Modify: `admin_front_ts/src/types/user.ts`

- [ ] **Step 1: Add status body and wrapper**

In `users.ts`, add:

```ts
type UserStatusBody = { status: number }
```

Then add to `UsersListApi`:

```ts
changeStatus: (params: { id: Id; status: number }) => {
  const ids = normalizePositiveIDs(params.id, 'user')
  const body: UserStatusBody = { status: params.status }
  return request.patch<void, UserStatusBody>(`${ADMIN_API_PREFIX}/users/${ids[0]}/status`, body)
},
```

- [ ] **Step 2: Add i18n-backed status table key**

Add `status: '状态'` / `status: 'Status'` under `user.table` in:

```text
admin_front_ts/src/i18n/locales/zh-CN.ts
admin_front_ts/src/i18n/locales/en-US.ts
```

No new visible hard-coded Chinese is allowed.

### Task 4: Minimal page wiring

**Files:**
- Modify: `admin_front_ts/src/views/Main/user/userManager/components/UserList/index.vue`

- [ ] **Step 1: Import common status enum**

Add:

```ts
import { CommonEnum } from '@/enums'
```

- [ ] **Step 2: Destructure toggleStatus**

Add `toggleStatus` to the `useCrudTable` destructuring.

- [ ] **Step 3: Add status column and cell**

Add the status column:

```ts
{ key: 'status', label: t('user.table.status'), width: 110 },
```

Add the cell slot:

```vue
<template #cell-status="{ row }">
  <el-tag :type="row.status === CommonEnum.YES ? 'success' : 'danger'">
    {{ row.status === CommonEnum.YES ? t('common.status.enabled') : t('common.status.disabled') }}
  </el-tag>
</template>
```

- [ ] **Step 4: Add enable/disable actions under edit permission**

Add before delete:

```vue
<el-button
  v-if="userStore.can('user_userManager_edit') && row.status === CommonEnum.NO"
  type="warning"
  text
  @click="toggleStatus(row, CommonEnum.YES)"
>
  {{ t('common.actions.enable') }}
</el-button>
<el-button
  v-if="userStore.can('user_userManager_edit') && row.status === CommonEnum.YES"
  type="warning"
  text
  @click="toggleStatus(row, CommonEnum.NO)"
>
  {{ t('common.actions.disable') }}
</el-button>
```

### Task 5: Verify green and regenerate docs

**Files:**
- Modify generated: `docs/knowledge/frontend-api-inventory-2026-06-07.md`
- Modify generated: `docs/knowledge/frontend-backend-api-drift-2026-06-07.md`
- Modify generated: `docs/knowledge/api-source-only-route-review-2026-06-07.md`
- Modify generated: `docs/knowledge/full-stack-module-map-2026-06-07.md`

- [ ] **Step 1: Run target frontend checks**

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/user/user-list.test.ts
npm run typecheck
```

- [ ] **Step 2: Run exporters in order**

```powershell
cd E:\admin_go
powershell -ExecutionPolicy Bypass -File .\scripts\export-frontend-api-inventory.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\export-frontend-backend-api-drift.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\export-api-source-only-route-review.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\export-full-stack-module-map.ps1 -OutputDate 2026-06-07
```

Expected:

```text
frontend exact backend API calls increases from 256 to 257.
backend source-only rows decreases from 21 to 20.
owner-decision-required routes decreases from 2 to 1.
PATCH /api/admin/v1/users/:id/status is absent from source-only review.
```

### Task 6: Knowledge/status/fact guard sync

**Files:**
- Create: `docs/knowledge/admin-user-status-contract-review-2026-06-07.md`
- Modify: `docs/knowledge/README.md`
- Modify: `docs/knowledge/current-runtime-knowledge.md`
- Modify: `docs/knowledge/runtime-source-map.md`
- Modify: `docs/status/current-status.md`
- Modify: `docs/status/known-issues.md`
- Modify: `scripts/check-runtime-doc-facts.ps1`

- [ ] **Step 1: Add review artifact**

Record:

```text
Admin user status is an active frontend gap now closed.
Frontend calls PATCH /api/admin/v1/users/:id/status.
Status route stays under user_userManager_edit.
Remaining API-DRIFT-001 owner decision is POST /api/admin/v1/ai-agents/:id/test.
```

- [ ] **Step 2: Update fact guard**

Require:

```text
frontend inventory contains PATCH /api/admin/v1/users/:id/status
source-only review does not contain /api/admin/v1/users/:id/status
owner-decision count is 1
full-stack module map owner-decision count is 1
new review artifact is indexed from README/current-runtime/source-map/status
```

- [ ] **Step 3: Root verification**

```powershell
cd E:\admin_go
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1 -LiveSchema
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```
