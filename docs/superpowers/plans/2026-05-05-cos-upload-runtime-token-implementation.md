# COS Upload Runtime Token Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Work in the current branch only; do not create a worktree. Do not commit or push unless the user explicitly asks.

**Goal:** Replace the legacy `/api/getUploadToken` runtime with a Go REST endpoint and typed Vue upload client that support COS by default and keep OSS as an explicit optional extension.

**Architecture:** Backend stays a Gin modular monolith. The new `uploadtoken` module owns HTTP/service/repository rules; the new `platform/storage/cos` package owns COS STS signing behind a small interface. Frontend keeps one shared upload client, but token acquisition moves to `request + /api/admin/v1/upload-tokens` and OSS no longer pretends to be built in.

**Tech Stack:** Go, Gin, GORM, MySQL, stdlib context/http/crypto, optional Tencent COS STS SDK after verification, Vue 3, TypeScript, existing `cos-js-sdk-v5`.

---

## Source Spec

Read first:

- `AGENTS.md`
- `docs/superpowers/specs/2026-05-05-cos-upload-runtime-token-design.md`
- `docs/contracts/admin-api-v1.md`
- `docs/migration/current-status.md`
- `admin_back_go/docs/architecture.md`
- `admin_front_ts/src/lib/upload/uploadClient.ts`

Do not implement OSS runtime in this plan.

---

## File Map

Backend create:

```text
admin_back_go/internal/module/uploadtoken/request.go
admin_back_go/internal/module/uploadtoken/dto.go
admin_back_go/internal/module/uploadtoken/model.go
admin_back_go/internal/module/uploadtoken/repository.go
admin_back_go/internal/module/uploadtoken/service.go
admin_back_go/internal/module/uploadtoken/handler.go
admin_back_go/internal/module/uploadtoken/route.go
admin_back_go/internal/module/uploadtoken/errors.go
admin_back_go/internal/module/uploadtoken/service_test.go
admin_back_go/internal/platform/storage/cos/signer.go
admin_back_go/internal/platform/storage/cos/signer_test.go
```

Backend modify:

```text
admin_back_go/internal/config/config.go
admin_back_go/internal/config/upload_token_config_test.go
admin_back_go/internal/bootstrap/app.go
admin_back_go/internal/bootstrap/route_meta.go
admin_back_go/internal/bootstrap/route_meta_test.go
admin_back_go/internal/server/router.go
admin_back_go/internal/server/router_test.go
admin_back_go/.env.example
admin_back_go/scripts/full-admin-smoke.ps1
admin_back_go/docs/architecture.md
```

Frontend create:

```text
admin_front_ts/src/api/system/uploadToken.ts
```

Frontend modify:

```text
admin_front_ts/src/lib/upload/uploadClient.ts
```

Workspace docs modify:

```text
docs/contracts/admin-api-v1.md
docs/migration/current-status.md
docs/testing/smoke-matrix.md
```

---

## Task 1: Config and COS signer boundary

**Files:**

- Modify: `admin_back_go/internal/config/config.go`
- Create: `admin_back_go/internal/config/upload_token_config_test.go`
- Create: `admin_back_go/internal/platform/storage/cos/signer.go`
- Create: `admin_back_go/internal/platform/storage/cos/signer_test.go`
- Modify: `admin_back_go/.env.example`

- [ ] Add upload token config structs in `admin_back_go/internal/config/config.go`:

```go
type UploadTokenConfig struct {
	TTL            time.Duration
	KeyRandomBytes int
	COS            COSSTSConfig
}

type COSSTSConfig struct {
	Enabled bool
	Endpoint string
	Region   string
}
```

- [ ] Add config field:

```go
type Config struct {
	// existing fields...
	Secretbox  SecretboxConfig
	UploadToken UploadTokenConfig
	CORS       CORSConfig
}
```

- [ ] Load env in `Load()` right after `Secretbox`:

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

- [ ] Write config test:

```go
package config

import (
	"testing"
	"time"
)

func TestLoadReadsUploadTokenConfig(t *testing.T) {
	t.Setenv("UPLOAD_TOKEN_TTL", "10m")
	t.Setenv("UPLOAD_KEY_RANDOM_BYTES", "6")
	t.Setenv("COS_STS_ENABLED", "true")
	t.Setenv("COS_STS_ENDPOINT", "sts.tencentcloudapi.com")
	t.Setenv("COS_STS_REGION", "ap-shanghai")

	cfg := Load()

	if cfg.UploadToken.TTL != 10*time.Minute {
		t.Fatalf("expected 10m, got %s", cfg.UploadToken.TTL)
	}
	if cfg.UploadToken.KeyRandomBytes != 6 {
		t.Fatalf("expected random bytes 6, got %d", cfg.UploadToken.KeyRandomBytes)
	}
	if !cfg.UploadToken.COS.Enabled {
		t.Fatalf("expected COS STS enabled")
	}
	if cfg.UploadToken.COS.Endpoint != "sts.tencentcloudapi.com" {
		t.Fatalf("unexpected endpoint %q", cfg.UploadToken.COS.Endpoint)
	}
	if cfg.UploadToken.COS.Region != "ap-shanghai" {
		t.Fatalf("unexpected region %q", cfg.UploadToken.COS.Region)
	}
}
```

- [ ] Create signer boundary in `admin_back_go/internal/platform/storage/cos/signer.go`:

```go
package cos

import (
	"context"
	"errors"
	"time"
)

var (
	ErrDisabled      = errors.New("cos sts: disabled")
	ErrInvalidConfig = errors.New("cos sts: invalid config")
)

type SignInput struct {
	SecretID  string
	SecretKey string
	Bucket    string
	Region    string
	Key       string
	TTL       time.Duration
}

type Credentials struct {
	TmpSecretID  string
	TmpSecretKey string
	SessionToken string
	StartTime    int64
	ExpiredTime  int64
}

type CredentialSigner interface {
	Sign(ctx context.Context, input SignInput) (*Credentials, error)
}

type DisabledSigner struct{}

func (DisabledSigner) Sign(ctx context.Context, input SignInput) (*Credentials, error) {
	return nil, ErrDisabled
}
```

- [ ] Add signer tests:

```go
package cos

import (
	"context"
	"errors"
	"testing"
	"time"
)

func TestDisabledSignerReturnsExplicitError(t *testing.T) {
	_, err := (DisabledSigner{}).Sign(context.Background(), SignInput{
		SecretID: "sid", SecretKey: "skey", Bucket: "bucket", Region: "ap-nanjing", Key: "images/a.png", TTL: time.Minute,
	})
	if !errors.Is(err, ErrDisabled) {
		t.Fatalf("expected ErrDisabled, got %v", err)
	}
}
```

- [ ] Update `.env.example`:

```dotenv
# Upload runtime token config. COS STS is disabled by default; upload config CRUD does not require it.
UPLOAD_TOKEN_TTL=15m
UPLOAD_KEY_RANDOM_BYTES=4
COS_STS_ENABLED=false
COS_STS_ENDPOINT=sts.tencentcloudapi.com
COS_STS_REGION=ap-guangzhou
```

- [ ] Run:

```powershell
cd E:\admin_go\admin_back_go
go test -p=1 ./internal/config ./internal/platform/storage/cos
```

Expected: PASS.

---

## Task 2: Backend uploadtoken module tests and service

**Files:**

- Create: `admin_back_go/internal/module/uploadtoken/errors.go`
- Create: `admin_back_go/internal/module/uploadtoken/model.go`
- Create: `admin_back_go/internal/module/uploadtoken/dto.go`
- Create: `admin_back_go/internal/module/uploadtoken/repository.go`
- Create: `admin_back_go/internal/module/uploadtoken/service.go`
- Create: `admin_back_go/internal/module/uploadtoken/service_test.go`

- [ ] Create `errors.go`:

```go
package uploadtoken

import "errors"

var ErrRepositoryNotConfigured = errors.New("upload token repository is not configured")

const ErrRepositoryNotConfiguredMessage = "上传运行时仓储未配置"
```

- [ ] Create `model.go`:

```go
package uploadtoken

type EnabledConfig struct {
	SettingID    int64
	DriverID     int64
	RuleID       int64
	Driver       string
	SecretIDEnc  string
	SecretKeyEnc string
	Bucket       string
	Region       string
	AppID        string
	Endpoint     string
	BucketDomain string
	RoleARN      string
	MaxSizeMB    int
	ImageExts    string
	FileExts     string
}
```

