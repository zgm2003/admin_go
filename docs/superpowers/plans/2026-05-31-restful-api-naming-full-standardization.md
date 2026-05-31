# RESTful API Naming Full Standardization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the whole Go/Vue active system comply with the accepted RESTful API naming standard, with no CRUD `init/add/edit/del/status` wrappers or non-bootstrap `Init` page-dictionary handler/service names left in touched runtime code.

**Architecture:** HTTP routes are already mostly correct, so do not churn URLs. Standardize code-facing names at the boundary: frontend API wrappers expose only `pageInit/create/update/changeStatus/deleteOne/deleteBatch`; backend page dictionary handlers/services are renamed to `PageInit` except the real bootstrap `users/init`. Add guard tests first so the bad names cannot come back.

**Tech Stack:** Go 1.26 + Gin; Vue 3 + TypeScript + Vitest; root governance scripts.

---

## Linus 三问

1. 真问题吗？是。项目未上线，继续保留 CRUD `init/add/edit/del/status` 会让新代码抄旧垃圾。
2. 更简单的做法？有。先上 guard，再按模块机械迁移，不改 HTTP contract，不碰数据库。
3. 会破坏什么？可能破坏前端调用方和 Go handler tests，所以每一批都先写失败测试、再改调用方、再跑 targeted tests。

## Non-negotiable target state

- Backend route URL：不得出现 CRUD `/list /add /edit /del`。
- Backend page dictionary：除 `GET /api/admin/v1/users/init` bootstrap 外，handler/service 方法统一 `PageInit`。
- Frontend API wrapper：`admin_front_ts/src/api/**/*.ts` 不再暴露 CRUD `init/add/edit/del/status`。
- Frontend call sites：页面、composable、tests 不再调用 `Api.init/add/edit/del/status`。
- Public CRUD hook：`useCrudTable` 只接受标准方法名；不再有 `del/status` legacy fallback。
- Business commands keep explicit verbs when they are not CRUD, e.g. `login/logout/send-code/test/cancel/pay/stats/statusCount/forceUpdate/updateJson`.

## Current evidence to preserve

- P0 backend action URL scan found no `/list /add /edit /del` route violations.
- `admin_back_go/internal/module/user/transport/admin/route.go` has `/init` bootstrap; keep it.
- P1 frontend drift remains in API wrappers and call sites.
- P2 backend drift remains in many page-dictionary handlers/services named `Init`.

## File structure map

### Root docs and guards

- Read: `docs/superpowers/specs/2026-05-30-restful-api-naming-audit-design.md`
- Modify: `docs/status/current-status.md` only after runtime verification passes.
- Modify: `docs/contracts/admin-api-v1.md` only if contract text still mentions temporary aliases as allowed current behavior.

### Frontend guard tests

- Create: `admin_front_ts/tests/shared/api/restful-naming-guard.test.ts`
- Modify: `admin_front_ts/tests/shared/table/useCrudTable.test.ts`

### Frontend runtime files

- Modify: `admin_front_ts/src/hooks/useCrudTable.ts`
- Modify: all `admin_front_ts/src/api/**/*.ts` exposing CRUD `init/add/edit/del/status`.
- Modify: frontend call sites reported by this command:

```powershell
cd E:\admin_go\admin_front_ts
rg -n "\.(init|add|edit|del|status)\(" src -g "*.ts" -g "*.vue"
```

### Backend guard tests

- Create: `admin_back_go/internal/architecture/restful_naming_guard_test.go`

### Backend runtime files

- Modify: backend page-dictionary modules found by:

```powershell
cd E:\admin_go\admin_back_go
rg -n "GET\(\"/page-init\", handler\.(Init|.*Init)\)|func \(.*\*Handler.*\) Init\(|func \(.*\*Service.*\) Init\(" internal/module
```

Do not rename `internal/module/user` bootstrap `Init` unless it is split so `users/init` remains bootstrap and `users/page-init` remains `PageInit`.

---

## Task 0: Baseline and exact inventory

**Files:** none.

