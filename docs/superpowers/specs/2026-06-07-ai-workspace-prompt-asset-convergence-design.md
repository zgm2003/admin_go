# AI 图片工作台、提示词、素材统一能力收敛 Spec

状态：Draft，等待确认后进入 implementation plan。
日期：2026-06-07

## 需求判断

【需求判断】
是真问题。现在的问题不是一个样式 bug，而是领域模型分裂：图片生成已经收敛到 `ai/image`，但 Admin 前端仍带着后台管理式的收藏、审核、筛选交互；Canvas 的提示词和素材仍落在 `canvas` 模块或浏览器本地状态里。这会继续制造重复表、重复接口、重复 UI 和权限漂移。

【核心问题】
同一套 AI 创作能力必须只有一套领域模型：

- 图片生成：`ai/image`
- 提示词库：`ai/prompt`
- 素材库：`ai/asset`

Admin 和 Canvas 只是两个 platform transport。不能因为当前入口不同就复制业务模块、复制表、复制交互。

【复杂度检查】
现状复杂度来自错误归属，而不是业务复杂：

- Admin 图片工作台出现 Canvas 没有的收藏/审核/状态筛选，属于伪需求。
- Canvas 提示词、素材放在 `canvas` module，属于能力归属错误。
- Canvas 我的素材仍有浏览器本地存储语义，和“后端持久化为准”的方向冲突。
- 403 被全局 AuthGuard 接管，可能把普通业务/API 403 变成整页无权限，交互层级错误。

【破坏性分析】
需要保护：

- 现有 Canvas 页面 URL：`/image`、`/prompts`、`/assets`。
- 现有 Canvas API 调用路径在迁移期间不能突然断：`/api/canvas/v1/prompts`、`/api/canvas/v1/assets`、`/api/canvas/v1/ai/images/*`。
- 现有 `canvas_prompts`、`canvas_assets` 数据必须迁移到 AI 归属表，不能丢。
- Admin/Canvas 权限必须保持 platform 语义；权限码是入口能力控制，不是 Go module 名的机械映射。

## 当前事实

### 图片

- 后端图片能力已经收敛到 `internal/module/ai/image`，Admin/Canvas 分别在 `transport/admin` 和 `transport/canvas`。
- 数据表已经收敛到 `ai_image_tasks` / `ai_image_files`。
- Canvas 生图工作台的交互事实是：生成记录、新建、全选、删除、提示词库、我的素材、参考图、参数、开始生成、结果卡片、添加到素材、加入参考图、下载、失败重试。
- Admin 图片页不应该再有收藏、审核、后台审批式状态筛选。

### 提示词

- 当前后端提示词模型在 `internal/module/canvas`，表是 `canvas_prompts`。
- 当前 Canvas 前端通过 `/api/canvas/v1/prompts` 读取提示词库。
- 这不是 Canvas 专属能力；Admin 也需要同一套提示词能力。

### 素材

- 当前后端公开素材模型在 `internal/module/canvas`，表是 `canvas_assets`。
- 当前 Canvas “我的素材”主要由前端 store / 浏览器持久化承载。
- 这不是 Canvas 专属能力；Admin 也需要同一套素材能力，并且素材应后端持久化。

### 403

- Canvas 页面已通过路由权限显示顶部导航时，页面内 API 403 不应该直接把整个页面打成 403。
- 图片 API 客户端现在会把 axios 403 通过 auth-error 事件交给 `CanvasAuthGuard`；这需要区分“登录/RBAC 403”和“业务/provider 403”。

## 目标架构

### 模块归属

目标 Go module：

```text
internal/module/ai/image
internal/module/ai/prompt
internal/module/ai/asset
```

目标 transport：

```text
internal/module/ai/image/transport/admin
internal/module/ai/image/transport/canvas
internal/module/ai/prompt/transport/admin
internal/module/ai/prompt/transport/canvas
internal/module/ai/asset/transport/admin
internal/module/ai/asset/transport/canvas
```

`internal/module/canvas` 不再拥有 prompt / asset 的 model、repository、service。Canvas module 只保留 Canvas 平台壳和真正 Canvas 专属设置。

### 表归属

目标表：

```text
ai_image_tasks
ai_image_files
ai_prompts
ai_assets
```

迁移规则：

- `canvas_prompts` -> `ai_prompts`
- `canvas_assets` -> `ai_assets`
- 迁移必须保留数据、id、时间、状态、软删除语义。
- 不做长期双写。
- 如果需要短期 URL 兼容，只保留 route bridge，不保留双 service / 双 repository。

### 数据模型原则

图片任务：

