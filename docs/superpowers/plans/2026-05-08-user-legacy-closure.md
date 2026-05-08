# User Legacy Closure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the remaining live User-side PHP legacy adapters for quick entries, login logs, and user-session kick/batchKick while keeping forgot-password in its separate account-security slice.

**Architecture:** Add two small Go modules for `users_quick_entry` writes and `users_login_log` reads, then extend the existing `usersession` module with a revoke write path. Reuse current auth identity, permission middleware, operation-log route metadata, and session Redis key rules; do not invent a new auth/session stack.

**Tech Stack:** Go/Gin/GORM/MySQL/Redis, existing `session.Cache` and token prefix config, Vue 3 + TypeScript, existing `request` HTTP client, Vitest source-contract tests, repo smoke scripts.

---

## Implementation status

状态：implemented and verified on 2026-05-08。Tasks 1-8 已完成；文档、smoke、后端 focused tests/vet、前端 Vitest/vue-tsc/build、contract check、residue/diff gates 已跑。`forgetPassword` 仍是独立 account-security legacy 例外，不属于本计划。

当前已完成的局部验证：

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/session -run TestRevocationService -count=1
go test ./internal/module/userquickentry -count=1
go test ./internal/module/userloginlog -count=1
go test ./internal/module/usersession -count=1
go test ./internal/server -run TestRouterInstallsUserLegacyClosureRESTRoutes -count=1
go test ./internal/bootstrap -run 'TestPermissionRouteRulesUseExplicitRESTPatterns|TestOperationRouteRulesUseExplicitRESTPatterns' -count=1
go test ./internal/module/session ./internal/module/userquickentry ./internal/module/userloginlog ./internal/module/usersession ./internal/server ./internal/bootstrap -count=1

cd E:\admin_go\admin_front_ts
npx vitest run tests/shared/user/users-api.test.ts --pool=threads
npx vitest run tests/shared/user/user-list.test.ts --pool=threads
npx vue-tsc -b --pretty false
```

最终门禁已在收口轮次跑完：后端 focused `go test`、`go vet`、contract gate、前端 Vitest/vue-tsc/build、full smoke、active residue、`git diff --check`。

## Master rules

```text
Migrate now: quick entry save, login log init/list, session revoke.
Keep out: forgetPassword.
Delete only if still dead: EditPassword frontend API definition.
Never return access_token_hash or refresh_token_hash.
Never expose Go endpoints with /list /add /edit /del action paths.
```

## File map

### Create

```text
admin_back_go/internal/module/userquickentry/dto.go
admin_back_go/internal/module/userquickentry/model.go
admin_back_go/internal/module/userquickentry/request.go
admin_back_go/internal/module/userquickentry/repository.go
admin_back_go/internal/module/userquickentry/service.go
admin_back_go/internal/module/userquickentry/service_test.go
admin_back_go/internal/module/userquickentry/handler.go
admin_back_go/internal/module/userquickentry/handler_test.go
admin_back_go/internal/module/userquickentry/route.go

admin_back_go/internal/module/userloginlog/dto.go
admin_back_go/internal/module/userloginlog/model.go
admin_back_go/internal/module/userloginlog/request.go
admin_back_go/internal/module/userloginlog/repository.go
admin_back_go/internal/module/userloginlog/service.go
admin_back_go/internal/module/userloginlog/service_test.go
admin_back_go/internal/module/userloginlog/handler.go
admin_back_go/internal/module/userloginlog/handler_test.go
admin_back_go/internal/module/userloginlog/route.go

admin_back_go/internal/module/session/revoker.go
admin_back_go/internal/module/session/revoker_test.go

