# Queue env 收口设计

日期：2026-05-20
状态：draft
范围：`admin_back_go` 队列运行时配置、Docker-first env 模板、Asynq client/server/monitor、worker 启动契约、相关文档和测试

## 目标

这次只做 **queue env cleanup**，不重做队列系统、不改任务类型、不改队列监控 UI、不引入 outbox 或新的调度平台。

要达到的结果：

1. Docker-first env 里队列配置尽量短，只保留真实部署时可能需要改的基础设施和容量项。
2. 队列名称、lane 权重、默认 retry/timeout、停机等待时间等运行策略由代码内置。
3. 保持 `admin-api` 可 enqueue、`admin-worker` 可 consume、asynqmon 可 inspect 的现有能力。
4. 不把 queue bootstrap 依赖 `system_settings`，避免 worker 启动前必须先依赖 DB 配置。

## Linus 三问

1. 这是真问题吗？
   - 是。当前 Docker-first env 暴露 10 个 `QUEUE_*` 键，大部分是 Asynq 内部策略或产品默认策略。普通部署用户看到这些值，既难判断该不该改，改错还会造成 worker 吞吐、重试和队列 lane 行为异常。
2. 有更简单的做法吗？
   - 有。保留 `QUEUE_ENABLED`、`QUEUE_REDIS_DB`、`QUEUE_CONCURRENCY`；其他 queue policy 使用代码默认值，不新增后台配置和表字段。
3. 会破坏已有前端、接口、登录和权限吗？
   - 不应该。任务入队、worker 消费、队列监控、`/ready` 的 `queue_redis` check 都保持现有契约；只改变默认值来源和 Docker-first env 暴露面。

## 当前事实

Docker-first env 当前暴露：

```env
QUEUE_ENABLED=true
QUEUE_REDIS_DB=3
QUEUE_CONCURRENCY=10
QUEUE_DEFAULT_QUEUE=default
QUEUE_CRITICAL_WEIGHT=6
QUEUE_DEFAULT_WEIGHT=3
QUEUE_LOW_WEIGHT=1
QUEUE_SHUTDOWN_TIMEOUT=10s
QUEUE_DEFAULT_MAX_RETRY=3
QUEUE_DEFAULT_TIMEOUT=30s
```

这些键可以分成三类：

| env key | 当前含义 | 判断 | 目标 |
| --- | --- | --- | --- |
| `QUEUE_ENABLED` | 是否启用队列 client/server/monitor | 部署级开关，首次导库、排障、单 API 节点可能需要关 | 保留 env |
| `QUEUE_REDIS_DB` | Asynq 使用的 Redis DB | 基础设施隔离，和 Redis 部署有关 | 保留 env |
| `QUEUE_CONCURRENCY` | 单个 worker 进程并发执行 handler 数 | 机器规格/任务量相关，部署需要可调 | 保留 env |
| `QUEUE_DEFAULT_QUEUE` | 默认 lane 名称 | 代码约定，任务 builder 和 server queue map 应一致 | 内置 `default` |
| `QUEUE_CRITICAL_WEIGHT` | critical lane 权重 | 队列调度策略 | 内置 `6` |
| `QUEUE_DEFAULT_WEIGHT` | default lane 权重 | 队列调度策略 | 内置 `3` |
| `QUEUE_LOW_WEIGHT` | low lane 权重 | 队列调度策略 | 内置 `1` |
| `QUEUE_SHUTDOWN_TIMEOUT` | worker 停机等待 in-flight task 的时间 | 运行策略，默认值即可 | 内置 `10s` |
| `QUEUE_DEFAULT_MAX_RETRY` | 默认重试次数 | 任务可靠性策略，handler 要幂等 | 内置 `3` |
| `QUEUE_DEFAULT_TIMEOUT` | 默认任务超时 | 任务运行策略，handler 应尊重 context | 内置 `30s` |

现有运行时依赖关系：

- `internal/config.Load()` 读取 `QueueConfig`。
- `bootstrap.Resources` 根据 `QUEUE_ENABLED` 和 `QUEUE_REDIS_DB` 初始化 queue Redis client，并影响 `/ready` 的 `queue_redis`。
- `bootstrap.App` 在队列启用时创建 `taskqueue.Client`、`taskqueue.Inspector` 和 asynqmon UI。
- `bootstrap.Worker` 在队列启用时创建 `taskqueue.Client`、`taskqueue.Server` 和 job mux。
- `internal/platform/taskqueue` 使用 `DefaultQueue`、lane weights、retry/timeout、shutdown timeout 组装 Asynq client/server option。