- 保留任务和文件分离：task 记录请求，file 记录 input/mask/output。
- 保留 `platform` 区分 Admin/Canvas 入口。
- 删除或停用 Admin-only 字段和交互：`is_favorite` 不再作为工作台能力。
- `moderation` 不作为用户可见工作台配置。若 provider 仍需默认值，由 service 或 agent/model 配置决定，不由 Admin 页面暴露成产品概念。

提示词：

- 提示词是 AI prompt catalog，不属于 Canvas。
- Admin 能管理；Canvas 能读取/使用；Admin 图片工作台也能读取/使用。
- 字段以当前 `canvas_prompts` 真实字段为迁移基线，不为“未来扩展”新增无用字段。

素材：

- 素材是 AI asset library，不属于 Canvas。
- 支持 text / image / video。
- Admin 和 Canvas 共用同一领域模型。
- “我的素材”必须后端持久化，不再依赖浏览器缓存作为业务事实。
- 素材与图片任务文件不是同一张表：`ai_image_files` 是任务输入输出证据；`ai_assets` 是可复用素材库。生成结果“添加到素材”会从 output file 派生 asset。

## API 设计

### 图片工作台

Admin 外部路径继续使用：

```text
GET    /api/admin/v1/ai-images/page-init
GET    /api/admin/v1/ai-images
POST   /api/admin/v1/ai-images
GET    /api/admin/v1/ai-images/:id
DELETE /api/admin/v1/ai-images/:id
```

Canvas 外部路径继续使用：

```text
GET    /api/canvas/v1/ai/images
POST   /api/canvas/v1/ai/images/generations
POST   /api/canvas/v1/ai/images/edits
GET    /api/canvas/v1/ai/images/:id
DELETE /api/canvas/v1/ai/images/:id
```

Admin 不再新增/保留收藏接口作为工作台能力：

```text
PATCH /api/admin/v1/ai-images/:id/favorite  # retired
```

### 提示词

Admin 管理面建议路径：

```text
GET    /api/admin/v1/ai-prompts/page-init
GET    /api/admin/v1/ai-prompts
POST   /api/admin/v1/ai-prompts
GET    /api/admin/v1/ai-prompts/:id
PUT    /api/admin/v1/ai-prompts/:id
PATCH  /api/admin/v1/ai-prompts/:id/status
DELETE /api/admin/v1/ai-prompts/:id
DELETE /api/admin/v1/ai-prompts
```

Canvas 读取面保持现有用户路径，不破坏前端：

```text
GET /api/canvas/v1/prompts
```

实现归属变为：

```text
internal/module/ai/prompt/transport/canvas
```

### 素材

Admin 管理/使用面建议路径：

```text
GET    /api/admin/v1/ai-assets/page-init
GET    /api/admin/v1/ai-assets
POST   /api/admin/v1/ai-assets
GET    /api/admin/v1/ai-assets/:id
PUT    /api/admin/v1/ai-assets/:id
DELETE /api/admin/v1/ai-assets/:id
DELETE /api/admin/v1/ai-assets
```

Canvas 读取/我的素材面保持现有页面路径，API 可先保持：

```text
GET    /api/canvas/v1/assets
POST   /api/canvas/v1/assets
PUT    /api/canvas/v1/assets/:id
DELETE /api/canvas/v1/assets/:id
```

实现归属变为：

```text
internal/module/ai/asset/transport/canvas
```

## 前端设计

### Admin 图片工作台必须对齐 Canvas 工作台

Admin 页面结构保留三栏，但语义改成 Canvas 同款：

```text
左：生成记录
中：提示词 + 参考图 + 参数 + 开始生成
右：生成结果
```

左栏：

- 新建
- 全选 / 取消
- 删除
- 记录卡片展示：标题、缩略图、成功/失败数、张数、耗时、时间
- 不要收藏筛选
- 不要审核筛选

中栏：

- 提示词输入
- 查看提示词库
- 查看我的素材
- 剪切板 / 上传参考图
- 参数与 Canvas `ImageSettingsPanel` 语义一致：模型、尺寸、宽高比、质量、张数
- 不暴露 moderation / output_format / compression 这种后台参数面板

右栏：

- 空态：“还没有生成图片”
- pending 卡片：“生成中”
- success 卡片：图片、尺寸、大小、耗时、添加到素材、加入参考图、下载
- failed 卡片：错误、重试
- 不要收藏按钮
- 不要审核按钮
- 不要任务详情大卡片挤占结果区

### Canvas 继续保持现有工作台交互

Canvas 当前交互是目标参考，不要为了 Admin 反向污染 Canvas。

### Admin 提示词 / 素材页面

Admin 需要有同一套提示词和素材能力：

- 提示词：管理 prompt catalog，也可在图片工作台选择使用。
- 素材：管理/使用 AI asset library，也可在图片工作台选择为参考图或文本素材。
- 使用 Admin 现有 CRUD primitives：Search + AppTable + AppDialog + useCrudTable。
- 可见文案必须进 i18n。

