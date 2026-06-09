# Current Runtime Knowledge

更新时间：2026-06-08

本文是 Codex 快速理解当前项目的知识库，不是状态证明。状态证明看 `docs/status/current-status.md`，接口看 `docs/contracts/*`，表结构看 `docs/db/mysql-live-schema-2026-06-08.md` 和同名 `.sql`，表到 Go source owner 的映射看 `docs/knowledge/db-schema-ownership-map-2026-06-08.md`，跨后端路由/前端 API/live DB ownership 的模块地图看 `docs/knowledge/full-stack-module-map-2026-06-08.md`，Go backend capability 源码归属看 `docs/knowledge/backend-capability-manifest-2026-06-08.md`，每个 capability 的改动 runbook 看 `docs/knowledge/backend-capability-runbook-2026-06-08.md`，页面到 API/权限/DB 反查看 `docs/knowledge/frontend-page-runtime-map-2026-06-08.md`，Docker/env/smoke 运维看 `docs/knowledge/docker-env-smoke-runbook-2026-06-08.md`，故障排查看 `docs/knowledge/failure-troubleshooting-playbook-2026-06-08.md`，Admin/Canvas 用户流看 `docs/knowledge/admin-canvas-user-flow-runtime-map-2026-06-08.md`，Admin Vue `any/as any/fallback/direct external HTTP` 债务库存看 `docs/knowledge/admin-front-source-quality-inventory-2026-06-08.md`，后续 Go/Vue/Next/DB 质量递进路线看 `docs/architecture/09-codex-first-quality-runway.md`，Admin direct external helper 删除口径看 `docs/knowledge/admin-front-direct-external-helper-review-2026-06-07.md`，Admin Header breadcrumb source-quality 口径看 `docs/knowledge/admin-front-header-breadcrumb-source-quality-review-2026-06-07.md`，Admin forgot-password request-error source-quality 口径看 `docs/knowledge/admin-front-forgot-password-error-source-quality-review-2026-06-07.md`，Admin JsonEditor source-quality 口径看 `docs/knowledge/admin-front-json-editor-source-quality-review-2026-06-07.md`，Admin DIcon source-quality 口径看 `docs/knowledge/admin-front-dicon-source-quality-review-2026-06-07.md`，Admin wangEditor source-quality 口径看 `docs/knowledge/admin-front-editor-source-quality-review-2026-06-07.md`，Admin DownloadManager source-quality 口径看 `docs/knowledge/admin-front-download-manager-source-quality-review-2026-06-07.md`，Admin dev test 下载页 source-quality 口径看 `docs/knowledge/admin-front-dev-test-download-source-quality-review-2026-06-07.md`，Admin useValidator source-quality 口径看 `docs/knowledge/admin-front-validator-source-quality-review-2026-06-07.md`，Admin upload demo source-quality 口径看 `docs/knowledge/admin-front-upload-demo-source-quality-review-2026-06-07.md`，Admin demo any 清零口径看 `docs/knowledge/admin-front-demo-any-source-quality-review-2026-06-07.md`，Canvas AI 请求契约看 `docs/knowledge/canvas-ai-request-contract-review-2026-06-07.md`，Canvas RBAC 权限码口径看 `docs/knowledge/canvas-rbac-permission-contract-review-2026-06-07.md`，Canvas 资产页路由口径看 `docs/knowledge/canvas-asset-route-contract-review-2026-06-07.md`，Canvas logout 契约看 `docs/knowledge/canvas-auth-logout-contract-review-2026-06-07.md`，Admin 用户状态契约看 `docs/knowledge/admin-user-status-contract-review-2026-06-07.md`。

## Workspace map

