# Canvas RBAC Permission Contract Review

Date: 2026-06-07

Scope: Canvas `buttonCodes` contract for text/image/video generation actions.

This is source + live MySQL evidence. It does not claim a fresh served-route smoke.

## Decision

`canvas_ai_text_generate` is dead frontend type drift, not an active Canvas BUTTON permission.

Active Canvas generation BUTTON codes remain:

```text
canvas_ai_image_generate
canvas_ai_video_generate
```

There is no active separate Canvas BUTTON code for text generation. Text generation uses Canvas page/session access plus backend-managed `canvas_text_generate` agent scene selection; do not invent `canvas_ai_text_generate` as a fallback code.

## Evidence

Frontend source/test evidence:

```text
canvas_front_next/src/features/rbac/canvas-permissions.ts no longer defines canvas_ai_text_generate.
canvas_front_next/tests/shared/canvas-rbac-shell.test.ts explicitly rejects canvas_ai_text_generate in the canonical Canvas RBAC registry.
rg over canvas_front_next/src shows no can("canvas_ai_text_generate") call sites.
```

Backend source evidence:

```text
admin_back_go/database/migrations/20260531_canvas_front_next_integration.sql seeds canvas_ai_image_generate and canvas_ai_video_generate, not canvas_ai_text_generate.
admin_back_go/database/migrations/20260531_canvas_front_next_integration.sql cleanup list soft-deletes unknown Canvas BUTTON codes.
admin_back_go/internal/bootstrap/route_meta.go contains no Canvas AI text route permission rule; Canvas route access is page/session scoped here, not a separate text-generation BUTTON.
docs/contracts/admin-api-v1.md lists Canvas BUTTON rows without canvas_ai_text_generate.
```

Live MySQL evidence collected from `admin_back_go/.env` `MYSQL_DSN` against local live `admin` database on `127.0.0.1:3307`:

```text
SELECT id,code,name,parent_id,type,status,is_del
FROM permissions
WHERE platform='canvas'
  AND code IN ('canvas_access','canvas_prompt_read','canvas_asset_read','canvas_ai_text_generate','canvas_ai_image_generate','canvas_ai_video_generate')
ORDER BY type, code;

canvas_ai_text_generate => parent_id=0, type=3, status=2, is_del=1
canvas_access           => type=3, status=1, is_del=2
canvas_prompt_read      => type=3, status=1, is_del=2
canvas_asset_read       => type=3, status=1, is_del=2
canvas_ai_image_generate => type=3, status=1, is_del=2
canvas_ai_video_generate => type=3, status=1, is_del=2
```

The stale `canvas_ai_text_generate` row exists only as a soft-deleted orphan from earlier iterations. It must not be reintroduced into frontend canonical permission types.

## Boundary

This closes `CANVAS-DOC-001` only.

The separate asset-route ambiguity is closed by:

```text
docs/knowledge/canvas-asset-route-contract-review-2026-06-07.md
```
