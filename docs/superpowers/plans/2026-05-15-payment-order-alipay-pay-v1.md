# Payment Order Alipay Pay V1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Execution status:** implemented and verified in this pass. The original checklist below is marked complete; final verification evidence is recorded in the handoff response and current repo state.

**Goal:** 在现有 `payment_configs` 基础上落地第一版支付宝支付订单：创建订单、拉起 web/h5 支付、手动同步状态、关闭未支付订单、后台列表和详情。

**Architecture:** 支付域仍归 `internal/module/payment`，新增订单能力使用 `order_*.go` 文件隔离配置代码；支付宝 SDK 只能在 `internal/platform/payment/alipay` 内使用。前端新增 `/payment/orders` 页面，严格使用 `Search`、`AppTable`、`AppDialog`，并保持路径、component、permission code、i18n key 和表名一次性命名定稿。

**Tech Stack:** Go, Gin, GORM, MySQL/InnoDB, go-pay/gopay v1.5.118, existing secretbox/cert resolver/RBAC/OperationLog, Vue 3 + TypeScript + Element Plus + existing `request` client + Vitest + vue-tsc.

---

## Scope Lock

只做：

```text
payment_orders schema
payment_order_* permissions
/payment/orders menu and Vue page
GET/POST /api/admin/v1/payment/orders*
支付宝 TradePagePay / TradeWapPay
支付宝 TradeQuery manual sync
支付宝 TradeClose / local close
contract/status/smoke/docs sync
```

不做：

```text
wallet
recharge accounting
refund
withdraw
split settlement
reconcile
WeChat
Alipay notify callback
payment event table
automatic cron sync
automatic cron close
business fulfillment
frontend cashier page
```

Linus check:

```text
True problem: yes. payment_configs can store credentials, but the project still cannot create a payable order.
Simpler way: one order table, one state machine, one Alipay gateway extension, one admin page.
What breaks: nothing existing should break. /payment/config and payment_config_* stay untouched; old /payment/order stays retired.
```

Spec source:

```text
docs/superpowers/specs/2026-05-15-payment-order-alipay-pay-v1-design.md
```

---

## Naming Lock

These names are mandatory:

| Layer | Name |
| --- | --- |
| DB table | `payment_orders` |
| Backend module | `admin_back_go/internal/module/payment` |
| Backend order files | `order_model.go`, `order_request.go`, `order_dto.go`, `order_repository.go`, `order_service.go`, `order_handler.go` |
| API resource | `/api/admin/v1/payment/orders` |
| Frontend API | `admin_front_ts/src/api/payment/orders.ts` |
| Frontend page | `admin_front_ts/src/views/Main/payment/orders` |
| Route path | `/payment/orders` |
| Permission component | `payment/orders` |
| Menu i18n | `menu.payment_order` |
| Page permission | `payment_order_list` |
| Button permissions | `payment_order_add`, `payment_order_pay`, `payment_order_sync`, `payment_order_close` |
| OperationLog module | `payment_order` |
| CSS block | `.payment-order-page` |

These names are forbidden:

```text
/payment/order
component=payment/order
payment_order_page
payment_order_detail
payment_order_create
payment_orders_*
src/views/Main/payment/order
src/api/payment/order.ts
```

---

## File Map

### Create

```text
admin_back_go/database/migrations/20260515_payment_order_alipay_pay_v1.sql
admin_back_go/internal/module/payment/order_model.go
admin_back_go/internal/module/payment/order_request.go
admin_back_go/internal/module/payment/order_dto.go
admin_back_go/internal/module/payment/order_repository.go
admin_back_go/internal/module/payment/order_service.go
admin_back_go/internal/module/payment/order_handler.go
admin_back_go/internal/module/payment/order_service_test.go
admin_back_go/internal/platform/payment/alipay/pay_test.go
admin_front_ts/src/api/payment/orders.ts
admin_front_ts/src/views/Main/payment/orders/index.vue
admin_front_ts/src/views/Main/payment/orders/components/PaymentOrderFormDialog.vue
admin_front_ts/src/views/Main/payment/orders/components/PaymentOrderDetailDialog.vue
admin_front_ts/src/views/Main/payment/orders/composables/usePaymentOrderPage.ts
admin_front_ts/tests/shared/payment/payment-order-api.test.ts
admin_front_ts/tests/shared/payment/payment-order-page.test.ts
```

### Modify

```text
admin_back_go/internal/platform/payment/gateway.go
admin_back_go/internal/platform/payment/alipay/types.go
admin_back_go/internal/platform/payment/alipay/gateway.go
admin_back_go/internal/module/payment/dto.go
admin_back_go/internal/module/payment/repository.go
admin_back_go/internal/module/payment/service.go
admin_back_go/internal/module/payment/handler.go
admin_back_go/internal/module/payment/route.go
admin_back_go/internal/module/payment/config_service_test.go
admin_back_go/internal/module/payment/config_handler_test.go
admin_back_go/internal/bootstrap/route_meta.go
admin_back_go/internal/bootstrap/route_meta_test.go
admin_back_go/internal/server/router_test.go
admin_front_ts/src/i18n/locales/zh-CN.ts
admin_front_ts/src/i18n/locales/en-US.ts
docs/contracts/admin-api-v1.md
docs/status/current-status.md
docs/testing/smoke-matrix.md
admin_back_go/docs/architecture.md
```

### Do Not Create

```text
admin_back_go/internal/module/paymentorder
admin_front_ts/src/views/Main/payment/order
admin_front_ts/src/api/payment/order.ts
admin_back_go/database/migrations/*payment_event*
admin_back_go/database/migrations/*wallet*
```

---

## Contract Lock

### API

```text
GET    /api/admin/v1/payment/orders/page-init
GET    /api/admin/v1/payment/orders
GET    /api/admin/v1/payment/orders/:id
POST   /api/admin/v1/payment/orders
POST   /api/admin/v1/payment/orders/:id/pay
POST   /api/admin/v1/payment/orders/:id/sync
PATCH  /api/admin/v1/payment/orders/:id/close
```

No order edit/delete endpoints:

```text
PUT    /api/admin/v1/payment/orders/:id
DELETE /api/admin/v1/payment/orders/:id
```

### States

```text
pending
paying
paid
closed
failed
```

### Field Ban

Do not add these fields to `payment_orders`, DTOs, frontend types, or docs:

```text
currency
business_type
business_ref
buyer_id
created_by
updated_by
notify_url
refund_amount
refund_status
raw_request
raw_response
extra_json
```

---

## Task 1: Schema, Menu, Permission Migration

**Files:**
- Create: `admin_back_go/database/migrations/20260515_payment_order_alipay_pay_v1.sql`

- [x] **Step 1: Create `payment_orders` table**

Create the migration with this table exactly:

```sql
CREATE TABLE IF NOT EXISTS `payment_orders` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `order_no` VARCHAR(64) NOT NULL,
  `config_id` BIGINT NOT NULL,
  `config_code` VARCHAR(64) NOT NULL,
  `provider` VARCHAR(32) NOT NULL DEFAULT 'alipay',
  `pay_method` VARCHAR(16) NOT NULL,
  `subject` VARCHAR(128) NOT NULL,
  `amount_cents` BIGINT NOT NULL,
  `status` VARCHAR(16) NOT NULL,
  `pay_url` VARCHAR(2048) NOT NULL DEFAULT '',
  `return_url` VARCHAR(512) NOT NULL DEFAULT '',
  `alipay_trade_no` VARCHAR(64) NOT NULL DEFAULT '',
  `expired_at` DATETIME NOT NULL,
  `paid_at` DATETIME NULL,
  `closed_at` DATETIME NULL,
  `failure_reason` VARCHAR(255) NOT NULL DEFAULT '',
  `is_del` TINYINT NOT NULL DEFAULT 2,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_payment_orders_order_no` (`order_no`),
  KEY `idx_payment_orders_isdel_status_created` (`is_del`, `status`, `created_at`),
  KEY `idx_payment_orders_config_created` (`config_id`, `created_at`, `is_del`),
  CONSTRAINT `fk_payment_orders_config`
    FOREIGN KEY (`config_id`) REFERENCES `payment_configs` (`id`)
    ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

- [x] **Step 2: Insert `/payment/orders` page permission**

Append this SQL after the table:

```sql
SET @payment_parent_id := (
  SELECT `id`
  FROM `permissions`
  WHERE `platform` = 'admin'
    AND `type` = 1
    AND `is_del` = 2
    AND (`code` = 'payment' OR `path` = '/payment' OR `i18n_key` = 'menu.payment')
  ORDER BY `id`
  LIMIT 1
);

INSERT INTO `permissions` (`name`, `path`, `icon`, `parent_id`, `component`, `platform`, `type`, `sort`, `code`, `i18n_key`, `show_menu`, `status`, `is_del`)
SELECT '支付订单', '/payment/orders', 'Tickets', @payment_parent_id, 'payment/orders', 'admin', 2, 20, 'payment_order_list', 'menu.payment_order', 1, 1, 2
WHERE @payment_parent_id IS NOT NULL
ON DUPLICATE KEY UPDATE
  `name` = VALUES(`name`),
  `path` = VALUES(`path`),
  `icon` = VALUES(`icon`),
  `parent_id` = VALUES(`parent_id`),
  `component` = VALUES(`component`),
  `type` = VALUES(`type`),
  `sort` = VALUES(`sort`),
  `i18n_key` = VALUES(`i18n_key`),
  `show_menu` = 1,
  `status` = 1,
  `is_del` = 2,
  `updated_at` = CURRENT_TIMESTAMP;
```

- [x] **Step 3: Insert button permissions**

Append this SQL:

```sql
SET @payment_order_page_id := (
  SELECT `id`
  FROM `permissions`
  WHERE `platform` = 'admin'
    AND `code` = 'payment_order_list'
    AND `is_del` = 2
  LIMIT 1
);

INSERT INTO `permissions` (`name`, `path`, `icon`, `parent_id`, `component`, `platform`, `type`, `sort`, `code`, `i18n_key`, `show_menu`, `status`, `is_del`)
SELECT button_name, '', '', @payment_order_page_id, '', 'admin', 3, button_sort, button_code, '', 2, 1, 2
FROM (
  SELECT '新增支付订单' AS button_name, 'payment_order_add' AS button_code, 1 AS button_sort
  UNION ALL SELECT '拉起支付宝支付', 'payment_order_pay', 2
  UNION ALL SELECT '同步支付订单状态', 'payment_order_sync', 3
  UNION ALL SELECT '关闭支付订单', 'payment_order_close', 4
) AS payment_order_buttons
WHERE @payment_order_page_id IS NOT NULL
ON DUPLICATE KEY UPDATE
  `name` = VALUES(`name`),
  `parent_id` = VALUES(`parent_id`),
  `type` = VALUES(`type`),
  `sort` = VALUES(`sort`),
  `show_menu` = 2,
  `status` = 1,
  `is_del` = 2,
  `updated_at` = CURRENT_TIMESTAMP;
```

- [x] **Step 4: Grant order permissions to roles that can manage payment config**

Append this SQL:

```sql
CREATE TEMPORARY TABLE IF NOT EXISTS `tmp_payment_order_permission_grant_roles` (
  `role_id` INT UNSIGNED NOT NULL PRIMARY KEY
) ENGINE=MEMORY;

TRUNCATE TABLE `tmp_payment_order_permission_grant_roles`;

INSERT IGNORE INTO `tmp_payment_order_permission_grant_roles` (`role_id`)
SELECT DISTINCT rp.`role_id`
FROM `role_permissions` rp
JOIN `permissions` p ON p.`id` = rp.`permission_id`
JOIN `roles` r ON r.`id` = rp.`role_id`
WHERE rp.`is_del` = 2
  AND p.`is_del` = 2
  AND r.`is_del` = 2
  AND p.`platform` = 'admin'
  AND p.`code` IN ('payment_config_list', 'payment_config_edit', 'payment_config_test');

INSERT INTO `role_permissions` (`role_id`, `permission_id`, `is_del`)
SELECT gr.`role_id`, p.`id`, 2
FROM `tmp_payment_order_permission_grant_roles` gr
JOIN `permissions` p ON p.`platform` = 'admin'
  AND p.`is_del` = 2
  AND p.`code` IN (
    'payment_order_list',
    'payment_order_add',
    'payment_order_pay',
    'payment_order_sync',
    'payment_order_close'
  )
ON DUPLICATE KEY UPDATE
  `is_del` = 2,
  `updated_at` = CURRENT_TIMESTAMP;

DROP TEMPORARY TABLE IF EXISTS `tmp_payment_order_permission_grant_roles`;
```

- [x] **Step 5: Run static SQL sanity checks**

Run:

```powershell
rg -n "payment_order_page|payment_orders_\\*|/payment/order[^s]|payment/order" admin_back_go/database/migrations/20260515_payment_order_alipay_pay_v1.sql
```

Expected: no output.

Run:

```powershell
rg -n "payment_orders|payment_order_list|payment_order_add|payment_order_pay|payment_order_sync|payment_order_close|menu.payment_order|component" admin_back_go/database/migrations/20260515_payment_order_alipay_pay_v1.sql
```

Expected: output contains `payment_orders`, `/payment/orders`, `payment/orders`, and all five `payment_order_*` codes.

---

## Task 2: Alipay Gateway Pay/Query/Close Boundary

**Files:**
- Modify: `admin_back_go/internal/platform/payment/gateway.go`
- Modify: `admin_back_go/internal/platform/payment/alipay/types.go`
- Modify: `admin_back_go/internal/platform/payment/alipay/gateway.go`
- Create: `admin_back_go/internal/platform/payment/alipay/pay_test.go`

