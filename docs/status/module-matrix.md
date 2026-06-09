# Admin Go/Vue Runtime Module Index

状态更新时间：2026-06-09

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
  - `wallet recharge + debit/credit v1`
- AI suite and realtime conversation runtime:
  - `AI provider config / OpenAI first slice`
  - `AI agent config MVP`
  - `AI image playground gpt-image-2`
  - `AI run monitor unified provider-attempt MVP`
  - `AI tool runtime MVP`
  - `AI knowledge base RAG MVP`
  - `realtime / WebSocket / AI conversation`
- Canvas frontend runtime:
  - `canvas_front_next / canvas platform API`
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
  - implemented: users/me exposes router + BUTTON-only buttonCodes
  - PermissionCheck uses internal RouteAccessCodes so PAGE read routes remain protected without leaking PAGE code
    into frontend button visibility
- Frontend: adapted: role editor labels PAGE grants as 页面访问 and maps it to real PAGE permission_id
- Tests:
  - `internal/module/user`, `internal/module/permission`, `internal/module/role`, `internal/bootstrap`
  - frontend role matrix tests
- Smoke: users/me
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
  - export submit creates `export_tasks` pending row with `kind=user_list` and `platform=admin`, then enqueues `export:run:v1` low queue
- Frontend:
  - adapted for user manager page
  - export button uses Go REST `POST /api/admin/v1/users/export`, keeps `user_userManager_export`, and now goes through shared `useExportSubmit`
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
  - removed: fast-entry/shortcut-entry current-user write route and persistence are no longer part of the product contract.
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
  - runtime is registry-driven: provider registration lives in bootstrap, queries are scoped by `user_id + platform + kind`, and success rows persist `object_key/file_url/file_size/row_count`
  - worker handles `kind=user_list`, writes xlsx with string cells, uploads to current COS under `exports/<kind>/YYYYMMDD/...`, marks success/failed, sends notification, and returns localized backend error keys
- Frontend:
  - adapted: `src/api/system/exportTask.ts` uses Go REST `request`, no legacy export-task adapter
  - export task list/status query now supports `kind`; item shape includes `kind/kind_text`; delete APIs expose standard `deleteOne/deleteBatch` methods only
- Tests:
  - `internal/module/export`, `internal/jobs`, `internal/bootstrap`, `internal/server`
  - frontend `tests/shared/system/export-task-api.test.ts`, `tests/shared/system/export-submit-helper.test.ts`
- Smoke:
  - full smoke read-only probes status-count/list with `kind=user_list`
  - route snapshot and backend full tests preserve API surface
  - credential-gated `scripts/export-task-smoke.ps1 -RunRealExport` covers submit -> worker -> COS upload when API/worker/Redis/COS secrets are ready
