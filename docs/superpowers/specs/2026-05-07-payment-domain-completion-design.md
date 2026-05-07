# Payment Domain Completion Design

状态：updated after certificate ownership and PayReconcile admin REST landing。
日期：2026-05-07

本文只设计 **支付域**。本轮不扩散到 AI、聊天、上传、客户端版本或其它业务模块。

## Linus 三问

1. 真问题：是。支付不是一个页面，而是资金状态机：支付配置、证书、用户充值、第三方回调、钱包入账、后台审计、定时补偿、对账、履约重试都必须闭环。只迁三个 cron 或只迁几个列表接口都是半成品。
2. 更简单做法：不造“支付中台”。继续沿用当前 Gin modular monolith：REST 在 `admin-api`，scheduler/Asynq 在 `admin-worker`，第三方 SDK 只在 `internal/platform/payment/*`，业务状态机在支付模块 service/repository。
3. 会破坏什么：会碰订单、支付流水、回调日志、钱包余额、履约记录和第三方网关。任何重复入账、私钥泄露、证书继续依赖 PHP、cron 注册 noop、或把 legacy PHP handler 字符串当可执行任务，都是坏改动。

## 当前已确认事实

### 已经落地

```text
支付证书归属：Alipay cert 已复制到 admin_back_go/runtime/cert/alipay；runtime/cert 不进 git。
配置归属：admin_back_go/.env.example 已设置 PAYMENT_CERT_BASE_DIR=E:/admin_go/admin_back_go，LEGACY_ADMIN_BACK_ROOT=。
私钥归属：私钥仍只在 pay_channel.app_private_key_enc，经 secretbox 解密后传 SDK，不落盘。
支付宝 runtime：current-user 充值、pay attempts、结果查询、取消、本地钱包 summary/bills、raw Alipay notify 已在 Go。
支付宝补偿 cron：pay_close_expired_order、pay_sync_pending_transaction 已映射到 Go task type。
后台支付管理：pay channel、pay transaction read、pay notify log read、pay order admin、wallet admin 已迁 Go。
PayReconcile admin REST：page-init/list/detail/retry/file routes 已接入 Go；前端 reconcile API 已改用 Go REST request。
PayReconcile cron/runtime 第一版：pay_reconcile_daily/pay_reconcile_execute 已映射到 Go task type；daily 幂等创建任务，execute 已实现 Alipay trade bill 下载、UTF-8/GBK CSV/zip 解析、本地/平台/diff CSV 输出；无差异 success，有差异 diff，平台网络/下载/解析失败明确 failed，不 fake success。
```

### DB 运行事实

```text
pay_channel 当前只有 id=1 的支付宝官方沙盒，channel=2，status=1，is_del=2。
pay_channel 没有 supported_methods 列；支持方式在 extra_config.supported_methods，当前是 ["web", "h5"]。
当前没有 active WeChat channel。
pay_refunds 当前 count=0。
pay_refund_sync cron row 存在但 is_del=1，是 deleted legacy row，不是 active runtime。
```

当前支付 cron truth：

```text
pay_close_expired_order       handler=pay:close-expired-order:v1       is_del=2
pay_sync_pending_transaction  handler=pay:sync-pending-transaction:v1  is_del=2
pay_fulfillment_retry         handler=pay:fulfillment-retry:v1         is_del=2 after Go migration
pay_reconcile_daily           handler=pay:reconcile-daily:v1           is_del=2 after Go migration
pay_reconcile_execute         handler=pay:reconcile-execute:v1         is_del=2 after Go migration
pay_refund_sync               handler=app\process\Pay\PayRefundSyncTask        is_del=1
```

### 仍未完整迁移

```text
pay_reconcile_daily          -> pay:reconcile-daily:v1 已注册，daily creation implemented
pay_reconcile_execute        -> pay:reconcile-execute:v1 已注册，execute first version implemented with Alipay bill download/parser/diff; real sandbox platform availability still manual/special-probe only
pay_fulfillment_retry        -> pay:fulfillment-retry:v1 已注册，first version implemented；失败履约重试复用钱包入账幂等路径
WeChat runtime               -> 当前未启用；无 active channel，不实现 notify/wechat
Refund runtime               -> retired / pending-decision；无退款 contract 前不注册 pay_refund_sync
```

## 支付域目标

```text
Go 项目成为支付域唯一运行时 owner。
PHP 项目销毁后，支付配置、证书解析、支付宝回调、钱包入账、补偿 cron、对账管理、后续对账执行和履约重试仍可运行。
```

完成后的最低标准：

```text
1. 支付证书不依赖 E:/admin/admin_back。
2. 支付私钥不落文件、不进响应、不进 operation log、不进 smoke 输出。
3. 支付配置、用户充值、支付尝试、支付回调、钱包入账、后台审计、对账、履约重试有明确状态机。
4. cron_task 中 active 支付任务要么 registered 到 Go task type，要么明确 retired/disabled。
5. 前端支付域 `src/api/pay`、`views/Main/pay`、`views/Main/wallet` 不再使用 legacyRequest。
6. WeChat/refund 不能靠 enum 或旧表存在冒充已实现。
```

