# Admin Go/Vue Runtime Module Index

状态更新时间：2026-05-29

本文件是 `docs/status/current-status.md` 的当前状态明细层，只记录已验证的 Go/Vue runtime module 状态。不要把 planned 写成 implemented。

读取规则：

```text
current-status.md        # 当前入口、最新关键事实、验证缺口
module-matrix.md         # per-module 当前状态条目
archive/*.md            # 历史变更证据，不覆盖当前入口和本文件
```

写法规则：

```text
每个 module 只保留六个有用字段：Backend / Frontend / Tests / Smoke / Docs / Risk。
Backend 与 Frontend 写当前事实；Tests 与 Smoke 写验证边界；Docs 写同步来源；Risk 写明确剩余风险。
如果只是 planned、未来方向或历史叙事，放到 current-status 的验证缺口或 archive，不塞进 module 条目。
```

## Group index

- Runtime foundation / cross-cutting baseline:
  - `health / ready`
  - `backend i18n closure`
- Identity, auth, and access control:
  - `auth login/session`
  - `app auth baseline`
  - `captcha`
  - `auth platform`
  - `RBAC bootstrap`
  - `permission definitions`
  - `roles`
- User, profile, and export lifecycle:
  - `users management`
  - `user legacy closure`
  - `export tasks`
  - `profile / account security / avatar upload`
- Message channels and notification delivery:
  - `mail / Tencent SES`
  - `sms / Tencent Cloud SMS`
  - `notifications current-user read/list`
  - `notification task publish / scheduler`
- System operations, observability, and admin maintenance:
  - `system logs`
  - `operation log`
  - `system cron tasks`
  - `queue / worker / monitor`
  - `system settings`
  - `client version management`
- Upload and storage boundary:
  - `upload config`
  - `upload runtime/token`
- Payment and wallet:
  - `payment config + recharge cashier Alipay v1`
  - `wallet recharge/consume v1`
- AI suite and realtime conversation runtime:
  - `AI provider config / OpenAI first slice`
  - `AI agent config MVP`
  - `AI image playground gpt-image-2`
  - `AI run monitor token-only MVP`
  - `AI tool runtime MVP`
  - `AI knowledge base RAG MVP`
  - `realtime / WebSocket / AI conversation`
- Removed / retired scope:
  - `admin chat room`

## Runtime foundation / cross-cutting baseline

### health / ready

- Backend:
  - implemented: liveness separated from DB/Redis readiness, checks include
    database/redis/token_redis/queue_redis/realtime
  - not-ready response now uses localized backend error key
- Frontend: n/a
- Tests: `internal/readiness`, `internal/module/system`, `internal/bootstrap`, `internal/shared/i18n`
- Smoke: `/ready` in basic smoke
- Docs: architecture + contract + deployment docs
- Risk: readiness does not replace full smoke

### backend i18n closure

- Backend:
  - implemented: Gin i18n middleware, zh-CN/en-US catalog loader, response-boundary localization for error and
    success `msg`, explicit app error keys, deterministic legacy fallback bridge for still-unkeyed response
    messages, and catalog/source coverage guards
- Frontend:
  - adapted: common HTTP headers send Accept-Language from `lang` Cookie
  - high-visible frontend static UI uses Vue I18n keys
- Tests:
  - `internal/shared/i18n`, `internal/shared/apperror`, `internal/shared/response`, `internal/middleware`,
    `internal/server`
  - frontend `src/i18n`, HTTP/i18n Vitest guards
- Smoke:
  - backend full tests
  - frontend i18n/header tests, typecheck, build
- Docs: contract + backend architecture + i18n closure plan
- Risk:
  - DB labels, historical logs, user input, third-party raw errors, and AI prompt content are not translated as
    business content

## Identity, auth, and access control

### auth login/session

- Backend:
  - implemented: `internal/module/auth` now owns login, captcha, token/session primitives, refresh/logout, login-log
    write path, and session policy boundary
  - former standalone captcha/session/usersession/userloginlog modules have been consolidated into
    `internal/module/auth` without changing API contract URLs
- Frontend: adapted
- Tests: `internal/module/auth`
- Smoke:
  - password/code login, refresh/logout, login log count
  - auth consolidation verified by backend full tests
- Docs: architecture + contract
- Risk:
  - phone code fixed 123456
  - email uses Tencent SES
  - live smoke not rerun in the consolidation task

### app auth baseline

- Backend:
  - implemented: `GET /api/app/v1/auth/login-config`, `GET /api/app/v1/auth/captcha`, `POST
    /api/app/v1/auth/send-code`, `POST /api/app/v1/auth/login`, `GET /api/app/v1/users/me`, `GET
    /api/app/v1/profile`, `PUT /api/app/v1/profile`, `POST /api/app/v1/upload-tokens`, `POST
    /api/app/v1/auth/logout`
  - app password login now follows `auth_platforms` slide captcha policy and bearer requests default `platform=app`
  - 平台不是 module，`/api/app/v1/auth/*` 由 `auth/transport/app` 注册 platform route，app current-user profile compile route
    归属 `profile/transport/app`，upload-token 归属 `uploadtoken/transport/app`
- Frontend:
  - adapted: `admin_app` UniApp Vue3 shell only uses `/api/app/v1`, parses token + current-user profile, guards the
    two tabbar pages with app login state instead of backend RBAC, admin_app 目录结构已对齐 PC admin 的
    views/hooks/store/i18n/enums/platform/lib 分层；H5/LAN dev 必须直连可访问的 Go backend `/api/app/v1`，
    不在 Vite 上反代 `/api/app/v1`；局域网真机调试要求后端监听地址、防火墙和 `CORS_ALLOW_ORIGINS`
    覆盖实际 H5 origin；当前 admin_app runtime 默认 API base 是本机
    `http://127.0.0.1:8080/api/app/v1`，LAN/部署用 `VITE_APP_API_BASE_URL` 覆盖；登录页采用 PC
    mobile-inspired surface，slide captcha 内层验证器复用 `go-captcha-vue` 官方 `Slide` 组件和样式
