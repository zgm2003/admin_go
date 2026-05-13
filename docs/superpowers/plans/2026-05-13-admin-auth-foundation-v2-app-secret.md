# Admin Auth Foundation v2 APP_SECRET Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace split `TOKEN_PEPPER` / `VAULT_KEY` runtime secrets with one `APP_SECRET`, then upgrade admin access tokens to JWT while keeping opaque refresh tokens and `user_sessions` as the login-state truth source.

**Architecture:** `APP_SECRET` is read from config and expanded through HKDF into purpose-specific keys. `secretbox` receives only the derived AES-GCM key, `session.Authenticator` receives a derived token pepper and a JWT access-token codec, and `AuthToken` middleware remains a thin project-owned boundary. Refresh tokens stay opaque and are stored only as peppered hashes; JWT access tokens are verified, then the session is checked against `user_sessions` and Redis session cache.

**Tech Stack:** Go 1.26 stdlib `crypto/hkdf`, Gin, GORM/MySQL, Redis, existing `secretbox`, new `internal/platform/accesstoken`, `github.com/golang-jwt/jwt/v5`, PowerShell smoke scripts.

---

## Scope Check

This is one coupled change, not two independent jobs. `APP_SECRET` affects token hashing, JWT signing, and secretbox encryption, so auth and env must move together in one plan.

This plan deliberately does not implement OAuth2/OIDC login. It only creates the correct foundation so an OAuth2 callback can later create a normal `user_sessions` row and issue this system's own token pair.

---

## File Structure

### Create

- `admin_back_go/internal/platform/secretkey/secretkey.go`  
  Root-secret validation and HKDF-derived purpose keys.
- `admin_back_go/internal/platform/secretkey/secretkey_test.go`  
  Deterministic, separated, 32-byte derivation and unsafe-secret rejection.
- `admin_back_go/internal/platform/accesstoken/jwt.go`  
  JWT access-token issue/parse. No Gin, DB, Redis, or RBAC import.
- `admin_back_go/internal/platform/accesstoken/jwt_test.go`  
  JWT round trip, tamper rejection, wrong-signing-key rejection, and expired token rejection.
- `docs/deployment/auth-foundation-v2-reset-runbook.md`  
  Destructive reset runbook for the not-yet-online environment.

### Modify

- `admin_back_go/go.mod` / `admin_back_go/go.sum`: add direct dependency `github.com/golang-jwt/jwt/v5`.
- `admin_back_go/internal/config/config.go`: add `App.Secret`, remove runtime dependence on `TOKEN_PEPPER` and `VAULT_KEY`, add validation.
- `admin_back_go/internal/config/config_test.go`: replace token pepper / vault tests with `APP_SECRET` tests.
- `admin_back_go/internal/platform/secretbox/secretbox.go`: change raw string key hashing to injected 32-byte key.
- `admin_back_go/internal/module/session/*`: JWT access, opaque refresh, session-id cache key, session-id lookup.
- `admin_back_go/internal/module/usersession/*`: revoke cache by session id, not access-token hash.
- `admin_back_go/internal/bootstrap/*`: build keyring once and inject derived keys.
- `admin_back_go/cmd/admin-api/main.go` / `cmd/admin-worker/main.go`: fail startup on unsafe `APP_SECRET`.
- `admin_back_go/.env` / `.env.example`: replace `TOKEN_PEPPER` and `VAULT_KEY` with `APP_SECRET`.
- `admin_back_go/docs/architecture.md`, `docs/contracts/admin-api-v1.md`, `docs/deployment/production.md`, `docs/architecture/06-admin-middleware-selection.md`: update runtime truth.

---

## Task 1: Add `APP_SECRET` config and validation

**Files:**
- Modify: `admin_back_go/internal/config/config.go`
- Modify: `admin_back_go/internal/config/config_test.go`
- Delete or rewrite: `admin_back_go/internal/config/secretbox_config_test.go`

- [ ] **Step 1: Write failing config tests**

Add to `admin_back_go/internal/config/config_test.go`:

```go
func TestLoadReadsAppSecret(t *testing.T) {
	t.Setenv("APP_SECRET", strings.Repeat("a", 64))

	cfg := Load()

	if cfg.App.Secret != strings.Repeat("a", 64) {
		t.Fatalf("expected APP_SECRET to be loaded")
	}
}

func TestValidateRuntimeSecretsRejectsMissingAppSecret(t *testing.T) {
	cfg := Config{App: AppConfig{Name: "admin-api", Env: "local"}}

	err := ValidateRuntimeSecrets(cfg)

	if err == nil || !strings.Contains(err.Error(), "APP_SECRET") {
		t.Fatalf("expected APP_SECRET validation error, got %v", err)
	}
}

func TestValidateRuntimeSecretsRejectsDefaultAppSecret(t *testing.T) {
	cfg := Config{App: AppConfig{Name: "admin-api", Env: "local", Secret: "change_me_to_at_least_64_random_chars"}}

	err := ValidateRuntimeSecrets(cfg)

	if err == nil || !strings.Contains(err.Error(), "unsafe") {
		t.Fatalf("expected unsafe APP_SECRET validation error, got %v", err)
	}
}

func TestValidateRuntimeSecretsAcceptsLongAppSecret(t *testing.T) {
	cfg := Config{App: AppConfig{Name: "admin-api", Env: "local", Secret: strings.Repeat("k", 64)}}

	if err := ValidateRuntimeSecrets(cfg); err != nil {
		t.Fatalf("expected APP_SECRET to pass validation: %v", err)
	}
}
```

