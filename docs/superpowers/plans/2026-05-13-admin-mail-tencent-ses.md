# Admin Mail Tencent SES Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Tencent Cloud SES mail management, wire real email verification-code sending into `auth/send-code`, and expose `/system/mail` in the admin frontend.

**Architecture:** `internal/module/mail` owns mail config, Tencent template mapping, logs, and verify-code send orchestration. `internal/platform/mail/tencentcloudses` is the only package that imports Tencent Cloud SDK. `auth.Service` depends only on a tiny `VerifyCodeMailSender` interface, so auth does not import the mail module or Tencent SDK.

**Tech Stack:** Go 1.26, Gin, GORM/MySQL, Redis verify-code cache, existing `secretbox` derived from `APP_SECRET`, Tencent Cloud Go SDK `github.com/tencentcloud/tencentcloud-sdk-go/tencentcloud/ses/v20201002`, Vue 3 `<script setup lang="ts">`, Element Plus, Vitest, PowerShell smoke scripts.

---

## Source Spec

Read first:

```text
E:/admin_go/docs/superpowers/specs/2026-05-13-admin-mail-tencent-ses-design.md
```

Hard rules:

```text
Only Tencent Cloud SES API.
No SMTP.
No self-hosted mail server.
No multi-provider abstraction.
Tencent SecretId/SecretKey are encrypted in DB with secretbox, never stored in .env.
mail_configs / mail_templates / mail_logs all include is_del.
Every read path filters is_del=2.
Every table field must have a real usage path.
Mail logs never store email body, verify code, or full TemplateData.
VERIFY_CODE_DEV_MODE=true behavior stays unchanged.
Phone real-mode branch still returns SMS-not-configured.
Page-init follows the existing project convention: response payload is `data.dict`, not a flat `data` object.
```

---

## File Structure

### Create

```text
admin_back_go/database/migrations/20260513_mail_tencent_ses.sql
admin_back_go/internal/enum/mail.go
admin_back_go/internal/dict/mail.go
admin_back_go/internal/platform/mail/tencentcloudses/client.go
admin_back_go/internal/platform/mail/tencentcloudses/client_test.go
admin_back_go/internal/module/mail/model.go
admin_back_go/internal/module/mail/dto.go
admin_back_go/internal/module/mail/request.go
admin_back_go/internal/module/mail/errors.go
admin_back_go/internal/module/mail/repository.go
admin_back_go/internal/module/mail/service.go
admin_back_go/internal/module/mail/handler.go
admin_back_go/internal/module/mail/route.go
admin_back_go/internal/module/mail/service_test.go
admin_back_go/internal/module/mail/handler_test.go
admin_front_ts/src/api/system/mail.ts
admin_front_ts/src/views/Main/system/mail/index.vue
admin_front_ts/src/views/Main/system/mail/components/MailConfigPanel.vue
admin_front_ts/src/views/Main/system/mail/components/MailTemplatePanel.vue
admin_front_ts/src/views/Main/system/mail/components/MailLogPanel.vue
admin_front_ts/tests/shared/system/mail-api.test.ts
```

### Modify

```text
admin_back_go/go.mod
admin_back_go/go.sum
admin_back_go/internal/module/auth/service.go
admin_back_go/internal/module/auth/service_test.go
admin_back_go/internal/bootstrap/app.go
admin_back_go/internal/bootstrap/route_meta.go
admin_back_go/internal/bootstrap/route_meta_test.go
admin_back_go/internal/server/router.go
admin_back_go/internal/server/router_test.go
admin_back_go/scripts/full-admin-smoke.ps1
admin_back_go/docs/architecture.md
admin_front_ts/src/i18n/locales/zh-CN.ts
admin_front_ts/src/i18n/locales/en-US.ts
docs/contracts/admin-api-v1.md
docs/migration/current-status.md
docs/testing/smoke-matrix.md
```

---

## Task 1: Add DB schema and mail menu/permissions

**Files:**

- Create: `E:/admin_go/admin_back_go/database/migrations/20260513_mail_tencent_ses.sql`

- [ ] **Step 1: Create migration with the three tables**

Create `20260513_mail_tencent_ses.sql` with:

```sql
CREATE TABLE IF NOT EXISTS `mail_configs` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `config_key` VARCHAR(32) NOT NULL DEFAULT 'default',
  `secret_id_enc` TEXT NOT NULL,
  `secret_id_hint` VARCHAR(64) NOT NULL DEFAULT '',
  `secret_key_enc` TEXT NOT NULL,
  `secret_key_hint` VARCHAR(64) NOT NULL DEFAULT '',
  `region` VARCHAR(64) NOT NULL DEFAULT 'ap-guangzhou',
  `endpoint` VARCHAR(128) NOT NULL DEFAULT 'ses.tencentcloudapi.com',
  `from_email` VARCHAR(255) NOT NULL,
  `from_name` VARCHAR(100) NOT NULL DEFAULT '',
  `reply_to` VARCHAR(255) NOT NULL DEFAULT '',
  `status` TINYINT UNSIGNED NOT NULL DEFAULT 2,
  `is_del` TINYINT UNSIGNED NOT NULL DEFAULT 2,
  `last_test_at` DATETIME NULL,
  `last_test_error` VARCHAR(500) NOT NULL DEFAULT '',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_mail_configs_config_key` (`config_key`),
  KEY `idx_mail_configs_status_del` (`status`, `is_del`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mail_templates` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `scene` VARCHAR(32) NOT NULL,
  `name` VARCHAR(100) NOT NULL,
  `subject` VARCHAR(200) NOT NULL,
  `tencent_template_id` BIGINT UNSIGNED NOT NULL,
  `variables_json` JSON NOT NULL,
  `sample_variables_json` JSON NOT NULL,
  `status` TINYINT UNSIGNED NOT NULL DEFAULT 1,
  `is_del` TINYINT UNSIGNED NOT NULL DEFAULT 2,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_mail_templates_scene` (`scene`),
  KEY `idx_mail_templates_status_del` (`status`, `is_del`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mail_logs` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `scene` VARCHAR(32) NOT NULL,
  `template_id` BIGINT UNSIGNED NULL,
  `to_email` VARCHAR(255) NOT NULL,
  `subject` VARCHAR(200) NOT NULL DEFAULT '',
  `tencent_request_id` VARCHAR(128) NOT NULL DEFAULT '',
  `tencent_message_id` VARCHAR(128) NOT NULL DEFAULT '',
  `status` TINYINT UNSIGNED NOT NULL,
  `is_del` TINYINT UNSIGNED NOT NULL DEFAULT 2,
  `error_code` VARCHAR(128) NOT NULL DEFAULT '',
  `error_message` VARCHAR(500) NOT NULL DEFAULT '',
  `duration_ms` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `sent_at` DATETIME NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_mail_logs_scene_created` (`is_del`, `scene`, `created_at`),
  KEY `idx_mail_logs_status_created` (`is_del`, `status`, `created_at`),
  KEY `idx_mail_logs_to_email_created` (`is_del`, `to_email`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

- [ ] **Step 2: Add menu and button permissions in the same migration**

Use this permission shape:

```text
PAGE: system_mail, path=/system/mail, component=system/mail, i18n_key=menu.system_mail
BUTTON:
  system_mail_configEdit
  system_mail_configDel
  system_mail_test
  system_mail_templateAdd
  system_mail_templateEdit
  system_mail_templateStatus
  system_mail_templateDel
  system_mail_logDel
```

Parent lookup must be robust:

```sql
SET @system_parent_id := (
  SELECT `id`
  FROM `permissions`
  WHERE `platform` = 'admin'
    AND `type` = 1
    AND `is_del` = 2
    AND (`i18n_key` = 'menu.system' OR `path` = '/system' OR `code` = 'system')
  ORDER BY `id`
  LIMIT 1
);
```

Grant the mail page/buttons to roles that already hold `system_setting_edit` or `system_uploadConfig_settingEdit`.

- [ ] **Step 3: Static verify and commit**

Run:

```powershell
cd E:/admin_go
git diff --check -- admin_back_go/database/migrations/20260513_mail_tencent_ses.sql
rg -n "mail_configs|mail_templates|mail_logs|system_mail|is_del" admin_back_go/database/migrations/20260513_mail_tencent_ses.sql
git add admin_back_go/database/migrations/20260513_mail_tencent_ses.sql
git commit -m "feat: add mail ses schema and permissions"
```

Expected: `git diff --check` exits 0; `rg` shows all three tables, every `system_mail*` code, and `is_del` in every table.

---

## Task 2: Add backend mail domain and repository

**Files:**

- Create: `admin_back_go/internal/enum/mail.go`
- Create: `admin_back_go/internal/dict/mail.go`
- Create: `admin_back_go/internal/module/mail/model.go`
- Create: `admin_back_go/internal/module/mail/dto.go`
- Create: `admin_back_go/internal/module/mail/request.go`
- Create: `admin_back_go/internal/module/mail/errors.go`
- Create: `admin_back_go/internal/module/mail/repository.go`
- Create: `admin_back_go/internal/module/mail/domain_test.go`
- Create: `admin_back_go/internal/module/mail/repository_test.go`

- [ ] **Step 1: Write failing field-contract tests**

Create domain/repository tests with these test names and assertions:

```go
func TestMailDictsReturnRequiredValues(t *testing.T)
func TestMailModelsKeepSoftDeleteFields(t *testing.T)
func TestRepositoryReadContractsRequireIsDelFilter(t *testing.T)
func TestRepositorySaveDefaultConfigRestoresSoftDeletedDefault(t *testing.T)
func TestRepositorySaveTemplateRestoresSoftDeletedScene(t *testing.T)
func TestRepositoryListLogsFiltersSoftDeletedRows(t *testing.T)
```

The assertions must prove:

```text
mail scene dict count = 4.
mail log scene dict count = 5.
mail log status dict count = 3.
Config / Template / Log structs all expose IsDel.
active repository read methods use is_del=2.
soft-deleted default config is restored instead of inserting a duplicate.
soft-deleted template with the same scene is restored instead of inserting a duplicate.
soft-deleted logs do not appear in list/detail responses.
```

- [ ] **Step 2: Run failing tests**

Run:

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/module/mail
```

Expected: FAIL because package `mail` is incomplete.

- [ ] **Step 3: Implement enum and dict**

Create `internal/enum/mail.go`:

```go
package enum

const (
	MailLogStatusPending = 1
	MailLogStatusSuccess = 2
	MailLogStatusFailed  = 3
	MailSceneTest        = "test"
)

func IsMailLogStatus(value int) bool {
	return value == MailLogStatusPending || value == MailLogStatusSuccess || value == MailLogStatusFailed
}

func IsMailTemplateScene(value string) bool {
	switch value {
	case VerifyCodeSceneLogin, VerifyCodeSceneForget, VerifyCodeSceneBindEmail, VerifyCodeSceneChangePassword:
		return true
	default:
		return false
	}
}

func IsMailLogScene(value string) bool {
	return IsMailTemplateScene(value) || value == MailSceneTest
}
```

Create `internal/dict/mail.go`:

```go
package dict

import "admin_back_go/internal/enum"

func MailSceneOptions() []Option[string] {
	return []Option[string]{
		{Label: "邮箱验证码登录", Value: enum.VerifyCodeSceneLogin},
		{Label: "找回密码", Value: enum.VerifyCodeSceneForget},
		{Label: "绑定/换绑邮箱", Value: enum.VerifyCodeSceneBindEmail},
		{Label: "验证码改密", Value: enum.VerifyCodeSceneChangePassword},
	}
}

func MailLogSceneOptions() []Option[string] {
	return append(MailSceneOptions(), Option[string]{Label: "测试发送", Value: enum.MailSceneTest})
}

func MailLogStatusOptions() []Option[int] {
	return []Option[int]{
		{Label: "发送中", Value: enum.MailLogStatusPending},
		{Label: "发送成功", Value: enum.MailLogStatusSuccess},
		{Label: "发送失败", Value: enum.MailLogStatusFailed},
	}
}
```

- [ ] **Step 4: Implement models, DTOs, and repository**

Model structs must exactly cover all schema fields:

```text
Config: ID, ConfigKey, SecretIDEnc, SecretIDHint, SecretKeyEnc, SecretKeyHint, Region, Endpoint, FromEmail, FromName, ReplyTo, Status, IsDel, LastTestAt, LastTestError, CreatedAt, UpdatedAt.
Template: ID, Scene, Name, Subject, TencentTemplateID, VariablesJSON, SampleVariablesJSON, Status, IsDel, CreatedAt, UpdatedAt.
Log: ID, Scene, TemplateID, ToEmail, Subject, TencentRequestID, TencentMessageID, Status, IsDel, ErrorCode, ErrorMessage, DurationMS, SentAt, CreatedAt, UpdatedAt.
```

Repository interface:

```go
type Repository interface {
	DefaultConfig(ctx context.Context) (*Config, error)
	SaveDefaultConfig(ctx context.Context, row Config) error
	SoftDeleteDefaultConfig(ctx context.Context) error
	ListTemplates(ctx context.Context) ([]Template, error)
	TemplateByID(ctx context.Context, id uint64) (*Template, error)
	TemplateByScene(ctx context.Context, scene string) (*Template, error)
	SaveTemplate(ctx context.Context, row Template) (uint64, error)
	UpdateTemplate(ctx context.Context, id uint64, update TemplateUpdate) error
	SoftDeleteTemplate(ctx context.Context, id uint64) error
	CreateLog(ctx context.Context, row Log) (uint64, error)
	FinishLog(ctx context.Context, id uint64, finish LogFinish) error
	ListLogs(ctx context.Context, query LogQuery) ([]Log, int64, error)
	LogByID(ctx context.Context, id uint64) (*Log, error)
	SoftDeleteLogs(ctx context.Context, ids []uint64) error
}
```

Typed update DTOs:

```go
type TemplateUpdate struct {
	Scene               string
	Name                string
	Subject             string
	TencentTemplateID   uint64
	VariablesJSON       string
	SampleVariablesJSON string
	Status              int
}

type LogFinish struct {
	Status           int
	RequestID        string
	MessageID        string
	ErrorCode        string
	ErrorMessage     string
	DurationMS       uint64
	SentAt           *time.Time
}
```

Every active repository read/update/delete method must include:

```go
Where("is_del = ?", enum.CommonNo)
```

`SaveDefaultConfig` must restore and overwrite the soft-deleted `config_key=default` row instead of creating duplicate active default rows.
`SaveTemplate` must restore and overwrite a soft-deleted row with the same `scene` instead of creating a duplicate or failing on `uk_mail_templates_scene`.

- [ ] **Step 5: Run focused tests and commit**

Run:

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/enum ./internal/dict ./internal/module/mail
```

Expected: tests pass. Do not commit a package that still has compile failures.

```powershell
cd E:/admin_go
git add admin_back_go/internal/enum/mail.go admin_back_go/internal/dict/mail.go admin_back_go/internal/module/mail
git commit -m "feat: add mail domain repository"
```

---

## Task 3: Add Tencent SES platform client

**Files:**

- Modify: `admin_back_go/go.mod`
- Modify: `admin_back_go/go.sum`
- Create: `admin_back_go/internal/platform/mail/tencentcloudses/client.go`
- Create: `admin_back_go/internal/platform/mail/tencentcloudses/client_test.go`

- [ ] **Step 1: Add SDK**

Run:

```powershell
cd E:/admin_go/admin_back_go
go get github.com/tencentcloud/tencentcloud-sdk-go@latest
```

- [ ] **Step 2: Write client mapping tests**

Create tests:

```go
func TestBuildFromEmailAddress(t *testing.T) {
	if got := BuildFromEmailAddress("noreply@example.com", "Admin"); got != "Admin <noreply@example.com>" {
		t.Fatalf("unexpected from address: %q", got)
	}
	if got := BuildFromEmailAddress("noreply@example.com", ""); got != "noreply@example.com" {
		t.Fatalf("unexpected bare from address: %q", got)
	}
}

func TestTemplateDataJSONIsStable(t *testing.T) {
	got, err := TemplateDataJSON(map[string]string{"ttl_minutes":"5", "code":"123456", "app_name":"admin_go"})
	if err != nil {
		t.Fatalf("TemplateDataJSON returned error: %v", err)
	}
	if got != `{"app_name":"admin_go","code":"123456","ttl_minutes":"5"}` {
		t.Fatalf("unexpected template data: %s", got)
	}
}
```

- [ ] **Step 3: Implement wrapper**

`client.go` must expose:

```go
type SendInput struct {
	SecretID string
	SecretKey string
	Region string
	Endpoint string
	FromEmail string
	FromName string
	ReplyTo string
	ToEmail string
	Subject string
	TemplateID uint64
	TemplateData map[string]string
}

type SendResult struct {
	RequestID string
	MessageID string
}

type Client struct { Timeout time.Duration }
func New(timeout time.Duration) *Client
func BuildFromEmailAddress(email string, name string) string
func TemplateDataJSON(values map[string]string) (string, error)
func (c *Client) Send(ctx context.Context, input SendInput) (SendResult, error)
```

`Send` must map:

```text
FromEmailAddress = BuildFromEmailAddress(input.FromEmail, input.FromName)
Destination = []string{input.ToEmail}
Subject = input.Subject
Template.TemplateID = input.TemplateID
Template.TemplateData = TemplateDataJSON(input.TemplateData)
TriggerType = 1
ReplyToAddresses = input.ReplyTo when non-empty
```

- [ ] **Step 4: Run tests and commit**

Run:

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/platform/mail/tencentcloudses
cd E:/admin_go
git add admin_back_go/go.mod admin_back_go/go.sum admin_back_go/internal/platform/mail/tencentcloudses
git commit -m "feat: add tencent ses mail client"
```

Expected: tests pass and commit succeeds.

---

## Task 4: Implement mail service business rules

**Files:**

- Modify: `admin_back_go/internal/module/mail/service.go`
- Modify: `admin_back_go/internal/module/mail/service_test.go`

- [ ] **Step 1: Complete service tests**

Add test coverage for:

```text
PageInit dicts.
SaveConfig encrypts secrets and returns hints.
SaveConfig keeps old encrypted secrets when secret_id/secret_key inputs are blank.
SaveTemplate rejects missing sample_variables.
SendVerifyCode fails when config is missing.
SendVerifyCode fails when config status=2.
SendVerifyCode fails when template is missing.
SendVerifyCode fails when template status=2.
SendVerifyCode writes a success log with RequestId/MessageId and without code/TemplateData.
SendVerifyCode writes a failed log with error_code/error_message and without code/TemplateData.
TestSend uses the template sample_variables, writes scene=test logs, updates last_test_at, clears last_test_error on success, and writes last_test_error on failure.
DeleteConfig/Template/Logs call soft-delete repository methods.
```

- [ ] **Step 2: Implement service public surface**

`service.go` must expose:

```go
type Sender interface {
	Send(ctx context.Context, input SendInput) (SendResult, error)
}

type SenderFunc func(ctx context.Context, input SendInput) (SendResult, error)

func (fn SenderFunc) Send(ctx context.Context, input SendInput) (SendResult, error) {
	return fn(ctx, input)
}

type SendInput struct {
	SecretID string
	SecretKey string
	Region string
	Endpoint string
	FromEmail string
	FromName string
	ReplyTo string
	ToEmail string
	Subject string
	TemplateID uint64
	TemplateData map[string]string
}

type SendResult struct {
	RequestID string
	MessageID string
}

func NewService(repository Repository, box secretbox.Box, sender Sender) *Service
func (s *Service) PageInit(ctx context.Context) (*PageInitResponse, *apperror.Error)
func (s *Service) Config(ctx context.Context) (*ConfigResponse, *apperror.Error)
func (s *Service) SaveConfig(ctx context.Context, input SaveConfigInput) *apperror.Error
func (s *Service) DeleteConfig(ctx context.Context) *apperror.Error
func (s *Service) TestSend(ctx context.Context, input TestInput) *apperror.Error
func (s *Service) Templates(ctx context.Context) ([]TemplateDTO, *apperror.Error)
func (s *Service) SaveTemplate(ctx context.Context, input SaveTemplateInput) (uint64, *apperror.Error)
func (s *Service) UpdateTemplate(ctx context.Context, id uint64, input SaveTemplateInput) *apperror.Error
func (s *Service) ChangeTemplateStatus(ctx context.Context, id uint64, status int) *apperror.Error
func (s *Service) DeleteTemplate(ctx context.Context, id uint64) *apperror.Error
func (s *Service) Logs(ctx context.Context, query LogQuery) (*LogListResponse, *apperror.Error)
func (s *Service) Log(ctx context.Context, id uint64) (*LogDTO, *apperror.Error)
func (s *Service) DeleteLogs(ctx context.Context, ids []uint64) *apperror.Error
func (s *Service) SendVerifyCode(ctx context.Context, scene string, toEmail string, code string, ttl time.Duration) *apperror.Error
```

- [ ] **Step 3: Implement JSON variable rules**

Helpers:

```go
func encodeVariables(values []string) (string, *apperror.Error)
func decodeVariables(raw string) ([]string, error)
func encodeSampleVariables(values map[string]string, variables []string) (string, *apperror.Error)
func decodeSampleVariables(raw string) (map[string]string, error)
```

Rules:

```text
Trim variable names.
Reject blank variable names.
Reject duplicate variable names.
Require sample_variables to contain every variable key.
Only store JSON generated by json.Marshal.
```

- [ ] **Step 4: Implement send orchestration**

`SendVerifyCode` must:

```text
Load default config using repository method that filters is_del=2.
Require config status=1.
Decrypt SecretId and SecretKey.
Load template by scene using repository method that filters is_del=2.
Require template status=1.
Build TemplateData with code, ttl_minutes, app_name.
Create pending log before Tencent call.
Call sender once with context.
Finish log success with tencent_request_id, tencent_message_id, duration_ms, sent_at.
Finish log failure with error_code, error_message, duration_ms.
Never write code or TemplateData into mail_logs.
```

- [ ] **Step 5: Run tests and commit**

Run:

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/enum ./internal/dict ./internal/module/mail
cd E:/admin_go
git add admin_back_go/internal/enum/mail.go admin_back_go/internal/dict/mail.go admin_back_go/internal/module/mail
git commit -m "feat: implement mail management service"
```

Expected: tests pass and commit succeeds.

---

## Task 5: Add mail HTTP routes, bootstrap wiring, and route metadata

**Files:**

- Create/modify: `admin_back_go/internal/module/mail/request.go`
- Create/modify: `admin_back_go/internal/module/mail/handler.go`
- Create/modify: `admin_back_go/internal/module/mail/route.go`
- Create/modify: `admin_back_go/internal/module/mail/handler_test.go`
- Modify: `admin_back_go/internal/server/router.go`
- Modify: `admin_back_go/internal/server/router_test.go`
- Modify: `admin_back_go/internal/bootstrap/app.go`
- Modify: `admin_back_go/internal/bootstrap/route_meta.go`
- Modify: `admin_back_go/internal/bootstrap/route_meta_test.go`

- [ ] **Step 1: Add failing route metadata tests**

Add permission route cases:

```go
{http.MethodPut, "/api/admin/v1/mail/config", "system_mail_configEdit"},
{http.MethodDelete, "/api/admin/v1/mail/config", "system_mail_configDel"},
{http.MethodPost, "/api/admin/v1/mail/test", "system_mail_test"},
{http.MethodPost, "/api/admin/v1/mail/templates", "system_mail_templateAdd"},
{http.MethodPut, "/api/admin/v1/mail/templates/:id", "system_mail_templateEdit"},
{http.MethodPatch, "/api/admin/v1/mail/templates/:id/status", "system_mail_templateStatus"},
{http.MethodDelete, "/api/admin/v1/mail/templates/:id", "system_mail_templateDel"},
{http.MethodDelete, "/api/admin/v1/mail/logs/:id", "system_mail_logDel"},
{http.MethodDelete, "/api/admin/v1/mail/logs", "system_mail_logDel"},
```

Add read routes to the “must not require button permission” list:

```go
{http.MethodGet, "/api/admin/v1/mail/page-init"},
{http.MethodGet, "/api/admin/v1/mail/config"},
{http.MethodGet, "/api/admin/v1/mail/templates"},
{http.MethodGet, "/api/admin/v1/mail/logs"},
{http.MethodGet, "/api/admin/v1/mail/logs/:id"},
```

Add operation route cases with actions:

```text
update_config, delete_config, test_send, create_template, update_template,
change_template_status, delete_template, delete_log, delete_logs
```

- [ ] **Step 2: Implement request, handler, route**

Route contract:

```text
GET    /api/admin/v1/mail/page-init
GET    /api/admin/v1/mail/config
PUT    /api/admin/v1/mail/config
DELETE /api/admin/v1/mail/config
POST   /api/admin/v1/mail/test
GET    /api/admin/v1/mail/templates
POST   /api/admin/v1/mail/templates
PUT    /api/admin/v1/mail/templates/:id
PATCH  /api/admin/v1/mail/templates/:id/status
DELETE /api/admin/v1/mail/templates/:id
GET    /api/admin/v1/mail/logs
GET    /api/admin/v1/mail/logs/:id
DELETE /api/admin/v1/mail/logs/:id
DELETE /api/admin/v1/mail/logs
```

`route.go`:

```go
func RegisterRoutes(router *gin.Engine, service HTTPService) {
	handler := NewHandler(service)
	group := router.Group("/api/admin/v1/mail")
	group.GET("/page-init", handler.PageInit)
	group.GET("/config", handler.Config)
	group.PUT("/config", handler.SaveConfig)
	group.DELETE("/config", handler.DeleteConfig)
	group.POST("/test", handler.TestSend)
	group.GET("/templates", handler.Templates)
	group.POST("/templates", handler.CreateTemplate)
	group.PUT("/templates/:id", handler.UpdateTemplate)
	group.PATCH("/templates/:id/status", handler.ChangeTemplateStatus)
	group.DELETE("/templates/:id", handler.DeleteTemplate)
	group.GET("/logs", handler.Logs)
	group.GET("/logs/:id", handler.Log)
	group.DELETE("/logs/:id", handler.DeleteLog)
	group.DELETE("/logs", handler.DeleteLogs)
}
```

- [ ] **Step 3: Wire server and bootstrap**

In `internal/server/router.go`:

```text
import internal/module/mail.
Add MailService mail.HTTPService to Dependencies.
Call mail.RegisterRoutes(router, deps.MailService).
```

In `internal/bootstrap/app.go`:

```text
Create mailService after secretBox is created.
Use mail.NewGormRepository(resources.DB).
Use mail.SenderFunc as the explicit adapter around tencentcloudses.New(10*time.Second) so platform DTOs do not leak into module/mail.
Pass MailService: mailService into server.Dependencies.
```

Adapter shape:

```go
sesClient := tencentcloudses.New(10 * time.Second)
mailSender := mail.SenderFunc(func(ctx context.Context, input mail.SendInput) (mail.SendResult, error) {
	result, err := sesClient.Send(ctx, tencentcloudses.SendInput{
		SecretID:     input.SecretID,
		SecretKey:    input.SecretKey,
		Region:       input.Region,
		Endpoint:     input.Endpoint,
		FromEmail:    input.FromEmail,
		FromName:     input.FromName,
		ReplyTo:      input.ReplyTo,
		ToEmail:      input.ToEmail,
		Subject:      input.Subject,
		TemplateID:   input.TemplateID,
		TemplateData: input.TemplateData,
	})
	if err != nil {
		return mail.SendResult{}, err
	}
	return mail.SendResult{RequestID: result.RequestID, MessageID: result.MessageID}, nil
})
```

- [ ] **Step 4: Add route metadata**

In `route_meta.go`, map all mutation routes to `system_mail_*` permissions and operation log titles:

```text
编辑邮件配置
删除邮件配置
发送测试邮件
新增邮件模板
编辑邮件模板
修改邮件模板状态
删除邮件模板
删除邮件日志
批量删除邮件日志
```

- [ ] **Step 5: Run tests and commit**

Run:

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/module/mail ./internal/server ./internal/bootstrap
cd E:/admin_go
git add admin_back_go/internal/module/mail admin_back_go/internal/server admin_back_go/internal/bootstrap
git commit -m "feat: expose mail management api"
```

Expected: tests pass and commit succeeds.

---

## Task 6: Wire real email sending into auth send-code

**Files:**

- Modify: `admin_back_go/internal/module/auth/service.go`
- Modify: `admin_back_go/internal/module/auth/service_test.go`
- Modify: `admin_back_go/internal/bootstrap/app.go`

- [ ] **Step 1: Write failing auth tests**

Add tests:

```go
func TestServiceSendCodeRealEmailUsesMailSender(t *testing.T)
func TestServiceSendCodeRealEmailDeletesCachedCodeWhenMailFails(t *testing.T)
func TestServiceSendCodeRealPhoneStillReportsSMSNotConfigured(t *testing.T)
func TestServiceSendCodeDevModeStillReturnsTestCode(t *testing.T)
```

Assertions:

```text
Real email branch calls sender once with scene, account, generated code, and TTL.
Real email branch writes Redis before sender call.
Sender failure best-effort deletes Redis code.
Phone real-mode branch still returns 短信验证码服务未配置.
Dev mode still returns 验证码发送成功(测试:xxxxxx).
```

- [ ] **Step 2: Add auth interface and option**

In `auth/service.go`:

```go
type VerifyCodeMailSender interface {
	SendVerifyCode(ctx context.Context, scene string, toEmail string, code string, ttl time.Duration) *apperror.Error
}

func WithVerifyCodeMailSender(sender VerifyCodeMailSender) Option {
	return func(s *Service) { s.verifyCodeMailSender = sender }
}
```

Add field:

```go
verifyCodeMailSender VerifyCodeMailSender
```

- [ ] **Step 3: Replace real-mode branch**

Rules:

```text
If !DevMode and account type is phone: return 短信验证码服务未配置.
Generate code.
Write Redis.
If !DevMode and account type is email:
  require verifyCodeMailSender.
  call SendVerifyCode.
  on failure delete Redis key and return error.
  on success return 验证码发送成功.
If DevMode: return 验证码发送成功(测试:code).
```

Do not change `VerifyCodeCacheKey`.

- [ ] **Step 4: Inject mail service**

In `bootstrap/app.go`, pass:

```go
auth.WithVerifyCodeMailSender(mailService),
```

- [ ] **Step 5: Run tests and commit**

Run:

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/module/auth ./internal/module/mail ./internal/bootstrap ./internal/server
cd E:/admin_go
git add admin_back_go/internal/module/auth admin_back_go/internal/bootstrap/app.go
git commit -m "feat: send email verify codes through mail service"
```

Expected: tests pass and commit succeeds.

---

## Task 7: Add typed Vue API and mail management page

**Files:**

- Create: `admin_front_ts/src/api/system/mail.ts`
- Create: `admin_front_ts/src/views/Main/system/mail/index.vue`
- Create: `admin_front_ts/src/views/Main/system/mail/components/MailConfigPanel.vue`
- Create: `admin_front_ts/src/views/Main/system/mail/components/MailTemplatePanel.vue`
- Create: `admin_front_ts/src/views/Main/system/mail/components/MailLogPanel.vue`
- Create: `admin_front_ts/tests/shared/system/mail-api.test.ts`
- Modify: `admin_front_ts/src/i18n/locales/zh-CN.ts`
- Modify: `admin_front_ts/src/i18n/locales/en-US.ts`

Vue component map:

```text
index.vue: route-level composition surface; fetch page-init once and render tabs.
MailConfigPanel.vue: config form, secret hint/blank-preserve behavior, test-send form.
MailTemplatePanel.vue: template list/form/status/delete and variable/sample-variable editing.
MailLogPanel.vue: log filters/list/detail/delete; no body/code display.
```

- [ ] **Step 1: Write frontend API contract test**

Create `tests/shared/system/mail-api.test.ts` that asserts:

```text
src/api/system/mail.ts imports request and ADMIN_API_PREFIX.
BASE is `${ADMIN_API_PREFIX}/mail`.
It uses page-init/config/test/templates/logs REST routes.
It contains delete config and delete logs calls.
It does not contain legacyRequest.
It does not contain /api/admin/Mail.
It contains secret_id_hint and secret_key_hint.
It does not contain secret_id_enc or secret_key_enc.
```

- [ ] **Step 2: Implement typed API**

`src/api/system/mail.ts` must define:

```ts
export type CommonStatus = 1 | 2
export type MailScene = 'login' | 'forget' | 'bind_email' | 'change_password'
export type MailLogScene = MailScene | 'test'
export type MailLogStatus = 1 | 2 | 3
```

API methods:

```text
MailApi.pageInit()
MailApi.config()
MailApi.saveConfig(params)
MailApi.deleteConfig()
MailApi.test(params)
MailApi.templates()
MailApi.addTemplate(params)
MailApi.editTemplate(params)
MailApi.changeTemplateStatus(params)
MailApi.deleteTemplate(params)
MailApi.logs(params)
MailApi.log(params)
MailApi.deleteLog(params)
MailApi.deleteLogs(params)
```

Rules:

```text
No any.
No Record<string, any>.
No secret_id_enc / secret_key_enc types.
Positive id guard for all :id routes.
```

- [ ] **Step 3: Implement Vue page**

All SFCs must use:

```vue
<script setup lang="ts">
```

Rules:

```text
index.vue stays thin and only composes tabs.
MailConfigPanel uses hint as placeholder; blank secret fields preserve old values.
MailTemplatePanel edits variables as typed string list and sample variables as key/value rows.
MailLogPanel renders only list/detail fields exposed by API.
Every mutation button uses userStore.can('system_mail_*').
No v-html.
No body/code/TemplateData display.
```

- [ ] **Step 4: Add i18n**

Add:

```ts
system_mail: '邮件管理'
```

and English:

```ts
system_mail: 'Mail'
```

Add page labels for Tencent SecretId, Tencent SecretKey, region, endpoint, from email, from name, reply-to, Tencent template ID, variables, sample variables, and send logs.

- [ ] **Step 5: Run frontend verification and commit**

Run:

```powershell
cd E:/admin_go/admin_front_ts
npx vitest run tests/shared/system/mail-api.test.ts
npx vue-tsc -b --pretty false
npm run build
git add src/api/system/mail.ts src/views/Main/system/mail src/i18n/locales/zh-CN.ts src/i18n/locales/en-US.ts tests/shared/system/mail-api.test.ts
git commit -m "feat: add mail management page"
```

Expected: all commands pass and frontend repo commit succeeds.

---

## Task 8: Update docs, smoke, and final verification

**Files:**

- Modify: `docs/contracts/admin-api-v1.md`
- Modify: `docs/migration/current-status.md`
- Modify: `docs/testing/smoke-matrix.md`
- Modify: `admin_back_go/docs/architecture.md`
- Modify: `admin_back_go/scripts/full-admin-smoke.ps1`

- [ ] **Step 1: Update API contract**

Add Mail Management section with all routes:

```text
GET    /api/admin/v1/mail/page-init
GET    /api/admin/v1/mail/config
PUT    /api/admin/v1/mail/config
DELETE /api/admin/v1/mail/config
POST   /api/admin/v1/mail/test
GET    /api/admin/v1/mail/templates
POST   /api/admin/v1/mail/templates
PUT    /api/admin/v1/mail/templates/:id
PATCH  /api/admin/v1/mail/templates/:id/status
DELETE /api/admin/v1/mail/templates/:id
GET    /api/admin/v1/mail/logs
GET    /api/admin/v1/mail/logs/:id
DELETE /api/admin/v1/mail/logs/:id
DELETE /api/admin/v1/mail/logs
```

Explicitly state:

```text
SecretId/SecretKey are write-only.
Responses return only secret_id_hint and secret_key_hint.
mail_logs never return body, verify code, or TemplateData.
Read routes are bearer token.
Mutation routes require system_mail_* permission.
```

- [ ] **Step 2: Update architecture and status docs**

In `admin_back_go/docs/architecture.md`, add:

```text
internal/module/mail 腾讯云 SES 邮件配置、模板映射、发送日志和验证码邮件发送边界
internal/platform/mail/tencentcloudses 腾讯云 SES SDK SendEmail 薄封装边界
```

In `docs/testing/smoke-matrix.md`, add:

```text
mail management read | no | yes | GET /mail/page-init, /mail/config, /mail/templates, /mail/logs | no | n/a | verifies dict shape and no secret/body/code leak
```

In `docs/migration/current-status.md`, add mail row only after final verification passes.

- [ ] **Step 3: Add smoke read probes**

In `full-admin-smoke.ps1`, add read-only probes:

```powershell
$mailInit = Invoke-AdminGet '/api/admin/v1/mail/page-init'
Assert-ApiOK $mailInit 'mail page-init'
if (-not (Test-HasProperty $mailInit.data.dict 'mail_scene_arr')) { throw 'mail page-init missing mail_scene_arr' }
if (-not (Test-HasProperty $mailInit.data.dict 'mail_log_status_arr')) { throw 'mail page-init missing mail_log_status_arr' }

$mailConfig = Invoke-AdminGet '/api/admin/v1/mail/config'
Assert-ApiOK $mailConfig 'mail config'
if (Test-HasProperty $mailConfig.data 'secret_id_enc') { throw 'mail config leaked secret_id_enc' }
if (Test-HasProperty $mailConfig.data 'secret_key_enc') { throw 'mail config leaked secret_key_enc' }

$mailTemplates = Invoke-AdminGet '/api/admin/v1/mail/templates'
Assert-ApiOK $mailTemplates 'mail templates'

$mailLogs = Invoke-AdminGet '/api/admin/v1/mail/logs?current_page=1&page_size=10'
Assert-ApiOK $mailLogs 'mail logs'
if (Test-HasProperty $mailLogs.data 'list') {
  foreach ($row in (Get-ObjectArray $mailLogs.data.list)) {
    if (Test-HasProperty $row 'body') { throw 'mail log leaked body' }
    if (Test-HasProperty $row 'template_data') { throw 'mail log leaked template_data' }
    if (Test-HasProperty $row 'code') { throw 'mail log leaked verify code' }
  }
}
```

Do not add real email sending to default smoke.

- [ ] **Step 4: Run backend verification**

Run:

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/platform/mail/tencentcloudses ./internal/module/mail ./internal/module/auth ./internal/server ./internal/bootstrap
go vet ./...
powershell -ExecutionPolicy Bypass -File .\scripts\check-contract.ps1
```

Expected: all pass.

- [ ] **Step 5: Run frontend verification**

Run:

```powershell
cd E:/admin_go/admin_front_ts
npx vitest run tests/shared/system/mail-api.test.ts
npx vue-tsc -b --pretty false
npm run build
```

Expected: all pass.

- [ ] **Step 6: Run full smoke**

Run:

```powershell
cd E:/admin_go/admin_back_go
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account 15671628271 -Password 123456
```

Expected: mail read probes pass and no secret/body/code leak failure appears.

- [ ] **Step 7: Run residue scans**

Run:

```powershell
cd E:/admin_go
rg -n "MAIL_SECRET|TENCENTCLOUD_SECRET" admin_back_go/.env.example admin_back_go/deploy docs admin_back_go/internal/config
rg -n "secret_id_enc|secret_key_enc" admin_front_ts/src admin_front_ts/tests
rg -n "template_data|verify_code|验证码|mail_log.*code|code.*mail_log|MailLog.*Code" admin_front_ts/src/api/system/mail.ts admin_front_ts/src/views/Main/system/mail admin_back_go/internal/module/mail/dto.go
```

Expected:

```text
MAIL_SECRET and TENCENTCLOUD_SECRET do not appear as runtime env keys.
secret_id_enc and secret_key_enc do not appear in frontend API response types.
template_data and verify code are not exposed in mail log DTO/frontend types.
```

- [ ] **Step 8: Commit docs and smoke**

Run:

```powershell
cd E:/admin_go
git add docs/contracts/admin-api-v1.md docs/migration/current-status.md docs/testing/smoke-matrix.md admin_back_go/docs/architecture.md admin_back_go/scripts/full-admin-smoke.ps1
git commit -m "docs: document mail management contract and smoke"
```

Expected: commit succeeds.

---

## Final Review Checklist

Before reporting done:

```text
mail_configs has is_del and all config reads filter is_del=2.
mail_templates has is_del and all template reads/updates/deletes/sends filter is_del=2.
mail_logs has is_del and list/detail filter is_del=2.
Every table field has a code path matching the spec field-use contract.
Frontend does not contain secret_id_enc or secret_key_enc.
Mail logs do not expose body, verify code, or TemplateData.
VERIFY_CODE_DEV_MODE=true still returns test code.
VERIFY_CODE_DEV_MODE=false email branch sends through mail service.
VERIFY_CODE_DEV_MODE=false phone branch still reports SMS not configured.
Tencent SDK is isolated under internal/platform/mail/tencentcloudses.
Default smoke does not send real email.
Docs, contract, smoke matrix, and architecture match runtime behavior.
```

Final verification command set:

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/platform/mail/tencentcloudses ./internal/module/mail ./internal/module/auth ./internal/server ./internal/bootstrap
go vet ./...
powershell -ExecutionPolicy Bypass -File .\scripts\check-contract.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account 15671628271 -Password 123456

cd E:/admin_go/admin_front_ts
npx vitest run tests/shared/system/mail-api.test.ts
npx vue-tsc -b --pretty false
npm run build
```