- [ ] Create `dto.go`:

```go
package uploadtoken

type CreateInput struct {
	Folder   string
	FileName string
	FileSize int64
	FileKind string
}

type CreateResponse struct {
	Provider     string          `json:"provider"`
	Bucket       string          `json:"bucket"`
	Region       string          `json:"region"`
	Key          string          `json:"key"`
	UploadPath   string          `json:"upload_path"`
	BucketDomain *string         `json:"bucket_domain"`
	Credentials  CredentialsDTO  `json:"credentials"`
	StartTime    int64           `json:"start_time"`
	ExpiredTime  int64           `json:"expired_time"`
	Rule         UploadRuleDTO   `json:"rule"`
}

type CredentialsDTO struct {
	TmpSecretID  string `json:"tmp_secret_id"`
	TmpSecretKey string `json:"tmp_secret_key"`
	SessionToken string `json:"session_token"`
}

type UploadRuleDTO struct {
	MaxSizeMB int      `json:"max_size_mb"`
	ImageExts []string `json:"image_exts"`
	FileExts  []string `json:"file_exts"`
}
```

- [ ] Create repository interface and GORM query in `repository.go`:

```go
package uploadtoken

import (
	"context"
	"errors"

	"admin_back_go/internal/enum"
	"admin_back_go/internal/platform/database"

	"gorm.io/gorm"
)

type Repository interface {
	GetEnabledConfig(ctx context.Context) (*EnabledConfig, error)
}

type GormRepository struct {
	db *gorm.DB
}

func NewGormRepository(client *database.Client) *GormRepository {
	if client == nil || client.Gorm == nil {
		return nil
	}
	return &GormRepository{db: client.Gorm}
}

func (r *GormRepository) GetEnabledConfig(ctx context.Context) (*EnabledConfig, error) {
	if r == nil || r.db == nil {
		return nil, ErrRepositoryNotConfigured
	}

	var row EnabledConfig
	err := r.db.WithContext(ctx).
		Table("upload_setting AS s").
		Select(`s.id AS setting_id, s.driver_id, s.rule_id,
			d.driver, d.secret_id_enc, d.secret_key_enc, d.bucket, d.region, d.appid, d.endpoint, d.bucket_domain, d.role_arn,
			rule.max_size_mb, rule.image_exts, rule.file_exts`).
		Joins("JOIN upload_driver AS d ON d.id = s.driver_id AND d.is_del = ?", enum.CommonNo).
		Joins("JOIN upload_rule AS rule ON rule.id = s.rule_id AND rule.is_del = ?", enum.CommonNo).
		Where("s.status = ?", enum.CommonYes).
		Where("s.is_del = ?", enum.CommonNo).
		Order("s.id DESC").
		Limit(1).
		Scan(&row).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	if row.SettingID == 0 {
		return nil, nil
	}
	return &row, nil
}
```

- [ ] Create `service.go` with explicit dependencies:

```go
package uploadtoken

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"path/filepath"
	"strings"
	"time"

	"admin_back_go/internal/apperror"
	"admin_back_go/internal/enum"
	"admin_back_go/internal/platform/secretbox"
	storagecos "admin_back_go/internal/platform/storage/cos"
)

const (
	ProviderCOS = "cos"
	FileKindImage = "image"
	FileKindFile = "file"
)

type Service struct {
	repo Repository
	box secretbox.Box
	signer storagecos.CredentialSigner
	ttl time.Duration
	randomBytes int
	now func() time.Time
	random func([]byte) (int, error)
}

type Options struct {
	TTL time.Duration
	RandomBytes int
	Now func() time.Time
	Random func([]byte) (int, error)
}

func NewService(repo Repository, box secretbox.Box, signer storagecos.CredentialSigner, opts Options) *Service {
	if signer == nil {
		signer = storagecos.DisabledSigner{}
	}
	if opts.TTL <= 0 {
		opts.TTL = 15 * time.Minute
	}
	if opts.RandomBytes <= 0 {
		opts.RandomBytes = 4
	}
	if opts.Now == nil {
		opts.Now = time.Now
	}
	if opts.Random == nil {
		opts.Random = rand.Read
	}
	return &Service{repo: repo, box: box, signer: signer, ttl: opts.TTL, randomBytes: opts.RandomBytes, now: opts.Now, random: opts.Random}
}

func (s *Service) Create(ctx context.Context, input CreateInput) (*CreateResponse, *apperror.Error) {
	input = normalizeInput(input)
	if !enum.IsUploadFolder(input.Folder) {
		return nil, apperror.BadRequest("上传目录不支持")
	}
	if input.FileName == "" {
		return nil, apperror.BadRequest("文件名不能为空")
	}
	if input.FileSize <= 0 {
		return nil, apperror.BadRequest("文件大小不正确")
	}
	if input.FileKind != FileKindImage && input.FileKind != FileKindFile {
		return nil, apperror.BadRequest("上传类型不支持")
	}
	if s == nil || s.repo == nil {
		return nil, apperror.Internal(ErrRepositoryNotConfiguredMessage)
	}

	cfg, err := s.repo.GetEnabledConfig(ctx)
	if err != nil {
		return nil, apperror.Internal("读取上传配置失败")
	}
	if cfg == nil {
		return nil, apperror.BadRequest("未配置有效上传设置")
	}
	if cfg.Driver != enum.UploadDriverCOS {
		return nil, apperror.BadRequest("当前上传驱动未启用 COS runtime")
	}

	imageExts, fileExts, appErr := parseRuleExts(cfg)
	if appErr != nil {
		return nil, appErr
	}
	if appErr := validateFile(input, cfg.MaxSizeMB, imageExts, fileExts); appErr != nil {
		return nil, appErr
	}

	secretID, err := s.box.Decrypt(cfg.SecretIDEnc)
	if err != nil || secretID == "" {
		return nil, apperror.Internal("上传密钥不可用")
	}
	secretKey, err := s.box.Decrypt(cfg.SecretKeyEnc)
	if err != nil || secretKey == "" {
		return nil, apperror.Internal("上传密钥不可用")
	}

	key, err := s.buildKey(input.Folder, input.FileName)
	if err != nil {
		return nil, apperror.Internal("生成上传路径失败")
	}
	creds, err := s.signer.Sign(ctx, storagecos.SignInput{
		SecretID: secretID, SecretKey: secretKey, Bucket: cfg.Bucket, Region: cfg.Region, Key: key, TTL: s.ttl,
	})
	if errors.Is(err, storagecos.ErrDisabled) {
		return nil, apperror.Internal("COS 临时凭证未启用")
	}
	if err != nil {
		return nil, apperror.Internal("COS 临时凭证签发失败")
	}
	if creds == nil {
		return nil, apperror.Internal("COS 临时凭证签发失败")
	}

	return &CreateResponse{
		Provider: ProviderCOS,
		Bucket: cfg.Bucket,
		Region: cfg.Region,
		Key: key,
		UploadPath: uploadPath(input.Folder, s.now()),
		BucketDomain: optionalString(cfg.BucketDomain),
		Credentials: CredentialsDTO{TmpSecretID: creds.TmpSecretID, TmpSecretKey: creds.TmpSecretKey, SessionToken: creds.SessionToken},
		StartTime: creds.StartTime,
		ExpiredTime: creds.ExpiredTime,
		Rule: UploadRuleDTO{MaxSizeMB: cfg.MaxSizeMB, ImageExts: imageExts, FileExts: fileExts},
	}, nil
}

func normalizeInput(input CreateInput) CreateInput {
	input.Folder = strings.Trim(strings.TrimSpace(input.Folder), "/")
	input.FileName = filepath.Base(strings.TrimSpace(input.FileName))
	input.FileKind = strings.TrimSpace(input.FileKind)
	return input
}

func parseRuleExts(cfg *EnabledConfig) ([]string, []string, *apperror.Error) {
	var imageExts []string
	var fileExts []string
	if err := json.Unmarshal([]byte(cfg.ImageExts), &imageExts); err != nil {
		return nil, nil, apperror.BadRequest("上传配置不完整")
	}
	if err := json.Unmarshal([]byte(cfg.FileExts), &fileExts); err != nil {
		return nil, nil, apperror.BadRequest("上传配置不完整")
	}
	return imageExts, fileExts, nil
}

func validateFile(input CreateInput, maxSizeMB int, imageExts []string, fileExts []string) *apperror.Error {
	if maxSizeMB > 0 && input.FileSize > int64(maxSizeMB)*1024*1024 {
		return apperror.BadRequest("文件大小超过限制")
	}
	ext := strings.TrimPrefix(strings.ToLower(filepath.Ext(input.FileName)), ".")
	if ext == "" {
		return apperror.BadRequest("文件类型不支持")
	}
	allowed := fileExts
	if input.FileKind == FileKindImage {
		allowed = imageExts
	}
	for _, item := range allowed {
		if strings.EqualFold(item, ext) {
			return nil
		}
	}
	return apperror.BadRequest("文件类型不支持")
}

func (s *Service) buildKey(folder string, fileName string) (string, error) {
	now := s.now()
	randomPart, err := s.randomHex()
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("%s%d-%s-%s", uploadPath(folder, now), now.UnixMilli(), randomPart, safeFileName(fileName)), nil
}

func (s *Service) randomHex() (string, error) {
	buf := make([]byte, s.randomBytes)
	if _, err := s.random(buf); err != nil {
		return "", err
	}
	return hex.EncodeToString(buf), nil
}

func uploadPath(folder string, now time.Time) string {
	return fmt.Sprintf("%s/%04d/%02d/%02d/", folder, now.Year(), now.Month(), now.Day())
}

func safeFileName(name string) string {
	name = filepath.Base(strings.TrimSpace(name))
	if name == "." || name == string(filepath.Separator) || name == "" {
		name = "file"
	}
	var b strings.Builder
	for _, r := range name {
		if (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') || (r >= '0' && r <= '9') || r == '.' || r == '_' || r == '-' {
			b.WriteRune(r)
			continue
		}
		b.WriteByte('_')
	}
	out := b.String()
	if out == "" {
		out = "file"
	}
	if len(out) > 120 {
		out = out[len(out)-120:]
	}
	return out
}

func optionalString(value string) *string {
	value = strings.TrimSpace(value)
	if value == "" {
		return nil
	}
	return &value
}
```

