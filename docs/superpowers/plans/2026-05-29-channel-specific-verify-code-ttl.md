# Channel-specific Verify Code TTL Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move verification-code TTL ownership from the global `system_settings.auth.verify_code.ttl_minutes` key to channel-specific mail and SMS configuration rows without changing public API field names or auth routes.

**Architecture:** Keep HTTP binding in `module/{capability}/transport/admin`, keep mail/sms business rules in their capability services, and let auth depend on a narrow `VerifyCodeTTLProvider` interface. Remove verify-code TTL from `shared/setting`; captcha/upload TTL remain system settings.

**Tech Stack:** Go 1.26, Gin, GORM, MySQL migration SQL, Redis code store, Vue 3 + TypeScript + vue-i18n, Vitest, PowerShell verification on Windows.

---

## Read first

- `E:\admin_go\AGENTS.md`
- `E:\admin_go\docs\status\current-status.md`
- `E:\admin_go\docs\status\module-matrix.md`
- `E:\admin_go\docs\architecture\00-platform-and-module-rules.md`
- `E:\admin_go\docs\architecture\04-go-backend-framework.md`
- `E:\admin_go\docs\architecture\05-development-quality-rules.md`
- `E:\admin_go\docs\superpowers\specs\2026-05-27-channel-specific-verify-code-ttl-design.md`

## Ownership

```text
Primary implementation role: backend-worker
Frontend copy/contract role: frontend-adapter if the worker is split
Review role: reviewer after tests pass
```

Do not implement this as architect. The architect output is this spec/plan.

## File map

### Backend schema and guards

- Create: `E:\admin_go\admin_back_go\database\migrations\20260529_channel_verify_code_ttl.sql`
- Modify: `E:\admin_go\admin_back_go\internal\architecture\shared_boundary_test.go`

### Backend mail capability

- Modify: `E:\admin_go\admin_back_go\internal\module\mail\model.go`
- Modify: `E:\admin_go\admin_back_go\internal\module\mail\repository.go`
- Modify: `E:\admin_go\admin_back_go\internal\module\mail\service.go`
- Modify: `E:\admin_go\admin_back_go\internal\module\mail\service_test.go`
- Modify: `E:\admin_go\admin_back_go\internal\module\mail\repository_test.go`
- Check: `E:\admin_go\admin_back_go\internal\module\mail\transport\admin\request.go`

### Backend SMS capability

- Modify: `E:\admin_go\admin_back_go\internal\module\sms\model.go`
- Modify: `E:\admin_go\admin_back_go\internal\module\sms\repository.go`
- Modify: `E:\admin_go\admin_back_go\internal\module\sms\service.go`
- Modify: `E:\admin_go\admin_back_go\internal\module\sms\service_test.go`
- Check: `E:\admin_go\admin_back_go\internal\module\sms\transport\admin\request.go`

### Backend auth/bootstrap/shared setting

- Modify: `E:\admin_go\admin_back_go\internal\module\auth\verify_code_policy.go`
- Modify: `E:\admin_go\admin_back_go\internal\module\auth\verify_code_policy_test.go`
- Modify: `E:\admin_go\admin_back_go\internal\module\auth\service.go`
- Modify: `E:\admin_go\admin_back_go\internal\module\auth\service_test.go`
- Modify: `E:\admin_go\admin_back_go\internal\bootstrap\app.go`
- Modify: `E:\admin_go\admin_back_go\internal\shared\setting\setting.go`
- Modify: `E:\admin_go\admin_back_go\internal\shared\setting\setting_test.go`

### Frontend and docs after runtime verification

