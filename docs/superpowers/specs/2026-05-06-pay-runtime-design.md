# Pay Runtime Minimal Closure Design

状态：ready for planning。本文只设计支付运行时最小闭环，不直接实现业务代码。
日期：2026-05-06

## Linus 三问

1. 真问题：是。Go 现在已经迁完支付渠道、支付流水只读、后台订单、钱包读取和人工调账，但真实支付 runtime 仍在 legacy PHP。用户已经明确提醒 `E:\admin\admin_back\runtime\cert\alipay` 有支付宝证书，不能后续接支付时假装不知道。
2. 更简单做法：第一刀只做 **支付宝沙盒充值下单 + 支付宝异步回调验签 + 幂等入账**。不同时做微信、退款、提现、对账、商品订单、消费扣款、支付后复杂通知。
3. 会破坏什么：会碰资金状态机。必须保持现有后台只读接口、钱包调账接口、RBAC、OperationLog 不破坏；新 runtime 只新增 app/current-user 支付接口和公开回调入口，不改已有 admin REST 语义。

## 当前事实

### Go 当前状态

已实现：

```text
internal/module/paychannel       # 支付渠道配置管理，含证书路径字段和私钥密文
internal/module/paytransaction   # 支付流水只读
internal/module/payorder         # 后台订单管理和本地关单
internal/module/wallet           # 后台钱包读取 + 人工调账
internal/platform/secretbox      # AES-GCM，兼容 legacy KeyVault 格式：base64(iv + tag + ciphertext)
```

`admin_back_go/go.mod` 当前没有支付 SDK 依赖。现有支付相关文档明确写着：支付渠道、支付流水、订单、钱包调账都 **不接支付 SDK**。

### Legacy 支付宝事实

支付宝证书文件存在于 legacy：

```text
E:\admin\admin_back\runtime\cert\alipay\appPublicCert.crt
E:\admin\admin_back\runtime\cert\alipay\alipayPublicCert.crt
E:\admin\admin_back\runtime\cert\alipay\alipayRootCert.crt
```

只确认文件名、大小、时间，不读取、不输出证书正文。

当前库 `pay_channel.id=1`：

```text
channel=2
name=支付宝官方沙盒
app_id=2021000146628092
mch_id=2088721061391352
notify_url=https://www.zgm2003.cn/api/pay/notify/alipay
public_cert_path=runtime/cert/alipay/appPublicCert.crt
platform_cert_path=runtime/cert/alipay/alipayPublicCert.crt
root_cert_path=runtime/cert/alipay/alipayRootCert.crt
status=1
is_del=2
app_private_key_enc exists
```

旧 PHP `PaySdk::buildAlipayConfig()` 的关键事实：

```text
pay_channel.public_cert_path   -> app_public_cert_path
pay_channel.platform_cert_path -> alipay_public_cert_path
pay_channel.root_cert_path     -> alipay_root_cert_path
pay_channel.app_private_key_enc -> app_secret_cert
sandbox -> Pay::MODE_SANDBOX
```

旧 PHP 回调入口：

```text
POST /pay/notify/alipay
```

旧 PHP 回调处理：

```text
1. 写 pay_notify_logs，process_status=pending
2. 根据 out_trade_no 找 pay_transactions
3. 找 channel，初始化 SDK，验签
4. PayDomainService::handlePaySuccess(transactionNo, tradeNo, channel, rawData)
5. Redis lock: pay_notify_{transactionNo}
6. DB transaction 内更新 pay_transactions、orders、order_fulfillments
7. recharge 履约最终写 wallet_transactions 并更新 user_wallets
8. 成功返回支付宝要求的原始 success；失败返回 fail
```

### 当前数据事实

当前订单/流水已经有支付宝沙盒历史数据：

```text
orders: 3 rows
pay_transactions: 3 rows
id=3 transaction_no=T260413183826000006 status=3 trade_no=2026041322001436870509510316
```

说明旧链路曾真实跑通过支付宝沙盒支付。Go runtime 不能忽略证书和旧状态语义。

## Scope

