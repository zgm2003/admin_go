# Env Deploy Config Truth Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** 清理 `.env` 和部署相关配置里的假兼容、误导注释和半成品配置，并把 scheduler 的 Redis 分布式锁真正接入运行时。

**Architecture:** 只改当前已经确认的问题：env 注释真相、上传驱动 Endpoint 文案、支付证书 legacy 清理、scheduler Redis 分布式锁、未使用 payment lock TTL 清理。配置必须和运行时一致：保留马上部署要用的配置，删除只读不生效或旧 PHP 兼容残留。

**Tech Stack:** Go 1.x, Gin, gocron/v2, go-redis/v9, existing `internal/platform/redislock`, Vue 3, Element Plus, Vitest static contract tests.

---

## Scope

做这些：

1. `.env` 注释修真：支付证书、COS STS、AI 对话、scheduler lock。
2. 删除旧 PHP 支付证书兼容字段 `LegacyAdminBackRoot`。
3. 把 `SCHEDULER_LOCK_PREFIX` 从“配置已存在”推进到“Redis 分布式锁真的生效”。
4. 上传驱动表单把 `Endpoint` 讲成人能懂的话，并给 placeholder。
5. 删除当前只读不生效的 payment lock TTL 配置字段。
6. 跑后端/前端针对验证。

不做这些：

- 不改数据库上传配置表结构。
- 不迁移支付业务逻辑。
- 不重做上传模块 UI。
- 不新增 OSS runtime。
- 不把所有 `.env` 行尾注释一次性重写。

---

## File Map

### Backend env/config

- Modify: `admin_back_go/.env`
  - 修正注释。
  - 新增 `SCHEDULER_LOCK_TTL=30s`，让分布式锁 TTL 显式可调。
  - 不恢复 `LEGACY_ADMIN_BACK_ROOT`。

- Modify: `admin_back_go/internal/config/config.go`
  - `SchedulerConfig` 增加 `LockTTL time.Duration`。
  - 删除 `PaymentConfig.LegacyAdminBackRoot`。
  - 删除 `PaymentConfig.NotifyLockTTL` / `PaymentConfig.AttemptLockTTL`，因为当前业务代码没有使用。

- Modify: `admin_back_go/internal/config/config_test.go`
  - 更新 scheduler lock TTL 默认值和 env override 测试。
  - 删除 legacy PHP cert root 断言。
  - 删除 payment lock TTL 断言。

- Modify: `admin_back_go/internal/config/upload_token_config_test.go`
  - 如果 `.env` 或默认断言依赖 `UPLOAD_KEY_RANDOM_BYTES=4`，同步到 `8`；没有依赖则不动。

### Payment cert path

- Modify: `admin_back_go/internal/platform/payment/certpath.go`
  - `CertPathResolver` 删除 `LegacyAdminBackRoot` 字段。
  - 解析顺序保留：绝对路径直接检查；相对路径按 `CertBaseDir`、`WorkingDir` 查找。

- Modify: `admin_back_go/internal/platform/payment/certpath_test.go`
  - 删除 legacy root 成功解析测试。
  - 保留 Go base dir 成功解析测试。
  - 保留缺证书失败测试。

- Modify: `admin_back_go/internal/bootstrap/app.go`
  - 构造 `payment.CertPathResolver` 时不再传 `LegacyAdminBackRoot`。

- Modify: `admin_back_go/internal/bootstrap/worker.go`
  - 同上。

### Scheduler distributed lock

- Modify: `admin_back_go/internal/platform/scheduler/scheduler.go`
  - 增加 scheduler 内部 `Locker` interface。
  - 增加 `Option`：`WithLocker(locker Locker)`、`WithLogger(logger *slog.Logger)`。
  - `Every` / `Cron` 注册任务时包装分布式锁。
  - 未配置 locker 或 lock prefix 为空时保持现有单进程行为。
  - 锁未抢到时跳过本次任务并返回 nil。
  - 抢到锁后执行任务，最后用 token 解锁。

- Modify: `admin_back_go/internal/platform/scheduler/scheduler_test.go`
  - 增加 lock key 使用 `SCHEDULER_LOCK_PREFIX + jobName` 的测试。
  - 增加锁未抢到时不执行 task 的测试。
  - 增加 task 执行后 unlock 的测试。

