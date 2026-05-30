# 2026-05 Runtime Change Log

状态更新时间：2026-05-30

本文件从 `docs/status/current-status.md` 分层归档而来，保留 2026-05 已验证运行时变更记录和验证命令。它是历史证据层，不是新的当前事实入口。

当前入口仍然是：

```text
docs/status/current-status.md
docs/status/module-matrix.md
```

## 2026-05-30 COS upload runtime smoke closure

- Re-entered the enabled COS upload driver secrets for the current Docker-first `APP_SECRET`-derived secretbox key.
- Closed `UPLOAD-RUNTIME-001` as a runtime data repair: the previous failure was undecryptable persisted secret blobs, not a code defect.
- Verified with `powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account 15671628271 -Password 123456`; the JSON summary reported `upload_token_probe=passed`, `upload_token_code=0`, and `upload_token_provider=cos`.

## 2026-05-30 AI chat cancel late-event guard

- Fixed `AI-FE-001`: canceled request ids are retained across later successful completions, and late WebSocket user/assistant events can only mutate the matching in-flight request or matching streaming assistant message.
- Added formal Vitest coverage for old canceled request `delta/completed/failed` events after a newer request completes, and for old canceled user-message acknowledgement not clearing a newer request's sending state.
- Fixed frontend paths: `admin_front_ts/src/views/Main/ai/chat/composables/useConversationSessions.ts` and `admin_front_ts/tests/shared/ai/ai-chat-cancel-state.test.ts`.
- Verified with RED/GREEN `npm test -- tests/shared/ai/ai-chat-cancel-state.test.ts`.

## 2026-05-30 payment finalizer state regression hardening

- Fixed a stale finalizer race where a duplicate callback/sync/cron path could observe an old `paying` recharge snapshot after another path already credited the wallet, then write the recharge status back from `credited` to `paid`.
- Added CAS guarding to the recharge paid marker and added current-row guards in wallet credit so closed/failed recharges are not reopened or credited by a stale finalizer.
- Added regression tests for stale credited snapshots, concurrently closed recharges, and the Gorm `UpdateRechargePaid` CAS predicate.
- Verified with focused RED/GREEN tests, `go test ./internal/module/payment ./internal/module/payment/... ./internal/infra/payment/alipay ./internal/module/crontask ./internal/bootstrap ./internal/middleware ./internal/server -count=1`, and `go vet ./internal/module/payment/... ./internal/infra/payment/alipay`.

## 2026-05-30 payment race/return hardening

- Fixed follow-up payment audit findings: order CAS misses are no longer treated as success by finalization or pay-url creation, so a closed/failed order cannot be credited and `PayOrder` cannot leak a stale gateway URL after the local order changed.
- Fixed first-wallet creation races in both payment recharge and wallet admin repositories: `uk_user_wallet_user` duplicate insert races now re-read and return the existing wallet.
- Tightened callback audit amount parsing so signed or non-digit yuan/cent fragments such as `10.-1` are invalid instead of being normalized into a misleading amount.
- Fixed `/payment/recharge` automatic sync and return-url sync to keep retrying when `PaymentRechargeApi.sync()` succeeds but the returned status is still `paying`.
- Fixed `/payment/config` notify URL guidance to use the canonical production public callback `https://www.zgm2003.cn/api/payment/callbacks/alipay`.
- Verified with payment backend RED/GREEN tests, `go test ./internal/module/payment ./internal/module/payment/... ./internal/infra/payment/alipay ./internal/module/crontask ./internal/bootstrap ./internal/middleware ./internal/server -count=1`, `go vet ./internal/module/payment/... ./internal/infra/payment/alipay`, frontend payment/wallet Vitest, targeted ESLint, and `npm run build:check`.

## 2026-05-30 payment hardening follow-up

