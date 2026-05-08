# Payment Domain Rebuild Design

状态：draft for review  
日期：2026-05-08  
范围：只重建支付域；不扩散到 AI、聊天、上传、客户端版本或其它业务模块。

## 结论

当前支付域允许整体推倒重建，包括旧支付管理、钱包、支付表结构、前端页面和 Go 模块。  
但重建不是把外部支付后台项目硬塞进来，而是在本项目现有 Gin/GORM/REST/RBAC/secretbox/operation log/Vue 动态菜单体系内，落一个干净的 `payment` bounded context。

推荐路线：

```text
保留 gopay 作为第一 SDK 候选；
不整体引入 gopay-platform、HotGo 或其它支付后台；
删除旧 pay/wallet 域的业务耦合；
先只实现支付宝收款闭环；
钱包、退款、对账、转账、微信全部后置，除非后续有明确产品需求。
```

## Linus 三问

1. 真问题：是。当前支付域被 PHP 迁移痕迹拖脏，模块横跨 `paychannel/payorder/paytransaction/paynotifylog/payruntime/payreconcile/wallet`，支付、钱包、对账、履约揉在一起。截图里的支付宝沙盒 500 只是表象，真正问题是边界不干净。
2. 更简单做法：不是继续修补旧钱包和旧支付管理，而是把支付域削成最小支付宝收款模型：渠道配置、支付订单、支付事件、支付宝 gateway。
3. 会破坏什么：会破坏当前支付菜单、钱包页、旧支付 API、旧测试数据和旧 cron。允许破坏，但必须通过迁移、备份、菜单权限更新、契约同步和 smoke 验证来破坏，不能手工删库跑路。

## 当前运行事实

### 当前支付模块

```text
admin_back_go/internal/module/paychannel
admin_back_go/internal/module/paynotifylog
admin_back_go/internal/module/payorder
admin_back_go/internal/module/payreconcile
admin_back_go/internal/module/payruntime
admin_back_go/internal/module/paytransaction
admin_back_go/internal/module/wallet
admin_back_go/internal/platform/payment/alipay
```

### 当前前端模块

```text
admin_front_ts/src/api/pay/*
admin_front_ts/src/views/Main/pay/*
admin_front_ts/src/views/Main/wallet/*
admin_front_ts/src/views/Main/home/components/HomeWalletPanel.vue
admin_front_ts/src/enums/PayEnum.ts
```

### 当前数据量

```text
pay_channel: 1
orders: 3
order_items: 3
pay_transactions: 3
pay_notify_logs: 0
user_wallets: 0
wallet_transactions: 0
order_fulfillments: 0
pay_reconcile_tasks: 0
pay_refunds: 0
```

这些数据量说明：重建成本低，适合现在做；继续给旧结构打补丁才是坏品味。

## 开源调研取舍

### gopay

采用：作为第一支付宝 SDK 候选。

理由：

```text
当前项目已经依赖 github.com/go-pay/gopay。
它覆盖支付宝网页/H5支付、查询、关闭、回调验签、账单下载等能力。
截图故障更像证书/配置/沙盒环境问题，不足以证明 SDK 本身不可用。
```

约束：

```text
gopay 只能存在于 internal/platform/payment/alipay。
业务 service 不直接 import SDK。
SDK 返回的第三方细节只通过本项目 Gateway DTO 暴露。
```

### smartwalle/alipay/v3

采用：作为第二 SDK 候选 PoC，不作为第一落地路线。

理由：

```text
它只做支付宝，依赖面更小。
支持公钥证书和普通公钥验签。
如果 gopay 在当前沙盒证书链路上继续不可控，可以用同一 Gateway 接口切换实现。
```

### gopay-platform

采用：只借鉴表拆分思想。

可借鉴：

```text
payment_channel
payment_channel_config
payment_order
金额使用分
支付订单独立于业务订单
```

不采用：

```text
不整体搬项目。
不搬 panic 初始化。
不搬硬编码 return_url/notify_url。
不搬全 POST 风格。
不引入它的 web/orm/xlog 体系。
```

### HotGo

采用：只借鉴支付网关接口思想。

可借鉴：

```text
PayClient 小接口。
支付网关只负责收钱。
业务回调/履约不要写死在 SDK 层。
```

