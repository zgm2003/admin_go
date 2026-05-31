# RESTful API Naming Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate Go/Vue RESTful API naming toward the standard without breaking existing runtime behavior.

**Architecture:** Keep HTTP paths stable first, then standardize code-facing names. The public migration choke point is `useCrudTable`: it must accept standard names before any wrapper is migrated. Backend `/init` page dictionaries get `/page-init` aliases before old `/init` paths are removed in a later deprecation slice.

**Tech Stack:** Go 1.26 + Gin + GORM; Vue 3 + TypeScript + Element Plus + vue-i18n; Vitest + Go unit/architecture tests + root governance checker.

---

## Linus 三问

1. 这是个真问题吗？是。审查已经证明 HTTP route 基本没烂，但前端 wrapper 和 `/init` 字典路由会让新模块继续复制旧动作式命名。
2. 有更简单的做法吗？有。先改公共 hook 兼容标准名，再一块一块迁 wrapper；不要全仓替换。
3. 会破坏已有用户空间吗？不能。`/init`、`add/edit/del/status` 旧名在迁移期保留 alias；每个模块先测试再切调用方。

## Current Evidence Snapshot

审查报告：`docs/superpowers/reviews/2026-05-31-restful-api-naming-audit-review.md`。

| Area | Current fact |
| --- | --- |
| Backend route registrations scanned | 260 |
| Backend `/list /add /edit /del` route violations | 0 |
| Frontend request URLs using `/list /add /edit /del` | 0 |
| Backend non-bootstrap `/init` page dictionary routes | 12 |
| Backend `/page-init` routes with `Init`-style handler names | 8 |
| Backend single delete routes with generic `Delete` handler | 8 |
| Frontend exact legacy wrapper methods | 92 (`init` 25, `add` 18, `edit` 17, `del` 21, `status` 11) |
| Direct frontend call sites to those legacy methods | 59 |
| Structural blocker | `admin_front_ts/src/hooks/useCrudTable.ts` still encodes `api.del` and `api.status` |

## Scope Gates

- Root docs/spec/review/plan live under `E:/admin_go/docs/superpowers`。
- Runtime repos are separate worktrees: `E:/admin_go/admin_back_go` and `E:/admin_go/admin_front_ts`。
- This plan does not authorize a broad rename. Each runtime batch must start from a clean known state for the files it touches.
- Keep these compatibility aliases until a dedicated removal plan proves zero callers:
  - frontend: `init/add/edit/del/status`
  - backend: old non-bootstrap `GET /init` routes
- `GET /api/admin/v1/users/init` is bootstrap. Do not convert it to `pageInit()`.
- Command routes stay command routes when they are real business commands, for example login/logout/send-code/test/cancel/reindex/export.

## File Structure Map

### Root docs

- Read: `docs/superpowers/specs/2026-05-30-restful-api-naming-audit-design.md`
- Read: `docs/superpowers/reviews/2026-05-31-restful-api-naming-audit-review.md`
- Modify after runtime changes: `docs/contracts/admin-api-v1.md`
- Modify if status/smoke facts change: `docs/status/current-status.md`
- Modify if smoke coverage changes: `docs/testing/smoke-matrix.md`

### Frontend public hook

- Modify: `admin_front_ts/src/hooks/useCrudTable.ts`
- Test: `admin_front_ts/tests/shared/table/useCrudTable.test.ts`

### Frontend first active wrapper batch

- Modify: `admin_front_ts/src/api/ai/billingRules.ts`
- Modify: `admin_front_ts/src/views/Main/ai/agents/components/AgentBillingDialog/index.vue`
- Test: `admin_front_ts/tests/shared/ai/ai-billing-rule-api.test.ts`

### Frontend wallet naming batch

- Modify: `admin_front_ts/src/api/wallet/index.ts`
- Modify: `admin_front_ts/src/views/Main/payment/ledger/index.vue`
- Modify: `admin_front_ts/src/views/Main/payment/wallets/index.vue`
- Modify: `admin_front_ts/src/views/Main/personal/wallet/index.vue`
- Test: `admin_front_ts/tests/shared/wallet/wallet-api.test.ts`
- Test: `admin_front_ts/tests/shared/wallet/wallet-pages.test.ts`
- Test: `admin_front_ts/tests/shared/payment-wallet-billing-redesign.test.ts`

### Backend route alias batch

- Create: `admin_back_go/internal/architecture/restful_api_naming_test.go`
- Modify: `admin_back_go/internal/module/auth_platform/transport/admin/route.go`
- Modify: `admin_back_go/internal/module/crontask/transport/admin/route.go`
- Modify: `admin_back_go/internal/module/notification/transport/admin/route.go`
- Modify: `admin_back_go/internal/module/notification/transport/admin/task_route.go`
- Modify: `admin_back_go/internal/module/operationlog/transport/admin/route.go`
- Modify: `admin_back_go/internal/module/permission/transport/admin/route.go`
- Modify: `admin_back_go/internal/module/role/transport/admin/route.go`
- Modify: `admin_back_go/internal/module/systemlog/transport/admin/route.go`
- Modify: `admin_back_go/internal/module/systemsetting/transport/admin/route.go`
- Modify: `admin_back_go/internal/module/uploadconfig/transport/admin/route.go`
- Test: `admin_back_go/internal/architecture/restful_api_naming_test.go`
- Test: `admin_back_go/internal/server/router_test.go` if router snapshot expects explicit routes

### Backend touched handler cleanup

- Modify: `admin_back_go/internal/module/ai/billing/transport/admin/handler.go`
- Modify: `admin_back_go/internal/module/ai/billing/transport/admin/route.go`
- Modify: `admin_back_go/internal/module/ai/billing/transport/admin/handler_test.go`
- Test: `admin_back_go/internal/module/ai/billing/transport/admin/handler_test.go`

---

## Task 0: Baseline and branch safety

**Files:** none.

- [ ] **Step 1: Check root repo status**

Run:

```powershell
cd E:\admin_go
git status --short
```

Expected decision:

```text
If only docs/spec/review/plan files from this RESTful naming work are dirty, continue.
If unrelated files are dirty, do not overwrite them; write down the exact file list in the handoff before runtime work.
```

- [ ] **Step 2: Check backend repo status**

Run:

```powershell
cd E:\admin_go\admin_back_go
git status --short
```

Expected decision:

```text
If backend has unrelated WIP, do not start Task 4 or Task 5 in this worktree.
If backend is clean or only has files from the current task, continue.
```

