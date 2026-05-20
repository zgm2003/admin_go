# Scheduler Env Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Shrink Docker-first scheduler env to `SCHEDULER_ENABLED` while preserving DB-backed cron task registration and Redis distributed locking.

**Architecture:** Keep the deployment-level scheduler enable switch in `config.SchedulerConfig`. Move scheduler timezone, Redis lock prefix, and lock TTL to code-owned defaults in `internal/config` and normalize those defaults at both config-load and direct-construction boundaries so `admin-worker` and `platform/scheduler` behave consistently without exposing infrastructure policy in env or `system_settings`.

**Tech Stack:** Go, go-co-op/gocron v2, Redis `SETNX` lock, existing `internal/config`, existing `internal/platform/scheduler`, existing `internal/bootstrap`, Docker-first env templates, PowerShell governance checks.

---

## Design constraints

- Do not change `cron_task` schema, seed data, REST contract, or frontend page.
- Do not move scheduler policy to `system_settings`.
- Do not add SQL migration.
- Do not change queue task type strings or payloads.
- Do not change `QUEUE_*`, `AI_RUN_STALE_TIMEOUT`, realtime, token, CORS, MySQL, Redis, upload, payment, captcha, or verify-code env groups.
- Keep `SCHEDULER_ENABLED=false` behavior: `admin-worker` queue may still consume queued tasks, but scheduler registration does not start.
- Keep business schedules DB-owned through `cron_task` rows plus Go registry.
- Keep Redis distributed lock behavior when Redis resource exists.
- Keep code-owned defaults:
  - timezone: `Asia/Shanghai`
  - lock prefix: `admin_go:scheduler:`
  - lock TTL: `30s`
- Docker-first env final scheduler section must be:

```env
SCHEDULER_ENABLED=true
```

## File map

### Backend code and tests

- Modify: `admin_back_go/internal/config/config.go`
  - Add exported scheduler default constants.
  - Add `NormalizeSchedulerConfig`.
  - Stop reading `SCHEDULER_TIMEZONE`, `SCHEDULER_LOCK_PREFIX`, and `SCHEDULER_LOCK_TTL`.
  - Keep `SchedulerConfig` fields because runtime still needs resolved values.
- Modify: `admin_back_go/internal/config/config_test.go`
  - Update default and env override tests so scheduler policy env values are ignored.
  - Replace old scheduler-lock env example test with Docker-first guard that only allows `SCHEDULER_ENABLED`.
- Modify: `admin_back_go/internal/platform/scheduler/scheduler.go`
  - Use `config.NormalizeSchedulerConfig` in `New`.
  - Ensure zero-value config still gets default timezone, lock prefix, and lock TTL.
- Modify: `admin_back_go/internal/platform/scheduler/scheduler_test.go`
  - Add regression coverage that zero-value config still uses lock prefix and TTL when a locker is injected.
- Modify: `admin_back_go/internal/bootstrap/worker.go`
  - Normalize scheduler config before storing `worker.cfg` and before scheduler construction/logging.
- Modify: `admin_back_go/internal/bootstrap/worker_test.go`
  - Add regression coverage that direct `NewWorker` construction normalizes scheduler policy defaults.

### Deploy/docs

- Modify: `admin_back_go/deploy/docker-first/admin-go.env.example`
  - Remove `SCHEDULER_TIMEZONE`, `SCHEDULER_LOCK_PREFIX`, and `SCHEDULER_LOCK_TTL`.
- Modify: `admin_back_go/deploy/docker-first/admin-go.env`
  - Remove the same three keys if the local ignored file exists.
- Modify: `admin_back_go/docs/architecture.md`
  - Replace active scheduler env contract with code-owned defaults.
- Modify: `admin_back_go/README.md`
  - Replace active scheduler env examples.
- Modify: `docs/deployment/docker-first-backend.md`
  - Keep only `SCHEDULER_ENABLED` in Docker-first examples.
- Modify: `docs/architecture/04-go-backend-framework.md`
  - State scheduler timezone/lock policy are code-owned defaults.
- Modify: `docs/architecture/05-development-quality-rules.md`
  - If active queue/scheduler rules mention scheduler lock env, replace with code-owned default language.
