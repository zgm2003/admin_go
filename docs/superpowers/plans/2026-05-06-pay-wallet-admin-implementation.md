# Pay Wallet Admin Read-Only Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Work in the current branch. Do not create a worktree. Do not commit unless the user explicitly asks.

**Goal:** Migrate后台钱包管理 read-only 查询 from legacy PHP `UserWallet` POST APIs to Go REST endpoints under `/api/admin/v1`, while keeping wallet adjustment explicitly isolated as legacy until the next write-path slice.

**Architecture:** Add a focused `internal/module/wallet` module using the existing Gin modular monolith chain: `route -> handler -> service -> repository -> model`. Read routes use the real permission code `pay_wallet_list`; no operation log is registered for read-only queries. Frontend moves wallet list/transaction reads to `request` + Go REST, and names the remaining legacy adjustment boundary explicitly.

**Tech Stack:** Go 1.21+, Gin, GORM, MySQL, go-playground validator, Vue 3, TypeScript, Vite, Vitest, Element Plus.

---

## Task 1: Add Wallet Enum / Dict / Validate Foundation

**Files:**

- Modify: `E:/admin_go/admin_back_go/internal/enum/pay.go`
- Modify: `E:/admin_go/admin_back_go/internal/enum/pay_test.go`
- Modify: `E:/admin_go/admin_back_go/internal/dict/dict.go`
- Modify: `E:/admin_go/admin_back_go/internal/dict/pay_test.go`
- Modify: `E:/admin_go/admin_back_go/internal/validate/pay.go`
- Modify: `E:/admin_go/admin_back_go/internal/validate/pay_test.go`
- Modify: `E:/admin_go/admin_back_go/internal/validate/register.go`

- [ ] Add wallet constants and stable order:

```go
const (
	WalletTypeRecharge = 1
	WalletTypeConsume  = 2
	WalletTypeAdjust   = 3
)

const (
	WalletSourceNone    = 0
	WalletSourceFulfill = 1
	WalletSourceManual  = 2
)
```

- [ ] Add label maps and `IsWalletType` / `IsWalletSource`.
- [ ] Add `dict.WalletTypeOptions()` and `dict.WalletSourceOptions()`.
- [ ] Register validator tags:

```go
"wallet_type":   validateWalletType,
"wallet_source": validateWalletSource,
```

- [ ] Run targeted tests:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/enum ./internal/dict ./internal/validate
```

Expected: PASS.

## Task 2: Add Backend Wallet Read Module

**Files:**

- Create: `E:/admin_go/admin_back_go/internal/module/wallet/errors.go`
- Create: `E:/admin_go/admin_back_go/internal/module/wallet/model.go`
- Create: `E:/admin_go/admin_back_go/internal/module/wallet/dto.go`
- Create: `E:/admin_go/admin_back_go/internal/module/wallet/request.go`
- Create: `E:/admin_go/admin_back_go/internal/module/wallet/repository.go`
- Create: `E:/admin_go/admin_back_go/internal/module/wallet/service.go`
- Create: `E:/admin_go/admin_back_go/internal/module/wallet/handler.go`
- Create: `E:/admin_go/admin_back_go/internal/module/wallet/route.go`
- Create: `E:/admin_go/admin_back_go/internal/module/wallet/service_test.go`
- Create: `E:/admin_go/admin_back_go/internal/module/wallet/handler_test.go`

- [ ] Define request structs:

```go
type listRequest struct {
	CurrentPage int    `form:"current_page" binding:"required,min=1"`
	PageSize    int    `form:"page_size" binding:"required,min=1,max=50"`
	UserID      *int64 `form:"user_id" binding:"omitempty,min=1"`
	StartDate   string `form:"start_date" binding:"omitempty,datetime=2006-01-02"`
	EndDate     string `form:"end_date" binding:"omitempty,datetime=2006-01-02"`
}

