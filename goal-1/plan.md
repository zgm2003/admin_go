# Goal Plan: Multi-platform Governance Docs

## 原始目标

`e:\admin_go\docs\superpowers\plans\2026-05-27-multi-platform-01-governance-docs.md 本次改动涉及到了架构重构，一定要好！ $superpowers $golang-pro`

## 当前上下文

- 工作区：`E:\admin_go` root governance repo。
- 运行时子仓：`admin_back_go`（Go 后端），`admin_front_ts`（Vue 前端）。
- 本 goal 执行 referenced plan：`docs/superpowers/plans/2026-05-27-multi-platform-01-governance-docs.md`。
- 选定项目 agent 角色：`architect`。本轮是架构治理文档更新，不直接写 Go 业务代码、不改前端页面、不建表。
- 已读冷启动文档：`AGENTS.md`、`docs/status/current-status.md`、`docs/architecture/00-open-source-first.md`、`01-step-by-step-roadmap.md`、`02-agent-framework.md`、`03-technology-decision.md`、`04-go-backend-framework.md`、`05-development-quality-rules.md`、`07-documentation-governance.md`、`08-codex-hooks.md`、`docs/testing/pre-push-gates.md`、`agents/architect.md`。
- 当前 root worktree 在 goal 初始化前已有 plan 文件相关脏状态：删除 `docs/superpowers/plans/2026-05-27-multi-platform-backend-boundary-redesign.md`，新增 `2026-05-27-multi-platform-01..04-*.md`。后续任务不得覆盖这些既有变更，提交/回滚时必须只处理本 goal 相关文件。

## 需求分析

本 goal 是 docs-only 架构治理切片，目标是把多平台后端边界从旧口径 `api/domain/shared/platform` 调整为新口径：

```text
module/{capability}/transport/{platform} + shared + infra
```

核心要求：

1. 创建并固化 R1-R8 多平台架构硬规则。
2. 统一 root `AGENTS.md` 的 platform/module/transport/shared/infra/adapter 词汇。
3. 改写 `docs/architecture/04-go-backend-framework.md` 的长期目标分层，去掉 DDD 风格四层目标。
4. 改写 `docs/architecture/05-development-quality-rules.md` 的多平台差异落位表。
5. 在 `docs/status/current-status.md` 诚实记录 2026-05-27 架构 pivot，不声明代码迁移已完成。
6. 清理 `admin_back_go/docs/architecture.md` 里的 legacy/compat/fallback 架构性叙事。
7. 执行 cross-doc consistency、`git diff --check` 和 `scripts/check-agent-governance.ps1 -Mode working`。
8. 本 plan 不触碰任何 `.go` 文件，不声称 auth transport/module consolidation/frontend cleanup 已完成。

## Linus 三问

1. 这是真问题吗？是真问题。当前 governance docs 与 referenced spec/plan 的新多平台边界存在冲突：旧 `api/domain/shared/platform` 口径会继续误导后续架构重构。
2. 有更简单做法吗？有：docs-only 先收敛词汇和硬规则，不先改 Go 代码；后续 plan-02/03/04 再做迁移。
3. 会破坏已有前端、接口、登录和权限吗？本 goal 不改运行时代码，风险主要是文档误导。必须避免把 planned 写成 implemented。

## 执行方案

- 每个新会话开始必须先全量读取：
  - `goal-1/input.md`
  - `goal-1/plan.md`
  - `goal-1/tasks.md`
- 每轮先用 `update_plan` 注册小 todo。
- 每轮只执行 `tasks.md` 中第一个未完成 task。
- 每个 task 完成前必须基于实际证据做自检，不能口头声称“有信心”。
- 每个 task 完成后更新 `tasks.md`：状态、改动、验证结果、剩余风险、下一步。
- 若该 task 修改了文件，按项目规则尽量提交本 task 变更；如存在外部脏状态，提交前必须确认只 stage 本 task 文件，避免把无关脏文件带入。
- 每三个 task 后执行一次大型全面检查-debug循环，并把结果写入 `tasks.md`。
- 全部 task 完成后执行最终最大 review，覆盖 C 端影响、架构一致性、docs truth、权限/安全、测试/构建适配、回滚方案。

