# 多平台后端架构边界设计

日期：2026-05-27
状态：codex 二次校订（含 infra/adapter 命名协议），等待用户最终确认
负责人：Claude（基于 codex 初稿迭代；codex 二次注入"capability 不绑定平台" + "infra 是层、adapter 是角色"修订；用户委托决断）

---

## 0. 文档说明

本 spec 经过两轮校订，本节简述每一轮的精神。

### 0.1 与 codex 初稿的差异（第一轮）

Codex 初稿的诊断大致正确，但**实施模型选错了**。本稿保留诊断、替换模型。逐条对照：

| 主题 | Codex 初稿 | 本稿 | 变更理由 |
|---|---|---|---|
| 顶层分包 | `api/{admin,app,...}` + `domain` + `shared` + `platform` 四层 | `module/{capability}/transport/{platform}/` + `shared/` + `infra/` | 见 §3.2 |
| `module` 目录 | "过渡历史结构，不是未来唯一边界" | **保留为业务能力归属处，是核心概念** | `module` 含义可以收紧，不必否定 |
| admin/app user 关系 | 同一 `domain/user` 被 `api/admin/user` 和 `api/app/user` 共享 | **同 `users` 表，但是 3 个不同 module**：`user`（用户管理能力）/ `profile`（admin+app 自服务）/ `auth`（admin+app 认证） | 用户管理 ≠ 自服务 ≠ 认证，不是同能力不同入口 |
| dict 设计形态 | "Service + Registry，或函数 + 集中 assembler"（未拍板） | **Service + Registry**，含义见 §7.1 | 函数 + assembler 不能管理缓存/失效 |
| `internal/platform` 改名 | "建议改 adapter，但目录改名是后续实施问题" | **本 spec 内拍板：`internal/infra/`**（详见 §0.4） | 命名冲突 + 名实相符 |
| 第一刀切什么 | dict（"影响面可控"） | **auth**（建立多平台样板，跑通后所有 module 跟样板走） | 第一刀的目的是确立 pattern，不是选最小风险 |
| 第一刀范围 | "只改文档，不改代码" | **文档 + auth 代码切片同时进行** | 文档单独走会落空 |

### 0.2 Codex 二次注入 A：capability 不绑定平台

第一轮初版里多处出现 `(admin only)` 标签（如 "permission（admin only）"、"user（后台用户管理）"），codex 指出这与项目愿景冲突：

```text
"admin only" 是当前暴露面，不是能力定义。
把任何 capability 钉死成 "admin-only" 等于提前关上未来平台扩展的门。
"当前先实现 transport/admin/" 是事实陈述；"长期只有 admin 入口" 是错误结论。
```

本稿据此修订：

- 所有 capability 描述统一为"当前 admin 管理入口"而非"admin only"
- §3.2 R3 增补："当前只有 admin 入口也不是 admin-only"
- §1.3 反目标增补："不把任何 capability 定义成长期 admin-only"
- §12.3 第三刀范围说明"这里的 admin 只是当前暴露面，不是 admin-only 分类"

### 0.3 与实际代码现状对齐

第一轮 spec 多处提到 `internal/module/appauth/` 目录需要删除——但该目录**当前并不存在**。项目实际状态是 auth/user 等模块**已经尝试过两种多平台路由方案**，都不理想。本稿 §2 "现状快照" 精确描述实际反例，并据此校正 §12.1 第一刀的具体动作。

### 0.4 Codex 二次注入 B：infra 是层，adapter 是角色

Claude 第一版选择 `internal/infra/` 作为外部资源目录名，codex 在二轮校订中给出语义反驳，**已被采纳**：

```text
adapter 这个词在架构上通常意味着：
  domain 定义 port/interface
  adapter 实现这个 port

但当前项目不是这个模式：
  internal/platform/database/   直接暴露 *gorm.DB，没有 domain port
  internal/platform/redisclient/ 直接给 *redis.Client
  internal/platform/logging/    是 slog wrapper
这些大部分不是 adapter，是 infrastructure resources（运行时技术资源）。

把整层叫 adapter，等于声称一个我们没做的 ports & adapters 契约。
```

**最终协议**：

```text
infra/   = 层名（事实描述：运行时技术资源）
adapter  = infra 内某些实现的角色名（多供应商/有隐式 port 时使用）

infra/database          GORM wrapper（不是 adapter，是 wrapper）
infra/redis             Redis client（同上）
infra/payment/alipay    支付宝 adapter（有"支付网关"隐式 port，是真正的 adapter）
infra/ai/openai         OpenAI adapter（同上）
infra/storage/cos       COS adapter（同上）
```

如果 codex 对任一条不同意，请在 §15 "待共同确认开放点"留下意见再走 plan。

---

## 1. 前提与目标

### 1.1 项目前提

```text
后端：admin_back_go（Go + Gin，单体多进程：admin-api / admin-worker）
当前接入前端：admin（Vue 后台）、admin_app（Flutter 移动端，独立仓库）
未来可能接入：merchant（商户端）、openapi（对外 API）、miniapp 等
项目状态：未上线，没有线上数据契约约束，可以大胆重构
```

### 1.2 设计目标

```text
一个后端服务多个前端（admin/app/未来平台）
业务能力归属清晰、阅读路径短
公共能力（dict/enum/validate/setting）真正统一
运行时技术资源（DB/Redis/SDK）与业务平台名字严格不冲突：
  业务平台 = platform；技术资源 = infra
新增平台 = 加路由，不增业务 module
彻底删除 legacy/compat/fallback 框架性概念
任何 capability 不被钉死在某个平台上：当前暴露面 ≠ 长期归属
```

### 1.3 反目标（明确不做什么）

