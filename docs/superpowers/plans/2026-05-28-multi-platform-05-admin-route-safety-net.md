# Admin Route Safety Net Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Freeze the currently working admin route surface before more architecture refactors, then create route group seams so later transport plans can run with fewer conflicts.

**Architecture:** This plan does not move business modules. It adds a route snapshot/golden test and extracts the existing `NewRouter` registration block into group functions that still call the current modules.

**Tech Stack:** Go, Gin `Engine.Routes()`, PowerShell, root governance checker.

---

## Scope Check

This plan executes:

```text
1. Add a route snapshot test for current admin/public admin-support routes.
2. Commit the generated route snapshot as testdata.
3. Extract current router module registrations into group seam files without behavior change.
4. Verify route snapshot before and after seam extraction.
5. Update active status docs to say this is a safety/seam plan, not transport completion.
```

This plan does **not** move module HTTP files, rename URLs, rename `internal/platform`, change frontend code, or change DB/schema/seed data.

## File Structure

- Create: `admin_back_go/internal/server/testdata/admin_routes_golden.txt`
- Modify: `admin_back_go/internal/server/router_test.go`
- Modify: `admin_back_go/internal/server/router.go`
- Create: `admin_back_go/internal/server/routes_auth.go`
- Create: `admin_back_go/internal/server/routes_admin_foundation.go`
- Create: `admin_back_go/internal/server/routes_admin_comms.go`
- Create: `admin_back_go/internal/server/routes_admin_ai.go`
- Create: `admin_back_go/internal/server/routes_admin_commerce_rbac.go`
- Create: `admin_back_go/internal/server/routes_admin_user.go`
- Modify: `docs/status/current-status.md`

## Task 1: Add route snapshot test and golden file

- [ ] **Step 1: Add imports to `router_test.go`**

Ensure `admin_back_go/internal/server/router_test.go` imports:

```go
import (
	"os"
	"path/filepath"
	"sort"
)
```

Do not duplicate imports already present.

- [ ] **Step 2: Add the snapshot test**

Append this test near the existing router route tests:

```go
func TestAdminRouteSnapshot(t *testing.T) {
	router := NewRouter(Dependencies{Logger: slog.New(slog.NewTextHandler(io.Discard, nil))})

	var routes []string
	for _, route := range router.Routes() {
		path := route.Path
		if strings.HasPrefix(path, "/api/admin/v1/") ||
			strings.HasPrefix(path, "/api/payment/callbacks/") ||
			path == "/health" || path == "/ready" {
			routes = append(routes, route.Method+" "+path)
		}
	}
	sort.Strings(routes)

	goldenPath := filepath.Join("testdata", "admin_routes_golden.txt")
	if os.Getenv("UPDATE_ADMIN_ROUTE_SNAPSHOT") == "1" {
		if err := os.MkdirAll(filepath.Dir(goldenPath), 0o755); err != nil {
			t.Fatalf("create testdata: %v", err)
		}
		if err := os.WriteFile(goldenPath, []byte(strings.Join(routes, "\n")+"\n"), 0o644); err != nil {
			t.Fatalf("write route snapshot: %v", err)
		}
	}

	wantBytes, err := os.ReadFile(goldenPath)
	if err != nil {
		t.Fatalf("read route snapshot: %v", err)
	}
	want := strings.TrimSpace(string(wantBytes))
	got := strings.Join(routes, "\n")
	if got != want {
		t.Fatalf("admin route snapshot mismatch\n--- got ---\n%s\n--- want ---\n%s", got, want)
	}
}
```

- [ ] **Step 3: Generate and verify the golden file**

```powershell
cd E:\admin_go\admin_back_go
$env:UPDATE_ADMIN_ROUTE_SNAPSHOT='1'
go test ./internal/server -run TestAdminRouteSnapshot -count=1
Remove-Item Env:\UPDATE_ADMIN_ROUTE_SNAPSHOT
go test ./internal/server -run TestAdminRouteSnapshot -count=1
```

Expected: both runs PASS and `internal/server/testdata/admin_routes_golden.txt` exists.

## Task 2: Extract route group seams without changing behavior

- [ ] **Step 1: Create group files**

Move current module registration calls from `NewRouter` into these functions while preserving the existing call order inside each group:

```go
func registerAuthRoutes(router *gin.Engine, deps Dependencies)
func registerAdminFoundationRoutes(router *gin.Engine, deps Dependencies)
func registerAdminCommsRoutes(router *gin.Engine, deps Dependencies)
func registerAdminAIRoutes(router *gin.Engine, deps Dependencies)
func registerAdminCommerceRBACRoutes(router *gin.Engine, deps Dependencies)
func registerAdminUserRoutes(router *gin.Engine, deps Dependencies)
```

Ownership:

```text
routes_auth.go: authadmin + authapp only
routes_admin_foundation.go: system, clientversion, exporttask, crontask, operationlog, queuemonitor, systemsetting, systemlog, realtime
routes_admin_comms.go: mail, sms, notification, notificationtask, uploadconfig, uploadtoken
routes_admin_ai.go: aiprovider, aiagent, aiimage, aiknowledge, aiconversation, aimessage, airun, aichat, aitool
routes_admin_commerce_rbac.go: payment, wallet, permission, role, authplatform
routes_admin_user.go: user, userquickentry
```

- [ ] **Step 2: Replace `NewRouter` registration block**

After middleware setup, `NewRouter` should call:

```go
registerAuthRoutes(router, deps)
registerAdminFoundationRoutes(router, deps)
registerAdminAIRoutes(router, deps)
registerAdminUserRoutes(router, deps)
registerAdminCommsRoutes(router, deps)
registerAdminCommerceRBACRoutes(router, deps)
```

Ensure `system.RegisterRoutes(router, deps.Readiness)` is registered exactly once, either inside foundation or directly in `NewRouter`.

- [ ] **Step 3: Verify snapshot unchanged**

```powershell
cd E:\admin_go\admin_back_go
gofmt -w .\internal\server\router.go .\internal\server\routes_*.go .\internal\server\router_test.go
go test ./internal/server -run TestAdminRouteSnapshot -count=1
go test ./internal/server ./internal/architecture -count=1
```

Expected: PASS. If snapshot fails, restore the exact old registration behavior before continuing.

## Task 3: Full safety verification

```powershell
cd E:\admin_go\admin_back_go
go test ./... -count=1

cd E:\admin_go\admin_front_ts
npm run typecheck
npm run test -- tests/shared/user/users-api.test.ts

cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected: all PASS.

## Task 4: Docs and commits

- [ ] **Step 1: Update `docs/status/current-status.md`**

Add:

```markdown
### 2026-05-28 admin route safety seam

- Added an admin route snapshot gate before continuing transport refactors.
- Split server route registration into owned group seams so later transport-shell plans can run in parallel with less `router.go` conflict.
- This does not mean all modules have moved to `transport/admin`; it only protects the admin route surface before the parallel wave.
```

- [ ] **Step 2: Commit**

```powershell
cd E:\admin_go\admin_back_go
git add internal/server/router.go internal/server/router_test.go internal/server/routes_*.go internal/server/testdata/admin_routes_golden.txt
git commit -m "test: protect admin route surface before transport sweep"

cd E:\admin_go
git add docs/status/current-status.md
git commit -m "docs: record admin route safety seam"
```

Expected: backend commit contains only server test/seam files; root commit contains only status docs.

## Plan self-review

- Admin preservation: route snapshot blocks accidental admin URL deletion/rename.
- Parallelism: later plans edit separate `routes_admin_*.go` files instead of one `router.go` block.
- Docs honesty: status entry says transport migration is not complete.