- Tests:
  - `internal/module/auth`, `internal/module/profile`, `internal/module/user`, `internal/module/uploadtoken`,
    `internal/middleware`, `internal/server`, `internal/shared/response`, `internal/shared/i18n`
  - `admin_app` `docs/app-api-v1.md`, `docs/architecture.md`
- Smoke:
  - backend focused tests
  - `admin_app` Vitest contract/session/login-copy/backend-base tests, `vue-tsc`, `build:h5`
  - live smoke should cover backend direct login-config/captcha plus CORS preflight
- Docs: app API contract + backend architecture + app docs + app auth captcha plan
- Risk:
  - secure storage remains next slice
  - App 真机/小程序端是否继续沿用 H5 `go-captcha-vue` 需要单独发布切片验证
  - LAN phone debugging is no longer the code default; each developer must set `VITE_APP_API_BASE_URL` plus matching
    backend bind/CORS/firewall for the current device network

### captcha

- Backend:
  - implemented under `internal/module/auth/captcha.go` with localized backend error keys for zh-CN/en-US
  - runtime TTL reads `system_settings.auth.captcha.ttl_minutes`, slide tolerance reads
    `system_settings.auth.captcha.slide_padding`, and Redis namespace `captcha:slide:` is code-owned
- Frontend:
  - adapted with `go-captcha-vue`
  - editable through the existing system settings page by key search
- Tests: `internal/module/auth`, `internal/shared/i18n`, `internal/config`
- Smoke: real slide challenge in smoke
- Docs: architecture + contract
- Risk:
  - only slide supported
  - captcha policy rows must exist and stay enabled
  - API path remains `GET /api/admin/v1/auth/captcha` / `GET /api/app/v1/auth/captcha`

### auth platform

- Backend:
  - implemented: login types, captcha type, token TTL/session policy
  - handler/service public errors now carry localized zh-CN/en-US keys
  - capability directory is `internal/module/auth_platform` while i18n keys remain `authplatform.*`
- Frontend: adapted
- Tests: `internal/module/auth_platform`, `internal/shared/i18n`
- Smoke:
  - init/list in smoke
  - backend full test suite plus route snapshot
- Docs: `docs/contracts/admin-api-v1.md`
- Risk:
  - broader policy UI polish later
  - data labels are not part of `response.msg` i18n scope

### RBAC bootstrap

- Backend:
  - implemented: users/init exposes BUTTON-only buttonCodes
  - PermissionCheck uses internal RouteAccessCodes so PAGE read routes remain protected without leaking PAGE code
    into frontend button visibility
- Frontend: adapted: role editor labels PAGE grants as 页面访问 and maps it to real PAGE permission_id
- Tests:
  - `internal/module/user`, `internal/module/permission`, `internal/module/role`, `internal/bootstrap`
  - frontend role matrix tests
- Smoke: users/me + users/init
- Docs: architecture + contract
- Risk: no multi-role model in phase one

### permission definitions

- Backend: implemented
- Frontend: adapted
- Tests: `internal/module/permission`
- Smoke: create DIR/PAGE/BUTTON + batch delete
- Docs: architecture + contract
- Risk: operation-log hardening is next phase

### roles

- Backend: implemented
- Frontend: adapted
- Tests: `internal/module/role`
- Smoke: grant/restore test role in smoke
- Docs: architecture + contract
- Risk: deleting bound roles intentionally blocked

## User, profile, and export lifecycle

### users management

- Backend:
  - implemented for page-init/list/edit/batch-edit/status/delete/export submit
  - admin HTTP routes are owned by `internal/module/user/transport/admin`
  - export submit creates `export_tasks` pending row and enqueues `export:run:v1` low queue
- Frontend:
  - adapted for user manager page
  - export button uses Go REST `POST /api/admin/v1/users/export` and keeps `user_userManager_export`
- Tests:
  - `internal/module/user`, `internal/module/user/transport/admin`, `internal/module/export`, `internal/jobs`,
    `internal/server`, `internal/bootstrap`
  - frontend user/export-task API Vitest
- Smoke:
  - users page-init + list in basic smoke
  - export task read-only probes in full smoke matrix
- Docs: architecture + contract
- Risk:
  - worker requires enabled queue and Tencent COS config for actual file generation
  - upload runtime is Tencent COS-only
  - `bucket_domain` is stored as a bare host and runtime builds HTTPS public URLs

### user legacy closure

- Backend:
  - implemented: quick-entry save `PUT /api/admin/v1/users/me/quick-entries` is owned by `profile/transport/admin`
    and `profile` quick-entry service/repository/model
  - auth-owned login-log read `GET /api/admin/v1/users/login-logs/page-init` + `GET /api/admin/v1/users/login-logs`,
    and auth-owned user-session read/revoke `GET /api/admin/v1/user-sessions*` + `PATCH
    /api/admin/v1/user-sessions/:id/revoke` + `PATCH /api/admin/v1/user-sessions/revoke` with localized backend
    error keys, and public forgot-password reset `POST /api/admin/v1/auth/forgot-password`
  - session list still derives active/expired/revoked from `revoked_at` + `refresh_expires_at` and never returns
    token hash fields
  - consolidation kept existing API contract URLs unchanged
- Frontend:
  - adapted: home quick-entry, login-log page, session kick/batchKick, and login-page `forgetPassword` now use Go
    REST
  - `src/lib/http` no longer creates a legacy client or requires `VITE_SOME_KEY`
  - dead `EditPassword` frontend definition removed
- Tests:
  - `internal/module/auth`, `internal/module/profile`, `internal/module/profile/transport/admin`, `internal/server`,
    `internal/bootstrap`, `internal/shared/i18n`
  - frontend `src/api/user/*`, `src/lib/http/*`, `src/types/user.ts`, user API Vitest
- Smoke:
  - full smoke probes quick-entry save/restore, login-log page-init/list, user-session page-init/list/stats
    token-hash non-leak, and current-session anti-kick
  - focused profile tests and route snapshot preserve quick-entry behavior
