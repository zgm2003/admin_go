# Wallet Payment Aggregation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task. This is a serial boundary refactor. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the standalone wallet module under the payment capability at `internal/module/payment/wallet` while preserving all admin wallet/payment behavior.

**Architecture:** Wallet belongs to payment for this Phase 2 boundary because recharge credits and consume debits share wallet tables and business flow. This slice is a directory/package-boundary refactor only: keep `package wallet`, keep admin routes under `/api/admin/v1/wallet*`, and keep DB tables, payloads, permission codes, i18n keys, cron task types, and payment callback/finalizer behavior unchanged.

**Tech Stack:** Go, Gin, GORM, backend architecture tests, admin route snapshot, Vue/Vitest contract checks, root governance checker.

---

## Current verified baseline

Before executing, verify both repos are synced:

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

Current runtime truth before this plan:

```text
internal/module/payment              # payment config, recharge, order, callback, finalizer
internal/module/wallet               # wallet summary, transactions, admin wallet users, ledger, consume
internal/module/payment/wallet_model.go
internal/module/payment/wallet_repository.go
```

Target runtime truth after this plan:

```text
internal/module/payment              # payment capability root remains
internal/module/payment/wallet       # moved wallet admin/current-user service under payment capability
internal/module/payment/wallet_model.go
internal/module/payment/wallet_repository.go
```

Do not merge `payment/wallet_model.go` or `payment/wallet_repository.go` into `payment/wallet` in this slice. Those files are payment recharge/finalizer internals and are outside this mechanical move.

## Assigned worktree

```text
E:\admin_go_parallel\p16-wallet-payment
branch: work/p16-wallet-payment
```

Create it from backend master:

```powershell
cd E:\admin_go\admin_back_go
git fetch origin
git switch master
git pull --ff-only
git worktree add E:\admin_go_parallel\p16-wallet-payment -b work/p16-wallet-payment master
cd E:\admin_go_parallel\p16-wallet-payment
```

## Files

Backend worker owns:

- Move directory: `internal/module/wallet` -> `internal/module/payment/wallet`
- Create: `internal/architecture/payment_wallet_aggregation_test.go`
- Modify: `internal/architecture/multiplatform_boundary_test.go`
- Modify: `internal/bootstrap/app.go`
- Modify: `internal/server/router.go`
- Modify: `internal/server/routes_admin_commerce_rbac.go`
- Modify moved files under `internal/module/payment/wallet/**` only for import path updates
- Modify backend docs only if active backend docs directly name `internal/module/wallet`: `docs/architecture.md`

Root coordinator owns after backend merge/push:

- Modify: `E:\admin_go\docs/status/current-status.md` for key-fact summary
- Modify: `E:\admin_go\docs/status/module-matrix.md` for commerce/RBAC and wallet per-module sections
- Modify: `E:\admin_go\docs/architecture/00-platform-and-module-rules.md`
- Modify: `E:\admin_go\docs/superpowers/plans/2026-05-28-multi-platform-phase2-execution-map.md`

Do not modify frontend source in this plan. Frontend tests are contract checks only.

## Non-negotiable behavior

```text
No DB schema changes.
No frontend source changes.
No admin URL changes.
No permission code changes.
No operation log rule changes.
No i18n key/text changes.
Keep user_wallets and wallet_transactions table names and semantics.
Keep /api/admin/v1/wallet/summary.
Keep /api/admin/v1/wallet/transactions*.
Keep /api/admin/v1/wallet/users*.
Keep /api/admin/v1/wallet/ledger*.
Keep POST /api/admin/v1/wallet/consumptions guarded by wallet_consume_add.
Keep payment callback, recharge finalizer, payment cron, Alipay behavior, and wallet credit idempotency unchanged.
Keep package identifier package wallet for the moved wallet subpackage.
```

## Task 1: Add RED architecture guard

**Files:**

- Create: `internal/architecture/payment_wallet_aggregation_test.go`

- [x] **Step 1: Create the guard test**

Write this exact file:

```go
package architecture

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestWalletOwnedByPaymentModule(t *testing.T) {
	root := backendRoot(t)

	mustNotExist(t, root, "internal/module/wallet")
	mustExist(t, root, "internal/module/payment/wallet/service.go")
	mustExist(t, root, "internal/module/payment/wallet/repository.go")
	mustExist(t, root, "internal/module/payment/wallet/transport/admin/route.go")
}

func TestNoImportsOfOldWalletModulePath(t *testing.T) {
	root := backendRoot(t)
	banned := "admin_back_go/internal/module/wallet"
	var offenders []string

	for _, base := range []string{"internal", "cmd"} {
		err := filepath.WalkDir(filepath.Join(root, base), func(path string, entry os.DirEntry, walkErr error) error {
			if walkErr != nil {
				return walkErr
			}
			if entry.IsDir() || filepath.Ext(path) != ".go" {
				return nil
			}
			if filepath.ToSlash(path) == filepath.ToSlash(filepath.Join(root, "internal/architecture/payment_wallet_aggregation_test.go")) {
				return nil
			}
			body, err := os.ReadFile(path)
			if err != nil {
				return err
			}
			if strings.Contains(string(body), banned) {
				rel, _ := filepath.Rel(root, path)
				offenders = append(offenders, filepath.ToSlash(rel))
			}
			return nil
		})
		if err != nil {
			t.Fatalf("walk %s go files: %v", base, err)
		}
	}

	if len(offenders) > 0 {
		t.Fatalf("old wallet module imports remain:\n  %s", strings.Join(offenders, "\n  "))
	}
}
```

- [x] **Step 2: Run RED**

```powershell
cd E:\admin_go_parallel\p16-wallet-payment
go test ./internal/architecture -run TestWalletOwnedByPaymentModule -count=1
```

Expected before moving directories:

```text
FAIL
expected internal/module/wallet to be removed
```

## Task 2: Move wallet directory with history

**Files:**

- Move: `internal/module/wallet` -> `internal/module/payment/wallet`

- [x] **Step 1: Move the directory**

```powershell
cd E:\admin_go_parallel\p16-wallet-payment
New-Item -ItemType Directory -Force .\internal\module\payment | Out-Null
git mv .\internal\module\wallet .\internal\module\payment\wallet
```

- [x] **Step 2: Confirm package name stayed stable**

```powershell
cd E:\admin_go_parallel\p16-wallet-payment
Get-ChildItem .\internal\module\payment\wallet -Recurse -Filter *.go | ForEach-Object {
  Select-String -Path $_.FullName -Pattern '^package wallet$'
}
```

Expected: moved package files still report `package wallet`; no file reports `package payment`.

## Task 3: Update imports and route seams

**Files:**

- Modify: `internal/bootstrap/app.go`
- Modify: `internal/server/router.go`
- Modify: `internal/server/routes_admin_commerce_rbac.go`
- Modify: `internal/module/payment/wallet/transport/admin/handler.go`
- Modify: `internal/module/payment/wallet/transport/admin/handler_test.go`

- [x] **Step 1: Replace old import paths**

```powershell
cd E:\admin_go_parallel\p16-wallet-payment
rg -l 'admin_back_go/internal/module/wallet' internal cmd | ForEach-Object {
  (Get-Content $_ -Raw).Replace('admin_back_go/internal/module/wallet', 'admin_back_go/internal/module/payment/wallet') | Set-Content -Encoding UTF8 $_
}
```

- [x] **Step 2: Verify key imports are readable aliases**

```powershell
cd E:\admin_go_parallel\p16-wallet-payment
Select-String -Path .\internal\bootstrap\app.go -Pattern 'walletmodule "admin_back_go/internal/module/payment/wallet"'
Select-String -Path .\internal\server\router.go -Pattern 'walletadmin "admin_back_go/internal/module/payment/wallet/transport/admin"'
Select-String -Path .\internal\server\routes_admin_commerce_rbac.go -Pattern 'walletadmin "admin_back_go/internal/module/payment/wallet/transport/admin"'
Select-String -Path .\internal\module\payment\wallet\transport\admin\handler.go -Pattern 'walletmodule "admin_back_go/internal/module/payment/wallet"'
```

Expected: all four commands print one matching line.

## Task 4: Update architecture boundary test

**Files:**

- Modify: `internal/architecture/multiplatform_boundary_test.go`

- [x] **Step 1: Replace `TestCommerceRBACAdminTransportShells` with this exact function**

