# Admin Realtime v1 Contract

状态：partially implemented。当前已实现最小 admin WebSocket：认证 upgrade、本机 connection manager、bounded send queue、read/write pump、heartbeat ping/pong、`realtime.connected.v1`、`realtime.ping.v1` / `realtime.pong.v1`、`realtime.subscribe.v1` topic 白名单骨架、local/no-op Publisher 边界、typed config 开关、断开清理。Redis fan-out、业务通知、AI streaming 仍是 planned。

## Protocol

```text
Transport: WebSocket
Admin path: GET /api/admin/v1/realtime/ws
Future app path: GET /api/app/v1/realtime/ws
SSE: intentionally not supported
```

配置开关：

```text
REALTIME_ENABLED=true|false
REALTIME_PUBLISHER=local|noop
REALTIME_HEARTBEAT_INTERVAL=25s
REALTIME_SEND_BUFFER=16
```

`REALTIME_ENABLED=false` 时：

```text
GET /api/admin/v1/realtime/ws -> HTTP 503
response body -> { "code": 503, "data": {}, "msg": "Realtime未启用" }
```

`REALTIME_PUBLISHER=noop` 不等于关闭 WebSocket；它只表示服务端业务 publication 显式丢弃。当前不支持 `REALTIME_PUBLISHER=redis`，Redis fan-out 仍是 planned。

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

如果浏览器环境无法稳定传自定义 header，再新增短期 realtime ticket：

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

状态：partially implemented。当前只允许订阅服务端可从身份直接推导出的基础 topic，不接业务通知，不接 Redis fan-out。

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

## AI streaming events

状态：planned。

AI 回复不走 SSE，统一走 WebSocket：

```json
{
  "type": "ai.response.start.v1",
  "request_id": "01HX...",
  "data": {
    "conversation_id": 10
  }
}
```

```json
{
  "type": "ai.response.delta.v1",
  "request_id": "01HX...",
  "data": {
    "text": "你好"
  }
}
```

```json
{
  "type": "ai.response.completed.v1",
  "request_id": "01HX...",
  "data": {
    "usage": {}
  }
}
```

```json
{
  "type": "ai.response.failed.v1",
  "request_id": "01HX...",
  "data": {
    "code": 100,
    "msg": "模型调用失败"
  }
}
```

取消：

```json
{
  "type": "ai.response.cancel.v1",
  "request_id": "01HX...",
  "data": {
    "response_id": "resp_xxx"
  }
}
```

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

当前 manager 是单进程内存连接表，只服务本节点连接生命周期。它不是分布式 fan-out 真相源；多节点广播后续接 Redis Pub/Sub 或 Redis Streams。

## Publish boundary

状态：partially implemented。

当前后端已有项目内发布边界：

```text
platform/realtime.Publisher
platform/realtime.Publication
platform/realtime.LocalPublisher
platform/realtime.NoopPublisher
```

当前装配由 `bootstrap.newRealtimeStack` 统一选择：

```text
REALTIME_ENABLED=false -> NoopPublisher + WebSocket 503
REALTIME_PUBLISHER=local -> LocalPublisher
REALTIME_PUBLISHER=noop -> NoopPublisher
unknown publisher -> NoopPublisher + WebSocket 503，并记录 server log
```

规则：

```text
业务模块以后只依赖 Publisher 接口，不直接拿 gorilla.Conn / Manager / Redis client
LocalPublisher 只投递到当前进程 Manager，适合本地单节点 smoke 和早期通知骨架
NoopPublisher 只能显式注入，用于 realtime 未启用场景；不能伪装成已推送成功的业务能力
Redis Pub/Sub / Redis Streams publisher 后续实现时必须保持同一个 Publication 合同
```

当前 Publication 只包含 `session_key + envelope`，不支持任意业务 topic fan-out；业务 topic fan-out 仍是 planned。

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
text/event-stream
unversioned event type
client-defined arbitrary topic or subscribing another user/session
long-running CPU work inside WebSocket handler
```
