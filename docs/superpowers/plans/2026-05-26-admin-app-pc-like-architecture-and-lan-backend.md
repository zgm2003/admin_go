# Admin App PC-like Frontend Architecture and LAN Backend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `admin_app` use the same readable frontend architecture language as PC admin and make the Go backend reachable from LAN phone debugging at `192.168.5.20`.

**Architecture:** This is a structure-preserving refactor: move files into PC-admin-like directories, update imports/routes/docs, and lock the new layout with tests before and after migration. Backend LAN access stays deployment-owned through Docker host bind and `CORS_ALLOW_ORIGINS`; app business behavior and API contracts do not change.

**Tech Stack:** UniApp + Vue 3 + TypeScript + vue-i18n + uview-plus + Vitest; Go backend config/middleware tests; Docker-first Compose.

---

## File structure map

### Frontend target files

- Move: `admin_app/src/pages/**` -> `admin_app/src/views/**`
- Move: `admin_app/src/composables/useSession.ts` -> `admin_app/src/hooks/useSession.ts`
- Move: `admin_app/src/composables/usePreferences.ts` -> `admin_app/src/hooks/usePreferences.ts`
- Move: `admin_app/src/stores/session.ts` -> `admin_app/src/store/session.ts`
- Move: `admin_app/src/stores/preferences.ts` -> `admin_app/src/store/preferences.ts`
- Move: `admin_app/src/constants/storage.ts` -> `admin_app/src/enums/storage.ts`
- Move: `admin_app/src/i18n.ts` -> `admin_app/src/i18n/index.ts`
- Move: `admin_app/src/locales/en-US.ts` -> `admin_app/src/i18n/locales/en-US.ts`
- Move: `admin_app/src/locales/zh-CN.ts` -> `admin_app/src/i18n/locales/zh-CN.ts`
- Move: `admin_app/src/config/env.ts` -> `admin_app/src/lib/http/env.ts`
- Move: `admin_app/src/api/http.ts` -> `admin_app/src/lib/http/index.ts`
- Move: `admin_app/src/lib/appUploadRuntime.ts` -> `admin_app/src/lib/upload/appUploadRuntime.ts`
- Move: `admin_app/src/lib/platform/appMediaPermission.ts` -> `admin_app/src/platform/app/appMediaPermission.ts`
- Move: `admin_app/src/plugins/uview-runtime.ts` -> `admin_app/src/platform/uview/runtime.ts`
- Move: `admin_app/src/plugins/uview-luch-request-shim.ts` -> `admin_app/src/platform/uview/luch-request-shim.ts`
- Modify: `admin_app/src/pages.json`
- Modify: `admin_app/src/main.ts`
- Modify: `admin_app/src/App.vue`
- Modify: `admin_app/src/router/guards.ts`
- Modify: `admin_app/src/utils/storage.ts`
- Modify: `admin_app/src/utils/localCache.ts`
- Modify: `admin_app/src/api/appAuth.ts`
- Modify: `admin_app/src/api/appProfile.ts`
- Modify: `admin_app/src/api/appUpload.ts`
- Modify: `admin_app/src/components/AppMediaUploader/src/AppMediaUploader.vue`
- Modify: `admin_app/vite.config.ts`
- Test: `admin_app/tests/app-architecture.test.ts`
- Modify tests under `admin_app/tests/*.test.ts` that refer to old paths.

### Backend LAN files

- Modify: `admin_back_go/deploy/docker-first/compose.env.example`
- Modify if present and ignored: `admin_back_go/deploy/docker-first/.env`
- Modify if present and ignored: `admin_back_go/deploy/docker-first/admin-go.env`
- Modify: `admin_back_go/internal/config/config_test.go`
- Modify: `admin_back_go/README.md`
- Modify: `docs/deployment/local.md`
- Modify: `docs/status/current-status.md`
- Modify: `admin_app/docs/architecture.md`
- Modify: `admin_app/docs/app-api-v1.md`

---

### Task 1: Backend LAN host bind and CORS plan guard

