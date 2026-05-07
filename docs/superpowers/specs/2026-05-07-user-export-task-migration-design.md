# User Export Task Migration Design

状态：implemented on 2026-05-07

## Goal

把用户管理页的导出链路从 PHP legacy adapter 搬到 Go：用户点击“导出”后，Go 创建 `export_tasks` 记录，投递低优先级异步任务，worker 生成 `.xlsx` 文件并上传到当前启用的 COS，任务完成或失败后通过 Go 通知链路提醒发起用户。前端用户导出按钮和导出任务页都改用 Go REST API。

## Linus 三问

1. 这是真问题吗？是。当前 `docs/migration/current-status.md` 和 `docs/contracts/admin-api-v1.md` 都明确写着用户管理的 export 仍是 explicit legacy adapter。
2. 有更简单的方法吗？有。只搬 `user_list` 这一条真实导出链路，不做万能报表平台，不新增导出模板 DSL，不支持 OSS runtime。
3. 会破坏什么吗？不能破坏现有 `user_userManager_export` 权限码、`export_tasks` 表、通知跳转 `/system/exportTask?status=2|3`、导出任务页下载体验和用户隔离规则。

## Current Evidence

### 已迁的部分

- 用户管理页 list/page-init/edit/batch-edit/status/delete 已经走 Go REST。
- `admin_back_go/internal/module/user/route.go` 当前没有 `POST /api/admin/v1/users/export`。
- `admin_front_ts/src/api/user/users.ts` 当前 `UsersListApi.export` 还走 `legacyRequest.post('/api/admin/UsersList/export')`。
- 前端按钮已经用独立权限码 `user_userManager_export`，这个权限码必须保留。

### legacy PHP 业务事实

legacy 链路只作为业务事实，不作为新架构规则：

```text
POST /api/admin/UsersList/export
  -> UsersListModule::export
  -> validate ids
  -> UsersDep::getMap(ids)
  -> RoleDep::getMap(role_ids)
  -> UserProfileDep::getMapByUserIds(user_ids)
  -> format rows with headers {id, username, email, phone, avatar, sex, role}
  -> ExportTaskDep::create(user_id, '用户列表导出')
  -> RedisQueue::send('export_task', payload)
  -> ExportTask consumer
  -> ExportService builds .xlsx
  -> UploadService uploads to exports/YYYYMMDD
  -> export_tasks success/failed
  -> NotificationService urgent link to /system/exportTask?status=2 or ?status=3
```

现有表 `export_tasks` 已存在，字段事实：

```text
id int unsigned PK
user_id int unsigned
title varchar(100)
file_name varchar(255) nullable
file_url varchar(500) nullable
file_size int unsigned nullable
row_count int unsigned nullable
status tinyint unsigned default 1
error_msg varchar(500) nullable
expire_at datetime nullable
is_del tinyint unsigned default 2
created_at datetime
updated_at datetime
```

状态值保持：

```text
1 = 处理中
2 = 已完成
3 = 失败
```

## Scope

### In scope

1. Go 后端新增 `exporttask` 模块，用 REST API 管理当前用户自己的导出任务。
2. Go 后端在 `user` 模块新增用户列表导出提交接口。
3. Go worker 新增 `export:run:v1` task handler，第一版只支持 `kind=user_list`。
4. Go 通用 xlsx writer 能把稳定 header + string rows 写成 `.xlsx` bytes。
5. Go 导出 uploader 复用当前启用的 COS upload config 和 `platform/storage/cos.ObjectWriter`。
6. 前端 `UsersListApi.export` 和 `ExportTaskApi` 切到 Go REST。
7. 更新合同、状态、架构、smoke matrix 文档。
8. 后端单测、前端 contract test、最小 smoke 探针覆盖。

### Out of scope

1. 不迁所有业务导出；本轮只迁 `user_list`。
2. 不实现 OSS runtime 上传；当前 Go runtime 仍 COS-only。
3. 不做导出文件服务端代理下载；导出任务页继续拿 `file_url` 用现有 `downloadFile`。
4. 不新增 `export_tasks` 表结构字段。
5. 不做跨用户导出任务管理后台；导出任务 API 只看当前 token 用户。
6. 不做导出任务取消、重试、清空、文件删除。
7. 不把整包 rows 塞进队列 payload。

## Open Source Decision

