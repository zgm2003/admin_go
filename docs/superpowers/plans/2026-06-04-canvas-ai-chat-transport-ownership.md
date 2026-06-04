# Canvas AI Chat Transport Ownership Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move `POST /api/canvas/v1/ai/chat/completions` from `internal/module/canvas/transport/canvas` to `internal/module/ai/chat/transport/canvas` without changing the external Canvas API contract.

**Architecture:** `canvas` keeps Canvas platform resources (`settings/prompts/assets`). `ai/chat` owns Canvas stateless text generation through a real `aichat.HTTPService` method. Video routes remain in Canvas transport for the separate Phase B plan.

**Tech Stack:** Go, Gin, GORM-backed `ai/chat` repository, `internal/infra/ai.Engine`, `secretbox`, `apperror`, `response`, PowerShell verification.

---

## Scope

Implements only Phase A from `docs/superpowers/specs/2026-06-04-canvas-ai-chat-video-transport-ownership-design.md`.

Do not migrate these in this plan:

```text
POST /api/canvas/v1/ai/videos
GET  /api/canvas/v1/ai/videos/:id
GET  /api/canvas/v1/ai/videos/:id/content
```

## Files

Create:

```text
admin_back_go/internal/module/ai/chat/transport/canvas/route.go
admin_back_go/internal/module/ai/chat/transport/canvas/request.go
admin_back_go/internal/module/ai/chat/transport/canvas/handler.go
admin_back_go/internal/module/ai/chat/transport/canvas/handler_test.go
```

Modify:

```text
admin_back_go/internal/module/ai/chat/dto.go
admin_back_go/internal/module/ai/chat/service.go
admin_back_go/internal/module/ai/chat/service_test.go
admin_back_go/internal/module/canvas/transport/canvas/route.go
admin_back_go/internal/module/canvas/transport/canvas/request.go
admin_back_go/internal/module/canvas/transport/canvas/handler.go
admin_back_go/internal/module/canvas/transport/canvas/handler_test.go
admin_back_go/internal/module/canvas/service.go
admin_back_go/internal/module/canvas/service_test.go
admin_back_go/internal/module/canvas/dto.go
admin_back_go/internal/server/routes_canvas.go
admin_back_go/internal/server/router_test.go
admin_back_go/internal/bootstrap/app.go
admin_back_go/internal/architecture/platform_route_line_test.go
```

Delete:

```text
admin_back_go/internal/module/canvas/text_runtime.go
admin_back_go/internal/module/canvas/text_runtime_test.go
admin_back_go/internal/module/canvas/text_repository.go
```

## Compatibility rules

```text
URL stays POST /api/canvas/v1/ai/chat/completions
Request stays agent_id/message/model
Response data stays id/object/content
Auth identity must be PlatformCanvas
Client model must not override ai_agents.model_id
No ai_conversations, ai_messages, ai_runs writes
No WebSocket publish
No billing checks or writes
Canvas settings still returns agents.text from canvas_text_generate
Canvas video routes remain registered by canvas transport
```

---

### Task 1: Add Canvas stateless completion service to `ai/chat`

**Files:**
- Modify: `admin_back_go/internal/module/ai/chat/dto.go`
- Modify: `admin_back_go/internal/module/ai/chat/service.go`
- Modify: `admin_back_go/internal/module/ai/chat/service_test.go`
- Modify: `admin_back_go/internal/server/router_test.go`

- [ ] **Step 1: Write RED service tests**

In `admin_back_go/internal/module/ai/chat/service_test.go`, add `agentID uint64` to `fakeRepository`, and record it in `AgentForRuntime`:

```go
func (f *fakeRepository) AgentForRuntime(ctx context.Context, agentID uint64) (*AgentEngineConfig, error) {
	f.agentID = agentID
	return f.agent, nil
}
```

Add this fixture:

```go
func validCanvasTextAgentConfig(t *testing.T) (*AgentEngineConfig, secretbox.Box) {
	t.Helper()
	box := secretbox.New([]byte("12345678901234567890123456789012"))
	cipher, err := box.Encrypt("provider-key")
	if err != nil { t.Fatalf("encrypt fixture: %v", err) }
	return &AgentEngineConfig{AgentID: 8, AgentName: "Canvas文本助手", ProviderID: 2, ModelID: "gpt-4.1-mini", ModelDisplayName: "GPT 4.1 Mini", SystemPrompt: "用中文回答", ScenesJSON: `["canvas_text_generate"]`, EngineType: string(infraai.EngineTypeOpenAI), EngineBaseURL: "https://api.openai.test/v1", EngineAPIKeyEnc: cipher, AgentStatus: enum.CommonYes, EngineStatus: enum.CommonYes}, box
}
```

Add these tests:

