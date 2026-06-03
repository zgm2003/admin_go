# Canvas AI Image Transport Ownership Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move Canvas image generation/edit/status routes from `internal/module/canvas/transport/canvas` to `internal/module/ai/image/transport/canvas` without changing any external `/api/canvas/v1/ai/images/*` URL or frontend contract.

**Architecture:** Treat `canvas` as a platform and `ai/image` as the image-generation capability owner. The new Canvas image transport is a thin HTTP adapter over the existing `aiimage.Service`; `canvas` keeps only `/settings`, `/prompts`, `/assets`, plus existing chat/video until separate follow-up specs migrate them.

**Tech Stack:** Go 1.26, Gin, existing `apperror`/`response` envelope, existing `middleware.AuthIdentity`, existing `aiimage.HTTPService`, Vitest/Next checks for frontend contract preservation.

---

## Spec

Primary design spec:

```text
docs/superpowers/specs/2026-06-03-canvas-ai-transport-ownership-design.md
```

This implementation plan intentionally covers only Phase 1 from the spec: `ai/image/transport/canvas`. Do not migrate chat or video in this plan.

## File Structure

Create:

```text
admin_back_go/internal/module/ai/image/transport/canvas/route.go
admin_back_go/internal/module/ai/image/transport/canvas/request.go
admin_back_go/internal/module/ai/image/transport/canvas/handler.go
admin_back_go/internal/module/ai/image/transport/canvas/handler_test.go
```

Modify:

```text
admin_back_go/internal/architecture/platform_route_line_test.go
admin_back_go/internal/server/routes_canvas.go
admin_back_go/internal/server/router_test.go
admin_back_go/internal/module/canvas/transport/canvas/route.go
admin_back_go/internal/module/canvas/transport/canvas/request.go
admin_back_go/internal/module/canvas/transport/canvas/handler.go
admin_back_go/internal/module/canvas/transport/canvas/handler_test.go
admin_back_go/internal/module/canvas/dto.go
admin_back_go/internal/module/canvas/service.go
admin_back_go/internal/module/canvas/service_test.go
admin_back_go/internal/bootstrap/app.go
docs/contracts/admin-api-v1.md
```

Do not modify:

```text
canvas_front_next/src/services/api/image.ts
canvas_front_next/src/services/api/image.test.ts
```

Those frontend paths are verification targets only. If they need URL changes, the backend migration broke userspace.

---

### Task 1: Add RED architecture ownership guards

**Files:**
- Modify: `admin_back_go/internal/architecture/platform_route_line_test.go`

- [ ] **Step 1: Add architecture tests that describe the desired ownership**

Append these tests to `admin_back_go/internal/architecture/platform_route_line_test.go`:

```go
func TestCanvasAIImageRoutesOwnedByAIImageTransport(t *testing.T) {
	root := backendRoot(t)

	canvasRoute := readRouteLineSource(t, root, "internal/module/canvas/transport/canvas/route.go")
	mustNotContainRouteLine(t, canvasRoute, `"/ai/images`)

	aiImageCanvasRoute := filepath.Join(root, "internal", "module", "ai", "image", "transport", "canvas", "route.go")
	if _, err := os.Stat(aiImageCanvasRoute); err != nil {
		t.Fatalf("expected ai image canvas route transport to exist: %v", err)
	}

	routesCanvas := readRouteLineSource(t, root, "internal/server/routes_canvas.go")
	mustContainRouteLine(t, routesCanvas, `aiimagecanvas "admin_back_go/internal/module/ai/image/transport/canvas"`)
	mustContainRouteLine(t, routesCanvas, `aiimagecanvas.RegisterRoutes(router, deps.AiImageService)`)
}

func TestCanvasModuleProductionCodeDoesNotImportAIImage(t *testing.T) {
	root := backendRoot(t)
	canvasRoot := filepath.Join(root, "internal", "module", "canvas")
	var offenders []string

	err := filepath.WalkDir(canvasRoot, func(path string, entry os.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if entry.IsDir() || filepath.Ext(path) != ".go" || strings.HasSuffix(path, "_test.go") {
			return nil
		}
		body, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		if strings.Contains(string(body), `admin_back_go/internal/module/ai/image`) {
			rel, _ := filepath.Rel(root, path)
			offenders = append(offenders, filepath.ToSlash(rel))
		}
		return nil
	})
	if err != nil {
		t.Fatalf("walk canvas module: %v", err)
	}
	if len(offenders) > 0 {
		t.Fatalf("canvas module production code must not import ai/image; offenders=%v", offenders)
	}
}
```

- [ ] **Step 2: Run the architecture tests and confirm they fail for the right reason**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture -run "TestCanvasAIImageRoutesOwnedByAIImageTransport|TestCanvasModuleProductionCodeDoesNotImportAIImage" -count=1
```

Expected:

```text
FAIL: canvas route still contains "/ai/images"
FAIL: internal/module/ai/image/transport/canvas/route.go does not exist
FAIL: canvas module production code imports admin_back_go/internal/module/ai/image
```

- [ ] **Step 3: Commit the RED architecture guard**

```powershell
git add internal/architecture/platform_route_line_test.go
git commit -m "test(canvas): guard ai image canvas route ownership"
```

---

### Task 2: Add RED tests for the new AI image Canvas transport

**Files:**
- Create: `admin_back_go/internal/module/ai/image/transport/canvas/handler_test.go`

- [ ] **Step 1: Create the new transport test file**

Create `admin_back_go/internal/module/ai/image/transport/canvas/handler_test.go`:

```go
package canvas

import (
	"bytes"
	"context"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"admin_back_go/internal/middleware"
	aiimagemodule "admin_back_go/internal/module/ai/image"
	"admin_back_go/internal/shared/apperror"
	"admin_back_go/internal/shared/enum"

	"github.com/gin-gonic/gin"
)

type fakeCanvasImageService struct {
	createInput aiimagemodule.CreateInput
	uploadInput aiimagemodule.CreateWithUploadedAssetsInput
	detailUserID uint64
	detailTaskID uint64
}

func (f *fakeCanvasImageService) PageInit(ctx context.Context) (*aiimagemodule.PageInitResponse, *apperror.Error) {
	return nil, apperror.InternalKey("unexpected", nil, "unexpected")
}

func (f *fakeCanvasImageService) List(ctx context.Context, userID uint64, query aiimagemodule.ListQuery) (*aiimagemodule.ListResponse, *apperror.Error) {
	return nil, apperror.InternalKey("unexpected", nil, "unexpected")
}

func (f *fakeCanvasImageService) Detail(ctx context.Context, userID uint64, taskID uint64) (*aiimagemodule.DetailResponse, *apperror.Error) {
	f.detailUserID = userID
	f.detailTaskID = taskID
	return &aiimagemodule.DetailResponse{
		Task: aiimagemodule.TaskDTO{ID: taskID, Status: aiimagemodule.StatusSuccess},
		Outputs: []aiimagemodule.AssetDTO{{
			ID:         700,
			StorageURL: "https://example.test/cat.png",
			MimeType:   "image/png",
			SourceType: aiimagemodule.SourceTypeGenerated,
		}},
	}, nil
}

func (f *fakeCanvasImageService) RegisterAsset(ctx context.Context, input aiimagemodule.RegisterAssetInput) (*aiimagemodule.AssetDTO, *apperror.Error) {
	return nil, apperror.InternalKey("unexpected", nil, "unexpected")
}

func (f *fakeCanvasImageService) Create(ctx context.Context, input aiimagemodule.CreateInput) (*aiimagemodule.CreateTaskResponse, *apperror.Error) {
	f.createInput = input
	return &aiimagemodule.CreateTaskResponse{Task: aiimagemodule.TaskDTO{ID: 88, Status: aiimagemodule.StatusPending}}, nil
}

func (f *fakeCanvasImageService) CreateWithUploadedAssets(ctx context.Context, input aiimagemodule.CreateWithUploadedAssetsInput) (*aiimagemodule.CreateTaskResponse, *apperror.Error) {
	f.uploadInput = input
	return &aiimagemodule.CreateTaskResponse{Task: aiimagemodule.TaskDTO{ID: 89, Status: aiimagemodule.StatusPending}}, nil
}

func (f *fakeCanvasImageService) Favorite(ctx context.Context, input aiimagemodule.FavoriteInput) (*aiimagemodule.TaskDTO, *apperror.Error) {
	return nil, apperror.InternalKey("unexpected", nil, "unexpected")
}

func (f *fakeCanvasImageService) Delete(ctx context.Context, userID uint64, taskID uint64) *apperror.Error {
	return apperror.InternalKey("unexpected", nil, "unexpected")
}

func TestCanvasImageGenerationCreatesCanvasPlatformTask(t *testing.T) {
	gin.SetMode(gin.ReleaseMode)
	service := &fakeCanvasImageService{}
	router := gin.New()
	router.Use(func(c *gin.Context) {
		c.Set(middleware.ContextAuthIdentity, &middleware.AuthIdentity{UserID: 9, Platform: enum.PlatformCanvas})
	})
	RegisterRoutes(router, service)

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodPost, "/api/canvas/v1/ai/images/generations", strings.NewReader(`{"agent_id":8,"prompt":"cat","n":2}`))
	request.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d body=%s", recorder.Code, recorder.Body.String())
	}
	if service.createInput.UserID != 9 || service.createInput.AgentID != 8 || service.createInput.Platform != enum.PlatformCanvas || service.createInput.N != 2 {
		t.Fatalf("unexpected create input: %#v", service.createInput)
	}
	for _, want := range []string{`"task_id":88`, `"status":"pending"`} {
		if !strings.Contains(recorder.Body.String(), want) {
			t.Fatalf("response missing %s: %s", want, recorder.Body.String())
		}
	}
}

func TestCanvasImageEditUploadsReferencesAndCreatesCanvasPlatformTask(t *testing.T) {
	gin.SetMode(gin.ReleaseMode)
	service := &fakeCanvasImageService{}
	router := gin.New()
	router.Use(func(c *gin.Context) {
		c.Set(middleware.ContextAuthIdentity, &middleware.AuthIdentity{UserID: 9, Platform: enum.PlatformCanvas})
	})
	RegisterRoutes(router, service)

	var body bytes.Buffer
	writer := multipart.NewWriter(&body)
	_ = writer.WriteField("agent_id", "8")
	_ = writer.WriteField("prompt", "use this reference")
	_ = writer.WriteField("n", "1")
	file, err := writer.CreateFormFile("image", "reference.png")
	if err != nil {
		t.Fatalf("create multipart file: %v", err)
	}
	if _, err := file.Write([]byte{0x89, 'P', 'N', 'G', '\r', '\n', 0x1a, '\n'}); err != nil {
		t.Fatalf("write multipart file: %v", err)
	}
	if err := writer.Close(); err != nil {
		t.Fatalf("close multipart writer: %v", err)
	}

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodPost, "/api/canvas/v1/ai/images/edits", &body)
	request.Header.Set("Content-Type", writer.FormDataContentType())
	router.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d body=%s", recorder.Code, recorder.Body.String())
	}
	if service.uploadInput.UserID != 9 || service.uploadInput.AgentID != 8 || service.uploadInput.Platform != enum.PlatformCanvas || service.uploadInput.Prompt != "use this reference" {
		t.Fatalf("unexpected upload input: %#v", service.uploadInput)
	}
	if len(service.uploadInput.Assets) != 1 || service.uploadInput.Assets[0].FileName != "reference.png" || len(service.uploadInput.Assets[0].Body) == 0 {
		t.Fatalf("expected uploaded reference image, got %#v", service.uploadInput.Assets)
	}
	if !strings.Contains(recorder.Body.String(), `"task_id":89`) {
		t.Fatalf("response missing task id: %s", recorder.Body.String())
	}
}

func TestCanvasImageStatusReturnsTaskAndOutputs(t *testing.T) {
	gin.SetMode(gin.ReleaseMode)
	service := &fakeCanvasImageService{}
	router := gin.New()
	router.Use(func(c *gin.Context) {
		c.Set(middleware.ContextAuthIdentity, &middleware.AuthIdentity{UserID: 9, Platform: enum.PlatformCanvas})
	})
	RegisterRoutes(router, service)

	recorder := httptest.NewRecorder()
	router.ServeHTTP(recorder, httptest.NewRequest(http.MethodGet, "/api/canvas/v1/ai/images/88", nil))

	if recorder.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d body=%s", recorder.Code, recorder.Body.String())
	}
	if service.detailUserID != 9 || service.detailTaskID != 88 {
		t.Fatalf("unexpected detail lookup user=%d task=%d", service.detailUserID, service.detailTaskID)
	}
	for _, want := range []string{`"task"`, `"outputs"`, `"storage_url":"https://example.test/cat.png"`} {
		if !strings.Contains(recorder.Body.String(), want) {
			t.Fatalf("response missing %s: %s", want, recorder.Body.String())
		}
	}
}
```

