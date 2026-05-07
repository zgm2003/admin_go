# Payment Domain Completion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish the payment domain as a staged Go-owned runtime: certificates are already Go-owned, PayReconcile admin REST is already migrated, and the remaining work is PayReconcile cron/runtime, fulfillment retry cron, explicit WeChat/refund decisions, docs/smoke truth, and final gates.

**Architecture:** Keep the existing Gin modular monolith. `admin-api` owns REST handlers only; `admin-worker` owns DB-backed scheduler and Asynq handlers; payment SDK/network clients stay under `internal/platform/payment/*`; payment state transitions stay in module services and repositories.

**Tech Stack:** Go 1.26 module as currently declared, Gin, Gorm, MySQL, Redis lock, Asynq wrapper, gocron/v2, Vue 3/Vite, Vitest, existing `github.com/go-pay/gopay` Alipay boundary.

---

## Master rule

This is a payment-only plan. Do not touch AI/chat/upload/client-version or other business modules except shared docs/status files that must mention payment truth.

## Current baseline already done

```text
P0 certificate ownership: done.
P1a PayReconcile admin REST/API: done.
```

Evidence to keep intact:

```text
admin_back_go/runtime/cert/alipay/appPublicCert.crt
admin_back_go/runtime/cert/alipay/alipayPublicCert.crt
admin_back_go/runtime/cert/alipay/alipayRootCert.crt
admin_back_go/.env.example has PAYMENT_CERT_BASE_DIR=E:/admin_go/admin_back_go and LEGACY_ADMIN_BACK_ROOT=
admin_back_go/internal/module/payreconcile exists
admin_front_ts/src/api/pay/reconcile.ts uses request + /api/admin/v1/pay-reconcile-tasks
admin_front_ts/tests/shared/pay/pay-reconcile-api.test.ts forbids legacyRequest and /api/admin/PayReconcile/
```

Do not redo these as new features. Only verify and document them.

## Current DB facts

```text
pay_channel has no supported_methods column; supported methods live in extra_config.supported_methods.
Only active channel row is Alipay sandbox: channel=2, status=1, is_del=2, supported_methods=[web,h5].
No active WeChat pay_channel exists.
pay_refunds count=0.
pay_refund_sync cron row exists but is_del=1.
```

Active payment cron truth:

```text
pay_close_expired_order       pay:close-expired-order:v1       is_del=2
pay_sync_pending_transaction  pay:sync-pending-transaction:v1  is_del=2
pay_fulfillment_retry         pay:fulfillment-retry:v1         is_del=2 after Go migration
pay_reconcile_daily           pay:reconcile-daily:v1           is_del=2 after Go migration
pay_reconcile_execute         pay:reconcile-execute:v1         is_del=2 after Go migration
pay_refund_sync               app\process\Pay\PayRefundSyncTask        is_del=1
```

## File map

### Verify / doc sync for completed slices

- Modify `docs/migration/current-status.md`
- Modify `docs/contracts/admin-api-v1.md`
- Modify `docs/testing/smoke-matrix.md`
- Modify `admin_back_go/docs/architecture.md`
- Modify `docs/superpowers/specs/2026-05-07-payment-domain-completion-design.md`
- Modify `docs/superpowers/plans/2026-05-07-payment-domain-completion.md`

### PayReconcile cron/runtime

- Create `admin_back_go/internal/module/payreconcile/jobs.go`
- Create `admin_back_go/internal/module/payreconcile/jobs_test.go`
- Extend `admin_back_go/internal/module/payreconcile/dto.go`
- Extend `admin_back_go/internal/module/payreconcile/repository.go`
- Extend `admin_back_go/internal/module/payreconcile/service.go`
- Extend `admin_back_go/internal/module/payreconcile/service_test.go`
- Modify `admin_back_go/internal/module/crontask/registry.go`
- Modify `admin_back_go/internal/module/crontask/registry_test.go`
- Modify `admin_back_go/internal/module/crontask/scheduler_service_test.go`
- Modify `admin_back_go/internal/jobs/noop.go`
- Modify `admin_back_go/internal/jobs/noop_test.go`
- Modify `admin_back_go/internal/bootstrap/app.go` and worker dependency wiring only if `jobs.Dependencies` requires new service field
- Create `admin_back_go/database/migrations/20260507_pay_reconcile_go_handlers.sql`

