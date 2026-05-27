# 兼容路由命名与模块边界治理设计

日期：2026-05-27
状态：待用户 review
负责人：Codex

## 先说实话

我们现在不是“完全规范”，但也不是“架构方向错了”。更准确地说：

```text
大方向是对的：Gin modular monolith + capability module + REST 契约 + smoke/docs truth。
当前痛点是真的：迁移期留下的 legacy 词义、兼容入口命名、平台 scope 和业务 module 的边界还不够干净。
```

这也是你现在痛苦的来源：不是某一个 `legacy` 变量难看，而是它暴露了一个更深的问题——代码里有些词同时承担了“历史来源”“当前职责”“迁移状态”“兼容策略”四种意思。

如果这个问题不收口，未来每新增一个平台或入口，开发者会自然复制出：

```text
legacy2
newLegacy
appauth
merchantauth
adminuser
appuser
```

这会让重构越做越乱。

所以本设计的目标不是“大重构一刀切”，而是先把概念边界钉死：

```text
module     = 业务能力边界
platform   = HTTP 作用域 / 策略作用域
compat     = 当前仍保留的兼容入口职责
legacy     = 历史来源描述，不是代码所有权
```

## Linus 三问

1. 这是真问题吗？

是。`legacy := router.Group("/api/Users")` 这种写法会让后续开发者误以为“遗留”是一个长期代码区域；`appauth` 这种包名也已经证明平台容易被误建成 module。

2. 有更简单的做法吗？

有。先不重排目录、不删除兼容接口、不改公开 API，只做命名、文档和架构守卫：

```text
legacy 变量名 -> xxxCompat
legacy adapter 词义 -> compat adapter
平台命名 module -> 架构测试阻断
兼容入口 -> 明确来源、消费者、退出条件
```

3. 会破坏已有前端、接口、登录和权限吗？

不应该破坏。本设计不改变 URL、不改变 handler、不改变 service、不改变数据库、不改变前端调用。后续实现第一刀只改变量名、注释、文档和架构测试。

## 当前证据

### 代码证据

当前 active Go runtime 里存在裸 `legacy` 路由变量：

```go
// admin_back_go/internal/module/auth/route.go
legacy := router.Group("/api/Users")
legacy.POST("/getLoginConfig", handler.LoginConfig)
legacy.POST("/sendCode", handler.SendCode)
legacy.POST("/login", handler.Login)
legacy.POST("/refresh", handler.Refresh)
legacy.POST("/logout", handler.Logout)

// admin_back_go/internal/module/user/route.go
legacy := router.Group("/api/Users")
legacy.POST("/init", handler.Init)
```

它们的真实职责不是“遗留模块”，而是：

```text
旧 /api/Users/* HTTP path 的兼容 adapter。
```

### 文档证据

现有架构文档已经有正确方向：

```text
/api/admin/v1 和 /api/app/v1 是 HTTP scope，不是业务模块边界。
平台不是 module。新增平台不得默认新增 xxxauth / xxxuser / xxxupload。
兼容必须有名字、有边界、有删除计划。
```

但文档仍混用 `legacy adapter`、`legacy fallback`、`legacy action path` 等说法。历史来源可以叫 legacy，但当前代码职责更应该叫 compat。

### 模块证据

当前 `internal/module` 下面已经是 capability module 为主：

```text
auth
user
permission
role
payment
wallet
uploadtoken
notification
aiagent
aichat
aiconversation
aimessage
```

这说明 `internal/module` 本身不是错的。真正要避免的是把这些东西误建成 module：

```text
平台：appauth / adminauth / merchantauth
兼容入口：legacyusers / legacyauth
供应商品牌：tencentauth / alipaypayment，除非它真是 platform boundary
运行方式：fastjob / slowjob
旧系统名称：phpusers / oldai
```

## 核心结论

### 1. 不建议取消 `internal/module`

取消 module 文件夹会让代码重新退化成全局技术分层：

```text
internal/handler/auth.go
internal/service/auth.go
internal/repository/auth.go
internal/handler/user.go
internal/service/user.go
```

这种结构看起来“整齐”，但业务一多，跨文件跳转会更痛苦，能力边界会更弱。

本项目更适合继续使用：

```text
internal/module/<capability>/...
```

原因：

```text
一个业务能力的 route / handler / service / repository / dto 放在一起
模块可以独立测试
模块边界更接近未来可拆服务边界
前端菜单、权限、契约更容易对齐到业务能力
```

### 2. 但不应该强迫每个 module 都五层齐全

现有规则里的 `route -> handler -> service -> repository -> model` 应该理解为“最多允许这样分”，不是“每个模块必须这样写”。

推荐规则：

```text
小模块：route.go / handler.go / service.go / request.go 足够
没有 DB：不要 repository.go
没有表：不要 model.go
没有复杂响应：不要 presenter.go
没有跨平台差异：不要 platform_handler.go
没有旧入口：不要 compat_route.go
```

也就是说，保留文件夹分层，但反对为了架构感硬塞文件。

### 3. `legacy` 不应该作为 active code 的职责名

`legacy` 只能表示历史来源，例如：

```text
这个 URL 来源于旧 PHP 系统。
这个字段是旧契约别名。
这个 migration 是为了清理旧表。
```

active code 当前承担的是兼容职责，所以应该叫：

```text
compat
usersCompat
usersAuthCompat
oldUsersCompat
```

推荐命名：

```go
adminAuth := router.Group("/api/admin/v1/auth")
usersAuthCompat := router.Group("/api/Users")
```

而不是：

```go
v1 := router.Group("/api/admin/v1/auth")
legacy := router.Group("/api/Users")
```

