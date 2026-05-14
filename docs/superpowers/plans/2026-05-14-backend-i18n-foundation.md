# Backend I18n Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 接入官方 `gin-contrib/i18n`，让后端外层错误响应按前端语言返回 `msg`，并建立后续模块逐个收口的 catalog 基线。

**Architecture:** 前端继续用 `lang` Cookie 作为语言真相源，并把它发送为 `Accept-Language`；Go 后端在 CORS 后、AuthToken 前挂 i18n middleware；`apperror.Error` 保存内部 `MessageID` 和 fallback `Message`，`response` 是唯一把 error key 翻译成 `msg` 的出口。Catalog 按语言 + 模块拆 yaml 文件，通过项目自定义 loader 喂给官方 gin-contrib/i18n bundle。

**Tech Stack:** Go 1.26, Gin, github.com/gin-contrib/i18n v1.3.0, go-i18n v2, yaml catalog, Vue 3, Axios, js-cookie, Vitest.

---

## Source Spec

```text
E:/admin_go/docs/superpowers/specs/2026-05-14-backend-i18n-foundation-design.md
```

硬规则：

```text
响应结构仍然是 { code, data, msg }。
不新增 response.message_id。
zh-CN 是默认语言。
en-US 请求只要求外层错误返回英文。
未迁移模块继续使用 fallback 中文，不 panic。
第一刀只收 AuthToken / PermissionCheck / response nil error / common request invalid。
```

---

## Files

Create:

```text
admin_back_go/internal/i18n/i18n.go
admin_back_go/internal/i18n/i18n_test.go
admin_back_go/internal/i18n/locales/zh-CN/common.yaml
admin_back_go/internal/i18n/locales/zh-CN/auth.yaml
admin_back_go/internal/i18n/locales/zh-CN/permission.yaml
admin_back_go/internal/i18n/locales/en-US/common.yaml
admin_back_go/internal/i18n/locales/en-US/auth.yaml
admin_back_go/internal/i18n/locales/en-US/permission.yaml
admin_front_ts/tests/shared/http-language-header.test.ts
```

Modify:

```text
admin_back_go/go.mod
admin_back_go/go.sum
admin_back_go/internal/apperror/error.go
admin_back_go/internal/apperror/error_test.go
admin_back_go/internal/response/response.go
admin_back_go/internal/response/response_test.go
admin_back_go/internal/middleware/auth_token.go
admin_back_go/internal/middleware/auth_token_test.go
admin_back_go/internal/middleware/permission_check.go
admin_back_go/internal/middleware/permission_check_test.go
admin_back_go/internal/bootstrap/permission_checker.go
admin_back_go/internal/config/config.go
admin_back_go/internal/config/config_test.go
admin_back_go/internal/server/router.go
admin_back_go/internal/server/router_test.go
admin_back_go/.env.example
admin_front_ts/src/lib/http/platform.ts
admin_front_ts/src/lib/http/headers.ts
docs/contracts/admin-api-v1.md
admin_back_go/docs/architecture.md
docs/migration/current-status.md
```

Do not modify:

```text
admin_back_go/internal/module/payment
admin_back_go/internal/module/aichat
admin_back_go/internal/module/mail
admin_back_go/internal/dict
admin_front_ts/src/i18n/locales/*.ts
```

理由：第一刀只做 foundation，不把业务模块和前端静态文案搅进去。

---

## Task 1: Add official i18n dependency and project catalog loader

**Files:**

- Create: `E:/admin_go/admin_back_go/internal/i18n/i18n.go`
- Create: `E:/admin_go/admin_back_go/internal/i18n/i18n_test.go`
- Create: `E:/admin_go/admin_back_go/internal/i18n/locales/zh-CN/common.yaml`
- Create: `E:/admin_go/admin_back_go/internal/i18n/locales/zh-CN/auth.yaml`
- Create: `E:/admin_go/admin_back_go/internal/i18n/locales/zh-CN/permission.yaml`
- Create: `E:/admin_go/admin_back_go/internal/i18n/locales/en-US/common.yaml`
- Create: `E:/admin_go/admin_back_go/internal/i18n/locales/en-US/auth.yaml`
- Create: `E:/admin_go/admin_back_go/internal/i18n/locales/en-US/permission.yaml`
- Modify: `E:/admin_go/admin_back_go/go.mod`
- Modify: `E:/admin_go/admin_back_go/go.sum`

