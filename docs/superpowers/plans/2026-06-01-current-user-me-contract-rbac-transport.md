# Current User `users/me` Contract, RBAC, and QuickEntry Removal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `GET /api/{admin,app,canvas}/v1/users/me` the only current-user bootstrap contract, return one shared DTO on all three platforms, move app/canvas current-user routes under `user`, apply Canvas PAGE/BUTTON RBAC, and delete QuickEntry from backend, frontend, docs, smoke, and database.

**Architecture:** `user` owns current-user bootstrap for every platform; `profile` owns profile read/write only. QuickEntry is not a platform capability and is removed instead of modeled as an admin-only DTO exception. Presenters map one service DTO to one wire DTO without alias fields or fallback defaults.

**Tech Stack:** Go 1.26, Gin, MySQL 8.4, Vue 3/Pinia, Next.js Canvas frontend, PowerShell smoke scripts, Vitest, Go tests.

---

## Current truth before this plan

- `/api/admin/v1/users/me` shape is the canonical shape except it still contains QuickEntry in old code.
- `/api/admin/v1/users/init` must not remain mounted.
- `/api/app/v1/users/me` and `/api/canvas/v1/users/me` must use the same DTO as admin.
- `internal/module/user/transport/{admin,app,canvas}` must own `users/me`.
- `internal/module/profile` must not own `users/me` or QuickEntry.
- Canvas RBAC must include PAGE rows, BUTTON rows with PAGE parent, and role grants.
- QuickEntry must disappear from active runtime: code, routes, smoke, tests, frontend, docs, and table.

## Target DTO

Allowed fields only:

```text
user_id
username
avatar
role_name
permissions
router
buttonCodes
```

Forbidden fields:

```text
quick_entry
quickEntry
id
nickname
display_name
avatar_url
permissionCodes
permission_codes
button_codes
```

## File map

Backend remove/modify:

- Modify: `admin_back_go/internal/module/user/dto.go`
- Modify: `admin_back_go/internal/module/user/model.go`
- Modify: `admin_back_go/internal/module/user/repository.go`
- Modify: `admin_back_go/internal/module/user/service.go`
- Modify: `admin_back_go/internal/module/user/service_test.go`
- Modify: `admin_back_go/internal/module/user/transport/admin/handler.go`
- Modify: `admin_back_go/internal/module/user/transport/admin/handler_test.go`
- Modify: `admin_back_go/internal/module/user/transport/admin/presenter.go`
- Modify/Create: `admin_back_go/internal/module/user/transport/app/*`
- Modify/Create: `admin_back_go/internal/module/user/transport/canvas/*`
- Modify: `admin_back_go/internal/module/auth/transport/app/*`
- Modify: `admin_back_go/internal/module/auth/transport/canvas/*`
- Modify: `admin_back_go/internal/module/profile/http.go`
- Modify/Delete: `admin_back_go/internal/module/profile/transport/admin/*` QuickEntry route only
- Modify: `admin_back_go/internal/module/profile/transport/app/*`
- Delete: `admin_back_go/internal/module/profile/transport/canvas/*`
- Delete: `admin_back_go/internal/module/profile/quickentry_dto.go`
- Delete: `admin_back_go/internal/module/profile/quickentry_model.go`
- Delete: `admin_back_go/internal/module/profile/quickentry_repository.go`
- Delete: `admin_back_go/internal/module/profile/quickentry_service.go`
- Delete: `admin_back_go/internal/module/profile/quickentry_service_test.go`
- Modify: `admin_back_go/internal/server/router.go`
- Modify: `admin_back_go/internal/server/routes_admin_user.go`
- Modify: `admin_back_go/internal/server/router_test.go`
- Modify: `admin_back_go/internal/server/testdata/admin_routes_golden.txt`
- Modify: `admin_back_go/internal/bootstrap/app.go`
- Modify: `admin_back_go/internal/architecture/*.go`
- Modify: `admin_back_go/internal/shared/i18n/locales/*/user.yaml`
- Modify: `admin_back_go/scripts/basic-admin-smoke.ps1`
- Modify: `admin_back_go/scripts/full-admin-smoke.ps1`
- Create: `admin_back_go/database/migrations/20260601_drop_users_quick_entry.sql`
- Modify: `admin_back_go/database/migrations/20260531_canvas_front_next_integration.sql`
- Modify/Create: `admin_back_go/scripts/check-canvas-rbac.ps1`

