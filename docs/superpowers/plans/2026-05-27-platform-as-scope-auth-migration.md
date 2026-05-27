# 平台作为作用域的 Auth 迁移实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 消除 `internal/module/appauth` 这种平台命名认证模块，把 app 认证归回 `auth`，把 app 用户/profile/upload-token 归回各自业务模块。

**Architecture:** 平台只作为 route prefix、platform scope、policy lookup 和 response presenter 存在。认证业务逻辑继续只有 `internal/module/auth.Service` 一份；app 专属响应由 `auth` 内部 platform handler/presenter 输出。非认证 app endpoints 不进入 `auth`，分别归属 `user` 和 `uploadtoken`。

**Tech Stack:** Go 1.26、Gin、项目自有 `apperror` / `response` / `middleware.AuthToken`、`auth_platforms` 登录策略、Go test。

---

## 设计输入

Spec：`docs/superpowers/specs/2026-05-27-platform-as-scope-not-module-design.md`

硬规则：

```text
平台不是 module。新增平台默认不得新增平台命名业务模块。
```

## 文件结构

新增：

- `admin_back_go/internal/module/auth/platform_route.go`：注册 `/api/app/v1/auth` 这类平台认证路由。
- `admin_back_go/internal/module/auth/platform_handler.go`：平台认证 HTTP adapter，强制 platform scope，调用现有 `auth.Service`。
- `admin_back_go/internal/module/auth/platform_dto.go`：app/platform login response presenter 类型。
- `admin_back_go/internal/module/auth/platform_handler_test.go`：auth-owned app auth route 测试。
- `admin_back_go/internal/module/user/app_dto.go`：app user/profile response presenter。
- `admin_back_go/internal/module/user/app_handler.go`：app current-user/profile HTTP adapter。
- `admin_back_go/internal/module/user/app_route_test.go`：user-owned app routes 测试。
- `admin_back_go/internal/module/uploadtoken/app_handler.go`：app upload-token HTTP adapter。
- `admin_back_go/internal/module/uploadtoken/app_route_test.go`：uploadtoken-owned app route 测试。
- `admin_back_go/internal/architecture/platform_scope_test.go`：禁止 `internal/module/appauth` 回潮的架构守卫。

修改：

- `admin_back_go/internal/server/router.go`：移除 `appauth` import；注册 auth/user/uploadtoken 所属 app routes。
- `admin_back_go/internal/module/user/route.go`：注册 `/api/app/v1/users/me`、`/api/app/v1/profile`。
- `admin_back_go/internal/module/uploadtoken/route.go`：注册 `/api/app/v1/upload-tokens`。
- `admin_back_go/internal/server/router_test.go`：保留 app API 行为断言，更新为新模块归属。
- `docs/status/current-status.md`
- `docs/contracts/admin-api-v1.md`
- `admin_back_go/docs/architecture.md`
- `docs/architecture/04-go-backend-framework.md`

删除：

- `admin_back_go/internal/module/appauth/dto.go`
- `admin_back_go/internal/module/appauth/handler.go`
- `admin_back_go/internal/module/appauth/route.go`

---

## Task 1: 在 `auth` 内新增平台认证路由 RED 测试

**Files:**

- Create: `admin_back_go/internal/module/auth/platform_handler_test.go`

- [ ] **Step 1: 写失败测试**

创建 `admin_back_go/internal/module/auth/platform_handler_test.go`：

