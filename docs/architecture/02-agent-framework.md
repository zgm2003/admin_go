# Agent Framework

## 定位

`Superpowers` 是通用开发流程框架。`E:\admin_go\agents` 是本项目自己的 agent 分工规则。

两者关系：

```text
Superpowers = 怎么推进任务
agents/     = 谁负责什么、不能做什么、必须产出什么
```

## Agent 列表

```text
architect.md        # 架构调研、开源对标、阶段边界
api-contract.md     # REST/OpenAPI/legacy API 映射
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

## 输出格式

每个 agent 完成任务时输出：

```text
Outcome
Changed files
Key evidence
Verification
Next step
```

## 当前阶段限制

当前只允许 Phase 0：agent 框架和规则落地。

不允许：

```text
初始化 Go module
选择最终 RBAC 表结构
改 admin_front_ts 业务代码
迁移 PHP 业务
安装一堆未验证依赖
```