Admin frontend remove/modify:

- Delete: `admin_front_ts/src/api/user/usersQuickEntry.ts`
- Modify: `admin_front_ts/src/types/user.ts`
- Modify: `admin_front_ts/src/store/user.ts`
- Modify: `admin_front_ts/src/views/Main/home/index.vue`
- Modify: `admin_front_ts/src/views/Main/home/composables/useHomeDashboard.ts`
- Modify: `admin_front_ts/src/views/Main/home/composables/helpers.ts`
- Delete: `admin_front_ts/src/views/Main/home/components/HomeQuickEntryPanel.vue`
- Delete: `admin_front_ts/src/views/Main/home/components/HomeQuickEntryManagerDialog.vue`
- Modify: `admin_front_ts/src/i18n/locales/zh-CN.ts`
- Modify: `admin_front_ts/src/i18n/locales/en-US.ts`
- Modify: `admin_front_ts/tests/shared/home/home-dashboard.test.ts`
- Modify: `admin_front_ts/tests/shared/user/users-api.test.ts`

Canvas frontend/docs:

- Modify: `canvas_front_next/src/services/api/auth.ts`
- Modify: `canvas_front_next/tests/shared/canvas-auth-boundary.test.ts`
- Modify: `docs/contracts/admin-api-v1.md`
- Modify: `docs/architecture/05-development-quality-rules.md`
- Modify: `docs/testing/smoke-matrix.md`
- Modify: `admin_back_go/docs/architecture.md`

---

## Task 1: Spec and plan sync

**Files:**
- Modify: `docs/superpowers/specs/2026-06-01-current-user-me-contract-rbac-transport-design.md`
- Modify: `docs/superpowers/plans/2026-06-01-current-user-me-contract-rbac-transport.md`

- [x] **Step 1: Rewrite spec for QuickEntry removal**

Spec must say QuickEntry is removed entirely, not admin-only.

- [x] **Step 2: Rewrite plan around deletion-first contract**

Plan must include backend, DB, admin frontend, Canvas, docs, smoke, and verification.

- [x] **Step 3: Self-review spec/plan**

Run:

```powershell
cd E:\admin_go
rg -n "保留 quick_entry|quick_entry: admin only|AdminCurrentUserMeResponse|quick-entry write|users_quick_entry.*keep" docs/superpowers/specs/2026-06-01-current-user-me-contract-rbac-transport-design.md docs/superpowers/plans/2026-06-01-current-user-me-contract-rbac-transport.md
```

Expected: no positive requirement preserving QuickEntry; self-check lines that mention the forbidden wording only as removal criteria are acceptable.

---

## Task 2: Add RED backend guards for QuickEntry removal

**Files:**
- Modify: `admin_back_go/internal/architecture/restful_api_naming_test.go`
- Modify: `admin_back_go/internal/architecture/platform_route_line_test.go`
- Modify/Create: `admin_back_go/internal/architecture/quickentry_removal_test.go`
- Modify: `admin_back_go/internal/server/router_test.go`
- Modify: `admin_back_go/internal/module/user/transport/admin/handler_test.go`
- Modify/Create: `admin_back_go/internal/module/user/transport/app/route_test.go`
- Modify/Create: `admin_back_go/internal/module/user/transport/canvas/route_test.go`

- [ ] **Step 1: Route naming guard rejects current-user init**

Use this behavior in architecture tests:

```go
for route := range routes {
    if strings.Contains(routePath(route), "/users/init") {
        t.Fatalf("current-user bootstrap must not expose users/init: %s", route)
    }
}
```

