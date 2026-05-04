# Upload Config Foundation Design Spec

状态：proposed
日期：2026-05-04

## Goal

把旧 PHP 的上传配置管理迁到 Go REST + Vue typed client，但只做**配置地基**：上传驱动、上传规则、启用配置三块先闭环。真实上传 token、COS/OSS SDK 调用、服务端上传、AI/导出产物上传放到下一阶段。

一句话：先把“上传系统的事实源”做干净，再让业务模块依赖它。别把一个高风险上传链路硬塞进 CRUD 里。

## Linus 三问

```text
1. 真问题？是。上传配置现在仍走 PHP legacy 全 POST，后续头像、AI 图片、导出文件、支付对账、Tauri 包都会依赖上传地基。
2. 更简单做法？有。先迁配置 CRUD 和密钥加密；上传 token / SDK / 真实文件流下一阶段单独做。
3. 会破坏什么？不能破坏已有真实 COS/OSS 配置、现有前端上传配置页、RBAC 按钮权限、当前可用的上传数据。
```

## Current Verified Baseline

本 spec 建立在 2026-05-04 已推送基线上：

```text
admin_back_go  9a8222e feat: migrate system settings to Go REST
admin_front_ts cd20f29 feat: adapt system settings to Go API
admin_go       16698ee docs: document system settings migration
```

系统设置已经迁移。上传配置还没有开始实现，本 spec 只规划上传模块，不继续膨胀系统设置计划。

## Legacy Facts

### Legacy routes

旧 PHP routes 是全 POST action path，只作为业务事实，不进入 Go 新契约：

```text
/api/admin/UploadDriver/init
/api/admin/UploadDriver/list
/api/admin/UploadDriver/add
/api/admin/UploadDriver/edit
/api/admin/UploadDriver/del

/api/admin/UploadRule/init
/api/admin/UploadRule/list
/api/admin/UploadRule/add
/api/admin/UploadRule/edit
/api/admin/UploadRule/del

/api/admin/UploadSetting/init
/api/admin/UploadSetting/list
/api/admin/UploadSetting/add
/api/admin/UploadSetting/edit
/api/admin/UploadSetting/status
/api/admin/UploadSetting/del

/api/getUploadToken
```

`/api/getUploadToken` 是上传运行时能力，本阶段明确排除。

### Legacy permission codes

沿用现有按钮权限 code，不重新发明：

