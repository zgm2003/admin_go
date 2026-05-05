# Notification Realtime Fan-out Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans for sequential implementation. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Connect notification task sending to admin WebSocket clients through the smallest correct cross-process Redis Pub/Sub fan-out.

**Architecture:** Keep `admin-worker` as the queue/scheduler owner and `admin-api` as the WebSocket owner. Business code publishes `platform/realtime.Publication`; Redis Pub/Sub bridges processes; local manager only delivers to sessions inside the API process.

**Tech Stack:** Go, Gin, gorilla/websocket wrapper, go-redis/v9, Asynq, Vue 3 TypeScript.

---

### Task 1: Realtime publication target and local delivery

**Files:**
- Modify: `admin_back_go/internal/platform/realtime/manager.go`
- Modify: `admin_back_go/internal/platform/realtime/publisher.go`
- Modify: `admin_back_go/internal/platform/realtime/publisher_test.go`
- Modify: `admin_back_go/internal/platform/realtime/session_test.go`

- [ ] Add tests for `Manager.SendToUser(platform, userID, envelope)` delivering to every matching local session and no others.
- [ ] Add tests for `LocalPublisher` accepting `Publication{Platform, UserID}`.
- [ ] Implement target validation: `session_key` or `platform + user_id` is required.
- [ ] Run `go test ./internal/platform/realtime`.

### Task 2: Redis Pub/Sub fan-out boundary

**Files:**
- Create: `admin_back_go/internal/platform/realtime/redis_pubsub.go`
- Create/Modify: `admin_back_go/internal/platform/realtime/redis_pubsub_test.go`
- Modify: `admin_back_go/internal/config/config.go`
- Modify: `admin_back_go/internal/bootstrap/realtime.go`
- Modify: `admin_back_go/internal/bootstrap/realtime_test.go`
- Modify: `admin_back_go/internal/bootstrap/resources.go`

- [ ] Add tests for publication JSON encode/decode preserving target and envelope.
- [ ] Add tests for subscriber message handling delivering to local publisher without a real Redis server.
- [ ] Add config constant `redis` and `REALTIME_REDIS_CHANNEL`.
- [ ] Implement `RedisPublisher` using existing `github.com/redis/go-redis/v9`.
- [ ] Implement `RedisSubscriber` lifecycle with context cancellation and shutdown.
- [ ] Wire `admin-api` stack: redis publisher + redis subscriber + local delivery.
- [ ] Update readiness to treat `redis` as supported.
- [ ] Run `go test ./internal/platform/realtime ./internal/bootstrap`.

### Task 3: Notification task realtime event emission

**Files:**
- Modify: `admin_back_go/internal/module/notificationtask/service.go`
- Modify: `admin_back_go/internal/module/notificationtask/service_test.go`
- Modify: `admin_back_go/internal/bootstrap/app.go`
- Modify: `admin_back_go/internal/bootstrap/worker.go`

- [ ] Add failing tests proving `SendTask` publishes `notification.created.v1` after inserting notifications.
- [ ] Add failing test proving publisher errors do not fail the task after DB insert.
- [ ] Add publisher/logger options to notification task service.
- [ ] Build explicit payload strings: `level=normal|urgent`, `notification_type=info|success|warning|error`.
- [ ] Publish only to admin platform for `task.platform=admin|all`; skip app until app WebSocket exists.
- [ ] Wire worker with Redis publisher when `REALTIME_PUBLISHER=redis`; do not fake local publisher in worker.
- [ ] Run `go test ./internal/module/notificationtask ./internal/bootstrap`.

### Task 4: Frontend contract tightening and docs

**Files:**
- Modify: `admin_front_ts/src/components/NotificationRuntime/src/index.vue` if typing is too loose.
- Modify: `docs/contracts/admin-realtime-v1.md`
- Modify: `docs/contracts/admin-api-v1.md`
- Modify: `docs/architecture/06-realtime-and-distributed-boundary.md`
- Modify: `docs/migration/current-status.md`
- Modify: `admin_back_go/.env.example`
- Modify: `admin_back_go/.env` if current local dev should exercise the real fan-out.

- [ ] Document `notification.created.v1` payload as string enum contract.
- [ ] Document Redis Pub/Sub fan-out as implemented baseline, not planned.
- [ ] Remove old statement that notification task realtime fan-out is not implemented.
- [ ] Keep frontend listener narrow; no `any`, no fallback fields.
- [ ] Run root/backend diff checks and targeted frontend type/lint if touched.

### Task 5: Verification and commits

- [ ] Run backend targeted tests.
- [ ] Run `go test ./...`.
- [ ] Run `go vet ./...`.
- [ ] Run race detector for realtime/notificationtask.
- [ ] Run frontend typecheck/lint if touched.
- [ ] Run `git diff --check` in each touched repo.
- [ ] Commit by repo/module; do not push.
