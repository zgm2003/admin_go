# Plan 04: Frontend `/api/Users/*` Legacy Cleanup

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove all frontend references to `/api/Users/*` legacy POST routes in `admin_front_ts` and `admin_app`. Backend deletion happens in plan-02; this plan ensures no frontend code calls the deleted endpoints when plan-02 lands.

**Source spec:** `docs/superpowers/specs/2026-05-27-multi-platform-backend-boundary-design.md` §14.1 R-3 (legacy route removal coordination).

**Tech Stack:** TypeScript (Vue), Dart (Flutter), `rg`, `git diff --check`.

---

## Scope Check

This plan executes:

```text
1. Enumerate /api/Users/* references in admin_front_ts and admin_app
2. Rewrite each call site to the new endpoint:
     /api/Users/getLoginConfig   → GET  /api/admin/v1/auth/login-config       (admin)
                                  → GET  /api/app/v1/auth/login-config         (app)
     /api/Users/sendCode         → POST /api/admin/v1/auth/send-code           (admin)
                                  → POST /api/app/v1/auth/send-code            (app)
     /api/Users/login            → POST /api/admin/v1/auth/login               (admin)
                                  → POST /api/app/v1/auth/login                (app)
     /api/Users/refresh          → POST /api/admin/v1/auth/refresh             (admin)
     /api/Users/logout           → POST /api/admin/v1/auth/logout              (admin)
                                  → POST /api/app/v1/auth/logout               (app)
     /api/Users/init             → GET  /api/admin/v1/users/init               (admin)
3. Run frontend lint/typecheck on touched files
4. Update docs/contracts/admin-api-v1.md and docs/testing/smoke-matrix.md if they list legacy paths
```

This plan does **not**:
- Touch any backend Go code (plan-02 / plan-03).
- Touch governance docs (plan-01).
- Add new endpoints (the new endpoints already exist as the non-legacy variants).

**Parallel siblings:** can run alongside plan-01, plan-02, plan-03 — no file overlap with any of them.

**Coordination:** ideal merge order is plan-04 merges **before or with** plan-02. If plan-02 lands first, frontend will 404 on these calls. If plan-04 lands first, backend still serves both — no breakage. Recommended: merge plan-04 first.

---

## File Structure (to be determined by Task 1 grep)

Likely callers based on typical structure:

- `admin_front_ts/src/api/` — axios API client modules
- `admin_front_ts/src/store/` — Pinia/Vuex auth store
- `admin_front_ts/src/views/login/` — login page components
- `admin_app/lib/data/api/` — Dart API client
- `admin_app/lib/features/auth/` — auth screens
- `docs/contracts/admin-api-v1.md` — API contract doc (if mentions legacy)
- `docs/testing/smoke-matrix.md` — smoke test matrix (if mentions legacy)

Task 1 produces the actual list.

---

## Task 1: Enumerate all `/api/Users` references

**Files:**

- Validate only.

- [ ] **Step 1: Scan admin_front_ts**

```powershell
cd E:\admin_go
rg -n "/api/Users" admin_front_ts\src admin_front_ts\tests -g "!*node_modules*" -g "!*dist*" -g "!*build*"
```

Record every match: file path, line, exact URL string, surrounding context (which HTTP method, which caller).

- [ ] **Step 2: Scan admin_app**

```powershell
cd E:\admin_go
rg -n "/api/Users" admin_app\lib admin_app\test -g "!*build*" -g "!*.dart_tool*"
```

Record matches the same way.

- [ ] **Step 3: Scan docs**

```powershell
cd E:\admin_go
rg -n "/api/Users" docs admin_back_go\docs -g "!*node_modules*"
```

Note: backend doc references will also be cleaned by plan-01, but the contract/smoke-matrix docs are listed here since they describe frontend-visible contracts.

- [ ] **Step 4: Build the rewrite table**

For each legacy path found, decide the target per the table in Scope Check. If a call site is ambiguous (e.g., shared util used by both admin and app), inspect the consumer to determine which platform prefix applies.

If grep returns **no matches** in any of the three scans, this plan reduces to: skip to Task 4 (verify zero references). Document this in the handoff.

---

## Task 2: Rewrite `admin_front_ts` call sites

**Files:**

- Modify: files identified in Task 1 Step 1

- [ ] **Step 1: Rewrite each axios/fetch URL**

For each match from Task 1 Step 1, update the URL string AND the HTTP method if the legacy form used POST but the new endpoint uses GET (e.g., `getLoginConfig`).

Example diff for a likely caller (`admin_front_ts/src/api/auth.ts` or similar):

