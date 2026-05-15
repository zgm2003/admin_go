# Payment Recharge Cashier V1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把当前工程化的“新增支付订单”收口成真正的充值收银台：用户选套餐、支付宝付款、返回充值页、同步充值记录并幂等入账钱包余额。

**Architecture:** 继续使用现有 Go Gin modular monolith，支付域仍归 `admin_back_go/internal/module/payment`，新增充值、套餐、钱包能力用 `recharge_*.go` / `wallet_*.go` / `package_*.go` 文件隔离；`payment_orders` 保持底层支付单，充值单 `payment_recharges` 才是业务单。前端新增 `/payment/recharge`，用 Vue 3 `<script setup lang="ts">`、feature components、composable、`Search`、`AppTable`，不再让用户填写 `config_code`、手写金额或 `return_url`。

**Tech Stack:** Go, Gin, GORM, MySQL/InnoDB, go-pay/gopay v1.5.118, existing RBAC/OperationLog/secretbox/cert resolver, Vue 3 + TypeScript + Element Plus + existing `request` client + Vitest + vue-tsc.

---

## Scope Lock

Spec source:

```text
docs/superpowers/specs/2026-05-15-payment-recharge-cashier-v1-design.md
```

只做：

```text
/payment/recharge 产品页
payment_recharge_* 权限
payment_configs.sort
payment_recharge_packages / payment_recharges / user_wallets / wallet_transactions
充值套餐 seed
创建充值并拉起支付宝
继续支付 / 手动同步 / 关闭未支付充值单
支付宝 paid 后钱包幂等入账
contract/status/smoke/docs sync
```

不做：

```text
退款
提现
分账
微信支付
notify 回调
自动对账
自动关闭/自动同步 cron
订阅权益、会员有效期、赠送天数
充值套餐管理 UI
管理员手工调账
用户消费扣款
多币种
发票
优惠券
```

Linus check:

```text
True problem: yes. 当前支付订单新增弹窗暴露工程字段，用户真实任务是余额充值。
Simpler way: 套餐 -> 后端选支付宝配置 -> payment_order -> payment_recharge -> sync 入账。
What breaks: 不能破坏 /payment/config、payment_configs、payment_orders 底层支付能力、登录/RBAC/OperationLog。
```

---

## Naming Lock

These names are mandatory:

| Layer | Name |
| --- | --- |
| DB tables | `payment_recharge_packages`, `payment_recharges`, `user_wallets`, `wallet_transactions` |
| Existing DB table modified | `payment_configs.sort` |
| Backend module | `admin_back_go/internal/module/payment` |
| Backend recharge files | `recharge_model.go`, `recharge_request.go`, `recharge_dto.go`, `recharge_repository.go`, `recharge_service.go`, `recharge_handler.go` |
| Backend wallet files | `wallet_model.go`, `wallet_repository.go` |
| Backend package file | `package_model.go` |
| API resource | `/api/admin/v1/payment/recharges` |
| Frontend API | `admin_front_ts/src/api/payment/recharges.ts` |
| Frontend page | `admin_front_ts/src/views/Main/payment/recharge` |
| Route path | `/payment/recharge` |
| Permission component | `payment/recharge` |
| Menu i18n | `menu.payment_recharge` |
| Page permission | `payment_recharge_list` |
| Button permissions | `payment_recharge_add`, `payment_recharge_pay`, `payment_recharge_sync`, `payment_recharge_close` |
| OperationLog module | `payment_recharge` |
| CSS block | `.payment-recharge-page` |

These names are forbidden:

```text
/payment/order
component=payment/order
payment_recharge_page
payment_order_create_for_recharge
wallet_pay
pay_recharge_*
recharge_order_*
src/views/Main/payment/order
src/api/payment/recharge.ts
```

---

## File Map

### Create

```text
admin_back_go/database/migrations/20260515_payment_recharge_cashier_v1.sql
admin_back_go/internal/module/payment/package_model.go
admin_back_go/internal/module/payment/wallet_model.go
admin_back_go/internal/module/payment/wallet_repository.go
admin_back_go/internal/module/payment/recharge_model.go
admin_back_go/internal/module/payment/recharge_request.go
admin_back_go/internal/module/payment/recharge_dto.go
admin_back_go/internal/module/payment/recharge_repository.go
admin_back_go/internal/module/payment/recharge_service.go
admin_back_go/internal/module/payment/recharge_handler.go
admin_back_go/internal/module/payment/recharge_service_test.go
admin_front_ts/src/api/payment/recharges.ts
admin_front_ts/src/views/Main/payment/recharge/index.vue
admin_front_ts/src/views/Main/payment/recharge/components/RechargePackageGrid.vue
admin_front_ts/src/views/Main/payment/recharge/components/RechargePaymentMethodCard.vue
admin_front_ts/src/views/Main/payment/recharge/components/RechargeCheckoutPanel.vue
admin_front_ts/src/views/Main/payment/recharge/components/RechargeRecentRecords.vue
admin_front_ts/src/views/Main/payment/recharge/components/RechargeRecordsTable.vue
admin_front_ts/src/views/Main/payment/recharge/composables/usePaymentRechargePage.ts
admin_front_ts/tests/shared/payment/payment-recharge-api.test.ts
admin_front_ts/tests/shared/payment/payment-recharge-page.test.ts
```

### Modify

```text
admin_back_go/internal/module/payment/model.go
admin_back_go/internal/module/payment/request.go
admin_back_go/internal/module/payment/dto.go
admin_back_go/internal/module/payment/repository.go
admin_back_go/internal/module/payment/service.go
admin_back_go/internal/module/payment/route.go
admin_back_go/internal/bootstrap/route_meta.go
admin_back_go/internal/bootstrap/route_meta_test.go
admin_back_go/internal/server/router_test.go
admin_back_go/scripts/full-admin-smoke.ps1
admin_back_go/docs/architecture.md
admin_front_ts/src/api/payment/config.ts
admin_front_ts/src/views/Main/payment/config/composables/usePaymentConfigPage.ts
admin_front_ts/src/views/Main/payment/config/components/PaymentConfigForm.vue
admin_front_ts/src/views/Main/payment/config/index.vue
admin_front_ts/src/i18n/locales/zh-CN.ts
admin_front_ts/src/i18n/locales/en-US.ts
docs/contracts/admin-api-v1.md
docs/status/current-status.md
docs/testing/smoke-matrix.md
```

### Do Not Create

```text
admin_back_go/internal/module/wallet
admin_back_go/internal/module/recharge
admin_front_ts/src/views/Main/payment/order
admin_front_ts/src/api/payment/recharge.ts
admin_back_go/database/migrations/*refund*
admin_back_go/database/migrations/*wechat*
```

---

## Contract Lock

### Recharge API

```text
GET    /api/admin/v1/payment/recharges/page-init
GET    /api/admin/v1/payment/recharges
GET    /api/admin/v1/payment/recharges/:id
POST   /api/admin/v1/payment/recharges
POST   /api/admin/v1/payment/recharges/:id/pay
POST   /api/admin/v1/payment/recharges/:id/sync
PATCH  /api/admin/v1/payment/recharges/:id/close
```

### Recharge states

```text
pending
paying
paid
credited
closed
failed
```

### Frontend create payload must only contain

```ts
{
  package_code: string
  pay_method: 'web' | 'h5'
  return_url: string
}
```

`return_url` is generated by the page code from the current route. It is not an input field.

### Field ban

Do not add these fields to new tables, DTOs, frontend types, or docs for this slice:

```text
refund_amount
refund_status
subscription_days
membership_level
business_type
business_ref
raw_request
raw_response
extra_json
currency
created_by
updated_by
```

---

## Task 1: Schema, Seed Data, Menu, Permission Migration

