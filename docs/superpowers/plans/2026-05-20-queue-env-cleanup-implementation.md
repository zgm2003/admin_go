# Queue Env Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Shrink Docker-first queue env to `QUEUE_ENABLED`, `QUEUE_REDIS_DB`, and `QUEUE_CONCURRENCY` while preserving current Asynq queue behavior.

**Architecture:** Keep deployment-controlled queue availability, Redis DB, and worker concurrency in `config.QueueConfig`. Move queue lane names, lane weights, default retry/timeout, and shutdown timeout into `internal/platform/taskqueue` code-owned defaults so task producers/consumers share one stable policy without exposing it in env or `system_settings`.

**Tech Stack:** Go, Asynq, existing `internal/config`, existing `internal/platform/taskqueue`, PowerShell governance checks, Docker-first env templates.

---

## Design constraints

- Do not change task type strings or payload schemas.
- Do not move queue policy to `system_settings`.
- Do not touch frontend code.
- Do not change realtime, scheduler, token, AI, CORS, MySQL, Redis, or logging env groups.
- Keep `QUEUE_ENABLED=false` behavior: queue clients/server disabled and readiness reports `queue_redis=disabled`.
- Keep `QUEUE_REDIS_DB=3` default and `QUEUE_CONCURRENCY=10` default.
- Keep runtime policy values: critical/default/low weights `6/3/1`, default queue `default`, default retry `3`, default timeout `30s`, shutdown timeout `10s`.

## File map

### Backend code and tests

- Modify: `admin_back_go/internal/config/config.go`
  - Remove public env loading for queue policy keys.
  - Keep only `Enabled`, `RedisDB`, and `Concurrency` in `QueueConfig`.
- Modify: `admin_back_go/internal/config/config_test.go`
  - Adjust default/override tests for the new queue config shape.
  - Add Docker-first env guard for deprecated queue policy keys.
  - Remove expectations that deprecated queue policy env keys are documented.
- Modify: `admin_back_go/internal/platform/taskqueue/client.go`
  - Own default queue name, retry, and timeout inside taskqueue package.
  - Keep explicit task-level overrides working.
- Modify: `admin_back_go/internal/platform/taskqueue/client_test.go`
  - Update tests to assert code-owned defaults and `QUEUE_REDIS_DB` behavior.
- Modify: `admin_back_go/internal/platform/taskqueue/server.go`
  - Own lane weights and shutdown timeout inside taskqueue package.
  - Keep `Concurrency` and `RedisDB` from `QueueConfig`.
- Modify: `admin_back_go/internal/platform/taskqueue/server_test.go`
  - Update tests to assert fixed queue weights and reject empty Redis behavior.
- Modify: `admin_back_go/internal/bootstrap/worker_test.go`
  - Remove no-longer-existing queue policy fields from `config.QueueConfig` test setup.
- Modify if compile requires it: `admin_back_go/internal/bootstrap/resources_test.go`, `admin_back_go/internal/module/queuemonitor/asynqmon_test.go`, and any other tests constructing `config.QueueConfig` with removed fields.

### Deploy/docs

- Modify: `admin_back_go/deploy/docker-first/admin-go.env.example`
  - Remove deprecated queue policy env lines.
- Modify: `admin_back_go/deploy/docker-first/admin-go.env`
  - If present in the local working tree, remove the same deprecated queue policy env lines even though it is ignored/local.
- Modify: `admin_back_go/docs/architecture.md`
  - Replace queue policy env contract with code-owned defaults.
- Modify: `docs/contracts/admin-api-v1.md`
  - Update runtime/env contract text.
- Modify: `docs/deployment/docker-first-backend.md`
  - Update Docker-first queue env example and explanation.
- Modify if `rg` finds active references: `docs/deployment/local.md`, `docs/deployment/production.md`, `docs/architecture/04-go-backend-framework.md`, `docs/architecture/05-development-quality-rules.md`.

---

## Task 1: Config contract tests first

**Files:**
- Modify: `admin_back_go/internal/config/config_test.go`

