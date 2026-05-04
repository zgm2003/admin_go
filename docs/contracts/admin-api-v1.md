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
| read-only admin resources | permissions/auth-platforms/roles/users/operation-logs list or init | bearer token |
| permission mutations | permissions create/update/status/delete | bearer token + `permission_permission_*` route permission |
| role mutations | roles create/update/default/delete | bearer token + `permission_role_*` route permission |
| auth platform mutations | auth-platforms create/update/status/delete | bearer token + `permission_authPlatform_*` route permission |
| user mutations | users update/status/batch/delete | bearer token + `user_userManager_*` route permission |
| operation log delete | operation-logs delete/batch delete | bearer token + `devTools_operationLog_del` route permission |

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
敏感字段会在 Go backend 里遮蔽，至少包括 password/token/captcha/captcha_answer/code。
delete permission code 是 devTools_operationLog_del。
DELETE 只走 REST: /api/admin/v1/operation-logs/:id 和 /api/admin/v1/operation-logs body { ids: number[] }。
```

## Auth Platform

状态：implemented in Go backend, adapted in Vue frontend。

用途：管理认证平台登录方式、验证码策略、token TTL、会话绑定策略和自动注册策略。

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
