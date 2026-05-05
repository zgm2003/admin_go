# COS Upload Runtime Token Design Spec

状态：approved-by-user-direction
日期：2026-05-05

## Goal

把上传运行时从旧 PHP `/api/getUploadToken` 迁到 Go REST + Vue typed client，并且只内置腾讯云 COS。OSS 配置仍可在配置页维护，但 OSS runtime 是 optional extension：默认后端 `go.mod` 和前端 `package.json` 不引入阿里云 OSS SDK。

一句话：配置事实源已经迁完，现在只做一个 COS-first 的上传 token 地基，让后续头像、AI 图片、导出文件、Tauri 包、商品素材等业务能共用同一个上传入口。

## Linus 三问

```text
1. 真问题？是。当前前端真实上传仍在 src/lib/upload/uploadClient.ts 使用 legacyRequest + /api/getUploadToken，并且有 any / optional ali-oss 残留。
2. 更简单做法？有。先做 POST /api/admin/v1/upload-tokens，只签 COS 临时凭证和对象 key；不做服务端转存、不做 OSS、不改表。
3. 会破坏什么？不能破坏 upload config CRUD、已有 COS 配置、前端已有 uploadFileToCloud 调用形状；OSS 不能静默兜底成 COS。
```

## Current Evidence

```text
upload config 已 implemented/adapted：
- upload_driver / upload_rule / upload_setting CRUD
- secret 通过 VAULT_KEY + secretbox 加密
- setting 启用互斥事务

runtime 仍未迁：
- admin_front_ts/src/lib/upload/uploadClient.ts imports legacyRequest
- token path 仍为 /api/getUploadToken
- upload runtime 默认边界已经写入 contract：COS-only default, OSS optional
```

## Open Source / Official Source Review

本阶段尊重开源和官方 SDK，但不为了“看起来完整”乱装 OSS 依赖。

采用：

- 前端继续使用已存在依赖 `cos-js-sdk-v5`，它是腾讯云 COS JS SDK，适合浏览器直传。
- 后端 token 签发阶段优先使用腾讯云 STS 的轻量 SDK 或官方 API 封装，保持 `internal/platform/storage/cos` 很薄。

候选：

```text
github.com/tencentyun/cos-go-sdk-v5
github.com/tencentyun/qcloud-cos-sts-sdk/go
```

取舍：

```text
cos-go-sdk-v5 适合服务端操作 COS object。
本阶段不做服务端上传/下载 object，只签临时凭证，所以优先用 STS 能力，不把 object client 设计成业务入口。
如果 STS SDK 形态不适合当前 Go module，就在 platform/cos 内用标准 net/http 调腾讯云 STS API，但调用细节必须藏在 platform，module 不知道供应商 SDK。
```

明确不采用：

```text
不安装 ali-oss。
不安装阿里云 Go OSS SDK。
不在默认前端 bundle 静态 import OSS SDK。
不把 OSS runtime 写成假支持。
```

## Scope

### In scope

- 新 Go REST endpoint：

```text
POST /api/admin/v1/upload-tokens
```

- 读取当前 enabled `upload_setting`。
- join 到 `upload_driver` + `upload_rule`。
- 只接受 driver=`cos`。
- 解密 `secret_id_enc` / `secret_key_enc`。
- 生成规范化 object key。
- 根据 upload rule 校验：

```text
folder 白名单
file name / extension
file size
file kind: image | file
```

- 返回浏览器 COS 直传需要的临时凭证和上传限制。
- 前端 `src/lib/upload/uploadClient.ts` 从 legacy runtime 改成 Go typed API。
- 删除该文件里的 `any`、`as any`、`Record<string, any>`。
- OSS runtime 请求时明确错误。
- full smoke 增加 read-only token shape probe，只有在 COS runtime env 完整且 DB 有 enabled COS setting 时才执行。

### Out of scope

- 不做服务端接收文件流。
- 不做 OSS runtime。
- 不做上传文件数据库记录表。
- 不做断点续传、多分片上传 UI。
- 不做 CDN 刷新。
- 不改 upload_* 表结构。
- 不迁所有业务页面上传组件，只保证共享 upload client 可用。

