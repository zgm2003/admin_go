# Notification Realtime Fan-out Design

状态：approved for implementation on 2026-05-05.

## Outcome

Build the first real realtime business loop:

```text
notification task publish/scheduler -> admin-worker notification:send-task:v1 -> notifications DB rows -> Redis Pub/Sub realtime publication -> admin-api local WebSocket manager -> Vue notification.created.v1 listeners
```

This is admin-only. It does not implement app WebSocket, Redis Streams replay, AI streaming, or arbitrary topic subscription.

## Linus check

1. 真问题：是。`admin-worker` owns queue/scheduler, while `admin-api` owns WebSocket connections. A local in-process publisher cannot cross that process boundary.
2. 更简单做法：Redis Pub/Sub is the smallest correct fan-out because Redis already exists for token/cache/queue. Redis Streams/outbox are not needed for this first volatile realtime hint.
3. 会破坏什么：REST notification DB truth must not depend on WebSocket delivery. If realtime publish fails, the task still succeeds after DB insert; frontend can still reload from REST.

## Scope

Implemented in this slice:

- Extend realtime `Publication` to target either a concrete `session_key` or all local sessions for `platform + user_id`.
- Keep `LocalPublisher` for same-process tests and future direct use.
- Add Redis Pub/Sub publisher/subscriber under `internal/platform/realtime`.
- `admin-worker` publishes notification events to Redis when `REALTIME_PUBLISHER=redis`.
- `admin-api` subscribes to the Redis channel and delivers events to its local WebSocket sessions.
- Notification realtime payload is explicit and versioned:

```json
{
  "type": "notification.created.v1",
  "request_id": "notification-task-7-1",
  "data": {
    "task_id": 7,
    "title": "...",
    "content": "...",
    "link": "/notification",
    "level": "urgent",
    "notification_type": "warning"
  }
}
```

Not implemented:

- No app endpoint fan-out.
- No Redis Streams replay/ack.
- No notification撤回.
- No AI/WebRTC/OpenAI realtime work.
- No arbitrary client topic names.

## Architecture

`Publisher` remains the only business-facing boundary:

```text
notificationtask.Service -> platform/realtime.Publisher
RedisPublisher -> Redis Pub/Sub channel
RedisSubscriber in admin-api -> LocalPublisher -> Manager.SendToUser
Manager -> bounded Session.Send queue -> gorilla/websocket wrapper
```

The notification task service does not import Gin, gorilla, Redis clients, or manager internals. It only emits a `Publication` after DB rows are inserted.

## Failure policy

- DB insert is source of truth.
- Realtime publish is best-effort.
- Offline users are not errors.
- Redis publish errors are logged but do not mark notification task failed.
- Invalid Redis publication payload is logged and dropped by subscriber.

## Config

```text
REALTIME_ENABLED=true
REALTIME_PUBLISHER=redis
REALTIME_REDIS_CHANNEL=admin_go:realtime:publish
```

`local` and `noop` stay valid explicit modes. `redis` is the correct mode when `admin-worker` and `admin-api` are separate processes.

## Verification

Backend:

```powershell
go test ./internal/platform/realtime ./internal/module/notificationtask ./internal/bootstrap
go test ./...
go vet ./...
go test -race ./internal/platform/realtime ./internal/module/realtime ./internal/module/notificationtask
git diff --check
```

Frontend if touched:

```powershell
npx vue-tsc -b --pretty false
npx eslint src/components/NotificationRuntime/src/index.vue src/views/Main/home/composables/useHomeDashboard.ts
```