- [ ] Add service tests covering spec. Use this fake signer:

```go
type fakeSigner struct {
	input storagecos.SignInput
	err error
}

func (f *fakeSigner) Sign(ctx context.Context, input storagecos.SignInput) (*storagecos.Credentials, error) {
	f.input = input
	if f.err != nil {
		return nil, f.err
	}
	return &storagecos.Credentials{
		TmpSecretID: "tmp-id", TmpSecretKey: "tmp-key", SessionToken: "token", StartTime: 100, ExpiredTime: 200,
	}, nil
}
```

- [ ] Minimum test names:

```text
TestCreateRejectsMissingEnabledSetting
TestCreateRejectsNonCOSDriver
TestCreateRejectsUnsupportedFolder
TestCreateRejectsUnsupportedImageExtension
TestCreateRejectsOversizeFile
TestCreateBuildsSafeKeyAndSignsCOS
TestCreateDoesNotExposeDriverSecrets
TestCreateReturnsExplicitDisabledError
```

- [ ] Run:

```powershell
cd E:\admin_go\admin_back_go
go test -p=1 ./internal/module/uploadtoken
```

Expected: PASS.

---

## Task 3: Backend HTTP route, bootstrap, permission, and operation metadata

**Files:**

- Create: `admin_back_go/internal/module/uploadtoken/request.go`
- Create: `admin_back_go/internal/module/uploadtoken/handler.go`
- Create: `admin_back_go/internal/module/uploadtoken/route.go`
- Modify: `admin_back_go/internal/server/router.go`
- Modify: `admin_back_go/internal/bootstrap/app.go`
- Modify: `admin_back_go/internal/bootstrap/route_meta.go`
- Modify: `admin_back_go/internal/bootstrap/route_meta_test.go`
- Modify: `admin_back_go/internal/server/router_test.go`

- [ ] Create `request.go`:

```go
package uploadtoken

type createRequest struct {
	Folder   string `json:"folder" binding:"required,upload_folder"`
	FileName string `json:"file_name" binding:"required,max=255"`
	FileSize int64  `json:"file_size" binding:"required,min=1"`
	FileKind string `json:"file_kind" binding:"required,oneof=image file"`
}
```

