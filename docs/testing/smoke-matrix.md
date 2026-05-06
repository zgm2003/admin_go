# Admin Smoke Matrix

状态更新时间：2026-05-06

本文是 smoke 覆盖地图，不是接口契约。接口契约看 `docs/contracts/admin-api-v1.md`。

## Smoke levels

| Level | Script | Purpose | Runtime target | Writes DB | Cleanup |
| --- | --- | --- | --- | --- | --- |
| Basic smoke | `admin_back_go/scripts/basic-admin-smoke.ps1` | 证明 admin 基础启动链路没断 | 快，适合每个核心改动后跑 | yes | yes |
| Full smoke | `admin_back_go/scripts/full-admin-smoke.ps1` | 在 basic 基础上增加更慢的核心模块端到端检查 | 慢，适合阶段收口前跑 | yes | yes |

完整测试策略看 `docs/testing/test-strategy.md`。本文件只记录 smoke 覆盖矩阵。

## Current matrix

| Area | Basic smoke | Full smoke | API coverage | Mutation | Cleanup rule | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| readiness | yes | via basic | `GET /ready` with database/redis/token_redis/queue_redis/realtime checks | no | n/a | 证明 MySQL/Redis/QueueRedis/Realtime readiness shape；dependency detail 属于 readiness，不属于 health |
| login config | yes | via basic | `GET /api/admin/v1/auth/login-config` | no | n/a | 断言登录方式顺序是 `email,phone,password` |
| verify code login | yes | via basic | `POST /api/admin/v1/auth/send-code`, `POST /api/admin/v1/auth/login` | login session | logout | 使用 dev code，不接真实短信/邮件 |
| slide captcha login | yes | via basic + full own login | `GET /api/admin/v1/auth/captcha`, `POST /api/admin/v1/auth/login` | login session | logout | 自动读取本次 challenge 的 Redis 答案，不绕过验证码 |
| login log queue | yes | via basic | `users_login_log` recent count | yes | no cleanup | 证明 auth queue/worker 或同步兜底路径可用 |
| users bootstrap | yes | via basic | `GET /api/admin/v1/users/me`, `GET /api/admin/v1/users/init` | no | n/a | 验证 router/buttonCodes |
| users management read | yes | via basic | `GET /api/admin/v1/users/page-init`, `GET /api/admin/v1/users` | no | n/a | 验证用户管理页 Go REST read path |
| profile + avatar first upload slice | no | yes | `GET /api/admin/v1/profile`, `GET /api/admin/v1/users/:id/profile`, `PUT /api/admin/v1/profile`, avatar upload token via shared client contract | harmless self-update of same values | n/a | full smoke 读取 profile shape，PUT 原值证明路由/operation log；真实头像直传仍由前端上传 token flow 负责 |
| account security writes | no | failure probes only | `PUT /api/admin/v1/profile/security/password`, `PUT /api/admin/v1/profile/security/email`, `PUT /api/admin/v1/profile/security/phone` | no successful mutation | n/a | full smoke 只验证错误旧密码/错误邮箱验证码/错误手机号验证码返回 `code=100`，不修改真实测试账号密码、手机号、邮箱 |
| auth platform read | yes | via basic | `GET /api/admin/v1/auth-platforms/init`, `GET /api/admin/v1/auth-platforms` | no | n/a | 验证 captcha dict 存在 |
| notifications current-user read | no | yes | `GET /api/admin/v1/notifications/init`, `GET /api/admin/v1/notifications`, `GET /api/admin/v1/notifications/unread-count` | no | n/a | full smoke 只探测字典、分页 shape、未读数 shape；不标记已读/删除真实通知，避免改变测试账号状态 |
| notification task publish read | no | yes | `GET /api/admin/v1/notification-tasks/init`, `GET /api/admin/v1/notification-tasks/status-count`, `GET /api/admin/v1/notification-tasks` | no | n/a | full smoke 只探测发布任务字典、状态统计、分页 shape；不创建通知任务，避免给测试/真实用户发送垃圾通知 |
| permission + role RBAC loop | yes | via basic | permissions create/delete, role update/restore, users/init | yes | delete temp permissions; restore role | 临时 DIR/PAGE/BUTTON 必须清掉 |
| system log read-only | no | yes, lines conditional | `GET /api/admin/v1/system-logs/init`, `GET /api/admin/v1/system-logs/files`, `GET /api/admin/v1/system-logs/files/:name/lines` | no | n/a | full smoke 探测 init/files shape；当文件列表非空时读取第一份日志 tail lines；不做删除/清空/下载日志 |
| system settings read | no | yes | `GET /api/admin/v1/system-settings/init`, `GET /api/admin/v1/system-settings` | no | n/a | full smoke 只探测 init/list shape；旧 `devtools_queue_monitor_queues` 清理由迁移脚本/人工执行，不在 smoke 里做写库删除 |
| upload config read | no | yes | `GET /api/admin/v1/upload-drivers/init`, `GET /api/admin/v1/upload-drivers`, `GET /api/admin/v1/upload-rules/init`, `GET /api/admin/v1/upload-rules`, `GET /api/admin/v1/upload-settings/init`, `GET /api/admin/v1/upload-settings` | no | n/a | full smoke 必须始终探测三类配置 init/list shape；不触发云 SDK |
| upload config write probe | no | gated yes | `POST/DELETE upload-drivers`, `POST/DELETE upload-rules`, `POST/DELETE upload-settings` | yes, only disabled temp rows | delete setting -> rule -> driver | 只有 VAULT_KEY 存在时执行；永远不启用临时 setting，不修改现有 enabled setting；VAULT_KEY 空时 summary 输出 skipped_no_vault_key；不安装/调用 OSS SDK |
| upload token shape | no | gated yes | `POST /api/admin/v1/upload-tokens` | token only | n/a | `COS_STS_ENABLED=false` 时 summary 输出 skipped_cos_sts_disabled；启用时只校验 provider/key/credentials shape，永远不上传真实文件 |
| pay channel read | no | yes | `GET /api/admin/v1/pay-channels/page-init`, `GET /api/admin/v1/pay-channels` | no | n/a | full smoke 只探测支付渠道字典、分页 shape、supported_methods 展示字段和私钥不泄漏；不创建/修改真实支付配置，不触发支付 SDK |
| pay runtime minimal closure | no | default read-only + optional write | default checks enabled Alipay channel cert path/private-key non-leak, `GET /api/admin/v1/wallet/summary`, `GET /api/admin/v1/wallet/bills`, `GET /api/admin/v1/recharge-orders`; optional `POST /api/admin/v1/recharge-orders`, `POST /api/admin/v1/recharge-orders/:order_no/pay-attempts`, `GET /api/admin/v1/recharge-orders/:order_no/result`, `PATCH /api/admin/v1/recharge-orders/:order_no/cancel` | optional creates sandbox recharge order + waiting transaction, then closes the local smoke order | optional cancel cleanup for the smoke order; no payment/callback cleanup because no real sandbox payment is executed | default full smoke 不创建真实充值单，只探测个人钱包页运行时读接口；传 `-EnablePaymentRuntimeProbe` 才发起支付宝 sandbox 支付尝试、校验 `pay_data.content`/本地查询 shape 并取消 smoke 订单；支付宝付款和 notify 入账是手动 sandbox e2e，不冒充自动 smoke |
| pay transaction read | no | yes | `GET /api/admin/v1/pay-transactions/page-init`, `GET /api/admin/v1/pay-transactions`, `GET /api/admin/v1/pay-transactions/:id` when row exists | no | n/a | full smoke 只探测支付流水字典、分页 shape、详情 shape、channel_resp/raw_notify JSON object shape 和支付渠道私钥不泄漏；不发起支付、不重试回调、不改钱包、不跑对账 |
| pay order admin management | no | yes | `GET /api/admin/v1/pay-orders/page-init`, `GET /api/admin/v1/pay-orders/status-count`, `GET /api/admin/v1/pay-orders`, `GET /api/admin/v1/pay-orders/:id` when row exists, `PATCH /api/admin/v1/pay-orders/:id/remark`, conditional `PATCH /api/admin/v1/pay-orders/:id/close` | yes, remark restore; close only when pending/paying row exists | remark restores original value; close is irreversible and therefore skipped unless fixture row is already pending/paying | full smoke 探测后台订单字典、状态统计、分页、详情、备注写入恢复；close 只验证 Go local-close 边界，不调用第三方 SDK、不查单、不改钱包 |
| wallet admin read + adjustment | no | yes | `GET /api/admin/v1/wallets/page-init`, `GET /api/admin/v1/wallets`, `GET /api/admin/v1/wallet-transactions`, `POST /api/admin/v1/wallet-adjustments` | yes, `+100 / duplicate / -100 restore` when a wallet row exists | final wallet balance equals original; duplicate must return same transaction id | full smoke 探测后台钱包字典、分页、流水分页 shape；如果存在钱包行，执行调账正向、重复幂等、反向恢复，并等待 `钱包调账` 操作日志；不触发支付 SDK |
| operation log read/delete | no | yes | `GET /api/admin/v1/operation-logs/init`, `GET /api/admin/v1/operation-logs`, `DELETE /api/admin/v1/operation-logs/:id` | yes | delete temp operation log row; delete temp permission | full 先创建临时权限触发 `新增权限` 操作日志，再删除该日志 |
| queue health | yes | via basic | `auth:login-log:v1` worker path or sync fallback evidence | yes | no cleanup | 当前以 login log 近 5 分钟记录证明 queue/worker 或显式同步策略可用 |
| scheduler business dispatch | no | unit tests | `notification-task-dispatch-due` -> `notification:dispatch-due:v1` -> `notification:send-task:v1` | no in smoke | n/a | 调度器不放进 smoke 写路径；用 `go test ./internal/module/notificationtask ./internal/jobs ./internal/bootstrap` 证明 scheduler 只 enqueue，handler 才 claim DB/send |
| queue monitor read-only | no | yes | `GET /api/admin/v1/queue-monitor`, `GET /api/admin/v1/queue-monitor/failed`, `HEAD /api/admin/v1/queue-monitor-ui` | no | n/a | full smoke 只探测只读 JSON 摘要、失败任务分页 shape 和 asynqmon UI 可访问性，不做 retry/delete/clear |
| realtime WebSocket connect/heartbeat | yes | via basic | `GET /api/admin/v1/realtime/ws`, `realtime.connected.v1`, `realtime.ping.v1`, `realtime.pong.v1` | local session register/cleanup only | client closes socket | 证明 AuthToken 后的 WebSocket upgrade、项目 envelope、ping/pong 和 bounded session pump 没断；browser cookie auth、topic 白名单、`REALTIME_ENABLED=false` 503、Publisher local/noop、Vue URL/envelope cleanup 走单元/Vitest，不放 basic smoke；fan-out 走单元测试，不测 AI |

