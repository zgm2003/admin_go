# User Export Task Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move user-list export and the export-task page from PHP legacy adapters to Go REST + Go worker.

**Architecture:** User export submission stays in `internal/module/user`; export task lifecycle, xlsx generation, COS upload, and worker handling live in a new `internal/module/exporttask`. HTTP creates a pending task and enqueues `export:run:v1`; worker re-reads selected user IDs, generates `.xlsx`, uploads to COS, updates `export_tasks`, and sends a Go notification.

**Tech Stack:** Go 1.26.1, Gin, GORM, Asynq via `taskqueue`, Tencent COS via existing `storage/cos`, `github.com/xuri/excelize/v2`, Vue 3, TypeScript, Vitest.

---

## Execution Status

状态：implemented on 2026-05-07.

说明：下面的 checkbox 保留为执行计划原文，方便后续 review 每个窄步骤；当前运行时状态以代码、合同文档和最终验证命令为准。

---

## Spec

Implement from:

```text
docs/superpowers/specs/2026-05-07-user-export-task-migration-design.md
```

## Non-negotiable rules

```text
1. Do not copy PHP /api/admin/UsersList/export or /ExportTask/* style into Go.
2. Do not reuse user_userManager_edit for export.
3. Do not put rendered row data into the queue payload.
4. Do not add OSS runtime support in this slice.
5. Do not change user-list or export-task page visuals.
6. Do not leave docs saying export is still waiting for Go migration.
```

## Files

Create:

```text
admin_back_go/internal/enum/export_task.go
admin_back_go/internal/enum/export_task_test.go
admin_back_go/internal/module/exporttask/model.go
admin_back_go/internal/module/exporttask/dto.go
admin_back_go/internal/module/exporttask/request.go
admin_back_go/internal/module/exporttask/repository.go
admin_back_go/internal/module/exporttask/service.go
admin_back_go/internal/module/exporttask/handler.go
admin_back_go/internal/module/exporttask/route.go
admin_back_go/internal/module/exporttask/jobs.go
admin_back_go/internal/module/exporttask/writer.go
admin_back_go/internal/module/exporttask/uploader.go
admin_back_go/internal/module/exporttask/upload_config_repository.go
admin_back_go/internal/module/exporttask/service_test.go
admin_back_go/internal/module/exporttask/handler_test.go
admin_back_go/internal/module/exporttask/jobs_test.go
admin_back_go/internal/module/exporttask/writer_test.go
admin_back_go/internal/module/exporttask/uploader_test.go
admin_front_ts/tests/shared/system/export-task-api.test.ts
```

Modify:

```text
admin_back_go/go.mod
admin_back_go/go.sum
admin_back_go/internal/jobs/noop.go
admin_back_go/internal/jobs/noop_test.go
admin_back_go/internal/bootstrap/app.go
admin_back_go/internal/bootstrap/worker.go
admin_back_go/internal/bootstrap/route_meta.go
admin_back_go/internal/bootstrap/route_meta_test.go
admin_back_go/internal/server/router.go
admin_back_go/internal/server/router_test.go
admin_back_go/internal/module/user/dto.go
admin_back_go/internal/module/user/request.go
admin_back_go/internal/module/user/repository.go
admin_back_go/internal/module/user/service.go
admin_back_go/internal/module/user/handler.go
admin_back_go/internal/module/user/route.go
admin_back_go/internal/module/user/service_test.go
admin_back_go/internal/module/user/handler_test.go
admin_front_ts/src/types/user.ts
admin_front_ts/src/api/user/users.ts
admin_front_ts/src/api/system/exportTask.ts
admin_front_ts/tests/shared/user/user-list.test.ts
docs/contracts/admin-api-v1.md
docs/migration/current-status.md
docs/testing/smoke-matrix.md
admin_back_go/docs/architecture.md
```

---

## Task 1: Export task enum and Excelize dependency

**Files:** `admin_back_go/internal/enum/export_task.go`, `admin_back_go/internal/enum/export_task_test.go`, `admin_back_go/go.mod`, `admin_back_go/go.sum`

- [ ] Write failing enum test in `export_task_test.go` for statuses `1/2/3` and labels `处理中/已完成/失败`.
- [ ] Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/enum -run TestExportTaskStatusLabelsAndValidation -count=1
```

Expected: fail on undefined export task enum.

- [ ] Create `export_task.go`:

```go
package enum

