# 导出运行时 V2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把导出做成可复用基础能力：业务模块只注册 provider 和提交入口，统一复用 `export_tasks`、队列、xlsx writer、COS uploader、通知和导出任务页。

**Architecture:** 保留 `internal/module/export` 作为导出运行时，新增 registry、显式 `scope`、`kind/platform/object_key`、COS object key 返回和 gated real export smoke。当前用户管理页继续兼容 `{ ids: number[] }`，但内部归一化为 `scope=selected` 的 `user_list` 导出。

**Tech Stack:** Go 1.x、Gin、GORM、Asynq taskqueue、Tencent COS object writer、excelize、Vue 3、TypeScript、Vitest、PowerShell smoke。

---

## 执行前约束

当前 workspace 可能有大量无关脏改。执行本计划时必须先看状态：

```powershell
cd E:\admin_go
git status --short
git -C admin_back_go status --short
git -C admin_front_ts status --short
```

只 stage 当前 task 的文件。不要把 payment、wallet、canvas 或 AI billing 的既有脏改混进导出提交。

推荐执行方式：每个 task 一个小提交。实现阶段若使用独立 worktree，先用 `superpowers:using-git-worktrees` 建隔离工作区。

## 文件结构

### Root docs

- Modify: `docs/contracts/admin-api-v1.md`：更新导出 submit、export task 字段、COS object key、真实导出 smoke 契约。
- Modify: `docs/status/current-status.md`：只在代码和验证完成后写 verified 状态。
- Modify: `docs/status/module-matrix.md`：更新 user/export lifecycle 明细。
- Modify: `docs/testing/smoke-matrix.md`：保留默认 read-only smoke，新增 credential-gated real export smoke。
- Plan source: `docs/superpowers/specs/2026-05-30-export-runtime-v2-design.md`。

### Backend runtime

- Create: `admin_back_go/database/migrations/20260530_export_runtime_v2.sql`：给 `export_tasks` 增加 `kind/platform/object_key`。
- Create: `admin_back_go/internal/module/export/definition.go`：导出定义、scope、registry、provider 边界。
- Modify: `admin_back_go/internal/module/export/model.go`：增加 `Kind`、`Platform`、`ObjectKey`。
- Modify: `admin_back_go/internal/module/export/dto.go`：增加 list/status query 的 `Kind/Platform`、任务返回的 `kind/kind_text`、创建/成功结果字段。
- Modify: `admin_back_go/internal/module/export/jobs.go`：V2 payload 增加 `scope/params`，保留旧 `user_list` 兼容。
- Modify: `admin_back_go/internal/module/export/service.go`：改成 registry 驱动，运行时传 `BuildInput`，成功时落 `object_key`。
- Modify: `admin_back_go/internal/module/export/repository.go`：按 `user_id + platform + kind + is_del` 查询，`MarkSuccess` 写 `object_key`。
- Modify: `admin_back_go/internal/module/export/uploader.go`：上传 key 改成 `exports/<kind>/YYYYMMDD/...`，返回 `ObjectKey`。
- Modify: `admin_back_go/internal/module/export/transport/admin/request.go`：list/status query 增加 `kind`。
- Modify: `admin_back_go/internal/module/export/transport/admin/handler.go`：从 token identity 传 `Platform`，绑定 `Kind`。
- Modify: `admin_back_go/internal/module/user/export_provider.go`：实现新的 `export.Provider` signature。
- Modify: `admin_back_go/internal/module/user/service.go`：创建 pending task 时写 `kind/platform`，队列 payload 写 `scope=selected`。
- Modify: `admin_back_go/internal/bootstrap/worker.go`：用 registry 注册 `user_list` provider。
- Create: `admin_back_go/scripts/export-task-smoke.ps1`：只在 `-RunRealExport` 时提交真实导出并轮询任务。

### Frontend runtime

- Create: `admin_front_ts/src/hooks/useExportSubmit.ts`：复用 selected ids 校验、submit 调用、i18n success 提示。
- Modify: `admin_front_ts/src/views/Main/user/userManager/components/UserList/index.vue`：保持按钮和权限，使用 helper 提交。
- Modify: `admin_front_ts/src/api/system/exportTask.ts`：增加 `kind/kind_text` 类型和可选 `kind` query。
- Modify: `admin_front_ts/src/api/user/users.ts`：第一阶段继续保留 `{ ids: number[] }` 外部调用。
- Modify: `admin_front_ts/src/i18n/locales/zh-CN.ts`：新增 helper 所需可见文案。
- Modify: `admin_front_ts/src/i18n/locales/en-US.ts`：新增英文文案。

---

## Task 1: 后端 schema、model、DTO 和 repository 基础字段

**Files:**
- Create: `admin_back_go/database/migrations/20260530_export_runtime_v2.sql`
- Modify: `admin_back_go/internal/module/export/model.go`
- Modify: `admin_back_go/internal/module/export/dto.go`
- Modify: `admin_back_go/internal/module/export/repository.go`
- Modify: `admin_back_go/internal/module/export/service.go`
- Modify: `admin_back_go/internal/module/export/service_test.go`

- [ ] **Step 1: 写失败测试，证明 pending task 必须记录 kind/platform**

Append this test to `admin_back_go/internal/module/export/service_test.go` before `ptrInt`:

```go
func TestCreatePendingStoresKindPlatformAndDefaults(t *testing.T) {
	now := time.Date(2026, 5, 30, 9, 0, 0, 0, time.UTC)
	repo := &fakeRepository{createdID: 88}

	got, err := NewService(repo, WithNow(func() time.Time { return now })).CreatePending(context.Background(), CreatePendingInput{
		UserID:   9,
		Title:    "用户列表导出",
		Kind:     " user_list ",
		Platform: " admin ",
	})
	if err != nil {
		t.Fatalf("CreatePending returned error: %v", err)
	}
	if got != 88 {
		t.Fatalf("expected id 88, got %d", got)
	}
	if repo.created.Kind != KindUserList || repo.created.Platform != enum.PlatformAdmin {
		t.Fatalf("expected kind/platform to be stored, got kind=%q platform=%q", repo.created.Kind, repo.created.Platform)
	}

	repo = &fakeRepository{createdID: 89}
	_, err = NewService(repo, WithNow(func() time.Time { return now })).CreatePending(context.Background(), CreatePendingInput{UserID: 9, Title: "用户列表导出"})
	if err != nil {
		t.Fatalf("CreatePending with defaults returned error: %v", err)
	}
	if repo.created.Kind != KindUserList || repo.created.Platform != enum.PlatformAdmin {
		t.Fatalf("expected default kind/platform, got kind=%q platform=%q", repo.created.Kind, repo.created.Platform)
	}
}
```

- [ ] **Step 2: 写失败测试，证明 list 返回 kind/kind_text 并按 platform/kind 传查询条件**

