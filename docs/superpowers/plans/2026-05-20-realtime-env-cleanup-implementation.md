# Realtime Env Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Shrink Docker-first realtime env to `REALTIME_ENABLED` and `REALTIME_PUBLISHER` while preserving current WebSocket, Redis Pub/Sub fan-out, heartbeat, and slow-client protection behavior.

**Architecture:** Keep deployment-controlled realtime availability and publisher topology in `config.RealtimeConfig`. Move Redis channel, heartbeat interval, and send buffer to code-owned defaults in the config/bootstrap boundary so `admin-api` and `admin-worker` share one stable policy without exposing low-level WebSocket tuning in env or `system_settings`.

**Tech Stack:** Go, gorilla/websocket, Redis Pub/Sub, existing `internal/config`, existing `internal/bootstrap`, existing `internal/module/realtime`, PowerShell governance checks, Docker-first env templates.

---

## Design constraints

- Do not change WebSocket path: `GET /api/admin/v1/realtime/ws`.
- Do not change frontend realtime URL, cookie-token auth, envelope schema, or topic names.
- Do not move realtime policy to `system_settings`.
- Do not change `CORS_ALLOW_ORIGINS`; Origin allowlist remains env-owned.
- Keep `REALTIME_ENABLED=false` behavior: WebSocket upgrade returns 503 and readiness reports `realtime=disabled`.
- Keep `REALTIME_PUBLISHER=local|noop|redis` behavior:
  - `local`: API process local session delivery.
  - `noop`: WebSocket still works, business publication is dropped.
  - `redis`: API subscribes, worker publishes through Redis Pub/Sub.
- Keep code-owned runtime defaults:
  - Redis channel: `admin_go:realtime:publish`
  - Heartbeat interval: `25s`
  - Send buffer: `16`
- Keep Docker-first default:
  - `REALTIME_ENABLED=true`
  - `REALTIME_PUBLISHER=redis`
- Do not touch queue, scheduler, AI timeout, token, MySQL, Redis, CORS, payment, upload, captcha, or verify-code env groups in this slice.

## File map

### Backend code and tests

- Modify: `admin_back_go/internal/config/config.go`
  - Add exported realtime policy default constants.
  - Stop reading `REALTIME_REDIS_CHANNEL`, `REALTIME_HEARTBEAT_INTERVAL`, and `REALTIME_SEND_BUFFER` from env.
  - Keep `RealtimeConfig` fields because bootstrap still needs the resolved values.
- Modify: `admin_back_go/internal/config/config_test.go`
  - Update override test so deprecated realtime policy env values are ignored.
  - Add Docker-first env guard for deprecated realtime policy keys.
  - Keep default assertions for resolved realtime policy values.
- Modify: `admin_back_go/internal/bootstrap/realtime.go`
  - Normalize zero-value realtime policy fields to code defaults before constructing service, handler, publisher, and subscriber.
- Modify: `admin_back_go/internal/bootstrap/worker.go`
  - Normalize zero-value realtime channel before constructing worker Redis publisher.
- Modify: `admin_back_go/internal/bootstrap/realtime_test.go`
  - Add regression coverage that direct zero-value `RealtimeConfig` still uses code defaults.
- Modify: `admin_back_go/internal/bootstrap/worker_test.go`
  - Add regression coverage that worker Redis publisher uses code-owned default channel when channel is omitted.

### Deploy/docs

- Modify: `admin_back_go/deploy/docker-first/admin-go.env.example`
  - Remove `REALTIME_REDIS_CHANNEL`, `REALTIME_HEARTBEAT_INTERVAL`, and `REALTIME_SEND_BUFFER`.
- Modify: `admin_back_go/deploy/docker-first/admin-go.env`
  - Remove the same three keys if the local ignored file exists.
- Modify: `docs/contracts/admin-realtime-v1.md`
  - Update realtime config contract so only `REALTIME_ENABLED` and `REALTIME_PUBLISHER` are env-owned.
  - Document code-owned defaults for channel, heartbeat, and send buffer.
- Modify: `docs/architecture/06-realtime-and-distributed-boundary.md`
  - Replace active env examples and send-buffer text with code-owned default language.
