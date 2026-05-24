# Platform Scope Adapter Architecture Design

状态：review-ready spec for expert review
日期：2026-05-24
责任 agent：`architect`
范围：`admin_back_go` 多端 API 入口、认证平台策略、业务模块复用、Docker-first `APP_NAME` 清理

## 1. 一句话结论

后端确实需要修正架构口径：

```text
/api/admin/v1 和 /api/app/v1 是 HTTP scope，不是业务模块边界。

auth / AI / wallet / upload / notification 等业务能力必须按 capability 复用 service。
admin/app/partner/merchant 这类差异只允许落在 route / handler / presenter / policy 层。
```

所以：

```text
authplatform 继续和平台联动，但只管认证/会话策略。
APP_NAME=admin-api 应该从共享 Docker-first env 和 Config.App.Name 中清理。
appauth 当前可保留为过渡 adapter，但不能被理解成“App Auth 业务模块”。
```

## 2. Linus 三问

### 2.1 这是真问题吗？

是。

当前新增了 `admin_app` 登录入口，后端出现 `internal/module/appauth`。这次代码没有复制 auth 业务，仍然复用了 `internal/module/auth`，方向不算错；但命名会给后续开发者一个错误暗示：

```text
今天 appauth
明天 appai
后天 appwallet / xxauth / xxai
```

如果不立规则，平台维度会污染业务模块维度，最后变成同一套业务按端复制 N 份。

### 2.2 有更简单的做法吗？

有。不要上微服务，不要上大 DDD，不要为每个平台复制模块。

当前阶段最小正确方案就是：

```text
Platform Scope Adapter
```

也就是共享业务 service，只在 HTTP adapter 和 response presenter 上区分端。

### 2.3 会破坏已有前端、接口、登录和权限吗？

按本 spec 分阶段推进，短期不破坏：

```text
Phase 1 只写架构治理文档。
Phase 2 只清理无实际运行时身份语义的 APP_NAME。
Phase 3 以后新增 App 业务按新规则落地。
Phase 4 才考虑 appauth 结构收敛，且必须有路由和登录测试保护。
```

## 3. 当前项目事实

### 3.1 App auth 已经复用共享 auth service

当前 App auth 路由在：

```text
admin_back_go/internal/module/appauth/route.go
```

它注册：

```text
GET  /api/app/v1/auth/login-config
GET  /api/app/v1/auth/captcha
POST /api/app/v1/auth/send-code
POST /api/app/v1/auth/login
GET  /api/app/v1/users/me
POST /api/app/v1/auth/logout
GET  /api/app/v1/profile
PUT  /api/app/v1/profile
POST /api/app/v1/upload-tokens
```

核心登录逻辑仍在：

```text
admin_back_go/internal/module/auth/service.go
```

`auth.Service.Login` 已接收 `LoginInput.Platform`，并通过 `PlatformConfigProvider` 读取平台认证策略：

```text
LoginTypes(ctx, platform)
CaptchaType(ctx, platform)
AllowRegister(ctx, platform)
session.Create(ctx, Platform: input.Platform)
```

这说明当前问题不是“已经复制业务”，而是“`appauth` 这个目录把 App scope 下的 auth / profile / upload-token adapter 放在了一起，目录命名和治理规则不足”。

### 3.2 authplatform 的职责是认证平台策略，不是全局平台配置中心

当前 `internal/module/authplatform` 管理的是 `auth_platforms`：

```text
login_types
captcha_type
allow_register
access_ttl
refresh_ttl
bind_platform / bind_device / bind_ip
single_session / max_sessions
```

所以它应该继续参与登录、refresh、session 校验、自动注册等认证链路。

但它不应该变成万能平台配置中心。比如 App AI 限流、钱包展示字段、通知推送策略，不应该塞进 `auth_platforms`，而应该由对应 capability 模块拥有自己的 policy：

```text
AI    -> ai policy by platform / scene / agent
wallet -> wallet policy by platform / user / scene
notify -> notification target/platform policy
```

### 3.3 APP_NAME=admin-api 是共享 env 里的错误语义

当前配置读取：

```text
admin_back_go/internal/config/config.go
AppConfig.Name <- envString("APP_NAME", "admin-api")
```

但 Docker-first 运行时同一份 env 同时给两个进程用：

```text
admin-api
admin-worker
```

真实进程身份已经由入口决定：

```text
cmd/admin-api/main.go     -> logging.ForProcess("admin-api")
cmd/admin-worker/main.go  -> logging.ForProcess("admin-worker")
```

所以共享 `admin-go.env` 里写：

