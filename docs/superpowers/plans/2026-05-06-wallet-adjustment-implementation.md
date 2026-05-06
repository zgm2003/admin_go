# Wallet Adjustment Write Path Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Work in the current branch. Do not create a worktree. Commit only at the end of this module, after verification passes.

**Goal:** Replace legacy `POST /api/admin/UserWallet/adjust` with `POST /api/admin/v1/wallet-adjustments`, with transaction safety, idempotency, RBAC, OperationLog, frontend TypeScript adaptation, smoke restore, and synced docs.

**Architecture:** Keep the current `internal/module/wallet` module. `handler` binds JSON and extracts `operator_id`; `service` validates and maps domain errors; `repository` owns the single MySQL transaction using GORM, `SELECT ... FOR UPDATE`, `user_wallets.version`, and `wallet_transactions.uk_biz_action_no` for idempotency. Frontend removes the explicit legacy adapter and submits a typed Go REST payload with a browser UUID idempotency key.

**Tech Stack:** Go, Gin, GORM, MySQL/InnoDB, `gorm.io/gorm/clause`, Vue 3, TypeScript, Element Plus, Vitest.

---

## File Map

Backend:

```text
admin_back_go/internal/module/wallet/request.go
admin_back_go/internal/module/wallet/dto.go
admin_back_go/internal/module/wallet/errors.go
admin_back_go/internal/module/wallet/service.go
admin_back_go/internal/module/wallet/repository.go
admin_back_go/internal/module/wallet/model.go
admin_back_go/internal/module/wallet/handler.go
admin_back_go/internal/module/wallet/route.go
admin_back_go/internal/module/wallet/service_test.go
admin_back_go/internal/module/wallet/handler_test.go
admin_back_go/internal/bootstrap/route_meta.go
admin_back_go/internal/bootstrap/route_meta_test.go
```

Frontend:

```text
admin_front_ts/src/api/pay/wallet.ts
admin_front_ts/src/views/Main/pay/wallet/components/WalletAdjustDialog.vue
admin_front_ts/tests/shared/pay/wallet-api.test.ts
```

Smoke/docs:

```text
admin_back_go/scripts/full-admin-smoke.ps1
docs/contracts/admin-api-v1.md
docs/migration/current-status.md
docs/testing/smoke-matrix.md
admin_back_go/docs/architecture.md
```

---

## Task 1: Backend Contract Types

**Files:**

- Modify: `E:/admin_go/admin_back_go/internal/module/wallet/request.go`
- Modify: `E:/admin_go/admin_back_go/internal/module/wallet/dto.go`
- Modify: `E:/admin_go/admin_back_go/internal/module/wallet/errors.go`

- [ ] **Step 1: Add JSON request struct**

Add below existing query request structs:

```go
type createAdjustmentRequest struct {
	UserID         int64  `json:"user_id" binding:"required,min=1"`
	Delta          int    `json:"delta" binding:"required"`
	Reason         string `json:"reason" binding:"required,max=255"`
	IdempotencyKey string `json:"idempotency_key" binding:"required,min=8,max=50"`
}
```

- [ ] **Step 2: Add DTOs**

Add to `dto.go`:

```go
type CreateAdjustmentInput struct {
	UserID         int64
	Delta          int
	Reason         string
	IdempotencyKey string
	OperatorID     int64
}

type AdjustmentMutation struct {
	UserID         int64
	Delta          int
	Reason         string
	IdempotencyKey string
	BizActionNo    string
	OperatorID     int64
}

type AdjustmentResult struct {
	TransactionID int64
	BizActionNo   string
	BalanceBefore int
	BalanceAfter  int
}

type WalletAdjustmentCreateResponse struct {
	TransactionID int64  `json:"transaction_id"`
	BizActionNo   string `json:"biz_action_no"`
	BalanceBefore int    `json:"balance_before"`
	BalanceAfter  int    `json:"balance_after"`
}
```

Extend `HTTPService`:

```go
type HTTPService interface {
	Init(ctx context.Context) (*InitResponse, *apperror.Error)
	List(ctx context.Context, query ListQuery) (*ListResponse, *apperror.Error)
	Transactions(ctx context.Context, query TransactionListQuery) (*TransactionListResponse, *apperror.Error)
	CreateAdjustment(ctx context.Context, input CreateAdjustmentInput) (*WalletAdjustmentCreateResponse, *apperror.Error)
}
```

- [ ] **Step 3: Add sentinel errors**

Replace `errors.go` with:

```go
package wallet

import "errors"

var (
	ErrRepositoryNotConfigured = errors.New("wallet repository not configured")
	ErrUserNotFound            = errors.New("wallet user not found")
	ErrInsufficientBalance     = errors.New("wallet insufficient balance")
	ErrAdjustmentConflict      = errors.New("wallet adjustment idempotency conflict")
)
```

- [ ] **Step 4: Verify red state**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/wallet
```

Expected: FAIL until fake services/repositories implement `CreateAdjustment`.

---

## Task 2: Service Validation and Error Mapping

**Files:**

- Modify: `E:/admin_go/admin_back_go/internal/module/wallet/service.go`
- Modify: `E:/admin_go/admin_back_go/internal/module/wallet/service_test.go`

- [ ] **Step 1: Extend fake repository in tests**

Add fields and method to `fakeRepository`:

```go
adjustmentResult *AdjustmentResult
adjustmentErr    error
lastAdjustment   AdjustmentMutation