Replace `TestListScopesUserAndFormatsFileSize` in `admin_back_go/internal/module/export/service_test.go`:

```go
func TestListScopesUserPlatformKindAndFormatsFileSize(t *testing.T) {
	createdAt := time.Date(2026, 5, 7, 12, 30, 0, 0, time.UTC)
	expireAt := createdAt.Add(7 * 24 * time.Hour)
	fileSize := int64(2048)
	rowCount := int64(3)
	repo := &fakeRepository{rows: []Task{{
		ID: 7, UserID: 9, Platform: enum.PlatformAdmin, Kind: KindUserList, Title: "用户列表导出", FileName: "u.xlsx", FileURL: "https://cos/u.xlsx",
		FileSize: &fileSize, RowCount: &rowCount, Status: enum.ExportTaskStatusSuccess, ExpireAt: &expireAt, CreatedAt: createdAt,
	}}, total: 1}
	got, appErr := NewService(repo).List(context.Background(), ListQuery{
		UserID: 9, Platform: enum.PlatformAdmin, Kind: KindUserList, CurrentPage: 1, PageSize: 20, Status: ptrInt(enum.ExportTaskStatusSuccess), FileName: " u ",
	})
	if appErr != nil {
		t.Fatalf("List returned error: %v", appErr)
	}
	if repo.gotList.UserID != 9 || repo.gotList.Platform != enum.PlatformAdmin || repo.gotList.Kind != KindUserList || repo.gotList.FileName != "u" {
		t.Fatalf("expected scoped trimmed list query, got %#v", repo.gotList)
	}
	if got.Page.Total != 1 || got.Page.TotalPage != 1 || len(got.List) != 1 {
		t.Fatalf("unexpected page/list: %#v", got)
	}
	item := got.List[0]
	if item.Kind != KindUserList || item.KindText != "用户列表" || item.FileSizeText != "2 KB" || item.StatusText != "已完成" || item.ExpireAt == nil || *item.ExpireAt != "2026-05-14 12:30:00" {
		t.Fatalf("unexpected list item: %#v", item)
	}
}
```

- [ ] **Step 3: 运行测试，确认现在失败**

```powershell
cd E:\admin_go\admin_back_go
go test -p 1 ./internal/module/export -run "TestCreatePendingStoresKindPlatformAndDefaults|TestListScopesUserPlatformKindAndFormatsFileSize" -count=1
```

Expected: fail with compile errors such as `unknown field Kind` or `ListItem has no field Kind`.

- [ ] **Step 4: 创建 SQL migration**

Create `admin_back_go/database/migrations/20260530_export_runtime_v2.sql`:

```sql
ALTER TABLE `export_tasks`
  ADD COLUMN `kind` varchar(64) NOT NULL DEFAULT 'user_list' COMMENT '导出类型' AFTER `title`,
  ADD COLUMN `platform` varchar(32) NOT NULL DEFAULT 'admin' COMMENT '平台入口' AFTER `user_id`,
  ADD COLUMN `object_key` varchar(500) NULL COMMENT 'COS object key' AFTER `file_url`;

UPDATE `export_tasks`
SET `kind` = 'user_list'
WHERE `kind` = '' OR `kind` IS NULL;

UPDATE `export_tasks`
SET `platform` = 'admin'
WHERE `platform` = '' OR `platform` IS NULL;

CREATE INDEX `idx_export_tasks_user_platform_status` ON `export_tasks` (`user_id`, `platform`, `status`, `is_del`);
CREATE INDEX `idx_export_tasks_user_platform_kind` ON `export_tasks` (`user_id`, `platform`, `kind`, `is_del`);
```

- [ ] **Step 5: 更新 model/dto 类型**

Modify `admin_back_go/internal/module/export/model.go` so `Task` includes:

```go
Platform  string     `gorm:"column:platform"`
Kind      string     `gorm:"column:kind"`
ObjectKey string     `gorm:"column:object_key"`
```

Modify `admin_back_go/internal/module/export/dto.go` with these struct changes:

```go
type StatusCountQuery struct {
	UserID   int64
	Platform string
	Kind     string
	Title    string
	FileName string
}

type ListQuery struct {
	UserID      int64
	Platform    string
	Kind        string
	CurrentPage int
	PageSize    int
	Status      *int
	Title       string
	FileName    string
}

type ListItem struct {
	ID           int64   `json:"id"`
	Kind         string  `json:"kind"`
	KindText     string  `json:"kind_text"`
	Title        string  `json:"title"`
	FileName     *string `json:"file_name"`
	FileURL      *string `json:"file_url"`
	FileSizeText string  `json:"file_size_text"`
	RowCount     *int64  `json:"row_count"`
	Status       int     `json:"status"`
	StatusText   string  `json:"status_text"`
	ErrorMsg     *string `json:"error_msg"`
	ExpireAt     *string `json:"expire_at"`
	CreatedAt    string  `json:"created_at"`
}

type CreatePendingInput struct {
	UserID   int64
	Platform string
	Kind     string
	Title    string
}

type SuccessResult struct {
	FileName  string
	FileURL   string
	ObjectKey string
	FileSize  int64
	RowCount  int64
}

type DeleteInput struct {
	UserID   int64
	Platform string
	IDs      []int64
}
```

- [ ] **Step 6: 更新 service 归一化**

In `admin_back_go/internal/module/export/service.go`, add helpers:

```go
func normalizeKind(value string) string {
	value = strings.TrimSpace(value)
	if value == "" {
		return KindUserList
	}
	return value
}

func normalizePlatform(value string) string {
	value = strings.TrimSpace(value)
	if value == "" {
		return enum.PlatformAdmin
	}
	return value
}

func kindText(kind string) string {
	switch normalizeKind(kind) {
	case KindUserList:
		return "用户列表"
	default:
		return normalizeKind(kind)
	}
}
```

Replace the start of `CreatePending` with:

```go
input.Title = strings.TrimSpace(input.Title)
input.Kind = normalizeKind(input.Kind)
input.Platform = normalizePlatform(input.Platform)
if input.UserID <= 0 || input.Title == "" {
	return 0, apperror.BadRequestKey("exporttask.create_pending.invalid", nil, "导出任务参数错误")
}
```

Inside the `Task{}` literal in `CreatePending`, add:

```go
Platform:  input.Platform,
Kind:      input.Kind,
```

Replace `normalizeStatusCountQuery` with:

```go
func normalizeStatusCountQuery(query StatusCountQuery) StatusCountQuery {
	query.Platform = normalizePlatform(query.Platform)
	query.Kind = strings.TrimSpace(query.Kind)
	query.Title = strings.TrimSpace(query.Title)
	query.FileName = strings.TrimSpace(query.FileName)
	return query
}
```

Inside `normalizeListQuery`, after the user id check, add:

```go
query.Platform = normalizePlatform(query.Platform)
query.Kind = strings.TrimSpace(query.Kind)
```

Inside `listItemFromTask`, add these fields:

```go
Kind:         normalizeKind(row.Kind),
KindText:     kindText(row.Kind),
```

- [ ] **Step 7: 更新 repository 查询和成功落库**

Modify `Repository` interface:

```go
DeleteByUser(ctx context.Context, userID int64, platform string, ids []int64) error
```

Modify `MarkSuccess` updates to include:

```go
"object_key": result.ObjectKey,
```

Modify `scopedQuery` to filter:

```go
Where("user_id = ?", userID).
Where("platform = ?", normalizePlatform(platform)).
Where("is_del = ?", enum.CommonNo)
```

If `kind` is non-empty, add:

```go
db = db.Where("kind = ?", kind)
```

- [ ] **Step 8: Update fakeRepository signatures**

In `admin_back_go/internal/module/export/service_test.go`, add:

```go
deletedPlatform string
```

Replace fake delete method:

```go
func (f *fakeRepository) DeleteByUser(ctx context.Context, userID int64, platform string, ids []int64) error {
	f.deletedUserID = userID
	f.deletedPlatform = platform
	f.deletedIDs = append([]int64{}, ids...)
	return f.err
}
```

- [ ] **Step 9: Run backend export package tests**

```powershell
cd E:\admin_go\admin_back_go
go test -p 1 ./internal/module/export -count=1
```

Expected: package compiles and tests pass, except registry compile errors that Task 2 will resolve.

- [ ] **Step 10: Commit Task 1**

```powershell
cd E:\admin_go
git add admin_back_go/database/migrations/20260530_export_runtime_v2.sql `
  admin_back_go/internal/module/export/model.go `
  admin_back_go/internal/module/export/dto.go `
  admin_back_go/internal/module/export/repository.go `
  admin_back_go/internal/module/export/service.go `
  admin_back_go/internal/module/export/service_test.go
git commit -m "feat: extend export task schema"
```

---

## Task 2: export registry 和 V2 queue payload

**Files:**
- Create: `admin_back_go/internal/module/export/definition.go`
- Create: `admin_back_go/internal/module/export/definition_test.go`
- Modify: `admin_back_go/internal/module/export/jobs.go`
- Modify: `admin_back_go/internal/module/export/jobs_test.go`
- Modify: `admin_back_go/internal/module/export/run_test.go`
- Modify: `admin_back_go/internal/bootstrap/worker.go`

- [ ] **Step 1: 写 registry 单测**

Create `admin_back_go/internal/module/export/definition_test.go`:

```go
package exporttask

import (
	"context"
	"strings"
	"testing"
)

type registryProvider struct{}

func (registryProvider) BuildExportData(ctx context.Context, input BuildInput) (*FileData, error) {
	return &FileData{Prefix: input.Kind, Headers: []Column{{Key: "id", Title: "ID"}}, Rows: []map[string]string{{"id": "1"}}}, nil
}

func TestRegistryResolvesKnownKindAndRejectsUnknown(t *testing.T) {
	registry, err := NewRegistry(Definition{Kind: KindUserList, Title: "用户列表", Provider: registryProvider{}})
	if err != nil {
		t.Fatalf("NewRegistry returned error: %v", err)
	}
	def, ok := registry.Resolve(" user_list ")
	if !ok || def.Kind != KindUserList || def.Title != "用户列表" {
		t.Fatalf("unexpected definition: ok=%v def=%#v", ok, def)
	}
	if _, ok := registry.Resolve("payment_orders"); ok {
		t.Fatalf("expected unknown kind to be rejected")
	}
}

func TestRegistryRejectsDuplicateOrEmptyDefinition(t *testing.T) {
	_, err := NewRegistry(Definition{})
	if err == nil || !strings.Contains(err.Error(), "kind") {
		t.Fatalf("expected empty kind error, got %v", err)
	}
	_, err = NewRegistry(
		Definition{Kind: KindUserList, Title: "用户列表", Provider: registryProvider{}},
		Definition{Kind: " user_list ", Title: "用户列表2", Provider: registryProvider{}},
	)
	if err == nil || !strings.Contains(err.Error(), "duplicate") {
		t.Fatalf("expected duplicate kind error, got %v", err)
	}
}
```

- [ ] **Step 2: 运行 registry 测试确认失败**

```powershell
cd E:\admin_go\admin_back_go
go test -p 1 ./internal/module/export -run "TestRegistry" -count=1
```

Expected: fail because `Definition`, `BuildInput`, `NewRegistry` do not exist.

- [ ] **Step 3: 创建 definition.go**

Create `admin_back_go/internal/module/export/definition.go`:

```go
package exporttask

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
)

const (
	ScopeSelected = "selected"
	ScopeFiltered = "filtered"
)

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
	Scope    string
	IDs      []int64
	Params   json.RawMessage
}

type Registry struct {
	definitions map[string]Definition
}

func NewRegistry(definitions ...Definition) (*Registry, error) {
	registry := &Registry{definitions: make(map[string]Definition, len(definitions))}
	for _, definition := range definitions {
		definition.Kind = normalizeKind(definition.Kind)
		definition.Title = strings.TrimSpace(definition.Title)
		if definition.Kind == "" {
			return nil, fmt.Errorf("export registry kind is required")
		}
		if definition.Provider == nil {
			return nil, fmt.Errorf("export registry provider is required for %s", definition.Kind)
		}
		if _, exists := registry.definitions[definition.Kind]; exists {
			return nil, fmt.Errorf("export registry duplicate kind: %s", definition.Kind)
		}
		if definition.Title == "" {
			definition.Title = kindText(definition.Kind)
		}
		registry.definitions[definition.Kind] = definition
	}
	return registry, nil
}