- Fixed the payment-only audit findings: manual sync now closes linked recharges for `TRADE_CLOSED` and expired `ACQ.TRADE_NOT_EXIST`; paid-but-uncredited recharges are compensated by the scheduler; the Alipay amount parser rejects malformed signed cent fragments such as `10.-1`; `/payment/recharge` creation is gated by `payment_recharge_add`; and `paid` renders as warning while only `credited` renders as success.
- Fixed backend paths: `admin_back_go/internal/module/payment/order_service.go`, `admin_back_go/internal/module/payment/job_service.go`, `admin_back_go/internal/module/payment/recharge_repository.go`, and `admin_back_go/internal/infra/payment/alipay/gateway.go`.
- Fixed frontend paths: `admin_front_ts/src/views/Main/payment/recharge/**` and the matching i18n/test files.
- Verified with focused payment/alipay tests, extended payment/crontask/bootstrap/middleware/server tests, `go vet ./internal/module/payment/... ./internal/infra/payment/alipay`, frontend payment/wallet Vitest, `npm run build:check`, `git diff --check` for all three repos, and root governance check.

## 2026-05-30 payment frontend/backend retry, state, and callback hardening

- Fixed the frontend recharge auto-sync state machine: a visible `paying` recharge is marked as auto-synced only after `PaymentRechargeApi.sync()` succeeds, so a transient failure can retry during the same page session instead of waiting for a reload or manual sync.
- Fixed the return-url recharge sync state machine: a `recharge_no` is marked synced only after the lookup and sync path succeeds, with a separate in-flight guard preventing concurrent duplicate sync while still allowing retry after transient failure.
- Fixed the payment order list action guard: `payment_order_sync` is now exposed only for `paying` orders, matching the backend `SyncOrder` status precondition.
- Fixed existing-order settlement against disabled-or-soft-deleted bound Alipay configs while locking configs with pending/paying orders against mutation, disable, and delete.
- Added CAS status guards to payment order `paying`/`failed`/`paid`/`closed` transitions and recharge close transitions, so delayed fail/close paths cannot overwrite an already-paid order or close an already-paid recharge.
- Fixed callback audit handling: long form values are truncated before JSON marshaling, and callback audit insert failure no longer blocks verified settlement.
- Added `admin_front_ts/tests/shared/payment/payment-recharge-auto-sync.test.ts` to prove the first sync rejection is followed by a second auto-sync call for the same recharge id and that return-url lookup failures are retryable.
- Extended `admin_front_ts/tests/shared/payment/payment-order-page.test.ts` to guard the payment-order sync action status check.
- Added backend regression coverage for disabled/deleted bound configs, open-order config guards, callback audit JSON/failure behavior, and state-CAS repository/close-helper behavior.
- Verified with `go test ./internal/module/payment -count=1`, `go test ./internal/module/payment ./internal/module/payment/... ./internal/infra/payment/alipay ./internal/module/crontask ./internal/bootstrap ./internal/middleware ./internal/server -count=1`, `go vet ./internal/module/payment/... ./internal/infra/payment/alipay`, `npm test -- tests/shared/payment/payment-recharge-auto-sync.test.ts`, `npm test -- tests/shared/payment/payment-order-page.test.ts`, `npm test -- tests/shared/payment/payment-config-api.test.ts tests/shared/payment/payment-config-page.test.ts tests/shared/payment/payment-order-api.test.ts tests/shared/payment/payment-order-page.test.ts tests/shared/payment/payment-recharge-api.test.ts tests/shared/payment/payment-recharge-page.test.ts tests/shared/payment/payment-recharge-auto-sync.test.ts tests/shared/wallet/wallet-api.test.ts tests/shared/wallet/wallet-pages.test.ts`, `npx eslint src/views/Main/payment/recharge/composables/usePaymentRechargePage.ts tests/shared/payment/payment-recharge-auto-sync.test.ts src/views/Main/payment/orders/index.vue src/views/Main/payment/orders/composables/usePaymentOrderPage.ts tests/shared/payment/payment-order-page.test.ts`, and `npm run build:check`.

## 2026-05-30 wallet transaction number hardening

