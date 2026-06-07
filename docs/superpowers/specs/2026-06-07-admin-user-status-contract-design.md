# Admin User Status Contract Design

Date: 2026-06-07

## Problem

`PATCH /api/admin/v1/users/:id/status` exists in the Go backend and has route metadata, handler, service, repository, and tests. The Admin Vue user list does not call it. The current page only exposes edit/delete/batch profile updates, so the route stays in the source-only owner-decision backlog.

This is a real frontend gap, not a backend-only endpoint. User status is already present in `UserListItem.status`, and other admin modules expose status changes through a dedicated `changeStatus` wrapper instead of hiding the mutation inside general edit/batch-edit flows.

## Goal

Make user status an explicit Admin Vue action:

```text
UsersListApi.changeStatus({ id, status })
  -> PATCH /api/admin/v1/users/:id/status
  -> body { status }

UserList page:
  display user.status as enabled/disabled
  allow user_userManager_edit holders to enable/disable through useCrudTable.toggleStatus
```

This removes `PATCH /api/admin/v1/users/:id/status` from the `API-DRIFT-001` owner-decision backlog.

## Component map

```text
UserList/index.vue:
  existing route-level composition surface for search/table/dialogs.
  This slice only adds a status column and reuses the existing useCrudTable.toggleStatus action.

UsersListApi:
  owns the REST endpoint shape and positive id normalization.

tests/shared/user/user-list.test.ts:
  guards the frontend API wrapper and page wiring so the source-only route does not regress.
```

No new component is introduced. Splitting the existing user list page would be a separate refactor; doing it here would mix a contract fix with layout churn.

## Non-goals

```text
Do not change Go backend route/service semantics.
Do not add a new permission code; backend already maps status route to user_userManager_edit.
Do not route status changes through batchEdit or update profile.
Do not add fallback status defaults.
Do not rewrite the user list page or CRUD primitives.
```

## Contract

### Endpoint

```text
PATCH /api/admin/v1/users/:id/status
Body: { status: number }
Permission: user_userManager_edit
Response: data {}
```

`status` uses the existing common status values:

```text
1 = enabled
2 = disabled
```

### Frontend behavior

- `UsersListApi.changeStatus` must use a dedicated PATCH `/users/:id/status` request.
- The user list table must include a `status` column.
- Enable/disable buttons must use `toggleStatus(row, CommonEnum.YES|NO)`.
- Button visibility must stay guarded by `userStore.can('user_userManager_edit')`.
- Existing edit, delete, batch edit, export behavior must remain unchanged.

## Evidence rules

- `admin_front_ts/src/api/user/users.ts` contains a dedicated `changeStatus` wrapper.
- `admin_front_ts/src/views/Main/user/userManager/components/UserList/index.vue` imports `CommonEnum`, destructures `toggleStatus`, renders the status column, and calls `toggleStatus` for enable/disable.
- `admin_front_ts/tests/shared/user/user-list.test.ts` guards the wrapper and page wiring.
- Generated API drift no longer lists `PATCH /api/admin/v1/users/:id/status` as source-only.
- API source-only route review owner-decision count drops from `2` to `1`; the remaining row is `POST /api/admin/v1/ai-agents/:id/test`.

## Verification target

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/user/user-list.test.ts
npm run typecheck

cd E:\admin_go
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1 -LiveSchema
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```