```text
不引入 DDD 风格的 api / domain / application / infrastructure 多层分包
不把"是否上线"作为重构成本的借口（项目未上线，不需要小心翼翼）
不维护 /api/Users/* 等旧 POST 路由作为"legacy adapter"
不在业务 module 命名上出现平台前缀（不再有 appauth / merchantuser）
不在代码里写"默认平台"或"未标平台时假设 admin"这类隐式约定
不把任何 capability 定义成长期 admin-only；当前只有 admin 入口只是当前暴露面
不在同一 package 内用 platform_* / app_* 文件前缀代替 transport/{platform}/ 目录分层
不把 infra/ 当成"什么都能放"的杂物筐：infra 只装运行时被 import 的技术资源
不引入 Ports & Adapters / Hexagonal 的强制 port 抽象（除非业务真有多供应商切换需求）
```

---

## 2. 现状快照（事实地基）

本节是事实陈述，不带规范判断；规范判断在 §3 之后。

### 2.1 当前 module 清单（36 个）

```text
internal/module/
  aiagent  aichat  aiconversation  aiimage  aiknowledge
  aimessage  aiprovider  airun  aitool
  auth  authplatform  captcha
  clientversion  crontask  exporttask
  mail  notification  notificationtask
  operationlog  payment  permission  queuemonitor
  realtime  role  session
  sms  system  systemlog  systemsetting
  uploadconfig  uploadtoken
  user  userloginlog  userquickentry  usersession
  wallet
```

观察：

- "user" 词被滥用为前缀（`userloginlog` / `userquickentry` / `usersession`）
- "ai" 大领域被切成 9 个并列 module
- `authplatform` 驼峰命名与其他单词模块不一致
- `appauth` 目录**不存在**（早期可能讨论过，未落地）
- `session` 与 `usersession` 并存
- `captcha` 是独立 module，但功能上是 auth 的副产品

### 2.2 当前多平台路由的两种实现形态（都不理想）

**形态 A：`module/user/` —— 单一 route.go 内挂多平台**

`module/user/route.go` 一个文件同时挂载 4 类路由前缀：

```text
/api/Users/*              (legacy POST init)
/api/admin/v1/users/*     (11 个 endpoint)
/api/admin/v1/profile/*   (5 个 endpoint)
/api/app/v1/users/*       (1 个 endpoint: me)
/api/app/v1/profile/*     (2 个 endpoint: get / put)
```

同包内有 `app_handler.go` / `app_dto.go` / `app_route_test.go`——
**用文件名前缀代替目录分层**，全包内搜 `Handler` 同时命中 admin 与 app 两套。

**形态 B：`module/auth/` —— 两套同包变体 + 两个 RegisterXxx 入口**

`module/auth/` 同包内并存两套：

```text
route.go              admin 入口（/api/admin/v1/auth/* + /api/Users/* legacy）
handler.go            admin handler
request.go            admin request struct
dto.go                admin DTO

platform_route.go     由 RegisterPlatformRoutes 注册任意 platform
platform_handler.go   platform handler（构造时传入 platform 字符串）
platform_handler_test.go
platform_dto.go       platform DTO
```

`internal/server/router.go:131-137` 调用两次：

```go
auth.RegisterRoutes(router, deps.AuthService)
auth.RegisterPlatformRoutes(router, auth.PlatformRouteOptions{
    Prefix:   "/api/app/v1/auth",
    Platform: enum.PlatformApp,
    ...
})
```

仍然是**同包混杂**，"admin 用 route.go，app 用 platform_route.go" 是隐式约定，新来者读不出。

### 2.3 当前 legacy 路由

`/api/Users/*` 仍在被注册：

```text
module/auth/route.go:21-26   /api/Users/{getLoginConfig,sendCode,login,refresh,logout}
module/user/route.go:13-14   /api/Users/init
```

未上线项目，前端可改。本 spec 决定**直接删除**，不留 compat layer。

### 2.4 当前 `internal/platform/` 内容

```text
internal/platform/
  accesstoken  ai  database  logging  logstore
  mail  payment  README.md  realtime
  redisclient  redislock  scheduler  secretbox
  secretkey  sms  storage  taskqueue
```

全部是外部资源/SDK 适配。**目录名 `platform` 与"业务平台 admin/app/openapi"撞车**，是当前可读性最大痛点之一。本 spec 将其改名为 `internal/infra/`（理由见 §0.4 + §8）。

### 2.5 当前架构文档与本 spec 的冲突

`docs/architecture/04-go-backend-framework.md:11-22` 把目标写成：

```text
cmd -> bootstrap -> api -> domain -> shared -> platform
```

即 codex 初稿的 DDD 风格 4 层。本 spec 推翻该模型，详见 §11 Q1/Q2。

---

## 3. 设计原则与核心硬规则

### 3.1 设计原则

```text
1. 一个能力 = 一个目录：阅读路径短，能力边界清晰
2. 平台差异下沉到 transport 子目录：service/repository 跨平台共用
3. 公共能力强边界：dict/enum/validate/setting 通过 shared/ 统一治理
4. 业务平台与技术资源严格分名：
   - 业务平台叫 platform（admin/app/openapi/merchant/...）
   - 技术资源层叫 infra（DB/Redis/Queue/Storage/SDK/Logging/...）
   - 多供应商实现可叫 adapter（角色名，如 infra/payment/alipay 是 Alipay adapter）
5. 不维护 legacy：未上线项目不需要 compat layer
```

### 3.2 核心硬规则（R1-R8，写进根架构文档）

以下 8 条是项目级硬规则，违反即视为架构缺陷。