- Modify: `E:\admin_go\admin_front_ts\src\i18n\locales\zh-CN.ts`
- Modify: `E:\admin_go\admin_front_ts\src\i18n\locales\en-US.ts`
- Modify: `E:\admin_go\admin_front_ts\tests\shared\system\mail-api.test.ts`
- Modify: `E:\admin_go\admin_front_ts\tests\shared\system\sms-api.test.ts`
- Modify after backend/frontend tests: `E:\admin_go\docs\contracts\admin-api-v1.md`
- Modify after backend/frontend tests: `E:\admin_go\docs\status\current-status.md` for key-fact summary and verification gap
- Modify after backend/frontend tests: `E:\admin_go\docs\status\module-matrix.md` for mail/sms per-module sections
- Modify after backend/frontend tests: `E:\admin_go\admin_back_go\docs\architecture.md`
- Modify after backend/frontend tests: `E:\admin_go\docs\testing\smoke-matrix.md`
- Modify after backend/frontend tests if still stale: `E:\admin_go\docs\deployment\production.md`

---

## Task 1: Add the failing architecture guard

**Files:**
- Modify: `E:\admin_go\admin_back_go\internal\architecture\shared_boundary_test.go`

- [x] **Step 1: Replace stale shared-setting expectations**

In `TestMigratedDictSettingCallSitesUseSharedBoundaries`, remove the checks that require:

```text
sharedsetting.AuthVerifyCodeTTLMinutes(ctx, p.repository)
sharedsetting.AuthVerifyCodeTTLMinutesOrDefault(ctx, repo)
sharedsetting.SaveAuthVerifyCodeTTLMinutes(ctx, repo, ttl)
```

- [x] **Step 2: Add a guard that rejects global verify-code TTL runtime usage**

Add a focused test such as `TestVerifyCodeTTLDoesNotUseSystemSettingRuntime` that scans these files:

```text
internal/module/auth/verify_code_policy.go
internal/module/mail/service.go
internal/module/mail/repository.go
internal/module/sms/service.go
internal/module/sms/repository.go
internal/shared/setting/setting.go
```

The guard must reject active runtime references to:

```text
AuthVerifyCodeTTLKey
AuthVerifyCodeTTLMinutes
AuthVerifyCodeTTLMinutesOrDefault
SaveAuthVerifyCodeTTLMinutes
SystemSettingVerifyCodePolicyProvider
"auth.verify_code.ttl_minutes"
```

Allow the migration SQL and docs to mention the old key.

- [x] **Step 3: Run the guard and verify it fails before implementation**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture -run TestVerifyCodeTTLDoesNotUseSystemSettingRuntime -count=1
```

Expected: FAIL because current auth/mail/sms/shared-setting code still uses the global key.

---

## Task 2: Add the channel TTL migration

**Files:**
- Create: `E:\admin_go\admin_back_go\database\migrations\20260529_channel_verify_code_ttl.sql`

- [x] **Step 1: Create an idempotent migration file**

Use the existing `information_schema` + prepared statement style from prior migrations. Capture whether each column already existed before the `ALTER`; that flag prevents reruns from overwriting a user's later channel TTL edits:

```sql
SET @schema_name := DATABASE();

SET @mail_ttl_column_exists := (
  SELECT EXISTS(
    SELECT 1
    FROM information_schema.COLUMNS
    WHERE table_schema = @schema_name
      AND table_name = 'mail_configs'
      AND column_name = 'verify_code_ttl_minutes'
  )
);

SET @add_mail_ttl := (
  SELECT IF(
    @mail_ttl_column_exists,
    'SELECT 1',
    'ALTER TABLE `mail_configs` ADD COLUMN `verify_code_ttl_minutes` INT UNSIGNED NOT NULL DEFAULT 5 AFTER `reply_to`'
  )
);
PREPARE stmt FROM @add_mail_ttl;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
```

Repeat for `sms_configs` after `endpoint`.

- [x] **Step 2: Backfill from the old global key**

Compute one safe integer variable:

```sql
SET @old_verify_code_ttl := (
  SELECT CASE
    WHEN `value_type` = 2
      AND `status` = 1
      AND `is_del` = 2
      AND TRIM(`setting_value`) REGEXP '^[0-9]+$'
      AND CAST(TRIM(`setting_value`) AS UNSIGNED) BETWEEN 1 AND 60
    THEN CAST(TRIM(`setting_value`) AS UNSIGNED)
    ELSE 5
  END
  FROM `system_settings`
  WHERE `setting_key` = 'auth.verify_code.ttl_minutes'
  ORDER BY `id`
  LIMIT 1
);

