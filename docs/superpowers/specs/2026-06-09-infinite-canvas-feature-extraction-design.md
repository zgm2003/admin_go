# Canvas Front Next Feature Backport Design

状态：corrected active design
日期：2026-06-09
目标项目：`E:\admin_go\canvas_front_next`
必要联动：`E:\admin_go\admin_back_go`、`E:\admin_go\admin_front_ts`
对照来源：`E:\GitDownload\infinite-canvas`

## 纠偏结论

用户真实目标是：改造 `E:\admin_go\canvas_front_next`，把 `E:\GitDownload\infinite-canvas` 比 admin_go 当前项目多出来、且适合 admin_go 架构的能力挑出来移植。

`E:\GitDownload\infinite-canvas` 只作为只读对照来源，不是本轮目标仓库；不得把它的 `/api/auth/*`、`/api/v1/*`、`/api/assets`、独立后台、JWT/session 或表结构直接搬进 admin_go。

admin_go runtime 仍以这些事实为准：

```text
Canvas frontend: E:\admin_go\canvas_front_next
Backend:         E:\admin_go\admin_back_go
Admin frontend:  E:\admin_go\admin_front_ts
Canvas API:      /api/canvas/v1/*
Admin API:       /api/admin/v1/*
Backend layout:  internal/module/{capability}/transport/{platform}
```

## 对照审计结论

### admin_go 已经更强或已有等价能力

- Canvas API envelope、auth event、logout 和 401/403 处理已经按 admin_go 契约存在。
- Canvas 图片/视频生成由 Go 后端托管 provider，不允许浏览器提交 provider/model/api key/base_url。
- Canvas assets 已经通过 `/api/canvas/v1/assets` 做当前用户持久化，不存在 public asset library / `user_id=0` shared library 语义。
- Admin Vue 已有 prompt/provider/agent/tool/knowledge/run/chat 管理；Admin 素材库是主动退休，不是遗漏。
- `canvas_front_next` 已有 Vitest、ZIP 导入导出、inputOrder、stale token、图片/视频/文本资源引用等基础能力。

### 来源项目多出来且值得选择性移植

1. **音频资源链路**
   - 来源有 Audio node、audio metadata、上传/拖拽音频、audio controls、音频生成相关入口。
   - admin_go 当前缺口应分阶段处理：先做 Canvas 音频资源引用基础，再决定是否做完整音频节点 UI、后端 audio generation 和 Admin 场景配置。

2. **Seedance/视频高级参数**
   - 来源有 `generate_audio`、`watermark`、ratio/resolution/duration、视频/音频参考等更完整的视频参数。
   - admin_go 需要映射到 `/api/canvas/v1/ai/videos*` 和 Go `internal/module/ai/video/transport/canvas`，不能直接搬来源 API。

3. **参考媒体上传给 provider 可访问 URL**
   - 来源有参考媒体上传接口思路。
   - admin_go 应落在 Canvas `/api/canvas/v1/*` 与 COS/storage 边界，返回 provider 可访问 URL；不新增 `/api/v1/media/references`。

4. **当前画布合并导入**
   - 用户 Cine Make 工作流需要：先在当前画布生成人物/场景/风格主图，再把分镜/Keyframe 节点包追加到同一画布。
   - 这不是简单“导入为新项目”，应新增 fail-closed 的 current-canvas merge import。

5. **导入 schema fail-closed / 素材元数据质量**
   - admin_go 已有 ZIP 导入导出和 assets 持久化，但可以借鉴来源项目的严格校验思路。

### 不适合直接迁移

- `/asset-library` 公共素材库：admin_go 文档和 runtime 明确它是已删除死页，不直接恢复。
- 来源项目独立 admin、credits/free-generation、JWT/session、DB 表结构：不覆盖 admin_go 当前 Go/Vue/RBAC/AI agent 模型。
- 浏览器侧自定义 provider/channel：不符合 admin_go 后端托管 provider 边界。

## 分阶段设计

### C1：Canvas 音频资源引用基础（本轮已落地）

目标：让音频作为 Canvas 资源类型进入引用编号、composer token、生成上下文和节点基础渲染，但不声称完整音频生成链路完成。

范围：

