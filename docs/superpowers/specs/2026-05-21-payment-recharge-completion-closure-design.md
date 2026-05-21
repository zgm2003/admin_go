# Payment Recharge Completion Closure Design

日期：2026-05-21
状态：draft for review
范围：补齐支付宝充值完成闭环，让用户支付后即使关闭网页，也能通过 callback、返回页同步和定时补偿最终看到支付成功与钱包入账。本 spec 只覆盖当前 Go/Vue 支付域的支付宝充值，不扩散到微信、退款、订阅、对账或其它业务履约。

## 1. 结论

当前充值收银台已经能完成这条链路：

```text
选套餐 -> 创建 payment_recharges + payment_orders -> 拉起支付宝 -> return_url 回到 /payment/recharge -> 前端调用 sync -> 后端 TradeQuery -> 订单 paid -> 充值 credited -> 钱包入账
```

但它还不是生产级闭环。用户如果付款后没有回到我们的页面，或者浏览器在支付宝页直接关闭，当前默认链路不会立刻把本地订单推进到成功。要解决这个真实问题，需要三层互补：

```text
1. 支付宝异步回调：主链路。用户关网页也能入账。
2. return_url / reopen 自动 sync：体验链路。用户回到充值页时快速刷新状态。
3. 定时补偿 sync/close：兜底链路。callback 丢失、用户不返回、订单过期也能最终收敛。
```

本 slice 的最终用户预期：

```text
用户支付成功后：
- 如果回到充值页，页面自动同步并显示成功。
- 如果关闭网页，后端仍会通过 callback 或补偿任务推进状态。
- 如果本地/测试环境没有公网 callback，用户重新打开充值页也会自动同步最近的支付中充值单。
```

## 2. Linus 三问

### 2.1 这是真问题吗？

是。资金链路不能依赖“用户一定会回到页面”。用户付款成功后关闭浏览器、支付宝 return_url 被拦截、网络切换、callback 重试延迟，都是正常场景。只靠前端 return_url sync 会导致后台长期显示 `paying`，用户余额没有入账，客服和运营都无法解释。

### 2.2 更简单的方法是什么？

不做支付中台，不引入新业务抽象。继续复用现有支付状态机：

```text
payment_orders = 底层支付单
payment_recharges = 用户充值单
user_wallets / wallet_transactions = 入账事实
internal/platform/payment/alipay = 支付宝 SDK 边界
internal/module/payment = 订单、充值、钱包状态推进 owner
```

新增最小闭环：

```text
callback handler -> 复用 order/recharge finalize 逻辑
cron sync      -> 复用已有 SyncOrder/SyncRecharge 状态机
frontend reopen sync -> 复用已有 /payment/recharges/:id/sync
```

不新开“回调状态机”，不让 callback 直接绕过充值入账逻辑，不让前端自己判断 paid。

### 2.3 会破坏什么吗？

不能破坏：

```text
/payment/config
/payment/recharge
隐藏的 /payment/orders 只读/运维可见能力
payment_configs 私钥/证书安全边界
payment_orders 已有 pay/sync/close 行为
payment_recharges 入账幂等
wallet_transactions(source_type, source_id) 幂等事实
登录、RBAC、OperationLog、current-status、smoke 口径
```

特别禁止：

```text
后台手工把订单改 paid
前端根据 return_url 参数直接改成功
回调不验签就入账
金额不匹配仍入账
重复 callback 重复加余额
把支付宝原始 payload 写进 OperationLog
把支付回调放到 /api/admin/v1 且要求后台登录
把定时任务注册成 noop 假装完成
```

## 3. 当前事实源

当前已落地事实：