- Modify: `docs/testing/smoke-matrix.md`
  - If it mentions scheduler env, keep only `SCHEDULER_ENABLED`.
- Modify: `docs/status/current-status.md`
  - If needed, mention scheduler Redis lock policy is code-owned while `cron_task` remains DB-owned.

Historical files under `docs/superpowers/specs` and `docs/superpowers/plans` may keep old discussion references unless they are the current scheduler cleanup spec/plan.

---

## Task 1: Config contract tests first

**Files:**
- Modify: `admin_back_go/internal/config/config_test.go`

- [ ] **Step 1: Update scheduler override test so policy env values are ignored**

In `TestLoadReadsEnvironmentOverrides`, keep the current env setup lines:

```go
	t.Setenv("SCHEDULER_ENABLED", "false")
	t.Setenv("SCHEDULER_TIMEZONE", "UTC")
	t.Setenv("SCHEDULER_LOCK_PREFIX", "test:scheduler:")
	t.Setenv("SCHEDULER_LOCK_TTL", "45s")
```

Replace the scheduler assertion:

```go
	if cfg.Scheduler.Timezone != "UTC" || cfg.Scheduler.LockPrefix != "test:scheduler:" || cfg.Scheduler.LockTTL != 45*time.Second {
		t.Fatalf("unexpected scheduler config: %#v", cfg.Scheduler)
	}
```

with:

```go
	if cfg.Scheduler.Timezone != "Asia/Shanghai" ||
		cfg.Scheduler.LockPrefix != "admin_go:scheduler:" ||
		cfg.Scheduler.LockTTL != 30*time.Second {
		t.Fatalf("scheduler policy env must be ignored, got %#v", cfg.Scheduler)
	}
```

- [ ] **Step 2: Replace old Docker-first scheduler lock env example test**

Replace `TestEnvExampleDocumentsSchedulerDistributedLock` with:

```go
func TestDockerFirstEnvDocumentsOnlySchedulerRuntimeKnob(t *testing.T) {
	for _, fileName := range []string{"admin-go.env", "admin-go.env.example"} {
		values := readDockerFirstEnvIfExists(t, fileName)
		if len(values) == 0 {
			continue
		}
		if got := values["SCHEDULER_ENABLED"]; got != "true" {
			t.Fatalf("deploy/docker-first/%s must keep SCHEDULER_ENABLED=true, got %q", fileName, got)
		}
		for _, key := range deprecatedSchedulerPolicyEnvKeys() {
			if _, ok := values[key]; ok {
				t.Fatalf("deploy/docker-first/%s must not document scheduler policy key %s", fileName, key)
			}
		}
	}
}

func deprecatedSchedulerPolicyEnvKeys() []string {
	return []string{
		"SCHEDULER_TIMEZONE",
		"SCHEDULER_LOCK_PREFIX",
		"SCHEDULER_LOCK_TTL",
	}
}
```

- [ ] **Step 3: Run config tests and verify RED**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/config
```

Expected before implementation:

```text
FAIL
scheduler policy env must be ignored
```

or:

```text
FAIL
deploy/docker-first/admin-go.env must not document scheduler policy key SCHEDULER_TIMEZONE
```

Either failure is valid RED because current code still reads policy env and current Docker-first env still documents those keys.

- [ ] **Step 4: Commit the failing tests**

Commit only the config test change:

```powershell
cd E:\admin_go\admin_back_go
git add internal/config/config_test.go
git commit -m "test: guard scheduler env cleanup"
```

Expected:

```text
[master <hash>] test: guard scheduler env cleanup
```

---

## Task 2: Config implementation

**Files:**
- Modify: `admin_back_go/internal/config/config.go`
- Modify: `admin_back_go/internal/config/config_test.go`

- [ ] **Step 1: Add scheduler default constants and normalizer**

In `admin_back_go/internal/config/config.go`, add this block immediately after `type SchedulerConfig struct`:

```go
const (
	DefaultSchedulerTimezone   = "Asia/Shanghai"
	DefaultSchedulerLockPrefix = "admin_go:scheduler:"
	DefaultSchedulerLockTTL    = 30 * time.Second
)

