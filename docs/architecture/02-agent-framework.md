# Agent Framework

## 定位

`Superpowers` 是通用开发流程框架。`E:\admin_go\agents` 是本项目自己的 agent 分工规则。

当前治理关系分四层：

```text
Superpowers       = 怎么理解需求、写 spec/plan、执行 TDD
agents/           = 谁负责什么、不能做什么、必须产出什么
Codex hooks       = 对话内提醒、上下文注入、低误伤阻断
Git pre-push hook = push 前轻量治理检查
```

`docs/superpowers` 仍是 spec/plan 的存放入口，不是单独的治理执行层。

`Codex hooks` 不替代 `scripts/check-agent-governance.ps1`、smoke 或 runtime 证据。它只帮助 Codex 在对话过程中少忘规则。

## Agent 列表

```text
architect.md        # 架构调研、开源对标、阶段边界
api-contract.md     # REST/OpenAPI/current API contract；historical action mapping 只作考古
backend-worker.md   # Go 后端实现
frontend-adapter.md # 前端适配 Go API
reviewer.md         # 越界、质量、验证审查
```

## 通用工作流

冷启动阅读顺序只维护在 `docs/README.md`。本文件不复制第二份清单。

```text
1. Follow docs/README.md cold-start order
2. Pick exactly one agent role
3. Read that role file
4. Work only within allowed scope
5. Produce evidence, file list, verification result
```

## 禁止全能 agent

坏味道：

```text
一个 agent 同时定架构、写后端、改前端、补测试、改文档
```

正确做法：

```text
Architect 先定来源和边界
API Contract 固定接口
Backend Worker 按契约实现
Frontend Adapter 按契约适配
Reviewer 查越界和证据
```

## Documentation governance

文档真相源、状态口径、同步矩阵和归档规则统一放在：

```text
docs/architecture/07-documentation-governance.md
```

agent 不准靠旧计划或聊天记录覆盖当前运行时事实；文档冲突时先按 governance 的真相源顺序判断。

## Pre-push gate rules

轻量 pre-push gate 的默认规则、strict gate、skip 规则和输出格式统一放在：

```text
docs/testing/pre-push-gates.md
```

pre-push 不是 full smoke，也不要求 DB/Redis/backend/frontend 默认在线。

## Codex lifecycle hooks

Codex hooks 的项目级说明在：

```text
docs/architecture/08-codex-hooks.md
```


计划配置入口：

```text
.codex/hooks.json
.codex/config.toml
```

计划脚本位置：

```text
.codex/hooks/*.ps1
```

项目 hooks 只做对话内治理：冷启动提示、Superpowers/TDD 提醒、危险命令低误伤阻断、完成前验证提醒。不要让 hooks 自动改业务代码、自动修文档或假装覆盖所有工具路径。

## 默认实现质量规则

agent 接手任何模块时，不能只看“能不能跑”。默认实现质量规则统一在：

```text
docs/architecture/05-development-quality-rules.md
```

当前必须记住三条：

```text
Full-stack i18n 默认做：后端 apperror.*Key / response.OKWithMessageKey / 双语 catalog；前端 vue-i18n / zh-CN.ts / en-US.ts。
Frontend CRUD 默认用项目公共组件：Search + AppTable + AppDialog + useCrudTable；只读列表用 Search + AppTable + useTable。
Frontend layout 默认待在 Layout page-card/body-card 内：不要重复套大卡片；表格页必须维护 flex 高度链，不能撑破 shell。
```

这三条属于 agent 冷启动规则，不是具体模块的临时偏好。发现旧代码不符合，可以分批修；新写和 touched code 不准继续扩大坏味道。

## 输出格式

每个 agent 完成任务时输出：

```text
Outcome
Changed files
Key evidence
Verification
Next step
```

## 当前执行规则

当前项目已经不是 Phase 0 空仓。agent 框架仍然生效，但不能再用早期空仓口径阻止正常开发。

接手任务时先看：

```text
docs/status/current-status.md
docs/contracts/admin-api-v1.md
docs/contracts/admin-realtime-v1.md
admin_back_go/docs/architecture.md
```

允许：

```text
按契约继续 Go/Vue 窄切片演进
修复与运行时不一致的文档
补测试、smoke、contract gate
维护 agent 冷启动规则
```

不允许：

```text
绕过 current-status 直接猜进度
绕过 API contract 让前后端互猜字段
把历史 action 路由风格搬进 Go 新接口
一次改一堆业务模块
安装未调研、未记录取舍、未验证的依赖
```


## Superpowers 文档归属

```text
E:\admin_go\docs\superpowers                    # 当前 spec/plan 总入口
E:\admin_go\docs\superpowers\archive            # 历史 spec/plan 归档
E:\admin_go\admin_back_go\docs                   # 只放 Go 后端运行时文档
```

`admin_back_go/docs/superpowers` 不再作为有效入口。看到历史后端 bootstrap 计划时，先去总控 `docs/superpowers/archive/backend-bootstrap`。
