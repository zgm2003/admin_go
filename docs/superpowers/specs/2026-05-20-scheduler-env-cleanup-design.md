# Scheduler env 收口设计

日期：2026-05-20
状态：draft
范围：`admin_back_go` worker scheduler、分布式锁默认值、Docker-first env 模板、相关架构/部署文档和测试

## 目标

这次只做 **scheduler env cleanup**，不重做系统定时任务，不改 `cron_task` 表，不改队列 handler，不改 notification/AI/payment 业务任务。

要达到的结果：

1. Docker-first env 里 scheduler 配置尽量短，只保留真实部署时可能需要快速开关的项。
2. scheduler timezone、Redis 分布式锁 key prefix、lock TTL 由代码内置默认值管理。
3. 保持 `admin-worker` 继续从 `cron_task` 表注册启用任务，继续通过 queue 投递真实任务。
4. 保持多 worker 场景的 Redis 分布式锁保护能力，不因为 env 收口退化成无锁。
5. 不把 scheduler bootstrap 依赖 `system_settings`，避免 worker 启动前必须先依赖 DB 系统设置读取基础设施默认值。

## Linus 三问

1. 这是真问题吗？
   - 是。当前 Docker-first env 暴露 4 个 `SCHEDULER_*` 键，其中 timezone、lock prefix、lock TTL 是运行时基础设施默认值。普通部署用户很难判断该不该改；改错会导致时区偏移、多个 worker 互相抢跑，或锁过早/过晚释放。
2. 有更简单的做法吗？
   - 有。只保留 `SCHEDULER_ENABLED`；其他 scheduler policy 用代码默认值，不新增后台配置、不新增表字段。
3. 会破坏已有前端、接口、登录和权限吗？
   - 不应该。系统定时任务 REST、`cron_task` 管理页、registry status、queue task 类型、worker handler 都不变；只改变默认值来源和 Docker-first env 暴露面。

## 当前事实

Docker-first env 当前暴露：

```env
SCHEDULER_ENABLED=true
SCHEDULER_TIMEZONE=Asia/Shanghai
SCHEDULER_LOCK_PREFIX=admin_go:scheduler:
SCHEDULER_LOCK_TTL=30s
```

这些键可以分成两类：

| env key | 当前含义 | 判断 | 目标 |
| --- | --- | --- | --- |
| `SCHEDULER_ENABLED` | 是否在 `admin-worker` 中启动 scheduler | 部署级开关；排障、导入数据、临时停 cron 时需要快速可控 | 保留 env |
| `SCHEDULER_TIMEZONE` | gocron 注册任务使用的时区 | 运行时默认值；当前产品默认中国后台，固定 `Asia/Shanghai` 更清晰 | 内置 `Asia/Shanghai` |
| `SCHEDULER_LOCK_PREFIX` | Redis 分布式锁 key prefix | 代码命名空间；不应让用户随意改到和其他 key 冲突 | 内置 `admin_go:scheduler:` |
| `SCHEDULER_LOCK_TTL` | 每次 scheduler job 执行前获取 Redis 锁的 TTL | 基础设施保护策略；过短/过长都会影响任务执行 | 内置 `30s` |

现有运行时依赖关系：

- `internal/config.Load()` 读取 `SchedulerConfig`。
- `bootstrap.NewWorker()` 只在 `cfg.Queue.Enabled=true` 后才装配 queue 和 scheduler。
- `cfg.Scheduler.Enabled=true` 时，worker 创建 `platform/scheduler.Scheduler`。
- 如果 Redis resource 存在，worker 给 scheduler 注入 `redislock.New(...)`，每个 scheduler job 执行前先拿 Redis 分布式锁。
- `internal/module/crontask.SchedulerService.RegisterEnabled()` 从 `cron_task` 表读取启用任务，并按 Go registry 注册到 scheduler。
- `jobs.RegisterSchedules()` 当前不再注册静态业务 schedule；业务 cron-to-queue 事实源是 `cron_task` 表 + Go registry。

## 选型

### 方案 A：全部迁到 `system_settings`

不推荐。

原因：

- Scheduler 是 `admin-worker` 启动期基础设施能力；不能把时区、锁 prefix、锁 TTL 变成依赖 DB 系统设置的启动前置条件。
- `system_settings` 适合 captcha TTL、verify code TTL、upload token TTL 这类业务策略，不适合 Redis lock namespace 这类基础设施细节。
- 如果系统设置缓存、DB、迁移状态异常，scheduler 默认值也会受影响，启动链路更脆。

### 方案 B：保留全部 `SCHEDULER_*` env

不采用。

原因：

- env 继续变长，违背 Docker-first “用户只改必要项”的方向。
- `SCHEDULER_LOCK_PREFIX` 是代码命名空间，普通用户改错后多个部署/任务可能互相影响。
- `SCHEDULER_LOCK_TTL` 是执行保护策略，不是运营后台或部署者日常需要调的业务值。
- `SCHEDULER_TIMEZONE` 在当前产品默认下没有必要每次部署暴露。

