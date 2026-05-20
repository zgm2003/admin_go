# Token/session Env Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove `TOKEN_REDIS_PREFIX`, `TOKEN_SESSION_CACHE_TTL`, and `TOKEN_SINGLE_SESSION_POINTER_TTL` from Docker-first env while preserving the current `token:` / `30m` / `720h` runtime behavior as code-owned defaults.

**Architecture:** Keep deployment secrets/topology in env and keep session cache implementation policy inside Go code. `APP_SECRET` and `TOKEN_REDIS_DB` stay env-owned; Redis key namespace and cache TTL defaults move to `internal/config` constants plus normalization used by `config.Load()` and `session.NewAuthenticator()`. Business authentication policy remains in `auth_platforms`, not `system_settings`.

**Tech Stack:** Go 1.x, Gin modular backend, Redis cache-aside session store, MySQL `user_sessions` / `auth_platforms`, Docker Compose, PowerShell smoke scripts, Markdown docs.

---

## Scope Check

This plan covers one narrow subsystem: token/session Redis env cleanup. It does not change login UI, JWT claim shape, refresh-token rotation, user session APIs, RBAC, `auth_platforms` schema/UI, `system_settings`, frontend code, or Docker service topology.

## File Map

Backend repo `E:\admin_go\admin_back_go`:

- Modify `internal/config/config.go`
  - Add token/session code-owned default constants.
  - Add `NormalizeTokenConfig`.
  - Stop reading `TOKEN_REDIS_PREFIX`, `TOKEN_SESSION_CACHE_TTL`, and `TOKEN_SINGLE_SESSION_POINTER_TTL`.
  - Continue reading `TOKEN_REDIS_DB` from env with default `2`.
- Modify `internal/config/config_test.go`
  - Prove token/session defaults are `token:` / `30m` / `720h`.
  - Prove old token Redis/cache env keys are ignored.
  - Prove Docker-first env files only keep `APP_SECRET` and `TOKEN_REDIS_DB` for token/session.
- Modify `internal/module/session/service.go`
  - Normalize `config.TokenConfig` through `config.NormalizeTokenConfig` in `NewAuthenticator`.
  - Remove local literal fallback values from the authenticator constructor.
- Modify `internal/module/session/service_test.go`
  - Prove `NewAuthenticator` uses code-owned defaults for blank/invalid token cache policy.
- Modify `deploy/docker-first/admin-go.env.example`
  - Remove `TOKEN_REDIS_PREFIX`, `TOKEN_SESSION_CACHE_TTL`, `TOKEN_SINGLE_SESSION_POINTER_TTL`.
- Modify local ignored `deploy/docker-first/admin-go.env`
  - Remove the same three keys for local Docker-first testing. This file is not committed.
- Modify `docs/architecture.md`
  - Remove old token Redis/cache env names from the active env list.
  - Document `token:` / `30m` / `720h` as code-owned defaults.
- Modify `README.md`
  - Keep `APP_SECRET` / `TOKEN_REDIS_DB` wording.
  - Clarify token Redis prefix/cache TTL are code-owned defaults, not user-facing env.

Root repo `E:\admin_go`:

- Modify `docs/contracts/admin-api-v1.md`
  - Replace old `.env` list with `APP_SECRET` + `TOKEN_REDIS_DB` + code-owned token Redis/cache defaults.
- Modify `docs/status/current-status.md` only if active auth/session status text mentions removed env keys.
- Modify `docs/testing/smoke-matrix.md` only if active smoke text mentions removed env keys.

No SQL migration. No `system_settings` row. No frontend changes.

---

### Task 1: Make `internal/config` own token/session defaults and ignore old env

**Files:**
- Modify: `E:\admin_go\admin_back_go\internal\config\config.go`
- Modify: `E:\admin_go\admin_back_go\internal\config\config_test.go`

- [ ] **Step 1: Write failing config tests**

In `internal/config/config_test.go`, update `TestLoadUsesSafeDefaults` token assertions to use named defaults:

```go
	if cfg.Token.RedisPrefix != DefaultTokenRedisPrefix {
		t.Fatalf("expected token redis prefix %q, got %q", DefaultTokenRedisPrefix, cfg.Token.RedisPrefix)
	}
	if cfg.Token.SessionCacheTTL != DefaultTokenSessionCacheTTL {
		t.Fatalf("expected token session cache ttl %s, got %s", DefaultTokenSessionCacheTTL, cfg.Token.SessionCacheTTL)
	}
	if cfg.Token.SingleSessionPointerTTL != DefaultTokenSingleSessionPointerTTL {
		t.Fatalf("expected single session pointer ttl %s, got %s", DefaultTokenSingleSessionPointerTTL, cfg.Token.SingleSessionPointerTTL)
	}
	if cfg.Token.RedisDB != DefaultTokenRedisDB {
		t.Fatalf("expected token redis db %d, got %d", DefaultTokenRedisDB, cfg.Token.RedisDB)
	}
```

In `TestLoadReadsEnvironmentOverrides`, keep legacy env assignments but make the values different from defaults so ignored behavior is proven:

```go
	t.Setenv("TOKEN_REDIS_PREFIX", "token-test:")
	t.Setenv("TOKEN_SESSION_CACHE_TTL", "45m")
	t.Setenv("TOKEN_SINGLE_SESSION_POINTER_TTL", "111h")
	t.Setenv("TOKEN_REDIS_DB", "5")
```

Replace the current token assertion block with:

```go
	if cfg.Token.RedisPrefix != DefaultTokenRedisPrefix ||
		cfg.Token.SessionCacheTTL != DefaultTokenSessionCacheTTL ||
		cfg.Token.SingleSessionPointerTTL != DefaultTokenSingleSessionPointerTTL {
		t.Fatalf("token Redis/cache policy env must be ignored, got %#v", cfg.Token)
	}
	if cfg.Token.RedisDB != 5 {
		t.Fatalf("expected token redis db 5, got %d", cfg.Token.RedisDB)
	}
```

Add these tests near the scheduler/realtime normalization tests:

```go
func TestNormalizeTokenConfigAppliesCodeOwnedDefaults(t *testing.T) {
	cfg := NormalizeTokenConfig(TokenConfig{RedisPrefix: "   "})

	if cfg.RedisPrefix != DefaultTokenRedisPrefix {
		t.Fatalf("expected default token redis prefix %q, got %q", DefaultTokenRedisPrefix, cfg.RedisPrefix)
	}
	if cfg.SessionCacheTTL != DefaultTokenSessionCacheTTL {
		t.Fatalf("expected default token session cache ttl %s, got %s", DefaultTokenSessionCacheTTL, cfg.SessionCacheTTL)
	}
	if cfg.SingleSessionPointerTTL != DefaultTokenSingleSessionPointerTTL {
		t.Fatalf("expected default single session pointer ttl %s, got %s", DefaultTokenSingleSessionPointerTTL, cfg.SingleSessionPointerTTL)
	}
}

func TestNormalizeTokenConfigPreservesExplicitValues(t *testing.T) {
	cfg := NormalizeTokenConfig(TokenConfig{
		RedisPrefix:             " custom-token: ",
		SessionCacheTTL:         45 * time.Minute,
		SingleSessionPointerTTL: 48 * time.Hour,
		RedisDB:                 5,
	})

	if cfg.RedisPrefix != "custom-token:" {
		t.Fatalf("expected trimmed token redis prefix custom-token:, got %q", cfg.RedisPrefix)
	}
	if cfg.SessionCacheTTL != 45*time.Minute {
		t.Fatalf("expected explicit token session cache ttl 45m, got %s", cfg.SessionCacheTTL)
	}
	if cfg.SingleSessionPointerTTL != 48*time.Hour {
		t.Fatalf("expected explicit single session pointer ttl 48h, got %s", cfg.SingleSessionPointerTTL)
	}
	if cfg.RedisDB != 5 {
		t.Fatalf("expected explicit token redis db 5, got %d", cfg.RedisDB)
	}
}

func TestNormalizeTokenConfigDefaultsNonPositiveDurations(t *testing.T) {
	cfg := NormalizeTokenConfig(TokenConfig{
		RedisPrefix:             "token:",
		SessionCacheTTL:         -time.Second,
		SingleSessionPointerTTL: -time.Hour,
	})

	if cfg.SessionCacheTTL != DefaultTokenSessionCacheTTL {
		t.Fatalf("expected negative session cache ttl to default to %s, got %s", DefaultTokenSessionCacheTTL, cfg.SessionCacheTTL)
	}
	if cfg.SingleSessionPointerTTL != DefaultTokenSingleSessionPointerTTL {
		t.Fatalf("expected negative pointer ttl to default to %s, got %s", DefaultTokenSingleSessionPointerTTL, cfg.SingleSessionPointerTTL)
	}
}
```

