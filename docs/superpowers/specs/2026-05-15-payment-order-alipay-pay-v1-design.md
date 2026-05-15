# Payment Order Alipay Pay V1 Design

日期：2026-05-15  
状态：draft for review  
范围：在已经完成 `payment_configs` 的前提下，补上第一版支付宝支付订单与支付拉起；不做钱包、退款、对账、微信、业务履约。

## 1. 结论

这次不是把旧 `payment_orders` 捡回来修。旧订单表已经从 payment-config-only slice 退役，本 slice 从当前 Go/Vue 架构重新做一个干净的支付订单能力：

```text
payment_orders 表
支付宝 web / h5 支付订单创建
支付宝 pay_url 拉起
支付宝订单手动同步
支付宝订单关闭
后台订单列表 / 详情
菜单、权限、API contract、smoke 同步
```

第一版必须克制：

```text
只接支付宝
只做支付发起、查询同步、关闭未支付订单
return_url 是每次支付订单入参，不回到 payment_configs
订单不能编辑金额
后台不能手动改 paid
不做 notify 回调
不做钱包入账
不做退款、提现、分账、对账、微信
```

## 2. Linus 三问

### 2.1 这是真问题吗？

是。支付配置已经能保存支付宝证书和私钥，但还不能产生一笔可支付订单。没有订单表和状态机，`payment_configs` 只是配置页，不是支付能力。

### 2.2 更简单的方法是什么？

一张订单表、一个状态机、一个支付宝 gateway 扩展，后台页面只做真实动作：

```text
创建订单 -> 拉起支付宝 -> 同步状态 -> 关闭订单
```

不要为了“以后业务很多”提前塞 `business_json`、钱包字段、退款字段、对账字段、回调事件表。

### 2.3 会破坏什么吗？

不能破坏：

```text
/payment/config
payment_configs
payment_config_* 权限
登录、RBAC、动态菜单、operation log
```

会新增：

```text
/payment/orders
payment_orders
payment_order_* 权限
/api/admin/v1/payment/orders*
```

旧 `/payment/order`、旧 `payment_order_*` 不能直接复活；路径统一改成复数 `/payment/orders`，表名统一 `payment_orders`，前端目录统一 `payment/orders`。

## 3. 当前事实源

当前支付配置 slice 已完成：

```text
active table: payment_configs
backend owner: admin_back_go/internal/module/payment
gateway boundary: admin_back_go/internal/platform/payment/alipay
frontend page: admin_front_ts/src/views/Main/payment/config
active menu: /payment/config, component=payment/config
active permission: payment_config_*
```

当前合同明确：`return_url` 不属于支付配置，后续创建具体支付请求时按单次支付入参传入。

## 4. Scope

### 4.1 In scope

```text
1. 新增 payment_orders 表。
2. 后台创建一笔支付宝订单。
3. 后台拉起支付宝 web / h5 支付，返回 pay_url。
4. 后台手动同步支付宝订单状态。
5. 后台关闭 pending / paying 订单。
6. 后台订单列表、搜索、详情。
7. 菜单 / 权限 / i18n / route meta / OperationLog。
8. API contract、current-status、smoke read gate。
```

### 4.2 Out of scope

```text
钱包余额
充值入账
退款
提现
分账
对账
微信支付
支付宝 notify 回调接收
支付事件表
自动定时同步
自动关闭过期订单 cron
业务订单履约
用户端收银台页面
```

自动任务不是第一版。后续如果要做 `payment_close_expired_order` 或 `payment_sync_pending_order`，必须另写 spec，并且再决定是否补索引。

## 5. 数据库设计

### 5.1 新表：payment_orders

```sql
CREATE TABLE `payment_orders` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `order_no` VARCHAR(64) NOT NULL,
  `config_id` BIGINT NOT NULL,
  `config_code` VARCHAR(64) NOT NULL,
  `provider` VARCHAR(32) NOT NULL DEFAULT 'alipay',
  `pay_method` VARCHAR(16) NOT NULL,
  `subject` VARCHAR(128) NOT NULL,
  `amount_cents` BIGINT NOT NULL,
  `status` VARCHAR(16) NOT NULL,
  `pay_url` VARCHAR(2048) NOT NULL DEFAULT '',
  `return_url` VARCHAR(512) NOT NULL DEFAULT '',
  `alipay_trade_no` VARCHAR(64) NOT NULL DEFAULT '',
  `expired_at` DATETIME NOT NULL,
  `paid_at` DATETIME NULL,
  `closed_at` DATETIME NULL,
  `failure_reason` VARCHAR(255) NOT NULL DEFAULT '',
  `is_del` TINYINT NOT NULL DEFAULT 2,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_payment_orders_order_no` (`order_no`),
  KEY `idx_payment_orders_isdel_status_created` (`is_del`, `status`, `created_at`),
  KEY `idx_payment_orders_config_created` (`config_id`, `created_at`, `is_del`),
  CONSTRAINT `fk_payment_orders_config`
    FOREIGN KEY (`config_id`) REFERENCES `payment_configs` (`id`)
    ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

