# Platform Scope Adapter Architecture Design

状态：discussion draft for architecture review  
日期：2026-05-24  
范围：`admin_back_go` 多端 API 入口、平台差异、业务模块复用、Docker-first 运行时命名

## 1. 背景

当前 Go 后端已经同时服务两个 HTTP scope：

```text
/api/admin/v1  # 后台管理端
/api/app/v1    # 用户 App / To C 端
```

`admin_app` 登录切片新增了 `/api/app/v1/auth/*`，后端当前通过 `internal/module/appauth` 暴露 App 登录入口。这个切片本身已经复用了 `auth.Service`，没有重新实现一套账号校验、验证码、session 创建逻辑。

但这个命名和目录形态暴露了一个更大的架构风险：

```text
今天新增 appauth，
明天接 App AI 就可能新增 appai，
后天新增 xx 平台就可能新增 xxauth / xxai / xxwallet。
```

这不是 Go 代码风格问题，而是业务边界问题。平台不同不应导致业务模块复制。入口和出参可以不同，业务逻辑必须复用。

## 2. 结论

本项目后端应采用：

```text
Platform Scope Adapter
```

核心原则：

```text
平台 scope 是 HTTP 入口边界，不是业务模块边界。
业务模块按业务能力命名，不按平台命名。
平台差异只允许出现在 route / handler / presenter / policy 层。
service / repository / model 不因 admin/app/xx 平台复制。
```

标准调用链：

```text
/api/admin/v1/...  -> admin handler -> shared service -> repository/model -> admin presenter
/api/app/v1/...    -> app handler   -> shared service -> repository/model -> app presenter
```

不允许的方向：

```text
adminauth + appauth + xxauth 各自一套业务
adminai + appai + xxai 各自一套业务
adminwallet + appwallet + xxwallet 各自一套业务
```

允许的方向：

```text
auth       # 登录、验证码、token、session 策略
aichat     # AI 会话、消息、模型调用、工具/RAG 编排
wallet     # 钱包、余额、流水、消费
upload     # 上传 token、COS 运行时能力

admin/app 只作为这些模块的入口和出参投影。
```

## 3. 当前事实

### 3.1 App auth 不是第二套 auth 业务

当前 `appauth` 做了三件事：

```text
1. 注册 /api/app/v1/auth/* 路由。
2. 将 platform 固定为 app，不信任前端 header。
3. 将 auth/user/upload 的共享 service 响应裁剪为 App 需要的出参。
```

真实认证逻辑仍在：

```text
admin_back_go/internal/module/auth/service.go
```

`auth.Service.Login` 已经接收 `LoginInput.Platform`，并通过 `authplatform.Service` 读取平台策略：

```text
login_types
captcha_type
allow_register
access_ttl
refresh_ttl
single_session / max_sessions
```

这说明当前方向有正确部分：业务逻辑已经初步 platform-aware。

### 3.2 当前坏味道

坏味道不是“已经复制业务”，而是：

```text
appauth 这个模块名容易让后续实现者误以为“每个平台都需要一个业务模块”。
```

如果不立规矩，后续 AI、wallet、payment、notification 都可能被平台名前缀污染。

### 3.3 `APP_NAME=admin-api` 的实际问题

`deploy/docker-first/admin-go.env` 当前包含：

```text
APP_NAME=admin-api
```

但 Docker-first Compose 使用同一个 `admin-go.env` 启动两个进程：

```text
admin-api
admin-worker
```

运行时代码里，进程身份事实上由入口决定：

```text
cmd/admin-api/main.go     -> logging.ForProcess("admin-api")
cmd/admin-worker/main.go  -> logging.ForProcess("admin-worker")
```

`APP_NAME` 当前主要被加载到 `Config.App.Name`，但没有成为稳定的进程身份来源。把 `APP_NAME=admin-api` 放进共享 runtime env，会造成语义误导：

```text
同一份 env 同时给 admin-api 和 admin-worker 用，
但 APP_NAME 写成 admin-api。
```

这不是立即阻塞的问题，但应在后续 env cleanup 中收口。

## 4. 架构设计

### 4.1 Scope

Scope 是 HTTP 命名空间：

```text
admin
app
```

未来如果有新平台，例如：

```text
partner
merchant
openapi
```

它们也只是新的 HTTP scope 或 API consumer 类型，不自动等于新业务模块。

Scope 决定：

```text
route prefix
public path
auth token 默认 platform
RBAC / permission policy
operation log policy
response presenter
字段可见性
```

