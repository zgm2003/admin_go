# Realtime and Distributed Boundary

状态更新时间：2026-05-04

当前实现状态：

```text
implemented:
  github.com/gorilla/websocket thin wrapper
  GET /api/admin/v1/realtime/ws
  AuthToken protected upgrade
  local connection manager
  bounded send queue
  read pump / write pump
  WebSocket ping heartbeat + business realtime.ping.v1 -> realtime.pong.v1
  realtime.subscribe.v1 identity topic whitelist
  local/no-op/redis Publisher interface boundary
  Redis Pub/Sub fan-out for notification.created.v1
  typed REALTIME_* config and bootstrap Publisher selection
  explicit disabled mode: WebSocket upgrade returns 503
  disconnect cleanup
  basic smoke connect/ping/pong

planned:
  business topic permission checks
  AI streaming event source
```

## Decision

Realtime 基建采用 **WebSocket-only**。

```text
REST       # 状态变更、查询、管理 CRUD
WebSocket  # 通知、订阅、心跳、进度输出、AI token/audio/event streaming
Queue      # 慢任务、重试、异步副作用
Redis      # session/cache/queue broker/future fan-out
```

不引入 SSE：

```text
不新增 /sse 路由
不新增 text/event-stream contract
不把 AI streaming 设计成单向 HTTP 长连接
```

原因很简单：admin 后续需要通知、AI、多端状态、取消、心跳、订阅和权限 topic。WebSocket 是一个统一双向通道；SSE 会制造第二套实时协议，收益小，维护成本高。

OpenAI 官方 Realtime 文档也明确有 WebSocket 接入方式；服务端到服务端集成可以用 WebSocket 直连 Realtime API。浏览器/移动端直连 OpenAI 时官方更推荐 WebRTC，但我们自己的 admin 前端连接自己的 Go 后端，仍采用项目内 WebSocket 网关。

## Route namespace

```text
GET /api/admin/v1/realtime/ws  # admin WebSocket upgrade
GET /api/app/v1/realtime/ws    # future app WebSocket upgrade
```

这些不是 REST CRUD，但仍必须挂在 admin/app scope 下，方便网关、鉴权、分布式部署和后续拆 `cmd/admin-realtime`。

当前只实现 admin WebSocket。app WebSocket 是 planned：路径合理，但不能直接复制 admin 的 cookie fallback；app 要单独处理平台、设备、token 来源和 topic 权限。

## Process boundary

第一阶段：

```text
cmd/admin-api hosts REST + initial WebSocket upgrade
cmd/admin-worker owns queue + scheduler
```

未来满足任一条件再拆：

```text
WebSocket 连接数或 fd/memory 压力明显影响 REST
需要独立扩容 realtime
需要独立发布 realtime
需要单独限流或隔离 AI streaming
```

拆分目标：

```text
cmd/admin-realtime hosts WebSocket only
cmd/admin-api remains REST only
cmd/admin-worker remains queue/scheduler only
```

## Connection contract

初始连接必须完成：

```text
authenticate
bind user_id/session_id/platform/device_id
start heartbeat
register connection with bounded send queue
close cleanly on auth expiry or shutdown
```

认证策略优先：

```text
Authorization: Bearer <access_token>
platform: admin
device-id: <device>
```

如果浏览器 WebSocket header 限制导致 Authorization 不稳定，再定义一次性 realtime ticket；不要把长期 token 放 query string。

当前浏览器实现先走路径限定 cookie token。因为本地 `localhost` 和 `127.0.0.1` cookie 不互通，前端 realtime client 会对 loopback host 做归一化：当前页面是 `127.0.0.1` 就把 `ws://localhost:8080/...` 改成 `ws://127.0.0.1:8080/...`；当前页面是 `localhost` 就保持/改成 `localhost`。这不是生产网关策略，只是本地 loopback cookie 对齐。

Go API 的 token refresh 也必须走 Go base URL：

```text
VITE_GO_API_BASE_URL + /api/admin/v1/auth/refresh
```