项目基础三字段固定为：

```text
is_del
created_at
updated_at
```

不是 `credat_at`。库里只允许标准拼写 `created_at`。

### 5.2 每个字段为什么存在

| 字段 | 第一版真实用途 | 写入/读取位置 |
| --- | --- | --- |
| id | 后台列表行、详情、pay/sync/close 路由主键 | repository 主键查询；前端 row-key |
| order_no | 本地支付订单号，同时作为支付宝 `out_trade_no` | create 生成；pay/query/close 传支付宝 |
| config_id | 绑定具体 `payment_configs.id`，保证订单知道用哪套证书和 app_id | create 由 `config_code` 解析；pay/sync/close 取配置 |
| config_code | 配置编码快照和列表搜索展示 | create 快照；列表/详情返回 |
| provider | 支付供应商，当前只能 `alipay`，用于筛选和 gateway 分发 | create 从配置复制；service 校验 |
| pay_method | 支付方式，当前 `web` / `h5` | create 入参；pay 选择 `TradePagePay` 或 `TradeWapPay` |
| subject | 支付宝订单标题 | create 入参；pay 传 `subject`；列表展示 |
| amount_cents | 金额，单位分，避免 float/decimal 参与 Go 运算 | create 入参；pay 转 `total_amount`；列表展示 |
| status | 订单状态机 | create/pay/sync/close 写；列表筛选 |
| pay_url | 支付宝 SDK 返回的跳转 URL | pay 写；详情/操作返回；列表不展示长 URL |
| return_url | 单次支付完成后的同步跳转地址 | create 入参；pay 传支付宝；不是配置字段 |
| alipay_trade_no | 支付宝交易号 | sync 从支付宝查询结果写入；详情展示 |
| expired_at | 订单过期时间 | create 计算；pay 传 `time_expire`；列表/详情展示 |
| paid_at | 支付成功时间 | sync 映射 `TRADE_SUCCESS` / `TRADE_FINISHED` 时写入 |
| closed_at | 关闭时间 | close 或 sync 映射 `TRADE_CLOSED` 时写入 |
| failure_reason | 支付拉起失败原因 | pay 失败写入；详情展示；成功后清空 |
| is_del | 项目软删基础字段，所有 repository 查询必须带 `is_del=2` | repository 查询条件；本 slice 不提供 UI 删除 |
| created_at | 创建时间 | 列表排序、搜索展示 |
| updated_at | 最后状态更新时间 | 列表展示、状态变化追踪 |

### 5.3 明确不建的字段

```text
currency          # 第一版固定 CNY，没多币种就不入库
business_type     # 没有上层业务履约，不建假关联
business_ref      # 没有上层业务履约，不建假关联
buyer_id          # 当前不是用户钱包/会员支付
created_by        # 操作者由 OperationLog 记录；订单本身不消费
updated_by        # 同上
notify_url        # 支付配置已有，订单不重复保存
refund_amount     # 退款不做
refund_status     # 退款不做
raw_request       # 垃圾桶字段，禁止
raw_response      # 垃圾桶字段，禁止
extra_json        # 垃圾桶字段，禁止
```

这张表只放第一版代码会真实读写的字段。以后 notify / 钱包 / 退款要加字段，必须用新 spec 解释字段用途。

## 6. 订单状态机

### 6.1 状态值

```text
pending  # 本地订单已创建，尚未成功拿到支付宝 pay_url
paying   # 已成功拿到 pay_url，等待用户付款
paid     # 手动 sync 查询到支付宝已支付
closed   # 后台关闭，或 sync 查询到支付宝已关闭
failed   # 拉起支付宝支付失败
```

### 6.2 允许转移

```text
create:        -> pending
pay success:   pending/failed -> paying
pay failed:    pending/failed -> failed
sync paid:     paying -> paid
sync closed:   paying -> closed
sync waiting:  paying -> paying
close local:   pending/failed -> closed
close alipay:  paying -> closed
```

### 6.3 禁止转移

```text
paid -> closed       # 已支付不能后台关闭，退款是另一个业务
paid -> failed       # 支付成功不能被失败覆盖
closed -> paid       # 本地已关闭不允许手工改 paid
any -> paid by admin # 后台不能手动点“设为已支付”
```

