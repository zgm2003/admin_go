# Export Runtime V2 Design

状态：draft for user review on 2026-05-30

## Goal

把现有“用户列表导出”收敛成一个可复用的 Go 导出运行时：业务模块只负责提交导出请求和构造业务数据，`internal/module/export` 负责导出任务、队列执行、`.xlsx` 生成、COS 上传、状态记录和通知。

第一阶段不是重写一套报表平台。第一阶段只把当前 `user_list` 链路补成可验证、可扩展的通用骨架，并保留当前用户管理页按钮体验。后续支付订单、钱包流水、通知、AI run 等场景按同一骨架注册新的导出定义。

## Linus 三问

1. 这是真问题吗？是。当前用户导出已有 Go 实现和 COS uploader，但默认 smoke 只读 `export-tasks`，不触发真实导出、不等待 worker、不上传 COS；未来导出场景多，如果继续每个模块各写一套，就是垃圾复制。
2. 有更简单的方法吗？有。复用已有 `export_tasks`、`export:run:v1`、`XLSXWriter`、`COSUploader`，只补一个小的 export definition registry 和提交契约，不做模板 DSL、不做万能 SQL、不做同步下载。
3. 会破坏什么吗？不能破坏 `POST /api/admin/v1/users/export`、`user_userManager_export`、`/system/exportTask?status=2|3`、已有导出任务下载、当前用户隔离、COS-only 上传契约和现有 `.xlsx` 格式。

## Current evidence

当前仓库已经有这些事实：

- `POST /api/admin/v1/users/export` 已经是 Go REST 契约，权限固定是 `user_userManager_export`。
- `GET /api/admin/v1/export-tasks/status-count`、`GET /api/admin/v1/export-tasks`、`DELETE /api/admin/v1/export-tasks` 已经是当前用户 scoped。
- `internal/module/export` 已有 task model、service、repository、xlsx writer、COS uploader、notification notifier、queue handler。
- worker 已经把 `ExportTaskService` 接进 `jobs.Register`，并配置 `user.NewExportDataProvider`、`XLSXWriter`、`COSUploader`。
- smoke matrix 只做导出任务 read probe，不触发真实导出和 COS 上传。这是当前最明显的验证缺口。

## Product decision

未来导出范围采用“显式范围”：

```text
selected  # 导出显式勾选行
filtered  # 导出当前筛选条件下的结果
```

当前用户管理页第一阶段继续保持现有行为：必须勾选用户后导出，提交体仍兼容 `{ ids: number[] }`。这是 userspace，不动它。新导出场景默认使用显式 `scope`，不允许靠空字段猜行为。

## Scope

### In scope

1. 把 `internal/module/export` 定义成通用导出运行时。
2. 增加 export definition registry：按 `kind` 找到对应业务数据 provider。
3. 让业务模块提交导出时只创建任务和投递队列，不在 HTTP handler 里生成文件。
4. 保持 COS-only：导出文件由 worker 服务端上传到当前启用 COS。
5. 让导出任务表能区分 `kind`、`platform` 和 COS `object_key`。
6. 补一个 credential-gated 真实导出 smoke，证明任务能从 submit 跑到 COS 上传完成。
7. 前端抽出最小提交复用逻辑，未来多个页面不用复制“勾选校验 + 提交 + 提示”。

### Out of scope

1. 不做万能报表平台。
2. 不允许前端传 SQL、表名、列名或任意字段表达式。
3. 不做同步下载。
4. 不做 OSS、S3、local fallback；当前运行时仍是 COS-only。
5. 不做导出任务跨用户后台管理。
6. 不做取消、重试、进度条和 COS 对象删除。
7. 不做 CSV/PDF；第一版只支持 `.xlsx`。

## Architecture

### Responsibility split

```text
business transport/admin
  -> bind and validate business export request
  -> enforce business permission through route metadata
  -> call business service SubmitExport

business service
  -> normalize selected ids or filters
  -> create export_tasks pending row through export.Service
  -> enqueue export:run:v1

export runtime
  -> own export_tasks lifecycle
  -> own export definition registry
  -> own xlsx writer
  -> own COS upload
  -> own success/failed status update
  -> own notification dispatch request

business export provider
  -> own business query
  -> own row formatting
  -> return stable headers and string cells
```

Rule: handler never generates Excel. Service never uploads files directly during HTTP request. Worker owns expensive work.

### Package shape

Keep the existing package name and directory:

```text
admin_back_go/internal/module/export/
  definition.go          # Definition, Registry, Provider boundary
  dto.go                 # task/list/submit/run DTOs
  jobs.go                # export:run:v1 payload and handler registration
  model.go               # export_tasks model
  repository.go          # task persistence
  service.go             # task lifecycle and Run orchestration
  writer.go              # xlsx writer
  uploader.go            # COS upload boundary
  upload_config_repository.go
  notifier.go
  transport/admin/
```

