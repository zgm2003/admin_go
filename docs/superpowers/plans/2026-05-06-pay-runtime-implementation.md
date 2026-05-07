# Pay Runtime Minimal Closure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Work in the current branch. Do not create a worktree. One module one commit. Do not commit unless the user explicitly asks.

**Goal:** Build the first real payment runtime closure in Go: Alipay sandbox recharge order creation, Alipay web/h5 pay attempt creation, async notify verification, idempotent order success, and recharge wallet credit.

**Architecture:** Keep Gin modular monolith. Third-party SDK code is isolated under `internal/platform/payment/alipay`; business orchestration lives in `internal/module/payruntime`; DB state changes stay in repository transactions; wallet credit is a payment-domain transaction, not an artificial call to the manual adjustment API. Public Alipay notify returns raw `success`/`fail`, not the standard `{ code, data, msg }` JSON envelope.

**Tech Stack:** Go 1.21+ style, Gin, GORM, MySQL, Redis, `github.com/go-pay/gopay`, existing `secretbox`, existing enum/dict/validate, Vue 3 + TypeScript for the touched payment client only.

---

## Task 1: Add payment runtime config and cert path resolver

**Files:**

- Modify: `E:/admin_go/admin_back_go/internal/config/config.go`
- Modify: `E:/admin_go/admin_back_go/internal/config/config_test.go`
- Modify: `E:/admin_go/admin_back_go/.env.example`
- Create: `E:/admin_go/admin_back_go/internal/platform/payment/certpath.go`
- Create: `E:/admin_go/admin_back_go/internal/platform/payment/certpath_test.go`

- [ ] Add config structs:

```go
type PaymentConfig struct {
	CertBaseDir         string
	LegacyAdminBackRoot string
	AlipayTimeout       time.Duration
	NotifyLockTTL       time.Duration
	AttemptLockTTL      time.Duration
}
```

and add `Payment PaymentConfig` to `Config`.

- [ ] Load env in `Load()`:

```go
Payment: PaymentConfig{
	CertBaseDir:         envString("PAYMENT_CERT_BASE_DIR", ""),
	LegacyAdminBackRoot: envString("LEGACY_ADMIN_BACK_ROOT", ""),
	AlipayTimeout:       envDuration("PAYMENT_ALIPAY_TIMEOUT", 10*time.Second),
	NotifyLockTTL:       envDuration("PAYMENT_NOTIFY_LOCK_TTL", 30*time.Second),
	AttemptLockTTL:      envDuration("PAYMENT_ATTEMPT_LOCK_TTL", 30*time.Second),
},
```

- [ ] Add config tests:

```go
func TestLoadReadsPaymentConfig(t *testing.T) {
	t.Setenv("PAYMENT_CERT_BASE_DIR", "E:/admin/admin_back")
	t.Setenv("LEGACY_ADMIN_BACK_ROOT", "E:/admin/admin_back")
	t.Setenv("PAYMENT_ALIPAY_TIMEOUT", "9s")
	t.Setenv("PAYMENT_NOTIFY_LOCK_TTL", "40s")
	t.Setenv("PAYMENT_ATTEMPT_LOCK_TTL", "41s")

	cfg := Load()

	if cfg.Payment.CertBaseDir != "E:/admin/admin_back" || cfg.Payment.LegacyAdminBackRoot != "E:/admin/admin_back" {
		t.Fatalf("unexpected payment dirs: %#v", cfg.Payment)
	}
	if cfg.Payment.AlipayTimeout != 9*time.Second || cfg.Payment.NotifyLockTTL != 40*time.Second || cfg.Payment.AttemptLockTTL != 41*time.Second {
		t.Fatalf("unexpected payment durations: %#v", cfg.Payment)
	}
}
```

- [ ] Implement resolver:

```go
package payment

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

var ErrCertPathRequired = errors.New("payment: cert path is required")

type CertPathResolver struct {
	CertBaseDir         string
	LegacyAdminBackRoot string
	WorkingDir          string
}

func (r CertPathResolver) Resolve(storedPath string) (string, error) {
	storedPath = strings.TrimSpace(strings.ReplaceAll(storedPath, "\\", "/"))
	if storedPath == "" {
		return "", ErrCertPathRequired
	}
	if filepath.IsAbs(storedPath) {
		return requireFile(storedPath)
	}
	for _, base := range []string{r.CertBaseDir, r.LegacyAdminBackRoot, r.WorkingDir} {
		base = strings.TrimSpace(base)
		if base == "" {
			continue
		}
		candidate := filepath.Join(filepath.FromSlash(base), filepath.FromSlash(storedPath))
		if resolved, err := requireFile(candidate); err == nil {
			return resolved, nil
		}
	}
	return "", fmt.Errorf("payment: cert file not found: %s", storedPath)
}

func requireFile(path string) (string, error) {
	abs, err := filepath.Abs(path)
	if err != nil {
		return "", fmt.Errorf("payment: resolve cert abs path: %w", err)
	}
	info, err := os.Stat(abs)
	if err != nil {
		return "", fmt.Errorf("payment: cert file not readable: %w", err)
	}
	if info.IsDir() {
		return "", fmt.Errorf("payment: cert path is directory: %s", abs)
	}
	return filepath.ToSlash(abs), nil
}
```

- [ ] Add resolver tests for absolute path, relative path with `LegacyAdminBackRoot`, and missing path.

- [ ] Update `.env.example` with:

```env
# Payment runtime. Channel credentials remain in pay_channel table.
PAYMENT_CERT_BASE_DIR=
LEGACY_ADMIN_BACK_ROOT=E:/admin/admin_back
PAYMENT_ALIPAY_TIMEOUT=10s
PAYMENT_NOTIFY_LOCK_TTL=30s
PAYMENT_ATTEMPT_LOCK_TTL=30s
```

- [ ] Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/config ./internal/platform/payment
```

Expected: PASS.

## Task 2: Add Redis lock platform wrapper

**Files:**

- Create: `E:/admin_go/admin_back_go/internal/platform/redislock/redislock.go`
- Create: `E:/admin_go/admin_back_go/internal/platform/redislock/redislock_test.go`
- Modify later wiring only in Task 7.

- [ ] Define interface and locker:

```go
package redislock

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"
)

var ErrNotAcquired = errors.New("redislock: lock not acquired")

const unlockScript = `
if redis.call("GET", KEYS[1]) == ARGV[1] then
  return redis.call("DEL", KEYS[1])
end
return 0
`

type Locker interface {
	Lock(ctx context.Context, key string, ttl time.Duration) (token string, err error)
	Unlock(ctx context.Context, key string, token string) error
}

type RedisLocker struct { client redis.Cmdable }

func New(client redis.Cmdable) *RedisLocker { return &RedisLocker{client: client} }

func (l *RedisLocker) Lock(ctx context.Context, key string, ttl time.Duration) (string, error) {
	if l == nil || l.client == nil {
		return "", errors.New("redislock: client not configured")
	}
	if key == "" || ttl <= 0 {
		return "", errors.New("redislock: invalid lock input")
	}
	token, err := randomToken()
	if err != nil {
		return "", err
	}
	ok, err := l.client.SetNX(ctx, key, token, ttl).Result()
	if err != nil {
		return "", fmt.Errorf("redislock: setnx: %w", err)
	}
	if !ok {
		return "", ErrNotAcquired
	}
	return token, nil
}

func (l *RedisLocker) Unlock(ctx context.Context, key string, token string) error {
	if l == nil || l.client == nil {
		return errors.New("redislock: client not configured")
	}
	if key == "" || token == "" {
		return errors.New("redislock: invalid unlock input")
	}
	if err := l.client.Eval(ctx, unlockScript, []string{key}, token).Err(); err != nil {
		return fmt.Errorf("redislock: unlock: %w", err)
	}
	return nil
}

