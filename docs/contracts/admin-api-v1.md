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
| auth config/captcha/code/login/refresh | `/api/admin/v1/auth/login-config`, `/captcha`, `/send-code`, `/login`, `/refresh` | public |
| logout | `POST /api/admin/v1/auth/logout` | bearer token |
| current user bootstrap | `GET /api/admin/v1/users/me`, `GET /api/admin/v1/users/init` | bearer token |
| read-only admin resources | permissions/auth-platforms/roles/users/profile/operation-logs/system-settings/upload-drivers/upload-rules/upload-settings/notifications list or init | bearer token |
| current user notifications | `GET/PATCH/DELETE /api/admin/v1/notifications...` | bearer token; current-user ownership only, no RBAC button permission |
| permission mutations | permissions create/update/status/delete | bearer token + `permission_permission_*` route permission |
| role mutations | roles create/update/default/delete | bearer token + `permission_role_*` route permission |
| auth platform mutations | auth-platforms create/update/status/delete | bearer token + `permission_authPlatform_*` route permission |
| user mutations | users update/status/batch/delete | bearer token + `user_userManager_*` route permission |
| operation log delete | operation-logs delete/batch delete | bearer token + `devTools_operationLog_del` route permission |
| system setting mutations | system-settings create/update/status/delete | bearer token + `system_setting_*` route permission |
| upload config mutations | upload-drivers/upload-rules/upload-settings create/update/status/delete | bearer token + `system_uploadConfig_*` route permission |
| upload token create | `POST /api/admin/v1/upload-tokens` | bearer token + `system_uploadToken_create` route permission |
| notification task mutations | notification-tasks create/cancel/delete | bearer token + `system_notificationTask_*` route permission |
| current profile update | `PUT /api/admin/v1/profile` | bearer token; operation log only, no user-manager button permission |

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
  | { scene: 'login'; login_type: 'email'; account: string }
  | { scene: 'login'; login_type: 'phone'; account: string }
```

Response example：

```json
{ "code": 0, "data": {}, "msg": "ok" }
```

规则：local dev 可使用 `VERIFY_CODE_DEV_MODE=true` 和 `VERIFY_CODE_DEV_CODE`；production 不允许假装已接真实短信/邮件。

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

状态：implemented in Go backend, adapted in Vue frontend for list/page-init/edit/batch-edit/delete/status。Export 仍是显式 legacy adapter，等待 Go export-task 模块迁移。

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
DB 写入 + Redis enqueue 当前不是强事务；enqueue 失败会返回明确错误，任务仍留 pending。`notification-task-dispatch-due` 会补偿 `send_at IS NULL` 的立即 pending 任务和到期定时任务。后续强一致用 outbox。
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
schedule:  notification-task-dispatch-due every 1m
queue lane: default
```

边界：

```text
admin-api 只处理 HTTP，不消费队列，不跑 cron。
admin-worker 才拥有 Asynq server 和 gocron scheduler。
scheduler callback 只能 enqueue dispatch-due task，不能扫描 DB 或发通知。
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
VAULT_KEY 为空时写入 secret 会明确失败，不做假加密。
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

Auth: bearer token + `system_uploadToken_create` route permission.

Request:

```ts
interface UploadTokenRequest {
  folder: 'avatars' | 'images' | 'videos' | 'cover_images' | 'ai_chat_images' | 'releases' | 'tauri_updater' | 'exports' | 'goods_tts' | 'chat_images' | 'chat_files' | 'reconcile_reports' | 'cine_keyframes'
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
    { "name": "admin-api.log", "size": 1024, "size_human": "1.00 KB", "mtime": "2026-05-04 19:30:00" }
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
.env 只保存 TOKEN_PEPPER、TOKEN_REDIS_PREFIX、TOKEN_REDIS_DB、TOKEN_SESSION_CACHE_TTL、TOKEN_SINGLE_SESSION_POINTER_TTL 这类运行时基础设施配置
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
