# Payment Recharge Cashier V1 Design

日期：2026-05-15  
状态：draft for review  
范围：在 `payment_configs` + `payment_orders` 已落地的前提下，把“手工新增支付订单”收口成真正给用户使用的充值收银台与充值记录。第一版只做支付宝充值，不做退款、订阅权益、微信、自动对账和 notify 回调。

## 1. 结论

当前 `/payment/orders` 的“新增支付订单”弹窗是支付工程测试面板，不是产品页面。让用户自己选支付配置、支付方式、手写金额、手写 `return_url`，这是坏设计。

下一版要做的是：

```text
用户看到：充值套餐 -> 支付宝付款 -> 返回当前充值页 -> 充值记录同步 -> 钱包余额增加
用户不看到：config_code、证书、app_id、return_url、PC/H5 技术名、手工订单标题
```

核心落点：

```text
页面：/payment/recharge
组件：payment/recharge
权限：payment_recharge_*
API：/api/admin/v1/payment/recharges*
业务表：payment_recharge_packages / payment_recharges / user_wallets / wallet_transactions
底层支付表：继续复用 payment_orders
支付配置选择：后端按 payment_configs.status + sort 自动选择，用户不选渠道配置
```

现有 `payment_orders` 仍然是底层支付订单表；新页面不再暴露“新增支付订单”这种原始能力。支付订单创建变成充值服务的内部动作。

## 2. Linus 三问

### 2.1 这是真问题吗？

是。现在的支付订单页暴露的是工程参数，不是用户任务。用户的真实任务是“我要充值余额”，不是“我要创建一笔带 config_code 的支付宝订单”。

### 2.2 更简单的方法是什么？

不要让用户填技术字段。用一个清晰流程：

```text
选套餐 -> 确认支付 -> 后端选择可用支付宝配置 -> 创建 payment_order -> 拉起支付宝 -> 返回当前页面 -> 同步支付状态 -> 入账
```

金额来自套餐，不来自自由输入；`return_url` 来自当前页面路由，不来自用户输入；支付配置由后端按优先级选。

### 2.3 会破坏什么吗？

不能破坏：

```text
/payment/config
payment_configs
payment_config_* 权限
payment_orders 底层支付表和已有 pay/sync/close 能力
登录、RBAC、动态菜单、OperationLog
```

会新增/调整：

```text
新增 /payment/recharge 产品页
新增 payment_recharge_* 权限
新增充值套餐、充值单、钱包、钱包流水表
payment_configs 增加 sort 字段，用于后端支付配置选择
前端隐藏“手工新增支付订单”入口
```

## 3. 当前事实源

已经落地的支付 slice：

```text
active payment config table: payment_configs
active payment order table: payment_orders
backend module owner: admin_back_go/internal/module/payment
gateway boundary: admin_back_go/internal/platform/payment/alipay
frontend config page: admin_front_ts/src/views/Main/payment/config
frontend current order page: admin_front_ts/src/views/Main/payment/orders
current menu: /payment/config, /payment/orders
current order API: /api/admin/v1/payment/orders*
```

关键合同继续有效：

```text
payment_configs 没有 return_url
return_url 属于每次具体支付订单
paid 不能由后台手工改，只能由支付宝 query/sync 或未来 notify 驱动
```

本 spec 的产品判断：`return_url` 不再出现在任何用户可编辑表单里，由充值页自动生成并传给后端。

## 4. Scope

### 4.1 In scope

```text
1. 新增充值收银台页面：套餐卡片、支付宝支付卡片、支付摘要、当前余额、最近充值记录。
2. 新增充值记录 tab：搜索 + AppTable 展示当前用户充值记录。
3. 新增充值套餐表，第一版通过 migration seed 基础套餐；不做套餐管理 UI。
4. 新增用户钱包表和钱包流水表，用于余额展示和支付成功后的入账审计。
5. 新增充值单表，连接用户、套餐和 payment_orders。
6. 新增 payment_configs.sort，并在支付配置页面展示/编辑；后端按 sort 自动选启用配置。
7. 新增充值 API：page-init、create-and-pay、list、detail、sync、close。
8. 支付宝支付成功后通过手动/自动 sync 入账，入账必须幂等。
9. 权限、菜单、route meta、OperationLog、i18n、contract、smoke 同步。
```

