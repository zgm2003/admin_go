# 平台是作用域，不是业务模块：架构设计

日期：2026-05-27
状态：待用户 review
负责人：Codex

## 问题

当前后端同时存在：

```text
internal/module/auth
internal/module/appauth
```

`appauth` 并不是完整复制了一套认证业务逻辑。它现在调用的是 `auth.Service`，例如 login-config、send-code、login、logout 都还是走 `auth` 的 service。真正的问题是：`appauth` 这个包名和边界会让“平台入口”看起来像一个“业务模块”。

如果继续沿着这个模式扩展，未来每新增一个平台，都可能自然长出：

```text
merchantauth
merchantuser
merchantupload
partnernotification
```

这会把系统从“按业务能力模块化”变成“按平台复制代码”。平台越多，维护成本越高。

## 核心规则

平台是作用域、策略和访问入口，不是业务模块。

业务模块应该表达系统能力：

```text
auth          认证
user          用户
upload        上传
notification  通知
payment       支付
permission    权限
```

平台只是访问面：

```text
admin
app
merchant
partner
openapi
```

默认规则：新增平台时，不应该新增 `xxxauth`、`xxxuser`、`xxxupload` 这类平台命名的业务包。只有出现新的业务能力，并且它有独立生命周期、独立数据归属、独立规则时，才应该新增 module。

## 当前证据

当前认证业务本身已经支持平台维度：

- `auth.Service.LoginConfig(ctx, platform)` 已经按 platform 读取登录策略。
- `auth.Service.Login(ctx, auth.LoginInput{ Platform: ... })` 已经签发平台作用域 session。
- `auth_platforms` 已经是登录类型、验证码、token TTL、session 策略的事实源。
- middleware 已经能按路径推导默认平台，例如 `/api/app/v1/* -> app`。

所以 `appauth` 的存在不是因为 auth service 不支持 app，而是因为 app HTTP 入口和响应包装被单独切成了一个平台包。

另外，`appauth` 现在还混入了非认证接口：

```text
GET  /api/app/v1/users/me
GET  /api/app/v1/profile
PUT  /api/app/v1/profile
POST /api/app/v1/upload-tokens
```

这些接口也不该由 `appauth` 长期拥有。

## 目标

1. 保持“一个业务能力一个 module”。
2. 平台差异通过路由 prefix、platform 参数、策略读取、响应 presenter 表达。
3. 阻止未来新增平台时复制出平台命名业务模块。
4. 保留现有公开 API 路径，不破坏前端调用。
5. 迁移期间保持 admin/app 现有契约兼容。

## 非目标

本设计不做这些事：

- 不重写整个 router 架构。
- 不把 app profile / upload-token 强行塞进 auth。
- 不修改 token 格式、session 存储或 `auth_platforms` 表结构。
- 不引入一个过度抽象的通用平台框架。
- 不增加新旧字段兜底别名。

## 设计原则

### 1. module 按业务能力归属

module 拥有业务规则、数据访问、service 编排和对应能力的路由注册。

平台专属路由可以存在，但应该放在业务能力所属 module 下，而不是新建平台命名 module。

### 2. platform 是作用域

平台相关 route 必须显式声明 platform，或者由统一的 path 规则推导。

需要平台差异的 service input 应该带 `Platform` 字段。

### 3. 响应差异放在 presenter，不复制 service

不同平台可能需要不同响应结构。这个差异应该由小的 response mapper / presenter 解决，而不是复制业务模块。

例如：

```text
auth service result -> admin presenter -> 当前 admin 登录响应
auth service result -> app presenter   -> { token, user }
```

### 4. 策略事实源仍是 auth_platforms

登录策略继续由 `auth_platforms` 负责。新增平台主要应该增加策略数据和 route 注册，而不是新增认证包。

## auth 目标结构

目标上，`auth` 包应该拥有 admin 和 app 的认证路由：

