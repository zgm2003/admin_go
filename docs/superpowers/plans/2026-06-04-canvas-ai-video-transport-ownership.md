# Canvas AI Video Transport Ownership Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move Canvas video generation routes and runtime ownership from `internal/module/canvas` to `internal/module/ai/video` without changing the external Canvas API contract or `canvas_video_tasks` table name.

**Architecture:** `canvas` keeps Canvas platform resources (`settings/prompts/assets`) and still returns `agents.video` from settings. `ai/video` owns Canvas video generation, provider task lifecycle, `canvas_video_tasks` model/repository, and Canvas HTTP transport. Server registers `aivideocanvas` beside `aiimagecanvas` and `aichatcanvas`.

**Tech Stack:** Go, Gin, GORM, `internal/infra/ai.VideoEngine`, `secretbox`, `apperror`, `response`, PowerShell verification.

---

## Scope

Implements Phase B from `docs/superpowers/specs/2026-06-04-canvas-ai-video-transport-ownership-design.md`.

Move these routes:

```text
POST /api/canvas/v1/ai/videos
GET  /api/canvas/v1/ai/videos/:id
GET  /api/canvas/v1/ai/videos/:id/content
```

from:

```text
admin_back_go/internal/module/canvas/transport/canvas
```

to:

```text
admin_back_go/internal/module/ai/video/transport/canvas
```

Do not change:

```text
external URLs
request JSON fields
response JSON fields
canvas_video_tasks physical table name
Canvas free-generation semantics
Canvas settings agents.video
```

## Files

Create:

```text
admin_back_go/internal/module/ai/video/dto.go
admin_back_go/internal/module/ai/video/model.go
admin_back_go/internal/module/ai/video/repository.go
admin_back_go/internal/module/ai/video/service.go
admin_back_go/internal/module/ai/video/service_test.go
admin_back_go/internal/module/ai/video/transport/canvas/request.go
admin_back_go/internal/module/ai/video/transport/canvas/handler.go
admin_back_go/internal/module/ai/video/transport/canvas/route.go
admin_back_go/internal/module/ai/video/transport/canvas/handler_test.go
```

Modify:

```text
admin_back_go/internal/server/router.go
admin_back_go/internal/server/routes_canvas.go
admin_back_go/internal/server/router_test.go
admin_back_go/internal/bootstrap/app.go
admin_back_go/internal/architecture/platform_route_line_test.go
admin_back_go/internal/module/canvas/dto.go
admin_back_go/internal/module/canvas/model.go
admin_back_go/internal/module/canvas/service.go
admin_back_go/internal/module/canvas/service_test.go
admin_back_go/internal/module/canvas/transport/canvas/route.go
admin_back_go/internal/module/canvas/transport/canvas/request.go
admin_back_go/internal/module/canvas/transport/canvas/handler.go
admin_back_go/internal/module/canvas/transport/canvas/handler_test.go
```

Delete:

```text
admin_back_go/internal/module/canvas/video_runtime.go
admin_back_go/internal/module/canvas/video_runtime_test.go
admin_back_go/internal/module/canvas/video_repository.go
```

## Compatibility rules

```text
POST /api/canvas/v1/ai/videos still returns data.id/data.status
GET /api/canvas/v1/ai/videos/:id still returns data.id/data.status
GET /api/canvas/v1/ai/videos/:id/content still streams binary body
client model must not override ai_agents.model_id
Canvas video remains free: no billing checks/writes
canvas_video_tasks table name remains unchanged
ownership check remains user_id + id + is_del=2
provider_task_id missing is an explicit error
Canvas settings still returns agents.video
```

---

### Task 1: Add `ai/video` core service, model, repository, and tests

**Files:**
- Create: `admin_back_go/internal/module/ai/video/dto.go`
- Create: `admin_back_go/internal/module/ai/video/model.go`
- Create: `admin_back_go/internal/module/ai/video/repository.go`
- Create: `admin_back_go/internal/module/ai/video/service.go`
- Create: `admin_back_go/internal/module/ai/video/service_test.go`

- [ ] **Step 1: Write RED service tests**

Create `admin_back_go/internal/module/ai/video/service_test.go` with these cases:

```go
package aivideo

import (
    "context"
    "errors"
    "testing"

    infraai "admin_back_go/internal/infra/ai"
    "admin_back_go/internal/infra/secretbox"
    "admin_back_go/internal/shared/apperror"
    "admin_back_go/internal/shared/enum"
)

type fakeRepository struct {
    agent         *AgentRuntime
    agentID       int64
    createdTask   VideoTask
    createdTaskID int64
    updates       []updateCall
    task          *VideoTask
}

type updateCall struct { userID int64; id int64; fields map[string]any }
func (f *fakeRepository) AgentForRuntime(ctx context.Context, agentID int64) (*AgentRuntime, error) { f.agentID = agentID; return f.agent, nil }
func (f *fakeRepository) CreateTask(ctx context.Context, task VideoTask) (int64, error) { f.createdTask = task; if f.createdTaskID > 0 { return f.createdTaskID, nil }; return 77, nil }
func (f *fakeRepository) UpdateTask(ctx context.Context, userID int64, id int64, fields map[string]any) error { f.updates = append(f.updates, updateCall{userID: userID, id: id, fields: fields}); return nil }
func (f *fakeRepository) GetTask(ctx context.Context, userID int64, id int64) (*VideoTask, error) { return f.task, nil }

type fakeEngineFactory struct { engine infraai.VideoEngine; input EngineConfig; err error }
func (f *fakeEngineFactory) NewVideoEngine(ctx context.Context, input EngineConfig) (infraai.VideoEngine, error) { f.input = input; if f.err != nil { return nil, f.err }; return f.engine, nil }

type fakeVideoEngine struct { createInput infraai.VideoInput; createTask *infraai.VideoTask; createErr error; statusID string; statusTask *infraai.VideoTask; statusErr error; contentID string; body []byte; contentType string; contentErr error }
func (f *fakeVideoEngine) CreateVideo(ctx context.Context, input infraai.VideoInput) (*infraai.VideoTask, error) { f.createInput = input; return f.createTask, f.createErr }
func (f *fakeVideoEngine) GetVideo(ctx context.Context, taskID string) (*infraai.VideoTask, error) { f.statusID = taskID; return f.statusTask, f.statusErr }
func (f *fakeVideoEngine) DownloadVideo(ctx context.Context, taskID string) ([]byte, string, error) { f.contentID = taskID; if f.contentErr != nil { return nil, "", f.contentErr }; return f.body, f.contentType, nil }

func validCanvasVideoAgent(t *testing.T, box secretbox.Box) *AgentRuntime {
    t.Helper()
    cipher, err := box.Encrypt("provider-key")
    if err != nil { t.Fatalf("encrypt fixture: %v", err) }
    return &AgentRuntime{AgentID: 8, ProviderID: 9, ModelID: "grok-imagine-video", ScenesJSON: `["canvas_video_generate"]`, EngineType: string(infraai.EngineTypeOpenAI), EngineBaseURL: "https://api.openai.test/v1", EngineAPIKeyEnc: cipher, AgentStatus: enum.CommonYes, EngineStatus: enum.CommonYes}
}
```

