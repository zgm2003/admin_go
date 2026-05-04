# Admin Foundation Modules Batch 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate the next admin foundation modules from PHP legacy to Go REST + Vue typed clients: system settings first, then upload drivers/rules/settings as configuration management only. Keep the existing official `asynqmon` queue monitor; only remove the old `devtools_queue_monitor_queues` system-setting row from the new setting contract.

**Architecture:** Keep `admin_back_go` as Gin modular monolith. Each backend module follows `route -> handler -> service -> repository -> model`; enum/dict/validate stay in shared `internal/*`; frontend API uses `request` and `/api/admin/v1` only. Upload token and real cloud SDK are explicitly deferred until upload configuration is verified; future runtime default dependencies may include COS only, while OSS remains optional/user-installed.

**Tech Stack:** Go 1.21+, Gin, GORM, MySQL, Redis cache where already wired, Element Plus, Vue 3 `<script setup lang="ts">`, TypeScript.

---

## Source Spec

Read first:

- `docs/superpowers/specs/2026-05-04-admin-foundation-modules-design.md`
- `docs/migration/current-status.md`
- `docs/contracts/admin-api-v1.md`
- `admin_back_go/docs/architecture.md`

## Phase Boundary

This plan is **foundation batch 1**, not broad business migration.

Included:

- `system-settings`
- legacy queue config cleanup for `devtools_queue_monitor_queues` only; queue monitor itself remains asynqmon-based
- `upload-drivers`
- `upload-rules`
- `upload-settings`
- contract/status/smoke docs

Excluded:

- `/api/getUploadToken`
- actual upload SDK: COS default, OSS optional extension
- notification task
- export task
- table/schema changes

## File Map

### Backend create/modify

- Create: `admin_back_go/internal/enum/system_setting.go`
- Create/Modify: `admin_back_go/internal/enum/upload.go`
- Modify: `admin_back_go/internal/dict/dict.go`
- Modify: `admin_back_go/internal/validate/register.go`
- Create: `admin_back_go/internal/validate/system_setting.go`
- Create: `admin_back_go/internal/validate/upload.go`
- Create: `admin_back_go/internal/platform/secretbox/secretbox.go`
- Create: `admin_back_go/internal/module/systemsetting/*`
- Create: `admin_back_go/internal/module/uploadconfig/*`
- Modify: `admin_back_go/internal/bootstrap/app.go`
- Modify: `admin_back_go/internal/bootstrap/route_meta.go`
- Modify: `admin_back_go/internal/server/router.go`
- Modify: `admin_back_go/docs/architecture.md`
- Modify: `admin_back_go/scripts/full-admin-smoke.ps1`

### Frontend modify

- Modify: `admin_front_ts/src/api/system/setting.ts`
- Modify: `admin_front_ts/src/api/system/uploadConfig.ts`
- Modify: `admin_front_ts/src/views/Main/system/setting/index.vue`
- Modify: `admin_front_ts/src/views/Main/system/uploadConfig/components/UploadDriver/index.vue`
- Modify: `admin_front_ts/src/views/Main/system/uploadConfig/components/UploadRule/index.vue`
- Modify: `admin_front_ts/src/views/Main/system/uploadConfig/components/UploadSetting/index.vue`

### Workspace docs modify

- Modify: `docs/contracts/admin-api-v1.md`
- Modify: `docs/migration/current-status.md`
- Modify: `docs/testing/smoke-matrix.md`

---

## Task 1: System Settings Contract and Backend Skeleton

**Goal:** Land system settings backend shape without touching upload yet.

- [ ] Add enum values for value types: string/number/bool/json.
- [ ] Add dict options `system_setting_value_type_arr` from enum.
- [ ] Add validator tags for system setting value type and common status if missing.
- [ ] Create `internal/module/systemsetting` with request/dto/model/repository/service/handler/route.
- [ ] Register routes:

```text
GET    /api/admin/v1/system-settings/init
GET    /api/admin/v1/system-settings
POST   /api/admin/v1/system-settings
PUT    /api/admin/v1/system-settings/:id
PATCH  /api/admin/v1/system-settings/:id/status
DELETE /api/admin/v1/system-settings/:id
DELETE /api/admin/v1/system-settings
```