### Fulfillment retry cron

- Extend `admin_back_go/internal/module/payruntime/dto.go`
- Extend `admin_back_go/internal/module/payruntime/repository.go`
- Extend `admin_back_go/internal/module/payruntime/service.go`
- Extend `admin_back_go/internal/module/payruntime/service_test.go`
- Extend `admin_back_go/internal/module/payruntime/jobs.go`
- Extend `admin_back_go/internal/module/payruntime/jobs_test.go`
- Modify `admin_back_go/internal/module/crontask/registry.go`
- Modify `admin_back_go/internal/module/crontask/registry_test.go`
- Modify `admin_back_go/internal/jobs/noop.go`
- Create `admin_back_go/database/migrations/20260507_pay_fulfillment_retry_go_handler.sql`

### Smoke / contract gate

- Modify `admin_back_go/scripts/full-admin-smoke.ps1`
- Modify `docs/testing/smoke-matrix.md`
- Modify `docs/contracts/admin-api-v1.md`
- Modify `docs/migration/current-status.md`

## Task 0: Baseline freeze and no-overclaim gate

- [x] Check dirty state before touching anything else.

```powershell
cd E:/admin_go
git status --short
git -C admin_back_go status --short
git -C admin_front_ts status --short
```

Expected:

```text
Only payment docs/code changes and known unrelated docs/deployment changes are present.
Do not revert unrelated dirty files.
```

- [x] Verify completed certificate gate.

```powershell
cd E:/admin_go/admin_back_go
powershell -ExecutionPolicy Bypass -File .\scripts\check-payment-certs.ps1 -DisallowLegacyRoot
go test ./internal/platform/payment ./internal/config ./internal/module/payruntime
```

Expected:

```text
check script prints only path/bytes/sha256 under E:/admin_go/admin_back_go.
go test passes.
```

- [x] Verify PayReconcile admin REST already works.

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/module/payreconcile ./internal/server ./internal/bootstrap

