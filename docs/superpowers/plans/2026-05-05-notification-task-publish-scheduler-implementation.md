# Notification Task Publish + Scheduler Dispatch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Do not create a worktree. Commit once per repo after verification.

**Goal:** Migrate notification task publishing to Go REST and wire the first real business scheduler/queue path for immediate and scheduled notification dispatch.

**Architecture:** Keep `admin-api` HTTP-only and `admin-worker` as the only queue consumer + scheduler host. `notificationtask` owns REST/service/repository/jobs; `internal/jobs` only registers handlers and schedule definitions. Scheduler enqueues `notification:dispatch-due:v1`; worker handlers perform DB claim/send/update with idempotent behavior.

**Tech Stack:** Go 1.21+, Gin, GORM, MySQL, Asynq wrapper, gocron/v2 wrapper, Vue 3, TypeScript, Element Plus.

---

## Task 1: Enum / dict / validate extension

**Files:**
- Modify: `admin_back_go/internal/enum/notification.go`
- Modify: `admin_back_go/internal/dict/dict.go`
- Modify: `admin_back_go/internal/validate/notification.go`
- Modify: `admin_back_go/internal/validate/register.go`
- Test: `admin_back_go/internal/dict/dict_test.go`
- Test: `admin_back_go/internal/validate/validate_test.go`

- [ ] Add notification target type constants and labels.
- [ ] Add notification task status constants and labels.
- [ ] Add `PlatformAll`, `IsNotificationTaskPlatform`, `NotificationTaskPlatforms` if not already available.
- [ ] Add dict options for target type, task status, and task platform with `all` first.
- [ ] Add validator tags `notification_target_type`, `notification_task_status`, `notification_task_platform`.
- [ ] Write/extend tests for dict order and validator rejection.
- [ ] Run `go test ./internal/dict ./internal/validate`.

## Task 2: Backend notificationtask service/repository TDD

**Files:**
- Create: `admin_back_go/internal/module/notificationtask/model.go`
- Create: `admin_back_go/internal/module/notificationtask/dto.go`
- Create: `admin_back_go/internal/module/notificationtask/request.go`
- Create: `admin_back_go/internal/module/notificationtask/repository.go`
- Create: `admin_back_go/internal/module/notificationtask/service.go`
- Create: `admin_back_go/internal/module/notificationtask/service_test.go`

- [ ] Write failing tests for `Init` dict shape and order.
- [ ] Write failing tests for list/status-count normalization.
- [ ] Write failing tests for create target validation: all/users/roles.
- [ ] Write failing tests proving immediate create enqueues `notification:send-task:v1`.
- [ ] Write failing tests proving scheduled create does not enqueue immediately.
- [ ] Write failing tests proving cancel only works through service for pending tasks.
- [ ] Implement model/dto/repository/service minimally.
- [ ] Keep repository business-free: SQL scopes, claim, insert, updates only.
- [ ] Run `go test ./internal/module/notificationtask`.

## Task 3: Queue jobs and scheduler registration

**Files:**
- Create: `admin_back_go/internal/module/notificationtask/jobs.go`
- Create: `admin_back_go/internal/module/notificationtask/jobs_test.go`
- Modify: `admin_back_go/internal/jobs/noop.go`
- Modify: `admin_back_go/internal/jobs/noop_test.go`
- Modify: `admin_back_go/internal/bootstrap/worker.go`
- Modify: `admin_back_go/internal/bootstrap/worker_test.go`

- [ ] Write failing test for task builders: `notification:dispatch-due:v1`, `notification:send-task:v1`.
- [ ] Write failing test for send-task handler decoding payload and calling service.
- [ ] Write failing test for dispatch-due handler claim + enqueue send tasks.
- [ ] Write failing test that `jobs.Register` wires both notification handlers.
- [ ] Write failing test that `RegisterSchedules` registers `notification-task-dispatch-due` without executing DB work at registration time.
- [ ] Implement module-owned jobs and thin registration in `internal/jobs`.
- [ ] Wire `notificationtask.NewService` into `bootstrap.NewWorker`.
- [ ] Run `go test ./internal/module/notificationtask ./internal/jobs ./internal/bootstrap`.

## Task 4: HTTP route/bootstrap integration

