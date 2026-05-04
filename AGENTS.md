# E:\admin_go Agent Guidance

## 核心判断

这是一个 **open-source-first admin rewrite workspace**，不是闭门造车实验场。

冷启动判断顺序固定：

```text
1. 先读当前状态，不靠聊天记录猜进度
2. 再读架构、契约、测试文档
3. 再按 agent 角色接手一个窄切片
4. 最后才改代码、跑验证、同步文档
```

历史推进顺序是：

```text
Phase 0: Agent framework and rules
Phase 1: Open-source research and architecture decision
Phase 2: Minimal Go service skeleton
Phase 3: Database and config baseline
Phase 4: Auth and RBAC core
Phase 5: Admin frontend API adaptation
Phase 6: Legacy PHP feature migration
```

## Linus 三问

每个任务开始前先问：

```text
1. 这是个真问题，还是臆想出来的？
2. 有更简单的做法吗？
3. 会破坏已有前端、接口、登录和权限吗？
```

如果答案不清楚，先停下来查证，不要写代码。

## 不可协商原则

### 0. 代码质量、架构质量、文档真实性永远优先

这是作品级重构，不是能跑就行的临时代码。

每次改动都必须同时维护：

```text
代码质量：简单、明确、可测、无隐藏兜底、无无主 goroutine
架构质量：边界清楚、职责单一、尊重既定分层、不把 Go 写成 Java 或 PHP
文档质量：API、枚举、缓存、队列、部署、验证命令和运行时事实同步更新
```

没有验证证据，不准说“完成”；文档与运行时冲突时，以运行时为准并修正文档。

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
Phase 0-5: 已经有基线实现，具体状态以 docs/migration/current-status.md 为准
Phase 6: 后续按模块迁移 legacy PHP 业务，每次只迁一个窄切片
```

禁止跨阶段偷跑。比如 RBAC 或契约没验明，就别写业务模块；Go skeleton 或 smoke 没验证，就别声称基建完成。

### 3. Legacy 只提供业务事实，不提供新架构规则

旧项目可以参考：

```text
E:\admin\admin_back       # PHP legacy backend reference
E:\admin_go\admin_front_ts # current frontend workspace
```

但旧 PHP 的路由风格、分层、命名、历史兼容，不自动成为 Go 新项目规则。

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

处理任何任务前，先读：

```text
AGENTS.md
docs/architecture/00-open-source-first.md
docs/architecture/01-step-by-step-roadmap.md
docs/architecture/02-agent-framework.md
docs/architecture/03-technology-decision.md
docs/architecture/04-go-backend-framework.md
docs/architecture/05-development-quality-rules.md
```

按角色继续读：

```text
agents/architect.md
agents/api-contract.md
agents/backend-worker.md
agents/frontend-adapter.md
agents/reviewer.md
```

## 路径输出格式

可跳转固定写法：

```text
[绝对路径:行号](/绝对路径#L行号)
```

路径必须是绝对路径，使用 `/`，不加引号。