Source check: Excelize official docs confirm the module is pure Go for reading/writing XLSX files and expose NewFile, SetCellStr, and WriteToBuffer APIs: https://xuri.me/excelize/en/ , https://xuri.me/excelize/en/cell.html , https://xuri.me/excelize/en/utils.html .

`.xlsx` 生成使用 `github.com/xuri/excelize/v2`。理由：

- 纯 Go spreadsheet library，直接支持创建和写入 Microsoft Excel `.xlsx` 文件。
- API 可用 `excelize.NewFile()`、`SetCellStr()`、`WriteToBuffer()` 生成 bytes，符合当前 worker 上传 bytes 的边界。
- 不引入 Java/Python sidecar，不新增外部二进制。

第一版不用 streaming writer，因为用户列表导出来自显式勾选 ids，正常规模较小。后续如果出现大批量全量导出，再单独写性能设计，不提前复杂化。

## API Contract

### Submit user export

```text
POST /api/admin/v1/users/export
Permission: user_userManager_export
OperationLog: module=user action=export title=用户导出
```

Request:

```ts
interface UserExportRequest {
  ids: number[] // required, non-empty, positive int, unique after normalization
}
```

Response:

```ts
interface UserExportResponse {
  id: number
  message: '导出任务已提交，完成后将通知您'
}
```

Rules:

- `ids` 为空返回 400。
- 非正整数 id 返回 400。
- 重复 id 在 service 层去重。
- 查询不到任何用户返回 404 `导出用户不存在`。
- 只导出未软删除用户。
- task 创建成功但队列投递失败时，任务必须标记失败并返回 500，不允许留下永久 pending 假任务。

### Export task status count

```text
GET /api/admin/v1/export-tasks/status-count
```

Query:

```ts
interface ExportTaskStatusCountQuery {
  title?: string
  file_name?: string
}
```

Response:

```ts
type ExportTaskStatusCountResponse = Array<{
  label: '处理中' | '已完成' | '失败'
  value: 1 | 2 | 3
  num: number
}>
```

Rules:

- Always return three statuses in fixed order: 1, 2, 3.
- Only count current token user rows with `is_del=2`.
- Before counting, soft-delete expired rows by setting `is_del=1` where `expire_at < now`.

### Export task list

```text
GET /api/admin/v1/export-tasks
```

Query:

```ts
interface ExportTaskListQuery {
  current_page?: number // default 1
  page_size?: number // default 20, max follows common page rule
  status?: 1 | 2 | 3
  title?: string
  file_name?: string
}
```

Response:

```ts
interface ExportTaskListResponse {
  list: Array<{
    id: number
    title: string
    file_name: string | null
    file_url: string | null
    file_size_text: string
    row_count: number | null
    status: 1 | 2 | 3
    status_text: '处理中' | '已完成' | '失败'
    error_msg: string | null
    expire_at: string | null
    created_at: string
  }>
  page: {
    page_size: number
    current_page: number
    total_page: number
    total: number
  }
}
```

Rules:

- Only current token user rows.
- `title` and `file_name` use prefix LIKE, same as PHP behavior.
- `file_size_text` output follows legacy: `-`, `N B`, `N KB`, `N MB`.

### Export task delete

```text
DELETE /api/admin/v1/export-tasks/:id
DELETE /api/admin/v1/export-tasks
```

Batch request:

```ts
interface ExportTaskBatchDeleteRequest {
  ids: number[]
}
```

Rules:

- Only soft-delete current token user rows.
- Deleting a non-owned id affects zero rows and still returns success, matching current list isolation behavior.
- No COS object deletion in this phase.

## Backend Design

### Package layout

```text
admin_back_go/internal/module/exporttask/
  model.go         # export_tasks GORM model
  dto.go           # query/input/response/task DTOs and status labels
  request.go       # Gin binding structs
  repository.go    # export_tasks persistence and current-user queries
  service.go       # status count/list/delete/create/mark success/failure
  handler.go       # REST binding and response only
  route.go         # /api/admin/v1/export-tasks routes
  jobs.go          # export:run:v1 task payload, builder, handler registration
  writer.go        # xlsx writer boundary using excelize
  uploader.go      # COS upload boundary for generated files
```

用户导出入口仍属于 `internal/module/user`，因为它是用户模块动作，不是通用 export task 管理动作：