Scope 不决定：

```text
是否复制 service
是否复制 repository
是否复制 model
是否复制业务表
```

### 4.2 Platform

Platform 是业务策略参数：

```text
admin
app
```

平台进入 service 的方式应该是显式上下文：

```go
type RequestContext struct {
    UserID   int64
    Platform string
    DeviceID string
    ClientIP string
}
```

或者在现有代码阶段先使用已经存在的输入字段：

```go
auth.LoginInput.Platform
user.InitInput.Platform
session.CreateInput.Platform
```

关键点：不要让 service 从 `gin.Context` 里偷读 header。service 只接收已经解析好的平台语义。

### 4.3 Adapter / Handler

Handler 是 HTTP adapter，职责只有：

```text
解析 path/query/body/header
从 middleware 读取 identity
构造 service input
调用 service
选择 presenter
返回 response
```

Handler 可以按 scope 分开，因为 HTTP 入参和出参可能不同。

例如 auth：

```text
internal/module/auth/
  route_admin.go
  route_app.go
  handler_admin.go
  handler_app.go
  presenter_admin.go
  presenter_app.go
  service.go
  repository.go
```

短期也可以保留：

```text
internal/module/appauth/
```

但必须把它定义为“临时 App Auth HTTP adapter”，不能把它当成 App Auth 业务模块。

### 4.4 Presenter

Presenter 是出参投影层。

同一份 service result，可以投影成不同 scope 响应：

```text
Admin current user:
  user_id
  role
  router
  buttonCodes
  quick_entry
  profile

App current user:
  id
  nickname
  avatar
```

不要让 service 为每个端拼不同 JSON。service 返回稳定业务结果，presenter 裁剪给不同端。

建议命名：

```go
func presentAdminLogin(result *auth.LoginResponse, currentUser *user.InitResponse) adminLoginResponse
func presentAppLogin(result *auth.LoginResponse, currentUser *user.InitResponse) appLoginResponse
```

或按文件拆：

```text
presenter_admin.go
presenter_app.go
```

### 4.5 Policy

不同平台的业务策略应进入独立 policy 或现有配置表：

```text
auth_platforms
permission platform
notification platform
client_versions platform
```

例如 auth：

```text
auth.Service.Login(ctx, input{Platform: "app"})
  -> authplatform.LoginTypes(ctx, "app")
  -> authplatform.CaptchaType(ctx, "app")
  -> session.AuthPolicy(ctx, "app")
```

这是正确方向。

如果未来 App AI 需要不同限制，应该是：

```text
ai policy by platform / scene / agent
```

而不是：

```text
appai.Service
```

## 5. 模块命名规则

### 5.1 业务模块按能力命名

允许：

```text
auth
session
user
wallet
payment
uploadtoken
aichat
aiconversation
aimessage
airun
aitool
aiknowledge
notification
```

禁止新增这类平台名前缀业务模块：

```text
appauth
appai
appwallet
apppayment
adminai
adminwallet
xxauth
xxai
```

例外：如果目录明确是 HTTP adapter，并且有删除/收敛计划，可以临时存在。

### 5.2 临时 adapter 必须有边界说明

如果保留 `appauth`，需要在文档中明确：

```text
appauth = /api/app/v1/auth HTTP adapter only
不拥有 auth 业务规则
不拥有 auth repository
不拥有 auth model
不允许复制 auth service
未来可收敛回 auth/route_app.go + auth/handler_app.go
```

## 6. AI 接入示例

当 App 接 AI，不要做：

```text
internal/module/appai
```

应该做：

```text
internal/module/aichat/
  route_admin.go
  route_app.go
  handler_admin.go
  handler_app.go
  presenter_admin.go
  presenter_app.go
  service.go
  repository.go
```

调用链：

```text
POST /api/admin/v1/ai-conversations/:id/messages
  -> admin handler
  -> aichat.Service.SendMessage(ctx, input{Platform: admin, UserID, ConversationID, Content})
  -> admin presenter

POST /api/app/v1/ai-conversations/:id/messages
  -> app handler
  -> aichat.Service.SendMessage(ctx, input{Platform: app, UserID, ConversationID, Content})
  -> app presenter
```

service 负责：

```text
会话归属校验
消息落库
模型调用
工具调用
知识库检索
run/event/token 记录
扣费或额度检查
```

presenter 负责：

```text
Admin 是否暴露 run monitor / token / debug 字段
App 是否只暴露消息展示字段
```

## 7. Docker-first env 命名规则