| Workspace | Role | Current stack | Primary evidence |
| --- | --- | --- | --- |
| `E:\admin_go` | meta repo / 总控文档 / agents / governance | Markdown + PowerShell governance | `docs/README.md`, `agents/`, `scripts/check-agent-governance.ps1` |
| `E:\admin_go\admin_back_go` | Go backend runtime | Go 1.26.1, Gin, GORM, MySQL, Redis, Asynq, gocron | `admin_back_go/go.mod`, `admin_back_go/internal/`, `admin_back_go/database/migrations/` |
| `E:\admin_go\admin_front_ts` | Admin Vue frontend runtime | Vue 3.5, TypeScript, Vite, Element Plus, Pinia, vue-i18n | `admin_front_ts/package.json`, `admin_front_ts/src/` |
| `E:\admin_go\canvas_front_next` | Canvas Next frontend runtime | Next 16, React 19, TypeScript, Ant Design, Zustand, React Query | `canvas_front_next/package.json`, `canvas_front_next/src/` |

### Version facts that must stay source-backed

These values are copied from `go.mod` / `package.json`, not memory:

| Workspace | Runtime / dependency | Current manifest value |
| --- | --- | --- |
| `admin_back_go` | Go | `1.26.1` |
| `admin_front_ts` | Vue | `^3.5.24` |
| `admin_front_ts` | Vite | `^8.0.3` |
| `admin_front_ts` | TypeScript | `~5.9.3` |
| `admin_front_ts` | Element Plus | `^2.13.0` |
| `admin_front_ts` | Pinia | `^3.0.2` |
| `admin_front_ts` | vue-i18n | `^9.13.0` |
| `admin_front_ts` | axios | `^1.8.4` |
| `canvas_front_next` | Next | `16.2.3` |
| `canvas_front_next` | React | `19.2.5` |
| `canvas_front_next` | TypeScript | `^5` |
| `canvas_front_next` | Ant Design | `^6.4.2` |
| `canvas_front_next` | Zustand | `^5.0.12` |
| `canvas_front_next` | React Query | `^5.100.9` |
| `canvas_front_next` | axios | `^1.16.0` |

## Codex-first quality runway

`docs/architecture/09-codex-first-quality-runway.md` is the current operating route for future hardening slices. It records the current verified generated baseline (`287` Go routes, `266` exact frontend/backend route matches, `55` live MySQL tables, Admin Vue `0` any / `511` fallback candidates) and forces future work through narrow docs/source/API/DB/runtime slices instead of broad sweeps.

## Backend: Go modular monolith

当前后端不是 legacy compatibility layer。架构目标是：

```text
cmd -> bootstrap -> server -> module/{capability}/transport/{platform} -> service -> repository -> model
                                    \-> shared
                                    \-> infra
```

### Hard boundaries

- `platform` 只表示业务入口：`admin` / `app` / `canvas` / 未来 `openapi`、`merchant`、`miniapp`。
- `module` 是业务能力，不带平台前缀。
- HTTP 表面必须在 `internal/module/{capability}/transport/{platform}/`。
- `shared` 拥有跨能力公共能力：`apperror`、`response`、`i18n`、`enum`、`validate`、`dict`、`setting`。
- `infra` 拥有运行时技术资源：DB、Redis、queue、scheduler、storage、AI provider、payment SDK、mail/SMS SDK。

### Current module groups

```text
ai/auth/auth_platform/canvas/clientversion/crontask/export/mail/notification/
operationlog/payment/permission/profile/queuemonitor/realtime/role/sms/
system/systemlog/systemsetting/uploadconfig/uploadtoken/user
```

### Runtime facts to preserve

- Admin/app/canvas current-user bootstrap uses `GET /api/{admin,app,canvas}/v1/users/me`.
- Canvas auth routes live under `/api/canvas/v1/auth/*` and force platform `canvas`.
- Canvas AI text/image/video uses backend-managed agent/provider selection. Canvas frontend sends `agent_id` plus contract-approved user content/generation params, not provider/model billing metadata. Chat/video backend transports reject client `model` / `provider` / `api_key` / `base_url` overrides instead of ignoring them.
- Queue and scheduler are single-monolith multi-process: `cmd/admin-api` serves HTTP; `cmd/admin-worker` consumes queue and schedules work.
- Permission and operation logs are explicit route metadata, not reflection or handler annotations.

## Admin frontend: Vue adapter

Admin frontend is an adapter to the Go contract, not a place to invent backend fields.

### Runtime map