不采用：

```text
不引入 GoFrame。
不搬 panic 单号生成。
不搬无主 goroutine 异步回调。
```

## 新支付域目标

第一阶段只做到：

```text
后台可配置支付宝渠道。
当前用户可创建支付宝支付订单。
后端可生成支付宝网页/H5支付链接。
支付宝异步通知可验签、校验金额、幂等落库。
后台可查看支付订单和事件。
定时任务可关闭过期订单、同步 pending 订单。
```

第一阶段明确不做：

```text
钱包余额
人工调账
退款
对账
转账
微信
多商户平台
复杂分账
```

如果产品后续需要余额账户，再单独设计 `wallet/account_ledger`，不要让支付 SDK 直接改余额。

## 后端边界

### 包结构

目标结构：

```text
admin_back_go/internal/module/payment
  controller.go
  service.go
  repository.go
  model.go
  dto.go
  route.go
  enum.go
  errors.go

admin_back_go/internal/platform/payment
  gateway.go

admin_back_go/internal/platform/payment/alipay
  gateway.go
  cert.go
  mapper.go
```

删除或退役：

```text
internal/module/paychannel
internal/module/paynotifylog
internal/module/payorder
internal/module/payreconcile
internal/module/payruntime
internal/module/paytransaction
internal/module/wallet
```

如果为了渐进迁移必须短期共存，旧包只能标记 retired，并且不能再注册新 route。

### Gateway 接口

支付 service 只依赖本项目接口：

```go
type Gateway interface {
    CreatePagePay(ctx context.Context, cfg ChannelConfig, req CreatePayRequest) (*CreatePayResult, error)
    Query(ctx context.Context, cfg ChannelConfig, outTradeNo string) (*QueryResult, error)
    VerifyNotify(ctx context.Context, cfg ChannelConfig, form map[string]string) (*NotifyResult, error)
    Close(ctx context.Context, cfg ChannelConfig, outTradeNo string) error
}
```

规则：

```text
所有网络 IO 必须带 context timeout。
VerifyNotify 是本地验签，不需要网络 timeout。
任何 SDK error 必须 wrap，不能 panic。
SDK raw response 只能进 payment_events，不直接污染业务表。
金额统一用 cents BIGINT，不用 float。
```

## 数据模型

允许删除旧表，但必须用迁移完成，不手工删。

### payment_channels

用途：渠道基础信息，不存私钥正文。

关键字段：

```text
id BIGINT PK
code VARCHAR(64) UNIQUE              # alipay_sandbox / alipay_prod
name VARCHAR(128)
provider VARCHAR(32)                 # alipay
status TINYINT                       # 1 enabled, 2 disabled
supported_methods JSON               # ["web","h5"]
remark VARCHAR(255)
is_del TINYINT                       # 1 deleted, 2 normal，沿用项目习惯
created_at DATETIME
updated_at DATETIME
```

### payment_channel_configs

用途：渠道密钥、证书和环境配置。

关键字段：

```text
id BIGINT PK
channel_id BIGINT UNIQUE
app_id VARCHAR(64)
merchant_id VARCHAR(64)
sign_type VARCHAR(16)                # RSA2
is_sandbox TINYINT
notify_url VARCHAR(512)
return_url VARCHAR(512)
private_key_enc TEXT                 # secretbox 加密
app_cert_path VARCHAR(512)
alipay_cert_path VARCHAR(512)
alipay_root_cert_path VARCHAR(512)
extra_config JSON
created_at DATETIME
updated_at DATETIME
```

规则：

```text
private_key_enc 不出响应、不进 operation log、不进 smoke 输出。
证书文件仍归属 admin_back_go/runtime/cert/alipay。
路径必须经过 CertPathResolver，不允许回退 PHP 根目录。
```

### payment_orders

用途：本地支付订单，独立于旧 `orders`。

关键字段：