- [ ] **Step 3: Check frontend repo status**

Run:

```powershell
cd E:\admin_go\admin_front_ts
git status --short
```

Expected decision:

```text
If frontend has unrelated WIP, do not start Task 1 through Task 3 in this worktree.
If frontend is clean or only has files from the current task, continue.
```

- [ ] **Step 4: Re-read the governing docs**

Run:

```powershell
cd E:\admin_go
Get-Content -Raw .\docs\superpowers\specs\2026-05-30-restful-api-naming-audit-design.md
Get-Content -Raw .\docs\superpowers\reviews\2026-05-31-restful-api-naming-audit-review.md
Get-Content -Raw .\docs\contracts\admin-api-v1.md
```

Expected: the implementer can state the standard names without guessing:

```text
Backend routes: REST resources, no /list /add /edit /del.
Page dictionary route: GET /api/admin/v1/<resources>/page-init.
Bootstrap init exception: GET /api/admin/v1/users/init.
Go names: List Detail Create Update ChangeStatus DeleteOne DeleteBatch PageInit.
Frontend names: list detail create update changeStatus deleteOne deleteBatch pageInit.
```

- [ ] **Step 5: Commit or stash nothing automatically**

Do not run `git stash`, `git reset`, or cleanup commands. This workspace commonly has another Codex writing code; preserving user space matters more than a clean-looking tree.

---

## Task 1: Extend `useCrudTable` to support standard CRUD method names

**Files:**

- Modify: `admin_front_ts/src/hooks/useCrudTable.ts`
- Modify: `admin_front_ts/tests/shared/table/useCrudTable.test.ts`

### Target behavior

`useCrudTable` accepts both standard and legacy methods:

```ts
preferred: deleteOne / deleteBatch / changeStatus
legacy:    del / status
```

Call preference:

```text
confirmDel(row)  -> deleteOne({ id }) first, fallback del({ id })
batchDel()       -> deleteBatch({ ids }) first, fallback del({ id: ids })
toggleStatus()   -> changeStatus({ id, status }) first, fallback status({ id, status })
```

- [ ] **Step 1: Add failing test for standard names**

Edit `admin_front_ts/tests/shared/table/useCrudTable.test.ts` and insert this test before the legacy test:

```ts
  it('prefers standard deleteOne, deleteBatch, and changeStatus methods', async () => {
    const list = vi.fn().mockResolvedValue({
      list: [{ id: 1, status: 1 }],
      page: { current_page: 1, page_size: 20, total: 1 },
    })
    const deleteOne = vi.fn().mockResolvedValue(undefined)
    const deleteBatch = vi.fn().mockResolvedValue(undefined)
    const changeStatus = vi.fn().mockResolvedValue(undefined)
    const del = vi.fn().mockResolvedValue(undefined)
    const status = vi.fn().mockResolvedValue(undefined)
    confirm.mockResolvedValue(undefined)

    const table = useCrudTable({
      api: { list, deleteOne, deleteBatch, changeStatus, del, status },
      searchForm: ref({ keyword: 'demo' }),
    })

    table.onSelectionChange([{ id: 1, status: 1 }])
    await table.confirmDel({ id: 1, status: 1 })
    await table.batchDel()
    await table.toggleStatus({ id: 1, status: 1 }, 2)

    expect(deleteOne).toHaveBeenCalledWith({ id: 1 })
    expect(deleteBatch).toHaveBeenCalledWith({ ids: [1] })
    expect(changeStatus).toHaveBeenCalledWith({ id: 1, status: 2 })
    expect(del).not.toHaveBeenCalled()
    expect(status).not.toHaveBeenCalled()
    expect(success).toHaveBeenCalledTimes(3)
  })
```

- [ ] **Step 2: Verify RED**

Run:

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/table/useCrudTable.test.ts
```

Expected: fail with TypeScript/runtime evidence that `deleteOne`, `deleteBatch`, or `changeStatus` is not supported by `CrudApiModule` or not called.

- [ ] **Step 3: Patch `CrudApiModule` type**

In `admin_front_ts/src/hooks/useCrudTable.ts`, replace the API interface with:

```ts
interface CrudApiModule<
  T extends Identifiable,
  P extends PaginationParams = PaginationParams,
> extends TableApiModule<T, P> {
  deleteOne?(params: { id: Id }): Promise<unknown>
  deleteBatch?(params: { ids: Id[] }): Promise<unknown>
  changeStatus?(params: { id: Id; status: number }): Promise<unknown>
  del?(params: { id: Id | Id[] }): Promise<unknown>
  status?(params: { id: Id; status: number }): Promise<unknown>
}
```

- [ ] **Step 4: Patch delete/status dispatch**

In `admin_front_ts/src/hooks/useCrudTable.ts`, add helper functions inside `useCrudTable()` after `onSearch()`:

```ts
  function hasDeleteOne() {
    return Boolean(api.deleteOne || api.del)
  }

  function hasDeleteBatch() {
    return Boolean(api.deleteBatch || api.del)
  }

  function hasChangeStatus() {
    return Boolean(api.changeStatus || api.status)
  }

  async function deleteOne(id: Id) {
    if (api.deleteOne) {
      await api.deleteOne({ id })
      return
    }
    await api.del?.({ id })
  }

  async function deleteBatch(ids: Id[]) {
    if (api.deleteBatch) {
      await api.deleteBatch({ ids })
      return
    }
    await api.del?.({ id: ids })
  }

  async function changeStatus(id: Id, status: number) {
    if (api.changeStatus) {
      await api.changeStatus({ id, status })
      return
    }
    await api.status?.({ id, status })
  }
```

Then change the guards and calls:

```ts
    if (!hasDeleteOne()) {
      console.warn('useCrudTable: deleteOne/del api not provided')
      return
    }
```

```ts
    await deleteOne(row.id)
```

```ts
    if (!hasDeleteBatch()) {
      console.warn('useCrudTable: deleteBatch/del api not provided')
      return
    }
```

```ts
    await deleteBatch(table.selectedIds.value)
```

```ts
    if (!hasChangeStatus()) {
      console.warn('useCrudTable: changeStatus/status api not provided')
      return
    }
```

```ts
    await changeStatus(row.id, newStatus)
```

- [ ] **Step 5: Verify GREEN for hook tests**

Run:

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/table/useCrudTable.test.ts
```

Expected: pass.

- [ ] **Step 6: Run frontend type/build check for public hook change**