`paid` 第一版只能由 `sync` 根据支付宝查询结果写入。notify 回调以后接入时，也必须复用同一套状态机，不准另开一套“回调状态”。

## 7. 后端设计

### 7.1 模块边界

继续使用当前支付模块，不新建 Java 味目录：

```text
admin_back_go/internal/module/payment
```

新增文件使用 `order_` 前缀，避免把配置代码搅成一坨：

```text
order_model.go
order_request.go
order_dto.go
order_repository.go
order_service.go
order_handler.go
```

调用链保持项目规则：

```text
route -> handler -> service -> repository -> model
```

禁止：

```text
handler 直接查 DB
service 依赖 gin.Context
repository 写状态机规则
model 写业务方法
```

### 7.2 Gateway 扩展

`admin_back_go/internal/platform/payment/alipay` 当前只有本地配置测试。本 slice 扩展最小接口：

```go
type PayInput struct {
    OutTradeNo  string
    Method      string
    Subject     string
    AmountCents int64
    ReturnURL   string
    ExpiredAt   time.Time
}

type PayResult struct {
    PayURL string
}

type QueryResult struct {
    TradeNo string
    Status  string
    PaidAt  *time.Time
}

type Gateway interface {
    TestConfig(ctx context.Context, cfg ChannelConfig) error
    Pay(ctx context.Context, cfg ChannelConfig, in PayInput) (*PayResult, error)
    Query(ctx context.Context, cfg ChannelConfig, outTradeNo string) (*QueryResult, error)
    Close(ctx context.Context, cfg ChannelConfig, outTradeNo string) error
}
```

实现映射：

```text
web -> gopay/alipay.Client.TradePagePay
h5  -> gopay/alipay.Client.TradeWapPay
query -> TradeQuery
close -> TradeClose
```

金额转换必须用整数格式化：

```text
amount_cents=1234 -> "12.34"
```

禁止用 float 参与金额计算。

### 7.3 服务规则

#### CreateOrder

```text
1. 校验 config_code 存在、provider=alipay、status=enabled。
2. 校验 pay_method 在 payment_configs.enabled_methods_json 内。
3. 校验 subject、amount_cents、return_url、expire_minutes。
4. 生成 order_no。
5. 插入 payment_orders，status=pending。
```

#### PayOrder

```text
1. 只允许 pending / failed。
2. 如果订单已过期，直接转 closed。
3. 读取 payment_configs 并解密私钥、解析证书。
4. 调用支付宝 PagePay/WapPay。
5. 成功：写 pay_url、status=paying、failure_reason=''。
6. 失败：写 status=failed、failure_reason。
```

如果调用方对已经 `paying` 且 `pay_url` 不为空的订单重复 pay，返回现有 pay_url，保证幂等。

#### SyncOrder

```text
1. 只允许 paying。
2. 调用支付宝 TradeQuery。
3. WAIT_BUYER_PAY -> 保持 paying。
4. TRADE_SUCCESS / TRADE_FINISHED -> paid，写 alipay_trade_no / paid_at。
5. TRADE_CLOSED -> closed，写 closed_at。
```

#### CloseOrder

```text
1. pending / failed：本地关闭，写 closed_at。
2. paying：调用支付宝 TradeClose 后写 closed_at。
3. paid：拒绝关闭。
4. closed：幂等成功。
```

### 7.4 API

统一前缀：

```text
/api/admin/v1/payment/orders
```

Endpoint：

```text
GET    /api/admin/v1/payment/orders/page-init
GET    /api/admin/v1/payment/orders
GET    /api/admin/v1/payment/orders/:id
POST   /api/admin/v1/payment/orders
POST   /api/admin/v1/payment/orders/:id/pay
POST   /api/admin/v1/payment/orders/:id/sync
PATCH  /api/admin/v1/payment/orders/:id/close
```

不提供：

```text
PUT    /api/admin/v1/payment/orders/:id
DELETE /api/admin/v1/payment/orders/:id
```

订单金额和状态不能后台编辑或删除。

#### page-init response

```json
{
  "dict": {
    "provider_arr": [{ "label": "支付宝", "value": "alipay" }],
    "pay_method_arr": [{ "label": "电脑网站支付", "value": "web" }],
    "order_status_arr": [{ "label": "待支付", "value": "paying" }]
  },
  "config_options": [
    {
      "label": "支付宝沙箱(alipay_sandbox)",
      "value": "alipay_sandbox",
      "provider": "alipay",
      "enabled_methods": ["web", "h5"]
    }
  ]
}
```