```text
R1. 一个业务能力 = 一个 internal/module/{capability}/ 目录
    capability 名只描述能力本身（auth / user / payment / ai / ...）
    capability 名永不带平台前缀（禁止 appauth / adminuser / merchantpayment）
    capability 命名小写下划线，单数形式（payment 不是 payments）

R2. 任何对外 HTTP 路由必须位于
    internal/module/{capability}/transport/{platform}/
    禁止 module 根目录下直接出现 route.go / handler.go
    禁止"裸 transport"（transport/route.go 没有 platform 子目录）
    禁止同包内用 platform_*.go / app_*.go 文件前缀代替目录分层

R3. 即使某个能力当前只暴露一个平台入口，也必须显式放在
    transport/{platform}/ 下，没有默认平台、没有隐式约定
    当前只有 admin 入口也不是 admin-only；只是当前先实现 transport/admin/，
    未来新增平台继续在同 capability 下扩展
    例：permission 当前只实现 admin 暴露面，路径仍是
    module/permission/transport/admin/

R4. 新增平台 = 在每个相关 module 下加 transport/{new_platform}/
    + 在 bootstrap 加一行 Register 调用
    禁止为新平台新建 module/{platform}{capability}/

R5. service / repository 不依赖 gin.Context
    平台信息通过显式 Platform 入参传入 service
    service 持有的状态不区分平台（认证策略差异由 auth_platforms 表表达）

R6. 模块不直接读 internal/enum 拼 option 数组
    模块在 bootstrap 时向 shared/dict.Service 注册自己的 provider
    page-init 一律通过 dict.PageInit(ctx, names...) 组装

R7. 模块不直接读 system_settings 表
    通过 shared/setting 边界读取，强类型 key，含默认值与缓存

R8. 项目无 legacy / compat / fallback 框架性概念
    旧 /api/Users/* 类 POST 路由直接删除，前端跟着删
    architecture.md 不再保留 "legacy adapter" "fallback bridge" 等段落
```

---

## 4. 目标目录结构

```text
admin_back_go/
  cmd/
    admin-api/                进程入口：HTTP runtime
    admin-worker/             进程入口：Asynq worker + scheduler
  internal/
    bootstrap/                依赖装配
    server/                   Gin 引擎 + 全局 middleware
    config/                   typed config

    module/                   ★ 业务能力
      auth/
        service.go              业务核心（admin+app 共用一份）
        repository.go
        model.go
        jobs.go                 该模块自有 Asynq task 注册
        loginlog.go             认证副产品（合并自原 userloginlog）
        session.go              会话管理（合并自原 session + usersession）
        captcha.go              滑块验证码（合并自原 captcha）
        transport/
          admin/
            route.go            /api/admin/v1/auth/*
            handler.go
            request.go
            presenter.go
          app/
            route.go            /api/app/v1/auth/*
            handler.go
            request.go
            presenter.go
      auth_platform/          auth_platforms 策略管理（当前 admin 管理入口）
        transport/admin/
      permission/             RBAC/权限能力（当前 admin 管理入口）
        transport/admin/
      user/                   用户管理能力（当前 admin 管理入口）
        transport/admin/
      profile/                当前用户自服务（admin + app）
        service.go              个人资料、绑邮箱、改密、头像、安全
        quickentry.go           原 userquickentry 合并
        transport/admin/
        transport/app/
      uploadconfig/           上传配置能力（当前 admin 管理入口）
        transport/admin/
      uploadtoken/            上传 token 签发（admin + app）
        transport/admin/
        transport/app/
      notification/           通知 + 通知任务（含 notification_task）
        transport/admin/
      mail/                   邮件配置 + 模板 + 日志 + 发送
        transport/admin/
      sms/                    短信
        transport/admin/
      payment/                支付（含 wallet 子包）
        wallet/                 钱包业务子包
        transport/admin/
        transport/callback/     /api/payment/callbacks/*（公开回调入口）
      ai/                     AI 大领域（含子包）
        provider/               原 aiprovider
        agent/                  原 aiagent
        conversation/           原 aiconversation + aimessage
        run/                    原 airun
        tool/                   原 aitool
        knowledge/              原 aiknowledge
        image/                  原 aiimage
        chat/                   原 aichat（runtime）
        transport/admin/
      systemsetting/
        transport/admin/
      systemlog/
        transport/admin/
      operationlog/
        transport/admin/
      crontask/
        transport/admin/
      queuemonitor/
        transport/admin/
      clientversion/
        transport/admin/        管理后台 CRUD
        transport/app/          客户端 update.json check
      realtime/                 WebSocket
        transport/admin/
        transport/app/
      export/                   导出任务（原 exporttask）
        transport/admin/
      system/                   health/readiness/ping（公开探活）
        transport/public/       /api/system/* 公开

    shared/                   ★ 跨能力公共服务
      dict/                     字典 Service + Registry，含缓存策略
      enum/                     跨域稳定常量（CommonYes/CommonNo/Platform 等）
      validate/                 go-playground 校验器注册
      i18n/                     翻译边界
      response/                 统一响应包装 { code, data, msg }
      apperror/                 错误模型
      pagination/               分页约定
      setting/                  system_settings 读取边界

    infra/                    ★ 运行时技术资源层（原 internal/platform/ 改名）
                              （层名是 infra；其中多供应商实现可称为 adapter，见 §8）
      database/                 MySQL（GORM + sql.DB）—— wrapper，非 adapter
      redis/                    通用 Redis client —— wrapper
      taskqueue/                Asynq 封装 —— wrapper
      scheduler/                gocron 封装 —— wrapper
      logging/                  slog + lumberjack —— wrapper
      secretbox/                AES-GCM —— wrapper
      secretkey/                HKDF —— wrapper
      logstore/                 OS 日志文件读取 —— wrapper
      accesstoken/              token 工具 —— wrapper
      storage/cos/              腾讯云 COS adapter（隐式 port: object storage）
      payment/alipay/           支付宝 SDK adapter（隐式 port: payment gateway）
      ai/openai/                OpenAI-compatible adapter（隐式 port: chat model）
      mail/tencentses/          腾讯云 SES adapter（隐式 port: mail sender）
      sms/tencent/              腾讯云短信 adapter（隐式 port: sms sender）
      realtime/                 WebSocket Publisher（local/redis/noop 多实现 = adapter）

    jobs/                     Asynq task type 全局注册入口（保持薄）
      registry.go
      types.go
```

