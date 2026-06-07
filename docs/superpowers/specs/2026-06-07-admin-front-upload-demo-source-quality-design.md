# Admin Front Upload Demo Source Quality Spec

日期：2026-06-07

## 需求分析

【需求判断】
是真问题。`admin_front_ts/src/views/Main/component/upload/index.vue` 是上传组件示例页，`ref<any[]>` 把 `UpMediaList` 的模型结构藏掉，会让后续调用方继续复制 any。

【核心问题】
上传媒体列表的数据结构必须有名字：`{ name, url, uid }`。父 demo 和子组件应该共享同一个类型，而不是各自靠 `any` 或隐式结构猜。

【复杂度检查】
不重构上传组件、不改上传流程、不处理 `UpMediaList.vue` 里的 URL 预览 fallback。只抽一个本地 `UploadMediaItem` 类型、清掉父页面 `ref<any[]>`，加 source guard 和知识库事实。

【破坏性分析】
不改 route、不改 UI、不改 `v-model` 值形状。TypeScript 层更严格，运行时行为保持。

## 代码分析

【数据结构】
`UploadMediaItem` 是唯一模型结构：`name: string`、`url: string`、`uid: number`。

【特殊情况】
`ref<any[]>` 是设计缺口，不是业务降级。用共享类型消灭特殊情况。

【复杂度】
一个 `media.ts` 足够；不需要上传领域模型包或通用泛型抽象。

【兼容性】
保留 `UpMediaList v-model` 结构兼容；现有 demo 数据仍是空数组初始值。

【结论】
值得做。关闭一个剩余 any 行，并把当前 inventory 同步为 `280 files / 7 any / 562 fallback`。
