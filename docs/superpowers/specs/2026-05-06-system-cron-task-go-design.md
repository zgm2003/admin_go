# System Cron Task Go Migration Design

## Linus 三问

1. 真问题：是。系统管理的定时任务页面仍走 PHP `legacyRequest -> /api/admin/CronTask/*`，但通知任务定时发送、支付超时关单、支付状态补查、对账等都依赖调度器。系统管理没闭环就继续迁业务，会把业务建在沙子上。
2. 更简单方法：不重写调度框架，不照搬 PHP 字符串执行 class。复用现有 `github.com/go-co-op/gocron/v2` + Asynq；新增 Go 版 `cron_task` 管理模块；把 `cron_task.name` 映射到 Go 代码注册的任务 registry。DB 只存配置和日志，代码 registry 才是真正可执行边界。
3. 会破坏什么：不能破坏现有通知任务发送链路、admin-worker 启动、queue monitor、cron_task 表数据和前端页面。未迁 Go 的 PHP handler 不能在 Go 里假装运行，必须显示“未接入”。

## Scope

本设计只做系统管理里的定时任务闭环：

```text
cron_task CRUD
cron_task_log read
admin-worker 启动时按 DB cron_task 注册 gocron job
schedule trigger 写 cron_task_log 并 enqueue versioned Asynq task
notification_task_scheduler 首个真实接入 Go registry
frontend CronTaskApi 从 legacyRequest 迁到 /api/admin/v1/cron-tasks
contract/status/smoke/docs 同步
```

不做：

```text
支付超时关单 Go handler
支付状态补查 Go handler
退款补查 Go handler
对账执行 Go handler
AI run timeout Go handler
聊天好友过期清理 Go handler
通用“用户自定义脚本执行”
动态加载 Go plugin
根据 DB handler 字符串反射执行代码
```

这些未迁任务本刀只展示为 `registry_status=missing` 或 `disabled`，不能加入 scheduler。

## Current Facts

前端当前仍是 legacy：

```text
admin_front_ts/src/api/system/cronTask.ts
  import { legacyRequest } from '@/lib/http'
  /api/admin/CronTask/init
  /api/admin/CronTask/list
  /api/admin/CronTask/add
  /api/admin/CronTask/edit
  /api/admin/CronTask/del
  /api/admin/CronTask/status
  /api/admin/CronTask/logs
```

DB 当前有这些任务：

```text
ai_run_timeout                 app\process\AiRunTimeoutTask
notification_task_scheduler    app\process\NotificationTaskScheduler
clean_expired_contact_request  app\process\CleanExpiredContactRequestTask
pay_close_expired_order        app\process\Pay\PayCloseExpiredOrderTask
pay_sync_pending_transaction   app\process\Pay\PaySyncPendingTransactionTask
pay_fulfillment_retry          app\process\Pay\PayFulfillmentRetryTask
pay_refund_sync                app\process\Pay\PayRefundSyncTask
pay_reconcile_daily            app\process\Pay\PayReconcileDailyTask
pay_reconcile_execute          app\process\Pay\PayReconcileExecuteTask
```

Go 当前已有底层框架：

```text
cmd/admin-worker
internal/platform/scheduler       # gocron/v2 thin wrapper
internal/platform/taskqueue       # Asynq wrapper
internal/jobs.RegisterSchedules   # static cron-to-queue hook
notification:dispatch-due:v1
notification:send-task:v1
```

问题：`RegisterSchedules` 现在静态注册 `notification-task-dispatch-due every 1m`，没有受 `cron_task` 管理页面控制，也没有写 `cron_task_log`。这会让页面状态和真实调度行为脱节。

## Architecture Decision

采用 **DB config + Go registry + queue task** 三段式：

```text
cron_task table
  -> crontask.Repository.ListEnabled()
  -> crontask.Registry.Lookup(task.name)
  -> scheduler.Cron(task.name, task.cron, withSeconds=true, taskFunc)
  -> taskFunc:
       logStart(cron_task_log status=running)
       build versioned Asynq task from registry entry
       enqueue task
       logEnd(success/failure)
  -> queue worker handler executes real business
```

关键点：

```text
DB 决定启用/禁用和 cron 表达式。
Go registry 决定哪些任务可执行。
scheduler callback 只 enqueue，不扫描业务表、不发通知、不做支付。
queue handler 才做业务。
cron_task_log 记录的是“调度触发/投递”结果，不冒充业务处理最终结果。
```

这符合现有架构：`admin-worker` owns queue + scheduler；`admin-api` 只提供 REST；业务慢活进 Asynq。

## Why Not Execute `handler` String

PHP 旧设计把 `handler` 写成 class path，例如 `app\process\Pay\PayCloseExpiredOrderTask`。Go 不能照搬：

```text
安全差：DB 字符串决定执行代码，权限边界烂。
可维护性差：重构函数名/包名时 DB 悄悄坏。
不可测试：无法在编译期发现 handler 丢失。
分布式差：不同 worker 版本可能解释同一个字符串不同。
```

Go 里 `handler` 只保留为展示字段/legacy provenance；可执行事实使用 `name` 查 registry。