const (
	ExportTaskStatusPending = 1
	ExportTaskStatusSuccess = 2
	ExportTaskStatusFailed  = 3
)

var ExportTaskStatusLabels = map[int]string{
	ExportTaskStatusPending: "处理中",
	ExportTaskStatusSuccess: "已完成",
	ExportTaskStatusFailed:  "失败",
}

func IsExportTaskStatus(value int) bool {
	_, ok := ExportTaskStatusLabels[value]
	return ok
}
```

- [ ] Add dependency:

```powershell
cd E:\admin_go\admin_back_go
go get github.com/xuri/excelize/v2@latest
```

- [ ] Verify:

```powershell
go test ./internal/enum -count=1
```

Expected: PASS.

---

## Task 2: Export task REST module

**Files:** `admin_back_go/internal/module/exporttask/*`

- [ ] Write `service_test.go` for:

```text
StatusCount returns statuses 1/2/3 in order and scopes UserID.
List scopes UserID and formats file_size_text.
Delete normalizes ids and calls DeleteByUser(user_id, ids).
CreatePending creates status=1 and expire_at=now+7 days.
MarkFailed caps error_msg at 500 runes.
```

- [ ] Run failing test:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/exporttask -run 'Test(StatusCount|List|Delete|CreatePending)' -count=1
```

Expected: fail because module is not implemented.

- [ ] Create `model.go` mapping existing `export_tasks` table:

```go
type Task struct {
	ID        int64      `gorm:"column:id"`
	UserID    int64      `gorm:"column:user_id"`
	Title     string     `gorm:"column:title"`
	FileName  string     `gorm:"column:file_name"`
	FileURL   string     `gorm:"column:file_url"`
	FileSize  *int64     `gorm:"column:file_size"`
	RowCount  *int64     `gorm:"column:row_count"`
	Status    int        `gorm:"column:status"`
	ErrorMsg  string     `gorm:"column:error_msg"`
	ExpireAt  *time.Time `gorm:"column:expire_at"`
	IsDel     int        `gorm:"column:is_del"`
	CreatedAt time.Time  `gorm:"column:created_at"`
	UpdatedAt time.Time  `gorm:"column:updated_at"`
}
func (Task) TableName() string { return "export_tasks" }
```

- [ ] Create `dto.go` with:

```text
StatusCountQuery, StatusCountItem, ListQuery, ListResponse, Page, ListItem,
CreatePendingInput, CreatePendingResponse, DeleteInput, SuccessResult.
```

JSON names must match the spec: `file_name`, `file_url`, `file_size_text`, `row_count`, `status_text`, `error_msg`, `expire_at`, `created_at`.

- [ ] Create `repository.go` with interface:

```go
type Repository interface {
	CleanExpired(ctx context.Context, now time.Time) error
	CountByStatus(ctx context.Context, query StatusCountQuery) (map[int]int64, error)
	List(ctx context.Context, query ListQuery) ([]Task, int64, error)
	Create(ctx context.Context, row Task) (int64, error)
	MarkSuccess(ctx context.Context, id int64, result SuccessResult) error
	MarkFailed(ctx context.Context, id int64, message string) error
	DeleteByUser(ctx context.Context, userID int64, ids []int64) error
	Get(ctx context.Context, id int64) (*Task, error)
}
```

Repository rules:

```text
CleanExpired: expire_at < now AND is_del=2 -> is_del=1
Count/List: WHERE user_id=? AND is_del=2
Filters: status exact; title/file_name prefix LIKE
MarkSuccess: status=2 + file fields + clear error_msg
MarkFailed: status=3 + capped error_msg
DeleteByUser: user_id=? AND id IN ? AND is_del=2 -> is_del=1
```

- [ ] Create `service.go` with:

```go
func NewService(repository Repository, opts ...Option) *Service
func (s *Service) StatusCount(ctx context.Context, query StatusCountQuery) ([]StatusCountItem, *apperror.Error)
func (s *Service) List(ctx context.Context, query ListQuery) (*ListResponse, *apperror.Error)
func (s *Service) CreatePending(ctx context.Context, input CreatePendingInput) (int64, error)
func (s *Service) MarkSuccess(ctx context.Context, id int64, result SuccessResult) error
func (s *Service) MarkFailed(ctx context.Context, id int64, message string) error
func (s *Service) Delete(ctx context.Context, input DeleteInput) *apperror.Error
```

- [ ] Create `request.go`, `handler.go`, `route.go`:

```text
GET    /api/admin/v1/export-tasks/status-count
GET    /api/admin/v1/export-tasks
DELETE /api/admin/v1/export-tasks/:id
DELETE /api/admin/v1/export-tasks
```

Handlers must read `middleware.GetAuthIdentity(c)` and return 401 if missing.

- [ ] Add `handler_test.go` for auth scoping and route binding.
- [ ] Verify:

```powershell
go test ./internal/module/exporttask -count=1
```

Expected: PASS.

---

## Task 3: XLSX writer and COS uploader

**Files:** `writer.go`, `uploader.go`, `upload_config_repository.go`, `writer_test.go`, `uploader_test.go`

- [ ] Write `writer_test.go` that creates an xlsx with `id` and `phone`, opens it using Excelize, and verifies phone/id are read back as strings.
- [ ] Implement `writer.go`:

```go
type Column struct { Key string; Title string }
type FileData struct { Headers []Column; Rows []map[string]string; Prefix string }
type XLSXWriter struct{}
func (XLSXWriter) Write(data FileData) ([]byte, error)
```

Use `excelize.NewFile()`, `SetCellStr`, `CoordinatesToCellName`, and `WriteToBuffer()`.

- [ ] Write `uploader_test.go` with fake upload config repo and fake COS object writer. Verify:

```text
key starts with exports/YYYYMMDD/
content-type is xlsx MIME
result returns file name, url, size, row_count
missing config and non-cos driver fail explicitly
```

- [ ] Implement `upload_config_repository.go` with exporttask-owned query. Do not import `clientversion` for upload config.
- [ ] Implement `uploader.go`:

```text
file_name = <prefix>_YYYYMMDD_HHMMSS_<task_id>.xlsx
key       = exports/YYYYMMDD/<file_name>
content-type = application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
url uses bucket_domain when present, otherwise https://<bucket>.cos.<region>.myqcloud.com/<key>
```

- [ ] Verify:

```powershell
go test ./internal/module/exporttask -run 'Test(XLSXWriter|COSUploader)' -count=1
```

Expected: PASS.

---

## Task 4: Worker job handler

**Files:** `exporttask/jobs.go`, `exporttask/service.go`, `internal/jobs/noop.go`, `internal/jobs/noop_test.go`, `internal/bootstrap/worker.go`

- [ ] Write `jobs_test.go` proving:

```text
NewRunTask returns Type=export:run:v1 and Queue=low.
DecodeRunPayload rejects missing task_id/kind/user_id/ids.
RegisterHandlers processes a task through taskqueue.Mux.
```

- [ ] Create `jobs.go`:

```go
const TypeRunV1 = "export:run:v1"
const KindUserList = "user_list"

type RunPayload struct {
	TaskID   int64   `json:"task_id"`
	Kind     string  `json:"kind"`
	UserID   int64   `json:"user_id"`
	Platform string  `json:"platform"`
	IDs      []int64 `json:"ids"`
}
type RunInput = RunPayload
type JobService interface { Run(ctx context.Context, input RunInput) error }
```

`NewRunTask` uses `taskqueue.QueueLow`, `MaxRetry: 3`, `Timeout: 5*time.Minute`.

- [ ] Extend `Service` with worker dependencies:

```go
type ExportDataProvider interface { BuildExportData(ctx context.Context, kind string, ids []int64) (*FileData, error) }
type FileWriter interface { Write(data FileData) ([]byte, error) }
type FileUploader interface { Upload(ctx context.Context, input UploadInput) (*UploadResult, error) }
type Notifier interface { NotifyExportSuccess(ctx context.Context, input NotifyInput) error; NotifyExportFailed(ctx context.Context, input NotifyInput) error }
func (s *Service) Run(ctx context.Context, input RunInput) error
```

Run flow:

```text
validate payload -> repo.Get(task_id) -> noop if missing/deleted/success
provider.BuildExportData(kind, ids) -> writer.Write -> uploader.Upload
MarkSuccess -> best-effort success notification
on generation/upload error: MarkFailed -> best-effort failed notification -> return error
```

- [ ] Update `internal/jobs/noop.go` dependencies:

```go
ExportTaskService exporttask.JobService
```

Call `exporttask.RegisterHandlers(mux, deps.ExportTaskService, logger)`.

- [ ] Update `worker.go` to build a worker-grade exporttask service with:

```text
exporttask.NewGormRepository(resources.DB)
exporttask.NewGormUploadConfigRepository(resources.DB)
secretbox.New(cfg.Secretbox.Key)
storagecos.NewObjectWriter(storagecos.ObjectWriterConfig{Enabled: cfg.UploadToken.COS.Enabled})
exporttask.XLSXWriter{}
user.NewExportDataProvider(user.NewGormRepository(resources.DB))
notificationtask-backed notifier
```

- [ ] Verify:

```powershell
go test ./internal/module/exporttask ./internal/jobs ./internal/bootstrap -count=1
```

Expected: PASS.

---

## Task 5: User export submit endpoint

**Files:** `internal/module/user/*`

- [ ] Add user service tests proving:

```text
Export rejects empty ids.
Export normalizes duplicate ids.
Export creates pending export task.
Export enqueues export:run:v1 low queue task.
Enqueue failure marks created task failed and returns error.
```

- [ ] Add DTO/request:

```go
type ExportInput struct { UserID int64; Platform string; IDs []int64 }
type ExportResponse struct { ID int64 `json:"id"`; Message string `json:"message"` }
type ExportUserRow struct { ID int64; Username string; Email string; Phone string; Avatar string; Sex int; RoleName string }
type exportRequest struct { IDs []int64 `json:"ids" binding:"required,min=1,dive,gt=0"` }
```

- [ ] Add repository method:

```go
ExportUsersByIDs(ctx context.Context, ids []int64) ([]ExportUserRow, error)
```

Query from `users`, left join `user_profiles`, left join `roles`, only `users.is_del=2`.

- [ ] Add `user.NewExportDataProvider(repository)` implementing `exporttask.ExportDataProvider` for `exporttask.KindUserList` with headers:

```text
id 用户ID
username 用户名
email 邮箱
phone 手机号
avatar 头像
sex 性别
role 角色
```

- [ ] Add `Service.Export(ctx, ExportInput)`:

```text
normalize ids -> verify selected users exist -> CreatePending(user_id,'用户列表导出')
NewRunTask(task_id,user_list,user_id,platform,ids) -> Enqueue
on enqueue error MarkFailed(task_id,error) and return Internal('提交导出任务失败')
return {id, message:'导出任务已提交，完成后将通知您'}
```

- [ ] Add handler method `Export(c)` using current auth identity and `response.OK`.
- [ ] Add route:

```go
users.POST("/export", handler.Export)
```

- [ ] Verify:

```powershell
go test ./internal/module/user -run Export -count=1
go test ./internal/module/user -count=1
```

Expected: PASS.

---

## Task 6: Router, metadata, and API bootstrap

**Files:** `server/router.go`, `server/router_test.go`, `bootstrap/app.go`, `bootstrap/route_meta.go`, `bootstrap/route_meta_test.go`

- [ ] Add `ExportTaskService exporttask.HTTPService` to router dependencies.
- [ ] Register `exporttask.RegisterRoutes(router, deps.ExportTaskService)`.
- [ ] In `permissionRouteRules`, add only:

```go
middleware.NewRouteKey(http.MethodPost, "/api/admin/v1/users/export"): "user_userManager_export",
```

Do not invent export-task delete permission in this slice.

- [ ] In `operationRouteRules`, add:

```text
POST   /api/admin/v1/users/export        user/export/用户导出
DELETE /api/admin/v1/export-tasks/:id    export_task/delete/删除导出任务
DELETE /api/admin/v1/export-tasks        export_task/delete_batch/批量删除导出任务
```

- [ ] Wire API `app.go`: API process builds exporttask lifecycle service and passes it to router; user service receives export task creator and queue enqueuer. API process does not build xlsx writer or uploader.
- [ ] Add router tests for `POST /users/export`, `GET /export-tasks/status-count`, `GET /export-tasks`, `DELETE /export-tasks/:id`.
- [ ] Verify:

```powershell
go test ./internal/bootstrap ./internal/server -count=1
```

Expected: PASS.

---

## Task 7: Frontend API migration

**Files:** `src/types/user.ts`, `src/api/user/users.ts`, `src/api/system/exportTask.ts`, frontend tests

- [ ] Create `tests/shared/system/export-task-api.test.ts` asserting:

```text
src/api/system/exportTask.ts imports request, not legacyRequest.
It uses `${ADMIN_API_PREFIX}/export-tasks/status-count`.
It uses `${ADMIN_API_PREFIX}/export-tasks`.
It does not contain /api/admin/ExportTask/statusCount, /list, /del.
It has explicit single delete path and batch delete body.
```

- [ ] Update `tests/shared/user/user-list.test.ts` to assert `src/api/user/users.ts` does not contain `/api/admin/UsersList/export` and still keeps `user_userManager_export` button guard.
- [ ] Update `UserExportResponse`:

```ts
export interface UserExportResponse {
  id: number
  message: string
}
```

- [ ] Switch `UsersListApi.export`:

```ts
export: (params: { ids: number[] }) =>
  request.post<UserExportResponse, { ids: number[] }>(`${ADMIN_API_PREFIX}/users/export`, params),
```

- [ ] Switch `ExportTaskApi` to Go REST:

```ts
statusCount: params => request.get(`${ADMIN_API_PREFIX}/export-tasks/status-count`, { params })
list: params => request.get(`${ADMIN_API_PREFIX}/export-tasks`, { params })
del: single id -> DELETE /export-tasks/:id; multiple ids -> DELETE /export-tasks body { ids }
```

- [ ] Verify:

```powershell
cd E:\admin_go\admin_front_ts
pnpm exec vitest run tests/shared/user/user-list.test.ts tests/shared/system/export-task-api.test.ts
```

Expected: PASS.

---

## Task 8: Docs and smoke matrix

**Files:** `docs/contracts/admin-api-v1.md`, `docs/migration/current-status.md`, `docs/testing/smoke-matrix.md`, `admin_back_go/docs/architecture.md`

- [ ] Update API contract with exact endpoints:

```text
POST /api/admin/v1/users/export
GET /api/admin/v1/export-tasks/status-count
GET /api/admin/v1/export-tasks
DELETE /api/admin/v1/export-tasks/:id
DELETE /api/admin/v1/export-tasks
```

- [ ] Update current status: users management now includes export submit and Go export worker runtime.
- [ ] Add/export task row: REST status-count/list/delete current-user scoped; worker supports user_list export.
- [ ] Update architecture: queue payload stores IDs, not rendered rows; worker owns xlsx and COS upload.
- [ ] Update smoke matrix with read-only probes only:

```text
GET /api/admin/v1/export-tasks/status-count
GET /api/admin/v1/export-tasks?current_page=1&page_size=20
```

- [ ] Stale text check:

```powershell
cd E:\admin_go
rg -n "export still explicit legacy adapter|等待 Go export-task|UsersList/export|ExportTask/statusCount|ExportTask/list|ExportTask/del" docs admin_back_go\docs admin_front_ts\src\api
```

Expected: no stale legacy export statements.

---

## Task 9: Final verification gate

- [ ] Backend targeted:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/enum ./internal/module/exporttask ./internal/module/user ./internal/jobs ./internal/bootstrap ./internal/server -count=1
```

Expected: PASS.

- [ ] Backend full:

```powershell
go test ./...
go vet ./...
```

Expected: PASS.

- [ ] Frontend targeted:

```powershell
cd E:\admin_go\admin_front_ts
pnpm exec vitest run tests/shared/user/user-list.test.ts tests/shared/system/export-task-api.test.ts
pnpm exec vue-tsc --noEmit
```

Expected: PASS.

- [ ] Residue review:

```powershell
cd E:\admin_go
rg -n "UsersList/export|ExportTask/statusCount|ExportTask/list|ExportTask/del" admin_front_ts\src admin_front_ts\tests docs admin_back_go\docs
rg -n "user_userManager_edit.*export|export.*user_userManager_edit" admin_back_go admin_front_ts docs
git status --short
git diff -- docs admin_back_go admin_front_ts
```

Expected:

```text
No legacy export endpoints in active frontend/docs.
No export bound to user_userManager_edit.
Diff contains no unrelated UI changes and no PHP path added to Go code.
```

## Self-review

```text
Spec coverage: user export submit, export task REST, worker xlsx/COS runtime, permission/operation log, frontend migration, docs, and verification are each covered by tasks.
Red-flag scan: no incomplete markers are present.
Type consistency: queue type export:run:v1, kind user_list, status 1/2/3, and UserExportResponse{id,message} are consistent across tasks.
```

