# Multi-platform Phase 2 Closure Review Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task. This is the final serial closure gate for Phase 2; do not run implementation tasks in parallel. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prove and document the current Phase 2 closure state for the multi-platform backend boundary refactor without breaking existing admin behavior, and keep the status smoke-pending unless both admin smoke scripts pass.

**Architecture:** Plans 11-16 already moved shared packages, infra naming, admin transports, flat module ownership, AI aggregation, and wallet/payment ownership. Plan 17 adds one final backend architecture guard, runs the full backend/frontend/admin preservation gates, and then updates active root docs plus the original spec status. It introduces no API behavior, DB schema, permission code, route URL, frontend source, payment callback, or business runtime change.

**Tech Stack:** Go architecture tests, Gin route snapshot tests, Vue/Vitest contract checks, root governance checker, optional admin smoke scripts, Markdown docs truth.

---

## Current verified baseline

Before execution, verify both repos are clean and synced:

```powershell
cd E:\admin_go
git status --short --branch
cd E:\admin_go\admin_back_go
git status --short --branch
```

Expected:

```text
## master...origin/master
```

Current Phase 2 facts before this plan:

```text
Plan 11: internal/shared owns apperror, response, i18n, enum, validate, dict, setting
Plan 12a: userquickentry -> internal/module/profile
Plan 12b: notificationtask -> internal/module/notification/task
Plan 12c: exporttask -> internal/module/export
Plan 12d: authplatform -> internal/module/auth_platform
Plan 13: AI aggregation map and slice plans
Plan 14a: aiprovider, aiagent, aitool -> internal/module/ai/{provider,agent,tool}
Plan 14b: aiimage -> internal/module/ai/image
Plan 14c: aiknowledge -> internal/module/ai/knowledge
Plan 15: aiconversation, aimessage, aichat, airun -> internal/module/ai/{conversation,message,chat,run}
Plan 16: wallet -> internal/module/payment/wallet
```

Plan 17 is not a new feature plan. It is a final closure plan. If any verification command fails, stop, fix the narrow cause, rerun the exact failed command, and do not mark the spec complete until the full gate passes.

## Assigned work

Backend guard worktree:

```text
E:\admin_go_parallel\p17-phase2-closure-backend
branch: work/p17-phase2-closure
```

Root docs are updated only after the backend guard branch is merged and verified:

```text
E:\admin_go
branch: master
```

Create the backend worktree:

```powershell
cd E:\admin_go\admin_back_go
git fetch origin
git switch master
git pull --ff-only
git worktree add E:\admin_go_parallel\p17-phase2-closure-backend -b work/p17-phase2-closure master
cd E:\admin_go_parallel\p17-phase2-closure-backend
```

## Files

Backend worker owns:

- Create: `internal/architecture/multiplatform_phase2_closure_test.go`

Root coordinator owns after backend merge/push:

- Create: `E:\admin_go\docs\superpowers\reviews\2026-05-29-multi-platform-phase2-closure-review.md`
- Modify: `E:\admin_go\docs\status\current-status.md` for key-fact summary and verification gap
- Modify: `E:\admin_go\docs\status\module-matrix.md` if per-module sections drift
- Modify: `E:\admin_go\docs\architecture\00-platform-and-module-rules.md`
- Modify: `E:\admin_go\docs\superpowers\specs\2026-05-27-multi-platform-backend-boundary-design.md`
- Modify: `E:\admin_go\docs\superpowers\plans\2026-05-28-multi-platform-phase2-execution-map.md`

Do not modify frontend source. Do not modify database migrations. Do not modify payment callback/finalizer code. Do not modify route metadata, permission codes, i18n keys, operation log rules, or admin URLs.

## Non-negotiable behavior

```text
Admin behavior must remain stable.
Existing /api/admin/v1/* URLs must remain stable.
Existing app routes remain compile-safe but app product completeness is not expanded in this plan.
No DB schema changes.
No live data migration.
No frontend source rewrite.
No payment runtime behavior change.
No AI runtime behavior change.
No queue task type change.
No permission code change.
No i18n key/text change.
Historical docs under docs/superpowers/plans and docs/superpowers/specs may retain provenance, but active docs must clearly say current runtime truth.
```

## Task 1: Add final Phase 2 backend architecture guard

**Files:**

- Create: `internal/architecture/multiplatform_phase2_closure_test.go`