- [x] **Step 1: Write gateway unit tests**

Create `pay_test.go` with tests for pure helpers:

```go
package alipay

import (
	"testing"
	"time"
)

func TestFormatAmountCents(t *testing.T) {
	cases := []struct {
		name  string
		cents int64
		want  string
	}{
		{name: "one yuan", cents: 100, want: "1.00"},
		{name: "yuan and cents", cents: 1234, want: "12.34"},
		{name: "one cent", cents: 1, want: "0.01"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got, err := formatAmountCents(tc.cents)
			if err != nil {
				t.Fatalf("formatAmountCents error=%v", err)
			}
			if got != tc.want {
				t.Fatalf("amount=%s want=%s", got, tc.want)
			}
		})
	}
}

func TestFormatAmountCentsRejectsInvalidAmount(t *testing.T) {
	for _, cents := range []int64{0, -1} {
		if _, err := formatAmountCents(cents); err == nil {
			t.Fatalf("expected error for cents=%d", cents)
		}
	}
}

func TestBuildPayBodyUsesReturnURLAndExpireTime(t *testing.T) {
	expiredAt := time.Date(2026, 5, 15, 13, 30, 0, 0, time.UTC)
	body, err := buildPayBody(PayInput{
		OutTradeNo:  "PAY202605150001",
		Method:      "web",
		Subject:     "测试订单",
		AmountCents: 1234,
		ReturnURL:   "https://example.test/pay/result",
		ExpiredAt:   expiredAt,
	})
	if err != nil {
		t.Fatalf("buildPayBody error=%v", err)
	}
	if body.GetString("out_trade_no") != "PAY202605150001" {
		t.Fatalf("unexpected out_trade_no: %s", body.GetString("out_trade_no"))
	}
	if body.GetString("total_amount") != "12.34" {
		t.Fatalf("unexpected total_amount: %s", body.GetString("total_amount"))
	}
	if body.GetString("return_url") != "https://example.test/pay/result" {
		t.Fatalf("unexpected return_url: %s", body.GetString("return_url"))
	}
	if body.GetString("time_expire") != "2026-05-15 13:30:00" {
		t.Fatalf("unexpected time_expire: %s", body.GetString("time_expire"))
	}
}
```

- [x] **Step 2: Run tests and verify they fail**

Run:

```powershell
cd admin_back_go
go test ./internal/platform/payment/alipay -run "TestFormatAmountCents|TestBuildPayBody" -count=1
```

Expected: fail with undefined `formatAmountCents`, `buildPayBody`, or `PayInput`.

- [x] **Step 3: Extend platform payment interface**

In `admin_back_go/internal/platform/payment/gateway.go`, add:

```go
type PayInput struct {
	OutTradeNo  string
	Method      string
	Subject     string
	AmountCents int64
	ReturnURL   string
	ExpiredAt   time.Time
}

type PayResult struct {
	PayURL string
}

type QueryResult struct {
	TradeNo string
	Status  string
	PaidAt  *time.Time
}

type Gateway interface {
	TestConfig(ctx context.Context, cfg ChannelConfig) error
	Pay(ctx context.Context, cfg ChannelConfig, in PayInput) (*PayResult, error)
	Query(ctx context.Context, cfg ChannelConfig, outTradeNo string) (*QueryResult, error)
	Close(ctx context.Context, cfg ChannelConfig, outTradeNo string) error
}
```

Use `time.Time` from the standard library. Keep `ChannelConfig` unchanged.

- [x] **Step 4: Mirror types in alipay package or alias platform types**

In `admin_back_go/internal/platform/payment/alipay/types.go`, choose one clean option:

```go
type PayInput = payment.PayInput
type PayResult = payment.PayResult
type QueryResult = payment.QueryResult
```

Import:

```go
import (
	"context"

	"admin_back_go/internal/platform/payment"
)
```

Keep the existing `ChannelConfig` type if current tests depend on it, but the preferred boundary is to accept `payment.ChannelConfig` in `GopayGateway`.

- [x] **Step 5: Implement helper functions and gateway methods**

In `gateway.go`, add:

```go
func formatAmountCents(cents int64) (string, error) {
	if cents <= 0 {
		return "", errors.New("alipay: amount cents must be positive")
	}
	return fmt.Sprintf("%d.%02d", cents/100, cents%100), nil
}

func buildPayBody(in PayInput) (gopay.BodyMap, error) {
	if strings.TrimSpace(in.OutTradeNo) == "" {
		return nil, errors.New("alipay: out trade no is required")
	}
	if strings.TrimSpace(in.Subject) == "" {
		return nil, errors.New("alipay: subject is required")
	}
	amount, err := formatAmountCents(in.AmountCents)
	if err != nil {
		return nil, err
	}
	body := make(gopay.BodyMap)
	body.Set("out_trade_no", strings.TrimSpace(in.OutTradeNo))
	body.Set("total_amount", amount)
	body.Set("subject", strings.TrimSpace(in.Subject))
	if returnURL := strings.TrimSpace(in.ReturnURL); returnURL != "" {
		body.Set("return_url", returnURL)
	}
	if !in.ExpiredAt.IsZero() {
		body.Set("time_expire", in.ExpiredAt.Format("2006-01-02 15:04:05"))
	}
	return body, nil
}
```

Add `Pay`:

```go
func (g *GopayGateway) Pay(ctx context.Context, cfg ChannelConfig, in PayInput) (*PayResult, error) {
	client, err := newClient(cfg)
	if err != nil {
		return nil, err
	}
	body, err := buildPayBody(in)
	if err != nil {
		return nil, err
	}
	var payURL string
	switch strings.TrimSpace(in.Method) {
	case "web":
		payURL, err = client.TradePagePay(ctx, body)
	case "h5":
		payURL, err = client.TradeWapPay(ctx, body)
	default:
		return nil, fmt.Errorf("alipay: unsupported pay method %q", in.Method)
	}
	if err != nil {
		return nil, fmt.Errorf("alipay: create pay url: %w", err)
	}
	return &PayResult{PayURL: payURL}, nil
}
```

Add `Query` and `Close` using `TradeQuery` and `TradeClose`; map Alipay statuses to the raw strings returned by SDK response. The service layer will convert raw Alipay status to local state.

- [x] **Step 6: Run gateway tests**

Run:

```powershell
cd admin_back_go
go test ./internal/platform/payment ./internal/platform/payment/alipay -count=1
```

Expected: pass.

---

## Task 3: Order Model, Repository, DTO, State Machine

**Files:**
- Create: `admin_back_go/internal/module/payment/order_model.go`
- Create: `admin_back_go/internal/module/payment/order_dto.go`
- Create: `admin_back_go/internal/module/payment/order_repository.go`
- Modify: `admin_back_go/internal/module/payment/repository.go`
- Modify: `admin_back_go/internal/module/payment/dto.go`
- Create: `admin_back_go/internal/module/payment/order_service.go`
- Modify: `admin_back_go/internal/module/payment/service.go`
- Create: `admin_back_go/internal/module/payment/order_service_test.go`
- Modify: `admin_back_go/internal/module/payment/config_service_test.go`

