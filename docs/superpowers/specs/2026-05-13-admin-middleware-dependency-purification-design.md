# Admin Middleware and Dependency Purification Design

日期：2026-05-13  
范围：`admin_back_go` 后端 Go middleware / 直接依赖 / 开源中间件候选池  
状态：design for review

## Linus 三问

### 1. 这是个真问题，还是臆想出来的？

是真问题。

这个项目已经不是 demo。当前 admin 后端承接登录态、RBAC、操作日志、上传、队列、WebSocket、支付、AI runtime 等路径。如果继续靠“能跑就行”的自写中间件和无审计依赖堆下去，后续做双令牌、OAuth2/OIDC、分布式、指标和链路追踪时会越来越难收口。

但问题也不是“所有自写都是垃圾”。当前全局 middleware 链路已经被 smoke 证明过，登录、权限、审计、WebSocket 都挂在这条线上。直接把它们换成第三方黑盒，是破坏 userspace。

本次真问题是：

```text
把当前依赖和 middleware 链路审计清楚；
删除或降级没有直接价值的依赖；
为后续选择优秀开源中间件建立准入标准；
保留已验证的登录、权限、审计、WebSocket 运行语义。
```

### 2. 有更简单的做法吗？

有。不要今天就重写认证，不要今天就上 OAuth2，不要看到 gin-gonic/contrib 就把 middleware 全换掉。

第一刀只做后端提纯：

```text
go.mod / go.sum 只接受 go mod tidy 证明的真实变化
middleware 链路只做文档化和候选池整理
开源中间件进入候选清单，不直接替换认证主链路
后续 Auth Foundation v2 另开 spec
```

### 3. 会破坏已有前端、接口、登录和权限吗？

按本设计不会。

本次不改变：

```text
Authorization: Bearer <access_token>
Cookie: access_token for explicitly allowed GET/HEAD paths
AuthToken -> PermissionCheck -> OperationLog 顺序
user_sessions 作为 session 真相源
auth_platforms 作为 token TTL 和 session policy 事实源
现有 /api/admin/v1 contract
```

如果任何实现步骤会影响上述行为，必须停止并升级为单独 spec。

## 当前证据

### 项目事实

当前后端架构是 Gin modular monolith：

```text
cmd -> bootstrap -> server -> module -> platform
route -> handler -> service -> repository -> model
```

全局 middleware 由 `admin_back_go/internal/server/router.go` 装配，当前顺序：

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

当前 `admin_back_go/internal/middleware/README.md` 已定义各 middleware 边界：

```text
RequestID      只处理 X-Request-Id
AccessLog      只记录访问日志，不做审计
CORS           只处理浏览器跨域
AuthToken      只解析 token 并挂载 AuthIdentity
PermissionCheck 只按显式 RouteKey 调 PermissionChecker
OperationLog   只按显式 RouteKey 调 OperationRecorder
```

认证和权限现状：

```text
auth login/session: implemented
auth platform: token TTL and session policy are DB-managed facts
RBAC bootstrap: implemented
user session read/revoke: implemented
realtime WebSocket: cookie token only for explicit GET/HEAD upgrade path
```

### 依赖审计初扫

`go mod why -m` 初扫结果：

```text
github.com/gin-contrib/cors                  direct, used by internal/middleware/cors.go
github.com/gin-gonic/gin                     direct, core HTTP framework
github.com/go-co-op/gocron/v2                direct, platform/scheduler
github.com/go-pay/gopay                      direct, platform/payment/alipay
github.com/go-playground/validator/v10       direct, internal/validate
github.com/go-sql-driver/mysql               direct, MySQL driver and mysql error handling
github.com/gorilla/websocket                 direct, platform/realtime
github.com/hibiken/asynq                     direct, platform/taskqueue
github.com/hibiken/asynqmon                  direct, module/queuemonitor
github.com/joho/godotenv                     direct, config.LoadDotEnv
github.com/redis/go-redis/v9                 direct, Redis clients/caches/pubsub/locks
github.com/robfig/cron/v3                    direct, cron expression parsing
github.com/tencentyun/cos-go-sdk-v5          direct, COS object writer
github.com/tencentyun/qcloud-cos-sts-sdk     direct, COS STS signer
github.com/wenlng/go-captcha-assets          direct, slide captcha assets
github.com/wenlng/go-captcha/v2              direct, slide captcha engine
github.com/xuri/excelize/v2                  direct, user export xlsx writer
golang.org/x/crypto                          direct, bcrypt
gopkg.in/natefinch/lumberjack.v2             direct, log file rotation
gorm.io/driver/mysql                         direct, GORM MySQL driver
gorm.io/gorm                                 direct, repositories
```

`go mod tidy -diff` 初扫显示唯一直接依赖提纯点：

```diff
- golang.org/x/text v0.35.0
+ golang.org/x/text v0.35.0 // indirect
```

项目代码没有直接 import `golang.org/x/text`。它由 `github.com/xuri/excelize/v2` 链路带入。

### gin-gonic/contrib 事实