func NormalizeSchedulerConfig(cfg SchedulerConfig) SchedulerConfig {
	cfg.Timezone = strings.TrimSpace(cfg.Timezone)
	if cfg.Timezone == "" {
		cfg.Timezone = DefaultSchedulerTimezone
	}
	cfg.LockPrefix = strings.TrimSpace(cfg.LockPrefix)
	if cfg.LockPrefix == "" {
		cfg.LockPrefix = DefaultSchedulerLockPrefix
	}
	if cfg.LockTTL <= 0 {
		cfg.LockTTL = DefaultSchedulerLockTTL
	}
	return cfg
}
```

`config.go` already imports `strings` and `time`, so no new import is needed.

- [ ] **Step 2: Stop reading deprecated scheduler policy env keys**

In `config.Load()`, replace:

```go
		Scheduler: SchedulerConfig{
			Enabled:    envBool("SCHEDULER_ENABLED", true),
			Timezone:   envString("SCHEDULER_TIMEZONE", "Asia/Shanghai"),
			LockPrefix: envString("SCHEDULER_LOCK_PREFIX", "admin_go:scheduler:"),
			LockTTL:    envDuration("SCHEDULER_LOCK_TTL", 30*time.Second),
		},
```

with:

```go
		Scheduler: NormalizeSchedulerConfig(SchedulerConfig{
			Enabled: envBool("SCHEDULER_ENABLED", true),
		}),
```

- [ ] **Step 3: Update config tests to assert constants**

In `TestLoadUsesSafeDefaults`, replace:

```go
	if cfg.Scheduler.Timezone != "Asia/Shanghai" {
		t.Fatalf("expected scheduler timezone Asia/Shanghai, got %q", cfg.Scheduler.Timezone)
	}
	if cfg.Scheduler.LockPrefix != "admin_go:scheduler:" {
		t.Fatalf("expected scheduler lock prefix admin_go:scheduler:, got %q", cfg.Scheduler.LockPrefix)
	}
	if cfg.Scheduler.LockTTL != 30*time.Second {
		t.Fatalf("expected scheduler lock ttl 30s, got %s", cfg.Scheduler.LockTTL)
	}
```

with:

```go
	if cfg.Scheduler.Timezone != DefaultSchedulerTimezone {
		t.Fatalf("expected scheduler timezone %s, got %q", DefaultSchedulerTimezone, cfg.Scheduler.Timezone)
	}
	if cfg.Scheduler.LockPrefix != DefaultSchedulerLockPrefix {
		t.Fatalf("expected scheduler lock prefix %s, got %q", DefaultSchedulerLockPrefix, cfg.Scheduler.LockPrefix)
	}
	if cfg.Scheduler.LockTTL != DefaultSchedulerLockTTL {
		t.Fatalf("expected scheduler lock ttl %s, got %s", DefaultSchedulerLockTTL, cfg.Scheduler.LockTTL)
	}
```

In `TestLoadReadsEnvironmentOverrides`, replace the literals from Task 1 with constants:

```go
	if cfg.Scheduler.Timezone != DefaultSchedulerTimezone ||
		cfg.Scheduler.LockPrefix != DefaultSchedulerLockPrefix ||
		cfg.Scheduler.LockTTL != DefaultSchedulerLockTTL {
		t.Fatalf("scheduler policy env must be ignored, got %#v", cfg.Scheduler)
	}
```

- [ ] **Step 4: Add a direct normalizer unit test**

Add this test after `TestLoadReadsEnvironmentOverrides`:

```go
func TestNormalizeSchedulerConfigAppliesCodeOwnedDefaults(t *testing.T) {
	cfg := NormalizeSchedulerConfig(SchedulerConfig{Enabled: true})

	if !cfg.Enabled {
		t.Fatalf("expected enabled flag to be preserved")
	}
	if cfg.Timezone != DefaultSchedulerTimezone {
		t.Fatalf("expected default timezone %q, got %q", DefaultSchedulerTimezone, cfg.Timezone)
	}
	if cfg.LockPrefix != DefaultSchedulerLockPrefix {
		t.Fatalf("expected default lock prefix %q, got %q", DefaultSchedulerLockPrefix, cfg.LockPrefix)
	}
	if cfg.LockTTL != DefaultSchedulerLockTTL {
		t.Fatalf("expected default lock ttl %s, got %s", DefaultSchedulerLockTTL, cfg.LockTTL)
	}
}