不能走 legacy `VITE_SOME_KEY`。如果 refresh 打到旧 PHP，浏览器 CORS 报错只是症状，根因是前端新 API client 的 refresh baseURL 错了。

## Message envelope

所有事件必须版本化：

```json
{
  "type": "notification.created.v1",
  "request_id": "01HX...",
  "data": {}
}
```

AI streaming 也走同一套 envelope：

```json
{ "type": "ai.response.delta.v1", "request_id": "01HX...", "data": { "text": "..." } }
{ "type": "ai.response.completed.v1", "request_id": "01HX...", "data": {} }
{ "type": "ai.response.failed.v1", "request_id": "01HX...", "data": { "code": 100, "msg": "..." } }
```

取消也走 WebSocket 或 REST 显式命令，不能靠断线当业务取消语义：

```json
{ "type": "ai.response.cancel.v1", "request_id": "01HX...", "data": { "response_id": "..." } }
```

## Topic rules

禁止客户端提交任意 topic 名称。

允许 topic 只能由服务端根据身份和权限构造：

```text
user:{user_id}
role:{role_id}
platform:{platform}
permission:{permission_code}
```

订阅必须走 permission check；前端不能靠隐藏按钮保护 topic。

当前 topic 骨架已经实现最小白名单：

```text
user:{current_user_id}
session:{current_session_id}
platform:{current_platform}
```

这只是连接基础能力；当前通知任务的 `notification.created.v1` 由服务端按 `platform + user_id` 定向推送，不依赖客户端自造 topic。其他业务 topic 例如 `permission:{permission_code}` 后续必须接 RBAC permission service，再接 fan-out。

## Current implementation detail

第一期已经落地最小连接生命周期：

```text
platform/realtime.Conn      # gorilla.Conn thin wrapper，不暴露给业务 service
platform/realtime.Session   # bounded send queue + read/write pump + heartbeat
platform/realtime.Manager   # 本机 session registry，key = platform:user_id:session_id
platform/realtime.Publisher # 发布接口，local/no-op/redis 保持同一合同
module/realtime.Handler     # Gin upgrade 边界，注册 session，调用 service 处理 envelope
module/realtime.Service     # connected/ping/pong/subscribe/error 业务 envelope，不依赖 Gin/gorilla
```

当前 send queue buffer 固定为 16。队列满就关闭连接，这是故意的 slow-client drop policy，不做无界缓存。

现在 send queue buffer 已经配置化：

```text
REALTIME_SEND_BUFFER=16
```

默认仍是 16；改大不是“越大越好”，只是给不同部署规模调节慢客户端容忍度。真正慢客户端仍然要丢连接，不能无界缓存。

## Backpressure and lifecycle

每个连接必须有：

```text
bounded send queue
read pump and write pump 生命周期
context cancellation
heartbeat ping/pong
slow-client drop policy
disconnect cleanup
shutdown drain timeout
```

禁止：

```text
每条消息开无界 goroutine
无界 channel
handler 里跑 CPU-heavy AI 或报表任务
把连接状态当成权限真相源
```

## Current publish boundary

当前发布边界已接通知任务最小闭环：

```text
Publisher.Publish(ctx, Publication)
Publication.SessionKey or Platform+UserID
Publication.Envelope
LocalPublisher -> Manager.Send / Manager.SendToUser
RedisPublisher -> Redis Pub/Sub -> RedisSubscriber -> LocalPublisher
NoopPublisher -> explicit disabled implementation
```

当前 bootstrap 装配规则：

```text
REALTIME_ENABLED=false
  -> WebSocket upgrade 明确拒绝，HTTP 503
  -> Publisher = NoopPublisher

REALTIME_ENABLED=true
REALTIME_PUBLISHER=local
  -> WebSocket upgrade 可用
  -> Publisher = LocalPublisher -> 当前进程 Manager

REALTIME_ENABLED=true
REALTIME_PUBLISHER=redis
  -> WebSocket upgrade 可用
  -> admin-api 启动 RedisSubscriber
  -> admin-worker 使用 RedisPublisher 跨进程发布 notification.created.v1

REALTIME_ENABLED=true
REALTIME_PUBLISHER=noop
  -> WebSocket connect/ping/pong 可用
  -> 业务 publication 显式丢弃，用于未接推送或测试边界
```

