# System cron cleanup design

日期：2026-05-21

## 目标

把系统定时任务页从“迁移态/兼容态”收口成纯 Go 项目表达：

1. 前端不再展示“接入状态”列。
2. “任务类型/旧处理器”统一改成“任务类型”，不再显示“Go任务 / 旧处理器”标签。
3. 清理已经移除的聊天室/好友请求遗留任务 `clean_expired_contact_request`。
4. 确认 `cron_task` 表没有额外字段；如发现 runtime DB 有多余字段再写显式清理迁移。
5. 让支付补偿任务在当前 Docker runtime 真正注册运行，并把验证命令固化到实施计划。

## 现场事实

### 代码与运行时存在版本差

当前后端源码最新提交包含支付 cron registry：

```text
admin_back_go HEAD = 277d411 feat(payment): implement Alipay callback handling and related functionality
commit time = 2026-05-21 15:55:01 +0800
```

当前 Docker 后端镜像早于这个提交：

```text
admin-go-backend:local Created=2026-05-21T00:20:22Z
admin-worker started around 2026-05-21 09:03 +0800
```

因此截图里支付任务显示“未接入”不是数据库字段问题，而是 live API/worker 还在跑旧镜像。

### 支付 cron rows 入库晚于 worker 启动

MySQL 容器使用 UTC；查询显示：

```text
mysql_now = 2026-05-21 08:14:55 UTC
payment_* updated_at = 2026-05-21 07:59:58 UTC
minutes_since_update = 14
```

worker 启动日志只注册了：

```text
ai_run_timeout -> ai:run-timeout:v1
notification_task_scheduler -> notification:dispatch-due:v1
skip unregistered clean_expired_contact_request
```

没有注册 `payment_sync_pending_order` / `payment_close_expired_order`，因为这两行是在 worker 启动后才入库。当前 scheduler 不热重载 `cron_task`，所以需要重建/重启后端容器，至少要让最新 `admin-api` 和 `admin-worker` 同时生效。

### `cron_task` 表结构没有多加字段

当前 live DB 字段：

```text
id
name
title
description
cron
cron_readable
handler
status
is_del
created_at
updated_at
```

没有 `registry_status`、`registry_task_type`、`registry_description` 这类字段。它们只是 Go API 派生响应字段和前端展示字段。

## 范围

### 本次要做

#### 后端

- 保留 `cron_task.handler` 作为现有数据库列名，避免无意义 schema churn。
- 把 Go 内部 registry 继续作为可执行任务真相源。
- 删除公共 REST list item 中迁移态展示字段：
  - `registry_status`
  - `registry_status_text`
  - `registry_task_type`
  - `registry_description`
- `handler` 字段在 API 语义上收口为“任务类型”，已注册任务返回版本化 task type。
- 对未注册的历史任务，不再作为“旧处理器”美化展示；清理目标任务应直接从 active rows 移除。
- 新增 migration 软删除或删除 `clean_expired_contact_request`：
  - 推荐软删除：`status=2, is_del=1`
  - 原因：可回滚、符合当前 `is_del` 模式；前端 active list 不再展示。

#### 前端

- 移除主表“接入状态”列。
- “任务类型/旧处理器”改成“任务类型”。
- 删除行内 `Go任务` / `旧处理器` 标签。
- 只显示一个任务类型 code，例如：
  - `notification:dispatch-due:v1`
  - `ai:run-timeout:v1`
  - `payment:sync-pending-order:v1`
  - `payment:close-expired-order:v1`
- 删除 `CronTaskRegistryStatus` 类型、`registry_status` 查询条件和对应 UI 逻辑。
- 保持日志弹窗继续用 `useCronTaskLogs` + `useTable`，不要退回 `useCrudTable`。

#### 文档/契约

- 同步 `docs/contracts/admin-api-v1.md` 的 System Cron Tasks 字段契约。
- 同步 `docs/status/current-status.md`：描述不再包含 registry 状态展示列；仍保留 Go registry 是执行真相源。
- 同步 `docs/testing/smoke-matrix.md`：smoke 不再断言 `registry_status`，改为断言任务存在且 `handler` 返回版本化 Go task type。
- 同步 `admin_back_go/docs/architecture.md`：去掉“未迁 Go 的 legacy handler 展示”口径，明确 active 列表不展示遗留任务。

### 本次不做

- 不重命名数据库列 `handler`。
- 不引入 worker 热重载。
- 不把 scheduler 策略放回 env 或 system_settings。
- 不新增 `cron_task` 字段。
- 不恢复聊天室、好友请求、旧支付对账、微信支付、退款等任务。
- 不把 scheduler callback 改成直接跑业务；仍然只写 `cron_task_log` 并 enqueue Asynq task。

## Vue 组件边界

当前 `src/views/Main/system/cronTask/index.vue` 已是 Vue 3 `<script setup lang="ts">`。

本次不新增多组件拆分，只做收口清理：

- route view：继续负责主 CRUD 表、任务弹窗、日志弹窗组合。
- `useCronTaskLogs`：继续独立承载日志只读列表；日志列表不使用 CRUD hook。
- 派生展示逻辑：只保留 `displayTaskType(row)`，不再保留 registry tag 类型映射。

如果实现时发现 `index.vue` 继续膨胀，再单独拆 `CronTaskFormDialog` / `CronTaskLogDialog`，但不在本次 spec 强行扩大。

## 后端设计

### API item

目标响应：