- Stack: Vue 3.5 + Vite 8 + TypeScript 5.9 + Element Plus + Pinia + vue-i18n.
- Bootstrap: `src/main.ts` installs Pinia/router/i18n, waits for router readiness, then calls `setupDynamicRoutes()`.
- API prefix: `src/lib/http/api-prefix.ts` fixes admin REST base at `/api/admin/v1`.
- Current user: `src/api/user/users.ts` calls `GET /api/admin/v1/users/me`; `src/store/user.ts` writes `permissions`, `router`, and `buttonCodes`.
- User status: `src/api/user/users.ts` calls `PATCH /api/admin/v1/users/:id/status`; `src/views/Main/user/userManager/components/UserList/index.vue` exposes enable/disable through `useCrudTable.toggleStatus` under `user_userManager_edit`.
- AI agent test: `src/api/ai/agents.ts` calls `POST /api/admin/v1/ai-agents/:id/test`; `src/views/Main/ai/agents/index.vue` exposes the enabled-row test action under `ai_agent_test` without browser-side provider credential input.
- Route/RBAC: backend `router` plus `src/router/runtime-route-tree.ts` builds dynamic routes; button/action visibility only calls `userStore.can(code)`.
- i18n: `src/i18n/index.ts` reads `lang` cookie; `src/lib/http/platform.ts` sends the same language through `Accept-Language`.
- Layout: `src/views/Layout/index.vue` wraps route content in `page-card` by default via `src/views/Layout/utils/page-layout.ts`.

### Default page construction

```text
Search + AppTable + AppDialog + useCrudTable   # CRUD
Search + AppTable + useTable                   # read-only list
```

### Default rules

- Vue 3 + `<script setup lang="ts">` + Composition API.
- New visible text must update `zh-CN.ts` and `en-US.ts`.
- Standard CRUD pages do not hand-write `el-table`, `el-dialog`, or filter `el-form`.
- Route pages live inside Layout `page-card`; do not add a second large card.
- Touched code must not add `any`, `as any`, or `Record<string, any>`.

### Shared primitive hardening already started

The first quality-hardening slice typed `Search`, `AppTable`, `ColumnSetting`, `RemoteSelect` boundaries and added guard tests. Treat this as the pattern for future modules: add a focused guard first, then remove the bad state at the shared boundary.

Evidence:

```text
admin_front_ts/tests/shared/table/shared-primitives-quality.test.ts
admin_front_ts/tests/shared/i18n/no-visible-chinese.test.ts
admin_front_ts/tests/shared/table/remote-select-contract.test.ts
admin_front_ts/tests/shared/table/useCrudTable.test.ts
admin_front_ts/src/components/Table/src/types.ts
admin_front_ts/src/components/Search/src/index.vue
admin_front_ts/src/components/RemoteSelect/src/index.vue
admin_front_ts/src/components/Table/src/components/TableActions.vue
admin_front_ts/src/hooks/useCrudTable.ts
```

Do not overstate this as “the whole frontend has no any/fallback.” The verified slice is shared primitives only. `TableActions` visible refresh text is now guarded by `no-visible-chinese.test.ts` and uses `common.actions.refresh`.

### Admin frontend hardening backlog



`ADMIN-FRONT-HARDENING-013` is resolved for remaining tracked demo any rows: `tests/shared/form/form-demo-source-quality.test.ts`, `tests/shared/display/display-demo-source-quality.test.ts`, and `tests/shared/effect/particle-background-source-quality.test.ts` guard `form/index.vue`, `display/index.vue`, and `ParticleBackground.vue` against `any` and hidden numeric fallbacks. The refreshed source-quality inventory reports `0` `any` candidates, `0` `as any`, `0` `catch(error: any)`, `511` fallback candidates, and `0` direct external HTTP candidates. `docs/knowledge/admin-front-demo-any-source-quality-review-2026-06-07.md` records the decision.
Current open frontend gaps are tracked in `docs/status/known-issues.md`. After the Admin AI interaction retirement, no open issue is tracked there for Admin Vue any/as-any/catch-any/direct-external rows; those candidates are currently zero, and the remaining `511` fallback rows stay as review inventory.

