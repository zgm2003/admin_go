# Transport Admin Alias Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove transitional `transport/admin` root-module type aliases and guard the boundary so `transport/{platform}` stays an HTTP surface instead of a re-export layer.

**Architecture:** Add a failing architecture guard first, then clean shared server dependency seams, then run independent module lanes in parallel. Each lane only touches its own `internal/module/**/transport/admin` files and must not edit `internal/server/router.go`.

**Tech Stack:** Go 1.26, Gin, existing `internal/architecture` Go tests, PowerShell verification on Windows.

---

## Read first

- `E:\admin_go\AGENTS.md`
- `E:\admin_go\docs\status\current-status.md`
- `E:\admin_go\docs\status\module-matrix.md`
- `E:\admin_go\docs\architecture\04-go-backend-framework.md`
- `E:\admin_go\docs\superpowers\specs\2026-05-29-transport-admin-alias-cleanup-design.md`
- `E:\admin_go\docs\superpowers\specs\2026-05-27-multi-platform-backend-boundary-design.md`

## Parallel rule

```text
Task 1 and Task 2 are serial.
Task 3A, 3B, 3C, 3D, and 3E can run in parallel after Task 2.
Task 4 is serial integration.
Parallel lane workers must not edit internal/server/router.go, docs, or architecture tests.
```

## File map

### Shared serial files

- Modify: `E:\admin_go\admin_back_go\internal\architecture\multiplatform_boundary_test.go`
  - Adds the guard that rejects `transport/**/aliases.go` and root-module type aliases.
- Modify: `E:\admin_go\admin_back_go\internal\server\router.go`
  - Moves dependency field types that currently rely on transport alias re-exports to root module packages.

### Parallel lane files

AI core lane:

- Delete: `E:\admin_go\admin_back_go\internal\module\ai\provider\transport\admin\aliases.go`
- Modify: `E:\admin_go\admin_back_go\internal\module\ai\provider\transport\admin\handler.go`
- Modify: `E:\admin_go\admin_back_go\internal\module\ai\provider\transport\admin\route.go`
- Delete: `E:\admin_go\admin_back_go\internal\module\ai\agent\transport\admin\aliases.go`
- Modify: `E:\admin_go\admin_back_go\internal\module\ai\agent\transport\admin\handler.go`
- Modify: `E:\admin_go\admin_back_go\internal\module\ai\agent\transport\admin\route.go`
- Delete: `E:\admin_go\admin_back_go\internal\module\ai\tool\transport\admin\aliases.go`
- Modify: `E:\admin_go\admin_back_go\internal\module\ai\tool\transport\admin\handler.go`
- Modify: `E:\admin_go\admin_back_go\internal\module\ai\tool\transport\admin\route.go`

AI runtime lane:

- Delete: `E:\admin_go\admin_back_go\internal\module\ai\conversation\transport\admin\aliases.go`
- Modify: `E:\admin_go\admin_back_go\internal\module\ai\conversation\transport\admin\handler.go`
- Modify: `E:\admin_go\admin_back_go\internal\module\ai\conversation\transport\admin\route.go`
- Delete: `E:\admin_go\admin_back_go\internal\module\ai\message\transport\admin\aliases.go`
- Modify: `E:\admin_go\admin_back_go\internal\module\ai\message\transport\admin\handler.go`
- Modify: `E:\admin_go\admin_back_go\internal\module\ai\message\transport\admin\route.go`
- Delete: `E:\admin_go\admin_back_go\internal\module\ai\chat\transport\admin\aliases.go`
- Modify: `E:\admin_go\admin_back_go\internal\module\ai\chat\transport\admin\handler.go`
- Modify: `E:\admin_go\admin_back_go\internal\module\ai\chat\transport\admin\route.go`
- Delete: `E:\admin_go\admin_back_go\internal\module\ai\run\transport\admin\aliases.go`
- Modify: `E:\admin_go\admin_back_go\internal\module\ai\run\transport\admin\handler.go`
- Modify: `E:\admin_go\admin_back_go\internal\module\ai\run\transport\admin\route.go`