Business modules keep their own submit endpoints. Example:

```text
internal/module/user/
  export_provider.go     # user_list provider
  service.go             # SubmitExport stays user-owned
  transport/admin        # POST /api/admin/v1/users/export
```

Do not create `adminexport`, `appexport`, `paymentexport` packages. Platform differences are route/request/presenter policy, not duplicated business modules.

## Export definition contract

The runtime registry maps a stable `kind` to a provider:

```go
type Definition struct {
    Kind     string
    Title    string
    Provider Provider
}

type Provider interface {
    BuildExportData(ctx context.Context, input BuildInput) (*FileData, error)
}

type BuildInput struct {
    TaskID   int64
    UserID   int64
    Platform string
    Kind     string
    Scope    Scope
    IDs      []int64
    Params   json.RawMessage
}
```

`Params` is raw only at the export runtime boundary. Each provider decodes it into its own typed request and rejects invalid data. The export runtime must not understand every module's filters.

Kind naming:

```text
user_list
payment_orders
wallet_transactions
ai_runs
```

No `admin_` prefix. Platform is not the business capability.

## Submit contract

New export submit endpoints use this shape:

```ts
type ExportScope = 'selected' | 'filtered'

interface ExportSubmitRequest {
  scope: ExportScope
  ids?: number[]
  filters?: object
}
```

Rules:

- `scope=selected` requires non-empty positive integer `ids`.
- `scope=filtered` requires a typed business filter object.
- Each business module sets its own max row cap.
- The route's existing permission code owns authorization.
- The service creates a pending task before enqueue.
- If enqueue fails after task creation, mark the task failed immediately.

Existing user export remains valid:

```ts
POST /api/admin/v1/users/export
{ ids: number[] }
```

If this endpoint is touched in V2, `{ ids }` is normalized to `scope=selected` inside the user transport/service boundary only. Do not make the export runtime guess missing `scope` for every future module.

## Queue payload

Current payload carries ids only. V2 payload becomes:

```go
type RunPayload struct {
    TaskID   int64           `json:"task_id"`
    Kind     string          `json:"kind"`
    UserID   int64           `json:"user_id"`
    Platform string          `json:"platform"`
    Scope    string          `json:"scope"`
    IDs      []int64         `json:"ids,omitempty"`
    Params   json.RawMessage `json:"params,omitempty"`
}
```

Compatibility rule:

- Existing `user_list` jobs with no `scope` are interpreted as `selected` only for `user_list` compatibility.
- New jobs must include `scope`.

The payload must never contain rendered rows. Redis is not a spreadsheet storage backend.

## Database design

Existing `export_tasks` stays the task table. Add only fields that remove real ambiguity:

```sql
ALTER TABLE export_tasks
  ADD COLUMN kind varchar(64) NOT NULL DEFAULT 'user_list' COMMENT '导出类型',
  ADD COLUMN platform varchar(32) NOT NULL DEFAULT 'admin' COMMENT '平台入口',
  ADD COLUMN object_key varchar(500) NULL COMMENT 'COS object key';
```

Why these fields are useful:

- `kind`: multiple export scenes need source identity for filtering, audits and worker diagnostics.
- `platform`: admin/app/openapi/merchant task visibility must not be guessed from user_id.
- `object_key`: `file_url` is presentation; COS cleanup and object lifecycle need the real key.

Fields intentionally not added in V2:

- `format`: only `.xlsx` exists.
- `progress`: no streaming progress in this slice.
- `total_rows`: row count is enough after completion; pre-count is provider-specific and can be expensive.
- `params_json`: queue payload owns execution parameters; task list does not need to expose filters.
- `storage_driver`: runtime is COS-only.

Existing rows are backfilled to `kind='user_list'` and `platform='admin'`.

## COS upload contract

V2 keeps server-side COS upload:

```text
source: enabled upload_setting + COS upload_driver
secret: decrypt through current APP_SECRET-derived secretbox
content-type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
key: exports/<kind>/YYYYMMDD/<safe_title>_YYYYMMDD_HHMMSS_<task_id>.xlsx
url: bucket_domain when configured, otherwise default COS public URL
```

If upload config is missing, non-COS, secret decrypt fails, or COS Put fails, the worker marks the task failed. No fake success. No fallback.

Existing `exports/YYYYMMDD/...` URLs remain valid because old rows store full `file_url`; V2 only changes new object keys.

## Frontend design

### User list

Keep the current button location and permission:

```text
permission: user_userManager_export
button: 导出
behavior phase 1: selected ids only
```

The current user list must not silently export all rows when nothing is selected. Empty selection still shows `请选择至少一项`.

### Reusable submit helper

Add a small frontend helper when implementation starts:

```text
src/hooks/useExportSubmit.ts
```

It owns only the repeated client behavior:

- selected id check
- call submit API
- show i18n success message
- optional action link to `/system/exportTask?status=1`

It must not own business filters, table state or permission checks. Those stay in each page.

### Export task page

Extend list filters only after backend fields exist:

- `kind`
- `status`
- `title`
- `file_name`

Response may include:

```ts
interface ExportTaskItem {
  id: number
  kind: string
  kind_text: string
  title: string
  file_name: string | null
  file_url: string | null
  file_size_text: string
  row_count: number | null
  status: 1 | 2 | 3
  status_text: string
  error_msg: string | null
  expire_at: string | null
  created_at: string
}
```

No visible Chinese can be hardcoded in touched Vue files; add zh-CN/en-US i18n keys.

## Permissions and operation log

Submit permissions stay business-owned:

```text
POST /api/admin/v1/users/export -> user_userManager_export
future payment order export     -> payment_order_export
future wallet ledger export     -> wallet_ledger_export
```

Export task list/status-count remain authenticated current-user views.

Delete operation stays scoped to current user. If a delete button permission exists, use that route permission; do not reuse an unrelated edit permission.

Operation log:

- Business submit endpoint logs the business action, e.g. `module=user action=export title=用户导出`.
- Export task delete logs `module=export_task action=delete/delete_batch`.
- Worker success/failure is persisted in `export_tasks`; it is not an HTTP operation log.

## Error handling

Submit errors:

- invalid selected ids -> 400
- invalid filters -> 400
- no rows found -> 404 or provider-specific bad request
- queue unavailable after task creation -> mark failed, return 500

Worker errors:

- unknown kind -> mark failed
- invalid payload -> mark failed when task id is loadable
- provider query failure -> mark failed
- xlsx generation failure -> mark failed
- upload config missing or decrypt failure -> mark failed
- COS Put failure -> mark failed
- notification failure -> log only; do not downgrade a successful export

Idempotency:

- success or soft-deleted task is a no-op on retry.
- failed task may be overwritten only by an explicit future retry feature, not by random duplicate worker execution.

## Testing strategy

Backend:

- `export` registry resolves known kind and rejects unknown kind.
- `RunPayload` validates required fields and preserves compatibility for old `user_list` selected jobs.
- `Service.Run` marks failed on unknown kind, provider error, writer error and uploader error.
- `COSUploader` returns `object_key`, `file_url`, `file_size`, `row_count` and uses `exports/<kind>/YYYYMMDD`.
- repository creates/list filters by `user_id + platform + is_del`.
- migration backfills existing rows to `kind=user_list/platform=admin`.
- user export still accepts `{ ids }` and maps to selected `user_list`.

Frontend:

- user export button still guarded by `user_userManager_export`.
- empty selected ids still blocks submit.
- submit helper does not hardcode Chinese text.
- export task API includes REST paths only; no legacy action path.
- export task page uses AppTable/Search and does not add extra page-card.

Smoke:

Default full smoke remains read-only:

```text
GET /api/admin/v1/export-tasks/status-count
GET /api/admin/v1/export-tasks?current_page=1&page_size=20
```

Add credential-gated real export smoke:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\export-task-smoke.ps1 `
  -Account 15671628271 `
  -Password 123456 `
  -RunRealExport
```

The gated smoke:

1. logs in;
2. submits one `user_list` export for a known existing user id;
3. polls `export-tasks` until status is success or failed;
4. asserts success row has `.xlsx` filename, positive file size, row count and COS-style `file_url`;
5. soft-deletes the created task through the API;
6. does not delete the COS object.

If enabled COS secrets cannot decrypt under the current `APP_SECRET`, the smoke fails. Skipping would hide the exact bug this feature is supposed to catch.

## Rollout plan

Phase 1:

- Add schema migration for `kind/platform/object_key`.
- Add registry and V2 run payload.
- Keep current user export selected-only behavior.
- Make user_list provider register through the registry.
- Add backend tests and gated real export smoke.
- Update contract/status/smoke docs.

Phase 2:

- Add the next real export scene, preferably payment orders or wallet transactions.
- Use explicit `scope=selected|filtered`.
- Add export task `kind` filter to frontend if more than one kind is active.

Phase 3:

- Consider retry/cancel/object cleanup only after real users need it.

## Acceptance criteria

The design is implemented only when all of these are true:

1. Existing user export still works with current UI and permission.
2. Worker can generate `.xlsx` and upload it to COS through current enabled upload config.
3. Failed upload/config/decrypt states mark the task failed; no permanent pending.
4. Export task list remains scoped to current token user and platform.
5. At least one gated real export smoke proves submit -> queue -> worker -> COS -> task success.
6. Docs distinguish implemented behavior from planned future export scenes.
