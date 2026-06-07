# Admin Smoke Matrix

状态更新时间：2026-05-31

本文是 smoke 覆盖地图，不是接口契约。接口契约看 `docs/contracts/admin-api-v1.md`。

当前验证摘要看 `docs/status/current-status.md`。截至 2026-05-30，COS 上传驱动密钥已按当前 Docker-first `APP_SECRET` 重新录入，`full-admin-smoke.ps1` 已通过；summary 记录 `upload_token_probe=passed`、`upload_token_code=0`、`upload_token_provider=cos`。如果以后再次出现 enabled COS setting 但 secretbox 解不开，仍必须按 `上传密钥不可用` 失败处理，不允许跳过。

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
| Platform route-line guard | no | code gate | `go test ./internal/architecture -run "PlatformRouteLine" -count=1` | no | n/a | Ensures canvas/app/admin URL prefixes are registered by matching `transport/{platform}` packages, not by dynamic prefix injection through another platform transport. |
| readiness | yes | via basic | `GET /ready` with database/redis/token_redis/queue_redis/realtime checks | no | n/a | 证明 MySQL/Redis/QueueRedis/Realtime readiness shape；dependency detail 属于 readiness，不属于 health |
| login config | yes | via basic | `GET /api/admin/v1/auth/login-config` | no | n/a | 断言登录方式顺序是 `email,phone,password` |
| verify code login | yes | via basic | `POST /api/admin/v1/auth/send-code`, `POST /api/admin/v1/auth/login` | login session | logout | 手机号验证码固定 `123456`；邮箱验证码走腾讯云 SES，basic smoke 默认用手机号账号 |
| slide captcha login | yes | via basic + full own login | `GET /api/admin/v1/auth/captcha`, `POST /api/admin/v1/auth/login`, `POST /api/admin/v1/auth/logout` | login session | logout | 自动读取本次 challenge 的 Redis 答案，不绕过验证码 |
| login log queue | yes | via basic | `users_login_log` recent count | yes | no cleanup | 证明 auth queue/worker 或同步兜底路径可用 |
| users bootstrap | yes | via basic | `GET /api/admin/v1/users/me` | no | n/a | 验证 router/buttonCodes；client version route 必须返回 `/system/clientVersion` + `system/clientVersion` |
| AI provider/agent menu gate | yes | via basic | `GET /api/admin/v1/users/me` menu/router payload | no | n/a | users/me must not return retired goods/cine/model/agent/prompt AI menu entries; it must return the seven active AI entries `/ai/providers`, `/ai/agents`, `/ai/knowledge`, `/ai/tools`, `/ai/runs`, `/ai/chat`, and `/ai/image-playground`. Smoke clears current-user button cache before this gate so stale Redis grants do not hide DB/menu truth. |
| AI provider/agent/tool/knowledge/image config read | no | yes | `GET /api/admin/v1/ai-providers/page-init`, `GET /api/admin/v1/ai-providers`, `GET /api/admin/v1/ai-agents/page-init`, `GET /api/admin/v1/ai-agents`, `GET /api/admin/v1/ai-agents?scene=chat`, `GET /api/admin/v1/ai-agents?scene=agent_generate`, `GET /api/admin/v1/ai-agents?scene=image_generate`, `GET /api/admin/v1/ai-agents?scene=canvas_text_generate`, `GET /api/admin/v1/ai-agents?scene=canvas_image_generate`, `GET /api/admin/v1/ai-agents?scene=canvas_video_generate`, `GET /api/admin/v1/ai-agents/options`, `GET /api/admin/v1/ai-agents/options?scene=image_generate`, `GET /api/admin/v1/ai-agents/options?scene=canvas_text_generate`, `GET /api/admin/v1/ai-agents/options?scene=canvas_image_generate`, `GET /api/admin/v1/ai-agents/options?scene=canvas_video_generate`, `GET /api/admin/v1/ai-images/page-init`, `GET /api/admin/v1/ai-images`, `POST /api/admin/v1/ai-images`, `GET /api/admin/v1/ai-images/:id`, `DELETE /api/admin/v1/ai-images/:id`, optional `GET /api/admin/v1/ai-agents/:id/tools` when an agent option exists, optional `GET /api/admin/v1/ai-agents/:id/knowledge-bases` when an agent option exists, `GET /api/admin/v1/ai-knowledge-bases/page-init`, `GET /api/admin/v1/ai-knowledge-bases`, `GET /api/admin/v1/ai-tools/page-init`, `GET /api/admin/v1/ai-tools/generate/page-init`, `GET /api/admin/v1/ai-tools` | yes, temp Admin image task | delete temp task | full smoke proves the provider/agent/tool/knowledge/image admin tables are Go-owned and asserts the three Canvas scenes exist in ai-agent page-init/options. Admin image reads are backed by `ai_image_tasks/ai_image_files` with `platform=admin`; full smoke creates a temp Admin image task from an `image_generate` agent, verifies detail/list, then deletes it without waiting for paid provider output; `/api/admin/v1/ai-images/assets` is retired and not a smoke endpoint. Old `/api/admin/v1/ai-billing-rules*` read smoke is removed because the global AI billing system is retired. Admin image and Canvas generation are free runtime callers; balance/debit/refund behavior is not a smoke expectation. |
| AI conversation/run monitor disabled-baseline | no | yes | `GET /api/admin/v1/ai-conversations`, optional `GET /api/admin/v1/ai-conversations/:id/messages` shape when fixture exists, `GET /api/admin/v1/ai-runs/page-init`, `GET /api/admin/v1/ai-runs`, optional `GET /api/admin/v1/ai-runs/:id` when a run fixture exists, `GET /api/admin/v1/ai-runs/stats` | no successful mutation by default | n/a | full smoke proves conversation and unified AI run-monitor read paths use the local AI schema. Run monitor filters include `platform`, `modality`, `source_type`, `usage_status`, and `status`; stats return `avg_duration_ms`; events are lifecycle-only; detail renders `source_type/source_id/input_snapshot/usage_status` for non-chat rows and returns `tool_calls` plus `knowledge_retrievals` from separate audit tables when present. Conversation send is a mutation and is covered by unit/contract tests unless an explicit live provider probe is enabled; browser chat no longer calls `/api/admin/v1/ai-chat/runs` or REST event polling. Stream timeout governance is unit-tested: live max duration, provider idle timeout, and stale-run cron cleanup are separate. `AI-FE-001` is covered by focused Vitest regression cases, not smoke. |
| canvas_front_next / canvas API | no | yes, via focused code gates + full admin smoke baseline | `GET /api/canvas/v1/auth/login-config`, `GET /api/canvas/v1/auth/captcha`, `POST /api/canvas/v1/auth/send-code`, `GET /api/canvas/v1/settings`, `GET /api/canvas/v1/prompts`, `GET /api/canvas/v1/assets`, canvas AI chat/image/video routes | live generation only when provider/agent fixtures are explicitly prepared | clean up created canvas tasks if a live probe is enabled | 2026-05-31 verified: backend full tests, frontend boundary/type/build, live DB query, full-admin-smoke, and root governance passed. Route-line hardening was reverified with architecture guard, backend full tests, basic-admin-smoke, full-admin-smoke, and root governance gates. Canvas image routes now live in `internal/module/ai/image/transport/canvas` and persist in `ai_image_tasks/ai_image_files` with `platform=canvas`; they must not fork a separate Canvas image repository/service/model. Hotfix gates also assert no `/api/canvas/v1/auth/register`, login-config-driven email/phone/password tabs, send-code login, password-submit captcha modal, axios-backed API/proxy requests, `(user)` auth guard, and 401/403 handling. Canvas RBAC SQL/code gates assert PAGE rows (`canvas_page`, `canvas_image_page`, `canvas_video_page`, `canvas_prompts_page`, `canvas_assets_page`) plus BUTTON rows (`canvas_access`, `canvas_prompt_read`, `canvas_asset_read`, `canvas_ai_image_generate`, `canvas_ai_video_generate`); canvas login/current-user payloads must be users/me-shaped and expose PAGE access through `router`, while `buttonCodes` stays BUTTON-only. Canvas AI page-init/settings gates assert `agents.text|image|video` come from `canvas_text_generate` / `canvas_image_generate` / `canvas_video_generate` and that settings no longer exposes billing rules, wallet payloads, recharge routes, balance, cost, unit price, debit, or refund concepts. |
| users management read | yes | via basic | `GET /api/admin/v1/users/page-init`, `GET /api/admin/v1/users` | no | n/a | 验证用户管理页 Go REST read path |
| user legacy closure | no | yes | `GET /api/admin/v1/users/login-logs/page-init`, `GET /api/admin/v1/users/login-logs?current_page=1&page_size=10`, `GET /api/admin/v1/user-sessions/page-init`, `GET /api/admin/v1/user-sessions?current_page=1&page_size=10`, `GET /api/admin/v1/user-sessions/stats`, `PATCH /api/admin/v1/user-sessions/:id/revoke` current-session failure probe | no default write | n/a | 登录日志只读 shape；会话列表继续断言 token hash 不泄漏；revoke 只验证当前 session 不能踢自己，不随机踢 live session |
| export tasks read | no | yes | `GET /api/admin/v1/export-tasks/status-count?kind=user_list`, `GET /api/admin/v1/export-tasks?current_page=1&page_size=20&kind=user_list` | no | n/a | full smoke 只探测当前用户导出任务状态统计和分页 shape，断言 `kind/kind_text` 字段；不触发真实导出、不等待 worker、不上传 COS |
| profile + avatar first upload slice | no | yes | `GET /api/admin/v1/profile`, `GET /api/admin/v1/users/:id/profile`, `PUT /api/admin/v1/profile`, avatar upload token via shared client contract | harmless self-update of same values | n/a | full smoke 读取 profile shape，PUT 原值证明路由/operation log；真实头像直传仍由前端上传 token flow 负责 |
| account security writes | no | failure probes only | `PUT /api/admin/v1/profile/security/password`, `PUT /api/admin/v1/profile/security/email`, `PUT /api/admin/v1/profile/security/phone`; forgot-password success is unit-tested via `POST /api/admin/v1/auth/forgot-password` | no successful mutation | n/a | full smoke 只验证错误旧密码/错误邮箱验证码/错误手机号验证码返回 `code=100`，不修改真实测试账号密码、手机号、邮箱；forgot-password 成功会改密码，所以不放默认 smoke 写路径 |
| auth platform read | yes | via basic | `GET /api/admin/v1/auth-platforms/page-init`, `GET /api/admin/v1/auth-platforms` | no | n/a | 验证 captcha dict 存在 |
| notifications current-user read | no | yes | `GET /api/admin/v1/notifications/page-init`, `GET /api/admin/v1/notifications`, `GET /api/admin/v1/notifications/unread-count` | no | n/a | full smoke 只探测字典、分页 shape、未读数 shape；不标记已读/删除真实通知，避免改变测试账号状态 |
| notification task publish read | no | yes | `GET /api/admin/v1/notification-tasks/page-init`, `GET /api/admin/v1/notification-tasks/status-count`, `GET /api/admin/v1/notification-tasks` | no | n/a | full smoke 只探测发布任务字典、状态统计、分页 shape；不创建通知任务，避免给测试/真实用户发送垃圾通知 |
| system cron tasks | no | yes | `GET /api/admin/v1/cron-tasks/page-init`, `GET /api/admin/v1/cron-tasks`, conditional `GET /api/admin/v1/cron-tasks/:id/logs` | no | n/a | full smoke probes dict/page/list/log shape and asserts `notification_task_scheduler`, `ai_run_timeout`, `payment_sync_pending_order`, and `payment_close_expired_order` return versioned Go task type handlers; payment tasks must report `payment:sync-pending-order:v1` / `payment:close-expired-order:v1`; `ai_run_timeout` must report `ai:run-timeout:v1`; `registry_status` compatibility fields must not be present. Smoke checks list shape and does not intentionally kill fresh AI replies or execute payment compensation writes. |
| permission + role RBAC loop | yes | via basic | permissions create/delete, role update/restore, users/me | yes | delete temp permissions; restore role | 临时 DIR/PAGE/BUTTON 必须清掉 |
| system log read-only | no | yes, lines conditional | `GET /api/admin/v1/system-logs/page-init`, `GET /api/admin/v1/system-logs/files`, `GET /api/admin/v1/system-logs/files/:name/lines` | no | n/a | full smoke 探测 page-init/files shape；当文件列表非空时读取第一份日志 tail lines；不做删除/清空/下载日志 |
| system settings read | no | yes | `GET /api/admin/v1/system-settings/page-init`, `GET /api/admin/v1/system-settings` | no | n/a | full smoke 只探测 page-init/list shape；旧 `devtools_queue_monitor_queues` 清理由迁移脚本/人工执行，不在 smoke 里做写库删除 |
| mail Tencent SES read | no | yes | `GET /api/admin/v1/mail/page-init`, `GET /api/admin/v1/mail/config`, `GET /api/admin/v1/mail/templates`, `GET /api/admin/v1/mail/logs` | no | n/a | full smoke only probes dict/config/template/log shapes, channel-specific `verify_code_ttl_minutes`, and encrypted secrets/template payload fields do not leak; no default real email send and no Tencent API call in smoke |
| sms Tencent Cloud read | no | yes | `GET /api/admin/v1/sms/page-init`, `GET /api/admin/v1/sms/config`, `GET /api/admin/v1/sms/templates`, `GET /api/admin/v1/sms/logs` | no | n/a | full smoke only probes dict/config/template/log shapes, channel-specific `verify_code_ttl_minutes`, and encrypted secrets, SMS body, template params, raw request, and raw response fields do not leak; no default real SMS send and no Tencent API call in smoke |
| client version management read | no | yes | `GET /api/admin/v1/client-versions/page-init`, `GET /api/admin/v1/client-versions`, `GET /api/admin/v1/client-versions/update-json` | no | n/a | full smoke only probes dict/page/list/update-json shape; does not create version rows, does not set latest, does not publish COS manifest |
| upload config read | no | yes | `GET /api/admin/v1/upload-drivers/page-init`, `GET /api/admin/v1/upload-drivers`, `GET /api/admin/v1/upload-rules/page-init`, `GET /api/admin/v1/upload-rules`, `GET /api/admin/v1/upload-settings/page-init`, `GET /api/admin/v1/upload-settings` | no | n/a | full smoke 必须始终探测三类配置 page-init/list shape；不触发云 SDK |
| upload config write probe | no | gated yes | `POST /api/admin/v1/upload-drivers`, `POST /api/admin/v1/upload-rules`, `POST /api/admin/v1/upload-settings`, `DELETE /api/admin/v1/upload-settings/:id`, `DELETE /api/admin/v1/upload-rules/:id`, `DELETE /api/admin/v1/upload-drivers/:id` | yes, only disabled temp rows | delete setting -> rule -> driver | API 启动已强校验 APP_SECRET；永远不启用临时 setting，不修改现有 enabled setting；不安装/调用 OSS SDK |
| upload token shape | no | gated yes | `POST /api/admin/v1/upload-tokens` | token only | n/a | 没有 enabled upload setting 时 summary 输出 `skipped_upload_setting_missing`；存在 enabled COS setting 时只校验 provider/key/credentials shape，永远不上传真实文件。If enabled COS secrets cannot be decrypted with the current `APP_SECRET`-derived key, this is `UPLOAD-RUNTIME-001` and must fail as `上传密钥不可用`, not skip. |
| payment config + recharge cashier Alipay v1 | no | yes | full smoke probes `GET /api/admin/v1/payment/configs/page-init`, `GET /api/admin/v1/payment/configs?current_page=1&page_size=20`, `GET /api/admin/v1/payment/recharges/page-init`, `GET /api/admin/v1/payment/recharges?current_page=1&page_size=10`; users/me menu gate asserts Left menu only shows one payment top-level entry with visible children `/payment/config`, `/payment/ledger`, `/payment/wallets`, and hidden `/profile/wallet` + `/payment/recharge` route availability | no default mutation | n/a | Alipay config/recharge read only; smoke expects provider=`alipay`, asserts config secrets never leak, and checks package/wallet/recharge list shape. `/payment/recharge opens from /profile/wallet with no manual sync button.` Default smoke does not upload certificates, call `configs/:id/test`, create recharges/orders, trigger pay, write wallet credit, invoke real Alipay callback, or claim Task 10 live DB/full verification. |
| payment/wallet read ledger | no | yes | `GET /api/admin/v1/wallet/summary`, `GET /api/admin/v1/wallet/transactions?current_page=1&page_size=10`, `GET /api/admin/v1/payment/ledger/page-init`, `GET /api/admin/v1/payment/ledger?current_page=1&page_size=10`, `GET /api/admin/v1/payment/wallets/page-init`, `GET /api/admin/v1/payment/wallets?current_page=1&page_size=10` | no default mutation | n/a | `/payment/ledger loads and filters direction/source_type/date range.` `/payment/wallets loads and filters user keyword.` `/profile/wallet loads summary and self transaction tab.` Left-side wallet pages are retired/historical, not visible smoke expectations. Default smoke does not call any public consume route and does not default to wallet consumption probes. |
| operation log read/delete | no | yes | `GET /api/admin/v1/operation-logs/page-init`, `GET /api/admin/v1/operation-logs`, `POST /api/admin/v1/permissions`, `DELETE /api/admin/v1/operation-logs/:id`, `DELETE /api/admin/v1/permissions/:id` | yes | delete temp operation log row; delete temp permission | full 先创建临时权限触发 `新增权限` 操作日志，再删除该日志 |
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
AI conversation focused gates cover ai/conversation, ai/message, and ai/chat REST/service contracts plus frontend AI REST/WebSocket event contract tests, including `AI-FE-001` canceled-stream late-event guards; ai/tool gate covers tool definition/binding/internal dispatch/audit; ai/run gate covers unified `ai_runs` / `ai_run_events` monitor reads, source fields, usage_status, aggregates, and `ai_tool_calls` detail visibility
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

Payment/wallet smoke is read-only by default in this rebuild. Payment probes config page-init/list, recharge page-init/list shape, `/payment/ledger` page-init/list filters, `/payment/wallets` page-init/list filters, current-user wallet summary/transactions, hidden `/profile/wallet`, hidden `/payment/recharge`, and payment menu state only. Certificate upload, config test with real credentials, sandbox recharge/order creation, pay URL generation, wallet credit, notify, and real Alipay calls remain manual, unit/service, or future credential-gated probes. Old AI billing debit/refund probes are removed because the global AI billing system is retired.

Export runtime V2 keeps default full smoke read-only. Real submit -> worker -> COS upload is credential-gated and must be run explicitly with:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\export-task-smoke.ps1 `
  -Account 15671628271 `
  -Password 123456 `
  -BaseURL http://127.0.0.1:8080 `
  -RunRealExport
```

Expected gated result: JSON contains `status: 2`, `.xlsx`, `row_count >= 1`, and `file_url_present: true`.

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