Add tests:

```go
func TestCreateUsesAgentModelCreatesLocalTaskAndStoresProviderTask(t *testing.T) {
    box := secretbox.New([]byte("12345678901234567890123456789012"))
    engine := &fakeVideoEngine{createTask: &infraai.VideoTask{ID: "provider-task-1", Status: "running"}}
    factory := &fakeEngineFactory{engine: engine}
    repo := &fakeRepository{agent: validCanvasVideoAgent(t, box)}

    result, appErr := NewService(Dependencies{Repository: repo, Secretbox: box, EngineFactory: factory}).Create(context.Background(), CreateInput{UserID: 7, AgentID: 8, ModelID: "client-model", Prompt: " clip ", DurationSeconds: 4, Size: "1280x720", ResolutionName: "720p"})

    if appErr != nil { t.Fatalf("Create error=%#v", appErr) }
    if result == nil || result.ID != 77 || result.Status != "running" { t.Fatalf("unexpected create result: %#v", result) }
    if repo.createdTask.UserID != 7 || repo.createdTask.AgentID != 8 || repo.createdTask.ModelID != "grok-imagine-video" || repo.createdTask.Prompt != "clip" || repo.createdTask.Status != StatusPending || repo.createdTask.IsDel != IsDelActive { t.Fatalf("local task mismatch: %#v", repo.createdTask) }
    if factory.input.APIKey != "provider-key" || factory.input.EngineType != infraai.EngineTypeOpenAI { t.Fatalf("engine config mismatch: %#v", factory.input) }
    if engine.createInput.Model != "grok-imagine-video" || engine.createInput.Prompt != "clip" || engine.createInput.DurationSeconds != 4 || engine.createInput.Size != "1280x720" { t.Fatalf("provider input mismatch: %#v", engine.createInput) }
    if len(repo.updates) != 1 || repo.updates[0].fields["provider_task_id"] != "provider-task-1" || repo.updates[0].fields["status"] != StatusRunning { t.Fatalf("provider task update mismatch: %#v", repo.updates) }
}

func TestCreateProviderFailureMarksLocalTaskFailed(t *testing.T) {
    box := secretbox.New([]byte("12345678901234567890123456789012"))
    repo := &fakeRepository{agent: validCanvasVideoAgent(t, box)}
    engine := &fakeVideoEngine{createErr: errors.New("provider down")}
    _, appErr := NewService(Dependencies{Repository: repo, Secretbox: box, EngineFactory: &fakeEngineFactory{engine: engine}}).Create(context.Background(), CreateInput{UserID: 7, AgentID: 8, Prompt: "clip"})
    if appErr == nil || appErr.MessageID != "canvas.ai.video.provider_failed" { t.Fatalf("expected provider failure error, got %#v", appErr) }
    if len(repo.updates) != 1 || repo.updates[0].fields["status"] != StatusFailed { t.Fatalf("provider failure must mark task failed, updates=%#v", repo.updates) }
}

func TestCreateRejectsEmptyProviderTaskID(t *testing.T) {
    box := secretbox.New([]byte("12345678901234567890123456789012"))
    repo := &fakeRepository{agent: validCanvasVideoAgent(t, box)}
    engine := &fakeVideoEngine{createTask: &infraai.VideoTask{ID: "  ", Status: "running"}}
    _, appErr := NewService(Dependencies{Repository: repo, Secretbox: box, EngineFactory: &fakeEngineFactory{engine: engine}}).Create(context.Background(), CreateInput{UserID: 7, AgentID: 8, Prompt: "clip"})
    if appErr == nil || appErr.MessageID != "canvas.ai.video.provider_task_invalid" { t.Fatalf("expected provider task invalid error, got %#v", appErr) }
    if len(repo.updates) != 1 || repo.updates[0].fields["status"] != StatusFailed { t.Fatalf("invalid provider task must mark task failed, updates=%#v", repo.updates) }
}

func TestStatusAndContentUseOwnedActiveTaskProviderTaskID(t *testing.T) {
    box := secretbox.New([]byte("12345678901234567890123456789012"))
    engine := &fakeVideoEngine{statusTask: &infraai.VideoTask{ID: "provider-task-1", Status: "completed"}, body: []byte("video"), contentType: "video/mp4"}
    repo := &fakeRepository{agent: validCanvasVideoAgent(t, box), task: &VideoTask{ID: 77, UserID: 7, AgentID: 8, ProviderTaskID: "provider-task-1", Status: StatusRunning, IsDel: IsDelActive}}
    svc := NewService(Dependencies{Repository: repo, Secretbox: box, EngineFactory: &fakeEngineFactory{engine: engine}})
    status, appErr := svc.Status(context.Background(), 7, 77)
    if appErr != nil || status == nil || status.ID != 77 || status.Status != StatusCompleted || engine.statusID != "provider-task-1" { t.Fatalf("status mismatch status=%#v id=%q err=%#v", status, engine.statusID, appErr) }
    body, contentType, appErr := svc.Content(context.Background(), 7, 77)
    if appErr != nil || string(body) != "video" || contentType != "video/mp4" || engine.contentID != "provider-task-1" { t.Fatalf("content mismatch body=%q type=%q id=%q err=%#v", string(body), contentType, engine.contentID, appErr) }
}

func TestStatusRejectsTaskFromDifferentUser(t *testing.T) {
    box := secretbox.New([]byte("12345678901234567890123456789012"))
    repo := &fakeRepository{agent: validCanvasVideoAgent(t, box), task: &VideoTask{ID: 77, UserID: 99, AgentID: 8, ProviderTaskID: "provider-task-1", IsDel: IsDelActive}}
    _, appErr := NewService(Dependencies{Repository: repo, Secretbox: box, EngineFactory: &fakeEngineFactory{engine: &fakeVideoEngine{}}}).Status(context.Background(), 7, 77)
    if appErr == nil || appErr.MessageID != "canvas.ai.video.not_found" { t.Fatalf("expected ownership not_found error, got %#v", appErr) }
}

func TestContentRejectsMissingProviderTaskID(t *testing.T) {
    box := secretbox.New([]byte("12345678901234567890123456789012"))
    repo := &fakeRepository{agent: validCanvasVideoAgent(t, box), task: &VideoTask{ID: 77, UserID: 7, AgentID: 8, ProviderTaskID: " ", IsDel: IsDelActive}}
    _, _, appErr := NewService(Dependencies{Repository: repo, Secretbox: box, EngineFactory: &fakeEngineFactory{engine: &fakeVideoEngine{}}}).Content(context.Background(), 7, 77)
    if appErr == nil || appErr.MessageID != "canvas.ai.video.provider_task_missing" { t.Fatalf("expected missing provider task error, got %#v", appErr) }
}

func TestCreateRejectsNonCanvasVideoScene(t *testing.T) {
    box := secretbox.New([]byte("12345678901234567890123456789012"))
    agent := validCanvasVideoAgent(t, box)
    agent.ScenesJSON = `["chat"]`
    _, appErr := NewService(Dependencies{Repository: &fakeRepository{agent: agent}, Secretbox: box, EngineFactory: &fakeEngineFactory{engine: &fakeVideoEngine{}}}).Create(context.Background(), CreateInput{UserID: 7, AgentID: 8, Prompt: "clip"})
    if appErr == nil || appErr.Code != apperror.CodeBadRequest || appErr.MessageID != "canvas.ai.video.agent_unavailable" { t.Fatalf("expected canvas video scene rejection, got %#v", appErr) }
}
```

