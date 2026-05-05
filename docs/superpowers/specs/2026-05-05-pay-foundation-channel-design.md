# Pay Foundation and Pay Channel Design

状态：approved for planning，未实现。
日期：2026-05-05

## 目标

把支付域迁移的第一块地基踩实：先补 Go 支付枚举、字典、入参校验和支付渠道管理 REST API，再适配前端支付渠道页面。不要在本阶段接真实支付 SDK、支付回调、充值下单、钱包调账或对账执行。

一句话：**先迁配置管理和契约，不碰真实资金流。**

## Linus 三问

1. 这是个真问题吗？

是。当前前端 `src/api/pay/*` 仍大量走 legacy PHP，MySQL 里已经存在支付渠道、订单、支付流水、钱包和对账表；支付后台不是空想模块。

2. 有更简单的做法吗？

有。第一刀只迁 `PayChannel` 和支付基础 enum/dict/validate。支付 SDK、回调、充值、履约、钱包扣增、对账下载都先不做，避免一次把资金状态机、第三方 SDK、队列、事务和文件下载绑在一起。

3. 会破坏什么吗？

如果接口命名、字段或权限 code 改错，会破坏现有支付渠道页面和充值页读取可用渠道。设计上保持旧业务字段语义，迁新 REST path；前端只改 `PayChannelApi` 调 Go，不改页面业务交互。

## 当前事实

### Go 基建事实

`docs/migration/current-status.md` 显示当前 Go 基建已经有：

- auth/session/RBAC
- users/profile
- operation log
- system log
- queue/worker/scheduler
- upload config/runtime token
- realtime WebSocket baseline

但 Go 里还没有支付域：

- `internal/enum` 无 `pay.go`
- `internal/dict` 无支付 options
- `internal/validate` 无支付自定义 validator tag
- `internal/module` 无 `paychannel` 或 `wallet` 模块

### legacy PHP 业务事实

支付渠道旧入口：

```text
E:\admin\admin_back\app\controller\Pay\PayChannelController.php
E:\admin\admin_back\app\module\Pay\PayChannelModule.php
E:\admin\admin_back\app\dep\Pay\PayChannelDep.php
E:\admin\admin_back\app\validate\Pay\PayChannelValidate.php
E:\admin\admin_back\app\enum\PayEnum.php
```

旧支付渠道能力：

```text
init
list
add
edit
del
status
```

旧按钮权限 code：

```text
pay_channel_add
pay_channel_edit
pay_channel_del
pay_channel_status
```

旧页面 code：

```text
pay_channel_list
```

### 前端事实

当前前端支付渠道 API：

```text
admin_front_ts/src/api/pay/channel.ts
```

仍使用 legacy action path：

```text
/api/admin/PayChannel/init
/api/admin/PayChannel/list
/api/admin/PayChannel/add
/api/admin/PayChannel/edit
/api/admin/PayChannel/del
/api/admin/PayChannel/status
```

页面位置：

```text
admin_front_ts/src/views/Main/pay/channel/index.vue
admin_front_ts/src/views/Main/pay/channel/types.ts
admin_front_ts/src/views/Main/pay/channel/composables/usePayChannelPage.ts
```

### MySQL 事实

当前支付域表：

```text
pay_channel
orders
order_items
order_fulfillments
pay_transactions
pay_notify_logs
pay_reconcile_tasks
pay_refunds
user_wallets
wallet_transactions
```

当前行数：

```text
pay_channel=1
orders=3
order_items=3
order_fulfillments=1
pay_transactions=3
pay_notify_logs=0
pay_reconcile_tasks=3
pay_refunds=0
user_wallets=1
wallet_transactions=1
```

支付渠道表名是 `pay_channel`，不是 `pay_channels`。Go model 必须显式 `TableName() string { return "pay_channel" }`。

## 非目标

本阶段明确不做：

- 真实支付 SDK 接入
- `recharge/createPay/queryResult/cancelOrder`
- 支付回调 `/api/pay/notify/*`
- 钱包调账
- 订单关闭/备注
- 支付流水写入
- 履约 worker
- 对账任务执行、下载、重试
- 新增支付表结构
- 批量迁移 `src/api/pay/*`

## 开源优先取舍

### 支付 SDK

后续真实支付 runtime 不应手写微信/支付宝协议。候选：

- `github.com/go-pay/gopay`：聚合微信、支付宝等多支付方式，适合快速统一封装。
- `github.com/wechatpay-apiv3/wechatpay-go`：微信支付官方 Go SDK，适合微信链路严肃落地。
- `github.com/smartwalle/alipay`：支付宝 Go SDK 候选。

