# Auth 平台 transport 边界规范化设计

日期：2026-05-31
状态：draft for review
范围：`admin_back_go/internal/module/auth` 后端 transport 边界；不包含前端 UI 改造、不包含数据库字段新增。

## 0. Linus 三问

1. 这是个真问题吗？
   是。当前 `/api/canvas/v1/auth/*` 虽然能跑，但由 `auth/transport/app` 通过可变 `Prefix + Platform` 注册出来。运行正确不代表架构正确；代码阅读者会看到 canvas 入口藏在 app transport 里，平台线索断掉。
2. 有更简单的方法吗？
   有。不要发明复杂路由工厂，也不要把 canvas 复制成新业务模块。保留共享 service，把 HTTP 入口拆回 `transport/{platform}`，每个平台包显式注册自己的 prefix 和 platform。
3. 会破坏已有用户吗？
   不允许。URL、请求体、响应体、token、captcha、send-code、login-config 行为必须保持兼容；这是内部边界重构，不改外部 contract。

## 1. 当前坏味道

当前真实代码链路：

```go
// internal/server/routes_auth.go
authapp.Register(router, authapp.RouteOptions{
    Prefix:   "/api/app/v1/auth",
    Platform: enum.PlatformApp,
})

authapp.Register(router, authapp.RouteOptions{
    Prefix:   "/api/canvas/v1/auth",
    Platform: enum.PlatformCanvas,
})
```

`auth/transport/app` 的 `Register` 接受动态 `Prefix` 和动态 `Platform`，因此一个名叫 app 的 transport 包同时注册 app 和 canvas 两个平台。

这违反项目多平台规则的精神：

```text
platform = 业务入口：admin / app / canvas / openapi / merchant / miniapp
transport = internal/module/{capability}/transport/{platform}/
新增平台 = 在相关 module 增加 transport/{new_platform}/ + bootstrap 显式 Register
```

当前问题不是业务逻辑重复，而是入口线索被隐藏：

```text
浏览器 /api/canvas/v1/auth/login-config
  -> canvas_front_next Next proxy
  -> Go /api/canvas/v1/auth/login-config
  -> server/routes_auth.go
  -> auth/transport/app.Register(Prefix=/api/canvas/v1/auth, Platform=canvas)
  -> auth service LoginConfig(platform=canvas)
```

从 URL 看是 canvas，从 transport 目录看却是 app。新接手的人会误判 canvas 没有 auth transport，或者误以为 app transport 是一个通用前台网关。这就是垃圾边界。

## 2. 设计目标

### 2.1 必须做到

- 每个平台入口必须有自己的 transport 包。
- `server/routes_*.go` 只能调用对应平台 transport 的 `Register`。
- 平台 URL prefix 不从 server 传入，不做动态重定向式注册。
- 平台常量不从外部随意传入；app 包固定 app，canvas 包固定 canvas。
- 业务复用留在 service / repository / shared policy，不藏在错误命名的 transport 里。
- 外部 API contract 不变。
- 架构测试必须能防止以后再出现 `authapp.Register(... canvas ...)` 这种写法。

### 2.2 不做什么

- 不新增 `module/canvasauth`、`module/appauth` 这种平台前缀业务模块。
- 不复制 auth service、captcha service、session service。
- 不改 `auth_platforms` 表结构。
- 不改 `/api/app/v1/auth/*` 或 `/api/canvas/v1/auth/*` URL。
- 不把 canvas auth 塞回 admin transport。
- 不新增隐式 fallback、兼容别名、长期迁移桥。

## 3. 推荐方案

### 方案 A：每个平台独立 transport，service 继续复用（推荐）

目录：

```text
internal/module/auth/transport/
  admin/
    route.go
    handler.go
    request.go
    presenter.go
  app/
    route.go
    handler.go
    request.go
    presenter.go
  canvas/
    route.go
    handler.go
    request.go
    presenter.go
```

注册：

```go
// internal/server/routes_auth.go
authadmin.Register(router, ...)
authapp.Register(router, authapp.Options{...})
authcanvas.Register(router, authcanvas.Options{...})
```

`app.Register` 内部固定：

```go
const prefix = "/api/app/v1/auth"
const platform = enum.PlatformApp
```

`canvas.Register` 内部固定：

