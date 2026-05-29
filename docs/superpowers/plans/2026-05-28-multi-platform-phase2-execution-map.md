# Multi-platform Phase 2 Execution Map

> **For agentic workers:** This is the coordinator map for Phase 2. Execute the concrete plans listed below, not this file as code. Use `superpowers:subagent-driven-development` for independent post-11 module slices, and use `superpowers:executing-plans` for serial high-coupling slices.

**Goal:** Finish the parts of `docs/superpowers/specs/2026-05-27-multi-platform-backend-boundary-design.md` that Phase 1 deliberately did not finish: full `shared` package migration and module aggregation.

**Architecture:** Phase 1 protected admin route/handler boundaries and renamed the runtime technical-resource layer to `infra`. Phase 2 keeps admin URLs and behavior stable while moving cross-capability packages under `internal/shared` first, then aggregating legacy-flat modules into capability owners.

**Tech Stack:** Go, Gin, root governance checker, backend architecture tests, admin route snapshot, targeted frontend contract/type checks when admin API behavior is touched.

---

## Current verified baseline

As of 2026-05-28 after Plan 11:

```text
admin route/handler transport boundary: implemented and guarded
internal/platform -> internal/infra: implemented and guarded
internal/shared owns apperror, response, i18n, enum, validate, dict, setting
old root shared-like packages internal/{apperror,response,i18n,enum,validate,dict}: removed and guarded
```

Remaining Phase 2 work after the verified 12a-12d wave:

```text
module aggregation:
  DONE 12a: userquickentry -> profile ownership closure
  DONE 12b: notificationtask -> notification/task ownership
  DONE 12c: exporttask directory -> export
  DONE 12d: authplatform directory -> auth_platform
  DONE 13: AI aggregation map + concrete 14a/14b/14c/15 plan files
  DONE 14a: aiprovider/aiagent/aitool -> internal/module/ai/{provider,agent,tool}
  DONE 14b: aiimage -> internal/module/ai/image
  DONE 14c: aiknowledge -> internal/module/ai/knowledge
  DONE 15: aiconversation/aimessage/aichat/airun -> internal/module/ai/{conversation,message,chat,run}
  TODO: wallet -> payment/wallet decision closure
```

`docs/status/current-status.md` remains the runtime truth source. This Phase 2 map must not be used to claim planned work is implemented.

## Non-negotiable rules

1. **Admin preservation first:** existing admin login, menu, RBAC, users, payment, AI, upload, notification, system pages, and existing admin API URLs must keep working.
2. **No route churn unless a concrete plan says so:** shared package moves and module directory aggregation must not casually change `/api/admin/v1/*` contracts.
3. **No shared/module concurrency:** finish Plan 11 before any module aggregation. Moving `enum`, `apperror`, `response`, `i18n`, `validate`, and `dict` changes imports across nearly every module.
4. **No big-bang AI aggregation before mapping:** AI modules are coupled through provider, agent, tool, conversation, message, run, knowledge, image, and chat runtime. Map first, execute in slices.
5. **No DB schema changes by default:** Phase 2 is package/module boundary work. Schema changes require a separate narrow plan and live DB verification.
6. **No frontend rewrites by default:** run frontend checks only when admin API contract or imports touched by frontend tests can drift.
7. **Docs truth:** active docs can say what is implemented only after fresh verification. Historical superpowers plans/specs keep provenance and do not override runtime.

## Execution order

```text
DONE:
  11 shared package migration

DONE PARALLEL WAVE B:
  12a profile/userquickentry ownership closure
  12b notification + notificationtask aggregation
  12c exporttask -> export rename
  12d authplatform -> auth_platform rename

SERIAL / MAP-FIRST after 12a-12d:
  DONE 13 AI aggregation map

DONE PARALLEL WAVE C, merged sequentially:
  DONE 14a AI provider/agent/tool aggregation slice
  DONE 14b AI image aggregation slice
  DONE 14c AI knowledge aggregation slice

DONE SERIAL after 14a-14c:
  DONE 15 AI conversation/message/chat/run runtime aggregation slice

DECISION SLICE after 11, can run after small-module wave if desired:
  16 wallet/payment ownership decision and first safe slice

FINAL:
  17 Phase 2 guard, docs, and spec closure review
```

