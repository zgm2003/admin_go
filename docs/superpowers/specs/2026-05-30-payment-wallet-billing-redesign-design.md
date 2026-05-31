# 支付钱包与 AI 扣费整改设计 Spec

日期：2026-05-30
状态：已实现并进入 2026-05-31 终审；本轮终审已要求删除 legacy `consume` 内部表面，当前事实以 runtime、测试和 `docs/status/current-status.md` 为准。
范围：`E:\admin_go` 当前 Go/Vue admin 系统的支付、钱包、AI 场景计费基础。本轮实现只改 admin 系统，不改 `canvas_front_next`，不接 infinite-canvas 运行时接口。

---

## 0. 一句话结论

把“积分”彻底并入 **钱包余额**。系统不再维护第二套积分事实源。

```text
用户充值 -> payment_recharges/payment_orders 完成支付 -> user_wallets.balance_cents 增加 -> wallet_transactions(direction=in)
AI 生成 -> 创建 billable request -> 钱包预扣 -> wallet_transactions(direction=out) -> 成功保留，失败幂等退款
```

管理菜单收敛成一个一级菜单：

```text
支付管理
  - 支付配置
  - 收支明细
  - 用户钱包
```

不再给用户看“手动同步”。系统应该靠 callback + cron 补偿稳定闭环，而不是让用户替系统擦屁股。

---

## 1. 当前事实

### 1.1 当前 live menu 事实

本地 live MySQL 当前还有 3 个支付/钱包相关一级入口：

```text
钱包中心        /wallet
钱包管理        /wallet-manage
支付管理        /payment
```

当前可见子菜单：

```text
/payment/config        支付配置
/payment/recharge      充值/记录
/payment/orders        支付订单
/wallet/transactions   资金明细
/wallet/users          用户钱包
/wallet/ledger         资金流水
```

这就是坏味道：同一件事被拆成三套入口，“资金明细 / 资金流水 / 支付订单 / 充值记录”语义互相打架。

### 1.2 当前表事实

当前支付钱包闭环已经有这些 active tables：

```text
payment_configs
payment_orders
payment_recharge_packages
payment_recharges
payment_callback_events
user_wallets
wallet_transactions
```

其中真正的钱包事实源只有：

```text
user_wallets
wallet_transactions
```

`payment_orders` 是第三方支付网关订单，不是用户账单；`payment_recharges` 是充值业务单，不是余额流水。

### 1.3 当前钱包能力

当前 wallet 已经具备关键基础：

```text
user_wallets.balance_cents
user_wallets.total_recharge_cents
user_wallets.total_consume_cents
wallet_transactions.direction = in/out
wallet_transactions.source_type/source_id 幂等约束
Debit/Credit 会在 DB transaction 内改余额 + 写流水
```

当前有效 source type 是：

```text
recharge
ai_generate
ai_refund
```

legacy `consume` 不能继续当垃圾桶；没有当前调用方就不保留。

---

## 2. Linus 三问

### 2.1 这是真问题吗？

是。因为 canvas 迁进来以后，生成图/文/视频就需要真钱包扣费。旧 `infinite-canvas` 的积分和 `credit_logs` 不能照搬，否则系统会出现两套余额：

```text
admin_go wallet balance
infinite-canvas credits
```

两套钱就是灾难。

### 2.2 更简单的方法是什么？

余额唯一。流水唯一。充值和消费都进 `wallet_transactions`。

```text
积分 = 钱包余额展示口径
扣积分 = wallet debit
退积分 = wallet credit refund
```

不要新建 `points`、`credits`、`coin_logs`。那些都是重复事实源。

### 2.3 会破坏什么吗？

会，前提是乱改：

- 如果删掉 `payment_orders` 表，支付宝支付闭环会坏。它虽然不该做菜单，但仍是 runtime 表。
- 如果用户侧还有手动同步按钮，产品会继续暴露系统不稳定。
- 如果 AI 扣费直接写 `wallet_transactions` 而没有业务 request source，幂等和退款会乱。
- 如果按 token 事后扣费，视频/图片没有稳定 token，余额可能变成负数或 provider 成本不可控。
- 如果新增“积分表”，钱包就废了。