## Non-smoke gates

有些基建不应该硬塞进 smoke。队列/调度器/worker 的第一层验证走单元测试和进程边界检查：

```powershell
go test ./internal/platform/taskqueue ./internal/platform/scheduler ./internal/jobs ./internal/bootstrap
go test ./internal/module/queuemonitor ./internal/platform/taskqueue ./internal/server ./internal/bootstrap
```

当前覆盖：

```text
taskqueue.Mux 已注册 handler 可以处理 project task
未知 task type 必须显式失败，不允许静默吞掉
jobs.Register 同时注册 system:no-op:v1、auth:login-log:v1、notification:dispatch-due:v1、notification:send-task:v1
jobs.RegisterSchedules 只把 schedule trigger 转成 Enqueuer.Enqueue，不直接跑业务
notification-task-dispatch-due 只 enqueue notification:dispatch-due:v1；dispatch-due handler 才 claim 到期 notification_task 并 enqueue send-task
realtime Redis Pub/Sub fan-out 通过 `go test ./internal/platform/realtime ./internal/module/notificationtask ./internal/bootstrap` 验证，不在 smoke 发送真实通知
admin-worker 可构造 queue server + scheduler；admin-api 只持有 producer，不消费队列
```

## Commands

Run from `E:/admin_go/admin_back_go`:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\basic-admin-smoke.ps1 `
  -Account 15671628271 `
  -Password 123456
```

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 `
  -Account 15671628271 `
  -Password 123456
```

Optional payment runtime probe, only when you intentionally want to create a real sandbox recharge order and payment attempt:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 `
  -Account 15671628271 `
  -Password 123456 `
  -EnablePaymentRuntimeProbe
```

## Rules

```text
Smoke 不是单元测试，不替代 go test / vue-tsc。
Basic smoke 保持快，不随便塞慢模块。
Full smoke 可以慢，但必须每一步可解释、可清理。
任何写库 smoke 都必须使用临时数据，成功后清理，失败时保留 .tmp 日志。
Full smoke 最终只输出一个 JSON summary，方便 agent 和 CI 读取。
Release gate 不等于 full smoke；release gate 还要跑 go test/go vet/vue-tsc/build/contract check。
```

## Next candidates

```text
Do not pick an upload slice by itself. Pick the next real business module first.
If that module owns an image/file field, wire it through upload token/client inside that module.
AI agent avatar, chat attachment, and rich text image must migrate as part of their owning business modules, not as standalone upload pages.
```
