# Runtime Source Map

更新时间：2026-06-07

本文是源码级导航图，不是运行时验收报告。它回答“当前代码最新版在哪里”，不替代 `docs/status/current-status.md`、`docs/contracts/*`、smoke/test 输出或 live MySQL schema。

生成依据：

```text
admin_back_go/internal/module/* source tree
admin_front_ts/src source tree
canvas_front_next/src source tree
admin_back_go/go.mod
admin_front_ts/package.json
canvas_front_next/package.json
docs/db/mysql-live-schema-2026-06-07.md
docs/knowledge/db-schema-ownership-map-2026-06-07.md
docs/knowledge/full-stack-module-map-2026-06-07.md
docs/knowledge/backend-capability-manifest-2026-06-07.md
docs/knowledge/admin-front-source-quality-inventory-2026-06-07.md
docs/knowledge/admin-front-direct-external-helper-review-2026-06-07.md
docs/knowledge/admin-front-header-breadcrumb-source-quality-review-2026-06-07.md
docs/knowledge/admin-front-forgot-password-error-source-quality-review-2026-06-07.md
docs/knowledge/admin-front-json-editor-source-quality-review-2026-06-07.md
docs/knowledge/admin-front-dicon-source-quality-review-2026-06-07.md
docs/knowledge/admin-front-editor-source-quality-review-2026-06-07.md
docs/knowledge/admin-front-download-manager-source-quality-review-2026-06-07.md
docs/knowledge/admin-front-dev-test-download-source-quality-review-2026-06-07.md
docs/knowledge/admin-front-validator-source-quality-review-2026-06-07.md
docs/knowledge/admin-front-upload-demo-source-quality-review-2026-06-07.md
docs/knowledge/admin-front-demo-any-source-quality-review-2026-06-07.md
docs/knowledge/canvas-ai-request-contract-review-2026-06-07.md
docs/knowledge/canvas-rbac-permission-contract-review-2026-06-07.md
docs/knowledge/canvas-asset-route-contract-review-2026-06-07.md
docs/knowledge/canvas-auth-logout-contract-review-2026-06-07.md
docs/knowledge/admin-user-status-contract-review-2026-06-07.md
docs/knowledge/admin-ai-agent-test-contract-review-2026-06-07.md
```

## Backend source map

### Entrypoints

| Area | Current source |
| --- | --- |
| HTTP API process | `admin_back_go/cmd/admin-api/main.go` |
| Worker process | `admin_back_go/cmd/admin-worker/main.go` |
| App assembly | `admin_back_go/internal/bootstrap/app.go` |
| Gin engine / middleware / route mount | `admin_back_go/internal/server/router.go` |
| Route metadata | `admin_back_go/internal/bootstrap/route_meta.go` |
| Current jobs register | `admin_back_go/internal/jobs/noop.go` |
| Queue infra | `admin_back_go/internal/infra/taskqueue` |
| Scheduler infra | `admin_back_go/internal/infra/scheduler` |

### Module transport inventory

`transport/callback` 是外部回调 HTTP 表面例外，不是 business platform。

| Capability | Current HTTP surfaces |
| --- | --- |
| `ai` | `agent/transport/admin`, `chat/transport/admin`, `chat/transport/canvas`, `conversation/transport/admin`, `image/transport/admin`, `image/transport/canvas`, `knowledge/transport/admin`, `message/transport/admin`, `provider/transport/admin`, `run/transport/admin`, `tool/transport/admin`, `video/transport/canvas` |
| `auth` | `transport/admin`, `transport/app`, `transport/canvas` |
| `auth_platform` | `transport/admin` |
| `canvas` | `transport/canvas` |
| `clientversion` | `transport/admin` |
| `crontask` | `transport/admin` |
| `export` | `transport/admin` |
| `mail` | `transport/admin` |
| `notification` | `transport/admin` |
| `operationlog` | `transport/admin` |
| `payment` | `transport/admin`, `transport/callback`, `transport/canvas`, `wallet/transport/admin`, `wallet/transport/canvas` |
| `permission` | `transport/admin` |
| `profile` | `transport/admin`, `transport/app`, `transport/canvas` |
| `queuemonitor` | `transport/admin` |
| `realtime` | `transport/admin` |
| `role` | `transport/admin` |
| `sms` | `transport/admin` |
| `system` | `transport/admin` |
| `systemlog` | `transport/admin` |
| `systemsetting` | `transport/admin` |
| `uploadconfig` | `transport/admin` |
| `uploadtoken` | `transport/admin`, `transport/app` |
| `user` | `transport/admin`, `transport/app`, `transport/canvas` |

