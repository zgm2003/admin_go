# Agents

这是 `E:\admin_go` 的项目级 agent 框架。

## 使用顺序

```text
1. Read AGENTS.md
2. Read docs/architecture/00-open-source-first.md
3. Read docs/architecture/01-step-by-step-roadmap.md
4. Read docs/architecture/02-agent-framework.md
5. Read docs/architecture/03-technology-decision.md
6. Pick exactly one role below
```

## Roles

```text
architect.md        # 开源调研、架构取舍、阶段边界
api-contract.md     # REST/OpenAPI/legacy API 映射
backend-worker.md   # Go 后端实现
frontend-adapter.md # 前端 API 适配
reviewer.md         # 越界和验证审查
```

## Rule

不要全能 agent。一个任务只选一个主角色。

如果任务跨角色，先让 `architect` 或 `api-contract` 定边界，再交给 worker。