**注**：上面是**目标结构**，不是第一刀完成形态。迁移按 §12 分多刀做，但所有新增/触碰过的代码必须立刻符合上面规则。

---

## 5. module 与 transport 细则

### 5.1 module 命名规则

```text
名字 = 业务能力，小写下划线
单数：payment 不是 payments
不带通用后缀：user 不是 usermanager
不带平台前缀：auth 不是 admin_auth / appauth
不带技术词：notification 不是 notification_service / notification_module
```

### 5.2 module 内部典型布局

```text
module/{cap}/
  service.go              业务编排，全平台共用
  repository.go           DB 访问
  model.go                ORM 模型 + 表名
  request.go              业务 input struct（不带 binding tag，binding 在 transport）
  enum.go                 (optional) 仅本模块用的 enum
  jobs.go                 (optional) 该模块的 Asynq task 构造 + handler
  {sub}.go                (optional) 子能力（如 auth/loginlog.go, auth/session.go）

  transport/
    admin/
      route.go            路由注册，导出 Register(r, deps)
      handler.go          HTTP handler，调用 service
      request.go          HTTP 入参 struct（带 binding tag）
      presenter.go        响应映射
    app/                  (若该能力服务 app)
      route.go
      handler.go
      request.go
      presenter.go
    callback/             (若该能力有公开回调，如 payment)
      route.go
      handler.go
    public/               (若该能力是公开探活，如 system)
      route.go
      handler.go
```

### 5.3 文件命名约定

```text
transport/{platform}/ 内的文件名不再重复 platform
  ✓ transport/admin/route.go
  ✗ transport/admin/admin_route.go    （目录已经写明 admin，文件名重复冗余）
  ✗ module/auth/platform_route.go    （同包前缀代替分层，R2 禁止）
  ✗ module/user/app_handler.go       （同上）

transport 包导出统一函数 Register
  ✓ admin.Register(r, deps)
  ✗ admin.RegisterAdminRoutes(r, deps)
  ✗ auth.RegisterPlatformRoutes(...)    （留给当前过渡，第一刀完成后消失）
```

### 5.4 service 跨平台规则

```text
service 方法签名带 Platform 入参（来自 enum）：
  func (s *Service) Login(ctx, in LoginInput) (LoginResult, error)
  type LoginInput struct {
      Platform enum.Platform   // app / admin / ...
      Account  string
      ...
  }

service 不区分平台行为时不写 if platform == admin
平台差异通过：
  1. auth_platforms 表读策略（登录方式/TTL/单端登录/...）
  2. transport presenter 映射响应字段
  3. transport handler 选择性挂 middleware（如 admin 才挂 RBAC）
```

### 5.5 transport 平台规则

```text
transport/{platform}/ 是该能力对该平台的全部 HTTP 表面：
  route + handler + request binding + presenter

transport.handler 不调 repository，只调 service
transport.handler 不直接读 redis / DB

每个 transport 包导出 Register(r *gin.Engine, deps)
bootstrap 在装配阶段显式调用：
  authsvc := auth.NewService(deps...)
  authadmin.Register(adminGroup, authsvc)
  authapp.Register(appGroup, authsvc)
```

### 5.6 service / repository 复用

```text
admin / app 都用一份 service
admin / app 都用一份 repository
若 admin / app 的查询条件差异巨大（例如 admin 看全部用户，app 只看自己），
  在 service 层用不同方法表达，不在 repository 写 if platform
```

---

## 6. user vs profile vs auth：同一张 users 表，三个能力

这是 codex 初稿最重要的纠偏点，单独成节。

### 6.1 三个能力的边界

```text
module/auth/        认证能力
  对象：身份核验（登录/登出/换 token/送验证码/会话/登录日志）
  数据：users 表（读账号信息），auth_platforms 表（读策略），user_sessions 表（写会话）
  平台：admin + app + 未来平台

module/profile/     当前用户自服务能力
  对象：登录人自己的资料（个人信息/头像/绑邮箱/改密/快捷入口）
  数据：users 表（读写自身记录），user_quick_entries 表
  平台：admin + app

module/user/        用户管理能力
  对象：管理者对其他用户的运营（列表/详情/状态变更/批量操作/导出）
  数据：users 表（读写任意记录），关联表
  平台：当前 admin 管理入口；其他平台未来扩展（如 merchant 看自己旗下用户）
```

### 6.2 为什么不是同能力不同入口

三者本来就是**不同能力共享同一张数据表**：

- 登录是登录，不是"用户管理的一个端点"
- 自服务有强权限收敛（只能改自己），与管理操作的权限模型本质不同
- 管理者列表 N 个用户与用户读自己的资料，业务规则、缓存策略、错误语义都不同

强行合成一个 module 会把三套规则塞进同一份 service，跨平台共用变成跨业务耦合。

### 6.3 共享数据的处理

```text
共享 users 表的读写不通过 import 别人的 repository 实现，而是：
- profile.Repository 和 user.Repository 各自查询 users 表
- 若有共用查询（如 GetByID），抽到 shared/repository 或保持各自实现（少量重复无害）
- auth.Repository 读 users 表做账号校验，不调用 user.Service
- 跨能力调用走 service 层接口，不直读对方 repository
```

---

## 7. shared 边界细则

### 7.1 shared/dict（核心升级）

#### 7.1.1 接口形态

```go
package dict

type Option struct {
    Value any    `json:"value"`
    Label string `json:"label"`
    Extra map[string]any `json:"extra,omitempty"`
}

type Tree struct {
    Value    any     `json:"value"`
    Label    string  `json:"label"`
    Children []Tree  `json:"children,omitempty"`
}

type Bundle map[string]any   // page-init payload，key = dict name

type Service interface {
    // 同步 enum 字典，永不报错
    Enum(name string) []Option

    // 异步 DB 字典，可能涉及 Redis 缓存
    DB(ctx context.Context, name string) ([]Option, error)

    // 树字典
    Tree(ctx context.Context, name string) (Tree, error)

    // page-init 一次拿一组
    PageInit(ctx context.Context, names ...string) (Bundle, error)

    // 失效缓存（DB 字典更新后调用）
    Invalidate(name string) error
}
```