cd E:/admin_go/admin_front_ts
npx vitest run tests/shared/pay
```

Expected:

```text
PayReconcile backend tests pass.
Pay shared Vitest tests pass.
```

- [x] Verify no payment frontend legacy client remains.

```powershell
cd E:/admin_go
rg -n "legacyRequest" admin_front_ts/src/api/pay admin_front_ts/src/views/Main/pay admin_front_ts/src/views/Main/wallet
```

Expected:

```text
No output. ripgrep exit code 1 is acceptable for no matches.
```

## Task 1: Sync docs to current payment truth

Purpose: fix stale docs that still say PayReconcile REST/front/cron or fulfillment retry are planned or legacy.

- [x] Update `docs/contracts/admin-api-v1.md` Pay Reconcile section.

Replace old status paragraphs that claimed PayReconcile admin REST/front/cron was still planned with exact current status:

```text
状态：admin REST implemented, worker runtime first version implemented. 管理接口和前端 API 已迁 Go REST；`pay_reconcile_daily` 和 `pay_reconcile_execute` 已注册 Go handler；daily 幂等创建任务，execute 已实现 Alipay trade bill 下载、UTF-8/GBK CSV/zip 解析、本地/平台/diff CSV 输出和 success/diff/failed 状态；平台网络/下载/解析失败不能 fake success。
```

Keep routes as implemented routes, not planned routes.

- [x] Update `docs/testing/smoke-matrix.md` Pay Reconcile row.

Required wording:

```text
pay reconcile admin/runtime | no | planned read-only probe | Go REST page-init/list/detail/retry/file implemented; cron pay_reconcile_daily/pay_reconcile_execute registered to Go task type handlers; execute downloads/parses Alipay trade bill, writes local/platform/diff CSV, and marks success/diff/failed explicitly | no by default | n/a | front API no longer uses legacyRequest; smoke still needs read-only probe and cron registry gate; real platform bill download remains outside default smoke
```

- [x] Update `docs/migration/current-status.md` only if it lacks a PayReconcile admin REST row.

Required row semantics:

```text
pay reconcile admin/runtime | implemented first version: REST page-init/list/detail/retry/file plus worker pay:reconcile-daily:v1/pay:reconcile-execute:v1; daily creates tasks; execute downloads/parses Alipay trade bill, writes local/platform/diff CSV, and marks success/diff/failed explicitly | adapted: src/api/pay/reconcile.ts uses Go REST, no legacyRequest | internal/module/payreconcile + platform alipay + frontend Vitest | smoke pending | contract + payment spec/plan | no fake success; real sandbox bill availability still needs manual/special probe
```

- [x] Run docs grep.

```powershell
cd E:/admin_go
rg -n "仍走 legacyRequest|显式 legacy adapter|迁移前不能写成 Go 已完成|当前未实现；前端" docs/migration/current-status.md docs/contracts/admin-api-v1.md docs/testing/smoke-matrix.md docs/superpowers
```

Expected:

```text
No stale statement saying PayReconcile admin REST or front API is still legacy.
It is OK to say real sandbox platform bill download is not auto-smoked; do not say fake bill tests prove platform E2E.
```

## Task 2: PayReconcile cron task types and handler wiring

Purpose: add real task types and queue handlers; no business fake/noop.

- [x] Write failing `admin_back_go/internal/module/payreconcile/jobs_test.go`.

Test content must cover:

```go
func TestNewReconcileDailyTaskEncodesPayload(t *testing.T) {
    task, err := NewReconcileDailyTask(ReconcileDailyPayload{Date: "2026-05-06", Limit: 20})
    if err != nil { t.Fatalf("NewReconcileDailyTask returned error: %v", err) }
    if task.Type != TypeReconcileDailyV1 { t.Fatalf("unexpected type: %s", task.Type) }
    if task.Queue != taskqueue.QueueLow { t.Fatalf("unexpected queue: %s", task.Queue) }
    if task.UniqueTTL <= 0 { t.Fatalf("expected unique ttl") }
    payload, err := DecodeReconcileDailyPayload(task.Payload)
    if err != nil { t.Fatalf("decode: %v", err) }
    if payload.Date != "2026-05-06" || payload.Limit != 20 { t.Fatalf("unexpected payload: %#v", payload) }
}

func TestRegisterHandlersWiresReconcileTasks(t *testing.T) {
    mux := taskqueue.NewMux()
    service := &fakeReconcileJobService{}
    RegisterHandlers(mux, service, nil)
    dailyTask, _ := NewReconcileDailyTask(ReconcileDailyPayload{Date: "2026-05-06", Limit: 2})
    executeTask, _ := NewReconcileExecuteTask(ReconcileExecutePayload{TaskID: 9, Limit: 3})
    if err := mux.ProcessProjectTask(context.Background(), dailyTask); err != nil { t.Fatalf("daily: %v", err) }
    if err := mux.ProcessProjectTask(context.Background(), executeTask); err != nil { t.Fatalf("execute: %v", err) }
    if service.dailyDate != "2026-05-06" || service.dailyLimit != 2 || service.executeTaskID != 9 || service.executeLimit != 3 {
        t.Fatalf("unexpected calls: %#v", service)
    }
}
```

- [x] Implement `admin_back_go/internal/module/payreconcile/jobs.go`.

Required constants:

```go
const (
    TypeReconcileDailyV1 = "pay:reconcile-daily:v1"
    TypeReconcileExecuteV1 = "pay:reconcile-execute:v1"
)
```

Required payloads:

```go
type ReconcileDailyPayload struct {
    Date string `json:"date,omitempty"`
    Limit int `json:"limit,omitempty"`
}

