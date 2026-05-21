# Wallet Recharge and Consume V1 Design

日期：2026-05-21
状态：draft for review，不提交 commit
范围：站在用户和产品经理视角，确定“支付、充值、钱包、消费”的未来菜单、表职责和第一版落地边界。第一版只做支付宝充值和钱包消费扣款，不做退款、提现、对账、冻结、赠送、会员权益或多业务履约。

## 1. 产品结论

本项目后续资金体系只保留两个用户能理解的动作：

```text
充值：外部支付宝付款 -> 钱包余额增加
消费：钱包余额扣减 -> 形成支出流水
```

因此产品语言要固定：

```text
支付订单 = 第三方支付/支付宝收款订单，给管理、财务、技术排障看
充值记录 = 用户充值业务记录，给用户看“我充了没有、到账没有”
钱包流水 = 钱包余额变化事实，充值入账和消费扣款都在这里
```

不要把“用户支出”塞进 `payment_orders`。`payment_orders` 只回答“支付宝这笔收款是什么状态”；用户支出要看钱包流水。

## 2. Linus 三问

### 2.1 这是真问题吗？

是。当前 `/payment/recharge`、`/payment/orders` 同时存在，但如果菜单和页面文案不切开，用户会误以为“充值记录”和“支付订单”重复。未来再加入消费后，如果没有钱包流水入口，用户和管理都会问“支出去哪看”。

### 2.2 更简单的做法是什么？

不新造复杂支付中心，不做退款/提现/冻结/对账。保留现有支付收款链路，只补齐钱包视角：

```text
支付管理：只管支付宝配置和支付宝订单
钱包中心：给当前用户充值、看充值记录、看资金明细
钱包管理：给管理看用户余额和全站资金流水
```

消费第一版直接原子扣钱包余额并写 `wallet_transactions`，不单独建 `wallet_consumptions`。如果未来消费需要 pending/failed/cancel 状态，再新增消费业务单表。

### 2.3 会破坏什么吗？

不能破坏：

```text
支付宝配置、证书、回调、支付订单状态机
现有 payment_recharges / payment_orders / user_wallets / wallet_transactions 数据
已支付/已入账的幂等入账规则
登录、RBAC、动态菜单、OperationLog、smoke
```

需要调整的是信息架构和钱包字段，不是推翻支付链路。

## 3. 当前事实源

当前 live DB 已有表：

```text
payment_configs
payment_orders
payment_recharge_packages
payment_recharges
payment_callback_events
user_wallets
wallet_transactions
```

当前字段事实：

```text
user_wallets: id, user_id, balance_cents, total_recharge_cents, is_del, created_at, updated_at
wallet_transactions: transaction_no, wallet_id, user_id, direction, amount_cents, balance_before_cents, balance_after_cents, source_type, source_id, remark
payment_recharges: recharge_no, user_id, package_code, package_name, amount_cents, payment_order_id, status, paid_at, credited_at
payment_orders: order_no, config_id/config_code, provider, pay_method, subject, amount_cents, status, pay_url, return_url, alipay_trade_no, expired_at, paid_at, closed_at
```

已缺口：

```text
user_wallets 缺 total_consume_cents，管理端无法快速看累计消费
wallet_transactions 已能表达 in/out，但还没有产品化菜单和查询 API
消费扣款能力未落地
```

## 4. 菜单设计

### 4.1 用户侧 / 当前登录用户

菜单建议：

```text
钱包中心
- 充值        /wallet/recharge      component=wallet/recharge
- 资金明细    /wallet/transactions  component=wallet/transactions
```

说明：

```text
充值页包含套餐、发起支付宝支付、充值记录 tab。
资金明细页展示当前用户全部余额变化：充值入账、消费扣款。
```

过渡策略：

```text
当前已有 /payment/recharge，第一版可以复用页面能力。
最终菜单应从“支付管理/充值记录”移动到“钱包中心/充值”。
旧 /payment/recharge 可以保留隐藏 redirect 或兼容路由，避免刷新旧链接 404。
```

### 4.2 管理侧

菜单建议：

```text
支付管理
- 支付配置    /payment/config
- 支付订单    /payment/orders

钱包管理
- 用户钱包    /wallet/users
- 资金流水    /wallet/ledger
```

说明：

```text
支付配置：支付宝 app_id、证书、启用状态、优先级。
支付订单：支付宝/网关收款单，处理 pay/sync/close 和技术排障。
用户钱包：用户余额、累计充值、累计消费、最近流水入口。
资金流水：全站钱包 in/out 流水，可筛用户、方向、来源、时间。
```

不新增管理端“消费记录”菜单。管理看支出时进入“资金流水”，筛 `direction=out`。

## 5. 表设计

### 5.1 保留的表职责

```text
payment_configs              支付宝配置事实源
payment_orders               第三方支付订单事实源，只表示外部收款订单
payment_recharge_packages    充值套餐事实源
payment_recharges            充值业务单事实源
payment_callback_events      支付宝回调审计，不作为业务真相源
user_wallets                 用户钱包余额事实源
wallet_transactions          钱包资金流水事实源，充值和消费都在这里
```

