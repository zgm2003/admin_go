# Platform-as-scope, not platform-as-module design

Date: 2026-05-27
Status: draft for user review
Owner: Codex

## Problem

The current backend still has both `internal/module/auth` and `internal/module/appauth`. `appauth` is not a full duplicate of auth business logic: it calls `auth.Service` for login-config, send-code, login, and logout. The problem is architectural naming and boundary drift: `appauth` makes a platform entry point look like a business module.

If this pattern continues, every new platform can accidentally create a new set of platform-named modules such as `merchantauth`, `merchantuser`, `merchantupload`, or `partnernotification`. That turns the system from modular business capabilities into duplicated platform slices.

## Core rule

Platform is a scope, policy, and transport dimension. Platform is not a module.

Modules are business capabilities:

```text
auth
user
upload
notification
payment
permission
```

Platforms are access surfaces:

```text
admin
app
merchant
partner
openapi
```

A new platform must not create a new `xxxauth`, `xxxuser`, `xxxupload`, or similar package by default. A new module is allowed only when there is a new business capability with its own lifecycle, data ownership, and rules.

## Current evidence

Current auth business logic is already platform-aware:

- `auth.Service.LoginConfig(ctx, platform)` reads login policy by platform.
- `auth.Service.Login(ctx, auth.LoginInput{ Platform: ... })` issues platform-scoped sessions.
- `auth_platforms` is the policy source for login types, captcha, token TTL, and session behavior.
- middleware already defaults bearer platform by path, including `/api/app/v1/* -> app`.

`appauth` currently adds a platform HTTP wrapper, forces `platform=app`, and adapts the response shape. It also mixes non-auth app endpoints such as current user, profile, and upload-token into the same package. That package should not become the template for future platform expansion.

## Goals

1. Keep one business module per capability.
2. Make platform variation explicit through route registration options, platform scope, policy lookup, and response presenters.
3. Remove the architectural incentive to add platform-named modules for shared capabilities.
4. Preserve existing public API paths while moving ownership to the correct module.
5. Keep admin/app contract compatibility during the migration.

## Non-goals

- Do not redesign the entire router tree.
- Do not merge unrelated app profile or upload-token behavior into `auth`.
- Do not change token format, session storage, or `auth_platforms` schema in this slice.
- Do not add a generic framework that hides module ownership.
- Do not add fallback aliases for old and new response fields.

## Design principles

### Module ownership

A module owns business rules, data access, service orchestration, and route registration for its capability. Platform-specific routes may exist inside the same module as transport adapters, but the module name remains business-oriented.

### Platform scope

Every platform-specific route must declare its platform explicitly at registration time or derive it from a single path-scoped rule. Service inputs that need platform behavior must carry `Platform` as a field.

### Presenter boundary

Different platforms may need different response shapes. That variation belongs in small presenters or response mappers, not in duplicated services.

Example:

```text
auth service result -> admin presenter -> current admin login response
auth service result -> app presenter   -> { token, user }
```

### Policy source

Login policy remains in `auth_platforms`. Adding a platform should mainly add policy data and route registration, not new modules.

## Target auth shape

The target auth package should own both admin and platform auth routes:

```text
internal/module/auth
  service.go
  handler.go                 # current admin-compatible auth handler
  platform_handler.go        # platform auth HTTP adapter
  route.go                   # admin route registration
  platform_route.go          # reusable platform route registration
  presenter.go               # response mappers where needed
```

A platform route registration should look conceptually like:

```go
auth.RegisterPlatformRoutes(router, auth.PlatformRouteOptions{
    Prefix:   "/api/app/v1/auth",
    Platform: enum.PlatformApp,
})
```

A future platform should add another registration, not another `xxxauth` package:

```go
auth.RegisterPlatformRoutes(router, auth.PlatformRouteOptions{
    Prefix:   "/api/merchant/v1/auth",
    Platform: enum.PlatformMerchant,
})
```

## App-specific non-auth endpoints

The current `appauth` package also owns app current-user/profile/upload-token routes:

```text
GET  /api/app/v1/users/me
GET  /api/app/v1/profile
PUT  /api/app/v1/profile
POST /api/app/v1/upload-tokens
```

These should not move into `auth`. They should be assigned to business modules or narrow platform route adapters:

```text
user module        -> /api/app/v1/users/me, /api/app/v1/profile, PUT /api/app/v1/profile
uploadtoken module -> /api/app/v1/upload-tokens
```

If a small platform adapter is needed, it must live under the owning business module, not under `appauth`.

## Migration outline

### Slice 1: auth routes only

Move app auth endpoints from `appauth` into `auth` without changing paths:

```text
GET  /api/app/v1/auth/login-config
GET  /api/app/v1/auth/captcha
POST /api/app/v1/auth/send-code
POST /api/app/v1/auth/login
POST /api/app/v1/auth/logout
```

`auth` should still call the existing auth service and force `platform=app` for app auth routes. The app login response remains `{ token, user }` if the current app contract requires it.

### Slice 2: app current-user/profile/upload ownership

Move remaining app endpoints out of `appauth` into the owning modules:

```text
user        owns current user and profile app routes
uploadtoken owns app upload token route
```

After this slice, `internal/module/appauth` should be removed.

## Testing requirements

Before implementation, write failing tests that prove the new architecture:

1. App auth routes still exist under `/api/app/v1/auth/*`.
2. App auth routes force `platform=app` and ignore a conflicting `platform` header.
3. Admin auth routes keep current `/api/admin/v1/auth/*` behavior.
4. No `internal/module/appauth` package remains after the full migration slice.
5. App login response shape remains compatible with the current frontend contract.
6. App current-user/profile/upload routes still work after moving to their owning modules.

Existing focused tests to preserve or update:

```text
admin_back_go/internal/server/router_test.go
admin_back_go/internal/module/auth/handler_test.go
admin_back_go/internal/module/appauth/* tests or their replacements
```

## Documentation requirements

Update these docs when implementation lands:

```text
docs/status/current-status.md
docs/contracts/admin-api-v1.md
admin_back_go/docs/architecture.md
docs/architecture/04-go-backend-framework.md
```

The docs must state the hard rule:

```text
Platform is not a module. New platforms must not create platform-named business modules by default.
```

## Acceptance criteria

- No new platform-named auth module is introduced.
- App auth endpoints are owned by `internal/module/auth` or a clearly auth-owned transport adapter.
- Shared auth business logic remains single-source.
- App profile/upload endpoints are not moved into auth.
- Adding a future platform requires route registration and policy data, not a new `xxxauth` package.
- Tests and docs describe the platform-as-scope rule clearly.

## Self-review

- Placeholder scan: no unfinished placeholder markers remain.
- Scope check: the design is limited to platform/module boundaries, with auth migration as the first concrete slice.
- Consistency check: auth owns auth; user/uploadtoken own non-auth app endpoints; platform stays a route/policy dimension.
- Ambiguity check: the rule for when to create a module is explicit: only for a new business capability, not for a new platform.