SET @old_verify_code_ttl := COALESCE(@old_verify_code_ttl, 5);
```

Then update active rows:

```sql
UPDATE `mail_configs`
SET `verify_code_ttl_minutes` = @old_verify_code_ttl,
    `updated_at` = CURRENT_TIMESTAMP
WHERE `is_del` = 2
  AND (
    @mail_ttl_column_exists = 0
    OR `verify_code_ttl_minutes` < 1
    OR `verify_code_ttl_minutes` > 60
  );
```

Do the same for `sms_configs`.

- [x] **Step 3: Disable and soft-delete the old global key**

```sql
UPDATE `system_settings`
SET `status` = 2,
    `is_del` = 1,
    `remark` = '验证码有效期已迁移到 mail_configs.verify_code_ttl_minutes 和 sms_configs.verify_code_ttl_minutes',
    `updated_at` = CURRENT_TIMESTAMP
WHERE `setting_key` = 'auth.verify_code.ttl_minutes';
```

- [x] **Step 4: Add a migration dry-run or text guard test if the project already has one for nearby migrations**

If no migration runner exists, at minimum add or update a lightweight repository/architecture test that asserts the migration file contains both new columns and the old-key retirement statement.

---

## Task 3: Move mail TTL to `mail_configs`

**Files:**
- Modify: `E:\admin_go\admin_back_go\internal\module\mail\model.go`
- Modify: `E:\admin_go\admin_back_go\internal\module\mail\repository.go`
- Modify: `E:\admin_go\admin_back_go\internal\module\mail\service.go`
- Modify: `E:\admin_go\admin_back_go\internal\module\mail\service_test.go`
- Modify: `E:\admin_go\admin_back_go\internal\module\mail\repository_test.go`

- [x] **Step 1: Write failing service tests**

Add/replace tests proving:

```text
SaveConfig stores VerifyCodeTTLMinutes on mail Config, not system_settings.
Config returns row.VerifyCodeTTLMinutes for configured mail.
Config returns default 5 when no mail config row exists.
VerifyCodeTTL returns row TTL as time.Duration.
VerifyCodeTTL returns default 5 minutes when no mail config row exists.
Invalid row TTL is rejected.
```

- [x] **Step 2: Run mail tests and verify failure**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/mail -count=1
```

Expected: FAIL because the model/repository/service still use shared system setting.

- [x] **Step 3: Add `VerifyCodeTTLMinutes` to `mail.Config`**

```go
VerifyCodeTTLMinutes int `gorm:"column:verify_code_ttl_minutes"`
```

Place it after `ReplyTo` to match the migration.

- [x] **Step 4: Remove system-setting methods from mail repository**

Remove from `Repository` and `GormRepository`:

```text
SettingByKey
SaveSetting
InvalidateSettingCache
```

Do not leave dead imports for `systemsetting`, `clause`, or Redis cache helpers if they are only used for that path.

- [x] **Step 5: Update `SaveConfig`**

Add local mail constants for default/min/max TTL minutes. Normalize 1-60 in the mail service, assign the value to `row.VerifyCodeTTLMinutes`, and save the config row once. Do not call `sharedsetting.SaveAuthVerifyCodeTTLMinutes`.

- [x] **Step 6: Update `Config` and `VerifyCodeTTL`**

`Config` should read from the row when present. Add:

```go
func (s *Service) VerifyCodeTTL(ctx context.Context) (time.Duration, *apperror.Error)
```

Return default 5 minutes when no config row exists.