## 选型

### 方案 A：把所有队列策略迁到 `system_settings`

不推荐。

原因：

- queue bootstrap 早于很多业务模块，worker 启动必须先可靠拿到队列配置。
- DB 不可用时，`admin-worker` 仍应能明确失败或通过 env 关闭，而不是卡在读取系统设置。
- `system_settings` 适合业务策略，不适合 worker 基础设施启动策略。
- 队列 lane 和 retry 默认属于代码契约，随任务 handler 设计一起演进，不适合让后台用户随意改。

### 方案 B：保留全部 `QUEUE_*` env

不采用。

原因：

- env 仍然长，违背 Docker-first “用户只改必要项”的方向。
- lane 名称和权重不是部署必填知识，暴露后只会增加误配概率。
- 默认 retry/timeout 与任务幂等、任务类型设计强相关，应该由代码和测试共同约束。

### 方案 C：只保留部署级队列项，其余内置（推荐）

内容：

Docker-first env 最终只保留：

```env
QUEUE_ENABLED=true
QUEUE_REDIS_DB=3
QUEUE_CONCURRENCY=10
```

代码内置：

```text
default_queue=default
critical_weight=6
default_weight=3
low_weight=1
shutdown_timeout=10s
default_max_retry=3
default_timeout=30s
```

优点：

- env 一次减少 7 个键。
- 保留部署真正可能需要改的启用状态、Redis DB 和 worker 并发。
- 队列策略跟随代码、任务 builder 和测试一起维护，减少“env 改了但 handler 不适配”的风险。
- 不引入 DB/system_settings 启动依赖。

缺点：

- 少数部署若确实要改 lane 权重或 retry/timeout，需要发版或另做专门设计，不再靠 env 热改。

推荐采用。

## 推荐设计

### 1. Docker-first env 只保留三项

最终 Docker-first env 的 queue 部分变为：

```env
QUEUE_ENABLED=true
QUEUE_REDIS_DB=3
QUEUE_CONCURRENCY=10
```

说明：

- `QUEUE_ENABLED=false` 仍用于首次导库、排障、单 API 节点、不运行 worker 的部署场景。
- `QUEUE_REDIS_DB=3` 仍用于把 Asynq queue broker 和 token/session/cache Redis key 隔离。
- `QUEUE_CONCURRENCY=10` 仍允许按 worker 节点 CPU/I/O 能力调整吞吐。

### 2. queue policy 代码内置

内置默认值：

```text
QueueDefault = "default"
QueueCritical = "critical"
QueueLow = "low"
critical_weight = 6
default_weight = 3
low_weight = 1
shutdown_timeout = 10s
default_max_retry = 3
default_timeout = 30s
```

注意：

- lane 名称必须继续由 `internal/platform/taskqueue` 统一导出/使用，不能在任务 builder 里散写字符串。
- server queue map 仍应包含 critical/default/low，且权重保持当前行为。
- client enqueue 默认仍落到 default lane；指定 low/critical 的任务 builder 不变。

### 3. 不进 `system_settings`

本切片不新增系统设置 key。

理由：

- worker 启动期配置不能依赖业务 DB 设置。
- queue policy 和任务 handler 语义强绑定，不是运营后台应该随意调整的业务开关。
- 系统设置页已经承担 captcha、verify code、upload token TTL 这类业务策略；不要把基础设施默认值倒进去。

### 4. `/ready` 和 asynqmon 行为不变

不改：

- `QUEUE_ENABLED=false` 时，`queue_redis` readiness 为 `disabled`。
- `QUEUE_ENABLED=true` 且 Redis 不可用时，`queue_redis` readiness 为 `down`。
- `admin-api` 在队列启用时仍创建 queue client/inspector。
- `admin-worker` 在队列启用时仍启动 Asynq server。
- 队列监控仍使用 Asynq Redis DB 和官方 asynqmon UI。

### 5. 本地 Docker-first 样例同步收口

需要同步：