---

## 3. 目标和非目标

### 3.1 目标

1. 支付/钱包菜单收敛到一个一级菜单 `支付管理`。
2. 用户余额入口放到右上角用户菜单，新增隐藏页 `我的钱包`。
3. `充值` 成为隐藏路由/弹层能力，不再是管理侧可见菜单。
4. `收支明细` 统一展示 `wallet_transactions`，admin 看全部，用户只看自己。
5. admin 后端先建立 AI 生成扣费基础：钱包预扣、失败退款、账单记录。
6. 图/文/视频场景先按固定单位计费，不做 token 计费；实际 canvas 接入放到下一切片。
7. 价格配置放在 AI 场景/智能体配置里，不塞进支付菜单。
8. 只保留会被 runtime 使用的表和字段；无用菜单、权限、页面退役或隐藏，但隐藏入口必须仍有明确调用方。

### 3.2 非目标

1. 不做第二套积分系统。
2. 不迁移 `infinite-canvas.credit_logs` 为新表。
3. 不新增“充值记录”独立菜单。
4. 不新增“支付订单”可见菜单。
5. 不把用户手动同步作为产品功能。
6. 不做提现、退款到支付宝、对账、微信支付、订阅权益。
7. 不在第一版做 token 后付费。

---

## 4. 菜单整改设计

### 4.1 最终菜单

最终只保留一个可见一级菜单：

```text
支付管理
  /payment/config   支付配置
  /payment/ledger   收支明细
  /payment/wallets  用户钱包
```

命名建议：

| 页面 | 推荐中文 | 推荐英文 | 说明 |
|---|---|---|---|
| `/payment/config` | 支付配置 | Payment Config | 支付宝配置、证书、启停、测试 |
| `/payment/ledger` | 收支明细 | Billing Ledger | 全部用户钱包流水，收入/支出统一看 |
| `/payment/wallets` | 用户钱包 | User Wallets | 用户余额聚合，不展示流水细节 |

`收支明细` 比“资金流水 / 账单 / 订单管理”更准确：它不是支付订单，不只是收入，也不是充值记录。

### 4.2 隐藏入口

```text
/payment/recharge   充值，隐藏，不在左侧菜单显示
/profile/wallet     我的钱包，隐藏，从右上角用户菜单进入
```

`我的钱包` 页面建议放在用户下拉菜单里，和截图里的 `个人资料` 同级：

```text
个人资料
我的钱包
退出登录
```

`我的钱包` 页面使用 `el-tabs`：

```text
Tab 1: 钱包
  - 当前余额
  - 累计充值
  - 累计消费
  - 充值按钮

Tab 2: 收支明细
  - 只看当前用户自己的 wallet_transactions
  - direction: 收入 / 支出
  - source_type: 充值 / AI生成 / 退款 / 手动调整（如果未来支持）
```

### 4.3 需要退役的可见入口

```text
/wallet                    钱包中心一级菜单 -> 退役
/wallet-manage             钱包管理一级菜单 -> 退役
/wallet/transactions       资金明细 -> 合并到 /profile/wallet 的个人收支明细
/wallet/ledger             资金流水 -> 迁到 /payment/ledger
/wallet/users              用户钱包 -> 迁到 /payment/wallets
/payment/orders            支付订单 -> 隐藏或退役为内部排障能力
/payment/recharge          充值/记录 -> 隐藏，不在左侧菜单显示
```

这不是“删能力”，是删重复入口。

---

## 5. 支付、钱包、账单的领域边界

### 5.1 支付配置

`payment_configs` 只负责第三方收款配置。

保留原因：

```text
支付宝 app_id
私钥密文
证书路径
notify_url
environment
enabled_methods_json
sort
status
```

不允许放：

```text
充值套餐
用户余额
AI价格
return_url
```

### 5.2 支付订单

`payment_orders` 是网关订单 runtime 表。它继续存在的唯一理由是当前支付宝收款 runtime 真实使用它；如果后续支付链路不再引用它，就必须删除或迁移，不能为了“以后可能用”保留。

当前使用点：

