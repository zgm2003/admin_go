# Go Backend Framework and Architecture

## 结论

`admin_back_go` 采用 **Gin modular monolith**。

不是 Java 式分层，也不是微服务，也不是闭门造车。它是一个能承接当前 admin 系统、RBAC、AI 应用接入、WebSocket realtime、队列和未来模块演进的 Go 后端骨架。

一句话：

```text
cmd -> bootstrap -> server -> module -> platform
```

业务模块内部固定为：

```text
route -> handler -> service -> repository -> model
```

但这不是让每个模块都硬塞 5 个文件。没有数据库就没有 repository，没有表就没有 model。少一层是一层。

## 为什么选这个架构

### 真问题

我们要承接的是已有 admin 系统，不是写 demo。

它必须承接：

```text
现有 RBAC 契约
现有前端动态菜单和路由
用户登录和 session
平台隔离 admin/app
WebSocket / AI streaming
队列和定时任务
业务模块渐进演进
```

### 简单做法

先保持单体。不要一上来微服务，不要一上来 DDD 包袱，不要一上来生成器驱动。

```text
一个 Go 进程
一个 Gin HTTP API
一套清楚的模块边界
一套可测试的契约
```

### 不破坏什么

不破坏现有前端，不破坏现有 RBAC 语义，不破坏用户登录路径。

现有产品事实和契约是输入。Go 运行时按当前契约实现，但不重新发明权限模型。

## 顶层目录

```text
admin_back_go/
  cmd/admin-api/              # HTTP 进程入口，只负责启动 API
  cmd/admin-worker/           # 后台进程入口，只负责队列消费和定时调度
  docs/                       # 本仓库架构、状态和契约文档
  internal/bootstrap/         # 应用装配：config/logger/server/resources
  internal/config/            # 配置读取和默认值
  internal/server/            # Gin engine、全局 middleware、路由挂载
  internal/middleware/        # HTTP middleware
  internal/response/          # 统一响应和错误映射
  internal/module/            # 业务模块
  internal/jobs/              # 队列任务类型、handler 注册、cron 投递注册
  internal/platform/          # DB/Redis/queue/storage/AI clients 等外部资源
  internal/version/           # 版本信息
```

## module 规则

模块是业务边界，不是技术分层垃圾桶。

推荐模块：

```text
system      # health / ping / runtime info
user        # 用户资料、后台用户管理
session     # token/session/login state
permission  # 权限定义、菜单、按钮、路由
role        # 角色和授权矩阵
auth        # 登录、登出、me、init
operationlog
```

模块内部最多这些文件：

```text
route.go       # 注册路由，只绑定 handler
handler.go     # 解析 HTTP，调用 service，返回 response
request.go     # HTTP 入参结构和 binding tag，只服务当前模块
service.go     # 业务规则，不能依赖 gin.Context
repository.go  # 数据访问，不能写业务决策
model.go       # 数据库映射，只放字段和基础 tag
dto.go         # service/input/output/response DTO，不放 Gin binding tag
errors.go      # 模块错误
```

## Platform Scope Adapter 规则

`/api/admin/v1` 和 `/api/app/v1` 是 HTTP scope，不是业务模块边界。

业务模块必须按 capability 命名，例如 `auth`、`aichat`、`wallet`、`uploadtoken`、`notification`。新增平台时，默认只新增 route / handler / presenter / policy，不新增 `appai`、`appwallet`、`xxauth` 这类平台名前缀业务模块。

允许：

```text
/api/admin/v1/... -> admin route/handler -> shared service -> repository/model -> admin presenter
/api/app/v1/...   -> app route/handler   -> shared service -> repository/model -> app presenter
```

禁止：

```text
adminauth + appauth + xxauth 各自实现业务
adminai + appai + xxai 各自实现业务
adminwallet + appwallet + xxwallet 各自实现业务
```

临时平台 adapter 必须有名字、有边界、有收敛计划。`appauth` 当前只能被理解为 `/api/app/v1` scope 下 auth / users/me / profile / upload-tokens 的临时 HTTP adapter bundle，不拥有 auth/user/uploadtoken service、repository、model 或认证策略。

## 调用方向

允许：

```text
cmd -> bootstrap
bootstrap -> config/server/platform
server -> middleware/module route
route -> handler
handler -> service
service -> repository
repository -> model
```

禁止反向依赖：

```text
service -> gin.Context
repository -> gin.Context
model -> service
model -> repository
module A 随便 import module B 的 handler/repo
handler 直接查 DB/Redis
```

跨模块调用必须走 service 层，并且先问：是不是模块边界错了？

## 旧接口与新接口

为了不破坏前端，允许存在边界明确的 compatibility adapter：

```text
/api/Users/init
/api/admin/Permission/list
```

但它们不能污染新模块内部。做法是：

```text
legacy route adapter -> module service -> repository
```

新接口另走：

```text
/api/{scope}/v1/...
当前 admin = /api/admin/v1/...
未来 app   = /api/app/v1/...
```

旧接口兼容层不是新世界规则。

## RBAC 决策

采用现有 RBAC 契约作为 Go runtime 基线。

必须保留的语义：

```text
users.role_id 单角色模型，第一阶段不改多角色
permissions: DIR / PAGE / BUTTON
role_permissions: DIR 不授权，PAGE 授权，BUTTON 授权并隐含父 PAGE
Users/init 返回 permissions + router + buttonCodes + quick_entry
platform 使用 session.platform，不盲信 header
route access grant cache key 语义保持稳定
show_menu 只控制菜单显示，不代表无页面权限
PermissionCheck 必须 fail-closed：用户或角色不存在时拒绝，不允许绕过
route access grant cache 只做性能加速，cache miss/error 必须回源计算，不能成为权限真相源
role/permission 变更必须清理受影响用户的 route access grant cache
```