## Data Model

沿用现有表，不先改表结构：

```text
cron_task:
  id
  name
  title
  description
  cron
  cron_readable
  handler
  status        # 1 enabled, 2 disabled
  is_del        # 1 deleted, 2 active
  created_at
  updated_at

cron_task_log:
  id
  task_id
  task_name
  start_time
  end_time
  duration_ms
  status        # 1 success, 2 failed, 3 running
  result
  error_msg
  is_del
  created_at
```

新增响应字段，不改表：

```text
registry_status: registered | missing | disabled | invalid_cron
registry_task_type: versioned Asynq task type, e.g. notification:dispatch-due:v1
registry_description: Go registry entry description
next_run_time: derived by cron parser/gocron helper; invalid returns '-'
```

## Registry

新增 `internal/module/crontask` 内的 registry，初始只注册一条真实任务：

```text
name: notification_task_scheduler
queue task: notification:dispatch-due:v1
queue: default
unique_ttl: 55s
summary: 扫描 pending/due notification_task 并投递 send-task
```

暂不注册 pay/ai/chat 任务。原因：对应业务 handler 尚未 Go 化，注册假任务比不注册更糟。

Registry entry 接口形状：

```go
type RegistryEntry struct {
    Name        string
    TaskType    string
    Description string
    BuildTask   func() (taskqueue.Task, error)
}
```

## Backend REST Contract

Base namespace：`/api/admin/v1`。

```text
GET    /cron-tasks/init
GET    /cron-tasks
POST   /cron-tasks
PUT    /cron-tasks/:id
PATCH  /cron-tasks/:id/status
DELETE /cron-tasks/:id
DELETE /cron-tasks
GET    /cron-tasks/:id/logs
```

Request/response 保持 `{ code, data, msg }`。

### Init

`GET /api/admin/v1/cron-tasks/init`

Response data:

```ts
interface CronTaskInitResponse {
  dict: {
    cron_preset_arr: Array<{ label: string; value: string }>
    cron_task_status_arr: Array<{ label: string; value: number }>
    cron_task_registry_status_arr: Array<{ label: string; value: string }>
    cron_task_log_status_arr: Array<{ label: string; value: number }>
  }
}
```

### List

`GET /api/admin/v1/cron-tasks?current_page=1&page_size=20&title=&status=&registry_status=`

Response item:

```ts
interface CronTaskItem {
  id: number
  name: string
  title: string
  description: string
  cron: string
  cron_readable: string
  handler: string
  status: number
  status_name: string
  next_run_time: string
  registry_status: 'registered' | 'missing' | 'disabled' | 'invalid_cron'
  registry_status_text: string
  registry_task_type: string
  registry_description: string
  created_at: string
  updated_at: string
}
```

Rules:

```text
status=2 -> registry_status disabled，即使 registry 存在也不注册。
status=1 + registry missing -> 页面显示未接入，worker 不注册。
status=1 + registry exists + cron invalid -> 页面显示 cron 错误，worker 启动时跳过并记录 warn，不阻塞整个 worker。
status=1 + registry exists + cron valid -> registered。
```

### Create / Update

`POST /api/admin/v1/cron-tasks`

`PUT /api/admin/v1/cron-tasks/:id`

Body:

```ts
interface CronTaskForm {
  name: string
  title: string
  description?: string
  cron: string
  cron_readable?: string
  handler?: string
  status: number
}
```

Rules:

```text
name 必须唯一，1-50，snake_case。
cron 必须是 6-field cron expression because gocron.CronJob(..., withSeconds=true)。
新增时如果 name 不在 registry，允许保存，但返回 registry_status=missing；这样可以保留历史任务，但不会执行。
handler 不作为执行依据；新增/编辑时如果为空，service 可填入 registry task type 或保留空字符串。
```

### Status

`PATCH /api/admin/v1/cron-tasks/:id/status`

Body:

```ts
interface CronTaskStatusBody { status: 1 | 2 }
```

Status change only updates DB. Running `admin-worker` does not hot reload schedules in this slice. UI must keep restart warning. Future slice can add reload endpoint or worker watcher.

### Delete

Soft delete only. Deleting unknown/missing registry task is allowed. Deleting registered task is allowed but current worker needs restart to remove already-registered schedule. UI warning remains.

### Logs

`GET /api/admin/v1/cron-tasks/:id/logs?current_page=1&page_size=20&date=2026-05-01,2026-05-06&status=1`

Response keeps existing frontend shape:

```ts
interface CronTaskLogItem {
  id: number
  task_id: number
  task_name: string
  start_time: string | null
  end_time: string | null
  duration_ms: number | null
  status: number
  status_name: string
  result: string | null
  error_msg: string | null
  created_at: string
}
```

## RBAC and OperationLog

Permission metadata:

```text
POST /cron-tasks: devTools_cronTask_add
PUT /cron-tasks/:id: devTools_cronTask_edit
PATCH /cron-tasks/:id/status: devTools_cronTask_status
DELETE /cron-tasks/:id and batch: devTools_cronTask_del
GET /cron-tasks/:id/logs: devTools_cronTask_logs
```