- [ ] **Step 2: Run the new transport tests and confirm they fail because the transport does not exist**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/ai/image/transport/canvas -count=1
```

Expected:

```text
FAIL: package admin_back_go/internal/module/ai/image/transport/canvas has test code but RegisterRoutes is undefined
```

- [ ] **Step 3: Commit the RED transport tests**

```powershell
git add internal/module/ai/image/transport/canvas/handler_test.go
git commit -m "test(aiimage): specify canvas image transport"
```

---

### Task 3: Implement `ai/image/transport/canvas`

**Files:**
- Create: `admin_back_go/internal/module/ai/image/transport/canvas/route.go`
- Create: `admin_back_go/internal/module/ai/image/transport/canvas/request.go`
- Create: `admin_back_go/internal/module/ai/image/transport/canvas/handler.go`

- [ ] **Step 1: Create the route registration**

Create `admin_back_go/internal/module/ai/image/transport/canvas/route.go`:

```go
package canvas

import (
	aiimagemodule "admin_back_go/internal/module/ai/image"
	"admin_back_go/internal/shared/validate"

	"github.com/gin-gonic/gin"
)

func RegisterRoutes(router *gin.Engine, service aiimagemodule.HTTPService) {
	validate.MustRegister()
	handler := NewHandler(service)
	group := router.Group("/api/canvas/v1/ai/images")
	group.POST("/generations", handler.Generations)
	group.POST("/edits", handler.Edits)
	group.GET("/:id", handler.Status)
}
```

- [ ] **Step 2: Create the Canvas image request DTOs**

Create `admin_back_go/internal/module/ai/image/transport/canvas/request.go`:

```go
package canvas

type imageGenerationRequest struct {
	AgentID           uint64   `json:"agent_id" form:"agent_id" binding:"required,gt=0"`
	Prompt            string   `json:"prompt" form:"prompt" binding:"required,max=20000"`
	Size              string   `json:"size" form:"size" binding:"omitempty,max=32"`
	Quality           string   `json:"quality" form:"quality" binding:"omitempty,max=16"`
	OutputFormat      string   `json:"output_format" form:"output_format" binding:"omitempty,max=16"`
	OutputCompression *int     `json:"output_compression" form:"output_compression" binding:"omitempty,gte=0,lte=100"`
	Moderation        string   `json:"moderation" form:"moderation" binding:"omitempty,max=16"`
	N                 int      `json:"n" form:"n" binding:"omitempty,min=1,max=15"`
	InputAssetIDs     []uint64 `json:"input_asset_ids" form:"input_asset_ids" binding:"omitempty,dive,gt=0"`
	MaskAssetID       uint64   `json:"mask_asset_id" form:"mask_asset_id" binding:"omitempty,gt=0"`
	MaskTargetAssetID uint64   `json:"mask_target_asset_id" form:"mask_target_asset_id" binding:"omitempty,gt=0"`
}

type imageGenerationResponse struct {
	TaskID uint64 `json:"task_id"`
	Status string `json:"status"`
}
```

- [ ] **Step 3: Create the handler**

Create `admin_back_go/internal/module/ai/image/transport/canvas/handler.go`:

```go
package canvas

import (
	"context"
	"io"
	"net/http"
	"strconv"
	"strings"

	"admin_back_go/internal/middleware"
	aiimagemodule "admin_back_go/internal/module/ai/image"
	"admin_back_go/internal/shared/apperror"
	"admin_back_go/internal/shared/enum"
	"admin_back_go/internal/shared/response"

	"github.com/gin-gonic/gin"
)

const (
	maxImageEditFiles     = 10
	maxImageEditFileBytes = 20 << 20
	maxImageEditBodyBytes = maxImageEditFiles*maxImageEditFileBytes + 1<<20
)

type Handler struct{ service aiimagemodule.HTTPService }

