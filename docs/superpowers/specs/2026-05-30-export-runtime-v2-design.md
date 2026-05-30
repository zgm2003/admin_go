# 导出运行时 V2 设计

状态：2026-05-30 用户评审稿

## 目标

把现有“用户列表导出”收敛成一个可复用的 Go 导出运行时：业务模块只负责提交导出请求和构造业务数据，`internal/module/export` 负责导出任务、队列执行、`.xlsx` 生成、COS 上传、状态记录和通知。

第一阶段不是重写一套报表平台。第一阶段只把当前 `user_list` 链路补成可验证、可扩展的通用骨架，并保留当前用户管理页按钮体验。后续支付订单、钱包流水、通知、AI run 等场景按同一骨架注册新的导出定义。

## 核心定位

导出必须按“项目基础能力”设计，不是用户管理页的一个按钮补丁。以后任何列表页、流水页、订单页、审计页、AI 运行页，只要需要导出，都应该复用同一套运行时：

```text
提交入口       # 业务模块拥有：权限、筛选、字段语义
导出任务       # export runtime 拥有：状态、归属、过期、删除
队列执行       # export runtime 拥有：异步、重试、失败落库
文件生成       # export runtime 拥有：xlsx writer、文件名、行数
COS 上传       # export runtime 拥有：上传配置、object_key、file_url
通知和下载入口 # export runtime 拥有：成功/失败通知、导出任务页
```

以后新增导出场景，只允许新增“业务 provider + 提交接口 + 权限码 + 测试”，不允许复制一套导出任务表、上传逻辑、Excel writer 或下载页。复制这些基础链路就是坏味道。

## Linus 三问

1. 这是真问题吗？是。当前用户导出已有 Go 实现和 COS uploader，但默认 smoke 只读 `export-tasks`，不触发真实导出、不等待 worker、不上传 COS；未来导出场景多，如果继续每个模块各写一套，就是垃圾复制。
2. 有更简单的方法吗？有。复用已有 `export_tasks`、`export:run:v1`、`XLSXWriter`、`COSUploader`，只补一个小的 export definition registry 和提交契约，不做模板 DSL、不做万能 SQL、不做同步下载。
3. 会破坏什么吗？不能破坏 `POST /api/admin/v1/users/export`、`user_userManager_export`、`/system/exportTask?status=2|3`、已有导出任务下载、当前用户隔离、COS-only 上传契约和现有 `.xlsx` 格式。

## 当前证据

当前仓库已经有这些事实：

- `POST /api/admin/v1/users/export` 已经是 Go REST 契约，权限固定是 `user_userManager_export`。
- `GET /api/admin/v1/export-tasks/status-count`、`GET /api/admin/v1/export-tasks`、`DELETE /api/admin/v1/export-tasks` 已经按当前用户隔离。
- `internal/module/export` 已有 task model、service、repository、xlsx writer、COS uploader、notification notifier、queue handler。
- worker 已经把 `ExportTaskService` 接进 `jobs.Register`，并配置 `user.NewExportDataProvider`、`XLSXWriter`、`COSUploader`。
- smoke matrix 只做导出任务读取探针，不触发真实导出和 COS 上传。这是当前最明显的验证缺口。

## 产品取舍

未来导出范围采用“显式范围”：

```text
selected  # 导出显式勾选行
filtered  # 导出当前筛选条件下的结果
```

当前用户管理页第一阶段继续保持现有行为：必须勾选用户后导出，提交体仍兼容 `{ ids: number[] }`。这是 userspace，不动它。新导出场景默认使用显式 `scope`，不允许靠空字段猜行为。

## 范围

### 本次包含

1. 把 `internal/module/export` 定义成通用导出运行时。
2. 增加 export definition registry：按 `kind` 找到对应业务数据 provider。
3. 让业务模块提交导出时只创建任务和投递队列，不在 HTTP handler 里生成文件。
4. 保持 COS-only：导出文件由 worker 服务端上传到当前启用 COS。
5. 让导出任务表能区分 `kind`、`platform` 和 COS `object_key`。
6. 补一个 credential-gated 真实导出 smoke，证明任务能从 submit 跑到 COS 上传完成。
7. 前端抽出最小提交复用逻辑，未来多个页面不用复制“勾选校验 + 提交 + 提示”。
8. 固化新导出场景的接入模板，后续按模板接 payment、wallet、AI 等场景。

### 本次不包含