- Docs: contract + backend architecture + smoke matrix
- Risk:
  - current provider coverage is still only `kind=user_list`
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
  - page-init exposes `default_ttl_minutes` only as an unconfigured form seed; runtime email verification-code TTL
    requires an active mail config row and fails explicitly when it is missing
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
  - page-init exposes `default_ttl_minutes` only as an unconfigured form seed; runtime phone/SMS verification-code TTL
    requires an active SMS config row and fails explicitly when it is missing
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
  - active driver DTOs and setting dicts fail closed on non-COS stored drivers instead of returning blank labels or
    bucket-name fallback labels
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
  - enabled COS settings with undecryptable secrets are real failures (`上传密钥不可用`), not skip cases
  - 2026-05-30 live full smoke passed after COS secret re-entry, with `upload_token_probe=passed`,
    `upload_token_code=0`, and `upload_token_provider=cos`; the probe still validates token shape only and does
    not upload a real file
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
  - implemented: `internal/module/payment` owns Alipay config CRUD, private local certificate upload, recharge cashier,
    low-level payment order runtime, public Alipay callback, callback audit, shared paid finalizer, wallet balance, and
    wallet transaction crediting; admin transport owns management routes and canvas transport owns current-user recharge routes
  - active payment tables are `payment_configs`, `payment_orders`, `payment_recharge_packages`, `payment_recharges`,
    and `payment_callback_events`; recharge credit also writes shared `user_wallets` / `wallet_transactions`
  - `payment_configs.sort` selects the preferred enabled Alipay config
  - current admin read surfaces split money facts into `/payment/ledger` and `/payment/wallets`; recharge keeps
    page-init/list/detail/create/pay, while gateway order operations remain backend runtime internals
  - callback/operator gateway query/cron compensation share transaction-protected idempotent crediting via
    `wallet_transactions(source_type, source_id)`
  - existing orders settle against their bound Alipay config even if that config is later disabled or soft-deleted; configs with
    pending/paying orders are locked against mutation, disable, and delete
  - payment order status transitions use CAS guards so pay/fail/close operations do not overwrite already-paid orders
  - CAS misses are treated as state changes, not success: finalizer re-reads before wallet credit and `PayOrder` never returns a stale
    gateway `pay_url` if the local order changed under it
  - recharge paid markers are CAS guarded and wallet credit locks the current recharge row, so a stale callback/query/cron finalizer cannot
    downgrade `credited` back to `paid` or credit a recharge that was closed concurrently
  - Alipay callback audit payload is marshaled as valid JSON after per-field truncation; audit insert failure does
    not block verified settlement
  - callback audit amount parsing shares the strict digit rule for yuan/cent fragments; malformed values such as `10.-1`
    audit as invalid and cannot settle by normalization
  - first wallet creation handles `uk_user_wallet_user` duplicate races by returning the existing wallet instead of surfacing a
    one-off 500
  - wallet transaction number hardening is closed: shared serial generation no longer wraps at one million same-timestamp
    calls and no longer appends a 20-digit zero-padded sequence; debit/credit paths retry `uk_wallet_transaction_no`
    collisions without breaking source idempotency, and recharge credit uses the same bounded retry path
  - Alipay notify amount parsing rejects signed or non-digit cent fragments instead of normalizing malformed values
  - expired Alipay `ACQ.TRADE_NOT_EXIST` rows close the local order and linked recharge instead of retrying forever
- Frontend:
  - Visible menu: 支付管理 -> 支付配置 / 收支明细 / 用户钱包
  - Hidden user route: /profile/wallet
  - Hidden recharge route: /payment/recharge
  - Retired visible entries: /wallet, /wallet-manage, /payment/orders
  - adapted: active product pages are `/payment/config`, `/payment/ledger`, `/payment/wallets`, hidden current-user
    wallet `/profile/wallet`, and hidden recharge cashier `/payment/recharge`
  - `/payment/recharge` opens from `/profile/wallet`, keeps create/pay/list/detail refresh, and does not expose a manual
    gateway status action button
  - `/payment/config` notify URL guidance points at the canonical public callback
    `https://www.zgm2003.cn/api/payment/callbacks/alipay`
  - active files include `src/api/payment/config.ts`, `src/api/payment/recharges.ts`, `src/api/wallet/index.ts`,
    `views/Main/payment/config`, `views/Main/payment/ledger`, `views/Main/payment/wallets`, and
    `views/Main/personal/wallet`
  - channel/event/old wallet/order menu pages stay retired
- Tests:
  - `internal/module/payment`, `internal/infra/payment`, `internal/infra/payment/alipay`, `internal/bootstrap`,
    `internal/server`
  - payment callback/config/state-CAS/wallet-create-race regression tests; frontend payment config/recharge/wallet Vitest,
    eslint + vue-tsc
