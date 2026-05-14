# Admin API v1 Contract

状态：partially implemented。本文只记录 Go 新接口已经明确落地或正在本阶段收口的契约；旧 PHP 全 POST 接口只作为 legacy adapter，不定义新契约。

统一响应：

```json
{ "code": 0, "data": {}, "msg": "ok" }
```

命名空间：

```text
后台管理端：/api/admin/v1
未来 App 端：/api/app/v1
```

## Contract Source Policy

状态：implemented as documentation gate baseline。

当前阶段采用 **Markdown first**：`docs/contracts/admin-api-v1.md` 是人工可读的前后端契约源；OpenAPI YAML 等自动化产物后续再引入，不能反过来替代本文的业务规则说明。

规则：

```text
每个迁移到 Go 的资源必须先更新本文，再改前端调用。
新 Go API 只能使用 /api/admin/v1 或 /api/app/v1 命名空间。
新 Go API 使用 RESTful resource，不允许 /api/admin/Xxx/list、/api/admin/Xxx/add、/api/admin/Xxx/edit、/api/admin/Xxx/del 这种 legacy action path。
init/page-init 属于页面字典或 bootstrap contract，必须显式写清用途和 enum/dict 来源。
旧 PHP 兼容入口必须标注 legacy adapter，不得伪装成新契约。
```

本地 contract gate：

```powershell
cd E:/admin_go/admin_back_go
powershell -ExecutionPolicy Bypass -File .\scripts\check-contract.ps1
```

## Auth Requirement Matrix

状态：implemented for current Go routes。

| Area | Routes | Auth requirement |
| --- | --- | --- |
| health/readiness | `GET /health`, `GET /ready` | public |
| auth config/captcha/code/login/forgot-password/refresh | `/api/admin/v1/auth/login-config`, `/captcha`, `/send-code`, `/forgot-password`, `/login`, `/refresh` | public |
| logout | `POST /api/admin/v1/auth/logout` | bearer token |
| current user bootstrap | `GET /api/admin/v1/users/me`, `GET /api/admin/v1/users/init` | bearer token |
| read-only admin resources | permissions/auth-platforms/roles/users/profile/operation-logs/system-settings/mail/upload-drivers/upload-rules/upload-settings/notifications list or init | bearer token |
| user quick-entry current-user write | `PUT /api/admin/v1/users/me/quick-entries` | bearer token; current user only, no user-manager button permission |
| user login logs read | `GET /api/admin/v1/users/login-logs/page-init`, `GET /api/admin/v1/users/login-logs` | bearer token |
| user sessions read/revoke | `GET /api/admin/v1/user-sessions/page-init`, `GET /api/admin/v1/user-sessions`, `GET /api/admin/v1/user-sessions/stats`, `PATCH /api/admin/v1/user-sessions/:id/revoke`, `PATCH /api/admin/v1/user-sessions/revoke` | read routes: bearer token; revoke routes: bearer token + `user_userManager_kick` |
| current user notifications | `GET/PATCH/DELETE /api/admin/v1/notifications...` | bearer token; current-user ownership only, no RBAC button permission |
| permission mutations | permissions create/update/status/delete | bearer token + `permission_permission_*` route permission |
| role mutations | roles create/update/default/delete | bearer token + `permission_role_*` route permission |
| auth platform mutations | auth-platforms create/update/status/delete | bearer token + `permission_authPlatform_*` route permission |
| user mutations | users update/status/batch/delete | bearer token + `user_userManager_*` route permission |
| operation log delete | operation-logs delete/batch delete | bearer token + `devTools_operationLog_del` route permission |
| system setting mutations | system-settings create/update/status/delete | bearer token + `system_setting_*` route permission |
| mail management mutations | mail config/test/template/log write routes | bearer token + `system_mail_*` route permission |
| upload config mutations | upload-drivers/upload-rules/upload-settings create/update/status/delete | bearer token + `system_uploadConfig_*` route permission |
| upload token create | `POST /api/admin/v1/upload-tokens` | bearer token; current-user upload capability, no RBAC button permission |
| notification task mutations | notification-tasks create/cancel/delete | bearer token + `system_notificationTask_*` route permission |
| current profile update | `PUT /api/admin/v1/profile` | bearer token; operation log only, no user-manager button permission |
| AI sidecar provider/agent/tool/knowledge management | ai-providers/ai-agents/ai-tools/ai-knowledge-bases/ai-knowledge-documents write routes | bearer token; mutation routes use explicit `ai_provider_*`, `ai_agent_*`, `ai_tool_*`, `ai_knowledge_*`, `ai_knowledge_document_*` route permissions and OperationLog metadata; secret fields are write-only/masked |
| AI sidecar runtime current-user | ai-conversations current-user CRUD, ai-conversations/:id/messages list/send, and ai-runs read monitor | bearer token; current-user ownership where applicable; message send requires an enabled chat-scene AI agent + provider and must fail explicitly when not configured |
| Retired AI legacy routes | legacy model/tool/prompt/agent/knowledge-base routes | not mounted in active Go runtime; only backup/rollback SQL, historical specs, or negative router tests may mention exact old route strings |

## Health / Readiness

状态：implemented。

```text
GET /health
GET /ready
```

`/health` 只证明进程活着，不访问 MySQL/Redis。

`/ready` 返回统一响应，`data.checks` 当前固定包含：

```text
database
redis
token_redis
queue_redis
realtime
```

规则：

```text
未配置的外部依赖返回 disabled，不算失败。
配置了的 MySQL/Redis/TokenRedis/QueueRedis 必须 ping 成功，否则 status=not_ready。
QUEUE_ENABLED=true 但 REDIS_ADDR 为空时 queue_redis=down。
REALTIME_ENABLED=true 但 REALTIME_PUBLISHER 是未实现值时 realtime=down。
```

通用错误：

```text
参数错误：HTTP 200 + code != 0，msg 说明字段或业务错误。
未登录/会话失效：AuthToken 拒绝请求。
无权限：PermissionCheck fail-closed。
资源不存在或已删除：service 返回明确业务错误，不做静默成功。
业务冲突：例如默认角色不能删除、admin 核心认证平台不能禁用或删除。
```

## Auth Public APIs

状态：implemented in Go backend, adapted in Vue frontend。

用途：登录配置、验证码、验证码登录、密码登录、refresh/logout 的认证边界。

### Login Config

`GET /api/admin/v1/auth/login-config`

Response example：

```json
{
  "code": 0,
  "data": {
    "login_type_arr": [
      { "label": "邮箱登录", "value": "email" },
      { "label": "手机登录", "value": "phone" },
      { "label": "密码登录", "value": "password" }
    ],
    "captcha_enabled": true,
    "captcha_type": "slide"
  },
  "msg": "ok"
}
```

规则：`login_type_arr` 顺序固定为 `email -> phone -> password`，由 Go enum/dict 派生，前端不手写 fallback。

### Send Code

`POST /api/admin/v1/auth/send-code`

Body：

```ts
type SendCodeBody =
  | { scene: 'login'; account: string }
  | { scene: 'forget'; account: string }
  | { scene: 'bind_phone'; account: string }
  | { scene: 'bind_email'; account: string }
  | { scene: 'change_password'; account: string }
```

Response example：

```json
{ "code": 0, "data": {}, "msg": "ok" }
```

规则：account 必须是合法邮箱或手机号；scene 由 Go `enum.VerifyCodeScenes` + `verify_code_scene` validator 派生。手机号验证码固定 `123456`，写 Redis 后返回成功，不接短信且不受 env 控制；邮箱账号生成随机验证码，写 Redis 后必须走 `internal/module/mail.SendVerifyCode` + 腾讯云 SES，发送失败要清理 Redis code。生产如果不开放手机号登录，在 `auth_platforms.login_types` 关闭 `phone`。

### Forgot Password

`POST /api/admin/v1/auth/forgot-password`

Body：

```ts
interface ForgotPasswordBody {
  account: string
  code: string
  new_password: string
  confirm_password: string
}
```

Response:

```json
{ "code": 0, "data": {}, "msg": "ok" }
```

规则：

```text
该接口是公共 auth 入口，不需要 bearer token。
验证码继续复用 POST /api/admin/v1/auth/send-code，scene 必须是 forget。
account 必须是当前 users.email 或 users.phone 中存在且未删除的账号。
用户必须处于启用状态。
成功后写入 users.password 的 PHP-compatible bcrypt hash，并消费 Redis 验证码。
前端必须使用 Go request 调用本接口，不允许再走 legacy /api/Users/forgetPassword。
新 Go 契约不接受 legacy 字段：newpassword、respassword、account_type。
```

错误：

```text
invalid account                            -> code 100 / 请输入正确的邮箱或手机号
missing account                            -> code 100 / 重置密码参数错误
invalid or expired verification code        -> code 100 / 验证码错误或已失效
password confirm mismatch                   -> code 100 / 两次输入的密码不一致
password length invalid                     -> code 100 / 密码长度必须为6-128位
missing user                                -> code 100 / 账号不存在
disabled user                               -> code 100 / 账号已被禁用，请联系管理员
```

### Captcha

`GET /api/admin/v1/auth/captcha?type=slide`

Response `data` 包含 go-captcha slide challenge；前端使用 `go-captcha-vue` 渲染，不自造滑块视觉。

### Login

`POST /api/admin/v1/auth/login`

Body：

```ts
type LoginBody =
  | {
      login_type: 'password'
      account: string
      password: string
      platform: 'admin'
      captcha_id: string
      captcha_answer: unknown
    }
  | {
      login_type: 'email' | 'phone'
      account: string
      code: string
      platform: 'admin'
    }
```

Response example：

```json
{
  "code": 0,
  "data": {
    "access_token": "string",
    "refresh_token": "string",
    "expires_in": 7200,
    "token_type": "Bearer"
  },
  "msg": "ok"
}
```

规则：

```text
密码登录必须通过 slide captcha。
验证码登录支持 allow_register 控制的自动注册。
access_token / refresh_token TTL 来自当前 platform 的 auth_platforms.access_ttl / auth_platforms.refresh_ttl；不是 .env。
access_token 是本系统签发的 JWT，只包含 sid/sub/platform/device_id/iat/nbf/exp/iss 这类最小 claims；refresh_token 是 opaque random string，数据库只保存 hash。前端不得解析 JWT 决定权限，权限仍以后端 users/me、RBAC 和菜单接口为准。
登录日志投递 auth:login-log:v1 到 critical queue；队列不可用时按已记录策略同步写库。
```

### Refresh / Logout

```text
POST /api/admin/v1/auth/refresh
POST /api/admin/v1/auth/logout
```

Refresh Body：

```ts
{ refresh_token: string }
```

Logout 需要 `Authorization: Bearer <access_token>`。

## RBAC Bootstrap

状态：implemented in Go backend, adapted in Vue frontend。

用途：登录后初始化当前后台用户、菜单树、动态路由、按钮权限和快捷入口。

```text
GET /api/admin/v1/users/me
GET /api/admin/v1/users/init
POST /api/Users/init                 # legacy-compatible adapter，返回同一份 data
```

Response `data`：

```ts
interface UserInitResponse {
  user_id: number
  username: string
  avatar: string
  role_name: string
  permissions: PermissionMenuItem[]
  router: DynamicRouteItem[]
  buttonCodes: string[]
  quick_entry: QuickEntryItem[]
}
```

Response example：

```json
{
  "code": 0,
  "data": {
    "user_id": 1,
    "username": "admin",
    "avatar": "",
    "role_name": "管理员",
    "permissions": [],
    "router": [],
    "buttonCodes": ["system_permission_add"],
    "quick_entry": []
  },
  "msg": "ok"
}
```

规则：

```text
permissions/router/buttonCodes/quick_entry 是稳定字段名，不加兜底别名。
show_menu 只控制菜单显示，不影响 router 页面权限真相。
BUTTON 授权由 Go service 自动带出父 PAGE 和祖先 DIR；前端不能猜。
前端按钮显隐只读 buttonCodes；API 放行只由 PermissionCheck 判断。
```

## Permission Definitions

状态：implemented in Go backend, adapted in Vue frontend。

用途：管理 admin/app 范围内的 DIR / PAGE / BUTTON 权限定义。

### Init

`GET /api/admin/v1/permissions/init`

Response `data.dict`：

```ts
interface PermissionInitDict {
  permission_tree: PermissionTreeNode[]
  permission_type_arr: Array<{ label: string; value: 1 | 2 | 3 }>
  permission_platform_arr: Array<{ label: string; value: 'admin' | 'app' }>
}
```

### List

`GET /api/admin/v1/permissions`

Query：

```ts
interface PermissionListQuery {
  platform: 'admin' | 'app'
  name?: string
  path?: string
  type?: 1 | 2 | 3
}
```

### Create / Update

```text
POST /api/admin/v1/permissions
PUT  /api/admin/v1/permissions/:id
```

Body：

```ts
interface PermissionMutationBody {
  platform: 'admin' | 'app'
  type: 1 | 2 | 3
  name: string
  parent_id: number
  icon?: string
  path?: string
  component?: string
  code?: string
  i18n_key?: string
  sort: number
  show_menu?: 1 | 2
}
```

Create example：

```json
{
  "platform": "admin",
  "type": 2,
  "name": "测试页面",
  "parent_id": 1,
  "icon": "Menu",
  "path": "/test/page",
  "component": "Main/test/page/index",
  "i18n_key": "menu.testPage",
  "sort": 100,
  "show_menu": 1
}
```

规则：

