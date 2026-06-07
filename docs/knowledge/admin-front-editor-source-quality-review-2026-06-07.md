# Admin Front Editor Source Quality Review

日期：2026-06-07

## Outcome

`ADMIN-FRONT-HARDENING-008` resolved for the wangEditor wrapper only.

The `Editor.vue` `as any` row and same-file upload URL fallback rows are closed. This does **not** mean the whole Admin Vue source-quality backlog is closed; the refreshed inventory still records `8` `any` candidates, `0` `catch(error: any)` candidates, and `562` fallback candidates elsewhere.

## Evidence

```text
source file = admin_front_ts/src/views/Main/component/display/components/Editor.vue
guard test = admin_front_ts/tests/shared/editor/editor-source-quality.test.ts
inventory = docs/knowledge/admin-front-source-quality-inventory-2026-06-07.md
any candidates = 7
as any candidates = 0
catch(error: any) candidates = 0
fallback candidates = 562
Editor.vue priority evidence = no regex finding in configured categories
```

Key source facts:

- `Editor.vue` imports `Boot`, `IDomEditor`, `IEditorConfig`, and `IModuleConf` from wangEditor instead of indexing a dynamic module through `any`.
- `editorRef` is `shallowRef<IDomEditor | null>(null)`.
- `cfg` is `computed<AdminEditorConfig>`.
- image/video upload insert functions are locally typed.
- `requireUploadURL(result.url)` rejects empty upload URLs instead of inserting `''`.

## Compatibility

Preserved:

```text
props: editorId, height, editorConfig, modelValue, uploadFolder, useCosUpload
emits: change, update:modelValue
expose: getEditorRef
default editor id: wangeditor-1
default height: 500px
default upload folder: article
default COS upload: enabled
wangEditor toolbar/editor template shape
```

Changed deliberately:

```text
uploadFileToCloud(...).url empty string now throws "wangEditor upload returned empty URL".
```

That is not a user-facing behavior break; it is fail-closed handling for a broken upload contract. Empty upload URL was never a valid rich-text asset.

## Verification

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/editor/editor-source-quality.test.ts
npm run typecheck

cd E:\admin_go
powershell -ExecutionPolicy Bypass -File .\scripts\export-admin-front-source-quality-inventory.ps1 -OutputDate 2026-06-07
```

Observed inventory after refresh:

```text
source_files_scanned=280
any_candidates=7
as_any_candidates=0
fallback_candidates=562
direct_external_http_candidates=0
```

## Boundary

This closes only the wangEditor wrapper `any/as any` and upload URL fallback debt.

Do not use this as permission to regex-sweep all remaining fallbacks. Remaining inventory rows must still be reviewed one narrow slice at a time.