type ReconcileExecutePayload struct {
    TaskID int64 `json:"task_id,omitempty"`
    Limit int `json:"limit,omitempty"`
}
```

Required service interface:

```go
type JobService interface {
    CreateDailyTasks(ctx context.Context, input CreateDailyTasksInput) (*CreateDailyTasksResult, error)
    ExecutePendingTasks(ctx context.Context, input ExecutePendingTasksInput) (*ExecutePendingTasksResult, error)
    ExecuteTask(ctx context.Context, taskID int64) (*ExecuteTaskResult, error)
}
```

Handler rule:

```text
ReconcileExecutePayload.TaskID > 0 calls ExecuteTask.
TaskID == 0 calls ExecutePendingTasks with Limit.
```

- [x] Wire queue handler registration in `internal/jobs/noop.go`.

Add dependency:

```go
PayReconcileService payreconcile.JobService
```

Register:

```go
payreconcile.RegisterHandlers(mux, deps.PayReconcileService, logger)
```

- [x] Add default registry entries in `internal/module/crontask/registry.go`.

```go
registry.Register(RegistryEntry{
    Name: "pay_reconcile_daily",
    TaskType: payreconcile.TypeReconcileDailyV1,
    Description: "按支付渠道创建每日对账任务",
    BuildTask: func() (taskqueue.Task, error) {
        return payreconcile.NewReconcileDailyTask(payreconcile.ReconcileDailyPayload{})
    },
})
registry.Register(RegistryEntry{
    Name: "pay_reconcile_execute",
    TaskType: payreconcile.TypeReconcileExecuteV1,
    Description: "执行待处理支付对账任务",
    BuildTask: func() (taskqueue.Task, error) {
        return payreconcile.NewReconcileExecuteTask(payreconcile.ReconcileExecutePayload{})
    },
})
```

- [x] Update registry tests.

Expected:

```text
NewDefaultRegistry.Lookup("pay_reconcile_daily").TaskType == payreconcile.TypeReconcileDailyV1
NewDefaultRegistry.Lookup("pay_reconcile_execute").TaskType == payreconcile.TypeReconcileExecuteV1
SchedulerService registers those rows only by registry name and enqueues matching task type.
```

- [x] Run tests.

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/module/payreconcile ./internal/module/crontask ./internal/jobs ./internal/bootstrap
```

Expected:

```text
Tests pass. No noop handler used for payment reconcile.
```

## Task 3: PayReconcile daily task creation

Purpose: implement idempotent daily task creation. Do not download bills yet.

- [x] Extend DTO.

Add:

```go
type CreateDailyTasksInput struct {
    Date string
    Limit int
    Now time.Time
}

type CreateDailyTasksResult struct {
    Date string
    Scanned int
    Created int
    Existing int
    Skipped int
}
```

- [x] Extend repository interface.

```go
ActivePayChannels(ctx context.Context) ([]ChannelSummary, error)
FindReconcileTask(ctx context.Context, channelID int64, date time.Time, billType int) (*Task, error)
CreateReconcileTask(ctx context.Context, task Task) error
```

`ActivePayChannels` already exists; reuse it.

- [x] Write failing service tests.

Test cases:

```text
empty input date uses yesterday based on service.now.
creates one pending BillTypePay task per active channel.
if task exists for channel/date/bill_type, increments Existing and does not duplicate.
Limit caps active channels processed.
```

- [x] Implement `Service.CreateDailyTasks`.

Rules:

```text
Date format is yyyy-mm-dd; invalid date returns error.
Default date is yesterday.
Default limit is 100; max is enum.PageSizeMax or explicit small cap.
Created task fields: reconcile_date, channel, channel_id, bill_type=1, status=ReconcilePending, is_del=2, created_at/updated_at.
Idempotency is repository lookup before insert plus duplicate-key safe handling if possible.
```

- [x] Run tests.

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/module/payreconcile
```

## Task 4: PayReconcile execute task first real version

Purpose: implement real state transitions and local bill generation; third-party unsupported must fail loudly, not silently pass.

- [x] Add DTOs.

```go
type ExecutePendingTasksInput struct {
    Limit int
    Now time.Time
}