### 方案 C：只保留 scheduler 启用开关，其余内置（推荐）

内容：

Docker-first env 最终只保留：

```env
SCHEDULER_ENABLED=true
```

代码内置：

```text
scheduler_timezone = Asia/Shanghai
scheduler_lock_prefix = admin_go:scheduler:
scheduler_lock_ttl = 30s
```

优点：

- env 一次减少 3 个键。
- 保留真正有部署价值的开关：要不要启动 worker scheduler。
- 多 worker 分布式锁仍默认启用，不需要用户理解 Redis lock 参数。
- 不引入 DB/system_settings 启动依赖。

缺点：

- 如果极少数部署确实需要非中国时区或自定义锁 namespace，不能再只靠 Docker-first env 改；应单独设计部署 namespace 或高级配置，不要为普通部署继续暴露这 3 个键。

推荐采用。

## 推荐设计

### 1. Docker-first env 只保留 `SCHEDULER_ENABLED`

最终 Docker-first env 的 scheduler 部分变为：

```env
SCHEDULER_ENABLED=true
```

说明：

- `SCHEDULER_ENABLED=false` 仍表示 worker 不启动 scheduler；queue worker 本身仍可消费已入队任务。
- Docker-first 默认保留 `true`，因为系统通知任务、AI run timeout 等 cron-to-queue 任务需要 scheduler 注册。
- 导入数据、排障、临时停止自动任务时，部署者仍可通过 env 快速关闭 scheduler。

### 2. scheduler policy 代码内置

内置默认值：

```text
DefaultSchedulerTimezone = "Asia/Shanghai"
DefaultSchedulerLockPrefix = "admin_go:scheduler:"
DefaultSchedulerLockTTL = 30s
```

注意：

- `config.Load()` 不再读取 `SCHEDULER_TIMEZONE`、`SCHEDULER_LOCK_PREFIX`、`SCHEDULER_LOCK_TTL`。
- 直接构造零值 `config.SchedulerConfig{}` 时，`platform/scheduler.New()` 仍必须归一化这些默认值。
- Redis locker 存在时，默认 lock prefix 不为空，确保分布式锁默认生效。
- scheduler 启动日志要显示归一化后的时区，不能因为 `cfg.Scheduler.Timezone` 为空而打印空字符串。

### 3. 不进 `system_settings`

本切片不新增系统设置 key。

理由：

- `SCHEDULER_ENABLED` 是部署期开关，适合 env。
- timezone/lock prefix/lock TTL 是 worker bootstrap 和基础设施默认值，不是业务策略。
- `cron_task` 表已经是“哪些业务任务启用、cron 表达式是什么”的业务事实源；不要把 scheduler 基础参数再拆进系统设置。

### 4. system cron 行为不变

不改：

- `cron_task` 表结构和数据语义。
- `/api/admin/v1/cron-tasks` REST 契约。
- Go registry name 到 queue task type 的映射。
- `notification_task_scheduler` 投递 `notification:dispatch-due:v1`。
- `ai_run_timeout` 投递 `ai:run-timeout:v1`。
- scheduler job 执行前的 Redis 分布式锁保护。
- queue enabled/Redis DB/concurrency 现有配置。

### 5. 文档同步收口

需要同步：

- `admin_back_go/deploy/docker-first/admin-go.env.example`
- 本地 ignored 的 `admin_back_go/deploy/docker-first/admin-go.env` 如果存在
- `docs/deployment/docker-first-backend.md`
- `docs/architecture/04-go-backend-framework.md`
- `docs/architecture/05-development-quality-rules.md` 如仍把 scheduler lock env 当作 active contract
- `admin_back_go/docs/architecture.md`
- `admin_back_go/README.md` 中 active runtime 的 `SCHEDULER_*` env 列表

文档口径改为：

```text
Docker-first env only keeps SCHEDULER_ENABLED for scheduler runtime.
Scheduler timezone, distributed lock prefix, and lock TTL are code-owned defaults.
Business task schedules remain DB-owned through cron_task rows.
```

历史 spec/plan 中记录旧讨论的 `SCHEDULER_TIMEZONE` / `SCHEDULER_LOCK_PREFIX` / `SCHEDULER_LOCK_TTL` 不强制回改；active docs 和 deploy 模板必须清干净。

## 迁移范围

### 需要改

后端仓 `admin_back_go`：

- `internal/config/config.go`
- `internal/config/config_test.go`
- `internal/platform/scheduler/scheduler.go`
- `internal/platform/scheduler/scheduler_test.go`
- `internal/bootstrap/worker.go`
- `internal/bootstrap/worker_test.go` 中 scheduler 构造和日志相关用例
- `deploy/docker-first/admin-go.env.example`
- 本地 ignored 的 `deploy/docker-first/admin-go.env` 如果存在
- `README.md`
- `docs/architecture.md`

