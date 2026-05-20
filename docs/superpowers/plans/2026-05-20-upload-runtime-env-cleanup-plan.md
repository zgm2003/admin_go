# Upload Runtime Env Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove upload runtime implementation details from Docker-first env, move upload token TTL to `system_settings.upload.token.ttl_minutes`, and keep the upload configuration tables as the only COS upload fact source.

**Architecture:** `uploadconfig` continues to own COS SecretId/SecretKey/Bucket/Region/APPID/endpoint/domain and rule settings. `uploadtoken` owns browser temporary credential signing and reads only the TTL policy from `system_settings`. `platform/storage/cos` owns Tencent STS SDK defaults, so STS endpoint/region are code constants rather than user-facing env or upload-config fields.

**Tech Stack:** Go 1.x, Gin modular backend, GORM/MySQL `system_settings`, Tencent COS STS SDK, PowerShell smoke scripts, Docker-first env templates.

---

## File Structure

- Modify: `admin_back_go/internal/config/config.go`
  - Remove `Config.UploadToken`, `UploadTokenConfig`, `COSSTSConfig`, and the five env reads.
- Modify: `admin_back_go/internal/config/config_test.go`
  - Add guards that Docker-first env does not document upload runtime policy and `Config` has no `UploadToken`.
- Delete: `admin_back_go/internal/config/upload_token_config_test.go`
  - Remove obsolete assertions for env-backed upload runtime config.
- Create: `admin_back_go/internal/module/uploadtoken/policy.go`
  - Add TTL setting key, policy provider, default TTL, and bounds.
- Create: `admin_back_go/internal/module/uploadtoken/policy_test.go`
  - Cover valid setting and fallback cases.
- Modify: `admin_back_go/internal/module/uploadtoken/service.go`
  - Replace env-derived TTL/random bytes with TTL provider + code-owned 8-byte key randomness.
- Modify: `admin_back_go/internal/module/uploadtoken/service_test.go`
  - Update constructor options and key expectations.
- Modify: `admin_back_go/internal/bootstrap/app.go`
  - Always wire enabled COS signer/object reader/object writer; inject upload token TTL provider.
- Modify: `admin_back_go/internal/bootstrap/worker.go`
  - Always wire enabled COS object reader/writer.
- Modify: `admin_back_go/internal/platform/storage/cos/signer.go`
  - Make Tencent STS API endpoint/region defaults explicit exported constants.
- Modify: `admin_back_go/internal/platform/storage/cos/signer_test.go`
  - Prove STS defaults are independent from COS bucket region.
- Create: `admin_back_go/database/migrations/20260520_upload_token_ttl_policy.sql`
  - Seed `system_settings.upload.token.ttl_minutes`.
- Modify: `admin_back_go/deploy/docker-first/admin-go.env.example`
  - Remove `UPLOAD_TOKEN_TTL`, `UPLOAD_KEY_RANDOM_BYTES`, `COS_STS_ENABLED`, `COS_STS_ENDPOINT`, `COS_STS_REGION`.
- Modify if present: `admin_back_go/deploy/docker-first/admin-go.env`
  - Remove the same keys from ignored local env, without committing secrets.
- Modify: `admin_back_go/scripts/full-admin-smoke.ps1`
  - Remove `COS_STS_ENABLED` gate; skip only when upload setting is missing/non-COS.
- Modify: `admin_back_go/docs/architecture.md`, `admin_back_go/README.md`
  - Update backend-owned upload runtime docs.
- Modify: `docs/status/current-status.md`, `docs/testing/smoke-matrix.md`, `docs/contracts/admin-api-v1.md`, `docs/deployment/docker-first-backend.md`
  - Update active root docs.

---

### Task 1: Add upload runtime env/config regression tests

**Files:**
- Modify: `admin_back_go/internal/config/config_test.go`
- Delete: `admin_back_go/internal/config/upload_token_config_test.go`

- [ ] **Step 1: Add failing env/config tests**

In `admin_back_go/internal/config/config_test.go`, immediately after `TestConfigDoesNotExposeVerifyCodeRuntimePolicy`, add:

```go
func TestDockerFirstEnvDoesNotDocumentUploadRuntimePolicy(t *testing.T) {
	for _, fileName := range []string{"admin-go.env", "admin-go.env.example"} {
		values := readDockerFirstEnv(t, fileName)

		for _, key := range []string{"UPLOAD_TOKEN_TTL", "UPLOAD_KEY_RANDOM_BYTES", "COS_STS_ENABLED", "COS_STS_ENDPOINT", "COS_STS_REGION"} {
			if _, ok := values[key]; ok {
				t.Fatalf("%s should move to system_settings or code constant, not Docker env file %s", key, fileName)
			}
		}
	}
}

func TestConfigDoesNotExposeUploadRuntimePolicy(t *testing.T) {
	if _, ok := reflect.TypeOf(Config{}).FieldByName("UploadToken"); ok {
		t.Fatalf("upload runtime policy should not be loaded from env config")
	}
}
```

- [ ] **Step 2: Run tests to verify current failure**

Run from `E:/admin_go/admin_back_go`:

```powershell
go test -count=1 ./internal/config -run "TestDockerFirstEnvDoesNotDocumentUploadRuntimePolicy|TestConfigDoesNotExposeUploadRuntimePolicy"
```

Expected failure includes one of:

```text
UPLOAD_TOKEN_TTL should move to system_settings or code constant
```

```text
upload runtime policy should not be loaded from env config
```

- [ ] **Step 3: Delete the obsolete env-backed config test**

Delete:

```text
admin_back_go/internal/config/upload_token_config_test.go
```

This file currently asserts `UPLOAD_TOKEN_TTL`, `UPLOAD_KEY_RANDOM_BYTES`, and `COS_STS_*` are read from env, which is the behavior being removed.

---

### Task 2: Remove upload runtime policy from config and Docker-first env

**Files:**
- Modify: `admin_back_go/internal/config/config.go`
- Modify: `admin_back_go/deploy/docker-first/admin-go.env.example`
- Modify if present: `admin_back_go/deploy/docker-first/admin-go.env`

- [ ] **Step 1: Remove `UploadToken` from `Config`**

In `admin_back_go/internal/config/config.go`, replace the top-level `Config` type with:

```go
type Config struct {
	App       AppConfig
	HTTP      HTTPConfig
	Logging   LoggingConfig
	MySQL     MySQLConfig
	Redis     RedisConfig
	Token     TokenConfig
	Queue     QueueConfig
	Realtime  RealtimeConfig
	Scheduler SchedulerConfig
	Payment   PaymentConfig
	AI        AIConfig
	CORS      CORSConfig
}
```

- [ ] **Step 2: Remove upload token config types**

Delete these type definitions from `config.go`:

```go
type UploadTokenConfig struct {
	TTL            time.Duration
	KeyRandomBytes int
	COS            COSSTSConfig
}

type COSSTSConfig struct {
	Enabled  bool
	Endpoint string
	Region   string
}
```

- [ ] **Step 3: Remove upload token env loading**

Delete this `Load()` block:

```go
UploadToken: UploadTokenConfig{
	TTL:            envDuration("UPLOAD_TOKEN_TTL", 15*time.Minute),
	KeyRandomBytes: envInt("UPLOAD_KEY_RANDOM_BYTES", 4),
	COS: COSSTSConfig{
		Enabled:  envBool("COS_STS_ENABLED", false),
		Endpoint: envString("COS_STS_ENDPOINT", "sts.tencentcloudapi.com"),
		Region:   envString("COS_STS_REGION", "ap-guangzhou"),
	},
},
```

- [ ] **Step 4: Remove upload runtime keys from Docker-first env example**

In `admin_back_go/deploy/docker-first/admin-go.env.example`, delete:

```env
UPLOAD_TOKEN_TTL=15m
UPLOAD_KEY_RANDOM_BYTES=8

COS_STS_ENABLED=false
COS_STS_ENDPOINT=sts.tencentcloudapi.com
COS_STS_REGION=ap-guangzhou
```

- [ ] **Step 5: Remove upload runtime keys from ignored local env if present**

If `admin_back_go/deploy/docker-first/admin-go.env` exists, remove any lines whose key is:

```text
UPLOAD_TOKEN_TTL
UPLOAD_KEY_RANDOM_BYTES
COS_STS_ENABLED
COS_STS_ENDPOINT
COS_STS_REGION
```

Do not stage or commit `admin-go.env` if it is ignored.

- [ ] **Step 6: Run config tests**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test -count=1 ./internal/config
```

Expected:

```text
ok  	admin_back_go/internal/config
```

- [ ] **Step 7: Confirm active config/env keys are gone**

Run:

```powershell
cd E:\admin_go\admin_back_go
rg -n "UPLOAD_TOKEN_TTL|UPLOAD_KEY_RANDOM_BYTES|COS_STS_ENABLED|COS_STS_ENDPOINT|COS_STS_REGION" internal/config deploy/docker-first/admin-go.env.example
```

Expected: no output.

---

### Task 3: Add upload token TTL policy provider

**Files:**
- Create: `admin_back_go/internal/module/uploadtoken/policy.go`
- Create: `admin_back_go/internal/module/uploadtoken/policy_test.go`

- [ ] **Step 1: Create failing policy tests**

Create `admin_back_go/internal/module/uploadtoken/policy_test.go`:

```go
package uploadtoken

import (
	"context"
	"errors"
	"testing"
	"time"

	"admin_back_go/internal/enum"
	"admin_back_go/internal/module/systemsetting"
)

type fakeTTLPolicyRepository struct {
	row *systemsetting.Setting
	err error
	key string
}

func (f *fakeTTLPolicyRepository) SettingByKey(ctx context.Context, key string) (*systemsetting.Setting, error) {
	f.key = key
	if f.err != nil {
		return nil, f.err
	}
	return f.row, nil
}

