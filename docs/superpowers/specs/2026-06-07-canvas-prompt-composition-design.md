# Canvas 提示词组装增强设计

日期：2026-06-07
状态：spec written for user review；尚未实现
主角色：frontend-adapter（Canvas Next 前端契约适配切片）

## 需求分析

【需求判断】
是真问题。参考项目最近增强的不是单个输入框样式，而是一套“资源 -> 编号 -> prompt -> 请求”的提示词组装链路。当前 `canvas_front_next` 已经有图片/文本/视频生成基础链路，但提示词对参考图片和上游文本的表达偏粗糙，模型难以稳定理解“哪张图对应哪段描述”。

【核心问题】
真正需要解决的是：让 Canvas 生成请求在不破坏后端托管 `agent_id` 契约的前提下，把上游资源以稳定、可读、可测试的方式注入提示词。第一阶段只处理文本和图片引用，明确不把参考项目的浏览器侧 provider/baseUrl/apiKey/model 覆盖逻辑搬进来。

【复杂度检查】
不能为了“完整复刻参考项目”引入音频节点、Seedance AgentPlan、视频/音频参考文件上传和浏览器系统提示词。第一阶段只做一个窄切片：图片引用编号、配置节点 token 组装、输入框 `@` 选择资源，以及对应测试。

【破坏性分析】
现有项目必须继续支持：

- 旧 Canvas 节点只保存 `metadata.prompt` 的情况。
- 当前 `inputOrder` 对配置节点输入排序的行为。
- `/api/canvas/v1/ai/images/*` 只提交 `agent_id`，不提交客户端 provider/model/api_key/base_url。
- `/api/canvas/v1/ai/chat/completions` 和 `/api/canvas/v1/ai/videos` 现有契约不被前端字段扩散破坏。

## 代码分析

【数据结构】
当前目标项目的提示词数据主要散在：

```text
CanvasNodeMetadata.prompt          # 普通节点/配置节点的旧提示词字段
CanvasNodeMetadata.inputOrder      # 当前项目已有的配置节点输入排序
NodeGenerationContext.prompt       # 生成前拼好的 prompt
NodeGenerationContext.referenceImages
```

第一阶段新增/启用的核心数据结构：

```text
CanvasNodeMetadata.composerContent?: string
CanvasResourceReference            # nodeId/kind/label/title/preview/text/active
```

`composerContent` 只服务配置节点富文本组装；`prompt` 保持旧行为和兼容。资源引用仍以画布连接和 nodeId 为事实源，不把字符串里的 `图片1` 当成唯一数据源。

【特殊情况】
当前特殊情况是“提示词里想引用图片，但实际请求只知道有几张参考图，不知道用户说的是哪一张”。参考项目用 `图片1/图片2` 编号消灭这种歧义。我们应把编号逻辑集中到 transform 层，而不是在每个请求调用点手写字符串拼接。

【复杂度】
第一阶段只新增三个小边界：

1. `image-reference-prompt.ts`：图片引用编号和 prompt 包装。
2. `canvas-resource-references.ts`：从节点/连接计算可引用资源。
3. `canvas-node-generation.ts`：把 `composerContent` token 转成最终 prompt 和引用数组。

不要在 `canvas-client-page.tsx` 里继续堆复杂规则。它只负责传入 nodes/connections，调用 transform。

【兼容性】
无数据库迁移；无 Go 后端新接口；无现有 API 返回结构变更。旧节点没有 `composerContent` 时继续按旧 `prompt + upstreamText` 逻辑工作。

【结论】
值得做。第一阶段优先级高于工具条增强，因为它直接影响生成质量。

## 证据

参考项目：