func NewHandler(service aiimagemodule.HTTPService) *Handler { return &Handler{service: service} }

func (h *Handler) Generations(c *gin.Context) {
	userID, ok := currentUserID(c)
	if !ok {
		return
	}
	var req imageGenerationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, apperror.BadRequestKey("canvas.ai.image.request.invalid", nil, "图片生成参数错误"))
		return
	}
	result, appErr := h.requireService().Create(c.Request.Context(), createInput(userID, req))
	writeCreateResult(c, result, appErr)
}

func (h *Handler) Edits(c *gin.Context) {
	userID, ok := currentUserID(c)
	if !ok {
		return
	}
	req, uploads, ok := bindImageEditRequest(c)
	if !ok {
		return
	}
	result, appErr := h.requireService().CreateWithUploadedAssets(c.Request.Context(), aiimagemodule.CreateWithUploadedAssetsInput{
		CreateInput: createInput(userID, req),
		Assets:      uploads,
	})
	writeCreateResult(c, result, appErr)
}

func (h *Handler) Status(c *gin.Context) {
	userID, ok := currentUserID(c)
	if !ok {
		return
	}
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil || id == 0 {
		response.Error(c, apperror.BadRequestKey("canvas.ai.image.id.invalid", nil, "图片任务ID无效"))
		return
	}
	result, appErr := h.requireService().Detail(c.Request.Context(), userID, id)
	writeResult(c, result, appErr)
}

func (h *Handler) requireService() aiimagemodule.HTTPService {
	if h == nil || h.service == nil {
		return nilHTTPService{}
	}
	return h.service
}

func createInput(userID uint64, req imageGenerationRequest) aiimagemodule.CreateInput {
	return aiimagemodule.CreateInput{
		UserID:            userID,
		AgentID:           req.AgentID,
		Platform:          enum.PlatformCanvas,
		Prompt:            req.Prompt,
		Size:              req.Size,
		Quality:           req.Quality,
		OutputFormat:      req.OutputFormat,
		OutputCompression: req.OutputCompression,
		Moderation:        req.Moderation,
		N:                 req.N,
		InputAssetIDs:     req.InputAssetIDs,
		MaskAssetID:       req.MaskAssetID,
		MaskTargetAssetID: req.MaskTargetAssetID,
	}
}

func currentUserID(c *gin.Context) (uint64, bool) {
	identity := middleware.GetAuthIdentity(c)
	if identity == nil || identity.UserID <= 0 {
		response.Error(c, apperror.UnauthorizedKey("auth.token.invalid_or_expired", nil, "Token无效或已过期"))
		return 0, false
	}
	return uint64(identity.UserID), true
}

func writeCreateResult(c *gin.Context, result *aiimagemodule.CreateTaskResponse, appErr *apperror.Error) {
	if appErr != nil {
		response.Error(c, appErr)
		return
	}
	if result == nil || result.Task.ID == 0 {
		response.Error(c, apperror.InternalKey("canvas.ai.image.result_invalid", nil, "Canvas图片生成结果无效"))
		return
	}
	response.OK(c, imageGenerationResponse{TaskID: result.Task.ID, Status: result.Task.Status})
}

func writeResult(c *gin.Context, result any, appErr *apperror.Error) {
	if appErr != nil {
		response.Error(c, appErr)
		return
	}
	response.OK(c, result)
}

func bindImageEditRequest(c *gin.Context) (imageGenerationRequest, []aiimagemodule.UploadedAssetInput, bool) {
	c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, maxImageEditBodyBytes)
	if err := c.Request.ParseMultipartForm(maxImageEditFileBytes); err != nil {
		response.Error(c, apperror.BadRequestKey("canvas.ai.image.request.invalid", nil, "图片生成参数错误"))
		return imageGenerationRequest{}, nil, false
	}
	var req imageGenerationRequest
	if err := c.ShouldBind(&req); err != nil {
		response.Error(c, apperror.BadRequestKey("canvas.ai.image.request.invalid", nil, "图片生成参数错误"))
		return imageGenerationRequest{}, nil, false
	}
	form := c.Request.MultipartForm
	if form == nil || len(form.File["image"]) == 0 {
		response.Error(c, apperror.BadRequestKey("canvas.ai.image.request.invalid", nil, "图片生成参数错误"))
		return imageGenerationRequest{}, nil, false
	}
	files := form.File["image"]
	if len(files) > maxImageEditFiles {
		response.Error(c, apperror.BadRequestKey("canvas.ai.image.request.invalid", nil, "图片生成参数错误"))
		return imageGenerationRequest{}, nil, false
	}
	uploads := make([]aiimagemodule.UploadedAssetInput, 0, len(files))
	for _, header := range files {
		file, err := header.Open()
		if err != nil {
			response.Error(c, apperror.BadRequestKey("canvas.ai.image.request.invalid", nil, "图片生成参数错误"))
			return imageGenerationRequest{}, nil, false
		}
		body, readErr := io.ReadAll(io.LimitReader(file, maxImageEditFileBytes+1))
		closeErr := file.Close()
		if readErr != nil || closeErr != nil || len(body) == 0 || len(body) > maxImageEditFileBytes {
			response.Error(c, apperror.BadRequestKey("canvas.ai.image.request.invalid", nil, "图片生成参数错误"))
			return imageGenerationRequest{}, nil, false
		}
		mimeType := strings.TrimSpace(header.Header.Get("Content-Type"))
		if mimeType == "" {
			mimeType = http.DetectContentType(body)
		}
		uploads = append(uploads, aiimagemodule.UploadedAssetInput{FileName: header.Filename, MimeType: mimeType, Body: body})
	}
	return req, uploads, true
}

