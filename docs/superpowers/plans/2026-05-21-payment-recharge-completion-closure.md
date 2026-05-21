# Payment Recharge Completion Closure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 补齐支付宝充值完成闭环：callback、手动 sync、cron 补偿共用幂等入账边界，用户支付后即使关闭网页也最终看到充值成功。

**Architecture:** 支付业务仍由 `admin_back_go/internal/module/payment` 负责；`internal/platform/payment/alipay` 只处理支付宝协议、SDK、证书验签，不访问 DB。新增 public callback 不走 `/api/admin/v1`，不依赖登录/RBAC/OperationLog；callback、manual sync、cron 三条路径都收敛到 payment service 内部 finalizer。

**Tech Stack:** Go, Gin, GORM, MySQL/InnoDB, Asynq task queue, DB-backed cron registry, go-pay/gopay, Vue 3 + TypeScript + Element Plus + existing request client + Vitest.

---

## Scope Lock

只做：

```text
POST /api/payment/callbacks/alipay
payment_callback_events 审计表
支付宝 callback parse/verify 平台边界
order/recharge paid finalize 内部边界
payment:sync-pending-order:v1
payment:close-expired-order:v1
cron_task seed: payment_sync_pending_order / payment_close_expired_order
/payment/recharge reopen 自动同步最近可见 paying 充值单
backend/frontend/docs/smoke matrix 同步
```

不做：

```text
微信支付
退款/退款回调
订阅/会员权益/商品履约
对账单下载
支付配置 UI 重做
raw /payment/orders create UX 回归
ngrok/内网穿透部署教程
```

Linus check:

```text
True problem: yes. 资金入账不能依赖用户一定从支付宝 return_url 回来。
Simpler way: 不建支付中台；复用 payment_orders/payment_recharges/wallet_transactions 状态机。
What breaks: 不能破坏 /payment/config、/payment/recharge、隐藏 /payment/orders、RBAC、OperationLog、现有手动 sync/pay/close。
```

Spec source:

```text
docs/superpowers/specs/2026-05-21-payment-recharge-completion-closure-design.md
```

---

## Naming Lock

| Layer | Name |
| --- | --- |
| Callback route | `POST /api/payment/callbacks/alipay` |
| Callback response | `text/plain; charset=utf-8`, body exactly `success` or `fail` |
| Audit table | `payment_callback_events` |
| Callback files | `callback_model.go`, `callback_dto.go`, `callback_repository.go`, `callback_service.go`, `callback_handler.go` |
| Finalizer file | `finalizer.go` |
| Payment job files | `jobs.go`, `job_service.go` |
| Cron row 1 | `payment_sync_pending_order` |
| Cron row 2 | `payment_close_expired_order` |
| Task type 1 | `payment:sync-pending-order:v1` |
| Task type 2 | `payment:close-expired-order:v1` |

Forbidden names:

```text
/api/payment/notify/alipay
/api/admin/v1/payment/callbacks/alipay
/api/pay/notify/alipay
payment_notify_events
payment_events
payment_webhooks
notify_service.go
webhook_service.go
```

---

## File Map

### Create

```text
admin_back_go/database/migrations/20260521_payment_recharge_completion_closure.sql
admin_back_go/internal/module/payment/callback_model.go
admin_back_go/internal/module/payment/callback_dto.go
admin_back_go/internal/module/payment/callback_repository.go
admin_back_go/internal/module/payment/callback_service.go
admin_back_go/internal/module/payment/callback_handler.go
admin_back_go/internal/module/payment/finalizer.go
admin_back_go/internal/module/payment/jobs.go
admin_back_go/internal/module/payment/job_service.go
admin_back_go/internal/module/payment/callback_service_test.go
admin_back_go/internal/module/payment/finalizer_test.go
admin_back_go/internal/module/payment/jobs_test.go
admin_back_go/internal/platform/payment/alipay/notify_test.go
```

### Modify

```text
admin_back_go/internal/platform/payment/gateway.go
admin_back_go/internal/platform/payment/alipay/types.go
admin_back_go/internal/platform/payment/alipay/gateway.go
admin_back_go/internal/module/payment/repository.go
admin_back_go/internal/module/payment/order_repository.go
admin_back_go/internal/module/payment/recharge_repository.go
admin_back_go/internal/module/payment/order_service.go
admin_back_go/internal/module/payment/recharge_service.go
admin_back_go/internal/module/payment/dto.go
admin_back_go/internal/module/payment/handler.go
admin_back_go/internal/module/payment/route.go
admin_back_go/internal/module/payment/*_test.go
admin_back_go/internal/module/crontask/registry.go
admin_back_go/internal/module/crontask/registry_test.go
admin_back_go/internal/middleware/auth_token.go
admin_back_go/internal/middleware/auth_token_test.go
admin_back_go/internal/bootstrap/app.go
admin_back_go/internal/bootstrap/worker.go
admin_back_go/internal/bootstrap/route_meta_test.go
admin_back_go/internal/jobs/noop.go
admin_back_go/internal/jobs/noop_test.go
admin_front_ts/src/views/Main/payment/recharge/composables/usePaymentRechargePage.ts
admin_front_ts/src/views/Main/payment/recharge/components/RechargeRecentRecords.vue
admin_front_ts/tests/shared/payment/payment-recharge-page.test.ts
docs/contracts/admin-api-v1.md
docs/status/current-status.md
docs/testing/smoke-matrix.md
admin_back_go/docs/architecture.md
```

---

## Contract Lock

### Public callback

```text
POST /api/payment/callbacks/alipay
Content-Type: application/x-www-form-urlencoded
AuthToken: skip
RBAC: none
OperationLog: none
Response success: text/plain body success
Response failure: text/plain body fail
```

### Callback business rules

```text
invalid signature -> payment_callback_events.failed -> fail -> no mutation
unknown out_trade_no -> payment_callback_events.ignored -> success -> no mutation
app_id mismatch -> payment_callback_events.failed -> fail -> no mutation
amount mismatch -> payment_callback_events.failed -> fail -> no mutation
TRADE_SUCCESS / TRADE_FINISHED -> order paid + recharge credited -> success
WAIT_BUYER_PAY / other non-success -> ignored -> success
internal finalize error -> failed -> fail, so Alipay can retry
```

### Cron task defaults

```text
payment_sync_pending_order: cron = 0 */2 * * * *
payment_close_expired_order: cron = 0 */5 * * * *
sync pending limit default = 50
close expired limit default = 50
```

---

## Task 1: Schema and Audit Model

**Files:**
- Create: `admin_back_go/database/migrations/20260521_payment_recharge_completion_closure.sql`
- Create: `admin_back_go/internal/module/payment/callback_model.go`
- Create: `admin_back_go/internal/module/payment/callback_dto.go`
- Create: `admin_back_go/internal/module/payment/callback_repository.go`
- Modify: `admin_back_go/internal/module/payment/repository.go`
- Test: `admin_back_go/internal/module/payment/callback_service_test.go`

- [ ] **Step 1: Write failing callback audit repository test**

Create `admin_back_go/internal/module/payment/callback_service_test.go` with:

```go
package payment

import (
    "context"
    "testing"
    "time"

    "admin_back_go/internal/enum"
)

func TestCallbackAuditEventRecordsPendingThenProcessed(t *testing.T) {
    repo := newFakeCallbackRepo()
    now := time.Date(2026, 5, 21, 10, 0, 0, 0, time.UTC)
    eventID, err := repo.CreateCallbackEvent(context.Background(), CallbackEvent{
        Provider: providerAlipay, NotifyID: "notify-1", OutTradeNo: "PAY20260521100000000000",
        TradeNo: "202605212200", TradeStatus: "TRADE_SUCCESS", AppID: "2026000000000000",
        TotalAmountCents: 1000, SignatureValid: enum.CommonNo, ProcessStatus: callbackProcessPending,
        RawPayloadJSON: `{"out_trade_no":"PAY20260521100000000000"}`, ReceivedAt: now, IsDel: enum.CommonNo,
    })
    if err != nil { t.Fatalf("CreateCallbackEvent error=%v", err) }
    if eventID != 1 { t.Fatalf("expected event id 1, got %d", eventID) }
    processedAt := now.Add(time.Second)
    if err := repo.UpdateCallbackEventProcessed(context.Background(), eventID, enum.CommonYes, callbackProcessSuccess, "credited", processedAt); err != nil {
        t.Fatalf("UpdateCallbackEventProcessed error=%v", err)
    }
    if repo.callbackEvent.ProcessStatus != callbackProcessSuccess || repo.callbackEvent.SignatureValid != enum.CommonYes {
        t.Fatalf("unexpected event=%#v", repo.callbackEvent)
    }
}

type fakeCallbackRepo struct{ callbackEvent CallbackEvent }
func newFakeCallbackRepo() *fakeCallbackRepo { return &fakeCallbackRepo{} }
func (r *fakeCallbackRepo) CreateCallbackEvent(ctx context.Context, event CallbackEvent) (int64, error) { event.ID = 1; r.callbackEvent = event; return event.ID, nil }
func (r *fakeCallbackRepo) UpdateCallbackEventProcessed(ctx context.Context, id int64, signatureValid int, status string, message string, processedAt time.Time) error {
    r.callbackEvent.SignatureValid = signatureValid; r.callbackEvent.ProcessStatus = status; r.callbackEvent.ProcessMessage = message; r.callbackEvent.ProcessedAt = &processedAt; return nil
}
```

- [ ] **Step 2: Run RED**

```powershell
cd admin_back_go
go test ./internal/module/payment -run TestCallbackAuditEventRecordsPendingThenProcessed -count=1
```

Expected: fails with undefined `CallbackEvent` / `callbackProcessPending`.

- [ ] **Step 3: Add migration**

Create `admin_back_go/database/migrations/20260521_payment_recharge_completion_closure.sql`:

```sql
CREATE TABLE IF NOT EXISTS `payment_callback_events` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `provider` VARCHAR(32) NOT NULL DEFAULT 'alipay',
  `notify_id` VARCHAR(128) NOT NULL DEFAULT '',
  `out_trade_no` VARCHAR(64) NOT NULL DEFAULT '',
  `trade_no` VARCHAR(64) NOT NULL DEFAULT '',
  `trade_status` VARCHAR(32) NOT NULL DEFAULT '',
  `app_id` VARCHAR(64) NOT NULL DEFAULT '',
  `total_amount_cents` BIGINT NOT NULL DEFAULT 0,
  `signature_valid` TINYINT NOT NULL DEFAULT 2,
  `process_status` VARCHAR(16) NOT NULL DEFAULT 'pending',
  `process_message` VARCHAR(512) NOT NULL DEFAULT '',
  `raw_payload_json` JSON NULL,
  `received_at` DATETIME NOT NULL,
  `processed_at` DATETIME NULL,
  `is_del` TINYINT NOT NULL DEFAULT 2,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_payment_callback_events_notify_id` (`provider`, `notify_id`),
  KEY `idx_payment_callback_events_out_trade_no` (`provider`, `out_trade_no`),
  KEY `idx_payment_callback_events_status_time` (`process_status`, `received_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE `payment_orders`
  ADD KEY `idx_payment_orders_provider_status_expired` (`provider`, `status`, `is_del`, `expired_at`, `id`),
  ADD KEY `idx_payment_orders_status_updated` (`status`, `is_del`, `updated_at`, `id`);

ALTER TABLE `payment_recharges`
  ADD KEY `idx_payment_recharges_order_isdel` (`payment_order_id`, `is_del`);

INSERT INTO `cron_tasks` (`name`, `title`, `description`, `cron`, `cron_readable`, `handler`, `status`, `is_del`)
SELECT 'payment_sync_pending_order', '支付中订单补偿同步', '扫描支付中支付宝订单并补偿同步本地订单/充值/钱包状态', '0 */2 * * * *', '每2分钟', 'payment:sync-pending-order:v1', 1, 2
WHERE NOT EXISTS (SELECT 1 FROM `cron_tasks` WHERE `name` = 'payment_sync_pending_order' AND `is_del` = 2);

INSERT INTO `cron_tasks` (`name`, `title`, `description`, `cron`, `cron_readable`, `handler`, `status`, `is_del`)
SELECT 'payment_close_expired_order', '过期支付订单关闭', '扫描过期未支付支付宝订单并关闭本地/支付宝订单', '0 */5 * * * *', '每5分钟', 'payment:close-expired-order:v1', 1, 2
WHERE NOT EXISTS (SELECT 1 FROM `cron_tasks` WHERE `name` = 'payment_close_expired_order' AND `is_del` = 2);
```

If live DB already has equivalent indexes, adjust migration before applying; do not add duplicate indexes.

- [ ] **Step 4: Add callback model/DTO/repository**

Create `callback_model.go`:

```go
package payment

import "time"

type CallbackEvent struct {
    ID int64 `gorm:"column:id;primaryKey"`
    Provider string `gorm:"column:provider"`
    NotifyID string `gorm:"column:notify_id"`
    OutTradeNo string `gorm:"column:out_trade_no"`
    TradeNo string `gorm:"column:trade_no"`
    TradeStatus string `gorm:"column:trade_status"`
    AppID string `gorm:"column:app_id"`
    TotalAmountCents int64 `gorm:"column:total_amount_cents"`
    SignatureValid int `gorm:"column:signature_valid"`
    ProcessStatus string `gorm:"column:process_status"`
    ProcessMessage string `gorm:"column:process_message"`
    RawPayloadJSON string `gorm:"column:raw_payload_json"`
    ReceivedAt time.Time `gorm:"column:received_at"`
    ProcessedAt *time.Time `gorm:"column:processed_at"`
    IsDel int `gorm:"column:is_del"`
    CreatedAt time.Time `gorm:"column:created_at"`
    UpdatedAt time.Time `gorm:"column:updated_at"`
}
func (CallbackEvent) TableName() string { return "payment_callback_events" }
```

Create `callback_dto.go`:

```go
package payment

import "net/url"

const (
    callbackProcessPending = "pending"
    callbackProcessSuccess = "success"
    callbackProcessFailed  = "failed"
    callbackProcessIgnored = "ignored"
    callbackResultSuccess  = "success"
    callbackResultFail     = "fail"
)

type AlipayCallbackInput struct { Form url.Values }
type AlipayCallbackResult struct { Text string }
```

Modify `Repository` in `repository.go`:

```go
CreateCallbackEvent(ctx context.Context, event CallbackEvent) (int64, error)
UpdateCallbackEventProcessed(ctx context.Context, id int64, signatureValid int, status string, message string, processedAt time.Time) error
```

Create `callback_repository.go`:

```go
package payment

import (
    "context"
    "strings"
    "time"
)

func (r *GormRepository) CreateCallbackEvent(ctx context.Context, event CallbackEvent) (int64, error) {
    if r == nil || r.db == nil { return 0, ErrRepositoryNotConfigured }
    event.Provider = strings.TrimSpace(event.Provider)
    event.ProcessStatus = strings.TrimSpace(event.ProcessStatus)
    event.ProcessMessage = trimMax(event.ProcessMessage, 512)
    if err := r.db.WithContext(ctx).Create(&event).Error; err != nil { return 0, err }
    return event.ID, nil
}

func (r *GormRepository) UpdateCallbackEventProcessed(ctx context.Context, id int64, signatureValid int, status string, message string, processedAt time.Time) error {
    if r == nil || r.db == nil { return ErrRepositoryNotConfigured }
    return r.db.WithContext(ctx).Model(&CallbackEvent{}).Where("id = ?", id).Updates(map[string]any{
        "signature_valid": signatureValid,
        "process_status": strings.TrimSpace(status),
        "process_message": trimMax(message, 512),
        "processed_at": processedAt,
    }).Error
}
```

- [ ] **Step 5: Run GREEN and commit**

```powershell
cd admin_back_go
go test ./internal/module/payment -run TestCallbackAuditEventRecordsPendingThenProcessed -count=1
cd ..
git add admin_back_go/database/migrations/20260521_payment_recharge_completion_closure.sql admin_back_go/internal/module/payment/callback_* admin_back_go/internal/module/payment/repository.go
git commit -m "feat(payment): add callback audit event storage"
```

---

## Task 2: Alipay Notify Platform Boundary

**Files:**
- Modify: `admin_back_go/internal/platform/payment/gateway.go`
- Modify: `admin_back_go/internal/platform/payment/alipay/types.go`
- Modify: `admin_back_go/internal/platform/payment/alipay/gateway.go`
- Create: `admin_back_go/internal/platform/payment/alipay/notify_test.go`

- [ ] **Step 1: Write failing notify parsing test**

Create `admin_back_go/internal/platform/payment/alipay/notify_test.go`:

```go
package alipay

import (
    "net/url"
    "testing"
)

func TestParseNotifyPayloadNormalizesAmountToCents(t *testing.T) {
    form := url.Values{}
    form.Set("notify_id", "notify-1")
    form.Set("out_trade_no", "PAY20260521100000000000")
    form.Set("trade_no", "202605212200")
    form.Set("trade_status", "TRADE_SUCCESS")
    form.Set("app_id", "2026000000000000")
    form.Set("total_amount", "10.05")
    form.Set("sign", "signature")
    form.Set("sign_type", "RSA2")

    payload, err := ParseNotifyPayload(form)
    if err != nil { t.Fatalf("ParseNotifyPayload error=%v", err) }
    if payload.OutTradeNo != "PAY20260521100000000000" || payload.TotalAmountCents != 1005 {
        t.Fatalf("unexpected payload=%#v", payload)
    }
}

func TestParseNotifyPayloadRejectsInvalidAmount(t *testing.T) {
    form := url.Values{"total_amount": []string{"10.005"}}
    _, err := ParseNotifyPayload(form)
    if err == nil { t.Fatal("expected invalid amount error") }
}
```

- [ ] **Step 2: Run RED**

```powershell
cd admin_back_go
go test ./internal/platform/payment/alipay -run TestParseNotifyPayload -count=1
```

Expected: fails with undefined `ParseNotifyPayload`.

- [ ] **Step 3: Extend gateway interfaces**

Modify `admin_back_go/internal/platform/payment/gateway.go` imports:

```go
import (
    "context"
    "net/url"
    "time"
)
```

Add:

```go
type NotifyPayload struct {
    NotifyID string
    OutTradeNo string
    TradeNo string
    TradeStatus string
    AppID string
    TotalAmountCents int64
    Raw map[string]string
}
```

Extend `Gateway`:

```go
VerifyNotify(ctx context.Context, cfg ChannelConfig, form url.Values) (*NotifyPayload, error)
```

Do the equivalent in `admin_back_go/internal/platform/payment/alipay/types.go` using package-local `NotifyPayload`.

- [ ] **Step 4: Implement parser and verifier in Alipay platform**

In `admin_back_go/internal/platform/payment/alipay/gateway.go`, add imports `net/url` and `strconv` if missing, then append:

```go
func ParseNotifyPayload(form url.Values) (*NotifyPayload, error) {
    amountCents, err := parseAmountCents(form.Get("total_amount"))
    if err != nil { return nil, err }
    raw := make(map[string]string, len(form))
    for key, values := range form {
        if len(values) == 0 { continue }
        raw[key] = values[0]
    }
    return &NotifyPayload{
        NotifyID: strings.TrimSpace(form.Get("notify_id")),
        OutTradeNo: strings.TrimSpace(form.Get("out_trade_no")),
        TradeNo: strings.TrimSpace(form.Get("trade_no")),
        TradeStatus: strings.TrimSpace(form.Get("trade_status")),
        AppID: strings.TrimSpace(form.Get("app_id")),
        TotalAmountCents: amountCents,
        Raw: raw,
    }, nil
}

func parseAmountCents(value string) (int64, error) {
    value = strings.TrimSpace(value)
    if value == "" { return 0, errors.New("alipay: total amount is required") }
    parts := strings.Split(value, ".")
    if len(parts) > 2 || parts[0] == "" { return 0, fmt.Errorf("alipay: invalid total amount %q", value) }
    yuan, err := strconv.ParseInt(parts[0], 10, 64)
    if err != nil || yuan < 0 { return 0, fmt.Errorf("alipay: invalid total amount %q", value) }
    centText := "00"
    if len(parts) == 2 {
        if len(parts[1]) > 2 { return 0, fmt.Errorf("alipay: invalid total amount %q", value) }
        centText = (parts[1] + "00")[:2]
    }
    cents, err := strconv.ParseInt(centText, 10, 64)
    if err != nil { return 0, fmt.Errorf("alipay: invalid total amount %q", value) }
    return yuan*100 + cents, nil
}

func (g *GopayGateway) VerifyNotify(ctx context.Context, cfg ChannelConfig, form url.Values) (*NotifyPayload, error) {
    _ = ctx
    client, err := newClient(cfg)
    if err != nil { return nil, err }
    payload, err := ParseNotifyPayload(form)
    if err != nil { return nil, err }
    body := gopay.BodyMap{}
    for key, values := range form {
        if len(values) == 0 { continue }
        body.Set(key, values[0])
    }
    if err := client.VerifySignWithCert(body); err != nil {
        return nil, fmt.Errorf("alipay: verify notify sign: %w", err)
    }
    return payload, nil
}
```

If this `gopay` version has a different verify method name, inspect local module source under `$(go env GOPATH)\pkg\mod\github.com\go-pay\gopay*` and adapt only inside `VerifyNotify`.

- [ ] **Step 5: Add platform adapter mapping**

If `NewPlatformGateway` in `admin_back_go/internal/platform/payment/alipay/mapper.go` wraps package-local `Gateway`, implement `VerifyNotify` there by mapping `alipay.NotifyPayload` to `payment.NotifyPayload`.

Expected shape:

```go
func (g *PlatformGateway) VerifyNotify(ctx context.Context, cfg payment.ChannelConfig, form url.Values) (*payment.NotifyPayload, error) {
    result, err := g.gateway.VerifyNotify(ctx, toAlipayConfig(cfg), form)
    if err != nil { return nil, err }
    return &payment.NotifyPayload{
        NotifyID: result.NotifyID, OutTradeNo: result.OutTradeNo, TradeNo: result.TradeNo,
        TradeStatus: result.TradeStatus, AppID: result.AppID, TotalAmountCents: result.TotalAmountCents, Raw: result.Raw,
    }, nil
}
```

- [ ] **Step 6: Update fake gateways and run tests**

Add `VerifyNotify` to fake gateway types in payment tests:

```go
func (f *fakeOrderGateway) VerifyNotify(ctx context.Context, cfg gateway.ChannelConfig, form url.Values) (*gateway.NotifyPayload, error) {
    f.verifyNotifyCalled = true
    return f.notifyPayload, f.notifyErr
}
```

Run:

```powershell
cd admin_back_go
go test ./internal/platform/payment/... ./internal/module/payment -run "TestParseNotifyPayload|TestGopay|TestCreateOrder" -count=1
```

Expected: all selected tests pass.

- [ ] **Step 7: Commit**

```powershell
cd ..
git add admin_back_go/internal/platform/payment admin_back_go/internal/module/payment/*_test.go
git commit -m "feat(payment): add alipay notify verification boundary"
```

---

## Task 3: Shared Finalizer for Order/Recharges

**Files:**
- Create: `admin_back_go/internal/module/payment/finalizer.go`
- Modify: `admin_back_go/internal/module/payment/order_service.go`
- Modify: `admin_back_go/internal/module/payment/recharge_service.go`
- Modify: `admin_back_go/internal/module/payment/repository.go`
- Modify: `admin_back_go/internal/module/payment/recharge_repository.go`
- Test: `admin_back_go/internal/module/payment/finalizer_test.go`

- [ ] **Step 1: Write failing finalizer tests**

Create `admin_back_go/internal/module/payment/finalizer_test.go`:

```go
package payment

import (
    "context"
    "testing"

    "admin_back_go/internal/enum"
)

func TestFinalizeOrderPaidCreditsRechargeOnce(t *testing.T) {
    repo := newFakeRechargeRepo()
    paidAt := fixedRechargeNow().Add(1)
    repo.wallet = &Wallet{ID: 1, UserID: 7, BalanceCents: 1000, TotalRechargeCents: 1000, IsDel: enum.CommonNo}
    repo.order = &Order{ID: 1, OrderNo: "PAY20260515100000000000", Status: orderStatusPaying, AmountCents: 1000, IsDel: enum.CommonNo}
    repo.recharge = &Recharge{ID: 1, RechargeNo: "RCG20260515100000000000", UserID: 7, PaymentOrderID: 1, Status: rechargeStatusPaying, AmountCents: 1000, IsDel: enum.CommonNo}
    service := newRechargeService(repo, &fakeOrderGateway{})

    result, appErr := service.FinalizeOrderPaid(context.Background(), 1, "202605212200", paidAt, finalizeSourceCallback)
    if appErr != nil { t.Fatalf("FinalizeOrderPaid error=%v", appErr) }
    if result.OrderStatus != orderStatusPaid || result.RechargeStatus != rechargeStatusCredited { t.Fatalf("unexpected result=%#v", result) }
    if repo.creditCount != 1 || repo.wallet.BalanceCents != 2000 { t.Fatalf("expected one credit, creditCount=%d wallet=%#v", repo.creditCount, repo.wallet) }

    _, appErr = service.FinalizeOrderPaid(context.Background(), 1, "202605212200", paidAt, finalizeSourceCallback)
    if appErr != nil { t.Fatalf("duplicate FinalizeOrderPaid error=%v", appErr) }
    if repo.creditCount != 1 || repo.wallet.BalanceCents != 2000 { t.Fatalf("duplicate finalize credited again") }
}

func TestFinalizeOrderPaidAllowsRawOrderWithoutRecharge(t *testing.T) {
    repo := newFakeOrderRepoWithOrder(orderStatusPaying)
    service := newOrderService(repo, &fakeOrderGateway{})
    result, appErr := service.FinalizeOrderPaid(context.Background(), repo.order.ID, "202605212200", fixedOrderNow(), finalizeSourceSync)
    if appErr != nil { t.Fatalf("FinalizeOrderPaid raw order error=%v", appErr) }
    if result.OrderStatus != orderStatusPaid || result.RechargeStatus != "" { t.Fatalf("unexpected raw order finalizer result=%#v", result) }
}
```

- [ ] **Step 2: Run RED**

```powershell
cd admin_back_go
go test ./internal/module/payment -run TestFinalizeOrderPaid -count=1
```

Expected: `FinalizeOrderPaid` undefined.

- [ ] **Step 3: Add finalizer and repo method**

Create `finalizer.go`:

```go
package payment

import (
    "context"
    "net/http"
    "strings"
    "time"

    "admin_back_go/internal/apperror"
)

const (
    finalizeSourceSync = "sync"
    finalizeSourceCallback = "callback"
    finalizeSourceCronSync = "cron_sync"
    finalizeSourceCronClose = "cron_close"
)

type FinalizePaidResult struct {
    OrderID int64
    OrderNo string
    OrderStatus string
    RechargeID int64
    RechargeStatus string
    Wallet *Wallet
}

func (s *Service) FinalizeOrderPaid(ctx context.Context, orderID int64, tradeNo string, paidAt time.Time, source string) (*FinalizePaidResult, *apperror.Error) {
    if orderID <= 0 { return nil, apperror.BadRequest("无效的支付订单ID") }
    if paidAt.IsZero() { paidAt = s.now() }
    repo, appErr := s.requireRepository(); if appErr != nil { return nil, appErr }
    order, err := repo.GetOrder(ctx, orderID)
    if err != nil { return nil, apperror.Wrap(apperror.CodeInternal, http.StatusInternalServerError, "查询支付订单失败", err) }
    if order == nil { return nil, apperror.NotFound("支付订单不存在") }
    if order.Status != orderStatusPaid {
        if err := repo.UpdateOrderPaid(ctx, order.ID, strings.TrimSpace(tradeNo), paidAt); err != nil {
            return nil, apperror.Wrap(apperror.CodeInternal, http.StatusInternalServerError, "保存支付订单成功状态失败", err)
        }
    }
    result := &FinalizePaidResult{OrderID: order.ID, OrderNo: order.OrderNo, OrderStatus: orderStatusPaid}
    recharge, err := repo.GetRechargeByOrderID(ctx, order.ID)
    if err != nil { return nil, apperror.Wrap(apperror.CodeInternal, http.StatusInternalServerError, "查询订单关联充值单失败", err) }
    if recharge == nil { return result, nil }
    if recharge.Status != rechargeStatusCredited {
        if err := repo.UpdateRechargePaid(ctx, recharge.ID, paidAt); err != nil {
            return nil, apperror.Wrap(apperror.CodeInternal, http.StatusInternalServerError, "更新充值支付状态失败", err)
        }
    }
    wallet, credited, err := repo.CreditRecharge(ctx, recharge.ID, paidAt, s.now())
    if err != nil { return nil, apperror.Wrap(apperror.CodeInternal, http.StatusInternalServerError, "充值入账失败", err) }
    result.RechargeID = credited.ID
    result.RechargeStatus = credited.Status
    result.Wallet = wallet
    return result, nil
}
```

Modify `Repository`:

```go
GetRechargeByOrderID(ctx context.Context, orderID int64) (*Recharge, error)
```

Add to `recharge_repository.go`:

```go
func (r *GormRepository) GetRechargeByOrderID(ctx context.Context, orderID int64) (*Recharge, error) {
    if r == nil || r.db == nil { return nil, ErrRepositoryNotConfigured }
    var row Recharge
    err := r.db.WithContext(ctx).Where("payment_order_id = ? AND is_del = ?", orderID, enum.CommonNo).First(&row).Error
    if errors.Is(err, gorm.ErrRecordNotFound) { return nil, nil }
    return &row, err
}
```

- [ ] **Step 4: Update fake repos**

Add `GetRechargeByOrderID` to fake repos. Make `fakeRechargeRepo.CreditRecharge` idempotent using `creditedSources map[int64]bool` so duplicate finalizer calls do not increase `creditCount`.

- [ ] **Step 5: Route SyncOrder and SyncRecharge through finalizer**

In `order_service.go`, make `SyncOrder` return current state when already paid:

```go
if row.Status == orderStatusPaid {
    resp := orderStatusResponse(*row)
    return &resp, nil
}
```

Replace successful query branch with:

```go
if _, appErr := s.FinalizeOrderPaid(ctx, row.ID, resultTradeNo(result), paidAt, finalizeSourceSync); appErr != nil { return nil, appErr }
```

In `recharge_service.go`, replace direct `UpdateRechargePaid` + `CreditRecharge` with `FinalizeOrderPaid(ctx, row.PaymentOrderID, row.AlipayTradeNo, paidAt, finalizeSourceSync)` and then reload the recharge row for response.

- [ ] **Step 6: Run GREEN and commit**

```powershell
cd admin_back_go
go test ./internal/module/payment -run "TestFinalizeOrderPaid|TestSyncOrderMapsTradeSuccessToPaid|TestSyncRechargeReturnsCreditedWithoutCreditingAgain" -count=1
cd ..
git add admin_back_go/internal/module/payment
git commit -m "feat(payment): share paid finalizer across sync paths"
```

---

## Task 4: Public Alipay Callback Service and Route

**Files:**
- Create: `admin_back_go/internal/module/payment/callback_service.go`
- Create: `admin_back_go/internal/module/payment/callback_handler.go`
- Modify: `admin_back_go/internal/module/payment/handler.go`
- Modify: `admin_back_go/internal/module/payment/dto.go`
- Modify: `admin_back_go/internal/module/payment/route.go`
- Modify: `admin_back_go/internal/middleware/auth_token.go`
- Modify: `admin_back_go/internal/middleware/auth_token_test.go`
- Modify: `admin_back_go/internal/bootstrap/route_meta_test.go`
- Test: `admin_back_go/internal/module/payment/callback_service_test.go`

- [ ] **Step 1: Add failing callback service tests**

Append tests covering:

```text
invalid signature -> result.Text == fail, no order mutation, event failed
unknown out_trade_no -> result.Text == success, event ignored
TRADE_SUCCESS -> order paid + recharge credited + wallet credited once
duplicate TRADE_SUCCESS -> wallet not credited twice
```

Use helpers:

```go
func validAlipayCallbackForm() url.Values {
    form := url.Values{}
    form.Set("notify_id", "notify-1")
    form.Set("out_trade_no", "PAY20260521100000000000")
    form.Set("trade_no", "202605212200")
    form.Set("trade_status", "TRADE_SUCCESS")
    form.Set("app_id", "2026000000000000")
    form.Set("total_amount", "10.00")
    return form
}

func validNotifyPayload() *gateway.NotifyPayload {
    return &gateway.NotifyPayload{NotifyID: "notify-1", OutTradeNo: "PAY20260521100000000000", TradeNo: "202605212200", TradeStatus: "TRADE_SUCCESS", AppID: "2026000000000000", TotalAmountCents: 1000}
}
```

Create a fake repo embedding `fakeRechargeRepo` and add `GetOrderByNo`.

- [ ] **Step 2: Run RED**

```powershell
cd admin_back_go
go test ./internal/module/payment -run TestHandleAlipayCallback -count=1
```

Expected: `HandleAlipayCallback` undefined and `GetOrderByNo` missing.

- [ ] **Step 3: Add order lookup by order_no**

Modify `Repository`:

```go
GetOrderByNo(ctx context.Context, orderNo string) (*Order, error)
```

Add to `order_repository.go`:

```go
func (r *GormRepository) GetOrderByNo(ctx context.Context, orderNo string) (*Order, error) {
    if r == nil || r.db == nil { return nil, ErrRepositoryNotConfigured }
    var row Order
    err := r.db.WithContext(ctx).Where("order_no = ? AND is_del = ?", strings.TrimSpace(orderNo), enum.CommonNo).First(&row).Error
    if errors.Is(err, gorm.ErrRecordNotFound) { return nil, nil }
    return &row, err
}
```

Add nil implementations to fake repos used by existing tests.

- [ ] **Step 4: Implement callback service**

Create `callback_service.go`:

```go
package payment

import (
    "context"
    "encoding/json"
    "net/url"
    "strings"

    "admin_back_go/internal/apperror"
    "admin_back_go/internal/enum"
    gateway "admin_back_go/internal/platform/payment"
    payalipay "admin_back_go/internal/platform/payment/alipay"
)

func (s *Service) HandleAlipayCallback(ctx context.Context, input AlipayCallbackInput) (*AlipayCallbackResult, *apperror.Error) {
    repo, appErr := s.requireRepository()
    if appErr != nil { return &AlipayCallbackResult{Text: callbackResultFail}, nil }
    eventID, err := repo.CreateCallbackEvent(ctx, CallbackEvent{Provider: providerAlipay, ProcessStatus: callbackProcessPending, RawPayloadJSON: rawPayloadJSON(input.Form), ReceivedAt: s.now(), IsDel: enum.CommonNo})
    if err != nil { return &AlipayCallbackResult{Text: callbackResultFail}, nil }
    fail := func(message string) (*AlipayCallbackResult, *apperror.Error) {
        _ = repo.UpdateCallbackEventProcessed(ctx, eventID, enum.CommonNo, callbackProcessFailed, message, s.now())
        return &AlipayCallbackResult{Text: callbackResultFail}, nil
    }
    ignore := func(message string) (*AlipayCallbackResult, *apperror.Error) {
        _ = repo.UpdateCallbackEventProcessed(ctx, eventID, enum.CommonYes, callbackProcessIgnored, message, s.now())
        return &AlipayCallbackResult{Text: callbackResultSuccess}, nil
    }

    rawPayload, err := gatewayPayloadFromRawForm(input.Form)
    if err != nil || rawPayload.OutTradeNo == "" { return fail("invalid callback payload") }
    order, err := repo.GetOrderByNo(ctx, rawPayload.OutTradeNo)
    if err != nil { return fail("query order failed") }
    if order == nil { return ignore("order not found") }
    cfg, appErr := s.configByOrder(ctx, order)
    if appErr != nil { return fail(appErr.Message) }
    platformCfg, appErr := s.gatewayConfigFromConfig(*cfg)
    if appErr != nil { return fail(appErr.Message) }
    gw, appErr := s.requireGateway()
    if appErr != nil { return fail(appErr.Message) }
    verified, err := gw.VerifyNotify(ctx, platformCfg, input.Form)
    if err != nil { return fail("invalid signature") }
    if strings.TrimSpace(verified.AppID) != strings.TrimSpace(cfg.AppID) { return fail("app_id mismatch") }
    if verified.TotalAmountCents != order.AmountCents { return fail("amount mismatch") }
    switch strings.TrimSpace(verified.TradeStatus) {
    case "TRADE_SUCCESS", "TRADE_FINISHED":
        if _, appErr := s.FinalizeOrderPaid(ctx, order.ID, verified.TradeNo, s.now(), finalizeSourceCallback); appErr != nil { return fail(appErr.Message) }
        _ = repo.UpdateCallbackEventProcessed(ctx, eventID, enum.CommonYes, callbackProcessSuccess, "credited", s.now())
        return &AlipayCallbackResult{Text: callbackResultSuccess}, nil
    default:
        return ignore("non-success trade status")
    }
}

func gatewayPayloadFromRawForm(form url.Values) (*gateway.NotifyPayload, error) {
    payload, err := payalipay.ParseNotifyPayload(form)
    if err != nil { return nil, err }
    return &gateway.NotifyPayload{NotifyID: payload.NotifyID, OutTradeNo: payload.OutTradeNo, TradeNo: payload.TradeNo, TradeStatus: payload.TradeStatus, AppID: payload.AppID, TotalAmountCents: payload.TotalAmountCents, Raw: payload.Raw}, nil
}

func rawPayloadJSON(form url.Values) string {
    raw := make(map[string]string, len(form))
    for key, values := range form {
        if len(values) == 0 || key == "sign" { continue }
        raw[key] = values[0]
    }
    data, err := json.Marshal(raw)
    if err != nil { return "{}" }
    if len(data) > 8192 { data = data[:8192] }
    return string(data)
}
```

- [ ] **Step 5: Add HTTP service method and handler**

Modify `HTTPService` in `dto.go`:

```go
HandleAlipayCallback(ctx context.Context, input AlipayCallbackInput) (*AlipayCallbackResult, *apperror.Error)
```

Add nil service implementation in `handler.go` returning fail text.

Create `callback_handler.go`:

```go
package payment

import (
    "net/http"
    "github.com/gin-gonic/gin"
)

func (h *Handler) AlipayCallback(c *gin.Context) {
    if err := c.Request.ParseForm(); err != nil {
        c.Data(http.StatusOK, "text/plain; charset=utf-8", []byte(callbackResultFail))
        return
    }
    result, _ := h.requireService().HandleAlipayCallback(c.Request.Context(), AlipayCallbackInput{Form: c.Request.PostForm})
    text := callbackResultFail
    if result != nil && result.Text == callbackResultSuccess { text = callbackResultSuccess }
    c.Data(http.StatusOK, "text/plain; charset=utf-8", []byte(text))
}
```

Modify `route.go`, outside `/api/admin/v1` groups:

```go
callbacks := router.Group("/api/payment/callbacks")
callbacks.POST("/alipay", handler.AlipayCallback)
```

- [ ] **Step 6: Make callback public and metadata-free**

Modify `DefaultAuthSkipPaths()` in `auth_token.go`:

```go
"/api/payment/callbacks/alipay": {},
```

Replace old auth test with:

```go
func TestDefaultAuthSkipPathsExposeOnlyCanonicalPaymentCallback(t *testing.T) {
    paths := DefaultAuthSkipPaths()
    if _, ok := paths["/api/payment/callbacks/alipay"]; !ok { t.Fatalf("canonical payment callback must be public") }
    if _, ok := paths["/api/payment/notify/alipay"]; ok { t.Fatalf("old payment notify path must not be public") }
    if _, ok := paths["/api/pay/notify/alipay"]; ok { t.Fatalf("legacy pay notify path must not remain public") }
}
```

In `route_meta_test.go`, assert `POST /api/payment/callbacks/alipay` is absent from permission and operation maps.

- [ ] **Step 7: Run GREEN and commit**

```powershell
cd admin_back_go
go test ./internal/module/payment ./internal/middleware ./internal/bootstrap -run "TestHandleAlipayCallback|TestDefaultAuthSkipPathsExposeOnlyCanonicalPaymentCallback|TestPermissionRouteRulesUseExplicitRESTPatterns|TestOperationRouteRules" -count=1
cd ..
git add admin_back_go/internal/module/payment admin_back_go/internal/middleware/auth_token.go admin_back_go/internal/middleware/auth_token_test.go admin_back_go/internal/bootstrap/route_meta_test.go
git commit -m "feat(payment): add public alipay callback closure"
```

---

## Task 5: Cron Compensation Jobs and Worker Wiring

**Files:**
- Create: `admin_back_go/internal/module/payment/jobs.go`
- Create: `admin_back_go/internal/module/payment/job_service.go`
- Create: `admin_back_go/internal/module/payment/jobs_test.go`
- Modify: `admin_back_go/internal/module/payment/repository.go`
- Modify: `admin_back_go/internal/module/payment/order_repository.go`
- Modify: `admin_back_go/internal/module/crontask/registry.go`
- Modify: `admin_back_go/internal/module/crontask/registry_test.go`
- Modify: `admin_back_go/internal/jobs/noop.go`
- Modify: `admin_back_go/internal/jobs/noop_test.go`
- Modify: `admin_back_go/internal/bootstrap/worker.go`

- [ ] **Step 1: Write failing job tests**

Create `admin_back_go/internal/module/payment/jobs_test.go` testing:

```text
NewSyncPendingOrderTask -> Type payment:sync-pending-order:v1, default queue, UniqueTTL 55s
DecodeSyncPendingOrderPayload keeps limit
SyncPendingOrders scans two orders, one paid and one query failure; result Paid=1 Failed=1 and batch continues
```

- [ ] **Step 2: Run RED**

```powershell
cd admin_back_go
go test ./internal/module/payment -run "TestNewPaymentSyncPendingOrderTaskUsesVersionedType|TestSyncPendingOrdersCreditsPaidAndContinuesAfterFailures" -count=1
```

Expected: task/job methods undefined.

- [ ] **Step 3: Add task types and handlers**

Create `jobs.go` with:

```go
const (
    TypeSyncPendingOrderV1  = "payment:sync-pending-order:v1"
    TypeCloseExpiredOrderV1 = "payment:close-expired-order:v1"
)

type SyncPendingOrderPayload struct { Limit int `json:"limit,omitempty"` }
type CloseExpiredOrderPayload struct { Limit int `json:"limit,omitempty"` }

type JobService interface {
    SyncPendingOrders(ctx context.Context, input SyncPendingOrderInput) (*SyncPendingOrderResult, error)
    CloseExpiredOrders(ctx context.Context, input CloseExpiredOrderInput) (*CloseExpiredOrderResult, error)
}
```

Implement `NewSyncPendingOrderTask`, `NewCloseExpiredOrderTask`, decode helpers, and `RegisterHandlers` following `notificationtask/jobs.go`; use `taskqueue.QueueDefault` and `UniqueTTL: 55 * time.Second`.

- [ ] **Step 4: Add job service**

Create `job_service.go` with:

```go
const defaultPaymentJobLimit = 50

type SyncPendingOrderInput struct{ Limit int }
type SyncPendingOrderResult struct{ Scanned, Paid, Closed, Waiting, Failed int }
type CloseExpiredOrderInput struct{ Limit int }
type CloseExpiredOrderResult struct{ Scanned, Paid, Closed, Waiting, Failed int }
```

Implement:

```text
SyncPendingOrders: ListPendingPayingOrders(now-30s, limit), query each order, finalize paid, close local on TRADE_CLOSED, continue after single-row failure.
CloseExpiredOrders: ListExpiredOpenOrders(now, limit), locally close pending/failed, for paying query first; if paid finalize, if still waiting call gateway Close then local close.
```

Keep SDK network IO outside DB transactions; reuse `FinalizeOrderPaid` for paid states.

- [ ] **Step 5: Add batch repository methods**

Modify `Repository`:

```go
ListPendingPayingOrders(ctx context.Context, cutoff time.Time, limit int) ([]Order, error)
ListExpiredOpenOrders(ctx context.Context, now time.Time, limit int) ([]Order, error)
```

Add to `order_repository.go`:

```go
func (r *GormRepository) ListPendingPayingOrders(ctx context.Context, cutoff time.Time, limit int) ([]Order, error) {
    if r == nil || r.db == nil { return nil, ErrRepositoryNotConfigured }
    if limit <= 0 || limit > 100 { limit = defaultPaymentJobLimit }
    var rows []Order
    err := r.db.WithContext(ctx).Where("provider = ? AND status = ? AND is_del = ? AND updated_at <= ?", providerAlipay, orderStatusPaying, enum.CommonNo, cutoff).Order("id asc").Limit(limit).Find(&rows).Error
    return rows, err
}

func (r *GormRepository) ListExpiredOpenOrders(ctx context.Context, now time.Time, limit int) ([]Order, error) {
    if r == nil || r.db == nil { return nil, ErrRepositoryNotConfigured }
    if limit <= 0 || limit > 100 { limit = defaultPaymentJobLimit }
    var rows []Order
    err := r.db.WithContext(ctx).Where("provider = ? AND status IN ? AND is_del = ? AND expired_at < ?", providerAlipay, []string{orderStatusPending, orderStatusPaying}, enum.CommonNo, now).Order("expired_at asc, id asc").Limit(limit).Find(&rows).Error
    return rows, err
}
```

- [ ] **Step 6: Register cron registry entries**

Modify `crontask/registry.go` to import payment module and register:

```go
registry.Register(RegistryEntry{Name: "payment_sync_pending_order", TaskType: payment.TypeSyncPendingOrderV1, Description: "扫描支付中支付宝订单并补偿同步本地订单/充值/钱包状态", BuildTask: func() (taskqueue.Task, error) { return payment.NewSyncPendingOrderTask(payment.SyncPendingOrderPayload{}) }})
registry.Register(RegistryEntry{Name: "payment_close_expired_order", TaskType: payment.TypeCloseExpiredOrderV1, Description: "扫描过期未支付支付宝订单并关闭本地/支付宝订单", BuildTask: func() (taskqueue.Task, error) { return payment.NewCloseExpiredOrderTask(payment.CloseExpiredOrderPayload{}) }})
```

Add `TestDefaultRegistryIncludesPaymentTasks` in `registry_test.go`.

- [ ] **Step 7: Wire queue handlers and worker service**

Modify `internal/jobs/noop.go`:

```go
PaymentService payment.JobService
payment.RegisterHandlers(mux, deps.PaymentService, logger)
```

Add handler test in `noop_test.go` for both payment tasks.

Modify `bootstrap/worker.go` to construct payment service with `paymentmodule.NewGormRepository(resources.DB)`, `payalipay.NewPlatformGateway(payalipay.NewGopayGateway())`, `secretBox`, and `payment.CertPathResolver{CertBaseDir: cfg.Payment.CertBaseDir, WorkingDir: "."}`; pass it to `jobs.Register` as `PaymentService`.

- [ ] **Step 8: Run GREEN and commit**

```powershell
cd admin_back_go
go test ./internal/module/payment ./internal/module/crontask ./internal/jobs ./internal/bootstrap -run "TestNewPaymentSyncPendingOrderTaskUsesVersionedType|TestSyncPendingOrdersCreditsPaidAndContinuesAfterFailures|TestDefaultRegistryIncludesPaymentTasks|TestRegisterHandlesPaymentTaskHandlers|TestNewWorker" -count=1
cd ..
git add admin_back_go/internal/module/payment admin_back_go/internal/module/crontask admin_back_go/internal/jobs admin_back_go/internal/bootstrap/worker.go
git commit -m "feat(payment): add recharge completion cron compensation"
```

---

## Task 6: Frontend Reopen Auto Sync

**Files:**
- Modify: `admin_front_ts/src/views/Main/payment/recharge/composables/usePaymentRechargePage.ts`
- Modify: `admin_front_ts/src/views/Main/payment/recharge/components/RechargeRecentRecords.vue`
- Test: `admin_front_ts/tests/shared/payment/payment-recharge-page.test.ts`

- [ ] **Step 1: Add failing frontend behavior test**

Append to `payment-recharge-page.test.ts`:

```ts
  it('auto syncs at most three visible paying recharges on reopen with permission guard', () => {
    const composable = read('src/views/Main/payment/recharge/composables/usePaymentRechargePage.ts')
    const recent = read('src/views/Main/payment/recharge/components/RechargeRecentRecords.vue')

    expect(composable).toContain("import { useUserStore } from '@/store/user'")
    expect(composable).toContain('const userStore = useUserStore()')
    expect(composable).toContain('const autoSyncedRechargeIDs = shallowRef(new Set<number>())')
    expect(composable).toContain('async function autoSyncVisiblePayingRecharges()')
    expect(composable).toContain("userStore.can('payment_recharge_sync')")
    expect(composable).toContain("item.status === 'paying'")
    expect(composable).toContain('.slice(0, 3)')
    expect(composable).toContain('autoSyncedRechargeIDs.value.add(row.id)')
    expect(composable).toContain('await autoSyncVisiblePayingRecharges()')
    expect(composable).toContain('ElNotification.warning')
    expect(recent).toContain("userStore.can('payment_recharge_sync')")
  })
```

- [ ] **Step 2: Run RED**

```powershell
cd admin_front_ts
npm run test -- tests/shared/payment/payment-recharge-page.test.ts
```

Expected: new test fails.

- [ ] **Step 3: Implement composable auto sync**

Modify `usePaymentRechargePage.ts`:

```ts
import { useUserStore } from '@/store/user'
```

Inside `usePaymentRechargePage()`:

```ts
  const userStore = useUserStore()
  const autoSyncedRechargeIDs = shallowRef(new Set<number>())
```

Add function:

```ts
  async function autoSyncVisiblePayingRecharges() {
    if (!userStore.can('payment_recharge_sync')) return
    const candidates = data.value
      .filter((item) => item.status === 'paying' && !autoSyncedRechargeIDs.value.has(item.id))
      .slice(0, 3)
    if (candidates.length === 0) return

    let changed = false
    for (const row of candidates) {
      autoSyncedRechargeIDs.value.add(row.id)
      try {
        const result = await PaymentRechargeApi.sync(row.id)
        wallet.value = result.wallet
        changed = true
      } catch {
        ElNotification.warning({ message: '部分支付中充值单自动同步失败，可稍后手动同步' })
      }
    }
    if (changed) {
      await init()
      await table.getList()
    }
  }
```

Modify `refreshAll()`:

```ts
  async function refreshAll() {
    await init()
    await table.getList()
    await autoSyncVisiblePayingRecharges()
  }
```

Return `autoSyncVisiblePayingRecharges`.

- [ ] **Step 4: Harden return_url sync failure UX**

Wrap `syncReturnRecharge` body in try/catch:

```ts
  async function syncReturnRecharge(rechargeNo: string) {
    const normalized = rechargeNo.trim()
    if (!normalized || syncedReturnRechargeNo.value === normalized) return
    syncedReturnRechargeNo.value = normalized
    try {
      const result = await PaymentRechargeApi.list({ current_page: 1, page_size: 1, keyword: normalized })
      const row = result.list.find((item) => item.recharge_no === normalized)
      if (!row) { await table.getList(); return }
      const status = await PaymentRechargeApi.sync(row.id)
      wallet.value = status.wallet
      await refreshAll()
    } catch {
      ElNotification.warning({ message: '支付结果自动同步失败，可稍后在充值记录中手动同步' })
      await table.getList()
    }
  }
```

- [ ] **Step 5: Guard recent actions by permissions**

Modify `RechargeRecentRecords.vue`:

```ts
import { useUserStore } from '@/store/user'
const userStore = useUserStore()
```

Change buttons:

```vue
v-if="userStore.can('payment_recharge_pay') && props.canPay(row)"
v-if="userStore.can('payment_recharge_sync') && props.canSync(row)"
v-if="userStore.can('payment_recharge_close') && props.canClose(row)"
```

- [ ] **Step 6: Run GREEN and commit**

```powershell
cd admin_front_ts
npm run test -- tests/shared/payment/payment-recharge-page.test.ts tests/shared/payment/payment-recharge-api.test.ts
npm run build:check
cd ..
git add admin_front_ts/src/views/Main/payment/recharge/composables/usePaymentRechargePage.ts admin_front_ts/src/views/Main/payment/recharge/components/RechargeRecentRecords.vue admin_front_ts/tests/shared/payment/payment-recharge-page.test.ts
git commit -m "feat(payment): auto sync recent paying recharges on reopen"
```

---

## Task 7: Documentation, Smoke Matrix, Final Verification

**Files:**
- Modify: `docs/contracts/admin-api-v1.md`
- Modify: `docs/status/current-status.md`
- Modify: `docs/testing/smoke-matrix.md`
- Modify: `admin_back_go/docs/architecture.md`

- [ ] **Step 1: Update API contract**

In `docs/contracts/admin-api-v1.md`, add:

```markdown
### Public Alipay callback

`POST /api/payment/callbacks/alipay`

- Auth: none. This route is intentionally public for Alipay server-to-server callback.
- RBAC: none.
- OperationLog: none.
- Content-Type: `application/x-www-form-urlencoded`.
- Response: `text/plain; charset=utf-8`.
- Success body: `success`.
- Failure body: `fail`.

Processing rules:

- Verify Alipay signature with the configured Alipay public certificate.
- Match `out_trade_no` to `payment_orders.order_no`.
- Reject `app_id` mismatch and amount mismatch.
- `TRADE_SUCCESS` and `TRADE_FINISHED` finalize the order and any linked recharge.
- Unknown order and non-success trade statuses are audited as ignored and return `success` to avoid retry storms.
- Internal processing failure returns `fail` so Alipay can retry.
```

- [ ] **Step 2: Update current status after verification**

In `docs/status/current-status.md`, update the payment row only after tests pass. Include:

```text
implemented: public `POST /api/payment/callbacks/alipay`, `payment_callback_events` audit, shared paid finalizer, `payment_sync_pending_order`, `payment_close_expired_order`, and `/payment/recharge` reopen auto sync for visible paying records
```

Remaining risk text:

```text
Alipay only; callback, manual return_url sync, reopen auto sync, and DB-backed cron compensation now close the recharge completion path. No refund, reconcile, WeChat, subscription, wallet consumption, or business fulfillment in this slice; `private_key_enc`/plaintext key/cert content must never leak; `return_url` belongs to each recharge/payment order, not `payment_configs`; real callback/manual smoke requires sandbox credentials and reachable notify_url.
```

Do not claim real Alipay callback manual smoke passed unless it was actually run.

- [ ] **Step 3: Update smoke matrix**

In `docs/testing/smoke-matrix.md`, add:

```markdown
Payment recharge completion closure read gate:

- `POST /api/payment/callbacks/alipay` is registered as a public route and is absent from RBAC/OperationLog metadata.
- `payment_callback_events` exists when migrations are applied.
- Cron registry exposes `payment_sync_pending_order -> payment:sync-pending-order:v1`.
- Cron registry exposes `payment_close_expired_order -> payment:close-expired-order:v1`.
- Default smoke does not create real paid orders or mutate wallet state.
```

Add credential-gated manual smoke:

```markdown
Credential-gated Alipay manual smoke:

1. Configure Alipay sandbox credentials and mounted cert paths.
2. Create `recharge_10` from `/payment/recharge`.
3. Pay in sandbox and close the browser before returning to `return_url`.
4. Wait for callback or `payment_sync_pending_order` worker compensation.
5. Verify `payment_orders.status=paid`, `payment_recharges.status=credited`, and exactly one `wallet_transactions(source_type='recharge', source_id=<recharge_id>)` row.
6. Replay callback or click sync again and verify wallet balance does not increase twice.
```

- [ ] **Step 4: Update backend architecture doc**

In `admin_back_go/docs/architecture.md`, add:

```markdown
Payment recharge closure:

- Public Alipay callback is `POST /api/payment/callbacks/alipay`; it returns plain text and does not use admin auth/RBAC/OperationLog.
- `payment_callback_events` is audit-only and never becomes the source of order or wallet truth.
- `payment_orders`, `payment_recharges`, `user_wallets`, and `wallet_transactions` remain the state source.
- Callback, manual sync, and cron compensation share the same paid finalizer to keep wallet credit idempotent.
- Worker cron rows `payment_sync_pending_order` and `payment_close_expired_order` enqueue versioned payment tasks through the DB-backed cron registry.
```

- [ ] **Step 5: Run targeted backend verification**

```powershell
cd admin_back_go
go test ./internal/platform/payment/... ./internal/module/payment ./internal/module/crontask ./internal/jobs ./internal/middleware ./internal/bootstrap -count=1
```

Expected: all listed packages pass.

- [ ] **Step 6: Run frontend verification**

```powershell
cd admin_front_ts
npm run test -- tests/shared/payment/payment-recharge-page.test.ts tests/shared/payment/payment-recharge-api.test.ts
npm run build:check
```

Expected: tests pass and build check exits 0.

- [ ] **Step 7: Run repo-level governance checks**

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected: both exit 0.

- [ ] **Step 8: Final docs commit**

```powershell
git add docs/contracts/admin-api-v1.md docs/status/current-status.md docs/testing/smoke-matrix.md admin_back_go/docs/architecture.md
git commit -m "docs(payment): document recharge completion closure"
```

---

## Execution Notes

- TDD is mandatory: RED -> minimal implementation -> GREEN for each task.
- Keep callback raw audit bounded; never log private key, certificate content, APP_SECRET, bearer token, cookies, or plaintext app key.
- SDK network calls stay outside MySQL transactions.
- If `gopay` certificate verify method differs locally, adapt only `internal/platform/payment/alipay` and keep service interfaces stable.
- If live schema already has equivalent indexes, do not add duplicate indexes just to match names.
- If local callback cannot be reached by Alipay sandbox, use reopen auto sync and cron tests as local proof; do not claim callback manual smoke passed.

---

## Self-Review

Spec coverage:

```text
callback endpoint: Task 4
callback audit table: Task 1
SDK parse/verify boundary: Task 2
shared finalize: Task 3
cron sync/close: Task 5
frontend reopen sync: Task 6
docs/smoke/current-status: Task 7
idempotent wallet credit: Task 3/4/5 tests
public no-auth/no-RBAC/no-OperationLog callback: Task 4 tests
```

Placeholder scan:

```text
No TBD/TODO/fill-later placeholders. SDK method uncertainty is explicitly contained inside the platform boundary with a concrete local source inspection fallback.
```

Type consistency:

```text
Task types, cron names, route path, model names, process statuses, and finalizer source names are consistent across tasks.
```