- [ ] Create `handler.go`:

```go
package uploadtoken

import (
	"context"

	"admin_back_go/internal/apperror"
	"admin_back_go/internal/response"

	"github.com/gin-gonic/gin"
)

type HTTPService interface {
	Create(ctx context.Context, input CreateInput) (*CreateResponse, *apperror.Error)
}

type Handler struct {
	service HTTPService
}

func NewHandler(service HTTPService) *Handler {
	return &Handler{service: service}
}

func (h *Handler) Create(c *gin.Context) {
	var req createRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, apperror.BadRequest("上传 token 参数错误"))
		return
	}
	result, appErr := h.requireService().Create(c.Request.Context(), CreateInput{
		Folder: req.Folder, FileName: req.FileName, FileSize: req.FileSize, FileKind: req.FileKind,
	})
	if appErr != nil {
		response.Error(c, appErr)
		return
	}
	response.OK(c, result)
}

func (h *Handler) requireService() HTTPService {
	if h == nil || h.service == nil {
		return failingService{}
	}
	return h.service
}

type failingService struct{}

func (failingService) Create(ctx context.Context, input CreateInput) (*CreateResponse, *apperror.Error) {
	return nil, apperror.Internal("上传运行时服务未配置")
}
```

- [ ] Create `route.go`:

```go
package uploadtoken

import (
	"admin_back_go/internal/validate"

	"github.com/gin-gonic/gin"
)

func RegisterRoutes(router *gin.Engine, service HTTPService) {
	validate.MustRegister()
	handler := NewHandler(service)
	group := router.Group("/api/admin/v1/upload-tokens")
	group.POST("", handler.Create)
}
```

- [ ] Modify `server.Dependencies` in `admin_back_go/internal/server/router.go`:

```go
UploadTokenService uploadtoken.HTTPService
```

Register after upload config:

```go
uploadtoken.RegisterRoutes(router, deps.UploadTokenService)
```

- [ ] Modify bootstrap:

```go
uploadTokenService := uploadtoken.NewService(
	uploadtoken.NewGormRepository(resources.DB),
	secretBox,
	cosSigner,
	uploadtoken.Options{TTL: cfg.UploadToken.TTL, RandomBytes: cfg.UploadToken.KeyRandomBytes},
)
```

Use disabled signer when `COS_STS_ENABLED=false`. If a real signer is not implemented yet, wire `storagecos.DisabledSigner{}` and leave Task 4 to replace it.

- [ ] Add route metadata in `route_meta.go`:

```go
middleware.NewRouteKey(http.MethodPost, "/api/admin/v1/upload-tokens"): "system_uploadToken_create",
```

Operation rule:

```go
middleware.NewRouteKey(http.MethodPost, "/api/admin/v1/upload-tokens"): {
	Module: "upload_token",
	Action: "create",
	Title:  "签发上传凭证",
},
```

- [ ] Update route meta tests to assert permission and operation rule exist.

- [ ] Add router test asserting `POST /api/admin/v1/upload-tokens` reaches fake service with valid body and returns `provider=cos`.

- [ ] Run:

```powershell
cd E:\admin_go\admin_back_go
go test -p=1 ./internal/server ./internal/bootstrap ./internal/module/uploadtoken
```

Expected: PASS.

---

## Task 4: Real COS STS signer

**Files:**

- Modify: `admin_back_go/go.mod`
- Modify: `admin_back_go/internal/platform/storage/cos/signer.go`
- Modify: `admin_back_go/internal/platform/storage/cos/signer_test.go`
- Modify: `admin_back_go/internal/bootstrap/app.go`

- [ ] Before adding a dependency, verify the chosen Tencent STS package from official source. Record the chosen package in `admin_back_go/docs/architecture.md`.

- [ ] If using `github.com/tencentyun/qcloud-cos-sts-sdk/go`, add it with:

```powershell
cd E:\admin_go\admin_back_go
go get github.com/tencentyun/qcloud-cos-sts-sdk/go
```

If this package shape is unusable with the current Go version, do not force it. Implement a thin `net/http` Tencent STS client in `platform/storage/cos` instead, with context timeout and tests using `httptest.Server`.