These are closure characterization guards. Plans 11-16 already landed, so the new tests are expected to pass once written. A failure means runtime drift or an incomplete merge, not a requested product behavior change.

- [ ] **Step 1: Create the final closure guard test**

Write this exact file:

```go
package architecture

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestMultiPlatformPhase2ClosureRuntimeShape(t *testing.T) {
	root := backendRoot(t)

	required := []string{
		"internal/infra",
		"internal/shared/apperror",
		"internal/shared/response",
		"internal/shared/i18n",
		"internal/shared/enum",
		"internal/shared/validate",
		"internal/shared/dict",
		"internal/shared/setting",
		"internal/module/auth/transport/admin/route.go",
		"internal/module/auth/transport/app/route.go",
		"internal/module/profile/transport/admin/route.go",
		"internal/module/profile/transport/app/route.go",
		"internal/module/user/transport/admin/route.go",
		"internal/module/auth_platform/transport/admin/route.go",
		"internal/module/notification/task",
		"internal/module/notification/transport/admin/task_route.go",
		"internal/module/export/transport/admin/route.go",
		"internal/module/ai/provider/transport/admin/route.go",
		"internal/module/ai/agent/transport/admin/route.go",
		"internal/module/ai/tool/transport/admin/route.go",
		"internal/module/ai/image/transport/admin/route.go",
		"internal/module/ai/knowledge/transport/admin/route.go",
		"internal/module/ai/conversation/transport/admin/route.go",
		"internal/module/ai/message/transport/admin/route.go",
		"internal/module/ai/chat/transport/admin/route.go",
		"internal/module/ai/run/transport/admin/route.go",
		"internal/module/payment/transport/admin/route.go",
		"internal/module/payment/transport/callback/route.go",
		"internal/module/payment/wallet/transport/admin/route.go",
	}
	for _, rel := range required {
		mustExist(t, root, rel)
	}

	removed := []string{
		"internal/platform",
		"internal/apperror",
		"internal/response",
		"internal/i18n",
		"internal/enum",
		"internal/validate",
		"internal/dict",
		"internal/module/captcha",
		"internal/module/session",
		"internal/module/usersession",
		"internal/module/userloginlog",
		"internal/module/userquickentry",
		"internal/module/notificationtask",
		"internal/module/exporttask",
		"internal/module/authplatform",
		"internal/module/aiprovider",
		"internal/module/aiagent",
		"internal/module/aitool",
		"internal/module/aiimage",
		"internal/module/aiknowledge",
		"internal/module/aiconversation",
		"internal/module/aimessage",
		"internal/module/aichat",
		"internal/module/airun",
		"internal/module/wallet",
	}
	for _, rel := range removed {
		mustNotExist(t, root, rel)
	}
}

func TestMultiPlatformPhase2ClosureNoLegacyProductionImports(t *testing.T) {
	root := backendRoot(t)
	bannedImports := []string{
		"admin_back_go/internal/platform",
		"admin_back_go/internal/apperror",
		"admin_back_go/internal/response",
		"admin_back_go/internal/i18n",
		"admin_back_go/internal/enum",
		"admin_back_go/internal/validate",
		"admin_back_go/internal/dict",
		"admin_back_go/internal/module/captcha",
		"admin_back_go/internal/module/session",
		"admin_back_go/internal/module/usersession",
		"admin_back_go/internal/module/userloginlog",
		"admin_back_go/internal/module/userquickentry",
		"admin_back_go/internal/module/notificationtask",
		"admin_back_go/internal/module/exporttask",
		"admin_back_go/internal/module/authplatform",
		"admin_back_go/internal/module/aiprovider",
		"admin_back_go/internal/module/aiagent",
		"admin_back_go/internal/module/aitool",
		"admin_back_go/internal/module/aiimage",
		"admin_back_go/internal/module/aiknowledge",
		"admin_back_go/internal/module/aiconversation",
		"admin_back_go/internal/module/aimessage",
		"admin_back_go/internal/module/aichat",
		"admin_back_go/internal/module/airun",
		"admin_back_go/internal/module/wallet",
	}

	var offenders []string
	for _, base := range []string{"cmd", "internal"} {
		err := filepath.WalkDir(filepath.Join(root, base), func(path string, entry os.DirEntry, walkErr error) error {
			if walkErr != nil {
				return walkErr
			}
			if entry.IsDir() || filepath.Ext(path) != ".go" || strings.HasSuffix(path, "_test.go") {
				return nil
			}
			body, err := os.ReadFile(path)
			if err != nil {
				return err
			}
			text := string(body)
			for _, banned := range bannedImports {
				if strings.Contains(text, banned) {
					rel, _ := filepath.Rel(root, path)
					offenders = append(offenders, filepath.ToSlash(rel)+" references "+banned)
				}
			}
			return nil
		})
		if err != nil {
			t.Fatalf("walk %s go files: %v", base, err)
		}
	}

	if len(offenders) > 0 {
		t.Fatalf("legacy Phase 2 production imports remain:\n  %s", strings.Join(offenders, "\n  "))
	}
}
```

