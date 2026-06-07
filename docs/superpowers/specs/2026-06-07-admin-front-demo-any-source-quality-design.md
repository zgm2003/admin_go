# Admin Front Demo Any Source Quality Spec

日期：2026-06-07

## 需求分析

【需求判断】
是真问题。Admin Vue source-quality inventory 剩余 `any` 都集中在 demo/display/effect 代码里；继续保留会让后续开发复制错误形状。

【核心问题】
数据结构没有名字：form demo 的表单/远程参数、display demo 的透传列属性、ParticleBackground 的粒子/鼠标状态都不应该靠 `any` 通过类型检查。

【复杂度检查】
不重构页面、不改 UI、不碰 API。只给现有数据结构命名，并用 guard 锁住坏写法。

【破坏性分析】
不改路由、接口、DOM 结构或用户操作。ParticleBackground 的 `dpr` 和距离处理从隐藏 `|| 1` 改为显式函数，行为等价但失败点可见。

## 代码分析

【数据结构】
`SearchFormModel`、`RemoteListFetchMethod`、`MockRemoteSelectParams`、`Record<string, unknown>`、`Particle`、`PointerPosition` 是本切片核心结构。

【特殊情况】
`any` 和 `|| 1` 是设计缺口，不是业务降级。用显式类型和 invariant helper 消灭。

【复杂度】
局部类型和小函数足够；不引入新 composable、不拆组件、不创建领域抽象。

【兼容性】
保留 demo 行为和 canvas 动画行为。source guard 只阻止旧坏形状回归。

【结论】
值得做。目标是把 current inventory 的 `any/as any/catch-any/direct external HTTP` 行清为 0，同时明确 fallback 债务仍未关闭。