- [ ] **Step 2: Run the focused RED test**

```powershell
cd E:\admin_go\admin_back_go
go test -count=1 ./internal/config
```

Expected: FAIL. Acceptable failure signatures include undefined names such as `DefaultTokenRedisPrefix` / `NormalizeTokenConfig`, or the old env values being returned for token Redis/cache policy.

- [ ] **Step 3: Implement token defaults and normalization**

In `internal/config/config.go`, directly after `type TokenConfig struct { ... }`, add:

```go
const (
	DefaultTokenRedisPrefix             = "token:"
	DefaultTokenSessionCacheTTL         = 30 * time.Minute
	DefaultTokenSingleSessionPointerTTL = 30 * 24 * time.Hour
	DefaultTokenRedisDB                 = 2
)

func NormalizeTokenConfig(cfg TokenConfig) TokenConfig {
	cfg.RedisPrefix = strings.TrimSpace(cfg.RedisPrefix)
	if cfg.RedisPrefix == "" {
		cfg.RedisPrefix = DefaultTokenRedisPrefix
	}
	if cfg.SessionCacheTTL <= 0 {
		cfg.SessionCacheTTL = DefaultTokenSessionCacheTTL
	}
	if cfg.SingleSessionPointerTTL <= 0 {
		cfg.SingleSessionPointerTTL = DefaultTokenSingleSessionPointerTTL
	}
	return cfg
}
```

In `Load()`, replace the current token block:

```go
		Token: TokenConfig{
			RedisPrefix:             envString("TOKEN_REDIS_PREFIX", "token:"),
			SessionCacheTTL:         envDuration("TOKEN_SESSION_CACHE_TTL", 30*time.Minute),
			SingleSessionPointerTTL: envDuration("TOKEN_SINGLE_SESSION_POINTER_TTL", 30*24*time.Hour),
			RedisDB:                 envInt("TOKEN_REDIS_DB", 2),
		},
```

with:

```go
		Token: NormalizeTokenConfig(TokenConfig{
			RedisDB: envInt("TOKEN_REDIS_DB", DefaultTokenRedisDB),
		}),
```

- [ ] **Step 4: Verify GREEN for config**

```powershell
cd E:\admin_go\admin_back_go
gofmt -w internal/config/config.go internal/config/config_test.go
go test -count=1 ./internal/config
```

Expected: `ok admin_back_go/internal/config`.

- [ ] **Step 5: Commit backend config change**

```powershell
cd E:\admin_go\admin_back_go
git add internal/config/config.go internal/config/config_test.go
git commit -m "refactor: internalize token session defaults"
```

---

### Task 2: Normalize token config at the session authenticator boundary

**Files:**
- Modify: `E:\admin_go\admin_back_go\internal\module\session\service.go`
- Modify: `E:\admin_go\admin_back_go\internal\module\session\service_test.go`

- [ ] **Step 1: Write failing authenticator normalization test**

Add this test near the top-level authenticator constructor tests in `internal/module/session/service_test.go`:

```go
func TestNewAuthenticatorNormalizesTokenConfigDefaults(t *testing.T) {
	auth := NewAuthenticator(AuthenticatorDeps{
		Config: config.TokenConfig{
			RedisPrefix:             "   ",
			SessionCacheTTL:         -time.Second,
			SingleSessionPointerTTL: -time.Hour,
		},
	})

	if auth.cfg.RedisPrefix != config.DefaultTokenRedisPrefix {
		t.Fatalf("expected default redis prefix %q, got %q", config.DefaultTokenRedisPrefix, auth.cfg.RedisPrefix)
	}
	if auth.cfg.SessionCacheTTL != config.DefaultTokenSessionCacheTTL {
		t.Fatalf("expected default session cache ttl %s, got %s", config.DefaultTokenSessionCacheTTL, auth.cfg.SessionCacheTTL)
	}
	if auth.cfg.SingleSessionPointerTTL != config.DefaultTokenSingleSessionPointerTTL {
		t.Fatalf("expected default pointer ttl %s, got %s", config.DefaultTokenSingleSessionPointerTTL, auth.cfg.SingleSessionPointerTTL)
	}
}
```

