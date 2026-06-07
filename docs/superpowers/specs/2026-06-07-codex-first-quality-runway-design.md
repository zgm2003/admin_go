# Codex-first Quality Runway Spec

日期：2026-06-07

## 需求分析

【需求判断】
是真问题。现有知识库有大量事实 artifact，但缺少一条后续质量递进路线，容易导致 agent 横向乱扫或把 fallback 债务误写成已完成。

【核心问题】
需要把 Go capability、Admin Vue source-quality、Canvas Next performance/contract、live DB schema 四条线收敛到同一套 Codex-first 执行门槛。

【复杂度检查】
只新增一个架构路线图和 checker 引用，不引入新工具、不改变现有 agent 体系。

【破坏性分析】
纯文档治理切片，不改变 runtime 行为。

## 代码分析

【数据结构】
路线图的数据结构是：事实基线 -> 递进规则 -> agent 选择 -> runway -> 每轮收口门槛。

【特殊情况】
Admin Vue fallback 不等于 bug，必须按类别审查；Canvas/Go/DB 也不能用单个 inventory 代替 runtime 证据。

【复杂度】
一个 `09-codex-first-quality-runway.md` 足够，不复制完整冷启动清单。

【兼容性】
只在 `docs/README.md` 冷启动顺序追加一项，保持原入口不变。

【结论】
值得做。它让后续 Codex 有明确 next-step，但不会把未来工作写成已完成。