- [ ] **Step 1: Verify clean boundaries**

Run:

```powershell
cd E:\admin_go
git status --short
cd E:\admin_go\admin_back_go
git status --short
cd E:\admin_go\admin_front_ts
git status --short
```

Expected: no unrelated dirty files. If unrelated dirty files exist, stop and report before editing.

- [ ] **Step 2: Capture frontend legacy inventory**

Run:

```powershell
cd E:\admin_go\admin_front_ts
rg -n "\b(init|add|edit|del|status)\s*:|\bconst\s+(init|add|edit|del|status)\s*=|\.(init|add|edit|del|status)\(" src tests -g "*.ts" -g "*.vue"
```

Expected before implementation: matches exist. Save the output in the task notes; it is the RED baseline.

- [ ] **Step 3: Capture backend naming inventory**

Run:

```powershell
cd E:\admin_go\admin_back_go
rg -n "GET\(\"/page-init\", handler\.(Init|[A-Za-z]+Init)\)|func \(.*\*(Handler|Service).*\) Init\(" internal/module
```

Expected before implementation: matches exist, except user bootstrap must be reviewed separately.

---

## Task 1: Add frontend RESTful naming guard test

**Files:**

- Create: `admin_front_ts/tests/shared/api/restful-naming-guard.test.ts`

- [ ] **Step 1: Write failing guard test**

Create `admin_front_ts/tests/shared/api/restful-naming-guard.test.ts`:

```ts
import { readdirSync, readFileSync, statSync } from 'node:fs'
import { join, relative } from 'node:path'
import { describe, expect, it } from 'vitest'

const apiRoot = join(process.cwd(), 'src', 'api')

function walkTsFiles(dir: string): string[] {
  return readdirSync(dir).flatMap((entry) => {
    const path = join(dir, entry)
    if (statSync(path).isDirectory()) return walkTsFiles(path)
    return path.endsWith('.ts') ? [path] : []
  })
}

function read(path: string): string {
  return readFileSync(path, 'utf8')
}

describe('RESTful frontend API naming guard', () => {
  it('does not expose legacy CRUD wrapper names in src/api', () => {
    const violations = walkTsFiles(apiRoot).flatMap((file) => {
      const source = read(file)
      const matches = [...source.matchAll(/(^|\n)\s*(init|add|edit|del|status)\s*:/g)]
      return matches.map((match) => `${relative(process.cwd(), file)}:${match[2]}`)
    })

    expect(violations).toEqual([])
  })
})
```

- [ ] **Step 2: Verify RED**

Run:

```powershell
cd E:\admin_go\admin_front_ts
npm test -- tests/shared/api/restful-naming-guard.test.ts
```

Expected: FAIL listing current `init/add/edit/del/status` wrapper exports.

---

## Task 2: Standardize `useCrudTable`

**Files:**

- Modify: `admin_front_ts/src/hooks/useCrudTable.ts`
- Modify: `admin_front_ts/tests/shared/table/useCrudTable.test.ts`

- [ ] **Step 1: Write failing tests for no legacy fallback**

In `tests/shared/table/useCrudTable.test.ts`, add/adjust assertions so the API type and behavior require:

```ts
const api = {
  list,
  deleteOne,
  deleteBatch,
  changeStatus,
}
```

and no test object passes `del` or `status`.

- [ ] **Step 2: Verify RED**

Run:

```powershell
cd E:\admin_go\admin_front_ts
npm test -- tests/shared/table/useCrudTable.test.ts
```

Expected: FAIL while `useCrudTable` still references `api.del` or `api.status`.

- [ ] **Step 3: Remove legacy fallback from implementation**

Change `src/hooks/useCrudTable.ts` API shape to only allow:

```ts
interface CrudApi<Id extends string | number = number> {
  list(params: ListParams): Promise<ListResponse>
  deleteOne?(params: { id: Id }): Promise<unknown>
  deleteBatch?(params: { ids: Id[] }): Promise<unknown>
  changeStatus?(params: { id: Id; status: number }): Promise<unknown>
}
```

