# Canvas Front Next Auth/RBAC Shell Hardening Implementation Plan

> 目标：修正 Canvas auth/RBAC shell 的契约漂移。后端返回 users/init-shaped payload；前端用 `router` 管页面，用 `buttonCodes` 管按钮/动作，不再造 `permissionCodes` 或字段 alias。

## Task 1: 锁住后端 Canvas current-user 契约

- 修改测试：
  - `admin_back_go/internal/module/auth/transport/canvas/handler_test.go`
  - `admin_back_go/internal/module/profile/transport/canvas/route_test.go`
- RED 断言：
  - login `data.user` 与 users/me `data` 都包含 `user_id`、`username`、`avatar`、`role_name`、`permissions`、`router`、`buttonCodes`。
  - 不包含 `id`、`nickname`、`display_name`、`avatar_url`、`permissionCodes`、`permission_codes`、`button_codes`。
- 实现：
  - `auth/transport/canvas` login 直接返回 `*user.InitResponse` 作为 `data.user`。
  - `profile/transport/canvas` users/me 直接返回 `*profile.InitResponse`。
  - 删除 Canvas 私有 user presenter/dto 映射。

验证：

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/auth/transport/canvas ./internal/module/profile/transport/canvas -count=1
```

## Task 2: 锁住前端 exact contract

- 修改测试：
  - `canvas_front_next/tests/shared/canvas-auth-boundary.test.ts`
  - `canvas_front_next/tests/shared/canvas-rbac-shell.test.ts`
- RED 断言：
  - `auth.ts` 声明 users/init-shaped fields。
  - `auth.ts` 不出现 `Partial<AuthUser>`、`display_name`、`avatar_url`、`permissionCodes`、`permission_codes`、`button_codes`、`created_at`、`updated_at`。
  - user store 保存 `routePaths` + `buttonCodes`，不保存 `permissionCodes`。

实现：

- `src/services/api/auth.ts`
  - `AuthUser` 精确使用 `user_id/username/avatar/role_name/permissions/router/buttonCodes/quick_entry`。
  - 登录和 users/me 不做 alias normalization。
- `src/stores/use-user-store.ts`
  - `routePaths = toRoutePathSet(user.router)`。
  - `can(code)` 只判断 `buttonCodes.includes(code)`。
- `src/features/rbac/canvas-permissions.ts`
  - local registry 只存 label/icon/path。
  - `hasCanvasRoute(routePaths, pathname)` 和 `visibleCanvasNavItems(routePaths)` 用 backend router path。
- `AppTopNav` / `CanvasAuthGuard` / account menu 读 `routePaths`。
- `profile/page.tsx` 显示 `username/user_id/role_name`。

验证：

```powershell
cd E:\admin_go\canvas_front_next
npm test -- tests/shared/canvas-auth-boundary.test.ts tests/shared/canvas-rbac-shell.test.ts
npm run typecheck
```

## Task 3: 同步契约文档

更新：

- `docs/contracts/admin-api-v1.md`
- `docs/status/current-status.md`
- `docs/status/module-matrix.md`
- `docs/testing/smoke-matrix.md`
- 本 spec/plan

写清：

```text
permissions -> 菜单
router -> 页面路由
buttonCodes -> BUTTON-only can(code)
```

不再写 `permissionCodes` 作为 Canvas contract。

## Task 4: 最终验证

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/auth/transport/canvas ./internal/module/profile/transport/canvas ./internal/module/permission ./internal/module/user -count=1

cd E:\admin_go\canvas_front_next
npm test -- tests/shared/canvas-auth-boundary.test.ts tests/shared/canvas-rbac-shell.test.ts tests/shared/canvas-api-boundary.test.ts src/services/api/request.test.ts
npm run typecheck

cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

不跑成功就不能写 verified。