本阶段只做渠道配置 CRUD，不调用 SDK。原因：配置 CRUD 的真问题是后台管理和密钥安全，不是第三方协议。

### 密钥加密

继续复用本项目已经存在的：

```text
admin_back_go/internal/platform/secretbox
```

支付渠道 `app_private_key` 写入时用 `VAULT_KEY` 加密保存到 `app_private_key_enc`；响应只返回 `app_private_key_hint`，永不返回明文和密文。

## Go 后端设计

### 模块边界

新增模块：

```text
admin_back_go/internal/module/paychannel
```

职责只包括 `pay_channel` 后台配置管理。

文件边界：

```text
route.go       注册 /api/admin/v1/pay-channels 路由
handler.go     HTTP bind/query/param，调用 service，返回 response
request.go     request structs + binding tags
service.go     支付渠道业务规则、secretbox 加密、支持方式归一化
repository.go  GORM 查询、事务、唯一性检查、软删除、状态切换
model.go       pay_channel 表映射
dto.go         service input/output DTO
errors.go      模块错误，如渠道不存在、重复配置、密钥缺失
```

没有 SDK client，没有 payment runtime interface。

### REST API

所有接口在：

```text
/api/admin/v1
```

#### 页面初始化

```text
GET /api/admin/v1/pay-channels/page-init
```

返回：

```json
{
  "dict": {
    "channel_arr": [
      { "label": "微信支付", "value": 1 },
      { "label": "支付宝", "value": 2 }
    ],
    "common_status_arr": [
      { "label": "启用", "value": 1 },
      { "label": "禁用", "value": 2 }
    ],
    "pay_method_arr": [
      { "label": "PC网页支付", "value": "web" },
      { "label": "H5支付", "value": "h5" },
      { "label": "APP支付", "value": "app" },
      { "label": "小程序支付", "value": "mini" },
      { "label": "扫码支付", "value": "scan" },
      { "label": "公众号支付", "value": "mp" }
    ]
  }
}
```

#### 列表

```text
GET /api/admin/v1/pay-channels?current_page=1&page_size=20&name=&channel=&status=
```

返回沿用项目分页结构：

```json
{
  "list": [
    {
      "id": 1,
      "name": "支付宝沙箱",
      "channel": 2,
      "channel_name": "支付宝",
      "supported_methods": ["web", "scan"],
      "supported_methods_text": "PC网页支付 / 扫码支付",
      "mch_id": "xxx",
      "app_id": "xxx",
      "notify_url": "",
      "app_private_key_hint": "****abcd",
      "public_cert_path": "",
      "platform_cert_path": "",
      "root_cert_path": "",
      "sort": 0,
      "is_sandbox": 1,
      "is_sandbox_text": "是",
      "status": 1,
      "status_name": "启用",
      "remark": "",
      "created_at": "2026-05-05 12:00:00"
    }
  ],
  "page": {
    "page_size": 20,
    "current_page": 1,
    "total_page": 1,
    "total": 1
  }
}
```

#### 新增

```text
POST /api/admin/v1/pay-channels
```

Body：

```json
{
  "name": "支付宝沙箱",
  "channel": 2,
  "supported_methods": ["web", "scan"],
  "mch_id": "xxx",
  "app_id": "xxx",
  "notify_url": "https://example.test/api/pay/notify/alipay",
  "app_private_key": "-----BEGIN PRIVATE KEY-----...",
  "app_private_key_hint": "alipay-sandbox",
  "public_cert_path": "",
  "platform_cert_path": "",
  "root_cert_path": "",
  "sort": 0,
  "is_sandbox": 1,
  "status": 1,
  "remark": ""
}
```

规则：

- `name` 必填，1-50。
- `channel` 必须是 Go enum 支持的支付渠道。
- `supported_methods` 必须非空，且全部属于当前 `channel` 支持范围。
- `mch_id` 必填，1-64。
- `app_id` 可空，最长 64。
- `notify_url` 可空，最长 512。本阶段不强制 URL 格式，避免本地 mock 和内网地址被误杀。
- `app_private_key` 有值时必须配置 `VAULT_KEY`，否则返回显式配置错误。
- 唯一性：`channel + mch_id + app_id` 在未删除记录中唯一。

#### 更新

```text
PUT /api/admin/v1/pay-channels/:id
```

Body 与新增一致，但 `app_private_key` 可为空。为空表示不更新私钥，不清空旧私钥。

规则：

