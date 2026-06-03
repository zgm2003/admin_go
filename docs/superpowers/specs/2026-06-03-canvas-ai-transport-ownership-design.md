# Canvas AI Transport Ownership Design

## Linus 三问

1. **真问题还是假问题？**  
   真问题。`canvas` 现在同时承担 Canvas 专属资源、Canvas 平台 HTTP 壳、AI chat/image/video 路由聚合和部分 AI runtime。它能跑，但边界不干净；继续加功能会让 `canvas` 变成新一代垃圾桶。

2. **有更简单的做法吗？**  
   有。不要改外部 URL，不要重写前端，不要一次性重构所有 AI。先把已经有独立 capability 的 `ai/image` 接管 Canvas 图片 HTTP transport；再按同样规则迁 chat/video。

3. **会破坏已有前端、接口、登录和权限吗？**  
   不应该破坏。`/api/canvas/v1/ai/*` 外部路径、request/response envelope、鉴权方式、任务状态和前端轮询契约必须保持不变。变更只发生在后端 route owner 和内部依赖注入。

4. **为什么这个状态会出现？**  
   为了快速闭合 Canvas 前端，把 Canvas 当成一个产品壳层做了聚合。图片业务后来已经沉到 `internal/module/ai/image`，但 HTTP owner 还留在 `internal/module/canvas/transport/canvas`；文本和视频 runtime 也仍在 `canvas` 里。这是交付顺序留下的架构债，不是功能 bug。

## 需求判断

这个架构改动我认可，但必须按“兼容优先、窄切片迁移”的方式做。

当前规则里：

```text
module    = 业务能力：internal/module/{capability}/
transport = 能力对某个平台的 HTTP 表面：internal/module/{capability}/transport/{platform}/
platform  = admin / app / openapi / merchant / canvas 等入口
```

所以 `/api/canvas/v1/ai/images/*` 的外部路径虽然带着 `canvas`，但业务 owner 仍然应该是 `ai/image`，HTTP surface 应该是：

```text
internal/module/ai/image/transport/canvas
```

`canvas` module 应该只拥有 Canvas 产品自己的资源：

```text
/api/canvas/v1/settings
/api/canvas/v1/prompts
/api/canvas/v1/assets
未来如果做服务端画布项目，再放 /api/canvas/v1/canvas-projects 或类似 Canvas 专属资源
```

## 当前事实

### 前端事实

`canvas_front_next` 当前不是空壳。它已经有登录、RBAC shell、首页、我的画布、画布详情、图片工作台、视频工作台、提示词库、素材库、我的素材、个人资料和 API proxy。

但前端功能要分层看：

- 后端闭环：登录、当前用户、个人资料、settings、prompts、assets、AI image、AI video。
- 本地闭环：我的画布、我的素材、画布节点和本地生成资产缓存。
- 未完成为服务端 SaaS 闭环：服务端画布项目、服务端我的素材、服务端 Canvas 生成历史/任务中心。

这不是这次架构迁移要解决的问题。不能借 route owner 迁移顺手发明 `canvas_projects`、`canvas_user_assets` 或任务中心。

### 图片生成事实

图片生成已经是异步任务：

```text
前端 POST /api/canvas/v1/ai/images/generations
后端 ai/image 创建 ai_image_tasks pending
后端入队 ai:image-generate:v1
worker 执行 provider 生成
前端 GET /api/canvas/v1/ai/images/:id 轮询
```

这个链路方向正确。需要改的是 HTTP owner，不是异步模型。

### scene 事实

图片场景不是“必须两个 scene 才能生图”。

```text
image_generate        = admin 图片工作台场景
canvas_image_generate = Canvas 图片生成场景
```

Canvas 请求只应该要求 `canvas_image_generate`。同一个智能体想同时出现在 admin 图片工作台和 Canvas 前端，才需要同时配置两个 scene。

## 目标架构

### 1. Route owner 按 capability 归属

目标形态：

```text
internal/module/canvas/transport/canvas
  GET  /api/canvas/v1/settings
  GET  /api/canvas/v1/prompts
  GET  /api/canvas/v1/assets

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

外部 URL 保持原样。`canvas` 仍是平台入口名，不是业务 owner。

### 2. 图片先迁，因为它已经具备独立 capability

`ai/image` 已经拥有：

```text
ai_image_tasks
ai_image_assets
ai_image_task_assets
ai:image-generate:v1
Service.Create
Service.CreateWithUploadedAssets
Service.Detail
```

所以第一刀只需要新增 `ai/image/transport/canvas`，把 Canvas 图片 HTTP handler 从 `canvas/transport/canvas` 搬过去。

目标依赖方向：

```text
server routes
  -> ai/image/transport/canvas
      -> ai/image.Service

