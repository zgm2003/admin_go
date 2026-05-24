# Platform Scope Adapter and APP_NAME Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Encode the Platform Scope Adapter rule, keep `authplatform` scoped to authentication/session policy, and remove misleading shared `APP_NAME=admin-api` runtime configuration without touching the active `admin_app` login implementation.

**Architecture:** Treat `/api/admin/v1` and `/api/app/v1` as HTTP scopes, not business module boundaries. Shared capability modules such as `auth`, `aichat`, `wallet`, and `uploadtoken` own business service/repository/model logic; platform differences stay in route/handler/presenter/policy. Process identity is owned by `cmd/admin-api`, `cmd/admin-worker`, and Docker Compose service names, not by shared `APP_NAME`.

**Tech Stack:** Go 1.x backend, Gin modular monolith, Docker-first env templates, Markdown governance docs, PowerShell governance checks.

---

## Scope Check

This plan intentionally does **not** move `internal/module/appauth` in this pass. Another Codex is actively touching the App auth slice, and current runtime already reuses capability services; the immediate architecture risk is bad governance and misleading env naming, not duplicated business logic.

In scope:

```text
1. Add durable Platform Scope Adapter rules to architecture/quality docs.
2. Mark `appauth` as a transitional HTTP adapter, not a business module pattern.
3. Remove `APP_NAME` from Go config, tests, Docker-first env templates, and backend env docs.
4. Add tests that prevent `Config.App.Name` and Docker-first `APP_NAME` from reappearing.
5. Run focused config tests plus root governance checks.
```

Out of scope:

```text
1. Moving appauth files into auth/user/uploadtoken modules.
2. Changing /api/app/v1 paths or response contracts.
3. Adding App AI / wallet runtime endpoints.
4. Adding PROCESS_NAME / PROJECT_NAME as a replacement env.
5. Touching admin_app frontend code.
```

## File Structure

Root docs:

```text
Modify: docs/architecture/04-go-backend-framework.md
Modify: docs/architecture/05-development-quality-rules.md
Read:   docs/status/current-status.md
Read:   docs/superpowers/specs/2026-05-24-platform-scope-adapter-design.md
```

Backend docs:

```text
Modify: admin_back_go/docs/architecture.md
```

Backend config/runtime:

```text
Modify: admin_back_go/internal/config/config.go
Modify: admin_back_go/internal/config/config_test.go
Modify: admin_back_go/deploy/docker-first/admin-go.env.example
Modify: admin_back_go/deploy/docker-first/admin-go.env
```

Verification only:

```text
Run: E:\admin_go\scripts\check-agent-governance.ps1
Run: git diff --check
Run: cd E:\admin_go\admin_back_go; go test ./internal/config -count=1
```

---

### Task 1: Encode Platform Scope Adapter governance

**Files:**
- Modify: `docs/architecture/04-go-backend-framework.md`
- Modify: `docs/architecture/05-development-quality-rules.md`
- Modify: `admin_back_go/docs/architecture.md`

- [x] **Step 1: Add backend framework rule**

In `docs/architecture/04-go-backend-framework.md`, after the existing `module 规则` section and before `调用方向`, add this section:

````markdown
## Platform Scope Adapter 规则

`/api/admin/v1` 和 `/api/app/v1` 是 HTTP scope，不是业务模块边界。

业务模块必须按 capability 命名，例如 `auth`、`aichat`、`wallet`、`uploadtoken`、`notification`。新增平台时，默认只新增 route / handler / presenter / policy，不新增 `appai`、`appwallet`、`xxauth` 这类平台名前缀业务模块。

允许：

```text
/api/admin/v1/... -> admin route/handler -> shared service -> repository/model -> admin presenter
/api/app/v1/...   -> app route/handler   -> shared service -> repository/model -> app presenter
```

禁止：

```text
adminauth + appauth + xxauth 各自实现业务
adminai + appai + xxai 各自实现业务
adminwallet + appwallet + xxwallet 各自实现业务
```

临时平台 adapter 必须有名字、有边界、有收敛计划。`appauth` 当前只能被理解为 `/api/app/v1` scope 下 auth / users/me / profile / upload-tokens 的临时 HTTP adapter bundle，不拥有 auth/user/uploadtoken service、repository、model 或认证策略。
````

- [x] **Step 2: Add quality-rule smell guard**

In `docs/architecture/05-development-quality-rules.md`, after `RESTful API 规则`, add:

````markdown
## 平台 scope 不复制业务模块

新增端、平台、入口时先判断差异属于哪一层：