```text
DIR 只能挂根或 DIR；需要 i18n_key。
PAGE 只能挂根或 DIR；需要 path/component/i18n_key。
BUTTON 在 admin 平台只能挂 PAGE；需要 code。
show_menu 仅对 DIR/PAGE 有业务意义；BUTTON 固定不进菜单。
同平台 path/code/i18n_key 按类型做唯一约束校验。
```

### Status / Delete

```text
PATCH  /api/admin/v1/permissions/:id/status    body: { status: 1 | 2 }
DELETE /api/admin/v1/permissions/:id
DELETE /api/admin/v1/permissions               body: { ids: number[] }
```

规则：删除父节点时不能留下未删除子节点；批量删除子树要一次提交完整 ids。

## Users Management

状态：implemented in Go backend, adapted in Vue frontend for list/page-init/edit/batch-edit/delete/status/export submit。导出任务列表、状态统计、删除和 `user_list` worker runtime 已迁到 Go。

用途：后台用户管理页的字典初始化、列表筛选、安全字段编辑、资料批量修改、状态修改和软删除。

### Page Init

`GET /api/admin/v1/users/page-init`

注意：`GET /api/admin/v1/users/init` 只服务当前登录用户 bootstrap，不能复用成用户管理页字典接口。

Response `data.dict`：

```ts
interface UsersPageInitDict {
  roleArr: Array<{ label: string; value: number }>
  auth_address_tree: AddressTreeNode[]
  sexArr: Array<{ label: '未知' | '男' | '女'; value: 0 | 1 | 2 }>
  platformArr: Array<{ label: 'admin' | 'app'; value: 'admin' | 'app' }>
}

interface AddressTreeNode {
  id: number
  parent_id: number
  label: string
  value: number
  children?: AddressTreeNode[]
}
```

`auth_address_tree` 是地址大字典，Go 后端从 Redis `admin_go:dict:address:v1` 读取；缓存不存在、Redis 不可用或 payload 损坏时，回源 MySQL `address` 表并重建，不改变 response shape。

### List

`GET /api/admin/v1/users`

Query：

```ts
interface UsersListQuery {
  current_page: number
  page_size: number
  keyword?: string
  username?: string
  email?: string
  detail_address?: string
  address_id?: string // comma separated ids, e.g. "3,4"; no legacy address alias
  role_id?: number
  sex?: 0 | 1 | 2
  date?: string // "YYYY-MM-DD,YYYY-MM-DD"
}
```

Response `data`：

```ts
interface UsersListResponse {
  list: Array<{
    id: number
    username: string
    email: string
    phone: string
    avatar: string | null
    sex: 0 | 1 | 2
    sex_show: string
    role_id: number
    role_name: string
    bio: string
    address_show: string
    address_id: number
    detail_address: string
    status: 1 | 2
    created_at: string
  }>
  page: { page_size: number; current_page: number; total_page: number; total: number }
}
```

### Update / Status / Delete

```text
PUT    /api/admin/v1/users/:id
PATCH  /api/admin/v1/users/:id/status
DELETE /api/admin/v1/users/:id
DELETE /api/admin/v1/users          body: { ids: number[] }
```

Update Body：

```ts
interface UserUpdateBody {
  username: string
  avatar?: string
  role_id: number
  sex: 0 | 1 | 2
  address_id: number
  detail_address?: string
  bio?: string
}
```

Status Body：

```ts
{ status: 1 | 2 }
```

### Batch Profile Update

`PATCH /api/admin/v1/users`

Body：

```ts
type UserBatchProfileUpdateBody =
  | { ids: number[]; field: 'sex'; sex: 0 | 1 | 2 }
  | { ids: number[]; field: 'address_id'; address_id: number }
  | { ids: number[]; field: 'detail_address'; detail_address: string }
```

规则：

```text
新 Go 契约只接受 address_id，不接受 legacy address 别名。
编辑 role_id 后清理该用户 admin/app 平台 button grant cache。
列表查询使用 prefix LIKE，避免默认全模糊扫表。
用户删除是 users + user_profiles 软删除。
```

### Export Submit

```text
POST /api/admin/v1/users/export
Permission: user_userManager_export
OperationLog: module=user action=export title=用户导出
```

Request：

```ts
interface UserExportRequest {
  ids: number[]
}
```

Response `data`：

```ts
interface UserExportResponse {
  id: number
  message: string
}
```

规则：只接受显式勾选的正整数用户 id；service 去重后只导出未软删除用户。创建 `export_tasks` pending 记录后投递 `export:run:v1` 到 low queue；队列投递失败必须把任务标记 failed，不允许留下永久 pending。

## Current User Quick Entry

状态：implemented in Go backend, adapted in Vue frontend。

用途：首页“快捷入口”保存当前登录用户选择的后台页面权限。读取仍通过 `GET /api/admin/v1/users/init` 的稳定字段 `quick_entry` 返回。

```text
PUT /api/admin/v1/users/me/quick-entries
```

Request：

```ts
interface CurrentUserQuickEntrySaveRequest {
  permission_ids: number[]
}
```

Response `data`：

```ts
interface CurrentUserQuickEntrySaveResponse {
  quick_entry: Array<{
    id: number
    permission_id: number
    sort: number
  }>
}
```

Rules：

```text
Auth: bearer token only, current user owns the write.
No user-manager RBAC button permission; this is not editing another user.
permission_ids must be positive integers; service deduplicates while preserving order.
max count: 6.
accepted permission rows: permissions.platform=admin, type=PAGE(2), status=1, is_del=2.
write is transactional: soft-delete current user's old users_quick_entry rows, insert the new ordered rows, then return the current active rows.
response field name remains quick_entry; no quickEntry alias.
```

## User Login Logs

状态：implemented in Go backend, adapted in Vue frontend。

用途：后台用户登录日志页面的字典初始化和分页查询。

### Page Init

`GET /api/admin/v1/users/login-logs/page-init`

Response `data.dict`：

```ts
interface UserLoginLogPageInitResponse {
  dict: {
    platformArr: Array<{ label: string; value: 'admin' | 'app' | string }>
    login_type_arr: Array<{ label: string; value: 'email' | 'phone' | 'password' }>
  }
}
```

### List

`GET /api/admin/v1/users/login-logs`

Query：

```ts
interface UserLoginLogListQuery {
  current_page: number
  page_size: number
  user_id?: number
  login_account?: string
  login_type?: 'email' | 'phone' | 'password'
  ip?: string
  platform?: 'admin' | 'app'
  is_success?: 1 | 2
  date_start?: string // YYYY-MM-DD
  date_end?: string   // YYYY-MM-DD
}
```

Response `data`：

```ts
interface UserLoginLogListResponse {
  list: Array<{
    id: number
    user_id: number | null
    user_name: string
    login_account: string
    login_type: string
    login_type_name: string
    platform: string
    platform_name: string
    ip: string
    ua: string
    is_success: 1 | 2
    reason: string
    created_at: string
  }>
  page: { page_size: number; current_page: number; total_page: number; total: number }
}
```

Rules：

```text
source table: users_login_log AS l LEFT JOIN users AS u ON u.id = l.user_id AND u.is_del = 2.
l.is_del = 2.
login_account filter: prefix LIKE '<login_account>%'.
ip filter: prefix LIKE '<ip>%'.
date_start expands to 00:00:00; date_end expands to 23:59:59.
missing/deleted user returns user_name="" rather than hiding the log row.
page_size default: 20; max: enum.PageSizeMax.
```

## User Sessions

状态：implemented in Go backend, adapted in Vue frontend for `page-init` / `list` / `stats` / `revoke` / `batch revoke`。

用途：后台用户管理页的“登录会话/在线用户”列表、筛选字典、在线统计和踢下线。

Auth：

```text
Read routes: bearer token only.
Revoke routes: bearer token + user_userManager_kick.
OperationLog: revoke routes only.
```

### Page Init

`GET /api/admin/v1/user-sessions/page-init`

Response `data.dict`：

```ts
interface UserSessionPageInitResponse {
  dict: {
    platformArr: Array<{ label: string; value: 'admin' | 'app' }>
    statusArr: Array<{ label: string; value: 'active' | 'expired' | 'revoked' }>
  }
}
```

### List

`GET /api/admin/v1/user-sessions`

Query：

```ts
interface UserSessionListQuery {
  current_page: number
  page_size: number
  username?: string
  platform?: 'admin' | 'app'
  status?: 'active' | 'expired' | 'revoked'
}
```

Response `data`：

```ts
interface UserSessionListResponse {
  list: Array<{
    id: number
    user_id: number
    username: string
    platform: string
    platform_name: string
    device_id: string
    ip: string
    ua: string
    last_seen_at: string
    created_at: string
    expires_at: string
    refresh_expires_at: string
    revoked_at: string | null
    status: 'active' | 'expired' | 'revoked'
  }>
  page: { page_size: number; current_page: number; total_page: number; total: number }
}
```

Rules：

```text
source table: user_sessions LEFT JOIN users
is_del = 2
username filter: users.username LIKE '<username>%'
platform filter: exact admin/app only when provided
active: revoked_at IS NULL AND refresh_expires_at > now
expired: revoked_at IS NULL AND refresh_expires_at <= now
revoked: revoked_at IS NOT NULL
sort: active -> expired -> revoked, then last_seen_at DESC
page_size default: 20
page_size max: enum.PageSizeMax
current_page default: 1
response must not include access_token_hash or refresh_token_hash
```

### Stats

`GET /api/admin/v1/user-sessions/stats`

Response `data`：

```ts
interface UserSessionStatsResponse {
  total_active: number
  platform_distribution: Record<string, number> & {
    admin: number
    app: number
  }
}
```

Rules：

```text
active stats use refresh_expires_at, not access expires_at.
Always include admin and app keys even when count is zero.
No cache in this Go slice; correctness beats stale legacy stats.
```

### Revoke One

```text
PATCH /api/admin/v1/user-sessions/:id/revoke
Permission: user_userManager_kick
OperationLog: module=user_session action=revoke title=踢下线用户会话
```

Response `data`：

```ts
interface UserSessionRevokeResponse {
  id: number
  revoked: boolean
}
```

Rules：

```text
id must be a positive integer.
current AuthIdentity.SessionID cannot revoke itself; return code=100.
missing session returns 404.
already revoked session is idempotent: { id, revoked: false }.
new revoke sets user_sessions.revoked_at and clears Redis access token cache.
single-session pointer TOKEN_REDIS_PREFIX + cur_sess:<platform>:<user_id> is deleted only when its value equals this session id.
response must never include access_token_hash or refresh_token_hash.
```

### Batch Revoke

```text
PATCH /api/admin/v1/user-sessions/revoke
Permission: user_userManager_kick
OperationLog: module=user_session action=revoke_batch title=批量踢下线用户会话
```

Request：

```ts
interface UserSessionBatchRevokeRequest {
  ids: number[]
}
```

Response `data`：

```ts
interface UserSessionBatchRevokeResponse {
  count: number
  skipped_current: number
  skipped_already_revoked: number
}
```

Rules：

```text
ids are positive integers; service deduplicates.
max count: 100.
current AuthIdentity.SessionID is skipped, not revoked.
already revoked sessions are skipped.
only newly revoked sessions have Redis token/pointer cleanup attempted.
```

Legacy PHP `UserSession/kick` and `UserSession/batchKick` are no longer active frontend contracts. Do not reintroduce legacy POST action paths under Go REST.

## Export Tasks

状态：implemented in Go backend, adapted in Vue frontend for status-count/list/delete。worker 第一版只支持 `kind=user_list`，生成 `.xlsx` 并上传当前启用的 COS。

用途：当前登录用户查看自己的异步导出任务、按状态统计、软删除导出任务。

### Status Count

`GET /api/admin/v1/export-tasks/status-count`

Query：

```ts
interface ExportTaskStatusCountQuery {
  title?: string
  file_name?: string
}
```

Response `data` 固定按 `1,2,3` 返回：

```ts
type ExportTaskStatusCountResponse = Array<{
  label: '处理中' | '已完成' | '失败'
  value: 1 | 2 | 3
  num: number
}>
```

### List

`GET /api/admin/v1/export-tasks`

Query：

```ts
interface ExportTaskListQuery {
  current_page?: number
  page_size?: number
  status?: 1 | 2 | 3
  title?: string
  file_name?: string
}
```

Response `data`：

```ts
interface ExportTaskListResponse {
  list: Array<{
    id: number
    title: string
    file_name: string | null
    file_url: string | null
    file_size_text: string
    row_count: number | null
    status: 1 | 2 | 3
    status_text: '处理中' | '已完成' | '失败'
    error_msg: string | null
    expire_at: string | null
    created_at: string
  }>
  page: { page_size: number; current_page: number; total_page: number; total: number }
}
```

### Delete

```text
DELETE /api/admin/v1/export-tasks/:id
DELETE /api/admin/v1/export-tasks        body: { ids: number[] }
```

规则：status-count/list/delete 均按当前 token user scoped；查询前软删除过期任务；`title` 和 `file_name` 使用 prefix LIKE；删除只软删 `export_tasks`，不删除 COS 对象。导出 worker 的 queue payload 只放 `task_id/kind/user_id/platform/ids`，不放渲染后的 rows。

## Profile

状态：implemented in Go backend, adapted in Vue frontend for base profile、avatar upload and account security writes。

用途：当前后台用户查看/编辑个人资料；用户管理页跳转可只读查看指定用户资料。头像上传不是服务端转存，仍通过 shared upload client 调用 `POST /api/admin/v1/upload-tokens` 获取 COS 临时凭证。

### Read

```text
GET /api/admin/v1/profile
GET /api/admin/v1/users/:id/profile
```

Auth: bearer token。

Response `data`：

