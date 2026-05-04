# RBAC Models Research

## Status

Phase 1 research draft. RBAC is not finalized. Do not create tables yet.

## The real problem

Admin systems are not hard because of CRUD. They are hard because permissions leak everywhere:

```text
login state
user roles
menu tree
button permission
API permission
super admin bypass
data scope
audit log
frontend dynamic routes
```

If this model is wrong, every business module will inherit garbage.

## Domestic references to compare

### gin-vue-admin

Source:

```text
https://github.com/flipped-aurora/gin-vue-admin
https://www.gin-vue-admin.com/
```

Research points:

```text
Authority / role model
Menu model
API permission binding
Casbin usage or equivalent policy layer
Frontend dynamic route payload
```

### go-admin-team/go-admin

Source:

```text
https://github.com/go-admin-team/go-admin
```

Research points:

```text
Role-menu relation
Role-API relation
Permission code naming
Middleware check point
```

### RuoYi-style admin permission model

Source:

```text
https://github.com/yangzongzhuan/RuoYi-Vue
https://github.com/YunaiV/ruoyi-vue-pro
```

Why included:

```text
Not chosen as backend stack. Only used as mature domestic admin permission reference.
RuoYi-style menu/button/API permission thinking is widely understood by Chinese admin developers.
```

What to learn:

```text
menu tree and button permission separation
permission string conventions
frontend route generation
admin user/role/post/dept style extension points
```

What to reject:

```text
Do not copy Java layering
Do not copy enterprise ceremony
Do not copy all modules
```

## Minimum RBAC questions before implementation

These must be answered before database design:

```text
1. Is permission modeled as menu tree nodes, API resources, action codes, or separate records?
2. Are button permissions children of menu nodes or independent permissions?
3. Is API permission directly bound to role, or bound through permission records?
4. How does super admin bypass checks?
5. Does frontend receive full menu tree, route list, permission code list, or all three?
6. Is data permission in Phase 4 real, or only reserved?
7. How do operation logs know user, role, request path, and permission result?
```

## Current minimal shape to validate later

Not final table design, only a candidate mental model:

```text
admin_users
admin_roles
admin_permissions
admin_menus
admin_user_roles
admin_role_permissions
admin_operation_logs
```

Permission types to compare against open source:

```text
menu
button
api
data-reserved
```

## Current checkpoint decision

Do not self-design RBAC yet.

Next step:

```text
Read gin-vue-admin and go-admin-team RBAC source/docs
Extract exact entity fields and middleware flow
Then write final RBAC decision
```
