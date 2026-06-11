# Canvas 生图核心交互与性能极限化设计

日期：2026-06-11
状态：spec written for user review；尚未实现
主角色：frontend-adapter（Canvas Next 前端交互/性能窄切片）
目标工作区：`E:/admin_go/canvas_front_next`

## 需求结论

用户明确确认：本轮 Canvas 产品主流程只服务 **文字节点 + 图片节点**。Video / Audio / Config 不删除，但从核心生图交互里降级为兼容能力；不要再围绕多媒体大而全继续堆交互。

本轮要解决的不是单个 bug，而是用户心智断裂：

```text
用户把文字和图片连到一个图片节点上，系统就应该理解：这些都是这次生图的上下文。
用户选中一个节点生图，系统就应该对这个节点生图，不应被 hover、旧面板或旧批量根节点抢走。
用户不应该为了让连接生效被迫手动 @。
节点很多时，画布仍要保持可拖、可选、可编辑、可生成。
```

设计原则一句话：

```text
连接即上下文；@ 是高级精确控制，不是生图前置条件。
```

## 当前痛点与根因

### 1. 连接后不一定自动生效

当前 `buildNodeGenerationContext()` 在普通 prompt 路径会自动拼接上游文本和图片引用，但一旦 Config 节点存在 `composerContent`，逻辑进入 `buildComposerGenerationContext()`，只有 `@[node:<id>]` token 命中的节点才会被选中。用户已经连线但没有手动 @ 时，连接可能不进入生成上下文。

证据：

