# Logging Env Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Docker-first logging env keeps only `LOG_DIR`, while logging file names, rotation, file-extension whitelist, and tail limits become code-owned defaults.

**Architecture:** `internal/config` remains the single startup config boundary. `Load()` will read only `LOG_DIR` for logging and will construct all other logging values from code defaults before `platform/logging` and `platform/logstore` consume them. No `system_settings` row is added because logging must work before DB readiness.

**Tech Stack:** Go, `log/slog`, `gopkg.in/natefinch/lumberjack.v2`, existing `internal/platform/logging`, existing `internal/platform/logstore`, Docker Compose env files, Markdown docs.

---

## File map

Backend repo `E:\admin_go\admin_back_go`:

- Modify `internal/config/config.go`
  - Add `DefaultLoggingConfig()` and logging default constants.
  - Change `Load()` so logging reads only `LOG_DIR` from env.
- Modify `internal/config/logging_test.go`
  - Prove deprecated logging env keys are ignored and `LOG_DIR` is the only logging env override.
- Modify `internal/config/logging_process_test.go`
  - Prove process-specific file names come from code defaults, not env.
- Modify `internal/config/config_test.go`
  - Prove Docker-first `admin-go.env.example` and local ignored `admin-go.env` document only `LOG_DIR` from the logging env group.
- Modify `deploy/docker-first/admin-go.env.example`
  - Remove every logging env key except `LOG_DIR=/app/runtime/logs`.
- Modify ignored local file `deploy/docker-first/admin-go.env`
  - Mirror the same logging env cleanup so local tests pass; do not stage this ignored file.
- Modify `docs/architecture.md`
  - Update system log baseline to say logging strategy is code-owned and Docker env only controls `LOG_DIR`.

Root repo `E:\admin_go`:

- Modify `docs/contracts/admin-api-v1.md`
  - Update System Logs contract wording for code-owned logging defaults.
- Modify `docs/deployment/docker-first-backend.md`
  - Document that Docker-first env only exposes `LOG_DIR` for logging.
- Modify `docs/status/current-status.md`
  - Update system logs row with logging env cleanup state.
- Keep `docs/testing/smoke-matrix.md` unchanged unless implementation-time scan finds a literal `LOG_` logging env mention; current scan shows none.

No database migration and no frontend change are required.

---

### Task 1: Add failing config/env tests

**Files:**
- Modify: `E:\admin_go\admin_back_go\internal\config\logging_test.go`
- Modify: `E:\admin_go\admin_back_go\internal\config\logging_process_test.go`
- Modify: `E:\admin_go\admin_back_go\internal\config\config_test.go`

- [ ] **Step 1: Replace `logging_test.go` with a test that treats old logging env keys as ignored**

Replace the whole file `E:\admin_go\admin_back_go\internal\config\logging_test.go` with:

```go
package config

import (
	"path/filepath"
	"reflect"
	"testing"
)

func TestLoadReadsOnlyLogDirFromEnvironment(t *testing.T) {
	t.Setenv("LOG_DIR", filepath.Join("custom", "logs"))
	t.Setenv("LOG_ENABLE_FILE", "false")
	t.Setenv("LOG_FILE_NAME", "legacy.log")
	t.Setenv("LOG_API_FILE_NAME", "api-custom.log")
	t.Setenv("LOG_WORKER_FILE_NAME", "worker-custom.log")
	t.Setenv("LOG_MAX_TAIL_LINES", "1000")
	t.Setenv("LOG_ALLOWED_EXTENSIONS", ".log,.jsonl")
	t.Setenv("LOG_FILE_MAX_SIZE_MB", "1")
	t.Setenv("LOG_FILE_MAX_BACKUPS", "1")
	t.Setenv("LOG_FILE_MAX_AGE_DAYS", "1")
	t.Setenv("LOG_FILE_COMPRESS", "false")

	cfg := Load()

	if !cfg.Logging.EnableFile {
		t.Fatalf("LOG_ENABLE_FILE must be code-owned and default true")
	}
	if cfg.Logging.Dir != filepath.Join("custom", "logs") {
		t.Fatalf("expected LOG_DIR override to be used, got %q", cfg.Logging.Dir)
	}
	if cfg.Logging.FileName != "admin-api.log" || cfg.Logging.APIFileName != "admin-api.log" {
		t.Fatalf("api log file names must be code-owned defaults, got %#v", cfg.Logging)
	}
	if cfg.Logging.WorkerFileName != "admin-worker.log" {
		t.Fatalf("worker log file name must be code-owned default, got %#v", cfg.Logging)
	}
	if cfg.Logging.MaxTailLines != 2000 {
		t.Fatalf("max tail lines must be code-owned default 2000, got %d", cfg.Logging.MaxTailLines)
	}
	if !reflect.DeepEqual(cfg.Logging.AllowedExtensions, []string{".log"}) {
		t.Fatalf("allowed extensions must be code-owned .log only, got %#v", cfg.Logging.AllowedExtensions)
	}
	if cfg.Logging.FileMaxSizeMB != 64 || cfg.Logging.FileMaxBackups != 7 || cfg.Logging.FileMaxAgeDays != 14 || !cfg.Logging.FileCompress {
		t.Fatalf("file rotation config must be code-owned defaults, got %#v", cfg.Logging)
	}
}
```

