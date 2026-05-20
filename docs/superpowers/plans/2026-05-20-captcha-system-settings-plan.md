# Captcha System Settings Migration and Prefix Inlining Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` or `superpowers:executing-plans` to implement this plan task-by-task.

**Goal:** Move CAPTCHA tunables out of env into `system_settings`, keep the Redis prefix as a code constant, and keep login/captcha smoke working.

**Architecture:** The captcha module will read `auth.captcha.ttl_minutes` and `auth.captcha.slide_padding` through a small DB-backed policy boundary, while the Redis namespace stays a private code constant. Existing `/api/admin/v1/system-settings` CRUD remains the operator UI; no new captcha page is introduced in this slice.

**Tech Stack:** Go 1.26, Gin, GORM, system_settings table, existing admin system settings page, PowerShell smoke scripts, Go tests.

---

### Task 1: Add captcha policy boundary and wire it into bootstrap

**Files:**
- Create: `admin_back_go/internal/module/captcha/policy.go`
- Create: `admin_back_go/internal/module/captcha/policy_test.go`
- Modify: `admin_back_go/internal/bootstrap/app.go`
- Modify: `admin_back_go/internal/module/captcha/service.go`
- Modify: `admin_back_go/internal/module/captcha/service_test.go`

- [ ] **Step 1: Write the failing test**

```go
func TestSystemSettingCaptchaPolicyProviderReadsTTLAndPadding(t *testing.T) {
    // row with key auth.captcha.ttl_minutes returns duration in minutes
    // row with key auth.captcha.slide_padding returns integer padding
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `go test ./internal/module/captcha -run TestSystemSettingCaptchaPolicyProviderReadsTTLAndPadding -v`
Expected: FAIL because `policy.go` does not exist yet.

- [ ] **Step 3: Write minimal implementation**

```go
const (
    CaptchaTTLSettingKey = "auth.captcha.ttl_minutes"
    CaptchaSlidePaddingSettingKey = "auth.captcha.slide_padding"
    defaultCaptchaRedisPrefix = "captcha:slide:"
)