func TestNormalizeSchedulerConfigTrimsExplicitValues(t *testing.T) {
	cfg := NormalizeSchedulerConfig(SchedulerConfig{
		Timezone:   " UTC ",
		LockPrefix: " custom:scheduler: ",
		LockTTL:    45 * time.Second,
	})

	if cfg.Timezone != "UTC" {
		t.Fatalf("expected trimmed timezone UTC, got %q", cfg.Timezone)
	}
	if cfg.LockPrefix != "custom:scheduler:" {
		t.Fatalf("expected trimmed lock prefix, got %q", cfg.LockPrefix)
	}
	if cfg.LockTTL != 45*time.Second {
		t.Fatalf("expected explicit lock ttl 45s, got %s", cfg.LockTTL)
	}
}
```

- [ ] **Step 5: Run config tests and verify remaining RED is env-file-only**

Run:

```powershell
cd E:\admin_go\admin_back_go
gofmt -w internal/config/config.go internal/config/config_test.go
go test ./internal/config
```

Expected after config implementation but before env cleanup:

```text
FAIL
deploy/docker-first/admin-go.env must not document scheduler policy key SCHEDULER_TIMEZONE
```

The scheduler override assertion must pass at this point.

- [ ] **Step 6: Commit config implementation**

Commit:

```powershell
cd E:\admin_go\admin_back_go
git add internal/config/config.go internal/config/config_test.go
git commit -m "refactor: internalize scheduler policy defaults"
```

Expected:

```text
[master <hash>] refactor: internalize scheduler policy defaults
```

---

## Task 3: Scheduler and worker default normalization

**Files:**
- Modify: `admin_back_go/internal/platform/scheduler/scheduler.go`
- Modify: `admin_back_go/internal/platform/scheduler/scheduler_test.go`
- Modify: `admin_back_go/internal/bootstrap/worker.go`
- Modify: `admin_back_go/internal/bootstrap/worker_test.go`

- [ ] **Step 1: Add scheduler zero-value default regression test**

In `admin_back_go/internal/platform/scheduler/scheduler_test.go`, add this test after `TestNewUsesConfiguredTimezone`:

```go
func TestNewUsesCodeOwnedDefaultsForZeroConfig(t *testing.T) {
	locker := &fakeLocker{}
	scheduler, err := New(config.SchedulerConfig{}, WithLocker(locker))
	if err != nil {
		t.Fatalf("New returned error: %v", err)
	}
	defer scheduler.Shutdown(context.Background())

	if scheduler.location.String() != config.DefaultSchedulerTimezone {
		t.Fatalf("expected default location %s, got %s", config.DefaultSchedulerTimezone, scheduler.location)
	}

	run := false
	err = scheduler.wrapTask("job-a", func(ctx context.Context) error {
		run = true
		return nil
	})(context.Background())
	if err != nil {
		t.Fatalf("task returned error: %v", err)
	}
	if !run {
		t.Fatalf("expected task to run")
	}
	if locker.lockKey != config.DefaultSchedulerLockPrefix+"job-a" {
		t.Fatalf("unexpected lock key: %q", locker.lockKey)
	}
	if locker.lockTTL != config.DefaultSchedulerLockTTL {
		t.Fatalf("unexpected lock ttl: %s", locker.lockTTL)
	}
}
```

- [ ] **Step 2: Add worker direct-construction normalization test**

In `admin_back_go/internal/bootstrap/worker_test.go`, add this test after `TestNewWorkerAllowsQueueDisabledWithoutRedis`:

```go
func TestNewWorkerNormalizesSchedulerPolicyDefaults(t *testing.T) {
	worker, err := NewWorker(config.Config{
		App:       config.AppConfig{Secret: strings.Repeat("a", 64)},
		Queue:     config.QueueConfig{Enabled: false},
		Scheduler: config.SchedulerConfig{Enabled: true},
	}, slog.Default())
	if err != nil {
		t.Fatalf("expected worker to build, got %v", err)
	}
	defer worker.Shutdown(t.Context())

	if worker.cfg.Scheduler.Timezone != config.DefaultSchedulerTimezone {
		t.Fatalf("expected worker scheduler timezone %q, got %q", config.DefaultSchedulerTimezone, worker.cfg.Scheduler.Timezone)
	}
	if worker.cfg.Scheduler.LockPrefix != config.DefaultSchedulerLockPrefix {
		t.Fatalf("expected worker scheduler lock prefix %q, got %q", config.DefaultSchedulerLockPrefix, worker.cfg.Scheduler.LockPrefix)
	}
	if worker.cfg.Scheduler.LockTTL != config.DefaultSchedulerLockTTL {
		t.Fatalf("expected worker scheduler lock ttl %s, got %s", config.DefaultSchedulerLockTTL, worker.cfg.Scheduler.LockTTL)
	}
}
```

- [ ] **Step 3: Run tests and verify RED**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/platform/scheduler ./internal/bootstrap
```

