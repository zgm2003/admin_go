# Verify Code Env Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove verify-code runtime policy leftovers from Docker-first env and make the Redis namespace code-owned while keeping `system_settings.auth.verify_code.ttl_minutes` as the only TTL policy source.

**Architecture:** TTL remains DB-backed through the existing `VerifyCodePolicyProvider`; no new table or migration is needed. The Redis namespace becomes an auth-module constant used by both auth send/verify flows and user account-security verification, so bootstrap no longer wires verify-code prefix from config. Docker-first env files are shortened and tests guard against reintroducing `VERIFY_CODE_TTL` / `VERIFY_CODE_REDIS_PREFIX`.

**Tech Stack:** Go 1.x, Webman-style Go admin backend modules, Redis-backed code store, MySQL-backed `system_settings`, PowerShell verification scripts.

---

## File Structure

- Modify: `admin_back_go/internal/config/config.go`
  - Remove `Config.VerifyCode`, `VerifyCodeConfig`, and `VERIFY_CODE_REDIS_PREFIX` env loading.
- Modify: `admin_back_go/internal/config/config_test.go`
  - Add tests proving verify-code runtime policy is not part of env/config.
  - Extend Docker-first env guards to cover both `admin-go.env` and `admin-go.env.example`.
- Modify: `admin_back_go/internal/module/auth/code_store.go`
  - Keep `auth:verify_code:` as a code-owned namespace.
  - Change `VerifyCodeCacheKey` so callers do not pass a prefix.
- Modify: `admin_back_go/internal/module/auth/service.go`
  - Remove `VerifyCodeOptions.RedisPrefix`.
  - Build verify-code keys with the code-owned namespace.
- Modify: `admin_back_go/internal/module/auth/service_test.go`
  - Update key-helper call sites and option literals after removing `RedisPrefix`.
- Modify: `admin_back_go/internal/module/user/service.go`
  - Remove user-owned verify-code prefix state.
  - Make `WithVerifyCodeStore` accept only the store.
- Modify: `admin_back_go/internal/module/user/service_test.go`
  - Update `WithVerifyCodeStore` call sites.
- Modify: `admin_back_go/internal/bootstrap/app.go`
  - Stop injecting verify-code prefix from `cfg.VerifyCode`.
- Modify: `admin_back_go/deploy/docker-first/admin-go.env`
  - Remove `VERIFY_CODE_TTL` and `VERIFY_CODE_REDIS_PREFIX`.
- Modify: `admin_back_go/deploy/docker-first/admin-go.env.example`
  - Remove `VERIFY_CODE_TTL` and `VERIFY_CODE_REDIS_PREFIX`.
- Modify: `docs/status/current-status.md`
  - Clarify that verify-code TTL is system-setting-owned and Redis namespace is code-owned.
- Modify if matches exist: `docs/deployment/*.md`
  - Remove stale references to `VERIFY_CODE_TTL` / `VERIFY_CODE_REDIS_PREFIX`.

---

### Task 1: Add env/config regression tests

**Files:**
- Modify: `admin_back_go/internal/config/config_test.go`

- [ ] **Step 1: Add failing tests and a reusable env reader**

In `admin_back_go/internal/config/config_test.go`, replace `TestEnvExampleDoesNotDocumentCaptchaRuntimePolicy` and `readEnvExample` with the following code, keeping nearby tests unchanged:

```go
func TestDockerFirstEnvDoesNotDocumentCaptchaRuntimePolicy(t *testing.T) {
	for _, fileName := range []string{"admin-go.env", "admin-go.env.example"} {
		values := readDockerFirstEnv(t, fileName)

		for _, key := range []string{"CAPTCHA_TTL", "CAPTCHA_REDIS_PREFIX", "CAPTCHA_SLIDE_PADDING"} {
			if _, ok := values[key]; ok {
				t.Fatalf("%s should move to system_settings or code constant, not Docker env file %s", key, fileName)
			}
		}
	}
}

func TestDockerFirstEnvDoesNotDocumentVerifyCodeRuntimePolicy(t *testing.T) {
	for _, fileName := range []string{"admin-go.env", "admin-go.env.example"} {
		values := readDockerFirstEnv(t, fileName)

		for _, key := range []string{"VERIFY_CODE_TTL", "VERIFY_CODE_REDIS_PREFIX"} {
			if _, ok := values[key]; ok {
				t.Fatalf("%s should move to system_settings or code constant, not Docker env file %s", key, fileName)
			}
		}
	}
}

func TestConfigDoesNotExposeVerifyCodeRuntimePolicy(t *testing.T) {
	if _, ok := reflect.TypeOf(Config{}).FieldByName("VerifyCode"); ok {
		t.Fatalf("verify-code runtime policy should not be loaded from env config")
	}
}
```

Replace the existing `readEnvExample` helper with:

```go
func readEnvExample(t *testing.T) map[string]string {
	t.Helper()
	return readDockerFirstEnv(t, "admin-go.env.example")
}

func readDockerFirstEnv(t *testing.T, fileName string) map[string]string {
	t.Helper()
	content, err := os.ReadFile(filepath.Join("..", "..", "deploy", "docker-first", fileName))
	if err != nil {
		t.Fatalf("read deploy/docker-first/%s: %v", fileName, err)
	}

	values := make(map[string]string)
	for _, line := range strings.Split(string(content), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		key, value, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}
		values[strings.TrimSpace(key)] = strings.TrimSpace(value)
	}
	return values
}
```

- [ ] **Step 2: Run config tests to verify failure**

Run from `E:/admin_go/admin_back_go`:

```powershell
go test -count=1 ./internal/config -run "TestDockerFirstEnvDoesNotDocumentVerifyCodeRuntimePolicy|TestConfigDoesNotExposeVerifyCodeRuntimePolicy"
```

Expected now:

```text
FAIL
VERIFY_CODE_TTL should move to system_settings or code constant
```

or:

```text
FAIL
verify-code runtime policy should not be loaded from env config
```

Both failures are acceptable at this stage because env/config cleanup has not been implemented.

- [ ] **Step 3: Do not commit yet**

Keep this failing-test checkpoint local until Tasks 2-4 make the backend compile and pass.

---

### Task 2: Remove verify-code keys from Docker-first env files

**Files:**
- Modify: `admin_back_go/deploy/docker-first/admin-go.env`
- Modify: `admin_back_go/deploy/docker-first/admin-go.env.example`

- [ ] **Step 1: Delete stale verify-code env lines**

Remove these exact lines from both files:

```env
VERIFY_CODE_TTL=5m
VERIFY_CODE_REDIS_PREFIX=auth:verify_code:
```

Do not add replacement env keys.

- [ ] **Step 2: Re-run the env regression test**

Run from `E:/admin_go/admin_back_go`:

```powershell
go test -count=1 ./internal/config -run "TestDockerFirstEnvDoesNotDocumentVerifyCodeRuntimePolicy"
```

Expected:

```text
ok  	admin_back_go/internal/config
```

- [ ] **Step 3: Confirm the env files no longer contain the keys**

Run from `E:/admin_go`:

```powershell
rg -n "VERIFY_CODE_TTL|VERIFY_CODE_REDIS_PREFIX" admin_back_go/deploy/docker-first/admin-go.env admin_back_go/deploy/docker-first/admin-go.env.example
```

Expected:

```text
```

No output.

---

### Task 3: Remove verify-code runtime policy from config

**Files:**
- Modify: `admin_back_go/internal/config/config.go`
- Modify: `admin_back_go/internal/config/config_test.go`

- [ ] **Step 1: Remove config shape**

In `admin_back_go/internal/config/config.go`, remove the `VerifyCode` field from `Config`:

```go
type Config struct {
	App         AppConfig
	HTTP        HTTPConfig
	Logging     LoggingConfig
	MySQL       MySQLConfig
	Redis       RedisConfig
	Token       TokenConfig
	Queue       QueueConfig
	Realtime    RealtimeConfig
	Scheduler   SchedulerConfig
	Payment     PaymentConfig
	UploadToken UploadTokenConfig
	AI          AIConfig
	CORS        CORSConfig
}
```