- Smoke:
  - 2026-05-31 full smoke passed for payment config page-init/list, payment recharge page-init/list, payment ledger
    page-init/list with filters, payment wallets page-init/list with keyword filter, current-user wallet summary/transactions,
    and users/me router/menu state
  - menu gate expects a single visible payment top-level entry with visible children `/payment/config`, `/payment/ledger`,
    and `/payment/wallets`; `/profile/wallet` and `/payment/recharge` are hidden routes
  - default smoke does not upload certs, call config test, create real paid orders, call real Alipay, write paid
    state, or invoke the real Alipay callback
  - credential-gated probes may create sandbox recharge/pay only when explicitly enabled
- Docs:
  - payment config/recharge/wallet redesign specs/plans plus old AI billing retirement plan + recharge completion closure spec/plan + admin API
    contract + smoke matrix
- Risk:
  - Alipay only
  - no refund, reconcile, WeChat, subscription, business fulfillment, manual balance adjustment, points, or canvas credit
    table in this slice
  - old user debit belonged to retired wallet/AI billing, not `payment_orders`; new AI generation is free
  - `private_key_enc`/plaintext key/cert content/raw callback payload must never leak
  - `return_url` belongs to each recharge/payment order, not `payment_configs`

### wallet recharge + debit/credit v1

- Backend:
  - implemented: `internal/module/payment/wallet` owns wallet summary, current-user transactions, admin wallet users,
    admin ledger, and historical debit/credit primitives; admin transport owns admin/current-admin wallet surfaces; Canvas AI generation no longer depends on `/api/canvas/v1/wallet/*`
  - wallet now lives under `admin_back_go/internal/module/payment/wallet` while package identifiers and `wallet.*`
    i18n keys remain stable
  - `user_wallets.total_consume_cents` records cumulative spend
  - internal debit/credit use a DB transaction, row lock, positive amount, source idempotency, duplicate-key race
    recovery, cross-user source ownership rejection, balance check for debit, and `wallet_transactions(direction=in|out)`
- Frontend:
  - adapted: admin wallet reads moved under `/payment/ledger` and `/payment/wallets`; current-user wallet moved to
    hidden `/profile/wallet` and uses typed `src/api/wallet`, `Search`, `AppTable`, `useTable`, and Vue i18n
  - `/payment/recharge` is reached from the current-user wallet recharge button and is not a left-side menu entry
- Tests:
  - verified baseline packages include `internal/module/payment/wallet`, `internal/module/payment`,
    `internal/server`, `internal/bootstrap`, `internal/shared/i18n`
  - transaction number hardening is covered: shared `serialno` no longer wraps at one million calls for the same
    timestamp and no longer appends a 20-digit zero-padded sequence; mutation paths retry `uk_wallet_transaction_no`
    without breaking source idempotency, and `CreditRecharge` retries the same transaction-no collision path
  - frontend wallet API/page Vitest + `vue-tsc`
- Smoke:
  - 2026-05-31 full smoke passed for current-user wallet summary/transactions, payment ledger init/list,
    payment wallets init/list, and users/me payment router/menu state
  - default smoke does not call internal debit/credit
- Docs: wallet recharge/debit-credit + payment-wallet redesign spec/plan + old AI billing retirement plan + admin API contract + smoke matrix
- Risk:
  - v1 intentionally excludes refund, withdraw, freeze, manual adjustment, reconcile, currency, points, membership
    fulfillment, and `/wallet/recharge` migration
  - no public current-user consume HTTP route remains in the active product contract

## AI suite and realtime conversation runtime

### AI provider config / OpenAI first slice

- Backend:
  - implemented for the first AI menu only: MySQL MCP snapshot `docs/db/ai-live-schema-mcp-2026-05-10.md` verifies
    `ai_providers` + `ai_provider_models` as the live provider tables
  - tracked schema files in this repo are not treated as the source for table count. Active provider-config backend
    is `internal/module/ai/provider` plus `internal/infra/ai/provider`
  - first provider `engine_type` is exactly `openai`; `driver`/`driver_name` aliases are not part of the active API
  - API key is encrypted server-side and never returned. Provider config has no default-model concept
  - list DTO fails closed on invalid stored `engine_type`, health/model-sync status, provider status, or provider-model
    status instead of inventing `unknown` or blank labels
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
  - fallback hardening covers canonical `engine_type` only and invalid stored provider/model status fail-closed behavior
  - frontend AI provider API Vitest + `npm run build:check`
