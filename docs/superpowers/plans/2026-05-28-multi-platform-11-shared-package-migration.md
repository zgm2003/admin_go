# Shared Package Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` only for review support; implement this plan with `superpowers:executing-plans` because the import graph is high-coupling and the tasks are sequential. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move backend cross-capability public packages into `internal/shared` without changing admin URLs, response payload shape, enum values, validation semantics, or i18n catalog behavior.

**Architecture:** This is a dependency-aware package migration. Move leaf packages first, update imports mechanically, run focused tests after each group, then add an architecture guard so new code imports `internal/shared/*` instead of the old root shared-like paths.

**Tech Stack:** Go packages/imports, `gofmt`, backend architecture tests, route snapshot, full backend test/build, root governance checker.

---

## Scope Check

In scope:

```text
admin_back_go/internal/apperror -> admin_back_go/internal/shared/apperror
admin_back_go/internal/i18n     -> admin_back_go/internal/shared/i18n
admin_back_go/internal/response -> admin_back_go/internal/shared/response
admin_back_go/internal/enum     -> admin_back_go/internal/shared/enum
admin_back_go/internal/validate -> admin_back_go/internal/shared/validate
admin_back_go/internal/dict     -> admin_back_go/internal/shared/dict final ownership
admin_back_go/internal/shared/setting import updates to shared apperror/enum
Go import path updates in internal/cmd
architecture guard for the completed migration
active docs update
```

Out of scope:

```text
module aggregation or module renaming
admin/app/openapi route URL changes
DB schema changes
enum value changes
validation tag behavior changes
response JSON shape changes
new frontend UI work
payment/auth secret or production config changes
```

## Migration order

Use this order to reduce import-cycle risk:

```text
1. enum
2. apperror
3. i18n
4. response
5. validate
6. dict final ownership
7. shared/setting import cleanup
8. guard/docs/full verification
```

Do not move all directories at once. After each group, run the focused test listed below and fix compile errors before continuing.

## Task 1: Inventory imports and package contents

- [x] **Step 1: Confirm clean starting point**

```powershell
cd E:\admin_go
git status --short --branch
git -C admin_back_go status --short --branch
git -C admin_front_ts status --short --branch
```

Expected: root/backend/frontend are on the intended branch. If there are unrelated local changes, record them and do not overwrite them.

- [x] **Step 2: Inventory old imports**

```powershell
cd E:\admin_go\admin_back_go
rg -n 'admin_back_go/internal/(apperror|response|i18n|enum|validate|dict)' internal cmd
```

Expected: direct imports exist across modules, middleware, server, bootstrap, infra, shared/setting, and tests.

- [x] **Step 3: Inventory current shared packages**

```powershell
cd E:\admin_go\admin_back_go
Get-ChildItem .\internal\shared -Directory | Select-Object -ExpandProperty Name
Get-ChildItem .\internal -Directory | Where-Object { $_.Name -in @('apperror','response','i18n','enum','validate','dict') } | Select-Object -ExpandProperty Name
```

Expected before migration:

```text
internal/shared contains dict and setting
old root shared-like directories still contain apperror, response, i18n, enum, validate, dict
```

## Task 2: Move `enum` first and update imports

- [x] **Step 1: Move package**

```powershell
cd E:\admin_go\admin_back_go
git mv .\internal\enum .\internal\shared\enum
```

- [x] **Step 2: Update imports**

```powershell
cd E:\admin_go\admin_back_go
rg -l 'admin_back_go/internal/enum' internal cmd | ForEach-Object {
  (Get-Content -LiteralPath $_ -Raw).Replace('admin_back_go/internal/enum','admin_back_go/internal/shared/enum') | Set-Content -LiteralPath $_ -NoNewline
}
gofmt -w .\internal .\cmd
```