`v1` 也不是最理想，因为它只表达版本，不表达 scope 和 capability。`adminAuth` 更清楚。

### 4. 新增平台不新增平台命名 module

新增平台时，默认只新增：

```text
route prefix
request DTO
presenter
policy / platform config
```

不新增：

```text
appauth
merchantauth
partneruser
openapiupload
```

例如未来新增 merchant：

```go
auth.RegisterPlatformRoutes(router, auth.PlatformRouteOptions{
    Prefix:   "/api/merchant/v1/auth",
    Platform: enum.PlatformMerchant,
})
```

而不是：

```text
internal/module/merchantauth
```

### 5. 兼容入口必须有退出条件

允许 compat，但必须显式：

```text
来源：兼容哪个旧 URL / 旧字段 / 旧前端调用
消费者：谁还在用
边界：只在 route/handler/request 层转换
退出条件：哪个前端/API 切换完成后删除
```

禁止：

```text
compat 逻辑进入 service
compat 字段进入 repository/model
新接口为了“保险”继续接受旧字段
以后新增入口继续叫 legacy
```

## 术语标准

| 词 | 允许含义 | 禁止含义 |
| --- | --- | --- |
| `module` | 业务能力边界 | 平台、旧接口、供应商品牌、运行方式 |
| `platform` | admin/app/merchant 这类访问作用域和策略作用域 | 业务模块名 |
| `compat` | 当前代码承担的兼容职责 | 新业务能力 |
| `legacy` | 历史来源、旧系统 provenance | active code 变量名、包名、长期架构区域 |
| `scope` | `/api/admin/v1`、`/api/app/v1` 这类 HTTP 作用域 | module 边界 |
| `presenter` | 平台响应差异映射 | 复制 service 的理由 |

## 路由命名规则

### 推荐

```go
adminAuth := router.Group("/api/admin/v1/auth")
appAuth := router.Group("/api/app/v1/auth")
usersAuthCompat := router.Group("/api/Users")
usersCompat := router.Group("/api/Users")
```

### 禁止

```go
v1 := router.Group("/api/admin/v1/auth")        // 太泛，不能表达 scope/capability
legacy := router.Group("/api/Users")           // 词义污染
legacy2 := router.Group("/api/Other")          // 更糟
old := router.Group("/api/Users")              // 太泛
```

### 文件命名建议

```text
route.go              当前 module 的主 REST route 注册
platform_route.go     多平台共用 route 注册器，只有平台差异足够明显时才建
app_route.go          app scope 专属且不能共用时才建
compat_route.go       兼容旧 HTTP path，只有兼容入口超过少量映射或有复杂转换时才建
handler.go            当前主 handler
platform_handler.go   平台 handler / presenter，需要时才建
compat_handler.go     旧入参/旧响应转换复杂时才建
```

当前 `/api/Users/*` 只有少量映射，可以先保留在原 `route.go`，只改变量名和注释；不急着拆 `compat_route.go`。

## module 新增判断

新增 module 前必须满足至少一个强条件，并且不能只因为平台/兼容/历史来源而新增。

### 可以新增 module 的信号

```text
有独立业务能力名称
有独立 API resource
有独立 DB 表或外部资源生命周期
有独立权限菜单/按钮
有独立 service 规则和测试边界
未来可能被单独拆服务
```

### 不应该新增 module 的信号

```text
只是 URL prefix 不同
只是 admin/app 返回字段不同
只是旧接口路径不同
只是 provider 品牌不同
只是队列高低优先级不同
只是为了少 import 几个文件
只是为了目录看起来高级
```

## 这次治理范围

### 要做

```text
1. active Go route 里不再出现裸 legacy := router.Group(...)
2. /api/Users/* 兼容入口变量改为 xxxCompat
3. 架构文档把当前职责统一为 compat adapter
4. 保留 legacy 作为历史来源词，但不作为 active code owner
5. 增加 architecture test 防止裸 legacy 路由变量回潮
6. 更新 module README，强调“最多文件，不是必选文件”
```

### 不做

```text
不删除 /api/Users/* 兼容 URL
不改 admin/app 公开 API
不移动现有业务模块
不把 internal/module 改成全局 handler/service/repository
不批量重命名所有文档里的 legacy 历史描述
不重写 router 注册框架
不做 DB migration
```

## 验收标准

1. `admin_back_go/internal/module/**` active Go route 中没有裸 `legacy := router.Group(...)`。
2. 兼容旧 URL 的变量名使用 `*Compat`。
3. `docs/architecture/04-go-backend-framework.md` 明确：compat adapter 是当前职责，legacy 只是历史来源。
4. `docs/architecture/05-development-quality-rules.md` 明确：兼容必须有名字、边界、退出计划。
5. `admin_back_go/internal/module/README.md` 明确：module 是 capability boundary，内部文件是最多集合，不是必选层级。
6. `go test ./internal/architecture -count=1` 可以阻断裸 `legacy` route 变量回潮。
7. 不改变任何公开 URL、handler 行为、service 逻辑、DB schema。

## 后续更大问题怎么处理

这次只治理“词义和边界”。如果后续还觉得 module 数量太多，应该单独做一次 module inventory，不要和本次 compat 命名混在一起。

module inventory 要回答：

```text
哪些 module 是真正业务能力
哪些是 user 下的子能力
哪些是 AI 下的子能力
哪些只是因为迁移期被拆出来
哪些可以只通过文件拆分而不是目录拆分
```

但那是下一刀。当前第一刀先把“平台、兼容、历史来源、业务能力”四个概念分开。
