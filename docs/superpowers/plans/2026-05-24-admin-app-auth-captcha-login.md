# Admin App Auth Captcha Login Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `admin_app` H5 login work through the local Go backend, align app auth with `auth_platforms`, require slide captcha for password login, and restyle the UniApp login page to match the PC login page's mobile layout.

**Adjustment on 2026-05-24:** H5 must not use a Vite reverse proxy for `/api/app/v1`. The app should request `http://127.0.0.1:8080/api/app/v1` directly and rely on backend CORS.

**Architecture:** Keep `/api/app/v1` as the To C app namespace. Reuse existing Go auth/captcha/session services, but expose app-scoped public endpoints through `appauth` and force `platform=app` server-side instead of trusting headers. In `admin_app`, keep all HTTP calls inside `src/api/*`, keep session persistence in `src/stores/session.ts`, and build a UniApp-native mobile login surface inspired by `admin_front_ts/src/views/Login`.

**Tech Stack:** Go + Gin backend, UniApp Vue3 + TypeScript + Composition API frontend, Vitest/vue-tsc/build:h5 verification.

---

### Task 1: Backend app auth contract and captcha enforcement

**Files:**
- Modify: `admin_back_go/internal/module/appauth/dto.go`
- Modify: `admin_back_go/internal/module/appauth/handler.go`
- Modify: `admin_back_go/internal/module/appauth/route.go`
- Modify: `admin_back_go/internal/module/captcha/route.go`
- Modify: `admin_back_go/internal/module/auth/service.go`
- Modify: `admin_back_go/internal/module/auth/service_test.go`
- Modify: `admin_back_go/internal/server/router_test.go`

- [x] **Step 1: Write failing Go tests**

Add tests proving:

```go
// internal/module/auth/service_test.go
func TestServiceAppPasswordLoginRequiresCaptcha(t *testing.T) {
    service := NewService(&fakeAuthRepository{}, fakeLoginTypeProvider{types: []string{"password"}}, &fakeSessionCreator{}, &fakeCaptchaVerifier{})
    _, appErr := service.Login(context.Background(), LoginInput{
        LoginAccount: "15671628271",
        LoginType:    LoginTypePassword,
        Password:     "123456",
        Platform:     "app",
    })
    if appErr == nil || !strings.Contains(appErr.Message, "请完成验证码") {
        t.Fatalf("expected app password login to require captcha, got %v", appErr)
    }
}
```

```go
// internal/server/router_test.go
// Extend TestRouterInstallsAppAuthRoutes so it covers:
// GET  /api/app/v1/auth/login-config
// GET  /api/app/v1/auth/captcha
// POST /api/app/v1/auth/send-code
// POST /api/app/v1/auth/login with login_type/login_account/captcha payload
```

- [x] **Step 2: Verify tests fail**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/auth ./internal/server -run "TestServiceAppPasswordLoginRequiresCaptcha|TestRouterInstallsAppAuthRoutes" -count=1
```

Expected: FAIL because app password login still skips captcha and app login-config/captcha/send-code routes are not all installed.

- [x] **Step 3: Implement backend**

Implement these contract changes:

```text
GET  /api/app/v1/auth/login-config -> auth.LoginConfig(ctx, "app")
GET  /api/app/v1/auth/captcha      -> captcha.Generate
POST /api/app/v1/auth/send-code    -> auth.SendCode
POST /api/app/v1/auth/login        -> auth.Login(ctx, platform="app")
```

Use this app login request schema:

```json
{
  "login_type": "password",
  "login_account": "15671628271",
  "password": "123456",
  "code": "",
  "captcha_id": "captcha-id",
  "captcha_answer": { "x": 120, "y": 80 }
}
```

Keep response schema:

```json
{
  "token": "access-token",
  "user": { "id": 1, "nickname": "不羡明月知", "avatar": "" }
}
```

Remove the app-only password captcha bypass by making password login require captcha for every platform.

- [x] **Step 4: Verify backend**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/auth ./internal/module/appauth ./internal/module/captcha ./internal/server -count=1
```

Expected: PASS.

### Task 2: Admin app H5 backend base and app auth client

**Files:**
- Modify: `admin_app/vite.config.ts`
- Modify: `admin_app/src/types/auth.ts`
- Modify: `admin_app/src/api/appAuth.ts`
- Modify: `admin_app/src/stores/session.ts`
- Modify: `admin_app/tests/app-auth-api.test.ts`
- Modify: `admin_app/tests/session-controller.test.ts`
- Add or modify: `admin_app/tests/app-backend-base.test.ts`

- [x] **Step 1: Write failing Vitest tests**

Add tests proving:

```ts
// tests/app-backend-base.test.ts
expect(server.proxy?.['/api/app/v1']).toBeUndefined()
expect(resolveAppApiBaseUrl()).toBe('http://127.0.0.1:8080/api/app/v1')
```

```ts
// tests/app-auth-api.test.ts
await client.login({
  login_type: 'password',
  login_account: '15671628271',
  password: '123456',
  captcha_id: 'captcha-id',
  captcha_answer: { x: 120, y: 80 },
})
expect(calls[0].url).toBe('/auth/login')
```

- [x] **Step 2: Verify tests fail**

Run:

```powershell
cd E:\admin_go\admin_app
npm run test:unit -- tests/app-auth-api.test.ts tests/app-backend-base.test.ts
```

Expected: FAIL because the app still uses a Vite proxy or relative API base, and new app auth methods/types are missing.

- [x] **Step 3: Implement frontend API boundary**

Remove the Vite proxy and set a direct backend base:

```ts
const DEFAULT_APP_API_BASE_URL = 'http://127.0.0.1:8080/api/app/v1'
```

Extend app auth client with `loginConfig`, `captcha`, `sendCode`, and new login payload.

- [x] **Step 4: Verify frontend API**

Run:

```powershell
cd E:\admin_go\admin_app
npm run test:unit -- tests/app-auth-api.test.ts tests/session-controller.test.ts tests/app-backend-base.test.ts
```

Expected: PASS.

### Task 3: UniApp login page matching PC mobile style

**Files:**
- Modify: `admin_app/src/pages/login/index.vue`
- Modify: `admin_app/src/locales/zh-CN.ts`
- Modify: `admin_app/src/locales/en-US.ts`
- Add: `admin_app/tests/app-login-copy.test.ts`

- [x] **Step 1: Write failing copy/structure tests**

Add a text-level test proving the login page includes:

```text
login-mobile-sheet
method-tabs
captcha-overlay
agreement-row
```

and locales include:

```text
auth.loginTypes.password
auth.loginTypes.email
auth.loginTypes.phone
auth.captchaTitle
auth.serviceAgreement
auth.privacyPolicy
```

- [x] **Step 2: Verify tests fail**

Run:

```powershell
cd E:\admin_go\admin_app
npm run test:unit -- tests/app-login-copy.test.ts
```

Expected: FAIL because the current login page is a simple two-field form.

- [x] **Step 3: Implement UniApp login UI**

Keep the page UniApp-native:

```text
view/text/input/button/slider/u-button
```

Implement:

```text
PC mobile-like background mesh
mobile brand header
method tabs from login_config
password/email/phone mode switching
send-code for email/phone modes
captcha overlay with master image, tile image, slider, confirm button
service/privacy agreement checkbox
remember account toggle
```

- [x] **Step 4: Verify login page**

Run:

```powershell
cd E:\admin_go\admin_app
npm run test:unit -- tests/app-login-copy.test.ts tests/app-auth-api.test.ts tests/session-controller.test.ts
npm run type-check
npm run build:h5
```

Expected: PASS.

### Task 4: Docs and end-to-end verification

**Files:**
- Modify: `docs/contracts/admin-api-v1.md`
- Modify: `docs/status/current-status.md`
- Modify: `admin_app/docs/app-api-v1.md`
- Modify: `admin_app/docs/architecture.md`

- [x] **Step 1: Sync docs**

Record the verified app auth contract:

```text
GET  /api/app/v1/auth/login-config
GET  /api/app/v1/auth/captcha
POST /api/app/v1/auth/send-code
POST /api/app/v1/auth/login
GET  /api/app/v1/users/me
POST /api/app/v1/auth/logout
```

State that app password login now follows the app platform captcha policy instead of skipping captcha.

- [x] **Step 2: Run final verification**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/auth ./internal/module/appauth ./internal/module/captcha ./internal/server -count=1

cd E:\admin_go\admin_app
npm run test:unit
npm run type-check
npm run build:h5

cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected: all commands exit 0.

- [x] **Step 3: Manual runtime smoke**

With backend on `127.0.0.1:8080` and HBuilderX/Vite on `localhost:5173`, verify direct backend + CORS:

```powershell
curl.exe -i http://127.0.0.1:8080/api/app/v1/auth/login-config
curl.exe -i http://127.0.0.1:8080/api/app/v1/auth/captcha
curl.exe -i -X OPTIONS http://127.0.0.1:8080/api/app/v1/auth/login-config -H "Origin: http://localhost:5173" -H "Access-Control-Request-Method: GET"
```

Expected: direct backend endpoints return JSON and CORS preflight succeeds.