Implementation rules:

```ts
confirmDel(row) uses api.deleteOne only.
batchDel() uses api.deleteBatch only.
toggleStatus(row) uses api.changeStatus only.
warning messages mention only standard names.
```

- [ ] **Step 4: Verify GREEN**

Run:

```powershell
cd E:\admin_go\admin_front_ts
npm test -- tests/shared/table/useCrudTable.test.ts
```

Expected: PASS.

---

## Task 3: Standardize frontend API wrappers and call sites

**Files:**

- Modify: `admin_front_ts/src/api/**/*.ts`
- Modify: call sites under `admin_front_ts/src/views/**/*.ts`, `admin_front_ts/src/views/**/*.vue`, and relevant tests.

- [ ] **Step 1: Rename API object properties mechanically**

For every CRUD wrapper:

```text
init -> pageInit
add -> create
edit -> update
status -> changeStatus
del -> deleteOne or deleteBatch depending on signature
```

Rules:

```text
If the old del accepted { id: Id | Id[] }, split into deleteOne({ id }) and deleteBatch({ ids }).
If the backend only supports single delete, expose only deleteOne and update the UI to call single delete.
If the method is a business command, keep business name: pay/test/cancel/statusCount/updateJson/forceUpdate.
```

- [ ] **Step 2: Update direct call sites**

Replace direct calls:

```text
Api.init()       -> Api.pageInit()
Api.add(payload) -> Api.create(payload)
Api.edit(payload)-> Api.update(payload)
Api.status(...)  -> Api.changeStatus(...)
Api.del(...)     -> Api.deleteOne(...) or Api.deleteBatch(...)
```

Known current direct call sites include:

```text
src/views/Main/user/usersLoginLog/index.vue
src/views/Main/user/userManager/components/UserList/index.vue
src/views/Main/payment/config/composables/usePaymentConfigPage.ts
src/views/Main/payment/recharge/composables/usePaymentRechargePage.ts
src/views/Main/system/clientVersion/index.vue
```

- [ ] **Step 3: Update module API tests**

For each touched API test, replace expectations like:

```ts
expect(source).toContain('init: pageInit')
expect(source).toContain('add: create')
expect(source).toContain('edit: update')
expect(source).toContain('status: changeStatus')
expect(source).toContain('del,')
```

with expectations for standard exports only:

```ts
expect(source).toContain('pageInit')
expect(source).toContain('create')
expect(source).toContain('update')
expect(source).toContain('changeStatus')
expect(source).toContain('deleteOne')
expect(source).not.toContain('init: pageInit')
expect(source).not.toContain('add: create')
expect(source).not.toContain('edit: update')
expect(source).not.toContain('status: changeStatus')
expect(source).not.toContain('del,')
```

- [ ] **Step 4: Verify frontend guard GREEN**

Run:

```powershell
cd E:\admin_go\admin_front_ts
npm test -- tests/shared/api/restful-naming-guard.test.ts
```

Expected: PASS.

- [ ] **Step 5: Verify no direct old calls remain**

Run:

```powershell
cd E:\admin_go\admin_front_ts
rg -n "\.(init|add|edit|del|status)\(" src tests -g "*.ts" -g "*.vue"
```

Expected: no CRUD API call matches. Matches in non-API contexts such as `Set.add`, CSS class add, store init, i18n keys, or component event names must be reviewed and ignored only if clearly not an API wrapper call.

- [ ] **Step 6: Run targeted frontend tests**

Run:

```powershell
cd E:\admin_go\admin_front_ts
npm test -- tests/shared/api/restful-naming-guard.test.ts tests/shared/table/useCrudTable.test.ts tests/shared/payment/payment-config-api.test.ts tests/shared/payment/payment-config-page.test.ts tests/shared/payment/payment-recharge-api.test.ts tests/shared/payment/payment-recharge-page.test.ts tests/shared/system/cron-task-api.test.ts tests/shared/system/export-task-api.test.ts tests/shared/system/operation-log-api.test.ts tests/shared/system/upload-config-api.test.ts tests/shared/permission/auth-platform-api.test.ts tests/shared/permission/role-api.test.ts tests/shared/user
```

