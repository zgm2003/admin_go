# System Cron Task Go Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish the System Management scheduled task foundation by migrating `cron_task` management, `cron_task_log`, and worker scheduler registration from PHP legacy to Go REST + Go registry + Asynq.

**Architecture:** Keep `admin-api` as REST-only and `admin-worker` as queue/scheduler owner. `cron_task` DB rows control cron/status/title/log visibility; Go registry controls what can actually execute; gocron callback only writes scheduler logs and enqueues versioned Asynq tasks. No dynamic handler string execution.

**Tech Stack:** Go 1.21+, Gin, GORM, MySQL, Asynq, gocron/v2, Vue 3, TypeScript, Element Plus.

---

## Non-Negotiable Rules

- [ ] Do not execute `cron_task.handler` as code.
- [ ] Do not register PHP-only tasks as fake Go tasks.
- [ ] Do not keep `legacyRequest` in `src/api/system/cronTask.ts`.
- [ ] Do not make scheduler callback do business work; it only enqueues Asynq tasks.
- [ ] Do not let one missing/invalid cron row prevent `admin-worker` startup.
- [ ] Do not claim pay/AI/chat cron handlers are implemented in this slice.
- [ ] Do not introduce `any`, `as any`, or `Record<string, any>` in touched frontend code.
- [ ] Update docs and smoke matrix in the same implementation slice.

## File Map

Backend create:

```text
admin_back_go/internal/module/crontask/model.go
admin_back_go/internal/module/crontask/dto.go
admin_back_go/internal/module/crontask/request.go
admin_back_go/internal/module/crontask/registry.go
admin_back_go/internal/module/crontask/repository.go
admin_back_go/internal/module/crontask/service.go
admin_back_go/internal/module/crontask/scheduler_service.go
admin_back_go/internal/module/crontask/handler.go
admin_back_go/internal/module/crontask/route.go
admin_back_go/internal/module/crontask/*_test.go
```

Backend modify:

```text
admin_back_go/internal/server/router.go
admin_back_go/internal/server/router_test.go
admin_back_go/internal/bootstrap/app.go
admin_back_go/internal/bootstrap/worker.go
admin_back_go/internal/bootstrap/worker_test.go
admin_back_go/internal/bootstrap/route_meta.go
admin_back_go/internal/bootstrap/route_meta_test.go
admin_back_go/internal/jobs/noop.go
admin_back_go/internal/jobs/noop_test.go
admin_back_go/internal/platform/scheduler/scheduler.go
admin_back_go/internal/platform/scheduler/scheduler_test.go
admin_back_go/scripts/full-admin-smoke.ps1
```

Frontend modify:

```text
admin_front_ts/src/api/system/cronTask.ts
admin_front_ts/src/views/Main/system/cronTask/index.vue
```

Docs modify:

```text
docs/contracts/admin-api-v1.md
docs/migration/current-status.md
docs/testing/smoke-matrix.md
admin_back_go/docs/architecture.md
```

## Task 1: Backend module skeleton and registry

**Files:**
- Create: `admin_back_go/internal/module/crontask/model.go`
- Create: `admin_back_go/internal/module/crontask/dto.go`
- Create: `admin_back_go/internal/module/crontask/registry.go`
- Create: `admin_back_go/internal/module/crontask/registry_test.go`

- [ ] **Step 1: Write registry test**

Create `internal/module/crontask/registry_test.go`:

```go
package crontask

import (
	"testing"

	"admin_back_go/internal/module/notificationtask"
)

func TestDefaultRegistryContainsNotificationTaskSchedulerOnly(t *testing.T) {
	registry := NewDefaultRegistry()

	entry, ok := registry.Lookup("notification_task_scheduler")
	if !ok {
		t.Fatalf("expected notification_task_scheduler registry entry")
	}
	if entry.TaskType != notificationtask.TypeDispatchDueV1 {
		t.Fatalf("expected task type %s, got %s", notificationtask.TypeDispatchDueV1, entry.TaskType)
	}
	if entry.BuildTask == nil {
		t.Fatalf("expected BuildTask")
	}

	task, err := entry.BuildTask()
	if err != nil {
		t.Fatalf("BuildTask returned error: %v", err)
	}
	if task.Type != notificationtask.TypeDispatchDueV1 {
		t.Fatalf("expected task type %s, got %s", notificationtask.TypeDispatchDueV1, task.Type)
	}

	if _, ok := registry.Lookup("pay_close_expired_order"); ok {
		t.Fatalf("pay_close_expired_order must not be registered until pay cron handler migrates to Go")
	}
}
```

- [ ] **Step 2: Run failing test**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/crontask
```

Expected: package missing or `NewDefaultRegistry` undefined.

- [ ] **Step 3: Add models and DTO constants**

Create `internal/module/crontask/model.go`:

```go
package crontask

import "time"

const (
	CommonYes = 1
	CommonNo  = 2

	LogStatusSuccess = 1
	LogStatusFailed  = 2
	LogStatusRunning = 3

	RegistryStatusRegistered = "registered"
	RegistryStatusMissing    = "missing"
	RegistryStatusDisabled   = "disabled"
	RegistryStatusInvalidCron = "invalid_cron"
)

type Task struct {
	ID           int64     `gorm:"column:id"`
	Name         string    `gorm:"column:name"`
	Title        string    `gorm:"column:title"`
	Description  string    `gorm:"column:description"`
	Cron         string    `gorm:"column:cron"`
	CronReadable string    `gorm:"column:cron_readable"`
	Handler      string    `gorm:"column:handler"`
	Status       int       `gorm:"column:status"`
	IsDel        int       `gorm:"column:is_del"`
	CreatedAt    time.Time `gorm:"column:created_at"`
	UpdatedAt    time.Time `gorm:"column:updated_at"`
}

func (Task) TableName() string { return "cron_task" }

type TaskLog struct {
	ID         int64      `gorm:"column:id"`
	TaskID     int64      `gorm:"column:task_id"`
	TaskName   string     `gorm:"column:task_name"`
	StartTime  *time.Time `gorm:"column:start_time"`
	EndTime    *time.Time `gorm:"column:end_time"`
	DurationMS *int64     `gorm:"column:duration_ms"`
	Status     int        `gorm:"column:status"`
	Result     string     `gorm:"column:result"`
	ErrorMsg   string     `gorm:"column:error_msg"`
	IsDel      int        `gorm:"column:is_del"`
	CreatedAt  time.Time  `gorm:"column:created_at"`
}