Run:

```powershell
cd E:\admin_go\admin_front_ts
npm run build:check
```

Expected: pass. If this hits Windows/Vitest worker instability, do not hide it; report the exact error and rerun only after process pressure is reduced.

---

## Task 2: Migrate `AiBillingRuleApi` wrapper and its direct dialog calls

**Files:**

- Modify: `admin_front_ts/src/api/ai/billingRules.ts`
- Modify: `admin_front_ts/src/views/Main/ai/agents/components/AgentBillingDialog/index.vue`
- Modify: `admin_front_ts/tests/shared/ai/ai-billing-rule-api.test.ts`

### Target behavior

Expose standard methods and keep temporary aliases:

```ts
standard: pageInit / create / update / changeStatus / deleteOne
legacy aliases: init / add / edit / status / del
```

Direct page calls switch to standard names.

- [ ] **Step 1: Update the API contract test first**

In `admin_front_ts/tests/shared/ai/ai-billing-rule-api.test.ts`, replace the old mutation-name expectations in `exposes the planned billing rule scenes, units, and mutations` with:

```ts
    expect(source).toContain('const pageInit = () => request.get<AiBillingRulePageInitResponse>')
    expect(source).toContain('const create = (params: AiBillingRuleMutationParams)')
    expect(source).toContain('const update = (params: AiBillingRuleMutationParams)')
    expect(source).toContain('const changeStatus = (params: { id: Id; status: number })')
    expect(source).toContain('const deleteOne = (params: { id: Id })')
    expect(source).toContain('pageInit,')
    expect(source).toContain('create,')
    expect(source).toContain('update,')
    expect(source).toContain('changeStatus,')
    expect(source).toContain('deleteOne,')
    expect(source).toContain('init: pageInit')
    expect(source).toContain('add: create')
    expect(source).toContain('edit: update')
    expect(source).toContain('status: changeStatus')
    expect(source).toContain('del: deleteOne')
```

Add this assertion to the dialog test block:

```ts
    expect(dialog).toContain('AiBillingRuleApi.pageInit()')
    expect(dialog).toContain('AiBillingRuleApi.create(payload)')
    expect(dialog).toContain('AiBillingRuleApi.update(payload)')
    expect(dialog).toContain('AiBillingRuleApi.changeStatus({ id: row.id, status: nextStatus })')
    expect(dialog).toContain('AiBillingRuleApi.deleteOne({ id: row.id })')
    expect(dialog).not.toContain('AiBillingRuleApi.init()')
    expect(dialog).not.toContain('AiBillingRuleApi.add(payload)')
    expect(dialog).not.toContain('AiBillingRuleApi.edit(payload)')
    expect(dialog).not.toContain('AiBillingRuleApi.status({ id: row.id')
    expect(dialog).not.toContain('AiBillingRuleApi.del({ id: row.id })')
```

- [ ] **Step 2: Verify RED**

Run:

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/ai/ai-billing-rule-api.test.ts
```

Expected: fail because the wrapper and dialog still use `init/add/edit/status/del` directly.

- [ ] **Step 3: Refactor the wrapper with stable function constants**

Replace the `export const AiBillingRuleApi = { ... }` object in `admin_front_ts/src/api/ai/billingRules.ts` with:

```ts
const pageInit = () => request.get<AiBillingRulePageInitResponse>(`${ADMIN_API_PREFIX}/ai-billing-rules/page-init`)
const list = () => request.get<PaginatedResponse<AiBillingRuleItem>>(`${ADMIN_API_PREFIX}/ai-billing-rules`, { params: { current_page: 1, page_size: 50 } })
const create = (params: AiBillingRuleMutationParams) => request.post<{ id: number }, AiBillingRuleCreateBody>(`${ADMIN_API_PREFIX}/ai-billing-rules`, createBody(params))
const update = (params: AiBillingRuleMutationParams) => request.put<void, AiBillingRuleUpdateBody>(`${ADMIN_API_PREFIX}/ai-billing-rules/${positiveID(params.id ?? 0, 'AI billing rule id')}`, updateBody(params))
const changeStatus = (params: { id: Id; status: number }) => request.patch<void, { status: number }>(`${ADMIN_API_PREFIX}/ai-billing-rules/${positiveID(params.id, 'AI billing rule id')}/status`, { status: params.status })
const deleteOne = (params: { id: Id }) => request.delete<void>(`${ADMIN_API_PREFIX}/ai-billing-rules/${positiveID(params.id, 'AI billing rule id')}`)

export const AiBillingRuleApi = {
  pageInit,
  list,
  create,
  update,
  changeStatus,
  deleteOne,

  // Temporary aliases for existing callers during RESTful naming migration.
  init: pageInit,
  add: create,
  edit: update,
  status: changeStatus,
  del: deleteOne,
}
```

- [ ] **Step 4: Switch direct dialog calls to standard names**

In `admin_front_ts/src/views/Main/ai/agents/components/AgentBillingDialog/index.vue`, make these exact call changes:

```ts
AiBillingRuleApi.init()        -> AiBillingRuleApi.pageInit()
AiBillingRuleApi.add(payload)  -> AiBillingRuleApi.create(payload)
AiBillingRuleApi.edit(payload) -> AiBillingRuleApi.update(payload)
AiBillingRuleApi.status(...)   -> AiBillingRuleApi.changeStatus(...)
AiBillingRuleApi.del(...)      -> AiBillingRuleApi.deleteOne(...)
```

The intended changed blocks are:

```ts
    const [initData, listData] = await Promise.all([
      AiBillingRuleApi.pageInit(),
      AiBillingRuleApi.list(),
    ])
```

```ts
    if (dialogMode.value === 'add') {
      await AiBillingRuleApi.create(payload)
    } else {
      await AiBillingRuleApi.update(payload)
    }
```

```ts
  await AiBillingRuleApi.changeStatus({ id: row.id, status: nextStatus })
```

```ts
  await AiBillingRuleApi.deleteOne({ id: row.id })
```

- [ ] **Step 5: Verify GREEN for AI billing wrapper**

Run:

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/ai/ai-billing-rule-api.test.ts
```

Expected: pass.

- [ ] **Step 6: Verify hook + AI billing together**