```diff
-export const getLoginConfig = () => request.post('/api/Users/getLoginConfig')
+export const getLoginConfig = () => request.get('/api/admin/v1/auth/login-config')
```

```diff
-export const login = (data) => request.post('/api/Users/login', data)
+export const login = (data) => request.post('/api/admin/v1/auth/login', data)
```

Adjust response handling if the new endpoint returns a different envelope shape — typically the new routes already share the same response wrapper as `/api/admin/v1/*`.

- [ ] **Step 2: Run frontend typecheck on touched files**

```powershell
cd E:\admin_go\admin_front_ts
pnpm run typecheck
# or: npm run typecheck / yarn typecheck — use whichever the project script defines
```

Expected: no new TS errors. If a touched file had pre-existing errors unrelated to this plan, document them in handoff but do not silently leave them.

- [ ] **Step 3: Run frontend unit tests for touched modules**

```powershell
cd E:\admin_go\admin_front_ts
pnpm run test -- src/api src/store/auth
```

Expected: PASS or PASS with skips matching pre-plan-04 baseline.

---

## Task 3: Rewrite `admin_app` call sites

**Files:**

- Modify: files identified in Task 1 Step 2

- [ ] **Step 1: Rewrite each Dio/http URL**

Same pattern as Task 2 but using app endpoints (`/api/app/v1/auth/*` prefix). Example:

```diff
-final response = await dio.post('/api/Users/login', data: payload);
+final response = await dio.post('/api/app/v1/auth/login', data: payload);
```

- [ ] **Step 2: Run flutter analyze**

```powershell
cd E:\admin_go\admin_app
flutter analyze
```

Expected: no new analyzer issues.

- [ ] **Step 3: Run flutter unit tests**

```powershell
cd E:\admin_go\admin_app
flutter test
```

Expected: PASS or PASS with skips matching pre-plan-04 baseline.

---

## Task 4: Update contract / smoke docs

**Files:**

- Modify (if mentioned in Task 1 Step 3): `docs/contracts/admin-api-v1.md`
- Modify (if mentioned in Task 1 Step 3): `docs/testing/smoke-matrix.md`

- [ ] **Step 1: Remove legacy entries from contracts**

For each `/api/Users/*` row in `docs/contracts/admin-api-v1.md`, **delete the row entirely**. Do not leave "deprecated" markers — per spec §1.3 the project has no legacy concept.

If the contract doc has a "deprecated" section listing these endpoints, delete the section.

- [ ] **Step 2: Update smoke-matrix**

In `docs/testing/smoke-matrix.md`, replace any `/api/Users/*` smoke step with the new endpoint URL.

- [ ] **Step 3: Verify**

```powershell
cd E:\admin_go
rg -n "/api/Users" docs admin_back_go\docs
```

Expected: no matches.

---

## Task 5: Final verification gate

**Files:**

- Validate only.

- [ ] **Step 1: Zero frontend references**

```powershell
cd E:\admin_go
rg -n "/api/Users" admin_front_ts\src admin_front_ts\tests admin_app\lib admin_app\test docs admin_back_go\docs -g "!*node_modules*" -g "!*dist*" -g "!*build*" -g "!*.dart_tool*"
```

Expected: **no output**. Any match means a call site or doc was missed.

- [ ] **Step 2: Frontend builds clean**

```powershell
cd E:\admin_go\admin_front_ts
pnpm run build
```

```powershell
cd E:\admin_go\admin_app
flutter build apk --debug
```

Expected: both succeed. The flutter build can be skipped if the local toolchain doesn't have Android SDK — substitute `flutter analyze` as proof of compile-cleanliness.

- [ ] **Step 3: Governance gate**

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected: pass.

- [ ] **Step 4: Final handoff**

```text
Completed in plan-04: removed all /api/Users/* references from admin_front_ts, admin_app, docs/contracts, docs/testing.
Call sites rewritten to /api/{admin,app}/v1/auth/* and /api/admin/v1/users/init per platform.
This plan should land before or together with plan-02; landing after plan-02 will cause frontend 404s in the gap.
```

---

## Plan self-review

- Spec coverage: spec §14.1 R-3 frontend coordination.
- Parallelism: zero overlap with plan-01 (docs), plan-02 (backend), plan-03 (backend module merge).
- Independence: this plan is self-contained — it can land first, last, or middle of the multi-platform series.
- Honesty: Task 1 lists scan output as the ground truth for which files to touch; the plan doesn't enumerate them upfront because frontend structure isn't audited as part of the source spec.
- Discoverability: every URL rewrite is in the Scope Check table so an executor can plan all the rewrites without exploring backend code.
- Test gates: Task 2/3 require typecheck + unit tests pass per platform; Task 5 requires zero residual references.
