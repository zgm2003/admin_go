# COS-only Upload Governance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Converge the upload configuration and runtime contract to Tencent COS only, removing the fake OSS option while preserving existing COS client-token and server-side upload flows.

**Architecture:** Keep the existing Go modular monolith boundaries: `enum` owns upload constants, `uploadconfig` owns admin configuration mutation, `uploadtoken` owns browser upload credentials, and COS platform packages own Tencent SDK calls. The Vue upload config page remains a thin Composition API view over typed REST clients; shared upload runtime keeps COS-only `uploadFileToCloud` and URL construction.

**Tech Stack:** Go 1.21+, Gin/Gorm service modules, Tencent COS Go SDK boundary, Vue 3 `<script setup lang="ts">`, Element Plus, Vitest, vue-tsc.

---

## Spec and current-state inputs

Read these before executing the tasks:

- `docs/superpowers/specs/2026-05-16-cos-upload-governance-design.md`
- `docs/status/current-status.md`
- `docs/contracts/admin-api-v1.md`
- `admin_back_go/internal/enum/upload.go`
- `admin_back_go/internal/module/uploadconfig/service.go`
- `admin_back_go/internal/module/uploadtoken/service.go`
- `admin_front_ts/src/api/system/uploadConfig.ts`
- `admin_front_ts/src/views/Main/system/uploadConfig/components/UploadDriver/index.vue`
- `admin_front_ts/src/lib/upload/url.ts`

Keep unrelated dirty files out of every commit. At plan creation time, unrelated SMS docs were already modified in the root workspace. Do not stage them unless the user explicitly asks.

## File responsibility map

Backend files:

- `admin_back_go/internal/enum/upload.go` — active upload driver enum, labels, upload folders, extension normalization.
- `admin_back_go/internal/enum/upload_test.go` — guards that COS is the only upload driver.
- `admin_back_go/internal/module/uploadconfig/service.go` — create/update driver validation, driver init dict, setting dict labels.
- `admin_back_go/internal/module/uploadconfig/service_test.go` — service-level tests for COS-only validation and bucket-domain host semantics.
- `admin_back_go/internal/module/uploadtoken/service.go` — client-token runtime; should remain COS-only and one-key scoped.
- `admin_back_go/internal/module/uploadtoken/service_test.go` — token runtime tests, including non-COS rejection and bare bucket-domain return.
- `admin_back_go/database/migrations/20260516_cos_upload_only.sql` — soft-disable active OSS upload config/driver rows and normalize current COS bucket domains to bare host.

Frontend files:

- `admin_front_ts/src/api/system/uploadConfig.ts` — typed upload config REST contract; `UploadDriverType` becomes `'cos'` only.
- `admin_front_ts/src/views/Main/system/uploadConfig/components/UploadDriver/index.vue` — remove OSS branch and keep COS-only form.
- `admin_front_ts/src/i18n/locales/zh-CN.ts` — upload config copy says COS-only and bare access domain.
- `admin_front_ts/src/i18n/locales/en-US.ts` — English copy mirrors COS-only semantics.
- `admin_front_ts/src/lib/upload/url.ts` — shared public URL builder; keep defensive scheme handling for legacy values while config validation rejects scheme.
- `admin_front_ts/tests/shared/system/upload-config-copy.test.ts` — static UI/copy guard.
- `admin_front_ts/tests/shared/system/upload-client-url.test.ts` — URL builder guard.
- `admin_front_ts/tests/shared/system/upload-config-api.test.ts` — new static API guard for COS-only types and query normalization.

Docs files:

- `docs/status/current-status.md` — after implementation, describe upload runtime as Tencent COS-only.
- `docs/contracts/admin-api-v1.md` — after implementation, document upload driver `driver=cos` only and `bucket_domain` as bare host.

---

### Task 1: Backend enum becomes COS-only

**Files:**
- Modify: `admin_back_go/internal/enum/upload_test.go`
- Modify: `admin_back_go/internal/enum/upload.go`

- [ ] **Step 1: Write the failing enum test**

