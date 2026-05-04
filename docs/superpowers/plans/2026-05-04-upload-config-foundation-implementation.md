# Upload Config Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Work in the current branch only; do not create a worktree. Commit/push only when the active user goal explicitly asks for it.

**Goal:** Migrate upload configuration management from PHP legacy POST APIs to Go REST + Vue typed APIs, while keeping real upload token/SDK work out of this batch.

**Architecture:** Backend stays Gin modular monolith. Upload config is one module with three resources: drivers, rules, settings. Shared enum/dict/validate and `platform/secretbox` stay thin and reusable; handler does HTTP only, service owns business rules and transactions, repository owns GORM queries, model owns table mapping.

**Tech Stack:** Go 1.21+, Gin, GORM, MySQL, Go stdlib `crypto/aes` + `crypto/cipher` AES-GCM, Vue 3 `<script setup lang="ts">`, Element Plus, existing `request + ADMIN_API_PREFIX` frontend HTTP layer.

---

## Source Spec

Read before changing code:

- `docs/superpowers/specs/2026-05-04-upload-config-foundation-design.md`
- `docs/contracts/admin-api-v1.md`
- `docs/migration/current-status.md`
- `docs/testing/smoke-matrix.md`
- `admin_back_go/docs/architecture.md`
- `AGENTS.md`

## Phase Boundary

Included:

```text
upload-drivers CRUD
upload-rules CRUD
upload-settings CRUD + exclusive enable
VAULT_KEY-compatible secretbox
enum/dict/validate
operation log route metadata
frontend typed REST client adaptation
full smoke read-only probe, optional safe write probe
```

Excluded:

```text
/api/getUploadToken
COS STS / OSS STS
server-side file upload
frontend upload widget migration
COS/OSS SDK dependency installation
schema changes
```

## File Map

Backend create/modify:

```text
admin_back_go/internal/config/config.go
admin_back_go/internal/config/config_test.go
admin_back_go/internal/enum/upload.go
admin_back_go/internal/dict/dict.go
admin_back_go/internal/validate/register.go
admin_back_go/internal/validate/upload.go
admin_back_go/internal/platform/secretbox/secretbox.go
admin_back_go/internal/platform/secretbox/secretbox_test.go
admin_back_go/internal/module/uploadconfig/route.go
admin_back_go/internal/module/uploadconfig/handler.go
admin_back_go/internal/module/uploadconfig/request.go
admin_back_go/internal/module/uploadconfig/dto.go
admin_back_go/internal/module/uploadconfig/model.go
admin_back_go/internal/module/uploadconfig/repository.go
admin_back_go/internal/module/uploadconfig/service.go
admin_back_go/internal/module/uploadconfig/errors.go
admin_back_go/internal/module/uploadconfig/service_test.go
admin_back_go/internal/bootstrap/app.go
admin_back_go/internal/bootstrap/route_meta.go
admin_back_go/internal/server/router.go
admin_back_go/scripts/full-admin-smoke.ps1
admin_back_go/.env.example
admin_back_go/docs/architecture.md
```

Frontend modify:

```text
admin_front_ts/src/api/system/uploadConfig.ts
admin_front_ts/src/views/Main/system/uploadConfig/index.vue
admin_front_ts/src/views/Main/system/uploadConfig/components/UploadDriver/index.vue
admin_front_ts/src/views/Main/system/uploadConfig/components/UploadRule/index.vue
admin_front_ts/src/views/Main/system/uploadConfig/components/UploadSetting/index.vue
```

Workspace docs modify:

```text
docs/contracts/admin-api-v1.md
docs/migration/current-status.md
docs/testing/smoke-matrix.md
```

---

## Task 1: Secretbox Config and AES-GCM Compatibility

**Goal:** Add a reusable secret encryption boundary that can read existing PHP KeyVault ciphertext.

**Files:**

- Modify: `admin_back_go/internal/config/config.go`
- Modify: `admin_back_go/internal/config/config_test.go`
- Create: `admin_back_go/internal/platform/secretbox/secretbox.go`
- Create: `admin_back_go/internal/platform/secretbox/secretbox_test.go`
- Modify: `admin_back_go/.env.example`

