# Pay Foundation and Pay Channel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Do not use a worktree; this project explicitly works in the current branch. Do not commit unless the user explicitly asks.

**Goal:** Migrate the first payment-domain slice to Go: pay enum/dict/validate foundation, secure Pay Channel REST API, operation-log masking, frontend Pay Channel API adaptation, docs and smoke coverage.

**Architecture:** Keep the existing Gin modular monolith. New backend code lives under `admin_back_go/internal/module/paychannel` and follows `route -> handler -> service -> repository -> model`; `handler` binds HTTP only, `service` owns business rules and secret encryption, `repository` owns GORM queries only. Legacy PHP is business evidence only; new API is strict REST under `/api/admin/v1/pay-channels`.

**Tech Stack:** Go 1.21+, Gin, GORM, go-playground validator, existing `secretbox`, MySQL, Vue 3 + TypeScript + Vite, existing `request` client, Vitest.

---

## Scope lock

This plan implements only Pay Foundation + Pay Channel management.

Do not implement in this slice:

- payment SDK runtime
- recharge/createPay/queryResult/cancelOrder
- payment notify callback
- wallet balance mutation
- order close/remark
- transaction creation
- fulfillment worker
- reconciliation execution/download/retry
- schema changes unless tests prove the current table cannot support the contract

## Contract lock

New endpoints:

```text
GET    /api/admin/v1/pay-channels/page-init
GET    /api/admin/v1/pay-channels
POST   /api/admin/v1/pay-channels
PUT    /api/admin/v1/pay-channels/:id
PATCH  /api/admin/v1/pay-channels/:id/status
DELETE /api/admin/v1/pay-channels/:id
```

Permission and operation metadata:

```text
POST   /api/admin/v1/pay-channels             -> pay_channel_add     -> 新增支付渠道
PUT    /api/admin/v1/pay-channels/:id         -> pay_channel_edit    -> 编辑支付渠道
PATCH  /api/admin/v1/pay-channels/:id/status  -> pay_channel_status  -> 切换支付渠道状态
DELETE /api/admin/v1/pay-channels/:id         -> pay_channel_del     -> 删除支付渠道
```

Deletion rule: if `orders.channel_id` or `pay_transactions.channel_id` references the channel, reject delete and tell the user to disable instead.

## Files map

Backend create:

```text
admin_back_go/internal/enum/pay.go
admin_back_go/internal/enum/pay_test.go
admin_back_go/internal/dict/pay_test.go
admin_back_go/internal/validate/pay.go
admin_back_go/internal/validate/pay_test.go
admin_back_go/internal/module/paychannel/dto.go
admin_back_go/internal/module/paychannel/errors.go
admin_back_go/internal/module/paychannel/handler.go
admin_back_go/internal/module/paychannel/handler_test.go
admin_back_go/internal/module/paychannel/model.go
admin_back_go/internal/module/paychannel/repository.go
admin_back_go/internal/module/paychannel/request.go
admin_back_go/internal/module/paychannel/route.go
admin_back_go/internal/module/paychannel/service.go
admin_back_go/internal/module/paychannel/service_test.go
```

Backend modify:

```text
admin_back_go/internal/dict/dict.go
admin_back_go/internal/validate/register.go
admin_back_go/internal/module/operationlog/service.go
admin_back_go/internal/module/operationlog/service_test.go
admin_back_go/internal/server/router.go
admin_back_go/internal/bootstrap/app.go
admin_back_go/internal/bootstrap/route_meta.go
admin_back_go/scripts/full-admin-smoke.ps1
```

Frontend modify/create:

```text
admin_front_ts/src/api/pay/channel.ts
admin_front_ts/src/views/Main/pay/channel/types.ts
admin_front_ts/src/views/Main/pay/channel/composables/usePayChannelPage.ts
admin_front_ts/src/views/Main/pay/channel/index.vue
tests/shared/pay/pay-channel-api.test.ts
```

Docs modify:

```text
docs/contracts/admin-api-v1.md
docs/migration/current-status.md
docs/testing/smoke-matrix.md
admin_back_go/docs/architecture.md
```

---

## Task 1: Pay enum foundation

**Files:**
- Create: `admin_back_go/internal/enum/pay.go`
- Create: `admin_back_go/internal/enum/pay_test.go`

- [ ] **Step 1: Write enum tests first**

Create `admin_back_go/internal/enum/pay_test.go` with tests for stable channel order, stable method order, supported method filtering, duplicate removal, and channel-specific validation.

Key assertions:

```go
func TestPayChannelOrder(t *testing.T) {
    require.Equal(t, []int{PayChannelWechat, PayChannelAlipay}, PayChannels)
}

func TestNormalizePaySupportedMethods(t *testing.T) {
    got := NormalizePaySupportedMethods(PayChannelWechat, []string{"h5", "scan", "scan", "web", ""})
    require.Equal(t, []string{"h5", "scan"}, got)
}

func TestPaySupportedMethodsValid(t *testing.T) {
    require.True(t, PaySupportedMethodsValid(PayChannelWechat, []string{"scan", "h5"}))
    require.False(t, PaySupportedMethodsValid(PayChannelWechat, []string{"web"}))
    require.True(t, PaySupportedMethodsValid(PayChannelAlipay, []string{"web", "scan"}))
}
```

- [ ] **Step 2: Run red test**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/enum
```

Expected: fail because pay enum symbols do not exist.

- [ ] **Step 3: Implement `pay.go`**

Create constants and helper functions:

```go
const (
    PayChannelWechat = 1
    PayChannelAlipay = 2
)

const (
    PayMethodWeb  = "web"
    PayMethodH5   = "h5"
    PayMethodApp  = "app"
    PayMethodMini = "mini"
    PayMethodScan = "scan"
    PayMethodMP   = "mp"
)
```

Expose ordered slices and labels:

```go
var PayChannels = []int{PayChannelWechat, PayChannelAlipay}
var PayMethods = []string{PayMethodWeb, PayMethodH5, PayMethodApp, PayMethodMini, PayMethodScan, PayMethodMP}
```

Implement:

```go
IsPayChannel(value int) bool
IsPayMethod(value string) bool
PayDefaultSupportedMethods(channel int) []string
NormalizePaySupportedMethods(channel int, methods []string) []string
PaySupportedMethodsValid(channel int, methods []string) bool
```

Wechat supports `scan,h5,app,mini,mp`; Alipay supports `web,h5,app,scan,mini`.

- [ ] **Step 4: Run green test**

Run:

```powershell
go test ./internal/enum
```

Expected: pass.

---

## Task 2: Pay dict and validator tags

**Files:**
- Modify: `admin_back_go/internal/dict/dict.go`
- Create: `admin_back_go/internal/dict/pay_test.go`
- Create: `admin_back_go/internal/validate/pay.go`
- Modify: `admin_back_go/internal/validate/register.go`
- Create: `admin_back_go/internal/validate/pay_test.go`

- [ ] **Step 1: Write dict tests**

Create `dict/pay_test.go` proving:

```text
PayChannelOptions() -> 微信支付 then 支付宝
PayMethodOptions() -> web,h5,app,mini,scan,mp
PayMethodOptionsForChannel(enum.PayChannelWechat) excludes web
```

- [ ] **Step 2: Run dict red test**

```powershell
go test ./internal/dict
```

Expected: fail because dict functions do not exist.

- [ ] **Step 3: Implement dict functions**

Add to `dict.go`:

```go
func PayChannelOptions() []Option[int]
func PayMethodOptions() []Option[string]
func PayMethodOptionsForChannel(channel int) []Option[string]
```

Use `enum.PayChannelLabels`, `enum.PayMethodLabels`, and ordered enum slices. Do not hardcode label order in dict.

- [ ] **Step 4: Run dict green test**

```powershell
go test ./internal/dict
```

Expected: pass.

- [ ] **Step 5: Write validator tests**

Create `validate/pay_test.go` using `go-playground/validator/v10` directly. Test `pay_channel` accepts `1/2` and rejects `9`; `pay_method` accepts `scan` and rejects `bank`.

- [ ] **Step 6: Run validate red test**

```powershell
go test ./internal/validate
```

Expected: fail because validator funcs/tags do not exist.

- [ ] **Step 7: Implement validator funcs and register tags**

Create `validate/pay.go`:

```go
func validatePayChannel(fl playground.FieldLevel) bool {
    return enum.IsPayChannel(int(fl.Field().Int()))
}