Also update `TestLoadReadsEnvironmentOverrides`:

```go
t.Setenv("APP_SECRET", strings.Repeat("s", 64))
```

and assert:

```go
if cfg.App.Secret != strings.Repeat("s", 64) {
	t.Fatalf("unexpected app secret")
}
```

Remove old test expectations for `cfg.Token.Pepper` and `cfg.Secretbox.Key`.

- [ ] **Step 2: Run config tests and verify they fail**

Run:

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/config
```

Expected: FAIL with compile errors for `AppConfig.Secret` and `ValidateRuntimeSecrets` not existing.

- [ ] **Step 3: Implement config loading and validation**

In `admin_back_go/internal/config/config.go`, change `AppConfig`:

```go
type AppConfig struct {
	Name   string
	Env    string
	Secret string
}
```

In `Load()`, change app construction:

```go
App: AppConfig{
	Name:   envString("APP_NAME", "admin-api"),
	Env:    envString("APP_ENV", "local"),
	Secret: envString("APP_SECRET", ""),
},
```

Remove `Pepper` from `TokenConfig`:

```go
type TokenConfig struct {
	RedisPrefix             string
	SessionCacheTTL         time.Duration
	SingleSessionPointerTTL time.Duration
	RedisDB                 int
}
```

Remove `SecretboxConfig` from `Config`; delete the `Secretbox: SecretboxConfig{Key: envString("VAULT_KEY", "")}` block.

Add validation:

```go
var unsafeAppSecrets = map[string]struct{}{
	"":                                      {},
	"change_me_to_at_least_64_random_chars": {},
	"change_me_to_long_random":              {},
}

func ValidateRuntimeSecrets(cfg Config) error {
	secret := strings.TrimSpace(cfg.App.Secret)
	if _, unsafe := unsafeAppSecrets[secret]; unsafe {
		return fmt.Errorf("APP_SECRET is missing or unsafe")
	}
	if len(secret) < 32 {
		return fmt.Errorf("APP_SECRET is too short: got %d chars, need at least 32", len(secret))
	}
	return nil
}
```

Add `fmt` to imports.

- [ ] **Step 4: Run config tests and verify they pass**

Run:

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/config
```

Expected: PASS.

- [ ] **Step 5: Commit config foundation**

Run:

```powershell
cd E:/admin_go/admin_back_go
git add -A internal/config
git commit -m "feat: introduce app secret config"
```

Expected: commit succeeds.

---

## Task 2: Add HKDF keyring

**Files:**
- Create: `admin_back_go/internal/platform/secretkey/secretkey.go`
- Create: `admin_back_go/internal/platform/secretkey/secretkey_test.go`

- [ ] **Step 1: Write failing keyring tests**

Create `admin_back_go/internal/platform/secretkey/secretkey_test.go`:

```go
package secretkey

import (
	"bytes"
	"strings"
	"testing"
)

func TestNewKeyRingDerivesStableSeparatedKeys(t *testing.T) {
	root := strings.Repeat("a", 64)

	first, err := NewKeyRing(root)
	if err != nil {
		t.Fatalf("NewKeyRing returned error: %v", err)
	}
	second, err := NewKeyRing(root)
	if err != nil {
		t.Fatalf("NewKeyRing second call returned error: %v", err)
	}

	if len(first.SecretboxKey()) != 32 || len(first.JWTSigningKey()) != 32 {
		t.Fatalf("expected 32-byte derived keys")
	}
	if !bytes.Equal(first.SecretboxKey(), second.SecretboxKey()) {
		t.Fatalf("expected stable secretbox derivation")
	}
	if bytes.Equal(first.SecretboxKey(), first.JWTSigningKey()) {
		t.Fatalf("expected secretbox and JWT keys to differ")
	}
	if first.TokenPepper() == "" {
		t.Fatalf("expected non-empty token pepper")
	}
}

func TestNewKeyRingRejectsUnsafeSecrets(t *testing.T) {
	for _, secret := range []string{"", "short", "change_me_to_at_least_64_random_chars"} {
		if _, err := NewKeyRing(secret); err == nil {
			t.Fatalf("expected %q to be rejected", secret)
		}
	}
}
```

