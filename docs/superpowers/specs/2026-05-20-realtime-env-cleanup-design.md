# Realtime env 收口设计

日期：2026-05-20
状态：draft
范围：`admin_back_go` Realtime / WebSocket 运行时配置、Docker-first env 模板、`admin-api` + `admin-worker` fan-out 装配、相关契约文档和测试

## 目标

这次只做 **realtime env cleanup**，不重做 WebSocket 协议、不改前端连接方式、不引入 Redis Streams、不做 realtime ticket、不扩展 topic 权限系统。

要达到的结果：

1. Docker-first env 里 realtime 配置尽量短，只保留真实部署时可能需要改的开关和拓扑项。
2. Redis Pub/Sub channel、heartbeat interval、每连接 send buffer 这些实现默认值由代码内置。
3. 保持 `admin-api` WebSocket 可连接、`admin-worker` 可跨进程发布通知/AI 事件、`/ready` realtime check 行为不变。
4. 不把 realtime bootstrap 依赖 `system_settings`，避免 API/worker 启动前必须先依赖 DB 读取协议默认值。

## Linus 三问

1. 这是真问题吗？
   - 是。当前 Docker-first env 暴露 5 个 `REALTIME_*` 键，其中 channel、heartbeat、send buffer 是协议/实现默认值。普通部署用户很难判断该不该改，改错会造成 WebSocket 断连、跨进程 fan-out 失效或慢客户端缓存异常。
2. 有更简单的做法吗？
   - 有。保留 `REALTIME_ENABLED` 和 `REALTIME_PUBLISHER`；其他 realtime policy 使用代码默认值，不新增后台配置和表字段。
3. 会破坏已有前端、接口、登录和权限吗？
   - 不应该。WebSocket path、cookie token upgrade、Origin 白名单、envelope、ping/pong、`notification.created.v1`、AI conversation-scoped `ai.response.*.v1` 都不变；只改变默认值来源和 Docker-first env 暴露面。

## 当前事实

Docker-first env 当前暴露：

```env
REALTIME_ENABLED=true
REALTIME_PUBLISHER=redis
REALTIME_REDIS_CHANNEL=admin_go:realtime:publish
REALTIME_HEARTBEAT_INTERVAL=25s
REALTIME_SEND_BUFFER=16
```

这些键可以分成三类：

| env key | 当前含义 | 判断 | 目标 |
| --- | --- | --- | --- |
| `REALTIME_ENABLED` | 是否启用 WebSocket upgrade 和 realtime publisher | 部署级功能开关，排障/禁用 realtime 时需要可控 | 保留 env |
| `REALTIME_PUBLISHER` | publication 投递拓扑：`local` / `noop` / `redis` | 部署拓扑项；Docker-first 的 `admin-api + admin-worker` 两进程需要 `redis` fan-out | 保留 env |
| `REALTIME_REDIS_CHANNEL` | Redis Pub/Sub channel 名称 | 代码命名空间，当前产品不做多租户共享 Redis channel 配置 | 内置 `admin_go:realtime:publish` |
| `REALTIME_HEARTBEAT_INTERVAL` | server heartbeat interval | 协议默认值，前后端共同适配当前 25s | 内置 `25s` |
| `REALTIME_SEND_BUFFER` | 每连接 bounded send queue 大小 | slow-client drop policy，不能变成随意调大缓存 | 内置 `16` |

现有运行时依赖关系：

- `internal/config.Load()` 读取 `RealtimeConfig`。
- `bootstrap.Resources` 根据 `REALTIME_ENABLED` / `REALTIME_PUBLISHER` 判断 `/ready` 的 `realtime` 状态。
- `bootstrap.App` 用 `RealtimeConfig` 创建 WebSocket manager、local publisher、Redis publisher/subscriber 和 handler。
- `bootstrap.Worker` 在 `REALTIME_PUBLISHER=redis` 时使用 Redis publisher，向 `admin-api` 发布通知/AI 事件；`local` 在 worker 中会显式退化为 noop，避免假装跨进程投递。
- `module/realtime.Handler` 使用 heartbeat interval 和 send buffer 维护连接生命周期。

## 选型

### 方案 A：全部迁到 `system_settings`

不推荐。

原因：

- Realtime 是 `admin-api` 启动期协议能力，`admin-worker` 也要在业务任务里发布事件；启动期不能依赖 DB 系统设置来决定 WebSocket/publisher 装配。
- `heartbeat interval` 和 `send buffer` 是协议/资源保护默认值，不是运营后台应该随意调整的业务策略。
- `publisher` 是部署拓扑，不是业务配置；放到 `system_settings` 会导致 worker/API 启动时序和缓存失效问题。