func (TaskLog) TableName() string { return "cron_task_log" }
```

Create `internal/module/crontask/dto.go`:

```go
package crontask

import "admin_back_go/internal/dict"

type Page struct {
	PageSize    int   `json:"page_size"`
	CurrentPage int   `json:"current_page"`
	TotalPage   int   `json:"total_page"`
	Total       int64 `json:"total"`
}

type InitResponse struct {
	Dict InitDict `json:"dict"`
}

type InitDict struct {
	CronPresetArr          []dict.Option[string] `json:"cron_preset_arr"`
	CronTaskStatusArr      []dict.Option[int]    `json:"cron_task_status_arr"`
	CronTaskRegistryStatus []dict.Option[string] `json:"cron_task_registry_status_arr"`
	CronTaskLogStatusArr   []dict.Option[int]    `json:"cron_task_log_status_arr"`
}

type ListResponse struct {
	List []ListItem `json:"list"`
	Page Page       `json:"page"`
}

type ListItem struct {
	ID                     int64  `json:"id"`
	Name                   string `json:"name"`
	Title                  string `json:"title"`
	Description            string `json:"description"`
	Cron                   string `json:"cron"`
	CronReadable           string `json:"cron_readable"`
	Handler                string `json:"handler"`
	Status                 int    `json:"status"`
	StatusName             string `json:"status_name"`
	NextRunTime            string `json:"next_run_time"`
	RegistryStatus         string `json:"registry_status"`
	RegistryStatusText     string `json:"registry_status_text"`
	RegistryTaskType       string `json:"registry_task_type"`
	RegistryDescription    string `json:"registry_description"`
	CreatedAt              string `json:"created_at"`
	UpdatedAt              string `json:"updated_at"`
}

type LogsResponse struct {
	List []LogItem `json:"list"`
	Page Page      `json:"page"`
}

type LogItem struct {
	ID         int64   `json:"id"`
	TaskID     int64   `json:"task_id"`
	TaskName   string  `json:"task_name"`
	StartTime  *string `json:"start_time"`
	EndTime    *string `json:"end_time"`
	DurationMS *int64  `json:"duration_ms"`
	Status     int     `json:"status"`
	StatusName string  `json:"status_name"`
	Result     *string `json:"result"`
	ErrorMsg   *string `json:"error_msg"`
	CreatedAt  string  `json:"created_at"`
}
```

- [ ] **Step 4: Add registry implementation**

Create `internal/module/crontask/registry.go`:

```go
package crontask

import (
	"strings"

	"admin_back_go/internal/module/notificationtask"
	"admin_back_go/internal/platform/taskqueue"
)

type RegistryEntry struct {
	Name        string
	TaskType    string
	Description string
	BuildTask   func() (taskqueue.Task, error)
}

type Registry struct {
	entries map[string]RegistryEntry
}

func NewRegistry(entries []RegistryEntry) Registry {
	m := make(map[string]RegistryEntry, len(entries))
	for _, entry := range entries {
		name := strings.TrimSpace(entry.Name)
		if name == "" {
			continue
		}
		entry.Name = name
		m[name] = entry
	}
	return Registry{entries: m}
}

func NewDefaultRegistry() Registry {
	return NewRegistry([]RegistryEntry{
		{
			Name:        "notification_task_scheduler",
			TaskType:    notificationtask.TypeDispatchDueV1,
			Description: "扫描待发送通知任务并投递 notification:send-task:v1",
			BuildTask: func() (taskqueue.Task, error) {
				return notificationtask.NewDispatchDueTask(notificationtask.DispatchDuePayload{})
			},
		},
	})
}

func (r Registry) Lookup(name string) (RegistryEntry, bool) {
	if r.entries == nil {
		return RegistryEntry{}, false
	}
	entry, ok := r.entries[strings.TrimSpace(name)]
	return entry, ok
}
```

- [ ] **Step 5: Verify task**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/crontask
```

Expected: PASS.

## Task 2: Request binding, repository, service list/init/logs

**Files:**
- Create: `admin_back_go/internal/module/crontask/request.go`
- Create: `admin_back_go/internal/module/crontask/repository.go`
- Create: `admin_back_go/internal/module/crontask/service.go`
- Create: `admin_back_go/internal/module/crontask/service_test.go`

- [ ] **Step 1: Write service tests**

Create `internal/module/crontask/service_test.go` with fake repository tests for list decoration:

```go
package crontask

import (
	"context"
	"errors"
	"testing"
	"time"
)

func TestServiceListDecoratesRegistryStatus(t *testing.T) {
	now := time.Date(2026, 5, 6, 12, 0, 0, 0, time.Local)
	repo := &fakeRepository{
		tasks: []Task{
			{ID: 1, Name: "notification_task_scheduler", Title: "通知任务调度器", Cron: "0 * * * * *", Status: CommonYes, IsDel: CommonNo, CreatedAt: now, UpdatedAt: now},
			{ID: 2, Name: "pay_close_expired_order", Title: "支付超时关单", Cron: "0 * * * * *", Status: CommonYes, IsDel: CommonNo, Handler: "app\\process\\Pay\\PayCloseExpiredOrderTask", CreatedAt: now, UpdatedAt: now},
			{ID: 3, Name: "disabled_task", Title: "禁用任务", Cron: "0 * * * * *", Status: CommonNo, IsDel: CommonNo, CreatedAt: now, UpdatedAt: now},
			{ID: 4, Name: "bad_cron", Title: "错误表达式", Cron: "bad", Status: CommonYes, IsDel: CommonNo, CreatedAt: now, UpdatedAt: now},
		},
	}
	service := NewService(repo, NewDefaultRegistry())

	res, appErr := service.List(context.Background(), ListQuery{CurrentPage: 1, PageSize: 20})
	if appErr != nil {
		t.Fatalf("List returned appErr: %v", appErr)
	}
	if len(res.List) != 4 {
		t.Fatalf("expected 4 items, got %#v", res.List)
	}
	assertStatus(t, res.List[0], RegistryStatusRegistered)
	assertStatus(t, res.List[1], RegistryStatusMissing)
	assertStatus(t, res.List[2], RegistryStatusDisabled)
	assertStatus(t, res.List[3], RegistryStatusInvalidCron)
}

func TestServiceCreateRejectsDuplicateName(t *testing.T) {
	service := NewService(&fakeRepository{nameExists: true}, NewDefaultRegistry())
	_, appErr := service.Create(context.Background(), SaveInput{Name: "notification_task_scheduler", Title: "通知", Cron: "0 * * * * *", Status: CommonYes})
	if appErr == nil {
		t.Fatalf("expected duplicate name app error")
	}
}

func TestServiceCreateRejectsInvalidCron(t *testing.T) {
	service := NewService(&fakeRepository{}, NewDefaultRegistry())
	_, appErr := service.Create(context.Background(), SaveInput{Name: "demo_task", Title: "demo", Cron: "bad", Status: CommonYes})
	if appErr == nil {
		t.Fatalf("expected invalid cron app error")
	}
}

func TestServiceLogsMapsStatusAndDates(t *testing.T) {
	start := time.Date(2026, 5, 6, 12, 0, 0, 0, time.Local)
	end := start.Add(time.Second)
	duration := int64(1000)
	repo := &fakeRepository{
		logs: []TaskLog{{ID: 9, TaskID: 1, TaskName: "notification_task_scheduler", StartTime: &start, EndTime: &end, DurationMS: &duration, Status: LogStatusSuccess, Result: "queued", CreatedAt: start}},
	}
	service := NewService(repo, NewDefaultRegistry())
	res, appErr := service.Logs(context.Background(), LogsQuery{TaskID: 1, CurrentPage: 1, PageSize: 20})
	if appErr != nil {
		t.Fatalf("Logs returned appErr: %v", appErr)
	}
	if len(res.List) != 1 || res.List[0].StatusName != "成功" || res.List[0].StartTime == nil {
		t.Fatalf("unexpected logs response: %#v", res.List)
	}
}

func assertStatus(t *testing.T, item ListItem, want string) {
	t.Helper()
	if item.RegistryStatus != want {
		t.Fatalf("task %s expected registry_status=%s, got %#v", item.Name, want, item)
	}
}

type fakeRepository struct {
	tasks      []Task
	logs       []TaskLog
	nameExists bool
	createID   int64
	err        error
}

func (f *fakeRepository) List(ctx context.Context, query ListQuery) ([]Task, int64, error) {
	return f.tasks, int64(len(f.tasks)), f.err
}
func (f *fakeRepository) NameExists(ctx context.Context, name string, excludeID int64) (bool, error) {
	return f.nameExists, f.err
}
func (f *fakeRepository) Create(ctx context.Context, row Task) (int64, error) {
	if f.err != nil {
		return 0, f.err
	}
	if f.createID == 0 {
		return 1, nil
	}
	return f.createID, nil
}
func (f *fakeRepository) Get(ctx context.Context, id int64) (*Task, error) {
	if f.err != nil {
		return nil, f.err
	}
	for _, task := range f.tasks {
		if task.ID == id {
			return &task, nil
		}
	}
	return nil, ErrTaskNotFound
}
func (f *fakeRepository) Update(ctx context.Context, id int64, row Task) error { return f.err }
func (f *fakeRepository) UpdateStatus(ctx context.Context, id int64, status int) error { return f.err }
func (f *fakeRepository) Delete(ctx context.Context, ids []int64) error { return f.err }
func (f *fakeRepository) Logs(ctx context.Context, query LogsQuery) ([]TaskLog, int64, error) {
	return f.logs, int64(len(f.logs)), f.err
}
func (f *fakeRepository) ListEnabled(ctx context.Context) ([]Task, error) { return f.tasks, f.err }
func (f *fakeRepository) LogStart(ctx context.Context, task Task, now time.Time) (int64, error) {
	if f.err != nil {
		return 0, f.err
	}
	return 1, nil
}
func (f *fakeRepository) LogEnd(ctx context.Context, logID int64, success bool, result string, errMsg string, now time.Time) error {
	if errors.Is(f.err, ErrTaskNotFound) {
		return nil
	}
	return f.err
}
```

- [ ] **Step 2: Run failing tests**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/crontask
```

Expected: service types undefined.

- [ ] **Step 3: Add requests and interfaces**

Create `internal/module/crontask/request.go`:

```go
package crontask

type listRequest struct {
	CurrentPage    int     `form:"current_page" binding:"required,min=1"`
	PageSize       int     `form:"page_size" binding:"required,min=1,max=100"`
	Title          string  `form:"title" binding:"omitempty,max=100"`
	Status         *int    `form:"status" binding:"omitempty,oneof=1 2"`
	RegistryStatus string `form:"registry_status" binding:"omitempty,oneof=registered missing disabled invalid_cron"`
}

type saveRequest struct {
	Name         string `json:"name" binding:"required,max=50"`
	Title        string `json:"title" binding:"required,max=100"`
	Description string `json:"description" binding:"omitempty,max=255"`
	Cron         string `json:"cron" binding:"required,max=50"`
	CronReadable string `json:"cron_readable" binding:"omitempty,max=50"`
	Handler      string `json:"handler" binding:"omitempty,max=255"`
	Status       int    `json:"status" binding:"required,oneof=1 2"`
}

type statusRequest struct {
	Status int `json:"status" binding:"required,oneof=1 2"`
}

type batchDeleteRequest struct {
	IDs []int64 `json:"ids" binding:"required,min=1,dive,min=1"`
}

type logsRequest struct {
	CurrentPage int    `form:"current_page" binding:"required,min=1"`
	PageSize    int    `form:"page_size" binding:"required,min=1,max=100"`
	Status      *int   `form:"status" binding:"omitempty,oneof=1 2 3"`
	Date        string `form:"date" binding:"omitempty,max=64"`
}
```

- [ ] **Step 4: Add repository interface and GORM implementation**

Create `internal/module/crontask/repository.go`:

```go
package crontask

import (
	"context"
	"errors"
	"time"

	"gorm.io/gorm"
)

var (
	ErrRepositoryNotConfigured = errors.New("cron task repository is not configured")
	ErrTaskNotFound            = errors.New("cron task not found")
)

type Repository interface {
	List(ctx context.Context, query ListQuery) ([]Task, int64, error)
	NameExists(ctx context.Context, name string, excludeID int64) (bool, error)
	Create(ctx context.Context, row Task) (int64, error)
	Get(ctx context.Context, id int64) (*Task, error)
	Update(ctx context.Context, id int64, row Task) error
	UpdateStatus(ctx context.Context, id int64, status int) error
	Delete(ctx context.Context, ids []int64) error
	Logs(ctx context.Context, query LogsQuery) ([]TaskLog, int64, error)
	ListEnabled(ctx context.Context) ([]Task, error)
	LogStart(ctx context.Context, task Task, now time.Time) (int64, error)
	LogEnd(ctx context.Context, logID int64, success bool, result string, errMsg string, now time.Time) error
}

