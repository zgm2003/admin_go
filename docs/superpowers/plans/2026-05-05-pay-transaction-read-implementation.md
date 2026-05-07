# Pay Transaction Read Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate the admin pay transaction read-only page from legacy PHP POST APIs to Go REST endpoints under `/api/admin/v1/pay-transactions`.

**Architecture:** Add a narrow Gin module `paytransaction` using `route -> handler -> service -> repository -> model`. Keep this slice read-only: page-init, list, detail. Reuse existing pay enum/dict/validate and do not introduce payment SDK, callback, wallet mutation, or reconciliation execution.

**Tech Stack:** Go 1.21+, Gin, GORM, MySQL, go-playground validator, Vue 3, TypeScript, Vitest, Element Plus.

---

## Contract Lock

Implement exactly these endpoints:

```text
GET /api/admin/v1/pay-transactions/page-init
GET /api/admin/v1/pay-transactions
GET /api/admin/v1/pay-transactions/:id
```

Do not add legacy-compatible POST routes. Do not add write APIs in this slice.

---

## Task 1: Extend pay enum/dict/validate for transaction status

**Files:**
- Modify: `E:/admin_go/admin_back_go/internal/enum/pay.go`
- Modify: `E:/admin_go/admin_back_go/internal/enum/pay_test.go`
- Modify: `E:/admin_go/admin_back_go/internal/dict/dict.go`
- Modify: `E:/admin_go/admin_back_go/internal/dict/pay_test.go`
- Modify: `E:/admin_go/admin_back_go/internal/validate/pay.go`
- Modify: `E:/admin_go/admin_back_go/internal/validate/register.go`
- Modify/Create: `E:/admin_go/admin_back_go/internal/validate/pay_test.go`

- [ ] **Step 1: Add enum tests for transaction status labels/order**

Add tests proving the enum is stable:

```go
func TestPayTransactionStatusesAreStable(t *testing.T) {
	want := []int{enum.PayTxnCreated, enum.PayTxnWaiting, enum.PayTxnSuccess, enum.PayTxnFailed, enum.PayTxnClosed}
	if !reflect.DeepEqual(enum.PayTxnStatuses, want) {
		t.Fatalf("PayTxnStatuses = %#v, want %#v", enum.PayTxnStatuses, want)
	}
	if enum.PayTxnStatusLabels[enum.PayTxnSuccess] != "支付成功" {
		t.Fatalf("unexpected success label: %q", enum.PayTxnStatusLabels[enum.PayTxnSuccess])
	}
	if enum.IsPayTxnStatus(999) {
		t.Fatal("999 must not be a valid transaction status")
	}
}
```

- [ ] **Step 2: Run red test**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/enum
```

Expected before implementation: compile fail for missing `PayTxnCreated` or `IsPayTxnStatus`.

- [ ] **Step 3: Implement enum**

Add to `internal/enum/pay.go`:

```go
const (
	PayTxnCreated = 1
	PayTxnWaiting = 2
	PayTxnSuccess = 3
	PayTxnFailed  = 4
	PayTxnClosed  = 5
)

var PayTxnStatuses = []int{
	PayTxnCreated,
	PayTxnWaiting,
	PayTxnSuccess,
	PayTxnFailed,
	PayTxnClosed,
}

var PayTxnStatusLabels = map[int]string{
	PayTxnCreated: "已创建",
	PayTxnWaiting: "等待支付",
	PayTxnSuccess: "支付成功",
	PayTxnFailed:  "支付失败",
	PayTxnClosed:  "已关闭",
}

