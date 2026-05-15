# Development Quality Rules

## 结论

这个项目不允许靠“兜底字段”“兼容猜测”“全 POST”“any TS”堆出一个看似能跑、实际不可维护的 admin。

要重构，就写清楚契约；要兼容，就显式写 adapter；要替换旧链路，就一条真实链路一条真实链路收。

## Linus 三问

每次加接口、字段、前端调用、缓存、日志前先问：

```text
1. 这是解决真实问题，还是在给未知情况铺垃圾兜底？
2. 能不能用更简单、更明确的契约表达？
3. 会不会破坏已有登录、菜单、权限、前端路由或用户数据？
```

答不清楚就查运行时和旧系统事实，不准猜。

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
显式 legacy adapter，例如 /api/Users/init -> service -> repository
显式兼容边界，例如新页面走 request，保留 adapter 只服务未收口旧调用
对外部不可信输入做严格校验后拒绝
```

规则很简单：**兼容必须有名字、有边界、有删除计划；静默兜底就是垃圾代码。**

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

旧 action POST 接口只能作为 legacy mapping 文档或显式 adapter，不能污染新 REST 设计。

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
internal/enum     # 跨模块稳定常量和 IsXxx 判断
internal/dict     # enum -> 前端 dict option
internal/validate # Gin binding / go-playground validator 自定义 tag
```

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
internal/platform/taskqueue  # Asynq 封装
internal/platform/scheduler  # gocron/v2 封装
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
前端被触碰代码无 any
有最小测试
有可复现 smoke 或构建验证
```

没有验证，不准说完成。