第一刀实现：

```text
支付宝沙盒充值订单创建
支付宝 Web/H5 支付尝试创建
支付宝异步回调验签
支付成功幂等状态推进
充值钱包入账履约
pay_notify_logs 审计记录
full smoke 可选沙盒下单 shape 验证 + 回调单元测试
```

建议新模块和平台层：

```text
admin_back_go/internal/platform/payment
admin_back_go/internal/platform/payment/alipay
admin_back_go/internal/module/payruntime
admin_back_go/internal/platform/redislock
```

为什么新建 `payruntime`：

```text
paychannel 只管理配置事实源。
payorder 是后台订单管理，不应该塞用户侧下单。
paytransaction 是只读展示，不应该突然变成写服务。
wallet 已有调账写路径，但支付入账属于支付域编排，不应把 SDK/回调塞进 wallet。
```

## Non-scope

本阶段不做：

```text
微信支付
退款
提现
冻结/解冻
支付对账下载和差异处理
商品订单/消费订单 runtime
多币种
复杂营销优惠
outbox 强一致
支付通知 WebSocket 实时推送
后台人工补单 UI
微服务拆分
```

## Open-source decision

### 候选

1. `github.com/go-pay/gopay`

事实：当前可查询到 latest 为 `v1.5.118`，模块时间为 2026-04-10，提供支付宝 `Client`、`TradePagePay`、`TradeWapPay`、`TradeQuery`、`TradeClose`、`ParseNotifyToBodyMap`、`VerifySignWithCert`、`SetCertSnByPath` 等能力。

优点：

```text
维护活跃
覆盖支付宝和微信，后续微信可复用同一平台层思想
支持证书 SN 和证书验签
API 足够直白，适合 Go thin wrapper
```

缺点：

```text
不是支付宝官方 SDK
接口面很大，不能让业务模块到处 import gopay
```

2. `github.com/smartwalle/alipay`

事实：latest 仍是 `v1.0.2`，时间在 2019 年，GoVersion 1.12。

优点：

```text
更轻
```

缺点：

```text
维护明显不如 gopay 活跃
证书链路和当前项目长期维护风险更高
```

### 决策

本项目第一刀选 `github.com/go-pay/gopay`，但只允许在 `internal/platform/payment/alipay` 内部 import。业务模块只依赖本项目定义的接口：

```go
type AlipayGateway interface {
    Create(ctx context.Context, req CreateRequest) (*CreateResponse, error)
    VerifyNotify(ctx context.Context, req NotifyRequest) (*NotifyResult, error)
    SuccessBody() string
    FailureBody() string
}
```

这样尊重开源，不手写 RSA/验签；同时不让第三方 SDK 泄漏到业务层。

## 证书和密钥设计

### 私钥

来源：`pay_channel.app_private_key_enc`。

解密：复用 `internal/platform/secretbox`，必须要求 `VAULT_KEY` 与 legacy PHP 一致。缺失或解密失败返回显式配置错误。

禁止：

```text
禁止打印私钥明文
禁止把私钥明文放 response / OperationLog / system log
禁止在测试里写真实私钥
```

### 证书路径

来源：

```text
public_cert_path
platform_cert_path
root_cert_path
```

Go 解析规则：

```text
1. 空路径：配置错误
2. 绝对路径：直接校验存在且是文件
3. 相对路径：先按 PAYMENT_CERT_BASE_DIR 解析
4. 若 PAYMENT_CERT_BASE_DIR 为空，按 LEGACY_ADMIN_BACK_ROOT 解析
5. 若仍为空，按当前 admin_back_go 工作目录解析
6. 找不到：配置错误，不兜底
```

推荐本地 env：

```env
LEGACY_ADMIN_BACK_ROOT=E:/admin/admin_back
PAYMENT_CERT_BASE_DIR=E:/admin/admin_back
```

`runtime/cert/alipay/appPublicCert.crt` 最终应解析到：

```text
E:/admin/admin_back/runtime/cert/alipay/appPublicCert.crt
```