type GormRepository struct{ db *gorm.DB }

func NewGormRepository(db *gorm.DB) *GormRepository { return &GormRepository{db: db} }

func (r *GormRepository) requireDB() (*gorm.DB, error) {
	if r == nil || r.db == nil {
		return nil, ErrRepositoryNotConfigured
	}
	return r.db, nil
}
```

Then implement methods in the same file using existing module patterns:

```go
func (r *GormRepository) List(ctx context.Context, query ListQuery) ([]Task, int64, error) {
	db, err := r.requireDB()
	if err != nil { return nil, 0, err }
	q := db.WithContext(ctx).Model(&Task{}).Where("is_del = ?", CommonNo)
	if query.Title != "" { q = q.Where("title LIKE ?", query.Title+"%") }
	if query.Status != nil { q = q.Where("status = ?", *query.Status) }
	var total int64
	if err := q.Count(&total).Error; err != nil { return nil, 0, err }
	var rows []Task
	offset := (query.CurrentPage - 1) * query.PageSize
	if err := q.Order("id ASC").Limit(query.PageSize).Offset(offset).Find(&rows).Error; err != nil { return nil, 0, err }
	return rows, total, nil
}
```

Also implement `NameExists`, `Create`, `Get`, `Update`, `UpdateStatus`, `Delete`, `Logs`, `ListEnabled`, `LogStart`, `LogEnd`. Use `is_del=2`, soft delete by setting `is_del=1`, and `created_at/updated_at` fields.

- [ ] **Step 5: Add service implementation**

Create `internal/module/crontask/service.go` with:

```go
package crontask

import (
	"context"
	"regexp"
	"strings"
	"time"

	"admin_back_go/internal/apperror"
	"admin_back_go/internal/dict"
)

var taskNamePattern = regexp.MustCompile(`^[a-z][a-z0-9_]{0,49}$`)

type ListQuery struct {
	CurrentPage    int
	PageSize       int
	Title          string
	Status         *int
	RegistryStatus string
}

type LogsQuery struct {
	TaskID      int64
	CurrentPage int
	PageSize    int
	Status      *int
	Date        string
}

type SaveInput struct {
	ID           int64
	Name         string
	Title        string
	Description  string
	Cron         string
	CronReadable string
	Handler      string
	Status       int
}

type Service struct {
	repo     Repository
	registry Registry
	now      func() time.Time
}

func NewService(repo Repository, registry Registry) *Service {
	return &Service{repo: repo, registry: registry, now: time.Now}
}
```

Implement:

```go
func (s *Service) Init(ctx context.Context) (*InitResponse, *apperror.Error)
func (s *Service) List(ctx context.Context, query ListQuery) (*ListResponse, *apperror.Error)
func (s *Service) Create(ctx context.Context, input SaveInput) (*ListItem, *apperror.Error)
func (s *Service) Update(ctx context.Context, id int64, input SaveInput) *apperror.Error
func (s *Service) ChangeStatus(ctx context.Context, id int64, status int) *apperror.Error
func (s *Service) Delete(ctx context.Context, ids []int64) *apperror.Error
func (s *Service) Logs(ctx context.Context, query LogsQuery) (*LogsResponse, *apperror.Error)
```

Use helper rules:

```go
func validateTaskName(name string) bool { return taskNamePattern.MatchString(name) }
func validateSixFieldCron(expr string) bool { return len(strings.Fields(expr)) == 6 }
func statusName(status int) string
func registryStatusName(status string) string
func logStatusName(status int) string
```

For first slice, `next_run_time` can use a helper that returns `-` for invalid and simple presets; runtime validity is still enforced by gocron at registration.

- [ ] **Step 6: Verify service tests**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/crontask
```

Expected: PASS.

## Task 3: Scheduler service and DB-aware schedule registration

**Files:**
- Create: `admin_back_go/internal/module/crontask/scheduler_service.go`
- Create: `admin_back_go/internal/module/crontask/scheduler_service_test.go`
- Modify: `admin_back_go/internal/jobs/noop.go`
- Modify: `admin_back_go/internal/jobs/noop_test.go`

- [ ] **Step 1: Write scheduler service tests**

Create `internal/module/crontask/scheduler_service_test.go`:

```go
package crontask

import (
	"context"
	"errors"
	"log/slog"
	"testing"
	"time"

	"admin_back_go/internal/module/notificationtask"
	"admin_back_go/internal/platform/scheduler"
	"admin_back_go/internal/platform/taskqueue"
)

func TestSchedulerServiceRegistersOnlyEnabledRegisteredTasks(t *testing.T) {
	now := time.Date(2026, 5, 6, 12, 0, 0, 0, time.Local)
	repo := &fakeRepository{tasks: []Task{
		{ID: 1, Name: "notification_task_scheduler", Title: "通知任务调度器", Cron: "0 * * * * *", Status: CommonYes, IsDel: CommonNo, CreatedAt: now, UpdatedAt: now},
		{ID: 2, Name: "pay_close_expired_order", Title: "支付超时关单", Cron: "0 * * * * *", Status: CommonYes, IsDel: CommonNo, CreatedAt: now, UpdatedAt: now},
		{ID: 3, Name: "bad_cron", Title: "错误表达式", Cron: "bad", Status: CommonYes, IsDel: CommonNo, CreatedAt: now, UpdatedAt: now},
	}}
	registrar := &fakeScheduleRegistrar{}
	enqueuer := &fakeEnqueuer{}
	service := NewSchedulerService(repo, NewDefaultRegistry(), enqueuer, slog.Default())

	if err := service.RegisterEnabled(context.Background(), registrar); err != nil {
		t.Fatalf("RegisterEnabled returned error: %v", err)
	}
	if len(registrar.cronCalls) != 1 {
		t.Fatalf("expected one cron registration, got %#v", registrar.cronCalls)
	}
	if registrar.cronCalls[0].name != "notification_task_scheduler" {
		t.Fatalf("unexpected registered job: %#v", registrar.cronCalls[0])
	}
}

func TestSchedulerTaskLogsAndEnqueues(t *testing.T) {
	now := time.Date(2026, 5, 6, 12, 0, 0, 0, time.Local)
	repo := &fakeRepository{tasks: []Task{{ID: 1, Name: "notification_task_scheduler", Cron: "0 * * * * *", Status: CommonYes, IsDel: CommonNo}}}
	registrar := &fakeScheduleRegistrar{}
	enqueuer := &fakeEnqueuer{}
	service := NewSchedulerService(repo, NewDefaultRegistry(), enqueuer, slog.Default())
	service.now = func() time.Time { return now }

	if err := service.RegisterEnabled(context.Background(), registrar); err != nil {
		t.Fatalf("RegisterEnabled returned error: %v", err)
	}
	if err := registrar.cronCalls[0].task(context.Background()); err != nil {
		t.Fatalf("scheduled task returned error: %v", err)
	}
	if len(enqueuer.tasks) != 1 || enqueuer.tasks[0].Type != notificationtask.TypeDispatchDueV1 {
		t.Fatalf("expected notification dispatch task enqueue, got %#v", enqueuer.tasks)
	}
}

func TestSchedulerTaskWritesFailedLogWhenEnqueueFails(t *testing.T) {
	repo := &fakeRepository{tasks: []Task{{ID: 1, Name: "notification_task_scheduler", Cron: "0 * * * * *", Status: CommonYes, IsDel: CommonNo}}}
	registrar := &fakeScheduleRegistrar{}
	enqueuer := &fakeEnqueuer{err: errors.New("redis down")}
	service := NewSchedulerService(repo, NewDefaultRegistry(), enqueuer, slog.Default())

	if err := service.RegisterEnabled(context.Background(), registrar); err != nil {
		t.Fatalf("RegisterEnabled returned error: %v", err)
	}
	if err := registrar.cronCalls[0].task(context.Background()); err == nil {
		t.Fatalf("expected enqueue error")
	}
}

type fakeScheduleRegistrar struct {
	cronCalls []registeredCronCall
}

type registeredCronCall struct {
	name        string
	expression  string
	withSeconds bool
	task        scheduler.TaskFunc
}

func (f *fakeScheduleRegistrar) Every(name string, interval time.Duration, task scheduler.TaskFunc) error {
	return nil
}

func (f *fakeScheduleRegistrar) Cron(name string, expression string, withSeconds bool, task scheduler.TaskFunc) error {
	if len(expression) < 5 {
		return scheduler.ErrJobIntervalRequired
	}
	f.cronCalls = append(f.cronCalls, registeredCronCall{name: name, expression: expression, withSeconds: withSeconds, task: task})
	return nil
}

type fakeEnqueuer struct {
	tasks []taskqueue.Task
	err   error
}

func (f *fakeEnqueuer) Enqueue(ctx context.Context, task taskqueue.Task, opts ...taskqueue.Option) (*taskqueue.EnqueueResult, error) {
	if f.err != nil {
		return nil, f.err
	}
	f.tasks = append(f.tasks, task)
	return &taskqueue.EnqueueResult{ID: "task-id", Type: task.Type, Queue: task.Queue}, nil
}
```

- [ ] **Step 2: Run failing scheduler tests**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/crontask
```

Expected: `NewSchedulerService` undefined.

- [ ] **Step 3: Implement SchedulerService**

Create `internal/module/crontask/scheduler_service.go`:

```go
package crontask

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"admin_back_go/internal/jobs"
	"admin_back_go/internal/platform/scheduler"
	"admin_back_go/internal/platform/taskqueue"
)

type SchedulerService struct {
	repo     Repository
	registry Registry
	enqueuer taskqueue.Enqueuer
	logger   *slog.Logger
	now      func() time.Time
}

func NewSchedulerService(repo Repository, registry Registry, enqueuer taskqueue.Enqueuer, logger *slog.Logger) *SchedulerService {
	if logger == nil {
		logger = slog.Default()
	}
	return &SchedulerService{repo: repo, registry: registry, enqueuer: enqueuer, logger: logger, now: time.Now}
}

func (s *SchedulerService) RegisterEnabled(ctx context.Context, registrar jobs.ScheduleRegistrar) error {
	if s == nil || s.repo == nil {
		return ErrRepositoryNotConfigured
	}
	if registrar == nil {
		return jobs.ErrScheduleRegistrarRequired
	}
	if s.enqueuer == nil {
		return jobs.ErrScheduleEnqueuerRequired
	}
	rows, err := s.repo.ListEnabled(ctx)
	if err != nil {
		return fmt.Errorf("list enabled cron tasks: %w", err)
	}
	for _, row := range rows {
		entry, ok := s.registry.Lookup(row.Name)
		if !ok {
			s.logger.WarnContext(ctx, "cron task registry missing; schedule skipped", "name", row.Name, "handler", row.Handler)
			continue
		}
		if !validateSixFieldCron(row.Cron) {
			s.logger.WarnContext(ctx, "cron task cron invalid; schedule skipped", "name", row.Name, "cron", row.Cron)
			continue
		}
		taskFunc := s.enqueueWithLog(row, entry)
		if err := registrar.Cron(row.Name, row.Cron, true, taskFunc); err != nil {
			s.logger.WarnContext(ctx, "cron task schedule registration failed; schedule skipped", "name", row.Name, "cron", row.Cron, "error", err)
			continue
		}
		s.logger.InfoContext(ctx, "cron task schedule registered", "name", row.Name, "cron", row.Cron, "task_type", entry.TaskType)
	}
	return nil
}

func (s *SchedulerService) enqueueWithLog(row Task, entry RegistryEntry) scheduler.TaskFunc {
	return func(ctx context.Context) error {
		start := s.now()
		logID, err := s.repo.LogStart(ctx, row, start)
		if err != nil {
			return fmt.Errorf("cron task %s log start: %w", row.Name, err)
		}
		task, err := entry.BuildTask()
		if err != nil {
			_ = s.repo.LogEnd(ctx, logID, false, "", err.Error(), s.now())
			return fmt.Errorf("cron task %s build task: %w", row.Name, err)
		}
		result, err := s.enqueuer.Enqueue(ctx, task)
		if err != nil {
			_ = s.repo.LogEnd(ctx, logID, false, "", err.Error(), s.now())
			return fmt.Errorf("cron task %s enqueue %s: %w", row.Name, task.Type, err)
		}
		message := fmt.Sprintf("queued task_id=%s type=%s queue=%s", result.ID, result.Type, result.Queue)
		if err := s.repo.LogEnd(ctx, logID, true, message, "", s.now()); err != nil {
			return fmt.Errorf("cron task %s log end: %w", row.Name, err)
		}
		return nil
	}
}
```

- [ ] **Step 4: Deprecate static notification schedule**

Modify `internal/jobs/noop.go` so `RegisterSchedules` no longer statically registers `notification-task-dispatch-due`. Keep it as a compatibility function returning no error with an empty list, and document DB-backed cron task registration owns business schedules:

```go
func RegisterSchedules(registrar ScheduleRegistrar, enqueuer taskqueue.Enqueuer, logger *slog.Logger) error {
	return registerScheduleDefinitions(registrar, enqueuer, logger, nil)
}
```

Modify `internal/jobs/noop_test.go`:
- Replace `TestRegisterSchedulesRegistersNotificationDispatchDue` with `TestRegisterSchedulesHasNoStaticBusinessSchedules`.
- Assert no every/cron calls.

- [ ] **Step 5: Verify scheduler tests**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/crontask ./internal/jobs
```