**Files:**
- Modify: `admin_back_go/internal/config/config_test.go`
- Modify: `admin_back_go/deploy/docker-first/compose.env.example`
- Modify if present: `admin_back_go/deploy/docker-first/.env`
- Modify if present: `admin_back_go/deploy/docker-first/admin-go.env`
- Modify: `admin_back_go/README.md`
- Modify: `docs/deployment/local.md`

- [ ] **Step 1: Add the failing backend config tests**

Append these tests near the existing Docker-first/CORS tests in `admin_back_go/internal/config/config_test.go`:

```go
func TestDockerFirstComposeExampleAllowsLanApiBind(t *testing.T) {
	values := readDockerFirstComposeEnv(t, "compose.env.example")

	if got := values["ADMIN_API_HOST_BIND"]; got != "0.0.0.0" {
		t.Fatalf("compose.env.example must bind API to LAN for phone debugging, got %q", got)
	}
}

func TestLoadPreservesLanDevCORSOrigin(t *testing.T) {
	t.Setenv("CORS_ALLOW_ORIGINS", "http://localhost:5173,http://127.0.0.1:5173,http://192.168.5.20:5173")

	cfg := Load()
	want := []string{"http://localhost:5173", "http://127.0.0.1:5173", "http://192.168.5.20:5173"}
	if !reflect.DeepEqual(cfg.CORS.AllowOrigins, want) {
		t.Fatalf("unexpected LAN dev CORS origins: %#v", cfg.CORS.AllowOrigins)
	}
}

func readDockerFirstComposeEnv(t *testing.T, fileName string) map[string]string {
	t.Helper()
	content, err := os.ReadFile(filepath.Join("..", "..", "deploy", "docker-first", fileName))
	if err != nil {
		t.Fatalf("read deploy/docker-first/%s: %v", fileName, err)
	}
	values := make(map[string]string)
	for _, line := range strings.Split(string(content), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		key, value, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}
		values[strings.TrimSpace(key)] = strings.TrimSpace(value)
	}
	return values
}
```

- [ ] **Step 2: Run the backend tests and verify RED**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/config -run "TestDockerFirstComposeExampleAllowsLanApiBind|TestLoadPreservesLanDevCORSOrigin" -count=1
```

Expected before implementation: `TestDockerFirstComposeExampleAllowsLanApiBind` fails because `compose.env.example` still has `ADMIN_API_HOST_BIND=127.0.0.1`. `TestLoadPreservesLanDevCORSOrigin` may already pass because env parsing should preserve explicit origins.

- [ ] **Step 3: Change Docker-first compose example to LAN bind**

Modify `admin_back_go/deploy/docker-first/compose.env.example`:

```env
ADMIN_API_HOST_BIND=0.0.0.0
ADMIN_API_HOST_PORT=8080
```

- [ ] **Step 4: Update active local Docker-first env files if they exist**

Run this PowerShell snippet from `E:\admin_go`:

```powershell
$composeEnv = 'admin_back_go\deploy\docker-first\.env'
if (Test-Path $composeEnv) {
  (Get-Content $composeEnv) -replace '^ADMIN_API_HOST_BIND=.*$', 'ADMIN_API_HOST_BIND=0.0.0.0' | Set-Content -Encoding UTF8 $composeEnv
}

$runtimeEnv = 'admin_back_go\deploy\docker-first\admin-go.env'
if (Test-Path $runtimeEnv) {
  $content = Get-Content $runtimeEnv -Raw
  $lanCors = 'CORS_ALLOW_ORIGINS=http://localhost:5173,http://127.0.0.1:5173,http://192.168.5.20:5173'
  if ($content -match '(?m)^CORS_ALLOW_ORIGINS=') {
    $content = $content -replace '(?m)^CORS_ALLOW_ORIGINS=.*$', $lanCors
  } else {
    $content = $content.TrimEnd() + "`r`n" + $lanCors + "`r`n"
  }
  Set-Content -Encoding UTF8 $runtimeEnv $content
}
```

- [ ] **Step 5: Update LAN debugging docs**

In `admin_back_go/README.md` and `docs/deployment/local.md`, document this exact local phone-debugging shape:

```env
ADMIN_API_HOST_BIND=0.0.0.0
CORS_ALLOW_ORIGINS=http://localhost:5173,http://127.0.0.1:5173,http://192.168.5.20:5173
```

Also state that production CORS should use the deployed domain, while `192.168.5.20` is the current LAN dev origin.

- [ ] **Step 6: Run backend GREEN verification**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/config ./internal/middleware ./internal/server -count=1
```