- `CanvasNodeType.Audio`、`CanvasGenerationMode`、audio metadata 基础字段。
- 资源编号支持 `音频1`，并参与 `inputOrder`。
- `@[node:<audio>]` composer token 输出为 `音频1`，并保留 stale token 行为。
- `NodeGenerationContext` 增加 `referenceAudios` / `audioCount`。
- 配置 composer 候选、配置面板 input summary、节点渲染表补齐 Audio，避免新增枚举后 typecheck 漏洞。
- 只做 `<audio controls>` 基础渲染和 storage-backed Audio 节点本地恢复；不新增完整上传、工具栏创建入口、后端 audio generation 或 Admin 场景。

成功标准：

- Targeted Vitest 覆盖 audio label / composer / context。
- Targeted Vitest 覆盖 storage-backed Audio hydration 和 missing blob fail-closed。
- `npm run typecheck` 通过。
- 不触碰 `E:\GitDownload\infinite-canvas`。

### C2：Canvas 参考媒体上传与视频高级参数

目标：把来源项目里更强的视频/参考媒体参数映射到 admin_go Canvas 后端。

当前 C2-A 第一刀状态：

- 已先落地 `generate_audio` / `watermark` 请求契约和端到端透传。
- `canvas_front_next` 视频设置、视频 API、Canvas 节点局部视频设置和视频页日志保存/恢复只暴露这两个后端允许参数。
- Go Canvas video transport/service/OpenAI-compatible adapter 透传这两个布尔字段；浏览器仍不能提交 `model` / `provider` / `api_key` / `base_url`。
- 当前不包含参考视频/参考音频上传，不新增 `/api/v1/media/references`，不包含完整 Seedance/火山 Agent Plan path routing，不触碰 `E:\GitDownload\infinite-canvas`。

当前 C2-B 状态：

- `canvas_front_next` 已把 `referenceVideos` / `referenceAudios` 从生成上下文传到视频 API client，但 client 在当前后端契约未支持前显式 fail-closed，不再静默丢弃这些引用后继续调用 `/api/canvas/v1/ai/videos`。
- 视频节点 metadata 的 `references` 现在通过共享 helper 记录 image/video/audio 引用来源，便于 UI/后续契约排查；这不是 provider 可访问 URL 上传链路。
- 当前仍不新增参考媒体上传、Seedance content-role payload、Admin provider 策略 UI 或后端 contract 字段。

当前 C2-C 状态：

- `admin_back_go/internal/infra/ai/openaicompat` 已提取上游非 2xx JSON 错误里的可读 message，并保持 API key 脱敏。
- reference video privacy 类错误会返回更明确的中文提示，便于用户理解“参考视频受限/隐私风险”类失败。
- 这只是错误信息 hardening，不代表当前 Canvas 已支持参考视频上传或 Seedance 专属协议。

范围：

- Canvas 前端请求形状先写测试，不允许 provider/base_url/api_key/model override。
- Go 后端在 `internal/module/ai/video/transport/canvas` 或相邻 capability 中接收明确 DTO。
- C2-A 已支持 `generate_audio` / `watermark`；参考视频/音频上传到 storage、provider 可访问 URL、ratio/resolution/duration 策略和完整 Seedance/火山路径仍是后续 planned。
- C2-B 已支持参考视频/音频输入的前端显式拒绝和 metadata 记录；不改变后端 DTO。
- C2-C 已支持 OpenAI-compatible 上游错误详情提取和 reference video privacy 友好提示；不改变请求/响应契约。

非目标：不直接引入来源 `/api/v1/media/references`。

### C3：当前画布合并导入

目标：支持把一个 canvas zip 的节点追加到当前画布，不覆盖用户已锁定主图。

范围：

- 保留画布库“导入画布 = 新建项目”的现有行为。
- 编辑页新增“合并/导入到当前画布”。
- ID remap、连接 remap、右侧放置、文件 restore fail-closed。
- 支持稳定 anchor metadata：人物/场景/风格主图能被分镜/Keyframe 节点复用。
- 缺锚点时不乱连，给用户可见提示。

当前第一刀状态：

