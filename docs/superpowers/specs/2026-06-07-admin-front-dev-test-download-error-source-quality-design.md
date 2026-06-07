# Admin Front Dev Test Download Error Source Quality Spec

日期：2026-06-07

## 需求分析

【需求判断】
是真问题。`admin_front_ts/src/views/Main/test/index.vue` 是当前 Admin Vue dev test 下载入口，仍存在 `catch (error: any)`、错误消息兜底和 filename `|| undefined` 示例，会把坏模式继续传播。

【核心问题】
下载错误边界必须从 `unknown` 收口到非空 `Error.message`；可选 filename 是业务规则，必须显式表达，不能用逻辑或兜底掩盖空值。

【复杂度检查】
不拆页面、不重构 DownloadManager、不扩大到全部 fallback backlog。只加两个局部 helper、一个 source guard、刷新 inventory 和知识库事实。

【破坏性分析】
不改路由、不改 UI、不改 DownloadManager API。唯一行为变化是非 Error 或空错误消息不再被 generic 文案吞掉。

## 代码分析

【数据结构】
错误原因只有两类：合法 Error 且 message 非空；非法错误原因。filename 只有两类：trim 后非空字符串；无 filename。

【特殊情况】
`error.message || ...` 和 `testFilename.value || undefined` 是隐式兜底，必须被显式 helper 替代。

【复杂度】
局部函数足够，无需抽 composable 或通用错误框架。

【兼容性】
保留 `/Main/test` 页面、下载入口、预设文件和批量下载流程。

【结论】
值得做。关闭最后一个 dev test 下载 catch-any 行，并同步文档事实，避免 planned/implemented 漂移。