Expected: all selected packages pass.

- [ ] **Step 7: Verify Compose config**

Run:

```powershell
cd E:\admin_go\admin_back_go\deploy\docker-first
docker compose --env-file compose.env.example config --quiet
```

Expected: exit code `0`.

---

### Task 2: Add frontend architecture RED test

**Files:**
- Create: `admin_app/tests/app-architecture.test.ts`

- [ ] **Step 1: Create the architecture test**

Create `admin_app/tests/app-architecture.test.ts` with:

```ts
import { existsSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, it } from 'vitest'

const srcRoot = join(process.cwd(), 'src')

function readProjectFile(path: string): string {
  return readFileSync(join(process.cwd(), path), 'utf-8')
}

describe('admin_app frontend architecture', () => {
  it('uses PC-admin-like top-level directory names', () => {
    for (const dir of ['api', 'components', 'enums', 'hooks', 'i18n', 'lib', 'platform', 'router', 'store', 'types', 'utils', 'views']) {
      expect(existsSync(join(srcRoot, dir)), `${dir} should exist`).toBe(true)
    }

    for (const dir of ['composables', 'config', 'constants', 'locales', 'pages', 'plugins', 'stores']) {
      expect(existsSync(join(srcRoot, dir)), `${dir} should be migrated away`).toBe(false)
    }
  })

  it('routes UniApp pages through src/views', () => {
    const pages = JSON.parse(readProjectFile('src/pages.json')) as {
      pages: Array<{ path: string }>
      tabBar: { list: Array<{ pagePath: string; text: string }> }
    }

    expect(pages.pages.map((page) => page.path)).toEqual([
      'views/login/index',
      'views/home/index',
      'views/mine/index',
      'views/profile/edit',
      'views/settings/index',
    ])
    expect(pages.tabBar.list).toEqual([
      { pagePath: 'views/home/index', text: '首页' },
      { pagePath: 'views/mine/index', text: '我的' },
    ])
  })

  it('does not import through old architecture aliases', () => {
    const forbidden = [
      '@/composables',
      '@/config',
      '@/constants',
      '@/locales',
      '@/plugins',
      '@/stores',
      '@/lib/platform',
      '@/lib/appUploadRuntime',
      '../src/composables',
      '../src/config',
      '../src/constants',
      '../src/locales',
      '../src/plugins',
      '../src/stores',
    ]

    const filesToCheck = [
      'src/App.vue',
      'src/main.ts',
      'src/router/guards.ts',
      'src/api/appAuth.ts',
      'src/api/appProfile.ts',
      'src/api/appUpload.ts',
      'src/lib/http/index.ts',
      'src/hooks/useSession.ts',
      'src/hooks/usePreferences.ts',
      'src/components/AppMediaUploader/src/AppMediaUploader.vue',
      'tests/app-backend-base.test.ts',
      'tests/app-preferences.test.ts',
      'tests/session-controller.test.ts',
      'tests/uview-runtime.test.ts',
    ]

    for (const file of filesToCheck) {
      const content = readProjectFile(file)
      for (const oldPath of forbidden) {
        expect(content, `${file} must not contain ${oldPath}`).not.toContain(oldPath)
      }
    }
  })
})
```

- [ ] **Step 2: Run the architecture test and verify RED**

Run:

```powershell
cd E:\admin_go\admin_app
npm run test:unit -- tests/app-architecture.test.ts
```

Expected before migration: FAIL because old directories still exist and `views/*` does not exist yet.

---

### Task 3: Move non-page architecture directories

**Files:**
- Move and modify all files listed in the frontend target map except `views`.

- [ ] **Step 1: Create target directories and move files**

Run from `E:\admin_go\admin_app`:

```powershell
New-Item -ItemType Directory -Force src\hooks,src\store,src\enums,src\i18n\locales,src\lib\http,src\lib\upload,src\platform\app,src\platform\uview | Out-Null
Move-Item src\composables\useSession.ts src\hooks\useSession.ts
Move-Item src\composables\usePreferences.ts src\hooks\usePreferences.ts
Move-Item src\stores\session.ts src\store\session.ts
Move-Item src\stores\preferences.ts src\store\preferences.ts
Move-Item src\constants\storage.ts src\enums\storage.ts
Move-Item src\locales\en-US.ts src\i18n\locales\en-US.ts
Move-Item src\locales\zh-CN.ts src\i18n\locales\zh-CN.ts
Move-Item src\i18n.ts src\i18n\index.ts
Move-Item src\config\env.ts src\lib\http\env.ts
Move-Item src\api\http.ts src\lib\http\index.ts
Move-Item src\lib\appUploadRuntime.ts src\lib\upload\appUploadRuntime.ts
Move-Item src\lib\platform\appMediaPermission.ts src\platform\app\appMediaPermission.ts
Move-Item src\plugins\uview-runtime.ts src\platform\uview\runtime.ts
Move-Item src\plugins\uview-luch-request-shim.ts src\platform\uview\luch-request-shim.ts
Remove-Item src\composables,src\stores,src\constants,src\locales,src\config,src\plugins -Force
if ((Get-ChildItem src\lib\platform -ErrorAction SilentlyContinue | Measure-Object).Count -eq 0) { Remove-Item src\lib\platform -Force }
```

- [ ] **Step 2: Update imports for moved files**

Apply these import replacements across `admin_app/src` and `admin_app/tests`:

```text
@/composables/useSession        -> @/hooks/useSession
@/composables/usePreferences    -> @/hooks/usePreferences
@/stores/session                -> @/store/session
@/stores/preferences            -> @/store/preferences
@/constants/storage             -> @/enums/storage
@/config/env                    -> @/lib/http/env
@/api/http                      -> @/lib/http
@/lib/appUploadRuntime          -> @/lib/upload/appUploadRuntime
@/lib/platform/appMediaPermission -> @/platform/app/appMediaPermission
@/plugins/uview-runtime         -> @/platform/uview/runtime
../src/config/env               -> ../src/lib/http/env
../src/stores/preferences       -> ../src/store/preferences
../src/stores/session           -> ../src/store/session
../src/plugins/uview-runtime    -> ../src/platform/uview/runtime
```

- [ ] **Step 3: Fix relative imports in moved i18n/http files**

`admin_app/src/i18n/index.ts` should import locales and types like this:

```ts
import { createI18n } from 'vue-i18n'

import enUS from './locales/en-US'
import zhCN from './locales/zh-CN'
import type { AppLocale } from '@/types/preferences'

export type { AppLocale }

export const i18n = createI18n({
  legacy: false,
  locale: 'zh-CN',
  fallbackLocale: 'zh-CN',
  messages: {
    'zh-CN': zhCN,
    'en-US': enUS,
  },
})
```

`admin_app/src/lib/http/index.ts` should import env/storage like this:

```ts
import { APP_API_BASE_URL } from './env'
import { ACCESS_TOKEN_STORAGE_KEY, APP_LOCALE_STORAGE_KEY } from '@/enums/storage'
```

- [ ] **Step 4: Update Vite uview shim alias**

In `admin_app/vite.config.ts`, update the shim path:

```ts
const uviewLuchRequestShim = fileURLToPath(
  new URL('./src/platform/uview/luch-request-shim.ts', import.meta.url)
)
```

- [ ] **Step 5: Run targeted TypeScript check**

Run:

```powershell
cd E:\admin_go\admin_app
npm run type-check
```

Expected after import migration: no TypeScript errors from moved modules.

---

### Task 4: Move pages to views and update UniApp routing

**Files:**
- Move: `admin_app/src/pages/**` -> `admin_app/src/views/**`
- Modify: `admin_app/src/pages.json`
- Modify: `admin_app/src/router/guards.ts`
- Modify: `admin_app/src/views/mine/index.vue`
- Modify tests: `admin_app/tests/app-routing.test.ts`, `admin_app/tests/app-profile-ui.test.ts`, `admin_app/tests/app-login-copy.test.ts`

- [ ] **Step 1: Move page files**

Run from `E:\admin_go\admin_app`:

```powershell
New-Item -ItemType Directory -Force src\views | Out-Null
Move-Item src\pages\login src\views\login
Move-Item src\pages\home src\views\home
Move-Item src\pages\mine src\views\mine
Move-Item src\pages\profile src\views\profile
Move-Item src\pages\settings src\views\settings
Remove-Item src\pages -Force
```

- [ ] **Step 2: Update `src/pages.json`**

Replace every `pages/` page path with `views/`:

```json
{
  "pages": [
    { "path": "views/login/index", "style": { "navigationStyle": "custom" } },
    { "path": "views/home/index", "style": { "navigationStyle": "custom" } },
    { "path": "views/mine/index", "style": { "navigationStyle": "custom" } },
    { "path": "views/profile/edit", "style": { "navigationStyle": "custom" } },
    { "path": "views/settings/index", "style": { "navigationStyle": "custom" } }
  ],
  "easycom": {
    "autoscan": true,
    "custom": {
      "^u-(.*)": "uview-plus/components/u-$1/u-$1.vue",
      "^up-(.*)": "uview-plus/components/u-$1/u-$1.vue"
    }
  },
  "tabBar": {
    "color": "#7F97AF",
    "selectedColor": "#2563EB",
    "backgroundColor": "#ffffff",
    "borderStyle": "white",
    "list": [
      { "pagePath": "views/home/index", "text": "首页" },
      { "pagePath": "views/mine/index", "text": "我的" }
    ]
  },
  "globalStyle": {
    "navigationBarTextStyle": "black",
    "navigationBarTitleText": "智澜 Admin App",
    "navigationBarBackgroundColor": "#ffffff",
    "backgroundColor": "#f6f8fc",
    "backgroundTextStyle": "dark"
  }
}
```

- [ ] **Step 3: Update router guard constants**

In `admin_app/src/router/guards.ts`:

```ts
export const LOGIN_PAGE = '/views/login/index'
export const HOME_PAGE = '/views/home/index'
```

- [ ] **Step 4: Update page navigation**

In `admin_app/src/views/mine/index.vue`:

```ts
uni.navigateTo({ url: '/views/profile/edit' })
uni.navigateTo({ url: '/views/settings/index' })
```

- [ ] **Step 5: Update path-based tests**

Replace test reads and expected route paths:

```text
src/pages/login/index.vue       -> src/views/login/index.vue
src/pages/home/index.vue        -> src/views/home/index.vue
src/pages/mine/index.vue        -> src/views/mine/index.vue
src/pages/profile/edit.vue      -> src/views/profile/edit.vue
src/pages/settings/index.vue    -> src/views/settings/index.vue
pages/login/index               -> views/login/index
pages/home/index                -> views/home/index
pages/mine/index                -> views/mine/index
pages/profile/edit              -> views/profile/edit
pages/settings/index            -> views/settings/index
/pages/profile/edit             -> /views/profile/edit
/pages/settings/index           -> /views/settings/index
```

- [ ] **Step 6: Run routing and architecture tests**

Run:

```powershell
cd E:\admin_go\admin_app
npm run test:unit -- tests/app-architecture.test.ts tests/app-routing.test.ts tests/app-profile-ui.test.ts tests/app-login-copy.test.ts
```

Expected: all selected tests pass.

---

### Task 5: Update frontend docs and status truth

**Files:**
- Modify: `admin_app/docs/architecture.md`
- Modify: `admin_app/docs/app-api-v1.md`
- Modify: `docs/status/current-status.md`

- [ ] **Step 1: Update `admin_app/docs/architecture.md`**

Replace old directory references with the new architecture map:

```text
src/views/login/index.vue       -> appAuthClient.loginConfig/captcha/sendCode
src/views/home/index.vue        -> requireAuthenticatedPage -> session.state.user
src/views/mine/index.vue        -> account hub + profile/settings entry
src/views/profile/edit.vue      -> appProfileClient.profile/updateProfile + AppMediaUploader
src/views/settings/index.vue    -> usePreferences language/theme + local cache management
src/lib/http/env.ts             -> default http://192.168.5.20:8080/api/app/v1, override by VITE_APP_API_BASE_URL
src/store/session.ts            -> injectable session controller
src/store/preferences.ts        -> injectable preferences controller
src/hooks/useSession.ts         -> runtime singleton
src/hooks/usePreferences.ts     -> runtime singleton
src/i18n/locales/*              -> visible copy
src/platform/*                  -> App/uview runtime boundary
```