1. 不做万能报表平台。
2. 不允许前端传 SQL、表名、列名或任意字段表达式。
3. 不做同步下载。
4. 不做 OSS、S3、local fallback；当前运行时仍是 COS-only。
5. 不做导出任务跨用户后台管理。
6. 不做取消、重试、进度条和 COS 对象删除。
7. 不做 CSV/PDF；第一版只支持 `.xlsx`。

## 架构设计

### 职责拆分

```text
business transport/admin
  -> 绑定并校验业务导出请求
  -> 通过 route metadata 执行业务权限
  -> 调用业务 service SubmitExport

business service
  -> 归一化勾选 ids 或筛选条件
  -> 通过 export.Service 创建 export_tasks pending 行
  -> 投递 export:run:v1

export runtime
  -> 管理 export_tasks 生命周期
  -> 管理导出定义 registry
  -> 管理 xlsx writer
  -> 管理 COS 上传
  -> 管理成功/失败状态更新
  -> 管理通知投递请求

business export provider
  -> 管理业务查询
  -> 管理行格式化
  -> 返回稳定表头和字符串单元格
```

规则：handler 永远不生成 Excel。service 在 HTTP 请求里也不直接上传文件。昂贵工作统一交给 worker。

### 包结构

保留现有包名和目录：

```text
admin_back_go/internal/module/export/
  definition.go          # Definition、Registry、Provider 边界
  dto.go                 # task/list/submit/run DTO
  jobs.go                # export:run:v1 payload 和 handler 注册
  model.go               # export_tasks model
  repository.go          # task 持久化
  service.go             # task 生命周期和 Run 编排
  writer.go              # xlsx writer
  uploader.go            # COS 上传边界
  upload_config_repository.go
  notifier.go
  transport/admin/
```

业务模块保留自己的提交入口。例子：

```text
internal/module/user/
  export_provider.go     # user_list provider
  service.go             # SubmitExport 保持 user-owned
  transport/admin        # POST /api/admin/v1/users/export
```

不要创建 `adminexport`、`appexport`、`paymentexport` 这类包。平台差异是 route/request/presenter policy，不是复制业务模块的理由。

## 导出定义契约

运行时 registry 用稳定 `kind` 找 provider：

```go
type Definition struct {
    Kind     string
    Title    string
    Provider Provider
}

type Provider interface {
    BuildExportData(ctx context.Context, input BuildInput) (*FileData, error)
}

type BuildInput struct {
    TaskID   int64
    UserID   int64
    Platform string
    Kind     string
    Scope    Scope
    IDs      []int64
    Params   json.RawMessage
}
```

`Params` 只在 export runtime 边界保持 raw。每个 provider 必须解码成自己的强类型请求并拒绝非法数据。export runtime 不应该理解每个业务模块的筛选字段。

`kind` 命名示例：

```text
user_list
payment_orders
wallet_transactions
ai_runs
```

不要加 `admin_` 前缀。platform 不是业务能力。

## 新导出场景接入模板

以后接一个新导出场景，固定只做这些事：

```text
1. 在业务模块定义 typed request/filter
2. 在业务模块注册 export provider
3. 在业务模块保留自己的 submit endpoint
4. 在 route metadata 上绑定业务权限码
5. provider 返回稳定 headers + string rows
6. export runtime 创建 task、跑 worker、上传 COS、更新状态、发通知
7. 前端页面复用 useExportSubmit 提交，不复制任务页和上传逻辑
8. 补 provider/service/API/frontend/smoke 的最小验证
```

例子：

```text
用户列表导出:
  endpoint: POST /api/admin/v1/users/export
  permission: user_userManager_export
  kind: user_list
  provider: internal/module/user.ExportDataProvider

支付订单导出:
  endpoint: POST /api/admin/v1/payment/orders/export
  permission: payment_order_export
  kind: payment_orders
  provider: internal/module/payment/order.ExportDataProvider

钱包流水导出:
  endpoint: POST /api/admin/v1/wallet/transactions/export
  permission: wallet_transaction_export
  kind: wallet_transactions
  provider: internal/module/wallet.ExportDataProvider
```

这个模板的重点是：业务差异只进入 provider 和 submit request；导出生命周期不分叉。

## 提交契约

新导出提交接口使用这个形状：

```ts
type ExportScope = 'selected' | 'filtered'

interface ExportSubmitRequest {
  scope: ExportScope
  ids?: number[]
  filters?: object
}
```

规则：

