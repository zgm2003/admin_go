# CORS Env Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep only `CORS_ALLOW_ORIGINS` in Docker-first env while making CORS headers, credentials, max age, and local default origins code-owned and tested.

**Architecture:** `internal/config.DefaultCORSConfig()` remains the single source of truth for code-owned CORS defaults. `config.Load()` only accepts deployment-owned origin overrides from `CORS_ALLOW_ORIGINS`; HTTP CORS middleware and WebSocket Origin checking continue to share `cfg.CORS.AllowOrigins`. CORS policy does not move into `system_settings` because it is an entry-layer browser/security boundary, not business configuration.

**Tech Stack:** Go 1.x, Gin, `github.com/gin-contrib/cors`, Gorilla WebSocket origin checker through realtime stack, Docker Compose Docker-first deployment, PowerShell/curl smoke checks, Markdown docs.

---

## Scope Check

This plan covers one narrow subsystem: CORS env cleanup for the Go backend Docker-first path. It does not change auth/session behavior, frontend request code, Nginx/Baota panel CORS behavior, WebSocket message protocol, DB schema, SQL migrations, or `system_settings`.

## File Map

Backend repo `E:\admin_go\admin_back_go`:

- Modify `internal/config/config.go`
  - Stop reading `CORS_ALLOW_HEADERS`, `CORS_ALLOW_CREDENTIALS`, and `CORS_MAX_AGE`.
  - Continue reading `CORS_ALLOW_ORIGINS`.
  - Remove `http://localhost:5174` and `http://127.0.0.1:5174` from `DefaultCORSConfig().AllowOrigins`.
  - Keep allowed methods, headers, exposed headers, credentials, and max age as code-owned defaults.
- Modify `internal/config/config_test.go`
  - Prove default origins are exactly `http://localhost:5173` and `http://127.0.0.1:5173`.
  - Prove `5174` is not a default origin.
  - Prove legacy CORS env keys are ignored while `CORS_ALLOW_ORIGINS` still works.
  - Prove code-owned headers still include `Accept-Language`, `Authorization`, `platform`, `device-id`, `X-Trace-Id`, and `X-Request-Id`.
- Modify `internal/middleware/cors_test.go`
  - Prove default CORS allows the code-owned frontend headers for `localhost:5173` preflight.
  - Prove default CORS rejects `localhost:5174` preflight.
- Modify `deploy/docker-first/admin-go.env.example`
  - Remove `CORS_ALLOW_HEADERS`, `CORS_ALLOW_CREDENTIALS`, and `CORS_MAX_AGE`.
  - Leave only `CORS_ALLOW_ORIGINS=https://zgm2003.cn` in the CORS section.
- Modify local ignored `deploy/docker-first/admin-go.env`
  - Remove the same three legacy CORS keys for local runtime verification.
  - Keep the current local origin list if the user needs frontend testing from `localhost:5173`.
- Modify `README.md`
  - Remove `5174` from local CORS examples.
  - Remove `CORS_ALLOW_CREDENTIALS=true` from examples.
  - Document that CORS headers, credentials, exposed headers, and max age are code-owned defaults.
- Modify `docs/architecture.md`
  - Remove `5174` from default CORS origins.
  - Replace the active CORS env list with only `CORS_ALLOW_ORIGINS`.
  - Document `CORS_ALLOW_HEADERS`, `CORS_ALLOW_CREDENTIALS`, and `CORS_MAX_AGE` as deprecated/ignored Docker-first env keys.

Root repo `E:\admin_go`:

- Create `docs/superpowers/plans/2026-05-21-cors-env-cleanup-implementation.md` for this plan.
- Inspect only, no planned edits unless matches appear during execution:
  - `docs/contracts/admin-api-v1.md`
  - `docs/status/current-status.md`
  - `docs/testing/smoke-matrix.md`

No frontend repo changes are planned.

---

### Task 1: Write RED tests for CORS defaults and ignored legacy env keys

**Files:**
- Modify: `E:\admin_go\admin_back_go\internal\config\config_test.go`
- Modify: `E:\admin_go\admin_back_go\internal\middleware\cors_test.go`

- [ ] **Step 1: Tighten default CORS origin assertions**

In `E:\admin_go\admin_back_go\internal\config\config_test.go`, inside `TestLoadUsesSafeDefaults`, replace the current `wantOrigins` block and CORS header assertions with:

```go
	wantOrigins := []string{
		"http://localhost:5173",
		"http://127.0.0.1:5173",
	}
	if !reflect.DeepEqual(cfg.CORS.AllowOrigins, wantOrigins) {
		t.Fatalf("unexpected default cors origins: %#v", cfg.CORS.AllowOrigins)
	}
	for _, origin := range []string{"http://localhost:5174", "http://127.0.0.1:5174"} {
		if containsString(cfg.CORS.AllowOrigins, origin) {
			t.Fatalf("default cors origins must not include %s: %#v", origin, cfg.CORS.AllowOrigins)
		}
	}
	for _, header := range []string{
		"Origin",
		"Content-Type",
		"Accept",
		"Accept-Language",
		"Authorization",
		"platform",
		"device-id",
		"X-Trace-Id",
		"X-Request-Id",
	} {
		if !containsString(cfg.CORS.AllowHeaders, header) {
			t.Fatalf("default cors headers must contain %s: %#v", header, cfg.CORS.AllowHeaders)
		}
	}
	if !containsString(cfg.CORS.ExposeHeaders, "X-Request-Id") {
		t.Fatalf("default cors expose headers must contain X-Request-Id: %#v", cfg.CORS.ExposeHeaders)
	}
	if !cfg.CORS.AllowCredentials {
		t.Fatalf("expected cors credentials to be allowed by default")
	}
	if cfg.CORS.MaxAge != 12*time.Hour {
		t.Fatalf("expected cors max age 12h, got %s", cfg.CORS.MaxAge)
	}
```

- [ ] **Step 2: Prove only `CORS_ALLOW_ORIGINS` is still env-owned**

In `TestLoadReadsEnvironmentOverrides`, keep the existing `CORS_ALLOW_ORIGINS` assignment and replace the three legacy CORS env assignments with deliberately different values:

```go
	t.Setenv("CORS_ALLOW_ORIGINS", "https://admin.example.com, http://localhost:5173")
	t.Setenv("CORS_ALLOW_HEADERS", "X-Legacy-CORS")
	t.Setenv("CORS_ALLOW_CREDENTIALS", "false")
	t.Setenv("CORS_MAX_AGE", "30m")
```

Replace the current CORS assertion block at the end of `TestLoadReadsEnvironmentOverrides` with:

```go
	if !reflect.DeepEqual(cfg.CORS.AllowOrigins, []string{"https://admin.example.com", "http://localhost:5173"}) {
		t.Fatalf("unexpected cors origins: %#v", cfg.CORS.AllowOrigins)
	}
	wantCORSDefaults := DefaultCORSConfig()
	if !reflect.DeepEqual(cfg.CORS.AllowHeaders, wantCORSDefaults.AllowHeaders) {
		t.Fatalf("cors allow headers env must be ignored, got %#v", cfg.CORS.AllowHeaders)
	}
	if !reflect.DeepEqual(cfg.CORS.ExposeHeaders, wantCORSDefaults.ExposeHeaders) {
		t.Fatalf("cors expose headers must stay default, got %#v", cfg.CORS.ExposeHeaders)
	}
	if cfg.CORS.AllowCredentials != wantCORSDefaults.AllowCredentials {
		t.Fatalf("cors credentials env must be ignored, got %v", cfg.CORS.AllowCredentials)
	}
	if cfg.CORS.MaxAge != wantCORSDefaults.MaxAge {
		t.Fatalf("cors max age env must be ignored, got %s", cfg.CORS.MaxAge)
	}
```

- [ ] **Step 3: Replace the narrow Accept-Language test with a full default-header test**

In `E:\admin_go\admin_back_go\internal\config\config_test.go`, replace `TestDefaultCORSAllowsAcceptLanguage` with:

```go
func TestDefaultCORSConfigUsesCodeOwnedPolicy(t *testing.T) {
	cfg := DefaultCORSConfig()

	if !reflect.DeepEqual(cfg.AllowOrigins, []string{"http://localhost:5173", "http://127.0.0.1:5173"}) {
		t.Fatalf("unexpected default cors origins: %#v", cfg.AllowOrigins)
	}
	for _, origin := range []string{"http://localhost:5174", "http://127.0.0.1:5174"} {
		if containsString(cfg.AllowOrigins, origin) {
			t.Fatalf("default cors origins must not include %s: %#v", origin, cfg.AllowOrigins)
		}
	}
	for _, header := range []string{
		"Origin",
		"Content-Type",
		"Accept",
		"Accept-Language",
		"Authorization",
		"platform",
		"device-id",
		"X-Trace-Id",
		"X-Request-Id",
	} {
		if !containsString(cfg.AllowHeaders, header) {
			t.Fatalf("DefaultCORSConfig must allow %s, got %#v", header, cfg.AllowHeaders)
		}
	}
	if !reflect.DeepEqual(cfg.ExposeHeaders, []string{"X-Request-Id"}) {
		t.Fatalf("unexpected default cors expose headers: %#v", cfg.ExposeHeaders)
	}
	if !cfg.AllowCredentials {
		t.Fatalf("expected default cors credentials to be true")
	}
	if cfg.MaxAge != 12*time.Hour {
		t.Fatalf("expected default cors max age 12h, got %s", cfg.MaxAge)
	}
}
```