func IsPayTxnStatus(value int) bool {
	for _, status := range PayTxnStatuses {
		if status == value {
			return true
		}
	}
	return false
}
```

- [ ] **Step 4: Add dict test**

Add to `internal/dict/pay_test.go`:

```go
func TestPayTxnStatusOptions(t *testing.T) {
	options := dict.PayTxnStatusOptions()
	if len(options) != len(enum.PayTxnStatuses) {
		t.Fatalf("len = %d, want %d", len(options), len(enum.PayTxnStatuses))
	}
	if options[0].Value != enum.PayTxnCreated || options[0].Label != enum.PayTxnStatusLabels[enum.PayTxnCreated] {
		t.Fatalf("first option = %#v", options[0])
	}
}
```

- [ ] **Step 5: Implement dict function**

Add to `internal/dict/dict.go`:

```go
func PayTxnStatusOptions() []Option[int] {
	options := make([]Option[int], 0, len(enum.PayTxnStatuses))
	for _, value := range enum.PayTxnStatuses {
		options = append(options, Option[int]{
			Label: enum.PayTxnStatusLabels[value],
			Value: value,
		})
	}
	return options
}
```

- [ ] **Step 6: Add validation test**

Add test using an anonymous struct:

```go
func TestValidatePayTxnStatus(t *testing.T) {
	validate.MustRegister()
	type payload struct {
		Status int `validate:"pay_txn_status"`
	}
	if err := validate.Struct(payload{Status: enum.PayTxnSuccess}); err != nil {
		t.Fatalf("valid txn status rejected: %v", err)
	}
	if err := validate.Struct(payload{Status: 999}); err == nil {
		t.Fatal("invalid txn status accepted")
	}
}
```

- [ ] **Step 7: Implement validator**

In `internal/validate/pay.go`:

```go
func validatePayTxnStatus(fl playground.FieldLevel) bool {
	value, ok := intValue(fl.Field())
	return ok && enum.IsPayTxnStatus(value)
}
```

In `internal/validate/register.go`, register:

```go
mustRegisterValidation("pay_txn_status", validatePayTxnStatus)
```

- [ ] **Step 8: Run green tests**

```powershell
go test ./internal/enum ./internal/dict ./internal/validate
```

Expected: pass.

---

## Task 2: Add backend paytransaction service and repository tests

**Files:**
- Create: `E:/admin_go/admin_back_go/internal/module/paytransaction/errors.go`
- Create: `E:/admin_go/admin_back_go/internal/module/paytransaction/model.go`
- Create: `E:/admin_go/admin_back_go/internal/module/paytransaction/dto.go`
- Create: `E:/admin_go/admin_back_go/internal/module/paytransaction/repository.go`
- Create: `E:/admin_go/admin_back_go/internal/module/paytransaction/service.go`
- Create: `E:/admin_go/admin_back_go/internal/module/paytransaction/service_test.go`

- [ ] **Step 1: Create DTO/model skeletons used by tests**

Create `model.go` with:

```go
package paytransaction

import "time"

type Transaction struct {
	ID            int64     `gorm:"column:id"`
	TransactionNo string    `gorm:"column:transaction_no"`
	OrderID       int64     `gorm:"column:order_id"`
	OrderNo       string    `gorm:"column:order_no"`
	AttemptNo     int       `gorm:"column:attempt_no"`
	ChannelID     int64     `gorm:"column:channel_id"`
	Channel       int       `gorm:"column:channel"`
	PayMethod     string    `gorm:"column:pay_method"`
	Amount        int       `gorm:"column:amount"`
	TradeNo       string    `gorm:"column:trade_no"`
	TradeStatus   string    `gorm:"column:trade_status"`
	Status        int       `gorm:"column:status"`
	PaidAt        *time.Time `gorm:"column:paid_at"`
	ClosedAt      *time.Time `gorm:"column:closed_at"`
	ChannelResp   string    `gorm:"column:channel_resp"`
	RawNotify     string    `gorm:"column:raw_notify"`
	IsDel         int       `gorm:"column:is_del"`
	CreatedAt     time.Time `gorm:"column:created_at"`
	UpdatedAt     time.Time `gorm:"column:updated_at"`
}

func (Transaction) TableName() string { return "pay_transactions" }
```

Create `dto.go` with the public DTOs from the spec, including `InitResponse`, `ListQuery`, `ListResponse`, `DetailResponse`, `ListRow`, `DetailRow`, `ChannelSummary`, `OrderSummary`, `HTTPService`.

- [ ] **Step 2: Write service tests**

Cover:

```text
Init returns channel_arr and txn_status_arr
List defaults current_page/page_size and maps status/channel/pay_method labels
List normalizes JSON-free rows and page total_page
Detail returns transaction/channel/order and JSON objects for channel_resp/raw_notify
Detail returns not found for missing row
Invalid status/channel query is rejected in handler, not service
```

Use a fake repository implementing:

```go
type fakeRepository struct {
	listRows []ListRow
	total int64
	detail *DetailRow
	detailErr error
}
```

- [ ] **Step 3: Run red test**

```powershell
go test ./internal/module/paytransaction
```

Expected: fail until service/repository exist.

- [ ] **Step 4: Implement service**

Rules:

```text
nil repository -> internal error
CurrentPage default 1
PageSize default 20, max enum.PageSizeMax
order_no/transaction_no trimmed
format time with "2006-01-02 15:04:05"
*Time nil -> null in JSON by using *string DTO fields
channel_resp/raw_notify invalid/blank -> empty map[string]unknown
```

- [ ] **Step 5: Implement repository**

Use GORM query equivalent to legacy:

```go
db := r.db.WithContext(ctx).
    Table("pay_transactions AS pt").
    Joins("LEFT JOIN orders AS o ON o.id = pt.order_id AND o.is_del = ?", enum.CommonNo).
    Joins("LEFT JOIN users AS u ON u.id = o.user_id AND u.is_del = ?", enum.CommonNo).
    Where("pt.is_del = ?", enum.CommonNo)