func (f *fakeRepository) CreateAdjustment(ctx context.Context, input AdjustmentMutation) (*AdjustmentResult, error) {
	f.lastAdjustment = input
	if f.adjustmentErr != nil {
		return nil, f.adjustmentErr
	}
	if f.adjustmentResult != nil {
		return f.adjustmentResult, nil
	}
	return &AdjustmentResult{
		TransactionID: 1,
		BizActionNo:   input.BizActionNo,
		BalanceBefore: 1000,
		BalanceAfter:  1000 + input.Delta,
	}, nil
}
```

- [ ] **Step 2: Add failing service tests**

Append these tests:

```go
func TestCreateAdjustmentValidatesInput(t *testing.T) {
	service := NewService(&fakeRepository{})
	tests := []struct {
		name  string
		input CreateAdjustmentInput
	}{
		{name: "missing user", input: CreateAdjustmentInput{Delta: 1, Reason: "修正", IdempotencyKey: "idem-0001", OperatorID: 1}},
		{name: "zero delta", input: CreateAdjustmentInput{UserID: 7, Delta: 0, Reason: "修正", IdempotencyKey: "idem-0001", OperatorID: 1}},
		{name: "blank reason", input: CreateAdjustmentInput{UserID: 7, Delta: 1, Reason: "  ", IdempotencyKey: "idem-0001", OperatorID: 1}},
		{name: "bad idempotency", input: CreateAdjustmentInput{UserID: 7, Delta: 1, Reason: "修正", IdempotencyKey: "bad key with spaces", OperatorID: 1}},
		{name: "missing operator", input: CreateAdjustmentInput{UserID: 7, Delta: 1, Reason: "修正", IdempotencyKey: "idem-0001", OperatorID: 0}},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			_, appErr := service.CreateAdjustment(context.Background(), tc.input)
			if appErr == nil || appErr.Code != apperror.CodeBadRequest {
				t.Fatalf("expected bad request, got %#v", appErr)
			}
		})
	}
}

func TestCreateAdjustmentNormalizesInputAndReturnsResponse(t *testing.T) {
	repo := &fakeRepository{
		adjustmentResult: &AdjustmentResult{
			TransactionID: 9,
			BizActionNo:   "WALLET:ADJUST:idem-0001",
			BalanceBefore: 1000,
			BalanceAfter:  1100,
		},
	}
	service := NewService(repo)

	got, appErr := service.CreateAdjustment(context.Background(), CreateAdjustmentInput{
		UserID: 7, Delta: 100, Reason: "  人工修正  ", IdempotencyKey: " idem-0001 ", OperatorID: 3,
	})
	if appErr != nil {
		t.Fatalf("expected success, got %v", appErr)
	}
	if repo.lastAdjustment.Reason != "人工修正" || repo.lastAdjustment.BizActionNo != "WALLET:ADJUST:idem-0001" {
		t.Fatalf("unexpected mutation input: %#v", repo.lastAdjustment)
	}
	if got.TransactionID != 9 || got.BalanceBefore != 1000 || got.BalanceAfter != 1100 {
		t.Fatalf("unexpected response: %#v", got)
	}
}

func TestCreateAdjustmentMapsDomainErrors(t *testing.T) {
	tests := []struct {
		name string
		err  error
		code int
		msg  string
	}{
		{name: "user not found", err: ErrUserNotFound, code: apperror.CodeNotFound, msg: "用户不存在"},
		{name: "insufficient", err: ErrInsufficientBalance, code: apperror.CodeBadRequest, msg: "可用余额不足，无法调减"},
		{name: "conflict", err: ErrAdjustmentConflict, code: apperror.CodeBadRequest, msg: "幂等键已被不同请求使用"},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			service := NewService(&fakeRepository{adjustmentErr: tc.err})
			_, appErr := service.CreateAdjustment(context.Background(), CreateAdjustmentInput{
				UserID: 7, Delta: 100, Reason: "修正", IdempotencyKey: "idem-0001", OperatorID: 3,
			})
			if appErr == nil || appErr.Code != tc.code || appErr.Message != tc.msg {
				t.Fatalf("unexpected appErr: %#v", appErr)
			}
		})
	}
}
```

- [ ] **Step 3: Implement service method**

Add imports in `service.go`:

```go
"errors"
"regexp"
```

Add package variable:

```go
var idempotencyKeyPattern = regexp.MustCompile(`^[A-Za-z0-9_.:-]+$`)
```

Add method and helpers:

```go
func (s *Service) CreateAdjustment(ctx context.Context, input CreateAdjustmentInput) (*WalletAdjustmentCreateResponse, *apperror.Error) {
	repo, appErr := s.requireRepository()
	if appErr != nil {
		return nil, appErr
	}
	mutation, appErr := normalizeAdjustmentInput(input)
	if appErr != nil {
		return nil, appErr
	}
	result, err := repo.CreateAdjustment(ctx, mutation)
	if err != nil {
		return nil, mapAdjustmentError(err)
	}
	return &WalletAdjustmentCreateResponse{
		TransactionID: result.TransactionID,
		BizActionNo:   result.BizActionNo,
		BalanceBefore: result.BalanceBefore,
		BalanceAfter:  result.BalanceAfter,
	}, nil
}

