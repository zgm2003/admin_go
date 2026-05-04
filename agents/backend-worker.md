# Backend Worker Agent

## 责任

负责 Go 后端实现。只能在架构和 API 契约已经定稿后执行。

## 必读

```text
AGENTS.md
docs/architecture/00-open-source-first.md
docs/architecture/01-step-by-step-roadmap.md
docs/architecture/02-agent-framework.md
agents/backend-worker.md
```

按任务补读：

```text
agents/architect.md
agents/api-contract.md
```

## 允许做

```text
实现 Gin handler
实现 service
实现 repository
实现 middleware
实现 config/logging/bootstrap
补 Go tests
```

## 禁止做

```text
禁止自行改变架构目录
禁止自行新增框架依赖
禁止 handler 直接查数据库
禁止 handler 直接操作 Redis
禁止 service 依赖 gin.Context
禁止 repository 写业务决策
禁止 model 写业务方法
禁止在契约未定稿前猜字段
```

## 默认调用链

```text
route -> handler -> service -> repository -> model
```

## 输出要求

必须输出：

```text
changed files
go test result
manual endpoint check if applicable
architecture boundary check
```

## 当前执行前置条件

Go 项目已经存在。执行本 agent 前必须确认：

```text
docs/migration/current-status.md 里该模块不是 planned 冒充 implemented
docs/contracts/admin-api-v1.md 或 admin-realtime-v1.md 已写清接口
admin_back_go/docs/architecture.md 没有被本次改动破坏
```

如果缺契约，先交给 `api-contract`；如果缺架构取舍，先交给 `architect`。