`https://github.com/gin-gonic/contrib` 是 Gin 社区 middleware 集合，不是“所有子目录都可直接采用”的质量背书。其 README 表达的是 community-contributed middleware，维护责任分散。

典型反例：`gin-gonic/contrib/sessions` 已标记 abandoned，并建议使用 `gin-contrib/sessions`。

结论：

```text
非官方不等于不能用；
官方或 contrib 也不等于可以无脑用；
采用标准必须是 production-grade、当前真需求、维护健康、可验证、可隔离。
```

## 目标

1. 让 `admin_back_go` 的直接依赖保持“只有项目直接使用的包才 direct require”。
2. 明确当前 middleware 链路哪些必须保留、哪些可用优秀开源包替换、哪些禁止引入。
3. 建立后续中间件引入准入标准，避免“为了高级加包”。
4. 写一份长期可维护的中间件选型文档，作为后续 Auth Foundation v2、限流、压缩、指标、追踪的前置规则。
5. 本轮不破坏现有登录、权限、审计、WebSocket、前端 API contract。

## 非目标

本次不做：

```text
不实现 JWT
不实现 OAuth2/OIDC
不替换 AuthToken 主链路
不替换 PermissionCheck / OperationLog
不接入全局限流
不接入全局 timeout
不接入 metrics/tracing runtime
不改前端依赖
不重构业务模块
不删除任何已经被 go mod why 证明为项目直接使用的依赖
```

这次是提纯和定标准，不是把认证系统拆了重写。

## 推荐设计

### 1. 直接依赖提纯规则

`go.mod` direct require 的标准：

```text
项目源码或测试直接 import，保留 direct
只由第三方依赖带入，降为 indirect
没有任何 go mod why 路径，删除
```

本轮允许的实际依赖变更：

```text
golang.org/x/text: direct -> indirect
```

如果 `go mod tidy` 产生额外 diff，必须逐项解释，不允许无脑接受。

### 2. 当前 middleware 保留规则

当前链路先保留：

```text
Recovery          gin 自带，保留
RequestID         保留，后续可评估 gin-contrib/requestid，但不能改变 header/context contract
AccessLog         保留，项目 slog 字段已定；后续可评估 gin-contrib/logger/slog
CORS              保留 gin-contrib/cors，已经是开源实现
AuthToken         保留，不能被 gin-jwt 黑盒替换
PermissionCheck   保留，项目 RBAC 必须显式 RouteKey
OperationLog      保留，项目审计 payload/脱敏/64KB 限制不能丢
```

理由：

```text
AuthToken / PermissionCheck / OperationLog 是业务安全边界，不是纯技术 middleware。
RequestID / AccessLog 已经和项目日志、排障、OperationLog 关联。
CORS 已经采用 gin-contrib/cors，没有必要手写。
```

### 3. 开源中间件候选池

候选池只进入文档，不直接进入 runtime。

#### CORS

当前采用：

```text
github.com/gin-contrib/cors
```

结论：保留。

#### Request ID

候选：

```text
github.com/gin-contrib/requestid
```

采用前必须满足：

```text
响应头仍是 X-Request-Id
gin.Context key 不破坏 GetRequestID(c)
已有 request_id 测试通过
AccessLog / OperationLog 字段不变
```

第一轮不替换。

#### Access Logger

候选：

```text
github.com/gin-contrib/logger
github.com/gin-contrib/slog
```

采用前必须满足：

```text
保留 request_id/method/path/status/latency_ms/client_ip
不记录 body
不记录完整 query string
输出仍进入项目 slog logger
不影响 platform/logging 文件轮转
```

第一轮不替换。

#### Compression

候选：

```text
github.com/gin-contrib/gzip
```

采用条件：

```text
只作用普通 HTTP response
不影响 /api/admin/v1/realtime/ws
不压缩已经是二进制或流式的响应
可通过配置开关关闭
有 benchmark 或 smoke 证明没有破坏前端
```

本次不引入。后续可作为独立小切片。

#### Rate Limit

候选方向：

```text
golang.org/x/time/rate      # 本机内存限流
Redis-backed limiter        # 分布式登录/验证码限流
```

采用条件：

```text
只先保护 /auth/login /auth/send-code /auth/forgot-password /auth/captcha
不能全局限流后台 API
错误响应必须保持统一 envelope
分布式部署前优先 Redis-backed
```

本次不引入。后续作为 Auth Foundation v2 的安全切片。

#### JWT / Auth

候选：

```text
github.com/appleboy/gin-jwt
golang-jwt/jwt/v5
gin-gonic/contrib/jwt
```

结论：

```text
不允许任何 gin JWT middleware 直接接管登录态。
JWT 只能作为后续 AccessTokenCodec 的一种实现。
session.Authenticator 仍负责 user_sessions / auth_platforms / Redis / policy。
```

这部分必须进入 `Auth Foundation v2`，不属于本轮提纯。

#### Sessions

候选：

```text
github.com/gin-contrib/sessions
```

结论：

```text
不采用作为 admin 登录态主方案。
```