func randomToken() (string, error) {
	buf := make([]byte, 16)
	if _, err := rand.Read(buf); err != nil {
		return "", fmt.Errorf("redislock: random token: %w", err)
	}
	return hex.EncodeToString(buf), nil
}
```

- [ ] Tests use `redismock` only if already present; otherwise write a fake `redis.Cmdable` is too heavy. Keep unit coverage at `randomToken` and invalid inputs now, and add integration behavior in smoke/manual if Redis is running. Do not pull a test-only Redis mock dependency in this task unless it stays tiny and justified.

- [ ] Run:

```powershell
go test ./internal/platform/redislock
```

Expected: PASS.

## Task 3: Add Alipay platform gateway wrapper

**Files:**

- Modify: `E:/admin_go/admin_back_go/go.mod`
- Modify: `E:/admin_go/admin_back_go/go.sum`
- Create: `E:/admin_go/admin_back_go/internal/platform/payment/alipay/types.go`
- Create: `E:/admin_go/admin_back_go/internal/platform/payment/alipay/gateway.go`
- Create: `E:/admin_go/admin_back_go/internal/platform/payment/alipay/gateway_test.go`

- [ ] Add dependency:

```powershell
cd E:\admin_go\admin_back_go
go get github.com/go-pay/gopay@v1.5.118
```

- [ ] Define types:

```go
package alipay

import "context"

type ChannelConfig struct {
	ChannelID        int64
	AppID            string
	PrivateKey       string
	AppCertPath      string
	AlipayCertPath   string
	RootCertPath     string
	NotifyURL        string
	IsSandbox        bool
}

type CreateRequest struct {
	OutTradeNo string
	Subject    string
	AmountCents int
	PayMethod  string
	ReturnURL  string
}

type CreateResponse struct {
	Mode string
	Content string
	Raw map[string]any
}

type NotifyRequest struct {
	Form map[string]string
}

type NotifyResult struct {
	OutTradeNo string
	TradeNo string
	TradeStatus string
	TotalAmountCents int
	AppID string
	Raw map[string]any
}

type Gateway interface {
	Create(ctx context.Context, cfg ChannelConfig, req CreateRequest) (*CreateResponse, error)
	VerifyNotify(ctx context.Context, cfg ChannelConfig, req NotifyRequest) (*NotifyResult, error)
	SuccessBody() string
	FailureBody() string
}
```

- [ ] Implement `GopayGateway`:

```go
package alipay

import (
	"context"
	"errors"
	"fmt"
	"strconv"
	"strings"

	"github.com/go-pay/gopay"
	gopayalipay "github.com/go-pay/gopay/alipay"
)

type GopayGateway struct{}

func NewGopayGateway() *GopayGateway { return &GopayGateway{} }

func (g *GopayGateway) Create(ctx context.Context, cfg ChannelConfig, req CreateRequest) (*CreateResponse, error) {
	client, err := newClient(cfg)
	if err != nil { return nil, err }
	bm := gopay.BodyMap{}
	bm.Set("subject", req.Subject)
	bm.Set("out_trade_no", req.OutTradeNo)
	bm.Set("total_amount", formatCents(req.AmountCents))
	if strings.TrimSpace(req.ReturnURL) != "" { client.SetReturnUrl(strings.TrimSpace(req.ReturnURL)) }
	var content string
	switch strings.TrimSpace(req.PayMethod) {
	case "web":
		content, err = client.TradePagePay(ctx, bm)
	case "h5":
		content, err = client.TradeWapPay(ctx, bm)
	default:
		return nil, fmt.Errorf("alipay: unsupported pay method %s", req.PayMethod)
	}
	if err != nil { return nil, fmt.Errorf("alipay: create pay: %w", err) }
	return &CreateResponse{Mode: "external", Content: content, Raw: map[string]any{"content": content}}, nil
}