- Smoke:
  - basic/full smoke users/me gate requires providers/agents/knowledge/tools/runs/chat order and rejects retired
    goods/cine/model/agent/prompt entries
  - full smoke provider read gate requires `engine_type=openai`, health/model-sync statuses `unknown/ok/failed`, and no
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
  - list supports scene search for `chat`, `agent_generate`, `canvas_text_generate`, `canvas_image_generate`, and `canvas_video_generate`; the retired non-Canvas image scene is rejected
  - options defaults to enabled `chat` scene agents and accepts Canvas scene filters only for Canvas runtime selectors
  - service stores only MVP metadata: `model_display_name`, `scenes_json`, optional `system_prompt`, and optional
    `avatar`
  - old app/binding naming is not the active contract
  - agent code, agent type, per-agent external app id/key, response mode, runtime config JSON, model snapshot JSON,
    `created_by`, and `updated_by` are intentionally not part of the MVP table
- Frontend:
  - adapted: `src/api/ai/agents.ts` uses Go REST only, page route is `/ai/agents`, search supports
    name/scene/provider/status, form uses name input, model cascader, scene `el-select-v2` multiple default `chat`
    and includes `工具生成` plus Canvas text/image/video scene options, status select, system prompt textarea, `UpMedia` avatar, tool configuration, and
    knowledge-base binding dialog
- Tests:
  - `internal/module/ai/agent`, `internal/bootstrap`, `internal/server`
  - frontend `tests/shared/ai/ai-agent-api.test.ts`, `vue-tsc`, `npm run build:check`
- Smoke:
  - full smoke read gate now asserts `scene_arr`, `provider_model_options`, Canvas scene-filter
    list/options, optional tool binding, optional knowledge binding, and list MVP fields `model_id` / `scenes` /
    `system_prompt` / `avatar` without code/type/key/config leaks
- Docs: admin API contract + smoke matrix + backend architecture
- Risk:
  - config MVP is done
  - chat page consumes option avatar/system_prompt and agent config page now owns tool/knowledge usage binding
  - Old AI billing rules are retired; AI agent config now owns runtime scene/model selection only.
  - Canvas frontend integration is now tracked under `canvas_front_next / canvas platform API`; Admin AI image interaction is retired.

### AI prompt/asset convergence and Canvas asset ownership

- Backend:
  - implemented: prompt ownership is `internal/module/ai/prompt`, with Admin transport `/api/admin/v1/ai-prompts` and Canvas transport preserving `/api/canvas/v1/prompts`.
  - implemented: asset ownership is `internal/module/ai/asset`, but only Canvas exposes `GET/POST/PUT/DELETE /api/canvas/v1/assets`; Admin `/api/admin/v1/ai-assets*` transport/routes/menu permissions are retired.
  - `ai_assets.user_id` is the ownership boundary. Canvas handlers derive `user_id` from the authenticated Canvas token and repository writes/updates/deletes are guarded by `id + user_id + is_del`.
  - active tables are `ai_prompts` and user-owned `ai_assets`; legacy `canvas_prompts` / `canvas_assets` were backed up and dropped by `20260608_ai_prompt_asset_drop_legacy.sql`.
  - no public/shared asset library exists; do not use `user_id=0` as a shared-library convention.
- Frontend:
  - Admin Vue keeps prompt management under `src/views/Main/ai/prompts` and typed client `src/api/ai/prompts.ts`; Admin asset management page/API files are removed.
  - Canvas Next asset picker only shows “我的素材”; `fetchAssetLibrary` / `library` tab / `/asset-library` route aliases are negative-guarded.
  - Canvas image 403 handling uses structured auth/RBAC classification and keeps provider/business 403 as local image workflow errors.