`ADMIN-FRONT-HARDENING-012` is resolved for upload demo media-list typing: `tests/shared/upload/upload-demo-source-quality.test.ts` guards `src/views/Main/component/upload/index.vue` against `ref<any[]>`; the page and `UpMediaList.vue` now share `UploadMediaItem` from `components/media.ts`. `docs/knowledge/admin-front-upload-demo-source-quality-review-2026-06-07.md` records the decision.

`ADMIN-FRONT-HARDENING-011` is resolved for `useValidator.ts` validator typing and message handling: `tests/shared/validator/use-validator-source-quality.test.ts` guards `src/hooks/web/useValidator.ts` against `val: any` and `message ||` fallback; the composable now uses `ValidatorValue = string`, explicit `LengthRange`, and `resolveValidatorMessage(message, fallback)` so only `undefined` uses i18n fallback. `docs/knowledge/admin-front-validator-source-quality-review-2026-06-07.md` records the decision.

`ADMIN-FRONT-HARDENING-009` is resolved for DownloadManager error and filename handling: `tests/shared/download-manager/download-manager-source-quality.test.ts` guards `DownloadManager/src/download.ts` against `catch (...: any)`, Web fetch failed-download `window.open(url, '_blank')` fallback, and filename `||` chains; `DownloadManager/src/errors.ts` requires real non-empty `Error.message` values, and `download.ts` now derives filenames through explicit helpers. `docs/knowledge/admin-front-download-manager-source-quality-review-2026-06-07.md` records the decision.

Admin dev test download error handling is resolved for the remaining catch-any row: `tests/shared/download-manager/dev-test-download-source-quality.test.ts` guards `src/views/Main/test/index.vue` against `catch (error: any)`, `error.message || t(...)`, and `testFilename.value || undefined`; the page now catches `unknown`, requires a non-empty `Error.message`, and uses an explicit optional filename helper. `docs/knowledge/admin-front-dev-test-download-source-quality-review-2026-06-07.md` records the decision.

`ADMIN-FRONT-HARDENING-008` is resolved for wangEditor wrapper typing and upload URL handling: `tests/shared/editor/editor-source-quality.test.ts` guards `src/views/Main/component/display/components/Editor.vue` against `any/as any` and `result.url ||` upload URL fallback; the component now uses wangEditor exported types and `requireUploadURL(result.url)`. `docs/knowledge/admin-front-editor-source-quality-review-2026-06-07.md` records the decision.

`ADMIN-FRONT-HARDENING-007` is resolved for DIcon Element Plus dynamic-module typing: `tests/shared/icon/dicon-source-quality.test.ts` guards `DIcon/src/index.vue` against `(mod as any)` and `as unknown as Promise<Record<string, Component>>`; the component now narrows runtime icon names through `keyof typeof import('@element-plus/icons-vue')`. `docs/knowledge/admin-front-dicon-source-quality-review-2026-06-07.md` records the decision.

`ADMIN-FRONT-HARDENING-006` is resolved for JsonEditor parse-error and touched i18n handling: `tests/shared/json-editor/json-editor-source-quality.test.ts` guards `JsonEditor/src/index.vue` and `JsonEditor/src/json.ts` against `catch any`, optional-chain error fallback, implicit empty-editor fallback, and raw visible Chinese. `docs/knowledge/admin-front-json-editor-source-quality-review-2026-06-07.md` records the decision.

`ADMIN-FRONT-HARDENING-005` is resolved for forgot-password request-error handling: `tests/shared/user/forgot-password-source-quality.test.ts` guards `useForgotPassword.ts` against `catch (error: any)` and `error?.message ||` fallbacks, and `docs/knowledge/admin-front-forgot-password-error-source-quality-review-2026-06-07.md` records the decision.

`ADMIN-FRONT-HARDENING-003` is resolved: `admin_front_ts/src/api/tools.ts` was unused, deleted, and guarded by `admin_front_ts/tests/shared/api/no-direct-external-helper.test.ts`; `docs/knowledge/admin-front-direct-external-helper-review-2026-06-07.md` records the decision.