- Modify: `admin_back_go/docs/architecture.md`
  - Replace active env listing and runtime contract for realtime defaults.
- Modify: `admin_back_go/README.md`
  - Replace active env examples so Docker-first users see only `REALTIME_ENABLED` and `REALTIME_PUBLISHER`.
- Modify if `rg` finds active references outside historical specs/plans:
  - `docs/deployment/docker-first-backend.md`
  - `docs/deployment/local.md`
  - `docs/deployment/production.md`
  - `docs/contracts/admin-api-v1.md`
  - `docs/testing/smoke-matrix.md`
  - `docs/status/current-status.md`

Historical files under `docs/superpowers/specs` and `docs/superpowers/plans` may keep old discussion references unless they are the current realtime cleanup spec/plan.

---

## Task 1: Config tests first

**Files:**
- Modify: `admin_back_go/internal/config/config_test.go`

- [ ] **Step 1: Add a failing guard for Docker-first realtime env keys**

Add this test after `TestDockerFirstEnvDocumentsOnlyQueueRuntimeKnobs` in `admin_back_go/internal/config/config_test.go`:

```go
func TestDockerFirstEnvDocumentsOnlyRealtimeRuntimeKnobs(t *testing.T) {
	for _, fileName := range []string{"admin-go.env", "admin-go.env.example"} {
		values := readDockerFirstEnvIfExists(t, fileName)
		if len(values) == 0 {
			continue
		}
		if got := values["REALTIME_ENABLED"]; got != "true" {
			t.Fatalf("deploy/docker-first/%s must keep REALTIME_ENABLED=true, got %q", fileName, got)
		}
		if got := values["REALTIME_PUBLISHER"]; got != RealtimePublisherRedis {
			t.Fatalf("deploy/docker-first/%s must keep REALTIME_PUBLISHER=redis, got %q", fileName, got)
		}
		for _, key := range deprecatedRealtimePolicyEnvKeys() {
			if _, ok := values[key]; ok {
				t.Fatalf("deploy/docker-first/%s must not document realtime policy key %s", fileName, key)
			}
		}
	}
}

func deprecatedRealtimePolicyEnvKeys() []string {
	return []string{
		"REALTIME_REDIS_CHANNEL",
		"REALTIME_HEARTBEAT_INTERVAL",
		"REALTIME_SEND_BUFFER",
	}
}
```

- [ ] **Step 2: Update `TestLoadUsesSafeDefaults` to assert code-owned realtime defaults through constants**

In `TestLoadUsesSafeDefaults`, replace the existing realtime policy literal assertions:

```go
	if cfg.Realtime.HeartbeatInterval != 25*time.Second {
		t.Fatalf("expected realtime heartbeat interval 25s, got %s", cfg.Realtime.HeartbeatInterval)
	}
	if cfg.Realtime.SendBuffer != 16 {
		t.Fatalf("expected realtime send buffer 16, got %d", cfg.Realtime.SendBuffer)
	}
	if cfg.Realtime.RedisChannel != "admin_go:realtime:publish" {
		t.Fatalf("expected realtime redis channel default, got %q", cfg.Realtime.RedisChannel)
	}
```

with:

```go
	if cfg.Realtime.HeartbeatInterval != DefaultRealtimeHeartbeatInterval {
		t.Fatalf("expected realtime heartbeat interval %s, got %s", DefaultRealtimeHeartbeatInterval, cfg.Realtime.HeartbeatInterval)
	}
	if cfg.Realtime.SendBuffer != DefaultRealtimeSendBuffer {
		t.Fatalf("expected realtime send buffer %d, got %d", DefaultRealtimeSendBuffer, cfg.Realtime.SendBuffer)
	}
	if cfg.Realtime.RedisChannel != DefaultRealtimeRedisChannel {
		t.Fatalf("expected realtime redis channel default %q, got %q", DefaultRealtimeRedisChannel, cfg.Realtime.RedisChannel)
	}
```

- [ ] **Step 3: Update env override test so realtime policy env values are ignored**

In `TestLoadReadsEnvironmentOverrides`, keep the old policy env values intentionally set as regression input:

```go
	t.Setenv("REALTIME_ENABLED", "false")
	t.Setenv("REALTIME_PUBLISHER", "noop")
	t.Setenv("REALTIME_HEARTBEAT_INTERVAL", "10s")
	t.Setenv("REALTIME_SEND_BUFFER", "32")
	t.Setenv("REALTIME_REDIS_CHANNEL", "test:realtime")
```

Replace the realtime assertions with:

```go
	if cfg.Realtime.Enabled {
		t.Fatalf("expected realtime enabled override to false")
	}
	if cfg.Realtime.Publisher != RealtimePublisherNoop {
		t.Fatalf("expected realtime publisher noop, got %q", cfg.Realtime.Publisher)
	}
	if cfg.Realtime.HeartbeatInterval != DefaultRealtimeHeartbeatInterval ||
		cfg.Realtime.SendBuffer != DefaultRealtimeSendBuffer ||
		cfg.Realtime.RedisChannel != DefaultRealtimeRedisChannel {
		t.Fatalf("realtime policy env must be ignored, got %#v", cfg.Realtime)
	}
```

- [ ] **Step 4: Run config tests and verify RED**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/config
```

Expected before implementation:

```text
FAIL
deploy/docker-first/admin-go.env must not document realtime policy key REALTIME_REDIS_CHANNEL
```

If `admin-go.env` is absent, the same failure should appear for `admin-go.env.example`.

- [ ] **Step 5: Commit the failing tests**

Commit only the test change:

```powershell
cd E:\admin_go\admin_back_go
git add internal/config/config_test.go
git commit -m "test: guard realtime env cleanup"
```

Expected:

```text
[master abc1234] test: guard realtime env cleanup
```

---

## Task 2: Config implementation

**Files:**
- Modify: `admin_back_go/internal/config/config.go`
- Modify: `admin_back_go/internal/config/config_test.go`

- [ ] **Step 1: Add code-owned realtime default constants**

In `admin_back_go/internal/config/config.go`, replace:

```go
const (
	RealtimePublisherLocal = "local"
	RealtimePublisherNoop  = "noop"
	RealtimePublisherRedis = "redis"
)
```

with:

```go
const (
	RealtimePublisherLocal = "local"
	RealtimePublisherNoop  = "noop"
	RealtimePublisherRedis = "redis"

	DefaultRealtimeRedisChannel      = "admin_go:realtime:publish"
	DefaultRealtimeHeartbeatInterval = 25 * time.Second
	DefaultRealtimeSendBuffer        = 16
)
```

- [ ] **Step 2: Stop reading deprecated realtime policy env keys**

In `config.Load()`, replace the `Realtime` block:

```go
		Realtime: RealtimeConfig{
			Enabled:           envBool("REALTIME_ENABLED", true),
			Publisher:         envString("REALTIME_PUBLISHER", RealtimePublisherLocal),
			HeartbeatInterval: envDuration("REALTIME_HEARTBEAT_INTERVAL", 25*time.Second),
			SendBuffer:        envInt("REALTIME_SEND_BUFFER", 16),
			RedisChannel:      envString("REALTIME_REDIS_CHANNEL", "admin_go:realtime:publish"),
		},
```

with:

```go
		Realtime: RealtimeConfig{
			Enabled:           envBool("REALTIME_ENABLED", true),
			Publisher:         envString("REALTIME_PUBLISHER", RealtimePublisherLocal),
			HeartbeatInterval: DefaultRealtimeHeartbeatInterval,
			SendBuffer:        DefaultRealtimeSendBuffer,
			RedisChannel:      DefaultRealtimeRedisChannel,
		},
```

- [ ] **Step 3: Run config tests and verify remaining RED is deploy env only**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/config
```

Expected at this point:

```text
FAIL
deploy/docker-first/admin-go.env must not document realtime policy key REALTIME_REDIS_CHANNEL
```

The env override assertion must no longer fail; only deploy files still contain deprecated keys.

- [ ] **Step 4: Commit config implementation**

Commit:

```powershell
cd E:\admin_go\admin_back_go
git add internal/config/config.go internal/config/config_test.go
git commit -m "refactor: internalize realtime policy defaults"
```

Expected:

```text
[master abc1234] refactor: internalize realtime policy defaults
```

---

## Task 3: Bootstrap default normalization