- Modify: `admin_back_go/internal/bootstrap/worker.go`
  - 当 `resources.Redis.Redis` 存在时注入 `redislock.New(resources.Redis.Redis)`。
  - scheduler 继续使用默认 Redis DB 0 做锁，避免跟 queue DB 混用。

- Modify: `admin_back_go/internal/bootstrap/worker_test.go`
  - 至少补一个轻量断言：scheduler disabled 时不要求 Redis lock。
  - 如果现有构造测试能覆盖，不强行做复杂 mock。

### Upload config UI copy

- Modify: `admin_front_ts/src/i18n/locales/zh-CN.ts`
  - `upload.driver.form.endpoint` 改成 `COS 写入端点（可留空）`。
  - 新增 `endpoint_placeholder`：`默认自动使用 https://{bucket}.cos.{region}.myqcloud.com`。
  - 保留 `bucket_domain: '访问域名'`。
  - 新增 `bucket_domain_placeholder`：`例如 cos.example.com，用于生成文件访问地址`。

- Modify: `admin_front_ts/src/i18n/locales/en-US.ts`
  - `endpoint` 改成 `COS write endpoint (optional)`。
  - 新增对应 placeholder。

- Modify: `admin_front_ts/src/views/Main/system/uploadConfig/components/UploadDriver/index.vue`
  - 给 endpoint input 增加 placeholder。
  - 给 bucket_domain input 增加 placeholder。

- Create: `admin_front_ts/tests/shared/system/upload-config-copy.test.ts`
  - 静态检查 Endpoint 文案不再裸露成 `Endpoint`。
  - 静态检查 placeholder 解释默认 COS endpoint 和访问域名用途。

---

## Task 1: Fix env comments and remove fake legacy payment config

**Files:**

- Modify: `admin_back_go/.env`
- Modify: `admin_back_go/internal/config/config.go`
- Modify: `admin_back_go/internal/config/config_test.go`
- Modify: `admin_back_go/internal/bootstrap/app.go`
- Modify: `admin_back_go/internal/bootstrap/worker.go`
- Modify: `admin_back_go/internal/platform/payment/certpath.go`
- Modify: `admin_back_go/internal/platform/payment/certpath_test.go`

- [x] **Step 1: Update `.env` comments only where they are currently misleading**

Replace the payment cert block with:

```env
# 支付证书：解析数据库中相对证书路径的基准目录；本地指向 Go 后端根目录，线上改成部署目录或容器内目录。
PAYMENT_CERT_BASE_DIR=E:/admin_go/admin_back_go
```

Replace the COS STS comment with:

```env
# COS STS：控制腾讯云临时凭证签发器；bucket、SecretId、SecretKey、上传地域和访问域名来自后台上传配置。
COS_STS_ENABLED=true
COS_STS_ENDPOINT=sts.tencentcloudapi.com
COS_STS_REGION=ap-guangzhou
```

Replace the AI block with line comments:

```env
# AI 对话：控制流式回复超时和运行记录残留判定，避免 AI 请求长期卡住。
AI_CHAT_STREAM_MAX_DURATION=5m      # 单次 AI 回复最长执行时间；超时后会中断回复处理
AI_CHAT_STREAM_IDLE_TIMEOUT=60s     # 流式回复空闲超时；超过该时间没有新数据就认为连接卡住
AI_RUN_STALE_TIMEOUT=15m            # AI run 超时判定窗口；超过该时间未更新会被视为残留运行
```

- [x] **Step 2: Remove `LegacyAdminBackRoot` from config**

In `admin_back_go/internal/config/config.go`, change:

```go
type PaymentConfig struct {
	CertBaseDir         string
	LegacyAdminBackRoot string
	AlipayTimeout       time.Duration
	NotifyLockTTL       time.Duration
	AttemptLockTTL      time.Duration
}
```

to:

```go
type PaymentConfig struct {
	CertBaseDir   string
	AlipayTimeout time.Duration
}
```

And change the loader from:

```go
Payment: PaymentConfig{
	CertBaseDir:         envString("PAYMENT_CERT_BASE_DIR", ""),
	LegacyAdminBackRoot: envString("LEGACY_ADMIN_BACK_ROOT", ""),
	AlipayTimeout:       envDuration("PAYMENT_ALIPAY_TIMEOUT", 10*time.Second),
	NotifyLockTTL:       envDuration("PAYMENT_NOTIFY_LOCK_TTL", 30*time.Second),
	AttemptLockTTL:      envDuration("PAYMENT_ATTEMPT_LOCK_TTL", 30*time.Second),
},
```