func normalizeAdjustmentInput(input CreateAdjustmentInput) (AdjustmentMutation, *apperror.Error) {
	reason := strings.TrimSpace(input.Reason)
	key := strings.TrimSpace(input.IdempotencyKey)
	if input.UserID <= 0 {
		return AdjustmentMutation{}, apperror.BadRequest("无效的用户ID")
	}
	if input.OperatorID <= 0 {
		return AdjustmentMutation{}, apperror.BadRequest("未获取到操作人")
	}
	if input.Delta == 0 {
		return AdjustmentMutation{}, apperror.BadRequest("调整金额不能为0")
	}
	if reason == "" || len([]rune(reason)) > 255 {
		return AdjustmentMutation{}, apperror.BadRequest("调账原因不能为空且不能超过255个字符")
	}
	if key == "" || len(key) < 8 || len(key) > 50 || !idempotencyKeyPattern.MatchString(key) {
		return AdjustmentMutation{}, apperror.BadRequest("幂等键格式错误")
	}
	return AdjustmentMutation{
		UserID: input.UserID, Delta: input.Delta, Reason: reason, IdempotencyKey: key,
		BizActionNo: "WALLET:ADJUST:" + key, OperatorID: input.OperatorID,
	}, nil
}

func mapAdjustmentError(err error) *apperror.Error {
	switch {
	case errors.Is(err, ErrUserNotFound):
		return apperror.NotFound("用户不存在")
	case errors.Is(err, ErrInsufficientBalance):
		return apperror.BadRequest("可用余额不足，无法调减")
	case errors.Is(err, ErrAdjustmentConflict):
		return apperror.BadRequest("幂等键已被不同请求使用")
	case errors.Is(err, ErrRepositoryNotConfigured):
		return apperror.Internal("钱包仓储未配置")
	default:
		return apperror.Wrap(apperror.CodeInternal, 500, "钱包调账失败", err)
	}
}
```

- [ ] **Step 4: Run service tests**

```powershell
cd E:\admin_go\admin_back_go
gofmt -w internal\module\wallet\service.go internal\module\wallet\service_test.go
go test ./internal/module/wallet
```

Expected: either PASS or compile failure in handler fake service, fixed in Task 4.

---

## Task 3: Repository Transaction and Idempotency

**Files:**

- Modify: `E:/admin_go/admin_back_go/internal/module/wallet/model.go`
- Modify: `E:/admin_go/admin_back_go/internal/module/wallet/repository.go`

- [ ] **Step 1: Add user existence model**

Add to `model.go`:

```go
type walletUser struct {
	ID    int64 `gorm:"column:id;primaryKey"`
	IsDel int   `gorm:"column:is_del"`
}

func (walletUser) TableName() string {
	return "users"
}
```

- [ ] **Step 2: Extend Repository interface**

```go
type Repository interface {
	List(ctx context.Context, query ListQuery) ([]ListRow, int64, error)
	Transactions(ctx context.Context, query TransactionListQuery) ([]TransactionRow, int64, error)
	CreateAdjustment(ctx context.Context, input AdjustmentMutation) (*AdjustmentResult, error)
}
```

- [ ] **Step 3: Add imports**

Add to `repository.go`:

```go
"encoding/json"
"errors"
"time"

"github.com/go-sql-driver/mysql"
"gorm.io/gorm/clause"
```

- [ ] **Step 4: Add ext struct and duplicate helper**

```go
type adjustmentExt struct {
	IdempotencyKey string `json:"idempotency_key"`
	Reason         string `json:"reason"`
	Delta          int    `json:"delta"`
	UserID         int64  `json:"user_id"`
	OperatorID     int64  `json:"operator_id"`
}