`ADMIN-FRONT-HARDENING-004` is resolved for Header breadcrumb route-walk typing: `tests/layout/header-source-quality.test.ts` guards `Header/index.vue`, and `docs/knowledge/admin-front-header-breadcrumb-source-quality-review-2026-06-07.md` records the decision.

`ADMIN-FRONT-HARDENING-002` is resolved only for `SearchDialog.vue` route-walk typing: `tests/layout/search-dialog-source-quality.test.ts` guards the component against `any/as any`, and the component now walks `PermissionMenuItem` data through explicit search result types.

Admin user status is an active frontend contract call. `UsersListApi.changeStatus()` calls `PATCH /api/admin/v1/users/:id/status`, and the user list status actions use `user_userManager_edit` with no batch-edit fallback. `docs/knowledge/admin-user-status-contract-review-2026-06-07.md` records the source evidence.

Admin AI agent test is an active frontend contract call. `AiAgentApi.test()` calls `POST /api/admin/v1/ai-agents/:id/test`, and the AI agent list action is visible only for enabled rows with `ai_agent_test`. `docs/knowledge/admin-ai-agent-test-contract-review-2026-06-07.md` records the source evidence.

`docs/knowledge/admin-front-source-quality-inventory-2026-06-08.md` is the current regex source inventory for Admin Vue quality debt. Current counts are `274` source files scanned, `0` `any` candidates, `0` `as any` candidates, `0` `catch(error: any)` candidates, `511` fallback candidates, and `0` direct external HTTP candidates. Treat those rows as review evidence, not automatic fixes and not a build failure by themselves.

## Canvas frontend: Next app

Canvas is not a billing client. It is a Next frontend for `/api/canvas/v1/*`.

### Tech and deployment

```text
Next 16.2.3
React 19.2.5
Ant Design 6
Zustand 5
React Query 5
axios
```

The browser uses relative `/api/canvas/v1/*` URLs. Next route proxy `src/app/api/[...path]/route.ts` forwards to `API_BASE_URL`, defaulting to `http://127.0.0.1:8080`. Production deployment is Next standalone, not static export.

### Runtime contract

- Auth uses backend login-config: `/api/canvas/v1/auth/login-config`.
- Logout calls backend revoke: `POST /api/canvas/v1/auth/logout`, then clears local browser state only after backend success.
- Current user uses `/api/canvas/v1/users/me`.
- Public settings uses `/api/canvas/v1/settings`.
- Prompts/assets use `/api/canvas/v1/prompts` and `/api/canvas/v1/assets`.
- Image generation uses `/api/canvas/v1/ai/images*`.
- Admin AI interaction retirement: `/api/admin/v1/ai-images*`, `/api/admin/v1/ai-assets*`, `/ai/image-playground`, and `/ai/assets` are not active runtime surfaces; Canvas assets are current-user-owned through `ai_assets.user_id`, and no public asset library exists.
- Video generation uses `/api/canvas/v1/ai/videos*`.
- Chat/text generation uses `/api/canvas/v1/ai/chat/completions`.

### Auth and RBAC

```text
(user) layout -> ClientRootInit -> CanvasAuthGuard
401 -> /login
403 -> no-access state
router -> PAGE route access
buttonCodes -> BUTTON/action access only
```

Canvas route registry currently exposes:

```text
/canvas
/image
/video
/prompts
/assets
/profile
```

### Agent settings

`/api/canvas/v1/settings` returns `agents.text`, `agents.image`, and `agents.video`. The frontend formats a selected agent as `agent:{id}` and active generation requests submit `agent_id`; provider/model dispatch remains backend-owned. `docs/knowledge/canvas-ai-request-contract-review-2026-06-07.md` records the active request shapes and forbidden provider/model override fields.

Canvas `buttonCodes` do not include a separate active text-generation permission. `canvas_ai_text_generate` was verified as a soft-deleted live MySQL orphan and removed from the Canvas Next canonical permission type; active generation BUTTON codes remain `canvas_ai_image_generate` and `canvas_ai_video_generate`. `docs/knowledge/canvas-rbac-permission-contract-review-2026-06-07.md` records the live DB/source evidence.