- Docs: contract + smoke matrix + backend architecture
- Risk:
  - actual non-current kick smoke is intentionally not run against random live sessions
  - Redis cleanup is covered by focused Go tests and current-session anti-kick by smoke
  - phone code fixed 123456
  - email uses Tencent SES

### export tasks

- Backend:
  - implemented: `GET /api/admin/v1/export-tasks/status-count`, `GET /api/admin/v1/export-tasks`, `DELETE
    /api/admin/v1/export-tasks/:id`, `DELETE /api/admin/v1/export-tasks`
  - capability directory is `internal/module/export` while Go package identifiers and i18n keys remain `exporttask`
  - worker handles `kind=user_list`, writes xlsx with string cells, uploads to current COS, marks success/failed,
    sends notification, and returns localized backend error keys
- Frontend: adapted: `src/api/system/exportTask.ts` uses Go REST `request`, no legacy export-task adapter
- Tests:
  - `internal/module/export`, `internal/jobs`, `internal/bootstrap`, `internal/server`
  - frontend `tests/shared/system/export-task-api.test.ts`
- Smoke:
  - full smoke read-only probes status-count/list
  - route snapshot and backend full tests preserve API surface
  - actual export e2e requires queue worker + enabled Tencent COS config
- Docs: contract + backend architecture + smoke matrix
- Risk:
  - no universal export platform
  - no OSS runtime
  - no retry/cancel/COS delete UI in this slice

### profile / account security / avatar upload

- Backend:
  - implemented: `GET /api/admin/v1/profile`, `GET /api/admin/v1/users/:id/profile`, `PUT /api/admin/v1/profile`,
    `PUT /api/admin/v1/profile/security/password`, `PUT /api/admin/v1/profile/security/email`, `PUT
    /api/admin/v1/profile/security/phone`
  - current-user profile/security HTTP routes are owned by `internal/module/profile/transport/admin`, while
    user-manager target profile read remains under `user/transport/admin`
  - self-update and security writes record operation logs, no user-manager button permission
- Frontend:
  - adapted: personal base info/security and home profile summary read/write Go profile contract
  - avatar upload uses shared Go upload token client via `UpMedia` against Tencent COS only
- Tests:
  - `internal/module/profile`, `internal/module/profile/transport/admin`, `internal/module/user`,
    `internal/bootstrap`, `internal/server`
  - frontend `vue-tsc`
  - targeted Security eslint exits 0 with style warnings only
- Smoke: full smoke probes read/update, profile operation log, and non-mutating account-security failure cases
- Docs: contract + profile/avatar spec/plan + account-security spec/plan + smoke matrix
- Risk:
  - address dict now uses Redis permanent cache-aside with MySQL fallback
  - cache invalidation is manual until a Go address CRUD/import slice exists
  - `auth/send-code` remains public
  - phone code is fixed 123456 and email code uses Tencent SES
  - no avatar crop/server-side upload
  - upload runtime is Tencent COS-only
  - `bucket_domain` is stored as a bare host and runtime builds HTTPS public URLs

## Message channels and notification delivery

### mail / Tencent SES

- Backend:
  - implemented: `internal/module/mail` owns config/template/log/send orchestration
  - `internal/infra/mail/tencentcloudses` is the only Tencent SDK boundary
  - `auth/send-code` injects `VerifyCodeMailSender` for email, always sends email codes through Tencent SES, uses
    fixed `123456` for phone without SMS/env switches, requires mail templates to expose exactly `code` /
    `ttl_minutes`, and reads email verification-code TTL from `mail_configs.verify_code_ttl_minutes`, while Redis
    namespace `auth:verify_code:` is code-owned
- Frontend:
  - adapted: `/system/mail` page with config/template/log tabs, typed REST client, no encrypted secret fields or
    template payload exposure, channel-specific verify-code TTL field saved through `mail_configs`, and log tab
    follows the standard Search + AppTable + AppDialog + useCrudTable pattern like SMS
- Tests:
  - `internal/module/mail`, `internal/infra/mail/tencentcloudses`, `internal/module/auth`, `internal/server`,
    `internal/bootstrap`
  - frontend `tests/shared/system/mail-api.test.ts` + `vue-tsc`
- Smoke:
  - full smoke read-only probes page-init/config/templates/logs
  - no default real send
- Docs: contract + backend architecture + smoke matrix
- Risk:
  - real Tencent SES send requires enabled config and approved template IDs
  - phone login is controlled by `auth_platforms.login_types`
  - no SMTP/multi-provider/webhook/retry queue in this slice

### sms / Tencent Cloud SMS

- Backend:
  - implemented: `internal/module/sms` owns config/template/log/test-send orchestration
  - `internal/infra/sms/tencentcloudsms` is the only Tencent SMS SDK boundary
  - SendSms uses context + 10s timeout, pending->success/failed log closure, encrypted SecretId/SecretKey,
    channel-specific `sms_configs.verify_code_ttl_minutes`, code-owned Redis namespace `auth:verify_code:`, and only
    `code` / `ttl_minutes` template variables
  - `auth/send-code` phone remains fixed `123456` and is not wired to SMS, but its Redis TTL comes from SMS config
- Frontend:
  - adapted: `/system/sms` page with config/template/log tabs, typed REST client, constrained `ap-guangzhou` region,
    no encrypted secret fields, no SMS body/template params/raw payload exposure, and standard
    Search/AppTable/AppDialog/useCrudTable for logs
- Tests:
  - backend `internal/module/sms`, `internal/infra/sms/tencentcloudsms`, `internal/server`, `internal/bootstrap`,
    `internal/shared/i18n`
  - frontend `tests/shared/system/sms-api.test.ts`
- Smoke:
  - smoke matrix read-only probes page-init/config/templates/logs
  - no default real SMS send
- Docs: contract + backend architecture + smoke matrix + SMS spec/plan
- Risk:
  - real Tencent SMS send requires enabled config, approved sign/template IDs, and valid Tencent credentials
  - no sign/template application, webhook receipt, retry queue, multi-provider, batch, marketing, or international
    SMS in this slice