### Shared and infra boundaries

| Boundary | Current source |
| --- | --- |
| Errors / response / i18n | `admin_back_go/internal/shared/apperror`, `response`, `i18n` |
| Enum / dict / validate / setting | `admin_back_go/internal/shared/enum`, `dict`, `validate`, `setting` |
| DB / Redis | `admin_back_go/internal/infra/database`, `redisclient` |
| Storage / payment / mail / sms / AI SDKs | `admin_back_go/internal/infra/storage`, `payment`, `mail`, `sms`, `ai` |

## Admin Vue source map

### Runtime facts

| Area | Current source |
| --- | --- |
| App bootstrap | `admin_front_ts/src/main.ts` |
| API prefix | `admin_front_ts/src/lib/http/api-prefix.ts` |
| HTTP client | `admin_front_ts/src/lib/http` |
| Current user API | `admin_front_ts/src/api/user/users.ts` |
| User/RBAC store | `admin_front_ts/src/store/user.ts` |
| Dynamic route tree | `admin_front_ts/src/router/runtime-route-tree.ts` |
| Layout page-card | `admin_front_ts/src/views/Layout/index.vue`, `admin_front_ts/src/views/Layout/utils/page-layout.ts` |
| i18n setup | `admin_front_ts/src/i18n/index.ts`, `admin_front_ts/src/i18n/locales/zh-CN.ts`, `admin_front_ts/src/i18n/locales/en-US.ts` |

### API and UI primitives

| Area | Current source |
| --- | --- |
| API modules | `ai`, `payment`, `permission`, `system`, `user`, `wallet` under `admin_front_ts/src/api` |
| Standard CRUD primitives | `admin_front_ts/src/components/Search`, `Table`, `AppDialog`; `admin_front_ts/src/hooks/useCrudTable.ts` |
| Read-only table primitive | `admin_front_ts/src/components/Table/src/useTable.ts`, exported by `admin_front_ts/src/components/Table/index.ts` |
| Remote option loading | `admin_front_ts/src/components/RemoteSelect` |
| Upload components | `admin_front_ts/src/components/UpFile`, `admin_front_ts/src/components/UpMedia` |
| Realtime client | `admin_front_ts/src/hooks/useWebSocket.ts`, `admin_front_ts/src/components/NotificationRuntime` |

### Known frontend hardening gaps


`ADMIN-FRONT-HARDENING-013` is resolved for remaining tracked demo any rows: `form/index.vue`, `display/index.vue`, and `ParticleBackground.vue` are guarded by form/display/effect source-quality tests. Current source-quality inventory now reports `0` `any` candidates; fallback rows remain review inventory. `docs/knowledge/admin-front-demo-any-source-quality-review-2026-06-07.md` records the decision.
Source-quality inventory:

```text
docs/knowledge/admin-front-source-quality-inventory-2026-06-07.md
```

Current inventory facts: `280` Admin Vue source files scanned, `0` `any` candidates, `0` `as any` candidates, `0` `catch(error: any)` candidates, `559` fallback candidates, and `0` direct external HTTP candidates. This is regex review evidence, not type-aware proof and not permission to sweep-replace code.

