# Known Issues and WIP

状态更新时间：2026-05-30

本文只记录当前已知 bug、失败测试和未闭环 WIP。这里的内容不是 verified change-log；修复完成前不得把它写成 implemented。

## Current open issues

```text
None.
```

## Resolved on 2026-05-30

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

Fresh reproduction from the current worktree on 2026-05-30 still fails at the wallet repository boundary:

```text
repository_test.go:130: expected duplicate transaction_no to retry
next expectation is: ExpectedExec => INSERT INTO `wallet_transactions`
actual call: SELECT * FROM `wallet_transactions` ... FOR UPDATE
```

Failure meaning:

```text
The no-wrap serial generator direction is covered, but wallet duplicate uk_wallet_transaction_no retry is not implemented.
The current wallet test expects retry insert after transaction_no collision; current production code treats every duplicate key as a possible source race first and performs a source FOR UPDATE lookup instead.
CreditRecharge inserts the same wallet_transactions unique-key surface but has no duplicate transaction_no retry branch.
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