- [x] **Step 3: Focused verification**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/shared/enum ./internal/dict ./internal/shared/dict ./internal/shared/setting ./internal/validate -count=1
```

Expected: PASS after any compile fixes. The package name remains `enum`.

## Task 3: Move `apperror` and update imports

- [x] **Step 1: Move package**

```powershell
cd E:\admin_go\admin_back_go
git mv .\internal\apperror .\internal\shared\apperror
```

- [x] **Step 2: Update imports**

```powershell
cd E:\admin_go\admin_back_go
rg -l 'admin_back_go/internal/apperror' internal cmd | ForEach-Object {
  (Get-Content -LiteralPath $_ -Raw).Replace('admin_back_go/internal/apperror','admin_back_go/internal/shared/apperror') | Set-Content -LiteralPath $_ -NoNewline
}
gofmt -w .\internal .\cmd
```

- [x] **Step 3: Focused verification**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/shared/apperror ./internal/shared/setting ./internal/middleware ./internal/server -count=1
```

Expected: PASS. The package name remains `apperror`; only import paths change.

## Task 4: Move `i18n` and update imports

- [x] **Step 1: Move package with embedded locales**

```powershell
cd E:\admin_go\admin_back_go
git mv .\internal\i18n .\internal\shared\i18n
```

The `locales/*/*.yaml` tree moves with the package. Keep `//go:embed locales/*/*.yaml` unchanged because it is relative to the new package directory.

- [x] **Step 2: Update imports**

```powershell
cd E:\admin_go\admin_back_go
rg -l 'admin_back_go/internal/i18n' internal cmd | ForEach-Object {
  (Get-Content -LiteralPath $_ -Raw).Replace('admin_back_go/internal/i18n','admin_back_go/internal/shared/i18n') | Set-Content -LiteralPath $_ -NoNewline
}
gofmt -w .\internal .\cmd
```

- [x] **Step 3: Focused verification**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/shared/i18n ./internal/response ./internal/server -count=1
```

Expected: PASS. If `source_coverage_test.go` reads source paths, update it to scan the current `internal` tree while excluding generated/build artifacts.

## Task 5: Move `response` and update imports

- [x] **Step 1: Move package**

```powershell
cd E:\admin_go\admin_back_go
git mv .\internal\response .\internal\shared\response
```

- [x] **Step 2: Update imports and internal dependencies**

```powershell
cd E:\admin_go\admin_back_go
rg -l 'admin_back_go/internal/response' internal cmd | ForEach-Object {
  (Get-Content -LiteralPath $_ -Raw).Replace('admin_back_go/internal/response','admin_back_go/internal/shared/response') | Set-Content -LiteralPath $_ -NoNewline
}
gofmt -w .\internal .\cmd
```

After import replacement, confirm `internal/shared/response/response.go` imports:

```text
admin_back_go/internal/shared/apperror
admin_back_go/internal/shared/i18n
```

- [x] **Step 3: Focused verification**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/shared/response ./internal/middleware ./internal/server -count=1
```

Expected: PASS and response JSON remains `{ code, data, msg }`.

## Task 6: Move `validate` and update imports

- [x] **Step 1: Move package**

```powershell
cd E:\admin_go\admin_back_go
git mv .\internal\validate .\internal\shared\validate
```

- [x] **Step 2: Update imports**

```powershell
cd E:\admin_go\admin_back_go
rg -l 'admin_back_go/internal/validate' internal cmd | ForEach-Object {
  (Get-Content -LiteralPath $_ -Raw).Replace('admin_back_go/internal/validate','admin_back_go/internal/shared/validate') | Set-Content -LiteralPath $_ -NoNewline
}
gofmt -w .\internal .\cmd
```

- [x] **Step 3: Focused verification**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/shared/validate ./internal/server -count=1
```

Expected: PASS. Validation tag names and enum checks are unchanged.

## Task 7: Finalize `dict` ownership under `internal/shared/dict`

`internal/shared/dict` already exists as a compatibility boundary. Do not overwrite it blindly.

- [x] **Step 1: Split the existing shared registry from legacy wrappers**

In `internal/shared/dict`, keep the Service/Registry/provider-name code, but put it in `registry.go`. The final `registry.go` must call local option functions directly:

```go
package dict

const (
	ProviderCommonStatus           = "common_status"
	ProviderCommonYesNo            = "common_yes_no"
	ProviderPlatform               = "platform"
	ProviderSystemSettingValueType = "system_setting_value_type"
)

type providerFunc func() any

type Registry struct {
	providers map[string]providerFunc
}

