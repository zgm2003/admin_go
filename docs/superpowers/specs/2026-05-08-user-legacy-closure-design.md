# User Legacy Closure Design

状态：implemented on 2026-05-08。本文定义并记录今天收口的 User 侧剩余 PHP legacy 切片；验证证据以 plan 尾部和当前 docs/migration/current-status.md 为准。
日期：2026-05-08

## Linus 三问

1. 真问题：是。当前用户域已经有 Go auth/users/profile/session read-only，但首页快捷入口、登录日志、会话踢下线还在 PHP legacy；这些是可见后台功能，不收口就没法进入全量测试。
2. 更简单做法：只迁真实仍被前端调用的窄切片。`forgetPassword` 已归账号安全后续 slice；`EditPassword` 当前只剩 API 定义，先做删除确认，不把死接口迁成 Go 垃圾。
3. 会破坏什么：不能破坏 `users/init` 返回的 `quick_entry` 字段，不能泄漏 token hash，不能允许管理员踢掉自己当前会话，不能把 PHP `/list`/`/add` 风格带进 Go REST。

## 当前运行事实

### 已迁 Go

```text
GET /api/admin/v1/users/me
GET /api/admin/v1/users/init
GET /api/admin/v1/users/page-init
GET /api/admin/v1/users
PUT/PATCH/DELETE /api/admin/v1/users...
GET /api/admin/v1/profile...
PUT /api/admin/v1/profile/security/password|email|phone
GET /api/admin/v1/user-sessions/page-init
GET /api/admin/v1/user-sessions
GET /api/admin/v1/user-sessions/stats
PUT /api/admin/v1/users/me/quick-entries
GET /api/admin/v1/users/login-logs/page-init
GET /api/admin/v1/users/login-logs
PATCH /api/admin/v1/user-sessions/:id/revoke
PATCH /api/admin/v1/user-sessions/revoke
```

`user-sessions` 已从 read-only 扩到 revoke 写路径；当前会话 anti-kick、Redis token/pointer 清理和 OperationLog 都属于本次收口。

### 本次收口前的 PHP 前端入口

```text
admin_front_ts/src/api/user/usersQuickEntry.ts
  legacyRequest.post('/api/admin/UsersQuickEntry/save')

admin_front_ts/src/api/user/usersLoginLog.ts
  legacyRequest.post('/api/admin/UsersLoginLog/init')
  legacyRequest.post('/api/admin/UsersLoginLog/list')

admin_front_ts/src/api/user/users.ts
  legacyRequest.post('/api/Users/forgetPassword')
  legacyRequest.post('/api/Users/EditPassword')
  legacyRequest.post('/api/admin/UserSession/kick')
  legacyRequest.post('/api/admin/UserSession/batchKick')
```

收口后：quick-entry、login-log、session kick/batchKick 前端均改为 Go REST；`forgetPassword` 仍作为账号安全后续 slice 保持 legacy；`EditPassword` 死定义删除。

### Live DB 事实

```text
users_quick_entry: 24
users_login_log: 740
user_sessions: 749
```

权限事实：

```text
/user/usersLoginLog id=8 type=PAGE status=1 is_del=2
user_userManager_kick id=11 type=BUTTON status=1 is_del=2
```

## Scope

### 必须迁 Go

```text
Quick entry:
PUT /api/admin/v1/users/me/quick-entries

Login log:
GET /api/admin/v1/users/login-logs/page-init
GET /api/admin/v1/users/login-logs

User session revoke:
PATCH /api/admin/v1/user-sessions/:id/revoke
PATCH /api/admin/v1/user-sessions/revoke
```

### 必须清理或确认

```text
/api/Users/EditPassword
```

当前只在 `admin_front_ts/src/api/user/users.ts` 里发现定义，没发现页面调用。实现前必须再跑：

```powershell
cd E:\admin_go
rg -n "EditPassword|/api/Users/EditPassword" admin_front_ts/src admin_back_go/internal E:/admin/admin_back/app
```

如果仍只有死定义，删除前端 API 类型和方法；不要迁 Go。

### 明确不做

```text
不迁 /api/Users/forgetPassword：它属于 docs/superpowers/specs/2026-05-05-account-security-design.md 后续账号安全 slice。
不改登录、注册、refresh、logout 语义。
不改 SessionList UI 样式。
不新增 DB 表。
不把 users_quick_entry 改成前端本地存储。
不返回 access_token_hash / refresh_token_hash。
```