- [ ] **Step 1: Add a failing guard for deprecated Docker-first queue policy env keys**

Add this test near the existing Docker-first env cleanup tests in `admin_back_go/internal/config/config_test.go`:

```go
func TestDockerFirstEnvDocumentsOnlyQueueRuntimeKnobs(t *testing.T) {
	for _, fileName := range []string{"admin-go.env", "admin-go.env.example"} {
		values := readDockerFirstEnvIfExists(t, fileName)
		if len(values) == 0 {
			continue
		}
		if got := values["QUEUE_ENABLED"]; got != "true" {
			t.Fatalf("deploy/docker-first/%s must keep QUEUE_ENABLED=true, got %q", fileName, got)
		}
		if got := values["QUEUE_REDIS_DB"]; got != "3" {
			t.Fatalf("deploy/docker-first/%s must keep QUEUE_REDIS_DB=3, got %q", fileName, got)
		}
		if got := values["QUEUE_CONCURRENCY"]; got != "10" {
			t.Fatalf("deploy/docker-first/%s must keep QUEUE_CONCURRENCY=10, got %q", fileName, got)
		}
		for _, key := range deprecatedQueuePolicyEnvKeys() {
			if _, ok := values[key]; ok {
				t.Fatalf("deploy/docker-first/%s must not document queue policy key %s", fileName, key)
			}
		}
	}
}

func deprecatedQueuePolicyEnvKeys() []string {
	return []string{
		"QUEUE_DEFAULT_QUEUE",
		"QUEUE_CRITICAL_WEIGHT",
		"QUEUE_DEFAULT_WEIGHT",
		"QUEUE_LOW_WEIGHT",
		"QUEUE_SHUTDOWN_TIMEOUT",
		"QUEUE_DEFAULT_MAX_RETRY",
		"QUEUE_DEFAULT_TIMEOUT",
	}
}
```

- [ ] **Step 2: Update `TestLoadDefaults` queue assertions to only cover env-owned fields**

In `TestLoadDefaults`, replace the queue policy assertions with this smaller check:

```go
	if !cfg.Queue.Enabled {
		t.Fatalf("expected queue to be enabled by default")
	}
	if cfg.Queue.RedisDB != 3 {
		t.Fatalf("expected queue redis db 3, got %d", cfg.Queue.RedisDB)
	}
	if cfg.Queue.Concurrency != 10 {
		t.Fatalf("expected queue concurrency 10, got %d", cfg.Queue.Concurrency)
	}
```

Remove any checks in this test for:

```go
cfg.Queue.DefaultQueue
cfg.Queue.CriticalWeight
cfg.Queue.DefaultWeight
cfg.Queue.LowWeight
cfg.Queue.ShutdownTimeout
cfg.Queue.DefaultMaxRetry
cfg.Queue.DefaultTimeout
```

- [ ] **Step 3: Update env override test to only set queue env-owned fields**

In the env override test currently setting all `QUEUE_*` keys, keep only:

```go
	t.Setenv("QUEUE_ENABLED", "false")
	t.Setenv("QUEUE_REDIS_DB", "4")
	t.Setenv("QUEUE_CONCURRENCY", "22")
```

Replace the queue assertions with:

```go
	if cfg.Queue.Enabled {
		t.Fatalf("expected queue enabled override to false")
	}
	if cfg.Queue.RedisDB != 4 || cfg.Queue.Concurrency != 22 {
		t.Fatalf("unexpected queue config: %#v", cfg.Queue)
	}
```

Remove expectations for deprecated queue policy fields.