路径解析只返回绝对路径，不读取或输出证书正文。单元测试使用临时 fake cert 文件名验证路径，不使用真实证书内容。

## API contract

### Current-user recharge create

```text
POST /api/admin/v1/recharge-orders
```

Auth：bearer token，platform=admin 当前登录用户。这里先放在 admin namespace，因为当前 Vue 个人钱包页属于 admin 系统内的个人中心；未来 app 系统独立时再提供 `/api/app/v1/recharge-orders`。

Body：

```ts
interface RechargeOrderCreateBody {
  amount: number       // cents, > 0, must be one of enum.RechargePresets in first phase
  pay_method: 'web' | 'h5'
  channel_id: number   // must be enabled Alipay channel in first phase
}
```

Response `data`：

```ts
interface RechargeOrderCreateResponse {
  order_id: number
  order_no: string
  pay_amount: number
  expire_time: string
}
```

Rules：

```text
只允许充值订单。
同一用户存在未过期 PENDING/PAYING 充值订单时拒绝新建。
若旧订单已过期，第一刀只做本地关闭，不查第三方补偿；第三方查单补偿留给下一刀。
DB transaction 内创建 orders 和 order_items。
订单号格式沿用 legacy：R + yyMMddHHmmss + 6位 Redis INCR 序列。
```

### Current-user create pay attempt

```text
POST /api/admin/v1/recharge-orders/:order_no/pay-attempts
```

Auth：bearer token，订单必须属于当前用户。

Body：

```ts
interface RechargePayAttemptCreateBody {
  pay_method?: 'web' | 'h5'
  return_url?: string
}
```

Response `data`：

```ts
interface RechargePayAttemptCreateResponse {
  transaction_no: string
  txn_id: number
  order_no: string
  pay_amount: number
  channel: 2
  pay_method: 'web' | 'h5'
  notify_url: string
  return_url: string
  pay_data: {
    mode: 'external' | 'qrcode' | 'text'
    content: string
    meta: Record<string, unknown>
  }
}
```

Rules：

```text
只支持支付宝 channel=2。
只支持 web/h5。
每次新发起支付前关闭上一条 active transaction，并尽力调用支付宝 close；close 失败只记 warning，不阻断新支付尝试。
DB transaction 内创建 pay_transactions，状态先 CREATED。
调用 Alipay gateway 成功后，更新 pay_transactions.status=WAITING、channel_resp，并推进 orders.pay_status=PAYING。
如果调用支付宝失败，pay_transactions 更新为 FAILED 或保留 CREATED + fail reason 需要在计划里定死；第一刀推荐更新为 FAILED，避免 created 垃圾长期被当 active。
```

### Alipay notify callback

```text
POST /api/pay/notify/alipay
```

Public：第三方回调入口，不走统一 `{ code, data, msg }` 包装。

Response：

```text
success -> HTTP 200 text/plain body: success
failure -> HTTP 200 text/plain body: fail
```

Rules：

```text
必须先写 pay_notify_logs，失败也要记录。
raw_data 记录表单字段；headers 记录请求头但必须 mask Authorization/Cookie/Set-Cookie。
必须用支付宝公钥证书验签，不手写 RSA。
只接受 TRADE_SUCCESS / TRADE_FINISHED 作为成功支付。
根据 out_trade_no 找 pay_transactions，再找 channel_id 精确初始化 gateway；不要 fallback 到任意启用渠道。
回调金额 total_amount 必须等于 pay_transactions.amount，单位换算严格到分。
app_id 必须等于 pay_channel.app_id。
验签失败、金额不符、app_id 不符都写 failed log 并返回 fail。
```

## Domain transaction flow

### 充值下单

```text
handler -> payruntime.Service.CreateRechargeOrder(ctx, userID, input)
service -> repository.WithTx
repository -> insert orders
repository -> insert order_items
```

### 发起支付

```text
handler -> service.CreatePayAttempt(ctx, userID, orderNo, input)
service -> repository.WithTx: lock order, close last active txn, insert new txn CREATED
service -> payment.AlipayGateway.Create(ctx, req)
service -> repository.WithTx: txn WAITING + channel_resp, order PAYING
```

