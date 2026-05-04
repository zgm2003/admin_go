# Frontend Admin Permission Patterns

## Status

Phase 1 research draft. Do not rewrite frontend UI.

Current frontend stack is local `admin_front_ts`:

```text
Vue 3
Vite
TypeScript
Element Plus
Pinia
Vue Router
Vue I18n
Axios
Tauri-related packages
```

Source file:

```text
E:\admin_go\admin_front_ts\package.json
```

## The real problem

The frontend is not just pages. Admin permission affects:

```text
login token storage
current user profile
menu tree rendering
dynamic route registration
button-level directives or helpers
API client error handling
logout / token expiry
```

## Domestic frontend references

### vue-vben-admin

Source:

```text
https://github.com/vbenjs/vue-vben-admin
https://doc.vvbin.cn/
```

What to learn:

```text
permission mode
route/menu separation
API client organization
layout and route metadata
```

What to reject:

```text
Do not rewrite current UI into Vben
Do not import its whole architecture
```

### vue-pure-admin

Source:

```text
https://github.com/pure-admin/vue-pure-admin
```

What to learn:

```text
dynamic route and menu patterns
button permission conventions
Element Plus admin UI organization
```

What to reject:

```text
Do not replace current frontend project wholesale
Do not introduce unrelated UI framework changes
```

### soybean-admin

Source:

```text
https://github.com/soybeanjs/soybean-admin
```

What to learn:

```text
Vue 3 admin permission model
route metadata structure
clean frontend module boundaries
```

What to reject:

```text
Do not chase visual redesign
Do not change UI style in backend rewrite phase
```

### RuoYi frontend permission model

Source:

```text
https://github.com/yangzongzhuan/RuoYi-Vue
https://github.com/YunaiV/ruoyi-vue-pro
```

What to learn:

```text
menu tree payload
permission string list
button permission directive shape
admin user/role/menu screens interaction
```

What to reject:

```text
Do not bring Java backend assumptions into Go
Do not clone pages blindly
```

## Current frontend adaptation principle

```text
Keep admin_front_ts UI.
Only adapt API client, auth store, menu route loading, and permission checks when contract is ready.
```

Do not start frontend adaptation until API contract exists.

## Required frontend contract later

The Go backend must eventually provide:

```text
POST /api/v1/auth/login
POST /api/v1/auth/logout
GET  /api/v1/auth/me
GET  /api/v1/auth/menus
GET  /api/v1/auth/permissions
```

But endpoint names remain draft until API Contract Agent finalizes OpenAPI.

## Current checkpoint decision

Frontend should not define backend architecture.

Frontend should consume a clean contract:

```text
user profile
roles
menu tree
permission codes
route metadata if needed
```
