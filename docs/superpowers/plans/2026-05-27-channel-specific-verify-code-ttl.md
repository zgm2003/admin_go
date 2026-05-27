# 渠道独立验证码 TTL Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把验证码 TTL 从全局 `system_settings.auth.verify_code.ttl_minutes` 收口为邮件、短信两个渠道各自配置，避免邮件管理和短信管理互相覆盖。

**Architecture:** `mail_configs` 和 `sms_configs` 分别持有 `verify_code_ttl_minutes`。`auth.Service` 在识别账号类型后通过小接口读取渠道 TTL：email 读 mail，phone 读 sms；auth 不直接依赖 Tencent SDK，也不把 TTL 继续写进 `system_settings`。

**Tech Stack:** Go 1.26、Gin、GORM、MySQL migration、Vue 3 + TypeScript + vue-i18n、Vitest、项目自有 `apperror` / `response` / `systemsetting` / `secretbox`。

---

## 设计输入

Spec：`docs/superpowers/specs/2026-05-27-channel-specific-verify-code-ttl-design.md`

关键事实：

```text
当前 mail/sms 配置页都有 verify_code_ttl_minutes 字段，但后端都读写 system_settings.auth.verify_code.ttl_minutes。
当前 live DB 中 mail_configs / sms_configs 没有 TTL 字段。
目标是邮件和短信 TTL 各自配置，系统设置不再出现全局验证码 TTL。
```

## 文件结构

新增：

- `admin_back_go/database/migrations/20260527_channel_verify_code_ttl.sql`：增加两个配置表 TTL 字段，回填旧全局值，软删旧全局 setting。
- `admin_back_go/internal/module/auth/channel_verify_code_policy_test.go`：auth 渠道 TTL policy 单测。
- `admin_back_go/internal/module/auth/channel_verify_code_policy.go`：按账号类型分派 email/phone TTL provider。

修改：

- `admin_back_go/internal/module/mail/model.go`：`Config` 增加 `VerifyCodeTTLMinutes`。
- `admin_back_go/internal/module/mail/repository.go`：保存 config 时写入 `verify_code_ttl_minutes`；删除 systemsetting 读写依赖。
- `admin_back_go/internal/module/mail/service.go`：配置响应和 `VerifyCodeTTL` 从 mail config 读取。
- `admin_back_go/internal/module/mail/service_test.go`：改掉 “persist to system settings” 测试，新增 config-row TTL 测试。
- `admin_back_go/internal/module/sms/model.go`：`Config` 增加 `VerifyCodeTTLMinutes`。
- `admin_back_go/internal/module/sms/repository.go`：保存 config 时写入 `verify_code_ttl_minutes`；删除 systemsetting 读写依赖。
- `admin_back_go/internal/module/sms/service.go`：配置响应、test-send 和 `VerifyCodeTTL` 从 sms config 读取。
- `admin_back_go/internal/module/sms/service_test.go`：新增 config-row TTL 和 test-send TTL 测试。
- `admin_back_go/internal/module/auth/service.go`：`VerifyCodePolicyProvider` 改为按 account type 读取 TTL。
- `admin_back_go/internal/module/auth/service_test.go`：email/phone send-code 分别断言 TTL。
- `admin_back_go/internal/module/auth/verify_code_policy.go`：删除或瘦身旧 `SystemSettingVerifyCodePolicyProvider`，不再作为 active provider。
- `admin_back_go/internal/bootstrap/app.go`：注入 channel policy provider。
- `admin_back_go/internal/server/router_test.go`：如果有 mail/sms fake service TTL 断言，同步字段。
- `admin_front_ts/src/i18n/locales/zh-CN.ts`：邮件/短信 TTL 帮助文案不再说共用。
- `admin_front_ts/src/i18n/locales/en-US.ts`：英文文案不再说 shared。
- `admin_front_ts/tests/shared/system/mail-api.test.ts`：断言无 shared/system setting 文案。
- `admin_front_ts/tests/shared/system/sms-api.test.ts`：断言无 shared/system setting 文案。
- `docs/status/current-status.md`：实现验证后同步 mail/sms/auth facts。
- `docs/contracts/admin-api-v1.md`：更新 mail/sms config 保存语义和 TTL 来源。
- `admin_back_go/docs/architecture.md`：记录 system_settings 不再持有 verify-code TTL。
- `docs/testing/smoke-matrix.md`：更新 read gate 说明。
- `docs/deployment/docker-first-backend.md`、`docs/deployment/production.md`：删掉全局 `auth.verify_code.ttl_minutes` 说明。

---

## Task 1: 写 auth 渠道 TTL policy RED 测试

**Files:**