Delete this type:

```go
type VerifyCodeConfig struct {
	RedisPrefix string
}
```

Delete this block from `Load()`:

```go
VerifyCode: VerifyCodeConfig{
	RedisPrefix: envString("VERIFY_CODE_REDIS_PREFIX", "auth:verify_code:"),
},
```

- [ ] **Step 2: Run config tests**

Run from `E:/admin_go/admin_back_go`:

```powershell
go test -count=1 ./internal/config
```

Expected:

```text
ok  	admin_back_go/internal/config
```

- [ ] **Step 3: Confirm config no longer reads verify-code env**

Run from `E:/admin_go`:

```powershell
rg -n "VERIFY_CODE|VerifyCodeConfig|cfg\\.VerifyCode" admin_back_go/internal/config admin_back_go/internal/bootstrap
```

Expected at this point:

```text
admin_back_go/internal/bootstrap/app.go:... cfg.VerifyCode.RedisPrefix
```

The remaining bootstrap references will be removed in Task 5.

---

### Task 4: Make verify-code cache keys code-owned in auth/user modules

**Files:**
- Modify: `admin_back_go/internal/module/auth/code_store.go`
- Modify: `admin_back_go/internal/module/auth/service.go`
- Modify: `admin_back_go/internal/module/auth/service_test.go`
- Modify: `admin_back_go/internal/module/user/service.go`
- Modify: `admin_back_go/internal/module/user/service_test.go`

- [ ] **Step 1: Add failing auth key test**

Append this test to `admin_back_go/internal/module/auth/service_test.go`:

```go
func TestVerifyCodeCacheKeyUsesCodeOwnedNamespace(t *testing.T) {
	got := VerifyCodeCacheKey("email", VerifyCodeSceneLogin, "user@example.com")
	want := "auth:verify_code:email:login:b58996c504c5638798eb6b511e6f49af"
	if got != want {
		t.Fatalf("expected code-owned verify-code cache key %q, got %q", want, got)
	}
}
```

- [ ] **Step 2: Run auth tests to verify compile failure**

Run from `E:/admin_go/admin_back_go`:

```powershell
go test -count=1 ./internal/module/auth -run TestVerifyCodeCacheKeyUsesCodeOwnedNamespace
```

Expected now:

```text
FAIL
not enough arguments in call to VerifyCodeCacheKey
```

- [ ] **Step 3: Change auth cache key helper**

In `admin_back_go/internal/module/auth/code_store.go`, keep the namespace constant unexported and change the public helper to no longer accept a prefix:

```go
const defaultVerifyCodeRedisPrefix = "auth:verify_code:"
```

```go
func VerifyCodeCacheKey(accountType string, scene string, account string) string {
	return defaultVerifyCodeRedisPrefix + verifyCodeKey(accountType, scene, account)
}
```

- [ ] **Step 4: Remove prefix from auth service options**

In `admin_back_go/internal/module/auth/service.go`, change `VerifyCodeOptions` to:

```go
type VerifyCodeOptions struct {
	TTL           time.Duration
	PhoneCode     string
	CodeGenerator func() (string, error)
}
```

Change the default options in `NewService` to:

```go
verifyCodeOptions: VerifyCodeOptions{
	TTL:       defaultVerifyCodeTTL,
	PhoneCode: defaultPhoneCode,
},
```

Change `verifyCodeCacheKey` to:

```go
func (s *Service) verifyCodeCacheKey(accountType string, scene string, account string) string {
	return VerifyCodeCacheKey(accountType, scene, account)
}
```

Remove this prefix-normalization block from `normalizeVerifyCodeOptions`:

```go
options.RedisPrefix = strings.TrimSpace(options.RedisPrefix)
if options.RedisPrefix == "" {
	options.RedisPrefix = defaultVerifyCodeRedisPrefix
}
```

- [ ] **Step 5: Remove prefix from user service**