Replace `TestUploadDriverMembership` in `admin_back_go/internal/enum/upload_test.go` with this test:

```go
func TestUploadDriverMembership(t *testing.T) {
	if !IsUploadDriver(UploadDriverCOS) {
		t.Fatalf("cos must be the only supported upload driver")
	}
	if IsUploadDriver("oss") || IsUploadDriver("s3") || IsUploadDriver("") {
		t.Fatalf("only cos should be accepted as an upload driver")
	}
	if len(UploadDrivers) != 1 || UploadDrivers[0] != UploadDriverCOS {
		t.Fatalf("upload drivers must be COS-only, got %#v", UploadDrivers)
	}
	if len(UploadDriverLabels) != 1 || UploadDriverLabels[UploadDriverCOS] != "腾讯云 COS" {
		t.Fatalf("upload driver labels must expose COS only, got %#v", UploadDriverLabels)
	}
}
```

- [ ] **Step 2: Run the enum test and verify RED**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/enum -run TestUploadDriverMembership -count=1
```

Expected result before implementation:

```text
FAIL
only cos should be accepted as an upload driver
```

- [ ] **Step 3: Implement COS-only enum**

Edit `admin_back_go/internal/enum/upload.go` so the driver section is exactly:

```go
const (
	UploadDriverCOS = "cos"
)

var UploadDrivers = []string{
	UploadDriverCOS,
}

var UploadDriverLabels = map[string]string{
	UploadDriverCOS: "腾讯云 COS",
}
```

Remove `UploadDriverOSS` entirely. Do not add a replacement alias.

- [ ] **Step 4: Run enum tests and verify GREEN**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/enum -count=1
```

Expected result:

```text
ok  	admin_back_go/internal/enum
```

- [ ] **Step 5: Commit Task 1**

Run:

```powershell
git -C E:\admin_go\admin_back_go add internal/enum/upload.go internal/enum/upload_test.go
git -C E:\admin_go\admin_back_go commit -m "refactor: make upload driver cos only"
```

Expected result: one backend commit containing only enum files.

---

### Task 2: Backend uploadconfig rejects non-COS and scheme-bearing bucket domains

**Files:**
- Modify: `admin_back_go/internal/module/uploadconfig/service_test.go`
- Modify: `admin_back_go/internal/module/uploadconfig/service.go`

- [ ] **Step 1: Update driver init test to expect COS-only**

In `admin_back_go/internal/module/uploadconfig/service_test.go`, change `TestDriverInitReturnsEnumBackedDict` assertions to:

```go
options := got.Dict.UploadDriverArr
if len(options) != 1 || options[0].Value != enum.UploadDriverCOS || options[0].Label != "腾讯云 COS" {
	t.Fatalf("upload driver dict must expose COS only, got %#v", options)
}
```

- [ ] **Step 2: Replace the OSS role test with a non-COS rejection test**

Replace `TestDriverCreateRejectsMissingOSSRoleARN` with:

```go
func TestDriverCreateRejectsNonCOSDriver(t *testing.T) {
	service := NewService(&fakeRepository{}, testSecretBox(t))

	_, appErr := service.CreateDriver(context.Background(), DriverCreateInput{Driver: "oss", SecretID: "sid", SecretKey: "skey", Bucket: "bucket-a", Region: "cn-hangzhou"})
	if appErr == nil || appErr.Message != "当前仅支持腾讯云 COS，请重新配置 COS" {
		t.Fatalf("expected COS-only driver error, got %#v", appErr)
	}
}
```

- [ ] **Step 3: Add create/update tests for bare bucket domain**

Append these tests to `admin_back_go/internal/module/uploadconfig/service_test.go`:

```go
func TestDriverCreateRejectsBucketDomainWithScheme(t *testing.T) {
	service := NewService(&fakeRepository{}, testSecretBox(t))

	_, appErr := service.CreateDriver(context.Background(), DriverCreateInput{
		Driver: enum.UploadDriverCOS, SecretID: "sid", SecretKey: "skey", Bucket: "bucket-a", Region: "ap-nanjing", AppID: "1314", BucketDomain: "https://cos.example.com",
	})
	if appErr == nil || appErr.Message != "访问域名请填写裸域名，例如 cos.example.com" {
		t.Fatalf("expected bare-domain validation error, got %#v", appErr)
	}
}

func TestDriverCreateRejectsBucketDomainWithPath(t *testing.T) {
	service := NewService(&fakeRepository{}, testSecretBox(t))

	_, appErr := service.CreateDriver(context.Background(), DriverCreateInput{
		Driver: enum.UploadDriverCOS, SecretID: "sid", SecretKey: "skey", Bucket: "bucket-a", Region: "ap-nanjing", AppID: "1314", BucketDomain: "cos.example.com/path",
	})
	if appErr == nil || appErr.Message != "访问域名请填写裸域名，例如 cos.example.com" {
		t.Fatalf("expected bare-domain validation error, got %#v", appErr)
	}
}

func TestDriverCreateAcceptsBareBucketDomain(t *testing.T) {
	repo := &fakeRepository{}
	service := NewService(repo, testSecretBox(t))

	_, appErr := service.CreateDriver(context.Background(), DriverCreateInput{
		Driver: enum.UploadDriverCOS, SecretID: "sid", SecretKey: "skey", Bucket: "bucket-a", Region: "ap-nanjing", AppID: "1314", BucketDomain: " cos.example.com ",
	})
	if appErr != nil {
		t.Fatalf("expected bare bucket domain to be accepted: %#v", appErr)
	}
	if repo.createdDriver == nil || repo.createdDriver.BucketDomain != "cos.example.com" {
		t.Fatalf("expected trimmed bare bucket domain, got %#v", repo.createdDriver)
	}
}

func TestDriverUpdateRejectsNonCOSDriver(t *testing.T) {
	repo := &fakeRepository{driverByID: map[int64]Driver{7: {ID: 7, Driver: enum.UploadDriverCOS, Bucket: "old", SecretIDEnc: "old-id", SecretKeyEnc: "old-key"}}}
	service := NewService(repo, testSecretBox(t))

	appErr := service.UpdateDriver(context.Background(), 7, DriverUpdateInput{Driver: "oss", Bucket: "bucket-a", Region: "cn-hangzhou"})
	if appErr == nil || appErr.Message != "当前仅支持腾讯云 COS，请重新配置 COS" {
		t.Fatalf("expected COS-only driver error, got %#v", appErr)
	}
}
```

- [ ] **Step 4: Run uploadconfig tests and verify RED**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/uploadconfig -count=1
```

Expected result before implementation: failures around driver dict count, non-COS handling, and bucket domain validation.

- [ ] **Step 5: Add bucket-domain validation helper**

In `admin_back_go/internal/module/uploadconfig/service.go`, add imports if missing:

```go
import (
	"context"
	"encoding/json"
	"math"
	"net/url"
	"sort"
	"strings"
	"time"
)
```

Then add this helper near the existing normalize helpers:

```go
func normalizeBucketDomain(value string) (string, *apperror.Error) {
	domain := strings.TrimSpace(value)
	if domain == "" {
		return "", nil
	}
	if strings.Contains(domain, "://") || strings.Contains(domain, "/") || strings.Contains(domain, "?") || strings.Contains(domain, "#") {
		return "", apperror.BadRequest("访问域名请填写裸域名，例如 cos.example.com")
	}
	parsed, err := url.Parse("https://" + domain)
	if err != nil || parsed.Host != domain || parsed.Hostname() == "" {
		return "", apperror.BadRequest("访问域名请填写裸域名，例如 cos.example.com")
	}
	return domain, nil
}
```

- [ ] **Step 6: Enforce COS-only in create normalization**

In `normalizeDriverCreateInput`, after trimming fields, replace the old driver validation with:

```go
if input.Driver != enum.UploadDriverCOS {
	return input, apperror.BadRequest("当前仅支持腾讯云 COS，请重新配置 COS")
}
if input.Bucket == "" {
	return input, apperror.BadRequest("bucket 不能为空")
}
if input.Region == "" {
	return input, apperror.BadRequest("region 不能为空")
}
if input.AppID == "" {
	return input, apperror.BadRequest("COS appid 不能为空")
}
bucketDomain, appErr := normalizeBucketDomain(input.BucketDomain)
if appErr != nil {
	return input, appErr
}
input.BucketDomain = bucketDomain
return input, nil
```

- [ ] **Step 7: Enforce COS-only in update normalization**

In `normalizeDriverUpdateInput`, use the same validation block as create:

```go
if input.Driver != enum.UploadDriverCOS {
	return input, apperror.BadRequest("当前仅支持腾讯云 COS，请重新配置 COS")
}
if input.Bucket == "" {
	return input, apperror.BadRequest("bucket 不能为空")
}
if input.Region == "" {
	return input, apperror.BadRequest("region 不能为空")
}
if input.AppID == "" {
	return input, apperror.BadRequest("COS appid 不能为空")
}
bucketDomain, appErr := normalizeBucketDomain(input.BucketDomain)
if appErr != nil {
	return input, appErr
}
input.BucketDomain = bucketDomain
return input, nil
```

Remove the old `input.Driver == enum.UploadDriverOSS` role ARN branch.

- [ ] **Step 8: Run uploadconfig tests and verify GREEN**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/uploadconfig -count=1
```