```ts
interface ProfileResponse {
  profile: {
    user_id: number
    username: string
    email: string
    avatar: string
    phone: string
    role_id: number
    role_name: string
    address_id: number
    detail_address: string
    sex: 0 | 1 | 2
    birthday: string
    bio: string
    is_self: 1 | 2
    has_password: boolean
  }
  dict: {
    auth_address_tree: AddressTreeNode[]
    sexArr: Array<{ label: '未知' | '男' | '女'; value: 0 | 1 | 2 }>
    verify_type_arr: Array<{ label: string; value: 'password' | 'code' }>
  }
}
```

地址字典来源：

```text
MySQL address 表是真相源。
Go user service 通过 Redis cache-aside 读取派生地址树。
Redis key: admin_go:dict:address:v1
TTL: none，redis TTL 期望为 -1。
Redis miss / Redis error / corrupt cache 会回源 MySQL 重建，不改变 response shape。
```

规则：

```text
is_self 只由 token user_id 和目标 user_id 服务端计算。
GET /profile 等价于读取当前 token 用户。
GET /users/:id/profile 用于用户管理跳转只读展示，不代表可编辑其他用户个人资料。
返回字段不提供 legacy address 别名，只提供 address_id。
```

### Update Current Profile

```text
PUT /api/admin/v1/profile
```

Auth: bearer token。OperationLog: `Module=profile`, `Action=update_profile`, `Title=编辑个人资料`。不挂 `user_userManager_edit`，用户编辑自己资料不需要用户管理按钮权限。

Body：

```ts
interface UpdateProfileBody {
  username: string
  avatar?: string
  sex: 0 | 1 | 2
  birthday?: string | null
  address_id: number
  detail_address?: string
  bio?: string
}
```

错误：

```text
address alias present / missing address_id -> code 100 / 参数错误
username empty after trim                  -> code 100 / 用户名不能为空
invalid sex                                -> code 100 / 无效的性别
invalid birthday                           -> code 100 / 生日格式错误
missing user                               -> code 404 / 用户不存在
```

### Account Security Writes

```text
PUT /api/admin/v1/profile/security/password
PUT /api/admin/v1/profile/security/email
PUT /api/admin/v1/profile/security/phone
```

Auth: bearer token。当前用户自己的账号安全设置只需要登录态，不挂 `user_userManager_edit`。三条写接口都记录 OperationLog：

```text
profile_security.update_password -> 修改登录密码
profile_security.update_email    -> 绑定或换绑邮箱
profile_security.update_phone     -> 绑定或换绑手机号
```

Password Body：

```ts
type UpdatePasswordBody =
  | {
      verify_type: 'password'
      old_password: string
      new_password: string
      confirm_password: string
    }
  | {
      verify_type: 'code'
      account: string
      code: string
      new_password: string
      confirm_password: string
    }
```

Email Body：

```ts
interface UpdateEmailBody {
  email: string
  code: string
}
```

Phone Body：

```ts
interface UpdatePhoneBody {
  phone: string
  code: string
}
```

Response:

```json
{ "code": 0, "data": {}, "msg": "ok" }
```

规则：

```text
verify_type 来自 enum/dict/validate 的 user_verify_type，只允许 password/code。
验证码继续复用 POST /api/admin/v1/auth/send-code；scene 必须分别是 bind_email、bind_phone、change_password。
password 验证方式校验当前旧密码。
code 改密方式要求 account 属于当前用户已绑定的 email 或 phone，再消费 change_password 验证码。
邮箱/手机号换绑先做格式、重复绑定、当前用户存在性校验，再消费验证码。
成功消费验证码后删除 Redis code key。
新 Go 契约不接受 legacy 字段：newpassword、respassword、account_type、address 等。
```

错误：

```text
invalid verify_type                         -> code 100 / 参数错误
password confirm mismatch                   -> code 100 / 两次输入的密码不一致
wrong old password                          -> code 100 / 旧密码错误
missing owned code account                  -> code 100 / 请先绑定邮箱或手机号
invalid or expired verification code        -> code 100 / 验证码错误或已过期
duplicate email                             -> code 100 / 邮箱已被绑定
duplicate phone                             -> code 100 / 手机号已被绑定
missing user                                -> code 404 / 用户不存在
```

## Roles

状态：implemented in Go backend, adapted in Vue frontend。

用途：管理角色和角色权限矩阵。当前模型是单用户单角色；没有隐藏 super admin bypass。

### Init / List

```text
GET /api/admin/v1/roles/init
GET /api/admin/v1/roles
```

List Query：

```ts
interface RoleListQuery {
  current_page: number
  page_size: number
  name?: string
}
```

Update example：

```json
{
  "name": "运营角色",
  "permission_id": [10, 11, 12]
}
```

List Response `data`：

```ts
interface RoleListResponse {
  list: Array<{
    id: number
    name: string
    permission_id: number[]
    is_default: 1 | 2
    created_at: string
    updated_at: string
  }>
  page: { page_size: number; current_page: number; total_page: number; total: number }
}
```

### Create / Update

```text
POST /api/admin/v1/roles
PUT  /api/admin/v1/roles/:id
```

Body：

```ts
interface RoleMutationBody {
  name: string
  permission_id: number[]
}
```

规则：

```text
role_permissions 只保存 PAGE/BUTTON。
提交 BUTTON 时 Go service 自动补父 PAGE。
提交 DIR 会被忽略，DIR 只由 PAGE/BUTTON 计算上下文时带出。
角色授权变更后清理绑定用户所有平台的 button grant cache。
```

### Set Default / Delete

```text
PATCH  /api/admin/v1/roles/:id/default
DELETE /api/admin/v1/roles/:id
DELETE /api/admin/v1/roles        body: { ids: number[] }
```

规则：默认角色不能删除；已绑定用户的角色不能删除。

## Operation Logs

状态：implemented in Go backend, adapted in Vue frontend。

用途：后台操作审计列表、按用户/动作/日期筛选，以及删除历史日志。

### Init

`GET /api/admin/v1/operation-logs/init`

当前返回空 `data`，保留为页面初始化契约位。

### List

`GET /api/admin/v1/operation-logs`

Query：

```ts
interface OperationLogListQuery {
  current_page: number
  page_size: number
  user_id?: number
  action?: string
  date?: string // "YYYY-MM-DD,YYYY-MM-DD"
}
```

Response `data`：

```ts
interface OperationLogListResponse {
  list: Array<{
    id: number
    user_name: string
    user_email: string
    action: string
    request_data: string | null
    response_data: string | null
    is_success: 1 | 2
    created_at: string
  }>
  page: { page_size: number; current_page: number; total_page: number; total: number }
}
```

规则：

```text
request_data / response_data 存的是 JSON 字符串摘要，不是 raw 结构体。
request_data 顶层是审计 envelope：method/path/module/action/request_id/client_ip/session_id/platform/latency_ms；真实入参在 `payload` 字段。
response_data 顶层是审计 envelope：status/success；真实接口响应在 `payload` 字段，业务 data 仍在 `payload.data`。
前端列表只能展示摘要，详情弹窗必须展示格式化 JSON；不能把 wrapper key 当成入参/出参本体。
敏感字段会在 Go backend 里遮蔽，至少包括 password/token/captcha/captcha_answer/code/secret_id/secret_key/secret_id_enc/secret_key_enc。
delete permission code 是 devTools_operationLog_del。
DELETE 只走 REST: /api/admin/v1/operation-logs/:id 和 /api/admin/v1/operation-logs body { ids: number[] }。
```

## Notifications

状态：implemented in Go backend, adapted in Vue frontend for current-user read/list/read/delete basics。

用途：当前登录用户的通知中心和首页通知卡片。该切片只处理用户自己的 `notifications` 读路径和已读/删除动作，不迁移 `notification_task` 发布任务，也不声明 WebSocket 业务推送已经实现。

### Init

`GET /api/admin/v1/notifications/init`

Auth: bearer token.

Response `data.dict`：

```ts
interface NotificationInitDict {
  notification_type_arr: Array<{ label: string; value: 1 | 2 | 3 | 4 }>
  notification_level_arr: Array<{ label: string; value: 1 | 2 }>
  notification_read_status_arr: Array<{ label: string; value: 1 | 2 }>
}
```

字典由 Go `internal/enum` -> `internal/dict` 派生：

```text
type:  1 普通 / 2 成功 / 3 警告 / 4 错误
level: 1 普通 / 2 紧急
read:  1 已读 / 2 未读
```

### List

`GET /api/admin/v1/notifications`

Query：

```ts
interface NotificationListQuery {
  current_page: number
  page_size: number
  keyword?: string
  type?: 1 | 2 | 3 | 4
  level?: 1 | 2
  is_read?: 1 | 2
}
```

Response `data`：

```ts
interface NotificationListResponse {
  list: Array<{
    id: number
    title: string
    content: string
    type: number
    type_text: string
    level: number
    level_text: string
    link: string
    is_read: 1 | 2
    created_at: string
  }>
  page: { page_size: number; current_page: number; total_page: number; total: number }
}
```

Rules:

```text
只返回当前 token 用户自己的通知：user_id = auth_identity.user_id。
平台范围固定为 session platform + all：platform IN(current_platform, 'all')。
只读未软删数据：is_del = 2。
keyword 是 title prefix search，不做全表任意模糊扫描。
排序固定 id desc。
```

### Unread count

`GET /api/admin/v1/notifications/unread-count`

Auth: bearer token.

Response:

```ts
interface NotificationUnreadCountResponse {
  count: number
}
```

### Mark read / Delete

```text
PATCH  /api/admin/v1/notifications/:id/read
PATCH  /api/admin/v1/notifications/read      body: { ids: number[] } or { ids: [] } for mark all visible unread notifications
DELETE /api/admin/v1/notifications/:id
DELETE /api/admin/v1/notifications           body: { ids: number[] }
```

Rules:

```text
所有 write 都必须带 user_id + platform scope + is_del=2 条件，不能修改别人的通知。
PATCH /read 的空 ids 表示把当前用户、当前 platform 可见的全部未读通知标记已读。
DELETE 不接受空 ids；删除是软删除 is_del=1。
这些 current-user routes 不挂 RBAC button permission。
这些 read/delete 动作当前不写 operation log；如果未来要审计，必须加显式 route metadata，不能靠反射或隐式猜测。
```

## Admin Chat Room

状态：removed from current admin scope on 2026-05-07 by product decision.

Active Go API no longer includes `/api/admin/v1/chat...` endpoints. The admin chat frontend page, typed API client, Pinia store, tests, menu i18n, Go module, route registration, and bootstrap wiring are removed.

DB cleanup is destructive and explicit: `admin_back_go/database/migrations/20260507_remove_admin_chat.sql` removes the admin chat permission/menu grants and drops `chat_messages`, `chat_participants`, `chat_contacts`, and `chat_conversations`.

AI chat is a separate AI module and remains active under `admin_front_ts/src/views/Main/ai/chat`, `admin_front_ts/src/api/ai/chat.ts`, and the `ai_chat_images` upload folder.

## AI Core Provider Config / Local Runtime Surface

状态：provider config slice、智能体配置 MVP、AI 对话 WebSocket MVP、运行监控 token-only MVP、AI tool runtime MVP、AI Knowledge Base RAG MVP are implemented for OpenAI-first local runtime.

本节替代旧 AI 配置契约。旧模型/提示词/知识库产品面、旧工具映射概念和 legacy app 命名已经不是 active provider/agent/tool contract；`ai_agents` 是当前智能体配置事实源，`ai_tools` 是当前工具定义事实源。当前产品方向是 admin_go 自有页面 + 服务端 provider boundary，不嵌入第三方控制台，不把外部 key 暴露给浏览器。

Hard boundaries:

```text
Vue -> admin_go REST/WebSocket only; Vue never calls an AI provider directly.
Provider API keys stay server-side, encrypted at write boundary and masked in DTOs.
internal/module/* does not import provider SDKs/clients; provider calls go through internal/platform/ai boundaries.
admin_go owns users, RBAC, menus, operation logs, REST contracts, WebSocket envelopes, local conversations, messages, runs, agent metadata, local knowledge bases, and knowledge retrieval audit rows.
The first provider-config driver is exactly openai.
No iframe console embedding, no browser SSE/EventSource provider stream.
```

Retired active endpoints and menu routes are the old model/tool/prompt/knowledge-base REST resources plus legacy ai-app/app naming. Active contract docs intentionally do not keep the exact old strings; those exact strings may appear only in backup/rollback SQL, historical superpowers docs, or negative router tests that assert the routes are not installed.

## AI Engine Connections / Provider Config

状态：implemented for the first AI menu, product name “供应商配置”. The physical table name stays `ai_providers` for compatibility until all six AI menus are migrated.

```text
GET    /api/admin/v1/ai-providers/page-init
GET    /api/admin/v1/ai-providers
POST   /api/admin/v1/ai-providers/model-options
POST   /api/admin/v1/ai-providers
PUT    /api/admin/v1/ai-providers/:id
PATCH  /api/admin/v1/ai-providers/:id/status
POST   /api/admin/v1/ai-providers/:id/model-options
POST   /api/admin/v1/ai-providers/:id/test
POST   /api/admin/v1/ai-providers/:id/sync-models
GET    /api/admin/v1/ai-providers/:id/models
PUT    /api/admin/v1/ai-providers/:id/models
DELETE /api/admin/v1/ai-providers/:id
```

Rules:

- tables: `ai_providers`, `ai_provider_models`
- `engine_type` / `driver` first slice supports only `openai`
- empty `base_url` means `https://api.openai.com/v1`
- model discovery calls `GET {effective_base_url}/models` with `Authorization: Bearer <api_key>`
- create/edit preview `POST /model-options` uses the request API key; edit preview `POST /:id/model-options` uses the saved encrypted API key and does not write sync/health state
- provider models are persisted in `ai_provider_models`; selected model ids, display names, and model status are first-class columns, not JSON blobs
- `ai_provider_models` is a current selectable model snapshot table, not history; replace writes hard-delete the provider's old snapshot rows and insert the current list
- `ai_provider_models` must not store `raw_json`, `source`, `is_del`, `created_by`, or `updated_by`
- `ai_providers` must not store provider-specific dumping-ground `config_json`, `created_by`, or `updated_by`; provider-specific knobs need an explicit future contract
- provider config has no default model concept; 智能体配置 owns concrete model selection
- create requires provider name, `openai` driver, API key, and at least one model
- update with empty `api_key` keeps the existing encrypted key; non-empty `api_key` rewrites `api_key_enc` and `api_key_hint`
- plaintext API key is write-only; responses, OperationLog payloads, smoke output, and frontend storage must never expose plaintext or encrypted secret blobs, remote raw model payloads, source markers, or provider config JSON blobs
- health and model-sync status values are `unknown`, `ok`, and `failed`
- delete is soft delete and must reject active dependent agents/maps when that would create orphan runtime config

## AI Agents / Agents

状态：implemented MVP. This page is now the active `agent` configuration slice, not an app-mapping shell.

```text
GET    /api/admin/v1/ai-agents/page-init
GET    /api/admin/v1/ai-agents
GET    /api/admin/v1/ai-agents/options
GET    /api/admin/v1/ai-agents/provider-models/:id
GET    /api/admin/v1/ai-agents/:id
POST   /api/admin/v1/ai-agents
PUT    /api/admin/v1/ai-agents/:id
PATCH  /api/admin/v1/ai-agents/:id/status
POST   /api/admin/v1/ai-agents/:id/test
DELETE /api/admin/v1/ai-agents/:id
```

Rules:

- table: `ai_agents`
- local agent is the admin_go “智能体” entry
- `provider_id` points to the local provider row
- create/update require a concrete `model_id` selected from enabled `ai_provider_models` under the selected provider
- `model_display_name` is denormalized from the selected provider model for list display
- list query supports `scene=chat` and `scene=agent_generate`; there is no agent code or agent type filter in the MVP
- MVP scene field is `scenes`; current allowed values are `chat` and `agent_generate`; empty internal input normalizes to `["chat"]`
- MVP form fields are name, model cascader, scenes, status, optional system prompt, and optional avatar
- `ai_agents` deliberately does not store agent code, agent type, per-agent external app ids, per-agent API keys, response mode, runtime config JSON, model snapshot JSON, `created_by`, or `updated_by`; those are future contracts, not MVP columns
- runtime uses the selected agent plus its provider credentials; per-agent credential override is not part of this slice
- `GET /ai-agents/options` feeds chat/runtime selectors and returns only enabled `chat` scene agent id/name/avatar/system_prompt facts; `agent_generate` is for the next AI-generated-agent flow and does not enter the chat selector by default
- `GET /ai-agents/page-init` returns `scene_arr` and `provider_model_options`; `GET /ai-agents/provider-models/:id` refreshes enabled models for a provider
- `agent_id` / `agent_name` are the canonical AI runtime selector fields; old app aliases must not drive new DB queries or new Vue state

## AI Conversations

状态：implemented MVP for the “对话” slice. This slice owns only `ai_conversations` and `ai_messages`; run monitor is implemented as a separate token-only read slice.

```text
GET    /api/admin/v1/ai-conversations
GET    /api/admin/v1/ai-conversations/:id
POST   /api/admin/v1/ai-conversations
PUT    /api/admin/v1/ai-conversations/:id
DELETE /api/admin/v1/ai-conversations/:id
```

Rules:

- table: `ai_conversations`
- physical columns are only `id`, `user_id`, `agent_id`, `title`, `last_message_at`, `is_del`, `created_at`, `updated_at`
- canonical relationship is `agent_id -> ai_agents.id`; active code must not join `ai_apps`
- current-user scoped: list/detail/update/delete reject conversations owned by another user
- list uses cursor inputs `agent_id`, `before_id`, `limit`; no page/status/title archive contract in MVP
- list order is `last_message_at desc, id desc`, with empty `last_message_at` last
- update only renames `title`; blank title is rejected
- every user message insert and assistant completion updates `last_message_at`; frontend uses it for sort/display
- delete is soft delete (`is_del=1`) and also marks child messages deleted in the same transaction
- responses do not expose `user_id`, `is_del`, `status`, provider conversation ids, token fields, or run ids

## AI Messages

状态：implemented for conversation-scoped chat messages with the restored old-admin input surface. Transport remains WebSocket-only for assistant output.

```text
GET  /api/admin/v1/ai-conversations/:id/messages
POST /api/admin/v1/ai-conversations/:id/messages
POST /api/admin/v1/ai-conversations/:id/messages/cancel
```

Rules:

- table: `ai_messages`
- physical columns are `id`, `conversation_id`, `role`, `content_type`, `content`, `meta_json`, `is_del`, `created_at`, `updated_at`
- message ownership is checked through the owning conversation and current user
- `content_type` is mandatory; current chat writes `text`
- `meta_json` stores explicit message extensions only: `attachments`, `runtime_params`, and later-renderable `blocks` / `feedback`; it is not a dump bucket for hidden provider state
- message history uses cursor inputs `before_id`, `limit`; no offset page contract
- send body is `{ content, request_id, attachments?, runtime_params? }`; `content` may be empty only when at least one uploaded image attachment exists
- `attachments` currently supports up to 5 image objects `{ type:"image", url, name, size }`
- `runtime_params` currently accepts `temperature`, `max_tokens`, and `max_history`; unknown keys are rejected instead of silently ignored
- send response is `{ conversation_id, user_message_id, request_id }`
- cancel body is `{ request_id }`; response is `{ conversation_id, request_id, status:"canceled" }`
- send accepts only conversations whose agent is enabled and has `chat` in `scenes_json`
- assistant replies are delivered by WebSocket events and persisted as one final assistant message after completion
- no edit, delete-message, batch-delete, tool-call, RAG, token, provider message id, status, `user_id`, or `run_id` fields in this slice

## AI Chat Runtime

状态：implemented as internal conversation reply executor only. There are no active `/api/admin/v1/ai-chat/*` HTTP routes in the conversation MVP.

Active send flow:

```text
POST /api/admin/v1/ai-conversations/:id/messages
admin-api in-process conversation reply dispatcher
WebSocket /api/admin/v1/realtime/ws -> ai.response.*.v1
```

Runtime rules:

- Vue starts chat by creating/selecting an `ai_conversations` row and posting a text message to `/:id/messages`
- `aimessage` persists the user message plus explicit `meta_json`, updates `last_message_at`, generates title from the first user message when title is empty, then hands off to the API-process reply dispatcher
- `aichat` executes the reply through `internal/platform/ai.Engine` using recent conversation messages, selected agent prompt, optional image attachments, and allowed runtime parameters
- `ai:conversation-reply:v1` remains a registered worker task type, but it is not the active browser chat MVP handoff path; the API process owns the immediate reply execution so local WebSocket conversations do not depend on a separately running worker
- `POST /messages/cancel` cancels the matching in-process reply context by `conversation_id + request_id`; late WebSocket events for a locally canceled request must be ignored by the browser
- provider stream is consumed only inside Go and converted to admin_go WebSocket envelopes; the browser never receives provider stream directly
- AI chat streaming timeout is layered: provider stream reads do not use a 30s total HTTP timeout; live reply max duration is controlled by `AI_CHAT_STREAM_MAX_DURATION`; upstream silence is controlled by `AI_CHAT_STREAM_IDLE_TIMEOUT`; `ai_run_timeout` only marks stale running rows older than `AI_RUN_STALE_TIMEOUT`
- OpenAI-compatible Chat Completions requests set `stream_options.include_usage=true`; token usage is written to existing `prompt_tokens`, `completion_tokens`, and `total_tokens` fields when the provider returns usage
- before the first provider call, `aichat` invokes the local knowledge runtime for the selected agent; enabled `ai_agent_knowledge_bases` bindings may inject selected knowledge context into the current user content and persist retrieval audit rows
- knowledge retrieval failure is non-blocking for chat: the run records a `knowledge_failed` event and continues without knowledge context
- browser realtime is WebSocket-only: `ai.response.start.v1`, `ai.response.delta.v1`, `ai.response.completed.v1`, `ai.response.failed.v1`
- all AI response payloads are conversation-scoped and must not contain `run_id`
- removed from active chat slice: `/api/admin/v1/ai-chat/runs`, `/api/admin/v1/ai-chat/runs/:run_id/events`, `/api/admin/v1/ai-chat/runs/:run_id/cancel`, `/api/admin/v1/ai-chat/messages`
- no SSE, EventSource, streamable HTTP fallback, or browser-direct tool/RAG execution path in this slice

## AI Runs Monitor

状态：implemented token-only MVP.

```text
GET /api/admin/v1/ai-runs/page-init
GET /api/admin/v1/ai-runs
GET /api/admin/v1/ai-runs/:id
GET /api/admin/v1/ai-runs/stats
GET /api/admin/v1/ai-runs/stats/by-date
GET /api/admin/v1/ai-runs/stats/by-agent
GET /api/admin/v1/ai-runs/stats/by-user
```

Rules:

- lifecycle tables: `ai_runs`, `ai_run_events`; there is no daily aggregate table in this MVP
- tool execution audit is owned by `ai_tool_calls` and appears only on run detail as `tool_calls`; lifecycle events stay in `ai_run_events`
- one `ai_runs` row represents one assistant reply attempt for one persisted user message
- run source is conversation/agent/provider centric: `ai_runs.conversation_id`, `ai_runs.user_message_id`, `ai_runs.assistant_message_id`, `ai_runs.agent_id`, `ai_runs.provider_id`, `ai_runs.model_id`, and `ai_runs.model_display_name`
- status is string-based runtime state: `running`, `success`, `failed`, `canceled`, `timeout`; there is no fake `pending` state
- event types are lifecycle-only: `start`, `completed`, `failed`, `canceled`, `timeout`; WebSocket delta is not persisted as events
- stats aggregate only `ai_runs` token and duration fields: total runs, success rate, failed terminal count, prompt/completion/total tokens, and average duration
- token-only means no billing amount, no provider task ids, no input/output snapshots, no raw usage dumps, and no execution-step timeline
- these read routes are bearer-token protected and must not expose prompt secrets, encrypted API keys, raw provider credentials, or hidden provider payloads

`GET /api/admin/v1/ai-runs/page-init` returns:

```ts
interface AiRunInitResponse {
  dict: {
    status_arr: Array<{ label: string; value: 'running' | 'success' | 'failed' | 'canceled' | 'timeout' }>
    agentArr: Array<{ label: string; value: number }>
    providerArr: Array<{ label: string; value: number }>
  }
}
```

`GET /api/admin/v1/ai-runs` query:

```ts
interface AiRunListQuery {
  current_page?: number
  page_size?: number
  status?: 'running' | 'success' | 'failed' | 'canceled' | 'timeout'
  user_id?: number
  request_id?: string
  agent_id?: number
  provider_id?: number
  date_start?: string
  date_end?: string
}
```

List item:

```ts
interface AiRunItem {
  id: number
  request_id: string
  user_id: number
  agent_id: number
  agent_name: string
  provider_id: number
  provider_name: string
  conversation_id: number
  conversation_title: string
  status: 'running' | 'success' | 'failed' | 'canceled' | 'timeout'
  status_name: string
  model_id: string
  model_display_name: string
  prompt_tokens: number
  completion_tokens: number
  total_tokens: number
  duration_ms: number | null
  duration_text: string
  error_message: string
  created_at: string
}
```

Detail adds:

```ts
interface AiRunDetailResponse extends AiRunItem {
  username: string
  user_message: {
    id: number
    role: number
    content_type: string
    content: string
    meta_json: object
    created_at: string
  } | null
  assistant_message: {
    id: number
    role: number
    content_type: string
    content: string
    meta_json: object
    created_at: string
  } | null
  events: Array<{
    id: number
    seq: number
    event_type: 'start' | 'completed' | 'failed' | 'canceled' | 'timeout'
    message: string
    created_at: string
  }>
  knowledge_retrievals: Array<{
    id: number
    run_id: number
    query: string
    status: 'success' | 'failed' | 'skipped'
    status_name: string
    total_hits: number
    selected_hits: number
    duration_ms: number | null
    duration_text: string
    error_message: string
    created_at: string
    hits: Array<{
      id: number
      knowledge_base_id: number
      knowledge_base_name: string
      document_id: number
      document_title: string
      chunk_id: number
      chunk_index: number
      score: number
      rank_no: number
      content_snapshot: string
      status: 1 | 2
      status_name: string
      skip_reason: string
      created_at: string
    }>
  }>
  tool_calls: Array<{
    id: number
    tool_id: number
    tool_code: string
    tool_name: string
    call_id: string | null
    status: 'running' | 'success' | 'failed' | 'timeout'
    arguments_json: object
    result_json: object | null
    error_message: string
    duration_ms: number | null
    started_at: string
    finished_at: string
  }>
  started_at: string
  finished_at: string
  updated_at: string
}
```

Stats summary:

```ts
interface AiRunStatsSummary {
  total_runs: number
  success_rate: number
  fail_runs: number
  total_tokens: number
  total_prompt_tokens: number
  total_completion_tokens: number
  avg_duration_ms: number
}
```

## AI Knowledge Base RAG MVP

状态：implemented. Active truth source is local MySQL-backed RAG tables, not Dify/provider datasets and not the retired `ai_knowledge_maps` contract.