- [x] **Step 1: Write service tests first**

Create `order_service_test.go` with table-driven tests covering:

```text
CreateOrder stores pending order and copies config_id/config_code/provider.
CreateOrder rejects disabled config.
CreateOrder rejects pay_method not in enabled_methods_json.
PayOrder changes pending -> paying and stores pay_url.
PayOrder changes pending -> failed and stores failure_reason when gateway fails.
PayOrder returns existing pay_url for paying order.
SyncOrder maps TRADE_SUCCESS -> paid and writes alipay_trade_no/paid_at.
SyncOrder maps TRADE_CLOSED -> closed and writes closed_at.
CloseOrder rejects paid.
CloseOrder closes pending locally.
CloseOrder calls gateway close for paying.
```

Use fake repository and fake gateway in the same file. The fake gateway must implement all methods on the updated `gateway.Gateway`:

```go
type fakeOrderGateway struct {
	payResult   *gateway.PayResult
	payErr      error
	queryResult *gateway.QueryResult
	queryErr    error
	closeErr    error
	closeCount  int
	payInput    gateway.PayInput
}

func (g *fakeOrderGateway) TestConfig(ctx context.Context, cfg gateway.ChannelConfig) error { return nil }
func (g *fakeOrderGateway) Pay(ctx context.Context, cfg gateway.ChannelConfig, in gateway.PayInput) (*gateway.PayResult, error) {
	g.payInput = in
	if g.payErr != nil {
		return nil, g.payErr
	}
	return g.payResult, nil
}
func (g *fakeOrderGateway) Query(ctx context.Context, cfg gateway.ChannelConfig, outTradeNo string) (*gateway.QueryResult, error) {
	if g.queryErr != nil {
		return nil, g.queryErr
	}
	return g.queryResult, nil
}
func (g *fakeOrderGateway) Close(ctx context.Context, cfg gateway.ChannelConfig, outTradeNo string) error {
	g.closeCount++
	return g.closeErr
}
```

- [x] **Step 2: Run tests and verify they fail**

Run:

```powershell
cd admin_back_go
go test ./internal/module/payment -run "TestCreateOrder|TestPayOrder|TestSyncOrder|TestCloseOrder" -count=1
```

Expected: fail because order service types and methods do not exist.

- [x] **Step 3: Add order model**

Create `order_model.go`:

```go
package payment

import "time"

type Order struct {
	ID             int64      `gorm:"column:id;primaryKey"`
	OrderNo        string     `gorm:"column:order_no"`
	ConfigID       int64      `gorm:"column:config_id"`
	ConfigCode     string     `gorm:"column:config_code"`
	Provider       string     `gorm:"column:provider"`
	PayMethod      string     `gorm:"column:pay_method"`
	Subject        string     `gorm:"column:subject"`
	AmountCents    int64      `gorm:"column:amount_cents"`
	Status         string     `gorm:"column:status"`
	PayURL         string     `gorm:"column:pay_url"`
	ReturnURL      string     `gorm:"column:return_url"`
	AlipayTradeNo  string     `gorm:"column:alipay_trade_no"`
	ExpiredAt      time.Time  `gorm:"column:expired_at"`
	PaidAt         *time.Time `gorm:"column:paid_at"`
	ClosedAt       *time.Time `gorm:"column:closed_at"`
	FailureReason  string     `gorm:"column:failure_reason"`
	IsDel          int        `gorm:"column:is_del"`
	CreatedAt      time.Time  `gorm:"column:created_at"`
	UpdatedAt      time.Time  `gorm:"column:updated_at"`
}

func (Order) TableName() string { return "payment_orders" }
```

- [x] **Step 4: Add order DTOs and constants**

Create `order_dto.go` with:

```go
const (
	orderStatusPending = "pending"
	orderStatusPaying  = "paying"
	orderStatusPaid    = "paid"
	orderStatusClosed  = "closed"
	orderStatusFailed  = "failed"
)

type OrderInitResponse struct {
	Dict          OrderInitDict       `json:"dict"`
	ConfigOptions []OrderConfigOption `json:"config_options"`
}

type OrderInitDict struct {
	ProviderArr    []dict.Option[string] `json:"provider_arr"`
	PayMethodArr   []dict.Option[string] `json:"pay_method_arr"`
	OrderStatusArr []dict.Option[string] `json:"order_status_arr"`
}

type OrderListQuery struct {
	CurrentPage int
	PageSize    int
	Keyword     string
	ConfigCode  string
	Provider    string
	PayMethod   string
	Status      string
	DateStart   string
	DateEnd     string
}

type OrderCreateInput struct {
	ConfigCode    string
	PayMethod     string
	Subject       string
	AmountCents   int64
	ReturnURL     string
	ExpireMinutes int
}
```

Keep JSON response fields aligned with the spec: `order_no`, `config_code`, `provider_text`, `pay_method_text`, `amount_text`, `status_text`, `pay_url`, `return_url`, `alipay_trade_no`, `expired_at`, `paid_at`, `closed_at`, `created_at`, `updated_at`.

- [x] **Step 5: Add repository methods**

Create `order_repository.go` for GORM queries. Extend the existing `Repository` interface in `repository.go` with:

```go
ListOrders(ctx context.Context, query OrderListQuery) ([]Order, int64, error)
GetOrder(ctx context.Context, id int64) (*Order, error)
CreateOrder(ctx context.Context, order Order) (int64, error)
UpdateOrderPaying(ctx context.Context, id int64, payURL string) error
UpdateOrderFailed(ctx context.Context, id int64, reason string) error
UpdateOrderPaid(ctx context.Context, id int64, tradeNo string, paidAt time.Time) error
UpdateOrderClosed(ctx context.Context, id int64, closedAt time.Time) error
ListEnabledOrderConfigOptions(ctx context.Context) ([]Config, error)
```

Every query must include:

```go
Where("is_del = ?", enum.CommonNo)
```

No repository method may decide allowed state transitions. Repository only reads/writes rows.

- [x] **Step 6: Implement service methods**

Create `order_service.go` and add methods on `Service`:

```go
func (s *Service) OrderInit(ctx context.Context) (*OrderInitResponse, *apperror.Error)
func (s *Service) ListOrders(ctx context.Context, query OrderListQuery) (*OrderListResponse, *apperror.Error)
func (s *Service) GetOrder(ctx context.Context, id int64) (*OrderDetail, *apperror.Error)
func (s *Service) CreateOrder(ctx context.Context, input OrderCreateInput) (*OrderCreateResponse, *apperror.Error)
func (s *Service) PayOrder(ctx context.Context, id int64) (*OrderPayResponse, *apperror.Error)
func (s *Service) SyncOrder(ctx context.Context, id int64) (*OrderStatusResponse, *apperror.Error)
func (s *Service) CloseOrder(ctx context.Context, id int64) (*OrderStatusResponse, *apperror.Error)
```