```text
admin_back_go/internal/module/user/
  request.go       # add exportRequest
  dto.go           # add UserExportResponse / ExportUserRow if needed
  repository.go    # add ExportUsersByIDs or reuse focused query
  service.go       # add Export(ctx, input)
  handler.go       # add Export handler
  route.go         # add POST /api/admin/v1/users/export
```

### Dependency direction

```text
user.Service
  -> user.Repository for selected users
  -> exporttask.Service.CreatePending
  -> taskqueue.Enqueuer.Enqueue(exporttask.NewRunTask)

worker jobs.Register
  -> exporttask.RegisterJobs
  -> exporttask.Service.RunTask
  -> user export data repository or exporttask-owned user export reader
  -> exporttask.XLSXWriter
  -> exporttask.COSUploader
  -> exporttask.Repository.MarkSuccess/MarkFailed
  -> notification insert + realtime publish through existing notification task/current notification boundary
```

The decisive rule: HTTP handler never generates Excel. API only creates a task and enqueues work.

### Queue payload

```go
type RunPayload struct {
    TaskID   int64   `json:"task_id"`
    Kind     string  `json:"kind"`
    UserID   int64   `json:"user_id"`
    Platform string  `json:"platform"`
    IDs      []int64 `json:"ids"`
}
```

`Kind` first version:

```text
user_list
```

Payload carries selected ids, not pre-rendered rows. That avoids redis payload bloat and keeps data formatting in Go worker where failures can be retried.

### Excel format

Headers exactly preserve legacy first-version fields:

```text
id       用户ID
username 用户名
email    邮箱
phone    手机号
avatar   头像
sex      性别
role     角色
```

All cell values are written as string to avoid phone/id/scientific notation corruption. Sex uses labels from Go enum. Role name comes from current role table. Missing profile avatar/sex uses empty/未知. Missing role uses empty string.

### Upload format

```text
key: exports/YYYYMMDD/users_export_YYYYMMDD_HHMMSS_<task_id>.xlsx
content-type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
url: CDN domain when configured, otherwise https://<bucket>.cos.<region>.myqcloud.com/<key>
```

The uploader loads enabled upload config the same way manifest publishing does: join enabled `upload_setting` with COS `upload_driver`, decrypt secret id/key via `secretbox`, call `storage/cos.ObjectWriter.Put`.

### Notification behavior

On success:

```text
title: 用户列表导出 - 导出完成
content: 点击查看导出文件
link: /system/exportTask?status=2
level/type: success/urgent equivalent in existing Go notification enums
platform: request platform if available, otherwise admin
```

On final failure inside worker:

```text
title: 用户列表导出 - 导出失败
content: 导出任务失败，请重试
link: /system/exportTask?status=3
level/type: error/urgent equivalent
```

Publishing realtime failure must not turn a successful export into failed. DB notification insert failure should be logged but not corrupt completed export status.

## Frontend Design

### User export button

Keep UI unchanged. Only switch client:

```text
UsersListApi.export
  from legacyRequest.post('/api/admin/UsersList/export')
  to request.post('/api/admin/v1/users/export')
```

Return type becomes:

```ts
interface UserExportResponse {
  id: number
  message: string
}
```

`exportExcel()` can continue to show `data.message || t('common.export.submitted')`.

### Export task page

Keep UI unchanged. Only switch API:

```text
ExportTaskApi.statusCount -> GET /api/admin/v1/export-tasks/status-count
ExportTaskApi.list        -> GET /api/admin/v1/export-tasks
ExportTaskApi.del         -> DELETE /api/admin/v1/export-tasks/:id or DELETE /api/admin/v1/export-tasks with body {ids}
```

Delete wrapper should mirror `UsersListApi.del`: single id uses path param, batch uses request body.

## Permission and Operation Log

Add route metadata:

```text
POST   /api/admin/v1/users/export        -> user_userManager_export
DELETE /api/admin/v1/export-tasks/:id    -> system_exportTask_del if seeded, otherwise no permission rule until permission seed exists
DELETE /api/admin/v1/export-tasks        -> system_exportTask_del if seeded, otherwise no permission rule until permission seed exists
```

Current DB has page `/system/exportTask` and user export button `user_userManager_export`, but no task delete button code observed. The safe first implementation is:

- enforce `user_userManager_export` on submit immediately;
- keep export-task list/status-count accessible to authenticated users because data is scoped to current user;
- add delete permission only if a dedicated button permission is seeded in the same migration.

Do not reuse `user_userManager_edit` or another unrelated permission for export.

Operation log metadata:

```text
POST   /api/admin/v1/users/export        module=user        action=export        title=用户导出
DELETE /api/admin/v1/export-tasks/:id    module=export_task action=delete        title=删除导出任务
DELETE /api/admin/v1/export-tasks        module=export_task action=delete_batch  title=批量删除导出任务
```

List/status-count are read-only and do not need operation logs.

## Error Handling

1. Invalid request returns 400.
2. No selected users returns 404.
3. Queue disabled or enqueue failure after task creation marks that task failed and returns 500.
4. Worker unknown kind marks failed with `unsupported export kind`.
5. Excel generation failure marks failed.
6. Upload config missing, non-COS driver, decrypt failure, COS upload failure mark failed.
7. Failure message stored in `export_tasks.error_msg` is capped at 500 characters.
8. Worker retries must be idempotent enough: if task is already success or soft-deleted, handler noops.

## Testing Strategy

### Backend tests

- `exporttask` service:
  - status count always returns 1/2/3 in order;
  - list only returns current user rows;
  - delete only affects current user;
  - file size text matches legacy;
  - mark failed caps error text.
- `exporttask` writer:
  - generated xlsx can be reopened by excelize;
  - phone and id cells are stored/read as strings;
  - header order is stable.
- `exporttask` jobs:
  - `NewRunTask` uses type `export:run:v1` and low queue;
  - unsupported kind marks failed;
  - success path writes xlsx, uploads, marks success, and requests notification.
- `user` service/handler:
  - export rejects empty ids;
  - export normalizes duplicate ids;
  - export creates pending task and enqueues low queue task;
  - enqueue failure marks failed and returns error.
- `bootstrap` route metadata:
  - `POST /api/admin/v1/users/export` maps to `user_userManager_export`.
- `server` router:
  - installs `POST /api/admin/v1/users/export` and `GET /api/admin/v1/export-tasks` routes.

### Frontend tests

- `src/api/user/users.ts` no longer contains `/api/admin/UsersList/export`.
- `src/api/system/exportTask.ts` no longer imports `legacyRequest`.
- Export task delete selects correct REST shape for single and batch delete.
- User list page still guards export button with `user_userManager_export`.

### Smoke

Add read-only smoke after Go API is running:

```text
GET /api/admin/v1/export-tasks/status-count
GET /api/admin/v1/export-tasks?current_page=1&page_size=20
```

Add optional non-default smoke for export submit only when environment variable allows mutation:

```text
POST /api/admin/v1/users/export { ids: [known_user_id] }
wait worker or poll export task list
expect status 2 or explicit status 3 with error_msg
```

Default smoke must not create COS files unless explicitly enabled.

## Documentation Updates

Update these files after implementation:

```text
docs/contracts/admin-api-v1.md
docs/migration/current-status.md
docs/testing/smoke-matrix.md
admin_back_go/docs/architecture.md
```

Expected final status text:

```text
users management: implemented for page-init/list/edit/batch-edit/status/delete/export submit; export worker uses Go export task runtime.
export tasks: implemented REST status-count/list/delete scoped by current user; frontend adapted to Go REST.
```

## Rollout and Verification

Backend:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/exporttask ./internal/module/user ./internal/jobs ./internal/bootstrap ./internal/server
go test ./...
go vet ./...
```

Frontend:

```powershell
cd E:\admin_go\admin_front_ts
pnpm exec vitest run tests/shared/user/user-list.test.ts tests/shared/system/export-task-api.test.ts
pnpm exec vue-tsc --noEmit
```

Full workspace residue checks:

```powershell
rg -n "UsersList/export|ExportTask/statusCount|ExportTask/list|ExportTask/del|legacyRequest" E:\admin_go\admin_front_ts\src\api\user\users.ts E:\admin_go\admin_front_ts\src\api\system\exportTask.ts
rg -n "export still explicit legacy adapter|等待 Go export-task" E:\admin_go\docs E:\admin_go\admin_back_go\docs
```

The first command should show no legacy export endpoints in touched clients. The second command should show no stale statements claiming export is still waiting for migration.