func isDuplicateKey(err error) bool {
	var mysqlErr *mysql.MySQLError
	return errors.As(err, &mysqlErr) && mysqlErr.Number == 1062
}
```

- [ ] **Step 5: Implement transaction entry**

```go
func (r *GormRepository) CreateAdjustment(ctx context.Context, input AdjustmentMutation) (*AdjustmentResult, error) {
	if r == nil || r.db == nil {
		return nil, ErrRepositoryNotConfigured
	}
	var result *AdjustmentResult
	err := r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		res, err := createAdjustmentInTx(ctx, tx, input)
		if err != nil {
			return err
		}
		result = res
		return nil
	})
	if err != nil {
		if isDuplicateKey(err) {
			return findExistingAdjustmentWithDB(ctx, r.db, input)
		}
		return nil, err
	}
	return result, nil
}
```

- [ ] **Step 6: Implement transaction body**

Add `createAdjustmentInTx` with this exact flow:

```go
func createAdjustmentInTx(ctx context.Context, tx *gorm.DB, input AdjustmentMutation) (*AdjustmentResult, error) {
	if existing, err := findAdjustmentByBizActionNo(ctx, tx, input.BizActionNo); err != nil || existing != nil {
		if err != nil {
			return nil, err
		}
		return resultFromExistingAdjustment(existing, input)
	}

	var user walletUser
	err := tx.WithContext(ctx).Where("id = ?", input.UserID).Where("is_del = ?", enum.CommonNo).First(&user).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrUserNotFound
	}
	if err != nil {
		return nil, err
	}

	walletRow, err := lockOrCreateWallet(ctx, tx, input.UserID)
	if err != nil {
		return nil, err
	}
	if input.Delta < 0 && walletRow.Balance < -input.Delta {
		return nil, ErrInsufficientBalance
	}

	before := walletRow.Balance
	after := before + input.Delta
	updates := map[string]any{
		"balance":    after,
		"version":    gorm.Expr("version + 1"),
		"updated_at": time.Now(),
	}
	update := tx.WithContext(ctx).Model(&UserWallet{}).
		Where("id = ?", walletRow.ID).
		Where("version = ?", walletRow.Version).
		Where("is_del = ?", enum.CommonNo)
	if input.Delta < 0 {
		update = update.Where("balance >= ?", -input.Delta)
	}
	updated := update.Updates(updates)
	if updated.Error != nil {
		return nil, updated.Error
	}
	if updated.RowsAffected == 0 {
		return nil, ErrInsufficientBalance
	}

	extValue, err := json.Marshal(adjustmentExt{
		IdempotencyKey: input.IdempotencyKey,
		Reason:         input.Reason,
		Delta:          input.Delta,
		UserID:         input.UserID,
		OperatorID:     input.OperatorID,
	})
	if err != nil {
		return nil, err
	}
	transaction := WalletTransaction{
		BizActionNo: input.BizActionNo, UserID: input.UserID, WalletID: walletRow.ID,
		Type: enum.WalletTypeAdjust, AvailableDelta: input.Delta, FrozenDelta: 0,
		BalanceBefore: before, BalanceAfter: after, FrozenBefore: walletRow.Frozen, FrozenAfter: walletRow.Frozen,
		OrderID: 0, OrderNo: "", SourceType: enum.WalletSourceManual, SourceID: 0,
		Title: "系统调账", Remark: input.Reason, OperatorID: input.OperatorID, Ext: string(extValue), IsDel: enum.CommonNo,
	}
	if err := tx.WithContext(ctx).Create(&transaction).Error; err != nil {
		return nil, err
	}
	return &AdjustmentResult{TransactionID: transaction.ID, BizActionNo: transaction.BizActionNo, BalanceBefore: transaction.BalanceBefore, BalanceAfter: transaction.BalanceAfter}, nil
}
```

- [ ] **Step 7: Implement repository helper functions**

Add helpers:

```go
func lockOrCreateWallet(ctx context.Context, tx *gorm.DB, userID int64) (*UserWallet, error) {
	var walletRow UserWallet
	err := tx.WithContext(ctx).
		Clauses(clause.Locking{Strength: "UPDATE"}).
		Where("user_id = ?", userID).
		Where("is_del = ?", enum.CommonNo).
		First(&walletRow).Error
	if err == nil {
		return &walletRow, nil
	}
	if !errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, err
	}
	walletRow = UserWallet{UserID: userID, IsDel: enum.CommonNo}
	if err := tx.WithContext(ctx).Create(&walletRow).Error; err != nil {
		return nil, err
	}
	return &walletRow, nil
}

func findExistingAdjustmentWithDB(ctx context.Context, db *gorm.DB, input AdjustmentMutation) (*AdjustmentResult, error) {
	existing, err := findAdjustmentByBizActionNo(ctx, db, input.BizActionNo)
	if err != nil {
		return nil, err
	}
	return resultFromExistingAdjustment(existing, input)
}

func findAdjustmentByBizActionNo(ctx context.Context, db *gorm.DB, bizActionNo string) (*WalletTransaction, error) {
	var existing WalletTransaction
	err := db.WithContext(ctx).
		Where("biz_action_no = ?", bizActionNo).
		Where("is_del = ?", enum.CommonNo).
		First(&existing).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &existing, nil
}

func resultFromExistingAdjustment(existing *WalletTransaction, input AdjustmentMutation) (*AdjustmentResult, error) {
	if existing == nil {
		return nil, gorm.ErrRecordNotFound
	}
	if !existingAdjustmentMatches(existing, input) {
		return nil, ErrAdjustmentConflict
	}
	return &AdjustmentResult{TransactionID: existing.ID, BizActionNo: existing.BizActionNo, BalanceBefore: existing.BalanceBefore, BalanceAfter: existing.BalanceAfter}, nil
}

func existingAdjustmentMatches(existing *WalletTransaction, input AdjustmentMutation) bool {
	if existing.BizActionNo != input.BizActionNo || existing.UserID != input.UserID || existing.AvailableDelta != input.Delta || strings.TrimSpace(existing.Remark) != input.Reason || existing.OperatorID != input.OperatorID {
		return false
	}
	var ext adjustmentExt
	if strings.TrimSpace(existing.Ext) == "" {
		return false
	}
	if err := json.Unmarshal([]byte(existing.Ext), &ext); err != nil {
		return false
	}
	return ext.IdempotencyKey == input.IdempotencyKey && ext.Reason == input.Reason && ext.Delta == input.Delta && ext.UserID == input.UserID && ext.OperatorID == input.OperatorID
}
```

- [ ] **Step 8: Format and test**

```powershell
cd E:\admin_go\admin_back_go
gofmt -w internal\module\wallet\model.go internal\module\wallet\repository.go
go test ./internal/module/wallet
```

Expected: remaining failure only if handler is not wired yet.

---

## Task 4: Handler, Route, and Handler Tests

**Files:**

- Modify: `E:/admin_go/admin_back_go/internal/module/wallet/handler.go`
- Modify: `E:/admin_go/admin_back_go/internal/module/wallet/route.go`
- Modify: `E:/admin_go/admin_back_go/internal/module/wallet/handler_test.go`

- [ ] **Step 1: Import middleware and add handler**

In `handler.go`, import `admin_back_go/internal/middleware`, then add:

```go
func (h *Handler) CreateAdjustment(c *gin.Context) {
	identity := middleware.GetAuthIdentity(c)
	if identity == nil || identity.UserID <= 0 {
		response.Error(c, apperror.Unauthorized("未登录"))
		return
	}
	var req createAdjustmentRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, apperror.BadRequest("钱包调账参数错误"))
		return
	}
	result, appErr := h.requireService().CreateAdjustment(c.Request.Context(), CreateAdjustmentInput{
		UserID: req.UserID, Delta: req.Delta, Reason: req.Reason, IdempotencyKey: req.IdempotencyKey, OperatorID: identity.UserID,
	})
	writeResult(c, result, appErr)
}
```

Add nil service method:

```go
func (nilHTTPService) CreateAdjustment(ctx context.Context, input CreateAdjustmentInput) (*WalletAdjustmentCreateResponse, *apperror.Error) {
	return nil, apperror.Internal("钱包服务未配置")
}
```

- [ ] **Step 2: Register route**

In `route.go`:

```go
router.POST("/api/admin/v1/wallet-adjustments", handler.CreateAdjustment)
```

- [ ] **Step 3: Extend handler fake service**

In `handler_test.go`:

```go
adjustmentInput CreateAdjustmentInput