Also assert these routes exist:

```text
GET /api/admin/v1/users/me
GET /api/app/v1/users/me
GET /api/canvas/v1/users/me
```

- [ ] **Step 2: Add QuickEntry active-runtime guard**

Create a test that scans active backend paths and fails on these tokens:

```text
users_quick_entry
quick_entry
quickEntry
QuickEntry
quick-entries
UserQuickEntryService
```

Allowed paths in the test itself and the new drop migration:

```text
internal/architecture/quickentry_removal_test.go
database/migrations/20260601_drop_users_quick_entry.sql
```

- [ ] **Step 3: Server route guard rejects quick-entry route**

Add router test:

```go
func TestRouterDoesNotInstallQuickEntryRoute(t *testing.T) {
    router := newTestRouter(t, Dependencies{
        Authenticator: func(ctx context.Context, input middleware.TokenInput) (*middleware.AuthIdentity, *apperror.Error) {
            return &middleware.AuthIdentity{UserID: 1, SessionID: 10, Platform: input.Platform}, nil
        },
        UserService: &fakeRouterUserService{result: &user.InitResponse{UserID: 1, Username: "admin"}},
    })

    recorder := httptest.NewRecorder()
    request := httptest.NewRequest(http.MethodPut, "/api/admin/v1/users/me/quick-entries", strings.NewReader(`{"items":[]}`))
    request.Header.Set("Authorization", "Bearer access-token")
    request.Header.Set("platform", "admin")
    router.ServeHTTP(recorder, request)

    if recorder.Code != http.StatusNotFound {
        t.Fatalf("quick-entry route must not be mounted, got %d body=%s", recorder.Code, recorder.Body.String())
    }
}
```

- [ ] **Step 4: users/me payload tests forbid QuickEntry and alias fields**

For admin/app/canvas transport tests, assert response contains only target DTO fields and forbids:

```text
quick_entry quickEntry id nickname display_name avatar_url permissionCodes permission_codes button_codes
```

- [ ] **Step 5: Verify RED**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test -count=1 -p=1 ./internal/architecture ./internal/server ./internal/module/user/transport/admin ./internal/module/user/transport/app ./internal/module/user/transport/canvas
```

Expected: FAIL before implementation because QuickEntry code/routes/table references still exist.

---

## Task 3: Remove backend QuickEntry implementation

**Files:** backend files listed in file map.

- [ ] **Step 1: Remove QuickEntry from user DTO and persistence**

Delete `QuickEntry` fields and remove any query or preload reading `users_quick_entry`.

Expected `InitResponse` shape:

```go
type InitResponse struct {
    UserID      int64
    Username    string
    Avatar      string
    RoleName    string
    Permissions []permission.MenuItem
    Router      []permission.RouteItem
    ButtonCodes []string
}
```

- [ ] **Step 2: Delete profile QuickEntry service/repository/model/dto/test**

Delete files:

```text
internal/module/profile/quickentry_dto.go
internal/module/profile/quickentry_model.go
internal/module/profile/quickentry_repository.go
internal/module/profile/quickentry_service.go
internal/module/profile/quickentry_service_test.go
```

- [ ] **Step 3: Remove QuickEntry route and dependency wiring**

Remove:

```text
PUT /api/admin/v1/users/me/quick-entries
Dependencies.UserQuickEntryService
profile.NewQuickEntryService(...)
profileadmin.RegisterRoutes(..., deps.UserQuickEntryService)
```

Profile admin route registration should only receive what it needs for profile/security.

- [ ] **Step 4: Remove QuickEntry i18n and smoke checks**

Delete `userquickentry.*` catalog keys if they only served QuickEntry. Remove smoke request/round-trip for `/quick-entries`.

- [ ] **Step 5: Verify backend deletion GREEN**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test -count=1 -p=1 ./internal/architecture ./internal/server ./internal/module/user ./internal/module/profile
```

Expected: PASS.

---

