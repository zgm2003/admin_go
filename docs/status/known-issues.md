# Known Issues and WIP

状态更新时间：2026-05-30

本文只记录当前已知 bug、失败测试和未闭环 WIP。这里的内容不是 verified change-log；修复完成前不得把它写成 implemented。

## Current open issues

```text
None.
```

## Resolved on 2026-05-30

### PAY-HARDEN-002 payment close/finalizer/parser/frontend permission follow-up

Status: fixed and verified after the payment-only bug audit.

Pre-fix failures:

```text
SyncOrder TRADE_CLOSED and expired ACQ.TRADE_NOT_EXIST closed payment_orders but left linked payment_recharges open.
FinalizeOrderPaid could leave order/recharge paid but wallet uncredited after CreditRecharge failure; SyncPendingOrders scanned only paying orders.
Alipay amount parser accepted signed cent fragments such as 10.-1.
/payment/recharge checkout could call add without payment_recharge_add frontend permission.
paid and credited both rendered as success, hiding paid-but-not-credited state.
```

Fixed paths:

```text
admin_back_go/internal/module/payment/order_service.go
admin_back_go/internal/module/payment/job_service.go
admin_back_go/internal/module/payment/recharge_repository.go
admin_back_go/internal/infra/payment/alipay/gateway.go
admin_front_ts/src/views/Main/payment/recharge/**
```

Verified after implementation:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/payment ./internal/infra/payment/alipay -count=1
go test ./internal/module/payment/... ./internal/infra/payment/alipay -count=1
go test ./internal/module/payment ./internal/module/payment/... ./internal/infra/payment/alipay ./internal/module/crontask ./internal/bootstrap ./internal/middleware ./internal/server -count=1
go vet ./internal/module/payment/... ./internal/infra/payment/alipay

cd E:\admin_go\admin_front_ts
npm test -- tests/shared/payment/payment-recharge-page.test.ts
npm test -- tests/shared/payment/payment-config-api.test.ts tests/shared/payment/payment-config-page.test.ts tests/shared/payment/payment-order-api.test.ts tests/shared/payment/payment-order-page.test.ts tests/shared/payment/payment-recharge-api.test.ts tests/shared/payment/payment-recharge-page.test.ts tests/shared/wallet/wallet-api.test.ts tests/shared/wallet/wallet-pages.test.ts
npm run build:check
```

### PAY-WALLET-001 wallet transaction_no collision follow-up

Status: fixed and verified after user confirmed "修吧".

### Evidence

Fixed backend files:

```text
admin_back_go/internal/module/payment/serialno/serial_no.go
admin_back_go/internal/module/payment/serialno/serial_no_test.go
admin_back_go/internal/module/payment/recharge_repository.go
admin_back_go/internal/module/payment/recharge_repository_test.go
admin_back_go/internal/module/payment/wallet/repository.go
admin_back_go/internal/module/payment/wallet/repository_test.go
```

Root cause evidence:

```text
wallet_transactions.transaction_no has unique key uk_wallet_transaction_no
old serialno.New used seq % 1_000_000, so same prefix + second + nanosecond can wrap after one million calls
Consume duplicate-key handling currently treats every duplicate key as a possible source idempotency race first
CreditRecharge does not retry duplicate transaction_no
```

Original failing verification:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/payment/serialno ./internal/module/payment/wallet -count=1
```

Observed result on 2026-05-30:

```text
ok   admin_back_go/internal/module/payment/serialno
FAIL admin_back_go/internal/module/payment/wallet
FAIL TestRepositoryConsumeRetriesDuplicateTransactionNo
```

Pre-fix reproduction from the 2026-05-30 worktree failed at the wallet repository boundary:

```text
repository_test.go:130: expected duplicate transaction_no to retry
next expectation is: ExpectedExec => INSERT INTO `wallet_transactions`
actual call: SELECT * FROM `wallet_transactions` ... FOR UPDATE
```

Pre-fix failure meaning:

```text
The no-wrap serial generator direction was covered, but wallet duplicate uk_wallet_transaction_no retry was not implemented.
The wallet test expected retry insert after transaction_no collision; production code treated every duplicate key as a possible source race first and performed a source FOR UPDATE lookup instead.
CreditRecharge inserted the same wallet_transactions unique-key surface but had no duplicate transaction_no retry branch.
```

### Implemented path

The confirmed fix used Option B:

```text
Keep the serialno no-wrap root fix.
Retry uk_wallet_transaction_no insert collisions with a finite 3-attempt retry.
Preserve uk_wallet_transaction_source idempotency behavior for consume source races.
Apply the same transaction_no retry path to recharge credit.
```

Verified after implementation:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/payment/serialno ./internal/module/payment/wallet ./internal/module/payment -count=1
go test ./internal/module/payment/... -count=1
git diff --check
```