Expected result:

```text
ok  	admin_back_go/internal/module/uploadconfig
```

- [ ] **Step 9: Commit Task 2**

Run:

```powershell
git -C E:\admin_go\admin_back_go add internal/module/uploadconfig/service.go internal/module/uploadconfig/service_test.go
git -C E:\admin_go\admin_back_go commit -m "fix: enforce cos-only upload config"
```

---

### Task 3: Backend uploadtoken keeps COS-only runtime and host-only bucket domain

**Files:**
- Modify: `admin_back_go/internal/module/uploadtoken/service_test.go`
- Modify: `admin_back_go/internal/module/uploadtoken/service.go`

- [ ] **Step 1: Add token response bucket-domain normalization test**

Append this test to `admin_back_go/internal/module/uploadtoken/service_test.go`:

```go
func TestCreateReturnsBareBucketDomainFromConfig(t *testing.T) {
	cfg := validConfig(t, enum.UploadDriverCOS)
	cfg.BucketDomain = "cos.example.com"
	service := NewService(fakeRepository{config: cfg}, secretbox.New([]byte("12345678901234567890123456789012")), &fakeSigner{}, Options{})

	got, appErr := service.Create(context.Background(), validInput())
	if appErr != nil {
		t.Fatalf("Create returned error: %#v", appErr)
	}
	if got.BucketDomain == nil || *got.BucketDomain != "cos.example.com" {
		t.Fatalf("expected bare bucket domain in token response, got %#v", got.BucketDomain)
	}
}
```

- [ ] **Step 2: Keep existing non-COS rejection test aligned**

If `TestCreateRejectsNonCOSDriver` asserts an old message, update it to assert:

```go
if appErr == nil || appErr.Message != "当前上传驱动未启用 COS runtime" {
	t.Fatalf("expected non COS error, got %#v", appErr)
}
```

This is the runtime fallback error when stale data somehow points upload-token at a non-COS row.

- [ ] **Step 3: Run uploadtoken tests**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/uploadtoken -count=1
```

Expected result: tests pass if config cleanup in Task 2 already guarantees host-only values; if not, proceed to Step 4.

- [ ] **Step 4: Add defensive trim in token response**

If Step 3 fails because `BucketDomain` carries whitespace, change the response assignment in `admin_back_go/internal/module/uploadtoken/service.go` from:

```go
BucketDomain: optionalString(cfg.BucketDomain),
```

to:

```go
BucketDomain: optionalString(strings.TrimSpace(cfg.BucketDomain)),
```

- [ ] **Step 5: Run uploadtoken tests and verify GREEN**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/uploadtoken -count=1
```

Expected result:

```text
ok  	admin_back_go/internal/module/uploadtoken
```