- [ ] Add config struct:

```go
type SecretboxConfig struct {
	Key string
}
```

- [ ] Add `Secretbox SecretboxConfig` to `config.Config`.
- [ ] Load `VAULT_KEY` into `Config.Secretbox.Key`.
- [ ] Add `.env.example` section:

```dotenv
# AES-GCM vault key for encrypted API keys and upload driver secrets. Must match legacy PHP VAULT_KEY when reading existing encrypted rows.
VAULT_KEY=
```

- [ ] Write `secretbox_test.go` tests:

```text
TestBoxEncryptFailsWithoutKey
TestBoxEncryptDecryptRoundTrip
TestBoxDecryptLegacyFormat
TestHint
```

- [ ] Implement `secretbox.Box` with these public methods:

```go
type Box struct {
	key string
}

func New(key string) Box
func (b Box) Encrypt(plain string) (string, error)
func (b Box) Decrypt(ciphertext string) (string, error)
func Hint(plain string) string
```

- [ ] Keep PHP-compatible format:

```text
sha256(VAULT_KEY) -> AES-256 key
iv/nonce: 12 random bytes
tag: 16 bytes
stored: base64(iv + tag + ciphertext)
```

- [ ] Run:

```powershell
cd E:/admin_go/admin_back_go
go test -p=1 ./internal/platform/secretbox ./internal/config
```

Expected: PASS.

---

## Task 2: Upload Enum, Dict, and Validators

**Goal:** Make upload values centralized before any handler accepts input.

**Files:**

- Create: `admin_back_go/internal/enum/upload.go`
- Modify: `admin_back_go/internal/dict/dict.go`
- Modify: `admin_back_go/internal/validate/register.go`
- Create: `admin_back_go/internal/validate/upload.go`

- [ ] Add upload driver constants:

```go
const (
	UploadDriverCOS = "cos"
	UploadDriverOSS = "oss"
)
```

- [ ] Add ordered driver options:

```text
cos -> 腾讯云 COS
oss -> 阿里云 OSS
```

- [ ] Add image extension whitelist in this order:

```text
jpeg, jpg, gif, png, svg, ico, doc, psd, bmp, tiff, webp, tif, pjpeg
```

- [ ] Add file extension whitelist in this order:

```text
docx, pdf, txt, html, zip, tar, doc, css, csv, ppt, xlsx, xls, xml
```

- [ ] Add upload folder whitelist for next phase:

```text
avatars, images, videos, cover_images, ai_chat_images, releases, tauri_updater,
exports, goods_tts, chat_images, chat_files, reconcile_reports, cine_keyframes
```

- [ ] Expose enum helpers:

```go
func IsUploadDriver(value string) bool
func IsUploadImageExt(value string) bool
func IsUploadFileExt(value string) bool
func NormalizeUploadExts(values []string, allowed func(string) bool, ordered []string) ([]string, error)
```

- [ ] Add dict builders:

```text
upload_driver_arr
upload_image_ext_arr
upload_file_ext_arr
```

- [ ] Add validator tags that call enum helpers:

```text
upload_driver
upload_image_ext
upload_file_ext
```

- [ ] Run:

```powershell
cd E:/admin_go/admin_back_go
go test -p=1 ./internal/enum ./internal/dict ./internal/validate
```

Expected: PASS.

---

## Task 3: Uploadconfig Module Skeleton and Routes

**Goal:** Create module boundaries and route registration without business shortcuts.

**Files:**

- Create: `admin_back_go/internal/module/uploadconfig/model.go`
- Create: `admin_back_go/internal/module/uploadconfig/dto.go`
- Create: `admin_back_go/internal/module/uploadconfig/request.go`
- Create: `admin_back_go/internal/module/uploadconfig/errors.go`
- Create: `admin_back_go/internal/module/uploadconfig/repository.go`
- Create: `admin_back_go/internal/module/uploadconfig/service.go`
- Create: `admin_back_go/internal/module/uploadconfig/handler.go`
- Create: `admin_back_go/internal/module/uploadconfig/route.go`
- Modify: `admin_back_go/internal/bootstrap/app.go`
- Modify: `admin_back_go/internal/server/router.go`

