# Verify Code TTL DB Policy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**执行状态：implemented and verified on 2026-05-14**

**Goal:** 把验证码 TTL 从 env 迁到 `system_settings`，删除验证码邮件模板里的 `app_name`，并让 auth/mail/Vue/docs 统一只认 `code` + `ttl_minutes`。

**Architecture:** `auth` 通过一个小接口读取验证码公共策略；`mail` 只负责 Tencent SES 配置、模板、日志和发送，不拥有 TTL 策略；`/system/mail` 暂时承载“验证码公共配置”的 UI，但值写入 `system_settings.auth.verify_code.ttl_minutes`，不是 `mail_configs`。

**Tech Stack:** Go 1.26, Gin, GORM/MySQL, Redis verify-code cache, existing `system_settings`, Tencent SES mail module, Vue 3 `<script setup lang="ts">`, Element Plus, Vitest.

---

## Source Spec

```text
E:/admin_go/docs/superpowers/specs/2026-05-14-verify-code-template-ttl-db-design.md
```

硬规则：

```text
app_name 不再是验证码模板变量。
验证码模板变量必须且只能是 code / ttl_minutes。
ttl_minutes 是验证码公共业务配置，存在 system_settings.auth.verify_code.ttl_minutes。
/system/mail 可以展示/保存 TTL，但后端不能把 TTL 写进 mail_configs。
手机号验证码继续固定 123456，不做短信发送。
邮箱验证码继续走 Tencent SES。
本轮不做短信配置页、不做品牌名配置、不做每模板独立 TTL。
```

当前坏味道证据：

```text
admin_back_go/internal/module/mail/service.go:23      defaultAppName exists
admin_back_go/internal/module/mail/service.go:330     SendVerifyCode still sends app_name
admin_back_go/internal/config/config.go:224           VERIFY_CODE_TTL still feeds runtime config
admin_back_go/internal/bootstrap/app.go:242           auth gets cfg.VerifyCode.TTL
 docs/mail-templates/tencent-ses/*.html               still uses {{app_name}}
```

---

## Files

Create:

```text
admin_back_go/database/migrations/20260514_verify_code_ttl_policy.sql
admin_back_go/internal/module/auth/verify_code_policy.go
admin_back_go/internal/module/auth/verify_code_policy_test.go
```

Modify:

```text
admin_back_go/internal/module/auth/service.go
admin_back_go/internal/module/auth/service_test.go
admin_back_go/internal/module/mail/dto.go
admin_back_go/internal/module/mail/request.go
admin_back_go/internal/module/mail/handler.go
admin_back_go/internal/module/mail/repository.go
admin_back_go/internal/module/mail/service.go
admin_back_go/internal/module/mail/service_test.go
admin_back_go/internal/module/mail/repository_test.go
admin_back_go/internal/platform/mail/tencentcloudses/client_test.go
admin_back_go/internal/bootstrap/app.go
admin_back_go/internal/server/router_test.go
admin_front_ts/src/api/system/mail.ts
admin_front_ts/src/views/Main/system/mail/mailDict.ts
admin_front_ts/src/views/Main/system/mail/components/MailConfigPanel.vue
admin_front_ts/src/views/Main/system/mail/components/MailTemplatePanel.vue
admin_front_ts/tests/shared/system/mail-api.test.ts
docs/mail-templates/tencent-ses/login-code.html
docs/mail-templates/tencent-ses/forget-password-code.html
docs/mail-templates/tencent-ses/bind-email-code.html
docs/mail-templates/tencent-ses/change-password-code.html
docs/contracts/admin-api-v1.md
docs/deployment/first-node-baota-docker.md
docs/deployment/production.md
docs/migration/current-status.md
docs/superpowers/specs/2026-05-14-verify-code-template-ttl-db-design.md
```

Do not modify:

```text
admin_back_go/internal/module/user/service.go
admin_back_go/internal/module/user/service_test.go
```

理由：用户资料/账号安全只消费 Redis 里已有验证码；本轮改的是创建验证码时的 TTL 来源。

---

## Task 1: DB migration seeds shared TTL and fixes existing mail template variables

**Files:**

- Create: `E:/admin_go/admin_back_go/database/migrations/20260514_verify_code_ttl_policy.sql`

- [x] **Step 1: Add migration SQL**

```sql
INSERT INTO `system_settings` (`setting_key`, `setting_value`, `value_type`, `remark`, `status`, `is_del`)
VALUES ('auth.verify_code.ttl_minutes', '5', 2, '验证码有效期分钟数，邮件和短信共用', 1, 2)
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

UPDATE `mail_templates`
SET
  `variables_json` = JSON_ARRAY('code', 'ttl_minutes'),
  `sample_variables_json` = JSON_OBJECT('code', '123456', 'ttl_minutes', '5'),
  `updated_at` = CURRENT_TIMESTAMP
WHERE `is_del` = 2
  AND `scene` IN ('login', 'forget', 'bind_email', 'change_password');
```

- [x] **Step 2: Verify scope**

Run:

```powershell
cd E:/admin_go
rg -n "auth.verify_code.ttl_minutes|mail_configs.*ttl|app_name" admin_back_go/database/migrations/20260514_verify_code_ttl_policy.sql
```

Expected:

```text
auth.verify_code.ttl_minutes exists.
mail_configs TTL and app_name do not exist.
```

---

## Task 2: Add auth policy provider backed by system_settings

**Files:**

- Create: `E:/admin_go/admin_back_go/internal/module/auth/verify_code_policy.go`
- Create: `E:/admin_go/admin_back_go/internal/module/auth/verify_code_policy_test.go`
- Modify: `E:/admin_go/admin_back_go/internal/module/auth/service.go`

