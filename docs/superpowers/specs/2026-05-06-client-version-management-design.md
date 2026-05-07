# Client Version Management Design

Status: implemented; amended on 2026-05-07 to canonicalize table and RBAC code names before production.
Date: 2026-05-06
Scope: migrate the existing “系统管理 / 版本管理” slice from legacy PHP to Go REST + typed Vue client.

## Linus 三问

1. 真问题：是。当前版本管理仍走 `legacyRequest` 和 PHP `/api/admin/TauriVersion/*`，系统管理模块没有闭环。
2. 更简单的方法：统一成 `client_versions` 表和 `system_clientVersion_*` RBAC button codes；Go 模块/API、前端视图目录、页面 i18n key 使用 clientVersion；菜单 PAGE 数据保持 `system/clientVersion`。
3. 会破坏什么：项目未上线，直接清理历史 Tauri 命名不会破坏外部 userspace；本切片必须同步 DB migration、Go route metadata、前端 buttonCodes 和文档。

## Open-source / official source check

- Tauri v2 updater 支持 static JSON 或 dynamic update server；static JSON 必须包含 `version`、`platforms.[target].url`、`platforms.[target].signature`，`pub_date` 若存在必须 RFC3339，平台 key 使用 `OS-ARCH` 形式。
- 腾讯云 COS Go SDK 使用 `github.com/tencentyun/cos-go-sdk-v5`，可通过 ObjectService 执行对象上传；本项目不引入 OSS Go SDK。
- 本模块不需要新的队列/cron：版本发布是管理员同步操作；慢的是二进制文件上传，已由前端 COS 直传承担。`update.json` 很小，服务器同步发布可以接受。

References:
- https://v2.tauri.app/zh-cn/plugin/updater/
- https://pkg.go.dev/github.com/tencentyun/cos-go-sdk-v5

## Naming decision

新 Go 世界不再把模块命名成 `tauriVersion`。

```text
Backend module: internal/module/clientversion
REST resource:  /api/admin/v1/client-versions
Domain wording: client version / 客户端版本
DB table:       client_versions  # canonical storage table
Frontend route: src/views/Main/system/clientVersion  # canonical page folder
Frontend API:   src/api/system/clientVersion.ts     # 新 typed client；旧 tauriVersion.ts 删除或变成无导出死代码检查失败
I18n key:       clientVersion                         # page key; menu key target is menu.system_clientVersion
Permission:     system_clientVersion_*             # canonical RBAC button codes
```

这不是“命名洁癖”。这是消除特殊情况：业务叫“客户端版本”，Tauri 只是当前桌面壳实现细节。项目未上线，DB 表和按钮权限 code 不需要背历史包袱，统一成 `client_versions` 和 `system_clientVersion_*`；旧 Tauri 名称只作为 legacy 事实或迁移 source condition 存在。

## Current legacy facts

Legacy reference files:

```text
E:/admin/admin_back/app/controller/System/TauriVersionController.php
E:/admin/admin_back/app/module/System/TauriVersionModule.php
E:/admin/admin_back/app/dep/System/TauriVersionDep.php
E:/admin/admin_back/app/validate/System/TauriVersionValidate.php
E:/admin/admin_back/app/service/System/TauriUpdaterService.php
```

Legacy behavior to preserve:

- List: filter by `platform`, active rows only, order by `id desc`, return `file_size_text`.
- Create: `version + platform + is_del=2` unique; default `is_latest=2`, `force_update=2`.
- Update: only update whitelisted fields; if latest row changes manifest fields, republish `update.json`.
- Set latest: transactionally clear old latest for the same platform, set selected row latest, publish `update.json`.
- Delete: forbid deleting current latest.
- Force update: update `force_update` only after row existence check.
- Client check: public current client check returns `{ force_update: boolean }`; missing version returns false.
- Manifest: latest row produces Tauri static JSON shape; missing latest returns `[]` for admin preview compatibility.

Corrected legacy fact:

- Legacy comment says hard delete, but `BaseDep::delete()` soft-deletes by setting `is_del=1`. Go must soft-delete, because the table already has `uk_version_platform_del(version, platform, is_del)`.

## Database contract

Canonical table after 2026-05-07 domain rename migration:

```text
client_versions(
  id,
  version,
  notes,
  file_url,
  signature,
  platform,
  file_size,
  is_latest,
  force_update,
  is_del,
  created_at,
  updated_at
)
```

Important indexes:

```text
uk_version_platform_del(version, platform, is_del)
idx_platform_latest(platform, is_latest)
idx_force_update(force_update)
idx_created_at(created_at)
```

Rules:

- `is_del=2` is active; `is_del=1` is deleted.
- `is_latest=1` means latest; `is_latest=2` means not latest.
- `force_update=1` means force; `force_update=2` means normal.
- Exactly one latest row per platform is a service invariant. DB does not currently enforce partial unique latest, so service transaction must enforce it.

## Enum / dict / validate

Add first-class Go enum/dict/validate support:

```text
internal/enum/client_version.go
internal/dict/client_version.go or extend dict.go with focused function
internal/validate/client_version.go
```

Supported platforms in v1:

```text
windows-x86_64 => Windows
darwin-x86_64  => macOS
```

Do not reuse upload folder enum as version platform truth. Upload config can know folders; client version owns client platform.

Init response:

```ts
interface ClientVersionPageInitResponse {
  dict: {
    client_version_platform_arr: Array<{ label: string; value: 'windows-x86_64' | 'darwin-x86_64' }>
    common_yes_no_arr: Array<{ label: string; value: 1 | 2 }>
  }
}
```

## REST API contract

All responses use existing `{ code, data, msg }` envelope.

### Admin read APIs

```http
GET /api/admin/v1/client-versions/page-init
GET /api/admin/v1/client-versions?current_page=1&page_size=20&platform=windows-x86_64
GET /api/admin/v1/client-versions/update-json?platform=windows-x86_64
```

Auth:

- bearer token only.
- No mutating RBAC button permission for read endpoints.
- No OperationLog for read endpoints.

List item:

```ts
interface ClientVersionItem {
  id: number
  version: string
  notes: string
  file_url: string
  signature: string
  platform: 'windows-x86_64' | 'darwin-x86_64'
  platform_name: string
  file_size: number
  file_size_text: string
  is_latest: 1 | 2
  is_latest_name: string
  force_update: 1 | 2
  force_update_name: string
  created_at: string
  updated_at: string
}
```

### Admin mutation APIs

```http
POST   /api/admin/v1/client-versions
PUT    /api/admin/v1/client-versions/:id
PATCH  /api/admin/v1/client-versions/:id/latest
PATCH  /api/admin/v1/client-versions/:id/force-update
DELETE /api/admin/v1/client-versions/:id
```

Permissions:

```text
POST latest? no, create:             system_clientVersion_add
PUT update:                          system_clientVersion_edit
PATCH /:id/latest:                   system_clientVersion_setLatest
PATCH /:id/force-update:             system_clientVersion_forceUpdate
DELETE /:id:                         system_clientVersion_del
```

OperationLog metadata:

```text
client_version.create
client_version.update
client_version.set_latest
client_version.force_update
client_version.delete
```

Sensitive logging:

- `signature` can be long but is not a secret; still cap by OperationLog existing 64KB cap.
- No COS `secret_id/secret_key`, upload credentials, tokens, or private keys may appear in request/response logs.

Create body:

```ts
interface ClientVersionCreateBody {
  version: string              // required, max 20, SemVer-ish string accepted by Tauri
  notes?: string               // max 1000
  file_url: string             // required URL
  signature: string            // required .sig content, not URL
  platform: 'windows-x86_64' | 'darwin-x86_64'
  file_size?: number           // >= 0
  force_update?: 1 | 2
}
```

Update body:

```ts
interface ClientVersionUpdateBody extends ClientVersionCreateBody {}
```

Force update body:

```ts
interface ClientVersionForceUpdateBody { force_update: 1 | 2 }
```