func (r *Registry) Resolve(kind string) (Definition, bool) {
	if r == nil {
		return Definition{}, false
	}
	definition, ok := r.definitions[normalizeKind(kind)]
	return definition, ok
}
```

- [ ] **Step 4: 写 V2 payload 失败测试**

In `admin_back_go/internal/module/export/jobs_test.go`, update the payload test to assert `ScopeSelected`, normalized ids, and lean JSON. Add imports:

```go
"reflect"
"strings"
```

Add compatibility test:

```go
func TestDecodeRunPayloadDefaultsOldUserListScopeToSelected(t *testing.T) {
	payload, err := DecodeRunPayload([]byte(`{"task_id":7,"kind":"user_list","user_id":9,"platform":"admin","ids":[3]}`))
	if err != nil {
		t.Fatalf("DecodeRunPayload returned error: %v", err)
	}
	if payload.Scope != ScopeSelected {
		t.Fatalf("expected old user_list payload to default selected scope, got %#v", payload)
	}
}
```

- [ ] **Step 5: Run payload 测试确认失败**

```powershell
cd E:\admin_go\admin_back_go
go test -p 1 ./internal/module/export -run "TestNewRunTaskUsesVersionedTypeLowQueueAndLeanPayload|TestDecodeRunPayloadDefaultsOldUserListScopeToSelected" -count=1
```

Expected: fail because `RunPayload.Scope` is missing.

- [ ] **Step 6: 更新 jobs.go payload**

Modify `RunPayload`:

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

Replace `normalizeRunPayload` and `validateRunInput` so old `user_list` without scope becomes `selected`, new jobs require valid `scope`, and `selected` requires ids.

- [ ] **Step 7: Update service constructor to use registry**

In `admin_back_go/internal/module/export/service.go`, replace field `provider ExportDataProvider` with:

```go
registry *Registry
```

Add option:

```go
func WithDefinitionRegistry(registry *Registry) Option {
	return func(s *Service) {
		s.registry = registry
	}
}
```

- [ ] **Step 8: Update run tests fake provider signature**

In `admin_back_go/internal/module/export/run_test.go`, replace `fakeDataProvider` with:

```go
type fakeDataProvider struct {
	input BuildInput
	data  *FileData
	err   error
}

func (f *fakeDataProvider) BuildExportData(ctx context.Context, input BuildInput) (*FileData, error) {
	f.input = input
	return f.data, f.err
}
```

Add helper:

```go
func testRegistry(t *testing.T, provider Provider) *Registry {
	t.Helper()
	registry, err := NewRegistry(Definition{Kind: KindUserList, Title: "用户列表", Provider: provider})
	if err != nil {
		t.Fatalf("NewRegistry returned error: %v", err)
	}
	return registry
}
```

- [ ] **Step 9: Update worker registry wiring**

In `admin_back_go/internal/bootstrap/worker.go`, create registry before `exporttask.NewService`:

```go
userExportProvider := user.NewExportDataProvider(user.NewGormRepository(resources.DB))
exportRegistry, err := exporttask.NewRegistry(exporttask.Definition{
	Kind:     exporttask.KindUserList,
	Title:    "用户列表",
	Provider: userExportProvider,
})
if err != nil {
	_ = queueClient.Close()
	_ = resources.Close()
	return nil, err
}
```

Pass:

```go
exporttask.WithDefinitionRegistry(exportRegistry),
```

- [ ] **Step 10: Run task tests**

```powershell
cd E:\admin_go\admin_back_go
go test -p 1 ./internal/module/export ./internal/bootstrap -run "TestRegistry|TestNewRunTask|TestDecodeRunPayload|TestRun" -count=1
```

Expected: pass for export tests; bootstrap compile errors must be fixed before commit.

- [ ] **Step 11: Commit Task 2**

```powershell
cd E:\admin_go
git add admin_back_go/internal/module/export/definition.go `
  admin_back_go/internal/module/export/definition_test.go `
  admin_back_go/internal/module/export/jobs.go `
  admin_back_go/internal/module/export/jobs_test.go `
  admin_back_go/internal/module/export/service.go `
  admin_back_go/internal/module/export/run_test.go `
  admin_back_go/internal/bootstrap/worker.go
git commit -m "feat: add export definition registry"
```

---

## Task 3: Runtime Run 编排和 COS object_key

**Files:**
- Modify: `admin_back_go/internal/module/export/service.go`
- Modify: `admin_back_go/internal/module/export/uploader.go`
- Modify: `admin_back_go/internal/module/export/uploader_test.go`
- Modify: `admin_back_go/internal/module/export/run_test.go`
- Modify: `admin_back_go/internal/module/export/repository.go`

- [ ] **Step 1: 写 uploader 失败测试，要求新 key 带 kind 并返回 object_key**

Replace old upload folder test with:

```go
func TestCOSUploaderUploadsXLSXToKindFolderAndReturnsObjectKey(t *testing.T) {
	writer := &fakeCOSWriter{}
	now := time.Date(2026, 5, 7, 12, 13, 14, 0, time.UTC)
	uploader := NewCOSUploader(fakeUploadConfigRepository{config: &UploadConfig{
		Driver: enum.UploadDriverCOS, SecretIDEnc: "sid", SecretKeyEnc: "skey", Bucket: "bucket", Region: "ap-guangzhou", BucketDomain: "https://cdn.example.com",
	}}, plainSecretbox{}, writer, WithUploadNow(func() time.Time { return now }))

	got, err := uploader.Upload(context.Background(), UploadInput{TaskID: 88, Kind: KindUserList, Prefix: "用户列表导出", Body: []byte("xlsx"), RowCount: 3})
	if err != nil {
		t.Fatalf("Upload returned error: %v", err)
	}
	wantKey := "exports/user_list/20260507/用户列表导出_20260507_121314_88.xlsx"
	if got.FileName != "用户列表导出_20260507_121314_88.xlsx" || got.ObjectKey != wantKey || got.FileURL != "https://cdn.example.com/"+wantKey || got.FileSize != 4 || got.RowCount != 3 {
		t.Fatalf("unexpected upload result: %#v", got)
	}
	if writer.input.Key != wantKey {
		t.Fatalf("expected object key %q, got %q", wantKey, writer.input.Key)
	}
}
```

- [ ] **Step 2: Run tests to verify failure**

```powershell
cd E:\admin_go\admin_back_go
go test -p 1 ./internal/module/export -run "TestCOSUploaderUploadsXLSXToKindFolderAndReturnsObjectKey|TestRunGeneratesUploadsMarksSuccessAndNotifies" -count=1
```

Expected: fail because `UploadInput.Kind`, `UploadResult.ObjectKey`, and `SuccessResult.ObjectKey` are not fully wired.

- [ ] **Step 3: Update uploader input/output**

In `admin_back_go/internal/module/export/uploader.go`, update structs:

```go
type UploadInput struct {
	TaskID   int64
	Kind     string
	Prefix   string
	Body     []byte
	RowCount int64
}