func NewRegistry() *Registry {
	registry := &Registry{providers: map[string]providerFunc{}}
	registry.Register(ProviderCommonStatus, func() any { return CommonStatusOptions() })
	registry.Register(ProviderCommonYesNo, func() any { return CommonYesNoOptions() })
	registry.Register(ProviderPlatform, func() any { return PlatformOptions() })
	registry.Register(ProviderSystemSettingValueType, func() any { return SystemSettingValueTypeOptions() })
	return registry
}

func (r *Registry) Register(name string, provider providerFunc) {
	if r == nil || name == "" || provider == nil {
		return
	}
	r.providers[name] = provider
}

func (r *Registry) Options(name string) (any, bool) {
	if r == nil {
		return nil, false
	}
	provider, ok := r.providers[name]
	if !ok {
		return nil, false
	}
	return provider(), true
}

type Service struct {
	registry *Registry
}

func NewService(registry *Registry) *Service {
	if registry == nil {
		registry = NewRegistry()
	}
	return &Service{registry: registry}
}

func (s *Service) Options(name string) (any, bool) {
	if s == nil {
		return nil, false
	}
	return s.registry.Options(name)
}
```

Remove `import legacydict "admin_back_go/internal/dict"` from `internal/shared/dict`.

- [x] **Step 2: Move old dict implementation files into shared/dict**

Use `Move-Item` only for files that do not collide with the new `registry.go`:

```powershell
cd E:\admin_go\admin_back_go
Get-ChildItem .\internal\dict -File | ForEach-Object {
  git mv $_.FullName (Join-Path (Resolve-Path .\internal\shared\dict) $_.Name)
}
```

If `dict.go` collides with the previous shared wrapper file, keep the old implementation version that defines `Option` and the full option functions, and keep the registry code in `registry.go`.

- [x] **Step 3: Update dict imports**

```powershell
cd E:\admin_go\admin_back_go
rg -l 'admin_back_go/internal/dict' internal cmd | ForEach-Object {
  (Get-Content -LiteralPath $_ -Raw).Replace('admin_back_go/internal/dict','admin_back_go/internal/shared/dict') | Set-Content -LiteralPath $_ -NoNewline
}
rg -l 'admin_back_go/internal/shared/dict' internal cmd | ForEach-Object {
  (Get-Content -LiteralPath $_ -Raw).Replace('legacydict.', '') | Set-Content -LiteralPath $_ -NoNewline
}
gofmt -w .\internal .\cmd
```

- [x] **Step 4: Remove the empty old dict directory**

```powershell
cd E:\admin_go\admin_back_go
if (Test-Path .\internal\dict) {
  $remaining = Get-ChildItem .\internal\dict -Force
  if ($remaining.Count -eq 0) {
    Remove-Item -LiteralPath .\internal\dict
  } else {
    Write-Error "internal/dict still has files; inspect before removal"
  }
}
```

- [x] **Step 5: Focused verification**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/shared/dict ./internal/module/authplatform ./internal/module/user ./internal/module/payment ./internal/module/aiagent -count=1
```

Expected: PASS. Dict option labels and values are unchanged.

## Task 8: Add migration guard

- [x] **Step 1: Add architecture test**

Create `internal/architecture/shared_package_migration_test.go`:

```go
package architecture

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestSharedPackageMigrationComplete(t *testing.T) {
	root := backendRoot(t)
	packages := []string{"apperror", "response", "i18n", "enum", "validate", "dict"}
	for _, name := range packages {
		if _, err := os.Stat(filepath.Join(root, "internal", name)); !os.IsNotExist(err) {
			t.Fatalf("old shared-like package internal/%s must not exist after migration", name)
		}
		if _, err := os.Stat(filepath.Join(root, "internal", "shared", name)); err != nil {
			t.Fatalf("internal/shared/%s must exist after migration: %v", name, err)
		}
	}

	banned := []string{
		"admin_back_go/internal/apperror",
		"admin_back_go/internal/response",
		"admin_back_go/internal/i18n",
		"admin_back_go/internal/enum",
		"admin_back_go/internal/validate",
		"admin_back_go/internal/dict",
	}

	for _, base := range []string{"cmd", "internal"} {
		err := filepath.WalkDir(filepath.Join(root, base), func(path string, d os.DirEntry, err error) error {
			if err != nil {
				return err
			}
			if d.IsDir() || filepath.Ext(path) != ".go" {
				return nil
			}
			body, err := os.ReadFile(path)
			if err != nil {
				return err
			}
			text := string(body)
			for _, oldImport := range banned {
				if strings.Contains(text, oldImport) {
					rel, _ := filepath.Rel(root, path)
					t.Fatalf("%s still imports old shared-like package %q", filepath.ToSlash(rel), oldImport)
				}
			}
			return nil
		})
		if err != nil {
			t.Fatalf("walk %s: %v", base, err)
		}
	}
}
```