原因：

```text
当前 admin 已有 user_sessions 表、refresh token、revoke、kick、single-session、max-sessions。
cookie session store 不能替代项目 session domain。
gin-gonic/contrib/sessions 已 abandoned，禁止采用。
```

#### Metrics

候选：

```text
Prometheus middleware
```

采用条件：

```text
指标 endpoint 必须内网或鉴权
不能泄露用户、token、业务 payload
指标 label 不能包含高基数字段如 user_id/session_id/raw path param
```

本次不引入。

#### Tracing

候选：

```text
go.opentelemetry.io/contrib/instrumentation/github.com/gin-gonic/gin/otelgin
```

采用条件：

```text
先保留现有 X-Request-Id
trace id 与 request id 的关系写清楚
不把敏感 header/body 写入 span
exporter 配置必须可关闭
```

本次不引入。

#### Secure Headers

候选：

```text
github.com/gin-contrib/secure
```

采用条件：

```text
先确认前端部署拓扑：Nginx / 1Panel / Tauri / API domain
不要在 API 层误配破坏本地开发或 WebSocket
```

本次不引入。

#### Basic Auth

候选：

```text
gin.BasicAuth
```

采用条件：

```text
只用于 pprof / debug / metrics 这类内部入口
不得用于 admin 用户登录
不得绕过 AuthToken / PermissionCheck 主链路
```

本次不引入。

### 4. 文档产物

新增架构文档：

```text
docs/architecture/06-admin-middleware-selection.md
```

文档必须包含：

```text
当前 middleware 链路
当前直接依赖审计表
保留/可替换/禁止/后续候选分类
开源中间件准入标准
本轮实际变更
后续切片建议
验证命令
```

这份文档是后续引入任何 middleware 的 gate。没有写进候选池和采用标准的包，不允许直接加进 `go.mod`。

## 实施边界

### 允许改动

```text
admin_back_go/go.mod
admin_back_go/go.sum
docs/architecture/06-admin-middleware-selection.md
```

如果 `go mod tidy` 没有改 `go.sum`，不强求。

### 不允许改动

```text
admin_back_go/internal/server/router.go
admin_back_go/internal/middleware/*.go
admin_back_go/internal/module/session/*
admin_back_go/internal/module/auth/*
admin_front_ts/*
database/*
scripts/smoke 逻辑
```

如果后续实现发现必须动上述文件，说明这个 spec 范围不够，必须停下来重新评审。

## 验证策略

### 静态验证

```powershell
cd E:/admin_go/admin_back_go
go mod tidy -diff
go test ./...
go vet ./...
powershell -ExecutionPolicy Bypass -File .\scripts\check-contract.ps1
```

说明：

```text
go mod tidy -diff 用来证明依赖提纯范围。
go test ./... 证明依赖变更没有破坏编译和单测。
go vet ./... 证明 Go 静态基础检查通过。
check-contract.ps1 证明 contract gate 没被文档/路由漂移破坏。
```

### Smoke 验证

如果实现只移动 `golang.org/x/text` direct/indirect 并新增文档，基础 smoke 可作为最终前置建议，不强制每次都跑。

如果实现期间出现任何额外依赖变化，必须跑：

```powershell
cd E:/admin_go
powershell -ExecutionPolicy Bypass -File .\scripts\basic-admin-smoke.ps1 -Account 15671628271 -Password 123456
```

如果触碰 middleware runtime 文件，必须跑：

```powershell
cd E:/admin_go
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account 15671628271 -Password 123456
```

## 成功标准

本轮完成必须满足：

```text
go.mod 中没有无证据 direct dependency
golang.org/x/text 被正确降为 indirect，或能解释为什么不能降
新增中间件选型文档
文档明确禁止 abandoned sessions / 黑盒 JWT 接管 / 全局 timeout / 全局限流
go test ./... 通过
go vet ./... 通过
check-contract.ps1 通过
git diff --check 通过
```

没有这些验证证据，不准说完成。

## 后续切片建议

按风险从低到高：

```text
1. Compression slice：评估 gin-contrib/gzip，只覆盖普通 HTTP
2. Login rate-limit slice：Redis-backed，保护登录/验证码/忘记密码
3. RequestID/AccessLog refinement：评估是否值得替换为 gin-contrib/requestid/logger/slog
4. Metrics slice：Prometheus endpoint，内网/鉴权保护
5. Tracing slice：otelgin，敏感字段屏蔽
6. Auth Foundation v2：双令牌、AccessTokenCodec、refresh rotation、OAuth2/OIDC 预留
```

顺序不能反过来。认证底座是大手术，必须单独 spec + plan。

## Review checklist

实现前 reviewer 必须确认：

```text
是否只做后端 Go 提纯？
是否没有触碰登录/权限/审计 runtime？
是否没有新增未评审 middleware？
是否没有把 contrib 当成质量背书？
是否所有依赖变化都有 go mod why / tidy 证据？
是否验证命令真实跑过？
```

如果任何一项不是明确 yes，不能合并。