```

Filters:

```text
pt.order_no exact
pt.transaction_no exact
o.user_id exact
pt.channel exact
pt.status exact
pt.created_at >= start_date 00:00:00
pt.created_at <= end_date 23:59:59
```

Select list fields and scan into `ListRow`. Detail should join user/order/channel and scan into `DetailRow`; never select pay_channel private-key columns.

- [ ] **Step 6: Run green test**

```powershell
go test ./internal/module/paytransaction
```

Expected: pass.

---

## Task 3: Add handler/routes and backend wiring

**Files:**
- Create: `E:/admin_go/admin_back_go/internal/module/paytransaction/request.go`
- Create: `E:/admin_go/admin_back_go/internal/module/paytransaction/handler.go`
- Create: `E:/admin_go/admin_back_go/internal/module/paytransaction/route.go`
- Create: `E:/admin_go/admin_back_go/internal/module/paytransaction/handler_test.go`
- Modify: `E:/admin_go/admin_back_go/internal/server/router.go`
- Modify: `E:/admin_go/admin_back_go/internal/server/router_test.go`
- Modify: `E:/admin_go/admin_back_go/internal/bootstrap/app.go`
- Modify: `E:/admin_go/admin_back_go/internal/bootstrap/route_meta.go`
- Modify: `E:/admin_go/admin_back_go/internal/bootstrap/route_meta_test.go`

- [ ] **Step 1: Write handler tests**

Use Gin + fake HTTP service. Cover:

```text
GET /page-init calls service Init
GET list binds current_page/page_size/order_no/transaction_no/user_id/channel/status/start_date/end_date
GET detail parses :id
GET detail rejects invalid :id
GET list rejects invalid pay_txn_status binding
```

- [ ] **Step 2: Implement request structs**

`request.go`:

```go
type listRequest struct {
	CurrentPage   int    `form:"current_page" binding:"omitempty,min=1"`
	PageSize      int    `form:"page_size" binding:"omitempty,min=1,max=100"`
	OrderNo       string `form:"order_no" binding:"omitempty,max=32"`
	TransactionNo string `form:"transaction_no" binding:"omitempty,max=64"`
	UserID        *int64 `form:"user_id" binding:"omitempty,min=1"`
	Channel       *int   `form:"channel" binding:"omitempty,pay_channel"`
	Status        *int   `form:"status" binding:"omitempty,pay_txn_status"`
	StartDate     string `form:"start_date" binding:"omitempty,datetime=2006-01-02"`
	EndDate       string `form:"end_date" binding:"omitempty,datetime=2006-01-02"`
}
```

- [ ] **Step 3: Implement handler and routes**

`route.go`:

```go
func RegisterRoutes(router *gin.Engine, service HTTPService) {
	validate.MustRegister()
	handler := NewHandler(service)
	group := router.Group("/api/admin/v1/pay-transactions")
	group.GET("/page-init", handler.Init)
	group.GET("", handler.List)
	group.GET("/:id", handler.Detail)
}
```

- [ ] **Step 4: Wire router/bootstrap**

Follow paychannel wiring style:

```go
paytransactionRepo := paytransaction.NewGormRepository(resources.Database)
paytransactionService := paytransaction.NewService(paytransactionRepo)
paytransaction.RegisterRoutes(engine, paytransactionService)
```

- [ ] **Step 5: Add permission metadata tests and route tests**

Assert these keys exist:

```text
GET /api/admin/v1/pay-transactions/page-init -> pay_transaction_list
GET /api/admin/v1/pay-transactions -> pay_transaction_list
GET /api/admin/v1/pay-transactions/:id -> pay_transaction_list
```

Assert no operation log metadata is required for these read-only routes.

- [ ] **Step 6: Run backend package tests**

```powershell
go test ./internal/module/paytransaction ./internal/server ./internal/bootstrap
```

Expected: pass.

---

## Task 4: Update backend docs and full smoke

**Files:**
- Modify: `E:/admin_go/docs/contracts/admin-api-v1.md`
- Modify: `E:/admin_go/docs/migration/current-status.md`
- Modify: `E:/admin_go/docs/testing/smoke-matrix.md`
- Modify: `E:/admin_go/admin_back_go/docs/architecture.md`
- Modify: `E:/admin_go/admin_back_go/scripts/full-admin-smoke.ps1`

- [ ] **Step 1: Add contract docs**

Add section `## Pay Transactions` documenting:

```text
GET /api/admin/v1/pay-transactions/page-init
GET /api/admin/v1/pay-transactions
GET /api/admin/v1/pay-transactions/:id
```

Include auth, query fields, response shape, and “read-only only”.

- [ ] **Step 2: Update migration status**

Add/adjust row:

```text
pay transaction read | implemented: read-only page-init/list/detail | adapted after frontend task | tests... | full smoke... | docs... | no payment state mutation/runtime SDK
```

Do not mark full payment domain implemented.

- [ ] **Step 3: Update smoke matrix**

Add full smoke row:

```text
pay transaction read | page-init/list/detail when row exists | validates no private key leak and JSON object shape
```

- [ ] **Step 4: Extend full smoke**

Add after pay channel probe:

```powershell
$payTxnInit = Invoke-AdminApi -Method GET -Path "/api/admin/v1/pay-transactions/page-init" -Token $AccessToken
$summary.pay_transaction_init_code = $payTxnInit.code
$summary.pay_transaction_channel_dict_count = @($payTxnInit.data.dict.channel_arr).Count
$summary.pay_transaction_status_dict_count = @($payTxnInit.data.dict.txn_status_arr).Count

$payTxnList = Invoke-AdminApi -Method GET -Path "/api/admin/v1/pay-transactions?current_page=1&page_size=20" -Token $AccessToken
$summary.pay_transaction_list_code = $payTxnList.code
$summary.pay_transaction_list_count = @($payTxnList.data.list).Count
$summary.pay_transaction_total = [int]$payTxnList.data.page.total

if (@($payTxnList.data.list).Count -gt 0) {
  $firstTxn = @($payTxnList.data.list)[0]
  Assert-False ($firstTxn.PSObject.Properties.Name -contains 'app_private_key') 'pay transaction list leaked app_private_key'
  Assert-False ($firstTxn.PSObject.Properties.Name -contains 'app_private_key_enc') 'pay transaction list leaked app_private_key_enc'
  $payTxnDetail = Invoke-AdminApi -Method GET -Path ("/api/admin/v1/pay-transactions/{0}" -f $firstTxn.id) -Token $AccessToken
  $summary.pay_transaction_detail_code = $payTxnDetail.code
  Assert-False ($payTxnDetail.data.channel.PSObject.Properties.Name -contains 'app_private_key') 'pay transaction detail leaked app_private_key'
  Assert-False ($payTxnDetail.data.channel.PSObject.Properties.Name -contains 'app_private_key_enc') 'pay transaction detail leaked app_private_key_enc'
}
```

Use existing helper names in the script. If helper names differ, adapt to existing helpers rather than adding a second assertion framework.

- [ ] **Step 5: Run smoke syntax check**

```powershell
cd E:\admin_go\admin_back_go
powershell -NoProfile -ExecutionPolicy Bypass -Command '$null = [scriptblock]::Create((Get-Content -Raw .\scripts\full-admin-smoke.ps1)); "ok"'
```

Expected: `ok`.

---

## Task 5: Migrate frontend PayTransaction API and page table hook

**Files:**
- Modify: `E:/admin_go/admin_front_ts/src/api/pay/transaction.ts`
- Modify: `E:/admin_go/admin_front_ts/src/views/Main/pay/transaction/index.vue`
- Create: `E:/admin_go/admin_front_ts/tests/shared/pay/pay-transaction-api.test.ts`

- [ ] **Step 1: Write API contract test**

Mock `@/lib/http` request object and assert:

```text
init -> request.get('/api/admin/v1/pay-transactions/page-init')
list -> request.get('/api/admin/v1/pay-transactions', { params })
detail -> request.get('/api/admin/v1/pay-transactions/:id')
```

Also assert source does not import `legacyRequest`.

- [ ] **Step 2: Run red test**

```powershell
cd E:\admin_go\admin_front_ts
npx vitest run tests/shared/pay/pay-transaction-api.test.ts
```

Expected: fail while API still uses legacyRequest.

- [ ] **Step 3: Replace API transport**

