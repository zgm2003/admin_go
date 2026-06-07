# Admin Front DIcon Source Quality Review

Date: 2026-06-07

## Decision

`admin_front_ts/src/components/DIcon/src/index.vue` DIcon Element Plus dynamic-module as-any debt has been closed.

The old component already knew which module it was importing, but indexed the result through `(mod as any)[name]`. That was not an external unknown boundary; it was a typed module with a runtime string key. The current code types the module as `typeof import('@element-plus/icons-vue')` and narrows runtime icon names through an explicit `keyof` guard before indexing.

## Source change

```text
admin_front_ts/src/components/DIcon/src/index.vue:
  type ElementPlusIconsModule = typeof import('@element-plus/icons-vue')
  type ElementPlusIconName = keyof ElementPlusIconsModule
  hasElementPlusIcon(mod, name): name is ElementPlusIconName
  epIconsModulePromise = import('@element-plus/icons-vue')
  hasElementPlusIcon(mod, name) ? mod[name] : undefined
```

## Guard

```text
admin_front_ts/tests/shared/icon/dicon-source-quality.test.ts:
  rejects (mod as any)
  rejects as unknown as Promise<Record<string, Component>>
  rejects Record<string, Component>
  requires ElementPlusIconsModule / ElementPlusIconName
  requires hasElementPlusIcon(...) key narrowing before module indexing
```

## Inventory result after cleanup

```text
docs/knowledge/admin-front-source-quality-inventory-2026-06-07.md:
  source files scanned = 280
  any candidates = 7
  as any candidates = 0
  catch(error: any) candidates = 0
  fallback candidates = 562
  direct external HTTP candidates = 0
  DIcon/src/index.vue priority evidence = explicit missing-icon/null-state fallback rows only; no any/as-any row remains
```

## Boundary

This only closes DIcon dynamic-module any/as-any debt. It does not close DIcon's explicit missing-icon null-state fallback rows or general Admin Vue source-quality inventory rows.



