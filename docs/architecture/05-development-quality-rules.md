# Development Quality Rules

## 结论

这个项目不允许靠“兜底字段”“兼容猜测”“全 POST”“any TS”堆出一个看似能跑、实际不可维护的 admin。

当前架构口径是 new-system-first / multi-platform-first：这是新 Go/Vue 多平台系统，不是 legacy migration。要重构，就写清楚契约；要接入新平台，就先定 `module/{capability}/transport/{platform}` + `shared` + `infra` 边界；要替换不合理链路，就一条真实链路一条真实链路收。

## Linus 三问

每次加接口、字段、前端调用、缓存、日志前先问：

```text
1. 这是解决真实问题，还是在给未知情况铺垃圾兜底？
2. 能不能用更简单、更明确的契约表达？
3. 会不会破坏已有登录、菜单、权限、前端路由或用户数据？
```

答不清楚就查运行时和旧系统事实，不准猜。

## Superpowers and TDD 默认规则

新行为、行为变更、bugfix、refactor 默认按 Superpowers 流程推进。

```text
需求不清或要设计新行为 -> brainstorming
设计认可后 -> spec
spec 认可后 -> implementation plan
进入实现 -> TDD
```

实现阶段默认 TDD：

```text
先写最小失败测试
确认失败原因正确
再写最小生产代码
确认测试通过
再重构
```

docs-only governance changes do not require backend/frontend runtime tests, but they still require `git diff --check` and governance checks.

## AI 自主解题规则

AI 默认自己解决问题，不把可以查证的事情抛回给用户。

默认先查：

```text
docs/status/current-status.md
docs/contracts/*
docs/architecture/*
runtime docs
git diff / git status
targeted tests
logs and smoke output
official vendor docs when the behavior is tool/provider-specific
```

需要问用户：

```text
真实不可逆业务选择
需要生产凭据、账号、支付后台或第三方控制台操作
会删除数据或改变线上状态
多个产品方案无法从现有规则推出
用户明确要求先确认
```

不需要问用户：

```text
文档归属
路径命名
轻量验证命令
是否先读 current-status
是否先查官方 Codex/OpenAI docs
是否遵守 TDD
是否补必要注释
```

## 禁止兜底字段

禁止：

```text
后端同时接受 id / ids / permission_id / permissionIds，只为“保险”
前端同时读 user_id / userId / id，只为“兼容”
接口缺字段时静默补默认值，让错误数据继续流动
后端返回未定义字段给前端猜
前端用 Record<string, any> 吞掉后端契约
用 ?? [] / ?? {} 掩盖接口契约漂移
```

允许：

```text
业务上明确的默认值，例如新增根菜单 parent_id=0
历史路径在当前运行时仍存在时，必须显式标注为待治理事实，不能作为新设计模板
显式平台入口边界，例如 admin/app 分别在 `transport/{platform}` 表达，再调用同一 capability 的 module service
对外部不可信输入做严格校验后拒绝
```

规则很简单：**新项目能力必须有明确 owner、边界和验证证据；静默兜底就是垃圾代码。**

## RESTful API 规则

新 Go API 统一使用：

```text
/api/{scope}/v1/<resource>

当前后台管理端：/api/admin/v1/<resource>
未来用户应用端：/api/app/v1/<resource>
```

方法语义固定：

```text
GET    /api/admin/v1/permissions             list/query
GET    /api/admin/v1/permissions/:id         detail
POST   /api/admin/v1/permissions             create
PUT    /api/admin/v1/permissions/:id         replace/update
PATCH  /api/admin/v1/permissions/:id/status  partial state change
DELETE /api/admin/v1/permissions/:id         delete one
```

禁止：

```text
新接口继续 /api/admin/Xxx/list 全 POST
把动作塞进 URL：/add /edit /del /status
为了省事让一个 POST 根据 field 决定所有行为
让前端先定义后端契约
```

旧 action POST 形态如果仍在当前运行时出现，只能作为待治理事实记录，不能污染新 REST 设计。

## 多平台入口不复制业务模块

admin/app/openapi/merchant 是业务 platform 入口，不是复制业务包的理由。新增端、平台、入口时先判断差异属于哪一层：

不要把任何业务能力定义成长期 `admin-only`。当前只有 admin 入口，只是当前暴露面，不是能力边界；未来 app / openapi / merchant 等入口仍应在同一 capability 下扩展。

