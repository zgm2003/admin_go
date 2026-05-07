# Frontend Realtime Go WebSocket Contract Cleanup Design

状态：partially implemented
日期：2026-05-05

## Linus 三问

```text
1. 真问题：前端 realtime 仍连旧 ws://127.0.0.1:7272，并调用 legacy /api/admin/WebSocket/bind；Go 后端已经有 /api/admin/v1/realtime/ws，前后端契约不一致。
2. 更简单方法：不引入新前端库，不写自定义 WebSocket 协议；继续用浏览器原生 WebSocket，后端继续用 gorilla/websocket 薄封装。只把前端连接、鉴权、envelope、测试和文档收齐。
3. 会破坏什么：不能影响登录、RBAC、现有 REST 请求；不能把 access token 放 query string；不能把 cookie 鉴权变成全局 API fallback；不能开始迁聊天/AI/通知业务。
```

## Goal

把当前 Vue 前端 realtime runtime 从旧 PHP WebSocket 切到 Go 后端：

```text
GET /api/admin/v1/realtime/ws
```

本切片只证明：

```text
login cookie/header state -> Go WebSocket upgrade -> realtime.connected.v1 -> optional identity subscribe -> ping/pong -> disconnect cleanup
```

## Open-source / official component decision

- 后端第一期已经选择 `github.com/gorilla/websocket`，本切片不换库。
- 前端使用浏览器原生 `WebSocket`，不引入 socket.io 或自造封装框架。
- Vue 侧继续保留当前 `useWebSocket` composable 单例模型，减少页面侵入。
- 不引入 SSE；`stream.ts` 只作为未迁 AI legacy helper 暂存，不允许新模块继续依赖它。

## Scope

### Included

- 后端 `AuthToken` 对 `GET /api/admin/v1/realtime/ws` 启用**路径限定 cookie token**，和 queue-monitor-ui 一样显式配置。
- Cookie fallback 只允许 GET/HEAD 指定 path prefix，默认 platform 固定为 `admin`。
- 前端 WebSocket URL 默认从 `VITE_GO_API_BASE_URL` 派生：
  - `http://localhost:8080` -> `ws://localhost:8080/api/admin/v1/realtime/ws`
  - `https://api.example.com` -> `wss://api.example.com/api/admin/v1/realtime/ws`
- `VITE_WEB_SOCKET_URL` 仍可显式覆盖，但 `.env.development` 必须指向 Go WS，而不是旧 `7272`。
- 移除前端 `/api/admin/WebSocket/bind` legacy 调用。
- 前端消息 envelope 对齐 Go contract：`type/request_id/data`。
- 前端处理这些基础事件：
  - `realtime.connected.v1`
  - `realtime.pong.v1`
  - `realtime.subscribed.v1`
  - `realtime.error.v1`
- 前端收到 connected 后可以根据服务端返回的 `user_id/platform` 自动订阅身份 topic：`user:<id>`、`platform:<platform>`。
- 更新 frontend unit tests、backend route auth tests、realtime contract/docs/current-status。

### Excluded

- 不做 Redis Pub/Sub / Streams fan-out。
- 不做 notification business event 发布。
- 不做 chat message migration。
- 不做 AI streaming。
- 不做 `POST /api/admin/v1/realtime/tickets`；短期 ticket 留给跨域 cookie 不稳定或网关隔离时的后续切片。
- 不删除 legacy AI polling/SSE helper，避免在非本切片破坏 AI legacy 页面；但新代码不得继续使用 SSE。

## Backend design

当前 `AuthToken` 已有 `CookieTokenPathConfig`，用于 queue-monitor-ui 这种浏览器无法加 Authorization header 的特殊入口。本切片复用它，而不是新增一套 token parser。

新增显式路径：

```text
/api/admin/v1/realtime/ws
```

规则：

```text
Authorization header 仍然优先。
没有 Authorization 时，只有 GET/HEAD 且 path 匹配 realtime ws 才读取 access_token cookie。
从 cookie 取 token 时 platform 使用 admin。
普通 JSON API 不启用 cookie fallback。
POST/DELETE 不启用 cookie fallback。
```

## Frontend design

组件边界保持简单：

```text
src/lib/realtime/message-bus.ts       # project envelope type + typed event bus
src/lib/realtime/websocket-client.ts  # singleton WebSocket runtime, URL resolve, reconnect, send envelope
src/hooks/useWebSocket.ts             # Vue composable, expose readonly-ish runtime state/actions
src/views/Layout/index.vue            # only mounts useWebSocket, no business logic
```

Frontend state:

```ts
interface WebSocketSnapshot {
  ws: WebSocket | null
  isConnected: boolean       // browser socket open
  isReady: boolean           // server realtime.connected.v1 received
  reconnectCount: number
}
```

Client send contract:

```ts
sendSharedWebSocket('realtime.ping.v1', {}, requestId)
sendSharedWebSocket('realtime.subscribe.v1', { topics }, requestId)
```

## Error handling

- Invalid `VITE_GO_API_BASE_URL` throws a clear frontend error before creating an invalid WebSocket URL.
- WebSocket parse error is logged and does not crash Layout.
- `realtime.error.v1` logs server `msg`/`code` and still flows through `message-bus` for future UI handling.
- Reconnect remains bounded by `maxReconnectAttempts` and active consumer count.

## Testing

Backend:

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/server ./internal/middleware ./internal/module/realtime ./internal/platform/realtime
```

Frontend:

```powershell
cd E:/admin_go/admin_front_ts
npx vitest run tests/shared/realtime/websocket-client.test.ts tests/shared/realtime/message-bus.test.ts
npx vue-tsc -b --pretty false
npx eslint src/lib/realtime/websocket-client.ts src/lib/realtime/message-bus.ts src/hooks/useWebSocket.ts src/views/Layout/index.vue
```

Full gates after this slice when runtime is available:

```powershell
cd E:/admin_go/admin_back_go
go test -p=1 ./...
go vet -p=1 ./...
powershell -ExecutionPolicy Bypass -File .\scripts\check-contract.ps1
```

## Next slice after this

完成本切片后，再进入第一个真实业务模块：`notification read/list basics`。不要直接跳 AI、聊天、支付或钱包写路径。
