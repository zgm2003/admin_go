# Admin Smoke Matrix

状态更新时间：2026-05-05

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
| permission + role RBAC loop | yes | via basic | permissions create/delete, role update/restore, users/init | yes | delete temp permissions; restore role | 临时 DIR/PAGE/BUTTON 必须清掉 |
| system log read-only | no | yes, lines conditional | `GET /api/admin/v1/system-logs/init`, `GET /api/admin/v1/system-logs/files`, `GET /api/admin/v1/system-logs/files/:name/lines` | no | n/a | full smoke 探测 init/files shape；当文件列表非空时读取第一份日志 tail lines；不做删除/清空/下载日志 |
| system settings read | no | yes | `GET /api/admin/v1/system-settings/init`, `GET /api/admin/v1/system-settings` | no | n/a | full smoke 只探测 init/list shape；旧 `devtools_queue_monitor_queues` 清理由迁移脚本/人工执行，不在 smoke 里做写库删除 |
| upload config read | no | yes | `GET /api/admin/v1/upload-drivers/init`, `GET /api/admin/v1/upload-drivers`, `GET /api/admin/v1/upload-rules/init`, `GET /api/admin/v1/upload-rules`, `GET /api/admin/v1/upload-settings/init`, `GET /api/admin/v1/upload-settings` | no | n/a | full smoke 必须始终探测三类配置 init/list shape；不触发云 SDK |
| upload config write probe | no | gated yes | `POST/DELETE upload-drivers`, `POST/DELETE upload-rules`, `POST/DELETE upload-settings` | yes, only disabled temp rows | delete setting -> rule -> driver | 只有 VAULT_KEY 存在时执行；永远不启用临时 setting，不修改现有 enabled setting；VAULT_KEY 空时 summary 输出 skipped_no_vault_key；不安装/调用 OSS SDK |
| upload token shape | no | gated yes | `POST /api/admin/v1/upload-tokens` | token only | n/a | `COS_STS_ENABLED=false` 时 summary 输出 skipped_cos_sts_disabled；启用时只校验 provider/key/credentials shape，永远不上传真实文件 |
| operation log read/delete | no | yes | `GET /api/admin/v1/operation-logs/init`, `GET /api/admin/v1/operation-logs`, `DELETE /api/admin/v1/operation-logs/:id` | yes | delete temp operation log row; delete temp permission | full 先创建临时权限触发 `新增权限` 操作日志，再删除该日志 |
| queue health | yes | via basic | `auth:login-log:v1` worker path or sync fallback evidence | yes | no cleanup | 当前以 login log 近 5 分钟记录证明 queue/worker 或显式同步策略可用 |
| queue monitor read-only | no | yes | `GET /api/admin/v1/queue-monitor`, `GET /api/admin/v1/queue-monitor/failed`, `HEAD /api/admin/v1/queue-monitor-ui` | no | n/a | full smoke 只探测只读 JSON 摘要、失败任务分页 shape 和 asynqmon UI 可访问性，不做 retry/delete/clear |
| realtime WebSocket connect/heartbeat | yes | via basic | `GET /api/admin/v1/realtime/ws`, `realtime.connected.v1`, `realtime.ping.v1`, `realtime.pong.v1` | local session register/cleanup only | client closes socket | 证明 AuthToken 后的 WebSocket upgrade、项目 envelope、ping/pong 和 bounded session pump 没断；browser cookie auth、topic 白名单、`REALTIME_ENABLED=false` 503、Publisher local/noop、Vue URL/envelope cleanup 走单元/Vitest，不放 basic smoke；不测 fan-out/AI |

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
jobs.Register 同时注册 system:no-op:v1 和 auth:login-log:v1
jobs.RegisterSchedules 只把 schedule trigger 转成 Enqueuer.Enqueue，不直接跑业务
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