- [ ] **Step 2: Format the test**

```powershell
cd E:\admin_go_parallel\p17-phase2-closure-backend
gofmt -w .\internal\architecture\multiplatform_phase2_closure_test.go
```

- [ ] **Step 3: Run the focused guard**

```powershell
cd E:\admin_go_parallel\p17-phase2-closure-backend
go test ./internal/architecture -run TestMultiPlatformPhase2Closure -count=1
```

Expected:

```text
ok  	admin_back_go/internal/architecture
```

## Task 2: Run backend final closure gate and commit guard branch

**Files:**

- Test: whole backend repo
- Commit: backend branch `work/p17-phase2-closure`

- [ ] **Step 1: Run backend architecture and route gates**

```powershell
cd E:\admin_go_parallel\p17-phase2-closure-backend
go test ./internal/architecture -count=1
go test ./internal/server -run TestAdminRouteSnapshot -count=1
```

Expected: both commands exit `0`.

- [ ] **Step 2: Run backend focused module gates**

```powershell
cd E:\admin_go_parallel\p17-phase2-closure-backend
go test ./internal/bootstrap ./internal/server ./internal/module/auth ./internal/module/profile ./internal/module/user ./internal/module/permission ./internal/module/role ./internal/module/payment/... ./internal/module/ai/... ./internal/module/notification/... ./internal/module/export ./internal/module/crontask ./internal/jobs -count=1
```

Expected: command exits `0`.

- [ ] **Step 3: Run backend full tests and build**

```powershell
cd E:\admin_go_parallel\p17-phase2-closure-backend
go test ./... -count=1
go build ./...
git diff --check
```

Expected: every command exits `0`.

- [ ] **Step 4: Review backend diff shape**

```powershell
cd E:\admin_go_parallel\p17-phase2-closure-backend
git status --short
git diff --stat
git diff --name-status
```

Expected diff shape:

```text
A	internal/architecture/multiplatform_phase2_closure_test.go
```

No non-test production Go files, migrations, frontend files, route metadata, permission definitions, payment callback/finalizer files, or i18n catalogs should appear in this backend diff.

- [ ] **Step 5: Commit backend guard**

```powershell
cd E:\admin_go_parallel\p17-phase2-closure-backend
git add internal/architecture/multiplatform_phase2_closure_test.go
git commit -m "test: guard multi-platform phase2 closure"
git rev-parse --short HEAD
```

Record the printed commit SHA in the worker report.

## Task 3: Merge backend guard and rerun post-merge backend gate

**Files:**

- Backend master branch only

- [ ] **Step 1: Merge backend guard branch into backend master**

```powershell
cd E:\admin_go\admin_back_go
git switch master
git pull --ff-only
git merge --no-ff work/p17-phase2-closure
```

Expected: merge succeeds with one new architecture test file.

- [ ] **Step 2: Rerun backend post-merge gate**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture -count=1
go test ./internal/server -run TestAdminRouteSnapshot -count=1
go test ./internal/bootstrap ./internal/server ./internal/module/auth ./internal/module/profile ./internal/module/user ./internal/module/permission ./internal/module/role ./internal/module/payment/... ./internal/module/ai/... ./internal/module/notification/... ./internal/module/export ./internal/module/crontask ./internal/jobs -count=1
go test ./... -count=1
go build ./...
git diff --check
```

Expected: every command exits `0`.

- [ ] **Step 3: Push backend master**

```powershell
cd E:\admin_go\admin_back_go
git push
```

Expected: backend `master` is synced with `origin/master`.

## Task 4: Run frontend/admin preservation gates

**Files:**

- No frontend source edits
- Test: existing frontend contract tests

- [ ] **Step 1: Run frontend typecheck and build check**

```powershell
cd E:\admin_go\admin_front_ts
npm run typecheck
npm run build:check
```

Expected: both commands exit `0`.

- [ ] **Step 2: Run admin contract test groups that cover the refactor surface**

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/router tests/shared/user tests/shared/permission tests/shared/payment tests/shared/wallet tests/shared/ai tests/shared/system tests/shared/realtime tests/shared/http
```