- [ ] **Step 2: Update `admin_app/docs/app-api-v1.md`**

Update references from `src/config/env.ts` to `src/lib/http/env.ts`, and from `pages/profile/edit` to `views/profile/edit`.

- [ ] **Step 3: Update `docs/status/current-status.md`**

In the `app auth baseline` row, mention:

```text
admin_app 目录结构已对齐 PC admin 的 views/hooks/store/i18n/enums/platform/lib 分层；H5 默认直连 http://192.168.5.20:8080/api/app/v1，局域网真机调试要求 Docker-first 后端绑定 0.0.0.0 且 CORS_ALLOW_ORIGINS 包含 http://192.168.5.20:5173。
```

- [ ] **Step 4: Run docs grep guard**

Run:

```powershell
cd E:\admin_go
rg -n "src/(pages|composables|stores|locales|constants|config|plugins)|pages/(login|home|mine|profile|settings)" admin_app\docs docs\status\current-status.md
```

Expected: no stale old architecture references, except historical archived Superpowers docs if the command is intentionally widened later.

---

### Task 6: Full verification

**Files:**
- No new files; verify all touched code/docs.

- [ ] **Step 1: Run all admin_app unit tests**

Run:

```powershell
cd E:\admin_go\admin_app
npm run test:unit
```

Expected: all Vitest tests pass.

- [ ] **Step 2: Run TypeScript check**

Run:

```powershell
cd E:\admin_go\admin_app
npm run type-check
```

Expected: exit code `0`.

- [ ] **Step 3: Run H5 build**

Run:

```powershell
cd E:\admin_go\admin_app
npm run build:h5
```

Expected: exit code `0`, proving UniApp accepts `views/*` page paths for H5.

- [ ] **Step 4: Run App build when the local environment supports it**

Run:

```powershell
cd E:\admin_go\admin_app
npm run build:app
```

Expected if the local HBuilderX/UniApp App build toolchain is available: exit code `0`. If the environment lacks the App build dependency, record the exact toolchain error and keep H5 + typecheck as the verified gate for this session.

- [ ] **Step 5: Run backend tests**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/config ./internal/middleware ./internal/server -count=1
```

Expected: exit code `0`.

- [ ] **Step 6: Verify live LAN CORS when backend is running**

With backend listening on `192.168.5.20:8080`, run:

```powershell
curl.exe -i -X OPTIONS http://192.168.5.20:8080/api/app/v1/auth/login-config `
  -H "Origin: http://192.168.5.20:5173" `
  -H "Access-Control-Request-Method: GET"
```

Expected decisive headers:

```text
HTTP/1.1 204 No Content
Access-Control-Allow-Origin: http://192.168.5.20:5173
```

If backend is not running in this session, do not claim live CORS is verified; report it as pending for user-side functional testing.

- [ ] **Step 7: Run diff and governance checks**

Run from `E:\admin_go`:

```powershell
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected: both commands exit `0`.

- [ ] **Step 8: Final residue scan**

Run:

```powershell
cd E:\admin_go\admin_app
rg -n "@/(composables|stores|locales|config|constants|plugins|lib/platform)|@/lib/appUploadRuntime|src/(pages|composables|stores|locales|constants|config|plugins)|/pages/|pages/(login|home|mine|profile|settings)" src tests docs vite.config.ts
```

Expected: no matches for active code/tests/docs. If matches are in comments documenting the migration, either remove them or explicitly justify them in docs.

---

## Self-review checklist

- Spec coverage: frontend architecture rename, UniApp route migration, backend LAN bind/CORS, docs sync, and verification are all covered by tasks.
- Placeholder scan: no unfinished placeholder markers are used.
- Type consistency: moved imports use `hooks`, `store`, `enums`, `i18n`, `lib/http`, `lib/upload`, `platform/app`, `platform/uview`, and `views` consistently.
- Scope control: no UI rewrite, API contract change, DB change, or PC admin business copy is included.

