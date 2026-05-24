# Admin App Phase 3 UniApp Shell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Build the first `admin_app` UniApp Vue3 shell: real `/api/app/v1` login, current-user session, logout, two guarded tabbar pages, and a maintainable mobile UI baseline.

**Architecture:** Treat `admin_app` as an independent UniApp Vue3 + TypeScript runtime under the `E:\admin_go` agent framework. Keep the app API boundary separate from `/api/admin/v1`: the app only calls `/api/app/v1/auth/login`, `/api/app/v1/users/me`, and `/api/app/v1/auth/logout`; first-pass RBAC is a session guard because the served App API does not return app menus, routes, or button capabilities.

**Tech Stack:** UniApp Vue3, TypeScript, Vue I18n, Vitest, vue-tsc, H5 build through `uni build`, `uview-plus@3.8.37` via `easycom` on-demand components plus a local minimal `$u` runtime.

---

## Scope Check

This plan replaces the stale Flutter plan at the same path. The live project is `E:\admin_go\admin_app`, and the current app runtime is UniApp Vue3 + TypeScript, not Flutter.

In scope:

```text
1. Register admin_app with the E:\admin_go agent framework.
2. Document the UniApp runtime architecture and app-api v1 contract.
3. Replace UniApp starter pages/assets with login/home/mine.
4. Implement app API request, auth client, session controller, storage, and route guards.
5. Use Vue I18n for visible copy.
6. Select and wire uview-plus without full plugin install.
7. Verify with Vitest, vue-tsc, H5 build, governance checks, and live /api/app/v1 smoke.
```

Out of scope:

```text
1. Reusing backend admin RBAC router/buttonCodes in the app.
2. Creating fake app menu trees before the backend serves them.
3. Secure native credential storage; current token storage is the next slice.
4. Implementing business modules beyond home/mine shell pages.
5. Reopening the Flutter implementation path.
```

## File Structure

Root governance:

```text
Modify: docs/status/current-status.md
Replace: docs/superpowers/plans/2026-05-23-admin-app-phase3-real-login-shell.md
```

App governance and docs:

```text
Create: admin_app/AGENTS.md
Create: admin_app/docs/architecture.md
Create: admin_app/docs/app-api-v1.md
```

App package/build baseline:

```text
Modify: admin_app/package.json
Create: admin_app/package-lock.json
Modify: admin_app/vite.config.ts
Create: admin_app/vitest.config.ts
Modify: admin_app/src/env.d.ts
Rename: admin_app/src/shime-uni.d.ts -> admin_app/src/shim-uni.d.ts
Delete: admin_app/src/pages/index/index.vue
Delete: admin_app/src/static/logo.png
```

App runtime code:

```text
Modify: admin_app/src/main.ts
Modify: admin_app/src/App.vue
Modify: admin_app/src/pages.json
Create: admin_app/src/api/http.ts
Create: admin_app/src/api/appAuth.ts
Create: admin_app/src/composables/useSession.ts
Create: admin_app/src/config/env.ts
Create: admin_app/src/constants/storage.ts
Create: admin_app/src/i18n.ts
Create: admin_app/src/locales/zh-CN.ts
Create: admin_app/src/locales/en-US.ts
Create: admin_app/src/pages/login/index.vue
Create: admin_app/src/pages/home/index.vue
Create: admin_app/src/pages/mine/index.vue
Create: admin_app/src/plugins/uview-runtime.ts
Create: admin_app/src/plugins/uview-luch-request-shim.ts
Create: admin_app/src/router/guards.ts
Create: admin_app/src/stores/session.ts
Create: admin_app/src/types/api.ts
Create: admin_app/src/types/auth.ts
Create: admin_app/src/types/user.ts
Create: admin_app/src/utils/storage.ts
```

App tests:

```text
Create: admin_app/tests/api-http.test.ts
Create: admin_app/tests/app-auth-api.test.ts
Create: admin_app/tests/app-routing.test.ts
Create: admin_app/tests/router-guards.test.ts
Create: admin_app/tests/session-controller.test.ts
Create: admin_app/tests/uview-runtime.test.ts
```

---

### Task 1: Register admin_app in the agent framework

**Files:**
- Create: `admin_app/AGENTS.md`
- Create: `admin_app/docs/architecture.md`
- Create: `admin_app/docs/app-api-v1.md`
- Modify: `docs/status/current-status.md`

