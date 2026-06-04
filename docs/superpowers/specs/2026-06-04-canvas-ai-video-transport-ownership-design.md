# Canvas AI Video Transport Ownership Design

日期：2026-06-04

## 需求分析

### 【需求判断】

是真问题。

Phase A 已经把 `POST /api/canvas/v1/ai/chat/completions` 从 `internal/module/canvas/transport/canvas` 迁到 `internal/module/ai/chat/transport/canvas`。现在剩下的错位点是 Canvas video：

```text
POST /api/canvas/v1/ai/videos
GET  /api/canvas/v1/ai/videos/:id
GET  /api/canvas/v1/ai/videos/:id/content
```

这些 URL 里的 `canvas` 是 platform surface，不是业务 owner。视频生成、provider task lifecycle、provider task id、status polling 和 content download 都是 AI video capability，不应该继续由 `internal/module/canvas` 拥有。

### 【核心问题】

真正要修的是数据 owner 和 runtime owner：

```text
canvas      = Canvas 平台配置、prompts、assets、settings 聚合
ai/video    = Canvas 视频生成 runtime、provider 调用、canvas_video_tasks 任务事实源
transport   = 每个 capability 对 Canvas platform 暴露自己的 HTTP 表面
```

外部 URL 不变，但代码 owner 必须变：

```text
internal/module/ai/video/transport/canvas
  POST /api/canvas/v1/ai/videos
  GET  /api/canvas/v1/ai/videos/:id
  GET  /api/canvas/v1/ai/videos/:id/content
```

### 【复杂度检查】

不能只移动 route。

只移动 route 但 handler 继续调用 `canvas.Service` 是假迁移，依赖方向仍然错。好品味不是把文件摆漂亮，而是让数据、状态流转和依赖方向一起干净。

也不能为了“AI video owner”重命名表。`canvas_video_tasks` 已经是 live runtime 表名，外部任务事实源和历史数据都依赖它。表名是兼容事实，不是代码 owner。

最小正确方案是：

```text
新增 internal/module/ai/video
保留 VideoTask.TableName() = "canvas_video_tasks"
把 VideoRuntimeService / VideoGormRepository / VideoTask / video DTO 移到 ai/video
新增 ai/video/transport/canvas
server 注册 aivideocanvas.RegisterRoutes(router, deps.AiVideoService)
canvas transport 和 canvas service 删除 video generation/status/content owner
```

### 【破坏性分析】

不能破坏：

- `POST /api/canvas/v1/ai/videos`
- `GET /api/canvas/v1/ai/videos/:id`
- `GET /api/canvas/v1/ai/videos/:id/content`
- create response `id/status`
- status response `id/status`
- content endpoint 的 binary body 和 provider content type
- `canvas_video_tasks` 表名
- `id + user_id + is_del = active` ownership 校验
- Canvas free-generation：不查余额、不扣款、不写 `ai_billing_records`
- 前端继续只传 `agent_id/prompt/duration_seconds/size/resolution_name/model`
- provider model 使用 `ai_agents.model_id`，不接受客户端 `model` 覆盖
- `/api/canvas/v1/settings` 仍由 canvas 返回 `agents.video`

## 当前状态证据

已经干净的部分：

```text
internal/module/ai/image/transport/canvas owns Canvas image routes
internal/module/ai/chat/transport/canvas owns Canvas chat route
```

仍然错位的部分：

```text
internal/module/canvas/transport/canvas/route.go still owns /ai/videos routes
internal/module/canvas/service.go still owns GenerateVideo / VideoStatus / VideoContent
internal/module/canvas/video_runtime.go still owns provider video runtime
internal/module/canvas/video_repository.go still owns canvas_video_tasks repository
internal/module/canvas/model.go still defines VideoTask.TableName() = canvas_video_tasks
```

这些是架构债，不是用户功能异常。迁移必须保持用户路径可用。

## 方案取舍

### 方案 A：只把 route 搬到 ai/video/transport/canvas

做法：新增 `ai/video/transport/canvas`，handler 继续依赖 `canvas.Service`。

结论：不采用。

这只是目录漂移。AI video transport 反向依赖 Canvas platform service，`canvas.Service` 仍然拥有 provider runtime 和任务生命周期。特殊情况没有消灭，只是藏起来。

### 方案 B：新增 ai/video，表也改名为 ai_video_tasks

做法：把 runtime 和 repository 都迁走，并把 physical table 从 `canvas_video_tasks` 改成 `ai_video_tasks`。