admin_front_ts/tests/shared/user/users-quick-entry-api.test.ts
admin_front_ts/tests/shared/user/users-login-log-api.test.ts
```

### Modify

```text
admin_back_go/internal/module/usersession/dto.go
admin_back_go/internal/module/usersession/request.go
admin_back_go/internal/module/usersession/repository.go
admin_back_go/internal/module/usersession/service.go
admin_back_go/internal/module/usersession/service_test.go
admin_back_go/internal/module/usersession/handler.go
admin_back_go/internal/module/usersession/handler_test.go
admin_back_go/internal/module/usersession/route.go
admin_back_go/internal/server/router.go
admin_back_go/internal/server/router_test.go
admin_back_go/internal/bootstrap/app.go
admin_back_go/internal/bootstrap/route_meta.go
admin_back_go/internal/bootstrap/route_meta_test.go
admin_back_go/scripts/full-admin-smoke.ps1

admin_front_ts/src/api/user/usersQuickEntry.ts
admin_front_ts/src/api/user/usersLoginLog.ts
admin_front_ts/src/api/user/users.ts
admin_front_ts/src/types/user.ts
admin_front_ts/tests/shared/user/users-api.test.ts

docs/contracts/admin-api-v1.md
docs/migration/current-status.md
docs/testing/smoke-matrix.md
admin_back_go/docs/architecture.md
```

---

## Task 1: Add `session.RevocationService` instead of copying Redis key strings

**Files:**
- Create: `admin_back_go/internal/module/session/revoker.go`
- Create: `admin_back_go/internal/module/session/revoker_test.go`

- [x] **Step 1: Write failing revoker tests**

Create `admin_back_go/internal/module/session/revoker_test.go`:

```go
package session

import (
	"context"
	"testing"
	"time"
)

type fakeRevocationCache struct {
	values      map[string]string
	deletedKeys []string
}

func (f *fakeRevocationCache) Get(ctx context.Context, key string) (string, error) {
	return f.values[key], nil
}
func (f *fakeRevocationCache) Set(ctx context.Context, key string, value string, ttl time.Duration) error { return nil }
func (f *fakeRevocationCache) Expire(ctx context.Context, key string, ttl time.Duration) error { return nil }
func (f *fakeRevocationCache) Del(ctx context.Context, key string) error {
	f.deletedKeys = append(f.deletedKeys, key)
	delete(f.values, key)
	return nil
}

func TestRevocationServiceDeletesAccessTokenAndMatchingPointer(t *testing.T) {
	cache := &fakeRevocationCache{values: map[string]string{"token:cur_sess:admin:44": "99"}}
	service := NewRevocationService(cache, RevocationConfig{RedisPrefix: "token:"})

	err := service.RevokeCache(context.Background(), Session{ID: 99, UserID: 44, Platform: "admin", AccessTokenHash: "access-hash"})
	if err != nil { t.Fatalf("RevokeCache returned error: %v", err) }

	if !contains(cache.deletedKeys, "token:access-hash") { t.Fatalf("access cache was not deleted: %#v", cache.deletedKeys) }
	if !contains(cache.deletedKeys, "token:cur_sess:admin:44") { t.Fatalf("matching pointer was not deleted: %#v", cache.deletedKeys) }
}

func TestRevocationServiceKeepsNonMatchingPointer(t *testing.T) {
	cache := &fakeRevocationCache{values: map[string]string{"token:cur_sess:admin:44": "100"}}
	service := NewRevocationService(cache, RevocationConfig{RedisPrefix: "token:"})

	err := service.RevokeCache(context.Background(), Session{ID: 99, UserID: 44, Platform: "admin", AccessTokenHash: "access-hash"})
	if err != nil { t.Fatalf("RevokeCache returned error: %v", err) }

	if !contains(cache.deletedKeys, "token:access-hash") { t.Fatalf("access cache was not deleted: %#v", cache.deletedKeys) }
	if contains(cache.deletedKeys, "token:cur_sess:admin:44") { t.Fatalf("non-matching pointer must not be deleted: %#v", cache.deletedKeys) }
}

func contains(values []string, target string) bool {
	for _, value := range values { if value == target { return true } }
	return false
}
```

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/session -run TestRevocationService -count=1
```

Expected: fail because `NewRevocationService` does not exist.

- [x] **Step 2: Implement revocation service**