### 7.1 当前问题

当前 `admin-go.env` 是共享 runtime env：

```text
admin-api    使用它
admin-worker 使用它
```

所以这里放：

```text
APP_NAME=admin-api
```

不够准确。

### 7.2 建议

短期：

```text
不依赖 APP_NAME 做任何业务判断。
文档标记 APP_NAME 为 legacy / cosmetic。
不要基于 APP_NAME 判断当前进程是 api 还是 worker。
```

中期：

```text
删除 APP_NAME。
保留 APP_ENV / APP_SECRET。
进程身份由 cmd 入口和 Compose service name 决定。
```

如果未来确实需要产品名：

```text
PROJECT_NAME=admin-go
```

如果未来确实需要进程名：

```text
admin-api:
  environment:
    PROCESS_NAME: admin-api

admin-worker:
  environment:
    PROCESS_NAME: admin-worker
```

但当前阶段不建议新增 `PROCESS_NAME`，因为代码已经通过入口明确进程身份。

## 8. 推荐推进路径

### Phase 1：先立规则，不重构运行时代码

目标：

```text
防止 appauth 命名坏味道继续扩散。
防止新 App AI / App wallet 接入时复制业务模块。
```

动作：

```text
1. 在架构文档增加 Platform Scope Adapter 规则。
2. 标记 appauth 是 adapter，不是业务模块。
3. 标记 APP_NAME=admin-api 的语义风险。
```

不做：

```text
不移动现有 appauth 代码。
不改接口路径。
不改数据库。
不影响正在跑的 admin_app 登录切片。
```

### Phase 2：新 App 业务按新规则落地

第一个适合验证的业务可以是：

```text
App AI 会话
App wallet summary
App profile
```

落地时必须证明：

```text
没有新增 appai/appwallet 业务模块。
只新增 app route / handler / presenter。
service 复用已有业务能力。
```

### Phase 3：收敛 appauth

等当前 `admin_app` 登录稳定后，再考虑把：

```text
internal/module/appauth
```

收敛为：

```text
internal/module/auth/route_app.go
internal/module/auth/handler_app.go
internal/module/auth/presenter_app.go
```

这是结构优化，不是功能变化。必须有测试保护：

```text
GET  /api/app/v1/auth/login-config
GET  /api/app/v1/auth/captcha
POST /api/app/v1/auth/send-code
POST /api/app/v1/auth/login
GET  /api/app/v1/users/me
POST /api/app/v1/auth/logout
```

## 9. 会破坏什么

如果按本设计推进，短期不破坏运行时。

可能破坏的点只出现在 Phase 3 结构收敛：

```text
路由漏注册
public skip path 漏配
platform=app 固定逻辑丢失
App 出参误返回 admin RBAC 字段
前端 admin_app contract test 失败
```

因此 Phase 3 必须等当前长任务结束后单独做。

## 10. 验证方式

docs-only 阶段：

```powershell
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

后续代码阶段：

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/auth ./internal/module/appauth ./internal/module/session ./internal/server -count=1
```

如果涉及 AI：

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/aichat ./internal/module/aiconversation ./internal/module/aimessage ./internal/server -count=1
```

如果涉及 `admin_app`：

```powershell
cd E:\admin_go\admin_app
npm run test -- tests/app-auth-api.test.ts tests/session-controller.test.ts
npx vue-tsc -b --pretty false
npm run build:h5
```

## 11. Agent 分工

下一步不应该由一个 agent 全做。

```text
architect
  固定 Platform Scope Adapter 规则和阶段边界。

api-contract
  为 /api/app/v1 的新增业务写清楚入参/出参，不让前后端猜字段。

backend-worker
  按契约实现 app route / handler / presenter，复用 service。

frontend-adapter
  admin_app 只按 /api/app/v1 contract 调用，不直接追后端内部结构。

reviewer
  专查是否出现 appai/appwallet/xxauth 这类平台复制坏味道。
```

## 12. 最终规则

可以直接贴进架构治理文档的规则：

```text
平台 scope 不是业务模块边界。

/api/admin/v1、/api/app/v1 只代表 HTTP 入口、权限策略、出参投影不同。
auth、AI、wallet、upload、notification 等业务能力必须由共享 service 承载。
新增平台时，默认只新增 route / handler / presenter / policy，不新增 app*/admin*/xx* 业务模块。

临时平台 adapter 必须有名字、有边界、有收敛计划；禁止把平台 adapter 演变成第二套业务实现。
```