- [ ] **Step 6: Commit Task 3**

Run:

```powershell
git -C E:\admin_go\admin_back_go add internal/module/uploadtoken/service.go internal/module/uploadtoken/service_test.go
git -C E:\admin_go\admin_back_go commit -m "test: guard cos upload token domain contract"
```

If only the test file changed, commit only the test file with the same message.

---

### Task 4: Add database migration to disable stale OSS upload config

**Files:**
- Create: `admin_back_go/database/migrations/20260516_cos_upload_only.sql`

- [ ] **Step 1: Create the migration**

Create `admin_back_go/database/migrations/20260516_cos_upload_only.sql` with exactly:

```sql
-- COS-only upload governance.
-- Active upload runtime supports Tencent COS only. Historical OSS rows are
-- soft-disabled instead of physically deleted so old audit references remain readable.

UPDATE `upload_setting` AS s
JOIN `upload_driver` AS d ON d.`id` = s.`driver_id`
SET s.`status` = 2,
    s.`is_del` = 1,
    s.`updated_at` = NOW()
WHERE d.`driver` <> 'cos';

UPDATE `upload_driver`
SET `is_del` = 1,
    `updated_at` = NOW()
WHERE `driver` <> 'cos';

UPDATE `upload_driver`
SET `bucket_domain` = TRIM(BOTH '/' FROM REPLACE(REPLACE(TRIM(`bucket_domain`), 'https://', ''), 'http://', '')),
    `updated_at` = NOW()
WHERE `driver` = 'cos'
  AND `is_del` = 2
  AND `bucket_domain` <> '';
```

- [ ] **Step 2: Validate migration syntax locally without applying broadly**

Run a parser-level dry check by asking MySQL to explain the first update shape is valid on the target schema:

```powershell
cd E:\admin_go\admin_back_go
$env:MYSQL_PWD='123456'
mysql --host=127.0.0.1 --port=3306 --user=root --database=admin --protocol=TCP --execute="SELECT COUNT(*) AS non_cos_settings FROM upload_setting s JOIN upload_driver d ON d.id=s.driver_id WHERE d.driver <> 'cos';"
Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
```

Expected output includes a `non_cos_settings` column. Do not require the count to be zero before migration.

- [ ] **Step 3: Commit Task 4**

Run:

```powershell
git -C E:\admin_go\admin_back_go add database/migrations/20260516_cos_upload_only.sql
git -C E:\admin_go\admin_back_go commit -m "chore: disable non-cos upload config"
```

---

### Task 5: Frontend API types and static guards become COS-only

**Files:**
- Create: `admin_front_ts/tests/shared/system/upload-config-api.test.ts`
- Modify: `admin_front_ts/src/api/system/uploadConfig.ts`

- [ ] **Step 1: Write failing frontend API static test**

Create `admin_front_ts/tests/shared/system/upload-config-api.test.ts`:

```ts
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { describe, expect, it } from 'vitest'

const read = (path: string) => readFileSync(resolve(process.cwd(), path), 'utf8')

describe('upload config API contract', () => {
  it('exposes Tencent COS as the only upload driver type', () => {
    const source = read('src/api/system/uploadConfig.ts')

    expect(source).toContain("export type UploadDriverType = 'cos'")
    expect(source).not.toContain("'cos' | 'oss'")
    expect(source).not.toContain("params.driver === 'oss'")
  })
})
```

- [ ] **Step 2: Run test and verify RED**

Run:

```powershell
cd E:\admin_go\admin_front_ts
npx vitest run tests/shared/system/upload-config-api.test.ts
```

Expected result before implementation:

```text
FAIL
expected source not to contain "'cos' | 'oss'"
```

- [ ] **Step 3: Update upload config API type**

In `admin_front_ts/src/api/system/uploadConfig.ts`, change:

```ts
export type UploadDriverType = 'cos' | 'oss'
```

to:

```ts
export type UploadDriverType = 'cos'
```

Change query normalization from:

```ts
if (params.driver === 'cos' || params.driver === 'oss') {
  query.driver = params.driver
}
```

to:

```ts
if (params.driver === 'cos') {
  query.driver = params.driver
}
```

- [ ] **Step 4: Run frontend API test and verify GREEN**

Run:

```powershell
cd E:\admin_go\admin_front_ts
npx vitest run tests/shared/system/upload-config-api.test.ts
```

Expected result:

```text
1 passed
```

- [ ] **Step 5: Commit Task 5**

Run:

```powershell
git -C E:\admin_go\admin_front_ts add src/api/system/uploadConfig.ts tests/shared/system/upload-config-api.test.ts
git -C E:\admin_go\admin_front_ts commit -m "refactor: make upload config api cos only"
```

---

### Task 6: Frontend upload driver page removes OSS branch and copy says COS-only

**Files:**
- Modify: `admin_front_ts/tests/shared/system/upload-config-copy.test.ts`
- Modify: `admin_front_ts/src/views/Main/system/uploadConfig/components/UploadDriver/index.vue`
- Modify: `admin_front_ts/src/i18n/locales/zh-CN.ts`
- Modify: `admin_front_ts/src/i18n/locales/en-US.ts`

- [ ] **Step 1: Strengthen upload config copy test**

Extend `tests/shared/system/upload-config-copy.test.ts` with this second test:

```ts
  it('does not render the removed OSS configuration branch', () => {
    const view = readFrontendSource('src/views/Main/system/uploadConfig/components/UploadDriver/index.vue')
    const api = readFrontendSource('src/api/system/uploadConfig.ts')

    expect(view).not.toContain("form.driver==='oss'")
    expect(view).not.toContain('role_arn')
    expect(api).toContain("export type UploadDriverType = 'cos'")
  })
```

Update the first test expected bucket-domain placeholder to the final copy:

```ts
expect(uploadCopy).toContain("bucket_domain_placeholder: '例如 cos.example.com，不要填写 https://，用于生成文件访问地址'")
```

- [ ] **Step 2: Run upload copy test and verify RED**

Run:

```powershell
cd E:\admin_go\admin_front_ts
npx vitest run tests/shared/system/upload-config-copy.test.ts
```

Expected result before implementation: failure because OSS branch and old placeholder still exist.

- [ ] **Step 3: Remove OSS validation from UploadDriver page**

In `admin_front_ts/src/views/Main/system/uploadConfig/components/UploadDriver/index.vue`, delete the rule branch that checks:

```ts
if (form.value.driver === 'oss' && !form.value.role_arn) callback(new Error(requiredMsg(t('upload.driver.form.role_arn'))))
```

Keep COS AppID validation:

```ts
if (form.value.driver === 'cos' && !form.value.appid) callback(new Error(requiredMsg(t('upload.driver.form.appid'))))
```

- [ ] **Step 4: Make driver type guard COS-only**

Replace `requireDriverType` with:

```ts
const requireDriverType = (value: UploadDriverFormState['driver']): UploadDriverType => {
  if (value !== 'cos') {
    throw new Error(t('upload.driver.form.cos_only'))
  }
  return value
}
```

- [ ] **Step 5: Default the add form to COS**

In the initial `form` state and `resetForm`, set:

```ts
driver: 'cos',
```

instead of an empty string. Keep edit mode using `row.driver` because backend now returns only COS.

- [ ] **Step 6: Remove OSS template branch**

Delete the template block:

```vue
<template v-else-if="form.driver==='oss'">
  ...
</template>
```

Keep the COS block and the common endpoint / bucket domain fields.

- [ ] **Step 7: Update Chinese copy**

In `admin_front_ts/src/i18n/locales/zh-CN.ts`, inside the upload driver form copy, set these keys:

```ts
cos_only: '当前仅支持腾讯云 COS',
bucket_domain_placeholder: '例如 cos.example.com，不要填写 https://，用于生成文件访问地址',
```

If `cos_only` does not exist, add it under the same `upload.driver.form` object.

- [ ] **Step 8: Update English copy**

In `admin_front_ts/src/i18n/locales/en-US.ts`, inside the upload driver form copy, set matching keys:

```ts
cos_only: 'Only Tencent COS is supported currently',
bucket_domain_placeholder: 'For example cos.example.com. Do not include https://. Used to build public file URLs',
```

- [ ] **Step 9: Run upload config frontend tests**

Run:

```powershell
cd E:\admin_go\admin_front_ts
npx vitest run tests/shared/system/upload-config-api.test.ts tests/shared/system/upload-config-copy.test.ts tests/shared/system/upload-client-url.test.ts
```

Expected result:

```text
3 passed
```

- [ ] **Step 10: Commit Task 6**

Run:

```powershell
git -C E:\admin_go\admin_front_ts add src/views/Main/system/uploadConfig/components/UploadDriver/index.vue src/i18n/locales/zh-CN.ts src/i18n/locales/en-US.ts tests/shared/system/upload-config-copy.test.ts
git -C E:\admin_go\admin_front_ts commit -m "refactor: remove oss upload config ui"
```

---

### Task 7: Public URL builders keep one contract across frontend and backend

**Files:**
- Modify: `admin_front_ts/tests/shared/system/upload-client-url.test.ts`
- Modify: `admin_front_ts/src/lib/upload/url.ts`
- Modify: `admin_back_go/internal/module/aiimage/service_test.go`
- Modify: `admin_back_go/internal/module/aiimage/service.go`
- Modify if needed: `admin_back_go/internal/module/exporttask/uploader_test.go`
- Modify if needed: `admin_back_go/internal/module/exporttask/uploader.go`

- [ ] **Step 1: Tighten frontend URL test around bare domain contract**

Keep the existing defensive legacy scheme test. Rename the no-scheme test to:

```ts
  it('builds HTTPS public URLs from the host-only COS bucket domain contract', () => {
    expect(buildPublicFileURL('cos.example.com', 'bucket', 'ap-nanjing', 'avatars/a.png')).toBe('https://cos.example.com/avatars/a.png')
    expect(buildPublicFileURL(null, 'bucket', 'ap-nanjing', 'avatars/a.png')).toBe('https://bucket.cos.ap-nanjing.myqcloud.com/avatars/a.png')
  })
```

- [ ] **Step 2: Run frontend URL test**

Run:

```powershell
cd E:\admin_go\admin_front_ts
npx vitest run tests/shared/system/upload-client-url.test.ts
```

Expected result: pass. If it fails, fix `src/lib/upload/url.ts` so no-scheme domains are prefixed with `https://`.

- [ ] **Step 3: Add backend AI image public URL test for bare domain**

In `admin_back_go/internal/module/aiimage/service_test.go`, ensure this test exists or update the existing equivalent:

```go
func TestPublicCOSURLNormalizesSchemeLessPublicDomain(t *testing.T) {
	got := publicCOSURL(cosRuntimeConfig{BucketDomain: "cos.example.com"}, "ai-images/out.png")
	if got != "https://cos.example.com/ai-images/out.png" {
		t.Fatalf("unexpected public COS URL: %s", got)
	}
}
```

- [ ] **Step 4: Run backend AI image test**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/aiimage -run TestPublicCOSURLNormalizesSchemeLessPublicDomain -count=1
```

Expected result: pass. If it fails, keep `publicURLJoin` behavior that prefixes `https://` for no-scheme hosts.

- [ ] **Step 5: Commit Task 7 if files changed**

If tests or URL builders changed, run:

```powershell
git -C E:\admin_go\admin_front_ts add tests/shared/system/upload-client-url.test.ts src/lib/upload/url.ts
git -C E:\admin_go\admin_front_ts commit -m "test: guard cos public url contract"

git -C E:\admin_go\admin_back_go add internal/module/aiimage/service.go internal/module/aiimage/service_test.go internal/module/exporttask/uploader.go internal/module/exporttask/uploader_test.go
git -C E:\admin_go\admin_back_go commit -m "test: guard server cos public url contract"
```

Skip a commit for a repo if `git diff --quiet` shows no changes in that repo.

---

### Task 8: Update docs to match COS-only runtime