支付网关调用不放在长事务内。原因：第三方 HTTP 请求不可控，拿着 DB transaction 等网络是坏味道。为避免半成功状态：

```text
先创建 CREATED txn
网关成功后推进 WAITING
网关失败后标记 FAILED
```

### 回调入账

```text
handler -> service.HandleAlipayNotify(ctx, http request facts)
service -> notify log pending
service -> gateway.VerifyNotify
service -> redis lock pay_notify:{transaction_no}
service -> repository.WithTx:
  SELECT pay_transactions FOR UPDATE
  verify current status
  update pay_transactions SUCCESS
  update orders PAID/PENDING_BIZ
  create order_fulfillments if absent by idempotency key
service -> taskqueue enqueue fulfillment OR synchronous fulfill if queue unavailable policy says so
```

第一刀建议履约同步执行在同一个 service 中，不先引入支付 outbox。理由：充值入账是当前最小闭环，已有 wallet repository 证明同步事务可控。但要把边界写死：后续多业务履约、重试和补偿再迁入 queue/outbox。

### 充值钱包入账

复用 wallet 写路径思想，但不要调用人工调账接口。新增 payruntime 自己的 repository 方法在同一个 DB transaction 内：

```text
wallet biz_action_no = FULFILL:RECHARGE:{order_no}
SELECT user_wallets FOR UPDATE
balance += amount
total_recharge += amount
version += 1
insert wallet_transactions type=充值入账 source_type=履约 source_id=fulfillment_id
update order_fulfillments SUCCESS
update orders.biz_status=SUCCESS, biz_done_at=now
```

幂等：

```text
wallet_transactions.uk_biz_action_no 是最终幂等事实。
如果重复回调发现 transaction/order/wallet 已成功，返回 success，不重复加钱。
如果同 biz_action_no 已存在但金额/用户/order 不匹配，标记异常，返回 fail。
```

## Locks and idempotency

新增平台层：

```text
internal/platform/redislock
```

要求：

```text
SetNX key random token ttl
unlock 用 Lua 比对 token 后删除
context-aware
Redis 不可用时支付回调不能假装加锁成功
```

锁 key：

```text
pay_notify:{transaction_no}
pay_create_attempt:{order_no}
```

注意：Redis lock 是并发优化，不是资金正确性的唯一来源。真正正确性靠：

```text
SELECT ... FOR UPDATE
pay_transactions status compare
orders status compare
wallet_transactions.uk_biz_action_no
```

## Config

新增配置：

```go
type PaymentConfig struct {
    CertBaseDir         string
    LegacyAdminBackRoot string
    AlipayTimeout       time.Duration
    NotifyLockTTL       time.Duration
    AttemptLockTTL      time.Duration
}
```

Env：

```env
PAYMENT_CERT_BASE_DIR=
LEGACY_ADMIN_BACK_ROOT=E:/admin/admin_back
PAYMENT_ALIPAY_TIMEOUT=10s
PAYMENT_NOTIFY_LOCK_TTL=30s
PAYMENT_ATTEMPT_LOCK_TTL=30s
```

不把 app_id、证书路径、notify_url 放 env。渠道配置事实源是 `pay_channel` 表。

## Logging / audit

### pay_notify_logs

必须落库字段：

```text
channel=2
notify_type=1
transaction_no
trade_no
headers(masked)
raw_data(masked)
process_status pending/success/failed/ignored
process_msg
ip
```

### OperationLog

第三方回调不走后台用户，不写 OperationLog。它写 `pay_notify_logs` 和 system log。

用户创建充值订单/支付尝试属于当前用户行为，第一刀不注册后台按钮 OperationLog，避免把个人中心用户操作混成后台管理操作。后续如果需要用户行为日志，单独建 user action log，不塞 OperationLog。

### System log

可记录：

```text
transaction_no
order_no
channel_id
trade_no
status
error message
```

禁止记录：

