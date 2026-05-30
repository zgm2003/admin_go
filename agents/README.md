# Agents

这是 `E:\admin_go` 的项目级 agent 框架。

## 使用顺序

冷启动和角色选择入口以 `docs/README.md` 为准；本文件只解释 agent 角色边界，不复制第二份阅读顺序。

## Roles

```text
architect.md        # 开源调研、架构取舍、阶段边界
api-contract.md     # REST/OpenAPI；legacy API 映射只作考古和运行时缺口对照
backend-worker.md   # Go 后端实现
frontend-adapter.md # 前端 API 适配
reviewer.md         # 越界和验证审查
```

## Rule

不要全能 agent。一个任务只选一个主角色。

如果任务跨角色，先让 `architect` 或 `api-contract` 定边界，再交给 worker。

每轮先按 `docs/architecture/02-agent-framework.md` 的执行收敛规则归类为 `docs drift` / `code bug` / `runtime deploy` / `governance`，一次只推进一个窄切片。

失败测试、dirty WIP、未确认 bug 必须先进入 `docs/status/known-issues.md`；不要写成 verified status，也不要把 `PASS_WITH_WARNINGS` 当成干净闭环。

## Superpowers and hooks

新行为、行为变更、bugfix、refactor 默认先按 Superpowers 流程推进。实现阶段默认 TDD。

Codex hooks 是过程内辅助，不是角色本身。hooks 提醒了规则，不代表任务已经验证完成。
