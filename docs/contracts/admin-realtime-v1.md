# Admin Realtime v1 Contract

状态：admin WebSocket、notification fan-out、AI conversation events 已实现；app WebSocket、ticket auth、任意业务 topic 权限仍是 planned/partial。当前已实现 admin WebSocket 认证 upgrade、本机 connection manager、bounded send queue、read/write pump、heartbeat ping/pong、`realtime.connected.v1`、`realtime.ping.v1` / `realtime.pong.v1`、`realtime.subscribe.v1` topic 白名单骨架、local/no-op/redis Publisher 边界、typed config 开关、断开清理。Vue 前端已从旧 WebSocket 切到 Go WebSocket baseline：URL 指向 `/api/admin/v1/realtime/ws`，移除 `/api/admin/WebSocket/bind`，按 versioned envelope 收发。Redis Pub/Sub fan-out、`notification.created.v1` 通知任务推送、以及 AI 对话 MVP 的 conversation-scoped `ai.response.start/delta/completed/failed.v1` envelope 已实现；真实 LLM provider E2E 仍是可选、凭证门控能力。

## Protocol

```text
Transport: WebSocket
Admin path: GET /api/admin/v1/realtime/ws
Future app path: GET /api/app/v1/realtime/ws
SSE: intentionally not supported
```

`/api/app/v1/realtime/ws` 是命名空间契约预留，不代表当前已经实现 app WebSocket。app 端后续必须单独定义平台绑定、token 来源、topic 白名单和权限规则，不能直接复用 admin cookie 策略。

配置开关：

```text
REALTIME_ENABLED=true|false
REALTIME_PUBLISHER=local|noop|redis
```

代码内置 realtime policy：

```text
Redis Pub/Sub channel: admin_go:realtime:publish
Heartbeat interval: 25s
Send buffer per connection: 16
```

这些值不是 Docker-first env，也不进 system_settings。`REALTIME_PUBLISHER=redis` 时，`admin-api` 和 `admin-worker` 使用同一份代码默认 channel。

`REALTIME_ENABLED=false` 时：

```text
GET /api/admin/v1/realtime/ws -> HTTP 503
response body -> { "code": 503, "data": {}, "msg": "Realtime未启用" }
```

`REALTIME_PUBLISHER=noop` 不等于关闭 WebSocket；它只表示服务端业务 publication 显式丢弃。`REALTIME_PUBLISHER=redis` 表示业务 publication 先发 Redis Pub/Sub，再由 `admin-api` 订阅并投递到本进程 WebSocket sessions。

Implementation library：

```text
第一期后端使用 github.com/gorilla/websocket。
Gin 不内置 WebSocket；Gin handler 只负责 HTTP upgrade 入口。
项目不手写 WebSocket 协议，只做项目级 envelope、auth、local session manager、topic、heartbeat、backpressure 封装。
```

## Authentication

优先使用：

```text
Authorization: Bearer <access_token>
platform: admin
device-id: <device-id>
```

浏览器原生 WebSocket 不能稳定附加自定义 `Authorization` header；当前 Vue runtime 使用**路径限定 cookie token**完成 upgrade 认证：

```text
GET /api/admin/v1/realtime/ws
Cookie: access_token=<access_token>
```

本地开发有一个实际坑：cookie 按 host 隔离。前端如果跑在 `http://127.0.0.1:5173`，WebSocket 却连 `ws://localhost:8080/...`，浏览器不会把 `127.0.0.1` 下的 `access_token` cookie 发给 `localhost`。因此前端 realtime client 会把 loopback 目标 host 归一化到当前页面 host：

```text
http://127.0.0.1:5173 + ws://localhost:8080/api/admin/v1/realtime/ws
-> ws://127.0.0.1:8080/api/admin/v1/realtime/ws
```

非 loopback 生产域名不做这种改写。

WebSocket upgrade 不走普通 CORS 预检；后端 gorilla/websocket `CheckOrigin` 使用同一份 `CORS_ALLOW_ORIGINS` 显式白名单，并额外允许非浏览器空 Origin 和同 host upgrade。开发时如果前端源是 `http://127.0.0.1:5173`，该 origin 必须出现在 `CORS_ALLOW_ORIGINS`。

规则：

```text
cookie token 只在 /api/admin/v1/realtime/ws 这类显式配置的 GET/HEAD path 生效。
普通 JSON API 不允许 cookie token fallback。
mutating request 不允许 cookie token fallback。
从 cookie 取 token 时 platform 固定为 admin，用于 session policy 校验。
```