- Fixed wallet `transaction_no` collision handling after a known-issue reproduction showed `uk_wallet_transaction_no` duplicate paths were not retried correctly.
- `serialno.New` no longer wraps the per-second sequence with `% 1_000_000`; wallet consume and recharge credit now retry duplicate `transaction_no` insert collisions with a finite retry while preserving source idempotency behavior for `uk_wallet_transaction_source` races.
- Fixed backend paths: `admin_back_go/internal/module/payment/serialno/serial_no.go`, `admin_back_go/internal/module/payment/recharge_repository.go`, and `admin_back_go/internal/module/payment/wallet/repository.go` plus their tests.
- Verified with `go test ./internal/module/payment/serialno ./internal/module/payment/wallet ./internal/module/payment -count=1`, `go test ./internal/module/payment/... -count=1`, and `git diff --check`.

## 2026-05-29 multi-platform backend boundary Phase 2 closure

- Channel-specific verify-code TTL has landed in Go/Vue runtime: email TTL is owned by `mail_configs.verify_code_ttl_minutes`, SMS TTL is owned by `sms_configs.verify_code_ttl_minutes`, and the old `system_settings.auth.verify_code.ttl_minutes` key was soft-deleted in the local live MySQL check (`status=2`, `is_del=1`). Basic admin smoke passed after applying `20260529_channel_verify_code_ttl.sql`; full smoke reached mail/sms read probes with HTTP 200 and then stopped at the existing upload-token probe with `上传密钥不可用`, so do not record full smoke as passing for this slice.
- Phase 2 of `docs/superpowers/specs/2026-05-27-multi-platform-backend-boundary-design.md` has passed code/docs/frontend gates after Plans 11-17, but final admin smoke is still pending because the local runtime was unavailable in the closure session; do not mark the spec fully closed until basic and full smoke pass.
- Current backend boundary truth is `internal/module/{capability}/transport/{platform}` + `internal/shared` + `internal/infra`; active exceptions are product-scope decisions, not architecture drift.
- Admin behavior preservation remains the acceptance standard: existing admin URLs, DB table names, permission codes, i18n keys, route metadata, operation log rules, queue task types, payment callback/finalizer behavior, and frontend typed API contracts were preserved.
- Future app/openapi/merchant/miniapp work starts from this boundary and must add `transport/{platform}` slices under existing capabilities instead of creating platform-prefixed modules.

## 2026-05-29 transport admin alias cleanup

- Transitional `aliases.go` files under `admin_back_go/internal/module/**/transport/admin` have been removed; transport packages now import root capability modules explicitly instead of re-exporting service/repository/model/DTO types or root constants.
- `TestTransportDoesNotReExportModuleTypes` now guards that `transport/**/aliases.go` plus root-module type/const re-exports do not return, including transport files whose name is not `aliases.go`.
- Server dependency fields that had depended on transport alias re-exports now point at root module contracts for readiness, client version, cron task, export task, notification, and notification task services; existing transport-local narrow interfaces remain untouched.
- No admin URL, payload, permission code, i18n key, DB table, queue task type, realtime path, payment callback/finalizer, or frontend source change was introduced.
- Verified with alias scans, `go test ./internal/architecture -count=1`, `go test ./internal/server -run TestAdminRouteSnapshot -count=1`, focused lane package tests, `go test ./... -count=1`, `go build ./...`, and root governance/diff checks.

## 2026-05-28 small module aggregation wave

- Small flat modules now follow capability ownership without admin API drift: `userquickentry` service/model/repository moved into `admin_back_go/internal/module/profile`, `notificationtask` moved under `admin_back_go/internal/module/notification/task` plus `notification/transport/admin/task_*`, `exporttask` directory was renamed to `admin_back_go/internal/module/export`, and `authplatform` directory was renamed to `admin_back_go/internal/module/auth_platform`.
- Preserved admin/runtime contracts: `/api/admin/v1/users/me/quick-entries`, `/api/admin/v1/notification-tasks`, `/api/admin/v1/export-tasks`, `/api/admin/v1/auth-platforms`, `notification:dispatch-due:v1`, `notification:send-task:v1`, `export:run:v1`, `user_userManager_export`, DB tables, payloads, validation tags, permission codes, and existing i18n message IDs.
- Architecture guards now reject standalone `internal/module/{userquickentry,notificationtask,exporttask,authplatform}` and require the new capability paths.
- Verified in `admin_back_go` with focused profile/notification/export/auth_platform package tests, `go test ./internal/jobs ./internal/module/crontask ./internal/bootstrap ./internal/server -count=1`, `go test ./internal/architecture -count=1`, `go test ./internal/server -run TestAdminRouteSnapshot -count=1`, `go test ./... -count=1`, `go build ./...`, old-path scans, and `git diff --check`.

