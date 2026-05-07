# Pay Runtime Cron Migration Design

## Outcome

Migrate the first legacy payment cron slice from PHP Webman to Go without changing product scope. The Go runtime remains Alipay-only. We will migrate the two compensation tasks that keep recharge orders clean:

```text
pay_close_expired_order       -> pay:close-expired-order:v1
pay_sync_pending_transaction  -> pay:sync-pending-transaction:v1
```

This reuses the already-proven Go cron path from `notification_task_scheduler -> notification:dispatch-due:v1`: `cron_task` is the DB truth, `admin-worker` registers only known Go registry entries, scheduler callbacks only write `cron_task_log` and enqueue Asynq tasks, and task handlers own business work.

## Legacy behavior source

Legacy PHP facts:

```text
config/process.php registers PayCloseExpiredOrderTask and PaySyncPendingTransactionTask.
PayEnum::ORDER_EXPIRE_SECONDS = 1800.
RechargeModule writes expire_time = now + 1800 seconds.
PayCloseExpiredOrderTask scans expired pending/paying orders in batches of 50.
PaySyncPendingTransactionTask scans created/waiting transactions older than 5 minutes in batches of 100.
Both paths query third-party status before mutating local state.
```

Live DB currently has enabled rows:

```text
pay_close_expired_order       cron=0 * * * * *     handler=app\process\Pay\PayCloseExpiredOrderTask
pay_sync_pending_transaction  cron=0 */5 * * * *   handler=app\process\Pay\PaySyncPendingTransactionTask
```

Go must preserve the `name` values and replace runtime execution with versioned task types through registry metadata. PHP handler strings remain provenance for missing rows only, not executable code.

## Scope

### In scope for this slice

- Register `pay_close_expired_order` in Go cron registry.
- Register `pay_sync_pending_transaction` in Go cron registry.
- Add queue tasks and handlers under `internal/module/payruntime`.
- Add service methods for:
  - close expired recharge orders;
  - sync pending Alipay transactions.
- Add repository methods for scanning and locking the needed rows.
- Add Alipay gateway `Query` and `Close` operations.
- Update docs/contracts/current-status to stop calling old expired close "planned" after implementation.
- Unit-test service behavior, task payload decoding, handler registration, and registry mapping.

### Out of scope for this slice

- WeChat runtime. It is explicitly outside product scope.
- Refund. It is intentionally out of product scope, not a future migration item.
- Reconciliation execution.
- Fulfillment retry cron.
- Frontend UI redesign.
- Dynamic execution of PHP handler strings.

## Architecture

### Task names

```text
cron_task.name=pay_close_expired_order       -> task type pay:close-expired-order:v1
cron_task.name=pay_sync_pending_transaction  -> task type pay:sync-pending-transaction:v1
```

Payloads are intentionally small and optional:

```json
{ "limit": 50 }
{ "limit": 100 }
```

If omitted, service defaults match PHP behavior.

### Service responsibilities

`payruntime.Service` owns the payment state machine. Handler only decodes payload and calls service. Repository only performs DB reads/writes.

Close expired flow:

```text
1. now := service clock
2. cutoff := now - 30 minutes
3. repository finds recharge orders where pay_status in pending/paying and expire_time <= cutoff
4. for each order, acquire pay_create_txn_{order_no} lock
5. lock order row in DB and skip if no longer pending/paying
6. find latest active transaction
7. if no active transaction: locally close order
8. if active transaction: query Alipay using transaction_no/trade_no
9. if Alipay says paid: call existing MarkPaySuccessAndCreditRecharge
10. if Alipay says not paid: close local order, close active transaction, call Alipay close best-effort
11. if Alipay query errors: count deferred and leave state unchanged
```

Pending sync flow:

```text
1. cutoff := now - 5 minutes
2. repository finds active Alipay transactions older than cutoff whose orders are pending/paying
3. for each transaction, query Alipay
4. if paid: call existing MarkPaySuccessAndCreditRecharge
5. if not paid: keep state unchanged
6. if query errors: count deferred and leave state unchanged
```

### Gateway responsibilities

The Alipay gateway owns SDK calls only:

```go
Query(ctx, cfg, QueryRequest) (*QueryResult, error)
Close(ctx, cfg, CloseRequest) error
```

`QueryResult` exposes the stable facts service needs:

```text
OutTradeNo
TradeNo
TradeStatus
TotalAmountCents
Raw
```

Paid statuses are only:

```text
TRADE_SUCCESS
TRADE_FINISHED
```

Other statuses are not paid.

### Safety rules

- No network I/O inside DB transactions.
- No wallet mutation outside `MarkPaySuccessAndCreditRecharge`.
- No duplicate credit: existing idempotency remains the only wallet credit path.
- Best-effort Alipay close must not roll back local close.
- Unknown or non-Alipay channel is skipped/deferred; this project does not migrate WeChat runtime.
- Scheduler callback never scans business DB.

## Testing

Required Go tests:

```text
go test ./internal/module/payruntime ./internal/module/crontask ./internal/jobs ./internal/bootstrap
```

Target checks:

- `NewCloseExpiredOrderTask` and `NewSyncPendingTransactionTask` encode payloads and set unique TTLs.
- `RegisterHandlers` wires both pay runtime task types.
- `crontask.NewDefaultRegistry()` maps both legacy names to versioned task types.
- close-expired closes stale unpaid order and active transaction after unpaid Alipay query.
- close-expired marks paid and credits wallet when Alipay query returns paid.
- close-expired defers on gateway query error without closing.
- pending-sync marks paid when Alipay query returns paid.
- pending-sync leaves unpaid transaction unchanged.

## Documentation updates

Update:

```text
docs/migration/current-status.md
docs/contracts/admin-api-v1.md
admin_back_go/docs/architecture.md
docs/testing/smoke-matrix.md if needed
```

The docs must say:

```text
Alipay close-expired and pending-sync cron are implemented through Go cron registry + Asynq handlers.
WeChat remains out of scope.
Reconciliation/fulfillment retry remain separate slices. Refund remains out of product scope.
```