| 差异类型 | 落位 |
|---|---|
| route prefix 不同 | `transport/{platform}` 的 `route.go` |
| 请求字段不同 | `transport/{platform}` 的 `request.go` |
| 返回字段不同 | `transport/{platform}` 的 `presenter.go` |
| 认证/会话策略不同 | auth 模块策略 + `auth_platforms` 表 |
| 业务规则不同 | module service 显式 policy/input |
| 跨领域公共数据 | `shared/dict` 或 `shared/setting` |
| 外部 SDK/技术资源差异 | `infra` |

禁止为了端差异复制业务模块：

```text
appai / appwallet / xxauth / adminai
```

平台不是业务复制理由。新增平台不得默认新增 `xxxauth` / `xxxuser` / `xxxupload` 这类平台命名业务模块；`/api/app/v1` 这类路径差异优先通过 `transport/{platform}` 的 route/request/presenter 表达；认证会话走 auth 模块策略 + `auth_platforms` 表；业务能力进入 module service，共享能力进入 shared，技术资源进入 infra。

## 公共能力先归 shared

字典、枚举、校验、系统配置、分页、错误、i18n 都是跨领域公共能力。新增或触碰这类能力时，先判断是否属于 shared，不要顺手塞进业务 module。

`dict` 特别规则：

```text
字典是统一公共服务，不是每个业务 module 自己手写 option 的工具角落。
```

禁止：

```text
业务 module 重复手写 common status / platform / login type options
业务 module 自己决定共享树形字典 Redis key
业务 module 自己解释同一个 system_settings key 的默认值
```

允许：

```text
module service 暴露业务候选项查询
shared/dict 统一组装前端字典形态
shared/setting 统一拥有仍属于 system_settings 的 typed key 默认值、范围和缓存失效写入
transport/{platform} page-init 只声明需要哪些字典和业务 options
```

当前已迁移 typed keys：

```text
auth.captcha.ttl_minutes
upload.token.ttl_minutes
```

`internal/module/systemsetting` 是后台 CRUD，不是这些已迁移 key 的跨模块读取边界。

验证码发送 TTL 不再属于 system_settings：邮件渠道使用 `mail_configs.verify_code_ttl_minutes`，短信渠道使用 `sms_configs.verify_code_ttl_minutes`。

## TypeScript 规则

前端新代码和被触碰代码必须完整 TypeScript。

禁止：

```text
any
as any
Record<string, any>
接口 DTO 继承 Record<string, unknown> 来吞未知字段
未定义响应类型直接消费接口返回
为了过编译扩大类型到 unknown 后到处强转
```

允许：

```text
unknown 只用于真正未知的外部边界，必须在边界处收窄
判别联合类型表达不同业务形态
明确的 DTO / query / payload / response 类型
```

前端 API 层必须是契约翻译层，不是字段猜测层。

## Full-stack i18n 默认规则

新模块默认就是 i18n 模块。不要等页面写完、接口写完、用户截图骂完再“补国际化”。

后端规则：

```text
Gin middleware 顺序保持 CORS -> I18n -> AuthToken。
语言来源只读 Accept-Language；支持 zh-CN / en-US；默认 zh-CN。
response 是 HTTP { code, data, msg } 的唯一 msg 本地化边界。
错误消息用 apperror.*Key，不能只丢中文 fallback。
成功消息用 response.OKWithMessageKey，不能靠 OKWithMessage 长期吃 legacy fallback。
新增模块必须维护 internal/shared/i18n/locales/zh-CN/<module>.yaml 和 internal/shared/i18n/locales/en-US/<module>.yaml。
缺翻译 key 可以返回 fallback，不能 panic；但完成态必须跑 i18n coverage。
```

后端新模块至少验证：

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/shared/i18n -count=1
go test ./internal/module/<module> -count=1
```

前端规则：

```text
Vue 组件和只从 <script setup> 调用链内执行的页面/组件 composable 用 useI18n().t。
store / util / API client / router guard / module-scope helper 用 src/i18n 导出的 i18n.global.t，不能依赖组件实例。
新增可见文案必须同时更新 src/i18n/locales/zh-CN.ts 和 src/i18n/locales/en-US.ts。
菜单、按钮、表格列、搜索 label、弹窗标题、确认文案、空状态、错误提示都算可见文案。
HTTP 继续通过 lang Cookie 产生 Accept-Language，不在页面里自造语言状态。
```

前端新模块至少验证：

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/i18n/literal-i18n-keys.test.ts tests/shared/i18n/no-visible-chinese.test.ts
npx vue-tsc -b --pretty false
```

允许例外：

```text
DB labels、历史日志、用户输入、第三方原始错误、AI prompt/content 不当成业务可见文案强翻译。
旧模块遗留裸中文可以分批收，但新写和 touched code 不准继续扩大问题。
```

## Frontend CRUD 公共组件规则

