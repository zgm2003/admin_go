# Admin Front Demo Any Source Quality Review

日期：2026-06-07

## Outcome

Admin Vue demo/source-only `any` inventory debt is closed for the current tracked rows.

This slice covers only:

```text
form demo handler/ref/remote-select params typing
display demo table column passthrough documentation type
ParticleBackground particle and pointer state typing
```

## Evidence

```text
form source = admin_front_ts/src/views/Main/component/form/index.vue
display source = admin_front_ts/src/views/Main/component/display/index.vue
particle source = admin_front_ts/src/views/Main/component/effect/components/ParticleBackground.vue
guards = admin_front_ts/tests/shared/form/form-demo-source-quality.test.ts
guards = admin_front_ts/tests/shared/display/display-demo-source-quality.test.ts
guards = admin_front_ts/tests/shared/effect/particle-background-source-quality.test.ts
inventory = docs/knowledge/admin-front-source-quality-inventory-2026-06-07.md
source files scanned = 280
any candidates = 0
as any candidates = 0
catch(error: any) candidates = 0
fallback candidates = 555
direct external HTTP candidates = 0
Demo any priority evidence = form/index.vue and display/index.vue have no configured source-quality finding; ParticleBackground has only the pointer null-state logical-or guard
```

Key source facts:

- `form/index.vue` uses `SearchFormModel`, `IconSelectExpose`, `MockRemoteSelectParams`, and `RemoteListFetchMethod<MockRemoteSelectOption, MockRemoteSelectParams>` instead of `any`.
- `display/index.vue` documents table column passthrough as `Record<string, unknown>` instead of `any`.
- `ParticleBackground.vue` defines `Particle` and `PointerPosition`, and uses explicit invariant helpers (`requireParticleContext`, `positiveDistance`, `requireParticle`) instead of `any` or logical-or numeric fallbacks.

## Compatibility

Preserved:

```text
/Main/component/form demo UI and query behavior
/Main/component/display table documentation shape
ParticleBackground canvas rendering and pointer interaction
existing routes and API calls
```

Changed deliberately:

```text
tracked demo any candidates are no longer present
ParticleBackground no longer uses window.devicePixelRatio || 1 or distance || 1 as hidden numeric fallbacks
```

## Verification

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/form/form-demo-source-quality.test.ts tests/shared/display/display-demo-source-quality.test.ts tests/shared/effect/particle-background-source-quality.test.ts
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

This closes the currently tracked Admin Vue `any/as any/catch-any/direct external HTTP` source-quality inventory rows.

It does not close the remaining `555` fallback candidates. Those rows remain review inventory and must be handled one narrow slice at a time.
