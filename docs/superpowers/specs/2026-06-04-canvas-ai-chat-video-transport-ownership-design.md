# Canvas AI Chat/Video Transport Ownership Design

日期：2026-06-04

## 需求分析

### 【需求判断】

是真问题。

`internal/module/canvas/transport/canvas` 现在仍注册 Canvas AI text/video 路由：

```text
POST /api/canvas/v1/ai/chat/completions
POST /api/canvas/v1/ai/videos
GET  /api/canvas/v1/ai/videos/:id
GET  /api/canvas/v1/ai/videos/:id/content
```

昨天的 image transport ownership plan 只完成了 `/api/canvas/v1/ai/images/*` owner 迁移，chat/video 被明确留给 follow-up。现在要补的不是“修漏掉的一行 route”，而是把 Canvas AI text/video 从 Canvas 平台壳里抽回 AI capability owner。

### 【核心问题】

真正要解决的是 route owner 和 runtime owner 的错位：

```text
canvas = Canvas 平台入口和平台配置
ai/chat = 文本/对话能力 owner
ai/video = 视频生成能力 owner
```

外部 URL 里包含 `/api/canvas/v1`，只说明这是 Canvas 平台入口；不说明业务能力 owner 应该是 `internal/module/canvas`。

### 【复杂度检查】

不要一刀乱搬。

Chat 和 video 的成熟度不同：

- Canvas chat 当前是 stateless completion，不等同于 admin AI conversation/message/run 的会话流。
- Canvas video 当前有 `canvas_video_tasks` 和 provider task lifecycle，但还没有独立 `internal/module/ai/video` capability。
- `canvas_video_tasks` 是已验证的运行时表，不能为了目录好看改表名。

所以实现必须拆成两个窄切片：

```text
Phase A: Canvas chat route owner 迁到 ai/chat/transport/canvas
Phase B: Canvas video capability 抽到 ai/video，再迁 ai/video/transport/canvas
```

### 【破坏性分析】

不能破坏：

- 外部 URL。
- request/response JSON 字段。
- auth identity 取 user_id 的方式。
- Canvas free-generation：不查余额、不扣款、不写 `ai_billing_records`。
- Canvas settings 的 `agents.text|image|video` 返回。
- `canvas_video_tasks` 表名和 `id + user_id + is_del=2` ownership 校验。

## 现状证据

### 已经完成的部分

`/api/canvas/v1/ai/images/*` 已经由 `internal/module/ai/image/transport/canvas` 拥有。

```text
internal/module/ai/image/transport/canvas
  POST /api/canvas/v1/ai/images/generations
  POST /api/canvas/v1/ai/images/edits
  GET  /api/canvas/v1/ai/images/:id
```

`internal/server/routes_canvas.go` 当前分别注册 Canvas platform transport 和 AI image Canvas transport。

### 仍然错位的部分

当前 `internal/module/canvas/transport/canvas/route.go` 仍拥有：

```text
POST /api/canvas/v1/ai/chat/completions
POST /api/canvas/v1/ai/videos
GET  /api/canvas/v1/ai/videos/:id
GET  /api/canvas/v1/ai/videos/:id/content
```

当前 Canvas service 仍包含：

```text
ChatCompletion
GenerateVideo
VideoStatus
VideoContent
```

当前 Canvas module 仍包含：

```text
TextRuntimeService
VideoRuntimeService
VideoGormRepository
VideoTask.TableName() = canvas_video_tasks
```

这些是架构债，不是功能异常。运行时可以工作，但 owner 不干净。

## 方案取舍

### 方案 A：只移动 route，service 仍反向依赖 canvas

做法：新建 `ai/chat/transport/canvas` 和 `ai/video/transport/canvas`，但 handler 继续调用 `canvas.Service`。

结论：不采用。

这是假迁移。目录看起来对了，依赖方向仍然错了：AI capability transport 反向依赖 Canvas platform service。特殊情况没有消灭，只是藏起来。

### 方案 B：一次性迁 chat + video + 表结构

做法：一刀把 chat、video、任务表、runtime、provider status、content download 全部抽走，甚至重命名 `canvas_video_tasks`。

结论：不采用。

这会扩大破坏面。Video 是异步任务，有 provider task id、status polling、content streaming 和 live DB 表；一次性改表名或语义没有收益，只有风险。

### 方案 C：先 chat，后 video，外部契约不动

做法：

