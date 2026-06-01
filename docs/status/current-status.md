# Admin Go/Vue Runtime Current Status

状态更新时间：2026-06-01

本文是当前运行时事实入口，只放最新关键事实、验证缺口和跳转。详细 per-module 分组明细已经分层到 `docs/status/module-matrix.md`；历史变更记录已经归档到 `docs/status/archive/2026-05-runtime-change-log.md`。

不要把 planned 写成 implemented。文档与运行时冲突时，以 live runtime、smoke/test output、served API 和 process config 为准。

## Current status layers

```text
docs/status/current-status.md                         # 当前入口：关键事实、验证缺口、读法
docs/status/module-matrix.md                          # 当前明细：per-module Go/Vue runtime status
docs/status/known-issues.md                           # 当前已知 bug / WIP 证据，不当成 verified
docs/status/archive/2026-05-runtime-change-log.md     # 历史证据：2026-05 verified change log
```

## Current runtime truth

- 架构方向：new-system-first / multi-platform-first。后端目标是一套核心能力服务 admin / app / openapi / merchant 等多个前端或平台入口。
- 当前 backend boundary truth 是 `internal/module/{capability}/transport/{platform}` + `internal/shared` + `internal/infra`；active exceptions 是产品范围决定，不是架构漂移。
- Admin behavior preservation 仍是验收标准：现有 admin URLs、DB 表名、permission codes、i18n keys、route metadata、operation log rules、queue task types、payment callback/finalizer 行为、frontend typed API contracts 不得被重构破坏。
- Future app/openapi/merchant/miniapp work 必须在现有 capability 下增加 `transport/{platform}`，不要创建平台前缀业务模块。
- Channel-specific verify-code TTL 已落地：email TTL 归 `mail_configs.verify_code_ttl_minutes`，SMS TTL 归 `sms_configs.verify_code_ttl_minutes`；旧 `system_settings.auth.verify_code.ttl_minutes` 已在本地 live MySQL check 中软删除。
- `admin_app` H5/LAN dev 当前仍是直连 Go backend `/api/app/v1`：runtime 默认 API base 是 `http://127.0.0.1:8080/api/app/v1`；部署或 LAN 真机调试必须用 `VITE_APP_API_BASE_URL` 覆盖为当前可访问的 Go backend origin。
- Realtime 当前是 admin WebSocket + notification fan-out + AI conversation events；AI cancel 是 REST `POST /api/admin/v1/ai-conversations/:id/messages/cancel`，WebSocket 只发 `ai.response.start/delta/completed/failed.v1`。
- Queue / scheduler 当前已有 Redis-backed scheduler lock；worker hot reload 和 DB+queue outbox 仍是 planned。
- Canvas free-generation active slice contract：`canvas_front_next` 独立 Next.js 前端只调用 `/api/canvas/v1/*`；本切片明确退休旧 AI billing 全局系统，Canvas 对话、图片、视频生成统一通过后端托管 provider 免费执行，不查余额、不扣款、不写 `ai_billing_records`。backend/frontend/root gates 和本地 live DB migration/query 已验证。
- Canvas AI runtime selector 当前按智能体场景绑定取数：`/api/canvas/v1/settings` 的 `agents.text|image|video` 来自启用的 `ai_agents` Canvas 专属场景（`canvas_text_generate` / `canvas_image_generate` / `canvas_video_generate`）；`scenes` 只是可用 Canvas 运行场景，不再是 billing metadata；Canvas AI 请求只提交 `agent_id`，provider model 由后端智能体决定。
- Canvas free-generation boundary：Canvas profile 由 `internal/module/profile/transport/canvas` 拥有 `GET/PUT /api/canvas/v1/profile`；Canvas UI 的 wallet/recharge 收费入口在旧 AI billing 删除切片中退休。payment/wallet/recharge 基础域仍保留给非本切片能力和未来会员时间制模型。
- Canvas auth/RBAC hotfix：后台菜单管理 `permissions/page-init` 默认平台字典必须包含 `admin/app/canvas`；Canvas 登录页必须读 `/api/canvas/v1/auth/login-config` 渲染 email/phone/password 登录方式，email/phone 走 `/send-code` 验证码登录并按 `allow_register` 自动开户，password 登录点击提交后再弹 slide captcha，不提供独立注册入口；`canvas_front_next` 的 `(user)` 页面由登录态 guard 保护，401 跳登录、403 显示无权限页。
- Canvas auth/RBAC transport boundary hardening：Canvas auth 由 `internal/module/auth/transport/canvas` 拥有 `/api/canvas/v1/auth/*`，Canvas current-user 由 `internal/module/user/transport/canvas` 拥有 `/api/canvas/v1/users/me`，App current-user 由 `internal/module/user/transport/app` 拥有 `/api/app/v1/users/me`；profile transport 不拥有 current-user bootstrap，只拥有 profile read/update。旧 Canvas wallet/recharge current-user routes 不再是 Canvas AI 免费生成的 active dependency；payment/wallet transport 只保留基础充值域边界。
- Current-user bootstrap contract：admin/app/canvas 统一使用 `GET /api/{admin,app,canvas}/v1/users/me` 和同一个 DTO（`user_id`、`username`、`avatar`、`role_name`、`permissions`、`router`、`buttonCodes`）；`users/init` 不再是 bootstrap 例外；已删除废弃首页捷径功能、admin 前端入口、后端保存路由和本地 live MySQL 表。Canvas SQL seed 包含 PAGE rows（`canvas_page`、`canvas_image_page`、`canvas_video_page`、`canvas_prompts_page`、`canvas_assets_page`、`canvas_profile_page`）以及 BUTTON rows（`canvas_access`、`canvas_prompt_read`、`canvas_asset_read`、`canvas_ai_image_generate`、`canvas_ai_video_generate`）；top/mobile navigation 和 route guard 使用 backend `router`，按钮/动作 `can(code)` 只读 `buttonCodes`。