```text
route prefix 不同      -> route/handler
请求字段不同          -> request DTO
返回字段不同          -> presenter
认证/会话策略不同     -> authplatform 或 session policy
业务规则真的不同      -> capability service 的显式 policy/input
```

禁止为了端差异复制业务模块：

```text
appai / appwallet / xxauth / adminai
```

`appauth` 这类已经存在的过渡目录必须保持 adapter-only：不查 DB，不拥有 repository/model，不复制 shared service。它当前覆盖 `/api/app/v1/auth/*`、`/api/app/v1/users/me`、`/api/app/v1/profile`、`/api/app/v1/upload-tokens`，未来收敛时必须按 capability 回到 `auth` / `user` / `uploadtoken`。新增类似目录前必须先写 spec 并说明退出条件。
````

- [x] **Step 3: Add backend runtime baseline**

In `admin_back_go/docs/architecture.md`, update `模块家族` wording so `appauth` is explicitly transitional. Add this text near the existing App API paragraph:

```markdown
App 用户端 API 是独立 HTTP 命名空间，当前挂在 `/api/app/v1`，但它仍复用同一套 capability service。`internal/module/appauth` 是过渡期的 App scope adapter bundle：它当前承载 `/api/app/v1/auth/*`、`/api/app/v1/users/me`、`/api/app/v1/profile`、`/api/app/v1/upload-tokens`，固定 `platform=app`、裁剪 App 出参、复用 `auth/user/session/captcha/uploadtoken` 等 service；它不是第二套 auth/user/uploadtoken 业务模块，不能作为后续 `appai` / `appwallet` 的命名模板。

平台差异默认收敛在 route / handler / presenter / policy。`authplatform` 只拥有认证/会话策略，例如登录方式、验证码类型、token TTL、会话绑定、单端登录和是否允许注册；它不是 AI、钱包、通知等业务的全局平台配置中心。
```

- [x] **Step 4: Verify the docs contain the rule**

Run:

```powershell
cd E:\admin_go
rg -n "Platform Scope Adapter|平台 scope 不是业务模块边界|appauth.*adapter|authplatform.*认证/会话" docs\architecture admin_back_go\docs\architecture.md -S
```

Expected: matches in all three modified docs.

- [x] **Step 5: Commit boundary check for Task 1**

Run:

```powershell
cd E:\admin_go
git diff -- docs/architecture/04-go-backend-framework.md docs/architecture/05-development-quality-rules.md admin_back_go/docs/architecture.md
```

Expected: only documentation changes; no Go, Vue, SQL, or env file changes in this task.

---

### Task 2: Add failing APP_NAME cleanup tests

**Files:**
- Modify: `admin_back_go/internal/config/config_test.go`

- [x] **Step 1: Add tests before implementation**

Append these tests to `admin_back_go/internal/config/config_test.go`:

```go
func TestConfigDoesNotExposeAppName(t *testing.T) {
	unsetEnvForTest(t, "APP_ENV")
	t.Setenv("APP_NAME", "admin-api-test")

	cfg := Load()
	appType := reflect.TypeOf(cfg.App)
	if _, ok := appType.FieldByName("Name"); ok {
		t.Fatalf("AppConfig must not expose Name; process identity is owned by cmd entrypoints and Compose services")
	}
	if cfg.App.Env != "local" {
		t.Fatalf("expected app env local, got %q", cfg.App.Env)
	}
}

func TestDockerFirstEnvDoesNotDocumentAppName(t *testing.T) {
	paths := []string{
		filepath.Join("..", "..", "deploy", "docker-first", "admin-go.env.example"),
		filepath.Join("..", "..", "deploy", "docker-first", "admin-go.env"),
	}
	for _, path := range paths {
		content, err := os.ReadFile(path)
		if os.IsNotExist(err) {
			continue
		}
		if err != nil {
			t.Fatalf("read %s: %v", path, err)
		}
		if strings.Contains(string(content), "APP_NAME") {
			t.Fatalf("%s must not document APP_NAME in shared Docker-first env", path)
		}
	}
}
```

`config_test.go` already imports `os`, `filepath`, `reflect`, `strings`, `testing`, and `time`; do not add duplicate imports.

- [x] **Step 2: Run the failing tests**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/config -run "TestConfigDoesNotExposeAppName|TestDockerFirstEnvDoesNotDocumentAppName" -count=1
```

Expected: FAIL because `AppConfig.Name` exists and Docker-first env files still contain `APP_NAME`.

---

### Task 3: Remove APP_NAME from Go config and tests

**Files:**
- Modify: `admin_back_go/internal/config/config.go`
- Modify: `admin_back_go/internal/config/config_test.go`

- [x] **Step 1: Remove `Name` from AppConfig**

Change `admin_back_go/internal/config/config.go` from:

```go
type AppConfig struct {
	Name   string
	Env    string
	Secret string
}
```

to:

```go
type AppConfig struct {
	Env    string
	Secret string
}
```

- [x] **Step 2: Stop reading APP_NAME**

Change the `App` block in `Load()` from:

```go
App: AppConfig{
	Name:   envString("APP_NAME", "admin-api"),
	Env:    envString("APP_ENV", "local"),
	Secret: envString("APP_SECRET", ""),
},
```

to:

```go
App: AppConfig{
	Env:    envString("APP_ENV", "local"),
	Secret: envString("APP_SECRET", ""),
},
```

- [x] **Step 3: Update default config test**

In `TestLoadUsesSafeDefaults`, delete this assertion:

```go
if cfg.App.Name != "admin-api" {
	t.Fatalf("expected app name admin-api, got %q", cfg.App.Name)
}
```

Keep the existing `cfg.App.Env` and `cfg.App.Secret` assertions.

- [x] **Step 4: Update env override test**

In `TestLoadReadsEnvironmentOverrides`, remove:

```go
t.Setenv("APP_NAME", "admin-api-test")
```

Change:

```go
if cfg.App.Name != "admin-api-test" || cfg.App.Env != "test" || cfg.App.Secret != strings.Repeat("s", 64) {
	t.Fatalf("unexpected app config: %#v", cfg.App)
}
```

to:

```go
if cfg.App.Env != "test" || cfg.App.Secret != strings.Repeat("s", 64) {
	t.Fatalf("unexpected app config: %#v", cfg.App)
}
```

- [x] **Step 5: Update dotenv test**

Find the dotenv test that writes:

```go
APP_NAME=admin-api-dotenv
HTTP_ADDR=:19090
```

Change it to:

```go
APP_ENV=dotenv
HTTP_ADDR=:19090
```

Delete the assertion for `cfg.App.Name` and assert `cfg.App.Env` instead:

```go
if cfg.App.Env != "dotenv" {
	t.Fatalf("expected app env from .env, got %q", cfg.App.Env)
}
```

- [x] **Step 6: Remove Name from direct AppConfig literals**

In `config_test.go`, remove `Name: "admin-api"` from the runtime-secret validation fixtures:

```go
cfg := Config{App: AppConfig{Name: "admin-api", Env: "local"}}
cfg := Config{App: AppConfig{Name: "admin-api", Env: "local", Secret: "change_me_to_at_least_64_random_chars"}}
cfg := Config{App: AppConfig{Name: "admin-api", Env: "local", Secret: strings.Repeat("k", 64)}}
```

Change them to:

```go
cfg := Config{App: AppConfig{Env: "local"}}
cfg := Config{App: AppConfig{Env: "local", Secret: "change_me_to_at_least_64_random_chars"}}
cfg := Config{App: AppConfig{Env: "local", Secret: strings.Repeat("k", 64)}}
```

- [x] **Step 7: Remove APP_NAME from unset helper calls**

Delete any `unsetEnvForTest(t, "APP_NAME")` call from `config_test.go`.

- [x] **Step 8: Run focused config tests**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/config -count=1
```

Expected: PASS.

---

### Task 4: Remove APP_NAME from Docker-first env and docs

**Files:**
- Modify: `admin_back_go/deploy/docker-first/admin-go.env.example`
- Modify: `admin_back_go/deploy/docker-first/admin-go.env`
- Modify: `admin_back_go/docs/architecture.md`

- [x] **Step 1: Remove APP_NAME from env example**

In `admin_back_go/deploy/docker-first/admin-go.env.example`, remove this line:

```dotenv
APP_NAME=admin-api
```

Keep:

```dotenv
APP_ENV=production
HTTP_ADDR=:8080
HTTP_READ_HEADER_TIMEOUT=5s
```

- [x] **Step 2: Remove APP_NAME from local Docker-first env**

In `admin_back_go/deploy/docker-first/admin-go.env`, remove this line:

```dotenv
APP_NAME=admin-api
```

Keep the Chinese section header `# 应用与 HTTP`, because `APP_ENV` and HTTP settings still belong there.

- [x] **Step 3: Remove APP_NAME from backend architecture env list**

In `admin_back_go/docs/architecture.md`, find the env list containing:

```text
APP_NAME
APP_ENV
HTTP_ADDR
```

Remove `APP_NAME`, leaving:

```text
APP_ENV
HTTP_ADDR
HTTP_READ_HEADER_TIMEOUT
```

- [x] **Step 4: Add backend doc note for process identity**

Near the logging/process section in `admin_back_go/docs/architecture.md`, add:

```markdown
进程身份不来自 env。`cmd/admin-api` 固定使用 `logging.ForProcess("admin-api")`，`cmd/admin-worker` 固定使用 `logging.ForProcess("admin-worker")`；Docker-first Compose service name 也分别是 `admin-api` 和 `admin-worker`。共享 `admin-go.env` 不再提供 `APP_NAME`，避免同一份 env 同时服务 API/worker 时产生错误语义。
```

- [x] **Step 5: Verify APP_NAME is gone from runtime locations**

Run:

```powershell
cd E:\admin_go
rg -n "APP_NAME|App\.Name|cfg\.App\.Name" admin_back_go\cmd admin_back_go\internal admin_back_go\deploy admin_back_go\docs docs\architecture docs\deployment -S
```

Expected: no matches. Matches inside `docs/superpowers/specs` or `docs/superpowers/plans` are allowed because those files explain the cleanup decision.

- [x] **Step 6: Run config tests again**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/config -count=1
```

Expected: PASS.

---

### Task 5: Full verification and handoff

**Files:**
- Read: root git diff
- Read: backend git diff

- [x] **Step 1: Run backend focused tests**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/config ./internal/bootstrap ./internal/server -count=1
```

Expected: PASS. This validates config loading, bootstrap construction, and router compile safety without touching the concurrent App auth implementation more broadly.

- [x] **Step 2: Run architecture/governance checks**

Run:

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected: both PASS.

- [x] **Step 3: Confirm no accidental platform module proliferation**

Run:

```powershell
cd E:\admin_go\admin_back_go
Get-ChildItem -Path .\internal\module -Directory | Where-Object { $_.Name -match '^(app|admin|xx).*(auth|ai|wallet|payment)$' } | Select-Object -ExpandProperty Name
```

Expected: only `appauth` may appear, and the final response must state it is transitional adapter-only. If any new `appai`, `appwallet`, `adminai`, or similar directory appears, stop and review before continuing.

- [x] **Step 4: Summarize diff for expert review**

Run:

```powershell
cd E:\admin_go
git diff --stat
git diff -- docs/architecture/04-go-backend-framework.md docs/architecture/05-development-quality-rules.md docs/superpowers/specs/2026-05-24-platform-scope-adapter-design.md docs/superpowers/plans/2026-05-24-platform-scope-adapter-and-app-name-cleanup.md
cd E:\admin_go\admin_back_go
git diff -- internal/config/config.go internal/config/config_test.go deploy/docker-first/admin-go.env.example deploy/docker-first/admin-go.env docs/architecture.md
```

Expected: concise diff limited to docs, config cleanup, env cleanup, and tests.

- [x] **Step 5: Do not claim appauth consolidation is complete**

Final handoff must explicitly say:

```text
appauth 仍然存在，但已被治理为 transitional HTTP adapter。
本计划没有移动 appauth，也没有改变 /api/app/v1 contract。
APP_NAME cleanup 是独立低风险切片。
appauth 结构收敛需要等当前 admin_app 登录任务稳定后另开计划。
```

---

## Later Follow-up: appauth structural consolidation

Only start this after the current `admin_app` auth/captcha/login task is merged or otherwise stable.

Required preconditions:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/auth ./internal/module/appauth ./internal/module/captcha ./internal/module/user ./internal/module/uploadtoken ./internal/server -count=1
cd E:\admin_go\admin_app
npm run test:unit -- tests/app-auth-api.test.ts tests/session-controller.test.ts tests/app-backend-base.test.ts
npm run type-check
npm run build:h5
```

If the project still wants structural cleanup, write a separate plan that moves `appauth` adapter code into:

```text
admin_back_go/internal/module/auth/route_app.go
admin_back_go/internal/module/auth/handler_app.go
admin_back_go/internal/module/auth/presenter_app.go
admin_back_go/internal/module/user/route_app.go
admin_back_go/internal/module/user/handler_app.go
admin_back_go/internal/module/user/presenter_app.go
admin_back_go/internal/module/uploadtoken/route_app.go
admin_back_go/internal/module/uploadtoken/handler_app.go
admin_back_go/internal/module/uploadtoken/presenter_app.go
```

That follow-up must not change public paths or response shape. It must preserve every route currently registered by `internal/module/appauth/route.go`, including `/api/app/v1/auth/*`, `/api/app/v1/users/me`, `/api/app/v1/profile`, and `/api/app/v1/upload-tokens`.