type nilHTTPService struct{}

func (nilHTTPService) PageInit(ctx context.Context) (*aiimagemodule.PageInitResponse, *apperror.Error) {
	return nil, apperror.InternalKey("aiimage.service_missing", nil, "AI图片服务未配置")
}
func (nilHTTPService) List(ctx context.Context, userID uint64, query aiimagemodule.ListQuery) (*aiimagemodule.ListResponse, *apperror.Error) {
	return nil, apperror.InternalKey("aiimage.service_missing", nil, "AI图片服务未配置")
}
func (nilHTTPService) Detail(ctx context.Context, userID uint64, taskID uint64) (*aiimagemodule.DetailResponse, *apperror.Error) {
	return nil, apperror.InternalKey("aiimage.service_missing", nil, "AI图片服务未配置")
}
func (nilHTTPService) RegisterAsset(ctx context.Context, input aiimagemodule.RegisterAssetInput) (*aiimagemodule.AssetDTO, *apperror.Error) {
	return nil, apperror.InternalKey("aiimage.service_missing", nil, "AI图片服务未配置")
}
func (nilHTTPService) Create(ctx context.Context, input aiimagemodule.CreateInput) (*aiimagemodule.CreateTaskResponse, *apperror.Error) {
	return nil, apperror.InternalKey("aiimage.service_missing", nil, "AI图片服务未配置")
}
func (nilHTTPService) CreateWithUploadedAssets(ctx context.Context, input aiimagemodule.CreateWithUploadedAssetsInput) (*aiimagemodule.CreateTaskResponse, *apperror.Error) {
	return nil, apperror.InternalKey("aiimage.service_missing", nil, "AI图片服务未配置")
}
func (nilHTTPService) Favorite(ctx context.Context, input aiimagemodule.FavoriteInput) (*aiimagemodule.TaskDTO, *apperror.Error) {
	return nil, apperror.InternalKey("aiimage.service_missing", nil, "AI图片服务未配置")
}
func (nilHTTPService) Delete(ctx context.Context, userID uint64, taskID uint64) *apperror.Error {
	return apperror.InternalKey("aiimage.service_missing", nil, "AI图片服务未配置")
}
```

- [ ] **Step 4: Run the new transport tests**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/ai/image/transport/canvas -count=1
```

Expected:

```text
ok admin_back_go/internal/module/ai/image/transport/canvas
```

- [ ] **Step 5: Commit the new transport**

```powershell
git add internal/module/ai/image/transport/canvas
git commit -m "feat(aiimage): add canvas image transport"
```

---

### Task 4: Register the new transport in server routes

**Files:**
- Modify: `admin_back_go/internal/server/routes_canvas.go`
- Modify: `admin_back_go/internal/server/router_test.go`

- [ ] **Step 1: Register both Canvas shell routes and AI image Canvas routes**

Replace `admin_back_go/internal/server/routes_canvas.go` with:

```go
package server

import (
	aiimagecanvas "admin_back_go/internal/module/ai/image/transport/canvas"
	canvastransport "admin_back_go/internal/module/canvas/transport/canvas"

	"github.com/gin-gonic/gin"
)

func registerCanvasRoutes(router *gin.Engine, deps Dependencies) {
	canvastransport.RegisterRoutes(router, deps.CanvasService)
	aiimagecanvas.RegisterRoutes(router, deps.AiImageService)
}
```

- [ ] **Step 2: Add a router-level fake for `AiImageService`**

In `admin_back_go/internal/server/router_test.go`, add the missing import:

```go
aiimage "admin_back_go/internal/module/ai/image"
```

After `fakeRouterCanvasService`, add:

```go
type fakeRouterAIImageService struct {
	createInput aiimage.CreateInput
	detailUserID uint64
	detailTaskID uint64
}

func (f *fakeRouterAIImageService) PageInit(ctx context.Context) (*aiimage.PageInitResponse, *apperror.Error) {
	return nil, apperror.InternalKey("unexpected", nil, "unexpected")
}
func (f *fakeRouterAIImageService) List(ctx context.Context, userID uint64, query aiimage.ListQuery) (*aiimage.ListResponse, *apperror.Error) {
	return nil, apperror.InternalKey("unexpected", nil, "unexpected")
}
func (f *fakeRouterAIImageService) Detail(ctx context.Context, userID uint64, taskID uint64) (*aiimage.DetailResponse, *apperror.Error) {
	f.detailUserID = userID
	f.detailTaskID = taskID
	return &aiimage.DetailResponse{Task: aiimage.TaskDTO{ID: taskID, Status: aiimage.StatusSuccess}}, nil
}
func (f *fakeRouterAIImageService) RegisterAsset(ctx context.Context, input aiimage.RegisterAssetInput) (*aiimage.AssetDTO, *apperror.Error) {
	return nil, apperror.InternalKey("unexpected", nil, "unexpected")
}
func (f *fakeRouterAIImageService) Create(ctx context.Context, input aiimage.CreateInput) (*aiimage.CreateTaskResponse, *apperror.Error) {
	f.createInput = input
	return &aiimage.CreateTaskResponse{Task: aiimage.TaskDTO{ID: 88, Status: aiimage.StatusPending}}, nil
}
func (f *fakeRouterAIImageService) CreateWithUploadedAssets(ctx context.Context, input aiimage.CreateWithUploadedAssetsInput) (*aiimage.CreateTaskResponse, *apperror.Error) {
	f.createInput = input.CreateInput
	return &aiimage.CreateTaskResponse{Task: aiimage.TaskDTO{ID: 89, Status: aiimage.StatusPending}}, nil
}
func (f *fakeRouterAIImageService) Favorite(ctx context.Context, input aiimage.FavoriteInput) (*aiimage.TaskDTO, *apperror.Error) {
	return nil, apperror.InternalKey("unexpected", nil, "unexpected")
}
func (f *fakeRouterAIImageService) Delete(ctx context.Context, userID uint64, taskID uint64) *apperror.Error {
	return apperror.InternalKey("unexpected", nil, "unexpected")
}
```

