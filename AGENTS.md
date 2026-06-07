# E:\admin_go Agent Guidance

## 核心判断

这是一个 **open-source-first / new-system-first / multi-platform-first Go/Vue workspace**。当前事实源是 Go 后端、Vue 前端、契约文档、smoke 和运行时行为；不要再把本项目当成旧系统收尾半成品，也不要把旧 PHP/Webman 设计当成新 Go 项目的兼容包袱。

后端长期目标是：

```text
一套后端核心能力，一对多服务 admin / app / canvas / openapi / merchant 等前端或平台入口。
```

## 架构词汇（与 docs/architecture/00-platform-and-module-rules.md 对齐）

- `platform` 仅指业务平台：admin / app / canvas / openapi / merchant / miniapp
- `module` 业务能力归属：`internal/module/{capability}/`
- `transport` 能力对某平台的 HTTP 表面：`internal/module/{capability}/transport/{platform}/`
- `shared` 跨领域公共服务：dict / enum / validate / i18n / response / apperror / pagination / setting
- `infra`（infra 运行时技术资源层）：DB / Redis / Queue / Storage / SDK / Logging
- `adapter`（adapter infra 内多供应商实现的角色名）：不是层名

不再使用：
- 旧 `platform` 技术资源目录名作为外部资源目录（已迁至 `internal/infra/`，避免与业务 platform 撞车）
- `api/{platform}/` 顶层分包（弃用 DDD 风格四层）
- "admin only" 作为能力定义（当前 admin 入口 ≠ admin-only）

不要把任何业务能力定义成长期 `admin-only`。当前只有 admin 入口，只能说明当前先暴露 `admin` 平台；当前 canvas 入口、未来 app / openapi / merchant 等入口仍应在同一 capability 下扩展，而不是复制新业务模块。

冷启动判断顺序固定：

```text
1. 先读当前状态，不靠聊天记录猜进度
2. 再读架构、契约、测试文档
3. 再按 agent 角色接手一个窄切片
4. 最后才改代码、跑验证、同步文档
```

工程建设顺序是：

```text
Phase 0: Agent framework and rules
Phase 1: Open-source research and architecture decision
Phase 2: Minimal Go service skeleton
Phase 3: Database and config baseline
Phase 4: Auth and RBAC core
Phase 5: Admin frontend API adaptation
Phase 6: Go/Vue active runtime closure
Phase 7: Go/Vue module evolution
```

## Codex-first 四层治理

本仓库默认是 Codex-first，但不是只靠提示词记忆。

```text
Superpowers       = 需求理解、spec、plan、TDD 工作法
agents/           = 项目角色边界，谁负责什么、不能做什么
Codex hooks       = 对话内提醒、上下文注入、低误伤阻断
Git pre-push hook = push 前轻量治理检查
```

默认顺序：

```text
1. 用 Superpowers 理解需求；新行为/行为变更先 brainstorming
2. 进入实现或 bugfix 前默认 TDD：先失败测试，再生产代码
3. 只选一个项目 agent 主角色，不做全能 agent
4. Codex hooks 只做过程治理，不替代 Git pre-push、smoke 或 runtime 验证
```

执行收敛硬规则：

```text
每轮先把问题归类为 docs drift / code bug / runtime deploy / governance，只推进一个窄切片。
纯文档漂移：可直接修、验证、提交。
代码 bug：先给证据、失败测试和最小修复边界；用户未确认前不把半截生产代码写进仓库。
WIP/失败测试只能写成 verification gap，不能写成 verified change-log。
用户给出明确线上事实（例如前端域名/后端域名）后，必须同步 env、active docs 和 guard test，并搜索残留反例。
连续一轮没有产出 patch、验证结果或明确决策时，必须停下来汇报阻塞点；不准继续横向扫仓库刷时间。
```

## Linus 三问

每个任务开始前先问：

```text
1. 这是个真问题，还是臆想出来的？
2. 有更简单的做法吗？
3. 会破坏已有前端、接口、登录和权限吗？
```