AI assets lane:

- Delete: `E:\admin_go\admin_back_go\internal\module\ai\image\transport\admin\aliases.go`
- Modify: `E:\admin_go\admin_back_go\internal\module\ai\image\transport\admin\handler.go`
- Modify: `E:\admin_go\admin_back_go\internal\module\ai\image\transport\admin\route.go`
- Delete: `E:\admin_go\admin_back_go\internal\module\ai\knowledge\transport\admin\aliases.go`
- Modify: `E:\admin_go\admin_back_go\internal\module\ai\knowledge\transport\admin\handler.go`
- Modify: `E:\admin_go\admin_back_go\internal\module\ai\knowledge\transport\admin\route.go`

Foundation lane:

- Delete: `E:\admin_go\admin_back_go\internal\module\clientversion\transport\admin\aliases.go`
- Delete: `E:\admin_go\admin_back_go\internal\module\crontask\transport\admin\aliases.go`
- Delete: `E:\admin_go\admin_back_go\internal\module\export\transport\admin\aliases.go`
- Delete: `E:\admin_go\admin_back_go\internal\module\operationlog\transport\admin\aliases.go`
- Delete: `E:\admin_go\admin_back_go\internal\module\queuemonitor\transport\admin\aliases.go`
- Delete: `E:\admin_go\admin_back_go\internal\module\realtime\transport\admin\aliases.go`
- Delete: `E:\admin_go\admin_back_go\internal\module\system\transport\admin\aliases.go`
- Delete: `E:\admin_go\admin_back_go\internal\module\systemlog\transport\admin\aliases.go`
- Delete: `E:\admin_go\admin_back_go\internal\module\systemsetting\transport\admin\aliases.go`
- Modify matching `handler.go`, `route.go`, and existing tests under each listed directory.

Business/comms/upload lane:

- Delete: `E:\admin_go\admin_back_go\internal\module\auth_platform\transport\admin\aliases.go`
- Delete: `E:\admin_go\admin_back_go\internal\module\mail\transport\admin\aliases.go`
- Modify: `E:\admin_go\admin_back_go\internal\module\mail\transport\admin\handler.go`
- Modify: `E:\admin_go\admin_back_go\internal\module\notification\transport\admin\handler.go`
- Modify: `E:\admin_go\admin_back_go\internal\module\notification\transport\admin\task_handler.go`
- Delete: `E:\admin_go\admin_back_go\internal\module\payment\transport\admin\aliases.go`
- Modify: `E:\admin_go\admin_back_go\internal\module\payment\transport\admin\handler.go`
- Modify: `E:\admin_go\admin_back_go\internal\module\payment\transport\admin\order_handler.go`
- Modify: `E:\admin_go\admin_back_go\internal\module\payment\transport\admin\recharge_handler.go`
- Modify: `E:\admin_go\admin_back_go\internal\module\sms\transport\admin\handler.go`
- Modify: `E:\admin_go\admin_back_go\internal\module\uploadconfig\transport\admin\handler.go`
- Modify: `E:\admin_go\admin_back_go\internal\module\uploadtoken\transport\admin\handler.go`

---

### Task 1: Add the failing architecture guard

**Files:**
- Modify: `E:\admin_go\admin_back_go\internal\architecture\multiplatform_boundary_test.go`

- [ ] **Step 1: Add `regexp` to imports**

Change the import block to include `regexp`:

```go
import (
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"
)
```

- [ ] **Step 2: Add the guard test**

Append this test near `TestNoModuleRootHTTPSurface`:

```go
func TestTransportDoesNotReExportModuleTypes(t *testing.T) {
	root := backendRoot(t)
	moduleRoot := filepath.Join(root, "internal", "module")
	moduleTypeAlias := regexp.MustCompile(`(?m)(^\s*type\s+[A-Z][A-Za-z0-9_]*\s*=\s*[a-zA-Z0-9_]+module\.)|(^\s*[A-Z][A-Za-z0-9_]*\s*=\s*[a-zA-Z0-9_]+module\.)`)

	var offenders []string
	err := filepath.WalkDir(moduleRoot, func(path string, entry os.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if entry.IsDir() || filepath.Ext(path) != ".go" {
			return nil
		}
		rel, _ := filepath.Rel(root, path)
		rel = filepath.ToSlash(rel)
		if !strings.Contains(rel, "/transport/") {
			return nil
		}
		if filepath.Base(path) == "aliases.go" {
			offenders = append(offenders, rel+" uses aliases.go under transport")
		}
		body, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		if moduleTypeAlias.Match(body) {
			offenders = append(offenders, rel+" re-exports root module types")
		}
		return nil
	})
	if err != nil {
		t.Fatalf("walk module transport files: %v", err)
	}
	if len(offenders) > 0 {
		t.Fatalf("transport packages must not re-export root module types:\n  %s", strings.Join(offenders, "\n  "))
	}
}
```

- [ ] **Step 3: Run the architecture test and verify it fails for the current aliases**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture -run TestTransportDoesNotReExportModuleTypes -count=1
```

Expected: FAIL. The failure must name existing offenders such as `internal/module/ai/agent/transport/admin/aliases.go`.

- [ ] **Step 4: Commit Task 1**

```powershell
git add internal/architecture/multiplatform_boundary_test.go
git commit -m "test: guard transport module aliases"
```

---

### Task 2: Clean shared server dependency seams that rely on root alias re-exports

**Files:**
- Modify: `E:\admin_go\admin_back_go\internal\server\router.go`

- [ ] **Step 1: Update root module imports for fields currently backed by aliases**

Add root imports where missing:

```go
clientversion "admin_back_go/internal/module/clientversion"
crontask "admin_back_go/internal/module/crontask"
exporttask "admin_back_go/internal/module/export"
notification "admin_back_go/internal/module/notification"
notificationtask "admin_back_go/internal/module/notification/task"
system "admin_back_go/internal/module/system"
```

Keep transport/admin imports that are still needed for route registration, local handlers, or HTTP constants.

- [ ] **Step 2: Change only the shared fields that currently depend on root alias re-exports**

Use this target shape in `Dependencies`:

```go
Readiness               system.ReadinessChecker
ClientVersionService    clientversion.HTTPService
CronTaskService         crontask.HTTPService
ExportTaskService       exporttask.HTTPService
NotificationService     notification.HTTPService
NotificationTaskService notificationtask.HTTPService
```

Do not change fields that are backed by transport-local interfaces in this task, such as `MailService mailadmin.HTTPService`, `SmsService smsadmin.HTTPService`, `UploadConfigService uploadconfigadmin.HTTPService`, or `RoleService roleadmin.HTTPService`.

- [ ] **Step 3: Compile server package**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/server -run TestAdminRouteSnapshot -count=1
```

Expected: PASS or fail only because Task 1 guard still sees aliases. `internal/server` itself must compile.

- [ ] **Step 4: Commit Task 2**

```powershell
git add internal/server/router.go
git commit -m "refactor: point server deps at root services"
```

---

### Task 3A: Parallel lane - AI core aliases

**Files:**
- Delete/modify files listed in “AI core lane”.

- [ ] **Step 1: Replace alias usage with explicit root imports**

For each package, use this pattern:

```go
import aiagentmodule "admin_back_go/internal/module/ai/agent"

type Handler struct{ service aiagentmodule.HTTPService }

func NewHandler(service aiagentmodule.HTTPService) *Handler {
	return &Handler{service: service}
}

func createInput(req mutationRequest) aiagentmodule.CreateInput {
	return aiagentmodule.CreateInput{
		ProviderID:   req.ProviderID,
		Name:         req.Name,
		ModelID:      req.ModelID,
		Scenes:       req.Scenes,
		SystemPrompt: req.SystemPrompt,
		Avatar:       req.Avatar,
		Status:       req.Status,
	}
}
```

Apply the same explicit-prefix pattern to `provider` and `tool` with aliases `aiprovidermodule` and `aitoolmodule`.

- [ ] **Step 2: Delete the three aliases files**

