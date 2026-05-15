# Payment Config Rebuild V1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 重做支付第一版的唯一 active slice：支付宝支付配置、私有证书上传、配置测试、菜单权限和前端配置页。

**Architecture:** `payment_configs` 成为支付配置唯一 active runtime 表；旧 `payment_channels/payment_channel_configs` 只作为迁移来源，不再被 Go/Vue runtime 读取。后端仍在 `internal/module/payment`，保持 `route -> handler -> service -> repository -> model`，支付宝 SDK 仍只允许在 `internal/platform/payment/alipay`；前端只保留 `/payment/config` 页面和 `src/api/payment/config.ts`。钱包、充值入账、订单、事件、退款、提现、对账、微信全部不进入第一版。

**Tech Stack:** Go, Gin, GORM, MySQL/InnoDB, existing secretbox, existing RBAC/OperationLog/route meta, go-pay/gopay behind platform boundary, Vue 3 + TypeScript + Element Plus + existing `request` client + Vitest.

---

## Scope Lock

只做：

```text
payment_configs schema
Alipay config CRUD
private certificate upload into runtime/payment/certs/alipay/<config_code>/<sha256>.crt
local config validation and test
enable-before-test guard
payment_config_* permission codes
/payment/config menu
Vue payment config page
contract/status/smoke/architecture docs
```

不做：

```text
wallet
recharge
payment order rebuild
payment notify/event rebuild
refund
withdraw
split settlement
reconcile
WeChat
product/package/member billing
```

Linus check:

```text
True problem: yes, current payment config is still channel-shaped and carries provider/sign_type/merchant_id/extra_config baggage.
Simpler way: one Alipay config table, one config page, one private cert store.
What breaks: old /payment/channel, /payment/order, /payment/event menus and payment_channel/payment_order/payment_event permission codes. Break them deliberately through migration, route meta, frontend tests, and smoke.
```

Live facts checked before writing this plan:

```text
DB tables: payment_channel_configs, payment_channels, payment_events, payment_orders
Active menu: /payment/channel, /payment/order, /payment/event
Active button codes: payment_channel_add/edit/status/del, payment_order_close
Current backend routes: /api/admin/v1/payment/channels, /orders, /events, /api/payment/notify/alipay
Current frontend files: src/api/payment/channel.ts, order.ts, event.ts and views/Main/payment/{channel,order,event}
```

---

## File Map

### Create

```text
admin_back_go/database/migrations/20260515_payment_config_rebuild_v1.sql
admin_back_go/database/migrations/20260515_payment_config_only_cleanup.sql
admin_back_go/internal/platform/payment/certstore.go
admin_back_go/internal/platform/payment/certstore_test.go
admin_back_go/internal/platform/payment/alipay/config_test.go
admin_back_go/internal/module/payment/config_repository_test.go
admin_back_go/internal/module/payment/config_service_test.go
admin_back_go/internal/module/payment/config_handler_test.go
admin_front_ts/src/api/payment/config.ts
admin_front_ts/src/views/Main/payment/config/index.vue
admin_front_ts/src/views/Main/payment/config/composables/usePaymentConfigPage.ts
admin_front_ts/tests/shared/payment/payment-config-api.test.ts
admin_front_ts/tests/shared/payment/payment-config-page.test.ts
```

### Modify

```text
admin_back_go/internal/module/payment/model.go
admin_back_go/internal/module/payment/dto.go
admin_back_go/internal/module/payment/request.go
admin_back_go/internal/module/payment/repository.go
admin_back_go/internal/module/payment/service.go
admin_back_go/internal/module/payment/handler.go
admin_back_go/internal/module/payment/route.go
admin_back_go/internal/bootstrap/app.go
admin_back_go/internal/bootstrap/worker.go
admin_back_go/internal/bootstrap/route_meta.go
admin_back_go/internal/bootstrap/route_meta_test.go
admin_back_go/internal/server/router_test.go
admin_back_go/internal/jobs/noop.go
admin_back_go/internal/jobs/noop_test.go
admin_back_go/scripts/check-payment-certs.ps1
admin_back_go/scripts/full-admin-smoke.ps1
admin_front_ts/src/i18n/locales/zh-CN.ts
admin_front_ts/src/i18n/locales/en-US.ts
admin_front_ts/tests/shared/router/view-registry.test.ts
admin_front_ts/tests/shared/router/runtime-route-tree.test.ts
docs/contracts/admin-api-v1.md
docs/status/current-status.md
docs/testing/smoke-matrix.md
admin_back_go/docs/architecture.md
```

### Delete after replacement compiles

```text
admin_front_ts/src/api/payment/channel.ts
admin_front_ts/src/api/payment/order.ts
admin_front_ts/src/api/payment/event.ts
admin_front_ts/src/views/Main/payment/channel
admin_front_ts/src/views/Main/payment/order
admin_front_ts/src/views/Main/payment/event
admin_front_ts/tests/shared/payment/payment-channel-api.test.ts
admin_front_ts/tests/shared/payment/payment-order-api.test.ts
admin_front_ts/tests/shared/payment/payment-event-api.test.ts
```

This slice now physically removes the old payment runtime after config migration. `20260515_payment_config_only_cleanup.sql` drops `payment_channels`, `payment_channel_configs`, `payment_orders`, and `payment_events`, and deletes retired payment channel/order/event permissions plus old payment cron rows. Future payment-order slices must rebuild tables from a new spec instead of inheriting the old schema.

---

## Contract Lock

### API

```text
GET    /api/admin/v1/payment/configs/page-init
GET    /api/admin/v1/payment/configs
POST   /api/admin/v1/payment/configs
PUT    /api/admin/v1/payment/configs/:id
PATCH  /api/admin/v1/payment/configs/:id/status
DELETE /api/admin/v1/payment/configs/:id
POST   /api/admin/v1/payment/certificates
POST   /api/admin/v1/payment/configs/:id/test
```

### Permission Codes

```text
payment_config_list
payment_config_add
payment_config_edit
payment_config_status
payment_config_del
payment_config_upload_cert
payment_config_test
```

Retired from active runtime:

```text
payment_channel_*
payment_order_*
payment_event_*
```