```go
func TestCanvasCompletionUsesCanvasTextAgentAndDoesNotPersistConversation(t *testing.T) {
	agent, box := validCanvasTextAgentConfig(t)
	repo := &fakeRepository{agent: agent}
	engine := &captureEngine{}
	factory := &fakeEngineFactory{engine: engine}
	pub := &fakePublisher{}
	now := time.Date(2026, 6, 4, 12, 0, 0, 123, time.UTC)

	res, appErr := NewService(Dependencies{Repository: repo, Publisher: pub, EngineFactory: factory, Secretbox: box, Now: func() time.Time { return now }}).CanvasCompletion(context.Background(), CanvasCompletionInput{UserID: 7, AgentID: 8, ModelID: "client-model", Message: " hello canvas "})

	if appErr != nil { t.Fatalf("CanvasCompletion returned error: %#v", appErr) }
	if res == nil || res.ID != "canvas-chat-1780574400000000123" || res.Object != "chat.completion" || res.Content != "看到了图片" { t.Fatalf("unexpected response: %#v", res) }
	if repo.agentID != 8 { t.Fatalf("expected runtime agent id 8, got %d", repo.agentID) }
	if engine.input.UserID != 7 || engine.input.AgentID != 8 || engine.input.UserKey != "canvas:7" || engine.input.Content != "hello canvas" { t.Fatalf("unexpected engine input: %#v", engine.input) }
	if engine.input.Inputs["model_id"] != "gpt-4.1-mini" || engine.input.Inputs["system_prompt"] != "用中文回答" { t.Fatalf("agent model/system prompt not used: %#v", engine.input.Inputs) }
	if repo.createdRun.ConversationID != 0 || repo.createdRun.UserMessageID != 0 || repo.assistant.Content != "" || len(pub.pubs) != 0 { t.Fatalf("stateless completion must not persist or publish: repo=%#v pubs=%#v", repo, pub.pubs) }
	if factory.input.APIKey != "provider-key" || factory.input.EngineType != infraai.EngineTypeOpenAI { t.Fatalf("unexpected engine config: %#v", factory.input) }
}

func TestCanvasCompletionRejectsNonCanvasTextScene(t *testing.T) {
	agent, box := validAgentConfig(t)
	_, appErr := NewService(Dependencies{Repository: &fakeRepository{agent: agent}, EngineFactory: &fakeEngineFactory{engine: infraai.NewFakeEngine("ok")}, Secretbox: box}).CanvasCompletion(context.Background(), CanvasCompletionInput{UserID: 7, AgentID: 5, Message: "hi"})
	if appErr == nil || appErr.Code != apperror.CodeBadRequest || appErr.MessageID != "canvas.ai.chat.agent_unavailable" { t.Fatalf("expected canvas text scene rejection, got %#v", appErr) }
}

func TestCanvasCompletionRejectsEmptyProviderAnswer(t *testing.T) {
	agent, box := validCanvasTextAgentConfig(t)
	_, appErr := NewService(Dependencies{Repository: &fakeRepository{agent: agent}, EngineFactory: &fakeEngineFactory{engine: blankEngine{}}, Secretbox: box}).CanvasCompletion(context.Background(), CanvasCompletionInput{UserID: 7, AgentID: 8, Message: "hi"})
	if appErr == nil || appErr.MessageID != "canvas.ai.chat.empty_result" { t.Fatalf("expected empty result error, got %#v", appErr) }
}
```

- [ ] **Step 2: Verify RED**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/ai/chat -run 'TestCanvasCompletion' -count=1
```

Expected:

```text
FAIL
undefined: CanvasCompletionInput
```

- [ ] **Step 3: Add DTO and HTTP interface**

In `admin_back_go/internal/module/ai/chat/dto.go`, add:

```go
type CanvasCompletionInput struct { UserID int64; AgentID int64; ModelID string; Message string }

type CanvasCompletionResponse struct { ID string `json:"id"`; Object string `json:"object"`; Content string `json:"content"` }

type HTTPService interface {
	CanvasCompletion(ctx context.Context, input CanvasCompletionInput) (*CanvasCompletionResponse, *apperror.Error)
}
```

Remove the previous empty `type HTTPService interface{}`.

- [ ] **Step 4: Implement service method**

In `admin_back_go/internal/module/ai/chat/service.go`, add:

```go
const canvasTextGenerateScene = "canvas_text_generate"