Expected before implementation:

```text
FAIL
unexpected lock key: ""
```

and/or:

```text
FAIL
expected worker scheduler timezone "Asia/Shanghai", got ""
```

- [ ] **Step 4: Normalize config inside scheduler.New**

In `admin_back_go/internal/platform/scheduler/scheduler.go`, replace the beginning of `New`:

```go
func New(cfg config.SchedulerConfig, opts ...Option) (*Scheduler, error) {
	timezone := strings.TrimSpace(cfg.Timezone)
	if timezone == "" {
		timezone = "Asia/Shanghai"
	}
	location, err := time.LoadLocation(timezone)
```

with:

```go
func New(cfg config.SchedulerConfig, opts ...Option) (*Scheduler, error) {
	cfg = config.NormalizeSchedulerConfig(cfg)
	location, err := time.LoadLocation(cfg.Timezone)
```

Then replace the scheduler result initialization:

```go
	result := &Scheduler{
		scheduler:  s,
		location:   location,
		lockPrefix: strings.TrimSpace(cfg.LockPrefix),
		lockTTL:    cfg.LockTTL,
		logger:     slog.Default(),
	}
	if result.lockTTL <= 0 {
		result.lockTTL = 30 * time.Second
	}
```

with:

```go
	result := &Scheduler{
		scheduler:  s,
		location:   location,
		lockPrefix: cfg.LockPrefix,
		lockTTL:    cfg.LockTTL,
		logger:     slog.Default(),
	}
```

Keep `strings` imported because `wrapTask` still uses `strings.TrimSpace`.

- [ ] **Step 5: Normalize scheduler config inside NewWorker**

In `admin_back_go/internal/bootstrap/worker.go`, add this line near the start of `NewWorker`, after the nil logger guard and before `ValidateRuntimeSecrets`:

```go
	cfg.Scheduler = config.NormalizeSchedulerConfig(cfg.Scheduler)
```

The beginning should look like:

```go
func NewWorker(cfg config.Config, logger *slog.Logger) (*Worker, error) {
	if logger == nil {
		logger = slog.Default()
	}
	cfg.Scheduler = config.NormalizeSchedulerConfig(cfg.Scheduler)
	if err := config.ValidateRuntimeSecrets(cfg); err != nil {
		return nil, err
	}
```

This ensures `w.cfg.Scheduler.Timezone` used in the startup log is not empty even when tests or callers directly construct `config.Config`.

- [ ] **Step 6: Run scheduler/bootstrap tests and verify GREEN**

Run:

```powershell
cd E:\admin_go\admin_back_go
gofmt -w internal/platform/scheduler/scheduler.go internal/platform/scheduler/scheduler_test.go internal/bootstrap/worker.go internal/bootstrap/worker_test.go
go test ./internal/platform/scheduler ./internal/bootstrap
```

Expected:

```text
ok  	admin_back_go/internal/platform/scheduler
ok  	admin_back_go/internal/bootstrap
```

- [ ] **Step 7: Commit scheduler and worker normalization**

Commit:

```powershell
cd E:\admin_go\admin_back_go
git add internal/platform/scheduler/scheduler.go internal/platform/scheduler/scheduler_test.go internal/bootstrap/worker.go internal/bootstrap/worker_test.go
git commit -m "refactor: normalize scheduler defaults at runtime"
```

