# Admin Front Upload Demo Source Quality Review

日期：2026-06-07

## Outcome

Admin upload demo `imgList` typing debt is closed.

`src/views/Main/component/upload/index.vue` now binds `UpMediaList` with a concrete `UploadMediaItem[]` model instead of `ref<any[]>`, and `UpMediaList.vue` shares that shape through a small local type file.

## Evidence

```text
source file = admin_front_ts/src/views/Main/component/upload/index.vue
shared type = admin_front_ts/src/views/Main/component/upload/components/media.ts
child component = admin_front_ts/src/views/Main/component/upload/components/UpMediaList.vue
guard test = admin_front_ts/tests/shared/upload/upload-demo-source-quality.test.ts
inventory = docs/knowledge/admin-front-source-quality-inventory-2026-06-07.md
source files scanned = 280
any candidates = 7
as any candidates = 0
catch(error: any) candidates = 0
fallback candidates = 562
direct external HTTP candidates = 0
Upload demo priority evidence = upload/index.vue has no configured source-quality finding; UpMediaList fallback rows remain outside this slice
```

Key source facts:

- `UploadMediaItem` owns the `{ name, url, uid }` model shape.
- `upload/index.vue` imports `UploadMediaItem` and uses `ref<UploadMediaItem[]>([])`.
- `UpMediaList.vue` uses the same model type for props, emits, watcher input, and emitted payload conversion.

## Compatibility

Preserved:

```text
/Main/component/upload demo route and UI shape
UpMediaList v-model contract
UpMedia and UpFile examples
existing Element Plus upload behavior
```

Changed deliberately:

```text
upload demo model state is no longer an any array
```

## Verification

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/upload/upload-demo-source-quality.test.ts
npm run typecheck

cd E:\admin_go
powershell -ExecutionPolicy Bypass -File .\scripts\export-admin-front-source-quality-inventory.ps1 -OutputDate 2026-06-07
```

Observed inventory after refresh:

```text
source_files_scanned=280
any_candidates=7
as_any_candidates=0
catch_error_any_candidates=0
fallback_candidates=562
direct_external_http_candidates=0
```

## Boundary

This closes only the upload demo `ref<any[]>` model typing slice.

It does not close `UpMediaList.vue` preview/url fallback rows or the remaining general Admin Vue `any` and fallback review rows.