### 5.2 需要补的字段

```sql
ALTER TABLE user_wallets
  ADD COLUMN total_consume_cents BIGINT NOT NULL DEFAULT 0 COMMENT '累计消费金额，单位分' AFTER total_recharge_cents;
```

用途：

```text
balance_cents：当前可用余额
total_recharge_cents：历史累计充值入账
total_consume_cents：历史累计消费扣款
```

不加 `total_refund_cents`、`frozen_cents`、`version`、`currency`。这些不是当前产品范围。

### 5.3 wallet_transactions 规则

第一版固定枚举：

```text
direction:
  in   充值入账
  out  消费扣款

source_type:
  recharge  充值入账，source_id = payment_recharges.id
  consume   钱包消费，source_id = 外部业务ID或内部生成的消费来源ID
```

约束：

```text
amount_cents 永远为正数，方向由 direction 表示。
balance_before_cents / balance_after_cents 必须在同一 DB transaction 内写入。
同一 source_type + source_id 只能写一次，保证充值/消费幂等。
余额不足时消费失败，不写流水。
已写流水不允许修改金额；错误只能通过后续新业务规则处理，本 v1 不做退款/冲正。
```

### 5.4 为什么不建 wallet_consumptions

第一版消费是即时余额扣减，不存在“待支付、支付中、已关闭”这种状态机。`wallet_transactions` 已经能回答：

```text
谁消费了
消费多少钱
消费前余额多少
消费后余额多少
什么时候消费
来源是什么
```

所以不建 `wallet_consumptions`。未来如果消费变成订单型业务，例如需要待确认、失败重试、取消、履约状态，再单独加消费业务单表，并继续把最终资金变化落到 `wallet_transactions`。

## 6. 状态和资金流

### 6.1 充值流

```text
用户选套餐
-> 创建 payment_recharges + payment_orders
-> 拉起支付宝 pay_url
-> 支付宝 callback / 手动 sync / cron sync 确认 paid
-> shared finalizer 写 payment_orders=paid、payment_recharges=credited
-> user_wallets.balance_cents += amount
-> user_wallets.total_recharge_cents += amount
-> wallet_transactions(direction=in, source_type=recharge, source_id=recharge_id)
```

关闭规则：

```text
pending / failed / paying：允许用户取消支付，最终状态 closed
paid / credited：不允许取消，不做退款
```

### 6.2 消费流

```text
业务请求消费 amount_cents
-> 校验 amount > 0
-> 查询并锁定 user_wallets
-> balance_cents >= amount 才允许继续
-> user_wallets.balance_cents -= amount
-> user_wallets.total_consume_cents += amount
-> wallet_transactions(direction=out, source_type=consume, source_id=source_id)
-> 返回消费成功和新余额
```

失败规则：

```text
余额不足：返回业务错误，不写 wallet_transactions
重复 source_type + source_id：返回已有流水，不能重复扣款
用户钱包不存在：创建零余额钱包后仍按余额不足处理，除非是充值入账
```

## 7. API 设计

命名空间继续使用：

```text
/api/admin/v1
```

### 7.1 当前用户钱包中心

```text
GET  /api/admin/v1/wallet/summary
GET  /api/admin/v1/wallet/transactions
POST /api/admin/v1/wallet/consumptions
```

`GET /wallet/summary` 返回：

```ts
interface WalletSummaryResponse {
  balance_cents: number
  balance_text: string
  total_recharge_cents: number
  total_recharge_text: string
  total_consume_cents: number
  total_consume_text: string
}
```

`GET /wallet/transactions` 查询当前登录用户流水：

```ts
interface WalletTransactionListQuery {
  current_page: number
  page_size: number
  direction?: 'in' | 'out' | ''
  source_type?: 'recharge' | 'consume' | ''
  date_start?: string
  date_end?: string
}
```

`POST /wallet/consumptions` 是第一版“落地玩玩”的消费扣款入口：

```ts
interface WalletConsumeRequest {
  amount_cents: number
  source_id: number
  remark?: string
}
```

说明：

```text
source_type 固定为 consume，不让前端传。
source_id 第一版可由调用方传入测试业务 ID；后续接真实业务时由真实业务表 ID 提供。
```

### 7.2 管理端钱包管理

```text
GET /api/admin/v1/wallet/users/page-init
GET /api/admin/v1/wallet/users
GET /api/admin/v1/wallet/ledger/page-init
GET /api/admin/v1/wallet/ledger
```

`/wallet/users` 展示用户余额汇总：

```ts
interface AdminWalletUserItem {
  user_id: number
  nickname: string
  account: string
  balance_cents: number
  balance_text: string
  total_recharge_cents: number
  total_recharge_text: string
  total_consume_cents: number
  total_consume_text: string
  updated_at: string
}
```

`/wallet/ledger` 展示全站资金流水：

```ts
interface AdminWalletLedgerQuery {
  current_page: number
  page_size: number
  user_id?: number
  keyword?: string
  direction?: 'in' | 'out' | ''
  source_type?: 'recharge' | 'consume' | ''
  date_start?: string
  date_end?: string
}
```