- [ ] **Step 4: Add middleware coverage for `5173` allowed headers and `5174` rejection**

In `E:\admin_go\admin_back_go\internal\middleware\cors_test.go`, update `TestCORSAllowsConfiguredFrontendPreflight` to use the code-owned default config and include all frontend headers:

```go
func TestCORSAllowsConfiguredFrontendPreflight(t *testing.T) {
	gin.SetMode(gin.TestMode)

	handlerRan := false
	router := gin.New()
	router.Use(CORS(config.DefaultCORSConfig()))
	router.POST("/api/admin/v1/ping", func(c *gin.Context) {
		handlerRan = true
		c.String(http.StatusOK, "pong")
	})

	request := httptest.NewRequest(http.MethodOptions, "/api/admin/v1/ping", nil)
	request.Header.Set("Origin", "http://localhost:5173")
	request.Header.Set("Access-Control-Request-Method", http.MethodPost)
	request.Header.Set("Access-Control-Request-Headers", "Authorization, platform, device-id, X-Trace-Id, X-Request-Id, Accept-Language")
	recorder := httptest.NewRecorder()

	router.ServeHTTP(recorder, request)

	if handlerRan {
		t.Fatalf("preflight should not reach route handler")
	}
	if recorder.Code != http.StatusNoContent {
		t.Fatalf("expected status %d, got %d", http.StatusNoContent, recorder.Code)
	}
	if got := recorder.Header().Get("Access-Control-Allow-Origin"); got != "http://localhost:5173" {
		t.Fatalf("expected allowed origin, got %q", got)
	}
	if got := recorder.Header().Get("Access-Control-Allow-Credentials"); got != "true" {
		t.Fatalf("expected credentials true, got %q", got)
	}
	if got := recorder.Header().Get("Access-Control-Max-Age"); got != "43200" {
		t.Fatalf("expected max age 43200, got %q", got)
	}
	allowHeaders := recorder.Header().Get("Access-Control-Allow-Headers")
	for _, header := range []string{"Authorization", "platform", "device-id", "X-Trace-Id", "X-Request-Id", "Accept-Language"} {
		if !strings.Contains(strings.ToLower(allowHeaders), strings.ToLower(header)) {
			t.Fatalf("expected allow headers to contain %s, got %q", header, allowHeaders)
		}
	}
}
```

Add this test below it:

```go
func TestDefaultCORSRejects5174Preflight(t *testing.T) {
	gin.SetMode(gin.TestMode)

	router := gin.New()
	router.Use(CORS(config.DefaultCORSConfig()))
	router.POST("/api/admin/v1/ping", func(c *gin.Context) {
		c.String(http.StatusOK, "pong")
	})

	request := httptest.NewRequest(http.MethodOptions, "/api/admin/v1/ping", nil)
	request.Header.Set("Origin", "http://localhost:5174")
	request.Header.Set("Access-Control-Request-Method", http.MethodPost)
	recorder := httptest.NewRecorder()

	router.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusForbidden {
		t.Fatalf("expected status %d for non-default 5174 origin, got %d", http.StatusForbidden, recorder.Code)
	}
	if got := recorder.Header().Get("Access-Control-Allow-Origin"); got != "" {
		t.Fatalf("expected no allow-origin for 5174, got %q", got)
	}
}
```

- [ ] **Step 5: Run focused RED tests**

```powershell
cd E:\admin_go\admin_back_go
go test -count=1 ./internal/config ./internal/middleware
```

Expected: FAIL before implementation. Acceptable failure signatures:

```text
unexpected default cors origins: []string{"http://localhost:5173", "http://127.0.0.1:5173", "http://localhost:5174", "http://127.0.0.1:5174"}
```