Expected: PASS. If `tests/shared/user` is not a valid path, run the exact user tests found by `Get-ChildItem tests/shared -Recurse -Filter '*user*test.ts'`.

---

## Task 4: Add backend RESTful naming guard test

**Files:**

- Create: `admin_back_go/internal/architecture/restful_naming_guard_test.go`

- [ ] **Step 1: Write failing backend guard**

Create `internal/architecture/restful_naming_guard_test.go`:

```go
package architecture

import (
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"
)

func TestRESTfulRouteNamingGuard(t *testing.T) {
	root := filepath.Join("..", "module")
	forbiddenRoute := regexp.MustCompile(`\.(GET|POST|PUT|PATCH|DELETE)\("[^"]*/(list|add|edit|del)(/|"|\?)`)
	pageInitWithInitHandler := regexp.MustCompile(`\.GET\("/page-init", handler\.(Init|[A-Za-z]+Init)\)`)

	var violations []string
	_ = filepath.WalkDir(root, func(path string, d os.DirEntry, err error) error {
		if err != nil || d.IsDir() || !strings.HasSuffix(path, ".go") {
			return nil
		}
		b, readErr := os.ReadFile(path)
		if readErr != nil {
			violations = append(violations, path+": read failed")
			return nil
		}
		source := string(b)
		if forbiddenRoute.MatchString(source) {
			violations = append(violations, path+": contains CRUD action route")
		}
		if pageInitWithInitHandler.MatchString(source) {
			violations = append(violations, path+": /page-init must bind handler.PageInit")
		}
		return nil
	})

	if len(violations) > 0 {
		t.Fatalf("RESTful naming violations:\n%s", strings.Join(violations, "\n"))
	}
}
```

- [ ] **Step 2: Verify RED**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture -run TestRESTfulRouteNamingGuard -count=1
```

Expected: FAIL while `/page-init` binds `handler.Init` or `handler.*Init`.

---

## Task 5: Rename backend page dictionary handlers/services

**Files:**

- Modify: every backend module where `/page-init` binds `handler.Init` or `handler.*Init`.
- Modify: related handler tests and fake service interfaces.

- [ ] **Step 1: Rename handler methods**

For each page dictionary endpoint:

```go
func (h *Handler) Init(c *gin.Context) { ... }
```

becomes:

```go
func (h *Handler) PageInit(c *gin.Context) { ... }
```

Route binding becomes:

```go
group.GET("/page-init", handler.PageInit)
```

Allowed exception:

```go
users.GET("/init", handler.Init) // bootstrap only
```

- [ ] **Step 2: Rename service methods**

For page dictionary services:

```go
func (s *Service) Init(ctx context.Context) (*InitResponse, *apperror.Error)
```

becomes:

```go
func (s *Service) PageInit(ctx context.Context) (*PageInitResponse, *apperror.Error)
```

If renaming response structs is too large for one module, method rename is mandatory first; response type rename can be done in the same module only when tests stay focused. Do not leave route bound to `Init`.

- [ ] **Step 3: Update interfaces and fakes**

Any handler-local interface like:

```go
type service interface {
	Init(ctx context.Context) (*module.InitResponse, *apperror.Error)
}
```

must become:

```go
type service interface {
	PageInit(ctx context.Context) (*module.PageInitResponse, *apperror.Error)
}
```

Update test fakes in the same package.

- [ ] **Step 4: Verify backend guard GREEN**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture -run TestRESTfulRouteNamingGuard -count=1
```

Expected: PASS.

- [ ] **Step 5: Run targeted backend module tests**

Run focused tests for changed packages. Example shape:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/ai/agent/... ./internal/module/ai/provider/... ./internal/module/ai/run/... ./internal/module/ai/tool/... ./internal/module/auth_platform/... ./internal/module/clientversion/... ./internal/module/crontask/... ./internal/module/notification/... ./internal/module/operationlog/... ./internal/module/permission/... ./internal/module/role/... ./internal/module/systemlog/... ./internal/module/systemsetting/... ./internal/module/uploadconfig/... -count=1 -p=1
```