```text
out_trade_no/order_no
绑定 payment_config
支付宝 pay_url
支付宝 trade_no
支付状态
过期关闭
callback/sync/cron finalizer
```

管理侧如果要看它，应该从 `收支明细` 或充值详情里钻取，不单独占一个左侧菜单。

### 5.3 充值

`payment_recharges` 是充值业务单。它解释“用户为什么收入这笔余额”。

用户不需要一个独立“充值记录”菜单，因为充值成功后最终要看的就是余额流水：

```text
wallet_transactions(direction=in, source_type=recharge)
```

充值中/失败/关闭记录可以在 `我的钱包 -> 钱包` 的“最近充值”小块展示，但不作为主账单事实源。

### 5.4 钱包

`user_wallets` 只回答一个问题：

```text
这个用户现在余额是多少？
```

`wallet_transactions` 只回答一个问题：

```text
余额为什么变化？
```

这两张表是钱的事实源。其它支付表只是解释来源。

---

## 6. AI 生成扣费设计

### 6.1 计费口径

第一版采用 **按固定单位预扣费**，不按 token 后付费。

原因很简单：

- 图片和视频没有稳定 token。
- 视频通常是异步任务，等完成后再扣费会导致 provider 成本先发生。
- 用户生成前必须知道大概扣多少钱。
- 余额不足应该在调用上游前失败，不能先烧 provider 再发现没钱。

### 6.2 计费单位

本轮 admin 系统先接入一个当前 runtime 场景：

| scene | unit | unit_count | 说明 |
|---|---|---:|---|
| `admin_image_generate` | `image` | `n` | 现有 admin 图片工作台每张图扣固定金额 |

未来 canvas 接入时再新增三种配置，不默认落库：

| scene | unit | unit_count | 说明 |
|---|---|---:|---|
| `canvas_text_generate` | `request` | 1 | 每次文本生成扣固定金额 |
| `canvas_image_generate` | `image` | `n` | 每张图扣固定金额 |
| `canvas_video_generate` | `second` | `duration_seconds` | 视频按秒扣，更贴近上游成本 |

如果产品想极简，也可以把视频改成 `request`。但既然视频参数里已经有秒数，按秒更不容易亏。

### 6.3 价格配置在哪里

不要放支付管理。支付管理管钱流，不管 AI 产品定价。

推荐放在：

```text
AI 管理 -> 智能体配置 -> 场景计费
```

也可以做成智能体配置页的一个小区块：

```text
场景：无限画布-视频
计费单位：秒
单价：0.20 元/秒
状态：启用
```

这比新增一个“价格管理”一级/二级菜单干净。价格属于 AI 场景策略，不属于支付宝配置。

### 6.4 新表：`ai_billing_rules`

价格规则表只放会使用的字段：

```text
id                  bigint pk
scene               varchar(64) unique
unit                varchar(16)   request / image / second
unit_price_cents    bigint
status              tinyint       1 enabled / 2 disabled
is_del              tinyint       1 deleted / 2 active
created_at          datetime
updated_at          datetime
```

索引：

```text
uk_ai_billing_rules_scene(scene)
idx_ai_billing_rules_status(status, is_del, scene)
```

不加 `config_json`、`currency`、`tenant_id`、`provider_id`、`model_id`。当前系统只按人民币分计余额，canvas 第一版每个 scene 恰好一个 agent，没必要加废字段。

如果未来同一 scene 允许多个 agent/model 给用户选择，再升级到：

```text
scene + agent_id
```

不是现在预埋垃圾字段。

### 6.5 新表：`ai_billing_records`

AI 每次实际扣费必须有一个业务 source，否则 wallet 幂等无锚点。

```text
id                          bigint pk
request_no                  varchar(64) unique
user_id                     bigint
platform                    varchar(32)   canvas / admin / app
scene                       varchar(64)
agent_id                    bigint
provider_id                 bigint
model_id                    varchar(191)
unit                        varchar(16)
unit_count                  int
unit_price_cents            bigint
amount_cents                bigint
status                      varchar(16)   pending / charged / success / failed / refunded
debit_transaction_id        bigint null
refund_transaction_id       bigint null
provider_task_id            varchar(128)
error_message               varchar(512)
created_at                  datetime
updated_at                  datetime
finished_at                 datetime null
```