- [ ] **Step 4: Run the config tests and confirm the new guard fails before implementation**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/config
```

Expected before implementation:

```text
FAIL
... deploy/docker-first/admin-go.env must not document queue policy key QUEUE_DEFAULT_QUEUE ...
```

The exact first deprecated key may vary between `admin-go.env` and `admin-go.env.example`.

---

## Task 2: Move queue policy defaults into taskqueue package

**Files:**
- Modify: `admin_back_go/internal/config/config.go`
- Modify: `admin_back_go/internal/platform/taskqueue/client.go`
- Modify: `admin_back_go/internal/platform/taskqueue/server.go`

- [ ] **Step 1: Shrink `QueueConfig` in config**

In `admin_back_go/internal/config/config.go`, change `QueueConfig` to:

```go
type QueueConfig struct {
	Enabled     bool
	RedisDB     int
	Concurrency int
}
```

- [ ] **Step 2: Stop reading deprecated queue policy env keys**

In `Load()`, replace the `Queue: QueueConfig{...}` block with:

```go
		Queue: QueueConfig{
			Enabled:     envBool("QUEUE_ENABLED", true),
			RedisDB:     envInt("QUEUE_REDIS_DB", 3),
			Concurrency: envInt("QUEUE_CONCURRENCY", 10),
		},
```

- [ ] **Step 3: Add taskqueue default constants**

In `admin_back_go/internal/platform/taskqueue/server.go`, extend the existing queue constants block to include code-owned default policy values:

```go
const (
	QueueCritical = "critical"
	QueueDefault  = "default"
	QueueLow      = "low"

	DefaultCriticalWeight = 6
	DefaultQueueWeight    = 3
	DefaultLowWeight      = 1
)
```

Add `time` to the imports in `server.go` and add:

```go
const DefaultShutdownTimeout = 10 * time.Second
```

If Go formatting prefers one const block, use:

```go
const (
	QueueCritical = "critical"
	QueueDefault  = "default"
	QueueLow      = "low"

	DefaultCriticalWeight = 6
	DefaultQueueWeight    = 3
	DefaultLowWeight      = 1
	DefaultShutdownTimeout = 10 * time.Second
)
```

- [ ] **Step 4: Use code-owned server defaults**

In `NewServer`, keep `queueCfg.Concurrency`, but replace the queue map and shutdown timeout usage with defaults:

```go
	queues := queueWeights()
	if len(queues) == 0 {
		return nil, ErrQueueWeightRequired
	}

	return &Server{
		server: asynq.NewServer(redisOpt, asynq.Config{
			Concurrency:     queueCfg.Concurrency,
			Queues:          queues,
			ShutdownTimeout: DefaultShutdownTimeout,
		}),
	}, nil
```

Change `queueWeights` to take no config:

```go
func queueWeights() map[string]int {
	return map[string]int{
		QueueCritical: DefaultCriticalWeight,
		QueueDefault:  DefaultQueueWeight,
		QueueLow:      DefaultLowWeight,
	}
}
```

- [ ] **Step 5: Add taskqueue client defaults**

In `admin_back_go/internal/platform/taskqueue/client.go`, add these constants after the `Task` type or near existing package-level declarations:

```go
const (
	DefaultMaxRetry = 3
	DefaultTimeout  = 30 * time.Second
)
```

`client.go` already imports `time`, so no new import is needed.

- [ ] **Step 6: Use code-owned client defaults**

In `NewClient`, replace the fields sourced from `queueCfg` with constants:

```go
	return &Client{
		client:          asynq.NewClient(redisOpt),
		redisOpt:        redisOpt,
		defaultQueue:    QueueDefault,
		defaultMaxRetry: DefaultMaxRetry,
		defaultTimeout:  DefaultTimeout,
	}, nil
```

- [ ] **Step 7: Run formatting and expect compile failures in tests that still reference removed fields**

Run:

```powershell
cd E:\admin_go\admin_back_go
gofmt -w internal/config/config.go internal/platform/taskqueue/client.go internal/platform/taskqueue/server.go
go test ./internal/config ./internal/platform/taskqueue ./internal/bootstrap
```

Expected at this midpoint:

```text
FAIL or build failed
unknown field DefaultQueue in struct literal of type config.QueueConfig
unknown field CriticalWeight in struct literal of type config.QueueConfig
```

This confirms implementation changed the public config shape and tests must be updated next.

---

## Task 3: Update taskqueue tests for code-owned defaults

**Files:**
- Modify: `admin_back_go/internal/platform/taskqueue/client_test.go`
- Modify: `admin_back_go/internal/platform/taskqueue/server_test.go`

- [ ] **Step 1: Simplify empty Redis client test config**

In `client_test.go`, change `TestNewClientRejectsEmptyRedisAddr` to call:

```go
	client, err := NewClient(config.RedisConfig{}, config.QueueConfig{})