- [x] **Step 2: Run guard**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture -run TestSharedPackageMigrationComplete -count=1
```

Expected: PASS.

## Task 9: Full backend verification

- [x] **Step 1: Run shared and architecture tests**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/shared/... -count=1
go test ./internal/architecture -count=1
```

Expected: PASS.

- [x] **Step 2: Run route snapshot and full backend suite**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/server -run TestAdminRouteSnapshot -count=1
go test ./... -count=1
go build ./...
```

Expected: PASS. If the full suite fails, fix the first compile/test failure before continuing.

- [x] **Step 3: Frontend gate only if API behavior drift is suspected**

Run this if route snapshot or backend contract tests show DTO/page-init response changes:

```powershell
cd E:\admin_go\admin_front_ts
npm run typecheck
npm run test -- tests/shared/user/users-api.test.ts
```

Expected: PASS when run. If no API behavior drift is observed, record that frontend runtime was not touched.

## Task 10: Active docs and commits

- [x] **Step 1: Update active docs**

Update these files to match the verified runtime:

```text
E:\admin_go\docs\status\current-status.md
E:\admin_go\docs\architecture\00-platform-and-module-rules.md
E:\admin_go\docs\architecture\04-go-backend-framework.md
E:\admin_go\docs\architecture\05-development-quality-rules.md
E:\admin_go\admin_back_go\docs\architecture.md
```

Required wording:

```text
internal/shared now owns apperror, response, i18n, enum, validate, dict, and setting.
old root shared-like packages are gone.
systemsetting remains admin CRUD; shared/setting remains the cross-module typed settings boundary for migrated keys.
No module aggregation is claimed by Plan 11.
```

- [x] **Step 2: Commit backend changes**

```powershell
cd E:\admin_go\admin_back_go
git status --short
git add internal docs
git commit -m "refactor: move shared packages under shared boundary"
```

Expected: backend commit created.

- [x] **Step 3: Commit root docs**

```powershell
cd E:\admin_go
git status --short
git add docs/status/current-status.md docs/architecture docs/superpowers/plans/2026-05-28-multi-platform-11-shared-package-migration.md admin_back_go/docs/architecture.md
git commit -m "docs: plan shared package boundary migration"
```

Expected: root docs commit created if the root repo tracks those files. If `admin_back_go/docs/architecture.md` is not tracked by root, leave it committed only in the backend repo and do not force-add nested repo internals to root.

- [x] **Step 4: Root governance verification**

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected: both PASS.

## Review checklist before marking Plan 11 complete

```text
No `admin_back_go/internal/{apperror,response,i18n,enum,validate,dict}` import remains in Go files.
`internal/shared/{apperror,response,i18n,enum,validate,dict,setting}` all exist.
`internal/shared/response` imports shared apperror/i18n only.
`internal/shared/dict` no longer wraps old `internal/dict`.
`internal/shared/setting` imports shared apperror/enum.
Admin route snapshot passes.
Full backend tests and build pass.
Active docs do not claim module aggregation.
```

## Rollback

Rollback is one backend commit plus one docs commit:

```powershell
cd E:\admin_go\admin_back_go
git revert <backend-shared-migration-commit>

cd E:\admin_go
git revert <root-docs-shared-migration-commit>
```

If the migration fails before commit, use `git status --short` to identify moved directories and restore only the files touched by this plan:

```powershell
cd E:\admin_go\admin_back_go
git restore --source=HEAD --staged --worktree -- internal cmd docs
```

Do not touch frontend files during rollback unless Task 9 Step 3 actually changed frontend files.
