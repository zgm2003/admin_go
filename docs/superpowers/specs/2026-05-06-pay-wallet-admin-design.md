# Pay Wallet Admin Migration Design

状态：ready for review。本文只做钱包后台管理迁移设计，不直接实现业务代码，不提交 commit。

## Linus 三问

1. 真问题：是。支付渠道、支付流水、后台订单已经在 Go 收口，但后台钱包管理仍走 legacy PHP `UserWallet` 全 POST。钱包是余额事实源，不能继续靠前后端互猜字段。
2. 更简单做法：第一刀只迁后台钱包 read-only：钱包列表、钱包流水、页面字典。调账写路径先把事务、幂等、版本号和操作日志边界写死，下一刀单独实现。
3. 会破坏什么：不能破坏当前钱包页面、调账按钮、用户个人钱包页和充值页。第一刀不会删除 legacy 调账能力，只把它显式隔离为 legacy adapter，避免把 read-only 迁移和真钱包写操作混在一刀。

## Scope

本阶段实现目标是 **后台钱包管理 read-only**：

```text
GET /api/admin/v1/wallets/page-init
GET /api/admin/v1/wallets
GET /api/admin/v1/wallet-transactions
```

本阶段只写清但不实现的下一刀写路径：

```text
POST /api/admin/v1/wallet-adjustments
```

为什么不是 `PATCH /api/admin/v1/wallets/:user_id/adjust`：

```text
调账不是“改一个字段”，而是创建一条资金流水并原子更新余额。
把 adjust 塞进 URL 是动作式接口，味道不好。
创建 wallet-adjustment 资源更 RESTful，也更自然承载幂等 key、操作日志和审计。
```

## Non-scope

本阶段不迁：

```text
/api/admin/pay/recharge
/api/admin/pay/createPay
/api/admin/pay/cancelOrder
/api/admin/pay/queryResult
/api/admin/pay/orderDetail
/api/admin/pay/walletInfo
/api/admin/pay/walletBills
/api/admin/pay/myOrders

/api/app/v1/wallet
/api/app/v1/wallet-bills
充值下单
支付 SDK
支付回调
钱包入账/扣款 runtime
退款
提现
冻结/解冻
对账执行
```

当前用户侧首页、个人钱包页、充值页仍使用已有 legacy 用户侧接口。它们属于后续 `app` / current-user wallet slice，不混进后台钱包管理 read-only。

## Legacy Route Map

Legacy PHP 后台路由：

```text
POST /api/admin/UserWallet/init         -> UserWalletModule::init
POST /api/admin/UserWallet/list         -> UserWalletModule::list
POST /api/admin/UserWallet/transactions -> UserWalletModule::transactions
POST /api/admin/UserWallet/adjust       -> UserWalletModule::adjust
```

Legacy PHP 用户侧钱包查询：

```text
POST /api/admin/pay/walletInfo
POST /api/admin/pay/walletBills
POST /api/app/Pay/walletInfo
POST /api/app/Pay/walletBills
```

Go 新接口映射：

```text
GET /api/admin/v1/wallets/page-init      replaces UserWallet/init
GET /api/admin/v1/wallets                replaces UserWallet/list
GET /api/admin/v1/wallet-transactions    replaces UserWallet/transactions
POST /api/admin/v1/wallet-adjustments    future replacement for UserWallet/adjust
```

## Current Runtime / DB Facts

当前库：`admin`。

表行数：

```text
user_wallets          active-ish rows: 1
wallet_transactions   active-ish rows: 0
orders                rows: 3
pay_transactions      rows: 3
permissions           rows: 260
```

权限事实：

```text
PAGE   钱包管理   code=pay_wallet_list   path=/pay/wallet
BUTTON 调整钱包   code=pay_wallet_adjust parent=pay_wallet_list
PAGE   钱包       path=/wallet           current-user page, not admin wallet management
```

`user_wallets` 关键字段：

```text
id
user_id unique uk_user_id
balance           int unsigned, cents
frozen            int unsigned, cents
total_recharge    int unsigned, cents
total_consume     int unsigned, cents
version           int unsigned, optimistic concurrency guard
is_del            tinyint, active value = 2
created_at
updated_at
```

`wallet_transactions` 关键字段：

