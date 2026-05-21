# Wallet Recharge and Consume V1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Add the first wallet slice: total consume accounting, wallet summary/transactions/admin ledger APIs, a guarded consume API, and read-only Vue wallet pages.

**Architecture:** Keep `payment` responsible for Alipay collection and recharge state; add `internal/module/wallet` for wallet balance, ledger reads, and consumption writes. Reuse `user_wallets` and `wallet_transactions`, adding only `user_wallets.total_consume_cents`.

**Tech Stack:** Go 1.21+, Gin, GORM/MySQL transactions with row locks, existing `apperror`/`response`/RBAC middleware, Vue 3 `<script setup>` + TypeScript, `Search` + `AppTable` + `useTable`, Vitest, Go unit tests, live Docker MySQL migration.

---

## Scope Check

This is the first implementation slice from `docs/superpowers/specs/2026-05-21-wallet-recharge-consume-v1-design.md`.

In this plan:

```text
1. Add total_consume_cents to user_wallets.
2. Add wallet REST APIs for current-user summary, current-user transactions, admin wallet users, admin ledger, and guarded consume.
3. Add wallet menus for funds detail and admin wallet management.
4. Add Vue wallet API and three read pages: current-user funds detail, admin wallet users, admin ledger.
5. Keep smoke read-only by default.
```

Out of this plan:

```text
1. Moving /payment/recharge to /wallet/recharge.
2. Refactoring payment finalizer to call wallet service.
3. Refund, withdraw, freeze, manual adjustment, reconcile, WeChat, membership entitlement, and business fulfillment.
```

## File Structure

Backend:

```text
Create: admin_back_go/internal/module/wallet/model.go
Create: admin_back_go/internal/module/wallet/dto.go
Create: admin_back_go/internal/module/wallet/request.go
Create: admin_back_go/internal/module/wallet/repository.go
Create: admin_back_go/internal/module/wallet/service.go
Create: admin_back_go/internal/module/wallet/handler.go
Create: admin_back_go/internal/module/wallet/route.go
Create: admin_back_go/internal/module/wallet/service_test.go
Create: admin_back_go/internal/module/wallet/handler_test.go
Create: admin_back_go/database/migrations/20260521_wallet_recharge_consume_v1.sql
Modify: admin_back_go/internal/server/router.go
Modify: admin_back_go/internal/bootstrap/app.go
Modify: admin_back_go/internal/bootstrap/route_meta.go
Modify: admin_back_go/internal/bootstrap/route_meta_test.go
Modify: admin_back_go/internal/module/payment/wallet_model.go
Modify: admin_back_go/internal/module/payment/recharge_dto.go
Modify: admin_back_go/internal/module/payment/recharge_service.go
```

Frontend:

```text
Create: admin_front_ts/src/api/wallet/index.ts
Create: admin_front_ts/src/views/Main/wallet/transactions/index.vue
Create: admin_front_ts/src/views/Main/wallet/users/index.vue
Create: admin_front_ts/src/views/Main/wallet/ledger/index.vue
Create: admin_front_ts/tests/shared/wallet/wallet-api.test.ts
Create: admin_front_ts/tests/shared/wallet/wallet-pages.test.ts
Modify: admin_front_ts/src/i18n/locales/zh-CN.ts
Modify: admin_front_ts/src/i18n/locales/en-US.ts
Modify: admin_front_ts/src/api/payment/recharges.ts
```

Docs/smoke:

```text
Modify: docs/contracts/admin-api-v1.md
Modify: docs/status/current-status.md
Modify: docs/testing/smoke-matrix.md
Modify: admin_back_go/scripts/full-admin-smoke.ps1
```

---

## Task 1: Migration and Live Schema Baseline

**Files:**
- Create: `admin_back_go/database/migrations/20260521_wallet_recharge_consume_v1.sql`
- Runtime: live MySQL `admin.user_wallets`, `permissions`, `role_permissions`

- [x] **Step 1: Write the migration**

Create `admin_back_go/database/migrations/20260521_wallet_recharge_consume_v1.sql`:

```sql
-- Wallet recharge + consume v1.
-- payment_orders is the Alipay/gateway collection ledger.
-- wallet_transactions is the funds ledger for recharge in and consume out.

ALTER TABLE `user_wallets`
  ADD COLUMN `total_consume_cents` BIGINT NOT NULL DEFAULT 0 COMMENT '累计消费金额，单位分' AFTER `total_recharge_cents`;

INSERT INTO `permissions` (`parent_id`, `name`, `code`, `path`, `component`, `type`, `icon`, `show_menu`, `sort`, `platform`, `status`, `is_del`, `created_at`, `updated_at`)
SELECT 0, '钱包中心', 'wallet_center', '/wallet', '', 1, 'Wallet', 1, 45, 'admin', 1, 2, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
WHERE NOT EXISTS (SELECT 1 FROM `permissions` WHERE `platform` = 'admin' AND `code` = 'wallet_center' AND `is_del` = 2);

INSERT INTO `permissions` (`parent_id`, `name`, `code`, `path`, `component`, `type`, `icon`, `show_menu`, `sort`, `platform`, `status`, `is_del`, `created_at`, `updated_at`)
SELECT p.`id`, '资金明细', 'wallet_transaction_list', '/wallet/transactions', 'wallet/transactions', 2, '', 1, 20, 'admin', 1, 2, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
FROM `permissions` p
WHERE p.`platform` = 'admin' AND p.`code` = 'wallet_center' AND p.`is_del` = 2
  AND NOT EXISTS (SELECT 1 FROM `permissions` c WHERE c.`platform` = 'admin' AND c.`path` = '/wallet/transactions' AND c.`is_del` = 2);

INSERT INTO `permissions` (`parent_id`, `name`, `code`, `path`, `component`, `type`, `icon`, `show_menu`, `sort`, `platform`, `status`, `is_del`, `created_at`, `updated_at`)
SELECT 0, '钱包管理', 'wallet_manage', '/wallet-manage', '', 1, 'WalletFilled', 1, 46, 'admin', 1, 2, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
WHERE NOT EXISTS (SELECT 1 FROM `permissions` WHERE `platform` = 'admin' AND `code` = 'wallet_manage' AND `is_del` = 2);

INSERT INTO `permissions` (`parent_id`, `name`, `code`, `path`, `component`, `type`, `icon`, `show_menu`, `sort`, `platform`, `status`, `is_del`, `created_at`, `updated_at`)
SELECT p.`id`, '用户钱包', 'wallet_user_list', '/wallet/users', 'wallet/users', 2, '', 1, 10, 'admin', 1, 2, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
FROM `permissions` p
WHERE p.`platform` = 'admin' AND p.`code` = 'wallet_manage' AND p.`is_del` = 2
  AND NOT EXISTS (SELECT 1 FROM `permissions` c WHERE c.`platform` = 'admin' AND c.`path` = '/wallet/users' AND c.`is_del` = 2);

INSERT INTO `permissions` (`parent_id`, `name`, `code`, `path`, `component`, `type`, `icon`, `show_menu`, `sort`, `platform`, `status`, `is_del`, `created_at`, `updated_at`)
SELECT p.`id`, '资金流水', 'wallet_ledger_list', '/wallet/ledger', 'wallet/ledger', 2, '', 1, 20, 'admin', 1, 2, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
FROM `permissions` p
WHERE p.`platform` = 'admin' AND p.`code` = 'wallet_manage' AND p.`is_del` = 2
  AND NOT EXISTS (SELECT 1 FROM `permissions` c WHERE c.`platform` = 'admin' AND c.`path` = '/wallet/ledger' AND c.`is_del` = 2);

INSERT INTO `permissions` (`parent_id`, `name`, `code`, `path`, `component`, `type`, `icon`, `show_menu`, `sort`, `platform`, `status`, `is_del`, `created_at`, `updated_at`)
SELECT p.`id`, '测试消费', 'wallet_consume_add', '', '', 3, '', 2, 30, 'admin', 1, 2, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
FROM `permissions` p
WHERE p.`platform` = 'admin' AND p.`code` = 'wallet_transaction_list' AND p.`is_del` = 2
  AND NOT EXISTS (SELECT 1 FROM `permissions` c WHERE c.`platform` = 'admin' AND c.`code` = 'wallet_consume_add' AND c.`is_del` = 2);

INSERT INTO `role_permissions` (`role_id`, `permission_id`, `is_del`, `created_at`, `updated_at`)
SELECT r.`id`, p.`id`, 2, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
FROM `roles` r
JOIN `permissions` p ON p.`platform` = 'admin'
  AND p.`is_del` = 2
  AND p.`code` IN ('wallet_center', 'wallet_transaction_list', 'wallet_manage', 'wallet_user_list', 'wallet_ledger_list')
WHERE r.`is_del` = 2
ON DUPLICATE KEY UPDATE `is_del` = 2, `updated_at` = CURRENT_TIMESTAMP;
```

- [x] **Step 2: Check current live state**

Run:

```powershell
cd E:\admin_go
docker exec admin-go-state-mysql mysql -uroot -padmin_go_local --default-character-set=utf8mb4 -D admin -e "SHOW COLUMNS FROM user_wallets LIKE 'total_consume_cents'; SELECT id,name,code,path,component,show_menu FROM permissions WHERE code IN ('wallet_center','wallet_transaction_list','wallet_manage','wallet_user_list','wallet_ledger_list','wallet_consume_add') ORDER BY id;"
```

Expected before first apply:

```text
SHOW COLUMNS returns no rows.
Permission SELECT may be empty.
```

- [x] **Step 3: Apply SQL to live DB**

Run:

```powershell
docker exec -i admin-go-state-mysql mysql -uroot -padmin_go_local --default-character-set=utf8mb4 -D admin < admin_back_go/database/migrations/20260521_wallet_recharge_consume_v1.sql
```

Expected:

```text
No SQL error.
```

- [x] **Step 4: Verify live DB state**

Run:

```powershell
docker exec admin-go-state-mysql mysql -uroot -padmin_go_local --default-character-set=utf8mb4 -D admin -e "SHOW COLUMNS FROM user_wallets LIKE 'total_consume_cents'; SELECT p.id,p.parent_id,p.name,p.code,p.path,p.component,p.show_menu,GROUP_CONCAT(rp.role_id ORDER BY rp.role_id) AS roles FROM permissions p LEFT JOIN role_permissions rp ON rp.permission_id=p.id AND rp.is_del=2 WHERE p.code IN ('wallet_center','wallet_transaction_list','wallet_manage','wallet_user_list','wallet_ledger_list','wallet_consume_add') GROUP BY p.id,p.parent_id,p.name,p.code,p.path,p.component,p.show_menu ORDER BY p.parent_id,p.sort,p.id;"
```

Expected:

```text
user_wallets has total_consume_cents.
wallet_center, wallet_transaction_list, wallet_manage, wallet_user_list, wallet_ledger_list exist and have role grants.
wallet_consume_add exists but has no default grant unless deliberately granted later.
```

- [x] **Step 5: Clear permission cache**

Run:

```powershell
$keys = docker exec admin-go-state-redis redis-cli --raw --scan --pattern 'auth_perm_uid_*'
foreach ($key in $keys) { docker exec admin-go-state-redis redis-cli DEL $key | Out-Null }
```

Expected:

```text
No required output.
```

---

## Task 2: Backend Wallet Model, DTO, Repository

**Files:**
- Create: `admin_back_go/internal/module/wallet/model.go`
- Create: `admin_back_go/internal/module/wallet/dto.go`
- Create: `admin_back_go/internal/module/wallet/repository.go`
- Modify: `admin_back_go/internal/module/payment/wallet_model.go`
- Modify: `admin_back_go/internal/module/payment/recharge_dto.go`
- Modify: `admin_back_go/internal/module/payment/recharge_service.go`

- [x] **Step 1: Update existing payment wallet summary**

Add `TotalConsumeCents` to `payment.Wallet`:

```go
TotalConsumeCents  int64     `gorm:"column:total_consume_cents"`
```

Add fields to `payment.WalletSummary`:

```go
TotalConsumeCents  int64  `json:"total_consume_cents"`
TotalConsumeText   string `json:"total_consume_text"`
```

Update `walletSummary` in `payment/recharge_service.go`:

```go
TotalConsumeCents:  wallet.TotalConsumeCents,
TotalConsumeText:   amountText(wallet.TotalConsumeCents),
```

- [x] **Step 2: Create `wallet/model.go`**

```go
package wallet

import "time"

type Wallet struct {
	ID                 int64     `gorm:"column:id;primaryKey"`
	UserID             int64     `gorm:"column:user_id"`
	BalanceCents       int64     `gorm:"column:balance_cents"`
	TotalRechargeCents int64     `gorm:"column:total_recharge_cents"`
	TotalConsumeCents  int64     `gorm:"column:total_consume_cents"`
	IsDel              int       `gorm:"column:is_del"`
	CreatedAt          time.Time `gorm:"column:created_at"`
	UpdatedAt          time.Time `gorm:"column:updated_at"`
}

func (Wallet) TableName() string { return "user_wallets" }

type Transaction struct {
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

func (Transaction) TableName() string { return "wallet_transactions" }

type WalletWithUser struct {
	Wallet
	Nickname string `gorm:"column:nickname"`
	Phone    string `gorm:"column:phone"`
	Email    string `gorm:"column:email"`
}

type TransactionWithUser struct {
	Transaction
	Nickname string `gorm:"column:nickname"`
	Phone    string `gorm:"column:phone"`
	Email    string `gorm:"column:email"`
}
```

- [x] **Step 3: Create `wallet/dto.go`**

```go
package wallet

const (
	DirectionIn  = "in"
	DirectionOut = "out"
	SourceRecharge = "recharge"
	SourceConsume  = "consume"
	defaultPageSize = 20
	maxPageSize     = 100
)

type Page struct {
	PageSize    int   `json:"page_size"`
	CurrentPage int   `json:"current_page"`
	TotalPage   int   `json:"total_page"`
	Total       int64 `json:"total"`
}

type SummaryResponse struct {
	BalanceCents       int64  `json:"balance_cents"`
	BalanceText        string `json:"balance_text"`
	TotalRechargeCents int64  `json:"total_recharge_cents"`
	TotalRechargeText  string `json:"total_recharge_text"`
	TotalConsumeCents  int64  `json:"total_consume_cents"`
	TotalConsumeText   string `json:"total_consume_text"`
}

type TransactionListQuery struct {
	CurrentPage int
	PageSize    int
	UserID      int64
	Keyword     string
	Direction   string
	SourceType  string
	DateStart   string
	DateEnd     string
}

type TransactionListResponse struct {
	List []TransactionItem `json:"list"`
	Page Page              `json:"page"`
}

type TransactionItem struct {
	ID                 int64  `json:"id"`
	TransactionNo      string `json:"transaction_no"`
	UserID             int64  `json:"user_id"`
	Nickname           string `json:"nickname"`
	Account            string `json:"account"`
	Direction          string `json:"direction"`
	DirectionText      string `json:"direction_text"`
	AmountCents        int64  `json:"amount_cents"`
	AmountText         string `json:"amount_text"`
	BalanceBeforeCents int64  `json:"balance_before_cents"`
	BalanceBeforeText  string `json:"balance_before_text"`
	BalanceAfterCents  int64  `json:"balance_after_cents"`
	BalanceAfterText   string `json:"balance_after_text"`
	SourceType         string `json:"source_type"`
	SourceTypeText     string `json:"source_type_text"`
	SourceID           int64  `json:"source_id"`
	Remark             string `json:"remark"`
	CreatedAt          string `json:"created_at"`
}

type WalletUserListQuery struct {
	CurrentPage int
	PageSize    int
	Keyword     string
	UserID      int64
}

type WalletUserListResponse struct {
	List []WalletUserItem `json:"list"`
	Page Page             `json:"page"`
}

type WalletUserItem struct {
	WalletID           int64  `json:"wallet_id"`
	UserID             int64  `json:"user_id"`
	Nickname           string `json:"nickname"`
	Account            string `json:"account"`
	BalanceCents       int64  `json:"balance_cents"`
	BalanceText        string `json:"balance_text"`
	TotalRechargeCents int64  `json:"total_recharge_cents"`
	TotalRechargeText  string `json:"total_recharge_text"`
	TotalConsumeCents  int64  `json:"total_consume_cents"`
	TotalConsumeText   string `json:"total_consume_text"`
	UpdatedAt          string `json:"updated_at"`
}

type ConsumeInput struct {
	UserID      int64
	AmountCents int64
	SourceID    int64
	Remark      string
}

type ConsumeResponse struct {
	Transaction TransactionItem `json:"transaction"`
	Wallet      SummaryResponse `json:"wallet"`
}
```

- [x] **Step 4: Create repository contract and implementation**

Create `admin_back_go/internal/module/wallet/repository.go`. Required exported surface:

```go
var ErrRepositoryNotConfigured = errors.New("wallet repository not configured")
var ErrInsufficientBalance = errors.New("wallet insufficient balance")

type Repository interface {
	GetOrCreateWallet(ctx context.Context, userID int64) (*Wallet, error)
	ListTransactions(ctx context.Context, query TransactionListQuery) ([]TransactionWithUser, int64, error)
	ListWalletUsers(ctx context.Context, query WalletUserListQuery) ([]WalletWithUser, int64, error)
	Consume(ctx context.Context, input ConsumeInput, now time.Time) (*Wallet, *Transaction, error)
}
```

Implementation requirements:

```text
1. NewGormRepository(client *database.Client) returns nil if client/Gorm is nil.
2. ListTransactions queries wallet_transactions wt left join users u.
3. ListWalletUsers queries user_wallets w left join users u.
4. Consume runs in one GORM transaction.
5. Consume locks user_wallets row with clause.Locking{Strength: "UPDATE"}.
6. Consume creates a zero wallet if none exists, then returns ErrInsufficientBalance for positive amount.
7. Consume checks existing source_type=consume + source_id before deducting.
8. Consume writes direction=out, amount_cents positive, before/after balances, source_type=consume.
```

Use these helper functions:

```go
func normalizePage(currentPage int, pageSize int) (int, int, int) {
	if currentPage <= 0 { currentPage = 1 }
	if pageSize <= 0 { pageSize = defaultPageSize }
	if pageSize > maxPageSize { pageSize = maxPageSize }
	return currentPage, pageSize, (currentPage - 1) * pageSize
}

func totalPage(total int64, pageSize int) int {
	if pageSize <= 0 { return 0 }
	pages := int(total) / pageSize
	if int(total)%pageSize != 0 { pages++ }
	return pages
}
```

- [x] **Step 5: Format and compile**

Run:

```powershell
cd E:\admin_go\admin_back_go
gofmt -w internal/module/payment/wallet_model.go internal/module/payment/recharge_dto.go internal/module/payment/recharge_service.go internal/module/wallet
go test ./internal/module/payment
```

Expected:

```text
payment package passes after WalletSummary changes.
wallet package will pass after Task 3 service/handler files are added.
```

---

## Task 3: Backend Wallet Service and Tests

**Files:**
- Create: `admin_back_go/internal/module/wallet/service.go`
- Create: `admin_back_go/internal/module/wallet/service_test.go`

- [x] **Step 1: Write service tests first**

Create `admin_back_go/internal/module/wallet/service_test.go`:

```go
package wallet

import (
	"context"
	"errors"
	"testing"
	"time"
)

func TestServiceSummaryCreatesZeroWallet(t *testing.T) {
	repo := &fakeRepo{}
	service := NewService(repo)
	result, appErr := service.Summary(context.Background(), 7)
	if appErr != nil { t.Fatalf("Summary error=%v", appErr) }
	if result.BalanceCents != 0 || result.TotalConsumeCents != 0 { t.Fatalf("unexpected summary=%#v", result) }
	if repo.wallet.UserID != 7 { t.Fatalf("expected wallet user id 7, got %#v", repo.wallet) }
}

func TestServiceConsumeRejectsInsufficientBalance(t *testing.T) {
	repo := &fakeRepo{consumeErr: ErrInsufficientBalance}
	service := NewService(repo)
	_, appErr := service.Consume(context.Background(), ConsumeInput{UserID: 7, AmountCents: 100, SourceID: 1})
	if appErr == nil || appErr.Message != "余额不足" { t.Fatalf("expected insufficient balance, got %v", appErr) }
}

func TestServiceConsumeReturnsTransactionAndWallet(t *testing.T) {
	now := time.Date(2026, 5, 21, 12, 0, 0, 0, time.UTC)
	repo := &fakeRepo{
		wallet: Wallet{ID: 1, UserID: 7, BalanceCents: 900, TotalRechargeCents: 1000, TotalConsumeCents: 100},
		transaction: Transaction{ID: 9, TransactionNo: "WTX1", WalletID: 1, UserID: 7, Direction: DirectionOut, AmountCents: 100, BalanceBeforeCents: 1000, BalanceAfterCents: 900, SourceType: SourceConsume, SourceID: 88, CreatedAt: now},
	}
	service := NewService(repo, WithNow(func() time.Time { return now }))
	result, appErr := service.Consume(context.Background(), ConsumeInput{UserID: 7, AmountCents: 100, SourceID: 88, Remark: "test"})
	if appErr != nil { t.Fatalf("Consume error=%v", appErr) }
	if result.Wallet.BalanceCents != 900 || result.Transaction.Direction != DirectionOut || result.Transaction.SourceType != SourceConsume { t.Fatalf("unexpected result=%#v", result) }
}

type fakeRepo struct {
	wallet      Wallet
	transaction Transaction
	consumeErr  error
}

func (r *fakeRepo) GetOrCreateWallet(ctx context.Context, userID int64) (*Wallet, error) {
	if r.wallet.UserID == 0 { r.wallet = Wallet{ID: 1, UserID: userID} }
	return &r.wallet, nil
}

func (r *fakeRepo) ListTransactions(ctx context.Context, query TransactionListQuery) ([]TransactionWithUser, int64, error) { return nil, 0, nil }
func (r *fakeRepo) ListWalletUsers(ctx context.Context, query WalletUserListQuery) ([]WalletWithUser, int64, error) { return nil, 0, nil }
func (r *fakeRepo) Consume(ctx context.Context, input ConsumeInput, now time.Time) (*Wallet, *Transaction, error) {
	if r.consumeErr != nil { return nil, nil, r.consumeErr }
	if r.transaction.ID == 0 { return nil, nil, errors.New("missing transaction fixture") }
	return &r.wallet, &r.transaction, nil
}
```

- [x] **Step 2: Verify failing test**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/wallet
```

Expected before implementation:

```text
FAIL with undefined: NewService or missing methods.
```

- [x] **Step 3: Implement service**

Create `admin_back_go/internal/module/wallet/service.go` with:

```go
type Service struct {
	repo Repository
	now  func() time.Time
}

type Option func(*Service)

func WithNow(fn func() time.Time) Option {
	return func(s *Service) { if fn != nil { s.now = fn } }
}

func NewService(repo Repository, opts ...Option) *Service {
	s := &Service{repo: repo, now: time.Now}
	for _, opt := range opts { opt(s) }
	return s
}
```

Required methods:

```go
func (s *Service) Summary(ctx context.Context, userID int64) (*SummaryResponse, *apperror.Error)
func (s *Service) ListTransactions(ctx context.Context, query TransactionListQuery) (*TransactionListResponse, *apperror.Error)
func (s *Service) ListWalletUsers(ctx context.Context, query WalletUserListQuery) (*WalletUserListResponse, *apperror.Error)
func (s *Service) Consume(ctx context.Context, input ConsumeInput) (*ConsumeResponse, *apperror.Error)
```

Validation rules:

```text
Summary: userID > 0.
Consume: userID > 0, amount_cents > 0, source_id > 0.
ErrInsufficientBalance maps to apperror.BadRequest("余额不足").
Other repository errors wrap with apperror.CodeInternal.
```

Mapping helpers required:

```go
func amountText(cents int64) string { return fmt.Sprintf("%.2f", float64(cents)/100) }
func accountText(phone string, email string) string { if strings.TrimSpace(phone) != "" { return phone }; return strings.TrimSpace(email) }
func directionText(value string) string { if value == DirectionOut { return "消费" }; if value == DirectionIn { return "充值" }; return value }
func sourceTypeText(value string) string { if value == SourceConsume { return "消费" }; if value == SourceRecharge { return "充值" }; return value }
```

- [x] **Step 4: Run focused tests**

Run:

```powershell
cd E:\admin_go\admin_back_go
gofmt -w internal/module/wallet
go test ./internal/module/wallet ./internal/module/payment
```

Expected:

```text
ok admin_back_go/internal/module/wallet
ok admin_back_go/internal/module/payment
```

---

## Task 4: Backend Routes, RBAC, Bootstrap

**Files:**
- Create: `admin_back_go/internal/module/wallet/request.go`
- Create: `admin_back_go/internal/module/wallet/handler.go`
- Create: `admin_back_go/internal/module/wallet/route.go`
- Create: `admin_back_go/internal/module/wallet/handler_test.go`
- Modify: `admin_back_go/internal/server/router.go`
- Modify: `admin_back_go/internal/bootstrap/app.go`
- Modify: `admin_back_go/internal/bootstrap/route_meta.go`
- Modify: `admin_back_go/internal/bootstrap/route_meta_test.go`

- [x] **Step 1: Add request structs**

Create `admin_back_go/internal/module/wallet/request.go`:

```go
package wallet

