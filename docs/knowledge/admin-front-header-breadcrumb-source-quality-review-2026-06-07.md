# Admin Front Header Breadcrumb Source Quality Review

Date: 2026-06-07

## Decision

`admin_front_ts/src/views/Layout/components/Header/index.vue` breadcrumb route-walk debt has been closed.

The old code treated menu nodes as `any[]`, returned `getPath(...) || []`, and accepted `item: any` for label resolution. That hid the actual data shape already guaranteed by `userStore.permissions: PermissionMenuItem[]` and made a missing breadcrumb path look like a harmless default.

## Source change

```text
admin_front_ts/src/views/Layout/components/Header/index.vue:
  imports PermissionMenuItem
  derives breadcrumbs through findBreadcrumbPath(items: PermissionMenuItem[], target: string)
  checks missing path explicitly with matchedPath !== null
  passes PermissionMenuItem into getBreadcrumbLabel
  uses shallowRef for primitive local state touched in this slice
```

## Guard

```text
admin_front_ts/tests/layout/header-source-quality.test.ts:
  rejects any/as any in Header/index.vue
  rejects the retired getPath(...) || [] fallback
  rejects the retired !selectedIndex || selectedIndex === ... branch
```

## Inventory result after cleanup

```text
docs/knowledge/admin-front-source-quality-inventory-2026-06-07.md:
  any candidates = 29
  fallback candidates = 589
  direct external HTTP candidates = 0
  Header/index.vue priority evidence = no regex finding in configured categories
```

## Boundary

This only closes Header breadcrumb route-walk source-quality debt. It does not close the remaining Admin Vue `any/as any/catch-any/fallback` inventory rows.