Create `admin_back_go/internal/module/session/revoker.go`:

```go
package session

import (
	"context"
	"strconv"
	"strings"
)

type RevocationConfig struct { RedisPrefix string }

type RevocationService struct {
	cache Cache
	cfg RevocationConfig
}

func NewRevocationService(cache Cache, cfg RevocationConfig) *RevocationService {
	if cfg.RedisPrefix == "" { cfg.RedisPrefix = "token:" }
	return &RevocationService{cache: cache, cfg: cfg}
}

func (s *RevocationService) RevokeCache(ctx context.Context, row Session) error {
	if s == nil || s.cache == nil { return ErrCacheNotConfigured }
	if strings.TrimSpace(row.AccessTokenHash) != "" {
		if err := s.cache.Del(ctx, s.cacheKey(row.AccessTokenHash)); err != nil { return err }
	}
	if row.ID > 0 && row.UserID > 0 && strings.TrimSpace(row.Platform) != "" {
		pointerKey := s.singleSessionPointerKey(row.Platform, row.UserID)
		current, err := s.cache.Get(ctx, pointerKey)
		if err != nil { return err }
		if sameSessionID(current, row.ID) {
			if err := s.cache.Del(ctx, pointerKey); err != nil { return err }
		}
	}
	return nil
}

func (s *RevocationService) RevokeCaches(ctx context.Context, rows []Session) error {
	for _, row := range rows {
		if err := s.RevokeCache(ctx, row); err != nil { return err }
	}
	return nil
}

func (s *RevocationService) cacheKey(tokenHash string) string { return s.cfg.RedisPrefix + tokenHash }
func (s *RevocationService) singleSessionPointerKey(platform string, userID int64) string {
	return s.cfg.RedisPrefix + "cur_sess:" + strings.ToLower(strings.TrimSpace(platform)) + ":" + strconv.FormatInt(userID, 10)
}
```

- [x] **Step 3: Verify session package**

Run:

```powershell
go test ./internal/module/session -run TestRevocationService -count=1
```

Expected: pass.

---

## Task 2: Implement current-user quick-entry save

**Files:**
- Create: `admin_back_go/internal/module/userquickentry/*`

- [x] **Step 1: Write failing service tests**

Create `admin_back_go/internal/module/userquickentry/service_test.go` with tests proving:

```text
Save rejects missing user.
Save rejects more than 6 ids.
Save deduplicates permission ids while preserving order.
Save rejects ids that are not active admin PAGE permissions.
Save runs repository.ReplaceForUser once and returns latest quick_entry.
```

Use a fake repository with methods:

```go
type Repository interface {
	ActiveAdminPagePermissionIDs(ctx context.Context, ids []int64) (map[int64]struct{}, error)
	ReplaceForUser(ctx context.Context, userID int64, permissionIDs []int64) ([]QuickEntry, error)
}
```

Run:

```powershell
go test ./internal/module/userquickentry -count=1
```

Expected: fail because package does not exist.

- [x] **Step 2: Implement module files**

Required DTO:

```go
type SaveInput struct { PermissionIDs []int64 }
type SaveResponse struct { QuickEntry []QuickEntry `json:"quick_entry"` }
type QuickEntry struct { ID int64 `json:"id"`; PermissionID int64 `json:"permission_id"`; Sort int `json:"sort"` }
type HTTPService interface { Save(ctx context.Context, userID int64, input SaveInput) (*SaveResponse, *apperror.Error) }
```

Required repository behavior:

```text
ActiveAdminPagePermissionIDs: SELECT id FROM permissions WHERE id IN ? AND platform='admin' AND type=2 AND status=1 AND is_del=2.
ReplaceForUser transaction:
  UPDATE users_quick_entry SET is_del=1, updated_at=now WHERE user_id=? AND is_del=2
  INSERT rows user_id, permission_id, sort=1..N, is_del=2
  SELECT latest rows ORDER BY sort ASC
```

Route:

```text
PUT /api/admin/v1/users/me/quick-entries
```