- 已先落地 `canvas_front_next` 编辑页 current-canvas merge import wiring。
- 该路径用于把 canvas ZIP 节点包追加到当前画布；画布库导入仍保持“导入 = 新建项目”。
- 已有 targeted tests 覆盖 ZIP parse fail-closed、asset restore、ID/connection remap、右侧放置、anchor 复用、缺锚点 warning，以及编辑页不调用 `importProject(` 的 merge wiring。
- C3-B 已补齐当前画布合并导入的本地 storage-key remap：恢复导出包 blob 时生成新导入 key，并在 merge 前重写 imported project 内的 storage-key 引用，降低旧 ZIP key 冲突和污染当前画布的风险。
- 画布库“导入画布 = 新建项目”路径已改用同一套 `parseCanvasExportZip` / `restoreCanvasExportAssets`，因此新建项目导入也获得 ZIP fail-closed 校验和 fresh storage-key remap。
- 当前仍只按测试证据声明前端行为，不把 C3 写成整体完成；浏览器手工 Cine Make、云端项目同步、backend asset ownership remap 仍是后续切片。

成功标准：

- 画布库导入新建项目行为不被编辑页 merge import 改写。
- 画布库导入虽保持新建项目语义，但必须复用共享 parser/remap，不能绕回直接 `readZip` 写旧 storageKey。
- 编辑页 merge import 只更新当前项目。
- ID remap、connection remap、右侧放置、anchor 复用、缺锚点提示、坏包 fail-closed 分别有 targeted tests。
- imported project 的 storage-key 引用在合并前被重写为本次导入的新 key，anchorKey / requiredAnchorKeys 不被当成 storage key 修改。
- `npm run typecheck` 通过。

### C4：素材/导入严格校验

目标：借鉴来源项目 fail-closed 思路，增强 admin_go Canvas assets 和 ZIP 导入质量。

当前 C4-A / C4-B 第一刀状态：

- 已先落地 `canvas_front_next` 素材 ZIP 导入/导出 fail-closed hardening。
- `readAssetPackage` 现在校验 `assets.json` root schema、text/image/video asset shape、image/video `storageKey`/`mimeType`/`bytes`/`width`/`height`、file manifest 与 asset metadata 一致性、声明 blob 存在性和 ZIP entry size；所有校验通过后才写入 image/media blob store。
- `exportAssets` 现在只把 text asset 和实际打包成功的 media asset 写入 manifest，避免生成“asset 有声明但 ZIP 缺 blob”的坏包。
- 素材页导入仍走 backend-backed `addAsset(withoutImportedAssetSlug(...))`，不直接塞本地 store，不复用导出包旧 `id` / `createdAt` / `updatedAt` / `metadata.slug`。
- 已落地 `admin_back_go` Canvas `/api/canvas/v1/assets` image/video create/update service 校验：`url` 必须非空，`content` 必须是严格 JSON media metadata，包含 storage-backed `storageKey`、正数 `width` / `height` / `bytes` 和匹配 `mimeType`。
- 后端 `storageKey` 兼容当前 COS object key（如 `ai-images/...`）和带路径 typed key（如 `image:task/...` / `video:task/...`），拒绝浏览器本地短 key（如 `image:localBrowserOnly`）和类型错配 key。
- 当前不包含 audio backend asset type，不新增 DB metadata columns，不恢复 public asset library 或 Admin 素材库。

范围：

- C4-A 已覆盖：素材 ZIP `assets.json` schema、image/video mime/bytes/width/height、storageKey/file/blob 一致性，以及坏包不部分污染浏览器本地 blob store。
- Canvas project ZIP import 额外拒绝重复 exported storageKey/path，避免 remap 和 blob restore 语义含糊。
- C4-B 已覆盖：`/api/canvas/v1/assets` image/video payload 严格 media metadata 校验，拒绝未知顶层 media metadata 字段和浏览器本地短 key。
- 后续仍待契约确认：audio asset 的后端类型、mime/bytes/duration 规则和 Canvas UI；如要把 media metadata 变成 DB 一等字段，需要单独 migration/spec。

非目标：不恢复 public asset library，不恢复 Admin 素材库。

### C5：Admin 管理补齐（仅在产品契约确认后）

可能需要：

- 若做完整音频生成：新增 `canvas_audio_generate` 场景、Admin agent/provider 配置、后端 i18n catalog。
- 若做视频高级参数：Admin agent/provider 策略只做后端管理，不让浏览器自定义渠道。

## 验证策略

每个代码切片至少：

```powershell
cd E:\admin_go\canvas_front_next
npm test -- <targeted tests>
npm run typecheck
```

跨仓或文档收口：

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

触碰 backend route/schema/contracts 时，再加对应 Go test、contract drift、runtime doc fact check。