Run:

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/table/useCrudTable.test.ts tests/shared/ai/ai-billing-rule-api.test.ts
npm run build:check
```

Expected: pass.

---

## Task 3: Clean wallet page-init naming without changing wallet URLs

**Files:**

- Modify: `admin_front_ts/src/api/wallet/index.ts`
- Modify: `admin_front_ts/src/views/Main/payment/ledger/index.vue`
- Modify: `admin_front_ts/src/views/Main/payment/wallets/index.vue`
- Modify: `admin_front_ts/src/views/Main/personal/wallet/index.vue`
- Modify: `admin_front_ts/tests/shared/wallet/wallet-api.test.ts`
- Modify: `admin_front_ts/tests/shared/wallet/wallet-pages.test.ts`

### Target behavior

Keep the active HTTP URLs:

```text
GET /api/admin/v1/payment/wallets/page-init
GET /api/admin/v1/payment/wallets
GET /api/admin/v1/payment/ledger/page-init
GET /api/admin/v1/payment/ledger
GET /api/admin/v1/wallet/summary
GET /api/admin/v1/wallet/transactions
```

Rename code-facing wallet methods:

```ts
usersInit  -> walletUsersPageInit alias kept
users      -> walletUsersList alias kept
ledgerInit -> ledgerPageInit alias kept
ledger     -> ledgerList alias kept
```

- [ ] **Step 1: Update wallet API test first**

Add these expectations to `admin_front_ts/tests/shared/wallet/wallet-api.test.ts`:

```ts
    expect(source).toContain('const walletUsersPageInit = () => request.get<WalletUsersPageInitResponse>')
    expect(source).toContain('const walletUsersList = (params: WalletUserListParams)')
    expect(source).toContain('const ledgerPageInit = () => request.get<WalletLedgerPageInitResponse>')
    expect(source).toContain('const ledgerList = (params: WalletTransactionListParams)')
    expect(source).toContain('walletUsersPageInit,')
    expect(source).toContain('walletUsersList,')
    expect(source).toContain('ledgerPageInit,')
    expect(source).toContain('ledgerList,')
    expect(source).toContain('usersInit: walletUsersPageInit')
    expect(source).toContain('users: walletUsersList')
    expect(source).toContain('ledgerInit: ledgerPageInit')
    expect(source).toContain('ledger: ledgerList')
```

- [ ] **Step 2: Update wallet page test first**

Add these expectations to `admin_front_ts/tests/shared/wallet/wallet-pages.test.ts`:

```ts
    const ledgerPage = read('src/views/Main/payment/ledger/index.vue')
    const walletsPage = read('src/views/Main/payment/wallets/index.vue')
    const personalWalletPage = read('src/views/Main/personal/wallet/index.vue')

    expect(ledgerPage).toContain('WalletApi.ledgerList')
    expect(ledgerPage).toContain('WalletApi.ledgerPageInit()')
    expect(ledgerPage).not.toContain('WalletApi.ledgerInit()')
    expect(walletsPage).toContain('WalletApi.walletUsersList')
    expect(walletsPage).toContain('WalletApi.walletUsersPageInit()')
    expect(walletsPage).not.toContain('WalletApi.usersInit()')
    expect(personalWalletPage).toContain('WalletApi.transactions')
```

- [ ] **Step 3: Verify RED**

Run:

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/wallet/wallet-api.test.ts tests/shared/wallet/wallet-pages.test.ts
```

Expected: fail because wallet API and pages still use `usersInit/users/ledgerInit/ledger`.

- [ ] **Step 4: Refactor wallet wrapper with standard names and aliases**

In `admin_front_ts/src/api/wallet/index.ts`, define functions before the export object:

```ts
const summary = () => request.get<WalletSummaryResponse>(`${ADMIN_API_PREFIX}/wallet/summary`)
const transactions = (params: WalletTransactionListParams) => request.get<PaginatedResponse<WalletTransactionItem>>(`${ADMIN_API_PREFIX}/wallet/transactions`, { params })
const walletUsersPageInit = () => request.get<WalletUsersPageInitResponse>(`${ADMIN_API_PREFIX}/payment/wallets/page-init`)
const walletUsersList = (params: WalletUserListParams) => request.get<PaginatedResponse<WalletUserItem>>(`${ADMIN_API_PREFIX}/payment/wallets`, { params })
const ledgerPageInit = () => request.get<WalletLedgerPageInitResponse>(`${ADMIN_API_PREFIX}/payment/ledger/page-init`)
const ledgerList = (params: WalletTransactionListParams) => request.get<PaginatedResponse<WalletTransactionItem>>(`${ADMIN_API_PREFIX}/payment/ledger`, { params })

export const WalletApi = {
  summary,
  transactions,
  walletUsersPageInit,
  walletUsersList,
  ledgerPageInit,
  ledgerList,

  // Temporary aliases for existing callers during RESTful naming migration.
  usersInit: walletUsersPageInit,
  users: walletUsersList,
  ledgerInit: ledgerPageInit,
  ledger: ledgerList,
}
```

- [ ] **Step 5: Switch wallet page calls**

In `admin_front_ts/src/views/Main/payment/ledger/index.vue`:

```ts
const ledgerApi = { list: WalletApi.ledgerList }
```

```ts
  const result = await WalletApi.ledgerPageInit()
```

In `admin_front_ts/src/views/Main/payment/wallets/index.vue`:

```ts
const walletUserApi = { list: WalletApi.walletUsersList }
```

```ts
  await WalletApi.walletUsersPageInit()
```

Do not change `admin_front_ts/src/views/Main/personal/wallet/index.vue` unless the test reveals accidental `ledger*` or `users*` calls there. The current personal wallet page uses `WalletApi.summary()` and `WalletApi.transactions()` and should stay that way.

- [ ] **Step 6: Verify GREEN for wallet tests**

Run:

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/wallet/wallet-api.test.ts tests/shared/wallet/wallet-pages.test.ts tests/shared/payment-wallet-billing-redesign.test.ts
```

Expected: pass.

- [ ] **Step 7: Verify frontend slice together**

Run:

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/table/useCrudTable.test.ts tests/shared/ai/ai-billing-rule-api.test.ts tests/shared/wallet/wallet-api.test.ts tests/shared/wallet/wallet-pages.test.ts tests/shared/payment-wallet-billing-redesign.test.ts
npm run build:check
```

Expected: pass.

---

## Task 4: Add backend `/page-init` aliases for non-bootstrap `/init` routes

**Files:**

- Create: `admin_back_go/internal/architecture/restful_api_naming_test.go`
- Modify: backend route files listed in the table below
- Modify: `docs/contracts/admin-api-v1.md`

### Route alias table