### 方案 B：保留全部 `REALTIME_*` env

不采用。

原因：

- env 仍然长，违背 Docker-first “用户只改必要项”的方向。
- `REALTIME_REDIS_CHANNEL` 对普通部署用户没有产品意义，改错直接导致 API 订阅和 worker 发布不在同一 channel。
- `REALTIME_HEARTBEAT_INTERVAL` / `REALTIME_SEND_BUFFER` 是代码应守住的连接策略，暴露后只会鼓励误调。

### 方案 C：只保留部署级 realtime 项，其余内置（推荐）

内容：

Docker-first env 最终只保留：

```env
REALTIME_ENABLED=true
REALTIME_PUBLISHER=redis
```

代码内置：

```text
realtime_redis_channel = admin_go:realtime:publish
heartbeat_interval = 25s
send_buffer = 16
```

优点：

- env 一次减少 3 个键。
- 保留真正需要部署者理解和选择的能力：是否启用 realtime、单进程/丢弃/Redis fan-out 拓扑。
- Docker-first 默认仍适配 `admin-api + admin-worker` 两进程，用 `redis` 保证 worker 发出的通知/AI 事件能到 API WebSocket session。
- 不引入 DB/system_settings 启动依赖。

缺点：

- 如果某个高级部署确实多个独立环境共享同一个 Redis Pub/Sub channel 空间，不能再只靠 env 改 channel；应优先隔离 Redis 实例/命名空间，或后续单独设计统一 runtime namespace，而不是为这一项继续拉长 Docker-first env。

推荐采用。

## 推荐设计

### 1. Docker-first env 只保留两项

最终 Docker-first env 的 realtime 部分变为：

```env
REALTIME_ENABLED=true
REALTIME_PUBLISHER=redis
```

说明：

- `REALTIME_ENABLED=false` 仍表示 WebSocket upgrade 明确拒绝，返回 503；不是静默 fallback。
- `REALTIME_PUBLISHER=redis` 是 Docker-first 推荐值，因为 `admin-api` 持有 WebSocket sessions，`admin-worker` 只负责任务消费和事件发布。
- `REALTIME_PUBLISHER=local` 仍保留给单 API 进程、本机直接投递场景。
- `REALTIME_PUBLISHER=noop` 仍保留给测试/排障场景：WebSocket connect/ping/pong 可用，但业务 publication 显式丢弃。

### 2. realtime policy 代码内置

内置默认值：

```text
DefaultRedisChannel = "admin_go:realtime:publish"
DefaultHeartbeatInterval = 25s
DefaultSendBuffer = 16
```

注意：

- `admin-api` RedisSubscriber 和 `admin-worker` RedisPublisher 必须继续使用同一份代码默认 channel，不能散写字符串。
- send buffer 仍是 bounded queue；队列满时关闭慢客户端，不做无界缓存。
- heartbeat interval 继续写进 `realtime.connected.v1` 相关能力，不改变前端协议。

### 3. 不进 `system_settings`

本切片不新增系统设置 key。

理由：

- Realtime 装配发生在 API/worker bootstrap 阶段，不能依赖业务 DB 设置。
- `REALTIME_PUBLISHER` 是部署拓扑；`heartbeat/send_buffer/channel` 是实现默认值。
- `system_settings` 已经用于 captcha、verify code、upload token TTL 这类业务策略；不要把协议/基础设施默认值倒进去。

### 4. `/ready` 和 runtime 行为不变

不改：

- `REALTIME_ENABLED=false` 时，`realtime` readiness 为 `disabled`。
- `REALTIME_ENABLED=true` 且 `REALTIME_PUBLISHER` 为 `local` / `noop` / `redis` / 空时，`realtime` readiness 为 `up`。
- `REALTIME_ENABLED=true` 但 `REALTIME_PUBLISHER` 是未知值时，`realtime` readiness 为 `down`，WebSocket upgrade 显式关闭。
- `admin-api` 在 `redis` publisher 下启动 RedisSubscriber。
- `admin-worker` 只有在 `redis` publisher 下才真正跨进程发布；`local` 在 worker 里仍是 noop。

### 5. 文档同步收口

需要同步：

