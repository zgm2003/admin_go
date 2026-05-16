# SMS Management Tencent Cloud SMS Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a production-grade System -> SMS Management slice backed by Tencent Cloud SMS `SendSms`, with config/template/log/test-send management and no change to current phone verification-code login behavior.

**Architecture:** Add an independent `sms` module beside `mail`. `internal/module/sms` owns config, template, log, validation, test-send, and reusable send orchestration; `internal/platform/sms/tencentcloudsms` is the only package allowed to import Tencent Cloud SMS SDK. Frontend follows the current mail page shape, but only uses SMS fields: no subject, no SMTP, no provider abstraction, no sign/template application workflow.

**Tech Stack:** Go, Gin, GORM, MySQL, Redis-backed system setting cache, `secretbox`, Tencent Cloud Go SDK, Vue 3, TypeScript, Element Plus, Vitest.

---

## 2026-05-16 Refresh Notes

- Official Tencent Cloud SMS Go SDK docs use `sms/v20210111` and `SendSms` fields `SmsSdkAppId`, `SignName`, `TemplateId`, `TemplateParamSet`, and `PhoneNumberSet`: https://cloud.tencent.com/document/product/382/43199
- Tencent Cloud's 2021-01-11 SMS API migration makes `Region` mandatory and renames old 2019 fields to `SmsSdkAppId` / `TemplateId` / `SignName`: https://cloud.tencent.com/document/api/382/63195
- Tencent Cloud API overview separates runtime `SendSms` from sign/template management APIs: https://cloud.tencent.com/document/api/382/52077
- `go list -m -versions github.com/tencentcloud/tencentcloud-sdk-go/tencentcloud/sms` currently shows `v1.3.93` as the latest SMS module version available in this workspace.
- `admin_back_go/internal/enum/verify_code.go` already has `VerifyCodeSceneBindPhone`; do not touch verify-code enum just to add a constant that already exists.
- `admin_front_ts` currently has unrelated payment recharge dirty files. SMS implementation must not stage, revert, or reformat those files.

## Hard Boundaries

- Do not modify `auth/send-code` in this slice. Phone codes remain fixed `123456`; email still uses Tencent SES.
- Do not add sign application, template application, webhook, retry queue, multi-provider, marketing SMS, or international SMS.
- Do not store SMS body, verification code, or full template parameters in logs.
- All SMS tables must include `is_del`, `created_at`, and `updated_at`.
- SecretId/SecretKey must use `secretbox` encryption. HTTP responses return only hints.
- Every read path must filter `is_del = enum.CommonNo`.
- `sms_sdk_app_id`, `sign_name`, `region`, and `endpoint` are all used by the `SendSms` call path.
- Do not add a field unless this plan names its write path, read path, and runtime reason. Specifically no `provider`, `channel`, `app_name`, `brand`, `callback_url`, `retry_count`, `raw_request`, `raw_response`, `template_content`, or `template_params`.
- Stability means explicit bounded failure, not hidden retries: Tencent SDK calls use context + 10s timeout; every send creates one pending log and finishes it as success/failed; no automatic retry queue, no batch send, no raw payload persistence.
- SMS implementation must not switch `auth/send-code` phone verification away from fixed `123456` in this slice.

## File Structure

### Backend create

- `admin_back_go/database/migrations/20260516_sms_tencent_cloud.sql` — schema, menu, buttons, and role grants.
- `admin_back_go/internal/enum/sms.go` — SMS log statuses and SMS scene validators, reusing existing verify-code scene constants.
- `admin_back_go/internal/dict/sms.go` — SMS scenes, log scenes, log statuses, region options.
- `admin_back_go/internal/module/sms/model.go` — `sms_configs`, `sms_templates`, `sms_logs` GORM models.
- `admin_back_go/internal/module/sms/dto.go` — response DTOs, service inputs, sender input/result.
- `admin_back_go/internal/module/sms/request.go` — Gin binding structs.
- `admin_back_go/internal/module/sms/errors.go` — module sentinel errors.
- `admin_back_go/internal/module/sms/repository.go` — GORM repository and setting cache invalidation.
- `admin_back_go/internal/module/sms/service.go` — validation, secret encryption, shared TTL, send flow, log flow.
- `admin_back_go/internal/module/sms/handler.go` — HTTP handlers.
- `admin_back_go/internal/module/sms/route.go` — `/api/admin/v1/sms` routes.
- `admin_back_go/internal/platform/sms/tencentcloudsms/client.go` — Tencent SMS SDK wrapper.
- `admin_back_go/internal/i18n/locales/zh-CN/sms.yaml` — SMS backend response translations.
- `admin_back_go/internal/i18n/locales/en-US/sms.yaml` — SMS backend response translations.

### Backend modify

- `admin_back_go/go.mod`, `admin_back_go/go.sum` — add Tencent Cloud SMS SDK module.
- `admin_back_go/internal/server/router.go` — add `SmsService` dependency and route registration.
- `admin_back_go/internal/bootstrap/app.go` — wire repository, secretbox, Tencent SMS client, sender adapter.
- `admin_back_go/internal/bootstrap/route_meta.go` — permission and operation-log route rules.
- `admin_back_go/internal/bootstrap/route_meta_test.go` — metadata regression coverage.
- `admin_back_go/internal/server/router_test.go` — fake SMS service and route coverage.
- `admin_back_go/internal/module/README.md` — add active `sms` module line.
- `admin_back_go/docs/architecture.md` — add SMS runtime boundary.

### Frontend create

- `admin_front_ts/src/api/system/sms.ts` — typed SMS REST client.
- `admin_front_ts/src/views/Main/system/sms/index.vue` — tab shell.
- `admin_front_ts/src/views/Main/system/sms/smsDict.ts` — dict defaults/normalizer.
- `admin_front_ts/src/views/Main/system/sms/components/SmsConfigPanel.vue` — config and test-send panel.
- `admin_front_ts/src/views/Main/system/sms/components/SmsTemplatePanel.vue` — template CRUD panel.
- `admin_front_ts/src/views/Main/system/sms/components/SmsLogPanel.vue` — log list/detail panel.
- `admin_front_ts/tests/shared/system/sms-api.test.ts` — API/page contract guard.

### Frontend modify

- `admin_front_ts/src/i18n/locales/zh-CN.ts` — `menu.system_sms` and `sms.*`.
- `admin_front_ts/src/i18n/locales/en-US.ts` — English SMS labels.

### Docs modify

- `docs/contracts/admin-api-v1.md` — add SMS API contract.
- `docs/status/current-status.md` — add SMS row after implementation verification.
- `docs/testing/smoke-matrix.md` — add read-only SMS probes next to mail probes after implementation verification.
- `docs/superpowers/specs/2026-05-15-sms-management-tencent-cloud-design.md` — mark implemented after all gates pass.

---

### Task 1: Backend Schema, Enums, Dicts, and Models

**Files:**
- Create: `admin_back_go/database/migrations/20260516_sms_tencent_cloud.sql`
- Create: `admin_back_go/internal/enum/sms.go`
- Create: `admin_back_go/internal/dict/sms.go`
- Create: `admin_back_go/internal/module/sms/model.go`
- Create: `admin_back_go/internal/module/sms/errors.go`
- Create: `admin_back_go/internal/module/sms/repository_test.go`

- [ ] **Step 1: Write failing dict/model tests**

Create `admin_back_go/internal/module/sms/repository_test.go`:

```go
package sms

import (
	"reflect"
	"strings"
	"testing"

	"admin_back_go/internal/dict"
	"admin_back_go/internal/enum"
)

func TestSmsDictsReturnRequiredValues(t *testing.T) {
	scenes := dict.SmsSceneOptions()
	want := []string{
		enum.VerifyCodeSceneLogin,
		enum.VerifyCodeSceneForget,
		enum.VerifyCodeSceneBindPhone,
		enum.VerifyCodeSceneChangePassword,
	}
	if len(scenes) != len(want) {
		t.Fatalf("sms scene count = %d, want %d", len(scenes), len(want))
	}
	for i, value := range want {
		if scenes[i].Value != value {
			t.Fatalf("sms scene[%d] = %q, want %q", i, scenes[i].Value, value)
		}
	}
	if got := len(dict.SmsLogSceneOptions()); got != 5 {
		t.Fatalf("sms log scene count = %d, want 5", got)
	}
	if got := len(dict.SmsLogStatusOptions()); got != 3 {
		t.Fatalf("sms log status count = %d, want 3", got)
	}
	if got := dict.SmsRegionOptions(); len(got) != 1 || got[0].Value != DefaultRegion {
		t.Fatalf("sms region options = %#v, want only %s", got, DefaultRegion)
	}
}

func TestSmsModelsKeepSoftDeleteAndTimestamps(t *testing.T) {
	cases := map[string]reflect.Type{
		"Config":   reflect.TypeOf(Config{}),
		"Template": reflect.TypeOf(Template{}),
		"Log":      reflect.TypeOf(Log{}),
	}
	for name, typ := range cases {
		for fieldName, column := range map[string]string{
			"IsDel":     "is_del",
			"CreatedAt": "created_at",
			"UpdatedAt": "updated_at",
		} {
			field, ok := typ.FieldByName(fieldName)
			if !ok {
				t.Fatalf("%s must expose %s", name, fieldName)
			}
			if tag := field.Tag.Get("gorm"); !strings.Contains(tag, "column:"+column) {
				t.Fatalf("%s.%s must map to %s, got %q", name, fieldName, column, tag)
			}
		}
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
cd admin_back_go
go test ./internal/module/sms ./internal/dict ./internal/enum
```

Expected: compile failure for missing `sms` package, `dict.SmsSceneOptions`, `dict.SmsLogSceneOptions`, `dict.SmsLogStatusOptions`, and SMS models. `enum.VerifyCodeSceneBindPhone` already exists and must not be re-added.

- [ ] **Step 3: Add SMS enums and dicts**

Create `admin_back_go/internal/enum/sms.go`:

```go
package enum

const (
	SmsLogStatusPending = 1
	SmsLogStatusSuccess = 2
	SmsLogStatusFailed  = 3

	SmsSceneTest = "test"
)

func IsSmsLogStatus(value int) bool {
	return value == SmsLogStatusPending || value == SmsLogStatusSuccess || value == SmsLogStatusFailed
}

func IsSmsTemplateScene(value string) bool {
	switch value {
	case VerifyCodeSceneLogin, VerifyCodeSceneForget, VerifyCodeSceneBindPhone, VerifyCodeSceneChangePassword:
		return true
	default:
		return false
	}
}

func IsSmsLogScene(value string) bool {
	return IsSmsTemplateScene(value) || value == SmsSceneTest
}
```

Do not modify `admin_back_go/internal/enum/verify_code.go`; the current runtime already defines `VerifyCodeSceneBindPhone`.

Create `admin_back_go/internal/dict/sms.go`:

```go
package dict

import "admin_back_go/internal/enum"

func SmsSceneOptions() []Option[string] {
	return []Option[string]{
		{Label: "手机号验证码登录", Value: enum.VerifyCodeSceneLogin},
		{Label: "找回密码", Value: enum.VerifyCodeSceneForget},
		{Label: "绑定/换绑手机号", Value: enum.VerifyCodeSceneBindPhone},
		{Label: "验证码改密", Value: enum.VerifyCodeSceneChangePassword},
	}
}

func SmsLogSceneOptions() []Option[string] {
	return append(SmsSceneOptions(), Option[string]{Label: "测试发送", Value: enum.SmsSceneTest})
}

func SmsRegionOptions() []Option[string] {
	return []Option[string]{{Label: "广州", Value: "ap-guangzhou"}}
}

func IsSmsRegion(value string) bool {
	for _, option := range SmsRegionOptions() {
		if option.Value == value {
			return true
		}
	}
	return false
}

func SmsLogStatusOptions() []Option[int] {
	return []Option[int]{
		{Label: "发送中", Value: enum.SmsLogStatusPending},
		{Label: "发送成功", Value: enum.SmsLogStatusSuccess},
		{Label: "发送失败", Value: enum.SmsLogStatusFailed},
	}
}
```

- [ ] **Step 4: Add models and errors**

Create `admin_back_go/internal/module/sms/model.go`:

```go
package sms

import "time"

const defaultConfigKey = "default"

type Config struct {
	ID            uint64     `gorm:"column:id;primaryKey"`
	ConfigKey     string     `gorm:"column:config_key"`
	SecretIDEnc   string     `gorm:"column:secret_id_enc"`
	SecretIDHint  string     `gorm:"column:secret_id_hint"`
	SecretKeyEnc  string     `gorm:"column:secret_key_enc"`
	SecretKeyHint string     `gorm:"column:secret_key_hint"`
	SmsSdkAppID   string     `gorm:"column:sms_sdk_app_id"`
	SignName      string     `gorm:"column:sign_name"`
	Region        string     `gorm:"column:region"`
	Endpoint      string     `gorm:"column:endpoint"`
	Status        int        `gorm:"column:status"`
	IsDel         int        `gorm:"column:is_del"`
	LastTestAt    *time.Time `gorm:"column:last_test_at"`
	LastTestError string     `gorm:"column:last_test_error"`
	CreatedAt     time.Time  `gorm:"column:created_at"`
	UpdatedAt     time.Time  `gorm:"column:updated_at"`
}

func (Config) TableName() string { return "sms_configs" }

type Template struct {
	ID                  uint64    `gorm:"column:id;primaryKey"`
	Scene               string    `gorm:"column:scene"`
	Name                string    `gorm:"column:name"`
	TencentTemplateID   string    `gorm:"column:tencent_template_id"`
	VariablesJSON       string    `gorm:"column:variables_json"`
	SampleVariablesJSON string    `gorm:"column:sample_variables_json"`
	Status              int       `gorm:"column:status"`
	IsDel               int       `gorm:"column:is_del"`
	CreatedAt           time.Time `gorm:"column:created_at"`
	UpdatedAt           time.Time `gorm:"column:updated_at"`
}

func (Template) TableName() string { return "sms_templates" }

type Log struct {
	ID               uint64     `gorm:"column:id;primaryKey"`
	Scene            string     `gorm:"column:scene"`
	TemplateID       *uint64    `gorm:"column:template_id"`
	ToPhone          string     `gorm:"column:to_phone"`
	TencentRequestID string     `gorm:"column:tencent_request_id"`
	TencentSerialNo  string     `gorm:"column:tencent_serial_no"`
	TencentFee       uint64     `gorm:"column:tencent_fee"`
	Status           int        `gorm:"column:status"`
	IsDel            int        `gorm:"column:is_del"`
	ErrorCode        string     `gorm:"column:error_code"`
	ErrorMessage     string     `gorm:"column:error_message"`
	DurationMS       uint64     `gorm:"column:duration_ms"`
	SentAt           *time.Time `gorm:"column:sent_at"`
	CreatedAt        time.Time  `gorm:"column:created_at"`
	UpdatedAt        time.Time  `gorm:"column:updated_at"`
}

func (Log) TableName() string { return "sms_logs" }
```

Create `admin_back_go/internal/module/sms/errors.go`:

```go
package sms

import "errors"

var (
	ErrRepositoryNotConfigured = errors.New("sms repository is not configured")
	ErrSenderNotConfigured     = errors.New("sms sender is not configured")
)
```

- [ ] **Step 5: Add migration SQL**

Create `admin_back_go/database/migrations/20260516_sms_tencent_cloud.sql` with:

```sql
CREATE TABLE IF NOT EXISTS `sms_configs` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `config_key` VARCHAR(32) NOT NULL DEFAULT 'default',
  `secret_id_enc` TEXT NOT NULL,
  `secret_id_hint` VARCHAR(64) NOT NULL DEFAULT '',
  `secret_key_enc` TEXT NOT NULL,
  `secret_key_hint` VARCHAR(64) NOT NULL DEFAULT '',
  `sms_sdk_app_id` VARCHAR(32) NOT NULL DEFAULT '',
  `sign_name` VARCHAR(100) NOT NULL DEFAULT '',
  `region` VARCHAR(64) NOT NULL DEFAULT 'ap-guangzhou',
  `endpoint` VARCHAR(128) NOT NULL DEFAULT 'sms.tencentcloudapi.com',
  `status` TINYINT UNSIGNED NOT NULL DEFAULT 2,
  `is_del` TINYINT UNSIGNED NOT NULL DEFAULT 2,
  `last_test_at` DATETIME NULL,
  `last_test_error` VARCHAR(500) NOT NULL DEFAULT '',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_sms_configs_config_key` (`config_key`),
  KEY `idx_sms_configs_status_del` (`status`, `is_del`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `sms_templates` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `scene` VARCHAR(32) NOT NULL,
  `name` VARCHAR(100) NOT NULL,
  `tencent_template_id` VARCHAR(32) NOT NULL,
  `variables_json` JSON NOT NULL,
  `sample_variables_json` JSON NOT NULL,
  `status` TINYINT UNSIGNED NOT NULL DEFAULT 1,
  `is_del` TINYINT UNSIGNED NOT NULL DEFAULT 2,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_sms_templates_scene` (`scene`),
  KEY `idx_sms_templates_status_del` (`status`, `is_del`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `sms_logs` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `scene` VARCHAR(32) NOT NULL,
  `template_id` BIGINT UNSIGNED NULL,
  `to_phone` VARCHAR(20) NOT NULL,
  `tencent_request_id` VARCHAR(128) NOT NULL DEFAULT '',
  `tencent_serial_no` VARCHAR(128) NOT NULL DEFAULT '',
  `tencent_fee` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `status` TINYINT UNSIGNED NOT NULL,
  `is_del` TINYINT UNSIGNED NOT NULL DEFAULT 2,
  `error_code` VARCHAR(128) NOT NULL DEFAULT '',
  `error_message` VARCHAR(500) NOT NULL DEFAULT '',
  `duration_ms` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `sent_at` DATETIME NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_sms_logs_scene_created` (`is_del`, `scene`, `created_at`),
  KEY `idx_sms_logs_status_created` (`is_del`, `status`, `created_at`),
  KEY `idx_sms_logs_to_phone_created` (`is_del`, `to_phone`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

Add permission rows in the same migration:

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

INSERT INTO `permissions` (`name`, `path`, `icon`, `parent_id`, `component`, `platform`, `type`, `sort`, `code`, `i18n_key`, `show_menu`, `status`, `is_del`)
SELECT '短信管理', '/system/sms', 'ChatDotRound', @system_parent_id, 'system/sms', 'admin', 2, 91, 'system_sms', 'menu.system_sms', 1, 1, 2
WHERE @system_parent_id IS NOT NULL
ON DUPLICATE KEY UPDATE
  `name` = VALUES(`name`),
  `path` = VALUES(`path`),
  `icon` = VALUES(`icon`),
  `parent_id` = VALUES(`parent_id`),
  `component` = VALUES(`component`),
  `type` = VALUES(`type`),
  `sort` = VALUES(`sort`),
  `i18n_key` = VALUES(`i18n_key`),
  `show_menu` = VALUES(`show_menu`),
  `status` = VALUES(`status`),
  `is_del` = 2,
  `updated_at` = CURRENT_TIMESTAMP;

SET @sms_page_id := (
  SELECT `id` FROM `permissions` WHERE `platform` = 'admin' AND `code` = 'system_sms' LIMIT 1
);

INSERT INTO `permissions` (`name`, `path`, `icon`, `parent_id`, `component`, `platform`, `type`, `sort`, `code`, `i18n_key`, `show_menu`, `status`, `is_del`)
SELECT button_name, '', '', @sms_page_id, NULL, 'admin', 3, button_sort, button_code, '', 2, 1, 2
FROM (
  SELECT '编辑短信配置' AS button_name, 'system_sms_configEdit' AS button_code, 1 AS button_sort
  UNION ALL SELECT '删除短信配置', 'system_sms_configDel', 2
  UNION ALL SELECT '发送测试短信', 'system_sms_test', 3
  UNION ALL SELECT '新增短信模板', 'system_sms_templateAdd', 4
  UNION ALL SELECT '编辑短信模板', 'system_sms_templateEdit', 5
  UNION ALL SELECT '修改短信模板状态', 'system_sms_templateStatus', 6
  UNION ALL SELECT '删除短信模板', 'system_sms_templateDel', 7
  UNION ALL SELECT '删除短信日志', 'system_sms_logDel', 8
) AS sms_buttons
WHERE @sms_page_id IS NOT NULL
ON DUPLICATE KEY UPDATE
  `name` = VALUES(`name`),
  `parent_id` = VALUES(`parent_id`),
  `type` = VALUES(`type`),
  `sort` = VALUES(`sort`),
  `show_menu` = VALUES(`show_menu`),
  `status` = VALUES(`status`),
  `is_del` = 2,
  `updated_at` = CURRENT_TIMESTAMP;
```

Grant existing system/mail administrators the SMS page and buttons:

```sql
CREATE TEMPORARY TABLE IF NOT EXISTS `tmp_sms_permission_grant_roles` (
  `role_id` INT UNSIGNED NOT NULL PRIMARY KEY
) ENGINE=MEMORY;

TRUNCATE TABLE `tmp_sms_permission_grant_roles`;

INSERT IGNORE INTO `tmp_sms_permission_grant_roles` (`role_id`)
SELECT DISTINCT rp.`role_id`
FROM `role_permissions` rp
JOIN `permissions` p ON p.`id` = rp.`permission_id`
JOIN `roles` r ON r.`id` = rp.`role_id`
WHERE rp.`is_del` = 2
  AND p.`is_del` = 2
  AND r.`is_del` = 2
  AND p.`platform` = 'admin'
  AND p.`code` IN ('system_mail', 'system_setting_edit', 'system_uploadConfig_settingEdit');

INSERT INTO `role_permissions` (`role_id`, `permission_id`, `is_del`)
SELECT gr.`role_id`, p.`id`, 2
FROM `tmp_sms_permission_grant_roles` gr
JOIN `permissions` p ON p.`platform` = 'admin'
  AND p.`is_del` = 2
  AND p.`code` IN (
    'system_sms',
    'system_sms_configEdit',
    'system_sms_configDel',
    'system_sms_test',
    'system_sms_templateAdd',
    'system_sms_templateEdit',
    'system_sms_templateStatus',
    'system_sms_templateDel',
    'system_sms_logDel'
  )
ON DUPLICATE KEY UPDATE
  `is_del` = 2,
  `updated_at` = CURRENT_TIMESTAMP;

DROP TEMPORARY TABLE IF EXISTS `tmp_sms_permission_grant_roles`;
```

- [ ] **Step 6: Run tests and commit**

Run:

```powershell
cd admin_back_go
go test ./internal/module/sms ./internal/dict ./internal/enum
```

Expected: PASS.

Commit:

```powershell
git add database/migrations/20260516_sms_tencent_cloud.sql internal/enum/sms.go internal/dict/sms.go internal/module/sms/model.go internal/module/sms/errors.go internal/module/sms/repository_test.go
git commit -m "feat: add sms schema and enums"
```

---

### Task 2: SMS Repository and DTO Contracts

**Files:**
- Create: `admin_back_go/internal/module/sms/dto.go`
- Create: `admin_back_go/internal/module/sms/repository.go`
- Modify: `admin_back_go/internal/module/sms/repository_test.go`

- [ ] **Step 1: Add failing repository tests**

Extend `repository_test.go` with sqlmock coverage for these exact read filters:

```go
func TestSmsRepositoryReadContractsRequireIsDelFilter(t *testing.T) {
	repo, mock, closeDB := newMockRepository(t)
	defer closeDB()

	mock.ExpectQuery("SELECT \\* FROM `sms_configs` WHERE config_key = \\? AND is_del = \\? ORDER BY `sms_configs`.`id` LIMIT \\?").
		WithArgs(defaultConfigKey, enum.CommonNo, 1).
		WillReturnRows(sqlmock.NewRows([]string{"id"}))
	mock.ExpectQuery("SELECT \\* FROM `sms_templates` WHERE is_del = \\? ORDER BY id DESC").
		WithArgs(enum.CommonNo).
		WillReturnRows(sqlmock.NewRows([]string{"id"}))
	mock.ExpectQuery("SELECT \\* FROM `sms_logs` WHERE is_del = \\? ORDER BY created_at DESC, id DESC LIMIT \\?").
		WithArgs(enum.CommonNo, 20).
		WillReturnRows(sqlmock.NewRows([]string{"id"}))

	if _, err := repo.DefaultConfig(context.Background()); err != nil {
		t.Fatalf("DefaultConfig error: %v", err)
	}
	if _, err := repo.ListTemplates(context.Background()); err != nil {
		t.Fatalf("ListTemplates error: %v", err)
	}
	if _, _, err := repo.ListLogs(context.Background(), LogQuery{CurrentPage: 1, PageSize: 20}); err != nil {
		t.Fatalf("ListLogs error: %v", err)
	}
	assertMockExpectations(t, mock)
}
```

Also add restore tests for `SaveDefaultConfig` and `SaveTemplate`, using `FOR UPDATE` and asserting a soft-deleted row is updated with `is_del = enum.CommonNo`.

- [ ] **Step 2: Run test to verify failure**

Run:

```powershell
cd admin_back_go
go test ./internal/module/sms
```

Expected: compile failure for missing `LogQuery`, `GormRepository`, and repository methods.

- [ ] **Step 3: Add DTOs**

Create `dto.go` with:

```go
package sms

import (
	"time"
	"admin_back_go/internal/dict"
)

const (
	DefaultRegion   = "ap-guangzhou"
	DefaultEndpoint = "sms.tencentcloudapi.com"
)

type PageInitResponse struct{ Dict PageInitDict `json:"dict"` }
type PageInitDict struct {
	CommonStatusArr   []dict.Option[int]    `json:"common_status_arr"`
	SmsSceneArr       []dict.Option[string] `json:"sms_scene_arr"`
	SmsLogSceneArr    []dict.Option[string] `json:"sms_log_scene_arr"`
	SmsLogStatusArr   []dict.Option[int]    `json:"sms_log_status_arr"`
	SmsRegionArr      []dict.Option[string] `json:"sms_region_arr"`
	DefaultRegion     string                `json:"default_region"`
	DefaultEndpoint   string                `json:"default_endpoint"`
	DefaultTTLMinutes int                   `json:"default_ttl_minutes"`
}
type ConfigResponse struct {
	ID                   *uint64 `json:"id"`
	Configured           bool    `json:"configured"`
	SecretIDHint         string  `json:"secret_id_hint"`
	SecretKeyHint        string  `json:"secret_key_hint"`
	SmsSdkAppID          string  `json:"sms_sdk_app_id"`
	SignName             string  `json:"sign_name"`
	Region               string  `json:"region"`
	Endpoint             string  `json:"endpoint"`
	Status               int     `json:"status"`
	VerifyCodeTTLMinutes int     `json:"verify_code_ttl_minutes"`
	LastTestAt           *string `json:"last_test_at"`
	LastTestError        string  `json:"last_test_error"`
	CreatedAt            *string `json:"created_at"`
	UpdatedAt            *string `json:"updated_at"`
}
type SaveConfigInput struct {
	SecretID string
	SecretKey string
	SmsSdkAppID string
	SignName string
	Region string
	Endpoint string
	Status int
	VerifyCodeTTLMinutes int
}
type TestInput struct{ ToPhone string; TemplateScene string }
type TemplateDTO struct {
	ID uint64 `json:"id"`
	Scene string `json:"scene"`
	Name string `json:"name"`
	TencentTemplateID string `json:"tencent_template_id"`
	Variables []string `json:"variables"`
	SampleVariables map[string]string `json:"sample_variables"`
	Status int `json:"status"`
	CreatedAt string `json:"created_at"`
	UpdatedAt string `json:"updated_at"`
}
type SaveTemplateInput struct {
	Scene string
	Name string
	TencentTemplateID string
	Variables []string
	SampleVariables map[string]string
	Status int
}
type TemplateUpdate struct {
	Scene string
	Name string
	TencentTemplateID string
	VariablesJSON string
	SampleVariablesJSON string
	Status int
}
type LogQuery struct {
	CurrentPage int
	PageSize int
	Scene string
	Status *int
	ToPhone string
	CreatedAtStart *time.Time
	CreatedAtEnd *time.Time
}
type Page struct{ PageSize int `json:"page_size"`; CurrentPage int `json:"current_page"`; TotalPage int `json:"total_page"`; Total int64 `json:"total"` }
type LogListResponse struct{ List []LogDTO `json:"list"`; Page Page `json:"page"` }
type LogDTO struct {
	ID uint64 `json:"id"`
	Scene string `json:"scene"`
	TemplateID *uint64 `json:"template_id"`
	ToPhone string `json:"to_phone"`
	Status int `json:"status"`
	TencentRequestID string `json:"tencent_request_id"`
	TencentSerialNo string `json:"tencent_serial_no"`
	TencentFee uint64 `json:"tencent_fee"`
	ErrorCode string `json:"error_code"`
	ErrorMessage string `json:"error_message"`
	DurationMS uint64 `json:"duration_ms"`
	SentAt *string `json:"sent_at"`
	CreatedAt string `json:"created_at"`
	UpdatedAt string `json:"updated_at"`
	Template *LogTemplateDTO `json:"template,omitempty"`
}
type LogTemplateDTO struct {
	ID uint64 `json:"id"`
	Scene string `json:"scene"`
	Name string `json:"name"`
	TencentTemplateID string `json:"tencent_template_id"`
	Variables []string `json:"variables"`
	Status int `json:"status"`
}
type LogFinish struct{ Status int; RequestID string; SerialNo string; Fee uint64; ErrorCode string; ErrorMessage string; DurationMS uint64; SentAt *time.Time }
type SendInput struct{ SecretID string; SecretKey string; Region string; Endpoint string; SmsSdkAppID string; SignName string; ToPhone string; TemplateID string; TemplateParams []string }
type SendResult struct{ RequestID string; SerialNo string; Fee uint64 }
```

- [ ] **Step 4: Implement repository**

Create `repository.go` with the same boundaries as `mail` but SMS field names. The interface must include:

```go
type Repository interface {
	DefaultConfig(ctx context.Context) (*Config, error)
	SaveDefaultConfig(ctx context.Context, row Config) error
	SoftDeleteDefaultConfig(ctx context.Context) error
	UpdateConfigTestResult(ctx context.Context, at *time.Time, errorMessage string) error
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
	SettingByKey(ctx context.Context, key string) (*systemsetting.Setting, error)
	SaveSetting(ctx context.Context, row systemsetting.Setting) error
	InvalidateSettingCache(ctx context.Context, key string) error
}
```

Required update maps:

```go
map[string]any{
	"secret_id_enc": row.SecretIDEnc,
	"secret_id_hint": row.SecretIDHint,
	"secret_key_enc": row.SecretKeyEnc,
	"secret_key_hint": row.SecretKeyHint,
	"sms_sdk_app_id": row.SmsSdkAppID,
	"sign_name": row.SignName,
	"region": row.Region,
	"endpoint": row.Endpoint,
	"status": row.Status,
	"is_del": enum.CommonNo,
}
```

```go
map[string]any{
	"status": finish.Status,
	"tencent_request_id": finish.RequestID,
	"tencent_serial_no": finish.SerialNo,
	"tencent_fee": finish.Fee,
	"error_code": truncate(finish.ErrorCode, 128),
	"error_message": truncate(finish.ErrorMessage, 500),
	"duration_ms": finish.DurationMS,
	"sent_at": finish.SentAt,
}
```

`ListLogs` must filter by `scene`, `status`, `to_phone LIKE prefix%`, `created_at >=`, `created_at <=`, and order `created_at DESC, id DESC`.

- [ ] **Step 5: Run tests and commit**

Run:

```powershell
cd admin_back_go
go test ./internal/module/sms
```

Expected: PASS.

Commit:

```powershell
git add internal/module/sms/dto.go internal/module/sms/repository.go internal/module/sms/repository_test.go
git commit -m "feat: add sms repository contracts"
```

---

### Task 3: Tencent Cloud SMS SDK Boundary

**Files:**
- Create: `admin_back_go/internal/platform/sms/tencentcloudsms/client.go`
- Create: `admin_back_go/internal/platform/sms/tencentcloudsms/client_test.go`
- Modify: `admin_back_go/go.mod`
- Modify: `admin_back_go/go.sum`

- [ ] **Step 1: Add SDK dependency**

Run:

```powershell
cd admin_back_go
go get github.com/tencentcloud/tencentcloud-sdk-go/tencentcloud/sms@v1.3.93
```

Expected: `go.mod` includes `github.com/tencentcloud/tencentcloud-sdk-go/tencentcloud/sms v1.3.93`.

- [ ] **Step 2: Write failing platform tests**

Create `client_test.go`:

```go
package tencentcloudsms

import (
	"errors"
	"reflect"
	"testing"
)

func TestTemplateParamsUseVariableOrder(t *testing.T) {
	got, err := BuildTemplateParams([]string{"code", "ttl_minutes"}, map[string]string{"ttl_minutes": "5", "code": "123456"})
	if err != nil {
		t.Fatalf("BuildTemplateParams returned error: %v", err)
	}
	if want := []string{"123456", "5"}; !reflect.DeepEqual(got, want) {
		t.Fatalf("params = %#v, want %#v", got, want)
	}
}

func TestTemplateParamsRejectMissingVariable(t *testing.T) {
	if _, err := BuildTemplateParams([]string{"code", "ttl_minutes"}, map[string]string{"code": "123456"}); err == nil {
		t.Fatal("expected missing ttl_minutes error")
	}
}

func TestSendErrorExposesTencentCode(t *testing.T) {
	err := SendError{Code: "FailedOperation.TemplateIncorrect", Message: "template incorrect", Cause: errors.New("sdk")}
	if err.ErrorCode() != "FailedOperation.TemplateIncorrect" {
		t.Fatalf("unexpected code: %q", err.ErrorCode())
	}
	if err.Error() != "FailedOperation.TemplateIncorrect: template incorrect" {
		t.Fatalf("unexpected error: %q", err.Error())
	}
}

func TestClientDefaultTimeoutIsBounded(t *testing.T) {
	client := New(0)
	if client.Timeout != defaultTimeout {
		t.Fatalf("default timeout = %s, want %s", client.Timeout, defaultTimeout)
	}
}
```

- [ ] **Step 3: Run tests to verify failure**

```powershell
cd admin_back_go
go test ./internal/platform/sms/tencentcloudsms
```

Expected: compile failure for missing package functions.

- [ ] **Step 4: Implement `client.go`**

Create the SDK wrapper with:

```go
package tencentcloudsms

import (
	"context"
	"fmt"
	"strings"
	"time"

	common "github.com/tencentcloud/tencentcloud-sdk-go/tencentcloud/common"
	tcerr "github.com/tencentcloud/tencentcloud-sdk-go/tencentcloud/common/errors"
	"github.com/tencentcloud/tencentcloud-sdk-go/tencentcloud/common/profile"
	sms "github.com/tencentcloud/tencentcloud-sdk-go/tencentcloud/sms/v20210111"
)

const defaultTimeout = 10 * time.Second

// SendInput is the minimal Tencent Cloud SMS SendSms request shape used by admin_go.
type SendInput struct {
	SecretID       string
	SecretKey      string
	Region         string
	Endpoint       string
	SmsSdkAppID    string
	SignName       string
	ToPhone        string
	TemplateID     string
	TemplateParams []string
}

// SendResult is the sanitized SendSms result persisted by the module.
type SendResult struct {
	RequestID string
	SerialNo  string
	Fee       uint64
}

// Client wraps Tencent Cloud SMS SDK calls.
type Client struct{ Timeout time.Duration }

// New creates a Tencent Cloud SMS client wrapper with a bounded timeout.
func New(timeout time.Duration) *Client { if timeout <= 0 { timeout = defaultTimeout }; return &Client{Timeout: timeout} }

// SendError preserves Tencent Cloud's per-recipient error code without leaking request payloads.
type SendError struct{ Code string; Message string; Cause error }
func (e SendError) Error() string { if e.Code == "" { if e.Message != "" { return e.Message }; return e.Cause.Error() }; return e.Code + ": " + e.Message }
func (e SendError) Unwrap() error { return e.Cause }
func (e SendError) ErrorCode() string { return e.Code }

func BuildTemplateParams(variables []string, values map[string]string) ([]string, error) {
	params := make([]string, 0, len(variables))
	for _, variable := range variables {
		key := strings.TrimSpace(variable)
		value, ok := values[key]
		if !ok {
			return nil, fmt.Errorf("missing sms template variable %s", key)
		}
		params = append(params, value)
	}
	return params, nil
}
```

`Send` must derive a bounded context when the caller has no earlier deadline, then create `sms.NewSendSmsRequest()` and set:

```go
request.SmsSdkAppId = common.StringPtr(strings.TrimSpace(input.SmsSdkAppID))
request.SignName = common.StringPtr(strings.TrimSpace(input.SignName))
request.TemplateId = common.StringPtr(strings.TrimSpace(input.TemplateID))
request.PhoneNumberSet = common.StringPtrs([]string{strings.TrimSpace(input.ToPhone)})
request.TemplateParamSet = common.StringPtrs(input.TemplateParams)
```

After `SendSmsWithContext`, map:

```go
result.RequestID = stringValue(response.Response.RequestId)
result.SerialNo = stringValue(response.Response.SendStatusSet[0].SerialNo)
result.Fee = uint64Value(response.Response.SendStatusSet[0].Fee)
```

If first send status `Code` is non-empty and not `Ok`, return `SendError{Code: code, Message: message}`.

Do not expose request payload, template params, SecretId, or SecretKey in `SendError`.

- [ ] **Step 5: Run tests and commit**

Run:

```powershell
cd admin_back_go
go test ./internal/platform/sms/tencentcloudsms
```

Expected: PASS.

Commit:

```powershell
git add go.mod go.sum internal/platform/sms/tencentcloudsms/client.go internal/platform/sms/tencentcloudsms/client_test.go
git commit -m "feat: add tencent cloud sms client"
```

---

### Task 4: SMS Service Rules

**Files:**
- Create: `admin_back_go/internal/module/sms/service.go`
- Create: `admin_back_go/internal/module/sms/service_test.go`
- Modify: `admin_back_go/internal/i18n/locales/zh-CN/sms.yaml`
- Modify: `admin_back_go/internal/i18n/locales/en-US/sms.yaml`

- [ ] **Step 1: Write failing service tests**

Create `service_test.go` with fake repository/sender and these behaviors:

```go
func TestServiceSendVerifyCodeUsesEnabledConfigTemplateAndWritesSanitizedLogs(t *testing.T) {
	box := testSecretBox()
	secretIDEnc, _ := box.Encrypt("AKID-secret")
	secretKeyEnc, _ := box.Encrypt("SECRET-key")
	repo := &fakeSmsRepository{
		config: &Config{SecretIDEnc: secretIDEnc, SecretKeyEnc: secretKeyEnc, SmsSdkAppID: "1400000000", SignName: "智澜", Region: DefaultRegion, Endpoint: DefaultEndpoint, Status: enum.CommonYes},
		templates: map[string]*Template{
			enum.VerifyCodeSceneLogin: {ID: 77, Scene: enum.VerifyCodeSceneLogin, TencentTemplateID: "123456", VariablesJSON: `["code","ttl_minutes"]`, SampleVariablesJSON: `{"code":"123456","ttl_minutes":"5"}`, Status: enum.CommonYes},
		},
	}
	sender := &fakeSmsSender{result: SendResult{RequestID: "req-1", SerialNo: "serial-1", Fee: 1}}
	service := NewService(repo, box, sender)

	appErr := service.SendVerifyCode(context.Background(), enum.VerifyCodeSceneLogin, "15600000000", "654321", 5*time.Minute)

	if appErr != nil {
		t.Fatalf("expected SendVerifyCode to succeed, got %v", appErr)
	}
	if sender.input.ToPhone != "+8615600000000" || sender.input.TemplateID != "123456" {
		t.Fatalf("unexpected sender input: %#v", sender.input)
	}
	if !reflect.DeepEqual(sender.input.TemplateParams, []string{"654321", "5"}) {
		t.Fatalf("unexpected template params: %#v", sender.input.TemplateParams)
	}
	if strings.Contains(repo.created.ErrorMessage, "654321") {
		t.Fatalf("sms log must not persist verify code: %#v", repo.created)
	}
	if repo.finish.Status != enum.SmsLogStatusSuccess || repo.finish.SerialNo != "serial-1" || repo.finish.Fee != 1 {
		t.Fatalf("unexpected finish log: %#v", repo.finish)
	}
}

func TestServiceRejectsBindEmailSceneForSms(t *testing.T) {
	service := NewService(&fakeSmsRepository{}, testSecretBox(), &fakeSmsSender{})
	appErr := service.SendVerifyCode(context.Background(), enum.VerifyCodeSceneBindEmail, "15600000000", "123456", 5*time.Minute)
	if appErr == nil || appErr.Code != apperror.CodeBadRequest || appErr.MessageID != "sms.scene.invalid" {
		t.Fatalf("expected invalid sms scene error, got %#v", appErr)
	}
}
```

- [ ] **Step 2: Run tests to verify failure**

```powershell
cd admin_back_go
go test ./internal/module/sms
```

Expected: compile failure for missing service.

- [ ] **Step 3: Implement service**

Create `service.go` with:

```go
type Sender interface { Send(ctx context.Context, input SendInput) (SendResult, error) }
type SenderFunc func(ctx context.Context, input SendInput) (SendResult, error)
func (f SenderFunc) Send(ctx context.Context, input SendInput) (SendResult, error) { return f(ctx, input) }
type codedError interface{ ErrorCode() string }
type Service struct{ repository Repository; secretBox secretbox.Box; sender Sender }
func NewService(repository Repository, secretBox secretbox.Box, sender Sender) *Service {
	return &Service{repository: repository, secretBox: secretBox, sender: sender}
}
```

Implement the same public HTTP service method set as `mail.HTTPService`, with SMS DTOs:

```go
PageInit, Config, SaveConfig, DeleteConfig, TestSend,
Templates, CreateTemplate, UpdateTemplate, ChangeTemplateStatus, DeleteTemplate,
Logs, Log, DeleteLogs, SendVerifyCode
```

Required validation:

- phone accepts `1[3-9]\d{9}`, `86...`, or `+86...`; output must be `+86` + 11-digit phone.
- `region` must be `dict.IsSmsRegion(region)`.
- blank endpoint becomes `DefaultEndpoint`.
- `sms_sdk_app_id` and `sign_name` are required.
- first config save requires both secrets; subsequent config saves keep existing encrypted values when blank.
- template scene must pass `enum.IsSmsTemplateScene`; `bind_email` fails.
- template variables and sample variables must be exactly `code` and `ttl_minutes`.
- shared TTL key is `auth.verify_code.ttl_minutes`, saved through `system_settings`.

Required send flow:

```go
result, err := sender.Send(ctx, SendInput{
	SecretID: secretID,
	SecretKey: secretKey,
	Region: cfg.Region,
	Endpoint: cfg.Endpoint,
	SmsSdkAppID: cfg.SmsSdkAppID,
	SignName: cfg.SignName,
	ToPhone: normalizedPhone,
	TemplateID: tmpl.TencentTemplateID,
	TemplateParams: params,
})
```

Create pending log before the SDK call, finish success with `RequestID`, `SerialNo`, `Fee`, `DurationMS`, `SentAt`, and finish failure with provider error code plus truncated message.

No retry loop is allowed in `Service`. If Tencent returns an error, finish the same log as failed and return a localized error. Retrying belongs to a future explicitly specified queue/outbox slice, not this management slice.

- [ ] **Step 4: Add backend i18n catalogs**

Create `zh-CN/sms.yaml` and `en-US/sms.yaml`. Required keys:

```yaml
sms.repository_missing: 短信仓储未配置
sms.sender_missing: 短信发送器未配置
sms.service_missing: 短信服务未配置
sms.config.query_failed: 查询短信配置失败
sms.config.save_failed: 保存短信配置失败
sms.config.delete_failed: 删除短信配置失败
sms.config.test_result_failed: 更新短信测试结果失败
sms.config.not_configured: 短信服务未配置
sms.config.disabled: 短信服务已禁用
sms.secret.encrypt_failed: 加密短信密钥失败
sms.secret.decrypt_id_failed: 解密 Tencent SecretId 失败
sms.secret.decrypt_key_failed: 解密 Tencent SecretKey 失败
sms.secret.required: 首次配置必须填写腾讯云 SecretId 和 SecretKey
sms.secret.missing: 腾讯云短信密钥未配置
sms.scene.invalid: 无效的短信模板场景
sms.phone.invalid: 手机号格式不正确
sms.code.empty: 验证码不能为空
sms.template.query_failed: 查询短信模板失败
sms.template.parse_failed: 解析短信模板失败
sms.template.save_failed: 保存短信模板失败
sms.template.update_failed: 更新短信模板失败
sms.template.status_failed: 修改短信模板状态失败
sms.template.delete_failed: 删除短信模板失败
sms.template.not_found: 短信模板不存在
sms.template.not_configured: 短信模板未配置
sms.template.disabled: 短信模板已禁用
sms.template.id.invalid: 无效的短信模板ID
sms.template.name.empty: 短信模板名称不能为空
sms.template.tencent_id.empty: 腾讯云模板 ID 不能为空
sms.template.variables.invalid: 短信模板变量只允许 code 和 ttl_minutes
sms.template.variables.missing: 短信模板变量缺少 {{.name}}
sms.template.variables.extra: 短信模板变量多余 {{.name}}
sms.template.sample.invalid: 短信模板样例变量必须与变量列表一致
sms.log.write_failed: 写入短信日志失败
sms.log.update_failed: 更新短信日志失败
sms.log.query_failed: 查询短信日志失败
sms.log.template_query_failed: 查询短信日志模板失败
sms.log.template_parse_failed: 解析短信日志模板变量失败
sms.log.not_found: 短信日志不存在
sms.log.id.invalid: 无效的短信日志ID
sms.log.delete.empty: 请选择要删除的短信日志
sms.log.delete_failed: 删除短信日志失败
sms.log.scene.invalid: 无效的短信日志场景
sms.log.status.invalid: 无效的短信日志状态
sms.send_failed: 短信发送失败
sms.ttl.query_failed: 查询验证码有效期配置失败
sms.ttl.save_failed: 保存验证码有效期配置失败
sms.ttl.cache_failed: 清理验证码有效期配置缓存失败
sms.ttl.invalid: 验证码有效期必须为 1 到 60 分钟
sms.date.invalid: 时间格式错误
sms.current_page.invalid: 当前页无效
sms.page_size.invalid: 每页数量无效
```

The English file must contain the same keys with English values.

- [ ] **Step 5: Run tests and commit**

```powershell
cd admin_back_go
go test ./internal/module/sms ./internal/i18n
```

Expected: PASS.

Commit:

```powershell
git add internal/module/sms/service.go internal/module/sms/service_test.go internal/i18n/locales/zh-CN/sms.yaml internal/i18n/locales/en-US/sms.yaml
git commit -m "feat: add sms service rules"
```

---

### Task 5: HTTP Routes, Bootstrap, Permissions, and Operation Logs

**Files:**
- Create: `admin_back_go/internal/module/sms/request.go`
- Create: `admin_back_go/internal/module/sms/handler.go`
- Create: `admin_back_go/internal/module/sms/route.go`
- Create: `admin_back_go/internal/module/sms/handler_test.go`
- Modify: `admin_back_go/internal/server/router.go`
- Modify: `admin_back_go/internal/server/router_test.go`
- Modify: `admin_back_go/internal/bootstrap/app.go`
- Modify: `admin_back_go/internal/bootstrap/route_meta.go`
- Modify: `admin_back_go/internal/bootstrap/route_meta_test.go`
- Modify: `admin_back_go/internal/module/README.md`

- [ ] **Step 1: Add handler tests**

Create handler tests that assert:

```go
GET /api/admin/v1/sms/page-init returns dict.sms_scene_arr and default_endpoint
GET /api/admin/v1/sms/config never returns secret_id_enc, secret_key_enc, cipher, or AKID
GET /api/admin/v1/sms/logs/:id never returns template_params, TemplateParams, verify_code, or 654321
PUT /api/admin/v1/sms/config binds secret_id, secret_key, sms_sdk_app_id, sign_name, region, endpoint, status, verify_code_ttl_minutes
```

- [ ] **Step 2: Implement request/handler/route**

`request.go` must define JSON/query fields:

```go
saveConfigRequest: secret_id, secret_key, sms_sdk_app_id, sign_name, region, endpoint, status, verify_code_ttl_minutes
testRequest: to_phone, template_scene
templateRequest: scene, name, tencent_template_id, variables, sample_variables, status
logListRequest: current_page, page_size, scene, status, to_phone, created_at_start, created_at_end
deleteLogsRequest: ids
```

`route.go` must register exactly:

```text
GET    /api/admin/v1/sms/page-init
GET    /api/admin/v1/sms/config
PUT    /api/admin/v1/sms/config
DELETE /api/admin/v1/sms/config
POST   /api/admin/v1/sms/test
GET    /api/admin/v1/sms/templates
POST   /api/admin/v1/sms/templates
PUT    /api/admin/v1/sms/templates/:id
PATCH  /api/admin/v1/sms/templates/:id/status
DELETE /api/admin/v1/sms/templates/:id
GET    /api/admin/v1/sms/logs
GET    /api/admin/v1/sms/logs/:id
DELETE /api/admin/v1/sms/logs/:id
DELETE /api/admin/v1/sms/logs
```

- [ ] **Step 3: Add route metadata**

Permission rules:

```go
PUT /api/admin/v1/sms/config -> system_sms_configEdit
DELETE /api/admin/v1/sms/config -> system_sms_configDel
POST /api/admin/v1/sms/test -> system_sms_test
POST /api/admin/v1/sms/templates -> system_sms_templateAdd
PUT /api/admin/v1/sms/templates/:id -> system_sms_templateEdit
PATCH /api/admin/v1/sms/templates/:id/status -> system_sms_templateStatus
DELETE /api/admin/v1/sms/templates/:id -> system_sms_templateDel
DELETE /api/admin/v1/sms/logs/:id -> system_sms_logDel
DELETE /api/admin/v1/sms/logs -> system_sms_logDel
```

Operation rules use `Module: "sms"` and actions:

```text
update_config, delete_config, test_send, create_template, update_template,
change_template_status, delete_template, delete_log, delete_logs
```

- [ ] **Step 4: Wire bootstrap**

In `router.go`, import `internal/module/sms`, add `SmsService sms.HTTPService` to dependencies, and call:

```go
sms.RegisterRoutes(router, deps.SmsService)
```

In `bootstrap/app.go`, import aliases:

```go
smsmodule "admin_back_go/internal/module/sms"
platformsms "admin_back_go/internal/platform/sms/tencentcloudsms"
```

Wire:

```go
smsClient := platformsms.New(10 * time.Second)
smsSender := smsmodule.SenderFunc(func(ctx context.Context, input smsmodule.SendInput) (smsmodule.SendResult, error) {
	result, err := smsClient.Send(ctx, platformsms.SendInput{
		SecretID: input.SecretID,
		SecretKey: input.SecretKey,
		Region: input.Region,
		Endpoint: input.Endpoint,
		SmsSdkAppID: input.SmsSdkAppID,
		SignName: input.SignName,
		ToPhone: input.ToPhone,
		TemplateID: input.TemplateID,
		TemplateParams: input.TemplateParams,
	})
	if err != nil {
		return smsmodule.SendResult{}, err
	}
	return smsmodule.SendResult{RequestID: result.RequestID, SerialNo: result.SerialNo, Fee: result.Fee}, nil
})
smsService := smsmodule.NewService(smsmodule.NewGormRepository(resources.DB, resources.Redis), secretBox, smsSender)
```

Pass `SmsService: smsService`.

- [ ] **Step 5: Run tests and commit**

```powershell
cd admin_back_go
go test ./internal/module/sms ./internal/bootstrap ./internal/server
```

Expected: PASS.

Commit:

```powershell
git add internal/module/sms/request.go internal/module/sms/handler.go internal/module/sms/route.go internal/module/sms/handler_test.go internal/server/router.go internal/server/router_test.go internal/bootstrap/app.go internal/bootstrap/route_meta.go internal/bootstrap/route_meta_test.go internal/module/README.md
git commit -m "feat: wire sms admin api"
```

---

### Task 6: Frontend API, Page, and I18n

**Files:**
- Create: `admin_front_ts/src/api/system/sms.ts`
- Create: `admin_front_ts/src/views/Main/system/sms/index.vue`
- Create: `admin_front_ts/src/views/Main/system/sms/smsDict.ts`
- Create: `admin_front_ts/src/views/Main/system/sms/components/SmsConfigPanel.vue`
- Create: `admin_front_ts/src/views/Main/system/sms/components/SmsTemplatePanel.vue`
- Create: `admin_front_ts/src/views/Main/system/sms/components/SmsLogPanel.vue`
- Create: `admin_front_ts/tests/shared/system/sms-api.test.ts`
- Modify: `admin_front_ts/src/i18n/locales/zh-CN.ts`
- Modify: `admin_front_ts/src/i18n/locales/en-US.ts`

- [ ] **Step 1: Write failing frontend contract test**

Create `tests/shared/system/sms-api.test.ts` asserting:

```ts
src/api/system/sms.ts imports request and ADMIN_API_PREFIX
SmsApi uses /sms/page-init, /sms/config, /sms/test, /sms/templates, /sms/logs
SmsRegion is exactly 'ap-guangzhou'
SMS files never contain secret_id_enc, secret_key_enc, template_params, TemplateParams, any, Record<string, any>
config panel uses system_sms_configEdit, system_sms_configDel, system_sms_test
template panel uses system_sms_templateAdd, system_sms_templateEdit, system_sms_templateStatus, system_sms_templateDel
log panel uses system_sms_logDel
log panel imports Search, useCrudTable, AppTable, AppDialog
```

Run:

```powershell
cd admin_front_ts
npm run test -- tests/shared/system/sms-api.test.ts
```

Expected: FAIL because SMS frontend files do not exist.

- [ ] **Step 2: Create typed API client**

`src/api/system/sms.ts` must expose these types:

```ts
export type SmsCommonStatus = 1 | 2
export type SmsLogStatus = 1 | 2 | 3
export type SmsTemplateScene = 'login' | 'forget' | 'bind_phone' | 'change_password'
export type SmsLogScene = SmsTemplateScene | 'test'
export type SmsRegion = 'ap-guangzhou'
```

Use `BASE = `${ADMIN_API_PREFIX}/sms`` and methods:

```ts
pageInit, config, saveConfig, deleteConfig, test,
templates, createTemplate, updateTemplate, updateTemplateStatus, deleteTemplate,
logs, log, deleteLog, deleteLogs
```

`normalizeLogParams` only sends non-empty `scene`, numeric `status`, trimmed `to_phone`, and date strings.

Do not add duplicate aliases such as `addTemplate`, `editTemplate`, or `changeTemplateStatus` for SMS. Mail has historical aliases, but this new module does not need them.

- [ ] **Step 3: Create dict helper and tab shell**

`smsDict.ts`:

```ts
export function createDefaultSmsDict(): SmsPageInitResponse['dict'] {
  return {
    common_status_arr: [],
    sms_scene_arr: [],
    sms_log_scene_arr: [],
    sms_log_status_arr: [],
    sms_region_arr: [{ label: '广州', value: 'ap-guangzhou' }],
    default_region: 'ap-guangzhou',
    default_endpoint: 'sms.tencentcloudapi.com',
    default_ttl_minutes: 5,
  }
}
export function normalizeSmsDict(dict: SmsPageInitResponse['dict']): SmsPageInitResponse['dict'] {
  return { ...createDefaultSmsDict(), ...dict }
}
```

`index.vue` must lazy-load `SmsConfigPanel`, `SmsTemplatePanel`, and `SmsLogPanel`, use `t('sms.tabs.config')`, `t('sms.tabs.template')`, `t('sms.tabs.log')`, and refresh logs when the log tab is reactivated.

- [ ] **Step 4: Create panels**

`SmsConfigPanel.vue`:

- fields: `secret_id`, `secret_key`, `sms_sdk_app_id`, `sign_name`, `region`, `endpoint`, `verify_code_ttl_minutes`, `status`.
- test fields: `to_phone`, `template_scene`.
- region uses `<el-select-v2 :options="dict.sms_region_arr">`.
- TTL uses `<el-input-number :controls="false">`.
- permissions: `system_sms_configEdit`, `system_sms_configDel`, `system_sms_test`.

`SmsTemplatePanel.vue`:

- table columns: ID, scene, name, tencent_template_id, variables, status, updated_at, actions.
- form fields: scene, name, tencent_template_id, variables, sample variables, status.
- fixed variables are exactly `['code', 'ttl_minutes']`.
- no `subject` field.
- permissions: `system_sms_templateAdd`, `system_sms_templateEdit`, `system_sms_templateStatus`, `system_sms_templateDel`.

`SmsLogPanel.vue`:

- use `Search`, `useCrudTable`, `AppTable`, and `AppDialog`.
- filters: scene, status, to_phone, dateRange.
- columns: ID, scene, to_phone, status, error_code, duration_ms, tencent_fee, created_at, actions.
- detail fields: RequestId, SerialNo, fee, error code/message, sent_at, created_at, template summary.
- permission: `system_sms_logDel`.

- [ ] **Step 5: Add i18n**

Add `menu.system_sms` next to `menu.system_mail`.

Add top-level `sms` labels in both locale files. Required zh-CN labels include:

```ts
tabs: { config: '短信配置', template: '短信模板', log: '发送日志' }
config.notice: '仅管理已在腾讯云审核通过的短信签名和模板，本页不申请签名或模板。'
config.smsSdkAppId: '短信应用 ID'
config.signName: '短信签名'
config.verifyCodeTTLHelp: '邮件和短信验证码共用该 TTL，模板变量 ttl_minutes 使用此值。'
template.tencentTemplateId: '腾讯云模板 ID'
template.rules.verifyCodeVariables: '验证码短信变量只能是 code 和 ttl_minutes'
log.securityNotice: '日志只记录发送事实，不保存短信正文、验证码或完整模板参数。'
```

English labels must use the same object structure.

- [ ] **Step 6: Run checks and commit**

```powershell
cd admin_front_ts
npm run test -- tests/shared/system/sms-api.test.ts
npx vue-tsc -b --pretty false
```

Expected: PASS.

Commit:

```powershell
git add src/api/system/sms.ts src/views/Main/system/sms src/i18n/locales/zh-CN.ts src/i18n/locales/en-US.ts tests/shared/system/sms-api.test.ts
git commit -m "feat: add sms management frontend"
```

---

### Task 7: Contracts, Status, Smoke, and Final Verification

**Files:**
- Modify: `docs/contracts/admin-api-v1.md`
- Modify: `docs/status/current-status.md`
- Modify: `docs/testing/smoke-matrix.md`
- Modify: `admin_back_go/docs/architecture.md`
- Modify: `docs/superpowers/specs/2026-05-15-sms-management-tencent-cloud-design.md`

- [ ] **Step 1: Add API contract**

Add `## SMS Tencent Cloud` with all routes:

```text
GET    /api/admin/v1/sms/page-init
GET    /api/admin/v1/sms/config
PUT    /api/admin/v1/sms/config
DELETE /api/admin/v1/sms/config
POST   /api/admin/v1/sms/test
GET    /api/admin/v1/sms/templates
POST   /api/admin/v1/sms/templates
PUT    /api/admin/v1/sms/templates/:id
PATCH  /api/admin/v1/sms/templates/:id/status
DELETE /api/admin/v1/sms/templates/:id
GET    /api/admin/v1/sms/logs
GET    /api/admin/v1/sms/logs/:id
DELETE /api/admin/v1/sms/logs/:id
DELETE /api/admin/v1/sms/logs
```

State:

```text
config response never returns secret_id_enc / secret_key_enc / plaintext secrets.
logs never return SMS body, verification code, or template params.
auth/send-code phone behavior is unchanged in this slice.
```

- [ ] **Step 2: Add architecture boundary**

In `admin_back_go/docs/architecture.md`, add:

```text
internal/module/sms owns sms_configs / sms_templates / sms_logs.
internal/platform/sms/tencentcloudsms is the only Tencent SMS SDK boundary.
Only Tencent Cloud SMS SendSms is supported.
SmsSdkAppId, SignName, Region, and Endpoint all participate in real send.
SecretId / SecretKey are encrypted with secretbox and only hints are returned by HTTP.
sms_logs record scene, phone, RequestId, SerialNo, Fee, error code/message, duration, and status; they do not store body, code, or template params.
auth/send-code phone stays fixed 123456 in this slice.
```

- [ ] **Step 3: Add smoke probes**

Add read-only probes:

```powershell
Invoke-RestMethod "$Base/api/admin/v1/sms/page-init" -Headers $Headers
Invoke-RestMethod "$Base/api/admin/v1/sms/config" -Headers $Headers
Invoke-RestMethod "$Base/api/admin/v1/sms/templates" -Headers $Headers
Invoke-RestMethod "$Base/api/admin/v1/sms/logs?current_page=1&page_size=20" -Headers $Headers
```

Expected:

```text
page-init.data.dict.sms_scene_arr contains login / forget / bind_phone / change_password
config.data does not contain secret_id_enc or secret_key_enc
templates.data.list is an array
logs.data.list is an array and logs.data.page exists
```

- [ ] **Step 4: Update status after verification**

In `docs/status/current-status.md`, add an SMS row only after Step 5 passes. The row must explicitly say:

```text
auth/send-code phone behavior remains fixed 123456.
real Tencent SMS send requires enabled config, approved sign name, and approved template IDs.
no sign/template application, webhook, retry queue, multi-provider, marketing SMS, or international SMS.
```

Mark `docs/superpowers/specs/2026-05-15-sms-management-tencent-cloud-design.md` as `已实现` only after Step 5 passes.

- [ ] **Step 5: Final verification**

Backend:

```powershell
cd admin_back_go
go test ./internal/module/sms ./internal/platform/sms/tencentcloudsms ./internal/bootstrap ./internal/server ./internal/i18n
go test ./...
```

Frontend:

```powershell
cd admin_front_ts
npm run test -- tests/shared/system/sms-api.test.ts
npx vue-tsc -b --pretty false
```

Residue checks:

```powershell
cd E:\admin_go
rg -n "secret_id_enc|secret_key_enc|template_params|TemplateParams|verify_code" admin_front_ts/src/api/system/sms.ts admin_front_ts/src/views/Main/system/sms
rg -n "bind_email" admin_back_go/internal/module/sms admin_front_ts/src/api/system/sms.ts admin_front_ts/src/views/Main/system/sms
```

Expected:

```text
all tests pass
both residue checks print no lines
```

- [ ] **Step 6: Commit docs in the correct repos**

```powershell
cd E:\admin_go\admin_back_go
git add docs/architecture.md
git commit -m "docs: document sms runtime boundary"

cd E:\admin_go
git add docs/contracts/admin-api-v1.md docs/status/current-status.md docs/testing/smoke-matrix.md docs/superpowers/specs/2026-05-15-sms-management-tencent-cloud-design.md docs/superpowers/plans/2026-05-15-sms-management-tencent-cloud.md
git commit -m "docs: refresh sms management contract and plan"
```

Do not stage unrelated dirty files from `admin_front_ts`, especially payment recharge work that existed before this SMS slice started.

---

## Self-Review Checklist

- Spec coverage: config, templates, logs, test send, Tencent `SendSms`, secret hints, shared TTL, domestic phone normalization, soft delete, timestamps, route permissions, operation logs, frontend typed API, i18n, docs, and smoke are covered.
- Scope control: `auth/send-code` remains unchanged; sign application, template application, webhook, retry queue, multi-provider, marketing SMS, and international SMS are outside this slice.
- Field usage: every `sms_configs`, `sms_templates`, and `sms_logs` field has a runtime read/write path or display path.
- Contract safety: frontend never sees encrypted secrets, plaintext secrets, SMS body, verification code, or template params.
- Compatibility: existing mail/auth routes are not renamed or removed.
