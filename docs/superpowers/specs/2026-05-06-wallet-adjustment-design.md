# Wallet Adjustment Write Path Design

状态：ready for implementation plan。本 spec 只设计后台钱包调账写路径，不直接实现代码。

## Linus 三问

1. 真问题：是。后台钱包 read-only 已迁到 Go，但真正动钱的 `UserWallet/adjust` 仍在 legacy PHP；它是资金余额变更入口，不能长期留在全 POST、无明确事务边界、无幂等键的旧路径里。
2. 更简单做法：只做一个资源创建接口 `POST /api/admin/v1/wallet-adjustments`。不新建 `wallet_adjustments` 表，不引入队列，不重做钱包域模型；直接用现有 `wallet_transactions.uk_biz_action_no` 做幂等事实源。
3. 会破坏什么：不能破坏当前钱包列表、流水弹窗、调账按钮、RBAC、操作日志和测试账号余额。实现必须保留用户界面行为，但把前端调账从 explicit legacy adapter 切到 Go REST；full smoke 必须用正负两笔调账恢复余额。

## Current Context

已完成上一刀：

```text
GET /api/admin/v1/wallets/page-init
GET /api/admin/v1/wallets
GET /api/admin/v1/wallet-transactions
```

当前显式遗留边界：

```ts
LegacyWalletAdjustmentApi.create -> POST /api/admin/UserWallet/adjust
```

本刀目标是删除这个遗留边界，迁到：

```text
POST /api/admin/v1/wallet-adjustments
```

## Scope

本刀只做后台人工调账：

```text
管理员选择用户
填写正负调整金额
填写必填原因
前端生成 idempotency_key
Go 后端在一个 DB transaction 内创建/锁定钱包、更新余额、插入钱包流水
返回流水 ID、幂等业务号、余额 before/after
记录 OperationLog
full smoke 做 +100 / duplicate / -100 恢复
```

## Non-scope

不做：

```text
用户侧钱包查询 /api/app/v1/wallet*
充值下单
支付回调入账
订单消费扣款
提现
冻结/解冻
退款
对账执行
钱包事件队列
新建 wallet_adjustments 表
数据权限模型扩展
多币种
金额单位从分改元
```

## Legacy Facts

Legacy route：

```text
POST /api/admin/UserWallet/adjust -> UserWalletModule::adjust
```

Legacy 入参：

```php
'user_id' => v::intVal()->positive()->setName('用户ID')
'delta'   => v::intVal()->setName('调整金额')
'reason'  => v::optional(v::stringType()->length(0, 255))->setName('调账原因')
```

Legacy 行为：

```text
getOrCreateWallet(user_id)
delta < 0 时先检查 balance >= abs(delta)
adjustBalance(wallet_id, version, delta)
插入 wallet_transactions
biz_action_no = WALLET:ADJUST:{timestamp}:{rand}
type = 3 系统调账
source_type = 2 人工
operator_id = request.userId
```

Legacy 明显问题：

```text
钱包更新和流水插入没有明确的一体化 DB transaction。
biz_action_no 是时间 + 随机数，不支持客户端重试幂等。
reason 允许空，资金审计质量差。
调账接口是 action path，不是新 Go REST 资源。
```

Go rewrite 必须修掉这些问题，而不是逐行复制旧代码。

## REST Contract

### Create Wallet Adjustment

```text
POST /api/admin/v1/wallet-adjustments
```

Auth：bearer token + `pay_wallet_adjust`。

OperationLog：required。

```text
module = pay_wallet
action = adjust
title  = 钱包调账
```

Request body：

```ts
interface WalletAdjustmentCreateBody {
  user_id: number
  delta: number
  reason: string
  idempotency_key: string
}
```

Rules：

```text
user_id 必须 > 0。
delta 是 signed cents，不能为 0。
reason trim 后必须 1..255 个字符。新接口不继承 legacy 的空原因。
idempotency_key 必填，trim 后 8..50 字符，只允许 A-Z a-z 0-9 _ - : .。
50 是数据库边界：`wallet_transactions.biz_action_no` 是 varchar(64)，前缀 `WALLET:ADJUST:` 占 14。
前端第一版使用 crypto.randomUUID() 生成 UUID。
如果浏览器没有 crypto.randomUUID，前端显式报错，不生成伪随机兜底。
```

Response data：

```ts
interface WalletAdjustmentCreateResponse {
  transaction_id: number
  biz_action_no: string
  balance_before: number
  balance_after: number
}
```

Success examples：

```json
{
  "code": 0,
  "data": {
    "transaction_id": 123,
    "biz_action_no": "WALLET:ADJUST:550e8400-e29b-41d4-a716-446655440000",
    "balance_before": 1000,
    "balance_after": 1100
  },
  "msg": "ok"
}
```

Error rules：

