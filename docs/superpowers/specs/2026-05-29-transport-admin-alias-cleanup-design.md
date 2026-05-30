# Transport Admin Alias Cleanup Design

状态：implemented in backend; reviewer focused gates passed on 2026-05-30
日期：2026-05-29
负责人：Codex（Architect Agent）
关联上游 spec：`docs/superpowers/specs/2026-05-27-multi-platform-backend-boundary-design.md`

实现证据：`admin_back_go` 提交 `2c6d428 refactor: remove transport admin aliases` 已删除 `transport/**/aliases.go` 并新增 architecture guard。2026-05-30 reviewer 复核的 focused gates：

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/server -run TestAdminRouteSnapshot -count=1
go test ./internal/bootstrap -run 'Test(Permission|Operation)RouteRulesUseExplicitRESTPatterns' -count=1
go test ./internal/architecture -run TestTransportDoesNotReExportModuleTypes -count=1
```

## 0. Linus 三问

```text
1. 这是个真问题吗？
   是。transport/admin 现在用 aliases.go 重新导出根 module 的 service、repository、model、DTO，边界被马甲隐藏了。

2. 有更简单的方法吗？
   有。transport/admin 直接显式 import 根 module，只在 handler/route 内使用根 module 类型；transport 包不要重新 export 根 module 类型。

3. 会破坏什么吗？
   不应破坏任何 URL、DB table、permission code、i18n key、queue task type、response payload。清理必须是编译期边界收口，不是行为改造。
```

## 1. 背景

`2026-05-27-multi-platform-backend-boundary-design.md` 已经把后端边界拍成：

```text
internal/module/{capability}/transport/{platform}/
internal/shared/
internal/infra/
```

该 spec 对 `transport/{platform}` 的定义是 HTTP 表面：

```text
route + handler + request binding + presenter
```

并且规定：

```text
transport.handler 不调 repository，只调 service
每个 transport 包导出 Register(r *gin.Engine, deps)
```

它没有设计 `aliases.go`，也没有允许 transport 包把根 module 的 repository/model/service 类型重新导出。

## 2. 当前问题快照

当前 `admin_back_go/internal/module/**/transport/admin` 下存在批量根 module alias：

```text
internal/module/ai/agent/transport/admin/aliases.go
internal/module/ai/chat/transport/admin/aliases.go
internal/module/ai/conversation/transport/admin/aliases.go
internal/module/ai/image/transport/admin/aliases.go
internal/module/ai/knowledge/transport/admin/aliases.go
internal/module/ai/message/transport/admin/aliases.go
internal/module/ai/provider/transport/admin/aliases.go
internal/module/ai/run/transport/admin/aliases.go
internal/module/ai/tool/transport/admin/aliases.go
internal/module/auth_platform/transport/admin/aliases.go
internal/module/clientversion/transport/admin/aliases.go
internal/module/crontask/transport/admin/aliases.go
internal/module/export/transport/admin/aliases.go
internal/module/mail/transport/admin/aliases.go
internal/module/operationlog/transport/admin/aliases.go
internal/module/payment/transport/admin/aliases.go
internal/module/queuemonitor/transport/admin/aliases.go
internal/module/realtime/transport/admin/aliases.go
internal/module/system/transport/admin/aliases.go
internal/module/systemlog/transport/admin/aliases.go
internal/module/systemsetting/transport/admin/aliases.go
```

另外还有多处同类直接 type alias，虽然文件不叫 aliases.go，性质一样：

```text
internal/module/notification/transport/admin/handler.go
internal/module/notification/transport/admin/task_handler.go
internal/module/sms/transport/admin/handler.go
internal/module/uploadconfig/transport/admin/handler.go
internal/module/uploadtoken/transport/admin/handler.go
```

以及一处常量转发：

```text
internal/module/mail/transport/admin/handler.go
  DefaultEndpoint = mailmodule.DefaultEndpoint
  DefaultRegion   = mailmodule.DefaultRegion
