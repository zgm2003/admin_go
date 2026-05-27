# Plan 03: Consolidate Auth-Adjacent Modules into `auth`

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Merge `captcha`, `session`, `usersession`, and `userloginlog` modules into `module/auth` as local files (`captcha.go`, `session.go`, `loginlog.go`), removing the four standalone packages. This completes spec §12.1 first-knife scope.

**Source spec:** `docs/superpowers/specs/2026-05-27-multi-platform-backend-boundary-design.md` §12.1 (consolidation portion) + §9 (module aggregation table).

**Prerequisite:** `plan-02-auth-transport.md` **must be merged** before this plan starts. plan-03 modifies files plan-02 creates (`auth/transport/{admin,app}/handler.go` import paths) and the new auth package layout.

**Tech Stack:** Go, PowerShell, `go test`, `rg`, `git diff --check`.

---

## Scope Check

This plan executes:

```text
1. internal/module/captcha       → internal/module/auth/captcha.go (merged)
2. internal/module/session       → internal/module/auth/session.go (merged)
3. internal/module/usersession   → internal/module/auth/session.go (merged with above)
4. internal/module/userloginlog  → internal/module/auth/loginlog.go (merged)
5. All importers of the four deleted modules are rewritten.
6. Static architecture guard extended to assert the four deleted modules stay deleted.
```

This plan does **not**:
- Touch governance docs (plan-01 owns them).
- Touch frontend (plan-04 owns it).
- Rename `internal/platform` → `internal/infra` (a later plan).
- Touch shared/dict, AI aggregation, profile split (later plans).

**Parallel siblings:** none — this plan is fully sequential after plan-02.
**Blocks:** future spec §12.2-12.5 plans.

---

## Current importers (verified 2026-05-27)

```text
internal/module/captcha imported by:
  internal/module/auth/service.go               (captcha.Answer, captcha.VerifyInput)
  internal/module/auth/transport/admin/*        (after plan-02)
  internal/module/auth/transport/app/*          (after plan-02)
  internal/server/router.go                     (captcha.RegisterRoutes, captcha.HTTPService)
  internal/bootstrap/* (verify with rg)

internal/module/session imported by:
  internal/module/auth/service.go               (session.CreateInput, session.TokenResult, session.RefreshInput)
  internal/module/auth/dto.go                   (RefreshResponse = session.TokenResult)
  internal/module/auth/transport/admin/*        (after plan-02)
  internal/module/auth/transport/app/*          (after plan-02)
  internal/module/usersession/service.go        (cross-module dependency)
  internal/module/authplatform/service.go       (verify)
  internal/bootstrap/* (verify with rg)

internal/module/usersession imported by:
  internal/server/router.go                     (usersession.RegisterRoutes, usersession.HTTPService)
  internal/bootstrap/* (verify with rg)

internal/module/userloginlog imported by:
  internal/server/router.go                     (userloginlog.RegisterRoutes, userloginlog.HTTPService)
  internal/bootstrap/* (verify with rg)
```

Task 1 confirms the importer map before code moves.

---

## File Structure

Create in `internal/module/auth/`:

- Create: `admin_back_go/internal/module/auth/captcha.go` (merged from `module/captcha/*.go` non-test files)
- Create: `admin_back_go/internal/module/auth/captcha_test.go` (merged from `module/captcha/*_test.go`)
- Create: `admin_back_go/internal/module/auth/session.go` (merged from `module/session/*.go` + `module/usersession/*.go` non-test files)
- Create: `admin_back_go/internal/module/auth/session_test.go` (merged from `module/{session,usersession}/*_test.go`)
- Create: `admin_back_go/internal/module/auth/loginlog.go` (merged from `module/userloginlog/*.go` non-test files)
- Create: `admin_back_go/internal/module/auth/loginlog_test.go` (merged from `module/userloginlog/*_test.go`)

Modify in `internal/module/auth/`:

- Modify: `admin_back_go/internal/module/auth/service.go` (remove `import captcha` / `import session`, rename type references to local)
- Modify: `admin_back_go/internal/module/auth/dto.go` (remove `import session`, rewrite `RefreshResponse = session.TokenResult` to local type)
- Modify: `admin_back_go/internal/module/auth/transport/admin/handler.go` (remove imports of captcha/session, use authmodule.X)
- Modify: `admin_back_go/internal/module/auth/transport/app/handler.go` (same)
- Modify: `admin_back_go/internal/module/auth/transport/admin/handler_test.go` (same)
- Modify: `admin_back_go/internal/module/auth/transport/app/handler_test.go` (same)

Modify outside auth:

- Modify: `admin_back_go/internal/server/router.go` (remove the four Register calls; consider if any need to be re-exposed from auth)
- Modify: `admin_back_go/internal/server/router_test.go`
- Modify: `admin_back_go/internal/bootstrap/app.go` (remove imports/wiring)
- Modify: `admin_back_go/internal/bootstrap/authenticator.go` (if it imports session)
- Modify: `admin_back_go/internal/module/authplatform/service.go` (if it imports session)

Delete directories:

- Delete: `admin_back_go/internal/module/captcha/`
- Delete: `admin_back_go/internal/module/session/`
- Delete: `admin_back_go/internal/module/usersession/`
- Delete: `admin_back_go/internal/module/userloginlog/`

Extend architecture guard:

- Modify: `admin_back_go/internal/architecture/multiplatform_boundary_test.go`

---

## Task 0: Pre-flight verification

**Files:**

- Validate only.

- [ ] **Step 1: Confirm plan-02 is merged**

```powershell
cd E:\admin_go\admin_back_go
Test-Path .\internal\module\auth\transport\admin\route.go
Test-Path .\internal\module\auth\transport\app\route.go
Test-Path .\internal\module\auth\route.go
Test-Path .\internal\module\auth\platform_route.go
```

Expected: first two `True`, last two `False`. If not, **stop** — plan-02 has not completed.

- [ ] **Step 2: Enumerate importers of the four target modules**

```powershell
cd E:\admin_go\admin_back_go
rg -n "admin_back_go/internal/module/captcha" internal cmd
rg -n "admin_back_go/internal/module/session" internal cmd
rg -n "admin_back_go/internal/module/usersession" internal cmd
rg -n "admin_back_go/internal/module/userloginlog" internal cmd
```

Save the output. Every file listed will need to be updated in Task 4. If the list deviates significantly from the "Current importers" section above, **update the plan first** before continuing.

- [ ] **Step 3: Baseline tests pass**

```powershell
cd E:\admin_go\admin_back_go
go test ./... -count=1
```

Expected: PASS. Establishes the regression baseline.

---

## Task 1: Extend architecture guard (RED)

**Files:**

- Modify: `admin_back_go/internal/architecture/multiplatform_boundary_test.go`

- [ ] **Step 1: Add `TestAuthAdjacentModulesAreMerged`**

Append to the existing architecture test file:

```go
func TestAuthAdjacentModulesAreMerged(t *testing.T) {
	root := backendRoot(t)
	// these standalone packages must no longer exist
	for _, rel := range []string{
		"internal/module/captcha",
		"internal/module/session",
		"internal/module/usersession",
		"internal/module/userloginlog",
	} {
		if info, err := os.Stat(filepath.Join(root, rel)); err == nil && info.IsDir() {
			t.Fatalf("expected %s to be removed (merged into auth)", rel)
		}
	}
	// these merged files must exist in auth
	for _, rel := range []string{
		"internal/module/auth/captcha.go",
		"internal/module/auth/session.go",
		"internal/module/auth/loginlog.go",
	} {
		if _, err := os.Stat(filepath.Join(root, rel)); err != nil {
			t.Fatalf("expected %s to exist: %v", rel, err)
		}
	}
}

func TestNoImportsOfDeletedAuthAdjacentModules(t *testing.T) {
	root := backendRoot(t)
	banned := []string{
		"admin_back_go/internal/module/captcha",
		"admin_back_go/internal/module/session",
		"admin_back_go/internal/module/usersession",
		"admin_back_go/internal/module/userloginlog",
	}
	var offenders []string
	err := filepath.WalkDir(filepath.Join(root, "internal"), func(path string, entry os.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if entry.IsDir() || filepath.Ext(path) != ".go" {
			return nil
		}
		body, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		text := string(body)
		for _, mod := range banned {
			if strings.Contains(text, mod) {
				rel, _ := filepath.Rel(root, path)
				offenders = append(offenders, filepath.ToSlash(rel)+" imports "+mod)
			}
		}
		return nil
	})
	if err != nil {
		t.Fatalf("walk internal go files: %v", err)
	}
	if len(offenders) > 0 {
		t.Fatalf("banned auth-adjacent imports remain:\n  %s", strings.Join(offenders, "\n  "))
	}
}
```

