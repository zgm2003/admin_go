# Canvas Asset Route Contract Review

Date: 2026-06-07

Scope: Canvas Next top-level asset page route ownership and `CANVAS-DOC-002`.

This is source + live MySQL evidence. It does not claim a fresh browser smoke.

## Decision

`/asset-library` was a dead Canvas Next page, not a hidden route and not a missing backend seed.

The only active top-level Canvas asset page route is:

```text
/assets
```

The backend public asset library API remains:

```text
GET /api/canvas/v1/assets
```

The in-canvas asset picker remains the active frontend caller for the public asset library and is gated by `canvas_asset_read`.

## Evidence

Frontend source/test evidence:

```text
canvas_front_next/src/features/rbac/canvas-permissions.ts defines path "/assets" and does not define "/asset-library".
canvas_front_next/src/app/(user)/asset-library/page.tsx was removed.
canvas_front_next/tests/shared/canvas-rbac-shell.test.ts guards against reintroducing the dead asset-library page and keeps the asset API caller assertion on asset-picker-modal.tsx.
canvas_front_next/src/app/(user)/canvas/components/asset-picker-modal.tsx still gates fetchAssetLibrary with isReady, token, and can("canvas_asset_read").
```

Backend/source contract evidence:

```text
admin_back_go/database/migrations/20260531_canvas_front_next_integration.sql seeds canvas_assets_page at /assets.
docs/contracts/admin-api-v1.md lists active Canvas PAGE rows including canvas_assets_page and active BUTTON rows including canvas_asset_read.
docs/knowledge/runtime-inventory-2026-06-07.md now lists (user)/assets and no (user)/asset-library page.
docs/knowledge/frontend-api-inventory-2026-06-07.md no longer has a blob/download row for asset-library/page.tsx; frontend API calls found is now 272.
```

Live MySQL evidence collected from `admin_back_go/.env` `MYSQL_DSN` against local live `admin` database on `127.0.0.1:3307`:

```text
SELECT id,code,name,path,component,type,status,is_del,show_menu,parent_id
FROM permissions
WHERE platform='canvas'
  AND (path IN ('/assets','/asset-library') OR code LIKE '%asset%')
ORDER BY type,code;

canvas_assets_page => path=/assets, component=assets, type=2, status=1, is_del=2, show_menu=1
canvas_asset_read  => parent_id=canvas_assets_page, type=3, status=1, is_del=2
```

No active `/asset-library` Canvas PAGE row exists.

## Boundary

This closes `CANVAS-DOC-002` only.

It does not rewrite the local `/assets` "我的素材" page and does not change `GET /api/canvas/v1/assets`.