Expected: PASS.

## Task 4: HTTP handler, routes, server wiring, metadata

**Files:**
- Create: `admin_back_go/internal/module/crontask/handler.go`
- Create: `admin_back_go/internal/module/crontask/route.go`
- Create: `admin_back_go/internal/module/crontask/handler_test.go`
- Modify: `admin_back_go/internal/server/router.go`
- Modify: `admin_back_go/internal/server/router_test.go`
- Modify: `admin_back_go/internal/bootstrap/app.go`
- Modify: `admin_back_go/internal/bootstrap/route_meta.go`
- Modify: `admin_back_go/internal/bootstrap/route_meta_test.go`

- [ ] **Step 1: Write handler/route tests**

Create `internal/module/crontask/handler_test.go` with tests for:

```text
GET /api/admin/v1/cron-tasks/init returns dict
GET /api/admin/v1/cron-tasks binds query
POST /api/admin/v1/cron-tasks binds JSON
PUT /api/admin/v1/cron-tasks/:id binds ID + JSON
PATCH /api/admin/v1/cron-tasks/:id/status binds status
DELETE /api/admin/v1/cron-tasks/:id passes single id
GET /api/admin/v1/cron-tasks/:id/logs binds task id and query
```

Use a fake HTTP service inside the test and `gin.CreateTestContext`.

- [ ] **Step 2: Implement handler and route**

`handler.go` should follow existing module style:

```go
type HTTPService interface {
	Init(ctx context.Context) (*InitResponse, *apperror.Error)
	List(ctx context.Context, query ListQuery) (*ListResponse, *apperror.Error)
	Create(ctx context.Context, input SaveInput) (*ListItem, *apperror.Error)
	Update(ctx context.Context, id int64, input SaveInput) *apperror.Error
	ChangeStatus(ctx context.Context, id int64, status int) *apperror.Error
	Delete(ctx context.Context, ids []int64) *apperror.Error
	Logs(ctx context.Context, query LogsQuery) (*LogsResponse, *apperror.Error)
}
```

Routes:

```go
func RegisterRoutes(router *gin.Engine, service HTTPService) {
	group := router.Group("/api/admin/v1/cron-tasks")
	group.GET("/init", handler.Init)
	group.GET("", handler.List)
	group.POST("", handler.Create)
	group.PUT("/:id", handler.Update)
	group.PATCH("/:id/status", handler.ChangeStatus)
	group.DELETE("/:id", handler.DeleteOne)
	group.DELETE("", handler.DeleteBatch)
	group.GET("/:id/logs", handler.Logs)
}
```

- [ ] **Step 3: Wire server dependencies**

Modify `internal/server/router.go`:

```go
import "admin_back_go/internal/module/crontask"

type Dependencies struct {
    AuthService             auth.HTTPService
    CaptchaService          captcha.HTTPService
    UserService             user.HTTPService
    PermissionService       permission.HTTPService
    RoleService             role.HTTPService
    AuthPlatformService     authplatform.HTTPService
    OperationLogService     operationlog.HTTPService
    SystemSettingService    systemsetting.HTTPService
    SystemLogService        systemlog.HTTPService
    UploadConfigService     uploadconfig.HTTPService
    UploadTokenService      uploadtoken.HTTPService
    QueueMonitorService     queuemonitor.HTTPService
    NotificationService     notification.HTTPService
    NotificationTaskService notificationtask.HTTPService
    CronTaskService         crontask.HTTPService
}

crontask.RegisterRoutes(router, deps.CronTaskService)
```

Modify `internal/bootstrap/app.go` to construct:

```go
cronTaskService := crontask.NewService(crontask.NewGormRepository(resources.DB), crontask.NewDefaultRegistry())
```

- [ ] **Step 4: Add RBAC and operation metadata**

Modify `internal/bootstrap/route_meta.go`:

```go
middleware.NewRouteKey(http.MethodPost, "/api/admin/v1/cron-tasks"): "devTools_cronTask_add",
middleware.NewRouteKey(http.MethodPut, "/api/admin/v1/cron-tasks/:id"): "devTools_cronTask_edit",
middleware.NewRouteKey(http.MethodPatch, "/api/admin/v1/cron-tasks/:id/status"): "devTools_cronTask_status",
middleware.NewRouteKey(http.MethodDelete, "/api/admin/v1/cron-tasks/:id"): "devTools_cronTask_del",
middleware.NewRouteKey(http.MethodDelete, "/api/admin/v1/cron-tasks"): "devTools_cronTask_del",
middleware.NewRouteKey(http.MethodGet, "/api/admin/v1/cron-tasks/:id/logs"): "devTools_cronTask_logs",
```

Operation log metadata for mutating routes:

```text
cron_task create/update/change_status/delete/delete_batch
```

- [ ] **Step 5: Verify route and metadata tests**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/crontask ./internal/server ./internal/bootstrap
```

Expected: PASS.

## Task 5: Worker wiring

**Files:**
- Modify: `admin_back_go/internal/bootstrap/worker.go`
- Modify: `admin_back_go/internal/bootstrap/worker_test.go`

- [ ] **Step 1: Write/update worker test**

Update `worker_test.go` so worker construction expects scheduler exists and DB-backed cron registration can be called without static schedules. Test should fail before wiring because `crontask.NewSchedulerService` is not used.

- [ ] **Step 2: Wire CronTask scheduler service**

Modify `internal/bootstrap/worker.go`:

```go
cronTaskRepository := crontask.NewGormRepository(resources.DB)
cronTaskRegistry := crontask.NewDefaultRegistry()
cronTaskScheduler := crontask.NewSchedulerService(cronTaskRepository, cronTaskRegistry, queueClient, logger)
if err := cronTaskScheduler.RegisterEnabled(context.Background(), s); err != nil {
    // infra error should fail worker construction
}
```

Remove static `jobs.RegisterSchedules(s, queueClient, logger)` call or leave only empty compatibility call after DB-backed registration if tests require.

- [ ] **Step 3: Verify worker/bootstrap**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/bootstrap ./internal/jobs ./internal/module/crontask
```

