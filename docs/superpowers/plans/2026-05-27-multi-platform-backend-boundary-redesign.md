# Multi-platform Auth Transport Boundary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the first executable slice of `2026-05-27-multi-platform-backend-boundary-design.md`: make auth the reference `module/{capability}/transport/{platform}` module, remove `/api/Users/*` backend compatibility routes, and sync root governance docs with module/transport/shared/infra rules.

**Architecture:** `platform` means business entry (`admin/app/openapi/merchant`); `infra` means external technical resources. `internal/module/auth/transport/{admin,app}` owns HTTP/Gin request binding and routes; `internal/module/auth` keeps shared auth service/repository/model code. The source spec has five migration knives, so this plan implements knife `12.1A` only and records the rest as separate plans for clean rollback.

**Tech Stack:** Go, Gin, PowerShell, Markdown governance docs, `go test`, `rg`, `git diff --check`, `scripts/check-agent-governance.ps1`.

---

## Scope Check

Source spec: `docs/superpowers/specs/2026-05-27-multi-platform-backend-boundary-design.md`.

This plan executes:

```text
1. Root governance docs align with R1-R8, infra naming, and no admin-only capability rule.
2. Auth admin/app routes move under transport/{admin,app}.
3. /api/Users/* backend compatibility routes are removed.
4. Static architecture tests protect the new boundary.
```

This plan does not merge `captcha`, `session`, `usersession`, or `userloginlog` into `auth`; that becomes knife `12.1B`. It also does not execute shared/dict, small module shells, module aggregation, or `internal/platform -> internal/infra` import rename.

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
- Create: `admin_back_go/internal/module/auth/transport/admin/request.go`
- Create: `admin_back_go/internal/module/auth/transport/app/route.go`
- Create: `admin_back_go/internal/module/auth/transport/app/handler.go`
- Create: `admin_back_go/internal/module/auth/transport/app/request.go`
- Modify: `admin_back_go/internal/module/auth/service.go`
- Modify: `admin_back_go/internal/module/auth/dto.go`
- Delete: `admin_back_go/internal/module/auth/route.go`
- Delete: `admin_back_go/internal/module/auth/handler.go`
- Delete: `admin_back_go/internal/module/auth/request.go`
- Delete: `admin_back_go/internal/module/auth/platform_route.go`
- Delete: `admin_back_go/internal/module/auth/platform_handler.go`
- Delete: `admin_back_go/internal/module/auth/platform_dto.go`

Route/bootstrap cleanup:

- Modify: `admin_back_go/internal/server/router.go`
- Modify: `admin_back_go/internal/module/user/route.go`
- Modify: `admin_back_go/internal/middleware/auth_token.go`
- Modify: `admin_back_go/internal/server/router_test.go`
- Modify: `admin_back_go/internal/module/user/handler_test.go`

---

## Task 1: Sync root architecture docs with spec decisions

**Files:**

- Modify: `AGENTS.md`
- Modify: `docs/architecture/04-go-backend-framework.md`
- Modify: `docs/architecture/05-development-quality-rules.md`
- Modify: `docs/status/current-status.md`

- [ ] **Step 1: Update `AGENTS.md` vocabulary**

Ensure `AGENTS.md` says:

```markdown
module    = 业务能力归属：auth/user/profile/permission/payment/wallet/ai/system
transport = 多平台 HTTP 表面：admin/app/openapi/merchant
shared    = 跨领域公共能力：dict/enum/validate/i18n/setting/pagination/errors
infra     = 运行时技术资源：db/redis/queue/storage/tencent/openai/alipay/logging
```

Expected: `platform` is no longer used for external resources.

- [ ] **Step 2: Update `docs/architecture/04-go-backend-framework.md` conclusion**

Use this sentence:

```markdown
cmd -> bootstrap -> server -> module/{capability}/transport/{platform} -> module service -> shared/infra
```

Add: `platform` only means business platform; external technical resources are `infra`; adapter is a role inside infra, not the layer name.

- [ ] **Step 3: Update `docs/architecture/05-development-quality-rules.md` multi-platform rule**

Ensure the layer decision table says:

```text
route prefix 不同      -> transport/{platform}
请求字段不同          -> transport request DTO
返回字段不同          -> transport presenter
认证/会话策略不同     -> auth/session policy 或 auth_platforms 策略
业务规则真的不同      -> module service 的显式 policy/input
跨领域公共数据        -> shared/dict 或 shared/setting
外部 SDK/基础设施差异 -> infra
```

- [ ] **Step 4: Update `docs/status/current-status.md` without fake implementation claims**

Use wording like:

```markdown
架构方向更新：`platform` 只表示业务平台：admin/app/openapi/merchant；外部技术资源层叫 `infra`。当前 `internal/module` 与 `internal/platform` 仍是过渡事实，目录迁移必须逐刀验证。
```

- [ ] **Step 5: Verify docs wording**

Run:

```powershell
cd E:\admin_go
rg -n "platform = 外部|api/domain/shared/platform|internal/adapter|adapter/\s+★" AGENTS.md docs\architecture docs\status
rg -n "module/\{capability\}/transport/\{platform\}|shared/infra|外部技术资源层叫 `infra`|不要把任何业务能力定义成长期" AGENTS.md docs\architecture docs\status
```

Expected: first `rg` has no matches; second `rg` has matches in root governance docs.

---

## Task 2: Add RED architecture guard for auth transport boundary

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
		"internal/module/auth/transport/admin/request.go",
		"internal/module/auth/transport/app/route.go",
		"internal/module/auth/transport/app/handler.go",
		"internal/module/auth/transport/app/request.go",
	} {
		mustExist(t, root, rel)
	}
	for _, rel := range []string{
		"internal/module/auth/route.go",
		"internal/module/auth/handler.go",
		"internal/module/auth/request.go",
		"internal/module/auth/platform_route.go",
		"internal/module/auth/platform_handler.go",
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

## Task 3: Move admin auth HTTP surface to `transport/admin`

**Files:**

- Create: `admin_back_go/internal/module/auth/transport/admin/route.go`
- Create: `admin_back_go/internal/module/auth/transport/admin/handler.go`
- Create: `admin_back_go/internal/module/auth/transport/admin/request.go`
- Delete: `admin_back_go/internal/module/auth/route.go`
- Delete: `admin_back_go/internal/module/auth/handler.go`
- Delete: `admin_back_go/internal/module/auth/request.go`
- Modify: `admin_back_go/internal/module/auth/dto.go`

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

func RegisterRoutes(router *gin.Engine, service auth.SessionService) {
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

- [ ] **Step 5: Delete old admin HTTP files**

Run:

```powershell
cd E:\admin_go\admin_back_go
Remove-Item -LiteralPath .\internal\module\auth\route.go,.\internal\module\auth\handler.go,.\internal\module\auth\request.go -Force
```

Expected: files are removed.

- [ ] **Step 6: Compile admin transport package**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/auth/transport/admin -count=1
```

Expected: PASS after import and type-prefix fixes.

---

## Task 4: Move app auth HTTP surface to `transport/app`

**Files:**

- Create: `admin_back_go/internal/module/auth/transport/app/route.go`
- Create: `admin_back_go/internal/module/auth/transport/app/handler.go`
- Create: `admin_back_go/internal/module/auth/transport/app/request.go`
- Delete: `admin_back_go/internal/module/auth/platform_route.go`
- Delete: `admin_back_go/internal/module/auth/platform_handler.go`
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

func RegisterRoutes(router *gin.Engine, opts RouteOptions) {
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

- [ ] **Step 5: Delete platform-prefixed files**

Run:

```powershell
cd E:\admin_go\admin_back_go
Remove-Item -LiteralPath .\internal\module\auth\platform_route.go,.\internal\module\auth\platform_handler.go,.\internal\module\auth\platform_dto.go -Force
```

Expected: files are removed.

- [ ] **Step 6: Compile app transport package**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/auth/transport/app -count=1
```

Expected: PASS after import and type-prefix fixes.

---

## Task 5: Rewire router and remove `/api/Users/*`

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
authadmin.RegisterRoutes(router, deps.AuthService)
authapp.RegisterRoutes(router, authapp.RouteOptions{
	Prefix:         "/api/app/v1/auth",
	Platform:       enum.PlatformApp,
	AuthService:    deps.AuthService,
	CaptchaService: deps.CaptchaService,
	UserService:    deps.UserService,
})
```

Expected: `rg -n "RegisterPlatformRoutes" admin_back_go/internal` has no matches.

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

Expected: PASS. If the regex misses local test names, run the full package set in Task 6.

---

## Task 6: Make the boundary guard GREEN

**Files:**

- Validate only, with fixes in files touched by Tasks 3-5 if checks fail.

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
rg -n "RegisterPlatformRoutes|platform_handler|platform_route|platform_dto|/api/Users" internal
Get-ChildItem .\internal\module\auth -File | Where-Object { $_.Name -in @('route.go','handler.go','request.go') -or $_.Name -like 'platform_*' -or $_.Name -like 'app_*' -or $_.Name -like 'admin_*' }
```

Expected: both commands produce no output.

- [ ] **Step 3: Check required transport files**

Run:

```powershell
cd E:\admin_go\admin_back_go
Test-Path .\internal\module\auth\transport\admin\route.go
Test-Path .\internal\module\auth\transport\admin\handler.go
Test-Path .\internal\module\auth\transport\app\route.go
Test-Path .\internal\module\auth\transport\app\handler.go
```

Expected:

```text
True
True
True
True
```

- [ ] **Step 4: Run focused auth/server package tests**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture ./internal/module/auth ./internal/module/auth/transport/admin ./internal/module/auth/transport/app ./internal/module/user ./internal/server ./internal/middleware -count=1
```

Expected: PASS.

---

## Task 7: Update docs after code movement

**Files:**

- Modify: `admin_back_go/docs/architecture.md`
- Modify: `docs/status/current-status.md`
- Modify: `docs/architecture/04-go-backend-framework.md`
- Modify: `docs/architecture/05-development-quality-rules.md`
- Modify: `docs/testing/smoke-matrix.md` if it mentions `/api/Users/*`
- Modify: `docs/contracts/admin-api-v1.md` if it mentions `/api/Users/*`

- [ ] **Step 1: Remove active legacy route docs**

Run:

```powershell
cd E:\admin_go
rg -n "/api/Users|legacy adapter|compat adapter|fallback bridge" docs admin_back_go\docs
```

Expected before edit: matches may exist. Rewrite them as removed historical notes or delete active-runtime references.

- [ ] **Step 2: Document auth as the first reference transport module**

Add wording to backend architecture docs:

```markdown
Auth is the first reference multi-platform module:

```text
internal/module/auth/service.go                  # shared auth business capability
internal/module/auth/transport/admin/route.go    # /api/admin/v1/auth/*
internal/module/auth/transport/app/route.go      # /api/app/v1/auth/*
```

`transport/admin` is the current admin exposure, not an admin-only capability. Future platforms extend the same `auth` capability with `transport/{platform}`.
```

- [ ] **Step 3: Update current status precisely**

In `docs/status/current-status.md`, say auth transport boundary is implemented only after code passes. Do not claim shared/dict, all module shells, or `internal/infra` rename are implemented.

- [ ] **Step 4: Verify docs search**

Run:

```powershell
cd E:\admin_go
rg -n "/api/Users|legacy adapter|compat adapter|fallback bridge" docs admin_back_go\docs admin_back_go\internal
rg -n "transport/\{admin,app\}|module/auth/transport|internal/module/auth/transport" docs admin_back_go\docs
```

Expected: first command has no active runtime references; second command documents the auth transport boundary.

---

## Task 8: Final verification gate for knife 12.1A

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
Completed in this plan: knife 12.1A auth transport boundary + /api/Users cleanup.
Not executed in this plan: 12.1B captcha/session/usersession/userloginlog consolidation, 12.2 shared/dict, 12.3 smaller module transport shells, 12.4 module aggregation/profile split, 12.5 internal/platform -> internal/infra rename.
```

---

## Follow-up Plan Queue

Create separate Superpowers plans in this order after knife `12.1A` is green:

```text
1. 2026-05-27-auth-adjacent-module-consolidation.md
   Scope: move captcha/session/usersession/userloginlog under auth or prove why one stays separate.

2. 2026-05-27-shared-dict-service.md
   Scope: internal/dict -> internal/shared/dict Service + Registry, register providers, migrate one page-init.

3. 2026-05-27-small-module-transport-shells.md
   Scope: permission/auth_platform/system_setting/system_log/operation_log/cron_task/queue_monitor one module per task.

4. 2026-05-27-profile-boundary-and-module-aggregation.md
   Scope: profile split, user self-service, notification task merge, AI module aggregation.

5. 2026-05-27-infra-rename.md
   Scope: internal/platform -> internal/infra import rename and wrapper/adapter role documentation.
```

Each follow-up plan starts with RED tests or static architecture guards and ends with task-specific tests plus root governance checks when root docs are touched.

---

## Plan self-review

- Spec coverage: covers spec knife `12.1A` and explicitly queues `12.1B` plus `12.2`-`12.5` as separate plans.
- Boundary consistency: uses `platform` only for business entry dimension and `infra` for external technical resources.
- No admin-only drift: current admin exposure is `transport/admin`, not a capability boundary.
- TDD: starts with failing static architecture tests before moving auth route files.
- Runtime safety: removes `/api/Users/*` only with architecture guard, route test, middleware cleanup, and frontend grep.
- Verification: requires focused Go tests, full backend test attempt, frontend grep, `git diff --check`, and root governance checker.