- [ ] **Step 2: Verify RED**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/ai/video -count=1
```

Expected: package missing or undefined `NewService` / `Dependencies` / `CreateInput`.

- [ ] **Step 3: Create `dto.go`, `model.go`, `repository.go`, and `service.go`**

Use package name `aivideo`. Move the existing Canvas video runtime data structures into this package with these names:

```go
const SceneCanvasVideoGenerate = "canvas_video_generate"
const StatusPending = "pending"
const StatusRunning = "running"
const StatusCompleted = "completed"
const StatusFailed = "failed"
const StatusCancelled = "cancelled"
const IsDelActive = 2

type HTTPService interface {
    Create(ctx context.Context, input CreateInput) (*CreateResponse, *apperror.Error)
    Status(ctx context.Context, userID int64, id int64) (*StatusResponse, *apperror.Error)
    Content(ctx context.Context, userID int64, id int64) ([]byte, string, *apperror.Error)
}

func (VideoTask) TableName() string { return "canvas_video_tasks" }
```

The service implementation must preserve the existing Canvas video behavior:

```text
Create validates user/agent/prompt
Create loads only canvas_video_generate enabled agent
Create uses agent.ModelID for provider input
Create inserts local pending task before provider call
Create marks local task failed on provider failure or empty provider task id
Status loads owned active task before provider status call
Content loads owned active task before provider download call
Content rejects empty body
```

- [ ] **Step 4: Verify GREEN and commit**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/ai/video -count=1
```

Expected:

```text
ok  	admin_back_go/internal/module/ai/video
```

```powershell
cd E:\admin_go\admin_back_go
git add internal/module/ai/video
git commit -m "feat(ai-video): add canvas video service"
```

---

### Task 2: Add `ai/video/transport/canvas`

**Files:**
- Create: `admin_back_go/internal/module/ai/video/transport/canvas/request.go`
- Create: `admin_back_go/internal/module/ai/video/transport/canvas/handler.go`
- Create: `admin_back_go/internal/module/ai/video/transport/canvas/route.go`
- Create: `admin_back_go/internal/module/ai/video/transport/canvas/handler_test.go`

- [ ] **Step 1: Write RED transport tests**

Create `admin_back_go/internal/module/ai/video/transport/canvas/handler_test.go`:

```go
package canvas

import (
    "context"
    "net/http"
    "net/http/httptest"
    "strings"
    "testing"

    "admin_back_go/internal/middleware"
    aivideomodule "admin_back_go/internal/module/ai/video"
    "admin_back_go/internal/shared/apperror"
    "admin_back_go/internal/shared/enum"

    "github.com/gin-gonic/gin"
)

type fakeCanvasVideoService struct { createInput aivideomodule.CreateInput; statusUserID int64; statusID int64; contentUserID int64; contentID int64; contentType string; contentBody []byte }
func (f *fakeCanvasVideoService) Create(ctx context.Context, input aivideomodule.CreateInput) (*aivideomodule.CreateResponse, *apperror.Error) { f.createInput = input; return &aivideomodule.CreateResponse{ID: 99, Status: aivideomodule.StatusPending}, nil }
func (f *fakeCanvasVideoService) Status(ctx context.Context, userID int64, id int64) (*aivideomodule.StatusResponse, *apperror.Error) { f.statusUserID = userID; f.statusID = id; return &aivideomodule.StatusResponse{ID: id, Status: aivideomodule.StatusRunning}, nil }
func (f *fakeCanvasVideoService) Content(ctx context.Context, userID int64, id int64) ([]byte, string, *apperror.Error) { f.contentUserID = userID; f.contentID = id; if f.contentBody != nil { return f.contentBody, f.contentType, nil }; return []byte("video"), "video/mp4", nil }

func TestCanvasVideoRoutesUseCanvasIdentityAndService(t *testing.T) {
    gin.SetMode(gin.ReleaseMode)
    service := &fakeCanvasVideoService{}
    router := gin.New()
    router.Use(func(c *gin.Context) { c.Set(middleware.ContextAuthIdentity, &middleware.AuthIdentity{UserID: 9, Platform: enum.PlatformCanvas}) })
    RegisterRoutes(router, service)

    recorder := httptest.NewRecorder()
    request := httptest.NewRequest(http.MethodPost, "/api/canvas/v1/ai/videos", strings.NewReader(`{"agent_id":10,"prompt":"clip","duration_seconds":4,"size":"1280x720","resolution_name":"720p","model":"client-model"}`))
    request.Header.Set("Content-Type", "application/json")
    router.ServeHTTP(recorder, request)
    if recorder.Code != http.StatusOK { t.Fatalf("expected status 200, got %d body=%s", recorder.Code, recorder.Body.String()) }
    if service.createInput.UserID != 9 || service.createInput.AgentID != 10 || service.createInput.Prompt != "clip" || service.createInput.DurationSeconds != 4 || service.createInput.ModelID != "client-model" { t.Fatalf("unexpected create input: %#v", service.createInput) }

    recorder = httptest.NewRecorder()
    router.ServeHTTP(recorder, httptest.NewRequest(http.MethodGet, "/api/canvas/v1/ai/videos/99", nil))
    if recorder.Code != http.StatusOK || service.statusUserID != 9 || service.statusID != 99 { t.Fatalf("status route mismatch code=%d body=%s service=%#v", recorder.Code, recorder.Body.String(), service) }

    recorder = httptest.NewRecorder()
    router.ServeHTTP(recorder, httptest.NewRequest(http.MethodGet, "/api/canvas/v1/ai/videos/99/content", nil))
    if recorder.Code != http.StatusOK || service.contentUserID != 9 || service.contentID != 99 || recorder.Body.String() != "video" || recorder.Header().Get("Content-Type") != "video/mp4" { t.Fatalf("content route mismatch code=%d body=%s type=%s service=%#v", recorder.Code, recorder.Body.String(), recorder.Header().Get("Content-Type"), service) }
}

func TestCanvasVideoRoutesRejectWrongPlatformIdentity(t *testing.T) {
    gin.SetMode(gin.ReleaseMode)
    service := &fakeCanvasVideoService{}
    router := gin.New()
    router.Use(func(c *gin.Context) { c.Set(middleware.ContextAuthIdentity, &middleware.AuthIdentity{UserID: 9, Platform: enum.PlatformAdmin}) })
    RegisterRoutes(router, service)
    recorder := httptest.NewRecorder()
    request := httptest.NewRequest(http.MethodPost, "/api/canvas/v1/ai/videos", strings.NewReader(`{"agent_id":10,"prompt":"clip"}`))
    request.Header.Set("Content-Type", "application/json")
    router.ServeHTTP(recorder, request)
    if recorder.Code != http.StatusUnauthorized { t.Fatalf("expected 401, got %d body=%s", recorder.Code, recorder.Body.String()) }
    if service.createInput.UserID != 0 { t.Fatalf("service must not be called for wrong platform: %#v", service.createInput) }
}

func TestCanvasVideoContentFallsBackToOctetStreamForEmptyContentType(t *testing.T) {
    gin.SetMode(gin.ReleaseMode)
    service := &fakeCanvasVideoService{contentBody: []byte("video"), contentType: ""}
    router := gin.New()
    router.Use(func(c *gin.Context) { c.Set(middleware.ContextAuthIdentity, &middleware.AuthIdentity{UserID: 9, Platform: enum.PlatformCanvas}) })
    RegisterRoutes(router, service)
    recorder := httptest.NewRecorder()
    router.ServeHTTP(recorder, httptest.NewRequest(http.MethodGet, "/api/canvas/v1/ai/videos/99/content", nil))
    if recorder.Code != http.StatusOK || recorder.Header().Get("Content-Type") != "application/octet-stream" { t.Fatalf("expected octet-stream fallback, got code=%d type=%s body=%s", recorder.Code, recorder.Header().Get("Content-Type"), recorder.Body.String()) }
}
```

- [ ] **Step 2: Verify RED**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/ai/video/transport/canvas -count=1
```

Expected: `FAIL` with `undefined: RegisterRoutes`.

- [ ] **Step 3: Create transport files**

Create `request.go`:

```go
package canvas