- [x] **Step 1: Write failing tests**

Create `verify_code_policy_test.go`:

```go
package auth

import (
	"context"
	"errors"
	"testing"
	"time"

	"admin_back_go/internal/enum"
	"admin_back_go/internal/module/systemsetting"
)

type fakeVerifyCodePolicyRepository struct {
	row *systemsetting.Setting
	err error
}

func (f fakeVerifyCodePolicyRepository) SettingByKey(ctx context.Context, key string) (*systemsetting.Setting, error) {
	return f.row, f.err
}

func TestSystemSettingVerifyCodePolicyProviderTTL(t *testing.T) {
	tests := []struct {
		name    string
		row     *systemsetting.Setting
		want    time.Duration
		wantErr string
	}{
		{name: "enabled", row: &systemsetting.Setting{SettingKey: VerifyCodeTTLSettingKey, SettingValue: "7", ValueType: enum.SystemSettingValueNumber, Status: enum.CommonYes, IsDel: enum.CommonNo}, want: 7 * time.Minute},
		{name: "missing", row: nil, wantErr: "验证码有效期配置缺失"},
		{name: "disabled", row: &systemsetting.Setting{SettingKey: VerifyCodeTTLSettingKey, SettingValue: "5", ValueType: enum.SystemSettingValueNumber, Status: enum.CommonNo, IsDel: enum.CommonNo}, wantErr: "验证码有效期配置已禁用"},
		{name: "wrong type", row: &systemsetting.Setting{SettingKey: VerifyCodeTTLSettingKey, SettingValue: "5", ValueType: enum.SystemSettingValueString, Status: enum.CommonYes, IsDel: enum.CommonNo}, wantErr: "验证码有效期配置类型必须为数字"},
		{name: "zero", row: &systemsetting.Setting{SettingKey: VerifyCodeTTLSettingKey, SettingValue: "0", ValueType: enum.SystemSettingValueNumber, Status: enum.CommonYes, IsDel: enum.CommonNo}, wantErr: "验证码有效期必须在 1-60 分钟之间"},
		{name: "too large", row: &systemsetting.Setting{SettingKey: VerifyCodeTTLSettingKey, SettingValue: "61", ValueType: enum.SystemSettingValueNumber, Status: enum.CommonYes, IsDel: enum.CommonNo}, wantErr: "验证码有效期必须在 1-60 分钟之间"},
		{name: "decimal", row: &systemsetting.Setting{SettingKey: VerifyCodeTTLSettingKey, SettingValue: "1.5", ValueType: enum.SystemSettingValueNumber, Status: enum.CommonYes, IsDel: enum.CommonNo}, wantErr: "验证码有效期必须为整数分钟"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			provider := NewSystemSettingVerifyCodePolicyProvider(fakeVerifyCodePolicyRepository{row: tt.row})
			got, appErr := provider.VerifyCodeTTL(context.Background())
			if tt.wantErr != "" {
				if appErr == nil || appErr.Message != tt.wantErr { t.Fatalf("want %q got %#v", tt.wantErr, appErr) }
				return
			}
			if appErr != nil || got != tt.want { t.Fatalf("ttl=%s err=%#v", got, appErr) }
		})
	}
}

func TestSystemSettingVerifyCodePolicyProviderWrapsRepositoryError(t *testing.T) {
	provider := NewSystemSettingVerifyCodePolicyProvider(fakeVerifyCodePolicyRepository{err: errors.New("db down")})
	_, appErr := provider.VerifyCodeTTL(context.Background())
	if appErr == nil || appErr.Message != "查询验证码有效期配置失败" { t.Fatalf("got %#v", appErr) }
}
```

Run:

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/module/auth -run "TestSystemSettingVerifyCodePolicyProvider" -count=1
```

Expected: fail with undefined provider names.

- [x] **Step 2: Implement provider**

Create `verify_code_policy.go`:

```go
package auth

import (
	"context"
	"net/http"
	"strconv"
	"strings"
	"time"

	"admin_back_go/internal/apperror"
	"admin_back_go/internal/enum"
	"admin_back_go/internal/module/systemsetting"
)

const (
	VerifyCodeTTLSettingKey = "auth.verify_code.ttl_minutes"
	minVerifyCodeTTLMinutes = 1
	maxVerifyCodeTTLMinutes = 60
)

type VerifyCodePolicyProvider interface {
	VerifyCodeTTL(ctx context.Context) (time.Duration, *apperror.Error)
}

type VerifyCodePolicyRepository interface {
	SettingByKey(ctx context.Context, key string) (*systemsetting.Setting, error)
}

type SystemSettingVerifyCodePolicyProvider struct { repository VerifyCodePolicyRepository }

func NewSystemSettingVerifyCodePolicyProvider(repository VerifyCodePolicyRepository) *SystemSettingVerifyCodePolicyProvider {
	return &SystemSettingVerifyCodePolicyProvider{repository: repository}
}