```text
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

### Legacy tables

当前 MySQL 表已经存在，本阶段不改表结构：

```text
upload_driver
upload_rule
upload_setting
```

`upload_driver` 关键字段：

```text
id int unsigned PK
driver varchar(20)
secret_id_enc text
secret_id_hint varchar(20)
secret_key_enc text
secret_key_hint varchar(20)
bucket varchar(255)
region varchar(100)
appid varchar(100)
endpoint varchar(255)
bucket_domain varchar(255)
role_arn varchar(255)
is_del tinyint unsigned default 2
created_at datetime
updated_at datetime
unique index uniq_driver_bucket(driver,bucket)
```

`upload_rule` 关键字段：

```text
id int unsigned PK
title varchar(50)
max_size_mb int unsigned default 5
image_exts json
file_exts json
is_del tinyint unsigned default 2
created_at datetime
updated_at datetime
```

`upload_setting` 关键字段：

```text
id int unsigned PK
driver_id int unsigned indexed
rule_id int unsigned indexed
status tinyint unsigned indexed, 1=启用, 2=禁用
is_del tinyint unsigned default 2
remark varchar(255)
created_at datetime
updated_at datetime
unique index uniq_driver_rule(driver_id,rule_id)
index idx_status(status)
index idx_rule(rule_id)
```

当前数据事实：

```text
upload_driver: 2 rows, cos + oss, secret 只保留 *_hint，不暴露明文
upload_rule: 2 rows, image_exts/file_exts 是 JSON array
upload_setting: 当前 id=1 为启用 COS 配置，其他配置禁用或软删
```

### Legacy enum facts

驱动：

```text
cos = 腾讯云 COS
oss = 阿里云 OSS
```

图片扩展名白名单：

```text
jpeg, jpg, gif, png, svg, ico, doc, psd, bmp, tiff, webp, tif, pjpeg
```

普通文件扩展名白名单：

```text
docx, pdf, txt, html, zip, tar, doc, css, csv, ppt, xlsx, xls, xml
```

上传目录白名单属于上传运行时，不是本阶段配置 CRUD 的主目标，但要先进入 enum，供下一阶段 token 使用：

```text
avatars, images, videos, cover_images, ai_chat_images, releases, tauri_updater,
exports, goods_tts, chat_images, chat_files, reconcile_reports, cine_keyframes
```

## Open Source / Official Source Review

本阶段不引入 COS/OSS SDK，因为只做配置 CRUD。真实上传阶段再引入 SDK，避免现在把依赖装进来但没有端到端上传验证。

已确认来源：

- 腾讯云 COS Go SDK：`github.com/tencentyun/cos-go-sdk-v5`，官方 README 使用 `go get -u github.com/tencentyun/cos-go-sdk-v5`。
- 阿里云 OSS：旧 v1 包是 `github.com/aliyun/aliyun-oss-go-sdk/oss`；阿里云 2025 文档说明 OSS SDK Go V2 使用 `github.com/aliyun/alibabacloud-oss-go-sdk-v2/oss` 并要求 Go 1.18+。
- 密钥加密用 Go 标准库，不引入自嗨 crypto 包：`crypto/aes.NewCipher` 支持 16/24/32 字节 key；`crypto/cipher.NewGCM` 提供标准 nonce length 的 GCM AEAD。

取舍：

```text
本阶段采用 Go stdlib AES-GCM 做 secretbox。
本阶段不引入 tencentyun/cos-go-sdk-v5。
本阶段不引入 aliyun OSS SDK。
下一阶段 upload runtime 再按 COS/OSS token/服务端上传需求选 SDK，并写独立 spec。
```

## Scope

### Included

- Go REST API：`/api/admin/v1/upload-drivers`, `/upload-rules`, `/upload-settings`
- enum/dict/validate：上传驱动、扩展名、上传目录、状态
- `internal/platform/secretbox`：AES-256-GCM 加密/解密，兼容旧 PHP KeyVault 数据格式
- upload config backend module：`route -> handler -> service -> repository -> model`
- Vue typed API：`src/api/system/uploadConfig.ts` 从 `legacyRequest` 切到 `request + ADMIN_API_PREFIX`
- 保持现有上传配置页交互，不重做 UI
- operation log metadata + 敏感字段 mask
- contract/current-status/smoke matrix 更新
- full smoke read-only probes；有 `VAULT_KEY` 时允许安全写入临时禁用配置并清理

### Excluded

- 不做 `/api/getUploadToken`
- 不做真实 COS STS / OSS STS 临时凭证
- 不做服务端上传文件流
- 不做前端真实 Upload 组件迁移
- 不做 SDK 依赖安装
- 不改表结构
- 不新增 all-POST action path
- 不做“兼容字段兜底”

## Architecture

### Backend package layout

采用一个业务模块 `uploadconfig`，不要拆出三个孤岛模块，因为 driver/rule/setting 生命周期强相关，而且 setting init 需要 driver/rule dict。

```text
admin_back_go/internal/module/uploadconfig/
  route.go
  handler.go
  request.go
  dto.go
  model.go
  repository.go
  service.go
  errors.go
  service_test.go
  repository_test.go   # 只有 DB 行为必须验证时才写