结论：不采用。

表名不是美学问题。`canvas_video_tasks` 是已经验证的 live runtime 表；为了目录好看改表名会引入迁移、回滚、历史任务读取和前端轮询风险，没有收益。

### 方案 C：新增 ai/video owner，保留 canvas_video_tasks 表名

做法：

1. 新建 `internal/module/ai/video`，接管 model / dto / repository / service runtime。
2. `VideoTask.TableName()` 继续返回 `canvas_video_tasks`。
3. 新建 `internal/module/ai/video/transport/canvas`，外部 URL 不变。
4. `canvas` 只保留 settings/prompts/assets；settings 继续返回 video agents。
5. 用 architecture guards 防止 `/ai/videos` 和 video runtime 回到 canvas。

结论：采用。

这是最小破坏、最大 owner 清晰度的方案。

## 目标架构

### Route owner

完成后：

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
server -> ai/video/transport/canvas
ai/video/transport/canvas -> ai/video.HTTPService
ai/video -> infra/ai.VideoEngine
ai/video -> ai_agents / ai_providers runtime data
ai/video -> canvas_video_tasks physical table
canvas -> Canvas prompts/assets/settings and ai_agents scene listing for settings facade
```

禁止：

```text
ai/video/transport/canvas -> internal/module/canvas
ai/video -> internal/module/canvas
canvas/transport/canvas -> /ai/videos routes
canvas.Service -> GenerateVideo / VideoStatus / VideoContent runtime
canvas module production code -> VideoRuntimeService / VideoGormRepository / AgentForVideoRuntime
```

## Endpoint contract

### Create

```text
POST /api/canvas/v1/ai/videos
```

Request：

```json
{
  "agent_id": 9,
  "prompt": "clip",
  "duration_seconds": 4,
  "size": "1280x720",
  "resolution_name": "720p",
  "model": "client-model"
}
```

`model` 只保留兼容读取，不用于 provider model 选择。

Response data：

```json
{
  "id": 77,
  "status": "pending"
}
```

### Status

```text
GET /api/canvas/v1/ai/videos/:id
```

Response data：

```json
{
  "id": 77,
  "status": "running"
}
```

### Content

```text
GET /api/canvas/v1/ai/videos/:id/content
```

Response：

```text
binary body
Content-Type = provider content type
fallback Content-Type = application/octet-stream only when provider returns empty content type
```

## ai/video service contract

新增 `internal/module/ai/video` package，包名建议 `aivideo`。

HTTP service：

```go
type HTTPService interface {
    Create(ctx context.Context, input CreateInput) (*CreateResponse, *apperror.Error)
    Status(ctx context.Context, userID int64, id int64) (*StatusResponse, *apperror.Error)
    Content(ctx context.Context, userID int64, id int64) ([]byte, string, *apperror.Error)
}
```

内部输入输出：

```go
type CreateInput struct {
    UserID          int64
    AgentID         int64
    ModelID         string
    Prompt          string
    DurationSeconds int
    Size            string
    ResolutionName  string
}

type CreateResponse struct {
    ID     int64  `json:"id"`
    Status string `json:"status"`
}

