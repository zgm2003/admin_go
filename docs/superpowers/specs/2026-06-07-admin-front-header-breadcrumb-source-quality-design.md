# Admin Front Header Breadcrumb Source Quality Design

Date: 2026-06-07

## Requirement

Remove the `any[]`, `item: any`, and `getPath(...) || []` breadcrumb route-walk debt from `admin_front_ts/src/views/Layout/components/Header/index.vue` without changing route/store contracts.

## Design

Use the existing `PermissionMenuItem` data structure from `@/types/user` as the breadcrumb node type. Move the recursive route search into `findBreadcrumbPath(items: PermissionMenuItem[], target: string): PermissionMenuItem[] | null`, then handle `null` explicitly instead of hiding it behind logical-or fallback.

For touched primitive local state in the SFC, use `shallowRef` to keep reactivity narrow.

## Non-goals

```text
Do not rewrite the layout shell.
Do not change userStore.permissions or backend router DTO.
Do not claim all Header/Layout fallback debt is gone outside this breadcrumb route-walk slice.
```

## Verification

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/layout/header-source-quality.test.ts
npm run typecheck
```