- [ ] **Step 2: Replace `logging_process_test.go` with process-name tests that do not set env**

Replace the whole file `E:\admin_go\admin_back_go\internal\config\logging_process_test.go` with:

```go
package config

import "testing"

func TestLoggingConfigForProcessUsesDedicatedWorkerFile(t *testing.T) {
	cfg := Load()
	workerLogging := cfg.Logging.ForProcess("admin-worker")

	if workerLogging.FileName != "admin-worker.log" {
		t.Fatalf("expected admin-worker to write admin-worker.log, got %q", workerLogging.FileName)
	}
	if cfg.Logging.FileName != "admin-api.log" {
		t.Fatalf("ForProcess must not mutate base config, got %q", cfg.Logging.FileName)
	}
}

func TestLoggingConfigForProcessKeepsAPIFile(t *testing.T) {
	cfg := Load()
	apiLogging := cfg.Logging.ForProcess("admin-api")

	if apiLogging.FileName != "admin-api.log" {
		t.Fatalf("expected admin-api to write admin-api.log, got %q", apiLogging.FileName)
	}
}
```

- [ ] **Step 3: Add Docker-first logging env guard to `config_test.go`**

In `E:\admin_go\admin_back_go\internal\config\config_test.go`, insert this test after `TestDockerFirstEnvDoesNotDocumentVerifyCodeRuntimePolicy`:

```go
func TestDockerFirstEnvDocumentsOnlyLogDir(t *testing.T) {
	for _, fileName := range []string{"admin-go.env", "admin-go.env.example"} {
		values := readDockerFirstEnvIfExists(t, fileName)
		if len(values) == 0 {
			continue
		}
		if got := values["LOG_DIR"]; got != "/app/runtime/logs" {
			t.Fatalf("deploy/docker-first/%s must keep LOG_DIR=/app/runtime/logs, got %q", fileName, got)
		}
		for _, key := range deprecatedLoggingEnvKeys() {
			if _, ok := values[key]; ok {
				t.Fatalf("deploy/docker-first/%s must not document logging policy key %s", fileName, key)
			}
		}
	}
}

func deprecatedLoggingEnvKeys() []string {
	return []string{
		"LOG_ENABLE_FILE",
		"LOG_FILE_NAME",
		"LOG_API_FILE_NAME",
		"LOG_WORKER_FILE_NAME",
		"LOG_MAX_TAIL_LINES",
		"LOG_ALLOWED_EXTENSIONS",
		"LOG_FILE_MAX_SIZE_MB",
		"LOG_FILE_MAX_BACKUPS",
		"LOG_FILE_MAX_AGE_DAYS",
		"LOG_FILE_COMPRESS",
	}
}
```

- [ ] **Step 4: Run the focused test and confirm it fails before implementation**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test -count=1 ./internal/config
```

Expected: FAIL. At least one failure must mention either old `LOG_*` values still overriding code defaults or Docker-first env still documenting deprecated logging keys.

---

### Task 2: Internalize logging defaults and shrink Docker env files

**Files:**
- Modify: `E:\admin_go\admin_back_go\internal\config\config.go`
- Modify: `E:\admin_go\admin_back_go\deploy\docker-first\admin-go.env.example`
- Modify ignored local file: `E:\admin_go\admin_back_go\deploy\docker-first\admin-go.env`

- [ ] **Step 1: Add code-owned logging defaults to `config.go`**

In `E:\admin_go\admin_back_go\internal\config\config.go`, after `type LoggingConfig struct { ... }`, add:

```go
const (
	defaultLogDir            = "runtime/logs"
	defaultAPIFileName       = "admin-api.log"
	defaultWorkerFileName    = "admin-worker.log"
	defaultMaxTailLines      = 2000
	defaultFileMaxSizeMB     = 64
	defaultFileMaxBackups    = 7
	defaultFileMaxAgeDays    = 14
	defaultLogFileCompress   = true
	defaultLogFileEnableFile = true
)