canvas module
  -> 不再 import ai/image DTO
  -> 不再拥有 /ai/images route
```

### 3. Chat 和 video 分阶段迁，不假装已经干净

Chat 和 video 当前比 image 更乱：

- Canvas chat 的 runtime 现在在 `internal/module/canvas/text_runtime.go`。
- Canvas video 的 task/runtime 现在在 `internal/module/canvas/video_runtime.go`。
- admin AI conversation/chat 另有现成 `ai/conversation`、`ai/message`、`ai/chat` 业务语义，不能随便拿来兼容 Canvas stateless chat completions。

因此不要在第一刀里强行迁 chat/video。正确顺序是：

1. 先迁 `ai/image/transport/canvas`，收掉最明显、风险最低的错位。
2. 再为 Canvas stateless chat 明确 owner：要么接入已有 `ai/chat` 的合适 service，要么先抽出一个薄的 `ai/chat` Canvas runtime adapter。
3. 最后再决定 video 是否建立 `internal/module/ai/video`。如果建立，就把 video task 表、runtime、provider status 拉出 `canvas`；如果暂时不建，就不要把 video route 假迁到 AI transport 里继续反向依赖 `canvas`。

## 详细设计：Image 第一刀

### 新增 transport

新增：

```text
internal/module/ai/image/transport/canvas/route.go
internal/module/ai/image/transport/canvas/handler.go
internal/module/ai/image/transport/canvas/handler_test.go
```

这个 transport 只做 HTTP 层工作：

- 读取 current user。
- 绑定 JSON 或 multipart。
- 校验 URL task id。
- 把 Canvas 平台语义显式写入 `aiimage.CreateInput.Platform = enum.PlatformCanvas`。
- 调用 `aiimage.Service`。
- 返回和现有 Canvas API 一样的 response envelope。

它不应该：

- 查询 Canvas prompts/assets/settings。
- 读写 Canvas 本地画布项目。
- 重新实现图片任务状态机。
- 改 `ai_image_tasks` 表结构。
- 发明新的 response shape。

### 收缩 canvas transport

从 `internal/module/canvas/transport/canvas` 移除：

```text
POST /ai/images/generations
POST /ai/images/edits
GET  /ai/images/:id
```

并删除 Canvas HTTPService 上图片相关方法：

```text
GenerateImage(...)
ImageStatus(...)
```

如果 `canvas.Service` 只因为图片路由才依赖 `aiimage`，这个依赖必须一起删除。

### Server 依赖注入

`internal/server` 应该显式注册两个 owner：

```text
canvastransport.RegisterRoutes(router, deps.CanvasService)
aiimagecanvas.RegisterRoutes(router, deps.AiImageService)
```

`Dependencies` 已经有 `AiImageService` 和 `CanvasService`，不要再让 `CanvasService` 代理 `AiImageService`。

### Bootstrap

`internal/bootstrap/app.go` 里仍然构造同一个 `aiImageService`。变化是：

- `aiImageService` 直接注入给 `server.Dependencies.AiImageService`。
- `canvasService` 的 settings deps 不再需要 `Image`。
- `canvasService` 仍负责 `/settings`，其中 image agent list 可以继续通过 Canvas repository 查 `canvas_image_generate`，因为 settings 是 Canvas 产品壳层能力。

这里有一个边界判断：`/settings` 返回 Canvas 可选 agent 列表，它属于 Canvas 前端启动配置；即使列表来自 `ai_agents` 表，也可以留在 Canvas module。真正的图片生成 task owner 必须在 `ai/image`。

## 后续设计：Chat

Canvas chat 当前是：

```text
POST /api/canvas/v1/ai/chat/completions
```

这个接口是 Canvas 前端的 stateless completion，不等同于 admin AI conversation 的 WebSocket 会话流。

迁移目标：

```text
internal/module/ai/chat/transport/canvas
```

但迁移前必须先定清楚 `ai/chat` 的 service 边界：

- 输入：`user_id`、`agent_id`、`message`
- 平台：`canvas`
- 输出：`id`、`object`、`content`
- 不写 `ai_conversations` / `ai_messages`，除非用户明确要 Canvas 聊天也进入会话历史。

第一版可以保持 stateless，不新增表，不接 WebSocket。

## 后续设计：Video

Canvas video 当前已经有 task 概念，但 runtime 在 `canvas` module 内。它比 image 更像“还没抽 capability”。

迁移目标可以是：

```text
internal/module/ai/video
internal/module/ai/video/transport/canvas
```

但这一步必须单独设计，不要跟 image 迁移混在一起。因为它可能涉及：

- video task model owner。
- repository 从 `canvas` 移到 `ai/video`。
- provider task status normalizer。
- content download 行为。
- 现有 `canvas_video_*` 表名是否保留。

如果为了兼容保留旧表名，也应该让 `ai/video` service 拥有这些表的读写。表名不等于 module owner。

## 架构 guard

必须新增或更新架构测试，防止回归：

### Image owner guard

RED 条件：

```text
internal/module/canvas/transport/canvas/route.go contains "/ai/images"
```

GREEN 条件：

```text
internal/module/ai/image/transport/canvas/route.go exists
internal/server/routes_canvas.go registers aiimagecanvas.RegisterRoutes
external URL remains /api/canvas/v1/ai/images/*
```

### Dependency guard

RED 条件：

```text
internal/module/canvas imports internal/module/ai/image
```

允许例外只能在测试 fake 里短期出现；生产代码不能有这个反向业务依赖。

### Contract guard

前端 service URL 不改：

```text
canvas_front_next/src/services/api/image.ts
  /api/canvas/v1/ai/images/generations
  /api/canvas/v1/ai/images/edits
  /api/canvas/v1/ai/images/:id
```

如果迁移导致这些路径变更，就是破坏用户空间。

## 测试策略

### 后端

必须跑：

```powershell
go test ./internal/module/ai/image ./internal/module/ai/image/transport/canvas ./internal/module/canvas ./internal/module/canvas/transport/canvas ./internal/server ./internal/architecture
```

关注点：

- Canvas image generation JSON request 仍返回 task id。
- Canvas image edit multipart request 仍把上传参考图注册为 COS input asset。
- Canvas image status 仍返回 task + outputs。
- Canvas prompts/assets/settings 不受影响。
- architecture guard 确认 `/ai/images` 不再由 canvas transport 拥有。

### 前端

必须跑：

```powershell
npm run typecheck
npm test
npm run build
```

工作目录：

```text
E:\admin_go\canvas_front_next
```

关注点：

- `requestGeneration` 创建 task 后仍轮询 `/api/canvas/v1/ai/images/:id`。
- `requestEdit` multipart 后仍轮询。
- 图片任务超时/失败错误文案不被本地兜底吞掉。

### Governance

docs/code 完成后必须跑：

```powershell
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

## 非目标

- 不改 `canvas_front_next` 的外部 API URL。
- 不把本地画布项目迁到服务端。
- 不新增 `canvas_projects`、`canvas_user_assets` 或生成历史中心。
- 不把 Canvas AI 生成接回旧 billing。
- 不一次性迁 chat/video。
- 不重写 AI provider adapter。
- 不改 `ai_image_tasks`、`ai_image_assets`、`ai_image_task_assets` 表结构。
- 不改变 `canvas_image_generate` scene 语义。

## 分阶段交付

### Phase 1：Image route owner 迁移

结果：

```text
/api/canvas/v1/ai/images/* 仍可用
owner 从 canvas transport 迁到 ai/image/transport/canvas
canvas module 生产代码不再 import ai/image
```

这是第一张实现计划应该覆盖的唯一代码迁移。

### Phase 2：Chat owner 设计和迁移

结果：

```text
/api/canvas/v1/ai/chat/completions 仍可用
owner 从 canvas transport 迁到 ai/chat/transport/canvas
保持 stateless completion，除非另开 spec 做 Canvas 会话历史
```

### Phase 3：Video capability 抽取

结果：

```text
/api/canvas/v1/ai/videos* 仍可用
video task/runtime owner 从 canvas 移到 ai/video
是否保留旧表名由兼容性决定
```

这一步需要单独 spec 或至少单独 implementation plan，因为它不只是搬 handler。

## 成功标准

Image 第一刀完成后必须满足：

```text
外部 URL 零变化
前端零改或仅测试基线更新
Canvas settings/prompts/assets 正常
Canvas image generation/edit/status 正常
ai:image-generate:v1 队列任务正常
canvas module 不再代理 ai/image task 创建和查询
architecture guard 防止 /ai/images 回到 canvas transport
```

## 结论

这次架构改动值得做。正确理由不是“目录更优雅”，而是：

```text
AI image 是 AI image 的业务能力，不是 Canvas 的业务能力。
Canvas 是平台入口和产品壳，不应该拥有 AI task 状态机。
URL 里的 canvas 是 platform，不是 module owner。
```

第一刀只迁 image，简单、可测、兼容、能回滚。chat/video 后续按同样规则处理，但不要把还没抽干净的 runtime 假装迁完。