- [ ] **Step 2: Run tests and verify they fail**

Run:

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/platform/secretkey
```

Expected: FAIL because package does not exist.

- [ ] **Step 3: Implement keyring**

Create `admin_back_go/internal/platform/secretkey/secretkey.go`:

```go
package secretkey

import (
	"crypto/hkdf"
	"crypto/sha256"
	"encoding/base64"
	"fmt"
	"strings"
)

const keyLength = 32

type KeyRing struct {
	secretboxKey    []byte
	tokenPepper     string
	jwtSigningKey   []byte
	sessionCacheKey []byte
}

func NewKeyRing(rootSecret string) (*KeyRing, error) {
	root := strings.TrimSpace(rootSecret)
	if root == "" || root == "change_me_to_at_least_64_random_chars" || root == "change_me_to_long_random" {
		return nil, fmt.Errorf("APP_SECRET is missing or unsafe")
	}
	if len(root) < 32 {
		return nil, fmt.Errorf("APP_SECRET is too short: got %d chars, need at least 32", len(root))
	}
	tokenPepperKey, err := derive(root, "admin_go:token-pepper:v1")
	if err != nil {
		return nil, err
	}
	secretboxKey, err := derive(root, "admin_go:secretbox:v1")
	if err != nil {
		return nil, err
	}
	jwtSigningKey, err := derive(root, "admin_go:jwt-signing:v1")
	if err != nil {
		return nil, err
	}
	sessionCacheKey, err := derive(root, "admin_go:session-cache:v1")
	if err != nil {
		return nil, err
	}
	return &KeyRing{
		secretboxKey:    secretboxKey,
		tokenPepper:     base64.RawURLEncoding.EncodeToString(tokenPepperKey),
		jwtSigningKey:   jwtSigningKey,
		sessionCacheKey: sessionCacheKey,
	}, nil
}

func (k *KeyRing) SecretboxKey() []byte { return clone(k.secretboxKey) }
func (k *KeyRing) TokenPepper() string  { if k == nil { return "" }; return k.tokenPepper }
func (k *KeyRing) JWTSigningKey() []byte { return clone(k.jwtSigningKey) }
func (k *KeyRing) SessionCacheKey() []byte { return clone(k.sessionCacheKey) }

func derive(root string, info string) ([]byte, error) {
	key, err := hkdf.Key(sha256.New, []byte(root), nil, info, keyLength)
	if err != nil {
		return nil, fmt.Errorf("derive %s: %w", info, err)
	}
	return key, nil
}

func clone(in []byte) []byte {
	out := make([]byte, len(in))
	copy(out, in)
	return out
}
```

- [ ] **Step 4: Run tests and commit**

Run:

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/platform/secretkey
git add internal/platform/secretkey
git commit -m "feat: derive purpose keys from app secret"
```

Expected: tests pass and commit succeeds.

---

## Task 3: Convert secretbox to derived-key input

**Files:**
- Modify: `admin_back_go/internal/platform/secretbox/secretbox.go`
- Modify: `admin_back_go/internal/platform/secretbox/secretbox_test.go`
- Modify: tests calling `secretbox.New("...")`

- [ ] **Step 1: Write failing secretbox tests**

Replace secretbox key tests with:

```go
func TestBoxEncryptFailsWithoutKey(t *testing.T) {
	box := New(nil)
	_, err := box.Encrypt("plain")
	if err == nil || !errors.Is(err, ErrMissingKey) {
		t.Fatalf("expected missing key error, got %v", err)
	}
}

func TestBoxEncryptRejectsShortKey(t *testing.T) {
	box := New([]byte("short"))
	_, err := box.Encrypt("plain")
	if err == nil || !errors.Is(err, ErrInvalidKey) {
		t.Fatalf("expected invalid key error, got %v", err)
	}
}

func TestBoxEncryptDecryptRoundTrip(t *testing.T) {
	box := New([]byte("12345678901234567890123456789012"))
	ciphertext, err := box.Encrypt("secret-value")
	if err != nil {
		t.Fatalf("Encrypt returned error: %v", err)
	}
	plain, err := box.Decrypt(ciphertext)
	if err != nil {
		t.Fatalf("Decrypt returned error: %v", err)
	}
	if plain != "secret-value" {
		t.Fatalf("expected secret-value, got %q", plain)
	}
}
```

Remove `TestBoxDecryptLegacyFormat`.

- [ ] **Step 2: Implement secretbox key boundary**

Change `secretbox.Box`:

```go
var (
	ErrMissingKey        = errors.New("secretbox: key is not configured")
	ErrInvalidKey        = errors.New("secretbox: key must be 32 bytes")
	ErrInvalidCiphertext = errors.New("secretbox: invalid ciphertext")
)

type Box struct {
	key []byte
}

func New(key []byte) Box {
	cloned := make([]byte, len(key))
	copy(cloned, key)
	return Box{key: cloned}
}
```