- [ ] **Step 1: Add dependency**

Run:

```powershell
cd E:/admin_go/admin_back_go
go get github.com/gin-contrib/i18n@v1.3.0
```

Expected:

```text
go.mod includes github.com/gin-contrib/i18n v1.3.0.
go.sum is updated.
```

- [ ] **Step 2: Add catalog files**

Create `internal/i18n/locales/zh-CN/common.yaml`:

```yaml
common.ok: ok
common.internal_error: 系统错误
common.request.invalid: 参数错误
```

Create `internal/i18n/locales/zh-CN/auth.yaml`:

```yaml
auth.token.missing: 缺少Token
auth.token.invalid_format: Token格式错误
auth.token.invalid_or_expired: Token无效或已过期
auth.token.authenticator_missing: Token认证未配置
```

Create `internal/i18n/locales/zh-CN/permission.yaml`:

```yaml
permission.checker_missing: 权限检查未配置
permission.api.denied: 无接口权限
permission.code_missing: 权限标识未配置
```

Create `internal/i18n/locales/en-US/common.yaml`:

```yaml
common.ok: ok
common.internal_error: System error
common.request.invalid: Invalid request
```

Create `internal/i18n/locales/en-US/auth.yaml`:

```yaml
auth.token.missing: Missing token
auth.token.invalid_format: Invalid token format
auth.token.invalid_or_expired: Token is invalid or expired
auth.token.authenticator_missing: Token authenticator is not configured
```

Create `internal/i18n/locales/en-US/permission.yaml`:

```yaml
permission.checker_missing: Permission checker is not configured
permission.api.denied: API permission denied
permission.code_missing: Permission code is not configured
```

- [ ] **Step 3: Write failing catalog tests**

Create `internal/i18n/i18n_test.go`:

```go
package i18n

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
)

func TestLocalizeUsesAcceptLanguage(t *testing.T) {
	gin.SetMode(gin.TestMode)
	router := gin.New()
	router.Use(Localize())
	router.GET("/probe", func(c *gin.Context) {
		message, err := Message(c, "auth.token.missing", nil, "fallback")
		if err != nil {
			t.Fatalf("localize message: %v", err)
		}
		c.String(http.StatusOK, message)
	})

	req := httptest.NewRequest(http.MethodGet, "/probe", nil)
	req.Header.Set("Accept-Language", "en-US")
	recorder := httptest.NewRecorder()
	router.ServeHTTP(recorder, req)

	if recorder.Body.String() != "Missing token" {
		t.Fatalf("expected English message, got %q", recorder.Body.String())
	}
}

func TestLocalizeFallsBackToZhCN(t *testing.T) {
	gin.SetMode(gin.TestMode)
	router := gin.New()
	router.Use(Localize())
	router.GET("/probe", func(c *gin.Context) {
		message, err := Message(c, "auth.token.missing", nil, "fallback")
		if err != nil {
			t.Fatalf("localize message: %v", err)
		}
		c.String(http.StatusOK, message)
	})

	req := httptest.NewRequest(http.MethodGet, "/probe", nil)
	req.Header.Set("Accept-Language", "fr-FR")
	recorder := httptest.NewRecorder()
	router.ServeHTTP(recorder, req)

	if recorder.Body.String() != "缺少Token" {
		t.Fatalf("expected zh-CN fallback, got %q", recorder.Body.String())
	}
}

func TestCatalogKeysMatch(t *testing.T) {
	zhKeys, err := CatalogKeys("zh-CN")
	if err != nil {
		t.Fatalf("load zh-CN keys: %v", err)
	}
	enKeys, err := CatalogKeys("en-US")
	if err != nil {
		t.Fatalf("load en-US keys: %v", err)
	}
	if len(zhKeys) != len(enKeys) {
		t.Fatalf("catalog key count mismatch zh=%d en=%d", len(zhKeys), len(enKeys))
	}
	for key := range zhKeys {
		if _, ok := enKeys[key]; !ok {
			t.Fatalf("missing en-US key %q", key)
		}
	}
}
```