## API Contract

### Request

```http
POST /api/admin/v1/upload-tokens
Authorization: Bearer <access_token>
Content-Type: application/json
```

```ts
interface UploadTokenRequest {
  folder: 'avatars' | 'images' | 'videos' | 'cover_images' | 'ai_chat_images' | 'releases' | 'tauri_updater' | 'exports' | 'goods_tts' | 'chat_images' | 'chat_files' | 'reconcile_reports' | 'cine_keyframes'
  file_name: string
  file_size: number
  file_kind: 'image' | 'file'
}
```

规则：

```text
folder 必须来自 internal/enum.UploadFolders。
file_name 只用于提取扩展名和生成安全文件名，不能信任前端传来的路径。
file_size 单位 byte，必须 > 0。
file_kind=image 时只查 image_exts；file_kind=file 时只查 file_exts。
```

### Response

```ts
interface UploadTokenResponse {
  provider: 'cos'
  bucket: string
  region: string
  key: string
  upload_path: string
  bucket_domain: string | null
  credentials: {
    tmp_secret_id: string
    tmp_secret_key: string
    session_token: string
  }
  start_time: number
  expired_time: number
  rule: {
    max_size_mb: number
    image_exts: string[]
    file_exts: string[]
  }
}
```

对象 key 规则：

```text
{folder}/{yyyy}/{mm}/{dd}/{unix_ms}-{random8}-{safe_file_name}
```

示例：

```text
images/2026/05/05/1777900000000-a1b2c3d4-demo.png
```

`safe_file_name` 规则：

```text
只保留 ASCII 字母、数字、点、下划线、短横线。
其他字符替换为下划线。
空文件名改为 file。
最多保留 120 字符。
```

### Error cases

```text
没有 enabled upload setting              -> 100 / 未配置有效上传设置
enabled setting 指向 deleted driver/rule -> 100 / 上传配置不完整
enabled driver != cos                    -> 100 / 当前上传驱动未启用 COS runtime
VAULT_KEY 为空或密钥解密失败             -> 500 / 上传密钥不可用
folder 不在白名单                       -> 100 / 上传目录不支持
file_size 超出 rule.max_size_mb          -> 100 / 文件大小超过限制
extension 不在允许列表                   -> 100 / 文件类型不支持
COS STS 配置缺失                         -> 500 / COS 临时凭证配置不完整
COS STS 请求失败                         -> 500 / COS 临时凭证签发失败
```

禁止：

```text
禁止 fallback 到 legacy /api/getUploadToken。
禁止 OSS fallback 到 COS。
禁止返回 upload_driver secret 明文。
禁止把 secret 写入 operation log。
```

## Backend Architecture

### Module

新建模块：

```text
admin_back_go/internal/module/uploadtoken
```

内部仍然按项目固定边界：

```text
route -> handler -> service -> repository -> model
```

但不硬造 model：

```text
route.go       注册 POST /api/admin/v1/upload-tokens
handler.go     bind JSON，调用 service
request.go     HTTP binding tag
dto.go         response DTO + service input
service.go     规则校验、key 生成、调用 COS signer
repository.go  查询 enabled setting + driver + rule
errors.go      模块错误文案
```

Repository 可以复用 uploadconfig 的表结构概念，但不要 import uploadconfig handler/service。跨模块只能依赖稳定表事实或抽更小的 shared DTO；第一期用本模块 query row，避免把 uploadconfig service 变成杂货铺。

### Platform boundary

新建平台包：

```text
admin_back_go/internal/platform/storage/cos
```

职责：

```text
只负责 Tencent COS STS temporary credentials。
不负责上传配置业务规则。
不负责 DB。
不依赖 Gin。
所有网络调用都必须接收 context.Context。
```

接口：

```go
type CredentialSigner interface {
    Sign(ctx context.Context, input SignInput) (*Credentials, error)
}
```

`uploadtoken.Service` 只依赖这个小接口，方便单测 fake signer。

### Config

新增 env：