type UploadResult struct {
	FileName  string
	FileURL   string
	ObjectKey string
	FileSize  int64
	RowCount  int64
}
```

Generate key:

```go
kind := normalizeKind(input.Kind)
fileName := fmt.Sprintf("%s_%s_%d.xlsx", prefix, now.Format("20060102_150405"), input.TaskID)
key := path.Join("exports", safePathSegment(kind), now.Format("20060102"), safePathSegment(fileName))
```

Add:

```go
func safePathSegment(value string) string {
	value = strings.TrimSpace(value)
	if value == "" {
		return "export"
	}
	replacer := strings.NewReplacer("/", "_", "\\", "_", "..", "_", ":", "_", "*", "_", "?", "_", "\"", "_", "<", "_", ">", "_", "|", "_")
	return replacer.Replace(value)
}
```

- [ ] **Step 4: Update Service.Run to pass BuildInput and UploadInput.Kind**

Use registry resolution in `Service.Run`:

```go
definition, ok := s.registry.Resolve(input.Kind)
if !ok {
	return s.failRun(ctx, *task, input, fmt.Errorf("unsupported export kind: %s", input.Kind))
}
data, err := definition.Provider.BuildExportData(ctx, BuildInput{
	TaskID:   input.TaskID,
	UserID:   input.UserID,
	Platform: input.Platform,
	Kind:     input.Kind,
	Scope:    input.Scope,
	IDs:      input.IDs,
	Params:   input.Params,
})
```

Replace the uploader call in `Service.Run`:

```go
result, err := s.uploader.Upload(ctx, UploadInput{TaskID: input.TaskID, Kind: input.Kind, Prefix: data.Prefix, Body: body, RowCount: int64(len(data.Rows))})
```

Add `ObjectKey` to the success result:

```go
ObjectKey: result.ObjectKey,
```

- [ ] **Step 5: Run export runtime tests**

```powershell
cd E:\admin_go\admin_back_go
go test -p 1 ./internal/module/export -count=1
```

Expected: pass.

- [ ] **Step 6: Commit Task 3**

```powershell
cd E:\admin_go
git add admin_back_go/internal/module/export/service.go `
  admin_back_go/internal/module/export/uploader.go `
  admin_back_go/internal/module/export/uploader_test.go `
  admin_back_go/internal/module/export/run_test.go `
  admin_back_go/internal/module/export/repository.go
git commit -m "feat: store export cos object key"
```

---

## Task 4: 用户导出兼容接入新 runtime

**Files:**
- Modify: `admin_back_go/internal/module/user/export_provider.go`
- Modify: `admin_back_go/internal/module/user/service.go`
- Modify: `admin_back_go/internal/module/user/service_test.go`

- [ ] **Step 1: 写失败测试，用户 submit payload 必须带 selected scope/platform/kind**

In `TestServiceExportNormalizesCreatesPendingAndEnqueuesLowTask`, assert:

```go
if creator.createdInput.UserID != 9 || creator.createdInput.Title != "用户列表导出" || creator.createdInput.Kind != exporttask.KindUserList || creator.createdInput.Platform != enum.PlatformAdmin {
	t.Fatalf("unexpected created task input: %#v", creator.createdInput)
}
```

Update fake creator input type:

```go
type CreateExportTaskInput struct {
	UserID   int64
	Platform string
	Kind     string
	Title    string
}
```

Update payload assertion:

```go
if payload.TaskID != 88 || payload.Kind != exporttask.KindUserList || payload.UserID != 9 || payload.Platform != enum.PlatformAdmin || payload.Scope != exporttask.ScopeSelected || !reflect.DeepEqual(payload.IDs, []int64{2, 3}) {
	t.Fatalf("unexpected payload: %#v", payload)
}
```

- [ ] **Step 2: 写 provider 新 signature 失败测试**

Modify `TestExportDataProviderBuildsUserListFileData`:

```go
data, err := NewExportDataProvider(repo).BuildExportData(context.Background(), exporttask.BuildInput{Kind: exporttask.KindUserList, Scope: exporttask.ScopeSelected, IDs: []int64{2}})
```

- [ ] **Step 3: Run user tests to verify failure**

```powershell
cd E:\admin_go\admin_back_go
go test -p 1 ./internal/module/user -run "TestServiceExportNormalizesCreatesPendingAndEnqueuesLowTask|TestExportDataProviderBuildsUserListFileData" -count=1
```

Expected: fail because user provider still uses old signature and creator does not receive kind/platform.

- [ ] **Step 4: Update user export provider signature**

Replace `BuildExportData` signature in `admin_back_go/internal/module/user/export_provider.go`:

```go
func (p *ExportDataProvider) BuildExportData(ctx context.Context, input exporttask.BuildInput) (*exporttask.FileData, error)
```

Replace the function body with:

```go
if p == nil || p.repository == nil {
	return nil, ErrRepositoryNotConfigured
}
if input.Kind != exporttask.KindUserList {
	return nil, fmt.Errorf("unsupported export kind: %s", input.Kind)
}
if input.Scope != "" && input.Scope != exporttask.ScopeSelected {
	return nil, fmt.Errorf("unsupported user export scope: %s", input.Scope)
}
ids := normalizeIDs(input.IDs)
if len(ids) == 0 {
	return nil, fmt.Errorf("export user ids are required")
}
rows, err := p.repository.ExportUsersByIDs(ctx, ids)
if err != nil {
	return nil, err
}
```

Keep the existing row mapping and header construction after this block.

- [ ] **Step 5: Update user service submit**

In `admin_back_go/internal/module/user/service.go`, create pending task:

```go
taskID, err := s.exportTaskCreator.CreatePending(ctx, exporttask.CreatePendingInput{UserID: input.UserID, Platform: input.Platform, Kind: exporttask.KindUserList, Title: "用户列表导出"})
```

Create queue payload:

```go
task, err := exporttask.NewRunTask(exporttask.RunPayload{
	TaskID:   taskID,
	Kind:     exporttask.KindUserList,
	UserID:   input.UserID,
	Platform: input.Platform,
	Scope:    exporttask.ScopeSelected,
	IDs:      ids,
})
```

- [ ] **Step 6: Run user and export package tests**

```powershell
cd E:\admin_go\admin_back_go
go test -p 1 ./internal/module/user ./internal/module/export -count=1
```

Expected: pass.

- [ ] **Step 7: Commit Task 4**

```powershell
cd E:\admin_go
git add admin_back_go/internal/module/user/export_provider.go `
  admin_back_go/internal/module/user/service.go `
  admin_back_go/internal/module/user/service_test.go