**Files:**
- Modify: `admin_back_go/internal/bootstrap/realtime.go`
- Modify: `admin_back_go/internal/bootstrap/worker.go`
- Modify: `admin_back_go/internal/bootstrap/realtime_test.go`
- Modify: `admin_back_go/internal/bootstrap/worker_test.go`

- [ ] **Step 1: Add bootstrap tests for zero-value policy defaults**

In `admin_back_go/internal/bootstrap/realtime_test.go`, add `reflect` to the imports:

```go
import (
	"errors"
	"reflect"
	"testing"
	"time"

	"admin_back_go/internal/config"
	platformrealtime "admin_back_go/internal/platform/realtime"
)
```

Add these helpers and test after `TestNewRealtimeStackUsesRedisPublisherAndSubscriberWhenConfigured`:

```go
func TestNewRealtimeStackAppliesCodeOwnedRealtimeDefaults(t *testing.T) {
	stack := newRealtimeStack(config.RealtimeConfig{
		Enabled:   true,
		Publisher: config.RealtimePublisherRedis,
	})

	if !stack.enabled {
		t.Fatalf("expected realtime stack to be enabled")
	}
	if got := realtimePublisherChannel(t, stack.publisher); got != config.DefaultRealtimeRedisChannel {
		t.Fatalf("expected redis publisher channel %q, got %q", config.DefaultRealtimeRedisChannel, got)
	}
	if got := realtimeSubscriberChannel(t, stack.subscriber); got != config.DefaultRealtimeRedisChannel {
		t.Fatalf("expected redis subscriber channel %q, got %q", config.DefaultRealtimeRedisChannel, got)
	}
	if got := realtimeHandlerHeartbeat(t, stack.handler); got != config.DefaultRealtimeHeartbeatInterval {
		t.Fatalf("expected handler heartbeat %s, got %s", config.DefaultRealtimeHeartbeatInterval, got)
	}
	if got := realtimeHandlerSendBuffer(t, stack.handler); got != config.DefaultRealtimeSendBuffer {
		t.Fatalf("expected handler send buffer %d, got %d", config.DefaultRealtimeSendBuffer, got)
	}
}

func realtimePublisherChannel(t *testing.T, publisher platformrealtime.Publisher) string {
	t.Helper()
	value := reflect.ValueOf(publisher)
	if value.Kind() != reflect.Pointer || value.IsNil() {
		t.Fatalf("expected pointer publisher, got %T", publisher)
	}
	field := value.Elem().FieldByName("channel")
	if !field.IsValid() {
		t.Fatalf("publisher %T has no channel field", publisher)
	}
	return field.String()
}

func realtimeSubscriberChannel(t *testing.T, subscriber *platformrealtime.RedisSubscriber) string {
	t.Helper()
	if subscriber == nil {
		t.Fatalf("expected redis subscriber")
	}
	field := reflect.ValueOf(subscriber).Elem().FieldByName("channel")
	if !field.IsValid() {
		t.Fatalf("subscriber has no channel field")
	}
	return field.String()
}

func realtimeHandlerHeartbeat(t *testing.T, handler any) time.Duration {
	t.Helper()
	value := reflect.ValueOf(handler)
	if value.Kind() != reflect.Pointer || value.IsNil() {
		t.Fatalf("expected pointer handler, got %T", handler)
	}
	service := value.Elem().FieldByName("service")
	if !service.IsValid() || service.IsNil() {
		t.Fatalf("handler has no service field")
	}
	heartbeat := service.Elem().FieldByName("heartbeatInterval")
	if !heartbeat.IsValid() {
		t.Fatalf("service has no heartbeatInterval field")
	}
	return time.Duration(heartbeat.Int())
}

func realtimeHandlerSendBuffer(t *testing.T, handler any) int {
	t.Helper()
	value := reflect.ValueOf(handler)
	if value.Kind() != reflect.Pointer || value.IsNil() {
		t.Fatalf("expected pointer handler, got %T", handler)
	}
	field := value.Elem().FieldByName("sendBuffer")
	if !field.IsValid() {
		t.Fatalf("handler has no sendBuffer field")
	}
	return int(field.Int())
}
```

In `admin_back_go/internal/bootstrap/worker_test.go`, add `reflect` to the imports:

```go
import (
	"log/slog"
	"reflect"
	"strings"
	"testing"

	"admin_back_go/internal/config"
	platformrealtime "admin_back_go/internal/platform/realtime"
)
```

Add this test after `TestRealtimePublisherForWorkerUsesRedisOnlyForCrossProcessFanout`:

```go
func TestRealtimePublisherForWorkerUsesCodeOwnedDefaultChannel(t *testing.T) {
	workerPublisher := realtimePublisherForWorker(config.Config{
		Realtime: config.RealtimeConfig{Enabled: true, Publisher: config.RealtimePublisherRedis},
	}, &Resources{})

	if _, ok := workerPublisher.(*platformrealtime.RedisPublisher); !ok {
		t.Fatalf("expected worker redis publisher, got %T", workerPublisher)
	}
	if got := realtimePublisherChannelFromWorkerTest(t, workerPublisher); got != config.DefaultRealtimeRedisChannel {
		t.Fatalf("expected worker redis publisher channel %q, got %q", config.DefaultRealtimeRedisChannel, got)
	}
}

func realtimePublisherChannelFromWorkerTest(t *testing.T, publisher platformrealtime.Publisher) string {
	t.Helper()
	value := reflect.ValueOf(publisher)
	if value.Kind() != reflect.Pointer || value.IsNil() {
		t.Fatalf("expected pointer publisher, got %T", publisher)
	}
	field := value.Elem().FieldByName("channel")
	if !field.IsValid() {
		t.Fatalf("publisher %T has no channel field", publisher)
	}
	return field.String()
}
```

- [ ] **Step 2: Run bootstrap tests and verify RED**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/bootstrap
```

Expected before implementation:

```text
FAIL
expected redis publisher channel "admin_go:realtime:publish", got ""
```

- [ ] **Step 3: Normalize realtime config in bootstrap**

In `admin_back_go/internal/bootstrap/realtime.go`, add this helper near the top of the file after the `realtimeStack` struct:

```go
func withRealtimePolicyDefaults(cfg config.RealtimeConfig) config.RealtimeConfig {
	if cfg.HeartbeatInterval <= 0 {
		cfg.HeartbeatInterval = config.DefaultRealtimeHeartbeatInterval
	}
	if cfg.SendBuffer <= 0 {
		cfg.SendBuffer = config.DefaultRealtimeSendBuffer
	}
	if cfg.RedisChannel == "" {
		cfg.RedisChannel = config.DefaultRealtimeRedisChannel
	}
	return cfg
}
```

Then update `newRealtimeStackWithRedis` so its first statement after logger selection is:

```go
	cfg = withRealtimePolicyDefaults(cfg)
