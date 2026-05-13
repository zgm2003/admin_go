# Admin Middleware Selection

状态更新时间：2026-05-13

## 结论

`admin_back_go` 不排斥非官方中间件，也不迷信官方或 contrib 标签。

本项目采用的标准是：

```text
production-grade 优先
当前真需求优先
维护健康优先
可验证优先
可隔离优先
```

中间件不能因为“看起来高级”进入项目。任何新增 middleware 必须先说明解决什么真问题、会破坏什么、如何验证、如何回滚。

## 当前全局 middleware 链路

当前链路由 `admin_back_go/internal/server/router.go` 装配：

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

规则：

```text
Recovery 用 Gin 自带能力。
RequestID、AccessLog、AuthToken、PermissionCheck、OperationLog 是项目边界，不允许被第三方黑盒接管。
CORS 已采用 github.com/gin-contrib/cors。
```

## 当前 middleware 职责

```text
RequestID
  读取或生成 X-Request-Id，写回响应头，写入 gin.Context。

AccessLog
  记录 request_id/method/path/status/latency_ms/client_ip。
  不记录 body，不记录完整 query string，不做业务审计。

CORS
  处理浏览器跨域和 OPTIONS preflight。
  当前用 github.com/gin-contrib/cors。

AuthToken
  解析 Authorization: Bearer <token>。
  只在显式 GET/HEAD path 允许 cookie access_token。
  把 token/platform/device-id/client-ip 交给 session authenticator。
  不签发 token，不查 RBAC，不直接拼 Redis key。

PermissionCheck
  按显式 RouteKey(method + path) 查权限码。
  从 AuthToken 挂载的 AuthIdentity 读取身份。
  把检查交给注入的 PermissionChecker。

OperationLog
  按显式 RouteKey(method + path) 查审计规则。
  在 handler 后收集请求/响应摘要、状态、耗时。
  把记录交给 OperationRecorder。
```

## 直接依赖准入标准

`admin_back_go/go.mod` direct require 必须满足：

```text
项目源码或测试直接 import，保留 direct。
只由第三方依赖带入，必须是 indirect。
没有 go mod why 路径，删除。
```

本次提纯发现：

```text
golang.org/x/text 没有项目源码直接 import。
它由 github.com/xuri/excelize/v2 带入。
因此它应是 indirect require。
```

## 当前直接依赖审计

```text
github.com/gin-contrib/cors                  CORS middleware
github.com/gin-gonic/gin                     HTTP core
github.com/go-co-op/gocron/v2                scheduler wrapper
github.com/go-pay/gopay                      Alipay gateway
github.com/go-playground/validator/v10       request validation
github.com/golang-jwt/jwt/v5                 JWT access-token codec only; Gin JWT middleware is not used
github.com/go-sql-driver/mysql               MySQL driver and MySQL error type
github.com/gorilla/websocket                 realtime WebSocket
github.com/hibiken/asynq                     task queue
github.com/hibiken/asynqmon                  queue monitor UI
github.com/joho/godotenv                     local .env loading
github.com/redis/go-redis/v9                 Redis cache/queue/realtime/session support
github.com/robfig/cron/v3                    cron expression parsing
github.com/tencentyun/cos-go-sdk-v5          COS object writer
github.com/tencentyun/qcloud-cos-sts-sdk     COS STS signer
github.com/wenlng/go-captcha-assets          captcha assets
github.com/wenlng/go-captcha/v2              captcha engine
github.com/xuri/excelize/v2                  xlsx export
golang.org/x/crypto                          bcrypt
gopkg.in/natefinch/lumberjack.v2             log rotation
gorm.io/driver/mysql                         GORM MySQL driver
gorm.io/gorm                                 repositories
```

## Open-source middleware candidate pool

候选池只是后续评估入口，不代表本轮采用。

### Keep now

```text
github.com/gin-contrib/cors
```

原因：当前 CORS 已经使用成熟开源实现，配置由项目 `config.CORSConfig` 控制。

### Evaluate later

```text
github.com/gin-contrib/requestid
github.com/gin-contrib/logger
github.com/gin-contrib/slog
github.com/gin-contrib/gzip
github.com/gin-contrib/secure
go.opentelemetry.io/contrib/instrumentation/github.com/gin-gonic/gin/otelgin
Prometheus middleware
Redis-backed rate limiter
gin-contrib/jwt or other JWT middleware
```

采用前必须写独立 plan，并证明：

```text
现有 response envelope 不变。
现有 X-Request-Id 不变。
现有 AuthIdentity 不变。
现有 OperationLog 审计字段不丢。
WebSocket upgrade 不被破坏。
basic/full smoke 通过。
```

### Explicitly forbidden without a separate auth spec

```text
任何 gin JWT middleware 直接接管 admin 登录态
任何 cookie session package 替代 user_sessions
全局 timeout middleware
全局 API rate limit
gin-gonic/contrib/sessions
```

原因：

```text
admin 登录态已经有 user_sessions、refresh token、踢下线、单端登录、最大会话数、platform/device/IP policy。
JWT 只作为 internal/platform/accesstoken codec，不是认证架构本身。
gin-gonic/contrib/sessions 已 abandoned，不能采用。
全局 timeout 会误伤 WebSocket、AI stream、支付回调。
全局 rate limit 会误伤后台正常操作。
```

## 后续切片顺序

按风险从低到高：

```text
1. Compression：gin-contrib/gzip，仅普通 HTTP response。
2. Login rate limit：Redis-backed，只保护 login/captcha/send-code/forgot-password。
3. RequestID/AccessLog refinement：评估 requestid/logger/slog 是否真有收益。
4. Metrics：Prometheus endpoint，内网或鉴权。
5. Tracing：otelgin，敏感字段屏蔽，可关闭 exporter。
6. OAuth2/OIDC callback foundation：后续只负责把外部身份换成本系统 user_sessions + token pair。
```

认证底座已由 Auth Foundation v2 收口：APP_SECRET + HKDF 派生 key、JWT access token、opaque refresh token、user_sessions 真相源。后续 OAuth2/OIDC 不得绕过这条登录态边界。

## 验证门槛

每次依赖或 middleware 变更至少运行：

```powershell
cd E:/admin_go/admin_back_go
go mod tidy -diff
go test ./...
go vet ./...
powershell -ExecutionPolicy Bypass -File .\scripts\check-contract.ps1
git diff --check
```

如果触碰 runtime middleware 文件，必须额外运行：

```powershell
cd E:/admin_go
powershell -ExecutionPolicy Bypass -File .\scripts\basic-admin-smoke.ps1 -Account 15671628271 -Password 123456
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account 15671628271 -Password 123456
```

没有验证证据，不准说完成。