func validatePayMethod(fl playground.FieldLevel) bool {
    return enum.IsPayMethod(trimmedString(fl.Field()))
}
```

Register in `register.go`:

```go
"pay_channel": validatePayChannel,
"pay_method":  validatePayMethod,
```

- [ ] **Step 8: Run validate green test**

```powershell
go test ./internal/validate
```

Expected: pass.

---

## Task 3: Operation log private-key masking

**Files:**
- Modify: `admin_back_go/internal/module/operationlog/service.go`
- Modify: `admin_back_go/internal/module/operationlog/service_test.go`

- [ ] **Step 1: Write masking test**

Add/extend a test proving payload fields named `app_private_key` and `app_private_key_enc` are masked in operation-log request/response capture.

Expected visible output must not contain the original secret string.

- [ ] **Step 2: Run red test**

```powershell
go test ./internal/module/operationlog
```

Expected: fail if current masking misses payment private-key fields.

- [ ] **Step 3: Extend `shouldMaskField`**

Add these exact fields to the mask rule:

```go
"app_private_key",
"app_private_key_enc",
```

Do not add broad substring rules that accidentally mask harmless business text.

- [ ] **Step 4: Run green test**

```powershell
go test ./internal/module/operationlog
```

Expected: pass.

---

## Task 4: PayChannel module service and repository

**Files:**
- Create: `admin_back_go/internal/module/paychannel/model.go`
- Create: `admin_back_go/internal/module/paychannel/dto.go`
- Create: `admin_back_go/internal/module/paychannel/errors.go`
- Create: `admin_back_go/internal/module/paychannel/repository.go`
- Create: `admin_back_go/internal/module/paychannel/service.go`
- Create: `admin_back_go/internal/module/paychannel/service_test.go`

- [ ] **Step 1: Write service tests first**

Create tests using a fake repository and real/fake `secretbox.Box` as needed. Cover:

```text
PageInit returns pay channel/method/common status dict
Create rejects unsupported channel
Create rejects unsupported supported_methods for channel
Create normalizes supported_methods to enum order
Create with app_private_key and empty secretbox key fails visibly
Create returns id after encrypting private key and storing only encrypted/hint fields
Update with blank app_private_key keeps previous encrypted key
Delete rejects referenced channel
Output DTO never contains app_private_key or app_private_key_enc fields
```

- [ ] **Step 2: Run service red test**

```powershell
go test ./internal/module/paychannel
```

Expected: fail because module files do not exist.

- [ ] **Step 3: Implement model**

`model.go` must map table `pay_channel` exactly:

```go
type Channel struct {
    ID               int64     `gorm:"column:id;primaryKey"`
    Name             string    `gorm:"column:name"`
    Channel          int       `gorm:"column:channel"`
    MchID            string    `gorm:"column:mch_id"`
    AppID            string    `gorm:"column:app_id"`
    NotifyURL        string    `gorm:"column:notify_url"`
    AppPrivateKeyEnc string    `gorm:"column:app_private_key_enc"`
    AppPrivateKeyHint string   `gorm:"column:app_private_key_hint"`
    PublicCertPath   string   `gorm:"column:public_cert_path"`
    PlatformCertPath string   `gorm:"column:platform_cert_path"`
    RootCertPath     string   `gorm:"column:root_cert_path"`
    ExtraConfig      string   `gorm:"column:extra_config"`
    IsSandbox        int      `gorm:"column:is_sandbox"`
    Sort             int      `gorm:"column:sort"`
    Remark           string   `gorm:"column:remark"`
    Status           int      `gorm:"column:status"`
    IsDel            int      `gorm:"column:is_del"`
    CreatedAt        time.Time `gorm:"column:created_at"`
    UpdatedAt        time.Time `gorm:"column:updated_at"`
}

