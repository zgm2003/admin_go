# Distributed Readiness

状态：architecture baseline。当前是 Gin modular monolith + 多进程部署，不是微服务。

## 当前正确架构

```text
admin-api      多副本 REST/WebSocket edge
admin-worker   多副本异步处理
MySQL          source of truth
Redis          token/session/cache/captcha/queue/realtime fan-out
Vue frontend   static assets
```

这已经是“分布式友好”的单体，不需要现在拆微服务。

## 不能依赖进程内存的东西

```text
登录 session / token
captcha challenge
verify code
RBAC 权限真相
button grant cache 的正确性
queue task state
operation log
业务状态
```

允许进程内存：

```text
当前 WebSocket 本机连接表
短生命周期 handler 局部变量
只影响性能、不影响正确性的本地对象
```

## Redis 当前职责

```text
REDIS_DB        普通缓存、captcha、verify code、RBAC button cache
TOKEN_REDIS_DB  token/session
QUEUE_REDIS_DB  Asynq queue broker、asynqmon inspector
Redis Pub/Sub   realtime fan-out when REALTIME_PUBLISHER=redis
```

未来职责：

```text
scheduler 多副本锁，只有真的多 worker cron 需要时启用
Redis Streams 只有在需要重放/ack 时再做
```

## Realtime 分布式边界

当前：

```text
infra/realtime.Manager 只保存本进程连接
REALTIME_PUBLISHER 支持 local/noop/redis
Docker-first production default: REALTIME_PUBLISHER=redis
```

未来：

```text
Redis Streams / ack / replay 只有在需要离线补偿或可重放消息时再做
```

禁止：

```text
业务 service 直接 redis.Publish
业务 service 直接操作 Manager.sessions
把 sticky session 当正确性依赖
用 query string 长期 token 解决 WebSocket 鉴权
```

## Queue 分布式边界

Asynq 是 Redis-backed at-least-once queue。多个 `admin-worker` 可以同时消费。

必须遵守：

```text
handler 幂等
任务 type 版本化：module:action:v1
慢任务进入 low lane 或独立 worker
scheduler 只投递任务，不直接执行业务
需要 DB + queue 强一致时再加 outbox
```

## 什么时候拆服务

只在真问题出现时拆：

```text
WebSocket 连接数/fd/内存影响 REST
AI streaming 需要独立限流和发布节奏
low/AI worker CPU 压垮普通 worker
某个业务模块有独立伸缩/发布/权限边界
团队已经能维护跨服务契约和观测
```

不是拆服务的理由：

```text
“Go 很强所以要微服务”
“作品看起来高级”
“以后可能会大”
```

## Readiness gate

`/ready` 现在必须能暴露：

```text
database
redis
token_redis
queue_redis
realtime
```

这让部署系统能区分：

```text
进程没死但 MySQL 挂了
Redis 普通 DB 可用但 queue DB 不可用
queue 开了但 REDIS_ADDR 没配
realtime publisher 配置不可用或 Redis fan-out 依赖不可达
```

这不是过度设计，是阻止生产环境“看起来启动了，实际关键依赖坏了”的最低成本检查。