### 4.2 Out of scope

```text
退款
提现
分账
微信支付
notify 回调
自动对账
自动关闭/自动同步 cron
订阅权益、会员有效期、赠送天数
充值套餐管理 UI
管理员给用户手工调账
用户消费扣款
多币种
发票
优惠券
```

不要因为截图里有“订阅/赠送天数”就把订阅系统塞进本 slice。第一版只做余额充值和充值记录。

## 5. 产品设计

### 5.1 页面定位

新页面不是“支付订单管理”，而是“充值/记录”。菜单建议：

```text
支付管理
  - 支付配置    /payment/config     component=payment/config
  - 充值/记录   /payment/recharge   component=payment/recharge
```

`/payment/orders` 的原始手工订单 UI 不再作为面向用户的主入口。是否保留为内部运维页，留到后续单独决定；本 slice 不继续强化这个坏入口。

### 5.2 UI 结构

页面必须在现有 `body-card` 容器内完成，不搞大面积溢出。

```text
PaymentRechargePage
  el-tabs
    Tab 1: 充值
      左侧：套餐选择 + 支付宝支付方式
      右侧：收银台摘要 + 当前余额 + 最近充值记录
    Tab 2: 充值记录
      Search + AppTable + 行操作
```

视觉方向：清爽、高级、克制。不要“赛博大屏”、不要大紫渐变、不要满屏特效。可以使用轻微蓝色强调、细边框卡片、柔和阴影和状态 tag。

### 5.3 用户交互

#### 充值 tab

用户只能做这些事：

```text
1. 选择一个充值套餐。
2. 看到应付金额、当前余额、充值后预计余额。
3. 选择/确认支付宝支付；当前只有支付宝，所以默认选中。
4. 点击“确认支付”。
```

用户不能做这些事：

```text
手写金额
选择 payment_config
选择 app_id / 证书 / 渠道配置
填写 return_url
填写订单标题
填写过期分钟
手动把订单改成 paid
```

`pay_method` 不作为技术下拉暴露。前端按设备环境选择：

```text
桌面浏览器：web
移动浏览器：h5
```

UI 对用户只展示“支付宝”。

#### 充值记录 tab

记录表展示：

```text
充值单号
支付订单号
套餐名
金额
状态
支付时间
入账时间
创建时间
操作：继续支付 / 同步 / 关闭 / 详情
```

行操作规则：

```text
pending/failed：允许继续支付
paying：允许继续支付、同步、关闭
paid/credited：只允许查看详情；credited 表示已入账
closed：只允许查看详情
```

### 5.4 return_url 策略

`return_url` 不能出现在表单。

前端只传当前页面路由基准地址：

```text
window.location.origin + router.resolve('/payment/recharge').href
```

后端创建充值单后，拼出最终同步返回地址：

```text
/payment/recharge?tab=records&recharge_no=<recharge_no>
```

最终传给支付宝的 `return_url` 存入 `payment_orders.return_url`。用户支付完成回到该页面后，前端根据 `recharge_no` 自动调用一次 sync，并刷新余额和记录。

这比让用户填 URL 强一万倍：灵活、可控、不会把工程字段暴露出去。

## 6. 命名规范

### 6.1 前后端命名

```text
route path:        /payment/recharge
component/view:    payment/recharge
frontend folder:   admin_front_ts/src/views/Main/payment/recharge
frontend API:      admin_front_ts/src/api/payment/recharges.ts
backend module:    admin_back_go/internal/module/payment
backend files:     recharge_*.go, wallet_*.go, package_*.go
operation module:  payment_recharge
menu i18n:         menu.payment_recharge
```

### 6.2 权限编码

```text
PAGE   payment_recharge_list    /payment/recharge component=payment/recharge i18n=menu.payment_recharge
BUTTON payment_recharge_add     创建充值单并拉起支付
BUTTON payment_recharge_pay     继续支付已有未完成充值单
BUTTON payment_recharge_sync    同步支付宝状态并尝试入账
BUTTON payment_recharge_close   关闭未支付充值单
```