```text
用户ID无效 -> code=100, msg=无效的用户ID
调整金额为0 -> code=100, msg=调整金额不能为0
调账原因为空/超长 -> code=100, msg=调账原因不能为空且不能超过255个字符
幂等键非法 -> code=100, msg=幂等键格式错误
可用余额不足 -> code=100, msg=可用余额不足，无法调减
同幂等键不同请求 -> code=100, msg=幂等键已被不同请求使用
用户不存在 -> code=404, msg=用户不存在
数据库异常 -> code=500, msg=钱包调账失败
```

## Data and Idempotency Design

不新建表。幂等事实源直接使用现有唯一索引：

```text
wallet_transactions.uk_biz_action_no
```

业务号生成：

```text
biz_action_no = WALLET:ADJUST:{idempotency_key}
```

`wallet_transactions.ext` 写入用于幂等 payload 比对：

```json
{
  "idempotency_key": "550e8400-e29b-41d4-a716-446655440000",
  "reason": "人工修正余额",
  "delta": 100,
  "user_id": 7,
  "operator_id": 1
}
```

幂等规则：

```text
1. transaction 开始后先按 biz_action_no 查询 wallet_transactions.is_del=2。
2. 如果存在，解析 ext 并比对 user_id/delta/reason/idempotency_key。
3. 完全一致：返回已有流水的 transaction_id/biz_action_no/balance_before/balance_after，不再次更新钱包。
4. 不一致：返回 code=100 幂等键已被不同请求使用。
5. 如果不存在：继续创建本次调账。
6. 如果并发插入时撞上 uk_biz_action_no：重新查询同 biz_action_no，再按同样规则处理；不能让用户看到 MySQL duplicate key 原文。
```

## Transaction and Concurrency Design

仓储提供单个写事务方法，不把事务散落在 service：

```go
type Repository interface {
    ...read methods...
    CreateAdjustment(ctx context.Context, input AdjustmentMutation) (*AdjustmentResult, error)
}
```

`CreateAdjustment` 内部使用：

```text
db.WithContext(ctx).Transaction(func(tx *gorm.DB) error { ... })
```

事务步骤：

```text
1. 查 wallet_transactions by biz_action_no + is_del=2。
2. 已存在则做幂等比对并返回。
3. 查 users by id + is_del=2；不存在返回 domain result: user not found。
4. SELECT user_wallets WHERE user_id=? AND is_del=2 FOR UPDATE。
5. 如果钱包不存在，在同一个 tx 内 create user_wallets：balance=0,frozen=0,total_recharge=0,total_consume=0,version=0,is_del=2。
6. 对负数 delta，检查 locked wallet.balance >= abs(delta)。
7. UPDATE user_wallets SET balance = balance + delta, version = version + 1, updated_at=now WHERE id=? AND version=? AND is_del=2；负数同时追加 balance >= abs(delta)。
8. RowsAffected=0 视为版本冲突或余额不足，返回业务错误。
9. INSERT wallet_transactions。
10. commit。
```

锁策略：

```go
Clauses(clause.Locking{Strength: "UPDATE"})
```

为什么还保留 version guard：

```text
FOR UPDATE 负责串行化同钱包写入，version guard 负责防止脏状态或未来非锁定写路径绕过。
这不是过度设计；钱包余额是资金事实源，双保险比“靠运气没并发”好。
```

余额规则：

```text
delta > 0: balance 增加，version + 1。
delta < 0: balance 减少，但不能低于 0，version + 1。
total_recharge 不变。
total_consume 不变。
frozen 不变。
```

## Backend Boundaries

模块仍然是：

```text
admin_back_go/internal/module/wallet
```

新增/修改职责：

```text
request.go      createAdjustmentRequest，HTTP binding tag
handler.go      解析 JSON + AuthIdentity，调用 service，不碰 DB
service.go      normalize/validate input，调用 repository，映射业务错误
repository.go   单事务调账，FOR UPDATE，幂等查询/插入
model.go        复用 UserWallet / WalletTransaction；如需 User 最小模型，只放本模块私有字段
errors.go       调账领域 sentinel errors
route.go        POST /api/admin/v1/wallet-adjustments
```

handler 身份提取：

```go
identity := middleware.GetAuthIdentity(c)
```

handler 只把 `operator_id` 放进 service input：

```go
CreateAdjustmentInput{OperatorID: identity.UserID, ...}
```

service 禁止依赖 `gin.Context`。

repository 禁止决定 HTTP code/msg，只返回领域错误或结果。

## Frontend Design

修改：

```text
admin_front_ts/src/api/pay/wallet.ts
admin_front_ts/src/views/Main/pay/wallet/components/WalletAdjustDialog.vue
admin_front_ts/tests/shared/pay/wallet-api.test.ts
```

删除：

```ts
LegacyWalletAdjustmentApi
```

新增类型：

