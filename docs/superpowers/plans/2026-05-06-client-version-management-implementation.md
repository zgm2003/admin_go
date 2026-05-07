# Client Version Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Do not create a worktree and do not commit unless the user explicitly asks.

**Goal:** Migrate “系统管理 / 版本管理” from legacy PHP `TauriVersion` APIs to normalized Go REST `/api/admin/v1/client-versions` plus typed Vue client, including manifest publish correctness.

**Architecture:** Keep the Go modular monolith boundary: `route -> handler -> service -> repository -> model`. The Go module is `clientversion`; the DB table is `client_versions`; frontend route folder is `clientVersion`. The menu PAGE path/component/i18n key use clientVersion, and mutating route permissions use canonical `system_clientVersion_*` codes.

**Tech Stack:** Gin, GORM, MySQL, existing secretbox/VAULT_KEY, official Tencent COS Go SDK for server-side manifest PutObject, Vue 3 + TypeScript + Element Plus.

---

## Task 0: Baseline guard and current facts

**Files:**
- Read: `E:/admin_go/AGENTS.md`
- Read: `E:/admin_go/docs/superpowers/specs/2026-05-06-client-version-management-design.md`
- Read: `E:/admin_go/docs/contracts/admin-api-v1.md`
- Read: `E:/admin_go/docs/migration/current-status.md`
- Read: `E:/admin_go/admin_back_go/docs/architecture.md`

- [ ] Run `git status --short` at root, backend, frontend and record unrelated dirty files.
- [ ] Confirm `client_versions` columns/indexes and active latest row with read-only SQL after migration.
- [ ] Confirm canonical permission codes `system_clientVersion_*` exist and old `devTools_tauriVersion_*` codes do not remain in active DB rows.
- [ ] Confirm legacy `src/api/system/tauriVersion.ts` is deleted or no longer imported after the typed `clientVersion.ts` migration.
- [ ] Do not edit code until this evidence matches the design.

## Task 1: Backend enum/dict/validate foundation

**Files:**
- Create: `E:/admin_go/admin_back_go/internal/enum/client_version.go`
- Create/Modify: `E:/admin_go/admin_back_go/internal/enum/client_version_test.go`
- Modify: `E:/admin_go/admin_back_go/internal/dict/dict.go` or create focused `client_version.go`
- Create/Modify: `E:/admin_go/admin_back_go/internal/dict/client_version_test.go`
- Create: `E:/admin_go/admin_back_go/internal/validate/client_version.go`
- Modify: `E:/admin_go/admin_back_go/internal/validate/validate_test.go`

- [ ] Add `ClientPlatformWindowsX8664` and `ClientPlatformDarwinX8664` constants.
- [ ] Add `IsClientPlatform(value string) bool` and `ClientPlatformName(value string) string`.
- [ ] Add dict options `client_version_platform_arr` and reuse existing common yes/no dict if present.
- [ ] Register validator tag `client_platform`.
- [ ] Write table-driven tests for valid/invalid platforms and dict order.
- [ ] Run `go test ./internal/enum ./internal/dict ./internal/validate`.

## Task 2: Storage publisher boundary

**Files:**
- Modify/Create: `E:/admin_go/admin_back_go/internal/platform/storage/cos/object_writer.go`
- Create: `E:/admin_go/admin_back_go/internal/platform/storage/cos/object_writer_test.go`
- Modify: `E:/admin_go/admin_back_go/go.mod`
- Modify: `E:/admin_go/admin_back_go/go.sum`

- [ ] Add official dependency `github.com/tencentyun/cos-go-sdk-v5` only if not already present.
- [ ] Define a tiny project interface, e.g. `type ObjectWriter interface { Put(ctx context.Context, input PutInput) error }`.
- [ ] Implement COS writer with context timeout, bucket/region validation, and `application/json; charset=utf-8` content type support.
- [ ] Keep this package generic; it must know nothing about client versions.
- [ ] Unit-test disabled/invalid config and request construction with fake transport where practical.
- [ ] Run `go test ./internal/platform/storage/cos`.

## Task 3: Client version module model/repository