- Tests:
  - backend targeted AI asset/canvas/image/server/bootstrap/architecture tests, Admin Vue `npm test` + `npm run typecheck`, and Canvas Next `npm test` + `npm run typecheck` cover this slice.
- Docs:
  - admin API contract, generated route/API/schema/module artifacts, current-status, and this module matrix are refreshed on 2026-06-08.
- Risk:
  - existing historical `ai_assets` rows without an owner are soft-deleted by migration; runtime must not query them as public assets.
  - Legacy `canvas_prompts` / `canvas_assets` retirement is verified by the 2026-06-08 backend cleanup migration and refreshed live schema.

### AI image generation

- Backend:
  - implemented: `internal/module/ai/image` owns image generation runtime for Canvas. Active HTTP surface is Canvas `GET/POST/DELETE /api/canvas/v1/ai/images*`; Admin `/api/admin/v1/ai-images*` transport/routes/menu permissions are retired.
  - active tables remain `ai_image_tasks` and `ai_image_files`; platform/user ownership is expressed by task `platform` / `user_id` columns.
  - retired split tables `admin_ai_image_tasks`, `admin_ai_image_files`, `canvas_image_tasks`, `canvas_image_files`, `ai_image_assets`, and `ai_image_task_assets` are copied into the single tables then dropped by `20260607_ai_image_single_capability_convergence.sql`.
  - image generation is asynchronous through the AI image task handler; provider attempts are recorded by `ai_runs` without source polymorphism.
  - Canvas service accepts agents with `scene=canvas_image_generate`; generated b64 outputs are archived to COS and remote URL outputs are kept as task-owned output files.
- Frontend:
  - Admin Vue 图片工作台 page/API/tests are removed; Admin is a management console, not an interaction studio.
  - Canvas image history is read/deleted through backend `GET/DELETE /api/canvas/v1/ai/images`; browser cache is not used as business persistence.
- Tests:
  - `internal/module/ai/image`, `internal/bootstrap`, `internal/server`, `internal/architecture`, plus Canvas Next image/asset boundary tests.
- Smoke:
  - Admin smoke no longer probes `ai-images*`; Canvas image live generation still requires configured agent + worker + COS/provider fixtures.
- Docs: current status, admin API contract, smoke matrix, and generated artifacts refreshed on 2026-06-08.
- Risk:
  - do not delete `ai_image_tasks` or `ai_image_files`; only the Admin interactive HTTP/UI surface was retired, and `ai_runs` stays a narrow provider-attempt log.
  - real Canvas image generation requires an enabled queue worker, Tencent COS upload config, and a valid Canvas image agent.

## Canvas frontend runtime

### canvas_front_next / canvas platform API