- [ ] **Step 3: Add a router test proving `/api/canvas/v1/ai/images/*` is installed through `AiImageService`**

Append this test near `TestRouterInstallsCanvasPromptAndAssetRoutes`:

```go
func TestRouterInstallsCanvasAIImageRoutesFromAIImageService(t *testing.T) {
	canvasService := &fakeRouterCanvasService{}
	aiImageService := &fakeRouterAIImageService{}
	router := newTestRouter(t, Dependencies{
		Authenticator: func(ctx context.Context, input middleware.TokenInput) (*middleware.AuthIdentity, *apperror.Error) {
			return &middleware.AuthIdentity{UserID: 9, SessionID: 10, Platform: input.Platform}, nil
		},
		CanvasService:  canvasService,
		AiImageService: aiImageService,
	})

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodPost, "/api/canvas/v1/ai/images/generations", strings.NewReader(`{"agent_id":8,"prompt":"cat","n":2}`))
	request.Header.Set("Authorization", "Bearer canvas-token")
	request.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusOK {
		t.Fatalf("expected canvas image generation route, code=%d body=%s", recorder.Code, recorder.Body.String())
	}
	if aiImageService.createInput.UserID != 9 || aiImageService.createInput.AgentID != 8 || aiImageService.createInput.Platform != enum.PlatformCanvas || aiImageService.createInput.N != 2 {
		t.Fatalf("expected ai image service to own canvas image generation, input=%#v", aiImageService.createInput)
	}
	if canvasService.imageInput.UserID != 0 || canvasService.imageStatus != 0 {
		t.Fatalf("canvas service must not receive image route calls, canvas=%#v", canvasService)
	}

	recorder = httptest.NewRecorder()
	request = httptest.NewRequest(http.MethodGet, "/api/canvas/v1/ai/images/88", nil)
	request.Header.Set("Authorization", "Bearer canvas-token")
	router.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusOK {
		t.Fatalf("expected canvas image status route, code=%d body=%s", recorder.Code, recorder.Body.String())
	}
	if aiImageService.detailUserID != 9 || aiImageService.detailTaskID != 88 {
		t.Fatalf("expected ai image service detail lookup, user=%d task=%d", aiImageService.detailUserID, aiImageService.detailTaskID)
	}
}
```

- [ ] **Step 4: Run the router test before shrinking Canvas service**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/server -run TestRouterInstallsCanvasAIImageRoutesFromAIImageService -count=1
```

Expected:

```text
ok admin_back_go/internal/server
```

At this point both old Canvas image routes and the new AI image Canvas routes may be registered with identical paths. If Gin reports duplicate route registration, skip to Task 5 immediately and remove the old Canvas image registrations before re-running this command.

- [ ] **Step 5: Commit server route registration**

```powershell
git add internal/server/routes_canvas.go internal/server/router_test.go
git commit -m "feat(server): register canvas ai image routes by capability"
```

---

### Task 5: Remove image route ownership from Canvas transport and service

**Files:**
- Modify: `admin_back_go/internal/module/canvas/transport/canvas/route.go`
- Modify: `admin_back_go/internal/module/canvas/transport/canvas/request.go`
- Modify: `admin_back_go/internal/module/canvas/transport/canvas/handler.go`
- Modify: `admin_back_go/internal/module/canvas/transport/canvas/handler_test.go`
- Modify: `admin_back_go/internal/module/canvas/dto.go`
- Modify: `admin_back_go/internal/module/canvas/service.go`
- Modify: `admin_back_go/internal/module/canvas/service_test.go`
- Modify: `admin_back_go/internal/bootstrap/app.go`
- Modify: `admin_back_go/internal/server/router_test.go`

- [ ] **Step 1: Remove image routes from Canvas route registration**

Edit `admin_back_go/internal/module/canvas/transport/canvas/route.go` so the route list is exactly:

```go
package canvas

import "github.com/gin-gonic/gin"