```text
id
biz_action_no unique uk_biz_action_no
user_id indexed with created_at
wallet_id
type              1 recharge, 2 consume, 3 adjust
available_delta   signed cents
frozen_delta      signed cents
balance_before
balance_after
frozen_before
frozen_after
order_id
order_no
source_type       0 none, 1 fulfill, 2 manual
source_id
title
remark
operator_id
ext json
is_del
created_at
updated_at
```

## Enum / Dict / Validate

补齐 Go 侧钱包枚举，来源对齐 legacy `PayEnum`：

```text
WalletTypeRecharge = 1 充值入账
WalletTypeConsume  = 2 消费扣款
WalletTypeAdjust   = 3 系统调账

WalletSourceNone    = 0 未关联
WalletSourceFulfill = 1 履约
WalletSourceManual  = 2 人工
```

要求：

```text
internal/enum/pay.go 增加稳定顺序、label map、IsWalletType、IsWalletSource
internal/dict/dict.go 由 enum 派生 WalletTypeOptions / WalletSourceOptions
internal/validate/pay.go 增加 wallet_type / wallet_source validator
handler request struct 只用 enum-backed validator，不写散落 oneof
```

## REST Contract

统一后台命名空间：

```text
/api/admin/v1
```

### Page Init

```text
GET /api/admin/v1/wallets/page-init
```

Auth：bearer token + `pay_wallet_list`。

Response `data`：

```ts
interface WalletPageInitResponse {
  dict: {
    wallet_type_arr: Array<{ label: string; value: 1 | 2 | 3 }>
    wallet_source_arr: Array<{ label: string; value: 0 | 1 | 2 }>
  }
}
```

### Wallet List

```text
GET /api/admin/v1/wallets
```

Auth：bearer token + `pay_wallet_list`。

Query：

```ts
interface WalletListQuery {
  current_page: number
  page_size: number
  user_id?: number
  start_date?: string // yyyy-mm-dd, filters user_wallets.created_at >= date 00:00:00
  end_date?: string   // yyyy-mm-dd, filters user_wallets.created_at <= date 23:59:59
}
```

Response `data`：

```ts
interface WalletListResponse {
  list: Array<{
    id: number
    user_id: number
    user_name: string
    user_email: string
    balance: number
    frozen: number
    total_recharge: number
    total_consume: number
    created_at: string
  }>
  page: { page_size: number; current_page: number; total_page: number; total: number }
}
```

Rules：

```text
金额统一为分，不在后端返回元字符串。
只查 user_wallets.is_del=2。
LEFT JOIN users 只做展示事实；用户不存在时 user_name/user_email 返回空字符串，不伪造用户。
默认 current_page=1、page_size=20；page_size 不能超过 enum.PageSizeMax。
```

### Wallet Transaction List

```text
GET /api/admin/v1/wallet-transactions
```

Auth：bearer token + `pay_wallet_list`。

Query：

```ts
interface WalletTransactionListQuery {
  current_page: number
  page_size: number
  user_id?: number
  type?: 1 | 2 | 3
  start_date?: string
  end_date?: string
}
```

Response `data`：

```ts
interface WalletTransactionListResponse {
  list: Array<{
    id: number
    user_id: number
    user_name: string
    user_email: string
    biz_action_no: string
    type: 1 | 2 | 3
    type_text: string
    available_delta: number
    frozen_delta: number
    balance_before: number
    balance_after: number
    order_no: string
    title: string
    remark: string
    created_at: string
  }>
  page: { page_size: number; current_page: number; total_page: number; total: number }
}
```

Rules：

```text
只查 wallet_transactions.is_del=2。
type_text 由 Go enum/dict 派生，不由前端兜底。
当前表可能 0 行；空列表是正常业务状态。
```

### Future Wallet Adjustment

下一刀单独实现：

```text
POST /api/admin/v1/wallet-adjustments
```

Auth：bearer token + `pay_wallet_adjust`。

Body：

```ts
interface WalletAdjustmentCreateBody {
  user_id: number
  delta: number          // signed cents, cannot be 0
  reason: string         // 1..255
  idempotency_key: string // client generated UUID, required
}
```

Future response：

```ts
interface WalletAdjustmentCreateResponse {
  transaction_id: number
  biz_action_no: string
}
```

Future rules：