这张表 **不加 `is_del`**。

原因：

```text
ai_billing_records 是账务事实和 wallet_transactions 的 source 证明。
账务事实不允许软删除，也不提供删除 API。
生命周期只能通过 status 表达，不能靠 is_del 隐藏。
```

索引：

```text
uk_ai_billing_records_request_no(request_no)
idx_ai_billing_records_user_created(user_id, created_at, id)
idx_ai_billing_records_scene_created(scene, created_at, id)
idx_ai_billing_records_status_created(status, created_at, id)
idx_ai_billing_records_provider_task(provider_id, provider_task_id)
```

字段解释：

- `amount_cents` 是扣费快照，价格改了不影响历史。
- `debit_transaction_id` 关联支出流水。
- `refund_transaction_id` 关联失败退款流水。
- `provider_task_id` 给视频异步轮询使用；同步图文可以为空。
- 不保存 prompt、图片 bytes、API key、provider raw response。那些不是账务字段。

### 6.6 wallet source type

扩展 source type：

```text
recharge       充值入账
ai_generate    AI 生成支出
ai_refund      AI 生成失败退款
adjust         后台人工调整，第一版不实现，只保留为后续显式 spec
```

支出：

```text
wallet_transactions.direction = out
wallet_transactions.source_type = ai_generate
wallet_transactions.source_id = ai_billing_records.id
```

退款：

```text
wallet_transactions.direction = in
wallet_transactions.source_type = ai_refund
wallet_transactions.source_id = ai_billing_records.id
```

`uk_wallet_transaction_source(source_type, source_id)` 继续保证幂等。

### 6.7 扣费流程

```text
1. canvas_front_next 发起生成请求
2. admin_back_go 识别 scene 和 agent
3. 查询 ai_billing_rules
4. 计算 amount_cents = unit_price_cents * unit_count
5. 创建 ai_billing_records(status=pending)
6. wallet 预扣：direction=out/source_type=ai_generate/source_id=billing_record.id
7. 预扣成功后调用 provider
8. provider 创建失败：写失败状态 + 钱包退款
9. provider 成功：写 success 或 charged，返回结果/任务ID
10. 视频异步任务后续失败：按 billing_record 幂等退款
```

余额不足：

```text
不创建 provider 请求
不写支出流水
返回明确错误：余额不足，请先充值
```

### 6.8 为什么不按 token

token 计费适合纯文本聊天，但不适合当前 canvas 第一版：

| 模式 | 问题 |
|---|---|
| 事后按 token 扣 | 可能 provider 已扣成本，但用户余额不足 |
| 预估 token 预扣 | 估算不准，需要冻结/补扣/退款，复杂度立刻翻倍 |
| 图片/视频 token | 没有统一 token 口径 |

所以第一版：

```text
canvas 按固定单位计费
AI chat token 计费以后单独 spec
```

---

## 7. 钱包服务整改

### 7.1 legacy `Consume` 的结论

`wallet.Consume` 已退役。它曾经复用了事务和幂等，但语义是错的：

```text
旧实现把 source_type 固定成 legacy consume
只支持支出
没有退款/通用入账能力
没有当前产品调用方
```

AI 扣费必须走明确业务 source：`ai_generate` / `ai_refund`。保留 `consume` wrapper 只会让下一个开发者误以为还有通用消费入口。

### 7.2 新服务接口

内部 service 建议收敛成：

```text
Debit(user_id, amount_cents, source_type, source_id, remark)
Credit(user_id, amount_cents, source_type, source_id, remark)
```

约束：

```text
amount_cents 永远正数
方向由 Debit/Credit 决定
source_type + source_id 全局幂等
余额扣减和流水写入必须同一个 DB transaction
余额不足不写流水
```

不保留 `Consume` wrapper，也不保留 HTTP 测试消费入口。当前没有调用方，保留就是架构噪音。

### 7.3 用户余额展示

余额继续用分存储，前端展示元：

```text
balance_cents -> balance_text
amount_cents  -> amount_text
```

