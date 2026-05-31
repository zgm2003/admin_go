# RESTful API Naming Audit Review

状态：review report / no runtime changes。

审查目标：按 `docs/superpowers/specs/2026-05-30-restful-api-naming-audit-design.md` 细扫当前 Go/Vue 项目里的 RESTful 命名问题，先产出分级报告，不直接重命名。

## Scope

本轮扫描：

```text
admin_back_go/internal/module/**/transport/**/*route*.go
admin_front_ts/src/api/**/*.ts
admin_front_ts/src/**/*.ts
admin_front_ts/src/**/*.vue
admin_front_ts/src/hooks/useCrudTable.ts
admin_front_ts/src/components/Table/src/useTable.ts
docs/**/*.md for old action path residue spot-check
```

本轮排除：

```text
不修改 admin_back_go runtime
不修改 admin_front_ts runtime
不迁移任何 API 调用
不把历史 specs/plans 里的 provenance 当成当前 runtime 缺陷
```

## Commands used

```powershell
rg -n '"[^"]*/(list|add|edit|del)(/|"|\?)' admin_back_go/internal/module -g '*route*.go'
rg -n '\.GET\("/init"|\.GET\("[^"]*/init"' admin_back_go/internal/module -g '*route*.go'
rg -n 'page-init' admin_back_go/internal/module -g '*route*.go'
rg -n '^\\s*(init|add|edit|del|status)\\s*:' admin_front_ts/src/api -g '*.ts'
rg -n 'useCrudTable|api:\\s*\\{?\\s*(\\w+Api|list:|del:|status:)|api:\\s*\\w+Api' admin_front_ts/src -g '*.ts' -g '*.vue'
rg -n '/api/(admin|app)/[^`"\\s)]*/(list|add|edit|del)(/|`|"|\\s|\\))' . -g '!**/node_modules/**' -g '!**/.git/**' -g '!**/dist/**' -g '!**/vendor/**' -g '!**/.tmp*/**'
```

另外用了只读 Python 脚本解析：

```text
backend route.go: method/path/handler
frontend export const *Api object: top-level wrapper method names
frontend direct call sites: Api.method(
```

## Summary

| Area | Result |
| --- | --- |
| Backend route files scanned | 260 route registrations under `internal/module/**/transport/**` |
| P0 `/list /add /edit /del` backend route violation | 0 |
| Frontend request URL using `/list /add /edit /del` | 0 under `admin_front_ts/src/api` |
| Backend non-bootstrap `/init` routes | 12 |
| Backend `/page-init` routes whose handler is still `Init`-style | 8 |
| Backend single-delete routes whose handler is generic `Delete` | 8 |
| Frontend API files scanned | 34 |
| Frontend exact legacy wrapper methods | 92 total: `init` 25, `add` 18, `edit` 17, `del` 21, `status` 11 |
| Direct frontend call sites for those exact legacy methods | 59 direct calls; remaining methods are usually used through `useCrudTable` or currently not directly referenced |
| Public component blocker | `useCrudTable` still requires `api.del` and `api.status` |

Good news: the actual HTTP route layer is mostly RESTful. No current Go route is using `/list`, `/add`, `/edit`, or `/del`. The bad smell is concentrated in old `/init` page dictionary routes and frontend wrapper names.

Bad news: frontend wrapper naming is not a small edge case. The old names are everywhere. A blind replace would be stupid and would break pages.

## P0: URL contract violations

### Verdict

No current backend route violation found for:

```text
/list
/add
/edit
/del
```

No current frontend API request URL found with those suffixes under `admin_front_ts/src/api`.

### Residue in docs

Only historical/design docs mention old action paths. Examples:

```text
docs/contracts/admin-api-v1.md                  # canonical prohibition, not a bug
docs/architecture/05-development-quality-rules.md # canonical prohibition, not a bug
docs/superpowers/specs/2026-05-08-*.md          # historical/provenance wording
docs/superpowers/plans/2026-05-03-*.md          # historical/provenance wording
```

Do not churn old archived/provenance docs just to make grep clean. Current runtime truth is route.go + active contract.

## P1-A: Backend page dictionary routes still using `/init`

These are not `/add/edit/del` action APIs, but they now conflict with the new standard: normal page dictionaries should be `page-init`; `init` should mean bootstrap only.

Allowed exception:

```text
GET /api/admin/v1/users/init
```

That one is current-user bootstrap and should not be reused for user-management page dictionaries.

Non-bootstrap `/init` routes:

| File | Line | Current route | Handler | Recommendation |
| --- | ---: | --- | --- | --- |
| `admin_back_go/internal/module/auth_platform/transport/admin/route.go` | 14 | `GET /api/admin/v1/auth-platforms/init` | `handler.Init` | Add `/page-init`, keep `/init` as temporary alias |
| `admin_back_go/internal/module/crontask/transport/admin/route.go` | 15 | `GET /api/admin/v1/cron-tasks/init` | `handler.Init` | Add `/page-init`, keep `/init` as temporary alias |
| `admin_back_go/internal/module/notification/transport/admin/route.go` | 15 | `GET /api/admin/v1/notifications/init` | `handler.Init` | Add `/page-init`, keep `/init` as temporary alias |
| `admin_back_go/internal/module/notification/transport/admin/task_route.go` | 15 | `GET /api/admin/v1/notification-tasks/init` | `handler.Init` | Add `/page-init`, keep `/init` as temporary alias |
| `admin_back_go/internal/module/operationlog/transport/admin/route.go` | 14 | `GET /api/admin/v1/operation-logs/init` | `handler.Init` | Add `/page-init`, keep `/init` as temporary alias |
| `admin_back_go/internal/module/permission/transport/admin/route.go` | 14 | `GET /api/admin/v1/permissions/init` | `handler.Init` | Add `/page-init`, keep `/init` as temporary alias |
| `admin_back_go/internal/module/role/transport/admin/route.go` | 14 | `GET /api/admin/v1/roles/init` | `handler.Init` | Add `/page-init`, keep `/init` as temporary alias |
| `admin_back_go/internal/module/systemlog/transport/admin/route.go` | 14 | `GET /api/admin/v1/system-logs/init` | `handler.Init` | Add `/page-init`, keep `/init` as temporary alias |
| `admin_back_go/internal/module/systemsetting/transport/admin/route.go` | 14 | `GET /api/admin/v1/system-settings/init` | `handler.Init` | Add `/page-init`, keep `/init` as temporary alias |
| `admin_back_go/internal/module/uploadconfig/transport/admin/route.go` | 14 | `GET /api/admin/v1/upload-drivers/init` | `handler.DriverInit` | Add `/page-init`, keep `/init` as temporary alias |
| `admin_back_go/internal/module/uploadconfig/transport/admin/route.go` | 22 | `GET /api/admin/v1/upload-rules/init` | `handler.RuleInit` | Add `/page-init`, keep `/init` as temporary alias |
| `admin_back_go/internal/module/uploadconfig/transport/admin/route.go` | 30 | `GET /api/admin/v1/upload-settings/init` | `handler.SettingInit` | Add `/page-init`, keep `/init` as temporary alias |

Migration rule: do not remove `/init` first. Add `/page-init`, move frontend wrapper to `pageInit()`, then deprecate old alias later.

## P1-B: Frontend API wrapper exact legacy names

Exact old names found in API wrapper objects:

```text
init/add/edit/del/status
```

Counts:

```text
init   25
add    18
edit   17
del    21
status 11
total  92
```

Grouped findings:

| API object | File | Legacy methods |
| --- | --- | --- |
| `AiAgentApi` | `admin_front_ts/src/api/ai/agents.ts` | `init@232`, `add@241`, `edit@242`, `status@246`, `del@247` |
| `AiBillingRuleApi` | `admin_front_ts/src/api/ai/billingRules.ts` | `init@74`, `add@76`, `edit@77`, `status@78`, `del@79` |
| `AiConversationApi` | `admin_front_ts/src/api/ai/conversations.ts` | `add@72`, `edit@73`, `del@74` |
| `AiImageApi` | `admin_front_ts/src/api/ai/images.ts` | `init@165`, `del@171` |
| `AiKnowledgeApi` | `admin_front_ts/src/api/ai/knowledge.ts` | `init@262`, `add@265`, `edit@266`, `status@270`, `del@271` |
| `AiProviderApi` | `admin_front_ts/src/api/ai/providers.ts` | `init@198`, `add@202`, `edit@203`, `status@207`, `del@215` |
| `AiRunApi` | `admin_front_ts/src/api/ai/runs.ts` | `init@275` |
| `AiToolApi` | `admin_front_ts/src/api/ai/tools.ts` | `init@159`, `add@163`, `edit@164`, `status@168`, `del@169` |
| `PaymentConfigApi` | `admin_front_ts/src/api/payment/config.ts` | `init@94`, `add@96`, `edit@97`, `status@98`, `del@99` |
| `PaymentRechargeApi` | `admin_front_ts/src/api/payment/recharges.ts` | `init@93`, `add@96` |
| `AuthPlatformApi` | `admin_front_ts/src/api/permission/authPlatform.ts` | `init@124`, `add@126`, `edit@127`, `del@131`, `status@139` |
| `PermissionApi` | `admin_front_ts/src/api/permission/permission.ts` | `init@89`, `add@91`, `edit@92`, `status@98` |
| `RoleApi` | `admin_front_ts/src/api/permission/role.ts` | `init@61`, `add@63`, `edit@64`, `del@68` |
| `ClientVersionApi` | `admin_front_ts/src/api/system/clientVersion.ts` | `init@140`, `add@142`, `edit@143`, `del@145` |
| `CronTaskApi` | `admin_front_ts/src/api/system/cronTask.ts` | `init@77`, `add@79`, `edit@80`, `del@81`, `status@84` |
| `ExportTaskApi` | `admin_front_ts/src/api/system/exportTask.ts` | `del@59` |
| `SystemLogApi` | `admin_front_ts/src/api/system/log.ts` | `init@47` |
| `NotificationApi` | `admin_front_ts/src/api/system/notification.ts` | `init@127`, `del@152` |
| `NotificationTaskApi` | `admin_front_ts/src/api/system/notificationTask.ts` | `init@106`, `add@111`, `del@113` |
| `OperationLogApi` | `admin_front_ts/src/api/system/operationLog.ts` | `init@96`, `del@99` |
| `SystemSettingApi` | `admin_front_ts/src/api/system/setting.ts` | `init@111`, `add@113`, `edit@114`, `del@118`, `status@126` |
| `UploadDriverApi` | `admin_front_ts/src/api/system/uploadConfig.ts` | `init@283`, `add@285`, `edit@286`, `del@290` |
| `UploadRuleApi` | `admin_front_ts/src/api/system/uploadConfig.ts` | `init@294`, `add@296`, `edit@297`, `del@301` |
| `UploadSettingApi` | `admin_front_ts/src/api/system/uploadConfig.ts` | `init@305`, `add@307`, `edit@308`, `del@312`, `status@313` |
| `UsersApi` | `admin_front_ts/src/api/user/users.ts` | `init@125` |
| `UsersListApi` | `admin_front_ts/src/api/user/users.ts` | `init@171`, `edit@177`, `del@185` |
| `UsersLoginLogApi` | `admin_front_ts/src/api/user/usersLoginLog.ts` | `init@44` |

Important: `UsersApi.init` is current-user bootstrap and should not be treated the same as page dictionary init. Rename only if we deliberately choose a clearer bootstrap name like `bootstrap()` or `currentUserInit()`; do not blindly convert it to `pageInit()`.

## P1-C: Non-exact wrapper drift worth tracking

These do not match exact old names, but still show inconsistent page-init or CRUD vocabulary:

| File | Line | Current method | Issue |
| --- | ---: | --- | --- |
| `admin_front_ts/src/api/wallet/index.ts` | 85 | `usersInit` | calls `/payment/wallets/page-init`; should probably become resource-specific `WalletUsersApi.pageInit()` or `walletUsersPageInit()` |
| `admin_front_ts/src/api/wallet/index.ts` | 87 | `ledgerInit` | calls `/payment/ledger/page-init`; should probably become `WalletLedgerApi.pageInit()` or `ledgerPageInit()` |
| `admin_front_ts/src/api/ai/tools.ts` | 160 | `generateInit` | calls `/ai-tools/generate/page-init`; should become `generatePageInit()` |
| `admin_front_ts/src/api/system/mail.ts` | 224, 226 | `addTemplate`, `editTemplate` | aliases exist beside `createTemplate` and `updateTemplate`; keep only standard names eventually |

These are lower risk than exact `add/edit/del/init/status`, but new/touched modules should avoid adding more of them.

## P2-A: Backend handler naming drift on `/page-init`

Routes already use `/page-init`, but handler names still say `Init` or domain-specific `*Init` rather than `PageInit`.

| File | Line | Route | Handler |
| --- | ---: | --- | --- |
| `admin_back_go/internal/module/ai/agent/transport/admin/route.go` | 15 | `/api/admin/v1/ai-agents/page-init` | `handler.Init` |
| `admin_back_go/internal/module/ai/knowledge/transport/admin/route.go` | 13 | `/api/admin/v1/ai-knowledge-bases/page-init` | `h.Init` |
| `admin_back_go/internal/module/ai/provider/transport/admin/route.go` | 14 | `/api/admin/v1/ai-providers/page-init` | `handler.Init` |
| `admin_back_go/internal/module/ai/run/transport/admin/route.go` | 14 | `/api/admin/v1/ai-runs/page-init` | `handler.Init` |
| `admin_back_go/internal/module/ai/tool/transport/admin/route.go` | 15 | `/api/admin/v1/ai-tools/page-init` | `handler.Init` |
| `admin_back_go/internal/module/clientversion/transport/admin/route.go` | 15 | `/api/admin/v1/client-versions/page-init` | `handler.Init` |
| `admin_back_go/internal/module/payment/transport/admin/route.go` | 14 | `/api/admin/v1/payment/configs/page-init` | `handler.ConfigInit` |
| `admin_back_go/internal/module/payment/transport/admin/route.go` | 23 | `/api/admin/v1/payment/recharges/page-init` | `handler.RechargeInit` |

Recommendation: low-risk touched-code cleanup. Do not rename these in isolation unless tests are cheap and the module is already being touched.

## P2-B: Backend generic `Delete` handler names

Single-resource DELETE routes using generic `Delete`:

| File | Line | Route | Handler |
| --- | ---: | --- | --- |
| `admin_back_go/internal/module/ai/agent/transport/admin/route.go` | 24 | `DELETE /api/admin/v1/ai-agents/:id` | `handler.Delete` |
| `admin_back_go/internal/module/ai/billing/transport/admin/route.go` | 19 | `DELETE /api/admin/v1/ai-billing-rules/:id` | `handler.Delete` |
| `admin_back_go/internal/module/ai/conversation/transport/admin/route.go` | 18 | `DELETE /api/admin/v1/ai-conversations/:id` | `handler.Delete` |
| `admin_back_go/internal/module/ai/image/transport/admin/route.go` | 20 | `DELETE /api/admin/v1/ai-images/:id` | `handler.Delete` |
| `admin_back_go/internal/module/ai/provider/transport/admin/route.go` | 25 | `DELETE /api/admin/v1/ai-providers/:id` | `handler.Delete` |
| `admin_back_go/internal/module/ai/tool/transport/admin/route.go` | 22 | `DELETE /api/admin/v1/ai-tools/:id` | `handler.Delete` |
| `admin_back_go/internal/module/clientversion/transport/admin/route.go` | 23 | `DELETE /api/admin/v1/client-versions/:id` | `handler.Delete` |
| `admin_back_go/internal/module/notification/transport/admin/task_route.go` | 20 | `DELETE /api/admin/v1/notification-tasks/:id` | `handler.Delete` |

Recommendation: rename to `DeleteOne` when the file is next touched. If no batch delete exists by product design, `Delete` is survivable but less explicit.

## P3: Intentional business command routes

These are not CRUD drift by themselves. They are commands or subresources and should stay if contract docs explain them.

Representative groups:

```text
auth: login-config, captcha, send-code, forgot-password, login, refresh, logout
session: stats, revoke
notification: unread-count, read, cancel, status-count
payment: pay, test, certificates, callbacks
AI provider/tool/knowledge/message: test, sync-models, model-options, generate-draft, reindex, retrieval-tests, cancel
client version: update-json, current-check, latest, force-update
mail/sms: config, test, templates, logs
system: health, ready, ping
```

Rule: command route is acceptable only when it is a real business command, not a disguised CRUD operation. `POST /resources/:id/test` is okay. `POST /resources/add` is not.

## Public component constraint

`useCrudTable` currently encodes the old frontend contract:

```text
api.del?(params: { id: Id | Id[] })
api.status?(params: { id: Id; status: number })
```

Evidence:

```text
admin_front_ts/src/hooks/useCrudTable.ts:11-13 defines del/status
admin_front_ts/src/hooks/useCrudTable.ts:56 calls api.del
admin_front_ts/src/hooks/useCrudTable.ts:83 calls api.del for batch
admin_front_ts/src/hooks/useCrudTable.ts:106 calls api.status
```

This is the real migration choke point. If we rename every API wrapper first, the common CRUD pages break. The simple path is:

```text
1. Extend useCrudTable to accept deleteOne/deleteBatch/changeStatus.
2. Keep del/status as deprecated aliases during migration.
3. Move one module at a time.
4. Remove legacy aliases only after all users are migrated.
```

## Recommended migration order

### Wave 0: no-code guard

Keep the current docs/spec/review. Do not change runtime yet.

### Wave 1: public hook compatibility

Change only `useCrudTable` types and internals so it supports both:

```text
preferred: deleteOne/deleteBatch/changeStatus
legacy:    del/status
```

This removes the structural blocker without touching all pages.

### Wave 2: touched/new modules

Fix modules that are active or recently touched first:

```text
AiBillingRuleApi
WalletApi usersInit/ledgerInit naming
payment config/recharge wrappers
AI agent/provider/tool/knowledge wrappers if currently touched
```

Each module should add standard names first, switch local page calls, then leave old aliases only if another caller still needs them.

### Wave 3: `/init` route aliases

For the 12 non-bootstrap backend `/init` routes:

```text
add /page-init route
keep /init route temporarily
switch frontend to pageInit()
update contract docs
later remove /init only after smoke/contract confirms no frontend caller remains
```

### Wave 4: broad historical cleanup

Only after public hook and touched modules are stable:

```text
permission / role / auth-platform
cron-task / system-setting / upload-config
notification / operation-log / export-task / system-log
AI older wrappers
```

## Do not do this

Do not run a broad search-and-replace:

```text
init -> pageInit
add -> create
edit -> update
del -> deleteOne
status -> changeStatus
```

That will break bootstrap (`users/init`), subresources, public CRUD hook behavior, tests, and probably user-facing pages.

## Suggested next implementation plan

If we choose Balanced migration:

1. Write tests for `useCrudTable` accepting `deleteOne/deleteBatch/changeStatus` while preserving `del/status`.
2. Patch `useCrudTable`.
3. Pick one active module, preferably `AiBillingRuleApi`, and convert its wrapper plus direct page calls.
4. Run targeted frontend tests/typecheck.
5. Repeat module-by-module.
6. Only then touch backend route aliases for old `/init`.

## Verification status for this review

This review is scan-only. It did not run backend/frontend unit tests because it did not change runtime code.

Required docs-only verification before closing this review:

```powershell
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```