- Create: `admin_back_go/internal/module/auth/channel_verify_code_policy_test.go`
- Modify: `admin_back_go/internal/module/auth/service_test.go`

- [ ] **Step 1: 新增 channel policy 失败测试**

创建 `admin_back_go/internal/module/auth/channel_verify_code_policy_test.go`：

```go
package auth

import (
	"context"
	"testing"
	"time"

	"admin_back_go/internal/apperror"
	"admin_back_go/internal/enum"
)

type fakeTTLProvider struct {
	ttl    time.Duration
	called bool
	err    *apperror.Error
}

func (f *fakeTTLProvider) VerifyCodeTTL(ctx context.Context) (time.Duration, *apperror.Error) {
	f.called = true
	if f.err != nil {
		return 0, f.err
	}
	return f.ttl, nil
}

func TestChannelVerifyCodePolicyProviderRoutesByAccountType(t *testing.T) {
	email := &fakeTTLProvider{ttl: 7 * time.Minute}
	phone := &fakeTTLProvider{ttl: 9 * time.Minute}
	provider := NewChannelVerifyCodePolicyProvider(email, phone)

	emailTTL, appErr := provider.VerifyCodeTTL(context.Background(), enum.LoginTypeEmail)
	if appErr != nil || emailTTL != 7*time.Minute || !email.called || phone.called {
		t.Fatalf("expected email TTL only, ttl=%s email=%v phone=%v err=%v", emailTTL, email.called, phone.called, appErr)
	}

	email.called = false
	phone.called = false
	phoneTTL, appErr := provider.VerifyCodeTTL(context.Background(), enum.LoginTypePhone)
	if appErr != nil || phoneTTL != 9*time.Minute || !phone.called || email.called {
		t.Fatalf("expected phone TTL only, ttl=%s email=%v phone=%v err=%v", phoneTTL, email.called, phone.called, appErr)
	}
}

func TestChannelVerifyCodePolicyProviderRejectsInvalidAccountType(t *testing.T) {
	provider := NewChannelVerifyCodePolicyProvider(&fakeTTLProvider{ttl: time.Minute}, &fakeTTLProvider{ttl: time.Minute})
	_, appErr := provider.VerifyCodeTTL(context.Background(), "password")
	if appErr == nil || appErr.Message != "无效的验证码账号类型" {
		t.Fatalf("expected invalid account type error, got %#v", appErr)
	}
}
```

- [ ] **Step 2: 修改 auth SendCode TTL 测试期望**

在 `admin_back_go/internal/module/auth/service_test.go` 中把 fake policy 签名改成：

```go
type fakeVerifyCodePolicyProvider struct {
	ttl         time.Duration
	err         *apperror.Error
	accountType string
}

func (f *fakeVerifyCodePolicyProvider) VerifyCodeTTL(ctx context.Context, accountType string) (time.Duration, *apperror.Error) {
	f.accountType = accountType
	if f.err != nil {
		return 0, f.err
	}
	return f.ttl, nil
}
```

给 email/phone SendCode 测试分别加断言：

```go
if policy.accountType != enum.LoginTypeEmail {
	t.Fatalf("expected email TTL policy, got %q", policy.accountType)
}
```

和：

```go
if policy.accountType != enum.LoginTypePhone {
	t.Fatalf("expected phone TTL policy, got %q", policy.accountType)
}
```

- [ ] **Step 3: 运行测试确认 RED**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/auth -run "ChannelVerifyCodePolicyProvider|SendCode" -count=1
```

Expected:

```text
FAIL
undefined: NewChannelVerifyCodePolicyProvider
not enough arguments in call to s.verifyCodePolicy.VerifyCodeTTL
```

- [ ] **Step 4: 提交 RED 测试**

```powershell
git add internal/module/auth/channel_verify_code_policy_test.go internal/module/auth/service_test.go
git commit -m "test: cover channel-specific verify code ttl policy"
```

---

## Task 2: 写 mail/sms TTL schema migration

**Files:**

- Create: `admin_back_go/database/migrations/20260527_channel_verify_code_ttl.sql`

- [ ] **Step 1: 新增 migration**

创建 `admin_back_go/database/migrations/20260527_channel_verify_code_ttl.sql`：

```sql
SET @verify_code_ttl_minutes := (
  SELECT CASE
    WHEN `status` = 1
      AND `is_del` = 2
      AND `setting_value` REGEXP '^[0-9]+$'
      AND CAST(`setting_value` AS UNSIGNED) BETWEEN 1 AND 60
    THEN CAST(`setting_value` AS UNSIGNED)
    ELSE 5
  END
  FROM `system_settings`
  WHERE `setting_key` = 'auth.verify_code.ttl_minutes'
  ORDER BY `id` DESC
  LIMIT 1
);

