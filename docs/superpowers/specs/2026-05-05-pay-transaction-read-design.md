# Pay Transaction Read Migration Design

状态：draft for implementation
日期：2026-05-05
范围：支付域第二刀，只迁移后台支付流水只读管理页，不做支付下单、回调、钱包调账、对账执行。

## Linus 三问

1. 真问题：是。Pay Channel 已经迁到 Go，但支付流水页仍走 legacy 全 POST，后台无法完整脱离 PHP 支付管理。
2. 更简单做法：先迁 `pay_transactions` 只读 init/list/detail，复用现有 pay enum/dict/validate，不碰支付 SDK 和状态机。
3. 会破坏什么：不能破坏已存在前端支付流水页面字段；新接口保持返回字段同当前页面消费字段一致，只把 transport 改成 RESTful Go。

## 目标

把后台支付流水管理页迁到 Go REST：

```text
GET /api/admin/v1/pay-transactions/page-init
GET /api/admin/v1/pay-transactions
GET /api/admin/v1/pay-transactions/:id
```

这三个接口只读。它们服务 admin 后台审计和排障，不承担支付结果变更。

## 不做什么

本切片明确不做：

```text
支付 SDK 接入
充值下单 / createPay
支付回调 / 验签 / handlePaySuccess
订单关闭 / 订单备注
钱包入账 / 调账
对账下载 / 对账执行
退款（产品范围关闭，不是未来迁移项）
批量导出
```

这些要么涉及第三方支付协议，要么涉及事务状态机，不能混进只读列表迁移。

## 现状证据

Legacy 后端：

```text
E:/admin/admin_back/app/controller/Pay/PayTransactionController.php
E:/admin/admin_back/app/module/Pay/PayTransactionModule.php
E:/admin/admin_back/app/dep/Pay/PayTransactionDep.php
E:/admin/admin_back/app/validate/Pay/PayTransactionValidate.php
```

前端当前入口：

```text
E:/admin_go/admin_front_ts/src/api/pay/transaction.ts
E:/admin_go/admin_front_ts/src/views/Main/pay/transaction/index.vue
```

当前数据库样本：

```text
orders active rows: 3
pay_transactions active rows: 3
user_wallets active rows: 1
wallet_transactions active rows: 1
pay_notify_logs active rows: 0
pay_reconcile_tasks active rows: 3
```

结论：支付域已有真实 runtime 数据，先迁只读流水能马上 smoke，不需要制造假支付。

## 数据模型

使用现有表，不改表结构：

```text
pay_transactions
orders
users
pay_channel
```

查询关系：

```text
pay_transactions.order_id -> orders.id
orders.user_id -> users.id
pay_transactions.channel_id -> pay_channel.id
```

字段原则：

```text
列表只返回摘要字段
详情返回 channel_resp/raw_notify，但只作为 JSON 对象，不做业务解释
不返回 pay_channel 私钥字段
不把 JSON 解码失败当成服务崩溃；返回空对象并保持日志可排查
```

## API Contract

### GET /api/admin/v1/pay-transactions/page-init

Auth：后台 token required。

Response data：

```json
{
  "dict": {
    "channel_arr": [{ "label": "微信支付", "value": 1 }],
    "txn_status_arr": [{ "label": "已创建", "value": 1 }]
  }
}
```

### GET /api/admin/v1/pay-transactions

Query：

```text
current_page int optional min=1 default=1
page_size int optional min=1 max=100 default=20
order_no string optional max=32 exact match
transaction_no string optional max=64 exact match
user_id int optional min=1
channel int optional enum pay_channel
status int optional enum pay_txn_status
start_date string optional YYYY-MM-DD
end_date string optional YYYY-MM-DD
```

Response data：

```json
{
  "list": [
    {
      "id": 3,
      "transaction_no": "T260413183826000006",
      "order_no": "R260413183826000005",
      "user_id": 1,
      "user_name": "admin",
      "user_email": "demo@example.test",
      "attempt_no": 1,
      "channel_id": 1,
      "channel": 2,
      "channel_text": "支付宝",
      "pay_method": "web",
      "pay_method_text": "PC网页支付",
      "amount": 1000,
      "trade_no": "",
      "trade_status": "",
      "status": 3,
      "status_text": "支付成功",
      "paid_at": null,
      "created_at": "2026-04-13 18:38:26"
    }
  ],
  "page": {
    "page_size": 20,
    "current_page": 1,
    "total_page": 1,
    "total": 3
  }
}
```

