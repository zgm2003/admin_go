# Admin Front AI Image Payload Source Quality Spec

日期：2026-06-07

## 需求分析

【需求判断】
是真问题。`src/api/ai/images.ts` 的 create-task payload 用 `payload.* || undefined` 把空值、非法值和省略值混在一起；mask ID 也靠 truthy 判断跳过 `0`。

【核心问题】
可选枚举和可选 ID 是两种不同数据结构：枚举允许 UI 传 `''` 表示省略；ID 只允许 `undefined` 表示省略，非法数字必须 fail-closed。

【复杂度检查】
不改页面、不改后端、不改路由。只给 normalization 加两个小 helper，并加 source guard 防回归。

【破坏性分析】
正常空枚举仍省略；合法 mask ID 行为不变。`0` 不再被静默忽略，这是故意暴露坏状态。

## 代码分析

【数据结构】
`optionalImageEnum` 管 enum/空字符串；`optionalPositiveID` 管可选 ID。

【特殊情况】
`|| undefined` 和 truthy ID 检查是兜底，不是业务规则。业务规则必须显式。

【复杂度】
两个局部函数足够，不抽通用全局 helper。

【兼容性】
保留 `AiImageTaskCreatePayload` 和 `AiImageApi.createTask`。

【结论】
值得做。关闭 4 个 payload logical-or fallback 行，并把 inventory 从 `559` fallback 降到 `555`。