func TestSystemSettingTTLPolicyProviderReadsUploadTokenTTL(t *testing.T) {
	repo := &fakeTTLPolicyRepository{row: validUploadTokenTTLSetting("20")}
	provider := NewSystemSettingTTLPolicyProvider(repo)

	got := provider.TTL(context.Background())

	if got != 20*time.Minute {
		t.Fatalf("expected ttl 20m, got %s", got)
	}
	if repo.key != UploadTokenTTLSettingKey {
		t.Fatalf("expected key %q, got %q", UploadTokenTTLSettingKey, repo.key)
	}
}

func TestSystemSettingTTLPolicyProviderFallsBackToDefault(t *testing.T) {
	cases := []struct {
		name string
		row  *systemsetting.Setting
		err  error
	}{
		{name: "missing", row: nil},
		{name: "deleted", row: &systemsetting.Setting{SettingKey: UploadTokenTTLSettingKey, SettingValue: "20", ValueType: enum.SystemSettingValueNumber, Status: enum.CommonYes, IsDel: enum.CommonYes}},
		{name: "disabled", row: &systemsetting.Setting{SettingKey: UploadTokenTTLSettingKey, SettingValue: "20", ValueType: enum.SystemSettingValueNumber, Status: enum.CommonNo, IsDel: enum.CommonNo}},
		{name: "wrong type", row: &systemsetting.Setting{SettingKey: UploadTokenTTLSettingKey, SettingValue: "20", ValueType: enum.SystemSettingValueString, Status: enum.CommonYes, IsDel: enum.CommonNo}},
		{name: "decimal", row: validUploadTokenTTLSetting("1.5")},
		{name: "zero", row: validUploadTokenTTLSetting("0")},
		{name: "negative", row: validUploadTokenTTLSetting("-1")},
		{name: "too large", row: validUploadTokenTTLSetting("1441")},
		{name: "repository error", err: errors.New("db down")},
	}

	for _, tt := range cases {
		t.Run(tt.name, func(t *testing.T) {
			provider := NewSystemSettingTTLPolicyProvider(&fakeTTLPolicyRepository{row: tt.row, err: tt.err})

			got := provider.TTL(context.Background())

			if got != DefaultTTL {
				t.Fatalf("expected default ttl %s, got %s", DefaultTTL, got)
			}
		})
	}
}

func TestSystemSettingTTLPolicyProviderFallsBackWhenRepositoryMissing(t *testing.T) {
	provider := NewSystemSettingTTLPolicyProvider(nil)

	got := provider.TTL(context.Background())

	if got != DefaultTTL {
		t.Fatalf("expected default ttl %s, got %s", DefaultTTL, got)
	}
}

func validUploadTokenTTLSetting(value string) *systemsetting.Setting {
	return &systemsetting.Setting{
		SettingKey:   UploadTokenTTLSettingKey,
		SettingValue: value,
		ValueType:    enum.SystemSettingValueNumber,
		Status:       enum.CommonYes,
		IsDel:        enum.CommonNo,
	}
}
```

- [ ] **Step 2: Run policy tests to verify failure**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test -count=1 ./internal/module/uploadtoken -run "TTLPolicy"
```

Expected:

```text
undefined: NewSystemSettingTTLPolicyProvider
```

- [ ] **Step 3: Add provider implementation**

Create `admin_back_go/internal/module/uploadtoken/policy.go`:

```go
package uploadtoken

import (
	"context"
	"strconv"
	"strings"
	"time"

	"admin_back_go/internal/enum"
	"admin_back_go/internal/module/systemsetting"
)

const (
	// UploadTokenTTLSettingKey is the system_settings key for browser COS temporary credential lifetime in minutes.
	UploadTokenTTLSettingKey = "upload.token.ttl_minutes"
	// DefaultTTL is the fallback upload temporary credential lifetime.
	DefaultTTL = 15 * time.Minute
	minTTLMinutes = 1
	maxTTLMinutes = 1440
)

// TTLPolicyProvider reads runtime upload-token lifetime policy.
type TTLPolicyProvider interface {
	TTL(ctx context.Context) time.Duration
}

// TTLPolicyRepository is the minimal system-setting read boundary uploadtoken needs.
type TTLPolicyRepository interface {
	SettingByKey(ctx context.Context, key string) (*systemsetting.Setting, error)
}

// SystemSettingTTLPolicyProvider reads upload-token TTL from system_settings.
type SystemSettingTTLPolicyProvider struct {
	repository TTLPolicyRepository
}

// NewSystemSettingTTLPolicyProvider returns a DB-backed upload-token TTL policy provider.
func NewSystemSettingTTLPolicyProvider(repository TTLPolicyRepository) *SystemSettingTTLPolicyProvider {
	return &SystemSettingTTLPolicyProvider{repository: repository}
}

// TTL returns the enabled upload-token lifetime, or DefaultTTL for missing/invalid policy.
func (p *SystemSettingTTLPolicyProvider) TTL(ctx context.Context) time.Duration {
	if p == nil || p.repository == nil {
		return DefaultTTL
	}
	row, err := p.repository.SettingByKey(ctx, UploadTokenTTLSettingKey)
	if err != nil {
		return DefaultTTL
	}
	if row == nil || row.IsDel != enum.CommonNo || row.Status != enum.CommonYes {
		return DefaultTTL
	}
	if row.ValueType != enum.SystemSettingValueNumber {
		return DefaultTTL
	}
	minutes, err := strconv.Atoi(strings.TrimSpace(row.SettingValue))
	if err != nil || minutes < minTTLMinutes || minutes > maxTTLMinutes {
		return DefaultTTL
	}
	return time.Duration(minutes) * time.Minute
}
```