func (f *fakeHTTPService) CreateAdjustment(ctx context.Context, input CreateAdjustmentInput) (*WalletAdjustmentCreateResponse, *apperror.Error) {
	f.called = "create_adjustment"
	f.adjustmentInput = input
	return &WalletAdjustmentCreateResponse{TransactionID: 8, BizActionNo: "WALLET:ADJUST:idem-0001", BalanceBefore: 1000, BalanceAfter: 1100}, nil
}
```

- [ ] **Step 4: Add handler auth test**

Add helper with identity:

```go
func newWalletHandlerRouterWithIdentity(identity *middleware.AuthIdentity) (*gin.Engine, *fakeHTTPService) {
	gin.SetMode(gin.TestMode)
	service := &fakeHTTPService{}
	router := gin.New()
	router.Use(func(c *gin.Context) {
		if identity != nil {
			c.Set(middleware.ContextAuthIdentity, identity)
		}
		c.Next()
	})
	RegisterRoutes(router, service)
	return router, service
}
```

Add test:

```go
func TestHandlerCreateAdjustmentUsesAuthIdentity(t *testing.T) {
	router, service := newWalletHandlerRouterWithIdentity(&middleware.AuthIdentity{UserID: 3, SessionID: 9, Platform: "admin"})
	body := strings.NewReader(`{"user_id":7,"delta":100,"reason":"人工修正","idempotency_key":"idem-0001"}`)
	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodPost, "/api/admin/v1/wallet-adjustments", body)
	request.Header.Set("Content-Type", "application/json")

	router.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK || service.called != "create_adjustment" {
		t.Fatalf("expected create adjustment, status=%d called=%s body=%s", recorder.Code, service.called, recorder.Body.String())
	}
	if service.adjustmentInput.UserID != 7 || service.adjustmentInput.Delta != 100 || service.adjustmentInput.OperatorID != 3 {
		t.Fatalf("unexpected input: %#v", service.adjustmentInput)
	}
}
```

Also add a nil identity test expecting `http.StatusUnauthorized`.

- [ ] **Step 5: Test**

```powershell
cd E:\admin_go\admin_back_go
gofmt -w internal\module\wallet\handler.go internal\module\wallet\route.go internal\module\wallet\handler_test.go
go test ./internal/module/wallet
```

Expected: PASS.

---

## Task 5: RBAC and OperationLog Metadata

**Files:**

- Modify: `E:/admin_go/admin_back_go/internal/bootstrap/route_meta.go`
- Modify: `E:/admin_go/admin_back_go/internal/bootstrap/route_meta_test.go`

- [ ] **Step 1: Add permission rule**

```go
middleware.NewRouteKey(http.MethodPost, "/api/admin/v1/wallet-adjustments"): "pay_wallet_adjust",
```

- [ ] **Step 2: Add operation rule**

```go
middleware.NewRouteKey(http.MethodPost, "/api/admin/v1/wallet-adjustments"): {
	Module: "pay_wallet",
	Action: "adjust",
	Title:  "钱包调账",
},
```

- [ ] **Step 3: Add assertions**

Add permission table case:

```go
{http.MethodPost, "/api/admin/v1/wallet-adjustments", "pay_wallet_adjust"},
```

Add operation assertion:

```go
rule, ok := operationRouteRules()[middleware.NewRouteKey(http.MethodPost, "/api/admin/v1/wallet-adjustments")]
if !ok || rule.Module != "pay_wallet" || rule.Action != "adjust" || rule.Title != "钱包调账" {
	t.Fatalf("wallet adjustment operation rule mismatch: %#v", rule)
}
```

- [ ] **Step 4: Verify**

```powershell
cd E:\admin_go\admin_back_go
gofmt -w internal\bootstrap\route_meta.go internal\bootstrap\route_meta_test.go
go test ./internal/bootstrap
```

Expected: PASS.

---

## Task 6: Frontend API Migration

**Files:**

- Modify: `E:/admin_go/admin_front_ts/src/api/pay/wallet.ts`
- Modify: `E:/admin_go/admin_front_ts/tests/shared/pay/wallet-api.test.ts`

- [ ] **Step 1: Remove legacy request import**

Change:

```ts
import request, { legacyRequest } from '@/lib/http'
```

to:

```ts
import request from '@/lib/http'
```

- [ ] **Step 2: Replace adjust types and API**

Remove `WalletAdjustParams` and `LegacyWalletAdjustmentApi`. Add:

```ts
export interface WalletAdjustmentCreatePayload {
  user_id: number
  delta: number
  reason: string
  idempotency_key: string
}