- [ ] Service rules:
  - create-only `key`
  - prefix filter by `key`
  - value type validation
  - soft delete only
  - cache invalidation for changed key if setting cache exists
  - old `devtools_queue_monitor_queues` row is not part of the Go setting contract and must be cleaned up separately
- [ ] Add operation log metadata for create/update/status/delete.
- [ ] Add tests for list filter, create duplicate key rejection, type validation, update missing row, status invalidation, delete batch.
- [ ] Update `docs/contracts/admin-api-v1.md` with system-settings contract.
- [ ] Document that queue monitor stays on official asynqmon and no longer reads `devtools_queue_monitor_queues` from system settings.

Verification:

```powershell
cd E:/admin_go/admin_back_go
go test -p=1 ./internal/module/systemsetting ./internal/enum ./internal/dict ./internal/validate ./internal/server ./internal/bootstrap
```

## Task 2: System Settings Frontend Migration

**Goal:** Make system setting page call Go REST without changing UI shape.

- [ ] Change `src/api/system/setting.ts` from `legacyRequest` to `request + ADMIN_API_PREFIX`.
- [ ] Map methods:

```text
init   -> GET    /system-settings/init
list   -> GET    /system-settings
add    -> POST   /system-settings
edit   -> PUT    /system-settings/:id
status -> PATCH  /system-settings/:id/status
del    -> DELETE /system-settings/:id or DELETE /system-settings body { ids }
```

- [ ] Keep explicit TS interfaces; remove `RequestPayload` inheritance if it exists only for loose typing.
- [ ] Update page code only where API contract requires it.
- [ ] Do not add fallback field aliases.

Verification:

```powershell
cd E:/admin_go/admin_front_ts
npx vue-tsc -b --pretty false
npx eslint src/api/system/setting.ts src/views/Main/system/setting/index.vue
```

## Task 3: Upload Enum, Dict, and Secretbox Foundation

**Goal:** Build upload shared foundation before CRUD.

- [ ] Add upload enum for drivers, image extensions, file extensions, upload folders if needed for later token work.
- [ ] Add dict builders:

```text
upload_driver_arr
upload_image_ext_arr
upload_file_ext_arr
```

- [ ] Add validator tags that call enum membership checks.
- [ ] Add `internal/platform/secretbox` thin encryption wrapper.
- [ ] Secretbox rules:
  - configured key required for encrypt/decrypt
  - no fake encryption
  - hint never reveals full secret
  - tests cover missing key, encrypt/decrypt roundtrip, hint shape
- [ ] Document that upload token is deferred.

Verification:

```powershell
cd E:/admin_go/admin_back_go
go test -p=1 ./internal/platform/secretbox ./internal/enum ./internal/dict ./internal/validate
```

## Task 4: Upload Drivers Backend and Frontend

**Goal:** Migrate cloud storage driver configuration without exposing secrets.

- [ ] Create driver model/repository/service/handler in `internal/module/uploadconfig` or subfiles named clearly by resource.
- [ ] Register routes:

```text
GET    /api/admin/v1/upload-drivers/init
GET    /api/admin/v1/upload-drivers
POST   /api/admin/v1/upload-drivers
PUT    /api/admin/v1/upload-drivers/:id
DELETE /api/admin/v1/upload-drivers/:id
DELETE /api/admin/v1/upload-drivers
```

- [ ] Service rules:
  - driver enum only
  - create requires secret_id and secret_key
  - update omits secret fields to keep old encrypted values
  - list never returns plaintext secrets
  - duplicate `driver + bucket` rejected
- [ ] Add operation log metadata with secret masking.
- [ ] Migrate `UploadDriverApi` in `src/api/system/uploadConfig.ts` to Go REST.
- [ ] Adjust UploadDriver page only as required by typed REST methods.

Verification:

```powershell
cd E:/admin_go/admin_back_go
go test -p=1 ./internal/module/uploadconfig ./internal/platform/secretbox ./internal/server ./internal/bootstrap
cd E:/admin_go/admin_front_ts
npx vue-tsc -b --pretty false
npx eslint src/api/system/uploadConfig.ts src/views/Main/system/uploadConfig/components/UploadDriver/index.vue
```