- [ ] **Step 4: Run policy tests**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test -count=1 ./internal/module/uploadtoken -run "TTLPolicy"
```

Expected:

```text
ok  	admin_back_go/internal/module/uploadtoken
```

---

### Task 4: Refactor upload token service to use DB TTL and code-owned key randomness

**Files:**
- Modify: `admin_back_go/internal/module/uploadtoken/service.go`
- Modify: `admin_back_go/internal/module/uploadtoken/service_test.go`

- [ ] **Step 1: Add service tests**

In `service_test.go`, add near `fakeSigner`:

```go
type fakeTTLPolicyProvider struct {
	ttl time.Duration
}

func (f fakeTTLPolicyProvider) TTL(ctx context.Context) time.Duration {
	if f.ttl <= 0 {
		return DefaultTTL
	}
	return f.ttl
}
```

Add before `validInput()`:

```go
func TestCreateReadsTTLFromPolicyProvider(t *testing.T) {
	signer := &fakeSigner{}
	service := NewService(fakeRepository{config: validConfig(t, enum.UploadDriverCOS)}, secretbox.New([]byte("12345678901234567890123456789012")), signer, Options{
		TTLPolicy: fakeTTLPolicyProvider{ttl: 22 * time.Minute},
		Now:       func() time.Time { return time.Date(2026, 5, 20, 10, 0, 0, 0, time.UTC) },
		Random:    func(b []byte) (int, error) { for i := range b { b[i] = 0x11 }; return len(b), nil },
	})

	_, appErr := service.Create(context.Background(), validInput())

	if appErr != nil {
		t.Fatalf("unexpected error: %#v", appErr)
	}
	if signer.input.TTL != 22*time.Minute {
		t.Fatalf("expected signer ttl from policy provider, got %s", signer.input.TTL)
	}
}

func TestCreateDefaultsKeyRandomBytesToEight(t *testing.T) {
	signer := &fakeSigner{}
	service := NewService(fakeRepository{config: validConfig(t, enum.UploadDriverCOS)}, secretbox.New([]byte("12345678901234567890123456789012")), signer, Options{
		Now:    func() time.Time { return time.Date(2026, 5, 20, 10, 0, 0, 0, time.UTC) },
		Random: func(b []byte) (int, error) { for i := range b { b[i] = byte(i + 1) }; return len(b), nil },
	})

	got, appErr := service.Create(context.Background(), validInput())

	if appErr != nil {
		t.Fatalf("unexpected error: %#v", appErr)
	}
	if !strings.Contains(got.Key, "0102030405060708") {
		t.Fatalf("expected 8 random bytes in key, got %q", got.Key)
	}
}
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test -count=1 ./internal/module/uploadtoken -run "TestCreateReadsTTLFromPolicyProvider|TestCreateDefaultsKeyRandomBytesToEight"
```

Expected failure mentions `unknown field TTLPolicy` or the key random bytes assertion.

- [ ] **Step 3: Update service struct and options**

In `service.go`, replace `Service` and `Options` with:

```go
type Service struct {
	repo        Repository
	box         secretbox.Box
	signer      storagecos.CredentialSigner
	ttlPolicy   TTLPolicyProvider
	randomBytes int
	now         func() time.Time
	random      func([]byte) (int, error)
}

type Options struct {
	TTLPolicy TTLPolicyProvider
	Now       func() time.Time
	Random    func([]byte) (int, error)
}
```

Near constants, add:

```go
const defaultKeyRandomBytes = 8
```

- [ ] **Step 4: Update constructor**

Replace `NewService` with:

```go
func NewService(repo Repository, box secretbox.Box, signer storagecos.CredentialSigner, opts Options) *Service {
	if signer == nil {
		signer = storagecos.DisabledSigner{}
	}
	if opts.TTLPolicy == nil {
		opts.TTLPolicy = NewSystemSettingTTLPolicyProvider(nil)
	}
	if opts.Now == nil {
		opts.Now = time.Now
	}
	if opts.Random == nil {
		opts.Random = rand.Read
	}
	return &Service{repo: repo, box: box, signer: signer, ttlPolicy: opts.TTLPolicy, randomBytes: defaultKeyRandomBytes, now: opts.Now, random: opts.Random}
}
```

- [ ] **Step 5: Use policy TTL when signing**

In `Create`, before calling `s.signer.Sign`, add:

```go
ttl := DefaultTTL
if s.ttlPolicy != nil {
	ttl = s.ttlPolicy.TTL(ctx)
}
if ttl <= 0 {
	ttl = DefaultTTL
}
```

Then replace the signer input field:

```go
TTL: s.ttl,
```

with:

```go
TTL: ttl,
```

- [ ] **Step 6: Update existing service test literals**

In `TestCreateBuildsSafeKeyAndSignsCOS`, replace `Options` with:

```go
Options{
	TTLPolicy: fakeTTLPolicyProvider{ttl: 10 * time.Minute},
	Now:       func() time.Time { return time.Date(2026, 5, 5, 12, 30, 0, 0, time.Local) },
	Random:    func(b []byte) (int, error) { copy(b, []byte{0xa1, 0xb2, 0xc3, 0xd4, 0xe5, 0xf6, 0xa7, 0xb8}); return len(b), nil },
}
```

Update the expected key:

```go
if got.Key != "images/2026/05/05/1777955400000-a1b2c3d4e5f6a7b8-___.png" {
	t.Fatalf("unexpected key %q", got.Key)
}
```

In `TestCreateAcceptsAIAgentAvatarFolder`, replace the random function with:

```go
Random: func(b []byte) (int, error) { copy(b, []byte{0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08}); return len(b), nil },
```

- [ ] **Step 7: Run uploadtoken tests**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test -count=1 ./internal/module/uploadtoken
```