to:

```go
Payment: PaymentConfig{
	CertBaseDir:   envString("PAYMENT_CERT_BASE_DIR", ""),
	AlipayTimeout: envDuration("PAYMENT_ALIPAY_TIMEOUT", 10*time.Second),
},
```

- [x] **Step 3: Remove legacy root from payment cert resolver**

In `admin_back_go/internal/platform/payment/certpath.go`, change:

```go
type CertPathResolver struct {
	CertBaseDir         string
	LegacyAdminBackRoot string
	WorkingDir          string
}
```

to:

```go
type CertPathResolver struct {
	CertBaseDir string
	WorkingDir  string
}
```

And change:

```go
for _, base := range []string{r.CertBaseDir, r.LegacyAdminBackRoot, r.WorkingDir} {
```

to:

```go
for _, base := range []string{r.CertBaseDir, r.WorkingDir} {
```

- [x] **Step 4: Update bootstrap resolver construction**

In both `admin_back_go/internal/bootstrap/app.go` and `admin_back_go/internal/bootstrap/worker.go`, replace:

```go
paymentCertResolver := payment.CertPathResolver{
	CertBaseDir:         cfg.Payment.CertBaseDir,
	LegacyAdminBackRoot: cfg.Payment.LegacyAdminBackRoot,
	WorkingDir:          ".",
}
```

with:

```go
paymentCertResolver := payment.CertPathResolver{
	CertBaseDir: cfg.Payment.CertBaseDir,
	WorkingDir:  ".",
}
```

- [x] **Step 5: Update config tests**

In `admin_back_go/internal/config/config_test.go`:

- Remove `t.Setenv("LEGACY_ADMIN_BACK_ROOT", "")`.
- Remove assertions against `cfg.Payment.LegacyAdminBackRoot`.
- Remove `PAYMENT_NOTIFY_LOCK_TTL` / `PAYMENT_ATTEMPT_LOCK_TTL` test setup and assertions.
- Keep `PAYMENT_CERT_BASE_DIR` and `PAYMENT_ALIPAY_TIMEOUT` tests.

Expected payment assertion shape:

```go
if cfg.Payment.CertBaseDir != "E:/admin_go/admin_back_go" {
	t.Fatalf("expected payment cert base dir to point at Go backend, got %q", cfg.Payment.CertBaseDir)
}
if cfg.Payment.AlipayTimeout != 9*time.Second {
	t.Fatalf("expected alipay timeout 9s, got %s", cfg.Payment.AlipayTimeout)
}
```

- [x] **Step 6: Update payment cert path tests**

In `admin_back_go/internal/platform/payment/certpath_test.go`:

- Delete the legacy root success test.
- Keep or add this behavior:

```go
func TestCertPathResolverResolvesRelativePathFromGoCertBaseDir(t *testing.T) {
	goRoot := t.TempDir()
	certPath := filepath.Join(goRoot, "runtime", "cert", "alipay", "appPublicCert.crt")
	if err := os.MkdirAll(filepath.Dir(certPath), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(certPath, []byte("cert"), 0o644); err != nil {
		t.Fatal(err)
	}

	resolved, err := CertPathResolver{CertBaseDir: goRoot}.Resolve("runtime/cert/alipay/appPublicCert.crt")
	if err != nil {
		t.Fatalf("Resolve returned error: %v", err)
	}
	if resolved != filepath.ToSlash(certPath) {
		t.Fatalf("unexpected resolved path: %s", resolved)
	}
}
```

- [x] **Step 7: Run backend config/payment tests**

Run from `admin_back_go`:

```powershell
go test ./internal/config ./internal/platform/payment ./internal/bootstrap
```

Expected: exit code 0.

---

## Task 2: Make scheduler Redis distributed lock real

**Files:**

- Modify: `admin_back_go/.env`
- Modify: `admin_back_go/internal/config/config.go`
- Modify: `admin_back_go/internal/config/config_test.go`
- Modify: `admin_back_go/internal/platform/scheduler/scheduler.go`
- Modify: `admin_back_go/internal/platform/scheduler/scheduler_test.go`
- Modify: `admin_back_go/internal/bootstrap/worker.go`