```text
id BIGINT PK
order_no VARCHAR(64) UNIQUE          # 本地支付订单号
user_id BIGINT
channel_id BIGINT
provider VARCHAR(32)                 # alipay
pay_method VARCHAR(16)               # web / h5
subject VARCHAR(128)
amount_cents BIGINT
currency VARCHAR(8)                  # CNY
status TINYINT                       # pending/paying/succeeded/closed/failed
out_trade_no VARCHAR(64) UNIQUE      # 给支付宝的商户订单号
trade_no VARCHAR(128)                # 支付宝交易号
pay_url TEXT
paid_at DATETIME NULL
expired_at DATETIME
closed_at DATETIME NULL
client_ip VARCHAR(64)
return_url VARCHAR(512)
business_type VARCHAR(64)            # recharge/subscription/manual_test
business_ref VARCHAR(128)
is_del TINYINT
created_at DATETIME
updated_at DATETIME
```

状态规则：

```text
pending -> paying -> succeeded
pending/paying -> closed
pending/paying -> failed
succeeded 是终态，不能回退。
closed 是终态，除非明确创建新订单。
```

### payment_events

用途：统一审计 notify/query/create/close。

关键字段：

```text
id BIGINT PK
order_no VARCHAR(64)
out_trade_no VARCHAR(64)
event_type VARCHAR(32)               # create/query/notify/close/sync
provider VARCHAR(32)
request_data JSON
response_data JSON
process_status TINYINT               # pending/success/failed/ignored
error_message VARCHAR(1024)
created_at DATETIME
```

规则：

```text
原 pay_notify_logs 可被 payment_events 取代。
第三方 raw 数据只进 event，敏感字段先 sanitize。
重复通知写 ignored/success 事件，但不能重复改 payment_orders。
```

## API 契约

后台管理：

```text
GET    /api/admin/v1/payment/channels/page-init
GET    /api/admin/v1/payment/channels
POST   /api/admin/v1/payment/channels
PUT    /api/admin/v1/payment/channels/:id
PATCH  /api/admin/v1/payment/channels/:id/status
DELETE /api/admin/v1/payment/channels/:id

GET    /api/admin/v1/payment/orders/page-init
GET    /api/admin/v1/payment/orders
GET    /api/admin/v1/payment/orders/:id
PATCH  /api/admin/v1/payment/orders/:id/close

GET    /api/admin/v1/payment/events
GET    /api/admin/v1/payment/events/:id
```

当前用户支付：

```text
POST   /api/admin/v1/payment/orders
POST   /api/admin/v1/payment/orders/:order_no/pay
GET    /api/admin/v1/payment/orders/:order_no/result
PATCH  /api/admin/v1/payment/orders/:order_no/cancel
```

公共回调：

```text
POST   /api/payment/notify/alipay
```

兼容规则：

```text
旧 /api/admin/v1/recharge-orders 不保留长期兼容。
如果前端需要过渡，最多在同一个发布内做 redirect/retired notice，不新增双写逻辑。
notify 返回支付宝要求的 text/plain success/fail，不套 admin JSON。
```

## RBAC 和菜单

旧菜单可全部移除：

```text
支付渠道
统一订单管理
支付流水
钱包管理
回调审计
对账管理
个人钱包
```

新菜单建议：

```text
支付管理
  支付渠道
  支付订单
  支付事件
```

新权限建议：

```text
payment_channel_list
payment_channel_add
payment_channel_edit
payment_channel_status
payment_channel_del
payment_order_list
payment_order_close
payment_event_list
```

规则：

```text
权限和菜单必须通过 DB migration 更新。
不能只删前端路由，不清 DB 权限，否则运行时菜单还会残留。
不能只删 DB 菜单，不删前端 view，否则死代码继续堆积。
```

## 前端设计

Vue 3 仍按项目现状走 Composition API 和 typed API client。

删除：

```text
admin_front_ts/src/api/pay/*
admin_front_ts/src/views/Main/pay/*
admin_front_ts/src/views/Main/wallet/*
admin_front_ts/src/views/Main/home/components/HomeWalletPanel.vue
```

新增：

```text
admin_front_ts/src/api/payment/channel.ts
admin_front_ts/src/api/payment/order.ts
admin_front_ts/src/api/payment/event.ts

admin_front_ts/src/views/Main/payment/channel
admin_front_ts/src/views/Main/payment/order
admin_front_ts/src/views/Main/payment/event
```

组件规则：

