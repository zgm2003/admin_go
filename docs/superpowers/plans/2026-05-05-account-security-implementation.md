# Account Security Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` for sequential execution. Steps use checkbox (`- [x]`) syntax for tracking. Do not create worktree. Do not commit unless the user explicitly asks.

**Goal:** Migrate personal account security writes from PHP legacy APIs to Go REST endpoints.

**Architecture:** Keep the slice inside `internal/module/user` as part of profile ownership. Reuse auth verification-code storage through a small dependency boundary; do not couple user service to `auth.Service`. Keep route -> handler -> service -> repository -> model.

**Tech Stack:** Go, Gin, go-playground validator, bcrypt, GORM, Vue 3 `<script setup lang="ts">`, typed request client.

---

## Task 1: Enum / dict / validate foundation

**Files:**
- Modify: `admin_back_go/internal/enum/user.go`
- Modify: `admin_back_go/internal/dict/dict.go`
- Modify: `admin_back_go/internal/dict/dict_test.go`
- Modify: `admin_back_go/internal/validate/user.go`
- Modify: `admin_back_go/internal/validate/register.go`
- Modify: `admin_back_go/internal/validate/validate_test.go`

- [x] Add enum constants `VerifyTypePassword=password`, `VerifyTypeCode=code`, `IsUserVerifyType`.
- [x] Add `dict.UserVerifyTypeOptions()` returning password then code.
- [x] Register `user_verify_type` validation tag backed by enum.
- [x] Run `go test ./internal/enum ./internal/dict ./internal/validate`.

## Task 2: Public verify-code helper and user service dependency

**Files:**
- Modify: `admin_back_go/internal/module/auth/code_store.go`
- Modify: `admin_back_go/internal/module/user/service.go`
- Modify: `admin_back_go/internal/module/user/dto.go`
- Modify: `admin_back_go/internal/bootstrap/app.go`

- [x] Export `auth.VerifyCodeCacheKey(prefix, accountType, scene, account)` so user module can reuse the exact key rule without importing auth service.
- [x] Add user `VerifyCodeStore` interface with `Get/Delete` only.
- [x] Extend `user.NewService` with option-style `WithVerifyCodeStore(store, prefix)` or a minimal constructor-safe option so existing tests remain readable.
- [x] Use `dict.UserVerifyTypeOptions()` for profile dict.

## Task 3: Backend TDD for service behavior

**Files:**
- Modify: `admin_back_go/internal/module/user/service_test.go`

- [x] Add fake code store and repository duplicate tracking methods.
- [x] Write failing tests for password old-password path.
- [x] Write failing tests for password code path consuming `change_password` code.
- [x] Write failing tests for email bind duplicate and successful write.
- [x] Write failing tests for phone duplicate and successful write.
- [x] Run `go test ./internal/module/user` and confirm RED failures are for missing methods/behavior.

## Task 4: Implement service/repository security writes

**Files:**
- Modify: `admin_back_go/internal/module/user/repository.go`
- Modify: `admin_back_go/internal/module/user/service.go`
- Modify: `admin_back_go/internal/module/user/dto.go`

- [x] Add repository methods `ExistsEmailForOtherUser`, `ExistsPhoneForOtherUser`.
- [x] Add service methods `UpdatePassword`, `UpdateEmail`, `UpdatePhone`.
- [x] Add bcrypt verify/hash helpers in user module; support reading `$2y$` and save generated hash as `$2y$`.
- [x] Consume verification codes only after all business validation passes.
- [x] Run `go test ./internal/module/user` and keep existing tests green.

## Task 5: Handler/routes/metadata

**Files:**
- Modify: `admin_back_go/internal/module/user/request.go`
- Modify: `admin_back_go/internal/module/user/handler.go`
- Modify: `admin_back_go/internal/module/user/handler_test.go`
- Modify: `admin_back_go/internal/module/user/route.go`
- Modify: `admin_back_go/internal/bootstrap/route_meta.go`
- Modify: `admin_back_go/internal/bootstrap/route_meta_test.go`

- [x] Add request DTOs for password/email/phone security updates with strict binding tags.
- [x] Add `PUT /api/admin/v1/profile/security/password|email|phone` routes.
- [x] Add handler methods using current auth identity only.
- [x] Add operation-log metadata for all three routes.
- [x] Assert these routes do not gain user-manager permission rules.
- [x] Run `go test ./internal/module/user ./internal/bootstrap`.

## Task 6: Frontend typed API switch

**Files:**
- Modify: `admin_front_ts/src/types/user.ts`
- Modify: `admin_front_ts/src/api/user/users.ts`
- Modify: `admin_front_ts/src/views/Main/personal/components/Security/index.vue`

- [x] Add `account` to code-verified password update payload.
- [x] Switch updatePhone/updateEmail/updatePassword from `legacyRequest.post` to `request.put` under `/api/admin/v1/profile/security/...`.
- [x] Update Security component to pass `account: passwordAccount` when using code verify.
- [x] Keep component focused; no UI rewrite.
- [x] Run targeted `npx vue-tsc -b --pretty false` and eslint if environment allows.

## Task 7: Docs and smoke

**Files:**
- Modify: `docs/contracts/admin-api-v1.md`
- Modify: `docs/migration/current-status.md`
- Modify: `docs/testing/smoke-matrix.md`
- Modify: `admin_back_go/docs/architecture.md`
- Modify: `admin_back_go/scripts/full-admin-smoke.ps1`

- [x] Update Profile status from legacy security adapter to implemented.
- [x] Document the three REST endpoints, request schemas, errors, operation logs.
- [x] Add full smoke failure probes that do not mutate real account security data.
- [x] Run `powershell -ExecutionPolicy Bypass -File .\scripts\check-contract.ps1`.

## Final verification

Backend:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/enum ./internal/dict ./internal/validate ./internal/module/auth ./internal/module/user ./internal/bootstrap
go test -p=1 ./...
go vet -p=1 ./...
git diff --check -- . ':!runtime/**' ':!.tmp/**'
powershell -ExecutionPolicy Bypass -File .\scripts\check-contract.ps1
```

Frontend:

```powershell
cd E:\admin_go\admin_front_ts
npx vue-tsc -b --pretty false
npx eslint src/api/user/users.ts src/types/user.ts src/views/Main/personal/components/Security/index.vue
```