```text
internal/module/auth
  service.go              # 认证业务逻辑，只写一份
  handler.go              # 当前 admin 兼容 handler
  platform_handler.go     # 平台认证 HTTP 适配层
  route.go                # admin auth route 注册
  platform_route.go       # 可复用平台 auth route 注册
  presenter.go            # 必要的响应映射
```

app 认证路由概念上应该这样注册：

```go
auth.RegisterPlatformRoutes(router, auth.PlatformRouteOptions{
    Prefix:   "/api/app/v1/auth",
    Platform: enum.PlatformApp,
})
```

未来新增平台时，也只是注册新平台入口：

```go
auth.RegisterPlatformRoutes(router, auth.PlatformRouteOptions{
    Prefix:   "/api/merchant/v1/auth",
    Platform: enum.PlatformMerchant,
})
```

而不是新增：

```text
internal/module/merchantauth
```

## app 非认证接口怎么归属

当前 `appauth` 还包含这些接口：

```text
GET  /api/app/v1/users/me
GET  /api/app/v1/profile
PUT  /api/app/v1/profile
POST /api/app/v1/upload-tokens
```

这些不应该迁进 `auth`。

推荐归属：

```text
user module        -> /api/app/v1/users/me、/api/app/v1/profile、PUT /api/app/v1/profile
uploadtoken module -> /api/app/v1/upload-tokens
```

如果这些接口需要 app 专属 DTO，就在所属业务 module 下做 app route adapter / presenter，不再放进 `appauth`。

## 迁移切片

### Slice 1：只迁移 app 认证路由

把 app auth endpoints 从 `appauth` 收回 `auth`，路径不变：

```text
GET  /api/app/v1/auth/login-config
GET  /api/app/v1/auth/captcha
POST /api/app/v1/auth/send-code
POST /api/app/v1/auth/login
POST /api/app/v1/auth/logout
```

要求：

- 继续调用现有 auth service。
- app auth route 固定 `platform=app`。
- app login response 保持当前前端契约，例如 `{ token, user }`。
- admin auth route 不受影响。

### Slice 2：迁移 app 用户资料和上传入口

把剩余 app endpoints 移出 `appauth`：

```text
user        owns current user and profile app routes
uploadtoken owns app upload token route
```

Slice 2 完成后，删除 `internal/module/appauth`。

## 测试要求

实现前先写失败测试，证明新架构目标：

1. `/api/app/v1/auth/*` 路由仍然存在。
2. app auth 路由强制使用 `platform=app`，忽略冲突的 `platform` header。
3. `/api/admin/v1/auth/*` 保持现有行为。
4. 完整迁移后不再存在 `internal/module/appauth` 包。
5. app login 响应结构保持当前前端契约。
6. app 当前用户、profile、upload-token 路由移动归属后仍然可用。

需要保留或更新的重点测试：

```text
admin_back_go/internal/server/router_test.go
admin_back_go/internal/module/auth/handler_test.go
admin_back_go/internal/module/appauth/* 测试或对应替代测试
```

## 文档要求

实现落地时同步更新：

```text
docs/status/current-status.md
docs/contracts/admin-api-v1.md
admin_back_go/docs/architecture.md
docs/architecture/04-go-backend-framework.md
```

必须写清楚硬规则：

```text
平台不是 module。新增平台默认不得新增平台命名业务模块。
```

## 验收标准

- 不新增平台命名 auth module。
- app auth endpoints 由 `internal/module/auth` 或 auth 明确拥有的 transport adapter 承接。
- 认证业务逻辑仍然只有一份。
- app profile / upload-token 不被塞进 auth。
- 未来新增平台只需要 route 注册和策略数据，不需要新建 `xxxauth` 包。
- 测试和文档明确说明“平台是作用域，不是 module”。

## 自检

- 占位符检查：没有未完成占位标记。
- 范围检查：设计聚焦平台/module 边界，以 auth 迁移为第一刀。
- 一致性检查：auth 只拥有认证；user/uploadtoken 拥有非认证 app endpoints；platform 保持 route/policy 维度。
- 歧义检查：什么时候新增 module 已明确：只有新增业务能力时才新增，不因新增平台而新增。
