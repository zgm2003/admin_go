# Notification Read/List Go Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Do not create a worktree. Do not commit.

**Goal:** Migrate the current-user notification center read/list/read/delete basics from legacy PHP all-POST APIs to Go REST under `/api/admin/v1/notifications`.

**Architecture:** Keep the Gin modular monolith boundary: `route -> handler -> service -> repository -> model`. Current-user notification APIs use bearer-token identity, not RBAC button permission, and every repository mutation is scoped by `user_id`, `platform IN(current, all)`, and `is_del=2`. Frontend remains Vue 3 typed API client using existing Element Plus/AppTable/Search components.

**Tech Stack:** Go 1.21+, Gin, GORM, MySQL, project enum/dict/validate, Vue 3, TypeScript, Element Plus.

---

## Task 1: Backend enum/dict/validate foundation

**Files:**
- Create: `admin_back_go/internal/enum/notification.go`
- Modify: `admin_back_go/internal/dict/dict.go`
- Create: `admin_back_go/internal/validate/notification.go`
- Modify: `admin_back_go/internal/validate/register.go`
- Test: `admin_back_go/internal/dict/dict_test.go`
- Test: `admin_back_go/internal/validate/validate_test.go`

- [ ] Add notification type/level constants and `IsNotificationType`, `IsNotificationLevel` helpers.
- [ ] Add dict options: `NotificationTypeOptions`, `NotificationLevelOptions`, `NotificationReadStatusOptions`.
- [ ] Add validator tags: `notification_type`, `notification_level`.
- [ ] Add tests proving dict order and validators reject unsupported values.
- [ ] Run `go test ./internal/enum ./internal/dict ./internal/validate`.

## Task 2: Backend notification module with TDD

**Files:**
- Create: `admin_back_go/internal/module/notification/model.go`
- Create: `admin_back_go/internal/module/notification/dto.go`
- Create: `admin_back_go/internal/module/notification/request.go`
- Create: `admin_back_go/internal/module/notification/repository.go`
- Create: `admin_back_go/internal/module/notification/service.go`
- Create: `admin_back_go/internal/module/notification/service_test.go`

- [ ] Write failing service tests for init dict, list normalization, unread count ownership input, mark-read ID normalization, delete ID normalization, invalid enum rejection.
- [ ] Implement model/dto/request/repository/service to satisfy tests.
- [ ] Ensure repository filters `user_id`, `platform IN ?`, `is_del=2`; no handler DB access.
- [ ] Run `go test ./internal/module/notification`.

## Task 3: HTTP route/bootstrap integration

**Files:**
- Create: `admin_back_go/internal/module/notification/handler.go`
- Create: `admin_back_go/internal/module/notification/route.go`
- Modify: `admin_back_go/internal/server/router.go`
- Modify: `admin_back_go/internal/server/router_test.go`
- Modify: `admin_back_go/internal/bootstrap/app.go`
- Test: `admin_back_go/internal/bootstrap/route_meta_test.go`

- [ ] Add `HTTPService` interface and handler methods for init/list/unread-count/read/delete.
- [ ] Register routes under `/api/admin/v1/notifications`.
- [ ] Wire service in bootstrap and router dependencies.
- [ ] Add router tests proving GET list passes current user/platform from AuthIdentity and DELETE/PATCH routes exist.
- [ ] Add route meta test proving no RBAC button rule is added for current-user notification routes.
- [ ] Run `go test ./internal/module/notification ./internal/server ./internal/bootstrap`.

## Task 4: Frontend typed Go API and notification UI adaptation

**Files:**
- Modify: `admin_front_ts/src/api/system/notification.ts`
- Modify: `admin_front_ts/src/views/Main/notification/index.vue`
- Modify: `admin_front_ts/src/views/Main/home/composables/useHomeDashboard.ts`
- Modify: `admin_front_ts/src/components/NotificationRuntime/src/index.vue`

- [ ] Replace `legacyRequest` with `request` in notification API.
- [ ] Map list/init/unread-count to Go GET routes.
- [ ] Map single read/delete to `PATCH/DELETE /notifications/:id/...`; map batch/all to body `{ ids }`.
- [ ] Remove unnecessary `as unknown as NotificationInitResponse` in the page.
- [ ] Change notification WebSocket refresh/listener event from `notification` to `notification.created.v1` for migrated notification runtime/home snapshot.
- [ ] Run frontend typecheck and targeted eslint.

## Task 5: Contract/docs/smoke sync

**Files:**
- Modify: `docs/contracts/admin-api-v1.md`
- Modify: `docs/migration/current-status.md`
- Modify: `docs/testing/smoke-matrix.md`
- Modify: `admin_back_go/docs/architecture.md`
- Modify: `admin_back_go/scripts/full-admin-smoke.ps1`

- [ ] Document notification REST endpoints and auth policy.
- [ ] Update current-status only after backend/frontend verification.
- [ ] Add full smoke read-only probes for notification init/list/unread-count.
- [ ] Update architecture doc with notification boundary and no notification_task in this slice.
- [ ] Run `powershell -ExecutionPolicy Bypass -File .\scripts\check-contract.ps1`.
- [ ] Run `git diff --check -- . ':!runtime/**' ':!.tmp/**'`.

## Task 6: Final verification

**Files:**
- All touched files.

- [ ] Run backend targeted tests: `go test ./internal/module/notification ./internal/server ./internal/bootstrap`.
- [ ] Run backend full tests: `go test -p=1 ./...`.
- [ ] Run backend vet: `go vet -p=1 ./...`.
- [ ] Run frontend typecheck: `npx vue-tsc -b --pretty false`.
- [ ] Run targeted frontend eslint.
- [ ] If local API is running, run full smoke; otherwise report smoke not run because runtime is not owned by this turn.