#### 7.1.2 Provider 注册（在 bootstrap）

```go
dict.RegisterEnum("login_types", enum.LoginTypeOptions)
dict.RegisterEnum("platform", enum.PlatformOptions)
dict.RegisterDB("roles", roleRepo.AllOptions,
    dict.Cache{Key: "dict:roles:v1", TTL: 5 * time.Minute})
dict.RegisterTree("address", addressRepo.Tree,
    dict.Cache{Key: "dict:address:v1", TTL: 0})       // 0 = 永不过期，写时显式 invalidate
```

#### 7.1.3 模块 page-init 形态

```go
// transport/admin/handler.go
func (h *Handler) PageInit(c *gin.Context) {
    bundle, err := h.dict.PageInit(c, "status", "login_types", "roles")
    // 直接返回 bundle
}
```

模块**不**自己拼 option 数组，**不**自己缓存树字典，**不**自己决定 Redis key。

### 7.2 shared/enum

```text
跨域稳定常量 + label map 原始定义
仅常量与函数，不持有状态
不允许业务模块在自己包内重复定义 CommonYes/CommonNo/Platform 等
```

### 7.3 shared/validate

```text
go-playground validator 自定义 tag 集中注册
模块的 HTTP request struct 引用这些 tag，不在每个 route 单独 MustRegister
当前已有 tag 全部迁过来（platform_scope/captcha_type/login_type/...）
```

### 7.4 shared/setting

```text
system_settings 读取边界
强类型 key，含默认值
缓存策略统一（Redis key/TTL）
失效语义：写时通过 setting.Invalidate(key) 清缓存

模块不再到处写 settingRepo.Get("upload.token.ttl_minutes")
统一通过：
  ttl := setting.UploadTokenTTL(ctx)
  ttl := setting.CaptchaSlideTTL(ctx)
```

### 7.5 shared/response / apperror / pagination / i18n

```text
原 internal/response、internal/apperror、internal/i18n 迁过来
形态不变，只换位置
```

---

## 8. infra 边界细则（原 internal/platform/）

### 8.1 命名定位

```text
infra 是层名：运行时技术资源（业务代码 import 的、在 admin-api / admin-worker
            进程内实例化的外部 SDK / client / wrapper）

adapter 是角色名：infra 内某些"多供应商可切换 / 有隐式 port"的实现
              典型例子：
                infra/payment/alipay      支付网关，未来可能加 wechatpay
                infra/storage/cos         对象存储，未来可能加 oss/s3
                infra/ai/openai           chat model，已经多家
                infra/realtime            发布协议，多 backend 切换
              非典型（不叫 adapter，叫 wrapper）：
                infra/database            就一个 GORM
                infra/redis               就一个 client
                infra/logging             就一个 slog
```

### 8.2 内容规则

```text
infra 持有外部资源 client / SDK 适配，仅此而已
infra 不知道业务模型
模块通过依赖注入拿 infra，不自建 client / 不 import SDK

业务相关的 helper 不进 infra：
  例：CertificateStorage 当前在 internal/platform/payment，
      因为它知道"证书路径规则"——这属于业务，应在 module/payment

infra 的判定标准（两条都必须 yes 才进 infra）：
  - 是否被 Go 业务代码 import？
  - 是否在 admin-api / admin-worker 进程中被实例化或调用？

infra 不放（这些属于 internal/ 之外）：
  - CI / 部署脚本 / k8s manifest
  - Terraform / Pulumi 等 IaC
  - Prometheus 配置 / Grafana 面板 / runbook
  - 仅文档 / 仅 README 的目录
```

### 8.3 为什么是 infra 而不是 adapter（与 codex 的协议存档）

```text
反对 adapter 作层名的核心论证：
  adapter 在架构语境里意味着 "domain 定义 port，adapter 实现 port"。
  本项目 service 直接注入 *gorm.DB / *redis.Client，没有 port 定义。
  把整层叫 adapter 等于声称一个项目没做的 ports & adapters 契约。

infra 的优势：
  1. 事实描述，不声称契约：infra = "运行时技术资源"，是说事实
  2. 留出 adapter 作为角色名：真正多供应商切换的地方仍可叫 adapter
  3. 未来若引入 hexagonal port，adapter 这个词没被占，可以原位使用

存档原因：避免下次新人/LLM 来问"为什么不叫 adapter"时重新讨论一次。
```

---

## 9. module 重新聚合表（36 → ~19）

| 当前 module | 目标归属 | 说明 |
|---|---|---|
| auth | module/auth/ | 保留，加 transport/{admin,app}/；同包 platform_*.go 拆到 transport/app/ |
| captcha | module/auth/captcha.go | 滑块验证码归属认证副产品 |
| session | module/auth/session.go | 合并入 auth |
| usersession | module/auth/session.go | 合并入 auth（与上一行同目标文件） |
| userloginlog | module/auth/loginlog.go | 登录日志是认证副产品 |
| authplatform | module/auth_platform/ | 改名加下划线；当前先有 admin 管理入口 |
| permission | module/permission/ | 当前先有 admin 管理入口，加 transport/admin/ |
| role | module/permission/role.go 或独立 module/role/ | 看复杂度决定（推荐合入 permission） |
| user | module/user/ | 用户管理能力，当前先有 admin 管理入口；同包 app_*.go 拆出，app 自服务迁到 profile |
| userquickentry | module/profile/quickentry.go | 自服务能力 |
| uploadconfig | module/uploadconfig/ | 当前先有 admin 管理入口 |
| uploadtoken | module/uploadtoken/ | admin + app |
| payment | module/payment/ | 保留 |
| wallet | module/payment/wallet/ | 作为 payment 子包；表共享、业务相邻 |
| notification | module/notification/ | 保留 |
| notificationtask | module/notification/task.go | 合并入 notification |
| mail | module/mail/ | 保留 |
| sms | module/sms/ | 保留 |
| aiagent / aichat / aiconversation / aiimage / aiknowledge / aimessage / aiprovider / airun / aitool | module/ai/{agent,chat,conversation,image,knowledge,message,provider,run,tool}/ | 9 个 module 合成 1 个 module/ai/，内部子包 |
| systemsetting | module/systemsetting/ | 保留 |
| systemlog | module/systemlog/ | 保留 |
| operationlog | module/operationlog/ | 保留 |
| crontask | module/crontask/ | 保留 |
| queuemonitor | module/queuemonitor/ | 保留 |
| clientversion | module/clientversion/ | admin + app |
| realtime | module/realtime/ | admin + app |
| exporttask | module/export/ | 改名 |
| system | module/system/ | 保留（health/readiness/ping），transport/public/ |
| —— | module/profile/ | **新增**：承接 user/app_*.go + userquickentry，admin + app |