SET @verify_code_ttl_minutes := COALESCE(@verify_code_ttl_minutes, 5);

ALTER TABLE `mail_configs`
  ADD COLUMN `verify_code_ttl_minutes` INT UNSIGNED NOT NULL DEFAULT 5 AFTER `reply_to`;

ALTER TABLE `sms_configs`
  ADD COLUMN `verify_code_ttl_minutes` INT UNSIGNED NOT NULL DEFAULT 5 AFTER `endpoint`;

UPDATE `mail_configs`
SET `verify_code_ttl_minutes` = @verify_code_ttl_minutes,
    `updated_at` = CURRENT_TIMESTAMP
WHERE `is_del` = 2;

UPDATE `sms_configs`
SET `verify_code_ttl_minutes` = @verify_code_ttl_minutes,
    `updated_at` = CURRENT_TIMESTAMP
WHERE `is_del` = 2;

UPDATE `system_settings`
SET `status` = 2,
    `is_del` = 1,
    `remark` = '已迁移到 mail_configs.verify_code_ttl_minutes 和 sms_configs.verify_code_ttl_minutes',
    `updated_at` = CURRENT_TIMESTAMP
WHERE `setting_key` = 'auth.verify_code.ttl_minutes';
```

- [ ] **Step 2: 本地 SQL 静态检查**

```powershell
cd E:\admin_go\admin_back_go
rg -n "auth\.verify_code\.ttl_minutes|verify_code_ttl_minutes" database\migrations\20260527_channel_verify_code_ttl.sql
```

Expected:

```text
migration contains one legacy source read/update and two channel columns.
```

- [ ] **Step 3: 提交 migration**

```powershell
git add database/migrations/20260527_channel_verify_code_ttl.sql
git commit -m "db: move verify code ttl into mail and sms configs"
```

---

## Task 3: 让 mail 配置真正持有 TTL

**Files:**

- Modify: `admin_back_go/internal/module/mail/model.go`
- Modify: `admin_back_go/internal/module/mail/repository.go`
- Modify: `admin_back_go/internal/module/mail/service.go`
- Modify: `admin_back_go/internal/module/mail/service_test.go`

- [ ] **Step 1: 写 mail service RED 测试**

在 `admin_back_go/internal/module/mail/service_test.go` 替换旧 system setting 持久化测试，新增：

```go
func TestServiceSaveConfigPersistsVerifyCodeTTLToMailConfig(t *testing.T) {
	repo := newFakeRepository()
	service := NewService(repo, fakeSecretBox{}, fakeSender{})

	appErr := service.SaveConfig(context.Background(), SaveConfigInput{
		SecretID: "AKID", SecretKey: "SECRET", Region: DefaultRegion, Endpoint: DefaultEndpoint,
		FromEmail: "new@example.com", Status: enum.CommonYes, VerifyCodeTTLMinutes: 11,
	})
	if appErr != nil {
		t.Fatalf("SaveConfig returned error: %v", appErr)
	}
	if repo.config == nil || repo.config.VerifyCodeTTLMinutes != 11 {
		t.Fatalf("expected mail config TTL 11, got %#v", repo.config)
	}
	if repo.savedSetting != nil {
		t.Fatalf("mail config must not write system setting, got %#v", repo.savedSetting)
	}
}

func TestServiceVerifyCodeTTLReadsMailConfig(t *testing.T) {
	repo := newFakeRepository()
	repo.config = &Config{ConfigKey: defaultConfigKey, VerifyCodeTTLMinutes: 13, Status: enum.CommonYes, IsDel: enum.CommonNo}
	service := NewService(repo, fakeSecretBox{}, fakeSender{})

	ttl, appErr := service.VerifyCodeTTL(context.Background())
	if appErr != nil || ttl != 13*time.Minute {
		t.Fatalf("expected 13m TTL, got %s err=%v", ttl, appErr)
	}
}
```

- [ ] **Step 2: 运行测试确认 RED**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/mail -run "SaveConfigPersistsVerifyCodeTTLToMailConfig|VerifyCodeTTLReadsMailConfig" -count=1
```

Expected:

```text
FAIL
Config has no field VerifyCodeTTLMinutes
service.VerifyCodeTTL undefined
```

- [ ] **Step 3: 修改 mail model**

在 `admin_back_go/internal/module/mail/model.go` 的 `Config` 中加字段：

```go
VerifyCodeTTLMinutes int `gorm:"column:verify_code_ttl_minutes"`
```

位置放在 `ReplyTo` 后、`Status` 前。

- [ ] **Step 4: 修改 mail repository 保存字段**

在 `admin_back_go/internal/module/mail/repository.go`：

删除 imports：

```go
"admin_back_go/internal/module/systemsetting"
"admin_back_go/internal/platform/redisclient"
```

