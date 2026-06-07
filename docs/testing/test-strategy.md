# Admin Go Rewrite Test Strategy

状态更新时间：2026-06-07

本文定义测试和验证门禁。它不是建议，是后续迁移模块的交付标准。

## Test levels

| Level | Scope | When to run | Must be fast? | External services |
| --- | --- | --- | --- | --- |
| Unit tests | Go service/repository boundary, Vue API/helper/component logic | 每个后端/前端模块改动后 | yes | 默认不依赖真实 MySQL/Redis，除非测试目标就是 repository/runtime integration |
| Targeted integration | 指定 Go 包、指定 Vue lint/typecheck/vitest | 每个窄切片收口 | yes | 只碰当前切片需要的依赖 |
| Basic smoke | `/ready` dependency shape、登录、captcha、session、users/me、用户管理只读、RBAC 最小闭环、login log queue、WebSocket connect/ping/pong | 每个核心改动后 | yes | 真实 MySQL/Redis |
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

Smoke is not pre-push. Smoke 证明真实运行链路，pre-push 只做轻量 hook gate；默认 pre-push 规则见 `docs/testing/pre-push-gates.md`。

当前 smoke 脚本会自己启动临时后端进程，但只自动导入仓库根 `admin_back_go/.env` 这个兼容入口；它不会自动读取 Docker-first 的 `deploy/docker-first/admin-go.env`。本项目默认不维护仓库根 `.env`，所以跑 smoke 前要在当前 shell 显式提供 `MYSQL_DSN`、`REDIS_ADDR`、`APP_SECRET` 等运行 env。

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
go test -race ./internal/module/auth ./internal/infra/taskqueue ./internal/infra/scheduler ./internal/infra/realtime ./internal/module/realtime ./internal/jobs ./internal/bootstrap
```

当前 Windows 环境注意：

```text
race detector 依赖 cgo。若本机未安装 gcc，会失败：
cgo: C compiler "gcc" not found

这种失败不是业务测试失败，但不能伪装成 race 已通过。报告时必须原样说明。
```

## Mandatory gates by change type

验证矩阵以本文为准；`docs/README.md` 只做入口摘要，不复制完整 gate。

| Change type | Mandatory commands |
| --- | --- |
| Go package code | `go test <touched packages>` + `go test ./...` + `go vet -p=1 ./...` |
| Go queue/scheduler/session/cache/realtime | 上面全部 + `go test -race <touched concurrent packages>`，若缺 gcc 必须报告阻塞 |
| API contract | 从 `E:/admin_go/admin_back_go` 运行 `powershell -ExecutionPolicy Bypass -File .\scripts\check-contract.ps1` |
| Smoke script | 从 `E:/admin_go/admin_back_go` 实跑 `basic-admin-smoke.ps1` 或 `full-admin-smoke.ps1` |
| Vue API/types/view | `npx vue-tsc -b --pretty false` + targeted `npx eslint ...` |
| Vue public component/router/store/request | 上面全部 + `npm run build` |
| Documentation only | `git diff --check` + `powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working`，并确认没有把 planned 写成 implemented |

Documentation-only gate 只证明 diff 空白/治理规则和文档措辞，不证明 Go/Vue runtime、Docker readiness 或 smoke 通过。只要文档声明了 runtime 行为，就必须引用已有验证证据或重新跑对应验证。

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