git commit -m "feat: route user export through runtime registry"
```

---

## Task 5: Export task admin API and frontend helper

**Files:**
- Modify: `admin_back_go/internal/module/export/transport/admin/request.go`
- Modify: `admin_back_go/internal/module/export/transport/admin/handler.go`
- Modify: `admin_back_go/internal/module/export/transport/admin/handler_test.go`
- Create: `admin_front_ts/src/hooks/useExportSubmit.ts`
- Modify: `admin_front_ts/src/views/Main/user/userManager/components/UserList/index.vue`
- Modify: `admin_front_ts/src/api/system/exportTask.ts`
- Modify: `admin_front_ts/tests/shared/user/user-list.test.ts`
- Modify: `admin_front_ts/tests/shared/system/export-task-api.test.ts`
- Create: `admin_front_ts/tests/shared/system/export-submit-helper.test.ts`

- [ ] **Step 1: Backend handler test for platform/kind query**

In `TestHandlerStatusCountScopesCurrentUser`, use this request:

```go
request := httptest.NewRequest(http.MethodGet, "/api/admin/v1/export-tasks/status-count?kind=user_list&title=%E7%94%A8%E6%88%B7", nil)
```

Use this assertion:

```go
if service.statusQuery.UserID != 9 || service.statusQuery.Platform != "admin" || service.statusQuery.Kind != exporttaskmodule.KindUserList || service.statusQuery.Title != "用户" {
	t.Fatalf("unexpected status query: %#v", service.statusQuery)
}
```

In `TestHandlerListBindsQueryAndScopesCurrentUser`, use this request:

```go
request := httptest.NewRequest(http.MethodGet, "/api/admin/v1/export-tasks?current_page=2&page_size=10&status=2&kind=user_list&file_name=u.xlsx", nil)
```

Use this assertion:

```go
if service.listQuery.UserID != 9 || service.listQuery.Platform != "admin" || service.listQuery.Kind != exporttaskmodule.KindUserList || service.listQuery.CurrentPage != 2 || service.listQuery.PageSize != 10 || service.listQuery.Status == nil || *service.listQuery.Status != 2 || service.listQuery.FileName != "u.xlsx" {
	t.Fatalf("unexpected list query: %#v", service.listQuery)
}
```

- [ ] **Step 2: Run handler tests to verify failure**

```powershell
cd E:\admin_go\admin_back_go
go test -p 1 ./internal/module/export/transport/admin -run "TestHandlerStatusCountScopesCurrentUser|TestHandlerListBindsQueryAndScopesCurrentUser" -count=1
```

Expected: fail because handler does not bind kind/platform yet.

- [ ] **Step 3: Update backend request/handler**

Use these request structs in `request.go`:

```go
type statusCountRequest struct {
	Kind     string `form:"kind" binding:"omitempty,max=64"`
	Title    string `form:"title" binding:"omitempty,max=100"`
	FileName string `form:"file_name" binding:"omitempty,max=255"`
}

type listRequest struct {
	CurrentPage int    `form:"current_page" binding:"omitempty,min=1"`
	PageSize    int    `form:"page_size" binding:"omitempty,min=1,max=50"`
	Status      *int   `form:"status" binding:"omitempty,oneof=1 2 3"`
	Kind        string `form:"kind" binding:"omitempty,max=64"`
	Title       string `form:"title" binding:"omitempty,max=100"`
	FileName    string `form:"file_name" binding:"omitempty,max=255"`
}
```

In `handler.go`, pass `Platform: identity.Platform` and `Kind: req.Kind` into `StatusCountQuery` and `ListQuery`. In delete calls, pass:

```go
exporttaskmodule.DeleteInput{UserID: identity.UserID, Platform: identity.Platform, IDs: []int64{id}}
```

and:

```go
exporttaskmodule.DeleteInput{UserID: identity.UserID, Platform: identity.Platform, IDs: req.IDs}
```

- [ ] **Step 4: Frontend helper test first**

Create `admin_front_ts/tests/shared/system/export-submit-helper.test.ts`:

```ts
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { describe, expect, it } from 'vitest'

function readFrontendSource(relativePath: string) {
  return readFileSync(resolve(process.cwd(), relativePath), 'utf8')
}

describe('export submit helper contract', () => {
  it('centralizes selected id validation and export submitted message without hardcoded Chinese', () => {
    const source = readFrontendSource('src/hooks/useExportSubmit.ts')

    expect(source).toContain('export function useExportSubmit')
    expect(source).toContain('selectedIds.length === 0')
    expect(source).toContain("t('common.selectAtLeastOne')")
    expect(source).toContain("t('common.export.submitted')")
    expect(source).not.toMatch(/[\u4e00-\u9fff]/)
  })

  it('user list uses the shared helper and keeps export permission', () => {
    const source = readFrontendSource('src/views/Main/user/userManager/components/UserList/index.vue')

    expect(source).toContain("import { useExportSubmit } from '@/hooks/useExportSubmit'")
    expect(source).toContain("userStore.can('user_userManager_export')")
    expect(source).toContain('@click="exportExcel"')
  })
})
```

- [ ] **Step 5: Run frontend helper test to verify failure**

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/system/export-submit-helper.test.ts
```

Expected: fail because hook file does not exist.

- [ ] **Step 6: Create frontend helper**

Create `admin_front_ts/src/hooks/useExportSubmit.ts`:

```ts
import { ElNotification } from 'element-plus'
import { useI18n } from 'vue-i18n'

interface ExportSubmitOptions<Response extends { message?: string | null }> {
  selectedIds: () => number[]
  submit: (ids: number[]) => Promise<Response>
  afterSubmit?: () => void | Promise<void>
}

export function useExportSubmit<Response extends { message?: string | null }>(options: ExportSubmitOptions<Response>) {
  const { t } = useI18n()

  const submitSelectedExport = async () => {
    const selectedIds = options.selectedIds()
    if (selectedIds.length === 0) {
      ElNotification.error({ message: t('common.selectAtLeastOne') })
      return
    }

    const data = await options.submit([...selectedIds])
    ElNotification.success({ message: data.message || t('common.export.submitted') })
    await options.afterSubmit?.()
  }

  return { submitSelectedExport }
}
```

- [ ] **Step 7: Refactor user list to helper**

In `UserList/index.vue`, add:

```ts
import { useExportSubmit } from '@/hooks/useExportSubmit'
```

After `selectedIds` is created, add:

```ts
const { submitSelectedExport } = useExportSubmit({
  selectedIds: () => selectedIds.value,
  submit: (ids) => UsersListApi.export({ ids }),
})
```

Replace `exportExcel`:

```ts
const exportExcel = async () => {
  await submitSelectedExport()
}
```

- [ ] **Step 8: Update export task API type**

In `admin_front_ts/src/api/system/exportTask.ts`, update the type blocks:

```ts
export interface ExportTaskListParams extends RequestPayload {
  current_page?: number
  page_size?: number
  status?: number | ''
  kind?: string
  title?: string
  file_name?: string
}

export interface ExportTaskItem {
  id: number
  kind: string
  kind_text: string
  title: string
  file_name?: string | null
  file_url?: string | null
  file_size_text: string
  row_count?: number | null
  status: number
  status_text: string
  error_msg?: string | null
  expire_at?: string | null
  created_at: string
}
```