type videoGenerationRequest struct { AgentID int64 `json:"agent_id" binding:"required,gt=0"`; ModelID string `json:"model" binding:"omitempty,max=128"`; Prompt string `json:"prompt" binding:"required,max=20000"`; DurationSeconds int `json:"duration_seconds" binding:"omitempty,gte=0,lte=60"`; Size string `json:"size" binding:"omitempty,max=64"`; ResolutionName string `json:"resolution_name" binding:"omitempty,max=64"` }
```

Create `route.go`:

```go
package canvas

import (
    aivideomodule "admin_back_go/internal/module/ai/video"
    "admin_back_go/internal/shared/validate"
    "github.com/gin-gonic/gin"
)

func RegisterRoutes(router *gin.Engine, service aivideomodule.HTTPService) {
    validate.MustRegister()
    handler := NewHandler(service)
    group := router.Group("/api/canvas/v1/ai/videos")
    group.POST("", handler.VideoGenerations)
    group.GET("/:id", handler.VideoStatus)
    group.GET("/:id/content", handler.VideoContent)
}
```

Create `handler.go` with these exact behaviors:

```text
currentUserID requires AuthIdentity.UserID > 0
currentUserID requires AuthIdentity.Platform == enum.PlatformCanvas
VideoGenerations binds videoGenerationRequest and calls service.Create
VideoStatus parses :id and calls service.Status
VideoContent parses :id and calls service.Content
empty content type falls back to application/octet-stream
nil service returns canvas.ai.video.service_missing
```

Use the same response helpers as `internal/module/ai/chat/transport/canvas/handler.go`, but import `aivideomodule "admin_back_go/internal/module/ai/video"`.

- [ ] **Step 4: Verify GREEN and commit**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/ai/video/transport/canvas -count=1
```

Expected:

```text
ok  	admin_back_go/internal/module/ai/video/transport/canvas
```

```powershell
cd E:\admin_go\admin_back_go
git add internal/module/ai/video/transport/canvas
git commit -m "feat(ai-video): add canvas video transport"
```

---

### Task 3: Register video through `ai/video` and remove video routes from Canvas transport

**Files:**
- Modify: `admin_back_go/internal/server/router.go`
- Modify: `admin_back_go/internal/server/routes_canvas.go`
- Modify: `admin_back_go/internal/server/router_test.go`
- Modify: `admin_back_go/internal/module/canvas/transport/canvas/route.go`
- Modify: `admin_back_go/internal/module/canvas/transport/canvas/request.go`
- Modify: `admin_back_go/internal/module/canvas/transport/canvas/handler.go`
- Modify: `admin_back_go/internal/module/canvas/transport/canvas/handler_test.go`

- [ ] **Step 1: Write RED server router test**

In `admin_back_go/internal/server/router_test.go`, add import:

```go
aivideo "admin_back_go/internal/module/ai/video"
```

Add fake service near other fake AI services:

```go
type fakeRouterAIVideoService struct { createInput aivideo.CreateInput; statusUserID int64; statusID int64; contentUserID int64; contentID int64 }
func (f *fakeRouterAIVideoService) Create(ctx context.Context, input aivideo.CreateInput) (*aivideo.CreateResponse, *apperror.Error) { f.createInput = input; return &aivideo.CreateResponse{ID: 99, Status: aivideo.StatusPending}, nil }
func (f *fakeRouterAIVideoService) Status(ctx context.Context, userID int64, id int64) (*aivideo.StatusResponse, *apperror.Error) { f.statusUserID = userID; f.statusID = id; return &aivideo.StatusResponse{ID: id, Status: aivideo.StatusRunning}, nil }
func (f *fakeRouterAIVideoService) Content(ctx context.Context, userID int64, id int64) ([]byte, string, *apperror.Error) { f.contentUserID = userID; f.contentID = id; return []byte("video"), "video/mp4", nil }
```

Add after `TestRouterInstallsCanvasAIChatRouteFromAIChatService`:

```go
func TestRouterInstallsCanvasAIVideoRoutesFromAIVideoService(t *testing.T) {
    canvasService := &fakeRouterCanvasService{}
    aiVideoService := &fakeRouterAIVideoService{}
    router := newTestRouter(t, Dependencies{
        Authenticator: func(ctx context.Context, input middleware.TokenInput) (*middleware.AuthIdentity, *apperror.Error) { return &middleware.AuthIdentity{UserID: 9, SessionID: 10, Platform: input.Platform}, nil },
        CanvasService: canvasService,
        AiVideoService: aiVideoService,
    })

    recorder := httptest.NewRecorder()
    request := httptest.NewRequest(http.MethodPost, "/api/canvas/v1/ai/videos", strings.NewReader(`{"agent_id":10,"prompt":"clip","duration_seconds":4,"size":"1280x720","resolution_name":"720p","model":"client-model"}`))
    request.Header.Set("Authorization", "Bearer canvas-token")
    request.Header.Set("Content-Type", "application/json")
    router.ServeHTTP(recorder, request)
    if recorder.Code != http.StatusOK { t.Fatalf("expected AI video generation status 200, got %d body=%s", recorder.Code, recorder.Body.String()) }
    if aiVideoService.createInput.UserID != 9 || aiVideoService.createInput.AgentID != 10 || aiVideoService.createInput.Prompt != "clip" || aiVideoService.createInput.DurationSeconds != 4 || aiVideoService.createInput.ModelID != "client-model" { t.Fatalf("expected AI video service Create input from canvas route, got %#v", aiVideoService.createInput) }

    recorder = httptest.NewRecorder()
    request = httptest.NewRequest(http.MethodGet, "/api/canvas/v1/ai/videos/99", nil)
    request.Header.Set("Authorization", "Bearer canvas-token")
    router.ServeHTTP(recorder, request)
    if recorder.Code != http.StatusOK || aiVideoService.statusUserID != 9 || aiVideoService.statusID != 99 { t.Fatalf("expected AI video status route through service, code=%d body=%s service=%#v", recorder.Code, recorder.Body.String(), aiVideoService) }

    recorder = httptest.NewRecorder()
    request = httptest.NewRequest(http.MethodGet, "/api/canvas/v1/ai/videos/99/content", nil)
    request.Header.Set("Authorization", "Bearer canvas-token")
    router.ServeHTTP(recorder, request)
    if recorder.Code != http.StatusOK || aiVideoService.contentUserID != 9 || aiVideoService.contentID != 99 || recorder.Body.String() != "video" { t.Fatalf("expected AI video content route through service, code=%d body=%s service=%#v", recorder.Code, recorder.Body.String(), aiVideoService) }
}
```