把 `Repository` 接口里的以下方法删除：

```go
SettingByKey(ctx context.Context, key string) (*systemsetting.Setting, error)
SaveSetting(ctx context.Context, row systemsetting.Setting) error
InvalidateSettingCache(ctx context.Context, key string) error
```

把 `GormRepository` 改成：

```go
type GormRepository struct {
	db *gorm.DB
}

func NewGormRepository(client *database.Client, cache ...any) *GormRepository {
	if client == nil || client.Gorm == nil {
		return nil
	}
	return &GormRepository{db: client.Gorm}
}
```

在 `SaveDefaultConfig` 的 `fields` map 加入：

```go
"verify_code_ttl_minutes": row.VerifyCodeTTLMinutes,
```

删除文件末尾的 `SettingByKey` / `SaveSetting` / `InvalidateSettingCache` / `systemSettingCacheKey` 方法。

- [ ] **Step 5: 修改 mail service**

在 `admin_back_go/internal/module/mail/service.go`：

删除 imports：

```go
"strconv"
"admin_back_go/internal/module/systemsetting"
```

删除常量：

```go
verifyCodeTTLSettingKey = "auth.verify_code.ttl_minutes"
```

把 `Config()` 改成：

```go
func (s *Service) Config(ctx context.Context) (*ConfigResponse, *apperror.Error) {
	repo, appErr := s.requireRepository()
	if appErr != nil {
		return nil, appErr
	}
	row, err := repo.DefaultConfig(ctx)
	if err != nil {
		return nil, apperror.Wrap(apperror.CodeInternal, http.StatusInternalServerError, "查询邮件配置失败", err)
	}
	if row == nil {
		return defaultConfigResponse(defaultVerifyCodeTTLMin), nil
	}
	ttl, appErr := normalizeVerifyCodeTTLMinutes(row.VerifyCodeTTLMinutes)
	if appErr != nil {
		return nil, appErr
	}
	return configResponseFromRow(*row, ttl), nil
}
```

把 `SaveConfig()` 中写 system setting 的整段删除，只保留 config 保存：

```go
row, appErr := s.configRowFromInput(existing, input)
if appErr != nil {
	return appErr
}
if err := repo.SaveDefaultConfig(ctx, row); err != nil {
	return apperror.Wrap(apperror.CodeInternal, http.StatusInternalServerError, "保存邮件配置失败", err)
}
return nil
```

在 `configRowFromInput` 返回值中加：

```go
VerifyCodeTTLMinutes: input.VerifyCodeTTLMinutes,
```

删除 `configuredVerifyCodeTTL` 方法，新增：

```go
func (s *Service) VerifyCodeTTL(ctx context.Context) (time.Duration, *apperror.Error) {
	repo, appErr := s.requireRepository()
	if appErr != nil {
		return 0, appErr
	}
	row, err := repo.DefaultConfig(ctx)
	if err != nil {
		return 0, apperror.Wrap(apperror.CodeInternal, http.StatusInternalServerError, "查询邮件配置失败", err)
	}
	if row == nil {
		return time.Duration(defaultVerifyCodeTTLMin) * time.Minute, nil
	}
	minutes, appErr := normalizeVerifyCodeTTLMinutes(row.VerifyCodeTTLMinutes)
	if appErr != nil {
		return 0, appErr
	}
	return time.Duration(minutes) * time.Minute, nil
}
```

- [ ] **Step 6: 运行 mail 测试确认 GREEN**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/mail -count=1
```

Expected:

```text
ok  	admin_back_go/internal/module/mail
```

- [ ] **Step 7: 提交 mail 改动**

```powershell
git add internal/module/mail/model.go internal/module/mail/repository.go internal/module/mail/service.go internal/module/mail/service_test.go
git commit -m "fix: store mail verify code ttl in mail config"
```

---

## Task 4: 让 sms 配置真正持有 TTL

**Files:**

- Modify: `admin_back_go/internal/module/sms/model.go`
- Modify: `admin_back_go/internal/module/sms/repository.go`
- Modify: `admin_back_go/internal/module/sms/service.go`
- Modify: `admin_back_go/internal/module/sms/service_test.go`

- [ ] **Step 1: 写 sms RED 测试**

在 `admin_back_go/internal/module/sms/service_test.go` 新增：

```go
func TestServiceSaveConfigPersistsVerifyCodeTTLToSmsConfig(t *testing.T) {
	repo := newFakeRepository()
	service := NewService(repo, fakeSecretBox{}, fakeSender{})

	appErr := service.SaveConfig(context.Background(), SaveConfigInput{
		SecretID: "AKID", SecretKey: "SECRET", SmsSdkAppID: "1400000000", SignName: "签名",
		Region: DefaultRegion, Endpoint: DefaultEndpoint, Status: enum.CommonYes, VerifyCodeTTLMinutes: 12,
	})
	if appErr != nil {
		t.Fatalf("SaveConfig returned error: %v", appErr)
	}
	if repo.config == nil || repo.config.VerifyCodeTTLMinutes != 12 {
		t.Fatalf("expected sms config TTL 12, got %#v", repo.config)
	}
	if repo.savedSetting != nil {
		t.Fatalf("sms config must not write system setting, got %#v", repo.savedSetting)
	}
}

