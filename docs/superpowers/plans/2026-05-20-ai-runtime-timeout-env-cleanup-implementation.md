# AI Runtime Timeout Env Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove `AI_CHAT_STREAM_MAX_DURATION`, `AI_CHAT_STREAM_IDLE_TIMEOUT`, and `AI_RUN_STALE_TIMEOUT` from Docker-first env while preserving the current `5m` / `60s` / `15m` runtime behavior as code-owned defaults.

**Architecture:** Keep AI runtime timeout policy inside Go code, not env and not `system_settings`. `internal/config` owns the public default constants and normalization function; bootstrap normalizes zero-value `AIConfig` before wiring API/worker services. Backend module/platform packages may keep their local fallback behavior, but bootstrap must pass normalized values and tests must prove old env keys are ignored.

**Tech Stack:** Go 1.x, standard `time.Duration`, existing `internal/config`, `internal/bootstrap`, `internal/module/aichat`, `internal/platform/ai/openaicompat`, Docker Compose, Markdown docs.

---

## Scope Check

This plan covers one narrow subsystem: AI runtime timeout env cleanup. It does not change AI provider config, AI agent config, AI chat protocol, run monitor schema/UI, scheduler cron rows, queue behavior, or frontend code.

## File Map

Backend repo `E:\admin_go\admin_back_go`:

- Modify `internal/config/config.go`
  - Add AI timeout default constants.
  - Add `NormalizeAIConfig`.
  - Stop reading the three deprecated `AI_*TIMEOUT` env keys.
- Modify `internal/config/config_test.go`
  - Prove defaults are `5m` / `60s` / `15m`.
  - Prove old env keys are ignored.
  - Prove Docker-first env files do not document these deprecated keys.
- Modify `internal/bootstrap/app.go`
  - Normalize `cfg.AI` in API bootstrap.
  - Use code-owned AI defaults in `aiReplyTimeout`, stream idle timeout, and run stale timeout fallback.
- Modify `internal/bootstrap/worker.go`
  - Normalize `cfg.AI` in worker bootstrap.
  - Use code-owned AI defaults for worker `aichat.Service`.
- Modify `internal/bootstrap/ai_reply_dispatcher_test.go`
  - Make the default timeout assertion use `config.DefaultAIChatStreamMaxDuration`.
- Modify `deploy/docker-first/admin-go.env.example`
  - Remove the three AI timeout keys.
- Modify local ignored `deploy/docker-first/admin-go.env`
  - Remove the same three keys for local Docker-first testing. This file is not committed.
- Modify `docs/architecture.md`
  - Remove these keys from active env list.
  - Update AI timeout wording to code-owned runtime guardrails.

Root repo `E:\admin_go`:

- Modify `docs/contracts/admin-api-v1.md`
  - Replace raw env names with code-owned runtime guardrail wording.
- Modify `docs/testing/smoke-matrix.md`
  - Replace `AI_RUN_STALE_TIMEOUT` wording.
- Modify `docs/status/current-status.md`
  - Replace `AI_RUN_STALE_TIMEOUT` wording in current AI/system cron status.

No SQL migration. No `system_settings` row. No frontend changes.

---

### Task 1: Make `internal/config` own AI timeout defaults and ignore old env

**Files:**
- Modify: `E:\admin_go\admin_back_go\internal\config\config.go`
- Modify: `E:\admin_go\admin_back_go\internal\config\config_test.go`

- [ ] **Step 1: Update config tests first**

In `internal/config/config_test.go`, update the AI assertions in `TestLoadUsesSafeDefaults` to use named defaults:

```go
	if cfg.AI.ChatStreamMaxDuration != DefaultAIChatStreamMaxDuration {
		t.Fatalf("expected AI chat stream max duration %s, got %s", DefaultAIChatStreamMaxDuration, cfg.AI.ChatStreamMaxDuration)
	}
	if cfg.AI.ChatStreamIdleTimeout != DefaultAIChatStreamIdleTimeout {
		t.Fatalf("expected AI chat stream idle timeout %s, got %s", DefaultAIChatStreamIdleTimeout, cfg.AI.ChatStreamIdleTimeout)
	}
	if cfg.AI.RunStaleTimeout != DefaultAIRunStaleTimeout {
		t.Fatalf("expected AI run stale timeout %s, got %s", DefaultAIRunStaleTimeout, cfg.AI.RunStaleTimeout)
	}
```