```ts
interface CronTaskItem {
  id: number
  name: string
  title: string
  description: string
  cron: string
  cron_readable: string
  handler: string // API 语义：任务类型 task type
  status: number
  status_name: string
  next_run_time: string
  created_at: string
  updated_at: string
}
```

说明：

- `handler` 暂不改 JSON 字段名，避免前后端一次性大迁移。
- UI 文案改成“任务类型”。
- 对 Go registry 已知任务，service 继续用 registry task type 覆盖 `handler`。
- `clean_expired_contact_request` 通过 migration 从 active rows 消失，不靠 UI 隐藏。

### Scheduler runtime

重建/重启后应在 worker 启动日志看到四条注册：

```text
registered db-backed cron task ai_run_timeout task_type=ai:run-timeout:v1
registered db-backed cron task notification_task_scheduler task_type=notification:dispatch-due:v1
registered db-backed cron task payment_sync_pending_order task_type=payment:sync-pending-order:v1
registered db-backed cron task payment_close_expired_order task_type=payment:close-expired-order:v1
```

随后在 `cron_task_log` 中应看到 payment 两个 task 的 log：

```text
payment_sync_pending_order
payment_close_expired_order
```

## 数据清理设计

新增 migration：

```sql
UPDATE cron_task
SET status = 2,
    is_del = 1,
    updated_at = CURRENT_TIMESTAMP
WHERE name = 'clean_expired_contact_request'
  AND is_del = 2;

UPDATE cron_task
SET handler = CASE name
    WHEN 'notification_task_scheduler' THEN 'notification:dispatch-due:v1'
    WHEN 'ai_run_timeout' THEN 'ai:run-timeout:v1'
    WHEN 'payment_sync_pending_order' THEN 'payment:sync-pending-order:v1'
    WHEN 'payment_close_expired_order' THEN 'payment:close-expired-order:v1'
    ELSE handler
  END,
    updated_at = CURRENT_TIMESTAMP
WHERE name IN (
    'notification_task_scheduler',
    'ai_run_timeout',
    'payment_sync_pending_order',
    'payment_close_expired_order'
  )
  AND is_del = 2;
```

原因：

- 聊天室/好友请求已经从 current-status 删除。
- 这个 cron row 当前 worker 明确 `skip unregistered`，继续展示只会制造噪音。
- 软删除保留审计/回滚空间，不扩大破坏面。
- 同一迁移顺手把已知 Go cron 的 `handler` 值归一到版本化 task type，避免 live DB 继续残留旧 class string。

## 测试与回归

### 后端

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/crontask ./internal/platform/scheduler ./internal/jobs ./internal/bootstrap
go vet ./internal/module/crontask ./internal/platform/scheduler ./internal/jobs ./internal/bootstrap
```

重点断言：

- 默认 registry 包含四个 Go cron：
  - `notification_task_scheduler`
  - `ai_run_timeout`
  - `payment_sync_pending_order`
  - `payment_close_expired_order`
- 默认 registry 不包含：
  - `clean_expired_contact_request`
  - 旧 `pay_*` 任务
- API list item 不再暴露 registry 展示字段。
- scheduler callback 仍然只写 log + enqueue，不直接跑业务。

### 前端

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/system/cron-task-api.test.ts
npm run test -- tests/shared/i18n/literal-i18n-keys.test.ts tests/shared/i18n/no-visible-chinese.test.ts
npx vue-tsc -b --pretty false
```

重点断言：

- `src/api/system/cronTask.ts` 不再定义 registry status 类型/字段。
- `src/views/Main/system/cronTask/index.vue` 不再渲染“接入状态”。
- 页面不再出现“Go任务”“旧处理器”“任务类型/旧处理器”。
- 日志列表继续通过 `useCronTaskLogs` 使用 `useTable`。

### Docker/runtime 验证

实现后需要重建并重启后端 Docker-first 栈：

```powershell
cd E:\admin_go\.docker\admin-go-backend
docker compose config --quiet
docker compose up -d --build
curl.exe -fsS http://127.0.0.1:8080/health
curl.exe -fsS http://127.0.0.1:8080/ready
docker compose logs --tail=200 admin-worker
```

DB 验证：

```powershell
docker exec admin-go-state-mysql mysql -uroot -padmin_go_local -Dadmin -e "SELECT id,name,handler,status,is_del FROM cron_task WHERE is_del=2 ORDER BY id; SELECT task_name,status,result,error_msg,created_at FROM cron_task_log WHERE task_name IN ('payment_sync_pending_order','payment_close_expired_order') ORDER BY id DESC LIMIT 10;"
```

成功标准：

- active `cron_task` 不再有 `clean_expired_contact_request`。
- active list 中四个 Go task 都是版本化 task type。
- worker 日志显示 payment 两个 cron 已注册。
- `cron_task_log` 出现 payment 两个 task 的执行记录。

## 风险与取舍

- 当前不做 worker 热重载，所以“修改 cron 后要重启 worker”仍然成立。
- 当前保留 DB 列 `handler`，只是收口其业务含义；等以后有更大 schema cleanup 再考虑物理改名。
- 删除 registry 展示字段会影响旧前端；但当前前端和 API 同仓演进，按 Go/Vue active runtime 统一改。
- payment cron 真运行需要最新镜像；只改源码不重建 Docker 不能证明完成。

## 自检

- 无 TBD/TODO。
- 未把计划写成 implemented。
- 没有新增数据库字段。
- 没有恢复旧聊天室/好友请求概念。
- 没有把 scheduler callback 改成业务执行入口。
