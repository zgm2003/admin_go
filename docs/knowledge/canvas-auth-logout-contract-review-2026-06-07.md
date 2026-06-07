# Canvas Auth Logout Contract Review

Date: 2026-06-07

## Decision

`POST /api/canvas/v1/auth/logout` is an active Canvas frontend gap that has been closed.

It is not a backend-only diagnostic endpoint and not a dead route. The backend owns session revocation; the frontend must call it before clearing browser state.

## Source evidence

```text
Backend route:
admin_back_go/internal/module/auth/transport/canvas/route.go registers POST /api/canvas/v1/auth/logout.

Backend handler:
admin_back_go/internal/module/auth/transport/canvas/handler.go parses Authorization bearer token and calls authService.Logout(ctx, accessToken).

Backend test:
admin_back_go/internal/module/auth/transport/canvas/handler_test.go sends Authorization: Bearer canvas-token and verifies the service receives canvas-token.

Frontend API:
canvas_front_next/src/services/api/auth.ts exports logout(token) and calls POST /api/canvas/v1/auth/logout through apiPost with the bearer token argument.

Frontend state:
canvas_front_next/src/stores/use-user-store.ts exposes async logout() separately from clearSession().

Frontend UI:
canvas_front_next/src/components/layout/user-status-actions.tsx account menu uses store logout(), not clearSession().
```

## Runtime behavior

```text
token exists:
  call POST /api/canvas/v1/auth/logout with Authorization: Bearer token
  if backend succeeds, clear token, refreshToken, user, buttonCodes, routePaths
  if backend fails, keep the browser session and rethrow the backend error

token missing:
  clear local state only, because there is no server token to revoke
```

This is deliberate fail-closed behavior. A failed backend logout must not be hidden by clearing local state.
In short: backend failure preserves the browser session.

## API drift result

Current 2026-06-07 generated artifacts after the later Admin user status and Admin AI agent test closures:

```text
docs/knowledge/frontend-backend-api-drift-2026-06-07.md:
  frontend exact backend API calls compared = 258
  frontend-route-match = 258
  frontend-method-mismatch = 0
  frontend-no-backend-route = 0
  backend admin/canvas source-only routes = 19

docs/knowledge/api-source-only-route-review-2026-06-07.md:
  source-only routes reviewed = 19
  owner-decision-required routes = 0
```

`API-DRIFT-001` has no remaining owner-decision-required route after the later Admin AI agent test closure.

## Verification

```powershell
cd E:\admin_go\canvas_front_next
npm run test -- src/stores/use-user-store.test.ts src/services/api/auth.test.ts tests/shared/canvas-auth-boundary.test.ts

cd E:\admin_go
powershell -ExecutionPolicy Bypass -File .\scripts\export-frontend-api-inventory.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\export-frontend-backend-api-drift.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\export-api-source-only-route-review.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\export-full-stack-module-map.ps1 -OutputDate 2026-06-07
```