Rules to encode:

```text
Create -> pending
Pay pending/failed -> paying or failed
Pay paying with pay_url -> return existing pay_url
Sync paying + TRADE_SUCCESS/TRADE_FINISHED -> paid
Sync paying + TRADE_CLOSED -> closed
Sync paying + WAIT_BUYER_PAY -> paying
Close pending/failed -> closed locally
Close paying -> gateway close then closed
Close paid -> apperror.BadRequest("已支付订单不能关闭")
```

Generate `order_no` with a deterministic helper using `Now`:

```go
func newPaymentOrderNo(now time.Time) string {
	return "PAY" + now.Format("20060102150405") + fmt.Sprintf("%06d", now.Nanosecond()%1000000)
}
```

If tests need multiple order numbers in the same nanosecond, pass different `Now` values in test cases; do not add global mutable counters.

- [x] **Step 7: Update fake config gateway in existing tests**

In `config_service_test.go`, extend `fakeGateway`:

```go
func (g *fakeGateway) Pay(ctx context.Context, cfg gateway.ChannelConfig, in gateway.PayInput) (*gateway.PayResult, error) {
	return &gateway.PayResult{PayURL: "https://example.test/pay"}, nil
}
func (g *fakeGateway) Query(ctx context.Context, cfg gateway.ChannelConfig, outTradeNo string) (*gateway.QueryResult, error) {
	return &gateway.QueryResult{Status: "WAIT_BUYER_PAY"}, nil
}
func (g *fakeGateway) Close(ctx context.Context, cfg gateway.ChannelConfig, outTradeNo string) error {
	return nil
}
```

- [x] **Step 8: Run payment module tests**

Run:

```powershell
cd admin_back_go
go test ./internal/module/payment -count=1
```

Expected: pass.

---

## Task 4: Order HTTP Handlers, Routes, RBAC Route Meta

**Files:**
- Create: `admin_back_go/internal/module/payment/order_request.go`
- Create: `admin_back_go/internal/module/payment/order_handler.go`
- Modify: `admin_back_go/internal/module/payment/handler.go`
- Modify: `admin_back_go/internal/module/payment/route.go`
- Modify: `admin_back_go/internal/bootstrap/route_meta.go`
- Modify: `admin_back_go/internal/bootstrap/route_meta_test.go`
- Modify: `admin_back_go/internal/server/router_test.go`
- Modify: `admin_back_go/internal/module/payment/config_handler_test.go`

- [x] **Step 1: Add request binding structs**

Create `order_request.go`:

```go
type listOrdersRequest struct {
	CurrentPage int    `form:"current_page" binding:"omitempty,min=1"`
	PageSize    int    `form:"page_size" binding:"omitempty,min=1,max=50"`
	Keyword     string `form:"keyword" binding:"max=128"`
	ConfigCode  string `form:"config_code" binding:"max=64"`
	Provider    string `form:"provider" binding:"omitempty,oneof=alipay"`
	PayMethod   string `form:"pay_method" binding:"omitempty,oneof=web h5"`
	Status      string `form:"status" binding:"omitempty,oneof=pending paying paid closed failed"`
	DateStart   string `form:"date_start" binding:"omitempty,max=20"`
	DateEnd     string `form:"date_end" binding:"omitempty,max=20"`
}

type createOrderRequest struct {
	ConfigCode    string `json:"config_code" binding:"required,max=64"`
	PayMethod     string `json:"pay_method" binding:"required,oneof=web h5"`
	Subject       string `json:"subject" binding:"required,max=128"`
	AmountCents   int64  `json:"amount_cents" binding:"required,min=1"`
	ReturnURL     string `json:"return_url" binding:"omitempty,max=512"`
	ExpireMinutes int    `json:"expire_minutes" binding:"omitempty,min=1,max=1440"`
}
```

- [x] **Step 2: Add handler methods**

Create `order_handler.go` with methods:

```go
func (h *Handler) OrderInit(c *gin.Context)
func (h *Handler) ListOrders(c *gin.Context)
func (h *Handler) GetOrder(c *gin.Context)
func (h *Handler) CreateOrder(c *gin.Context)
func (h *Handler) PayOrder(c *gin.Context)
func (h *Handler) SyncOrder(c *gin.Context)
func (h *Handler) CloseOrder(c *gin.Context)
```

Use existing `routeInt64`, `writeResult`, and `writeEmpty` patterns. Route id error text:

```text
无效的支付订单ID
```

- [x] **Step 3: Extend service interface**

Where the payment `HTTPService` interface is defined, add:

```go
OrderInit(ctx context.Context) (*OrderInitResponse, *apperror.Error)
ListOrders(ctx context.Context, query OrderListQuery) (*OrderListResponse, *apperror.Error)
GetOrder(ctx context.Context, id int64) (*OrderDetail, *apperror.Error)
CreateOrder(ctx context.Context, input OrderCreateInput) (*OrderCreateResponse, *apperror.Error)
PayOrder(ctx context.Context, id int64) (*OrderPayResponse, *apperror.Error)
SyncOrder(ctx context.Context, id int64) (*OrderStatusResponse, *apperror.Error)
CloseOrder(ctx context.Context, id int64) (*OrderStatusResponse, *apperror.Error)
```

- [x] **Step 4: Register routes**

In `route.go`, keep config routes and add:

```go
orders := router.Group("/api/admin/v1/payment/orders")
orders.GET("/page-init", handler.OrderInit)
orders.GET("", handler.ListOrders)
orders.GET("/:id", handler.GetOrder)
orders.POST("", handler.CreateOrder)
orders.POST("/:id/pay", handler.PayOrder)
orders.POST("/:id/sync", handler.SyncOrder)
orders.PATCH("/:id/close", handler.CloseOrder)
```

- [x] **Step 5: Update route registration tests**

In `config_handler_test.go`, rename the test to reflect both config and order endpoints or add a new test. It must assert these exist:

```text
GET /api/admin/v1/payment/orders/page-init
GET /api/admin/v1/payment/orders
GET /api/admin/v1/payment/orders/:id
POST /api/admin/v1/payment/orders
POST /api/admin/v1/payment/orders/:id/pay
POST /api/admin/v1/payment/orders/:id/sync
PATCH /api/admin/v1/payment/orders/:id/close
```

It must still assert retired endpoints are absent:

```text
GET /api/admin/v1/payment/channels
GET /api/admin/v1/payment/events
POST /api/payment/notify/alipay
GET /api/admin/v1/payment/order
```

- [x] **Step 6: Add route meta permission codes**

In `route_meta.go`, add:

```go
middleware.NewRouteKey(http.MethodGet, "/api/admin/v1/payment/orders/page-init"): "payment_order_list",
middleware.NewRouteKey(http.MethodGet, "/api/admin/v1/payment/orders"):           "payment_order_list",
middleware.NewRouteKey(http.MethodGet, "/api/admin/v1/payment/orders/:id"):       "payment_order_list",
middleware.NewRouteKey(http.MethodPost, "/api/admin/v1/payment/orders"):          "payment_order_add",
middleware.NewRouteKey(http.MethodPost, "/api/admin/v1/payment/orders/:id/pay"):  "payment_order_pay",
middleware.NewRouteKey(http.MethodPost, "/api/admin/v1/payment/orders/:id/sync"): "payment_order_sync",
middleware.NewRouteKey(http.MethodPatch, "/api/admin/v1/payment/orders/:id/close"): "payment_order_close",
```

Add operation log rules:

```go
middleware.NewRouteKey(http.MethodPost, "/api/admin/v1/payment/orders"): {
	Module: "payment_order",
	Action: "create",
	Title:  "新增支付订单",
},
middleware.NewRouteKey(http.MethodPost, "/api/admin/v1/payment/orders/:id/pay"): {
	Module:              "payment_order",
	Action:              "pay",
	Title:               "拉起支付宝支付",
	SkipResponsePayload: true,
},
middleware.NewRouteKey(http.MethodPost, "/api/admin/v1/payment/orders/:id/sync"): {
	Module: "payment_order",
	Action: "sync",
	Title:  "同步支付订单状态",
},
middleware.NewRouteKey(http.MethodPatch, "/api/admin/v1/payment/orders/:id/close"): {
	Module: "payment_order",
	Action: "close",
	Title:  "关闭支付订单",
},
```

- [x] **Step 7: Update route meta tests**

In `route_meta_test.go`, assert:

```text
/api/admin/v1/payment/orders/page-init -> payment_order_list
/api/admin/v1/payment/orders -> payment_order_list/payment_order_add depending method
/api/admin/v1/payment/orders/:id/pay -> payment_order_pay
/api/admin/v1/payment/orders/:id/sync -> payment_order_sync
/api/admin/v1/payment/orders/:id/close -> payment_order_close
```

Assert `pay` route has:

```go
rule.Module == "payment_order"
rule.Action == "pay"
rule.SkipResponsePayload == true
```

- [x] **Step 8: Run backend route tests**

Run:

```powershell
cd admin_back_go
go test ./internal/module/payment ./internal/bootstrap ./internal/server -count=1
```

Expected: pass.

---

## Task 5: Frontend Payment Order API Contract

**Files:**
- Create: `admin_front_ts/src/api/payment/orders.ts`
- Create: `admin_front_ts/tests/shared/payment/payment-order-api.test.ts`

- [x] **Step 1: Write frontend API contract test**

Create `payment-order-api.test.ts`:

```ts
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { describe, expect, it } from 'vitest'

const read = (path: string) => readFileSync(resolve(process.cwd(), path), 'utf8')
const loose = new RegExp(`\\b${'an'}${'y'}\\b|as ${'an'}${'y'}|Record<string, ${'an'}${'y'}>`)

describe('payment order api', () => {
  it('uses canonical orders REST paths and strict payloads', () => {
    const source = read('src/api/payment/orders.ts')
    expect(source).toContain('request.get<PaymentOrderInitResponse>(`${ADMIN_API_PREFIX}/payment/orders/page-init`)')
    expect(source).toContain('request.get<PaginatedResponse<PaymentOrderListItem>>(`${ADMIN_API_PREFIX}/payment/orders`')
    expect(source).toContain('request.get<PaymentOrderDetail>(`${ADMIN_API_PREFIX}/payment/orders/${positiveID(id)}`)')
    expect(source).toContain('request.post<PaymentOrderCreateResponse, PaymentOrderCreatePayload>(`${ADMIN_API_PREFIX}/payment/orders`')
    expect(source).toContain('request.post<PaymentOrderPayResponse>(`${ADMIN_API_PREFIX}/payment/orders/${positiveID(id)}/pay`)')
    expect(source).toContain('request.post<PaymentOrderStatusResponse>(`${ADMIN_API_PREFIX}/payment/orders/${positiveID(id)}/sync`)')
    expect(source).toContain('request.patch<PaymentOrderStatusResponse>(`${ADMIN_API_PREFIX}/payment/orders/${positiveID(id)}/close`)')
    expect(source).not.toContain('/payment/order`')
    expect(source).not.toContain('/payment/channels')
    expect(source).not.toContain('/payment/events')
    expect(source).toContain("export type PaymentOrderProvider = 'alipay'")
    expect(source).toContain("export type PaymentOrderPayMethod = 'web' | 'h5'")
    expect(source).toContain("export type PaymentOrderStatus = 'pending' | 'paying' | 'paid' | 'closed' | 'failed'")
    expect(source).toContain('amount_cents: number')
    expect(source).toContain('return_url: string')
    expect(source).not.toContain('business_type')
    expect(source).not.toContain('refund_status')
    expect(source).not.toContain('extra_json')
    expect(source).not.toMatch(loose)
  })
})
```

- [x] **Step 2: Run test and verify it fails**

Run:

```powershell
cd admin_front_ts
npx vitest run tests/shared/payment/payment-order-api.test.ts
```

Expected: fail because `src/api/payment/orders.ts` does not exist.

- [x] **Step 3: Create typed API client**

Create `src/api/payment/orders.ts`:

```ts
import request from '@/lib/http'
import { ADMIN_API_PREFIX } from '@/lib/http/api-prefix'
import type { DictOption, PaginatedResponse } from '@/types/common'

export type PaymentOrderProvider = 'alipay'
export type PaymentOrderPayMethod = 'web' | 'h5'
export type PaymentOrderStatus = 'pending' | 'paying' | 'paid' | 'closed' | 'failed'

export interface PaymentOrderInitResponse {
  dict: {
    provider_arr: DictOption<PaymentOrderProvider>[]
    pay_method_arr: DictOption<PaymentOrderPayMethod>[]
    order_status_arr: DictOption<PaymentOrderStatus>[]
  }
  config_options: Array<{
    label: string
    value: string
    provider: PaymentOrderProvider
    enabled_methods: PaymentOrderPayMethod[]
  }>
}

export interface PaymentOrderListParams {
  current_page: number
  page_size: number
  keyword?: string
  config_code?: string
  provider?: PaymentOrderProvider | ''
  pay_method?: PaymentOrderPayMethod | ''
  status?: PaymentOrderStatus | ''
  date_start?: string
  date_end?: string
}

export interface PaymentOrderListItem {
  id: number
  order_no: string
  config_code: string
  provider: PaymentOrderProvider
  provider_text: string
  pay_method: PaymentOrderPayMethod
  pay_method_text: string
  subject: string
  amount_cents: number
  amount_text: string
  status: PaymentOrderStatus
  status_text: string
  expired_at: string
  created_at: string
  updated_at: string
}

