# Go Backend Framework and Architecture

## 结论

`admin_back_go` 采用 **Gin modular monolith**，但架构口径从 2026-05-27 起明确为 **new-system-first / multi-platform-first**。

不是 Java 式分层，也不是微服务，也不是闭门造车。它是一个新 Go 后端，要用一套核心能力服务 admin / app / canvas / openapi / merchant 等多个前端或平台入口。旧 PHP/Webman 项目只能作为设计参考，不是新项目的兼容包袱。

一句话：

```text
cmd -> bootstrap -> server -> module/{capability}/transport/{platform} -> module service -> shared / infra
```

当前代码仍大量存在于 `internal/module`，这是过渡事实；长期边界按业务能力收敛到 `module/{capability}`，平台差异显式落到 `transport/{platform}`，公共能力进入 `shared`，运行时技术资源进入 `infra`。

单体仍然是单体，只是内部边界从模糊的平铺 module 逐步收口到 `module / transport / shared / infra`。

## 为什么选这个架构

### 真问题

我们要建设的是未来能接入多个平台的新后端，不是写 demo，也不是维护旧接口兼容层。

它必须承接：

```text
现有 RBAC 契约
现有前端动态菜单和路由
用户登录和 session
多平台入口 admin/app/canvas/openapi/merchant
WebSocket / AI streaming
队列和定时任务
业务领域能力渐进演进
公共能力统一治理
```

### 简单做法

先保持单体。不要一上来微服务，不要一上来 DDD 包袱，不要一上来生成器驱动。

```text
一个 Go 单体
一组 Gin HTTP API 平台入口
一套清楚的 module/transport/shared/infra 边界
一套可测试的契约
```

### 不破坏什么

不破坏现有前端，不破坏现有 RBAC 语义，不破坏用户登录路径。

现有产品事实和契约是输入。Go 运行时按当前契约实现，但不把旧系统路径当成长期架构主线。

## 顶层目录

```text
admin_back_go/
  cmd/admin-api/              # HTTP 进程入口，只负责启动 API
  cmd/admin-worker/           # 后台进程入口，只负责队列消费和定时调度
  docs/                       # Go 后端运行时架构说明；状态/契约/测试/部署 truth 归 root docs/
  internal/bootstrap/         # 应用装配：config/logger/server/resources
  internal/config/            # 配置读取和默认值
  internal/server/            # Gin engine、全局 middleware、路由挂载；后续逐步变薄
  internal/middleware/        # HTTP middleware
  internal/module/            # 业务能力目录；长期按 capability + transport/{platform} 收口
  internal/shared/            # 跨能力公共服务：apperror/response/i18n/enum/validate/dict/setting
  internal/jobs/              # 队列任务类型、handler 注册、cron 投递注册
  internal/infra/             # 运行时技术资源层；承接 DB/Redis/queue/storage/AI clients
  internal/version/           # 版本信息
```

## 长期目标分层

```text
internal/module/{capability}/                       业务能力归属（auth/user/payment/ai/...）
internal/module/{capability}/transport/{platform}/  能力对某平台的 HTTP 表面
internal/shared/                                    跨能力公共服务
internal/infra/                                     运行时技术资源层（原外部资源目录）
```

不采用顶层平台 API 包 + 顶层领域包的 4 层切分。
理由：service 已经天然跨平台（入参带 platform），抽领域目录容易变成空抽象；
跨平台字段改动高频的项目，HTTP 表面与业务能力拆成远距离大目录会让日常修改成本变高。

`transport/{platform}` 只表达 HTTP 表面差异：route prefix、request DTO、presenter、认证入口、权限入口、operation log 策略。
module service 负责业务规则、状态变更、事务边界和领域错误，并只依赖 `shared` / `infra`。
`shared` 负责 dict / enum / validate / i18n / setting / pagination / errors 等跨能力公共服务。
`infra` 负责 DB / Redis / Queue / Storage / SDK / Logging 等运行时技术资源，不表达 admin/app/canvas/openapi/merchant 业务平台。

当前已落地的 shared 边界：

```text
internal/shared/apperror # 领域错误码、HTTP 状态和 i18n key/fallback 错误边界
internal/shared/response # HTTP { code, data, msg } 响应和 msg 本地化边界
internal/shared/i18n     # zh-CN/en-US catalog、Message lookup、legacy fallback bridge
internal/shared/enum     # 跨能力稳定常量和 IsXxx 判断
internal/shared/validate # Gin binding / go-playground validator 自定义 tag
internal/shared/dict     # enum -> frontend dict option；common providers registry
internal/shared/setting  # typed system setting keys and defaults
```

旧 root shared-like packages 已删除：`internal/apperror`、`internal/response`、`internal/i18n`、`internal/enum`、`internal/validate`、`internal/dict`。

`systemsetting` module 继续只做后台 CRUD；`shared/setting` 仍是已迁移 typed settings key 的跨模块读取/写入边界。小模块聚合第一波已落地：`profile` owns quick-entry data/service, `notification` owns notification tasks under `notification/task`, export task capability path is `internal/module/export`, and auth platform capability path is `internal/module/auth_platform`; routes/tables/queue task types/i18n IDs stay stable.

## module 过渡规则

`internal/module` 是当前过渡目录。模块仍然可以承接当前运行时，但新增平台入口和公共能力时，不再默认继续往 module 里堆。

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