Expected: Vitest exits `0` and reports all listed test files passing.

## Task 5: Run final admin smoke if local runtime is available

**Files:**

- No source edits
- Smoke scripts: `admin_back_go/scripts/basic-admin-smoke.ps1`, `admin_back_go/scripts/full-admin-smoke.ps1`

This task proves the real admin runtime did not break. If Docker/backend/frontend/DB are not running, start them using the existing project runbook before smoke. If local infrastructure cannot be brought up in this session, write the exact smoke command and failure reason into the closure review, leave the spec status as `implemented with smoke pending`, and do not mark Phase 2 fully closed.

- [ ] **Step 1: Run basic smoke**

```powershell
cd E:\admin_go\admin_back_go
powershell -ExecutionPolicy Bypass -File .\scripts\basic-admin-smoke.ps1 -Account 15671628271 -Password 123456
```

Expected: script exits `0` and confirms login, users/me, users/init, route visibility, and logout are working.

- [ ] **Step 2: Run full smoke**

```powershell
cd E:\admin_go\admin_back_go
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account 15671628271 -Password 123456
```

Expected: script exits `0` and confirms core admin read paths for user/RBAC/system/upload/payment/wallet/AI/realtime remain working. The default smoke must not create paid payment state or call real Alipay callback.

## Task 6: Write final closure docs after verification attempt

**Files:**

- Create: `E:\admin_go\docs\superpowers\reviews\2026-05-29-multi-platform-phase2-closure-review.md`
- Modify: `E:\admin_go\docs\status\current-status.md` for key-fact summary and verification gap
- Modify: `E:\admin_go\docs\status\module-matrix.md` if per-module sections drift
- Modify: `E:\admin_go\docs\architecture\00-platform-and-module-rules.md`
- Modify: `E:\admin_go\docs\superpowers\specs\2026-05-27-multi-platform-backend-boundary-design.md`
- Modify: `E:\admin_go\docs\superpowers\plans\2026-05-28-multi-platform-phase2-execution-map.md`

Run this task after Tasks 1-5 pass, or after Task 5 records a concrete smoke blocking reason. If smoke did not pass, keep Phase 2 smoke-pending and do not write full-closure wording.

- [ ] **Step 1: Create the closure review artifact with actual command evidence**

Use this PowerShell command after all verification commands have been run in the same session:

````powershell
cd E:\admin_go
New-Item -ItemType Directory -Force .\docs\superpowers\reviews | Out-Null
$rootSha = git -C E:\admin_go rev-parse --short HEAD
$backendSha = git -C E:\admin_go\admin_back_go rev-parse --short HEAD
$review = @"
# Multi-platform Phase 2 Closure Review

Date: 2026-05-29
Root baseline before closure docs: $rootSha
Backend baseline after Plan17 guard merge: $backendSha

## Outcome

Phase 2 closes the architecture-level backend boundary refactor from `docs/superpowers/specs/2026-05-27-multi-platform-backend-boundary-design.md` when every command in this review exits 0.

## Runtime shape verified

- `internal/shared` owns apperror, response, i18n, enum, validate, dict, and setting.
- `internal/infra` is the runtime technical-resource layer; old `internal/platform` must not return.
- HTTP surfaces live under `internal/module/{capability}/transport/{platform}`.
- AI flat modules live under `internal/module/ai/{provider,agent,tool,image,knowledge,conversation,message,chat,run}`.
- Wallet lives under `internal/module/payment/wallet`.
- Admin URLs, DB table names, permission codes, i18n keys, route metadata, operation log rules, queue task types, and payment callback/finalizer behavior are preserved.

## Verification commands

Backend:

```powershell
go test ./internal/architecture -count=1
go test ./internal/server -run TestAdminRouteSnapshot -count=1
go test ./internal/bootstrap ./internal/server ./internal/module/auth ./internal/module/profile ./internal/module/user ./internal/module/permission ./internal/module/role ./internal/module/payment/... ./internal/module/ai/... ./internal/module/notification/... ./internal/module/export ./internal/module/crontask ./internal/jobs -count=1
go test ./... -count=1
go build ./...
git diff --check
```