- Backend:
  - implemented: `auth_platforms.canvas` seed and canvas capability permissions, `/api/canvas/v1/auth/*`, `/api/canvas/v1/users/me`, `/api/canvas/v1/profile`, public settings, AI-owned prompts/assets transports, and AI text/image/video generation routes. Old Canvas wallet/recharge UI/routes are retired from the Canvas free-generation surface; payment/wallet基础域 remains outside Canvas AI.
  - route ownership: auth has dedicated `transport/admin`, `transport/app`, and `transport/canvas`; user app owns `/api/app/v1/users/me`, user canvas owns `/api/canvas/v1/users/me`; profile app owns `/api/app/v1/profile`, profile canvas owns `/api/canvas/v1/profile`; Canvas chat/video AI routes are owned by `internal/module/ai/chat|video/transport/canvas`, Canvas image routes are owned by `internal/module/ai/image/transport/canvas`, and Canvas prompt/asset routes are owned by `internal/module/ai/prompt|asset/transport/canvas`; payment/wallet admin routes remain payment-owned, and Canvas AI generation no longer depends on payment/wallet transport.
  - implemented: `permissions/page-init` default platform dictionary includes `admin/app/canvas`; canvas RBAC gates live in `permissions.platform='canvas'` and are not copied into an admin menu tree.
  - planned cleanup: Canvas PAGE rows stay focused on free-generation pages (`canvas_page`, `canvas_image_page`, `canvas_video_page`, `canvas_prompts_page`, `canvas_assets_page`, `canvas_profile_page`) and BUTTON rows stay focused on generation/assets/prompts (`canvas_access`, `canvas_prompt_read`, `canvas_asset_read`, `canvas_ai_image_generate`, `canvas_ai_video_generate`); old wallet/recharge Canvas rows are retired with the old AI billing surface. Canvas auth login `data.user` and `/api/canvas/v1/users/me` return the canonical users/me payload (`user_id`, `username`, `avatar`, `role_name`, `permissions`, `router`, `buttonCodes`) instead of permission alias fields.
  - implemented: `/api/*/auth/login-config` returns `allow_register`; Canvas uses it with login types and slide captcha, and no `/api/canvas/v1/auth/register` route is exposed.
  - implemented: text/image/video generation use backend-managed provider config for free; old `ai_billing_records(platform=canvas)` charge/refund/audit is deleted; image tasks use `ai_image_tasks/ai_image_files` with `platform=canvas`; video binds upstream task id to `canvas_video_tasks.provider_task_id`, stores the AI run binding in `canvas_video_tasks.run_id`, and reads status/content by task ownership (`id + user_id + is_del=2`).
  - partially implemented C2-A: Canvas video accepts explicit `generate_audio` / `watermark` booleans through `/api/canvas/v1/ai/videos` while provider/model dispatch remains backend-owned.
  - implemented: `/api/canvas/v1/settings` exposes selectable AI runtime through `agents.text|image|video` derived from enabled `ai_agents` Canvas-specific scene bindings (`canvas_text_generate`, `canvas_image_generate`, `canvas_video_generate`); old billing-scene metadata is removed and must not be treated as a model source.
  - partially implemented C4-B: Canvas `/api/canvas/v1/assets` image/video create/update payloads now fail closed in `internal/module/ai/asset` unless `url` is present and `content` is strict JSON media metadata with storage-backed `storageKey`, positive `width`/`height`/`bytes`, matching `mimeType`, no unknown top-level metadata fields, and no browser-local short storage keys. This keeps `type` limited to `text|image|video`; audio asset type and DB metadata columns are still not implemented.
  - not implemented in this slice: cloud-synced `canvas_projects`, per-user asset ownership/visibility, and mutation-permission isolation for Canvas “我的素材”.