```ts
export interface WalletAdjustmentCreatePayload {
  user_id: number
  delta: number
  reason: string
  idempotency_key: string
}

export interface WalletAdjustmentCreateResponse {
  transaction_id: number
  biz_action_no: string
  balance_before: number
  balance_after: number
}
```

新增 API：

```ts
export const WalletAdjustmentApi = {
  create: (payload: WalletAdjustmentCreatePayload) =>
    request.post<WalletAdjustmentCreateResponse, WalletAdjustmentCreatePayload>(`${ADMIN_API_PREFIX}/wallet-adjustments`, payload),
}
```

`WalletAdjustDialog.vue`：

```text
reason 改为必填，max=255。
delta 校验不能为 0。
submit 时把元转换为分：Math.round(delta * 100)。
每次提交生成一个 idempotency_key。
如果 crypto.randomUUID 不存在，ElNotification.error 明确提示“当前浏览器不支持安全幂等键生成，请升级浏览器”，不请求后端。
成功后关闭弹窗并刷新列表。
不加确认二次弹窗，不改变现有交互骨架。
```

## Permission and Operation Log

权限 metadata：

```text
POST /api/admin/v1/wallet-adjustments -> pay_wallet_adjust
```

操作日志 metadata：

```text
POST /api/admin/v1/wallet-adjustments -> module=pay_wallet, action=adjust, title=钱包调账
```

OperationLog 当前会捕获 request/response 摘要。本接口无密码、token、验证码答案，但仍禁止记录 auth token；这由已有 middleware 规则负责。

## Tests

Backend unit tests：

```text
service rejects invalid user_id
service rejects delta=0
service rejects blank/too-long reason
service rejects bad idempotency_key
service maps insufficient balance to code=100
service maps idempotency conflict to code=100
service returns existing transaction for duplicate same payload
repository transaction creates wallet when missing
repository transaction updates existing wallet and inserts wallet_transactions
repository negative delta cannot overdraw
handler requires auth identity
handler binds JSON and passes operator_id
route metadata has permission + operation rule
```

Repository DB tests can use sqlmock-style unit boundaries only if current project already has such setup. If not, keep repository transaction covered by focused GORM tests only where practical and rely on full smoke for real MySQL end-to-end. Do not add a heavy new DB test harness in this slice.

Frontend tests：

```text
WalletAdjustmentApi uses POST /api/admin/v1/wallet-adjustments
No /api/admin/UserWallet/adjust remains in wallet touched files
WalletAdjustDialog uses crypto.randomUUID and idempotency_key
Touched wallet files contain no any/as any/Record<string, any>
```

Smoke：

```text
1. Login and run existing wallet read probes.
2. Pick a wallet row from GET /wallets. If no wallet exists, skip with skipped_no_wallet_rows.
3. Save original balance.
4. POST +100 cents with idempotency_key A and reason codex-full-smoke-adjust-plus-{timestamp}.
5. Verify code=0, balance_after=original+100.
6. POST the exact same body again.
7. Verify same transaction_id and wallet balance is still original+100.
8. POST -100 cents with idempotency_key B.
9. Verify final wallet balance equals original.
10. Query wallet-transactions for user_id and verify both biz_action_no values appear.
11. Query operation-logs action=钱包调账 and verify a new log exists after beforeMaxID.
```

如果第 8 步恢复失败：

```text
smoke 必须输出 wallet_adjustment_restore_failed=true，并保留 .tmp 日志。
不要假装通过。
```

## Documentation Updates Required During Implementation

```text
docs/contracts/admin-api-v1.md
docs/migration/current-status.md
docs/testing/smoke-matrix.md
admin_back_go/docs/architecture.md
```

文档口径：

```text
wallet admin adjustment = implemented only after backend + frontend + smoke all pass。
LegacyWalletAdjustmentApi 删除后，current-status 不再说调账仍是 legacy。
```

## Exit Criteria

```text
POST /api/admin/v1/wallet-adjustments 可用，且受 pay_wallet_adjust 权限保护。
调账写入 wallet 和 wallet_transactions 在同一个 DB transaction 内完成。
同 idempotency_key 重试不重复加减余额。
同 idempotency_key 不同 payload 被拒绝。
负数调账不能把余额扣成负数。
前端钱包调账不再调用 legacy PHP。
OperationLog 能看到“钱包调账”。
full smoke 能 +100、重复请求、-100 恢复余额。
Go tests/vet、contract gate、frontend vitest/vue-tsc/eslint、git diff --check 通过。
```

## Self-review

```text
无 TBD/TODO。
没有新建表，避免不必要 schema 扩张。
没有把 legacy /UserWallet/adjust 搬进 Go。
没有 PATCH /wallets/:id/adjust 动作接口。
资金写路径明确 transaction、FOR UPDATE、version guard、幂等、operation log。
前端没有 silent fallback；crypto.randomUUID 不存在时显式失败。
```