type Policy interface {
    TTL(ctx context.Context) (time.Duration, *apperror.Error)
    SlidePadding(ctx context.Context) (int, *apperror.Error)
}
```

`bootstrap/app.go` should construct the captcha service with a DB-backed policy and a Redis store using the inline prefix constant, not env.

- [ ] **Step 4: Run test to verify it passes**

Run: `go test ./internal/module/captcha ./internal/bootstrap -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add admin_back_go/internal/module/captcha/policy.go admin_back_go/internal/module/captcha/policy_test.go admin_back_go/internal/module/captcha/service.go admin_back_go/internal/module/captcha/service_test.go admin_back_go/internal/bootstrap/app.go
git commit -m "feat: read captcha policy from system settings"
```

### Task 2: Move captcha keys into system_settings seed and keep env short

**Files:**
- Create: `admin_back_go/database/migrations/20260520_captcha_policy.sql`
- Modify: `admin_back_go/deploy/docker-first/admin-go.env`
- Modify: `admin_back_go/deploy/docker-first/admin-go.env.example`
- Modify: `admin_back_go/README.md`
- Modify: `admin_back_go/docs/architecture.md`
- Modify: `docs/deployment/docker-first-backend.md`
- Modify: `docs/deployment/local.md`
- Modify: `docs/deployment/production.md`
- Modify: `admin_back_go/internal/config/config.go`
- Modify: `admin_back_go/internal/config/config_test.go`

- [ ] **Step 1: Write the failing test**

```go
func TestLoadDoesNotExposeCaptchaEnvAsRuntimeDependency(t *testing.T) {
    // assert captcha prefix is no longer part of config
    // assert cfg has no Captcha.RedisPrefix field usage in the new wiring
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `go test ./internal/config -run TestLoadDoesNotExposeCaptchaEnvAsRuntimeDependency -v`
Expected: FAIL until config and tests are updated.

- [ ] **Step 3: Write minimal implementation**

```sql
INSERT INTO `system_settings` (`setting_key`, `setting_value`, `value_type`, `remark`, `status`, `is_del`)
VALUES
  ('auth.captcha.ttl_minutes', '2', 2, '验证码有效期分钟数', 1, 2),
  ('auth.captcha.slide_padding', '10', 2, '滑块容差像素', 1, 2)
ON DUPLICATE KEY UPDATE
  `setting_value` = CASE
    WHEN `setting_value` IS NULL OR TRIM(`setting_value`) = '' THEN VALUES(`setting_value`)
    ELSE `setting_value`
  END,
  `value_type` = 2,
  `remark` = VALUES(`remark`),
  `status` = 1,
  `is_del` = 2,
  `updated_at` = CURRENT_TIMESTAMP;
```

`config.go` should remove captcha env fields from `CaptchaConfig` and leave only non-business runtime config in `.env`.

- [ ] **Step 4: Run test to verify it passes**

Run: `go test ./internal/config ./internal/bootstrap -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add admin_back_go/database/migrations/20260520_captcha_policy.sql admin_back_go/internal/config/config.go admin_back_go/internal/config/config_test.go admin_back_go/deploy/docker-first/admin-go.env admin_back_go/deploy/docker-first/admin-go.env.example admin_back_go/README.md admin_back_go/docs/architecture.md docs/deployment/docker-first-backend.md docs/deployment/local.md docs/deployment/production.md
git commit -m "feat: move captcha policy into system settings"
```

### Task 3: Update smoke scripts to use the inline captcha prefix

**Files:**
- Modify: `admin_back_go/scripts/basic-admin-smoke.ps1`
- Modify: `admin_back_go/scripts/full-admin-smoke.ps1`

- [ ] **Step 1: Write the failing test**

```powershell
# verify the scripts no longer require CAPTCHA_REDIS_PREFIX from env
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Select-String -Path .\admin_back_go\scripts\*.ps1 -Pattern 'CAPTCHA_REDIS_PREFIX'`
Expected: hits only before the edit.

- [ ] **Step 3: Write minimal implementation**

Replace the env read with:

```powershell
$prefix = 'captcha:slide:'
```

- [ ] **Step 4: Run test to verify it passes**

Run: `Select-String -Path .\admin_back_go\scripts\*.ps1 -Pattern 'CAPTCHA_REDIS_PREFIX'`
Expected: no hits in the smoke scripts.

- [ ] **Step 5: Commit**

```bash
git add admin_back_go/scripts/basic-admin-smoke.ps1 admin_back_go/scripts/full-admin-smoke.ps1
git commit -m "chore: inline captcha redis prefix in smoke scripts"
```

### Task 4: Update docs and frontend-facing setting copy

**Files:**
- Modify: `admin_front_ts/src/views/Main/system/setting/index.vue`
- Modify: `admin_front_ts/src/api/system/setting.ts` if needed for helper copy only
- Modify: `docs/superpowers/specs/2026-05-20-captcha-system-settings-design.md` if the implementation changes
- Modify: `docs/superpowers/plans/2026-05-20-captcha-system-settings-plan.md` if scope needs tightening

- [ ] **Step 1: Write the failing test**

```ts
// add or adjust the existing system setting UI test to assert the captcha keys are visible/usable
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm test -- tests/shared/system/setting-*` or the closest existing targeted test for the page
Expected: FAIL before the UI text and seed rows are updated.

- [ ] **Step 3: Write minimal implementation**

Add tiny helper copy in the existing system settings page so operators can find:

```text
auth.captcha.ttl_minutes
auth.captcha.slide_padding
```

without building a separate captcha page.

- [ ] **Step 4: Run test to verify it passes**

Run: focused frontend test / typecheck used by this repo slice.
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add admin_front_ts/src/views/Main/system/setting/index.vue admin_front_ts/src/api/system/setting.ts docs/superpowers/specs/2026-05-20-captcha-system-settings-design.md docs/superpowers/plans/2026-05-20-captcha-system-settings-plan.md
git commit -m "docs: align captcha settings operator copy"
```

### Task 5: Verify runtime and governance

**Files:**
- No new files; verify the whole slice.

- [ ] **Step 1: Run the focused Go tests**

Run: `go test ./internal/module/captcha ./internal/bootstrap ./internal/config -v`

- [ ] **Step 2: Run repo-wide Go tests if the focused set is green**

Run: `go test ./...`

- [ ] **Step 3: Run governance checks**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
git diff --check
```

- [ ] **Step 4: Run runtime smoke**

Run the backend smoke path that exercises captcha and password login.

- [ ] **Step 5: Final commit**

Commit once the runtime checks are green.

---

**Coverage check**

- `CAPTCHA_TTL` moved: Task 1 + Task 2
- `CAPTCHA_SLIDE_PADDING` moved: Task 1 + Task 2
- Redis prefix inlined: Task 1 + Task 3
- env shortened: Task 2
- use existing system settings page: Task 4
- login/captcha smoke preserved: Task 5