- [ ] **Step 9: Run focused frontend tests**

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/system/export-submit-helper.test.ts tests/shared/user/user-list.test.ts tests/shared/system/export-task-api.test.ts
```

Expected: pass.

- [ ] **Step 10: Commit Task 5**

```powershell
cd E:\admin_go
git add admin_back_go/internal/module/export/transport/admin/request.go `
  admin_back_go/internal/module/export/transport/admin/handler.go `
  admin_back_go/internal/module/export/transport/admin/handler_test.go `
  admin_front_ts/src/hooks/useExportSubmit.ts `
  admin_front_ts/src/views/Main/user/userManager/components/UserList/index.vue `
  admin_front_ts/src/api/system/exportTask.ts `
  admin_front_ts/tests/shared/user/user-list.test.ts `
  admin_front_ts/tests/shared/system/export-task-api.test.ts `
  admin_front_ts/tests/shared/system/export-submit-helper.test.ts
git commit -m "feat: share export submit flow"
```

---

## Task 6: Gated real export smoke

**Files:**
- Create: `admin_back_go/scripts/export-task-smoke.ps1`
- Modify: `docs/testing/smoke-matrix.md`

- [ ] **Step 1: Create smoke script with explicit gate**

Create `admin_back_go/scripts/export-task-smoke.ps1`:

```powershell
param(
  [string]$Account = $env:SMOKE_LOGIN_ACCOUNT,
  [string]$Password = $env:SMOKE_LOGIN_PASSWORD,
  [string]$BaseURL = 'http://127.0.0.1:8080',
  [string]$Platform = 'admin',
  [string]$DeviceID = 'codex-export-smoke',
  [switch]$RunRealExport
)

$ErrorActionPreference = 'Stop'

function Assert-ApiOK($Response, [string]$Label) {
  if ($Response.code -ne 0) {
    throw "$Label failed: $($Response | ConvertTo-Json -Depth 12)"
  }
}

if (-not $RunRealExport) {
  throw 'Real export smoke is gated. Pass -RunRealExport to submit an export and upload to COS.'
}

if ([string]::IsNullOrWhiteSpace($Account) -or [string]::IsNullOrWhiteSpace($Password)) {
  throw 'Set SMOKE_LOGIN_ACCOUNT and SMOKE_LOGIN_PASSWORD, or pass -Account and -Password.'
}

function Invoke-Api($Path, [string]$Method = 'Get', $Headers = @{}, $Body = $null) {
  $params = @{
    Uri = "$BaseURL$Path"
    Method = $Method
    Headers = $Headers
    TimeoutSec = 10
  }
  if ($null -ne $Body) {
    $params.ContentType = 'application/json'
    $params.Body = ($Body | ConvertTo-Json -Depth 8)
  }
  Invoke-RestMethod @params
}

$captcha = Invoke-Api '/api/admin/v1/auth/captcha'
Assert-ApiOK $captcha 'captcha'

$login = Invoke-Api '/api/admin/v1/auth/login' 'Post' @{ platform = $Platform; 'device-id' = $DeviceID } @{
  login_account = $Account
  login_type = 'password'
  password = $Password
  captcha_id = $captcha.data.captcha_id
  captcha_answer = @{ x = 0; y = 0 }
}
Assert-ApiOK $login 'login'
if ([string]::IsNullOrWhiteSpace($login.data.access_token)) {
  throw 'login did not return access_token'
}

$headers = @{
  platform = $Platform
  'device-id' = $DeviceID
  Authorization = "Bearer $($login.data.access_token)"
}

$users = Invoke-Api '/api/admin/v1/users?current_page=1&page_size=1' 'Get' $headers
Assert-ApiOK $users 'users list'
$firstUser = @($users.data.list) | Select-Object -First 1
if ($null -eq $firstUser -or [int64]$firstUser.id -le 0) {
  throw 'users list returned no exportable user'
}

$submit = Invoke-Api '/api/admin/v1/users/export' 'Post' $headers @{ ids = @([int64]$firstUser.id) }
Assert-ApiOK $submit 'submit export'
$taskID = [int64]$submit.data.id
if ($taskID -le 0) {
  throw "submit export returned invalid id: $($submit | ConvertTo-Json -Depth 12)"
}

$task = $null
for ($i = 0; $i -lt 40; $i++) {
  Start-Sleep -Milliseconds 750
  $list = Invoke-Api '/api/admin/v1/export-tasks?current_page=1&page_size=20&kind=user_list' 'Get' $headers
  Assert-ApiOK $list 'export task list'
  $task = @($list.data.list) | Where-Object { [int64]$_.id -eq $taskID } | Select-Object -First 1
  if ($null -ne $task -and ([int]$task.status -eq 2 -or [int]$task.status -eq 3)) {
    break
  }
}

if ($null -eq $task) {
  throw "export task $taskID is not visible for current user"
}
if ([int]$task.status -ne 2) {
  throw "export task $taskID did not succeed: $($task | ConvertTo-Json -Depth 12)"
}
if (-not ([string]$task.file_name).EndsWith('.xlsx')) {
  throw "export task file_name is not xlsx: $($task.file_name)"
}
if ([string]::IsNullOrWhiteSpace([string]$task.file_url)) {
  throw 'export task file_url is empty'
}
if ([int64]$task.row_count -lt 1) {
  throw "export task row_count is invalid: $($task.row_count)"
}
if ([string]$task.file_size_text -eq '-') {
  throw "export task file_size_text is invalid: $($task.file_size_text)"
}

Invoke-Api "/api/admin/v1/export-tasks/$taskID" 'Delete' $headers | Out-Null