Expected: PASS.

---

## Task 6: Contract/docs cleanup

**Files:**

- Modify: `docs/contracts/admin-api-v1.md`
- Modify: `docs/status/current-status.md`
- Optional modify: `docs/superpowers/reviews/*.md` only if creating a final review note.

- [ ] **Step 1: Remove migration-alias wording from current contract**

In `docs/contracts/admin-api-v1.md`, replace current-alias wording with final-state wording:

```text
Frontend API wrapper 使用 list/detail/create/update/changeStatus/deleteOne/deleteBatch/pageInit；不得新增或保留 CRUD init/add/edit/del/status wrapper。
```

Keep bootstrap exception:

```text
GET /api/admin/v1/users/init only serves current-user bootstrap.
```

- [ ] **Step 2: Update current status only after tests pass**

In `docs/status/current-status.md`, add a latest pointer only after frontend and backend checks are green:

```text
2026-05-31 RESTful API naming full standardization: frontend CRUD wrappers and call sites use standard names only; backend page dictionary handlers bind PageInit; users/init remains the bootstrap exception.
```

- [ ] **Step 3: Verify docs governance**

Run:

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected: PASS.

---

## Task 7: Final verification gate

**Files:** none.

- [ ] **Step 1: Frontend type and targeted tests**

Run:

```powershell
cd E:\admin_go\admin_front_ts
npm test -- tests/shared/api/restful-naming-guard.test.ts tests/shared/table/useCrudTable.test.ts
npm run typecheck
```

Expected: PASS.

- [ ] **Step 2: Backend guard and targeted tests**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture -run TestRESTfulRouteNamingGuard -count=1
go test ./internal/module/... -count=1 -p=1
```

Expected: PASS. If this is too broad or slow on Windows, run the exact changed module package list from Task 5 and state the scope.

- [ ] **Step 3: Final grep checks**

Run:

```powershell
cd E:\admin_go\admin_front_ts
rg -n "\b(init|add|edit|del|status)\s*:|\bconst\s+(init|add|edit|del|status)\s*=" src/api tests/shared -g "*.ts"
rg -n "\.(init|add|edit|del|status)\(" src tests -g "*.ts" -g "*.vue"

cd E:\admin_go\admin_back_go
rg -n "GET\(\"/page-init\", handler\.(Init|[A-Za-z]+Init)\)|func \(.*\*(Handler|Service).*\) Init\(" internal/module
```

Expected:

```text
Frontend API wrapper grep: no CRUD wrapper declarations.
Frontend call grep: no API CRUD call sites; non-API matches must be explicitly listed if any.
Backend grep: no page-init Init handlers/services; user bootstrap Init may remain only under user module.
```

- [ ] **Step 4: Root governance**

Run:

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected: PASS.

---

## Execution notes

- Do not batch rename with blind regex over the whole repo. Use grep inventory, edit module-by-module, and run tests after each batch.
- Do not touch DB, permissions, i18n text, menus, or route URLs unless a test proves the naming cleanup requires it.
- Do not convert `users/init`; it is the bootstrap exception.
- Do not rename business commands into CRUD names.
- If a module has no batch delete endpoint, do not invent one. Expose only the operation the backend supports.

## Self-review

Spec coverage:

- Standard route naming: Task 4 guard.
- Frontend standard names: Tasks 1-3 guard and migration.
- Handler/service `PageInit`: Tasks 4-5.
- No big-bang URL churn: explicit non-goal in architecture and notes.
- Verification: Tasks 6-7.

Placeholder scan: no TBD / TODO / implement later instructions are used as work items.

Type consistency: frontend method names are consistently `pageInit/create/update/changeStatus/deleteOne/deleteBatch`; backend page dictionary method is consistently `PageInit`; bootstrap remains `Init` only for `users/init`.