- [x] **Step 7: Run mail tests**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/mail -count=1
```

Expected: PASS.

---

## Task 4: Move SMS TTL to `sms_configs`

**Files:**
- Modify: `E:\admin_go\admin_back_go\internal\module\sms\model.go`
- Modify: `E:\admin_go\admin_back_go\internal\module\sms\repository.go`
- Modify: `E:\admin_go\admin_back_go\internal\module\sms\service.go`
- Modify: `E:\admin_go\admin_back_go\internal\module\sms\service_test.go`

- [x] **Step 1: Write failing service tests**

Add/replace tests proving:

```text
SaveConfig stores VerifyCodeTTLMinutes on sms Config, not system_settings.
Config returns row.VerifyCodeTTLMinutes for configured SMS.
Config returns default 5 when no SMS config row exists.
VerifyCodeTTL returns row TTL as time.Duration.
VerifyCodeTTL returns default 5 minutes when no SMS config row exists.
TestSend fills ttl_minutes from sms config TTL.
Invalid row TTL is rejected.
```

- [x] **Step 2: Run SMS tests and verify failure**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/sms -count=1
```

Expected: FAIL because the service still reads/writes shared system setting.

- [x] **Step 3: Add `VerifyCodeTTLMinutes` to `sms.Config`**

```go
VerifyCodeTTLMinutes int `gorm:"column:verify_code_ttl_minutes"`
```

Place it after `Endpoint` to match the migration.

- [x] **Step 4: Remove system-setting methods from SMS repository**

Remove `SettingByKey`, `SaveSetting`, and `InvalidateSettingCache` from `Repository` and `GormRepository`.

- [x] **Step 5: Update `SaveConfig`, `Config`, `VerifyCodeTTL`, and `TestSend`**

Add local SMS constants for default/min/max TTL minutes. Use `sms_configs.verify_code_ttl_minutes` as the only SMS TTL source. `TestSend` must use that value for template variable `ttl_minutes`.

- [x] **Step 6: Run SMS tests**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/sms -count=1
```

Expected: PASS.

---

## Task 5: Replace auth global policy with channel policy

**Files:**
- Modify: `E:\admin_go\admin_back_go\internal\module\auth\verify_code_policy.go`
- Modify: `E:\admin_go\admin_back_go\internal\module\auth\verify_code_policy_test.go`
- Modify: `E:\admin_go\admin_back_go\internal\module\auth\service.go`
- Modify: `E:\admin_go\admin_back_go\internal\module\auth\service_test.go`
- Modify: `E:\admin_go\admin_back_go\internal\bootstrap\app.go`

- [x] **Step 1: Write failing auth policy tests**

Tests must prove:

```text
email account type uses email provider TTL.
phone account type uses phone provider TTL.
unknown account type is rejected.
provider error is propagated.
missing email or phone provider fails clearly with an internal configuration error.
```

- [x] **Step 2: Write failing SendCode TTL tests**

Use fake code store and fake policy provider. Prove:

```text
email SendCode stores Redis code with email TTL.
phone SendCode stores Redis code with phone TTL and still uses fixed 123456.
```

- [x] **Step 3: Run auth tests and verify failure**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/auth -run "Test.*VerifyCode|Test.*SendCode" -count=1
```

Expected: FAIL because the policy interface is still no-arg.

- [x] **Step 4: Change the auth policy interface**

Target shape:

```go
type VerifyCodePolicyProvider interface {
    VerifyCodeTTL(ctx context.Context, accountType string) (time.Duration, *apperror.Error)
}

type VerifyCodeTTLProvider interface {
    VerifyCodeTTL(ctx context.Context) (time.Duration, *apperror.Error)
}
```

Add `ChannelVerifyCodePolicyProvider` with email and phone providers.

- [x] **Step 5: Update `SendCode`**

After `accountType := accountTypeOf(input.Account)`, call:

```go
ttl, appErr := s.verifyCodeTTL(ctx, accountType)
```

Do not change the Redis key namespace or success message.

- [x] **Step 6: Remove system-setting provider**

Delete `SystemSettingVerifyCodePolicyProvider` and the `sharedsetting.Reader` dependency from auth verify-code policy code.

- [x] **Step 7: Update bootstrap wiring**

In `internal/bootstrap/app.go`, replace:

```go
auth.NewSystemSettingVerifyCodePolicyProvider(systemSettingRepository)
```