type listTransactionsRequest struct {
	CurrentPage int    `form:"current_page" binding:"omitempty,min=1"`
	PageSize    int    `form:"page_size" binding:"omitempty,min=1,max=100"`
	Keyword     string `form:"keyword" binding:"omitempty,max=64"`
	Direction   string `form:"direction" binding:"omitempty,oneof=in out"`
	SourceType  string `form:"source_type" binding:"omitempty,oneof=recharge consume"`
	DateStart   string `form:"date_start" binding:"omitempty,max=32"`
	DateEnd     string `form:"date_end" binding:"omitempty,max=32"`
}

type listWalletUsersRequest struct {
	CurrentPage int    `form:"current_page" binding:"omitempty,min=1"`
	PageSize    int    `form:"page_size" binding:"omitempty,min=1,max=100"`
	Keyword     string `form:"keyword" binding:"omitempty,max=64"`
	UserID      int64  `form:"user_id" binding:"omitempty,min=1"`
}

type consumeRequest struct {
	AmountCents int64  `json:"amount_cents" binding:"required,min=1"`
	SourceID    int64  `json:"source_id" binding:"required,min=1"`
	Remark      string `json:"remark" binding:"omitempty,max=255"`
}
```

- [x] **Step 2: Add route registration**

Create `admin_back_go/internal/module/wallet/route.go`:

```go
package wallet

import (
	"admin_back_go/internal/validate"
	"github.com/gin-gonic/gin"
)

func RegisterRoutes(router *gin.Engine, service HTTPService) {
	validate.MustRegister()
	handler := NewHandler(service)
	group := router.Group("/api/admin/v1/wallet")
	group.GET("/summary", handler.Summary)
	group.GET("/transactions", handler.MyTransactions)
	group.POST("/consumptions", handler.Consume)
	group.GET("/users/page-init", handler.AdminPageInit)
	group.GET("/users", handler.AdminWalletUsers)
	group.GET("/ledger/page-init", handler.AdminPageInit)
	group.GET("/ledger", handler.AdminLedger)
}
```

- [x] **Step 3: Implement handler**

Create `admin_back_go/internal/module/wallet/handler.go`.

Required handler methods:

```go
func (h *Handler) Summary(c *gin.Context)
func (h *Handler) MyTransactions(c *gin.Context)
func (h *Handler) Consume(c *gin.Context)
func (h *Handler) AdminPageInit(c *gin.Context)
func (h *Handler) AdminWalletUsers(c *gin.Context)
func (h *Handler) AdminLedger(c *gin.Context)
```

Auth helper:

```go
func authUserID(c *gin.Context) (int64, bool) {
	identity := middleware.GetAuthIdentity(c)
	if identity == nil || identity.UserID <= 0 {
		response.Error(c, apperror.Unauthorized("Token无效或已过期"))
		return 0, false
	}
	return identity.UserID, true
}
```

`AdminPageInit` response:

```go
gin.H{"dict": gin.H{
	"direction_arr": []gin.H{{"label": "充值", "value": DirectionIn}, {"label": "消费", "value": DirectionOut}},
	"source_type_arr": []gin.H{{"label": "充值", "value": SourceRecharge}, {"label": "消费", "value": SourceConsume}},
}}
```

- [x] **Step 4: Register module in server/bootstrap**

Modify `admin_back_go/internal/server/router.go`:

```go
import wallet "admin_back_go/internal/module/wallet"
```

Add dependency:

```go
WalletService wallet.HTTPService
```

Register after payment:

```go
payment.RegisterRoutes(router, deps.PaymentService)
wallet.RegisterRoutes(router, deps.WalletService)
```

Modify `admin_back_go/internal/bootstrap/app.go`:

```go
walletmodule "admin_back_go/internal/module/wallet"
```

Create service:

```go
walletService := walletmodule.NewService(walletmodule.NewGormRepository(resources.DB))
```

Pass dependency:

```go
WalletService: walletService,
```

- [x] **Step 5: Add route permission metadata**

In `permissionRouteRules()` add:

```go
middleware.NewRouteKey(http.MethodGet, "/api/admin/v1/wallet/summary"):          "wallet_transaction_list",
middleware.NewRouteKey(http.MethodGet, "/api/admin/v1/wallet/transactions"):     "wallet_transaction_list",
middleware.NewRouteKey(http.MethodPost, "/api/admin/v1/wallet/consumptions"):    "wallet_consume_add",
middleware.NewRouteKey(http.MethodGet, "/api/admin/v1/wallet/users/page-init"):  "wallet_user_list",
middleware.NewRouteKey(http.MethodGet, "/api/admin/v1/wallet/users"):            "wallet_user_list",
middleware.NewRouteKey(http.MethodGet, "/api/admin/v1/wallet/ledger/page-init"): "wallet_ledger_list",
middleware.NewRouteKey(http.MethodGet, "/api/admin/v1/wallet/ledger"):           "wallet_ledger_list",
```

In `operationRouteRules()` add:

```go
middleware.NewRouteKey(http.MethodPost, "/api/admin/v1/wallet/consumptions"): {
	Module: "wallet",
	Action: "consume",
	Title:  "钱包消费",
},
```

- [x] **Step 6: Add route test**

Create `admin_back_go/internal/module/wallet/handler_test.go`:

```go
package wallet