- [x] **Step 1: Write the app execution rules**

Create `admin_app/AGENTS.md` with the app-specific boundary:

```text
admin_app is a UniApp Vue3 mobile runtime.
It only calls /api/app/v1.
It does not reuse /api/admin/v1 menu/button/cookie semantics.
First RBAC slice is login-state guard only.
Visible copy must go through src/locales/zh-CN.ts and src/locales/en-US.ts.
```

- [x] **Step 2: Document architecture and API contract**

Create `admin_app/docs/architecture.md` and `admin_app/docs/app-api-v1.md` covering:

```text
POST /api/app/v1/auth/login
GET  /api/app/v1/users/me
POST /api/app/v1/auth/logout
```

Record that App password login skips admin captcha and bearer requests use `platform=app`.

- [x] **Step 3: Sync root current status**

Update `docs/status/current-status.md` so `app auth baseline` points at `admin_app` UniApp docs and tests instead of the retired Flutter wording.

### Task 2: Replace UniApp starter with the app shell routes

**Files:**
- Modify: `admin_app/package.json`
- Create: `admin_app/package-lock.json`
- Modify: `admin_app/src/pages.json`
- Rename: `admin_app/src/shime-uni.d.ts -> admin_app/src/shim-uni.d.ts`
- Delete: `admin_app/src/pages/index/index.vue`
- Delete: `admin_app/src/static/logo.png`
- Test: `admin_app/tests/app-routing.test.ts`

- [x] **Step 1: Add routing regression tests**

Create `tests/app-routing.test.ts` to prove:

```text
package name is admin-app
login is the first page
only tabbar pages are home and mine
starter index page and logo asset are absent
shim-uni.d.ts replaces shime-uni.d.ts
```

- [x] **Step 2: Configure pages**

Set `src/pages.json` pages to:

```json
[
  { "path": "pages/login/index" },
  { "path": "pages/home/index" },
  { "path": "pages/mine/index" }
]
```

Set tabbar to:

```json
[
  { "pagePath": "pages/home/index", "text": "首页" },
  { "pagePath": "pages/mine/index", "text": "我的" }
]
```

- [x] **Step 3: Remove starter leftovers**

Delete the generated `pages/index/index.vue` and `static/logo.png`; rename the shim typo to `shim-uni.d.ts`.

### Task 3: Build the app API and session boundary

**Files:**
- Create: `admin_app/src/api/http.ts`
- Create: `admin_app/src/api/appAuth.ts`
- Create: `admin_app/src/stores/session.ts`
- Create: `admin_app/src/composables/useSession.ts`
- Create: `admin_app/src/config/env.ts`
- Create: `admin_app/src/constants/storage.ts`
- Create: `admin_app/src/types/api.ts`
- Create: `admin_app/src/types/auth.ts`
- Create: `admin_app/src/types/user.ts`
- Create: `admin_app/src/utils/storage.ts`
- Test: `admin_app/tests/api-http.test.ts`
- Test: `admin_app/tests/app-auth-api.test.ts`
- Test: `admin_app/tests/session-controller.test.ts`

- [x] **Step 1: Test the HTTP response boundary**

Add tests for unified response unwrap, non-zero response errors, and bearer token lookup.

- [x] **Step 2: Test the auth client contract**

Add tests proving the app auth client calls these exact relative paths:

```text
/auth/login
/users/me
/auth/logout
```

- [x] **Step 3: Test the session controller**

Add tests proving:

```text
no token -> guest
stored token -> fetch /users/me and authenticated
login -> persist token + user
logout -> call backend logout and clear local state
```

- [x] **Step 4: Implement the boundary**

Implement `appRequest`, `createAppAuthClient`, `createSessionController`, and UniApp storage adapters. Add `platform: app`, `Accept-Language: zh-CN`, and `Authorization: Bearer <token>` when authenticated.

### Task 4: Add login-state route guards

**Files:**
- Create: `admin_app/src/router/guards.ts`
- Test: `admin_app/tests/router-guards.test.ts`

- [x] **Step 1: Test guard behavior with injected dependencies**

Create tests for `createAuthGuards(authSession, navigator)` proving:

```text
authenticated session returns true and does not redirect
guest session reLaunches to /pages/login/index
login success can switchTab to /pages/home/index
```