func (g *GopayGateway) VerifyNotify(ctx context.Context, cfg ChannelConfig, req NotifyRequest) (*NotifyResult, error) {
	_ = ctx
	if len(req.Form) == 0 { return nil, errors.New("alipay: empty notify form") }
	bm := gopay.BodyMap{}
	for k, v := range req.Form { bm.Set(k, v) }
	ok, err := gopayalipay.VerifySignWithCert(cfg.AlipayCertPath, bm)
	if err != nil { return nil, fmt.Errorf("alipay: verify notify: %w", err) }
	if !ok { return nil, errors.New("alipay: invalid notify signature") }
	cents, err := parseYuanToCents(bm.GetString("total_amount"))
	if err != nil { return nil, err }
	return &NotifyResult{
		OutTradeNo: bm.GetString("out_trade_no"),
		TradeNo: bm.GetString("trade_no"),
		TradeStatus: bm.GetString("trade_status"),
		TotalAmountCents: cents,
		AppID: bm.GetString("app_id"),
		Raw: bodyMapToMap(bm),
	}, nil
}

func (g *GopayGateway) SuccessBody() string { return "success" }
func (g *GopayGateway) FailureBody() string { return "fail" }
```

- [ ] `newClient` must call:

```go
client, err := gopayalipay.NewClient(cfg.AppID, cfg.PrivateKey, !cfg.IsSandbox)
client.SetNotifyUrl(cfg.NotifyURL)
client.SetSignType("RSA2")
err = client.SetCertSnByPath(cfg.AppCertPath, cfg.RootCertPath, cfg.AlipayCertPath)
```

- [ ] Add pure tests for `formatCents`, `parseYuanToCents`, missing config validation. Do not use real cert/private key in tests.

- [ ] Run:

```powershell
go test ./internal/platform/payment/alipay
```

Expected: PASS.

## Task 4: Add payruntime models, DTOs, and repository transaction primitives

**Files:**

- Create: `E:/admin_go/admin_back_go/internal/module/payruntime/errors.go`
- Create: `E:/admin_go/admin_back_go/internal/module/payruntime/model.go`
- Create: `E:/admin_go/admin_back_go/internal/module/payruntime/dto.go`
- Create: `E:/admin_go/admin_back_go/internal/module/payruntime/repository.go`
- Create: `E:/admin_go/admin_back_go/internal/module/payruntime/repository_test.go`

- [ ] Models must cover existing tables only:

```text
orders
order_items
pay_transactions
pay_channel
pay_notify_logs
order_fulfillments
user_wallets
wallet_transactions
users
```

Do not create migrations in this task.

- [ ] Repository interface:

```go
type Repository interface {
	WithTx(ctx context.Context, fn func(Repository) error) error
	FindActiveAlipayChannel(ctx context.Context, channelID int64) (*Channel, error)
	FindLatestOngoingRechargeByUser(ctx context.Context, userID int64) (*Order, error)
	CreateRechargeOrder(ctx context.Context, input RechargeOrderMutation) (*RechargeOrderCreated, error)
	GetOrderByNoForUpdate(ctx context.Context, orderNo string) (*Order, error)
	FindLastActiveTransactionForUpdate(ctx context.Context, orderID int64) (*PayTransaction, error)
	CloseTransaction(ctx context.Context, txnID int64, now time.Time) error
	CreateTransaction(ctx context.Context, input TransactionMutation) (*PayTransaction, error)
	MarkTransactionWaiting(ctx context.Context, txnID int64, raw map[string]any, now time.Time) error
	MarkTransactionFailed(ctx context.Context, txnID int64, reason string, now time.Time) error
	CreateNotifyLog(ctx context.Context, input NotifyLogMutation) (int64, error)
	UpdateNotifyLog(ctx context.Context, id int64, input NotifyLogUpdate) error
	FindTransactionByNoForUpdate(ctx context.Context, transactionNo string) (*PayTransaction, error)
	MarkPaySuccessAndCreditRecharge(ctx context.Context, input PaySuccessMutation) (*PaySuccessResult, error)
}
```

- [ ] `CreateRechargeOrder` inserts `orders` and `order_items` in a transaction. It does not call SDK.

- [ ] `MarkPaySuccessAndCreditRecharge` must be one DB transaction and enforce:

```text
pay_transactions locked by SELECT FOR UPDATE
orders locked or updated with status compare
wallet locked by SELECT FOR UPDATE or created
wallet_transactions biz_action_no = FULFILL:RECHARGE:{order_no}
order_fulfillments idempotency_key = FULFILL:RECHARGE:{order_no}
duplicate existing wallet transaction returns already_success without balance mutation
```

- [ ] Use MySQL duplicate key detection for `wallet_transactions.uk_biz_action_no`.

- [ ] Repository tests may use fake repository for service first; if adding DB integration tests is too heavy, keep repository SQL covered by smaller methods and rely on full smoke. Do not claim repository integration coverage unless actually using MySQL test fixture.

## Task 5: Add payruntime service with fake gateway tests first

**Files:**

- Create: `E:/admin_go/admin_back_go/internal/module/payruntime/service.go`
- Create: `E:/admin_go/admin_back_go/internal/module/payruntime/service_test.go`

- [ ] Define service dependencies:

```go
type Service struct {
	repository Repository
	gateway alipay.Gateway
	secretbox secretbox.Box
	certResolver payment.CertPathResolver
	locker redislock.Locker
	now func() time.Time
	numberGenerator NumberGenerator
	notifyLockTTL time.Duration
	attemptLockTTL time.Duration
}
```

- [ ] Define number generator:

```go
type NumberGenerator interface { Next(ctx context.Context, prefix string) (string, error) }
```

- [ ] Service methods:

```go
func (s *Service) CreateRechargeOrder(ctx context.Context, userID int64, input RechargeOrderCreateInput) (*RechargeOrderCreateResponse, *apperror.Error)
func (s *Service) CreatePayAttempt(ctx context.Context, userID int64, orderNo string, input PayAttemptCreateInput) (*PayAttemptCreateResponse, *apperror.Error)
func (s *Service) HandleAlipayNotify(ctx context.Context, input AlipayNotifyInput) (string, *apperror.Error)
```

- [ ] Write failing tests:

```text
CreateRechargeOrder rejects amount not in RechargePresets
CreateRechargeOrder rejects existing non-expired pending order
CreatePayAttempt rejects order owned by another user
CreatePayAttempt closes previous active transaction before creating new one
CreatePayAttempt marks txn failed when gateway returns error
HandleAlipayNotify returns fail on invalid signature/app_id/amount mismatch
HandleAlipayNotify duplicate success does not credit twice
HandleAlipayNotify success returns raw "success" body
```

- [ ] Implement service with short functions. If a function needs more than 3 levels indentation, split it.

- [ ] Run:

```powershell
go test ./internal/module/payruntime
```

Expected: PASS.

## Task 6: Add number generator using Redis INCR

**Files:**

- Create: `E:/admin_go/admin_back_go/internal/module/payruntime/number.go`
- Create: `E:/admin_go/admin_back_go/internal/module/payruntime/number_test.go`

- [ ] Implement legacy-compatible format:

```text
R + yyMMddHHmmss + 6-digit sequence
T + yyMMddHHmmss + 6-digit sequence
D + yyMMddHHmmss + 6-digit sequence
```

- [ ] Redis key:

```text
pay_order_no_counter
```

- [ ] Tests should use fake incrementer, not real Redis:

```go
type Incrementer interface { Incr(ctx context.Context, key string) *redis.IntCmd }
```

If `redis.IntCmd` fake is awkward, wrap Redis behind a small project interface returning `(int64, error)` and test that interface.

## Task 7: Add handlers and routes

**Files:**

- Create: `E:/admin_go/admin_back_go/internal/module/payruntime/request.go`
- Create: `E:/admin_go/admin_back_go/internal/module/payruntime/handler.go`
- Create: `E:/admin_go/admin_back_go/internal/module/payruntime/route.go`
- Create: `E:/admin_go/admin_back_go/internal/module/payruntime/handler_test.go`
- Modify: `E:/admin_go/admin_back_go/internal/server/router.go`
- Modify: `E:/admin_go/admin_back_go/internal/server/router_test.go`

- [ ] Request structs:

```go
type rechargeOrderCreateRequest struct {
	Amount int `json:"amount" binding:"required,min=1"`
	PayMethod string `json:"pay_method" binding:"required,pay_method"`
	ChannelID int64 `json:"channel_id" binding:"required,min=1"`
}