- [ ] **Step 2: Verify RED**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/server -run TestRouterInstallsCanvasAIVideoRoutesFromAIVideoService -count=1
```

Expected: build failure for unknown `AiVideoService`, or zero fake service input if the dependency exists but route still belongs to Canvas.

- [ ] **Step 3: Add server dependency and registration**

In `admin_back_go/internal/server/router.go`, add import:

```go
aivideo "admin_back_go/internal/module/ai/video"
```

Add dependency field:

```go
AiVideoService aivideo.HTTPService
```

In `admin_back_go/internal/server/routes_canvas.go`, add import:

```go
aivideocanvas "admin_back_go/internal/module/ai/video/transport/canvas"
```

Register:

```go
func registerCanvasRoutes(router *gin.Engine, deps Dependencies) {
    canvastransport.RegisterRoutes(router, deps.CanvasService)
    aiimagecanvas.RegisterRoutes(router, deps.AiImageService)
    aichatcanvas.RegisterRoutes(router, deps.AiChatService)
    aivideocanvas.RegisterRoutes(router, deps.AiVideoService)
}
```

- [ ] **Step 4: Remove video from Canvas transport**

In `admin_back_go/internal/module/canvas/transport/canvas/route.go`, remove:

```go
group.POST("/ai/videos", handler.VideoGenerations)
group.GET("/ai/videos/:id", handler.VideoStatus)
group.GET("/ai/videos/:id/content", handler.VideoContent)
```

In `request.go`, remove `videoGenerationRequest`.

In `handler.go`, remove video methods and service interface methods:

```go
GenerateVideo
VideoStatus
VideoContent
VideoGenerations
currentUserIDAndRouteID
```

Remove now-unused imports such as `net/http` and `strconv`.

- [ ] **Step 5: Update Canvas transport tests**

In `admin_back_go/internal/module/canvas/transport/canvas/handler_test.go`, remove fake video fields and fake video methods. Delete `TestCanvasVideoRoutesUseAuthenticatedUserAndDoNotLeakProviderConfig`.

Add:

```go
func TestCanvasTransportDoesNotOwnAIVideoRoutes(t *testing.T) {
    gin.SetMode(gin.ReleaseMode)
    service := &fakeCanvasService{}
    router := gin.New()
    router.Use(func(c *gin.Context) { c.Set(middleware.ContextAuthIdentity, &middleware.AuthIdentity{UserID: 9, Platform: "canvas"}) })
    RegisterRoutes(router, service)
    cases := []struct { method string; path string; body string }{
        {http.MethodPost, "/api/canvas/v1/ai/videos", `{"agent_id":10,"prompt":"clip"}`},
        {http.MethodGet, "/api/canvas/v1/ai/videos/99", ""},
        {http.MethodGet, "/api/canvas/v1/ai/videos/99/content", ""},
    }
    for _, tc := range cases {
        t.Run(tc.method+" "+tc.path, func(t *testing.T) {
            var body io.Reader
            if tc.body != "" { body = strings.NewReader(tc.body) }
            recorder := httptest.NewRecorder()
            request := httptest.NewRequest(tc.method, tc.path, body)
            if tc.body != "" { request.Header.Set("Content-Type", "application/json") }
            router.ServeHTTP(recorder, request)
            if recorder.Code != http.StatusNotFound { t.Fatalf("canvas transport must not own %s %s, got code=%d body=%s", tc.method, tc.path, recorder.Code, recorder.Body.String()) }
        })
    }
}
```

Add `io` import for `io.Reader`.

- [ ] **Step 6: Update server fake Canvas service**

In `admin_back_go/internal/server/router_test.go`, remove `videoInput canvasmodule.VideoGenerationInput` from `fakeRouterCanvasService`, and delete its fake `GenerateVideo`, `VideoStatus`, and `VideoContent` methods.

- [ ] **Step 7: Verify GREEN and commit**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/server ./internal/module/canvas/transport/canvas ./internal/module/ai/video/transport/canvas -count=1
```

Expected:

```text
ok  	admin_back_go/internal/server
ok  	admin_back_go/internal/module/canvas/transport/canvas
ok  	admin_back_go/internal/module/ai/video/transport/canvas
```

```powershell
cd E:\admin_go\admin_back_go
git add internal/server/router.go internal/server/routes_canvas.go internal/server/router_test.go internal/module/canvas/transport/canvas internal/module/ai/video/transport/canvas
git commit -m "refactor(canvas): route video through ai video transport"
```

---

### Task 4: Remove Canvas video runtime ownership and add architecture guards

**Files:**
- Modify: `admin_back_go/internal/architecture/platform_route_line_test.go`
- Modify: `admin_back_go/internal/bootstrap/app.go`
- Modify: `admin_back_go/internal/module/canvas/dto.go`
- Modify: `admin_back_go/internal/module/canvas/model.go`
- Modify: `admin_back_go/internal/module/canvas/service.go`
- Modify: `admin_back_go/internal/module/canvas/service_test.go`
- Delete: `admin_back_go/internal/module/canvas/video_runtime.go`
- Delete: `admin_back_go/internal/module/canvas/video_runtime_test.go`
- Delete: `admin_back_go/internal/module/canvas/video_repository.go`