func (s *Service) CanvasCompletion(ctx context.Context, input CanvasCompletionInput) (*CanvasCompletionResponse, *apperror.Error) {
	input.Message = strings.TrimSpace(input.Message)
	input.ModelID = strings.TrimSpace(input.ModelID)
	if input.UserID <= 0 { return nil, apperror.UnauthorizedKey("auth.token.invalid_or_expired", nil, "Token无效或已过期") }
	if input.AgentID <= 0 || input.Message == "" { return nil, apperror.BadRequestKey("canvas.ai.chat.request.invalid", nil, "文本生成参数错误") }
	repo, appErr := s.requireRepository()
	if appErr != nil { return nil, apperror.InternalKey("canvas.ai.chat.repository_missing", nil, "Canvas文本生成仓储未配置") }
	agent, err := repo.AgentForRuntime(ctx, uint64(input.AgentID))
	if err != nil { return nil, apperror.WrapKey(apperror.CodeInternal, 500, "canvas.ai.chat.agent_query_failed", nil, "查询文本智能体失败", err) }
	if agent == nil || agent.AgentID == 0 { return nil, apperror.NotFoundKey("canvas.ai.chat.agent_not_found", nil, "文本智能体不存在") }
	if agent.AgentStatus != enum.CommonYes || agent.EngineStatus != enum.CommonYes || !agentSupportsCanvasText(agent.ScenesJSON) { return nil, apperror.BadRequestKey("canvas.ai.chat.agent_unavailable", nil, "该智能体不支持文本生成") }
	engine, appErr := s.canvasCompletionEngine(ctx, *agent)
	if appErr != nil { return nil, appErr }
	result, err := engine.StreamChat(ctx, infraai.ChatInput{AgentID: agent.AgentID, UserID: uint64(input.UserID), UserKey: canvasUserKey(input.UserID), Content: input.Message, Inputs: canvasCompletionInputs(*agent)}, discardEventSink{})
	if err != nil { return nil, apperror.WrapKey(apperror.CodeInternal, 500, "canvas.ai.chat.provider_failed", nil, "Canvas文本生成失败", err) }
	answer := ""
	if result != nil { answer = strings.TrimSpace(result.Answer) }
	if answer == "" { return nil, apperror.BadRequestKey("canvas.ai.chat.empty_result", nil, "Canvas文本生成结果为空") }
	return &CanvasCompletionResponse{ID: fmt.Sprintf("canvas-chat-%d", s.now().UnixNano()), Object: "chat.completion", Content: answer}, nil
}
```

Add helpers:

```go
func (s *Service) canvasCompletionEngine(ctx context.Context, agent AgentEngineConfig) (infraai.Engine, *apperror.Error) {
	if agent.AgentID == 0 || agent.ProviderID == 0 { return nil, apperror.BadRequestKey("canvas.ai.chat.agent_unavailable", nil, "该智能体不支持文本生成") }
	apiKeyEnc := strings.TrimSpace(agent.EngineAPIKeyEnc)
	if apiKeyEnc == "" { return nil, apperror.BadRequestKey("canvas.ai.chat.provider_key_missing", nil, "AI供应商API Key未配置") }
	if s == nil || s.secretbox == nil { return nil, apperror.InternalKey("canvas.ai.chat.secretbox_missing", nil, "AI密钥服务未配置") }
	apiKey, err := s.secretbox.Decrypt(apiKeyEnc)
	if err != nil { return nil, apperror.WrapKey(apperror.CodeInternal, 500, "canvas.ai.chat.provider_key_decrypt_failed", nil, "解密AI供应商API Key失败", err) }
	if strings.TrimSpace(apiKey) == "" { return nil, apperror.BadRequestKey("canvas.ai.chat.provider_key_missing", nil, "AI供应商API Key未配置") }
	if s.engineFactory == nil { return nil, apperror.InternalKey("canvas.ai.chat.engine_missing", nil, "AI引擎工厂未配置") }
	engine, err := s.engineFactory.NewEngine(ctx, EngineConfig{EngineType: infraai.EngineType(agent.EngineType), BaseURL: agent.EngineBaseURL, APIKey: apiKey})
	if err != nil { return nil, apperror.WrapKey(apperror.CodeInternal, 500, "canvas.ai.chat.engine_create_failed", nil, "创建AI引擎失败", err) }
	if engine == nil { return nil, apperror.InternalKey("canvas.ai.chat.engine_missing", nil, "AI引擎未配置") }
	return engine, nil
}

func canvasCompletionInputs(agent AgentEngineConfig) map[string]any { inputs := map[string]any{"model_id": agent.ModelID}; if systemPrompt := strings.TrimSpace(agent.SystemPrompt); systemPrompt != "" { inputs["system_prompt"] = systemPrompt }; return inputs }
func canvasUserKey(userID int64) string { return fmt.Sprintf("canvas:%d", userID) }
type discardEventSink struct{}
func (discardEventSink) Emit(ctx context.Context, event infraai.Event) error { return nil }
func agentSupportsCanvasText(raw string) bool { return agentSupportsScene(raw, canvasTextGenerateScene) }
func agentSupportsChat(raw string) bool { return agentSupportsScene(raw, "chat") }
func agentSupportsScene(raw string, want string) bool { var scenes []string; if err := json.Unmarshal([]byte(strings.TrimSpace(raw)), &scenes); err != nil || len(scenes) == 0 { return false }; for _, scene := range scenes { if strings.TrimSpace(scene) == want { return true } }; return false }
```

Replace the old hard-coded `agentSupportsChat` function with the three scene helper functions above.

- [ ] **Step 5: Update server fake for non-empty `aichat.HTTPService`**

In `admin_back_go/internal/server/router_test.go`, add import:

```go	aichat "admin_back_go/internal/module/ai/chat"
```

Replace `type fakeRouterAIChatService struct{}` with:

```go
type fakeRouterAIChatService struct { input aichat.CanvasCompletionInput }
func (f *fakeRouterAIChatService) CanvasCompletion(ctx context.Context, input aichat.CanvasCompletionInput) (*aichat.CanvasCompletionResponse, *apperror.Error) { f.input = input; return &aichat.CanvasCompletionResponse{ID: "chat-1", Object: "chat.completion", Content: "ok"}, nil }
```

Change any `AiChatService: fakeRouterAIChatService{}` fixture to:

```go
AiChatService: &fakeRouterAIChatService{},
```

- [ ] **Step 6: Verify GREEN and commit**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/ai/chat -count=1
```

Expected:

```text
ok  	admin_back_go/internal/module/ai/chat
```

Commit:

```powershell
cd E:\admin_go
git add admin_back_go/internal/module/ai/chat/dto.go admin_back_go/internal/module/ai/chat/service.go admin_back_go/internal/module/ai/chat/service_test.go admin_back_go/internal/server/router_test.go
git commit -m "feat(ai-chat): add canvas completion service"
```
---