```

- [ ] **Step 2: Simplify client defaults test config**

In `TestNewClientMapsRedisAndQueueDefaults`, replace the queue config literal with:

```go
	}, config.QueueConfig{RedisDB: 3})
```

Keep this assertion:

```go
	if client.defaultQueue != "default" || client.defaultMaxRetry != 3 || client.defaultTimeout != 30*time.Second {
		t.Fatalf("unexpected queue defaults: %#v", client)
	}
```

Optionally use constants in the assertion:

```go
	if client.defaultQueue != QueueDefault || client.defaultMaxRetry != DefaultMaxRetry || client.defaultTimeout != DefaultTimeout {
		t.Fatalf("unexpected queue defaults: %#v", client)
	}
```

- [ ] **Step 3: Rename normalize default test to reflect code-owned defaults**

Rename:

```go
func TestNormalizeTaskUsesConfiguredDefaults(t *testing.T) {
```

to:

```go
func TestNormalizeTaskUsesCodeOwnedDefaults(t *testing.T) {
```

Keep the manually constructed client as:

```go
	client := &Client{
		defaultQueue:    QueueDefault,
		defaultMaxRetry: DefaultMaxRetry,
		defaultTimeout:  DefaultTimeout,
	}
```

Update assertions to:

```go
	assertOption(t, opts, asynq.Queue(QueueDefault))
	assertOption(t, opts, asynq.MaxRetry(DefaultMaxRetry))
	assertOption(t, opts, asynq.Timeout(DefaultTimeout))
```

- [ ] **Step 4: Update explicit task override test to use constants for defaults**

In `TestNormalizeTaskAllowsExplicitQueueRetryTimeoutAndUniqueTTL`, construct the client with:

```go
	client := &Client{
		defaultQueue:    QueueDefault,
		defaultMaxRetry: DefaultMaxRetry,
		defaultTimeout:  DefaultTimeout,
	}
```

Keep explicit override assertions unchanged:

```go
	assertOption(t, opts, asynq.Queue("critical"))
	assertOption(t, opts, asynq.MaxRetry(7))
	assertOption(t, opts, asynq.Timeout(15*time.Second))
	assertOption(t, opts, asynq.Unique(time.Minute))
```

- [ ] **Step 5: Replace server queue weight tests**

In `server_test.go`, replace `TestQueueWeightsDropDisabledQueues` with:

```go
func TestQueueWeightsUseCodeOwnedDefaults(t *testing.T) {
	queues := queueWeights()

	if len(queues) != 3 {
		t.Fatalf("expected three enabled queues, got %#v", queues)
	}
	if queues[QueueCritical] != DefaultCriticalWeight {
		t.Fatalf("unexpected critical weight: %#v", queues)
	}
	if queues[QueueDefault] != DefaultQueueWeight {
		t.Fatalf("unexpected default weight: %#v", queues)
	}
	if queues[QueueLow] != DefaultLowWeight {
		t.Fatalf("unexpected low weight: %#v", queues)
	}
}
```

- [ ] **Step 6: Delete no-enabled-queues test**

Remove `TestNewServerRejectsNoEnabledQueues` from `server_test.go` because queue weights are no longer externally disableable.

- [ ] **Step 7: Update server start test config**

In `TestServerStartRejectsNilMux`, call:

```go
	server, err := NewServer(config.RedisConfig{Addr: "127.0.0.1:6379"}, config.QueueConfig{Concurrency: 1})
```

- [ ] **Step 8: Run taskqueue tests**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/platform/taskqueue
```

Expected:

```text
ok  	admin_back_go/internal/platform/taskqueue
```

---

## Task 4: Update bootstrap tests and remaining compile errors

**Files:**
- Modify: `admin_back_go/internal/bootstrap/worker_test.go`
- Modify if needed: `admin_back_go/internal/bootstrap/resources_test.go`
- Modify if needed: `admin_back_go/internal/module/queuemonitor/asynqmon_test.go`
- Modify any other file found by compile errors

- [ ] **Step 1: Find removed field references**

Run:

```powershell
cd E:\admin_go\admin_back_go
rg -n "DefaultQueue|CriticalWeight|DefaultWeight|LowWeight|ShutdownTimeout|DefaultMaxRetry|DefaultTimeout" internal --glob '!module/queuemonitor/asynqmonui/build/**' --glob '!**/*.map'
```

Expected after Tasks 2-3, remaining hits should be legitimate taskqueue constants/tests or stale test struct literals. Stale hits look like:

```text
config.QueueConfig{DefaultQueue: ...}
config.QueueConfig{CriticalWeight: ...}
```

- [ ] **Step 2: Update `worker_test.go` disabled queue config**

In `TestNewWorkerReturnsQueueDisabledWorker`, replace the queue config block with:

```go
		Queue: config.QueueConfig{
			Enabled: false,
		},
```

Keep assertions that worker queue client/server/scheduler are nil as they are.

- [ ] **Step 3: Update `worker_test.go` enabled queue configs**

For tests that need queue enabled, replace verbose queue config blocks with:

```go
		Queue: config.QueueConfig{
			Enabled:     true,
			RedisDB:     3,
			Concurrency: 2,
		},
```

If a test only needs construction and not specific concurrency, use:

```go
		Queue: config.QueueConfig{Enabled: true, RedisDB: 3, Concurrency: 1},
```

- [ ] **Step 4: Update `resources_test.go` if compile fails**

If `resources_test.go` has stale policy fields, replace queue configs with one of:

```go
Queue: config.QueueConfig{Enabled: true, RedisDB: 3}
```

or:

```go
Queue: config.QueueConfig{Enabled: false, RedisDB: 3}
```

Preserve each test's enabled/disabled intent.

- [ ] **Step 5: Update `asynqmon_test.go` if compile fails**

If asynqmon tests construct `config.QueueConfig`, keep only Redis DB:

```go
config.QueueConfig{RedisDB: 3}
```

- [ ] **Step 6: Run focused compile/tests**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/config ./internal/platform/taskqueue ./internal/bootstrap ./internal/module/queuemonitor
```

Expected:

```text
ok  	admin_back_go/internal/config
ok  	admin_back_go/internal/platform/taskqueue
ok  	admin_back_go/internal/bootstrap
ok  	admin_back_go/internal/module/queuemonitor
```

---

## Task 5: Shrink Docker-first env files

**Files:**
- Modify: `admin_back_go/deploy/docker-first/admin-go.env.example`
- Modify: `admin_back_go/deploy/docker-first/admin-go.env` if present

- [ ] **Step 1: Remove deprecated queue policy lines from env example**

In `admin_back_go/deploy/docker-first/admin-go.env.example`, replace the queue block:

```env
QUEUE_ENABLED=true
QUEUE_REDIS_DB=3
QUEUE_CONCURRENCY=10
QUEUE_DEFAULT_QUEUE=default
QUEUE_CRITICAL_WEIGHT=6
QUEUE_DEFAULT_WEIGHT=3
QUEUE_LOW_WEIGHT=1
QUEUE_SHUTDOWN_TIMEOUT=10s
QUEUE_DEFAULT_MAX_RETRY=3
QUEUE_DEFAULT_TIMEOUT=30s
```

with:

```env
QUEUE_ENABLED=true
QUEUE_REDIS_DB=3
QUEUE_CONCURRENCY=10
```

- [ ] **Step 2: Apply the same local env cleanup**

If `admin_back_go/deploy/docker-first/admin-go.env` exists, make the same replacement there:

```env
QUEUE_ENABLED=true
QUEUE_REDIS_DB=3
QUEUE_CONCURRENCY=10
```

Do not change secrets, DSN, Redis address, or other env groups.

- [ ] **Step 3: Run config test guard**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/config
```

Expected:

```text
ok  	admin_back_go/internal/config
```

---

## Task 6: Update backend architecture/docs contract

**Files:**
- Modify: `admin_back_go/docs/architecture.md`
- Modify: `docs/contracts/admin-api-v1.md`
- Modify: `docs/deployment/docker-first-backend.md`
- Modify if active references remain: `docs/deployment/local.md`, `docs/deployment/production.md`, `docs/architecture/04-go-backend-framework.md`, `docs/architecture/05-development-quality-rules.md`

- [ ] **Step 1: Locate all active deprecated queue env references**

Run from repo root:

```powershell
cd E:\admin_go
rg -n "QUEUE_DEFAULT_QUEUE|QUEUE_CRITICAL_WEIGHT|QUEUE_DEFAULT_WEIGHT|QUEUE_LOW_WEIGHT|QUEUE_SHUTDOWN_TIMEOUT|QUEUE_DEFAULT_MAX_RETRY|QUEUE_DEFAULT_TIMEOUT" docs admin_back_go/docs admin_back_go/deploy --glob '!**/*.map'
```

Expected before docs cleanup: references in architecture/deployment/contract docs and env examples.

- [ ] **Step 2: Update `admin_back_go/docs/architecture.md` env list**

Where the architecture document lists queue env keys, keep only:

```text
QUEUE_ENABLED
QUEUE_REDIS_DB
QUEUE_CONCURRENCY
```

Replace explanatory text for removed policy keys with:

```text
Queue lane names (`critical` / `default` / `low`), lane weights (`6/3/1`), default retry (`3`), default task timeout (`30s`), and worker shutdown timeout (`10s`) are code-owned defaults in `internal/platform/taskqueue`; Docker-first env does not expose them.
```

- [ ] **Step 3: Update `docs/contracts/admin-api-v1.md` queue runtime contract**

Add or update a short runtime note near the queue/scheduler behavior section:

```markdown
Docker-first queue env only exposes `QUEUE_ENABLED`, `QUEUE_REDIS_DB`, and `QUEUE_CONCURRENCY`. Queue lane names (`critical` / `default` / `low`), lane weights (`6/3/1`), default retry (`3`), default task timeout (`30s`), and worker shutdown timeout (`10s`) are code-owned defaults. They are not `system_settings` keys and are not part of the public Docker-first env contract.
```

Remove statements that describe removed queue policy keys as env contract.

- [ ] **Step 4: Update Docker-first backend runbook**

In `docs/deployment/docker-first-backend.md`, ensure the queue sample or explanation shows only:

```env
QUEUE_ENABLED=true
QUEUE_REDIS_DB=3
QUEUE_CONCURRENCY=10
```

Add this explanation near the env section:

```markdown
Queue lane names, lane weights, default retry/timeout, and worker shutdown timeout are fixed Go defaults. Deployment only controls whether queue is enabled, which Redis DB Asynq uses, and per-worker concurrency.
```

- [ ] **Step 5: Update local/production docs if they still mention removed keys**

For `docs/deployment/local.md` and `docs/deployment/production.md`, remove removed keys from env examples. If tuning text exists, keep only this concept:

```markdown
Tune `QUEUE_CONCURRENCY` according to worker node capacity. Do not tune queue lane weights through env; lane policy is code-owned.
```

- [ ] **Step 6: Verify no active deprecated queue env docs remain**

Run:

```powershell
cd E:\admin_go
rg -n "QUEUE_DEFAULT_QUEUE|QUEUE_CRITICAL_WEIGHT|QUEUE_DEFAULT_WEIGHT|QUEUE_LOW_WEIGHT|QUEUE_SHUTDOWN_TIMEOUT|QUEUE_DEFAULT_MAX_RETRY|QUEUE_DEFAULT_TIMEOUT" docs admin_back_go/docs admin_back_go/deploy --glob '!**/*.map'
```

Expected after cleanup:

```text
```

No output for active docs/deploy paths. It is acceptable if this implementation plan or the spec contains those names; do not include `docs/superpowers` in this final no-output command.

---

## Task 7: Final verification and commit

**Files:**
- Verify all modified files
- Commit backend and root changes separately if both repos are dirty

- [ ] **Step 1: Format Go files**

Run:

```powershell
cd E:\admin_go\admin_back_go
gofmt -w internal/config/config.go internal/config/config_test.go internal/platform/taskqueue/client.go internal/platform/taskqueue/client_test.go internal/platform/taskqueue/server.go internal/platform/taskqueue/server_test.go internal/bootstrap/worker_test.go internal/bootstrap/resources_test.go internal/module/queuemonitor/asynqmon_test.go
```

If a listed file was not changed, `gofmt` is still safe. If a file does not exist, remove it from the command and rerun.

- [ ] **Step 2: Run focused backend tests**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/config ./internal/platform/taskqueue ./internal/bootstrap ./internal/module/queuemonitor
```

Expected:

```text
ok  	admin_back_go/internal/config
ok  	admin_back_go/internal/platform/taskqueue
ok  	admin_back_go/internal/bootstrap
ok  	admin_back_go/internal/module/queuemonitor
```

- [ ] **Step 3: Run repo governance checks**

Run:

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected:

```text
git diff --check exits 0
Outcome: PASS or PASS_WITH_WARNINGS with no blocking governance violations
```

If governance prints docs-sync warnings for queue paths, check Task 6 references and update active docs before continuing.

- [ ] **Step 4: Inspect git status by repo**

Run:

```powershell
cd E:\admin_go
git status --short --branch
git -C admin_back_go status --short --branch
git -C admin_front_ts status --short --branch
```

Expected:

```text
root repo: docs changes only, possibly ahead from spec/plan commits
backend repo: config/taskqueue/deploy/docs changes
frontend repo: clean
```

- [ ] **Step 5: Commit backend implementation**

If `admin_back_go` has changes, commit them from the backend repo:

```powershell
cd E:\admin_go\admin_back_go
git add internal/config/config.go internal/config/config_test.go internal/platform/taskqueue/client.go internal/platform/taskqueue/client_test.go internal/platform/taskqueue/server.go internal/platform/taskqueue/server_test.go internal/bootstrap/worker_test.go internal/bootstrap/resources_test.go internal/module/queuemonitor/asynqmon_test.go deploy/docker-first/admin-go.env.example docs/architecture.md
git status --short
git commit -m "refactor: internalize queue policy defaults"
```

If `admin-go.env` is ignored/local, it will not be committed; still mention it in the final evidence if modified.

- [ ] **Step 6: Commit root docs**

If root docs changed, commit them from root:

```powershell
cd E:\admin_go
git add docs/contracts/admin-api-v1.md docs/deployment/docker-first-backend.md docs/deployment/local.md docs/deployment/production.md docs/architecture/04-go-backend-framework.md docs/architecture/05-development-quality-rules.md docs/superpowers/plans/2026-05-20-queue-env-cleanup-implementation.md
git status --short
git commit -m "docs: plan queue env cleanup"
```

If only the implementation plan changed in root, still commit the plan with the same message.

- [ ] **Step 7: Final clean verification**

Run:

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
git status --short --branch
git -C admin_back_go status --short --branch
git -C admin_front_ts status --short --branch
```

Expected:

```text
PASS
root ahead by new plan/docs commits, clean working tree
backend ahead by implementation commit, clean working tree
frontend clean
```

Do not push unless the user explicitly says `push吧`.

---

## Optional runtime verification after implementation

Run this if the user asks to start/restart backend or if code changes touch startup in a way that needs live proof:

```powershell
cd E:\admin_go\admin_back_go\deploy\docker-first
docker compose up -d --build admin-api admin-worker
curl.exe -fsS http://127.0.0.1:8080/health
curl.exe -fsS http://127.0.0.1:8080/ready
docker compose ps
```

Expected `/ready` queue-related result when queue is enabled:

```json
"queue_redis":{"status":"up"}
```

If `QUEUE_ENABLED=false`, expected queue readiness is `disabled`, not `up`.