Handler must read `middleware.GetAuthIdentity(c)` and reject missing identity.

- [x] **Step 3: Verify quick-entry module**

Run:

```powershell
go test ./internal/module/userquickentry -count=1
```

Expected: pass.

---

## Task 3: Implement login-log page-init/list

**Files:**
- Create: `admin_back_go/internal/module/userloginlog/*`

- [x] **Step 1: Write failing service tests**

Create `admin_back_go/internal/module/userloginlog/service_test.go` with tests proving:

```text
PageInit returns platformArr and login_type_arr.
List normalizes current_page/page_size and trims filters.
List converts date_start/date_end into full-day bounds.
List maps login_type/platform/is_success names.
List response includes user_name from join row and never requires user to still exist.
```

Run:

```powershell
go test ./internal/module/userloginlog -count=1
```

Expected: fail because package does not exist.

- [x] **Step 2: Implement module**

Required endpoints:

```text
GET /api/admin/v1/users/login-logs/page-init
GET /api/admin/v1/users/login-logs
```

Required query struct:

```go
type ListQuery struct {
	CurrentPage int
	PageSize int
	UserID int64
	LoginAccount string
	LoginType string
	IP string
	Platform string
	IsSuccess *int
	DateStart string
	DateEnd string
}
```

Required SQL behavior:

```text
FROM users_login_log l LEFT JOIN users u ON u.id=l.user_id
WHERE l.is_del=2
user_id exact
login_account LIKE '<trim>%'
login_type exact and must be email/phone/password when non-empty
ip LIKE '<trim>%'
platform exact and must pass enum.IsPlatform when non-empty
is_success in 1/2
created_at >= date_start 00:00:00
created_at <= date_end 23:59:59
ORDER BY l.id DESC
```

- [x] **Step 3: Verify login-log module**

Run:

```powershell
go test ./internal/module/userloginlog -count=1
```

Expected: pass.

---

## Task 4: Extend `usersession` with revoke write path

**Files:**
- Modify: `admin_back_go/internal/module/usersession/dto.go`
- Modify: `admin_back_go/internal/module/usersession/request.go`
- Modify: `admin_back_go/internal/module/usersession/repository.go`
- Modify: `admin_back_go/internal/module/usersession/service.go`
- Modify: `admin_back_go/internal/module/usersession/service_test.go`
- Modify: `admin_back_go/internal/module/usersession/handler.go`
- Modify: `admin_back_go/internal/module/usersession/handler_test.go`
- Modify: `admin_back_go/internal/module/usersession/route.go`

- [x] **Step 1: Add failing service tests**

Extend `service_test.go` with tests proving:

```text
Revoke rejects current session id.
Revoke returns revoked=false for already revoked session.
Revoke sets revoked_at for active session and calls cache revoker with access_token_hash/platform/user_id/session id.
BatchRevoke deduplicates ids, skips current session, skips already revoked, revokes the rest, and returns count/skipped_current/skipped_already_revoked.
```

Repository extension:

```go
GetByID(ctx context.Context, id int64) (*SessionRow, error)
GetByIDs(ctx context.Context, ids []int64) ([]SessionRow, error)
MarkRevoked(ctx context.Context, ids []int64, revokedAt time.Time) (int64, error)
```

- [x] **Step 2: Implement DTO/request/service/repository**

Add DTO:

```go
type RevokeResponse struct { ID int64 `json:"id"`; Revoked bool `json:"revoked"` }
type BatchRevokeInput struct { IDs []int64 }
type BatchRevokeResponse struct { Count int64 `json:"count"`; SkippedCurrent int `json:"skipped_current"`; SkippedAlreadyRevoked int `json:"skipped_already_revoked"` }
type CacheRevoker interface { RevokeCache(ctx context.Context, row session.Session) error; RevokeCaches(ctx context.Context, rows []session.Session) error }
```

Repository must select token hashes for revoke logic, but handler response and list response must still omit them.

- [x] **Step 3: Implement handler and routes**