### notifications current-user read/list

- Backend:
  - implemented: REST init/list/unread-count/mark-read/delete scoped by token user + platform/all + is_del=2 with
    localized backend error keys
  - no RBAC button rule or operation-log metadata for current-user read/delete
- Frontend:
  - adapted: notification center and home/runtime notification calls use Go REST and versioned
    `notification.created.v1` listener
- Tests:
  - `internal/module/notification`, `internal/server`, `internal/bootstrap`
  - frontend targeted eslint
- Smoke: full smoke read-only probes init/list/unread-count
- Docs: contract + notification spec/plan + smoke matrix
- Risk: notification.created.v1 Redis/WebSocket fan-out now implemented through notification task dispatch

### notification task publish / scheduler

- Backend:
  - implemented: REST init/status-count/list/create/cancel/delete, enum/dict/validate, route permission + operation
    log metadata, localized backend error keys, `notification:dispatch-due:v1` + `notification:send-task:v1`
  - task implementation now lives under `internal/module/notification/task`, with `/api/admin/v1/notification-tasks`
    routes preserved in `notification/transport/admin/task_*`
  - dispatch-due compensates both immediate `send_at IS NULL` pending tasks and due scheduled tasks
  - schedule registration is owned by `cron_task.name=notification_task_scheduler` Go registry in `admin-worker`
- Frontend:
  - adapted: publish page uses Go REST typed client, no legacyRequest
  - NotificationRuntime shows every `notification.created.v1` instead of filtering normal notices
- Tests:
  - `internal/module/notification`, `internal/module/notification/task`, `internal/shared/i18n`, `internal/jobs`,
    `internal/server`, `internal/bootstrap`
  - frontend vue-tsc + targeted eslint
- Smoke:
  - full smoke read-only probes init/status-count/list
  - backend full test suite and route snapshot preserve API surface
  - manual e2e verified task create -> worker send -> WebSocket `notification.created.v1`
- Docs: contract + notification task spec/plan + smoke matrix + backend architecture
- Risk:
  - DB+queue is not transactional
  - outbox planned if stronger consistency is needed
  - Redis Pub/Sub realtime fan-out implemented for admin notification.created.v1

## System operations, observability, and admin maintenance

### system logs

- Backend:
  - implemented baseline: slog stdout + default-on lumberjack file output, process-specific api/worker log files,
    code-owned rotation/tail/extension policy, Docker env only keeps LOG_DIR, read-only logstore, REST files/lines
    API with path traversal guard, localized backend error keys
- Frontend: adapted to Go REST API
- Tests:
  - `internal/infra/logstore`, `internal/infra/logging`, `internal/config`, `internal/module/systemlog`,
    `internal/server`
- Smoke: full smoke probes init/files shape and conditionally probes lines when a log file exists
- Docs: architecture + contract + plan + smoke matrix
- Risk:
  - first phase is read-only
  - no ELK/Loki, no delete/clear/download

### operation log

- Backend:
  - implemented: explicit route metadata plus request/response JSON capture with sanitization, 64KB cap, and
    localized backend error keys
- Frontend: adapted: list summary reads real request payload / response data and detail dialog formats JSON
- Tests:
  - `internal/module/operationlog`, `internal/middleware`, `internal/server`
  - frontend payload formatter Vitest
- Smoke: full smoke covers init/list/create-triggered log/delete
- Docs: architecture + contract + smoke matrix
- Risk: old historical rows may not have captured payload before middleware hardening

### system cron tasks

- Backend:
  - implemented: REST `cron_task` CRUD/logs + DB-backed worker scheduler registration
  - handler/service public errors carry localized zh-CN/en-US keys
  - active Go tasks are `notification_task_scheduler -> notification:dispatch-due:v1`, `ai_run_timeout ->
    ai:run-timeout:v1`, `payment_sync_pending_order -> payment:sync-pending-order:v1`, and
    `payment_close_expired_order -> payment:close-expired-order:v1`
  - `clean_expired_contact_request` is retired from active rows by cleanup migration
- Frontend:
  - adapted: cron task page uses Go REST, no `legacyRequest`, no “接入状态” column, and displays `handler`
    as the Go task type
- Tests:
  - `internal/module/crontask`, `internal/shared/i18n`, `internal/jobs`, `internal/bootstrap`, `internal/server`
  - frontend `tests/shared/system/cron-task-api.test.ts`
- Smoke:
  - full smoke probes init/list/logs and asserts the four active tasks return versioned task type handlers
  - backend full test suite
- Docs: admin API contract + backend architecture + smoke matrix
- Risk:
  - payment cron is Alipay recharge completion compensation only
  - refund/reconcile/WeChat/business fulfillment remain out of scope
  - worker still needs restart for schedule changes

### queue / worker / monitor

- Backend:
  - implemented baseline: producer/consumer wrapper, handler registry, DB-backed cron-to-queue boundary via system
    cron tasks, Redis-backed scheduler lock wrapping, read-only Asynq inspector summary, localized backend error
    keys, official `asynqmon` mounted at `/api/admin/v1/queue-monitor-ui/*`
- Frontend: adapted as thin iframe/new-window wrapper, no duplicate task-list UI
- Tests:
  - `internal/infra/taskqueue`, `internal/infra/scheduler`, `internal/infra/redislock`, `internal/jobs`,
    `internal/bootstrap`, `internal/module/queuemonitor`
  - frontend queue monitor contract test
- Smoke:
  - login log worker path + full smoke queue monitor read-only probe
  - scheduler lock covered by infra scheduler tests
- Docs: architecture + contract + smoke matrix
- Risk:
  - asynqmon is read-only and must be re-tested on Asynq upgrades
  - worker hot reload and DB+queue outbox remain planned

### system settings

- Backend:
  - implemented: REST init/list/create/update/status/delete, enum-backed value type dict, typed value validation,
    localized backend error keys, Redis setting-cache invalidation, legacy queue monitor setting excluded