```text
支付配置：payment_configs，支持支付宝私钥、证书、notify_url、sort、enabled_methods。这里的 notify_url 只是支付宝官方字段名；我们自己的路由、表名和服务名统一用 callback。
底层订单：payment_orders，支持 create/pay/sync/close；paid 由支付宝 query/sync 写入。
充值收银台：payment_recharges + payment_recharge_packages + user_wallets + wallet_transactions。
前端页面：/payment/recharge 自动生成 return_url，并在 URL 带 recharge_no 时调用 sync。
入账：CreditRecharge 使用 DB transaction 和钱包流水幂等边界。
证书目录：PAYMENT_CERT_BASE_DIR=/app 是 Docker 容器内的文件系统基路径，不是 URL；resolver 会把它和 runtime/payment/certs/alipay/<config_code>/<sha256>.crt 拼成 /app/runtime/payment/certs/alipay/...。证书只随后端运行节点挂载，不放 MySQL/Redis state 节点。
```

当前缺口：

```text
没有 active public Alipay callback endpoint。
没有 payment callback 审计表。
没有 payment_sync_pending_order / payment_close_expired_order Go cron。
普通打开充值页只刷新列表，不会自动同步所有最近 paying 订单。
默认 smoke 只做支付读 gate，不做真实支付宝 mutation。
```

文档现状也明确：当前 Alipay v1 不含 callback、自动 close/sync cron，这两个必须另写 spec 后再实现。

### 4.3 为什么要有 payment_callback_events

这张表只记第三方回调的审计事实，不替代业务状态表。

用途只保留四类：

```text
1. 证明支付宝是否真的打到我们这里，以及何时打到。
2. 记录验签、金额、app_id、订单号是否通过。
3. 记录我们返回了 success 还是 fail，失败原因是什么。
4. 给重复回调、漏回调、未入账、错账排查留证据。
```

它不承担：

```text
不作为订单状态源。
不作为钱包余额源。
不替代 payment_orders / payment_recharges / wallet_transactions。
不把第三方 payload 混进 OperationLog。
```

## 4. Scope

### 4.1 In scope

```text
1. 新增支付宝异步回调入口 POST /api/payment/callbacks/alipay。
2. 新增 payment_callback_events 审计表，记录每次回调的接收、验签、匹配和处理结果。
3. 新增支付宝 callback 验签/解析边界，优先复用 gopay SDK 能力，不手写 RSA。
4. callback 成功后复用 payment_orders + payment_recharges 的现有状态机，推进 paid/credited。
5. callback 与手动 sync 共用同一个“支付成功后入账”内部服务边界，保证幂等。
6. 新增 Go task type：payment:sync-pending-order:v1。
7. 新增 Go task type：payment:close-expired-order:v1。
8. 新增 cron_task seed：payment_sync_pending_order、payment_close_expired_order。
9. 前端 /payment/recharge 页面打开后自动同步当前用户最近少量 paying 充值单。
10. 保留 return_url 带 recharge_no 自动 sync，并明确它只是体验链路，不是唯一闭环。
11. 更新 API contract、backend architecture、current-status、smoke matrix。
12. 补后端单测、前端行为测试、credential-gated manual smoke 说明。
```

### 4.2 Out of scope

```text
微信支付
退款 / 退款回调
提现 / 冻结
订阅权益、会员有效期、商品履约
对账单下载和差异处理
支付回调消息中心
多租户支付配置
用户端 app 支付
跨域 ticket auth
支付宝服务商模式
ngrok / 内网穿透部署教程
支付配置 UI 重做
/payment/orders raw create UX 回归
```

## 5. 目标行为

### 5.1 用户正常支付并返回

```text
POST /api/admin/v1/payment/recharges
  -> 创建充值单和支付单
  -> 返回 pay_url
浏览器跳转支付宝
支付宝支付成功
浏览器跳回 return_url=/payment/recharge?tab=records&recharge_no=<recharge_no>
前端检测 recharge_no
前端 POST /api/admin/v1/payment/recharges/:id/sync
后端 TradeQuery
后端推进 paid/credited
前端刷新钱包和记录
```

这条链路当前已经存在，本 slice 只做稳定化：错误提示、重复调用幂等、与 reopen sync 共用去重逻辑。

### 5.2 用户支付后关闭网页

生产目标：