`ADMIN-FRONT-HARDENING-012` is resolved for upload demo media-list typing: `upload/index.vue` now uses `ref<UploadMediaItem[]>([])`, and `UpMediaList.vue` shares that model through `components/media.ts`; `tests/shared/upload/upload-demo-source-quality.test.ts` guards the slice. `docs/knowledge/admin-front-upload-demo-source-quality-review-2026-06-07.md` records the decision.

`ADMIN-FRONT-HARDENING-011` is resolved for `useValidator.ts` validator typing and message handling: `useValidator.ts` now types validator values as strings, uses an explicit `LengthRange`, and resolves message fallbacks only when `message === undefined`; `tests/shared/validator/use-validator-source-quality.test.ts` guards the slice. `docs/knowledge/admin-front-validator-source-quality-review-2026-06-07.md` records the decision.

`ADMIN-FRONT-HARDENING-003` is resolved for the direct external helper only: `admin_front_ts/src/api/tools.ts` was unused and deleted, and `tests/shared/api/no-direct-external-helper.test.ts` rejects the retired `api.btstu.cn` host. `docs/knowledge/admin-front-direct-external-helper-review-2026-06-07.md` records the decision.

`ADMIN-FRONT-HARDENING-004` is resolved for Header breadcrumb route-walk typing: `Header/index.vue` now uses `PermissionMenuItem` and explicit `matchedPath !== null` handling; `tests/layout/header-source-quality.test.ts` guards the slice. `docs/knowledge/admin-front-header-breadcrumb-source-quality-review-2026-06-07.md` records the decision.

`ADMIN-FRONT-HARDENING-005` is resolved for forgot-password request-error handling: `useForgotPassword.ts` now catches `unknown`, requires a non-empty `Error.message`, and `tests/shared/user/forgot-password-source-quality.test.ts` guards that empty request errors are not hidden behind `sendFailed` / `resetFailed`. `docs/knowledge/admin-front-forgot-password-error-source-quality-review-2026-06-07.md` records the decision.

`ADMIN-FRONT-HARDENING-008` is resolved for wangEditor wrapper typing and upload URL handling: `Editor.vue` now uses wangEditor exported types, typed insert callbacks, and `requireUploadURL(result.url)` instead of `result.url || ''`; `tests/shared/editor/editor-source-quality.test.ts` guards the slice. `docs/knowledge/admin-front-editor-source-quality-review-2026-06-07.md` records the decision.

`ADMIN-FRONT-HARDENING-009` is resolved for DownloadManager error and filename handling: `DownloadManager/src/download.ts` now catches `unknown`, classifies user cancellation explicitly, rethrows Web fetch failures instead of using `window.open(url, '_blank')` as a failed-download fallback, and derives filenames through explicit helpers instead of `||` chains. `tests/shared/download-manager/download-manager-source-quality.test.ts` guards the slice. `docs/knowledge/admin-front-download-manager-source-quality-review-2026-06-07.md` records the decision.

Admin dev test download error handling is resolved for the remaining catch-any row: `src/views/Main/test/index.vue` now catches `unknown`, requires a non-empty `Error.message`, and uses an explicit optional filename helper; `tests/shared/download-manager/dev-test-download-source-quality.test.ts` guards the source. `docs/knowledge/admin-front-dev-test-download-source-quality-review-2026-06-07.md` records the decision.

`ADMIN-FRONT-HARDENING-007` is resolved for DIcon dynamic Element Plus icon typing: `DIcon/src/index.vue` now uses `typeof import('@element-plus/icons-vue')` plus a `keyof` guard instead of `(mod as any)`, and `tests/shared/icon/dicon-source-quality.test.ts` guards the slice. `docs/knowledge/admin-front-dicon-source-quality-review-2026-06-07.md` records the decision.

`ADMIN-FRONT-HARDENING-006` is resolved for JsonEditor parse-error handling and touched i18n: `JsonEditor/src/json.ts` owns the explicit empty-editor `{}` rule and non-empty parse-error message requirement, `JsonEditor/src/index.vue` uses i18n keys, and `tests/shared/json-editor/json-editor-source-quality.test.ts` guards the slice. `docs/knowledge/admin-front-json-editor-source-quality-review-2026-06-07.md` records the decision.

