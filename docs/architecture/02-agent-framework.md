# Agent Framework

## 定位

`Superpowers` 是通用开发流程框架。`E:\admin_go\agents` 是本项目自己的 agent 分工规则。

两者关系：

```text
Superpowers = 怎么推进任务
agents/     = 谁负责什么、不能做什么、必须产出什么
docs/superpowers = spec/plan 总入口，包含当前计划和历史归档
```

## Agent 列表

```text
architect.md        # 架构调研、开源对标、阶段边界
api-contract.md     # REST/OpenAPI/current API contract；historical action mapping 只作考古
backend-worker.md   # Go 后端实现
frontend-adapter.md # 前端适配 Go API
reviewer.md         # 越界、质量、验证审查
```

## 通用工作流

```text
1. Read AGENTS.md
2. Read relevant docs/architecture/*.md
3. Pick exactly one agent role
4. Read that role file
5. Work only within allowed scope
6. Produce evidence, file list, verification result
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