- [ ] Define models for existing tables only:

```text
UploadDriverModel -> upload_driver
UploadRuleModel -> upload_rule
UploadSettingModel -> upload_setting
```

- [ ] Define request structs with binding tags for:

```text
DriverListQuery, DriverCreateRequest, DriverUpdateRequest, BatchDeleteRequest
RuleListQuery, RuleMutationRequest
SettingListQuery, SettingMutationRequest, StatusRequest
```

- [ ] Define response DTOs matching the spec exactly; do not include encrypted fields.
- [ ] Create repository constructor that accepts `*gorm.DB`.
- [ ] Create service constructor that accepts repository and `secretbox.Box`.
- [ ] Create handler constructor that accepts service.
- [ ] Register routes under:

```text
/api/admin/v1/upload-drivers
/api/admin/v1/upload-rules
/api/admin/v1/upload-settings
```

- [ ] Run route compile check:

```powershell
cd E:/admin_go/admin_back_go
go test -p=1 ./internal/module/uploadconfig ./internal/server ./internal/bootstrap
```

Expected: compile or known failing tests from later tasks only. Do not leave unused code.

---

## Task 4: Upload Drivers Backend

**Goal:** Implement driver CRUD with encrypted secrets and no plaintext leakage.

**Files:**

- Modify: `admin_back_go/internal/module/uploadconfig/repository.go`
- Modify: `admin_back_go/internal/module/uploadconfig/service.go`
- Modify: `admin_back_go/internal/module/uploadconfig/handler.go`
- Modify: `admin_back_go/internal/module/uploadconfig/route.go`
- Create/Modify: `admin_back_go/internal/module/uploadconfig/service_test.go`
- Modify: `admin_back_go/internal/bootstrap/route_meta.go`

- [ ] Write tests:

```text
TestDriverCreateEncryptsSecretsAndReturnsID
TestDriverCreateRejectsDuplicateDriverBucket
TestDriverCreateRejectsMissingCOSAppID
TestDriverCreateRejectsMissingOSSRoleARN
TestDriverUpdateKeepsSecretsWhenOmitted
TestDriverUpdateRotatesProvidedSecret
TestDriverListNeverReturnsPlaintextOrCiphertext
TestDriverDeleteRejectsReferencedDriver
```

- [ ] Implement `GET /upload-drivers/init` from dict.
- [ ] Implement `GET /upload-drivers` with pagination and optional driver filter.
- [ ] Implement `POST /upload-drivers`:

```text
validate driver enum
validate cos appid / oss role_arn
reject duplicate driver+bucket
encrypt secret_id and secret_key
write *_enc + *_hint only
```

- [ ] Implement `PUT /upload-drivers/:id`:

```text
reject missing row
reject duplicate driver+bucket excluding current id
if secret_id non-empty, encrypt and update id hint
if secret_key non-empty, encrypt and update key hint
if secret fields empty, keep existing encrypted values
```

- [ ] Implement delete one and batch delete:

```text
reject referenced driver where upload_setting.is_del=2
soft delete is_del=1
```

- [ ] Register route metadata:

```text
POST   /upload-drivers        system_uploadConfig_driverAdd   operation log
PUT    /upload-drivers/:id    system_uploadConfig_driverEdit  operation log
DELETE /upload-drivers/:id    system_uploadConfig_driverDel   operation log
DELETE /upload-drivers        system_uploadConfig_driverDel   operation log
```

- [ ] Ensure operation log masking includes `secret_id`, `secret_key`, `secret_id_enc`, `secret_key_enc`.
- [ ] Run:

```powershell
cd E:/admin_go/admin_back_go
go test -p=1 ./internal/module/uploadconfig ./internal/platform/secretbox ./internal/server ./internal/bootstrap
```

Expected: PASS.

---

## Task 5: Upload Rules Backend

**Goal:** Implement rule CRUD with extension normalization and referenced-delete guard.

**Files:**