- 切换 `channel` 时，必须提交新的 `supported_methods`。
- 如果提交 `supported_methods`，必须按新/当前渠道校验。
- 不返回明文私钥。

#### 状态切换

```text
PATCH /api/admin/v1/pay-channels/:id/status
```

Body：

```json
{ "status": 1 }
```

规则：

- status 只能是 `1=启用` 或 `2=禁用`。
- 本阶段不做“同渠道只能启用一个”的互斥规则，因为 legacy 当前没有该规则；不要为想象中的完美支付系统改业务语义。

#### 删除

```text
DELETE /api/admin/v1/pay-channels/:id
```

规则：

- 软删除：`is_del=1`。
- 本阶段不允许批量 delete body。批量删除如果未来需要，单独设计 `POST /api/admin/v1/pay-channels/batch-delete` 或逐个 DELETE，不偷塞 `id: number | number[]`。
- 如果该渠道已被订单或交易引用，第一期建议拒绝删除，只允许禁用。原因：支付渠道是审计事实，删除会影响历史订单解释。

### 权限和操作日志

保留既有权限 code：

```text
pay_channel_add
pay_channel_edit
pay_channel_del
pay_channel_status
```

建议路由元数据：

```text
POST   /api/admin/v1/pay-channels             permission=pay_channel_add     operation=新增支付渠道
PUT    /api/admin/v1/pay-channels/:id         permission=pay_channel_edit    operation=编辑支付渠道
PATCH  /api/admin/v1/pay-channels/:id/status  permission=pay_channel_status  operation=切换支付渠道状态
DELETE /api/admin/v1/pay-channels/:id         permission=pay_channel_del     operation=删除支付渠道
```

列表和 page-init 只需要页面权限 `pay_channel_list` 或按当前 PermissionCheck 的页面访问策略走，不记录 operation log。

操作日志敏感字段要求：

- `app_private_key`
- `app_private_key_enc`
- 后续所有证书密钥字段

都必须被 mask。当前 operation log 已遮蔽 `secret/key/token/password` 类字段，但本阶段要补测试证明 `app_private_key` 会被遮蔽；如果不遮蔽，就先修 operationlog，不要带着泄密风险迁支付。

### enum/dict/validate

新增：

```text
admin_back_go/internal/enum/pay.go
```

核心常量：

```go
const (
    PayChannelWechat = 1
    PayChannelAlipay = 2
)

const (
    PayMethodWeb  = "web"
    PayMethodH5   = "h5"
    PayMethodApp  = "app"
    PayMethodMini = "mini"
    PayMethodScan = "scan"
    PayMethodMP   = "mp"
)
```

Go 侧必须提供：

```go
IsPayChannel(value int) bool
IsPayMethod(value string) bool
PayDefaultSupportedMethods(channel int) []string
NormalizePaySupportedMethods(channel int, methods []string) []string
PaySupportedMethodsValid(channel int, methods []string) bool
```

新增 dict：

```text
PayChannelOptions()
PayMethodOptions()
PayMethodOptionsForChannel(channel int)
```

新增 validate tag：

```text
pay_channel
pay_method
```

数组项校验可在 service 做，因为 `supported_methods` 需要依赖 `channel`，不是单字段 validator 能好看解决的问题。

## 前端设计

### API client

改：

```text
admin_front_ts/src/api/pay/channel.ts
```

从 `legacyRequest` 改为 `request`：

```text
GET    /api/admin/v1/pay-channels/page-init
GET    /api/admin/v1/pay-channels
POST   /api/admin/v1/pay-channels
PUT    /api/admin/v1/pay-channels/:id
PATCH  /api/admin/v1/pay-channels/:id/status
DELETE /api/admin/v1/pay-channels/:id
```

类型要求：

- 移除 `extends Record<string, unknown>`。
- 移除 `params?: Record<string, unknown>`。
- 不使用 `any / as any / Record<string, any>`。
- 删除接口 `PayChannelDeleteParams { id: number | number[] }`，新接口只删单个 id。

### 页面和 composable

优先不改视觉。只改：

- API 方法名适配：`init/list/add/edit/del/status` 可以保留在 client facade 里，避免大改页面；但内部必须走 REST。
- 删除动作若页面支持多选，需要本阶段收敛为逐个 DELETE 或禁用批量入口。不得把 `id[]` 偷塞给 DELETE body。
- 支付方式选择仍按当前 UI，但 options 从 Go dict 来。

### mock 参数回归

用户提到的 “mock 参数” 本阶段理解为：不要因为迁 Go API 破坏前端/本地测试中的支付配置 mock shape。

回归重点：