or:

```text
cors allow headers env must be ignored, got []string{"X-Legacy-CORS"}
```

or:

```text
expected status 403 for non-default 5174 origin, got 204
```

Do not commit while tests are red.

---

### Task 2: Implement minimal CORS config cleanup

**Files:**
- Modify: `E:\admin_go\admin_back_go\internal\config\config.go`

- [ ] **Step 1: Stop reading legacy CORS env keys**

In `E:\admin_go\admin_back_go\internal\config\config.go`, replace the CORS load block:

```go
	corsConfig := DefaultCORSConfig()
	corsConfig.AllowOrigins = envCSV("CORS_ALLOW_ORIGINS", corsConfig.AllowOrigins)
	corsConfig.AllowHeaders = envCSV("CORS_ALLOW_HEADERS", corsConfig.AllowHeaders)
	corsConfig.AllowCredentials = envBool("CORS_ALLOW_CREDENTIALS", corsConfig.AllowCredentials)
	corsConfig.MaxAge = envDuration("CORS_MAX_AGE", corsConfig.MaxAge)
```

with:

```go
	corsConfig := DefaultCORSConfig()
	corsConfig.AllowOrigins = envCSV("CORS_ALLOW_ORIGINS", corsConfig.AllowOrigins)
```

- [ ] **Step 2: Remove 5174 from code defaults**

In `DefaultCORSConfig()`, replace:

```go
		AllowOrigins: []string{
			"http://localhost:5173",
			"http://127.0.0.1:5173",
			"http://localhost:5174",
			"http://127.0.0.1:5174",
		},
```

with:

```go
		AllowOrigins: []string{
			"http://localhost:5173",
			"http://127.0.0.1:5173",
		},
```

Keep this code-owned policy unchanged:

```go
		AllowMethods: []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"},
		AllowHeaders: []string{
			"Origin",
			"Content-Type",
			"Accept",
			"Accept-Language",
			"Authorization",
			"platform",
			"device-id",
			"X-Trace-Id",
			"X-Request-Id",
		},
		ExposeHeaders:    []string{"X-Request-Id"},
		AllowCredentials: true,
		MaxAge:           12 * time.Hour,
```

- [ ] **Step 3: Verify GREEN for focused backend tests**

```powershell
cd E:\admin_go\admin_back_go
gofmt -w internal/config/config.go internal/config/config_test.go internal/middleware/cors_test.go
go test -count=1 ./internal/config ./internal/middleware
```

Expected:

```text
ok  	admin_back_go/internal/config
ok  	admin_back_go/internal/middleware
```

- [ ] **Step 4: Commit backend code/test cleanup**

```powershell
cd E:\admin_go\admin_back_go
git add internal/config/config.go internal/config/config_test.go internal/middleware/cors_test.go
git commit -m "refactor: internalize cors runtime defaults"
```

---

### Task 3: Shorten Docker-first env and sync backend docs

**Files:**
- Modify: `E:\admin_go\admin_back_go\deploy\docker-first\admin-go.env.example`
- Modify: `E:\admin_go\admin_back_go\deploy\docker-first\admin-go.env` ignored local runtime file
- Modify: `E:\admin_go\admin_back_go\README.md`
- Modify: `E:\admin_go\admin_back_go\docs\architecture.md`

- [ ] **Step 1: Remove legacy CORS keys from Docker-first env example**

In `E:\admin_go\admin_back_go\deploy\docker-first\admin-go.env.example`, replace:

```env
CORS_ALLOW_ORIGINS=https://zgm2003.cn
CORS_ALLOW_HEADERS=Origin,Content-Type,Accept,Authorization,platform,device-id,X-Trace-Id,X-Request-Id
CORS_ALLOW_CREDENTIALS=true
CORS_MAX_AGE=12h
```

with:

```env
# Browser origins allowed to call the API and open WebSocket connections.
CORS_ALLOW_ORIGINS=https://zgm2003.cn
```

- [ ] **Step 2: Remove legacy CORS keys from local ignored Docker-first env**

In `E:\admin_go\admin_back_go\deploy\docker-first\admin-go.env`, remove these lines if present:

```env
CORS_ALLOW_HEADERS=Origin,Content-Type,Accept,Authorization,platform,device-id,X-Trace-Id,X-Request-Id
CORS_ALLOW_CREDENTIALS=true
CORS_MAX_AGE=12h
```

Keep local frontend testing origins as:

```env
CORS_ALLOW_ORIGINS=http://localhost:5173,http://127.0.0.1:5173,https://zgm2003.cn
```

This file is ignored and must not be added to git.

- [ ] **Step 3: Update README CORS examples and wording**

In `E:\admin_go\admin_back_go\README.md`, replace the local CORS example:

```env
CORS_ALLOW_ORIGINS=http://localhost:5173,http://127.0.0.1:5173,http://localhost:5174,http://127.0.0.1:5174
```

with:

```env
CORS_ALLOW_ORIGINS=http://localhost:5173,http://127.0.0.1:5173
```

Replace the online demo example:

```env
CORS_ALLOW_ORIGINS=https://zgm2003.cn
CORS_ALLOW_CREDENTIALS=true
```

with:

```env
CORS_ALLOW_ORIGINS=https://zgm2003.cn
```

Immediately after the online demo env block, add this paragraph:

```markdown
`CORS_ALLOW_ORIGINS` 是 Docker-first 唯一 CORS env。允许的请求头、暴露响应头、`AllowCredentials=true` 和预检缓存 `12h` 都是代码内置默认值；不要把 CORS policy 放进 `system_settings`。
```

In the later production env sample near the end of the README, replace:

```env
CORS_ALLOW_ORIGINS=https://zgm2003.cn
CORS_ALLOW_CREDENTIALS=true
```

with:

```env
CORS_ALLOW_ORIGINS=https://zgm2003.cn
```

- [ ] **Step 4: Update backend architecture CORS docs**

In `E:\admin_go\admin_back_go\docs\architecture.md`, replace the default origin list:

```text
http://localhost:5173
http://127.0.0.1:5173
http://localhost:5174
http://127.0.0.1:5174
```

with:

```text
http://localhost:5173
http://127.0.0.1:5173
```

Replace the CORS env list:

```text
CORS_ALLOW_ORIGINS
CORS_ALLOW_HEADERS
CORS_ALLOW_CREDENTIALS
CORS_MAX_AGE
```

with:

```text
CORS_ALLOW_ORIGINS
```

In the CORS rules block, keep the existing rules and add this line:

```text
CORS_ALLOW_HEADERS / CORS_ALLOW_CREDENTIALS / CORS_MAX_AGE 是旧 env，Docker-first 下已由代码默认值接管并忽略
```

In the Docker-first active env list, remove:

```text
CORS_ALLOW_HEADERS
CORS_ALLOW_CREDENTIALS
CORS_MAX_AGE
```

Keep:

```text
CORS_ALLOW_ORIGINS
```

- [ ] **Step 5: Verify docs no longer advertise removed CORS env keys as active config**

```powershell
cd E:\admin_go
rg -n "CORS_ALLOW_HEADERS|CORS_ALLOW_CREDENTIALS|CORS_MAX_AGE|localhost:5174|127\.0\.0\.1:5174" admin_back_go\deploy admin_back_go\README.md admin_back_go\docs docs\contracts docs\status docs\testing --glob '!**/*.map'
```

Expected output may include only deprecation/ignored wording in `admin_back_go\\docs\\architecture.md`. It must not show `localhost:5174`, `127.0.0.1:5174`, or active Docker-first env examples containing removed CORS keys.

- [ ] **Step 6: Run backend docs-adjacent focused tests**

```powershell
cd E:\admin_go\admin_back_go
go test -count=1 ./internal/config ./internal/middleware ./internal/server ./internal/bootstrap
```

Expected:

```text
ok  	admin_back_go/internal/config
ok  	admin_back_go/internal/middleware
ok  	admin_back_go/internal/server
ok  	admin_back_go/internal/bootstrap
```

- [ ] **Step 7: Commit deploy/docs cleanup**

```powershell
cd E:\admin_go\admin_back_go
git add deploy/docker-first/admin-go.env.example README.md docs/architecture.md
git commit -m "deploy: remove legacy cors policy env"
```

Do not add `deploy/docker-first/admin-go.env`.

---

### Task 4: Runtime verification and final governance checks

**Files:**
- Inspect: `E:\admin_go\admin_back_go\deploy\docker-first\docker-compose.yml`
- Inspect: `E:\admin_go\admin_back_go\deploy\docker-first\admin-go.env`
- No planned source changes in this task.

- [ ] **Step 1: Run Go tests and vet for touched backend packages**