- Frontend:
  - implemented: `canvas_front_next` is an independent Next.js repo on `master`; source comes from `infinite-canvas/web` but old admin UI and local/custom API-key channel mode are removed.
  - implemented boundary: auth/settings/prompts/assets/profile/text/image/video clients call `/api/canvas/v1/*`; prompt and asset clients are backed by AI module transports; no user-entered provider API key/base URL is used for generation; wallet/recharge UI is removed from Canvas free-generation surface while payment/wallet基础域保留 outside Canvas AI.
  - implemented: Canvas model/agent pickers use only configured `agents.*` options from settings, submit only `agent_id`, and no longer invent `canvas_text_generate` / `canvas_image_generate` / `canvas_video_generate` as selectable models.
  - implemented C2-A boundary: Canvas video UI/API only exposes contract-approved `generate_audio` / `watermark` switches; it does not expose provider/model/API key/base URL override.
  - implemented C2-C boundary: OpenAI-compatible provider failures now extract readable upstream JSON error details, keep API key redaction, and add a friendly hint for reference-video privacy-style messages. This is error-message hardening, not Seedance protocol support.
  - implemented C2-B boundary: Canvas video generation no longer silently drops `referenceVideos` / `referenceAudios`; the frontend API client fails closed before calling `/api/canvas/v1/ai/videos`, and video node metadata records image/video/audio reference origins. This is not reference-media upload or Seedance protocol support.
  - implemented: Canvas login page reads `/api/canvas/v1/auth/login-config`, renders the configured email/phone/password login-type tabs, uses `/api/canvas/v1/auth/send-code` for email/phone code login and `allow_register` auto-open-account semantics, opens slide captcha only after password-login submit, removes standalone register UI/API, and protects `(user)` pages with an auth guard; 401 redirects to login and 403 renders an explicit no-permission state.
  - implemented/planned boundary: Canvas frontend RBAC registry keeps local route labels/icons while route authorization comes from backend `router` paths; session store keeps `routePaths` separate from BUTTON-only `buttonCodes`; `can(code)` reads only `buttonCodes`; top/mobile navigation and route guard use `routePaths`; prompts/assets/settings protected API calls require ready token plus matching BUTTON permission before firing; `/profile` reads/saves through profile service; wallet/recharge account pages and cost wording are removed from the Canvas AI surface.
  - implemented: audio is now a frontend Canvas resource-reference kind for labels (`音频1`), `inputOrder`, config composer token replacement, `NodeGenerationContext.referenceAudios/audioCount`, config input summary, default specs, basic audio node rendering, and storage-backed Audio node hydration through the media local storage resolver. This does not yet include audio upload UI, backend audio generation, or Admin `canvas_audio_generate` scene configuration.
  - partially implemented: current-canvas merge import first slice is wired in the `canvas_front_next` edit page so a canvas ZIP node pack can be appended to the current project; the canvas library import path remains “import as new project” but now uses the shared fail-closed parser/asset restore path. C3-B restores exported blobs under fresh imported storage keys and rewrites imported project storage-key references before merge/import. This is frontend-only C3/C4 import status, not full browser Cine Make workflow, cloud sync, or backend asset ownership remap.
  - partially implemented C4-A: Canvas asset ZIP import/export in `canvas_front_next` now fails closed on malformed `assets.json`, invalid image/video metadata, storageKey/mime/bytes mismatch, duplicate exported storageKey/path, missing declared blobs, ZIP entry size mismatch, orphan file entries, and media assets whose blobs cannot be packaged. This is frontend parser/export hardening only; audio backend asset type remains a future slice.