不要新增 `points` 字段。产品要叫“积分”也只是展示文案，不是数据库事实。

---

## 8. API 设计

### 8.1 Admin 支付管理

最终可见页面 API：

```text
GET    /api/admin/v1/payment/configs/page-init
GET    /api/admin/v1/payment/configs
POST   /api/admin/v1/payment/configs
PUT    /api/admin/v1/payment/configs/:id
PATCH  /api/admin/v1/payment/configs/:id/status
DELETE /api/admin/v1/payment/configs/:id
POST   /api/admin/v1/payment/configs/:id/test
POST   /api/admin/v1/payment/certificates

GET    /api/admin/v1/payment/ledger/page-init
GET    /api/admin/v1/payment/ledger

GET    /api/admin/v1/payment/wallets/page-init
GET    /api/admin/v1/payment/wallets
```

`payment/ledger` 和 `payment/wallets` 可以复用现有 wallet service，但 URL 和菜单语义要归到支付管理下。

### 8.2 Current-user wallet

隐藏页从用户菜单进入：

```text
GET /api/admin/v1/wallet/summary
GET /api/admin/v1/wallet/transactions
```

充值入口：

```text
GET    /api/admin/v1/payment/recharges/page-init
POST   /api/admin/v1/payment/recharges
POST   /api/admin/v1/payment/recharges/:id/pay
```

用户侧不展示：

```text
POST /payment/recharges/:id/sync
PATCH /payment/recharges/:id/close
```

这些可以保留为 admin/debug hidden capability，但不要在普通产品页暴露。

### 8.3 未来 Canvas AI 扣费

未来 canvas 生成 API 不直接暴露钱包接口。它内部调用 wallet。本轮 admin 整改不实现这些 `/api/canvas/*` 路由，只把 admin 侧价格规则、钱包借贷能力、账单视图先落好：

```text
POST /api/canvas/v1/ai/images/generations
POST /api/canvas/v1/ai/chat/completions
POST /api/canvas/v1/ai/videos
GET  /api/canvas/v1/ai/videos/:id
GET  /api/canvas/v1/ai/videos/:id/content
```

错误：

```text
余额不足 -> 400/402，前端引导充值
场景未配置价格 -> 400，提示管理员配置计费规则
provider 创建失败 -> 502 + 自动退款
视频最终失败 -> 返回失败状态 + 自动退款
重复请求 -> 按 request_no/source_id 幂等返回已有结果或状态
```

---

## 9. 权限设计

### 9.1 可见菜单权限

```text
payment_config_list
payment_ledger_list
payment_wallet_list
```

对应按钮：

```text
payment_config_add
payment_config_edit
payment_config_status
payment_config_del
payment_config_upload_cert
payment_config_test
```

收支明细和用户钱包第一版只读，不要造一堆没用按钮。

### 9.2 隐藏能力权限

```text
payment_recharge_add      当前用户创建充值
payment_recharge_pay      当前用户继续支付
wallet_current_read       当前用户读自己的钱包和流水，可由登录态默认授予
canvas_ai_generate        canvas 平台发起 AI 生成
```

不建议继续默认暴露：

```text
payment_order_add
payment_order_sync
payment_recharge_sync
```

这些要么是内部服务调用，要么是运维排障，不是普通菜单按钮。

---

## 10. 表保留、退役和新增

### 10.1 保留表

| 表 | 是否保留 | 当前使用点 |
|---|---|---|
| `payment_configs` | 保留 | 支付宝配置事实源 |
| `payment_orders` | 保留，不做可见菜单 | 支付网关 runtime，callback/sync/cron 当前引用 |
| `payment_recharge_packages` | 保留 | 充值金额套餐事实源 |
| `payment_recharges` | 保留 | 充值业务单，解释充值入账来源 |
| `payment_callback_events` | 保留 | callback 审计和排障 |
| `user_wallets` | 保留 | 用户余额事实源 |
| `wallet_transactions` | 保留 | 收支明细事实源 |

硬边界：

```text
没有当前 runtime 使用点的表、字段、菜单、权限，不允许保留。
保留必须能指出调用路径、查询路径或审计用途。
“以后可能用”不是保留理由。
```