```go
package auth

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"admin_back_go/internal/apperror"
	"admin_back_go/internal/enum"
	"admin_back_go/internal/module/captcha"
	"admin_back_go/internal/module/permission"
	"admin_back_go/internal/module/session"
	"admin_back_go/internal/module/user"

	"github.com/gin-gonic/gin"
)

type fakePlatformSessionService struct {
	loginInput     LoginInput
	configPlatform string
	sendCodeInput  SendCodeInput
	logoutToken    string
}

func (f *fakePlatformSessionService) Login(ctx context.Context, input LoginInput) (*LoginResponse, *apperror.Error) {
	f.loginInput = input
	return &LoginResponse{AccessToken: "app-token", UserID: 7}, nil
}
func (f *fakePlatformSessionService) SendCode(ctx context.Context, input SendCodeInput) (string, *apperror.Error) {
	f.sendCodeInput = input
	return "", nil
}
func (f *fakePlatformSessionService) ForgetPassword(ctx context.Context, input ForgetPasswordInput) *apperror.Error {
	return nil
}
func (f *fakePlatformSessionService) LoginConfig(ctx context.Context, platform string) (*LoginConfigResponse, *apperror.Error) {
	f.configPlatform = platform
	return &LoginConfigResponse{CaptchaEnabled: true, CaptchaType: captcha.TypeSlide}, nil
}
func (f *fakePlatformSessionService) Refresh(ctx context.Context, input session.RefreshInput) (*session.TokenResult, *apperror.Error) {
	return &session.TokenResult{}, nil
}
func (f *fakePlatformSessionService) Logout(ctx context.Context, accessToken string) *apperror.Error {
	f.logoutToken = accessToken
	return nil
}

type fakePlatformCaptchaService struct{}

func (fakePlatformCaptchaService) Generate(ctx context.Context) (*captcha.ChallengeResponse, *apperror.Error) {
	return &captcha.ChallengeResponse{CaptchaID: "captcha-id", CaptchaType: captcha.TypeSlide, MasterImage: "master", TileImage: "tile", ExpiresIn: 120}, nil
}

type fakePlatformUserService struct {
	input user.InitInput
}

func (f *fakePlatformUserService) Init(ctx context.Context, input user.InitInput) (*user.InitResponse, *apperror.Error) {
	f.input = input
	return &user.InitResponse{
		UserID: input.UserID, Username: "App User", Avatar: "avatar.png", RoleName: "app",
		Permissions: []permission.MenuItem{}, Router: []permission.RouteItem{}, ButtonCodes: []string{},
	}, nil
}

func TestPlatformAuthRoutesForceConfiguredPlatform(t *testing.T) {
	authService := &fakePlatformSessionService{}
	userService := &fakePlatformUserService{}
	router := newPlatformAuthTestRouter(authService, userService)

	configRecorder := httptest.NewRecorder()
	configRequest := httptest.NewRequest(http.MethodGet, "/api/app/v1/auth/login-config", nil)
	configRequest.Header.Set("platform", enum.PlatformAdmin)
	router.ServeHTTP(configRecorder, configRequest)
	if configRecorder.Code != http.StatusOK {
		t.Fatalf("expected login-config status 200, got %d body=%s", configRecorder.Code, configRecorder.Body.String())
	}
	if authService.configPlatform != enum.PlatformApp {
		t.Fatalf("expected app platform, got %q", authService.configPlatform)
	}

	loginRecorder := httptest.NewRecorder()
	loginRequest := httptest.NewRequest(http.MethodPost, "/api/app/v1/auth/login", strings.NewReader(`{"login_type":"password","login_account":"15671628271","password":"123456","captcha_id":"captcha-id","captcha_answer":{"x":120,"y":80}}`))
	loginRequest.Header.Set("Content-Type", "application/json")
	loginRequest.Header.Set("platform", enum.PlatformAdmin)
	loginRequest.Header.Set("device-id", "ios-1")
	loginRequest.Header.Set("User-Agent", "agent")
	router.ServeHTTP(loginRecorder, loginRequest)
	if loginRecorder.Code != http.StatusOK {
		t.Fatalf("expected login status 200, got %d body=%s", loginRecorder.Code, loginRecorder.Body.String())
	}
	if authService.loginInput.Platform != enum.PlatformApp || authService.loginInput.DeviceID != "ios-1" {
		t.Fatalf("unexpected login input: %#v", authService.loginInput)
	}
	if userService.input.UserID != 7 || userService.input.Platform != enum.PlatformApp {
		t.Fatalf("unexpected init input: %#v", userService.input)
	}
	data := decodePlatformAuthData(t, loginRecorder)
	if data["token"] != "app-token" {
		t.Fatalf("expected app token response, got %#v", data)
	}
	if _, ok := data["access_token"]; ok {
		t.Fatalf("app login response must not expose admin token field: %#v", data)
	}
	userData := data["user"].(map[string]any)
	if userData["nickname"] != "App User" || userData["avatar"] != "avatar.png" {
		t.Fatalf("unexpected app user payload: %#v", userData)
	}
}

func TestPlatformAuthRoutesExposeCaptchaSendCodeAndLogout(t *testing.T) {
	authService := &fakePlatformSessionService{}
	router := newPlatformAuthTestRouter(authService, &fakePlatformUserService{})

	captchaRecorder := httptest.NewRecorder()
	router.ServeHTTP(captchaRecorder, httptest.NewRequest(http.MethodGet, "/api/app/v1/auth/captcha", nil))
	if captchaRecorder.Code != http.StatusOK {
		t.Fatalf("expected captcha status 200, got %d body=%s", captchaRecorder.Code, captchaRecorder.Body.String())
	}

	sendCodeRecorder := httptest.NewRecorder()
	sendCodeRequest := httptest.NewRequest(http.MethodPost, "/api/app/v1/auth/send-code", strings.NewReader(`{"account":"15671628271","scene":"login"}`))
	sendCodeRequest.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(sendCodeRecorder, sendCodeRequest)
	if sendCodeRecorder.Code != http.StatusOK {
		t.Fatalf("expected send-code status 200, got %d body=%s", sendCodeRecorder.Code, sendCodeRecorder.Body.String())
	}
	if authService.sendCodeInput.Account != "15671628271" || authService.sendCodeInput.Scene != VerifyCodeSceneLogin {
		t.Fatalf("unexpected send-code input: %#v", authService.sendCodeInput)
	}

	logoutRecorder := httptest.NewRecorder()
	logoutRequest := httptest.NewRequest(http.MethodPost, "/api/app/v1/auth/logout", nil)
	logoutRequest.Header.Set("Authorization", "Bearer app-token")
	router.ServeHTTP(logoutRecorder, logoutRequest)
	if logoutRecorder.Code != http.StatusOK {
		t.Fatalf("expected logout status 200, got %d body=%s", logoutRecorder.Code, logoutRecorder.Body.String())
	}
	if authService.logoutToken != "app-token" {
		t.Fatalf("expected logout token app-token, got %q", authService.logoutToken)
	}
}

func newPlatformAuthTestRouter(authService SessionService, userService PlatformUserInitService) *gin.Engine {
	gin.SetMode(gin.ReleaseMode)
	router := gin.New()
	RegisterPlatformRoutes(router, PlatformRouteOptions{
		Prefix:         "/api/app/v1/auth",
		Platform:       enum.PlatformApp,
		AuthService:    authService,
		CaptchaService: fakePlatformCaptchaService{},
		UserService:    userService,
	})
	return router
}

func decodePlatformAuthData(t *testing.T, recorder *httptest.ResponseRecorder) map[string]any {
	t.Helper()
	var body map[string]any
	if err := json.Unmarshal(recorder.Body.Bytes(), &body); err != nil {
		t.Fatalf("invalid json response: %v", err)
	}
	return body["data"].(map[string]any)
}
```

- [ ] **Step 2: 运行测试确认 RED**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/auth -run PlatformAuthRoutes -count=1
```

Expected:

```text
FAIL
undefined: PlatformUserInitService
undefined: RegisterPlatformRoutes
undefined: PlatformRouteOptions
```

- [ ] **Step 3: 提交 RED 测试**

```powershell
git add internal/module/auth/platform_handler_test.go
git commit -m "test: cover auth-owned platform auth routes"
```

---

## Task 2: 在 `auth` 实现平台认证 adapter

**Files:**

- Create: `admin_back_go/internal/module/auth/platform_dto.go`
- Create: `admin_back_go/internal/module/auth/platform_handler.go`
- Create: `admin_back_go/internal/module/auth/platform_route.go`

- [ ] **Step 1: 新增 DTO / presenter**

创建 `admin_back_go/internal/module/auth/platform_dto.go`：

```go
package auth

import "admin_back_go/internal/module/user"

type platformLoginRequest struct {
	LoginType     string                `json:"login_type" binding:"required,auth_platform_login_type"`
	LoginAccount  string                `json:"login_account" binding:"required,max=100"`
	Password      string                `json:"password" binding:"omitempty,max=128"`
	Code          string                `json:"code" binding:"omitempty,max=20"`
	CaptchaID     string                `json:"captcha_id" binding:"omitempty,max=128"`
	CaptchaAnswer *captchaAnswerRequest `json:"captcha_answer"`
}

type platformLoginResponse struct {
	Token string       `json:"token"`
	User  platformUser `json:"user"`
}

type platformUser struct {
	ID       int64  `json:"id"`
	Nickname string `json:"nickname"`
	Avatar   string `json:"avatar"`
}

func platformUserFromInit(currentUser *user.InitResponse) platformUser {
	if currentUser == nil {
		return platformUser{}
	}
	return platformUser{ID: currentUser.UserID, Nickname: currentUser.Username, Avatar: currentUser.Avatar}
}
```

- [ ] **Step 2: 新增 platform handler**

创建 `admin_back_go/internal/module/auth/platform_handler.go`：

```go
package auth

import (
	"context"
	"strings"

	"admin_back_go/internal/apperror"
	"admin_back_go/internal/middleware"
	"admin_back_go/internal/module/captcha"
	"admin_back_go/internal/module/user"
	"admin_back_go/internal/response"

	"github.com/gin-gonic/gin"
)

