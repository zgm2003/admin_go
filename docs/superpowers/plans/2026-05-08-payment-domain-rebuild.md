# Payment Domain Rebuild Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the legacy PHP-shaped `pay/*` + `wallet/*` domain with a project-native `payment` bounded context that supports Alipay web/H5 payment end-to-end.

**Architecture:** Build a new Go module at `admin_back_go/internal/module/payment` and keep third-party SDK calls behind `internal/platform/payment/alipay`. The new domain owns payment channels, channel configs, payment orders, payment events, Alipay notify, and two compensation cron tasks; wallet/refund/reconcile/WeChat stay retired until a separate spec exists. Vue moves from `src/api/pay` and `views/Main/pay|wallet` to typed `src/api/payment` clients and thin route-level payment views.

**Tech Stack:** Go 1.26.1, Gin, GORM, MySQL, Redis-backed payment order number generation, go-pay/gopay, secretbox, existing REST/response/apperror/middleware/operation-log stack, Vue 3 Composition API with `<script setup lang="ts">`, Element Plus, Vitest.

---

## Master Rules

```text
1. Do not implement wallet, refund, reconcile, transfer, WeChat, or multi-merchant platform in this plan.
2. Do not import gopay outside internal/platform/payment/alipay.
3. Do not keep long-term compatibility with /api/admin/v1/recharge-orders, /api/admin/v1/pay-*, or /api/admin/v1/wallet*.
4. Do not drop orders/order_items in a migration until code references prove they are payment-only. This plan renames payment-owned tables first and leaves non-payment names guarded.
5. Do not put SDK/network IO inside a MySQL transaction.
6. Do not expose private_key_enc or plaintext private key through response, operation log, smoke output, or frontend types.
7. Do not register noop cron handlers to fake completion.
```

Linus check:

```text
True problem: yes, old pay/wallet modules couple payment, wallet, notify, reconcile, fulfillment, and PHP migration residue.
Simpler way: one payment module, four payment_* tables, Alipay only.
What breaks: old pay/wallet pages, routes, permissions, cron names, and test data; break them deliberately through migrations and contract updates.
```

---

## File Map

### Create

- `admin_back_go/database/migrations/20260508_payment_domain_rebuild.sql`
- `admin_back_go/internal/enum/payment.go`
- `admin_back_go/internal/enum/payment_test.go`
- `admin_back_go/internal/dict/payment_test.go`
- `admin_back_go/internal/platform/payment/gateway.go`
- `admin_back_go/internal/platform/payment/alipay/mapper.go`
- `admin_back_go/internal/platform/payment/alipay/mapper_test.go`
- `admin_back_go/internal/module/payment/model.go`
- `admin_back_go/internal/module/payment/dto.go`
- `admin_back_go/internal/module/payment/request.go`
- `admin_back_go/internal/module/payment/errors.go`
- `admin_back_go/internal/module/payment/repository.go`
- `admin_back_go/internal/module/payment/service.go`
- `admin_back_go/internal/module/payment/handler.go`
- `admin_back_go/internal/module/payment/route.go`
- `admin_back_go/internal/module/payment/jobs.go`
- `admin_back_go/internal/module/payment/number.go`
- `admin_back_go/internal/module/payment/number_test.go`
- `admin_back_go/internal/module/payment/service_test.go`
- `admin_back_go/internal/module/payment/repository_test.go`
- `admin_back_go/internal/module/payment/jobs_test.go`
- `admin_back_go/internal/module/payment/handler_test.go`
- `admin_front_ts/src/api/payment/channel.ts`
- `admin_front_ts/src/api/payment/order.ts`
- `admin_front_ts/src/api/payment/event.ts`
- `admin_front_ts/src/views/Main/payment/channel/index.vue`
- `admin_front_ts/src/views/Main/payment/channel/composables/usePaymentChannelPage.ts`
- `admin_front_ts/src/views/Main/payment/order/index.vue`
- `admin_front_ts/src/views/Main/payment/order/composables/usePaymentOrderPage.ts`
- `admin_front_ts/src/views/Main/payment/event/index.vue`
- `admin_front_ts/src/views/Main/payment/event/composables/usePaymentEventPage.ts`
- `admin_front_ts/tests/shared/payment/payment-channel-api.test.ts`
- `admin_front_ts/tests/shared/payment/payment-order-api.test.ts`
- `admin_front_ts/tests/shared/payment/payment-event-api.test.ts`
- `admin_front_ts/tests/shared/payment/payment-views.test.ts`

### Modify

- `admin_back_go/internal/dict/dict.go`
- `admin_back_go/internal/validate/pay.go`
- `admin_back_go/internal/validate/register.go`
- `admin_back_go/internal/server/router.go`
- `admin_back_go/internal/server/router_test.go`
- `admin_back_go/internal/bootstrap/app.go`
- `admin_back_go/internal/bootstrap/worker.go`
- `admin_back_go/internal/bootstrap/route_meta.go`
- `admin_back_go/internal/bootstrap/route_meta_test.go`
- `admin_back_go/internal/module/crontask/registry.go`
- `admin_back_go/internal/module/crontask/registry_test.go`
- `admin_back_go/scripts/full-admin-smoke.ps1`
- `admin_front_ts/src/enums/index.ts`
- `admin_front_ts/src/router/modules` or the project route source if dynamic route view keys are statically mapped there
- `docs/contracts/admin-api-v1.md`
- `docs/migration/current-status.md`
- `docs/testing/smoke-matrix.md`
- `admin_back_go/docs/architecture.md`

### Delete after replacement compiles

- `admin_back_go/internal/module/paychannel`
- `admin_back_go/internal/module/paynotifylog`
- `admin_back_go/internal/module/payorder`
- `admin_back_go/internal/module/payreconcile`
- `admin_back_go/internal/module/payruntime`
- `admin_back_go/internal/module/paytransaction`
- `admin_back_go/internal/module/wallet`
- `admin_front_ts/src/api/pay`
- `admin_front_ts/src/views/Main/pay`
- `admin_front_ts/src/views/Main/wallet`
- `admin_front_ts/src/views/Main/home/components/HomeWalletPanel.vue`
- `admin_front_ts/src/enums/PayEnum.ts`
- old payment tests under `admin_front_ts/tests/shared/pay*` and `admin_front_ts/tests/shared/pay-order`

---

## Task 1: Add Payment Enum, Dict, and Validation Foundation

**Files:**
- Create: `admin_back_go/internal/enum/payment.go`
- Create: `admin_back_go/internal/enum/payment_test.go`
- Modify: `admin_back_go/internal/dict/dict.go`
- Create: `admin_back_go/internal/dict/payment_test.go`
- Modify: `admin_back_go/internal/validate/pay.go`
- Modify: `admin_back_go/internal/validate/register.go`

- [ ] **Step 1: Write failing enum tests**

Create `admin_back_go/internal/enum/payment_test.go`:

```go
package enum

import "testing"

func TestPaymentEnums(t *testing.T) {
	if !IsPaymentProvider(PaymentProviderAlipay) || IsPaymentProvider("wechat") {
		t.Fatalf("unexpected provider validation")
	}
	if !IsPaymentMethod(PaymentMethodWeb) || !IsPaymentMethod(PaymentMethodH5) || IsPaymentMethod("scan") {
		t.Fatalf("unexpected method validation")
	}
	if !IsPaymentOrderStatus(PaymentOrderPending) || !IsPaymentOrderStatus(PaymentOrderSucceeded) || IsPaymentOrderStatus(99) {
		t.Fatalf("unexpected order status validation")
	}
	if !IsPaymentEventType(PaymentEventNotify) || !IsPaymentEventType(PaymentEventSync) || IsPaymentEventType("refund") {
		t.Fatalf("unexpected event type validation")
	}
	if !IsPaymentEventProcessStatus(PaymentEventIgnored) || IsPaymentEventProcessStatus(99) {
		t.Fatalf("unexpected event process status validation")
	}
}
```

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/enum -run TestPaymentEnums
```

Expected: fail because the new payment enum names do not exist.

- [ ] **Step 2: Implement enum**

Create `admin_back_go/internal/enum/payment.go`:

```go
package enum

const (
	PaymentProviderAlipay = "alipay"
)

var PaymentProviders = []string{PaymentProviderAlipay}
var PaymentProviderLabels = map[string]string{PaymentProviderAlipay: "支付宝"}

const (
	PaymentMethodWeb = "web"
	PaymentMethodH5  = "h5"
)

var PaymentMethods = []string{PaymentMethodWeb, PaymentMethodH5}
var PaymentMethodLabels = map[string]string{
	PaymentMethodWeb: "PC网页支付",
	PaymentMethodH5:  "H5支付",
}

const (
	PaymentOrderPending   = 1
	PaymentOrderPaying    = 2
	PaymentOrderSucceeded = 3
	PaymentOrderClosed    = 4
	PaymentOrderFailed    = 5
)

var PaymentOrderStatuses = []int{PaymentOrderPending, PaymentOrderPaying, PaymentOrderSucceeded, PaymentOrderClosed, PaymentOrderFailed}
var PaymentOrderStatusLabels = map[int]string{
	PaymentOrderPending:   "待支付",
	PaymentOrderPaying:    "支付中",
	PaymentOrderSucceeded: "支付成功",
	PaymentOrderClosed:    "已关闭",
	PaymentOrderFailed:    "支付失败",
}

const (
	PaymentEventCreate = "create"
	PaymentEventQuery  = "query"
	PaymentEventNotify = "notify"
	PaymentEventClose  = "close"
	PaymentEventSync   = "sync"
)

var PaymentEventTypes = []string{PaymentEventCreate, PaymentEventQuery, PaymentEventNotify, PaymentEventClose, PaymentEventSync}
var PaymentEventTypeLabels = map[string]string{
	PaymentEventCreate: "创建支付",
	PaymentEventQuery:  "查询支付",
	PaymentEventNotify: "支付回调",
	PaymentEventClose:  "关闭支付",
	PaymentEventSync:   "定时同步",
}

const (
	PaymentEventPending = 1
	PaymentEventSuccess = 2
	PaymentEventFailed  = 3
	PaymentEventIgnored = 4
)

var PaymentEventProcessStatuses = []int{PaymentEventPending, PaymentEventSuccess, PaymentEventFailed, PaymentEventIgnored}
var PaymentEventProcessStatusLabels = map[int]string{
	PaymentEventPending: "待处理",
	PaymentEventSuccess: "成功",
	PaymentEventFailed:  "失败",
	PaymentEventIgnored: "已忽略",
}

func IsPaymentProvider(value string) bool {
	for _, item := range PaymentProviders {
		if item == value {
			return true
		}
	}
	return false
}

func IsPaymentMethod(value string) bool {
	for _, item := range PaymentMethods {
		if item == value {
			return true
		}
	}
	return false
}

func IsPaymentOrderStatus(value int) bool {
	for _, item := range PaymentOrderStatuses {
		if item == value {
			return true
		}
	}
	return false
}

func IsPaymentEventType(value string) bool {
	for _, item := range PaymentEventTypes {
		if item == value {
			return true
		}
	}
	return false
}

func IsPaymentEventProcessStatus(value int) bool {
	for _, item := range PaymentEventProcessStatuses {
		if item == value {
			return true
		}
	}
	return false
}
```

- [ ] **Step 3: Write failing dict tests**

Create `admin_back_go/internal/dict/payment_test.go`:

```go
package dict

import (
	"testing"

	"admin_back_go/internal/enum"
)

func TestPaymentOptionsUseEnumOrder(t *testing.T) {
	providers := PaymentProviderOptions()
	if len(providers) != 1 || providers[0].Value != enum.PaymentProviderAlipay || providers[0].Label != "支付宝" {
		t.Fatalf("unexpected provider options: %#v", providers)
	}
	methods := PaymentMethodOptions()
	if len(methods) != 2 || methods[0].Value != enum.PaymentMethodWeb || methods[1].Value != enum.PaymentMethodH5 {
		t.Fatalf("unexpected method options: %#v", methods)
	}
	statuses := PaymentOrderStatusOptions()
	if len(statuses) != len(enum.PaymentOrderStatuses) || statuses[0].Value != enum.PaymentOrderPending {
		t.Fatalf("unexpected order status options: %#v", statuses)
	}
	eventTypes := PaymentEventTypeOptions()
	if len(eventTypes) != len(enum.PaymentEventTypes) || eventTypes[2].Value != enum.PaymentEventNotify {
		t.Fatalf("unexpected event type options: %#v", eventTypes)
	}
	processStatuses := PaymentEventProcessStatusOptions()
	if len(processStatuses) != len(enum.PaymentEventProcessStatuses) || processStatuses[3].Value != enum.PaymentEventIgnored {
		t.Fatalf("unexpected process status options: %#v", processStatuses)
	}
}
```

Run:

```powershell
go test ./internal/dict -run TestPaymentOptionsUseEnumOrder
```

Expected: fail because the dict functions do not exist.

- [ ] **Step 4: Implement dict options**

Append these functions to `admin_back_go/internal/dict/dict.go`:

```go
func PaymentProviderOptions() []Option[string] {
	options := make([]Option[string], 0, len(enum.PaymentProviders))
	for _, value := range enum.PaymentProviders {
		options = append(options, Option[string]{Label: enum.PaymentProviderLabels[value], Value: value})
	}
	return options
}

func PaymentMethodOptions() []Option[string] {
	options := make([]Option[string], 0, len(enum.PaymentMethods))
	for _, value := range enum.PaymentMethods {
		options = append(options, Option[string]{Label: enum.PaymentMethodLabels[value], Value: value})
	}
	return options
}

func PaymentOrderStatusOptions() []Option[int] {
	options := make([]Option[int], 0, len(enum.PaymentOrderStatuses))
	for _, value := range enum.PaymentOrderStatuses {
		options = append(options, Option[int]{Label: enum.PaymentOrderStatusLabels[value], Value: value})
	}
	return options
}

func PaymentEventTypeOptions() []Option[string] {
	options := make([]Option[string], 0, len(enum.PaymentEventTypes))
	for _, value := range enum.PaymentEventTypes {
		options = append(options, Option[string]{Label: enum.PaymentEventTypeLabels[value], Value: value})
	}
	return options
}

func PaymentEventProcessStatusOptions() []Option[int] {
	options := make([]Option[int], 0, len(enum.PaymentEventProcessStatuses))
	for _, value := range enum.PaymentEventProcessStatuses {
		options = append(options, Option[int]{Label: enum.PaymentEventProcessStatusLabels[value], Value: value})
	}
	return options
}
```

- [ ] **Step 5: Add validators and registration**

Append to `admin_back_go/internal/validate/pay.go`:

```go
func validatePaymentProvider(fl playground.FieldLevel) bool {
	return enum.IsPaymentProvider(trimmedString(fl.Field()))
}

func validatePaymentMethod(fl playground.FieldLevel) bool {
	return enum.IsPaymentMethod(trimmedString(fl.Field()))
}

func validatePaymentOrderStatus(fl playground.FieldLevel) bool {
	value, ok := intValue(fl.Field())
	return ok && enum.IsPaymentOrderStatus(value)
}

func validatePaymentEventType(fl playground.FieldLevel) bool {
	return enum.IsPaymentEventType(trimmedString(fl.Field()))
}

func validatePaymentEventProcessStatus(fl playground.FieldLevel) bool {
	value, ok := intValue(fl.Field())
	return ok && enum.IsPaymentEventProcessStatus(value)
}
```

Add to the `validators` map in `admin_back_go/internal/validate/register.go`:

```go
"payment_provider":             validatePaymentProvider,
"payment_method":               validatePaymentMethod,
"payment_order_status":         validatePaymentOrderStatus,
"payment_event_type":           validatePaymentEventType,
"payment_event_process_status": validatePaymentEventProcessStatus,
```

- [ ] **Step 6: Run foundation tests**

Run:

```powershell
go test ./internal/enum ./internal/dict ./internal/validate
```

Expected: pass.

- [ ] **Step 7: Commit**

```powershell
git add admin_back_go/internal/enum/payment.go admin_back_go/internal/enum/payment_test.go admin_back_go/internal/dict/dict.go admin_back_go/internal/dict/payment_test.go admin_back_go/internal/validate/pay.go admin_back_go/internal/validate/register.go
git commit -m "feat: add payment enum foundation"
```

---

## Task 2: Add Database Migration for New Payment Domain and Menu

**Files:**
- Create: `admin_back_go/database/migrations/20260508_payment_domain_rebuild.sql`

- [ ] **Step 1: Create migration**

Create `admin_back_go/database/migrations/20260508_payment_domain_rebuild.sql`:

```sql
-- Rebuild payment as a project-native bounded context.
-- Old pay/wallet data is intentionally preserved by renaming payment-owned
-- tables first. Do not drop orders/order_items here because their names are
-- not payment-specific and must be checked separately before deletion.

RENAME TABLE `pay_channel` TO `pay_channel_legacy_20260508`;
RENAME TABLE `pay_transactions` TO `pay_transactions_legacy_20260508`;
RENAME TABLE `pay_notify_logs` TO `pay_notify_logs_legacy_20260508`;
RENAME TABLE `user_wallets` TO `user_wallets_legacy_20260508`;
RENAME TABLE `wallet_transactions` TO `wallet_transactions_legacy_20260508`;
RENAME TABLE `order_fulfillments` TO `order_fulfillments_legacy_20260508`;
RENAME TABLE `pay_reconcile_tasks` TO `pay_reconcile_tasks_legacy_20260508`;
RENAME TABLE `pay_refunds` TO `pay_refunds_legacy_20260508`;