```text
APP_NAME=admin-api
```

会误导后续设计：

```text
同一份 env 同时给 api 和 worker 用，却说 APP_NAME 是 admin-api。
```

这不是未来扩展方向，而是应该清掉的历史残留。

## 4. 架构决策：Platform Scope Adapter

### 4.1 定义

```text
Platform Scope Adapter = 多端 HTTP 入口 + 共享业务能力 + 端侧出参投影。
```

标准链路：

```text
/api/admin/v1/... -> admin route/handler -> shared service -> repository/model -> admin presenter
/api/app/v1/...   -> app route/handler   -> shared service -> repository/model -> app presenter
```

### 4.2 Scope 是 HTTP 入口，不是业务模块

Scope 决定：

```text
route prefix
public path
token 默认 platform
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
是否复制数据库表
```

未来如果出现：

```text
partner
merchant
openapi
```

默认也只是新的 HTTP scope 或 consumer 类型，不自动产生 `partnerauth`、`merchantai`、`openapiwallet`。

### 4.3 Platform 是业务策略参数

Platform 应显式进入 service input：

```go
type RequestContext struct {
    UserID   int64
    Platform string
    DeviceID string
    ClientIP string
}
```

当前不用急着新增统一 `RequestContext` 类型，可以先沿用已有输入字段：

```go
auth.LoginInput.Platform
user.InitInput.Platform
session.CreateInput.Platform
```

关键规则：

```text
service 不依赖 gin.Context。
service 不偷读 header。
handler / middleware 解析平台语义后，以明确字段传给 service。
```

### 4.4 Handler 是 adapter

Handler 可以按端分开，因为 HTTP 入参、公开路径和响应字段可能不同。

Handler 只做：

```text
解析 path/query/body/header
从 middleware 读取 identity
构造 service input
调用 service
选择 presenter
返回 response
```

Handler 不做：

```text
复制认证规则
复制 AI runtime
复制钱包余额计算
直接查 DB/Redis
```

### 4.5 Presenter 是出参投影

同一份 service result 可以投影成不同端响应：

```text
Admin current user:
  user_id
  roles
  router
  buttonCodes
  quick_entry
  profile

App current user:
  id
  nickname
  avatar
```

推荐形态：

```text
presenter_admin.go
presenter_app.go
```

或保持私有函数：

```go
func presentAdminLogin(result *auth.LoginResponse, currentUser *user.InitResponse) adminLoginResponse
func presentAppLogin(result *auth.LoginResponse, currentUser *user.InitResponse) appLoginResponse
```

不要让 service 为每个端拼不同 JSON。

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
aiprovider
aiagent
aichat
aiconversation
aimessage
airun
aitool
aiknowledge
notification
```

禁止新增平台名前缀业务模块：

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

### 5.2 例外：明确标注的临时 HTTP adapter

`appauth` 可以作为过渡存在，但必须被定义为：

```text
appauth = /api/app/v1 scope 下 auth / users/me / profile / upload-tokens 的临时 HTTP adapter bundle
不拥有 auth / user / uploadtoken 业务规则
不拥有 repository
不拥有 model
不允许复制 auth / user / uploadtoken service
未来按 capability 收敛回 auth / user / uploadtoken 各自的 app route / handler / presenter
```

这个例外不能扩散成 `appai` / `appwallet`。

## 6. App AI 示例

错误方向：

```text
internal/module/appai
```

正确方向（目标形态；当前 `aichat` 仍是 `route.go` / `handler.go` / `service.go` 等文件，不要求在本 spec 里立刻重命名）：

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

`aichat.Service` 拥有：

```text
会话归属校验
消息落库
模型调用
工具调用
知识库检索
run/event/token 记录
扣费或额度检查
```

Presenter 拥有：

```text
Admin 是否暴露 run monitor / token / debug 字段
App 是否只暴露消息展示字段
```

## 7. Docker-first APP_NAME 决策

### 7.1 不再保留 APP_NAME

推荐删除：

```text
APP_NAME
Config.App.Name
```

保留：

```text
APP_ENV
APP_SECRET
```

理由：

```text
APP_NAME 当前没有提供可靠进程身份。
admin-api / admin-worker 的身份已经由 cmd 入口和 Compose service name 决定。
共享 admin-go.env 不应该写死 admin-api。
```

### 7.2 不新增 PROCESS_NAME

当前不建议新增：

```text
PROCESS_NAME
SERVICE_NAME
```

因为现有代码已经有更可靠来源：

```text
cmd/admin-api/main.go
cmd/admin-worker/main.go
logging.ForProcess("...")
```

如果未来确实需要“产品名”，另开 `PROJECT_NAME=admin-go` 讨论；不要把产品名、进程名、平台名混在 `APP_NAME` 里。

## 8. 分阶段推进

### Phase 1：治理文档先落地

目标：

```text
防止 appauth 命名坏味道扩散。
防止后续 App AI / App wallet 复制业务模块。
明确 authplatform 只管认证/会话策略。
```

动作：

```text
更新 docs/architecture/04-go-backend-framework.md。
更新 docs/architecture/05-development-quality-rules.md。
更新 admin_back_go/docs/architecture.md。
```

不做：

```text
不移动 appauth 代码。
不改接口路径。
不改数据库。
不影响正在跑的 admin_app 登录切片。
```

### Phase 2：清理 APP_NAME

目标：

```text
移除 Config.App.Name 和 Docker-first APP_NAME。
让进程身份回到 cmd entry / Compose service。
```

动作：

```text
删除 AppConfig.Name。
删除 envString("APP_NAME", ...)。
更新 config tests。
删除 admin-go.env.example / admin-go.env 中的 APP_NAME。
更新后端架构文档 env 列表。
```

验证：

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/config -count=1
rg -n "APP_NAME|App\.Name|cfg\.App\.Name" cmd internal deploy docs -S
```