type PlatformCaptchaService interface {
	Generate(ctx context.Context) (*captcha.ChallengeResponse, *apperror.Error)
}

type PlatformUserInitService interface {
	Init(ctx context.Context, input user.InitInput) (*user.InitResponse, *apperror.Error)
}

type PlatformHandler struct {
	platform       string
	authService    SessionService
	captchaService PlatformCaptchaService
	userService    PlatformUserInitService
}

func NewPlatformHandler(opts PlatformRouteOptions) *PlatformHandler {
	return &PlatformHandler{
		platform:       strings.TrimSpace(opts.Platform),
		authService:    opts.AuthService,
		captchaService: opts.CaptchaService,
		userService:    opts.UserService,
	}
}

func (h *PlatformHandler) LoginConfig(c *gin.Context) {
	if h.authService == nil {
		response.Error(c, apperror.UnauthorizedKey("auth.platform.service_missing", nil, "登录服务未配置"))
		return
	}
	result, appErr := h.authService.LoginConfig(c.Request.Context(), h.platform)
	if appErr != nil {
		response.Error(c, appErr)
		return
	}
	response.OK(c, result)
}

func (h *PlatformHandler) Captcha(c *gin.Context) {
	if h.captchaService == nil {
		response.Error(c, apperror.InternalKey("captcha.service_missing", nil, "验证码服务未配置"))
		return
	}
	result, appErr := h.captchaService.Generate(c.Request.Context())
	if appErr != nil {
		response.Error(c, appErr)
		return
	}
	response.OK(c, result)
}

func (h *PlatformHandler) SendCode(c *gin.Context) {
	if h.authService == nil {
		response.Error(c, apperror.UnauthorizedKey("auth.platform.service_missing", nil, "登录服务未配置"))
		return
	}
	var req SendCodeRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, apperror.BadRequestKey("auth.send_code.request.invalid", nil, "验证码参数错误"))
		return
	}
	if _, appErr := h.authService.SendCode(c.Request.Context(), SendCodeInput{Account: req.Account, Scene: req.Scene}); appErr != nil {
		response.Error(c, appErr)
		return
	}
	response.OKWithMessageKey(c, gin.H{}, "auth.verify_code.sent", nil, "验证码发送成功")
}

func (h *PlatformHandler) Login(c *gin.Context) {
	if h.authService == nil {
		response.Error(c, apperror.UnauthorizedKey("auth.platform.service_missing", nil, "登录服务未配置"))
		return
	}
	if h.userService == nil {
		response.Error(c, apperror.InternalKey("auth.platform.user_service_missing", nil, "用户服务未配置"))
		return
	}
	var req platformLoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, apperror.BadRequestKey("auth.login.request.invalid", nil, "登录参数错误"))
		return
	}
	result, appErr := h.authService.Login(c.Request.Context(), LoginInput{
		LoginAccount:  req.LoginAccount,
		LoginType:     req.LoginType,
		Password:      req.Password,
		Code:          req.Code,
		CaptchaID:     req.CaptchaID,
		CaptchaAnswer: captchaAnswerFromRequest(req.CaptchaAnswer),
		Platform:      h.platform,
		DeviceID:      c.GetHeader("device-id"),
		ClientIP:      c.ClientIP(),
		UserAgent:     c.GetHeader("User-Agent"),
	})
	if appErr != nil {
		response.Error(c, appErr)
		return
	}
	if result == nil || strings.TrimSpace(result.AccessToken) == "" || result.UserID <= 0 {
		response.Error(c, apperror.InternalKey("auth.platform_login.result_invalid", nil, "登录结果无效"))
		return
	}
	currentUser, appErr := h.userService.Init(c.Request.Context(), user.InitInput{UserID: result.UserID, Platform: h.platform})
	if appErr != nil {
		response.Error(c, appErr)
		return
	}
	response.OK(c, platformLoginResponse{Token: result.AccessToken, User: platformUserFromInit(currentUser)})
}

func (h *PlatformHandler) Logout(c *gin.Context) {
	if h.authService == nil {
		response.Error(c, apperror.UnauthorizedKey("auth.platform.service_missing", nil, "登录服务未配置"))
		return
	}
	accessToken, tokenErr := middleware.ParseBearerToken(c.GetHeader("Authorization"))
	if tokenErr != nil {
		response.Error(c, tokenErr)
		return
	}
	if appErr := h.authService.Logout(c.Request.Context(), accessToken); appErr != nil {
		response.Error(c, appErr)
		return
	}
	response.OKNull(c)
}
```

- [ ] **Step 3: 新增 platform route 注册**

创建 `admin_back_go/internal/module/auth/platform_route.go`：

```go
package auth

import (
	"strings"

	"admin_back_go/internal/validate"

	"github.com/gin-gonic/gin"
)

type PlatformRouteOptions struct {
	Prefix         string
	Platform       string
	AuthService    SessionService
	CaptchaService PlatformCaptchaService
	UserService    PlatformUserInitService
}

func RegisterPlatformRoutes(router *gin.Engine, opts PlatformRouteOptions) {
	validate.MustRegister()
	prefix := strings.TrimRight(strings.TrimSpace(opts.Prefix), "/")
	if prefix == "" {
		panic("auth platform route prefix is required")
	}
	if strings.TrimSpace(opts.Platform) == "" {
		panic("auth platform route platform is required")
	}
	handler := NewPlatformHandler(opts)
	group := router.Group(prefix)
	group.GET("/login-config", handler.LoginConfig)
	group.GET("/captcha", handler.Captcha)
	group.POST("/send-code", handler.SendCode)
	group.POST("/login", handler.Login)
	group.POST("/logout", handler.Logout)
}
```

- [ ] **Step 4: 运行 auth 测试确认 GREEN**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/auth -run PlatformAuthRoutes -count=1
go test ./internal/module/auth -count=1
```

Expected:

```text
ok  	admin_back_go/internal/module/auth
```

- [ ] **Step 5: 提交 auth platform adapter**

```powershell
git add internal/module/auth/platform_dto.go internal/module/auth/platform_handler.go internal/module/auth/platform_route.go
git commit -m "feat: move platform auth adapter into auth module"
```

---

## Task 3: 让 server 使用 `auth` 注册 app auth routes

**Files:**

- Modify: `admin_back_go/internal/server/router.go`
- Modify: `admin_back_go/internal/module/appauth/route.go`
- Modify: `admin_back_go/internal/module/appauth/handler.go`

- [ ] **Step 1: 写失败断言，证明 `appauth` 不再拥有 auth route**

在 `admin_back_go/internal/server/router_test.go` 新增测试：