- [ ] **Step 4: Run failing tests**

Run:

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/i18n
```

Expected before implementation:

```text
FAIL because package admin_back_go/internal/i18n has no implementation.
```

- [ ] **Step 5: Implement project i18n package**

Create `internal/i18n/i18n.go`:

```go
// Package i18n wires project catalogs into gin-contrib/i18n.
package i18n

import (
	"bytes"
	"embed"
	"fmt"
	"io/fs"
	"path/filepath"
	"sort"
	"strings"

	gini18n "github.com/gin-contrib/i18n"
	"github.com/gin-gonic/gin"
	goi18n "github.com/nicksnyder/go-i18n/v2/i18n"
	"golang.org/x/text/language"
	"gopkg.in/yaml.v3"
)

//go:embed locales/*/*.yaml
var localeFS embed.FS

var supportedLanguages = []language.Tag{language.SimplifiedChinese, language.AmericanEnglish}
var languageMatcher = language.NewMatcher(supportedLanguages)

// Localize returns the Gin middleware used by admin_back_go.
func Localize() gin.HandlerFunc {
	return gini18n.Localize(gini18n.WithBundle(&gini18n.BundleCfg{
		RootPath:          "locales",
		AcceptLanguage:    supportedLanguages,
		FallbackLanguages: []language.Tag{language.SimplifiedChinese},
		DefaultLanguage:   language.SimplifiedChinese,
		FormatBundleFile:  "yaml",
		UnmarshalFunc:     yaml.Unmarshal,
		Loader:            gini18n.LoaderFunc(loadLanguageCatalog),
	}), gini18n.WithGetLngHandle(func(c *gin.Context, defaultLng string) string {
		if c == nil || c.Request == nil {
			return defaultLng
		}
		return MatchLanguage(c.GetHeader("Accept-Language")).String()
	}))
}

// MatchLanguage maps browser Accept-Language values to supported project tags.
func MatchLanguage(header string) language.Tag {
	tags, _, err := language.ParseAcceptLanguage(strings.TrimSpace(header))
	if err != nil || len(tags) == 0 {
		return language.SimplifiedChinese
	}
	matched, _, _ := languageMatcher.Match(tags...)
	base, _ := matched.Base()
	if base.String() == "en" {
		return language.AmericanEnglish
	}
	return language.SimplifiedChinese
}

// Message localizes a message key and falls back to fallback when the key is missing.
func Message(c *gin.Context, messageID string, templateData map[string]any, fallback string) (string, error) {
	messageID = strings.TrimSpace(messageID)
	if messageID == "" {
		return fallback, nil
	}
	localized, err := gini18n.GetMessage(c, &goi18n.LocalizeConfig{
		MessageID:    messageID,
		TemplateData: templateData,
	})
	if err != nil || strings.TrimSpace(localized) == "" {
		return fallback, err
	}
	return localized, nil
}

// CatalogKeys returns the flattened key set for a language directory.
func CatalogKeys(lang string) (map[string]struct{}, error) {
	files, err := catalogFiles(lang)
	if err != nil {
		return nil, err
	}
	keys := make(map[string]struct{})
	for _, file := range files {
		buf, err := localeFS.ReadFile(file)
		if err != nil {
			return nil, fmt.Errorf("read catalog %s: %w", file, err)
		}
		var values map[string]string
		if err := yaml.Unmarshal(buf, &values); err != nil {
			return nil, fmt.Errorf("parse catalog %s: %w", file, err)
		}
		for key, value := range values {
			key = strings.TrimSpace(key)
			if key == "" || strings.TrimSpace(value) == "" {
				return nil, fmt.Errorf("catalog %s contains empty key or value", file)
			}
			if _, exists := keys[key]; exists {
				return nil, fmt.Errorf("duplicate i18n key %s", key)
			}
			keys[key] = struct{}{}
		}
	}
	return keys, nil
}

