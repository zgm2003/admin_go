# Agent Default Implementation Quality Rules Plan

> **For agentic workers:** use `superpowers:executing-plans` or an equivalent task-by-task workflow. This plan is docs-only and must not touch backend/frontend runtime code.

**Goal:** 把用户认可的三条默认规则固化进 agent 冷启动、agent 框架和角色文档：前后端 i18n 默认做；前端 CRUD 默认使用公共组件；前端页面默认不撑破 Layout page-card/body-card。

**Spec source:**

```text
docs/superpowers/specs/2026-05-16-agent-default-implementation-quality-rules-design.md
```

## Scope lock

只做：

```text
AGENTS.md 冷启动硬规则
docs/architecture/02-agent-framework.md 默认实现质量规则
docs/architecture/05-development-quality-rules.md 详细规则和验收门槛
agents/frontend-adapter.md 前端执行规则
agents/backend-worker.md 后端 i18n 执行规则
agents/reviewer.md reviewer 审查项
本 spec / plan 记录
```

不做：

```text
admin_back_go/** runtime 改动
admin_front_ts/** runtime 改动
数据库迁移
API contract 改动
菜单 / RBAC 改动
full smoke 默认化
自动修复脚本
```

## Task 1: 固化详细质量规则

Files:

```text
docs/architecture/05-development-quality-rules.md
```

Steps:

- [x] 新增 `Full-stack i18n 默认规则`。
- [x] 新增 `Frontend CRUD 公共组件规则`。
- [x] 新增 `Frontend page-card / body-card 布局规则`。
- [x] 在验收门槛加入 i18n、CRUD primitives、page-card/body-card 三条硬要求。

## Task 2: 让冷启动直接看到规则

Files:

```text
AGENTS.md
docs/architecture/02-agent-framework.md
```

Steps:

- [x] 在 `AGENTS.md` 增加 `默认实现硬规则`。
- [x] 在 `02-agent-framework.md` 增加 `默认实现质量规则`。
- [x] 明确 `05-development-quality-rules.md` 是细则真相源。

## Task 3: 更新角色文档

Files:

```text
agents/frontend-adapter.md
agents/backend-worker.md
agents/reviewer.md
```

Steps:

- [x] 前端 agent 读取 `05-development-quality-rules.md`、`current-status`、API contract。
- [x] 前端 agent 默认使用 `useI18n`、`Search/AppTable/AppDialog/useCrudTable/useTable`、page-card 高度链。
- [x] 后端 agent 读取 `05-development-quality-rules.md`、`current-status`、API contract、后端架构文档。
- [x] 后端 agent 默认使用 `apperror.*Key`、`response.OKWithMessageKey`、双语 catalog。
- [x] reviewer 把漏 i18n、绕过公共 CRUD 组件、page-card/body-card 溢出纳入审查重点。

## Task 4: 验证

Run from root worktree:

```powershell
git diff --check -- . ':(exclude)**/node_modules/**'
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode range -Base master -Strict
```

Expected:

```text
all commands exit 0
```

Optional if hook runner is available:

```powershell
git hook run pre-push
```

If `git hook run` is unavailable on the local Git version, direct `check-agent-governance.ps1 -Mode range` is the evidence source.

## Commit

After verification:

```powershell
git add AGENTS.md docs/architecture/02-agent-framework.md docs/architecture/05-development-quality-rules.md agents/frontend-adapter.md agents/backend-worker.md agents/reviewer.md docs/superpowers/specs/2026-05-16-agent-default-implementation-quality-rules-design.md docs/superpowers/plans/2026-05-16-agent-default-implementation-quality-rules.md
git commit -m "docs: add default module quality rules for agents"
```

Do not push unless explicitly requested.