**Files:**
- Create: `admin_back_go/database/migrations/20260515_payment_recharge_cashier_v1.sql`

- [x] **Step 1: Create the migration with `payment_configs.sort` and new tables**

Create the migration with this structure. If local MySQL rejects `ADD COLUMN IF NOT EXISTS` or `CREATE INDEX IF NOT EXISTS`, replace those two statements with this repository's established idempotent migration style before running live DB:

```sql
ALTER TABLE `payment_configs`
  ADD COLUMN IF NOT EXISTS `sort` INT NOT NULL DEFAULT 100 AFTER `enabled_methods_json`;

CREATE INDEX IF NOT EXISTS `idx_payment_configs_provider_status_sort`
  ON `payment_configs` (`provider`, `status`, `is_del`, `sort`, `id`);

CREATE TABLE IF NOT EXISTS `payment_recharge_packages` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `code` VARCHAR(64) NOT NULL,
  `name` VARCHAR(128) NOT NULL,
  `amount_cents` BIGINT NOT NULL,
  `badge` VARCHAR(32) NOT NULL DEFAULT '',
  `sort` INT NOT NULL DEFAULT 100,
  `status` TINYINT NOT NULL DEFAULT 1,
  `is_del` TINYINT NOT NULL DEFAULT 2,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_payment_recharge_package_code` (`code`),
  KEY `idx_payment_recharge_package_status_sort` (`status`, `is_del`, `sort`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `user_wallets` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `user_id` BIGINT NOT NULL,
  `balance_cents` BIGINT NOT NULL DEFAULT 0,
  `total_recharge_cents` BIGINT NOT NULL DEFAULT 0,
  `is_del` TINYINT NOT NULL DEFAULT 2,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_user_wallet_user` (`user_id`),
  KEY `idx_user_wallet_isdel` (`is_del`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `wallet_transactions` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `transaction_no` VARCHAR(64) NOT NULL,
  `wallet_id` BIGINT NOT NULL,
  `user_id` BIGINT NOT NULL,
  `direction` VARCHAR(16) NOT NULL,
  `amount_cents` BIGINT NOT NULL,
  `balance_before_cents` BIGINT NOT NULL,
  `balance_after_cents` BIGINT NOT NULL,
  `source_type` VARCHAR(32) NOT NULL,
  `source_id` BIGINT NOT NULL,
  `remark` VARCHAR(255) NOT NULL DEFAULT '',
  `is_del` TINYINT NOT NULL DEFAULT 2,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_wallet_transaction_no` (`transaction_no`),
  UNIQUE KEY `uk_wallet_transaction_source` (`source_type`, `source_id`),
  KEY `idx_wallet_transaction_user_created` (`user_id`, `is_del`, `created_at`),
  KEY `idx_wallet_transaction_wallet_created` (`wallet_id`, `is_del`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `payment_recharges` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `recharge_no` VARCHAR(64) NOT NULL,
  `user_id` BIGINT NOT NULL,
  `package_code` VARCHAR(64) NOT NULL,
  `package_name` VARCHAR(128) NOT NULL,
  `amount_cents` BIGINT NOT NULL,
  `payment_order_id` BIGINT NOT NULL,
  `status` VARCHAR(16) NOT NULL,
  `paid_at` DATETIME NULL,
  `credited_at` DATETIME NULL,
  `failure_reason` VARCHAR(255) NOT NULL DEFAULT '',
  `is_del` TINYINT NOT NULL DEFAULT 2,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_payment_recharge_no` (`recharge_no`),
  UNIQUE KEY `uk_payment_recharge_order` (`payment_order_id`),
  KEY `idx_payment_recharge_user_status_created` (`user_id`, `is_del`, `status`, `created_at`),
  KEY `idx_payment_recharge_created` (`is_del`, `created_at`),
  CONSTRAINT `fk_payment_recharge_order`
    FOREIGN KEY (`payment_order_id`) REFERENCES `payment_orders` (`id`)
    ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

- [x] **Step 2: Add seed packages**

Append:

```sql
INSERT INTO `payment_recharge_packages` (`code`, `name`, `amount_cents`, `badge`, `sort`, `status`, `is_del`)
VALUES
  ('recharge_10', '¥10', 1000, '', 10, 1, 2),
  ('recharge_20', '¥20', 2000, '推荐', 20, 1, 2),
  ('recharge_30', '¥30', 3000, '推荐', 30, 1, 2),
  ('recharge_50', '¥50', 5000, '推荐', 40, 1, 2),
  ('recharge_100', '¥100', 10000, '推荐', 50, 1, 2),
  ('recharge_300', '¥300', 30000, '推荐', 60, 1, 2),
  ('recharge_500', '¥500', 50000, '推荐', 70, 1, 2),
  ('recharge_888', '¥888', 88800, '', 80, 1, 2)
ON DUPLICATE KEY UPDATE
  `name` = VALUES(`name`),
  `amount_cents` = VALUES(`amount_cents`),
  `badge` = VALUES(`badge`),
  `sort` = VALUES(`sort`),
  `status` = VALUES(`status`),
  `is_del` = 2,
  `updated_at` = CURRENT_TIMESTAMP;
```

- [x] **Step 3: Add payment recharge menu and button permissions**

Append a permission block equivalent to the existing payment order migration, with:

```text
PAGE   code=payment_recharge_list path=/payment/recharge component=payment/recharge i18n_key=menu.payment_recharge sort=20
BUTTON payment_recharge_add
BUTTON payment_recharge_pay
BUTTON payment_recharge_sync
BUTTON payment_recharge_close
```

Grant these permissions to roles that already have `payment_config_list` or `payment_order_list`.

- [x] **Step 4: Verify migration shape**

Run:

```powershell
cd E:\admin_go\admin_back_go
rg -n "payment_recharge_packages|payment_recharges|user_wallets|wallet_transactions|payment_recharge_list|sort|is_del|created_at|updated_at" database\migrations\20260515_payment_recharge_cashier_v1.sql
```

Expected: output includes all four table names, `payment_recharge_list`, `sort`, and each table has `is_del`, `created_at`, `updated_at`.

---

## Task 2: Backend Models and DTO Contract

**Files:**
- Modify: `admin_back_go/internal/module/payment/model.go`
- Modify: `admin_back_go/internal/module/payment/request.go`
- Modify: `admin_back_go/internal/module/payment/dto.go`
- Create: `admin_back_go/internal/module/payment/package_model.go`
- Create: `admin_back_go/internal/module/payment/wallet_model.go`
- Create: `admin_back_go/internal/module/payment/recharge_model.go`
- Create: `admin_back_go/internal/module/payment/recharge_request.go`
- Create: `admin_back_go/internal/module/payment/recharge_dto.go`

- [x] **Step 1: Add `sort` to payment config model and DTOs**

Add to `Config` in `model.go`:

```go
Sort int `gorm:"column:sort"`
```

Add to `ConfigListItem`:

```go
Sort int `json:"sort"`
```

Add to `ConfigMutationInput`:

```go
Sort int
```

Add to `configMutationRequest`:

```go
Sort int `json:"sort" binding:"omitempty,min=1,max=9999"`
```

- [x] **Step 2: Create package model**

Create `package_model.go`:

```go
package payment

import "time"

type RechargePackage struct {
	ID          int64     `gorm:"column:id;primaryKey"`
	Code        string    `gorm:"column:code"`
	Name        string    `gorm:"column:name"`
	AmountCents int64     `gorm:"column:amount_cents"`
	Badge       string    `gorm:"column:badge"`
	Sort        int       `gorm:"column:sort"`
	Status      int       `gorm:"column:status"`
	IsDel       int       `gorm:"column:is_del"`
	CreatedAt   time.Time `gorm:"column:created_at"`
	UpdatedAt   time.Time `gorm:"column:updated_at"`
}

func (RechargePackage) TableName() string { return "payment_recharge_packages" }
```

- [x] **Step 3: Create wallet models**

Create `wallet_model.go`:

```go
package payment

import "time"

type Wallet struct {
	ID                 int64     `gorm:"column:id;primaryKey"`
	UserID             int64     `gorm:"column:user_id"`
	BalanceCents       int64     `gorm:"column:balance_cents"`
	TotalRechargeCents int64     `gorm:"column:total_recharge_cents"`
	IsDel              int       `gorm:"column:is_del"`
	CreatedAt          time.Time `gorm:"column:created_at"`
	UpdatedAt          time.Time `gorm:"column:updated_at"`
}

func (Wallet) TableName() string { return "user_wallets" }

type WalletTransaction struct {
	ID                 int64     `gorm:"column:id;primaryKey"`
	TransactionNo      string    `gorm:"column:transaction_no"`
	WalletID           int64     `gorm:"column:wallet_id"`
	UserID             int64     `gorm:"column:user_id"`
	Direction          string    `gorm:"column:direction"`
	AmountCents        int64     `gorm:"column:amount_cents"`
	BalanceBeforeCents int64     `gorm:"column:balance_before_cents"`
	BalanceAfterCents  int64     `gorm:"column:balance_after_cents"`
	SourceType         string    `gorm:"column:source_type"`
	SourceID           int64     `gorm:"column:source_id"`
	Remark             string    `gorm:"column:remark"`
	IsDel              int       `gorm:"column:is_del"`
	CreatedAt          time.Time `gorm:"column:created_at"`
	UpdatedAt          time.Time `gorm:"column:updated_at"`
}

func (WalletTransaction) TableName() string { return "wallet_transactions" }
```

- [x] **Step 4: Create recharge model**

Create `recharge_model.go`:

```go
package payment

import "time"

type Recharge struct {
	ID             int64      `gorm:"column:id;primaryKey"`
	RechargeNo     string     `gorm:"column:recharge_no"`
	UserID         int64      `gorm:"column:user_id"`
	PackageCode    string     `gorm:"column:package_code"`
	PackageName    string     `gorm:"column:package_name"`
	AmountCents    int64      `gorm:"column:amount_cents"`
	PaymentOrderID int64      `gorm:"column:payment_order_id"`
	Status         string     `gorm:"column:status"`
	PaidAt         *time.Time `gorm:"column:paid_at"`
	CreditedAt     *time.Time `gorm:"column:credited_at"`
	FailureReason  string     `gorm:"column:failure_reason"`
	IsDel          int        `gorm:"column:is_del"`
	CreatedAt      time.Time  `gorm:"column:created_at"`
	UpdatedAt      time.Time  `gorm:"column:updated_at"`
}

func (Recharge) TableName() string { return "payment_recharges" }

type RechargeWithOrder struct {
	Recharge
	PaymentOrderNo string     `gorm:"column:payment_order_no"`
	PayURL         string     `gorm:"column:pay_url"`
	PayMethod      string     `gorm:"column:pay_method"`
	OrderStatus    string     `gorm:"column:order_status"`
	AlipayTradeNo  string     `gorm:"column:alipay_trade_no"`
	OrderPaidAt    *time.Time `gorm:"column:order_paid_at"`
	OrderClosedAt  *time.Time `gorm:"column:order_closed_at"`
}
```

- [x] **Step 5: Create request DTOs**

Create `recharge_request.go`:

```go
package payment

type listRechargesRequest struct {
	CurrentPage int    `form:"current_page" binding:"omitempty,min=1"`
	PageSize    int    `form:"page_size" binding:"omitempty,min=1,max=100"`
	Keyword     string `form:"keyword" binding:"omitempty,max=128"`
	Status      string `form:"status" binding:"omitempty,oneof=pending paying paid credited closed failed"`
	DateStart   string `form:"date_start" binding:"omitempty,max=32"`
	DateEnd     string `form:"date_end" binding:"omitempty,max=32"`
}

type createRechargeRequest struct {
	PackageCode string `json:"package_code" binding:"required,max=64"`
	PayMethod   string `json:"pay_method" binding:"required,oneof=web h5"`
	ReturnURL   string `json:"return_url" binding:"required,max=512"`
}
```

- [x] **Step 6: Create response DTOs and HTTPService additions**

Create `recharge_dto.go` with:

```go
package payment

import "admin_back_go/internal/dict"

const (
	rechargeStatusPending  = "pending"
	rechargeStatusPaying   = "paying"
	rechargeStatusPaid     = "paid"
	rechargeStatusCredited = "credited"
	rechargeStatusClosed   = "closed"
	rechargeStatusFailed   = "failed"

	walletDirectionIn    = "in"
	walletSourceRecharge = "recharge"
)

type RechargeInitResponse struct {
	Wallet        WalletSummary         `json:"wallet"`
	Packages      []RechargePackageItem `json:"packages"`
	PaymentMethod RechargePaymentMethod `json:"payment_method"`
	Dict          RechargeInitDict      `json:"dict"`
	Recent        []RechargeListItem    `json:"recent"`
}

type RechargeInitDict struct {
	StatusArr []dict.Option[string] `json:"status_arr"`
}

type WalletSummary struct {
	BalanceCents       int64  `json:"balance_cents"`
	BalanceText        string `json:"balance_text"`
	TotalRechargeCents int64  `json:"total_recharge_cents"`
	TotalRechargeText  string `json:"total_recharge_text"`
}

type RechargePackageItem struct {
	Code        string `json:"code"`
	Name        string `json:"name"`
	AmountCents int64  `json:"amount_cents"`
	AmountText  string `json:"amount_text"`
	Badge       string `json:"badge"`
}

type RechargePaymentMethod struct {
	Provider string `json:"provider"`
	Label    string `json:"label"`
	Enabled  bool   `json:"enabled"`
}

type RechargeListQuery struct {
	CurrentPage int
	PageSize    int
	UserID      int64
	Keyword     string
	Status      string
	DateStart   string
	DateEnd     string
}

type RechargeCreateInput struct {
	UserID      int64
	PackageCode string
	PayMethod   string
	ReturnURL   string
}

type RechargeListResponse struct {
	List []RechargeListItem `json:"list"`
	Page Page               `json:"page"`
}

type RechargeListItem struct {
	ID             int64  `json:"id"`
	RechargeNo     string `json:"recharge_no"`
	PaymentOrderNo string `json:"payment_order_no"`
	PackageCode    string `json:"package_code"`
	PackageName    string `json:"package_name"`
	AmountCents    int64  `json:"amount_cents"`
	AmountText     string `json:"amount_text"`
	Status         string `json:"status"`
	StatusText     string `json:"status_text"`
	PayURL         string `json:"pay_url"`
	PaidAt         string `json:"paid_at"`
	CreditedAt     string `json:"credited_at"`
	CreatedAt      string `json:"created_at"`
	UpdatedAt      string `json:"updated_at"`
}

type RechargeDetail struct {
	RechargeListItem
	FailureReason string `json:"failure_reason"`
	AlipayTradeNo string `json:"alipay_trade_no"`
}

type RechargePayResponse struct {
	ID             int64  `json:"id"`
	RechargeNo     string `json:"recharge_no"`
	PaymentOrderNo string `json:"payment_order_no"`
	Status         string `json:"status"`
	PayURL         string `json:"pay_url"`
}

type RechargeStatusResponse struct {
	ID            int64         `json:"id"`
	RechargeNo    string        `json:"recharge_no"`
	Status        string        `json:"status"`
	StatusText    string        `json:"status_text"`
	Wallet        WalletSummary `json:"wallet"`
	PaidAt        string        `json:"paid_at"`
	CreditedAt    string        `json:"credited_at"`
	FailureReason string        `json:"failure_reason"`
}
```

In `dto.go`, append these methods to `HTTPService`:

```go
RechargeInit(ctx context.Context, userID int64) (*RechargeInitResponse, *apperror.Error)
ListRecharges(ctx context.Context, query RechargeListQuery) (*RechargeListResponse, *apperror.Error)
GetRecharge(ctx context.Context, userID int64, id int64) (*RechargeDetail, *apperror.Error)
CreateRecharge(ctx context.Context, input RechargeCreateInput) (*RechargePayResponse, *apperror.Error)
PayRecharge(ctx context.Context, userID int64, id int64) (*RechargePayResponse, *apperror.Error)
SyncRecharge(ctx context.Context, userID int64, id int64) (*RechargeStatusResponse, *apperror.Error)
CloseRecharge(ctx context.Context, userID int64, id int64) (*RechargeStatusResponse, *apperror.Error)
```

- [x] **Step 7: Run compile red check**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/payment -run TestNonExistent
```

Expected: compile fails on missing repository/service methods. This is the expected red state.

---

## Task 3: Backend Repository and Config Sort Persistence

**Files:**
- Modify: `admin_back_go/internal/module/payment/repository.go`
- Modify: `admin_back_go/internal/module/payment/service.go`
- Create: `admin_back_go/internal/module/payment/wallet_repository.go`
- Create: `admin_back_go/internal/module/payment/recharge_repository.go`

- [x] **Step 1: Extend repository interface**

Add methods to `Repository`:

```go
ListRechargePackages(ctx context.Context) ([]RechargePackage, error)
GetRechargePackageByCode(ctx context.Context, code string) (*RechargePackage, error)
GetOrCreateWallet(ctx context.Context, userID int64) (*Wallet, error)
GetWallet(ctx context.Context, userID int64) (*Wallet, error)
ListRecharges(ctx context.Context, query RechargeListQuery) ([]RechargeWithOrder, int64, error)
ListRecentRecharges(ctx context.Context, userID int64, limit int) ([]RechargeWithOrder, error)
GetRecharge(ctx context.Context, userID int64, id int64) (*RechargeWithOrder, error)
CreateRechargeWithOrder(ctx context.Context, recharge Recharge, order Order) (RechargeWithOrder, error)
UpdateRechargePaying(ctx context.Context, id int64) error
UpdateRechargeFailed(ctx context.Context, id int64, reason string) error
UpdateRechargeClosed(ctx context.Context, id int64) error
CreditRecharge(ctx context.Context, rechargeID int64, paidAt time.Time, now time.Time) (*Wallet, *Recharge, error)
FirstEnabledConfigForPay(ctx context.Context, provider string, payMethod string) (*Config, error)
```

Also update `UpdateConfig` fields map:

```go
"sort": cfg.Sort,
```

- [x] **Step 2: Make config list ordered by sort**

In `ListConfigs`, replace order:

```go
err := db.Order("sort asc, id desc").Limit(limit).Offset(offset).Find(&rows).Error
```

- [x] **Step 3: Implement package and config selection methods**

Create `recharge_repository.go` with methods:

```go
func (r *GormRepository) ListRechargePackages(ctx context.Context) ([]RechargePackage, error) {
	if r == nil || r.db == nil {
		return nil, ErrRepositoryNotConfigured
	}
	var rows []RechargePackage
	err := r.db.WithContext(ctx).
		Where("is_del = ? AND status = ?", enum.CommonNo, enum.CommonYes).
		Order("sort asc, id asc").
		Find(&rows).Error
	return rows, err
}

func (r *GormRepository) GetRechargePackageByCode(ctx context.Context, code string) (*RechargePackage, error) {
	if r == nil || r.db == nil {
		return nil, ErrRepositoryNotConfigured
	}
	var row RechargePackage
	err := r.db.WithContext(ctx).
		Where("code = ? AND is_del = ? AND status = ?", strings.TrimSpace(code), enum.CommonNo, enum.CommonYes).
		First(&row).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	return &row, err
}

func (r *GormRepository) FirstEnabledConfigForPay(ctx context.Context, provider string, payMethod string) (*Config, error) {
	if r == nil || r.db == nil {
		return nil, ErrRepositoryNotConfigured
	}
	var rows []Config
	err := r.db.WithContext(ctx).
		Where("provider = ? AND status = ? AND is_del = ?", strings.TrimSpace(provider), enum.CommonYes, enum.CommonNo).
		Order("sort asc, id asc").
		Find(&rows).Error
	if err != nil {
		return nil, err
	}
	method := strings.TrimSpace(payMethod)
	for _, row := range rows {
		if methodEnabled(row.EnabledMethodsJSON, method) {
			return &row, nil
		}
	}
	return nil, nil
}
```

Use imports:

```go
import (
	"context"
	"errors"
	"strings"

	"admin_back_go/internal/enum"

	"gorm.io/gorm"
)
```

- [x] **Step 4: Implement wallet repository**

Create `wallet_repository.go`:

```go
package payment

import (
	"context"
	"errors"

	"admin_back_go/internal/enum"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

func (r *GormRepository) GetWallet(ctx context.Context, userID int64) (*Wallet, error) {
	if r == nil || r.db == nil {
		return nil, ErrRepositoryNotConfigured
	}
	var row Wallet
	err := r.db.WithContext(ctx).Where("user_id = ? AND is_del = ?", userID, enum.CommonNo).First(&row).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	return &row, err
}

func (r *GormRepository) GetOrCreateWallet(ctx context.Context, userID int64) (*Wallet, error) {
	if r == nil || r.db == nil {
		return nil, ErrRepositoryNotConfigured
	}
	wallet, err := r.GetWallet(ctx, userID)
	if err != nil || wallet != nil {
		return wallet, err
	}
	row := Wallet{UserID: userID, IsDel: enum.CommonNo}
	if err := r.db.WithContext(ctx).Create(&row).Error; err != nil {
		return nil, err
	}
	return &row, nil
}

func lockWalletForUpdate(tx *gorm.DB, userID int64) (*Wallet, error) {
	var wallet Wallet
	err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).
		Where("user_id = ? AND is_del = ?", userID, enum.CommonNo).
		First(&wallet).Error
	if err != nil {
		return nil, err
	}
	return &wallet, nil
}
```

- [x] **Step 5: Implement recharge list/detail/create/update methods**

Append to `recharge_repository.go`:

```go
func (r *GormRepository) ListRecharges(ctx context.Context, query RechargeListQuery) ([]RechargeWithOrder, int64, error) {
	if r == nil || r.db == nil {
		return nil, 0, ErrRepositoryNotConfigured
	}
	_, limit, offset := normalizePage(query.CurrentPage, query.PageSize)
	db := rechargeJoinQuery(r.db.WithContext(ctx)).Where("r.user_id = ? AND r.is_del = ?", query.UserID, enum.CommonNo)
	if keyword := strings.TrimSpace(query.Keyword); keyword != "" {
		like := keyword + "%"
		db = db.Where("r.recharge_no LIKE ? OR po.order_no LIKE ? OR r.package_name LIKE ?", like, like, like)
	}
	if status := strings.TrimSpace(query.Status); status != "" {
		db = db.Where("r.status = ?", status)
	}
	if start := strings.TrimSpace(query.DateStart); start != "" {
		db = db.Where("r.created_at >= ?", start)
	}
	if end := strings.TrimSpace(query.DateEnd); end != "" {
		db = db.Where("r.created_at <= ?", end)
	}
	var total int64
	if err := db.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	var rows []RechargeWithOrder
	err := db.Order("r.id desc").Limit(limit).Offset(offset).Find(&rows).Error
	return rows, total, err
}

func (r *GormRepository) ListRecentRecharges(ctx context.Context, userID int64, limit int) ([]RechargeWithOrder, error) {
	if r == nil || r.db == nil {
		return nil, ErrRepositoryNotConfigured
	}
	if limit <= 0 || limit > 10 {
		limit = 5
	}
	var rows []RechargeWithOrder
	err := rechargeJoinQuery(r.db.WithContext(ctx)).
		Where("r.user_id = ? AND r.is_del = ?", userID, enum.CommonNo).
		Order("r.id desc").Limit(limit).Find(&rows).Error
	return rows, err
}

func (r *GormRepository) GetRecharge(ctx context.Context, userID int64, id int64) (*RechargeWithOrder, error) {
	if r == nil || r.db == nil {
		return nil, ErrRepositoryNotConfigured
	}
	var row RechargeWithOrder
	err := rechargeJoinQuery(r.db.WithContext(ctx)).
		Where("r.id = ? AND r.user_id = ? AND r.is_del = ?", id, userID, enum.CommonNo).
		First(&row).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	return &row, err
}

func (r *GormRepository) CreateRechargeWithOrder(ctx context.Context, recharge Recharge, order Order) (RechargeWithOrder, error) {
	if r == nil || r.db == nil {
		return RechargeWithOrder{}, ErrRepositoryNotConfigured
	}
	err := r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		order.IsDel = enum.CommonNo
		if err := tx.Create(&order).Error; err != nil {
			return err
		}
		recharge.PaymentOrderID = order.ID
		recharge.IsDel = enum.CommonNo
		if err := tx.Create(&recharge).Error; err != nil {
			return err
		}
		return nil
	})
	if err != nil {
		return RechargeWithOrder{}, err
	}
	row, err := r.GetRecharge(ctx, recharge.UserID, recharge.ID)
	if err != nil {
		return RechargeWithOrder{}, err
	}
	if row == nil {
		return RechargeWithOrder{}, gorm.ErrRecordNotFound
	}
	return *row, nil
}

func (r *GormRepository) UpdateRechargePaying(ctx context.Context, id int64) error {
	if r == nil || r.db == nil {
		return ErrRepositoryNotConfigured
	}
	return r.db.WithContext(ctx).Model(&Recharge{}).Where("id = ? AND is_del = ?", id, enum.CommonNo).Updates(map[string]any{
		"status":         rechargeStatusPaying,
		"failure_reason": "",
	}).Error
}

func (r *GormRepository) UpdateRechargeFailed(ctx context.Context, id int64, reason string) error {
	if r == nil || r.db == nil {
		return ErrRepositoryNotConfigured
	}
	return r.db.WithContext(ctx).Model(&Recharge{}).Where("id = ? AND is_del = ?", id, enum.CommonNo).Updates(map[string]any{
		"status":         rechargeStatusFailed,
		"failure_reason": trimMax(reason, 255),
	}).Error
}

func (r *GormRepository) UpdateRechargeClosed(ctx context.Context, id int64) error {
	if r == nil || r.db == nil {
		return ErrRepositoryNotConfigured
	}
	return r.db.WithContext(ctx).Model(&Recharge{}).Where("id = ? AND is_del = ?", id, enum.CommonNo).Update("status", rechargeStatusClosed).Error
}

func rechargeJoinQuery(db *gorm.DB) *gorm.DB {
	return db.Table("payment_recharges AS r").
		Select(`r.*, po.order_no AS payment_order_no, po.pay_url AS pay_url, po.pay_method AS pay_method, po.status AS order_status, po.alipay_trade_no AS alipay_trade_no, po.paid_at AS order_paid_at, po.closed_at AS order_closed_at`).
		Joins("JOIN payment_orders AS po ON po.id = r.payment_order_id AND po.is_del = ?", enum.CommonNo)
}
```

- [x] **Step 6: Implement `CreditRecharge` transaction**

Append to `recharge_repository.go` and import `gorm.io/gorm/clause`:

```go
func (r *GormRepository) CreditRecharge(ctx context.Context, rechargeID int64, paidAt time.Time, now time.Time) (*Wallet, *Recharge, error) {
	if r == nil || r.db == nil {
		return nil, nil, ErrRepositoryNotConfigured
	}
	var creditedWallet Wallet
	var creditedRecharge Recharge
	err := r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var recharge Recharge
		if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).
			Where("id = ? AND is_del = ?", rechargeID, enum.CommonNo).
			First(&recharge).Error; err != nil {
			return err
		}
		wallet, err := lockWalletForUpdate(tx, recharge.UserID)
		if err != nil {
			return err
		}
		var existing int64
		if err := tx.Model(&WalletTransaction{}).
			Where("source_type = ? AND source_id = ? AND is_del = ?", walletSourceRecharge, recharge.ID, enum.CommonNo).
			Count(&existing).Error; err != nil {
			return err
		}
		if existing > 0 || recharge.CreditedAt != nil || recharge.Status == rechargeStatusCredited {
			creditedWallet = *wallet
			creditedRecharge = recharge
			return nil
		}
		before := wallet.BalanceCents
		after := before + recharge.AmountCents
		txRow := WalletTransaction{
			TransactionNo:      newWalletTransactionNo(now),
			WalletID:           wallet.ID,
			UserID:             recharge.UserID,
			Direction:          walletDirectionIn,
			AmountCents:        recharge.AmountCents,
			BalanceBeforeCents: before,
			BalanceAfterCents:  after,
			SourceType:         walletSourceRecharge,
			SourceID:           recharge.ID,
			Remark:             "支付宝充值",
			IsDel:              enum.CommonNo,
		}
		if err := tx.Create(&txRow).Error; err != nil {
			return err
		}
		if err := tx.Model(&Wallet{}).Where("id = ? AND is_del = ?", wallet.ID, enum.CommonNo).Updates(map[string]any{
			"balance_cents":         after,
			"total_recharge_cents":  wallet.TotalRechargeCents + recharge.AmountCents,
		}).Error; err != nil {
			return err
		}
		if err := tx.Model(&Recharge{}).Where("id = ? AND is_del = ?", recharge.ID, enum.CommonNo).Updates(map[string]any{
			"status":         rechargeStatusCredited,
			"paid_at":        paidAt,
			"credited_at":    now,
			"failure_reason": "",
		}).Error; err != nil {
			return err
		}
		wallet.BalanceCents = after
		wallet.TotalRechargeCents += recharge.AmountCents
		recharge.Status = rechargeStatusCredited
		recharge.PaidAt = &paidAt
		recharge.CreditedAt = &now
		creditedWallet = *wallet
		creditedRecharge = recharge
		return nil
	})
	if err != nil {
		return nil, nil, err
	}
	return &creditedWallet, &creditedRecharge, nil
}
```

- [x] **Step 7: Run focused compile**

Run:

```powershell
cd E:\admin_go\admin_back_go
gofmt -w internal\module\payment
go test ./internal/module/payment -run TestNonExistent
```

Expected: remaining failures should now be service/handler related only. Fix imports/signatures before continuing.

---

## Task 4: Backend Recharge Service and Handler

**Files:**
- Create: `admin_back_go/internal/module/payment/recharge_service.go`
- Create: `admin_back_go/internal/module/payment/recharge_handler.go`
- Modify: `admin_back_go/internal/module/payment/service.go`
- Modify: `admin_back_go/internal/module/payment/route.go`

- [x] **Step 1: Update config service for sort**

In `service.go`, normalize and persist config sort:

```go
sort := input.Sort
if sort <= 0 {
	sort = 100
}
```

Set `Sort: sort` in `Config{}` and map `Sort: row.Sort` into `ConfigListItem`.

- [x] **Step 2: Create recharge service core**

Create `recharge_service.go` implementing:

```go
func (s *Service) RechargeInit(ctx context.Context, userID int64) (*RechargeInitResponse, *apperror.Error)
func (s *Service) ListRecharges(ctx context.Context, query RechargeListQuery) (*RechargeListResponse, *apperror.Error)
func (s *Service) GetRecharge(ctx context.Context, userID int64, id int64) (*RechargeDetail, *apperror.Error)
func (s *Service) CreateRecharge(ctx context.Context, input RechargeCreateInput) (*RechargePayResponse, *apperror.Error)
func (s *Service) PayRecharge(ctx context.Context, userID int64, id int64) (*RechargePayResponse, *apperror.Error)
func (s *Service) SyncRecharge(ctx context.Context, userID int64, id int64) (*RechargeStatusResponse, *apperror.Error)
func (s *Service) CloseRecharge(ctx context.Context, userID int64, id int64) (*RechargeStatusResponse, *apperror.Error)
```

Implementation rules:

```text
CreateRecharge:
  validate current user
  validate package_code
  validate return_url http/https
  select config by provider=alipay + pay_method + sort
  create wallet if absent
  create payment_order + payment_recharge
  call PayOrder through payment_order_id
  set recharge paying or failed

SyncRecharge:
  if credited: return wallet without crediting again
  call SyncOrder when payment order is paying
  if payment order paid: call CreditRecharge transaction
  never credit if wallet transaction source already exists

CloseRecharge:
  reject paid/credited
  close underlying payment_order
  set recharge closed
```

Required helper signatures:

```go
func rechargePackageItems(rows []RechargePackage) []RechargePackageItem
func walletSummary(wallet *Wallet) WalletSummary
func rechargeListItems(rows []RechargeWithOrder) []RechargeListItem
func rechargeListItem(row RechargeWithOrder) RechargeListItem
func rechargeDetail(row RechargeWithOrder) RechargeDetail
func rechargePayResponse(row RechargeWithOrder) *RechargePayResponse
func rechargeStatusResponse(row RechargeWithOrder, wallet *Wallet) *RechargeStatusResponse
func rechargeStatusOptions() []dict.Option[string]
func rechargeStatusText(status string) string
func formatPtrTime(value *time.Time) string
func newPaymentRechargeNo(now time.Time) string
func newWalletTransactionNo(now time.Time) string
```

- [x] **Step 3: Create recharge handler**

Create `recharge_handler.go` with handler methods:

```go
RechargeInit
ListRecharges
GetRecharge
CreateRecharge
PayRecharge
SyncRecharge
CloseRecharge
```

Every method must fetch identity with `middleware.GetAuthIdentity(c)` and reject missing/zero user with:

```go
response.Error(c, apperror.Unauthorized("Token无效或已过期"))
```

Do not accept `user_id` from request.

- [x] **Step 4: Register routes**

In `route.go`, add:

```go
recharges := router.Group("/api/admin/v1/payment/recharges")
recharges.GET("/page-init", handler.RechargeInit)
recharges.GET("", handler.ListRecharges)
recharges.GET("/:id", handler.GetRecharge)
recharges.POST("", handler.CreateRecharge)
recharges.POST("/:id/pay", handler.PayRecharge)
recharges.POST("/:id/sync", handler.SyncRecharge)
recharges.PATCH("/:id/close", handler.CloseRecharge)
```

- [x] **Step 5: Run focused backend compile**

Run:

```powershell
cd E:\admin_go\admin_back_go
gofmt -w internal\module\payment
go test ./internal/module/payment
```

Expected: PASS after tests are updated in Task 5.

---

## Task 5: Backend Tests for Sort Selection and Idempotent Credit

**Files:**
- Create: `admin_back_go/internal/module/payment/recharge_service_test.go`
- Modify: existing payment test fakes when interface additions break compile

- [x] **Step 1: Add recharge service tests**

Create tests that cover:

```text
CreateRecharge rejects empty user
CreateRecharge rejects disabled/missing package
CreateRecharge rejects missing enabled payment config
CreateRecharge chooses lowest sort enabled Alipay config for pay method
CreateRecharge payload has no config code by construction
SyncRecharge returns credited without calling CreditRecharge again
CloseRecharge rejects credited
```

Use a fake `Repository` and fake `Gateway`. The fake repository must explicitly implement all `Repository` methods; no reflection, no `any` shortcuts.

- [x] **Step 2: Add idempotent credit repository test**

If practical with current test setup, use sqlite/gorm or sqlmock to prove `CreditRecharge` does not insert a second `wallet_transactions` row for the same `(source_type, source_id)`. Minimum acceptable test if DB test setup is too expensive:

```text
service-level credited state does not call CreditRecharge
repository method checks existing wallet_transactions before balance update
```

Use a source scan assertion only as a last resort; prefer executable test.

- [x] **Step 3: Run payment tests**

Run:

```powershell
cd E:\admin_go\admin_back_go
gofmt -w internal\module\payment
go test ./internal/module/payment
```

Expected: PASS.

---

## Task 6: Backend Route Meta, Router Fakes, and OperationLog

**Files:**
- Modify: `admin_back_go/internal/bootstrap/route_meta.go`
- Modify: `admin_back_go/internal/bootstrap/route_meta_test.go`
- Modify: `admin_back_go/internal/server/router_test.go`

- [x] **Step 1: Add route permission metadata**

Add:

```go
middleware.NewRouteKey(http.MethodGet, "/api/admin/v1/payment/recharges/page-init"): "payment_recharge_list",
middleware.NewRouteKey(http.MethodGet, "/api/admin/v1/payment/recharges"): "payment_recharge_list",
middleware.NewRouteKey(http.MethodGet, "/api/admin/v1/payment/recharges/:id"): "payment_recharge_list",
middleware.NewRouteKey(http.MethodPost, "/api/admin/v1/payment/recharges"): "payment_recharge_add",
middleware.NewRouteKey(http.MethodPost, "/api/admin/v1/payment/recharges/:id/pay"): "payment_recharge_pay",
middleware.NewRouteKey(http.MethodPost, "/api/admin/v1/payment/recharges/:id/sync"): "payment_recharge_sync",
middleware.NewRouteKey(http.MethodPatch, "/api/admin/v1/payment/recharges/:id/close"): "payment_recharge_close",
```

- [x] **Step 2: Add OperationLog metadata**

Add:

```go
middleware.NewRouteKey(http.MethodPost, "/api/admin/v1/payment/recharges"): {
	Module: "payment_recharge",
	Action: "add",
	Name:   "创建充值",
},
middleware.NewRouteKey(http.MethodPost, "/api/admin/v1/payment/recharges/:id/pay"): {
	Module:           "payment_recharge",
	Action:           "pay",
	Name:             "继续支付",
	SkipResponseData: true,
},
middleware.NewRouteKey(http.MethodPost, "/api/admin/v1/payment/recharges/:id/sync"): {
	Module: "payment_recharge",
	Action: "sync",
	Name:   "同步充值状态",
},
middleware.NewRouteKey(http.MethodPatch, "/api/admin/v1/payment/recharges/:id/close"): {
	Module: "payment_recharge",
	Action: "close",
	Name:   "关闭充值",
},
```

- [x] **Step 3: Update tests and fakes**

Update `route_meta_test.go` to assert all new permissions and operation log metadata.

Update `fakeRouterPaymentService` in `router_test.go` with all new `HTTPService` methods returning empty DTOs.

- [x] **Step 4: Run backend route tests**

Run:

```powershell
cd E:\admin_go\admin_back_go
gofmt -w internal\bootstrap internal\server
go test ./internal/bootstrap ./internal/server
```

Expected: PASS.

---

## Task 7: Frontend Payment Config Sort Field

**Files:**
- Modify: `admin_front_ts/src/api/payment/config.ts`
- Modify: `admin_front_ts/src/views/Main/payment/config/composables/usePaymentConfigPage.ts`
- Modify: `admin_front_ts/src/views/Main/payment/config/components/PaymentConfigForm.vue`

- [x] **Step 1: Update API types**

Add to `PaymentConfigListItem` and `PaymentConfigMutationPayload`:

```ts
sort: number
```

- [x] **Step 2: Update config page state**

In `usePaymentConfigPage.ts`:

```ts
{ key: 'sort', label: '优先级', width: 90 },
```

Add `sort: row.sort` to edit form and `sort: 100` to `defaultForm()`.

Add rule:

```ts
sort: [{ required: true, message: '请输入支付优先级', trigger: 'blur' }],
```

- [x] **Step 3: Add sort input**

In `PaymentConfigForm.vue`, add:

```vue
<el-col :md="12" :span="24">
  <el-form-item label="优先级" prop="sort" required>
    <el-input-number v-model="form.sort" :controls="false" :min="1" :max="9999" style="width: 100%" />
    <div class="payment-config-help">数字越小越优先。状态关闭时不会参与充值支付。</div>
  </el-form-item>
</el-col>
```

Add scoped style if missing:

```css
.payment-config-help {
  margin-top: 6px;
  color: var(--el-text-color-secondary);
  font-size: 12px;
  line-height: 1.5;
}
```

- [x] **Step 4: Run frontend config checks**

Run:

```powershell
cd E:\admin_go\admin_front_ts
npx vitest run tests/shared/payment/payment-config-api.test.ts tests/shared/payment/payment-config-page.test.ts
npx vue-tsc -b --pretty false
```

Expected: PASS.

---

## Task 8: Frontend Recharge API Client and Static Contract Tests

**Files:**
- Create: `admin_front_ts/src/api/payment/recharges.ts`
- Create: `admin_front_ts/tests/shared/payment/payment-recharge-api.test.ts`

- [x] **Step 1: Create typed recharge API client**

Create `src/api/payment/recharges.ts` with strict DTOs for:

```ts
PaymentRechargeStatus = 'pending' | 'paying' | 'paid' | 'credited' | 'closed' | 'failed'
PaymentRechargePayMethod = 'web' | 'h5'
WalletSummary
RechargePackageItem
RechargePaymentMethod
PaymentRechargeListItem
PaymentRechargeDetail
PaymentRechargeInitResponse
PaymentRechargeListParams
PaymentRechargeCreatePayload
PaymentRechargePayResponse
PaymentRechargeStatusResponse
```

Expose:

```ts
PaymentRechargeApi.init()
PaymentRechargeApi.list(params)
PaymentRechargeApi.detail(id)
PaymentRechargeApi.add(payload)
PaymentRechargeApi.pay(id)
PaymentRechargeApi.sync(id)
PaymentRechargeApi.close(id)
```

Use paths exactly:

```text
/payment/recharges/page-init
/payment/recharges
/payment/recharges/:id
/payment/recharges/:id/pay
/payment/recharges/:id/sync
/payment/recharges/:id/close
```

- [x] **Step 2: Add API contract test**

Create `payment-recharge-api.test.ts` asserting:

```ts
expect(source).toContain('/payment/recharges/page-init')
expect(source).toContain('/payment/recharges')
expect(source).toContain('/pay')
expect(source).toContain('/sync')
expect(source).toContain('/close')
expect(source).toContain('package_code: string')
expect(source).toContain('return_url: string')
expect(source).not.toContain('config_code')
expect(source).not.toContain('amount_yuan')
expect(source).not.toContain('subject')
expect(source).not.toContain('refund_')
expect(source).not.toContain('subscription_')
expect(source).not.toMatch(loose)
```

- [x] **Step 3: Run API static test**

Run:

```powershell
cd E:\admin_go\admin_front_ts
npx vitest run tests/shared/payment/payment-recharge-api.test.ts
```

Expected: PASS.

---

## Task 9: Frontend Recharge Page Components and Composable

**Files:**
- Create: `admin_front_ts/src/views/Main/payment/recharge/index.vue`
- Create: `admin_front_ts/src/views/Main/payment/recharge/components/RechargePackageGrid.vue`
- Create: `admin_front_ts/src/views/Main/payment/recharge/components/RechargePaymentMethodCard.vue`
- Create: `admin_front_ts/src/views/Main/payment/recharge/components/RechargeCheckoutPanel.vue`
- Create: `admin_front_ts/src/views/Main/payment/recharge/components/RechargeRecentRecords.vue`
- Create: `admin_front_ts/src/views/Main/payment/recharge/components/RechargeRecordsTable.vue`
- Create: `admin_front_ts/src/views/Main/payment/recharge/composables/usePaymentRechargePage.ts`
- Create: `admin_front_ts/tests/shared/payment/payment-recharge-page.test.ts`

- [x] **Step 1: Create composable**

`usePaymentRechargePage.ts` must own:

```text
page-init loading
wallet/packages/payment method/recent records state
selectedPackageCode
computed selectedPackage / balanceAfterText / canSubmit
records Search + AppTable state through useTable
createRecharge -> PaymentRechargeApi.add(buildCreatePayload(...)) -> window.location.href
payRecharge / syncRecharge / closeRecharge
route query tab=records and recharge_no auto-sync
```

`buildCreatePayload` must return only:

```ts
{
  package_code: packageCode,
  pay_method: browserPayMethod(),
  return_url: rechargeReturnURL(),
}
```

Check `admin_front_ts/src/router/index.ts` before implementing `rechargeReturnURL()`. If the app uses hash routing, return a URL that lands back on `#/payment/recharge`. If it uses history routing, use router resolve output.

- [x] **Step 2: Create split components**

Responsibilities:

```text
RechargePackageGrid: package cards only; props packages/selectedCode; emit select
RechargePaymentMethodCard: show Alipay method and unavailable state
RechargeCheckoutPanel: amount, wallet, balance-after, submit button; emit submit
RechargeRecentRecords: compact recent list; emit pay/sync/close
RechargeRecordsTable: Search + AppTable; row action buttons gated by payment_recharge_* permissions
index.vue: el-tabs + layout composition only
```

All components must use `<script setup lang="ts">`, typed props/emits, scoped styles.

- [x] **Step 3: UI rules**

Implement a restrained layout:

```text
root class payment-recharge-page
el-tabs at top
cashier tab: left main cards + right checkout panel
records tab: Search + AppTable
no el-dialog
no form input for config_code
no manual amount input
no return_url input
```

Use simple card styling: white background, thin border, selected blue outline, subtle shadow. No aggressive gradients.

- [x] **Step 4: Add page static test**

Create `payment-recharge-page.test.ts` asserting:

```ts
expect(page).toContain('el-tabs')
expect(page).toContain('RechargePackageGrid')
expect(page).toContain('RechargeCheckoutPanel')
expect(records).toContain("userStore.can('payment_recharge_pay')")
expect(records).toContain("userStore.can('payment_recharge_sync')")
expect(records).toContain("userStore.can('payment_recharge_close')")
expect(composable).toContain('PaymentRechargeApi.add')
expect(composable).toContain('return_url: rechargeReturnURL()')
expect(combined).not.toContain('config_code')
expect(combined).not.toContain('amount_yuan')
expect(combined).not.toContain('同步返回地址')
expect(combined).not.toContain('<el-dialog')
expect(combined).not.toMatch(loose)
```

- [x] **Step 5: Run frontend recharge checks**

Run:

```powershell
cd E:\admin_go\admin_front_ts
npx vitest run tests/shared/payment/payment-recharge-api.test.ts tests/shared/payment/payment-recharge-page.test.ts
npx vue-tsc -b --pretty false
```

Expected: PASS.

---

## Task 10: Frontend Menu Locale and Retire Raw Create UX

**Files:**
- Modify: `admin_front_ts/src/i18n/locales/zh-CN.ts`
- Modify: `admin_front_ts/src/i18n/locales/en-US.ts`
- Modify: `admin_front_ts/src/views/Main/payment/orders/index.vue`
- Modify: `admin_front_ts/src/views/Main/payment/orders/composables/usePaymentOrderPage.ts`
- Modify: `admin_front_ts/tests/shared/payment/payment-order-page.test.ts`

- [x] **Step 1: Add locale keys**

In `zh-CN.ts`:

```ts
payment_recharge: '充值/记录'
```

In `en-US.ts`:

```ts
payment_recharge: 'Recharge'
```

- [x] **Step 2: Remove raw create button from orders page**

In `orders/index.vue`, remove toolbar button using `payment_order_add` and remove `PaymentOrderFormDialog` from imports/template. Keep list/detail/pay/sync/close.

- [x] **Step 3: Remove raw create dialog state**

In `usePaymentOrderPage.ts`, remove:

```text
formDialogVisible
formRef
form
rules
openCreateDialog
confirmCreate
PaymentOrderApi.add(buildCreatePayload(form.value))
return_url form validation
amount_yuan conversion for create dialog
```

Do not remove `PaymentOrderApi.add` from API client yet; backend contract remains for internal use.

- [x] **Step 4: Update order page test**

Assert raw create UX is absent:

```ts
expect(page).not.toContain("userStore.can('payment_order_add')")
expect(page).not.toContain('PaymentOrderFormDialog')
expect(composable).not.toContain('PaymentOrderApi.add(buildCreatePayload')
expect(combined).not.toContain('同步返回地址')
```

- [x] **Step 5: Run payment frontend checks**

Run:

```powershell
cd E:\admin_go\admin_front_ts
npx vitest run tests/shared/payment/payment-order-api.test.ts tests/shared/payment/payment-order-page.test.ts tests/shared/payment/payment-recharge-api.test.ts tests/shared/payment/payment-recharge-page.test.ts
npx vue-tsc -b --pretty false
```

Expected: PASS.

---

## Task 11: Backend Contract, Smoke, Docs Sync

**Files:**
- Modify: `docs/contracts/admin-api-v1.md`
- Modify: `docs/status/current-status.md`
- Modify: `docs/testing/smoke-matrix.md`
- Modify: `admin_back_go/docs/architecture.md`
- Modify: `admin_back_go/scripts/full-admin-smoke.ps1`

- [x] **Step 1: Update admin API contract**

In `docs/contracts/admin-api-v1.md`, update payment section:

```text
active pages: /payment/config, /payment/recharge; /payment/orders is internal/raw order visibility only and does not expose raw create UX.
active tables: payment_configs, payment_orders, payment_recharge_packages, payment_recharges, user_wallets, wallet_transactions
```

Add recharge endpoint list and request/response examples. State explicitly:

```text
Recharge create payload has package_code, pay_method, return_url only. It has no config_code, subject, amount_yuan, or user-entered return_url field.
```

- [x] **Step 2: Update current status**

In `docs/status/current-status.md`, update payment row to mention:

```text
/payment/recharge exists
wallet credited through sync is idempotent
payment_configs.sort selects preferred enabled Alipay config
no notify/refund/WeChat/cron/subscription in this slice
```

- [x] **Step 3: Update smoke matrix and script**

In `docs/testing/smoke-matrix.md`, add read probes:

```text
GET /api/admin/v1/payment/recharges/page-init
GET /api/admin/v1/payment/recharges?current_page=1&page_size=10
users/init contains /payment/recharge component=payment/recharge
```

In `admin_back_go/scripts/full-admin-smoke.ps1`, add equivalent probes after payment order probes.

- [x] **Step 4: Update backend architecture**

In `admin_back_go/docs/architecture.md`, add:

```text
payment/recharge owns user-facing cashier; payment/orders remains low-level payment order runtime.
Wallet credit is DB-transactional and idempotent through wallet_transactions(source_type, source_id).
```

---

## Task 12: Final Verification and Live DB Check

**Files:**
- No source changes unless verification exposes a defect.

- [x] **Step 1: Run backend tests and vet**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test -p=1 ./internal/platform/payment ./internal/platform/payment/alipay ./internal/module/payment ./internal/bootstrap ./internal/server
go vet ./internal/platform/payment ./internal/platform/payment/alipay ./internal/module/payment ./internal/bootstrap ./internal/server
powershell -ExecutionPolicy Bypass -File .\scripts\check-contract.ps1
```

Expected: all exit 0.

- [x] **Step 2: Run frontend tests and typecheck**

Run:

```powershell
cd E:\admin_go\admin_front_ts
npx vitest run tests/shared/payment/payment-config-api.test.ts tests/shared/payment/payment-config-page.test.ts tests/shared/payment/payment-order-api.test.ts tests/shared/payment/payment-order-page.test.ts tests/shared/payment/payment-recharge-api.test.ts tests/shared/payment/payment-recharge-page.test.ts tests/shared/http-language-header.test.ts
npx vue-tsc -b --pretty false
```

Expected: all exit 0.

- [x] **Step 3: Run residue scan**

Run:

```powershell
cd E:\admin_go
rg -n "/payment/order\b|component=payment/order|payment_recharge_page|payment_order_create_for_recharge|pay_recharge_|recharge_order_|refund_status|refund_amount|subscription_days|raw_request|raw_response|extra_json" admin_back_go admin_front_ts docs/contracts docs/status docs/testing --glob "!docs/superpowers/**"
```

Expected: exit 1 with no output for payment files. If output is under payment implementation or current payment docs, fix it.

- [x] **Step 4: Apply migration to live DB when executing implementation locally**

Use the same `multiStatements=true` Go runner approach used for payment order migration. Then verify:

```sql
SELECT TABLE_NAME
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME IN ('payment_configs','payment_orders','payment_recharge_packages','payment_recharges','user_wallets','wallet_transactions')
ORDER BY TABLE_NAME;

SELECT COLUMN_NAME
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME = 'payment_configs'
  AND COLUMN_NAME = 'sort';

SELECT code, path, component, i18n_key, type, is_del, status
FROM permissions
WHERE code IN ('payment_recharge_list','payment_recharge_add','payment_recharge_pay','payment_recharge_sync','payment_recharge_close')
ORDER BY type, sort, code;
```

Expected:

```text
all six tables present
payment_configs.sort present
five payment_recharge_* permissions present and active
```

- [x] **Step 5: Optional manual browser smoke**

After backend/frontend are running and local DB migration is applied:

```text
1. Login.
2. Open 支付管理 -> 充值/记录.
3. Confirm packages render.
4. Confirm no payment config selector, no handwritten amount input, no return_url input.
5. Click a package, see checkout panel amount and balance-after amount.
6. If Alipay sandbox config is valid, click confirm pay and verify current window navigates to Alipay pay_url.
```

---

## Plan Self-Review

Spec coverage:

```text
Product cashier layout -> Task 9
No user config/amount/return_url fields -> Task 8/9/10 tests
payment_configs.sort -> Task 1/2/3/7
packages/recharges/wallets/transactions -> Task 1/2/3/4/5
idempotent credit -> Task 3/4/5
permissions/menu/route meta -> Task 1/6/10/11
contract/status/smoke -> Task 11/12
```

Placeholder scan:

```text
No TBD/fill-in-later steps. Where implementation depends on existing file style, exact snippets, names, and commands are provided.
```

Type consistency:

```text
PaymentRecharge* TypeScript types match Recharge* Go DTO names and JSON fields.
Permission path/component/i18n/table names match the spec naming lock.
```