- [x] **Step 1: Add explicit scheduler lock TTL to env/config**

In `.env`, replace scheduler block with:

```env
# 定时任务：worker 内 cron scheduler 配置；多 worker 部署时使用 Redis 分布式锁避免重复触发。
SCHEDULER_ENABLED=true
SCHEDULER_TIMEZONE=Asia/Shanghai
SCHEDULER_LOCK_PREFIX=admin_go:scheduler:
SCHEDULER_LOCK_TTL=30s
```

In `SchedulerConfig`, add:

```go
type SchedulerConfig struct {
	Enabled    bool
	Timezone   string
	LockPrefix string
	LockTTL    time.Duration
}
```

In config loading, add:

```go
LockTTL: envDuration("SCHEDULER_LOCK_TTL", 30*time.Second),
```

- [x] **Step 2: Update config tests for lock TTL**

In `admin_back_go/internal/config/config_test.go` default assertions:

```go
if cfg.Scheduler.LockTTL != 30*time.Second {
	t.Fatalf("expected scheduler lock ttl 30s, got %s", cfg.Scheduler.LockTTL)
}
```

In env override setup:

```go
t.Setenv("SCHEDULER_LOCK_TTL", "45s")
```

In env override assertions:

```go
if cfg.Scheduler.Timezone != "UTC" || cfg.Scheduler.LockPrefix != "test:scheduler:" || cfg.Scheduler.LockTTL != 45*time.Second {
	t.Fatalf("unexpected scheduler config: %#v", cfg.Scheduler)
}
```

- [x] **Step 3: Add scheduler lock option API**

In `admin_back_go/internal/platform/scheduler/scheduler.go`, add imports:

```go
"log/slog"

"admin_back_go/internal/platform/redislock"
```

Add types:

```go
type Locker interface {
	Lock(ctx context.Context, key string, ttl time.Duration) (string, error)
	Unlock(ctx context.Context, key string, token string) error
}

type Option func(*Scheduler)

func WithLocker(locker Locker) Option {
	return func(s *Scheduler) {
		s.locker = locker
	}
}

func WithLogger(logger *slog.Logger) Option {
	return func(s *Scheduler) {
		if logger != nil {
			s.logger = logger
		}
	}
}
```

Extend `Scheduler`:

```go
type Scheduler struct {
	scheduler  gocron.Scheduler
	location   *time.Location
	lockPrefix string
	lockTTL    time.Duration
	locker     Locker
	logger     *slog.Logger
}
```

Change constructor signature:

```go
func New(cfg config.SchedulerConfig, opts ...Option) (*Scheduler, error) {
```

Initialize:

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
for _, opt := range opts {
	if opt != nil {
		opt(result)
	}
}
return result, nil
```

- [x] **Step 4: Wrap scheduled task execution with Redis lock**

Add helper:

```go
func (s *Scheduler) wrapTask(name string, task TaskFunc) TaskFunc {
	return func(ctx context.Context) error {
		if s == nil || s.locker == nil || strings.TrimSpace(s.lockPrefix) == "" {
			return task(ctx)
		}
		key := s.lockPrefix + strings.TrimSpace(name)
		token, err := s.locker.Lock(ctx, key, s.lockTTL)
		if errors.Is(err, redislock.ErrNotAcquired) {
			if s.logger != nil {
				s.logger.InfoContext(ctx, "skip scheduler job because distributed lock is held", "name", name, "lock_key", key)
			}
			return nil
		}
		if err != nil {
			return fmt.Errorf("scheduler lock %s: %w", name, err)
		}
		defer func() {
			if unlockErr := s.locker.Unlock(ctx, key, token); unlockErr != nil && s.logger != nil {
				s.logger.ErrorContext(ctx, "unlock scheduler job failed", "name", name, "lock_key", key, "error", unlockErr)
			}
		}()
		return task(ctx)
	}
}
```

Use it in `Every` and `Cron`:

```go
gocron.NewTask(func(ctx context.Context) error {
	return s.wrapTask(name, task)(ctx)
}),
```

- [x] **Step 5: Inject Redis locker from worker**

In `admin_back_go/internal/bootstrap/worker.go`, import:

```go
"admin_back_go/internal/platform/redislock"
```

Before `scheduler.New`, build options:

```go
schedulerOptions := []scheduler.Option{scheduler.WithLogger(logger)}
if resources.Redis != nil && resources.Redis.Redis != nil {
	schedulerOptions = append(schedulerOptions, scheduler.WithLocker(redislock.New(resources.Redis.Redis)))
}
s, err := scheduler.New(cfg.Scheduler, schedulerOptions...)
```

- [x] **Step 6: Add scheduler distributed lock tests**

In `admin_back_go/internal/platform/scheduler/scheduler_test.go`, add a fake locker and unit tests around `wrapTask` so tests do not depend on gocron timing:

```go
type fakeLocker struct {
	lockKey   string
	lockTTL   time.Duration
	lockErr   error
	unlockKey string
	token     string
}