```go
const prefix = "/api/canvas/v1/auth"
const platform = enum.PlatformCanvas
```

优点：

- 路由线一眼可读。
- 新平台照模板加包，不污染旧平台。
- 共享业务逻辑仍在 `auth.Service`。
- 少量 transport 重复是可接受的，换来清晰边界。

缺点：

- app/canvas handler 会有一些薄重复代码。

判断：这点重复不是坏事。错误抽象比重复更糟。

### 方案 B：`transport/client` 通用包 + app/canvas 薄 wrapper

目录：

```text
transport/client/
transport/app/
transport/canvas/
```

缺点：`client` 又会变成新的“伪平台”，继续模糊 transport 语义。除非以后有 4 个以上前台平台且重复已经真实失控，否则现在不做。

### 方案 C：保留当前 `transport/app` 动态 Prefix+Platform

缺点：这就是当前问题。能跑，但可读性差，长期多平台会烂掉。不采用。

## 4. 目标架构

### 4.1 平台入口三件套

每个平台入口必须同时明确三件事：

```text
1. URL prefix：/api/{platform}/v1/auth
2. transport 包：internal/module/auth/transport/{platform}
3. service Platform 入参：enum.Platform{PlatformName}
```

三者必须在同一个平台包里绑定，不允许在 `server/routes_auth.go` 动态拼接。

### 4.2 app transport

`internal/module/auth/transport/app` 只服务 app：

```text
GET  /api/app/v1/auth/login-config
GET  /api/app/v1/auth/captcha
POST /api/app/v1/auth/send-code
POST /api/app/v1/auth/login
POST /api/app/v1/auth/logout
```

行为：

```text
LoginConfig -> AuthService.LoginConfig(platform=app)
Login       -> AuthService.Login(platform=app)
User init   -> UserService.Init(platform=app)
Token check -> bearer token platform 必须匹配 app
```

### 4.3 canvas transport

`internal/module/auth/transport/canvas` 只服务 canvas：

```text
GET  /api/canvas/v1/auth/login-config
GET  /api/canvas/v1/auth/captcha
POST /api/canvas/v1/auth/send-code
POST /api/canvas/v1/auth/login
POST /api/canvas/v1/auth/logout
```

行为：

```text
LoginConfig -> AuthService.LoginConfig(platform=canvas)
Login       -> AuthService.Login(platform=canvas)
User init   -> UserService.Init(platform=canvas)
Token check -> bearer token platform 必须匹配 canvas
```

### 4.4 admin transport 保持独立

`internal/module/auth/transport/admin` 不参与 app/canvas 重构。admin 仍然有后台专属行为：

```text
login-config 可按 admin platform header 查询
session admin / login log 等后台管理面仍在 admin transport
operation log / RBAC 规则仍按 admin 路径执行
```

## 5. 代码结构设计

### 5.1 server 注册层

目标：server 只表达“注册哪个平台”，不传 prefix，不传 platform。

```go
func registerAuthRoutes(router *gin.Engine, deps Dependencies) {
    authadmin.Register(router, deps.AuthService, deps.CaptchaService, deps.SessionAdminService, deps.LoginLogService)
    authapp.Register(router, authapp.Dependencies{
        AuthService:    deps.AuthService,
        CaptchaService: deps.CaptchaService,
        UserService:    deps.UserService,
    })
    authcanvas.Register(router, authcanvas.Dependencies{
        AuthService:    deps.AuthService,
        CaptchaService: deps.CaptchaService,
        UserService:    deps.UserService,
    })
}
```

禁止：

```go
authapp.Register(router, RouteOptions{Prefix: "/api/canvas/v1/auth", Platform: "canvas"})
```

### 5.2 platform route.go

每个平台包的 `route.go` 必须显式列完整路由：

```go
const routePrefix = "/api/canvas/v1/auth"

func Register(router *gin.Engine, deps Dependencies) {
    validate.MustRegister()
    handler := NewHandler(deps)
    group := router.Group(routePrefix)
    group.GET("/login-config", handler.LoginConfig)
    group.GET("/captcha", handler.Captcha)
    group.POST("/send-code", handler.SendCode)
    group.POST("/login", handler.Login)
    group.POST("/logout", handler.Logout)
}
```