## 2026-05-28 AI aggregation wave 14a-14c

- AI provider/agent/tool/image/knowledge modules now live under the AI capability tree: `admin_back_go/internal/module/ai/{provider,agent,tool,image,knowledge}`. Package identifiers and i18n keys remain stable (`aiprovider`, `aiagent`, `aitool`, `aiimage`, `aiknowledge`) to keep the refactor mechanical.
- Removed old flat module directories: `internal/module/aiprovider`, `internal/module/aiagent`, `internal/module/aitool`, `internal/module/aiimage`, and `internal/module/aiknowledge`; architecture guards now reject their return.
- Preserved admin/runtime contracts: `/api/admin/v1/ai-providers*`, `/api/admin/v1/ai-agents*`, `/api/admin/v1/ai-tools*`, `/api/admin/v1/ai-agents/:id/tools`, `/api/admin/v1/ai-images*`, `/api/admin/v1/ai-knowledge-bases*`, `/api/admin/v1/ai-knowledge-documents*`, `/api/admin/v1/ai-agents/:id/knowledge-bases`, `ai:image-generate:v1`, AI `ai_*` DB table names, permission codes, validation tags, response payloads, and existing i18n message IDs.
- Verified after each sequential backend merge with `go test ./internal/architecture -count=1`, `go test ./internal/server -run TestAdminRouteSnapshot -count=1`, `go test ./internal/bootstrap ./internal/server -count=1`, `go test ./... -count=1`, and `go build ./...`; final old-path scan reported `NO_OLD_AI_IMPORTS_OR_DIRS` before push.
- AI conversation runtime aggregation Plan 15 is merged in Go backend master: `aiconversation`, `aimessage`, `aichat`, and `airun` now live under `admin_back_go/internal/module/ai/{conversation,message,chat,run}`. Package identifiers remain stable (`aiconversation`, `aimessage`, `aichat`, `airun`) to keep the serial runtime chain mechanical.

## 2026-05-28 shared package migration

- `admin_back_go/internal/shared` now owns `apperror`, `response`, `i18n`, `enum`, `validate`, `dict`, and `setting`; old root shared-like packages under `admin_back_go/internal/{apperror,response,i18n,enum,validate,dict}` are gone.
- `admin_back_go/internal/shared/dict` owns dict options and the first shared registry providers `common_status`, `common_yes_no`, `platform`, and `system_setting_value_type`; option labels and values are unchanged.
- `admin_back_go/internal/shared/setting` remains the cross-module typed settings boundary for migrated system-setting keys `auth.captcha.ttl_minutes` and `upload.token.ttl_minutes`; verification-code TTL is channel-owned by `mail_configs.verify_code_ttl_minutes` and `sms_configs.verify_code_ttl_minutes`; `internal/module/systemsetting` remains only the admin CRUD surface for `system_settings`.
- Plan 11 itself did not claim module aggregation, module renaming, DB schema changes, admin URL changes, response payload shape changes, enum value changes, validation behavior changes, or i18n catalog behavior changes; the later small module aggregation wave above records the verified module moves.
- Verified with focused package migration tests, `go test ./internal/shared/... -count=1`, `go test ./internal/architecture -count=1`, `go test ./internal/server -run TestAdminRouteSnapshot -count=1`, `go test ./... -count=1`, and `go build ./...`.

## 2026-05-28 admin route safety seam

- Added an admin route snapshot gate before continuing transport refactors.
- Split server route registration into owned group seams so later transport-shell plans can run in parallel with less `router.go` conflict.
- This does not mean all modules have moved to `transport/admin`; it only protects the admin route surface before the parallel wave.

## 2026-05-28 AI admin transport shells