标准 CRUD 页面不要手搓。项目已经有自己的表格、搜索、弹窗和 CRUD hook。

默认组合：

```text
Search      -> E:\admin_go\admin_front_ts\src\components\Search
AppTable    -> E:\admin_go\admin_front_ts\src\components\Table
AppDialog   -> E:\admin_go\admin_front_ts\src\components\AppDialog
useCrudTable -> E:\admin_go\admin_front_ts\src\hooks\useCrudTable.ts
useTable    -> E:\admin_go\admin_front_ts\src\components\Table\src\useTable.ts
```

规则：

```text
CRUD 页面默认使用 Search + AppTable + AppDialog + useCrudTable。
只读列表默认使用 Search + AppTable + useTable。
只读列表不准为了方便套 useCrudTable；useCrudTable 只给真正有 create/update/delete/status 语义的页面。
弹窗用 AppDialog，不直接写 el-dialog。
表格用 AppTable，不直接写 el-table。
搜索区域用 Search，不在页面里手写一组 el-form 当筛选表单。
表格行操作放 AppTable slot，按钮权限用 userStore.can(...)，不把权限判断散成临时变量猜。
```

允许例外：

```text
permission 矩阵、component/demo 展示页、非 CRUD 的定制矩阵/表格 widget 可以直接使用底层 Element 组件，但必须局部化、写清用途，并有 targeted test 覆盖。
普通 CRUD 页面仍然必须使用 Search + AppTable + AppDialog + useCrudTable。
普通只读列表仍然必须使用 Search + AppTable + useTable。
高度定制的只读操作页可以用 useTable，不用 useCrudTable，但 Search/AppTable/AppDialog 仍然默认必须用。
第三方组件必须被项目 wrapper 包住后再扩散，不在业务页直接铺开。
```

## Frontend page-card / body-card 布局规则

用户口中的 body-card，在当前 Vue shell 里就是 `Layout` 给路由页面套的 `page-card`。页面默认已经在卡片里，不准再套一层大卡片把高度链撑烂。

当前事实：

```text
src/views/Layout/index.vue 根据 route.meta.pageLayout 给 route view 加 page-card。
AppTable fixedFooter=true 时会给 ElTable 注入 height: 100%，父级必须提供稳定高度链。
移动端 page-card 是 auto height + min-height: 100%；桌面端 page-card 是 height: 100%。
```

规则：

```text
普通业务页默认不要新增外层 el-card / page-card / body-card。
表格页根节点必须 display:flex; flex-direction:column; height:100%; min-width:0; min-height:0; overflow:hidden。
Search 在上，AppTable 在下；AppTable 吃剩余高度，不让页面总高度超过 page-card。
多个面板页面使用轻量 div section，不用 el-card 叠卡片；需要视觉分区就写局部 panel class。
长内容滚动必须发生在 page-card 内部的具体内容区，不能撑破 Layout。
Dialog 长内容用 AppDialog 的 height + bodyPadding + 内部滚动，不让弹窗内容把页面撑高。
不要靠全局 :deep 和魔法 margin 修 page-card 溢出；先修容器高度链。
```