重点：route.go 不接受 prefix 参数，不接受 platform 参数。

### 5.3 platform handler.go

每个平台 handler 内部固定平台：

```go
const platform = enum.PlatformCanvas
```

或：

```go
func (h *Handler) platform() string { return enum.PlatformCanvas }
```

允许 app/canvas handler 有薄重复，重复范围只限 HTTP 表面：bind request、调用 service、present response。

不允许复制：

```text
auth.Service 登录逻辑
captcha verification
session create/logout
verify-code send/cache policy
user repository
```

### 5.4 request / presenter

每个平台可保留自己的 request/presenter 文件，即使字段目前相同。

原因：平台响应将来可能分化，比如：

```text
app 返回 mobile profile fields
canvas 返回 wallet summary / canvas role hint
merchant 返回 tenant info
openapi 返回 client app info
```

如果提前把 request/presenter 抽成“万能前台”，之后改动会变成条件分支地狱。

### 5.5 service 层

`internal/module/auth/service.go` 不绑定平台包。service 只接受显式 `Platform` 输入：

```text
LoginConfig(ctx, platform)
Login(ctx, LoginInput{Platform: platform})
Logout(ctx, token)
SendCode(ctx, input)
```

service 不允许依赖 gin.Context，不允许自己判断 URL prefix。

## 6. Auth 以外的同类问题

本 spec 先修 auth，因为它已经暴露问题。但同一规则必须覆盖其它 canvas/app 当前用户入口：

```text
profile/users current-user
upload-token
payment current-user wallet/recharge
canvas prompt/asset/settings/AI
notification current-user
```

判断标准：

```text
如果 URL 是 /api/canvas/v1/...，对应能力必须有 transport/canvas 或明确的 canvas capability transport。
如果 URL 是 /api/app/v1/...，对应能力必须有 transport/app。
不能用 app transport 动态注册 canvas prefix。
```

本轮后端修复优先级：

```text
P0 auth transport 拆分：当前用户直接质疑、影响登录链路理解
P1 profile/users current-user canvas/app 注册检查
P2 payment wallet/recharge canvas thin route 检查
P3 architecture guard 扫全仓，禁止动态 Prefix+Platform 跨平台复用
```

## 7. 路由线规范

每条路由必须能按下面顺序追踪：

```text
URL
-> internal/server/routes_{capability}.go
-> internal/module/{capability}/transport/{platform}/route.go
-> internal/module/{capability}/transport/{platform}/handler.go
-> internal/module/{capability}/service.go
-> repository / infra
```

禁止出现：

```text
URL 是 canvas，但 transport 是 app
URL 是 app，但 transport 是 canvas
server 传 Prefix 到错误命名的 transport
handler 从 header/query 里猜当前平台
service 通过 URL 推断平台
```

## 8. 测试设计

### 8.1 RED：架构测试先失败

新增或扩展：

```text
admin_back_go/internal/architecture/platform_transport_boundary_test.go
```

断言：

```text
1. internal/module/auth/transport/canvas/route.go 存在
2. internal/module/auth/transport/canvas/handler.go 存在
3. internal/server/routes_auth.go 必须 import authcanvas
4. routes_auth.go 不允许出现 Prefix: "/api/canvas/v1/auth" 传给 authapp.Register
5. auth/transport/app 文件内容不允许包含 "/api/canvas/v1"
6. auth/transport/canvas 文件内容必须包含 "/api/canvas/v1/auth"
7. auth/transport/app 文件内容必须包含 "/api/app/v1/auth"
```

先跑：

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture -run "AuthTransport|PlatformTransport" -count=1
```

期望 RED：当前没有 `auth/transport/canvas`，会失败。

### 8.2 GREEN：路由行为测试

扩展已有 server/router tests：

```text
GET /api/app/v1/auth/login-config  -> fake auth service receives platform=app
GET /api/canvas/v1/auth/login-config -> fake auth service receives platform=canvas
POST /api/app/v1/auth/login -> LoginInput.Platform=app
POST /api/canvas/v1/auth/login -> LoginInput.Platform=canvas
GET /api/canvas/v1/users/me -> token Platform=canvas
```

重点不是 URL 是否 200，而是 platform 入参是否正确流入 service。

### 8.3 回归测试命令

后端最小验证：

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture ./internal/module/auth/transport/app ./internal/module/auth/transport/canvas ./internal/server -run "AuthTransport|Canvas|AppPlatform|LoginConfig|AuthRoutes" -count=1
```

