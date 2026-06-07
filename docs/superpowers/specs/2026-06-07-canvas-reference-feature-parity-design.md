# Canvas 参考项目新增功能对齐设计

日期：2026-06-07
状态：spec written for implementation planning
主角色：frontend-adapter（Canvas Next 前端交互/样式对齐切片）

## 需求分析

【需求判断】
是真问题。用户要的不是“随便挑一个功能优化”，而是参考项目 `E:/GitDownload/infinite-canvas` 最近新增的 Canvas 功能，在目标项目 `E:/admin_go/canvas_front_next` 里做差异对齐。相同功能必须相同交互、相同样式、相同组件边界。

【核心问题】
真正需要解决的是：先把参考项目新增功能做成清单，再按目标项目当前后端/前端事实分层落地。已经接好的提示词组装不重复做；没接好的能力不能假装完成。下一步优先补“图片节点预览 + 图片工具条配置 + 反推提示词 + 本地放大 + 超分空态”这一组前端可闭环功能。

【复杂度检查】
不要把参考项目全部照搬。参考项目有 `Audio`、局部编辑 mask、浏览器侧 provider/model/API key 等目标项目当前不能直接接的东西。正确做法是按数据结构和运行时契约筛选：前端纯交互能闭环的先做；依赖后端契约的另开 spec。

【破坏性分析】
必须保留：

- 当前 `/api/canvas/v1/*` 只提交后端托管 `agent_id` 的契约。
- 当前没有 `CanvasNodeType.Audio` 的事实。
- 当前图片生成、图片编辑、裁剪、多角度、查看大图、素材保存、下载行为。
- 上一阶段已落地的 config composer / resource mention / 图片引用编号。

## 代码分析

【数据结构】
参考项目新增功能分成三类：

```text
已可直接对齐：
  - 图片节点双击预览
  - 图片 hover toolbar 可配置
  - 复制提示词
  - 反推提示词
  - 本地图片放大
  - AI 超分空态入口

已部分对齐：
  - 配置节点 composer / reference selection / prompt token

需要后端契约另开切片：
  - 局部编辑 mask
  - 音频节点 / audio agent
  - 视频/音频 multipart reference input
```

工具条必须使用参考项目的数据驱动结构：

```text
ImageQuickToolId
ImageToolDefinition
ImageQuickToolsConfig
ImageToolSettingsModal
```

而不是在 `canvas-node-hover-toolbar.tsx` 继续堆 `hasImage ? <ToolbarAction ...>`。

【特殊情况】
目标项目当前的特殊情况是坏味道：

- 下载按钮单独走 `IconAction`，和其它按钮不一致。
- 图片工具之间靠 `ToolbarDivider` 分隔，参考项目同功能没有这个交互。
- 图片快捷工具不能配置显隐。
- 配置节点 toolbar 按钮现在走 `onInfo(node)`，不是打开配置对话。
- 图片节点双击仍只处理文本编辑，没有按参考项目打开大图预览。

这些都应通过参考项目同款组件结构消掉。

【复杂度】
下一步只做一个窄的前端可闭环批次，不把后端 mask/audio/video 契约混进来。第一批触碰文件限定在 Canvas 前端组件、工具函数和测试。

【兼容性】
localStorage 使用参考项目同名 key `canvas-image-quick-tools-v5`。读取旧数组或包含未知工具的配置时 normalize；如果出现 `maskEdit` 等目标项目不支持 ID，直接丢弃，不显示假按钮。

【结论】
值得做。参考项目新增功能里，提示词组装已完成第一批；下一批应该补图片节点交互和工具条。mask/audio 另开契约，不混在这次。

## 参考新增功能差异清单