聚合后约 19 个 module（含新增 profile），每个目标清晰、单数命名、能跟旧 PHP 设计的 `module/{User,System,Pay,Ai}` 分组对得上。

---

## 10. 现有反例 → 目标形态映射

| 当前形态 | 反例点 | 目标形态 |
|---|---|---|
| `/api/Users/getLoginConfig` 等 POST 旧路由（auth/route.go:21-26）| legacy compat 路由，未上线项目不需要 | **删除**，前端跟着改 |
| `/api/Users/init`（user/route.go:13-14）| 同上 | **删除** |
| `module/auth/{platform_route.go, platform_handler.go, platform_dto.go}` | 同包前缀代替目录分层 | `module/auth/transport/app/` 重组 |
| `module/auth/{route.go, handler.go, dto.go, request.go}` | 同包 admin 入口混在根目录 | `module/auth/transport/admin/` 重组 |
| `module/user/{app_handler.go, app_dto.go, app_route_test.go}` | 同包 admin+app 混杂 | admin 部分进 `module/user/transport/admin/`；app 自服务部分迁到 `module/profile/transport/app/` |
| `module/user/route.go` 内挂 4 类前缀（admin users / admin profile / app users / app profile） | 单文件挂多平台 | 按能力拆 user / profile，各自 transport/{platform}/ |
| `internal/module/authplatform/`（驼峰）| 命名风格不一致 | `module/auth_platform/` |
| `internal/module/aichat, aiagent, ...` 9 个 | 大领域被切碎 | `module/ai/{chat,agent,...}/` |
| `internal/module/{userloginlog, usersession, userquickentry, session}` | "user/session" 词被滥用 | 按职责拆到 auth / profile |
| `internal/dict/dict.go`（函数集合）| 不是统一服务 | `shared/dict/` Service + Registry |
| `internal/platform/`（命名冲突）| 与业务平台同名 | `internal/infra/`（详见 §8） |
| `internal/module/captcha/` | 不是独立能力 | 合入 `module/auth/captcha.go` |
| `docs/architecture/04-go-backend-framework.md:11-22` 的 `api/domain/shared/platform` 4 层目标 | 与本 spec 冲突 | 该文件按本 spec 重写 |

---

## 11. 回应 codex 原稿六个问题

**Q1**：Go 项目是否应该直接从 `internal/module` 迁到 `api/domain/shared/platform`？
**A1**：**不**。保留 `internal/module/{capability}/`，平台差异下沉到模块内 `transport/{platform}/`。理由：

- service 已经天然跨平台（service 入参带 `platform string`，admin/app 共用一份），抽 domain 是空抽象
- CRUD-heavy 项目跨大目录改字段成本太高（要改 api/admin + api/app + domain 三处）
- 模块=能力的短路径阅读体验是项目当前最大优势，不应放弃

**Q2**：api 按平台分 + domain 按业务分，这个边界适合 Gin + 当前项目规模？
**A2**：**不适合**。CRUD-heavy + 跨平台字段改动高频的项目，强制 HTTP 与业务跨大目录分离会让日常修改成本变高。本 spec 用 `transport/{platform}/` 子目录实现平台隔离，不抽 domain 大层。

**Q3**：shared/dict 是做成 Service + Registry，还是函数 + 集中 page-init assembler？
**A3**：**Service + Registry**（见 §7.1）。函数 + assembler 不能管理缓存策略、失效边界、异步 DB 字典；写到一半还是要回头做 Service。

**Q4**：admin user 和 app user 共享同 users 表，还是 domain 层定义 Account/User/Profile 三个概念？
**A4**：**同 users 表，但 3 个不同 module**（见 §6）：

- `module/user/`：用户管理能力，当前先有 admin 管理入口；未来其他平台入口仍从本能力扩展
- `module/profile/`：当前用户自服务（admin + app）
- `module/auth/`：认证（admin + app）

这三件事本来就不是"同能力不同入口"，是不同能力共享同一张数据表。

**Q5**：`internal/platform` 改名 infra？
**A5**：**改名，但不叫 adapter，叫 infra**（详见 §0.4 + §8.3）。adapter 是 hexagonal 模式里的角色名，project 没做 ports & adapters，叫 adapter 名实不符。`infra` 描述事实（运行时技术资源），adapter 作为角色名保留给多供应商场景（如 `infra/payment/alipay`）。

**Q6**：第一刀切 dict 还是 auth？
**A6**：**auth**。第一刀的目的是确立"一个能力服务多平台"的样板。Dict 是叶子服务，再小风险也不验证核心命题。Auth 跑通后，所有 module 按样板推。

---

## 12. 迁移路线（每一刀都是一个独立 plan）

### 12.1 第一刀：auth 样板 + 同步清理 `/api/Users/*`

**范围**：

文档：

