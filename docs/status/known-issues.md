# Known Issues and WIP

状态更新时间：2026-05-30

本文只记录当前已知 bug、失败测试和未闭环 WIP。这里的内容不是 verified change-log；修复完成前不得把它写成 implemented。

## PAY-WALLET-001 wallet transaction_no collision follow-up

Status: WIP / needs explicit implementation confirmation before production code change.

### Evidence

Current dirty backend files:

```text
admin_back_go/internal/module/payment/serialno/serial_no.go
admin_back_go/internal/module/payment/serialno/serial_no_test.go
admin_back_go/internal/module/payment/wallet/repository_test.go
```

Root cause evidence:

```text
wallet_transactions.transaction_no has unique key uk_wallet_transaction_no
old serialno.New used seq % 1_000_000, so same prefix + second + nanosecond can wrap after one million calls
Consume duplicate-key handling currently treats every duplicate key as a possible source idempotency race first
CreditRecharge does not retry duplicate transaction_no
```

Current verification:

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

Failure meaning:

```text
The no-wrap serial generator direction is covered, but wallet duplicate uk_wallet_transaction_no retry is not implemented.
The current wallet test expects retry insert after transaction_no collision; current production code performs a source FOR UPDATE lookup first and then returns the original error when no source row exists.
```

### Required decision before code change

Pick one path before touching production code:

```text
Option A: keep only serialno no-wrap root fix; remove or rewrite the wallet retry test as over-specified.
Option B: implement finite retry for uk_wallet_transaction_no only, preserve uk_wallet_transaction_source idempotency behavior, and apply the same duplicate-key distinction to recharge credit.
```

Minimum verification after implementation:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/payment/serialno ./internal/module/payment/wallet ./internal/module/payment -count=1
go test ./internal/module/payment/... -count=1
git diff --check
```