Frontend:

```powershell
npm run typecheck
npm run build:check
npm run test -- tests/shared/router tests/shared/user tests/shared/permission tests/shared/payment tests/shared/wallet tests/shared/ai tests/shared/system tests/shared/realtime tests/shared/http
```

Smoke:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\basic-admin-smoke.ps1 -Account 15671628271 -Password 123456
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account 15671628271 -Password 123456
```

Root governance:

```powershell
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

## Remaining risks after closure

- App product completeness remains outside this architecture closure.
- Future merchant/openapi/miniapp entrypoints still require their own product/API plans.
- Live third-party payment callbacks are not created by default smoke.
- Historical superpowers plans and specs retain provenance and can mention old paths; active docs and runtime guards define current truth.
"@
Set-Content -Path .\docs\superpowers\reviews\2026-05-29-multi-platform-phase2-closure-review.md -Encoding UTF8 -Value $review
````

- [ ] **Step 2: Update status docs**

In `E:\admin_go\docs\status\current-status.md`, keep the Phase 2 section as a key-fact summary and verification-gap record. The current default wording is smoke-pending:

```markdown
## 2026-05-29 multi-platform backend boundary Phase 2 closure

- Phase 2 of `docs/superpowers/specs/2026-05-27-multi-platform-backend-boundary-design.md` has passed code/docs/frontend gates after Plans 11-17, but final admin smoke is still pending; do not mark the spec fully closed until basic and full smoke pass.
- Current backend boundary truth is `internal/module/{capability}/transport/{platform}` + `internal/shared` + `internal/infra`; active exceptions are product-scope decisions, not architecture drift.
- Admin behavior preservation remains the acceptance standard: existing admin URLs, DB table names, permission codes, i18n keys, route metadata, operation log rules, queue task types, payment callback/finalizer behavior, and frontend typed API contracts were preserved.
- Future app/openapi/merchant/miniapp work starts from this boundary and must add `transport/{platform}` slices under existing capabilities instead of creating platform-prefixed modules.
```

Only if both basic and full smoke pass in a later rerun may the first bullet be changed to full closure:

```markdown
- Phase 2 of `docs/superpowers/specs/2026-05-27-multi-platform-backend-boundary-design.md` is closed after Plans 11-17, including final admin basic/full smoke and root governance.
```

Use `E:\admin_go\docs\status\module-matrix.md` for any per-module section changes; do not re-expand module sections inside `current-status.md`.

- [ ] **Step 3: Update architecture hard rules current-state paragraph**

In `E:\admin_go\docs\architecture\00-platform-and-module-rules.md`, replace the current paragraph that starts with `当前 internal/shared 已拥有` with this text:

```markdown
当前 Phase 2 架构级重构已完成最终收口：`internal/shared` 拥有 apperror / response / i18n / enum / validate / dict / setting；旧 root shared-like packages 已删除；`internal/infra` 是运行时技术资源层，旧 `internal/platform` 不得回归；HTTP 表面位于 `internal/module/{capability}/transport/{platform}`；`userquickentry` 归入 `profile`，`notificationtask` 归入 `notification/task`，`exporttask` 目录改为 `export`，`authplatform` 目录改为 `auth_platform`；AI flat modules 已迁入 `internal/module/ai/{provider,agent,tool,image,knowledge,conversation,message,chat,run}`；wallet 已迁入 `internal/module/payment/wallet`。旧目录和旧 import 路径由 backend architecture guards 保护，不得回归。
```

- [ ] **Step 4: Update original spec status**

At the top of `E:\admin_go\docs\superpowers\specs\2026-05-27-multi-platform-backend-boundary-design.md`, keep the current status smoke-pending unless both smoke commands pass:

```markdown
状态：代码与文档收口完成，等待最终 admin smoke 复验（运行时事实入口以 `docs/status/current-status.md` 为准，per-module 明细以 `docs/status/module-matrix.md` 为准，结构约束以 backend architecture guards 为准）
```

Only after both basic and full smoke pass may this become:

```markdown
状态：已完成（Phase 2 最终收口于 2026-05-29；运行时事实入口以 `docs/status/current-status.md` 为准，per-module 明细以 `docs/status/module-matrix.md` 为准，结构约束以 backend architecture guards 为准）
```