### 7.3 已有支付接口继续保留

```text
/payment/configs*      支付配置
/payment/orders*       第三方支付订单
/payment/recharges*    充值业务单，后续可被 /wallet/recharge 页面复用
```

不要把消费接口放到 `/payment/orders`，消费不是支付宝支付订单。

## 8. 权限码设计

用户侧钱包中心：

```text
PAGE   wallet_recharge_list          /wallet/recharge
BUTTON wallet_recharge_pay
BUTTON wallet_recharge_sync
BUTTON wallet_recharge_close

PAGE   wallet_transaction_list       /wallet/transactions
```

管理侧钱包管理：

```text
DIR    wallet_manage                 钱包管理
PAGE   wallet_user_list              /wallet/users
PAGE   wallet_ledger_list            /wallet/ledger
```

支付管理保留：

```text
PAGE   payment_config_list           /payment/config
PAGE   payment_order_list            /payment/orders
```

过渡规则：

```text
旧 payment_recharge_* 可以先继续保留给 /payment/recharge。
正式迁到 /wallet/recharge 时，新增 wallet_recharge_*，再把旧菜单隐藏或做 redirect。
不要让同一个用户同时看到 /payment/recharge 和 /wallet/recharge 两个入口。
```

## 9. 后端设计

建议新增钱包模块：

```text
internal/module/wallet
  route.go
  handler.go
  service.go
  repository.go
  model.go
  request.go
  dto.go
```

Go 边界：

```text
payment module：负责支付宝配置、订单、回调和充值状态机
wallet module：负责余额、流水、充值入账、消费扣款
```

钱包 service 需要提供小接口，给 payment finalizer 调用：

```go
type WalletService interface {
    CreditRecharge(ctx context.Context, input CreditRechargeInput) (*WalletTransaction, error)
    Consume(ctx context.Context, input ConsumeInput) (*WalletTransaction, error)
}
```

实现要求：

```text
context.Context 必须作为第一参数传递。
所有余额变更必须在 DB transaction 内完成。
消费扣款要 SELECT ... FOR UPDATE 锁钱包行，避免并发超扣。
错误要 wrap 上下文，service 返回 apperror 给 HTTP 层。
不要在 module/payment 里直接散落钱包 SQL。
不要开无主 goroutine；消费和入账都是同步事务。
```

## 10. 前端设计

第一版页面：

```text
src/api/wallet/index.ts
src/views/Main/wallet/recharge/index.vue
src/views/Main/wallet/transactions/index.vue
src/views/Main/wallet/users/index.vue
src/views/Main/wallet/ledger/index.vue
```

复用现有充值页能力：

```text
/wallet/recharge 可以先复用 payment/recharge 的组件逻辑，再改文案和菜单归属。
充值记录继续只看当前登录用户。
```

页面规则：

```text
表格页默认用 Search + AppTable + useTable。
不要手写 el-table / el-dialog。
可见文案进 i18n。
金额统一展示 cents -> yuan text，不让前端自己算业务真相。
```

## 11. 测试和 smoke

后端测试：

```text
wallet service：充值入账幂等、消费扣款成功、余额不足失败、重复 source 不重复扣款、并发扣款不超扣
wallet handler：summary/list/consume 参数校验
payment finalizer：改为调用 wallet service 后仍保证充值只入账一次
router/bootstrap：菜单和权限码注册
```

前端测试：

```text
wallet api path 测试
wallet transaction page 筛选参数测试
wallet ledger page 权限按钮/菜单测试
充值页迁移后不再出现在支付管理下
```

smoke：

```text
默认 read-only：summary、transactions、wallet users、ledger。
消费写 smoke 只在显式开关下跑，创建小额测试消费并校验余额/流水；默认不扣真实余额。
支付 smoke 继续只读配置、充值、支付订单，不默认触发真实支付宝。
```

## 12. 分阶段落地建议

### Phase 1：文案和菜单收口

```text
支付管理只保留 支付配置 / 支付订单。
充值入口迁到 钱包中心 / 充值。
新增 钱包中心 / 资金明细 只读页面。
```

### Phase 2：钱包累计消费字段和流水 API

```text
迁移 user_wallets.total_consume_cents。
新增 wallet module 的 summary/list/admin list/ledger read API。
前端接资金明细和管理端资金流水。
```

### Phase 3：消费扣款 v1

```text
新增 Consume service。
加幂等 source_type=consume + source_id。
前端加一个受控测试入口或后端仅提供 API，先用于“落地玩玩”。
```

### Phase 4：支付 finalizer 调整边界

```text
把充值入账从 payment service 内部 SQL 收敛到 wallet service。
保持 payment callback/manual sync/cron compensation 共用同一个入账路径。
```

## 13. Exit Criteria

```text
用户知道：充值看“钱包中心/充值”，支出看“钱包中心/资金明细”。
管理知道：支付宝问题看“支付订单”，用户余额和支出看“钱包管理/资金流水”。
DB 中充值和消费都落 wallet_transactions，余额变更可追溯。
没有退款、提现、冻结、调账、对账、微信支付等多余概念混入。
```