**Files:**
- Modify: `docs/status/current-status.md`
- Modify: `docs/contracts/admin-api-v1.md`

- [ ] **Step 1: Update current status upload language**

In `docs/status/current-status.md`, update rows that mention upload runtime:

- `export tasks` remaining risk should say actual export e2e requires queue worker and enabled Tencent COS config.
- `profile / account security / avatar upload` should say avatar upload uses shared Go upload token client against Tencent COS only.
- `AI image playground gpt-image-2` should say reference/mask images use existing COS-only upload-token runtime.

Use wording like:

```text
upload runtime is Tencent COS-only; `bucket_domain` is stored as a bare host and runtime builds HTTPS public URLs
```

- [ ] **Step 2: Update API contract upload config section**

In `docs/contracts/admin-api-v1.md`, find the upload driver/config section and record:

```text
`driver` accepts only `cos`.
`bucket_domain` is an optional bare host such as `cos.example.com`; clients must not send `http://` or `https://`.
OSS is not an active runtime and is not selectable in V1.
```

- [ ] **Step 3: Run docs diff check**

Run:

```powershell
cd E:\admin_go
git diff --check -- docs/status/current-status.md docs/contracts/admin-api-v1.md
```

Expected result: no output.

- [ ] **Step 4: Commit Task 8**

Run:

```powershell
git -C E:\admin_go add docs/status/current-status.md docs/contracts/admin-api-v1.md
git -C E:\admin_go commit -m "docs: align upload contract to cos only"
```

Do not stage unrelated SMS docs unless they are intentionally part of this task.

---

### Task 9: Final focused verification

**Files:**
- No production edits in this task.

- [ ] **Step 1: Run backend focused tests**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/enum ./internal/module/uploadconfig ./internal/module/uploadtoken ./internal/module/exporttask ./internal/module/aiimage ./internal/platform/storage/cos -count=1
```

Expected result: all listed packages pass.

- [ ] **Step 2: Run frontend focused tests**

Run:

```powershell
cd E:\admin_go\admin_front_ts
npx vitest run tests/shared/system/upload-config-api.test.ts tests/shared/system/upload-config-copy.test.ts tests/shared/system/upload-client-url.test.ts
```

Expected result: all listed Vitest files pass.

- [ ] **Step 3: Run frontend typecheck**

Run:

```powershell
cd E:\admin_go\admin_front_ts
$env:NODE_OPTIONS='--max-old-space-size=2048'
npx vue-tsc -b --pretty false
```

Expected result: no TypeScript errors.

- [ ] **Step 4: Run repo diff checks**

Run:

```powershell
cd E:\admin_go
git diff --check
git -C admin_back_go diff --check
git -C admin_front_ts diff --check
```

Expected result: no output from any command.

- [ ] **Step 5: Capture final status**

Run:

```powershell
cd E:\admin_go
git status --short
git -C admin_back_go status --short
git -C admin_front_ts status --short
```

Expected result: only unrelated pre-existing workspace changes remain. If upload files are still modified, commit or intentionally report them.

---

## Rollback notes

If upload config convergence breaks runtime, rollback should be surgical:

```powershell
git -C E:\admin_go\admin_back_go revert <backend-upload-commit>
git -C E:\admin_go\admin_front_ts revert <frontend-upload-commit>
git -C E:\admin_go revert <docs-upload-commit>
```

For database cleanup, restore rows by setting the intended COS row active again:

```sql
UPDATE upload_driver SET is_del = 2 WHERE driver = 'cos' AND bucket = 'zgm-1314542588';
UPDATE upload_setting SET status = 1, is_del = 2 WHERE driver_id = 1;
```

Do not restore OSS as active unless a new spec explicitly adds OSS runtime.

## Handoff summary for implementer

The implementation is intentionally not a new upload platform. It deletes a fake provider choice and makes the current runtime honest:

```text
COS-only enum
COS-only upload config UI
bare bucket_domain config
shared HTTPS public URL builder
client upload token remains one-key scoped
server upload remains context-bound COS SDK work
OSS rows become inactive historical data
```