| File | Add before old route | Keep old route |
| --- | --- | --- |
| `admin_back_go/internal/module/auth_platform/transport/admin/route.go` | `v1.GET("/page-init", handler.Init)` | `v1.GET("/init", handler.Init)` |
| `admin_back_go/internal/module/crontask/transport/admin/route.go` | `group.GET("/page-init", handler.Init)` | `group.GET("/init", handler.Init)` |
| `admin_back_go/internal/module/notification/transport/admin/route.go` | `group.GET("/page-init", handler.Init)` | `group.GET("/init", handler.Init)` |
| `admin_back_go/internal/module/notification/transport/admin/task_route.go` | `group.GET("/page-init", handler.Init)` | `group.GET("/init", handler.Init)` |
| `admin_back_go/internal/module/operationlog/transport/admin/route.go` | `group.GET("/page-init", handler.Init)` | `group.GET("/init", handler.Init)` |
| `admin_back_go/internal/module/permission/transport/admin/route.go` | `v1.GET("/page-init", handler.Init)` | `v1.GET("/init", handler.Init)` |
| `admin_back_go/internal/module/role/transport/admin/route.go` | `v1.GET("/page-init", handler.Init)` | `v1.GET("/init", handler.Init)` |
| `admin_back_go/internal/module/systemlog/transport/admin/route.go` | `group.GET("/page-init", handler.Init)` | `group.GET("/init", handler.Init)` |
| `admin_back_go/internal/module/systemsetting/transport/admin/route.go` | `group.GET("/page-init", handler.Init)` | `group.GET("/init", handler.Init)` |
| `admin_back_go/internal/module/uploadconfig/transport/admin/route.go` | `drivers.GET("/page-init", handler.DriverInit)` | `drivers.GET("/init", handler.DriverInit)` |
| `admin_back_go/internal/module/uploadconfig/transport/admin/route.go` | `rules.GET("/page-init", handler.RuleInit)` | `rules.GET("/init", handler.RuleInit)` |
| `admin_back_go/internal/module/uploadconfig/transport/admin/route.go` | `settings.GET("/page-init", handler.SettingInit)` | `settings.GET("/init", handler.SettingInit)` |

- [ ] **Step 1: Add failing architecture test**

Create `admin_back_go/internal/architecture/restful_api_naming_test.go`:

```go
package architecture

import (
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"
)

type pageInitAliasExpectation struct {
	rel        string
	pageInit   string
	legacyInit string
}

func TestAdminRoutesExposePageInitAliasesForPageDictionaries(t *testing.T) {
	root := backendRoot(t)
	expectations := []pageInitAliasExpectation{
		{"internal/module/auth_platform/transport/admin/route.go", `v1.GET("/page-init", handler.Init)`, `v1.GET("/init", handler.Init)`},
		{"internal/module/crontask/transport/admin/route.go", `group.GET("/page-init", handler.Init)`, `group.GET("/init", handler.Init)`},
		{"internal/module/notification/transport/admin/route.go", `group.GET("/page-init", handler.Init)`, `group.GET("/init", handler.Init)`},
		{"internal/module/notification/transport/admin/task_route.go", `group.GET("/page-init", handler.Init)`, `group.GET("/init", handler.Init)`},
		{"internal/module/operationlog/transport/admin/route.go", `group.GET("/page-init", handler.Init)`, `group.GET("/init", handler.Init)`},
		{"internal/module/permission/transport/admin/route.go", `v1.GET("/page-init", handler.Init)`, `v1.GET("/init", handler.Init)`},
		{"internal/module/role/transport/admin/route.go", `v1.GET("/page-init", handler.Init)`, `v1.GET("/init", handler.Init)`},
		{"internal/module/systemlog/transport/admin/route.go", `group.GET("/page-init", handler.Init)`, `group.GET("/init", handler.Init)`},
		{"internal/module/systemsetting/transport/admin/route.go", `group.GET("/page-init", handler.Init)`, `group.GET("/init", handler.Init)`},
		{"internal/module/uploadconfig/transport/admin/route.go", `drivers.GET("/page-init", handler.DriverInit)`, `drivers.GET("/init", handler.DriverInit)`},
		{"internal/module/uploadconfig/transport/admin/route.go", `rules.GET("/page-init", handler.RuleInit)`, `rules.GET("/init", handler.RuleInit)`},
		{"internal/module/uploadconfig/transport/admin/route.go", `settings.GET("/page-init", handler.SettingInit)`, `settings.GET("/init", handler.SettingInit)`},
	}

	for _, expectation := range expectations {
		source := readRestfulNamingFile(t, root, expectation.rel)
		if !strings.Contains(source, expectation.pageInit) {
			t.Fatalf("%s must contain %s", expectation.rel, expectation.pageInit)
		}
		if !strings.Contains(source, expectation.legacyInit) {
			t.Fatalf("%s must keep temporary legacy alias %s", expectation.rel, expectation.legacyInit)
		}
	}
}

func TestAdminRoutesDoNotUseLegacyActionPaths(t *testing.T) {
	root := backendRoot(t)
	transportRoot := filepath.Join(root, "internal", "module")
	legacyActionPath := regexp.MustCompile(`\.(GET|POST|PUT|PATCH|DELETE)\("(?:[^"]*/)?(list|add|edit|del)(/|"|\?)`)
	var offenders []string

	err := filepath.WalkDir(transportRoot, func(path string, entry os.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if entry.IsDir() || filepath.Base(path) != "route.go" && filepath.Base(path) != "task_route.go" {
			return nil
		}
		body, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		if legacyActionPath.Match(body) {
			rel, _ := filepath.Rel(root, path)
			offenders = append(offenders, filepath.ToSlash(rel))
		}
		return nil
	})
	if err != nil {
		t.Fatalf("walk transport routes: %v", err)
	}
	if len(offenders) > 0 {
		t.Fatalf("legacy action route paths remain:\n  %s", strings.Join(offenders, "\n  "))
	}
}

func readRestfulNamingFile(t *testing.T, root, rel string) string {
	t.Helper()
	body, err := os.ReadFile(filepath.Join(root, filepath.FromSlash(rel)))
	if err != nil {
		t.Fatalf("read %s: %v", rel, err)
	}
	return string(body)
}
```

- [ ] **Step 2: Verify RED**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture -run TestAdminRoutesExposePageInitAliasesForPageDictionaries -count=1
```

Expected: fail on the first route missing `/page-init` alias.