```

The beginning of `newRealtimeStackWithRedis` should look like:

```go
func newRealtimeStackWithRedis(cfg config.RealtimeConfig, allowedOrigins []string, redis *redisclient.Client, loggers ...*slog.Logger) realtimeStack {
	logger := slog.Default()
	if len(loggers) > 0 && loggers[0] != nil {
		logger = loggers[0]
	}
	cfg = withRealtimePolicyDefaults(cfg)

	enabled := realtimeEnabledFor(cfg, logger)
```

- [ ] **Step 4: Use the same normalization in worker publisher**

In `admin_back_go/internal/bootstrap/worker.go`, update `realtimePublisherForWorker` so it normalizes `cfg.Realtime` before checking the publisher:

```go
func realtimePublisherForWorker(cfg config.Config, resources *Resources) platformrealtime.Publisher {
	realtimeConfig := withRealtimePolicyDefaults(cfg.Realtime)
	if !realtimeConfig.Enabled {
		return platformrealtime.NoopPublisher{}
	}
	publisherName := realtimeConfig.Publisher
	if publisherName == "" {
		publisherName = config.RealtimePublisherLocal
	}
	switch publisherName {
	case config.RealtimePublisherRedis:
		if resources == nil || resources.Redis == nil || resources.Redis.Redis == nil {
			return platformrealtime.NewRedisPublisher(nil, realtimeConfig.RedisChannel)
		}
		return platformrealtime.NewRedisPublisher(resources.Redis.Redis, realtimeConfig.RedisChannel)
	case config.RealtimePublisherNoop:
		return platformrealtime.NoopPublisher{}
	case config.RealtimePublisherLocal:
		// Worker has no WebSocket sessions. Local mode would be a fake cross-process
		// fan-out, so keep it explicitly disabled in the worker.
		return platformrealtime.NoopPublisher{}
	default:
		return platformrealtime.NoopPublisher{}
	}
}
```

- [ ] **Step 5: Run bootstrap tests and verify GREEN**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/bootstrap
```

Expected:

```text
ok  	admin_back_go/internal/bootstrap
```

- [ ] **Step 6: Commit bootstrap normalization**

Commit:

```powershell
cd E:\admin_go\admin_back_go
git add internal/bootstrap/realtime.go internal/bootstrap/worker.go internal/bootstrap/realtime_test.go internal/bootstrap/worker_test.go
git commit -m "refactor: apply realtime code defaults in bootstrap"
```

Expected:

```text
[master abc1234] refactor: apply realtime code defaults in bootstrap
```

---

## Task 4: Docker-first env cleanup

**Files:**
- Modify: `admin_back_go/deploy/docker-first/admin-go.env.example`
- Modify: `admin_back_go/deploy/docker-first/admin-go.env`

- [ ] **Step 1: Remove deprecated realtime policy keys from Docker-first env example**

In `admin_back_go/deploy/docker-first/admin-go.env.example`, replace:

```env
REALTIME_ENABLED=true
REALTIME_PUBLISHER=redis
REALTIME_REDIS_CHANNEL=admin_go:realtime:publish
REALTIME_HEARTBEAT_INTERVAL=25s
REALTIME_SEND_BUFFER=16
```

with:

```env
REALTIME_ENABLED=true
REALTIME_PUBLISHER=redis
```

- [ ] **Step 2: Remove deprecated realtime policy keys from local Docker-first env**

If `admin_back_go/deploy/docker-first/admin-go.env` exists, make the same replacement:

```env
REALTIME_ENABLED=true
REALTIME_PUBLISHER=redis
```

Do not change local MySQL, Redis, APP_SECRET, or CORS values in this ignored file.

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

- [ ] **Step 4: Check env files no longer contain deprecated realtime policy keys**

Run:

```powershell
cd E:\admin_go
rg -n "REALTIME_REDIS_CHANNEL|REALTIME_HEARTBEAT_INTERVAL|REALTIME_SEND_BUFFER" admin_back_go/deploy/docker-first/admin-go.env admin_back_go/deploy/docker-first/admin-go.env.example
```

Expected:

```text
no output
```

- [ ] **Step 5: Commit env cleanup**

Commit tracked file changes. If `admin-go.env` is ignored, it will not be included in git but should remain locally cleaned for Docker runtime tests.

```powershell
cd E:\admin_go\admin_back_go
git add deploy/docker-first/admin-go.env.example
git commit -m "deploy: shrink realtime docker env"
```

Expected:

```text
[master abc1234] deploy: shrink realtime docker env
```

---

## Task 5: Active docs cleanup

**Files:**
- Modify: `docs/contracts/admin-realtime-v1.md`
- Modify: `docs/architecture/06-realtime-and-distributed-boundary.md`
- Modify: `docs/deployment/docker-first-backend.md`
- Modify: `docs/deployment/local.md`
- Modify: `docs/deployment/production.md`
- Modify: `docs/contracts/admin-api-v1.md`
- Modify: `docs/testing/smoke-matrix.md`
- Modify: `docs/status/current-status.md`
- Modify: `admin_back_go/docs/architecture.md`
- Modify: `admin_back_go/README.md`

- [ ] **Step 1: Update realtime contract config block**

In `docs/contracts/admin-realtime-v1.md`, replace the current config block:

```text
REALTIME_ENABLED=true|false
REALTIME_PUBLISHER=local|noop|redis
REALTIME_REDIS_CHANNEL=admin_go:realtime:publish
REALTIME_HEARTBEAT_INTERVAL=25s
REALTIME_SEND_BUFFER=16
```

with:

```text
REALTIME_ENABLED=true|false
REALTIME_PUBLISHER=local|noop|redis
```

Immediately below that block, add:

```text
代码内置 realtime policy：

Redis Pub/Sub channel: admin_go:realtime:publish
Heartbeat interval: 25s
Send buffer per connection: 16

这些值不是 Docker-first env，也不进 system_settings。REALTIME_PUBLISHER=redis 时，admin-api 和 admin-worker 使用同一份代码默认 channel。
```

- [ ] **Step 2: Update distributed boundary docs**

In `docs/architecture/06-realtime-and-distributed-boundary.md`, replace the active send-buffer env text:

```text
REALTIME_SEND_BUFFER=16
```

and its following explanation with:

```text
当前 send queue buffer 由代码默认值控制：

DefaultRealtimeSendBuffer = 16

默认 16；队列满就关闭连接，这是故意的 slow-client drop policy，不做无界缓存。这个值不放 Docker-first env，也不进 system_settings。
```

Replace deployment examples that show:

```text
REALTIME_ENABLED=true
REALTIME_PUBLISHER=redis
REALTIME_REDIS_CHANNEL=admin_go:realtime:publish
REALTIME_HEARTBEAT_INTERVAL=25s
REALTIME_SEND_BUFFER=16
```

with:

```text
REALTIME_ENABLED=true
REALTIME_PUBLISHER=redis
```

Add this sentence near the publisher mode explanation:

```text
Redis Pub/Sub channel、heartbeat interval、send buffer 都是代码内置默认值；Docker-first env 只暴露启用开关和 publisher 拓扑。
```

- [ ] **Step 3: Update backend architecture docs and README**

In `admin_back_go/docs/architecture.md` and `admin_back_go/README.md`, replace any active runtime env list containing:

```text
REALTIME_REDIS_CHANNEL
REALTIME_HEARTBEAT_INTERVAL
REALTIME_SEND_BUFFER
```

with this wording:

```text
Docker-first realtime env 只保留：

REALTIME_ENABLED=true
REALTIME_PUBLISHER=redis

代码内置：Redis Pub/Sub channel admin_go:realtime:publish、heartbeat interval 25s、send buffer 16。
```

Keep text explaining `local` / `noop` / `redis` publisher modes.

- [ ] **Step 4: Update deployment docs**

In `docs/deployment/docker-first-backend.md`, ensure the minimal env section contains:

```env
REALTIME_ENABLED=true
REALTIME_PUBLISHER=redis
```

Add or keep this explanation:

```text
Docker-first Realtime env 只保留启用开关和 publisher 拓扑。Redis Pub/Sub channel、25s heartbeat、每连接 16 条 send buffer 是 Go 代码内置默认值，不通过 env 或 system_settings 配置。
```

In `docs/deployment/local.md`, replace old local realtime env examples with:

```env
REALTIME_ENABLED=true
REALTIME_PUBLISHER=local
```

In `docs/deployment/production.md`, replace old production realtime env examples with:

```env
REALTIME_ENABLED=true
REALTIME_PUBLISHER=local
```

or keep `redis` only where the text explicitly talks about multi-process fan-out:

```env
REALTIME_ENABLED=true
REALTIME_PUBLISHER=redis
```

- [ ] **Step 5: Update contract/status references**

Use this search to find active references:

```powershell
cd E:\admin_go
rg -n "REALTIME_REDIS_CHANNEL|REALTIME_HEARTBEAT_INTERVAL|REALTIME_SEND_BUFFER" admin_back_go/docs admin_back_go/README.md docs/contracts docs/deployment docs/architecture docs/testing docs/status --glob '!**/*.map'
```

For each active reference outside historical superpowers files, apply this replacement rule:

```text
Do not list these keys as env.
State that channel=admin_go:realtime:publish, heartbeat=25s, send_buffer=16 are code-owned defaults.
```

- [ ] **Step 6: Verify active docs cleanup**

Run:

```powershell
cd E:\admin_go
rg -n "REALTIME_REDIS_CHANNEL|REALTIME_HEARTBEAT_INTERVAL|REALTIME_SEND_BUFFER" admin_back_go/docs admin_back_go/README.md docs/contracts docs/deployment docs/architecture docs/testing docs/status --glob '!**/*.map'
```

Expected:

```text
no output
```

Then run a broader search that may still show historical specs/plans:

```powershell
cd E:\admin_go
rg -n "REALTIME_REDIS_CHANNEL|REALTIME_HEARTBEAT_INTERVAL|REALTIME_SEND_BUFFER" docs/superpowers admin_back_go/deploy admin_back_go/internal --glob '!**/*.map'
```

Expected allowed hits:

```text
docs/superpowers/specs/2026-05-20-realtime-env-cleanup-design.md
docs/superpowers/plans/2026-05-20-realtime-env-cleanup-implementation.md
```

No hits should remain in `admin_back_go/deploy/docker-first/*.env*`.

- [ ] **Step 7: Commit docs cleanup**

Commit:

```powershell
cd E:\admin_go
git add docs/contracts/admin-realtime-v1.md docs/architecture/06-realtime-and-distributed-boundary.md docs/deployment/docker-first-backend.md docs/deployment/local.md docs/deployment/production.md docs/contracts/admin-api-v1.md docs/testing/smoke-matrix.md docs/status/current-status.md admin_back_go/docs/architecture.md admin_back_go/README.md
git commit -m "docs: update realtime env contract"
```

If some listed files were not changed, `git add` may print no error and simply stage changed paths. Verify with:

```powershell
git status --short
```

Expected:

```text
no unstaged tracked docs changes except ignored local admin-go.env
```

---

## Task 6: Targeted tests and Docker-first runtime

**Files:**
- No source edits expected unless tests expose a compile error.

- [ ] **Step 1: Run targeted backend tests**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./cmd/admin-api ./cmd/admin-worker ./internal/config ./internal/bootstrap ./internal/module/realtime ./internal/platform/realtime
```

Expected:

```text
ok  	admin_back_go/cmd/admin-api
ok  	admin_back_go/cmd/admin-worker
ok  	admin_back_go/internal/config
ok  	admin_back_go/internal/bootstrap
ok  	admin_back_go/internal/module/realtime
ok  	admin_back_go/internal/platform/realtime
```

- [ ] **Step 2: Rebuild and restart Docker-first backend**

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

- [ ] **Step 3: Verify health and readiness**

Run:

```powershell
cd E:\admin_go\admin_back_go\deploy\docker-first
curl.exe -fsS http://127.0.0.1:8080/health
curl.exe -fsS http://127.0.0.1:8080/ready
```

Expected:

```text
/health returns success JSON
/ready returns success JSON with database, redis, token_redis, queue_redis, realtime up
```

If `/ready` fails because local MySQL/Redis containers are intentionally stopped, do not patch code. Start state services from the existing Docker-first state runbook or report the exact down check.

- [ ] **Step 4: Commit runtime verification docs if no source changes are needed**

If Task 6 required no code/doc edits, do not create an empty commit. Record the command outputs in the final response.

If a compile/runtime fix was needed, commit only the actual files changed by that fix. For example, if the fix touched bootstrap normalization, run:

```powershell
cd E:\admin_go\admin_back_go
git add internal/bootstrap/realtime.go internal/bootstrap/worker.go
git commit -m "fix: keep realtime defaults stable at runtime"
```

---

## Task 7: Final governance and residue checks

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
root ahead by plan/docs commits, clean
backend ahead by implementation commits, clean
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
rg -n "REALTIME_REDIS_CHANNEL|REALTIME_HEARTBEAT_INTERVAL|REALTIME_SEND_BUFFER" admin_back_go/deploy admin_back_go/docs admin_back_go/README.md docs/contracts docs/deployment docs/architecture docs/testing docs/status --glob '!**/*.map'
```

Expected:

```text
no output
```

- [ ] **Step 4: Prepare final report**

Final report must include:

```text
Outcome:
- Realtime Docker-first env now keeps only REALTIME_ENABLED and REALTIME_PUBLISHER.
- REALTIME_REDIS_CHANNEL, REALTIME_HEARTBEAT_INTERVAL, and REALTIME_SEND_BUFFER are code-owned defaults.

Evidence:
- backend test command and PASS output summary
- Docker compose ps summary
- /ready summary with realtime up
- governance PASS summary
- commit hashes for backend/root

Not done:
- no runtime behavior change beyond default source
- no system_settings migration
- no frontend changes
- no push unless user explicitly says push
```

Do not say runtime is verified unless Task 6 actually ran and passed in the current turn.