In `TestLoadReadsEnvironmentOverrides`, keep these three old env assignments:

```go
	t.Setenv("AI_CHAT_STREAM_MAX_DURATION", "3m")
	t.Setenv("AI_CHAT_STREAM_IDLE_TIMEOUT", "45s")
	t.Setenv("AI_RUN_STALE_TIMEOUT", "20m")
```

Replace the old assertion that expected `3m` / `45s` / `20m` with:

```go
	if cfg.AI.ChatStreamMaxDuration != DefaultAIChatStreamMaxDuration ||
		cfg.AI.ChatStreamIdleTimeout != DefaultAIChatStreamIdleTimeout ||
		cfg.AI.RunStaleTimeout != DefaultAIRunStaleTimeout {
		t.Fatalf("AI runtime timeout env must be ignored, got %#v", cfg.AI)
	}
```

Add these tests near `TestNormalizeSchedulerConfigAppliesCodeOwnedDefaults`:

```go
func TestNormalizeAIConfigAppliesCodeOwnedDefaults(t *testing.T) {
	cfg := NormalizeAIConfig(AIConfig{})

	if cfg.ChatStreamMaxDuration != DefaultAIChatStreamMaxDuration {
		t.Fatalf("expected default AI chat stream max duration %s, got %s", DefaultAIChatStreamMaxDuration, cfg.ChatStreamMaxDuration)
	}
	if cfg.ChatStreamIdleTimeout != DefaultAIChatStreamIdleTimeout {
		t.Fatalf("expected default AI chat stream idle timeout %s, got %s", DefaultAIChatStreamIdleTimeout, cfg.ChatStreamIdleTimeout)
	}
	if cfg.RunStaleTimeout != DefaultAIRunStaleTimeout {
		t.Fatalf("expected default AI run stale timeout %s, got %s", DefaultAIRunStaleTimeout, cfg.RunStaleTimeout)
	}
}

func TestNormalizeAIConfigPreservesExplicitValues(t *testing.T) {
	cfg := NormalizeAIConfig(AIConfig{
		ChatStreamMaxDuration: 7 * time.Minute,
		ChatStreamIdleTimeout: 90 * time.Second,
		RunStaleTimeout:       22 * time.Minute,
	})

	if cfg.ChatStreamMaxDuration != 7*time.Minute {
		t.Fatalf("expected explicit AI chat stream max duration 7m, got %s", cfg.ChatStreamMaxDuration)
	}
	if cfg.ChatStreamIdleTimeout != 90*time.Second {
		t.Fatalf("expected explicit AI chat stream idle timeout 90s, got %s", cfg.ChatStreamIdleTimeout)
	}
	if cfg.RunStaleTimeout != 22*time.Minute {
		t.Fatalf("expected explicit AI run stale timeout 22m, got %s", cfg.RunStaleTimeout)
	}
}
```

- [ ] **Step 2: Run the focused failing test**

```powershell
cd E:\admin_go\admin_back_go
go test -count=1 ./internal/config
```

Expected now: failure with undefined names such as `DefaultAIChatStreamMaxDuration` and `NormalizeAIConfig`.

- [ ] **Step 3: Add AI defaults and normalization**

In `internal/config/config.go`, directly after `type AIConfig struct { ... }`, add:

```go
const (
	DefaultAIChatStreamMaxDuration = 5 * time.Minute
	DefaultAIChatStreamIdleTimeout = 60 * time.Second
	DefaultAIRunStaleTimeout       = 15 * time.Minute
)

func NormalizeAIConfig(cfg AIConfig) AIConfig {
	if cfg.ChatStreamMaxDuration <= 0 {
		cfg.ChatStreamMaxDuration = DefaultAIChatStreamMaxDuration
	}
	if cfg.ChatStreamIdleTimeout <= 0 {
		cfg.ChatStreamIdleTimeout = DefaultAIChatStreamIdleTimeout
	}
	if cfg.RunStaleTimeout <= 0 {
		cfg.RunStaleTimeout = DefaultAIRunStaleTimeout
	}
	return cfg
}
```

In `Load()`, replace the current AI block:

```go
		AI: AIConfig{
			ChatStreamMaxDuration: envDuration("AI_CHAT_STREAM_MAX_DURATION", 5*time.Minute),
			ChatStreamIdleTimeout: envDuration("AI_CHAT_STREAM_IDLE_TIMEOUT", 60*time.Second),
			RunStaleTimeout:       envDuration("AI_RUN_STALE_TIMEOUT", 15*time.Minute),
		},
```

with:

```go
		AI: NormalizeAIConfig(AIConfig{}),
```

- [ ] **Step 4: Format and verify config**

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
git commit -m "refactor: internalize AI timeout defaults"
```

---

### Task 2: Normalize AI defaults in API and worker bootstrap

**Files:**
- Modify: `E:\admin_go\admin_back_go\internal\bootstrap\app.go`
- Modify: `E:\admin_go\admin_back_go\internal\bootstrap\worker.go`
- Modify: `E:\admin_go\admin_back_go\internal\bootstrap\ai_reply_dispatcher_test.go`

- [ ] **Step 1: Update dispatcher timeout test first**

In `internal/bootstrap/ai_reply_dispatcher_test.go`, add this import:

```go
	"admin_back_go/internal/config"
```

Update `TestAIReplyTimeoutAddsCompletionWindow`:

```go
func TestAIReplyTimeoutAddsCompletionWindow(t *testing.T) {
	if got := aiReplyTimeout(3 * time.Minute); got != 3*time.Minute+30*time.Second {
		t.Fatalf("expected 3m30s reply timeout, got %s", got)
	}
	if got := aiReplyTimeout(0); got != config.DefaultAIChatStreamMaxDuration+30*time.Second {
		t.Fatalf("expected default %s reply timeout, got %s", config.DefaultAIChatStreamMaxDuration+30*time.Second, got)
	}
}
```

- [ ] **Step 2: Run the focused bootstrap test**

```powershell
cd E:\admin_go\admin_back_go
go test -count=1 ./internal/bootstrap
```

Expected now: failure until `aiReplyTimeout` uses the config default constant, or pass if the literal still matches. The test still protects against future drift.

- [ ] **Step 3: Normalize API bootstrap config**

In `internal/bootstrap/app.go`, update `New` near the logger default:

```go
func New(cfg config.Config, logger *slog.Logger) (*App, error) {
	if logger == nil {
		logger = slog.Default()
	}
	cfg.AI = config.NormalizeAIConfig(cfg.AI)
	if err := config.ValidateRuntimeSecrets(cfg); err != nil {
		return nil, err
	}
```

Update `aiReplyTimeout`:

```go
func aiReplyTimeout(maxDuration time.Duration) time.Duration {
	return positiveDuration(maxDuration, config.DefaultAIChatStreamMaxDuration) + 30*time.Second
}
```

Update AI service wiring in `New`:

```go
		EngineFactory:    aiChatEngineFactory{streamIdleTimeout: positiveDuration(cfg.AI.ChatStreamIdleTimeout, config.DefaultAIChatStreamIdleTimeout)},
```

and:

```go
		RunStaleTimeout:  positiveDuration(cfg.AI.RunStaleTimeout, config.DefaultAIRunStaleTimeout),
```

Update `aiChatEngineFactory.NewEngine`:

```go
			StreamIdleTimeout: positiveDuration(f.streamIdleTimeout, config.DefaultAIChatStreamIdleTimeout),
```

- [ ] **Step 4: Normalize worker bootstrap config**

In `internal/bootstrap/worker.go`, update `NewWorker` near existing scheduler normalization:

```go
func NewWorker(cfg config.Config, logger *slog.Logger) (*Worker, error) {
	if logger == nil {
		logger = slog.Default()
	}
	cfg.Scheduler = config.NormalizeSchedulerConfig(cfg.Scheduler)
	cfg.AI = config.NormalizeAIConfig(cfg.AI)
	if err := config.ValidateRuntimeSecrets(cfg); err != nil {
		return nil, err
	}
```

Update worker AI service wiring:

```go
		EngineFactory:   aiChatEngineFactory{streamIdleTimeout: positiveDuration(cfg.AI.ChatStreamIdleTimeout, config.DefaultAIChatStreamIdleTimeout)},
		RunStaleTimeout: positiveDuration(cfg.AI.RunStaleTimeout, config.DefaultAIRunStaleTimeout),
```

- [ ] **Step 5: Format and verify bootstrap**

```powershell
cd E:\admin_go\admin_back_go
gofmt -w internal/bootstrap/app.go internal/bootstrap/worker.go internal/bootstrap/ai_reply_dispatcher_test.go
go test -count=1 ./internal/bootstrap
```

Expected: `ok admin_back_go/internal/bootstrap`.

- [ ] **Step 6: Commit backend bootstrap change**

```powershell
cd E:\admin_go\admin_back_go
git add internal/bootstrap/app.go internal/bootstrap/worker.go internal/bootstrap/ai_reply_dispatcher_test.go
git commit -m "refactor: normalize AI timeout defaults at bootstrap"
```

---

### Task 3: Remove AI timeout keys from Docker-first env files and guard tests

**Files:**
- Modify: `E:\admin_go\admin_back_go\internal\config\config_test.go`
- Modify: `E:\admin_go\admin_back_go\deploy\docker-first\admin-go.env.example`
- Modify local ignored file: `E:\admin_go\admin_back_go\deploy\docker-first\admin-go.env`

- [ ] **Step 1: Replace the old env-example assertion with a forbidden-key guard**

In `internal/config/config_test.go`, delete `TestEnvExampleDocumentsAITimeouts`.

Add this guard near the scheduler/realtime Docker-first guards:

```go
func TestDockerFirstEnvDoesNotDocumentAITimeoutPolicy(t *testing.T) {
	for _, fileName := range []string{"admin-go.env", "admin-go.env.example"} {
		values := readDockerFirstEnvIfExists(t, fileName)
		if len(values) == 0 {
			continue
		}
		for _, key := range deprecatedAITimeoutEnvKeys() {
			if _, ok := values[key]; ok {
				t.Fatalf("deploy/docker-first/%s must not document AI timeout policy key %s", fileName, key)
			}
		}
	}
}

func deprecatedAITimeoutEnvKeys() []string {
	return []string{
		"AI_CHAT_STREAM_MAX_DURATION",
		"AI_CHAT_STREAM_IDLE_TIMEOUT",
		"AI_RUN_STALE_TIMEOUT",
	}
}
```

- [ ] **Step 2: Run config test to prove the guard fails before env cleanup**

```powershell
cd E:\admin_go\admin_back_go
go test -count=1 ./internal/config
```

Expected before env cleanup: failure like `must not document AI timeout policy key AI_CHAT_STREAM_MAX_DURATION`.

- [ ] **Step 3: Delete the three keys from Docker-first env template**

In `deploy/docker-first/admin-go.env.example`, remove:

```env
AI_CHAT_STREAM_MAX_DURATION=5m
AI_CHAT_STREAM_IDLE_TIMEOUT=60s
AI_RUN_STALE_TIMEOUT=15m
```

Keep `SCHEDULER_ENABLED=true` immediately after the realtime section:

```env
REALTIME_ENABLED=true
REALTIME_PUBLISHER=redis

# Keep scheduler enabled on only one worker cluster owner.
SCHEDULER_ENABLED=true
```

- [ ] **Step 4: Delete the same keys from local ignored env**

In `deploy/docker-first/admin-go.env`, remove:

```env
AI_CHAT_STREAM_MAX_DURATION=5m
AI_CHAT_STREAM_IDLE_TIMEOUT=60s
AI_RUN_STALE_TIMEOUT=15m
```

This file is ignored and should not be added to git, but it is read by the config guard if present.

- [ ] **Step 5: Verify Docker-first config tests and Compose**

```powershell
cd E:\admin_go\admin_back_go
gofmt -w internal/config/config_test.go
go test -count=1 ./internal/config
cd E:\admin_go\admin_back_go\deploy\docker-first
docker compose config --quiet
```

Expected:

```text
ok admin_back_go/internal/config
```

`docker compose config --quiet` should print no output.

- [ ] **Step 6: Commit backend deploy cleanup**

```powershell
cd E:\admin_go\admin_back_go
git add internal/config/config_test.go deploy/docker-first/admin-go.env.example
git commit -m "deploy: remove AI timeout docker env"
```

Do not add `deploy/docker-first/admin-go.env`.

---

### Task 4: Update active docs and contract wording

**Files:**
- Modify: `E:\admin_go\admin_back_go\docs\architecture.md`
- Modify: `E:\admin_go\docs\contracts\admin-api-v1.md`
- Modify: `E:\admin_go\docs\testing\smoke-matrix.md`
- Modify: `E:\admin_go\docs\status\current-status.md`

- [ ] **Step 1: Update backend architecture env list**

In `admin_back_go/docs/architecture.md`, remove these three lines from the active env list:

```text
AI_CHAT_STREAM_MAX_DURATION
AI_CHAT_STREAM_IDLE_TIMEOUT
AI_RUN_STALE_TIMEOUT
```

Keep:

```text
REALTIME_ENABLED
REALTIME_PUBLISHER
SCHEDULER_ENABLED
CORS_ALLOW_ORIGINS
```

- [ ] **Step 2: Update backend architecture AI timeout wording**

In `admin_back_go/docs/architecture.md`, replace:

```text
OpenAI-compatible StreamChat does not use a 30s HTTP total timeout while reading response body; live max duration comes from AI_CHAT_STREAM_MAX_DURATION and upstream silence comes from AI_CHAT_STREAM_IDLE_TIMEOUT.
ai_run_timeout is stale cleanup only: admin-worker marks running rows older than AI_RUN_STALE_TIMEOUT, not fresh online replies.
```

with:

```text
OpenAI-compatible StreamChat does not use a 30s HTTP total timeout while reading response body; live max duration and upstream silence timeout are code-owned AI runtime guardrails, not Docker-first env knobs.
ai_run_timeout is stale cleanup only: admin-worker marks running rows older than the code-owned AI run stale timeout default, not fresh online replies.
```

- [ ] **Step 3: Update admin API contract AI chat wording**

In `docs/contracts/admin-api-v1.md`, replace the bullet containing all three raw env names with:

```markdown
- AI chat streaming timeout is layered: provider stream reads do not use a 30s total HTTP timeout; live reply max duration, upstream silence timeout, and stale-run cleanup window are code-owned runtime guardrails, not Docker-first env knobs; `ai_run_timeout` only marks stale running rows older than the stale-run cleanup window
```

- [ ] **Step 4: Update admin API contract stale-run rule**

In `docs/contracts/admin-api-v1.md`, replace:

```markdown
- worker marks only stale `running` rows as `timeout`: `status='running' AND started_at IS NOT NULL AND started_at < now - AI_RUN_STALE_TIMEOUT`
```

with:

```markdown
- worker marks only stale `running` rows as `timeout`: `status='running' AND started_at IS NOT NULL AND started_at < now - code-owned AI run stale timeout default`
```

Replace the Chinese stale-run note:

```markdown
`ai_run_timeout` 是 stale-run sweeper only：worker 只处理 `status='running' AND started_at < now - AI_RUN_STALE_TIMEOUT` 的残留运行，不负责正常在线流式请求超时。
```

with:

```markdown
`ai_run_timeout` 是 stale-run sweeper only：worker 只处理超过代码内置 AI run stale timeout 默认值的残留 `running` 运行，不负责正常在线流式请求超时。
```

- [ ] **Step 5: Update smoke matrix**

In `docs/testing/smoke-matrix.md`, replace:

```text
ai_run_timeout 由 Go registry 投递 ai:run-timeout:v1；aichat worker handler 只扫描并标记超过 AI_RUN_STALE_TIMEOUT 的残留 running ai_runs
```

with:

```text
ai_run_timeout 由 Go registry 投递 ai:run-timeout:v1；aichat worker handler 只扫描并标记超过代码内置 AI run stale timeout 默认值的残留 running ai_runs
```

- [ ] **Step 6: Update current status**

In `docs/status/current-status.md`, replace `AI_RUN_STALE_TIMEOUT` in the system cron tasks row with:

```text
the code-owned AI run stale timeout default
```

The sentence should read:

```text
`notification_task_scheduler` maps to `notification:dispatch-due:v1`, `ai_run_timeout` maps to `ai:run-timeout:v1` and only sweeps stale running AI runs older than the code-owned AI run stale timeout default, and old handler strings are legacy provenance only for missing rows
```

- [ ] **Step 7: Verify active docs no longer expose deprecated env names**

```powershell
cd E:\admin_go
rg -n "AI_CHAT_STREAM_MAX_DURATION|AI_CHAT_STREAM_IDLE_TIMEOUT|AI_RUN_STALE_TIMEOUT" admin_back_go/deploy admin_back_go/docs admin_back_go/README.md docs/contracts docs/testing docs/status --glob "!**/*.map"
```

Expected: no output.

This scan intentionally excludes `docs/superpowers` because historical specs/plans keep old env names as provenance.

- [ ] **Step 8: Commit backend and root docs**

Backend docs commit:

```powershell
cd E:\admin_go\admin_back_go
git add docs/architecture.md
git commit -m "docs: update AI timeout runtime contract"
```

Root docs commit:

```powershell
cd E:\admin_go
git add docs/contracts/admin-api-v1.md docs/testing/smoke-matrix.md docs/status/current-status.md
git commit -m "docs: align AI timeout env cleanup"
```

---

### Task 5: Full verification and final cleanliness check

**Files:**
- No direct code edits in this task.

- [ ] **Step 1: Run backend focused tests**

```powershell
cd E:\admin_go\admin_back_go
go test -count=1 ./internal/config ./internal/bootstrap ./internal/platform/ai/openaicompat ./internal/module/aichat
```

Expected:

```text
ok admin_back_go/internal/config
ok admin_back_go/internal/bootstrap
ok admin_back_go/internal/platform/ai/openaicompat
ok admin_back_go/internal/module/aichat
```

- [ ] **Step 2: Run worker-adjacent tests**

```powershell
cd E:\admin_go\admin_back_go
go test -count=1 ./cmd/admin-worker ./internal/jobs ./internal/platform/taskqueue
```

Expected:

```text
?  admin_back_go/cmd/admin-worker [no test files]
ok admin_back_go/internal/jobs
ok admin_back_go/internal/platform/taskqueue
```

- [ ] **Step 3: Run vet**

```powershell
cd E:\admin_go\admin_back_go
go vet ./internal/config ./internal/bootstrap ./internal/platform/ai/openaicompat ./internal/module/aichat
```

Expected: no output.

- [ ] **Step 4: Validate Docker-first Compose**

```powershell
cd E:\admin_go\admin_back_go\deploy\docker-first
docker compose config --quiet
```

Expected: no output.

- [ ] **Step 5: Re-run active deprecated-env scan**

```powershell
cd E:\admin_go
rg -n "AI_CHAT_STREAM_MAX_DURATION|AI_CHAT_STREAM_IDLE_TIMEOUT|AI_RUN_STALE_TIMEOUT" admin_back_go/deploy admin_back_go/docs admin_back_go/README.md docs/contracts docs/testing docs/status --glob "!**/*.map"
```

Expected: no output.

- [ ] **Step 6: Run required repo checks**

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected:

```text
PASS: no blocking governance violations found.
```

- [ ] **Step 7: Confirm git status across repos**

```powershell
cd E:\admin_go
git status --short
git -C admin_back_go status --short
git -C admin_front_ts status --short
```

Expected:

```text
```

No output means all three working trees are clean. `admin_back_go/deploy/docker-first/admin-go.env` is ignored, so it should not appear.

---

## Self-Review

- Spec coverage:
  - Docker-first env deletion: Task 3.
  - Code-owned defaults: Task 1 and Task 2.
  - No `system_settings` / no SQL: File map and Task 3/4 avoid database changes.
  - Behavior unchanged at `5m` / `60s` / `15m`: Task 1 tests and Task 2 bootstrap constants.
  - Active docs updated: Task 4.
  - Full verification: Task 5.
- Placeholder scan:
  - No deferred implementation markers.
  - Every code-changing step includes exact code snippets or exact text replacements.
- Type consistency:
  - `DefaultAIChatStreamMaxDuration`, `DefaultAIChatStreamIdleTimeout`, `DefaultAIRunStaleTimeout`, and `NormalizeAIConfig` are introduced in `internal/config` before later tasks use them.
  - Bootstrap already imports `admin_back_go/internal/config`, so no new cross-package dependency is needed there.