import (
	"net/http"
	"testing"
	"github.com/gin-gonic/gin"
)

func TestRegisterRoutesInstallsWalletEndpoints(t *testing.T) {
	gin.SetMode(gin.TestMode)
	router := gin.New()
	RegisterRoutes(router, nil)
	want := map[string]bool{
		http.MethodGet + " /api/admin/v1/wallet/summary": false,
		http.MethodGet + " /api/admin/v1/wallet/transactions": false,
		http.MethodPost + " /api/admin/v1/wallet/consumptions": false,
		http.MethodGet + " /api/admin/v1/wallet/users/page-init": false,
		http.MethodGet + " /api/admin/v1/wallet/users": false,
		http.MethodGet + " /api/admin/v1/wallet/ledger/page-init": false,
		http.MethodGet + " /api/admin/v1/wallet/ledger": false,
	}
	for _, route := range router.Routes() {
		key := route.Method + " " + route.Path
		if _, ok := want[key]; ok { want[key] = true }
	}
	for key, ok := range want {
		if !ok { t.Fatalf("missing route %s", key) }
	}
}
```

- [x] **Step 7: Backend focused verification**

Run:

```powershell
cd E:\admin_go\admin_back_go
gofmt -w internal/module/wallet internal/server/router.go internal/bootstrap/app.go internal/bootstrap/route_meta.go internal/bootstrap/route_meta_test.go internal/module/payment/wallet_model.go internal/module/payment/recharge_dto.go internal/module/payment/recharge_service.go
go test ./internal/module/wallet ./internal/module/payment ./internal/server ./internal/bootstrap
go vet ./internal/module/wallet ./internal/module/payment ./internal/server ./internal/bootstrap
```

Expected:

```text
All pass.
```

---

## Task 5: Frontend Wallet API and Pages

**Files:**
- Create: `admin_front_ts/src/api/wallet/index.ts`
- Create: `admin_front_ts/src/views/Main/wallet/transactions/index.vue`
- Create: `admin_front_ts/src/views/Main/wallet/users/index.vue`
- Create: `admin_front_ts/src/views/Main/wallet/ledger/index.vue`
- Create: `admin_front_ts/tests/shared/wallet/wallet-api.test.ts`
- Create: `admin_front_ts/tests/shared/wallet/wallet-pages.test.ts`
- Modify: `admin_front_ts/src/api/payment/recharges.ts`
- Modify: `admin_front_ts/src/i18n/locales/zh-CN.ts`
- Modify: `admin_front_ts/src/i18n/locales/en-US.ts`

- [x] **Step 1: Update recharge wallet summary type**

In `admin_front_ts/src/api/payment/recharges.ts`, add:

```ts
total_consume_cents: number
total_consume_text: string
```

- [x] **Step 2: Create wallet API**

Create `admin_front_ts/src/api/wallet/index.ts`:

```ts
import request from '@/lib/http'
import { ADMIN_API_PREFIX } from '@/lib/http/api-prefix'
import type { DictOption, PaginatedResponse } from '@/types/common'

export type WalletDirection = 'in' | 'out'
export type WalletSourceType = 'recharge' | 'consume'

export interface WalletSummaryResponse {
  balance_cents: number
  balance_text: string
  total_recharge_cents: number
  total_recharge_text: string
  total_consume_cents: number
  total_consume_text: string
}

export interface WalletTransactionItem {
  id: number
  transaction_no: string
  user_id: number
  nickname: string
  account: string
  direction: WalletDirection
  direction_text: string
  amount_cents: number
  amount_text: string
  balance_before_cents: number
  balance_before_text: string
  balance_after_cents: number
  balance_after_text: string
  source_type: WalletSourceType
  source_type_text: string
  source_id: number
  remark: string
  created_at: string
}

export interface WalletTransactionListParams {
  current_page: number
  page_size: number
  keyword?: string
  direction?: WalletDirection | ''
  source_type?: WalletSourceType | ''
  date_start?: string
  date_end?: string
}

export interface WalletUserItem {
  wallet_id: number
  user_id: number
  nickname: string
  account: string
  balance_cents: number
  balance_text: string
  total_recharge_cents: number
  total_recharge_text: string
  total_consume_cents: number
  total_consume_text: string
  updated_at: string
}

export interface WalletUserListParams {
  current_page: number
  page_size: number
  keyword?: string
  user_id?: number
}

export interface WalletPageInitResponse {
  dict: {
    direction_arr: DictOption<WalletDirection>[]
    source_type_arr: DictOption<WalletSourceType>[]
  }
}

export interface WalletConsumePayload {
  amount_cents: number
  source_id: number
  remark?: string
}

export interface WalletConsumeResponse {
  transaction: WalletTransactionItem
  wallet: WalletSummaryResponse
}

const BASE = `${ADMIN_API_PREFIX}/wallet`

export const WalletApi = {
  summary: () => request.get<WalletSummaryResponse>(`${BASE}/summary`),
  transactions: (params: WalletTransactionListParams) => request.get<PaginatedResponse<WalletTransactionItem>>(`${BASE}/transactions`, { params }),
  consume: (payload: WalletConsumePayload) => request.post<WalletConsumeResponse, WalletConsumePayload>(`${BASE}/consumptions`, payload),
  usersInit: () => request.get<WalletPageInitResponse>(`${BASE}/users/page-init`),
  users: (params: WalletUserListParams) => request.get<PaginatedResponse<WalletUserItem>>(`${BASE}/users`, { params }),
  ledgerInit: () => request.get<WalletPageInitResponse>(`${BASE}/ledger/page-init`),
  ledger: (params: WalletTransactionListParams) => request.get<PaginatedResponse<WalletTransactionItem>>(`${BASE}/ledger`, { params }),
}
```

- [x] **Step 3: Add API test**

Create `admin_front_ts/tests/shared/wallet/wallet-api.test.ts`:

```ts
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { describe, expect, it } from 'vitest'

