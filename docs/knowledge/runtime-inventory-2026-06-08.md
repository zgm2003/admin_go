# Runtime Inventory Snapshot

Generated at: 2026-06-08 11:50:19 +08:00

This artifact is generated from current source manifests and directory structure. It is a navigation inventory, not runtime proof. Served API behavior, smoke/tests, and live MySQL schema still outrank this file.

## Source summary

| Source | Current fact |
| --- | --- |
| Go version | `1.26.1` |
| admin_front_ts `vue` | `^3.5.24` |
| admin_front_ts `vite` | `^8.0.3` |
| admin_front_ts `typescript` | `~5.9.3` |
| admin_front_ts `element-plus` | `^2.13.0` |
| admin_front_ts `pinia` | `^3.0.2` |
| admin_front_ts `vue-i18n` | `^9.13.0` |
| admin_front_ts `axios` | `^1.8.4` |
| canvas_front_next `next` | `16.2.3` |
| canvas_front_next `react` | `19.2.5` |
| canvas_front_next `typescript` | `^5` |
| canvas_front_next `antd` | `^6.4.2` |
| canvas_front_next `zustand` | `^5.0.12` |
| canvas_front_next `@tanstack/react-query` | `^5.100.9` |
| canvas_front_next `axios` | `^1.16.0` |
| Latest MySQL schema artifact | `docs/db/mysql-live-schema-2026-06-08.md` / `docs/db/mysql-live-schema-2026-06-08.sql` |
| Latest MySQL base table count | `55` |

## Backend module transport inventory

Rule: `callback` is an external callback HTTP surface exception, not a business platform.

| Capability | HTTP surfaces from source tree |
| --- | --- |
| `ai` | `agent/transport/admin`, `asset/transport/admin`, `asset/transport/canvas`, `chat/transport/admin`, `chat/transport/canvas`, `conversation/transport/admin`, `image/transport/admin`, `image/transport/canvas`, `knowledge/transport/admin`, `message/transport/admin`, `prompt/transport/admin`, `prompt/transport/canvas`, `provider/transport/admin`, `run/transport/admin`, `tool/transport/admin`, `video/transport/canvas` |
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

## Backend route fragments from transport source

These are route fragments found in module transport route files. They are useful for code navigation, but full served paths must still be verified through Gin route registration, route metadata, contract docs, or smoke.