| 参考新增功能 | 参考证据 | 目标项目现状 | 决策 |
|---|---|---|---|
| 配置节点 composer / 引用选择 / prompt token | [E:/GitDownload/infinite-canvas/web/src/app/(user)/canvas/components/canvas-config-composer.tsx:1](/E:/GitDownload/infinite-canvas/web/src/app/(user)/canvas/components/canvas-config-composer.tsx#L1) | 已在上一阶段引入并修正为节点下方弹出 composer | 不重复做，只作为回归保护 |
| 图片节点双击预览 | [E:/GitDownload/infinite-canvas/web/src/app/(user)/canvas/components/canvas-node.tsx:274](/E:/GitDownload/infinite-canvas/web/src/app/(user)/canvas/components/canvas-node.tsx#L274) | 目标项目已有预览 modal，但节点双击没接到 `onViewImage` | 本批补齐 |
| 图片工具条可配置 | [E:/GitDownload/infinite-canvas/web/src/app/(user)/canvas/components/canvas-node-hover-toolbar.tsx:12](/E:/GitDownload/infinite-canvas/web/src/app/(user)/canvas/components/canvas-node-hover-toolbar.tsx#L12) | 目标项目硬编码按钮、`IconAction`、`ToolbarDivider` | 本批补齐 |
| 工具条设置弹窗 | [E:/GitDownload/infinite-canvas/web/src/app/(user)/canvas/components/canvas-node-hover-toolbar.tsx:195](/E:/GitDownload/infinite-canvas/web/src/app/(user)/canvas/components/canvas-node-hover-toolbar.tsx#L195) | 文件不存在 | 本批按参考项目复制 |
| 反推提示词 | [E:/GitDownload/infinite-canvas/web/src/app/(user)/canvas/[id]/canvas-client-page.tsx:1450](/E:/GitDownload/infinite-canvas/web/src/app/(user)/canvas/[id]/canvas-client-page.tsx#L1450) | 目标项目没有 `IMAGE_PROMPT_REVERSE_PRESET` 和创建文本+配置节点链路 | 本批补齐 |
| 本地图片放大 | [E:/GitDownload/infinite-canvas/web/src/app/(user)/canvas/utils/canvas-image-data.ts:77](/E:/GitDownload/infinite-canvas/web/src/app/(user)/canvas/utils/canvas-image-data.ts#L77) | 目标项目没有 upscale helper/dialog | 本批补齐 |
| AI 超分 | [E:/GitDownload/infinite-canvas/web/src/app/(user)/canvas/[id]/canvas-client-page.tsx:2513](/E:/GitDownload/infinite-canvas/web/src/app/(user)/canvas/[id]/canvas-client-page.tsx#L2513) | 目标项目没有入口 | 本批只做参考项目同款“暂未实现”空态 |
| 局部编辑 mask | [E:/GitDownload/infinite-canvas/web/src/app/(user)/canvas/[id]/canvas-client-page.tsx:2509](/E:/GitDownload/infinite-canvas/web/src/app/(user)/canvas/[id]/canvas-client-page.tsx#L2509) | 后端是 `mask_asset_id/mask_target_asset_id`，前端没有 mask asset 注册闭环 | 后续单独 spec |
| Audio 节点/agent | [E:/GitDownload/infinite-canvas/web/src/app/(user)/canvas/types.ts:14](/E:/GitDownload/infinite-canvas/web/src/app/(user)/canvas/types.ts#L14) | 目标项目没有 audio node/agent contract | 后续单独 spec，当前不做 |

目标项目当前缺口证据：

- 硬编码图片裁剪按钮： [E:/admin_go/canvas_front_next/src/app/(user)/canvas/components/canvas-node-hover-toolbar.tsx:101](/E:/admin_go/canvas_front_next/src/app/(user)/canvas/components/canvas-node-hover-toolbar.tsx#L101)
- 仍有 `IconAction`： [E:/admin_go/canvas_front_next/src/app/(user)/canvas/components/canvas-node-hover-toolbar.tsx:192](/E:/admin_go/canvas_front_next/src/app/(user)/canvas/components/canvas-node-hover-toolbar.tsx#L192)
- 仍有 `ToolbarDivider`： [E:/admin_go/canvas_front_next/src/app/(user)/canvas/components/canvas-node-hover-toolbar.tsx:202](/E:/admin_go/canvas_front_next/src/app/(user)/canvas/components/canvas-node-hover-toolbar.tsx#L202)
- 节点双击只处理文本/批量，未处理图片预览： [E:/admin_go/canvas_front_next/src/app/(user)/canvas/components/canvas-node.tsx:265](/E:/admin_go/canvas_front_next/src/app/(user)/canvas/components/canvas-node.tsx#L265)
- Canvas image 后端 mask 字段事实： [E:/admin_go/admin_back_go/internal/module/ai/image/transport/canvas/request.go:13](/E:/admin_go/admin_back_go/internal/module/ai/image/transport/canvas/request.go#L13)
- Canvas edit handler 当前把 multipart `image` 文件作为输入资产： [E:/admin_go/admin_back_go/internal/module/ai/image/transport/canvas/handler.go:147](/E:/admin_go/admin_back_go/internal/module/ai/image/transport/canvas/handler.go#L147)

## 本批设计目标

1. 图片节点双击打开图片详情 modal，事件冒泡处理与参考项目一致。
2. 图片 hover toolbar 改成参考项目同款：统一按钮、无 divider、白底 tooltip、更多按钮、设置弹窗、文字显隐。
3. 新增 `canvas-image-toolbar-tools.tsx` 和 `canvas-image-toolbar-settings-modal.tsx`。
4. 支持复制提示词、反推提示词、本地放大、AI 超分空态。
5. 保留现有裁剪、多角度、查看大图、替换、下载、存素材、删除、信息。
6. 不引入 `Audio`，不显示 mask edit，不卡死在后端契约不清的功能上。

## 非目标

本批不做：

- 局部编辑 mask 的真实生成。
- `CanvasNodeType.Audio` 和 audio agent。
- 视频/音频参考文件 multipart 后端接入。
- 浏览器侧 provider/model/api_key/base_url/systemPrompt。
- 重构整个 `canvas-client-page.tsx`。

## 目标架构

### 1. 图片节点双击预览

`CanvasNode` 增加可选 `onViewImage` prop。双击逻辑顺序与参考项目一致：

```text
batch root -> toggle batch
image with content -> stop propagation + onViewImage
text -> enter editing
```

### 2. 图片工具条数据化

新增工具定义文件，目标工具 ID：

```text
copyPrompt
reversePrompt
replace
resize
crop
upscale
superResolve
angle
view
```

基础工具：

```text
info
delete
saveAsset
download
edit
```

默认显示：

```text
info, delete, saveAsset, download, edit,
copyPrompt, reversePrompt, replace, crop, upscale, view
```

默认隐藏：

```text
resize, superResolve, angle
```

不纳入：

```text
maskEdit
```

### 3. 设置弹窗

直接按参考项目结构迁移：

- 标题 `自定义工具栏`
- `节点预览`
- checkbox grid
- `显示按钮文字` switch
- 顶部 toolbar preview + scrollbar

### 4. 反推提示词

图片工具点击后创建两个节点：

```text
Text: title = 反推提示词
Config: title = 反推提示词配置
Config.composerContent = 参考图片：@[node:<imageId>]\n任务说明：@[node:<textNodeId>]
```

并创建：

```text
image -> config
text -> config
```

### 5. 本地放大

迁移参考项目本地 canvas upscale：

```text
resolveUpscaleSize()
upscaleDataUrl()
CanvasNodeUpscaleDialog
```

确认后在源图右侧创建 `Upscaled Image`，连接 source -> child。

### 6. AI 超分空态

与参考项目保持一致：入口可被用户从设置里打开，但点击只显示 `AI 超分` modal 和 `暂未实现`。不发请求，不写假任务。

### 7. mask boundary

mask 不在本批出现。后续要做时，必须先写 `Canvas mask edit backend contract`：

```text
mask 图片如何注册为 ai image asset
mask_target_asset_id 如何绑定源图
multipart mask 与 input image 是否共用字段
任务表和 provider input 如何记录
```

## 测试设计

新增源约束测试：

```text
tests/shared/canvas-reference-feature-parity.test.ts
```

检查：

- 存在 `canvas-image-toolbar-tools.tsx`。
- 存在 `canvas-image-toolbar-settings-modal.tsx`。
- hover toolbar 使用 `buildImageToolbarTools` / `ImageToolSettingsModal`。
- hover toolbar 不再出现 `IconAction` / `ToolbarDivider` / 硬编码图片工具分支。
- `canvas-node.tsx` 图片双击调用 `onViewImage`。
- client page 存在 `IMAGE_PROMPT_REVERSE_PRESET` / `createImageReversePromptNodes` / `CanvasNodeUpscaleDialog` / `AI 超分`。
- 不引入 `CanvasNodeType.Audio`，不引入 `CanvasNodeMaskEditDialog`。

新增单元测试：

```text
canvas-image-toolbar-tools.test.tsx
canvas-image-data.test.ts
```

验证：

- 默认工具 ID 顺序。
- unknown / maskEdit ID normalize 后丢弃。
- 旧数组 localStorage 配置可读。
- `resolveUpscaleSize()` 横图、竖图、异常 target 都稳定。

## 验收标准

1. 参考项目新增的前端可闭环功能，本批全部补齐。
2. 同名功能交互和样式按参考项目，不再“差不多”。
3. mask/audio/video multipart 明确留到后续契约，不显示成假能力。
4. `npm run test`、`npm run typecheck`、`git diff --check` 通过。
5. root `check-agent-governance.ps1 -Mode working` 通过。