- `deploy/docker-first/admin-go.env.example`
- 本地 ignored 的 `deploy/docker-first/admin-go.env` 如果存在
- 部署 runbook 中列出的 queue env 示例
- 架构/契约文档中“这些 queue policy 由 env 配置”的描述

文档口径改为：

```text
Docker-first env only keeps QUEUE_ENABLED, QUEUE_REDIS_DB, and QUEUE_CONCURRENCY for queue runtime.
Queue lane names, lane weights, default retry/timeout, and shutdown timeout are code-owned defaults.
```

## 迁移范围

### 需要改

后端仓 `admin_back_go`：

- `internal/config/config.go`
- `internal/config/config_test.go`
- `internal/platform/taskqueue/client.go` 如当前依赖 `QueueConfig.DefaultQueue`，改为使用代码默认常量或 internal defaults
- `internal/platform/taskqueue/server.go` 如当前依赖 `QueueConfig` weights/shutdown timeout，改为使用代码默认常量或 internal defaults
- `internal/platform/taskqueue/*_test.go`
- `internal/bootstrap/*_test.go` 中构造 `QueueConfig` 的用例
- `deploy/docker-first/admin-go.env.example`
- 本地 ignored 的 `deploy/docker-first/admin-go.env` 如果存在
- 后端架构文档中直接列出的 deprecated `QUEUE_*` env

根仓 `admin_go`：

- `docs/deployment/docker-first-backend.md`
- `docs/deployment/local.md` 如列出 queue policy env
- `docs/deployment/production.md` 如列出 queue policy env
- `docs/contracts/admin-api-v1.md` 中 queue env contract
- `docs/status/current-status.md` 如涉及 env 口径
- 后续 implementation plan

### 不改

- 队列任务类型和 payload schema。
- `notification:*`、`export:*`、`ai:*` 等现有 task builder 语义。
- `cron_task` / scheduler 注册逻辑。
- asynqmon UI 静态资源。
- 前端页面。
- MySQL/Redis/APP_SECRET/token/realtime/scheduler/AI/CORS 等其他 env 组。

## 行为保持

不改变：

- 队列默认启用。
- 队列 Redis DB 默认仍为 `3`。
- worker 默认并发仍为 `10`。
- 默认 lane 仍为 `default`。
- critical/default/low lane 权重仍为 `6/3/1`。
- 默认 retry 仍为 `3`。
- 默认 task timeout 仍为 `30s`。
- worker shutdown timeout 仍为 `10s`。
- `/ready` 的 `queue_redis` check 语义不变。
- asynqmon inspector 使用同一个 queue Redis DB。

## 兼容策略

本切片目标是 Docker-first env 收口，不是保留旧 env 热配置能力。

实现时允许：

- 删除 `QueueConfig` 中不再需要的字段；或
- 保留内部字段但不再从 env 读取，统一由 default constructor 填充。

但必须满足：

- `deploy/docker-first/admin-go.env.example` 和本地 `admin-go.env` 不再出现 deprecated queue policy keys。
- `internal/config.Load()` 不再把 deprecated queue policy keys 作为公开运行时配置契约。
- 测试要防止这些 key 回流到 Docker-first env。

Deprecated queue policy keys：

```text
QUEUE_DEFAULT_QUEUE
QUEUE_CRITICAL_WEIGHT
QUEUE_DEFAULT_WEIGHT
QUEUE_LOW_WEIGHT
QUEUE_SHUTDOWN_TIMEOUT
QUEUE_DEFAULT_MAX_RETRY
QUEUE_DEFAULT_TIMEOUT
```

## 测试策略

### 后端配置测试

新增/调整：

- 默认 queue config 只允许 env 覆盖 `Enabled`、`RedisDB`、`Concurrency`。
- Docker-first env example 不包含 deprecated queue policy keys。
- Docker-first 本地 env 如果存在，也不包含 deprecated queue policy keys。
- 默认 values 仍是：enabled true、redis db 3、concurrency 10、default lane default、weights 6/3/1、retry 3、timeout 30s、shutdown 10s。

### taskqueue 测试

保持或补充：

- client 默认 enqueue 使用 default lane。
- redis option 使用 `QUEUE_REDIS_DB`。
- server queue map 包含 critical/default/low 且权重为 6/3/1。
- server concurrency 仍来自 env/config。
- shutdown timeout/default retry/default timeout 行为保持。