type payAttemptCreateRequest struct {
	PayMethod string `json:"pay_method" binding:"omitempty,pay_method"`
	ReturnURL string `json:"return_url" binding:"omitempty,max=512"`
}
```

- [ ] Routes:

```text
POST /api/admin/v1/recharge-orders
POST /api/admin/v1/recharge-orders/:order_no/pay-attempts
POST /api/pay/notify/alipay
```

- [ ] For notify handler, do **not** call `response.OK/Error`. Use:

```go
c.Data(http.StatusOK, "text/plain; charset=utf-8", []byte(body))
```

- [ ] Handler obtains current user ID from auth context for current-user routes. Notify route is public.

- [ ] Router test must prove notify returns raw `success`, not JSON.

## Task 8: Bootstrap wiring and route metadata

**Files:**

- Modify: `E:/admin_go/admin_back_go/internal/bootstrap/app.go`
- Modify: `E:/admin_go/admin_back_go/internal/bootstrap/route_meta.go`
- Modify: `E:/admin_go/admin_back_go/internal/bootstrap/route_meta_test.go`
- Modify: `E:/admin_go/admin_back_go/internal/server/router.go`

- [ ] Wire:

```go
paymentResolver := payment.CertPathResolver{
	CertBaseDir: cfg.Payment.CertBaseDir,
	LegacyAdminBackRoot: cfg.Payment.LegacyAdminBackRoot,
	WorkingDir: ".",
}
alipayGateway := alipay.NewGopayGateway()
locker := redislock.New(resources.Redis)
numberGenerator := payruntime.NewRedisNumberGenerator(resources.Redis)
payruntimeService := payruntime.NewService(...)
```

- [ ] Add protected metadata for current-user routes only if current PermissionCheck requires it. If current personal wallet page has no button permission, do not invent `pay_runtime_create`; use AuthToken only for current-user endpoints and document it.

- [ ] Public notify route must not require AuthToken, PermissionCheck, or OperationLog.

- [ ] Route meta tests:

```text
/api/pay/notify/alipay absent from permission rules
/api/pay/notify/alipay absent from operation rules
```

## Task 9: Frontend minimal API migration for recharge/createPay

**Files:**

- Modify: `E:/admin_go/admin_front_ts/src/api/pay/order.ts`
- Modify only if required: `E:/admin_go/admin_front_ts/src/views/Main/wallet/useRechargePayment.ts`
- Create or modify: `E:/admin_go/admin_front_ts/tests/shared/pay/recharge-runtime-api.test.ts`

- [ ] Change:

```ts
recharge: (params: RechargeCreateParams) => request.post<RechargeOrderCreateResponse>(`${ADMIN_API_PREFIX}/recharge-orders`, params),
createPay: (params: CreatePayParams) => request.post<CreatePayResponse>(`${ADMIN_API_PREFIX}/recharge-orders/${params.order_no}/pay-attempts`, {
  pay_method: params.pay_method,
  return_url: params.return_url,
}),
```

- [x] Follow-up wallet-page runtime closure migrated `cancelOrder/queryResult/myOrders/walletInfo/walletBills` to Go REST; `src/api/pay/order.ts` no longer imports `legacyRequest`.

- [ ] Do not introduce `any`, `as any`, or `Record<string, any>`.

- [ ] Run targeted tests:

```powershell
cd E:\admin_go\admin_front_ts
npx vitest run tests/shared/pay/recharge-runtime-api.test.ts
npx eslint src/api/pay/order.ts src/views/Main/wallet/useRechargePayment.ts tests/shared/pay/recharge-runtime-api.test.ts
```

Expected: PASS or existing style warnings only if already documented; do not ignore new errors.

## Task 10: Update contracts, architecture, current status, smoke

**Files:**

- Modify: `E:/admin_go/docs/contracts/admin-api-v1.md`
- Modify: `E:/admin_go/docs/migration/current-status.md`
- Modify: `E:/admin_go/docs/testing/smoke-matrix.md`
- Modify: `E:/admin_go/admin_back_go/docs/architecture.md`
- Modify: `E:/admin_go/admin_back_go/scripts/full-admin-smoke.ps1`

- [ ] Add contract section `Pay Runtime Minimal Closure` documenting:

```text
POST /api/admin/v1/recharge-orders
POST /api/admin/v1/recharge-orders/:order_no/pay-attempts
POST /api/pay/notify/alipay raw callback
```

- [ ] Mark current status as `implemented first version` after code is actually done, not before:

```text
pay runtime | implemented first version: Alipay sandbox recharge create/pay-attempt/notify/wallet credit | frontend recharge/createPay/queryResult/cancel/myOrders/walletInfo/walletBills adapted | tests... | smoke... | docs... | Alipay only; WeChat and refund out of product scope; no reconcile
```

- [ ] Smoke additions:

Default always safe:

```text
pay channel cert path fields exist for Alipay enabled channel
private key fields not leaked
```

Optional flag:

```powershell
powershell -File .\scripts\full-admin-smoke.ps1 -EnablePaymentRuntimeProbe
```

When flag is absent, do not create real recharge orders.

- [ ] Document manual sandbox e2e:

```text
create recharge order -> create pay attempt -> open pay_data.content -> pay in Alipay sandbox -> verify callback DB effects
```

## Task 11: Verification gate

Run backend:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/config ./internal/platform/payment ./internal/platform/payment/alipay ./internal/platform/redislock ./internal/module/payruntime ./internal/server ./internal/bootstrap
go test ./...
go vet ./...
git diff --check
```