1. Phase A：把 Canvas stateless chat completion 收到 `ai/chat`，新建 `internal/module/ai/chat/transport/canvas`。
2. Phase B：新增 `internal/module/ai/video`，保留 `canvas_video_tasks` 表名，把 video runtime/repository/task owner 从 `canvas` 移过去，再新建 `internal/module/ai/video/transport/canvas`。
3. 每一 phase 都先加失败测试和 route owner guard，再改生产代码。

结论：采用。

这是最小可验证方案。它不改 URL，不改前端，不改 billing，不改 Canvas settings；只修正 owner 和依赖方向。

## 目标架构

### Route owner

迁移完成后：

```text
internal/module/canvas/transport/canvas
  GET /api/canvas/v1/settings
  GET /api/canvas/v1/prompts
  GET /api/canvas/v1/assets

internal/module/ai/image/transport/canvas
  POST /api/canvas/v1/ai/images/generations
  POST /api/canvas/v1/ai/images/edits
  GET  /api/canvas/v1/ai/images/:id

internal/module/ai/chat/transport/canvas
  POST /api/canvas/v1/ai/chat/completions

internal/module/ai/video/transport/canvas
  POST /api/canvas/v1/ai/videos
  GET  /api/canvas/v1/ai/videos/:id
  GET  /api/canvas/v1/ai/videos/:id/content
```

### Dependency direction

允许：

```text
server -> module/*/transport/{platform}
transport/canvas -> same capability service interface
ai/chat -> infra/ai + ai_agents runtime data
ai/video -> infra/ai + ai_agents runtime data + canvas_video_tasks physical table
canvas -> Canvas platform config/prompts/assets
```

禁止：

```text
ai/chat/transport/canvas -> canvas.Service
ai/video/transport/canvas -> canvas.Service
canvas.Service -> ai/chat runtime
canvas.Service -> ai/video runtime
canvas/transport/canvas -> /ai/chat or /ai/videos routes
```

### Canvas settings 保留在 canvas

`GET /api/canvas/v1/settings` 仍属于 Canvas 平台启动配置。

它可以继续返回：

```text
agents.text  from ai_agents scenes_json contains canvas_text_generate
agents.image from ai_agents scenes_json contains canvas_image_generate
agents.video from ai_agents scenes_json contains canvas_video_generate
```

这不是 AI runtime owner。settings 是平台配置聚合，generation task 才是 AI capability owner。

## Phase A：Canvas chat owner 迁移

### 目标

把：

```text
POST /api/canvas/v1/ai/chat/completions
```

从：

```text
internal/module/canvas/transport/canvas
```

迁到：

```text
internal/module/ai/chat/transport/canvas
```

外部 URL 和 JSON 契约不变。

### Endpoint contract

```text
POST /api/canvas/v1/ai/chat/completions
```

Request：

```ts
interface CanvasChatCompletionRequest {
  agent_id: number
  message: string
  model?: string
}
```

Response data：

```ts
interface CanvasChatCompletionResponse {
  id: string
  object: 'chat.completion'
  content: string
}
```

Envelope 继续使用统一 response wrapper。

### Service contract

在 `internal/module/ai/chat` 下增加明确的 Canvas stateless completion 能力，不接 admin conversation 的 message/run 表。

推荐内部输入：

```go
type CanvasCompletionInput struct {
    UserID  int64
    AgentID int64
    ModelID string
    Message string
}
```

推荐内部输出：

```go
type CanvasCompletionResponse struct {
    ID      string `json:"id"`
    Object  string `json:"object"`
    Content string `json:"content"`
}
```

推荐 service 方法：

```go
CanvasCompletion(ctx context.Context, input CanvasCompletionInput) (*CanvasCompletionResponse, *apperror.Error)
```

当前 `aichat.HTTPService` 是空接口，这本身没意义。Phase A 应把它改成真实接口，至少包含 Canvas completion 方法，让 `server.Dependencies.AiChatService` 可以被 `ai/chat/transport/canvas` 复用。

### Runtime behavior

Canvas chat completion 必须保持 stateless：

- 不创建 `ai_conversations`。
- 不写 `ai_messages`。
- 不写 `ai_runs`。
- 不发 WebSocket event。
- 不走 AI billing。
- 不接受前端覆盖 provider model；`model` 字段即使传入，也只能保持兼容读取，实际模型来自选中的 `ai_agents.model_id`。

Agent 必须满足：

