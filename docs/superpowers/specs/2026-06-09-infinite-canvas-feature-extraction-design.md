# Infinite Canvas Feature Extraction Design

状态：draft for user review  
日期：2026-06-09  
目标项目：`E:\GitDownload\infinite-canvas`  
来源项目：`E:\admin_go\canvas_front_next`

## 背景

用户要求把当前增强版里“多出来的功能”提取到目标项目 `E:\GitDownload\infinite-canvas`，并按 P 阶段全部落地。

只读盘点结论：

- 目标项目根目录是 Go + Gin + GORM 后端，前端在 `web/`。
- 目标前端 API 当前使用 `/api/auth/*`、`/api/v1/images/*`、`/api/v1/videos`、`/api/assets`、`/api/prompts` 等目标项目原生契约。
- 来源前端是 admin_go Canvas Next 适配版，依赖 `/api/canvas/v1/*`、Canvas RBAC、后端托管 AI agent、Canvas 当前用户素材和 admin_go 登录/权限模型。
- 目标项目已经拥有一些来源项目没有的上游能力：管理后台、音频节点、蒙版编辑、公开素材库、算力点、Seedance/音频相关功能。迁移时不得用来源项目覆盖或删除这些能力。

因此迁移策略不是整目录复制，而是：

```text
提取可复用能力 -> 映射到目标项目现有 API/状态模型 -> 保留目标项目已有功能 -> 用测试锁关键边界
```

## 非目标

本次迁移不做以下事项：

- 不把目标项目改成 admin_go 的 `/api/canvas/v1/*` 契约。
- 不删除目标项目已有管理后台、音频节点、蒙版编辑、算力点、公开素材库等能力。
- 不引入 admin_go 后端模块、数据库表或 RBAC 字典作为硬依赖。
- 不一次性重构目标项目目录结构。
- 不把来源项目的测试原样照搬到不适配目标契约的场景。

## P 阶段划分

### P0：安全底座与测试能力

目标：先建立最小测试与基础防线，确保后续迁移能被验证且不破坏目标项目。

范围：

- 给目标 `web/` 增加 Vitest 测试脚本和配置。
- 迁入或重写与目标契约无关的纯工具测试：
  - data URL 转文件拒绝空内容。
  - storage fallback 不复用失效 blob URL。
  - 图片引用提示词编号稳定。
- 可选迁入 `scripts/dev-open-browser.mjs`，但不强制改变目标默认 dev 命令，除非单测和用户确认需要。

成功标准：

- `web` 能运行 targeted Vitest。
- P0 不改变目标 API 行为和页面路由。
- 目标项目现有前端文件不会被大面积重排。

### P1：Canvas 文本、资源引用和高度链修复

目标：迁入来源项目里独立且用户可见价值高的画布编辑体验。

范围：

- 文本节点和节点底部 prompt 面板支持 `@资源` 候选与蓝色 token 高亮。
- 资源编号稳定：`图片1`、`视频1`、`音频1`、`文本1`。
- 生成配置节点组装提示词时，保留用户 stale token，不静默删除用户输入。
- 修复 mention textarea 默认 wrapper 高度链，避免文本节点编辑区坍缩。
- 目标项目已有音频节点，所以 P1 迁移时必须保留音频资源引用，而不是照搬来源项目中“不支持音频”的 guard。

成功标准：

- 文本节点编辑态 textarea 占满节点内容区。
- `@` 候选和高亮不会造成 caret 偏移。
- 配置节点引用编号按当前上游资源稳定生成。
- 音频资源仍能参与目标项目已有视频/音频相关流程。

### P4：素材后端持久化增强

目标：优先改进目标已有 `/api/assets` 素材链路的数据质量与稳定性。

范围：

- 复用来源项目的 fail-closed 思路：坏 tags、坏媒体内容、空 bytes、浏览器临时 URL 不能进入后端保存 payload。
- 保留目标项目已有素材导入/导出 zip 功能。
- 映射到目标项目 `/api/assets`，不得引入 `/api/canvas/v1/assets`。
- 可迁入分页并发拉取和完整媒体 metadata 校验。

成功标准：

- 保存图片/视频/音频素材时携带目标项目需要的完整 metadata。
- 导入素材时生成新的后端资产记录，不复用导出包里的旧 slug/id。
- 目标已有素材库页面和画布插入素材路径保持可用。

### P2：后端托管 AI 请求边界映射

目标：吸收来源项目“客户端不再直接提交 provider/API key/base_url/model override”的安全边界，但使用目标项目自己的后端模型渠道系统。

范围：

- 不照搬来源项目 `agent_id` 契约；先映射目标现有 `settings.modelChannel`、公开模型和私有渠道结构。
- 图片生成/编辑和视频生成请求统一经过目标后端代理。
- 保留目标已有 Seedance、音频、蒙版编辑和参考素材能力。
- 迁入错误解析、空 msg fail-closed、轮询上限、JSON blob 错误识别等防线。

成功标准：

- 浏览器不需要保存或提交 provider API key/base_url。
- 图片/视频/音频生成失败时显示后端返回的明确中文错误。
- 不破坏目标已有 `/video`、画布视频、音频节点、蒙版编辑。

### P3：登录、路由守卫和用户状态增强

目标：在最后迁入更强的会话/权限体验，避免先破坏目标项目现有账号、后台和算力点体系。

范围：

- 可迁入：
  - 401 触发跳登录。
  - 403 显示无权限结果页。
  - logout 先请求后端再清本地 session，失败时保留浏览器 session。
  - localStorage 不可用时不崩溃。
- 不直接迁入：
  - admin_go `login-config`。
  - slide captcha。
  - `/api/canvas/v1/users/me`。
  - admin_go Canvas RBAC route 字典。

成功标准：

- 目标原有 `/api/auth/login`、`/api/auth/register`、`/api/auth/me` 保持可用。
- 目标后台和算力点显示不被移除。
- 登录失败、会话过期、后端 logout 失败都有明确 UI 行为。

## 推荐执行顺序

```text
P0 -> P1 -> P4 -> P2 -> P3
```

理由：

1. P0 建测试和安全底座，不改业务。
2. P1 是画布局部 UI/引用能力，收益高、风险低。
3. P4 改素材数据质量，目标已有 API 可映射。
4. P2 涉及 AI 后端代理与模型渠道，风险较高。
5. P3 涉及登录、权限、后台和算力点，最后做。

## 主要风险

- 来源项目和目标项目 API 前缀不同，硬拷会导致所有生成、登录、素材请求失败。
- 目标项目有音频节点，来源项目部分 guard 明确“不支持音频”，迁移时必须改写。
- 目标项目已有管理后台和算力点，来源项目的 free-generation 逻辑不能直接覆盖。
- 目标项目 AGENTS 要求简单直接，避免为了迁移引入多层抽象。

## 验证策略

每个 P 阶段至少包含：

- targeted Vitest 或 Go test，优先覆盖迁移行为。
- TypeScript typecheck。
- `git diff --check`。
- 若修改目标后端，运行对应 Go 包测试。
- 若修改目标文档，更新 `docs/content/docs/progress/pending-test.mdx` 或 `todo.mdx`，不把未人工确认的功能写进正式说明。

## 交付策略

每个 P 阶段独立提交，提交信息建议：

```text
feat(web): add canvas safety test baseline
feat(canvas): port resource mention editing
feat(assets): harden backend asset persistence
feat(ai): route generation through backend channel boundary
feat(auth): harden session guard behavior
```

每个阶段完成后，只把“已实现但需人工验证”的内容移入目标项目 `docs/content/docs/progress/pending-test.mdx`。