- [ ] **Step 2: Run the focused RED test**

```powershell
cd E:\admin_go\admin_back_go
go test -count=1 ./internal/module/session -run TestNewAuthenticatorNormalizesTokenConfigDefaults
```

Expected: FAIL because `NewAuthenticator` currently preserves whitespace `RedisPrefix` and negative TTL values.

- [ ] **Step 3: Implement authenticator normalization**

In `internal/module/session/service.go`, replace the local fallback block in `NewAuthenticator`:

```go
	if deps.Config.RedisPrefix == "" {
		deps.Config.RedisPrefix = "token:"
	}
	if deps.Config.SessionCacheTTL == 0 {
		deps.Config.SessionCacheTTL = 30 * time.Minute
	}
	if deps.Config.SingleSessionPointerTTL == 0 {
		deps.Config.SingleSessionPointerTTL = 30 * 24 * time.Hour
	}
```

with:

```go
	deps.Config = config.NormalizeTokenConfig(deps.Config)
```

- [ ] **Step 4: Verify GREEN for session**

```powershell
cd E:\admin_go\admin_back_go
gofmt -w internal/module/session/service.go internal/module/session/service_test.go
go test -count=1 ./internal/module/session
```

Expected: `ok admin_back_go/internal/module/session`.

- [ ] **Step 5: Commit session boundary change**

```powershell
cd E:\admin_go\admin_back_go
git add internal/module/session/service.go internal/module/session/service_test.go
git commit -m "refactor: normalize token config in session authenticator"
```

---

### Task 3: Remove deprecated token/session keys from Docker-first env assets

**Files:**
- Modify: `E:\admin_go\admin_back_go\internal\config\config_test.go`
- Modify: `E:\admin_go\admin_back_go\deploy\docker-first\admin-go.env.example`
- Modify local ignored: `E:\admin_go\admin_back_go\deploy\docker-first\admin-go.env`

- [ ] **Step 1: Write failing Docker-first env guard test**

Add this test in `internal/config/config_test.go` near the other Docker-first env guard tests:

```go
func TestDockerFirstEnvDocumentsOnlyTokenRuntimeKnobs(t *testing.T) {
	for _, fileName := range []string{"admin-go.env", "admin-go.env.example"} {
		values := readDockerFirstEnvIfExists(t, fileName)
		if len(values) == 0 {
			continue
		}
		if strings.TrimSpace(values["APP_SECRET"]) == "" {
			t.Fatalf("deploy/docker-first/%s must keep APP_SECRET", fileName)
		}
		if got := values["TOKEN_REDIS_DB"]; got != "2" {
			t.Fatalf("deploy/docker-first/%s must keep TOKEN_REDIS_DB=2, got %q", fileName, got)
		}
		for _, key := range deprecatedTokenSessionEnvKeys() {
			if _, ok := values[key]; ok {
				t.Fatalf("deploy/docker-first/%s must not document token/session policy key %s", fileName, key)
			}
		}
	}
}

func deprecatedTokenSessionEnvKeys() []string {
	return []string{
		"TOKEN_REDIS_PREFIX",
		"TOKEN_SESSION_CACHE_TTL",
		"TOKEN_SINGLE_SESSION_POINTER_TTL",
	}
}
```

- [ ] **Step 2: Run the focused RED test**

```powershell
cd E:\admin_go\admin_back_go
go test -count=1 ./internal/config -run TestDockerFirstEnvDocumentsOnlyTokenRuntimeKnobs
```

Expected: FAIL because `deploy/docker-first/admin-go.env.example` and the local ignored `admin-go.env` still contain the three deprecated keys.

- [ ] **Step 3: Edit Docker-first env example**

In `deploy/docker-first/admin-go.env.example`, keep:

```env
# Code derives JWT signing, refresh-token pepper, secretbox, and session-cache keys internally.
APP_SECRET=CHANGE_ME_AT_LEAST_64_RANDOM_CHARS
TOKEN_REDIS_DB=2
```

Delete these lines:

```env
TOKEN_REDIS_PREFIX=token:
TOKEN_SESSION_CACHE_TTL=30m
TOKEN_SINGLE_SESSION_POINTER_TTL=720h
```

- [ ] **Step 4: Edit local ignored Docker-first env**

In `deploy/docker-first/admin-go.env`, keep the existing local `APP_SECRET` value and keep:

```env
TOKEN_REDIS_DB=2
```

Delete these lines if present:

```env
TOKEN_REDIS_PREFIX=token:
TOKEN_SESSION_CACHE_TTL=30m
TOKEN_SINGLE_SESSION_POINTER_TTL=720h
```

- [ ] **Step 5: Verify Docker env guard GREEN**

```powershell
cd E:\admin_go\admin_back_go
gofmt -w internal/config/config_test.go
go test -count=1 ./internal/config -run TestDockerFirstEnvDocumentsOnlyTokenRuntimeKnobs
```

Expected: `ok admin_back_go/internal/config`.

- [ ] **Step 6: Commit deploy env cleanup**

```powershell
cd E:\admin_go\admin_back_go
git add internal/config/config_test.go deploy/docker-first/admin-go.env.example
git commit -m "deploy: remove token session policy env"
```

`deploy/docker-first/admin-go.env` is ignored and must not be added to the commit.

---

### Task 4: Sync active docs and contracts

**Files:**
- Modify: `E:\admin_go\admin_back_go\docs\architecture.md`
- Modify: `E:\admin_go\admin_back_go\README.md`
- Modify: `E:\admin_go\docs\contracts\admin-api-v1.md`
- Modify: `E:\admin_go\docs\status\current-status.md` only if grep finds removed env names
- Modify: `E:\admin_go\docs\testing\smoke-matrix.md` only if grep finds removed env names

- [ ] **Step 1: Find active docs that still mention removed env keys**

```powershell
cd E:\admin_go
rg -n "TOKEN_REDIS_PREFIX|TOKEN_SESSION_CACHE_TTL|TOKEN_SINGLE_SESSION_POINTER_TTL" admin_back_go/docs admin_back_go/README.md docs/contracts docs/status docs/testing --glob '!**/*.map'
```

Expected before edits: hits in `admin_back_go/docs/architecture.md` and `docs/contracts/admin-api-v1.md`; `README.md` may only mention `TOKEN_REDIS_DB` and `APP_SECRET`, which are allowed.

- [ ] **Step 2: Update backend architecture auth/session wording**

In `admin_back_go/docs/architecture.md`, replace the auth/session implementation block lines with this wording:

```text
APP_SECRET 是唯一根密钥；internal/platform/secretkey 用 HKDF-SHA256 派生 jwt-signing、token-pepper、secretbox、session-cache keys。
access_token 是本系统签发的 JWT，只包含 sid/sub/platform/device_id/iat/nbf/exp/iss 最小 claims。
refresh_token 是 opaque random string，数据库只保存 sha256(refresh_token + "|" + derived token pepper)。
Redis session key = "token:session:" + session_id，其中 "token:" 是代码内置命名空间。
Redis single-session pointer key = "token:cur_sess:" + platform + ":" + user_id。
Redis payload = user_id|expires_at|ip|platform|device_id|session_id
Token Redis 使用独立 DB，默认 TOKEN_REDIS_DB = 2。
Redis 未命中 -> MySQL user_sessions.id
MySQL 条件：revoked_at IS NULL、is_del = 2、expires_at > now
命中 MySQL 后回写 Redis，并按代码内置 30m 续期。
按 auth_platforms 执行 current platform、bind_platform、bind_device、bind_ip、single_session 策略。
access/refresh token 有效期只来自 auth_platforms.access_ttl / auth_platforms.refresh_ttl。
最终 AuthIdentity.Platform 来自 session.platform，前端不得解析 JWT 决定权限。
```

In the active env list, remove:

```text
TOKEN_REDIS_PREFIX
TOKEN_SESSION_CACHE_TTL
TOKEN_SINGLE_SESSION_POINTER_TTL
```

Keep:

```text
APP_SECRET
TOKEN_REDIS_DB
```

Replace the config rule line with:

```text
APP_SECRET 是部署级唯一根密钥，TOKEN_REDIS_DB 是部署级 TokenRedis 隔离项；token Redis prefix `token:`、session cache TTL `30m`、single-session pointer TTL `720h` 是代码内置默认，不进 env，也不进 system_settings。
```

Replace the bootstrap resource line about pointer TTL with:

```text
单端登录指针 TTL 代码内置为 720h，对齐旧 30 天指针；真正单端登录策略仍由 auth_platforms.single_session 管理。
```

Replace revocation wording with:

```text
session.RevocationService 是 token Redis 清理边界：删除 "token:session:"+session_id；只有 "token:cur_sess:<platform>:<user_id>" 当前值等于被撤销 session id 时才删 pointer。
```

- [ ] **Step 3: Update API contract wording**

In `docs/contracts/admin-api-v1.md`, replace the single-session pointer sentence with:

```text
single-session pointer `token:cur_sess:<platform>:<user_id>` is deleted only when its value equals this session id; `token:` is a code-owned Redis namespace.
```

Replace the auth platform env sentence with:

```text
.env 只保存 `APP_SECRET` 和 `TOKEN_REDIS_DB` 这类认证/session 部署基础项；token Redis prefix `token:`、session cache TTL `30m`、single-session pointer TTL `720h` 是代码内置默认。access_ttl / refresh_ttl 仍以 auth_platforms 表为业务事实源。
```

- [ ] **Step 4: Update README only for Docker-first clarity**

In `admin_back_go/README.md`, keep the Redis section:

```env
REDIS_ADDR=127.0.0.1:6379
REDIS_PASSWORD=
REDIS_DB=0

TOKEN_REDIS_DB=2
QUEUE_REDIS_DB=3
```

Add this sentence directly below the existing Redis isolation note:

```text
Token Redis key prefix `token:`、session cache TTL `30m`、single-session pointer TTL `720h` 是代码内置默认，不再通过 Docker-first env 暴露；access/refresh token 有效期仍由 `auth_platforms` 管理。
```

- [ ] **Step 5: Verify active docs no longer expose removed env keys**

```powershell
cd E:\admin_go
rg -n "TOKEN_REDIS_PREFIX|TOKEN_SESSION_CACHE_TTL|TOKEN_SINGLE_SESSION_POINTER_TTL" admin_back_go/deploy admin_back_go/docs admin_back_go/README.md docs/contracts docs/status docs/testing --glob '!**/*.map'
```

Expected: no output.

- [ ] **Step 6: Commit docs sync**

```powershell
cd E:\admin_go\admin_back_go
git add docs/architecture.md README.md
git commit -m "docs: update token session runtime contract"

cd E:\admin_go
git add docs/contracts/admin-api-v1.md docs/status/current-status.md docs/testing/smoke-matrix.md docs/superpowers/specs/2026-05-20-token-session-env-cleanup-design.md docs/superpowers/plans/2026-05-20-token-session-env-cleanup-implementation.md
git commit -m "docs: design token session env cleanup"
```

Only add `docs/status/current-status.md` or `docs/testing/smoke-matrix.md` if they changed.

---

### Task 5: Run mandatory self-tests and runtime verification

**Files:**
- No source edits unless a test reveals a defect.

- [ ] **Step 1: Run focused backend tests**

```powershell
cd E:\admin_go\admin_back_go
go test -count=1 ./internal/config ./internal/module/session ./internal/bootstrap ./internal/module/auth ./internal/module/authplatform ./internal/middleware
```

Expected: all packages report `ok`.

- [ ] **Step 2: Run vet on touched backend areas**

```powershell
cd E:\admin_go\admin_back_go
go vet ./internal/config ./internal/module/session ./internal/bootstrap ./internal/module/auth ./internal/module/authplatform ./internal/middleware
```

Expected: no output and exit code `0`.

- [ ] **Step 3: Validate Docker-first compose config**

```powershell
cd E:\admin_go\admin_back_go\deploy\docker-first
docker compose config --quiet
```

Expected: no output and exit code `0`.

- [ ] **Step 4: Rebuild and restart backend containers**