Canvas asset top-level route is `/assets` only. `/asset-library` was verified as a dead page and removed; the public-library API remains `GET /api/canvas/v1/assets`, with active frontend use in the in-canvas asset picker gated by `canvas_asset_read`. `canvas_front_next` asset ZIP import/export now fails closed on malformed `assets.json`, invalid image/video metadata, storageKey/mime/bytes mismatch, missing declared blobs, ZIP entry size mismatch, orphan file entries, and media assets whose blobs cannot be packaged. Backend Canvas asset create/update now also fails closed for image/video media assets unless `content` is strict JSON metadata with storage-backed `storageKey`, positive `width`/`height`/`bytes`, and matching `mimeType`; `audio` asset support is still not active. `docs/knowledge/canvas-asset-route-contract-review-2026-06-07.md` records the live DB/source evidence for the route boundary.

Canvas logout is an active frontend contract call, not a backend-only route. `useUserStore.logout()` calls `POST /api/canvas/v1/auth/logout` with the current bearer token before clearing token/user/RBAC state; backend failure preserves the browser session instead of hiding the failure behind local cleanup. `docs/knowledge/canvas-auth-logout-contract-review-2026-06-07.md` records the source evidence.

### React / Next performance rules to keep

- Start independent requests early and await late; avoid waterfalls.
- Use direct imports for heavy UI/code paths; do not create large barrel imports.
- Keep request-specific state out of module globals in RSC/SSR paths.
- Minimize serialized props across server/client boundaries.
- Use memoization only for expensive work; do not memo trivial primitives.
- Keep frequently changing transient values in refs or scoped stores, not app-wide re-render state.
- Prefer route-local data clients and typed API wrappers over ad-hoc fetches inside deeply nested components.

### Canvas documentation gaps

Current open gaps are tracked in `docs/status/known-issues.md`. `CANVAS-DOC-001` is resolved as a dead frontend type drift cleanup: `canvas_ai_text_generate` is not an active BUTTON code and is guarded by `canvas_front_next/tests/shared/canvas-rbac-shell.test.ts`. `CANVAS-DOC-002` is resolved as a dead route cleanup: `/asset-library` is not an active Canvas page and `/assets` remains the only top-level asset page. `CANVAS-DOC-003` is resolved as an `agent_id`-only request contract guard: chat/video reject provider/model override fields, and the artifact `docs/knowledge/canvas-ai-request-contract-review-2026-06-07.md` records the boundary. `CANVAS-DOC-004` is now resolved as documentation wording only: retained Canvas payment/wallet基础域 routes are exact in `docs/contracts/admin-api-v1.md`, but no fresh route smoke is claimed. `API-DRIFT-001` is resolved with `0` owner-decision-required rows in `docs/knowledge/api-source-only-route-review-2026-06-08.md`; the remaining `19` source-only routes are classified as runtime/system, queue-monitor, retained Canvas payment/wallet, or frontend-parametric upload helper evidence.

## MySQL live schema

Current verified DB snapshot:

```text
docs/db/mysql-live-schema-2026-06-08.md   # table/column/index/count inventory
docs/db/mysql-live-schema-2026-06-08.sql  # full live DDL from mysqldump --no-data
docs/knowledge/db-schema-ownership-map-2026-06-08.md  # live table -> Go model/reference owner source map
docs/knowledge/full-stack-module-map-2026-06-08.md     # backend route + frontend API + DB ownership module map
docs/knowledge/backend-capability-manifest-2026-06-08.md  # Go capability -> source/service/repository/model/table/transport
```

The snapshot was generated from `admin_back_go/.env` `MYSQL_DSN` against live MySQL `DATABASE() = admin` on `127.0.0.1:3307`.
The ownership map starts from that live schema artifact and maps each live table to current Go source model/table references. It is source ownership evidence, not migration history, not runtime path coverage, and not proof that every table is exercised by smoke.

Current ownership-map facts:

```text
Live tables reviewed = 55
go-model = 55
live-schema-only = 0
legacy-table decision = canvas_prompts / canvas_assets backed up and dropped by 20260608_ai_prompt_asset_drop_legacy.sql
```