## Task 4: Ensure user transport owns all users/me routes

**Files:**
- Modify/Create: `admin_back_go/internal/module/user/transport/app/*`
- Modify/Create: `admin_back_go/internal/module/user/transport/canvas/*`
- Modify: `admin_back_go/internal/module/user/transport/admin/*`
- Modify: `admin_back_go/internal/module/profile/transport/app/*`
- Delete: `admin_back_go/internal/module/profile/transport/canvas/*`
- Modify: `admin_back_go/internal/server/routes_admin_user.go`
- Modify: `admin_back_go/internal/server/testdata/admin_routes_golden.txt`

- [ ] **Step 1: Keep admin users/me and remove users/init**

Admin route file must have:

```go
users.GET("/me", handler.Me)
```

It must not have:

```go
users.GET("/init", handler.Init)
```

- [ ] **Step 2: App and Canvas user transports call Init with platform**

App handler uses:

```go
usermodule.InitInput{UserID: identity.UserID, Platform: enum.PlatformApp}
```

Canvas handler uses:

```go
usermodule.InitInput{UserID: identity.UserID, Platform: enum.PlatformCanvas}
```

If `currentUser == nil`, return explicit internal error. Do not return empty DTO.

- [ ] **Step 3: Present one DTO**

All three presenters use JSON fields:

```go
UserID      int64                  `json:"user_id"`
Username    string                 `json:"username"`
Avatar      string                 `json:"avatar"`
RoleName    string                 `json:"role_name"`
Permissions []permission.MenuItem  `json:"permissions"`
Router      []permission.RouteItem `json:"router"`
ButtonCodes []string               `json:"buttonCodes"`
```

- [ ] **Step 4: Remove profile-owned users/me**

Profile app keeps only:

```text
GET /api/app/v1/profile
PUT /api/app/v1/profile
```

Delete profile canvas transport if no real canvas profile route remains.

- [ ] **Step 5: Register route owners**

`routes_admin_user.go` imports and registers:

```go
useradmin.RegisterRoutes(router, deps.UserService)
userapp.RegisterRoutes(router, deps.UserService)
usercanvas.RegisterRoutes(router, deps.UserService)
profileadmin.RegisterRoutes(router, deps.UserService)
profileapp.RegisterRoutes(router, deps.UserService)
```

- [ ] **Step 6: Verify route ownership**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test -count=1 -p=1 ./internal/server ./internal/architecture ./internal/module/user/transport/admin ./internal/module/user/transport/app ./internal/module/user/transport/canvas ./internal/module/profile/transport/app
```

Expected: PASS.

---

## Task 5: Align app/canvas login `data.user` with users/me

**Files:**
- Modify: `admin_back_go/internal/module/auth/transport/app/presenter.go`
- Modify: `admin_back_go/internal/module/auth/transport/app/handler.go`
- Modify: `admin_back_go/internal/module/auth/transport/app/handler_test.go`
- Modify: `admin_back_go/internal/module/auth/transport/canvas/presenter.go`
- Modify: `admin_back_go/internal/module/auth/transport/canvas/handler.go`
- Modify: `admin_back_go/internal/module/auth/transport/canvas/handler_test.go`

- [ ] **Step 1: Login tests require target DTO**

App and Canvas login tests require `data.user` fields:

```text
user_id username avatar role_name permissions router buttonCodes
```

They forbid:

```text
quick_entry quickEntry id nickname permissionCodes permission_codes button_codes
```

- [ ] **Step 2: Handler rejects nil currentUser**

Do not serialize empty user. Return explicit 500 apperror if current-user bootstrap is missing after login.

- [ ] **Step 3: Presenter maps same DTO**

`loginUser` shape matches users/me target DTO exactly.

- [ ] **Step 4: Verify auth tests**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test -count=1 -p=1 ./internal/module/auth/transport/app ./internal/module/auth/transport/canvas
```

Expected: PASS.

---

## Task 6: Database migration and Canvas RBAC proof