- `PayChannelApi.init()` 返回 `dict.channel_arr/common_status_arr/pay_method_arr`。
- `PayChannelApi.list()` 返回 `{ list, page }`。
- `supported_methods` 是 `string[]`。
- `supported_methods_text` 是展示文本。
- 响应不含 `app_private_key` 和 `app_private_key_enc`。

## 数据库和事务

本阶段不改表结构。

写操作：

- create/update/status/delete 都是单表写，可不强行套事务。
- 如果更新涉及 `app_private_key` 加密失败，必须在 repository 写入前失败。
- delete 需要先查引用：`orders.channel_id` 或 `pay_transactions.channel_id` 命中则拒绝删除。

后续钱包调账、充值入账、订单状态切换必须用事务，不在本阶段实现。

## 测试策略

### Backend unit tests

新增测试包：

```text
admin_back_go/internal/enum/pay_test.go
admin_back_go/internal/dict/pay_test.go
admin_back_go/internal/validate/pay_test.go
admin_back_go/internal/module/paychannel/service_test.go
admin_back_go/internal/module/paychannel/repository_test.go 或 handler_test.go
```

必须覆盖：

- 支付渠道 enum 顺序稳定。
- 支付方式 enum 顺序稳定。
- 微信/支付宝支持方式校验。
- `supported_methods` 去重、过滤、保序。
- 不支持的支付方式被拒绝。
- 重复 `channel+mch_id+app_id` 被拒绝。
- 切换渠道但没提交 `supported_methods` 被拒绝。
- 没 `VAULT_KEY` 时提交 `app_private_key` 失败。
- 返回 DTO 不含私钥明文/密文。
- 被订单/流水引用的渠道拒绝删除。

### Backend route/bootstrap tests

覆盖：

- `/api/admin/v1/pay-channels` 路由存在。
- mutating route 有 permission + operation log metadata。
- operation log 对 `app_private_key` 遮蔽。

### Frontend tests

新增/修改 Vitest：

```text
admin_front_ts/tests/shared/pay/pay-channel-api.test.ts
```

覆盖 REST method/path：

- `init` -> `GET /api/admin/v1/pay-channels/page-init`
- `list` -> `GET /api/admin/v1/pay-channels` with query params
- `add` -> `POST /api/admin/v1/pay-channels`
- `edit` -> `PUT /api/admin/v1/pay-channels/:id`
- `status` -> `PATCH /api/admin/v1/pay-channels/:id/status`
- `del` -> `DELETE /api/admin/v1/pay-channels/:id`

### Smoke

扩展 full smoke，不扩展 basic smoke：

```text
GET /api/admin/v1/pay-channels/page-init
GET /api/admin/v1/pay-channels
```

可选写入 probe：只有在 `VAULT_KEY` 存在且显式 smoke 参数允许时，创建一条 disabled sandbox temp channel，然后删除；默认不写，避免污染支付配置。

## 风险

1. 密钥泄漏风险

支付渠道的私钥比普通配置敏感。任何日志、响应、前端 detail 都不能出现明文/密文。先补遮蔽测试。

2. 删除历史渠道风险

历史订单和交易需要解释渠道名、渠道类型。被引用渠道必须拒绝删除，只能禁用。

3. 前端批量删除契约风险

legacy 支持 `id: number | number[]`，新 REST 不接受这种兜底。若页面有批量删除，必须显式逐个调用或本阶段隐藏批量删除。

4. SDK 过早引入风险

本阶段不需要任何支付 SDK。引入 SDK 只会扩大依赖和测试面。

## 实施顺序

1. 补支付 enum/dict/validate。
2. 补 operation log 对 `app_private_key` 的敏感字段遮蔽。
3. 实现 Go `paychannel` module 的 read/write REST。
4. 注册路由、权限和操作日志 metadata。
5. 更新 contract/current-status/smoke matrix。
6. 适配前端 `PayChannelApi`，最小改页面。
7. 跑 backend tests、frontend typecheck/lint/vitest、full smoke read-only probe。

## Definition of Done

- Go 后端存在 `paychannel` 模块且只负责支付渠道管理。
- `/api/admin/v1/pay-channels/*` 契约写进 `docs/contracts/admin-api-v1.md`。
- 前端支付渠道页面不再走 legacy PHP。
- 支付 enum/dict/validate 由 Go 统一提供。
- operation log 不泄露 `app_private_key`。
- 被引用渠道不能删除。
- full smoke 有只读支付渠道探针。
- 没有新增 `any / as any / Record<string, any>`。
- 未接真实支付 SDK，未触碰充值/回调/钱包调账。