```text
UPLOAD_TOKEN_TTL=15m
UPLOAD_KEY_RANDOM_BYTES=4
COS_STS_ENABLED=false
COS_STS_ENDPOINT=sts.tencentcloudapi.com
COS_STS_REGION=ap-guangzhou
```

说明：

```text
secret_id / secret_key 来自 upload_driver 加密字段，不再重复放 env。
COS_STS_ENABLED=false 时 token endpoint 可以注册，但请求时明确返回 COS 临时凭证未启用。
生产必须打开 COS_STS_ENABLED 并配置真实 COS driver。
```

## Frontend Architecture

### API layer

新建：

```text
admin_front_ts/src/api/system/uploadToken.ts
```

职责：

```text
只定义 UploadTokenRequest / UploadTokenResponse / UploadTokenApi。
使用 request + ADMIN_API_PREFIX。
不 import cos-js-sdk-v5。
不 import legacyRequest。
```

### Runtime client

改造：

```text
admin_front_ts/src/lib/upload/uploadClient.ts
```

保留现有对外方法：

```ts
getUploadToken(params)
validateFile(file, config, type)
uploadFileToCloud(file, config)
```

但实现改为：

```text
getUploadToken -> UploadTokenApi.create
uploadFileToCloud 只支持 provider='cos'
provider='oss' 直接 throw Error('当前版本未启用 OSS 上传运行时，请安装可选扩展或切换为 COS')
```

类型要求：

```text
不允许 any。
不允许 as any。
不允许 Record<string, any>。
COS SDK 回调类型最小化定义成本地接口，不把 SDK 类型泄漏到业务层。
```

## Security

```text
Token endpoint 必须走 AuthToken + PermissionCheck。
初始 permission code：system_uploadToken_create。
OperationLog 默认不记录 token response；如果记录 request，只允许 folder/file_name/file_size/file_kind，不记录 credentials。
STS policy 只允许当前 key 前缀，不给 bucket 全量写权限。
临时凭证 TTL 默认 15 分钟。
object key 由服务端生成，前端不能自选 key。
file_size 和 extension 后端先校验；前端校验只是体验优化。
```

## Distributed / Runtime Boundary

这个接口是 stateless 的：

```text
admin-api 多副本可以同时签发 token。
配置真相在 MySQL。
secret 解密依赖每个节点一致的 VAULT_KEY。
STS 网络请求必须使用 context timeout。
不在进程内缓存 secret 明文。
```

第一期不加 Redis cache。理由：签 token 是低频操作，配置正确性比省一次 DB 查询更重要。后续上传量上来再做短 TTL cache，并且必须接入 upload config 变更失效。

## Tests

Backend unit tests:

```text
TestCreateRejectsMissingEnabledSetting
TestCreateRejectsNonCOSDriver
TestCreateRejectsUnsupportedFolder
TestCreateRejectsUnsupportedImageExtension
TestCreateRejectsOversizeFile
TestCreateBuildsSafeKeyAndSignsCOS
TestCreateDoesNotExposeDriverSecrets
TestCOSSignerDisabledReturnsExplicitError
```

Frontend checks:

```text
npx vue-tsc -b --pretty false
npx eslint src/api/system/uploadToken.ts src/lib/upload/uploadClient.ts
```

Smoke:

```text
full-admin-smoke.ps1:
- login
- if COS_STS_ENABLED=false -> assert upload_token_probe=skipped_cos_sts_disabled
- if enabled + COS setting exists -> POST upload-tokens with safe test file metadata and assert provider/key/credentials shape
- never upload a real file in smoke
```

## Documentation Updates

必须同步：

```text
docs/contracts/admin-api-v1.md
docs/migration/current-status.md
docs/testing/smoke-matrix.md
admin_back_go/docs/architecture.md
admin_back_go/.env.example
```

状态规则：

```text
spec/plan 写完不算 implemented。
backend + frontend + tests + smoke 都过，current-status 才能从 planned 改为 implemented/adapted。
```

## Next Step After This

```text
按 plan 实现 COS upload runtime/token。
之后再迁第一个真实业务上传点，例如头像或 AI 图片；不要一口气改所有上传页面。
```