```text
ai_agents.status = enabled
provider/model runtime enabled
scenes_json contains canvas_text_generate
provider API key configured and decryptable
```

Provider 调用保持当前语义：

```text
UserKey = canvas:{user_id}
Content = message
Inputs.model_id = agent model_id
Inputs.system_prompt = agent system_prompt when present
```

### Error behavior

保持现有外部错误语义，错误 key 可以继续使用 `canvas.ai.chat.*`，因为这是 Canvas 平台入口的用户可见错误，不是模块路径。

核心错误：

```text
unauthorized user -> auth.token.invalid_or_expired
invalid request -> canvas.ai.chat.request.invalid
agent not found -> canvas.ai.chat.agent_not_found
agent wrong scene/disabled -> canvas.ai.chat.agent_unavailable
provider key missing -> canvas.ai.chat.provider_key_missing
provider failed -> canvas.ai.chat.provider_failed
empty provider result -> canvas.ai.chat.empty_result
service misconfigured -> canvas.ai.chat.*_missing
```

不要用空字符串或默认 content 掩盖 provider 空结果；如果 provider 理论上应返回内容，空结果就是错误。

### Files expected to change in Phase A

新增：

```text
admin_back_go/internal/module/ai/chat/transport/canvas/route.go
admin_back_go/internal/module/ai/chat/transport/canvas/handler.go
admin_back_go/internal/module/ai/chat/transport/canvas/request.go
admin_back_go/internal/module/ai/chat/transport/canvas/handler_test.go
```

修改：

```text
admin_back_go/internal/module/ai/chat/dto.go
admin_back_go/internal/module/ai/chat/service.go
admin_back_go/internal/module/ai/chat/repository.go
admin_back_go/internal/module/ai/chat/service_test.go
admin_back_go/internal/module/canvas/transport/canvas/route.go
admin_back_go/internal/module/canvas/transport/canvas/handler.go
admin_back_go/internal/module/canvas/transport/canvas/request.go
admin_back_go/internal/module/canvas/transport/canvas/handler_test.go
admin_back_go/internal/module/canvas/service.go
admin_back_go/internal/module/canvas/dto.go
admin_back_go/internal/module/canvas/text_runtime.go
admin_back_go/internal/module/canvas/text_repository.go
admin_back_go/internal/server/routes_canvas.go
admin_back_go/internal/server/router_test.go
admin_back_go/internal/bootstrap/app.go
```

是否物理删除 `canvas/text_runtime.go` 和 `canvas/text_repository.go` 由实现计划决定；最低要求是 Canvas production route/service 不再拥有 chat completion。

## Phase B：Canvas video capability 抽取

### 目标

把：

```text
POST /api/canvas/v1/ai/videos
GET  /api/canvas/v1/ai/videos/:id
GET  /api/canvas/v1/ai/videos/:id/content
```

从：

```text
internal/module/canvas/transport/canvas
```

迁到：

```text
internal/module/ai/video/transport/canvas
```

并新增：

```text
internal/module/ai/video
```

### Endpoint contract

Create request：

```ts
interface CanvasVideoGenerationRequest {
  agent_id: number
  prompt: string
  duration_seconds?: number
  size?: string
  resolution_name?: string
  model?: string
}
```

Create response data：

```ts
interface CanvasVideoGenerationResponse {
  id: number
  status: 'pending' | 'running' | 'completed' | 'failed' | 'cancelled'
}
```

Status response data：

```ts
interface CanvasVideoStatusResponse {
  id: number
  status: 'pending' | 'running' | 'completed' | 'failed' | 'cancelled'
}
```

Content response：

```text
binary body
Content-Type = provider content type, fallback application/octet-stream only when provider omits it
```

### Data ownership

`ai/video` owns the model and repository, but physical table name stays:

```text
canvas_video_tasks
```

Good taste here is not renaming a live table for aesthetics. The table name is compatibility; module owner is code responsibility.

`VideoTask.TableName()` should remain:

```go
func (VideoTask) TableName() string { return "canvas_video_tasks" }
```

Ownership check remains:

```text
id + user_id + is_del = active
```

Do not let the frontend pass `user_id`.

### Runtime behavior

Video service must preserve current behavior:

- Create local task first with `pending`.
- Call provider `CreateVideo` with model from selected agent, not client `model`.
- Store `provider_task_id` when provider returns a valid task id.
- On provider create failure, mark local task `failed` with error message.
- Status polling calls provider `GetVideo` only after loading owned local task.
- Content streaming calls provider `DownloadVideo` only after loading owned local task.
- Status normalizer keeps current accepted values and maps unknown provider status to existing safe status rules.
- No billing.

