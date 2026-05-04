# Admin Go Migration Current Status

状态更新时间：2026-05-04

本文只记录已经验证的 Go/Vue 迁移事实。不要把 planned 写成 implemented。

| Module | Go backend status | Frontend status | Tests | Smoke | Docs | Remaining risk |
| --- | --- | --- | --- | --- | --- | --- |
| health / ready | implemented: liveness separated from DB/Redis readiness, checks include database/redis/token_redis/queue_redis/realtime | n/a | `internal/readiness`, `internal/module/system`, `internal/bootstrap` | `/ready` in basic smoke | architecture + contract + deployment docs | readiness does not replace full smoke |
| auth login/session | implemented | adapted | `internal/module/auth`, `internal/module/session` | password/code login, refresh/logout, login log count | architecture + contract | real SMS/email sender still dev-mode |
| captcha | implemented | adapted with `go-captcha-vue` | `internal/module/captcha` | real slide challenge in smoke | architecture + contract | only slide supported |
| auth platform | implemented | adapted | `internal/module/authplatform` | init/list in smoke | `docs/contracts/admin-api-v1.md` | broader policy UI polish later |
| RBAC bootstrap | implemented | adapted | `internal/module/user`, `internal/module/permission`, `internal/bootstrap` | users/me + users/init | architecture + contract | no multi-role model in phase one |
| permission definitions | implemented | adapted | `internal/module/permission` | create DIR/PAGE/BUTTON + batch delete | architecture + contract | operation-log hardening is next phase |
| roles | implemented | adapted | `internal/module/role` | grant/restore test role in smoke | architecture + contract | deleting bound roles intentionally blocked |
| users management | implemented for page-init/list/edit/batch-edit/status/delete | adapted for user manager page | `internal/module/user`, `internal/server`, `internal/bootstrap` | users page-init + list in basic smoke | architecture + contract | export still explicit legacy adapter until Go export-task migration |
| system logs | implemented baseline: slog stdout + optional lumberjack file output, read-only logstore, REST files/lines API with path traversal guard | adapted to Go REST API | `internal/platform/logstore`, `internal/platform/logging`, `internal/module/systemlog`, `internal/server` | planned for full smoke probe | architecture + contract + plan | first phase is read-only; no ELK/Loki, no delete/clear/download |
| operation log | implemented | adapted | `internal/module/operationlog`, `internal/middleware`, `internal/server` | full smoke covers init/list/create-triggered log/delete | architecture + contract + smoke matrix | operation log detail viewer not migrated yet |
| queue / worker / monitor | implemented baseline: producer/consumer wrapper, handler registry, cron-to-queue schedule boundary, read-only Asynq inspector summary, official `asynqmon` mounted at `/api/admin/v1/queue-monitor-ui/*` | adapted as thin iframe/new-window wrapper, no duplicate task-list UI | `internal/platform/taskqueue`, `internal/platform/scheduler`, `internal/jobs`, `internal/bootstrap`, `internal/module/queuemonitor`; frontend queue monitor contract test | login log worker path + full smoke queue monitor read-only probe | architecture + contract + smoke matrix | real business cron jobs pending; asynqmon is read-only and must be re-tested on Asynq upgrades |
| realtime / WebSocket / AI streaming | partially implemented: gorilla/websocket thin wrapper, authenticated admin ws route, local connection manager, bounded send queue, read/write pump, connected event, ping/pong, identity topic subscribe whitelist, local/no-op Publisher boundary, typed REALTIME config, explicit disabled 503 | planned | `internal/platform/realtime`, `internal/module/realtime`, `internal/bootstrap`, `internal/config`, `internal/server` | basic smoke covers connect/ping/pong; tests cover subscribe reject, disabled route, local/noop publisher selection | architecture + realtime contract + smoke matrix | no business topic permission/Redis fan-out yet; AI streaming not implemented |

## Current verified RBAC loop

```text
login -> AuthToken -> users/me -> users/init
permission create DIR/PAGE/BUTTON
role update grants PAGE/BUTTON
users/init returns temporary router + buttonCodes
role restore
permission subtree delete
users page-init + users list
logout
```

Verification command:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\basic-admin-smoke.ps1 -Account 15671628271 -Password 123456
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account 15671628271 -Password 123456
```
