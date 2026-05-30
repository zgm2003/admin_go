# Admin Smoke Matrix

状态更新时间：2026-05-30

本文是 smoke 覆盖地图，不是接口契约。接口契约看 `docs/contracts/admin-api-v1.md`。

当前验证摘要看 `docs/status/current-status.md`。截至 2026-05-30，channel-specific verify-code TTL 切片的 basic admin smoke 已通过；full smoke 的已知失败点是既有 upload-token 探测返回 `上传密钥不可用`，所以不能把 full smoke 记录成通过。按当前脚本顺序，该失败点位于 mail/sms、client-version、upload config read、payment/wallet、AI read/disabled-baseline 和 upload config write probe 之后。2026-05-30 local live check confirmed this is an enabled COS upload setting whose encrypted secrets cannot be decrypted with the current Docker-first `APP_SECRET`; smoke must keep failing this case until the upload driver secrets are re-entered。

Smoke 脚本默认启动临时后端/worker 进程，端口分别是 `127.0.0.1:18080`（basic）和 `127.0.0.1:18081`（full），不是 Docker-first 当前运行的 `127.0.0.1:8080`。Docker runtime readiness 仍按 `docs/deployment/local.md` 使用 `/health` 和 `/ready` 单独验证。

当前 smoke 脚本只自动导入仓库根 `admin_back_go/.env`，不会自动读取 `admin_back_go/deploy/docker-first/admin-go.env`。由于本项目本地默认不再维护仓库根 `.env`，跑 smoke 前要在当前 shell 显式提供 `MYSQL_DSN`、`REDIS_ADDR`、`APP_SECRET` 等运行 env；这不是 Docker-first readiness 的替代。

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
| verify code login | yes | via basic | `POST /api/admin/v1/auth/send-code`, `POST /api/admin/v1/auth/login` | login session | logout | 手机号验证码固定 `123456`；邮箱验证码走腾讯云 SES，basic smoke 默认用手机号账号 |
| slide captcha login | yes | via basic + full own login | `GET /api/admin/v1/auth/captcha`, `POST /api/admin/v1/auth/login`, `POST /api/admin/v1/auth/logout` | login session | logout | 自动读取本次 challenge 的 Redis 答案，不绕过验证码 |
| login log queue | yes | via basic | `users_login_log` recent count | yes | no cleanup | 证明 auth queue/worker 或同步兜底路径可用 |
| users bootstrap | yes | via basic | `GET /api/admin/v1/users/me`, `GET /api/admin/v1/users/init` | no | n/a | 验证 router/buttonCodes；client version route 必须返回 `/system/clientVersion` + `system/clientVersion` |
| AI provider/agent menu gate | yes | via basic | `GET /api/admin/v1/users/init` menu/router payload | no | n/a | users/init must not return retired goods/cine/model/agent/prompt AI menu entries; it must return the seven active AI entries `/ai/providers`, `/ai/agents`, `/ai/knowledge`, `/ai/tools`, `/ai/runs`, `/ai/chat`, and `/ai/image-playground`. Smoke clears current-user button cache before this gate so stale Redis grants do not hide DB/menu truth. |
| AI provider/agent/tool/knowledge/image config read | no | yes | `GET /api/admin/v1/ai-providers/page-init`, `GET /api/admin/v1/ai-providers`, `GET /api/admin/v1/ai-agents/page-init`, `GET /api/admin/v1/ai-agents`, `GET /api/admin/v1/ai-agents?scene=chat`, `GET /api/admin/v1/ai-agents?scene=agent_generate`, `GET /api/admin/v1/ai-agents?scene=image_generate`, `GET /api/admin/v1/ai-agents/options`, `GET /api/admin/v1/ai-agents/options?scene=image_generate`, `GET /api/admin/v1/ai-images/page-init`, `GET /api/admin/v1/ai-images`, optional `GET /api/admin/v1/ai-images/:id` when a task exists, optional `GET /api/admin/v1/ai-agents/:id/tools` when an agent option exists, optional `GET /api/admin/v1/ai-agents/:id/knowledge-bases` when an agent option exists, `GET /api/admin/v1/ai-knowledge-bases/page-init`, `GET /api/admin/v1/ai-knowledge-bases`, `GET /api/admin/v1/ai-tools/page-init`, `GET /api/admin/v1/ai-tools/generate/page-init`, `GET /api/admin/v1/ai-tools` | no | n/a | full smoke proves the provider/agent/tool/knowledge/image admin tables are Go-owned, list/init shapes are stable, provider driver is exactly `openai`, health/model-sync statuses are `unknown` / `ok` / `failed`, agent init exposes `scene_arr` with `chat` / `agent_generate` / `image_generate` and `provider_model_options`, agent options default to enabled `chat` agents and accept `scene=image_generate`, image init exposes dicts plus image agent options, tool generate init reads enabled `agent_generate` scene agents, tool init exposes only `risk_level_arr` and `common_status_arr`, agent tool configuration reads `tool_ids` + `active_tool_ids`, knowledge seed `admin_go_project_architecture` exists, agent knowledge configuration reads `bindings` + `base_options`, and retired AI resources/secret/raw/source/config fields must not leak. |
| AI conversation/run monitor disabled-baseline | no | yes | `GET /api/admin/v1/ai-conversations`, optional `GET /api/admin/v1/ai-conversations/:id/messages` shape when fixture exists, `GET /api/admin/v1/ai-runs/page-init`, `GET /api/admin/v1/ai-runs`, optional `GET /api/admin/v1/ai-runs/:id` when a run fixture exists, `GET /api/admin/v1/ai-runs/stats` | no successful mutation by default | n/a | full smoke proves conversation and token-only run-monitor read paths use the local AI schema. Run monitor status filter is `status`, stats return `avg_duration_ms`, events are lifecycle-only, and run detail returns `tool_calls` plus `knowledge_retrievals` from separate audit tables when present. Conversation send is a mutation and is covered by unit/contract tests unless an explicit live provider probe is enabled; browser chat no longer calls `/api/admin/v1/ai-chat/runs` or REST event polling. Stream timeout governance is unit-tested: live max duration, provider idle timeout, and stale-run cron cleanup are separate. Known exception: `AI-FE-001` late canceled-stream WebSocket event guard remains open and is tracked in `docs/status/known-issues.md`. |
| users management read | yes | via basic | `GET /api/admin/v1/users/page-init`, `GET /api/admin/v1/users` | no | n/a | 验证用户管理页 Go REST read path |
| user legacy closure | no | yes | `PUT /api/admin/v1/users/me/quick-entries`, `GET /api/admin/v1/users/login-logs/page-init`, `GET /api/admin/v1/users/login-logs?current_page=1&page_size=10`, `GET /api/admin/v1/user-sessions/page-init`, `GET /api/admin/v1/user-sessions?current_page=1&page_size=10`, `GET /api/admin/v1/user-sessions/stats`, `PATCH /api/admin/v1/user-sessions/:id/revoke` current-session failure probe | yes, quick-entry save only | restore original current user's quick_entry | full smoke 保存一个当前用户已有 PAGE 到 quick-entry，再恢复原值；登录日志只读 shape；会话列表继续断言 token hash 不泄漏；revoke 只验证当前 session 不能踢自己，不随机踢 live session |
| export tasks read | no | yes | `GET /api/admin/v1/export-tasks/status-count`, `GET /api/admin/v1/export-tasks?current_page=1&page_size=20` | no | n/a | full smoke 只探测当前用户导出任务状态统计和分页 shape；不触发真实导出、不等待 worker、不上传 COS |
| profile + avatar first upload slice | no | yes | `GET /api/admin/v1/profile`, `GET /api/admin/v1/users/:id/profile`, `PUT /api/admin/v1/profile`, avatar upload token via shared client contract | harmless self-update of same values | n/a | full smoke 读取 profile shape，PUT 原值证明路由/operation log；真实头像直传仍由前端上传 token flow 负责 |
| account security writes | no | failure probes only | `PUT /api/admin/v1/profile/security/password`, `PUT /api/admin/v1/profile/security/email`, `PUT /api/admin/v1/profile/security/phone`; forgot-password success is unit-tested via `POST /api/admin/v1/auth/forgot-password` | no successful mutation | n/a | full smoke 只验证错误旧密码/错误邮箱验证码/错误手机号验证码返回 `code=100`，不修改真实测试账号密码、手机号、邮箱；forgot-password 成功会改密码，所以不放默认 smoke 写路径 |
| auth platform read | yes | via basic | `GET /api/admin/v1/auth-platforms/init`, `GET /api/admin/v1/auth-platforms` | no | n/a | 验证 captcha dict 存在 |
| notifications current-user read | no | yes | `GET /api/admin/v1/notifications/init`, `GET /api/admin/v1/notifications`, `GET /api/admin/v1/notifications/unread-count` | no | n/a | full smoke 只探测字典、分页 shape、未读数 shape；不标记已读/删除真实通知，避免改变测试账号状态 |
| notification task publish read | no | yes | `GET /api/admin/v1/notification-tasks/init`, `GET /api/admin/v1/notification-tasks/status-count`, `GET /api/admin/v1/notification-tasks` | no | n/a | full smoke 只探测发布任务字典、状态统计、分页 shape；不创建通知任务，避免给测试/真实用户发送垃圾通知 |
| system cron tasks | no | yes | `GET /api/admin/v1/cron-tasks/init`, `GET /api/admin/v1/cron-tasks`, conditional `GET /api/admin/v1/cron-tasks/:id/logs` | no | n/a | full smoke probes dict/page/list/log shape and asserts `notification_task_scheduler`, `ai_run_timeout`, `payment_sync_pending_order`, and `payment_close_expired_order` return versioned Go task type handlers; payment tasks must report `payment:sync-pending-order:v1` / `payment:close-expired-order:v1`; `ai_run_timeout` must report `ai:run-timeout:v1`; `registry_status` compatibility fields must not be present. Smoke checks list shape and does not intentionally kill fresh AI replies or execute payment compensation writes. |
| permission + role RBAC loop | yes | via basic | permissions create/delete, role update/restore, users/init | yes | delete temp permissions; restore role | 临时 DIR/PAGE/BUTTON 必须清掉 |
| system log read-only | no | yes, lines conditional | `GET /api/admin/v1/system-logs/init`, `GET /api/admin/v1/system-logs/files`, `GET /api/admin/v1/system-logs/files/:name/lines` | no | n/a | full smoke 探测 init/files shape；当文件列表非空时读取第一份日志 tail lines；不做删除/清空/下载日志 |
| system settings read | no | yes | `GET /api/admin/v1/system-settings/init`, `GET /api/admin/v1/system-settings` | no | n/a | full smoke 只探测 init/list shape；旧 `devtools_queue_monitor_queues` 清理由迁移脚本/人工执行，不在 smoke 里做写库删除 |
| mail Tencent SES read | no | yes | `GET /api/admin/v1/mail/page-init`, `GET /api/admin/v1/mail/config`, `GET /api/admin/v1/mail/templates`, `GET /api/admin/v1/mail/logs` | no | n/a | full smoke only probes dict/config/template/log shapes, channel-specific `verify_code_ttl_minutes`, and encrypted secrets/template payload fields do not leak; no default real email send and no Tencent API call in smoke |
| sms Tencent Cloud read | no | yes | `GET /api/admin/v1/sms/page-init`, `GET /api/admin/v1/sms/config`, `GET /api/admin/v1/sms/templates`, `GET /api/admin/v1/sms/logs` | no | n/a | full smoke only probes dict/config/template/log shapes, channel-specific `verify_code_ttl_minutes`, and encrypted secrets, SMS body, template params, raw request, and raw response fields do not leak; no default real SMS send and no Tencent API call in smoke |
| client version management read | no | yes | `GET /api/admin/v1/client-versions/page-init`, `GET /api/admin/v1/client-versions`, `GET /api/admin/v1/client-versions/update-json` | no | n/a | full smoke only probes dict/page/list/update-json shape; does not create version rows, does not set latest, does not publish COS manifest |
| upload config read | no | yes | `GET /api/admin/v1/upload-drivers/init`, `GET /api/admin/v1/upload-drivers`, `GET /api/admin/v1/upload-rules/init`, `GET /api/admin/v1/upload-rules`, `GET /api/admin/v1/upload-settings/init`, `GET /api/admin/v1/upload-settings` | no | n/a | full smoke 必须始终探测三类配置 init/list shape；不触发云 SDK |
| upload config write probe | no | gated yes | `POST /api/admin/v1/upload-drivers`, `POST /api/admin/v1/upload-rules`, `POST /api/admin/v1/upload-settings`, `DELETE /api/admin/v1/upload-settings/:id`, `DELETE /api/admin/v1/upload-rules/:id`, `DELETE /api/admin/v1/upload-drivers/:id` | yes, only disabled temp rows | delete setting -> rule -> driver | API 启动已强校验 APP_SECRET；永远不启用临时 setting，不修改现有 enabled setting；不安装/调用 OSS SDK |
| upload token shape | no | gated yes | `POST /api/admin/v1/upload-tokens` | token only | n/a | 没有 enabled upload setting 时 summary 输出 `skipped_upload_setting_missing`；存在 enabled COS setting 时只校验 provider/key/credentials shape，永远不上传真实文件。If enabled COS secrets cannot be decrypted with the current `APP_SECRET`-derived key, this is `UPLOAD-RUNTIME-001` and must fail as `上传密钥不可用`, not skip. |
| payment config + recharge cashier Alipay v1 | no | yes | full smoke probes `GET /api/admin/v1/payment/configs/page-init`, `GET /api/admin/v1/payment/configs?current_page=1&page_size=20`, `GET /api/admin/v1/payment/recharges/page-init`, `GET /api/admin/v1/payment/recharges?current_page=1&page_size=10`, plus payment-order ledger `GET /api/admin/v1/payment/orders/page-init`, `GET /api/admin/v1/payment/orders?current_page=1&page_size=20`; users/init menu gate asserts `/payment/config`, `/payment/recharge`, and `/payment/orders` are visible with their expected `view_key` values, and retired channel/event/pay routes are absent | no default mutation | n/a | Alipay config/recharge/order read only; smoke expects provider=`alipay`, asserts config secrets never leak, checks package/wallet/recharge/order list shape, and checks no raw payment create UX assumptions. Default smoke does not upload certificates, call `configs/:id/test`, create recharges/orders, trigger pay, sync real Alipay, write wallet credit, or invoke real Alipay callback; public callback route / auth skip / RBAC skip and cron registry are covered by backend tests plus smoke registry gates. Sandbox recharge/pay/sync is credential-gated manual smoke. |
| wallet read ledger | no | yes | `GET /api/admin/v1/wallet/summary`, `GET /api/admin/v1/wallet/transactions?current_page=1&page_size=10`, `GET /api/admin/v1/wallet/users/page-init`, `GET /api/admin/v1/wallet/users?current_page=1&page_size=10`, `GET /api/admin/v1/wallet/ledger/page-init`, `GET /api/admin/v1/wallet/ledger?current_page=1&page_size=10`; users/init menu gate asserts `/wallet/transactions`, `/wallet/users`, `/wallet/ledger` with expected `view_key` values | no default mutation | n/a | wallet read gate proves balance summary includes `total_consume_cents`, transaction/user/ledger list shapes are stable, and ledger dicts expose only `in/out` and `recharge/consume`; `POST /wallet/consumptions` is mutation-gated by `wallet_consume_add` and is not run by default smoke. |
| operation log read/delete | no | yes | `GET /api/admin/v1/operation-logs/init`, `GET /api/admin/v1/operation-logs`, `POST /api/admin/v1/permissions`, `DELETE /api/admin/v1/operation-logs/:id`, `DELETE /api/admin/v1/permissions/:id` | yes | delete temp operation log row; delete temp permission | full 先创建临时权限触发 `新增权限` 操作日志，再删除该日志 |
| queue health | yes | via basic | `auth:login-log:v1` worker path or sync fallback evidence | yes | no cleanup | 当前以 login log 近 5 分钟记录证明 queue/worker 或显式同步策略可用 |
| scheduler business dispatch | no | unit tests | `cron_task.name=notification_task_scheduler` -> `notification:dispatch-due:v1` -> `notification:send-task:v1` | no in smoke | n/a | 调度器不放进 smoke 写路径；用 `go test ./internal/module/crontask ./internal/module/notification/task ./internal/module/payment ./internal/jobs ./internal/bootstrap` 证明 DB-backed scheduler 只写 cron_task_log 并 enqueue，handler 才 claim DB/send/pay compensation |
| queue monitor read-only | no | yes | `GET /api/admin/v1/queue-monitor`, `GET /api/admin/v1/queue-monitor/failed`, `HEAD /api/admin/v1/queue-monitor-ui` | no | n/a | full smoke 只探测只读 JSON 摘要、失败任务分页 shape 和 asynqmon UI 可访问性，不做 retry/delete/clear |
| realtime WebSocket connect/heartbeat | yes | via basic | `GET /api/admin/v1/realtime/ws`, `realtime.connected.v1`, `realtime.ping.v1`, `realtime.pong.v1` | local session register/cleanup only | client closes socket | 证明 AuthToken 后的 WebSocket upgrade、项目 envelope、ping/pong 和 bounded session pump 没断；browser cookie auth、topic 白名单、`REALTIME_ENABLED=false` 503、Publisher local/noop、Vue URL/envelope cleanup 走单元/Vitest，不放 basic smoke；fan-out 走单元测试，不测 AI |