Agent must satisfy:

```text
scenes_json contains canvas_video_generate
agent enabled
provider/model runtime enabled
provider API key configured and decryptable
```

### Error behavior

Keep current external error keys stable at first migration:

```text
canvas.ai.video.request.invalid
canvas.ai.video.agent_not_found
canvas.ai.video.agent_unavailable
canvas.ai.video.provider_key_missing
canvas.ai.video.provider_failed
canvas.ai.video.provider_task_invalid
canvas.ai.video.task_create_failed
canvas.ai.video.task_update_failed
canvas.ai.video.task_query_failed
canvas.ai.video.provider_status_failed
canvas.ai.video.provider_content_failed
canvas.ai.video.not_found
```

Do not replace missing task/provider id with fake defaults. Missing `provider_task_id` is an invalid task state and must return an error.

### Files expected to change in Phase B

新增：

```text
admin_back_go/internal/module/ai/video/dto.go
admin_back_go/internal/module/ai/video/model.go
admin_back_go/internal/module/ai/video/service.go
admin_back_go/internal/module/ai/video/repository.go
admin_back_go/internal/module/ai/video/runtime.go
admin_back_go/internal/module/ai/video/transport/canvas/route.go
admin_back_go/internal/module/ai/video/transport/canvas/handler.go
admin_back_go/internal/module/ai/video/transport/canvas/request.go
admin_back_go/internal/module/ai/video/transport/canvas/handler_test.go
```

修改或删除：

```text
admin_back_go/internal/module/canvas/video_runtime.go
admin_back_go/internal/module/canvas/video_repository.go
admin_back_go/internal/module/canvas/model.go
admin_back_go/internal/module/canvas/service.go
admin_back_go/internal/module/canvas/dto.go
admin_back_go/internal/module/canvas/transport/canvas/route.go
admin_back_go/internal/module/canvas/transport/canvas/handler.go
admin_back_go/internal/module/canvas/transport/canvas/request.go
admin_back_go/internal/module/canvas/transport/canvas/handler_test.go
admin_back_go/internal/server/routes_canvas.go
admin_back_go/internal/server/router.go
admin_back_go/internal/server/router_test.go
admin_back_go/internal/bootstrap/app.go
```

最低要求：Canvas production route/service 不再拥有 video generation/status/content；`ai/video` 拥有 `canvas_video_tasks` read/write。

## Server registration

迁移完成后，Canvas route registration 应类似：

```go
func registerCanvasRoutes(router *gin.Engine, deps Dependencies) {
    canvastransport.RegisterRoutes(router, deps.CanvasService)
    aiimagecanvas.RegisterRoutes(router, deps.AiImageService)
    aichatcanvas.RegisterRoutes(router, deps.AiChatService)
    aivideocanvas.RegisterRoutes(router, deps.AiVideoService)
}
```

Phase A 只新增 `aichatcanvas`。Phase B 再新增 `aivideocanvas` 和 `AiVideoService` dependency。

不要让 `canvastransport.RegisterRoutes` 继续注册任何 `/ai/*` route。

## Frontend impact

Canvas Next 前端不应该需要改 URL。

必须保持这些调用不变：

```text
canvas_front_next -> POST /api/canvas/v1/ai/chat/completions
canvas_front_next -> POST /api/canvas/v1/ai/videos
canvas_front_next -> GET  /api/canvas/v1/ai/videos/:id
canvas_front_next -> GET  /api/canvas/v1/ai/videos/:id/content
```

如果实现计划发现前端 wrapper 字段和后端 request 不一致，应该先证明运行时不一致，再做最小兼容修正；不要为了后端目录迁移改用户侧交互。

## Architecture guards

### Phase A guard

新增或扩展 architecture test：

```text
canvas/transport/canvas/route.go must not contain "/ai/chat"
server/routes_canvas.go must import internal/module/ai/chat/transport/canvas
server/routes_canvas.go must call aichatcanvas.RegisterRoutes(router, deps.AiChatService)
```

同时保留 video known gap：Phase A 完成后 `/ai/videos` 仍可暂时在 canvas route，不能在 chat plan 里假装 video 已迁完。

### Phase B guard

新增或扩展 architecture test：