当前 module 根目录只放业务/runtime 文件；HTTP 表面必须进 `transport/{platform}`：

```text
service.go     # 业务规则，不能依赖 gin.Context
repository.go  # 数据访问，不能写业务决策
model.go       # 数据库映射，只放字段和基础 tag
dto.go         # service/input/output/response DTO，不放 Gin binding tag
errors.go      # 模块错误
jobs.go        # 模块自己的 task 构造和 handler 依赖，任务多了再拆
transport/admin/route.go    # admin HTTP 路由注册
transport/admin/handler.go  # admin HTTP 入参解析、调用 service、返回 response
transport/app/route.go      # app HTTP 路由注册（有 app 表面时）
transport/app/handler.go    # app HTTP 入参解析、调用 service、返回 response
transport/canvas/route.go   # canvas HTTP 路由注册（有 canvas 表面时）
transport/canvas/handler.go # canvas HTTP 入参解析、调用 service、返回 response
```

## 多平台规则

参见 `docs/architecture/00-platform-and-module-rules.md`（R1-R8）。

admin/app/canvas/openapi/merchant 是业务 platform，不是复制业务包的理由。

不要把任何业务能力定义成长期 `admin-only`。当前只有 admin 路由，只能说明当前暴露面先是 admin；当前 canvas 路由、未来 app / openapi / merchant 等入口仍应从同一 capability 扩展。

当前过渡期仍允许 service/repository/model/jobs 留在 module 根目录；active HTTP 路由、handler、request/presenter 等入口文件必须按 `internal/module/{capability}/transport/{platform}/` 收口。
架构测试 `TestNoModuleRootHTTPSurface` 会拒绝 module 根目录下的 `route.go`、`handler.go`、`app_handler.go`、`platform_handler.go`、`app_route_test.go`、`platform_route.go`。
admin/app/canvas 差异进入 transport 层；业务规则进入 module service；跨能力公共能力进入 shared；外部技术资源进入 infra。

admin user、app user、canvas user 可以有不同 HTTP 表达，但底层用户核心实体、账号安全、profile 基础能力应通过同一 capability 复用，而不是复制多套业务。

`transport/callback/` 是外部支付/第三方回调的 HTTP 表面命名例外，不是 business platform。它不能进入 platform 字典、权限平台枚举或用户 session platform。

## 调用方向

允许：

```text
cmd -> bootstrap
bootstrap -> config/server/infra
server -> middleware/module transport route
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

## 新项目 API 口径

本项目不是 legacy migration。后续文档和代码不再以 legacy/compat 作为主叙事。API 统一按平台和资源表达：

```text
/api/{scope}/v1/...
当前 admin = /api/admin/v1/...
当前 app   = /api/app/v1/...
当前 canvas = /api/canvas/v1/...
未来 openapi/merchant 按产品决策扩展
```

如果当前运行时代码里仍有旧命名路径，视为待治理事实，不再作为新设计模板。新功能必须按新项目 API 口径设计。

## RBAC 决策

采用现有 RBAC 契约作为 Go runtime 基线。

必须保留的语义：

```text
users.role_id 单角色模型，第一阶段不改多角色
permissions: DIR / PAGE / BUTTON
role_permissions: DIR 不授权，PAGE 授权，BUTTON 授权并隐含父 PAGE
users/me 返回 permissions + router + buttonCodes
platform 使用 session.platform，不盲信 header
route access grant cache key 语义保持稳定
show_menu 只控制菜单显示，不代表无页面权限
PermissionCheck 必须 fail-closed：用户或角色不存在时拒绝，不允许绕过
route access grant cache 只做性能加速，cache miss/error 必须回源计算，不能成为权限真相源
role/permission 变更必须清理受影响用户的 route access grant cache
```

### RBAC RouteAccessCodes 与 buttonCodes 分离

`users/me.buttonCodes` 是前端按钮显隐契约，只能包含 BUTTON code。后端 `PermissionCheck` 使用内部 `RouteAccessCodes` 判断 route metadata code；`RouteAccessCodes` 可包含 PAGE code 和 BUTTON code。不要为了读接口创建 `view` / `查看` BUTTON，也不要把 PAGE code 暴露成前端按钮能力。

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
internal/infra/taskqueue  # 封装 Asynq，不让业务到处 import asynq
internal/infra/scheduler  # 封装 gocron，不让业务直接跑 cron 业务
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

代码所有权按业务分。当前注册入口是 `internal/jobs/noop.go`；任务增多后再按下面拆，不提前造空文件：

```text
internal/jobs/noop.go            # 当前全局注册入口，保持薄
internal/jobs/registry.go        # 未来任务增多后的全局注册入口，可由 noop.go 演进/拆分
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

`fast/slow` 只存在于队列 lane、worker 部署和任务 SLA 文档里，不成为业务代码目录。当前 lane 名称和权重由 `internal/infra/taskqueue` 代码内置，普通 Docker-first env 不暴露 lane 权重。

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
Phase D: 接入 MySQL/Redis infra 层
Phase E: 接入 RBAC read path: CheckToken / CheckPermission / users/me
Phase F: 接入 RBAC write path: Permission / Role / AuthPlatform
Phase G: 业务模块演进
```

Phase A-G 是早期搭建顺序的历史快照，不是当前进度判断源。当前阶段和已验证事实以 `docs/status/current-status.md`、`docs/README.md` 和运行时验证为准；不要用这段早期清单覆盖 current-status。