Expected:

```text
[master <hash>] refactor: normalize scheduler defaults at runtime
```

---

## Task 4: Docker-first env cleanup

**Files:**
- Modify: `admin_back_go/deploy/docker-first/admin-go.env.example`
- Modify: `admin_back_go/deploy/docker-first/admin-go.env`

- [ ] **Step 1: Remove deprecated scheduler policy keys from env example**

In `admin_back_go/deploy/docker-first/admin-go.env.example`, replace:

```env
SCHEDULER_ENABLED=true
SCHEDULER_TIMEZONE=Asia/Shanghai
SCHEDULER_LOCK_PREFIX=admin_go:scheduler:
SCHEDULER_LOCK_TTL=30s
```

with:

```env
SCHEDULER_ENABLED=true
```

- [ ] **Step 2: Remove deprecated scheduler policy keys from local Docker-first env**

If `admin_back_go/deploy/docker-first/admin-go.env` exists, make the same replacement:

```env
SCHEDULER_ENABLED=true
```

Do not change local MySQL, Redis, APP_SECRET, CORS, queue, realtime, AI, or token values in this ignored file.

- [ ] **Step 3: Run config tests and verify GREEN**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/config
```

Expected:

```text
ok  	admin_back_go/internal/config
```

- [ ] **Step 4: Check env files no longer contain deprecated scheduler policy keys**

Run:

```powershell
cd E:\admin_go
rg -n "SCHEDULER_TIMEZONE|SCHEDULER_LOCK_PREFIX|SCHEDULER_LOCK_TTL" admin_back_go/deploy/docker-first/admin-go.env admin_back_go/deploy/docker-first/admin-go.env.example
```

Expected:

```text
no output
```

- [ ] **Step 5: Commit env cleanup**

Commit tracked file changes. `admin-go.env` is ignored/local, so it will not be included in git but should remain locally cleaned for Docker runtime tests.

```powershell
cd E:\admin_go\admin_back_go
git add deploy/docker-first/admin-go.env.example
git commit -m "deploy: shrink scheduler docker env"
```

Expected:

```text
[master <hash>] deploy: shrink scheduler docker env
```

---

## Task 5: Active docs cleanup

**Files:**
- Modify: `admin_back_go/docs/architecture.md`
- Modify: `admin_back_go/README.md`
- Modify: `docs/deployment/docker-first-backend.md`
- Modify: `docs/architecture/04-go-backend-framework.md`
- Modify: `docs/architecture/05-development-quality-rules.md`
- Modify: `docs/testing/smoke-matrix.md`
- Modify: `docs/status/current-status.md`

- [ ] **Step 1: Locate active scheduler policy env references**

Run:

```powershell
cd E:\admin_go
rg -n "SCHEDULER_TIMEZONE|SCHEDULER_LOCK_PREFIX|SCHEDULER_LOCK_TTL" admin_back_go/docs admin_back_go/README.md docs/deployment docs/architecture docs/testing docs/status --glob '!**/*.map'
```

Expected before docs cleanup: hits in active architecture/deployment docs and possibly current status/testing docs.

- [ ] **Step 2: Update backend architecture docs**

In `admin_back_go/docs/architecture.md`, replace active scheduler env lists containing:

```text
SCHEDULER_ENABLED
SCHEDULER_TIMEZONE
SCHEDULER_LOCK_PREFIX
SCHEDULER_LOCK_TTL
```

with:

```text
SCHEDULER_ENABLED
```

Add this sentence near the scheduler section:

```text
Scheduler timezone (`Asia/Shanghai`), distributed lock prefix (`admin_go:scheduler:`), and lock TTL (`30s`) are code-owned defaults. They are not Docker-first env keys and do not live in `system_settings`; business schedules remain DB-owned through `cron_task` rows.
```

- [ ] **Step 3: Update backend README**

In `admin_back_go/README.md`, replace any active scheduler env example with:

```env
SCHEDULER_ENABLED=true
```

Add this explanation after the example:

```text
Scheduler timezone, Redis lock prefix, and lock TTL are Go defaults. Use the cron task page/table for business schedule changes; use `SCHEDULER_ENABLED=false` only to disable scheduler registration during deployment or troubleshooting.
```

- [ ] **Step 4: Update Docker-first backend runbook**

In `docs/deployment/docker-first-backend.md`, replace scheduler env examples with:

```env
SCHEDULER_ENABLED=true
```

Add this note near the env explanation:

```text
Docker-first scheduler env only keeps the enable switch. The scheduler runs in `admin-worker`, reads enabled `cron_task` rows, and uses code-owned defaults for timezone (`Asia/Shanghai`) and Redis distributed lock policy (`admin_go:scheduler:` / `30s`).
```

Keep any existing note that `SCHEDULER_ENABLED=false` is useful during empty-schema import or scheduler troubleshooting.

- [ ] **Step 5: Update framework and quality-rule docs**

In `docs/architecture/04-go-backend-framework.md`, ensure the Queue/Scheduler section says:

```text
Scheduler business definitions live in `cron_task` rows and Go registry entries. Deployment env only controls `SCHEDULER_ENABLED`; timezone and Redis lock policy are code-owned defaults.
```

In `docs/architecture/05-development-quality-rules.md`, ensure the Queue / Scheduler rules say:

```text
Do not add new scheduler policy env keys for lock prefix, lock TTL, or timezone without a separate deployment namespace design. Cron business cadence belongs to `cron_task`; infrastructure defaults belong to code.
```

- [ ] **Step 6: Update smoke/status docs only if active references exist**

If `docs/testing/smoke-matrix.md` contains active scheduler env references, replace them with:

```text
`SCHEDULER_ENABLED` controls whether `admin-worker` registers DB-backed cron tasks. Scheduler timezone and Redis lock policy are code-owned defaults.
```

If `docs/status/current-status.md` needs a status note in the system cron row, use:

```text
system cron tasks use DB-backed `cron_task` rows plus code-owned scheduler timezone/Redis lock defaults
```

- [ ] **Step 7: Verify active docs cleanup**

Run:

```powershell
cd E:\admin_go
rg -n "SCHEDULER_TIMEZONE|SCHEDULER_LOCK_PREFIX|SCHEDULER_LOCK_TTL" admin_back_go/docs admin_back_go/README.md docs/deployment docs/architecture docs/testing docs/status --glob '!**/*.map'
```

Expected:

```text
no output
```

Then run a broader search that may still show historical specs/plans:

```powershell
cd E:\admin_go
rg -n "SCHEDULER_TIMEZONE|SCHEDULER_LOCK_PREFIX|SCHEDULER_LOCK_TTL" docs/superpowers admin_back_go/deploy admin_back_go/internal --glob '!**/*.map'
```

Expected allowed hits:

```text
docs/superpowers/specs/2026-05-20-scheduler-env-cleanup-design.md
docs/superpowers/plans/2026-05-20-scheduler-env-cleanup-implementation.md
```

No hits should remain in `admin_back_go/deploy/docker-first/*.env*` or active backend source reading env.

- [ ] **Step 8: Commit root docs cleanup**

Commit active root docs after implementation. The implementation plan is committed before execution and does not need to be staged again unless it was intentionally edited during execution.

```powershell
cd E:\admin_go
git add docs/deployment/docker-first-backend.md docs/architecture/04-go-backend-framework.md docs/architecture/05-development-quality-rules.md docs/testing/smoke-matrix.md docs/status/current-status.md admin_back_go/docs/architecture.md admin_back_go/README.md
git status --short
git commit -m "docs: update scheduler env contract"
```

If some listed files were not changed, `git add` stages only existing changed paths. Verify with `git status --short` before committing.

Expected:

```text
[master <hash>] docs: update scheduler env contract
```

---

## Task 6: Targeted backend verification

**Files:**
- No source edits expected unless tests expose a compile error.

- [ ] **Step 1: Run targeted backend tests**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/config ./internal/platform/scheduler ./internal/bootstrap ./internal/module/crontask
```

Expected:

```text
ok  	admin_back_go/internal/config
ok  	admin_back_go/internal/platform/scheduler
ok  	admin_back_go/internal/bootstrap
ok  	admin_back_go/internal/module/crontask
```

- [ ] **Step 2: Run focused vet**

Run:

```powershell
cd E:\admin_go\admin_back_go
go vet ./internal/config ./internal/platform/scheduler ./internal/bootstrap ./internal/module/crontask
```

Expected:

```text
no output
```

- [ ] **Step 3: Run worker and queue-adjacent tests if worker wiring changed**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./cmd/admin-worker ./internal/jobs ./internal/platform/taskqueue
```

Expected:

```text
ok  	admin_back_go/cmd/admin-worker
ok  	admin_back_go/internal/jobs
ok  	admin_back_go/internal/platform/taskqueue
```

- [ ] **Step 4: Verify Docker-first Compose config**

Run:

```powershell
cd E:\admin_go\admin_back_go\deploy\docker-first
docker compose config --quiet
```

Expected:

```text
no output
```

- [ ] **Step 5: Commit any verification-driven fix**

If Task 6 required no edits, do not create an empty commit.

If a compile/runtime fix was needed, commit only the changed files. For example:

```powershell
cd E:\admin_go\admin_back_go
git add internal/platform/scheduler/scheduler.go internal/bootstrap/worker.go
git commit -m "fix: keep scheduler defaults stable"
```

---

## Task 7: Optional Docker-first runtime verification

**Files:**
- No source edits expected.

Run this task if the user asks for fresh runtime proof or if targeted tests expose uncertainty about worker startup.

- [ ] **Step 1: Rebuild and restart Docker-first backend**

Run:

```powershell
cd E:\admin_go\admin_back_go\deploy\docker-first
docker compose up -d --build admin-api admin-worker
docker compose ps
```

Expected:

```text
admin-go-backend-admin-api-1      healthy
admin-go-backend-admin-worker-1   running
```

- [ ] **Step 2: Verify health and readiness**

Run:

```powershell
cd E:\admin_go\admin_back_go\deploy\docker-first
curl.exe -fsS http://127.0.0.1:8080/health
curl.exe -fsS http://127.0.0.1:8080/ready
```

Expected:

```text
/health returns success JSON
/ready returns success JSON with database, redis, token_redis, queue_redis, and realtime up
```

If `/ready` fails because local MySQL/Redis containers are intentionally stopped, do not patch code. Start state services from the existing Docker-first state runbook or report the exact down check.

---

## Task 8: Final governance and residue checks

**Files:**
- No edits expected.

- [ ] **Step 1: Check tracked and nested repo status**

Run:

```powershell
cd E:\admin_go
git status --short --branch
git -C admin_back_go status --short --branch
git -C admin_front_ts status --short --branch
```

Expected:

```text
root ahead by scheduler spec/plan/docs commits, clean
backend ahead by scheduler implementation commits, clean
frontend clean
```

Ignored local `admin_back_go/deploy/docker-first/admin-go.env` may be modified but should not appear in git status.

- [ ] **Step 2: Run whitespace and governance gates**

Run:

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected:

```text
git diff --check exits 0
PASS: no blocking governance violations found
```

- [ ] **Step 3: Run final active-reference search**

Run:

```powershell
cd E:\admin_go
rg -n "SCHEDULER_TIMEZONE|SCHEDULER_LOCK_PREFIX|SCHEDULER_LOCK_TTL" admin_back_go/deploy admin_back_go/docs admin_back_go/README.md docs/deployment docs/architecture docs/testing docs/status --glob '!**/*.map'
```

Expected:

```text
no output
```

- [ ] **Step 4: Prepare final report**

Final report must include:

```text
Outcome:
- Docker-first scheduler env now keeps only SCHEDULER_ENABLED.
- SCHEDULER_TIMEZONE, SCHEDULER_LOCK_PREFIX, and SCHEDULER_LOCK_TTL are code-owned defaults.
- cron_task remains the business schedule source of truth.
- Redis distributed lock remains enabled when worker has Redis resource.

Evidence:
- backend test command and PASS output summary
- docker compose config --quiet result
- optional /ready summary if runtime verification ran
- governance PASS summary
- commit hashes for backend/root

Not done:
- no system_settings migration
- no cron_task schema/page change
- no frontend change
- no push unless user explicitly says push
```

Do not say runtime is verified unless Task 7 actually ran and passed in the current session.