```

共享基建：

```text
admin_back_go/internal/enum/upload.go
admin_back_go/internal/dict/dict.go
admin_back_go/internal/validate/upload.go
admin_back_go/internal/platform/secretbox/secretbox.go
admin_back_go/internal/config/config.go
```

调用边界：

```text
handler: 只 bind query/body/path，调用 service，返回 response
service: 做业务规则、事务、敏感字段策略，不依赖 gin.Context
repository: 只做 GORM 查询/写入，不写业务判断
model: 只映射 upload_* 表字段
secretbox: 只做加解密，不知道 upload 业务
```

### Secretbox compatibility

旧 PHP `KeyVault` 格式必须兼容，否则现有 `secret_id_enc/secret_key_enc` 数据会废掉。

Go secretbox 规则：

```text
env: VAULT_KEY
key derivation: sha256(VAULT_KEY) -> 32 bytes
cipher: AES-256-GCM
nonce/iv length: 12 bytes
GCM tag length: 16 bytes
storage format: base64(iv(12) + tag(16) + ciphertext)
hint: empty -> ""; len<=4 -> "***" + plain; len>4 -> "***" + last4
```

没有 `VAULT_KEY` 时：

```text
encrypt/decrypt 必须返回明确配置错误
写入 secret 的 create/update 必须失败
不能假加密、不能明文写库、不能返回空字符串假装成功
```

## REST Contract

统一响应仍为：

```json
{ "code": 0, "data": {}, "msg": "ok" }
```

所有接口都在后台命名空间：

```text
/api/admin/v1
```

### Upload Drivers

#### Init

```text
GET /api/admin/v1/upload-drivers/init
Auth: bearer token
```

Response `data.dict`：

```ts
interface UploadDriverInitDict {
  upload_driver_arr: Array<{ label: string; value: 'cos' | 'oss' }>
}
```

#### List

```text
GET /api/admin/v1/upload-drivers
Auth: bearer token
```

Query：

```ts
interface UploadDriverListQuery {
  current_page: number
  page_size: number
  driver?: 'cos' | 'oss'
}
```

Response：

```ts
interface UploadDriverItem {
  id: number
  driver: 'cos' | 'oss'
  driver_show: string
  secret_id_hint: string
  secret_key_hint: string
  bucket: string
  region: string
  role_arn: string | null
  appid: string | null
  endpoint: string | null
  bucket_domain: string | null
  created_at: string
  updated_at: string
}
```

规则：list/detail 永远不返回 `secret_id_enc`, `secret_key_enc`, `secret_id`, `secret_key`。

#### Create

```text
POST /api/admin/v1/upload-drivers
Auth: bearer token + system_uploadConfig_driverAdd
```

Body：

```ts
type UploadDriverCreateBody =
  | {
      driver: 'cos'
      secret_id: string
      secret_key: string
      bucket: string
      region: string
      appid: string
      bucket_domain?: string
      endpoint?: string
      role_arn?: string
    }
  | {
      driver: 'oss'
      secret_id: string
      secret_key: string
      bucket: string
      region: string
      role_arn: string
      endpoint?: string
      bucket_domain?: string
      appid?: string
    }