- [ ] **Step 3: Add route aliases only, no handler logic change**

For each file in the route alias table, add the `/page-init` registration immediately before the existing `/init` registration. Example for auth platforms:

```go
v1 := router.Group("/api/admin/v1/auth-platforms")
v1.GET("/page-init", handler.Init)
v1.GET("/init", handler.Init)
v1.GET("", handler.List)
```

Example for upload config:

```go
drivers := router.Group("/api/admin/v1/upload-drivers")
drivers.GET("/page-init", handler.DriverInit)
drivers.GET("/init", handler.DriverInit)
drivers.GET("", handler.DriverList)
```

```go
rules := router.Group("/api/admin/v1/upload-rules")
rules.GET("/page-init", handler.RuleInit)
rules.GET("/init", handler.RuleInit)
rules.GET("", handler.RuleList)
```

```go
settings := router.Group("/api/admin/v1/upload-settings")
settings.GET("/page-init", handler.SettingInit)
settings.GET("/init", handler.SettingInit)
settings.GET("", handler.SettingList)
```

- [ ] **Step 4: Verify architecture test GREEN**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture -run 'TestAdminRoutesExposePageInitAliasesForPageDictionaries|TestAdminRoutesDoNotUseLegacyActionPaths' -count=1
```

Expected: pass.

- [ ] **Step 5: Verify affected backend packages**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/auth_platform/... ./internal/module/crontask/... ./internal/module/notification/... ./internal/module/operationlog/... ./internal/module/permission/... ./internal/module/role/... ./internal/module/systemlog/... ./internal/module/systemsetting/... ./internal/module/uploadconfig/... -count=1
```

Expected: pass.