### Task 2: Add `ai/chat/transport/canvas`

**Files:**
- Create: `admin_back_go/internal/module/ai/chat/transport/canvas/handler_test.go`
- Create: `admin_back_go/internal/module/ai/chat/transport/canvas/request.go`
- Create: `admin_back_go/internal/module/ai/chat/transport/canvas/handler.go`
- Create: `admin_back_go/internal/module/ai/chat/transport/canvas/route.go`

- [ ] **Step 1: Write RED transport tests**

Create `admin_back_go/internal/module/ai/chat/transport/canvas/handler_test.go`:

```go
package canvas

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"admin_back_go/internal/middleware"
	aichatmodule "admin_back_go/internal/module/ai/chat"
	"admin_back_go/internal/shared/apperror"
	"admin_back_go/internal/shared/enum"

	"github.com/gin-gonic/gin"
)

type fakeCanvasChatService struct { input aichatmodule.CanvasCompletionInput; returnNil bool; returnEmpty bool }
func (f *fakeCanvasChatService) CanvasCompletion(ctx context.Context, input aichatmodule.CanvasCompletionInput) (*aichatmodule.CanvasCompletionResponse, *apperror.Error) { f.input = input; if f.returnNil { return nil, nil }; if f.returnEmpty { return &aichatmodule.CanvasCompletionResponse{}, nil }; return &aichatmodule.CanvasCompletionResponse{ID: "chat-1", Object: "chat.completion", Content: "ok"}, nil }

func TestCanvasChatCompletionUsesCanvasIdentityAndService(t *testing.T) {
	gin.SetMode(gin.ReleaseMode)
	service := &fakeCanvasChatService{}
	router := gin.New()
	router.Use(func(c *gin.Context) { c.Set(middleware.ContextAuthIdentity, &middleware.AuthIdentity{UserID: 9, Platform: enum.PlatformCanvas}) })
	RegisterRoutes(router, service)

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodPost, "/api/canvas/v1/ai/chat/completions", strings.NewReader(`{"agent_id":7,"message":"hello","model":"client-model"}`))
	request.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK { t.Fatalf("expected status 200, got %d body=%s", recorder.Code, recorder.Body.String()) }
	if service.input.UserID != 9 || service.input.AgentID != 7 || service.input.Message != "hello" || service.input.ModelID != "client-model" { t.Fatalf("unexpected service input: %#v", service.input) }
	for _, want := range []string{`"id":"chat-1"`, `"object":"chat.completion"`, `"content":"ok"`} { if !strings.Contains(recorder.Body.String(), want) { t.Fatalf("response missing %s: %s", want, recorder.Body.String()) } }
}

func TestCanvasChatCompletionRejectsWrongPlatformIdentity(t *testing.T) {
	gin.SetMode(gin.ReleaseMode)
	service := &fakeCanvasChatService{}
	router := gin.New()
	router.Use(func(c *gin.Context) { c.Set(middleware.ContextAuthIdentity, &middleware.AuthIdentity{UserID: 9, Platform: enum.PlatformAdmin}) })
	RegisterRoutes(router, service)

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodPost, "/api/canvas/v1/ai/chat/completions", strings.NewReader(`{"agent_id":7,"message":"hello"}`))
	request.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusUnauthorized { t.Fatalf("expected 401, got %d body=%s", recorder.Code, recorder.Body.String()) }
	if service.input.UserID != 0 { t.Fatalf("service must not be called for wrong platform: %#v", service.input) }
}

func TestCanvasChatCompletionRejectsInvalidServiceResult(t *testing.T) {
	gin.SetMode(gin.ReleaseMode)
	for _, tt := range []struct { name string; service *fakeCanvasChatService }{{name: "nil result", service: &fakeCanvasChatService{returnNil: true}}, {name: "empty result", service: &fakeCanvasChatService{returnEmpty: true}}} {
		t.Run(tt.name, func(t *testing.T) {
			router := gin.New()
			router.Use(func(c *gin.Context) { c.Set(middleware.ContextAuthIdentity, &middleware.AuthIdentity{UserID: 9, Platform: enum.PlatformCanvas}) })
			RegisterRoutes(router, tt.service)
			recorder := httptest.NewRecorder()
			request := httptest.NewRequest(http.MethodPost, "/api/canvas/v1/ai/chat/completions", strings.NewReader(`{"agent_id":7,"message":"hello"}`))
			request.Header.Set("Content-Type", "application/json")
			router.ServeHTTP(recorder, request)
			if recorder.Code == http.StatusOK { t.Fatalf("expected non-200 status, got %d body=%s", recorder.Code, recorder.Body.String()) }
			if !strings.Contains(recorder.Body.String(), "Canvas文本生成结果无效") { t.Fatalf("response missing invalid result message: %s", recorder.Body.String()) }
		})
	}
}
```

- [ ] **Step 2: Verify RED**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/ai/chat/transport/canvas -count=1
```

Expected:

```text
FAIL
undefined: RegisterRoutes
```

- [ ] **Step 3: Create request DTO**

Create `admin_back_go/internal/module/ai/chat/transport/canvas/request.go`:

```go
package canvas