## Current verification gaps

- 2026-05-30 after re-entering COS upload driver secrets for the current `APP_SECRET`, full admin smoke passed and `UPLOAD-RUNTIME-001` is closed as a runtime data repair, not a code change. The summary reported `upload_token_probe=passed`, `upload_token_code=0`, and `upload_token_provider=cos`.
- 2026-05-30 Docker-first backend readiness was restored on `127.0.0.1:8080`; `/health` and `/ready` passed with database/redis/token_redis/queue_redis/realtime all `up`.
- 2026-05-27 multi-platform Phase 2 code/docs/frontend gates and the later full admin smoke gate have now passed for the current local Go/Vue runtime.
- Docker-first readiness 和 smoke 是两条验证链：Docker runtime 用 `127.0.0.1:8080 /health /ready`；smoke 脚本默认临时端口是 basic `127.0.0.1:18080`、full `127.0.0.1:18081`。
- `admin_app` 机器局域网默认值已清掉；本轮未跑真机 smoke，LAN 调试仍需按本机 IP 配置 `VITE_APP_API_BASE_URL`、后端监听地址、防火墙和 `CORS_ALLOW_ORIGINS`。
- Export runtime V2 code/tests are complete in the export worktree, but the credential-gated real submit-to-COS smoke has not been run in this environment; do not claim COS upload runtime closure until `scripts/export-task-smoke.ps1 -RunRealExport` passes。
- Canvas Front Next live DB baseline 已应用/查询 `20260531_canvas_front_next_integration.sql`：当前已验证的 canvas 业务表仍是 `canvas_prompts`、`canvas_assets`；本旧 AI billing 删除切片已新增并在本地 live DB 验证 `canvas_video_tasks` 保存视频异步任务事实。`canvas_users` / `canvas_credit_logs` / `canvas_settings` / `canvas_projects` / `canvas_wallets` 不存在；full-admin-smoke、后端全量 Go tests、Next test/typecheck/build 和 root governance gates 已通过。

## Latest status / change-log pointers

详细变更记录看 `docs/status/archive/2026-05-runtime-change-log.md`。近期关键批次：