## Task 5: Upload Rules Backend and Frontend

**Goal:** Migrate upload file validation rules.

- [ ] Register routes:

```text
GET    /api/admin/v1/upload-rules/init
GET    /api/admin/v1/upload-rules
POST   /api/admin/v1/upload-rules
PUT    /api/admin/v1/upload-rules/:id
DELETE /api/admin/v1/upload-rules/:id
DELETE /api/admin/v1/upload-rules
```

- [ ] Service rules:
  - title unique
  - max size 1..10240 MB
  - extension arrays must be enum members
  - JSON storage returns arrays to frontend
- [ ] Add tests for invalid extension rejection and duplicate title.
- [ ] Migrate `UploadRuleApi` to Go REST.

Verification:

```powershell
cd E:/admin_go/admin_back_go
go test -p=1 ./internal/module/uploadconfig ./internal/enum ./internal/dict ./internal/validate
cd E:/admin_go/admin_front_ts
npx vue-tsc -b --pretty false
npx eslint src/api/system/uploadConfig.ts src/views/Main/system/uploadConfig/components/UploadRule/index.vue
```

## Task 6: Upload Settings Backend and Frontend

**Goal:** Migrate active upload setting selection with transactional exclusivity.

- [ ] Register routes:

```text
GET    /api/admin/v1/upload-settings/init
GET    /api/admin/v1/upload-settings
POST   /api/admin/v1/upload-settings
PUT    /api/admin/v1/upload-settings/:id
PATCH  /api/admin/v1/upload-settings/:id/status
DELETE /api/admin/v1/upload-settings/:id
DELETE /api/admin/v1/upload-settings
```

- [ ] Service rules:
  - driver/rule existence required
  - duplicate driver_id + rule_id rejected
  - enabling uses DB transaction to disable other enabled rows first
  - enabled setting cannot be deleted
- [ ] Add tests for exclusive enable, enabled delete rejection, init dict from current driver/rule rows.
- [ ] Migrate `UploadSettingApi` to Go REST.

Verification:

```powershell
cd E:/admin_go/admin_back_go
go test -p=1 ./internal/module/uploadconfig ./internal/server ./internal/bootstrap
cd E:/admin_go/admin_front_ts
npx vue-tsc -b --pretty false
npx eslint src/api/system/uploadConfig.ts src/views/Main/system/uploadConfig/components/UploadSetting/index.vue
```

## Task 7: Docs and Smoke

**Goal:** Make cold-start docs match runtime and add safe smoke probes.

- [ ] Update `docs/contracts/admin-api-v1.md` with all four resource contracts.
- [ ] Update `docs/migration/current-status.md`:
  - system settings implemented only after verified
  - upload config implemented only after verified
  - upload token remains planned
- [ ] Update `docs/testing/smoke-matrix.md` with full smoke coverage.
- [ ] Extend `full-admin-smoke.ps1` with harmless probes:
  - system-settings init/list
  - upload-drivers init/list
  - upload-rules init/list
  - upload-settings init/list
  - optionally create disabled temp upload rule/driver/setting only if secretbox env exists; otherwise read-only probe only
- [ ] Do not add write smoke that requires real cloud credentials.

Verification:

```powershell
cd E:/admin_go/admin_back_go
go test -p=1 ./...
go vet -p=1 ./...
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account 15671628271 -Password 123456
cd E:/admin_go/admin_front_ts
npx vue-tsc -b --pretty false
npx eslint src/api/system/setting.ts src/api/system/uploadConfig.ts src/views/Main/system/setting/index.vue src/views/Main/system/uploadConfig/**/*.vue
cd E:/admin_go
git diff --check
```

## Completion Report Template

```text
Outcome:
Changed files:
Backend verification:
Frontend verification:
Smoke summary:
Known risks:
Next recommended step:
```

## Next After This Plan

After this batch is verified, the next foundation slice should be:

```text
COS-first upload token + real storage SDK boundary; OSS optional extension
```

Only then should business modules that upload/export generated assets depend on Go upload services.