func TestServiceVerifyCodeTTLReadsSmsConfig(t *testing.T) {
	repo := newFakeRepository()
	repo.config = &Config{ConfigKey: defaultConfigKey, VerifyCodeTTLMinutes: 14, Status: enum.CommonYes, IsDel: enum.CommonNo}
	service := NewService(repo, fakeSecretBox{}, fakeSender{})

	ttl, appErr := service.VerifyCodeTTL(context.Background())
	if appErr != nil || ttl != 14*time.Minute {
		t.Fatalf("expected 14m TTL, got %s err=%v", ttl, appErr)
	}
}
```

- [ ] **Step 2: 运行测试确认 RED**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/sms -run "SaveConfigPersistsVerifyCodeTTLToSmsConfig|VerifyCodeTTLReadsSmsConfig" -count=1
```

Expected:

```text
FAIL
Config has no field VerifyCodeTTLMinutes
service.VerifyCodeTTL undefined
```

- [ ] **Step 3: 修改 sms model / repository / service**

按 mail 的同样方式修改，但字段放在 `Endpoint` 后、`Status` 前：

```go
VerifyCodeTTLMinutes int `gorm:"column:verify_code_ttl_minutes"`
```

`SaveDefaultConfig` fields map 加：

```go
"verify_code_ttl_minutes": row.VerifyCodeTTLMinutes,
```

`sms.Service.Config()` 从 `row.VerifyCodeTTLMinutes` 返回 TTL。

`sms.Service.SaveConfig()` 不再写 `system_settings`。

`sms.Service.TestSend()` 里的：

```go
ttl, appErr := s.configuredVerifyCodeTTL(ctx, repo)
```

改成：

```go
ttl, appErr := s.configuredVerifyCodeTTLFromConfig(ctx, repo)
```

新增 helper：

```go
func (s *Service) configuredVerifyCodeTTLFromConfig(ctx context.Context, repo Repository) (int, *apperror.Error) {
	row, err := repo.DefaultConfig(ctx)
	if err != nil {
		return 0, wrapInternal("sms.config.query_failed", "查询短信配置失败", err)
	}
	if row == nil {
		return defaultVerifyCodeTTLMin, nil
	}
	return normalizeVerifyCodeTTLMinutes(row.VerifyCodeTTLMinutes)
}

func (s *Service) VerifyCodeTTL(ctx context.Context) (time.Duration, *apperror.Error) {
	repo, appErr := s.requireRepository()
	if appErr != nil {
		return 0, appErr
	}
	minutes, appErr := s.configuredVerifyCodeTTLFromConfig(ctx, repo)
	if appErr != nil {
		return 0, appErr
	}
	return time.Duration(minutes) * time.Minute, nil
}
```

删除 `SettingByKey` / `SaveSetting` / `InvalidateSettingCache` 相关接口、实现和 imports。

- [ ] **Step 4: 运行 sms 测试确认 GREEN**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/sms -count=1
```

Expected:

```text
ok  	admin_back_go/internal/module/sms
```

- [ ] **Step 5: 提交 sms 改动**

```powershell
git add internal/module/sms/model.go internal/module/sms/repository.go internal/module/sms/service.go internal/module/sms/service_test.go
git commit -m "fix: store sms verify code ttl in sms config"
```

---

## Task 5: 实现 auth 渠道 TTL policy 并接入 bootstrap

**Files:**

- Create: `admin_back_go/internal/module/auth/channel_verify_code_policy.go`
- Modify: `admin_back_go/internal/module/auth/service.go`
- Modify: `admin_back_go/internal/module/auth/verify_code_policy.go`
- Modify: `admin_back_go/internal/bootstrap/app.go`

- [ ] **Step 1: 新增 channel policy 实现**

创建 `admin_back_go/internal/module/auth/channel_verify_code_policy.go`：

```go
package auth

import (
	"context"
	"time"

	"admin_back_go/internal/apperror"
	"admin_back_go/internal/enum"
)

type VerifyCodeTTLProvider interface {
	VerifyCodeTTL(ctx context.Context) (time.Duration, *apperror.Error)
}