func (p *SystemSettingVerifyCodePolicyProvider) VerifyCodeTTL(ctx context.Context) (time.Duration, *apperror.Error) {
	if p == nil || p.repository == nil { return 0, apperror.Internal("验证码策略仓储未配置") }
	row, err := p.repository.SettingByKey(ctx, VerifyCodeTTLSettingKey)
	if err != nil { return 0, apperror.Wrap(apperror.CodeInternal, http.StatusInternalServerError, "查询验证码有效期配置失败", err) }
	if row == nil || row.IsDel != enum.CommonNo { return 0, apperror.Internal("验证码有效期配置缺失") }
	if row.Status != enum.CommonYes { return 0, apperror.BadRequest("验证码有效期配置已禁用") }
	if row.ValueType != enum.SystemSettingValueNumber { return 0, apperror.Internal("验证码有效期配置类型必须为数字") }
	minutes, err := strconv.Atoi(strings.TrimSpace(row.SettingValue))
	if err != nil { return 0, apperror.BadRequest("验证码有效期必须为整数分钟") }
	if minutes < minVerifyCodeTTLMinutes || minutes > maxVerifyCodeTTLMinutes { return 0, apperror.BadRequest("验证码有效期必须在 1-60 分钟之间") }
	return time.Duration(minutes) * time.Minute, nil
}
```

- [x] **Step 3: Add service option**

Modify `auth.Service` in `service.go`:

```go
verifyCodePolicy VerifyCodePolicyProvider
```

Add option near `WithVerifyCodeMailSender`:

```go
func WithVerifyCodePolicyProvider(provider VerifyCodePolicyProvider) Option {
	return func(s *Service) { s.verifyCodePolicy = provider }
}
```

Run the same focused test; expected `ok`.

---

## Task 3: Use policy TTL in auth.SendCode

**Files:**

- Modify: `E:/admin_go/admin_back_go/internal/module/auth/service.go`
- Modify: `E:/admin_go/admin_back_go/internal/module/auth/service_test.go`
- Modify: `E:/admin_go/admin_back_go/internal/bootstrap/app.go`

- [x] **Step 1: Add failing SendCode tests**

Append to `service_test.go` near existing SendCode tests:

```go
type fakeVerifyCodePolicyProvider struct { ttl time.Duration; err *apperror.Error }
func (f fakeVerifyCodePolicyProvider) VerifyCodeTTL(ctx context.Context) (time.Duration, *apperror.Error) {
	if f.err != nil { return 0, f.err }
	return f.ttl, nil
}

func TestServiceSendCodeUsesPolicyTTLForEmailCacheAndMailSender(t *testing.T) {
	store := &fakeCodeStore{}
	mailSender := &fakeVerifyCodeMailSender{}
	service := NewService(&fakeAuthRepository{}, fakeLoginTypeProvider{types: []string{LoginTypeEmail}}, &fakeSessionCreator{}, &fakeCaptchaVerifier{}, WithCodeStore(store), WithVerifyCodeMailSender(mailSender), WithVerifyCodePolicyProvider(fakeVerifyCodePolicyProvider{ttl: 9 * time.Minute}), WithVerifyCodeOptions(VerifyCodeOptions{TTL: 5 * time.Minute, CodeGenerator: func() (string, error) { return "654321", nil }}))
	_, appErr := service.SendCode(context.Background(), SendCodeInput{Account: "user@example.com", Scene: VerifyCodeSceneLogin})
	if appErr != nil { t.Fatalf("unexpected err %#v", appErr) }
	if store.setTTL != 9*time.Minute || mailSender.ttl != 9*time.Minute { t.Fatalf("store=%s mail=%s", store.setTTL, mailSender.ttl) }
}

func TestServiceSendCodeUsesPolicyTTLForPhoneCache(t *testing.T) {
	store := &fakeCodeStore{}
	service := NewService(&fakeAuthRepository{}, fakeLoginTypeProvider{types: []string{LoginTypePhone}}, &fakeSessionCreator{}, &fakeCaptchaVerifier{}, WithCodeStore(store), WithVerifyCodePolicyProvider(fakeVerifyCodePolicyProvider{ttl: 8 * time.Minute}), WithVerifyCodeOptions(VerifyCodeOptions{TTL: 5 * time.Minute}))
	_, appErr := service.SendCode(context.Background(), SendCodeInput{Account: "15671628271", Scene: VerifyCodeSceneLogin})
	if appErr != nil { t.Fatalf("unexpected err %#v", appErr) }
	if store.setCode != "123456" || store.setTTL != 8*time.Minute { t.Fatalf("code=%q ttl=%s", store.setCode, store.setTTL) }
}

func TestServiceSendCodeStopsWhenPolicyTTLInvalid(t *testing.T) {
	store := &fakeCodeStore{}
	service := NewService(&fakeAuthRepository{}, fakeLoginTypeProvider{types: []string{LoginTypeEmail}}, &fakeSessionCreator{}, &fakeCaptchaVerifier{}, WithCodeStore(store), WithVerifyCodeMailSender(&fakeVerifyCodeMailSender{}), WithVerifyCodePolicyProvider(fakeVerifyCodePolicyProvider{err: apperror.BadRequest("验证码有效期配置已禁用")}), WithVerifyCodeOptions(VerifyCodeOptions{TTL: 5 * time.Minute, CodeGenerator: func() (string, error) { return "654321", nil }}))
	message, appErr := service.SendCode(context.Background(), SendCodeInput{Account: "user@example.com", Scene: VerifyCodeSceneLogin})
	if message != "" || appErr == nil || appErr.Message != "验证码有效期配置已禁用" { t.Fatalf("message=%q err=%#v", message, appErr) }
	if store.setKey != "" { t.Fatalf("must not write Redis before policy passes: %#v", store) }
}
```

Run focused test; expected fail because old code uses `VerifyCodeOptions.TTL`.

- [x] **Step 2: Implement helper and use it**

In `service.go`, add:

```go
func (s *Service) verifyCodeTTL(ctx context.Context) (time.Duration, *apperror.Error) {
	if s != nil && s.verifyCodePolicy != nil { return s.verifyCodePolicy.VerifyCodeTTL(ctx) }
	return s.verifyCodeOptions.TTL, nil
}
```

In `SendCode`, before generating/storing code:

```go	ttl, appErr := s.verifyCodeTTL(ctx)
if appErr != nil { return "", appErr }
```

Then replace both `s.verifyCodeOptions.TTL` usages in `SendCode` with `ttl`.

- [x] **Step 3: Wire bootstrap**

In `bootstrap/app.go`, change system setting construction:

```go
systemSettingRepository := systemsetting.NewGormRepository(resources.DB, resources.Redis)
systemSettingService := systemsetting.NewService(systemSettingRepository)
```

Add auth option:

```go
auth.WithVerifyCodePolicyProvider(auth.NewSystemSettingVerifyCodePolicyProvider(systemSettingRepository)),
```

Leave only Redis prefix in verify options:

```go
auth.WithVerifyCodeOptions(auth.VerifyCodeOptions{RedisPrefix: cfg.VerifyCode.RedisPrefix}),
```

Run:

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/module/auth -run "TestServiceSendCode" -count=1
```