type ExecutePendingTasksResult struct {
    Scanned int
    Success int
    Diff int
    Failed int
    Skipped int
}

type ExecuteTaskResult struct {
    TaskID int64
    Status int
    PlatformCount int
    PlatformAmount int64
    LocalCount int
    LocalAmount int64
    DiffCount int
    DiffAmount int64
}
```

- [x] Extend repository for execution.

```go
ListPendingTasks(ctx context.Context, limit int) ([]Task, error)
GetTaskForUpdate(ctx context.Context, id int64) (*Task, error)
MarkTaskStatus(ctx context.Context, id int64, status int, fields map[string]any) error
ListSuccessfulTransactionsForBill(ctx context.Context, channelID int64, date time.Time) ([]BillTransactionRow, error)
WithTx(ctx context.Context, fn func(Repository) error) error
```

- [x] Add `BillTransactionRow`.

```go
type BillTransactionRow struct {
    TransactionNo string
    TradeNo string
    Amount int64
    Status int
    PaidAt time.Time
}
```

- [x] Write failing service tests.

Test cases:

```text
ExecutePendingTasks scans pending tasks and calls ExecuteTask.
ExecuteTask rejects non-pending/non-failed tasks as skipped/conflict.
ExecuteTask for unsupported non-Alipay channel marks failed with clear error.
ExecuteTask writes local bill counts/amount and local_file_url for Alipay path even if platform download is not yet available.
State transitions include download/comparing/failed or success/diff.
```

- [x] Implement minimal real execution.

Acceptable first version:

```text
Alipay platform bill download is implemented through the Go payment gateway.
On platform/network/download/parser error, task status becomes failed.
Do not mark success without platform bill comparison.
Do not fake platform_count/platform_amount.
```

- [x] Persist report files.

Use:

```text
admin_back_go/runtime/reconcile_reports/YYYY-MM-DD/<task_id>-local.csv
admin_back_go/runtime/reconcile_reports/YYYY-MM-DD/<task_id>-platform.csv
admin_back_go/runtime/reconcile_reports/YYYY-MM-DD/<task_id>-diff.csv
```

Rules:

```text
Create directories 0755.
Write CSV, not JSON blob in DB.
Store relative URL/path in pay_reconcile_tasks.*_file_url.
Do not write cert/private key contents.
```

- [x] Run tests.

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/module/payreconcile ./internal/module/crontask ./internal/jobs ./internal/bootstrap
```

## Task 5: DB migration for PayReconcile cron handlers

- [x] Create `admin_back_go/database/migrations/20260507_pay_reconcile_go_handlers.sql`.

SQL:

```sql
-- Pay reconcile cron tasks now map to Go registry task types.
UPDATE `cron_task`
SET `handler` = 'pay:reconcile-daily:v1',
    `updated_at` = NOW()
WHERE `name` = 'pay_reconcile_daily'
  AND `is_del` = 2;

UPDATE `cron_task`
SET `handler` = 'pay:reconcile-execute:v1',
    `updated_at` = NOW()
WHERE `name` = 'pay_reconcile_execute'
  AND `is_del` = 2;
```

- [x] Add/adjust tests proving registry/task type mapping.

Run:

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/module/crontask ./internal/jobs ./internal/module/payreconcile
```

Expected:

```text
pay_reconcile_daily and pay_reconcile_execute are registered in Go registry.
No PHP handler is executed by scheduler.
```

## Task 6: Fulfillment retry task type and handler wiring

Purpose: wire real task type first, then implement service. No noop.

- [x] Extend `payruntime/jobs.go`.

Add:

```go
const TypeFulfillmentRetryV1 = "pay:fulfillment-retry:v1"