Routes:

```text
PATCH /api/admin/v1/user-sessions/:id/revoke
PATCH /api/admin/v1/user-sessions/revoke
```

Handler rules:

```text
Read auth identity.
Single uses URL id.
Batch binds JSON { ids: number[] }.
Missing auth returns Unauthorized.
```

- [x] **Step 4: Verify usersession module**

Run:

```powershell
go test ./internal/module/usersession -count=1
```

Expected: pass.

---

## Task 5: Wire backend router/bootstrap/permission/operation log

**Files:**
- Modify: `admin_back_go/internal/server/router.go`
- Modify: `admin_back_go/internal/server/router_test.go`
- Modify: `admin_back_go/internal/bootstrap/app.go`
- Modify: `admin_back_go/internal/bootstrap/route_meta.go`
- Modify: `admin_back_go/internal/bootstrap/route_meta_test.go`

- [x] **Step 1: Add router tests first**

Extend `router_test.go` to assert these routes are installed:

```text
PUT /api/admin/v1/users/me/quick-entries
GET /api/admin/v1/users/login-logs/page-init
GET /api/admin/v1/users/login-logs
PATCH /api/admin/v1/user-sessions/:id/revoke
PATCH /api/admin/v1/user-sessions/revoke
```

- [x] **Step 2: Wire dependencies**

`server.Dependencies` additions:

```go
UserQuickEntryService userquickentry.HTTPService
UserLoginLogService userloginlog.HTTPService
```

`bootstrap.New` additions:

```go
sessionRevoker := session.NewRevocationService(sessionCache, session.RevocationConfig{RedisPrefix: cfg.Token.RedisPrefix})
userQuickEntryService := userquickentry.NewService(userquickentry.NewGormRepository(resources.DB))
userLoginLogService := userloginlog.NewService(userloginlog.NewGormRepository(resources.DB))
userSessionService := usersession.NewService(usersession.NewGormRepository(resources.DB), usersession.WithCacheRevoker(sessionRevoker))
```

Use actual existing variable names from `app.go`; do not create duplicate DB/Redis clients.

- [x] **Step 3: Add permission route rules**

Add:

```go
middleware.NewRouteKey(http.MethodPatch, "/api/admin/v1/user-sessions/:id/revoke"): "user_userManager_kick",
middleware.NewRouteKey(http.MethodPatch, "/api/admin/v1/user-sessions/revoke"): "user_userManager_kick",
```

Do not add permission checks to quick-entry save; it is current-user personalization, not a management button.

- [x] **Step 4: Add operation route rules**

Add:

```go
PATCH /api/admin/v1/user-sessions/:id/revoke -> Module "user_session", Action "revoke", Title "踢下线用户会话"
PATCH /api/admin/v1/user-sessions/revoke -> Module "user_session", Action "revoke_batch", Title "批量踢下线用户会话"
PUT /api/admin/v1/users/me/quick-entries -> Module "user", Action "save_quick_entries", Title "保存快捷入口"
```

Login-log GET routes must not write operation logs.

- [x] **Step 5: Verify wiring**

Run:

```powershell
go test ./internal/server ./internal/bootstrap -count=1
```

Expected: pass.

---

## Task 6: Switch frontend User clients to Go REST

**Files:**
- Create: `admin_front_ts/tests/shared/user/users-quick-entry-api.test.ts`
- Create: `admin_front_ts/tests/shared/user/users-login-log-api.test.ts`
- Modify: `admin_front_ts/src/api/user/usersQuickEntry.ts`
- Modify: `admin_front_ts/src/api/user/usersLoginLog.ts`
- Modify: `admin_front_ts/src/api/user/users.ts`
- Modify: `admin_front_ts/src/types/user.ts`
- Modify: `admin_front_ts/tests/shared/user/users-api.test.ts`

- [x] **Step 1: Write failing frontend contract tests**

Tests must assert:

```text
usersQuickEntry.ts imports request and ADMIN_API_PREFIX.
usersQuickEntry.ts contains PUT /users/me/quick-entries and no legacyRequest.
usersLoginLog.ts imports request and ADMIN_API_PREFIX.
usersLoginLog.ts contains GET /users/login-logs/page-init and GET /users/login-logs and no legacyRequest.
users.ts session kick uses PATCH /user-sessions/:id/revoke.
users.ts batchKick uses PATCH /user-sessions/revoke.
users.ts still contains /api/Users/forgetPassword.
users.ts does not contain /api/Users/EditPassword after dead-code confirmation.
Touched files contain no any/as any/Record<string, any>.
```

Run:

```powershell
cd E:\admin_go\admin_front_ts
npx vitest run tests/shared/user/users-api.test.ts tests/shared/user/users-quick-entry-api.test.ts tests/shared/user/users-login-log-api.test.ts
```

Expected: fail before client rewrite.

- [x] **Step 2: Rewrite `usersQuickEntry.ts`**

Required shape:

```ts
import request, { ADMIN_API_PREFIX } from '@/lib/http'
import type { QuickEntryItem } from '@/types/user'

export const UsersQuickEntryApi = {
  save: (params: { permission_ids: number[] }) =>
    request.put<{ quick_entry: QuickEntryItem[] }, { permission_ids: number[] }>(`${ADMIN_API_PREFIX}/users/me/quick-entries`, params),
}
```

- [x] **Step 3: Rewrite `usersLoginLog.ts`**

Add a normalizer that maps `date?: string[]` to `date_start/date_end`, trims text filters, and omits empty strings.

Required endpoints:

```text
GET ${ADMIN_API_PREFIX}/users/login-logs/page-init
GET ${ADMIN_API_PREFIX}/users/login-logs
```

- [x] **Step 4: Rewrite session kick clients in `users.ts`**

Required behavior:

```text
kick({id}) -> PATCH /user-sessions/${id}/revoke
batchKick({ids}) -> PATCH /user-sessions/revoke body {ids}
```

Then rerun dead-code check:

```powershell
cd E:\admin_go
rg -n "EditPassword|/api/Users/EditPassword" admin_front_ts/src admin_back_go/internal E:/admin/admin_back/app
```

If only the API method/type remains, delete it. Keep `forgetPassword` unchanged.

- [x] **Step 5: Verify frontend clients**

Run:

```powershell
cd E:\admin_go\admin_front_ts
npx vitest run tests/shared/user/users-api.test.ts tests/shared/user/users-quick-entry-api.test.ts tests/shared/user/users-login-log-api.test.ts
npx vue-tsc -b --pretty false
```

Expected: pass.

---

## Task 7: Contract docs and smoke

**Files:**
- Modify: `docs/contracts/admin-api-v1.md`
- Modify: `docs/migration/current-status.md`
- Modify: `docs/testing/smoke-matrix.md`
- Modify: `admin_back_go/docs/architecture.md`
- Modify: `admin_back_go/scripts/full-admin-smoke.ps1`

- [x] **Step 1: Update API contract**

Document these exact endpoints:

```text
PUT /api/admin/v1/users/me/quick-entries
GET /api/admin/v1/users/login-logs/page-init
GET /api/admin/v1/users/login-logs
PATCH /api/admin/v1/user-sessions/:id/revoke
PATCH /api/admin/v1/user-sessions/revoke
```

Also state:

```text
/api/Users/forgetPassword remains an explicit legacy/account-security exception.
/api/Users/EditPassword is removed if unused, not migrated.
```

- [x] **Step 2: Update status docs**

`current-status.md` must say User legacy closure is implemented only after verification passes, and must not claim forgot-password is migrated.

- [x] **Step 3: Add full smoke probes**

Add probes:

```text
GET /api/admin/v1/users/login-logs/page-init
GET /api/admin/v1/users/login-logs?current_page=1&page_size=5
PUT /api/admin/v1/users/me/quick-entries using the current quick_entry permission ids from users/init, then restore same ids
PATCH /api/admin/v1/user-sessions/<current_session_id>/revoke expects non-zero error code / HTTP 400 and message containing current session protection
GET /api/admin/v1/user-sessions verifies no token hash keys
```