```go
func TestAppAuthPackageDoesNotRegisterAuthRoutes(t *testing.T) {
	content, err := os.ReadFile(filepath.Join("..", "module", "appauth", "route.go"))
	if err != nil {
		t.Fatalf("read appauth route.go: %v", err)
	}
	text := string(content)
	for _, forbidden := range []string{"/api/app/v1/auth", "LoginConfig", "SendCode", "Login)", "Logout"} {
		if strings.Contains(text, forbidden) {
			t.Fatalf("appauth must not own auth route marker %q", forbidden)
		}
	}
}
```

补充 imports：

```go
import (
	"os"
	"path/filepath"
)
```

- [ ] **Step 2: 运行测试确认 RED**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/server -run TestAppAuthPackageDoesNotRegisterAuthRoutes -count=1
```

Expected:

```text
FAIL
appauth must not own auth route marker "/api/app/v1/auth"
```

- [ ] **Step 3: 修改 server route 注册**

在 `admin_back_go/internal/server/router.go` 中把：

```go
auth.RegisterRoutes(router, deps.AuthService)
appauth.RegisterRoutes(router, deps.AuthService, deps.CaptchaService, deps.UserService, deps.UploadTokenService)
```

改成：

```go
auth.RegisterRoutes(router, deps.AuthService)
auth.RegisterPlatformRoutes(router, auth.PlatformRouteOptions{
	Prefix:         "/api/app/v1/auth",
	Platform:       enum.PlatformApp,
	AuthService:    deps.AuthService,
	CaptchaService: deps.CaptchaService,
	UserService:    deps.UserService,
})
appauth.RegisterRoutes(router, deps.UserService, deps.UploadTokenService)
```

- [ ] **Step 4: 收窄 `appauth.RegisterRoutes`**

把 `admin_back_go/internal/module/appauth/route.go` 改成只注册非认证 app endpoints：

```go
package appauth

import (
	"admin_back_go/internal/validate"

	"github.com/gin-gonic/gin"
)

func RegisterRoutes(router *gin.Engine, userService UserService, uploadTokenService UploadTokenService) {
	validate.MustRegister()
	handler := NewHandler(userService, uploadTokenService)

	users := router.Group("/api/app/v1/users")
	users.GET("/me", handler.Me)

	profile := router.Group("/api/app/v1/profile")
	profile.GET("", handler.Profile)
	profile.PUT("", handler.UpdateProfile)

	uploadTokens := router.Group("/api/app/v1/upload-tokens")
	uploadTokens.POST("", handler.CreateUploadToken)
}
```

- [ ] **Step 5: 收窄 `appauth.Handler`**

在 `admin_back_go/internal/module/appauth/handler.go` 删除：

```text
AuthService interface
CaptchaService interface
Handler.authService
Handler.captchaService
LoginConfig
Captcha
SendCode
Login
Logout
```

把 constructor 改成：

```go
func NewHandler(userService UserService, uploadTokenService UploadTokenService) *Handler {
	return &Handler{userService: userService, uploadTokenService: uploadTokenService}
}
```

- [ ] **Step 6: 运行测试确认 GREEN**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/server -run "TestRouterInstallsAppAuthRoutes|TestAppAuthPackageDoesNotRegisterAuthRoutes" -count=1
```

Expected:

```text
ok  	admin_back_go/internal/server
```

- [ ] **Step 7: 提交**

```powershell
git add internal/server/router.go internal/server/router_test.go internal/module/appauth/route.go internal/module/appauth/handler.go
git commit -m "refactor: register app auth routes from auth module"
```

---

## Task 4: 把 app user/profile routes 迁到 `user` module

**Files:**

- Create: `admin_back_go/internal/module/user/app_dto.go`
- Create: `admin_back_go/internal/module/user/app_handler.go`
- Create: `admin_back_go/internal/module/user/app_route_test.go`
- Modify: `admin_back_go/internal/module/user/route.go`
- Modify: `admin_back_go/internal/module/appauth/route.go`
- Modify: `admin_back_go/internal/server/router.go`

- [ ] **Step 1: 写失败测试**

创建 `admin_back_go/internal/module/user/app_route_test.go`：

