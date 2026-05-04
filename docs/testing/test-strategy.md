# Admin Go Rewrite Test Strategy

状态更新时间：2026-05-04

本文定义测试和验证门禁。它不是建议，是后续迁移模块的交付标准。

## Test levels

| Level | Scope | When to run | Must be fast? | External services |
| --- | --- | --- | --- | --- |
| Unit tests | Go service/repository boundary, Vue API/helper/component logic | 每个后端/前端模块改动后 | yes | 默认不依赖真实 MySQL/Redis，除非测试目标就是 repository/runtime integration |
| Targeted integration | 指定 Go 包、指定 Vue lint/typecheck/vitest | 每个窄切片收口 | yes | 只碰当前切片需要的依赖 |
| Basic smoke | 登录、captcha、session、users/init、用户管理只读、RBAC 最小闭环、login log queue、WebSocket connect/ping/pong | 每个核心改动后 | yes | 真实 MySQL/Redis |
| Full smoke | basic + 较慢核心模块，例如 operation log read/delete | 阶段收口前 | no | 真实 MySQL/Redis |
| Release gate | 全量后端、前端 build、basic/full smoke、contract check、diff check | 声称稳定前 | no | 真实 MySQL/Redis |

## Backend unit-test policy

```text
handler test：验证 binding、HTTP status/response shape、错误映射，不直接测 SQL。
service test：表驱动测试业务规则、状态转换、缓存失效、队列投递策略。
repository test：只有 DB 行为重要时才写，例如唯一约束、软删除过滤、事务语义、复杂查询。
middleware test：验证 AuthToken / PermissionCheck / OperationLog 的 fail-closed 和执行顺序。
platform test：验证 queue/scheduler/redis/database wrapper 边界，不把 Asynq/gocron 细节泄漏给业务模块。
```

规则：

```text
handler 不直接访问 DB/Redis。
service 不依赖 gin.Context。
repository 不做业务判断。
队列 handler 必须幂等；Asynq 是 at-least-once。
阻塞路径必须接收 context.Context，并在超时/取消时退出。
```

## Frontend test policy

```text
typecheck 第一优先：npx vue-tsc -b --pretty false
每个迁移模块至少跑 targeted eslint。
API 层改动优先补/跑 vitest，验证 REST method/path/payload shape。
组件逻辑复杂时再写组件测试；纯布局小改不强行写测试。
触碰公共组件、路由、store、request 封装时必须跑 npm run build。
```

前端结构门禁：

```text
route-level index.vue 是组合层。
feature 子组件放 components/。
可复用或副作用重的逻辑放 composables/。
不引入 any / as any / Record<string, any>。
新 Go API 只用 request，不用 legacyRequest；legacy adapter 必须显式命名。
```

## Smoke policy

Basic smoke 保持快，只证明 admin 基础链路没断：

```powershell
cd E:/admin_go/admin_back_go
powershell -ExecutionPolicy Bypass -File .\scripts\basic-admin-smoke.ps1 `
  -Account 15671628271 `
  -Password 123456
```

Full smoke 可以慢，但必须清理所有临时数据，最终只输出 JSON summary：

```powershell
cd E:/admin_go/admin_back_go
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 `
  -Account 15671628271 `
  -Password 123456
```

失败规则：

```text
失败时保留 .tmp/ 日志。
不要吞错误重试到看似成功。
写库 smoke 必须只用临时数据；成功后清理，失败时让日志足够定位。
Basic smoke 不塞慢模块；慢模块进 full smoke。
```

## Race-detector policy

涉及这些包或能力时必须跑 race：

```text
auth/session/token cache
permission cache
taskqueue/scheduler/jobs/worker
realtime/WebSocket session manager
future AI streaming/cancellation
```

命令：

```powershell
cd E:/admin_go/admin_back_go
go test -race ./internal/module/auth ./internal/module/session ./internal/platform/taskqueue ./internal/platform/scheduler ./internal/platform/realtime ./internal/module/realtime ./internal/jobs ./internal/bootstrap
```

当前 Windows 环境注意：

```text
race detector 依赖 cgo。若本机未安装 gcc，会失败：
cgo: C compiler "gcc" not found

这种失败不是业务测试失败，但不能伪装成 race 已通过。报告时必须原样说明。
```

## Mandatory gates by change type

| Change type | Mandatory commands |
| --- | --- |
| Go package code | `go test <touched packages>` + `go test ./...` + `go vet -p=1 ./...` |
| Go queue/scheduler/session/cache/realtime | 上面全部 + `go test -race <touched concurrent packages>`，若缺 gcc 必须报告阻塞 |
| API contract | `powershell -ExecutionPolicy Bypass -File .\scripts\check-contract.ps1` |
| Smoke script | `basic-admin-smoke.ps1` 或 `full-admin-smoke.ps1` 实跑 |
| Vue API/types/view | `npx vue-tsc -b --pretty false` + targeted `npx eslint ...` |
| Vue public component/router/store/request | 上面全部 + `npm run build` |
| Documentation only | `git diff --check`，并确认没有把 planned 写成 implemented |

## Release gate

声称 “stable / 可以开始灌业务 / 基建收口” 前必须跑：

```powershell
cd E:/admin_go/admin_back_go
powershell -ExecutionPolicy Bypass -File .\scripts\check-contract.ps1
go test ./...
go vet -p=1 ./...
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\basic-admin-smoke.ps1 -Account 15671628271 -Password 123456
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account 15671628271 -Password 123456
```

```powershell
cd E:/admin_go/admin_front_ts
npx vue-tsc -b --pretty false
npm run build
```

如果 touched code 包含并发/queue/session/realtime/WebSocket/AI streaming，还要补 race gate；缺 gcc 时报告阻塞，不准写 “race passed”。

## Reporting format

每个阶段收口报告必须包含：

```text
Outcome:
Changed files:
Backend verification:
Frontend verification:
Smoke summary:
Known risks:
Next recommended step:
```
