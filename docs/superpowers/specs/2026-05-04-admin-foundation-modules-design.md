# Admin Foundation Modules Batch 1 Design Spec

状态：proposed
日期：2026-05-04

## Goal

在 admin core 已经完成登录、RBAC、用户、角色、权限、操作日志、队列监控、系统日志之后，按窄切片迁移下一批基础模块：

1. 系统设置 `system-settings`
2. 上传配置 `upload-drivers` / `upload-rules` / `upload-settings`
3. 通知/导出任务只进入后续队列，不在本批实现

这不是灌业务。它是继续打地基：配置、上传、后续业务文件产物都会依赖它。

## Linus 三问

```text
1. 真问题？是。当前 system setting 和 upload config 仍走 PHP legacy 全 POST，后续业务、上传、导出、AI 资产都会依赖这些能力。
2. 更简单做法？有。先迁系统设置，再迁上传配置管理；上传 token/COS runtime SDK 放到配置稳定后，OSS runtime 只做 optional extension。
3. 会破坏什么？不能破坏 RBAC、现有页面按钮权限、已有上传配置数据、现有前端表格交互。
```

## Current Facts

从当前仓库和 legacy 读取到的事实：

- `docs/migration/current-status.md` 已把 `upload settings read path` 和 `system settings read path` 标为 next candidates。
- 前端当前仍有 legacy API：
  - `admin_front_ts/src/api/system/setting.ts`
  - `admin_front_ts/src/api/system/uploadConfig.ts`
- 旧 PHP 系统设置：
  - 表：`system_settings`
  - value type：`1=字符串, 2=数字, 3=布尔, 4=JSON`
  - key 查询使用前缀匹配
  - 写入/状态/删除会清理 setting cache
  - 当前存在菜单页面，所以系统设置 CRUD 必须迁移到 Go，不能留空页或继续走 legacy
  - `devtools_queue_monitor_queues` 是旧 PHP 队列监控配置；Go 队列监控已经采用官方 `asynqmon` + env/Asynq lane，不再从 `system_settings` 读取这条配置
- 旧 PHP 上传配置：
  - 表：`upload_driver`, `upload_rule`, `upload_setting`
  - driver 当前枚举：`cos`, `oss`
  - rule 持有 `max_size_mb`, `image_exts`, `file_exts`
  - setting 组合 driver + rule，启用项互斥；启用配置不能删除
  - driver 密钥只返回 hint，不返回明文

## Design Boundary

本批只做 admin 管理配置，不做真正文件上传链路。

### Included

- Go REST API under `/api/admin/v1/...`
- Go module 分层：`route -> handler -> service -> repository -> model`
- enum/dict/validate 基建补齐
- 前端 API 从 `legacyRequest` 迁到 `request`
- 前端页面保持现有 Element Plus 表格交互，不重做 UI
- 队列监控页面保持官方 `asynqmon` 薄包装，不在本批重写、不删除
- operation log route metadata for mutations
- contract/current-status/smoke matrix docs

### Excluded

- 不做 `/api/getUploadToken` 兼容迁移
- 本批不接任何云 SDK；下一批 runtime 默认只允许 COS SDK 进内置依赖，OSS SDK 只做用户自选安装
- 不实际上传文件
- 不做通知任务、导出任务实现
- 不改表结构
- 不新增 all-POST 接口

## REST Contract Shape

### System Settings

```text
GET    /api/admin/v1/system-settings/init
GET    /api/admin/v1/system-settings
POST   /api/admin/v1/system-settings
PUT    /api/admin/v1/system-settings/:id
PATCH  /api/admin/v1/system-settings/:id/status
DELETE /api/admin/v1/system-settings/:id
DELETE /api/admin/v1/system-settings        body: { ids: number[] }
```

Query:

```ts
interface SystemSettingListQuery {
  current_page: number
  page_size: number
  key?: string
  status?: 1 | 2 | ''
}
```

Create body:

```ts
interface SystemSettingCreateBody {
  key: string
  value: string
  type: 1 | 2 | 3 | 4
  remark?: string
}
```

Update body:

```ts
interface SystemSettingUpdateBody {
  value: string
  type: 1 | 2 | 3 | 4
  remark?: string
}
```

Rules:

- `key` create-only；编辑不允许改 key，避免缓存和业务读取歧义。
- `type=2` 必须能解析为 number。
- `type=3` 只接受 `0/1/true/false`。
- `type=4` 必须是合法 JSON object 或 array。
- DB 是事实源；Redis cache 只能加速读取，写入、状态、删除必须清理对应 key。
- 不返回兜底字段，不接受 `setting_key` 作为 create/update 入参。
- 队列监控不属于系统设置 CRUD：`devtools_queue_monitor_queues` 迁移后应软删或标记删除；Go 队列监控继续使用 `QUEUE_*` env、Asynq Redis lane 和官方 asynqmon UI。

### Upload Drivers

```text
GET    /api/admin/v1/upload-drivers/init
GET    /api/admin/v1/upload-drivers
POST   /api/admin/v1/upload-drivers
PUT    /api/admin/v1/upload-drivers/:id
DELETE /api/admin/v1/upload-drivers/:id
DELETE /api/admin/v1/upload-drivers        body: { ids: number[] }
```