Expected: `ok`.

---

## Task 4: Mail config exposes/saves TTL through system_settings

**Files:**

- Modify: `admin_back_go/internal/module/mail/dto.go`
- Modify: `admin_back_go/internal/module/mail/request.go`
- Modify: `admin_back_go/internal/module/mail/handler.go`
- Modify: `admin_back_go/internal/module/mail/repository.go`
- Modify: `admin_back_go/internal/module/mail/service.go`
- Modify: `admin_back_go/internal/module/mail/service_test.go`
- Modify: `admin_back_go/internal/bootstrap/app.go`

- [x] **Step 1: Extend mail repository interface**

In `mail/repository.go`, import:

```go
"admin_back_go/internal/module/systemsetting"
"admin_back_go/internal/platform/redisclient"
```

Extend `Repository`:

```go
SettingByKey(ctx context.Context, key string) (*systemsetting.Setting, error)
SaveSetting(ctx context.Context, row systemsetting.Setting) error
InvalidateSettingCache(ctx context.Context, key string) error
```

Change repository struct/constructor:

```go
type GormRepository struct { db *gorm.DB; cache *redisclient.Client }
func NewGormRepository(client *database.Client, cache ...*redisclient.Client) *GormRepository { ... }
```

Implement `SettingByKey`, `SaveSetting`, `InvalidateSettingCache` using `system_settings`, `setting_key`, `is_del=2`, row lock in save, and Redis key `sys_setting_raw_` + dots replaced by `_`.

- [x] **Step 2: Extend DTO/request/handler**

Add field to `ConfigResponse` and `SaveConfigInput`:

```go
VerifyCodeTTLMinutes int `json:"verify_code_ttl_minutes"`
```

For `SaveConfigInput`, no JSON tag.

Add request field:

```go
VerifyCodeTTLMinutes int `json:"verify_code_ttl_minutes" binding:"required"`
```

Pass it through in `handler.SaveConfig`.

- [x] **Step 3: Implement service behavior**

In `mail/service.go` add constants:

```go
verifyCodeTTLSettingKey = "auth.verify_code.ttl_minutes"
defaultVerifyCodeTTLMin = 5
minVerifyCodeTTLMin = 1
maxVerifyCodeTTLMin = 60
```

Add helpers:

```go
func normalizeVerifyCodeTTLMinutes(value int) (int, *apperror.Error) {
	if value < minVerifyCodeTTLMin || value > maxVerifyCodeTTLMin { return 0, apperror.BadRequest("验证码有效期必须在 1-60 分钟之间") }
	return value, nil
}
```

`Config()` must return `verify_code_ttl_minutes` from `system_settings`; if missing, return default 5 for UI display only.

`SaveConfig()` must save mail config as before, then upsert:

```go
systemsetting.Setting{SettingKey: verifyCodeTTLSettingKey, SettingValue: strconv.Itoa(ttl), ValueType: enum.SystemSettingValueNumber, Remark: "验证码有效期分钟数，邮件和短信共用", Status: enum.CommonYes, IsDel: enum.CommonNo}
```

Then call `InvalidateSettingCache(ctx, verifyCodeTTLSettingKey)`.

- [x] **Step 4: Wire mail repo with Redis**

In `bootstrap/app.go`:

```go
mailService := mail.NewService(mail.NewGormRepository(resources.DB, resources.Redis), secretBox, mailSender)
```

- [x] **Step 5: Tests to add**

Add/adjust in `mail/service_test.go`:

```go
TestServiceConfigIncludesVerifyCodeTTLFromSystemSetting
TestServiceDefaultConfigIncludesVerifyCodeTTLFromSystemSetting
TestServiceSaveConfigPersistsVerifyCodeTTLToSystemSettings
TestServiceSaveConfigRejectsInvalidVerifyCodeTTL
```

Each fake repo must implement the new repository methods. Assertions:

```text
Config returns verify_code_ttl_minutes = row.SettingValue.
Default Config returns configured=false and ttl=5 or row value.
SaveConfig writes SettingKey auth.verify_code.ttl_minutes, SettingValue "11", ValueType number.
SaveConfig invalidates sys setting cache key through repository method.
TTL 0 or 61 returns 验证码有效期必须在 1-60 分钟之间.
```

