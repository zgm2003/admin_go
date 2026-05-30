# 支付钱包与 AI 计费整改 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 admin 系统内把支付/钱包菜单、钱包借贷能力、AI 场景计费和 admin AI 图片生成扣费收成一套可用账务闭环。

**Architecture:** 钱的唯一事实源仍是 `user_wallets` + `wallet_transactions`。支付网关订单只服务支付宝 runtime，不再做可见菜单；AI 计费规则由 AI 智能体配置页维护，`ai_billing_records` 只在接入当前 admin AI 图片工作台时落库并被使用。

**Tech Stack:** Go 1.26 + Gin + GORM + MySQL/InnoDB；Vue 3 + TypeScript + Element Plus + vue-i18n；Vitest + Go unit tests + root governance checker。

---

## Scope Gates

- 只改 `E:\admin_go` 的 admin 系统：`admin_back_go`、`admin_front_ts`、root docs。
- 不改 `canvas_front_next`，不新增 `/api/canvas/*`，不接 infinite-canvas 运行时。
- 不新增积分表、credit 表、ledger 重复表。
- `ai_billing_records` 必须在同一实施里接入 `POST /api/admin/v1/ai-images`；如果这个接入任务被取消，就不要创建这张表。
- 没有当前调用方的菜单、按钮、页面、HTTP route 不保留；隐藏入口必须有明确入口：右上角用户菜单或充值按钮。

## File Structure Map

### Root docs
- Modify: `docs/superpowers/specs/2026-05-30-payment-wallet-billing-redesign-design.md`
- Modify: `docs/status/module-matrix.md`
- Modify: `docs/contracts/admin-api-v1.md`
- Modify: `docs/testing/smoke-matrix.md`

### Backend
- Create: `admin_back_go/database/migrations/20260530_payment_wallet_billing_redesign.sql`
- Create: `admin_back_go/internal/architecture/payment_wallet_billing_redesign_test.go`
- Modify: `admin_back_go/internal/bootstrap/route_meta.go`
- Modify: `admin_back_go/internal/bootstrap/route_meta_test.go`
- Modify: `admin_back_go/internal/module/payment/transport/admin/route.go`
- Modify: `admin_back_go/internal/module/payment/wallet/dto.go`
- Modify: `admin_back_go/internal/module/payment/wallet/model.go`
- Modify: `admin_back_go/internal/module/payment/wallet/repository.go`
- Modify: `admin_back_go/internal/module/payment/wallet/repository_test.go`
- Modify: `admin_back_go/internal/module/payment/wallet/service.go`
- Modify: `admin_back_go/internal/module/payment/wallet/service_test.go`
- Modify: `admin_back_go/internal/module/payment/wallet/transport/admin/handler.go`
- Modify: `admin_back_go/internal/module/payment/wallet/transport/admin/handler_test.go`
- Modify: `admin_back_go/internal/module/payment/wallet/transport/admin/route.go`
- Create: `admin_back_go/internal/module/ai/billing/{dto.go,model.go,repository.go,repository_test.go,service.go,service_test.go}`
- Create: `admin_back_go/internal/module/ai/billing/transport/admin/{handler.go,request.go,route.go,handler_test.go}`
- Modify: `admin_back_go/internal/server/router.go`
- Modify: `admin_back_go/internal/bootstrap/app.go`
- Modify: `admin_back_go/internal/module/ai/image/{dto.go,model.go,repository.go,service.go,service_test.go,jobs_test.go}`
- Create/Modify i18n: `admin_back_go/internal/shared/i18n/locales/{zh-CN,en-US}/{wallet.yaml,aiimage.yaml,aibilling.yaml}`

### Frontend
- Modify: `admin_front_ts/src/api/wallet/index.ts`
- Create: `admin_front_ts/src/api/ai/billingRules.ts`
- Create: `admin_front_ts/src/views/Main/payment/ledger/index.vue`
- Create: `admin_front_ts/src/views/Main/payment/wallets/index.vue`
- Create: `admin_front_ts/src/views/Main/personal/wallet/index.vue`
- Modify: `admin_front_ts/src/views/Layout/components/Aside/index.vue`
- Modify: `admin_front_ts/src/views/Main/payment/recharge/index.vue`
- Modify: `admin_front_ts/src/views/Main/payment/recharge/composables/usePaymentRechargePage.ts`
- Remove: `admin_front_ts/src/api/payment/orders.ts`
- Remove: `admin_front_ts/src/views/Main/payment/orders/`
- Remove: `admin_front_ts/src/views/Main/wallet/{ledger,users,transactions}/`
- Modify: `admin_front_ts/src/views/Main/ai/agents/index.vue`
- Create: `admin_front_ts/src/views/Main/ai/agents/components/AgentBillingDialog/index.vue`
- Modify: `admin_front_ts/src/i18n/locales/{zh-CN.ts,en-US.ts}`
- Create: `admin_front_ts/tests/shared/payment-wallet-billing-redesign.test.ts`
- Create: `admin_front_ts/tests/shared/ai/ai-billing-rule-api.test.ts`