```go
package user

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"reflect"
	"strings"
	"testing"

	"admin_back_go/internal/apperror"
	"admin_back_go/internal/enum"
	"admin_back_go/internal/middleware"
	"admin_back_go/internal/module/permission"

	"github.com/gin-gonic/gin"
)

type fakeAppUserService struct {
	initInput     InitInput
	profileUserID int64
	profileViewer int64
	updateInput   UpdateProfileInput
}

func (f *fakeAppUserService) Init(ctx context.Context, input InitInput) (*InitResponse, *apperror.Error) {
	f.initInput = input
	return &InitResponse{
		UserID:      input.UserID,
		Username:    "App User",
		Avatar:      "avatar.png",
		RoleName:    "管理员",
		Permissions: []permission.MenuItem{{Index: "1", Label: "系统"}},
		Router:      []permission.RouteItem{{Name: "admin", Path: "/system"}},
		ButtonCodes: []string{"user_add"},
	}, nil
}

func (f *fakeAppUserService) PageInit(ctx context.Context) (*PageInitResponse, *apperror.Error) {
	return &PageInitResponse{}, nil
}

func (f *fakeAppUserService) Profile(ctx context.Context, userID int64, currentUserID int64) (*ProfileResponse, *apperror.Error) {
	f.profileUserID = userID
	f.profileViewer = currentUserID
	return &ProfileResponse{
		Profile: ProfileDetail{
			UserID:        userID,
			Username:      "App User",
			Email:         "app@example.test",
			Phone:         "15671628271",
			Avatar:        "avatar.png",
			RoleID:        99,
			RoleName:      "管理员",
			AddressID:     3,
			DetailAddress: "湖北武汉",
			Sex:           1,
			Birthday:      "2026-05-24",
			Bio:           "old bio",
			HasPassword:   true,
		},
		Dict: ProfileDict{
			AuthAddressTree: []AddressTreeNode{{ID: 3, Label: "武汉", Value: 3}},
			SexArr:          []SexOption{{Label: "男", Value: 1}},
		},
	}, nil
}

func (f *fakeAppUserService) UpdateProfile(ctx context.Context, input UpdateProfileInput) *apperror.Error {
	f.updateInput = input
	return nil
}

func (f *fakeAppUserService) UpdatePassword(ctx context.Context, input UpdatePasswordInput) *apperror.Error { return nil }
func (f *fakeAppUserService) UpdateEmail(ctx context.Context, input UpdateEmailInput) *apperror.Error { return nil }
func (f *fakeAppUserService) UpdatePhone(ctx context.Context, input UpdatePhoneInput) *apperror.Error { return nil }
func (f *fakeAppUserService) List(ctx context.Context, query ListQuery) (*ListResponse, *apperror.Error) { return &ListResponse{}, nil }
func (f *fakeAppUserService) Export(ctx context.Context, input ExportInput) (*ExportResponse, *apperror.Error) { return &ExportResponse{}, nil }
func (f *fakeAppUserService) Update(ctx context.Context, id int64, input UpdateInput) *apperror.Error { return nil }
func (f *fakeAppUserService) ChangeStatus(ctx context.Context, id int64, status int) *apperror.Error { return nil }
func (f *fakeAppUserService) Delete(ctx context.Context, ids []int64) *apperror.Error { return nil }
func (f *fakeAppUserService) BatchUpdateProfile(ctx context.Context, input BatchProfileUpdate) *apperror.Error { return nil }

func TestUserModuleRegistersAppCurrentUserAndProfileRoutes(t *testing.T) {
	service := &fakeAppUserService{}
	router := newAppUserTestRouter(service, &middleware.AuthIdentity{UserID: 7, SessionID: 20, Platform: enum.PlatformApp})

	meData := requestAppUserData(t, router, http.MethodGet, "/api/app/v1/users/me", "")
	if service.initInput.UserID != 7 || service.initInput.Platform != enum.PlatformApp {
		t.Fatalf("unexpected init input: %#v", service.initInput)
	}
	if meData["id"] != float64(7) || meData["nickname"] != "App User" || meData["avatar"] != "avatar.png" {
		t.Fatalf("unexpected app users/me payload: %#v", meData)
	}
	for _, forbidden := range []string{"role_name", "permissions", "router", "buttonCodes", "quick_entry"} {
		if _, ok := meData[forbidden]; ok {
			t.Fatalf("app users/me must not include admin field %q: %#v", forbidden, meData)
		}
	}

	profileData := requestAppUserData(t, router, http.MethodGet, "/api/app/v1/profile", "")
	if service.profileUserID != 7 || service.profileViewer != 7 {
		t.Fatalf("unexpected profile input: user=%d viewer=%d", service.profileUserID, service.profileViewer)
	}
	profile := profileData["profile"].(map[string]any)
	if profile["nickname"] != "App User" || profile["email"] != "app@example.test" || profile["bio"] != "old bio" {
		t.Fatalf("unexpected app profile payload: %#v", profileData)
	}
	for _, forbidden := range []string{"role_id", "role_name", "is_self"} {
		if _, ok := profile[forbidden]; ok {
			t.Fatalf("app profile must not include admin field %q: %#v", forbidden, profile)
		}
	}
	dict := profileData["dict"].(map[string]any)
	if _, ok := dict["auth_address_tree"]; !ok {
		t.Fatalf("missing address tree in app profile dict: %#v", dict)
	}

	birthday := "2026-05-25"
	updateData := requestAppUserData(t, router, http.MethodPut, "/api/app/v1/profile", `{"nickname":"App User 2","avatar":"avatar2.png","sex":2,"birthday":"`+birthday+`","address_id":8,"detail_address":"湖北武汉光谷","bio":"new bio"}`)
	if service.updateInput.UserID != 7 || service.updateInput.Username != "App User 2" || service.updateInput.Avatar != "avatar2.png" || service.updateInput.Sex != 2 || service.updateInput.AddressID != 8 || service.updateInput.DetailAddress != "湖北武汉光谷" || service.updateInput.Bio != "new bio" || service.updateInput.Birthday == nil || *service.updateInput.Birthday != birthday {
		t.Fatalf("unexpected update input: %#v", service.updateInput)
	}
	userData := updateData["user"].(map[string]any)
	if userData["id"] != float64(7) || userData["nickname"] != "App User" {
		t.Fatalf("unexpected update response: %#v", updateData)
	}
}

func TestUserModuleAppRoutesRejectWrongPlatformScope(t *testing.T) {
	router := newAppUserTestRouter(&fakeAppUserService{}, &middleware.AuthIdentity{UserID: 7, SessionID: 20, Platform: enum.PlatformAdmin})

	recorder := httptest.NewRecorder()
	router.ServeHTTP(recorder, httptest.NewRequest(http.MethodGet, "/api/app/v1/users/me", nil))

	if recorder.Code != http.StatusUnauthorized {
		t.Fatalf("expected wrong app platform status 401, got %d body=%s", recorder.Code, recorder.Body.String())
	}
}

func newAppUserTestRouter(service HTTPService, identity *middleware.AuthIdentity) *gin.Engine {
	gin.SetMode(gin.ReleaseMode)
	router := gin.New()
	if identity != nil {
		router.Use(func(c *gin.Context) {
			c.Set(middleware.ContextAuthIdentity, identity)
			c.Next()
		})
	}
	RegisterRoutes(router, service)
	return router
}

func requestAppUserData(t *testing.T, router *gin.Engine, method string, path string, body string) map[string]any {
	t.Helper()
	var reader *strings.Reader
	if body == "" {
		reader = strings.NewReader("")
	} else {
		reader = strings.NewReader(body)
	}
	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(method, path, reader)
	if body != "" {
		request.Header.Set("Content-Type", "application/json")
	}
	router.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusOK {
		t.Fatalf("%s %s expected status 200, got %d body=%s", method, path, recorder.Code, recorder.Body.String())
	}
	var decoded map[string]any
	if err := json.Unmarshal(recorder.Body.Bytes(), &decoded); err != nil {
		t.Fatalf("invalid json response: %v", err)
	}
	data, ok := decoded["data"].(map[string]any)
	if !ok {
		t.Fatalf("expected object data, got %#v", decoded)
	}
	if reflect.ValueOf(data).IsNil() {
		t.Fatalf("expected non-nil data")
	}
	return data
}
```

- [ ] **Step 2: 运行测试确认 RED**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/user -run "TestUserModuleRegistersAppCurrentUserAndProfileRoutes|TestUserModuleAppRoutesRejectWrongPlatformScope" -count=1
```

Expected:

```text
FAIL
expected status 200, got 404
```

- [ ] **Step 3: 新增 app DTO / presenter**

创建 `admin_back_go/internal/module/user/app_dto.go`：

```go
package user

type appUser struct {
	ID       int64  `json:"id"`
	Nickname string `json:"nickname"`
	Avatar   string `json:"avatar"`
}

type appProfileResponse struct {
	Profile appProfile     `json:"profile"`
	Dict    appProfileDict `json:"dict"`
}

type appProfileUpdateResponse struct {
	User appUser `json:"user"`
}

type appProfileDict struct {
	AuthAddressTree []AddressTreeNode `json:"auth_address_tree"`
	SexArr          []SexOption       `json:"sexArr"`
}

type appProfile struct {
	UserID        int64  `json:"user_id"`
	Nickname      string `json:"nickname"`
	Email         string `json:"email"`
	Phone         string `json:"phone"`
	Avatar        string `json:"avatar"`
	AddressID     int64  `json:"address_id"`
	DetailAddress string `json:"detail_address"`
	Sex           int    `json:"sex"`
	Birthday      string `json:"birthday"`
	Bio           string `json:"bio"`
	HasPassword   bool   `json:"has_password"`
}

