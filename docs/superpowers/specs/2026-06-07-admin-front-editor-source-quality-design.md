# Admin Front Editor Source Quality Spec

日期：2026-06-07

## 需求分析

【需求判断】
是真问题。`admin_front_ts/src/views/Main/component/display/components/Editor.vue` 是当前 Admin Vue source-quality inventory 中唯一 `as any` 文件，同时在同一 wangEditor 上传链路里存在多个 `any` 和 `result.url || ''` URL 兜底。

【核心问题】
真正需要解决的是富文本 wrapper 的边界类型缺失：wangEditor 实例、配置、菜单上传回调和 markdown module 注册都应由显式类型表达；COS 上传返回的 `url` 属于上传契约，空 URL 必须 fail closed，不能插入空字符串。

【复杂度检查】
不引入新抽象层、不拆 UI、不改上传业务；只在 `Editor.vue` 内用最小局部类型收口第三方配置边界，并用一个 focused Vitest source guard 防止回退。

【破坏性分析】
不改 props 名称、默认值、emits、`defineExpose({ getEditorRef })`、wangEditor toolbar/editor 结构或 COS 上传调用顺序；只把原本不可靠的空 URL 静默插入改为显式异常。

## 代码分析

【数据结构】
`editorRef` 应表达为 wangEditor `IDomEditor | null`，`editorConfig` 应是富文本配置对象，`MENU_CONF.uploadImage/uploadVideo.customUpload` 应有明确 insert 函数签名。

【特殊情况】
当前 `editorModule as any`、`editor: any`、`base/user/menu/merged: any` 都是类型结构缺失导致的特殊情况。`result.url || ''` 是用兜底掩盖上传契约破坏。

【复杂度】
保持单组件。新增局部 helper：

- `showEditorAlert`
- `cloneMenuConfig`
- `installCosUploadHandlers`
- `requireUploadURL`

这些 helper 只隔离第三方边界，不扩散抽象。

【兼容性】
保留：

- `editorId` 默认 `wangeditor-1`
- `height` 默认 `500px`
- `modelValue` 默认空字符串
- `uploadFolder` 默认 `article`
- `useCosUpload` 默认 `true`
- `change` / `update:modelValue`
- `getEditorRef`

【结论】
值得做。它关闭唯一 `as any` 文件，并减少同一文件内 `any` 与上传 URL 兜底债务；这是真实质量问题，不是为了架构图而重构。

## Scope

### In scope

- `admin_front_ts/src/views/Main/component/display/components/Editor.vue`
- 新增 focused source-quality guard test
- 刷新 Admin Vue source-quality inventory
- 同步当前知识库/status/fact-checker 文档口径

### Out of scope

- 不改 wangEditor UI/toolbar 配置
- 不新增 i18n 文案
- 不改上传 API、COS token、upload client
- 不处理其它 inventory rows
- 不重做 component demo 页面

## Acceptance

- `Editor.vue` 源码不包含 `any` / `as any`
- `Editor.vue` 源码不包含 `result.url ||`
- markdown module 注册使用 typed `Boot.registerModule(markdownModule.default)`
- `editorRef` 使用 `shallowRef<IDomEditor | null>(null)`
- `cfg` 使用 `computed<...IEditorConfig...>`
- 图片/视频 customUpload insert 函数有局部显式类型
- 上传 URL 使用 `requireUploadURL(result.url)`，空 URL 抛错
- targeted Vitest 与 `npm run typecheck` 通过
- inventory 刷新后 `as_any_candidates` 从 `1` 降为 `0`