- `scope=selected` 必须有非空正整数 `ids`。
- `scope=filtered` 必须有业务模块自己的强类型 filter。
- 每个业务模块自己设置最大导出行数。
- 授权由业务路由自己的 permission code 负责。
- service 先创建 pending task，再投递队列。
- task 创建后如果队列投递失败，必须立刻把任务标记 failed。

现有用户导出继续有效：

```ts
POST /api/admin/v1/users/export
{ ids: number[] }
```

如果 V2 触碰这个接口，`{ ids }` 只在 user transport/service 边界归一化为 `scope=selected`。不要让 export runtime 对所有未来模块猜测缺失的 `scope`。

## 队列 payload

当前 payload 只带 ids。V2 payload 改为：

```go
type RunPayload struct {
    TaskID   int64           `json:"task_id"`
    Kind     string          `json:"kind"`
    UserID   int64           `json:"user_id"`
    Platform string          `json:"platform"`
    Scope    string          `json:"scope"`
    IDs      []int64         `json:"ids,omitempty"`
    Params   json.RawMessage `json:"params,omitempty"`
}
```

兼容规则：

- 旧的 `user_list` job 如果没有 `scope`，只为 `user_list` 兼容解释成 `selected`。
- 新 job 必须带 `scope`。

payload 绝不能塞渲染后的 rows。Redis 不是 spreadsheet storage。

## 数据库设计

继续使用现有 `export_tasks` 表。只加真正能消除歧义的字段：

```sql
ALTER TABLE export_tasks
  ADD COLUMN kind varchar(64) NOT NULL DEFAULT 'user_list' COMMENT '导出类型',
  ADD COLUMN platform varchar(32) NOT NULL DEFAULT 'admin' COMMENT '平台入口',
  ADD COLUMN object_key varchar(500) NULL COMMENT 'COS object key';
```

这些字段有用：

- `kind`：多个导出场景需要知道来源，方便筛选、审计、worker 诊断。
- `platform`：admin/app/openapi/merchant 的任务可见性不能靠 `user_id` 猜。
- `object_key`：`file_url` 是展示 URL；COS 清理和对象生命周期需要真实 key。

V2 故意不加这些字段：

- `format`：现在只有 `.xlsx`。
- `progress`：本切片不做流式进度。
- `total_rows`：完成后 `row_count` 足够；预统计是 provider-specific，可能很贵。
- `params_json`：执行参数归队列 payload；任务列表不需要暴露筛选条件。
- `storage_driver`：运行时就是 COS-only。

已有 rows 回填为 `kind='user_list'`、`platform='admin'`。

## COS 上传契约

V2 保持服务端上传 COS：

```text
来源：enabled upload_setting + COS upload_driver
密钥：通过当前 APP_SECRET 派生的 secretbox 解密
content-type：application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
key: exports/<kind>/YYYYMMDD/<safe_title>_YYYYMMDD_HHMMSS_<task_id>.xlsx
url：优先 bucket_domain，否则默认 COS public URL
```

如果 upload config 缺失、不是 COS、secret 解密失败或 COS Put 失败，worker 必须把任务标记 failed。没有假成功。没有 fallback。

旧的 `exports/YYYYMMDD/...` URL 继续有效，因为老 rows 存的是完整 `file_url`；V2 只改变新 object key。

## 前端设计

### 用户列表

保持当前按钮位置和权限：

```text
permission: user_userManager_export
按钮：导出
第一阶段行为：只导出勾选 ids
```

当前用户列表不能在没勾选时偷偷导出全部。空选择仍然提示 `请选择至少一项`。

### 可复用提交 helper

实现阶段新增一个很小的前端 helper：

```text
src/hooks/useExportSubmit.ts
```

它只负责重复的客户端行为：

- selected id 检查
- 调 submit API
- 显示 i18n 成功提示
- 可选跳转 `/system/exportTask?status=1`

它不能拥有业务 filters、table state 或权限判断。这些必须留在各自页面。

### 导出任务页

后端字段存在后，再扩展列表筛选：

- `kind`
- `status`
- `title`
- `file_name`

响应可以增加：

```ts
interface ExportTaskItem {
  id: number
  kind: string
  kind_text: string
  title: string
  file_name: string | null
  file_url: string | null
  file_size_text: string
  row_count: number | null
  status: 1 | 2 | 3
  status_text: string
  error_msg: string | null
  expire_at: string | null
  created_at: string
}
```

触碰 Vue 文件时，不准硬编码可见中文；必须补 zh-CN/en-US i18n key。

## 权限和操作日志

提交权限归业务模块自己：