type appUpdateProfileRequest struct {
	Nickname      string  `json:"nickname" binding:"required,max=64"`
	Avatar        string  `json:"avatar" binding:"omitempty,max=255"`
	Sex           int     `json:"sex" binding:"user_sex"`
	Birthday      *string `json:"birthday" binding:"omitempty"`
	AddressID     *int64  `json:"address_id" binding:"required,min=0"`
	DetailAddress string  `json:"detail_address" binding:"omitempty,max=255"`
	Bio           string  `json:"bio" binding:"omitempty,max=1000"`
}

func appUserFromInit(currentUser *InitResponse) appUser {
	if currentUser == nil {
		return appUser{}
	}
	return appUser{ID: currentUser.UserID, Nickname: currentUser.Username, Avatar: currentUser.Avatar}
}

func appUserFromProfile(result *ProfileResponse) appUser {
	if result == nil {
		return appUser{}
	}
	return appUser{ID: result.Profile.UserID, Nickname: result.Profile.Username, Avatar: result.Profile.Avatar}
}

func appProfileFromUserProfile(result *ProfileResponse) appProfileResponse {
	if result == nil {
		return appProfileResponse{}
	}
	detail := result.Profile
	return appProfileResponse{
		Profile: appProfile{
			UserID:        detail.UserID,
			Nickname:      detail.Username,
			Email:         detail.Email,
			Phone:         detail.Phone,
			Avatar:        detail.Avatar,
			AddressID:     detail.AddressID,
			DetailAddress: detail.DetailAddress,
			Sex:           detail.Sex,
			Birthday:      detail.Birthday,
			Bio:           detail.Bio,
			HasPassword:   detail.HasPassword,
		},
		Dict: appProfileDict{
			AuthAddressTree: result.Dict.AuthAddressTree,
			SexArr:          result.Dict.SexArr,
		},
	}
}
```

- [ ] **Step 4: 新增 app handler**

创建 `admin_back_go/internal/module/user/app_handler.go`：

```go
package user

import (
	"admin_back_go/internal/apperror"
	"admin_back_go/internal/enum"
	"admin_back_go/internal/middleware"
	"admin_back_go/internal/response"

	"github.com/gin-gonic/gin"
)

func (h *Handler) AppMe(c *gin.Context) {
	identity, ok := h.appIdentity(c)
	if !ok {
		return
	}
	if h.service == nil {
		response.Error(c, apperror.InternalKey("user.service_missing", nil, "用户管理服务未配置"))
		return
	}
	currentUser, appErr := h.service.Init(c.Request.Context(), InitInput{UserID: identity.UserID, Platform: enum.PlatformApp})
	if appErr != nil {
		response.Error(c, appErr)
		return
	}
	response.OK(c, appUserFromInit(currentUser))
}

func (h *Handler) AppProfile(c *gin.Context) {
	identity, ok := h.appIdentity(c)
	if !ok {
		return
	}
	if h.service == nil {
		response.Error(c, apperror.InternalKey("user.service_missing", nil, "用户管理服务未配置"))
		return
	}
	result, appErr := h.service.Profile(c.Request.Context(), identity.UserID, identity.UserID)
	if appErr != nil {
		response.Error(c, appErr)
		return
	}
	response.OK(c, appProfileFromUserProfile(result))
}

func (h *Handler) AppUpdateProfile(c *gin.Context) {
	identity, ok := h.appIdentity(c)
	if !ok {
		return
	}
	if h.service == nil {
		response.Error(c, apperror.InternalKey("user.service_missing", nil, "用户管理服务未配置"))
		return
	}
	var req appUpdateProfileRequest
	if err := c.ShouldBindJSON(&req); err != nil || req.AddressID == nil {
		response.Error(c, apperror.BadRequestKey("app.profile.request.invalid", nil, "个人资料参数错误"))
		return
	}
	if appErr := h.service.UpdateProfile(c.Request.Context(), UpdateProfileInput{
		UserID:        identity.UserID,
		Username:      req.Nickname,
		Avatar:        req.Avatar,
		Sex:           req.Sex,
		Birthday:      req.Birthday,
		AddressID:     *req.AddressID,
		DetailAddress: req.DetailAddress,
		Bio:           req.Bio,
	}); appErr != nil {
		response.Error(c, appErr)
		return
	}
	result, appErr := h.service.Profile(c.Request.Context(), identity.UserID, identity.UserID)
	if appErr != nil {
		response.Error(c, appErr)
		return
	}
	response.OK(c, appProfileUpdateResponse{User: appUserFromProfile(result)})
}

func (h *Handler) appIdentity(c *gin.Context) (*middleware.AuthIdentity, bool) {
	identity := middleware.GetAuthIdentity(c)
	if identity == nil || identity.UserID <= 0 {
		response.Error(c, apperror.UnauthorizedKey("auth.token.invalid_or_expired", nil, "Token无效或已过期"))
		return nil, false
	}
	if identity.Platform != "" && identity.Platform != enum.PlatformApp {
		response.Error(c, apperror.UnauthorizedKey("auth.platform.invalid", map[string]any{"platform": identity.Platform}, "Token平台不匹配"))
		return nil, false
	}
	return identity, true
}
```

- [ ] **Step 5: 在 `user.RegisterRoutes` 注册 app routes**

在 `admin_back_go/internal/module/user/route.go` 的 `profile` group 后追加：

```go
	appUsers := router.Group("/api/app/v1/users")
	appUsers.GET("/me", handler.AppMe)

	appProfile := router.Group("/api/app/v1/profile")
	appProfile.GET("", handler.AppProfile)
	appProfile.PUT("", handler.AppUpdateProfile)
```

- [ ] **Step 6: 从 `appauth` 移除 user/profile route 注册**

把 `admin_back_go/internal/module/appauth/route.go` 改成仅保留 upload-token 临时注册：

```go
package appauth

import (
	"admin_back_go/internal/validate"

	"github.com/gin-gonic/gin"
)

func RegisterRoutes(router *gin.Engine, uploadTokenService UploadTokenService) {
	validate.MustRegister()
	handler := NewHandler(nil, nil, nil, uploadTokenService)

	uploadTokens := router.Group("/api/app/v1/upload-tokens")
	uploadTokens.POST("", handler.CreateUploadToken)
}
```

同步 `admin_back_go/internal/server/router.go` 调用：

```go
appauth.RegisterRoutes(router, deps.UploadTokenService)
```

- [ ] **Step 7: 运行测试确认 GREEN**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/user -run "TestUserModuleRegistersAppCurrentUserAndProfileRoutes|TestUserModuleAppRoutesRejectWrongPlatformScope" -count=1
go test ./internal/server -run "TestRouterInstallsAppAuthRoutes|TestRouterInstallsAppProfileAndUploadRoutes" -count=1
```