with:

```go
auth.NewChannelVerifyCodePolicyProvider(mailService, smsService)
```

- [x] **Step 8: Run auth/bootstrap tests**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/auth ./internal/bootstrap -count=1
```

Expected: PASS.

---

## Task 6: Remove verify-code TTL from `shared/setting`

**Files:**
- Modify: `E:\admin_go\admin_back_go\internal\shared\setting\setting.go`
- Modify: `E:\admin_go\admin_back_go\internal\shared\setting\setting_test.go`
- Modify: `E:\admin_go\admin_back_go\internal\architecture\shared_boundary_test.go`

- [x] **Step 1: Remove stale exported API**

Remove these from `shared/setting`:

```text
AuthVerifyCodeTTLKey
DefaultAuthVerifyCodeTTLMinutes
AuthVerifyCodeTTLMinutes
AuthVerifyCodeTTLMinutesOrDefault
SaveAuthVerifyCodeTTLMinutes
NormalizeAuthVerifyCodeTTLMinutes
```

Keep captcha and upload-token setting APIs.

- [x] **Step 2: Remove stale shared-setting tests**

Delete tests that only prove the old global verify-code TTL behavior.

- [x] **Step 3: Re-run shared and architecture tests**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/shared/setting ./internal/architecture -count=1
```

Expected: PASS. The new guard must also pass.

---

## Task 7: Update frontend channel-specific copy and contract tests

**Files:**
- Modify: `E:\admin_go\admin_front_ts\src\i18n\locales\zh-CN.ts`
- Modify: `E:\admin_go\admin_front_ts\src\i18n\locales\en-US.ts`
- Modify: `E:\admin_go\admin_front_ts\tests\shared\system\mail-api.test.ts`
- Modify: `E:\admin_go\admin_front_ts\tests\shared\system\sms-api.test.ts`

- [x] **Step 1: Write or update tests that reject shared wording**

Mail test should reject Chinese/English shared wording for mail config. SMS test should reject it for SMS config.

- [x] **Step 2: Update zh-CN copy**

Use channel-specific text:

```text
邮件验证码有效期；模板变量 ttl_minutes 自动取这个值。
短信验证码有效期；模板变量 ttl_minutes 自动取这个值。
```

- [x] **Step 3: Update en-US copy**

Use channel-specific text, for example:

```text
Email verification-code TTL. The ttl_minutes template variable uses this value.
SMS verification-code TTL. The ttl_minutes template variable uses this value.
```

- [x] **Step 4: Run frontend focused tests**

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/system/mail-api.test.ts tests/shared/system/sms-api.test.ts
npx vue-tsc -b --pretty false
```

Expected: PASS.

---

## Task 8: Update contracts and runtime docs after tests pass

**Files:**
- Modify: `E:\admin_go\docs\contracts\admin-api-v1.md`
- Modify: `E:\admin_go\docs\status\current-status.md` for key-fact summary and verification gap
- Modify: `E:\admin_go\docs\status\module-matrix.md` for mail/sms per-module sections
- Modify: `E:\admin_go\admin_back_go\docs\architecture.md`
- Modify: `E:\admin_go\docs\testing\smoke-matrix.md`
- Modify if stale: `E:\admin_go\docs\deployment\production.md`

- [x] **Step 1: Update admin API contract**

Change mail/sms config sections so they say:

```text
PUT /mail/config saves verify_code_ttl_minutes to mail_configs.verify_code_ttl_minutes.
PUT /sms/config saves verify_code_ttl_minutes to sms_configs.verify_code_ttl_minutes.
```

Keep request/response field names unchanged.

- [x] **Step 2: Update status docs only with verified facts**

Only after backend and frontend tests pass, update `current-status.md` with the key TTL fact and any verification gap, and update `module-matrix.md` mail/sms sections to say channel-specific TTL is implemented.

- [x] **Step 3: Update smoke/deployment wording**

Remove stale statements that say `auth.verify_code.ttl_minutes` is the runtime TTL source.

- [x] **Step 4: Search for stale shared wording**

```powershell
cd E:\admin_go
rg -n "邮件和短信共用|Shared by email and SMS|auth\.verify_code\.ttl_minutes|system_settings\.auth\.verify_code\.ttl_minutes" docs admin_back_go admin_front_ts
```

Expected: Remaining hits are only migration history, this spec/plan, or explicitly historical text.

---

## Task 9: Full backend verification

**Files:**
- No code edits unless tests expose real failures.

- [x] **Step 1: Run focused backend tests**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture -count=1
go test ./internal/module/mail ./internal/module/sms ./internal/module/auth ./internal/bootstrap ./internal/server -count=1
```