type FulfillmentRetryPayload struct {
    Limit int `json:"limit,omitempty"`
}
```

- [x] Extend `JobService`.

```go
RetryFailedFulfillments(ctx context.Context, input FulfillmentRetryInput) (*FulfillmentRetryResult, error)
```

- [x] Add task builder/decoder/handler.

```go
NewFulfillmentRetryTask(FulfillmentRetryPayload{Limit: n})
DecodeFulfillmentRetryPayload(payload)
RegisterHandlers wires TypeFulfillmentRetryV1
```

- [x] Update `jobs_test.go` fake service and tests.

Test must prove:

```text
payload Limit survives encode/decode.
handler calls RetryFailedFulfillments with Limit.
```

- [x] Add crontask registry entry.

```go
Name: "pay_fulfillment_retry"
TaskType: payruntime.TypeFulfillmentRetryV1
Description: "重试失败的支付履约任务"
BuildTask: payruntime.NewFulfillmentRetryTask(payruntime.FulfillmentRetryPayload{})
```

- [x] Run tests.

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/module/payruntime ./internal/module/crontask ./internal/jobs ./internal/bootstrap
```

Expected:

```text
Task type is wired, but service implementation must be real before DB migration is applied.
```

## Task 7: Fulfillment retry service implementation

- [x] Read legacy facts before coding.

Required files:

```text
E:/admin/admin_back/app/process/Pay/PayFulfillmentRetryTask.php
E:/admin/admin_back/app/queue/redis/slow/PayOrderFulfillment.php
E:/admin/admin_back/app/service/Pay/PayDomainService.php
E:/admin/admin_back/app/service/Pay/WalletService.php
```

- [x] Add DTOs.

```go
type FulfillmentRetryInput struct {
    Limit int
    Now time.Time
}

type FulfillmentRetryResult struct {
    Scanned int
    Retried int
    Success int
    Failed int
    Skipped int
}

type RetryableFulfillment struct {
    ID int64
    FulfillNo string
    OrderID int64
    OrderNo string
    SourceTxnID int64
    IdempotencyKey string
    RetryCount int
}
```

- [x] Extend repository.

```go
ListRetryableFulfillments(ctx context.Context, now time.Time, limit int) ([]RetryableFulfillment, error)
GetFulfillmentForUpdate(ctx context.Context, id int64) (*OrderFulfillment, error)
MarkFulfillmentRunning(ctx context.Context, id int64, now time.Time) error
MarkFulfillmentFailed(ctx context.Context, id int64, retryCount int, nextRetryAt *time.Time, lastError string, now time.Time) error
MarkFulfillmentManual(ctx context.Context, id int64, lastError string, now time.Time) error
```

- [x] Write failing tests.

Test cases:

```text
retry scans only failed/pending due rows.
retry of already credited recharge returns success/skipped without new wallet transaction.
max retry exceeded marks manual or remains failed with no immediate retry.
successful retry uses existing MarkPaySuccessAndCreditRecharge path and does not duplicate balance.
```

- [x] Implement service.

Rules:

```text
Default limit 50.
Only action_type=FulfillActionRecharge is eligible now.
Use order_fulfillments.idempotency_key and wallet_transactions.biz_action_no as duplicate guards.
Do not write a second wallet-credit implementation if existing MarkPaySuccessAndCreditRecharge can be reused.
Network SDK is not needed for fulfillment retry; it retries local fulfillment after payment success already exists.
```

- [x] Create DB migration `admin_back_go/database/migrations/20260507_pay_fulfillment_retry_go_handler.sql`.

```sql
-- Payment fulfillment retry now maps to a Go registry task type.
UPDATE `cron_task`
SET `handler` = 'pay:fulfillment-retry:v1',
    `updated_at` = NOW()
WHERE `name` = 'pay_fulfillment_retry'
  AND `is_del` = 2;
```