**Files:**
- Create: `admin_back_go/database/migrations/20260601_drop_users_quick_entry.sql`
- Modify: `admin_back_go/database/migrations/20260531_canvas_front_next_integration.sql`
- Modify: `admin_back_go/internal/architecture/canvas_front_next_integration_test.go`
- Modify/Create: `admin_back_go/scripts/check-canvas-rbac.ps1`

- [ ] **Step 1: Add drop table migration**

Create:

```sql
DROP TABLE IF EXISTS `users_quick_entry`;
```

- [ ] **Step 2: Add migration guard**

Architecture test must assert the drop migration exists and contains that exact table drop.

- [ ] **Step 3: Ensure Canvas migration seeds PAGE/BUTTON/grants**

Static guard requires target PAGE and BUTTON codes, BUTTON parent relation, role grant SQL, and orphan cleanup for `canvas_ai_text_generate` if present.

- [ ] **Step 4: Apply migrations to live DB**

Run after code review point:

```powershell
cd E:\admin_go\admin_back_go
Get-Content -Raw .\database\migrations\20260531_canvas_front_next_integration.sql | docker exec -i -e MYSQL_PWD=admin_go_local admin-go-state-mysql mysql --protocol=socket -uroot --database=admin
Get-Content -Raw .\database\migrations\20260601_drop_users_quick_entry.sql | docker exec -i -e MYSQL_PWD=admin_go_local admin-go-state-mysql mysql --protocol=socket -uroot --database=admin
powershell -ExecutionPolicy Bypass -File .\scripts\check-canvas-rbac.ps1
```

Expected checker values:

```text
canvas_pages >= 7
canvas_buttons_with_parent >= 8
canvas_role_grants > 0
canvas_orphan_buttons = 0
```

---

## Task 7: Remove admin frontend QuickEntry

**Files:** admin frontend files listed in file map.

- [ ] **Step 1: Add/adjust frontend RED tests**

Tests must fail while these exist:

```text
src/api/user/usersQuickEntry.ts
HomeQuickEntryPanel.vue
HomeQuickEntryManagerDialog.vue
quickEntry store state
QuickEntryItem type
quick_entry in UserInitResponse
quickEntry i18n keys
```

- [ ] **Step 2: Delete QuickEntry API and components**

Delete:

```text
src/api/user/usersQuickEntry.ts
src/views/Main/home/components/HomeQuickEntryPanel.vue
src/views/Main/home/components/HomeQuickEntryManagerDialog.vue
```

- [ ] **Step 3: Clean store/types/home composable/i18n**

Remove imports, state, computed values, methods, and labels that only served QuickEntry. Keep other home panels unchanged.

- [ ] **Step 4: Verify targeted admin frontend tests**