### 10.2 新增表

```text
ai_billing_rules
ai_billing_records
```

### 10.3 不新增表

```text
points
credits
credit_logs
canvas_credit_logs
payment_bill
payment_ledger
wallet_ledger
```

`wallet_transactions` 已经是账单/收支明细。再造一张 ledger 表就是重复事实源。

### 10.4 字段原则

所有金额字段只用：

```text
*_cents bigint
```

不用：

```text
decimal amount_yuan
float cost
points
credits
```

所有流水金额正数，方向单独表达：

```text
direction = in/out
amount_cents > 0
```

---

## 11. 查询性能和索引

### 11.1 钱包流水主查询

Admin 收支明细：

```text
WHERE is_del = 2
  AND optional user_id
  AND optional direction
  AND optional source_type
  AND optional created_at range
ORDER BY id DESC
LIMIT/OFFSET
```

建议补强索引：

```text
idx_wallet_tx_admin_created(is_del, created_at, id)
idx_wallet_tx_admin_direction_created(direction, is_del, created_at, id)
idx_wallet_tx_admin_source_created(source_type, is_del, created_at, id)
```

现有 `idx_wallet_transaction_user_created(user_id, is_del, created_at)` 可以服务用户自己的明细。

### 11.2 用户钱包主查询

Admin 用户钱包：

```text
WHERE w.is_del = 2
  AND optional w.user_id
  AND optional user keyword
ORDER BY w.updated_at DESC, w.id DESC
```

建议：

```text
idx_user_wallet_updated(is_del, updated_at, id)
```

关键词搜用户账号走 `users` 自己的 username/phone/email 索引，不要在 wallet 表复制账号字段。

### 11.3 AI billing 主查询

用户查自己的 AI 扣费记录：

```text
idx_ai_billing_records_user_created(user_id, created_at, id)
```

系统处理视频任务状态：

```text
idx_ai_billing_records_provider_task(provider_id, provider_task_id)
```

后台按状态排障：

```text
idx_ai_billing_records_status_created(status, created_at, id)
```

---

## 12. 页面整改

### 12.1 支付配置

保留当前页面，放在：

```text
支付管理 -> 支付配置
```

只做支付宝配置。支付渠道多供应商不是当前目标。

### 12.2 收支明细

新页面或迁移现有 `/wallet/ledger`：

```text
支付管理 -> 收支明细
```

字段：

```text
流水号
用户
方向：收入/支出
类型：充值/AI生成/AI退款
金额
变更前余额
变更后余额
备注
创建时间
```

不要显示 `payment_order_id` 这种技术字段为主列。需要时放详情抽屉。

### 12.3 用户钱包

新页面或迁移现有 `/wallet/users`：

```text
支付管理 -> 用户钱包
```

字段：

```text
用户ID
用户账号
余额
累计充值
累计消费
更新时间
```

第一版只读。不要加“后台手动改余额”，那是高风险功能，除非单独做人工调整 spec。

### 12.4 我的钱包

隐藏页，从右上角用户菜单进入：

```text
/profile/wallet
```

Tab：

```text
钱包
收支明细
```

钱包 tab 提供充值按钮；收支明细 tab 只读自己流水。

### 12.5 充值页

`/payment/recharge` 仍可作为隐藏 route 或充值弹层实现。它不再叫“充值/记录”，不再出现在左侧菜单。

用户充值后不用手动同步：

```text
callback 成功 -> 自动入账
cron 补偿 -> 自动同步支付中订单
return-url 回跳 -> 可以触发轻量状态刷新，但不要求用户点同步
```

---

## 13. 方案比较

### 方案 A：照搬 infinite-canvas 积分

结论：拒绝。

问题：

- 两套余额事实源。
- `credit_logs` 和 `wallet_transactions` 重复。
- 钱包充值无法统一给 canvas 消费。

### 方案 B：按 token 后付费

结论：第一版拒绝。

问题：

- 视频/图片没有统一 token。
- 余额不足只能事后发现。
- 需要冻结金额、补扣、退款、差额处理，复杂度翻倍。