In `src/api/pay/transaction.ts`:

```ts
import { request } from '@/lib/http'
import { ADMIN_API_PREFIX } from '@/lib/http/api-prefix'
```

Implement facade:

```ts
export const PayTransactionApi = {
  init: () => request.get<PayTransactionInitResponse>(`${ADMIN_API_PREFIX}/pay-transactions/page-init`),
  list: (params: PayTransactionListParams) => request.get<PaginatedResponse<PayTransactionItem>>(`${ADMIN_API_PREFIX}/pay-transactions`, { params: normalizeListParams(params) }),
  detail: (params: { id: number }) => request.get<PayTransactionDetailResponse>(`${ADMIN_API_PREFIX}/pay-transactions/${params.id}`),
}
```

`normalizeListParams` must drop empty string filters and keep typed values. Do not use `Record<string, any>`.

- [ ] **Step 4: Replace useCrudTable with useTable**

In `src/views/Main/pay/transaction/index.vue`:

```ts
import { useTable } from '@/components/Table'
```

Use:

```ts
const {
  loading: listLoading,
  data: listData,
  page,
  getList,
  onPageChange,
  refresh,
  resetPage,
} = useTable<PayTransactionItem, PayTransactionListParams>({
  api: PayTransactionApi,
  searchForm,
})

const onSearch = () => {
  resetPage()
  void getList()
}
```

- [ ] **Step 5: Fix touched TS `any` formatter**

If `index.vue` has formatter args typed `any`, replace with `unknown`:

```ts
formatter: (_r: unknown, _c: unknown, v: number) => `¥${formatFen(v)}`
```

- [ ] **Step 6: Run frontend tests**

```powershell
npx vitest run tests/shared/pay/pay-transaction-api.test.ts
npx vue-tsc -b --pretty false
npx eslint src/api/pay/transaction.ts src/views/Main/pay/transaction/index.vue tests/shared/pay/pay-transaction-api.test.ts
```

Expected: Vitest and vue-tsc pass; eslint has 0 errors. Existing style warnings are acceptable only if they already exist in touched Vue file and are reported clearly.

---

## Task 6: Final verification gate

**Files:**
- All touched files

- [ ] **Step 1: Backend verification**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/enum ./internal/dict ./internal/validate ./internal/module/paytransaction ./internal/server ./internal/bootstrap
go test ./...
go vet ./...
git diff --check
powershell -NoProfile -ExecutionPolicy Bypass -Command '$null = [scriptblock]::Create((Get-Content -Raw .\scripts\full-admin-smoke.ps1)); "ok"'
```

- [ ] **Step 2: Frontend verification**

```powershell
cd E:\admin_go\admin_front_ts
npx vitest run tests/shared/pay/pay-transaction-api.test.ts
npx vue-tsc -b --pretty false
npx eslint src/api/pay/transaction.ts src/views/Main/pay/transaction/index.vue tests/shared/pay/pay-transaction-api.test.ts
```

- [ ] **Step 3: Full smoke**

```powershell
cd E:\admin_go\admin_back_go
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account 15671628271 -Password 123456
```

Expected summary keys include:

```text
pay_transaction_init_code: 0
pay_transaction_list_code: 0
pay_transaction_status_dict_count: 5
pay_transaction_detail_code: 0 when list has rows
```

- [ ] **Step 4: Self-check forbidden patterns**

```powershell
cd E:\admin_go
rg "legacyRequest" admin_front_ts/src/api/pay/transaction.ts admin_front_ts/src/views/Main/pay/transaction -n
rg "any|as any|Record<string, any>" admin_front_ts/src/api/pay/transaction.ts admin_front_ts/src/views/Main/pay/transaction tests/shared/pay/pay-transaction-api.test.ts -n
rg "app_private_key|app_private_key_enc" admin_back_go/internal/module/paytransaction -n
```

Expected:

```text
No legacyRequest in migrated API/page.
No any/as any/Record<string, any> in touched frontend files.
No private-key fields selected or returned by paytransaction module.
```

- [ ] **Step 5: Final report**

Report:

```text
Outcome
Changed files
Backend verification
Frontend verification
Smoke summary
Known remaining payment/wallet modules
Next recommended module
```

Known remaining modules should explicitly list:

```text
pay order admin
user wallet admin and wallet transaction read/adjust
pay notify log
pay reconcile read/retry/download
app-side recharge/createPay/cancel/query wallet endpoints
payment callback/runtime SDK
reconciliation execution
refund product scope closed, not a remaining module
```