export interface WalletAdjustmentCreateResponse {
  transaction_id: number
  biz_action_no: string
  balance_before: number
  balance_after: number
}

export const WalletAdjustmentApi = {
  create: (payload: WalletAdjustmentCreatePayload) =>
    request.post<WalletAdjustmentCreateResponse, WalletAdjustmentCreatePayload>(`${ADMIN_API_PREFIX}/wallet-adjustments`, payload),
}
```

- [ ] **Step 3: Update API tests**

Replace the legacy adjustment test with:

```ts
it('uses Go REST endpoint for wallet adjustment writes', () => {
  const source = readFrontendSource('src/api/pay/wallet.ts')

  expect(source).toContain('export const WalletAdjustmentApi')
  expect(source).toContain('request.post<WalletAdjustmentCreateResponse, WalletAdjustmentCreatePayload>(`${ADMIN_API_PREFIX}/wallet-adjustments`')
  expect(source).not.toContain('LegacyWalletAdjustmentApi')
  expect(source).not.toContain('/api/admin/UserWallet/adjust')
  expect(source).not.toContain('legacyRequest')
})
```

- [ ] **Step 4: Run targeted test**

```powershell
cd E:\admin_go\admin_front_ts
npx vitest run tests/shared/pay/wallet-api.test.ts
```

Expected: may fail until Task 7 updates dialog references.

---

## Task 7: Frontend Dialog Validation and Idempotency Key

**Files:**

- Modify: `E:/admin_go/admin_front_ts/src/views/Main/pay/wallet/components/WalletAdjustDialog.vue`
- Modify: `E:/admin_go/admin_front_ts/tests/shared/pay/wallet-api.test.ts`

- [ ] **Step 1: Change import**

```ts
import { WalletAdjustmentApi } from '@/api/pay/wallet'
```

- [ ] **Step 2: Add browser UUID helper**

```ts
const createIdempotencyKey = () => {
  if (!globalThis.crypto?.randomUUID) {
    ElNotification.error({ message: '当前浏览器不支持安全幂等键生成，请升级浏览器' })
    return ''
  }
  return globalThis.crypto.randomUUID()
}
```

- [ ] **Step 3: Strengthen form rules**

Replace `rules` with:

```ts
const rules = computed<FormRules>(() => ({
  user_id: [{ required: true, message: t('pay_wallet.form.user_id') + t('common.required'), trigger: 'change' }],
  delta: [
    { required: true, message: t('pay_wallet.form.delta') + t('common.required'), trigger: 'blur' },
    {
      validator: (_rule, value: number, callback) => {
        if (Math.round(Number(value) * 100) === 0) {
          callback(new Error(t('pay_wallet.form.delta') + '不能为0'))
          return
        }
        callback()
      },
      trigger: 'blur',
    },
  ],
  reason: [
    { required: true, message: t('pay_wallet.form.reason') + t('common.required'), trigger: 'blur' },
    { max: 255, message: t('pay_wallet.form.reason') + '，最大长度255', trigger: 'blur' },
  ],
}))
```

Do not introduce `any`.

- [ ] **Step 4: Submit to Go API**

Replace request block in `submit`:

```ts
const idempotencyKey = createIdempotencyKey()
if (!idempotencyKey) {
  return
}

await WalletAdjustmentApi.create({
  user_id: Number(form.value.user_id),
  delta: Math.round(form.value.delta * 100),
  reason: form.value.reason.trim(),
  idempotency_key: idempotencyKey,
})
```

- [ ] **Step 5: Mark reason form item required**

```vue
<el-form-item
  :label="t('pay_wallet.form.reason')"
  prop="reason"
  required