### 方案 C：钱包余额 + 固定单位预扣 + 失败退款

结论：推荐。

优点：

- 钱包是唯一余额事实源。
- 用户生成前知道价格。
- provider 调用前先校验余额。
- 失败退款可幂等。
- 菜单和账单统一。

---

## 14. 分阶段路线

### Phase 0：事实锁定

- 查询 live `permissions`，确认当前支付/钱包菜单。
- 查询 live 支付钱包表和索引。
- 确认当前 wallet Debit/Credit 幂等和余额事务。

### Phase 1：菜单收敛

- 新增/迁移 `/payment/ledger`、`/payment/wallets`。
- 隐藏 `/wallet`、`/wallet-manage`、`/payment/orders`、`/payment/recharge` 左侧入口。
- 用户下拉菜单增加 `我的钱包`。

### Phase 2：钱包服务能力补齐

- 删除 legacy `Consume` 表面，保留明确的 `Debit` / `Credit`。
- 新增 `Credit/Refund` 内部能力。
- source type 增加 `ai_generate`、`ai_refund`。
- 保持旧 current-user wallet API 可用，避免破坏已有充值页。

### Phase 3：AI 场景计费配置

- 新增 `ai_billing_rules`。
- AI 智能体配置页增加“场景计费”区块。
- 先配置并使用 `admin_image_generate`；canvas 三个 scene 只作为可创建选项，不默认插入未使用数据。

### Phase 4：Admin 扣费基础闭环

- 新增 `ai_billing_records`。
- admin 后端提供内部 billable request 预扣/退款服务，并接入现有 `POST /api/admin/v1/ai-images` 作为第一条当前 runtime 使用路径。
- provider 创建失败或业务失败时按 billing record 幂等退款。
- 不改 `canvas_front_next`；canvas 图/文/视频生成接入预扣是下一切片。

### Phase 5：文档和 smoke 收口

- 同步 contracts/status/smoke matrix。
- full smoke 检查菜单只剩 `支付管理` 一个一级入口。
- wallet ledger smoke 检查收入/支出筛选。
- AI billing smoke 用 fake provider 验证扣费/退款幂等。

---

## 15. 验收标准

### 15.1 菜单验收

```text
左侧只出现一个一级菜单：支付管理
支付管理下只出现：支付配置、收支明细、用户钱包
左侧不出现：钱包中心、钱包管理、充值/记录、支付订单、资金明细、资金流水
右上角用户菜单出现：我的钱包
```

### 15.2 钱包验收

```text
充值成功写 wallet_transactions(direction=in, source_type=recharge)
AI生成成功写 wallet_transactions(direction=out, source_type=ai_generate)
AI生成失败写 wallet_transactions(direction=in, source_type=ai_refund)
重复回调/重复退款不重复变更余额
余额不足不调用 provider
```

### 15.3 价格验收

```text
canvas_text_generate 有启用价格规则
canvas_image_generate 有启用价格规则
canvas_video_generate 有启用价格规则
价格单位和单价保存在 ai_billing_rules
生成历史扣费金额使用 ai_billing_records 快照，不受后续改价影响
```

### 15.4 产品验收

```text
用户能在“我的钱包”看到余额和自己的收支明细
用户能从“我的钱包”发起充值
用户不需要手动同步充值状态
用户余额不足时 canvas 生成给出可读提示并引导充值
```

---

## 16. Spec 自检

- **占位符检查**：没有占位符、空章节或空泛延后式要求。
- **范围检查**：本 spec 只覆盖 admin 系统里的支付钱包菜单、余额事实源、AI 场景计费配置和必要扣费基础，不改 `canvas_front_next`，不做提现/退款到支付宝/对账/微信。
- **边界检查**：没有新增积分表；没有把 `payment_orders` 当用户账单；没有把价格配置塞进支付配置。
- **字段检查**：新增表只含当前扣费闭环会用到的字段；不加 `config_json`、`currency`、`tenant_id`、`points`。
- **兼容检查**：保留现有支付 runtime 表；菜单隐藏不等于删除 callback/cron/finalizer。
- **性能检查**：收支明细、用户钱包、AI billing 都有对应查询索引。