- [ ] **Step 2: Run RED**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture -run 'TestAuthAdjacentModulesAreMerged|TestNoImportsOfDeletedAuthAdjacentModules' -count=1
```

Expected: FAIL — `internal/module/captcha` etc. still exist and are imported.

---

## Task 2: Merge `captcha` into `auth/captcha.go`

**Files:**

- Create: `admin_back_go/internal/module/auth/captcha.go`
- Create: `admin_back_go/internal/module/auth/captcha_test.go`
- Delete: `admin_back_go/internal/module/captcha/` (entire directory)

- [ ] **Step 1: Inventory `module/captcha/`**

```powershell
cd E:\admin_go\admin_back_go
Get-ChildItem .\internal\module\captcha -File
```

List each `.go` file. Typical contents:
- `service.go` — captcha generation, verification logic
- `repository.go` (if any)
- `model.go` (if any)
- `route.go` / `handler.go` — captcha HTTP endpoint (`/api/admin/v1/captcha/*` or similar)
- `dto.go` — `Answer`, `VerifyInput`, `ChallengeResponse` types

- [ ] **Step 2: Decide route disposition**

The captcha HTTP endpoint is **part of the auth flow** per spec §9 ("滑块验证码归属认证副产品"). The route moves to:

- Admin captcha challenge generation → `auth/transport/admin/handler.go` (new method `Captcha`) + `auth/transport/admin/route.go` (new GET `/captcha` line)
- App captcha challenge generation already exists in `auth/transport/app/handler.go`

If the existing captcha routes have different prefix (e.g., `/api/admin/v1/captcha` vs the auth-prefix), preserve URL stability by mapping under `/api/admin/v1/auth/captcha` and update the frontend grep list in plan-04.

- [ ] **Step 3: Merge non-test files into `auth/captcha.go`**

Create `internal/module/auth/captcha.go`:
- Package: `package auth`
- Copy all top-level types/funcs from `module/captcha/*.go` non-test files
- Rename exported symbols that collide with existing `auth` symbols (e.g., if `auth` already has `Service`, rename captcha's `Service` to `captchaService` or keep as struct with `Captcha` prefix). Common case: `captcha.Service` → `CaptchaService` (auth-local).
- Strip the standalone HTTP handler/route code (it moves to transport per Step 2)

Key types to surface as `auth` package exports:
- `Answer` (used by auth/service.go LoginInput)
- `VerifyInput`
- `ChallengeResponse`

- [ ] **Step 4: Merge tests into `auth/captcha_test.go`**

Migrate `module/captcha/*_test.go` files:
- Package: `package auth`
- Rename test functions if they collide with existing auth tests (prefix with `TestCaptcha_`)

- [ ] **Step 5: Update consumers of `module/captcha`**

For each file in Task 0 Step 2 importer list, replace:

```text
import "admin_back_go/internal/module/captcha"   → remove
captcha.Answer                                   → Answer (when caller is in auth package) or auth.Answer (when caller is in another package)
captcha.VerifyInput                              → VerifyInput / auth.VerifyInput
captcha.ChallengeResponse                        → ChallengeResponse / auth.ChallengeResponse
captcha.HTTPService                              → auth.CaptchaHTTPService (the auth-exposed captcha HTTP surface)
```

Affected files (verify with Task 0 Step 2):
- `internal/module/auth/service.go`
- `internal/module/auth/dto.go`
- `internal/module/auth/transport/admin/handler.go`
- `internal/module/auth/transport/app/handler.go`
- `internal/module/auth/transport/admin/handler_test.go`
- `internal/module/auth/transport/app/handler_test.go`
- `internal/server/router.go` — remove `captcha.RegisterRoutes(...)` call (captcha endpoints now mounted via `authadmin.Register` / `authapp.Register`)
- `internal/server/router.go` Dependencies struct — remove `CaptchaService captcha.HTTPService` field; the captcha service is constructed inside auth wiring
- `internal/bootstrap/*` — adjust dependency wiring

- [ ] **Step 6: Delete captcha module directory**

```powershell
cd E:\admin_go\admin_back_go
Remove-Item -LiteralPath .\internal\module\captcha -Recurse -Force
```

- [ ] **Step 7: Compile**

```powershell
cd E:\admin_go\admin_back_go
go build ./...
go test ./internal/module/auth ./internal/module/auth/transport/admin ./internal/module/auth/transport/app ./internal/server -count=1
```

Expected: PASS.

---

## Task 3: Merge `session` + `usersession` into `auth/session.go`

**Files:**

- Create: `admin_back_go/internal/module/auth/session.go`
- Create: `admin_back_go/internal/module/auth/session_test.go`
- Delete: `admin_back_go/internal/module/session/`
- Delete: `admin_back_go/internal/module/usersession/`

- [ ] **Step 1: Inventory both modules**

```powershell
cd E:\admin_go\admin_back_go
Get-ChildItem .\internal\module\session -File
Get-ChildItem .\internal\module\usersession -File
```

`module/session/` provides token/session primitives consumed by auth (`session.CreateInput`, `session.TokenResult`, `session.RefreshInput`).
`module/usersession/` is the admin-facing CRUD for user_sessions table (list / kick / refresh).

These are two layers of the same concern: lower-level session primitives + admin management surface. Both belong inside `auth` per spec §9.

- [ ] **Step 2: Merge primitives into `auth/session.go`**

Create `internal/module/auth/session.go`:
- Package: `package auth`
- Copy from `module/session/`: `Service`, `Manager`, `Store`, `CreateInput`, `TokenResult`, `RefreshInput`, related types
- Rename to avoid collision with existing auth symbols: `session.Service` → `SessionStore` or `SessionManager` (pick one consistent name; auth.go already has `SessionService` for the auth-facing API)
- Copy from `module/usersession/`: management/listing types (e.g., `ListInput`, `KickInput`, repository methods)
- Where `usersession` had its own `Service`, fold methods into the merged `SessionManager` or create `SessionAdmin` for the management surface

Naming convention to avoid clash in `package auth`:
- `SessionManager` — low-level token issuance/refresh/revoke (was `session.Service`)
- `SessionAdmin` — admin management operations (was `usersession.Service`)
- `SessionRepository` — DB access (consolidate both)

- [ ] **Step 3: Merge management routes into `auth/transport/admin/`**

`usersession` had its own routes (e.g., `/api/admin/v1/user-sessions/*`). Move route registration into `auth/transport/admin/route.go` adding a sub-group:

```go
sessions := router.Group("/api/admin/v1/auth/sessions")
sessions.GET("", handler.SessionList)
sessions.DELETE("/:id", handler.SessionRevoke)
// ... etc
```

Or preserve original URL `/api/admin/v1/user-sessions/*` — pick **one** and update plan-04 frontend grep accordingly. Recommendation: prefix under `/api/admin/v1/auth/sessions` to make the auth-ownership explicit in URLs.

- [ ] **Step 4: Merge tests into `auth/session_test.go`**

Combine `module/{session,usersession}/*_test.go` into `auth/session_test.go`, package `auth`, with prefixed test names if collision (`TestSession_Create`, `TestSessionAdmin_List`).

- [ ] **Step 5: Update consumers**

Files to update (from Task 0 Step 2 importer list):
- `internal/module/auth/service.go` — remove `import session`, use local `SessionManager`, `CreateInput`, `TokenResult`, `RefreshInput`
- `internal/module/auth/dto.go` — `RefreshResponse = session.TokenResult` → `RefreshResponse = TokenResult` (or define locally)
- `internal/module/auth/transport/{admin,app}/handler.go` + `handler_test.go`
- `internal/module/authplatform/service.go` — if it imports session
- `internal/server/router.go` — remove `usersession.RegisterRoutes(...)` (now under auth admin transport); remove `UserSessionService` from Dependencies struct
- `internal/bootstrap/*` — adjust dependency wiring

- [ ] **Step 6: Delete the two directories**

```powershell
cd E:\admin_go\admin_back_go
Remove-Item -LiteralPath .\internal\module\session -Recurse -Force
Remove-Item -LiteralPath .\internal\module\usersession -Recurse -Force
```

- [ ] **Step 7: Compile**

```powershell
cd E:\admin_go\admin_back_go
go build ./...
go test ./internal/module/auth ./internal/module/auth/transport/admin ./internal/module/auth/transport/app ./internal/server ./internal/bootstrap -count=1
```

Expected: PASS.

---

## Task 4: Merge `userloginlog` into `auth/loginlog.go`

**Files:**

- Create: `admin_back_go/internal/module/auth/loginlog.go`
- Create: `admin_back_go/internal/module/auth/loginlog_test.go`
- Delete: `admin_back_go/internal/module/userloginlog/`

- [ ] **Step 1: Inventory**

```powershell
cd E:\admin_go\admin_back_go
Get-ChildItem .\internal\module\userloginlog -File
```

Expected contents:
- `service.go` — login log write + query
- `model.go` — user_login_logs table mapping
- `repository.go`
- `route.go` / `handler.go` / `dto.go` — admin login log listing endpoint
- `*_test.go`

- [ ] **Step 2: Merge non-test files into `auth/loginlog.go`**

Create `internal/module/auth/loginlog.go`:
- Package: `package auth`
- Symbol naming inside `package auth`: prefix with `LoginLog` to avoid collision (`LoginLogService`, `LoginLogRepository`, `LoginLogEntry`, `LoginLogQuery`)
- Strip standalone route code; route moves into `auth/transport/admin/`

- [ ] **Step 3: Move admin loginlog route into `auth/transport/admin/`**

Add to `auth/transport/admin/route.go`:

```go
loginLogs := router.Group("/api/admin/v1/auth/login-logs")
loginLogs.GET("", handler.LoginLogList)
```

(Or preserve `/api/admin/v1/user-login-logs/*` — pick and document for plan-04.)

Add corresponding `LoginLogList` method to `auth/transport/admin/handler.go`.

- [ ] **Step 4: Merge tests into `auth/loginlog_test.go`**

Migrate `module/userloginlog/*_test.go` files, package `auth`, prefix names with `TestLoginLog_`.

- [ ] **Step 5: Update consumers**

- `internal/module/auth/service.go` — if it records login logs, switch to local `LoginLogService`
- `internal/server/router.go` — remove `userloginlog.RegisterRoutes(...)`; remove `UserLoginLogService` field from Dependencies
- `internal/bootstrap/*` — adjust wiring

- [ ] **Step 6: Delete directory**

```powershell
cd E:\admin_go\admin_back_go
Remove-Item -LiteralPath .\internal\module\userloginlog -Recurse -Force
```

- [ ] **Step 7: Compile**

```powershell
cd E:\admin_go\admin_back_go
go build ./...
go test ./internal/module/auth ./internal/server ./internal/bootstrap -count=1
```

Expected: PASS.

---

## Task 5: Make architecture guard GREEN

**Files:**

- Validate only.

- [ ] **Step 1: Run the extended guard**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture -count=1
```

Expected: PASS.

- [ ] **Step 2: Confirm directories are gone**

```powershell
cd E:\admin_go\admin_back_go
Test-Path .\internal\module\captcha
Test-Path .\internal\module\session
Test-Path .\internal\module\usersession
Test-Path .\internal\module\userloginlog
```

Expected: all `False`.

- [ ] **Step 3: Confirm merged files exist**

```powershell
cd E:\admin_go\admin_back_go
Test-Path .\internal\module\auth\captcha.go
Test-Path .\internal\module\auth\session.go
Test-Path .\internal\module\auth\loginlog.go
```

Expected: all `True`.

- [ ] **Step 4: No stale imports**

```powershell
cd E:\admin_go\admin_back_go
rg -n "admin_back_go/internal/module/captcha|admin_back_go/internal/module/session|admin_back_go/internal/module/usersession|admin_back_go/internal/module/userloginlog" internal cmd
```

Expected: no output.

---

## Task 6: Final verification gate

**Files:**

- Validate only.

- [ ] **Step 1: Full backend test**

```powershell
cd E:\admin_go\admin_back_go
go test ./... -count=1
```

Expected: PASS.

- [ ] **Step 2: Frontend regression check**

```powershell
cd E:\admin_go
rg -n "/api/admin/v1/captcha|/api/admin/v1/user-sessions|/api/admin/v1/user-login-logs" admin_front_ts\src admin_app -g "!*node_modules*" -g "!*dist*" -g "!*build*"
```

Expected: if URL paths changed in Tasks 2/3/4 (recommended: nested under `/api/admin/v1/auth/...`), frontend references need plan-04 follow-up. If URLs preserved, no output expected.

- [ ] **Step 3: Governance gate**

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected: pass.

- [ ] **Step 4: Final handoff**

```text
Completed in plan-03: captcha + session + usersession + userloginlog merged into module/auth.
Spec §12.1 first knife is now fully complete (plan-02 + plan-03 combined).
Open items for later plans: §12.2 shared/dict, §12.3 small module transport shells, §12.4 profile + AI aggregation, §12.5 internal/platform → internal/infra rename.
```

---

## Risk and rollback

```text
R-3a. Symbol name collisions inside package auth
      Cause: captcha, session, usersession, userloginlog each had Service/Repository/Model
      Mitigation: rename per Task 2/3/4 conventions (CaptchaService, SessionManager, SessionAdmin, LoginLogService)
      Rollback: each Task ends with go build ./... — if compile fails, revert that single task's commits

R-3b. URL path changes break frontend
      Cause: moving routes from /api/admin/v1/user-sessions/* to /api/admin/v1/auth/sessions/*
      Mitigation: pick URL strategy in Task 3 Step 3 / Task 4 Step 3, document in handoff, run plan-04 follow-up if needed
      Rollback: keep original URL paths under new handler; cheap fix even post-merge

R-3c. Bootstrap dependency wiring breaks
      Cause: removing CaptchaService / UserSessionService / UserLoginLogService fields from Dependencies struct
      Mitigation: each Task ends with go build of ./internal/server ./internal/bootstrap; if those compile, wiring is intact
      Rollback: re-add deprecated fields temporarily; this plan can land in two commits if needed
```

---

## Plan self-review

- Spec coverage: completes spec §12.1 consolidation portion that plan-02 deferred.
- Prerequisite explicit: Task 0 Step 1 hard-stops if plan-02 hasn't merged.
- TDD: Task 1 adds RED architecture guard tests before any code move.
- Importer enumeration: Task 0 Step 2 forces operator to verify the importer map before touching code.
- Naming hygiene: each merge specifies symbol-renaming conventions to avoid `package auth` collisions.
- URL stability: explicit decision points in Task 3/4 for whether to preserve original URLs or unify under auth prefix.
- Build gates: every Task ends with `go build ./...` + focused test run.
- Cleanup: Task 5 verifies guards, Task 6 runs full backend test + frontend regression check + governance.
- No drift: this plan does **not** touch governance docs (plan-01) or frontend (plan-04) or any other knife.