### RBAC RouteAccessCodes 与 buttonCodes 分离

`users/init.buttonCodes` 是前端按钮显隐契约，只能包含 BUTTON code。后端 `PermissionCheck` 使用内部 `RouteAccessCodes` 判断 route metadata code；`RouteAccessCodes` 可包含 PAGE code 和 BUTTON code。不要为了读接口创建 `view` / `查看` BUTTON，也不要把 PAGE code 暴露成前端按钮能力。

## Middleware 顺序

最终目标顺序：

```text
Recovery
RequestID
AccessLog
CORS
AuthToken
PermissionCheck
OperationLog
Handler
```

`PermissionCheck` / `OperationLog` 已先落最小骨架：默认没有规则就不拦截、不记录；只有显式 route metadata 配置后才生效。不要用注解或反射猜权限。

## Queue and Scheduler

后台任务采用 **单体多进程**，不是现在拆微服务：

```text
cmd/admin-api     # HTTP API，只处理请求，不消费队列，不跑 cron
cmd/admin-worker  # 队列消费 + 定时任务调度
```

底层组件：

```text
queue     = github.com/hibiken/asynq，Redis-backed at-least-once task queue
scheduler = github.com/go-co-op/gocron/v2
```

边界固定：

```text
internal/platform/taskqueue  # 封装 Asynq，不让业务到处 import asynq
internal/platform/scheduler  # 封装 gocron，不让业务直接跑 cron 业务
internal/jobs                # 任务类型、handler 注册、schedule 注册
```

### Job layering

`jobs` 要分层，但不按 `fast/slow` 这种目录分层。

原因很简单：快慢是运行时队列和 worker 配置，不是业务模块所有权。把业务代码按快慢塞目录，后面同一个业务任务改队列就要搬文件，这是坏味道。

当前采用三条队列 lane：

```text
critical # 高优先级、短任务，例如登录日志、权限缓存刷新、通知触发
default  # 默认业务异步任务
low      # 慢任务/批量任务，例如报表、导入导出、AI 后处理
```

代码所有权按业务分。当前最小骨架只有 `internal/jobs/noop.go`；任务增多后按下面拆，不提前造空文件：

```text
internal/jobs/registry.go        # 全局注册入口，保持薄，任务多了再拆
internal/jobs/types.go           # 跨模块任务类型命名规则，任务多了再拆
internal/jobs/system/*.go        # 系统级探针、维护任务，任务多了再拆
internal/module/<name>/jobs.go   # 业务模块自己的 task 构造和 handler
```

投递时选择 queue：

```text
taskqueue.Task{
  Type:  "operationlog:write:v1",
  Queue: taskqueue.QueueCritical,
}
```

不要建：

```text
internal/jobs/fast
internal/jobs/slow
```

`fast/slow` 只存在于队列 lane、worker 部署和任务 SLA 文档里，不成为业务代码目录。当前 lane 名称和权重由 `internal/platform/taskqueue` 代码内置，普通 Docker-first env 不暴露 lane 权重。

### Go concurrency model

Go 的基本单位是 goroutine：

```text
goroutine          # 很轻量，由 Go runtime 调度
OS thread          # runtime 会按需使用系统线程
GOMAXPROCS         # 同时执行 Go 代码的 CPU 核心数上限，默认按机器 CPU
Asynq Concurrency  # 同一个 worker 进程里同时处理多少个 task handler
```

但别误解：Go 可以并发很多 I/O 任务，不代表 CPU 密集任务可以无限开。

规则：

```text
I/O 密集任务：可以适当提高 QUEUE_CONCURRENCY，例如短信、邮件、HTTP 回调、日志写入
CPU 密集任务：控制并发，放 low queue 或独立 worker，必要时限制 GOMAXPROCS
慢任务：不能挤占 critical/default lane
长任务：必须有 timeout、context cancellation、幂等和可重试边界
```

未来要扩容时，不改业务代码：

```text
启动更多 cmd/admin-worker 进程
或按节点能力调整 QUEUE_CONCURRENCY
或把 low/AI worker 单独部署
```

规则：

```text
scheduler 只能投递 queue task，不直接执行业务
worker handler 必须幂等，因为队列语义是 at-least-once
任务类型必须版本化，例如 system:no-op:v1、module:action:v1
业务模块以后通过 module/<name>/jobs.go 暴露任务构造和 handler 依赖，不把 HTTP handler 拿来当 job handler
强一致场景以后加 DB outbox；当前最小骨架不假装 Redis queue 能解决事务一致性
admin-api 不因为 worker 挂了就启动失败；worker 是独立进程和独立运维边界
```

## 错误和响应

统一响应：

```json
{
  "code": 0,
  "data": {},
  "msg": "ok"
}
```

handler 不直接拼业务错误文本。后续要做：

```text
app error -> http status + response code + msg
```

## Go 味道规则

禁止 Java 味：

```text
ServiceImpl
Manager
Factory
BO/VO/PO 大乱炖
AbstractBaseWhatever
无意义 interface
为测试而 interface
```

允许 interface 的条件：

```text
有两个真实实现
或需要隔离外部系统：DB/Redis/AI client/queue
```

## Phase 顺序

```text
Phase A: 架构骨架文档和目录边界
Phase B: 整理当前最小 system 模块到 route/handler/service
Phase C: 接入 config/log/response/error/middleware 基线
Phase D: 接入 MySQL/Redis platform 层
Phase E: 接入 RBAC read path: CheckToken / CheckPermission / Users/init
Phase F: 接入 RBAC write path: Permission / Role / AuthPlatform
Phase G: 业务模块演进
```

当前只做 Phase A。不要偷跑。