`config_options` 只返回 `status=1` 的配置。支付配置的启用动作已经有本地测试守卫；订单 page-init 不额外解密私钥或读取证书。真正拉起支付时再做证书和私钥解析，失败就写入订单 `failure_reason`。

#### list query

```text
current_page
page_size
keyword       # order_no / subject / alipay_trade_no
config_code
provider
pay_method
status
date_start
date_end
```

#### create request

```json
{
  "config_code": "alipay_sandbox",
  "pay_method": "web",
  "subject": "测试支付订单",
  "amount_cents": 100,
  "return_url": "http://localhost:8080/payment/result",
  "expire_minutes": 30
}
```

`return_url` 是每笔支付订单的入参。允许为空；非空时必须是 http/https URL。

#### create response

```json
{
  "id": 1,
  "order_no": "PAY202605151234560001",
  "status": "pending"
}
```

#### pay response

```json
{
  "id": 1,
  "order_no": "PAY202605151234560001",
  "status": "paying",
  "pay_url": "https://openapi.alipaydev.com/gateway.do?..."
}
```

#### sync / close response

```json
{
  "id": 1,
  "order_no": "PAY202605151234560001",
  "status": "paid",
  "status_text": "已支付",
  "alipay_trade_no": "202605152200...",
  "paid_at": "2026-05-15 12:40:01",
  "closed_at": ""
}
```

## 8. 权限、菜单、i18n

### 8.0 唯一命名矩阵

实现时只能按这张表落地。不要再出现单数 `/payment/order`、`payment/order`、`paymentOrder`、`payment_order_page` 这类别名；别名就是未来重构债。

| 层 | 唯一命名 | 说明 |
| --- | --- | --- |
| 数据表 | `payment_orders` | 复数表名，和 `payment_configs` 对齐 |
| 后端模块 | `internal/module/payment` + `order_*.go` | 不新建 `paymentorder` 包，避免支付域被拆散 |
| 后端 route group | `/api/admin/v1/payment/orders` | REST resource 用复数 |
| 前端 API 文件 | `src/api/payment/orders.ts` | 文件名跟 resource 复数一致 |
| 前端页面目录 | `src/views/Main/payment/orders` | 目录名跟路由复数一致 |
| 前端 route path | `/payment/orders` | 不使用旧 `/payment/order` |
| 前端 component key | `payment/orders` | 必须和权限表 `component` 一致 |
| 前端 composable | `usePaymentOrderPage` | 页面逻辑单数概念，代码标识用 Pascal/Camel |
| 页面权限 code | `payment_order_list` | 和当前 `payment_config_list` 规则一致 |
| 按钮权限前缀 | `payment_order_` | add/pay/sync/close 统一前缀 |
| i18n key | `menu.payment_order` | 菜单 key 用单数业务概念 |
| OperationLog module | `payment_order` | 和权限前缀一致 |
| CSS block | `.payment-order-page` | kebab-case，和现有页面风格一致 |

权限 code 规则固定：

```text
<domain>_<resource>_<action>

domain   = payment
resource = order
action   = list | add | pay | sync | close
```

不使用：

```text
payment_orders_*
payment_order_page
payment_order_detail
payment_order_create
payment_order_delete
/payment/order
component=payment/order
```

原因很简单：当前项目已有 `payment_config_*`，订单就必须是 `payment_order_*`。路径和文件用复数表达 REST resource，权限 code 用单数业务资源表达动作。两套规则各有用途，不能混写。

### 8.1 菜单

```text
DIR  payment              支付管理
PAGE payment_order_list   /payment/orders component=payment/orders i18n_key=menu.payment_order
```

排序：

```text
/payment/config   sort=10
/payment/orders   sort=20
```

### 8.2 按钮权限

```text
payment_order_add
payment_order_pay
payment_order_sync
payment_order_close
```

详情接口使用 `payment_order_list`，不单独造 `payment_order_detail`。详情是列表权限下的只读能力，单独按钮权限只会增加噪音。

### 8.3 route meta

```text
GET    /payment/orders/page-init -> payment_order_list
GET    /payment/orders           -> payment_order_list
GET    /payment/orders/:id       -> payment_order_list
POST   /payment/orders           -> payment_order_add
POST   /payment/orders/:id/pay   -> payment_order_pay
POST   /payment/orders/:id/sync  -> payment_order_sync
PATCH  /payment/orders/:id/close -> payment_order_close
```

OperationLog：

```text
Module: payment_order
create title: 新增支付订单
pay title: 拉起支付宝支付
sync title: 同步支付订单状态
close title: 关闭支付订单
```

`pay` 响应里有长 `pay_url`，route meta 必须 `SkipResponsePayload=true`。支付配置私钥、证书正文仍然不能进日志。

