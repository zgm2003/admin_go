# Realtime Browser Auth + Go Refresh Base Fix Spec

状态：implemented in this slice after verification.

## Problem

浏览器控制台暴露了两条真实基础链路问题：

```text
WebSocket connection to ws://localhost:8080/api/admin/v1/realtime/ws failed:
HTTP Authentication failed; no valid credentials available

POST http://localhost:8787/api/admin/v1/auth/refresh net::ERR_FAILED 200 (OK)
blocked by CORS policy
```

## Root cause

### WebSocket

浏览器原生 `WebSocket` 不能带自定义 `Authorization` header。Go 后端已经支持 `/api/admin/v1/realtime/ws` 的路径限定 cookie token，但本地前端常跑在：

```text
http://127.0.0.1:5173
```

而 `.env.development` 写的是：

```text
VITE_WEB_SOCKET_URL=ws://localhost:8080/api/admin/v1/realtime/ws
```

cookie 是按 host 隔离的，`127.0.0.1` 下写入的 `access_token` 不会发给 `localhost`，所以 WebSocket upgrade 没有凭证。

### Refresh

Go API client 的 refresh baseURL 错接到了 legacy PHP：

```text
apiClient.refreshBaseURL = VITE_SOME_KEY = http://localhost:8787
```

触发续杯时前端调用了：

```text
http://localhost:8787/api/admin/v1/auth/refresh
```

这不是 Go 后端。浏览器报 CORS 只是症状，根因是新 Go API 的 refresh 调错后端。

## Decision

1. WebSocket URL 构造必须对 loopback host 做归一化：只要目标 host 和浏览器 host 都是 loopback，就把 WebSocket host 改成当前页面 host，保持 cookie 可发送。
2. Go API client 的 refresh 必须走 `VITE_GO_API_BASE_URL`。
3. legacy client 暂时仍走 legacy baseURL，不把新 Go token refresh 逻辑强行塞给未迁移 legacy 模块。
4. `/api/app/v1/realtime/ws` 是未来 app scope 的正确命名，但当前只实现 admin path；app path 不能直接复制 admin cookie fallback，因为平台绑定和鉴权策略不同。

## Non-goals

```text
不把 access_token 放 query string
不在 WebSocket 里手写 Authorization hack
不现在实现 app WebSocket
不实现 Redis fan-out
不重构整个 frontend http client
```