- Frontend: adapted to Go REST API
- Tests:
  - `internal/module/systemsetting`, `internal/shared/enum`, `internal/shared/dict`, `internal/shared/validate`,
    `internal/server`, `internal/bootstrap`
  - frontend typecheck/lint
- Smoke: full smoke probes init/list shape
- Docs: contract + foundation plan + smoke matrix
- Risk:
  - `devtools_queue_monitor_queues` old row should be soft-deleted
  - do not turn generic settings into a dumping ground

### client version management

- Backend:
  - implemented: backend module `internal/module/clientversion`, enum/dict/validate, REST
    `/api/admin/v1/client-versions`, public `current-check`, COS manifest publisher, route permission + OperationLog
    metadata, localized backend error keys
- Frontend:
  - adapted: version page and TauriManager use `src/api/system/clientVersion.ts` with Go REST `request`, no
    legacyRequest
- Tests:
  - `internal/shared/enum`, `internal/shared/dict`, `internal/shared/validate`, `internal/infra/storage/cos`,
    `internal/module/clientversion`, `internal/bootstrap`, `internal/server`
- Smoke: full smoke probes page-init/list/update-json read-only
- Docs: client version spec/plan + admin API contract
- Risk:
  - server-side manifest publish currently supports COS only
  - DB table is `client_versions` and button permission codes are `system_clientVersion_*`
  - old Tauri names only remain in legacy source references

## Upload and storage boundary

### upload config

- Backend:
  - implemented: REST upload-drivers/upload-rules/upload-settings, APP_SECRET-derived secretbox, enum/dict/validate,
    setting exclusive enable transaction, route permission + operation log metadata
- Frontend: adapted to Go REST typed API/components
- Tests:
  - `internal/module/uploadconfig`, `internal/infra/secretbox`, `internal/shared/enum`, `internal/shared/dict`,
    `internal/shared/validate`, `internal/server`, `internal/bootstrap`
  - frontend typecheck/lint
- Smoke:
  - full smoke probes init/list always
  - disabled temp write probe runs after API startup validates APP_SECRET
- Docs: contract + upload foundation spec/plan + smoke matrix
- Risk:
  - config is Tencent COS-only
  - `bucket_domain` must be a bare host and runtime builds HTTPS public URLs
  - changing APP_SECRET requires encrypted secret re-entry
  - historical OSS rows are disabled by migration and are not selectable in V1

### upload runtime/token

- Backend:
  - implemented: `POST /api/admin/v1/upload-tokens`, COS-only STS signing, server-generated key,
    folder/ext/size/rule validation, localized backend error keys, bearer-token current-user capability with no RBAC
    button rule and no OperationLog metadata, no legacy fallback
- Frontend:
  - adapted: shared upload client uses Go REST + `cos-js-sdk-v5` only
  - non-COS runtime rows are rejected explicitly
- Tests:
  - `internal/module/uploadtoken`, `internal/infra/storage/cos`, `internal/config`, `internal/bootstrap`,
    `internal/server`, `internal/shared/validate`
  - frontend `src/api/system/uploadToken.ts`, `src/lib/upload/uploadClient.ts`
- Smoke:
  - full smoke token probe skips only when no enabled upload setting exists
  - otherwise validates token shape only
- Docs: contract + architecture + smoke matrix
- Risk:
  - no OSS runtime
  - upload token is the client-upload path
  - server-side modules use the same Tencent COS config through COS SDK boundaries
  - real client upload requires enabled COS upload setting and valid Tencent credentials
  - upload token TTL comes from `system_settings.upload.token.ttl_minutes`
  - Tencent STS API endpoint/region are code-owned implementation details

## Payment and wallet

### payment config + recharge cashier Alipay v1

- Backend:
  - implemented: `internal/module/payment` owns Alipay config CRUD, private local certificate upload, local config
    test, recharge cashier, low-level payment order runtime, public Alipay callback, callback audit, shared paid
    finalizer, wallet balance and wallet transaction crediting
  - active payment tables are `payment_configs`, `payment_orders`, `payment_recharge_packages`, `payment_recharges`,
    and `payment_callback_events`
  - recharge credit also writes shared `user_wallets` / `wallet_transactions`
  - `payment_configs.sort` selects the preferred enabled Alipay config
  - recharge REST supports page-init/list/detail/create/pay/sync/close
  - callback/manual sync/cron compensation share transaction-protected idempotent crediting via
    `wallet_transactions(source_type, source_id)`
  - expired Alipay `ACQ.TRADE_NOT_EXIST` rows close the local order and linked recharge instead of retrying forever
- Frontend:
  - adapted: active product pages are `/payment/config`, `/payment/recharge`, and `/payment/orders`
  - `/payment/recharge` reopen auto-syncs a small batch of visible paying records
  - `/payment/orders` is the visible Alipay/gateway collection-order ledger without raw create UX
  - active files include `src/api/payment/config.ts`, `src/api/payment/recharges.ts`, `views/Main/payment/config`,
    `views/Main/payment/recharge`, and a read/operation-only `views/Main/payment/orders`
  - channel/event/old wallet pages stay retired
- Tests:
  - `internal/module/payment`, `internal/infra/payment`, `internal/infra/payment/alipay`, `internal/bootstrap`,
    `internal/server`
  - frontend payment config/order/recharge Vitest + vue-tsc
- Smoke:
  - full smoke read gate probes payment config page-init/list, payment recharge page-init/list, payment order
    page-init/list, users/init visible `/payment/config` + `/payment/recharge` + `/payment/orders`, and cron
    registry for payment compensation
  - default smoke does not upload certs, call config test, create real paid orders, call real Alipay, write paid
    state, or invoke the real Alipay callback
  - credential-gated manual smoke may create sandbox recharge/pay/sync
- Docs:
  - payment config/order/recharge specs/plans + recharge completion closure spec/plan + admin API contract + smoke
    matrix
- Risk:
  - Alipay only
  - no refund, reconcile, WeChat, subscription, or business fulfillment in this slice
  - user consume belongs to wallet, not `payment_orders`
  - `private_key_enc`/plaintext key/cert content/raw callback payload must never leak
  - `return_url` belongs to each recharge/payment order, not `payment_configs`