### Field Ban

The first version must not create or return:

```text
provider
merchant_id
sign_type
extra_config
cert_content
cert_url
created_by
updated_by
```

---

## Task 1: Schema, Menu, RBAC, and Cron Retirement Migration

**Files:**
- Create: `admin_back_go/database/migrations/20260515_payment_config_rebuild_v1.sql`
- Create: `admin_back_go/database/migrations/20260515_payment_config_only_cleanup.sql`

- [x] **Step 1: Create the migration file**

Create `admin_back_go/database/migrations/20260515_payment_config_rebuild_v1.sql` with this structure:

```sql
CREATE TABLE IF NOT EXISTS `payment_configs` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `provider` VARCHAR(32) NOT NULL DEFAULT 'alipay',
  `code` VARCHAR(64) NOT NULL,
  `name` VARCHAR(128) NOT NULL,
  `app_id` VARCHAR(64) NOT NULL,
  `private_key_enc` TEXT NOT NULL,
  `private_key_hint` VARCHAR(64) NOT NULL DEFAULT '',
  `app_cert_path` VARCHAR(512) NOT NULL DEFAULT '',
  `platform_cert_path` VARCHAR(512) NOT NULL DEFAULT '',
  `root_cert_path` VARCHAR(512) NOT NULL DEFAULT '',
  `notify_url` VARCHAR(512) NOT NULL DEFAULT '',
  `environment` VARCHAR(16) NOT NULL DEFAULT 'sandbox',
  `enabled_methods_json` JSON NOT NULL,
  `status` TINYINT NOT NULL DEFAULT 2,
  `remark` VARCHAR(255) NOT NULL DEFAULT '',
  `is_del` TINYINT NOT NULL DEFAULT 2,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_payment_configs_code` (`code`),
  KEY `idx_payment_configs_provider_status` (`provider`, `status`, `is_del`),
  KEY `idx_payment_configs_environment` (`environment`, `is_del`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `payment_configs` (
  `provider`, `code`, `name`, `app_id`, `private_key_enc`, `private_key_hint`,
  `app_cert_path`, `platform_cert_path`, `root_cert_path`,
  `notify_url`, `environment`, `enabled_methods_json`,
  `status`, `remark`, `is_del`, `created_at`, `updated_at`
)
SELECT
  'alipay',
  ch.`code`,
  ch.`name`,
  cfg.`app_id`,
  COALESCE(cfg.`private_key_enc`, ''),
  COALESCE(cfg.`private_key_hint`, ''),
  cfg.`app_cert_path`,
  cfg.`alipay_cert_path`,
  cfg.`alipay_root_cert_path`,
  cfg.`notify_url`,
  CASE WHEN cfg.`is_sandbox` = 1 THEN 'sandbox' ELSE 'production' END,
  CASE
    WHEN JSON_VALID(ch.`supported_methods`) AND JSON_LENGTH(ch.`supported_methods`) > 0 THEN ch.`supported_methods`
    ELSE JSON_ARRAY('web', 'h5')
  END,
  ch.`status`,
  ch.`remark`,
  ch.`is_del`,
  ch.`created_at`,
  ch.`updated_at`
FROM `payment_channels` ch
JOIN `payment_channel_configs` cfg ON cfg.`channel_id` = ch.`id`
WHERE ch.`provider` = 'alipay'
  AND ch.`is_del` = 2
ON DUPLICATE KEY UPDATE
  `name` = VALUES(`name`),
  `app_id` = VALUES(`app_id`),
  `private_key_enc` = VALUES(`private_key_enc`),
  `private_key_hint` = VALUES(`private_key_hint`),
  `app_cert_path` = VALUES(`app_cert_path`),
  `platform_cert_path` = VALUES(`platform_cert_path`),
  `root_cert_path` = VALUES(`root_cert_path`),
  `notify_url` = VALUES(`notify_url`),
  `environment` = VALUES(`environment`),
  `enabled_methods_json` = VALUES(`enabled_methods_json`),
  `status` = VALUES(`status`),
  `remark` = VALUES(`remark`),
  `is_del` = 2,
  `updated_at` = CURRENT_TIMESTAMP;
```

- [x] **Step 2: Add idempotent payment menu and button permissions**

Append SQL that keeps the root `payment` DIR, creates `/payment/config`, copies role grants, and retires old visible payment pages:

```sql
SET @payment_parent_id := (
  SELECT `id`
  FROM `permissions`
  WHERE `platform` = 'admin'
    AND `type` = 1
    AND `is_del` = 2
    AND `code` = 'payment'
  ORDER BY `id`
  LIMIT 1
);

INSERT INTO `permissions` (`name`, `path`, `icon`, `parent_id`, `component`, `platform`, `type`, `sort`, `code`, `i18n_key`, `show_menu`, `status`, `is_del`)
SELECT '支付配置', '/payment/config', 'CreditCard', @payment_parent_id, 'payment/config', 'admin', 2, 10, 'payment_config_list', 'menu.payment_config', 1, 1, 2
WHERE @payment_parent_id IS NOT NULL
ON DUPLICATE KEY UPDATE
  `name` = VALUES(`name`),
  `path` = VALUES(`path`),
  `icon` = VALUES(`icon`),
  `parent_id` = VALUES(`parent_id`),
  `component` = VALUES(`component`),
  `type` = VALUES(`type`),
  `sort` = VALUES(`sort`),
  `i18n_key` = VALUES(`i18n_key`),
  `show_menu` = 1,
  `status` = 1,
  `is_del` = 2,
  `updated_at` = CURRENT_TIMESTAMP;

SET @payment_config_page_id := (
  SELECT `id`
  FROM `permissions`
  WHERE `platform` = 'admin'
    AND `code` = 'payment_config_list'
  LIMIT 1
);

INSERT INTO `permissions` (`name`, `path`, `icon`, `parent_id`, `component`, `platform`, `type`, `sort`, `code`, `i18n_key`, `show_menu`, `status`, `is_del`)
SELECT button_name, '', '', @payment_config_page_id, '', 'admin', 3, button_sort, button_code, '', 2, 1, 2
FROM (
  SELECT '新增支付配置' AS button_name, 'payment_config_add' AS button_code, 1 AS button_sort
  UNION ALL SELECT '编辑支付配置', 'payment_config_edit', 2
  UNION ALL SELECT '切换支付配置状态', 'payment_config_status', 3
  UNION ALL SELECT '删除支付配置', 'payment_config_del', 4
  UNION ALL SELECT '上传支付宝证书', 'payment_config_upload_cert', 5
  UNION ALL SELECT '测试支付配置', 'payment_config_test', 6
) AS payment_config_buttons
WHERE @payment_config_page_id IS NOT NULL
ON DUPLICATE KEY UPDATE
  `name` = VALUES(`name`),
  `parent_id` = VALUES(`parent_id`),
  `type` = VALUES(`type`),
  `sort` = VALUES(`sort`),
  `show_menu` = 2,
  `status` = 1,
  `is_del` = 2,
  `updated_at` = CURRENT_TIMESTAMP;
```

- [x] **Step 3: Add role grant migration and retire old codes**

Append this role mapping. It must run before old permission rows are soft-deleted:

```sql
CREATE TEMPORARY TABLE IF NOT EXISTS `tmp_payment_config_permission_map` (
  `old_code` VARCHAR(100) NOT NULL,
  `new_code` VARCHAR(100) NOT NULL,
  PRIMARY KEY (`old_code`, `new_code`)
) ENGINE=MEMORY;

TRUNCATE TABLE `tmp_payment_config_permission_map`;

INSERT INTO `tmp_payment_config_permission_map` (`old_code`, `new_code`) VALUES
  ('payment_channel_list', 'payment_config_list'),
  ('payment_channel_add', 'payment_config_add'),
  ('payment_channel_add', 'payment_config_upload_cert'),
  ('payment_channel_add', 'payment_config_test'),
  ('payment_channel_edit', 'payment_config_edit'),
  ('payment_channel_edit', 'payment_config_upload_cert'),
  ('payment_channel_edit', 'payment_config_test'),
  ('payment_channel_status', 'payment_config_status'),
  ('payment_channel_del', 'payment_config_del');

INSERT INTO `role_permissions` (`role_id`, `permission_id`, `is_del`)
SELECT DISTINCT rp.`role_id`, new_p.`id`, 2
FROM `role_permissions` rp
JOIN `permissions` old_p ON old_p.`id` = rp.`permission_id`
JOIN `tmp_payment_config_permission_map` m ON m.`old_code` = old_p.`code`
JOIN `permissions` new_p ON new_p.`platform` = 'admin'
  AND new_p.`is_del` = 2
  AND new_p.`code` = m.`new_code`
WHERE rp.`is_del` = 2
  AND old_p.`is_del` = 2
ON DUPLICATE KEY UPDATE
  `is_del` = 2,
  `updated_at` = CURRENT_TIMESTAMP;

UPDATE `role_permissions` rp
JOIN `permissions` p ON p.`id` = rp.`permission_id`
SET rp.`is_del` = 1,
    rp.`updated_at` = CURRENT_TIMESTAMP
WHERE p.`platform` = 'admin'
  AND p.`code` IN (
    'payment_channel_list',
    'payment_channel_add',
    'payment_channel_edit',
    'payment_channel_status',
    'payment_channel_del',
    'payment_order_list',
    'payment_order_close',
    'payment_event_list'
  );

UPDATE `permissions`
SET `is_del` = 1,
    `status` = 2,
    `show_menu` = 2,
    `updated_at` = CURRENT_TIMESTAMP
WHERE `platform` = 'admin'
  AND `code` IN (
    'payment_channel_list',
    'payment_channel_add',
    'payment_channel_edit',
    'payment_channel_status',
    'payment_channel_del',
    'payment_order_list',
    'payment_order_close',
    'payment_event_list'
  );

UPDATE `cron_tasks`
SET `status` = 2,
    `updated_at` = CURRENT_TIMESTAMP
WHERE `name` IN ('payment_close_expired_order', 'payment_sync_pending_order');

DROP TEMPORARY TABLE IF EXISTS `tmp_payment_config_permission_map`;
```

- [x] **Step 4: Static migration review**

Create `admin_back_go/database/migrations/20260515_payment_config_only_cleanup.sql` after the rebuild migration. It must:

```text
delete retired payment_channel/payment_order/payment_event role grants
delete retired payment_channel/payment_order/payment_event permission rows
delete old payment order cron rows/logs
drop payment_events, payment_orders, payment_channel_configs, payment_channels
```

Run:

```powershell
cd E:\admin_go
Select-String -Path .\admin_back_go\database\migrations\20260515_payment_config_rebuild_v1.sql -Pattern 'payment_configs','payment_config_list','payment_config_upload_cert','payment_channel_list'
Select-String -Path .\admin_back_go\database\migrations\20260515_payment_config_only_cleanup.sql -Pattern 'DROP TABLE IF EXISTS','payment_channels','payment_orders','payment_events'
git -C admin_back_go diff --check -- database/migrations/20260515_payment_config_rebuild_v1.sql database/migrations/20260515_payment_config_only_cleanup.sql
```

Expected:

```text
The new table and new permission codes are present.
Old permission codes only appear inside migration copy/retire statements.
diff --check exits 0.
```

---

## Task 2: Backend Model, DTO, Request, and Repository

**Files:**
- Modify: `admin_back_go/internal/module/payment/model.go`
- Modify: `admin_back_go/internal/module/payment/dto.go`
- Modify: `admin_back_go/internal/module/payment/request.go`
- Modify: `admin_back_go/internal/module/payment/repository.go`
- Create: `admin_back_go/internal/module/payment/config_repository_test.go`

- [x] **Step 1: Add repository red tests**

Create `admin_back_go/internal/module/payment/config_repository_test.go` with tests proving the active table name and repository contract:

```go
package payment

import "testing"

func TestConfigTableName(t *testing.T) {
	if (Config{}).TableName() != "payment_configs" {
		t.Fatalf("unexpected table name: %s", (Config{}).TableName())
	}
}

func TestConfigListQueryDefaults(t *testing.T) {
	query := ConfigListQuery{}
	page, size, offset := normalizePage(query.CurrentPage, query.PageSize)
	if page != 1 || size != 20 || offset != 0 {
		t.Fatalf("unexpected page defaults: page=%d size=%d offset=%d", page, size, offset)
	}
}
```

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/payment -run 'TestConfigTableName|TestConfigListQueryDefaults'
```

Expected: fail until `Config` and config query types exist.

- [x] **Step 2: Replace channel-shaped model with config model**

In `model.go`, add the active config model and remove active reads from `Channel` / `ChannelConfig`:

```go
type Config struct {
	ID                 int64     `gorm:"column:id;primaryKey"`
	Code               string    `gorm:"column:code"`
	Name               string    `gorm:"column:name"`
	AppID              string    `gorm:"column:app_id"`
	PrivateKeyEnc   string    `gorm:"column:private_key_enc"`
	PrivateKeyHint  string    `gorm:"column:private_key_hint"`
	AppCertPath        string    `gorm:"column:app_cert_path"`
	PlatformCertPath     string    `gorm:"column:platform_cert_path"`
	RootCertPath string    `gorm:"column:root_cert_path"`
	NotifyURL          string    `gorm:"column:notify_url"`
	Environment        string    `gorm:"column:environment"`
	EnabledMethodsJSON string    `gorm:"column:enabled_methods_json"`
	Status             int       `gorm:"column:status"`
	Remark             string    `gorm:"column:remark"`
	IsDel              int       `gorm:"column:is_del"`
	CreatedAt          time.Time `gorm:"column:created_at"`
	UpdatedAt          time.Time `gorm:"column:updated_at"`
}

func (Config) TableName() string { return "payment_configs" }
```

Keep `Order` and `Event` structs only if a later compile step still needs them for temporary code removal. They must not be exposed through active routes in this plan.

- [x] **Step 3: Add config DTOs**

In `dto.go`, replace channel DTOs with these config-facing names:

```go
type ConfigInitResponse struct {
	Dict ConfigInitDict `json:"dict"`
}

type ConfigInitDict struct {
	EnvironmentArr     []dict.Option[string] `json:"environment_arr"`
	CommonStatusArr    []dict.Option[int]    `json:"common_status_arr"`
	EnabledMethodArr   []dict.Option[string] `json:"enabled_method_arr"`
	CertificateTypeArr []dict.Option[string] `json:"certificate_type_arr"`
}

type ConfigListQuery struct {
	CurrentPage int
	PageSize    int
	Name        string
	Environment string
	Status      int
}

type ConfigListItem struct {
	ID                 int64    `json:"id"`
	Code               string   `json:"code"`
	Name               string   `json:"name"`
	AppID              string   `json:"app_id"`
	PrivateKeyHint  string   `json:"private_key_hint"`
	AppCertPath        string   `json:"app_cert_path"`
	PlatformCertPath     string   `json:"platform_cert_path"`
	RootCertPath string   `json:"root_cert_path"`
	NotifyURL          string   `json:"notify_url"`
	Environment        string   `json:"environment"`
	EnvironmentText    string   `json:"environment_text"`
	EnabledMethods     []string `json:"enabled_methods"`
	EnabledMethodsText string   `json:"enabled_methods_text"`
	Status             int      `json:"status"`
	StatusText         string   `json:"status_text"`
	Remark             string   `json:"remark"`
	CreatedAt          string   `json:"created_at"`
	UpdatedAt          string   `json:"updated_at"`
}

type ConfigMutationInput struct {
	ID                 int64
	Code               string
	Name               string
	AppID              string
	AppPrivateKey      string
	AppCertPath        string
	PlatformCertPath     string
	RootCertPath string
	NotifyURL          string
	Environment        string
	EnabledMethods     []string
	Status             int
	Remark             string
}

type CertificateUploadInput struct {
	ConfigCode string
	CertType   string
	FileName   string
	Size       int64
	Reader     io.Reader
}

type CertificateUploadResponse struct {
	Path     string `json:"path"`
	FileName string `json:"file_name"`
	SHA256   string `json:"sha256"`
	Size     int64  `json:"size"`
}

type ConfigTestResponse struct {
	OK      bool     `json:"ok"`
	Checks  []string `json:"checks"`
	Message string   `json:"message"`
}
```

Use concrete typed maps for labels. Do not return `private_key_enc` or plaintext private key.

- [x] **Step 4: Add request structs**

In `request.go`, define request-only payloads:

```go
type listConfigsRequest struct {
	CurrentPage int    `form:"current_page"`
	PageSize    int    `form:"page_size"`
	Name        string `form:"name"`
	Environment string `form:"environment"`
	Status      int    `form:"status"`
}

type configMutationRequest struct {
	Code               string   `json:"code" binding:"required,max=64"`
	Name               string   `json:"name" binding:"required,max=128"`
	AppID              string   `json:"app_id" binding:"required,max=64"`
	AppPrivateKey      string   `json:"app_private_key"`
	AppCertPath        string   `json:"app_cert_path" binding:"required,max=512"`
	PlatformCertPath     string   `json:"platform_cert_path" binding:"required,max=512"`
	RootCertPath string   `json:"root_cert_path" binding:"required,max=512"`
	NotifyURL          string   `json:"notify_url" binding:"required,max=512"`
	Environment        string   `json:"environment" binding:"required,oneof=sandbox production"`
	EnabledMethods     []string `json:"enabled_methods" binding:"required,min=1"`
	Status             int      `json:"status" binding:"required"`
	Remark             string   `json:"remark" binding:"max=255"`
}

type changeConfigStatusRequest struct {
	Status int `json:"status" binding:"required"`
}
```

There is no request field for `provider`, `merchant_id`, `sign_type`, or `extra_config`.

- [x] **Step 5: Add repository methods**

In `repository.go`, replace active channel methods with config methods:

```go
type Repository interface {
	ListConfigs(ctx context.Context, query ConfigListQuery) ([]Config, int64, error)
	GetConfig(ctx context.Context, id int64) (*Config, error)
	GetConfigByCode(ctx context.Context, code string) (*Config, error)
	CreateConfig(ctx context.Context, cfg Config) (int64, error)
	UpdateConfig(ctx context.Context, cfg Config, keepPrivateKey bool) error
	ChangeConfigStatus(ctx context.Context, id int64, status int) error
	DeleteConfig(ctx context.Context, id int64) error
}
```

Rules:

```text
All read paths filter is_del = 2.
Create writes is_del = 2.
Update never overwrites private_key_enc/private_key_hint when keepPrivateKey is true.
Delete is a soft delete that sets is_del = 1 and status = 2.
```

- [x] **Step 6: Run repository tests**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/payment -run 'TestConfigTableName|TestConfigListQueryDefaults'
```

Expected: pass.

---

## Task 3: Certificate Store, Local Alipay Config Test, and Service Rules

**Files:**
- Create: `admin_back_go/internal/platform/payment/certstore.go`
- Create: `admin_back_go/internal/platform/payment/certstore_test.go`
- Modify: `admin_back_go/internal/platform/payment/alipay/gateway.go`
- Create: `admin_back_go/internal/platform/payment/alipay/config_test.go`
- Modify: `admin_back_go/internal/module/payment/service.go`
- Create: `admin_back_go/internal/module/payment/config_service_test.go`
- Modify: `admin_back_go/internal/bootstrap/app.go`
- Modify: `admin_back_go/internal/bootstrap/worker.go`

- [x] **Step 1: Write cert store tests**

Create `admin_back_go/internal/platform/payment/certstore_test.go`:

```go
package payment

import (
	"context"
	"strings"
	"testing"
)

func TestLocalCertStoreSavesRelativeSHAPath(t *testing.T) {
	store := LocalCertStore{BaseDir: t.TempDir()}
	result, err := store.Save(context.Background(), CertificateFile{
		ConfigCode: "alipay_default",
		CertType:   "app_cert",
		FileName:   "appCertPublicKey.crt",
		Size:       int64(len("-----BEGIN CERTIFICATE-----\nabc\n-----END CERTIFICATE-----")),
		Reader:     strings.NewReader("-----BEGIN CERTIFICATE-----\nabc\n-----END CERTIFICATE-----"),
	})
	if err != nil {
		t.Fatalf("Save error=%v", err)
	}
	if !strings.HasPrefix(result.Path, "runtime/payment/certs/alipay/alipay_default/") {
		t.Fatalf("unexpected path: %s", result.Path)
	}
	if result.SHA256 == "" || result.Size == 0 {
		t.Fatalf("missing sha or size: %#v", result)
	}
}

func TestLocalCertStoreRejectsInvalidInput(t *testing.T) {
	store := LocalCertStore{BaseDir: t.TempDir()}
	cases := []CertificateFile{
		{ConfigCode: "../bad", CertType: "app_cert", FileName: "a.crt", Size: 1, Reader: strings.NewReader("x")},
		{ConfigCode: "ok", CertType: "bad", FileName: "a.crt", Size: 1, Reader: strings.NewReader("x")},
		{ConfigCode: "ok", CertType: "app_cert", FileName: "a.exe", Size: 1, Reader: strings.NewReader("x")},
		{ConfigCode: "ok", CertType: "app_cert", FileName: "a.crt", Size: 65537, Reader: strings.NewReader(strings.Repeat("x", 65537))},
	}
	for _, tc := range cases {
		if _, err := store.Save(context.Background(), tc); err == nil {
			t.Fatalf("expected reject for %#v", tc)
		}
	}
}
```

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/platform/payment -run TestLocalCertStore
```

Expected: fail until `LocalCertStore` exists.

- [x] **Step 2: Implement cert store**

Create `certstore.go`:

```go
type CertificateFile struct {
	ConfigCode string
	CertType   string
	FileName   string
	Size       int64
	Reader     io.Reader
}

type CertificateSaveResult struct {
	Path     string
	FileName string
	SHA256   string
	Size     int64
}

type LocalCertStore struct {
	BaseDir string
}
```

Implementation rules:

```text
max size: 64 KiB
allowed cert_type: app_cert, alipay_cert, alipay_root_cert
allowed extension: .crt, .pem
config_code: lowercase letters, numbers, underscore, dash only
write path: <BaseDir>/runtime/payment/certs/alipay/<config_code>/<sha256>.crt
return path: runtime/payment/certs/alipay/<config_code>/<sha256>.crt
use os.MkdirAll with 0700 and os.WriteFile with 0600
never return cert content
```

- [x] **Step 3: Add platform-local config validation**

In `admin_back_go/internal/platform/payment/alipay/gateway.go`, add:

```go
func (g *GopayGateway) TestConfig(ctx context.Context, cfg ChannelConfig) error {
	_ = ctx
	_, err := newClient(cfg)
	return err
}
```

Also add this method to the payment gateway interface used by the service. This must not create an order or call remote Alipay APIs; `newClient` only validates config and calls `SetCertSnByPath`.

- [x] **Step 4: Write service red tests**

Create `admin_back_go/internal/module/payment/config_service_test.go` with cases:

```text
CreateConfig encrypts app_private_key and stores private_key_hint.
UpdateConfig with empty app_private_key keeps existing encrypted key.
ChangeConfigStatus to enabled runs TestConfig before updating status.
UploadCertificate delegates to LocalCertStore and maps cert_type to the correct path field.
ConfigTest decrypts key, resolves three cert paths, validates environment and enabled_methods.
ListConfigs never exposes private_key_enc.
```

Use fake repository, fake secretbox, fake cert resolver, fake cert store, and fake gateway. Keep tests local and deterministic.

- [x] **Step 5: Implement service methods**

In `service.go`, expose only the config methods on `HTTPService`:

```go
type HTTPService interface {
	ConfigInit(ctx context.Context) (*ConfigInitResponse, *apperror.Error)
	ListConfigs(ctx context.Context, query ConfigListQuery) (*ConfigListResponse, *apperror.Error)
	CreateConfig(ctx context.Context, input ConfigMutationInput) (int64, *apperror.Error)
	UpdateConfig(ctx context.Context, id int64, input ConfigMutationInput) *apperror.Error
	ChangeConfigStatus(ctx context.Context, id int64, status int) *apperror.Error
	DeleteConfig(ctx context.Context, id int64) *apperror.Error
	UploadCertificate(ctx context.Context, input CertificateUploadInput) (*CertificateUploadResponse, *apperror.Error)
	TestConfig(ctx context.Context, id int64) (*ConfigTestResponse, *apperror.Error)
}
```

Business rules:

```text
code cannot change after create.
create requires app_private_key.
update with empty app_private_key keeps old encrypted key.
enabled_methods must contain web or h5 and no other method.
environment must be sandbox or production.
notify_url must be http or https.
status must be 1 or 2.
enable status must pass TestConfig first.
delete soft-deletes the config and disables it.
```

- [x] **Step 6: Wire dependencies**

Update `Dependencies` and bootstrap wiring:

```go
type Dependencies struct {
	Repository   Repository
	Gateway      gateway.Gateway
	Secretbox    secretCodec
	CertResolver certResolver
	CertStore    certificateStore
	Now          func() time.Time
}
```

In `app.go`, instantiate:

```go
paymentCertResolver := payment.CertPathResolver{CertBaseDir: cfg.Payment.CertBaseDir, WorkingDir: workingDir}
paymentCertStore := payment.LocalCertStore{BaseDir: cfg.Payment.CertBaseDir}
```

In `worker.go`, keep resolver wiring for future worker reuse, but do not register payment order cron handlers in this config-only slice.

- [x] **Step 7: Run backend focused tests**

Run:

```powershell
cd E:\admin_go\admin_back_go
$env:GOMAXPROCS='2'
go test -p=1 ./internal/platform/payment ./internal/platform/payment/alipay ./internal/module/payment
```

Expected: pass.

---

## Task 4: HTTP Routes, Route Meta, Operation Log, and Router Tests

**Files:**
- Modify: `admin_back_go/internal/module/payment/handler.go`
- Create: `admin_back_go/internal/module/payment/config_handler_test.go`
- Modify: `admin_back_go/internal/module/payment/route.go`
- Modify: `admin_back_go/internal/bootstrap/route_meta.go`
- Modify: `admin_back_go/internal/bootstrap/route_meta_test.go`
- Modify: `admin_back_go/internal/server/router_test.go`
- Modify: `admin_back_go/internal/jobs/noop.go`
- Modify: `admin_back_go/internal/jobs/noop_test.go`

- [x] **Step 1: Add route tests first**

Create or update handler/router tests proving active routes:

```text
GET    /api/admin/v1/payment/configs/page-init
GET    /api/admin/v1/payment/configs
POST   /api/admin/v1/payment/configs
PUT    /api/admin/v1/payment/configs/:id
PATCH  /api/admin/v1/payment/configs/:id/status
DELETE /api/admin/v1/payment/configs/:id
POST   /api/admin/v1/payment/certificates
POST   /api/admin/v1/payment/configs/:id/test
```

The same test must assert these old active routes are not registered:

```text
/api/admin/v1/payment/channels
/api/admin/v1/payment/orders
/api/admin/v1/payment/events
/api/payment/notify/alipay
```

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/server ./internal/module/payment -run 'Payment|Config'
```

Expected: fail until routes and handler methods are replaced.

- [x] **Step 2: Replace handler methods**

In `handler.go`, keep request binding and response writing only:

```go
func (h *Handler) ConfigInit(c *gin.Context)
func (h *Handler) ListConfigs(c *gin.Context)
func (h *Handler) CreateConfig(c *gin.Context)
func (h *Handler) UpdateConfig(c *gin.Context)
func (h *Handler) ChangeConfigStatus(c *gin.Context)
func (h *Handler) DeleteConfig(c *gin.Context)
func (h *Handler) UploadCertificate(c *gin.Context)
func (h *Handler) TestConfig(c *gin.Context)
```

Upload handler rules:

```text
Bind cert_type and config_code from multipart form.
Read file from form field named file.
Pass file header name, size, and opened reader to service.
Never log or echo cert content.
```

- [x] **Step 3: Replace route registration**

In `route.go`, register only:

```go
configs := router.Group("/api/admin/v1/payment/configs")
configs.GET("/page-init", handler.ConfigInit)
configs.GET("", handler.ListConfigs)
configs.POST("", handler.CreateConfig)
configs.PUT("/:id", handler.UpdateConfig)
configs.PATCH("/:id/status", handler.ChangeConfigStatus)
configs.DELETE("/:id", handler.DeleteConfig)
configs.POST("/:id/test", handler.TestConfig)

router.POST("/api/admin/v1/payment/certificates", handler.UploadCertificate)
```

Do not register payment order/event/notify routes in this config-only slice.

- [x] **Step 4: Update route meta and operation log rules**

In `route_meta.go`, map permissions:

```go
GET    /api/admin/v1/payment/configs/page-init      -> payment_config_list
GET    /api/admin/v1/payment/configs                -> payment_config_list
POST   /api/admin/v1/payment/configs                -> payment_config_add
PUT    /api/admin/v1/payment/configs/:id            -> payment_config_edit
PATCH  /api/admin/v1/payment/configs/:id/status     -> payment_config_status
DELETE /api/admin/v1/payment/configs/:id            -> payment_config_del
POST   /api/admin/v1/payment/certificates           -> payment_config_upload_cert
POST   /api/admin/v1/payment/configs/:id/test       -> payment_config_test
```

Operation log module/action:

```text
module=payment_config action=create title=新增支付配置
module=payment_config action=update title=编辑支付配置
module=payment_config action=change_status title=切换支付配置状态
module=payment_config action=delete title=删除支付配置
module=payment_config action=upload_cert title=上传支付宝证书
module=payment_config action=test title=测试支付配置
```

Existing operation-log masking already covers `app_private_key` and `private_key_enc`; add a focused assertion if the route meta test does not cover this path.

- [x] **Step 5: Retire payment cron registration**

In `internal/jobs/noop.go`, stop registering `payment:close-expired-order:v1` and `payment:sync-pending-order:v1` while the active payment slice is config-only. Update `noop_test.go` so it asserts those task types are absent from the registry.

- [x] **Step 6: Run backend route/meta tests**

Run:

```powershell
cd E:\admin_go\admin_back_go
$env:GOMAXPROCS='2'
go test -p=1 ./internal/module/payment ./internal/bootstrap ./internal/server ./internal/jobs
```

Expected: pass.

---

## Task 5: Frontend API, Page, Permission Gates, and i18n

**Files:**
- Create: `admin_front_ts/src/api/payment/config.ts`
- Create: `admin_front_ts/src/views/Main/payment/config/index.vue`
- Create: `admin_front_ts/src/views/Main/payment/config/composables/usePaymentConfigPage.ts`
- Modify: `admin_front_ts/src/i18n/locales/zh-CN.ts`
- Modify: `admin_front_ts/src/i18n/locales/en-US.ts`
- Modify: `admin_front_ts/tests/shared/router/view-registry.test.ts`
- Modify: `admin_front_ts/tests/shared/router/runtime-route-tree.test.ts`
- Create: `admin_front_ts/tests/shared/payment/payment-config-api.test.ts`
- Create: `admin_front_ts/tests/shared/payment/payment-config-page.test.ts`
- Delete: old payment channel/order/event API, views, and tests listed in File Map

- [x] **Step 1: Write frontend contract tests first**

Create `tests/shared/payment/payment-config-api.test.ts`:

```ts
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { describe, expect, it } from 'vitest'

const read = (path: string) => readFileSync(resolve(process.cwd(), path), 'utf8')
const loose = new RegExp(`\\b${'an'}${'y'}\\b|as ${'an'}${'y'}|Record<string, ${'an'}${'y'}>`)

describe('payment config api', () => {
  it('uses config REST paths and strict payloads', () => {
    const source = read('src/api/payment/config.ts')
    expect(source).toContain('request.get<PaymentConfigInitResponse>(`${ADMIN_API_PREFIX}/payment/configs/page-init`)')
    expect(source).toContain('request.post<PaymentConfigCreateResponse, PaymentConfigMutationPayload>(`${ADMIN_API_PREFIX}/payment/configs`')
    expect(source).toContain('request.post<PaymentCertificateUploadResponse, FormData>(`${ADMIN_API_PREFIX}/payment/certificates`')
    expect(source).toContain('request.post<PaymentConfigTestResponse>(`${ADMIN_API_PREFIX}/payment/configs/${positiveID(id)}/test`)')
    expect(source).not.toContain('/payment/channels')
    expect(source).not.toContain('/payment/orders')
    expect(source).not.toContain('/payment/events')
    expect(source).not.toContain('provider')
    expect(source).not.toContain('merchant_id')
    expect(source).not.toContain('sign_type')
    expect(source).not.toContain('extra_config')
    expect(source).not.toMatch(loose)
  })
})
```

Create `tests/shared/payment/payment-config-page.test.ts` to assert:

```text
src/views/Main/payment/config/index.vue gates buttons with payment_config_add/edit/status/delete/upload_cert/test.
The page imports @/api/payment/config through usePaymentConfigPage.
No payment_channel_* code remains in src/views/Main/payment/config.
No manual cert path input is shown without upload action.
```

- [x] **Step 2: Implement `src/api/payment/config.ts`**

Expose:

```ts
export const PaymentConfigApi = {
  init,
  list,
  add,
  edit,
  status,
  del,
  uploadCertificate,
  test,
}
```

Types:

```ts
export interface PaymentConfigMutationPayload {
  id?: number
  code: string
  name: string
  app_id: string
  app_private_key?: string
  app_cert_path: string
  platform_cert_path: string
  root_cert_path: string
  notify_url: string
  environment: 'sandbox' | 'production'
  enabled_methods: Array<'web' | 'h5'>
  status: number
  remark: string
}
```

No frontend type may include `private_key_enc`.

- [x] **Step 3: Implement the composable**

Create `usePaymentConfigPage.ts` around existing `useTable` conventions:

```text
state: dict, searchForm, table, dialogVisible, dialogMode, formRef, form, rules, uploadLoading
actions: init, refresh, openAddDialog, openEditDialog, confirmSubmit, changeStatus, confirmDel, uploadCert, testConfig
default form: environment=sandbox, enabled_methods=['web'], status=2
edit form: app_private_key=''
```

Validation:

```text
create requires app_private_key.
edit allows empty app_private_key.
code is disabled in edit mode.
enabled_methods must contain web or h5.
notify_url must start with http:// or https://.
```

- [x] **Step 4: Implement `index.vue`**

Build one page with:

```text
Search: name, environment, status
Table: name, code, app_id, environment, enabled_methods_text, status_text, created_at, actions
Dialog groups: 基础信息, 支付宝参数, 证书上传
Buttons: 新增, 编辑, 启用/禁用, 删除, 上传证书, 测试配置
```

Use RBAC:

```vue
userStore.can('payment_config_add')
userStore.can('payment_config_edit')
userStore.can('payment_config_status')
userStore.can('payment_config_del')
userStore.can('payment_config_upload_cert')
userStore.can('payment_config_test')
```

Certificate upload must call `PaymentConfigApi.uploadCertificate` with `FormData`, then write the returned `path` into the matching form field. Do not use generic COS upload components.

- [x] **Step 5: Update i18n and router tests**

Replace menu labels:

```ts
payment: '支付管理'
payment_config: '支付配置'
```

English:

```ts
payment: 'Payment'
payment_config: 'Payment Config'
```

Update router view tests so `payment/config` maps to:

```text
../views/Main/payment/config/index.vue
```

Old `/payment/channel`, `/payment/order`, and `/payment/event` should not be required visible routes after DB migration. If runtime dead-route tests intentionally cover missing views, keep those tests under the router slice and make them assert dead-page behavior, not active payment availability.

- [x] **Step 6: Run frontend focused tests**

Run:

```powershell
cd E:\admin_go\admin_front_ts
$env:NODE_OPTIONS='--max-old-space-size=2048'
npx vitest run tests/shared/payment/payment-config-api.test.ts tests/shared/payment/payment-config-page.test.ts tests/shared/router/view-registry.test.ts tests/shared/router/runtime-route-tree.test.ts
```

Expected: pass.

---

## Task 6: Contract, Status, Smoke, and Cert Script Sync

**Files:**
- Modify: `docs/contracts/admin-api-v1.md`
- Modify: `docs/status/current-status.md`
- Modify: `docs/testing/smoke-matrix.md`
- Modify: `admin_back_go/docs/architecture.md`
- Modify: `admin_back_go/scripts/check-payment-certs.ps1`
- Modify: `admin_back_go/scripts/full-admin-smoke.ps1`

- [x] **Step 1: Update API contract**

In `docs/contracts/admin-api-v1.md`, replace the active Payment section with:

```text
Payment V1 active scope: Alipay config only.
Active table: payment_configs.
Active admin routes: /api/admin/v1/payment/configs/* and /api/admin/v1/payment/certificates.
No wallet/refund/reconcile/WeChat/payment-order/notify route is active in this slice.
Secrets: private_key_enc never appears in API responses, frontend types, operation log payloads, or smoke output.
Certificates: stored as private relative paths under runtime/payment/certs/alipay/<config_code>/<sha256>.crt; no public URL and no download route.
```

- [x] **Step 2: Update current status**

In `docs/status/current-status.md`, change the payment row to:

```text
payment config rebuild v1 | implemented after this plan execution: payment_configs, config CRUD, certificate upload, local config test, /payment/config frontend | order/event/wallet/refund/reconcile/WeChat are not active in this slice
```

Do not claim order, notify, wallet, or payment runtime completion in this row.

- [x] **Step 3: Update smoke matrix and full smoke**

In `docs/testing/smoke-matrix.md` and `full-admin-smoke.ps1`, default smoke must probe:

```text
GET /api/admin/v1/payment/configs/page-init
GET /api/admin/v1/payment/configs?current_page=1&page_size=20
users/init has /payment/config with view_key payment/config
users/init does not require /payment/channel, /payment/order, /payment/event
responses do not expose private_key_enc or app_private_key
```

Default smoke must not upload certificates, call `configs/:id/test` against real credentials, create payment orders, or call Alipay.

- [x] **Step 4: Update cert script**

In `scripts/check-payment-certs.ps1`, query `payment_configs`:

```sql
SELECT code, app_cert_path, platform_cert_path, root_cert_path
FROM payment_configs
WHERE status = 1 AND is_del = 2
ORDER BY id
LIMIT 1;
```

Remove joins against `payment_channels` and `payment_channel_configs`.

- [x] **Step 5: Run docs/script static checks**

Run:

```powershell
cd E:\admin_go
Select-String -Path .\docs\contracts\admin-api-v1.md,.\docs\status\current-status.md,.\docs\testing\smoke-matrix.md,.\admin_back_go\docs\architecture.md -Pattern 'payment_channels|payment_channel_configs|/payment/channel|/payment/order|/payment/event|payment_channel_|payment_order_|payment_event_' -CaseSensitive:$false
git diff --check -- docs/contracts/admin-api-v1.md docs/status/current-status.md docs/testing/smoke-matrix.md admin_back_go/docs/architecture.md
git -C admin_back_go diff --check -- scripts/check-payment-certs.ps1 scripts/full-admin-smoke.ps1
```

Expected:

```text
Old payment terms only remain if explicitly labeled as retired migration provenance.
diff --check exits 0.
```

---

## Task 7: Final Verification Gate

**Files:**
- All files changed by Tasks 1-6

- [x] **Step 1: Backend tests**

Run:

```powershell
cd E:\admin_go\admin_back_go
$env:GOMAXPROCS='2'
go test -p=1 ./internal/module/payment ./internal/platform/payment ./internal/platform/payment/alipay ./internal/bootstrap ./internal/server ./internal/jobs
```

Expected: pass.

- [x] **Step 2: Backend contract check**

Run:

```powershell
cd E:\admin_go\admin_back_go
powershell -ExecutionPolicy Bypass -File .\scripts\check-contract.ps1
```

Expected: pass.

- [x] **Step 3: Frontend tests and type checks**

Run:

```powershell
cd E:\admin_go\admin_front_ts
$env:NODE_OPTIONS='--max-old-space-size=2048'
npx vitest run tests/shared/payment/payment-config-api.test.ts tests/shared/payment/payment-config-page.test.ts tests/shared/router/view-registry.test.ts tests/shared/router/runtime-route-tree.test.ts
npx vue-tsc -b --pretty false
npx eslint src/api/payment/config.ts src/views/Main/payment/config --ext .ts,.vue
```

Expected: pass.

- [x] **Step 4: Smoke script static route check**

Run:

```powershell
cd E:\admin_go\admin_back_go
Select-String -Path .\scripts\full-admin-smoke.ps1 -Pattern '/payment/config','/payment/channel','/payment/order','/payment/event','payment_config_','payment_channel_' -CaseSensitive:$false
```

Expected:

```text
/payment/config and payment_config_* are present.
Old payment routes/codes are absent from active assertions or explicitly checked as absent.
```

- [x] **Step 5: Workspace diff hygiene**

Run:

```powershell
cd E:\admin_go
git diff --check
git -C admin_back_go diff --check
git -C admin_front_ts diff --check
git status --short
git -C admin_back_go status --short
git -C admin_front_ts status --short
```

Expected:

```text
All diff checks exit 0.
Status output separates payment-config changes from unrelated existing dirty files.
No generated certificate files under runtime/ are staged.
```

---

## Self-Review Checklist

```text
Spec coverage: schema, cert upload, CRUD, enable-before-test, menu/RBAC, frontend page, docs and smoke are covered.
Scope control: no wallet, order, notify, refund, withdraw, reconcile, WeChat, or product billing.
Field control: every new table field has first-version behavior; provider is used and limited to alipay; merchant_id/sign_type/extra_config are banned.
Runtime truth: old channel/order/event routes, menus, cron rows, and tables are removed from the active slice.
Security: private key is write-only; cert files are private local files; operation logs must not expose secrets.
Verification: backend tests, frontend tests, contract check, smoke script checks, and diff checks are explicit.
```