```powershell
git rm -- internal/module/ai/provider/transport/admin/aliases.go internal/module/ai/agent/transport/admin/aliases.go internal/module/ai/tool/transport/admin/aliases.go
```

- [ ] **Step 3: Run focused tests**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/ai/provider ./internal/module/ai/agent ./internal/module/ai/tool -count=1
go test ./internal/server -run TestAdminRouteSnapshot -count=1
```

Expected: package tests and server route snapshot pass. Architecture guard may still fail until all lanes finish.

- [ ] **Step 4: Commit lane**

```powershell
git add internal/module/ai/provider/transport/admin internal/module/ai/agent/transport/admin internal/module/ai/tool/transport/admin
git commit -m "refactor: remove ai core transport aliases"
```

---

### Task 3B: Parallel lane - AI runtime aliases

**Files:**
- Delete/modify files listed in “AI runtime lane”.

- [ ] **Step 1: Replace alias usage with explicit root imports**

Use these package aliases:

```go
aiconversationmodule "admin_back_go/internal/module/ai/conversation"
aimessagemodule "admin_back_go/internal/module/ai/message"
aichatmodule "admin_back_go/internal/module/ai/chat"
airunmodule "admin_back_go/internal/module/ai/run"
```

Every formerly unqualified type from `aliases.go` must become prefixed, for example:

```go
func Register(router *gin.Engine, service aiconversationmodule.HTTPService) {
	handler := NewHandler(service)
}

type Handler struct{ service aiconversationmodule.HTTPService }

func (nilHTTPService) List(ctx context.Context, query aiconversationmodule.ListQuery) (*aiconversationmodule.ListResponse, *apperror.Error) {
	return nil, apperror.Internal("AI会话服务未配置")
}
```

- [ ] **Step 2: Delete the four aliases files**

```powershell
git rm -- internal/module/ai/conversation/transport/admin/aliases.go internal/module/ai/message/transport/admin/aliases.go internal/module/ai/chat/transport/admin/aliases.go internal/module/ai/run/transport/admin/aliases.go
```

- [ ] **Step 3: Run focused tests**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/ai/conversation ./internal/module/ai/message ./internal/module/ai/chat ./internal/module/ai/run -count=1
go test ./internal/server -run TestAdminRouteSnapshot -count=1
```

Expected: package tests and server route snapshot pass. Queue task names and route snapshot must not change.

- [ ] **Step 4: Commit lane**

```powershell
git add internal/module/ai/conversation/transport/admin internal/module/ai/message/transport/admin internal/module/ai/chat/transport/admin internal/module/ai/run/transport/admin
git commit -m "refactor: remove ai runtime transport aliases"
```

---

### Task 3C: Parallel lane - AI asset aliases

**Files:**
- Delete/modify files listed in “AI assets lane”.

- [ ] **Step 1: Replace alias usage with explicit root imports**

Use these package aliases:

```go
aiimagemodule "admin_back_go/internal/module/ai/image"
aiknowledgemodule "admin_back_go/internal/module/ai/knowledge"
```

Example target shape:

```go
type Handler struct{ service aiimagemodule.HTTPService }

func NewHandler(service aiimagemodule.HTTPService) *Handler {
	return &Handler{service: service}
}

func createInput(req createRequest) aiimagemodule.CreateInput {
	return aiimagemodule.CreateInput{
		AgentID: req.AgentID,
		Prompt:  req.Prompt,
		Status:  req.Status,
	}
}
```

Keep existing request binding tags unchanged.

- [ ] **Step 2: Delete the two aliases files**

```powershell
git rm -- internal/module/ai/image/transport/admin/aliases.go internal/module/ai/knowledge/transport/admin/aliases.go
```

