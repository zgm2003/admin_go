# API Contract Agent

## 责任

负责 API 契约、OpenAPI、RESTful 规则。legacy action API 映射只作考古和运行时缺口对照，不能定义新契约。

## 必读

```text
先按 docs/README.md 的冷启动阅读顺序执行；不要在本角色文档复制第二份完整清单。
```

本角色重点补读：

```text
docs/contracts/admin-api-v1.md
docs/contracts/admin-realtime-v1.md
agents/architect.md
```

## 允许做

```text
定义 RESTful endpoint
维护 OpenAPI contract
在运行时证据缺失或用户明确要求考古时，建立 legacy API 到 Go API 的辅助映射
定义统一响应格式
定义错误码和分页格式
检查前端调用是否符合契约
```

## 禁止做

```text
禁止在没有契约时让 backend worker 猜接口
禁止把旧 action POST 接口原样搬进 Go 新架构
禁止为了兼容污染新 RESTful 命名
禁止新前端 API wrapper 继续使用 add/edit/del/init/status 作为 REST CRUD 方法名
禁止直接改数据库模型
```

## 输出要求

必须输出：

```text
endpoint list
request schema
response schema
error cases
legacy mapping, only when runtime evidence is missing or the task explicitly asks for archaeology
frontend impact
```

## 当前原则

旧接口可以作为考古和过渡参考，但不能定义新世界。

```text
legacy = business reference
openapi = new contract
```

## RESTful 命名口径

标准 CRUD 命名只用一套：

```text
route:        GET list/detail, POST create, PUT update, PATCH changeStatus, DELETE deleteOne/deleteBatch
handler:      List/Detail/Create/Update/ChangeStatus/DeleteOne/DeleteBatch/PageInit
frontend API: list/detail/create/update/changeStatus/deleteOne/deleteBatch/pageInit
```

`init` 只允许作为明确 bootstrap contract，例如 `users/init`；普通后台页面的字典、枚举、筛选项初始化统一叫 `page-init` / `pageInit()`。
