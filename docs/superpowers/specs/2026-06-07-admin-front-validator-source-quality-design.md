# Admin Front useValidator Source Quality Spec

日期：2026-06-07

## 需求分析

【需求判断】
是真问题。`admin_front_ts/src/hooks/web/useValidator.ts` 是表单校验公共边界，`val: any` 和 `message || fallback` 会把类型错误、空消息和 i18n 问题吞掉。

【核心问题】
校验值必须按当前业务输入收口为字符串；自定义 message 缺失才使用 i18n 默认文案，空字符串不能被逻辑或改写。

【复杂度检查】
不引入校验框架、不重写 Element Plus rules、不扩大到全部 fallback backlog。只加局部类型、一个 message resolver、一个 source guard，并刷新知识库事实。

【破坏性分析】
不改 `useValidator()` 返回 API、不改 i18n key、不改 Element Plus callback 调用方式。唯一行为变化是显式传入的空 message 不再被 fallback 文案覆盖。

## 代码分析

【数据结构】
校验输入是 `ValidatorValue = string`；长度规则是 `{ min, max, message? }`；消息解析只有两种状态：`undefined` 表示使用 fallback，其余字符串保持原样。

【特殊情况】
`message || fallback` 是坏兜底，因为它把空字符串和缺失混成一类。改成 `message === undefined ? fallback : message`，特殊情况被数据语义消灭。

【复杂度】
局部 helper 足够；没有必要抽公共错误框架或泛型校验系统。

【兼容性】
保留所有 exported validator 名称和 callback contract；现有调用方仍按 Element Plus 校验规则调用。

【结论】
值得做。关闭公共校验边界的 `any/message fallback` 债务，并把 inventory 同步到 `7 any / 562 fallback`。