- [ ] **Step 3: Run focused tests**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/ai/image ./internal/module/ai/knowledge -count=1
go test ./internal/server -run TestAdminRouteSnapshot -count=1
```

Expected: package tests and server route snapshot pass.

- [ ] **Step 4: Commit lane**

```powershell
git add internal/module/ai/image/transport/admin internal/module/ai/knowledge/transport/admin
git commit -m "refactor: remove ai asset transport aliases"
```

---

### Task 3D: Parallel lane - Foundation aliases

**Files:**
- Delete/modify files listed in “Foundation lane”.

- [ ] **Step 1: Replace alias usage with explicit root imports**

Use these package aliases:

```go
clientversionmodule "admin_back_go/internal/module/clientversion"
crontaskmodule "admin_back_go/internal/module/crontask"
exporttaskmodule "admin_back_go/internal/module/export"
operationlogmodule "admin_back_go/internal/module/operationlog"
queuemonitormodule "admin_back_go/internal/module/queuemonitor"
realtimemodule "admin_back_go/internal/module/realtime"
systemmodule "admin_back_go/internal/module/system"
systemlogmodule "admin_back_go/internal/module/systemlog"
systemsettingmodule "admin_back_go/internal/module/systemsetting"
```

Example target shape for route/handler code:

```go
func RegisterRoutes(router *gin.Engine, service clientversionmodule.HTTPService) {
	validate.MustRegister()
	handler := NewHandler(service)
}

type Handler struct{ service clientversionmodule.HTTPService }
```

For queue monitor, keep `UIPath` exported from transport because it is an HTTP route constant used by server middleware. Move it out of `aliases.go` into `route.go`:

```go
const UIPath = queuemonitormodule.UIPath
```

For realtime tests and handler code, replace event constants with root-module prefixes:

```go
if connected.Type != realtimemodule.TypeConnectedV1 {
	t.Fatalf("expected connected event")
}
```

- [ ] **Step 2: Delete foundation aliases files**

```powershell
git rm -- internal/module/clientversion/transport/admin/aliases.go internal/module/crontask/transport/admin/aliases.go internal/module/export/transport/admin/aliases.go internal/module/operationlog/transport/admin/aliases.go internal/module/queuemonitor/transport/admin/aliases.go internal/module/realtime/transport/admin/aliases.go internal/module/system/transport/admin/aliases.go internal/module/systemlog/transport/admin/aliases.go internal/module/systemsetting/transport/admin/aliases.go
```

- [ ] **Step 3: Run focused tests**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/clientversion ./internal/module/crontask ./internal/module/export ./internal/module/operationlog ./internal/module/queuemonitor ./internal/module/realtime ./internal/module/system ./internal/module/systemlog ./internal/module/systemsetting -count=1
go test ./internal/server -run TestAdminRouteSnapshot -count=1
```

Expected: package tests and server route snapshot pass. Queue monitor UI path and realtime WS path stay unchanged.

- [ ] **Step 4: Commit lane**

```powershell
git add internal/module/clientversion/transport/admin internal/module/crontask/transport/admin internal/module/export/transport/admin internal/module/operationlog/transport/admin internal/module/queuemonitor/transport/admin internal/module/realtime/transport/admin internal/module/system/transport/admin internal/module/systemlog/transport/admin internal/module/systemsetting/transport/admin
git commit -m "refactor: remove foundation transport aliases"
```

---

### Task 3E: Parallel lane - Business, comms, and upload aliases

**Files:**
- Delete/modify files listed in “Business/comms/upload lane”.

- [ ] **Step 1: Replace aliases with explicit root imports**

Use these package aliases:

```go
authplatformmodule "admin_back_go/internal/module/auth_platform"
mailmodule "admin_back_go/internal/module/mail"
notificationmodule "admin_back_go/internal/module/notification"
notificationtaskmodule "admin_back_go/internal/module/notification/task"
paymentmodule "admin_back_go/internal/module/payment"
smsmodule "admin_back_go/internal/module/sms"
uploadconfigmodule "admin_back_go/internal/module/uploadconfig"
uploadtokenmodule "admin_back_go/internal/module/uploadtoken"
```

Example target shape for direct handler aliases:

```go
type Handler struct{ service HTTPService }

func (h *Handler) Init(c *gin.Context) {
	result, appErr := h.service.Init(c.Request.Context())
	writeResult(c, result, appErr)
}

func toCreateInput(req createRequest) uploadtokenmodule.CreateInput {
	return uploadtokenmodule.CreateInput{
		Driver: req.Driver,
		Path:   req.Path,
	}
}
```

For notification task, do not keep `type TaskHTTPService = notificationtaskmodule.HTTPService`. Use the root type directly:

```go
func RegisterTaskRoutes(router *gin.Engine, service notificationtaskmodule.HTTPService) {
	validate.MustRegister()
	handler := NewTaskHandler(service)
}

type TaskHandler struct {
	service notificationtaskmodule.HTTPService
}
```

For mail defaults, replace constants with direct root-module references at use sites, or keep a transport-owned const only if the value is part of the HTTP form default. Do not keep it in `aliases.go`.

- [ ] **Step 2: Delete aliases files in this lane**

```powershell
git rm -- internal/module/auth_platform/transport/admin/aliases.go internal/module/mail/transport/admin/aliases.go internal/module/payment/transport/admin/aliases.go
```

- [ ] **Step 3: Run focused tests**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/auth_platform ./internal/module/mail ./internal/module/notification ./internal/module/payment ./internal/module/sms ./internal/module/uploadconfig ./internal/module/uploadtoken -count=1
go test ./internal/server -run TestAdminRouteSnapshot -count=1
```

Expected: package tests and server route snapshot pass. Payment callback/admin route behavior must not change.

- [ ] **Step 4: Commit lane**

```powershell
git add internal/module/auth_platform/transport/admin internal/module/mail/transport/admin internal/module/notification/transport/admin internal/module/payment/transport/admin internal/module/sms/transport/admin internal/module/uploadconfig/transport/admin internal/module/uploadtoken/transport/admin
git commit -m "refactor: remove business transport aliases"
```

---

### Task 4: Integration, scans, and full verification

**Files:**
- Review all files changed by Tasks 1-3E.
- Modify any remaining file reported by scans below.

- [ ] **Step 1: Run alias scans**

```powershell
cd E:\admin_go\admin_back_go
Get-ChildItem -Path .\internal\module -Recurse -Filter aliases.go
rg -n '(^\s*[A-Z][A-Za-z0-9_]*\s*=\s*[a-zA-Z0-9_]+module\.)|(type\s+[A-Z][A-Za-z0-9_]*\s*=\s*[a-zA-Z0-9_]+module\.)' .\internal\module --glob '**/transport/**/*.go'
```

Expected: both commands return no transport alias offenders.

- [ ] **Step 2: Run architecture and route snapshot tests**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture -count=1
go test ./internal/server -run TestAdminRouteSnapshot -count=1
```

Expected: PASS.

- [ ] **Step 3: Run full backend verification**

```powershell
cd E:\admin_go\admin_back_go
go test ./... -count=1
go build ./...
```

Expected: PASS.

- [ ] **Step 4: Run root governance checks**

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected: both pass.

- [ ] **Step 5: Commit integration**

```powershell
git add admin_back_go docs/superpowers/specs/2026-05-29-transport-admin-alias-cleanup-design.md docs/superpowers/plans/2026-05-29-transport-admin-alias-cleanup.md
git commit -m "refactor: close transport alias cleanup"
```

---

## Self-review

- Spec coverage: Tasks cover architecture guard, server shared seam, all `aliases.go`, direct handler type aliases, scans, and full verification.
- Placeholder scan: no placeholder steps remain; each task has exact files, commands, and expected results.
- Type consistency: root package aliases use existing module paths; transport-local interfaces are intentionally left in scope only when they are not root-module alias re-exports.
- Parallel safety: only Task 2 edits `internal/server/router.go`; lane tasks are independent by directory.

## Execution handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-29-transport-admin-alias-cleanup.md`.

Two execution options:

1. **Subagent-Driven (recommended)** - dispatch one fresh worker for Task 1, one for Task 2, then dispatch Tasks 3A-3E in parallel, then integrate with Task 4.
2. **Inline Execution** - execute serially in this session using checkpoints.