Refresh command:

```powershell
cd E:\admin_go
powershell -ExecutionPolicy Bypass -File .\scripts\export-live-mysql-schema.ps1 -OutputDate 2026-06-08
powershell -ExecutionPolicy Bypass -File .\scripts\export-db-schema-ownership-map.ps1 -OutputDate 2026-06-08
powershell -ExecutionPolicy Bypass -File .\scripts\export-full-stack-module-map.ps1 -OutputDate 2026-06-08
powershell -ExecutionPolicy Bypass -File .\scripts\export-backend-capability-manifest.ps1 -OutputDate 2026-06-08
```

## Generated runtime inventory

Current generated inventory:

```text
docs/knowledge/runtime-inventory-2026-06-08.md
docs/knowledge/backend-route-inventory-2026-06-08.md
docs/knowledge/backend-route-contract-drift-2026-06-08.md
docs/knowledge/frontend-api-inventory-2026-06-08.md
docs/knowledge/frontend-backend-api-drift-2026-06-08.md
docs/knowledge/api-source-only-route-review-2026-06-08.md
docs/knowledge/db-schema-ownership-map-2026-06-08.md
docs/knowledge/full-stack-module-map-2026-06-08.md
docs/knowledge/backend-capability-manifest-2026-06-08.md
docs/knowledge/admin-front-source-quality-inventory-2026-06-08.md
```

Refresh command:

```powershell
cd E:\admin_go
powershell -ExecutionPolicy Bypass -File .\scripts\export-runtime-inventory.ps1 -OutputDate 2026-06-08
powershell -ExecutionPolicy Bypass -File .\scripts\export-backend-route-inventory.ps1 -OutputDate 2026-06-08
powershell -ExecutionPolicy Bypass -File .\scripts\export-backend-route-contract-drift.ps1 -OutputDate 2026-06-08
powershell -ExecutionPolicy Bypass -File .\scripts\export-frontend-api-inventory.ps1 -OutputDate 2026-06-08
powershell -ExecutionPolicy Bypass -File .\scripts\export-frontend-backend-api-drift.ps1 -OutputDate 2026-06-08
powershell -ExecutionPolicy Bypass -File .\scripts\export-api-source-only-route-review.ps1 -OutputDate 2026-06-08
powershell -ExecutionPolicy Bypass -File .\scripts\export-db-schema-ownership-map.ps1 -OutputDate 2026-06-08
powershell -ExecutionPolicy Bypass -File .\scripts\export-full-stack-module-map.ps1 -OutputDate 2026-06-08
powershell -ExecutionPolicy Bypass -File .\scripts\export-backend-capability-manifest.ps1 -OutputDate 2026-06-08
powershell -ExecutionPolicy Bypass -File .\scripts\export-admin-front-source-quality-inventory.ps1 -OutputDate 2026-06-08
```