func loadLanguageCatalog(path string) ([]byte, error) {
	lang := strings.TrimSuffix(filepath.Base(path), filepath.Ext(path))
	files, err := catalogFiles(lang)
	if err != nil {
		return nil, err
	}
	var merged bytes.Buffer
	for _, file := range files {
		buf, err := localeFS.ReadFile(file)
		if err != nil {
			return nil, fmt.Errorf("read catalog %s: %w", file, err)
		}
		merged.Write(buf)
		merged.WriteByte('\n')
	}
	return merged.Bytes(), nil
}

func catalogFiles(lang string) ([]string, error) {
	lang = strings.TrimSpace(lang)
	if lang == "" {
		return nil, fmt.Errorf("language is required")
	}
	pattern := "locales/" + lang + "/*.yaml"
	files, err := fs.Glob(localeFS, pattern)
	if err != nil {
		return nil, fmt.Errorf("glob catalog %s: %w", pattern, err)
	}
	if len(files) == 0 {
		return nil, fmt.Errorf("no catalog files for %s", lang)
	}
	sort.Strings(files)
	return files, nil
}
```

- [ ] **Step 6: Run catalog tests**

Run:

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/i18n
```

Expected:

```text
ok  admin_back_go/internal/i18n
```

---

## Task 2: Add keyed app errors while preserving fallback messages

**Files:**

- Modify: `E:/admin_go/admin_back_go/internal/apperror/error.go`
- Modify: `E:/admin_go/admin_back_go/internal/apperror/error_test.go`

- [ ] **Step 1: Add failing apperror tests**

Append to `internal/apperror/error_test.go`:

```go
func TestKeyedErrorPreservesFallbackMessage(t *testing.T) {
	err := UnauthorizedKey("auth.token.missing", nil, "缺少Token")
	if err.Code != CodeUnauthorized || err.HTTPStatus != http.StatusUnauthorized {
		t.Fatalf("unexpected error codes: %#v", err)
	}
	if err.MessageID != "auth.token.missing" {
		t.Fatalf("expected message id, got %q", err.MessageID)
	}
	if err.Message != "缺少Token" || err.Error() != "缺少Token" {
		t.Fatalf("fallback message broken: %#v", err)
	}
}

func TestKeyedErrorTemplateDataIsStored(t *testing.T) {
	data := map[string]any{"field": "email"}
	err := BadRequestKey("common.request.invalid", data, "参数错误")
	if err.TemplateData["field"] != "email" {
		t.Fatalf("expected template data to be stored, got %#v", err.TemplateData)
	}
}
```

Ensure `error_test.go` imports `net/http` if it does not already.

- [ ] **Step 2: Run failing tests**

Run:

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/apperror
```

Expected before implementation:

```text
FAIL with undefined UnauthorizedKey or BadRequestKey.
```

- [ ] **Step 3: Implement keyed constructors**

Update `internal/apperror/error.go`:

```go
type Error struct {
	Code         int
	HTTPStatus   int
	Message      string
	MessageID    string
	TemplateData map[string]any
	Cause        error
}

func NewKey(code int, httpStatus int, messageID string, templateData map[string]any, fallback string) *Error {
	return &Error{Code: code, HTTPStatus: httpStatus, Message: fallback, MessageID: messageID, TemplateData: templateData}
}

func WrapKey(code int, httpStatus int, messageID string, templateData map[string]any, fallback string, cause error) *Error {
	return &Error{Code: code, HTTPStatus: httpStatus, Message: fallback, MessageID: messageID, TemplateData: templateData, Cause: cause}
}