```text
支付宝 POST /api/payment/callbacks/alipay
后端验签 + 校验 app_id/out_trade_no/amount/trade_status
后端标记 payment_orders.paid
若该 order 属于充值单，后端 CreditRecharge
支付宝收到 plain text success
用户下次打开 /payment/recharge，列表直接看到 credited
```

本地或 callback 不可达目标：

```text
用户重新打开 /payment/recharge
页面加载列表
发现最近 N 条 paying 充值单
自动逐条调用 /payment/recharges/:id/sync
后端主动 TradeQuery
若支付宝已成功，推进 credited
```

### 5.3 callback 丢失或延迟

```text
admin-worker 定时触发 payment_sync_pending_order
查询 paying payment_orders
对未过期或短期已过期的订单调用 TradeQuery
成功 -> paid -> 充值入账
未支付 -> 保持 paying
支付宝返回 closed -> 本地 close
错误 -> 记录 cron_task_log/task error，不把订单改失败
```

### 5.4 用户不支付或订单过期

```text
admin-worker 定时触发 payment_close_expired_order
查询 expired_at < now 且 status in pending/paying 的 payment_orders
pending：直接本地 close
paying：优先调用支付宝 TradeQuery
  - paid：走成功入账
  - waiting：调用 TradeClose 后本地 close
  - closed：本地 close
  - query/close 失败：保留 paying，记录错误，下轮重试
```

## 6. API 设计

### 6.1 Public Alipay callback endpoint

```text
POST /api/payment/callbacks/alipay
Content-Type: application/x-www-form-urlencoded
AuthToken: 不需要
OperationLog: 不写
Response: text/plain; charset=utf-8
成功：success
失败：fail
```

该路由不是后台管理 API，不放在 `/api/admin/v1` 下。它只服务支付宝服务器回调，不能依赖浏览器 cookie、Bearer token、RBAC 或 CSRF。

处理规则：

```text
1. 先读取 form body，生成 request_id。
2. 先写 payment_callback_events received/pending 记录；写失败也要 system log。
3. 使用支付宝公钥证书验签。
4. 验签失败：event=failed，返回 fail。
5. 根据 out_trade_no 查 payment_orders。
6. 查不到订单：event=ignored，返回 success；不让支付宝无限重试无意义订单。
7. app_id 与 payment_configs.app_id 不匹配：event=failed，返回 fail。
8. total_amount 与 payment_orders.amount_cents 不匹配：event=failed，返回 fail。
9. trade_status in TRADE_SUCCESS/TRADE_FINISHED：进入成功 finalize。
10. trade_status 不是成功态：event=ignored，返回 success。
11. finalize 成功：event=success，返回 success。
12. finalize 内部错误：event=failed，返回 fail，让支付宝后续重试。
```

### 6.2 Existing admin sync routes

保留现有接口：

```text
POST /api/admin/v1/payment/recharges/:id/sync
POST /api/admin/v1/payment/orders/:id/sync
```

本 slice 不改它们的 URL，不新增别名，不引入全 POST 兼容路由。

新增要求：

```text
sync 与 callback 调用同一个 order/recharge finalize 内部函数。
sync 如果发现订单已 paid/充值已 credited，要幂等返回当前状态。
sync 不接受前端传入 paid/status/trade_no。
```

## 7. 数据库设计

### 7.1 新表：payment_callback_events