```text
POST /api/admin/v1/users/export -> user_userManager_export
未来支付订单导出             -> payment_order_export
未来钱包流水导出             -> wallet_ledger_export
```

导出任务 list/status-count 继续是登录用户自己的视图。

删除操作继续按当前用户隔离。如果有专用删除按钮权限，就用专用权限；不要拿 edit 这类无关权限凑数。

操作日志：

- 业务提交接口记录业务动作，例如 `module=user action=export title=用户导出`。
- 导出任务删除记录 `module=export_task action=delete/delete_batch`。
- worker 成功/失败写 `export_tasks`，不是 HTTP operation log。

## 错误处理

提交阶段错误：

- 勾选 ids 非法 -> 400
- 筛选条件非法 -> 400
- 查不到可导出数据 -> 404 或 provider-specific bad request
- task 创建后队列不可用 -> 标记 failed，返回 500

worker 阶段错误：

- 未知 kind -> 标记 failed
- payload 非法 -> task id 可加载时标记 failed
- provider 查询失败 -> 标记 failed
- xlsx 生成失败 -> 标记 failed
- upload config 缺失或解密失败 -> 标记 failed
- COS Put 失败 -> 标记 failed
- notification failure -> 只记录日志；不能把成功导出降级成失败

幂等规则：

- 已成功或已软删除的 task，worker retry 直接 no-op。
- 失败 task 只有未来显式 retry 功能才能覆盖；不能被随机重复 worker 执行改回成功。

## 测试策略

后端：

- `export` registry 能解析已知 kind，并拒绝 unknown kind。
- `RunPayload` 校验必填字段，并保留旧 `user_list` selected job 兼容。
- `Service.Run` 在 unknown kind、provider error、writer error、uploader error 时标记 failed。
- `COSUploader` 返回 `object_key`、`file_url`、`file_size`、`row_count`，并使用 `exports/<kind>/YYYYMMDD`。
- repository 创建和列表查询按 `user_id + platform + is_del` 隔离。
- migration 回填现有 rows 为 `kind=user_list/platform=admin`。
- 用户导出仍接受 `{ ids }`，并映射到 selected `user_list`。

前端：

- 用户导出按钮仍由 `user_userManager_export` 控制。
- 空 selected ids 仍阻止提交。
- submit helper 不硬编码中文。
- export task API 只使用 REST path；不出现 legacy action path。
- export task page 使用 AppTable/Search，不额外套 page-card。

Smoke：

默认 full smoke 继续只读：

```text
GET /api/admin/v1/export-tasks/status-count
GET /api/admin/v1/export-tasks?current_page=1&page_size=20
```

新增 credential-gated 真实导出 smoke：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\export-task-smoke.ps1 `
  -Account 15671628271 `
  -Password 123456 `
  -RunRealExport
```

这个 gated smoke 做六件事：

1. 登录；
2. 给一个已存在用户 id 提交 `user_list` 导出；
3. 轮询 `export-tasks`，直到 status 是成功或失败；
4. 断言成功行有 `.xlsx` 文件名、正数 file size、row count 和 COS 风格 `file_url`；
5. 通过 API 软删除刚创建的 task；
6. 不删除 COS object。

如果当前 `APP_SECRET` 解不开已启用 COS secrets，smoke 必须失败。跳过就是把这个功能最该发现的问题藏起来。

## 落地阶段

Phase 1：

- 加 `kind/platform/object_key` schema migration。
- 加 registry 和 V2 run payload。
- 保持当前用户导出 selected-only 行为。
- 让 user_list provider 通过 registry 注册。
- 补后端测试和 gated real export smoke。
- 更新契约、状态和 smoke 文档。

Phase 2：

- 加下一个真实导出场景，优先 payment orders 或 wallet transactions。
- 使用显式 `scope=selected|filtered`。
- 当 active kind 超过一个时，前端导出任务页再加 `kind` 筛选。

Phase 3：

- 只有真实用户需要时，再考虑 retry/cancel/object cleanup。

## 验收标准

实现完成必须满足：

1. 现有用户导出仍按当前 UI 和权限工作。
2. worker 能生成 `.xlsx` 并通过当前启用 upload config 上传 COS。
3. 上传、配置、解密失败会把任务标记 failed；不会留下永久 pending。
4. 导出任务列表仍按当前 token user 和 platform 隔离。
5. 至少一个带凭据开关的真实导出 smoke 证明 submit -> queue -> worker -> COS -> task success。
6. 文档明确区分已实现行为和未来计划导出场景。