Expected: PASS.

## Task 6: Frontend API and page migration

**Files:**
- Modify: `admin_front_ts/src/api/system/cronTask.ts`
- Modify: `admin_front_ts/src/views/Main/system/cronTask/index.vue`
- Create/Modify: `admin_front_ts/tests/shared/system/cron-task-api.test.ts`

- [ ] **Step 1: Write frontend contract test**

Create `tests/shared/system/cron-task-api.test.ts`:

```ts
import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

function readFrontendSource(relativePath: string) {
  return readFileSync(resolve(process.cwd(), relativePath), 'utf-8')
}

const forbiddenLooseTypePattern = new RegExp(`\\b${'an'}${'y'}\\b|as ${'an'}${'y'}|Record<string, ${'an'}${'y'}>`)

describe('cron task API REST contract', () => {
  it('uses Go REST endpoints instead of legacy CronTask all-post routes', () => {
    const source = readFrontendSource('src/api/system/cronTask.ts')

    expect(source).toContain("import request from '@/lib/http'")
    expect(source).toContain("import { ADMIN_API_PREFIX } from '@/lib/http/api-prefix'")
    expect(source).not.toContain('legacyRequest')
    expect(source).not.toContain('/api/admin/CronTask/')
    expect(source).toContain('request.get<CronTaskInitResponse>(`${ADMIN_API_PREFIX}/cron-tasks/init`)')
    expect(source).toContain('request.get<PaginatedResponse<CronTaskItem>>(`${ADMIN_API_PREFIX}/cron-tasks`')
    expect(source).toContain('request.post<CronTaskItem, CronTaskForm>(`${ADMIN_API_PREFIX}/cron-tasks`, params)')
    expect(source).toContain('request.put<void, CronTaskForm>(`${ADMIN_API_PREFIX}/cron-tasks/${params.id}`, params)')
    expect(source).toContain('request.patch<void, CronTaskStatusBody>(`${ADMIN_API_PREFIX}/cron-tasks/${params.id}/status`')
    expect(source).toContain('request.get<PaginatedResponse<CronTaskLogItem>>(`${ADMIN_API_PREFIX}/cron-tasks/${params.task_id}/logs`')
  })

  it('does not introduce loose TS types in touched files', () => {
    for (const file of ['src/api/system/cronTask.ts', 'src/views/Main/system/cronTask/index.vue']) {
      expect(readFrontendSource(file)).not.toMatch(forbiddenLooseTypePattern)
    }
  })
})
```

- [ ] **Step 2: Run failing frontend test**

```powershell
cd E:\admin_go\admin_front_ts
npx vitest run tests/shared/system/cron-task-api.test.ts
```

Expected: FAIL because API still imports `legacyRequest`.

- [ ] **Step 3: Update API client**

Modify `src/api/system/cronTask.ts`:

```ts
import request from '@/lib/http'
import { ADMIN_API_PREFIX } from '@/lib/http/api-prefix'
import type { DictOption, PaginatedResponse } from '@/types/common'
```

Add fields:

```ts
export type CronTaskRegistryStatus = 'registered' | 'missing' | 'disabled' | 'invalid_cron'

export interface CronTaskItem {
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
  registry_status: CronTaskRegistryStatus
  registry_status_text: string
  registry_task_type: string
  registry_description: string
  created_at: string
  updated_at: string
}

export interface CronTaskStatusBody { status: number }
```

Replace methods:

```ts
export const CronTaskApi = {
  init: () => request.get<CronTaskInitResponse>(`${ADMIN_API_PREFIX}/cron-tasks/init`),
  list: (params?: CronTaskListParams) => request.get<PaginatedResponse<CronTaskItem>>(`${ADMIN_API_PREFIX}/cron-tasks`, { params }),
  add: (params: CronTaskForm) => request.post<CronTaskItem, CronTaskForm>(`${ADMIN_API_PREFIX}/cron-tasks`, params),
  edit: (params: CronTaskForm & { id: number }) => request.put<void, CronTaskForm>(`${ADMIN_API_PREFIX}/cron-tasks/${params.id}`, params),
  del: (params: { id: number | number[] }) => Array.isArray(params.id)
    ? request.delete<void, { ids: number[] }>(`${ADMIN_API_PREFIX}/cron-tasks`, { data: { ids: params.id } })
    : request.delete<void>(`${ADMIN_API_PREFIX}/cron-tasks/${params.id}`),
  status: (params: { id: number; status: number }) => request.patch<void, CronTaskStatusBody>(`${ADMIN_API_PREFIX}/cron-tasks/${params.id}/status`, { status: params.status }),
  logs: (params: CronTaskLogListParams) => request.get<PaginatedResponse<CronTaskLogItem>>(`${ADMIN_API_PREFIX}/cron-tasks/${params.task_id}/logs`, { params }),
}
```

- [ ] **Step 4: Update page registry status column**

Modify `src/views/Main/system/cronTask/index.vue`:

```ts
const REGISTRY_STATUS_TYPE: Record<CronTaskRegistryStatus, 'success' | 'warning' | 'danger' | 'info'> = {
  registered: 'success',
  missing: 'warning',
  disabled: 'info',
  invalid_cron: 'danger',
}
```

Add a column:

```ts
{ key: 'registry_status', label: '接入状态', width: 110 },
```

Add slot:

```vue
<template #cell-registry_status="{ row }">
  <el-tag :type="REGISTRY_STATUS_TYPE[row.registry_status as CronTaskRegistryStatus] || 'info'" size="small">
    {{ row.registry_status_text }}
  </el-tag>
</template>
```

If TypeScript complains about row typing from AppTable slot, define a typed helper function instead of `as any`.

- [ ] **Step 5: Verify frontend**

```powershell
cd E:\admin_go\admin_front_ts
npx vitest run tests/shared/system/cron-task-api.test.ts
npx eslint src/api/system/cronTask.ts src/views/Main/system/cronTask/index.vue tests/shared/system/cron-task-api.test.ts
npx vue-tsc -b --pretty false
```

Expected: PASS; eslint may report existing style warnings only if already present, but no errors.