func (f *fakeLocker) Lock(ctx context.Context, key string, ttl time.Duration) (string, error) {
	f.lockKey = key
	f.lockTTL = ttl
	if f.lockErr != nil {
		return "", f.lockErr
	}
	if f.token == "" {
		f.token = "token"
	}
	return f.token, nil
}

func (f *fakeLocker) Unlock(ctx context.Context, key string, token string) error {
	f.unlockKey = key
	return nil
}
```

Add test for successful lock:

```go
func TestWrapTaskUsesDistributedLockWhenConfigured(t *testing.T) {
	locker := &fakeLocker{}
	s, err := New(config.SchedulerConfig{Timezone: "UTC", LockPrefix: "test:scheduler:", LockTTL: 45 * time.Second}, WithLocker(locker))
	if err != nil {
		t.Fatalf("New returned error: %v", err)
	}
	run := false
	err = s.wrapTask("job-a", func(ctx context.Context) error {
		run = true
		return nil
	})(context.Background())
	if err != nil {
		t.Fatalf("task returned error: %v", err)
	}
	if !run || locker.lockKey != "test:scheduler:job-a" || locker.lockTTL != 45*time.Second || locker.unlockKey != "test:scheduler:job-a" {
		t.Fatalf("unexpected lock behavior: run=%v locker=%#v", run, locker)
	}
}
```

Add test for lock not acquired:

```go
func TestWrapTaskSkipsWhenDistributedLockNotAcquired(t *testing.T) {
	locker := &fakeLocker{lockErr: redislock.ErrNotAcquired}
	s, err := New(config.SchedulerConfig{Timezone: "UTC", LockPrefix: "test:scheduler:", LockTTL: 30 * time.Second}, WithLocker(locker))
	if err != nil {
		t.Fatalf("New returned error: %v", err)
	}
	run := false
	err = s.wrapTask("job-a", func(ctx context.Context) error {
		run = true
		return nil
	})(context.Background())
	if err != nil {
		t.Fatalf("expected skip without error, got %v", err)
	}
	if run {
		t.Fatalf("task should not run when lock is held")
	}
}
```

- [x] **Step 7: Run scheduler/config/bootstrap tests**

Run from `admin_back_go`:

```powershell
go test ./internal/config ./internal/platform/scheduler ./internal/bootstrap
```

Expected: exit code 0.

---

## Task 3: Fix upload driver Endpoint UX copy

**Files:**

- Modify: `admin_front_ts/src/i18n/locales/zh-CN.ts`
- Modify: `admin_front_ts/src/i18n/locales/en-US.ts`
- Modify: `admin_front_ts/src/views/Main/system/uploadConfig/components/UploadDriver/index.vue`
- Create: `admin_front_ts/tests/shared/system/upload-config-copy.test.ts`

- [x] **Step 1: Add failing static copy test**

Create `admin_front_ts/tests/shared/system/upload-config-copy.test.ts`:

```ts
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { describe, expect, it } from 'vitest'

function readFrontendSource(relativePath: string) {
  return readFileSync(resolve(process.cwd(), relativePath), 'utf8')
}