如果后续跨域、网关隔离或多端部署导致 cookie WebSocket 不稳定，再新增短期 realtime ticket：

```text
POST /api/admin/v1/realtime/tickets
GET  /api/admin/v1/realtime/ws?ticket=<one_time_ticket>
```

ticket 必须短 TTL、一次性、绑定 user/session/platform/device，不得复用 access token query string。

## Envelope

所有 client/server message 都使用统一 JSON envelope：

```ts
interface RealtimeEnvelope<T = unknown> {
  type: string
  request_id?: string
  data: T
}
```

规则：

```text
type 必须版本化，例如 notification.created.v1。
request_id 用于关联一次订阅、AI 回复、取消或业务请求。
data 必须是对象；错误也放在 data 内，不发裸字符串。
```

## Core events

### Server: connected

状态：implemented。

```json
{
  "type": "realtime.connected.v1",
  "request_id": "01HX...",
  "data": {
    "user_id": 1,
    "platform": "admin",
    "heartbeat_interval_ms": 25000
  }
}
```

### Client: ping

状态：implemented。

```json
{
  "type": "realtime.ping.v1",
  "request_id": "01HX...",
  "data": {}
}
```

### Server: pong

状态：implemented。

```json
{
  "type": "realtime.pong.v1",
  "request_id": "01HX...",
  "data": {
    "server_time": "2026-05-04T12:00:00+08:00"
  }
}
```

### Client: subscribe

状态：partially implemented。当前只允许订阅服务端可从身份直接推导出的基础 topic。通知任务推送不依赖客户端自定义 topic；服务端按 `platform + user_id` 定向投递。

```json
{
  "type": "realtime.subscribe.v1",
  "request_id": "01HX...",
  "data": {
    "topics": ["user:1"]
  }
}
```

Topic 由服务端校验，客户端不能自由订阅任意 topic。

当前允许的基础 topic：

```text
user:{current_user_id}
session:{current_session_id}
platform:{current_platform}
```

订阅成功：

```json
{
  "type": "realtime.subscribed.v1",
  "request_id": "01HX...",
  "data": {
    "topics": ["user:1"]
  }
}
```

订阅其他用户、其他 session、任意自造 topic，返回 `realtime.error.v1`，`data.code=403`。

### Server: error

```json
{
  "type": "realtime.error.v1",
  "request_id": "01HX...",
  "data": {
    "code": 403,
    "msg": "无订阅权限"
  }
}
```


## Notification events

### Server: notification.created.v1

状态：implemented for admin notification task dispatch.

来源：`admin-worker` 处理 `notification:send-task:v1`，成功批量写入 `notifications` 后，best-effort 发布 Redis Pub/Sub realtime publication。`admin-api` 订阅同一个 channel 后按 `platform=admin + user_id` 投递给当前在线 session。

前端运行时规则：收到 `notification.created.v1` 后必须展示通知并刷新相关通知快照；`data.level` 只决定视觉优先级/原生通知策略，不能把普通通知直接过滤掉。

```json
{
  "type": "notification.created.v1",
  "request_id": "notification-task-7-1",
  "data": {
    "task_id": 7,
    "title": "系统通知",
    "content": "内容",
    "link": "/notification",
    "level": "urgent",
    "notification_type": "warning"
  }
}
```

Payload：

```ts
interface NotificationCreatedPayload {
  task_id: number
  title: string
  content: string
  link: string
  level: 'normal' | 'urgent'
  notification_type: 'info' | 'success' | 'warning' | 'error'
}
```

规则：

```text
DB notifications row 是真相，WebSocket 只是实时提示。
WebSocket/Redis 发布失败不回滚通知写库，也不把 notification_task 标失败。
task.platform=all/admin 时投递 admin WebSocket；task.platform=app 暂不投递，因为 app WebSocket 未实现。
前端收到事件后可以刷新 REST 通知列表；urgent 级别额外弹出通知。
```

## Admin chat events

状态：removed from current admin scope on 2026-05-07 by product decision.

The active realtime contract no longer defines admin chat message/read/contact/group events because the admin chat module, REST routes, frontend page/store, menu permission, and `chat_*` tables are removed.

AI response events are a separate AI runtime area below and must not reuse the removed admin chat contract.

## AI response events

状态：implemented conversation-scoped WebSocket MVP on 2026-05-09。

AI 回复不走 SSE、EventSource、streamable HTTP，也不再用 `/ai-chat/runs/:run_id/events` 做浏览器 catch-up。当前对话页只依赖共享 admin WebSocket：