type StatusResponse struct {
    ID     int64  `json:"id"`
    Status string `json:"status"`
}
```

Runtime behavior：

1. 校验 `UserID > 0`、`AgentID > 0`、`Prompt` 非空。
2. 查询 `ai_agents` + `ai_providers` runtime config。
3. 只接受 `scenes_json` 包含 `canvas_video_generate` 的启用 agent。
4. 解密 provider key。
5. 先创建本地 `canvas_video_tasks` pending row。
6. 调用 provider `CreateVideo`，model 使用 agent `model_id`。
7. provider create 失败时，回写本地 task 为 `failed`。
8. provider task id 为空时，回写本地 task 为 `failed` 并返回显式错误。
9. status/content 先按 `id + user_id + is_del=2` 加载本地 task。
10. status/content 使用本地 task 的 `provider_task_id` 调 provider。
11. `provider_task_id` 为空是坏状态，必须报错，不生成假 id。

## Data ownership

`ai/video` 拥有这个 model：

```go
type VideoTask struct { ... }
func (VideoTask) TableName() string { return "canvas_video_tasks" }
```

这看起来像 Canvas 表名，但 owner 是 AI video。表名保留是兼容规则，不是模块归属规则。

Repository 继续使用：

```text
ai_agents AS a JOIN ai_providers e
canvas_video_tasks
```

任务 ownership 固定：

```text
WHERE user_id = ? AND id = ? AND is_del = 2
```

不要让前端传 `user_id`。

## Error behavior

错误 key 保持 Canvas user-facing 语义，不因为模块目录迁到 `ai/video` 而重命名：

```text
auth.token.invalid_or_expired
canvas.ai.video.request.invalid
canvas.ai.video.id.invalid
canvas.ai.video.agent_query_failed
canvas.ai.video.agent_not_found
canvas.ai.video.agent_unavailable
canvas.ai.video.provider_key_missing
canvas.ai.video.provider_key_decrypt_failed
canvas.ai.video.engine_missing
canvas.ai.video.engine_create_failed
canvas.ai.video.provider_failed
canvas.ai.video.provider_task_invalid
canvas.ai.video.provider_task_missing
canvas.ai.video.provider_status_failed
canvas.ai.video.provider_status_invalid
canvas.ai.video.provider_content_failed
canvas.ai.video.repository_missing
canvas.ai.video.task_create_failed
canvas.ai.video.task_update_failed
canvas.ai.video.task_query_failed
canvas.ai.video.not_found
canvas.ai.video.content_empty
```

空 provider result、空 provider task id、空 content 都是错误，不允许静默兜底。

## Server registration

完成后：

```go
func registerCanvasRoutes(router *gin.Engine, deps Dependencies) {
    canvastransport.RegisterRoutes(router, deps.CanvasService)
    aiimagecanvas.RegisterRoutes(router, deps.AiImageService)
    aichatcanvas.RegisterRoutes(router, deps.AiChatService)
    aivideocanvas.RegisterRoutes(router, deps.AiVideoService)
}
```

`server.Dependencies` 增加：

```go
AiVideoService aivideo.HTTPService
```

`bootstrap` 构造 `aiVideoService`，不再构造 `canvasVideoRuntime`。

## Testing strategy

先写失败测试，再改生产代码。

必须覆盖：

```text
internal/module/ai/video: create uses agent model, not client model
internal/module/ai/video: create creates local canvas_video_tasks task before provider call
internal/module/ai/video: provider create failure marks local task failed
internal/module/ai/video: provider task id empty marks task failed and returns explicit error
internal/module/ai/video: status/content require owned active local task
internal/module/ai/video: status/content use provider_task_id
internal/module/ai/video/transport/canvas: handler injects PlatformCanvas user id
internal/module/ai/video/transport/canvas: wrong platform identity is rejected
internal/server: /api/canvas/v1/ai/videos* still works through full router and AiVideoService
internal/module/canvas/transport/canvas: no video route remains
internal/architecture: canvas must not own /ai/videos or video runtime
```

Recommended final command：

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture ./internal/module/ai/video ./internal/module/ai/video/transport/canvas ./internal/module/canvas ./internal/module/canvas/transport/canvas ./internal/server -count=1
```

Root governance：

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

## Non-goals

本切片不做：

- 不改外部 URL。
- 不改 Canvas Next 前端调用。
- 不重命名 `canvas_video_tasks`。
- 不新增 AI billing。
- 不引入 WebSocket 视频事件。
- 不把 settings 从 canvas 抽走。
- 不新增 provider SDK 大重构。
- 不迁 image/chat 已完成 owner。
- 不做 admin AI video 页面。

## Success criteria

```text
POST /api/canvas/v1/ai/videos external contract unchanged
GET /api/canvas/v1/ai/videos/:id external contract unchanged
GET /api/canvas/v1/ai/videos/:id/content external contract unchanged
route owner is internal/module/ai/video/transport/canvas
runtime owner is internal/module/ai/video
repository owner is internal/module/ai/video
VideoTask.TableName() remains canvas_video_tasks
Canvas transport no longer registers /ai/videos
Canvas service no longer owns GenerateVideo / VideoStatus / VideoContent
Canvas production code no longer contains VideoRuntimeService / VideoGormRepository / AgentForVideoRuntime
server registers aivideocanvas.RegisterRoutes(router, deps.AiVideoService)
architecture guards prevent regression
targeted Go tests pass
root governance checks pass
```

## 结论

值得做，而且这是当前 Canvas AI owner 清理的最后一刀。

保持 URL 和表名不动，移动 runtime owner。这样用户空间不破，数据事实不破，依赖方向干净。