- [ ] **Step 5: Update Phase 2 execution map**

In `E:\admin_go\docs\superpowers\plans\2026-05-28-multi-platform-phase2-execution-map.md`, update the remaining Plan 17 references so they say:

```text
DONE 17: final Phase 2 guard, docs, smoke-pending evidence, and spec closure review (`docs/superpowers/plans/2026-05-29-multi-platform-17-phase2-closure-review.md`)
```

Update the final done meaning block so it says:

```text
Phase 2 code/docs boundary is done only when all of the following are true:
internal/shared contains apperror, response, i18n, enum, validate, dict, setting
old root shared-like packages are removed and guarded
old technical-resource internal/platform is removed and guarded by internal/infra
small flat modules have been aggregated or explicitly retained with documented ownership
AI aggregation has landed through safe slices: 14a-14c plus Plan 15 are complete
wallet/payment decision is complete: wallet lives under internal/module/payment/wallet
final Plan 17 architecture guard passes
admin route snapshot passes
backend full tests and build pass
frontend admin contract/type/build gates pass
active docs say exactly what is implemented
the original multi-platform spec is reviewed against runtime before being marked complete
Full Phase 2 closure still requires admin basic and full smoke to pass; otherwise the spec remains marked smoke-pending.
```

## Task 7: Root governance, docs commit, and push

**Files:**

- Root docs from Task 6

- [ ] **Step 1: Review root docs diff**

```powershell
cd E:\admin_go
git status --short
git diff --stat
git diff -- docs/status/current-status.md docs/status/module-matrix.md docs/architecture/00-platform-and-module-rules.md docs/superpowers/specs/2026-05-27-multi-platform-backend-boundary-design.md docs/superpowers/plans/2026-05-28-multi-platform-phase2-execution-map.md docs/superpowers/reviews/2026-05-29-multi-platform-phase2-closure-review.md
```

Expected: only the Task 6 root docs paths are changed; `module-matrix.md` appears only if per-module sections drifted.

- [ ] **Step 2: Run root governance**

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected governance output:

```text
PASS: no blocking governance violations found.
```

- [ ] **Step 3: Commit and push root docs**

```powershell
cd E:\admin_go
git add docs/status/current-status.md docs/status/module-matrix.md docs/architecture/00-platform-and-module-rules.md docs/superpowers/specs/2026-05-27-multi-platform-backend-boundary-design.md docs/superpowers/plans/2026-05-28-multi-platform-phase2-execution-map.md docs/superpowers/reviews/2026-05-29-multi-platform-phase2-closure-review.md
git commit -m "docs: close multi-platform phase2 architecture refactor"
git push
```

Expected: root `master` is synced with `origin/master`.

## Final review checklist

Before reporting final closure, verify each item:

```text
Backend master contains the Plan17 guard commit.
Root master contains the Plan17 closure docs commit.
internal/module root has no route.go or handler.go HTTP surface files.
internal/platform is absent.
internal/shared owns apperror, response, i18n, enum, validate, dict, setting.
internal/module/wallet is absent and internal/module/payment/wallet exists.
Old AI flat module directories are absent and internal/module/ai subpackages exist.
Old small flat module directories userquickentry, notificationtask, exporttask, authplatform are absent.
Admin route snapshot passed.
Backend go test ./... and go build ./... passed.
Frontend typecheck, build:check, and listed contract tests passed.
Basic and full admin smoke passed, or the spec status explicitly says smoke pending.
Root governance checker passed.
No DB schema, route URL, permission code, i18n key, operation log rule, frontend source, payment finalizer, or callback behavior changed in this plan.
```

## Final worker report format

Report exactly:

```text
Plan17 backend commit: paste `git -C E:\admin_go\admin_back_go rev-parse --short HEAD`
Plan17 root docs commit: paste `git -C E:\admin_go rev-parse --short HEAD`
Backend verification: list every backend command from Tasks 2-3 with pass/fail result
Frontend verification: list every frontend command from Task 4 with pass/fail result
Smoke verification: list basic/full smoke result or the exact smoke-pending reason
Governance verification: git diff --check + check-agent-governance result
Outcome: Phase 2 closed, or code/docs closed with smoke pending
Remaining risks: app/openapi/merchant/miniapp product work remains future scope; live third-party callbacks are not created by default smoke
```