当前支持：

```text
local
noop
redis
```

`redis` 是 Redis Pub/Sub fan-out，不是 Redis Streams。未知 `REALTIME_PUBLISHER` 会让 WebSocket upgrade 显式关闭并记录 server log，而不是偷偷退回 local。

好品味点在这里：业务模块以后不应该知道当前是本机连接、Redis Pub/Sub 还是 Redis Streams。它只发 `Publication`。分布式实现替换 Publisher，不反向污染业务 module。

禁止：

```text
业务 service 直接 import gorilla/websocket
业务 service 直接操作 Manager.sessions
业务 service 直接 redis.Publish realtime channel
没有订阅权限检查就广播业务 topic
```

## Distributed fan-out

第一阶段可以本机 connection manager，但 public contract 不能假设单机。

当前多进程 fan-out：

```text
Redis Pub/Sub      # notification.created.v1 简单广播，admin-worker -> admin-api
Redis Streams      # planned，仅在需要消费确认/重放时
Queue task         # 慢副作用，不做实时 fan-out
```

WebSocket sticky session 只能是运维优化，不是正确性依赖。

## Library selection policy

实现前必须做短评审：

```text
维护活跃度
Gin 集成方式
context/cancel 支持
ping/pong 支持
compression 支持
测试便利性
是否强迫全局状态
```

候选至少比较：

```text
github.com/gorilla/websocket
nhooyr.io/websocket
```

Gin 官方文档的现实情况：

```text
Gin 自身不内置 WebSocket 实现。
Gin handler 暴露 http.ResponseWriter + *http.Request，所以可以用成熟 WebSocket 库 upgrade。
Gin 官方 WebSocket 文档示例使用 github.com/gorilla/websocket。
```

当前候选修正：

| Candidate | Status | Pros | Risk / Notes |
| --- | --- | --- | --- |
| `github.com/gorilla/websocket` | strong default | Gin 官方文档示例；成熟、广泛使用、API 稳定；完整测试实现 | 单连接并发写需要项目侧用 bounded send channel 串行化 |
| `github.com/coder/websocket` | modern candidate | `nhooyr.io/websocket` 后续维护者；context-first；支持并发写、ping/pong、compression；零依赖 | Gin 官方文档不是它；团队熟悉度可能低于 gorilla |
| `nhooyr.io/websocket` | do not choose directly | 曾经优秀 | pkg.go.dev 标记由 `github.com/coder/websocket` 继续维护，直接用旧包没必要 |

当前推荐：

```text
第一期采用 github.com/gorilla/websocket。
原因：Gin 官方文档直接示例，团队/AI 熟悉度最高，足够支撑 admin realtime foundation。
项目只封装 Upgrade/Connection/Hub/Envelope/Heartbeat/Backpressure，不手写 RFC6455 协议。
```

禁止：

```text
从 TCP/net.Conn 自己实现 WebSocket handshake/frame/mask/ping/pong
复制网上 chat demo 当生产架构
把 gorilla.Conn 暴露到业务 service
多个 goroutine 直接并发 WriteMessage
```

## Test plan

第一条端到端路径只做：

```text
authenticated connect
server sends connected event
client sends ping
server replies pong
client disconnect
server cleanup
```

然后再扩：

```text
unauthorized connect rejection
subscribe authorized topic
subscribe unauthorized topic rejection
slow-client backpressure
auth expiry close
multi-node fan-out simulation
AI stream delta/completed/failed/cancel
```

race gate：

```powershell
go test -race ./internal/platform/realtime ./internal/module/realtime ./internal/module/ai
```

如果 Windows 缺 gcc，必须报告 `cgo: C compiler "gcc" not found`，不能声称 race 通过。