- [ ] Real signer must:

```text
return ErrDisabled when config.Enabled=false
reject empty secret_id / secret_key / bucket / region / key
request a token scoped to one object key or its exact prefix
respect input TTL
propagate context cancellation
wrap provider errors with fmt.Errorf("%w", err)
```

- [ ] Tests must not call real Tencent network. Use fake HTTP server or fake SDK boundary.

- [ ] Bootstrap must choose real signer only when `cfg.UploadToken.COS.Enabled` is true:

```go
cosSigner := storagecos.DisabledSigner{}
if cfg.UploadToken.COS.Enabled {
	cosSigner = storagecos.NewSigner(storagecos.Config{
		Endpoint: cfg.UploadToken.COS.Endpoint,
		Region: cfg.UploadToken.COS.Region,
	})
}
```

Adjust concrete type if constructor returns interface.

- [ ] Run:

```powershell
cd E:\admin_go\admin_back_go
go test -p=1 ./internal/platform/storage/cos ./internal/module/uploadtoken ./internal/bootstrap
go vet -p=1 ./...
```

Expected: PASS.

---

## Task 5: Frontend typed upload token API and upload client cleanup

**Files:**

- Create: `admin_front_ts/src/api/system/uploadToken.ts`
- Modify: `admin_front_ts/src/lib/upload/uploadClient.ts`

- [ ] Create `uploadToken.ts`:

```ts
import request from '@/lib/http'
import { ADMIN_API_PREFIX } from '@/lib/http/api-prefix'

export type UploadProvider = 'cos'
export type UploadFileKind = 'image' | 'file'

export interface UploadTokenRequest {
  folder: string
  file_name: string
  file_size: number
  file_kind: UploadFileKind
}

export interface UploadCredentials {
  tmp_secret_id: string
  tmp_secret_key: string
  session_token: string
}

export interface UploadRule {
  max_size_mb: number
  image_exts: string[]
  file_exts: string[]
}

export interface UploadTokenResponse {
  provider: UploadProvider
  bucket: string
  region: string
  key: string
  upload_path: string
  bucket_domain: string | null
  credentials: UploadCredentials
  start_time: number
  expired_time: number
  rule: UploadRule
}

const BASE = `${ADMIN_API_PREFIX}/upload-tokens`

export const UploadTokenApi = {
  create: (params: UploadTokenRequest) => request.post<UploadTokenResponse, UploadTokenRequest>(BASE, params),
}
```

- [ ] Rewrite `uploadClient.ts` so imports start with:

```ts
import { UploadTokenApi, type UploadFileKind, type UploadTokenRequest, type UploadTokenResponse } from '@/api/system/uploadToken'
```

- [ ] Define local COS SDK callback types instead of `any`:

```ts
interface CosAuthorization {
  TmpSecretId: string
  TmpSecretKey: string
  SecurityToken: string
  StartTime: number
  ExpiredTime: number
}

interface CosClient {
  putObject(
    params: { Bucket: string; Region: string; Key: string; Body: File },
    callback: (error: Error | null) => void
  ): void
}

type CosConstructor = new (options: {
  getAuthorization: (_options: unknown, callback: (authorization: CosAuthorization) => void) => void
}) => CosClient
```

- [ ] Make `loadCOS` typed:

```ts
const loadCOS = () => import('cos-js-sdk-v5').then(module => module.default as CosConstructor)
```

- [ ] Replace legacy token call:

```ts
export const getUploadToken = (params: UploadTokenRequest): Promise<UploadTokenResponse> => {
  return UploadTokenApi.create(params)
}
```

- [ ] Update `uploadFileToCloud` to accept `UploadTokenResponse` and only support COS:

```ts
export const uploadFileToCloud = async (
  file: File,
  config: UploadTokenResponse
): Promise<{ url: string; key: string }> => {
  if (config.provider !== 'cos') {
    throw new Error('当前版本未启用 OSS 上传运行时，请安装可选扩展或切换为 COS')
  }
  return uploadToCos(file, config.key, config)
}
```

- [ ] Update credential field names:

```ts
TmpSecretId: credentials.tmp_secret_id
TmpSecretKey: credentials.tmp_secret_key
SecurityToken: credentials.session_token
StartTime: config.start_time
ExpiredTime: config.expired_time
```