- Modify: `admin_back_go/internal/module/uploadconfig/repository.go`
- Modify: `admin_back_go/internal/module/uploadconfig/service.go`
- Modify: `admin_back_go/internal/module/uploadconfig/handler.go`
- Modify: `admin_back_go/internal/bootstrap/route_meta.go`
- Modify: `admin_back_go/internal/module/uploadconfig/service_test.go`

- [ ] Write tests:

```text
TestRuleCreateRejectsDuplicateTitle
TestRuleCreateRejectsInvalidMaxSize
TestRuleCreateRejectsUnknownImageExt
TestRuleCreateRejectsUnknownFileExt
TestRuleCreateRejectsBothExtArraysEmpty
TestRuleCreateNormalizesLowercaseDedupeAndEnumOrder
TestRuleDeleteRejectsReferencedRule
```

- [ ] Implement `GET /upload-rules/init` from dict.
- [ ] Implement `GET /upload-rules` with prefix title filter and pagination.
- [ ] Implement create/update:

```text
title length 1..50
max_size_mb 1..10240
normalize image_exts and file_exts
reject both arrays empty
reject duplicate title in is_del=2
store JSON arrays
```

- [ ] Implement delete one and batch delete:

```text
reject referenced rule where upload_setting.is_del=2
soft delete is_del=1
```

- [ ] Register route metadata:

```text
POST   /upload-rules        system_uploadConfig_ruleAdd   operation log
PUT    /upload-rules/:id    system_uploadConfig_ruleEdit  operation log
DELETE /upload-rules/:id    system_uploadConfig_ruleDel   operation log
DELETE /upload-rules        system_uploadConfig_ruleDel   operation log
```

- [ ] Run:

```powershell
cd E:/admin_go/admin_back_go
go test -p=1 ./internal/module/uploadconfig ./internal/enum ./internal/dict ./internal/validate ./internal/server ./internal/bootstrap
```

Expected: PASS.

---

## Task 6: Upload Settings Backend and Exclusive Enable

**Goal:** Implement driver/rule combination config and enforce one enabled config through a transaction.

**Files:**

- Modify: `admin_back_go/internal/module/uploadconfig/repository.go`
- Modify: `admin_back_go/internal/module/uploadconfig/service.go`
- Modify: `admin_back_go/internal/module/uploadconfig/handler.go`
- Modify: `admin_back_go/internal/bootstrap/route_meta.go`
- Modify: `admin_back_go/internal/module/uploadconfig/service_test.go`

- [ ] Write tests:

```text
TestSettingInitReturnsDriverAndRuleDicts
TestSettingCreateRejectsMissingDriver
TestSettingCreateRejectsMissingRule
TestSettingCreateRejectsDuplicateDriverRule
TestSettingCreateEnabledDisablesOtherEnabledRows
TestSettingStatusEnabledDisablesOtherEnabledRows
TestSettingStatusDisabledOnlyDisablesCurrentRow
TestSettingDeleteRejectsEnabledSetting
```

- [ ] Implement `GET /upload-settings/init`:

```text
common_status_arr from dict
upload_driver_list from non-deleted drivers, label "<driver_show> - <bucket>"
upload_rule_list from non-deleted rules, label title
```

- [ ] Implement `GET /upload-settings` with filters:

```text
remark prefix
status
driver_id
rule_id
```

- [ ] Implement create/update:

```text
validate driver/rule exist and is_del=2
reject duplicate driver_id+rule_id excluding current id
status=1 calls exclusive enable transaction
status=2 writes normally
```

- [ ] Implement exclusive enable transaction:

```text
start tx
lock upload_setting rows where is_del=2 for update
set status=2 for all enabled rows
insert/update current setting as status=1
commit
```

- [ ] Implement status endpoint with same transaction for `status=1`.
- [ ] Implement delete one and batch delete:

```text
reject enabled setting
soft delete is_del=1
```

- [ ] Register route metadata:

```text
POST   /upload-settings             system_uploadConfig_settingAdd     operation log
PUT    /upload-settings/:id         system_uploadConfig_settingEdit    operation log
PATCH  /upload-settings/:id/status  system_uploadConfig_settingStatus  operation log
DELETE /upload-settings/:id         system_uploadConfig_settingDel     operation log
DELETE /upload-settings             system_uploadConfig_settingDel     operation log
```

