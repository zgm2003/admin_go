# Plan 02: Auth Transport Pattern + `/api/Users` Backend Cleanup

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish `internal/module/auth/transport/{admin,app}` as the reference multi-platform module pattern, and remove the `/api/Users/*` legacy POST routes from the Go runtime. This plan is the **sequential prerequisite for plan-03** (module consolidation), because plan-03 modifies files created here.

**Source spec:** `docs/superpowers/specs/2026-05-27-multi-platform-backend-boundary-design.md` §12.1.

**Tech Stack:** Go, Gin, PowerShell, `go test`, `rg`, `git diff --check`.

---

## Scope Check

This plan executes:

```text
1. Auth admin/app routes move under transport/{admin,app} per spec §4 four-file convention.
2. /api/Users/* backend POST routes are removed (auth + user + middleware whitelist).
3. Static architecture tests protect the new boundary.
4. Bootstrap rewires through new Register entry points.
```

This plan does **not**:
- Merge `captcha` / `session` / `usersession` / `userloginlog` into auth (plan-03).
- Write or update governance docs (plan-01).
- Clean frontend `/api/Users` references (plan-04).
- Execute shared/dict, smaller module shells, AI aggregation, or `internal/platform -> internal/infra` rename (queued as later plans).

**Sibling plans (can run in parallel from t=0):**
- `2026-05-27-multi-platform-01-governance-docs.md` — pure markdown, zero `.go` touch
- `2026-05-27-multi-platform-04-frontend-legacy-cleanup.md` — touches admin_front_ts/admin_app

**Blocks:** `2026-05-27-multi-platform-03-module-consolidation.md` must wait until this plan merges.

---

## Task 0: Pre-flight checks (run before any code change)

**Files:**

- Validate only.

- [ ] **Step 1: Confirm no frontend caller still hits `/api/Users/*`**

Per spec §14.1 R-3, frontend references must be enumerated **before** the backend routes are deleted, so frontend PRs can land in sync.

Run:

```powershell
cd E:\admin_go
rg -n "/api/Users" admin_front_ts\src admin_front_ts\tests admin_app\lib admin_app\test -g "!*node_modules*" -g "!*dist*" -g "!*build*"
```

Expected: empty output. If any reference exists, **stop** this plan and either (a) coordinate a frontend PR that removes the call first, or (b) re-scope the backend deletion to keep that one route as a planned remaining legacy endpoint (not preferred — spec §1.3 reject this).

- [ ] **Step 2: Confirm current backend baseline compiles and tests pass**

Run:

```powershell
cd E:\admin_go\admin_back_go
go build ./...
go test ./internal/module/auth ./internal/module/user ./internal/server -count=1
```

Expected: PASS. Establishes the regression baseline. If any test currently fails, **stop** — fix the baseline first; do not move into a refactor on broken ground.

---

## File Structure

Root governance docs:

- Modify: `AGENTS.md`
- Modify: `docs/architecture/04-go-backend-framework.md`
- Modify: `docs/architecture/05-development-quality-rules.md`
- Modify: `docs/status/current-status.md`

Architecture guard:

- Create: `admin_back_go/internal/architecture/multiplatform_boundary_test.go`

Auth transport refactor:

- Create: `admin_back_go/internal/module/auth/transport/admin/route.go`
- Create: `admin_back_go/internal/module/auth/transport/admin/handler.go`
- Create: `admin_back_go/internal/module/auth/transport/admin/handler_test.go` (relocated from `auth/handler_test.go`)
- Create: `admin_back_go/internal/module/auth/transport/admin/request.go`
- Create: `admin_back_go/internal/module/auth/transport/admin/presenter.go` (per spec §4)
- Create: `admin_back_go/internal/module/auth/transport/app/route.go`
- Create: `admin_back_go/internal/module/auth/transport/app/handler.go`
- Create: `admin_back_go/internal/module/auth/transport/app/handler_test.go` (relocated from `auth/platform_handler_test.go`)
- Create: `admin_back_go/internal/module/auth/transport/app/request.go`
- Create: `admin_back_go/internal/module/auth/transport/app/presenter.go` (carries former `platform_dto.go` response types)
- Keep unchanged at module root: `service.go`, `dto.go` (service input/output types — cross-platform contracts), `repository.go`, `model.go`, `code_store.go`, `verify_code_policy.go`, `service_test.go`, `jobs.go`, `jobs_test.go`
- Delete: `admin_back_go/internal/module/auth/route.go`
- Delete: `admin_back_go/internal/module/auth/handler.go`
- Delete: `admin_back_go/internal/module/auth/handler_test.go` (after content relocates to `transport/admin/`)
- Delete: `admin_back_go/internal/module/auth/request.go`
- Delete: `admin_back_go/internal/module/auth/platform_route.go`
- Delete: `admin_back_go/internal/module/auth/platform_handler.go`
- Delete: `admin_back_go/internal/module/auth/platform_handler_test.go` (after content relocates to `transport/app/`)
- Delete: `admin_back_go/internal/module/auth/platform_dto.go` (content moves to `transport/app/presenter.go` and `transport/app/request.go`)

Route/bootstrap cleanup:

- Modify: `admin_back_go/internal/server/router.go`
- Modify: `admin_back_go/internal/module/user/route.go`
- Modify: `admin_back_go/internal/middleware/auth_token.go`
- Modify: `admin_back_go/internal/server/router_test.go`
- Modify: `admin_back_go/internal/module/user/handler_test.go`