### Public current-client check

```http
GET /api/admin/v1/client-versions/current-check?version=1.0.7&platform=windows-x86_64
```

Auth:

- public, same as login-config/captcha category.
- No RBAC.
- No OperationLog.

Response:

```ts
interface ClientVersionCurrentCheckResponse {
  force_update: boolean
}
```

Missing row returns `force_update=false`. Unsupported platform is `400`.

Rationale: this is an admin desktop client capability, so it remains under admin scope, but it cannot require an already-valid token because force-update checks may run before login or during app bootstrap.

## Manifest publishing

This slice must not fake release behavior.

When these operations affect the latest row, Go must publish `update.json` to object storage:

```text
set latest
update latest row's version/notes/file_url/signature/file_size/force_update
```

Manifest path:

```text
tauri_updater/{platform}.json
```

Manifest payload:

```json
{
  "version": "1.0.7",
  "notes": "...",
  "pub_date": "2026-02-09T21:38:05+08:00",
  "platforms": {
    "windows-x86_64": {
      "url": "https://.../CloudAdmin_1.0.7_x64-setup.exe",
      "signature": "content of .sig file"
    }
  }
}
```

Storage rules:

- Use enabled upload setting and COS driver only.
- Decrypt COS secret via existing `secretbox` / `VAULT_KEY` path.
- Use official `github.com/tencentyun/cos-go-sdk-v5` for server-side `PutObject`/equivalent.
- Do not introduce OSS server SDK in this slice.
- If no enabled COS upload setting or VAULT_KEY cannot decrypt, mutating operation that needs manifest publish must return explicit error; do not silently mark latest without publishing.

Good taste rule: DB latest and published manifest must not diverge on success. Therefore set-latest/update-latest should run DB transaction first only if publish is part of the same service flow with rollback on publish failure, or publish after transaction with compensating rollback. The implementation plan will choose the simpler safe sequence with repository transaction and test it.

## Frontend adaptation

Create new typed API:

```text
src/api/system/clientVersion.ts
```

Update existing page:

```text
src/views/Main/system/clientVersion/index.vue
src/views/Main/system/clientVersion/components/SignatureInput.vue only if type cleanup is needed
src/components/TauriManager/src/index.vue for current-check and `any` removal
```

Rules:

- Use `request`, not `legacyRequest`.
- No `any`, `as any`, or fallback response fields in touched files.
- Keep `useCrudTable` shape by adapting API methods (`add/edit/del`) inside the typed client.
- Rename page folder and page i18n keys to clientVersion; apply the menu PAGE data migration for path/component/i18n_key.
- If download filename is touched, derive extension from URL instead of hardcoding `.zip`.

## Testing / smoke

Backend unit tests:

- enum/dict/validate platform support.
- create rejects duplicate active version+platform.
- create defaults force/latest values.
- set latest clears old latest in same platform only.
- delete rejects latest and soft-deletes non-latest.
- force update toggles only existing row.
- manifest payload obeys Tauri shape and RFC3339.
- update latest triggers publisher; publish failure prevents silent success.
- current-check missing row returns false.

Router/meta tests:

- all REST paths are registered.
- mutation routes have expected RBAC permission codes.
- mutation routes have expected OperationLog metadata.
- read/public endpoints have no OperationLog.

Frontend tests/type gates:

- API contract test proves methods call `/api/admin/v1/client-versions...` and never legacy paths.
- `vue-tsc` passes.
- targeted eslint on touched files.

Smoke extension:

- Read-only full smoke: page-init, list, update-json shape.
- Optional write smoke when enabled by flag: create temp version, set latest, force-update toggle, delete cleanup. Default smoke should not disturb real latest row.

## Out of scope

- Table rename from `tauri_version` to `client_versions` is required and tracked by `20260507_client_version_domain_rename.sql`.
- Menu PAGE route/component/i18n_key migration is limited to the client version page only.
- No permission code rename.
- No multi-platform release pipeline automation.
- No OSS runtime upload/publish.
- No AI/chat/pay module changes.