- [ ] Run:

```powershell
cd E:/admin_go/admin_back_go
go test -p=1 ./internal/module/uploadconfig ./internal/server ./internal/bootstrap
```

Expected: PASS.

---

## Task 7: Backend Contract, Architecture Docs, and Smoke

**Goal:** Make docs and verification match runtime before touching frontend.

**Files:**

- Modify: `docs/contracts/admin-api-v1.md`
- Modify: `docs/migration/current-status.md`
- Modify: `docs/testing/smoke-matrix.md`
- Modify: `admin_back_go/docs/architecture.md`
- Modify: `admin_back_go/scripts/full-admin-smoke.ps1`

- [ ] Add `Upload Config` section to `docs/contracts/admin-api-v1.md` with exact endpoint/query/body/response/error rules from spec.
- [ ] Add `upload config` row to `docs/migration/current-status.md` only after backend + frontend are verified; before frontend verification, mark backend implemented and frontend planned/partial honestly.
- [ ] Add smoke matrix rows:

```text
upload driver init/list
upload rule init/list
upload setting init/list
optional temp write probe gated by VAULT_KEY
```

- [ ] Update backend architecture docs with:

```text
secretbox uses VAULT_KEY and PHP-compatible AES-GCM format
uploadconfig module owns configuration only
upload runtime/token is next phase
```

- [ ] Extend `full-admin-smoke.ps1`:

```text
always call init/list for all three resources
if VAULT_KEY env is empty, print upload_write_probe="skipped_no_vault_key"
if VAULT_KEY exists, create disabled temp driver/rule/setting, verify, then cleanup in reverse order
never enable temp setting
never modify existing enabled setting
```

- [ ] Run:

```powershell
cd E:/admin_go/admin_back_go
go test -p=1 ./...
go vet -p=1 ./...
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account 15671628271 -Password 123456
```

Expected: tests/vet/diff pass, smoke JSON contains upload init/list codes.

---

## Task 8: Frontend API Client Migration

**Goal:** Convert upload config API to REST without page-level path guessing.

**Files:**

- Modify: `admin_front_ts/src/api/system/uploadConfig.ts`

- [ ] Replace `legacyRequest` import with current Go request layer:

```ts
import { request } from '@/lib/http'
import { ADMIN_API_PREFIX } from '@/api/common'
```

Use the actual existing import path if the project already exports `ADMIN_API_PREFIX` elsewhere; do not create a second constant.

- [ ] Remove `RequestPayload` inheritance from upload params if it only exists for legacy loose payloads.
- [ ] Make driver types discriminated unions where useful:

```ts
export type UploadDriverType = 'cos' | 'oss'
```

- [ ] Map API methods:

```text
Driver init   -> GET    /upload-drivers/init
Driver list   -> GET    /upload-drivers
Driver add    -> POST   /upload-drivers
Driver edit   -> PUT    /upload-drivers/:id
Driver del    -> DELETE /upload-drivers/:id or DELETE /upload-drivers body { ids }

Rule init     -> GET    /upload-rules/init
Rule list     -> GET    /upload-rules
Rule add      -> POST   /upload-rules
Rule edit     -> PUT    /upload-rules/:id
Rule del      -> DELETE /upload-rules/:id or DELETE /upload-rules body { ids }

Setting init  -> GET    /upload-settings/init
Setting list  -> GET    /upload-settings
Setting add   -> POST   /upload-settings
Setting edit  -> PUT    /upload-settings/:id
Setting status-> PATCH  /upload-settings/:id/status
Setting del   -> DELETE /upload-settings/:id or DELETE /upload-settings body { ids }
```

- [ ] In API layer, extract `id` for path params. Do not force Vue components to know REST URLs.
- [ ] Do not add fallback response fields or fallback labels.
- [ ] Run:

```powershell
cd E:/admin_go/admin_front_ts
npx vue-tsc -b --pretty false
npx eslint src/api/system/uploadConfig.ts
```

Expected: PASS.

---

## Task 9: Frontend UploadDriver Component Adaptation