```text
route view 只做 composition surface。
列表查询、支付动作、表单状态放 composable。
弹窗/表格/详情拆小组件。
不使用 any。
不让前端猜支付状态文本；状态字典来自 Go page-init。
打开支付宝链接前必须校验 pay_url 是 http/https/alipays scheme。
```

## 迁移策略

### 第一阶段：设计和备份

```text
写 spec。
写 implementation plan。
导出现有支付相关表结构和数据快照。
记录旧菜单/权限 ID。
```

### 第二阶段：建新表，停旧入口

```text
新增 payment_* 表。
新增 payment module 和 alipay gateway。
注册新 routes。
前端新增新 payment 页面。
旧 pay/wallet 菜单从 DB 软删除。
```

### 第三阶段：删除旧域

```text
删除旧 Go 模块。
删除旧前端 API/view。
删除旧 smoke/contract 中 pay/wallet 章节，替换为 payment 章节。
删除旧 cron payment row 或标记 retired。
```

### 第四阶段：清旧表

```text
如果旧表只有测试数据，迁移中先 rename 成 *_legacy_20260508 或备份后 drop。
不要直接 drop orders/users 等非支付基础表。
orders/order_items 是否删除必须单独确认它们是否被其它业务引用。
pay_channel/pay_transactions/pay_notify_logs/user_wallets/wallet_transactions/order_fulfillments/pay_reconcile_tasks/pay_refunds 可进入支付域清理候选。
```

注意：`orders` 和 `order_items` 名字不是 payment 前缀，必须先查引用。允许重构支付域不等于允许误删其它业务订单表。

## 定时任务

第一阶段只保留两个必要任务：

```text
payment_close_expired_order -> payment:close-expired-order:v1
payment_sync_pending_order  -> payment:sync-pending-order:v1
```

退役：

```text
pay_reconcile_daily
pay_reconcile_execute
pay_fulfillment_retry
pay_refund_sync
```

规则：

```text
cron_task DB row 是配置和展示。
Go registry 是可执行白名单。
禁止执行旧 PHP handler 字符串。
禁止注册 noop 假装完成。
```

## 验证标准

后端：

```text
go test ./internal/module/payment ./internal/platform/payment/alipay ./internal/module/crontask ./internal/jobs ./internal/bootstrap
go test -race ./internal/module/payment ./internal/platform/payment/alipay
```

前端：

```text
npm run typecheck
npm run test -- payment
npm run build
```

脚本：

```text
scripts/check-payment-certs.ps1 -DisallowLegacyRoot
scripts/check-contract.ps1
scripts/full-admin-smoke.ps1
```

smoke 必须覆盖：

```text
payment channel page-init/list
payment order page-init/list/detail
payment event list/detail
current-user create order/pay/result/cancel
private key 不泄露
notify route 返回 text/plain success/fail
cron registry 包含新 payment task type
旧 pay/wallet 菜单不再出现在运行时菜单
```

## 风险和处理

### 支付宝沙盒 500

处理：

```text
先更新/校验证书和 app_id/merchant_id/private key/notify_url/return_url。
用最小 CreatePagePay PoC 证明 SDK 与配置链路。
如果 gopay 仍不可控，用同一 Gateway 接口切 smartwalle/alipay/v3 PoC。
```

### 误删非支付订单表

处理：

```text
orders/order_items 删除前必须查所有代码引用和真实业务含义。
如果不是纯支付充值测试表，不能跟 pay_* 一起删。
```

### 前端菜单残留

处理：

```text
DB permissions/role_permissions/menu migration 必须和前端 route 删除一起做。
运行时菜单以 DB 为准，不以源码删除为准。
```

### 钱包需求反复

处理：

```text
第一阶段不做钱包。
如果后续确认需要余额账户，新增 wallet/account_ledger spec。
支付回调只发出 payment succeeded 事实，由业务模块消费；不要在支付 SDK 层直接加余额。
```

## 审查清单

```text
没有 TBD/TODO。
没有要求整体引入外部支付后台。
没有把 GoFrame/外部 ORM/外部 logger 带进项目。
没有把 SDK 泄漏到 business service。
没有 float 金额。
没有无主 goroutine。
没有网络 IO 放在 DB transaction 内。
没有长期双写旧 pay/wallet API。
删除范围包含 DB 菜单/权限、前端路由、后端 route、contract、smoke。
```