```

这些 alias 的坏味道分三类：

| 类别 | 例子 | 问题 |
| --- | --- | --- |
| HTTP service alias | `HTTPService = xxxmodule.HTTPService` | server/bootstrap 以为依赖 transport，实际依赖根 module service contract |
| repository/model alias | `Repository/GormRepository/Model = xxxmodule.*` | HTTP 表面开始“拥有”数据层类型，边界错位 |
| DTO/input alias | `CreateInput/ListQuery/Page = xxxmodule.*` | handler 内部偷懒可以接受为实现细节，但不该 export 成 transport API |

## 3. 目标状态

完成后必须满足：

```text
1. transport/admin 下不再存在 aliases.go。
2. transport/admin 下不再出现 `type X = xxxmodule.Y` 或 type block 内 `X = xxxmodule.Y` 这种根 module 类型转发，不管它写在 aliases.go 还是 handler.go。
3. transport/admin 包对外只暴露 HTTP 表面所需符号，核心是 Register / Handler / NewHandler，以及确实属于 HTTP 层的常量。
4. server.Dependencies 里因为 alias deletion 失效的字段改为根 module 包类型；已有的 transport 本地窄接口不在本轮强行外移。
5. handler/route 如需根 module 类型，显式 import 根 module 并使用 package 前缀，例如 aiagentmodule.HTTPService。
6. 不改变现有 admin route、payload、权限、i18n、DB、queue、runtime 行为。
```

## 4. 非目标

本轮不做：

```text
- 不重命名 route function（例如 RegisterRoutes -> Register）除非某个 alias 删除无法编译；这个是另一个边界清理切片。
- 不移动 service/repository/model 文件。
- 不重构 response payload。
- 不补新业务能力。
- 不触碰前端。
- 不清理历史 archive/spec 文本里的 alias 字样。
```

## 5. 设计方案比较

### 方案 A：保留 aliases.go，只加注释说明过渡

拒绝。注释不能修边界。坏代码加注释还是坏代码。

### 方案 B：一次性全仓删除 alias，边改边修编译

不推荐直接手干。改动面有 20+ 个 transport 包，容易把独立模块混成一个大冲突。

### 方案 C：先加架构 guard，再按独立模块 lane 并发删除

采用。先写一个会失败的架构测试，把目标状态钉死；再拆成互不共享文件的 lane 并发清理；最后由一个整合任务跑全量验证。

理由：

```text
- 每个 module 的 alias 删除大多只动本 module 的 transport/admin 文件。
- server.Dependencies 是共享冲突点，必须先单独处理或最后由整合人处理。
- architecture guard 可以防止后续又把 aliases.go 加回来。
```

## 6. 并发切分原则

并发必须避开共享文件冲突：

```text
串行 Task 1：新增 architecture guard，允许它先失败。
串行 Task 2：清理 internal/server/router.go 中依赖 transport/admin.HTTPService 的共享类型引用。
并发 Task 3A-3E：按 capability lane 删除各自 aliases.go，不改 server/router.go。
串行 Task 4：整合、跑完整测试、修漏网 alias。
```

推荐 lane：

| Lane | 范围 | 说明 |
| --- | --- | --- |
| AI core | `ai/provider`、`ai/agent`、`ai/tool` | AI 管理核心，类型多但彼此文件独立 |
| AI runtime | `ai/conversation`、`ai/message`、`ai/chat`、`ai/run` | 对话/运行态链路，必须保持 queue/runtime contract |
| AI assets | `ai/image`、`ai/knowledge` | 文件较大，单独 lane 降低冲突 |
| Foundation | `clientversion`、`crontask`、`export`、`operationlog`、`queuemonitor`、`realtime`、`system`、`systemlog`、`systemsetting` | 后台基础能力，不触碰业务支付/AI |
| Business misc | `auth_platform`、`mail`、`payment` | 业务配置/支付/邮件，关注证书和 provider 常量不变 |

## 7. 代码模式

### 7.1 删除前的坏模式

```go
package admin

import aiagentmodule "admin_back_go/internal/module/ai/agent"

type (
    HTTPService    = aiagentmodule.HTTPService
    CreateInput    = aiagentmodule.CreateInput
    Repository     = aiagentmodule.Repository
    GormRepository = aiagentmodule.GormRepository
)
```

### 7.2 删除后的目标模式

```go
package admin

import aiagentmodule "admin_back_go/internal/module/ai/agent"

func Register(router *gin.Engine, service aiagentmodule.HTTPService) {
    handler := NewHandler(service)
    // route setup stays unchanged
}

type Handler struct {
    service aiagentmodule.HTTPService
}

func createInput(req mutationRequest) aiagentmodule.CreateInput {
    return aiagentmodule.CreateInput{
        // field mapping stays unchanged
    }
}
```

如果 handler 只需要 service contract，也可以定义更窄的本地未导出接口：

```go
type httpService interface {
    List(ctx context.Context, query module.ListQuery) (*module.ListResponse, *apperror.Error)
}
```

但本轮默认不新造本地接口。原因：多数根 module 已经有 `HTTPService`，直接显式引用更小、更机械、风险更低。

## 8. 架构 guard

新增或扩展 architecture test，至少检查：

```text
1. internal/module/**/transport/**/aliases.go 不存在。
2. internal/module/**/transport/**/*.go 不包含单行 `type X = yyyymodule.Z`，也不包含 type block 内 `X = yyyymodule.Z`。
3. 编译能证明 server.Dependencies 不再依赖被删除的 transport alias；不粗暴禁止已有 transport 本地窄接口。
```

第三条不能粗暴禁止 server import transport/admin，也不能粗暴禁止所有 `xxxadmin.HTTPService`：当前仍有若干 transport 本地窄接口。要清的是 `aliases.go` 和 `type X = xxxmodule.Y` 这类根 module 转发。

## 9. 验收标准

必须全部满足：

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture -count=1
go test ./internal/server -run TestAdminRouteSnapshot -count=1
go test ./... -count=1
go build ./...

cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

补充静态扫描：

```powershell
cd E:\admin_go\admin_back_go
Get-ChildItem -Path .\internal\module -Recurse -Filter aliases.go
rg -n "^\s*[A-Z][A-Za-z0-9_]*\s*=\s*[a-zA-Z0-9_]+module\." .\internal\module --glob "**/transport/**/*.go"
```

期望：前两个扫描返回空；server/router.go 由 `go test ./...` 和 `go build ./...` 证明不依赖已删除 alias。

## 10. 风险与回滚

| 风险 | 处理 |
| --- | --- |
| 并发任务同时改 `internal/server/router.go` | 禁止 lane 任务改 router；router 只在 Task 2 / Task 4 处理 |
| handler 编译缺类型 | 显式 import 根 module，给类型加 package 前缀 |
| route snapshot 变化 | 立刻回滚对应 lane；alias 清理不应该改变路由 |
| architecture guard 写太宽误伤常量 | 只禁 `aliases.go` 和根 module type alias，不禁 transport 正常 import |
| 全量测试慢 | lane 内先跑 focused tests，最终整合再跑全量 |

## 11. 自检

```text
Placeholder scan：无 TBD/TODO。
内部一致性：目标只清 alias，不扩大到 RegisterRoutes 命名统一。
范围检查：单一边界 hardening，可拆成并发 lane。
歧义检查：允许 transport import 根 module；禁止重新导出根 module 类型。
```