func RegisterRoutes(router *gin.Engine, service HTTPService) {
	handler := NewHandler(service)
	group := router.Group("/api/canvas/v1")
	group.GET("/settings", handler.Settings)
	group.GET("/prompts", handler.Prompts)
	group.GET("/assets", handler.Assets)
	group.POST("/ai/chat/completions", handler.ChatCompletions)
	group.POST("/ai/videos", handler.VideoGenerations)
	group.GET("/ai/videos/:id", handler.VideoStatus)
	group.GET("/ai/videos/:id/content", handler.VideoContent)
}
```

- [ ] **Step 2: Remove Canvas image request DTO**

In `admin_back_go/internal/module/canvas/transport/canvas/request.go`, delete only this struct:

```go
type imageGenerationRequest struct {
	AgentID           int64    `json:"agent_id" form:"agent_id"`
	Prompt            string   `json:"prompt" form:"prompt"`
	Size              string   `json:"size" form:"size"`
	Quality           string   `json:"quality" form:"quality"`
	OutputFormat      string   `json:"output_format" form:"output_format"`
	OutputCompression *int     `json:"output_compression" form:"output_compression"`
	Moderation        string   `json:"moderation" form:"moderation"`
	N                 int      `json:"n" form:"n"`
	InputAssetIDs     []uint64 `json:"input_asset_ids" form:"input_asset_ids"`
	MaskAssetID       uint64   `json:"mask_asset_id" form:"mask_asset_id"`
	MaskTargetAssetID uint64   `json:"mask_target_asset_id" form:"mask_target_asset_id"`
}
```

- [ ] **Step 3: Remove Canvas image HTTP methods and upload parser**

In `admin_back_go/internal/module/canvas/transport/canvas/handler.go`:

Remove these imports:

```go
"io"
"strings"
aiimagemodule "admin_back_go/internal/module/ai/image"
```

Keep `net/http` because `VideoContent` uses it. Keep `strconv` because video route id parsing uses it.

Remove image methods from `HTTPService`:

```go
GenerateImage(ctx context.Context, input canvasmodule.ImageGenerationInput) (*canvasmodule.ImageGenerationResponse, *apperror.Error)
ImageStatus(ctx context.Context, userID int64, id uint64) (*canvasmodule.ImageStatusResponse, *apperror.Error)
```

Delete these handler methods:

```go
func (h *Handler) ImageGenerations(c *gin.Context) { ... }
func (h *Handler) ImageEdits(c *gin.Context) { ... }
func (h *Handler) ImageStatus(c *gin.Context) { ... }
```

Delete these failing service methods:

```go
func (failingService) GenerateImage(ctx context.Context, input canvasmodule.ImageGenerationInput) (*canvasmodule.ImageGenerationResponse, *apperror.Error) { ... }
func (failingService) ImageStatus(ctx context.Context, userID int64, id uint64) (*canvasmodule.ImageStatusResponse, *apperror.Error) { ... }
```

Delete the Canvas image upload parser:

```go
func bindImageEditRequest(c *gin.Context) (imageGenerationRequest, []aiimagemodule.UploadedAssetInput, bool) { ... }
```

- [ ] **Step 4: Remove Canvas image DTOs and runtime interface**

In `admin_back_go/internal/module/canvas/dto.go`, remove:

```go
type ImageGenerationInput struct { ... }
type ImageGenerationResponse struct { ... }
type ImageStatusResponse struct { ... }
type ImageRuntime interface { ... }
```

Also remove the `aiimagemodule "admin_back_go/internal/module/ai/image"` import from `dto.go` if it becomes unused.

- [ ] **Step 5: Remove Canvas service image proxy**

In `admin_back_go/internal/module/canvas/service.go`:

Remove this import:

```go
aiimagemodule "admin_back_go/internal/module/ai/image"
```

Change `SettingsDependencies` from:

```go
type SettingsDependencies struct {
	AuthPolicy AuthPolicyService
	Image      ImageRuntime
	Text       TextRuntime
	Video      VideoRuntime
}
```

to:

```go
type SettingsDependencies struct {
	AuthPolicy AuthPolicyService
	Text       TextRuntime
	Video      VideoRuntime
}
```

Delete these methods:

```go
func (s *Service) GenerateImage(ctx context.Context, input ImageGenerationInput) (*ImageGenerationResponse, *apperror.Error) { ... }
func (s *Service) ImageStatus(ctx context.Context, userID int64, id uint64) (*ImageStatusResponse, *apperror.Error) { ... }
```

Do not change `canvasImageAgentScene` or `canvasAgentGroups`; `/settings` must still return image agents for the frontend picker.

- [ ] **Step 6: Remove the image dependency from bootstrap Canvas settings**

In `admin_back_go/internal/bootstrap/app.go`, change:

```go
canvasService := canvasmodule.NewServiceWithSettings(canvasmodule.NewGormRepository(resources.DB), canvasmodule.SettingsDependencies{
	AuthPolicy: authPlatformService,
	Image:      aiImageService,
	Text:       canvasTextRuntime,
	Video:      canvasVideoRuntime,
})
```

to:

```go
canvasService := canvasmodule.NewServiceWithSettings(canvasmodule.NewGormRepository(resources.DB), canvasmodule.SettingsDependencies{
	AuthPolicy: authPlatformService,
	Text:       canvasTextRuntime,
	Video:      canvasVideoRuntime,
})
```

- [ ] **Step 7: Shrink Canvas transport tests**

In `admin_back_go/internal/module/canvas/transport/canvas/handler_test.go`:

Remove these imports:

```go
"bytes"
"mime/multipart"
```

Remove these fake fields:

```go
imageInput     canvasmodule.ImageGenerationInput
imageStatusID  uint64
```

Remove these fake methods:

```go
func (f *fakeCanvasService) GenerateImage(...)
func (f *fakeCanvasService) ImageStatus(...)
```

In `TestCanvasAIRoutesUseAuthenticatedUserAndDoNotLeakProviderConfig`, delete the image generation/status assertions for:

```text
POST /api/canvas/v1/ai/images/generations
GET  /api/canvas/v1/ai/images/88
```

Keep chat and video assertions in that test.

Delete the whole `TestCanvasImageEditsAcceptMultipartReferenceImages` test from this file. Its replacement lives in `internal/module/ai/image/transport/canvas/handler_test.go`.

- [ ] **Step 8: Shrink Canvas service tests**

In `admin_back_go/internal/module/canvas/service_test.go`:

Remove the fake image runtime and tests that assert `canvas.Service.GenerateImage` or `canvas.Service.ImageStatus`. Keep settings tests that assert `Agents.Image` contains `canvas_image_generate`.

Remove these fake pieces when present:

```go
image := &fakeCanvasImageRuntime{}
Image: image,
type fakeCanvasImageRuntime struct { ... }
```

Do not remove `canvasImageAgentScene` settings assertions.

- [ ] **Step 9: Shrink router test Canvas fake**

In `admin_back_go/internal/server/router_test.go`, after the new `fakeRouterAIImageService` test is in place, remove these fields from `fakeRouterCanvasService`:

```go
imageInput  canvasmodule.ImageGenerationInput
imageStatus uint64
```

Remove these methods:

```go
func (f *fakeRouterCanvasService) GenerateImage(...)
func (f *fakeRouterCanvasService) ImageStatus(...)
```

In `TestRouterInstallsCanvasAIImageRoutesFromAIImageService`, remove this check because the Canvas fake no longer has image fields:

```go
if canvasService.imageInput.UserID != 0 || canvasService.imageStatus != 0 {
	t.Fatalf("canvas service must not receive image route calls, canvas=%#v", canvasService)
}
```

The architecture guard now proves Canvas transport does not own `/ai/images`.

- [ ] **Step 10: Run Canvas and server tests**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/canvas ./internal/module/canvas/transport/canvas ./internal/module/ai/image/transport/canvas ./internal/server -count=1
```