Run:

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/module/mail -run "TestServiceConfigIncludesVerifyCodeTTL|TestServiceDefaultConfigIncludesVerifyCodeTTL|TestServiceSaveConfigPersistsVerifyCodeTTL|TestServiceSaveConfigRejectsInvalidVerifyCodeTTL" -count=1
```

Expected: `ok`.

---
## Task 5: Enforce exact template variables and remove app_name from runtime payload

**Files:**

- Modify: `admin_back_go/internal/module/mail/service.go`
- Modify: `admin_back_go/internal/module/mail/service_test.go`
- Modify: `admin_back_go/internal/module/mail/repository_test.go`
- Modify: `admin_back_go/internal/platform/mail/tencentcloudses/client_test.go`

- [x] **Step 1: Update tests first**

In `mail/service_test.go`:

1. Change verify-code template fixtures from:

```go
VariablesJSON: `["app_name","code","ttl_minutes"]`
SampleVariablesJSON: `{"app_name":"admin_go","code":"123456","ttl_minutes":"5"}`
```

to:

```go
VariablesJSON: `["code","ttl_minutes"]`
SampleVariablesJSON: `{"code":"123456","ttl_minutes":"5"}`
```

2. In `TestServiceSendVerifyCodeUsesEnabledConfigTemplateAndWritesSanitizedLogs`, add:

```go
if _, ok := sender.input.TemplateData["app_name"]; ok {
	t.Fatalf("verify-code TemplateData must not include app_name: %#v", sender.input.TemplateData)
}
if len(sender.input.TemplateData) != 2 {
	t.Fatalf("verify-code TemplateData must contain exactly code and ttl_minutes, got %#v", sender.input.TemplateData)
}
```

3. Replace the old “missing variable” test with:

```go
func TestServiceRejectsVerifyCodeTemplateWithAppNameVariable(t *testing.T) {
	service := NewService(&fakeMailRepository{}, testSecretBox(), &fakeMailSender{})
	_, appErr := service.CreateTemplate(context.Background(), SaveTemplateInput{
		Scene: enum.VerifyCodeSceneLogin, Name: "登录验证码", Subject: "Login", TencentTemplateID: 123456,
		Variables: []string{"app_name", "code", "ttl_minutes"},
		SampleVariables: map[string]string{"app_name": "admin_go", "code": "123456", "ttl_minutes": "5"},
		Status: enum.CommonYes,
	})
	if appErr == nil || appErr.Message != "验证码模板变量必须且只能是 code、ttl_minutes" { t.Fatalf("got %#v", appErr) }
}

func TestServiceRejectsVerifyCodeTemplateWithExtraSampleVariable(t *testing.T) {
	service := NewService(&fakeMailRepository{}, testSecretBox(), &fakeMailSender{})
	_, appErr := service.CreateTemplate(context.Background(), SaveTemplateInput{
		Scene: enum.VerifyCodeSceneForget, Name: "找回密码验证码", Subject: "Reset", TencentTemplateID: 123457,
		Variables: []string{"code", "ttl_minutes"},
		SampleVariables: map[string]string{"code": "123456", "ttl_minutes": "5", "app_name": "admin_go"},
		Status: enum.CommonYes,
	})
	if appErr == nil || appErr.Message != "验证码模板测试变量必须且只能是 code、ttl_minutes" { t.Fatalf("got %#v", appErr) }
}
```

In `repository_test.go`, replace any `app_name` fixture with code/ttl only.

In `platform/mail/tencentcloudses/client_test.go`, change expected JSON to:

```go
got, err := TemplateDataJSON(map[string]string{"ttl_minutes": "5", "code": "123456"})
if got != `{"code":"123456","ttl_minutes":"5"}` { ... }
```

Run focused tests and expect failure before implementation.

- [x] **Step 2: Remove app_name from SendVerifyCode**

In `mail/service.go`, delete `defaultAppName` and change payload to:

```go
data := map[string]string{
	"code":        code,
	"ttl_minutes": ttlMinutes(ttl),
}
```

- [x] **Step 3: Enforce exact variable contract**

In `templateRowFromInput`, after scene/status validation and before encoding:

```go
if appErr := ensureVerifyCodeTemplateVariables(input.Variables, input.SampleVariables); appErr != nil {
	return Template{}, appErr
}
```

Add helper:

```go
func ensureVerifyCodeTemplateVariables(variables []string, sample map[string]string) *apperror.Error {
	normalized, appErr := normalizeVariables(variables)
	if appErr != nil { return appErr }
	if len(normalized) != 2 || normalized[0] != "code" || normalized[1] != "ttl_minutes" {
		return apperror.BadRequest("验证码模板变量必须且只能是 code、ttl_minutes")
	}
	if len(sample) != 2 { return apperror.BadRequest("验证码模板测试变量必须且只能是 code、ttl_minutes") }
	for _, key := range normalized {
		if _, ok := sample[key]; !ok { return apperror.BadRequest("测试变量缺少 " + key) }
	}
	for key := range sample {
		if key != "code" && key != "ttl_minutes" { return apperror.BadRequest("验证码模板测试变量必须且只能是 code、ttl_minutes") }
	}
	return nil
}
```

Also tighten runtime data check:

```go
func ensureTemplateDataCoversVariables(variables []string, data map[string]string) *apperror.Error {
	allowed := make(map[string]struct{}, len(variables))
	for _, key := range variables {
		allowed[key] = struct{}{}
		if _, ok := data[key]; !ok { return apperror.Internal("邮件模板变量缺少 " + key) }
	}
	for key := range data {
		if _, ok := allowed[key]; !ok { return apperror.Internal("邮件模板变量多余 " + key) }
	}
	return nil
}
```

- [x] **Step 4: Verify focused tests**

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/module/mail ./internal/platform/mail/tencentcloudses -run "TestServiceSendVerifyCode|TestServiceRejectsVerifyCodeTemplate|TestTemplateDataJSON" -count=1
```

Expected: `ok`.

---

## Task 6: Update Vue mail config and template UI

**Files:**