- [x] **Step 2: Implement injected guards and default wrappers**

Implement:

```ts
createAuthGuards(authSession, navigator)
redirectToLogin()
redirectToHome()
requireAuthenticatedPage()
```

Default wrappers use the singleton `session` and `uni` navigator; tests use injected fakes.

### Task 5: Implement i18n pages and uview-plus runtime

**Files:**
- Modify: `admin_app/src/main.ts`
- Modify: `admin_app/src/App.vue`
- Create: `admin_app/src/i18n.ts`
- Create: `admin_app/src/locales/zh-CN.ts`
- Create: `admin_app/src/locales/en-US.ts`
- Create: `admin_app/src/pages/login/index.vue`
- Create: `admin_app/src/pages/home/index.vue`
- Create: `admin_app/src/pages/mine/index.vue`
- Create: `admin_app/src/plugins/uview-runtime.ts`
- Create: `admin_app/src/plugins/uview-luch-request-shim.ts`
- Modify: `admin_app/vite.config.ts`
- Test: `admin_app/tests/uview-runtime.test.ts`

- [x] **Step 1: Add Vue I18n**

Install `i18n` in `src/main.ts`; put every visible login/home/mine copy in `src/locales/zh-CN.ts` and `src/locales/en-US.ts`.

- [x] **Step 2: Render the pages**

Implement:

```text
pages/login/index.vue: account/password form -> session.login -> switchTab home
pages/home/index.vue: session guard + current user greeting + app API status card
pages/mine/index.vue: session guard + account card + logout modal -> backend logout -> login
```

- [x] **Step 3: Wire uview-plus without full install**

Use `pages.json` `easycom` for `u-*` / `up-*` components and install a local minimal `$u` runtime in `src/plugins/uview-runtime.ts`. Do not call full `app.use(uviewPlus)`, because the H5 build pulls unused broken component internals from the published package.

- [x] **Step 4: Shim the broken uview-plus relative import**

Use `vite.config.ts` aliasing to point uview-plus internal `luch-request` import to `src/plugins/uview-luch-request-shim.ts`. The shim rejects if used; current app runtime does not use uview-plus HTTP.

### Task 6: Verify app, live backend, and governance gates

**Files:**
- Runtime: `E:\admin_go\admin_app`
- Runtime: `E:\admin_go\.docker\admin-go-backend`
- Runtime: `http://127.0.0.1:8080`
- Governance: `E:\admin_go`

- [x] **Step 1: Run app unit tests**

Run:

```powershell
cd E:\admin_go\admin_app
npm run test:unit
```

Expected:

```text
6 files passed, 18 tests passed
```

- [x] **Step 2: Run app type check**

Run:

```powershell
npm run type-check
```

Expected:

```text
vue-tsc --noEmit exits 0
```

- [x] **Step 3: Run H5 build**

Run:

```powershell
npm run build:h5
```

Expected:

```text
DONE Build complete
```

Known warnings are Sass and uview-plus deprecation warnings only; they are not build failures.

- [x] **Step 4: Run live app-api smoke**

With backend Docker already healthy on `127.0.0.1:8080`, call:

```text
GET  /health
GET  /ready
POST /api/app/v1/auth/login
GET  /api/app/v1/users/me
POST /api/app/v1/auth/logout
```

Expected:

```text
/health -> status ok
/ready -> database/redis/token_redis/queue_redis/realtime up
login -> code=0, token returned, user.id=1
me -> code=0, user.id=1
logout -> code=0
```

- [x] **Step 5: Run root governance gates**

Run:

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected:

```text
No whitespace errors.
No blocking governance violations.
```

---

## Self-Review Checklist

- [x] Runtime identity: plan and docs say UniApp Vue3, not Flutter.
- [x] API boundary: app only calls `/api/app/v1/auth/login`, `/api/app/v1/users/me`, and `/api/app/v1/auth/logout`.
- [x] RBAC honesty: first version is login-state guard only; no fake admin menus, router trees, or buttonCodes.
- [x] UI component choice: `uview-plus@3.8.37` is used through `easycom` on demand plus local `$u` runtime, not full plugin install.
- [x] i18n: visible copy is in `zh-CN.ts` and `en-US.ts`.
- [x] Verification: unit tests, type check, H5 build, live app-api smoke, `git diff --check`, and governance checker are required before final completion claim.