const read = (path: string) => readFileSync(resolve(process.cwd(), path), 'utf8')
const loose = new RegExp(`\\b${'an'}${'y'}\\b|as ${'an'}${'y'}|Record<string, ${'an'}${'y'}>`)

describe('wallet api', () => {
  it('uses canonical wallet REST paths and strict types', () => {
    const source = read('src/api/wallet/index.ts')
    expect(source).toContain('`${BASE}/summary`')
    expect(source).toContain('`${BASE}/transactions`')
    expect(source).toContain('`${BASE}/consumptions`')
    expect(source).toContain('`${BASE}/users/page-init`')
    expect(source).toContain('`${BASE}/users`')
    expect(source).toContain('`${BASE}/ledger/page-init`')
    expect(source).toContain('`${BASE}/ledger`')
    expect(source).toContain("export type WalletDirection = 'in' | 'out'")
    expect(source).toContain("export type WalletSourceType = 'recharge' | 'consume'")
    expect(source).toContain('total_consume_cents: number')
    expect(source).not.toContain('refund')
    expect(source).not.toContain('frozen')
    expect(source).not.toMatch(loose)
  })
})
```

- [x] **Step 4: Create read pages**

Create three pages:

```text
admin_front_ts/src/views/Main/wallet/transactions/index.vue
admin_front_ts/src/views/Main/wallet/users/index.vue
admin_front_ts/src/views/Main/wallet/ledger/index.vue
```

Each page must:

```text
1. Use <script setup lang="ts">.
2. Import Search from '@/components/Search'.
3. Import AppTable and TableColumn from '@/components/Table'.
4. Import WalletApi and strict wallet types from '@/api/wallet'.
5. Use useTable.
6. Avoid any / as any / Record<string, any>.
7. Maintain a flex height chain: root div height:100%; min-height:0; overflow:hidden.
```

`transactions` uses `WalletApi.transactions` and columns:

```text
transaction_no, direction_text, amount_text, balance_before_text, balance_after_text, source_type_text, remark, created_at
```

`users` uses `WalletApi.users` and columns:

```text
user_id, nickname, account, balance_text, total_recharge_text, total_consume_text, updated_at
```

`ledger` uses `WalletApi.ledger` and columns:

```text
transaction_no, user_id, nickname, account, direction_text, amount_text, balance_before_text, balance_after_text, source_type_text, remark, created_at
```

- [x] **Step 5: Add page tests**

Create `admin_front_ts/tests/shared/wallet/wallet-pages.test.ts`:

```ts
import { readFileSync } from 'node:fs'
import { existsSync } from 'node:fs'
import { resolve } from 'node:path'
import { describe, expect, it } from 'vitest'

const read = (path: string) => readFileSync(resolve(process.cwd(), path), 'utf8')
const loose = new RegExp(`\\b${'an'}${'y'}\\b|as ${'an'}${'y'}|Record<string, ${'an'}${'y'}>`)

describe('wallet pages', () => {
  it('adds wallet pages with shared table components', () => {
    const files = ['src/views/Main/wallet/transactions/index.vue', 'src/views/Main/wallet/users/index.vue', 'src/views/Main/wallet/ledger/index.vue']
    for (const file of files) {
      expect(existsSync(resolve(process.cwd(), file))).toBe(true)
      const source = read(file)
      expect(source).toContain("import { Search } from '@/components/Search'")
      expect(source).toContain("import { AppTable")
      expect(source).toContain("from '@/api/wallet'")
      expect(source).toContain('useTable')
      expect(source).not.toMatch(loose)
    }
  })

  it('adds wallet menu locale labels', () => {
    const zh = read('src/i18n/locales/zh-CN.ts')
    const en = read('src/i18n/locales/en-US.ts')
    expect(zh).toContain("wallet_center: '钱包中心'")
    expect(zh).toContain("wallet_transaction: '资金明细'")
    expect(zh).toContain("wallet_manage: '钱包管理'")
    expect(zh).toContain("wallet_user: '用户钱包'")
    expect(zh).toContain("wallet_ledger: '资金流水'")
    expect(en).toContain("wallet_center: 'Wallet Center'")
    expect(en).toContain("wallet_transaction: 'Funds Detail'")
    expect(en).toContain("wallet_manage: 'Wallet Management'")
    expect(en).toContain("wallet_user: 'User Wallets'")
    expect(en).toContain("wallet_ledger: 'Funds Ledger'")
  })
})
```

- [x] **Step 6: Add locale labels**

In `zh-CN.ts`:

```ts
wallet_center: '钱包中心',
wallet_transaction: '资金明细',
wallet_manage: '钱包管理',
wallet_user: '用户钱包',
wallet_ledger: '资金流水',
```

In `en-US.ts`:

```ts
wallet_center: 'Wallet Center',
wallet_transaction: 'Funds Detail',
wallet_manage: 'Wallet Management',
wallet_user: 'User Wallets',
wallet_ledger: 'Funds Ledger',
```

- [x] **Step 7: Frontend focused verification**

Run:

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/wallet/wallet-api.test.ts tests/shared/wallet/wallet-pages.test.ts tests/shared/payment/payment-recharge-page.test.ts
npx vue-tsc -b --pretty false
```

Expected:

```text
All selected Vitest tests pass.
vue-tsc passes.
```

---

## Task 6: Docs, Smoke, Runtime Verification

**Files:**
- Modify: `docs/contracts/admin-api-v1.md`
- Modify: `docs/status/current-status.md`
- Modify: `docs/testing/smoke-matrix.md`
- Modify: `admin_back_go/scripts/full-admin-smoke.ps1`

- [x] **Step 1: Update API contract**

In `docs/contracts/admin-api-v1.md`, add a `Wallet` section:

```text
active tables: user_wallets, wallet_transactions
active pages: /wallet/transactions, /wallet/users, /wallet/ledger
product rule: payment_orders is the Alipay collection ledger; wallet_transactions is the funds ledger for recharge in and consume out
no refund / withdraw / freeze / adjustment / reconcile in v1
```

Routes:

```text
GET  /api/admin/v1/wallet/summary
GET  /api/admin/v1/wallet/transactions
POST /api/admin/v1/wallet/consumptions
GET  /api/admin/v1/wallet/users/page-init
GET  /api/admin/v1/wallet/users
GET  /api/admin/v1/wallet/ledger/page-init
GET  /api/admin/v1/wallet/ledger
```

- [x] **Step 2: Update status and smoke matrix**

In `docs/status/current-status.md`, add wallet v1 status:

```text
wallet recharge/consume v1: implemented baseline: user_wallets.total_consume_cents, wallet_transactions read ledger, current-user wallet summary/transactions, admin wallet users/ledger, and guarded consume API. Consumption is wallet-only balance deduction; it does not create payment_orders and does not imply refund/withdraw/freeze/adjustment/reconcile support.
```

In `docs/testing/smoke-matrix.md`, add:

```text
wallet read ledger | no | yes | GET /api/admin/v1/wallet/summary, GET /api/admin/v1/wallet/transactions, GET /api/admin/v1/wallet/users/page-init, GET /api/admin/v1/wallet/users, GET /api/admin/v1/wallet/ledger/page-init, GET /api/admin/v1/wallet/ledger | no default mutation | n/a | consume API is mutation-gated and not run by default smoke
```

- [x] **Step 3: Add smoke probes**

In `admin_back_go/scripts/full-admin-smoke.ps1`, add read-only probes after payment probes using the existing script helper names:

```powershell
$walletSummary = Invoke-AdminApi -Method GET -Path '/api/admin/v1/wallet/summary'
Assert-Ok $walletSummary 'wallet_summary'
Assert-HasField $walletSummary.data 'balance_cents' 'wallet_summary.balance_cents'
Assert-HasField $walletSummary.data 'total_consume_cents' 'wallet_summary.total_consume_cents'

$walletTransactions = Invoke-AdminApi -Method GET -Path '/api/admin/v1/wallet/transactions?current_page=1&page_size=10'
Assert-Ok $walletTransactions 'wallet_transactions'
Assert-HasField $walletTransactions.data 'list' 'wallet_transactions.list'

$walletUsers = Invoke-AdminApi -Method GET -Path '/api/admin/v1/wallet/users?current_page=1&page_size=10'
Assert-Ok $walletUsers 'wallet_users'
Assert-HasField $walletUsers.data 'list' 'wallet_users.list'

$walletLedger = Invoke-AdminApi -Method GET -Path '/api/admin/v1/wallet/ledger?current_page=1&page_size=10'
Assert-Ok $walletLedger 'wallet_ledger'
Assert-HasField $walletLedger.data 'list' 'wallet_ledger.list'
```

If the real script uses different helper names, adapt to the existing helper names while preserving the four read-only probes.

- [x] **Step 4: Backend and frontend verification**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/wallet ./internal/module/payment ./internal/server ./internal/bootstrap
go vet ./internal/module/wallet ./internal/module/payment ./internal/server ./internal/bootstrap

cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/wallet/wallet-api.test.ts tests/shared/wallet/wallet-pages.test.ts tests/shared/payment/payment-recharge-page.test.ts
npx vue-tsc -b --pretty false
```

Expected:

```text
All commands pass.
```

- [x] **Step 5: Rebuild and restart backend**

Run:

```powershell
cd E:\admin_go\.docker\admin-go-backend
docker compose up -d --build
docker ps --format "table {{.Names}}`t{{.Status}}`t{{.Ports}}" | Select-String -Pattern 'admin-go|NAMES'
Invoke-RestMethod http://127.0.0.1:8080/health
Invoke-RestMethod http://127.0.0.1:8080/ready
```

Expected:

```text
admin-go-backend-admin-api-1 healthy.
admin-go-backend-admin-worker-1 up.
/health and /ready return OK.
```

- [x] **Step 6: Live API verification**

Run:

```powershell
$base='http://127.0.0.1:8080'
$account='15671628271'
$device='codex-wallet-v1-check'
Invoke-RestMethod "$base/api/admin/v1/auth/send-code" -Method Post -ContentType 'application/json' -Body (@{account=$account;scene='login'}|ConvertTo-Json) | Out-Null
$login=Invoke-RestMethod "$base/api/admin/v1/auth/login" -Method Post -Headers @{platform='admin';'device-id'=$device} -ContentType 'application/json' -Body (@{login_account=$account;login_type='phone';code='123456'}|ConvertTo-Json)
$headers=@{platform='admin';'device-id'=$device;Authorization="Bearer $($login.data.access_token)"}
$summary=Invoke-RestMethod "$base/api/admin/v1/wallet/summary" -Headers $headers
$transactions=Invoke-RestMethod "$base/api/admin/v1/wallet/transactions?current_page=1&page_size=5" -Headers $headers
$users=Invoke-RestMethod "$base/api/admin/v1/wallet/users?current_page=1&page_size=5" -Headers $headers
$ledger=Invoke-RestMethod "$base/api/admin/v1/wallet/ledger?current_page=1&page_size=5" -Headers $headers
$summary.data | ConvertTo-Json -Depth 5
$transactions.data.page | ConvertTo-Json -Depth 5
$users.data.page | ConvertTo-Json -Depth 5
$ledger.data.page | ConvertTo-Json -Depth 5
```

Expected:

```text
summary includes total_consume_cents.
transactions/users/ledger return code=0 and page objects.
```

- [x] **Step 7: Final governance checks**

Run:

```powershell
cd E:\admin_go
git diff --check
git -C .\admin_back_go diff --check
git -C .\admin_front_ts diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected:

```text
All pass.
```

---

## Self-Review Checklist

- [x] Spec coverage: total consume field, wallet ledger, admin wallet users, admin ledger, consume API, no refund/withdraw/freeze/adjustment concepts.
- [x] Product boundary: payment orders remain Alipay collection; wallet transactions carry recharge and consume funds truth.
- [x] Type consistency: `total_consume_cents`, `DirectionOut`, `SourceConsume`, `/api/admin/v1/wallet/*` match across backend, frontend, docs, and tests.
- [x] No hidden default mutation: smoke remains read-only; consume requires `wallet_consume_add` and explicit call.
- [x] Runtime proof required before completion: live SQL applied, backend rebuilt, `/health` and `/ready` OK, live wallet APIs return `code=0`.