type chatCompletionRequest struct { AgentID int64 `json:"agent_id" binding:"required,gt=0"`; ModelID string `json:"model" binding:"omitempty,max=128"`; Message string `json:"message" binding:"required,max=20000"` }
```

- [ ] **Step 4: Create handler**

Create `admin_back_go/internal/module/ai/chat/transport/canvas/handler.go`:

```go
package canvas

import (
	"context"
	"strings"

	"admin_back_go/internal/middleware"
	aichatmodule "admin_back_go/internal/module/ai/chat"
	"admin_back_go/internal/shared/apperror"
	"admin_back_go/internal/shared/enum"
	"admin_back_go/internal/shared/response"

	"github.com/gin-gonic/gin"
)

type Handler struct{ service aichatmodule.HTTPService }
func NewHandler(service aichatmodule.HTTPService) *Handler { return &Handler{service: service} }

func (h *Handler) ChatCompletions(c *gin.Context) {
	userID, ok := currentUserID(c)
	if !ok { return }
	var req chatCompletionRequest
	if err := c.ShouldBindJSON(&req); err != nil { response.Error(c, apperror.BadRequestKey("canvas.ai.chat.request.invalid", nil, "文本生成参数错误")); return }
	result, appErr := h.requireService().CanvasCompletion(c.Request.Context(), aichatmodule.CanvasCompletionInput{UserID: userID, AgentID: req.AgentID, ModelID: req.ModelID, Message: req.Message})
	if appErr != nil { response.Error(c, appErr); return }
	if result == nil || strings.TrimSpace(result.Content) == "" { response.Error(c, apperror.InternalKey("canvas.ai.chat.result_invalid", nil, "Canvas文本生成结果无效")); return }
	response.OK(c, result)
}

func (h *Handler) requireService() aichatmodule.HTTPService { if h == nil || h.service == nil { return nilHTTPService{} }; return h.service }

func currentUserID(c *gin.Context) (int64, bool) {
	identity := middleware.GetAuthIdentity(c)
	if identity == nil || identity.UserID <= 0 { response.Error(c, apperror.UnauthorizedKey("auth.token.invalid_or_expired", nil, "Token无效或已过期")); return 0, false }
	if identity.Platform != enum.PlatformCanvas { response.Error(c, apperror.UnauthorizedKey("auth.platform.invalid", map[string]any{"platform": identity.Platform}, "Token平台不匹配")); return 0, false }
	return identity.UserID, true
}

type nilHTTPService struct{}
func (nilHTTPService) CanvasCompletion(ctx context.Context, input aichatmodule.CanvasCompletionInput) (*aichatmodule.CanvasCompletionResponse, *apperror.Error) { return nil, apperror.InternalKey("canvas.ai.chat.service_missing", nil, "Canvas文本生成服务未配置") }
```

- [ ] **Step 5: Create route**

Create `admin_back_go/internal/module/ai/chat/transport/canvas/route.go`:

```go
package canvas

import (
	aichatmodule "admin_back_go/internal/module/ai/chat"
	"admin_back_go/internal/shared/validate"

	"github.com/gin-gonic/gin"
)

func RegisterRoutes(router *gin.Engine, service aichatmodule.HTTPService) { validate.MustRegister(); handler := NewHandler(service); group := router.Group("/api/canvas/v1/ai/chat"); group.POST("/completions", handler.ChatCompletions) }
```

- [ ] **Step 6: Verify GREEN and commit**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/ai/chat/transport/canvas -count=1
```

Expected:

```text
ok  	admin_back_go/internal/module/ai/chat/transport/canvas
```

Commit:

```powershell
cd E:\admin_go
git add admin_back_go/internal/module/ai/chat/transport/canvas
git commit -m "feat(ai-chat): add canvas chat transport"
```

---

### Task 3: Register chat through `ai/chat` and remove chat from Canvas transport

**Files:**
- Modify: `admin_back_go/internal/server/routes_canvas.go`
- Modify: `admin_back_go/internal/server/router_test.go`
- Modify: `admin_back_go/internal/module/canvas/transport/canvas/route.go`
- Modify: `admin_back_go/internal/module/canvas/transport/canvas/request.go`
- Modify: `admin_back_go/internal/module/canvas/transport/canvas/handler.go`
- Modify: `admin_back_go/internal/module/canvas/transport/canvas/handler_test.go`

- [ ] **Step 1: Write RED router test**

In `admin_back_go/internal/server/router_test.go`, add after `TestRouterInstallsCanvasAIImageRoutesFromAIImageService`:

```go
func TestRouterInstallsCanvasAIChatRouteFromAIChatService(t *testing.T) {
	canvasService := &fakeRouterCanvasService{}
	aiChatService := &fakeRouterAIChatService{}
	router := newTestRouter(t, Dependencies{Authenticator: func(ctx context.Context, input middleware.TokenInput) (*middleware.AuthIdentity, *apperror.Error) { return &middleware.AuthIdentity{UserID: 9, SessionID: 10, Platform: input.Platform}, nil }, CanvasService: canvasService, AiChatService: aiChatService})

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodPost, "/api/canvas/v1/ai/chat/completions", strings.NewReader(`{"agent_id":8,"message":"hello","model":"client-model"}`))
	request.Header.Set("Authorization", "Bearer canvas-token")
	request.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK { t.Fatalf("expected AI chat completion status 200, got %d body=%s", recorder.Code, recorder.Body.String()) }
	if aiChatService.input.UserID != 9 || aiChatService.input.AgentID != 8 || aiChatService.input.Message != "hello" || aiChatService.input.ModelID != "client-model" { t.Fatalf("expected AI chat service input from canvas route, got %#v", aiChatService.input) }
}
```