```sql
CREATE TABLE `payment_callback_events` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `provider` VARCHAR(32) NOT NULL DEFAULT 'alipay',
  `notify_id` VARCHAR(128) NOT NULL DEFAULT '',
  `out_trade_no` VARCHAR(64) NOT NULL DEFAULT '',
  `trade_no` VARCHAR(64) NOT NULL DEFAULT '',
  `trade_status` VARCHAR(32) NOT NULL DEFAULT '',
  `app_id` VARCHAR(64) NOT NULL DEFAULT '',
  `total_amount_cents` BIGINT NOT NULL DEFAULT 0,
  `signature_valid` TINYINT NOT NULL DEFAULT 2,
  `process_status` VARCHAR(16) NOT NULL DEFAULT 'pending',
  `process_message` VARCHAR(512) NOT NULL DEFAULT '',
  `raw_payload_json` JSON NULL,
  `received_at` DATETIME NOT NULL,
  `processed_at` DATETIME NULL,
  `is_del` TINYINT NOT NULL DEFAULT 2,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_payment_callback_events_notify_id` (`provider`, `notify_id`),
  KEY `idx_payment_callback_events_out_trade_no` (`provider`, `out_trade_no`),
  KEY `idx_payment_callback_events_status_time` (`process_status`, `received_at`)
);
```

字段用途：

```text
notify_id：支付宝通知 ID，用于排查重复通知；不做唯一约束，因为支付宝重试也要留审计事实。
out_trade_no：我们的 payment_orders.order_no，定位订单。
trade_no：支付宝交易号，成功后写入 payment_orders.alipay_trade_no。
trade_status：支付宝返回的交易状态，决定 paid / credited / ignored。
app_id：验签后核对配置身份，防止串单。
total_amount_cents：金额校验和审计。
signature_valid：1/2 标识验签是否通过；不存 sign 原文到业务字段。
process_status：pending/success/failed/ignored。
process_message：失败或忽略原因，便于排查。
raw_payload_json：只存支付宝表单字段，截断大字段；不得存私钥、证书或内部 token。
```

### 7.2 现有表约束

不新增无用字段到 `payment_recharges`。充值单仍通过 `payment_order_id` 关联底层订单。

如现有索引不足，可补最小索引：

```text
payment_orders(provider, status, is_del, expired_at, id)
payment_orders(status, is_del, updated_at, id)
payment_recharges(payment_order_id, is_del)
wallet_transactions(source_type, source_id, is_del)  # 若尚无等价唯一/索引，必须补齐幂等索引
```

是否新增唯一约束要以 live schema 为准；不能在未知历史数据上强行加唯一导致迁移失败。

## 8. 后端设计

### 8.1 新内部边界：PaymentFinalizer

在 `internal/module/payment` 内抽出内部方法，不新开跨模块大抽象：

```text
FinalizeOrderPaid(ctx, orderID, tradeNo, paidAt, source)
FinalizeRechargeForOrder(ctx, orderID, paidAt, source)
```

`source` 只用于审计和日志：

```text
sync
callback
cron_sync
cron_close
```

要求：

```text
1. 支付 SDK 网络 IO 不放在 MySQL transaction 内。
2. 更新 order/recharge/wallet 必须在 DB transaction 内做行锁。
3. payment_orders paid 幂等：已 paid 时不覆盖 trade_no/paid_at，除非原字段为空。
4. payment_recharges credited 幂等：已有 wallet_transactions(source_type='recharge', source_id=recharge_id) 时不重复加余额。
5. low-level order 没有关联充值单时，只推进 payment_orders，不写钱包。
```

### 8.2 Callback handler

新增 handler 只做协议边界：

```text
parse form -> call service.HandleAlipayNotify(ctx, form) -> write plain text success/fail
```

不要把验签、金额校验、订单推进写在 handler 里。

### 8.3 Alipay platform boundary

`internal/platform/payment/alipay` 增加 callback 能力：

```text
ParseNotify(form/urlencoded body) -> NotifyPayload
VerifyNotify(payload, cfg) -> error
```

原则：

```text
使用 gopay SDK 的 ParseNotifyToBodyMap / VerifySignWithCert 能力。
证书路径仍走当前 CertPathResolver。
不手写 RSA。
不在 platform 层访问 DB。
不在 platform 层知道 payment_recharges 或 wallet。
```

### 8.4 Cron / Asynq

新增 task type：

```text
payment:sync-pending-order:v1
payment:close-expired-order:v1
```

建议 cron：

```text
payment_sync_pending_order   cron=*/2 * * * *   # 每 2 分钟补偿支付中订单
payment_close_expired_order  cron=*/5 * * * *   # 每 5 分钟关闭过期订单
```

执行范围：

```text
sync-pending：status=paying，is_del=2，updated_at <= now-30s，limit 50。
close-expired：status in pending/paying，expired_at < now，is_del=2，limit 50。
```

失败处理：

```text
单条失败不阻断整批。
每条失败写结构化日志和 task result summary。
网络错误不把订单标 failed。
支付宝返回确定 closed 才本地 close。
```

## 9. 前端设计

### 9.1 return_url 自动 sync 保留

现有行为保留：URL 带 `recharge_no` 时自动 sync 该单并刷新。

新增要求：

```text
同一页面生命周期内，同一个 recharge_no 只自动 sync 一次。
自动 sync 失败只展示轻量提示，不阻断列表展示。
成功后移除或忽略旧 query，避免刷新循环。
```

### 9.2 reopen 自动 sync 最近支付中订单

`/payment/recharge` 页面 `refreshAll()` 完成后：

```text
1. 从当前列表里取最近的 paying 充值单。
2. 最多自动 sync 3 条。
3. 只 sync 当前页可见数据，不额外扫全库。
4. 同一页面生命周期内同一 id 只 sync 一次。
5. 如果用户没有 payment_recharge_sync 权限，不自动调用；但产品角色默认应授予该权限。
6. sync 成功后刷新钱包和列表。
```

这个设计解决本地/测试环境 callback 不可达的问题，同时避免每次打开页面无限打支付宝查询。

### 9.3 手动同步保留

记录表和最近记录里的“同步”按钮保留。它是客服/用户可见的补救动作，不因为自动 sync 和 cron 存在就删除。

## 10. 状态机

### 10.1 payment_orders

```text
pending -> paying   # 拉起支付宝 pay_url 成功
pending -> closed   # 本地过期关闭
paying  -> paid     # sync/callback/cron 查询到 TRADE_SUCCESS 或 TRADE_FINISHED
paying  -> closed   # close-expired 确认支付宝未支付并关闭
failed  -> paying   # 重新 pay 成功生成 pay_url
paid    -> paid     # 幂等
closed  -> closed   # 幂等
```

禁止：

```text
pending -> paid without gateway proof
closed -> paid unless query proves actual paid and本地关闭是竞态产生；这种情况必须记录 warning 并按资金安全优先处理
paid -> closed
```

### 10.2 payment_recharges

```text
pending -> paying    # 底层订单进入 paying
paying  -> paid      # 底层订单 paid，但钱包尚未入账前的短暂状态
paid    -> credited  # 钱包入账成功
paying  -> closed    # 底层订单 closed
failed  -> paying    # 重新发起支付
credited -> credited # 幂等
```

实际服务应尽量在一次请求内从 `paying` 推进到 `credited`，不要长期停留在 `paid`。

## 11. 安全和审计

```text
支付回调不要求登录，但必须验签。
callback route 不写 OperationLog，避免原始第三方 payload 混入后台操作审计。
callback 必须写 payment_callback_events 和 system log。
私钥、证书内容、APP_SECRET、API Key 绝不进入响应、日志、event raw payload。
金额比较使用 cents，不能用 float。
app_id、out_trade_no、amount 任一不匹配都不能入账。
重复 callback / 重复 cron / 重复手动 sync 必须幂等。
支付宝返回 success/fail 必须是 plain text，不能包统一 JSON。
```

## 12. 测试设计

### 12.1 Backend unit tests

```text
payment callback parse/verify success with fake signed payload
callback invalid signature -> event failed -> response fail -> no order mutation
callback unknown out_trade_no -> event ignored -> response success -> no retry storm
callback app_id mismatch -> failed -> no mutation
callback amount mismatch -> failed -> no mutation
callback TRADE_SUCCESS -> order paid + recharge credited + wallet transaction once
callback duplicate success -> no duplicate wallet credit
manual SyncRecharge after callback success -> idempotent credited response
cron sync pending paid -> credited
cron sync pending waiting -> remains paying
cron close expired pending -> closed
cron close expired paying but query paid -> credited, not closed
cron batch single failure does not stop next order
```

### 12.2 Frontend tests

```text
return_url recharge_no triggers exactly one sync
page reopen auto syncs at most 3 visible paying rows
auto sync skips rows already synced in same page lifecycle
auto sync respects payment_recharge_sync permission
manual sync button remains visible for paying/paid rows with permission
no raw config_code/return_url field appears in recharge UI
```

### 12.3 Smoke / manual verification

默认 full smoke 仍然不做真实支付宝写操作。新增 read-only smoke 只验证：

```text
callback route registered as public/no RBAC/no OperationLog metadata
payment_callback_events schema exists
cron_task registry exposes payment_sync_pending_order/payment_close_expired_order when migration applied
/payment/recharge menu and list shape unchanged
```

credential-gated manual smoke：

```text
1. 配置支付宝沙箱。
2. 创建 recharge_10。
3. 支付后关闭支付宝页，不回 return_url。
4. 等 callback 或 payment_sync_pending_order。
5. 验证 payment_orders=paid、payment_recharges=credited、wallet_transactions 只新增一次。
6. 重放同一 callback 或再次点击 sync，验证余额不重复增加。
```

本地无公网 callback 时的 manual smoke：

```text
1. 创建 recharge_10 并支付。
2. 支付成功后关闭页面。
3. 重新打开 /payment/recharge。
4. 页面自动 sync 最近 paying 充值单。
5. 验证 credited 和钱包余额更新。
```

## 13. 文档同步要求

实现时必须同步：

```text
docs/contracts/admin-api-v1.md
docs/status/current-status.md
docs/testing/smoke-matrix.md
admin_back_go/docs/architecture.md
```

同步口径：

```text
Alipay callback implemented
payment_callback_events audit implemented
payment_sync_pending_order / payment_close_expired_order cron implemented
return_url sync remains UX helper, callback/cron are closure guarantees
默认 smoke 不做真实支付宝写操作
manual smoke 需要沙箱凭据和可访问 notify_url
```

## 14. 验收标准

这个 slice 完成时，必须能证明：

```text
1. 用户支付成功并关闭网页后，生产可通过 callback 或 cron 最终入账。
2. 本地无公网 callback 时，重新打开 /payment/recharge 能自动同步最近支付中订单。
3. callback 验签、app_id、金额、订单号校验缺一不可。
4. 重复 callback、重复 sync、重复 cron 不重复加钱包余额。
5. 支付宝回调返回 plain text success/fail。
6. callback 不依赖后台登录，不写 OperationLog。
7. cron_task 行和 Go registry 真实对应，不存在 noop 假任务。
8. 支付配置密钥、证书、APP_SECRET 不泄漏到日志/响应/测试输出。
9. current-status 只写已验证事实，不把计划写成 implemented。
```

## 15. 明确不解决的问题

```text
用户打开首页/dashboard 而不是 /payment/recharge 时，前端不会主动 sync；生产靠 callback/cron 保证最终一致。
支付宝 notify_url 的公网域名、HTTPS、网关/Nginx 转发属于部署配置，不在本 spec 写教程。
如果支付宝沙箱自身延迟，cron 会重试，不承诺秒级入账。
如果管理员禁用 payment_recharge_sync 权限，前端 reopen sync 不执行；角色种子应保证充值用户具备 sync 权限。
```

## 16. Spec self-review

```text
占位符：未发现未完成标记。
范围：只覆盖支付宝充值完成闭环，不扩散到退款、微信、订阅、对账。
一致性：callback、manual sync、cron 都复用同一支付成功 finalize 边界。
字段：新增 payment_callback_events 字段均有审计、匹配或处理用途。
验证：本文是 design spec，运行时代码尚未实现；runtime 闭环仍需后续 plan + TDD 实现。
```