Run frontend:

```powershell
cd E:\admin_go\admin_front_ts
npx vitest run tests/shared/pay/recharge-runtime-api.test.ts
npx vue-tsc -b --pretty false
npx eslint src/api/pay/order.ts src/views/Main/wallet/useRechargePayment.ts tests/shared/pay/recharge-runtime-api.test.ts
```

Run smoke from backend only after local API is running:

```powershell
cd E:\admin_go\admin_back_go
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account 15671628271 -Password 123456
```

Manual sandbox e2e is separate and must be reported as manual evidence, not automated smoke.

## Commit plan

One module commit after verification:

```powershell
cd E:\admin_go
git add docs admin_back_go admin_front_ts
git commit -m "feat: add alipay recharge runtime baseline"
git push
```

If only spec/plan is being committed before implementation:

```powershell
cd E:\admin_go
git add docs/superpowers/specs/2026-05-06-pay-runtime-design.md docs/superpowers/plans/2026-05-06-pay-runtime-implementation.md
git commit -m "docs: design pay runtime migration"
git push
```

## Self-review checklist

```text
Spec coverage: every spec section has at least one task.
No task asks the worker to hand-write RSA/signature verification.
No task changes existing pay channel/order/wallet admin contracts except docs additions.
No task wraps Alipay notify in standard JSON.
No task reads or prints real cert/private-key content.
No task claims full payment domain complete.
```