- Tests:
  - backend focused gates cover architecture migration guards, auth/platform, permission, Canvas service/transport, OpenAI-compatible video adapter, and bootstrap wiring; old wallet/recharge route wiring is not an active Canvas free-generation expectation.
  - frontend gates cover canvas API boundary, auth/RBAC shell behavior, API service behavior, typecheck, and Next build.
  - 2026-06-09 audio resource-reference foundation covered by targeted Canvas Vitest (`canvas-resource-references`, `canvas-node-generation`, `canvas-config-composer`, `canvas-reference-feature-parity`) and `npm run typecheck`.
  - 2026-06-09 audio local hydration covered by targeted Canvas Vitest (`src/app/(user)/canvas/[id]/hydrate-canvas-images.test.ts`) and `npm run typecheck`.
  - 2026-06-09 video advanced params C2-A covered by targeted Canvas Vitest (`src/services/api/video.test.ts`, `tests/shared/canvas-video-advanced-settings.test.ts`), `npm run typecheck`, and focused Go tests for `internal/module/ai/video`, `internal/module/ai/video/transport/canvas`, and `internal/infra/ai/openaicompat`.
  - 2026-06-09 video reference-media fail-closed C2-B covered by targeted Canvas Vitest (`src/services/api/video.test.ts`, `src/app/(user)/canvas/components/canvas-node-generation.test.ts`) and `npm run typecheck`.
  - 2026-06-09 video upstream error detail C2-C covered by focused Go tests for `internal/infra/ai/openaicompat`.
  - 2026-06-09 current-canvas merge import first slice covered by targeted Canvas Vitest for ZIP parse/asset restore, pure merge util behavior, edit-page merge-import wiring, plus `npm run typecheck`.
  - 2026-06-09 current-canvas merge import C3-B storage-key remap covered by targeted Canvas Vitest (`src/app/(user)/canvas/utils/canvas-import.test.ts`, `src/app/(user)/canvas/utils/canvas-merge-import.test.ts`, `tests/shared/canvas-merge-import-wiring.test.ts`) and `npm run typecheck`.
  - 2026-06-09 canvas library import shared parser/remap covered by targeted Canvas Vitest (`tests/shared/canvas-library-import-wiring.test.ts`, `src/app/(user)/canvas/utils/canvas-import.test.ts`) and `npm run typecheck`.
  - 2026-06-09 Canvas ZIP duplicate storageKey/path guard covered by targeted Canvas Vitest (`src/app/(user)/canvas/utils/canvas-import.test.ts`) and `npm run typecheck`.
  - 2026-06-09 asset ZIP import fail-closed C4-A covered by targeted Canvas Vitest (`src/app/(user)/assets/asset-transfer.test.ts`, `tests/shared/ai-asset-backend-persistence.test.ts`, `src/app/(user)/canvas/utils/canvas-import.test.ts`) and `npm run typecheck`.
  - 2026-06-09 asset backend metadata fail-closed C4-B covered by focused Go tests for `internal/module/ai/asset` and `internal/module/ai/asset/transport/canvas`.
- Smoke:
  - live DB migration/query, backend full tests, Next test/typecheck/build, full-admin-smoke, and root governance gates passed on 2026-05-31 for the baseline slice.
  - 2026-06-01 parity verification rebuilt Docker backend, checked `/health` and `/ready`, confirmed protected `/api/canvas/v1/profile` baseline behavior, and passed Next targeted tests/typecheck/build; `/api/canvas/v1/payment/recharges*` is retired from the Canvas AI surface in this slice.
  - 2026-06-01 agent-scene hardening passed backend `go test ./...`, Canvas Next Vitest/typecheck/build, and live DB inspection; the current slice requires only `canvas_*` image/video/text scene assertions for Canvas generation.
- Docs:
  - canvas spec/plan, current-status, module matrix, admin API contract, and smoke matrix; 2026-06-09 infinite-canvas feature extraction spec/plan corrected to treat `E:\GitDownload\infinite-canvas` as read-only comparison source and `E:\admin_go\canvas_front_next` as target.
- Risk:
  - live provider credentials/model availability still determines real text/image/video generation success; provider calls are backend-owned and fail closed without billing refund side effects.
  - video advanced params C2-A is only `generate_audio` / `watermark` request pass-through; C2-B only fails closed on reference video/audio instead of silently dropping them; C2-C only improves upstream error details. Reference video/audio upload, broader Seedance parameter policy, Admin strategy UI, and live provider success remain separate slices.
  - audio resource-reference support is not a completed audio-generation product path; do not expose full audio generation until backend/Admin scene contracts are defined and verified.
  - current-canvas merge import and asset ZIP import fail-closed remain partial slices; browser/manual Cine Make flow, cloud-synced projects, backend asset persistence/ownership remap, audio asset backend type, explicit DB metadata columns, and broader素材/导入产品化 hardening remain unclaimed until separately tested and documented.
  - current Canvas prompt/asset active tables are `ai_prompts` and `ai_assets`; legacy `canvas_prompts` / `canvas_assets` are no longer live tables after the 2026-06-08 cleanup. Canvas video remains in `canvas_video_tasks`; Canvas image history is stored in `ai_image_tasks` / `ai_image_files` with `platform=canvas`; do not add `canvas_users`, `canvas_credit_logs`, `canvas_settings`, `canvas_projects`, or `canvas_wallets` without a new spec.

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