## Non-smoke gates

有些基建不应该硬塞进 smoke。队列/调度器/worker 的第一层验证走单元测试和进程边界检查：

```powershell
go test ./internal/infra/taskqueue ./internal/infra/scheduler ./internal/jobs ./internal/bootstrap
go test ./internal/module/queuemonitor ./internal/infra/taskqueue ./internal/server ./internal/bootstrap
go test ./internal/infra/ai ./internal/infra/ai/provider ./internal/module/ai/provider ./internal/module/ai/agent ./internal/module/ai/knowledge ./internal/module/ai/tool ./internal/module/ai/chat ./internal/module/ai/conversation ./internal/module/ai/message ./internal/module/ai/run ./internal/server ./internal/bootstrap
```

当前覆盖：

```text
taskqueue.Mux 已注册 handler 可以处理 project task
未知 task type 必须显式失败，不允许静默吞掉
jobs.Register 同时注册 system:no-op:v1、auth:login-log:v1、notification:dispatch-due:v1、notification:send-task:v1
jobs.RegisterSchedules 不再注册静态业务 schedule；cron-to-queue 由 internal/module/crontask.SchedulerService.RegisterEnabled 负责
notification_task_scheduler 只写 cron_task_log 并 enqueue notification:dispatch-due:v1；dispatch-due handler 才 claim 到期 notification_task 并 enqueue send-task
ai_run_timeout 由 Go registry 投递 ai:run-timeout:v1；ai/chat worker handler 只扫描并标记超过代码内置 AI run stale timeout 默认值的残留 running ai_runs
AI conversation focused gates cover ai/conversation, ai/message, and ai/chat REST/service contracts plus frontend AI REST/WebSocket event contract tests; this does not close `AI-FE-001`, because the canceled-stream late-event regression still needs a formal failing Vitest case and fix. ai/tool gate covers tool definition/binding/internal dispatch/audit; ai/run gate covers token-only `ai_runs` / `ai_run_events` monitor reads, aggregates, and `ai_tool_calls` detail visibility
realtime Redis Pub/Sub fan-out 通过 `go test ./internal/infra/realtime ./internal/module/notification/task ./internal/bootstrap` 验证，不在 smoke 发送真实通知
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

Payment/wallet smoke is read-only by default in this rebuild. Payment probes config page-init/list, recharge page-init/list shape, payment order page-init/list shape, and payment menu state only. Wallet probes summary, current-user transactions, admin wallet users, admin ledger, and wallet menu state only. Certificate upload, config test with real credentials, sandbox recharge/order creation, pay URL generation, status sync, wallet credit, wallet consume, notify, and real Alipay calls remain manual or future credential-gated probes.

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
AI agent avatar, AI chat image, and rich text image must migrate as part of their owning business modules, not as standalone upload pages.
```