不用这些坏名字：

```text
payment_order_create_for_recharge
payment_recharge_page
wallet_pay
pay_recharge_*
recharge_order_*
/payment/order
component=payment/order
```

## 7. 数据库设计

项目基础三字段固定为：

```text
is_del
created_at
updated_at
```

所有新增表都必须包含这三个字段。所有字段必须在第一版代码中被写入或读取；不建“以后可能会用”的字段。

### 7.1 payment_configs 增加 sort

```sql
ALTER TABLE `payment_configs`
  ADD COLUMN `sort` INT NOT NULL DEFAULT 100 AFTER `enabled_methods_json`,
  ADD KEY `idx_payment_configs_provider_status_sort` (`provider`, `status`, `is_del`, `sort`, `id`);
```

字段用途：

| 字段 | 用途 |
| --- | --- |
| sort | 后端自动选择支付配置时按 `sort ASC, id ASC` 取优先配置；支付配置列表也展示/编辑 |

不做“只能一个 status=true”的硬约束。多个启用配置是合理的热备形态：

```text
status=1 + sort 小：优先使用
status=2：人工熔断，不参与选择
```

第一版不做自动熔断计数、失败率、半开恢复。那些字段如果没有运行时消费，就是垃圾字段。

### 7.2 payment_recharge_packages

充值套餐表。第一版由 migration seed 基础套餐，前端 page-init 消费；暂不做套餐管理 UI。