- 根架构文档新增 `docs/architecture/00-platform-and-module-rules.md`，写入 R1-R8
- `docs/architecture/04-go-backend-framework.md` 与 `05-development-quality-rules.md` 中跟本 spec 冲突的段落删除/重写
- `admin_back_go/docs/architecture.md` 中 legacy/compat 段落删除

代码（auth 模块重组）：

- 新建 `module/auth/transport/admin/`，把 `module/auth/{route.go, handler.go, request.go, dto.go}` 内容拆入
- 新建 `module/auth/transport/app/`，把 `module/auth/{platform_route.go, platform_handler.go, platform_dto.go}` 内容拆入，去掉 `platform_` 前缀
- `module/auth/service.go` 保留在 module 根（admin+app 共用）
- 合并 `internal/module/captcha/` → `module/auth/captcha.go`
- 合并 `internal/module/session/` → `module/auth/session.go`
- 合并 `internal/module/usersession/` → `module/auth/session.go`（与上条同文件，去重命名冲突）
- 合并 `internal/module/userloginlog/` → `module/auth/loginlog.go`
- 删除 `internal/module/{captcha,session,usersession,userloginlog}/` 目录
- 删除 `module/auth/route.go:21-26` 的 `/api/Users/*` legacy POST 注册
- 删除 `module/user/route.go:13-14` 的 `/api/Users/init` legacy POST 注册
- 删除 `module/user/handler_test.go` 内 `/api/Users/init` 用例
- `internal/server/router.go` 改为分别调用 `authadmin.Register` 和 `authapp.Register`

**验收**：

- admin smoke + app smoke 全过
- `grep -r "platform_handler\|platform_route\|platform_dto" internal/module/` 返回空
- `grep -r "RegisterPlatformRoutes" internal/` 返回空
- `grep -r "/api/Users" internal/` 仅在被删除测试外不再出现
- `ls internal/module/{captcha,session,usersession,userloginlog}` 全部不存在
- `module/auth/` 根目录不再含 `route.go` / `handler.go`

### 12.2 第二刀：shared/dict 服务化

**范围**：

- `internal/dict/` → `internal/shared/dict/`
- 实现 Service + Registry（§7.1）
- 在 bootstrap 注册当前所有 dict provider
- 选 1-2 个 module（例如 user / system_setting）接入，作为样板
- 删除模块内自拼 option 的代码

### 12.3 第三刀：小型 module 套 transport/{platform}/ 壳

**范围**：把所有当前直接挂路由的 module（permission / auth_platform / system_setting / system_log / operation_log / cron_task / queue_monitor / uploadconfig / uploadtoken / clientversion / realtime / system / ...）依次显式放入 `transport/{platform}/`。

注意：这里的 `admin` 只是**当前暴露面**，不是 admin-only 分类。一刀一个 module，每刀都过 smoke。

### 12.4 第四刀：内部子包聚合 + profile 拆分

**范围**：

- `aiagent/aichat/aiconversation/aiimage/aiknowledge/aimessage/aiprovider/airun/aitool` 9 个 → `module/ai/` 子包
- `notificationtask` 合并入 `notification`
- `user/app_*.go` + `userquickentry` → 新建 `module/profile/`，承接 admin+app 自服务
- `module/user/` 收敛为纯用户管理能力（transport/admin/）

### 12.5 第五刀：rename + 大清理

**范围**：

- `internal/platform/` → `internal/infra/`
- 全部 import 路径替换（admin_back_go/internal/platform → admin_back_go/internal/infra）
- 同时按 §8.1 区分 wrapper vs adapter：
  - 单一实现的（database/redis/logging/...）目录名不动，仅迁路径
  - 多供应商的（storage/payment/ai/mail/sms/realtime）目录名不动，但在注释/README 内标注"adapter"角色
- 重写 `admin_back_go/docs/architecture.md`（精简到 < 500 行，按本 spec 重写）
- `docs/architecture/04-go-backend-framework.md` 与 `05-development-quality-rules.md` 按本 spec 校订

### 12.6 完成态验收

```text
internal/module/ 下所有 module 名都是单数、无平台前缀、含 transport/{platform}/
internal/shared/ 下 dict/enum/validate/i18n/response/apperror/pagination/setting 齐全
internal/infra/ 下只有运行时技术资源（client / SDK / wrapper / adapter），无业务逻辑
internal/platform/ 目录不存在
grep -ri "legacy" internal/ 返回空（注释与变量名扫净）
grep -ri "compat" internal/ 返回空
grep -ri "fallback" internal/ 只在外部资源探测代码中出现，不再作为业务边界
grep -r "admin_back_go/internal/platform" 返回空（全部 import 已替换）
没有 module 命名带平台前缀
没有 module 根目录下的 route.go / handler.go
没有"裸 transport"（transport/route.go 而非 transport/{platform}/route.go）
没有同包内 platform_*.go / app_*.go 文件前缀
```

---

## 13. 验收标准

本 spec 通过的标准：

```text
1. 项目定位明确：多平台后端，无 legacy 框架性概念，capability 不绑定平台
2. 8 条硬规则（R1-R8）写进根架构文档
3. 目标目录结构 module / shared / infra 含义清晰、无歧义
4. infra vs adapter 的层/角色区分写明（§8.1 + §8.3），不再混用
5. 现状快照（§2）准确反映代码事实，没有提到不存在的模块
6. 现有 36 个 module 有明确的目标归属表（§9）
7. 第一刀范围 = auth + /api/Users 清理 + 文档，可验证
8. codex 原稿六个问题有直接答案，无暧昧
9. 给任何 LLM 或人类协作者看时，能围绕同一套概念讨论
```

---

## 14. 风险与回滚

### 14.1 第一刀风险点