**Files:**
- Create: `admin_back_go/internal/module/notificationtask/handler.go`
- Create: `admin_back_go/internal/module/notificationtask/route.go`
- Modify: `admin_back_go/internal/server/router.go`
- Modify: `admin_back_go/internal/server/router_test.go`
- Modify: `admin_back_go/internal/bootstrap/app.go`
- Modify: `admin_back_go/internal/bootstrap/route_meta.go`
- Modify: `admin_back_go/internal/bootstrap/route_meta_test.go`

- [ ] Add `HTTPService` interface and handlers for init/status-count/list/create/cancel/delete.
- [ ] Register routes under `/api/admin/v1/notification-tasks`.
- [ ] Wire service in app bootstrap and router dependencies.
- [ ] Add route tests proving query/body mapping and current user id flows into create.
- [ ] Add permission route metadata for mutating notification-task routes.
- [ ] Add operation log metadata for create/cancel/delete.
- [ ] Run `go test ./internal/module/notificationtask ./internal/server ./internal/bootstrap`.

## Task 5: Frontend typed REST client and page cleanup

**Files:**
- Modify: `admin_front_ts/src/api/system/notificationTask.ts`
- Modify: `admin_front_ts/src/views/Main/system/notificationTask/index.vue`

- [ ] Replace `legacyRequest` with `request`.
- [ ] Map endpoints:
  - `GET /api/admin/v1/notification-tasks/init`
  - `GET /api/admin/v1/notification-tasks/status-count`
  - `GET /api/admin/v1/notification-tasks`
  - `POST /api/admin/v1/notification-tasks`
  - `PATCH /api/admin/v1/notification-tasks/:id/cancel`
  - `DELETE /api/admin/v1/notification-tasks/:id`
- [ ] Remove `RequestPayload` inheritance from touched notification-task DTOs.
- [ ] Use explicit union-like numeric types for type/level/target_type/status where practical.
- [ ] Replace promise `then/finally` submit/cancel flow with `async/await`.
- [ ] Remove empty catch in cancel flow.
- [ ] Keep existing UI/components; no big visual rewrite.
- [ ] Run `npx vue-tsc -b --pretty false`.
- [ ] Run targeted eslint for touched files.

## Task 6: Docs and smoke sync

**Files:**
- Modify: `docs/contracts/admin-api-v1.md`
- Modify: `docs/migration/current-status.md`
- Modify: `docs/testing/smoke-matrix.md`
- Modify: `admin_back_go/docs/architecture.md`
- Modify: `admin_back_go/scripts/full-admin-smoke.ps1`

- [ ] Document notification-task REST contract, auth policy, and queue/scheduler behavior.
- [ ] Update current-status only after code verification.
- [ ] Add full smoke read-only probes for notification-task init/status-count/list.
- [ ] Update architecture doc: first real business schedule exists, scheduler still enqueue-only.
- [ ] Run `powershell -ExecutionPolicy Bypass -File .\scripts\check-contract.ps1`.

## Task 7: Final verification and commits

**Files:**
- All touched files.

- [ ] Add a data migration for notification-task BUTTON permissions if live DB has only the PAGE permission.
- [ ] Migration must insert `system_notificationTask_add`, `system_notificationTask_cancel`, `system_notificationTask_del` under `/system/notificationTask`.
- [ ] Migration must grant those buttons only to roles that already own the notification-task PAGE.
- [ ] Migration must be idempotent and must not create a hidden super-admin bypass.
- [ ] Run backend targeted tests:
  `go test ./internal/module/notificationtask ./internal/jobs ./internal/server ./internal/bootstrap`.
- [ ] Run queue/scheduler baseline:
  `go test ./internal/platform/taskqueue ./internal/platform/scheduler ./internal/jobs ./internal/bootstrap`.
- [ ] Run backend full tests:
  `go test ./...`.
- [ ] Run backend vet:
  `go vet ./...`.
- [ ] Run frontend typecheck:
  `npx vue-tsc -b --pretty false`.
- [ ] Run targeted frontend eslint:
  `npx eslint src/api/system/notificationTask.ts src/views/Main/system/notificationTask/index.vue`.
- [ ] Run `git diff --check` in root/backend/frontend.
- [ ] If runtime ports are free, run full smoke; otherwise report not run with port evidence.
- [ ] Commit one module per repo:
  - backend: `feat(notificationtask): add Go publish scheduler path`
  - frontend: `feat(notificationtask): use Go REST APIs`
  - root docs: `docs(notificationtask): document publish scheduler migration`