```powershell
cd E:\admin_go\admin_back_go\deploy\docker-first
docker compose up -d --build admin-api admin-worker
docker compose ps
```

Expected: `admin-api` is `Up` and `healthy`; `admin-worker` is `Up`.

- [ ] **Step 5: Verify runtime health and readiness**

```powershell
$health = Invoke-RestMethod -TimeoutSec 5 http://127.0.0.1:8080/health
$ready = Invoke-RestMethod -TimeoutSec 5 http://127.0.0.1:8080/ready
$health | ConvertTo-Json -Depth 8
$ready | ConvertTo-Json -Depth 8
```

Expected:

```text
health.data.status = ok
ready.data.status = ready
ready.data.checks.database.status = up
ready.data.checks.redis.status = up
ready.data.checks.token_redis.status = up
ready.data.checks.queue_redis.status = up
ready.data.checks.realtime.status = up
```

- [ ] **Step 6: Run authentication/session smoke when smoke credentials are available**

```powershell
cd E:\admin_go\admin_back_go
if ([string]::IsNullOrWhiteSpace($env:SMOKE_LOGIN_ACCOUNT) -or [string]::IsNullOrWhiteSpace($env:SMOKE_LOGIN_PASSWORD)) {
  throw 'SMOKE_LOGIN_ACCOUNT and SMOKE_LOGIN_PASSWORD are required for auth/session smoke.'
}
powershell -ExecutionPolicy Bypass -File .\scripts\basic-admin-smoke.ps1 -HTTPAddr '127.0.0.1:18080' -Account $env:SMOKE_LOGIN_ACCOUNT -Password $env:SMOKE_LOGIN_PASSWORD
```

Expected: script completes and prints its basic smoke summary; login, refresh/logout/session/RBAC probes pass.

- [ ] **Step 7: Run active docs/deploy removed-key scan**

```powershell
cd E:\admin_go
rg -n "TOKEN_REDIS_PREFIX|TOKEN_SESSION_CACHE_TTL|TOKEN_SINGLE_SESSION_POINTER_TTL" admin_back_go/deploy admin_back_go/docs admin_back_go/README.md docs/contracts docs/status docs/testing --glob '!**/*.map'
```

Expected: no output.

- [ ] **Step 8: Run global diff and governance gates**

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected:

```text
git diff --check: no output
check-agent-governance.ps1: PASS: no blocking governance violations found.
```

- [ ] **Step 9: Confirm final working tree state**

```powershell
cd E:\admin_go
git status --short
cd E:\admin_go\admin_back_go
git status --short
cd E:\admin_go\admin_front_ts
git status --short
```

Expected:

- root repo has only intended docs changes before commit, or clean after root commit.
- backend repo has only intended backend/deploy/docs changes before commit, or clean after backend commits.
- frontend repo stays clean.
- `deploy/docker-first/admin-go.env` may be locally modified but must remain ignored and unstaged.

---

## Acceptance Criteria

1. `deploy/docker-first/admin-go.env.example` no longer contains `TOKEN_REDIS_PREFIX`, `TOKEN_SESSION_CACHE_TTL`, or `TOKEN_SINGLE_SESSION_POINTER_TTL`.
2. Local `deploy/docker-first/admin-go.env` no longer contains the same three keys for runtime testing.
3. `APP_SECRET` remains env-owned and is never stored in DB/system_settings.
4. `TOKEN_REDIS_DB` remains env-owned and still defaults to `2`.
5. `config.Load()` ignores legacy `TOKEN_REDIS_PREFIX`, `TOKEN_SESSION_CACHE_TTL`, and `TOKEN_SINGLE_SESSION_POINTER_TTL` env values.
6. Runtime defaults stay unchanged: Redis prefix `token:`, session cache TTL `30m`, single-session pointer TTL `720h`.
7. `auth_platforms.access_ttl`, `auth_platforms.refresh_ttl`, `auth_platforms.single_session`, and `auth_platforms.max_sessions` remain the business source of truth.
8. No SQL migration is added and no `system_settings` token/session key is introduced.
9. Focused Go tests, vet, Docker compose validation, backend rebuild, `/health`, `/ready`, removed-key scan, `git diff --check`, and governance check pass.
10. Frontend working tree remains untouched.