func BadRequestKey(messageID string, templateData map[string]any, fallback string) *Error {
	return NewKey(CodeBadRequest, http.StatusBadRequest, messageID, templateData, fallback)
}

func UnauthorizedKey(messageID string, templateData map[string]any, fallback string) *Error {
	return NewKey(CodeUnauthorized, http.StatusUnauthorized, messageID, templateData, fallback)
}

func ForbiddenKey(messageID string, templateData map[string]any, fallback string) *Error {
	return NewKey(CodeForbidden, http.StatusForbidden, messageID, templateData, fallback)
}

func NotFoundKey(messageID string, templateData map[string]any, fallback string) *Error {
	return NewKey(CodeNotFound, http.StatusNotFound, messageID, templateData, fallback)
}

func InternalKey(messageID string, templateData map[string]any, fallback string) *Error {
	return NewKey(CodeInternal, http.StatusInternalServerError, messageID, templateData, fallback)
}
```

Keep existing `New`, `Wrap`, `BadRequest`, `Unauthorized`, `Forbidden`, `NotFound`, and `Internal` unchanged so old modules still compile.

- [ ] **Step 4: Run apperror tests**

Run:

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/apperror
```

Expected:

```text
ok  admin_back_go/internal/apperror
```

---

## Task 3: Localize response errors at the response boundary

**Files:**

- Modify: `E:/admin_go/admin_back_go/internal/response/response.go`
- Modify: `E:/admin_go/admin_back_go/internal/response/response_test.go`

- [ ] **Step 1: Add failing response test**

Append to `internal/response/response_test.go`:

```go
func TestErrorLocalizesKeyedMessage(t *testing.T) {
	gin.SetMode(gin.TestMode)
	router := gin.New()
	router.Use(projecti18n.Localize())
	router.GET("/probe", func(c *gin.Context) {
		Error(c, apperror.UnauthorizedKey("auth.token.missing", nil, "缺少Token"))
	})

	req := httptest.NewRequest(http.MethodGet, "/probe", nil)
	req.Header.Set("Accept-Language", "en-US")
	recorder := httptest.NewRecorder()
	router.ServeHTTP(recorder, req)

	var body map[string]any
	if err := json.Unmarshal(recorder.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if body["msg"] != "Missing token" {
		t.Fatalf("expected localized msg, got %#v", body["msg"])
	}
}
```

Add import alias:

```go
projecti18n "admin_back_go/internal/i18n"
```

- [ ] **Step 2: Run failing test**

Run:

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/response
```

Expected before implementation:

```text
FAIL because response still returns fallback 缺少Token.
```

- [ ] **Step 3: Implement localization in response**

Update `internal/response/response.go`:

```go
import (
	"admin_back_go/internal/apperror"
	projecti18n "admin_back_go/internal/i18n"

	"github.com/gin-gonic/gin"
)

func ErrorWithData(c *gin.Context, err *apperror.Error, data any) {
	if err == nil {
		err = apperror.InternalKey("common.internal_error", nil, "系统错误")
	}
	if data == nil {
		data = gin.H{}
	}

	message := err.Message
	if localized, localizeErr := projecti18n.Message(c, err.MessageID, err.TemplateData, err.Message); localizeErr == nil && localized != "" {
		message = localized
	}

	c.JSON(err.HTTPStatus, Body{
		Code: err.Code,
		Data: data,
		Msg:  message,
	})
}
```

Leave `OK` and `OKWithMessage` unchanged in this task.

- [ ] **Step 4: Run response tests**

Run:

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/response
```

Expected:

```text
ok  admin_back_go/internal/response
```

---

## Task 4: Wire i18n middleware before AuthToken and migrate outer errors

**Files:**

