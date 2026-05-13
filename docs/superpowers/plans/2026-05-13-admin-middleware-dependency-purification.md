# Admin Middleware and Dependency Purification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Purify `admin_back_go` backend middleware/dependency boundaries by accepting only proven `go mod tidy` dependency changes and documenting the open-source middleware selection gate.

**Architecture:** Keep the runtime middleware chain unchanged. Apply the minimal module dependency cleanup proven by `go mod tidy`, then add an architecture decision document that classifies current middleware, retained dependencies, allowed future candidates, and forbidden shortcuts.

**Tech Stack:** Go modules, Gin, existing `internal/middleware`, PowerShell validation scripts, Markdown architecture docs.

---

## Source Spec

Read first:

```text
E:/admin_go/docs/superpowers/specs/2026-05-13-admin-middleware-dependency-purification-design.md
```

Non-negotiable constraints from the spec:

```text
Do not touch runtime middleware code in this slice.
Do not implement JWT/OAuth2/OIDC in this slice.
Do not touch frontend dependencies in this slice.
Only accept go.mod/go.sum changes with go mod why / go mod tidy evidence.
Keep AuthToken -> PermissionCheck -> OperationLog semantics intact.
```

## File Structure

### Modify

```text
E:/admin_go/admin_back_go/go.mod
E:/admin_go/admin_back_go/go.sum
```

Responsibility:

```text
Reflect only the dependency graph normalization produced by go mod tidy. Expected change: golang.org/x/text moves from direct require to indirect require. go.sum may remain unchanged.
```

### Create

```text
E:/admin_go/docs/architecture/06-admin-middleware-selection.md
```

Responsibility:

```text
Long-lived architecture gate for middleware and dependency decisions: current chain, direct dependency audit, open-source candidate pool, forbidden packages/patterns, future slices, and validation requirements.
```

### No runtime files

Do not modify:

```text
E:/admin_go/admin_back_go/internal/server/router.go
E:/admin_go/admin_back_go/internal/middleware/*.go
E:/admin_go/admin_back_go/internal/module/session/*
E:/admin_go/admin_back_go/internal/module/auth/*
E:/admin_go/admin_front_ts/*
```

---

## Task 1: Normalize Go Direct Dependencies

**Files:**

- Modify: `E:/admin_go/admin_back_go/go.mod`
- Maybe modify: `E:/admin_go/admin_back_go/go.sum`

- [ ] **Step 1: Reconfirm the current module diff**

Run:

```powershell
cd E:/admin_go/admin_back_go
go mod tidy -diff
```

Expected decisive diff:

```diff
-	golang.org/x/text v0.35.0
+	golang.org/x/text v0.35.0 // indirect
```

If `go mod tidy -diff` shows any additional direct dependency deletion/addition, stop and inspect it with:

```powershell
go mod why -m <module>
rg -n "<module import path>" . -g "*.go" -g "!runtime/**"
```

- [ ] **Step 2: Apply the module normalization**

Run:

```powershell
cd E:/admin_go/admin_back_go
go mod tidy
```

Expected:

```text
go.mod updated so golang.org/x/text is indirect.
go.sum either unchanged or normalized by Go.
```

- [ ] **Step 3: Inspect dependency diff only**

Run:

```powershell
cd E:/admin_go/admin_back_go
git diff -- go.mod go.sum
```

Expected:

```text
Only dependency graph normalization is present.
No version downgrades/upgrades unless go mod tidy requires them.
No unrelated file changes.
```

- [ ] **Step 4: Verify direct-import truth for x/text**

Run:

```powershell
cd E:/admin_go/admin_back_go
rg -n "golang.org/x/text" . -g "*.go" -g "!runtime/**"
go mod why -m golang.org/x/text
```

Expected:

```text
rg returns no project Go source imports.
go mod why shows the module is reached through github.com/xuri/excelize/v2.
```

Do not commit yet. Commit after Task 2 so doc and dependency evidence land together.

---

## Task 2: Add Middleware Selection Architecture Gate

**Files:**

- Create: `E:/admin_go/docs/architecture/06-admin-middleware-selection.md`

- [ ] **Step 1: Create the architecture document**

