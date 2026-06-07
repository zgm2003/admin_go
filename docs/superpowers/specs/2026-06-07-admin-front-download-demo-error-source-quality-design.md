# Admin Front Download Demo Error Source Quality Spec

日期：2026-06-07

## 需求分析

【需求判断】
是真问题。下载 demo 页面仍把错误写成 `catch (error: any)`，并用 `error.message || '下载失败'` 掩盖空错误消息；文档示例也在传播同样写法。

【核心问题】
错误边界必须从 `unknown` 收口到非空 `Error.message`。空 message 或非 Error 是异常，不应该被兜底成“下载失败”。

【复杂度检查】
不重构 demo 页面、不拆组件、不批量 i18n；只加一个局部 helper 和一个 source guard。

【破坏性分析】
保留下载 demo UI、下载调用、用户取消返回值语义。批量下载遇到真实错误时停止并展示真实错误，不再吞掉。

## 代码分析

【数据结构】
错误只有两类：合法 Error 且 message 非空；非法错误原因。

【特殊情况】
`error.message || '下载失败'` 是兜底掩盖 bug；空错误消息应该暴露。

【复杂度】
一个局部 `requireDownloadDemoErrorMessage()` 足够。

【兼容性】
不改组件导出、不改路由、不改 DownloadManager API。

【结论】
值得做。关闭下载 demo 页 catch-any，并让示例不再教坏模式。