- `composerContent` 优先进入 composer 解析：[E:/admin_go/canvas_front_next/src/app/(user)/canvas/components/canvas-node-generation.ts:31](/E:/admin_go/canvas_front_next/src/app/(user)/canvas/components/canvas-node-generation.ts#L31)
- composer 无 token 时返回空引用上下文：[E:/admin_go/canvas_front_next/src/app/(user)/canvas/components/canvas-node-generation.ts:82](/E:/admin_go/canvas_front_next/src/app/(user)/canvas/components/canvas-node-generation.ts#L82)

### 2. 图片节点自身参考会压掉上游连接

图片模式生成时，如果源节点本身是已有图片，当前逻辑构造 `sourceReference` 后使用：

```text
sourceReference.length ? sourceReference : generationContext.referenceImages
```

这会让“目标图片自身”覆盖连接进来的图片/文字上下文。用户把“图片节点 + 文字节点”连到另一个图片节点时，期望三者都参与；当前代码容易只使用目标自身或只使用部分上下文。

证据：

- 自身图片优先分支：[E:/admin_go/canvas_front_next/src/app/(user)/canvas/[id]/canvas-client-page.tsx:1898](/E:/admin_go/canvas_front_next/src/app/(user)/canvas/[id]/canvas-client-page.tsx#L1898)
- `requestEdit()` 接收 referenceImages 后走图片编辑接口：[E:/admin_go/canvas_front_next/src/services/api/image.ts:302](/E:/admin_go/canvas_front_next/src/services/api/image.ts#L302)

### 3. 选中节点、悬停节点、面板节点和运行节点可能漂移

当前活跃节点是：

```text
hoveredNodeId || selectedNodeId
```

也就是 hover 优先于 selected。用户选中图片 2 后，鼠标经过图片 1，资源上下文和高亮可能切到图片 1。与此同时，`dialogNodeId`、`selectedNodeIds`、`hoveredNodeId`、`runningNodeIds` 又是多套状态。用户会感觉“我明明选了 2，为什么还像在用 1 生图”。

证据：

- active node 计算：[E:/admin_go/canvas_front_next/src/app/(user)/canvas/[id]/canvas-client-page.tsx:587](/E:/admin_go/canvas_front_next/src/app/(user)/canvas/[id]/canvas-client-page.tsx#L587)
- 点击节点后才切 `dialogNodeId`：[E:/admin_go/canvas_front_next/src/app/(user)/canvas/[id]/canvas-client-page.tsx:1003](/E:/admin_go/canvas_front_next/src/app/(user)/canvas/[id]/canvas-client-page.tsx#L1003)

### 4. 用户看不到“本次生成到底带了什么”

配置节点内部已有 `inputSummary`，但它只是数量 chip；普通图片节点、文本节点生图路径没有统一的“将使用：文本 1 个、图片 2 张、自身图 1 张”预执行反馈。用户自然会质疑 @ 是否有效、连接是否有效、图片是否真的送给模型。

证据：

- Config 面板展示输入数量：[E:/admin_go/canvas_front_next/src/app/(user)/canvas/components/canvas-config-node-panel.tsx:81](/E:/admin_go/canvas_front_next/src/app/(user)/canvas/components/canvas-config-node-panel.tsx#L81)
- 普通节点 prompt panel 没有同级上下文摘要：[E:/admin_go/canvas_front_next/src/app/(user)/canvas/components/canvas-node-prompt-panel.tsx:57](/E:/admin_go/canvas_front_next/src/app/(user)/canvas/components/canvas-node-prompt-panel.tsx#L57)

### 5. 大量节点性能热点明显

当前页面每次 `nodes/connections` 变化都会为每个节点构建 mention references：

```text
nodes.forEach((node) => map.set(node.id, buildNodeMentionReferences(node, nodes, connections)))
```

这会重复扫描连接和节点。节点数量多、连接多、拖拽频繁时，热点会被放大。

证据：

- 全量 mention map：[E:/admin_go/canvas_front_next/src/app/(user)/canvas/[id]/canvas-client-page.tsx:592](/E:/admin_go/canvas_front_next/src/app/(user)/canvas/[id]/canvas-client-page.tsx#L592)
- 可视节点已有裁剪，但上下文计算仍基于全量 nodes：[E:/admin_go/canvas_front_next/src/app/(user)/canvas/[id]/canvas-client-page.tsx:566](/E:/admin_go/canvas_front_next/src/app/(user)/canvas/[id]/canvas-client-page.tsx#L566)

### 6. 当前有未提交 WIP，必须保护

`canvas_front_next` 当前已有未提交改动，涉及：

```text
canvas-resource-mention-textarea 光标/高亮滚动同步
canvas-node-prompt-panel / infinite-canvas data-canvas-no-zoom 滚轮保护
canvas-merge-import anchor 自动连接
```

本 spec 后续实现不得覆盖这些 WIP。若要改同一文件，必须先把现有 diff 当作 baseline 继续增量修改，并保留其测试。

## 设计目标

1. **连接即上下文**：图片节点或文本节点连接到目标图片节点后，生成默认自动读取这些输入。
2. **图片 + 文字共同参考**：目标图片节点可同时使用自身图片、上游图片和上游文字。
3. **@ 降级为高级控制**：不 @ 也生成；@ 只用于指定顺序、强调、或未来“仅使用 @”模式。
4. **目标节点不漂**：生成目标优先级固定，不能被 hover 抢走。
5. **生图前可解释**：按钮附近展示本次会使用哪些输入，让用户放心。
6. **大量节点不卡**：第一阶段减少全量上下文计算，后续再做拖拽/渲染更深优化。
7. **兼容旧数据**：旧 `prompt`、`composerContent`、`inputOrder`、批量图片 metadata 都必须继续可用。

## 非目标

本轮不做：

- 删除 Config / Video / Audio 节点。
- 新增后端 API 或改变 `/api/canvas/v1/ai/images*` 契约。
- 浏览器提交 provider/model/api_key/base_url。
- 视频/音频参考媒体真实生成能力。
- 重写整个 Canvas 引擎。
- 把 `canvas-client-page.tsx` 一次性大拆分。

## 产品规则

### 规则 1：目标节点选择优先级

统一使用一个“明确生成目标”规则：

```text
explicit target from clicked button
> dialogNodeId / open panel node
> single selected node
> hovered node only for visual preview
```

含义：

- 用户点某个节点上的“生图”按钮，目标就是该节点。
- 用户打开某个节点的面板，面板上下文跟随该节点。
- 单选节点时，hover 其他节点不能改变生成上下文。
- hover 只做高亮和工具条显示，不参与生成目标决策。

### 规则 2：图片生成上下文默认自动合并

目标为图片生成时，输入来源分四类：

```text
basePrompt       # 用户在目标面板或节点里输入的提示词
upstreamTexts    # 所有连接进来的文本节点内容
upstreamImages   # 所有连接进来的图片节点内容
selfImage        # 如果目标图片节点自己已有图，则作为参考图之一
```

默认组合：

```text
finalPrompt = basePrompt + upstreamTexts（按 inputOrder/连接顺序追加）
referenceImages = dedupe(selfImage + upstreamImages 或 upstreamImages + selfImage，具体顺序见下）
```

顺序策略：

- 如果用户在 `composerContent` 里写了 @，@ 命中的输入按 @ 出现顺序优先。
- 未被 @ 命中的已连接输入仍追加到上下文尾部，不能静默丢掉。
- 没有 @ 时按 `inputOrder`，再按连接创建顺序。
- 自身图片默认放在 referenceImages 第一位，因为“修改这张图”是最直觉行为；上游图片继续追加，不能被压掉。

### 规则 3：Config composer 的新语义

旧语义：

```text
有 composerContent 且没有 @ => 只发送 composerContent，不带任何连接输入
```

新语义：

```text
有 composerContent 且没有 @ => composerContent 作为 basePrompt，同时自动带所有连接输入
有 composerContent 且有 @ => @ 命中输入优先排序，未 @ 的连接输入仍自动补入
```

后续如需“只使用 @ 引用”，另加显式开关，不能把它作为默认行为。

### 规则 4：生图前展示上下文摘要

在图片节点 prompt panel 和 Config 节点面板都展示统一摘要：

```text
将使用：文本 1 个 · 参考图 2 张
来源：自身图片、图片1、文本1
模式：图生图 / 文生图
```

交互要求：

- 摘要必须来自同一套 generation context builder，不另写一套 UI 猜测逻辑。
- 缺失参考图时要显示失败原因，而不是到请求阶段才突然报错。
- 如果没有 prompt 也没有上游文本，应禁用生成并提示“需要提示词或文字输入”。

### 规则 5：只把文字/图片作为核心可见主链路

实现时保留 Audio / Video 的已存在数据结构与测试，但核心摘要和主按钮优先表达：

```text
文字输入
图片参考
图片输出
```

Video / Audio 不作为本轮体验优化目标；若现有测试覆盖这些能力，保持不破坏即可。

## 目标架构

### 1. 上下文 builder 收口

新增或重构一个纯函数边界，建议命名：

```text
buildImageGenerationContext(options)
```

职责：从节点、连接、目标 nodeId、base prompt 推导完整图片生成上下文。

输入：

```ts
type BuildImageGenerationContextInput = {
  nodeId: string
  nodes: CanvasNodeData[]
  connections: CanvasConnection[]
  prompt: string
  includeSelfImage: boolean
}
```

输出：

```ts
type ImageGenerationContext = NodeGenerationContext & {
  selfImageCount: number
  upstreamImageCount: number
  upstreamTextCount: number
  summary: {
    mode: "text-to-image" | "image-to-image"
    labels: string[]
  }
}
```

约束：

- 纯函数，不访问 React state、DOM、axios、store。
- 去重按 nodeId，避免同一图片被自身和连接重复加入。
- 继续复用 `hydrateNodeGenerationContext()` 处理图片数据恢复。
- 不在 `canvas-client-page.tsx` 内手写引用合并。

### 2. 连接索引

为上下文和高亮构建一次索引：

```text
nodeById: Map<string, CanvasNodeData>
incomingByNodeId: Map<string, CanvasConnection[]>
outgoingByNodeId: Map<string, CanvasConnection[]>
```

`getContextResourceNodes()` / `getConnectedConfigResourceNodes()` 后续应优先走索引，避免每个节点重复 `connections.filter()`。

第一刀可以保持 API 兼容，先在内部建索引；后续再把签名替换成 index-aware 版本。

### 3. Mention references 懒计算

替换全量：

```text
nodes.forEach(buildNodeMentionReferences)
```

为按需：

```text
visibleNodes + dialogNodeId + editingNodeId + active explicit target
```

规则：

- 不可见且未编辑的节点，不需要 mention references。
- 当前打开面板节点必须有 references。
- 正在编辑文本节点必须有 references。
- hover 不触发全局重算。

### 4. 目标节点状态收口

新增轻量 helper，建议命名：

```text
resolveCanvasInteractionTarget({ explicitNodeId, dialogNodeId, selectedNodeIds, hoveredNodeId })
```

用于 UI 预览/高亮时的默认输出：

```text
explicitNodeId || dialogNodeId || singleSelectedNodeId || hoveredNodeId
```

生成调用使用更严格规则：必须传 explicitNodeId，或明确使用 `dialogNodeId / singleSelectedNodeId`；不能依赖 hover 推断。hover 只允许影响视觉高亮和工具条可见性。

### 5. UI 摘要组件

新增轻组件，建议命名：

```text
CanvasGenerationContextSummary
```

使用场景：

- `CanvasNodePromptPanel`
- `CanvasConfigNodePanel`

输入只接收 context summary，不自己从 nodes/connections 推导。

## 关键用户流

### 流 1：文字节点 -> 图片节点

步骤：

1. 用户写一个文字节点：`赛博城市雨夜，霓虹反光`。
2. 用户连到一个空图片节点。
3. 用户点击图片节点“生成”。

期望：

```text
prompt = 图片节点 prompt + 文本节点内容
referenceImages = []
mode = 文生图
摘要显示：文本 1 个 · 参考图 0 张
```

用户不需要 @。

### 流 2：图片节点 + 文字节点 -> 图片节点

步骤：

1. 图片 A 是角色参考。
2. 文字 B 是动作说明。
3. A 和 B 都连接到图片 C。
4. 用户在 C 点击生成。

期望：

```text
prompt 包含 C 的 prompt + B 的文字内容
referenceImages 包含 A
mode = 图生图
摘要显示：文本 1 个 · 参考图 1 张
```

### 流 3：已有图片节点继续改图

步骤：

1. 图片 C 已有内容。
2. 用户给 C 连入文字 B 和图片 A。
3. 用户在 C 输入“换成黄昏光线”并生成。

期望：

```text
prompt 包含“换成黄昏光线” + B
referenceImages 包含 C 自身图片 + A
mode = 图生图
```

不能因为 C 自身有图就丢掉 A/B。

### 流 4：Config composer 有 @

步骤：

1. Config 连接图片 A、图片 B、文本 C。
2. composer 写：`参考 @[node:B] 的构图，角色使用 @[node:A]`。

期望：

```text
@ 命中的 B/A 按出现顺序优先
未 @ 的文本 C 仍追加为文本上下文
prompt 中使用 图片1/图片2 或可解释标签
referenceImages 包含 B/A，顺序稳定
```

### 流 5：选中 2，hover 1

步骤：

1. 用户选中图片 2。
2. 鼠标移过图片 1。
3. 用户按图片 2 面板生成。

期望：

```text
生成目标 = 图片 2
hover 只影响图片 1 的视觉 hover，不改变生图上下文
```

## 实现切片建议

### Slice 1：上下文可信（第一刀）

范围：

- `canvas-node-generation.ts`
- `canvas-node-generation.test.ts`
- `canvas-client-page.tsx` 内最小调用点
- `canvas-node-prompt-panel.tsx` / `canvas-config-node-panel.tsx` 摘要入口（可先轻量）

内容：

- composerContent 无 @ 时自动带连接输入。
- composerContent 有 @ 时 @ 优先，未 @ 连接输入补入。
- 图片自身参考与上游参考合并、去重。
- 生成 metadata 记录完整 references。

### Slice 2：目标节点不漂

范围：

- `canvas-client-page.tsx`
- 对应源约束或行为测试

内容：

- active target helper。
- selected 优先于 hover。
- 生成调用传 explicit node id。
- 面板上下文不被 hover 改写。

### Slice 3：上下文摘要 UI

范围：

- 新增 `CanvasGenerationContextSummary`
- 接入 `CanvasNodePromptPanel`
- 接入 `CanvasConfigNodePanel`

内容：

- 显示文本/图片数量和模式。
- 显示“连接会自动生效，@ 可精确排序”的短提示。
- 禁用不可生成状态。

### Slice 4：性能第一刀

范围：

- `canvas-client-page.tsx`
- `canvas-resource-references.ts`

内容：

- 连接索引。
- mention refs 按需计算。
- `CanvasNode` memo 可作为后续增强，不强塞进第一刀。

## 测试策略

### RED 测试先行

实现前先写失败测试，至少覆盖：

1. Config 有 composerContent 但没有 @ 时，连接的文本/图片仍进入上下文。
2. Config 有 @ 时，未 @ 的连接文本不会被静默丢弃。
3. 已有图片节点生成时，自身图片和上游图片都会进入 referenceImages。
4. referenceImages 按 nodeId 去重。
5. 生成目标 helper 中 selected/dialog 优先于 hover。
6. mention references 不再对全部 nodes 无条件构建（可用源约束或纯函数测试）。

### 建议命令

在 `E:/admin_go/canvas_front_next`：

```powershell
npm run test -- "src/app/(user)/canvas/components/canvas-node-generation.test.ts" "src/app/(user)/canvas/utils/canvas-resource-references.test.ts"
npm run test -- "src/app/(user)/canvas/components/canvas-composer-layout.test.ts" "src/app/(user)/canvas/components/canvas-resource-mention-textarea.test.ts"
npm run typecheck
```

在 `E:/admin_go`：

```powershell
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

如果改动状态文档或知识库，再加：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1
```

## 验收标准

### 功能验收

- 文字节点连接图片节点后，不 @ 也能作为 prompt 输入。
- 图片节点连接图片节点后，不 @ 也能作为 reference image。
- 图片节点同时连接文字和图片时，两者都参与生图。
- 已有图片节点继续生图时，自身图片和上游图片都参与，不互相覆盖。
- 选中节点与 hover 节点不一致时，生成目标仍是明确选中/面板节点。
- UI 明确展示这次会使用多少文字和图片参考。

### 性能验收

- 可视节点裁剪继续生效。
- 不再每次渲染为所有节点构建 mention references。
- 连接索引用于减少重复扫描。
- 不引入新的全局 store 订阅导致整页重渲染。

### 契约验收

- 图片请求仍走 `/api/canvas/v1/ai/images/generations` 或 `/api/canvas/v1/ai/images/edits`。
- 前端仍只提交 `agent_id`、prompt、size、quality、n、image files。
- 不提交 provider/model/api_key/base_url。
- 不新增 Go 后端路由，不新增 DB schema。

## 风险与处理

### 风险 1：改变 composer 老用户预期

老用户可能习惯“只有 @ 才使用连接输入”。但当前用户反馈明确说明默认不应如此。处理方式：

- 默认改为连接自动生效。
- 后续如果需要精确模式，新增显式开关“仅使用 @ 引用”。

### 风险 2：图片参考数量过多

当前 `requestEdit()` 会把 references 全部转 FormData。若未来连接图片很多，可能超过 provider 限制。

本轮先不引入复杂策略；若需要，可加明确上限和 UI 提示：

```text
最多使用前 7 张参考图；超出的显示为未发送
```

但不能静默截断。

### 风险 3：与当前 WIP 冲突

当前子仓有光标/滚轮/merge anchor 未提交改动。实现时必须：

- 保留现有 diff。
- 不重置、不覆盖。
- 同文件改动先读 diff，再做增量 patch。

## 回滚方案

- 恢复 `buildNodeGenerationContext()` composer 无 token 行为。
- 恢复图片生成 `sourceReference ? sourceReference : generationContext.referenceImages` 分支。
- 移除新增摘要组件。
- 移除目标 helper，回到旧 active node 规则。
- 因本轮不做数据迁移，回滚不涉及 DB 或后端。

## 后续方向

如果第一刀验证通过，再进入：

1. 拖拽性能：拖动时使用 transient ref/transform，鼠标释放后提交节点位置。
2. 图片节点渲染：缩略图层、预览层、原图懒加载分离。
3. 大画布索引：节点空间索引用于 hit-test 和连接线裁剪。
4. 批量生图体验：每张输出明确“设为主图 / 继续衍生 / 替换源图”。
5. “仅使用 @ 引用”高级模式：给精准工作流用，但默认仍是连接即上下文。