Run:

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/user/users-api.test.ts tests/shared/home/home-dashboard.test.ts
```

Expected: PASS.

---

## Task 8: Canvas frontend contract cleanup

**Files:**
- Modify: `canvas_front_next/src/services/api/auth.ts`
- Modify: `canvas_front_next/tests/shared/canvas-auth-boundary.test.ts`

- [ ] **Step 1: AuthUser has only target DTO fields**

`AuthUser` must contain exactly current-user DTO fields and no QuickEntry or alias fields.

- [ ] **Step 2: Boundary test forbids aliases**

Forbid:

```text
Partial<AuthUser>
displayName
display_name
avatarUrl
avatar_url
permissionCodes
permission_codes
button_codes
quick_entry
quickEntry
created_at
updated_at
```

- [ ] **Step 3: Verify Canvas targeted test**

Run:

```powershell
cd E:\admin_go\canvas_front_next
npm run test -- tests/shared/canvas-auth-boundary.test.ts
```

Expected: PASS.

---

## Task 9: Docs and smoke cleanup

**Files:**
- Modify: `docs/contracts/admin-api-v1.md`
- Modify: `docs/architecture/05-development-quality-rules.md`
- Modify: `docs/testing/smoke-matrix.md`
- Modify: `admin_back_go/docs/architecture.md`
- Modify: `admin_back_go/scripts/basic-admin-smoke.ps1`
- Modify: `admin_back_go/scripts/full-admin-smoke.ps1`

- [ ] **Step 1: Replace bootstrap docs with users/me**

Docs must describe only:

```text
GET /api/admin/v1/users/me
GET /api/app/v1/users/me
GET /api/canvas/v1/users/me
```

- [ ] **Step 2: Remove QuickEntry docs/smoke**

Delete quick-entry endpoint docs and smoke round-trip. Do not keep “deprecated” active API docs.

- [ ] **Step 3: Search active references**

Run:

```powershell
cd E:\admin_go
rg -n "QuickEntry|quick_entry|quickEntry|quick-entries|users_quick_entry|usersQuickEntry|HomeQuickEntry|UserQuickEntryService|/users/init" admin_back_go\internal admin_back_go\database admin_back_go\scripts admin_front_ts\src admin_front_ts\tests canvas_front_next\src canvas_front_next\tests docs\contracts docs\architecture docs\testing docs\status -g '!**/node_modules/**' -g '!**/dist/**' -g '!**/.next/**'
```

Expected: only intentional deletion guards/migrations/spec-plan references remain; no active runtime dependency.

---

## Task 10: Focused fallback audit

**Files:**
- Modify targeted tests only if needed.
- Optional create: `docs/status/fallback-audit-2026-06-01.md` if scan produces non-trivial follow-ups.

- [ ] **Step 1: Scan touched data path**

Run:

```powershell
cd E:\admin_go
rg -n "\?\?|\|\||\?\.|permissionCodes|permission_codes|button_codes|quickEntry|quick_entry" admin_back_go/internal/module/user admin_back_go/internal/module/auth admin_back_go/internal/server admin_front_ts/src/api admin_front_ts/src/store admin_front_ts/src/types canvas_front_next/src/services -g '!**/node_modules/**' -g '!**/dist/**' -g '!**/.next/**'
```

- [ ] **Step 2: Fix Blocking only**

Fix only contract-hiding aliases/fallbacks in current-user/auth/RBAC path. Do not perform an unreviewable whole-frontend rewrite.

---

## Task 11: Full verification and status docs

**Files:**
- Modify after passing verification only: `docs/status/current-status.md`
- Modify after passing verification only: `docs/status/module-matrix.md`

- [ ] **Step 1: Backend focused tests**

```powershell
cd E:\admin_go\admin_back_go
go test -count=1 -p=1 ./internal/architecture ./internal/server ./internal/module/user ./internal/module/profile ./internal/module/auth
```

- [ ] **Step 2: Backend full tests**

```powershell
cd E:\admin_go\admin_back_go
go test -count=1 -p=1 ./...
```

- [ ] **Step 3: Frontend checks**

```powershell
cd E:\admin_go\admin_front_ts
npm run typecheck
npm run test
npm run build

cd E:\admin_go\canvas_front_next
npm run test
npm run typecheck
npm run build
```

- [ ] **Step 4: Governance gates**

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

- [ ] **Step 5: Update status docs only after evidence exists**

Use wording like:

```text
2026-06-01 current-user users/me contract cleanup verified: admin/app/canvas users/me share one DTO, users/init removed, QuickEntry removed from active runtime and DB, user transport owns app/canvas current-user routes, Canvas PAGE/BUTTON RBAC migration applied and live DB verified.
```

Do not write this before the commands above pass.

---

## Self-review checklist

- [x] Spec and plan no longer preserve admin-only QuickEntry.
- [x] Three platforms share one DTO.
- [x] `users/init` is removed, not kept as alias.
- [x] QuickEntry route, frontend, backend, and table deletion are explicit.
- [x] Canvas PAGE/BUTTON RBAC live DB verification remains required.
- [x] Touched fallback cleanup is focused on current-user/auth/RBAC, not a broad aesthetic rewrite.