### Canvas 提示词 / 素材页面

- 提示词页面继续用于浏览、搜索、复制、加入素材。
- 素材页面必须从后端读写 `ai_assets`，不能把浏览器 localStorage 当业务数据库。
- 如果短期保留本地素材导入/导出，只能作为临时导入导出工具，不作为主存储。

## 403 处理原则

403 分两类：

1. 登录/RBAC 403：应该进入 `CanvasAuthGuard` 的整页 403。
2. 业务/provider 403：应该留在当前操作内，例如结果卡片失败、toast 或局部错误，不应该整页 403。

落地要求：

- Canvas API client 不能对所有 axios 403 无脑触发全局 auth-error。
- 只有后端明确返回 auth / permission 类型错误时才触发全局 401/403。
- 图片生成、读取记录、删除记录等业务错误必须由工作台局部处理。
- 如果真实根因是 Canvas 角色缺少 `canvas_image_page` / `canvas_ai_image_generate` 授权，则修 seed/migration/current role grant 和缓存刷新，不在前端加兜底。

## 权限设计

权限码是 platform 入口控制，不是 module 目录名。

保留 Canvas 已有 PAGE/BUTTON 语义：

```text
canvas_image_page
canvas_prompts_page
canvas_assets_page
canvas_ai_image_generate
canvas_prompt_read
canvas_asset_read
```

新增 Admin AI 能力权限建议：

```text
ai_prompt_list / ai_prompt_add / ai_prompt_edit / ai_prompt_status / ai_prompt_del
ai_asset_list / ai_asset_add / ai_asset_edit / ai_asset_del
ai_image_task_add / ai_image_task_del
```

不新增：

```text
ai_image_task_favorite
ai_image_task_audit
```

## 兼容与迁移

迁移顺序：

1. 先加 AI prompt/asset capability，复制当前 canvas prompt/asset 行为到新 module。
2. 增加 schema migration，把 `canvas_prompts` / `canvas_assets` 数据迁到 `ai_prompts` / `ai_assets`。
3. Canvas 原 URL 由 ai module 的 canvas transport 接管。
4. Admin 新增 prompt/asset API 和页面。
5. Admin 图片工作台改为 Canvas 同款交互。
6. Canvas 我的素材改为后端持久化。
7. 删除 `internal/module/canvas` 中 prompt/asset model/repository/service 残留。
8. 删除 Admin 图片收藏/审核 UI/API/权限/字段残留；字段删除必须在确认无 runtime 依赖后执行 migration。

禁止：

- 不做双表长期同步。
- 不做 `/api/canvas/v1/prompts` 和 `/api/canvas/v1/ai/prompts` 两套长期接口。
- 不在前端用 localStorage 兜底后端素材缺失。
- 不新增 `admin_prompt`、`canvas_prompt`、`admin_asset`、`canvas_asset` 这类平台前缀业务模块。

## 测试与验收

后端：

- `go test ./... -count=1 -p=1`
- contract drift / route inventory 更新
- migration dry-run / live schema snapshot 更新
- 架构 guard：`internal/module/canvas` 不再拥有 Prompt/Asset model/repository/service
- API guard：Canvas prompt/assets URL 仍可用，但 handler source 属于 `ai/prompt`、`ai/asset`

Admin 前端：

- `npm test`
- `npm run typecheck`
- source guard：图片工作台不得出现 favorite/audit/moderation UI
- source guard：图片结果卡片必须包含添加到素材、加入参考图、下载、失败重试
- i18n guard：新增文案同步 zh-CN/en-US

Canvas 前端：

- `npm test`
- `npm run typecheck`
- source guard：素材主存储不得继续依赖 browser localStorage
- 403 guard：业务/provider 403 不触发整页 `CanvasAuthGuard`，真正 auth/RBAC 403 仍触发

Root governance：

```powershell
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1
```

## 不做事项

本 spec 不做：

- 新支付/扣费设计。
- 新 AI billing。
- 新 Canvas 画布节点能力。
- 多租户复杂可见性模型。
- 为未来可能存在的 prompt marketplace 做抽象。

如果后续要做 marketplace，必须另开 spec；当前只解决真实存在的 Admin/Canvas 图片、提示词、素材收敛问题。

## 结论

值得做。

这是数据结构和能力归属错误，不是 UI 小修。正确方向是：

```text
AI 能力归 AI module。
Admin / Canvas 只是 transport。
图片 / 提示词 / 素材都只保留一套领域模型。
工作台交互以 Canvas 当前真实工作流为准，Admin 不再自创后台审核/收藏语义。
```