Expected:

```text
ok  	admin_back_go/internal/module/user
ok  	admin_back_go/internal/server
```

- [ ] **Step 8: 提交**

```powershell
git add internal/module/user/app_dto.go internal/module/user/app_handler.go internal/module/user/app_route_test.go internal/module/user/route.go internal/module/appauth/route.go internal/server/router.go
git commit -m "refactor: move app user routes into user module"
```

---

## Task 5: 把 app upload-token route 迁到 `uploadtoken` module

**Files:**

- Create: `admin_back_go/internal/module/uploadtoken/app_handler.go`
- Create: `admin_back_go/internal/module/uploadtoken/app_route_test.go`
- Modify: `admin_back_go/internal/module/uploadtoken/route.go`
- Modify: `admin_back_go/internal/server/router.go`

- [ ] **Step 1: 写失败测试**

创建 `admin_back_go/internal/module/uploadtoken/app_route_test.go`：

```go
package uploadtoken

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"admin_back_go/internal/apperror"
	"admin_back_go/internal/enum"
	"admin_back_go/internal/middleware"

	"github.com/gin-gonic/gin"
)

type fakeAppUploadTokenService struct {
	input CreateInput
}

func (f *fakeAppUploadTokenService) Create(ctx context.Context, input CreateInput) (*CreateResponse, *apperror.Error) {
	f.input = input
	return &CreateResponse{Provider: ProviderCOS, Bucket: "bucket-a", Region: "ap-nanjing", Key: "avatars/avatar.png"}, nil
}

func TestUploadTokenModuleRegistersAppRoute(t *testing.T) {
	service := &fakeAppUploadTokenService{}
	router := newAppUploadTokenTestRouter(service, &middleware.AuthIdentity{UserID: 7, SessionID: 20, Platform: enum.PlatformApp})

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodPost, "/api/app/v1/upload-tokens", strings.NewReader(`{"folder":"avatars","file_name":"avatar.png","file_size":1024,"file_kind":"image"}`))
	request.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d body=%s", recorder.Code, recorder.Body.String())
	}
	if service.input.Folder != "avatars" || service.input.FileName != "avatar.png" || service.input.FileSize != 1024 || service.input.FileKind != "image" {
		t.Fatalf("unexpected create input: %#v", service.input)
	}
	body := decodeAppUploadTokenBody(t, recorder)
	data := body["data"].(map[string]any)
	if data["provider"] != ProviderCOS || data["bucket"] != "bucket-a" {
		t.Fatalf("unexpected response data: %#v", data)
	}
}

func TestUploadTokenAppRouteRequiresIdentity(t *testing.T) {
	router := newAppUploadTokenTestRouter(&fakeAppUploadTokenService{}, nil)

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodPost, "/api/app/v1/upload-tokens", strings.NewReader(`{"folder":"avatars","file_name":"avatar.png","file_size":1024,"file_kind":"image"}`))
	request.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusUnauthorized {
		t.Fatalf("expected status 401, got %d body=%s", recorder.Code, recorder.Body.String())
	}
}

func newAppUploadTokenTestRouter(service HTTPService, identity *middleware.AuthIdentity) *gin.Engine {
	gin.SetMode(gin.ReleaseMode)
	router := gin.New()
	if identity != nil {
		router.Use(func(c *gin.Context) {
			c.Set(middleware.ContextAuthIdentity, identity)
			c.Next()
		})
	}
	RegisterRoutes(router, service)
	return router
}

func decodeAppUploadTokenBody(t *testing.T, recorder *httptest.ResponseRecorder) map[string]any {
	t.Helper()
	var body map[string]any
	if err := json.Unmarshal(recorder.Body.Bytes(), &body); err != nil {
		t.Fatalf("invalid json response: %v", err)
	}
	return body
}
```

- [ ] **Step 2: 运行测试确认 RED**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/uploadtoken -run "TestUploadTokenModuleRegistersAppRoute|TestUploadTokenAppRouteRequiresIdentity" -count=1
```

Expected:

```text
FAIL
expected status 200, got 404
```

- [ ] **Step 3: 新增 app handler**

创建 `admin_back_go/internal/module/uploadtoken/app_handler.go`：

```go
package uploadtoken

import (
	"admin_back_go/internal/apperror"
	"admin_back_go/internal/enum"
	"admin_back_go/internal/middleware"
	"admin_back_go/internal/response"

	"github.com/gin-gonic/gin"
)

func (h *Handler) AppCreate(c *gin.Context) {
	identity := middleware.GetAuthIdentity(c)
	if identity == nil || identity.UserID <= 0 {
		response.Error(c, apperror.UnauthorizedKey("auth.token.invalid_or_expired", nil, "Token无效或已过期"))
		return
	}
	if identity.Platform != "" && identity.Platform != enum.PlatformApp {
		response.Error(c, apperror.UnauthorizedKey("auth.platform.invalid", map[string]any{"platform": identity.Platform}, "Token平台不匹配"))
		return
	}
	h.Create(c)
}
```

- [ ] **Step 4: 注册 app upload-token route**

把 `admin_back_go/internal/module/uploadtoken/route.go` 改成：

```go
package uploadtoken

import (
	"admin_back_go/internal/validate"

	"github.com/gin-gonic/gin"
)

func RegisterRoutes(router *gin.Engine, service HTTPService) {
	validate.MustRegister()
	handler := NewHandler(service)

	adminGroup := router.Group("/api/admin/v1/upload-tokens")
	adminGroup.POST("", handler.Create)

	appGroup := router.Group("/api/app/v1/upload-tokens")
	appGroup.POST("", handler.AppCreate)
}
```

- [ ] **Step 5: server 停止注册 `appauth`**

在 `admin_back_go/internal/server/router.go` 删除 import：

```go
"admin_back_go/internal/module/appauth"
```

删除调用：

```go
appauth.RegisterRoutes(router, deps.UploadTokenService)
```

- [ ] **Step 6: GREEN**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/uploadtoken -run "TestUploadTokenModuleRegistersAppRoute|TestUploadTokenAppRouteRequiresIdentity" -count=1
go test ./internal/server -run "TestRouterInstallsAppAuthRoutes|TestRouterInstallsAppProfileAndUploadRoutes" -count=1
```

Expected:

```text
ok  	admin_back_go/internal/module/uploadtoken
ok  	admin_back_go/internal/server
```

- [ ] **Step 7: 提交**

```powershell
git add internal/module/uploadtoken/app_handler.go internal/module/uploadtoken/app_route_test.go internal/module/uploadtoken/route.go internal/server/router.go
git commit -m "refactor: move app upload token route into uploadtoken module"
```