func (Channel) TableName() string { return "pay_channel" }
```

If the table has no `supported_methods` column, store normalized methods in `extra_config` JSON under key `supported_methods`; do not change schema in this slice.

- [ ] **Step 4: Implement repository**

Repository responsibilities:

```go
List(ctx, query) ([]Channel, int64, error)
Get(ctx, id) (*Channel, error)
ExistsUnique(ctx, channel int, mchID, appID string, excludeID int64) (bool, error)
Create(ctx, row Channel) (int64, error)
Update(ctx, id int64, fields map[string]any) error
ChangeStatus(ctx, id int64, status int) error
Delete(ctx, id int64) error
Referenced(ctx, id int64) (bool, error)
```

`Referenced` checks `orders` and `pay_transactions` count by `channel_id`.

- [ ] **Step 5: Implement service**

Service owns:

```text
trim and normalize inputs
status/common yes-no validation
pay method cross-field validation
unique check
private key encryption/hint
delete referenced rule
DTO conversion and method text generation
```

Do not return private key plaintext or ciphertext in DTO.

- [ ] **Step 6: Run service green test**

```powershell
go test ./internal/module/paychannel
```

Expected: pass.

---

## Task 5: PayChannel HTTP handler and routes

**Files:**
- Create: `admin_back_go/internal/module/paychannel/request.go`
- Create: `admin_back_go/internal/module/paychannel/handler.go`
- Create: `admin_back_go/internal/module/paychannel/handler_test.go`
- Create: `admin_back_go/internal/module/paychannel/route.go`

- [ ] **Step 1: Write handler tests**

Use `httptest` with a fake HTTP service. Cover:

```text
GET /page-init returns service result
GET list binds current_page/page_size/name/channel/status
POST create rejects invalid pay_channel binding
PUT update uses route id and JSON body
PATCH status uses route id and status body
DELETE uses route id only, no body id/ids fallback
```

- [ ] **Step 2: Run handler red test**

```powershell
go test ./internal/module/paychannel
```

Expected: fail until handler/route exists.

- [ ] **Step 3: Implement request structs**

Use Gin binding tags:

```go
type listRequest struct {
    CurrentPage int `form:"current_page" binding:"omitempty,min=1"`
    PageSize int `form:"page_size" binding:"omitempty,min=1,max=100"`
    Name string `form:"name" binding:"omitempty,max=80"`
    Channel int `form:"channel" binding:"omitempty,pay_channel"`
    Status int `form:"status" binding:"omitempty,common_status"`
}
```

Mutation body must explicitly define allowed fields. No `map[string]any`, no fallback aliases.

- [ ] **Step 4: Implement handler**

Handler only binds, parses `:id`, calls service, writes `response.OK/Error`.

- [ ] **Step 5: Implement route registration**

`route.go` must call `validate.MustRegister()` and register exactly the REST endpoints in the contract lock.

- [ ] **Step 6: Run handler green test**

```powershell
go test ./internal/module/paychannel
```

Expected: pass.

---

## Task 6: Wire backend bootstrap, route metadata, and contract docs

**Files:**
- Modify: `admin_back_go/internal/server/router.go`
- Modify: `admin_back_go/internal/bootstrap/app.go`
- Modify: `admin_back_go/internal/bootstrap/route_meta.go`
- Modify: `docs/contracts/admin-api-v1.md`
- Modify: `docs/migration/current-status.md`
- Modify: `docs/testing/smoke-matrix.md`
- Modify: `admin_back_go/docs/architecture.md`

- [ ] **Step 1: Add route/bootstrap tests or extend existing ones**

Find existing route metadata tests with:

```powershell
rg "route_meta|pay_channel|operation" admin_back_go/internal/bootstrap admin_back_go/internal/server -n
```

Add assertions that mutating Pay Channel routes have permission codes and operation titles.

- [ ] **Step 2: Run red test**

```powershell
go test ./internal/server ./internal/bootstrap
```

Expected: fail until routes/metadata are wired.

- [ ] **Step 3: Wire service in bootstrap**

Follow existing module wiring style. Construct:

```go
paychannel.NewRepository(db)
paychannel.NewService(repo, secretBox)
paychannel.RegisterRoutes(engine, service)
```

Use the existing `secretbox` instance; do not create a second config path.

- [ ] **Step 4: Register route metadata**

Add exact permission codes and operation titles from the contract lock. Ensure operation log captures payload after permission check.

- [ ] **Step 5: Update contract docs**

In `docs/contracts/admin-api-v1.md`, document:

```text
GET /api/admin/v1/pay-channels/page-init
GET /api/admin/v1/pay-channels
POST /api/admin/v1/pay-channels
PUT /api/admin/v1/pay-channels/:id
PATCH /api/admin/v1/pay-channels/:id/status
DELETE /api/admin/v1/pay-channels/:id
```

Include request fields, response shape, private-key non-return rule, delete-reference error.

- [ ] **Step 6: Update migration status and smoke matrix**

Mark Pay Channel as partially/implemented only after code/tests exist. Do not claim full payment domain implemented.

- [ ] **Step 7: Run backend package tests**

```powershell
go test ./internal/enum ./internal/dict ./internal/validate ./internal/module/operationlog ./internal/module/paychannel ./internal/server ./internal/bootstrap
```

Expected: pass.

---

## Task 7: Full smoke read-only Pay Channel probes

**Files:**
- Modify: `admin_back_go/scripts/full-admin-smoke.ps1`

- [ ] **Step 1: Add read-only smoke steps**

After login and before cleanup, call:

```text
GET /api/admin/v1/pay-channels/page-init
GET /api/admin/v1/pay-channels?current_page=1&page_size=20
```

Validate:

```text
page-init has dict.channel_arr, dict.pay_method_arr, dict.common_status_arr
list has list and page
each list item has no app_private_key and no app_private_key_enc
```

- [ ] **Step 2: Do not add default write probe**

Only document optional write probe for later. Default full smoke must not create real payment config.

- [ ] **Step 3: Run script syntax check**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "$null = [scriptblock]::Create((Get-Content -Raw .\scripts\full-admin-smoke.ps1)); 'ok'"
```