[pscustomobject]@{
  export_task_id = $taskID
  status = [int]$task.status
  file_name = [string]$task.file_name
  row_count = [int64]$task.row_count
  file_url_present = -not [string]::IsNullOrWhiteSpace([string]$task.file_url)
} | ConvertTo-Json -Depth 6
```

If the local captcha answer is not deterministic in this environment, copy the deterministic captcha extraction helper from `admin_back_go/scripts/basic-admin-smoke.ps1` into this smoke script before running the real export gate.

- [ ] **Step 2: Run smoke without gate to verify it refuses mutation**

```powershell
cd E:\admin_go\admin_back_go
powershell -ExecutionPolicy Bypass -File .\scripts\export-task-smoke.ps1
```

Expected: fail with `Real export smoke is gated`.

- [ ] **Step 3: Add smoke matrix wording**

In `docs/testing/smoke-matrix.md`, update the export task row:

```text
full smoke 只探测当前用户导出任务状态统计和分页 shape；不触发真实导出、不等待 worker、不上传 COS。真实 submit -> worker -> COS 上传由 `admin_back_go/scripts/export-task-smoke.ps1 -RunRealExport` 覆盖，必须显式传凭据和开关。
```

- [ ] **Step 4: Real export smoke command**

Only run when local backend and worker are up and enabled COS secrets are valid for current `APP_SECRET`:

```powershell
cd E:\admin_go\admin_back_go
powershell -ExecutionPolicy Bypass -File .\scripts\export-task-smoke.ps1 -Account 15671628271 -Password 123456 -BaseURL http://127.0.0.1:8080 -RunRealExport
```

Expected: JSON output with `status: 2`, `file_name` ending `.xlsx`, `row_count >= 1`, `file_url_present: true`.

- [ ] **Step 5: Commit Task 6**

```powershell
cd E:\admin_go
git add admin_back_go/scripts/export-task-smoke.ps1 docs/testing/smoke-matrix.md
git commit -m "test: add gated export task smoke"
```

---

## Task 7: Contract/status/docs sync

**Files:**
- Modify: `docs/contracts/admin-api-v1.md`
- Modify: `docs/status/current-status.md`
- Modify: `docs/status/module-matrix.md`
- Modify: `admin_back_go/docs/architecture.md`

- [ ] **Step 1: Update API contract export submit section**

In `docs/contracts/admin-api-v1.md`, update user export rules:

```text
规则：当前用户管理页继续只接受显式勾选的正整数用户 id；service 去重后只导出未软删除用户。内部归一化为 `kind=user_list`、`scope=selected`、`platform=admin` 的导出任务。创建 `export_tasks` pending 记录后投递 `export:run:v1` 到 low queue；队列投递失败必须把任务标记 failed，不允许留下永久 pending。
```

- [ ] **Step 2: Update Export Tasks contract section**

In `docs/contracts/admin-api-v1.md`, update `ExportTaskListQuery` and response to include:

```ts
kind?: string
kind: string
kind_text: string
```

Add rule:

```text
`export_tasks.kind/platform/object_key` 是 V2 运行时字段：kind 表示导出场景，platform 表示入口隔离，object_key 表示 COS object key。API list 不暴露 object_key，只返回 file_url 下载地址。
```

- [ ] **Step 3: Update module matrix**

In `docs/status/module-matrix.md`, add:

```text
- export runtime:
  - implemented as reusable `internal/module/export` runtime for task lifecycle, queue execution, xlsx writer, COS upload, status update and notification
  - `user_list` remains the first registered provider and keeps current selected-id user-manager behavior
  - `export_tasks` stores `kind/platform/object_key`; future payment/wallet/AI exports add providers instead of copying runtime
```

- [ ] **Step 4: Update current status based on real verification**

If gated smoke passed, add verified status to `docs/status/current-status.md`.

If gated smoke was not run, write this under `Current verification gaps`:

```text
Export runtime V2 code/tests are complete, but the credential-gated real submit-to-COS smoke has not been run in this environment; do not claim COS upload runtime closure until `scripts/export-task-smoke.ps1 -RunRealExport` passes.
```

- [ ] **Step 5: Update backend architecture doc**

In `admin_back_go/docs/architecture.md`, add:

```text
导出是 `internal/module/export` 的通用运行时能力：业务模块拥有 submit endpoint、权限码和 provider；export runtime 统一拥有 `export_tasks` 生命周期、`export:run:v1`、xlsx writer、COS uploader、状态落库和通知。用户导出只是第一条 `kind=user_list` provider；后续 payment/wallet/AI 导出不得复制任务表、writer 或上传逻辑。
```

- [ ] **Step 6: Run docs checks**

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected: both pass.

- [ ] **Step 7: Commit Task 7**

```powershell
cd E:\admin_go
git add docs/contracts/admin-api-v1.md `
  docs/status/current-status.md `
  docs/status/module-matrix.md `
  docs/testing/smoke-matrix.md `
  admin_back_go/docs/architecture.md
git commit -m "docs: sync export runtime v2 contract"
```

---

## Task 8: Final verification gate

**Files:**
- No new source files expected. This task verifies the finished slice.

- [ ] **Step 1: Backend focused tests**

```powershell
cd E:\admin_go\admin_back_go
go test -p 1 ./internal/module/export ./internal/module/export/transport/admin ./internal/module/user ./internal/jobs ./internal/bootstrap ./internal/server -count=1
```

Expected: all selected backend packages pass.

- [ ] **Step 2: Frontend focused tests**

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/system/export-submit-helper.test.ts tests/shared/user/user-list.test.ts tests/shared/system/export-task-api.test.ts
```

Expected: all selected Vitest files pass.

- [ ] **Step 3: Frontend typecheck**

```powershell
cd E:\admin_go\admin_front_ts
npm run typecheck
```

Expected: typecheck passes. If the project uses another script name, run `npm run` and choose the existing vue-tsc/typecheck script; record the exact command in final notes.

- [ ] **Step 4: SQL migration dry-run on local DB**

Only run when local MySQL is available:

```powershell
cd E:\admin_go\admin_back_go
mysql --host=127.0.0.1 --port=3307 --protocol=tcp --user=root --password=admin_go_local --database=admin --execute="START TRANSACTION; SOURCE database/migrations/20260530_export_runtime_v2.sql; SHOW COLUMNS FROM export_tasks LIKE 'kind'; SHOW COLUMNS FROM export_tasks LIKE 'platform'; SHOW COLUMNS FROM export_tasks LIKE 'object_key'; ROLLBACK;"
```

Expected: the three `SHOW COLUMNS` queries return rows.

- [ ] **Step 5: Gated real export smoke**

Only run if API, worker, Redis, DB and COS secrets are ready:

```powershell
cd E:\admin_go\admin_back_go
powershell -ExecutionPolicy Bypass -File .\scripts\export-task-smoke.ps1 -Account 15671628271 -Password 123456 -BaseURL http://127.0.0.1:8080 -RunRealExport
```

Expected: JSON contains `status: 2`, `.xlsx`, `row_count >= 1`, `file_url_present: true`.

- [ ] **Step 6: Governance checks**

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected: both pass.

---

## Self-review checklist

- Spec coverage:
  - 基础能力定位：Task 2 registry、Task 3 runtime、Task 5 helper、Task 7 docs cover it.
  - 多场景 provider 模板：Task 2 creates registry; Task 7 records provider-only expansion rule.
  - `selected|filtered` 显式 scope：Task 2 payload validates scope; Task 4 maps existing user export to selected.
  - `kind/platform/object_key`：Task 1 schema/model/dto/repository; Task 3 uploader and success result.
  - COS-only upload：Task 3 preserves COSUploader; Task 6 smoke proves real upload when credentials exist.
  - 当前用户列表兼容：Task 4 keeps `{ ids }`; Task 5 keeps permission/button behavior.
  - Smoke gap：Task 6 adds gated real smoke; Task 8 final gate runs or records gap.
- Placeholder scan: this plan contains no placeholder instructions or cross-task handwaving.
- Type consistency:
  - `ScopeSelected` / `ScopeFiltered` are defined in Task 2 and used by Tasks 2-4.
  - `BuildInput` is defined in Task 2 and used by `user.ExportDataProvider` in Task 4.
  - `ObjectKey` is added to `UploadResult` and `SuccessResult` in Tasks 1 and 3.
  - `Platform` is passed through handler/query/delete in Tasks 1 and 5.