```text
GET    /api/admin/v1/ai-knowledge-bases/page-init
GET    /api/admin/v1/ai-knowledge-bases
GET    /api/admin/v1/ai-knowledge-bases/:id
POST   /api/admin/v1/ai-knowledge-bases
PUT    /api/admin/v1/ai-knowledge-bases/:id
PATCH  /api/admin/v1/ai-knowledge-bases/:id/status
DELETE /api/admin/v1/ai-knowledge-bases/:id
GET    /api/admin/v1/ai-knowledge-bases/:id/documents
POST   /api/admin/v1/ai-knowledge-bases/:id/documents
GET    /api/admin/v1/ai-knowledge-documents/:id
PUT    /api/admin/v1/ai-knowledge-documents/:id
PATCH  /api/admin/v1/ai-knowledge-documents/:id/status
DELETE /api/admin/v1/ai-knowledge-documents/:id
POST   /api/admin/v1/ai-knowledge-documents/:id/reindex
GET    /api/admin/v1/ai-knowledge-documents/:id/chunks
POST   /api/admin/v1/ai-knowledge-bases/:id/retrieval-tests
GET    /api/admin/v1/ai-agents/:id/knowledge-bases
PUT    /api/admin/v1/ai-agents/:id/knowledge-bases
```

Tables:

```text
ai_knowledge_bases
ai_knowledge_documents
ai_knowledge_chunks
ai_agent_knowledge_bases
ai_knowledge_retrievals
ai_knowledge_retrieval_hits
```

Rules:

- `ai_knowledge_bases` stores local knowledge-base configuration: `name`, `code`, `description`, chunk settings, default retrieval settings, `status`, `is_del`, timestamps. Every field is used by CRUD, chunking, retrieval defaults, or filtering.
- `ai_knowledge_documents` stores editable source text and indexing state. Documents are filtered by `knowledge_base_id`, `status=1`, `is_del=2`, and `index_status='indexed'` at runtime.
- `ai_knowledge_chunks` stores deterministic text chunks. Runtime retrieval reads `title`, `content`, and `content_chars`; monitor hit snapshots are copied from chunk rows.
- `ai_agent_knowledge_bases` is the only place that says which knowledge bases an agent may read. Do not add JSON knowledge fields to `ai_agents`.
- Binding options `top_k`, `min_score`, and `max_context_chars` are runtime controls. Explicit `min_score=0` is valid and must not be replaced by a default.
- `ai_knowledge_retrievals` records one retrieval attempt per run when a bound agent triggers RAG. `status` is `success`, `failed`, or `skipped`.
- `ai_knowledge_retrieval_hits` snapshots every selected or skipped hit with score, rank, content snapshot, and skip reason. Run monitor must read this table instead of joining current chunks for historical content.
- Retrieval is a local deterministic MVP: SQL narrows active chunks by bound knowledge bases, Go scores title/content text matches, then applies `top_k`, `min_score`, and `max_context_chars`. No external vector DB, hosted file_search, Dify/RAGFlow dataset sync, OCR, or hidden provider dataset is part of this slice.
- Runtime injection format uses `[K1]`, `[K2]` references and prepends knowledge context only to the current provider call. It does not mutate `ai_agents.system_prompt` and does not rewrite persisted user message content.
- `GET /api/admin/v1/ai-runs/:id` includes `knowledge_retrievals` when retrieval was attempted. This is separate from `tool_calls`; retrieval records are written before the model call and hit records snapshot selected/skipped chunks.
- Permission mapping: base mutations use `ai_knowledge_add`, `ai_knowledge_edit`, `ai_knowledge_status`, `ai_knowledge_del`; document mutations use `ai_knowledge_document_add`, `ai_knowledge_document_edit`, `ai_knowledge_document_status`, `ai_knowledge_document_del`; reindex uses `ai_knowledge_reindex`; retrieval test uses `ai_knowledge_retrieval_test`; agent knowledge binding save uses `ai_agent_binding_add`.

Request/response highlights:

```ts
interface AiKnowledgeBaseItem {
  id: number
  name: string
  code: string
  description: string
  chunk_size_chars: number
  chunk_overlap_chars: number
  default_top_k: number
  default_min_score: number
  default_max_context_chars: number
  status: 1 | 2
  status_name: string
  created_at: string
  updated_at: string
}

interface AiKnowledgeDocumentItem {
  id: number
  knowledge_base_id: number
  title: string
  source_type: 'text' | 'markdown' | 'file'
  source_ref: string
  index_status: 'pending' | 'indexed' | 'failed'
  error_message: string
  last_indexed_at: string
  status: 1 | 2
  status_name: string
}

interface AiAgentKnowledgeBindingItem {
  id?: number
  knowledge_base_id: number
  knowledge_base_name: string
  top_k: number
  min_score: number
  max_context_chars: number
  status: 1 | 2
}
```

## AI Tools Runtime MVP

状态：implemented. Active truth source is exactly `ai_tools` + `ai_agent_tools` + `ai_tool_calls`; old tool-map metadata is retired from active runtime.

```text
GET    /api/admin/v1/ai-tools/page-init
GET    /api/admin/v1/ai-tools/generate/page-init
GET    /api/admin/v1/ai-tools
POST   /api/admin/v1/ai-tools/generate-draft
POST   /api/admin/v1/ai-tools
PUT    /api/admin/v1/ai-tools/:id
PATCH  /api/admin/v1/ai-tools/:id/status
DELETE /api/admin/v1/ai-tools/:id
GET    /api/admin/v1/ai-agents/:id/tools
PUT    /api/admin/v1/ai-agents/:id/tools
```

Rules:

- tables: `ai_tools`, `ai_agent_tools`, `ai_tool_calls`
- first server-backed tool code: `admin_user_count`; read-only, low risk, returns only `total_users`, `enabled_users`, `disabled_users`
- tool definition fields are all runtime-visible: `code` becomes provider function name, `parameters_json` becomes function schema, `timeout_ms` bounds server runtime, `result_schema_json` documents monitor/debug output shape
- `GET /ai-tools/generate/page-init` returns enabled `agent_generate` scene agents; `POST /ai-tools/generate-draft` calls the selected agent and returns a draft only
- `generate-draft` never inserts `ai_tools`; final persistence still uses `POST /api/admin/v1/ai-tools` after the admin reviews the generated fields
- generated drafts contain only `name`, `code`, `description`, `parameters_json`, `result_schema_json`, `risk_level`, `timeout_ms`, `status`, `warnings`, `clarifying_questions`, and optional token `usage`
- if a generated `code` has no registered Go executor, backend forces `status=2` and returns warning `该工具编码暂未注册服务端实现，已默认禁用`
- `/ai-tools/page-init`, list, create, and update do not expose or accept an executor field; there is no `ai_tools.executor` column because `code` is the single tool identity and server dispatch key
- disabled tool definitions can be stored before the matching server implementation exists; enabling or saving an enabled tool rejects a `code` that is not registered in the server runtime
- `/ai/tools` and `/api/admin/v1/ai-tools/*` manage tool definitions only; selecting which tools an agent can use is an agent configuration action under `/ai/agents` and `/api/admin/v1/ai-agents/:id/tools`
- bindings live in `ai_agent_tools`; do not add duplicate `tool_ids_json` or `tools_enabled` fields to `ai_agents`
- tool execution audit lives in `ai_tool_calls`; run detail returns `tool_calls`, while `ai_run_events` stays lifecycle-only
- MVP auto-executes only low-risk local server-backed tools; external HTTP/MCP/RAG/write tools need separate specs

## AI Run Timeout Worker

状态：implemented in Go worker registry.

```text
cron_task.name=ai_run_timeout
registry task type=ai:run-timeout:v1
queue handler=aichat.TimeoutRuns
```

Rules:

- cron row remains DB-owned through System Cron Tasks, but executable truth comes from the Go registry
- worker marks only stale `running` rows as `timeout`: `status='running' AND started_at IS NOT NULL AND started_at < now - AI_RUN_STALE_TIMEOUT`
- online stream max duration and upstream idle timeout are handled by the live `admin-api` reply execution path, not by this cron task
- default smoke checks registry/list shape; it does not create a long-running AI run just to time it out

## Notification Tasks

状态：implemented in Go backend, adapted in Vue frontend。

用途：后台通知发布任务管理。它不是当前用户通知 inbox，而是管理端创建 `notification_task`，由 `admin-worker` 通过 Asynq + gocron/v2 发送到 `notifications`。

### Init

`GET /api/admin/v1/notification-tasks/init`

Auth: bearer token.

Response `data.dict`：

```ts
interface NotificationTaskInitDict {
  notification_type_arr: Array<{ label: string; value: 1 | 2 | 3 | 4 }>
  notification_level_arr: Array<{ label: string; value: 1 | 2 }>
  notification_target_type_arr: Array<{ label: string; value: 1 | 2 | 3 }>
  notification_task_status_arr: Array<{ label: string; value: 1 | 2 | 3 | 4 }>
  platformArr: Array<{ label: string; value: 'all' | 'admin' | 'app' }>
}
```

字典由 Go `internal/enum` -> `internal/dict` 派生：

```text
type:        1 普通 / 2 成功 / 3 警告 / 4 错误
level:       1 普通 / 2 紧急
target_type: 1 全部用户 / 2 指定用户 / 3 指定角色
status:      1 待发送 / 2 发送中 / 3 已完成 / 4 失败
platform:    all / admin / app，all 必须排第一
```

### Status count

`GET /api/admin/v1/notification-tasks/status-count?title=`

Auth: bearer token.

Response `data` 按 status enum 顺序返回：

```ts
Array<{ label: string; value: 1 | 2 | 3 | 4; num: number }>
```

### List

`GET /api/admin/v1/notification-tasks`

Query：

```ts
interface NotificationTaskListQuery {
  current_page: number
  page_size: number
  status?: 1 | 2 | 3 | 4
  title?: string
}
```

Response `data`：

```ts
interface NotificationTaskListResponse {
  list: Array<{
    id: number
    title: string
    content: string
    type: 1 | 2 | 3 | 4
    type_text: string
    level: 1 | 2
    level_text: string
    link: string
    platform: 'all' | 'admin' | 'app'
    platform_text: string
    target_type: 1 | 2 | 3
    target_type_text: string
    status: 1 | 2 | 3 | 4
    status_text: string
    total_count: number
    sent_count: number
    send_at: string | null
    error_msg: string | null
    created_at: string
  }>
  page: { page_size: number; current_page: number; total_page: number; total: number }
}
```

Rules：

```text
只读 notification_task.is_del=2。
title 是 prefix search，不做全表任意模糊扫描。
排序固定 id desc。
```

### Create

`POST /api/admin/v1/notification-tasks`

Auth: bearer token + `system_notificationTask_add`。

Body：

```ts
interface NotificationTaskCreateBody {
  title: string
  content?: string
  type?: 1 | 2 | 3 | 4
  level?: 1 | 2
  link?: string
  platform?: 'all' | 'admin' | 'app'
  target_type: 1 | 2 | 3
  target_ids?: number[]
  send_at?: string // YYYY-MM-DD HH:mm:ss; empty = immediate
}
```

Response：

```ts
interface NotificationTaskCreateResponse {
  id: number
  queued: boolean
}
```

Rules：

```text
target_type=1 时服务端清空 target_ids。
target_type=2/3 时 target_ids 必须非空，并按正整数去重排序。
type 默认 1，level 默认 1，platform 默认 all。
send_at 空：写 task 后 enqueue notification:send-task:v1，queued=true。
send_at 非空：只写 pending task，queued=false，等待 scheduler。
created_by 来自 AuthToken identity.user_id，不接受前端传 created_by。
DB 写入 + Redis enqueue 当前不是强事务；enqueue 失败会返回明确错误，任务仍留 pending。`cron_task.name=notification_task_scheduler` 对应的 Go registry 会补偿 `send_at IS NULL` 的立即 pending 任务和到期定时任务。后续强一致用 outbox。
注意：后台如果有旧的 `admin-worker-smoke.exe` 或未重启 worker，可能不包含 notification:send-task:v1 handler，任务会停在 pending 或进入 Asynq archived。运行真实发布前必须启动当前代码的 `go run ./cmd/admin-worker`。
```

### Cancel / Delete

```text
PATCH  /api/admin/v1/notification-tasks/:id/cancel
DELETE /api/admin/v1/notification-tasks/:id
```

Auth：

```text
PATCH cancel: bearer token + system_notificationTask_cancel
DELETE:       bearer token + system_notificationTask_del
```

Rules：

```text
cancel 只允许 pending 任务；实现为软删除 is_del=1。
delete 是软删除 is_del=1。
已发送通知不会被撤回；本切片不做通知撤回。
```

### Queue / scheduler behavior

```text
task type: notification:dispatch-due:v1
task type: notification:send-task:v1
schedule:  cron_task.name=notification_task_scheduler -> notification:dispatch-due:v1
queue lane: default
```

边界：

```text
admin-api 只处理 HTTP，不消费队列，不跑 cron。
admin-worker 才拥有 Asynq server 和 gocron scheduler。
scheduler 由 `cron_task` 表 + Go registry 注册；当前 `notification_task_scheduler` 是第一条真实 Go registry。
scheduler callback 只能写 `cron_task_log` 并 enqueue dispatch-due task，不能扫描业务 DB 或发通知。
dispatch-due handler claim 到期 pending task，再 enqueue send-task。
send-task handler 解析目标用户、批量插入 notifications、更新 sent_count/status。
handler 必须幂等，Asynq 是 at-least-once 语义。
send-task 写入 notifications 后 best-effort 发布 `notification.created.v1`；Redis Pub/Sub 只做实时提示，DB notifications 仍是真相。
```