### wallet recharge/consume v1

- Backend:
  - implemented: `internal/module/payment/wallet` owns wallet summary, current-user transactions, admin wallet
    users, admin ledger, and guarded current-user consume
  - wallet now lives under `admin_back_go/internal/module/payment/wallet` while package identifiers and `wallet.*`
    i18n keys remain stable
  - `user_wallets.total_consume_cents` records cumulative spend
  - consume uses a DB transaction, row lock, positive amount, `source_type=consume + source_id` idempotency, balance
    check, and `wallet_transactions(direction=out)`
- Frontend:
  - adapted: `/wallet/transactions`, `/wallet/users`, and `/wallet/ledger` use typed `src/api/wallet`, `Search`,
    `AppTable`, `useTable`, and Vue i18n
  - `/payment/recharge` wallet summary also includes cumulative consume
- Tests:
  - `internal/module/payment/wallet`, `internal/module/payment`, `internal/server`, `internal/bootstrap`,
    `internal/shared/i18n`
  - frontend wallet API/page Vitest + `vue-tsc`
- Smoke:
  - full smoke read gate probes wallet summary, current-user transactions, wallet users init/list, wallet ledger
    init/list, and users/init visible `/wallet/transactions`, `/wallet/users`, `/wallet/ledger`
  - default smoke does not call consume
- Docs: wallet recharge/consume spec/plan + admin API contract + smoke matrix
- Risk:
  - v1 intentionally excludes refund, withdraw, freeze, manual adjustment, reconcile, currency, points, membership
    fulfillment, and `/wallet/recharge` migration
  - `wallet_consume_add` is not granted by default

## AI suite and realtime conversation runtime

### AI provider config / OpenAI first slice

- Backend:
  - implemented for the first AI menu only: MySQL MCP snapshot `docs/db/ai-live-schema-mcp-2026-05-10.md` verifies
    `ai_providers` + `ai_provider_models` as the live provider tables
  - tracked schema files in this repo are not treated as the source for table count. Active provider-config backend
    is `internal/module/ai/provider` plus `internal/infra/ai/provider`
  - first driver is exactly `openai`
  - API key is encrypted server-side and never returned. Provider config has no default-model concept
  - agent config owns concrete model selection. MCP live columns confirm `ai_provider_models` has no `raw_json` /
    `source` / soft-delete history / fake auditors and `ai_providers` has no provider dumping-ground `config_json`.
- Frontend:
  - adapted for provider config page: AI product menu order is `/ai/providers`, `/ai/agents`, `/ai/knowledge`,
    `/ai/tools`, `/ai/runs`, `/ai/chat`
  - `src/api/ai/providers.ts` exposes `openai` only, create/edit preview, saved-key edit preview,
    sync/model-list/update-model APIs, `model_ids/model_display_names`, and no secret/raw/source/config JSON
    response fields.
- Tests:
  - `internal/infra/ai/provider`, `internal/module/ai/provider`, route/meta/router tests
  - frontend AI provider API Vitest + `npm run build:check`
- Smoke:
  - basic/full smoke users/init gate requires providers/agents/knowledge/tools/runs/chat order and rejects retired
    goods/cine/model/agent/prompt entries
  - full smoke provider read gate requires driver `openai`, health/model-sync statuses `unknown/ok/failed`, and no
    plaintext/encrypted key/raw/source/config leaks
- Docs: OpenAI provider config spec/plan + admin API contract + smoke matrix
- Risk:
  - live OpenAI `/models` and provider test are credential-gated
  - provider config remains separate from agent/tool/knowledge/chat runtime slices

### AI agent config MVP

- Backend:
  - implemented: active module is `internal/module/ai/agent`
  - active table is `ai_agents`
  - REST is `/api/admin/v1/ai-agents`
  - create/update require name, provider-owned enabled `model_id`, scenes, and status
  - list supports scene search for `chat`, `agent_generate`, and `image_generate`
  - options defaults to enabled `chat` scene agents and accepts `scene=image_generate` for the image playground
  - service stores only MVP metadata: `model_display_name`, `scenes_json`, optional `system_prompt`, and optional
    `avatar`
  - old app/binding naming is not the active contract
  - agent code, agent type, per-agent external app id/key, response mode, runtime config JSON, model snapshot JSON,
    `created_by`, and `updated_by` are intentionally not part of the MVP table
- Frontend:
  - adapted: `src/api/ai/agents.ts` uses Go REST only, page route is `/ai/agents`, search supports
    name/scene/provider/status, form uses name input, model cascader, scene `el-select-v2` multiple default `chat`
    and includes `智能体生成` / `图片生成`, status select, system prompt textarea, `UpMedia` avatar, tool configuration, and
    knowledge-base binding dialog
- Tests:
  - `internal/module/ai/agent`, `internal/bootstrap`, `internal/server`
  - frontend `tests/shared/ai/ai-agent-api.test.ts`, `vue-tsc`, `npm run build:check`
- Smoke:
  - full smoke read gate now asserts `scene_arr`, `provider_model_options`, `image_generate` scene-filter
    list/options, optional tool binding, optional knowledge binding, and list MVP fields `model_id` / `scenes` /
    `system_prompt` / `avatar` without code/type/key/config leaks
- Docs: admin API contract + smoke matrix + backend architecture
- Risk:
  - config MVP is done
  - chat page consumes option avatar/system_prompt and agent config page now owns tool/knowledge usage binding

### AI image playground gpt-image-2

- Backend:
  - implemented: active tables are `ai_image_tasks`, `ai_image_assets`, and `ai_image_task_assets`
  - active module is `internal/module/ai/image`
  - route group is `/api/admin/v1/ai-images`
  - image generation is asynchronous through Redis/Asynq task `ai:image-generate:v1`
  - service accepts only enabled `ai_agents` with `scene=image_generate`, OpenAI-compatible provider, and
    `model_id=gpt-image-2`
  - generated b64 outputs are archived to COS and remote URL outputs are kept as remote assets
  - OperationLog route metadata skips request/response payload capture for prompt/image safety