```text
R-1. auth 同包内 platform_* 拆出时，service / 内部辅助函数可能被两侧依赖
     缓解：service.go 保持 module 根级，admin/app 两侧 transport 都依赖根级 service
     回滚：保留改造前的 platform_*.go 备份分支，问题严重时整刀回退

R-2. captcha / session / usersession / userloginlog 合并入 auth 会产生命名冲突
     缓解：先按文件名加前缀（loginlog_xxx, session_xxx）避免冲突，再分批改名
     回滚：每个合并操作独立 commit，可单点 revert

R-3. /api/Users/* 删除后前端如果还有引用会 404
     缓解：删除前 grep admin_front_ts / admin_app 仓库，列出所有引用，前端 PR 同步
     回滚：第一刀完成前不上线
```

### 14.2 第五刀风险点

```text
R-5a. internal/platform/ → internal/infra/ 改名涉及全仓 import 替换
      缓解：用 gofmt-aware 工具（gorename 或 goimports）批量替换，避免字符串 sed 误伤
      回滚：单 commit，问题严重时单点 revert

R-5b. wrapper 与 adapter 的语义区分如果在 review 中产生分歧
      缓解：以 §8.1 表格为准，不在 PR 内重新讨论
      回滚：不影响功能，命名争议可后续 PR 调整
```

### 14.3 整体回滚策略

- 每一刀独立 plan，独立 PR，独立 smoke
- 任意一刀失败 = 该刀 PR revert，不影响已合并的前序刀
- 不在主干跑半成品的 transport/{platform}/ 结构（要么完整套上，要么不改）

---

## 15. 待 codex / 用户共同确认的开放点

下面几条非阻塞，可在 plan 阶段微调：

```text
O1. role 是独立 module 还是 permission 的子文件？
    本 spec 默认合入 permission；若 role 业务复杂度未来明显独立，再拆。

O2. wallet 是 payment 子包还是独立 module？
    本 spec 默认 module/payment/wallet/ 子包；理由：表事实和业务流深度耦合（充值入账、扣费）。

O3. mail/sms 是否合并为 module/messaging？
    本 spec 默认保留独立。两者业务规则、SDK 适配、模板系统差异较大。

O4. shared/dict 的 Bundle 形态 map[string]any vs typed struct？
    本 spec 选 map[string]any（柔性，page-init 灵活）；若希望强类型，可在第二刀讨论。

O5. transport 包是否在 init() 注册路由，还是 bootstrap 显式 import？
    本 spec 选 bootstrap 显式 import + 调用 Register（编译期可控、可测试）；
    init() 注册有"导入即注册副作用"的可读性问题，不采用。

O6. module 内部 jobs.go 与全局 internal/jobs/ 关系？
    本 spec：module/{cap}/jobs.go 定义该模块自己的 task 构造与 handler；
    internal/jobs/registry.go 仍是全局注册入口（保持薄），bootstrap 显式 import 各 module 调用 RegisterJobs(mux)。

O7. system module 的 transport 平台标签用 public 还是 admin？
    本 spec 选 transport/public/，因为 health/ping 不绑定业务平台（admin/app 都可探活）。
    若坚持只走 admin 暴露面，改为 transport/admin/ 亦可。

O8. infra/ 下的目录是否需要强制区分 wrapper / adapter 命名？
    本 spec 不强制目录名带后缀（如 alipay_adapter/），区分通过 §8.1 表 + 注释表达。
    理由：目录名加角色后缀会冗长且未来切换角色时要改名；写在文档里足够。
```

---

## 16. 自检（writing-spec self-review）

- **占位符检查**：无占位符或“稍后讨论”标记。
- **事实地基**：§2 现状快照基于实际代码（`internal/module/` 36 项、`module/auth/platform_*.go` 文件、`/api/Users/*` 路由位置、`internal/platform/` 18 个子目录）逐项核对，未提及不存在的 `appauth` 目录。
- **内部一致性**：R1-R8 硬规则与 §4 目录结构、§5 transport 细则、§8 infra 边界、§9 重新聚合表、§10 反例映射、§12 迁移路线相互对应，未发现矛盾。
- **范围检查**：本 spec 聚焦"多平台后端边界"。不涉及 CI/CD、不涉及前端目录、不涉及测试框架重选 — 范围合适，可由一份 plan（auth 第一刀）启动。
- **歧义检查**：
  - "平台" 一词全文统一指业务平台（admin/app/...），技术资源用 "infra" 表达。
  - "infra" 是层名，"adapter" 是 infra 内某些实现的角色名（§8.1）。
  - "module" 一词仅指 `internal/module/{capability}/`，不再有"过渡 module"等模糊用法。
  - "legacy" 一词在本 spec 内只在批判语境出现，不作为架构概念。
  - "admin only" 不再用于 capability 描述，统一替换为"当前 admin 管理入口"。
- **YAGNI**：未提前为 merchant/openapi/miniapp 写代码层；只通过 `transport/{platform}/` 留扩展点，不引入抽象基类。也不强制引入 hexagonal port，仅在真正多供应商场景用 adapter 角色名。
- **第二轮校订完整性**：
  - codex 注入 A（capability 不绑定平台）已贯穿 §1.2 / §1.3 / §3.2 R3 / §4 目录注释 / §9 / §12.3。
  - codex 注入 B（infra 是层 / adapter 是角色）已贯穿 §0.4 / §1.2 / §1.3 / §3.1 / §4 / §8 / §10 / §11 Q5 / §12.5 / §12.6 / §15 O8 / §16。

---

## 附：与 architecture.md 的关系

本 spec 通过后：

1. `admin_back_go/docs/architecture.md` 需要按本 spec 重写（精简到 < 500 行，删除全部 legacy 段落）。
2. `E:/admin_go/docs/architecture/04-go-backend-framework.md` 与 `05-development-quality-rules.md` 中跟本 spec 冲突的条目需要同步更新（在第五刀完成）。
3. 根架构文档（`E:/admin_go/docs/architecture/`）补一份 `00-platform-and-module-rules.md`，把 R1-R8 写进去作为项目级硬规则。