In `admin_back_go/internal/module/user/service.go`, delete:

```go
const defaultVerifyCodePrefix = "auth:verify_code:"
```

Remove `verifyCodePrefix string` from `Service`.

Remove this field initialization:

```go
verifyCodePrefix:  defaultVerifyCodePrefix,
```

Remove this normalization block:

```go
service.verifyCodePrefix = strings.TrimSpace(service.verifyCodePrefix)
if service.verifyCodePrefix == "" {
	service.verifyCodePrefix = defaultVerifyCodePrefix
}
```

Change `WithVerifyCodeStore` to:

```go
func WithVerifyCodeStore(store VerifyCodeStore) Option {
	return func(s *Service) {
		s.verifyCodeStore = store
	}
}
```

Change `verifyCode` key creation to:

```go
key := auth.VerifyCodeCacheKey(accountType, scene, account)
```

- [ ] **Step 6: Update tests for new signatures**

In `admin_back_go/internal/module/auth/service_test.go`, replace calls like:

```go
VerifyCodeCacheKey("auth:verify_code:", accountType, scene, account)
```

with:

```go
VerifyCodeCacheKey(accountType, scene, account)
```

If no direct helper calls exist beyond the new test, no replacement is needed.

In `admin_back_go/internal/module/user/service_test.go`, replace calls like:

```go
WithVerifyCodeStore(store, "auth:verify_code:")
```

with:

```go
WithVerifyCodeStore(store)
```

- [ ] **Step 7: Run auth and user tests**

Run from `E:/admin_go/admin_back_go`:

```powershell
go test -count=1 ./internal/module/auth ./internal/module/user
```

Expected:

```text
ok  	admin_back_go/internal/module/auth
ok  	admin_back_go/internal/module/user
```

---

### Task 5: Clean bootstrap wiring

**Files:**
- Modify: `admin_back_go/internal/bootstrap/app.go`

- [ ] **Step 1: Remove auth verify-code prefix injection**

In `admin_back_go/internal/bootstrap/app.go`, delete this option from `auth.NewService(...)`:

```go
auth.WithVerifyCodeOptions(auth.VerifyCodeOptions{
	RedisPrefix: cfg.VerifyCode.RedisPrefix,
}),
```

Do not replace it; auth service already has code-owned defaults and DB-backed TTL policy.

- [ ] **Step 2: Remove user verify-code prefix injection**

Change:

```go
user.WithVerifyCodeStore(auth.NewRedisCodeStore(resources.Redis), cfg.VerifyCode.RedisPrefix),
```

to:

```go
user.WithVerifyCodeStore(auth.NewRedisCodeStore(resources.Redis)),
```

- [ ] **Step 3: Run bootstrap tests**

Run from `E:/admin_go/admin_back_go`:

```powershell
go test -count=1 ./internal/bootstrap
```

Expected:

```text
ok  	admin_back_go/internal/bootstrap
```

- [ ] **Step 4: Confirm no config/bootstrap verify-code env references remain**

Run from `E:/admin_go`:

```powershell
rg -n "VERIFY_CODE|VerifyCodeConfig|cfg\\.VerifyCode" admin_back_go/internal/config admin_back_go/internal/bootstrap
```

Expected:

```text
```

No output.

---

### Task 6: Update docs and remove stale references

**Files:**
- Modify: `docs/status/current-status.md`
- Modify if needed: `docs/deployment/*.md`

- [ ] **Step 1: Update current status wording**

In `docs/status/current-status.md`, update the `mail / Tencent SES` row phrase that currently says:

```text
reads verification-code TTL from `system_settings.auth.verify_code.ttl_minutes` instead of a legacy env TTL
```

to:

```text
reads verification-code TTL from `system_settings.auth.verify_code.ttl_minutes` instead of env, while Redis namespace `auth:verify_code:` is code-owned
```

If the SMS row has no verify-code namespace note, append the same concise namespace fact after `shared system_settings.auth.verify_code.ttl_minutes`.