- Frontend:
  - adapted: `/ai/image-playground` resolves to `src/views/Main/ai/image-playground/index.vue`, selects an image
    agent only, uploads reference/mask images via existing COS-only upload-token runtime, registers assets, submits
    tasks, lists history, opens detail, reuses prompts/assets, toggles favorite, deletes, and downloads outputs
  - no provider/model/API-key UI, no IndexedDB/localStorage source of truth
- Tests:
  - `internal/module/ai/image`, `internal/infra/ai/imagecompat`, `internal/infra/storage/cos`, `internal/bootstrap`,
    `internal/jobs`, `internal/server`
  - frontend `src/api/ai/images.ts`, `src/views/Main/ai/image-playground/*`, `tests/shared/ai/ai-image-api.test.ts`,
    `vue-tsc`
- Smoke:
  - full smoke probes `ai-agents?scene=image_generate`, `ai-agents/options?scene=image_generate`,
    `ai-images/page-init`, `ai-images` list, and optional detail when a task exists
  - actual provider generation needs configured agent + worker + COS
- Docs: AI image playground spec/plan + admin API contract + smoke matrix
- Risk:
  - no multi-model selector, no custom provider UI, no provider-key browser storage, no IndexedDB primary store
  - real image generation requires an enabled queue worker, Tencent COS upload config, and a valid `gpt-image-2`
    agent
  - upload runtime is Tencent COS-only
  - `bucket_domain` is stored as a bare host and runtime builds HTTPS public URLs

### AI run monitor token-only MVP

- Backend:
  - implemented: active lifecycle tables are `ai_runs` and `ai_run_events`
  - `aichat` creates one run per user message, writes lifecycle events `start/completed/failed/canceled/timeout`,
    records prompt/completion/total tokens and duration, links persisted user/assistant messages, and never persists
    WebSocket delta
  - stream timeout governance is layered: online stream max/idle timeout and stale-run cron cleanup are separate
  - detail additionally reads `ai_tool_calls` and `ai_knowledge_retrievals`/`ai_knowledge_retrieval_hits` as
    separate audit blocks
  - no daily aggregate table, billing amount, provider task ids, execution-step timeline, usage dumps, or snapshot
    JSON
- Frontend:
  - adapted: `/ai/runs` uses Go REST typed client with `status`, `model_id/model_display_name`,
    `duration_ms/duration_text`, `error_message`, lifecycle event `message`, `avg_duration_ms`, `tool_calls`, and
    `knowledge_retrievals`
  - old status/model/duration/error/event-payload aliases and execution-step UI are removed
- Tests:
  - `internal/shared/enum`, `internal/shared/dict`, `internal/module/ai/chat`, `internal/module/ai/run`,
    `internal/module/ai/knowledge`
  - frontend `src/api/ai/runs.ts`, `src/views/Main/ai/runs/*`, `vue-tsc`
- Smoke:
  - full smoke read gate covers page-init/list/stats shape and optional run detail
    `tool_calls`/`knowledge_retrievals`
  - unit tests cover runtime writes, terminal statuses, timeout marker, stale-only sweeper cutoff, monitor
    aggregates, tool calls, and knowledge retrieval detail
- Docs: AI run monitor spec/plan + AI knowledge RAG spec/plan + admin API contract + smoke matrix + backend architecture
- Risk:
  - token-only stats are done
  - no billing, provider task replay, or daily aggregate table in this slice

### AI tool runtime MVP

- Backend:
  - implemented: active tables are `ai_tools`, `ai_agent_tools`, and `ai_tool_calls`
  - active module is `internal/module/ai/tool`
  - seed tool `admin_user_count` is read-only low-risk and returns only `total_users/enabled_users/disabled_users`
  - `aichat` loads enabled agent tool bindings, sends structured function tools to the OpenAI-compatible provider,
    executes one tool-call round, stores every call in `ai_tool_calls`, then sends tool output back for the final
    assistant answer
  - AI tool generation uses existing `agent_generate` agents to return a draft only and does not insert `ai_tools`
  - no `ai_tools.executor` duplicate field, no `ai_agents` tool JSON field, and no old tool-map active runtime
- Frontend:
  - adapted: `/ai/tools` is tool definition management only and has an RBAC-gated `AI生成` draft dialog
  - generated drafts fill the existing add form and final save still uses `POST /api/admin/v1/ai-tools`
  - `/ai/agents` owns tool usage configuration through `GET/PUT /api/admin/v1/ai-agents/:id/tools`
  - `/ai/runs` detail renders `tool_calls` with arguments/result/error/duration
- Tests:
  - `internal/module/ai/tool`, `internal/module/ai/chat`, `internal/module/ai/run`,
    `internal/infra/ai/openaicompat`, `internal/server`, `internal/bootstrap`
  - frontend `src/api/ai/tools.ts`, `src/views/Main/ai/tools/*`, `src/api/ai/agents.ts`,
    `src/views/Main/ai/agents/*`, `src/api/ai/runs.ts`, `src/views/Main/ai/runs/*`
- Smoke:
  - full smoke probes `/ai-tools/page-init`, `/ai-tools/generate/page-init`, `/ai-tools`, optional
    `/ai-agents/:id/tools` when an agent option exists, and run detail `tool_calls` when a run exists
  - focused tests cover internal dispatch, binding, provider tool-call shape, generate-draft contract, and monitor
    detail
- Docs:
  - AI tool runtime spec/plan + AI tool generate-draft plan + admin API contract + smoke matrix + backend
    architecture
- Risk:
  - MVP intentionally excludes external HTTP tools, MCP, RAG, write-operation tools, manual execute button, billing,
    multi-round tool loops, and persistent run-monitor rows for admin-side draft generation

### AI knowledge base RAG MVP