## Parallel ownership

| Plan | Can run in parallel | Owns | Must not touch |
|---|---|---|---|
| 11 | no | `internal/shared/*`, old root shared-like packages, imports, shared architecture guard | module aggregation, route URLs, DB schema |
| 12a | done, ran with 12b/12c/12d after 11 | `profile`, `userquickentry`, profile docs/tests | AI, payment/wallet, shared migration |
| 12b | done, ran with 12a/12c/12d after 11 | `notification`, `notificationtask`, scheduler/notification task registration docs/tests | AI, export, auth platform |
| 12c | done, ran with 12a/12b/12d after 11 | `exporttask -> export`, export task route/service/jobs/docs/tests | notification, AI, payment |
| 12d | done, ran with 12a/12b/12c after 11 | `authplatform -> auth_platform`, auth platform admin route/service/docs/tests | auth login behavior, shared migration |
| 13 | no | AI dependency map, exact slice plan files | production code changes |
| 14a | done, ran with 14b/14c in separate worktrees; merged sequentially | `aiprovider`, `aiagent`, `aitool` -> `internal/module/ai/{provider,agent,tool}` | conversation/message/chat/run/image/knowledge runtime mutation beyond tool interface import |
| 14b | done, ran with 14a/14c in separate worktrees; merged sequentially | `aiimage` -> `internal/module/ai/image`, image queue/jobs/tests | provider/agent/tool internals, conversation/message/chat/run |
| 14c | done, ran with 14a/14b in separate worktrees; merged sequentially | `aiknowledge` -> `internal/module/ai/knowledge`, knowledge CRUD/runtime adapter imports | provider/agent/tool internals, conversation/message/chat/run |
| 15 | done, ran serially after 14a-14c | `aiconversation`, `aimessage`, `aichat`, `airun` -> `internal/module/ai/{conversation,message,chat,run}` | provider/tool/image/knowledge internals unless required for imports after 14a-14c |
| 16 | no by default | `wallet` and `payment` ownership decision, first safe move if approved by evidence | payment callback/Alipay finalizer behavior unless in scope |
| 17 | no | final architecture guards, active docs, spec status review | new behavior |

## Required gates

Plan 11 verification gate:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/shared/... -count=1
go test ./internal/architecture -count=1
go test ./internal/server -run TestAdminRouteSnapshot -count=1
go test ./... -count=1
go build ./...

cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

After any module aggregation:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture -count=1
go test ./internal/server -run TestAdminRouteSnapshot -count=1
go test ./... -count=1
```

When a slice changes an admin API DTO, page-init payload, or route binding:

```powershell
cd E:\admin_go\admin_front_ts
npm run typecheck
npm run test -- <touched frontend contract test>
```

AI aggregation gates additionally preserve:

```text
HTTP routes under /api/admin/v1/ai-*
queue task types ai:conversation-reply:v1, ai:run-timeout:v1, ai:image-generate:v1
realtime envelope events ai.response.start/delta/completed/failed.v1
DB table names and semantics for ai_* tables
permission codes in route_meta.go
```

## Done meaning for Phase 2

Phase 2 is done only when all of the following are true:

```text
internal/shared contains apperror, response, i18n, enum, validate, dict, setting
old root shared-like packages are removed or reduced to explicitly documented temporary wrappers with guards
small flat modules are either aggregated or have documented exceptions with tests
AI aggregation has landed through safe slices: 14a-14c plus Plan 15 are complete; remaining Phase 2 blockers are wallet/payment decision and final guard/docs/spec closure
admin route snapshot passes
backend full tests and build pass
active docs say exactly what is implemented
the original multi-platform spec is reviewed against runtime before being marked complete
```

## Why Plan 11 goes first

`enum`, `dict`, `validate`, `apperror`, `response`, and `i18n` are imported by most modules. Running module aggregation at the same time would create noisy import conflicts and make review unable to separate behavior risk from mechanical package moves.

Plan 11 was therefore a serial blocker. It has passed, so small ownership slices can now run in parallel because they touch disjoint module directories.
