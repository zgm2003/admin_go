# Admin Front DownloadManager Filename Source Quality Spec

日期：2026-06-07

## 需求分析

【需求判断】
是真问题。`admin_front_ts/src/components/DownloadManager/src/download.ts` 的错误边界已经 fail-closed，但文件名推导仍使用 `|| 'download'`、`options.filename || ...`、`savePath... || ...`，会把“输入为空/URL 无文件名/保存路径异常”混在一起。

【核心问题】
文件名推导是业务规则，不是兜底。需要显式区分：用户提供的非空 filename、URL 最后一段、默认下载文件名，以及保存路径文件名缺失时回到已验证的 suggested filename。

【复杂度检查】
不拆 DownloadManager，不改下载 API，不处理组件 UI fallback。只在 `download.ts` 增加小型纯函数并用 source guard 锁住形态。

【破坏性分析】
保留 `downloadFile(url, filename, options)` 签名、Tauri 保存对话框、Web blob 下载和默认文件名 `download` 行为。变化只是默认值来源从隐式逻辑或变成显式函数。

## 代码分析

【数据结构】
文件名来源按优先级排序：trim 后非空参数 filename → trim 后非空 URL 文件名 → `DEFAULT_DOWNLOAD_FILENAME`。
保存路径文件名来源：trim 后非空 savePath basename → suggested filename。

【特殊情况】
URL 为空尾段、query-only 尾段、filename 为空字符串都不是“随便 ||”的问题，应该由命名函数表达。

【复杂度】
三个纯函数足够：`filenameFromURL`、`resolveSuggestedDownloadFilename`、`resolveSavePathFilename`。

【兼容性】
不改导出、不改 UI、不改 i18n key、不改 Tauri command payload shape。

【结论】
值得做。它把 DownloadManager priority evidence 从“filename fallback review rows only”推进到“no configured source-quality finding”。