Replace `aead()`:

```go
func (b Box) aead() (cipher.AEAD, error) {
	if len(b.key) == 0 {
		return nil, ErrMissingKey
	}
	if len(b.key) != 32 {
		return nil, ErrInvalidKey
	}
	block, err := aes.NewCipher(b.key)
	if err != nil {
		return nil, fmt.Errorf("secretbox: create aes cipher: %w", err)
	}
	aead, err := cipher.NewGCM(block)
	if err != nil {
		return nil, fmt.Errorf("secretbox: create gcm: %w", err)
	}
	return aead, nil
}
```

Remove the `crypto/sha256` import.

- [ ] **Step 3: Update old test constructors**

Run:

```powershell
cd E:/admin_go/admin_back_go
rg -n 'secretbox\.New\("' internal
```

Replace test calls with:

```go
secretbox.New([]byte("12345678901234567890123456789012"))
```

If production code calls `secretbox.New(cfg.Secretbox.Key)`, do not patch it here; Task 6 wires the keyring.

- [ ] **Step 4: Run tests and commit**

Run:

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/platform/secretbox ./internal/module/aiprovider ./internal/module/uploadconfig ./internal/module/uploadtoken ./internal/module/payment ./internal/module/aiagent ./internal/module/aichat ./internal/module/aitool ./internal/module/exporttask ./internal/module/clientversion
git add internal/platform/secretbox internal/module
git commit -m "feat: use derived key for secretbox"
```

Expected: tests pass and commit succeeds.

---

## Task 4: Add JWT access-token codec

**Files:**
- Modify: `admin_back_go/go.mod`
- Modify: `admin_back_go/go.sum`
- Create: `admin_back_go/internal/platform/accesstoken/jwt.go`
- Create: `admin_back_go/internal/platform/accesstoken/jwt_test.go`

- [ ] **Step 1: Add dependency**

Run:

```powershell
cd E:/admin_go/admin_back_go
go get github.com/golang-jwt/jwt/v5
```

Expected: `go.mod` contains direct require for `github.com/golang-jwt/jwt/v5`.

- [ ] **Step 2: Write failing codec tests**

Create `admin_back_go/internal/platform/accesstoken/jwt_test.go`:

```go
package accesstoken

import (
	"strings"
	"testing"
	"time"
)

func TestJWTCodecIssueParseRoundTrip(t *testing.T) {
	codec := NewJWTCodec([]byte("12345678901234567890123456789012"), Options{Issuer: "admin_go"})
	now := time.Date(2026, 5, 13, 12, 0, 0, 0, time.UTC)
	token, err := codec.Issue(Claims{
		SessionID: 42,
		UserID:    7,
		Platform:  "admin",
		DeviceID:  "device-a",
		IssuedAt:  now,
		ExpiresAt: now.Add(time.Hour),
	})
	if err != nil {
		t.Fatalf("Issue returned error: %v", err)
	}
	if strings.Count(token, ".") != 2 {
		t.Fatalf("expected JWT access token, got %q", token)
	}
	claims, err := codec.Parse(token, now.Add(time.Minute))
	if err != nil {
		t.Fatalf("Parse returned error: %v", err)
	}
	if claims.SessionID != 42 || claims.UserID != 7 || claims.Platform != "admin" || claims.DeviceID != "device-a" {
		t.Fatalf("unexpected claims: %#v", claims)
	}
}

func TestJWTCodecRejectsExpiredToken(t *testing.T) {
	codec := NewJWTCodec([]byte("12345678901234567890123456789012"), Options{Issuer: "admin_go"})
	now := time.Date(2026, 5, 13, 12, 0, 0, 0, time.UTC)
	token, err := codec.Issue(Claims{SessionID: 42, UserID: 7, Platform: "admin", IssuedAt: now.Add(-2 * time.Hour), ExpiresAt: now.Add(-time.Hour)})
	if err != nil {
		t.Fatalf("Issue returned error: %v", err)
	}
	if _, err = codec.Parse(token, now); err == nil {
		t.Fatalf("expected expired token error")
	}
}
```

- [ ] **Step 3: Implement codec**

Create `admin_back_go/internal/platform/accesstoken/jwt.go` with:

```go
package accesstoken