type ChannelVerifyCodePolicyProvider struct {
	email VerifyCodeTTLProvider
	phone VerifyCodeTTLProvider
}

func NewChannelVerifyCodePolicyProvider(email VerifyCodeTTLProvider, phone VerifyCodeTTLProvider) *ChannelVerifyCodePolicyProvider {
	return &ChannelVerifyCodePolicyProvider{email: email, phone: phone}
}

func (p *ChannelVerifyCodePolicyProvider) VerifyCodeTTL(ctx context.Context, accountType string) (time.Duration, *apperror.Error) {
	if p == nil {
		return 0, apperror.Internal("验证码策略未配置")
	}
	switch accountType {
	case enum.LoginTypeEmail:
		if p.email == nil {
			return 0, apperror.Internal("邮件验证码策略未配置")
		}
		return p.email.VerifyCodeTTL(ctx)
	case enum.LoginTypePhone:
		if p.phone == nil {
			return 0, apperror.Internal("短信验证码策略未配置")
		}
		return p.phone.VerifyCodeTTL(ctx)
	default:
		return 0, apperror.BadRequest("无效的验证码账号类型")
	}
}
```

- [ ] **Step 2: 修改 auth policy interface 和调用点**

在 `admin_back_go/internal/module/auth/verify_code_policy.go` 中把 active interface 改成：

```go
type VerifyCodePolicyProvider interface {
	VerifyCodeTTL(ctx context.Context, accountType string) (time.Duration, *apperror.Error)
}
```

删除 `VerifyCodeTTLSettingKey`、`VerifyCodePolicyRepository` 和 `SystemSettingVerifyCodePolicyProvider` 相关实现，或把文件只保留 interface。推荐保留文件为接口定义，避免调用点大范围移动。

在 `admin_back_go/internal/module/auth/service.go`：

```go
ttl, appErr := s.verifyCodeTTL(ctx, accountType)
```

把 helper 改成：

```go
func (s *Service) verifyCodeTTL(ctx context.Context, accountType string) (time.Duration, *apperror.Error) {
	if s != nil && s.verifyCodePolicy != nil {
		return s.verifyCodePolicy.VerifyCodeTTL(ctx, accountType)
	}
	return s.verifyCodeOptions.TTL, nil
}
```

- [ ] **Step 3: 修改 bootstrap 注入**

在 `admin_back_go/internal/bootstrap/app.go` 把：

```go
auth.WithVerifyCodePolicyProvider(auth.NewSystemSettingVerifyCodePolicyProvider(systemSettingRepository)),
```

改成：

```go
auth.WithVerifyCodePolicyProvider(auth.NewChannelVerifyCodePolicyProvider(mailService, smsService)),
```

- [ ] **Step 4: 运行 auth/bootstrap 测试确认 GREEN**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/auth ./internal/bootstrap -count=1
```

Expected:

```text
ok  	admin_back_go/internal/module/auth
ok  	admin_back_go/internal/bootstrap
```

- [ ] **Step 5: 提交 auth policy 改动**

```powershell
git add internal/module/auth/channel_verify_code_policy.go internal/module/auth/service.go internal/module/auth/verify_code_policy.go internal/bootstrap/app.go
git commit -m "fix: read verify code ttl by delivery channel"
```

---

## Task 6: 更新前端文案和 contract tests

**Files:**

- Modify: `admin_front_ts/src/i18n/locales/zh-CN.ts`
- Modify: `admin_front_ts/src/i18n/locales/en-US.ts`
- Modify: `admin_front_ts/tests/shared/system/mail-api.test.ts`
- Modify: `admin_front_ts/tests/shared/system/sms-api.test.ts`

- [ ] **Step 1: 修改中文文案**

在 `admin_front_ts/src/i18n/locales/zh-CN.ts`：

邮件配置的 `verifyCodeTTLHelp` 改成：

```ts
verifyCodeTTLHelp: '邮件验证码有效期；模板变量 ttl_minutes 自动取这个值。',
```

短信配置的 `verifyCodeTTLHelp` 改成：

```ts
verifyCodeTTLHelp: '短信验证码有效期；模板变量 ttl_minutes 自动取这个值。',
```

- [ ] **Step 2: 修改英文文案**

在 `admin_front_ts/src/i18n/locales/en-US.ts`：

邮件配置的 `verifyCodeTTLHelp` 改成：

```ts
verifyCodeTTLHelp: 'Email verification-code TTL. The ttl_minutes template variable uses this value.',
```

短信配置的 `verifyCodeTTLHelp` 改成：

```ts
verifyCodeTTLHelp: 'SMS verification-code TTL. The ttl_minutes template variable uses this value.',
```

- [ ] **Step 3: 加 contract 文案守卫**