**Goal:** Keep existing UI but align payloads and types with REST client.

**Files:**

- Modify: `admin_front_ts/src/views/Main/system/uploadConfig/components/UploadDriver/index.vue`

- [ ] Keep `AppDialog`, `AppTable`, `Search`, and `useCrudTable`.
- [ ] Remove casts that hide contract problems, especially `as UploadDriverForm` when a narrower typed payload can be built.
- [ ] Build submit payload explicitly:

```text
always send driver, bucket, region, appid/role_arn/endpoint/bucket_domain
in add mode send secret_id and secret_key
in edit mode send secret_id/secret_key only if user typed non-empty values
```

- [ ] Keep form rule:

```text
add: secret_id and secret_key required
edit: secret fields optional and blank means keep old secret
cos: appid required
oss: role_arn required
```

- [ ] Run:

```powershell
cd E:/admin_go/admin_front_ts
npx vue-tsc -b --pretty false
npx eslint src/api/system/uploadConfig.ts src/views/Main/system/uploadConfig/components/UploadDriver/index.vue
```

Expected: PASS.

---

## Task 10: Frontend UploadRule Component Adaptation

**Goal:** Align rule form/list with Go enum dict and no fallback labels.

**Files:**

- Modify: `admin_front_ts/src/views/Main/system/uploadConfig/components/UploadRule/index.vue`

- [ ] Keep init dict as the only source of extension options.
- [ ] Add form validation that both extension arrays cannot be empty.
- [ ] Build submit payload explicitly:

```text
title
max_size_mb
image_exts
file_exts
id only for edit API layer path extraction
```

- [ ] Do not add hardcoded image/file extension labels in component.
- [ ] Run:

```powershell
cd E:/admin_go/admin_front_ts
npx vue-tsc -b --pretty false
npx eslint src/api/system/uploadConfig.ts src/views/Main/system/uploadConfig/components/UploadRule/index.vue
```

Expected: PASS.

---

## Task 11: Frontend UploadSetting Component Adaptation

**Goal:** Align setting form/list/status with REST and keep exclusive-enable behavior backend-owned.

**Files:**

- Modify: `admin_front_ts/src/views/Main/system/uploadConfig/components/UploadSetting/index.vue`

- [ ] Keep `status` toggle using `UploadSettingApi.status`.
- [ ] Do not implement exclusive enable in frontend. Backend is the truth.
- [ ] After status toggle, refresh list to reflect any other rows disabled by backend transaction.
- [ ] Build submit payload explicitly:

```text
driver_id
rule_id
status
remark
id only for edit API layer path extraction
```

- [ ] Run:

```powershell
cd E:/admin_go/admin_front_ts
npx vue-tsc -b --pretty false
npx eslint src/api/system/uploadConfig.ts src/views/Main/system/uploadConfig/components/UploadSetting/index.vue
```

Expected: PASS.

---

## Task 12: Final Verification Gate

**Goal:** Prove the upload config foundation is ready before claiming completion.

- [ ] Backend verification:

```powershell
cd E:/admin_go/admin_back_go
go test -p=1 ./...
go vet -p=1 ./...
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account 15671628271 -Password 123456
```

- [ ] Frontend verification:

```powershell
cd E:/admin_go/admin_front_ts
npx vue-tsc -b --pretty false
npx eslint src/api/system/uploadConfig.ts src/views/Main/system/uploadConfig/**/*.vue
git diff --check
```

- [ ] Workspace docs verification:

```powershell
cd E:/admin_go
git diff --check
```

- [ ] Completion report must include:

```text
Outcome:
Changed files:
Backend verification:
Frontend verification:
Smoke summary:
Known remaining risks:
Next recommended spec: upload runtime/token foundation
```

## Implementation Notes

- Do not install COS/OSS SDK in this plan.
- Do not change database schema in this plan.
- Do not mark `/api/getUploadToken` as migrated.
- Do not log or return encrypted secret columns.
- Do not silently fallback to legacy PHP endpoints.
- If existing rows fail decryption during later upload runtime work, stop and verify `VAULT_KEY`; do not re-encrypt blindly.