```text
canvas/transport/canvas/route.go must not contain "/ai/videos"
internal/module/ai/video/transport/canvas/route.go must own /api/canvas/v1/ai/videos routes
server/routes_canvas.go must import internal/module/ai/video/transport/canvas
server/routes_canvas.go must call aivideocanvas.RegisterRoutes(router, deps.AiVideoService)
canvas production files must not contain VideoRuntimeService, VideoGormRepository, or VideoTask TableName ownership
```

### Dependency guard

最终状态下禁止：

```text
internal/module/ai/chat/transport/canvas imports internal/module/canvas
internal/module/ai/video imports internal/module/canvas
internal/module/ai/video/transport/canvas imports internal/module/canvas
internal/module/canvas imports internal/module/ai/chat or internal/module/ai/video for generation runtime
```

## Testing strategy

### Phase A tests

先写失败测试：

```text
internal/architecture: canvas route must not own /ai/chat
internal/module/ai/chat/transport/canvas: handler parses request and injects auth user id
internal/module/ai/chat: CanvasCompletion uses canvas_text_generate agent scene
internal/module/ai/chat: client model override does not replace agent model
internal/module/ai/chat: empty provider answer fails, not silently defaulted
internal/server: POST /api/canvas/v1/ai/chat/completions still works through full router
internal/module/canvas/transport/canvas: no chat route remains
```

Recommended verification command：

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture ./internal/module/ai/chat ./internal/module/ai/chat/transport/canvas ./internal/module/canvas ./internal/module/canvas/transport/canvas ./internal/server -count=1
```

### Phase B tests

先写失败测试：

```text
internal/architecture: canvas route must not own /ai/videos
internal/module/ai/video: create stores canvas_video_tasks row and provider_task_id
internal/module/ai/video: create failure marks local task failed
internal/module/ai/video: status/content require id + user_id + active ownership
internal/module/ai/video: client model override does not replace agent model
internal/module/ai/video/transport/canvas: handlers parse request/path and inject auth user id
internal/server: POST/GET /api/canvas/v1/ai/videos* still works through full router
internal/module/canvas/transport/canvas: no video routes remain
```

Recommended verification command：

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture ./internal/module/ai/video ./internal/module/ai/video/transport/canvas ./internal/module/canvas ./internal/module/canvas/transport/canvas ./internal/server -count=1
```

### Governance checks

每个 phase 完成后运行：

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

## Non-goals

本 spec 不做：

- 不改 `/api/canvas/v1/ai/*` 外部 URL。
- 不改 Canvas 前端页面行为。
- 不把 Canvas stateless chat 接入 admin conversation history。
- 不新增 Canvas chat WebSocket。
- 不重命名 `canvas_video_tasks`。
- 不恢复或引入 AI billing。
- 不让前端传 provider/model 覆盖后端智能体选择。
- 不把 `settings` 从 canvas 抽走。
- 不做 provider SDK 大重构。

## Success criteria

Phase A 成功标准：

```text
POST /api/canvas/v1/ai/chat/completions external contract unchanged
route owner is internal/module/ai/chat/transport/canvas
Canvas transport no longer registers /ai/chat
Canvas service no longer owns ChatCompletion runtime
chat remains stateless and free
architecture/server/module tests pass
```

Phase B 成功标准：

```text
POST /api/canvas/v1/ai/videos external contract unchanged
GET /api/canvas/v1/ai/videos/:id external contract unchanged
GET /api/canvas/v1/ai/videos/:id/content external contract unchanged
route owner is internal/module/ai/video/transport/canvas
runtime owner is internal/module/ai/video
canvas_video_tasks physical table name remains unchanged
ownership check remains id + user_id + active
Canvas transport no longer registers /ai/videos
Canvas service no longer owns video generation/status/content runtime
architecture/server/module tests pass
```

Final clean state：

```text
canvas/transport/canvas owns only Canvas platform resources
ai/image/transport/canvas owns Canvas image generation routes
ai/chat/transport/canvas owns Canvas stateless chat route
ai/video/transport/canvas owns Canvas video routes
```

## 结论

值得做，但必须分两刀。

第一刀迁 chat，因为它可以保持 stateless、不加表、不碰前端。第二刀抽 video，因为它有任务表和 provider lifecycle，必须让 `ai/video` 真正拥有 runtime 和 repository，而不是只换 route 文件。

好品味不是把文件搬漂亮；好品味是让依赖方向、数据 owner、外部契约三件事同时干净。