在 `admin_front_ts/tests/shared/system/mail-api.test.ts` 增加：

```ts
it('does not describe mail verify-code ttl as shared with sms', () => {
  const zh = readFileSync(resolve(projectRoot, 'src/i18n/locales/zh-CN.ts'), 'utf8')
  const en = readFileSync(resolve(projectRoot, 'src/i18n/locales/en-US.ts'), 'utf8')
  expect(zh).toContain('邮件验证码有效期')
  expect(zh).not.toContain('邮件和短信验证码共用')
  expect(en).toContain('Email verification-code TTL')
  expect(en).not.toContain('Shared by email and SMS verification')
})
```

在 `admin_front_ts/tests/shared/system/sms-api.test.ts` 增加：

```ts
it('does not describe sms verify-code ttl as shared with mail', () => {
  const zh = readFileSync(resolve(projectRoot, 'src/i18n/locales/zh-CN.ts'), 'utf8')
  const en = readFileSync(resolve(projectRoot, 'src/i18n/locales/en-US.ts'), 'utf8')
  expect(zh).toContain('短信验证码有效期')
  expect(zh).not.toContain('邮件和短信验证码共用')
  expect(en).toContain('SMS verification-code TTL')
  expect(en).not.toContain('Shared by email and SMS verification')
})
```

如果测试文件尚未 import `readFileSync` / `resolve` / `projectRoot`，按现有 mail/sms API test 文件顶部风格补齐，不引入 `any`。

- [ ] **Step 4: 运行前端测试**

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/system/mail-api.test.ts tests/shared/system/sms-api.test.ts
npx vue-tsc -b --pretty false
```

Expected:

```text
Vitest PASS
vue-tsc PASS
```

- [ ] **Step 5: 提交前端文案**

```powershell
git add src/i18n/locales/zh-CN.ts src/i18n/locales/en-US.ts tests/shared/system/mail-api.test.ts tests/shared/system/sms-api.test.ts
git commit -m "fix: describe verify code ttl per delivery channel"
```

---

## Task 7: 更新 contract、status、部署和 smoke 文档

**Files:**

- Modify: `docs/status/current-status.md`
- Modify: `docs/contracts/admin-api-v1.md`
- Modify: `admin_back_go/docs/architecture.md`
- Modify: `docs/testing/smoke-matrix.md`
- Modify: `docs/deployment/docker-first-backend.md`
- Modify: `docs/deployment/production.md`

- [ ] **Step 1: 更新 API contract**

在 `docs/contracts/admin-api-v1.md` 的 mail rules 中把：

```text
ttl_minutes comes from system_settings.auth.verify_code.ttl_minutes and is shared by email verification and future SMS verification.
```

替换为：

```text
ttl_minutes for email verification comes from mail_configs.verify_code_ttl_minutes. It is not shared with SMS.
```

把 `/mail/config` 说明改成：

```text
PUT /mail/config accepts verify_code_ttl_minutes: number; the value is saved to mail_configs.verify_code_ttl_minutes, not system_settings.
```

在 sms rules 中把对应描述替换为：

```text
ttl_minutes for SMS verification comes from sms_configs.verify_code_ttl_minutes. It is not shared with mail.
```

和：

```text
PUT /sms/config accepts verify_code_ttl_minutes: number; the value is saved to sms_configs.verify_code_ttl_minutes, not system_settings.
```

- [ ] **Step 2: 更新 current-status**

在 `docs/status/current-status.md` 的 mail 行改成：

```text
reads verification-code TTL from mail_configs.verify_code_ttl_minutes; Redis namespace auth:verify_code: is code-owned
```

在 sms 行改成：

```text
uses sms_configs.verify_code_ttl_minutes for SMS/test-send ttl_minutes; auth/send-code phone remains fixed 123456 and uses the SMS TTL only for Redis expiry
```

- [ ] **Step 3: 更新 architecture / deployment 文档**

在 `admin_back_go/docs/architecture.md` 的 typed config / module boundary 附近加入：

```text
验证码 TTL 不再由 system_settings.auth.verify_code.ttl_minutes 统一管理。邮件验证码 TTL 属于 mail_configs.verify_code_ttl_minutes，短信验证码 TTL 属于 sms_configs.verify_code_ttl_minutes；system_settings 不承担跨渠道验证码策略。
```

在 `docs/deployment/docker-first-backend.md` 和 `docs/deployment/production.md` 删除“验证码有效期来自 DB 配置 system_settings.auth.verify_code.ttl_minutes”的说法，改成：

```text
验证码 Redis namespace auth:verify_code: 由代码内置。邮件验证码 TTL 在邮件管理配置，短信验证码 TTL 在短信管理配置；它们不是 Docker env，也不是 system_settings 全局项。
```

- [ ] **Step 4: 更新 smoke matrix**

在 `docs/testing/smoke-matrix.md` 中保留 send-code 行，但说明：

```text
手机号验证码固定 123456；TTL 来自短信配置。邮箱验证码走 Tencent SES；TTL 来自邮件配置。默认 smoke 不真实发送邮箱/短信。
```

- [ ] **Step 5: 文档扫描**

```powershell
cd E:\admin_go
rg -n "auth\.verify_code\.ttl_minutes|邮件和短信验证码共用|Shared by email and SMS verification|system_settings\.auth\.verify_code" docs admin_back_go\docs admin_front_ts\src admin_front_ts\tests admin_back_go\internal
```

Expected:

```text
只允许历史 spec/archive 或本次迁移 SQL 提到 auth.verify_code.ttl_minutes；active status/contract/frontend/runtime docs 不再把它当事实源。
```

- [ ] **Step 6: 提交文档**

```powershell
git add docs/status/current-status.md docs/contracts/admin-api-v1.md admin_back_go/docs/architecture.md docs/testing/smoke-matrix.md docs/deployment/docker-first-backend.md docs/deployment/production.md
git commit -m "docs: document channel-specific verify code ttl"
```

---

## Task 8: 本地 migration 和 runtime 验证

**Files:** 无源码新增，除非验证暴露具体失败。

- [ ] **Step 1: 在本地 DB 应用 migration**

```powershell
cd E:\admin_go\admin_back_go
mysql --host=127.0.0.1 --port=3307 --protocol=tcp --user=root --password=admin_go_local --database=admin < .\database\migrations\20260527_channel_verify_code_ttl.sql
```

Expected:

```text
命令退出码 0。
```

- [ ] **Step 2: 验证 live schema 和旧 setting 退场**

```powershell
mysql --host=127.0.0.1 --port=3307 --protocol=tcp --user=root --password=admin_go_local --database=admin -N -e "SELECT table_name,column_name FROM information_schema.columns WHERE table_schema=DATABASE() AND table_name IN ('mail_configs','sms_configs') AND column_name='verify_code_ttl_minutes' ORDER BY table_name; SELECT setting_key,status,is_del FROM system_settings WHERE setting_key='auth.verify_code.ttl_minutes';"
```

Expected:

```text
mail_configs    verify_code_ttl_minutes
sms_configs     verify_code_ttl_minutes
auth.verify_code.ttl_minutes    2    1
```

- [ ] **Step 3: 运行后端目标测试**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/mail ./internal/module/sms ./internal/module/auth ./internal/bootstrap ./internal/server -count=1
```

