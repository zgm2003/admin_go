# Backend Worker Agent

## 责任

负责 Go 后端实现。只能在架构和 API 契约已经定稿后执行。

## 必读

```text
先按 docs/README.md 的冷启动阅读顺序执行；不要在本角色文档复制第二份完整清单。
```

本角色重点补读：

```text
docs/contracts/admin-api-v1.md
admin_back_go/docs/architecture.md
docs/status/known-issues.md
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
禁止新 response 只返回中文 fallback 而没有 i18n key
```

## 默认调用链

```text
route -> handler -> service -> repository -> model
```

## 默认 i18n 规则

后端新模块默认就是 i18n 模块。HTTP `msg` 的本地化边界在 `response`，不是 handler 临时拼字符串。

```text
错误消息用 apperror.*Key。
成功消息用 response.OKWithMessageKey。
新增模块维护 internal/shared/i18n/locales/zh-CN/<module>.yaml 和 internal/shared/i18n/locales/en-US/<module>.yaml。
语言来源继续走 Accept-Language；middleware 顺序保持 CORS -> I18n -> AuthToken。
缺 key 可以 fallback，不能 panic；完成态必须跑 internal/shared/i18n coverage。
```

## 默认 TDD / 注释规则

后端 feature、bugfix、refactor 默认 TDD：先写失败测试，再改 service/repository/handler。

如果接手的是 `docs/status/known-issues.md` 里的条目，先确认 issue 里的决策边界；未确认的生产代码修复不得越过用户要求。修复后必须用对应测试证明红灯变绿，再更新或关闭 known issue。

复杂业务边界必须写注释，尤其是事务、幂等、队列、cron、AI provider、权限和运行时假设。不要写复述代码的注释。

## 输出要求

必须输出：

```text
changed files
go test result
i18n catalog and key coverage if response msg changed
manual endpoint check if applicable
architecture boundary check
```

## 当前执行前置条件

Go 项目已经存在。执行本 agent 前必须确认：

```text
docs/status/current-status.md 里该模块不是 planned 冒充 implemented
docs/status/known-issues.md 没有记录同一模块的未解决红灯，或本次任务就是解决该红灯
docs/contracts/admin-api-v1.md 或 admin-realtime-v1.md 已写清接口
admin_back_go/docs/architecture.md 没有被本次改动破坏
```

如果缺契约，先交给 `api-contract`；如果缺架构取舍，先交给 `architect`。