func DefaultLoggingConfig() LoggingConfig {
	return LoggingConfig{
		EnableFile:        defaultLogFileEnableFile,
		Dir:               filepath.FromSlash(defaultLogDir),
		FileName:          defaultAPIFileName,
		APIFileName:       defaultAPIFileName,
		WorkerFileName:    defaultWorkerFileName,
		MaxTailLines:      defaultMaxTailLines,
		AllowedExtensions: []string{".log"},
		FileMaxSizeMB:     defaultFileMaxSizeMB,
		FileMaxBackups:    defaultFileMaxBackups,
		FileMaxAgeDays:    defaultFileMaxAgeDays,
		FileCompress:      defaultLogFileCompress,
	}
}
```

- [ ] **Step 2: Change `Load()` so logging reads only `LOG_DIR`**

In `Load()`, delete this line:

```go
	logFileName := envString("LOG_FILE_NAME", "admin-api.log")
```

Immediately after CORS env loading, add:

```go
	loggingConfig := DefaultLoggingConfig()
	loggingConfig.Dir = envString("LOG_DIR", loggingConfig.Dir)
```

Replace the current `Logging: LoggingConfig{...},` literal with:

```go
		Logging: loggingConfig,
```

The resulting `Load()` must not contain these env reads:

```go
envBool("LOG_ENABLE_FILE", true)
envString("LOG_FILE_NAME", "admin-api.log")
envString("LOG_API_FILE_NAME", logFileName)
envString("LOG_WORKER_FILE_NAME", "admin-worker.log")
envInt("LOG_MAX_TAIL_LINES", 2000)
envCSV("LOG_ALLOWED_EXTENSIONS", []string{".log"})
envInt("LOG_FILE_MAX_SIZE_MB", 64)
envInt("LOG_FILE_MAX_BACKUPS", 7)
envInt("LOG_FILE_MAX_AGE_DAYS", 14)
envBool("LOG_FILE_COMPRESS", true)
```

- [ ] **Step 3: Shrink `admin-go.env.example` logging block**

In `E:\admin_go\admin_back_go\deploy\docker-first\admin-go.env.example`, replace the current logging block:

```env
LOG_ENABLE_FILE=true
LOG_DIR=/app/runtime/logs
LOG_FILE_NAME=admin-api.log
LOG_API_FILE_NAME=admin-api.log
LOG_WORKER_FILE_NAME=admin-worker.log
LOG_MAX_TAIL_LINES=2000
LOG_ALLOWED_EXTENSIONS=.log
LOG_FILE_MAX_SIZE_MB=64
LOG_FILE_MAX_BACKUPS=7
LOG_FILE_MAX_AGE_DAYS=14
LOG_FILE_COMPRESS=true
```

with:

```env
LOG_DIR=/app/runtime/logs
```

- [ ] **Step 4: Shrink local ignored `admin-go.env` logging block**

In `E:\admin_go\admin_back_go\deploy\docker-first\admin-go.env`, make the same replacement:

```env
LOG_DIR=/app/runtime/logs
```

Do not stage this ignored file. It is required for the local focused config test because existing config tests inspect the ignored live env file when present.

- [ ] **Step 5: Format and run focused config tests**

Run:

```powershell
cd E:\admin_go\admin_back_go
gofmt -w .\internal\config\config.go .\internal\config\config_test.go .\internal\config\logging_test.go .\internal\config\logging_process_test.go
go test -count=1 ./internal/config
```

Expected: PASS.

- [ ] **Step 6: Prove config code no longer reads deprecated logging env keys**

Run:

```powershell
cd E:\admin_go\admin_back_go
rg -n 'LOG_ENABLE_FILE|LOG_FILE_NAME|LOG_API_FILE_NAME|LOG_WORKER_FILE_NAME|LOG_MAX_TAIL_LINES|LOG_ALLOWED_EXTENSIONS|LOG_FILE_MAX_SIZE_MB|LOG_FILE_MAX_BACKUPS|LOG_FILE_MAX_AGE_DAYS|LOG_FILE_COMPRESS' .\internal\config\config.go
```

Expected: no matches and exit code 1.

- [ ] **Step 7: Commit backend config/env changes**

Run:

```powershell
cd E:\admin_go\admin_back_go
git status --short
git add .\internal\config\config.go .\internal\config\config_test.go .\internal\config\logging_test.go .\internal\config\logging_process_test.go .\deploy\docker-first\admin-go.env.example
git commit -m "refactor: internalize logging defaults"
```

Expected: commit succeeds. `deploy/docker-first/admin-go.env` remains ignored and unstaged.

---

### Task 3: Update backend and root documentation

**Files:**
- Modify: `E:\admin_go\admin_back_go\docs\architecture.md`
- Modify: `E:\admin_go\docs\contracts\admin-api-v1.md`
- Modify: `E:\admin_go\docs\deployment\docker-first-backend.md`
- Modify: `E:\admin_go\docs\status\current-status.md`

- [ ] **Step 1: Update backend architecture system log baseline**

In `E:\admin_go\admin_back_go\docs\architecture.md`, replace the `文件策略：` code block around the system log baseline with this text:

````markdown
文件策略：

```text
日志目录来自 LOG_DIR；Docker-first 默认 /app/runtime/logs。
admin-api 默认写 runtime/logs/admin-api.log。
admin-worker 默认写 runtime/logs/admin-worker.log。
文件轮转策略是代码默认值：64MB、7 backups、14 days、compress=true。
日志读取白名单是代码默认值：.log。
读取行数上限是代码默认值：2000。
```

这些日志策略不进 system_settings。原因是日志初始化早于 DB；DB 不通、migration 出错、启动失败时仍要能写 stdout 和文件日志。
````

Also replace the safety line:

```text
读取行数受 LOG_MAX_TAIL_LINES 限制
```

with:

```text
读取行数受代码默认上限 2000 限制
```

- [ ] **Step 2: Update API contract System Logs section**

In `E:\admin_go\docs\contracts\admin-api-v1.md`, in `## System Logs`, replace the lumberjack env block:

````markdown
文件输出使用 lumberjack 轮转，默认：

```text
LOG_FILE_MAX_SIZE_MB=64
LOG_FILE_MAX_BACKUPS=7
LOG_FILE_MAX_AGE_DAYS=14
LOG_FILE_COMPRESS=true
```

所以不是一个 `admin-api.log` 无限增长。`LOG_FILE_NAME` 仅保留旧配置入口；实际进程入口会按 `LOG_API_FILE_NAME` / `LOG_WORKER_FILE_NAME` 选择文件名。
````

with:

````markdown
文件输出使用 lumberjack 轮转，代码默认值固定为：

```text
file_max_size_mb=64
file_max_backups=7
file_max_age_days=14
file_compress=true
```

所以不是一个 `admin-api.log` 无限增长。Docker-first env 只保留 `LOG_DIR` 作为部署路径；`admin-api.log` / `admin-worker.log` 文件名、轮转策略、`.log` 白名单和 2000 行 tail 上限都是代码内置默认值。
````

Also replace this validation line:

```markdown
- `tail`: 1-2000, capped again by `LOG_MAX_TAIL_LINES`.
```

with:

```markdown
- `tail`: 1-2000, capped again by the code-owned max tail limit 2000.
```

- [ ] **Step 3: Update Docker-first backend deployment doc**

In `E:\admin_go\docs\deployment\docker-first-backend.md`, after the existing upload runtime paragraph and before the payment cert section, insert:

```markdown
日志运行时：

Docker-first env 的日志组只保留 `LOG_DIR=/app/runtime/logs`。文件日志默认开启；API 写 `admin-api.log`，worker 写 `admin-worker.log`。日志文件名、`.log` 读取白名单、最多 tail 2000 行、64MB/7 backups/14 days/compress 轮转策略都是 Go 代码内置默认值，不通过 env 或 `system_settings` 配置。
```

In section `## 3.1 系统日志跟着后端节点走`, add this sentence after the container path code block:

```markdown
`LOG_DIR` 只决定容器内日志目录；具体文件名和轮转策略由 Go 代码固定，部署时不要再配置 `LOG_FILE_NAME` / `LOG_MAX_TAIL_LINES` / `LOG_FILE_MAX_*` 这类策略键。
```

- [ ] **Step 4: Update current status system logs row**

In `E:\admin_go\docs\status\current-status.md`, update the `system logs` row backend status so it contains this wording:

```text
implemented baseline: slog stdout + default-on lumberjack file output, process-specific api/worker log files, code-owned rotation/tail/extension policy, Docker env only keeps LOG_DIR, read-only logstore, REST files/lines API with path traversal guard, localized backend error keys
```

Do not change unrelated module rows.

- [ ] **Step 5: Commit documentation changes in each repo**

