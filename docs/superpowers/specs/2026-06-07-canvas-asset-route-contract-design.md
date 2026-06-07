# Canvas Asset Route Contract Design

Date: 2026-06-07

## Problem

Canvas Next source contains two asset-like routes:

```text
/assets
/asset-library
```

The active Canvas RBAC route contract only contains `/assets`. Live MySQL, Go seed SQL, frontend route registry, and contract docs agree on `/assets`; `/asset-library` exists only as a Next page file and has no navigation entry.

Keeping both is bad taste. It creates a special case where source inventory implies a route that the backend router will never authorize. Adding a frontend fallback or alias would hide the contract bug instead of fixing it.

## Goal

Make `/assets` the only top-level Canvas asset page route.

```text
PAGE route: /assets
PAGE code: canvas_assets_page
BUTTON code: canvas_asset_read
Top/mobile nav: from backend router + local registry, path /assets
Canvas public-library API: GET /api/canvas/v1/assets
```

Remove the unreachable `/asset-library` page. Keep the canvas in-editor asset picker as the place that reads the backend public asset library with `canvas_asset_read`.

## Non-goals

```text
Do not add /asset-library to DB seed or docs.
Do not add a route alias or fallback permission check.
Do not change GET /api/canvas/v1/assets.
Do not rewrite the local /assets "我的素材" page in this slice.
Do not change canvas_asset_read semantics outside active callers.
```

## Evidence rules

- Live MySQL `permissions` must contain active Canvas PAGE `/assets` for `canvas_assets_page`.
- Live MySQL must not contain an active `/asset-library` Canvas PAGE.
- `canvas_front_next/src/features/rbac/canvas-permissions.ts` must define `/assets` and must not define `/asset-library`.
- `canvas_front_next/src/app/(user)/asset-library/page.tsx` must not exist.
- `canvas_front_next/tests/shared/canvas-rbac-shell.test.ts` must guard that dead route from coming back.
- Documentation and generated inventory must not present `/asset-library` as current route inventory after this fix.

## Runtime decision

`/asset-library` is a dead page, not a hidden route and not a missing seed. Direct navigation is blocked by `CanvasAuthGuard` because route authorization is derived from backend `router` paths, and live DB only grants `/assets`.

## Verification target

```text
canvas_front_next targeted RBAC test passes.
canvas_front_next typecheck passes.
root runtime fact checker with -LiveSchema verifies /assets live DB state and /asset-library absence.
root governance gates pass.
```