Expected:

```text
ok  	admin_back_go/internal/module/uploadtoken
```

---

### Task 5: Make Tencent STS defaults explicit in the COS platform layer

**Files:**
- Modify: `admin_back_go/internal/platform/storage/cos/signer.go`
- Modify: `admin_back_go/internal/platform/storage/cos/signer_test.go`

- [ ] **Step 1: Add default STS test**

In `signer_test.go`, add:

```go
func TestSignerUsesDefaultSTSAPIEndpointAndRegion(t *testing.T) {
	var got CredentialRequest
	signer := NewSigner(Config{Enabled: true, RequestCredential: func(ctx context.Context, input CredentialRequest) (*Credentials, error) {
		got = input
		return &Credentials{TmpSecretID: "tmp-id", TmpSecretKey: "tmp-key", SessionToken: "token", StartTime: 100, ExpiredTime: 200}, nil
	}})

	_, err := signer.Sign(context.Background(), SignInput{SecretID: "sid", SecretKey: "skey", Bucket: "bucket-1314", Region: "ap-nanjing", AppID: "1314", Key: "images/demo.png", TTL: time.Minute})
	if err != nil {
		t.Fatalf("Sign returned error: %v", err)
	}
	if got.Endpoint != DefaultSTSEndpoint {
		t.Fatalf("expected default STS endpoint %q, got %q", DefaultSTSEndpoint, got.Endpoint)
	}
	if got.Region != DefaultSTSRegion {
		t.Fatalf("expected default STS region %q, got %q", DefaultSTSRegion, got.Region)
	}
	if got.Policy.Statement[0].Resource[0] != "qcs::cos:ap-nanjing:uid/1314:bucket-1314/images/demo.png" {
		t.Fatalf("expected bucket region to remain ap-nanjing in policy, got %#v", got.Policy.Statement[0].Resource)
	}
}
```

- [ ] **Step 2: Run test to verify failure**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test -count=1 ./internal/platform/storage/cos -run TestSignerUsesDefaultSTSAPIEndpointAndRegion
```

Expected:

```text
undefined: DefaultSTSEndpoint
```

- [ ] **Step 3: Add constants and replace literals**

In `signer.go`, near the error vars, add:

```go
const (
	// DefaultSTSEndpoint is Tencent Cloud STS API endpoint, not a COS bucket endpoint.
	DefaultSTSEndpoint = "sts.tencentcloudapi.com"
	// DefaultSTSRegion is Tencent Cloud STS API request region, not the COS bucket region.
	DefaultSTSRegion = "ap-guangzhou"
)
```

Replace all fallback literals for the STS endpoint/region:

```go
"sts.tencentcloudapi.com"
"ap-guangzhou"
```

with:

```go
DefaultSTSEndpoint
DefaultSTSRegion
```

- [ ] **Step 4: Run COS platform tests**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test -count=1 ./internal/platform/storage/cos
```

Expected:

```text
ok  	admin_back_go/internal/platform/storage/cos
```

---

### Task 6: Rewire bootstrap to remove env-driven COS enablement

**Files:**
- Modify: `admin_back_go/internal/bootstrap/app.go`
- Modify: `admin_back_go/internal/bootstrap/worker.go`

- [ ] **Step 1: Enable app COS object clients unconditionally**

In `app.go`, replace:

```go
cosObjectReader := storagecos.NewObjectReader(storagecos.ObjectReaderConfig{Enabled: cfg.UploadToken.COS.Enabled})
cosObjectWriter := storagecos.NewObjectWriter(storagecos.ObjectWriterConfig{Enabled: cfg.UploadToken.COS.Enabled})
```

with:

```go
cosObjectReader := storagecos.NewObjectReader(storagecos.ObjectReaderConfig{Enabled: true})
cosObjectWriter := storagecos.NewObjectWriter(storagecos.ObjectWriterConfig{Enabled: true})
```

- [ ] **Step 2: Enable upload token signer unconditionally and inject TTL policy**

In `app.go`, replace:

```go
cosSigner := storagecos.CredentialSigner(storagecos.DisabledSigner{})
if cfg.UploadToken.COS.Enabled {
	cosSigner = storagecos.NewSigner(storagecos.Config{
		Enabled:  true,
		Endpoint: cfg.UploadToken.COS.Endpoint,
		Region:   cfg.UploadToken.COS.Region,
	})
}
uploadTokenService := uploadtoken.NewService(
	uploadtoken.NewGormRepository(resources.DB),
	secretBox,
	cosSigner,
	uploadtoken.Options{
		TTL:         cfg.UploadToken.TTL,
		RandomBytes: cfg.UploadToken.KeyRandomBytes,
	},
)
```

with:

```go
cosSigner := storagecos.NewSigner(storagecos.Config{Enabled: true})
uploadTokenService := uploadtoken.NewService(
	uploadtoken.NewGormRepository(resources.DB),
	secretBox,
	cosSigner,
	uploadtoken.Options{
		TTLPolicy: uploadtoken.NewSystemSettingTTLPolicyProvider(systemSettingRepository),
	},
)
```

- [ ] **Step 3: Enable worker COS object clients unconditionally**

In `worker.go`, replace every occurrence of:

```go
storagecos.NewObjectWriter(storagecos.ObjectWriterConfig{Enabled: cfg.UploadToken.COS.Enabled})
storagecos.NewObjectReader(storagecos.ObjectReaderConfig{Enabled: cfg.UploadToken.COS.Enabled})
```

with:

```go
storagecos.NewObjectWriter(storagecos.ObjectWriterConfig{Enabled: true})
storagecos.NewObjectReader(storagecos.ObjectReaderConfig{Enabled: true})
```

- [ ] **Step 4: Confirm bootstrap no longer references upload env config**

Run:

```powershell
cd E:\admin_go\admin_back_go
rg -n "UploadToken|COS_STS|UPLOAD_TOKEN" internal/bootstrap internal/config
```

Expected: no output.

- [ ] **Step 5: Run config/bootstrap tests**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test -count=1 ./internal/config ./internal/bootstrap
```

Expected:

```text
ok  	admin_back_go/internal/config
ok  	admin_back_go/internal/bootstrap
```

---

### Task 7: Seed `system_settings.upload.token.ttl_minutes`

**Files:**
- Create: `admin_back_go/database/migrations/20260520_upload_token_ttl_policy.sql`

- [ ] **Step 1: Create migration**

Create `admin_back_go/database/migrations/20260520_upload_token_ttl_policy.sql`:

```sql
SET NAMES utf8mb4;

INSERT INTO `system_settings` (`setting_key`, `setting_value`, `value_type`, `remark`, `status`, `is_del`)
VALUES
  ('upload.token.ttl_minutes', '15', 2, CONVERT(UNHEX('E4B88AE4BCA0E4B8B4E697B6E587ADE8AF81E69C89E69588E69C9FE58886E9929FE695B0') USING utf8mb4), 1, 2)
ON DUPLICATE KEY UPDATE
  `setting_value` = CASE
    WHEN `setting_value` IS NULL OR TRIM(`setting_value`) = '' THEN VALUES(`setting_value`)
    ELSE `setting_value`
  END,
  `value_type` = 2,
  `remark` = VALUES(`remark`),
  `status` = 1,
  `is_del` = 2,
  `updated_at` = CURRENT_TIMESTAMP;