type transactionListRequest struct {
	CurrentPage int    `form:"current_page" binding:"required,min=1"`
	PageSize    int    `form:"page_size" binding:"required,min=1,max=50"`
	UserID      *int64 `form:"user_id" binding:"omitempty,min=1"`
	Type        *int   `form:"type" binding:"omitempty,wallet_type"`
	StartDate   string `form:"start_date" binding:"omitempty,datetime=2006-01-02"`
	EndDate     string `form:"end_date" binding:"omitempty,datetime=2006-01-02"`
}
```

- [ ] Define service interface:

```go
type HTTPService interface {
	Init(ctx context.Context) (*InitResponse, *apperror.Error)
	List(ctx context.Context, query ListQuery) (*ListResponse, *apperror.Error)
	Transactions(ctx context.Context, query TransactionListQuery) (*TransactionListResponse, *apperror.Error)
}
```

- [ ] Repository reads:

```text
user_wallets AS w
LEFT JOIN users AS u ON u.id = w.user_id AND u.is_del = 2
wallet_transactions AS wt
LEFT JOIN users AS u ON u.id = wt.user_id AND u.is_del = 2
```

- [ ] Service rules:

```text
default current_page=1
default page_size=20
cap page_size by enum.PageSizeMax
trim dates
format times as "2006-01-02 15:04:05"
derive type_text from enum.WalletTypeLabels
return empty list normally when wallet_transactions has no rows
```

- [ ] Run targeted tests:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/wallet
```

Expected: PASS.

## Task 3: Register Routes and Metadata

**Files:**

- Modify: `E:/admin_go/admin_back_go/internal/bootstrap/app.go`
- Modify: `E:/admin_go/admin_back_go/internal/bootstrap/route_meta.go`
- Modify: `E:/admin_go/admin_back_go/internal/bootstrap/route_meta_test.go`
- Modify: `E:/admin_go/admin_back_go/internal/server/router.go`
- Modify: `E:/admin_go/admin_back_go/internal/server/router_test.go`

- [ ] Wire repository/service in bootstrap.
- [ ] Add server dependency:

```go
WalletService wallet.HTTPService
```

- [ ] Register routes:

```text
GET /api/admin/v1/wallets/page-init
GET /api/admin/v1/wallets
GET /api/admin/v1/wallet-transactions
```

- [ ] Add permission metadata:

```go
middleware.NewRouteKey(http.MethodGet, "/api/admin/v1/wallets/page-init"): "pay_wallet_list",
middleware.NewRouteKey(http.MethodGet, "/api/admin/v1/wallets"): "pay_wallet_list",
middleware.NewRouteKey(http.MethodGet, "/api/admin/v1/wallet-transactions"): "pay_wallet_list",
```