- Modify: `E:/admin_go/admin_back_go/internal/server/router.go`
- Modify: `E:/admin_go/admin_back_go/internal/server/router_test.go`
- Modify: `E:/admin_go/admin_back_go/internal/middleware/auth_token.go`
- Modify: `E:/admin_go/admin_back_go/internal/middleware/permission_check.go`
- Modify: `E:/admin_go/admin_back_go/internal/bootstrap/permission_checker.go`

- [ ] **Step 1: Add router-level failing test for missing token**

Append to `internal/server/router_test.go`:

```go
func TestRouterLocalizesAuthTokenErrors(t *testing.T) {
	router := NewRouter(Dependencies{})

	request := httptest.NewRequest(http.MethodGet, "/api/admin/v1/users/me", nil)
	request.Header.Set("Accept-Language", "en-US")
	recorder := httptest.NewRecorder()
	router.ServeHTTP(recorder, request)

	var body map[string]any
	if err := json.Unmarshal(recorder.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	if body["msg"] != "Missing token" {
		t.Fatalf("expected localized missing token, got %#v body=%s", body["msg"], recorder.Body.String())
	}
}
```

- [ ] **Step 2: Run failing server test**

Run:

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/server -run TestRouterLocalizesAuthTokenErrors -count=1
```

Expected before implementation:

```text
FAIL because i18n middleware is not mounted before AuthToken.
```

- [ ] **Step 3: Mount middleware in router**

Modify `internal/server/router.go` imports:

```go
projecti18n "admin_back_go/internal/i18n"
```

Insert after CORS and before AuthToken:

```go
router.Use(middleware.CORS(deps.CORS))
router.Use(projecti18n.Localize())
router.Use(middleware.AuthToken(middleware.AuthTokenConfig{
```

- [ ] **Step 4: Convert AuthToken outer errors to keyed errors**

In `internal/middleware/auth_token.go`, replace only public outer errors:

```go
apperror.Unauthorized("Token认证未配置")
apperror.Unauthorized("Token无效或已过期")
apperror.Unauthorized("缺少Token")
apperror.Unauthorized("Token格式错误")
```

with:

```go
apperror.UnauthorizedKey("auth.token.authenticator_missing", nil, "Token认证未配置")
apperror.UnauthorizedKey("auth.token.invalid_or_expired", nil, "Token无效或已过期")
apperror.UnauthorizedKey("auth.token.missing", nil, "缺少Token")
apperror.UnauthorizedKey("auth.token.invalid_format", nil, "Token格式错误")
```

- [ ] **Step 5: Convert PermissionCheck outer errors**

In `internal/middleware/permission_check.go`, replace:

```go
apperror.Unauthorized("Token无效或已过期")
apperror.Forbidden("权限检查未配置")
```

with:

```go
apperror.UnauthorizedKey("auth.token.invalid_or_expired", nil, "Token无效或已过期")
apperror.ForbiddenKey("permission.checker_missing", nil, "权限检查未配置")
```

In `internal/bootstrap/permission_checker.go`, replace:

```go
apperror.Unauthorized("Token无效或已过期")
apperror.Forbidden("权限标识未配置")
apperror.Forbidden("无接口权限")
```

with:

```go
apperror.UnauthorizedKey("auth.token.invalid_or_expired", nil, "Token无效或已过期")
apperror.ForbiddenKey("permission.code_missing", nil, "权限标识未配置")
apperror.ForbiddenKey("permission.api.denied", nil, "无接口权限")
```

Do not convert repository/internal failures in this task.

- [ ] **Step 6: Keep existing middleware tests passing**

Run:

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/middleware ./internal/server -run "AuthToken|PermissionCheck|RouterLocalizesAuthTokenErrors" -count=1
```

Expected:

```text
ok  admin_back_go/internal/middleware
ok  admin_back_go/internal/server
```

If old middleware unit tests assert Chinese fallback without project i18n middleware, keep those assertions unchanged. Keyed errors must still expose fallback Chinese when response localization is absent.

---

## Task 5: Allow and send Accept-Language from frontend

**Files:**

- Modify: `E:/admin_go/admin_back_go/internal/config/config.go`
- Modify: `E:/admin_go/admin_back_go/internal/config/config_test.go`
- Modify: `E:/admin_go/admin_back_go/.env.example`
- Modify: `E:/admin_go/admin_front_ts/src/lib/http/platform.ts`
- Create: `E:/admin_go/admin_front_ts/tests/shared/http-language-header.test.ts`

- [ ] **Step 1: Add backend CORS test**

Append to `internal/config/config_test.go`:

```go
func TestDefaultCORSAllowsAcceptLanguage(t *testing.T) {
	cfg := DefaultCORSConfig()
	found := false
	for _, header := range cfg.AllowHeaders {
		if header == "Accept-Language" {
			found = true
		}
	}
	if !found {
		t.Fatalf("DefaultCORSConfig must allow Accept-Language, got %#v", cfg.AllowHeaders)
	}
}
```

- [ ] **Step 2: Implement backend CORS header**

In `internal/config/config.go`, add to `DefaultCORSConfig().AllowHeaders`:

```go
"Accept-Language",
```

In `.env.example`, update:

```text
CORS_ALLOW_HEADERS=Origin,Content-Type,Accept,Accept-Language,Authorization,platform,device-id,X-Trace-Id,X-Request-Id
```

- [ ] **Step 3: Add frontend failing test**

Create `tests/shared/http-language-header.test.ts`:

```ts
import { describe, expect, it, vi } from 'vitest'

vi.mock('js-cookie', () => ({
  default: {
    get: vi.fn((key: string) => key === 'lang' ? 'en-US' : undefined),
  },
}))

describe('HTTP common language header', () => {
  it('sends Accept-Language from lang cookie', async () => {
    const { buildCommonHeaders } = await import('../../src/lib/http/platform')
    const headers = buildCommonHeaders('token')
    expect(headers['Accept-Language']).toBe('en-US')
  })
})
```

- [ ] **Step 4: Run failing frontend test**

Run:

```powershell
cd E:/admin_go/admin_front_ts
npm run test -- tests/shared/http-language-header.test.ts
```

Expected before implementation:

```text
FAIL because Accept-Language is undefined.
```

- [ ] **Step 5: Implement frontend language header**

Modify `src/lib/http/platform.ts`:

```ts
import Cookies from 'js-cookie'
import { getDeviceId } from './device'

export function getRequestLanguage(): 'zh-CN' | 'en-US' {
  const lang = Cookies.get('lang')
  return lang === 'en-US' ? 'en-US' : 'zh-CN'
}

export function buildCommonHeaders(token?: string): Record<string, string> {
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    'Accept-Language': getRequestLanguage(),
    platform: getPlatform(),
    'device-id': getDeviceId(),
    'X-Trace-Id': generateTraceId(),
  }

  if (token) {
    headers.Authorization = `Bearer ${token}`
  }

  return headers
}
```

Keep the existing `generateTraceId` and `getPlatform` functions unchanged.

- [ ] **Step 6: Run frontend and config tests**

Run:

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/config

cd E:/admin_go/admin_front_ts
npm run test -- tests/shared/http-language-header.test.ts
```

Expected:

```text
ok  admin_back_go/internal/config
PASS tests/shared/http-language-header.test.ts
```

---

## Task 6: Update contract and runtime docs

**Files:**

- Modify: `E:/admin_go/docs/contracts/admin-api-v1.md`
- Modify: `E:/admin_go/admin_back_go/docs/architecture.md`
- Modify: `E:/admin_go/docs/migration/current-status.md`

- [ ] **Step 1: Update API contract**

In `docs/contracts/admin-api-v1.md`, after the unified response block near the top, add:

```markdown
语言规则：

```text
前端请求通过 Accept-Language 传当前 UI 语言，当前只支持 zh-CN / en-US。
后端 response shape 不变，仍然只返回 code/data/msg。
msg 是面向用户展示的本地化文本；业务判断只能依赖 code 和 HTTP status，不能依赖 msg 字符串。
缺失或不支持的语言默认 zh-CN。
```
```

- [ ] **Step 2: Update backend architecture**

In `admin_back_go/docs/architecture.md`, add a section after `CORS baseline` or before `AuthToken baseline`:

```markdown
## I18n baseline

后端 i18n 使用官方 Gin 生态组件：

```text
github.com/gin-contrib/i18n
```

规则：

```text
middleware 顺序是 CORS -> I18n -> AuthToken，保证缺 Token / 无权限这类外层错误也能翻译。
语言来源只读 Accept-Language；支持 zh-CN / en-US；默认 zh-CN。
response shape 不变：{ code, data, msg }。
msg 是展示文案，业务判断不能依赖 msg。
apperror.Error 保留 fallback Message；MessageID 只做内部翻译 key，不返回给前端。
Catalog 按 internal/i18n/locales/{lang}/{module}.yaml 分模块维护。
未迁移模块继续返回 fallback 中文，不允许因为缺翻译 key panic。
```
```

- [ ] **Step 3: Update current status**

In `docs/migration/current-status.md`, add or update a row near foundation modules:

```markdown
| backend i18n foundation | implemented: Gin i18n middleware, zh-CN/en-US catalog loader, keyed app error fallback, localized AuthToken/PermissionCheck outer errors | adapted: common HTTP headers send Accept-Language from `lang` Cookie | `internal/i18n`, `internal/apperror`, `internal/response`, `internal/middleware`, `internal/server`; frontend HTTP header Vitest | outer errors covered by focused tests; full smoke still validates response shape | contract + backend architecture + i18n foundation spec/plan | business modules are still migrated one-by-one; DB labels and historical logs are not translated in this slice |
```

- [ ] **Step 4: Check docs diff**

Run:

```powershell
cd E:/admin_go
git diff -- docs/contracts/admin-api-v1.md admin_back_go/docs/architecture.md docs/migration/current-status.md
```

Expected:

```text
Only i18n-related docs changed.
No unrelated mail/payment/AI text moved.
```

---

## Task 7: Full verification

**Files:**

- Verify only; no source changes unless a verification failure points to this i18n slice.

- [ ] **Step 1: Backend focused tests**

Run:

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/i18n ./internal/apperror ./internal/response ./internal/middleware ./internal/config ./internal/server
```

Expected:

```text
All listed packages pass.
```

- [ ] **Step 2: Backend full tests**

Run:

```powershell
cd E:/admin_go/admin_back_go
go test ./...
```

Expected:

```text
All packages pass.
```

- [ ] **Step 3: Frontend focused test and typecheck**

Run:

```powershell
cd E:/admin_go/admin_front_ts
npm run test -- tests/shared/http-language-header.test.ts
npm run typecheck
```

Expected:

```text
Language header test passes.
Typecheck exits 0.
```

- [ ] **Step 4: Diff hygiene**

Run:

```powershell
cd E:/admin_go
git diff --check
git -C admin_back_go diff --check
git -C admin_front_ts diff --check
```

Expected:

```text
No whitespace errors.
```

- [ ] **Step 5: Review dirty workspace boundary before commit**

Run:

```powershell
cd E:/admin_go
git status --short
git -C admin_back_go status --short
git -C admin_front_ts status --short
```

Expected:

```text
Only i18n foundation files from this plan are selected for the i18n commit.
Existing mail / verify-code TTL / deployment edits remain separate unless the owner explicitly merges them.
```

---

## Self-review

```text
Spec coverage: language source, official middleware, catalog loader, keyed errors, response localization, frontend header, docs and verification are all mapped to tasks.
Scope check: plan does not migrate payment, AI, mail, dict labels, DB content, or historical logs.
Type consistency: MessageID and TemplateData names are consistent across apperror and response tasks.
All created files, code snippets, and commands are concrete.
```
