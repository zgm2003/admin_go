# Admin Front AI Image Payload Source Quality Review

日期：2026-06-07

## Outcome

Admin Vue AI image create-task payload fallback debt is closed for optional enum fields and mask IDs.

`src/api/ai/images.ts` no longer uses `payload.size || undefined`, `payload.quality || undefined`, `payload.output_format || undefined`, `payload.moderation || undefined`, or truthy mask ID checks that silently skip `0`.

## Evidence

```text
source file = admin_front_ts/src/api/ai/images.ts
guard test = admin_front_ts/tests/shared/ai/ai-image-api.test.ts
inventory = docs/knowledge/admin-front-source-quality-inventory-2026-06-07.md
source files scanned = 280
any candidates = 0
as any candidates = 0
catch(error: any) candidates = 0
fallback candidates = 555
direct external HTTP candidates = 0
AI image priority evidence = images.ts now only has positiveID predicate logical-or; optional payload fallbacks are gone
```

Key source facts:

- optionalImageEnum(...) treats only `undefined` and explicit empty string `''` as omitted optional enum values.
- `optionalPositiveID(...)` treats only `undefined` as omitted optional ID; `0` now reaches `positiveID(...)` and fails closed.
- The API route and payload shape stay the same: `POST /api/admin/v1/ai-images` through `AiImageApi.createTask(...)`.

## Compatibility

Preserved:

```text
AiImageTaskCreatePayload public type
AiImageApi.createTask wrapper
blank form enum values omitted from request body
existing route/API contract
```

Changed deliberately:

```text
mask_asset_id = 0 and mask_target_asset_id = 0 are no longer silently ignored by truthy checks
optional enum omission is explicit instead of logical-or fallback
```

## Verification

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/ai/ai-image-api.test.ts
npm run typecheck

cd E:\admin_go
powershell -ExecutionPolicy Bypass -File .\scripts\export-admin-front-source-quality-inventory.ps1 -OutputDate 2026-06-07
```

Observed inventory after refresh:

```text
source_files_scanned=280
any_candidates=0
as_any_candidates=0
fallback_candidates=555
direct_external_http_candidates=0
```

## Boundary

This closes only the AI image create-task optional payload fallback slice.

It does not close the remaining Admin Vue fallback inventory. `images.ts` still has the `positiveID` validation predicate logical-or, which is not a defaulting fallback.