- [ ] Do not add operation log metadata for these read-only routes.
- [ ] Run targeted tests:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/bootstrap ./internal/server
```

Expected: PASS.

## Task 4: Add Full Smoke Probes

**Files:**

- Modify: `E:/admin_go/admin_back_go/scripts/full-admin-smoke.ps1`
- Modify: `E:/admin_go/docs/testing/smoke-matrix.md`

- [ ] Add assertions for:

```text
wallet_page_init_code
wallet_type_dict_items
wallet_list_count
wallet_transaction_list_count
```

- [ ] Probe endpoints:

```powershell
GET "$baseURL/api/admin/v1/wallets/page-init"
GET "$baseURL/api/admin/v1/wallets?current_page=1&page_size=10"
GET "$baseURL/api/admin/v1/wallet-transactions?current_page=1&page_size=10"
```

- [ ] Do not create wallet rows or wallet transaction rows in smoke.
- [ ] Run smoke after backend is running:

```powershell
cd E:\admin_go\admin_back_go
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account 15671628271 -Password 123456
```

Expected: JSON summary includes wallet read-only probes; transaction count may be 0.

## Task 5: Move Frontend Wallet Read API to Go REST

**Files:**

- Modify: `E:/admin_go/admin_front_ts/src/api/pay/wallet.ts`
- Modify: `E:/admin_go/admin_front_ts/src/views/Main/pay/wallet/index.vue`
- Modify: `E:/admin_go/admin_front_ts/src/views/Main/pay/wallet/components/WalletTransactionDialog.vue`
- Modify: `E:/admin_go/admin_front_ts/src/views/Main/pay/wallet/components/WalletAdjustDialog.vue`
- Create: `E:/admin_go/admin_front_ts/tests/shared/pay/wallet-api.test.ts`

- [ ] Replace read methods with Go REST:

```ts
export const WalletApi = {
  pageInit: () => request.get<WalletPageInitResponse>('/api/admin/v1/wallets/page-init'),
  list: (params: WalletListParams) => request.get<PaginatedResponse<WalletListItem>>('/api/admin/v1/wallets', { params }),
  transactions: (params: WalletTransactionsParams) =>
    request.get<PaginatedResponse<WalletTransactionItem>>('/api/admin/v1/wallet-transactions', { params }),
}
```

- [ ] Isolate current legacy adjustment:

```ts
export const LegacyWalletAdjustmentApi = {
  create: (params: WalletAdjustParams) => legacyRequest.post<void>('/api/admin/UserWallet/adjust', params),
}
```

- [ ] Update wallet page and transaction dialog imports from `UserWalletApi` to `WalletApi`.
- [ ] Update adjust dialog import to `LegacyWalletAdjustmentApi`.
- [ ] Remove formatter `any` in touched wallet components; use `unknown` or concrete row types.
- [ ] Add API test expectations:

```text
WalletApi.pageInit uses GET /api/admin/v1/wallets/page-init
WalletApi.list uses GET /api/admin/v1/wallets
WalletApi.transactions uses GET /api/admin/v1/wallet-transactions
LegacyWalletAdjustmentApi.create is the only remaining /api/admin/UserWallet/adjust usage in this file
No any/as any/Record<string, any> in touched wallet files
```

- [ ] Run targeted frontend tests:

```powershell
cd E:\admin_go\admin_front_ts
npx vitest run tests/shared/pay/wallet-api.test.ts
npx vue-tsc -b --pretty false
npx eslint src/api/pay/wallet.ts src/views/Main/pay/wallet/index.vue src/views/Main/pay/wallet/components/WalletTransactionDialog.vue src/views/Main/pay/wallet/components/WalletAdjustDialog.vue tests/shared/pay/wallet-api.test.ts
```

Expected: tests/typecheck pass; eslint must have no errors.

## Task 6: Update Contract and Status Docs

**Files:**

- Modify: `E:/admin_go/docs/contracts/admin-api-v1.md`
- Modify: `E:/admin_go/docs/migration/current-status.md`
- Modify: `E:/admin_go/admin_back_go/docs/architecture.md`
- Modify: `E:/admin_go/docs/testing/smoke-matrix.md`

- [ ] Add Admin Wallet section to `admin-api-v1.md`.
- [ ] Mark wallet admin read-only as implemented only after code and smoke pass.
- [ ] Keep adjustment marked as planned/legacy adapter until `POST /wallet-adjustments` is implemented.
- [ ] Add backend architecture section:

```text
internal/module/wallet is read-only for wallets and wallet_transactions.
No queue/job/payment SDK is involved.
Adjustment will be wallet-adjustments write slice with DB transaction and idempotency.
```

- [ ] Run contract gate:

```powershell
cd E:\admin_go\admin_back_go
powershell -ExecutionPolicy Bypass -File .\scripts\check-contract.ps1
```

Expected: PASS.

## Task 7: Final Verification

Backend:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/enum ./internal/dict ./internal/validate ./internal/module/wallet ./internal/module/payorder ./internal/module/paytransaction ./internal/module/permission ./internal/server ./internal/bootstrap
go test ./...
go vet ./...
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account 15671628271 -Password 123456
```

Frontend:

```powershell
cd E:\admin_go\admin_front_ts
npx vitest run tests/shared/pay/wallet-api.test.ts
npx vue-tsc -b --pretty false
npx eslint src/api/pay/wallet.ts src/views/Main/pay/wallet/index.vue src/views/Main/pay/wallet/components/WalletTransactionDialog.vue src/views/Main/pay/wallet/components/WalletAdjustDialog.vue tests/shared/pay/wallet-api.test.ts
```

Forbidden scans:

```powershell
cd E:\admin_go
rg "any|as any|Record<string, any>" admin_front_ts/src/api/pay/wallet.ts admin_front_ts/src/views/Main/pay/wallet admin_front_ts/tests/shared/pay -n
rg "UserWallet/list|UserWallet/transactions|UserWallet/init" admin_front_ts/src/api/pay/wallet.ts admin_front_ts/src/views/Main/pay/wallet admin_front_ts/tests/shared/pay -n
```

Expected:

```text
No forbidden frontend type patterns in touched wallet files.
No legacy read endpoints remain for admin wallet read-only.
Only explicit LegacyWalletAdjustmentApi may reference /api/admin/UserWallet/adjust.
```

## Self-review

```text
Spec coverage: read-only wallet list/init/transactions covered; future adjustment boundary documented but not implemented.
No placeholders: placeholder scan is clean.
REST rule: no new /UserWallet/* route in Go.
Userspace: current adjustment function remains available through explicit legacy adapter until the wallet-adjustments slice.
Verification: backend, frontend, smoke, and contract gate commands listed.
```