## API Contract

### Save current user's quick entries

`PUT /api/admin/v1/users/me/quick-entries`

Auth: bearer token。

Request:

```ts
interface SaveQuickEntriesRequest {
  permission_ids: number[]
}
```

Response:

```ts
interface SaveQuickEntriesResponse {
  quick_entry: Array<{ id: number; permission_id: number; sort: number }>
}
```

Rules:

```text
permission_ids 最多 6 个。
permission_ids 必须去重后仍保持前端传入顺序。
每个 permission_id 必须存在于 permissions，platform=admin，type=PAGE，status=1，is_del=2。
保存为当前 auth user 的 users_quick_entry。
用一个 DB transaction：软删当前用户旧 quick entries，再按顺序写入 sort=1..N。
返回当前用户最新 quick_entry，字段名保持 users/init 兼容：quick_entry。
```

### Login log page-init

`GET /api/admin/v1/users/login-logs/page-init`

Response:

```ts
interface UserLoginLogInitResponse {
  dict: {
    platformArr: Array<{ label: string; value: string }>
    login_type_arr: Array<{ label: string; value: 'email' | 'phone' | 'password' }>
  }
}
```

Rules:

```text
platformArr 复用 Go platform dict。
login_type_arr 来自 auth/login config 既有登录类型；至少稳定包含当前系统支持的 email/phone/password。
```

### Login log list

`GET /api/admin/v1/users/login-logs`

Query:

```ts
interface UserLoginLogListQuery {
  current_page?: number
  page_size?: number
  user_id?: number
  login_account?: string
  login_type?: 'email' | 'phone' | 'password'
  ip?: string
  platform?: string
  is_success?: 1 | 2
  date_start?: string
  date_end?: string
}
```

Response:

```ts
interface UserLoginLogItem {
  id: number
  user_id: number | null
  user_name: string
  login_account: string
  login_type: 'email' | 'phone' | 'password'
  login_type_name: string
  platform: string
  platform_name: string
  ip: string
  ua: string
  is_success: number
  reason: string
  created_at: string
}

interface UserLoginLogListResponse {
  list: UserLoginLogItem[]
  page: { page_size: number; current_page: number; total_page: number; total: number }
}
```

Rules:

```text
Table: users_login_log AS l
Join: users AS u ON u.id = l.user_id
is_del = 2
user_id exact filter
login_account prefix filter
login_type exact filter
ip prefix filter
platform exact filter
is_success exact filter
created_at between date_start 00:00:00 and date_end 23:59:59
sort id DESC
user_name = users.username; missing user returns empty string
```

前端仍可保留 `date: string[]` 表单，但 API client 必须转换成 `date_start/date_end` query，不把数组塞给 Go。

### Revoke one session

`PATCH /api/admin/v1/user-sessions/:id/revoke`

Auth: bearer token + permission `user_userManager_kick`。

Request body: empty object or omitted。

Response:

```ts
interface RevokeUserSessionResponse {
  id: number
  revoked: boolean
}
```

Rules:

```text
id 必须存在，is_del=2。
禁止撤销当前 auth identity 的 session_id，返回 400：不能踢下线当前会话。
如果 revoked_at 已有值，返回 revoked=false，不报错，保持幂等。
否则设置 revoked_at=now。
删除 Redis access cache key: token:<access_token_hash>。
删除 Redis pointer key token:cur_sess:<platform>:<user_id> 只能在当前值等于 session id 时删除。
响应不返回 access_token_hash / refresh_token_hash。
写操作必须记录 OperationLog：module=user_session action=revoke title=踢下线用户会话。
```

### Revoke multiple sessions

`PATCH /api/admin/v1/user-sessions/revoke`

Auth: bearer token + permission `user_userManager_kick`。

Request:

```ts
interface BatchRevokeUserSessionsRequest {
  ids: number[]
}
```

Response:

```ts
interface BatchRevokeUserSessionsResponse {
  count: number
  skipped_current: number
  skipped_already_revoked: number
}
```

Rules:

```text
ids 去重，最多 100 个。
如果 ids 包含当前 session_id，不整体失败；跳过当前 session，skipped_current += 1。
对未撤销记录设置 revoked_at=now。
对已撤销记录 skipped_already_revoked += 1。
每条被撤销记录都删除 token:<access_token_hash>。
每条被撤销记录都按 compare-and-delete 规则清 token:cur_sess:<platform>:<user_id>。
count 只统计本次真正新撤销的数量。
空有效 ids 返回 count=0。
```