**Note:** Root governance docs (AGENTS.md, docs/architecture/*, docs/status/current-status.md) are owned by **plan-01-governance-docs**, not this plan. Do not touch them here even if you see them appearing inconsistent — plan-01 lands separately.

---

## Task 1: Add RED architecture guard for auth transport boundary

**Files:**

- Create: `admin_back_go/internal/architecture/multiplatform_boundary_test.go`

- [ ] **Step 1: Create the failing architecture test**

Write `admin_back_go/internal/architecture/multiplatform_boundary_test.go`:

```go
package architecture

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func backendRoot(t *testing.T) string {
	t.Helper()
	wd, err := os.Getwd()
	if err != nil {
		t.Fatalf("get working directory: %v", err)
	}
	return filepath.Clean(filepath.Join(wd, "..", ".."))
}

func mustExist(t *testing.T, root, rel string) {
	t.Helper()
	if _, err := os.Stat(filepath.Join(root, rel)); err != nil {
		t.Fatalf("expected %s to exist: %v", rel, err)
	}
}

func mustNotExist(t *testing.T, root, rel string) {
	t.Helper()
	if _, err := os.Stat(filepath.Join(root, rel)); err == nil {
		t.Fatalf("expected %s to be removed", rel)
	} else if !os.IsNotExist(err) {
		t.Fatalf("check %s: %v", rel, err)
	}
}

func TestAuthTransportBoundaryShape(t *testing.T) {
	root := backendRoot(t)
	for _, rel := range []string{
		"internal/module/auth/transport/admin/route.go",
		"internal/module/auth/transport/admin/handler.go",
		"internal/module/auth/transport/admin/handler_test.go",
		"internal/module/auth/transport/admin/request.go",
		"internal/module/auth/transport/admin/presenter.go",
		"internal/module/auth/transport/app/route.go",
		"internal/module/auth/transport/app/handler.go",
		"internal/module/auth/transport/app/handler_test.go",
		"internal/module/auth/transport/app/request.go",
		"internal/module/auth/transport/app/presenter.go",
	} {
		mustExist(t, root, rel)
	}
	for _, rel := range []string{
		"internal/module/auth/route.go",
		"internal/module/auth/handler.go",
		"internal/module/auth/handler_test.go",
		"internal/module/auth/request.go",
		"internal/module/auth/platform_route.go",
		"internal/module/auth/platform_handler.go",
		"internal/module/auth/platform_handler_test.go",
		"internal/module/auth/platform_dto.go",
	} {
		mustNotExist(t, root, rel)
	}
}

func TestNoLegacyUsersRoutesInGoRuntime(t *testing.T) {
	root := backendRoot(t)
	var offenders []string
	err := filepath.WalkDir(filepath.Join(root, "internal"), func(path string, entry os.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if entry.IsDir() || filepath.Ext(path) != ".go" {
			return nil
		}
		body, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		if strings.Contains(string(body), "/api/Users") {
			rel, _ := filepath.Rel(root, path)
			offenders = append(offenders, filepath.ToSlash(rel))
		}
		return nil
	})
	if err != nil {
		t.Fatalf("walk internal go files: %v", err)
	}
	if len(offenders) > 0 {
		t.Fatalf("legacy /api/Users references remain: %s", strings.Join(offenders, ", "))
	}
}

func TestAuthTransportHasNoPlatformPrefixedFiles(t *testing.T) {
	root := backendRoot(t)
	authRoot := filepath.Join(root, "internal", "module", "auth")
	var offenders []string
	err := filepath.WalkDir(authRoot, func(path string, entry os.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if entry.IsDir() {
			return nil
		}
		name := entry.Name()
		if strings.HasPrefix(name, "platform_") || strings.HasPrefix(name, "app_") || strings.HasPrefix(name, "admin_") {
			rel, _ := filepath.Rel(root, path)
			offenders = append(offenders, filepath.ToSlash(rel))
		}
		return nil
	})
	if err != nil {
		t.Fatalf("walk auth files: %v", err)
	}
	if len(offenders) > 0 {
		t.Fatalf("platform-prefixed auth files remain: %s", strings.Join(offenders, ", "))
	}
}
```

- [ ] **Step 2: Run RED test**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture -run 'TestAuthTransportBoundaryShape|TestNoLegacyUsersRoutesInGoRuntime|TestAuthTransportHasNoPlatformPrefixedFiles' -count=1
```

Expected: FAIL with missing `internal/module/auth/transport/...` files and `/api/Users` offenders.

---

## Task 2: Move admin auth HTTP surface to `transport/admin`

**Files:**

- Create: `admin_back_go/internal/module/auth/transport/admin/route.go`
- Create: `admin_back_go/internal/module/auth/transport/admin/handler.go`
- Create: `admin_back_go/internal/module/auth/transport/admin/handler_test.go`
- Create: `admin_back_go/internal/module/auth/transport/admin/request.go`
- Create: `admin_back_go/internal/module/auth/transport/admin/presenter.go`
- Delete: `admin_back_go/internal/module/auth/route.go`
- Delete: `admin_back_go/internal/module/auth/handler.go`
- Delete: `admin_back_go/internal/module/auth/handler_test.go`
- Delete: `admin_back_go/internal/module/auth/request.go`

- [ ] **Step 1: Create admin transport directory**

Run:

```powershell
cd E:\admin_go\admin_back_go
New-Item -ItemType Directory -Force .\internal\module\auth\transport\admin | Out-Null
```

Expected: directory exists.

- [ ] **Step 2: Create `transport/admin/request.go`**

Create request structs copied from the old admin auth request file. Package name must be `admin`; request structs stay local to the transport package.

```go
package admin

type LoginRequest struct {
	LoginAccount  string                `json:"login_account" binding:"required,max=100"`
	LoginType     string                `json:"login_type" binding:"required,auth_platform_login_type"`
	Password      string                `json:"password" binding:"omitempty,max=128"`
	Code          string                `json:"code" binding:"omitempty,len=6,numeric"`
	CaptchaID     string                `json:"captcha_id" binding:"omitempty,max=80"`
	CaptchaAnswer *captchaAnswerRequest `json:"captcha_answer"`
}

type SendCodeRequest struct {
	Account string `json:"account" binding:"required,max=120"`
	Scene   string `json:"scene" binding:"required,verify_code_scene"`
}

type ForgetPasswordRequest struct {
	Account         string `json:"account" binding:"required,max=120"`
	Code            string `json:"code" binding:"required,len=6,numeric"`
	NewPassword     string `json:"new_password" binding:"required,min=6,max=128"`
	ConfirmPassword string `json:"confirm_password" binding:"required,min=6,max=128"`
}

type RefreshRequest struct {
	RefreshToken string `json:"refresh_token" binding:"required"`
}

type captchaAnswerRequest struct {
	X int `json:"x" binding:"min=0,max=10000"`
	Y int `json:"y" binding:"min=0,max=10000"`
}
```

- [ ] **Step 3: Create `transport/admin/handler.go`**

Move old admin `auth/handler.go` behavior into package `admin`. Use root auth service/input/output types through alias `authmodule`:

```go
package admin

import (
	"strings"

	"admin_back_go/internal/apperror"
	"admin_back_go/internal/middleware"
	authmodule "admin_back_go/internal/module/auth"
	"admin_back_go/internal/module/captcha"
	"admin_back_go/internal/module/session"
	"admin_back_go/internal/response"

	"github.com/gin-gonic/gin"
)

type Handler struct {
	service authmodule.SessionService
}

func NewHandler(service authmodule.SessionService) *Handler {
	return &Handler{service: service}
}
```

Mechanical replacements inside moved method bodies:

```text
LoginInput              -> authmodule.LoginInput
SendCodeInput           -> authmodule.SendCodeInput
ForgetPasswordInput     -> authmodule.ForgetPasswordInput
LoginConfigResponse     -> authmodule.LoginConfigResponse
LoginResponse           -> authmodule.LoginResponse
```

Keep `captchaAnswerFromRequest` as a private helper under `transport/admin` and return `*captcha.Answer`.

- [ ] **Step 4: Create `transport/admin/route.go` without legacy routes**

```go
package admin

import (
	"admin_back_go/internal/module/auth"
	"admin_back_go/internal/validate"

	"github.com/gin-gonic/gin"
)

func Register(router *gin.Engine, service auth.SessionService) {
	validate.MustRegister()
	handler := NewHandler(service)

	v1 := router.Group("/api/admin/v1/auth")
	v1.GET("/login-config", handler.LoginConfig)
	v1.POST("/send-code", handler.SendCode)
	v1.POST("/forgot-password", handler.ForgetPassword)
	v1.POST("/login", handler.Login)
	v1.POST("/refresh", handler.Refresh)
	v1.POST("/logout", handler.Logout)
}
```

Per spec §5.3, transport package exports `Register` (not `RegisterRoutes` / `RegisterAdminRoutes`).

- [ ] **Step 5: Create `transport/admin/presenter.go`**

Move any response-mapping helpers that currently live inline in `auth/handler.go` (e.g. struct-to-JSON shaping if any) into `presenter.go`. If no admin-specific presenter logic exists today, create the file with package declaration and a comment so the four-file convention (`route/handler/request/presenter`) is satisfied — future admin-specific response shaping lands here. Do not move cross-platform DTOs from `auth/dto.go` (those are service contracts, stay at module root).

- [ ] **Step 6: Relocate admin handler tests**

Move `internal/module/auth/handler_test.go` to `internal/module/auth/transport/admin/handler_test.go`:
- Change package declaration to `package admin`
- Update any references to old `auth.Handler` / `auth.NewHandler` to local `Handler` / `NewHandler`
- Update imports for `LoginInput` / `LoginResponse` / `SendCodeInput` / `ForgetPasswordInput` to use `authmodule.X` alias
- Tests that exercised the old `/api/Users/*` legacy POST routes are deleted (not migrated)

- [ ] **Step 7: Delete old admin HTTP files**

Run:

```powershell
cd E:\admin_go\admin_back_go
Remove-Item -LiteralPath .\internal\module\auth\route.go,.\internal\module\auth\handler.go,.\internal\module\auth\handler_test.go,.\internal\module\auth\request.go -Force
```

Expected: files are removed.

- [ ] **Step 8: Compile admin transport package**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/auth/transport/admin -count=1
```

Expected: PASS after import and type-prefix fixes.

---

## Task 3: Move app auth HTTP surface to `transport/app`

**Files:**

- Create: `admin_back_go/internal/module/auth/transport/app/route.go`
- Create: `admin_back_go/internal/module/auth/transport/app/handler.go`
- Create: `admin_back_go/internal/module/auth/transport/app/handler_test.go`
- Create: `admin_back_go/internal/module/auth/transport/app/request.go`
- Create: `admin_back_go/internal/module/auth/transport/app/presenter.go`
- Delete: `admin_back_go/internal/module/auth/platform_route.go`
- Delete: `admin_back_go/internal/module/auth/platform_handler.go`
- Delete: `admin_back_go/internal/module/auth/platform_handler_test.go`
- Delete: `admin_back_go/internal/module/auth/platform_dto.go`

- [ ] **Step 1: Create app transport directory**

Run:

```powershell
cd E:\admin_go\admin_back_go
New-Item -ItemType Directory -Force .\internal\module\auth\transport\app | Out-Null
```

Expected: directory exists.

- [ ] **Step 2: Create `transport/app/request.go`**

```go
package app

type LoginRequest struct {
	LoginAccount  string                `json:"login_account" binding:"required,max=100"`
	LoginType     string                `json:"login_type" binding:"required,auth_platform_login_type"`
	Password      string                `json:"password" binding:"omitempty,max=128"`
	Code          string                `json:"code" binding:"omitempty,len=6,numeric"`
	CaptchaID     string                `json:"captcha_id" binding:"omitempty,max=80"`
	CaptchaAnswer *captchaAnswerRequest `json:"captcha_answer"`
}

type SendCodeRequest struct {
	Account string `json:"account" binding:"required,max=120"`
	Scene   string `json:"scene" binding:"required,verify_code_scene"`
}

type captchaAnswerRequest struct {
	X int `json:"x" binding:"min=0,max=10000"`
	Y int `json:"y" binding:"min=0,max=10000"`
}
```

- [ ] **Step 3: Create app route registration**

```go
package app

import (
	"strings"

	"admin_back_go/internal/module/auth"
	"admin_back_go/internal/validate"

	"github.com/gin-gonic/gin"
)

type RouteOptions struct {
	Prefix         string
	Platform       string
	AuthService    auth.SessionService
	CaptchaService CaptchaService
	UserService    UserInitService
}

func Register(router *gin.Engine, opts RouteOptions) {
	validate.MustRegister()
	prefix := strings.TrimRight(strings.TrimSpace(opts.Prefix), "/")
	if prefix == "" {
		panic("auth app route prefix is required")
	}
	if strings.TrimSpace(opts.Platform) == "" {
		panic("auth app route platform is required")
	}
	handler := NewHandler(opts)
	group := router.Group(prefix)
	group.GET("/login-config", handler.LoginConfig)
	group.GET("/captcha", handler.Captcha)
	group.POST("/send-code", handler.SendCode)
	group.POST("/login", handler.Login)
	group.POST("/logout", handler.Logout)
}
```

Per spec §5.3, transport package exports `Register` (not `RegisterRoutes` / `RegisterPlatformRoutes`).

- [ ] **Step 4: Create app handler**

Move old `platform_handler.go` into `transport/app/handler.go`, change package name to `app`, and rename symbols:

```text
PlatformCaptchaService  -> CaptchaService
PlatformUserInitService -> UserInitService
PlatformHandler         -> Handler
NewPlatformHandler      -> NewHandler
PlatformRouteOptions    -> RouteOptions
```

Use `authmodule "admin_back_go/internal/module/auth"` for shared auth types.

- [ ] **Step 5: Create `transport/app/presenter.go` from `platform_dto.go` content**

Migrate response types and helpers from the deleted `platform_dto.go`:

```go
package app

import "admin_back_go/internal/module/user"

type loginResponse struct {
	Token string       `json:"token"`
	User  userSummary  `json:"user"`
}

type userSummary struct {
	ID       int64  `json:"id"`
	Nickname string `json:"nickname"`
	Avatar   string `json:"avatar"`
}

func userSummaryFromInit(currentUser *user.InitResponse) userSummary {
	if currentUser == nil {
		return userSummary{}
	}
	return userSummary{ID: currentUser.UserID, Nickname: currentUser.Username, Avatar: currentUser.Avatar}
}
```

Type rename rationale: in original `platform_dto.go` they were prefixed `platform*` because the package was `auth` and needed to disambiguate from admin variants. In the new `package app` scope the `platform` prefix is redundant and confusing (the package itself is the platform).

The `request.go` already holds `LoginRequest` / `SendCodeRequest` from Step 2; do not duplicate them here.

- [ ] **Step 6: Relocate app handler tests**

Move `internal/module/auth/platform_handler_test.go` to `internal/module/auth/transport/app/handler_test.go`:
- Change package declaration to `package app`
- Rename test helper references: `PlatformHandler` → `Handler`, `NewPlatformHandler` → `NewHandler`, `PlatformRouteOptions` → `RouteOptions`
- Adjust imports for `authmodule` alias

- [ ] **Step 7: Delete platform-prefixed files**

Run:

```powershell
cd E:\admin_go\admin_back_go
Remove-Item -LiteralPath .\internal\module\auth\platform_route.go,.\internal\module\auth\platform_handler.go,.\internal\module\auth\platform_handler_test.go,.\internal\module\auth\platform_dto.go -Force
```

Expected: files are removed.

- [ ] **Step 8: Compile app transport package**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/auth/transport/app -count=1
```

Expected: PASS after import and type-prefix fixes.

---

## Task 4: Rewire router and remove `/api/Users/*`

**Files:**

- Modify: `admin_back_go/internal/server/router.go`
- Modify: `admin_back_go/internal/module/user/route.go`
- Modify: `admin_back_go/internal/middleware/auth_token.go`
- Modify: `admin_back_go/internal/server/router_test.go`
- Modify: `admin_back_go/internal/module/user/handler_test.go`

- [ ] **Step 1: Update server route imports and registration**

In `internal/server/router.go`, import auth transports:

```go
authadmin "admin_back_go/internal/module/auth/transport/admin"
authapp "admin_back_go/internal/module/auth/transport/app"
```

Replace old calls with:

```go
authadmin.Register(router, deps.AuthService)
authapp.Register(router, authapp.RouteOptions{
	Prefix:         "/api/app/v1/auth",
	Platform:       enum.PlatformApp,
	AuthService:    deps.AuthService,
	CaptchaService: deps.CaptchaService,
	UserService:    deps.UserService,
})
```

Expected: `rg -n "RegisterPlatformRoutes|auth\.RegisterRoutes" admin_back_go/internal` has no matches.

- [ ] **Step 2: Remove user legacy init route**

In `internal/module/user/route.go`, remove:

```go
legacy := router.Group("/api/Users")
legacy.POST("/init", handler.Init)
```

Expected: `/api/admin/v1/users/init`, `/api/admin/v1/users/me`, `/api/app/v1/users/me`, and `/api/app/v1/profile` remain registered.

- [ ] **Step 3: Remove `/api/Users/*` auth-token whitelist entries**

In `internal/middleware/auth_token.go`, remove all public path entries for `/api/Users/getLoginConfig`, `/api/Users/sendCode`, `/api/Users/login`, `/api/Users/refresh`, `/api/Users/logout`, and `/api/Users/init`.

Expected: `rg -n "/api/Users" admin_back_go/internal/middleware/auth_token.go` has no matches.

- [ ] **Step 4: Update tests that asserted legacy route behavior**

Remove `POST /api/Users/init` tests from `internal/module/user/handler_test.go`.

In `internal/server/router_test.go`, add a route-level assertion using the existing router test helper in that file:

```go
func TestLegacyUsersRoutesAreNotRegistered(t *testing.T) {
	router := newTestRouter(t)

	for _, tc := range []struct {
		method string
		path   string
	}{
		{method: http.MethodPost, path: "/api/Users/getLoginConfig"},
		{method: http.MethodPost, path: "/api/Users/sendCode"},
		{method: http.MethodPost, path: "/api/Users/login"},
		{method: http.MethodPost, path: "/api/Users/refresh"},
		{method: http.MethodPost, path: "/api/Users/logout"},
		{method: http.MethodPost, path: "/api/Users/init"},
	} {
		recorder := httptest.NewRecorder()
		router.ServeHTTP(recorder, httptest.NewRequest(tc.method, tc.path, nil))
		if recorder.Code != http.StatusNotFound {
			t.Fatalf("expected %s %s to be unregistered, got status=%d body=%s", tc.method, tc.path, recorder.Code, recorder.Body.String())
		}
	}
}
```

If the helper is not named `newTestRouter`, use the existing helper in `router_test.go` that builds a router with fake dependencies.

- [ ] **Step 5: Run focused backend tests**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/server ./internal/middleware ./internal/module/user -run 'TestLegacyUsersRoutesAreNotRegistered|TestAuth|TestApp|TestUser|TestPublic' -count=1
```

Expected: PASS. If the regex misses local test names, run the full package set in Task 5.

---

## Task 5: Make the boundary guard GREEN

**Files:**

- Validate only, with fixes in files touched by Tasks 2-4 if checks fail.

- [ ] **Step 1: Run architecture guard**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture -count=1
```

Expected: PASS.

- [ ] **Step 2: Check forbidden auth patterns**

Run:

```powershell
cd E:\admin_go\admin_back_go
rg -n "RegisterPlatformRoutes|platform_handler|platform_route|platform_dto|/api/Users|auth\.RegisterRoutes" internal
Get-ChildItem .\internal\module\auth -File | Where-Object { $_.Name -in @('route.go','handler.go','request.go','handler_test.go') -or $_.Name -like 'platform_*' -or $_.Name -like 'app_*' -or $_.Name -like 'admin_*' }
```

Expected: both commands produce no output. The PowerShell file check now also catches stale `handler_test.go` at module root (which would mean the tests were not relocated to `transport/admin/`).

- [ ] **Step 3: Check required transport files**

Run:

```powershell
cd E:\admin_go\admin_back_go
Test-Path .\internal\module\auth\transport\admin\route.go
Test-Path .\internal\module\auth\transport\admin\handler.go
Test-Path .\internal\module\auth\transport\admin\handler_test.go
Test-Path .\internal\module\auth\transport\admin\presenter.go
Test-Path .\internal\module\auth\transport\app\route.go
Test-Path .\internal\module\auth\transport\app\handler.go
Test-Path .\internal\module\auth\transport\app\handler_test.go
Test-Path .\internal\module\auth\transport\app\presenter.go
```

Expected: eight `True` lines.

- [ ] **Step 4: Run focused auth/server package tests**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture ./internal/module/auth ./internal/module/auth/transport/admin ./internal/module/auth/transport/app ./internal/module/user ./internal/server ./internal/middleware -count=1
```

Expected: PASS.

---

## Task 6: Final verification gate for plan-02

**Files:**

- Validate only.

- [ ] **Step 1: Run backend focused tests**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture ./internal/module/auth ./internal/module/auth/transport/admin ./internal/module/auth/transport/app ./internal/module/user ./internal/server ./internal/middleware -count=1
```

Expected: PASS.

- [ ] **Step 2: Run backend full tests**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./... -count=1
```

Expected: PASS. If this fails outside touched areas, capture the failing package and do not claim full backend green.

- [ ] **Step 3: Run frontend grep for deleted legacy calls**

Run:

```powershell
cd E:\admin_go
rg -n "/api/Users" admin_front_ts\src admin_front_ts\tests admin_app\src admin_app\tests -g "!*node_modules*" -g "!*dist*"
```

Expected: no output.

- [ ] **Step 4: Run root governance gates**

Run:

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected: `git diff --check` exits 0 and governance checker prints `PASS: no blocking governance violations found.`

- [ ] **Step 5: Final handoff text**

Use this exact scope statement in the implementation handoff:

```text
Completed in plan-02: auth transport reorg (transport/{admin,app}) + /api/Users backend removal + boundary architecture guard.
Not executed in plan-02: captcha/session/usersession/userloginlog merge (plan-03), governance docs (plan-01), frontend legacy cleanup (plan-04), shared/dict, smaller module shells, AI aggregation, internal/platform -> internal/infra rename.
Plan-03 must execute next to fully complete spec §12.1.
```

---

## Sibling and follow-up plans

**Parallel siblings (can run from t=0 alongside this plan):**

```text
2026-05-27-multi-platform-01-governance-docs.md
    Pure markdown, R1-R8 + AGENTS.md + status doc. Zero .go touch.

2026-05-27-multi-platform-04-frontend-legacy-cleanup.md
    admin_front_ts + admin_app: rewrite or remove /api/Users callers.
```

**Sequential after this plan (must wait until plan-02 merges):**

```text
2026-05-27-multi-platform-03-module-consolidation.md
    Merge captcha/session/usersession/userloginlog into auth.
    Touches files this plan creates (auth/transport/{admin,app}/handler.go imports).
```

**Later follow-ups (one plan per spec knife, scheduled after plan-03):**

```text
2026-05-27-shared-dict-service.md            spec §12.2
2026-05-27-small-module-transport-shells.md  spec §12.3
2026-05-27-profile-and-ai-aggregation.md     spec §12.4
2026-05-27-infra-rename.md                   spec §12.5
```

Each follow-up plan starts with RED tests or static architecture guards.

---

## Plan self-review

- Spec coverage: covers spec §12.1 auth transport reorg + `/api/Users` cleanup. Adjacent module merge (captcha/session/usersession/userloginlog) is split to plan-03 to allow plan-01/02/04 parallelism; full spec §12.1 completion requires plan-03 to follow.
- Boundary consistency: uses `platform` only for business entry dimension and `infra` for external technical resources.
- No admin-only drift: current admin exposure is `transport/admin`, not a capability boundary.
- TDD: starts with failing static architecture tests before moving auth route files.
- Pre-flight gate: Task 0 enforces frontend grep and baseline-green before any code change, per spec §14.1 R-3.
- File completeness: all 18 `auth/*.go` files have a destination (move / delete / keep at module root), including `handler_test.go` and `platform_handler_test.go` which would otherwise break the build.
- DTO disposition: `dto.go` stays at module root as service-contract types; `platform_dto.go` content explicitly migrates to `transport/app/presenter.go` (response) and was already covered by `request.go`.
- Naming: transport packages export `Register` per spec §5.3, not `RegisterRoutes` / `RegisterPlatformRoutes`.
- Four-file convention: each `transport/{platform}/` has `route.go` + `handler.go` + `request.go` + `presenter.go` per spec §4.
- Runtime safety: removes `/api/Users/*` only with architecture guard, route test, middleware cleanup, and frontend grep (pre + post).
- Verification: requires focused Go tests, full backend test attempt, frontend grep, `git diff --check`, and root governance checker.
- Parallelism: zero file overlap with plan-01 (only `.go` and bootstrap touched). Zero file overlap with plan-04 (only backend touched). Sequential w.r.t. plan-03 (plan-03 modifies files this plan creates).
