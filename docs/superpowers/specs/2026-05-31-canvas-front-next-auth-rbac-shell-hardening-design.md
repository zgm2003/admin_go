# Canvas Front Next Auth/RBAC Shell Hardening Design

日期：2026-05-31

## 结论

这次切片的权限模型必须对齐 admin/users init 的既有契约，不再给 Canvas 另造一套 `permissionCodes` / `button_codes` / `display_name` 兼容层。

Canvas 登录返回 `data.token + data.user`；其中 `data.user` 与 `/api/canvas/v1/users/me` 的 `data` 同形：

```ts
type CanvasCurrentUser = {
  user_id: number
  username: string
  avatar: string
  role_name: string
  permissions: MenuItem[]
  router: RouteItem[]
  buttonCodes: string[]
  quick_entry: unknown[]
}
```

稳定字段名就是这些。不得新增 `id`、`nickname`、`display_name`、`avatar_url`、`permissionCodes`、`permission_codes`、`button_codes` 等 alias。

## Linus 三问

1. 这是真问题吗？是真问题。Canvas 前端如果把 PAGE 和 BUTTON 混成一个 `permissionCodes`，会和 admin 的 `permissions/router/buttonCodes` 稳定模型分叉。
2. 有更简单做法吗？有。后端直接复用 users/init payload；前端 route guard/nav 读 `router`，按钮/动作 `can(code)` 读 `buttonCodes`。
3. 会破坏什么？主要风险是已有 Canvas 页面路由和登录后 hydrate。解决方式是保留现有 URL，只更正权限数据来源。

## 权限模型

```text
permissions  -> 菜单树
router       -> 页面路由授权
buttonCodes  -> BUTTON-only，给按钮/动作 can(code)
```

PAGE 授权只进入 `permissions` 和 `router`，不进入 `buttonCodes`。BUTTON 授权只进入 `buttonCodes`。前端不能把 PAGE/BUTTON 合并成一个长期 `permissionCodes` 字段。

Canvas seed 仍包含：

```text
PAGE: canvas_page, canvas_image_page, canvas_video_page, canvas_prompts_page, canvas_assets_page, canvas_profile_page, canvas_wallet_page
BUTTON: canvas_access, canvas_prompt_read, canvas_asset_read, canvas_ai_image_generate, canvas_ai_video_generate, canvas_wallet_read, canvas_recharge_add, canvas_recharge_pay
```

## 前端边界

- `src/services/api/auth.ts` 只声明真实后端字段，不使用 `Partial<AuthUser>`，不写 alias fallback。
- `src/stores/use-user-store.ts` 保存：`token`、`user`、`routePaths`、`buttonCodes`。
- `can(code)` 只判断 `buttonCodes`。
- 顶部/移动导航和 `CanvasAuthGuard` 只用 backend `router` 派生的 route path set。
- 本地 route registry 只保存 Canvas 页面 label/icon/path 这类展示元信息，不定义后端契约。

## 非目标

- 不新增 Canvas 用户/钱包/项目表。
- 不把 prompts/assets/settings 改回浏览器直连 provider。
- 不为旧错误字段做长期兼容。
- 不引入 `CanvasPagePermissionCode + CanvasActionPermissionCode` 这种新分叉命名；保持一套按钮 code 给 `can()`，页面授权走 `router`。

## 验收标准

- `/api/canvas/v1/auth/login` 的 `data.user` 和 `/api/canvas/v1/users/me` 返回 users/init-shaped payload。
- 响应里没有 `display_name`、`avatar_url`、`permissionCodes`、`permission_codes`、`button_codes`。
- `buttonCodes` 只包含 BUTTON code。
- route guard/nav 不再用 BUTTON code 判断页面访问，而是用 `router.path`。
- 登录页、captcha dialog、401/403 处理继续保留本切片既有行为。

## 验证

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