```powershell
cd E:\admin_go\admin_back_go
go test -count=1 ./internal/config ./internal/middleware ./internal/server ./internal/bootstrap
go vet ./internal/config ./internal/middleware ./internal/server ./internal/bootstrap
```

Expected:

```text
ok  	admin_back_go/internal/config
ok  	admin_back_go/internal/middleware
ok  	admin_back_go/internal/server
ok  	admin_back_go/internal/bootstrap
```

`go vet` should exit `0` with no diagnostics.

- [ ] **Step 2: Validate Docker Compose config**

```powershell
cd E:\admin_go\admin_back_go\deploy\docker-first
docker compose config --quiet
```

Expected: command exits `0` with no output.

- [ ] **Step 3: Rebuild and restart backend services**

```powershell
cd E:\admin_go\admin_back_go\deploy\docker-first
docker compose up -d --build admin-api admin-worker
docker compose ps
```

Expected `docker compose ps` shows:

```text
admin-api      Up ... healthy
admin-worker   Up
```

- [ ] **Step 4: Verify health and readiness**

```powershell
curl.exe -sS http://127.0.0.1:8080/health
curl.exe -sS http://127.0.0.1:8080/ready
```

Expected decisive fields:

```json
{"data":{"status":"ok"}}
```

and `/ready` includes these checks as `up`:

```text
database
redis
token_redis
queue_redis
realtime
```

- [ ] **Step 5: Verify CORS preflight from the supported local origin**

```powershell
curl.exe -i -X OPTIONS "http://127.0.0.1:8080/api/v1/auth/login" `
  -H "Origin: http://localhost:5173" `
  -H "Access-Control-Request-Method: POST" `
  -H "Access-Control-Request-Headers: authorization,platform,device-id,x-request-id,accept-language"
```

Expected decisive headers:

```text
HTTP/1.1 204 No Content
Access-Control-Allow-Origin: http://localhost:5173
Access-Control-Allow-Credentials: true
Access-Control-Allow-Headers: ...Accept-Language...Authorization...platform...device-id...X-Request-Id...
Access-Control-Max-Age: 43200
```

- [ ] **Step 6: Verify CORS preflight rejects 5174 by default when env does not include it**

First check the active local env does not include `5174`:

```powershell
cd E:\admin_go\admin_back_go\deploy\docker-first
Select-String -LiteralPath .\admin-go.env -Pattern '5174'
```

Expected: no output.

Then run:

```powershell
curl.exe -i -X OPTIONS "http://127.0.0.1:8080/api/v1/auth/login" `
  -H "Origin: http://localhost:5174" `
  -H "Access-Control-Request-Method: POST"
```

Expected decisive result:

```text
HTTP/1.1 403 Forbidden
```

and no `Access-Control-Allow-Origin: http://localhost:5174` header.

- [ ] **Step 7: Verify removed env keys are not present in the running container**

```powershell
cd E:\admin_go\admin_back_go\deploy\docker-first
docker compose exec -T admin-api /bin/sh -c "env | grep -E '^(CORS_ALLOW_HEADERS|CORS_ALLOW_CREDENTIALS|CORS_MAX_AGE)=' || true"
```

Expected: no output.

- [ ] **Step 8: Run root governance checks**

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected:

```text
PASS: no blocking governance violations found.
```

- [ ] **Step 9: Capture final git status**

```powershell
cd E:\admin_go
git status --short --branch
cd E:\admin_go\admin_back_go
git status --short --branch
cd E:\admin_go\admin_front_ts
git status --short --branch
```

Expected:

```text
root: ahead with spec/plan docs only, clean working tree
admin_back_go: ahead with CORS cleanup commits, clean working tree except ignored admin-go.env not shown
admin_front_ts: clean
```

Do not push unless the user explicitly says `push吧`.

---

## Self-Review Checklist

- Spec coverage: this plan keeps `CORS_ALLOW_ORIGINS`, internalizes headers/credentials/max age, removes `5174`, avoids `system_settings`, keeps WebSocket origin sharing through `cfg.CORS.AllowOrigins`, updates Docker-first env/docs, and includes unit/runtime/governance verification.
- Placeholder scan: no implementation step uses red-flag placeholders or vague follow-up language.
- Type consistency: all referenced Go symbols already exist today except no new symbols are introduced; tests use existing `config.DefaultCORSConfig`, `containsString`, `config.CORSConfig`, and `middleware.CORS`.
- Scope control: no SQL, frontend, auth/session, Nginx/Baota, or realtime protocol changes are included.