如果答案不清楚，先停下来查证，不要写代码。

## 默认实现硬规则

这些规则不是“建议”。新模块、触碰模块、修边角问题时默认都要检查：

```text
i18n：前后端都必须默认做。后端用 apperror.*Key / response.OKWithMessageKey / 双语 catalog；前端用 vue-i18n，新增可见文案同步 zh-CN.ts / en-US.ts。
CRUD：标准 CRUD 页面默认用 Search + AppTable + AppDialog + useCrudTable；只读列表用 Search + AppTable + useTable。不要手写 el-table、el-dialog、筛选 el-form。
布局：用户说的 body-card 在当前 Vue shell 里对应 Layout page-card。页面默认已经在 page-card 内，不要再套大卡片；表格页必须维护 flex 高度链，内容不能撑破 page-card/body-card。
```

细则统一维护在：

```text
docs/architecture/05-development-quality-rules.md
```

## 不可协商原则

### 0. 代码质量、架构质量、文档真实性永远优先

这是作品级重构，不是能跑就行的临时代码。

每次改动都必须同时维护：

```text
代码质量：简单、明确、可测、无隐藏兜底、无无主 goroutine
架构质量：边界清楚、职责单一、尊重既定分层、不把 Go 写成别的语言
文档质量：API、枚举、缓存、队列、部署、验证命令和运行时事实同步更新
```

没有验证证据，不准说“完成”；文档与运行时冲突时，以运行时为准并修正文档。

知识库、manifest 版本、关键 route/source 或 schema artifact 口径被触碰时，收口验证必须包含：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1
```

如果声明 MySQL live schema 已经重新核准，必须加 `-LiveSchema` 或重新运行 `scripts/export-live-mysql-schema.ps1` 并记录输出。

### 1. 尊重开源，不自嗨设计

架构、RBAC、前端权限、菜单、API 契约、项目结构，默认先找成熟开源项目和国内工程实践。

禁止：

```text
凭感觉自创目录
凭感觉自创 RBAC
凭感觉自创前端权限模型
凭感觉自创中间件堆栈
为了“高级”引入框架
```

允许：

```text
调研开源项目
摘取明确可复用的模式
记录来源、取舍和放弃原因
把复杂开源方案削成当前项目能落地的最小版本
```

### 2. 从低到高，一步一步搭

每一步必须能单独解释、单独验证、单独回滚。

推荐阶段和当前口径：

```text
Phase 0-5: 已经有基线实现，具体状态以 docs/status/current-status.md 为准
Phase 6: active runtime closure 已收口；默认只看 Go/Vue 当前事实
Phase 7: 后续按 Go/Vue runtime 做模块演进、产品补齐和质量 hardening，每次只做一个窄切片
```

禁止跨阶段偷跑。比如 RBAC 或契约没验明，就别写业务模块；Go skeleton 或 smoke 没验证，就别声称基建完成。

### 3. 历史系统不提供新架构规则

历史项目默认不读。只有用户明确要求考古，或当前运行时证据缺失且必须追溯来源时，才允许作为辅助输入。

```text
E:\admin_go\admin_front_ts # current Vue frontend workspace
```

历史系统的路由风格、分层、命名、兼容逻辑，不自动成为 Go 新项目规则；不得把历史系统当成 active runtime 依赖。

### 4. Agent 分工优先于“全能 AI”

项目 agent 角色定义在：

```text
agents/
```

每个 agent 必须遵守：

```text
只做自己的职责
先读必须文档
不越权改文件
输出证据和下一步
```

## 默认必读文档

完整冷启动清单只维护在 `docs/README.md`，不要在 `AGENTS.md` 和 agent 文档里复制第二份清单。

处理任何任务前，按 `docs/README.md` 的“冷启动阅读顺序”执行，并从 `agents/` 选择一个主角色。

## 路径输出格式

可跳转固定写法：

```text
[绝对路径:行号](/绝对路径#L行号)
```

路径必须是绝对路径，使用 `/`，不加引号。