- AI admin HTTP route ownership has moved to `internal/module/ai/{provider,agent,tool,image,knowledge,conversation,message,run,chat}/transport/admin`; service/repository/model/jobs remain under each AI subdomain root.
- `internal/server/routes_admin_ai.go` now imports the AI admin transport shells, while the existing `/api/admin/v1/ai-*` route surface is preserved by the route snapshot gate.
- Verified with `go test ./internal/architecture -run TestAIAdminTransportShells -count=1`, `go test ./internal/server -run TestAdminRouteSnapshot -count=1`, focused AI module/server tests, and the matching frontend AI API Vitest files.

## 2026-05-28 foundation admin transport shells

- Foundation/admin infra-facing HTTP route ownership has moved to `internal/module/{system,systemsetting,systemlog,operationlog,crontask,queuemonitor,clientversion,export,realtime}/transport/admin`; service/repository/model/jobs remain at each module root, with export task package identifiers and i18n keys kept as `exporttask` for contract stability.
- `internal/server/routes_admin_foundation.go` now imports the foundation admin transport shells; `/health`, `/ready`, `/api/admin/v1/ping`, system settings/logs, operation logs, cron tasks, queue monitor, client versions, export tasks, and realtime WebSocket URLs are unchanged.
- Verified with `go test ./internal/architecture -run TestFoundationAdminTransportShells -count=1`, `go test ./internal/server -run TestAdminRouteSnapshot -count=1`, focused foundation module + transport tests, and `go test ./... -count=1`.

## 2026-05-28 comms/upload admin transport shells

- Communication and upload admin HTTP route ownership has moved to `internal/module/{mail,sms,notification,uploadconfig,uploadtoken}/transport/admin`; notification task service/model/jobs now live under `internal/module/notification/task`, with admin task routes in `notification/transport/admin/task_*`.
- `uploadtoken` keeps the app upload-token route under `internal/module/uploadtoken/transport/app` without changing `POST /api/app/v1/upload-tokens`.
- `internal/server/routes_admin_comms.go` now imports the comms/upload admin transport shells, while existing `/api/admin/v1/mail`, `/sms`, `/notifications`, `/notification-tasks`, `/upload-*`, and `/upload-tokens` route surfaces are preserved by the route snapshot gate.
- Verified with `go test ./internal/architecture -run TestCommsUploadAdminTransportShells -count=1`, `go test ./internal/server -run TestAdminRouteSnapshot -count=1`, focused comms/upload module + transport tests, and `go test ./... -count=1`.

## 2026-05-28 commerce/RBAC admin transport shells

- Commerce/RBAC admin HTTP route ownership has moved to `internal/module/{auth_platform,permission,role,payment}/transport/admin` plus `internal/module/payment/wallet/transport/admin`; service/repository/model/jobs remain under their capability roots.
- Wallet transport shell moved in this slice; detailed wallet aggregation status is recorded in the 2026-05-29 section below.
- Payment public Alipay callback is explicitly separate under `internal/module/payment/transport/callback`; admin payment URLs remain under the existing `/api/admin/v1/payment-*` and wallet URLs.
- `internal/server/routes_admin_commerce_rbac.go` now imports the commerce/RBAC admin transport shells, while existing auth platform, permission, role, wallet, and payment admin route surfaces are preserved by the route snapshot gate.
- Verified with `go test ./internal/architecture -run TestCommerceRBACAdminTransportShells -count=1`, `go test ./internal/server -run TestAdminRouteSnapshot -count=1`, focused commerce/RBAC module + transport tests, and `go test ./... -count=1`.

## 2026-05-29 wallet payment aggregation

- Wallet now lives under `admin_back_go/internal/module/payment/wallet` while package identifiers and `wallet.*` i18n keys remain stable.
- Preserved admin wallet URLs: `/api/admin/v1/wallet/summary`, `/api/admin/v1/wallet/transactions*`, `/api/admin/v1/wallet/users*`, `/api/admin/v1/wallet/ledger*`, and guarded `POST /api/admin/v1/wallet/consumptions`.
- No DB schema, permission code, i18n key/text, operation log rule, payment callback/finalizer, Alipay adapter, or frontend source change was introduced.
- Verified after backend merge with `go test ./internal/architecture -count=1`, `go test ./internal/server -run TestAdminRouteSnapshot -count=1`, `go test ./internal/bootstrap ./internal/server ./internal/module/payment/... ./internal/module/crontask ./internal/jobs -count=1`, `go test ./... -count=1`, `go build ./...`, and frontend contract checks `npm run typecheck` plus `npm run test -- tests/shared/payment tests/shared/wallet`.