## 不变式

### 订单与流水

```text
orders.order_no 是业务订单号。
pay_transactions.transaction_no 是第三方 out_trade_no。
一个订单可以多次支付尝试，但同一时刻只能有一条 active transaction。
创建新支付尝试前必须关闭上一条 active transaction。
支付 SDK 网络 IO 不允许放在 MySQL transaction 内。
```

### 回调和入账

```text
回调先写 pay_notify_logs pending。
验签失败、金额不匹配、app_id 不匹配、交易号不匹配都写 failed。
同一 transaction_no 使用 Redis lock 防并发。
支付成功必须在一个 DB transaction 内完成 transaction/order/fulfillment/wallet/wallet_transaction 状态变更。
重复成功回调必须幂等，不重复加钱包余额。
```

### 钱包

```text
充值入账只增加 balance 和 total_recharge。
人工调账只改 balance/version，不改 total_recharge/total_consume/frozen。
frozen 是风控/提现预留，不因当前全 0 删除。
wallet_transactions 是审计事实，不允许被静默覆盖。
```

### 定时任务

```text
cron_task DB row = 配置、启用状态、cron 表达式、页面展示。
Go registry = 可执行任务白名单。
scheduler callback = 写 cron_task_log + enqueue Asynq task。
Asynq handler = 真正业务处理。
禁止执行 cron_task.handler 字符串。
禁止把未迁任务注册成 noop 假装完成。
```

## 子域设计

### 1. 支付配置与证书

当前已落地。后续只允许做验证和部署收口：

```text
scripts/migrate-payment-certs.ps1 只复制 Alipay cert，输出 path/bytes/sha256。
scripts/check-payment-certs.ps1 -DisallowLegacyRoot 必须证明证书解析到 admin_back_go/runtime/cert/alipay。
PAYMENT_CERT_BASE_DIR 指向 Go backend root。
LEGACY_ADMIN_BACK_ROOT 在 PHP teardown 前必须为空。
runtime/cert/alipay/*.crt 不提交。
```

### 2. 用户支付 runtime

当前只实现 Alipay sandbox web/h5：

```text
GET/POST /api/admin/v1/recharge-orders
POST /api/admin/v1/recharge-orders/:order_no/pay-attempts
GET /api/admin/v1/recharge-orders/:order_no/result
PATCH /api/admin/v1/recharge-orders/:order_no/cancel
GET /api/admin/v1/wallet/summary
GET /api/admin/v1/wallet/bills
POST /api/pay/notify/alipay
```

规则：

```text
Alipay SDK 只在 internal/platform/payment/alipay。
Alipay notify 返回 text/plain success/fail，不套 admin JSON。
取消本人订单仍是 local close；自动过期关单 cron 才 best-effort 查单/关单。
WeChat 不因为旧 PHP 有 notify 就默认迁；当前无 active channel，先记录 not active。
```

### 3. PayReconcile admin REST

当前 backend/frontend 已落地，职责只到后台管理和重试状态重置：

```text
GET   /api/admin/v1/pay-reconcile-tasks/page-init
GET   /api/admin/v1/pay-reconcile-tasks
GET   /api/admin/v1/pay-reconcile-tasks/:id
PATCH /api/admin/v1/pay-reconcile-tasks/:id/retry
GET   /api/admin/v1/pay-reconcile-tasks/:id/files/:type
```

规则：

```text
page-init 返回 pay_channel_arr/channel_arr/reconcile_status_arr/bill_type_arr。
list 支持 channel/status/bill_type/start_date/end_date。
detail 返回任务事实和 file URL，不 inline 读取文件正文。
retry 只允许 failed -> pending，并清空计数、文件 URL、error、started_at、finished_at。
files type 只允许 platform/local/diff；没有 URL 明确失败。
```

还没完成：

```text
Alipay 第三方账单下载已接入 Go gateway，平台失败会明确 failed。
本地账单 CSV、平台账单 CSV、diff CSV 已可生成到 runtime/reconcile_reports。
success/diff 闭环已有 fake bill 单测覆盖；真实支付宝 sandbox 平台账单下载仍需人工或专门探针验证。
full smoke 还没有 PayReconcile read-only probe。
```

### 4. PayReconcile cron/runtime

目标映射：

```text
pay_reconcile_daily   -> pay:reconcile-daily:v1
pay_reconcile_execute -> pay:reconcile-execute:v1
```

设计：

```text
Daily task：按 active pay_channel + 日期创建 pay_reconcile_tasks；同 channel/date/bill_type 幂等。
Execute task：扫描 pending/重试后的任务，pending -> download -> comparing -> success/diff/failed。
本地账单：读取成功 pay_transactions，按 channel/date 汇总。
平台账单：Alipay 通过 platform/payment/alipay gateway 下载；非 Alipay active channel 明确 failed unsupported。
差异输出：比较 transaction_no/trade_no/amount/status，生成 platform/local/diff 三类文件。
文件位置：优先 runtime/reconcile_reports；只返回 URL/path 元数据，不把大文件塞进 JSON。
```