Rules:

- driver 必须来自 enum：`cos | oss`。
- 同一 `driver + bucket` 不允许重复。
- list/detail 永远不返回 `secret_id` / `secret_key` 明文，只返回 `secret_id_hint` / `secret_key_hint`。
- create 必须提供密钥。
- update 如果不轮换密钥，前端明确不发送 `secret_id` / `secret_key`；后端保持旧密钥。
- 加密能力独立放在 `internal/platform/secretbox` 或同等薄封装；未配置密钥时，写入密钥的接口必须显式失败，不允许假加密。

### Upload Rules

```text
GET    /api/admin/v1/upload-rules/init
GET    /api/admin/v1/upload-rules
POST   /api/admin/v1/upload-rules
PUT    /api/admin/v1/upload-rules/:id
DELETE /api/admin/v1/upload-rules/:id
DELETE /api/admin/v1/upload-rules        body: { ids: number[] }
```

Rules:

- `title` 不允许重复。
- `max_size_mb` 范围：`1..10240`。
- `image_exts` 和 `file_exts` 必须来自 enum 白名单。
- repository/model 负责 JSON 字段读写；service 负责业务合法性。

### Upload Settings

```text
GET    /api/admin/v1/upload-settings/init
GET    /api/admin/v1/upload-settings
POST   /api/admin/v1/upload-settings
PUT    /api/admin/v1/upload-settings/:id
PATCH  /api/admin/v1/upload-settings/:id/status
DELETE /api/admin/v1/upload-settings/:id
DELETE /api/admin/v1/upload-settings        body: { ids: number[] }
```

Rules:

- `driver_id + rule_id` 不允许重复。
- 启用状态互斥；启用一个 setting 时事务内关闭其他 enabled setting。
- 启用中的 setting 不允许删除。
- `init` 字典从当前可用 driver/rule 列表生成。
- 不在本批实现上传 token；本模块只是配置事实源。

## Permissions and Operation Logs

沿用现有前端按钮权限 code，不重新发明：

```text
system_setting_add
system_setting_edit
system_setting_status
system_setting_del
system_uploadConfig_driverAdd
system_uploadConfig_driverEdit
system_uploadConfig_driverDel
system_uploadConfig_ruleAdd
system_uploadConfig_ruleEdit
system_uploadConfig_ruleDel
system_uploadConfig_settingAdd
system_uploadConfig_settingEdit
system_uploadConfig_settingStatus
system_uploadConfig_settingDel
```

如果 DB 权限 code 与上面不一致，以 live DB/前端菜单事实为准，不能靠猜。

所有 create/update/status/delete 都要注册 operation log rule。敏感字段必须 mask：

```text
secret_id
secret_key
secret_id_enc
secret_key_enc
token
password
```

## Frontend Architecture

- API 层：`src/api/system/setting.ts` 和 `src/api/system/uploadConfig.ts` 改为 `request + ADMIN_API_PREFIX`。
- 页面层：优先保持现有表格/弹窗，不借迁移重做 UI。
- 如果触碰后单个 `.vue` 超过 lint 阈值或职责过多，再拆 `components/` 和 `composables/`。
- touched code 不新增 `any/as any/Record<string, any>`。
- 不保留 fallback labels；所有 select options 从 Go dict/init 来。

## Implementation Order

为了小步可验收，必须按这个顺序：

1. System Settings backend + frontend + smoke
2. Upload enum/dict/secretbox foundation
3. Upload Drivers backend + frontend
4. Upload Rules backend + frontend
5. Upload Settings backend + frontend
6. Full smoke 增加 disabled temp upload config probe
7. 下一批再做 COS-first upload token + real storage SDK；OSS 只作为 optional extension

## Verification Gate

Backend:

```powershell
cd E:/admin_go/admin_back_go
go test -p=1 ./internal/module/systemsetting ./internal/enum ./internal/dict ./internal/validate ./internal/server ./internal/bootstrap
go test -p=1 ./internal/module/uploadconfig ./internal/platform/secretbox ./internal/enum ./internal/dict ./internal/validate ./internal/server ./internal/bootstrap
go test -p=1 ./...
go vet -p=1 ./...
git diff --check
```

Frontend:

```powershell
cd E:/admin_go/admin_front_ts
npx vue-tsc -b --pretty false
npx eslint src/api/system/setting.ts src/api/system/uploadConfig.ts src/views/Main/system/setting/index.vue src/views/Main/system/uploadConfig/**/*.vue
```

Smoke:

```powershell
cd E:/admin_go/admin_back_go
powershell -ExecutionPolicy Bypass -File .\scripts\basic-admin-smoke.ps1 -Account 15671628271 -Password 123456
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account 15671628271 -Password 123456
```

## Known Risks

- 上传 driver 密钥加密是高风险点，不能为了赶进度明文存储。
- upload setting 启用互斥必须事务化，否则并发下会出现多个 enabled setting。
- 上传 token 不在本批，不能把“配置管理完成”说成“上传系统完成”。
- 旧前端上传组件里还有 `any`，本批不碰真实上传链路时不强行扩大范围；后续 upload token 迁移时必须处理。