Expected: `ok`.

---

## Task 8: Frontend PayChannel API migration

**Files:**
- Modify: `admin_front_ts/src/api/pay/channel.ts`
- Modify if needed: `admin_front_ts/src/views/Main/pay/channel/types.ts`
- Modify if needed: `admin_front_ts/src/views/Main/pay/channel/composables/usePayChannelPage.ts`
- Modify if needed: `admin_front_ts/src/views/Main/pay/channel/index.vue`
- Create: `admin_front_ts/tests/shared/pay/pay-channel-api.test.ts`

- [ ] **Step 1: Read current frontend API and page usage**

Run:

```powershell
cd E:\admin_go\admin_front_ts
rg "PayChannelApi|PayChannel" src\api\pay src\views\Main\pay\channel tests -n
```

- [ ] **Step 2: Write frontend API path tests**

Create Vitest proving facade methods call REST paths:

```text
init -> GET /api/admin/v1/pay-channels/page-init
list -> GET /api/admin/v1/pay-channels
add -> POST /api/admin/v1/pay-channels
edit -> PUT /api/admin/v1/pay-channels/:id
status -> PATCH /api/admin/v1/pay-channels/:id/status
del -> DELETE /api/admin/v1/pay-channels/:id
```

Use the same mocking style as existing API tests under `tests/shared`.

- [ ] **Step 3: Run frontend red test**

```powershell
npx vitest run tests/shared/pay/pay-channel-api.test.ts
```

Expected: fail while API still uses legacy paths.

- [ ] **Step 4: Replace `legacyRequest` with `request`**

Keep the existing `PayChannelApi.init/list/add/edit/del/status` facade if that avoids page churn, but internally call REST with correct HTTP verbs.

Rules:

```text
No any
No as any
No Record<string, any>
No params?: Record<string, unknown>
No id: number | number[] for DELETE
```

- [ ] **Step 5: Update page/composable only when contract demands it**

If page uses batch delete, either loop single deletes or disable the batch entry in this slice. Do not send ids array to new REST API.

- [ ] **Step 6: Run frontend green tests**

```powershell
npx vitest run tests/shared/pay/pay-channel-api.test.ts
npx eslint src/api/pay/channel.ts src/views/Main/pay/channel/index.vue src/views/Main/pay/channel/composables/usePayChannelPage.ts src/views/Main/pay/channel/types.ts tests/shared/pay/pay-channel-api.test.ts
npx vue-tsc -b --pretty false
```

Expected: pass or only pre-existing unrelated warnings; no new `any` in touched files.

---

## Task 9: Final verification gate

**Files:**
- All touched files

- [ ] **Step 1: Backend verification**

Run from `E:\admin_go\admin_back_go`:

```powershell
go test ./internal/enum ./internal/dict ./internal/validate ./internal/module/operationlog ./internal/module/paychannel ./internal/server ./internal/bootstrap
go test ./...
go vet ./...
git diff --check
```

- [ ] **Step 2: Frontend verification**

Run from `E:\admin_go\admin_front_ts`:

```powershell
npx vitest run tests/shared/pay/pay-channel-api.test.ts
npx vue-tsc -b --pretty false
```

Run targeted eslint if touched files exist:

```powershell
npx eslint src/api/pay/channel.ts src/views/Main/pay/channel/index.vue src/views/Main/pay/channel/composables/usePayChannelPage.ts src/views/Main/pay/channel/types.ts tests/shared/pay/pay-channel-api.test.ts
```

- [ ] **Step 3: Smoke verification**

If `admin-api` is running, run from `E:\admin_go\admin_back_go`:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account 15671628271 -Password 123456
```

If it is not running, do not claim smoke passed; report it as not run and why.

- [ ] **Step 4: Reviewer self-check**

Check these before final answer:

```powershell
rg "legacyRequest" admin_front_ts/src/api/pay/channel.ts admin_front_ts/src/views/Main/pay/channel -n
rg "any|as any|Record<string, any>|Record<string, unknown>" admin_front_ts/src/api/pay/channel.ts admin_front_ts/src/views/Main/pay/channel tests/shared/pay/pay-channel-api.test.ts -n
rg "app_private_key|app_private_key_enc" admin_back_go/internal/module/paychannel admin_back_go/internal/module/operationlog -n
```

Final report must include:

```text
Outcome
Changed files
Backend verification
Frontend verification
Smoke summary
Known remaining payment/wallet modules
Next recommended module
```