Operation log metadata:

```text
create: 新增定时任务
update: 编辑定时任务
change_status: 定时任务状态切换
delete/delete_batch: 删除定时任务
```

Read/list/log routes do not write operation logs.

## Worker Registration Behavior

`admin-worker` assembly changes from static `jobs.RegisterSchedules(s, queueClient, logger)` to DB-aware registration:

```text
cronTaskService := crontask.NewSchedulerService(repo, registry, queueClient, logger)
cronTaskService.RegisterEnabled(ctx, scheduler)
```

Implementation detail:

```text
List enabled cron_task rows with is_del=2 and status=1.
For each row:
  lookup registry by row.name.
  if missing -> log warn, skip.
  validate cron by scheduler.Cron registration; if invalid -> log warn, skip.
  registered task func writes cron_task_log running/success/fail around enqueue.
```

A single bad row must not stop worker startup. Infrastructure errors such as DB unavailable still fail startup because worker cannot know schedule truth.

## Frontend Design

`src/api/system/cronTask.ts` switches to `request` and REST:

```text
init   -> GET /api/admin/v1/cron-tasks/init
list   -> GET /api/admin/v1/cron-tasks
add    -> POST /api/admin/v1/cron-tasks
edit   -> PUT /api/admin/v1/cron-tasks/:id
del    -> DELETE /api/admin/v1/cron-tasks/:id or DELETE /api/admin/v1/cron-tasks { ids }
status -> PATCH /api/admin/v1/cron-tasks/:id/status
logs   -> GET /api/admin/v1/cron-tasks/:id/logs
```

`src/views/Main/system/cronTask/index.vue` keeps current UX but adds registry status display:

```text
运行中/已禁用: existing status tag
已注册/未接入/cron错误: new registry status tag
handler column remains visible as legacy provenance, but label can be “处理器/任务类型”。
restart warning remains because this slice does not hot reload schedules.
```

Memory note: this page has two table flows. Main CRUD list stays `useCrudTable`; log list should stay list-only and use `useTable` if touched substantially. If only API migration touches it, do not rewrite unrelated table code.

## Open Source Boundary

Use existing mature packages:

```text
github.com/go-co-op/gocron/v2 for scheduling
github.com/hibiken/asynq for queue
GORM for DB
Gin for REST
Element Plus for UI components
```

Do not hand-roll cron parser for execution. For `next_run_time`, prefer gocron job `NextRun()` or `robfig/cron/v3` parser if a standalone parser is simpler; document chosen helper in implementation. If parser support is awkward, return `-` for invalid/unsupported and rely on gocron registration validation for runtime.

## Smoke and Tests

Backend unit tests:

```text
crontask service list decorates registry_status correctly.
create rejects duplicate name and invalid cron.
update cannot change name.
status toggles active row.
logs filter by task/date/status.
scheduler registration skips missing registry and invalid cron but registers notification_task_scheduler.
scheduler trigger writes running then success log and enqueues notification:dispatch-due:v1.
scheduler trigger writes failed log when enqueue fails.
route tests cover REST paths and request binding.
route_meta tests cover permission and operation log metadata.
```

Frontend tests:

```text
CronTaskApi no longer imports legacyRequest.
CronTaskApi uses RESTful /api/admin/v1/cron-tasks methods.
No any/as any/Record<string, any> in touched cronTask API/view.
```

Full smoke adds:

```text
GET /api/admin/v1/cron-tasks/init
GET /api/admin/v1/cron-tasks
GET /api/admin/v1/cron-tasks/:id/logs when a row exists
assert notification_task_scheduler row reports registry_status registered when enabled and cron valid
assert at least one PHP-only legacy task reports registry_status missing if present
```

No smoke mutation by default. Optional write probe can be added later, but this first slice avoids creating fake schedules.

## Docs and Status

Update:

```text
docs/contracts/admin-api-v1.md
admin_back_go/docs/architecture.md
docs/migration/current-status.md
docs/testing/smoke-matrix.md
docs/superpowers/plans/2026-05-03-admin-go-rewrite-goal-plan.md if it still implies static scheduler is enough
```

Status wording must be honest:

```text
system cron task management: implemented/adapted only after API, frontend, worker registration, and smoke are verified.
pay/ai/chat cron handlers: planned/not implemented until owning business module migrates.
```

## Rollout / Operational Notes

After changing cron_task rows, local dev must restart `admin-worker` for schedules to reload.

Commands:

```powershell
cd E:\admin_go\admin_back_go
go run ./cmd/admin-worker
```

This is acceptable for first Go slice. Hot reload is later and should not be invented prematurely.

## Exit Criteria

```text
admin_front_ts/src/api/system/cronTask.ts has no legacyRequest.
定时任务页面 no longer calls PHP 8787.
notification_task_scheduler is registered through cron_task DB + Go registry, not hard-coded static schedule.
cron_task_log records scheduler enqueue success/failure.
full smoke verifies init/list/logs and registry status.
go test -p 1 ./... and go vet -p 1 ./... pass.
frontend vue-tsc and targeted eslint pass or report only known warnings.
docs reflect runtime behavior.
```
