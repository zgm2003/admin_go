# Admin Front Dev Test Download Source Quality Review

日期：2026-06-07

## Outcome

Admin dev test page download error boundary is closed for `catch(error: any)` and fallback error messages.

`src/views/Main/test/index.vue` now catches download failures as `unknown`, requires a real non-empty `Error.message`, and uses an explicit optional filename helper instead of `testFilename.value || undefined`.

## Evidence

```text
source file = admin_front_ts/src/views/Main/test/index.vue
guard test = admin_front_ts/tests/shared/download-manager/dev-test-download-source-quality.test.ts
inventory = docs/knowledge/admin-front-source-quality-inventory-2026-06-07.md
source files scanned = 280
any candidates = 7
as any candidates = 0
catch(error: any) candidates = 0
fallback candidates = 562
direct external HTTP candidates = 0
Dev test download priority evidence = no catch-any/error fallback/filename || undefined rows remain
```

Key source facts:

- `handleDownloadWithProgress()` and `handleMultipleDownloads()` catch `unknown`, not `any`.
- `requireDevTestDownloadErrorMessage(error)` rejects non-`Error` reasons and empty `Error.message` values.
- `optionalDownloadFilename(testFilename.value)` makes the optional filename rule explicit.
- Batch download reports the real error and stops instead of silently swallowing it.

## Compatibility

Preserved:

```text
/dev test page route and UI shape
DownloadManager API usage
user cancel behavior through downloadFile return value
preset download URLs and filenames
batch download sequencing
```

Changed deliberately:

```text
non-Error download failures and empty Error.message values now fail closed instead of being replaced by generic text
```

## Verification

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/download-manager/dev-test-download-source-quality.test.ts

cd E:\admin_go
powershell -ExecutionPolicy Bypass -File .\scripts\export-admin-front-source-quality-inventory.ps1 -OutputDate 2026-06-07
```

Observed inventory after refresh:

```text
source_files_scanned=280
any_candidates=7
as_any_candidates=0
catch(error: any) candidates=0
fallback_candidates=562
direct_external_http_candidates=0
```

## Boundary

This closes only the dev test page download error-handling slice.

It does not close the remaining general Admin Vue `any` and fallback review rows. Keep reviewing one narrow slice at a time; do not regex-sweep the inventory.