Expected:

```text
所有 package PASS。
```

- [ ] **Step 4: 运行前端目标测试**

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/system/mail-api.test.ts tests/shared/system/sms-api.test.ts
npx vue-tsc -b --pretty false
```

Expected:

```text
Vitest PASS。
vue-tsc PASS。
```

- [ ] **Step 5: 可选 smoke read gate**

如果本地 backend 已启动：

```powershell
cd E:\admin_go\admin_back_go
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account 15671628271 -Password 123456
```

Expected:

```text
mail/sms page-init/config/templates/logs read-only probes PASS。
默认 smoke 不真实发送 Tencent SES/SMS。
```

---

## Task 9: 全量收尾检查

**Files:** 无源码新增，除非检查暴露具体失败。

- [ ] **Step 1: 后端完整测试**

```powershell
cd E:\admin_go\admin_back_go
go test ./... -count=1
```

Expected:

```text
所有 package PASS。
```

- [ ] **Step 2: 前端构建检查**

```powershell
cd E:\admin_go\admin_front_ts
npm run build:check
```

Expected:

```text
build check PASS。
```

- [ ] **Step 3: 根 repo 治理检查**

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected:

```text
working diff check passed
no blocking governance violations found
```

- [ ] **Step 4: 变更摘要**

```powershell
cd E:\admin_go
git status --short
git diff --stat
```

Expected:

```text
只包含本切片相关文件；没有 .codex/hooks.json 或 .codex/hooks/*.ps1 改动。
```

---

## Self-review checklist

- Spec coverage：schema、mail/sms config、auth TTL policy、frontend copy、contract/status/deployment docs、live DB 验证均有任务覆盖。
- 占位扫描：未发现未明确的实施项或空泛步骤。
- Type consistency：`VerifyCodeTTL(ctx context.Context)`、`VerifyCodeTTL(ctx context.Context, accountType string)`、`VerifyCodeTTLMinutes` 字段名在各任务中一致。
- Scope control：没有把手机号验证码接入真实短信发送，没有新增系统设置分类框架，没有改 token/captcha/auth_platforms 策略。