## Task 7: Full smoke and docs

**Files:**
- Modify: `admin_back_go/scripts/full-admin-smoke.ps1`
- Modify: `docs/contracts/admin-api-v1.md`
- Modify: `docs/migration/current-status.md`
- Modify: `docs/testing/smoke-matrix.md`
- Modify: `admin_back_go/docs/architecture.md`

- [ ] **Step 1: Extend full smoke**

In `full-admin-smoke.ps1`, add helper assertions:

```powershell
function Assert-CronTaskInit($Response) {
  Assert-ApiOK $Response 'cron task init'
  if ($null -eq $Response.data.dict.cron_preset_arr -or $null -eq $Response.data.dict.cron_task_registry_status_arr) {
    throw "cron task init dict missing: $($Response | ConvertTo-Json -Depth 12)"
  }
}

function Assert-CronTaskList($Response) {
  Assert-ApiOK $Response 'cron task list'
  if ($null -eq $Response.data.page -or $null -eq $Response.data.list) {
    throw "cron task list missing page/list: $($Response | ConvertTo-Json -Depth 12)"
  }
  $registeredNotification = $false
  $missingLegacy = $false
  foreach ($item in (Get-ObjectArray $Response.data.list)) {
    if ([string]$item.name -eq 'notification_task_scheduler' -and [string]$item.registry_status -eq 'registered') {
      $registeredNotification = $true
    }
    if ([string]$item.registry_status -eq 'missing') {
      $missingLegacy = $true
    }
  }
  return [pscustomobject]@{
    ListCount = (Get-ObjectArray $Response.data.list).Count
    Total = [int64]$Response.data.page.total
    NotificationRegistered = $registeredNotification
    MissingLegacyPresent = $missingLegacy
  }
}
```

Call:

```powershell
$cronTaskInit = Invoke-RestMethod "$baseURL/api/admin/v1/cron-tasks/init" -Headers $authHeaders -TimeoutSec 10
$cronTaskInitSummary = Assert-CronTaskInit $cronTaskInit
$cronTaskList = Invoke-RestMethod "$baseURL/api/admin/v1/cron-tasks?current_page=1&page_size=20" -Headers $authHeaders -TimeoutSec 10
$cronTaskListSummary = Assert-CronTaskList $cronTaskList
```

If rows exist, call logs for first row.

- [ ] **Step 2: Update contract docs**

Add `## System Cron Tasks` to `docs/contracts/admin-api-v1.md` documenting all routes, auth, request/response, registry rules, and worker reload limitation.

- [ ] **Step 3: Update status and smoke matrix**

Add/update `docs/migration/current-status.md` row:

```text
system cron tasks | implemented: REST cron_task CRUD/logs + DB-backed worker scheduler registration + registry_status; `notification_task_scheduler` maps to `notification:dispatch-due:v1` | adapted: cron task page uses Go REST, no legacyRequest | `internal/module/crontask`, `internal/jobs`, `internal/bootstrap`, `internal/server`; frontend `tests/shared/system/cron-task-api.test.ts` | full smoke probes init/list/logs and registry status | admin API contract + backend architecture + smoke matrix | only notification_task_scheduler registered; pay/AI/chat cron handlers planned
```

Add smoke matrix row for cron tasks.

- [ ] **Step 4: Update backend architecture**

Update `admin_back_go/docs/architecture.md` queue/scheduler section:

```text
cron_task DB controls enabled schedules.
Go crontask registry controls executable schedules.
admin-worker registers DB-backed schedules on startup.
cron callback only writes cron_task_log and enqueues queue task.
notification_task_scheduler is first registered Go cron task.
```

- [ ] **Step 5: Verify docs**

```powershell
cd E:\admin_go
rg -n "CronTask|/api/admin/CronTask|legacyRequest" admin_front_ts/src/api/system/cronTask.ts docs/contracts/admin-api-v1.md docs/migration/current-status.md docs/testing/smoke-matrix.md admin_back_go/docs/architecture.md
git diff --check
git -C admin_back_go diff --check
git -C admin_front_ts diff --check
```

Expected: no legacy `/api/admin/CronTask` in new contract/status docs or cronTask API.

## Task 8: Final verification and commits

**Files:** all touched files.

- [ ] **Step 1: Backend targeted tests**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/crontask ./internal/jobs ./internal/bootstrap ./internal/platform/scheduler ./internal/server
```

Expected: PASS.

- [ ] **Step 2: Backend full tests and vet**

```powershell
cd E:\admin_go\admin_back_go
go test -p 1 ./...
go vet -p 1 ./...
```

Expected: PASS.

- [ ] **Step 3: Frontend checks**

```powershell
cd E:\admin_go\admin_front_ts
npx vitest run tests/shared/system/cron-task-api.test.ts
npx eslint src/api/system/cronTask.ts src/views/Main/system/cronTask/index.vue tests/shared/system/cron-task-api.test.ts
npx vue-tsc -b --pretty false
```

Expected: PASS or known non-blocking warnings only; no errors.

- [ ] **Step 4: Full smoke**

```powershell
cd E:\admin_go\admin_back_go
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account 15671628271 -Password 123456
```

Expected summary contains:

```json
{
  "cron_task_init_code": 0,
  "cron_task_list_code": 0,
  "cron_task_notification_registered": true
}
```

- [ ] **Step 5: Commit per repo**

Backend:

```powershell
cd E:\admin_go\admin_back_go
git add internal/module/crontask internal/server internal/bootstrap internal/jobs internal/platform/scheduler scripts/full-admin-smoke.ps1 docs/architecture.md
git commit -m "feat: migrate cron tasks to Go scheduler"
```

Frontend:

```powershell
cd E:\admin_go\admin_front_ts
git add src/api/system/cronTask.ts src/views/Main/system/cronTask/index.vue tests/shared/system/cron-task-api.test.ts
git commit -m "fix: route cron task page to Go API"
```

Root docs:

```powershell
cd E:\admin_go
git add docs/contracts/admin-api-v1.md docs/migration/current-status.md docs/testing/smoke-matrix.md docs/superpowers/specs/2026-05-06-system-cron-task-go-design.md docs/superpowers/plans/2026-05-06-system-cron-task-go-implementation.md
git commit -m "docs: define Go cron task migration"
```

- [ ] **Step 6: Handoff**

Report:

```text
Outcome:
Changed files:
Backend verification:
Frontend verification:
Smoke summary:
Known remaining system-management modules:
Next recommended module:
```