```text
Transport: GET /api/admin/v1/realtime/ws
Events: ai.response.start.v1 / ai.response.delta.v1 / ai.response.completed.v1 / ai.response.failed.v1
Scope key: conversation_id + request_id
```

Start：

```json
{
  "type": "ai.response.start.v1",
  "request_id": "01HX...",
  "data": {
    "conversation_id": 10,
    "request_id": "client-request-id",
    "user_message_id": 101,
    "agent_id": 3
  }
}
```

Delta：

```json
{
  "type": "ai.response.delta.v1",
  "request_id": "01HX...",
  "data": {
    "conversation_id": 10,
    "request_id": "client-request-id",
    "delta": "你好"
  }
}
```

Completed：

```json
{
  "type": "ai.response.completed.v1",
  "request_id": "01HX...",
  "data": {
    "conversation_id": 10,
    "request_id": "client-request-id",
    "assistant_message_id": 102
  }
}
```

Failed：

```json
{
  "type": "ai.response.failed.v1",
  "request_id": "01HX...",
  "data": {
    "conversation_id": 10,
    "request_id": "client-request-id",
    "msg": "模型调用失败"
  }
}
```

Rules:

- payload must not contain `run_id`; token/cost/latency belongs to the later run-monitor slice
- frontend caches active chat state by `conversation_id`, not by agent or run id
- switching conversations must not cancel a pending reply; websocket deltas keep appending to the cached conversation session
- `ai.response.cancel.v1` is not part of this MVP
- current Go runtime must call `internal/infra/ai.Engine`; production must fail explicitly when no enabled provider/agent exists

## Implemented lifecycle

状态：partially implemented。

```text
handler upgrade 后创建 local Session
Session 使用 bounded send queue，当前 buffer=16
Session 拆成 read pump / write pump，所有写出经 send queue 串行化
subscribe 只允许 user/session/platform 三类身份基础 topic
server heartbeat 使用 WebSocket ping control frame
client `realtime.ping.v1` 仍回复业务层 `realtime.pong.v1`
同一 platform:user_id:session_id 新连接会替换旧本机连接
send queue 满时判定 slow client，关闭连接
```

当前 manager 是单进程内存连接表，只服务本节点连接生命周期。跨进程通知任务推送通过 Redis Pub/Sub 进入各 `admin-api` 节点，再落到本机 manager；需要重放/确认时才考虑 Redis Streams。

## Publish boundary

状态：partially implemented。

当前后端已有项目内发布边界和 Redis Pub/Sub fan-out：

```text
infra/realtime.Publisher
infra/realtime.Publication
infra/realtime.LocalPublisher
infra/realtime.NoopPublisher
infra/realtime.RedisPublisher
infra/realtime.RedisSubscriber
```

当前装配由 `bootstrap.newRealtimeStack` 统一选择：

```text
REALTIME_ENABLED=false -> NoopPublisher + WebSocket 503
REALTIME_PUBLISHER=local -> LocalPublisher
REALTIME_PUBLISHER=noop -> NoopPublisher
REALTIME_PUBLISHER=redis -> RedisPublisher + RedisSubscriber -> LocalPublisher
unknown publisher -> NoopPublisher + WebSocket 503，并记录 server log
```

规则：

```text
业务模块以后只依赖 Publisher 接口，不直接拿 gorilla.Conn / Manager / Redis client
LocalPublisher 只投递到当前进程 Manager，适合本地单节点 smoke 和单元测试
NoopPublisher 只能显式注入，用于 realtime 未启用场景；不能伪装成已推送成功的业务能力
RedisPublisher 是 admin-worker 到 admin-api 的最小正确跨进程 fan-out；Redis Streams 仍只在需要重放/ack 时再做
```

当前 Publication 支持 `session_key + envelope` 或 `platform + user_id + envelope`。它不支持任意客户端 topic fan-out；业务 topic 权限仍是 planned。

## Close policy

```text
unauthenticated: reject before upgrade or close immediately with realtime.error.v1
auth expired: send realtime.error.v1 then close
slow client: drop connection after bounded queue overflows
server shutdown: stop accepting upgrades, send close notice, drain within timeout
```

## Not supported

```text
GET /api/admin/v1/realtime/sse
server-sent stream MIME
access token query string, such as /realtime/ws?access_token=...
unversioned event type
client-defined arbitrary topic or subscribing another user/session
long-running CPU work inside WebSocket handler
```