**Files:**
- Create: `E:/admin_go/admin_back_go/internal/module/clientversion/model.go`
- Create: `E:/admin_go/admin_back_go/internal/module/clientversion/dto.go`
- Create: `E:/admin_go/admin_back_go/internal/module/clientversion/errors.go`
- Create: `E:/admin_go/admin_back_go/internal/module/clientversion/repository.go`
- Create: `E:/admin_go/admin_back_go/internal/module/clientversion/repository_test.go` only if DB behavior is isolated with fake DB or existing test pattern supports it

- [ ] Map model to table `client_versions`.
- [ ] Define repository interface for list/count/get/create/update/soft-delete/latest operations.
- [ ] Implement `WithTransaction(ctx, fn)` using GORM transaction, keeping business decisions in service.
- [ ] Ensure all active queries filter `is_del=2`.
- [ ] Implement `ClearLatestByPlatform` and `SetLatest` used inside transaction.
- [ ] Keep repository free of manifest logic.

## Task 4: Service behavior and tests

**Files:**
- Create: `E:/admin_go/admin_back_go/internal/module/clientversion/service.go`
- Create: `E:/admin_go/admin_back_go/internal/module/clientversion/service_test.go`

- [ ] Write failing tests for duplicate create rejection.
- [ ] Write failing tests for default `is_latest=2`, `force_update=2`.
- [ ] Write failing tests for set-latest same-platform transaction behavior.
- [ ] Write failing tests for delete latest rejection and non-latest soft delete.
- [ ] Write failing tests for force-update invalid value rejection.
- [ ] Write failing tests for manifest payload with RFC3339 `pub_date` and platform-specific signature/url.
- [ ] Write failing tests that update-latest and set-latest call publisher.
- [ ] Write failing tests that publisher failure returns explicit error and does not silently succeed.
- [ ] Write current-check tests: matching force row true, normal/missing false.
- [ ] Implement minimal service methods to pass tests.
- [ ] Keep service signatures context-based; no `gin.Context`.
- [ ] Run `go test ./internal/module/clientversion`.

## Task 5: Handler, request binding, routes

**Files:**
- Create: `E:/admin_go/admin_back_go/internal/module/clientversion/request.go`
- Create: `E:/admin_go/admin_back_go/internal/module/clientversion/handler.go`
- Create: `E:/admin_go/admin_back_go/internal/module/clientversion/handler_test.go`
- Create: `E:/admin_go/admin_back_go/internal/module/clientversion/route.go`
- Modify: `E:/admin_go/admin_back_go/internal/server/router.go`
- Modify: `E:/admin_go/admin_back_go/internal/server/router_test.go`
- Modify: `E:/admin_go/admin_back_go/internal/bootstrap/app.go`

- [ ] Add binding structs for list/create/update/force/current-check/update-json.
- [ ] `GET /page-init`, `GET /`, `GET /update-json`, `GET /current-check`, `POST /`, `PUT /:id`, `PATCH /:id/latest`, `PATCH /:id/force-update`, `DELETE /:id`.
- [ ] Current-check route must be public; register it before auth middleware if router structure requires that.
- [ ] Admin read/mutation routes require bearer token through existing middleware chain.
- [ ] Add fake service tests in `router_test.go` to prove paths/methods are installed and request mapping is correct.
- [ ] Run `go test ./internal/module/clientversion ./internal/server`.

## Task 6: RBAC route metadata and OperationLog

**Files:**
- Modify: `E:/admin_go/admin_back_go/internal/bootstrap/route_meta.go`
- Modify: `E:/admin_go/admin_back_go/internal/bootstrap/route_meta_test.go`

- [ ] Add permission metadata only for mutation routes:
  - `POST /api/admin/v1/client-versions` -> `system_clientVersion_add`
  - `PUT /api/admin/v1/client-versions/:id` -> `system_clientVersion_edit`
  - `PATCH /api/admin/v1/client-versions/:id/latest` -> `system_clientVersion_setLatest`
  - `PATCH /api/admin/v1/client-versions/:id/force-update` -> `system_clientVersion_forceUpdate`
  - `DELETE /api/admin/v1/client-versions/:id` -> `system_clientVersion_del`
- [ ] Add OperationLog metadata for those same mutation routes with module `client_version`.
- [ ] Add tests proving read/update-json/current-check routes have no OperationLog metadata.
- [ ] Run `go test ./internal/bootstrap`.