```text
2026-06-01 Canvas free generation / old AI billing retirement active slice: /api/canvas/v1/settings exposes agents.text/image/video from `canvas_text_generate` / `canvas_image_generate` / `canvas_video_generate`, Canvas generation is free, old `/api/admin/v1/ai-billing-rules*` and `ai_billing_*` active contract are retired, and payment/wallet基础域只保留给非本切片能力
2026-06-01 backend fallback hardening: AI provider canonical engine_type and stored-status fail-closed behavior, upload config non-COS read fail-closed behavior, and mail/SMS runtime VerifyCodeTTL missing-config fail-closed behavior verified with backend full tests
2026-05-31 Canvas Front Next integration baseline verified: canvas auth platform/routes, public prompts/assets/settings, backend-managed text/image/video AI generation, Next frontend boundary/type/build gates, live DB migration/query, full-admin-smoke, and root governance gates passed; the temporary wallet/recharge thin routes from that baseline are retired by the 2026-06-01 free-generation slice
2026-06-01 current-user users/me contract cleanup: admin/app/canvas users/me share one DTO, users/init removed, obsolete shortcut feature removed from backend/frontend/live DB, user transport owns app/canvas current-user routes, Canvas PAGE/BUTTON RBAC live DB checker passed
2026-05-31 Canvas auth/RBAC route-line hardening verified: canvas auth/users URL prefixes are owned by matching transport/canvas packages instead of app/admin dynamic registration; backend architecture/targeted/full tests, go vet, basic-admin-smoke, full-admin-smoke, and root governance gates passed. Old Canvas wallet/recharge prefixes are no longer active Canvas free-generation dependencies
2026-05-31 RESTful API naming full standardization: frontend CRUD wrappers and active call sites use standard names only; backend page dictionary routes bind PageInit-style handlers/services; current-user bootstrap is `users/me`
2026-05-31 payment serial readability hardening: RCG/PAY/WLT no longer append a 20-digit zero-padded sequence; new rows use compact uppercase base36 suffix while old rows stay unchanged
2026-05-31 export runtime v2 verified: registry-driven export runtime, `kind/platform/object_key`, frontend export submit helper, migration dry-run, and gated real submit-to-COS smoke all passed
2026-05-31 payment/wallet final review: legacy wallet consume DTO/service/repository/i18n surfaces removed; wallet mutations are now explicit Debit/Credit with ai_generate/ai_refund sources
2026-05-31 payment/wallet/AI billing redesign verified: backend full tests, frontend targeted tests/typecheck/quality, live DB migration check, and full-admin-smoke passed
2026-05-30 COS upload secrets re-entered and full-admin-smoke passed; UPLOAD-RUNTIME-001 closed
2026-05-30 AI chat cancel late-event guard fixed: canceled request ids survive later completions and WebSocket start/delta/completed/failed acknowledgements only mutate the matching in-flight request or matching streaming assistant message
2026-05-30 payment finalizer state regression hardening: stale finalizer snapshots cannot downgrade credited recharges back to paid or credit recharges that were closed concurrently; recharge paid markers are CAS guarded
2026-05-30 payment race/return hardening: CAS misses no longer credit or leak stale pay_url, wallet first-create duplicate races return the existing wallet, callback audit amount parsing rejects signed cent fragments, and recharge auto-sync/return-url sync keep retrying while Alipay still says paying
2026-05-30 payment hardening follow-up: linked recharge close, paid-uncredited compensation, Alipay amount parsing, recharge add permission UI
2026-05-30 payment frontend/backend hardening: transient recharge sync failures stay retryable, payment-order sync is shown only for `paying`, disabled/deleted bound configs can still settle existing orders, open-order configs are locked, payment state updates use CAS, and callback audit JSON no longer blocks settlement
2026-05-30 production websocket/domain and docker-first deploy docs alignment
2026-05-30 wallet transaction_no hardening fixed: serial no-wrap + transaction_no duplicate retry for consume and recharge credit
2026-05-29 multi-platform backend boundary Phase 2 gates passed; final smoke pending
2026-05-29 transport admin alias cleanup
2026-05-29 wallet payment aggregation
2026-05-28 infra runtime layer rename
2026-05-28 final transport boundary guard
2026-05-28 admin transport shell waves
2026-05-28 AI/small-module/shared aggregation waves
2026-05-27 multi-platform architecture direction snapshot
```

## Current module details

详细 per-module 状态看：

```text
docs/status/module-matrix.md
```

## Current known issues

当前未闭环 bug / WIP 看：

```text
docs/status/known-issues.md
```

## Current verified RBAC loop

```text
login -> AuthToken -> users/me -> users/init
permission create DIR/PAGE/BUTTON
role update grants PAGE/BUTTON
users/init returns temporary router + BUTTON-only buttonCodes
role restore
permission subtree delete
users page-init + users list
logout
```

Verification command:

```powershell
cd E:\admin_go\admin_back_go
powershell -ExecutionPolicy Bypass -File .\scripts\basic-admin-smoke.ps1 -Account 15671628271 -Password 123456
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account 15671628271 -Password 123456
```