### Phase 3：新增 App 业务按新规则落地

第一个验证场景可以是：

```text
App AI conversation
App wallet summary
App profile
```

验收标准：

```text
没有新增 appai / appwallet 业务模块。
只新增 app route / handler / presenter。
service 复用已有 capability。
API contract 写清楚 app 出参。
```

### Phase 4：可选收敛 appauth

等 `admin_app` 登录稳定、另一个 Codex 长任务结束后，再考虑把：

```text
internal/module/appauth
```

按 capability 拆回各自模块的 App adapter：

```text
internal/module/auth/route_app.go
internal/module/auth/handler_app.go
internal/module/auth/presenter_app.go
internal/module/user/route_app.go
internal/module/user/handler_app.go
internal/module/user/presenter_app.go
internal/module/uploadtoken/route_app.go
internal/module/uploadtoken/handler_app.go
internal/module/uploadtoken/presenter_app.go
```

这是结构优化，不是功能变化。必须先有测试保护：

```text
GET  /api/app/v1/auth/login-config
GET  /api/app/v1/auth/captcha
POST /api/app/v1/auth/send-code
POST /api/app/v1/auth/login
GET  /api/app/v1/users/me
POST /api/app/v1/auth/logout
GET  /api/app/v1/profile
PUT  /api/app/v1/profile
POST /api/app/v1/upload-tokens
```

## 9. 风险与破坏面

### Phase 1 风险

文档治理风险低，只影响后续开发规则。

### Phase 2 风险

`APP_NAME` 清理风险低。当前检索显示实际运行时身份由 `cmd/admin-api` / `cmd/admin-worker` 设置，不靠 `Config.App.Name`。

需要防止：

```text
测试仍断言 cfg.App.Name。
文档 env 列表仍包含 APP_NAME。
ignored 的本机 admin-go.env 仍让用户误解。
```

### Phase 4 风险

结构收敛风险中等，主要是路由和 public path：

```text
路由漏注册
public skip path 漏配
platform=app 固定逻辑丢失
App 出参误返回 admin RBAC 字段
admin_app contract test 失败
```

所以 Phase 4 不能和当前登录长任务混做。

## 10. 专家审查问题

请专家重点看这些点：

```text
1. /api/{scope}/v1 是否应被定义为 HTTP scope，而不是 module boundary？
2. authplatform 是否应该限制在认证/会话策略，而不是全局平台配置？
3. APP_NAME 清理是否还有未发现的真实运行时依赖？
4. appauth 是继续过渡保留，还是登录稳定后按 capability 拆回 auth / user / uploadtoken 的 app adapter？
5. presenter 层是否足够表达 admin/app 出参差异，是否需要现在引入统一 RequestContext？
```

## 11. 最终治理规则

可直接进入架构文档的规则：

```text
平台 scope 不是业务模块边界。

/api/admin/v1、/api/app/v1 只代表 HTTP 入口、权限策略、出参投影不同。
auth、AI、wallet、upload、notification 等业务能力必须由共享 service 承载。
新增平台时，默认只新增 route / handler / presenter / policy，不新增 app*/admin*/xx* 业务模块。

临时平台 adapter 必须有名字、有边界、有收敛计划；禁止把平台 adapter 演变成第二套业务实现。
```