## Task 7: Contract and migration docs

**Files:**
- Modify: `E:/admin_go/docs/contracts/admin-api-v1.md`
- Modify: `E:/admin_go/docs/migration/current-status.md`
- Modify: `E:/admin_go/admin_back_go/docs/architecture.md`
- Modify: `E:/admin_go/docs/testing/smoke-matrix.md` if present

- [ ] Add `Client Versions` section with every endpoint, auth requirement, request/response, error cases.
- [ ] Record public current-check route explicitly.
- [ ] Record mutation permission codes and OperationLog metadata.
- [ ] Record manifest publish behavior and COS-only server-side publish dependency.
- [ ] Update current status as `implemented` only after code and verification pass; before then use `planned` or do not add status row.
- [ ] Run `powershell -ExecutionPolicy Bypass -File .\scripts\check-contract.ps1` from backend.

## Task 8: Frontend typed API migration

**Files:**
- Create: `E:/admin_go/admin_front_ts/src/api/system/clientVersion.ts`
- Delete or stop importing: `E:/admin_go/admin_front_ts/src/api/system/tauriVersion.ts`
- Modify: `E:/admin_go/admin_front_ts/src/views/Main/system/clientVersion/index.vue`
- Modify: `E:/admin_go/admin_front_ts/src/components/TauriManager/src/index.vue`
- Optional test: `E:/admin_go/admin_front_ts/tests/shared/system/client-version-api.test.ts`

- [ ] Implement `ClientVersionApi` with `request` and `ADMIN_API_PREFIX`.
- [ ] Normalize `del({ id })` to REST DELETE single id; do not add batch delete unless backend supports it.
- [ ] Map `pageInit`, `list`, `add`, `edit`, `setLatest`, `forceUpdate`, `updateJson`, `currentCheck` to new paths.
- [ ] Update page imports/types to `ClientVersion*` names.
- [ ] Rename the page folder and page i18n key to `clientVersion`; keep only explicit legacy menu/view aliases needed during DB migration.
- [ ] Update `TauriManager` to call `ClientVersionApi.currentCheck` and remove `const res: any`.
- [ ] Replace `catch (error: any)` in touched `TauriManager` blocks with safe helper such as `getErrorMessage(error: unknown)` if touching that file.
- [ ] If touching download filename, derive extension from URL; do not keep `.zip` for `.exe` release.
- [ ] Run `npx vue-tsc -b --pretty false`.
- [ ] Run targeted eslint for touched files.

## Task 9: Smoke script extension

**Files:**
- Modify: `E:/admin_go/admin_back_go/scripts/full-admin-smoke.ps1`
- Modify: `E:/admin_go/docs/testing/smoke-matrix.md`

- [ ] Add read-only probes for page-init, list, and update-json shape.
- [ ] Add `-EnableClientVersionWriteProbe` flag for temp create/set-latest/force/delete flow.
- [ ] Default full smoke must not alter current latest version.
- [ ] Write probe cleanup must restore latest row and soft-delete temp rows even on failure.
- [ ] Print summary fields under `client_version`.

## Task 10: Final verification gate for this slice

Run from `E:/admin_go/admin_back_go`:

```powershell
go test ./internal/enum ./internal/dict ./internal/validate ./internal/platform/storage/cos ./internal/module/clientversion ./internal/bootstrap ./internal/server
go vet ./internal/enum ./internal/dict ./internal/validate ./internal/platform/storage/cos ./internal/module/clientversion ./internal/bootstrap ./internal/server
powershell -ExecutionPolicy Bypass -File .\scripts\check-contract.ps1
git diff --check
```

Run from `E:/admin_go/admin_front_ts`:

```powershell
npx vue-tsc -b --pretty false
npx eslint src/api/system/clientVersion.ts src/views/Main/system/clientVersion/index.vue src/views/Main/system/clientVersion/components/SignatureInput.vue src/router/view-registry.ts tests/shared/router/view-registry.test.ts src/components/TauriManager/src/index.vue
```

If frontend changes touch shared upload/table/dialog code, also run:

```powershell
npm run build
```

## Handoff output after implementation

Return this shape:

```text
Outcome:
Changed files:
Backend verification:
Frontend verification:
Smoke summary:
Known risks:
Next recommended module:
```