- [ ] **Step 2: Verify RED**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/server -run TestRouterInstallsCanvasAIChatRouteFromAIChatService -count=1
```

Expected:

```text
FAIL
expected AI chat service input from canvas route
```

- [ ] **Step 3: Register `aichatcanvas` in server route file**

In `admin_back_go/internal/server/routes_canvas.go`, add import:

```go	aichatcanvas "admin_back_go/internal/module/ai/chat/transport/canvas"
```

Change `registerCanvasRoutes` to:

```go
func registerCanvasRoutes(router *gin.Engine, deps Dependencies) {
	canvastransport.RegisterRoutes(router, deps.CanvasService)
	aiimagecanvas.RegisterRoutes(router, deps.AiImageService)
	aichatcanvas.RegisterRoutes(router, deps.AiChatService)
}
```

- [ ] **Step 4: Remove chat from Canvas transport**

In `admin_back_go/internal/module/canvas/transport/canvas/route.go`, delete:

```go
group.POST("/ai/chat/completions", handler.ChatCompletions)
```

Keep:

```go
group.POST("/ai/videos", handler.VideoGenerations)
group.GET("/ai/videos/:id", handler.VideoStatus)
group.GET("/ai/videos/:id/content", handler.VideoContent)
```

In `handler.go`, delete `ChatCompletion` from `HTTPService`, delete `Handler.ChatCompletions`, and delete `failingService.ChatCompletion`.

In `request.go`, delete `chatCompletionRequest`.

- [ ] **Step 5: Update Canvas transport tests**

In `admin_back_go/internal/module/canvas/transport/canvas/handler_test.go`, remove `chatInput` and fake `ChatCompletion` from `fakeCanvasService`.

Rename `TestCanvasAIRoutesUseAuthenticatedUserAndDoNotLeakProviderConfig` to:

```go
func TestCanvasVideoRoutesUseAuthenticatedUserAndDoNotLeakProviderConfig(t *testing.T)
```

Delete the chat request block in that test. Add this test:

```go
func TestCanvasTransportDoesNotOwnAIChatRoute(t *testing.T) {
	gin.SetMode(gin.ReleaseMode)
	service := &fakeCanvasService{}
	router := gin.New()
	router.Use(func(c *gin.Context) { c.Set(middleware.ContextAuthIdentity, &middleware.AuthIdentity{UserID: 9, Platform: "canvas"}) })
	RegisterRoutes(router, service)

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodPost, "/api/canvas/v1/ai/chat/completions", strings.NewReader(`{"agent_id":7,"message":"hello"}`))
	request.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusNotFound { t.Fatalf("canvas transport must not own AI chat completion route, got code=%d body=%s", recorder.Code, recorder.Body.String()) }
}
```

- [ ] **Step 6: Update server fake Canvas service**

In `admin_back_go/internal/server/router_test.go`, remove `chatInput` from `fakeRouterCanvasService` and delete its fake `ChatCompletion` method.

- [ ] **Step 7: Verify GREEN and commit**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/server ./internal/module/canvas/transport/canvas ./internal/module/ai/chat/transport/canvas -count=1
```

Expected:

```text
ok  	admin_back_go/internal/server
ok  	admin_back_go/internal/module/canvas/transport/canvas
ok  	admin_back_go/internal/module/ai/chat/transport/canvas
```

Commit:

```powershell
cd E:\admin_go
git add admin_back_go/internal/server/routes_canvas.go admin_back_go/internal/server/router_test.go admin_back_go/internal/module/canvas/transport/canvas/route.go admin_back_go/internal/module/canvas/transport/canvas/request.go admin_back_go/internal/module/canvas/transport/canvas/handler.go admin_back_go/internal/module/canvas/transport/canvas/handler_test.go
git commit -m "refactor(canvas): route chat through ai chat transport"
```
---

### Task 4: Remove Canvas chat runtime ownership and add architecture guards

**Files:**
- Modify: `admin_back_go/internal/architecture/platform_route_line_test.go`
- Modify: `admin_back_go/internal/module/canvas/service.go`
- Modify: `admin_back_go/internal/module/canvas/service_test.go`
- Modify: `admin_back_go/internal/module/canvas/dto.go`
- Delete: `admin_back_go/internal/module/canvas/text_runtime.go`
- Delete: `admin_back_go/internal/module/canvas/text_runtime_test.go`
- Delete: `admin_back_go/internal/module/canvas/text_repository.go`
- Modify: `admin_back_go/internal/bootstrap/app.go`

- [ ] **Step 1: Write RED architecture guards**

In `admin_back_go/internal/architecture/platform_route_line_test.go`, add:

```go
func TestCanvasAIChatRoutesOwnedByAIChatTransport(t *testing.T) {
	root := backendRoot(t)
	canvasRoute := readRouteLineSource(t, root, "internal/module/canvas/transport/canvas/route.go")
	mustNotContainRouteLine(t, canvasRoute, `"/ai/chat`)
	aiChatCanvasRoute := filepath.Join(root, "internal", "module", "ai", "chat", "transport", "canvas", "route.go")
	if _, err := os.Stat(aiChatCanvasRoute); err != nil { t.Fatalf("expected ai chat canvas route transport to exist: %v", err) }
	routesCanvas := readRouteLineSource(t, root, "internal/server/routes_canvas.go")
	mustContainRouteLine(t, routesCanvas, `aichatcanvas "admin_back_go/internal/module/ai/chat/transport/canvas"`)
	mustContainRouteLine(t, routesCanvas, `aichatcanvas.RegisterRoutes(router, deps.AiChatService)`)
}

func TestAIChatCanvasTransportDoesNotImportCanvasModule(t *testing.T) {
	root := backendRoot(t)
	transportRoot := filepath.Join(root, "internal", "module", "ai", "chat", "transport", "canvas")
	var offenders []string
	err := filepath.WalkDir(transportRoot, func(path string, entry os.DirEntry, walkErr error) error { if walkErr != nil { return walkErr }; if entry.IsDir() || filepath.Ext(path) != ".go" || strings.HasSuffix(path, "_test.go") { return nil }; body, err := os.ReadFile(path); if err != nil { return err }; if strings.Contains(string(body), `admin_back_go/internal/module/canvas`) { rel, _ := filepath.Rel(root, path); offenders = append(offenders, filepath.ToSlash(rel)) }; return nil })
	if err != nil { t.Fatalf("walk ai chat canvas transport: %v", err) }
	if len(offenders) > 0 { t.Fatalf("ai/chat canvas transport must not import canvas module; offenders=%v", offenders) }
}

func TestCanvasModuleProductionCodeDoesNotOwnAIChatRuntime(t *testing.T) {
	root := backendRoot(t)
	canvasRoot := filepath.Join(root, "internal", "module", "canvas")
	forbidden := []string{"ChatCompletion(", "ChatCompletionInput", "ChatCompletionResponse", "TextRuntimeService", "NewTextRuntimeService", "TextGormRepository", "NewTextGormRepository", "AgentForTextRuntime"}
	var offenders []string
	err := filepath.WalkDir(canvasRoot, func(path string, entry os.DirEntry, walkErr error) error { if walkErr != nil { return walkErr }; if entry.IsDir() || filepath.Ext(path) != ".go" || strings.HasSuffix(path, "_test.go") { return nil }; body, err := os.ReadFile(path); if err != nil { return err }; text := string(body); for _, token := range forbidden { if strings.Contains(text, token) { rel, _ := filepath.Rel(root, path); offenders = append(offenders, filepath.ToSlash(rel)+" contains "+token) } }; return nil })
	if err != nil { t.Fatalf("walk canvas module: %v", err) }
	if len(offenders) > 0 { t.Fatalf("canvas module production code must not own AI chat runtime:\n  %s", strings.Join(offenders, "\n  ")) }
}
```

- [ ] **Step 2: Verify RED**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture -run 'TestCanvasAIChatRoutesOwnedByAIChatTransport|TestAIChatCanvasTransportDoesNotImportCanvasModule|TestCanvasModuleProductionCodeDoesNotOwnAIChatRuntime' -count=1
```

Expected:

```text
FAIL
canvas module production code must not own AI chat runtime
```

- [ ] **Step 3: Remove Canvas service chat method**

In `admin_back_go/internal/module/canvas/service.go`, remove `fmt` from imports. Change `SettingsDependencies` to:

```go
type SettingsDependencies struct { AuthPolicy AuthPolicyService; Video VideoRuntime }
```

Delete `func (s *Service) ChatCompletion(...)` entirely.

- [ ] **Step 4: Remove Canvas chat/text DTOs**

In `admin_back_go/internal/module/canvas/dto.go`, delete:

```go
type ChatCompletionInput struct { UserID int64; AgentID int64; ModelID string; Message string }
type ChatCompletionResponse struct { ID string `json:"id"`; Object string `json:"object"`; Content string `json:"content"` }
type TextRuntime interface { Generate(ctx context.Context, input TextGenerationInput) (*TextGenerationResponse, *apperror.Error) }
type TextGenerationInput struct { UserID int64; AgentID int64; ModelID string; Message string }
type TextGenerationResponse struct { Content string }
type TextAgentRuntime struct { AgentID int64; ProviderID int64; ModelID string; ModelDisplayName string; SystemPrompt string; ScenesJSON string; EngineType string; EngineBaseURL string; EngineAPIKeyEnc string; AgentStatus int; EngineStatus int }
type TextRepository interface { AgentForTextRuntime(ctx context.Context, agentID int64) (*TextAgentRuntime, error) }
type TextEngineFactory interface { NewEngine(ctx context.Context, input TextEngineConfig) (infraai.Engine, error) }
type TextEngineConfig struct { EngineType infraai.EngineType; BaseURL string; APIKey string }
```

- [ ] **Step 5: Delete Canvas text runtime files**

Run:

```powershell
cd E:\admin_go
Remove-Item -LiteralPath .\admin_back_go\internal\module\canvas\text_runtime.go
Remove-Item -LiteralPath .\admin_back_go\internal\module\canvas\text_runtime_test.go
Remove-Item -LiteralPath .\admin_back_go\internal\module\canvas\text_repository.go
```

