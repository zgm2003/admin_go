# Notification Task Publish + Scheduler Dispatch Design

状态：approved for implementation
日期：2026-05-05

## Linus 三问

```text
1. 真问题：通知中心 read/list 已经走 Go，但“发布通知”仍停在 PHP legacy；而发布通知确实需要立即发送 + 定时调度 + 队列消费，否则后台基础模块不闭环。
2. 更简单方法：不先迁通用 cron_task CRUD，不手写 Redis queue；直接复用现有 Asynq + gocron/v2 基建，只做 notification_task 一个窄切片。
3. 会破坏什么：不能破坏当前通知中心 REST 合同；不能让 admin-api 跑 cron/消费队列；不能全体用户 smoke 乱发垃圾通知；不能把 legacy 全 POST 和兜底字段带进 Go。
```

## Goal

迁移后台通知任务发布页：

```text
init dict -> status count -> list -> create immediate/scheduled task -> cancel pending -> soft delete
```

同时打通第一个真实业务定时调度：

```text
admin-worker gocron schedule -> enqueue notification:dispatch-due:v1
dispatch-due handler claim due tasks -> enqueue notification:send-task:v1
send-task handler write notifications -> optional local realtime publish
```

## Scope

### Included

- Go REST endpoints under `/api/admin/v1/notification-tasks`.
- `notification_task` GORM model/repository/service/handler/route。
- enum/dict/validate 扩展：target type、task status、platform all。
- Asynq task types：
  - `notification:dispatch-due:v1`
  - `notification:send-task:v1`
- gocron schedule：
  - `notification-task-dispatch-due`
  - interval: 1 minute
- Immediate publish：create task 后立刻 enqueue send-task。
- Scheduled publish：create task 只入库 pending；scheduler 到期后 dispatch。
- Worker send task：按 target_type 解析用户，分批写 `notifications`，更新进度和状态。
- Local realtime boundary：发送成功后对本进程在线 session best-effort publish `notification.created.v1`。
- Frontend `src/api/system/notificationTask.ts` 从 legacyRequest 切到 Go REST typed client。
- Frontend touched page 保持现有 UI，不大改视觉；顺手去掉空 catch、then/finally 混用和明显 TS 松散点。
- docs/contract/current-status/smoke-matrix/full-smoke 同步。

### Excluded

- 不迁通用 `cron_task` / `cron_task_log` CRUD。
- 不做 Redis Pub/Sub / Redis Streams fan-out。
- 不做 outbox 表。
- 不做通知详情页、通知模板、撤回已发送通知。
- 不做 full smoke 写通知任务，第一轮只 read-only probe。
- 不改 `notifications` / `notification_task` 表结构；现有索引够当前量级。后续量上来再单独做索引迁移。

## Verified baseline

已验证命令：

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/platform/taskqueue ./internal/platform/scheduler ./internal/jobs ./internal/bootstrap
```

结果：`ok`。

当前基建事实：

- `cmd/admin-api` 只处理 HTTP，不消费 queue，不跑 cron。
- `cmd/admin-worker` 负责 Asynq server + gocron scheduler。
- `jobs.Register` 已注册 `system:no-op:v1`、`auth:login-log:v1`。
- `jobs.RegisterSchedules` 当前没有真实业务 schedule；本切片加入第一条。
- queue lane：`critical/default/low`。
- scheduler 只能 enqueue task，不能直接执行业务。

## Legacy facts

旧 PHP 事实源：

```text
NotificationEnum:
  type: 1普通 2成功 3警告 4错误
  level: 1普通 2紧急
  target_type: 1全部用户 2指定用户 3指定角色
  status: 1待发送 2发送中 3已完成 4失败

notification_task:
  title/content/type/level/link/platform/target_type/target_ids/status/total_count/sent_count/send_at/error_msg/created_by/is_del

flow:
  add -> calculate target count -> insert notification_task pending
  send_at empty -> enqueue notification_task
  scheduler scan pending send_at <= now -> set sending -> enqueue notification_task
  consumer load task -> resolve users -> batch 100 -> write notifications -> update sent_count/status
```

当前 MySQL 已确认：

- `notification_task.idx_status_del_send(status,is_del,send_at)` 存在。
- `notifications.idx_user_platform_del_id(user_id,is_del,id)` 存在。
- `users.idx_users_role_del(role_id,is_del)`、`users.idx_users_active(is_del,status)` 存在。

## API contract

```text
GET    /api/admin/v1/notification-tasks/init
GET    /api/admin/v1/notification-tasks/status-count?title=
GET    /api/admin/v1/notification-tasks?current_page=1&page_size=20&status=&title=
POST   /api/admin/v1/notification-tasks
PATCH  /api/admin/v1/notification-tasks/:id/cancel
DELETE /api/admin/v1/notification-tasks/:id
```

### Create body

```ts
interface NotificationTaskCreateBody {
  title: string
  content?: string
  type?: 1 | 2 | 3 | 4
  level?: 1 | 2
  link?: string
  platform?: 'all' | 'admin' | 'app'
  target_type: 1 | 2 | 3
  target_ids?: number[]
  send_at?: string // YYYY-MM-DD HH:mm:ss; empty = immediate
}
```

规则：

- `target_type=1` 时忽略 `target_ids`，服务端归一化为空数组。
- `target_type=2/3` 时必须有非空 `target_ids`。
- `type` 默认普通，`level` 默认普通，`platform` 默认 `all`。
- `send_at` 为空表示立即发送；非空表示定时发送。
- response: `{ id: number, queued: boolean }`。
- queued=false 表示定时任务仅入库 pending，等待 scheduler。
- queue enqueue 失败不吞：create 已写 DB 后 enqueue 失败会返回明确错误，文档记录这是当前 DB+queue 非事务一致性风险；后续 outbox 修。

## Backend design

新模块：

```text
internal/module/notificationtask
  model.go
  dto.go
  request.go
  repository.go
  service.go
  jobs.go
  handler.go
  route.go
  *_test.go
