# Step By Step Roadmap

状态更新时间：2026-05-04

## 目标

从低到高搭建 `E:\admin_go`，每阶段只解决一个真实问题。

## 当前状态

这份 roadmap 是历史推进顺序，不是说项目还停在 Phase 0。

当前真实进度看：

```text
docs/migration/current-status.md
docs/contracts/admin-api-v1.md
docs/contracts/admin-realtime-v1.md
admin_back_go/docs/architecture.md
```

规则：

```text
implemented / partially implemented / planned 以 current-status 为准。
后续进入 Phase 6 时，一个 legacy PHP 业务模块一个模块迁，不允许大撒网。
```

## Phase 0: Agent Framework

产物：

```text
AGENTS.md
agents/*.md
docs/architecture/00-open-source-first.md
docs/architecture/01-step-by-step-roadmap.md
docs/architecture/02-agent-framework.md
```

成功标准：

```text
AI 进入项目后知道谁负责什么
AI 知道不能闭门造车
AI 知道要先读 current-status，再决定当前能做什么
```

## Phase 1: Open-source Research

Main backend language is Go. Phase 1 does not re-litigate Java vs Go vs Python; it researches Go admin architecture, RBAC, frontend permission models, and AI integration boundaries.

产物：

```text
docs/open-source/01-go-admin-candidates.md
docs/open-source/02-rbac-models.md
docs/open-source/03-frontend-admin-patterns.md
docs/open-source/04-final-architecture-decision.md
```

成功标准：

```text
每个候选项目都有来源、优点、缺点、可借鉴点、不采用点
RBAC 和前端权限模型有明确取舍
能说清楚为什么选某个骨架，而不是自己拍脑袋
```

## Phase 2: Minimal Go Skeleton

只允许搭最小后端骨架：

```text
cmd/admin-api/main.go
internal/bootstrap/
internal/config/
internal/server/
internal/middleware/
```

成功标准：

```text
go test ./... 通过
health endpoint 可访问
配置、日志、错误响应格式固定
```

## Phase 3: Database Baseline

只做数据库连接、迁移约束、基础模型规范。

成功标准：

```text
能连接 MySQL
迁移方式明确
表字段约束明确
不写业务模块
```

## Phase 4: Auth + RBAC Core

只做后台最核心权限闭环：

```text
login
me
menus
users
roles
permissions
operation logs
```

成功标准：

```text
登录后能拿菜单
API 权限能拦截
按钮权限能返回给前端
审计日志能记录关键操作
```

## Phase 5: Frontend Adaptation

只适配当前前端和 Go API 契约，不重做 UI。

成功标准：

```text
前端登录、菜单、权限、用户管理能走 Go API
旧 PHP API 不被新适配层污染
```

## Phase 6: Legacy Migration

按模块迁移 PHP 业务。每个模块必须先有 legacy map 和 OpenAPI contract。

成功标准：

```text
一个模块迁一个模块
迁完有测试和前端验证
不破坏既有用户路径
```

## 铁律

```text
一个阶段没验收，不进入下一阶段。
一个阶段只解决一个核心问题。
任何跨阶段改动都要写明原因。
已经验收过的阶段不靠记忆复述，必须用 current-status、contract、smoke 证据确认。
```