Operation log：

```text
POST   -> module=notification_task, action=create
PATCH  -> module=notification_task, action=cancel
DELETE -> module=notification_task, action=delete
```


## System Settings

状态：implemented in Go backend, adapted in Vue frontend。

用途：后台系统设置菜单页的键值配置 CRUD。该页面存在菜单和按钮权限，所以不能留空页或继续走 legacy；但它不是队列监控配置中心。

### Init

`GET /api/admin/v1/system-settings/init`

Response `data.dict`：

```ts
interface SystemSettingInitDict {
  system_setting_value_type_arr: Array<{ label: string; value: 1 | 2 | 3 | 4 }>
}
```

字典由 Go `internal/enum` -> `internal/dict` 派生：

```text
1 字符串
2 数字
3 布尔
4 JSON
```

### List

`GET /api/admin/v1/system-settings`

Query：

```ts
interface SystemSettingListQuery {
  current_page: number
  page_size: number
  key?: string      // prefix match
  status?: 1 | 2
}
```

Response `data`：

```ts
interface SystemSettingListResponse {
  list: Array<{
    id: number
    setting_key: string
    setting_value: string
    value_type: 1 | 2 | 3 | 4
    value_type_name: string
    remark: string
    status: 1 | 2
    status_name: string
    is_del: 1 | 2
    created_at: string
    updated_at: string
  }>
  page: { page_size: number; current_page: number; total_page: number; total: number }
}
```

### Create / Update / Status / Delete

```text
POST   /api/admin/v1/system-settings
PUT    /api/admin/v1/system-settings/:id
PATCH  /api/admin/v1/system-settings/:id/status
DELETE /api/admin/v1/system-settings/:id
DELETE /api/admin/v1/system-settings        body: { ids: number[] }
```

Create body：

```ts
interface SystemSettingCreateBody {
  key: string
  value: string
  type: 1 | 2 | 3 | 4
  remark?: string
}
```

Update body：

```ts
interface SystemSettingUpdateBody {
  value: string
  type: 1 | 2 | 3 | 4
  remark?: string
}
```

Rules：

```text
key 只允许 create；edit 不允许改 key。
type=2 必须能解析为 number。
type=3 只接受 0/1/true/false。
type=4 必须是合法 JSON object 或 array。
写入、状态、删除都是软变更，并清理对应 Redis cache；key 规则继承 legacy：`sys_setting_raw_` + setting key 中的 `.` 替换为 `_`。
不接受 setting_key 作为 create/update 入参，不返回 fallback alias。
mutating routes 显式注册 operation log rule。
```

### Queue Monitor Config Cleanup

`devtools_queue_monitor_queues` 是旧 PHP 队列监控配置项。Go 队列监控已经采用官方 `asynqmon`、Asynq Redis lane 和 `QUEUE_*` env；系统设置 CRUD 不再读取或维护该 key。

迁移时应将该行软删或标记删除，不删除队列监控功能本身。


## Mail Tencent SES

状态：implemented in Go backend, adapted in Vue frontend。

用途：后台“系统管理 / 邮件管理”维护腾讯云 SES 发信配置、本地业务场景到腾讯云模板 ID 的映射、发送日志，并为 `auth/send-code` 的邮箱验证码真实发送提供运行时能力。

### Shared Rules

```text
Only Tencent Cloud SES API.
No SMTP.
No self-hosted mail server.
No multi-provider abstraction.
Tencent SecretId / SecretKey are encrypted in mail_configs by APP_SECRET-derived secretbox.
HTTP responses never return secret_id_enc / secret_key_enc or plaintext secrets.
mail_configs / mail_templates / mail_logs all include is_del; every read path filters is_del=2.
mail_logs never store email body, verification plaintext, or full template payload.
Tencent Cloud SDK imports are confined to internal/platform/mail/tencentcloudses.
auth.Service depends only on VerifyCodeMailSender and does not import module/mail or Tencent SDK.
```

### Page Init

`GET /api/admin/v1/mail/page-init`

Response `data.dict`:

```ts
interface MailPageInitDict {
  common_status_arr: Array<{ label: string; value: 1 | 2 }>
  mail_scene_arr: Array<{ label: string; value: 'login' | 'forget' | 'bind_email' | 'change_password' }>
  mail_log_scene_arr: Array<{ label: string; value: 'login' | 'forget' | 'bind_email' | 'change_password' | 'test' }>
  mail_log_status_arr: Array<{ label: string; value: 1 | 2 | 3 }>
  mail_region_arr: Array<{ label: string; value: 'ap-guangzhou' | 'ap-hongkong' }>
  default_region: string
  default_endpoint: string
}
```

### Config

```text
GET    /api/admin/v1/mail/config
PUT    /api/admin/v1/mail/config
DELETE /api/admin/v1/mail/config
POST   /api/admin/v1/mail/test
```

`GET /mail/config` response:

```ts
interface MailConfigResponse {
  id: number | null
  configured: boolean
  secret_id_hint: string
  secret_key_hint: string
  region: string
  endpoint: string
  from_email: string
  from_name: string
  reply_to: string
  status: 1 | 2
  last_test_at: string | null
  last_test_error: string
  created_at: string | null
  updated_at: string | null
}
```

`PUT /mail/config` body accepts plaintext `secret_id` / `secret_key` only as write-only inputs. First setup requires both. Later updates may leave them blank to reuse the current encrypted values.

Rules:

```text
config_key is fixed to default.
DELETE is a soft delete of the active default row.
PUT restores a soft-deleted default row instead of inserting a duplicate.
region only accepts Tencent Cloud SES SendEmail supported regions: ap-guangzhou or ap-hongkong; default is ap-guangzhou.
status=1 enables real sending; status=2 disables it explicitly.
POST /mail/test uses the selected template scene sample variables and updates last_test_at / last_test_error.
```

### Templates

```text
GET    /api/admin/v1/mail/templates
POST   /api/admin/v1/mail/templates
PUT    /api/admin/v1/mail/templates/:id
PATCH  /api/admin/v1/mail/templates/:id/status
DELETE /api/admin/v1/mail/templates/:id
```

Template item:

```ts
interface MailTemplateItem {
  id: number
  scene: 'login' | 'forget' | 'bind_email' | 'change_password'
  name: string
  subject: string
  tencent_template_id: number
  variables: string[]
  sample_variables: Record<string, string>
  status: 1 | 2
  created_at: string
  updated_at: string
}
```

Rules:

```text
This system does not edit Tencent HTML body. It maps local scenes to approved Tencent TemplateID.
variables must be non-empty; sample_variables must cover variables.
scene is unique; saving a soft-deleted scene restores the old row.
DELETE is soft delete.
```

### Logs

```text
GET    /api/admin/v1/mail/logs
GET    /api/admin/v1/mail/logs/:id
DELETE /api/admin/v1/mail/logs/:id
DELETE /api/admin/v1/mail/logs        body: { ids: number[] }
```

Query:

```ts
interface MailLogQuery {
  current_page: number
  page_size: number
  scene?: 'login' | 'forget' | 'bind_email' | 'change_password' | 'test'
  status?: 1 | 2 | 3
  to_email?: string
  created_at_start?: string
  created_at_end?: string
}
```

Log item:

```ts
interface MailLogItem {
  id: number
  scene: string
  template_id: number | null
  to_email: string
  subject: string
  status: 1 | 2 | 3
  tencent_request_id: string
  tencent_message_id: string
  error_code: string
  error_message: string
  duration_ms: number
  sent_at: string | null
  created_at: string
  updated_at: string
  template?: {
    id: number
    scene: 'login' | 'forget' | 'bind_email' | 'change_password'
    name: string
    tencent_template_id: number
    variables: string[]
    status: 1 | 2
  } | null
}
```

Rules:

```text
status: 1=pending, 2=success, 3=failed.
Logs store provider request/message IDs, error code/message, duration and timestamps only.
Detail may include a template summary so humans can identify the Tencent TemplateID and variable names used by the send.
No body, plaintext verification value, or template payload field is present in DB/API/frontend contract.
DELETE is soft delete.
```

### Auth send-code integration

```text
POST /api/admin/v1/auth/send-code
```

```text
email account -> generate value, write Redis, call mail.SendVerifyCode, cleanup Redis on send failure
phone account -> use fixed value 123456, write Redis, return success, no SMS sender
missing mail config/template/sender -> explicit error, no fake success
no env switch exists for fake verification-code delivery
```

Operation log / permission:

```text
PUT    /mail/config                 -> system_mail_configEdit, module=mail, action=update_config
DELETE /mail/config                 -> system_mail_configDel, module=mail, action=delete_config
POST   /mail/test                   -> system_mail_test, module=mail, action=test_send
POST   /mail/templates              -> system_mail_templateAdd, module=mail, action=create_template
PUT    /mail/templates/:id          -> system_mail_templateEdit, module=mail, action=update_template
PATCH  /mail/templates/:id/status   -> system_mail_templateStatus, module=mail, action=change_template_status
DELETE /mail/templates/:id          -> system_mail_templateDel, module=mail, action=delete_template
DELETE /mail/logs/:id and /logs     -> system_mail_logDel, module=mail, action=delete_log/delete_logs
```

## Payment

状态：implemented in Go backend, adapted in Vue frontend for the project-native payment bounded context。

用途：替换旧 PHP-shaped `pay/*`、`wallet/*`、`recharge-orders`、`pay-reconcile` 合同。Payment 只负责支付渠道、支付订单、支付事件、支付宝 Web/H5 支付和支付宝 notify；wallet、refund、reconcile、WeChat 不在本阶段。

### Shared Rules

```text
resource prefix: /api/admin/v1/payment
public notify prefix: /api/payment/notify
backend owner: internal/module/payment
gateway boundary: internal/platform/payment/alipay
provider scope: Alipay only
tables: payment_channels, payment_channel_configs, payment_orders, payment_events
cron: payment:close-expired-order:v1, payment:sync-pending-order:v1
```

硬规则：

```text
Alipay only.
No wallet/refund/reconcile/WeChat in this phase.
No old admin pay, wallet, or recharge-orders active contract.
POST /api/payment/notify/alipay returns text/plain success or text/plain fail.
private_key_enc and plaintext private key never appear in API response, operation log, smoke output, or frontend types.
order_no is the order route key; do not expose a second /:id order route that conflicts with Gin wildcard names.
Legacy `pay_*_legacy_20260508`, wallet, reconcile/refund, fulfillment, and old `orders`/`order_items` prototype tables are not active contract tables and are removed from the launch schema after live code-reference verification.
```

### Routes

```text
GET    /api/admin/v1/payment/channels/page-init
GET    /api/admin/v1/payment/channels
POST   /api/admin/v1/payment/channels
PUT    /api/admin/v1/payment/channels/:id
PATCH  /api/admin/v1/payment/channels/:id/status
DELETE /api/admin/v1/payment/channels/:id

GET    /api/admin/v1/payment/orders/page-init
GET    /api/admin/v1/payment/orders
POST   /api/admin/v1/payment/orders
GET    /api/admin/v1/payment/orders/:order_no
GET    /api/admin/v1/payment/orders/:order_no/result
POST   /api/admin/v1/payment/orders/:order_no/pay
PATCH  /api/admin/v1/payment/orders/:order_no/cancel
PATCH  /api/admin/v1/payment/orders/:order_no/close

GET    /api/admin/v1/payment/events
GET    /api/admin/v1/payment/events/:id

POST   /api/payment/notify/alipay
```

### Channel Contract

`payment/channels` 管理支付宝渠道配置。创建/更新可以接收私钥明文用于加密写入；读取、列表、详情、操作日志和前端类型都不得返回 `private_key_enc` 或私钥明文。删除必须受订单/事件引用保护，不能破坏已有支付事实。

### Order Contract

`payment/orders` 使用 `order_no` 作为路由 key。创建订单、发起支付、查询结果、取消和关闭都围绕 `order_no`，不得再增加 `/payment/orders/:id` 这种和 Gin wildcard 冲突、且破坏前端路由语义的第二套订单路由。

订单只表达支付事实：创建、支付尝试、结果查询、取消、关闭。钱包入账、退款、对账、微信支付、履约补偿都不是本合同的一部分。

### Event Contract

`payment/events` 是支付事件/回调审计读取接口。事件可以记录 notify 原文、验签结果、平台交易号和处理状态，但不得泄漏渠道私钥密文或明文。

### Alipay Notify Contract

`POST /api/payment/notify/alipay` 是 public raw notify endpoint。它必须完成支付宝验签、幂等事件写入和订单状态推进；HTTP body 只返回 `success` 或 `fail`，Content-Type 为 `text/plain`。

### Retired Legacy Contracts

旧 pay channels、pay transactions、pay notify logs、pay orders、wallet、pay runtime、pay reconcile 文档段落在 payment domain rebuild 后不再作为 active contract 保留。

## Upload Config

状态：implemented in Go backend, adapted in Vue frontend。

用途：后台上传配置页的三类事实源：上传驱动、上传规则、启用配置。这里只做配置管理，不做 `/api/getUploadToken`、云 STS、服务端上传或 SDK 接入。配置事实允许 `cos` / `oss` 两种 driver；运行时默认依赖只接受 COS，OSS 是可选扩展。

### Shared Rules

所有接口都在后台命名空间：

```text
/api/admin/v1
```

字典来源：

```text
internal/enum -> internal/dict
```

敏感字段规则：

