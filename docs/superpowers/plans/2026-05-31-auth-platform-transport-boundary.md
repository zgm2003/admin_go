# Auth Platform Transport Boundary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 Canvas/App/Admin 后端入口恢复成一条直线：URL -> `server/routes_*.go` -> `internal/module/{capability}/transport/{platform}` -> handler -> service -> repository/infra。

**Architecture:** 平台差异只落在 `transport/{platform}` 的 route/request/presenter/handler；service、repository、infra 继续复用。`server` 层只显式调用对应平台 transport 的 `Register`，不再传动态 `Prefix + Platform` 把一个平台 URL 挂到另一个平台 transport 里。

**Tech Stack:** Go + Gin, current `apperror` / `response` / `validate`, architecture tests under `admin_back_go/internal/architecture`, PowerShell verification on Windows.

---

## Linus 三问

1. **这是真问题吗？** 是。当前 `/api/canvas/v1/auth/*` 由 `auth/transport/app` 注册，`/api/canvas/v1/users/me` 由 `profile/transport/app` 注册，`/api/canvas/v1/wallet/*` 和 `/api/canvas/v1/payment/recharges*` 由 admin payment transports 注册。能跑，但路线是弯的。
2. **更简单的做法？** 有。别搞“万能前台 transport”和动态路由工厂；每个平台一个薄 transport 包，service 继续复用。
3. **会破坏什么？** 不允许破坏 URL、请求体、响应体、token 平台校验、login-config、captcha、send-code、401/403。所有改动要靠测试证明外部 contract 不变。

## Scope

本计划只修 Go 后端路由线和对应文档；不改 DB schema，不改前端 UI，不改登录配置数据。

当前已确认的坏点：

```text
admin_back_go/internal/server/routes_auth.go
  canvas auth 通过 authapp.Register(RouteOptions{Prefix: "/api/canvas/v1/auth", Platform: canvas}) 注册

admin_back_go/internal/server/routes_admin_user.go
  canvas users/me 通过 profileapp.RegisterRoutesWithOptions(... UsersPrefix: "/api/canvas/v1/users") 注册

admin_back_go/internal/server/routes_admin_commerce_rbac.go
  canvas wallet 通过 walletadmin.RegisterCurrentUserRoutes(router, "/api/canvas/v1/wallet", ...) 注册
  canvas recharge 通过 paymentadmin.RegisterRechargeRoutes(router, "/api/canvas/v1/payment/recharges", ...) 注册
```

## File Structure

Create:

```text
admin_back_go/internal/architecture/platform_route_line_test.go
admin_back_go/internal/module/auth/transport/canvas/{route.go,handler.go,request.go,presenter.go,handler_test.go}
admin_back_go/internal/module/profile/transport/canvas/{route.go,handler.go,dto.go,route_test.go}
admin_back_go/internal/module/payment/transport/canvas/{route.go,handler.go,request.go,handler_test.go}
admin_back_go/internal/module/payment/wallet/transport/canvas/{route.go,handler.go,request.go,handler_test.go}
```

Modify:

```text
admin_back_go/internal/architecture/{multiplatform_boundary_test.go,canvas_front_next_integration_test.go}
admin_back_go/internal/server/{routes_auth.go,routes_admin_user.go,routes_admin_commerce_rbac.go,router_test.go}
admin_back_go/internal/module/auth/transport/app/{route.go,handler.go,handler_test.go}
admin_back_go/internal/module/profile/transport/app/{route.go,handler.go,route_test.go}
admin_back_go/internal/module/payment/transport/admin/route.go
admin_back_go/internal/module/payment/wallet/transport/admin/route.go
docs/status/current-status.md
docs/status/module-matrix.md
docs/contracts/admin-api-v1.md
docs/testing/smoke-matrix.md
```

Do not modify:

```text
admin_back_go/database/migrations/*.sql
admin_front_ts/**
canvas_front_next/**
```

---

### Task 1: Add RED architecture guard for one-route-line ownership

**Files:**
- Create: `admin_back_go/internal/architecture/platform_route_line_test.go`
- Modify: `admin_back_go/internal/architecture/canvas_front_next_integration_test.go`
- Modify: `admin_back_go/internal/architecture/multiplatform_boundary_test.go`

- [ ] **Step 1: Create failing route-line architecture test**

Create `admin_back_go/internal/architecture/platform_route_line_test.go`:

```go
package architecture

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestPlatformRouteLineOwnership(t *testing.T) {
	root := backendRoot(t)
	for _, rel := range []string{
		"internal/module/auth/transport/canvas/route.go",
		"internal/module/auth/transport/canvas/handler.go",
		"internal/module/profile/transport/canvas/route.go",
		"internal/module/profile/transport/canvas/handler.go",
		"internal/module/payment/transport/canvas/route.go",
		"internal/module/payment/transport/canvas/handler.go",
		"internal/module/payment/wallet/transport/canvas/route.go",
		"internal/module/payment/wallet/transport/canvas/handler.go",
	} {
		mustExist(t, root, rel)
	}

	routesAuth := readRouteLineSource(t, root, "internal/server/routes_auth.go")
	mustContainRouteLine(t, routesAuth, `authcanvas "admin_back_go/internal/module/auth/transport/canvas"`)
	mustContainRouteLine(t, routesAuth, `authcanvas.Register(router, authcanvas.Dependencies{`)
	mustNotContainRouteLine(t, routesAuth, `Prefix:         "/api/canvas/v1/auth"`)
	mustNotContainRouteLine(t, routesAuth, `authapp.RouteOptions`)

	routesUser := readRouteLineSource(t, root, "internal/server/routes_admin_user.go")
	mustContainRouteLine(t, routesUser, `profilecanvas "admin_back_go/internal/module/profile/transport/canvas"`)
	mustContainRouteLine(t, routesUser, `profilecanvas.RegisterRoutes(router, profilecanvas.Dependencies{`)
	mustNotContainRouteLine(t, routesUser, `RegisterRoutesWithOptions`)
	mustNotContainRouteLine(t, routesUser, `UsersPrefix: "/api/canvas/v1/users"`)

	routesCommerce := readRouteLineSource(t, root, "internal/server/routes_admin_commerce_rbac.go")
	mustContainRouteLine(t, routesCommerce, `paymentcanvas "admin_back_go/internal/module/payment/transport/canvas"`)
	mustContainRouteLine(t, routesCommerce, `walletcanvas "admin_back_go/internal/module/payment/wallet/transport/canvas"`)
	mustContainRouteLine(t, routesCommerce, `walletcanvas.RegisterRoutes(router, deps.WalletService)`)
	mustContainRouteLine(t, routesCommerce, `paymentcanvas.RegisterRechargeRoutes(router, deps.PaymentService)`)
	mustNotContainRouteLine(t, routesCommerce, `walletadmin.RegisterCurrentUserRoutes(router, "/api/canvas/v1/wallet"`)
	mustNotContainRouteLine(t, routesCommerce, `paymentadmin.RegisterRechargeRoutes(router, "/api/canvas/v1/payment/recharges"`)
}

func TestNoCrossPlatformURLPrefixInsideWrongTransport(t *testing.T) {
	root := backendRoot(t)
	moduleRoot := filepath.Join(root, "internal", "module")
	var offenders []string
	err := filepath.WalkDir(moduleRoot, func(path string, entry os.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if entry.IsDir() || filepath.Ext(path) != ".go" || strings.HasSuffix(path, "_test.go") {
			return nil
		}
		rel, _ := filepath.Rel(root, path)
		rel = filepath.ToSlash(rel)
		if !strings.Contains(rel, "/transport/") {
			return nil
		}
		body, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		text := string(body)
		switch {
		case strings.Contains(rel, "/transport/app/") && strings.Contains(text, `"/api/canvas/v1`):
			offenders = append(offenders, rel+" contains canvas URL inside app transport")
		case strings.Contains(rel, "/transport/admin/") && strings.Contains(text, `"/api/canvas/v1`):
			offenders = append(offenders, rel+" contains canvas URL inside admin transport")
		case strings.Contains(rel, "/transport/canvas/") && strings.Contains(text, `"/api/app/v1`):
			offenders = append(offenders, rel+" contains app URL inside canvas transport")
		case strings.Contains(rel, "/transport/canvas/") && strings.Contains(text, `"/api/admin/v1`):
			offenders = append(offenders, rel+" contains admin URL inside canvas transport")
		}
		return nil
	})
	if err != nil {
		t.Fatalf("walk transport files: %v", err)
	}
	if len(offenders) > 0 {
		t.Fatalf("platform URL prefix must stay inside matching transport package:\n  %s", strings.Join(offenders, "\n  "))
	}
}

func readRouteLineSource(t *testing.T, root string, rel string) string {
	t.Helper()
	body, err := os.ReadFile(filepath.Join(root, rel))
	if err != nil {
		t.Fatalf("read %s: %v", rel, err)
	}
	return string(body)
}

func mustContainRouteLine(t *testing.T, text string, want string) {
	t.Helper()
	if !strings.Contains(text, want) {
		t.Fatalf("expected route-line source to contain %q", want)
	}
}

func mustNotContainRouteLine(t *testing.T, text string, forbidden string) {
	t.Helper()
	if strings.Contains(text, forbidden) {
		t.Fatalf("route-line source must not contain %q", forbidden)
	}
}
```

- [ ] **Step 2: Run RED**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture -run "PlatformRouteLine" -count=1
```

Expected: FAIL with missing canvas transport files and wrong server registrations.

- [ ] **Step 3: Update existing Canvas integration guard**

In `admin_back_go/internal/architecture/canvas_front_next_integration_test.go`, replace the `AuthRoutesAndPlatform` subtest with assertions for `authcanvas.Register(...)`, no `Prefix: "/api/canvas/v1/auth"`, and `assertCanvasPathExists(t, "internal/module/auth/transport/canvas")`.

Add helper:

```go
func assertCanvasPathExists(t *testing.T, rel string) {
	t.Helper()
	if _, err := os.Stat(filepath.Join(backendRoot(t), rel)); err != nil {
		t.Fatalf("path must exist: %s: %v", rel, err)
	}
}
```

- [ ] **Step 4: Extend multiplatform shape guard**

Extend `TestAuthTransportBoundaryShape` with:

```go
authRoot + "transport/canvas/route.go",
authRoot + "transport/canvas/handler.go",
authRoot + "transport/canvas/handler_test.go",
authRoot + "transport/canvas/request.go",
authRoot + "transport/canvas/presenter.go",
```

Extend `TestUserProfileTransportShape` with:

```go
"internal/module/profile/transport/canvas/route.go",
"internal/module/profile/transport/canvas/handler.go",
```

Extend `TestCommerceRBACAdminTransportShells` with:

```go
mustExist(t, root, "internal/module/payment/transport/canvas/route.go")
mustExist(t, root, "internal/module/payment/wallet/transport/canvas/route.go")
```

---

### Task 2: Split auth app/canvas transport

**Files:**
- Modify: `admin_back_go/internal/module/auth/transport/app/{route.go,handler.go,handler_test.go}`
- Create: `admin_back_go/internal/module/auth/transport/canvas/{route.go,handler.go,request.go,presenter.go,handler_test.go}`

- [ ] **Step 1: Replace app route with fixed app prefix**

Replace `auth/transport/app/route.go`:

```go
package app

import (
	authmodule "admin_back_go/internal/module/auth"
	"admin_back_go/internal/shared/validate"

	"github.com/gin-gonic/gin"
)

const routePrefix = "/api/app/v1/auth"

type Dependencies struct {
	AuthService    authmodule.SessionService
	CaptchaService authmodule.CaptchaHTTPService
	UserService    UserInitService
}

func Register(router *gin.Engine, deps Dependencies) {
	validate.MustRegister()
	handler := NewHandler(deps)
	group := router.Group(routePrefix)
	group.GET("/login-config", handler.LoginConfig)
	group.GET("/captcha", handler.Captcha)
	group.POST("/send-code", handler.SendCode)
	group.POST("/login", handler.Login)
	group.POST("/logout", handler.Logout)
}
```

- [ ] **Step 2: Fix app handler platform internally**

In `auth/transport/app/handler.go`:

```go
const platform = enum.PlatformApp

type Handler struct {
	authService    authmodule.SessionService
	captchaService authmodule.CaptchaHTTPService
	userService    UserInitService
}

func NewHandler(deps Dependencies) *Handler {
	return &Handler{
		authService:    deps.AuthService,
		captchaService: deps.CaptchaService,
		userService:    deps.UserService,
	}
}
```

Replace all `h.platform` uses with `platform`. The decisive calls must become:

```go
result, appErr := h.authService.LoginConfig(c.Request.Context(), platform)
```

```go
Platform: platform,
```

```go
currentUser, appErr := h.userService.Init(c.Request.Context(), user.InitInput{UserID: result.UserID, Platform: platform})
```

- [ ] **Step 3: Update app handler test registration**

In `auth/transport/app/handler_test.go`, replace test router setup:

```go
func newAuthTestRouter(authService authmodule.SessionService, userService UserInitService) *gin.Engine {
	gin.SetMode(gin.ReleaseMode)
	router := gin.New()
	Register(router, Dependencies{
		AuthService:    authService,
		CaptchaService: fakeCaptchaService{},
		UserService:    userService,
	})
	return router
}
```

- [ ] **Step 4: Create canvas route/request/presenter**

Create `auth/transport/canvas/route.go` with the same `Dependencies` shape as app, but:

```go
package canvas

const routePrefix = "/api/canvas/v1/auth"

func Register(router *gin.Engine, deps Dependencies) {
	validate.MustRegister()
	handler := NewHandler(deps)
	group := router.Group(routePrefix)
	group.GET("/login-config", handler.LoginConfig)
	group.GET("/captcha", handler.Captcha)
	group.POST("/send-code", handler.SendCode)
	group.POST("/login", handler.Login)
	group.POST("/logout", handler.Logout)
}
```

Create `request.go` with `SendCodeRequest`, `captchaAnswerRequest`, and `LoginRequest` matching app exactly. Create `presenter.go` with `loginResponse` and `canvasUser` matching the current app response keys: `token`, `user.id`, `user.nickname`, `user.avatar`.

- [ ] **Step 5: Create canvas handler**

Create `auth/transport/canvas/handler.go` with the same handler logic as the fixed app handler, but:

```go
package canvas

const platform = enum.PlatformCanvas
```

The required service calls are:

```go
h.authService.LoginConfig(c.Request.Context(), platform)
```

```go
authmodule.LoginInput{Platform: platform}
```

```go
user.InitInput{UserID: result.UserID, Platform: platform}
```

- [ ] **Step 6: Create canvas handler tests**

Create `auth/transport/canvas/handler_test.go` by using the same fake services as app tests and these canvas paths/assertions:

```go
"/api/canvas/v1/auth/login-config"
"/api/canvas/v1/auth/captcha"
"/api/canvas/v1/auth/send-code"
"/api/canvas/v1/auth/login"
"/api/canvas/v1/auth/logout"
enum.PlatformCanvas
```

The test must prove a forged `platform: admin` request header does not change canvas platform input.

- [ ] **Step 7: Verify auth transports**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/auth/transport/app ./internal/module/auth/transport/canvas -count=1
```

Expected: PASS.

---

### Task 3: Split profile current-user canvas transport

**Files:**
- Modify: `admin_back_go/internal/module/profile/transport/app/{route.go,handler.go,route_test.go}`
- Create: `admin_back_go/internal/module/profile/transport/canvas/{route.go,handler.go,dto.go,route_test.go}`

- [ ] **Step 1: Replace app profile route with fixed app routes**

Replace `profile/transport/app/route.go`:

```go
package app

import (
	"admin_back_go/internal/module/profile"
	"admin_back_go/internal/shared/validate"

	"github.com/gin-gonic/gin"
)

func RegisterRoutes(router *gin.Engine, service profile.AppService) {
	validate.MustRegister()
	handler := NewHandler(service)

	users := router.Group("/api/app/v1/users")
	users.GET("/me", handler.Me)

	profileGroup := router.Group("/api/app/v1/profile")
	profileGroup.GET("", handler.Profile)
	profileGroup.PUT("", handler.UpdateProfile)
}
```

- [ ] **Step 2: Fix app handler platform**

In `profile/transport/app/handler.go`, remove the `platform string` field and make app platform local:

```go
type Handler struct {
	service profile.AppService
}

func NewHandler(service profile.AppService) *Handler {
	return &Handler{service: service}
}
```

The `Me` call must be:

```go
currentUser, appErr := h.service.Init(c.Request.Context(), profile.InitInput{UserID: identity.UserID, Platform: enum.PlatformApp})
```

`appIdentity` must reject a non-empty non-app identity platform:

```go
if identity.Platform != "" && identity.Platform != enum.PlatformApp {
	response.Error(c, apperror.UnauthorizedKey("auth.platform.invalid", map[string]any{"platform": identity.Platform}, "Token平台不匹配"))
	return nil, false
}
```

- [ ] **Step 3: Move canvas current-user tests out of app package**

Delete app-package tests that prove `RegisterRoutesWithOptions` can mount canvas. Keep app tests for `/api/app/v1/users/me`, `/api/app/v1/profile`, update profile, and wrong-platform 401.

- [ ] **Step 4: Create profile canvas route and handler**

Create `profile/transport/canvas/route.go`:

```go
package canvas

import (
	"admin_back_go/internal/module/profile"
	"admin_back_go/internal/shared/validate"

	"github.com/gin-gonic/gin"
)

type Dependencies struct {
	Service profile.AppService
}

func RegisterRoutes(router *gin.Engine, deps Dependencies) {
	validate.MustRegister()
	handler := NewHandler(deps.Service)
	users := router.Group("/api/canvas/v1/users")
	users.GET("/me", handler.Me)
}
```

Create `handler.go`:

```go
package canvas

import (
	"admin_back_go/internal/middleware"
	"admin_back_go/internal/module/profile"
	"admin_back_go/internal/shared/apperror"
	"admin_back_go/internal/shared/enum"
	"admin_back_go/internal/shared/response"

	"github.com/gin-gonic/gin"
)

type Handler struct {
	service profile.AppService
}

func NewHandler(service profile.AppService) *Handler {
	return &Handler{service: service}
}

func (h *Handler) Me(c *gin.Context) {
	identity, ok := h.canvasIdentity(c)
	if !ok {
		return
	}
	if h.service == nil {
		response.Error(c, apperror.InternalKey("user.service_missing", nil, "用户管理服务未配置"))
		return
	}
	currentUser, appErr := h.service.Init(c.Request.Context(), profile.InitInput{UserID: identity.UserID, Platform: enum.PlatformCanvas})
	if appErr != nil {
		response.Error(c, appErr)
		return
	}
	response.OK(c, canvasUserFromInit(currentUser))
}

func (h *Handler) canvasIdentity(c *gin.Context) (*middleware.AuthIdentity, bool) {
	identity := middleware.GetAuthIdentity(c)
	if identity == nil || identity.UserID <= 0 {
		response.Error(c, apperror.UnauthorizedKey("auth.token.invalid_or_expired", nil, "Token无效或已过期"))
		return nil, false
	}
	if identity.Platform != "" && identity.Platform != enum.PlatformCanvas {
		response.Error(c, apperror.UnauthorizedKey("auth.platform.invalid", map[string]any{"platform": identity.Platform}, "Token平台不匹配"))
		return nil, false
	}
	return identity, true
}
```

Create `dto.go` with `canvasUser{ id, nickname, avatar }` and `canvasUserFromInit(*profile.InitResponse)`.

- [ ] **Step 5: Create profile canvas route tests**

Create `profile/transport/canvas/route_test.go` proving:

```text
GET /api/canvas/v1/users/me -> profile.InitInput{UserID: current user, Platform: canvas}
GET /api/canvas/v1/profile -> 404
identity.Platform=admin on canvas route -> 401
```

- [ ] **Step 6: Verify profile transports**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/profile/transport/app ./internal/module/profile/transport/canvas -count=1
```

Expected: PASS.

---

### Task 4: Split canvas wallet/recharge out of admin transports

**Files:**
- Modify: `admin_back_go/internal/module/payment/transport/admin/route.go`
- Create: `admin_back_go/internal/module/payment/transport/canvas/{route.go,handler.go,request.go,handler_test.go}`
- Modify: `admin_back_go/internal/module/payment/wallet/transport/admin/route.go`
- Create: `admin_back_go/internal/module/payment/wallet/transport/canvas/{route.go,handler.go,request.go,handler_test.go}`

- [ ] **Step 1: Make payment admin route admin-only**

In `payment/transport/admin/route.go`, delete the exported dynamic function:

```go
func RegisterRechargeRoutes(router *gin.Engine, prefix string, service HTTPService)
```

Keep only fixed admin route registration:

```go
func registerRechargeRoutes(router *gin.Engine, handler *Handler) {
	recharges := router.Group("/api/admin/v1/payment/recharges")
	recharges.GET("/page-init", handler.RechargePageInit)
	recharges.GET("", handler.ListRecharges)
	recharges.GET("/:id", handler.GetRecharge)
	recharges.POST("", handler.CreateRecharge)
	recharges.POST("/:id/pay", handler.PayRecharge)
}
```

- [ ] **Step 2: Create payment canvas recharge transport**

Create `payment/transport/canvas/route.go`:

```go
package canvas

import (
	"context"

	paymentmodule "admin_back_go/internal/module/payment"
	"admin_back_go/internal/shared/apperror"
	"admin_back_go/internal/shared/validate"

	"github.com/gin-gonic/gin"
)

type HTTPService interface {
	RechargePageInit(ctx context.Context, userID int64) (*paymentmodule.RechargePageInitResponse, *apperror.Error)
	ListRecharges(ctx context.Context, query paymentmodule.RechargeListQuery) (*paymentmodule.RechargeListResponse, *apperror.Error)
	CreateRecharge(ctx context.Context, input paymentmodule.RechargeCreateInput) (*paymentmodule.RechargePayResponse, *apperror.Error)
	PayRecharge(ctx context.Context, userID int64, id int64) (*paymentmodule.RechargePayResponse, *apperror.Error)
}

func RegisterRechargeRoutes(router *gin.Engine, service HTTPService) {
	validate.MustRegister()
	handler := NewHandler(service)
	recharges := router.Group("/api/canvas/v1/payment/recharges")
	recharges.GET("/page-init", handler.RechargePageInit)
	recharges.GET("", handler.ListRecharges)
	recharges.POST("", handler.CreateRecharge)
	recharges.POST("/:id/pay", handler.PayRecharge)
}
```

Create `request.go` with the existing recharge query/body structs from admin. Create `handler.go` with the existing recharge handler behavior, but `canvasIdentity` must reject a non-empty non-canvas identity platform and all user-scoped service calls must use `identity.UserID`.

- [ ] **Step 3: Make wallet admin route admin-only**

In `payment/wallet/transport/admin/route.go`, delete the exported dynamic function:

```go
func RegisterCurrentUserRoutes(router *gin.Engine, prefix string, service HTTPService)
```

Keep only:

```go
func registerCurrentUserRoutes(router *gin.Engine, handler *Handler) {
	current := router.Group("/api/admin/v1/wallet")
	current.GET("/summary", handler.Summary)
	current.GET("/transactions", handler.Transactions)
}
```

- [ ] **Step 4: Create wallet canvas transport**

Create `payment/wallet/transport/canvas/route.go`:

```go
package canvas

import (
	"context"

	walletmodule "admin_back_go/internal/module/payment/wallet"
	"admin_back_go/internal/shared/apperror"
	"admin_back_go/internal/shared/validate"

	"github.com/gin-gonic/gin"
)

type HTTPService interface {
	Summary(ctx context.Context, userID int64) (*walletmodule.SummaryResponse, *apperror.Error)
	Transactions(ctx context.Context, query walletmodule.TransactionListQuery) (*walletmodule.TransactionListResponse, *apperror.Error)
}

func RegisterRoutes(router *gin.Engine, service HTTPService) {
	validate.MustRegister()
	handler := NewHandler(service)
	current := router.Group("/api/canvas/v1/wallet")
	current.GET("/summary", handler.Summary)
	current.GET("/transactions", handler.Transactions)
}
```

Create `request.go` with `transactionListRequest`. Create `handler.go` with `Summary` and `Transactions`; force `walletmodule.TransactionListQuery.UserID = identity.UserID` and reject wrong identity platform with 401.

- [ ] **Step 5: Create canvas payment/wallet tests**

Payment canvas tests must prove:

```text
GET /api/canvas/v1/payment/recharges/page-init -> userID current canvas user
GET /api/canvas/v1/payment/recharges?user_id=999 -> service query UserID is current canvas user
POST /api/canvas/v1/payment/recharges -> create input UserID is current canvas user
POST /api/canvas/v1/payment/recharges/:id/pay -> current user + route id
identity.Platform=admin on canvas route -> 401
```

Wallet canvas tests must prove:

```text
GET /api/canvas/v1/wallet/summary -> current canvas user
GET /api/canvas/v1/wallet/transactions?user_id=999 -> service query UserID is current canvas user
identity.Platform=admin on canvas route -> 401
```

- [ ] **Step 6: Verify payment/wallet transports**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/payment/transport/admin ./internal/module/payment/transport/canvas ./internal/module/payment/wallet/transport/admin ./internal/module/payment/wallet/transport/canvas -count=1
```

Expected: PASS.

---

### Task 5: Rewire server registration into explicit platform transports

**Files:**
- Modify: `admin_back_go/internal/server/routes_auth.go`
- Modify: `admin_back_go/internal/server/routes_admin_user.go`
- Modify: `admin_back_go/internal/server/routes_admin_commerce_rbac.go`
- Modify: `admin_back_go/internal/server/router_test.go`

- [ ] **Step 1: Replace auth server registration**

`routes_auth.go` must become:

```go
package server

import (
	authadmin "admin_back_go/internal/module/auth/transport/admin"
	authapp "admin_back_go/internal/module/auth/transport/app"
	authcanvas "admin_back_go/internal/module/auth/transport/canvas"

	"github.com/gin-gonic/gin"
)

func registerAuthRoutes(router *gin.Engine, deps Dependencies) {
	authadmin.Register(router, deps.AuthService, deps.CaptchaService, deps.SessionAdminService, deps.LoginLogService)
	authapp.Register(router, authapp.Dependencies{AuthService: deps.AuthService, CaptchaService: deps.CaptchaService, UserService: deps.UserService})
	authcanvas.Register(router, authcanvas.Dependencies{AuthService: deps.AuthService, CaptchaService: deps.CaptchaService, UserService: deps.UserService})
}
```

- [ ] **Step 2: Replace profile server registration**

`routes_admin_user.go` must become:

```go
package server

import (
	profileadmin "admin_back_go/internal/module/profile/transport/admin"
	profileapp "admin_back_go/internal/module/profile/transport/app"
	profilecanvas "admin_back_go/internal/module/profile/transport/canvas"
	useradmin "admin_back_go/internal/module/user/transport/admin"

	"github.com/gin-gonic/gin"
)

func registerAdminUserRoutes(router *gin.Engine, deps Dependencies) {
	useradmin.RegisterRoutes(router, deps.UserService)
	profileadmin.RegisterRoutes(router, deps.UserService, deps.UserQuickEntryService)
	profileapp.RegisterRoutes(router, deps.UserService)
	profilecanvas.RegisterRoutes(router, profilecanvas.Dependencies{Service: deps.UserService})
}
```

- [ ] **Step 3: Replace commerce/RBAC server registration**

`routes_admin_commerce_rbac.go` must import and register `paymentcanvas` and `walletcanvas`:

```go
paymentcanvas "admin_back_go/internal/module/payment/transport/canvas"
walletcanvas "admin_back_go/internal/module/payment/wallet/transport/canvas"
```

The bottom of `registerAdminCommerceRBACRoutes` must be:

```go
authplatformadmin.RegisterRoutes(router, deps.AuthPlatformService)
walletcanvas.RegisterRoutes(router, deps.WalletService)
paymentcanvas.RegisterRechargeRoutes(router, deps.PaymentService)
```

- [ ] **Step 4: Keep router behavior tests and add route inventory assertion**

Add a server test proving these routes exist:

```text
GET  /api/canvas/v1/auth/login-config
GET  /api/canvas/v1/auth/captcha
POST /api/canvas/v1/auth/send-code
POST /api/canvas/v1/auth/login
POST /api/canvas/v1/auth/logout
GET  /api/canvas/v1/users/me
GET  /api/canvas/v1/wallet/summary
GET  /api/canvas/v1/wallet/transactions
GET  /api/canvas/v1/payment/recharges/page-init
GET  /api/canvas/v1/payment/recharges
POST /api/canvas/v1/payment/recharges
POST /api/canvas/v1/payment/recharges/:id/pay
```

The same test must prove these canvas routes do not exist:

```text
GET   /api/canvas/v1/profile
PUT   /api/canvas/v1/profile
GET   /api/canvas/v1/payment/ledger
GET   /api/canvas/v1/payment/wallets
POST  /api/canvas/v1/wallet/consumptions
POST  /api/canvas/v1/payment/recharges/:id/sync
PATCH /api/canvas/v1/payment/recharges/:id/close
```

- [ ] **Step 5: Verify server routes**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/server -run "Canvas|AppProfile|Wallet|Recharge|Auth" -count=1
```

Expected: PASS.

---

### Task 6: Source inventory for hidden route bends

**Files:**
- Read-only scan: `admin_back_go/internal/server/**/*.go`
- Read-only scan: `admin_back_go/internal/module/**/*.go`

- [ ] **Step 1: Run architecture tests**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture -run "PlatformRouteLine|AuthTransportBoundaryShape|CanvasFrontNextIntegration|UserProfileTransportShape|CommerceRBACAdminTransportShells" -count=1
```

Expected: PASS.

- [ ] **Step 2: Search for banned dynamic route APIs**

Run:

```powershell
cd E:\admin_go\admin_back_go
rg -n "RegisterRoutesWithOptions|RouteOptions|RegisterCurrentUserRoutes|RegisterRechargeRoutes\(router,\s*\"/api|Prefix:\s*\"/api/(app|canvas)/v1|UsersPrefix|ProfilePrefix" internal/server internal/module/auth internal/module/profile internal/module/payment -g "*.go" -g "!*_test.go"
```

Expected: no matches.

- [ ] **Step 3: Search for canvas URL literals in wrong transports**

Run:

```powershell
cd E:\admin_go\admin_back_go
$files = Get-ChildItem -Recurse -Path .\internal\module -Filter *.go |
  Where-Object { $_.FullName -notmatch '_test\.go$' -and ($_.FullName -match '\\transport\\app\\' -or $_.FullName -match '\\transport\\admin\\') }
$hits = $files | Select-String -Pattern '"/api/canvas/v1'
if ($hits) { $hits | ForEach-Object { "{0}:{1}:{2}" -f $_.Path,$_.LineNumber,$_.Line.Trim() }; exit 1 }
```

Expected: exit code 0 and no output.

- [ ] **Step 4: Search for app/admin URL literals in canvas transports**

Run:

```powershell
cd E:\admin_go\admin_back_go
$files = Get-ChildItem -Recurse -Path .\internal\module -Filter *.go |
  Where-Object { $_.FullName -notmatch '_test\.go$' -and $_.FullName -match '\\transport\\canvas\\' }
$hits = $files | Select-String -Pattern '"/api/(app|admin)/v1'
if ($hits) { $hits | ForEach-Object { "{0}:{1}:{2}" -f $_.Path,$_.LineNumber,$_.Line.Trim() }; exit 1 }
```

Expected: exit code 0 and no output.

---

### Task 7: Backend regression and smoke

**Files:**
- No source changes unless a test exposes a real regression.

- [ ] **Step 1: Run targeted backend tests**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/auth ./internal/module/auth/transport/... ./internal/module/profile/transport/... ./internal/module/payment/transport/... ./internal/module/payment/wallet/transport/... ./internal/middleware ./internal/server ./internal/architecture -count=1
```

Expected: PASS.

- [ ] **Step 2: Run full backend tests with constrained parallelism**

Run:

```powershell
cd E:\admin_go\admin_back_go
$env:GOMAXPROCS = '2'
go test -p=1 ./...
```

Expected: PASS.

- [ ] **Step 3: Run go vet**

Run:

```powershell
cd E:\admin_go\admin_back_go
go vet -p=1 ./...
```

Expected: PASS.

- [ ] **Step 4: Run admin smoke if runtime env is available**

Run:

```powershell
cd E:\admin_go\admin_back_go
powershell -ExecutionPolicy Bypass -File .\scripts\basic-admin-smoke.ps1 -Account 15671628271 -Password 123456
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account 15671628271 -Password 123456
```

Expected: PASS JSON summaries. If env is unavailable, report this as a verification gap and do not claim smoke coverage.

---

### Task 8: Sync docs to the new route-line truth

**Files:**
- Modify: `docs/status/current-status.md`
- Modify: `docs/status/module-matrix.md`
- Modify: `docs/contracts/admin-api-v1.md`
- Modify: `docs/testing/smoke-matrix.md`

- [ ] **Step 1: Update current status**

After tests pass, add this verified fact:

```md
- Canvas auth/RBAC transport boundary hardening: Canvas auth now owns `/api/canvas/v1/auth/*` through `internal/module/auth/transport/canvas`, Canvas current-user owns `/api/canvas/v1/users/me` through `internal/module/profile/transport/canvas`, and Canvas wallet/recharge current-user routes own `/api/canvas/v1/wallet/*` plus `/api/canvas/v1/payment/recharges*` through canvas transports. App/admin transports no longer mount canvas URL prefixes.
```

If smoke did not run, add a verification gap saying code tests passed but runtime smoke was not run.

- [ ] **Step 2: Update module matrix**

Record ownership:

```text
auth: admin/app/canvas each has dedicated transport/{platform}
profile: app owns /api/app/v1/users/me and /api/app/v1/profile; canvas owns only /api/canvas/v1/users/me
payment: admin owns management; canvas owns recharge current-user routes
payment/wallet: admin owns management/admin wallet; canvas owns wallet summary/transactions
```

- [ ] **Step 3: Update contract route ownership notes**

Add:

```text
/api/canvas/v1/auth/*                  -> internal/module/auth/transport/canvas
/api/canvas/v1/users/me                -> internal/module/profile/transport/canvas
/api/canvas/v1/wallet/*                -> internal/module/payment/wallet/transport/canvas
/api/canvas/v1/payment/recharges*      -> internal/module/payment/transport/canvas
/api/canvas/v1/prompts|assets|settings -> internal/module/canvas/transport/canvas
```

- [ ] **Step 4: Update smoke matrix**

Add backend architecture row:

```md
| Platform route-line guard | `go test ./internal/architecture -run "PlatformRouteLine" -count=1` | Ensures canvas/app/admin URL prefixes are registered by matching `transport/{platform}` packages, not by dynamic prefix injection through another platform transport. |
```

---

### Task 9: Final verification and governance gates

**Files:**
- Entire working tree.

- [ ] **Step 1: Run gofmt**

Run:

```powershell
cd E:\admin_go\admin_back_go
gofmt -w `
  .\internal\architecture\platform_route_line_test.go `
  .\internal\architecture\canvas_front_next_integration_test.go `
  .\internal\architecture\multiplatform_boundary_test.go `
  .\internal\server\routes_auth.go `
  .\internal\server\routes_admin_user.go `
  .\internal\server\routes_admin_commerce_rbac.go `
  .\internal\server\router_test.go `
  .\internal\module\auth\transport\app `
  .\internal\module\auth\transport\canvas `
  .\internal\module\profile\transport\app `
  .\internal\module\profile\transport\canvas `
  .\internal\module\payment\transport\admin `
  .\internal\module\payment\transport\canvas `
  .\internal\module\payment\wallet\transport\admin `
  .\internal\module\payment\wallet\transport\canvas
```

Expected: exit code 0.

- [ ] **Step 2: Run backend gates**

Run:

```powershell
cd E:\admin_go\admin_back_go
$env:GOMAXPROCS = '2'
go test -p=1 ./...
go vet -p=1 ./...
```

Expected: PASS.

- [ ] **Step 3: Run root governance gates**

Run:

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected: PASS.

- [ ] **Step 4: Report evidence**

Final report must include:

```text
Outcome: route lines are straight for auth/profile/payment/wallet canvas surfaces.
Changed files: grouped by architecture tests, transports, server registration, docs.
Verification: exact commands and PASS/FAIL output summary.
Known risks: smoke skipped or failed env, if applicable.
Next step: frontend/runtime smoke only after backend route-line tests pass.
```

Do not say “完成” if any required code test or governance gate was not run.

---

## Acceptance Criteria

```text
/api/canvas/v1/auth/* no longer passes through auth/transport/app.
/api/canvas/v1/users/me no longer passes through profile/transport/app.
/api/canvas/v1/wallet/* no longer passes through payment/wallet/transport/admin.
/api/canvas/v1/payment/recharges* no longer passes through payment/transport/admin.
server/routes_*.go visibly imports and calls the matching canvas transport packages.
app/admin transports contain no literal "/api/canvas/v1" production URL strings.
canvas transports contain no literal "/api/app/v1" or "/api/admin/v1" production URL strings.
external URLs, request payloads, response payloads, token parsing, and 401/403 behavior remain compatible.
architecture guard prevents the same class of mistake from returning.
```

## Execution Notes

- This is internal boundary refactor, not contract rewrite.
- Do not introduce `transport/client` pseudo-platform.
- Do not create `canvasauth`, `canvasprofile`, `canvaswallet`, or `canvaspayment` business modules.
- Do not move shared login/RBAC/payment logic into transport packages.
- Thin duplication in transport packages is intentional. The bad abstraction is the dynamic prefix trick, not five small handler methods.