`ADMIN-FRONT-HARDENING-002` is resolved for route-walk typing only: `SearchDialog.vue` no longer contains `any/as any`, and `tests/layout/search-dialog-source-quality.test.ts` guards that component. `ADMIN-FRONT-HARDENING-001` is resolved: `TableActions.vue` now uses `common.actions.refresh`, and `tests/shared/i18n/no-visible-chinese.test.ts` guards the shared component against visible raw Chinese.

## Canvas Next source map

### Runtime facts

| Area | Current source |
| --- | --- |
| Next API proxy | `canvas_front_next/src/app/api/[...path]/route.ts` |
| Auth service | `canvas_front_next/src/services/api/auth.ts` |
| Request client | `canvas_front_next/src/services/api/request.ts` |
| Settings service | `canvas_front_next/src/services/api/settings.ts` |
| Prompt / asset services | `canvas_front_next/src/services/api/prompts.ts`, `assets.ts` |
| Image / video services | `canvas_front_next/src/services/api/image.ts`, `video.ts` |
| Profile service | `canvas_front_next/src/services/api/profile.ts` |
| RBAC feature | `canvas_front_next/src/features/rbac` |
| User/config stores | `canvas_front_next/src/stores/use-user-store.ts`, `use-config-store.ts` |

Canvas AI request contract review:

```text
docs/knowledge/canvas-ai-request-contract-review-2026-06-07.md
```

The review records that chat/image/video generation submits `agent_id` plus user content/params, while backend chat/video transports reject client `model`, `provider`, `api_key`, and `base_url` overrides before service invocation. Video creation accepts the active Canvas Next FormData shape as well as JSON.

Canvas RBAC permission contract review:

```text
docs/knowledge/canvas-rbac-permission-contract-review-2026-06-07.md
```

The review records that `canvas_ai_text_generate` is a soft-deleted live MySQL orphan and is not part of the active Canvas Next canonical `buttonCodes` type. The current frontend guard is `canvas_front_next/tests/shared/canvas-rbac-shell.test.ts`.

Canvas asset route contract review:

```text
docs/knowledge/canvas-asset-route-contract-review-2026-06-07.md
```

The review records that `/assets` is the only active top-level Canvas asset page and `/asset-library` was a dead page removed from `canvas_front_next/src/app/(user)`.

Canvas auth logout contract review:

```text
docs/knowledge/canvas-auth-logout-contract-review-2026-06-07.md
```

The review records that Canvas Next calls `POST /api/canvas/v1/auth/logout` before clearing local token/user/RBAC state, and failed backend revocation preserves the browser session.

Admin user status contract review:

```text
docs/knowledge/admin-user-status-contract-review-2026-06-07.md
```

The review records that Admin Vue calls `PATCH /api/admin/v1/users/:id/status` from the user list enable/disable action, using the existing `user_userManager_edit` route permission.

Admin AI agent test contract review:

```text
docs/knowledge/admin-ai-agent-test-contract-review-2026-06-07.md
```

The review records that Admin Vue calls `POST /api/admin/v1/ai-agents/:id/test` from the AI agent list test action, using the existing `ai_agent_test` route permission.

### Page inventory

Current `page.tsx` routes under `canvas_front_next/src/app`:

```text
(auth)/login
(user)
(user)/assets
(user)/canvas
(user)/canvas/[id]
(user)/image
(user)/profile
(user)/prompts
(user)/video
```

`/asset-library` is not part of current source inventory or active RBAC contract. Do not reintroduce it as a route alias or frontend fallback.

## MySQL source of truth

Current schema artifact:

```text
docs/db/mysql-live-schema-2026-06-07.md
docs/db/mysql-live-schema-2026-06-07.sql
docs/knowledge/db-schema-ownership-map-2026-06-07.md
docs/knowledge/full-stack-module-map-2026-06-07.md
docs/knowledge/backend-capability-manifest-2026-06-07.md
docs/knowledge/admin-front-source-quality-inventory-2026-06-07.md
docs/knowledge/admin-front-direct-external-helper-review-2026-06-07.md
docs/knowledge/admin-front-header-breadcrumb-source-quality-review-2026-06-07.md
docs/knowledge/admin-front-forgot-password-error-source-quality-review-2026-06-07.md
docs/knowledge/admin-front-json-editor-source-quality-review-2026-06-07.md
docs/knowledge/canvas-ai-request-contract-review-2026-06-07.md
docs/knowledge/canvas-rbac-permission-contract-review-2026-06-07.md
docs/knowledge/canvas-asset-route-contract-review-2026-06-07.md
docs/knowledge/canvas-auth-logout-contract-review-2026-06-07.md
docs/knowledge/admin-user-status-contract-review-2026-06-07.md
docs/knowledge/admin-ai-agent-test-contract-review-2026-06-07.md
```

Verified table count in the snapshot: `56`.
The DB schema ownership map is derived from the live schema artifact plus current Go source references. It records `56` live tables reviewed, `55` `go-model` tables, and one `live-schema-only` table: `canvas_prompts_backup_20260601_before_infinite_import`.
The full-stack module map joins route inventory, frontend API inventory, DB ownership, and source-only review at capability level. It records `280` backend route registrations joined, `258` frontend exact backend calls assigned, `0` unassigned exact frontend calls, and `56` live DB tables mapped.
The backend capability manifest records `34` Go capabilities, `280` backend route registrations covered, and `3` helper packages that are not promoted to capability: `auth/verifycode`, `payment/serialno`, and `queuemonitor/asynqmonui`.

Key active tables present in the DDL artifact:

```text
users
permissions
roles
role_permissions
auth_platforms
ai_agents
ai_providers
ai_provider_models
canvas_prompts
canvas_assets
canvas_video_tasks
payment_configs
payment_recharges
payment_orders
user_wallets
wallet_transactions
```

## Source-map verification

Generated inventory snapshot:

```text
docs/knowledge/runtime-inventory-2026-06-07.md
docs/knowledge/backend-route-inventory-2026-06-07.md
docs/knowledge/backend-route-contract-drift-2026-06-07.md
docs/knowledge/frontend-api-inventory-2026-06-07.md
docs/knowledge/frontend-backend-api-drift-2026-06-07.md
docs/knowledge/api-source-only-route-review-2026-06-07.md
docs/knowledge/db-schema-ownership-map-2026-06-07.md
docs/knowledge/full-stack-module-map-2026-06-07.md
docs/knowledge/backend-capability-manifest-2026-06-07.md
```

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\export-runtime-inventory.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\export-backend-route-inventory.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\export-backend-route-contract-drift.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\export-frontend-api-inventory.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\export-frontend-backend-api-drift.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\export-api-source-only-route-review.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\export-db-schema-ownership-map.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\export-full-stack-module-map.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\export-backend-capability-manifest.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\export-admin-front-source-quality-inventory.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1 -LiveSchema
```

The inventory commands guard selected manifest/source/schema/API-call artifact drift. `frontend-api-inventory-2026-06-07.md` is source inventory only; it does not prove served route behavior. `db-schema-ownership-map-2026-06-07.md` is source ownership mapping only; it does not prove migration history or runtime path coverage. `full-stack-module-map-2026-06-07.md` is a joined navigation map; its frontend join invariant prevents unknown-capability fallback, but it still is not runtime smoke. `backend-capability-manifest-2026-06-07.md` is source package ownership evidence; it does not prove canonical writers or import graph boundaries. `admin-front-source-quality-inventory-2026-06-07.md` is regex source-quality evidence for Admin Vue `any/as any/fallback/direct external HTTP` rows; it does not classify every fallback as a bug. The final live-schema command additionally re-exports live MySQL schema and compares the table count with this tracked snapshot.