```

Response：

```ts
{ id: number }
```

Rules：

```text
driver 必须是 cos/oss。
secret_id / secret_key create 必填。
同一 driver + bucket 不能重复。
cos 必须有 appid，因为后续 COS STS policy 需要 uid/appid。
oss 必须有 role_arn，因为后续 OSS STS AssumeRole 需要 role arn。
secret 写库只写 *_enc + *_hint。
operation log 必须 mask secret_id/secret_key。
```

#### Update

```text
PUT /api/admin/v1/upload-drivers/:id
Auth: bearer token + system_uploadConfig_driverEdit
```

Body：同 create，但 `secret_id` / `secret_key` 改为可选：

```ts
interface UploadDriverUpdateBody {
  driver: 'cos' | 'oss'
  secret_id?: string
  secret_key?: string
  bucket: string
  region: string
  role_arn?: string
  appid?: string
  endpoint?: string
  bucket_domain?: string
}
```

Rules：

```text
secret_id / secret_key 未传或空字符串：保留旧密文。
secret_id / secret_key 非空：重新加密并更新 hint。
不能用 null 清空密钥。
```

#### Delete

```text
DELETE /api/admin/v1/upload-drivers/:id
DELETE /api/admin/v1/upload-drivers        body: { ids: number[] }
Auth: bearer token + system_uploadConfig_driverDel
```

Rules：

```text
软删除 is_del=1。
如果有非删除 upload_setting 引用 driver，拒绝删除。别制造悬空配置。
```

### Upload Rules

#### Init

```text
GET /api/admin/v1/upload-rules/init
Auth: bearer token
```

Response `data.dict`：

```ts
interface UploadRuleInitDict {
  upload_image_ext_arr: Array<{ label: string; value: string }>
  upload_file_ext_arr: Array<{ label: string; value: string }>
}
```

#### List

```text
GET /api/admin/v1/upload-rules
Auth: bearer token
```

Query：

```ts
interface UploadRuleListQuery {
  current_page: number
  page_size: number
  title?: string
}
```

Response：

```ts
interface UploadRuleItem {
  id: number
  title: string
  max_size_mb: number
  image_exts: string[]
  file_exts: string[]
  created_at: string
  updated_at: string
}
```

#### Create / Update

```text
POST /api/admin/v1/upload-rules
PUT  /api/admin/v1/upload-rules/:id
Auth: bearer token + system_uploadConfig_ruleAdd/Edit
```

Body：

```ts
interface UploadRuleMutationBody {
  title: string
  max_size_mb: number
  image_exts: string[]
  file_exts: string[]
}
```

Rules：

```text
title 长度 1..50，按当前表结构走，不接受 100 字符假契约。
title 在 is_del=2 范围内唯一。
max_size_mb: 1..10240。
image_exts / file_exts 必须是数组。
扩展名统一 lower-case + trim + 去重，并按 enum 顺序归一化。
扩展名必须来自 Go enum 白名单。
image_exts 和 file_exts 不能同时为空。
```

#### Delete

```text
DELETE /api/admin/v1/upload-rules/:id
DELETE /api/admin/v1/upload-rules        body: { ids: number[] }
Auth: bearer token + system_uploadConfig_ruleDel
```

Rules：

```text
软删除 is_del=1。
如果有非删除 upload_setting 引用 rule，拒绝删除。别制造悬空配置。
```

### Upload Settings

#### Init

```text
GET /api/admin/v1/upload-settings/init
Auth: bearer token
```

Response `data.dict`：

```ts
interface UploadSettingInitDict {
  upload_driver_list: Array<{ label: string; value: number }>
  upload_rule_list: Array<{ label: string; value: number }>
  common_status_arr: Array<{ label: string; value: 1 | 2 }>
}
```

`upload_driver_list` label 使用：

```text
<driver_show> - <bucket>
```

`upload_rule_list` label 使用：

```text
<title>
```

#### List

```text
GET /api/admin/v1/upload-settings
Auth: bearer token
```

Query：

```ts
interface UploadSettingListQuery {
  current_page: number
  page_size: number
  remark?: string
  status?: 1 | 2
  driver_id?: number
  rule_id?: number
}
```

Response：

```ts
interface UploadSettingItem {
  id: number
  driver_id: number
  rule_id: number
  driver_name: string
  rule_name: string
  status: 1 | 2
  status_name: string
  remark: string
  created_at: string
  updated_at: string
}
```

#### Create / Update

```text
POST /api/admin/v1/upload-settings
PUT  /api/admin/v1/upload-settings/:id
Auth: bearer token + system_uploadConfig_settingAdd/Edit
```

Body：

```ts
interface UploadSettingMutationBody {
  driver_id: number
  rule_id: number
  status: 1 | 2
  remark?: string
}
```

Rules：

```text
driver_id 必须存在且 is_del=2。
rule_id 必须存在且 is_del=2。
driver_id + rule_id 在 is_del=2 范围内不能重复。
status 只能是 1/2。
status=1 时必须在一个 DB transaction 内完成：锁定当前 upload_setting 活跃行 -> 清空其他启用项 -> 写入/更新当前项。
```

#### Status

```text
PATCH /api/admin/v1/upload-settings/:id/status
Auth: bearer token + system_uploadConfig_settingStatus
```

Body：

```ts
{ status: 1 | 2 }
```

Rules：

```text
启用时执行同样的互斥事务。
禁用时只禁用当前项，不自动启用别人。
允许系统没有启用上传配置；下一阶段 token 接口会显式报“未配置有效上传设置”。
```

#### Delete

```text
DELETE /api/admin/v1/upload-settings/:id
DELETE /api/admin/v1/upload-settings        body: { ids: number[] }
Auth: bearer token + system_uploadConfig_settingDel
```

Rules：

```text
启用中的 setting 不允许删除。
软删除 is_del=1。
```

## Frontend Boundary

Frontend file ownership：

```text
admin_front_ts/src/api/system/uploadConfig.ts
admin_front_ts/src/views/Main/system/uploadConfig/index.vue
admin_front_ts/src/views/Main/system/uploadConfig/components/UploadDriver/index.vue
admin_front_ts/src/views/Main/system/uploadConfig/components/UploadRule/index.vue
admin_front_ts/src/views/Main/system/uploadConfig/components/UploadSetting/index.vue
```

Rules：

```text
新 API 使用 request + ADMIN_API_PREFIX。
不再使用 legacyRequest。
不命名 goRequest。
不新增 any / as any / Record<string, any>。
不在前端写 driver/status/ext fallback label，全部来自 Go init dict。
保留现有 AppDialog/AppTable/Search/useCrudTable 交互。
触碰组件时顺手修正明显格式问题，但不借迁移重做视觉系统。
```

现有 `useCrudTable` 可能假设 `edit(form)` 带 id。REST update/delete 需要 API 层把 `form.id` 转成 path param，而不是让页面散落拼 path。

## Operation Log and Sensitive Data

所有写操作都注册 route metadata：

```text
upload driver create/update/delete
upload rule create/update/delete
upload setting create/update/status/delete
```

Mask 字段：

```text
secret_id
secret_key
secret_id_enc
secret_key_enc
access_token
refresh_token
token
password
captcha_answer
code
```

Operation log 中允许出现 hint：

```text
secret_id_hint
secret_key_hint
```

## Tests and Smoke

Backend unit tests must cover：

```text
secretbox: missing VAULT_KEY, encrypt/decrypt legacy format, hint rules
upload driver: enum validation, duplicate driver+bucket, secret omission keeps old value, no plaintext DTO, referenced driver delete rejected
upload rule: duplicate title, max_size bound, invalid extension rejected, normalized extension order, referenced rule delete rejected
upload setting: driver/rule existence, duplicate combo, enabled delete rejected, transactional exclusive enable
route meta: mutating routes have permission code and operation log rule
```

Full smoke：

```text
read-only always:
  GET /upload-drivers/init
  GET /upload-drivers
  GET /upload-rules/init
  GET /upload-rules
  GET /upload-settings/init
  GET /upload-settings

