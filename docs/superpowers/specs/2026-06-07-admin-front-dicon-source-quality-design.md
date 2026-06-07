# Admin Front DIcon Source Quality Design

Date: 2026-06-07

## Decision

Close the `DIcon` shared component's Element Plus dynamic-icon `as any` debt in one narrow Admin Vue quality slice.

## Current problem

`admin_front_ts/src/components/DIcon/src/index.vue` currently loads Element Plus icons dynamically and then indexes the module through:

```ts
const comp = (mod as any)[name] as Component | undefined
```

That hides the actual data structure. The module is not unknown: it is `typeof import('@element-plus/icons-vue')`. Treating it as `any` makes the icon resolver weaker than the runtime contract and keeps the source-quality inventory red.

## Scope

In scope:

- Type the dynamic Element Plus icons module as `typeof import('@element-plus/icons-vue')`.
- Add a small key guard so a runtime string icon name is narrowed to `keyof ElementPlusIconsModule`.
- Remove `(mod as any)` and the `as unknown as Promise<Record<string, Component>>` cast.
- Keep `DIcon` public props unchanged: `icon?: string`, `size?: number | string`.
- Keep missing Element Plus icons rendering nothing.
- Add a targeted source-quality guard for `DIcon`.
- Refresh Admin front source-quality inventory, review doc, runtime knowledge/status, and fact-check assertions.

Out of scope:

- Reworking icon naming, Iconify behavior, or icon cache semantics.
- Closing the remaining `Editor.vue` wangEditor `as any` row.
- Solving DownloadManager catch-any/fallback debt.
- Touching Go backend or Canvas Next runtime.

## Data model

The resolver has two valid icon states:

```text
Iconify icon string -> render Iconify component
Element Plus icon name present in module -> render that component
Element Plus icon name absent / module load failed -> cache null and render nothing
```

Missing icons are a legitimate UI absence state. They should stay explicit as `null`; the problem is only the untyped module access.

## Compatibility

No public contract changes. Existing callers still pass the same `icon` and `size` props. Unknown Element Plus icon names still render no icon. Iconify names containing `:` still go through `@iconify/vue`.

## Verification

Targeted checks:

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/icon/dicon-source-quality.test.ts
npm run typecheck
```

Root checks:

```powershell
cd E:\admin_go
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1 -LiveSchema
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

## Self-review

- No placeholders.
- This is not a broad icon-system redesign.
- This does not claim all Admin Vue `as any` debt is closed; it only closes the shared `DIcon` dynamic-module access row.
- Missing icon names remain a legitimate explicit `null` state, not a hidden fallback for broken API data.