- [ ] **Step 2: Search deployment docs**

Run from `E:/admin_go`:

```powershell
rg -n "VERIFY_CODE_TTL|VERIFY_CODE_REDIS_PREFIX" docs/deployment admin_back_go/README.md
```

Expected if no stale docs exist:

```text
```

No output.

If matches exist, replace them with:

```text
验证码有效期通过后台系统设置 `auth.verify_code.ttl_minutes` 调整；Redis namespace `auth:verify_code:` 由代码内置，不通过 env 配置。
```

- [ ] **Step 3: Search active code and deploy assets**

Run from `E:/admin_go`:

```powershell
rg -n "VERIFY_CODE_TTL|VERIFY_CODE_REDIS_PREFIX" admin_back_go/internal admin_back_go/deploy docs/deployment docs/status/current-status.md
```

Expected:

```text
```

No output.

---

### Task 7: Focused verification

**Files:**
- No source edits expected.

- [ ] **Step 1: Run focused backend tests**

Run from `E:/admin_go/admin_back_go`:

```powershell
go test -count=1 ./internal/module/auth ./internal/module/user ./internal/bootstrap ./internal/config
```

Expected:

```text
ok  	admin_back_go/internal/module/auth
ok  	admin_back_go/internal/module/user
ok  	admin_back_go/internal/bootstrap
ok  	admin_back_go/internal/config
```

- [ ] **Step 2: Run mail/sms regression tests**

Run from `E:/admin_go/admin_back_go`:

```powershell
go test -count=1 ./internal/module/mail ./internal/module/sms
```

Expected:

```text
ok  	admin_back_go/internal/module/mail
ok  	admin_back_go/internal/module/sms
```

- [ ] **Step 3: Run formatting**

Run from `E:/admin_go/admin_back_go`:

```powershell
gofmt -w internal/config/config.go internal/config/config_test.go internal/module/auth/code_store.go internal/module/auth/service.go internal/module/auth/service_test.go internal/module/user/service.go internal/module/user/service_test.go internal/bootstrap/app.go
```

Expected:

```text
```

No output.

- [ ] **Step 4: Run whitespace check**

Run from `E:/admin_go`:

```powershell
git diff --check
```

Expected:

```text
```

No output.

- [ ] **Step 5: Run governance checker**

Run from `E:/admin_go`:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected:

```text
PASS: no blocking governance violations found.
```

---

### Task 8: Review and commit

**Files:**
- Stage all files changed by this plan.

- [ ] **Step 1: Review changed files**

Run from `E:/admin_go`:

```powershell
git status --short
git diff --stat
git diff -- admin_back_go/internal/config/config.go admin_back_go/internal/bootstrap/app.go admin_back_go/internal/module/auth/code_store.go admin_back_go/internal/module/auth/service.go admin_back_go/internal/module/user/service.go
```

Expected:

```text
```

Diff shows only verify-code env cleanup, prefix internalization, tests, env files, and docs.

- [ ] **Step 2: Commit backend changes**

Run from `E:/admin_go/admin_back_go`:

```powershell
git status --short
git add internal/config/config.go internal/config/config_test.go internal/module/auth/code_store.go internal/module/auth/service.go internal/module/auth/service_test.go internal/module/user/service.go internal/module/user/service_test.go internal/bootstrap/app.go deploy/docker-first/admin-go.env deploy/docker-first/admin-go.env.example
git commit -m "refactor: internalize verify code redis namespace"
```

Expected:

```text
[master <hash>] refactor: internalize verify code redis namespace
```

- [ ] **Step 3: Commit root docs**

Run from `E:/admin_go`:

```powershell
git status --short
git add docs/superpowers/specs/2026-05-20-verify-code-env-cleanup-design.md docs/superpowers/plans/2026-05-20-verify-code-env-cleanup-plan.md docs/status/current-status.md
git commit -m "docs: plan verify code env cleanup"
```

Expected:

```text
[master <hash>] docs: plan verify code env cleanup
```

Do not push until the user explicitly asks for push or the final verification path includes push.
