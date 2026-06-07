# Admin Front DownloadManager Source Quality Review

日期：2026-06-07

## Outcome

`ADMIN-FRONT-HARDENING-009` resolved for the shared DownloadManager error boundary and filename fallback cleanup.

`DownloadManager/src/download.ts` no longer catches download failures as `any`, no longer hides failed blob downloads behind `window.open(url, '_blank')`, and no longer derives filenames through logical-or fallback chains.

## Evidence

```text
source file = admin_front_ts/src/components/DownloadManager/src/download.ts
helper file = admin_front_ts/src/components/DownloadManager/src/errors.ts
guard test = admin_front_ts/tests/shared/download-manager/download-manager-source-quality.test.ts
inventory = docs/knowledge/admin-front-source-quality-inventory-2026-06-07.md
source files scanned = 280
any candidates = 7
as any candidates = 0
catch(error: any) candidates = 0
fallback candidates = 562
direct external HTTP candidates = 0
DownloadManager/download.ts priority evidence = no regex finding in configured categories
```

Key source facts:

- `downloadFile()` catches `unknown`, not `any`.
- user cancellation is isolated by `isDownloadUserCancelled(error, t('download.userCancelled'))`.
- real failures pass through `requireDownloadError(error, 'download')` or `requireDownloadError(error, 'web download')`.
- non-`Error` reasons and empty `Error.message` values are rejected instead of being converted into fallback text.
- Web fetch failures are logged and rethrown; direct-open behavior remains only in explicit open-url flows, not as a failed-download fallback.
- Download filename derivation is explicit through `resolveSuggestedDownloadFilename(...)` and `resolveSavePathFilename(...)`, not `||` chains.

## Compatibility

Preserved:

```text
downloadFile(url, filename, options) signature
Tauri successful download flow
Tauri user-cancel return value: undefined
Web successful fetch-blob download flow
openUrl(url) explicit browser/Tauri open behavior
```

Changed deliberately:

```text
Web fetch download failure now throws a real Error instead of opening the URL in a new tab.
```

That is fail-closed behavior. A failed download is not a valid direct-open instruction.

## Verification

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/download-manager/download-manager-source-quality.test.ts
npm run typecheck

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

This closes only DownloadManager `download.ts` catch-any, failed-download silent direct-open fallback, and same-file filename logical-or fallback debt.

The later dev test download cleanup closed the remaining catch-any inventory row in `admin_front_ts/src/views/Main/test/index.vue`. General Admin Vue `any` and fallback rows remain review debt.