验证建议：

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/layout/page-layout.test.ts
npm run test -- <touched module test>
npx vue-tsc -b --pretty false
```

## 注释规则

AI 应该积极写有用注释，但不制造噪音。

应该写注释：

```text
非显然业务约束
事务、幂等、重试、队列、cron、WebSocket、AI provider 边界
安全、权限、跨仓、部署、运行时假设
为什么不能用更简单或更常见做法
临时兼容的退出条件和证据来源
```

不应该写注释：

```text
复述代码能直接看出的内容
没有 owner 或退出条件的待办注释
用注释掩盖坏命名
注释与 current-status / contract / runtime 不一致
把注释当测试或契约
```

验收口径：

```text
注释解释 why，不解释肉眼能看到的 what。
复杂边界没有注释是问题；无意义注释也是问题。
```

## Go 后端规则

Go 代码保持：

```text
route -> handler -> service -> repository -> model
```

禁止：

```text
handler 查 DB/Redis
service 依赖 gin.Context
repository 写业务决策
model 写业务方法
为了测试造无意义 interface
Java 风 ServiceImpl / Manager / Factory 污染 Go
```

允许 interface 的条件：

```text
真实有多个实现
或隔离外部系统：DB / Redis / queue / storage / AI client
```

### Enum / Dict / Validate

这些是基建，不是业务模块顺手写的私货。

```text
internal/shared/enum     # 跨模块稳定常量和 IsXxx 判断
internal/shared/dict     # enum -> 前端 dict option
internal/shared/validate # Gin binding / go-playground validator 自定义 tag
```

`internal/shared` 同时拥有 `apperror`、`response`、`i18n`、`enum`、`validate`、`dict`、`setting`。旧 root shared-like packages 不再存在；新代码不得 import `internal/{apperror,response,i18n,enum,validate,dict}`。

规则：

```text
handler 用 binding tag 拒绝明显非法入参
模块 HTTP request struct 放在 `internal/module/<name>/request.go`
service 再做业务规则校验
dict 必须从 enum 派生，不准页面或模块各写一份 label/value
validator tag 必须调用 enum.IsXxx，不准散落硬编码 oneof=...
验证码场景统一走 `enum.VerifyCodeScenes` + `verify_code_scene`，不准模块各写一份 login/forget/bind_phone
```

允许：

```text
业务模块保留更强的上下文校验，例如父级权限是否合法、admin 平台不能删除
```

禁止：

```text
每个 handler 自己手写一套 1/2、admin/app、password/email/phone
把 request struct 长期塞在 handler.go 尾部，导致入参层不可见
只靠前端 select 限制输入
把无效输入静默补默认值继续写库
```

## Upload 业务归属规则

上传是业务链路能力，不是独立业务幻想。

允许：

```text
先迁一个真实业务模块，再把它需要的图片/文件字段接到 upload token/client。
业务模块自己保存 object key/url、状态、权限和操作日志。
upload config / upload token 只做配置事实源和临时凭证签发。
```

禁止：

```text
为了“上传”单独新建无业务归属的 scene。
先做图片/文件上传页面，再倒推业务表。
让 uploadtoken 落业务引用或创建无主文件记录。
把 AI agent 头像、聊天附件、富文本图片这类场景脱离对应业务模块单独迁。
```

## 分布式未来

分布式是未来方向，但不是今天把系统拆烂的理由。

当前策略：

```text
先用 Gin modular monolith 跑通核心 admin
模块边界按未来可拆服务设计
接口使用 REST + 明确 DTO
审计日志、队列、AI sidecar 用清晰边界接入
需要跨进程时再拆，不为 PPT 拆
```

未来可拆的边界：

```text
auth/session
RBAC
operationlog
AI workflow
queue workers
notification
storage
```

现在不做微服务，但现在写的代码不能阻碍未来拆分。

### Queue / Scheduler 规则

异步任务不是自己手写 Redis list。当前统一使用：

```text
internal/infra/taskqueue  # Asynq 封装
internal/infra/scheduler  # gocron/v2 封装
internal/jobs                # 项目任务注册
cmd/admin-worker             # 独立 worker 进程
```

禁止：

```text
admin-api 里顺手启动 worker 或 cron
handler 里直接 asynq.NewClient / redis.LPush
cron job 直接写业务表，绕过 queue
没有幂等设计就把写操作丢进队列
任务 type 不带版本号
用 Redis queue 假装解决 DB 事务一致性
```

允许：

```text
scheduler 投递版本化 task
worker 消费 task 后调用 service
短期 at-least-once + 幂等 handler
强一致写路径后续引入 outbox
```

#### Job lane 规则

任务分层按 **业务所有权 + 队列 lane**，不要按 `fast/slow` 建目录。

```text
业务所有权：internal/module/<name>/jobs.go
系统任务：internal/jobs/system/*.go
注册入口：internal/jobs/registry.go
队列 lane：critical / default / low
```

当前任务少时允许先放在 `internal/jobs/noop.go` 这种单文件里；任务变多再拆目录。不要为了“看起来分层”制造空包。

`critical/default/low` 是运行时调度策略：

```text
critical # 短、急、不能被慢任务拖住
default  # 普通异步业务
low      # 慢、重、批量、AI/报表/导入导出
```

禁止：

```text
internal/jobs/fast
internal/jobs/slow
按速度给业务代码分包
让慢任务和登录/RBAC/操作日志抢同一个 worker lane
CPU 密集任务无限提高 QUEUE_CONCURRENCY
```

Go 的 goroutine 很轻，但不是免费 CPU。I/O 密集可以较高并发；CPU 密集必须限流、拆 low worker，必要时单独进程部署。

## 验收门槛

任何实现必须至少满足：

```text
有明确契约
没有静默兜底字段
新 Go API 是 RESTful
新增/触碰模块默认完成前后端 i18n
标准 CRUD 页面使用 Search + AppTable + AppDialog + useCrudTable
只读列表使用 Search + AppTable + useTable
页面内容不撑破 Layout page-card/body-card
前端被触碰代码无 any
有最小测试
有可复现 smoke 或构建验证
```

没有验证，不准说完成。