export interface PaymentOrderDetail extends PaymentOrderListItem {
  pay_url: string
  return_url: string
  alipay_trade_no: string
  paid_at: string
  closed_at: string
  failure_reason: string
}

export interface PaymentOrderCreatePayload {
  config_code: string
  pay_method: PaymentOrderPayMethod
  subject: string
  amount_cents: number
  return_url: string
  expire_minutes: number
}

export interface PaymentOrderCreateResponse {
  id: number
  order_no: string
  status: PaymentOrderStatus
}

export interface PaymentOrderPayResponse {
  id: number
  order_no: string
  status: PaymentOrderStatus
  pay_url: string
}

export interface PaymentOrderStatusResponse {
  id: number
  order_no: string
  status: PaymentOrderStatus
  status_text: string
  alipay_trade_no: string
  paid_at: string
  closed_at: string
}

function positiveID(value: number): number {
  if (!Number.isInteger(value) || value <= 0) throw new Error('payment order id must be positive')
  return value
}

export const PaymentOrderApi = {
  init: () => request.get<PaymentOrderInitResponse>(`${ADMIN_API_PREFIX}/payment/orders/page-init`),
  list: (params: PaymentOrderListParams) => request.get<PaginatedResponse<PaymentOrderListItem>>(`${ADMIN_API_PREFIX}/payment/orders`, { params }),
  detail: (id: number) => request.get<PaymentOrderDetail>(`${ADMIN_API_PREFIX}/payment/orders/${positiveID(id)}`),
  add: (payload: PaymentOrderCreatePayload) => request.post<PaymentOrderCreateResponse, PaymentOrderCreatePayload>(`${ADMIN_API_PREFIX}/payment/orders`, payload),
  pay: (id: number) => request.post<PaymentOrderPayResponse>(`${ADMIN_API_PREFIX}/payment/orders/${positiveID(id)}/pay`),
  sync: (id: number) => request.post<PaymentOrderStatusResponse>(`${ADMIN_API_PREFIX}/payment/orders/${positiveID(id)}/sync`),
  close: (id: number) => request.patch<PaymentOrderStatusResponse>(`${ADMIN_API_PREFIX}/payment/orders/${positiveID(id)}/close`),
}
```

- [x] **Step 4: Run frontend API test**

Run:

```powershell
cd admin_front_ts
npx vitest run tests/shared/payment/payment-order-api.test.ts
```

Expected: pass.

---

## Task 6: Frontend Payment Orders Page

**Files:**
- Create: `admin_front_ts/src/views/Main/payment/orders/index.vue`
- Create: `admin_front_ts/src/views/Main/payment/orders/components/PaymentOrderFormDialog.vue`
- Create: `admin_front_ts/src/views/Main/payment/orders/components/PaymentOrderDetailDialog.vue`
- Create: `admin_front_ts/src/views/Main/payment/orders/composables/usePaymentOrderPage.ts`
- Create: `admin_front_ts/tests/shared/payment/payment-order-page.test.ts`
- Modify: `admin_front_ts/src/i18n/locales/zh-CN.ts`
- Modify: `admin_front_ts/src/i18n/locales/en-US.ts`

- [x] **Step 1: Write page structure test**

Create `payment-order-page.test.ts`:

```ts
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { describe, expect, it } from 'vitest'

const read = (path: string) => readFileSync(resolve(process.cwd(), path), 'utf8')