```go
func TestCommerceRBACAdminTransportShells(t *testing.T) {
	root := backendRoot(t)
	for _, module := range []string{
		"auth_platform",
		"permission",
		"role",
		"payment",
	} {
		moduleRoot := "internal/module/" + module + "/"
		mustExist(t, root, moduleRoot+"transport/admin/route.go")
		mustNotExist(t, root, moduleRoot+"route.go")
		mustNotExist(t, root, moduleRoot+"handler.go")
	}

	walletRoot := "internal/module/payment/wallet/"
	mustExist(t, root, walletRoot+"transport/admin/route.go")
	mustNotExist(t, root, walletRoot+"route.go")
	mustNotExist(t, root, walletRoot+"handler.go")
}
```

- [x] **Step 2: Format architecture tests**

```powershell
cd E:\admin_go_parallel\p16-wallet-payment
gofmt -w .\internal\architecture\payment_wallet_aggregation_test.go .\internal\architecture\multiplatform_boundary_test.go
```

## Task 5: Verify moved wallet package and contracts

**Files:**

- Test: `internal/module/payment/wallet/...`
- Test: `internal/module/payment/...`
- Test: `internal/server`
- Test: `internal/bootstrap`

- [x] **Step 1: Format touched Go files**

```powershell
cd E:\admin_go_parallel\p16-wallet-payment
gofmt -w .\internal\module\payment\wallet .\internal\bootstrap .\internal\server .\internal\architecture
```

- [x] **Step 2: Confirm old directory and imports are gone**

```powershell
cd E:\admin_go_parallel\p16-wallet-payment
if (Test-Path .\internal\module\wallet) { throw 'internal/module/wallet still exists' }
rg -n 'admin_back_go/internal/module/wallet' internal cmd -g '!internal/architecture/payment_wallet_aggregation_test.go'
if ($LASTEXITCODE -eq 0) { throw 'old wallet import remains outside architecture guard' }
Write-Host 'NO_OLD_WALLET_IMPORTS_OR_DIRS'
```

Expected:

```text
NO_OLD_WALLET_IMPORTS_OR_DIRS
```

- [x] **Step 3: Run focused backend tests**

```powershell
cd E:\admin_go_parallel\p16-wallet-payment
go test ./internal/module/payment/wallet/... -count=1
go test ./internal/module/payment/... -count=1
go test ./internal/server -run 'TestAdminRouteSnapshot|TestRouterInstallsWallet|TestRouterInstallsPayment|TestPayment' -count=1
go test ./internal/bootstrap -run 'Payment|Wallet|RouteMeta|Operation' -count=1
go test ./internal/architecture -run 'TestWalletOwnedByPaymentModule|TestNoImportsOfOldWalletModulePath|TestCommerceRBACAdminTransportShells' -count=1
```

Expected: every command exits `0`; route snapshot reports `ok` and does not request snapshot regeneration.

## Task 6: Run full backend gate

**Files:**

- Whole backend repo

- [x] **Step 1: Run full backend tests and build**

```powershell
cd E:\admin_go_parallel\p16-wallet-payment
go test ./internal/architecture -count=1
go test ./internal/server -run TestAdminRouteSnapshot -count=1
go test ./internal/bootstrap ./internal/server ./internal/module/payment/... ./internal/module/crontask ./internal/jobs -count=1
go test ./... -count=1
go build ./...
git diff --check
powershell -ExecutionPolicy Bypass -File E:\admin_go\scripts\check-agent-governance.ps1 -Mode working
```

Expected: every command exits `0`; governance output contains `PASS: no blocking governance violations found.`

## Task 7: Run frontend contract checks

**Files:**

- No frontend source edits
- Tests: `admin_front_ts/tests/shared/payment/*`
- Tests: `admin_front_ts/tests/shared/wallet/*`

- [x] **Step 1: Run typecheck and focused Vitest contracts**

```powershell
cd E:\admin_go\admin_front_ts
npm run typecheck
npm run test -- tests/shared/payment tests/shared/wallet
```

Expected: Vitest reports all payment and wallet test files passing. Record exact passed file/test counts in the worker report.

## Task 8: Commit backend slice

**Files:**

- Backend changes from Tasks 1-6

- [x] **Step 1: Review diff**

```powershell
cd E:\admin_go_parallel\p16-wallet-payment
git status --short
git diff --stat
```

Expected diff shape:

```text
internal/architecture/payment_wallet_aggregation_test.go      new file
internal/architecture/multiplatform_boundary_test.go          modified
internal/bootstrap/app.go                                     import path modified
internal/server/router.go                                     import path modified
internal/server/routes_admin_commerce_rbac.go                 import path modified
internal/module/wallet/** -> internal/module/payment/wallet/** renamed
```

No `database/migrations/*.sql`, frontend source, permission definitions, route metadata, payment callback, payment finalizer, Alipay adapter, or DB schema files should appear in this diff.

- [x] **Step 2: Commit backend branch**

```powershell
cd E:\admin_go_parallel\p16-wallet-payment
git add internal cmd docs
git commit -m "refactor: move wallet under payment module"
```

- [x] **Step 3: Final backend worker report**

Report exactly:

```text
Backend branch: work/p16-wallet-payment
Commit: run `git rev-parse --short HEAD` after committing and paste the printed SHA
Moved: internal/module/wallet -> internal/module/payment/wallet
Preserved routes: /api/admin/v1/wallet/summary, /transactions, /users, /ledger, /consumptions
Verification: list every command from Tasks 5-7 with pass/fail result
Remaining risks: no live DB/payment callback smoke was run; this was a package-boundary refactor only
```

## Task 9: Coordinator merge and root docs sync

Run this task only after the backend worker report shows all gates passed.

**Files:**

- Modify: `E:\admin_go\docs/status/current-status.md` for key-fact summary
- Modify: `E:\admin_go\docs/status/module-matrix.md` for commerce/RBAC and wallet per-module sections
- Modify: `E:\admin_go\docs/architecture/00-platform-and-module-rules.md`
- Modify: `E:\admin_go\docs/superpowers/plans/2026-05-28-multi-platform-phase2-execution-map.md`

- [x] **Step 1: Merge backend branch sequentially**

```powershell
cd E:\admin_go\admin_back_go
git switch master
git pull --ff-only
git merge --no-ff work/p16-wallet-payment
```

- [x] **Step 2: Rerun backend post-merge gate**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture -count=1
go test ./internal/server -run TestAdminRouteSnapshot -count=1
go test ./internal/bootstrap ./internal/server ./internal/module/payment/... ./internal/module/crontask ./internal/jobs -count=1
go test ./... -count=1
go build ./...
git diff --check
```

Expected: every command exits `0`.

- [x] **Step 3: Push backend master**

```powershell
cd E:\admin_go\admin_back_go
git push
```

- [x] **Step 4: Update root docs truth**

In `E:\admin_go\docs/status/current-status.md`, keep only the key wallet/payment aggregation summary. In `E:\admin_go\docs/status/module-matrix.md`, update the commerce/RBAC and wallet sections so they say:

```text
wallet now lives under admin_back_go/internal/module/payment/wallet while package identifiers and wallet.* i18n keys remain stable.
```

In `E:\admin_go\docs/architecture/00-platform-and-module-rules.md`, update the current-state paragraph so it says:

```text
wallet has moved under internal/module/payment/wallet; the old internal/module/wallet directory must not return.
```

In `E:\admin_go\docs/superpowers/plans/2026-05-28-multi-platform-phase2-execution-map.md`, change Plan 16 from pending to done and leave Plan 17 as the final remaining Phase 2 step.

Do not claim Phase 2 is complete in root docs until Plan 17 runs.

- [x] **Step 5: Verify and commit root docs**

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
git add docs/status/current-status.md docs/status/module-matrix.md docs/architecture/00-platform-and-module-rules.md docs/superpowers/plans/2026-05-28-multi-platform-phase2-execution-map.md
git commit -m "docs: record wallet payment aggregation"
git push
```

Expected governance output: `PASS: no blocking governance violations found.`

## Review checklist

Before reporting this plan complete, verify each item:

```text
Spec O2 says wallet defaults to module/payment/wallet because recharge and consume are deeply coupled.
Admin wallet URLs are unchanged.
Payment callback route remains internal/module/payment/transport/callback.
Payment config/recharge/order admin routes remain internal/module/payment/transport/admin.
Wallet package identifier remains package wallet.
No DB schema or live data migration was introduced.
No frontend source was changed.
Backend route snapshot passed.
Payment and wallet focused tests passed.
Root docs describe implemented runtime only after backend merge and verification.
Plan 17 remains the final Phase 2 closure review.
```