- Modify: `admin_front_ts/src/api/system/mail.ts`
- Modify: `admin_front_ts/src/views/Main/system/mail/mailDict.ts`
- Modify: `admin_front_ts/src/views/Main/system/mail/components/MailConfigPanel.vue`
- Modify: `admin_front_ts/src/views/Main/system/mail/components/MailTemplatePanel.vue`
- Modify: `admin_front_ts/tests/shared/system/mail-api.test.ts`

- [x] **Step 1: Update frontend tests first**

In `mail-api.test.ts`, remove the old blanket forbidden assertion:

```ts
expect(source).not.toContain('verify_code')
```

Add:

```ts
it('exposes shared verify-code ttl on mail config without app_name template variables', () => {
  const apiSource = readFrontendSource('src/api/system/mail.ts')
  const configSource = readFrontendSource('src/views/Main/system/mail/components/MailConfigPanel.vue')
  const templateSource = readFrontendSource('src/views/Main/system/mail/components/MailTemplatePanel.vue')

  expect(apiSource).toContain('verify_code_ttl_minutes: number')
  expect(configSource).toContain('form.verify_code_ttl_minutes = row.verify_code_ttl_minutes || dict.value.default_ttl_minutes')
  expect(configSource).toContain('prop="verify_code_ttl_minutes"')
  expect(configSource).toContain("t('mail.config.verifyCodeTTLMinutes')")
  expect(configSource).toContain("t('mail.config.verifyCodeTTLHelp')")
  expect(templateSource).toContain("const verifyCodeTemplateVariables = ['code', 'ttl_minutes']")
  expect(templateSource).not.toContain('app_name')
})
```

Run:

```powershell
cd E:/admin_go/admin_front_ts
npm run test -- tests/shared/system/mail-api.test.ts
```

Expected: fail.

- [x] **Step 2: Extend API types**

In `src/api/system/mail.ts`, add:

```ts
default_ttl_minutes: number
```

to `MailPageInitResponse.dict`, and add:

```ts
verify_code_ttl_minutes: number
```

to both `MailConfigItem` and `MailConfigFormState`.

- [x] **Step 3: Extend default dict**

In `mailDict.ts`, add:

```ts
default_ttl_minutes: 5,
```

- [x] **Step 4: Add TTL field to MailConfigPanel**

In form state:

```ts
verify_code_ttl_minutes: 5,
```

In rules:

```ts
verify_code_ttl_minutes: [
  { required: true, message: t('mail.config.rules.verifyCodeTTL'), trigger: 'blur' },
  { type: 'number', min: 1, max: 60, message: t('mail.config.rules.verifyCodeTTLRange'), trigger: 'blur' },
],
```

In `applyConfig`:

```ts
form.verify_code_ttl_minutes = row.verify_code_ttl_minutes || dict.value.default_ttl_minutes
```

In template, add a field near `from_name`:

```vue
<el-col :span="24" :md="12">
  <el-form-item :label="t('mail.config.verifyCodeTTLMinutes')" prop="verify_code_ttl_minutes">
    <el-input-number v-model="form.verify_code_ttl_minutes" :min="1" :max="60" :precision="0" controls-position="right" />
    <div class="mail-config__help">{{ t('mail.config.verifyCodeTTLHelp') }}</div>
  </el-form-item>
</el-col>
```

Add CSS:

```css
.mail-config__help {
  width: 100%;
  margin-top: 6px;
  color: var(--el-text-color-secondary);
  font-size: 12px;
  line-height: 1.5;
}
```

- [x] **Step 5: Default template variables to exact pair**

In `MailTemplatePanel.vue` add:

```ts
const verifyCodeTemplateVariables = ['code', 'ttl_minutes']
const verifyCodeSampleVariables: Record<string, string> = { code: '123456', ttl_minutes: '5' }
```

In `openCreate()` after `resetForm()`:

```ts
form.variables_text = verifyCodeTemplateVariables.join('\n')
form.sample_variables = toSampleRows(verifyCodeTemplateVariables, verifyCodeSampleVariables)
```

In `buildPayload()` after normalizing variables:

```ts
if (variables.length !== 2 || variables[0] !== 'code' || variables[1] !== 'ttl_minutes') {
  throw new Error(t('mail.template.rules.verifyCodeVariables'))
}
```

After building sample variables:

```ts
const sampleKeys = Object.keys(sampleVariables).sort()
if (sampleKeys.length !== 2 || sampleKeys[0] !== 'code' || sampleKeys[1] !== 'ttl_minutes') {
  throw new Error(t('mail.template.rules.verifyCodeSampleVariables'))
}
```

- [x] **Step 6: Add i18n keys if needed**

Search:

```powershell
cd E:/admin_go/admin_front_ts
rg -n "mail\.config\.fromName|verifyCodeTTL|verifyCodeVariables" src/i18n src/views/Main/system/mail -S
```

If locale files contain mail keys, add Chinese/English keys:

```ts
verifyCodeTTLMinutes: '验证码有效期（分钟）',
verifyCodeTTLHelp: '邮件和短信验证码共用；模板变量 ttl_minutes 自动取这个值。',
verifyCodeTTL: '请输入验证码有效期',
verifyCodeTTLRange: '验证码有效期必须在 1-60 分钟之间',
verifyCodeVariables: '验证码模板变量必须且只能是 code、ttl_minutes',
verifyCodeSampleVariables: '验证码模板测试变量必须且只能是 code、ttl_minutes',
```

- [x] **Step 7: Verify frontend**

```powershell
cd E:/admin_go/admin_front_ts
npm run test -- tests/shared/system/mail-api.test.ts
npx vue-tsc -b --pretty false
```

Expected: both pass.

---

## Task 7: Remove app_name from local Tencent SES HTML templates

**Files:**

