# Canvas Auth Logout Contract Design

Date: 2026-06-07

## Problem

`POST /api/canvas/v1/auth/logout` is implemented and tested in the Go Canvas auth transport, but Canvas Next currently logs out by clearing local Zustand state only.

That is a bad state split:

```text
Backend owns session revocation.
Frontend owns browser state.
Logout currently mutates only browser state.
```

Keeping the route as `owner-decision-required` hides a real product path behind source inventory wording. Adding a silent fallback would be worse: if backend session revocation fails, clearing local state would make the UI look logged out while the server session remains valid.

## Goal

Make Canvas logout an active frontend contract call:

```text
UI action -> useUserStore.logout()
useUserStore.logout() -> POST /api/canvas/v1/auth/logout with Authorization: Bearer <access_token>
success -> clear browser token/user/RBAC state
failure -> keep browser session and surface the backend error
no local token -> clear local state only, because no server token exists to revoke
```

This closes the Canvas auth logout row from the `API-DRIFT-001` owner-decision backlog.

## Non-goals

```text
Do not change Go backend logout semantics.
Do not delete POST /api/canvas/v1/auth/logout.
Do not add a best-effort fallback that clears local state after backend logout failure.
Do not change login, refresh, users/me, route guard, RBAC, or Canvas billing/payment behavior.
Do not introduce a new logout route alias.
```

## Contract

### Endpoint

```text
POST /api/canvas/v1/auth/logout
Authorization: Bearer <access_token>
Body: null
Response data: null
```

### Frontend API wrapper

`canvas_front_next/src/services/api/auth.ts` must export a typed logout wrapper that calls the exact Canvas route through the existing `apiPost` helper and passes the access token as the helper token argument.

### Store behavior

`canvas_front_next/src/stores/use-user-store.ts` must expose an async `logout()` action separate from `clearSession()`:

```text
clearSession() = local browser state cleanup only
logout()       = server revocation, then local cleanup
```

If `logout()` is called with a stored token and the API call rejects, state remains authenticated and `isLoading` returns to false.

### UI behavior

`canvas_front_next/src/components/layout/user-status-actions.tsx` must call the async store logout action from the account dropdown. It must not call `clearSession()` directly for the normal logout menu item.

## Evidence rules

- `src/services/api/auth.ts` contains the exact `POST /api/canvas/v1/auth/logout` call.
- `src/stores/use-user-store.test.ts` proves successful logout revokes before clearing state.
- `src/stores/use-user-store.test.ts` proves failed backend logout preserves the session.
- `src/components/layout/user-status-actions.tsx` uses store `logout`, not `clearSession`, for the logout menu item.
- Generated frontend/backend API drift no longer lists `/api/canvas/v1/auth/logout` as backend source-only.
- API source-only route review owner-decision count drops from `3` to `2`; remaining rows are Admin AI agent test and Admin user status.

## Runtime decision

Canvas logout is an active frontend gap, not a backend-only endpoint and not a dead route.

## Verification target

```powershell
cd E:\admin_go\canvas_front_next
npm run test -- src/stores/use-user-store.test.ts src/services/api/auth.test.ts tests/shared/canvas-auth-boundary.test.ts tests/shared/canvas-rbac-shell.test.ts
npm run typecheck

cd E:\admin_go
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1 -LiveSchema
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```