### 8.4 前端 i18n

```text
zh-CN: menu.payment_order = 支付订单
en-US: menu.payment_order = Payment Orders
```

## 9. 前端设计

### 9.1 文件结构

```text
admin_front_ts/src/api/payment/orders.ts
admin_front_ts/src/views/Main/payment/orders/index.vue
admin_front_ts/src/views/Main/payment/orders/components/PaymentOrderFormDialog.vue
admin_front_ts/src/views/Main/payment/orders/components/PaymentOrderDetailDialog.vue
admin_front_ts/src/views/Main/payment/orders/composables/usePaymentOrderPage.ts
```

目录用复数 `orders`，和路由 `/payment/orders`、API `/payment/orders`、表 `payment_orders` 对齐。

### 9.2 页面组件

`index.vue` 只做组合，不塞业务细节：

```text
Search
AppTable
AppDialog(create/pay)
AppDialog(detail)
```

根容器：

```css
.payment-order-page {
  display: flex;
  flex-direction: column;
  height: 100%;
}
```

不再额外套一个超过 body-card 的大卡片。页面高度交给现有 layout/body-card；列表滚动交给 `AppTable`。

### 9.3 Search

搜索项：

```text
keyword
config_code
pay_method
status
date_start/date_end
```

Search 使用现有 `Search` 组件和 typed `SearchField`，不手写一套搜索栏。

### 9.4 AppTable

列：

```text
order_no
config_code
provider_text
pay_method_text
subject
amount_text
status_text
expired_at
created_at
updated_at
actions
```

`pay_url` 不进表格列，太长；只在支付结果提示和详情弹窗里展示。

操作按钮：

```text
payment_order_pay   # pending/failed 可见；paying 有 pay_url 时可再次打开
payment_order_sync  # paying 可见
payment_order_close # pending/failed/paying 可见
详情               # payment_order_list 即可
```

### 9.5 AppDialog

必须使用现有 `AppDialog`，不能回退 `el-dialog`。

弹窗尺寸：

```text
width: desktop 820px / mobile 94vw
height: desktop 70vh / mobile 72vh
top: desktop 4vh / mobile 3vh
```

内容超出时走 AppDialog 内滚动，不把 body-card 顶爆。

### 9.6 Composable

`usePaymentOrderPage.ts` 负责：

```text
page-init
useTable list
createOrder
payOrder
syncOrder
closeOrder
openDetailDialog
openPayDialog
```

Vue 规则：

```text
Composition API
<script setup lang="ts">
props down / events up
状态集中在 composable
组件只渲染和 emit
```

金额输入前端可展示元，但提交 API 必须转成 `amount_cents` 整数。禁止把浮点金额直接传给后端。

## 10. 后续文档和验证

实现本 spec 时必须同步：

```text
docs/contracts/admin-api-v1.md
docs/status/current-status.md
admin_back_go/docs/architecture.md
admin_back_go/docs/smoke-matrix.md
```

后端验证：

```powershell
go test -p=1 ./internal/module/payment ./internal/platform/payment ./internal/platform/payment/alipay ./internal/bootstrap ./internal/server
go vet ./internal/module/payment ./internal/platform/payment ./internal/platform/payment/alipay ./internal/bootstrap ./internal/server
powershell -ExecutionPolicy Bypass -File .\scripts\check-contract.ps1
```

前端验证：

```powershell
npx vitest run tests/shared/payment/payment-order-api.test.ts tests/shared/payment/payment-order-page.test.ts
npx vue-tsc -b --pretty false
```

Smoke：

```text
basic smoke: users/init 能看到 /payment/config 和 /payment/orders
full smoke read gate: page-init/list/detail shape
credential-gated manual smoke: 使用沙箱证书创建订单、pay 返回 pay_url、浏览器打开 pay_url、sync 查询状态
```

默认 smoke 不真实调用支付宝，不上传真实证书，不要求能支付成功。

## 11. Review checklist

实现前必须逐项确认：

```text
payment_orders 有 is_del / created_at / updated_at
表内每个字段都在 service/repository/API/frontend 中被使用
没有 extra_json/raw_json 这种垃圾桶字段
没有钱包/退款/对账/微信字段
return_url 只在订单创建入参和 payment_orders 内出现，不回到 payment_configs
订单金额不能编辑
paid 只能由支付宝 query/sync 写入
前端使用 Search/AppTable/AppDialog
弹窗设置 height/top，内容不撑爆 body-card
route meta 和权限 code 跟路径、component、i18n_key 一致
OperationLog 不记录私钥、证书正文、pay_url 长响应
```