```text
app_private_key
app_private_key_enc
certificate content
raw Authorization/Cookie
完整支付宝 sign 字段不是密钥，但为减少日志污染，不在普通 system log 输出完整 raw notify
```

## Frontend impact

当前 `admin_front_ts/src/api/pay/order.ts` 仍有 legacy：

```text
recharge -> /api/admin/pay/recharge
createPay -> /api/admin/pay/createPay
cancelOrder/queryResult/myOrders/walletInfo/walletBills -> legacy
```

第一刀只迁：

```text
OrderApi.recharge -> POST /api/admin/v1/recharge-orders
OrderApi.createPay -> POST /api/admin/v1/recharge-orders/:order_no/pay-attempts
```

不迁：

```text
walletInfo
walletBills
myOrders
queryResult
cancelOrder
```

原因：支付运行时先跑通下单/支付/回调；订单列表和钱包账单用户侧查询下一刀再迁，避免一刀太大。

前端 touched code 禁止 `any/as any/Record<string, any>`。当前 `CreatePayResponse.pay_data?: Record<string, unknown>` 可以保留，因为第三方 pay_data 的 meta 是外部边界；消费处必须收窄，不允许 `as any`。

## Tests

### Backend unit tests

必须覆盖：

```text
payment cert path resolver: absolute, relative + LEGACY_ADMIN_BACK_ROOT, missing file error
alipay gateway builder: missing VAULT_KEY, decrypt failure, missing app_id, missing cert path
notify verifier: invalid sign returns error, app_id mismatch, amount mismatch
payruntime service: create recharge order blocks existing pending order
payruntime service: create pay attempt closes last active txn and creates new attempt
payruntime service: gateway failure marks txn failed
payruntime service: duplicate callback returns success without duplicate wallet credit
payruntime service: callback success updates txn/order/fulfillment/wallet in transaction
redislock: unlock cannot delete other token lock
```

SDK 真实网络调用必须通过 fake gateway 测 service；平台层只做构造和本地验签/路径测试，不在 unit test 打支付宝网络。

### Smoke

默认 full smoke 不真实支付扣款，但增加安全探针：

```text
GET /api/admin/v1/pay-channels 确认 alipay cert path fields exist and no private key leak
POST /api/admin/v1/recharge-orders with smoke flag -EnablePaymentRuntimeProbe 才执行
POST /api/admin/v1/recharge-orders/:order_no/pay-attempts 只验证返回 pay_data shape，不自动打开支付链接
```

回调 smoke 不使用真实支付宝回调。可做：

```text
go test ./internal/module/payruntime -run TestHandleAlipayNotify
```

真实沙盒支付为 manual e2e：浏览器打开 pay_data.content，支付后等待支付宝回调，验证：

```text
pay_transactions.status=3
orders.pay_status=3
user_wallets.balance 增加
wallet_transactions 有 FULFILL:RECHARGE:{order_no}
pay_notify_logs.process_status=2
```

## Exit criteria

```text
Go 引入 gopay，但只在 internal/platform/payment/alipay 内使用。
支付宝证书路径按 pay_channel 三个字段解析到真实文件，缺失时报配置错误。
私钥通过 secretbox 解密，缺 VAULT_KEY 明确失败，不打印明文。
用户能创建充值订单、发起支付宝 web/h5 支付尝试。
支付宝异步回调能验签、校验 app_id/金额、幂等更新支付流水和订单。
充值成功能幂等入账钱包。
pay_notify_logs 有 pending/success/failed/ignored 审计事实。
新增 API 写入 docs/contracts/admin-api-v1.md。
current-status 只能标记 pay runtime partially implemented，不能宣称支付全域完成。
full smoke 增加默认安全探针；真实沙盒支付作为 manual e2e 记录。
```

## Self-review

```text
未发现占位项。
范围只覆盖支付宝沙盒充值最小闭环，没有把微信/退款/对账塞进第一刀。
证书路径、私钥、回调原始响应、幂等和事务边界已写清。
没有要求手写 RSA/验签，支付协议交给 gopay。
没有把第三方回调包进统一 JSON response。
```