| Route file | Method fragments |
| --- | --- |
| `admin_back_go/internal/module/ai/agent/transport/admin/route.go` | `DELETE /:id`<br>`GET /`<br>`GET /:id`<br>`GET /options`<br>`GET /page-init`<br>`GET /provider-models/:id`<br>`PATCH /:id/status`<br>`POST /`<br>`POST /:id/test`<br>`PUT /:id` |
| `admin_back_go/internal/module/ai/asset/transport/canvas/route.go` | `DELETE /assets/:id`<br>`GET /assets`<br>`POST /assets`<br>`PUT /assets/:id` |
| `admin_back_go/internal/module/ai/chat/transport/canvas/route.go` | `POST /completions` |
| `admin_back_go/internal/module/ai/conversation/transport/admin/route.go` | `DELETE /:id`<br>`GET /`<br>`GET /:id`<br>`POST /`<br>`PUT /:id` |
| `admin_back_go/internal/module/ai/image/transport/canvas/route.go` | `DELETE /:id`<br>`GET /`<br>`GET /:id`<br>`POST /edits`<br>`POST /generations` |
| `admin_back_go/internal/module/ai/knowledge/transport/admin/route.go` | `DELETE /ai-knowledge-bases/:id`<br>`DELETE /ai-knowledge-documents/:id`<br>`GET /ai-agents/:id/knowledge-bases`<br>`GET /ai-knowledge-bases`<br>`GET /ai-knowledge-bases/:id`<br>`GET /ai-knowledge-bases/:id/documents`<br>`GET /ai-knowledge-bases/page-init`<br>`GET /ai-knowledge-documents/:id`<br>`GET /ai-knowledge-documents/:id/chunks`<br>`PATCH /ai-knowledge-bases/:id/status`<br>`PATCH /ai-knowledge-documents/:id/status`<br>`POST /ai-knowledge-bases`<br>`POST /ai-knowledge-bases/:id/documents`<br>`POST /ai-knowledge-bases/:id/retrieval-tests`<br>`POST /ai-knowledge-documents/:id/reindex`<br>`PUT /ai-agents/:id/knowledge-bases`<br>`PUT /ai-knowledge-bases/:id`<br>`PUT /ai-knowledge-documents/:id` |
| `admin_back_go/internal/module/ai/message/transport/admin/route.go` | `GET /api/admin/v1/ai-conversations/:id/messages`<br>`POST /api/admin/v1/ai-conversations/:id/messages`<br>`POST /api/admin/v1/ai-conversations/:id/messages/cancel` |
| `admin_back_go/internal/module/ai/prompt/transport/admin/route.go` | `DELETE /`<br>`DELETE /:id`<br>`GET /`<br>`GET /:id`<br>`GET /page-init`<br>`PATCH /:id/status`<br>`POST /`<br>`PUT /:id` |
| `admin_back_go/internal/module/ai/prompt/transport/canvas/route.go` | `GET /prompts` |
| `admin_back_go/internal/module/ai/provider/transport/admin/route.go` | `DELETE /:id`<br>`GET /`<br>`GET /:id/models`<br>`GET /page-init`<br>`PATCH /:id/status`<br>`POST /`<br>`POST /:id/model-options`<br>`POST /:id/sync-models`<br>`POST /:id/test`<br>`POST /model-options`<br>`PUT /:id`<br>`PUT /:id/models` |
| `admin_back_go/internal/module/ai/run/transport/admin/route.go` | `GET /`<br>`GET /:id`<br>`GET /page-init`<br>`GET /stats`<br>`GET /stats/by-agent`<br>`GET /stats/by-date`<br>`GET /stats/by-user` |
| `admin_back_go/internal/module/ai/tool/transport/admin/route.go` | `DELETE /:id`<br>`GET /`<br>`GET /:id/tools`<br>`GET /generate/page-init`<br>`GET /page-init`<br>`PATCH /:id/status`<br>`POST /`<br>`POST /generate-draft`<br>`PUT /:id`<br>`PUT /:id/tools` |
| `admin_back_go/internal/module/ai/video/transport/canvas/route.go` | `GET /:id`<br>`GET /:id/content`<br>`POST /` |
| `admin_back_go/internal/module/auth_platform/transport/admin/route.go` | `DELETE /`<br>`DELETE /:id`<br>`GET /`<br>`GET /page-init`<br>`PATCH /:id/status`<br>`POST /`<br>`PUT /:id` |
| `admin_back_go/internal/module/auth/transport/admin/route.go` | `GET /`<br>`GET /captcha`<br>`GET /login-config`<br>`GET /page-init`<br>`GET /stats`<br>`PATCH /:id/revoke`<br>`PATCH /revoke`<br>`POST /forgot-password`<br>`POST /login`<br>`POST /logout`<br>`POST /refresh`<br>`POST /send-code` |
| `admin_back_go/internal/module/auth/transport/app/route.go` | `GET /captcha`<br>`GET /login-config`<br>`POST /login`<br>`POST /logout`<br>`POST /send-code` |
| `admin_back_go/internal/module/auth/transport/canvas/route.go` | `GET /captcha`<br>`GET /login-config`<br>`POST /login`<br>`POST /logout`<br>`POST /refresh`<br>`POST /send-code` |
| `admin_back_go/internal/module/canvas/transport/canvas/route.go` | `GET /settings` |
| `admin_back_go/internal/module/clientversion/transport/admin/route.go` | `DELETE /:id`<br>`GET /`<br>`GET /current-check`<br>`GET /page-init`<br>`GET /update-json`<br>`PATCH /:id/force-update`<br>`PATCH /:id/latest`<br>`POST /`<br>`PUT /:id` |
| `admin_back_go/internal/module/crontask/transport/admin/route.go` | `DELETE /`<br>`DELETE /:id`<br>`GET /`<br>`GET /:id/logs`<br>`GET /page-init`<br>`PATCH /:id/status`<br>`POST /`<br>`PUT /:id` |
| `admin_back_go/internal/module/export/transport/admin/route.go` | `DELETE /`<br>`DELETE /:id`<br>`GET /`<br>`GET /status-count` |
| `admin_back_go/internal/module/mail/transport/admin/route.go` | `DELETE /config`<br>`DELETE /logs`<br>`DELETE /logs/:id`<br>`DELETE /templates/:id`<br>`GET /config`<br>`GET /logs`<br>`GET /logs/:id`<br>`GET /page-init`<br>`GET /templates`<br>`PATCH /templates/:id/status`<br>`POST /templates`<br>`POST /test`<br>`PUT /config`<br>`PUT /templates/:id` |
| `admin_back_go/internal/module/notification/transport/admin/route.go` | `DELETE /`<br>`DELETE /:id`<br>`GET /`<br>`GET /page-init`<br>`GET /unread-count`<br>`PATCH /:id/read`<br>`PATCH /read` |
| `admin_back_go/internal/module/notification/transport/admin/task_route.go` | `DELETE /:id`<br>`GET /`<br>`GET /page-init`<br>`GET /status-count`<br>`PATCH /:id/cancel`<br>`POST /` |
| `admin_back_go/internal/module/operationlog/transport/admin/route.go` | `DELETE /`<br>`DELETE /:id`<br>`GET /`<br>`GET /page-init` |
| `admin_back_go/internal/module/payment/transport/admin/route.go` | `DELETE /:id`<br>`GET /`<br>`GET /:id`<br>`GET /page-init`<br>`PATCH /:id/status`<br>`POST /`<br>`POST /:id/pay`<br>`POST /:id/test`<br>`POST /api/admin/v1/payment/certificates`<br>`PUT /:id` |
| `admin_back_go/internal/module/payment/transport/callback/route.go` | `POST /alipay` |
| `admin_back_go/internal/module/payment/transport/canvas/route.go` | `GET /`<br>`GET /page-init`<br>`POST /`<br>`POST /:id/pay` |
| `admin_back_go/internal/module/payment/wallet/transport/admin/route.go` | `GET /`<br>`GET /page-init`<br>`GET /summary`<br>`GET /transactions` |
| `admin_back_go/internal/module/payment/wallet/transport/canvas/route.go` | `GET /summary`<br>`GET /transactions` |
| `admin_back_go/internal/module/permission/transport/admin/route.go` | `DELETE /`<br>`DELETE /:id`<br>`GET /`<br>`GET /page-init`<br>`PATCH /:id/status`<br>`POST /`<br>`PUT /:id` |
| `admin_back_go/internal/module/profile/transport/admin/route.go` | `GET /`<br>`PUT /`<br>`PUT /security/email`<br>`PUT /security/password`<br>`PUT /security/phone` |
| `admin_back_go/internal/module/profile/transport/app/route.go` | `GET /`<br>`PUT /` |
| `admin_back_go/internal/module/profile/transport/canvas/route.go` | `GET /`<br>`PUT /` |
| `admin_back_go/internal/module/queuemonitor/transport/admin/route.go` | `GET /`<br>`GET /failed` |
| `admin_back_go/internal/module/role/transport/admin/route.go` | `DELETE /`<br>`DELETE /:id`<br>`GET /`<br>`GET /page-init`<br>`PATCH /:id/default`<br>`POST /`<br>`PUT /:id` |
| `admin_back_go/internal/module/sms/transport/admin/route.go` | `DELETE /config`<br>`DELETE /logs`<br>`DELETE /logs/:id`<br>`DELETE /templates/:id`<br>`GET /config`<br>`GET /logs`<br>`GET /logs/:id`<br>`GET /page-init`<br>`GET /templates`<br>`PATCH /templates/:id/status`<br>`POST /templates`<br>`POST /test`<br>`PUT /config`<br>`PUT /templates/:id` |
| `admin_back_go/internal/module/system/transport/admin/route.go` | `GET /health`<br>`GET /ping`<br>`GET /ready` |
| `admin_back_go/internal/module/systemlog/transport/admin/route.go` | `GET /files`<br>`GET /files/:name/lines`<br>`GET /page-init` |
| `admin_back_go/internal/module/systemsetting/transport/admin/route.go` | `DELETE /`<br>`DELETE /:id`<br>`GET /`<br>`GET /page-init`<br>`PATCH /:id/status`<br>`POST /`<br>`PUT /:id` |
| `admin_back_go/internal/module/uploadconfig/transport/admin/route.go` | `DELETE /`<br>`DELETE /:id`<br>`GET /`<br>`GET /page-init`<br>`PATCH /:id/status`<br>`POST /`<br>`PUT /:id` |
| `admin_back_go/internal/module/uploadtoken/transport/admin/route.go` | `POST /` |
| `admin_back_go/internal/module/uploadtoken/transport/app/route.go` | `POST /` |
| `admin_back_go/internal/module/user/transport/admin/route.go` | `DELETE /`<br>`DELETE /:id`<br>`GET /`<br>`GET /:id/profile`<br>`GET /me`<br>`GET /page-init`<br>`PATCH /`<br>`PATCH /:id/status`<br>`POST /export`<br>`PUT /:id` |
| `admin_back_go/internal/module/user/transport/app/route.go` | `GET /me` |
| `admin_back_go/internal/module/user/transport/canvas/route.go` | `GET /me` |