后端扩展验证：

```powershell
go test ./internal/module/auth ./internal/module/auth/transport/... ./internal/middleware ./internal/server ./internal/architecture -count=1
```

治理验证：

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

## 9. 迁移步骤

### Step 1：写失败测试

先写 architecture guard，确认当前坏结构失败。

失败证据必须明确指向：

```text
missing internal/module/auth/transport/canvas
routes_auth.go registers canvas through authapp.Register
```

### Step 2：创建 canvas transport 包

新增：

```text
admin_back_go/internal/module/auth/transport/canvas/route.go
admin_back_go/internal/module/auth/transport/canvas/handler.go
admin_back_go/internal/module/auth/transport/canvas/request.go
admin_back_go/internal/module/auth/transport/canvas/presenter.go
admin_back_go/internal/module/auth/transport/canvas/handler_test.go
```

初始实现可以从 app transport 拷贝后改平台常量。拷贝不是问题，错误抽象才是问题。

### Step 3：收紧 app transport

修改 `auth/transport/app`：

```text
删除 Prefix 字段
删除 Platform 字段
Register 内固定 /api/app/v1/auth
handler 内固定 enum.PlatformApp
错误信息从 auth app route prefix 改成 auth app dependencies 等真实含义
```

### Step 4：修改 server 注册

`routes_auth.go` 改成：

```text
authapp.Register(...)
authcanvas.Register(...)
```

不再给 app transport 传 canvas prefix。

### Step 5：补 canvas transport handler tests

canvas 包自己的 tests 证明：

```text
login-config 强制 platform=canvas
login 强制 platform=canvas
send-code/captcha/logout 路由存在
request bind 失败返回统一错误
```

### Step 6：跑验证并同步 docs

同步：

```text
docs/contracts/admin-api-v1.md
docs/status/current-status.md
docs/status/module-matrix.md
docs/testing/smoke-matrix.md
```

只写 verified 的事实，不把未跑的验证写成已通过。

## 10. 验收标准

代码结构：

```text
auth/transport/app 不再注册 canvas
auth/transport/canvas 存在并注册 canvas
server/routes_auth.go 清楚显示 app + canvas 两条入口线
```

运行行为：

```text
/api/app/v1/auth/login-config 仍返回 app login-config
/api/canvas/v1/auth/login-config 仍返回 canvas login-config
/api/canvas/v1/auth/send-code 仍可用
/api/canvas/v1/auth/login password/code 登录语义不变
401/403 中间件行为不变
```

测试：

```text
architecture guard 能防止错误复用 app transport 注册 canvas
server route tests 能证明 platform 入参正确
module auth tests 通过
root governance 通过
```

文档：

```text
contract 说明 canvas auth ownership 是 auth/transport/canvas
current-status 不再说 canvas 复用 app transport
module-matrix 记录后端 transport 拆分完成后事实
```

## 11. 后续平台接入模板

以后新增 `merchant` 平台时，不允许复制当前坏做法。模板固定：

```text
internal/shared/enum/platform.go 增加 PlatformMerchant
internal/module/auth/transport/merchant/route.go
internal/module/auth/transport/merchant/handler.go
internal/module/auth/transport/merchant/request.go
internal/module/auth/transport/merchant/presenter.go
internal/server/routes_auth.go 增加 authmerchant.Register
middleware skip paths 增加 /api/merchant/v1/auth/login-config|captcha|send-code|login
permission allowed platforms 增加 merchant，如果该平台需要 RBAC
contract/status/smoke 文档同步
architecture guard 增加 merchant 断言
```

新增平台不是改一个 Prefix 参数；新增平台就是新增平台 transport 包。

## 12. 自检

- 没有新增平台业务模块。
- 没有改变外部 URL。
- 没有引入动态路由工厂。
- 没有把复用逻辑藏到错误命名的 app transport。
- 每条平台路由都能按 URL -> server -> transport/{platform} -> handler -> service 追踪。
- 允许少量薄 transport 重复，以换取平台边界清楚。