- [ ] **Step 6: Verify server route integration**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/server/... -count=1
```

Expected: pass. If route snapshot tests require explicit additions, add page-init requests for the same resources while keeping `/init` assertions.

- [ ] **Step 7: Update contract docs for aliases**

In `docs/contracts/admin-api-v1.md`, for each route in the alias table:

```text
Primary page dictionary: GET /api/admin/v1/<resources>/page-init
Temporary legacy alias: GET /api/admin/v1/<resources>/init
Alias removal condition: frontend wrapper and smoke use pageInit/page-init only.
```

Do not change `GET /api/admin/v1/users/init` bootstrap wording. It stays bootstrap.

---

## Task 5: Rename touched backend single-delete handler for AI billing

**Files:**

- Modify: `admin_back_go/internal/module/ai/billing/transport/admin/handler.go`
- Modify: `admin_back_go/internal/module/ai/billing/transport/admin/route.go`
- Modify: `admin_back_go/internal/module/ai/billing/transport/admin/handler_test.go`

### Target behavior

HTTP path stays unchanged:

```text
DELETE /api/admin/v1/ai-billing-rules/:id
```

Handler name becomes explicit:

```go
Delete -> DeleteOne
```

- [ ] **Step 1: Update handler test wording first**

In `admin_back_go/internal/module/ai/billing/transport/admin/handler_test.go`, rename the test:

```go
func TestHandlerStatusAndDeleteOne(t *testing.T) {
```

Keep the existing DELETE request path and `service.deleteID` assertion unchanged.

- [ ] **Step 2: Verify RED is not required for pure rename**

This rename may compile until production code is changed. The safety gate is `go test` after edits, not a behavioral RED. Do not change the route path.

- [ ] **Step 3: Rename handler method**

In `admin_back_go/internal/module/ai/billing/transport/admin/handler.go`:

```go
func (h *Handler) DeleteOne(c *gin.Context) {
	id, ok := routeID(c)
	if !ok {
		return
	}
	if appErr := h.requireService().DeleteRule(c.Request.Context(), id); appErr != nil {
		response.Error(c, appErr)
		return
	}
	response.OK(c, gin.H{})
}
```

Remove the old `func (h *Handler) Delete(c *gin.Context)` method after the new method exists.

- [ ] **Step 4: Point route to `DeleteOne`**

In `admin_back_go/internal/module/ai/billing/transport/admin/route.go`:

```go
group.DELETE("/:id", handler.DeleteOne)
```

- [ ] **Step 5: Verify backend AI billing transport**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/ai/billing/... -count=1
```

Expected: pass.

---

## Task 6: Follow-up frontend wrapper batches

Do these only after Tasks 1 through 3 are green. Each batch is one separate work item with its own tests and commit.

### Batch A: permission/auth-platform/role

**Files:**

- `admin_front_ts/src/api/permission/authPlatform.ts`
- `admin_front_ts/src/api/permission/permission.ts`
- `admin_front_ts/src/api/permission/role.ts`
- `admin_front_ts/tests/shared/permission/auth-platform-api.test.ts`
- `admin_front_ts/tests/shared/permission/permission-api.test.ts`
- `admin_front_ts/tests/shared/permission/role-api.test.ts`

**Method mapping:**

| Old wrapper | Standard wrapper |
| --- | --- |
| `init` | `pageInit` |
| `add` | `create` |
| `edit` | `update` |
| `status` | `changeStatus` |
| `del` | `deleteOne` or `deleteBatch` based on current HTTP call |

- [ ] **Step 1: Add/adjust tests to require standard exports and temporary aliases**

For each test file, assert both the standard name and the alias mapping. Use this exact assertion pattern with the relevant API object source:

```ts
expect(source).toContain('pageInit')
expect(source).toContain('create')
expect(source).toContain('update')
expect(source).toContain('changeStatus')
expect(source).toContain('init: pageInit')
expect(source).toContain('add: create')
expect(source).toContain('edit: update')
expect(source).toContain('status: changeStatus')
```

For resources that support both single and batch delete, assert:

```ts
expect(source).toContain('deleteOne')
expect(source).toContain('deleteBatch')
expect(source).toContain('del: deleteOne')
```

If the existing API has one `del(params: { id: Id | Id[] })` method, split it into `deleteOne({ id })` and `deleteBatch({ ids })`, then keep `del(params)` as the compatibility adapter.

- [ ] **Step 2: Run RED for permission batch**

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/permission/auth-platform-api.test.ts tests/shared/permission/permission-api.test.ts tests/shared/permission/role-api.test.ts
```

- [ ] **Step 3: Implement wrappers with function constants**

Use the same function-constant pattern from Task 2. Do not reference the export object from inside its own initializer.

- [ ] **Step 4: Switch direct page calls when tests identify them**

Search exact direct calls:

```powershell
cd E:\admin_go\admin_front_ts
rg -n 'AuthPlatformApi\.(init|add|edit|del|status)|PermissionApi\.(init|add|edit|del|status)|RoleApi\.(init|add|edit|del|status)' src
```

Replace only direct calls in active pages. Do not remove aliases from the API object.

- [ ] **Step 5: Run GREEN for permission batch**

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/permission/auth-platform-api.test.ts tests/shared/permission/permission-api.test.ts tests/shared/permission/role-api.test.ts
npm run build:check
```

### Batch B: system/upload/notification wrappers

**Files:**

- `admin_front_ts/src/api/system/cronTask.ts`
- `admin_front_ts/src/api/system/log.ts`
- `admin_front_ts/src/api/system/notification.ts`
- `admin_front_ts/src/api/system/notificationTask.ts`
- `admin_front_ts/src/api/system/operationLog.ts`
- `admin_front_ts/src/api/system/setting.ts`
- `admin_front_ts/src/api/system/uploadConfig.ts`
- `admin_front_ts/tests/shared/system/cron-task-api.test.ts`
- `admin_front_ts/tests/shared/system/notification-task-refresh.test.ts`
- `admin_front_ts/tests/shared/system/operation-log-api.test.ts`
- `admin_front_ts/tests/shared/system/system-setting-page.test.ts`
- `admin_front_ts/tests/shared/system/upload-config-api.test.ts`

**Method mapping:** same as Batch A.

- [ ] **Step 1: Add standard-name assertions to the listed tests**

Each touched API object must expose the standard names it actually supports. Do not invent `create/update/status` for read-only APIs.

Read-only examples:

```text
SystemLogApi: pageInit/list-like methods only; no fake create/update/delete.
OperationLogApi: pageInit/list/deleteOne/deleteBatch if current API supports deletion.
ExportTaskApi: deleteOne only if current API supports deletion.
```

- [ ] **Step 2: Run RED for system batch**

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/system/cron-task-api.test.ts tests/shared/system/notification-task-refresh.test.ts tests/shared/system/operation-log-api.test.ts tests/shared/system/system-setting-page.test.ts tests/shared/system/upload-config-api.test.ts
```

- [ ] **Step 3: Implement wrappers and direct-call migrations**

Search direct calls first:

```powershell
cd E:\admin_go\admin_front_ts
rg -n '(CronTaskApi|SystemLogApi|NotificationApi|NotificationTaskApi|OperationLogApi|SystemSettingApi|UploadDriverApi|UploadRuleApi|UploadSettingApi)\.(init|add|edit|del|status)' src
```

Switch direct calls to standard names. Keep aliases in wrappers.

- [ ] **Step 4: Run GREEN for system batch**

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/system/cron-task-api.test.ts tests/shared/system/notification-task-refresh.test.ts tests/shared/system/operation-log-api.test.ts tests/shared/system/system-setting-page.test.ts tests/shared/system/upload-config-api.test.ts
npm run build:check
```

### Batch C: AI older wrappers

**Files:**

- `admin_front_ts/src/api/ai/agents.ts`
- `admin_front_ts/src/api/ai/conversations.ts`
- `admin_front_ts/src/api/ai/images.ts`
- `admin_front_ts/src/api/ai/knowledge.ts`
- `admin_front_ts/src/api/ai/providers.ts`
- `admin_front_ts/src/api/ai/runs.ts`
- `admin_front_ts/src/api/ai/tools.ts`
- `admin_front_ts/tests/shared/ai/ai-agent-api.test.ts`
- `admin_front_ts/tests/shared/ai/ai-conversation-api.test.ts`
- `admin_front_ts/tests/shared/ai/ai-image-api.test.ts`
- `admin_front_ts/tests/shared/ai/ai-knowledge-api.test.ts`
- `admin_front_ts/tests/shared/ai/ai-provider-api.test.ts`
- `admin_front_ts/tests/shared/ai/ai-run-api.test.ts`
- `admin_front_ts/tests/shared/ai/ai-tools-api.test.ts`

**Special cases:**

```text
AiToolApi.generateInit -> generatePageInit
AiRunApi.init -> pageInit if it is page dictionaries, not bootstrap
AiConversationApi add/edit/del -> create/update/deleteOne if those are current-user CRUD wrappers
AiImageApi init -> pageInit, del -> deleteOne
```

- [ ] **Step 1: Add standard-name assertions to the listed AI tests**

Use the Task 2 assertion style. For `generateInit`, require:

```ts
expect(source).toContain('generatePageInit')
expect(source).toContain('generateInit: generatePageInit')
```

- [ ] **Step 2: Run RED for AI batch**

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/ai/ai-agent-api.test.ts tests/shared/ai/ai-conversation-api.test.ts tests/shared/ai/ai-image-api.test.ts tests/shared/ai/ai-knowledge-api.test.ts tests/shared/ai/ai-provider-api.test.ts tests/shared/ai/ai-run-api.test.ts tests/shared/ai/ai-tools-api.test.ts
```

- [ ] **Step 3: Implement wrappers and direct-call migrations**

Search direct calls first:

```powershell
cd E:\admin_go\admin_front_ts
rg -n '(AiAgentApi|AiConversationApi|AiImageApi|AiKnowledgeApi|AiProviderApi|AiRunApi|AiToolApi)\.(init|add|edit|del|status|generateInit)' src
```

Switch direct calls to standard names. Keep aliases in wrappers.

- [ ] **Step 4: Run GREEN for AI batch**

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/ai/ai-agent-api.test.ts tests/shared/ai/ai-conversation-api.test.ts tests/shared/ai/ai-image-api.test.ts tests/shared/ai/ai-knowledge-api.test.ts tests/shared/ai/ai-provider-api.test.ts tests/shared/ai/ai-run-api.test.ts tests/shared/ai/ai-tools-api.test.ts
npm run build:check
```

---

## Task 7: Backend handler naming cleanup for touched modules only

Do this after backend `/page-init` aliases are green. Do not rename every handler in the repo in one commit.

### Known P2 handler backlog

| Module route file | Current handler | Target handler |
| --- | --- | --- |
| `internal/module/ai/agent/transport/admin/route.go` | `handler.Init`, `handler.Delete` | `handler.PageInit`, `handler.DeleteOne` |
| `internal/module/ai/knowledge/transport/admin/route.go` | `h.Init` | `h.PageInit` |
| `internal/module/ai/provider/transport/admin/route.go` | `handler.Init`, `handler.Delete` | `handler.PageInit`, `handler.DeleteOne` |
| `internal/module/ai/run/transport/admin/route.go` | `handler.Init` | `handler.PageInit` |
| `internal/module/ai/tool/transport/admin/route.go` | `handler.Init`, `handler.Delete` | `handler.PageInit`, `handler.DeleteOne` |
| `internal/module/clientversion/transport/admin/route.go` | `handler.Init`, `handler.Delete` | `handler.PageInit`, `handler.DeleteOne` |
| `internal/module/payment/transport/admin/route.go` | `handler.ConfigInit`, `handler.RechargeInit` | `handler.ConfigPageInit`, `handler.RechargePageInit` |
| `internal/module/ai/conversation/transport/admin/route.go` | `handler.Delete` | `handler.DeleteOne` |
| `internal/module/ai/image/transport/admin/route.go` | `handler.Delete` | `handler.DeleteOne` |
| `internal/module/notification/transport/admin/task_route.go` | `handler.Delete` | `handler.DeleteOne` |

- [ ] **Step 1: Pick only modules already touched by the current runtime slice**

For this plan’s first backend implementation, the only already-touched low-risk module is AI billing from Task 5. The backlog table is for future touched-code cleanup.

- [ ] **Step 2: For a selected module, add/rename tests first**

Use the module’s existing handler test. Rename the test to the explicit action name and keep HTTP method/path unchanged.

- [ ] **Step 3: Rename handler methods and route references**

Example pattern:

```go
func (h *Handler) PageInit(c *gin.Context) { /* existing Init body */ }
func (h *Handler) DeleteOne(c *gin.Context) { /* existing Delete body */ }
```

Route pattern:

```go
group.GET("/page-init", handler.PageInit)
group.DELETE("/:id", handler.DeleteOne)
```

- [ ] **Step 4: Run exact package tests for the selected module**

For the known backlog, use these exact commands when that module is selected:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/ai/agent/... -count=1
go test ./internal/module/ai/knowledge/... -count=1
go test ./internal/module/ai/provider/... -count=1
go test ./internal/module/ai/run/... -count=1
go test ./internal/module/ai/tool/... -count=1
go test ./internal/module/clientversion/... -count=1
go test ./internal/module/payment/... -count=1
go test ./internal/module/ai/conversation/... -count=1
go test ./internal/module/ai/image/... -count=1
go test ./internal/module/notification/... -count=1
```

Run only the command for the selected module, plus `go test ./internal/server/... -count=1` if route registration changed.

---

## Task 8: Final docs/status/contract alignment

**Files:**

- Modify: `docs/contracts/admin-api-v1.md`
- Modify if runtime behavior/status changed: `docs/status/current-status.md`
- Modify if smoke matrix changed: `docs/testing/smoke-matrix.md`
- Keep as evidence: `docs/superpowers/reviews/2026-05-31-restful-api-naming-audit-review.md`

- [ ] **Step 1: Update contract naming policy if implementation changed it**

Ensure `docs/contracts/admin-api-v1.md` still contains:

```text
GET    /api/admin/v1/<resources>/page-init
GET    /api/admin/v1/<resources>
GET    /api/admin/v1/<resources>/:id
POST   /api/admin/v1/<resources>
PUT    /api/admin/v1/<resources>/:id
PATCH  /api/admin/v1/<resources>/:id/status
DELETE /api/admin/v1/<resources>/:id
DELETE /api/admin/v1/<resources>
```

Ensure it also states:

```text
init is bootstrap-only except temporary documented aliases during migration.
Frontend standard wrapper names are list/detail/create/update/changeStatus/deleteOne/deleteBatch/pageInit.
Legacy add/edit/del/init/status aliases are temporary compatibility, not new-module standard.
```

- [ ] **Step 2: Update route sections touched by Task 4**

For each of these sections, change heading/copy from `Init` to `Page Init` and list the temporary alias:

```text
Permission Definitions
Auth Platform
System Cron Tasks
System Logs
Operation Logs
System Settings
Upload Drivers
Upload Rules
Upload Settings
Notifications
Notification Tasks
Roles
```

- [ ] **Step 3: Update status only if runtime behavior changed**

If only code-facing aliases changed and no user-visible route was removed, `docs/status/current-status.md` should say:

```text
RESTful naming cleanup: added standard frontend wrapper names and backend page-init aliases while preserving legacy aliases; no route removal in this slice.
```

Do not mark old aliases removed unless the removal actually happened and tests prove it.

- [ ] **Step 4: Update smoke matrix only if smoke probes change**

If smoke still calls legacy `/init`, add parallel `/page-init` probes before removing old probes. Do not replace smoke with `/page-init` until frontend and contract are both migrated.

- [ ] **Step 5: Run root docs verification**

Run:

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected: pass.

---

## Task 9: Final verification matrix before claiming completion

Run only the commands matching touched areas.

### Frontend first-wave verification

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/table/useCrudTable.test.ts tests/shared/ai/ai-billing-rule-api.test.ts tests/shared/wallet/wallet-api.test.ts tests/shared/wallet/wallet-pages.test.ts tests/shared/payment-wallet-billing-redesign.test.ts
npm run build:check
```

### Backend alias verification

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture -run 'TestAdminRoutesExposePageInitAliasesForPageDictionaries|TestAdminRoutesDoNotUseLegacyActionPaths' -count=1
go test ./internal/module/auth_platform/... ./internal/module/crontask/... ./internal/module/notification/... ./internal/module/operationlog/... ./internal/module/permission/... ./internal/module/role/... ./internal/module/systemlog/... ./internal/module/systemsetting/... ./internal/module/uploadconfig/... -count=1
go test ./internal/server/... -count=1
```

### Backend AI billing handler rename verification

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/ai/billing/... -count=1
```

### Root governance verification

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Completion claim is allowed only when the commands for all touched areas pass and the result says exactly what stayed compatible.

## Commit slicing

Use small commits; do not mix unrelated runtime repos.

```text
commit 1: docs: add restful naming cleanup plan
commit 2: frontend: support standard crud api method names
commit 3: frontend: migrate ai billing api naming
commit 4: frontend: migrate wallet page-init api naming
commit 5: backend: add page-init aliases for page dictionaries
commit 6: backend: rename ai billing delete handler
commit 7: docs: align restful naming contract status
```

If another Codex has live WIP in a repo, do not commit that repo from this session. Hand off exact file paths and stop.