## 验证方式

按 referenced plan 与 governance hook 要求执行：

```powershell
cd E:\admin_go
Test-Path .\docs\architecture\00-platform-and-module-rules.md
rg -n "R1\.|R2\.|R3\.|R8\.|infra vs adapter" docs\architecture\00-platform-and-module-rules.md
rg -n "infra 运行时技术资源|adapter infra 内多供应商" AGENTS.md
rg -n "api -> domain|internal/api/\{admin|internal/domain/" docs\architecture\04-go-backend-framework.md
rg -n "transport/\{platform\}|internal/infra|00-platform-and-module-rules" docs\architecture\04-go-backend-framework.md
rg -n "transport/\{platform\}|外部 SDK/技术资源差异" docs\architecture\05-development-quality-rules.md
rg -n "2026-05-27 架构方向更新|36 个 module 将聚合至约 19 个" docs\status\current-status.md
rg -n "legacy adapter|compat adapter|fallback bridge" admin_back_go\docs\architecture.md
rg -n "internal/adapter/" AGENTS.md docs admin_back_go\docs
rg -n "api/domain/shared/platform" AGENTS.md docs admin_back_go\docs
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Docs-only change 不要求 backend/frontend runtime smoke；但如果最终审查发现 `.go` 或 frontend runtime 文件被误改，必须停止并回滚或补对应 runtime 验证。

## 风险与控制

- 风险：把未来计划写成 runtime fact。控制：`current-status.md` 只写“架构方向更新”，明确“不代表代码已完成”。
- 风险：术语替换过度，破坏历史说明或 source provenance。控制：只改 active governance docs；历史 archive 不作为本 goal 目标。
- 风险：cross-doc scan 因 spec/plan 或 archive 中保留旧词而失败。控制：先按 referenced plan scope 判断是否 active docs；若是历史引用，需决定删改或记录例外，不能直接忽略。
- 风险：误触 Go/runtime 文件。控制：每轮 `git status --short` 和 scoped diff；本 goal 不触碰 `.go`。
- 风险：existing dirty plan files 被误提交/回滚。控制：只 stage task 涉及文件；不自动恢复既有脏状态。
- 风险：hook/governance 文件改动触发额外要求。控制：本 goal 不计划改 `.codex/hooks*`；若实际改变，最终必须提醒用户用 `/hooks` review/trust。

## 回滚方案

- 单 task 回滚：用 `git diff -- <file>` 查本 task 文件，手动反向编辑或 `git restore -- <file>`；不得恢复 unrelated pre-existing plan deltas。
- 新增文件回滚：删除 `docs/architecture/00-platform-and-module-rules.md`，并恢复引用该文件的 active docs。
- 多文件回滚：优先用本 task commit 反向提交；若未提交，则按 `tasks.md` 记录逐文件恢复。
- Goal 文件本身是执行日志，不作为业务代码回滚目标；除非用户明确要求，不删除 `goal-1/`。

## 默认假设

- `docs/superpowers/specs/2026-05-27-multi-platform-backend-boundary-design.md` 是 R1-R8 的 source spec；如果某段与 current runtime 冲突，runtime fact 仍以 current-status/served behavior 为准，架构规则只声明 future governance。
- 本 goal 对应 referenced `plan-01`，不执行 plan-02/03/04。
- `admin_back_go/docs/architecture.md` 是允许修改的 subrepo backend runtime architecture doc。
- 本地网络和 Docker/DB/Redis 状态不影响 docs-only goal；不为了 docs-only 启停服务。
- 由于目标要求无人值守，遇到不确定信息不向用户提问；选择最保守、可回滚、docs-only 的处理方式。