Run:

```powershell
cd E:\admin_go\admin_back_go
git add .\docs\architecture.md
git commit -m "docs: update logging env contract"

cd E:\admin_go
git add .\docs\contracts\admin-api-v1.md .\docs\deployment\docker-first-backend.md .\docs\status\current-status.md
git commit -m "docs: update logging env contract"
```

Expected: both commits succeed if both repos have changes. If the backend commit has no changes because Task 2 already included `docs/architecture.md`, run `git status --short` and continue to the root commit.

---

### Task 4: Run full focused verification

**Files:**
- No source edits.

- [ ] **Step 1: Run backend focused tests**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test -count=1 ./internal/config ./internal/platform/logging ./internal/platform/logstore ./internal/module/systemlog
```

Expected: PASS.

- [ ] **Step 2: Run bootstrap/server tests because `Load()` feeds app bootstrap**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test -count=1 ./internal/bootstrap ./internal/server
```

Expected: PASS.

- [ ] **Step 3: Scan active code and Docker env for deprecated logging env contract**

Run:

```powershell
cd E:\admin_go
rg -n 'LOG_ENABLE_FILE|LOG_FILE_NAME|LOG_API_FILE_NAME|LOG_WORKER_FILE_NAME|LOG_MAX_TAIL_LINES|LOG_ALLOWED_EXTENSIONS|LOG_FILE_MAX_SIZE_MB|LOG_FILE_MAX_BACKUPS|LOG_FILE_MAX_AGE_DAYS|LOG_FILE_COMPRESS' .\admin_back_go\internal .\admin_back_go\deploy\docker-first .\docs\contracts\admin-api-v1.md .\docs\deployment\docker-first-backend.md .\admin_back_go\docs\architecture.md
```

Expected: no matches and exit code 1. This scan intentionally excludes the Superpowers spec/plan files because they preserve historical before/after context.

- [ ] **Step 4: Run root governance checks**

Run:

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected: PASS.

- [ ] **Step 5: Check repository status**

Run:

```powershell
cd E:\admin_go
git status --short --branch
git -C .\admin_back_go status --short --branch
git -C .\admin_front_ts status --short --branch
```

Expected:

```text
root repo: ahead with committed docs; no unstaged tracked files
admin_back_go: ahead with committed backend changes; no unstaged tracked files
admin_front_ts: clean
```

Ignored local `admin_back_go/deploy/docker-first/admin-go.env` may remain ignored and should not appear in normal `git status --short`.

---

### Task 5: Optional Docker-first runtime verification when user asks for live proof

**Files:**
- No source edits unless runtime verification exposes a real bug.

- [ ] **Step 1: Rebuild and restart backend services**

Run:

```powershell
cd E:\admin_go\admin_back_go\deploy\docker-first
docker compose config --quiet
docker compose up -d --build admin-api admin-worker
```

Expected: compose config exits 0, both services start.

- [ ] **Step 2: Check health and readiness**

Run:

```powershell
curl.exe -fsS http://127.0.0.1:8080/health
curl.exe -fsS http://127.0.0.1:8080/ready
```

Expected:

```text
/health returns HTTP 200
/ready returns HTTP 200 and database/redis/token_redis/queue_redis/realtime are up or intentionally disabled according to env
```

- [ ] **Step 3: Verify log files are created under `LOG_DIR`**

Run:

```powershell
cd E:\admin_go\admin_back_go\deploy\docker-first
docker compose exec admin-api sh -lc 'ls -l /app/runtime/logs && test -f /app/runtime/logs/admin-api.log'
docker compose exec admin-worker sh -lc 'ls -l /app/runtime/logs && test -f /app/runtime/logs/admin-worker.log'
```

Expected: both `test -f` commands exit 0.

- [ ] **Step 4: Probe system log API through existing smoke or focused request**

Preferred when smoke credentials are available:

```powershell
cd E:\admin_go\admin_back_go
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account 15671628271 -Password 123456
```

Expected: full smoke includes the system-log read-only probe and reports success or a clear JSON summary with the system-log probe passing.

---

## Completion criteria

- Docker-first env files expose only `LOG_DIR` for logging.
- `config.Load()` reads only `LOG_DIR` from logging env keys.
- `DefaultLoggingConfig()` owns file logging enabled state, process file names, tail limit, extension whitelist, and lumberjack rotation defaults.
- System log API contract and backend architecture docs no longer present deprecated logging strategy env as deployment configuration.
- Focused backend tests and root governance checks pass with fresh output.