describe('upload config form copy', () => {
  it('explains COS endpoint and bucket domain instead of exposing raw Endpoint wording', () => {
    const zh = readFrontendSource('src/i18n/locales/zh-CN.ts')
    const view = readFrontendSource('src/views/Main/system/uploadConfig/components/UploadDriver/index.vue')

    expect(zh).toContain("endpoint: 'COS 写入端点（可留空）'")
    expect(zh).toContain("endpoint_placeholder: '默认自动使用 https://{bucket}.cos.{region}.myqcloud.com'")
    expect(zh).toContain("bucket_domain_placeholder: '例如 cos.example.com，用于生成文件访问地址'")
    expect(zh).not.toContain("endpoint: 'Endpoint'")
    expect(view).toContain(":placeholder=\"t('upload.driver.form.endpoint_placeholder')\"")
    expect(view).toContain(":placeholder=\"t('upload.driver.form.bucket_domain_placeholder')\"")
  })
})
```

- [x] **Step 2: Run test to verify it fails before copy changes**

Run from `admin_front_ts`:

```powershell
npm run test -- tests/shared/system/upload-config-copy.test.ts
```

Expected: fail because current zh copy still contains `endpoint: 'Endpoint'` and template has no placeholders.

- [x] **Step 3: Update Chinese and English i18n copy**

In `src/i18n/locales/zh-CN.ts`, under `upload.driver.form`, set:

```ts
endpoint: 'COS 写入端点（可留空）',
endpoint_placeholder: '默认自动使用 https://{bucket}.cos.{region}.myqcloud.com',
bucket_domain: '访问域名',
bucket_domain_placeholder: '例如 cos.example.com，用于生成文件访问地址',
```

In `src/i18n/locales/en-US.ts`, under the same structure, set:

```ts
endpoint: 'COS write endpoint (optional)',
endpoint_placeholder: 'Defaults to https://{bucket}.cos.{region}.myqcloud.com',
bucket_domain: 'Public access domain',
bucket_domain_placeholder: 'Example: cos.example.com, used to build file URLs',
```

- [x] **Step 4: Add placeholders to the form**

In `UploadDriver/index.vue`, change endpoint input to:

```vue
<el-input v-model="form.endpoint" :placeholder="t('upload.driver.form.endpoint_placeholder')" clearable/>
```

Change bucket domain input to:

```vue
<el-input v-model="form.bucket_domain" :placeholder="t('upload.driver.form.bucket_domain_placeholder')" clearable/>
```

- [x] **Step 5: Run frontend copy test**

Run from `admin_front_ts`:

```powershell
npm run test -- tests/shared/system/upload-config-copy.test.ts
```

Expected: exit code 0.

---

## Task 4: Final verification

**Files:** no source edits in this task.

- [x] **Step 1: Backend targeted tests**

Run from `admin_back_go`:

```powershell
go test ./internal/config ./internal/platform/payment ./internal/platform/scheduler ./internal/bootstrap
```

Expected: exit code 0.

- [x] **Step 2: Backend broad tests**

Run from `admin_back_go`:

```powershell
go test ./...
```

Expected: exit code 0.

- [x] **Step 3: Frontend focused test**

Run from `admin_front_ts`:

```powershell
npm run test -- tests/shared/system/upload-config-copy.test.ts
```

Expected: exit code 0.

- [x] **Step 4: Frontend type check**

Run from `admin_front_ts`:

```powershell
npx vue-tsc -b --pretty false
```

Expected: exit code 0.

- [x] **Step 5: Diff sanity**

Run from `E:\admin_go`:

```powershell
git diff --check
```

Expected: no whitespace errors.

- [x] **Step 6: Manual deploy notes for `.env`**

Record these in the final handoff:

```text
PAYMENT_CERT_BASE_DIR 本地是 E:/admin_go/admin_back_go；Docker 里通常改成 /app；宝塔/裸机改成实际 Go 后端部署目录。
COS_STS_ENDPOINT 是腾讯云 STS 服务端点，不是 bucket endpoint，不是访问域名。
上传配置表单里的 COS 写入端点一般留空；访问域名填 cos.zgm2003.cn 这类公开域名。
SCHEDULER_LOCK_PREFIX + SCHEDULER_LOCK_TTL 已经接入 Redis 分布式锁，用默认 Redis DB。
```

---

## Self-Review

- Spec coverage: 覆盖刚才列出的 6 个问题：支付证书注释/legacy、COS STS 注释、上传 Endpoint 文案、scheduler 分布式锁、AI 注释、payment lock TTL 假配置。
- Placeholder scan: 无占位内容；每个任务有明确文件、代码片段和验证命令。
- Scope check: 不做上传重构、不做支付业务重构、不改数据库结构；范围足够窄。
- Compatibility: 删除旧 PHP cert root 是有意 breaking cleanup；当前 `.env` 已经不再配置它，用户确认 Go-only，不再兼容旧 PHP 路径。