```sql
CREATE TABLE `payment_recharge_packages` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `code` VARCHAR(64) NOT NULL,
  `name` VARCHAR(128) NOT NULL,
  `amount_cents` BIGINT NOT NULL,
  `badge` VARCHAR(32) NOT NULL DEFAULT '',
  `sort` INT NOT NULL DEFAULT 100,
  `status` TINYINT NOT NULL DEFAULT 1,
  `is_del` TINYINT NOT NULL DEFAULT 2,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_payment_recharge_package_code` (`code`),
  KEY `idx_payment_recharge_package_status_sort` (`status`, `is_del`, `sort`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

字段用途：

| 字段 | 用途 |
| --- | --- |
| id | 后台内部主键、排序稳定兜底 |
| code | 前端选择套餐时提交的稳定编码 |
| name | 套餐卡片标题，例如 `¥100` |
| amount_cents | 实际支付金额，单位分；充值金额来源，只能来自套餐 |
| badge | 卡片角标，例如 `推荐`，为空则不显示 |
| sort | 套餐展示顺序 |
| status | 是否启用，page-init 只返回启用套餐 |
| is_del | 软删过滤 |
| created_at | 创建时间 |
| updated_at | 更新时间 |

第一版 seed 建议：

```text
recharge_10   ¥10
recharge_20   ¥20 推荐
recharge_30   ¥30 推荐
recharge_50   ¥50 推荐
recharge_100  ¥100 推荐
recharge_300  ¥300 推荐
recharge_500  ¥500 推荐
recharge_888  ¥888
```

### 7.3 user_wallets

用户钱包余额表。

```sql
CREATE TABLE `user_wallets` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `user_id` BIGINT NOT NULL,
  `balance_cents` BIGINT NOT NULL DEFAULT 0,
  `total_recharge_cents` BIGINT NOT NULL DEFAULT 0,
  `is_del` TINYINT NOT NULL DEFAULT 2,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_user_wallet_user` (`user_id`),
  KEY `idx_user_wallet_isdel` (`is_del`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

字段用途：

| 字段 | 用途 |
| --- | --- |
| id | 钱包主键，流水表引用 |
| user_id | 当前登录用户，一人一个钱包 |
| balance_cents | 当前余额，充值页展示并在入账时增加 |
| total_recharge_cents | 累计充值金额，用户摘要和后续统计可直接读；本 slice 入账时同步更新 |
| is_del | 软删过滤；正常不删除钱包 |
| created_at | 钱包创建时间 |
| updated_at | 最后余额更新时间 |

### 7.4 wallet_transactions

钱包流水表。充值入账必须留流水，否则余额变动不可审计。

```sql
CREATE TABLE `wallet_transactions` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `transaction_no` VARCHAR(64) NOT NULL,
  `wallet_id` BIGINT NOT NULL,
  `user_id` BIGINT NOT NULL,
  `direction` VARCHAR(16) NOT NULL,
  `amount_cents` BIGINT NOT NULL,
  `balance_before_cents` BIGINT NOT NULL,
  `balance_after_cents` BIGINT NOT NULL,
  `source_type` VARCHAR(32) NOT NULL,
  `source_id` BIGINT NOT NULL,
  `remark` VARCHAR(255) NOT NULL DEFAULT '',
  `is_del` TINYINT NOT NULL DEFAULT 2,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_wallet_transaction_no` (`transaction_no`),
  UNIQUE KEY `uk_wallet_transaction_source` (`source_type`, `source_id`),
  KEY `idx_wallet_transaction_user_created` (`user_id`, `is_del`, `created_at`),
  KEY `idx_wallet_transaction_wallet_created` (`wallet_id`, `is_del`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

字段用途：

| 字段 | 用途 |
| --- | --- |
| id | 流水主键 |
| transaction_no | 展示/排障用流水号 |
| wallet_id | 关联钱包 |
| user_id | 当前用户过滤 |
| direction | 第一版充值只写 `in`；以后扣款才会有 `out`，但本字段现在就用于入账方向校验和展示 |
| amount_cents | 本次入账金额 |
| balance_before_cents | 入账前余额，用于审计 |
| balance_after_cents | 入账后余额，用于展示/审计 |
| source_type | 第一版固定 `recharge`，用于幂等来源约束 |
| source_id | `payment_recharges.id`，配合 source_type 保证一笔充值只入账一次 |
| remark | 流水说明，例如 `支付宝充值` |
| is_del | 软删过滤；流水正常不删除 |
| created_at | 流水创建时间 |
| updated_at | 流水更新时间 |

### 7.5 payment_recharges

充值单业务表。它不是底层支付订单；它表达“哪个用户为哪个套餐充值，是否已入账”。

```sql
CREATE TABLE `payment_recharges` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `recharge_no` VARCHAR(64) NOT NULL,
  `user_id` BIGINT NOT NULL,
  `package_code` VARCHAR(64) NOT NULL,
  `package_name` VARCHAR(128) NOT NULL,
  `amount_cents` BIGINT NOT NULL,
  `payment_order_id` BIGINT NOT NULL,
  `status` VARCHAR(16) NOT NULL,
  `paid_at` DATETIME NULL,
  `credited_at` DATETIME NULL,
  `failure_reason` VARCHAR(255) NOT NULL DEFAULT '',
  `is_del` TINYINT NOT NULL DEFAULT 2,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_payment_recharge_no` (`recharge_no`),
  UNIQUE KEY `uk_payment_recharge_order` (`payment_order_id`),
  KEY `idx_payment_recharge_user_status_created` (`user_id`, `is_del`, `status`, `created_at`),
  KEY `idx_payment_recharge_created` (`is_del`, `created_at`),
  CONSTRAINT `fk_payment_recharge_order`
    FOREIGN KEY (`payment_order_id`) REFERENCES `payment_orders` (`id`)
    ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

字段用途：

| 字段 | 用途 |
| --- | --- |
| id | 充值单主键，API detail/sync/close 使用 |
| recharge_no | 用户可见充值单号，return_url query 和记录表展示 |
| user_id | 当前用户隔离，只能看/操作自己的充值单 |
| package_code | 套餐编码快照，排障和记录展示 |
| package_name | 套餐名快照，套餐以后改名不影响历史记录 |
| amount_cents | 应付金额快照，创建支付订单和入账都读它 |
| payment_order_id | 连接底层 `payment_orders`，pay/sync/close 复用现有能力 |
| status | 充值业务状态：pending/paying/paid/credited/closed/failed |
| paid_at | 支付宝确认支付时间 |
| credited_at | 钱包入账时间；非空表示已入账 |
| failure_reason | 拉起支付/同步/入账失败原因，详情展示 |
| is_del | 软删过滤；本 slice 不提供删除 |
| created_at | 创建时间，记录排序 |
| updated_at | 状态更新时间 |

不把 `pay_url`、`return_url`、`config_code` 重复放进 `payment_recharges`。这些属于底层 `payment_orders`，需要时 join/read。

## 8. 状态机

### 8.1 充值状态

```text
pending   # 充值单和 payment_order 已创建，尚未拿到 pay_url
paying    # 已拿到 pay_url，等待用户支付
paid      # 支付宝已确认支付，但钱包尚未入账
credited  # 钱包已入账，终态
closed    # 未支付充值单已关闭，终态
failed    # 拉起支付或入账失败，需要用户重试或人工排查
```

### 8.2 允许转移

```text
create:            -> pending
pay success:        pending/failed -> paying
pay failed:         pending/failed -> failed
sync paid:          paying -> paid -> credited
sync waiting:       paying -> paying
sync closed:        paying -> closed
close unpaid:       pending/failed/paying -> closed
credit retry:       paid/failed -> credited     # 仅当 payment_order 已 paid 且未 credited
```

### 8.3 禁止转移

```text
credited -> any
closed -> credited
failed -> credited，除非底层 payment_order 已经 paid
任何状态 -> credited，如果 wallet_transactions 已存在同 source
任何状态 -> paid，通过后台手工按钮直接设置
```

钱包入账必须通过 DB transaction + 唯一约束保证幂等。

## 9. 后端设计

### 9.1 模块边界

继续使用当前支付模块，不引入 Java 味目录：

```text
admin_back_go/internal/module/payment
```

新增文件建议：

```text
recharge_model.go
recharge_request.go
recharge_dto.go
recharge_repository.go
recharge_service.go
recharge_handler.go
package_model.go
wallet_model.go
wallet_repository.go
```

`handler` 不查数据库，`repository` 不做业务决策，`service` 负责状态机和事务。

### 9.2 支付配置选择

新增 repository 方法：

```text
ListEnabledConfigsForPay(ctx, provider, payMethod) -> []Config
```

选择规则：

```text
provider = alipay
status = 1
is_del = 2
enabled_methods_json 包含当前 payMethod
ORDER BY sort ASC, id ASC
LIMIT 1
```

无可用配置时返回业务错误：

```text
当前支付宝支付通道不可用
```

不要让前端传 `config_code`。

### 9.3 create-and-pay 流程

`POST /api/admin/v1/payment/recharges` 是用户点击“确认支付”的唯一入口。

流程：

```text
1. 从 token 获取 current_user_id。
2. 校验 package_code 是否存在、启用。
3. 根据 UA/前端入参确定 pay_method：web/h5。
4. 后端按 sort 选择启用 payment_config。
5. 创建/读取 user_wallet。
6. 创建 payment_order，subject 使用固定规则：账户充值-<套餐名>。
7. 创建 payment_recharges，记录 user/package/payment_order。
8. 构造最终 return_url：当前充值页 + tab=records + recharge_no。
9. 调用支付宝 pay，写入 payment_orders.pay_url/status。
10. 写入 payment_recharges.status=paying。
11. 返回 pay_url，前端跳转。
```

支付网关调用不要放在 DB transaction 里。数据库创建失败就不调用支付宝；支付宝调用失败则把充值单和支付订单标记 failed，保留 failure_reason。

### 9.4 sync + 入账流程

`POST /api/admin/v1/payment/recharges/:id/sync`：

```text
1. 校验充值单属于当前用户。
2. 读取关联 payment_order。
3. 如果 payment_order 未 paid，则调用现有支付宝 query/sync。
4. 如果查询结果仍未支付，刷新状态并返回。
5. 如果已支付，进入 DB transaction：
   - SELECT payment_recharges FOR UPDATE
   - SELECT user_wallets FOR UPDATE
   - 检查 credited_at 是否为空
   - 检查 wallet_transactions(source_type='recharge', source_id=recharge.id) 不存在
   - 插入 wallet_transactions
   - 更新 user_wallets.balance_cents / total_recharge_cents
   - 更新 payment_recharges.status=credited, paid_at, credited_at
6. 返回最新余额和充值记录状态。
```

重复 sync 必须安全：已经入账就直接返回 `credited`，不能重复加钱。

### 9.5 close 流程

`PATCH /api/admin/v1/payment/recharges/:id/close`：

```text
pending/failed：本地关闭 payment_order + payment_recharge
paying：调用支付宝 close 后关闭
paid/credited：拒绝关闭
closed：幂等返回 closed
```

### 9.6 REST endpoints

```text
GET    /api/admin/v1/payment/recharges/page-init
GET    /api/admin/v1/payment/recharges
GET    /api/admin/v1/payment/recharges/:id
POST   /api/admin/v1/payment/recharges
POST   /api/admin/v1/payment/recharges/:id/pay
POST   /api/admin/v1/payment/recharges/:id/sync
PATCH  /api/admin/v1/payment/recharges/:id/close
```

`POST /:id/pay` 用于记录页“继续支付”，不是创建新充值单。

### 9.7 Request / Response 契约

创建请求：

```json
{
  "package_code": "recharge_100",
  "pay_method": "web",
  "return_url": "http://localhost:3000/payment/recharge"
}
```

注意：`return_url` 是前端自动传入的当前页面路由，不是表单字段。

创建响应：

```json
{
  "id": 1,
  "recharge_no": "RC202605150001",
  "payment_order_no": "PO202605150001",
  "status": "paying",
  "pay_url": "https://openapi-sandbox.dl.alipaydev.com/..."
}
```

page-init 响应：

```json
{
  "wallet": {
    "balance_cents": 3457,
    "balance_text": "¥34.57",
    "total_recharge_cents": 10000,
    "total_recharge_text": "¥100.00"
  },
  "packages": [
    { "code": "recharge_100", "name": "¥100", "amount_cents": 10000, "amount_text": "¥100.00", "badge": "推荐" }
  ],
  "payment_method": {
    "provider": "alipay",
    "label": "支付宝",
    "enabled": true
  },
  "dict": {
    "status_arr": []
  }
}
```

## 10. 前端设计

### 10.1 文件结构

```text
admin_front_ts/src/api/payment/recharges.ts
admin_front_ts/src/views/Main/payment/recharge/index.vue
admin_front_ts/src/views/Main/payment/recharge/components/RechargePackageGrid.vue
admin_front_ts/src/views/Main/payment/recharge/components/RechargePaymentMethodCard.vue
admin_front_ts/src/views/Main/payment/recharge/components/RechargeCheckoutPanel.vue
admin_front_ts/src/views/Main/payment/recharge/components/RechargeRecentRecords.vue
admin_front_ts/src/views/Main/payment/recharge/components/RechargeRecordsTable.vue
admin_front_ts/src/views/Main/payment/recharge/composables/usePaymentRechargePage.ts
```

组件职责：

| 组件 | 职责 |
| --- | --- |
| index.vue | 只做页面组合、tabs、布局 |
| RechargePackageGrid | 展示套餐卡片，props down / emits up |
| RechargePaymentMethodCard | 展示支付宝支付方式和可用状态 |
| RechargeCheckoutPanel | 展示应付金额、当前余额、充值后余额、确认按钮 |
| RechargeRecentRecords | 展示最近充值记录，提供继续支付/同步 |
| RechargeRecordsTable | Search + AppTable 全量记录 |
| usePaymentRechargePage | page-init、选择状态、创建支付、自动 sync、列表刷新 |

### 10.2 Vue 规则

必须使用：

```text
Vue 3 Composition API
<script setup lang="ts">
typed props / emits
computed 派生金额和按钮禁用态
watch 只处理 route query 自动 sync 这类副作用
Search + AppTable 组件
```

禁止：

```text
any / as any / Record<string, any>
把整个页面写成一个巨型 index.vue
在 template 里写复杂金额计算
把 return_url 放进 el-input
用 localStorage 当业务真相源
```

### 10.3 视觉规范

风格关键词：

```text
清爽
克制
高级
产品可用
```

设计细节：

```text
套餐卡片：白底、细边框、选中蓝色描边、角标小而明确
右侧收银台：金额数字突出，但不要夸张大屏风
支付方式：支付宝 icon + 文案 + 选中态
记录表：保持现有 AppTable 风格，不额外造表格系统
移动端：单列堆叠，收银台在套餐下方
```

## 11. 前端数据流

```text
onMounted -> page-init + records list
用户选套餐 -> selectedPackageCode
computed -> selectedPackage / payable / balanceAfter
确认支付 -> POST /payment/recharges -> location.href = pay_url
支付宝 return -> /payment/recharge?tab=records&recharge_no=...
watch route.query.recharge_no -> sync -> refresh page-init + records
记录行继续支付 -> POST /:id/pay -> location.href = pay_url
记录行同步 -> POST /:id/sync -> refresh
```

支付跳转建议使用当前窗口：

```text
window.location.href = pay_url
```

这样支付宝完成后能通过 `return_url` 回到充值页。不是新开一个孤立 tab。

## 12. 权限与菜单迁移

新增菜单：

```text
name: 充值/记录
path: /payment/recharge
component: payment/recharge
code: payment_recharge_list
i18n_key: menu.payment_recharge
parent: menu.payment
sort: 20
```

按钮：

```text
payment_recharge_add
payment_recharge_pay
payment_recharge_sync
payment_recharge_close
```

现有 `/payment/orders`：

```text
不继续作为用户主入口
不再出现“新增订单”手工表单
如果保留后台运维能力，只能做只读/操作记录页，不能让普通用户手工创建任意订单
```

第一版建议直接把菜单入口从“支付订单”切到“充值/记录”。底层 `payment_order_*` API 可以先保留给内部测试和后续运维页，但不要在用户充值页暴露。

## 13. OperationLog

需要记录：

```text
payment_recharge add   创建充值并拉起支付
payment_recharge pay   继续支付
payment_recharge sync  同步并可能入账
payment_recharge close 关闭未支付充值
```

不要记录：

```text
支付宝 pay_url 全量长链接
私钥、证书、解密内容
```

## 14. 测试策略

### 14.1 后端测试

```text
套餐不存在/禁用 -> 创建失败
无启用支付配置 -> 创建失败
payment_configs.sort 低者优先
创建充值单不接受前端 config_code
return_url 使用当前页面路由并追加 recharge_no
sync 未支付 -> 不入账
sync 已支付 -> 钱包余额增加、流水插入、recharge=credited
重复 sync -> 不重复入账
paid/credited 不能 close
用户不能操作别人的充值单
```

必须覆盖 DB transaction 幂等逻辑。这里不能靠“应该不会重复回调”这种屁话。

### 14.2 前端测试

```text
API client 路径和类型测试
page-init 渲染套餐和余额
确认支付 payload 不包含 config_code / subject / amount_yuan / 手写 return_url 字段
route query recharge_no 触发 sync
records table 行操作权限/状态显示
vue-tsc 通过
```

### 14.3 Smoke

默认 smoke 不真实调用支付宝，但要验证读路径：

```text
GET /payment/recharges/page-init
GET /payment/recharges
users/init 返回 /payment/recharge 菜单
页面契约无 config_code 手工输入字段
```

真实沙箱支付作为 credential-gated manual smoke：

```text
配置支付宝沙箱证书 -> 选择套餐 -> 创建充值 -> 打开 pay_url -> 支付宝返回 -> sync -> wallet credited
```

## 15. 实施边界

本 spec 后续 plan 应按这个顺序执行：

```text
1. DB migration：sort + packages + wallet + recharges + permission/menu seed
2. 后端：repository/model/service/handler/route/meta/tests
3. 前端：API types + recharge page components + composable + tests
4. contract/status/smoke 同步
5. 验证 live DB、Go tests、vue-tsc、Vitest、smoke read gate
```

不要先写漂亮页面再反推接口。充值是钱相关业务，后端状态机和幂等入账先定死。

## 16. Spec 自检

```text
没有 TBD/TODO
没有未使用字段
没有把订阅/退款/微信塞进第一版
没有让用户选择 payment_config
没有让用户填写 return_url
没有把 payment_orders 当充值业务表滥用
权限、路径、组件、表名、i18n key 命名一致
```
