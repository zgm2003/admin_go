# Multi-platform Refactor Execution Map

> **For agentic workers:** This is the coordinator map for the post plan-01..04 work. Execute the concrete plans listed below, not this file as code.

**Goal:** Finish the multi-platform backend boundary refactor quickly without regressing existing admin functionality.

**Architecture:** Admin behavior is protected first. Then route/handler transport moves run in parallel lanes with preserved public URLs. Global import changes (`shared/*`, `internal/platform -> internal/infra`) stay sequential.

**Tech Stack:** Go, Gin, Vue admin contract tests, PowerShell, root governance checker.

---

## Non-negotiable rules

1. **Admin first:** existing admin login, menu, RBAC, users, payment, AI, upload, notification, system pages and API URLs must remain compatible.
2. **App best-effort:** app code must compile if touched, but app behavior must not block admin-preserving architecture work.
3. **No URL churn in transport-shell plans:** moving `route.go` / `handler.go` into `transport/admin` must preserve existing `/api/admin/v1/*` endpoints.
4. **No big-bang shared/infra rename:** shared and infra plans are serial because they touch many imports.
5. **Docs truth:** any verified runtime ownership change updates active docs; historical `docs/superpowers/**` keeps provenance.

## Execution order

```text
SERIAL BLOCKER:
  05 admin route safety net + server route group seams

PARALLEL WAVE A after 05:
  06a foundation/admin-runtime transport shells
  06b comms/upload/notification transport shells
  06c AI transport shells
  06d commerce/RBAC transport shells

SERIAL after 06a-06d:
  07 user/profile admin-preserving split
  08 final transport guard + active docs reconciliation
  09 shared/dict + shared/setting boundary
  10 internal/platform -> internal/infra rename
```

## Parallel ownership

| Plan | Can run in parallel | Owns | Must not touch |
|---|---|---|---|
| 05 | no | `internal/server/router.go`, route snapshot, route group seam files | module transport moves |
| 06a | with 06b/06c/06d | `system`, `systemsetting`, `systemlog`, `operationlog`, `crontask`, `queuemonitor`, `clientversion`, `exporttask`, `realtime`; `routes_admin_foundation.go` | user, AI, payment, shared/infra |
| 06b | with 06a/06c/06d | `mail`, `sms`, `notification`, `notificationtask`, `uploadconfig`, `uploadtoken`; `routes_admin_comms.go` | auth/user/payment/AI |
| 06c | with 06a/06b/06d | `aiagent`, `aiprovider`, `aitool`, `aiknowledge`, `aiconversation`, `aimessage`, `airun`, `aichat`, `aiimage`; `routes_admin_ai.go` | non-AI modules |
| 06d | with 06a/06b/06c | `payment`, `wallet`, `permission`, `role`, `authplatform`; `routes_admin_commerce_rbac.go` | user/profile, AI, shared/infra |
| 07 | no | `user`, `userquickentry`, new `profile`; `routes_admin_user.go` | other modules |
| 08 | no | architecture guard, active docs, server group cleanup | new behavior |
| 09 | no | `internal/shared/{dict,setting}` and selected call sites | infra rename |
| 10 | no | `internal/platform -> internal/infra` import rename | business behavior |

## Required gates

After any backend route plan:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/server ./internal/architecture -count=1
go test ./... -count=1
```

After any root governance docs change:

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

When frontend admin risk exists:

```powershell
cd E:\admin_go\admin_front_ts
npm run typecheck
npm run test -- tests/shared/user/users-api.test.ts
```

## Done meaning

- 01-04 + 05-08 = admin route/handler transport boundary done with admin URLs preserved.
- 09-10 = shared/infra target physically represented in code.
- Only after 08 + 09 + 10 pass may the original multi-platform spec be marked implemented.