write smoke only when VAULT_KEY exists:
  create disabled temp driver with fake secrets
  create temp rule
  create disabled temp setting
  verify list sees them
  delete setting -> rule -> driver cleanup
```

Write smoke must never touch existing enabled production-like row.

## Contract and Documentation Updates

Implementation must update these docs in the same task batch：

```text
docs/contracts/admin-api-v1.md
docs/migration/current-status.md
docs/testing/smoke-matrix.md
admin_back_go/docs/architecture.md
admin_back_go/.env.example
```

Do not mark upload config as implemented until Go tests, frontend typecheck/lint, and smoke evidence exist.

## Risks

```text
1. 密钥兼容风险：Go secretbox 必须兼容旧 PHP KeyVault，否则现有真实密钥不可用。
2. 密钥泄露风险：DTO、operation log、frontend form 都不能返回明文或密文。
3. 并发启用风险：upload_setting 启用互斥必须事务化，不能靠两条普通 update 碰运气。
4. 悬空引用风险：driver/rule 被 setting 引用时不应删除，否则配置页看起来正常但上传运行时炸。
5. 过早 SDK 风险：现在装 COS/OSS SDK 但不做端到端上传，只会制造假完成。
```

## Next Spec After This

上传配置迁移完成后，下一份 spec 才做：

```text
Upload Runtime Foundation:
/api/admin/v1/upload-token 或按前端上传组件契约命名
COS STS / OSS STS
folder whitelist
object key normalization
file ext / max size enforcement
future server-side upload worker boundary
```