### bootstrap 测试

保持：

- `QUEUE_ENABLED=false` 时 worker 不启动 queue server，readiness 为 disabled。
- `QUEUE_ENABLED=true` 时 resources 使用 queue Redis DB。
- admin-api 创建 queue client/inspector 的条件不变。

### 文档/治理验证

必须跑：

```powershell
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

实现阶段还应跑后端 targeted tests，例如：

```powershell
go test ./internal/config ./internal/platform/taskqueue ./internal/bootstrap
```

Docker runtime 验证在实现阶段按需要执行：

```powershell
cd E:\admin_go\admin_back_go\deploy\docker-first
docker compose up -d --build admin-api admin-worker
curl.exe -fsS http://127.0.0.1:8080/ready
```

## 文档同步点

需要同步的口径：

1. Docker-first env 的 queue 组只剩 `QUEUE_ENABLED`、`QUEUE_REDIS_DB`、`QUEUE_CONCURRENCY`。
2. queue lane names、weights、default retry/timeout、shutdown timeout 都是代码内置默认值。
3. `QUEUE_ENABLED=false` 是明确关闭队列，不是静默兜底。
4. `QUEUE_CONCURRENCY` 仍是部署调优项；I/O 密集任务可按 worker 节点能力调高，但 CPU 密集任务不能无限提高。
5. 旧 `devtools_queue_monitor_queues` 仍不回到系统设置。

## 风险和处理

| 风险 | 处理 |
| --- | --- |
| 有部署依赖 env 调整 lane 权重 | Docker-first 不再支持热改；如真实需要，后续单独设计“高级队列策略”，不要混进普通 env |
| tests 构造 `QueueConfig` 时漏默认字段 | 使用 default constructor 或 helper，减少散落字段 |
| 文档仍列出 deprecated queue env | 用 `rg "QUEUE_DEFAULT_QUEUE|QUEUE_CRITICAL_WEIGHT|QUEUE_DEFAULT_WEIGHT|QUEUE_LOW_WEIGHT|QUEUE_SHUTDOWN_TIMEOUT|QUEUE_DEFAULT_MAX_RETRY|QUEUE_DEFAULT_TIMEOUT"` 收尾 |
| worker 行为被误改 | targeted `taskqueue` + `bootstrap` tests 验证默认队列、权重、并发、timeout |
| 用户误以为 queue 进系统设置 | 明确写入 contract/runbook：queue policy 是 code-owned startup config，不是 system setting |

## 非目标

本切片不做：

- outbox。
- 队列可视化重写。
- 动态调整 worker 并发。
- 后台系统设置管理 queue policy。
- 多 Redis 集群、多 queue broker。
- 修改任务 payload 或业务调度语义。
- 修改 scheduler env。
- 修改 realtime env。
- 修改 AI stream timeout env。

## 验收标准

完成实现后应满足：

1. `deploy/docker-first/admin-go.env.example` 和本地 `admin-go.env` 只保留三项 queue env。
2. `QUEUE_DEFAULT_QUEUE`、`QUEUE_CRITICAL_WEIGHT`、`QUEUE_DEFAULT_WEIGHT`、`QUEUE_LOW_WEIGHT`、`QUEUE_SHUTDOWN_TIMEOUT`、`QUEUE_DEFAULT_MAX_RETRY`、`QUEUE_DEFAULT_TIMEOUT` 不再是 Docker-first env contract。
3. 后端默认行为与当前运行时一致。
4. targeted Go tests 通过。
5. `git diff --check` 和 governance check 通过。
6. 如实际重启 Docker，`/ready` 仍显示 `queue_redis` 为 `up` 或在关闭队列时为 `disabled`。

## 下一步计划入口

用户 review 认可本 spec 后，再写 implementation plan。建议计划拆成：

1. Config defaults/tests：收口 `QueueConfig` env 读取和 Docker-first env guard。
2. Taskqueue code-owned defaults：让 client/server 使用内部默认策略。
3. Deploy/docs sync：同步 env example、本地 env、architecture/contract/deployment docs。
4. Verification：targeted Go tests + governance；必要时 Docker `/ready`。