---

## Task 6: 删除 `appauth` package 并加架构守卫

**Files:**

- Create: `admin_back_go/internal/architecture/platform_scope_test.go`
- Modify: `admin_back_go/internal/server/router_test.go`
- Delete: `admin_back_go/internal/module/appauth/dto.go`
- Delete: `admin_back_go/internal/module/appauth/handler.go`
- Delete: `admin_back_go/internal/module/appauth/route.go`

- [ ] **Step 1: 写架构守卫测试**

```powershell
cd E:\admin_go\admin_back_go
New-Item -ItemType Directory -Force internal\architecture
```

创建 `admin_back_go/internal/architecture/platform_scope_test.go`：

```go
package architecture_test

import (
	"os"
	"strings"
	"testing"
)

func TestPlatformIsNotAuthModule(t *testing.T) {
	entries, err := os.ReadDir("../module")
	if err != nil {
		t.Fatalf("read module dir: %v", err)
	}
	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}
		name := strings.ToLower(entry.Name())
		if name == "auth" {
			continue
		}
		if strings.HasSuffix(name, "auth") {
			t.Fatalf("platform-named auth module must not exist: internal/module/%s", entry.Name())
		}
	}
}
```

- [ ] **Step 2: 运行测试确认 RED**

```powershell
go test ./internal/architecture -run TestPlatformIsNotAuthModule -count=1
```

Expected:

```text
FAIL
platform-named auth module must not exist: internal/module/appauth
```

- [ ] **Step 3: 删除临时 server 断言**

在 `admin_back_go/internal/server/router_test.go` 删除 Task 3 加过的测试：

```go
func TestAppAuthPackageDoesNotRegisterAuthRoutes(t *testing.T) {
	content, err := os.ReadFile(filepath.Join("..", "module", "appauth", "route.go"))
	if err != nil {
		t.Fatalf("read appauth route.go: %v", err)
	}
	text := string(content)
	for _, forbidden := range []string{"/api/app/v1/auth", "LoginConfig", "SendCode", "Login)", "Logout"} {
		if strings.Contains(text, forbidden) {
			t.Fatalf("appauth must not own auth route marker %q", forbidden)
		}
	}
}
```

如果 `os`、`path/filepath` 只被这个测试使用，同步移除这两个 import。

- [ ] **Step 4: 删除 appauth 包**

```powershell
Remove-Item internal\module\appauth\dto.go, internal\module\appauth\handler.go, internal\module\appauth\route.go
Remove-Item internal\module\appauth -Force
```

- [ ] **Step 5: GREEN**

```powershell
go test ./internal/architecture -run TestPlatformIsNotAuthModule -count=1
go test ./internal/server -run "TestRouterInstallsAppAuthRoutes|TestRouterInstallsAppProfileAndUploadRoutes" -count=1
go test ./internal/module/auth ./internal/module/user ./internal/module/uploadtoken -count=1
```

Expected:

```text
ok  	admin_back_go/internal/architecture
ok  	admin_back_go/internal/server
ok  	admin_back_go/internal/module/auth
ok  	admin_back_go/internal/module/user
ok  	admin_back_go/internal/module/uploadtoken
```

- [ ] **Step 6: 提交**

```powershell
git add internal/architecture/platform_scope_test.go internal/server/router_test.go internal/module/appauth
git commit -m "refactor: remove appauth platform module"
```

---

## Task 7: 更新文档和状态

**Files:**

- Modify: `docs/status/current-status.md`
- Modify: `docs/contracts/admin-api-v1.md`
- Modify: `admin_back_go/docs/architecture.md`
- Modify: `docs/architecture/04-go-backend-framework.md`

- [ ] **Step 1: 更新 current-status**

在 `docs/status/current-status.md` 的 app auth baseline 行中，把模块归属改成：

```text
internal/module/auth, internal/module/user, internal/module/uploadtoken
```

补充：

```text
平台不是 module；app auth 由 auth 注册 platform route，app profile 和 upload-token 分别归属 user / uploadtoken。
```

- [ ] **Step 2: 更新 API contract**

在 `docs/contracts/admin-api-v1.md` 的 App auth baseline 段落保留公开路径不变，新增：

```text
Ownership：/api/app/v1/auth/* 归属 internal/module/auth；/api/app/v1/users/me 和 /api/app/v1/profile 归属 internal/module/user；/api/app/v1/upload-tokens 归属 internal/module/uploadtoken。平台 app 是 route/policy scope，不是 appauth module。
```

- [ ] **Step 3: 更新架构文档**

在 `admin_back_go/docs/architecture.md` 和 `docs/architecture/04-go-backend-framework.md` 加硬规则：

```text
平台不是 module。新增平台不得默认新增 xxxauth / xxxuser / xxxupload 这类平台命名业务模块。平台差异通过 route prefix、platform 字段、策略表和 presenter 表达；业务能力仍归属 auth/user/uploadtoken 等模块。
```

- [ ] **Step 4: 文档扫描**

```powershell
cd E:\admin_go
rg -n "appauth|平台不是 module|平台命名业务模块" docs admin_back_go\docs admin_back_go\internal
```

Expected:

```text
没有 internal/module/appauth 路径引用；文档只保留平台不是 module 的规则说明。
```

- [ ] **Step 5: 提交文档**

```powershell
git add docs/status/current-status.md docs/contracts/admin-api-v1.md admin_back_go/docs/architecture.md docs/architecture/04-go-backend-framework.md
git commit -m "docs: document platform-as-scope module rule"
```

---

## Task 8: 全量验证和收尾

**Files:** 无源码改动，除非验证暴露具体编译/契约失败。

- [ ] **Step 1: 跑目标 Go 测试**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/auth ./internal/module/user ./internal/module/uploadtoken ./internal/server ./internal/architecture -count=1
```

Expected:

```text
所有 package PASS
```

- [ ] **Step 2: 跑后端完整测试**

```powershell
go test ./... -count=1
```

Expected:

```text
所有 package PASS
```

- [ ] **Step 3: 跑治理检查**

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected:

```text
PASS: no blocking governance violations found.
```

- [ ] **Step 4: dry-run push**

```powershell
git push --dry-run origin master
git -C admin_back_go push --dry-run origin master
```

Expected:

```text
pre-push governance PASS
远端 dry-run 成功
```

---

## Self-review checklist

- Spec coverage：auth platform route、非认证 app endpoints 归属、删除 appauth、文档硬规则、测试要求均有任务覆盖。
- 占位标记检查：没有未完成占位标记。
- 类型一致性：`PlatformRouteOptions`、`PlatformHandler`、`PlatformUserInitService`、app DTO 名称在测试和实现步骤中一致。
- 范围控制：不改 token/session/auth_platforms schema，不重写 router，只迁移 appauth 的 ownership。