根仓 `admin_go`：

- `docs/deployment/docker-first-backend.md`
- `docs/architecture/04-go-backend-framework.md` 如存在 active scheduler env 列表
- `docs/architecture/05-development-quality-rules.md` 如存在 active scheduler env 列表
- `docs/testing/smoke-matrix.md` 如存在 active env 描述
- `docs/status/current-status.md` 如需要补充“scheduler lock 默认值代码内置”的状态

### 不需要改

- 不改前端。
- 不改 `cron_task` schema、seed 或页面字段。
- 不改 `internal/module/crontask` 的 CRUD/registry/service 行为。
- 不改 notification task / AI run timeout / queue handler 业务逻辑。
- 不改 `QUEUE_*` env。
- 不改 `AI_RUN_STALE_TIMEOUT`；它是 AI run stale 判定窗口，不是 scheduler lock TTL。
- 不新增 SQL/migration/system_settings row。

## 兼容与风险

### Docker-first 默认

Docker-first 保持：

```env
SCHEDULER_ENABLED=true
```

这样 `admin-worker` 启动后会注册 DB 中启用的 cron tasks，并通过 queue 投递业务任务。

### 本地开发和数据导入

如果本地数据库还没导入或正在排障，仍可临时设置：

```env
SCHEDULER_ENABLED=false
```

这样 worker 可以只保留 queue 消费能力，不注册 scheduler。

### 非默认时区

删除 `SCHEDULER_TIMEZONE` 后，当前默认统一为 `Asia/Shanghai`。

如果未来要支持多时区部署，应该单独设计：

- 是全站后台时区？
- 是用户展示时区？
- 是 cron 表达式解释时区？
- 是否要进 `system_settings` 或独立站点配置？

本切片不提前扩展。

### Redis key namespace

`SCHEDULER_LOCK_PREFIX` 内置后，多个独立部署共享同一个 Redis DB 时，理论上 scheduler lock key 会共享命名空间。

Docker-first 推荐做法仍然是：

- 独立 Redis 实例，或
- 至少独立 Redis DB / 独立部署栈

如果后续要支持多个环境共享同一个 Redis DB，应统一设计全局 runtime namespace，而不是只恢复 scheduler lock prefix env。

## 测试与验证

实现时至少先写失败测试：

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/config
go test ./internal/platform/scheduler
go test ./internal/bootstrap
```

期望 RED：

- `internal/config` 证明 `SCHEDULER_TIMEZONE` / `SCHEDULER_LOCK_PREFIX` / `SCHEDULER_LOCK_TTL` 仍被 env 覆盖。
- Docker-first env guard 证明 `admin-go.env.example` / 本地 `admin-go.env` 仍记录 deprecated scheduler policy keys。
- `internal/platform/scheduler` 证明零值 config 下 lock prefix 为空，Redis lock 不会默认生效。

实现后至少跑：

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/config ./internal/platform/scheduler ./internal/bootstrap ./internal/module/crontask
go vet ./internal/config ./internal/platform/scheduler ./internal/bootstrap ./internal/module/crontask
```

如 worker/runtime 装配改动较多，再补：

```powershell
go test ./cmd/admin-worker ./internal/jobs ./internal/platform/taskqueue
```

Docker-first config 验证：

```powershell
cd E:\admin_go\admin_back_go\deploy\docker-first
docker compose config --quiet
```

如用户要求 fresh runtime 验证，再补：

```powershell
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
  - `SCHEDULER_TIMEZONE`
  - `SCHEDULER_LOCK_PREFIX`
  - `SCHEDULER_LOCK_TTL`
- active docs 不再把这 3 个键描述为 Docker-first 必改 env。
- `SCHEDULER_ENABLED` 仍保留且行为不变。
- `admin-worker` 零值 scheduler config 仍使用：
  - `Asia/Shanghai`
  - `admin_go:scheduler:`
  - `30s`
- Redis locker 存在时，scheduler job 默认仍会尝试获取分布式锁。

## 明确不做

- 不做 cron task UI 改版。
- 不做 scheduler system settings。
- 不做全局 runtime namespace 设计。
- 不做多租户/多站点时区。
- 不改 queue 队列名、权重、超时、重试策略。
- 不改 AI stream timeout / AI run stale timeout。
- 不改 CORS。
- 不改 frontend。

## 审阅清单

请重点确认：

1. 是否接受 Docker-first scheduler env 最终只保留 `SCHEDULER_ENABLED`。
2. 是否接受 `SCHEDULER_TIMEZONE=Asia/Shanghai` 完全内置，不进系统设置。
3. 是否接受 `SCHEDULER_LOCK_PREFIX=admin_go:scheduler:` / `SCHEDULER_LOCK_TTL=30s` 完全内置。
4. 是否保持 `cron_task` 表继续作为业务任务启用和 cron 表达式事实源。
