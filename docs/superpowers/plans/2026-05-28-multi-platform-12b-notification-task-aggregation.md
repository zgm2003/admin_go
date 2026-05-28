# Notification Task Aggregation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` in the assigned backend worktree. Steps use checkbox (`- [ ]`) syntax for tracking. This plan may run in parallel with 12a/12c/12d only in an isolated worktree.

**Goal:** Move standalone `internal/module/notificationtask` into `internal/module/notification` while preserving notification-task admin URLs, job task types, cron behavior, i18n keys, and payloads.

**Architecture:** `notification` owns notifications and their scheduled dispatch tasks. This slice is a package ownership move, not a product behavior change. Keep DB table `notification_task`, route prefix `/api/admin/v1/notification-tasks`, Asynq task types `notification:send-task:v1` and `notification:dispatch-due:v1`, and message IDs `notificationtask.*` unchanged.

**Tech Stack:** Go, Gin transport, Asynq jobs, scheduler registry, GORM repository, backend architecture tests, route snapshot.

---

## Assigned worktree

```text
E:\admin_go_parallel\p12b-notification
branch: work/p12b-notification
```

## Files

- Move: all non-transport `internal/module/notificationtask/*` into subpackage `internal/module/notification/task/`; move HTTP route files under `internal/module/notification/transport/admin/` as task-prefixed files.
- Modify: `internal/jobs/noop.go`, `internal/jobs/noop_test.go`
- Modify: `internal/bootstrap/app.go`, `internal/bootstrap/worker.go`
- Modify: `internal/module/crontask/*` imports that reference notification task types.
- Modify: `internal/module/exporttask/notifier.go`, `notifier_test.go` imports only if Plan 12c has not already changed them in this branch.
- Modify: `internal/server/routes_admin_comms.go`, `internal/server/router.go`, `internal/server/router_test.go`
- Modify: `internal/architecture/multiplatform_boundary_test.go`
- Backend docs only if needed: `docs/architecture.md`
- Do not modify root docs/status.

## Non-negotiable behavior

```text
/api/admin/v1/notification-tasks URLs unchanged.
notification_task DB table unchanged.
cron_task name notification_task_scheduler unchanged.
Asynq task types unchanged.
message IDs stay notificationtask.*.
No frontend change.
No DB migration.
```

## Task 1: Add architecture guard

- [ ] Add/extend an architecture test that fails while `internal/module/notificationtask` exists and passes when task ownership is under `internal/module/notification`.
- [ ] Also assert `internal/module/notification/transport/admin` still exists and route snapshot remains the route truth.
- [ ] Run:

```powershell
go test ./internal/architecture -run Notification -count=1
```

Expected before implementation: FAIL on standalone `notificationtask`.

## Task 2: Move notification task code into notification/task

- [ ] Move files with history:

```powershell
git mv .\internal\module\notificationtask\dto.go .\internal\module\notification\task_dto.go
git mv .\internal\module\notificationtask\model.go .\internal\module\notification\task_model.go
git mv .\internal\module\notificationtask\repository.go .\internal\module\notification\task_repository.go
git mv .\internal\module\notificationtask\service.go .\internal\module\notification\task_service.go
git mv .\internal\module\notificationtask\service_test.go .\internal\module\notification\task_service_test.go
git mv .\internal\module\notificationtask\jobs.go .\internal\module\notification\task_jobs.go
git mv .\internal\module\notificationtask\jobs_test.go .\internal\module\notification\task_jobs_test.go
git mv .\internal\module\notificationtask\time.go .\internal\module\notification\task_time.go
git mv .\internal\module\notificationtask\i18n_test.go .\internal\module\notification\task_i18n_test.go
```

- [ ] Move transport files into `internal/module/notification/transport/admin/task_*` or keep them in the same admin package with clear names:

```powershell
git mv .\internal\module\notificationtask\transport\admin\handler.go .\internal\module\notification\transport\admin\task_handler.go
git mv .\internal\module\notificationtask\transport\admin\handler_i18n_test.go .\internal\module\notification\transport\admin\task_handler_i18n_test.go
git mv .\internal\module\notificationtask\transport\admin\request.go .\internal\module\notification\transport\admin\task_request.go
git mv .\internal\module\notificationtask\transport\admin\route.go .\internal\module\notification\transport\admin\task_route.go
```

- [ ] Change moved task subpackage files from `package notificationtask` to `package task`.
- [ ] Change moved transport files to import/use `notificationtask "admin_back_go/internal/module/notification/task"`.
- [ ] Keep exported type/function names stable inside the `task` subpackage; do not rename task constants or payload structs.

## Task 3: Update imports and route registration

- [ ] Replace imports of `admin_back_go/internal/module/notificationtask` with `admin_back_go/internal/module/notification/task` and alias them as `notificationtask` where that minimizes churn.
- [ ] Replace imports of `admin_back_go/internal/module/notificationtask/transport/admin` with `admin_back_go/internal/module/notification/transport/admin` and call the task route register function. If existing notification admin route already has `RegisterRoutes`, name the task one `RegisterTaskRoutes`.
- [ ] Update `internal/jobs/noop.go`, `internal/bootstrap/worker.go`, `internal/module/crontask/registry.go`, and tests to reference `notificationtask.TypeDispatchDueV1`, `notificationtask.NewDispatchDueTask`, `notificationtask.JobService`, etc. from the new subpackage path.
- [ ] Do not rename task constants or queue payload JSON.

## Task 4: Verification

- [ ] Format:

```powershell
gofmt -w .\internal\module\notification .\internal\jobs .\internal\bootstrap .\internal\module\crontask .\internal\server .\internal\architecture
```

- [ ] Confirm old module/imports are gone:

```powershell
if (Test-Path .\internal\module\notificationtask) { throw 'internal/module/notificationtask still exists' }
rg -n 'admin_back_go/internal/module/notificationtask|package notificationtask' internal cmd
```

Expected: no matches.

- [ ] Run focused tests:

```powershell
go test ./internal/module/notification/... -count=1
go test ./internal/jobs ./internal/module/crontask ./internal/bootstrap ./internal/server -count=1
go test ./internal/architecture -count=1
go test ./internal/server -run TestAdminRouteSnapshot -count=1
```

- [ ] Run full backend suite:

```powershell
go test ./... -count=1
```

## Task 5: Commit

```powershell
git status --short
git add internal docs
git commit -m "refactor: fold notification tasks into notification module"
```

Final report must include commit SHA, changed paths, verification output summary, and unresolved risks.