- Modify: `docs/mail-templates/tencent-ses/login-code.html`
- Modify: `docs/mail-templates/tencent-ses/forget-password-code.html`
- Modify: `docs/mail-templates/tencent-ses/bind-email-code.html`
- Modify: `docs/mail-templates/tencent-ses/change-password-code.html`

- [x] **Step 1: Replace copy**

Use these replacements while preserving existing style attributes.

`login-code.html`:

```html
<title>登录验证码</title>
<h1 style="margin:10px 0 0;font-size:24px;line-height:1.35;">登录验证码</h1>
<p style="margin:0 0 16px;font-size:16px;line-height:1.8;">您好，您正在登录后台管理系统。请在登录页面输入下面的验证码完成身份验证：</p>
<div style="padding:18px 32px;background:#f9fafb;border-top:1px solid #e5e7eb;color:#6b7280;font-size:13px;line-height:1.7;">本邮件由系统自动发送，请勿直接回复。</div>
```

`forget-password-code.html`:

```html
<title>找回密码验证码</title>
<h1 style="margin:10px 0 0;font-size:24px;line-height:1.35;">找回密码验证码</h1>
<p style="margin:0 0 16px;font-size:16px;line-height:1.8;">您好，您正在申请重置账号密码。请使用以下验证码继续完成密码重置：</p>
<div style="padding:18px 32px;background:#f9fafb;border-top:1px solid #e5e7eb;color:#6b7280;font-size:13px;line-height:1.7;">本邮件由系统自动发送，请勿直接回复。</div>
```

`bind-email-code.html`:

```html
<title>绑定邮箱验证码</title>
<h1 style="margin:10px 0 0;font-size:24px;line-height:1.35;">绑定邮箱验证码</h1>
<p style="margin:0 0 16px;font-size:16px;line-height:1.8;">您好，您正在为账号绑定或更换邮箱。请在页面中输入以下验证码确认邮箱归属：</p>
<div style="padding:18px 32px;background:#f9fafb;border-top:1px solid #e5e7eb;color:#6b7280;font-size:13px;line-height:1.7;">本邮件由系统自动发送，请勿直接回复。</div>
```

`change-password-code.html`:

```html
<title>修改密码验证码</title>
<h1 style="margin:10px 0 0;font-size:24px;line-height:1.35;">修改密码验证码</h1>
<p style="margin:0 0 16px;font-size:16px;line-height:1.8;">您好，您正在修改账号密码。请使用以下验证码确认本次敏感操作：</p>
<div style="padding:18px 32px;background:#f9fafb;border-top:1px solid #e5e7eb;color:#6b7280;font-size:13px;line-height:1.7;">本邮件由系统自动发送，请勿直接回复。</div>
```

Keep `{{code}}` and `{{ttl_minutes}}`.

- [x] **Step 2: Verify placeholders**

```powershell
cd E:/admin_go
rg -n "\{\{app_name\}\}|app_name" docs/mail-templates/tencent-ses
rg -n "\{\{(code|ttl_minutes)\}\}" docs/mail-templates/tencent-ses
```

Expected: first command no matches; second command finds all four templates.

---

## Task 8: Align contracts/deployment/status docs

**Files:**

- Modify: `docs/contracts/admin-api-v1.md`
- Modify: `docs/deployment/first-node-baota-docker.md`
- Modify: `docs/deployment/production.md`
- Modify: `docs/migration/current-status.md`
- Modify: `docs/superpowers/specs/2026-05-14-verify-code-template-ttl-db-design.md`

- [x] **Step 1: Fix API contract**

Replace old final-rule text:

```text
Verification-code templates must include app_name, code, and ttl_minutes.
app_name comes from APP_NAME, default admin_go.
ttl_minutes comes from VERIFY_CODE_TTL, default 5 minutes.
```

with:

```text
Verification-code templates must include exactly code and ttl_minutes.
app_name is not a verification-code template variable; mail_configs.from_name only controls the Tencent SES FromEmailAddress display name.
ttl_minutes comes from system_settings.auth.verify_code.ttl_minutes and is shared by email verification and future SMS verification.
Templates do not own independent TTL, app-name, brand-name, or system-name policy.
```

In `MailPageInitDict`, remove `default_app_name`; keep/add:

```ts
default_ttl_minutes: number
```

In mail config request/response schema, add:

```ts
verify_code_ttl_minutes: number
```

- [x] **Step 2: Fix deployment docs**

In both deployment docs:

```text
Remove APP_NAME=admin_go if it was only added for verification-code templates.
Remove VERIFY_CODE_TTL=5m from required env.
Keep VERIFY_CODE_REDIS_PREFIX=auth:verify_code:.
Add: 验证码有效期不是 env；它来自 DB 配置 system_settings.auth.verify_code.ttl_minutes，默认 seed 为 5 分钟，可在 /system/mail 的“验证码公共配置”里修改。验证码模板变量必须且只能包含 code / ttl_minutes。
```

- [x] **Step 3: Fix current status**

Update `mail / Tencent SES` row:

```text
auth/send-code injects VerifyCodeMailSender for email, always sends email codes through Tencent SES, uses fixed 123456 for phone without SMS/env switches, requires mail templates to expose exactly code / ttl_minutes, and reads verification-code TTL from system_settings.auth.verify_code.ttl_minutes instead of VERIFY_CODE_TTL.
```

- [x] **Step 4: Mark spec accepted**

Change:

```text
状态：draft for review
```

to:

```text
状态：accepted for implementation
```

- [x] **Step 5: Verify docs old policy is gone**