`backend-route-inventory-2026-06-08.md` is route source inventory only. It currently records `287` Go route registrations, `0` unresolved path expressions, `1` callback exception registration, and `0` unmatched `route_meta` keys. Do not treat it as served endpoint proof; smoke/runtime behavior still wins.
`backend-route-contract-drift-2026-06-08.md` compares those `287` route registrations with current contract/status/knowledge Markdown. Current result: `287` contract-exact, `0` contract-prefix-only, `0` source-docs-only, `0` undocumented-exact. Prefix-only is not exact contract coverage.
`frontend-api-inventory-2026-06-08.md` is frontend source inventory only. It currently records `281` frontend API call expressions, `240` Admin backend calls, `26` Canvas backend calls, `3` external HTTP calls, and `0` unresolved expressions. It separates blob/download, wrapper, and proxy calls so they do not become false backend contract drift.
`frontend-backend-api-drift-2026-06-08.md` compares exact frontend backend API calls with backend route source inventory. Current result: `266` exact frontend backend calls compared, `266` route-match, `0` method-mismatch, `0` no-backend-route. It also records `19` admin/canvas backend source routes not referenced by exact frontend calls; those are review evidence, not automatic bugs.
`api-source-only-route-review-2026-06-08.md` classifies those `19` source-only routes: `4` runtime/system, `3` queue-monitor, `6` retained Canvas payment/wallet, `6` frontend-parametric upload delete helper, and `0` owner-decision-required routes.
`db-schema-ownership-map-2026-06-08.md` maps the `55` live MySQL tables to current Go model/reference owner candidates. Current result: `55` tables have Go model ownership and `0` tables are live-schema-only after the legacy Canvas prompt/asset tables were retired.
`full-stack-module-map-2026-06-08.md` joins backend route inventory, frontend API inventory, DB schema ownership, and source-only review by capability. Current result: `287` backend route registrations joined, `266` frontend exact backend calls assigned, `0` unassigned exact frontend calls, `55` live DB tables mapped, and `0` owner-decision-required routes preserved.
`backend-capability-manifest-2026-06-08.md` maps Go backend capabilities to current source directories, direct service/repository/model files, route surfaces, direct tests, and live DB model-owned tables. Current result: `38` capabilities, `287` route registrations covered, and `4` helper packages not promoted to capability (`ai/internal/canvasrequest`, `auth/verifycode`, `payment/serialno`, `queuemonitor/asynqmonui`).
`backend-capability-runbook-2026-06-08.md` turns those `38` capabilities into a per-capability handoff table with source owner files, route surfaces, frontend-call counts, DB tables, direct tests, and first verification command. Use it before changing Go behavior; it does not replace source inspection.
`frontend-page-runtime-map-2026-06-08.md` maps `41` frontend pages (`32` Admin Vue + `9` Canvas Next) to API surfaces, permission/button codes, and DB/runtime ownership. Use it to answer “which page owns this API/table/permission?” before touching UI.
`docker-env-smoke-runbook-2026-06-08.md` records the Docker-first state/backend split, local Compose commands, env ownership, and smoke commands. Use it before restarting containers or changing deployment docs.
`failure-troubleshooting-playbook-2026-06-08.md` maps common backend/API/schema/frontend/docs failures to first checks, capability owners, and bad fixes to reject. Use it before broad repo scans.
`admin-canvas-user-flow-runtime-map-2026-06-08.md` records Admin and Canvas login/bootstrap/RBAC/API/logout user flows and the invariants around `/users/me`, Canvas active PAGE/BUTTON rows, `agent_id`, and retired Canvas drift.
`admin-front-source-quality-inventory-2026-06-08.md` maps Admin Vue source-quality candidates under `admin_front_ts/src`. Current result: `274` source files scanned, `0` `any` candidates, `0` `as any` candidates, `0` `catch(error: any)` candidates, `511` fallback candidates, and `0` direct external HTTP candidates. It strips comments before scanning and keeps `Header/index.vue`, `SearchDialog.vue`, `useForgotPassword.ts`, `JsonEditor/index.vue`, `DIcon/index.vue`, `Editor.vue`, `DownloadManager/src/download.ts`, `views/Main/component/download/index.vue`, `views/Main/test/index.vue`, and `useValidator.ts` as priority evidence; `Header/index.vue`, `JsonEditor/index.vue`, `Editor.vue`, `views/Main/component/download/index.vue`, and `views/Main/test/index.vue` now have no configured source-quality finding, `DIcon/index.vue` no longer has any/as-any findings but still records explicit missing-icon null-state fallback rows, `DownloadManager/src/download.ts` now has no configured source-quality finding, `useForgotPassword.ts` now only has validation predicate logical-or rows, `useValidator.ts` now only has a validation predicate logical-or row, and `upload/index.vue` now has no configured source-quality finding, but do not turn this inventory into a regex replacement sweep.

## Quality hardening order

Do not sweep the entire repo with regex replacement. Use this order:

```text
1. shared primitives and contract adapters
2. auth/current-user/RBAC bootstrap
3. payment/wallet/recharge
4. AI provider/agent/tool/knowledge/run/chat/image/video
5. notification/mail/sms/upload/export/cron
6. Canvas-specific frontend flows
```

For each batch:

```text
RED guard -> minimal code/docs change -> targeted tests/typecheck -> current-status/knowledge sync
```