```

- [ ] **Step 2: Verify migration content**

Run:

```powershell
cd E:\admin_go\admin_back_go
rg -n "upload.token.ttl_minutes|E4B88AE4BCA0E4B8B4E697B6E587ADE8AF81E69C89E69588E69C9FE58886E9929FE695B0|ON DUPLICATE KEY UPDATE" database/migrations/20260520_upload_token_ttl_policy.sql
```

Expected output includes all three patterns.

- [ ] **Step 3: Do not apply live DB in this plan**

Do not run the migration against live MySQL during plan execution unless the user explicitly asks for live DB apply. Runtime falls back to 15 minutes if the row is absent.

---

### Task 8: Update full smoke upload token probe

**Files:**
- Modify: `admin_back_go/scripts/full-admin-smoke.ps1`

- [ ] **Step 1: Replace `Invoke-UploadTokenProbe`**

Replace the whole `Invoke-UploadTokenProbe` function with:

```powershell
function Invoke-UploadTokenProbe([string]$BaseURL, [hashtable]$Headers) {
  $body = @{
    folder = 'avatars'
    file_name = 'codex-full-smoke.png'
    file_size = 1024
    file_kind = 'image'
  }

  $response = Invoke-JsonRequestAllowFailure 'POST' "$BaseURL/api/admin/v1/upload-tokens" $Headers $body

  if ($response.code -ne 200) {
    $msg = [string]$response.msg
    if ($msg -like '*未配置有效上传设置*' -or $msg -like '*当前上传驱动未启用 COS runtime*') {
      return [pscustomobject]@{
        Status = 'skipped_upload_setting_missing'
        Code = [int]$response.code
        Provider = ''
        Key = ''
      }
    }
    throw "upload token probe failed unexpectedly: $($response | ConvertTo-Json -Depth 12)"
  }

  if ([string]$response.data.provider -ne 'cos' -or [string]::IsNullOrWhiteSpace([string]$response.data.key)) {
    throw "upload token probe shape mismatch: $($response | ConvertTo-Json -Depth 12)"
  }
  if ($null -eq $response.data.credentials `
      -or [string]::IsNullOrWhiteSpace([string]$response.data.credentials.tmp_secret_id) `
      -or [string]::IsNullOrWhiteSpace([string]$response.data.credentials.tmp_secret_key) `
      -or [string]::IsNullOrWhiteSpace([string]$response.data.credentials.session_token)) {
    throw "upload token probe missing credentials: $($response | ConvertTo-Json -Depth 12)"
  }

  return [pscustomobject]@{
    Status = 'passed'
    Code = [int]$response.code
    Provider = [string]$response.data.provider
    Key = [string]$response.data.key
  }
}
```

- [ ] **Step 2: Confirm old skip gate is gone**

Run:

```powershell
cd E:\admin_go\admin_back_go
rg -n "COS_STS_ENABLED|skipped_cos_sts_disabled" scripts/full-admin-smoke.ps1
```

Expected: no output.

- [ ] **Step 3: Parse-check the PowerShell script**

Run:

```powershell
cd E:\admin_go\admin_back_go
$tokens=$null; $errors=$null; [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path .\scripts\full-admin-smoke.ps1), [ref]$tokens, [ref]$errors) | Out-Null; if ($errors.Count) { $errors | Format-List; exit 1 }
```

Expected: exit code `0`.

---

### Task 9: Update active docs

**Files:**
- Modify: `admin_back_go/docs/architecture.md`
- Modify: `admin_back_go/README.md`
- Modify: `docs/status/current-status.md`
- Modify: `docs/testing/smoke-matrix.md`
- Modify: `docs/contracts/admin-api-v1.md`
- Modify: `docs/deployment/docker-first-backend.md`

- [ ] **Step 1: Update backend architecture wording**

In `admin_back_go/docs/architecture.md`, replace the old `COS_STS_ENABLED` probe/signing wording with:

```text
upload token 探针不再读取 COS_STS_ENABLED。没有启用上传配置时输出 upload_token_probe=skipped_upload_setting_missing；存在启用 COS 上传配置时，POST /api/admin/v1/upload-tokens 只校验 provider/key/credentials shape，不上传真实文件。
```

and:

```text
COS STS signer 默认启用；是否能签发由后台 enabled upload setting、COS driver、SecretId/SecretKey、Bucket、Region、APPID 决定。Tencent STS API endpoint/region 是 platform/storage/cos 内置实现细节。
```

- [ ] **Step 2: Update backend README**

In `admin_back_go/README.md`, add near object storage/upload runtime documentation:

```text
Upload token runtime keeps env short: COS bucket, SecretId, SecretKey, Region, APPID, write endpoint, and access domain come from the admin upload configuration tables. Temporary credential lifetime is system_settings.upload.token.ttl_minutes with a 15 minute default. Tencent STS API endpoint/region are code-owned defaults inside internal/platform/storage/cos and are not Docker env keys.
```

- [ ] **Step 3: Update root current status**

In `docs/status/current-status.md`, update the `upload runtime/token` row so it says:

```text
full smoke token probe skips only when no enabled upload setting exists, otherwise validates token shape only
```

and:

```text
real client upload requires enabled COS upload setting and valid Tencent credentials; upload token TTL comes from system_settings.upload.token.ttl_minutes; Tencent STS API endpoint/region are code-owned implementation details
```

- [ ] **Step 4: Update smoke matrix**

In `docs/testing/smoke-matrix.md`, replace the upload token shape note with:

```text
没有 enabled upload setting 时 summary 输出 skipped_upload_setting_missing；存在启用 COS 配置时只校验 provider/key/credentials shape，永远不上传真实文件
```

- [ ] **Step 5: Update API contract**

In `docs/contracts/admin-api-v1.md`, remove these public deployment-branch lines:

```text
COS_STS_ENABLED=false returns explicit COS temporary credential disabled error.
COS_STS_ENABLED=false                 -> code 500 / COS 临时凭证未启用
```

Add in the same upload token notes area:

```text
Tencent STS API endpoint/region are code-owned platform defaults. Upload token creation is gated by the enabled COS upload setting and valid Tencent credentials, not by a Docker env switch.
```

- [ ] **Step 6: Update Docker-first backend runbook**

In `docs/deployment/docker-first-backend.md`, remove active mentions of:

```text
UPLOAD_TOKEN_TTL
UPLOAD_KEY_RANDOM_BYTES
COS_STS_ENABLED
COS_STS_ENDPOINT
COS_STS_REGION
```

Add near the backend env section:

```text
上传运行时不再通过 Docker env 配置临时凭证开关。COS bucket、SecretId、SecretKey、Region、APPID、写入端点和访问域名来自后台“系统管理 / 上传配置”。上传临时凭证有效期来自 system_settings.upload.token.ttl_minutes，默认 15 分钟。Tencent STS API endpoint/region 由 Go 代码内置，避免和 COS bucket region 混淆。
```

- [ ] **Step 7: Confirm active docs no longer carry old env contract**

Run:

```powershell
cd E:\admin_go
rg -n "COS_STS_ENABLED|UPLOAD_TOKEN_TTL|UPLOAD_KEY_RANDOM_BYTES|COS_STS_ENDPOINT|COS_STS_REGION|skipped_cos_sts_disabled" docs/status/current-status.md docs/testing/smoke-matrix.md docs/contracts/admin-api-v1.md docs/deployment/docker-first-backend.md admin_back_go/README.md admin_back_go/docs/architecture.md admin_back_go/scripts/full-admin-smoke.ps1 admin_back_go/deploy/docker-first/admin-go.env.example
```

Expected: no output.

---

### Task 10: Run focused verification and cleanup scans

**Files:**
- No planned file edits unless tests reveal compile errors.

- [ ] **Step 1: Run focused backend tests**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test -count=1 ./internal/config ./internal/bootstrap ./internal/module/uploadtoken ./internal/module/uploadconfig ./internal/platform/storage/cos
```

Expected:

```text
ok  	admin_back_go/internal/config
ok  	admin_back_go/internal/bootstrap
ok  	admin_back_go/internal/module/uploadtoken
ok  	admin_back_go/internal/module/uploadconfig
ok  	admin_back_go/internal/platform/storage/cos
```

- [ ] **Step 2: Run server-side COS consumer tests**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test -count=1 ./internal/module/exporttask ./internal/module/clientversion ./internal/module/aiimage
```

Expected:

```text
ok  	admin_back_go/internal/module/exporttask
ok  	admin_back_go/internal/module/clientversion
ok  	admin_back_go/internal/module/aiimage
```

- [ ] **Step 3: Confirm old config names are gone from active backend files**

Run:

```powershell
cd E:\admin_go\admin_back_go
rg -n "cfg\.UploadToken|UploadTokenConfig|COSSTSConfig|UPLOAD_TOKEN_TTL|UPLOAD_KEY_RANDOM_BYTES|COS_STS_ENABLED|COS_STS_ENDPOINT|COS_STS_REGION" internal deploy/docker-first/admin-go.env.example scripts/full-admin-smoke.ps1 README.md docs/architecture.md
```

Expected: no output.

- [ ] **Step 4: Confirm new setting key and defaults are present**

Run:

```powershell
cd E:\admin_go\admin_back_go
rg -n "upload.token.ttl_minutes|UploadTokenTTLSettingKey|DefaultTTL|DefaultSTSEndpoint|DefaultSTSRegion|skipped_upload_setting_missing" internal database scripts README.md docs/architecture.md
```

Expected output includes:

```text
internal/module/uploadtoken/policy.go
internal/module/uploadtoken/policy_test.go
database/migrations/20260520_upload_token_ttl_policy.sql
scripts/full-admin-smoke.ps1
```

---

### Task 11: Final governance verification and commits

**Files:**
- All files changed by Tasks 1-10.

- [ ] **Step 1: Run root whitespace check**

Run:

```powershell
cd E:\admin_go
git diff --check
```

Expected: no output and exit code `0`.

- [ ] **Step 2: Run governance checker**

Run:

```powershell
cd E:\admin_go
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected:

```text
PASS: no blocking governance violations found.
```

- [ ] **Step 3: Inspect repo status**

Run:

```powershell
cd E:\admin_go
git status --short --branch
git -C admin_back_go status --short --branch
git -C admin_front_ts status --short --branch
```

Expected:

```text
root repo: docs changes only
admin_back_go: backend/env/script/docs changes
admin_front_ts: clean
```

- [ ] **Step 4: Commit backend changes**

Run:

```powershell
cd E:\admin_go\admin_back_go
git add internal/config/config.go internal/config/config_test.go internal/config/upload_token_config_test.go internal/module/uploadtoken/policy.go internal/module/uploadtoken/policy_test.go internal/module/uploadtoken/service.go internal/module/uploadtoken/service_test.go internal/platform/storage/cos/signer.go internal/platform/storage/cos/signer_test.go internal/bootstrap/app.go internal/bootstrap/worker.go database/migrations/20260520_upload_token_ttl_policy.sql deploy/docker-first/admin-go.env.example scripts/full-admin-smoke.ps1 docs/architecture.md README.md
git commit -m "refactor: move upload runtime policy out of env"
```

If `internal/config/upload_token_config_test.go` was deleted, the `git add` command stages the deletion.

- [ ] **Step 5: Commit root docs changes**

Run:

```powershell
cd E:\admin_go
git add docs/status/current-status.md docs/testing/smoke-matrix.md docs/contracts/admin-api-v1.md docs/deployment/docker-first-backend.md
git commit -m "docs: update upload runtime env contract"
```

- [ ] **Step 6: Stop before push**

Do not push unless the user says `push吧` or explicitly asks to push. Report commit hashes and verification evidence.