Expected:

```text
ok admin_back_go/internal/module/canvas
ok admin_back_go/internal/module/canvas/transport/canvas
ok admin_back_go/internal/module/ai/image/transport/canvas
ok admin_back_go/internal/server
```

- [ ] **Step 11: Commit Canvas owner shrink**

```powershell
git add internal/module/canvas internal/module/ai/image/transport/canvas internal/server internal/bootstrap/app.go
git commit -m "refactor(canvas): move image route owner to ai image"
```

---

### Task 6: Update route ownership contract docs

**Files:**
- Modify: `docs/contracts/admin-api-v1.md`

- [ ] **Step 1: Update the Canvas route ownership sentence**

Find the existing route ownership sentence around the Canvas API contract and replace it with this wording:

```markdown
Route ownership：`/api/canvas/v1/auth/*` -> `internal/module/auth/transport/canvas`；`/api/canvas/v1/users/me` -> `internal/module/user/transport/canvas`；`/api/canvas/v1/profile` -> `internal/module/profile/transport/canvas`；`/api/canvas/v1/prompts|assets|settings` -> `internal/module/canvas/transport/canvas`；`/api/canvas/v1/ai/images/*` -> `internal/module/ai/image/transport/canvas`。Canvas chat/video 仍处于后续迁移范围，当前 URL 保持不变。
```

- [ ] **Step 2: Update the Canvas AI endpoint list if it lacks image status**

Ensure the Canvas endpoint list includes all three image routes:

```markdown
POST /api/canvas/v1/ai/images/generations
POST /api/canvas/v1/ai/images/edits
GET  /api/canvas/v1/ai/images/:id
```

- [ ] **Step 3: Run docs diff check**

Run:

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected:

```text
git diff --check exits 0
PASS: no blocking governance violations found.
```

- [ ] **Step 4: Commit docs**

```powershell
git add docs/contracts/admin-api-v1.md
git commit -m "docs(canvas): clarify ai image route ownership"
```

---

### Task 7: Run full targeted verification

**Files:**
- Verification only.

- [ ] **Step 1: Run backend targeted package tests**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/ai/image ./internal/module/ai/image/transport/canvas ./internal/module/canvas ./internal/module/canvas/transport/canvas ./internal/server ./internal/architecture -count=1
```

Expected:

```text
ok admin_back_go/internal/module/ai/image
ok admin_back_go/internal/module/ai/image/transport/canvas
ok admin_back_go/internal/module/canvas
ok admin_back_go/internal/module/canvas/transport/canvas
ok admin_back_go/internal/server
ok admin_back_go/internal/architecture
```

- [ ] **Step 2: Run frontend contract checks**

Run:

```powershell
cd E:\admin_go\canvas_front_next
npm run typecheck
npm test
npm run build
```

Expected:

```text
typecheck passes
vitest test files pass
next build completes successfully
```

- [ ] **Step 3: Run root governance checks**

Run:

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected:

```text
git diff --check exits 0
PASS: no blocking governance violations found.
```

- [ ] **Step 4: Confirm the final route ownership with grep**

Run:

```powershell
cd E:\admin_go
rg -n 'ai/images|internal/module/ai/image' .\admin_back_go\internal\module\canvas .\admin_back_go\internal\module\ai\image\transport\canvas .\admin_back_go\internal\server\routes_canvas.go
```

Expected:

```text
admin_back_go/internal/module/ai/image/transport/canvas/route.go contains /api/canvas/v1/ai/images route registrations
admin_back_go/internal/server/routes_canvas.go imports and calls aiimagecanvas.RegisterRoutes
admin_back_go/internal/module/canvas production files do not contain /ai/images or internal/module/ai/image
```

- [ ] **Step 5: Final commit if any verification-only doc adjustment was needed**

If verification forced docs or test-command wording changes:

```powershell
git add docs admin_back_go
git commit -m "chore(canvas): verify ai image transport ownership"
```

If no files changed after previous commits, do not create an empty commit.

---

## Self-Review Checklist

- [ ] Spec coverage: This plan implements only Phase 1 image route owner migration from the spec.
- [ ] URL compatibility: All external `/api/canvas/v1/ai/images/*` URLs stay unchanged.
- [ ] Data compatibility: `ai_image_tasks`, `ai_image_assets`, and `ai_image_task_assets` are not migrated or renamed.
- [ ] Frontend compatibility: `canvas_front_next/src/services/api/image.ts` remains a verification target, not an implementation target.
- [ ] Architecture guard: Tests prevent `/ai/images` from returning to `canvas/transport/canvas`.
- [ ] Scope control: Chat/video are explicitly left for later specs/plans.