- [ ] Delete OSS dynamic import from `uploadClient.ts`. No `ali-oss` string should remain in this file.

- [ ] Ensure no `any`, `as any`, or `Record<string, any>` in touched frontend files:

```powershell
cd E:\admin_go\admin_front_ts
rg -n "\bany\b|as any|Record<string, any>|legacyRequest|ali-oss|/api/getUploadToken" src/lib/upload/uploadClient.ts src/api/system/uploadToken.ts
```

Expected: no matches for forbidden patterns except harmless words inside comments are not allowed either.

- [ ] Run:

```powershell
cd E:\admin_go\admin_front_ts
npx vue-tsc -b --pretty false
npx eslint src/api/system/uploadToken.ts src/lib/upload/uploadClient.ts
```

Expected: typecheck PASS; eslint 0 errors.

---

## Task 6: Contract docs, smoke, and migration status

**Files:**

- Modify: `docs/contracts/admin-api-v1.md`
- Modify: `docs/migration/current-status.md`
- Modify: `docs/testing/smoke-matrix.md`
- Modify: `admin_back_go/docs/architecture.md`
- Modify: `admin_back_go/scripts/full-admin-smoke.ps1`

- [ ] Add contract section:

```md
## Upload Runtime Tokens

状态：implemented only after backend/frontend/smoke pass.

`POST /api/admin/v1/upload-tokens`

Request:
...

Response:
...

Rules:
- COS only by default.
- OSS runtime is optional and unsupported unless a future extension explicitly wires it.
- No legacy `/api/getUploadToken` fallback.
```

- [ ] Add auth matrix row:

```text
upload token create | POST /api/admin/v1/upload-tokens | bearer token + system_uploadToken_create route permission
```

- [ ] Update `docs/migration/current-status.md` only after verification:

```text
upload runtime/token | implemented: COS-first token signing endpoint, server-generated key, rule validation, explicit OSS unsupported | adapted: shared upload client uses Go request and cos-js-sdk-v5 only | tests... | full smoke... | contract + architecture | no OSS runtime; no server-side upload
```

- [ ] Update `docs/testing/smoke-matrix.md`:

```text
upload token shape | no | gated yes | POST /api/admin/v1/upload-tokens | token only | n/a | skip when COS_STS_ENABLED=false; never uploads real file
```

- [ ] Extend full smoke:

```text
If COS_STS_ENABLED is false or missing:
  upload_token_probe = skipped_cos_sts_disabled
If enabled:
  POST upload-tokens with folder=images,file_name=smoke.png,file_size=1024,file_kind=image
  assert provider=cos, key starts with images/, credentials fields are non-empty
```

- [ ] Do not make smoke depend on real file upload.

- [ ] Run:

```powershell
cd E:\admin_go
git diff --check
```

Expected: PASS.

---

## Task 7: Full verification gate

- [ ] Backend:

```powershell
cd E:\admin_go\admin_back_go
go test -p=1 ./...
go vet -p=1 ./...
git diff --check
```

- [ ] Frontend:

```powershell
cd E:\admin_go\admin_front_ts
npx vue-tsc -b --pretty false
npx eslint src/api/system/uploadToken.ts src/lib/upload/uploadClient.ts
```

- [ ] Full smoke:

```powershell
cd E:\admin_go\admin_back_go
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account 15671628271 -Password 123456
```

Expected:

```text
full smoke exits 0
upload config probes still pass
upload_token_probe is either skipped_cos_sts_disabled or passed
```

- [ ] Final report:

```text
Outcome:
Changed files:
Backend verification:
Frontend verification:
Smoke summary:
Known remaining risks:
Next recommended module:
```

---

## Self-review

Spec coverage:

```text
COS-only default: Task 1, 2, 4, 5, 6
OSS optional/no default dependency: Task 4, 5, 6
REST endpoint: Task 3, 6
frontend no legacyRequest/no any: Task 5
server-generated key/rule validation: Task 2
docs/smoke/status: Task 6, 7
```

Known risk:

```text
Tencent STS package API shape must be verified during Task 4 before coding against it. If it is awkward or stale, use a thin net/http signer behind the same interface instead of leaking provider details upward.
```