### 5. Fulfillment retry cron

目标映射：

```text
pay_fulfillment_retry -> pay:fulfillment-retry:v1
```

职责：

```text
扫描 failed 或到期 retryable 的 order_fulfillments。
只重试支付域能幂等处理的充值入账 fulfillment。
复用现有 wallet credit 幂等路径，不复制第二套加余额逻辑。
wallet_transactions.biz_action_no 是最终重复入账防线。
超过最大重试次数保持 failed/manual，并记录 last_error。
```

### 6. WeChat runtime

当前决策：not active。

```text
WeChat payment runtime is not active: current DB has no active channel=1 row.
DB 没有 active WeChat pay_channel。
Go 不实现 /api/pay/notify/wechat。
前端/后端不能把 WeChat enum 当已可支付。
If a WeChat channel is later enabled, write a dedicated WeChat runtime spec before coding.
```

如果未来启用，必须单独写 WeChat spec，至少覆盖：

```text
商户证书/API v3 key/serial number
create h5/scan/mp/mini/app
query/close
notify decrypt/verify
success/fail response format
cert 文件迁移到 admin_back_go/runtime/cert/wechat
fake gateway 单测和 sandbox/manual e2e 边界
```

### 7. Refund runtime

当前决策：retired / pending-decision。

```text
Refund runtime is retired/pending-decision: pay_refunds count is 0 and pay_refund_sync is_del=1.
没有 refund contract 前，不注册 pay_refund_sync，不写 noop，不写假 sync。
```

如果未来启用，必须单独写 refund spec，至少覆盖：

```text
退款申请 API
第三方退款调用
退款查询/同步 cron
退款回调或查询补偿
orders/pay_transactions/pay_refunds 状态变更
钱包冲正或资金调整规则
对账影响
RBAC + operation log
```

## 分阶段完成定义

### P0：证书脱离 PHP

状态：implemented，仍需每次 release 跑 gate。

```text
admin_back_go/runtime/cert/alipay 三个证书存在。
PAYMENT_CERT_BASE_DIR 指向 admin_back_go。
LEGACY_ADMIN_BACK_ROOT 为空时，Go 支付宝 runtime 仍能解析证书。
check-payment-certs.ps1 -DisallowLegacyRoot 通过。
```

### P1a：PayReconcile admin REST

状态：implemented in backend/frontend targeted tests，仍需同步 contract/smoke 文档。

```text
Go 有 internal/module/payreconcile。
Go routes 已挂载。
front src/api/pay/reconcile.ts 使用 request + /api/admin/v1/pay-reconcile-tasks。
```

### P1b：PayReconcile cron/runtime

状态：implemented first version。

```text
pay_reconcile_daily registered。
pay_reconcile_execute registered。
对账任务 pending/failed -> download -> comparing -> success/diff/failed 可测试。
Daily task 幂等创建已实现。
Execute task 可下载 Alipay trade bill、解析 UTF-8/GBK CSV 或 zip、生成 local/platform/diff CSV。
平台网络、账单不可用或解析失败必须 failed，不能 fake success。
```

### P2：履约失败重试

状态：implemented first version。

```text
pay_fulfillment_retry registered。
失败履约能幂等重试。
重复执行不会重复入账。
```

### P3：WeChat runtime

状态：not active。

```text
无 active WeChat channel：文档标记未启用，不实现 notify/wechat。
有 active WeChat channel：先写专门 spec，再实现。
```

### P4：Refund runtime

状态：retired / pending-decision。

```text
pay_refund_sync 保持 deleted/disabled。
无 refund spec 前不注册 Go task。
```

### P5：支付域总验证

```text
Go targeted tests pass。
Frontend pay contract tests pass。
Contract check pass。
Full smoke payment read path pass。
Optional sandbox payment probe 不冒充真实付款/回调验证。
PHP legacy root 不再是支付 runtime 必需依赖。
```

## 验证命令

后端：

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/platform/payment ./internal/platform/payment/alipay ./internal/module/payruntime
go test ./internal/module/paychannel ./internal/module/paytransaction ./internal/module/paynotifylog ./internal/module/payorder ./internal/module/wallet ./internal/module/payreconcile
go test ./internal/module/crontask ./internal/jobs ./internal/bootstrap ./internal/server
```

前端：

```powershell
cd E:/admin_go/admin_front_ts
npx vitest run tests/shared/pay
npx vue-tsc -b --pretty false
```

支付证书 gate：

```powershell
cd E:/admin_go/admin_back_go
powershell -ExecutionPolicy Bypass -File .\scripts\check-payment-certs.ps1 -DisallowLegacyRoot
```

legacy 支付前端 gate：

```powershell
cd E:/admin_go
rg -n "legacyRequest" admin_front_ts/src/api/pay admin_front_ts/src/views/Main/pay admin_front_ts/src/views/Main/wallet
```

## 不做的事

```text
不把支付做成微服务。
不引入动态执行 PHP class 字符串。
不把证书正文写入文档或 git。
不把真实私钥写入文件。
不注册 fake/noop cron 冒充支付完成。
不把微信/退款写成已实现。
```