```text
upload_driver list/detail 永远不返回 secret_id、secret_key、secret_id_enc、secret_key_enc。
写入 secret 只保存 secret_id_enc、secret_key_enc 和 hint。
operation log 必须 mask secret_id、secret_key、secret_id_enc、secret_key_enc。
APP_SECRET 缺失、默认值或长度不足时 API/worker 启动失败；secretbox 只接收 HKDF 派生的 32-byte key，不做假加密。
```

### Dependency Boundary

```text
upload config CRUD supports cos/oss records because existing data may contain both.
upload runtime is implemented separately as COS-first upload token signing.
Default in-repo backend/frontend dependencies include COS runtime only.
Aliyun OSS SDK must not be added to default go.mod/package.json.
If OSS runtime is requested without the optional OSS implementation/dependency, return an explicit unsupported/not-configured error; do not silently fallback to COS, legacy PHP, or fake success.
```

### Upload Drivers

#### Init

`GET /api/admin/v1/upload-drivers/init`

Response `data.dict`：

```ts
interface UploadDriverInitDict {
  upload_driver_arr: Array<{ label: string; value: 'cos' | 'oss' }>
}
```

#### List

`GET /api/admin/v1/upload-drivers`

Query：

```ts
interface UploadDriverListQuery {
  current_page: number
  page_size: number
  driver?: 'cos' | 'oss'
}
```

Response `data`：

```ts
interface UploadDriverListResponse {
  list: Array<{
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
  }>
  page: { page_size: number; current_page: number; total_page: number; total: number }
}
```

#### Create / Update

```text
POST /api/admin/v1/upload-drivers
PUT  /api/admin/v1/upload-drivers/:id
```

Create body：

```ts
type UploadDriverCreateBody =
  | {
      driver: 'cos'
      secret_id: string
      secret_key: string
      bucket: string
      region: string
      appid: string
      endpoint?: string
      bucket_domain?: string
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

Update body：

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
同一 driver + bucket 在 is_del=2 范围内唯一。
create 时 secret_id/secret_key 必填。
update 时 secret_id/secret_key 为空或省略表示保留旧密文。
cos 必须 appid；oss 必须 role_arn。
被 upload_setting 引用的 driver 不能删除。
```

#### Delete

```text
DELETE /api/admin/v1/upload-drivers/:id
DELETE /api/admin/v1/upload-drivers    body: { ids: number[] }
```

### Upload Rules

#### Init

`GET /api/admin/v1/upload-rules/init`

Response `data.dict`：

```ts
interface UploadRuleInitDict {
  upload_image_ext_arr: Array<{ label: string; value: string }>
  upload_file_ext_arr: Array<{ label: string; value: string }>
}
```

#### List

`GET /api/admin/v1/upload-rules`

Query：

```ts
interface UploadRuleListQuery {
  current_page: number
  page_size: number
  title?: string
}
```

Response `data`：

```ts
interface UploadRuleListResponse {
  list: Array<{
    id: number
    title: string
    max_size_mb: number
    image_exts: string[]
    file_exts: string[]
    created_at: string
    updated_at: string
  }>
  page: { page_size: number; current_page: number; total_page: number; total: number }
}
```

#### Create / Update

```text
POST /api/admin/v1/upload-rules
PUT  /api/admin/v1/upload-rules/:id
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
title 1..50，is_del=2 范围内唯一。
max_size_mb 1..10240。
image_exts/file_exts 必须来自 Go enum，写入前 trim + lower-case + dedupe，并按 enum 顺序归一化。
image_exts 和 file_exts 不能同时为空。
被 upload_setting 引用的 rule 不能删除。
```

#### Delete

```text
DELETE /api/admin/v1/upload-rules/:id
DELETE /api/admin/v1/upload-rules    body: { ids: number[] }
```

### Upload Settings

#### Init

`GET /api/admin/v1/upload-settings/init`

Response `data.dict`：

```ts
interface UploadSettingInitDict {
  upload_driver_list: Array<{ label: string; value: number }>
  upload_rule_list: Array<{ label: string; value: number }>
  common_status_arr: Array<{ label: string; value: 1 | 2 }>
}
```

Rules：

```text
upload_driver_list label = <driver_show> - <bucket>
upload_rule_list label = <title>
common_status_arr 来自 common status dict
```

#### List

`GET /api/admin/v1/upload-settings`

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

Response `data`：

```ts
interface UploadSettingListResponse {
  list: Array<{
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
  }>
  page: { page_size: number; current_page: number; total_page: number; total: number }
}
```

#### Create / Update / Status / Delete

```text
POST   /api/admin/v1/upload-settings
PUT    /api/admin/v1/upload-settings/:id
PATCH  /api/admin/v1/upload-settings/:id/status
DELETE /api/admin/v1/upload-settings/:id
DELETE /api/admin/v1/upload-settings    body: { ids: number[] }
```

Mutation body：

```ts
interface UploadSettingMutationBody {
  driver_id: number
  rule_id: number
  status: 1 | 2
  remark?: string
}
```

Status body：

```ts
{ status: 1 | 2 }
```

Rules：

```text
driver_id/rule_id 必须存在且 is_del=2。
driver_id + rule_id 在 is_del=2 范围内唯一。
status=1 时 repository 用单个 DB transaction 执行互斥启用：锁定活跃 setting 行 -> 禁用其他 enabled 行 -> insert/update 当前行为 enabled。
status=2 只禁用当前项，不自动启用其他项。
启用中的 setting 不能删除。
允许系统暂时没有 enabled upload setting；upload token 接口必须显式报未配置，而不是兜底。upload runtime 默认走 COS；OSS runtime 若未安装可选实现，必须显式报不支持或未配置。
```

## Upload Runtime Tokens

状态：implemented in Go backend, adapted in shared Vue upload client。

用途：给浏览器直传腾讯云 COS 签发临时凭证和服务端生成的 object key。它不是服务端上传接口，也不是旧 PHP `/api/getUploadToken` 的兼容兜底。

```text
POST /api/admin/v1/upload-tokens
```

Auth: bearer token only. This is a current-user upload capability used by avatar/AI chat/rich-text/file fields after login; it must not require `system_uploadToken_create` or any other RBAC button permission.

Request:

```ts
interface UploadTokenRequest {
  folder: 'avatars' | 'images' | 'videos' | 'cover_images' | 'ai_chat_images' | 'releases' | 'tauri_updater' | 'exports' | 'reconcile_reports'
  file_name: string
  file_size: number
  file_kind: 'image' | 'file'
}
```

Response `data`:

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

Rules:

```text
Only COS runtime is implemented by default.
OSS runtime is an optional future extension and must return an explicit unsupported/config error until wired.
No legacy /api/getUploadToken fallback.
folder must come from internal/enum.UploadFolders.
file_name is used only for extension validation and safe display suffix; object key is generated by the server.
file_size is bytes and must be > 0.
file_kind=image validates against image_exts; file_kind=file validates against file_exts.
Generated key format: {folder}/{yyyy}/{mm}/{dd}/{unix_ms}-{randomhex}-{safe_file_name}.
STS policy is scoped to the generated key resource, not the whole bucket.
Response never exposes upload_driver secret_id/secret_key plaintext.
COS_STS_ENABLED=false returns explicit COS temporary credential disabled error.
No OperationLog route metadata for upload token create, because the response contains temporary STS credentials. Business modules that persist the uploaded object reference own their own operation log.
Smoke checks token shape only; it never uploads a real file.
```

Error cases:

```text
no enabled upload setting             -> code 100 / 未配置有效上传设置
enabled setting has non-COS driver    -> code 100 / 当前上传驱动未启用 COS runtime
invalid folder                        -> code 100 / 上传目录不支持
invalid file size                     -> code 100 / 文件大小不正确 or 文件大小超过限制
invalid extension                     -> code 100 / 文件类型不支持
decrypt failure or missing secret     -> code 500 / 上传密钥不可用
COS_STS_ENABLED=false                 -> code 500 / COS 临时凭证未启用
COS STS provider failure              -> code 500 / COS 临时凭证签发失败
```


## System Logs

系统日志是运行时文件日志的只读浏览接口，不等于 `operation-logs`。`operation-logs` 记录后台用户操作审计并落库；`system-logs` 只读取 Go 进程写出的结构化文件日志。

文件策略：

```text
admin-api    -> runtime/logs/admin-api.log
admin-worker -> runtime/logs/admin-worker.log
```

文件输出使用 lumberjack 轮转，默认：

```text
LOG_FILE_MAX_SIZE_MB=64
LOG_FILE_MAX_BACKUPS=7
LOG_FILE_MAX_AGE_DAYS=14
LOG_FILE_COMPRESS=true
```

所以不是一个 `admin-api.log` 无限增长。`LOG_FILE_NAME` 仅保留旧配置入口；实际进程入口会按 `LOG_API_FILE_NAME` / `LOG_WORKER_FILE_NAME` 选择文件名。

### Init

`GET /api/admin/v1/system-logs/init`

Auth: bearer token.

Response:

```json
{
  "dict": {
    "log_level_arr": [
      { "label": "DEBUG", "value": "DEBUG" },
      { "label": "INFO", "value": "INFO" },
      { "label": "WARNING", "value": "WARNING" },
      { "label": "ERROR", "value": "ERROR" },
      { "label": "CRITICAL", "value": "CRITICAL" }
    ],
    "log_tail_arr": [
      { "label": "最近 100 行", "value": 100 },
      { "label": "最近 300 行", "value": 300 },
      { "label": "最近 500 行", "value": 500 },
      { "label": "最近 1000 行", "value": 1000 },
      { "label": "最近 2000 行", "value": 2000 }
    ]
  }
}
```

### Files

`GET /api/admin/v1/system-logs/files`

Auth: bearer token + `system_log_files` route permission.

Response:

```json
{
  "list": [
    { "name": "admin-api.log", "size": 1024, "size_human": "1.00 KB", "mtime": "2026-05-04 19:30:00" },
    { "name": "admin-worker.log", "size": 2048, "size_human": "2.00 KB", "mtime": "2026-05-04 19:31:00" }
  ]
}
```

Rules:

- Lists only configured extensions, default `.log`.
- Scans log root and first-level child directories only.
- Does not expose delete/clear/download in phase one.

### Lines

`GET /api/admin/v1/system-logs/files/:name/lines?tail=500&level=ERROR&keyword=db`

Auth: bearer token + `system_log_content` route permission.

`:name` is URL-escaped. A first-level child file such as `worker/admin-worker.log` must be sent as `worker%2Fadmin-worker.log`.

Response:

```json
{
  "filename": "admin-api.log",
  "total": 1,
  "lines": [
    { "number": 42, "level": "ERROR", "content": "ERROR db timeout" }
  ]
}
```

Validation and safety:

- `tail`: 1-2000, capped again by `LOG_MAX_TAIL_LINES`.
- `level`: one of `DEBUG/INFO/WARNING/ERROR/CRITICAL`.
- `keyword`: max 200 chars.
- Rejects absolute paths, `..`, backslash paths, null bytes, unsupported extensions, missing files.
- Filtering happens after tail; the API does not read an entire huge file just to search.

## Queue Monitor

状态：partially implemented。当前采用开源优先：官方 Asynq 监控组件 `github.com/hibiken/asynqmon` 提供完整监控 UI；项目只保留轻量只读 JSON 摘要接口。

### Official UI Mount

```text
GET /api/admin/v1/queue-monitor-ui
GET /api/admin/v1/queue-monitor-ui/*
```

规则：

```text
该路径挂载 asynqmon http.Handler，不包成 {code,data,msg} JSON。
该路径仍经过 AuthToken，未登录不可访问。
iframe/new window 无法主动附加 Authorization header，所以该路径的 GET/HEAD 文档请求允许使用现有 `access_token` cookie 完成认证；普通 JSON API 不允许 cookie token fallback，mutating request 也不允许。
cookie 认证只在该 UI 路径生效，并显式使用后台平台 `admin` 参与 session policy 校验；这不是全局平台默认值，也不是普通 API 的兜底。
前端 iframe 必须使用 `VITE_GO_API_BASE_URL + /api/admin/v1/queue-monitor-ui` 的绝对 URL；不能用相对路径，否则会命中前端 SPA 路由并显示前端 404。
Windows 本地开发时，asynqmon 内置静态 handler 会返回 `400 unexpected path prefix`；本项目复制官方 `ui/build` 静态文件并用薄 handler 服务首页和静态资源，`/api` 子路径仍使用官方 asynqmon handler。
asynqmon 使用 ReadOnly=true；POST/DELETE 这类运行/删除/清空任务操作由 asynqmon 拒绝。
前端队列监控页只做 iframe/新窗口薄包装，不复制完整任务列表和操作 UI。
```

### JSON Summary

`GET /api/admin/v1/queue-monitor`

Response `data`：

```ts
interface QueueMonitorItem {
  name: string
  label: string
  group: 'critical' | 'default' | 'low' | 'custom'
  waiting: number
  delayed: number
  failed: number
  pending: number
  active: number
  scheduled: number
  retry: number
  archived: number
  completed: number
  processed: number
  failed_today: number
  processed_total: number
  failed_total: number
  paused: boolean
  latency_ms: number
}
```

`GET /api/admin/v1/queue-monitor/failed`

Query：

```ts
interface QueueFailedListParams {
  queue: 'critical' | 'default' | 'low' | string
  current_page: number
  page_size: number
}
```

规则：JSON 摘要接口只读，不提供 retry/delete/clear。配置的 lane 即使 Asynq 尚未创建 Redis queue key，也返回 0 计数 item；Redis 连接、鉴权、协议错误不兜底。需要完整任务详情时进入 `queue-monitor-ui`。

## Auth Platform

状态：implemented in Go backend, adapted in Vue frontend。

用途：管理认证平台登录方式、验证码策略、token TTL、会话绑定策略和自动注册策略。