describe('payment order page', () => {
  it('uses canonical names and shared Search/AppTable/AppDialog primitives', () => {
    const page = read('src/views/Main/payment/orders/index.vue')
    const composable = read('src/views/Main/payment/orders/composables/usePaymentOrderPage.ts')
    const form = read('src/views/Main/payment/orders/components/PaymentOrderFormDialog.vue')
    const detail = read('src/views/Main/payment/orders/components/PaymentOrderDetailDialog.vue')
    const zh = read('src/i18n/locales/zh-CN.ts')
    const en = read('src/i18n/locales/en-US.ts')

    expect(page).toContain("import { Search } from '@/components/Search'")
    expect(page).toContain("import { AppTable } from '@/components/Table'")
    expect(page).toContain("import { AppDialog } from '@/components/AppDialog'")
    expect(page).toContain("userStore.can('payment_order_add')")
    expect(page).toContain("userStore.can('payment_order_pay')")
    expect(page).toContain("userStore.can('payment_order_sync')")
    expect(page).toContain("userStore.can('payment_order_close')")
    expect(page).toContain(':height="dialogLayout.height"')
    expect(page).toContain(':top="dialogLayout.top"')
    expect(page).toContain('class="payment-order-page"')
    expect(composable).toContain("from '@/api/payment/orders'")
    expect(composable).toContain('PaymentOrderApi.init()')
    expect(composable).toContain('PaymentOrderApi.pay(row.id)')
    expect(composable).toContain('PaymentOrderApi.sync(row.id)')
    expect(composable).toContain('PaymentOrderApi.close(row.id)')
    expect(form).toContain('amount_cents')
    expect(form).toContain('return_url')
    expect(detail).toContain('pay_url')
    expect(`${page}\n${composable}\n${form}\n${detail}`).not.toContain('/payment/order')
    expect(`${page}\n${composable}\n${form}\n${detail}`).not.toContain('payment_order_page')
    expect(`${page}\n${composable}\n${form}\n${detail}`).not.toContain('payment_orders_')
    expect(zh).toContain("payment_order: '支付订单'")
    expect(en).toContain("payment_order: 'Payment Orders'")
  })
})
```

- [x] **Step 2: Run test and verify it fails**

Run:

```powershell
cd admin_front_ts
npx vitest run tests/shared/payment/payment-order-page.test.ts
```

Expected: fail because page files do not exist.

- [x] **Step 3: Add i18n keys**

In both locale files under `menu`, add:

```ts
payment_order: '支付订单'
```

and:

```ts
payment_order: 'Payment Orders'
```

- [x] **Step 4: Create composable**

Create `usePaymentOrderPage.ts` with:

```text
dict shallowRef from PaymentOrderInitResponse
searchForm ref<PaymentOrderListParams>
useTable<PaymentOrderListItem, PaymentOrderListParams>({ api: PaymentOrderApi, searchForm })
columns computed for order_no/config_code/provider_text/pay_method_text/subject/amount_text/status_text/expired_at/created_at/updated_at/actions
searchFields computed for keyword/config_code/pay_method/status/date range
formDialogVisible, detailDialogVisible
form ref<PaymentOrderCreatePayload>
openAddDialog
confirmCreate
payOrder
syncOrder
closeOrder
openDetailDialog
```

Amount handling rule:

```text
UI may show amount in yuan.
Payload must send amount_cents integer.
Use Math.round(yuan * 100) only at the form boundary.
Never send floating amount to backend.
```

- [x] **Step 5: Create form dialog component**

`PaymentOrderFormDialog.vue` responsibilities:

```text
Render config_code select from config_options.
Render pay_method select from enabled methods.
Render subject input.
Render amount yuan input and convert to amount_cents through explicit emit/model handling.
Render return_url input.
Render expire_minutes input.
No API calls inside the component.
```

Use:

```vue
<script setup lang="ts">
```

and typed props/emits or typed `defineModel`. Do not use Options API.

- [x] **Step 6: Create detail dialog component**

`PaymentOrderDetailDialog.vue` responsibilities:

```text
Render order_no/config_code/provider/pay_method/subject/amount/status.
Render pay_url only inside detail dialog.
Render return_url/alipay_trade_no/expired_at/paid_at/closed_at/failure_reason.
No state mutation inside the component.
```

- [x] **Step 7: Create page composition**

`index.vue` must:

```text
Use Search.
Use AppTable.
Use AppDialog for create form.
Use AppDialog for detail.
Use dialogLayout computed with width/height/top.
Use useUserStore.can for payment_order_* buttons.
Keep root class payment-order-page.
```

The page must not wrap content in a new card outside existing body-card.

- [x] **Step 8: Run frontend page tests and typecheck**

Run:

```powershell
cd admin_front_ts
npx vitest run tests/shared/payment/payment-order-api.test.ts tests/shared/payment/payment-order-page.test.ts
npx vue-tsc -b --pretty false
```

Expected: pass.

---

## Task 7: Contract, Status, Smoke, Architecture Docs

**Files:**
- Modify: `docs/contracts/admin-api-v1.md`
- Modify: `docs/status/current-status.md`
- Modify: `docs/testing/smoke-matrix.md`
- Modify: `admin_back_go/docs/architecture.md`

- [x] **Step 1: Update API contract**

In `docs/contracts/admin-api-v1.md`, update the Payment section:

```text
payment config remains implemented.
payment order Alipay pay v1 is now implemented.
active payment tables: payment_configs, payment_orders.
active payment pages: /payment/config, /payment/orders.
active payment permissions: payment_config_*, payment_order_*.
```

Add endpoint list exactly as in Contract Lock.

Add field list for `payment_orders` and explicitly state:

```text
return_url is an order create parameter.
payment_configs still has no return_url.
paid can only be written by Alipay query/sync in this slice.
notify/refund/wallet/reconcile/WeChat are outside this slice.
```

- [x] **Step 2: Update current status**

In `docs/status/current-status.md`, update the payment row from config-only to:

```text
payment config remains implemented.
payment order Alipay pay v1 implemented: payment_orders table, /payment/orders page, create/pay/sync/close endpoints.
notify/refund/wallet/reconcile/WeChat remain out of scope.
```

- [x] **Step 3: Update smoke matrix**

In `docs/testing/smoke-matrix.md`, add:

```text
basic smoke: users/init includes /payment/config and /payment/orders.
full smoke read gate: payment orders page-init/list shape.
credential-gated manual smoke: sandbox config creates order, pay returns pay_url, sync checks status.
default smoke does not call real Alipay.
```

- [x] **Step 4: Update backend architecture doc**

In `admin_back_go/docs/architecture.md`, add the payment runtime fact:

```text
payment module owns both config and orders.
platform/payment/alipay owns SDK calls.
payment_orders is the only active payment order table.
payment events/notify/refund/wallet remain absent.
```

- [x] **Step 5: Run contract check**

Run:

```powershell
cd admin_back_go
powershell -ExecutionPolicy Bypass -File .\scripts\check-contract.ps1
```

Expected: pass.

---

## Task 8: Full Verification and Naming Residue Scan

**Files:**
- No planned source changes.
- If verification fails, fix the exact file reported by the failing test and rerun the same command.

- [x] **Step 1: Backend focused tests**

Run:

```powershell
cd admin_back_go
go test -p=1 ./internal/platform/payment ./internal/platform/payment/alipay ./internal/module/payment ./internal/bootstrap ./internal/server
```

Expected: pass.

- [x] **Step 2: Backend vet**

Run:

```powershell
cd admin_back_go
go vet ./internal/platform/payment ./internal/platform/payment/alipay ./internal/module/payment ./internal/bootstrap ./internal/server
```

Expected: no output and exit code 0.

- [x] **Step 3: Frontend focused tests**

Run:

```powershell
cd admin_front_ts
npx vitest run tests/shared/payment/payment-config-api.test.ts tests/shared/payment/payment-config-page.test.ts tests/shared/payment/payment-order-api.test.ts tests/shared/payment/payment-order-page.test.ts tests/shared/http-language-header.test.ts
```

Expected: pass.

- [x] **Step 4: Frontend typecheck**

Run:

```powershell
cd admin_front_ts
npx vue-tsc -b --pretty false
```

Expected: pass.

- [x] **Step 5: Naming residue scan**

Run from `E:\admin_go`:

```powershell
rg -n "/payment/order\\b|component=payment/order|payment_order_page|payment_order_create|payment_orders_" admin_back_go admin_front_ts docs/contracts docs/status docs/testing --glob "!docs/superpowers/**"
```

Expected: no output.

Run:

```powershell
rg -n "payment_orders|/payment/orders|payment/orders|payment_order_list|payment_order_add|payment_order_pay|payment_order_sync|payment_order_close|menu.payment_order" admin_back_go admin_front_ts docs
```

Expected: output includes migration, route meta, API contract, frontend API, frontend page, locale keys, and tests.

- [x] **Step 6: Field residue scan**

Run:

```powershell
rg -n "business_type|business_ref|refund_status|refund_amount|raw_request|raw_response|extra_json|buyer_id|created_by|updated_by" admin_back_go/internal/module/payment admin_front_ts/src/api/payment admin_front_ts/src/views/Main/payment docs/contracts/admin-api-v1.md
```

Expected: no output except contract text that explicitly says these fields are banned.

---

## Execution Notes

Do not commit automatically in this dirty multi-repo workspace. After each task, record:

```powershell
git -C E:\admin_go status --short
git -C E:\admin_go\admin_back_go status --short
git -C E:\admin_go\admin_front_ts status --short
```

Root docs changes belong to `E:\admin_go`. Backend code and migrations belong to `E:\admin_go\admin_back_go`. Frontend code and tests belong to `E:\admin_go\admin_front_ts`.

---

## Final Acceptance Checklist

```text
payment_orders has is_del / created_at / updated_at.
Every payment_orders field is read or written by code.
No wallet/refund/reconcile/WeChat/notify/event code is introduced.
return_url appears in order create/order table only, not payment_configs.
All canonical names match the Naming Lock.
Frontend page uses Search/AppTable/AppDialog.
AppDialog uses height and top.
No content creates a wrapper larger than body-card.
Backend handler -> service -> repository -> model boundary is intact.
OperationLog pay route skips pay_url response payload.
All verification commands pass.
```