- `admin_back_go/deploy/docker-first/admin-go.env.example`
- 本地 ignored 的 `admin_back_go/deploy/docker-first/admin-go.env` 如果存在
- `docs/deployment/docker-first-backend.md`
- `docs/contracts/admin-realtime-v1.md`
- `docs/architecture/06-realtime-and-distributed-boundary.md`
- `admin_back_go/docs/architecture.md`
- `admin_back_go/README.md` 中 active runtime 的 `REALTIME_*` env 列表

文档口径改为：

```text
Docker-first env only keeps REALTIME_ENABLED and REALTIME_PUBLISHER for realtime runtime.
Realtime Redis channel, heartbeat interval, and send buffer are code-owned defaults.
```

历史 spec/plan 中记录旧讨论的 `REALTIME_REDIS_CHANNEL` / `REALTIME_HEARTBEAT_INTERVAL` / `REALTIME_SEND_BUFFER` 不强制回改；active docs 和 deploy 模板必须清干净。

## 迁移范围

### 需要改

后端仓 `admin_back_go`：

- `internal/config/config.go`
- `internal/config/config_test.go`
- `internal/bootstrap/realtime.go`
- `internal/bootstrap/worker.go`
- `internal/bootstrap/*_test.go` 中构造 `RealtimeConfig` 的用例
- `internal/module/realtime/*_test.go` 如直接依赖 send buffer / heartbeat 默认值
- `deploy/docker-first/admin-go.env.example`
- 本地 ignored 的 `deploy/docker-first/admin-go.env` 如果存在
- 后端架构文档中直接列出的 deprecated realtime policy env

根仓 `admin_go`：

- `docs/contracts/admin-realtime-v1.md`
- `docs/architecture/06-realtime-and-distributed-boundary.md`
- `docs/deployment/docker-first-backend.md`
- 如 smoke/current-status 有 active env 描述，按新口径同步

### 不需要改

- 不改前端 WebSocket URL/envelope/cookie auth 逻辑。
- 不改 `CORS_ALLOW_ORIGINS`；Origin 白名单仍是部署项。
- 不改 Redis 基础连接配置；继续复用 `REDIS_ADDR` / `REDIS_PASSWORD` / `REDIS_DB`。
- 不改通知任务、AI conversation、AI run monitor、队列或 scheduler 业务逻辑。
- 不新增 SQL/migration/system_settings row。

## 兼容与风险

### Docker-first 默认

Docker-first 保持：

```env
REALTIME_ENABLED=true
REALTIME_PUBLISHER=redis
```

这样 `admin-worker` 发出的 `notification.created.v1` 和 AI conversation event 可以经 Redis Pub/Sub 到 `admin-api`，再投递给浏览器 WebSocket。

### 本地开发

普通本地开发仍可不设置 `REALTIME_PUBLISHER`，代码默认 `local`。如果启动 worker 并希望跨进程通知到 API，则显式设为 `redis`。

### 共享 Redis

`REALTIME_REDIS_CHANNEL` 内置后，多个完全独立环境共享同一个 Redis Pub/Sub channel 空间时理论上可能互相收到 publication。Docker-first 推荐用独立 Redis/独立部署栈解决隔离问题；如果后续要支持多环境共享 Redis，应单独设计统一 namespace，而不是单独恢复一个 channel env。

## 测试与验证

实现时至少跑：

```powershell
cd E:\admin_go\admin_back_go
go test ./cmd/admin-api ./cmd/admin-worker ./internal/config ./internal/bootstrap ./internal/module/realtime ./internal/platform/realtime
```

Docker-first runtime 验证：

```powershell
cd E:\admin_go\admin_back_go\deploy\docker-first
docker compose up -d --build admin-api admin-worker
docker compose ps
curl.exe -fsS http://127.0.0.1:8080/health
curl.exe -fsS http://127.0.0.1:8080/ready
```

治理检查：

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

完成判定：

- `admin-go.env.example` 和本地 `admin-go.env` 不再出现：
  - `REALTIME_REDIS_CHANNEL`
  - `REALTIME_HEARTBEAT_INTERVAL`
  - `REALTIME_SEND_BUFFER`
- active docs 不再把这 3 个键描述为 Docker-first 必改 env。
- `REALTIME_ENABLED` / `REALTIME_PUBLISHER` 仍保留且行为不变。
- `/ready` 仍能报告 `realtime` 状态。

## 明确不做

- 不做 realtime ticket。
- 不做 Redis Streams/replay。
- 不做多租户 channel namespace。
- 不做 system settings 管理 WebSocket 参数。
- 不做前端 UI 配置入口。
- 不做跨域 WebSocket 新策略。
- 不改 `CORS_ALLOW_ORIGINS`。
