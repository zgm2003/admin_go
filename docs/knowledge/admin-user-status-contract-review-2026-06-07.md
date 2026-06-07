# Admin User Status Contract Review

Date: 2026-06-07

## Decision

`PATCH /api/admin/v1/users/:id/status` is an active Admin Vue frontend gap that has been closed.

It is not a backend-only endpoint and not a dead route. User status already belongs to the user list DTO; the frontend now uses the dedicated status route instead of hiding status mutation in profile edit or batch-edit.

## Source evidence

```text
Backend route:
admin_back_go/internal/module/user/transport/admin/route.go registers PATCH /api/admin/v1/users/:id/status.

Backend handler:
admin_back_go/internal/module/user/transport/admin/handler.go binds JSON { status } and calls service.ChangeStatus(ctx, id, status).

Backend service:
admin_back_go/internal/module/user/service.go validates positive id and enum.IsCommonStatus(status), then updates user status.

Backend route metadata:
admin_back_go/internal/bootstrap/route_meta.go maps PATCH /api/admin/v1/users/:id/status to user_userManager_edit and operation action change_status.

Frontend API:
admin_front_ts/src/api/user/users.ts exports UsersListApi.changeStatus and calls PATCH /api/admin/v1/users/:id/status with body { status }.

Frontend page:
admin_front_ts/src/views/Main/user/userManager/components/UserList/index.vue renders the status column and calls useCrudTable.toggleStatus(row, CommonEnum.YES|NO) under user_userManager_edit.
```

## Runtime behavior

```text
enabled user row:
  show enabled tag
  show disable action for user_userManager_edit
  call PATCH /api/admin/v1/users/:id/status with { status: 2 }

disabled user row:
  show disabled tag
  show enable action for user_userManager_edit
  call PATCH /api/admin/v1/users/:id/status with { status: 1 }
```

No fallback status value is invented. The backend remains the validator for common status legality.

## API drift result

Current 2026-06-07 generated artifacts after the later Admin AI agent test closure:

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
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/user/user-list.test.ts

cd E:\admin_go
powershell -ExecutionPolicy Bypass -File .\scripts\export-frontend-api-inventory.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\export-frontend-backend-api-drift.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\export-api-source-only-route-review.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\export-full-stack-module-map.ps1 -OutputDate 2026-06-07
```