- [ ] **Step 1: Write RED architecture guards**

In `admin_back_go/internal/architecture/platform_route_line_test.go`, add:

```go
func TestCanvasAIVideoRoutesOwnedByAIVideoTransport(t *testing.T) {
    root := backendRoot(t)
    canvasRoute := readRouteLineSource(t, root, "internal/module/canvas/transport/canvas/route.go")
    mustNotContainRouteLine(t, canvasRoute, `"/ai/videos`)
    aiVideoCanvasRoute := filepath.Join(root, "internal", "module", "ai", "video", "transport", "canvas", "route.go")
    if _, err := os.Stat(aiVideoCanvasRoute); err != nil { t.Fatalf("expected ai video canvas route transport to exist: %v", err) }
    routesCanvas := readRouteLineSource(t, root, "internal/server/routes_canvas.go")
    mustContainRouteLine(t, routesCanvas, `aivideocanvas "admin_back_go/internal/module/ai/video/transport/canvas"`)
    mustContainRouteLine(t, routesCanvas, `aivideocanvas.RegisterRoutes(router, deps.AiVideoService)`)
}

func TestAIVideoCanvasTransportDoesNotImportCanvasModule(t *testing.T) {
    root := backendRoot(t)
    transportRoot := filepath.Join(root, "internal", "module", "ai", "video", "transport", "canvas")
    var offenders []string
    err := filepath.WalkDir(transportRoot, func(path string, entry os.DirEntry, walkErr error) error {
        if walkErr != nil { return walkErr }
        if entry.IsDir() || filepath.Ext(path) != ".go" || strings.HasSuffix(path, "_test.go") { return nil }
        body, err := os.ReadFile(path)
        if err != nil { return err }
        if strings.Contains(string(body), `admin_back_go/internal/module/canvas`) { rel, _ := filepath.Rel(root, path); offenders = append(offenders, filepath.ToSlash(rel)) }
        return nil
    })
    if err != nil { t.Fatalf("walk ai video canvas transport: %v", err) }
    if len(offenders) > 0 { t.Fatalf("ai/video canvas transport must not import canvas module; offenders=%v", offenders) }
}

func TestCanvasModuleProductionCodeDoesNotOwnAIVideoRuntime(t *testing.T) {
    root := backendRoot(t)
    canvasRoot := filepath.Join(root, "internal", "module", "canvas")
    forbidden := []string{"GenerateVideo(", "VideoGenerationInput", "VideoGenerationResponse", "VideoStatusResponse", "VideoRuntimeService", "NewVideoRuntimeService", "VideoGormRepository", "NewVideoGormRepository", "AgentForVideoRuntime", "VideoEngineFactory", "VideoRepository", "VideoTask) TableName"}
    var offenders []string
    err := filepath.WalkDir(canvasRoot, func(path string, entry os.DirEntry, walkErr error) error {
        if walkErr != nil { return walkErr }
        if entry.IsDir() || filepath.Ext(path) != ".go" || strings.HasSuffix(path, "_test.go") { return nil }
        body, err := os.ReadFile(path)
        if err != nil { return err }
        text := string(body)
        for _, token := range forbidden { if strings.Contains(text, token) { rel, _ := filepath.Rel(root, path); offenders = append(offenders, filepath.ToSlash(rel)+" contains "+token) } }
        return nil
    })
    if err != nil { t.Fatalf("walk canvas module: %v", err) }
    if len(offenders) > 0 { t.Fatalf("canvas module production code must not own AI video runtime:\n  %s", strings.Join(offenders, "\n  ")) }
}
```

- [ ] **Step 2: Verify RED**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture -run 'TestCanvasAIVideoRoutesOwnedByAIVideoTransport|TestAIVideoCanvasTransportDoesNotImportCanvasModule|TestCanvasModuleProductionCodeDoesNotOwnAIVideoRuntime' -count=1
```

Expected before deletion: `FAIL` because Canvas module still owns video runtime tokens.

- [ ] **Step 3: Remove Canvas service video ownership**

In `admin_back_go/internal/module/canvas/service.go`, change:

```go
type SettingsDependencies struct { AuthPolicy AuthPolicyService; Video VideoRuntime }
```

to:

```go
type SettingsDependencies struct { AuthPolicy AuthPolicyService }
```

Delete:

```go
GenerateVideo
VideoStatus
VideoContent
canvasVideoTask
normalizeVideoStatus
```

Remove unused imports.

- [ ] **Step 4: Remove Canvas video DTOs and model**

In `admin_back_go/internal/module/canvas/dto.go`, delete all video request/runtime DTOs:

```text
VideoGenerationInput
VideoGenerationResponse
VideoStatusResponse
VideoRuntime
VideoAgentRuntime
VideoRepository
VideoEngineFactory
VideoEngineConfig
VideoCreateInput
VideoCreateResult
VideoStatusInput
VideoContentInput
VideoProviderStatus
Secretbox
```

Keep `CanvasAgentGroups.Video` because settings still returns `agents.video`.

In `admin_back_go/internal/module/canvas/model.go`, delete `VideoTask` and its `TableName`; keep `Prompt` and `Asset`.

- [ ] **Step 5: Remove Canvas video tests and runtime files**

In `admin_back_go/internal/module/canvas/service_test.go`, delete:

```text
TestServiceGenerateVideoCreatesFreeCanvasTask
TestServiceVideoStatusUsesCanvasVideoTaskOwnership
TestServiceVideoContentStreamsProviderContent
fakeCanvasVideoRuntime and its methods
```