- [ ] **Step 6: Remove Canvas chat service tests**

In `admin_back_go/internal/module/canvas/service_test.go`, delete:

```go
func TestServiceChatCompletionUsesCanvasTextRuntime(t *testing.T)
func TestServiceChatCompletionDoesNotReturnNotImplemented(t *testing.T)
type fakeCanvasTextRuntime struct
func (f *fakeCanvasTextRuntime) Generate(...)
```

Remove unused imports after deletion.

- [ ] **Step 7: Remove Canvas text runtime from bootstrap**

In `admin_back_go/internal/bootstrap/app.go`, delete `canvasTextRuntime := ...`, remove `Text: canvasTextRuntime` from `SettingsDependencies`, and delete `canvasTextEngineFactory` with its `NewEngine` method.

The Canvas service construction must be:

```go
canvasService := canvasmodule.NewServiceWithSettings(canvasmodule.NewGormRepository(resources.DB), canvasmodule.SettingsDependencies{
	AuthPolicy: authPlatformService,
	Video:      canvasVideoRuntime,
})
```

- [ ] **Step 8: Verify GREEN**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture ./internal/module/canvas ./internal/module/canvas/transport/canvas ./internal/module/ai/chat ./internal/module/ai/chat/transport/canvas ./internal/server -count=1
```

Expected:

```text
ok  	admin_back_go/internal/architecture
ok  	admin_back_go/internal/module/canvas
ok  	admin_back_go/internal/module/canvas/transport/canvas
ok  	admin_back_go/internal/module/ai/chat
ok  	admin_back_go/internal/module/ai/chat/transport/canvas
ok  	admin_back_go/internal/server
```

- [ ] **Step 9: Search leftovers**

Run:

```powershell
cd E:\admin_go
rg -n 'ChatCompletion|TextRuntimeService|NewTextRuntimeService|TextGormRepository|AgentForTextRuntime|/ai/chat' .\admin_back_go\internal\module\canvas .\admin_back_go\internal\server\routes_canvas.go .\admin_back_go\internal\module\ai\chat\transport\canvas -g '!**/*_test.go'
```

Expected allowed output:

```text
admin_back_go/internal/module/ai/chat/transport/canvas/route.go: group := router.Group("/api/canvas/v1/ai/chat")
```

- [ ] **Step 10: Commit Task 4**

Run:

```powershell
cd E:\admin_go
git add admin_back_go/internal/architecture/platform_route_line_test.go admin_back_go/internal/module/canvas/service.go admin_back_go/internal/module/canvas/service_test.go admin_back_go/internal/module/canvas/dto.go admin_back_go/internal/bootstrap/app.go admin_back_go/internal/module/canvas/text_runtime.go admin_back_go/internal/module/canvas/text_runtime_test.go admin_back_go/internal/module/canvas/text_repository.go
git commit -m "refactor(canvas): remove chat runtime ownership"
```

---

### Task 5: Final verification

**Files:** Verify only unless a command exposes a real mismatch.

- [ ] **Step 1: Run targeted tests**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture ./internal/module/ai/chat ./internal/module/ai/chat/transport/canvas ./internal/module/canvas ./internal/module/canvas/transport/canvas ./internal/server -count=1
```

Expected all listed packages return `ok`.

- [ ] **Step 2: Verify source ownership**

```powershell
cd E:\admin_go
rg -n 'ai/chat|ai/videos|aiimagecanvas|aichatcanvas|RegisterRoutes\(router, deps\.(CanvasService|AiImageService|AiChatService)' .\admin_back_go\internal\module\canvas\transport\canvas\route.go .\admin_back_go\internal\module\ai\chat\transport\canvas\route.go .\admin_back_go\internal\module\ai\image\transport\canvas\route.go .\admin_back_go\internal\server\routes_canvas.go
```

Expected decisive lines:

```text
admin_back_go/internal/module/ai/chat/transport/canvas/route.go: group := router.Group("/api/canvas/v1/ai/chat")
admin_back_go/internal/module/canvas/transport/canvas/route.go: group.POST("/ai/videos", handler.VideoGenerations)
admin_back_go/internal/server/routes_canvas.go: aichatcanvas.RegisterRoutes(router, deps.AiChatService)
```

- [ ] **Step 3: Run governance**

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected:

```text
PASS: no blocking governance violations found.
```

- [ ] **Step 4: Inspect working tree**

```powershell
cd E:\admin_go
git status --short
```

Expected for this slice: no modified tracked files. Pre-existing untracked paths such as `docs/interview/` must not be committed by this plan.

## Completion criteria

```text
POST /api/canvas/v1/ai/chat/completions still returns id/object/content
server registers aichatcanvas.RegisterRoutes(router, deps.AiChatService)
canvas transport no longer registers /ai/chat
canvas transport still registers /ai/videos routes
ai/chat service owns CanvasCompletion
CanvasCompletion accepts only canvas_text_generate agents
CanvasCompletion uses agent model_id instead of client model override
CanvasCompletion does not write conversation/message/run records
CanvasCompletion does not publish WebSocket events
canvas text runtime/repository files are removed
architecture guards prevent chat route/runtime ownership from returning to canvas
final targeted Go tests pass
root governance checks pass
```