Token TTL 事实源：

```text
auth_platforms.access_ttl  = access_token 有效期，单位秒
auth_platforms.refresh_ttl = refresh_token 总有效期，单位秒
.env 只保存 APP_SECRET、TOKEN_REDIS_PREFIX、TOKEN_REDIS_DB、TOKEN_SESSION_CACHE_TTL、TOKEN_SINGLE_SESSION_POINTER_TTL 这类运行时基础设施配置。access_ttl / refresh_ttl 仍以 auth_platforms 表为业务事实源
```

### Enum / Dict

`GET /api/admin/v1/auth-platforms/init`

响应 `data.dict`：

```ts
interface AuthPlatformInitDict {
  common_status_arr: Array<{ label: string; value: number }>
  auth_platform_login_type_arr: Array<{ label: string; value: 'email' | 'phone' | 'password' }>
  auth_platform_captcha_type_arr: Array<{ label: string; value: 'slide' }>
}
```

规则：

```text
login type 顺序固定为 email -> phone -> password
captcha_type 当前只支持 slide
字典由 Go internal/enum -> internal/dict 派生，前端不手写 fallback label
```

### List

`GET /api/admin/v1/auth-platforms`

Query：

```ts
interface AuthPlatformListQuery {
  current_page: number
  page_size: number
  name?: string
  status?: 1 | 2
}
```

Response `data`：

```ts
interface AuthPlatformListResponse {
  list: AuthPlatformItem[]
  page: { page_size: number; current_page: number; total_page: number; total: number }
}
```

### Create

`POST /api/admin/v1/auth-platforms`

Body：

```ts
interface AuthPlatformCreateBody {
  code: string
  name: string
  login_types: Array<'email' | 'phone' | 'password'>
  captcha_type: 'slide'
  access_ttl: number
  refresh_ttl: number
  bind_platform: 1 | 2
  bind_device: 1 | 2
  bind_ip: 1 | 2
  single_session: 1 | 2
  max_sessions: number
  allow_register: 1 | 2
}
```

Response `data`：

```ts
{ id: number }
```

### Update

`PUT /api/admin/v1/auth-platforms/:id`

Body：同 create，但不包含 `code`。

规则：`login_types` 写入前按 `email -> phone -> password` 去重归一化；非法 `captcha_type` 直接拒绝，不写库。
`access_ttl` / `refresh_ttl` 是登录签发和 refresh 续签 access token 的业务事实源；不允许再用 env TTL 覆盖。

### Status

`PATCH /api/admin/v1/auth-platforms/:id/status`

Body：

```ts
{ status: 1 | 2 }
```

规则：只修改 `status`；不顺手重写 `captcha_type`、`login_types` 或 token 策略。

### Delete

```text
DELETE /api/admin/v1/auth-platforms/:id
DELETE /api/admin/v1/auth-platforms    body: { ids: number[] }
```

规则：`admin` 核心平台不允许删除，也不允许禁用。

## Contract Review Checklist

每次迁移或修改接口必须检查：

```text
method/path 是否符合 RESTful resource，不是 legacy action path。
是否写明 auth requirement：public / bearer token / permission code。
request query/body 是否有 TypeScript shape。
response data 是否有 TypeScript shape 或 JSON example。
错误场景是否写清：参数错误、权限失败、资源不存在、业务冲突。
dict/init 是否写明 enum 来源：internal/enum -> internal/dict。
前端调用是否使用 request，不使用 legacyRequest，除非明确 legacy adapter。
是否需要 operation log route metadata；需要就同步 route_meta 和本文。
是否需要 smoke 覆盖；需要就同步 smoke matrix。
```

## System Cron Tasks

状态：implemented in this slice。系统管理定时任务从 legacy `/api/admin/CronTask/*` 迁到 Go REST。`handler` 不是 Go 运行时执行入口；已接入 Go registry 的任务返回/保存版本化 Asynq task type，未迁 Go 的旧 PHP 字符串只作为 legacy provenance 展示。

### Runtime rule

```text
cron_task DB row = 配置、启用状态、cron 表达式、页面展示
Go crontask registry = 可执行任务真相源
admin-worker = scheduler owner
scheduler callback = 写 cron_task_log + enqueue Asynq task
queue handler = 真正业务执行
```

当前 Go registry 注册：

```text
name: notification_task_scheduler
Asynq task type: notification:dispatch-due:v1

name: payment_close_expired_order
Asynq task type: payment:close-expired-order:v1

name: payment_sync_pending_order
Asynq task type: payment:sync-pending-order:v1

name: ai_run_timeout
Asynq task type: ai:run-timeout:v1
```

未迁 Go 的 legacy handler 不注册假任务；列表返回 `registry_status=missing`。禁用行返回 `disabled`，表达式错误返回 `invalid_cron`。Payment 只保留 Alipay close-expired/sync-pending 两个补偿任务；wallet/refund/reconcile/WeChat 没有本阶段 registry 合同。

当前数据迁移：

```text
database/migrations/20260506_cron_task_go_handler_cleanup.sql
notification_task_scheduler.handler = notification:dispatch-due:v1

payment domain rebuild migration
payment_close_expired_order.handler = payment:close-expired-order:v1
payment_sync_pending_order.handler = payment:sync-pending-order:v1

AI runtime migration (2026-05-08)
ai_run_timeout.handler = ai:run-timeout:v1
```

`ai_run_timeout` 是 stale-run sweeper only：worker 只处理 `status='running' AND started_at < now - AI_RUN_STALE_TIMEOUT` 的残留运行，不负责正常在线流式请求超时。

### Routes

```text
GET    /api/admin/v1/cron-tasks/init
GET    /api/admin/v1/cron-tasks
POST   /api/admin/v1/cron-tasks
PUT    /api/admin/v1/cron-tasks/:id
PATCH  /api/admin/v1/cron-tasks/:id/status
DELETE /api/admin/v1/cron-tasks/:id
DELETE /api/admin/v1/cron-tasks
GET    /api/admin/v1/cron-tasks/:id/logs
```

Auth/RBAC：

```text
read/init/list: bearer token
create: devTools_cronTask_add
update: devTools_cronTask_edit
status: devTools_cronTask_status
delete/batch delete: devTools_cronTask_del
logs: devTools_cronTask_logs
```

Mutating routes write explicit OperationLog metadata with module `cron_task` and actions `create/update/change_status/delete/delete_batch`.

### List response item

```ts
type CronTaskRegistryStatus = 'registered' | 'missing' | 'disabled' | 'invalid_cron'

interface CronTaskItem {
  id: number
  name: string
  title: string
  description: string
  cron: string
  cron_readable: string
  handler: string // registered Go task returns task type; missing legacy rows may show old provenance
  status: number
  status_name: string
  next_run_time: string
  registry_status: CronTaskRegistryStatus
  registry_status_text: string
  registry_task_type: string
  registry_description: string
  created_at: string
  updated_at: string
}
```

规则：

```text
name 是 Go registry key，新增后不允许编辑修改。
registered 任务的 handler 由 Go registry task type 覆盖，前端不能把 PHP class 当“处理类”展示。
registry_status 是 Go 根据 DB row + registry + cron 表达式派生；支持筛选，并在服务端筛选后重新分页。
```

注意：修改 `cron_task` 配置后，已运行的 `admin-worker` 不热重载 schedule；需要重启 worker 或后续引入显式 reload/分布式锁策略。不要在 admin-api handler 里启动 cron。

## Client Versions

状态：implemented. 业务名称是“客户端版本”；Go REST 使用 `ClientVersionApi`，DB 表统一为 `client_versions`，前端视图目录和 i18n key 使用 `clientVersion`，mutation 权限 code 统一为 `system_clientVersion_*`。旧 Tauri 表名/权限名只允许出现在迁移 SQL 的 source condition 或 legacy PHP 参考说明里，不是新契约。菜单 PAGE route/component/i18n_key 通过 `20260507_client_version_permission_route_cleanup.sql` 迁到 `system/clientVersion`。

### Shared Rules

命名空间：

```text
/api/admin/v1/client-versions
```

字典来源：

```text
internal/enum.ClientPlatform* -> internal/dict.ClientVersionPlatformOptions
internal/enum.CommonYes/CommonNo -> internal/dict.CommonYesNoOptions
internal/validate.client_platform + common_yes_no
```

平台 v1：

```text
windows-x86_64 -> Windows
darwin-x86_64  -> macOS
```

数据规则：

```text
DB table is client_versions.
Menu PAGE target is path=/system/clientVersion, component=system/clientVersion, i18n_key=menu.system_clientVersion.
is_del=2 means active; is_del=1 means soft deleted.
is_latest=1 means latest; is_latest=2 means normal.
force_update=1 means force; force_update=2 means normal.
version + platform + is_del follows existing unique index.
Exactly one latest row per platform is enforced by service transaction, not by frontend.
```

### Page Init

```text
GET /api/admin/v1/client-versions/page-init
```

Auth：bearer token. No mutating RBAC button permission. No OperationLog metadata.

Response：

```ts
interface ClientVersionPageInitResponse {
  dict: {
    client_version_platform_arr: Array<{ label: string; value: 'windows-x86_64' | 'darwin-x86_64' }>
    common_yes_no_arr: Array<{ label: string; value: 1 | 2 }>
  }
}
```

### List

```text
GET /api/admin/v1/client-versions?current_page=1&page_size=20&platform=windows-x86_64
```

Auth：bearer token. No mutating RBAC button permission. No OperationLog metadata.

Query：

```ts
interface ClientVersionListQuery {
  current_page?: number
  page_size?: number
  platform?: 'windows-x86_64' | 'darwin-x86_64'
}
```

Response：

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

interface ClientVersionListResponse {
  list: ClientVersionItem[]
  page: Page
}
```

### Update JSON Preview

```text
GET /api/admin/v1/client-versions/update-json?platform=windows-x86_64
```

Auth：bearer token. No mutating RBAC button permission. No OperationLog metadata.

Rules：

```text
platform empty defaults to windows-x86_64.
missing latest row returns [] for admin preview compatibility.
existing latest row returns Tauri static updater JSON shape.
pub_date uses RFC3339.
```

Response shape when latest exists：

```ts
interface ClientVersionManifestPayload {
  version: string
  notes: string
  pub_date: string
  platforms: Record<'windows-x86_64' | 'darwin-x86_64', {
    url: string
    signature: string
  }>
}
```

### Current Check

```text
GET /api/admin/v1/client-versions/current-check?version=1.0.7&platform=windows-x86_64
```

Auth：public. This exact path is in `DefaultAuthSkipPaths`.

Query：

```ts
interface ClientVersionCurrentCheckQuery {
  version: string
  platform?: 'windows-x86_64' | 'darwin-x86_64'
}
```

Response：

```ts
interface ClientVersionCurrentCheckResponse {
  force_update: boolean
}
```

Rules：missing version/platform row returns `force_update=false`; this endpoint does not expose download URL or signature.

### Create / Update

```text
POST /api/admin/v1/client-versions
PUT  /api/admin/v1/client-versions/:id
```

Auth/RBAC：

```text
POST create: system_clientVersion_add
PUT update:  system_clientVersion_edit
```

OperationLog：

```text
module=client_version action=create title=发布客户端版本
module=client_version action=update title=编辑客户端版本
```

Body：

```ts
interface ClientVersionSaveBody {
  version: string
  notes?: string
  file_url: string
  signature: string
  platform: 'windows-x86_64' | 'darwin-x86_64'
  file_size?: number
  force_update?: 1 | 2 // create may omit and defaults to 2; update requires explicit valid value
}
```

Rules：

```text
create defaults is_latest=2, force_update=2, is_del=2.
update cannot change platform.
duplicate active version+platform is rejected.
if updating the current latest row, service republishes manifest; publish failure returns an explicit error instead of silent success.
```

### Set Latest / Force Update / Delete

```text
PATCH  /api/admin/v1/client-versions/:id/latest
PATCH  /api/admin/v1/client-versions/:id/force-update
DELETE /api/admin/v1/client-versions/:id
```

Auth/RBAC：

```text
PATCH latest:       system_clientVersion_setLatest
PATCH force-update: system_clientVersion_forceUpdate
DELETE:             system_clientVersion_del
```

OperationLog：

```text
module=client_version action=set_latest title=设为最新版本
module=client_version action=force_update title=切换强制更新
module=client_version action=delete title=删除客户端版本
```

Force update body：

```ts
interface ClientVersionForceUpdateBody {
  force_update: 1 | 2
}
```

Rules：

```text
set-latest clears old latest for the same platform and sets selected row latest in one DB transaction, then publishes manifest.
force-update validates common yes/no; if the row is latest, it republishes manifest.
delete is soft delete only and rejects current latest version.
```

### Manifest Publish Boundary

```text
clientversion.Service -> ManifestPublisher small interface -> ManifestCOSPublisher -> internal/platform/storage/cos.ObjectWriter -> github.com/tencentyun/cos-go-sdk-v5
```

Rules：

```text
Only COS server-side manifest publish is implemented in this slice.
The manifest object key is tauri_updater/{platform}.json.
Content-Type is application/json; charset=utf-8.
Enabled upload_setting + upload_driver remains the credential fact source.
secret_id_enc/secret_key_enc are decrypted only inside publisher and never returned or operation-logged.
OSS runtime is not silently supported; unsupported driver returns explicit error.
```

Error cases：

```text
400 invalid platform / invalid force_update / duplicate version+platform / cannot delete latest / platform cannot be changed
401 missing or expired token for protected admin routes
403 missing system_clientVersion_* button permission on mutating routes
404 client version does not exist
500 repository failure / manifest publisher not configured / upload config missing / COS publish failure
```