>
```

- [ ] **Step 6: Add source test**

```ts
it('generates a browser UUID idempotency key in the adjustment dialog', () => {
  const source = readFrontendSource('src/views/Main/pay/wallet/components/WalletAdjustDialog.vue')

  expect(source).toContain('globalThis.crypto?.randomUUID')
  expect(source).toContain('idempotency_key: idempotencyKey')
  expect(source).toContain('WalletAdjustmentApi.create')
  expect(source).not.toContain('LegacyWalletAdjustmentApi')
  expect(source).not.toContain('/api/admin/UserWallet/adjust')
})
```

- [ ] **Step 7: Verify frontend**

```powershell
cd E:\admin_go\admin_front_ts
npx vitest run tests/shared/pay/wallet-api.test.ts
npx vue-tsc -b --pretty false
npx eslint src/api/pay/wallet.ts src/views/Main/pay/wallet/components/WalletAdjustDialog.vue tests/shared/pay/wallet-api.test.ts
```

Expected: PASS.

---

## Task 8: Full Smoke Adjustment Probe

**Files:**

- Modify: `E:/admin_go/admin_back_go/scripts/full-admin-smoke.ps1`
- Modify: `E:/admin_go/docs/testing/smoke-matrix.md`

- [ ] **Step 1: Add wallet lookup helper**

Add after `Assert-WalletTransactionList`:

```powershell
function Get-WalletByUser([string]$BaseURL, [hashtable]$Headers, [int64]$UserID) {
  $response = Invoke-RestMethod "$BaseURL/api/admin/v1/wallets?current_page=1&page_size=1&user_id=$UserID" `
    -Headers $Headers `
    -TimeoutSec 10
  Assert-ApiOK $response 'wallet lookup by user'
  $rows = Get-ObjectArray $response.data.list
  if ($rows.Count -eq 0) { return $null }
  return $rows[0]
}
```

- [ ] **Step 2: Add adjustment probe helper**

Add:

```powershell
function Invoke-WalletAdjustmentProbe([string]$BaseURL, [hashtable]$Headers, $WalletRow) {
  if ($null -eq $WalletRow -or [int64]$WalletRow.user_id -le 0) {
    return [pscustomobject]@{ Status = 'skipped_no_wallet_rows'; PlusCode = $null; DuplicateSameTransaction = $false; Restored = $false; UserID = 0 }
  }

  $userID = [int64]$WalletRow.user_id
  $originalBalance = [int]$WalletRow.balance
  $suffix = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
  $plusKey = "codex-full-smoke-plus-$suffix"
  $minusKey = "codex-full-smoke-minus-$suffix"
  $reason = "codex full smoke wallet adjustment $suffix"

  $plusBody = @{ user_id = $userID; delta = 100; reason = $reason; idempotency_key = $plusKey }
  $plus = Invoke-JsonRequestAllowFailure 'Post' "$BaseURL/api/admin/v1/wallet-adjustments" $Headers $plusBody
  Assert-ApiOK $plus 'wallet adjustment plus'
  if ([int]$plus.data.balance_before -ne $originalBalance -or [int]$plus.data.balance_after -ne ($originalBalance + 100)) {
    throw "wallet adjustment plus balance mismatch: $($plus | ConvertTo-Json -Depth 12), original=$originalBalance"
  }

  $duplicate = Invoke-JsonRequestAllowFailure 'Post' "$BaseURL/api/admin/v1/wallet-adjustments" $Headers $plusBody
  Assert-ApiOK $duplicate 'wallet adjustment duplicate'
  if ([int64]$duplicate.data.transaction_id -ne [int64]$plus.data.transaction_id) {
    throw "wallet adjustment duplicate returned different transaction"
  }

  $afterDuplicate = Get-WalletByUser $BaseURL $Headers $userID
  if ($null -eq $afterDuplicate -or [int]$afterDuplicate.balance -ne ($originalBalance + 100)) {
    throw "wallet adjustment duplicate changed balance unexpectedly"
  }

  $minusBody = @{ user_id = $userID; delta = -100; reason = "$reason restore"; idempotency_key = $minusKey }
  $minus = Invoke-JsonRequestAllowFailure 'Post' "$BaseURL/api/admin/v1/wallet-adjustments" $Headers $minusBody
  Assert-ApiOK $minus 'wallet adjustment restore'

  $restoredWallet = Get-WalletByUser $BaseURL $Headers $userID
  $restored = $null -ne $restoredWallet -and [int]$restoredWallet.balance -eq $originalBalance
  if (-not $restored) {
    throw "wallet adjustment restore failed: wallet=$($restoredWallet | ConvertTo-Json -Depth 12), original=$originalBalance"
  }

  return [pscustomobject]@{
    Status = 'ok'
    PlusCode = [int]$plus.code
    DuplicateSameTransaction = $true
    Restored = $restored
    UserID = $userID
    PlusTransactionID = [int64]$plus.data.transaction_id
    MinusTransactionID = [int64]$minus.data.transaction_id
  }
}
```

- [ ] **Step 3: Invoke the probe after wallet read probes**

Add after `$walletTransactionListSummary`:

```powershell
$walletAdjustmentBeforeLogs = Get-OperationLogList $baseURL $authHeaders '钱包调账'
Assert-ApiOK $walletAdjustmentBeforeLogs 'wallet adjustment operation log before list'
$walletAdjustmentBeforeMaxID = Get-MaxOperationLogID $walletAdjustmentBeforeLogs
$walletRows = Get-ObjectArray $walletList.data.list
$walletAdjustmentProbe = if ($walletRows.Count -gt 0) { Invoke-WalletAdjustmentProbe $baseURL $authHeaders $walletRows[0] } else { [pscustomobject]@{ Status = 'skipped_no_wallet_rows'; PlusCode = $null; DuplicateSameTransaction = $false; Restored = $false; UserID = 0 } }
$walletAdjustmentOperationLog = if ($walletAdjustmentProbe.Status -eq 'ok') { Wait-NewOperationLog $baseURL $authHeaders '钱包调账' $walletAdjustmentBeforeMaxID } else { $null }
```

- [ ] **Step 4: Add final summary fields**

```powershell
wallet_adjustment_status = $walletAdjustmentProbe.Status
wallet_adjustment_user_id = $walletAdjustmentProbe.UserID
wallet_adjustment_plus_code = $walletAdjustmentProbe.PlusCode
wallet_adjustment_duplicate_same_transaction = $walletAdjustmentProbe.DuplicateSameTransaction
wallet_adjustment_restored = $walletAdjustmentProbe.Restored
wallet_adjustment_operation_log_id = if ($null -eq $walletAdjustmentOperationLog) { 0 } else { [int64]$walletAdjustmentOperationLog.id }
```

- [ ] **Step 5: Update smoke matrix**

Change wallet row to include `POST /api/admin/v1/wallet-adjustments`, mutation `+100 / duplicate / -100 restore`, and cleanup rule `final balance equals original`.

- [ ] **Step 6: Syntax check**

```powershell
cd E:\admin_go\admin_back_go
powershell -NoProfile -ExecutionPolicy Bypass -Command "$null = [scriptblock]::Create((Get-Content -Raw .\scripts\full-admin-smoke.ps1)); 'full smoke syntax ok'"
```

Expected: `full smoke syntax ok`.

---

## Task 9: Contract and Status Docs

**Files:**

- Modify: `E:/admin_go/docs/contracts/admin-api-v1.md`
- Modify: `E:/admin_go/docs/migration/current-status.md`
- Modify: `E:/admin_go/docs/testing/smoke-matrix.md`
- Modify: `E:/admin_go/admin_back_go/docs/architecture.md`

- [ ] **Step 1: Update API contract**

Under wallet admin, document:

```text
POST /api/admin/v1/wallet-adjustments
Auth: pay_wallet_adjust
OperationLog: module=pay_wallet action=adjust title=钱包调账
Request: user_id, delta, reason, idempotency_key
Response: transaction_id, biz_action_no, balance_before, balance_after
Rules: signed cents, reason required, same idempotency same payload returns same transaction, conflict rejected, no total_recharge/total_consume/frozen changes
```

- [ ] **Step 2: Update migration status**

Change wallet row from `read-only + legacy adjustment` to `read + adjustment write implemented` only after code, frontend, and smoke pass.

- [ ] **Step 3: Update backend architecture**

Document that `internal/module/wallet` now owns read-only plus manual adjustment, and that adjustment is synchronous DB transaction only: no payment SDK, no queue, no app-side wallet runtime.

- [ ] **Step 4: Run contract gate**

```powershell
cd E:\admin_go\admin_back_go
powershell -ExecutionPolicy Bypass -File .\scripts\check-contract.ps1
```

Expected: PASS.

---

## Task 10: Verification Gate and Commit

- [ ] **Step 1: Backend targeted**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/wallet ./internal/bootstrap ./internal/server
```

