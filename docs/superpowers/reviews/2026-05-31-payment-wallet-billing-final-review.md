# Payment Wallet Billing Final Review

日期：2026-05-31
范围：支付/钱包/AI 计费整改执行结果终审；同时检查 canvas 后续 spec/plan 是否跟新账务基线一致。

## Outcome

结论：原整改主体方向正确，但终审发现一个真问题：legacy wallet `consume` 内部表面还留在后端和前端测试/i18n 里。这个不是审美问题，是边界问题；没有当前调用方的扣款入口不能留给下一个开发者猜。

本次已补丁修掉：

```text
SourceConsume
ConsumeInput / ConsumeResponse
Service.Consume
Repository.Consume
ErrConsumeSourceOwnerMismatch
wallet.consume.* i18n keys
旧 paymentOrder i18n keys
旧 payment order / wallet tests stale expectation
```

## Blocking issues

### 1. Legacy wallet consume surface remained

原问题：HTTP `/wallet/consumptions` 已退休，但内部 DTO/service/repository/i18n 仍保留 `consume`。这会让 AI billing 之外的代码重新绕过 `ai_billing_records`，破坏账务 source 锚点。

Required fix：删除内部 consume wrapper，只保留明确 `Debit` / `Credit`，支出 source 当前只允许 `ai_generate`，退款 source 只允许 `ai_refund`。

状态：已修复并加 architecture guard。

### 2. Frontend stale payment order assumptions remained

原问题：支付订单页面/API 已退休，但测试仍期待旧 `PaymentRechargeApi.create` 和 `paymentOrder` locale。测试不是摆设，错了就会误导后续实现。

Required fix：测试改成当前事实：充值使用 `PaymentRechargeApi.add`；旧 payment order 页面/API/i18n 不存在；合法的 `payment_order_no` 充值字段不误删。

状态：已修复。

## Non-blocking issues

- `git diff --check` 仍提示 CRLF 将被 Git 规范化为 LF；这是换行提示，不是 blocking whitespace error。
- root 还有两个与本任务无关的未跟踪 RESTful API naming audit 文档，本次未改。

## Evidence

```powershell
cd E:\admin_go\admin_back_go
$env:GOMAXPROCS='2'; go test -p=1 ./internal/architecture ./internal/bootstrap ./internal/module/payment/... ./internal/module/ai/billing ./internal/module/ai/image -count=1
$env:GOMAXPROCS='2'; go test -p=1 ./... -count=1

cd E:\admin_go\admin_front_ts
npm run test -- --run tests/shared/wallet/wallet-api.test.ts tests/shared/wallet/wallet-pages.test.ts tests/shared/payment/payment-order-api.test.ts tests/shared/payment/payment-order-page.test.ts tests/shared/payment-wallet-billing-redesign.test.ts tests/shared/ai/ai-billing-rule-api.test.ts
npm run typecheck
npm run lint:quality

cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Observed：

```text
backend focused tests: PASS
backend go test ./...: PASS
frontend targeted tests: 6 files / 16 tests PASS
frontend typecheck: PASS
frontend lint:quality: PASS
root git diff --check: PASS
agent governance: PASS
```

## Canvas follow-up

Canvas spec/plan 已按本次支付钱包基线更新：

```text
Spec: docs/superpowers/specs/2026-05-31-canvas-front-next-integration-design.md
Plan: docs/superpowers/plans/2026-05-31-canvas-front-next-integration.md
```

关键约束：

```text
canvas auth platform code = canvas
canvas_front_next 只做 Next 前端
不保留 infinite-canvas 后端作为长期 runtime
不迁入 users / credit_logs / settings
不新增 canvas_users / canvas_credit_logs / canvas_settings / canvas_projects
Grok/xAI 复用 ai_providers 的 openai-compatible 配置；不新增供应商表
Canvas 扣费走 ai_billing_records(platform=canvas) + wallet Debit/Credit
```