- [x] Run tests.

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/module/payruntime ./internal/module/crontask ./internal/jobs ./internal/bootstrap
```

Expected:

```text
pay_fulfillment_retry is a real registered handler; duplicate retry does not duplicate wallet balance.
```

## Task 8: WeChat and refund decision docs

- [x] Document WeChat not active using correct schema facts.

Use this SQL shape, not a nonexistent `supported_methods` column:

```sql
SELECT id,name,channel,status,is_del,notify_url,public_cert_path,platform_cert_path,root_cert_path,extra_config
FROM pay_channel
WHERE channel = 1
ORDER BY id;
```

Required docs wording:

```text
WeChat payment runtime is not active: current DB has no active channel=1 row. Go does not implement /api/pay/notify/wechat. If a WeChat channel is later enabled, write a dedicated WeChat runtime spec before coding.
```

- [x] Document refund retired/pending-decision.

SQL facts:

```sql
SELECT COUNT(*) AS refund_count FROM pay_refunds;
SELECT id,name,status,handler,is_del FROM cron_task WHERE name='pay_refund_sync';
```

Required docs wording:

```text
Refund runtime is retired/pending-decision: pay_refunds count is 0 and pay_refund_sync is_del=1. Do not register pay_refund_sync until a refund contract exists.
```

- [x] Update docs:

```text
docs/migration/current-status.md
docs/contracts/admin-api-v1.md
docs/testing/smoke-matrix.md
admin_back_go/docs/architecture.md
```

## Task 9: Full payment verification gate

- [x] Run backend payment tests.

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/platform/payment ./internal/platform/payment/alipay
go test ./internal/module/paychannel ./internal/module/paytransaction ./internal/module/paynotifylog ./internal/module/payorder ./internal/module/wallet ./internal/module/payruntime ./internal/module/payreconcile
go test ./internal/module/crontask ./internal/jobs ./internal/bootstrap ./internal/server
```

- [x] Run frontend pay tests.

```powershell
cd E:/admin_go/admin_front_ts
npx vitest run tests/shared/pay
npx vue-tsc -b --pretty false
```

- [x] Run payment cert gate.

```powershell
cd E:/admin_go/admin_back_go
powershell -ExecutionPolicy Bypass -File .\scripts\check-payment-certs.ps1 -DisallowLegacyRoot
```

- [x] Run frontend legacy gate.

```powershell
cd E:/admin_go
rg -n "legacyRequest" admin_front_ts/src/api/pay admin_front_ts/src/views/Main/pay admin_front_ts/src/views/Main/wallet
```

Expected:

```text
No output.
```

- [x] Run contract gate.

```powershell
cd E:/admin_go/admin_back_go
powershell -ExecutionPolicy Bypass -File .\scripts\check-contract.ps1
```

- [x] Run full smoke.

```powershell
cd E:/admin_go/admin_back_go
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account 15671628271 -Password 123456
```

Optional runtime probe only when intentionally creating sandbox order/pay attempt:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account 15671628271 -Password 123456 -EnablePaymentRuntimeProbe
```

Do not claim real paid callback unless a manual Alipay sandbox payment actually happens and DB effects are checked.

## Done criteria

```text
1. Go-owned cert check passes with LEGACY_ADMIN_BACK_ROOT empty.
2. PayReconcile admin REST/front uses Go request and has tests.
3. pay_reconcile_daily/pay_reconcile_execute are registered to real Go task handlers, not noop.
4. pay_fulfillment_retry is registered to a real Go task handler, not noop.
5. pay_refund_sync is explicitly retired/pending-decision or implemented by a separate refund spec.
6. WeChat runtime is explicitly not active or implemented by a separate WeChat spec.
7. Targeted Go tests pass.
8. Targeted frontend pay tests pass.
9. Full smoke payment read path passes.
10. Docs do not claim unimplemented payment slices are done.
```

## Execution order

```text
0. Baseline freeze and verify completed slices
1. Docs truth sync
2. PayReconcile task type/handler wiring
3. PayReconcile daily task creation
4. PayReconcile execute first real version
5. PayReconcile DB handler migration
6. Fulfillment retry task wiring
7. Fulfillment retry service and migration
8. WeChat/refund decision docs
9. Full verification gate
```

Never start a DB handler migration before the Go handler and tests exist. A cron row pointing at a non-working Go handler is just a new kind of broken.