## Backend design

### Module split

```text
internal/module/userquickentry
  Owns users_quick_entry write for current user only.

internal/module/userloginlog
  Owns users_login_log read-only list/page-init.

internal/module/usersession
  Existing read-only module extends with revoke write path.
```

不要把 quick-entry 塞进 `internal/module/user` 巨文件里；该模块已经够大。新 slice 单独建小包，边界更清楚。

### Redis revocation boundary

当前 `session.Authenticator` 里的 key builder 是私有方法。为了不复制魔法字符串到 `usersession`，新增小边界：

```go
// internal/module/session/revoker.go
type RevocationStore interface {
  Del(ctx context.Context, key string) error
  Get(ctx context.Context, key string) (string, error)
}

type RevocationService struct { ... }
func (s *RevocationService) RevokeCache(ctx context.Context, session Session) error
func (s *RevocationService) RevokeCaches(ctx context.Context, sessions []Session) error
```

规则：

```text
cache key = token:<access_token_hash>
pointer key = token:cur_sess:<platform>:<user_id>
只有 pointer 当前值等于 session.ID 字符串才 Del pointer key。
Redis 删除失败不回滚 DB revoked_at，但要返回 error 给 handler，让 OperationLog 标失败；不要假装成功。
```

## Frontend design

### API client changes

```text
admin_front_ts/src/api/user/usersQuickEntry.ts
  legacyRequest -> request
  PUT ${ADMIN_API_PREFIX}/users/me/quick-entries

admin_front_ts/src/api/user/usersLoginLog.ts
  legacyRequest -> request
  GET ${ADMIN_API_PREFIX}/users/login-logs/page-init
  GET ${ADMIN_API_PREFIX}/users/login-logs with normalized query

admin_front_ts/src/api/user/users.ts
  UserSessionApi.kick -> PATCH ${ADMIN_API_PREFIX}/user-sessions/:id/revoke
  UserSessionApi.batchKick -> PATCH ${ADMIN_API_PREFIX}/user-sessions/revoke
  remove EditPassword if still unused
  keep forgetPassword legacy for this slice
```

### TypeScript rules

```text
Touched TS cannot use any/as any/Record<string, any>.
Keep exported names UsersQuickEntryApi, UsersLoginLogApi, UserSessionApi so pages do not need broad UI rewrites.
Keep UserLoginLogListParams.date for forms if needed, but normalize into date_start/date_end in API client.
```

## Verification gates

```powershell
cd E:\admin_go\admin_back_go
$env:GOMAXPROCS='2'
go test -p=1 ./internal/module/userquickentry ./internal/module/userloginlog ./internal/module/usersession ./internal/module/session ./internal/server ./internal/bootstrap
go vet -p=1 ./internal/module/userquickentry ./internal/module/userloginlog ./internal/module/usersession ./internal/module/session
powershell -ExecutionPolicy Bypass -File .\scripts\check-contract.ps1

cd E:\admin_go\admin_front_ts
npx vitest run tests/shared/user/users-api.test.ts tests/shared/user/users-quick-entry-api.test.ts tests/shared/user/users-login-log-api.test.ts
npx vue-tsc -b --pretty false

cd E:\admin_go\admin_back_go
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account 15671628271 -Password 123456
```

Smoke 必须证明：

```text
quick-entry save round trip works for current user and users/init returns updated quick_entry
login-log page-init/list return Go REST envelope
session revoke refuses current session
session revoke of a non-current test session marks revoked_at and no token hash leaks in list
legacy UserSession/kick/list/stats no longer appears in frontend API
forgetPassword remains explicitly legacy-backed
```

## Status wording after implementation

允许说：

```text
User legacy closure implemented for quick-entry, login logs, and user-session revoke.
```

禁止说：

```text
All auth/account security migrated.
forgetPassword migrated.
```

## Self-review

```text
Scope is narrow: three live legacy user features plus dead EditPassword cleanup check.
No placeholder remains: endpoints, request/response, tables, Redis keys, permissions and smoke gates are explicit.
Compatibility is preserved: users/init quick_entry name stays, forgetPassword stays out, current-session anti-kick is mandatory.
```
