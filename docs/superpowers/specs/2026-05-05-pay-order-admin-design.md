# Pay Order Admin Migration Design

状态：approved for implementation in current branch, no commit.

## Linus 三问

1. 真问题：是。支付渠道和支付流水已经迁到 Go，但后台“统一订单管理”还在走 legacy PHP 全 POST。这个页面是支付、钱包、履约、对账的事实中心，不能继续留在 PHP。
2. 更简单做法：先迁后台订单管理窄切片：init / status-count / list / detail / remark / local-close。不碰支付下单、第三方 SDK、回调、钱包调账、履约和对账执行。
3. 会破坏什么：不能破坏现有页面字段、权限码和按钮逻辑。DB 里页面权限实际是 `pay_recharge_list`，按钮是 `pay_order_edit`，Go route metadata 必须尊重这个事实。

## Scope

迁移后台订单管理页：

```text
GET   /api/admin/v1/pay-orders/page-init
GET   /api/admin/v1/pay-orders/status-count
GET   /api/admin/v1/pay-orders
GET   /api/admin/v1/pay-orders/:id
PATCH /api/admin/v1/pay-orders/:id/close
PATCH /api/admin/v1/pay-orders/:id/remark
```

不迁移用户侧/钱包侧接口：

```text
/api/admin/pay/recharge
/api/admin/pay/createPay
/api/admin/pay/cancelOrder
/api/admin/pay/myOrders
/api/admin/pay/queryResult
/api/admin/pay/orderDetail
/api/admin/pay/walletInfo
/api/admin/pay/walletBills
```

这些仍保留 legacyRequest，等钱包模块切片再处理。

## Runtime Facts

当前 MySQL 事实：

```text
orders active rows: 3
order_items active rows: 3
permissions page: id=98 name=统一订单管理 code=pay_recharge_list type=PAGE path=/pay/order
permissions button: id=109 name=订单操作 code=pay_order_edit type=BUTTON parent_id=98
```

Legacy PHP 事实：

```text
OrderAdminModule::init/list/detail/statusCount/close/remark
OrderDep::list/countByStatus/closeOrder/update
OrderValidate::list/detail/close/remark
PayEnum order_type/pay_status/biz_status/recharge_preset
```

## Contract Boundary

后台订单管理只读/轻写：

- list/detail/status-count 是后台事实查询。
- remark 只更新 `orders.admin_remark`。
- close 是 Go 第一版本地关闭：仅允许 `pay_status in (PENDING, PAYING)`，用 DB transaction 更新 `orders.pay_status=CLOSED`、`close_time`、`close_reason`，并关闭最后一条未完成 `pay_transactions`。
- close 不调用第三方支付 SDK，不查单，不关第三方订单。这个不是假实现；它是明确的 admin local close 边界。第三方 SDK/回调 runtime 后续单独迁移。

## Backend Design

模块：`internal/module/payorder`。

分层固定：

```text
route.go -> handler.go -> service.go -> repository.go -> model.go
request.go 只放 Gin binding 入参
dto.go 放 service/input/output DTO
```

枚举补齐在 `internal/enum/pay.go`：

```text
PayOrderRecharge/Consume/Goods
PayStatusPending/Paying/Paid/Closed/Exception
PayBizInit/Pending/Executing/Success/Failed/Manual
RechargePresets
```

字典由 `internal/dict` 派生，不让前端手写 label fallback。

## Frontend Design

文件：

```text
src/api/pay/order.ts
src/views/Main/pay/order/index.vue
src/views/Main/pay/order/composables/usePayOrderPage.ts
```

拆分原则：当前页面已经有 view + composable，先不额外拆组件；但必须去掉 touched code 里的 `any` formatter，并保持 route view 只做组合。

`OrderApi` 里后台订单管理方法改 Go REST：

```text
init/list/detail/statusCount/close/remark -> request + /api/admin/v1/pay-orders
```

用户侧钱包/充值方法继续 legacyRequest，不能冒充已经迁移。

## Tests and Smoke

Backend：

- enum/dict/validate 测 order type / pay status / biz status。
- payorder handler 测 query/body/id binding。
- payorder service 测 dict、list label/time、detail JSON、remark、close 状态规则。
- router/bootstrap route metadata 测注册和权限码。

Frontend：

- `tests/shared/pay-order/pay-order-api.test.ts` 断言后台订单管理改 Go REST、用户侧钱包仍 legacy、无 any/as any/Record<string, any>。
- 既有 helper test 保留。

Smoke：

- full smoke 探测 page-init/status-count/list/detail。
- 如果存在待支付/支付中订单才做 close 写探测；默认当前库没有待支付就跳过，避免污染历史数据。
- remark 写探测只在读到订单时执行，并恢复原备注，作为轻量可回滚验证。

## Exit Criteria

- 后台订单页不再依赖 legacy PHP。
- 权限闭环：read 用 `pay_recharge_list`，mutating 用 `pay_order_edit`。
- operation log 覆盖 close/remark，且不记录钱包/SDK 假动作。
- 文档、current-status、smoke-matrix 同步。