---

### Task 1: Lock the contract with failing tests

**Files:**
- Create: `admin_back_go/internal/architecture/payment_wallet_billing_redesign_test.go`
- Create: `admin_front_ts/tests/shared/payment-wallet-billing-redesign.test.ts`
- Create: `admin_front_ts/tests/shared/ai/ai-billing-rule-api.test.ts`

- [x] **Step 1: Write backend architecture test**

Create `payment_wallet_billing_redesign_test.go` that reads `database/migrations/20260530_payment_wallet_billing_redesign.sql`, `payment/transport/admin/route.go`, and `payment/wallet/transport/admin/route.go`. Assert the migration contains `ai_billing_rules`, `ai_billing_records`, `billing_record_id`, `/payment/ledger`, `/payment/wallets`, `/profile/wallet`, `payment_ledger_list`, `payment_wallet_list`, `ai_billing_rule_edit`. Assert it does not contain `credit_logs`, `canvas_credit_logs`, `wallet_ledger`, `payment_bill`, `points`. Assert route files do not expose `/api/admin/v1/payment/orders`, `/:id/sync`, `/:id/close`, `/consumptions`, `/wallet/ledger`, `/wallet/users`.

- [x] **Step 2: Write frontend contract tests**

`payment-wallet-billing-redesign.test.ts` must assert:

```ts
expect(existsSync(resolve(process.cwd(), 'src/views/Main/payment/ledger/index.vue'))).toBe(true)
expect(existsSync(resolve(process.cwd(), 'src/views/Main/payment/wallets/index.vue'))).toBe(true)
expect(existsSync(resolve(process.cwd(), 'src/views/Main/personal/wallet/index.vue'))).toBe(true)
expect(existsSync(resolve(process.cwd(), 'src/views/Main/payment/orders/index.vue'))).toBe(false)
expect(existsSync(resolve(process.cwd(), 'src/views/Main/wallet/ledger/index.vue'))).toBe(false)
expect(existsSync(resolve(process.cwd(), 'src/views/Main/wallet/users/index.vue'))).toBe(false)
expect(existsSync(resolve(process.cwd(), 'src/views/Main/wallet/transactions/index.vue'))).toBe(false)
```

Also assert `Aside/index.vue` contains `command="wallet"` and `router.push({ path: '/profile/wallet' })`, and `usePaymentRechargePage.ts` does not contain `.sync(` or `manualSync`.

`ai-billing-rule-api.test.ts` must assert `src/api/ai/billingRules.ts` contains `AiBillingRuleApi`, `${ADMIN_API_PREFIX}/ai-billing-rules/page-init`, `${ADMIN_API_PREFIX}/ai-billing-rules`, and does not contain `/api/canvas`, `credit`, or `points`.

- [x] **Step 3: Verify tests fail red**

Run:

```powershell
cd admin_back_go
go test ./internal/architecture -run PaymentWalletBillingRedesign -count=1
cd ..\admin_front_ts
npm run test -- --run tests/shared/payment-wallet-billing-redesign.test.ts tests/shared/ai/ai-billing-rule-api.test.ts
```

Expected: tests fail because migration and new frontend/API files do not exist yet.

### Task 2: Add the MySQL migration for only-used tables, indexes, and permissions

**Files:**
- Create: `admin_back_go/database/migrations/20260530_payment_wallet_billing_redesign.sql`

- [x] **Step 1: Create guarded migration SQL**

Use the project’s `information_schema` + prepared-statement migration style. Target schema:

```sql
CREATE TABLE `ai_billing_rules` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `scene` VARCHAR(64) NOT NULL,
  `unit` VARCHAR(16) NOT NULL,
  `unit_price_cents` BIGINT NOT NULL,
  `status` TINYINT NOT NULL DEFAULT 1,
  `is_del` TINYINT NOT NULL DEFAULT 2,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_ai_billing_rules_scene` (`scene`),
  KEY `idx_ai_billing_rules_status` (`status`, `is_del`, `scene`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `ai_billing_records` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `request_no` VARCHAR(64) NOT NULL,
  `user_id` BIGINT NOT NULL,
  `platform` VARCHAR(32) NOT NULL,
  `scene` VARCHAR(64) NOT NULL,
  `agent_id` BIGINT NOT NULL,
  `provider_id` BIGINT NOT NULL,
  `model_id` VARCHAR(191) NOT NULL,
  `unit` VARCHAR(16) NOT NULL,
  `unit_count` INT NOT NULL,
  `unit_price_cents` BIGINT NOT NULL,
  `amount_cents` BIGINT NOT NULL,
  `status` VARCHAR(16) NOT NULL,
  `debit_transaction_id` BIGINT NULL,
  `refund_transaction_id` BIGINT NULL,
  `provider_task_id` VARCHAR(128) NOT NULL DEFAULT '',
  `error_message` VARCHAR(512) NOT NULL DEFAULT '',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `finished_at` DATETIME NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_ai_billing_records_request_no` (`request_no`),
  KEY `idx_ai_billing_records_user_created` (`user_id`, `created_at`, `id`),
  KEY `idx_ai_billing_records_scene_created` (`scene`, `created_at`, `id`),
  KEY `idx_ai_billing_records_status_created` (`status`, `created_at`, `id`),
  KEY `idx_ai_billing_records_provider_task` (`provider_id`, `provider_task_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

Do not add `is_del` to `ai_billing_records`. This table is an accounting fact and the source anchor for `wallet_transactions`; it must not have a soft-delete path. Lifecycle is represented only by `status`.

Add `ai_image_tasks.billing_record_id BIGINT UNSIGNED NULL` and `idx_ai_image_tasks_billing_record_id(billing_record_id)` because admin AI image generation is the first current caller.

Add indexes if missing:

```text
wallet_transactions: idx_wallet_tx_admin_created(is_del, created_at, id)
wallet_transactions: idx_wallet_tx_admin_direction_created(direction, is_del, created_at, id)
wallet_transactions: idx_wallet_tx_admin_source_created(source_type, is_del, created_at, id)
user_wallets: idx_user_wallet_updated(is_del, updated_at, id)
```

- [x] **Step 2: Migrate permissions and menus**

Visible menu after migration:

```text
/payment          支付管理
/payment/config   支付配置
/payment/ledger   收支明细
/payment/wallets  用户钱包
```

Active hidden pages with callers:

```text
/payment/recharge  from 我的钱包 recharge button
/profile/wallet    from top-right user dropdown
```

Retire old visible records with `is_del = 1`:

```text
/wallet
/wallet-manage
/wallet/transactions
/wallet/ledger
/wallet/users
/payment/orders
```

Grant active roles:

```text
payment_config_list
payment_ledger_list
payment_wallet_list
payment_recharge_list
payment_recharge_add
payment_recharge_pay
profile_wallet
ai_billing_rule_edit
```

- [x] **Step 3: Run migration contract test green**

Run:

```powershell
cd admin_back_go
go test ./internal/architecture -run PaymentWalletBillingRedesign -count=1
```

Expected: `ok admin_back_go/internal/architecture`.

### Task 3: Replace wallet “consume” with real Debit/Credit primitives

**Files:**
- Modify: `admin_back_go/internal/module/payment/wallet/dto.go`
- Modify: `admin_back_go/internal/module/payment/wallet/repository.go`
- Modify: `admin_back_go/internal/module/payment/wallet/repository_test.go`
- Modify: `admin_back_go/internal/module/payment/wallet/service.go`
- Modify: `admin_back_go/internal/module/payment/wallet/service_test.go`
- Modify: `admin_back_go/internal/shared/i18n/locales/{zh-CN,en-US}/wallet.yaml`

- [x] **Step 1: Write wallet service tests**

Add tests for:

```text
Debit rejects amount_cents <= 0.
Debit rejects invalid source_type.
Debit returns wallet.debit.insufficient_balance and writes no transaction when balance is low.
Debit writes direction=out, source_type=ai_generate, source_id=billing_record_id.
Credit writes direction=in, source_type=ai_refund, source_id=billing_record_id.
Credit returns existing transaction for same source_type/source_id.
Same source_type/source_id owned by another user returns owner mismatch.
```

- [x] **Step 2: Write wallet repository tests**

Use the current repository test style. Prove:

```text
wallet row is locked or created inside a DB transaction.
transaction row and wallet balance update are in one transaction.
duplicate uk_wallet_transaction_source returns existing same-user transaction.
duplicate uk_wallet_transaction_source for another user returns owner mismatch.
Debit increments total_consume_cents.
Credit does not decrement total_consume_cents.
```

- [x] **Step 3: Implement wallet DTO constants and input**

In `dto.go`:

```go
const (
	DirectionIn  = "in"
	DirectionOut = "out"

	SourceRecharge   = "recharge"
	SourceAIGenerate = "ai_generate"
	SourceAIRefund   = "ai_refund"

	defaultPageSize = 20
	maxPageSize     = 100
)

type MutationInput struct {
	UserID      int64
	AmountCents int64
	SourceType  string
	SourceID    int64
	Remark      string
}

type MutationResponse struct {
	Transaction TransactionItem `json:"transaction"`
	Wallet      SummaryResponse `json:"wallet"`
}
```

- [x] **Step 4: Implement repository methods**

Repository interface:

```go
type Repository interface {
	GetOrCreateWallet(ctx context.Context, userID int64) (*Wallet, error)
	ListTransactions(ctx context.Context, query TransactionListQuery) ([]TransactionWithUser, int64, error)
	ListWalletUsers(ctx context.Context, query WalletUserListQuery) ([]WalletWithUser, int64, error)
	Debit(ctx context.Context, input MutationInput, now time.Time) (*Wallet, *Transaction, error)
	Credit(ctx context.Context, input MutationInput, now time.Time) (*Wallet, *Transaction, error)
}
```

Implement a shared private `applyMutation(ctx, input, direction, now)` so Debit and Credit do not duplicate transaction code. Preserve `source_type + source_id` idempotency and same-user ownership checks.

- [x] **Step 5: Implement service methods**

Expose:

```go
func (s *Service) Debit(ctx context.Context, input MutationInput) (*MutationResponse, *apperror.Error)
func (s *Service) Credit(ctx context.Context, input MutationInput) (*MutationResponse, *apperror.Error)
```

Map errors to keys:

```text
wallet.debit.amount.invalid
wallet.debit.source_type.invalid
wallet.debit.source_id.invalid
wallet.debit.insufficient_balance
wallet.credit.amount.invalid
wallet.credit.source_type.invalid
wallet.credit.source_id.invalid
wallet.mutation.source_id.owner_mismatch
wallet.mutation.failed
```

- [x] **Step 6: Remove public consume surface**

Delete public HTTP handling for `POST /api/admin/v1/wallet/consumptions`. This route has no product caller after AI billing uses internal `Debit`.

- [x] **Step 7: Run wallet tests**

Run:

```powershell
cd admin_back_go
go test ./internal/module/payment/wallet -count=1
```

Expected: `ok admin_back_go/internal/module/payment/wallet`.

### Task 4: Reshape admin payment/wallet routes and RBAC metadata

**Files:**
- Modify: `admin_back_go/internal/module/payment/transport/admin/route.go`
- Modify: `admin_back_go/internal/module/payment/wallet/transport/admin/{route.go,handler.go,handler_test.go}`
- Modify: `admin_back_go/internal/bootstrap/{route_meta.go,route_meta_test.go}`

- [x] **Step 1: Write route tests**

Assert:

```text
GET /api/admin/v1/payment/ledger/page-init works.
GET /api/admin/v1/payment/ledger passes user_id/direction/source_type/date filters.
GET /api/admin/v1/payment/wallets/page-init works.
GET /api/admin/v1/payment/wallets passes keyword/user_id filters.
GET /api/admin/v1/wallet/summary reads only current user.
GET /api/admin/v1/wallet/transactions forces current token user_id.
POST /api/admin/v1/wallet/consumptions returns 404.
```

- [x] **Step 2: Register wallet routes exactly**

`payment/wallet/transport/admin/route.go`:

```go
current := router.Group("/api/admin/v1/wallet")
current.GET("/summary", handler.Summary)
current.GET("/transactions", handler.Transactions)

ledger := router.Group("/api/admin/v1/payment/ledger")
ledger.GET("/page-init", handler.LedgerPageInit)
ledger.GET("", handler.Ledger)

wallets := router.Group("/api/admin/v1/payment/wallets")
wallets.GET("/page-init", handler.WalletUsersPageInit)
wallets.GET("", handler.WalletUsers)
```

- [x] **Step 3: Remove unused payment order and manual sync HTTP routes**

`payment/transport/admin/route.go` keeps config routes, certificate upload, and recharge routes:

```go
recharges.GET("/page-init", handler.RechargeInit)
recharges.GET("", handler.ListRecharges)
recharges.GET("/:id", handler.GetRecharge)
recharges.POST("", handler.CreateRecharge)
recharges.POST("/:id/pay", handler.PayRecharge)
```

Remove the `orders` group and remove recharge `sync` / `close` HTTP routes. Internal finalizer/cron code remains because it is a real runtime caller.

- [x] **Step 4: Update route metadata**

Add permission rules:

```text
GET /api/admin/v1/payment/ledger/page-init -> payment_ledger_list
GET /api/admin/v1/payment/ledger -> payment_ledger_list
GET /api/admin/v1/payment/wallets/page-init -> payment_wallet_list
GET /api/admin/v1/payment/wallets -> payment_wallet_list
```

Ensure these current-user routes do not require RBAC button permission:

```text
GET /api/admin/v1/wallet/summary
GET /api/admin/v1/wallet/transactions
GET /api/admin/v1/payment/recharges/page-init
GET /api/admin/v1/payment/recharges
GET /api/admin/v1/payment/recharges/:id
POST /api/admin/v1/payment/recharges
POST /api/admin/v1/payment/recharges/:id/pay
```

Remove route metadata for:

```text
/payment/orders*
/wallet/users*
/wallet/ledger*
/wallet/consumptions
/payment/recharges/:id/sync
/payment/recharges/:id/close
```

- [x] **Step 5: Run route tests**

Run:

```powershell
cd admin_back_go
go test ./internal/module/payment/wallet/transport/admin ./internal/bootstrap -count=1
```

Expected: both packages pass.

### Task 5: Add AI billing rules admin module

**Files:**
- Create: `admin_back_go/internal/module/ai/billing/{dto.go,model.go,repository.go,repository_test.go,service.go,service_test.go}`
- Create: `admin_back_go/internal/module/ai/billing/transport/admin/{handler.go,request.go,route.go,handler_test.go}`
- Modify: `admin_back_go/internal/server/router.go`
- Modify: `admin_back_go/internal/bootstrap/{app.go,route_meta.go,route_meta_test.go}`
- Create: `admin_back_go/internal/shared/i18n/locales/{zh-CN,en-US}/aibilling.yaml`

- [x] **Step 1: Write service tests**

Required cases:

```text
CreateRule trims scene/unit and rejects unknown unit.
CreateRule rejects unit_price_cents <= 0.
UpdateRule updates unit, unit_price_cents, status only.
DeleteRule soft-deletes by is_del=1.
EnabledRule(scene) returns enabled active rule.
EnabledRule(scene) returns aibilling.rule.not_configured when missing or disabled.
```

- [x] **Step 2: Implement DTO/model constants**

```go
const (
	SceneAdminImageGenerate  = "admin_image_generate"
	SceneCanvasTextGenerate  = "canvas_text_generate"
	SceneCanvasImageGenerate = "canvas_image_generate"
	SceneCanvasVideoGenerate = "canvas_video_generate"

	UnitRequest = "request"
	UnitImage   = "image"
	UnitSecond  = "second"

	RuleStatusEnabled  = 1
	RuleStatusDisabled = 2
)
```

Scene options returned by page-init:

```text
admin_image_generate  Admin 图片生成
canvas_text_generate  无限画布-文本生成
canvas_image_generate 无限画布-图片生成
canvas_video_generate 无限画布-视频生成
```

Do not seed canvas rows in migration. They are selectable options only.

- [x] **Step 3: Implement admin endpoints**

```text
GET    /api/admin/v1/ai-billing-rules/page-init
GET    /api/admin/v1/ai-billing-rules
POST   /api/admin/v1/ai-billing-rules
PUT    /api/admin/v1/ai-billing-rules/:id
PATCH  /api/admin/v1/ai-billing-rules/:id/status
DELETE /api/admin/v1/ai-billing-rules/:id
```

Mutation routes use permission `ai_billing_rule_edit`. Read routes are authenticated admin reads and do not need button permission.

- [x] **Step 4: Register service and routes**

Add `AiBillingService` to `server.Dependencies`, instantiate it in `bootstrap.New`, and register it inside `registerAdminAIRoutes`.

- [x] **Step 5: Run AI billing rule tests**

Run:

```powershell
cd admin_back_go
go test ./internal/module/ai/billing ./internal/module/ai/billing/transport/admin ./internal/bootstrap -count=1
```

Expected: all listed packages pass.

### Task 6: Add AI billing records and wire admin AI image generation as the first current caller

**Files:**
- Modify: `admin_back_go/internal/module/ai/billing/{dto.go,model.go,repository.go,repository_test.go,service.go,service_test.go}`
- Modify: `admin_back_go/internal/module/ai/image/{dto.go,model.go,repository.go,service.go,service_test.go,jobs_test.go}`
- Modify: `admin_back_go/internal/bootstrap/app.go`

- [x] **Step 1: Write billing record service tests**

Required cases:

```text
Charge creates billing record, debits wallet with source_type=ai_generate and source_id=billing_record.id.
Charge uses rule snapshot: unit, unit_count, unit_price_cents, amount_cents.
Charge rejects missing enabled rule before wallet debit.
Charge returns insufficient balance before provider task is created.
MarkSuccess moves charged -> success and sets finished_at.
Refund moves charged/failed -> refunded once and credits wallet with source_type=ai_refund.
Refund is idempotent when refund_transaction_id already exists.
```

- [x] **Step 2: Define billing record model and service interface**

```go
type BillingRecord struct {
	ID                  int64      `gorm:"column:id;primaryKey"`
	RequestNo           string     `gorm:"column:request_no"`
	UserID              int64      `gorm:"column:user_id"`
	Platform            string     `gorm:"column:platform"`
	Scene               string     `gorm:"column:scene"`
	AgentID             int64      `gorm:"column:agent_id"`
	ProviderID          int64      `gorm:"column:provider_id"`
	ModelID             string     `gorm:"column:model_id"`
	Unit                string     `gorm:"column:unit"`
	UnitCount           int        `gorm:"column:unit_count"`
	UnitPriceCents      int64      `gorm:"column:unit_price_cents"`
	AmountCents         int64      `gorm:"column:amount_cents"`
	Status              string     `gorm:"column:status"`
	DebitTransactionID  *int64     `gorm:"column:debit_transaction_id"`
	RefundTransactionID *int64     `gorm:"column:refund_transaction_id"`
	ProviderTaskID      string     `gorm:"column:provider_task_id"`
	ErrorMessage        string     `gorm:"column:error_message"`
	CreatedAt           time.Time  `gorm:"column:created_at"`
	UpdatedAt           time.Time  `gorm:"column:updated_at"`
	FinishedAt          *time.Time `gorm:"column:finished_at"`
}
```

`ai/image` consumes this interface:

```go
type BillingService interface {
	Charge(ctx context.Context, input billing.ChargeInput) (*billing.ChargeResult, *apperror.Error)
	BindProviderTask(ctx context.Context, billingRecordID int64, providerTaskID string) *apperror.Error
	MarkSuccess(ctx context.Context, billingRecordID int64) *apperror.Error
	Refund(ctx context.Context, input billing.RefundInput) *apperror.Error
}
```

- [x] **Step 3: Wire `aiimage.Create`**

After validation and before enqueueing provider work, call:

```go
charge, appErr := s.billing.Charge(ctx, billing.ChargeInput{
	RequestNo:  newImageBillingRequestNo(now, normalized.UserID),
	UserID:     int64(normalized.UserID),
	Platform:   "admin",
	Scene:      billing.SceneAdminImageGenerate,
	AgentID:    int64(agent.AgentID),
	ProviderID: int64(agent.ProviderID),
	ModelID:    agent.ModelID,
	UnitCount:  normalized.N,
	Remark:     "AI图片生成",
})
if appErr != nil {
	return nil, appErr
}
```

Create `ImageTask` with `BillingRecordID: &charge.RecordID`. If enqueue fails, call `billing.Refund` with reason `图片生成任务入队失败`.

- [x] **Step 4: Wire worker success/failure**

On success after `FinishTaskSuccess`, call `MarkSuccess` for `task.BillingRecordID`. On every failure path inside `finishFailed`, call `Refund` for `task.BillingRecordID`. Historical tasks with nil `BillingRecordID` skip billing without error.

- [x] **Step 5: Run image billing tests**

Run:

```powershell
cd admin_back_go
go test ./internal/module/ai/billing ./internal/module/ai/image -count=1
```

Expected: both packages pass.

### Task 7: Frontend payment/wallet menu and pages

**Files:**
- Modify: `admin_front_ts/src/api/wallet/index.ts`
- Create: `admin_front_ts/src/views/Main/payment/ledger/index.vue`
- Create: `admin_front_ts/src/views/Main/payment/wallets/index.vue`
- Create: `admin_front_ts/src/views/Main/personal/wallet/index.vue`
- Modify: `admin_front_ts/src/views/Layout/components/Aside/index.vue`
- Modify: `admin_front_ts/src/views/Main/payment/recharge/index.vue`
- Modify: `admin_front_ts/src/views/Main/payment/recharge/composables/usePaymentRechargePage.ts`
- Remove: `admin_front_ts/src/api/payment/orders.ts`
- Remove: `admin_front_ts/src/views/Main/payment/orders/`
- Remove: `admin_front_ts/src/views/Main/wallet/{ledger,users,transactions}/`
- Modify: `admin_front_ts/src/i18n/locales/{zh-CN.ts,en-US.ts}`

- [x] **Step 1: Update wallet API paths and types**

`WalletSourceType` becomes:

```ts
export type WalletSourceType = 'recharge' | 'ai_generate' | 'ai_refund'
```

Admin list methods become:

```ts
ledgerInit: () => request.get<WalletLedgerPageInitResponse>(`${ADMIN_API_PREFIX}/payment/ledger/page-init`),
ledger: (params: WalletTransactionListParams) => request.get<PaginatedResponse<WalletTransactionItem>>(`${ADMIN_API_PREFIX}/payment/ledger`, { params }),
usersInit: () => request.get<WalletUsersPageInitResponse>(`${ADMIN_API_PREFIX}/payment/wallets/page-init`),
users: (params: WalletUserListParams) => request.get<PaginatedResponse<WalletUserItem>>(`${ADMIN_API_PREFIX}/payment/wallets`, { params }),
```

Remove `consume` API.

- [x] **Step 2: Move admin wallet pages under payment**

Create `/payment/ledger` from current `/wallet/ledger` and `/payment/wallets` from current `/wallet/users`. Keep `Search + AppTable + useTable`. Do not add manual balance adjustment buttons.

- [x] **Step 3: Build current-user wallet page**

Create `src/views/Main/personal/wallet/index.vue` with `el-tabs`:

```text
Tab wallet: summary cards + recharge button
Tab transactions: current-user wallet transaction table
```

The recharge button routes to `/payment/recharge`.

- [x] **Step 4: Add top-right dropdown item**

In `Aside/index.vue` add:

```vue
<el-dropdown-item command="wallet"><el-icon><Wallet /></el-icon>{{ t('header.myWallet') }}</el-dropdown-item>
```

and command handling:

```ts
if (cmd === 'personal') router.push({ path: '/personal', query: { user_id: userStore.user_id } })
else if (cmd === 'wallet') router.push({ path: '/profile/wallet' })
else if (cmd === 'logout') logoutVisible.value = true
```

- [x] **Step 5: Remove manual sync UX from recharge page**

Remove calls and buttons for `PaymentRechargeApi.sync`, `PaymentRechargeApi.close`, manual sync labels, and manual close labels. Keep create/pay and list/detail refresh.

- [x] **Step 6: Run frontend payment tests**

Run:

```powershell
cd admin_front_ts
npm run test -- --run tests/shared/payment-wallet-billing-redesign.test.ts
npm run typecheck
```

Expected: test passes and `vue-tsc` exits 0.

### Task 8: Frontend AI billing rule editor inside AI agent config

**Files:**
- Create: `admin_front_ts/src/api/ai/billingRules.ts`
- Modify: `admin_front_ts/src/views/Main/ai/agents/index.vue`
- Create: `admin_front_ts/src/views/Main/ai/agents/components/AgentBillingDialog/index.vue`
- Modify: `admin_front_ts/src/i18n/locales/{zh-CN.ts,en-US.ts}`
- Create: `admin_front_ts/tests/shared/ai/ai-billing-rule-api.test.ts`

- [x] **Step 1: Implement API client**

Expose:

```ts
export type AiBillingUnit = 'request' | 'image' | 'second'
export type AiBillingScene = 'admin_image_generate' | 'canvas_text_generate' | 'canvas_image_generate' | 'canvas_video_generate'

export const AiBillingRuleApi = {
  init: () => request.get<AiBillingRulePageInitResponse>(`${ADMIN_API_PREFIX}/ai-billing-rules/page-init`),
  list: () => request.get<PaginatedResponse<AiBillingRuleItem>>(`${ADMIN_API_PREFIX}/ai-billing-rules`, { params: { current_page: 1, page_size: 100 } }),
  add: (params: AiBillingRuleMutationParams) => request.post<{ id: number }, AiBillingRuleMutationParams>(`${ADMIN_API_PREFIX}/ai-billing-rules`, params),
  edit: (params: AiBillingRuleMutationParams) => request.put<void, AiBillingRuleMutationParams>(`${ADMIN_API_PREFIX}/ai-billing-rules/${Number(params.id)}`, params),
  status: (params: { id: Id; status: number }) => request.patch<void, { status: number }>(`${ADMIN_API_PREFIX}/ai-billing-rules/${Number(params.id)}/status`, { status: params.status }),
  del: (params: { id: Id }) => request.delete<void>(`${ADMIN_API_PREFIX}/ai-billing-rules/${Number(params.id)}`),
}
```

- [x] **Step 2: Implement billing dialog**

Use `AppDialog + AppTable + el-form`; no new left-side menu. Columns: 场景、计费单位、单价、状态、更新时间、操作。 Validation: scene required, unit required, `unit_price_cents` integer > 0, status required.

- [x] **Step 3: Add toolbar entry in AI agents page**

Add one toolbar button near “新增”:

```vue
<el-button type="primary" plain @click="billingDialogVisible = true">{{ t('aiBilling.actions.config') }}</el-button>
```

Mount `<AgentBillingDialog v-model="billingDialogVisible" />`.

- [x] **Step 4: Run AI billing frontend tests**

Run:

```powershell
cd admin_front_ts
npm run test -- --run tests/shared/ai/ai-billing-rule-api.test.ts
npm run typecheck
```

Expected: test passes and `vue-tsc` exits 0.

### Task 9: Sync contracts, status, and smoke docs

**Files:**
- Modify: `docs/status/module-matrix.md`
- Modify: `docs/contracts/admin-api-v1.md`
- Modify: `docs/testing/smoke-matrix.md`

- [x] **Step 1: Update module matrix**

Payment section must state:

```text
Visible menu: 支付管理 -> 支付配置 / 收支明细 / 用户钱包
Hidden user route: /profile/wallet
Hidden recharge route: /payment/recharge
Retired visible entries: /wallet, /wallet-manage, /payment/orders
```

AI section must state:

```text
AI billing rules are configured in AI agent config.
Admin image generation is the first billed runtime caller.
Canvas integration is not part of this implementation.
```

- [x] **Step 2: Update API contract**

Document payment/wallet APIs:

```text
GET /api/admin/v1/payment/ledger/page-init
GET /api/admin/v1/payment/ledger
GET /api/admin/v1/payment/wallets/page-init
GET /api/admin/v1/payment/wallets
GET /api/admin/v1/wallet/summary
GET /api/admin/v1/wallet/transactions
```

Document AI billing rule APIs:

```text
GET/POST/PUT/PATCH/DELETE /api/admin/v1/ai-billing-rules
```

Remove product-facing references for `/payment/orders` page, `/wallet/users`, `/wallet/ledger`, `/wallet/transactions` left-side page, `/wallet/consumptions`, and manual recharge sync UI.

- [x] **Step 3: Update smoke matrix**

Add checks:

```text
Left menu only shows one payment top-level entry.
/payment/ledger loads and filters direction/source_type/date range.
/payment/wallets loads and filters user keyword.
/profile/wallet loads summary and self transaction tab.
/payment/recharge opens from /profile/wallet with no manual sync button.
AI agent page opens billing dialog and can save admin_image_generate price.
AI image generation with insufficient balance fails before provider enqueue.
AI image generation worker failure refunds exactly once.
```

### Task 10: Full verification and live DB check

**Files:**
- No new files unless a failing verification requires a narrow fix.

- [x] **Step 1: Backend verification**

Run:

```powershell
cd admin_back_go
go test ./internal/architecture ./internal/bootstrap ./internal/module/payment/... ./internal/module/ai/billing ./internal/module/ai/image -count=1
go test ./... -count=1
```

- [x] **Step 2: Frontend verification**

Run:

```powershell
cd admin_front_ts
npm run test -- --run tests/shared/payment-wallet-billing-redesign.test.ts tests/shared/ai/ai-billing-rule-api.test.ts
npm run typecheck
npm run lint:quality
```

- [x] **Step 3: Root governance verification**

Run:

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected: `git diff --check` exits 0 and governance checker prints `PASS: no blocking governance violations found`.

- [x] **Step 4: Live DB verification after applying migration**

Run:

```sql
SELECT name,path,code,i18n_key,show_menu,status,is_del,parent_id,sort
FROM permissions
WHERE platform='admin'
  AND (path LIKE '/payment%' OR path LIKE '/wallet%' OR path LIKE '/profile/wallet' OR code LIKE 'ai_billing%')
ORDER BY parent_id,sort,id;

SHOW INDEX FROM wallet_transactions;
SHOW INDEX FROM user_wallets;
SHOW INDEX FROM ai_billing_rules;
SHOW INDEX FROM ai_billing_records;
SHOW COLUMNS FROM ai_image_tasks LIKE 'billing_record_id';
```

Expected facts:

```text
/payment is the only visible payment/wallet top-level menu.
/payment/config, /payment/ledger, /payment/wallets are visible children.
/profile/wallet and /payment/recharge are active hidden routes.
/wallet, /wallet-manage, /payment/orders are not active visible menu entries.
ai_billing_rules and ai_billing_records indexes exist.
ai_image_tasks.billing_record_id exists and is indexed.
```

---

## Plan Self-Review

- Spec coverage: menu cleanup, current-user wallet, wallet Debit/Credit, AI billing rules, AI billing records, admin AI image current caller, docs, smoke, and DB verification are covered.
- Scope check: no `canvas_front_next`, no `/api/canvas/*`, no infinite-canvas runtime changes.
- No duplicate money source: no credit/points/canvas credit tables; wallet remains the only balance fact.
- Table usefulness: `ai_billing_rules` is used by AI agent config UI; `ai_billing_records` is used by admin AI image generation and wallet transaction source IDs.
- Performance: wallet admin list, user wallet list, billing records, and image-task billing lookup have explicit indexes.