## 2026-05-28 user/profile admin preservation

- User-management admin HTTP ownership has moved to `internal/module/user/transport/admin`; current-user profile and quick-entry HTTP ownership has moved to `internal/module/profile/transport/admin`; app profile compile routes live under `internal/module/profile/transport/app`.
- Existing admin URLs are preserved: `/api/admin/v1/users*`, `/api/admin/v1/users/:id/profile`, `/api/admin/v1/profile*`, and `/api/admin/v1/users/me/quick-entries` remain unchanged.
- `user` now means admin user-management capability; `profile` now means current-user self-service capability. Quick-entry service/repository/model code is owned by `profile`; `userquickentry.*` remains only as stable i18n message IDs.
- Verified with `go test ./internal/architecture -run TestUserProfileTransportShape -count=1`, focused user/profile/server route tests, `go test ./... -count=1`, and frontend `npm run typecheck` + `npm run test -- tests/shared/user/users-api.test.ts`.

## 2026-05-28 final transport boundary guard

- `TestNoModuleRootHTTPSurface` now enforces that active module root HTTP files stay out of `internal/module/*`; route/handler files belong under `internal/module/{capability}/transport/{platform}`.
- The guard rejects root `route.go`, `handler.go`, `app_handler.go`, `platform_handler.go`, `app_route_test.go`, and `platform_route.go`; service/repository/model/jobs files remain at module root.
- Current active docs scan classified the then-existing technical-resource paths as verified runtime paths, not as platform HTTP ownership; the later infra rename section records the completed path change.
- Verified with `go test ./internal/architecture -count=1`, `go test ./internal/server -run TestAdminRouteSnapshot -count=1`, `go test ./... -count=1`, frontend `npm run typecheck`, and frontend `npm run test -- tests/shared/user/users-api.test.ts`.

## 2026-05-28 infra runtime layer rename

- Backend runtime technical resources have moved from the old platform-named technical directory to `admin_back_go/internal/infra`; business platform concepts such as admin/app/openapi/merchant, `auth_platforms`, request `platform`, and API route prefixes are unchanged.
- `TestInfraRenameComplete` now guards that `internal/infra` exists, the old technical directory no longer exists, and Go files no longer import the old backend technical-resource path.
- Active root/backend docs now refer to technical resources through `internal/infra`; historical superpowers plans/specs remain historical records and do not override current runtime paths.
- Verified in `admin_back_go` with `go test ./internal/architecture -run TestInfraRenameComplete -count=1`, `go test ./internal/architecture -count=1`, `go test ./internal/server -run TestAdminRouteSnapshot -count=1`, `go test ./... -count=1`, and `go build ./...`.

## 2026-05-27 架构方向更新

- 多平台后端架构原则 R1-R8 落地为 `docs/architecture/00-platform-and-module-rules.md`。
- `platform` 词汇收紧：仅指业务平台 admin / app / openapi / merchant。
- 技术资源目录已在 2026-05-28 infra runtime layer rename 中收口为 `internal/infra`；当前表格里的运行时路径以已验证代码事实为准。
- 顶层目标分层从 `api/domain/shared/platform` 四层改为 `module/{capability}/transport/{platform}` + `shared` + `infra`。
- 2026-05-27 设计快照曾规划将 `internal/module/` 从 36 个 module 聚合至约 19 个（含新增 profile）；这不是当前代码计数的完成声明。
- 该快照已被 2026-05-28 infra rename 与 2026-05-29 Phase 2 verified sections 取代；表格和运行时路径以已验证代码事实为准。

参见：

- spec：`docs/superpowers/specs/2026-05-27-multi-platform-backend-boundary-design.md`
- plans：`docs/superpowers/plans/2026-05-27-multi-platform-{01..04}-*.md`