Expected: PASS.

- [x] **Step 2: Run full backend tests and build**

```powershell
cd E:\admin_go\admin_back_go
go test ./... -count=1
go build ./...
```

Expected: PASS.

- [x] **Step 3: If a live DB is available, verify schema and old key state**

Use the project’s current DB connection, then verify:

```sql
SHOW COLUMNS FROM mail_configs LIKE 'verify_code_ttl_minutes';
SHOW COLUMNS FROM sms_configs LIKE 'verify_code_ttl_minutes';
SELECT setting_key, status, is_del FROM system_settings WHERE setting_key = 'auth.verify_code.ttl_minutes';
```

Expected: both columns exist; old key is not active.

---

## Task 10: Root governance verification

**Files:**
- No edits unless checks expose real drift.

- [x] **Step 1: Run root whitespace check**

```powershell
cd E:\admin_go
git diff --check
```

Expected: no output and exit code 0.

- [x] **Step 2: Run root governance checker**

```powershell
cd E:\admin_go
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected: no blocking governance violations.

- [x] **Step 3: Summarize evidence**

Final report must separate:

```text
implemented runtime evidence
frontend evidence
docs/governance evidence
known smoke or live DB gaps
```

Do not say “fully complete” if live DB migration or smoke was not run.
---

## Execution record - 2026-05-29

Plan execution landed in the current Go/Vue runtime with the architecture adjusted for `module/{capability}/transport/{platform}` + `shared` + `infra`:

- `auth` depends on a narrow channel TTL interface and is wired with `mailService` / `smsService` in bootstrap.
- `mail_configs.verify_code_ttl_minutes` owns email verification-code TTL.
- `sms_configs.verify_code_ttl_minutes` owns SMS verification-code TTL.
- `shared/setting` no longer exposes verify-code TTL runtime APIs; captcha/upload TTL settings remain there.
- `system_settings.auth.verify_code.ttl_minutes` is retired by migration, not used as runtime policy.
- Frontend mail/sms copy is channel-specific and contract tests reject the old shared wording.
- Active docs/contracts/status/smoke/deployment wording was synced.

Fresh verification in this execution pass:

```powershell
cd E:\admin_go\admin_back_go
go vet ./...
go test ./... -count=1
go build ./...
go test -race ./internal/module/mail ./internal/module/sms ./internal/module/auth ./internal/bootstrap ./internal/server -count=1

cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/system/mail-api.test.ts tests/shared/system/sms-api.test.ts
npx vue-tsc -b --pretty false

cd E:\admin_go
git diff --check
git -C admin_back_go diff --check
git -C admin_front_ts diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Live DB verification after applying `admin_back_go/database/migrations/20260529_channel_verify_code_ttl.sql`:

```text
mail_configs.verify_code_ttl_minutes exists, default 5
sms_configs.verify_code_ttl_minutes exists, default 5
system_settings.auth.verify_code.ttl_minutes => status=2, is_del=1
```

Smoke record:

- `basic-admin-smoke.ps1 -Account 15671628271 -Password 123456` passed.
- `full-admin-smoke.ps1` reached mail/sms read probes with HTTP 200, then stopped at the pre-existing upload-token runtime config failure: `code=500, msg="上传密钥不可用"`. This is recorded as a full-smoke gap, not as a TTL implementation failure.