import (
	"errors"
	"fmt"
	"strconv"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

type Claims struct {
	SessionID int64
	UserID    int64
	Platform  string
	DeviceID  string
	IssuedAt  time.Time
	ExpiresAt time.Time
}

type Codec interface {
	Issue(Claims) (string, error)
	Parse(token string, now time.Time) (Claims, error)
}

type Options struct {
	Issuer string
}

type JWTCodec struct {
	signingKey []byte
	issuer     string
}

func NewJWTCodec(signingKey []byte, opts Options) *JWTCodec {
	key := make([]byte, len(signingKey))
	copy(key, signingKey)
	issuer := strings.TrimSpace(opts.Issuer)
	if issuer == "" {
		issuer = "admin_go"
	}
	return &JWTCodec{signingKey: key, issuer: issuer}
}

func (c *JWTCodec) Issue(claims Claims) (string, error) {
	if c == nil || len(c.signingKey) == 0 {
		return "", errors.New("access token signing key is not configured")
	}
	if claims.SessionID <= 0 || claims.UserID <= 0 {
		return "", errors.New("access token claims require session_id and user_id")
	}
	if !claims.ExpiresAt.After(claims.IssuedAt) {
		return "", errors.New("access token expiry must be after issued_at")
	}
	payload := jwt.MapClaims{
		"iss":       c.issuer,
		"sub":       strconv.FormatInt(claims.UserID, 10),
		"iat":       claims.IssuedAt.Unix(),
		"nbf":       claims.IssuedAt.Unix(),
		"exp":       claims.ExpiresAt.Unix(),
		"sid":       claims.SessionID,
		"platform":  claims.Platform,
		"device_id": claims.DeviceID,
	}
	return jwt.NewWithClaims(jwt.SigningMethodHS256, payload).SignedString(c.signingKey)
}

func (c *JWTCodec) Parse(tokenString string, now time.Time) (Claims, error) {
	if c == nil || len(c.signingKey) == 0 {
		return Claims{}, errors.New("access token signing key is not configured")
	}
	claims := jwt.MapClaims{}
	token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (any, error) {
		if token.Method != jwt.SigningMethodHS256 {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return c.signingKey, nil
	}, jwt.WithIssuer(c.issuer), jwt.WithTimeFunc(func() time.Time { return now }))
	if err != nil {
		return Claims{}, err
	}
	if token == nil || !token.Valid {
		return Claims{}, errors.New("invalid access token")
	}
	userID, err := strconv.ParseInt(fmt.Sprint(claims["sub"]), 10, 64)
	if err != nil {
		return Claims{}, errors.New("invalid access token subject")
	}
	sessionID, err := claimInt64(claims["sid"])
	if err != nil {
		return Claims{}, errors.New("invalid access token session id")
	}
	iat, err := claimInt64(claims["iat"])
	if err != nil {
		return Claims{}, errors.New("invalid access token iat")
	}
	exp, err := claimInt64(claims["exp"])
	if err != nil {
		return Claims{}, errors.New("invalid access token exp")
	}
	return Claims{SessionID: sessionID, UserID: userID, Platform: fmt.Sprint(claims["platform"]), DeviceID: fmt.Sprint(claims["device_id"]), IssuedAt: time.Unix(iat, 0), ExpiresAt: time.Unix(exp, 0)}, nil
}

func claimInt64(value any) (int64, error) {
	switch v := value.(type) {
	case float64:
		return int64(v), nil
	case int64:
		return v, nil
	default:
		return 0, fmt.Errorf("invalid number claim %T", value)
	}
}
```

- [ ] **Step 4: Run tests and commit**

Run:

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/platform/accesstoken
git add go.mod go.sum internal/platform/accesstoken
git commit -m "feat: add jwt access token codec"
```

Expected: tests pass and commit succeeds.

---

## Task 5: Refactor session auth to JWT access + opaque refresh

**Files:**
- Modify: `admin_back_go/internal/module/session/token.go`
- Modify: `admin_back_go/internal/module/session/service.go`
- Modify: `admin_back_go/internal/module/session/repository.go`
- Modify: `admin_back_go/internal/module/session/model.go`
- Modify: `admin_back_go/internal/module/session/revoker.go`
- Modify: `admin_back_go/internal/module/usersession/repository.go`
- Modify: `admin_back_go/internal/module/usersession/service.go`
- Modify: `admin_back_go/internal/module/session/service_test.go`

- [ ] **Step 1: Write failing session tests**

Add tests proving:

```go
// Login must return a JWT-looking access token and a non-JWT refresh token.
if strings.Count(result.AccessToken, ".") != 2 {
	t.Fatalf("expected JWT access token, got %q", result.AccessToken)
}
if strings.Count(result.RefreshToken, ".") != 0 {
	t.Fatalf("expected opaque refresh token, got %q", result.RefreshToken)
}
```

Add an authenticate test that seeds a session with `ID=42`, issues a JWT with `sid=42`, and asserts the repository lookup path uses session id instead of access hash.

- [ ] **Step 2: Extend repository contract**

Add to `Repository`:

```go
FindValidByID(ctx context.Context, sessionID int64, now time.Time) (*Session, error)
UpdateAccessToken(ctx context.Context, sessionID int64, accessHash string, expiresAt time.Time) error
```

Implement GORM lookup:

```go
func (r *GormRepository) FindValidByID(ctx context.Context, sessionID int64, now time.Time) (*Session, error) {
	if r == nil || r.db == nil {
		return nil, ErrRepositoryNotConfigured
	}
	var session Session
	err := r.db.WithContext(ctx).
		Where("id = ?", sessionID).
		Where("revoked_at IS NULL").
		Where("is_del = ?", commonNo).
		Where("expires_at > ?", now).
		First(&session).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &session, nil
}
```

Implement access update:

```go
func (r *GormRepository) UpdateAccessToken(ctx context.Context, sessionID int64, accessHash string, expiresAt time.Time) error {
	if r == nil || r.db == nil {
		return ErrRepositoryNotConfigured
	}
	return r.db.WithContext(ctx).
		Model(&Session{}).
		Where("id = ?", sessionID).
		Updates(map[string]any{"access_token_hash": accessHash, "expires_at": expiresAt}).Error
}
```

- [ ] **Step 3: Refactor Authenticator dependencies**

Add fields:

```go
AccessCodec accesstoken.Codec
TokenPepper string
```

Store them on `Authenticator`. Stop reading `cfg.Pepper`.

- [ ] **Step 4: Change login creation**

Creation order must be:

```text
1. generate opaque refresh token
2. hash refresh token with derived token pepper
3. create user_sessions row with temporary access hash
4. issue JWT access token with sid=sessionID
5. hash JWT access token for audit/debug column
6. update access_token_hash and expires_at
7. return JWT access + opaque refresh
```

Use this helper:

```go
func (a *Authenticator) issueAccessToken(sessionID int64, userID int64, platform string, deviceID string, policy *AuthPolicy, now time.Time) (string, string, time.Time, *apperror.Error) {
	if a.accessCodec == nil {
		return "", "", time.Time{}, apperror.Unauthorized("Token认证未配置")
	}
	expiresAt := now.Add(policy.AccessTTL)
	accessToken, err := a.accessCodec.Issue(accesstoken.Claims{
		SessionID: sessionID,
		UserID:    userID,
		Platform:  platform,
		DeviceID:  deviceID,
		IssuedAt:  now,
		ExpiresAt: expiresAt,
	})
	if err != nil {
		return "", "", time.Time{}, apperror.Internal("访问令牌生成失败")
	}
	accessHash, err := HashToken(accessToken, a.tokenPepper)
	if err != nil {
		return "", "", time.Time{}, apperror.Unauthorized("令牌格式错误")
	}
	return accessToken, accessHash, expiresAt, nil
}
```

- [ ] **Step 5: Change authenticate path**

Authentication must:

```text
1. parse JWT
2. cache lookup by token:session:<sid>
3. on miss, query user_sessions by sid
4. verify sid/user_id/platform/device_id match JWT claims
5. enforce platform/device/IP/single-session policy
6. return AuthIdentity
```

Add:

```go
func (a *Authenticator) sessionCacheKey(sessionID int64) string {
	return a.cfg.RedisPrefix + "session:" + strconv.FormatInt(sessionID, 10)
}
```

- [ ] **Step 6: Change refresh/logout/revoke cache behavior**

Refresh still finds by `refresh_token_hash`, but uses `a.tokenPepper` and issues new JWT access. Logout parses JWT and revokes by `claims.SessionID`.

`session.RevocationService` deletes:

```go
s.cfg.RedisPrefix + "session:" + strconv.FormatInt(row.ID, 10)
```

not `RedisPrefix + access_token_hash`.

- [ ] **Step 7: Run tests and commit**

Run:

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/module/session ./internal/module/usersession ./internal/module/auth
git add internal/module/session internal/module/usersession internal/module/auth
git commit -m "feat: use jwt access tokens with opaque refresh sessions"
```

Expected: tests pass and commit succeeds.

---

## Task 6: Wire keyring through bootstrap and commands

**Files:**
- Modify: `admin_back_go/internal/bootstrap/app.go`
- Modify: `admin_back_go/internal/bootstrap/worker.go`
- Modify: `admin_back_go/internal/bootstrap/authenticator.go`
- Modify: `admin_back_go/cmd/admin-api/main.go`
- Modify: `admin_back_go/cmd/admin-worker/main.go`
- Modify: `admin_back_go/internal/bootstrap/*_test.go`

- [ ] **Step 1: Change bootstrap signatures**

Change API bootstrap:

```go
func New(cfg config.Config, logger *slog.Logger) (*App, error) {
	if err := config.ValidateRuntimeSecrets(cfg); err != nil {
		return nil, err
	}
	keys, err := secretkey.NewKeyRing(cfg.App.Secret)
	if err != nil {
		return nil, fmt.Errorf("initialize app secret keys: %w", err)
	}
	// existing setup continues...
}
```

Change command usage:

```go
app, err := bootstrap.New(cfg, logger)
if err != nil {
	logger.Error("failed to initialize admin api", "error", err)
	os.Exit(1)
}
```

- [ ] **Step 2: Wire authenticator**

Change:

```go
func NewSessionAuthenticator(resources *Resources, cfg config.Config, keys *secretkey.KeyRing) *session.Authenticator {
	return session.NewAuthenticator(session.AuthenticatorDeps{
		Config:         cfg.Token,
		Cache:          session.NewRedisCache(resourcesTokenRedis(resources)),
		Repository:     session.NewGormRepository(resourcesDB(resources)),
		PolicyProvider: authplatform.NewService(authplatform.NewGormRepository(resourcesDB(resources))),
		AccessCodec:    accesstoken.NewJWTCodec(keys.JWTSigningKey(), accesstoken.Options{Issuer: "admin_go"}),
		TokenPepper:    keys.TokenPepper(),
	})
}
```

- [ ] **Step 3: Wire secretbox**

Change API and worker construction:

```go
secretBox := secretbox.New(keys.SecretboxKey())
```

No production code should call `secretbox.New(cfg.Secretbox.Key)` after this task.

- [ ] **Step 4: Update worker validation**

At the top of `NewWorker`:

```go
if err := config.ValidateRuntimeSecrets(cfg); err != nil {
	return nil, err
}
keys, err := secretkey.NewKeyRing(cfg.App.Secret)
if err != nil {
	return nil, err
}
```

Update tests that construct workers with:

```go
App: config.AppConfig{Secret: strings.Repeat("a", 64)},
```

- [ ] **Step 5: Run tests and commit**

Run:

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/bootstrap ./cmd/admin-api ./cmd/admin-worker
git add internal/bootstrap cmd/admin-api cmd/admin-worker
git commit -m "feat: wire app secret into auth bootstrap"
```

Expected: tests pass and commit succeeds.

---

## Task 7: Update env files and docs

**Files:**
- Modify: `admin_back_go/.env`
- Modify: `admin_back_go/.env.example`
- Modify: `admin_back_go/docs/architecture.md`
- Modify: `docs/contracts/admin-api-v1.md`
- Modify: `docs/deployment/production.md`
- Modify: `docs/architecture/06-admin-middleware-selection.md`
- Modify: `admin_back_go/README.md` if it mentions token or vault secrets

- [ ] **Step 1: Update real `.env`**

Replace:

```env
TOKEN_PEPPER=...
VAULT_KEY=...
```

with:

```env
# Application root secret: used only as root material; code derives token, JWT, and secretbox keys internally.
APP_SECRET=7a8b9c0d1e2f3g4h5i6j7k8l9m0n1o2p3q4r5s6t7u8v9w0x1y2z3a4b5c6d7e8f
```

Keep:

```env
TOKEN_REDIS_PREFIX=token:
TOKEN_REDIS_DB=2
TOKEN_SESSION_CACHE_TTL=30m
TOKEN_SINGLE_SESSION_POINTER_TTL=720h
```

- [ ] **Step 2: Update `.env.example`**

Use:

```env
# Application root secret. Single admin deployment only.
# Code derives JWT signing, refresh-token pepper, secretbox, and session-cache keys internally.
# Changing this invalidates existing login sessions and encrypted API/upload/payment secrets.
APP_SECRET=

# Token/session infrastructure settings. Business token TTLs are stored in auth_platforms.access_ttl / auth_platforms.refresh_ttl, not env.
TOKEN_REDIS_PREFIX=token:
TOKEN_REDIS_DB=2
TOKEN_SESSION_CACHE_TTL=30m
TOKEN_SINGLE_SESSION_POINTER_TTL=720h
```

- [ ] **Step 3: Update contract docs**

Add:

```text
access_token 是本系统签发的 JWT，只包含 sid/sub/platform/device_id/iat/nbf/exp/iss 这类最小 claims；refresh_token 是 opaque random string，数据库只保存 hash。前端不得解析 JWT 决定权限，权限仍以后端 users/me、RBAC 和菜单接口为准。
```

Replace old env sentence with:

```text
.env 只保存 APP_SECRET、TOKEN_REDIS_PREFIX、TOKEN_REDIS_DB、TOKEN_SESSION_CACHE_TTL、TOKEN_SINGLE_SESSION_POINTER_TTL 这类运行时基础设施配置。access_ttl / refresh_ttl 仍以 auth_platforms 表为业务事实源。
```

- [ ] **Step 4: Update backend architecture docs**

Replace old `TOKEN_PEPPER` / `VAULT_KEY` descriptions with:

```text
APP_SECRET 是唯一根密钥；internal/platform/secretkey 用 HKDF-SHA256 派生 jwt-signing、token-pepper、secretbox、session-cache keys。
access_token 是 JWT；AuthToken middleware 只提取 bearer/cookie token，session.Authenticator 解析 JWT 后按 sid 查询 Redis session cache，再回落 MySQL user_sessions。
refresh_token 仍是 opaque random string；数据库只保存 sha256(refresh_token + "|" + derived token pepper)。
secretbox 只接收 32-byte derived secretbox key；它不读 env，也不知道 APP_SECRET。
```

- [ ] **Step 5: Add reset runbook**

Create `docs/deployment/auth-foundation-v2-reset-runbook.md`:

```markdown
# Auth Foundation v2 Reset Runbook

日期：2026-05-13

## Impact

Changing `APP_SECRET` invalidates access tokens, refresh tokens, Redis token/session caches, encrypted AI provider API keys, encrypted upload driver secrets, and encrypted payment private keys.

## SQL

```sql
UPDATE user_sessions
SET revoked_at = NOW()
WHERE revoked_at IS NULL;
```

## Redis

```powershell
redis-cli -n 2 --scan --pattern "token:*" | ForEach-Object { redis-cli -n 2 DEL $_ }
```

## Manual re-entry

Re-enter AI provider API keys, upload driver secrets, and payment private keys through the admin UI. Do not copy old encrypted database blobs.
```

- [ ] **Step 6: Run docs residue scan and commit**

Run:

```powershell
cd E:/admin_go
rg -n "TOKEN_PEPPER|VAULT_KEY|legacy PHP KeyVault|sha256\(VAULT_KEY\)|sha256\(access_token" docs admin_back_go/docs admin_back_go/.env.example admin_back_go/README.md
```

Expected: no active runtime instructions remain. Historical plan/spec hits are acceptable.

Commit root and backend repos separately if needed:

```powershell
cd E:/admin_go/admin_back_go
git add .env .env.example docs README.md
git commit -m "docs: document app secret runtime config"

cd E:/admin_go
git add docs
git commit -m "docs: document auth foundation v2 reset"
```

---

## Task 8: Full verification

**Files:**
- Verify all changed files

- [ ] **Step 1: Tidy module**

Run:

```powershell
cd E:/admin_go/admin_back_go
go mod tidy
git diff -- go.mod go.sum
```

Expected: `github.com/golang-jwt/jwt/v5` appears as direct dependency. No unrelated dependency churn.

- [ ] **Step 2: Run backend verification**

Run:

```powershell
cd E:/admin_go/admin_back_go
go test ./...
go vet ./...
powershell -ExecutionPolicy Bypass -File .\scripts\check-contract.ps1
git diff --check
```

Expected: all pass.

- [ ] **Step 3: Run active residue scan**

Run:

```powershell
cd E:/admin_go
rg -n "TOKEN_PEPPER|VAULT_KEY|FindValidByAccessHash|access token hash cache|secretbox\.New\(cfg\.Secretbox" admin_back_go/internal admin_back_go/.env admin_back_go/.env.example admin_back_go/docs docs/contracts docs/deployment docs/architecture
```

Expected: no active runtime code still depends on old config. Historical specs/plans can keep old references.

- [ ] **Step 4: Run smoke after starting services**

Start API and worker with updated `.env`, then run:

```powershell
cd E:/admin_go
powershell -ExecutionPolicy Bypass -File .\scripts\basic-admin-smoke.ps1 -Account 15671628271 -Password 123456
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account 15671628271 -Password 123456
```

Expected: login succeeds, refresh succeeds, logout/revoke/session-list smoke gates pass, and no token hash fields leak.

- [ ] **Step 5: Check git status across repos**

Run:

```powershell
cd E:/admin_go
git status --short
git -C admin_back_go status --short
git -C admin_front_ts status --short
```

Expected: clean or only intentionally uncommitted local `.env` changes. If `.env` is tracked, commit it; if it is ignored, mention the local runtime change in final delivery.

---

## Final Acceptance Criteria

- `admin_back_go/.env` has `APP_SECRET` and no `TOKEN_PEPPER` / `VAULT_KEY` runtime settings.
- API and worker fail startup when `APP_SECRET` is missing, default, or shorter than 32 chars.
- `secretbox` receives a 32-byte derived key and no longer reads or names `VAULT_KEY`.
- Access token returned by login is JWT format with exactly two dots.
- Refresh token remains opaque and is not JWT format.
- `user_sessions` remains the session truth source.
- Redis cache key for auth session is `token:session:<session_id>`.
- Logout, kick, batch revoke, single-session policy, and max-session policy invalidate JWT access tokens through `user_sessions` state.
- Frontend API response shape is unchanged.
- `go test ./...`, `go vet ./...`, contract check, basic smoke, and full smoke pass.