```

调用边界：

```text
route -> handler -> service -> repository -> model
jobs.Register -> notificationtask.RegisterHandlers -> service
jobs.RegisterSchedules -> notificationtask.ScheduleDefinitions -> enqueue dispatch task
```

repository 负责数据动作，不做业务决策：

- list/status count。
- create task。
- get task。
- cancel/delete。
- claim due pending tasks：原子把到期 pending 改为 sending，再返回 ids。
- claim send task：pending/sending -> sending，保证重试幂等。
- resolve target users：all/users/roles。
- insert notifications batch。
- update sent count/status/error。

service 负责业务规则：

- enum/platform/target/send_at 校验。
- target_count 计算。
- create 后按 send_at 决定是否 enqueue。
- dispatch due 只 claim + enqueue，不发通知。
- send task 幂等：只处理 pending/sending 且未删除任务；完成任务再次消费直接 no-op。
- 发送失败写 failed + error_msg，并返回 error 让 Asynq 重试；最终失败仍会再次写 failed。

## Scheduler design

`RegisterSchedules` 注册：

```text
name: notification-task-dispatch-due
every: 1m
task: notification:dispatch-due:v1
queue: default
unique_ttl: 55s
```

调度器只 enqueue `dispatch-due`，不扫描 DB。扫描 DB 属于 worker handler 的业务 task，仍在 `admin-worker` 内执行。

## Queue lane and retry

```text
notification:dispatch-due:v1 -> default queue, short task, unique ttl 55s
notification:send-task:v1    -> default queue, batch write, max retry from queue default
```

不放 `critical`。通知发布不是登录/RBAC，不该抢最高优先级。

## Realtime boundary

本切片只用现有 local Publisher：

```text
notification.created.v1 -> session key {platform}:{user_id}:{session_id}
```

但当前任务消费者只知道 user_id，不知道所有 session_id；所以第一期 publish policy 是：

```text
如果 publisher 支持目标 session 才 best-effort 发布；默认 NoopPublisher/local 无 session map 查询时不阻塞写库。
```

换句话说：DB notification 写入是本切片真相；WebSocket 实时推送是 planned/local best-effort，不冒充分布式 fan-out 已完成。

## DB/queue consistency risk

当前是 DB 写入 + Redis queue enqueue 两步，不是强一致。

已接受的第一期策略：

- immediate create 后 enqueue 失败：接口返回错误，任务仍留 pending，可由后续 scheduler 或人工重试处理。
- scheduled task 靠每分钟 dispatch-due 扫描 pending 到期任务。
- send-task handler 幂等，允许 Asynq at-least-once 重投。
- 后续如果要强一致，新增 outbox 表，不用 Redis queue 假装事务。

## Frontend component map

- `src/api/system/notificationTask.ts`：唯一 Go REST typed client，负责路径和 body 翻译。
- `src/views/Main/system/notificationTask/index.vue`：页面组合层，保留现有 tabs/search/table/dialog。
- `RemoteSelect` 继续复用现有组件；本切片不扩大到清理其历史 `any` 类型。

Vue 规则：

- Composition API + `<script setup lang="ts">`。
- source state 最少，显示文本用 computed/helper。
- touched file 不新增 `any/as any/Record<string, any>`。
- 不增加 legacy fallback label。

## Permissions and operation log

本切片新增 mutating route metadata：

```text
POST   /api/admin/v1/notification-tasks           -> system_notificationTask_add
PATCH  /api/admin/v1/notification-tasks/:id/cancel -> system_notificationTask_cancel
DELETE /api/admin/v1/notification-tasks/:id        -> system_notificationTask_del
```

Live DB 验证发现旧权限数据只有通知管理 PAGE，没有发布/取消/删除 BUTTON。这个不是“可选优化”，因为 Go PermissionCheck 是 fail-closed。

补救策略：

```text
database/migrations/20260505_add_notification_task_button_permissions.sql
只插入三个 BUTTON 权限到 /system/notificationTask 页面下。
只给已经拥有该 PAGE 的角色补按钮授权。
不引入隐藏超级管理员绕过，不给未拥有页面的角色扩大菜单可见面。
执行后清理或等待对应用户 button cache TTL，避免旧 Redis 缓存继续拒绝新按钮。
```

OperationLog：

```text
notification_task.create
notification_task.cancel
notification_task.delete
```

说明：当前 DB 权限数据是否已有按钮 code 要用 live DB 验证；如果没有，本切片不自动灌权限数据，避免偷偷改菜单。route metadata 先写清，用户角色授权缺失时 fail-closed 是正确行为。

## Test and smoke strategy

Backend：

```powershell
go test ./internal/module/notificationtask ./internal/jobs ./internal/server ./internal/bootstrap
go test ./...
go vet ./...
```

Frontend：

```powershell
npx vue-tsc -b --pretty false
npx eslint src/api/system/notificationTask.ts src/views/Main/system/notificationTask/index.vue
```

Smoke：

- full smoke 第一轮只探测 init/status-count/list。
- 不创建通知任务，不给全体用户发垃圾通知。
- 写路径由 Go unit tests 覆盖。

## Exit criteria

- notification_task 发布页前端走 Go REST。
- immediate/scheduled 两种路径在服务层和 jobs tests 覆盖。
- scheduler 注册了第一条真实业务 schedule，且测试证明 schedule 只 enqueue。
- docs/current-status/contract/smoke-matrix 同步。
- root/backend/frontend 各自按模块 commit。