Do not revoke random live sessions in default smoke. If a disposable test session is created later, put it behind an explicit `-EnableUserSessionMutationProbe` switch.

- [x] **Step 4: Verify docs mention no old action path as active contract**

Run:

```powershell
cd E:\admin_go
rg -n "/api/admin/(UsersQuickEntry|UsersLoginLog|UserSession)/(save|init|list|kick|batchKick)|/api/Users/EditPassword" docs admin_front_ts/src/api/user
```

Expected: no active frontend API hit; docs may mention old paths only as legacy history.

---

## Task 8: Final verification

**Files:** no source changes unless a verification failure exposes a real bug.

- [x] **Step 1: Backend focused verification**

Run:

```powershell
cd E:\admin_go\admin_back_go
$env:GOMAXPROCS='2'
go test -p=1 ./internal/module/userquickentry ./internal/module/userloginlog ./internal/module/usersession ./internal/module/session ./internal/server ./internal/bootstrap
go vet -p=1 ./internal/module/userquickentry ./internal/module/userloginlog ./internal/module/usersession ./internal/module/session
powershell -ExecutionPolicy Bypass -File .\scripts\check-contract.ps1
git diff --check
```

Expected: exit 0.

- [x] **Step 2: Frontend focused verification**

Run:

```powershell
cd E:\admin_go\admin_front_ts
npx vitest run tests/shared/user/users-api.test.ts tests/shared/user/users-quick-entry-api.test.ts tests/shared/user/users-login-log-api.test.ts
npx vue-tsc -b --pretty false
git diff --check
```

Expected: exit 0.

- [x] **Step 3: Full smoke**

Run:

```powershell
cd E:\admin_go\admin_back_go
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account 15671628271 -Password 123456
```

Expected summary includes:

```text
users_quick_entry_save_code=0
users_login_log_init_code=0
users_login_log_list_code=0
user_session_current_revoke_blocked=true
user_session_token_hash_leak=false
```

- [x] **Step 4: Residue sweep**

Run:

```powershell
cd E:\admin_go
rg -n "legacyRequest|/api/admin/UsersQuickEntry|/api/admin/UsersLoginLog|/api/admin/UserSession|/api/Users/EditPassword" admin_front_ts/src/api/user admin_front_ts/tests/shared/user
```

Expected:

```text
Only /api/Users/forgetPassword remains as a deliberate legacy path in users.ts.
No UserSession kick/list/stats legacy path remains.
No EditPassword path remains if dead-code confirmation passed.
```

## Commit plan

If the user asks to commit after verification:

```powershell
git -C E:\admin_go\admin_back_go add internal/module/userquickentry internal/module/userloginlog internal/module/usersession internal/module/session internal/server internal/bootstrap scripts/full-admin-smoke.ps1 docs/architecture.md
git -C E:\admin_go\admin_back_go commit -m "feat: close user legacy api gaps"

git -C E:\admin_go\admin_front_ts add src/api/user src/types/user.ts tests/shared/user
git -C E:\admin_go\admin_front_ts commit -m "feat: switch user legacy clients to go rest"

git -C E:\admin_go add docs/contracts/admin-api-v1.md docs/migration/current-status.md docs/testing/smoke-matrix.md docs/superpowers/specs/2026-05-08-user-legacy-closure-design.md docs/superpowers/plans/2026-05-08-user-legacy-closure.md
git -C E:\admin_go commit -m "docs: plan user legacy closure"
```

## Self-review

```text
Spec coverage: quick-entry, login-log, session revoke, EditPassword cleanup check, forgetPassword non-goal are all mapped to tasks.
No placeholder text remains.
Plan does not migrate dead forgot-password or use legacy action paths.
Current-session anti-kick and Redis pointer compare-delete are explicit, not hand-waved.
```