```text
biz_action_no = WALLET:ADJUST:{idempotency_key}，利用 wallet_transactions.uk_biz_action_no 防重复。
同一个 idempotency_key 重试必须返回同一条流水，不允许二次加减余额。
wallet 不存在时在同一个 DB transaction 内创建。
负数调账必须保证 balance + delta >= 0。
必须更新 user_wallets.version = version + 1。
必须插入 wallet_transactions，记录 before/after、operator_id、source_type=manual。
必须注册 operation log，mask 无敏感字段但保留 delta/reason/idempotency_key 方便审计。
```

## Backend Design

新模块：

```text
admin_back_go/internal/module/wallet
```

文件职责：

```text
route.go       只注册 /wallets 和 /wallet-transactions 路由
handler.go     解析 Gin query，调用 service，返回 response
request.go     GET query binding
dto.go         service input/output DTO
model.go       user_wallets / wallet_transactions 映射
repository.go  GORM 查询，只做数据访问
service.go     字典、分页默认值、trim、label/time 归一化
errors.go      repository not configured 等模块错误
```

禁止：

```text
handler 直接查 DB
service 依赖 gin.Context
repository 拼 type_text
为 read-only 增加 queue/job
为 wallet read-only 增加微服务边界
```

## Frontend Design

后台钱包页面：

```text
admin_front_ts/src/api/pay/wallet.ts
admin_front_ts/src/views/Main/pay/wallet/index.vue
admin_front_ts/src/views/Main/pay/wallet/components/WalletTransactionDialog.vue
admin_front_ts/src/views/Main/pay/wallet/components/WalletAdjustDialog.vue
```

第一刀：

```text
把 init/list/transactions 改成 request + Go REST。
把 adjust 显式隔离成 legacy adjustment adapter，下一刀 wallet-adjustments 实现后删除。
去掉 touched code 里的 any/as any/Record<string, any>。
保留当前页面交互，不重做 UI。
```

推荐前端 API 边界：

```text
WalletApi.pageInit()
WalletApi.list(query)
WalletApi.transactions(query)
LegacyWalletAdjustmentApi.create(payload)
```

这样读路径和 legacy 写路径不会混在一个假装全新的 API 对象里。

## Permission and Operation Log

第一刀 read-only：

```text
GET /wallets/page-init       pay_wallet_list
GET /wallets                 pay_wallet_list
GET /wallet-transactions     pay_wallet_list
```

不注册 operation log，因为都是只读查询。

下一刀 adjustment：

```text
POST /wallet-adjustments     pay_wallet_adjust
operation log: module=pay_wallet, action=adjust, title=钱包调账
```

## Tests and Smoke

Backend:

```text
internal/enum pay wallet enum tests
internal/dict wallet dict tests
internal/validate wallet_type tests
internal/module/wallet handler binding tests
internal/module/wallet service tests: init/list/transactions/defaults/labels/empty rows
internal/server router tests: routes are mounted
internal/bootstrap route_meta tests: read routes require pay_wallet_list
```

Frontend:

```text
tests/shared/pay/wallet-api.test.ts
tests/shared/pay-wallet/use-wallet-page.test.ts 或现有页面 source test
```

Smoke:

```text
full-admin-smoke.ps1:
  GET /api/admin/v1/wallets/page-init
  GET /api/admin/v1/wallets?current_page=1&page_size=10
  GET /api/admin/v1/wallet-transactions?current_page=1&page_size=10
```

当前 `wallet_transactions` 可能为空，所以 smoke 只验证响应结构和字典，不要求必须有流水。

## Exit Criteria

```text
后台钱包列表和流水查询不再依赖 legacy PHP。
调账仍可用，但被明确标记为 legacy adapter，等待下一刀 wallet-adjustments。
Go API RESTful，没有 /UserWallet/list 这种新接口。
所有字典来自 Go enum/dict。
权限 route metadata 使用真实 DB 权限码 pay_wallet_list。
文档同步 contract/current-status/smoke-matrix/backend architecture。
后端 go test/go vet 通过；前端 vue-tsc 和 targeted eslint 通过。
```

## Self-review

```text
未发现占位项。
read-only 和 future write scope 已拆开。
没有把 legacy action path 搬进 Go。
没有假装支付 SDK、回调、钱包入账 runtime 已迁。
PATCH /wallets/:user_id/adjust 被明确拒绝，改为 future POST /wallet-adjustments。
```