Run:

```powershell
cd E:\admin_go\admin_back_go
Remove-Item -LiteralPath .\internal\module\canvas\video_runtime.go
Remove-Item -LiteralPath .\internal\module\canvas\video_runtime_test.go
Remove-Item -LiteralPath .\internal\module\canvas\video_repository.go
```

- [ ] **Step 6: Update bootstrap**

In `admin_back_go/internal/bootstrap/app.go`, add import:

```go
aivideo "admin_back_go/internal/module/ai/video"
```

Replace Canvas video runtime construction with AI video service construction:

```go
aiVideoService := aivideo.NewService(aivideo.Dependencies{
    Repository:    aivideo.NewGormRepository(resources.DB),
    Secretbox:     secretBox,
    EngineFactory: aiVideoEngineFactory{},
})
canvasService := canvasmodule.NewServiceWithSettings(canvasmodule.NewGormRepository(resources.DB), canvasmodule.SettingsDependencies{
    AuthPolicy: authPlatformService,
})
```

Add to `server.Dependencies` construction:

```go
AiVideoService: aiVideoService,
```

Rename the bootstrap video engine factory to AI video types:

```go
type aiVideoEngineFactory struct{}
func (aiVideoEngineFactory) NewVideoEngine(ctx context.Context, input aivideo.EngineConfig) (infraai.VideoEngine, error) { ... }
```

The method body should keep the old OpenAI-compatible video engine construction.

- [ ] **Step 7: Verify GREEN and commit**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture ./internal/module/ai/video ./internal/module/ai/video/transport/canvas ./internal/module/canvas ./internal/module/canvas/transport/canvas ./internal/server -count=1
```

Expected all listed packages return `ok`.

```powershell
cd E:\admin_go\admin_back_go
git add internal/architecture/platform_route_line_test.go internal/bootstrap/app.go internal/module/canvas/dto.go internal/module/canvas/model.go internal/module/canvas/service.go internal/module/canvas/service_test.go internal/module/canvas/video_runtime.go internal/module/canvas/video_runtime_test.go internal/module/canvas/video_repository.go
git commit -m "refactor(canvas): remove video runtime ownership"
```

---

### Task 5: Final verification

**Files:** Verify only unless a command exposes a real mismatch.

- [ ] **Step 1: Run targeted tests**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture ./internal/module/ai/video ./internal/module/ai/video/transport/canvas ./internal/module/ai/chat ./internal/module/ai/chat/transport/canvas ./internal/module/ai/image/transport/canvas ./internal/module/canvas ./internal/module/canvas/transport/canvas ./internal/server -count=1
```

Expected all packages return `ok`.

- [ ] **Step 2: Verify route ownership**

```powershell
cd E:\admin_go\admin_back_go
rg -n 'ai/videos|aivideocanvas|aichatcanvas|aiimagecanvas|RegisterRoutes\(router, deps\.(CanvasService|AiImageService|AiChatService|AiVideoService)' .\internal\module\canvas\transport\canvas\route.go .\internal\module\ai\video\transport\canvas\route.go .\internal\module\ai\chat\transport\canvas\route.go .\internal\module\ai\image\transport\canvas\route.go .\internal\server\routes_canvas.go
```

Expected decisive lines:

```text
internal/module/ai/video/transport/canvas/route.go: group := router.Group("/api/canvas/v1/ai/videos")
internal/server/routes_canvas.go: aivideocanvas.RegisterRoutes(router, deps.AiVideoService)
```

`internal/module/canvas/transport/canvas/route.go` must not contain `ai/videos`.

- [ ] **Step 3: Verify Canvas no longer owns AI video runtime**

```powershell
cd E:\admin_go\admin_back_go
rg -n 'GenerateVideo|VideoGenerationInput|VideoGenerationResponse|VideoStatusResponse|VideoRuntimeService|NewVideoRuntimeService|VideoGormRepository|NewVideoGormRepository|AgentForVideoRuntime|VideoEngineFactory|VideoRepository|VideoTask\) TableName' .\internal\module\canvas -g '!**/*_test.go'
```

Expected: no output.

- [ ] **Step 4: Verify `canvas_video_tasks` remains owned by ai/video**

```powershell
cd E:\admin_go\admin_back_go
rg -n 'canvas_video_tasks|func \(VideoTask\) TableName' .\internal\module\ai\video .\internal\module\canvas -g '!**/*_test.go'
```

Expected decisive line:

```text
internal/module/ai/video/model.go:func (VideoTask) TableName() string { return "canvas_video_tasks" }
```

No `canvas_video_tasks` ownership should remain in `internal/module/canvas` production code.

- [ ] **Step 5: Run governance**

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected:

```text
PASS: no blocking governance violations found.
```

- [ ] **Step 6: Inspect working trees**

```powershell
cd E:\admin_go
git status --short
cd E:\admin_go\admin_back_go
git status --short --branch
```

Expected: root clean, backend clean on the implementation branch or on `master` after merge.

## Completion criteria

```text
POST /api/canvas/v1/ai/videos still returns id/status
GET /api/canvas/v1/ai/videos/:id still returns id/status
GET /api/canvas/v1/ai/videos/:id/content still streams provider content
server registers aivideocanvas.RegisterRoutes(router, deps.AiVideoService)
canvas transport no longer registers /ai/videos
ai/video service owns create/status/content
ai/video accepts only canvas_video_generate agents
ai/video uses agent model_id instead of client model override
ai/video writes and updates canvas_video_tasks through ai/video repository
canvas_video_tasks table name is unchanged
canvas module production code no longer owns video runtime/repository/model
architecture guards prevent video route/runtime ownership from returning to canvas
final targeted Go tests pass
root governance checks pass
```