### GET /api/admin/v1/pay-transactions/:id

Response data：

```json
{
  "transaction": {
    "id": 3,
    "transaction_no": "T260413183826000006",
    "order_no": "R260413183826000005",
    "attempt_no": 1,
    "channel_id": 1,
    "channel": 2,
    "channel_text": "支付宝",
    "pay_method": "web",
    "pay_method_text": "PC网页支付",
    "amount": 1000,
    "trade_no": "",
    "trade_status": "",
    "status": 3,
    "status_text": "支付成功",
    "paid_at": null,
    "closed_at": null,
    "channel_resp": {},
    "raw_notify": {},
    "created_at": "2026-04-13 18:38:26"
  },
  "channel": {
    "id": 1,
    "name": "支付宝默认",
    "channel": 2
  },
  "order": {
    "id": 3,
    "order_no": "R260413183826000005",
    "user_id": 1,
    "user_name": "admin",
    "user_email": "demo@example.test",
    "title": "充值10元",
    "pay_amount": 1000,
    "pay_status": 3
  }
}
```

## Backend 设计

新模块：

```text
admin_back_go/internal/module/paytransaction/
  errors.go
  model.go
  dto.go
  request.go
  repository.go
  service.go
  handler.go
  route.go
  service_test.go
  handler_test.go
```

调用链固定：

```text
route -> handler -> service -> repository -> model
```

规则：

```text
handler 只 bind query/path，不查 DB
service 做默认分页、枚举 label、时间格式、JSON 字段规范化
repository 只写查询，不写业务判断
```

权限：

```text
GET /api/admin/v1/pay-transactions/page-init -> pay_transaction_list
GET /api/admin/v1/pay-transactions -> pay_transaction_list
GET /api/admin/v1/pay-transactions/:id -> pay_transaction_list
```

这三个是只读路由，不进入 operation log。

## Frontend 设计

改动最小：

```text
admin_front_ts/src/api/pay/transaction.ts
admin_front_ts/src/views/Main/pay/transaction/index.vue
```

`PayTransactionApi` 保持 `init/list/detail` facade，内部改 Go `request`：

```text
init   -> GET /api/admin/v1/pay-transactions/page-init
list   -> GET /api/admin/v1/pay-transactions
详情   -> GET /api/admin/v1/pay-transactions/:id
```

页面是只读表格，应该从 `useCrudTable` 改成 `useTable`，因为 `useCrudTable` 带 delete/status 的 CRUD 语义，这里是坏味道。

顺手修现有明显 TS 污点：

```text
不要 _r:any,_c:any 这种 formatter
不要 Record<string, any>
```

允许 `Record<string, unknown>` 表达第三方支付原始 JSON，但只限 API 类型字段 `channel_resp/raw_notify`，不能作为泛型兜底参数。

## Smoke

`full-admin-smoke.ps1` 增加只读 probe：

```text
GET /api/admin/v1/pay-transactions/page-init
GET /api/admin/v1/pay-transactions?current_page=1&page_size=20
if list_count > 0: GET /api/admin/v1/pay-transactions/:id
```

检查：

```text
init has channel_arr + txn_status_arr
list has list + page
list item has no app_private_key/app_private_key_enc
详情 transaction.channel_resp/raw_notify 是对象
详情 channel 不包含私钥字段
```

## 测试策略

Backend：

```text
service test: dict/status label/json normalize/page defaults
handler test: REST query/path binding and invalid id
router/bootstrap test: route exists + permission metadata exists
```

Frontend：

```text
Vitest: PayTransactionApi path/method contract
vue-tsc: 类型检查
eslint targeted: touched files no errors
```

## 下一步边界

Pay Transaction 只读迁完后，下一刀再选：

```text
Pay Order admin read/write-light: 订单列表、详情、关闭、备注
User Wallet admin: 钱包列表、流水、调账事务
Pay NotifyLog read-only: 回调日志审计
```

我的建议顺序是：

```text
pay transaction read -> pay order admin -> wallet admin -> notify log -> reconcile read/retry
```

原因：先把支付事实链路看清楚，再碰会改钱的钱包事务。