- 图片引用编号 helper： [E:/GitDownload/infinite-canvas/web/src/lib/image-reference-prompt.ts:7](/E:/GitDownload/infinite-canvas/web/src/lib/image-reference-prompt.ts#L7)
- 图片 edit 请求包装引用说明： [E:/GitDownload/infinite-canvas/web/src/services/api/image.ts:229](/E:/GitDownload/infinite-canvas/web/src/services/api/image.ts#L229)
- 配置节点 token 组装： [E:/GitDownload/infinite-canvas/web/src/app/(user)/canvas/components/canvas-node-generation.ts:57](/E:/GitDownload/infinite-canvas/web/src/app/(user)/canvas/components/canvas-node-generation.ts#L57)
- 资源引用计算： [E:/GitDownload/infinite-canvas/web/src/app/(user)/canvas/utils/canvas-resource-references.ts:18](/E:/GitDownload/infinite-canvas/web/src/app/(user)/canvas/utils/canvas-resource-references.ts#L18)
- 输入框 mention 接入： [E:/GitDownload/infinite-canvas/web/src/app/(user)/canvas/components/canvas-node-prompt-panel.tsx:69](/E:/GitDownload/infinite-canvas/web/src/app/(user)/canvas/components/canvas-node-prompt-panel.tsx#L69)

当前项目：

- 当前图片 edit 直接提交原始 prompt： [E:/admin_go/canvas_front_next/src/services/api/image.ts:207](/E:/admin_go/canvas_front_next/src/services/api/image.ts#L207)
- 当前配置节点只拼接上游文本和图片： [E:/admin_go/canvas_front_next/src/app/(user)/canvas/components/canvas-node-generation.ts:20](/E:/admin_go/canvas_front_next/src/app/(user)/canvas/components/canvas-node-generation.ts#L20)
- 当前项目已有 `inputOrder`，必须保留： [E:/admin_go/canvas_front_next/src/app/(user)/canvas/components/canvas-node-generation.ts:90](/E:/admin_go/canvas_front_next/src/app/(user)/canvas/components/canvas-node-generation.ts#L90)
- 当前配置节点面板已经展示输入顺序和编辑上游文本： [E:/admin_go/canvas_front_next/src/app/(user)/canvas/components/canvas-config-node-panel.tsx:42](/E:/admin_go/canvas_front_next/src/app/(user)/canvas/components/canvas-config-node-panel.tsx#L42)
- 当前视频前端传参考图，但后端 Canvas video handler 未接 multipart 文件： [E:/admin_go/admin_back_go/internal/module/ai/video/transport/canvas/handler.go:32](/E:/admin_go/admin_back_go/internal/module/ai/video/transport/canvas/handler.go#L32)

## 设计目标

1. 图片生成/编辑请求能告诉模型：参考图片编号是 `图片1、图片2...`。
2. 配置节点支持 `@[node:<id>]` token，用户可明确选择哪些上游资源进入 prompt。
3. 普通节点提示词输入支持 `@` 选择当前上下文可用资源，并用高亮/菜单降低记忆成本。
4. 保留当前 `inputOrder` 和旧 `metadata.prompt` 行为。
5. 所有变更有单元测试或源约束测试，不靠手工点页面证明。

## 非目标

第一阶段不做：

- 浏览器侧 `systemPrompt` 全局配置。
- 浏览器侧 provider/baseUrl/apiKey/model 覆盖。
- 音频节点、音频 agent、`agents.audio`。
- Seedance AgentPlan 或视频/音频多模态参考上传。
- Canvas video 后端参考文件 multipart 接入。
- 蒙版编辑 mask 后端契约。

这些都是后续独立 spec，不混进本切片。

## 目标架构

### 1. 图片引用 prompt helper

新增 `E:/admin_go/canvas_front_next/src/lib/image-reference-prompt.ts`：

```text
imageReferenceLabel(index) -> 图片1 / 图片2 / ...
buildImageReferencePromptText(prompt, references) -> 带编号说明的 prompt
```

规则：

- `references.length === 0` 时只返回 trim 后的 prompt。
- 有参考图时生成：`参考图片编号：图片1、图片2。请按这些编号理解提示词中的图片引用。\n\n<用户提示词>`。
- 不在 helper 内访问 store、axios、DOM 或后端契约。

### 2. 资源引用计算

新增 `E:/admin_go/canvas_front_next/src/app/(user)/canvas/utils/canvas-resource-references.ts`，职责只做图结构到资源列表的转换：

```text
CanvasResourceReference = {
  id,
  nodeId,
  kind: "image" | "text" | "video",
  label,
  title,
  previewUrl?,
  text?,
  active
}
```

第一阶段 `kind` 只实际启用 `image/text/video`。`audio` 暂不加入，因为当前项目没有 `CanvasNodeType.Audio`，后端也没有 audio agent contract。

资源来源：

- 对配置节点：优先读取连接到该配置节点的资源。
- 对普通节点：读取连接到该节点的资源。
- 如果上下文节点本身是资源节点，可作为可引用资源显示，但生成时仍以连接和 token 为准。

### 3. 配置节点 composer

配置节点面板新增富文本 composer 或等价轻量输入组件，写入：

```text
CanvasNodeMetadata.composerContent
```

token 语法：

```text
@[node:<nodeId>]
```

生成规则：

- 如果 `composerContent` 有内容，则 `buildNodeGenerationContext()` 走 composer 解析。
- token 指向图片：prompt 中替换为 `图片N`，同时把该图片加入 `referenceImages`。
- token 指向文本：prompt 中替换为 `【文本N】`，并在 prompt 尾部追加：`【文本N】\n<文本内容>`。
- token 指向视频：第一阶段只替换为 `视频N` 文字提示，不加入后端请求文件数组；视频多模态后端没接好，不能假装支持。
- token 指向已删除或不可达节点：保留原 token 文本，不静默删除。
- 没有 token 时：返回 composer 文本本身，不自动注入所有上游资源。

兼容规则：

- 没有 `composerContent` 时，保持当前旧逻辑：`prompt + upstreamText`，引用图来自连接上游。
- 有 `composerContent` 时，以 composer 为准；`prompt` 只作为旧数据回填来源，不作为额外拼接。
- 当前 `inputOrder` 继续决定上游资源的默认顺序和编号。

### 4. 普通节点 prompt 输入框 mention

普通节点提示词输入从纯 `Input.TextArea` 升级为资源 mention textarea：

- 用户输入 `@` 弹出当前上下文可引用资源。
- 选择资源后插入可读 label，例如 `图片1 ` 或 `文本1 `。
- label 只是用户提示词中的自然语言引用；真正参考图片数组仍由连接关系和 generation context 决定。
- 输入框高亮当前活跃资源 label，降低“我写的图片1是哪张”的认知成本。

这部分必须保持组件边界清楚：输入框只负责编辑体验，不直接发请求、不改 store、不查后端。

### 5. 图片 edit 请求包装

修改 `requestEdit(config, prompt, references, options)`：

- 在构造 FormData 前调用 `buildImageReferencePromptText(prompt, references)`。
- `formData.set("prompt", requestPrompt)`。
- 继续只提交 `agent_id`，不提交 `model/provider/api_key/base_url`。
- 继续使用现有 reference image hydration 和丢失图片 fail-closed 逻辑。

### 6. 视频引用缺口处理

当前前端 `requestVideoGeneration()` 会 append `input_reference[]`，但 Go Canvas video handler 只绑定 `agent_id/prompt/duration_seconds/size/resolution_name` 并调用 service；没有保存/读取这些参考文件。

第一阶段处理方式：

- 不扩大视频契约。
- 在 prompt 组装中允许出现 `视频N` 文本，但不新增 `referenceVideos` 请求参数。
- 后续如果要支持视频/音频参考输入，必须另开后端契约 spec：multipart bind、存储、任务表关系、provider engine input、smoke/test。

## 数据流

```text
nodes + connections + contextNodeId
  -> buildCanvasResourceReferences / buildNodeMentionReferences
  -> UI mention/composer 显示可选资源
  -> composerContent 或普通 prompt
  -> buildNodeGenerationContext
  -> hydrateNodeGenerationContext
  -> requestGeneration / requestEdit / requestImageQuestion
  -> /api/canvas/v1/* agent_id contract
```

`canvas-client-page.tsx` 不承载 prompt 规则，只连接组件和 transform。

## 错误处理

- 参考图片无法恢复 dataUrl：保持当前 fail-closed，抛出“参考图片已丢失，无法继续生成”。
- 空 prompt：沿用当前生成前校验，不发空请求。
- stale token：保留原 token 文本，不删除用户输入；不加入 reference arrays。
- 非图片资源在图片 edit 中：不加入 `referenceImages`，只作为 prompt 文本存在。
- 任何后端返回错误：沿用现有 `readAxiosError` / `requireApiMessage` 路径，不新增静默兜底。

## 测试设计

### 单元测试

1. `src/lib/image-reference-prompt.test.ts`
   - 无参考图返回 trim prompt。
   - 多参考图生成 `图片1、图片2` 编号说明。
   - 不产生 provider/model 字段。

2. `src/app/(user)/canvas/components/canvas-node-generation.test.ts`
   - legacy 无 `composerContent`：保留当前上游文本拼接和图片引用。
   - 有 `composerContent`：`@[node:image]` 变 `图片1`，并加入 `referenceImages`。
   - 文本 token：prompt 中出现 `【文本1】`，尾部追加文本正文。
   - stale token：原 token 文本保留，不丢内容。
   - `inputOrder` 决定编号顺序。

3. `src/services/api/image.test.ts`
   - `requestEdit()` FormData 的 `prompt` 包含参考图片编号说明。
   - `requestEdit()` 仍只提交 `agent_id`，不提交 `model/provider/api_key/base_url`。

### 组件/源约束测试

- 对 `canvas-node-prompt-panel.tsx` 增加轻量源约束：确认使用资源 mention textarea，而不是回退到裸 `Input.TextArea` 处理普通 prompt。
- 对 `canvas-client-page.tsx` 增加源约束：prompt 组装调用集中 helper，不在页面内手写 `图片1` 拼接。

### 验证命令

在 `E:/admin_go/canvas_front_next`：

```powershell
npm run test -- tests/shared/canvas-prompt-composition.test.ts
npm run test -- src/services/api/image.test.ts
npm run test -- src/app/(user)/canvas/components/canvas-node-generation.test.ts
npm run typecheck
```

在 `E:/admin_go`：

```powershell
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

如果实现时同步 status/knowledge/contract 口径，再加跑：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1
```

## 回滚方案

- 删除新增的 `image-reference-prompt.ts` 和 resource mention/composer 组件/工具文件。
- 恢复 `requestEdit()` 为原始 prompt。
- 恢复 `buildNodeGenerationContext()` 到 legacy 上游拼接逻辑。
- 保留旧数据无迁移压力，因为新增字段是可选 `composerContent`。

## 后续切片

1. 图片工具条自定义 + 本地 upscale。
2. 蒙版局部编辑：需要 Go Canvas image edit multipart mask 契约。
3. 视频参考输入：需要 Go Canvas video multipart 文件接入和 provider engine 参数。
4. 音频节点：需要 `agents.audio`、后端 audio capability、前端 node/store/API 全链路。