- [ ] **Step 2: Backend full**

```powershell
cd E:\admin_go\admin_back_go
go test ./...
go vet ./...
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-contract.ps1
```

- [ ] **Step 3: Frontend targeted**

```powershell
cd E:\admin_go\admin_front_ts
npx vitest run tests/shared/pay/wallet-api.test.ts
npx vue-tsc -b --pretty false
npx eslint src/api/pay/wallet.ts src/views/Main/pay/wallet/components/WalletAdjustDialog.vue tests/shared/pay/wallet-api.test.ts
```

- [ ] **Step 4: Forbidden scans**

```powershell
cd E:\admin_go
rg "UserWallet/adjust|LegacyWalletAdjustmentApi|legacyRequest" admin_front_ts/src/api/pay/wallet.ts admin_front_ts/src/views/Main/pay/wallet admin_front_ts/tests/shared/pay -n
rg "any|as any|Record<string, any>" admin_front_ts/src/api/pay/wallet.ts admin_front_ts/src/views/Main/pay/wallet admin_front_ts/tests/shared/pay -n
```

Expected: no output.

- [ ] **Step 5: Full smoke**

```powershell
cd E:\admin_go\admin_back_go
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account 15671628271 -Password 123456
```

Expected summary:

```text
wallet_adjustment_status = ok
wallet_adjustment_duplicate_same_transaction = true
wallet_adjustment_restored = true
wallet_adjustment_operation_log_id > 0
```

- [ ] **Step 6: Commit and push after all gates pass**

```powershell
cd E:\admin_go\admin_back_go
git add internal/module/wallet internal/bootstrap/route_meta.go internal/bootstrap/route_meta_test.go scripts/full-admin-smoke.ps1 docs/architecture.md
git commit -m "feat: add wallet adjustment write path"
git push

cd E:\admin_go\admin_front_ts
git add src/api/pay/wallet.ts src/views/Main/pay/wallet/components/WalletAdjustDialog.vue tests/shared/pay/wallet-api.test.ts
git commit -m "feat: migrate wallet adjustment to go rest"
git push

cd E:\admin_go
git add docs/contracts/admin-api-v1.md docs/migration/current-status.md docs/testing/smoke-matrix.md docs/superpowers/specs/2026-05-06-wallet-adjustment-design.md docs/superpowers/plans/2026-05-06-wallet-adjustment-implementation.md
git commit -m "docs: plan wallet adjustment write migration"
git push
```

If any verification fails, do not commit. Fix the defect and rerun the affected gate.

---

## Self-review

```text
Spec coverage: endpoint, validation, transaction, idempotency, RBAC, OperationLog, frontend, smoke, docs are covered.
Placeholder scan: no TBD/TODO/implement later placeholders.
REST rule: only POST /api/admin/v1/wallet-adjustments is introduced; no new /UserWallet route and no PATCH action URL.
Data safety: smoke restores balance and treats restore failure as hard failure.
Type safety: frontend tasks remove legacyRequest and forbid any/as any/Record<string, any> in touched wallet files.
Architecture: handler does not access DB; service does not depend on gin.Context; repository owns DB transaction only.
```