CREATE TABLE IF NOT EXISTS `payment_channels` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `code` VARCHAR(64) NOT NULL DEFAULT '' COMMENT 'channel code, e.g. alipay_sandbox',
  `name` VARCHAR(128) NOT NULL DEFAULT '',
  `provider` VARCHAR(32) NOT NULL DEFAULT 'alipay',
  `status` TINYINT NOT NULL DEFAULT 1 COMMENT '1 enabled, 2 disabled',
  `supported_methods` JSON NULL,
  `remark` VARCHAR(255) NOT NULL DEFAULT '',
  `is_del` TINYINT NOT NULL DEFAULT 2 COMMENT '1 deleted, 2 normal',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_payment_channels_code` (`code`),
  KEY `idx_payment_channels_provider_status` (`provider`, `status`, `is_del`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='payment channels';

CREATE TABLE IF NOT EXISTS `payment_channel_configs` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `channel_id` BIGINT NOT NULL,
  `app_id` VARCHAR(64) NOT NULL DEFAULT '',
  `merchant_id` VARCHAR(64) NOT NULL DEFAULT '',
  `sign_type` VARCHAR(16) NOT NULL DEFAULT 'RSA2',
  `is_sandbox` TINYINT NOT NULL DEFAULT 1,
  `notify_url` VARCHAR(512) NOT NULL DEFAULT '',
  `return_url` VARCHAR(512) NOT NULL DEFAULT '',
  `private_key_enc` TEXT NULL,
  `private_key_hint` VARCHAR(64) NOT NULL DEFAULT '',
  `app_cert_path` VARCHAR(512) NOT NULL DEFAULT '',
  `alipay_cert_path` VARCHAR(512) NOT NULL DEFAULT '',
  `alipay_root_cert_path` VARCHAR(512) NOT NULL DEFAULT '',
  `extra_config` JSON NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_payment_channel_configs_channel_id` (`channel_id`),
  KEY `idx_payment_channel_configs_app_id` (`app_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='payment channel configs';

CREATE TABLE IF NOT EXISTS `payment_orders` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `order_no` VARCHAR(64) NOT NULL DEFAULT '',
  `user_id` BIGINT NOT NULL DEFAULT 0,
  `channel_id` BIGINT NOT NULL DEFAULT 0,
  `provider` VARCHAR(32) NOT NULL DEFAULT 'alipay',
  `pay_method` VARCHAR(16) NOT NULL DEFAULT '',
  `subject` VARCHAR(128) NOT NULL DEFAULT '',
  `amount_cents` BIGINT NOT NULL DEFAULT 0,
  `currency` VARCHAR(8) NOT NULL DEFAULT 'CNY',
  `status` TINYINT NOT NULL DEFAULT 1,
  `out_trade_no` VARCHAR(64) NOT NULL DEFAULT '',
  `trade_no` VARCHAR(128) NOT NULL DEFAULT '',
  `pay_url` TEXT NULL,
  `paid_at` DATETIME NULL,
  `expired_at` DATETIME NOT NULL,
  `closed_at` DATETIME NULL,
  `client_ip` VARCHAR(64) NOT NULL DEFAULT '',
  `return_url` VARCHAR(512) NOT NULL DEFAULT '',
  `business_type` VARCHAR(64) NOT NULL DEFAULT 'manual_test',
  `business_ref` VARCHAR(128) NOT NULL DEFAULT '',
  `is_del` TINYINT NOT NULL DEFAULT 2,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_payment_orders_order_no` (`order_no`),
  UNIQUE KEY `uk_payment_orders_out_trade_no` (`out_trade_no`),
  KEY `idx_payment_orders_user_status` (`user_id`, `status`, `is_del`),
  KEY `idx_payment_orders_channel_status` (`channel_id`, `status`, `is_del`),
  KEY `idx_payment_orders_expired_at` (`expired_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='payment orders';

CREATE TABLE IF NOT EXISTS `payment_events` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `order_no` VARCHAR(64) NOT NULL DEFAULT '',
  `out_trade_no` VARCHAR(64) NOT NULL DEFAULT '',
  `event_type` VARCHAR(32) NOT NULL DEFAULT '',
  `provider` VARCHAR(32) NOT NULL DEFAULT 'alipay',
  `request_data` JSON NULL,
  `response_data` JSON NULL,
  `process_status` TINYINT NOT NULL DEFAULT 1,
  `error_message` VARCHAR(1024) NOT NULL DEFAULT '',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_payment_events_order_no` (`order_no`),
  KEY `idx_payment_events_out_trade_no` (`out_trade_no`),
  KEY `idx_payment_events_type_status` (`event_type`, `process_status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='payment events';

INSERT INTO `payment_channels` (`code`, `name`, `provider`, `status`, `supported_methods`, `remark`, `is_del`)
SELECT
  'alipay_sandbox',
  `name`,
  'alipay',
  `status`,
  JSON_ARRAY('web', 'h5'),
  `remark`,
  2
FROM `pay_channel_legacy_20260508`
WHERE `channel` = 2 AND `is_del` = 2
ORDER BY `id` ASC
LIMIT 1;

INSERT INTO `payment_channel_configs` (
  `channel_id`, `app_id`, `merchant_id`, `sign_type`, `is_sandbox`,
  `notify_url`, `return_url`, `private_key_enc`, `private_key_hint`,
  `app_cert_path`, `alipay_cert_path`, `alipay_root_cert_path`, `extra_config`
)
SELECT
  pc.`id`,
  legacy.`app_id`,
  legacy.`mch_id`,
  'RSA2',
  legacy.`is_sandbox`,
  legacy.`notify_url`,
  '',
  legacy.`app_private_key_enc`,
  legacy.`app_private_key_hint`,
  legacy.`public_cert_path`,
  legacy.`platform_cert_path`,
  legacy.`root_cert_path`,
  legacy.`extra_config`
FROM `payment_channels` AS pc
JOIN `pay_channel_legacy_20260508` AS legacy ON legacy.`channel` = 2 AND legacy.`is_del` = 2
WHERE pc.`code` = 'alipay_sandbox'
ORDER BY legacy.`id` ASC
LIMIT 1;

UPDATE `permissions`
SET `is_del` = 1, `updated_at` = NOW()
WHERE `platform` = 'admin'
  AND (
    `path` = '/wallet'
    OR `path` LIKE '/wallet/%'
    OR `path` = '/pay'
    OR `path` LIKE '/pay/%'
    OR `code` LIKE 'pay\_%'
  );

INSERT INTO `permissions` (`name`, `path`, `icon`, `parent_id`, `component`, `platform`, `type`, `sort`, `code`, `i18n_key`, `show_menu`, `status`, `is_del`, `created_at`, `updated_at`)
SELECT '支付管理', '/payment', 'Wallet', 0, '', 'admin', 1, 9600, 'payment', 'menu.payment', 1, 1, 2, NOW(), NOW()
WHERE NOT EXISTS (SELECT 1 FROM `permissions` WHERE `platform` = 'admin' AND `code` = 'payment' AND `is_del` = 2);

SET @payment_parent_id := (SELECT `id` FROM `permissions` WHERE `platform` = 'admin' AND `code` = 'payment' AND `is_del` = 2 LIMIT 1);

INSERT INTO `permissions` (`name`, `path`, `icon`, `parent_id`, `component`, `platform`, `type`, `sort`, `code`, `i18n_key`, `show_menu`, `status`, `is_del`, `created_at`, `updated_at`)
SELECT '支付渠道', '/payment/channel', '', @payment_parent_id, 'payment/channel/index', 'admin', 2, 9610, 'payment_channel_list', 'menu.payment.channel', 1, 1, 2, NOW(), NOW()
WHERE NOT EXISTS (SELECT 1 FROM `permissions` WHERE `platform` = 'admin' AND `code` = 'payment_channel_list' AND `is_del` = 2);

INSERT INTO `permissions` (`name`, `path`, `icon`, `parent_id`, `component`, `platform`, `type`, `sort`, `code`, `i18n_key`, `show_menu`, `status`, `is_del`, `created_at`, `updated_at`)
SELECT '支付订单', '/payment/order', '', @payment_parent_id, 'payment/order/index', 'admin', 2, 9620, 'payment_order_list', 'menu.payment.order', 1, 1, 2, NOW(), NOW()
WHERE NOT EXISTS (SELECT 1 FROM `permissions` WHERE `platform` = 'admin' AND `code` = 'payment_order_list' AND `is_del` = 2);

INSERT INTO `permissions` (`name`, `path`, `icon`, `parent_id`, `component`, `platform`, `type`, `sort`, `code`, `i18n_key`, `show_menu`, `status`, `is_del`, `created_at`, `updated_at`)
SELECT '支付事件', '/payment/event', '', @payment_parent_id, 'payment/event/index', 'admin', 2, 9630, 'payment_event_list', 'menu.payment.event', 1, 1, 2, NOW(), NOW()
WHERE NOT EXISTS (SELECT 1 FROM `permissions` WHERE `platform` = 'admin' AND `code` = 'payment_event_list' AND `is_del` = 2);

INSERT INTO `permissions` (`name`, `path`, `icon`, `parent_id`, `component`, `platform`, `type`, `sort`, `code`, `i18n_key`, `show_menu`, `status`, `is_del`, `created_at`, `updated_at`)
SELECT '新增支付渠道', '', '', p.`id`, '', 'admin', 3, 9611, 'payment_channel_add', 'button.payment.channel.add', 2, 1, 2, NOW(), NOW()
FROM `permissions` AS p
WHERE p.`platform` = 'admin' AND p.`code` = 'payment_channel_list' AND p.`is_del` = 2
  AND NOT EXISTS (SELECT 1 FROM `permissions` WHERE `platform` = 'admin' AND `code` = 'payment_channel_add' AND `is_del` = 2);

INSERT INTO `permissions` (`name`, `path`, `icon`, `parent_id`, `component`, `platform`, `type`, `sort`, `code`, `i18n_key`, `show_menu`, `status`, `is_del`, `created_at`, `updated_at`)
SELECT '编辑支付渠道', '', '', p.`id`, '', 'admin', 3, 9612, 'payment_channel_edit', 'button.payment.channel.edit', 2, 1, 2, NOW(), NOW()
FROM `permissions` AS p
WHERE p.`platform` = 'admin' AND p.`code` = 'payment_channel_list' AND p.`is_del` = 2
  AND NOT EXISTS (SELECT 1 FROM `permissions` WHERE `platform` = 'admin' AND `code` = 'payment_channel_edit' AND `is_del` = 2);

INSERT INTO `permissions` (`name`, `path`, `icon`, `parent_id`, `component`, `platform`, `type`, `sort`, `code`, `i18n_key`, `show_menu`, `status`, `is_del`, `created_at`, `updated_at`)
SELECT '切换支付渠道状态', '', '', p.`id`, '', 'admin', 3, 9613, 'payment_channel_status', 'button.payment.channel.status', 2, 1, 2, NOW(), NOW()
FROM `permissions` AS p
WHERE p.`platform` = 'admin' AND p.`code` = 'payment_channel_list' AND p.`is_del` = 2
  AND NOT EXISTS (SELECT 1 FROM `permissions` WHERE `platform` = 'admin' AND `code` = 'payment_channel_status' AND `is_del` = 2);

INSERT INTO `permissions` (`name`, `path`, `icon`, `parent_id`, `component`, `platform`, `type`, `sort`, `code`, `i18n_key`, `show_menu`, `status`, `is_del`, `created_at`, `updated_at`)
SELECT '删除支付渠道', '', '', p.`id`, '', 'admin', 3, 9614, 'payment_channel_del', 'button.payment.channel.del', 2, 1, 2, NOW(), NOW()
FROM `permissions` AS p
WHERE p.`platform` = 'admin' AND p.`code` = 'payment_channel_list' AND p.`is_del` = 2
  AND NOT EXISTS (SELECT 1 FROM `permissions` WHERE `platform` = 'admin' AND `code` = 'payment_channel_del' AND `is_del` = 2);

INSERT INTO `permissions` (`name`, `path`, `icon`, `parent_id`, `component`, `platform`, `type`, `sort`, `code`, `i18n_key`, `show_menu`, `status`, `is_del`, `created_at`, `updated_at`)
SELECT '关闭支付订单', '', '', p.`id`, '', 'admin', 3, 9621, 'payment_order_close', 'button.payment.order.close', 2, 1, 2, NOW(), NOW()
FROM `permissions` AS p
WHERE p.`platform` = 'admin' AND p.`code` = 'payment_order_list' AND p.`is_del` = 2
  AND NOT EXISTS (SELECT 1 FROM `permissions` WHERE `platform` = 'admin' AND `code` = 'payment_order_close' AND `is_del` = 2);

UPDATE `cron_task`
SET `is_del` = 1, `updated_at` = NOW()
WHERE `name` IN ('pay_reconcile_daily', 'pay_reconcile_execute', 'pay_fulfillment_retry', 'pay_refund_sync', 'pay_close_expired_order', 'pay_sync_pending_transaction');

INSERT INTO `cron_task` (`name`, `title`, `cron`, `handler`, `status`, `remark`, `is_del`, `created_at`, `updated_at`)
SELECT 'payment_close_expired_order', '关闭过期支付订单', '0 * * * * *', 'payment:close-expired-order:v1', 1, 'Go payment domain task', 2, NOW(), NOW()
WHERE NOT EXISTS (SELECT 1 FROM `cron_task` WHERE `name` = 'payment_close_expired_order' AND `is_del` = 2);

INSERT INTO `cron_task` (`name`, `title`, `cron`, `handler`, `status`, `remark`, `is_del`, `created_at`, `updated_at`)
SELECT 'payment_sync_pending_order', '同步待支付订单', '0 */5 * * * *', 'payment:sync-pending-order:v1', 1, 'Go payment domain task', 2, NOW(), NOW()
WHERE NOT EXISTS (SELECT 1 FROM `cron_task` WHERE `name` = 'payment_sync_pending_order' AND `is_del` = 2);
```

- [ ] **Step 2: Inspect migration references**

Run:

```powershell
cd E:\admin_go
Select-String -Path .\admin_back_go\database\migrations\20260508_payment_domain_rebuild.sql -Pattern 'DROP TABLE|orders|order_items|payment_channels|payment_orders|payment_events'
```

Expected:

```text
No DROP TABLE lines.
orders/order_items appear only in explanatory comments.
payment_* tables appear in CREATE TABLE statements.
```

- [ ] **Step 3: Commit**

```powershell
git add admin_back_go/database/migrations/20260508_payment_domain_rebuild.sql
git commit -m "feat: add payment domain rebuild migration"
```

---

## Task 3: Add Platform Gateway Interface and Alipay Mapper

**Files:**
- Create: `admin_back_go/internal/platform/payment/gateway.go`
- Create: `admin_back_go/internal/platform/payment/alipay/mapper.go`
- Create: `admin_back_go/internal/platform/payment/alipay/mapper_test.go`
- Modify: `admin_back_go/internal/platform/payment/alipay/types.go`
- Modify: `admin_back_go/internal/platform/payment/alipay/gateway.go`

- [ ] **Step 1: Write failing mapper tests**

Create `admin_back_go/internal/platform/payment/alipay/mapper_test.go`:

```go
package alipay

import (
	"testing"

	paymentcore "admin_back_go/internal/platform/payment"
)

func TestMapChannelConfig(t *testing.T) {
	cfg := MapChannelConfig(paymentcore.ChannelConfig{
		ChannelID:      9,
		AppID:          "app",
		PrivateKey:     "private",
		AppCertPath:    "app.crt",
		AlipayCertPath: "alipay.crt",
		RootCertPath:   "root.crt",
		NotifyURL:      "https://notify",
		IsSandbox:      true,
	})
	if cfg.ChannelID != 9 || cfg.AppID != "app" || cfg.PrivateKey != "private" || !cfg.IsSandbox {
		t.Fatalf("unexpected mapped config: %#v", cfg)
	}
}

func TestGatewayResultMapping(t *testing.T) {
	result := MapQueryResult(&QueryResult{OutTradeNo: "out", TradeNo: "trade", TradeStatus: "TRADE_SUCCESS", TotalAmountCents: 1234, AppID: "app"})
	if result.OutTradeNo != "out" || result.AmountCents != 1234 || result.PaidStatus() != true {
		t.Fatalf("unexpected mapped query result: %#v", result)
	}
}
```

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/platform/payment/alipay -run 'TestMapChannelConfig|TestGatewayResultMapping'
```

Expected: fail because mapper functions and platform types do not exist.

- [ ] **Step 2: Add platform payment interface**

Create `admin_back_go/internal/platform/payment/gateway.go`:

```go
package payment

import "context"

type ChannelConfig struct {
	ChannelID      int64
	AppID          string
	PrivateKey     string
	AppCertPath    string
	AlipayCertPath string
	RootCertPath   string
	NotifyURL      string
	IsSandbox      bool
}

type CreatePayRequest struct {
	OutTradeNo  string
	Subject     string
	AmountCents int64
	PayMethod   string
	ReturnURL   string
}

type CreatePayResult struct {
	Mode    string
	Content string
	Raw     map[string]any
}

type QueryResult struct {
	OutTradeNo  string
	TradeNo     string
	TradeStatus string
	AmountCents int64
	AppID       string
	Raw         map[string]any
}

func (r QueryResult) PaidStatus() bool {
	return r.TradeStatus == "TRADE_SUCCESS" || r.TradeStatus == "TRADE_FINISHED"
}

type NotifyResult struct {
	OutTradeNo  string
	TradeNo     string
	TradeStatus string
	AmountCents int64
	AppID       string
	Raw         map[string]any
}

func (r NotifyResult) PaidStatus() bool {
	return r.TradeStatus == "TRADE_SUCCESS" || r.TradeStatus == "TRADE_FINISHED"
}

type Gateway interface {
	CreatePagePay(ctx context.Context, cfg ChannelConfig, req CreatePayRequest) (*CreatePayResult, error)
	Query(ctx context.Context, cfg ChannelConfig, outTradeNo string) (*QueryResult, error)
	VerifyNotify(ctx context.Context, cfg ChannelConfig, form map[string]string) (*NotifyResult, error)
	Close(ctx context.Context, cfg ChannelConfig, outTradeNo string) error
	SuccessBody() string
	FailureBody() string
}
```

- [ ] **Step 3: Add Alipay mapper**

Create `admin_back_go/internal/platform/payment/alipay/mapper.go`:

```go
package alipay

import paymentcore "admin_back_go/internal/platform/payment"

func MapChannelConfig(cfg paymentcore.ChannelConfig) ChannelConfig {
	return ChannelConfig{
		ChannelID:      cfg.ChannelID,
		AppID:          cfg.AppID,
		PrivateKey:     cfg.PrivateKey,
		AppCertPath:    cfg.AppCertPath,
		AlipayCertPath: cfg.AlipayCertPath,
		RootCertPath:   cfg.RootCertPath,
		NotifyURL:      cfg.NotifyURL,
		IsSandbox:      cfg.IsSandbox,
	}
}

func MapCreateRequest(req paymentcore.CreatePayRequest) CreateRequest {
	return CreateRequest{
		OutTradeNo:  req.OutTradeNo,
		Subject:     req.Subject,
		AmountCents: int(req.AmountCents),
		PayMethod:   req.PayMethod,
		ReturnURL:   req.ReturnURL,
	}
}

func MapCreateResult(result *CreateResponse) *paymentcore.CreatePayResult {
	if result == nil {
		return nil
	}
	return &paymentcore.CreatePayResult{Mode: result.Mode, Content: result.Content, Raw: result.Raw}
}

func MapQueryResult(result *QueryResult) *paymentcore.QueryResult {
	if result == nil {
		return nil
	}
	return &paymentcore.QueryResult{
		OutTradeNo:  result.OutTradeNo,
		TradeNo:     result.TradeNo,
		TradeStatus: result.TradeStatus,
		AmountCents: int64(result.TotalAmountCents),
		AppID:       result.AppID,
		Raw:         result.Raw,
	}
}

func MapNotifyResult(result *NotifyResult) *paymentcore.NotifyResult {
	if result == nil {
		return nil
	}
	return &paymentcore.NotifyResult{
		OutTradeNo:  result.OutTradeNo,
		TradeNo:     result.TradeNo,
		TradeStatus: result.TradeStatus,
		AmountCents: int64(result.TotalAmountCents),
		AppID:       result.AppID,
		Raw:         result.Raw,
	}
}
```

- [ ] **Step 4: Add a platform adapter for GopayGateway**

Do not rename the existing SDK-level `Create`, `Query`, `Close`, or `VerifyNotify` methods because old code still compiles until Task 8 deletes it. Instead append this adapter to `admin_back_go/internal/platform/payment/alipay/mapper.go`:

```go
type PlatformGateway struct {
	inner *GopayGateway
}

func NewPlatformGateway(inner *GopayGateway) *PlatformGateway {
	return &PlatformGateway{inner: inner}
}

func (g *PlatformGateway) CreatePagePay(ctx context.Context, cfg paymentcore.ChannelConfig, req paymentcore.CreatePayRequest) (*paymentcore.CreatePayResult, error) {
	if g == nil || g.inner == nil {
		return nil, ErrGatewayNotConfigured
	}
	result, err := g.inner.Create(ctx, MapChannelConfig(cfg), MapCreateRequest(req))
	if err != nil {
		return nil, err
	}
	return MapCreateResult(result), nil
}

func (g *PlatformGateway) Query(ctx context.Context, cfg paymentcore.ChannelConfig, outTradeNo string) (*paymentcore.QueryResult, error) {
	if g == nil || g.inner == nil {
		return nil, ErrGatewayNotConfigured
	}
	result, err := g.inner.Query(ctx, MapChannelConfig(cfg), QueryRequest{OutTradeNo: outTradeNo})
	if err != nil {
		return nil, err
	}
	return MapQueryResult(result), nil
}

func (g *PlatformGateway) VerifyNotify(ctx context.Context, cfg paymentcore.ChannelConfig, form map[string]string) (*paymentcore.NotifyResult, error) {
	if g == nil || g.inner == nil {
		return nil, ErrGatewayNotConfigured
	}
	result, err := g.inner.VerifyNotify(ctx, MapChannelConfig(cfg), NotifyRequest{Form: form})
	if err != nil {
		return nil, err
	}
	return MapNotifyResult(result), nil
}

func (g *PlatformGateway) Close(ctx context.Context, cfg paymentcore.ChannelConfig, outTradeNo string) error {
	if g == nil || g.inner == nil {
		return ErrGatewayNotConfigured
	}
	return g.inner.Close(ctx, MapChannelConfig(cfg), CloseRequest{OutTradeNo: outTradeNo})
}

func (g *PlatformGateway) SuccessBody() string {
	if g == nil || g.inner == nil {
		return "success"
	}
	return g.inner.SuccessBody()
}

func (g *PlatformGateway) FailureBody() string {
	if g == nil || g.inner == nil {
		return "fail"
	}
	return g.inner.FailureBody()
}
```

Also update the import block in `mapper.go`:

```go
import (
	"context"
	"errors"

	paymentcore "admin_back_go/internal/platform/payment"
)
```

Add this compile assertion at the bottom of `mapper.go`:

```go
var ErrGatewayNotConfigured = errors.New("alipay: gateway not configured")
var _ paymentcore.Gateway = (*PlatformGateway)(nil)
```

- [ ] **Step 5: Run platform tests**

```powershell
go test ./internal/platform/payment ./internal/platform/payment/alipay
```

Expected: pass.

- [ ] **Step 6: Commit**

```powershell
git add admin_back_go/internal/platform/payment/gateway.go admin_back_go/internal/platform/payment/alipay/mapper.go admin_back_go/internal/platform/payment/alipay/mapper_test.go admin_back_go/internal/platform/payment/alipay/gateway.go
git commit -m "feat: add payment gateway boundary"
```

---

## Task 4: Add Payment Module Models, DTOs, Requests, and Repository

**Files:**
- Create: `admin_back_go/internal/module/payment/model.go`
- Create: `admin_back_go/internal/module/payment/dto.go`
- Create: `admin_back_go/internal/module/payment/request.go`
- Create: `admin_back_go/internal/module/payment/errors.go`
- Create: `admin_back_go/internal/module/payment/repository.go`
- Create: `admin_back_go/internal/module/payment/repository_test.go`

- [ ] **Step 1: Write repository tests**

Create `admin_back_go/internal/module/payment/repository_test.go`:

```go
package payment

import "testing"

func TestPaymentModelsUseNewTables(t *testing.T) {
	if (Channel{}).TableName() != "payment_channels" {
		t.Fatalf("unexpected channel table")
	}
	if (ChannelConfig{}).TableName() != "payment_channel_configs" {
		t.Fatalf("unexpected config table")
	}
	if (Order{}).TableName() != "payment_orders" {
		t.Fatalf("unexpected order table")
	}
	if (Event{}).TableName() != "payment_events" {
		t.Fatalf("unexpected event table")
	}
}
```

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/payment -run TestPaymentModelsUseNewTables
```

Expected: fail because module does not exist.

- [ ] **Step 2: Add models**

Create `admin_back_go/internal/module/payment/model.go`:

```go
package payment

import "time"

type Channel struct {
	ID               int64     `gorm:"column:id;primaryKey"`
	Code             string    `gorm:"column:code"`
	Name             string    `gorm:"column:name"`
	Provider         string    `gorm:"column:provider"`
	Status           int       `gorm:"column:status"`
	SupportedMethods string    `gorm:"column:supported_methods"`
	Remark           string    `gorm:"column:remark"`
	IsDel            int       `gorm:"column:is_del"`
	CreatedAt        time.Time `gorm:"column:created_at"`
	UpdatedAt        time.Time `gorm:"column:updated_at"`
}

func (Channel) TableName() string { return "payment_channels" }

type ChannelConfig struct {
	ID                 int64     `gorm:"column:id;primaryKey"`
	ChannelID          int64     `gorm:"column:channel_id"`
	AppID              string    `gorm:"column:app_id"`
	MerchantID         string    `gorm:"column:merchant_id"`
	SignType           string    `gorm:"column:sign_type"`
	IsSandbox          int       `gorm:"column:is_sandbox"`
	NotifyURL          string    `gorm:"column:notify_url"`
	ReturnURL          string    `gorm:"column:return_url"`
	PrivateKeyEnc      string    `gorm:"column:private_key_enc"`
	PrivateKeyHint     string    `gorm:"column:private_key_hint"`
	AppCertPath        string    `gorm:"column:app_cert_path"`
	AlipayCertPath     string    `gorm:"column:alipay_cert_path"`
	AlipayRootCertPath string    `gorm:"column:alipay_root_cert_path"`
	ExtraConfig        string    `gorm:"column:extra_config"`
	CreatedAt          time.Time `gorm:"column:created_at"`
	UpdatedAt          time.Time `gorm:"column:updated_at"`
}

func (ChannelConfig) TableName() string { return "payment_channel_configs" }

type Order struct {
	ID           int64      `gorm:"column:id;primaryKey"`
	OrderNo      string     `gorm:"column:order_no"`
	UserID       int64      `gorm:"column:user_id"`
	ChannelID    int64      `gorm:"column:channel_id"`
	Provider     string     `gorm:"column:provider"`
	PayMethod    string     `gorm:"column:pay_method"`
	Subject      string     `gorm:"column:subject"`
	AmountCents  int64      `gorm:"column:amount_cents"`
	Currency     string     `gorm:"column:currency"`
	Status       int        `gorm:"column:status"`
	OutTradeNo   string     `gorm:"column:out_trade_no"`
	TradeNo      string     `gorm:"column:trade_no"`
	PayURL       string     `gorm:"column:pay_url"`
	PaidAt       *time.Time `gorm:"column:paid_at"`
	ExpiredAt    time.Time  `gorm:"column:expired_at"`
	ClosedAt     *time.Time `gorm:"column:closed_at"`
	ClientIP     string     `gorm:"column:client_ip"`
	ReturnURL    string     `gorm:"column:return_url"`
	BusinessType string     `gorm:"column:business_type"`
	BusinessRef  string     `gorm:"column:business_ref"`
	IsDel        int        `gorm:"column:is_del"`
	CreatedAt    time.Time  `gorm:"column:created_at"`
	UpdatedAt    time.Time  `gorm:"column:updated_at"`
}

func (Order) TableName() string { return "payment_orders" }

type Event struct {
	ID            int64     `gorm:"column:id;primaryKey"`
	OrderNo       string    `gorm:"column:order_no"`
	OutTradeNo    string    `gorm:"column:out_trade_no"`
	EventType     string    `gorm:"column:event_type"`
	Provider      string    `gorm:"column:provider"`
	RequestData   string    `gorm:"column:request_data"`
	ResponseData  string    `gorm:"column:response_data"`
	ProcessStatus int       `gorm:"column:process_status"`
	ErrorMessage  string    `gorm:"column:error_message"`
	CreatedAt     time.Time `gorm:"column:created_at"`
}

func (Event) TableName() string { return "payment_events" }
```

- [ ] **Step 3: Add DTOs and requests**

Create `admin_back_go/internal/module/payment/dto.go` with the public service contract:

```go
package payment

import (
	"context"
	"time"

	"admin_back_go/internal/apperror"
	"admin_back_go/internal/dict"
)

type Page struct {
	PageSize    int   `json:"page_size"`
	CurrentPage int   `json:"current_page"`
	TotalPage   int   `json:"total_page"`
	Total       int64 `json:"total"`
}

type ChannelInitResponse struct {
	Dict ChannelInitDict `json:"dict"`
}

type ChannelInitDict struct {
	ProviderArr     []dict.Option[string] `json:"provider_arr"`
	CommonStatusArr []dict.Option[int]    `json:"common_status_arr"`
	PayMethodArr    []dict.Option[string] `json:"pay_method_arr"`
	YesNoArr         []dict.Option[int]    `json:"yes_no_arr"`
}

type ChannelListQuery struct {
	CurrentPage int
	PageSize    int
	Name        string
	Provider    string
	Status      int
}

type ChannelListResponse struct {
	List []ChannelListItem `json:"list"`
	Page Page              `json:"page"`
}

type ChannelListItem struct {
	ID                int64    `json:"id"`
	Code              string   `json:"code"`
	Name              string   `json:"name"`
	Provider          string   `json:"provider"`
	ProviderText      string   `json:"provider_text"`
	SupportedMethods  []string `json:"supported_methods"`
	SupportedText     string   `json:"supported_methods_text"`
	AppID             string   `json:"app_id"`
	MerchantID        string   `json:"merchant_id"`
	NotifyURL         string   `json:"notify_url"`
	ReturnURL         string   `json:"return_url"`
	PrivateKeyHint    string   `json:"private_key_hint"`
	AppCertPath       string   `json:"app_cert_path"`
	AlipayCertPath    string   `json:"alipay_cert_path"`
	AlipayRootCertPath string   `json:"alipay_root_cert_path"`
	IsSandbox          int      `json:"is_sandbox"`
	Status             int      `json:"status"`
	StatusText        string   `json:"status_text"`
	Remark            string   `json:"remark"`
	CreatedAt         string   `json:"created_at"`
	UpdatedAt         string   `json:"updated_at"`
}

type ChannelMutationInput struct {
	Code              string
	Name              string
	Provider          string
	SupportedMethods  []string
	AppID             string
	MerchantID        string
	NotifyURL         string
	ReturnURL         string
	PrivateKey        string
	AppCertPath       string
	AlipayCertPath    string
	AlipayRootCertPath string
	IsSandbox          int
	Status             int
	Remark             string
}

type OrderListQuery struct {
	CurrentPage int
	PageSize    int
	OrderNo     string
	UserID      int64
	Status      int
	StartDate   string
	EndDate     string
}

type OrderListResponse struct {
	List []OrderListItem `json:"list"`
	Page Page            `json:"page"`
}

type OrderListItem struct {
	ID          int64  `json:"id"`
	OrderNo     string `json:"order_no"`
	UserID      int64  `json:"user_id"`
	ChannelID   int64  `json:"channel_id"`
	Provider    string `json:"provider"`
	PayMethod   string `json:"pay_method"`
	Subject     string `json:"subject"`
	AmountCents int64  `json:"amount_cents"`
	Status      int    `json:"status"`
	StatusText  string `json:"status_text"`
	OutTradeNo  string `json:"out_trade_no"`
	TradeNo     string `json:"trade_no"`
	PaidAt      string `json:"paid_at"`
	ExpiredAt   string `json:"expired_at"`
	ClosedAt    string `json:"closed_at"`
	CreatedAt   string `json:"created_at"`
}

type CreateOrderInput struct {
	UserID       int64
	ChannelID    int64
	PayMethod    string
	Subject      string
	AmountCents  int64
	ReturnURL    string
	BusinessType string
	BusinessRef  string
	ClientIP     string
}

type NumberGenerator interface {
	Next(ctx context.Context, prefix string) (string, error)
}

type CreateOrderResponse struct {
	OrderNo     string `json:"order_no"`
	AmountCents int64  `json:"amount_cents"`
	ExpiredAt   string `json:"expired_at"`
}

type PayOrderResponse struct {
	OrderNo    string         `json:"order_no"`
	OutTradeNo string         `json:"out_trade_no"`
	PayMethod  string         `json:"pay_method"`
	PayURL     string         `json:"pay_url"`
	PayData    map[string]any `json:"pay_data"`
}

type ResultResponse struct {
	OrderNo    string `json:"order_no"`
	Status     int    `json:"status"`
	StatusText string `json:"status_text"`
	TradeNo    string `json:"trade_no"`
	PaidAt     string `json:"paid_at"`
}

type EventListQuery struct {
	CurrentPage   int
	PageSize      int
	OrderNo       string
	OutTradeNo    string
	EventType     string
	ProcessStatus int
}

type EventListResponse struct {
	List []EventListItem `json:"list"`
	Page Page            `json:"page"`
}

type EventListItem struct {
	ID            int64  `json:"id"`
	OrderNo       string `json:"order_no"`
	OutTradeNo    string `json:"out_trade_no"`
	EventType     string `json:"event_type"`
	EventTypeText string `json:"event_type_text"`
	Provider      string `json:"provider"`
	ProcessStatus int    `json:"process_status"`
	ProcessText   string `json:"process_status_text"`
	ErrorMessage  string `json:"error_message"`
	CreatedAt     string `json:"created_at"`
}

type OrderDetailResponse struct {
	Order OrderListItem `json:"order"`
}

type EventDetailResponse struct {
	Event        EventListItem          `json:"event"`
	RequestData  map[string]any         `json:"request_data"`
	ResponseData map[string]any         `json:"response_data"`
}

type NotifyInput struct {
	Form map[string]string
	IP   string
}

type CloseExpiredInput struct {
	Limit int
	Now   time.Time
}

type SyncPendingInput struct {
	Limit int
	Now   time.Time
}

type JobResult struct {
	Scanned  int
	Closed   int
	Paid     int
	Deferred int
	Skipped  int
}

type HTTPService interface {
	ChannelInit(ctx context.Context) (*ChannelInitResponse, *apperror.Error)
	ListChannels(ctx context.Context, query ChannelListQuery) (*ChannelListResponse, *apperror.Error)
	CreateChannel(ctx context.Context, input ChannelMutationInput) (int64, *apperror.Error)
	UpdateChannel(ctx context.Context, id int64, input ChannelMutationInput) *apperror.Error
	ChangeChannelStatus(ctx context.Context, id int64, status int) *apperror.Error
	DeleteChannel(ctx context.Context, id int64) *apperror.Error
	OrderInit(ctx context.Context) (*ChannelInitResponse, *apperror.Error)
	ListOrders(ctx context.Context, query OrderListQuery) (*OrderListResponse, *apperror.Error)
	GetAdminOrder(ctx context.Context, orderNo string) (*OrderDetailResponse, *apperror.Error)
	GetOrderResult(ctx context.Context, userID int64, orderNo string) (*ResultResponse, *apperror.Error)
	CreateOrder(ctx context.Context, input CreateOrderInput) (*CreateOrderResponse, *apperror.Error)
	PayOrder(ctx context.Context, userID int64, orderNo string, returnURL string) (*PayOrderResponse, *apperror.Error)
	CancelOrder(ctx context.Context, userID int64, orderNo string) *apperror.Error
	CloseAdminOrder(ctx context.Context, orderNo string) *apperror.Error
	ListEvents(ctx context.Context, query EventListQuery) (*EventListResponse, *apperror.Error)
	GetEvent(ctx context.Context, id int64) (*EventDetailResponse, *apperror.Error)
	HandleAlipayNotify(ctx context.Context, input NotifyInput) (string, *apperror.Error)
}
```

Create `admin_back_go/internal/module/payment/request.go`:

```go
package payment

type listChannelsRequest struct {
	CurrentPage int    `form:"current_page" binding:"required,min=1"`
	PageSize    int    `form:"page_size" binding:"required,min=1,max=100"`
	Name        string `form:"name" binding:"omitempty,max=128"`
	Provider    string `form:"provider" binding:"omitempty,payment_provider"`
	Status      int    `form:"status" binding:"omitempty,common_status"`
}

type channelMutationRequest struct {
	Code              string   `json:"code" binding:"required,max=64"`
	Name              string   `json:"name" binding:"required,max=128"`
	Provider          string   `json:"provider" binding:"required,payment_provider"`
	SupportedMethods  []string `json:"supported_methods" binding:"required,min=1,dive,payment_method"`
	AppID             string   `json:"app_id" binding:"required,max=64"`
	MerchantID        string   `json:"merchant_id" binding:"omitempty,max=64"`
	NotifyURL         string   `json:"notify_url" binding:"required,max=512"`
	ReturnURL         string   `json:"return_url" binding:"omitempty,max=512"`
	PrivateKey        string   `json:"private_key" binding:"omitempty"`
	AppCertPath       string   `json:"app_cert_path" binding:"required,max=512"`
	AlipayCertPath    string   `json:"alipay_cert_path" binding:"required,max=512"`
	AlipayRootCertPath string  `json:"alipay_root_cert_path" binding:"required,max=512"`
	IsSandbox         int      `json:"is_sandbox" binding:"required,common_yes_no"`
	Status            int      `json:"status" binding:"required,common_status"`
	Remark            string   `json:"remark" binding:"omitempty,max=255"`
}

type statusRequest struct {
	Status int `json:"status" binding:"required,common_status"`
}

type orderListRequest struct {
	CurrentPage int    `form:"current_page" binding:"required,min=1"`
	PageSize    int    `form:"page_size" binding:"required,min=1,max=100"`
	OrderNo     string `form:"order_no" binding:"omitempty,max=64"`
	UserID      int64  `form:"user_id" binding:"omitempty,min=1"`
	Status      int    `form:"status" binding:"omitempty,payment_order_status"`
	StartDate   string `form:"start_date" binding:"omitempty,max=32"`
	EndDate     string `form:"end_date" binding:"omitempty,max=32"`
}

type createOrderRequest struct {
	ChannelID    int64  `json:"channel_id" binding:"required,min=1"`
	PayMethod    string `json:"pay_method" binding:"required,payment_method"`
	Subject      string `json:"subject" binding:"required,max=128"`
	AmountCents  int64  `json:"amount_cents" binding:"required,min=1"`
	ReturnURL    string `json:"return_url" binding:"omitempty,max=512"`
	BusinessType string `json:"business_type" binding:"omitempty,max=64"`
	BusinessRef  string `json:"business_ref" binding:"omitempty,max=128"`
}

type payOrderRequest struct {
	ReturnURL string `json:"return_url" binding:"omitempty,max=512"`
}

type eventListRequest struct {
	CurrentPage   int    `form:"current_page" binding:"required,min=1"`
	PageSize      int    `form:"page_size" binding:"required,min=1,max=100"`
	OrderNo       string `form:"order_no" binding:"omitempty,max=64"`
	OutTradeNo    string `form:"out_trade_no" binding:"omitempty,max=64"`
	EventType     string `form:"event_type" binding:"omitempty,payment_event_type"`
	ProcessStatus int    `form:"process_status" binding:"omitempty,payment_event_process_status"`
}
```

Create `admin_back_go/internal/module/payment/errors.go`:

```go
package payment

import "errors"

var ErrRepositoryNotConfigured = errors.New("payment: repository not configured")
var ErrGatewayNotConfigured = errors.New("payment: gateway not configured")
```

- [ ] **Step 4: Add repository**

Create `admin_back_go/internal/module/payment/repository.go` with:

```go
package payment

import (
	"context"
	"errors"
	"strings"
	"time"

	"admin_back_go/internal/enum"
	"admin_back_go/internal/platform/database"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

type Repository interface {
	WithTx(ctx context.Context, fn func(Repository) error) error
	ListChannels(ctx context.Context, query ChannelListQuery) ([]Channel, int64, error)
	GetChannel(ctx context.Context, id int64) (*Channel, error)
	GetChannelConfig(ctx context.Context, channelID int64) (*ChannelConfig, error)
	CreateChannel(ctx context.Context, channel Channel, cfg ChannelConfig) (int64, error)
	UpdateChannel(ctx context.Context, id int64, fields map[string]any, cfgFields map[string]any) error
	ChangeChannelStatus(ctx context.Context, id int64, status int) error
	DeleteChannel(ctx context.Context, id int64) error
	FindEnabledChannel(ctx context.Context, id int64) (*Channel, *ChannelConfig, error)
	CreateOrder(ctx context.Context, order Order) (*Order, error)
	GetOrderByNo(ctx context.Context, orderNo string) (*Order, error)
	GetOrderByNoForUpdate(ctx context.Context, orderNo string) (*Order, error)
	GetOrderByID(ctx context.Context, id int64) (*Order, error)
	ListOrders(ctx context.Context, query OrderListQuery) ([]Order, int64, error)
	MarkOrderPaying(ctx context.Context, orderID int64, outTradeNo string, payURL string, returnURL string, now time.Time) error
	MarkOrderSucceeded(ctx context.Context, orderID int64, tradeNo string, paidAt time.Time) error
	MarkOrderClosed(ctx context.Context, orderID int64, now time.Time) error
	CreateEvent(ctx context.Context, event Event) error
	GetEventByID(ctx context.Context, id int64) (*Event, error)
	ListEvents(ctx context.Context, query EventListQuery) ([]Event, int64, error)
	ListExpiredOrders(ctx context.Context, now time.Time, limit int) ([]Order, error)
	ListPendingOrders(ctx context.Context, now time.Time, limit int) ([]Order, error)
}

type GormRepository struct {
	db *gorm.DB
}

func NewGormRepository(client *database.Client) *GormRepository {
	if client == nil || client.Gorm == nil {
		return nil
	}
	return &GormRepository{db: client.Gorm}
}

func (r *GormRepository) WithTx(ctx context.Context, fn func(Repository) error) error {
	if r == nil || r.db == nil {
		return ErrRepositoryNotConfigured
	}
	return r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		return fn(&GormRepository{db: tx})
	})
}

func (r *GormRepository) ListChannels(ctx context.Context, query ChannelListQuery) ([]Channel, int64, error) {
	if r == nil || r.db == nil {
		return nil, 0, ErrRepositoryNotConfigured
	}
	db := r.db.WithContext(ctx).Model(&Channel{}).Where("is_del = ?", enum.CommonNo)
	if strings.TrimSpace(query.Name) != "" {
		db = db.Where("name LIKE ?", strings.TrimSpace(query.Name)+"%")
	}
	if strings.TrimSpace(query.Provider) != "" {
		db = db.Where("provider = ?", strings.TrimSpace(query.Provider))
	}
	if query.Status > 0 {
		db = db.Where("status = ?", query.Status)
	}
	var total int64
	if err := db.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	var rows []Channel
	err := db.Order("id desc").Limit(query.PageSize).Offset((query.CurrentPage - 1) * query.PageSize).Find(&rows).Error
	return rows, total, err
}

func (r *GormRepository) GetChannel(ctx context.Context, id int64) (*Channel, error) {
	if r == nil || r.db == nil {
		return nil, ErrRepositoryNotConfigured
	}
	var row Channel
	err := r.db.WithContext(ctx).Where("id = ? AND is_del = ?", id, enum.CommonNo).First(&row).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	return &row, err
}

func (r *GormRepository) GetChannelConfig(ctx context.Context, channelID int64) (*ChannelConfig, error) {
	if r == nil || r.db == nil {
		return nil, ErrRepositoryNotConfigured
	}
	var row ChannelConfig
	err := r.db.WithContext(ctx).Where("channel_id = ?", channelID).First(&row).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	return &row, err
}

func (r *GormRepository) CreateChannel(ctx context.Context, channel Channel, cfg ChannelConfig) (int64, error) {
	if r == nil || r.db == nil {
		return 0, ErrRepositoryNotConfigured
	}
	err := r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := tx.Create(&channel).Error; err != nil {
			return err
		}
		cfg.ChannelID = channel.ID
		if err := tx.Create(&cfg).Error; err != nil {
			return err
		}
		return nil
	})
	return channel.ID, err
}

func (r *GormRepository) UpdateChannel(ctx context.Context, id int64, fields map[string]any, cfgFields map[string]any) error {
	if r == nil || r.db == nil {
		return ErrRepositoryNotConfigured
	}
	return r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if len(fields) > 0 {
			if err := tx.Model(&Channel{}).Where("id = ? AND is_del = ?", id, enum.CommonNo).Updates(fields).Error; err != nil {
				return err
			}
		}
		if len(cfgFields) > 0 {
			if err := tx.Model(&ChannelConfig{}).Where("channel_id = ?", id).Updates(cfgFields).Error; err != nil {
				return err
			}
		}
		return nil
	})
}

func (r *GormRepository) ChangeChannelStatus(ctx context.Context, id int64, status int) error {
	return r.UpdateChannel(ctx, id, map[string]any{"status": status}, nil)
}

func (r *GormRepository) DeleteChannel(ctx context.Context, id int64) error {
	return r.UpdateChannel(ctx, id, map[string]any{"is_del": enum.CommonYes}, nil)
}

func (r *GormRepository) FindEnabledChannel(ctx context.Context, id int64) (*Channel, *ChannelConfig, error) {
	channel, err := r.GetChannel(ctx, id)
	if err != nil || channel == nil {
		return channel, nil, err
	}
	if channel.Status != enum.CommonYes {
		return channel, nil, nil
	}
	cfg, err := r.GetChannelConfig(ctx, channel.ID)
	return channel, cfg, err
}

func (r *GormRepository) CreateOrder(ctx context.Context, order Order) (*Order, error) {
	if r == nil || r.db == nil {
		return nil, ErrRepositoryNotConfigured
	}
	if err := r.db.WithContext(ctx).Create(&order).Error; err != nil {
		return nil, err
	}
	return &order, nil
}

func (r *GormRepository) GetOrderByNo(ctx context.Context, orderNo string) (*Order, error) {
	if r == nil || r.db == nil {
		return nil, ErrRepositoryNotConfigured
	}
	var row Order
	err := r.db.WithContext(ctx).Where("order_no = ? AND is_del = ?", strings.TrimSpace(orderNo), enum.CommonNo).First(&row).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	return &row, err
}

func (r *GormRepository) GetOrderByNoForUpdate(ctx context.Context, orderNo string) (*Order, error) {
	if r == nil || r.db == nil {
		return nil, ErrRepositoryNotConfigured
	}
	var row Order
	err := r.db.WithContext(ctx).Clauses(clause.Locking{Strength: "UPDATE"}).Where("order_no = ? AND is_del = ?", strings.TrimSpace(orderNo), enum.CommonNo).First(&row).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	return &row, err
}

func (r *GormRepository) GetOrderByID(ctx context.Context, id int64) (*Order, error) {
	if r == nil || r.db == nil {
		return nil, ErrRepositoryNotConfigured
	}
	var row Order
	err := r.db.WithContext(ctx).Where("id = ? AND is_del = ?", id, enum.CommonNo).First(&row).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	return &row, err
}

func (r *GormRepository) ListOrders(ctx context.Context, query OrderListQuery) ([]Order, int64, error) {
	if r == nil || r.db == nil {
		return nil, 0, ErrRepositoryNotConfigured
	}
	db := r.db.WithContext(ctx).Model(&Order{}).Where("is_del = ?", enum.CommonNo)
	if strings.TrimSpace(query.OrderNo) != "" {
		db = db.Where("order_no LIKE ?", strings.TrimSpace(query.OrderNo)+"%")
	}
	if query.UserID > 0 {
		db = db.Where("user_id = ?", query.UserID)
	}
	if query.Status > 0 {
		db = db.Where("status = ?", query.Status)
	}
	var total int64
	if err := db.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	var rows []Order
	err := db.Order("id desc").Limit(query.PageSize).Offset((query.CurrentPage - 1) * query.PageSize).Find(&rows).Error
	return rows, total, err
}

func (r *GormRepository) MarkOrderPaying(ctx context.Context, orderID int64, outTradeNo string, payURL string, returnURL string, now time.Time) error {
	return r.db.WithContext(ctx).Model(&Order{}).Where("id = ? AND status IN ?", orderID, []int{enum.PaymentOrderPending, enum.PaymentOrderPaying}).Updates(map[string]any{
		"status":       enum.PaymentOrderPaying,
		"out_trade_no": outTradeNo,
		"pay_url":      payURL,
		"return_url":   returnURL,
		"updated_at":   now,
	}).Error
}

func (r *GormRepository) MarkOrderSucceeded(ctx context.Context, orderID int64, tradeNo string, paidAt time.Time) error {
	return r.db.WithContext(ctx).Model(&Order{}).Where("id = ? AND status IN ?", orderID, []int{enum.PaymentOrderPending, enum.PaymentOrderPaying}).Updates(map[string]any{
		"status":     enum.PaymentOrderSucceeded,
		"trade_no":   tradeNo,
		"paid_at":    paidAt,
		"updated_at": paidAt,
	}).Error
}

func (r *GormRepository) MarkOrderClosed(ctx context.Context, orderID int64, now time.Time) error {
	return r.db.WithContext(ctx).Model(&Order{}).Where("id = ? AND status IN ?", orderID, []int{enum.PaymentOrderPending, enum.PaymentOrderPaying}).Updates(map[string]any{
		"status":     enum.PaymentOrderClosed,
		"closed_at":  now,
		"updated_at": now,
	}).Error
}

func (r *GormRepository) CreateEvent(ctx context.Context, event Event) error {
	if r == nil || r.db == nil {
		return ErrRepositoryNotConfigured
	}
	return r.db.WithContext(ctx).Create(&event).Error
}

func (r *GormRepository) GetEventByID(ctx context.Context, id int64) (*Event, error) {
	if r == nil || r.db == nil {
		return nil, ErrRepositoryNotConfigured
	}
	var row Event
	err := r.db.WithContext(ctx).Where("id = ?", id).First(&row).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	return &row, err
}

func (r *GormRepository) ListEvents(ctx context.Context, query EventListQuery) ([]Event, int64, error) {
	if r == nil || r.db == nil {
		return nil, 0, ErrRepositoryNotConfigured
	}
	db := r.db.WithContext(ctx).Model(&Event{})
	if strings.TrimSpace(query.OrderNo) != "" {
		db = db.Where("order_no LIKE ?", strings.TrimSpace(query.OrderNo)+"%")
	}
	if strings.TrimSpace(query.OutTradeNo) != "" {
		db = db.Where("out_trade_no LIKE ?", strings.TrimSpace(query.OutTradeNo)+"%")
	}
	if strings.TrimSpace(query.EventType) != "" {
		db = db.Where("event_type = ?", strings.TrimSpace(query.EventType))
	}
	if query.ProcessStatus > 0 {
		db = db.Where("process_status = ?", query.ProcessStatus)
	}
	var total int64
	if err := db.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	var rows []Event
	err := db.Order("id desc").Limit(query.PageSize).Offset((query.CurrentPage - 1) * query.PageSize).Find(&rows).Error
	return rows, total, err
}

func (r *GormRepository) ListExpiredOrders(ctx context.Context, now time.Time, limit int) ([]Order, error) {
	if r == nil || r.db == nil {
		return nil, ErrRepositoryNotConfigured
	}
	var rows []Order
	err := r.db.WithContext(ctx).Where("status IN ? AND expired_at <= ? AND is_del = ?", []int{enum.PaymentOrderPending, enum.PaymentOrderPaying}, now, enum.CommonNo).Order("id asc").Limit(limit).Find(&rows).Error
	return rows, err
}

func (r *GormRepository) ListPendingOrders(ctx context.Context, now time.Time, limit int) ([]Order, error) {
	if r == nil || r.db == nil {
		return nil, ErrRepositoryNotConfigured
	}
	cutoff := now.Add(-5 * time.Minute)
	var rows []Order
	err := r.db.WithContext(ctx).Where("status = ? AND updated_at <= ? AND is_del = ?", enum.PaymentOrderPaying, cutoff, enum.CommonNo).Order("id asc").Limit(limit).Find(&rows).Error
	return rows, err
}
```

- [ ] **Step 5: Run repository model test**

```powershell
go test ./internal/module/payment -run TestPaymentModelsUseNewTables
```

Expected: pass.

- [ ] **Step 6: Commit**

```powershell
git add admin_back_go/internal/module/payment
git commit -m "feat: add payment data model"
```

---

## Task 5: Implement Payment Service Core

**Files:**
- Create: `admin_back_go/internal/module/payment/number.go`
- Create: `admin_back_go/internal/module/payment/number_test.go`
- Modify: `admin_back_go/internal/module/payment/service.go`
- Modify: `admin_back_go/internal/module/payment/service_test.go`

- [ ] **Step 1: Add deterministic payment number generator**

Create `admin_back_go/internal/module/payment/number.go`:

```go
package payment

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"
)

const orderNoCounterKey = "payment_order_no_counter"

type Counter interface {
	Incr(ctx context.Context, key string) (int64, error)
}

type redisCounter struct { client redis.Cmdable }

func (c redisCounter) Incr(ctx context.Context, key string) (int64, error) {
	if c.client == nil { return 0, errors.New("payment number: redis client not configured") }
	return c.client.Incr(ctx, key).Result()
}

type RedisNumberGenerator struct {
	counter Counter
	now     func() time.Time
}

func NewRedisNumberGenerator(counter Counter, now func() time.Time) *RedisNumberGenerator {
	if now == nil { now = time.Now }
	return &RedisNumberGenerator{counter: counter, now: now}
}

func NewRedisNumberGeneratorFromRedis(client redis.Cmdable) *RedisNumberGenerator {
	return NewRedisNumberGenerator(redisCounter{client: client}, time.Now)
}

func (g *RedisNumberGenerator) Next(ctx context.Context, prefix string) (string, error) {
	if prefix != "P" { return "", fmt.Errorf("payment number: invalid prefix %q", prefix) }
	if g == nil || g.counter == nil { return "", errors.New("payment number: counter not configured") }
	seq, err := g.counter.Incr(ctx, orderNoCounterKey)
	if err != nil { return "", fmt.Errorf("payment number: incr: %w", err) }
	return fmt.Sprintf("%s%s%06d", prefix, g.now().Format("060102150405"), seq%1000000), nil
}
```

Create `admin_back_go/internal/module/payment/number_test.go`:

```go
package payment

import (
	"context"
	"errors"
	"testing"
	"time"
)

func TestRedisNumberGeneratorNext(t *testing.T) {
	generator := NewRedisNumberGenerator(fakeCounter{next: 7}, func() time.Time { return time.Date(2026, 5, 8, 12, 34, 56, 0, time.UTC) })
	value, err := generator.Next(context.Background(), "P")
	if err != nil { t.Fatalf("Next returned error: %v", err) }
	if value != "P260508123456000007" { t.Fatalf("unexpected number: %q", value) }
}

func TestRedisNumberGeneratorRejectsInvalidPrefix(t *testing.T) {
	generator := NewRedisNumberGenerator(fakeCounter{next: 1}, time.Now)
	if _, err := generator.Next(context.Background(), "R"); err == nil { t.Fatalf("expected invalid prefix error") }
}

func TestRedisNumberGeneratorWrapsCounterError(t *testing.T) {
	generator := NewRedisNumberGenerator(fakeCounter{err: errors.New("redis down")}, time.Now)
	if _, err := generator.Next(context.Background(), "P"); err == nil { t.Fatalf("expected counter error") }
}

type fakeCounter struct { next int64; err error }
func (c fakeCounter) Incr(ctx context.Context, key string) (int64, error) { return c.next, c.err }
```

Run:

```powershell
go test ./internal/module/payment -run TestRedisNumberGenerator
```

Expected: pass.

- [ ] **Step 2: Write service tests for no-wallet Alipay flow**

Create `admin_back_go/internal/module/payment/service_test.go`:

```go
package payment

import (
	"context"
	"errors"
	"testing"
	"time"

	"admin_back_go/internal/enum"
	paymentcore "admin_back_go/internal/platform/payment"
)

var errUnexpectedRepositoryCall = errors.New("unexpected repository call")

type fakeGateway struct {
	createCalled bool
	queryStatus  string
	notify       *paymentcore.NotifyResult
}

func (g *fakeGateway) CreatePagePay(ctx context.Context, cfg paymentcore.ChannelConfig, req paymentcore.CreatePayRequest) (*paymentcore.CreatePayResult, error) {
	g.createCalled = true
	return &paymentcore.CreatePayResult{Mode: "external", Content: "https://alipay.example/pay", Raw: map[string]any{"content": "https://alipay.example/pay"}}, nil
}
func (g *fakeGateway) Query(ctx context.Context, cfg paymentcore.ChannelConfig, outTradeNo string) (*paymentcore.QueryResult, error) {
	return &paymentcore.QueryResult{OutTradeNo: outTradeNo, TradeNo: "trade", TradeStatus: g.queryStatus, AmountCents: 1000, AppID: cfg.AppID}, nil
}
func (g *fakeGateway) VerifyNotify(ctx context.Context, cfg paymentcore.ChannelConfig, form map[string]string) (*paymentcore.NotifyResult, error) {
	return g.notify, nil
}
func (g *fakeGateway) Close(ctx context.Context, cfg paymentcore.ChannelConfig, outTradeNo string) error { return nil }
func (g *fakeGateway) SuccessBody() string { return "success" }
func (g *fakeGateway) FailureBody() string { return "fail" }

func TestCreateOrderDoesNotTouchWallet(t *testing.T) {
	repo := newMemoryRepository()
	repo.channel = &Channel{ID: 1, Provider: enum.PaymentProviderAlipay, Status: enum.CommonYes, SupportedMethods: `["web","h5"]`, IsDel: enum.CommonNo}
	repo.config = &ChannelConfig{ChannelID: 1, AppID: "app", PrivateKeyEnc: "plain", NotifyURL: "https://notify", IsSandbox: enum.CommonYes}
	service := NewService(Dependencies{Repository: repo, Gateway: &fakeGateway{}, Secretbox: plainSecretbox{}, CertResolver: passthroughResolver{}, NumberGenerator: staticNumberGenerator("P260508120000000001"), Now: func() time.Time { return time.Date(2026, 5, 8, 12, 0, 0, 0, time.UTC) }})

	res, appErr := service.CreateOrder(context.Background(), CreateOrderInput{UserID: 7, ChannelID: 1, PayMethod: "web", Subject: "测试支付", AmountCents: 1000})
	if appErr != nil {
		t.Fatalf("CreateOrder appErr: %v", appErr)
	}
	if res.OrderNo == "" || res.AmountCents != 1000 {
		t.Fatalf("unexpected response: %#v", res)
	}
	if repo.walletTouched {
		t.Fatalf("payment core must not touch wallet")
	}
}

func TestPayOrderMarksPaying(t *testing.T) {
	repo := newMemoryRepository()
	repo.channel = &Channel{ID: 1, Provider: enum.PaymentProviderAlipay, Status: enum.CommonYes, SupportedMethods: `["web"]`, IsDel: enum.CommonNo}
	repo.config = &ChannelConfig{ChannelID: 1, AppID: "app", PrivateKeyEnc: "plain", NotifyURL: "https://notify", IsSandbox: enum.CommonYes}
	repo.order = &Order{ID: 10, OrderNo: "P1", UserID: 7, ChannelID: 1, Provider: enum.PaymentProviderAlipay, PayMethod: "web", Subject: "测试", AmountCents: 1000, Status: enum.PaymentOrderPending, ExpiredAt: time.Now().Add(time.Hour), IsDel: enum.CommonNo}
	gateway := &fakeGateway{}
	service := NewService(Dependencies{Repository: repo, Gateway: gateway, Secretbox: plainSecretbox{}, CertResolver: passthroughResolver{}, NumberGenerator: staticNumberGenerator("P260508120000000001"), Now: time.Now})

	res, appErr := service.PayOrder(context.Background(), 7, "P1", "http://127.0.0.1:5173/payment/result")
	if appErr != nil {
		t.Fatalf("PayOrder appErr: %v", appErr)
	}
	if !gateway.createCalled || res.PayURL == "" || repo.order.Status != enum.PaymentOrderPaying {
		t.Fatalf("pay order did not mark paying: res=%#v order=%#v", res, repo.order)
	}
}
```

Also create memory fakes in the same file. Use exact minimal fake methods matching `Repository`; every unused method should return `t.Fatal` is not possible inside methods, so return a clear error:

```go
type plainSecretbox struct{}
func (plainSecretbox) Encrypt(value string) (string, error) { return value, nil }
func (plainSecretbox) Decrypt(value string) (string, error) { return value, nil }

type passthroughResolver struct{}
func (passthroughResolver) Resolve(path string) (string, error) { return path, nil }

type staticNumberGenerator string
func (g staticNumberGenerator) Next(ctx context.Context, prefix string) (string, error) { return string(g), nil }

type memoryRepository struct {
	channel       *Channel
	config        *ChannelConfig
	order         *Order
	events        []Event
	walletTouched bool
}

func newMemoryRepository() *memoryRepository { return &memoryRepository{} }
func (r *memoryRepository) WithTx(ctx context.Context, fn func(Repository) error) error { return fn(r) }
func (r *memoryRepository) ListChannels(ctx context.Context, query ChannelListQuery) ([]Channel, int64, error) { return nil, 0, errUnexpectedRepositoryCall }
func (r *memoryRepository) GetChannel(ctx context.Context, id int64) (*Channel, error) { if r.channel != nil && r.channel.ID == id { return r.channel, nil }; return nil, nil }
func (r *memoryRepository) GetChannelConfig(ctx context.Context, channelID int64) (*ChannelConfig, error) { if r.config != nil && r.config.ChannelID == channelID { return r.config, nil }; return nil, nil }
func (r *memoryRepository) CreateChannel(ctx context.Context, channel Channel, cfg ChannelConfig) (int64, error) { return 0, errUnexpectedRepositoryCall }
func (r *memoryRepository) UpdateChannel(ctx context.Context, id int64, fields map[string]any, cfgFields map[string]any) error { return errUnexpectedRepositoryCall }
func (r *memoryRepository) ChangeChannelStatus(ctx context.Context, id int64, status int) error { return errUnexpectedRepositoryCall }
func (r *memoryRepository) DeleteChannel(ctx context.Context, id int64) error { return errUnexpectedRepositoryCall }
func (r *memoryRepository) FindEnabledChannel(ctx context.Context, id int64) (*Channel, *ChannelConfig, error) { if r.channel != nil && r.config != nil && r.channel.ID == id { return r.channel, r.config, nil }; return nil, nil, nil }
func (r *memoryRepository) CreateOrder(ctx context.Context, order Order) (*Order, error) { order.ID = 1; r.order = &order; return &order, nil }
func (r *memoryRepository) GetOrderByNo(ctx context.Context, orderNo string) (*Order, error) { if r.order != nil && r.order.OrderNo == orderNo { return r.order, nil }; return nil, nil }
func (r *memoryRepository) GetOrderByNoForUpdate(ctx context.Context, orderNo string) (*Order, error) { return r.GetOrderByNo(ctx, orderNo) }
func (r *memoryRepository) GetOrderByID(ctx context.Context, id int64) (*Order, error) { if r.order != nil && r.order.ID == id { return r.order, nil }; return nil, nil }
func (r *memoryRepository) ListOrders(ctx context.Context, query OrderListQuery) ([]Order, int64, error) { return nil, 0, errUnexpectedRepositoryCall }
func (r *memoryRepository) MarkOrderPaying(ctx context.Context, orderID int64, outTradeNo string, payURL string, returnURL string, now time.Time) error { r.order.Status = enum.PaymentOrderPaying; r.order.OutTradeNo = outTradeNo; r.order.PayURL = payURL; r.order.ReturnURL = returnURL; return nil }
func (r *memoryRepository) MarkOrderSucceeded(ctx context.Context, orderID int64, tradeNo string, paidAt time.Time) error { r.order.Status = enum.PaymentOrderSucceeded; r.order.TradeNo = tradeNo; r.order.PaidAt = &paidAt; return nil }
func (r *memoryRepository) MarkOrderClosed(ctx context.Context, orderID int64, now time.Time) error { r.order.Status = enum.PaymentOrderClosed; r.order.ClosedAt = &now; return nil }
func (r *memoryRepository) CreateEvent(ctx context.Context, event Event) error { r.events = append(r.events, event); return nil }
func (r *memoryRepository) GetEventByID(ctx context.Context, id int64) (*Event, error) { return nil, errUnexpectedRepositoryCall }
func (r *memoryRepository) ListEvents(ctx context.Context, query EventListQuery) ([]Event, int64, error) { return nil, 0, errUnexpectedRepositoryCall }
func (r *memoryRepository) ListExpiredOrders(ctx context.Context, now time.Time, limit int) ([]Order, error) { return nil, errUnexpectedRepositoryCall }
func (r *memoryRepository) ListPendingOrders(ctx context.Context, now time.Time, limit int) ([]Order, error) { return nil, errUnexpectedRepositoryCall }
```

Run:

```powershell
go test ./internal/module/payment -run 'TestCreateOrderDoesNotTouchWallet|TestPayOrderMarksPaying'
```

Expected: fail because service is not implemented.

- [ ] **Step 3: Implement service**

Create `admin_back_go/internal/module/payment/service.go`:

```go
package payment

import (
	"context"
	"encoding/json"
	"math"
	"strings"
	"time"

	"admin_back_go/internal/apperror"
	"admin_back_go/internal/dict"
	"admin_back_go/internal/enum"
	paymentcore "admin_back_go/internal/platform/payment"
	"admin_back_go/internal/platform/secretbox"
)

const timeLayout = "2006-01-02 15:04:05"

type secretDecrypter interface {
	Decrypt(value string) (string, error)
	Encrypt(value string) (string, error)
}

type certResolver interface {
	Resolve(path string) (string, error)
}

type Dependencies struct {
	Repository      Repository
	Gateway         paymentcore.Gateway
	Secretbox       secretDecrypter
	CertResolver    certResolver
	NumberGenerator NumberGenerator
	Now             func() time.Time
}

type Service struct {
	repository      Repository
	gateway         paymentcore.Gateway
	secretbox       secretDecrypter
	certResolver    certResolver
	numberGenerator NumberGenerator
	now             func() time.Time
}

func NewService(deps Dependencies) *Service {
	now := deps.Now
	if now == nil {
		now = time.Now
	}
	return &Service{repository: deps.Repository, gateway: deps.Gateway, secretbox: deps.Secretbox, certResolver: deps.CertResolver, numberGenerator: deps.NumberGenerator, now: now}
}

func (s *Service) ChannelInit(ctx context.Context) (*ChannelInitResponse, *apperror.Error) {
	return &ChannelInitResponse{Dict: ChannelInitDict{ProviderArr: dict.PaymentProviderOptions(), CommonStatusArr: dict.CommonStatusOptions(), PayMethodArr: dict.PaymentMethodOptions(), YesNoArr: dict.CommonYesNoOptions()}}, nil
}

func (s *Service) ListChannels(ctx context.Context, query ChannelListQuery) (*ChannelListResponse, *apperror.Error) {
	repo, appErr := s.requireRepository()
	if appErr != nil { return nil, appErr }
	query = normalizeChannelQuery(query)
	rows, total, err := repo.ListChannels(ctx, query)
	if err != nil { return nil, apperror.Wrap(apperror.CodeInternal, 500, "查询支付渠道失败", err) }
	list := make([]ChannelListItem, 0, len(rows))
	for _, row := range rows {
		cfg, _ := repo.GetChannelConfig(ctx, row.ID)
		list = append(list, channelItem(row, cfg))
	}
	return &ChannelListResponse{List: list, Page: page(total, query.CurrentPage, query.PageSize)}, nil
}

func (s *Service) CreateChannel(ctx context.Context, input ChannelMutationInput) (int64, *apperror.Error) {
	repo, appErr := s.requireRepository()
	if appErr != nil { return 0, appErr }
	channel, cfg, appErr := s.normalizeChannelInput(input)
	if appErr != nil { return 0, appErr }
	id, err := repo.CreateChannel(ctx, channel, cfg)
	if err != nil { return 0, apperror.Wrap(apperror.CodeInternal, 500, "新增支付渠道失败", err) }
	return id, nil
}

func (s *Service) UpdateChannel(ctx context.Context, id int64, input ChannelMutationInput) *apperror.Error {
	if id <= 0 { return apperror.BadRequest("无效的支付渠道ID") }
	repo, appErr := s.requireRepository()
	if appErr != nil { return appErr }
	_, cfg, appErr := s.normalizeChannelInput(input)
	if appErr != nil { return appErr }
	fields := map[string]any{"code": strings.TrimSpace(input.Code), "name": strings.TrimSpace(input.Name), "provider": strings.TrimSpace(input.Provider), "supported_methods": mustJSON(input.SupportedMethods), "status": input.Status, "remark": strings.TrimSpace(input.Remark)}
	cfgFields := map[string]any{"app_id": strings.TrimSpace(input.AppID), "merchant_id": strings.TrimSpace(input.MerchantID), "notify_url": strings.TrimSpace(input.NotifyURL), "return_url": strings.TrimSpace(input.ReturnURL), "app_cert_path": strings.TrimSpace(input.AppCertPath), "alipay_cert_path": strings.TrimSpace(input.AlipayCertPath), "alipay_root_cert_path": strings.TrimSpace(input.AlipayRootCertPath), "is_sandbox": input.IsSandbox}
	if cfg.PrivateKeyEnc != "" {
		cfgFields["private_key_enc"] = cfg.PrivateKeyEnc
		cfgFields["private_key_hint"] = cfg.PrivateKeyHint
	}
	if err := repo.UpdateChannel(ctx, id, fields, cfgFields); err != nil { return apperror.Wrap(apperror.CodeInternal, 500, "编辑支付渠道失败", err) }
	return nil
}

func (s *Service) ChangeChannelStatus(ctx context.Context, id int64, status int) *apperror.Error {
	if !enum.IsCommonStatus(status) { return apperror.BadRequest("无效的状态") }
	repo, appErr := s.requireRepository()
	if appErr != nil { return appErr }
	if err := repo.ChangeChannelStatus(ctx, id, status); err != nil { return apperror.Wrap(apperror.CodeInternal, 500, "切换支付渠道状态失败", err) }
	return nil
}

func (s *Service) DeleteChannel(ctx context.Context, id int64) *apperror.Error {
	repo, appErr := s.requireRepository()
	if appErr != nil { return appErr }
	if err := repo.DeleteChannel(ctx, id); err != nil { return apperror.Wrap(apperror.CodeInternal, 500, "删除支付渠道失败", err) }
	return nil
}

func (s *Service) OrderInit(ctx context.Context) (*ChannelInitResponse, *apperror.Error) { return s.ChannelInit(ctx) }

func (s *Service) CreateOrder(ctx context.Context, input CreateOrderInput) (*CreateOrderResponse, *apperror.Error) {
	repo, appErr := s.requireRepository()
	if appErr != nil { return nil, appErr }
	if s.numberGenerator == nil { return nil, apperror.Internal("支付单号生成器未配置") }
	now := s.now()
	orderNo, err := s.numberGenerator.Next(ctx, "P")
	if err != nil { return nil, apperror.Wrap(apperror.CodeInternal, 500, "生成支付订单号失败", err) }
	order := Order{OrderNo: orderNo, UserID: input.UserID, ChannelID: input.ChannelID, Provider: enum.PaymentProviderAlipay, PayMethod: strings.TrimSpace(input.PayMethod), Subject: strings.TrimSpace(input.Subject), AmountCents: input.AmountCents, Currency: "CNY", Status: enum.PaymentOrderPending, ExpiredAt: now.Add(30 * time.Minute), ClientIP: input.ClientIP, ReturnURL: strings.TrimSpace(input.ReturnURL), BusinessType: defaultString(input.BusinessType, "manual_test"), BusinessRef: strings.TrimSpace(input.BusinessRef), OutTradeNo: orderNo, IsDel: enum.CommonNo}
	created, err := repo.CreateOrder(ctx, order)
	if err != nil { return nil, apperror.Wrap(apperror.CodeInternal, 500, "创建支付订单失败", err) }
	return &CreateOrderResponse{OrderNo: created.OrderNo, AmountCents: created.AmountCents, ExpiredAt: formatTime(created.ExpiredAt)}, nil
}

func (s *Service) PayOrder(ctx context.Context, userID int64, orderNo string, returnURL string) (*PayOrderResponse, *apperror.Error) {
	repo, appErr := s.requireRepository()
	if appErr != nil { return nil, appErr }
	gateway, appErr := s.requireGateway()
	if appErr != nil { return nil, appErr }
	order, err := repo.GetOrderByNo(ctx, strings.TrimSpace(orderNo))
	if err != nil { return nil, apperror.Wrap(apperror.CodeInternal, 500, "查询支付订单失败", err) }
	if order == nil || order.UserID != userID { return nil, apperror.NotFound("支付订单不存在") }
	if order.Status == enum.PaymentOrderSucceeded { return nil, apperror.BadRequest("订单已支付") }
	channel, cfg, err := repo.FindEnabledChannel(ctx, order.ChannelID)
	if err != nil { return nil, apperror.Wrap(apperror.CodeInternal, 500, "查询支付渠道失败", err) }
	if channel == nil || cfg == nil { return nil, apperror.BadRequest("支付渠道不可用") }
	gatewayCfg, appErr := s.gatewayConfig(channel, cfg)
	if appErr != nil { return nil, appErr }
	outTradeNo := defaultString(order.OutTradeNo, order.OrderNo)
	result, err := gateway.CreatePagePay(ctx, gatewayCfg, paymentcore.CreatePayRequest{OutTradeNo: outTradeNo, Subject: order.Subject, AmountCents: order.AmountCents, PayMethod: order.PayMethod, ReturnURL: firstNonEmpty(returnURL, order.ReturnURL, cfg.ReturnURL)})
	if err != nil {
		_ = repo.CreateEvent(ctx, eventFrom(order, enum.PaymentEventCreate, enum.PaymentEventFailed, nil, map[string]any{"error": err.Error()}, err.Error()))
		return nil, apperror.Wrap(apperror.CodeInternal, 500, "创建支付宝支付失败", err)
	}
	if err := repo.MarkOrderPaying(ctx, order.ID, outTradeNo, result.Content, firstNonEmpty(returnURL, order.ReturnURL, cfg.ReturnURL), s.now()); err != nil {
		return nil, apperror.Wrap(apperror.CodeInternal, 500, "更新支付订单失败", err)
	}
	_ = repo.CreateEvent(ctx, eventFrom(order, enum.PaymentEventCreate, enum.PaymentEventSuccess, map[string]any{"out_trade_no": outTradeNo}, result.Raw, ""))
	return &PayOrderResponse{OrderNo: order.OrderNo, OutTradeNo: outTradeNo, PayMethod: order.PayMethod, PayURL: result.Content, PayData: result.Raw}, nil
}

func (s *Service) GetOrderResult(ctx context.Context, userID int64, orderNo string) (*ResultResponse, *apperror.Error) {
	repo, appErr := s.requireRepository()
	if appErr != nil { return nil, appErr }
	order, err := repo.GetOrderByNo(ctx, orderNo)
	if err != nil { return nil, apperror.Wrap(apperror.CodeInternal, 500, "查询支付结果失败", err) }
	if order == nil || order.UserID != userID { return nil, apperror.NotFound("支付订单不存在") }
	return resultItem(*order), nil
}

func (s *Service) CancelOrder(ctx context.Context, userID int64, orderNo string) *apperror.Error {
	repo, appErr := s.requireRepository()
	if appErr != nil { return appErr }
	order, err := repo.GetOrderByNo(ctx, orderNo)
	if err != nil { return apperror.Wrap(apperror.CodeInternal, 500, "查询支付订单失败", err) }
	if order == nil || order.UserID != userID { return apperror.NotFound("支付订单不存在") }
	if err := repo.MarkOrderClosed(ctx, order.ID, s.now()); err != nil { return apperror.Wrap(apperror.CodeInternal, 500, "取消支付订单失败", err) }
	return nil
}

func (s *Service) HandleAlipayNotify(ctx context.Context, input NotifyInput) (string, *apperror.Error) {
	repo, appErr := s.requireRepository()
	if appErr != nil { return "fail", appErr }
	gateway, appErr := s.requireGateway()
	if appErr != nil { return "fail", appErr }
	outTradeNo := strings.TrimSpace(input.Form["out_trade_no"])
	order, err := repo.GetOrderByNo(ctx, outTradeNo)
	if err != nil || order == nil { return gateway.FailureBody(), nil }
	channel, cfg, err := repo.FindEnabledChannel(ctx, order.ChannelID)
	if err != nil || channel == nil || cfg == nil { return gateway.FailureBody(), nil }
	gatewayCfg, appErr := s.gatewayConfig(channel, cfg)
	if appErr != nil { return gateway.FailureBody(), appErr }
	result, err := gateway.VerifyNotify(ctx, gatewayCfg, input.Form)
	if err != nil {
		_ = repo.CreateEvent(ctx, eventFrom(order, enum.PaymentEventNotify, enum.PaymentEventFailed, stringMapToAny(input.Form), nil, err.Error()))
		return gateway.FailureBody(), nil
	}
	if result.AppID != cfg.AppID || result.AmountCents != order.AmountCents || !result.PaidStatus() {
		_ = repo.CreateEvent(ctx, eventFrom(order, enum.PaymentEventNotify, enum.PaymentEventFailed, stringMapToAny(input.Form), result.Raw, "notify data mismatch"))
		return gateway.FailureBody(), nil
	}
	err = repo.WithTx(ctx, func(tx Repository) error {
		locked, err := tx.GetOrderByNoForUpdate(ctx, order.OrderNo)
		if err != nil || locked == nil { return err }
		if locked.Status == enum.PaymentOrderSucceeded {
			return tx.CreateEvent(ctx, eventFrom(locked, enum.PaymentEventNotify, enum.PaymentEventIgnored, stringMapToAny(input.Form), result.Raw, "already succeeded"))
		}
		if err := tx.MarkOrderSucceeded(ctx, locked.ID, result.TradeNo, s.now()); err != nil { return err }
		return tx.CreateEvent(ctx, eventFrom(locked, enum.PaymentEventNotify, enum.PaymentEventSuccess, stringMapToAny(input.Form), result.Raw, ""))
	})
	if err != nil { return gateway.FailureBody(), apperror.Wrap(apperror.CodeInternal, 500, "处理支付宝回调失败", err) }
	return gateway.SuccessBody(), nil
}

```

Append the list, detail, event, cron, and helper service methods to the same file:

```go
func (s *Service) ListOrders(ctx context.Context, query OrderListQuery) (*OrderListResponse, *apperror.Error) {
	repo, appErr := s.requireRepository()
	if appErr != nil {
		return nil, appErr
	}
	query = normalizeOrderQuery(query)
	rows, total, err := repo.ListOrders(ctx, query)
	if err != nil {
		return nil, apperror.Wrap(apperror.CodeInternal, 500, "查询支付订单失败", err)
	}
	list := make([]OrderListItem, 0, len(rows))
	for _, row := range rows {
		list = append(list, orderItem(row))
	}
	return &OrderListResponse{List: list, Page: page(total, query.CurrentPage, query.PageSize)}, nil
}

func (s *Service) GetAdminOrder(ctx context.Context, orderNo string) (*OrderDetailResponse, *apperror.Error) {
	if strings.TrimSpace(orderNo) == "" {
		return nil, apperror.BadRequest("无效的支付订单号")
	}
	repo, appErr := s.requireRepository()
	if appErr != nil {
		return nil, appErr
	}
	order, err := repo.GetOrderByNo(ctx, strings.TrimSpace(orderNo))
	if err != nil {
		return nil, apperror.Wrap(apperror.CodeInternal, 500, "查询支付订单失败", err)
	}
	if order == nil {
		return nil, apperror.NotFound("支付订单不存在")
	}
	return &OrderDetailResponse{Order: orderItem(*order)}, nil
}

func (s *Service) CloseAdminOrder(ctx context.Context, orderNo string) *apperror.Error {
	if strings.TrimSpace(orderNo) == "" {
		return apperror.BadRequest("无效的支付订单号")
	}
	repo, appErr := s.requireRepository()
	if appErr != nil {
		return appErr
	}
	order, err := repo.GetOrderByNo(ctx, strings.TrimSpace(orderNo))
	if err != nil {
		return apperror.Wrap(apperror.CodeInternal, 500, "查询支付订单失败", err)
	}
	if order == nil {
		return apperror.NotFound("支付订单不存在")
	}
	if order.Status == enum.PaymentOrderSucceeded {
		return apperror.BadRequest("已支付订单不能关闭")
	}
	if err := repo.MarkOrderClosed(ctx, order.ID, s.now()); err != nil {
		return apperror.Wrap(apperror.CodeInternal, 500, "关闭支付订单失败", err)
	}
	return nil
}

func (s *Service) ListEvents(ctx context.Context, query EventListQuery) (*EventListResponse, *apperror.Error) {
	repo, appErr := s.requireRepository()
	if appErr != nil {
		return nil, appErr
	}
	query = normalizeEventQuery(query)
	rows, total, err := repo.ListEvents(ctx, query)
	if err != nil {
		return nil, apperror.Wrap(apperror.CodeInternal, 500, "查询支付事件失败", err)
	}
	list := make([]EventListItem, 0, len(rows))
	for _, row := range rows {
		list = append(list, eventItem(row))
	}
	return &EventListResponse{List: list, Page: page(total, query.CurrentPage, query.PageSize)}, nil
}

func (s *Service) GetEvent(ctx context.Context, id int64) (*EventDetailResponse, *apperror.Error) {
	if id <= 0 {
		return nil, apperror.BadRequest("无效的支付事件ID")
	}
	repo, appErr := s.requireRepository()
	if appErr != nil {
		return nil, appErr
	}
	row, err := repo.GetEventByID(ctx, id)
	if err != nil {
		return nil, apperror.Wrap(apperror.CodeInternal, 500, "查询支付事件失败", err)
	}
	if row == nil {
		return nil, apperror.NotFound("支付事件不存在")
	}
	requestData := map[string]any{}
	responseData := map[string]any{}
	_ = json.Unmarshal([]byte(row.RequestData), &requestData)
	_ = json.Unmarshal([]byte(row.ResponseData), &responseData)
	return &EventDetailResponse{Event: eventItem(*row), RequestData: requestData, ResponseData: responseData}, nil
}

func (s *Service) CloseExpiredOrders(ctx context.Context, input CloseExpiredInput) (*JobResult, error) {
	repo, appErr := s.requireRepository()
	if appErr != nil {
		return nil, appErr
	}
	gateway, appErr := s.requireGateway()
	if appErr != nil {
		return nil, appErr
	}
	limit := input.Limit
	if limit <= 0 || limit > 100 {
		limit = 50
	}
	now := input.Now
	if now.IsZero() {
		now = s.now()
	}
	rows, err := repo.ListExpiredOrders(ctx, now, limit)
	if err != nil {
		return nil, err
	}
	result := &JobResult{Scanned: len(rows)}
	for _, row := range rows {
		channel, cfg, err := repo.FindEnabledChannel(ctx, row.ChannelID)
		if err != nil || channel == nil || cfg == nil {
			result.Deferred++
			continue
		}
		gatewayCfg, cfgErr := s.gatewayConfig(channel, cfg)
		if cfgErr != nil {
			result.Deferred++
			continue
		}
		query, err := gateway.Query(ctx, gatewayCfg, row.OutTradeNo)
		if err == nil && query.PaidStatus() && query.AmountCents == row.AmountCents {
			if err := repo.MarkOrderSucceeded(ctx, row.ID, query.TradeNo, now); err != nil {
				result.Deferred++
				continue
			}
			result.Paid++
			continue
		}
		if err != nil {
			result.Deferred++
			continue
		}
		_ = gateway.Close(ctx, gatewayCfg, row.OutTradeNo)
		if err := repo.MarkOrderClosed(ctx, row.ID, now); err != nil {
			result.Deferred++
			continue
		}
		result.Closed++
	}
	return result, nil
}

func (s *Service) SyncPendingOrders(ctx context.Context, input SyncPendingInput) (*JobResult, error) {
	repo, appErr := s.requireRepository()
	if appErr != nil {
		return nil, appErr
	}
	gateway, appErr := s.requireGateway()
	if appErr != nil {
		return nil, appErr
	}
	limit := input.Limit
	if limit <= 0 || limit > 100 {
		limit = 100
	}
	now := input.Now
	if now.IsZero() {
		now = s.now()
	}
	rows, err := repo.ListPendingOrders(ctx, now, limit)
	if err != nil {
		return nil, err
	}
	result := &JobResult{Scanned: len(rows)}
	for _, row := range rows {
		channel, cfg, err := repo.FindEnabledChannel(ctx, row.ChannelID)
		if err != nil || channel == nil || cfg == nil {
			result.Deferred++
			continue
		}
		gatewayCfg, cfgErr := s.gatewayConfig(channel, cfg)
		if cfgErr != nil {
			result.Deferred++
			continue
		}
		query, err := gateway.Query(ctx, gatewayCfg, row.OutTradeNo)
		if err != nil {
			result.Deferred++
			continue
		}
		if query.PaidStatus() && query.AmountCents == row.AmountCents {
			if err := repo.MarkOrderSucceeded(ctx, row.ID, query.TradeNo, now); err != nil {
				result.Deferred++
				continue
			}
			result.Paid++
			continue
		}
		result.Skipped++
	}
	return result, nil
}

func (s *Service) requireRepository() (Repository, *apperror.Error) {
	if s == nil || s.repository == nil {
		return nil, apperror.Internal("支付仓储未配置")
	}
	return s.repository, nil
}

func (s *Service) requireGateway() (paymentcore.Gateway, *apperror.Error) {
	if s == nil || s.gateway == nil {
		return nil, apperror.Internal("支付网关未配置")
	}
	return s.gateway, nil
}

func (s *Service) normalizeChannelInput(input ChannelMutationInput) (Channel, ChannelConfig, *apperror.Error) {
	if !enum.IsPaymentProvider(strings.TrimSpace(input.Provider)) {
		return Channel{}, ChannelConfig{}, apperror.BadRequest("无效的支付服务商")
	}
	if len(input.SupportedMethods) == 0 {
		return Channel{}, ChannelConfig{}, apperror.BadRequest("请至少选择一种支付方式")
	}
	for _, method := range input.SupportedMethods {
		if !enum.IsPaymentMethod(strings.TrimSpace(method)) {
			return Channel{}, ChannelConfig{}, apperror.BadRequest("无效的支付方式")
		}
	}
	privateKeyEnc := ""
	privateKeyHint := ""
	if strings.TrimSpace(input.PrivateKey) != "" {
		if s.secretbox == nil {
			return Channel{}, ChannelConfig{}, apperror.Internal("支付密钥加密器未配置")
		}
		ciphertext, err := s.secretbox.Encrypt(strings.TrimSpace(input.PrivateKey))
		if err != nil {
			return Channel{}, ChannelConfig{}, apperror.Wrap(apperror.CodeInternal, 500, "加密支付私钥失败", err)
		}
		privateKeyEnc = ciphertext
		privateKeyHint = secretbox.Hint(strings.TrimSpace(input.PrivateKey))
	}
	channel := Channel{
		Code:             strings.TrimSpace(input.Code),
		Name:             strings.TrimSpace(input.Name),
		Provider:         strings.TrimSpace(input.Provider),
		Status:           input.Status,
		SupportedMethods: mustJSON(input.SupportedMethods),
		Remark:           strings.TrimSpace(input.Remark),
		IsDel:            enum.CommonNo,
	}
	cfg := ChannelConfig{
		AppID:              strings.TrimSpace(input.AppID),
		MerchantID:         strings.TrimSpace(input.MerchantID),
		SignType:           "RSA2",
		IsSandbox:          input.IsSandbox,
		NotifyURL:          strings.TrimSpace(input.NotifyURL),
		ReturnURL:          strings.TrimSpace(input.ReturnURL),
		PrivateKeyEnc:      privateKeyEnc,
		PrivateKeyHint:     privateKeyHint,
		AppCertPath:        strings.TrimSpace(input.AppCertPath),
		AlipayCertPath:     strings.TrimSpace(input.AlipayCertPath),
		AlipayRootCertPath: strings.TrimSpace(input.AlipayRootCertPath),
		ExtraConfig:        "{}",
	}
	return channel, cfg, nil
}

func (s *Service) gatewayConfig(channel *Channel, cfg *ChannelConfig) (paymentcore.ChannelConfig, *apperror.Error) {
	if cfg == nil || channel == nil {
		return paymentcore.ChannelConfig{}, apperror.BadRequest("支付渠道不可用")
	}
	if s.secretbox == nil {
		return paymentcore.ChannelConfig{}, apperror.Internal("支付密钥解密器未配置")
	}
	privateKey, err := s.secretbox.Decrypt(cfg.PrivateKeyEnc)
	if err != nil {
		return paymentcore.ChannelConfig{}, apperror.Wrap(apperror.CodeInternal, 500, "解密支付私钥失败", err)
	}
	appCert := cfg.AppCertPath
	alipayCert := cfg.AlipayCertPath
	rootCert := cfg.AlipayRootCertPath
	if s.certResolver != nil {
		if appCert, err = s.certResolver.Resolve(cfg.AppCertPath); err != nil {
			return paymentcore.ChannelConfig{}, apperror.Wrap(apperror.CodeInternal, 500, "解析应用证书失败", err)
		}
		if alipayCert, err = s.certResolver.Resolve(cfg.AlipayCertPath); err != nil {
			return paymentcore.ChannelConfig{}, apperror.Wrap(apperror.CodeInternal, 500, "解析支付宝证书失败", err)
		}
		if rootCert, err = s.certResolver.Resolve(cfg.AlipayRootCertPath); err != nil {
			return paymentcore.ChannelConfig{}, apperror.Wrap(apperror.CodeInternal, 500, "解析支付宝根证书失败", err)
		}
	}
	return paymentcore.ChannelConfig{ChannelID: channel.ID, AppID: cfg.AppID, PrivateKey: privateKey, AppCertPath: appCert, AlipayCertPath: alipayCert, RootCertPath: rootCert, NotifyURL: cfg.NotifyURL, IsSandbox: cfg.IsSandbox == enum.CommonYes}, nil
}

func normalizeChannelQuery(query ChannelListQuery) ChannelListQuery { if query.CurrentPage <= 0 { query.CurrentPage = 1 }; if query.PageSize <= 0 || query.PageSize > 100 { query.PageSize = 20 }; return query }
func normalizeOrderQuery(query OrderListQuery) OrderListQuery { if query.CurrentPage <= 0 { query.CurrentPage = 1 }; if query.PageSize <= 0 || query.PageSize > 100 { query.PageSize = 20 }; return query }
func normalizeEventQuery(query EventListQuery) EventListQuery { if query.CurrentPage <= 0 { query.CurrentPage = 1 }; if query.PageSize <= 0 || query.PageSize > 100 { query.PageSize = 20 }; return query }
func page(total int64, currentPage int, pageSize int) Page { return Page{PageSize: pageSize, CurrentPage: currentPage, Total: total, TotalPage: int(math.Ceil(float64(total) / float64(pageSize)))} }
func formatTime(t time.Time) string { if t.IsZero() { return "" }; return t.Format(timeLayout) }
func formatTimePtr(t *time.Time) string { if t == nil || t.IsZero() { return "" }; return t.Format(timeLayout) }
func defaultString(value string, fallback string) string { if strings.TrimSpace(value) == "" { return fallback }; return strings.TrimSpace(value) }
func firstNonEmpty(values ...string) string { for _, value := range values { if strings.TrimSpace(value) != "" { return strings.TrimSpace(value) } }; return "" }

func mustJSON(value any) string {
	data, err := json.Marshal(value)
	if err != nil {
		return "{}"
	}
	return string(data)
}

func channelItem(row Channel, cfg *ChannelConfig) ChannelListItem {
	methods := []string{}
	_ = json.Unmarshal([]byte(row.SupportedMethods), &methods)
	item := ChannelListItem{ID: row.ID, Code: row.Code, Name: row.Name, Provider: row.Provider, ProviderText: enum.PaymentProviderLabels[row.Provider], SupportedMethods: methods, SupportedText: strings.Join(methods, ","), Status: row.Status, StatusText: commonStatusText(row.Status), Remark: row.Remark, CreatedAt: formatTime(row.CreatedAt), UpdatedAt: formatTime(row.UpdatedAt)}
	if cfg != nil {
		item.AppID = cfg.AppID
		item.MerchantID = cfg.MerchantID
		item.NotifyURL = cfg.NotifyURL
		item.ReturnURL = cfg.ReturnURL
		item.PrivateKeyHint = cfg.PrivateKeyHint
		item.AppCertPath = cfg.AppCertPath
		item.AlipayCertPath = cfg.AlipayCertPath
		item.AlipayRootCertPath = cfg.AlipayRootCertPath
		item.IsSandbox = cfg.IsSandbox
	}
	return item
}

func orderItem(row Order) OrderListItem {
	return OrderListItem{ID: row.ID, OrderNo: row.OrderNo, UserID: row.UserID, ChannelID: row.ChannelID, Provider: row.Provider, PayMethod: row.PayMethod, Subject: row.Subject, AmountCents: row.AmountCents, Status: row.Status, StatusText: enum.PaymentOrderStatusLabels[row.Status], OutTradeNo: row.OutTradeNo, TradeNo: row.TradeNo, PaidAt: formatTimePtr(row.PaidAt), ExpiredAt: formatTime(row.ExpiredAt), ClosedAt: formatTimePtr(row.ClosedAt), CreatedAt: formatTime(row.CreatedAt)}
}

func resultItem(row Order) *ResultResponse {
	return &ResultResponse{OrderNo: row.OrderNo, Status: row.Status, StatusText: enum.PaymentOrderStatusLabels[row.Status], TradeNo: row.TradeNo, PaidAt: formatTimePtr(row.PaidAt)}
}

func eventItem(row Event) EventListItem {
	return EventListItem{ID: row.ID, OrderNo: row.OrderNo, OutTradeNo: row.OutTradeNo, EventType: row.EventType, EventTypeText: enum.PaymentEventTypeLabels[row.EventType], Provider: row.Provider, ProcessStatus: row.ProcessStatus, ProcessText: enum.PaymentEventProcessStatusLabels[row.ProcessStatus], ErrorMessage: row.ErrorMessage, CreatedAt: formatTime(row.CreatedAt)}
}

func eventFrom(order *Order, eventType string, status int, request map[string]any, response map[string]any, message string) Event {
	if request == nil {
		request = map[string]any{}
	}
	if response == nil {
		response = map[string]any{}
	}
	return Event{OrderNo: order.OrderNo, OutTradeNo: order.OutTradeNo, EventType: eventType, Provider: order.Provider, RequestData: mustJSON(request), ResponseData: mustJSON(response), ProcessStatus: status, ErrorMessage: message}
}

func stringMapToAny(input map[string]string) map[string]any {
	output := make(map[string]any, len(input))
	for key, value := range input {
		output[key] = value
	}
	return output
}

func commonStatusText(status int) string {
	if status == enum.CommonYes {
		return "启用"
	}
	if status == enum.CommonNo {
		return "禁用"
	}
	return ""
}
```

- [ ] **Step 4: Run service tests**

```powershell
go test ./internal/module/payment
```

Expected: pass.

- [ ] **Step 5: Commit**

```powershell
git add admin_back_go/internal/module/payment/number.go admin_back_go/internal/module/payment/number_test.go admin_back_go/internal/module/payment/service.go admin_back_go/internal/module/payment/service_test.go
git commit -m "feat: implement payment service core"
```

---

## Task 6: Add HTTP Handlers, Routes, Router Wiring, and Route Metadata

**Files:**
- Create: `admin_back_go/internal/module/payment/handler.go`
- Create: `admin_back_go/internal/module/payment/route.go`
- Create: `admin_back_go/internal/module/payment/handler_test.go`
- Modify: `admin_back_go/internal/server/router.go`
- Modify: `admin_back_go/internal/server/router_test.go`
- Modify: `admin_back_go/internal/bootstrap/app.go`
- Modify: `admin_back_go/internal/bootstrap/route_meta.go`
- Modify: `admin_back_go/internal/bootstrap/route_meta_test.go`

- [ ] **Step 1: Write router tests**

Create `admin_back_go/internal/module/payment/handler_test.go`:

```go
package payment

import (
	"net/http"
	"testing"

	"github.com/gin-gonic/gin"
)

func TestRegisterRoutesIncludesPaymentEndpoints(t *testing.T) {
	gin.SetMode(gin.ReleaseMode)
	router := gin.New()
	RegisterRoutes(router, nilHTTPService{})
	routes := map[string]bool{}
	for _, route := range router.Routes() {
		routes[route.Method+" "+route.Path] = true
	}
	for _, want := range []string{
		http.MethodGet + " /api/admin/v1/payment/channels/page-init",
		http.MethodGet + " /api/admin/v1/payment/channels",
		http.MethodPost + " /api/admin/v1/payment/channels",
		http.MethodPost + " /api/admin/v1/payment/orders",
		http.MethodPost + " /api/admin/v1/payment/orders/:order_no/pay",
		http.MethodGet + " /api/admin/v1/payment/orders/:order_no/result",
		http.MethodPatch + " /api/admin/v1/payment/orders/:order_no/cancel",
		http.MethodGet + " /api/admin/v1/payment/orders/:order_no",
		http.MethodPatch + " /api/admin/v1/payment/orders/:order_no/close",
		http.MethodPost + " /api/payment/notify/alipay",
	} {
		if !routes[want] {
			t.Fatalf("missing route %s in %#v", want, routes)
		}
	}
}
```

Run:

```powershell
go test ./internal/module/payment -run TestRegisterRoutesIncludesPaymentEndpoints
```

Expected: fail because routes are not implemented.

- [ ] **Step 2: Implement routes**

Create `admin_back_go/internal/module/payment/route.go`:

```go
package payment

import "github.com/gin-gonic/gin"

func RegisterRoutes(router *gin.Engine, service HTTPService) {
	handler := NewHandler(service)

	channels := router.Group("/api/admin/v1/payment/channels")
	channels.GET("/page-init", handler.ChannelInit)
	channels.GET("", handler.ListChannels)
	channels.POST("", handler.CreateChannel)
	channels.PUT("/:id", handler.UpdateChannel)
	channels.PATCH("/:id/status", handler.ChangeChannelStatus)
	channels.DELETE("/:id", handler.DeleteChannel)

	orders := router.Group("/api/admin/v1/payment/orders")
	orders.GET("/page-init", handler.OrderInit)
	orders.GET("", handler.ListOrders)
	orders.POST("", handler.CreateOrder)
	orders.GET("/:order_no/result", handler.GetOrderResult)
	orders.POST("/:order_no/pay", handler.PayOrder)
	orders.PATCH("/:order_no/cancel", handler.CancelOrder)
	orders.GET("/:order_no", handler.GetAdminOrder)
	orders.PATCH("/:order_no/close", handler.CloseAdminOrder)

	events := router.Group("/api/admin/v1/payment/events")
	events.GET("", handler.ListEvents)
	events.GET("/:id", handler.GetEvent)

	router.POST("/api/payment/notify/alipay", handler.AlipayNotify)
}
```

Create `admin_back_go/internal/module/payment/handler.go` following existing handler style from `payruntime` and `paychannel`:

```go
package payment

import (
	"context"
	"net/http"
	"strconv"

	"admin_back_go/internal/apperror"
	"admin_back_go/internal/middleware"
	"admin_back_go/internal/response"

	"github.com/gin-gonic/gin"
)

type Handler struct { service HTTPService }
func NewHandler(service HTTPService) *Handler { return &Handler{service: service} }

func (h *Handler) ChannelInit(c *gin.Context) { result, appErr := h.requireService().ChannelInit(c.Request.Context()); writeResult(c, result, appErr) }
func (h *Handler) ListChannels(c *gin.Context) { var req listChannelsRequest; if err := c.ShouldBindQuery(&req); err != nil { response.Error(c, apperror.BadRequest("支付渠道列表参数错误")); return }; result, appErr := h.requireService().ListChannels(c.Request.Context(), ChannelListQuery{CurrentPage: req.CurrentPage, PageSize: req.PageSize, Name: req.Name, Provider: req.Provider, Status: req.Status}); writeResult(c, result, appErr) }
func (h *Handler) CreateChannel(c *gin.Context) { var req channelMutationRequest; if err := c.ShouldBindJSON(&req); err != nil { response.Error(c, apperror.BadRequest("支付渠道参数错误")); return }; id, appErr := h.requireService().CreateChannel(c.Request.Context(), channelInput(req)); if appErr != nil { response.Error(c, appErr); return }; response.OK(c, gin.H{"id": id}) }
func (h *Handler) UpdateChannel(c *gin.Context) { id, ok := routeID(c, "无效的支付渠道ID"); if !ok { return }; var req channelMutationRequest; if err := c.ShouldBindJSON(&req); err != nil { response.Error(c, apperror.BadRequest("支付渠道参数错误")); return }; writeResult(c, gin.H{}, h.requireService().UpdateChannel(c.Request.Context(), id, channelInput(req))) }
func (h *Handler) ChangeChannelStatus(c *gin.Context) { id, ok := routeID(c, "无效的支付渠道ID"); if !ok { return }; var req statusRequest; if err := c.ShouldBindJSON(&req); err != nil { response.Error(c, apperror.BadRequest("支付渠道状态参数错误")); return }; writeResult(c, gin.H{}, h.requireService().ChangeChannelStatus(c.Request.Context(), id, req.Status)) }
func (h *Handler) DeleteChannel(c *gin.Context) { id, ok := routeID(c, "无效的支付渠道ID"); if !ok { return }; writeResult(c, gin.H{}, h.requireService().DeleteChannel(c.Request.Context(), id)) }
func (h *Handler) OrderInit(c *gin.Context) { result, appErr := h.requireService().OrderInit(c.Request.Context()); writeResult(c, result, appErr) }
func (h *Handler) ListOrders(c *gin.Context) { var req orderListRequest; if err := c.ShouldBindQuery(&req); err != nil { response.Error(c, apperror.BadRequest("支付订单列表参数错误")); return }; result, appErr := h.requireService().ListOrders(c.Request.Context(), OrderListQuery{CurrentPage: req.CurrentPage, PageSize: req.PageSize, OrderNo: req.OrderNo, UserID: req.UserID, Status: req.Status, StartDate: req.StartDate, EndDate: req.EndDate}); writeResult(c, result, appErr) }
func (h *Handler) CreateOrder(c *gin.Context) { identity := middleware.GetAuthIdentity(c); if identity == nil || identity.UserID <= 0 { response.Error(c, apperror.Unauthorized("未登录")); return }; var req createOrderRequest; if err := c.ShouldBindJSON(&req); err != nil { response.Error(c, apperror.BadRequest("支付订单参数错误")); return }; result, appErr := h.requireService().CreateOrder(c.Request.Context(), CreateOrderInput{UserID: identity.UserID, ChannelID: req.ChannelID, PayMethod: req.PayMethod, Subject: req.Subject, AmountCents: req.AmountCents, ReturnURL: req.ReturnURL, BusinessType: req.BusinessType, BusinessRef: req.BusinessRef, ClientIP: c.ClientIP()}); writeResult(c, result, appErr) }
func (h *Handler) PayOrder(c *gin.Context) { identity := middleware.GetAuthIdentity(c); if identity == nil || identity.UserID <= 0 { response.Error(c, apperror.Unauthorized("未登录")); return }; var req payOrderRequest; if err := c.ShouldBindJSON(&req); err != nil { response.Error(c, apperror.BadRequest("支付参数错误")); return }; result, appErr := h.requireService().PayOrder(c.Request.Context(), identity.UserID, c.Param("order_no"), req.ReturnURL); writeResult(c, result, appErr) }
func (h *Handler) GetOrderResult(c *gin.Context) { identity := middleware.GetAuthIdentity(c); if identity == nil || identity.UserID <= 0 { response.Error(c, apperror.Unauthorized("未登录")); return }; result, appErr := h.requireService().GetOrderResult(c.Request.Context(), identity.UserID, c.Param("order_no")); writeResult(c, result, appErr) }
func (h *Handler) CancelOrder(c *gin.Context) { identity := middleware.GetAuthIdentity(c); if identity == nil || identity.UserID <= 0 { response.Error(c, apperror.Unauthorized("未登录")); return }; writeResult(c, gin.H{}, h.requireService().CancelOrder(c.Request.Context(), identity.UserID, c.Param("order_no"))) }
func (h *Handler) GetAdminOrder(c *gin.Context) { result, appErr := h.requireService().GetAdminOrder(c.Request.Context(), c.Param("order_no")); writeResult(c, result, appErr) }
func (h *Handler) CloseAdminOrder(c *gin.Context) { writeResult(c, gin.H{}, h.requireService().CloseAdminOrder(c.Request.Context(), c.Param("order_no"))) }
func (h *Handler) ListEvents(c *gin.Context) { var req eventListRequest; if err := c.ShouldBindQuery(&req); err != nil { response.Error(c, apperror.BadRequest("支付事件列表参数错误")); return }; result, appErr := h.requireService().ListEvents(c.Request.Context(), EventListQuery{CurrentPage: req.CurrentPage, PageSize: req.PageSize, OrderNo: req.OrderNo, OutTradeNo: req.OutTradeNo, EventType: req.EventType, ProcessStatus: req.ProcessStatus}); writeResult(c, result, appErr) }
func (h *Handler) GetEvent(c *gin.Context) { id, ok := routeID(c, "无效的支付事件ID"); if !ok { return }; result, appErr := h.requireService().GetEvent(c.Request.Context(), id); writeResult(c, result, appErr) }
func (h *Handler) AlipayNotify(c *gin.Context) { _ = c.Request.ParseForm(); form := map[string]string{}; for key, values := range c.Request.PostForm { if len(values) > 0 { form[key] = values[0] } }; body, _ := h.requireService().HandleAlipayNotify(c.Request.Context(), NotifyInput{Form: form, IP: c.ClientIP()}); c.Data(http.StatusOK, "text/plain; charset=utf-8", []byte(body)) }

func (h *Handler) requireService() HTTPService { if h == nil || h.service == nil { return nilHTTPService{} }; return h.service }
func writeResult(c *gin.Context, result any, appErr *apperror.Error) { if appErr != nil { response.Error(c, appErr); return }; response.OK(c, result) }
func routeID(c *gin.Context, msg string) (int64, bool) { id, err := strconv.ParseInt(c.Param("id"), 10, 64); if err != nil || id <= 0 { response.Error(c, apperror.BadRequest(msg)); return 0, false }; return id, true }
func channelInput(req channelMutationRequest) ChannelMutationInput { return ChannelMutationInput{Code: req.Code, Name: req.Name, Provider: req.Provider, SupportedMethods: req.SupportedMethods, AppID: req.AppID, MerchantID: req.MerchantID, NotifyURL: req.NotifyURL, ReturnURL: req.ReturnURL, PrivateKey: req.PrivateKey, AppCertPath: req.AppCertPath, AlipayCertPath: req.AlipayCertPath, AlipayRootCertPath: req.AlipayRootCertPath, IsSandbox: req.IsSandbox, Status: req.Status, Remark: req.Remark} }

type nilHTTPService struct{}
func (nilHTTPService) ChannelInit(ctx context.Context) (*ChannelInitResponse, *apperror.Error) { return nil, apperror.Internal("支付服务未配置") }
func (nilHTTPService) ListChannels(ctx context.Context, query ChannelListQuery) (*ChannelListResponse, *apperror.Error) { return nil, apperror.Internal("支付服务未配置") }
func (nilHTTPService) CreateChannel(ctx context.Context, input ChannelMutationInput) (int64, *apperror.Error) { return 0, apperror.Internal("支付服务未配置") }
func (nilHTTPService) UpdateChannel(ctx context.Context, id int64, input ChannelMutationInput) *apperror.Error { return apperror.Internal("支付服务未配置") }
func (nilHTTPService) ChangeChannelStatus(ctx context.Context, id int64, status int) *apperror.Error { return apperror.Internal("支付服务未配置") }
func (nilHTTPService) DeleteChannel(ctx context.Context, id int64) *apperror.Error { return apperror.Internal("支付服务未配置") }
func (nilHTTPService) OrderInit(ctx context.Context) (*ChannelInitResponse, *apperror.Error) { return nil, apperror.Internal("支付服务未配置") }
func (nilHTTPService) ListOrders(ctx context.Context, query OrderListQuery) (*OrderListResponse, *apperror.Error) { return nil, apperror.Internal("支付服务未配置") }
func (nilHTTPService) GetAdminOrder(ctx context.Context, orderNo string) (*OrderDetailResponse, *apperror.Error) { return nil, apperror.Internal("支付服务未配置") }
func (nilHTTPService) GetOrderResult(ctx context.Context, userID int64, orderNo string) (*ResultResponse, *apperror.Error) { return nil, apperror.Internal("支付服务未配置") }
func (nilHTTPService) CreateOrder(ctx context.Context, input CreateOrderInput) (*CreateOrderResponse, *apperror.Error) { return nil, apperror.Internal("支付服务未配置") }
func (nilHTTPService) PayOrder(ctx context.Context, userID int64, orderNo string, returnURL string) (*PayOrderResponse, *apperror.Error) { return nil, apperror.Internal("支付服务未配置") }
func (nilHTTPService) CancelOrder(ctx context.Context, userID int64, orderNo string) *apperror.Error { return apperror.Internal("支付服务未配置") }
func (nilHTTPService) CloseAdminOrder(ctx context.Context, orderNo string) *apperror.Error { return apperror.Internal("支付服务未配置") }
func (nilHTTPService) ListEvents(ctx context.Context, query EventListQuery) (*EventListResponse, *apperror.Error) { return nil, apperror.Internal("支付服务未配置") }
func (nilHTTPService) GetEvent(ctx context.Context, id int64) (*EventDetailResponse, *apperror.Error) { return nil, apperror.Internal("支付服务未配置") }
func (nilHTTPService) HandleAlipayNotify(ctx context.Context, input NotifyInput) (string, *apperror.Error) { return "fail", apperror.Internal("支付服务未配置") }
```

- [ ] **Step 3: Wire router and bootstrap**

Modify `admin_back_go/internal/server/router.go`:

```go
import "admin_back_go/internal/module/payment"
```

Add field:

```go
PaymentService payment.HTTPService
```

Replace old payment route registrations:

```go
payment.RegisterRoutes(router, deps.PaymentService)
```

Remove imports and fields for old `paychannel`, `paynotifylog`, `payorder`, `payreconcile`, `payruntime`, `paytransaction`, and `wallet` after Task 8 deletes old modules.

Modify `admin_back_go/internal/bootstrap/app.go`. Keep `admin_back_go/internal/platform/payment` reserved for `payment.CertPathResolver`; import the new module as `paymentmodule`:

```go
import paymentmodule "admin_back_go/internal/module/payment"
```

Then wire the service:

```go
var paymentNumberGenerator paymentmodule.NumberGenerator
if resources.Redis != nil && resources.Redis.Redis != nil {
	paymentNumberGenerator = paymentmodule.NewRedisNumberGeneratorFromRedis(resources.Redis.Redis)
}
paymentService := paymentmodule.NewService(paymentmodule.Dependencies{
	Repository:      paymentmodule.NewGormRepository(resources.DB),
	Gateway:         payalipay.NewPlatformGateway(alipayGateway),
	Secretbox:       secretBox,
	CertResolver:    paymentCertResolver,
	NumberGenerator: paymentNumberGenerator,
})
```

Use the `PlatformGateway` adapter from Task 3. Do not pass `GopayGateway` directly to `paymentmodule.NewService`.

- [ ] **Step 4: Replace permission and operation route metadata**

In `admin_back_go/internal/bootstrap/route_meta.go`, remove old pay/wallet keys and add:

```go
middleware.NewRouteKey(http.MethodPost, "/api/admin/v1/payment/channels"):             "payment_channel_add",
middleware.NewRouteKey(http.MethodPut, "/api/admin/v1/payment/channels/:id"):          "payment_channel_edit",
middleware.NewRouteKey(http.MethodPatch, "/api/admin/v1/payment/channels/:id/status"): "payment_channel_status",
middleware.NewRouteKey(http.MethodDelete, "/api/admin/v1/payment/channels/:id"):       "payment_channel_del",
middleware.NewRouteKey(http.MethodGet, "/api/admin/v1/payment/orders/page-init"):      "payment_order_list",
middleware.NewRouteKey(http.MethodGet, "/api/admin/v1/payment/orders"):                "payment_order_list",
middleware.NewRouteKey(http.MethodGet, "/api/admin/v1/payment/orders/:order_no"):         "payment_order_list",
middleware.NewRouteKey(http.MethodPatch, "/api/admin/v1/payment/orders/:order_no/close"): "payment_order_close",
middleware.NewRouteKey(http.MethodGet, "/api/admin/v1/payment/events"):                "payment_event_list",
middleware.NewRouteKey(http.MethodGet, "/api/admin/v1/payment/events/:id"):            "payment_event_list",
```

Operation rules:

```go
middleware.NewRouteKey(http.MethodPost, "/api/admin/v1/payment/channels"): {Module: "payment_channel", Action: "create", Title: "新增支付渠道"},
middleware.NewRouteKey(http.MethodPut, "/api/admin/v1/payment/channels/:id"): {Module: "payment_channel", Action: "update", Title: "编辑支付渠道"},
middleware.NewRouteKey(http.MethodPatch, "/api/admin/v1/payment/channels/:id/status"): {Module: "payment_channel", Action: "change_status", Title: "切换支付渠道状态"},
middleware.NewRouteKey(http.MethodDelete, "/api/admin/v1/payment/channels/:id"): {Module: "payment_channel", Action: "delete", Title: "删除支付渠道"},
middleware.NewRouteKey(http.MethodPatch, "/api/admin/v1/payment/orders/:order_no/close"): {Module: "payment_order", Action: "close", Title: "关闭支付订单"},
```

- [ ] **Step 5: Run router tests**

```powershell
go test ./internal/module/payment ./internal/server ./internal/bootstrap
```

Expected: pass after updating route tests for new paths and removing old expectations.

- [ ] **Step 6: Commit**

```powershell
git add admin_back_go/internal/module/payment/handler.go admin_back_go/internal/module/payment/route.go admin_back_go/internal/module/payment/handler_test.go admin_back_go/internal/server/router.go admin_back_go/internal/server/router_test.go admin_back_go/internal/bootstrap/app.go admin_back_go/internal/bootstrap/route_meta.go admin_back_go/internal/bootstrap/route_meta_test.go
git commit -m "feat: expose payment REST routes"
```

---

## Task 7: Add Payment Cron Tasks and Registry

**Files:**
- Create: `admin_back_go/internal/module/payment/jobs.go`
- Create: `admin_back_go/internal/module/payment/jobs_test.go`
- Modify: `admin_back_go/internal/module/crontask/registry.go`
- Modify: `admin_back_go/internal/module/crontask/registry_test.go`
- Modify: `admin_back_go/internal/bootstrap/worker.go`

- [ ] **Step 1: Write job tests**

Create `admin_back_go/internal/module/payment/jobs_test.go`:

```go
package payment

import "testing"

func TestPaymentTaskTypes(t *testing.T) {
	closeTask, err := NewCloseExpiredOrderTask(CloseExpiredPayload{Limit: 50})
	if err != nil {
		t.Fatalf("NewCloseExpiredOrderTask: %v", err)
	}
	if closeTask.Type != TypeCloseExpiredOrderV1 {
		t.Fatalf("unexpected close task type %s", closeTask.Type)
	}
	syncTask, err := NewSyncPendingOrderTask(SyncPendingPayload{Limit: 100})
	if err != nil {
		t.Fatalf("NewSyncPendingOrderTask: %v", err)
	}
	if syncTask.Type != TypeSyncPendingOrderV1 {
		t.Fatalf("unexpected sync task type %s", syncTask.Type)
	}
}
```

Run:

```powershell
go test ./internal/module/payment -run TestPaymentTaskTypes
```

Expected: fail because jobs do not exist.

- [ ] **Step 2: Implement jobs**

Create `admin_back_go/internal/module/payment/jobs.go`:

```go
package payment

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"time"

	"admin_back_go/internal/platform/taskqueue"
)

const (
	TypeCloseExpiredOrderV1 = "payment:close-expired-order:v1"
	TypeSyncPendingOrderV1  = "payment:sync-pending-order:v1"
)

type CloseExpiredPayload struct { Limit int `json:"limit,omitempty"` }
type SyncPendingPayload struct { Limit int `json:"limit,omitempty"` }

type JobService interface {
	CloseExpiredOrders(ctx context.Context, input CloseExpiredInput) (*JobResult, error)
	SyncPendingOrders(ctx context.Context, input SyncPendingInput) (*JobResult, error)
}

func NewCloseExpiredOrderTask(payload CloseExpiredPayload) (taskqueue.Task, error) {
	data, err := json.Marshal(payload)
	if err != nil { return taskqueue.Task{}, fmt.Errorf("encode %s payload: %w", TypeCloseExpiredOrderV1, err) }
	return taskqueue.Task{Type: TypeCloseExpiredOrderV1, Payload: data, Queue: taskqueue.QueueDefault, UniqueTTL: 55 * time.Second}, nil
}

func NewSyncPendingOrderTask(payload SyncPendingPayload) (taskqueue.Task, error) {
	data, err := json.Marshal(payload)
	if err != nil { return taskqueue.Task{}, fmt.Errorf("encode %s payload: %w", TypeSyncPendingOrderV1, err) }
	return taskqueue.Task{Type: TypeSyncPendingOrderV1, Payload: data, Queue: taskqueue.QueueDefault, UniqueTTL: 4*time.Minute + 55*time.Second}, nil
}

func RegisterHandlers(mux *taskqueue.Mux, service JobService, logger *slog.Logger) {
	if mux == nil { return }
	if logger == nil { logger = slog.Default() }
	mux.HandleFunc(TypeCloseExpiredOrderV1, func(ctx context.Context, task taskqueue.Task) error {
		var payload CloseExpiredPayload
		if len(task.Payload) > 0 {
			if err := json.Unmarshal(task.Payload, &payload); err != nil { return fmt.Errorf("decode %s payload: %w", TypeCloseExpiredOrderV1, err) }
		}
		result, err := service.CloseExpiredOrders(ctx, CloseExpiredInput{Limit: payload.Limit})
		if err != nil { return err }
		logger.InfoContext(ctx, "processed payment close expired order task", "scanned", result.Scanned, "closed", result.Closed, "paid", result.Paid, "deferred", result.Deferred, "skipped", result.Skipped)
		return nil
	})
	mux.HandleFunc(TypeSyncPendingOrderV1, func(ctx context.Context, task taskqueue.Task) error {
		var payload SyncPendingPayload
		if len(task.Payload) > 0 {
			if err := json.Unmarshal(task.Payload, &payload); err != nil { return fmt.Errorf("decode %s payload: %w", TypeSyncPendingOrderV1, err) }
		}
		result, err := service.SyncPendingOrders(ctx, SyncPendingInput{Limit: payload.Limit})
		if err != nil { return err }
		logger.InfoContext(ctx, "processed payment sync pending order task", "scanned", result.Scanned, "closed", result.Closed, "paid", result.Paid, "deferred", result.Deferred, "skipped", result.Skipped)
		return nil
	})
}
```

- [ ] **Step 3: Replace cron registry entries**

Modify `admin_back_go/internal/module/crontask/registry.go`:

```go
import "admin_back_go/internal/module/payment"
```

Remove `payruntime` and `payreconcile` payment registry imports and old entries. Register:

```go
registry.Register(RegistryEntry{
	Name:        "payment_close_expired_order",
	TaskType:    payment.TypeCloseExpiredOrderV1,
	Description: "扫描过期支付宝支付订单并关闭或补记成功",
	BuildTask: func() (taskqueue.Task, error) {
		return payment.NewCloseExpiredOrderTask(payment.CloseExpiredPayload{})
	},
})
registry.Register(RegistryEntry{
	Name:        "payment_sync_pending_order",
	TaskType:    payment.TypeSyncPendingOrderV1,
	Description: "扫描支付中订单，主动查单并补偿支付成功",
	BuildTask: func() (taskqueue.Task, error) {
		return payment.NewSyncPendingOrderTask(payment.SyncPendingPayload{})
	},
})
```

Update `registry_test.go` to assert the two new names exist and old `pay_*` names do not.

- [ ] **Step 4: Wire worker**

Modify `admin_back_go/internal/bootstrap/worker.go` to import `paymentmodule "admin_back_go/internal/module/payment"`, create the same `paymentService` dependencies as app bootstrap, and call:

```go
paymentmodule.RegisterHandlers(mux, paymentService, logger)
```

Remove old `payruntime.RegisterHandlers` and `payreconcile.RegisterHandlers` after old modules are deleted.

- [ ] **Step 5: Run cron tests**

```powershell
go test ./internal/module/payment ./internal/module/crontask ./internal/bootstrap
```

Expected: pass.

- [ ] **Step 6: Commit**

```powershell
git add admin_back_go/internal/module/payment/jobs.go admin_back_go/internal/module/payment/jobs_test.go admin_back_go/internal/module/crontask/registry.go admin_back_go/internal/module/crontask/registry_test.go admin_back_go/internal/bootstrap/worker.go
git commit -m "feat: register payment cron tasks"
```

---

## Task 8: Remove Old Backend Payment and Wallet Modules

**Files:**
- Delete old backend module directories listed in File Map
- Modify imports in `admin_back_go/internal/server/router.go`, `admin_back_go/internal/bootstrap/app.go`, `admin_back_go/internal/bootstrap/worker.go`, and any compile fallout

- [ ] **Step 1: Delete old directories**

Run PowerShell:

```powershell
cd E:\admin_go
Remove-Item -LiteralPath `
  'admin_back_go\internal\module\paychannel',`
  'admin_back_go\internal\module\paynotifylog',`
  'admin_back_go\internal\module\payorder',`
  'admin_back_go\internal\module\payreconcile',`
  'admin_back_go\internal\module\payruntime',`
  'admin_back_go\internal\module\paytransaction',`
  'admin_back_go\internal\module\wallet' `
  -Recurse -Force
```

- [ ] **Step 2: Verify no old backend imports**

Run:

```powershell
rg 'module/(paychannel|paynotifylog|payorder|payreconcile|payruntime|paytransaction|wallet)|payruntime\.|payreconcile\.' admin_back_go/internal
```

Expected: no matches.

- [ ] **Step 3: Run backend compile tests**

```powershell
cd E:\admin_go\admin_back_go
go test ./...
```

Expected: pass. Fix compile fallout by replacing old payment references with `module/payment` or removing obsolete tests.

- [ ] **Step 4: Commit**

```powershell
git add -A admin_back_go/internal
git commit -m "refactor: remove legacy pay wallet backend modules"
```

---

## Task 9: Add Frontend Payment API Clients and Contract Tests

**Files:**
- Create: `admin_front_ts/src/api/payment/channel.ts`
- Create: `admin_front_ts/src/api/payment/order.ts`
- Create: `admin_front_ts/src/api/payment/event.ts`
- Create: `admin_front_ts/tests/shared/payment/payment-channel-api.test.ts`
- Create: `admin_front_ts/tests/shared/payment/payment-order-api.test.ts`
- Create: `admin_front_ts/tests/shared/payment/payment-event-api.test.ts`

- [ ] **Step 1: Write frontend API contract tests**

Create `admin_front_ts/tests/shared/payment/payment-channel-api.test.ts`:

```ts
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { describe, expect, it } from 'vitest'

const read = (path: string) => readFileSync(resolve(process.cwd(), path), 'utf8')
const forbiddenLooseTypePattern = new RegExp(`\\b${'an'}${'y'}\\b|as ${'an'}${'y'}|Record<string, ${'an'}${'y'}>`)

describe('payment channel api', () => {
  it('uses new payment REST paths and strict types', () => {
    const source = read('src/api/payment/channel.ts')
    expect(source).toContain('request.get<PaymentChannelInitResponse>(`${ADMIN_API_PREFIX}/payment/channels/page-init`)')
    expect(source).toContain('request.post<PaymentChannelCreateResponse, PaymentChannelMutationPayload>(`${ADMIN_API_PREFIX}/payment/channels`')
    expect(source).not.toContain('/pay-channels')
    expect(source).not.toContain('legacy' + 'Request')
    expect(source).not.toMatch(forbiddenLooseTypePattern)
  })
})
```

Create `admin_front_ts/tests/shared/payment/payment-order-api.test.ts`:

```ts
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { describe, expect, it } from 'vitest'

const read = (path: string) => readFileSync(resolve(process.cwd(), path), 'utf8')
const forbiddenLooseTypePattern = new RegExp(`\\b${'an'}${'y'}\\b|as ${'an'}${'y'}|Record<string, ${'an'}${'y'}>`)

describe('payment order api', () => {
  it('uses new payment order REST paths and no old recharge routes', () => {
    const source = read('src/api/payment/order.ts')
    expect(source).toContain('request.get<PaymentOrderInitResponse>(`${ADMIN_API_PREFIX}/payment/orders/page-init`)')
    expect(source).toContain('request.post<PaymentCreateOrderResponse, PaymentCreateOrderPayload>(`${ADMIN_API_PREFIX}/payment/orders`')
    expect(source).toContain('request.post<PaymentPayOrderResponse, PaymentPayOrderPayload>(`${ADMIN_API_PREFIX}/payment/orders/${byOrderNo(orderNo)}/pay`')
    expect(source).toContain('request.get<PaymentResultResponse>(`${ADMIN_API_PREFIX}/payment/orders/${byOrderNo(orderNo)}/result`)')
    expect(source).toContain('request.patch<void>(`${ADMIN_API_PREFIX}/payment/orders/${byOrderNo(orderNo)}/close`)')
    expect(source).not.toContain('/recharge-orders')
    expect(source).not.toContain('/pay-orders')
    expect(source).not.toContain('/wallet')
    expect(source).not.toContain('legacy' + 'Request')
    expect(source).not.toMatch(forbiddenLooseTypePattern)
  })
})
```

Create `admin_front_ts/tests/shared/payment/payment-event-api.test.ts`:

```ts
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { describe, expect, it } from 'vitest'

const read = (path: string) => readFileSync(resolve(process.cwd(), path), 'utf8')
const forbiddenLooseTypePattern = new RegExp(`\\b${'an'}${'y'}\\b|as ${'an'}${'y'}|Record<string, ${'an'}${'y'}>`)

describe('payment event api', () => {
  it('uses new payment event REST paths and no old notify routes', () => {
    const source = read('src/api/payment/event.ts')
    expect(source).toContain('request.get<PaginatedResponse<PaymentEventListItem>>(`${ADMIN_API_PREFIX}/payment/events`')
    expect(source).not.toContain('/pay-notify-logs')
    expect(source).not.toContain('/pay-transactions')
    expect(source).not.toContain('legacy' + 'Request')
    expect(source).not.toMatch(forbiddenLooseTypePattern)
  })
})
```

Run:

```powershell
cd E:\admin_go\admin_front_ts
npm test -- tests/shared/payment/payment-channel-api.test.ts tests/shared/payment/payment-order-api.test.ts tests/shared/payment/payment-event-api.test.ts
```

Expected: fail because clients do not exist.

- [ ] **Step 2: Implement channel API client**

Create `admin_front_ts/src/api/payment/channel.ts`:

```ts
import request from '@/lib/http'
import { ADMIN_API_PREFIX } from '@/lib/http/api-prefix'
import type { DictOption, PaginatedResponse } from '@/types/common'

export interface PaymentChannelInitResponse {
  dict: {
    provider_arr: DictOption<string>[]
    common_status_arr: DictOption<number>[]
    pay_method_arr: DictOption<string>[]
    yes_no_arr: DictOption<number>[]
  }
}

export interface PaymentChannelListParams {
  current_page: number
  page_size: number
  name?: string
  provider?: string
  status?: number | ''
}

export interface PaymentChannelListItem {
  id: number
  code: string
  name: string
  provider: string
  provider_text: string
  supported_methods: string[]
  supported_methods_text: string
  app_id: string
  merchant_id: string
  notify_url: string
  return_url: string
  private_key_hint: string
  app_cert_path: string
  alipay_cert_path: string
  alipay_root_cert_path: string
  is_sandbox: number
  status: number
  status_text: string
  remark: string
  created_at: string
  updated_at: string
}

export interface PaymentChannelMutationPayload {
  id?: number
  code: string
  name: string
  provider: string
  supported_methods: string[]
  app_id: string
  merchant_id: string
  notify_url: string
  return_url: string
  private_key?: string
  app_cert_path: string
  alipay_cert_path: string
  alipay_root_cert_path: string
  is_sandbox: number
  status: number
  remark: string
}

export interface PaymentChannelCreateResponse { id: number }

function positiveID(value: number): number {
  if (!Number.isInteger(value) || value <= 0) throw new Error('payment channel id must be positive')
  return value
}

export const PaymentChannelApi = {
  init: () => request.get<PaymentChannelInitResponse>(`${ADMIN_API_PREFIX}/payment/channels/page-init`),
  list: (params: PaymentChannelListParams) => request.get<PaginatedResponse<PaymentChannelListItem>>(`${ADMIN_API_PREFIX}/payment/channels`, { params }),
  add: (payload: PaymentChannelMutationPayload) => request.post<PaymentChannelCreateResponse, PaymentChannelMutationPayload>(`${ADMIN_API_PREFIX}/payment/channels`, payload),
  edit: (payload: PaymentChannelMutationPayload) => request.put<void, PaymentChannelMutationPayload>(`${ADMIN_API_PREFIX}/payment/channels/${positiveID(payload.id ?? 0)}`, payload),
  status: (id: number, status: number) => request.patch<void, { status: number }>(`${ADMIN_API_PREFIX}/payment/channels/${positiveID(id)}/status`, { status }),
  del: (id: number) => request.delete<void>(`${ADMIN_API_PREFIX}/payment/channels/${positiveID(id)}`),
}
```

- [ ] **Step 3: Implement order and event clients**

Create `admin_front_ts/src/api/payment/order.ts` with typed methods:

```ts
import request from '@/lib/http'
import { ADMIN_API_PREFIX } from '@/lib/http/api-prefix'
import type { DictOption, PaginatedResponse } from '@/types/common'

export interface PaymentOrderInitResponse {
  dict: {
    provider_arr: DictOption<string>[]
    common_status_arr: DictOption<number>[]
    pay_method_arr: DictOption<string>[]
    yes_no_arr: DictOption<number>[]
  }
}
export interface PaymentOrderListParams { current_page: number; page_size: number; order_no?: string; user_id?: number | ''; status?: number | ''; start_date?: string; end_date?: string }
export interface PaymentOrderListItem { id: number; order_no: string; user_id: number; channel_id: number; provider: string; pay_method: string; subject: string; amount_cents: number; status: number; status_text: string; out_trade_no: string; trade_no: string; paid_at: string; expired_at: string; closed_at: string; created_at: string }
export interface PaymentCreateOrderPayload { channel_id: number; pay_method: string; subject: string; amount_cents: number; return_url?: string; business_type?: string; business_ref?: string }
export interface PaymentCreateOrderResponse { order_no: string; amount_cents: number; expired_at: string }
export interface PaymentPayOrderPayload { return_url?: string }
export interface PaymentPayOrderResponse { order_no: string; out_trade_no: string; pay_method: string; pay_url: string; pay_data: Record<string, unknown> }
export interface PaymentResultResponse { order_no: string; status: number; status_text: string; trade_no: string; paid_at: string }

const byOrderNo = (orderNo: string) => {
  const value = orderNo.trim()
  if (!value) throw new Error('payment order_no is required')
  return encodeURIComponent(value)
}

export const PaymentOrderApi = {
  init: () => request.get<PaymentOrderInitResponse>(`${ADMIN_API_PREFIX}/payment/orders/page-init`),
  list: (params: PaymentOrderListParams) => request.get<PaginatedResponse<PaymentOrderListItem>>(`${ADMIN_API_PREFIX}/payment/orders`, { params }),
  create: (payload: PaymentCreateOrderPayload) => request.post<PaymentCreateOrderResponse, PaymentCreateOrderPayload>(`${ADMIN_API_PREFIX}/payment/orders`, payload),
  pay: (orderNo: string, payload: PaymentPayOrderPayload) => request.post<PaymentPayOrderResponse, PaymentPayOrderPayload>(`${ADMIN_API_PREFIX}/payment/orders/${byOrderNo(orderNo)}/pay`, payload),
  result: (orderNo: string) => request.get<PaymentResultResponse>(`${ADMIN_API_PREFIX}/payment/orders/${byOrderNo(orderNo)}/result`),
  cancel: (orderNo: string) => request.patch<void>(`${ADMIN_API_PREFIX}/payment/orders/${byOrderNo(orderNo)}/cancel`),
  close: (orderNo: string) => request.patch<void>(`${ADMIN_API_PREFIX}/payment/orders/${byOrderNo(orderNo)}/close`),
}
```

Create `admin_front_ts/src/api/payment/event.ts`:

```ts
import request from '@/lib/http'
import { ADMIN_API_PREFIX } from '@/lib/http/api-prefix'
import type { PaginatedResponse } from '@/types/common'

export interface PaymentEventListParams { current_page: number; page_size: number; order_no?: string; out_trade_no?: string; event_type?: string; process_status?: number | '' }
export interface PaymentEventListItem { id: number; order_no: string; out_trade_no: string; event_type: string; event_type_text: string; provider: string; process_status: number; process_status_text: string; error_message: string; created_at: string }

export const PaymentEventApi = {
  list: (params: PaymentEventListParams) => request.get<PaginatedResponse<PaymentEventListItem>>(`${ADMIN_API_PREFIX}/payment/events`, { params }),
}
```

- [ ] **Step 4: Run frontend API tests**

```powershell
npm test -- tests/shared/payment/payment-channel-api.test.ts tests/shared/payment/payment-order-api.test.ts tests/shared/payment/payment-event-api.test.ts
```

Expected: pass.

- [ ] **Step 5: Commit**

```powershell
git add admin_front_ts/src/api/payment admin_front_ts/tests/shared/payment
git commit -m "feat: add payment frontend api clients"
```

---

## Task 10: Add Frontend Payment Views and Remove Old Pay/Wallet UI

**Files:**
- Create new Vue view/composable files listed in File Map
- Delete old frontend pay/wallet files listed in File Map
- Modify route mapping source if static mapping exists
- Modify `admin_front_ts/src/enums/index.ts`

- [ ] **Step 1: Write view source tests**

Create `admin_front_ts/tests/shared/payment/payment-views.test.ts`:

```ts
import { existsSync, readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { describe, expect, it } from 'vitest'

const root = process.cwd()
const read = (path: string) => readFileSync(resolve(root, path), 'utf8')

describe('payment views', () => {
  it('keeps route views thin and uses new api clients', () => {
    for (const path of [
      'src/views/Main/payment/channel/index.vue',
      'src/views/Main/payment/order/index.vue',
      'src/views/Main/payment/event/index.vue',
    ]) {
      expect(existsSync(resolve(root, path))).toBe(true)
      const source = read(path)
      expect(source).toContain('<script setup lang="ts">')
      expect(source).not.toContain('@/api/pay/')
      expect(source).not.toContain('legacy' + 'Request')
    }
  })

  it('removes old wallet and pay views', () => {
    expect(existsSync(resolve(root, 'src/views/Main/wallet/index.vue'))).toBe(false)
    expect(existsSync(resolve(root, 'src/views/Main/pay/order/index.vue'))).toBe(false)
  })
})
```

Run:

```powershell
npm test -- tests/shared/payment/payment-views.test.ts
```

Expected: fail because views are not created/deleted yet.

- [ ] **Step 2: Create channel view**

Create `admin_front_ts/src/views/Main/payment/channel/composables/usePaymentChannelPage.ts`:

```ts
import { computed, onMounted, ref } from 'vue'
import { ElNotification } from 'element-plus'
import { PaymentChannelApi, type PaymentChannelInitResponse, type PaymentChannelListItem, type PaymentChannelListParams } from '@/api/payment/channel'
import { useTable } from '@/components/Table'

export function usePaymentChannelPage() {
  const providerArr = ref<PaymentChannelInitResponse['dict']['provider_arr']>([])
  const statusArr = ref<PaymentChannelInitResponse['dict']['common_status_arr']>([])
  const searchForm = ref<PaymentChannelListParams>({ current_page: 1, page_size: 20, name: '', provider: '', status: '' })
  const table = useTable<PaymentChannelListItem, PaymentChannelListParams>({ api: PaymentChannelApi, searchForm })
  const columns = computed(() => [
    { key: 'name', label: '渠道名称' },
    { key: 'provider_text', label: '服务商' },
    { key: 'supported_methods_text', label: '支付方式' },
    { key: 'app_id', label: 'AppID' },
    { key: 'status_text', label: '状态' },
    { key: 'created_at', label: '创建时间' },
    { key: 'actions', label: '操作', width: 180 },
  ])
  async function init() {
    const res = await PaymentChannelApi.init()
    providerArr.value = res.dict.provider_arr
    statusArr.value = res.dict.common_status_arr
  }
  async function changeStatus(row: PaymentChannelListItem) {
    await PaymentChannelApi.status(row.id, row.status === 1 ? 2 : 1)
    ElNotification.success({ message: '操作成功' })
    await table.refresh()
  }
  onMounted(() => { void init(); void table.getList() })
  return { ...table, columns, providerArr, statusArr, searchForm, changeStatus }
}
```

Create `admin_front_ts/src/views/Main/payment/channel/index.vue`:

```vue
<script setup lang="ts">
import { AppTable } from '@/components/Table'
import { usePaymentChannelPage } from './composables/usePaymentChannelPage'

const { columns, data, loading, page, refresh, onPageChange, changeStatus } = usePaymentChannelPage()
</script>

<template>
  <div class="box">
    <AppTable :columns="columns" :data="data" :loading="loading" :pagination="page" row-key="id" @refresh="refresh" @update:pagination="onPageChange">
      <template #cell-actions="{ row }">
        <el-button type="primary" text @click="changeStatus(row)">切换状态</el-button>
      </template>
    </AppTable>
  </div>
</template>
```

- [ ] **Step 3: Create order and event views**

Create `admin_front_ts/src/views/Main/payment/order/composables/usePaymentOrderPage.ts`:

```ts
import { computed, onMounted, ref } from 'vue'
import { ElNotification } from 'element-plus'
import { PaymentOrderApi, type PaymentOrderListItem, type PaymentOrderListParams } from '@/api/payment/order'
import { useTable } from '@/components/Table'

export function usePaymentOrderPage() {
  const searchForm = ref<PaymentOrderListParams>({ current_page: 1, page_size: 20, order_no: '', user_id: '', status: '' })
  const table = useTable<PaymentOrderListItem, PaymentOrderListParams>({ api: PaymentOrderApi, searchForm })
  const columns = computed(() => [
    { key: 'order_no', label: '支付订单号', width: 210 },
    { key: 'user_id', label: '用户ID', width: 100 },
    { key: 'subject', label: '标题' },
    { key: 'amount_cents', label: '金额(分)', width: 120 },
    { key: 'status_text', label: '状态', width: 120 },
    { key: 'out_trade_no', label: '商户单号', width: 210 },
    { key: 'trade_no', label: '支付宝交易号', width: 210 },
    { key: 'created_at', label: '创建时间', width: 180 },
    { key: 'actions', label: '操作', width: 120 },
  ])
  async function close(row: PaymentOrderListItem) {
    await PaymentOrderApi.close(row.order_no)
    ElNotification.success({ message: '操作成功' })
    await table.refresh()
  }
  onMounted(() => { void table.getList() })
  return { ...table, columns, searchForm, close }
}
```

Create `admin_front_ts/src/views/Main/payment/order/index.vue`:

```vue
<script setup lang="ts">
import { AppTable } from '@/components/Table'
import { usePaymentOrderPage } from './composables/usePaymentOrderPage'

const { columns, data, loading, page, refresh, onPageChange, close } = usePaymentOrderPage()
</script>

<template>
  <div class="box">
    <AppTable :columns="columns" :data="data" :loading="loading" :pagination="page" row-key="id" @refresh="refresh" @update:pagination="onPageChange">
      <template #cell-actions="{ row }">
        <el-button type="danger" text @click="close(row)">关闭</el-button>
      </template>
    </AppTable>
  </div>
</template>
```

Create `admin_front_ts/src/views/Main/payment/event/composables/usePaymentEventPage.ts`:

```ts
import { computed, onMounted, ref } from 'vue'
import { PaymentEventApi, type PaymentEventListItem, type PaymentEventListParams } from '@/api/payment/event'
import { useTable } from '@/components/Table'

export function usePaymentEventPage() {
  const searchForm = ref<PaymentEventListParams>({ current_page: 1, page_size: 20, order_no: '', out_trade_no: '', event_type: '', process_status: '' })
  const table = useTable<PaymentEventListItem, PaymentEventListParams>({ api: PaymentEventApi, searchForm })
  const columns = computed(() => [
    { key: 'order_no', label: '支付订单号', width: 210 },
    { key: 'out_trade_no', label: '商户单号', width: 210 },
    { key: 'event_type_text', label: '事件类型', width: 120 },
    { key: 'provider', label: '服务商', width: 100 },
    { key: 'process_status_text', label: '处理状态', width: 120 },
    { key: 'error_message', label: '错误信息' },
    { key: 'created_at', label: '创建时间', width: 180 },
  ])
  onMounted(() => { void table.getList() })
  return { ...table, columns, searchForm }
}
```

Create `admin_front_ts/src/views/Main/payment/event/index.vue`:

```vue
<script setup lang="ts">
import { AppTable } from '@/components/Table'
import { usePaymentEventPage } from './composables/usePaymentEventPage'

const { columns, data, loading, page, refresh, onPageChange } = usePaymentEventPage()
</script>

<template>
  <div class="box">
    <AppTable :columns="columns" :data="data" :loading="loading" :pagination="page" row-key="id" @refresh="refresh" @update:pagination="onPageChange" />
  </div>
</template>
```

Keep all files `<script setup lang="ts">`, no `any`, no old `@/api/pay` imports.

- [ ] **Step 4: Delete old UI**

Run:

```powershell
cd E:\admin_go
Remove-Item -LiteralPath 'admin_front_ts\src\api\pay','admin_front_ts\src\views\Main\pay','admin_front_ts\src\views\Main\wallet' -Recurse -Force
Remove-Item -LiteralPath 'admin_front_ts\src\views\Main\home\components\HomeWalletPanel.vue' -Force
Remove-Item -LiteralPath 'admin_front_ts\src\enums\PayEnum.ts' -Force
```

Update `admin_front_ts/src/enums/index.ts` to remove exports from `PayEnum`.

- [ ] **Step 5: Verify no old frontend references**

Run:

```powershell
rg '@/api/pay|views/Main/pay|views/Main/wallet|PayEnum|recharge-orders|pay-orders|wallet' admin_front_ts/src admin_front_ts/tests
```

Expected: no matches except text in migration docs if docs are included by mistake; this command scopes to src/tests only.

- [ ] **Step 6: Run frontend tests**

```powershell
npm test -- tests/shared/payment
npm run build:check
```

Expected: pass.

- [ ] **Step 7: Commit**

```powershell
git add -A admin_front_ts/src admin_front_ts/tests/shared/payment
git commit -m "refactor: replace pay wallet frontend with payment views"
```

---

## Task 11: Update Contracts, Status Docs, Architecture Docs, and Smoke

**Files:**
- Modify: `docs/contracts/admin-api-v1.md`
- Modify: `docs/migration/current-status.md`
- Modify: `docs/testing/smoke-matrix.md`
- Modify: `admin_back_go/docs/architecture.md`
- Modify: `admin_back_go/scripts/full-admin-smoke.ps1`

- [ ] **Step 1: Replace old contract sections**

In `docs/contracts/admin-api-v1.md`, remove old sections for:

```text
Pay Channels
Pay Transactions
Pay Notify Logs
Pay Reconcile
Pay Orders
Wallet
Recharge runtime
```

Add a new `## Payment` section documenting:

```text
GET    /api/admin/v1/payment/channels/page-init
GET    /api/admin/v1/payment/channels
POST   /api/admin/v1/payment/channels
PUT    /api/admin/v1/payment/channels/:id
PATCH  /api/admin/v1/payment/channels/:id/status
DELETE /api/admin/v1/payment/channels/:id
GET    /api/admin/v1/payment/orders/page-init
GET    /api/admin/v1/payment/orders
POST   /api/admin/v1/payment/orders
GET    /api/admin/v1/payment/orders/:order_no
GET    /api/admin/v1/payment/orders/:order_no/result
POST   /api/admin/v1/payment/orders/:order_no/pay
PATCH  /api/admin/v1/payment/orders/:order_no/cancel
PATCH  /api/admin/v1/payment/orders/:order_no/close
GET    /api/admin/v1/payment/events
GET    /api/admin/v1/payment/events/:id
POST   /api/payment/notify/alipay
```

State explicitly:

```text
Alipay only.
No wallet/refund/reconcile/WeChat in this phase.
notify returns text/plain success/fail.
private_key_enc never appears in response.
order_no is the order route key; do not expose a second /:id order route that conflicts with Gin wildcard names.
```

- [ ] **Step 2: Update current status**

In `docs/migration/current-status.md`, replace the old pay/wallet rows with one row:

```markdown
| payment domain rebuild | implemented: project-native `internal/module/payment` owns channels/configs/orders/events, Alipay web/H5 create/pay/result/cancel/notify, and `payment:close-expired-order:v1` + `payment:sync-pending-order:v1`; old pay/wallet/reconcile/refund modules are retired | adapted: frontend uses `src/api/payment/*` and `views/Main/payment/*`; old `src/api/pay`, `views/Main/pay`, and `views/Main/wallet` removed | `internal/module/payment`, `internal/platform/payment/alipay`, `internal/module/crontask`, `internal/bootstrap`; frontend payment Vitest/typecheck/build | full smoke covers payment channel/order/event probes and runtime menu no longer exposes old pay/wallet | payment rebuild spec/plan + admin API contract + smoke matrix | Alipay only; no wallet/refund/reconcile/WeChat; `orders/order_items` are not dropped until separately proven payment-only |
```

- [ ] **Step 3: Update smoke script**

In `admin_back_go/scripts/full-admin-smoke.ps1`, replace old payment probes with:

```powershell
Invoke-AdminApi -Method GET -Path '/api/admin/v1/payment/channels/page-init'
Invoke-AdminApi -Method GET -Path '/api/admin/v1/payment/channels?current_page=1&page_size=20'
Invoke-AdminApi -Method GET -Path '/api/admin/v1/payment/orders/page-init'
Invoke-AdminApi -Method GET -Path '/api/admin/v1/payment/orders?current_page=1&page_size=20'
Invoke-AdminApi -Method GET -Path '/api/admin/v1/payment/events?current_page=1&page_size=20'
```

Add a menu assertion that `/pay`, `/wallet`, and codes starting with old `pay_` are absent, while `/payment/channel`, `/payment/order`, and `/payment/event` are present for a role with those grants.

- [ ] **Step 4: Run doc/source guards**

Run:

```powershell
rg '/api/admin/v1/(pay|wallet|recharge-orders)|src/api/pay|views/Main/pay|views/Main/wallet|pay_reconcile|pay_refund|payruntime' docs admin_back_go/docs admin_back_go/scripts admin_front_ts/src admin_front_ts/tests
```

Expected: no active-contract matches. Historical notes inside the new spec/plan are allowed only under `docs/superpowers`.

- [ ] **Step 5: Commit**

```powershell
git add docs/contracts/admin-api-v1.md docs/migration/current-status.md docs/testing/smoke-matrix.md admin_back_go/docs/architecture.md admin_back_go/scripts/full-admin-smoke.ps1
git commit -m "docs: document payment domain rebuild"
```

---

## Task 12: Final Verification

**Files:**
- No new files unless verification exposes a real defect.

- [ ] **Step 1: Backend tests**

```powershell
cd E:\admin_go\admin_back_go
go test ./...
go test -race ./internal/module/payment ./internal/platform/payment/alipay
```

Expected: pass.

- [ ] **Step 2: Frontend tests and build**

```powershell
cd E:\admin_go\admin_front_ts
npm test -- tests/shared/payment
npm run build:check
```

Expected: pass.

- [ ] **Step 3: Payment cert check**

```powershell
cd E:\admin_go\admin_back_go
powershell -ExecutionPolicy Bypass -File .\scripts\check-payment-certs.ps1 -DisallowLegacyRoot
```

Expected: cert paths resolve under `admin_back_go/runtime/cert/alipay`; no private key printed.

- [ ] **Step 4: Contract and smoke**

```powershell
cd E:\admin_go\admin_back_go
powershell -ExecutionPolicy Bypass -File .\scripts\check-contract.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account 15671628271 -Password 123456
```

Expected: contract passes; smoke confirms payment channel/order/event probes and old pay/wallet menu absence.

- [ ] **Step 5: Final grep**

```powershell
cd E:\admin_go
rg 'internal/module/(paychannel|paynotifylog|payorder|payreconcile|payruntime|paytransaction|wallet)|@/api/pay|views/Main/pay|views/Main/wallet|/api/admin/v1/recharge-orders|/api/admin/v1/pay-|/api/admin/v1/wallet' admin_back_go admin_front_ts docs
```

Expected: no active code/docs matches outside `docs/superpowers/specs/2026-05-08-payment-domain-rebuild-design.md` and this plan.

- [ ] **Step 6: Commit verification fixes if any**

If verification required fixes:

```powershell
git add -A
git commit -m "fix: verify payment domain rebuild"
```

If no fixes were needed, do not create an empty commit.

---

## Self-Review

Spec coverage:

```text
Open-source-first and no whole-project import: covered by Master Rules and Task 3.
Four-table payment model: covered by Task 2 and Task 4.
Alipay-only payment flow: covered by Task 3, Task 5, Task 6.
No wallet/refund/reconcile/WeChat: covered by Master Rules, Task 8, Task 11.
RBAC/menu cleanup: covered by Task 2 and Task 6.
Vue Composition API typed clients/views: covered by Task 9 and Task 10.
Cron registry: covered by Task 7.
Docs/smoke: covered by Task 11 and Task 12.
```

Implementation risks to check during execution:

```text
Task 2 migration uses deliberate `RENAME TABLE` for old payment-owned tables; verify those tables exist in the target DB before applying or split the backup step for environments that already pruned them. Task 5 requires Redis-backed `paymentNumberGenerator`; if Redis is unavailable, order creation must fail explicitly instead of generating duplicate time-only order numbers.
```


---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-08-payment-domain-rebuild.md`.

Two execution options:

1. **Subagent-Driven (recommended)** - dispatch a fresh subagent per task, review between tasks, fast iteration.
2. **Inline Execution** - execute tasks in this session using `superpowers:executing-plans`, batch execution with checkpoints.