## Admin Vue inventory

| Area | Current source items |
| --- | --- |
| API modules | `ai`, `payment`, `permission`, `system`, `user`, `wallet` |
| Shared components | `AppCaptcha`, `AppDialog`, `DIcon`, `DownloadManager`, `EmojiPicker`, `JsonEditor`, `MarkdownRenderer`, `NetworkStatusNotice`, `NotificationRuntime`, `RemoteSelect`, `Search`, `SendCode`, `Table`, `TauriManager`, `UpFile`, `UpMedia` |
| Hooks | `useCopy.ts`, `useCrudTable.ts`, `useExportSubmit.ts`, `useNetworkStatus.ts`, `useResponsive.ts`, `useTheme.ts`, `useWebSocket.ts` |
| Router files | `guard-helpers.ts`, `guards.ts`, `index.ts`, `routes.ts`, `runtime-route-tree.ts`, `view-registry.ts` |
| Store files | `menu.ts`, `tauri.ts`, `user.ts` |
| View files count | `146` |

## Canvas Next inventory

| Area | Current source items |
| --- | --- |
| App pages | `(auth)/login`<br>`(user)/assets`<br>`(user)/canvas/[id]`<br>`(user)/canvas`<br>`(user)/image`<br>`(user)`<br>`(user)/profile`<br>`(user)/prompts`<br>`(user)/video` |
| API service files | `admin.ts`, `assets.ts`, `auth.test.ts`, `auth.ts`, `error-payload.ts`, `image-complete-split.test.ts`, `image.test.ts`, `image.ts`, `profile.ts`, `prompts.ts`, `request.test.ts`, `request.ts`, `settings.ts`, `video.test.ts`, `video.ts` |
| Feature directories | `rbac` |
| Store files | `use-asset-store.ts`, `use-config-store.test.ts`, `use-config-store.ts`, `use-theme-store.ts`, `use-user-store.test.ts`, `use-user-store.ts` |

## Verification command

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\export-runtime-inventory.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1 -LiveSchema
```