```powershell
cd E:/admin_go
rg -n "app_name comes from APP_NAME|default_app_name|app_name/code/ttl_minutes|APP_NAME=admin_go|VERIFY_CODE_TTL" docs admin_back_go/internal admin_front_ts/src admin_front_ts/tests -S
```

Expected: no active runtime/deployment/contract matches. Historical old-code evidence inside the accepted spec is allowed only if it is clearly labeled as old/current-conflict evidence, not final policy.

---

## Task 9: Remove active env TTL dependency if no longer used

**Files:**

- Modify: `admin_back_go/internal/config/config.go` if active `cfg.VerifyCode.TTL` usage is gone.
- Modify: `admin_back_go/internal/config/*_test.go` if tests mention `VERIFY_CODE_TTL`.

- [x] **Step 1: Inspect usage**

```powershell
cd E:/admin_go
rg -n "VerifyCode\.TTL|VERIFY_CODE_TTL|VerifyCodeConfig" admin_back_go/internal admin_back_go/.env* .env* docs -S
```

Expected after Task 3:

```text
VerifyCode.RedisPrefix still used.
VerifyCode.TTL should not feed bootstrap runtime.
Deployment docs should not require VERIFY_CODE_TTL.
```

- [x] **Step 2: Minimal deletion**

If production code no longer reads `cfg.VerifyCode.TTL`, simplify config:

```go
type VerifyCodeConfig struct { RedisPrefix string }
...
VerifyCode: VerifyCodeConfig{RedisPrefix: envString("VERIFY_CODE_REDIS_PREFIX", "auth:verify_code:")},
```

Do not remove `auth.VerifyCodeOptions.TTL` in this plan; it remains a test fallback when no policy provider is injected.

- [x] **Step 3: Verify config package**

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/config -count=1
```

Expected: `ok`.

---

## Task 10: Full verification

- [x] **Step 1: gofmt**

```powershell
cd E:/admin_go/admin_back_go
gofmt -w .\internal\module\auth\service.go .\internal\module\auth\verify_code_policy.go .\internal\module\auth\verify_code_policy_test.go .\internal\module\auth\service_test.go .\internal\module\mail\dto.go .\internal\module\mail\request.go .\internal\module\mail\handler.go .\internal\module\mail\repository.go .\internal\module\mail\service.go .\internal\module\mail\service_test.go .\internal\module\mail\repository_test.go .\internal\platform\mail\tencentcloudses\client_test.go .\internal\bootstrap\app.go .\internal\server\router_test.go
```

- [x] **Step 2: Focused Go tests**

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/module/auth ./internal/module/mail ./internal/platform/mail/tencentcloudses ./internal/config ./internal/bootstrap -count=1
```

Expected: all `ok`.

- [x] **Step 3: Full Go tests**

```powershell
cd E:/admin_go/admin_back_go
go test ./... -count=1
```

Expected: all `ok`.

- [x] **Step 4: go vet**

```powershell
cd E:/admin_go/admin_back_go
go vet ./...
```

Expected: no output, exit 0.

- [x] **Step 5: race detector for changed modules**

```powershell
cd E:/admin_go/admin_back_go
go test -race ./internal/module/auth ./internal/module/mail -count=1
```

Expected: both `ok`.

- [x] **Step 6: golangci-lint if available**

```powershell
cd E:/admin_go/admin_back_go
if (Get-Command golangci-lint -ErrorAction SilentlyContinue) { golangci-lint run } else { Write-Host 'golangci-lint not installed; skipped' }
```

Expected: no lint output or explicit skipped message.

- [x] **Step 7: Frontend tests/typecheck**

```powershell
cd E:/admin_go/admin_front_ts
npm run test -- tests/shared/system/mail-api.test.ts
npx vue-tsc -b --pretty false
```

Expected: both pass.

- [x] **Step 8: Final grep gates**

```powershell
cd E:/admin_go
rg -n "\{\{app_name\}\}|TemplateData\[\"app_name\"\]|defaultAppName|default_app_name|APP_NAME=admin_go|app_name comes from APP_NAME|VERIFY_CODE_TTL" . -S
```

Expected: no active runtime/deployment/contract matches. Historical evidence inside the accepted spec is allowed only if clearly labeled as old behavior.

```powershell
cd E:/admin_go
rg -n "verify_code_ttl_minutes|auth.verify_code.ttl_minutes|code.*ttl_minutes|ttl_minutes.*code" docs admin_back_go/internal admin_back_go/database admin_front_ts/src admin_front_ts/tests -S
```

Expected: matches in migration, auth policy, mail config DTO/API/UI/tests, docs contract/status/spec.

- [x] **Step 9: Diff hygiene**

```powershell
cd E:/admin_go
git diff --check
git status --short
```

Expected:

```text
git diff --check exits 0.
Only intended root docs, admin_back_go, and admin_front_ts files are changed.
```

---

## Execution Order

```text
1. Migration.
2. Auth policy provider.
3. Auth SendCode TTL wiring.
4. Mail config API/DB TTL save.
5. Mail template exact variables and runtime payload cleanup.
6. Vue config/template UI.
7. HTML templates.
8. Docs.
9. Remove stale env TTL runtime dependency if unused.
10. Verification.
```

End-to-end proof required:

```text
/system/mail config save -> system_settings.auth.verify_code.ttl_minutes updated
/auth/send-code email -> reads DB TTL -> Redis Set uses same TTL -> Tencent SES TemplateData only has code + ttl_minutes
```

Self-review:

```text
No placeholder steps.
No SMS scope creep.
No mail_configs TTL column.
No app_name replacement variable.
Go interface is small and context-aware.
Verification includes go test, go vet, race detector, optional golangci-lint, frontend test/typecheck, grep gates, git diff --check.
```