- Backend:
  - implemented: active tables are `ai_knowledge_bases`, `ai_knowledge_documents`, `ai_knowledge_chunks`,
    `ai_agent_knowledge_bases`, `ai_knowledge_retrievals`, and `ai_knowledge_retrieval_hits`
  - active module is `internal/module/ai/knowledge`
  - `/api/admin/v1/ai-knowledge-bases` manages local bases/documents/chunks/retrieval tests
  - `/api/admin/v1/ai-agents/:id/knowledge-bases` stores which knowledge bases an agent can read
  - `aichat` retrieves bound knowledge before provider call, injects selected context only into the current model
    input, and writes retrieval/hit audit rows
  - no vector DB, no hosted file_search, no Dify/RAGFlow dataset sync, no `ai_agents` knowledge JSON
- Frontend:
  - adapted: `/ai/knowledge` uses `src/api/ai/knowledge.ts` and split Vue components for base list, base form,
    document panel, document form, chunks, and retrieval test
  - `/ai/agents` adds knowledge binding dialog with per-base top_k/min_score/max_context_chars/status
  - `/ai/runs` detail renders `knowledge_retrievals` before tool calls
- Tests:
  - `database/migrations/20260510_ai_knowledge_rag.sql`, `internal/module/ai/knowledge`, `internal/module/ai/chat`,
    `internal/module/ai/run`, `internal/server`, `internal/bootstrap`
  - frontend `src/api/ai/knowledge.ts`, `src/views/Main/ai/knowledge/*`, `src/api/ai/agents.ts`,
    `src/views/Main/ai/agents/*`, `src/api/ai/runs.ts`, `src/views/Main/ai/runs/*`
- Smoke:
  - full smoke probes knowledge init/list/seed presence
  - focused tests cover chunking, retrieval scoring/context, CRUD/binding/runtime retrieval, chat injection/failure
    continuation, run detail retrievals, frontend API contracts, and vue-tsc
- Docs: AI knowledge RAG spec/plan + admin API contract + smoke matrix + backend architecture
- Risk:
  - local deterministic retrieval is MVP quality
  - semantic embeddings/vector DB/OCR/multi-tenant isolation are intentionally out of scope

### realtime / WebSocket / AI conversation

- Backend:
  - implemented baseline plus restored old-admin conversation UX: gorilla/websocket thin wrapper, authenticated
    admin ws route, path-scoped browser cookie auth for `/api/admin/v1/realtime/ws`, explicit Origin allowlist,
    local connection manager, bounded send queue, read/write pump, connected event, ping/pong, identity topic
    subscribe whitelist, local/no-op/redis Publisher boundary, Redis Pub/Sub notification fan-out,
    conversation-scoped AI `ai.response.start/delta/completed/failed.v1` publication, in-process reply dispatcher
    cancel by `conversation_id + request_id`, configured live reply max duration, provider stream idle timeout
    without 30s HTTP total timeout, `ai_messages.meta_json` for explicit attachments/runtime params,
    OpenAI-compatible vision content and `temperature/max_tokens/max_history` passthrough, typed REALTIME config,
    localized disabled 503 and missing-identity errors
- Frontend:
  - adapted baseline plus restored chat surface: Vue client uses Go WS URL/envelope, removes legacy
    `/api/admin/WebSocket/bind`, message bus accepts `ai.response.start/delta/completed/failed.v1`, AI chat page
    uses `/ai-conversations/:id/messages` + `/messages/cancel` + shared WebSocket only, switches agent-scoped
    conversations/messages without interrupting other agent sessions, moves conversation list into a drawer,
    restores image upload/paste/drag, emoji, voice input, runtime params, local stop ignoring late events, and no
    longer uses SSE/streamable polling/run events
- Tests:
  - `internal/infra/realtime`, `internal/module/realtime`, `internal/module/ai/chat`,
    `internal/module/ai/conversation`, `internal/module/ai/message`, `internal/module/ai/agent`,
    `internal/bootstrap`, `internal/config`, `internal/server`, `internal/infra/ai/openaicompat`,
    `internal/shared/i18n`
  - frontend AI REST/WebSocket/input/session Vitest + vue-tsc/build
- Smoke:
  - basic smoke covers backend connect/ping/pong
  - full smoke covers AI conversation/read probes
  - tests cover subscribe reject, disabled route, local/noop/redis publisher selection, browser cookie auth/origin
    policy, localized disabled/missing-identity responses, frontend URL/envelope cleanup, conversation event
    dispatch, session LRU pending preservation, restored input tools, dispatcher cancellation, OpenAI stream
    idle/usage request behavior, OpenAI vision request shape, and message meta persistence
- Docs: architecture + realtime/API contract + smoke matrix + AI conversation spec/plan
- Risk:
  - no arbitrary business topic permission yet
  - AI response events are conversation-scoped first-version envelopes only
  - no SSE/EventSource/streamable fallback, no `/ai-chat/runs` browser path, no Redis Stream replay, no real
    provider E2E unless separately configured
  - image upload needs Go upload runtime/COS config
  - OpenAI-compatible `/chat/completions` cancellation is by request context, not provider stop API
  - run monitor stores only final lifecycle/token facts
  - ticket auth still planned for cross-domain/gateway cases

## Removed / retired scope

### admin chat room

- Backend:
  - removed: admin chat is outside current admin scope
  - Go `internal/module/chat` and `/api/admin/v1/chat...` routes are deleted
  - DB schema file `admin_back_go/database/migrations/20260507_remove_admin_chat.sql` removes `chat_*` tables and
    chat menu/role grants
- Frontend:
  - removed: `admin_front_ts/src/views/Main/chat`, `src/api/chat`, `src/store/chat.ts`, `tests/shared/chat`, and
    `menu.chat` i18n are deleted
  - AI chat stays under `src/views/Main/ai/chat` + `src/api/ai/chat.ts`
- Tests:
  - route/module deletion plus residue scans
  - normal backend/frontend build gates
- Smoke:
  - no smoke
  - no active admin chat path remains
- Docs: admin API/realtime contracts + schema deletion
- Risk:
  - destructive schema change drops chat history tables by product decision
  - do not confuse with AI chat