Create `E:/admin_go/docs/architecture/06-admin-middleware-selection.md` with this content:

````markdown
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
golang-jwt/jwt/v5 as a codec library
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
JWT 只能作为后续 AccessTokenCodec，不是认证架构本身。
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
6. Auth Foundation v2：双令牌、AccessTokenCodec、refresh rotation、OAuth2/OIDC 预留。
```

认证底座必须单独 spec + plan，不得混入普通依赖提纯。

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
````

- [ ] **Step 2: Check the architecture document**

Run:

```powershell
cd E:/admin_go
Select-String -LiteralPath .\docs\architecture\06-admin-middleware-selection.md -Pattern 'TBD|TODO|FIXME|待定' -CaseSensitive:$false
git diff --check -- docs/architecture/06-admin-middleware-selection.md
```

Expected:

```text
No placeholder matches.
git diff --check has no output.
```

---

## Task 3: Verify Backend After Purification

**Files:**

- Verify: `E:/admin_go/admin_back_go/go.mod`
- Verify: `E:/admin_go/admin_back_go/go.sum`
- Verify: `E:/admin_go/docs/architecture/06-admin-middleware-selection.md`

- [ ] **Step 1: Run Go unit tests**

Run:

```powershell
cd E:/admin_go/admin_back_go
go test ./...
```

Expected:

```text
All packages pass.
```

- [ ] **Step 2: Run Go vet**

Run:

```powershell
cd E:/admin_go/admin_back_go
go vet ./...
```

Expected:

```text
No vet diagnostics.
```

- [ ] **Step 3: Run contract gate**

Run:

```powershell
cd E:/admin_go/admin_back_go
powershell -ExecutionPolicy Bypass -File .\scripts\check-contract.ps1
```

Expected:

```text
Contract check passes.
```

- [ ] **Step 4: Run whitespace diff check**

Run:

```powershell
cd E:/admin_go
git diff --check
git -C E:/admin_go/admin_back_go diff --check
```

Expected:

```text
No output.
```

- [ ] **Step 5: Inspect final diff**

Run:

```powershell
cd E:/admin_go
git status --short
git diff -- docs/architecture/06-admin-middleware-selection.md
git -C E:/admin_go/admin_back_go status --short
git -C E:/admin_go/admin_back_go diff -- go.mod go.sum
```

Expected:

```text
Meta repo only has docs/architecture/06-admin-middleware-selection.md.
admin_back_go only has go.mod and maybe go.sum.
No runtime source files changed.
```

---

## Task 4: Commit Changes

**Files:**

- Commit in `E:/admin_go/admin_back_go`: `go.mod`, maybe `go.sum`
- Commit in `E:/admin_go`: `docs/architecture/06-admin-middleware-selection.md`, this plan if uncommitted

- [ ] **Step 1: Commit backend dependency normalization**

Run:

```powershell
cd E:/admin_go/admin_back_go
git status --short
git add go.mod go.sum
git commit -m "chore: tidy backend module dependencies"
```

Expected:

```text
Commit succeeds if go.mod/go.sum changed.
If only go.mod changed, git add go.sum is harmless when go.sum exists but unchanged.
```

If there are no backend changes, skip this commit and record:

```text
go mod tidy produced no backend diff.
```

- [ ] **Step 2: Commit meta architecture docs and plan**

Run:

```powershell
cd E:/admin_go
git status --short
git add docs/architecture/06-admin-middleware-selection.md docs/superpowers/plans/2026-05-13-admin-middleware-dependency-purification.md
git commit -m "docs: add middleware selection gate"
```

Expected:

```text
Commit succeeds.
```

- [ ] **Step 3: Final status**

Run:

```powershell
git -C E:/admin_go status --short
git -C E:/admin_go/admin_back_go status --short
git -C E:/admin_go/admin_front_ts status --short
```

Expected:

```text
All three working trees are clean.
```

## Self-review checklist

Before claiming completion:

```text
Spec coverage: dependency normalization, architecture gate, candidate pool, forbidden middleware, validation commands.
No placeholder wording in plan/doc.
No runtime files changed.
No frontend files changed.
No unverified success claims.
```
