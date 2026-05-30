# Admin API v1 Contract

状态：partially implemented。本文只记录 Go 新接口已经明确落地或正在本阶段收口的契约；旧 all POST 接口只作为历史兼容事实，不定义新契约。

统一响应：

```json
{ "code": 0, "data": {}, "msg": "ok" }
```

语言规则：

```text
前端请求通过 Accept-Language 传当前 UI 语言，当前只支持 zh-CN / en-US。
后端 response shape 不变，仍然只返回 code/data/msg。
Accept-Language 只控制 response.msg。
msg 是面向用户展示的本地化文本；业务判断只能依赖 code 和 HTTP status，不能依赖 msg 字符串。
data 里的业务内容不自动翻译。
缺失或不支持的语言默认 zh-CN。
```

命名空间：

```text
后台管理端：/api/admin/v1
App 端：/api/app/v1
```

## Contract Source Policy

状态：implemented as documentation gate baseline。

当前阶段采用 **Markdown first**：`docs/contracts/admin-api-v1.md` 是人工可读的前后端契约源；OpenAPI YAML 等自动化产物后续再引入，不能反过来替代本文的业务规则说明。

规则：

```text
每个迁移到 Go 的资源必须先更新本文，再改前端调用。
新 Go API 只能使用 /api/admin/v1 或 /api/app/v1 命名空间。
新 Go API 使用 RESTful resource，不允许 /api/admin/Xxx/list、/api/admin/Xxx/add、/api/admin/Xxx/edit、/api/admin/Xxx/del 这种旧动作式 path。
init/page-init 属于页面字典或 bootstrap contract，必须显式写清用途和 enum/dict 来源。
旧接口兼容入口必须标注兼容来源、退出条件和验证边界，不得伪装成新契约。
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
| App auth baseline | `GET /api/app/v1/auth/login-config`, `GET /api/app/v1/auth/captcha`, `POST /api/app/v1/auth/send-code`, `POST /api/app/v1/auth/login`, `GET /api/app/v1/users/me`, `GET/PUT /api/app/v1/profile`, `POST /api/app/v1/upload-tokens`, `POST /api/app/v1/auth/logout` | auth config/captcha/send-code/login: public; current user/profile/upload-token/logout: bearer token; app bearer requests default `platform=app` |
| read-only admin resources | permissions/auth-platforms/roles/users/profile/operation-logs/system-settings/mail/upload-drivers/upload-rules/upload-settings/notifications list or init | bearer token |
| user quick-entry current-user write | `PUT /api/admin/v1/users/me/quick-entries` | bearer token; current user only, no user-manager button permission |
| user login logs read | `GET /api/admin/v1/users/login-logs/page-init`, `GET /api/admin/v1/users/login-logs` | bearer token |
| user sessions read/revoke | `GET /api/admin/v1/user-sessions/page-init`, `GET /api/admin/v1/user-sessions`, `GET /api/admin/v1/user-sessions/stats`, `PATCH /api/admin/v1/user-sessions/:id/revoke`, `PATCH /api/admin/v1/user-sessions/revoke` | read routes: bearer token; revoke routes: bearer token + `user_userManager_kick` |

2026-05-27 auth-adjacent module consolidation only changed internal ownership (`captcha` / `session` / `usersession` / `userloginlog` -> `internal/module/auth`); it does not change the API contract URLs listed above.
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
| wallet current-user read/consume | `GET /api/admin/v1/wallet/summary`, `GET /api/admin/v1/wallet/transactions`, `POST /api/admin/v1/wallet/consumptions` | read routes: bearer token + `wallet_transaction_list`; consume route: bearer token + `wallet_consume_add`, current user only |
| wallet admin read | `GET /api/admin/v1/wallet/users/page-init`, `GET /api/admin/v1/wallet/users`, `GET /api/admin/v1/wallet/ledger/page-init`, `GET /api/admin/v1/wallet/ledger` | bearer token + `wallet_user_list` or `wallet_ledger_list` |
| AI sidecar provider/agent/tool/knowledge management | ai-providers/ai-agents/ai-tools/ai-knowledge-bases/ai-knowledge-documents write routes | bearer token; mutation routes use explicit `ai_provider_*`, `ai_agent_*`, `ai_tool_*`, `ai_knowledge_*`, `ai_knowledge_document_*` route permissions and OperationLog metadata; secret fields are write-only/masked |
| AI sidecar runtime current-user | ai-conversations current-user CRUD, ai-conversations/:id/messages list/send, and ai-runs read monitor | bearer token; current-user ownership where applicable; message send requires an enabled chat-scene AI agent + provider and must fail explicitly when not configured |
| Retired AI legacy routes | legacy model/tool/prompt/agent/knowledge-base routes | not mounted in active Go runtime; only backup/rollback SQL, historical specs, or negative router tests may mention exact old route strings |

## App Auth Baseline

状态：implemented for served runtime.

```text
GET  /api/app/v1/auth/login-config
GET  /api/app/v1/auth/captcha
POST /api/app/v1/auth/send-code
POST /api/app/v1/auth/login
GET  /api/app/v1/users/me
GET  /api/app/v1/profile
PUT  /api/app/v1/profile
POST /api/app/v1/upload-tokens
POST /api/app/v1/auth/logout
```

规则：

```text
login-config / captcha / send-code / login 是 app 公共 auth 入口，不需要 bearer token。
app login-config 强制按 platform=app 查询 auth_platforms，不信任前端 header。
app 密码登录必须提交 slide captcha，遵守 auth_platforms.captcha_type，不再跳过验证码。
app login 请求使用 login_type/login_account/password|code/captcha_id/captcha_answer，与 admin auth 入参语义一致，但返回 data.token + data.user{id,nickname,avatar}。
users/me 只返回 id/nickname/avatar，不返回 admin RBAC 字段。
logout 返回 data:null。
App bearer 请求在路径为 /api/app/v1/* 时默认 platform=app。
Ownership：`/api/app/v1/auth/*` 归属 `internal/module/auth/transport/app`；`/api/app/v1/users/me` 和 `/api/app/v1/profile` 当前由 `internal/module/profile/transport/app` 作为 current-user profile 编译入口注册，并复用现有 user service；`/api/app/v1/upload-tokens` 归属 `internal/module/uploadtoken/transport/app`。平台 app 是 route/policy scope，不是 appauth module。
```

请求：

```ts
type AppLoginBody =
  | {
      login_type: 'password'
      login_account: string
      password: string
      captcha_id: string
      captcha_answer: { x: number; y: number }
    }
  | {
      login_type: 'email' | 'phone'
      login_account: string
      code: string
    }

interface AppSendCodeBody {
  account: string
  scene: 'login'
}
```

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

Queue Docker-first env 只暴露 `QUEUE_ENABLED`、`QUEUE_REDIS_DB`、`QUEUE_CONCURRENCY`。Queue lane 名称 `critical/default/low`、lane 权重 `6/3/1`、默认重试 `3`、默认 task timeout `30s`、worker shutdown timeout `10s` 都是 `internal/infra/taskqueue` 代码内置默认值，不是 `system_settings`，也不是公开 Docker-first env contract。

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
成功后写入 users.password 的 bcrypt $2y$ hash，并消费 Redis 验证码。
前端必须使用 Go request 调用本接口，不允许保留旧用户域重置密码调用。
新 Go 契约不接受旧字段：newpassword、respassword、account_type。
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
PAGE 授权让 permissions tree + router 包含该 PAGE；PAGE code 可进入后端内部 RouteAccessCodes，但不返回到 users/init.buttonCodes。
BUTTON 授权由 Go service 自动带出父 PAGE 和祖先 DIR；buttonCodes 只包含 BUTTON code。
前端按钮显隐只读 buttonCodes；API 放行只由 PermissionCheck 使用内部 RouteAccessCodes 判断。
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

状态：implemented in Go backend, adapted in Vue frontend for list/page-init/edit/batch-edit/delete/status/export submit。admin user-management HTTP routes are owned by `internal/module/user/transport/admin`; 导出任务列表、状态统计、删除和 `user_list` worker runtime 已迁到 Go。

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
编辑 role_id 后清理该用户 admin/app 平台 route access grant cache。
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

状态：implemented in Go backend, adapted in Vue frontend。HTTP route ownership now lives in `internal/module/profile/transport/admin`; the URL stays `PUT /api/admin/v1/users/me/quick-entries` and the persistence service still reuses `internal/module/userquickentry` in this slice.

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
single-session pointer `token:cur_sess:<platform>:<user_id>` is deleted only when its value equals this session id; `token:` is a code-owned Redis namespace.
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

Legacy `UserSession/kick` and `UserSession/batchKick` are no longer active frontend contracts. Do not reintroduce legacy POST action paths under Go REST.

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

状态：implemented in Go backend, adapted in Vue frontend for base profile、avatar upload and account security writes。Current-user profile/security HTTP routes are owned by `internal/module/profile/transport/admin`; user-manager target profile read remains under `internal/module/user/transport/admin` so `GET /api/admin/v1/users/:id/profile` stays a user-management read surface.

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
提交 DIR 会被归一化忽略；DIR 可存在于 permissions 定义树，但不作为 role_permissions 授权记录保存。
不创建 view/查看 虚拟 BUTTON；角色编辑器里的“页面访问”映射真实 PAGE permission_id。
角色授权变更后清理绑定用户所有平台的 route access grant cache。
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

字典由 Go `internal/shared/enum` -> `internal/shared/dict` 派生：

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
internal/module/* does not import provider SDKs/clients; provider calls go through internal/infra/ai boundaries.
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
- list query supports `scene=chat`, `scene=agent_generate`, and `scene=image_generate`; there is no agent code or agent type filter in the MVP
- MVP scene field is `scenes`; current allowed values are `chat`, `agent_generate`, and `image_generate`; empty internal input normalizes to `["chat"]`
- MVP form fields are name, model cascader, scenes, status, optional system prompt, and optional avatar
- `ai_agents` deliberately does not store agent code, agent type, per-agent external app ids, per-agent API keys, response mode, runtime config JSON, model snapshot JSON, `created_by`, or `updated_by`; those are future contracts, not MVP columns
- runtime uses the selected agent plus its provider credentials; per-agent credential override is not part of this slice
- `GET /ai-agents/options` feeds runtime selectors and accepts optional `scene`; blank defaults to enabled `chat` scene agents, `scene=image_generate` is used by the image playground
- `GET /ai-agents/page-init` returns `scene_arr` and `provider_model_options`; `GET /ai-agents/provider-models/:id` refreshes enabled models for a provider
- `agent_id` / `agent_name` are the canonical AI runtime selector fields; old app aliases must not drive new DB queries or new Vue state

## AI Images / Image Playground

状态：implemented as an agent-driven `gpt-image-2` image playground. It is not a provider/model configuration page.

```text
GET    /api/admin/v1/ai-images/page-init
GET    /api/admin/v1/ai-images
GET    /api/admin/v1/ai-images/:id
POST   /api/admin/v1/ai-images/assets
POST   /api/admin/v1/ai-images
PATCH  /api/admin/v1/ai-images/:id/favorite
DELETE /api/admin/v1/ai-images/:id
```

Rules:

- tables: `ai_image_tasks`, `ai_image_assets`, `ai_image_task_assets`
- runtime selector is only `agent_id`; frontend must not ask for provider id, model id, API key, or a separate model selector
- selected agent must be enabled, include `image_generate`, use an enabled OpenAI-compatible provider, and have `model_id = gpt-image-2`
- `POST /ai-images` is async: it writes a pending task, links registered input/mask assets, enqueues `ai:image-generate:v1`, and returns immediately
- worker claims `pending -> running`, calls the image adapter, persists generated assets, then finalizes `success` or `failed`
- `POST /ai-images/assets` registers already-uploaded COS image assets; frontend uploads through the existing upload-token/COS runtime first
- prompt text, image URLs, base64 payloads, and provider raw response are not captured by OperationLog; image mutation route metadata uses `SkipRequestPayload` and `SkipResponsePayload`
- `raw_response_json` stays server-side only; API list/detail return task facts and grouped assets, not raw provider payloads

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
- `aichat` executes the reply through `internal/infra/ai.Engine` using recent conversation messages, selected agent prompt, optional image attachments, and allowed runtime parameters
- `ai:conversation-reply:v1` remains a registered worker task type, but it is not the active browser chat MVP handoff path; the API process owns the immediate reply execution so local WebSocket conversations do not depend on a separately running worker
- `POST /messages/cancel` cancels the matching in-process reply context by `conversation_id + request_id`; late WebSocket events for a locally canceled request must be ignored by the browser
- provider stream is consumed only inside Go and converted to admin_go WebSocket envelopes; the browser never receives provider stream directly
- AI chat streaming timeout is layered: provider stream reads do not use a 30s total HTTP timeout; live reply max duration, upstream silence timeout, and stale-run cleanup window are code-owned runtime guardrails, not Docker-first env knobs; `ai_run_timeout` only marks stale running rows older than the stale-run cleanup window
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
- worker marks only stale `running` rows as `timeout`: `status='running' AND started_at IS NOT NULL AND started_at < now - code-owned AI run stale timeout default`
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

字典由 Go `internal/shared/enum` -> `internal/shared/dict` 派生：

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
注意：后台如果有旧的 `admin-worker-smoke.exe` 或未重启 worker，可能不包含 notification:send-task:v1 handler，任务会停在 pending 或进入 Asynq archived。运行真实发布前必须启动当前代码构建出的 `admin-worker` Docker 容器。
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

Docker-first queue env 只保留 `QUEUE_ENABLED`、`QUEUE_REDIS_DB`、`QUEUE_CONCURRENCY`。Queue lane policy 跟随 Go 代码和任务 builder 演进，不通过系统设置或部署 env 热改。

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

字典由 Go `internal/shared/enum` -> `internal/shared/dict` 派生：

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

`devtools_queue_monitor_queues` 是旧队列监控配置项。Go 队列监控已经采用官方 `asynqmon`、Asynq Redis lane 和 Docker-first queue runtime env（仅 `QUEUE_ENABLED` / `QUEUE_REDIS_DB` / `QUEUE_CONCURRENCY`）；系统设置 CRUD 不再读取或维护该 key。

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
Tencent Cloud SDK imports are confined to internal/infra/mail/tencentcloudses.
auth.Service depends only on VerifyCodeMailSender and does not import module/mail or Tencent SDK.
Verification-code templates must include exactly code and ttl_minutes.
app_name is not a verification-code template variable; mail_configs.from_name only controls the Tencent SES FromEmailAddress display name.
ttl_minutes for email verification comes from mail_configs.verify_code_ttl_minutes.
Templates do not own independent TTL, app-name, brand-name, or system-name policy.
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
  default_ttl_minutes: number
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
  verify_code_ttl_minutes: number
  last_test_at: string | null
  last_test_error: string
  created_at: string | null
  updated_at: string | null
}
```

`PUT /mail/config` body accepts plaintext `secret_id` / `secret_key` only as write-only inputs. First setup requires both. Later updates may leave them blank to reuse the current encrypted values. It also accepts `verify_code_ttl_minutes: number`; the value is saved to `mail_configs.verify_code_ttl_minutes`.

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
Verification-code template variables must be exactly `code` and `ttl_minutes`; `sample_variables` must contain exactly the same two keys. Extra keys such as `app_name` are rejected.
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


## SMS Tencent Cloud

状态：implemented in Go backend, adapted in Vue frontend。

用途：后台“系统管理 / 短信管理”维护腾讯云短信发送配置、本地验证码场景到腾讯云模板 ID 的映射、发送日志，并提供独立测试发送能力。本切片不接入 `auth/send-code`；手机号验证码仍固定 `123456`。

### Shared Rules

```text
Only Tencent Cloud SMS SendSms.
No sign application API.
No template application API.
No callback/webhook receipt.
No automatic retry queue.
No multi-provider abstraction.
No marketing SMS, international/HK/Macau/Taiwan SMS, or batch send in phase one.
Tencent SecretId / SecretKey are encrypted in sms_configs by APP_SECRET-derived secretbox.
HTTP responses never return secret_id_enc / secret_key_enc or plaintext secrets.
sms_configs / sms_templates / sms_logs all include is_del; every read path filters is_del=2.
sms_logs never store SMS body, verification plaintext, template params, raw request, or raw response.
Tencent Cloud SDK imports are confined to internal/infra/sms/tencentcloudsms.
SendSms uses SmsSdkAppId, SignName, TemplateId, TemplateParamSet, PhoneNumberSet, Region, and Endpoint.
Tencent SDK calls use context plus a default 10s timeout.
Each send creates one pending log before the Tencent call and finishes the same log as success or failed.
Verification-code templates must include exactly code and ttl_minutes.
ttl_minutes for SMS verification and SMS test-send comes from sms_configs.verify_code_ttl_minutes.
```

### Page Init

`GET /api/admin/v1/sms/page-init`

Response `data.dict`:

```ts
interface SmsPageInitDict {
  common_status_arr: Array<{ label: string; value: 1 | 2 }>
  sms_scene_arr: Array<{ label: string; value: 'login' | 'forget' | 'bind_phone' | 'change_password' }>
  sms_log_scene_arr: Array<{ label: string; value: 'login' | 'forget' | 'bind_phone' | 'change_password' | 'test' }>
  sms_log_status_arr: Array<{ label: string; value: 1 | 2 | 3 }>
  sms_region_arr: Array<{ label: string; value: 'ap-guangzhou' }>
  default_region: 'ap-guangzhou'
  default_endpoint: 'sms.tencentcloudapi.com'
  default_ttl_minutes: number
}
```

### Config

```text
GET    /api/admin/v1/sms/config
PUT    /api/admin/v1/sms/config
DELETE /api/admin/v1/sms/config
POST   /api/admin/v1/sms/test
```

`GET /sms/config` response:

```ts
interface SmsConfigResponse {
  id: number | null
  configured: boolean
  secret_id_hint: string
  secret_key_hint: string
  sms_sdk_app_id: string
  sign_name: string
  region: 'ap-guangzhou'
  endpoint: string
  status: 1 | 2
  verify_code_ttl_minutes: number
  last_test_at: string | null
  last_test_error: string
  created_at: string | null
  updated_at: string | null
}
```

`PUT /sms/config` body accepts plaintext `secret_id` / `secret_key` only as write-only inputs. First setup requires both. Later updates may leave them blank to reuse the current encrypted values. It also accepts `verify_code_ttl_minutes: number`; the value is saved to `sms_configs.verify_code_ttl_minutes`.

Rules:

```text
config_key is fixed to default.
DELETE is a soft delete of the active default row.
PUT restores a soft-deleted default row instead of inserting a duplicate.
region only accepts ap-guangzhou in phase one; default is ap-guangzhou.
endpoint defaults to sms.tencentcloudapi.com.
status=1 enables real test sending; status=2 disables it explicitly.
POST /sms/test accepts one to_phone and one template_scene, normalizes mainland phone numbers to +86 E.164, uses sample verification-code params, and updates last_test_at / last_test_error.
```

### Templates

```text
GET    /api/admin/v1/sms/templates
POST   /api/admin/v1/sms/templates
PUT    /api/admin/v1/sms/templates/:id
PATCH  /api/admin/v1/sms/templates/:id/status
DELETE /api/admin/v1/sms/templates/:id
```

Template item:

```ts
interface SmsTemplateItem {
  id: number
  scene: 'login' | 'forget' | 'bind_phone' | 'change_password'
  name: string
  tencent_template_id: string
  variables: string[]
  sample_variables: Record<string, string>
  status: 1 | 2
  created_at: string
  updated_at: string
}
```

Rules:

```text
This system does not edit Tencent SMS body. It maps local scenes to approved Tencent TemplateId.
Verification-code template variables must be exactly `code` and `ttl_minutes`; `sample_variables` must contain exactly the same two keys. Extra keys such as `app_name` are rejected.
scene is unique; saving a soft-deleted scene restores the old row.
DELETE is soft delete.
```

### Logs

```text
GET    /api/admin/v1/sms/logs
GET    /api/admin/v1/sms/logs/:id
DELETE /api/admin/v1/sms/logs/:id
DELETE /api/admin/v1/sms/logs        body: { ids: number[] }
```

Query:

```ts
interface SmsLogQuery {
  current_page: number
  page_size: number
  scene?: 'login' | 'forget' | 'bind_phone' | 'change_password' | 'test'
  status?: 1 | 2 | 3
  to_phone?: string
  created_at_start?: string
  created_at_end?: string
}
```

Log item:

```ts
interface SmsLogItem {
  id: number
  scene: string
  template_id: number | null
  to_phone: string
  status: 1 | 2 | 3
  tencent_request_id: string
  tencent_serial_no: string
  tencent_fee: number
  error_code: string
  error_message: string
  duration_ms: number
  sent_at: string | null
  created_at: string
  updated_at: string
  template?: {
    id: number
    scene: 'login' | 'forget' | 'bind_phone' | 'change_password'
    name: string
    tencent_template_id: string
    variables: string[]
    status: 1 | 2
  } | null
}
```

Rules:

```text
status: 1=pending, 2=success, 3=failed.
Logs store provider RequestId/SerialNo/Fee, error code/message, duration and timestamps only.
Detail may include a template summary so humans can identify the Tencent TemplateId and variable names used by the send.
No body, plaintext verification value, template params, raw request, or raw response field is present in DB/API/frontend contract.
DELETE is soft delete.
```

Operation log / permission:

```text
PUT    /sms/config                 -> system_sms_configEdit, module=sms, action=update_config
DELETE /sms/config                 -> system_sms_configDel, module=sms, action=delete_config
POST   /sms/test                   -> system_sms_test, module=sms, action=test_send
POST   /sms/templates              -> system_sms_templateAdd, module=sms, action=create_template
PUT    /sms/templates/:id          -> system_sms_templateEdit, module=sms, action=update_template
PATCH  /sms/templates/:id/status   -> system_sms_templateStatus, module=sms, action=change_template_status
DELETE /sms/templates/:id          -> system_sms_templateDel, module=sms, action=delete_template
DELETE /sms/logs/:id and /logs     -> system_sms_logDel, module=sms, action=delete_log/delete_logs
```

## Payment

状态：payment config rebuild v1 + recharge cashier v1 + recharge completion closure implemented in Go backend, adapted in Vue frontend。Wallet recharge/consume v1 另见下一节 `Wallet`。

用途：当前 payment active scope 只做支付宝支付配置、充值收银台和充值完成闭环：配置 CRUD、私有证书上传、本地配置测试、套餐充值、后端自动选择可用支付宝配置、创建底层支付单、拉起 web/h5 支付、手动同步状态、支付宝正式异步回调、支付中订单定时补偿同步、过期订单定时关闭、钱包余额幂等入账。退款、提现、对账、微信、订阅权益不属于 payment slice；用户消费扣款属于 wallet slice，不进入 `payment_orders`。

### Shared Rules

```text
resource prefix: /api/admin/v1/payment
backend owner: internal/module/payment
gateway boundary: internal/infra/payment/alipay
provider scope: Alipay only
active payment tables: payment_configs, payment_orders, payment_recharge_packages, payment_recharges, payment_callback_events
shared wallet tables touched by recharge credit: user_wallets, wallet_transactions
active pages: /payment/config, /payment/recharge, /payment/orders
order page: /payment/orders is a product-visible Alipay/gateway collection-order ledger; raw create UX stays hidden
cert storage: runtime/payment/certs/alipay/<config_code>/<sha256>.crt
public callback: POST /api/payment/callbacks/alipay
```

硬规则：

```text
Alipay only.
No refund/reconcile/WeChat/subscription runtime contract in this slice.
Public Alipay callback is POST /api/payment/callbacks/alipay; old notify paths are retired.
payment_configs.sort selects the preferred enabled Alipay config; lower sort wins, then lower id.
payment_configs has no return_url; recharge create computes return_url per payment.
Users do not submit config_code, app_id, subject, amount_yuan, expire_minutes, or handwritten return_url on the recharge page.
paid/credited state can only be written by verified Alipay callback, manual Alipay query/sync, or the payment sync-pending cron path that reuses the same finalizer.
wallet credit is DB-transactional and idempotent through wallet_transactions(source_type, source_id).
private_key_enc and plaintext app_private_key never appear in API response, operation log, smoke output, or frontend types.
Certificate content is never returned; API only stores private relative cert paths.
No cert public URL and no certificate download route.
merchant_id, sign_type, extra_config are banned from this active contract.
```

### Routes

Config routes:

```text
GET    /api/admin/v1/payment/configs/page-init
GET    /api/admin/v1/payment/configs
POST   /api/admin/v1/payment/configs
PUT    /api/admin/v1/payment/configs/:id
PATCH  /api/admin/v1/payment/configs/:id/status
DELETE /api/admin/v1/payment/configs/:id
POST   /api/admin/v1/payment/certificates
POST   /api/admin/v1/payment/configs/:id/test
```

Recharge routes:

```text
GET    /api/admin/v1/payment/recharges/page-init
GET    /api/admin/v1/payment/recharges
GET    /api/admin/v1/payment/recharges/:id
POST   /api/admin/v1/payment/recharges
POST   /api/admin/v1/payment/recharges/:id/pay
POST   /api/admin/v1/payment/recharges/:id/sync
PATCH  /api/admin/v1/payment/recharges/:id/close
```

Payment order routes back the product-visible `/payment/orders` ledger. The Vue page exposes list/detail/pay/sync/close operations, but still does not expose raw create UX:

```text
GET    /api/admin/v1/payment/orders/page-init
GET    /api/admin/v1/payment/orders
GET    /api/admin/v1/payment/orders/:id
POST   /api/admin/v1/payment/orders              # backend/internal capability; raw create UX not exposed by product page
POST   /api/admin/v1/payment/orders/:id/pay
POST   /api/admin/v1/payment/orders/:id/sync
PATCH  /api/admin/v1/payment/orders/:id/close
```

No order edit/delete endpoints exist in this slice.

Public callback route:

```text
POST   /api/payment/callbacks/alipay
```

Callback contract:

```text
Content-Type: application/x-www-form-urlencoded
AuthToken: skip
RBAC: none
OperationLog: none
Response success: text/plain; charset=utf-8 body success
Response failure: text/plain; charset=utf-8 body fail
```

Callback rules:

```text
invalid signature -> payment_callback_events.failed -> fail -> no business mutation
unknown out_trade_no -> payment_callback_events.ignored -> success -> no business mutation
app_id mismatch -> payment_callback_events.failed -> fail -> no business mutation
amount mismatch -> payment_callback_events.failed -> fail -> no business mutation
TRADE_SUCCESS / TRADE_FINISHED -> shared paid finalizer -> order paid + recharge credited -> success
WAIT_BUYER_PAY / other non-success -> payment_callback_events.ignored -> success -> no business mutation
internal finalize error -> payment_callback_events.failed -> fail, so Alipay can retry
```

### Config Contract

`payment/configs` 管理 `payment_configs`。写入必须带 `provider=alipay`，可以接收 `app_private_key` 明文，但后端只加密保存 `private_key_enc` 和可展示的 `private_key_hint`。列表返回 provider/provider_text、hint、证书私有相对路径、环境、启用方式、优先级、状态和备注。

字段第一版用途固定：

```text
provider: 支付供应商，当前只允许 alipay，参与列表筛选、展示和本地测试分发。
code: 配置唯一编码，创建后不可改，证书私有目录也用它分桶。
name: 后台展示名。
app_id: 支付宝应用 ID，构建 SDK client 必需。
private_key_enc: 服务端 secretbox 加密后的应用私钥，只写入和本地测试使用，永不返回。
private_key_hint: 展示“已配置私钥”的安全提示。
app_cert_path / platform_cert_path / root_cert_path: 本地私有证书相对路径，启用、测试、支付、同步和回调验签前必须能解析到文件。
notify_url: 支付宝异步通知地址配置值；应指向 public callback route `/api/payment/callbacks/alipay`。
environment: sandbox / production，构建支付宝客户端时使用。
enabled_methods_json: 当前只允许 web / h5；充值按设备选择 web/h5 后用它过滤配置。
sort: 支付配置优先级，充值自动选择时按 sort ASC, id ASC。
status: 1 启用、2 禁用；启用前必须通过本地配置测试；禁用配置不参与充值支付。
remark: 后台备注。
is_del / created_at / updated_at: 基础三字段。
```

### Recharge Contract

`payment/recharges` 管理用户充值单。用户看到的是套餐、支付宝、余额和充值记录；底层 `payment_orders` 只是网关支付单，不再作为用户手工创建入口。

创建请求只允许：

```json
{
  "package_code": "recharge_100",
  "pay_method": "web",
  "return_url": "http://localhost:8080/payment/recharge"
}
```

明确没有：

```text
config_code
app_id
subject
amount_yuan
amount_cents
expire_minutes
user_id
```

`return_url` 是前端根据当前 `/payment/recharge` 路由自动生成的基准地址，不是表单字段。后端创建充值单后追加：

```text
?tab=records&recharge_no=<recharge_no>
```

充值状态：

```text
pending
paying
paid
credited
closed
failed
```

状态写入规则：

```text
Create -> pending, then Pay -> paying or failed
Pay pending/failed -> paying or failed
Pay paying with pay_url -> return existing pay_url
Sync paying + payment_order paid -> paid -> credited
Sync paid -> credited
Sync waiting -> still paying
Sync closed -> closed
Close pending/failed/paying -> closed
Close paid/credited -> reject
Repeat sync credited -> return credited, no second wallet credit
```

新增表字段第一版用途固定：

```text
payment_recharge_packages.code/name/amount_cents/badge/sort/status: page-init 套餐展示和创建充值单的金额事实源。
payment_recharges.recharge_no/user_id/package_code/package_name/amount_cents/payment_order_id/status/paid_at/credited_at/failure_reason: 充值记录、return_url 回跳识别、callback/sync/cron 共用状态机和入账审计。
payment_callback_events.provider/notify_id/out_trade_no/trade_no/trade_status/app_id/total_amount_cents/signature_valid/process_status/process_message/raw_payload_json/received_at/processed_at: 支付宝回调审计事实；不作为支付业务真相源。
user_wallets.user_id/balance_cents/total_recharge_cents/total_consume_cents: 充值页余额展示；充值入账时原子增加 balance/total_recharge，消费由 wallet slice 原子扣减 balance/增加 total_consume。
wallet_transactions.transaction_no/wallet_id/user_id/direction/amount_cents/balance_before_cents/balance_after_cents/source_type/source_id/remark: 钱包流水审计和 `(source_type, source_id)` 幂等约束；充值写 `direction=in/source_type=recharge`，消费写 `direction=out/source_type=consume`。
is_del / created_at / updated_at: 每张新增表都有并参与过滤、排序或审计展示。
```

### Order Contract

`payment/orders` 管理 `payment_orders`。它是底层支付订单 runtime：创建本地订单、拉起支付宝支付、手动同步支付宝状态、关闭未支付订单。充值服务会内部创建它；Vue 产品入口不再暴露“新增支付订单”表单。订单金额创建后不能编辑，后台不能手工改成 paid。

订单状态：

```text
pending
paying
paid
closed
failed
```

关键字段用途：

```text
order_no: 本地支付订单号，同时作为支付宝 out_trade_no。
config_id/config_code: 绑定 payment_configs，pay/sync/close 用它取证书和 app_id。
provider/pay_method/subject/amount_cents/status/pay_url/return_url/alipay_trade_no/expired_at/paid_at/closed_at/failure_reason: 支付宝支付闭环状态。
is_del / created_at / updated_at: 基础三字段，repository 查询固定 is_del=2。
```

### Certificate Upload Contract

`POST /api/admin/v1/payment/certificates` 是私有本地证书上传，不走 COS，不生成 public URL。multipart 字段：

```text
config_code: payment_configs.code
cert_type: app_cert | alipay_cert | alipay_root_cert
file: .crt 或 .pem 文件
```

响应只返回：

```text
path, file_name, sha256, size
```

### Config Test Contract

`POST /api/admin/v1/payment/configs/:id/test` 只做本地配置校验：解密私钥、解析三份证书路径、构建支付宝 SDK client。默认 smoke 不调用真实支付宝网关，不上传证书。

### Active Menu and Permission Codes

```text
PAGE   payment_config_list           /payment/config view_key=payment/config
BUTTON payment_config_add
BUTTON payment_config_edit
BUTTON payment_config_status
BUTTON payment_config_del
BUTTON payment_config_upload_cert
BUTTON payment_config_test

PAGE   payment_recharge_list         /payment/recharge view_key=payment/recharge
BUTTON payment_recharge_add
BUTTON payment_recharge_pay
BUTTON payment_recharge_sync
BUTTON payment_recharge_close

PAGE   payment_order_list            /payment/orders view_key=payment/orders show_menu=1
BUTTON payment_order_add             # backend/internal raw create capability; Vue raw create UX stays retired
BUTTON payment_order_pay
BUTTON payment_order_sync
BUTTON payment_order_close
```

`payment_recharge_*` 是产品可见充值入口权限，迁移脚本默认补给 active admin roles；`payment_order_*` 是产品可见支付订单/支出流水权限，但仍按角色单独授权，不跟随充值入口自动扩散。

### Retired From Active Product Runtime

```text
payment_channel_* permissions and channel menu
payment_event_* permissions and event menu
old pay_* permissions and legacy root-only wallet route
/payment/orders raw create UX
PaymentOrderFormDialog raw create UX
/api/admin/v1/payment/channels*
/api/admin/v1/payment/events*
/api/payment/notify/alipay
refund / WeChat / subscription / reconcile features
```

## Wallet

状态：wallet recharge/consume v1 implemented in Go backend, adapted in Vue frontend。

用途：钱包只回答“余额是多少、怎么变的”。产品语言固定为：

```text
支付订单 = 支付宝/第三方收款订单，给管理、财务、技术排障看。
充值记录 = 用户充值业务记录，给用户看“我充了没有、到账没有”。
钱包流水 = 余额变化事实，充值入账和消费扣款都在这里。
```

### Shared Rules

```text
resource prefix: /api/admin/v1/wallet
backend owner: internal/module/payment/wallet
active tables: user_wallets, wallet_transactions
current-user pages: /wallet/transactions
admin pages: /wallet/users, /wallet/ledger
```

硬规则：

```text
Wallet v1 只做充值入账后的余额展示、资金流水查询和即时消费扣款。
Consume 不创建 payment_orders；用户支出看 wallet_transactions(direction=out, source_type=consume)。
amount_cents 永远为正数，收支方向由 direction 表达。
余额变更必须在一个 DB transaction 内写 user_wallets 和 wallet_transactions。
source_type + source_id 全局幂等；重复 consume source 返回已有流水，不重复扣款。
余额不足不写 wallet_transactions。
本 slice 不做 refund / withdraw / freeze / adjustment / reconcile / currency / points / membership fulfillment。
```

### Routes

Current-user wallet center:

```text
GET  /api/admin/v1/wallet/summary
GET  /api/admin/v1/wallet/transactions
POST /api/admin/v1/wallet/consumptions
```

Admin wallet management:

```text
GET /api/admin/v1/wallet/users/page-init
GET /api/admin/v1/wallet/users
GET /api/admin/v1/wallet/ledger/page-init
GET /api/admin/v1/wallet/ledger
```

### Data Contract

`GET /wallet/summary`:

```json
{
  "balance_cents": 0,
  "balance_text": "0.00",
  "total_recharge_cents": 0,
  "total_recharge_text": "0.00",
  "total_consume_cents": 0,
  "total_consume_text": "0.00"
}
```

`GET /wallet/transactions` returns current-user rows only. `GET /wallet/ledger` returns admin rows and supports filters:

```text
current_page, page_size
keyword: transaction_no / remark / user account prefix search
user_id: ledger only
direction: in | out
source_type: recharge | consume
date_start, date_end
```

Transaction item:

```text
id, transaction_no, user_id, username, account
direction, direction_text
amount_cents, amount_text
balance_before_cents, balance_before_text
balance_after_cents, balance_after_text
source_type, source_type_text, source_id
remark, created_at
```

`GET /wallet/users` returns:

```text
id, wallet_id, user_id, username, account
balance_cents, balance_text
total_recharge_cents, total_recharge_text
total_consume_cents, total_consume_text
updated_at
```

`POST /wallet/consumptions` request:

```json
{
  "amount_cents": 100,
  "source_id": 12345,
  "remark": "test consume"
}
```

Response:

```text
transaction: wallet transaction item
wallet: same shape as /wallet/summary
```

### Active Menu and Permission Codes

```text
DIR    wallet_center               /wallet show_menu=1
PAGE   wallet_transaction_list     /wallet/transactions view_key=wallet/transactions show_menu=1
BUTTON wallet_consume_add          hidden button permission for POST /wallet/consumptions

DIR    wallet_manage               /wallet-manage show_menu=1
PAGE   wallet_user_list            /wallet/users view_key=wallet/users show_menu=1
PAGE   wallet_ledger_list          /wallet/ledger view_key=wallet/ledger show_menu=1
```

迁移脚本默认把 wallet read pages 授给已有支付权限角色；`wallet_consume_add` 不默认授予，避免默认 smoke 或普通管理浏览触发真实扣款。

## Upload Config

状态：implemented in Go backend, adapted in Vue frontend。

用途：后台上传配置页的三类事实源：上传驱动、上传规则、启用配置。这里只做配置管理，不做 `/api/getUploadToken`、云 STS、服务端上传或 SDK 接入。配置事实只允许 `cos` driver；OSS 不是 active runtime，V1 不可选。

### Shared Rules

所有接口都在后台命名空间：

```text
/api/admin/v1
```

字典来源：

```text
internal/shared/enum -> internal/shared/dict
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
upload config CRUD accepts only Tencent COS in V1.
`driver` accepts only `cos`.
`bucket_domain` is an optional bare host such as `cos.example.com`; clients must not send `http://` or `https://`.
Default in-repo backend/frontend dependencies include COS runtime only.
OSS is not an active runtime and is not selectable in V1; do not silently fallback to COS, legacy runtime, or fake success.
```

### Upload Drivers

#### Init

`GET /api/admin/v1/upload-drivers/init`

Response `data.dict`：

```ts
interface UploadDriverInitDict {
  upload_driver_arr: Array<{ label: string; value: 'cos' }>
}
```

#### List

`GET /api/admin/v1/upload-drivers`

Query：

```ts
interface UploadDriverListQuery {
  current_page: number
  page_size: number
  driver?: 'cos'
}
```

Response `data`：

```ts
interface UploadDriverListResponse {
  list: Array<{
    id: number
    driver: 'cos'
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
interface UploadDriverCreateBody {
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
```

Update body：

```ts
interface UploadDriverUpdateBody {
  driver: 'cos'
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
driver 只接受 `cos`；非 COS 返回“当前仅支持腾讯云 COS，请重新配置 COS”。
cos 必须 appid。
`bucket_domain` 是可选裸域名，例如 `cos.example.com`；客户端不能提交 `http://` 或 `https://`，也不能提交路径、query 或 fragment。
OSS is not an active runtime and is not selectable in V1.
被 upload_setting 引用的 driver 不能删除.
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
允许系统暂时没有 enabled upload setting；upload token 接口必须显式报未配置，而不是兜底。upload runtime is Tencent COS-only；`bucket_domain` 存储裸域名并由 runtime 构造 HTTPS public URL。OSS is not an active runtime and is not selectable in V1。
```

## Upload Runtime Tokens

状态：implemented in Go backend, adapted in shared Vue upload client。

用途：给浏览器直传腾讯云 COS 签发临时凭证和服务端生成的 object key。它不是服务端上传接口，也不是旧 `/api/getUploadToken` 的兼容兜底。

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
Only Tencent COS runtime is implemented.
OSS is not an active runtime and is not selectable in V1.
No legacy /api/getUploadToken fallback.
folder must come from internal/shared/enum.UploadFolders.
file_name is used only for extension validation and safe display suffix; object key is generated by the server.
file_size is bytes and must be > 0.
file_kind=image validates against image_exts; file_kind=file validates against file_exts.
Generated key format: {folder}/{yyyy}/{mm}/{dd}/{unix_ms}-{randomhex}-{safe_file_name}.
STS policy is scoped to the generated key resource, not the whole bucket.
`bucket_domain` in the response is a bare host from upload config, and clients build HTTPS public URLs from it.
Response never exposes upload_driver secret_id/secret_key plaintext.
Upload token TTL comes from system_settings.upload.token.ttl_minutes.
Tencent STS API endpoint/region are code-owned platform defaults, not upload config fields; upload config Region remains the COS bucket region.
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
COS STS provider failure              -> code 500 / COS 临时凭证签发失败
```


## System Logs

系统日志是运行时文件日志的只读浏览接口，不等于 `operation-logs`。`operation-logs` 记录后台用户操作审计并落库；`system-logs` 只读取 Go 进程写出的结构化文件日志。

文件策略：

```text
admin-api    -> runtime/logs/admin-api.log
admin-worker -> runtime/logs/admin-worker.log
```

文件输出使用 lumberjack 轮转，代码默认值固定为：

```text
file_max_size_mb=64
file_max_backups=7
file_max_age_days=14
file_compress=true
```

所以不是一个 `admin-api.log` 无限增长。Docker-first env 只保留 `LOG_DIR` 作为部署路径；`admin-api.log` / `admin-worker.log` 文件名、轮转策略、`.log` 白名单和 2000 行 tail 上限都是代码内置默认值。

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

- `tail`: 1-2000, capped again by the code-owned max tail limit 2000.
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
.env 只保存 `APP_SECRET` 和 `TOKEN_REDIS_DB` 这类认证/session 部署基础项；token Redis prefix `token:`、session cache TTL `30m`、single-session pointer TTL `720h` 是代码内置默认。access_ttl / refresh_ttl 仍以 auth_platforms 表为业务事实源。
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
字典由 Go internal/shared/enum -> internal/shared/dict 派生，前端不手写 fallback label
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
method/path 是否符合 RESTful resource，不是旧动作式 path。
是否写明 auth requirement：public / bearer token / permission code。
request query/body 是否有 TypeScript shape。
response data 是否有 TypeScript shape 或 JSON example。
错误场景是否写清：参数错误、权限失败、资源不存在、业务冲突。
dict/init 是否写明 enum 来源：internal/shared/enum -> internal/shared/dict。
前端调用是否使用 request，不使用 legacyRequest；如处于已批准的历史兼容边界，必须写清退出条件。
是否需要 operation log route metadata；需要就同步 route_meta 和本文。
是否需要 smoke 覆盖；需要就同步 smoke matrix。
```

## System Cron Tasks

状态：implemented in this slice。系统管理定时任务已经从 legacy `/api/admin/CronTask/*` 收口到 Go REST。`handler` 不是 Go 运行时执行入口；已接入 Go registry 的任务返回/保存版本化 Asynq task type，未注册到 Go registry 的旧 handler 字符串只作为 legacy provenance 展示。

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

name: ai_run_timeout
Asynq task type: ai:run-timeout:v1

name: payment_sync_pending_order
Asynq task type: payment:sync-pending-order:v1

name: payment_close_expired_order
Asynq task type: payment:close-expired-order:v1
```

未注册的历史任务不注册假任务，也不再通过列表展示“接入状态/旧处理器”迁移态标签；已确认废弃的 `clean_expired_contact_request` 通过 `20260521_cron_task_active_cleanup.sql` 从 active rows 软删除。当前支付闭环只注册支付宝充值完成补偿任务；wallet/refund/reconcile/WeChat 没有本阶段 registry 合同。

当前数据迁移：

```text
database/migrations/20260506_cron_task_go_handler_cleanup.sql
notification_task_scheduler.handler = notification:dispatch-due:v1

AI runtime migration (2026-05-08)
ai_run_timeout.handler = ai:run-timeout:v1

payment recharge completion closure migration (2026-05-21)
payment_sync_pending_order.handler = payment:sync-pending-order:v1
payment_close_expired_order.handler = payment:close-expired-order:v1

active cron cleanup migration (2026-05-21)
clean_expired_contact_request.status = 2
clean_expired_contact_request.is_del = 1
notification_task_scheduler.handler = notification:dispatch-due:v1
ai_run_timeout.handler = ai:run-timeout:v1
payment_sync_pending_order.handler = payment:sync-pending-order:v1
payment_close_expired_order.handler = payment:close-expired-order:v1
```

`ai_run_timeout` 是 stale-run sweeper only：worker 只处理超过代码内置 AI run stale timeout 默认值的残留 `running` 运行，不负责正常在线流式请求超时。

支付定时任务只做最终一致性补偿：`payment_sync_pending_order` 扫描支付中支付宝订单并复用手动 sync / callback 的 paid finalizer；`payment_close_expired_order` 扫描过期未支付订单并关闭本地/支付宝订单。支付宝返回 `ACQ.TRADE_NOT_EXIST` 且本地订单已过期时按未支付过期处理，同步关闭本地支付订单和关联充值单。

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
interface CronTaskItem {
  id: number
  name: string
  title: string
  description: string
  cron: string
  cron_readable: string
  handler: string // API 语义：任务类型 task type；已知 Go registry 任务返回版本化 Asynq task type
  status: number
  status_name: string
  next_run_time: string
  created_at: string
  updated_at: string
}
```

规则：

```text
name 是 Go registry key，新增后不允许编辑修改。
已知 Go registry 任务的 handler 由 Go registry task type 覆盖，前端列名展示为“任务类型”。
公共列表不再返回 registry_status / registry_task_type / registry_description 迁移态字段，也不再支持 registry_status 筛选。
```

注意：修改 `cron_task` 配置后，已运行的 `admin-worker` 不热重载 schedule；需要重启 worker 或后续引入显式 reload/分布式锁策略。不要在 admin-api handler 里启动 cron。

## Client Versions

状态：implemented. 业务名称是“客户端版本”；Go REST 使用 `ClientVersionApi`，DB 表统一为 `client_versions`，前端视图目录和 i18n key 使用 `clientVersion`，mutation 权限 code 统一为 `system_clientVersion_*`。旧 Tauri 表名/权限名只允许出现在cleanup SQL 的 source condition 或 legacy source reference说明里，不是新契约。菜单 PAGE route/component/i18n_key 通过 `20260507_client_version_permission_route_cleanup.sql` 收口到 `system/clientVersion`。

### Shared Rules

命名空间：

```text
/api/admin/v1/client-versions
```

字典来源：

```text
internal/shared/enum.ClientPlatform* -> internal/shared/dict.ClientVersionPlatformOptions
internal/shared/enum.CommonYes/CommonNo -> internal/shared/dict.CommonYesNoOptions
internal/shared/validate.client_platform + common_yes_no
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
clientversion.Service -> ManifestPublisher small interface -> ManifestCOSPublisher -> internal/infra/storage/cos.ObjectWriter -> github.com/tencentyun/cos-go-sdk-v5
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
