# Canvas Profile Wallet Recharge Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 `canvas_front_next` 的个人资料、我的钱包、充值入口复用 `admin_go` 现有 profile / wallet / payment recharge 服务，并新增受 RBAC 控制的 Canvas 充值菜单。

**Architecture:** 后端只补 Canvas platform HTTP transport 和 RBAC seed；profile、wallet、payment recharge 业务仍由现有 modules/services 拥有。Next 前端新增 profile/wallet/recharge API adapters，页面只调用 `/api/canvas/v1/*`，页面访问由 `router` 控制，按钮/动作由 `buttonCodes` 控制。

**Tech Stack:** Go + Gin + GORM + MySQL；Next.js App Router + React + TypeScript + Ant Design + Zustand；Vitest + Go tests + Docker-first backend verification。

---

## Scope Gates

- 不新增 `canvas_users`、`canvas_wallets`、`canvas_recharges`、`canvas_credit_logs`、`canvas_settings` 表。
- 不改 `admin_front_ts` 页面或 admin `/api/admin/v1/*` 契约。
- 不改 `/api/canvas/v1/users/me` bootstrap shape。
- 不把充值放进顶部创作工具导航；充值只进账号菜单和钱包页按钮。
- 不实现邮箱/手机号/密码安全修改；本计划只做基础资料读取/保存和安全状态展示。
- 不写 silent fallback：字段是后端契约保证就设为必填；缺字段让类型检查/测试失败。

## File Structure Map

### Root docs
- Created: `docs/superpowers/specs/2026-06-01-canvas-profile-wallet-recharge-parity-design.md`
- Create: `docs/superpowers/plans/2026-06-01-canvas-profile-wallet-recharge-parity.md`
- Modify after implementation: `docs/status/current-status.md`, `docs/status/module-matrix.md`, `docs/contracts/admin-api-v1.md` only if runtime behavior actually changes and verification passes.

### Backend `admin_back_go`
- Create: `internal/module/profile/transport/canvas/route.go`
- Create: `internal/module/profile/transport/canvas/handler.go`
- Create: `internal/module/profile/transport/canvas/request.go`
- Create: `internal/module/profile/transport/canvas/handler_test.go`
- Modify: route registration file that mounts profile transports.
- Modify: `internal/architecture/multiplatform_boundary_test.go`
- Create: `database/migrations/20260601_canvas_profile_wallet_recharge_menu.sql`
- Modify: `internal/architecture/canvas_front_next_integration_test.go`

### Frontend `canvas_front_next`
- Create: `tests/shared/canvas-profile-wallet-recharge.test.ts`
- Create: `src/services/api/profile.ts`
- Create: `src/services/api/wallet.ts`
- Create: `src/services/api/recharge.ts`
- Modify: `src/services/api/settings.ts`
- Modify: `src/app/(user)/profile/page.tsx`
- Modify: `src/app/(user)/wallet/page.tsx`
- Create: `src/app/(user)/recharge/page.tsx`
- Modify: `src/features/rbac/canvas-permissions.ts`
- Modify: `src/components/layout/user-status-actions.tsx`

---

### Task 1: Backend RED, lock Canvas profile transport and recharge seed

**Files:**
- Create: `admin_back_go/internal/module/profile/transport/canvas/handler_test.go`
- Modify: `admin_back_go/internal/architecture/multiplatform_boundary_test.go`
- Modify: `admin_back_go/internal/architecture/canvas_front_next_integration_test.go`

- [ ] **Step 1: Write failing Canvas profile transport test**

Create `E:/admin_go/admin_back_go/internal/module/profile/transport/canvas/handler_test.go`. The test must define a fake `profile.AppService`, mount `RegisterRoutes(router, service)`, then assert:

```go
GET /api/canvas/v1/profile -> data.profile.username == "canvas-user"
PUT /api/canvas/v1/profile -> service.updateInput.UserID == 8
wrong AuthIdentity.Platform=admin -> HTTP 401
```

Use this exact fake shape:

```go
type fakeCanvasProfileService struct {
    profileResult *profile.ProfileResponse
    updateInput   profile.UpdateProfileInput
}

func (f *fakeCanvasProfileService) Profile(ctx context.Context, userID int64, currentUserID int64) (*profile.ProfileResponse, *apperror.Error) {
    if userID != 8 || currentUserID != 8 {
        return nil, apperror.BadRequest("unexpected user id")
    }
    return f.profileResult, nil
}

func (f *fakeCanvasProfileService) UpdateProfile(ctx context.Context, input profile.UpdateProfileInput) *apperror.Error {
    f.updateInput = input
    return nil
}
```

- [ ] **Step 2: Change architecture boundary test**

In `E:/admin_go/admin_back_go/internal/architecture/multiplatform_boundary_test.go`, move these two paths from `mustNotExist` to `mustExist` inside `TestUserProfileTransportShape`:

```go
"internal/module/profile/transport/canvas/route.go",
"internal/module/profile/transport/canvas/handler.go",
```

Keep all other assertions unchanged.

- [ ] **Step 3: Add migration guard test**

Append to `E:/admin_go/admin_back_go/internal/architecture/canvas_front_next_integration_test.go`:

```go
func TestCanvasRechargeMenuMigration(t *testing.T) {
    migration := readCanvasIntegrationFile(t, "database/migrations/20260601_canvas_profile_wallet_recharge_menu.sql")
    for _, want := range []string{"SET NAMES utf8mb4", "canvas_recharge_page", "'/recharge'", "'recharge'", "'menu.canvas_recharge'", "canvas_wallet_read", "canvas_recharge_add", "canvas_recharge_pay", "INSERT INTO `role_permissions`"} {
        assertCanvasContains(t, migration, want)
    }
    for _, forbidden := range []string{"CREATE TABLE `canvas_users`", "CREATE TABLE `canvas_wallets`", "CREATE TABLE `canvas_recharges`", "CREATE TABLE `canvas_credit_logs`"} {
        assertCanvasNotContains(t, migration, forbidden)
    }
}
```

- [ ] **Step 4: Run RED**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/profile/transport/canvas ./internal/architecture -run "CanvasProfile|CanvasRechargeMenu|UserProfileTransportShape" -count=1
```

Expected: FAIL because canvas profile transport and migration do not exist.

---

### Task 2: Backend GREEN, implement canvas profile transport

**Files:**
- Create: `admin_back_go/internal/module/profile/transport/canvas/route.go`
- Create: `admin_back_go/internal/module/profile/transport/canvas/handler.go`
- Create: `admin_back_go/internal/module/profile/transport/canvas/request.go`
- Modify: the profile route registration file found by `rg -n "profile.*RegisterRoutes|profileadmin|profileapp" internal/server internal/bootstrap`

- [ ] **Step 1: Add route file**

Create `route.go`:

```go
package canvas

import (
    "admin_back_go/internal/module/profile"
    "admin_back_go/internal/shared/validate"
    "github.com/gin-gonic/gin"
)

func RegisterRoutes(router *gin.Engine, service profile.AppService) {
    validate.MustRegister()
    handler := NewHandler(service)
    group := router.Group("/api/canvas/v1/profile")
    group.GET("", handler.Profile)
    group.PUT("", handler.UpdateProfile)
}
```

- [ ] **Step 2: Add request file**

Create `request.go`:

```go
package canvas

type updateProfileRequest struct {
    Username      string  `json:"username" binding:"required,max=64"`
    Avatar        string  `json:"avatar" binding:"omitempty,max=512"`
    Sex           int     `json:"sex" binding:"omitempty,oneof=0 1 2"`
    Birthday      *string `json:"birthday" binding:"omitempty,max=10"`
    AddressID     *int64  `json:"address_id" binding:"required"`
    DetailAddress string  `json:"detail_address" binding:"omitempty,max=255"`
    Bio           string  `json:"bio" binding:"omitempty,max=500"`
}
```

- [ ] **Step 3: Add handler file**

Create `handler.go` with these key branches:

```go
func (h *Handler) Profile(c *gin.Context) {
    identity, ok := h.canvasIdentity(c)
    if !ok { return }
    if h.service == nil {
        response.Error(c, apperror.InternalKey("profile.service_missing", nil, "用户资料服务未配置"))
        return
    }
    result, appErr := h.service.Profile(c.Request.Context(), identity.UserID, identity.UserID)
    if appErr != nil { response.Error(c, appErr); return }
    if result == nil {
        response.Error(c, apperror.InternalKey("canvas.profile.result_missing", nil, "个人资料信息未返回"))
        return
    }
    response.OK(c, result)
}
```

`UpdateProfile` must bind `updateProfileRequest`, reject `AddressID == nil`, call `profile.UpdateProfileInput`, then return fresh `h.service.Profile(...)`. `canvasIdentity` must reject missing user and non-canvas platform with `auth.token.invalid_or_expired` / `auth.platform.invalid`.

- [ ] **Step 4: Mount route**

Import:

```go
profilecanvas "admin_back_go/internal/module/profile/transport/canvas"
```

Register using the existing user/profile service instance:

```go
profilecanvas.RegisterRoutes(router, deps.UserService)
```

Do not create another service.

- [ ] **Step 5: Run backend GREEN**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/profile/transport/canvas ./internal/architecture -run "CanvasProfile|UserProfileTransportShape" -count=1
```

Expected: PASS for profile transport and boundary shape.

---
### Task 3: DB/RBAC migration for `/recharge`

**Files:**
- Create: `admin_back_go/database/migrations/20260601_canvas_profile_wallet_recharge_menu.sql`

- [ ] **Step 1: Create migration**

Create `E:/admin_go/admin_back_go/database/migrations/20260601_canvas_profile_wallet_recharge_menu.sql`:

```sql
-- Add Canvas recharge page permission and keep Canvas labels UTF-8/idempotent.
SET NAMES utf8mb4;

UPDATE `auth_platforms`
SET `name` = '无限画布', `updated_at` = CURRENT_TIMESTAMP
WHERE `code` = 'canvas';

INSERT INTO `permissions` (`name`, `path`, `icon`, `parent_id`, `component`, `platform`, `type`, `sort`, `code`, `i18n_key`, `show_menu`, `status`, `is_del`)
SELECT '充值', '/recharge', 'CreditCard', 0, 'recharge', 'canvas', 2, 80, 'canvas_recharge_page', 'menu.canvas_recharge', 2, 1, 2
WHERE NOT EXISTS (
  SELECT 1 FROM `permissions` WHERE `platform` = 'canvas' AND `code` = 'canvas_recharge_page' AND `is_del` = 2
)
ON DUPLICATE KEY UPDATE
  `name` = VALUES(`name`), `path` = VALUES(`path`), `icon` = VALUES(`icon`),
  `parent_id` = VALUES(`parent_id`), `component` = VALUES(`component`), `type` = VALUES(`type`),
  `sort` = VALUES(`sort`), `i18n_key` = VALUES(`i18n_key`), `show_menu` = VALUES(`show_menu`),
  `status` = VALUES(`status`), `is_del` = VALUES(`is_del`), `updated_at` = CURRENT_TIMESTAMP;

SET @canvas_wallet_page_id := (SELECT `id` FROM `permissions` WHERE `platform` = 'canvas' AND `code` = 'canvas_wallet_page' AND `is_del` = 2 LIMIT 1);
SET @canvas_recharge_page_id := (SELECT `id` FROM `permissions` WHERE `platform` = 'canvas' AND `code` = 'canvas_recharge_page' AND `is_del` = 2 LIMIT 1);

UPDATE `permissions`
SET `name` = CASE `code`
    WHEN 'canvas_profile_page' THEN '个人资料'
    WHEN 'canvas_wallet_page' THEN '我的钱包'
    WHEN 'canvas_recharge_page' THEN '充值'
    WHEN 'canvas_wallet_read' THEN '读取钱包'
    WHEN 'canvas_recharge_add' THEN '创建充值'
    WHEN 'canvas_recharge_pay' THEN '支付充值'
    ELSE `name`
  END,
  `parent_id` = CASE
    WHEN `code` = 'canvas_wallet_read' THEN @canvas_wallet_page_id
    WHEN `code` IN ('canvas_recharge_add', 'canvas_recharge_pay') THEN @canvas_recharge_page_id
    ELSE `parent_id`
  END,
  `updated_at` = CURRENT_TIMESTAMP
WHERE `platform` = 'canvas'
  AND `is_del` = 2
  AND `code` IN ('canvas_profile_page','canvas_wallet_page','canvas_recharge_page','canvas_wallet_read','canvas_recharge_add','canvas_recharge_pay');

INSERT INTO `role_permissions` (`role_id`, `permission_id`, `is_del`)
SELECT r.`id`, p.`id`, 2
FROM `roles` r
JOIN `permissions` p ON p.`platform` = 'canvas' AND p.`code` IN ('canvas_recharge_page','canvas_recharge_add','canvas_recharge_pay') AND p.`is_del` = 2 AND p.`status` = 1
LEFT JOIN `role_permissions` rp ON rp.`role_id` = r.`id` AND rp.`permission_id` = p.`id` AND rp.`is_del` = 2
WHERE r.`is_del` = 2 AND rp.`id` IS NULL;
```

- [ ] **Step 2: Run migration guard**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture -run CanvasRechargeMenuMigration -count=1
```

Expected: PASS.

- [ ] **Step 3: Apply to live Docker MySQL**

```powershell
cd E:\admin_go\admin_back_go
docker cp database/migrations/20260601_canvas_profile_wallet_recharge_menu.sql admin-go-state-mysql:/tmp/20260601_canvas_profile_wallet_recharge_menu.sql
docker exec admin-go-state-mysql sh -lc 'mysql --default-character-set=utf8mb4 -uroot -padmin_go_local admin < /tmp/20260601_canvas_profile_wallet_recharge_menu.sql'
```

Expected: exit code 0.

- [ ] **Step 4: Verify live DB**

```powershell
docker exec admin-go-state-mysql mysql --default-character-set=utf8mb4 -uroot -padmin_go_local admin -e "SELECT code,path,name,parent_id,show_menu FROM permissions WHERE platform='canvas' AND code IN ('canvas_profile_page','canvas_wallet_page','canvas_recharge_page','canvas_wallet_read','canvas_recharge_add','canvas_recharge_pay') ORDER BY sort,id; SELECT COUNT(*) AS mojibake_count FROM permissions WHERE platform='canvas' AND name REGEXP '[Ãæç]';"
```

Expected: `canvas_recharge_page` exists with `/recharge` and `mojibake_count=0`.

---

### Task 4: Frontend RED, lock API/page/menu behavior

**Files:**
- Create: `canvas_front_next/tests/shared/canvas-profile-wallet-recharge.test.ts`

- [ ] **Step 1: Write shared test**

Create `E:/admin_go/canvas_front_next/tests/shared/canvas-profile-wallet-recharge.test.ts`:

```ts
import { describe, expect, test } from "vitest";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

const root = process.cwd();
const read = (path: string) => readFileSync(join(root, path), "utf8");

describe("canvas profile wallet recharge parity", () => {
    test("profile uses canvas profile service instead of users/me session fallback", () => {
        expect(existsSync(join(root, "src/services/api/profile.ts"))).toBe(true);
        const api = read("src/services/api/profile.ts");
        const page = read("src/app/(user)/profile/page.tsx");
        expect(api).toContain('"/api/canvas/v1/profile"');
        expect(api).toContain("fetchProfile(token: string)");
        expect(api).toContain("updateProfile(token: string");
        expect(api).toContain("has_password: boolean");
        expect(page).toContain("fetchProfile(token)");
        expect(page).toContain("updateProfile(token");
        expect(page).not.toContain("user?.username ??");
        expect(page).not.toContain("user?.user_id ??");
    });

    test("wallet api is split from settings and exposes required fields", () => {
        expect(existsSync(join(root, "src/services/api/wallet.ts"))).toBe(true);
        const walletApi = read("src/services/api/wallet.ts");
        const settingsApi = read("src/services/api/settings.ts");
        const walletPage = read("src/app/(user)/wallet/page.tsx");
        expect(walletApi).toContain('"/api/canvas/v1/wallet/summary"');
        expect(walletApi).toContain('"/api/canvas/v1/wallet/transactions"');
        expect(walletApi).toContain("total_recharge_cents: number");
        expect(walletApi).toContain("total_consume_cents: number");
        expect(walletApi).toContain("balance_before_text: string");
        expect(walletApi).not.toContain("total_recharge_cents?:");
        expect(settingsApi).not.toContain("fetchWalletSummary");
        expect(settingsApi).not.toContain("fetchWalletTransactions");
        expect(walletPage).toContain("fetchWalletSummary(token)");
        expect(walletPage).toContain("/recharge");
        expect(walletPage).toContain("canvas_recharge_add");
    });

    test("recharge page and account menu use router plus buttonCodes", () => {
        expect(existsSync(join(root, "src/app/(user)/recharge/page.tsx"))).toBe(true);
        const api = read("src/services/api/recharge.ts");
        const page = read("src/app/(user)/recharge/page.tsx");
        const registry = read("src/features/rbac/canvas-permissions.ts");
        const menu = read("src/components/layout/user-status-actions.tsx");
        expect(api).toContain('"/api/canvas/v1/payment/recharges/page-init"');
        expect(api).toContain("createRecharge(token: string");
        expect(api).toContain("payRecharge(token: string");
        expect(page).toContain("fetchRechargeInit(token)");
        expect(page).toContain("canvas_recharge_add");
        expect(page).toContain("canvas_recharge_pay");
        expect(page).toContain("window.location.origin");
        expect(registry).toContain('path: "/recharge"');
        expect(registry).toContain("showInTopNav: false");
        expect(menu).toContain('hasCanvasRoute(routePaths, "/recharge")');
        expect(menu).toContain('can("canvas_recharge_add")');
        expect(menu).toContain('href="/recharge"');
    });
});
```

- [ ] **Step 2: Run RED**

```powershell
cd E:\admin_go\canvas_front_next
npm run test -- tests/shared/canvas-profile-wallet-recharge.test.ts
```

Expected: FAIL until adapters/pages/menu are implemented.

---
### Task 5: Frontend GREEN, add API adapters

**Files:**
- Create: `canvas_front_next/src/services/api/profile.ts`
- Create: `canvas_front_next/src/services/api/wallet.ts`
- Create: `canvas_front_next/src/services/api/recharge.ts`
- Modify: `canvas_front_next/src/services/api/settings.ts`

- [ ] **Step 1: Add profile API**

Create `src/services/api/profile.ts` with required functions and exact endpoint:

```ts
export async function fetchProfile(token: string) {
    return apiGet<CanvasProfileResponse>("/api/canvas/v1/profile", undefined, token);
}

export async function updateProfile(token: string, payload: CanvasProfileUpdatePayload) {
    return apiPut<CanvasProfileResponse>("/api/canvas/v1/profile", payload, token);
}
```

Types must include required `profile.has_password: boolean`, `dict.auth_address_tree`, `dict.sexArr`, and `dict.verify_type_arr`.

- [ ] **Step 2: Add wallet API**

Create `src/services/api/wallet.ts` with required `CanvasWalletSummary` fields:

```ts
balance_cents: number;
balance_text: string;
total_recharge_cents: number;
total_recharge_text: string;
total_consume_cents: number;
total_consume_text: string;
```

Expose:

```ts
fetchWalletSummary(token: string)
fetchWalletTransactions(token: string, query?: CanvasWalletTransactionQuery)
```

Use `/api/canvas/v1/wallet/summary` and `/api/canvas/v1/wallet/transactions`.

- [ ] **Step 3: Add recharge API**

Create `src/services/api/recharge.ts` exposing:

```ts
fetchRechargeInit(token: string)
fetchRecharges(token: string, query?: { currentPage?: number; pageSize?: number; status?: CanvasRechargeStatus | "" })
createRecharge(token: string, payload: CanvasRechargeCreatePayload)
payRecharge(token: string, id: number)
```

Use only `/api/canvas/v1/payment/recharges*` endpoints. Do not introduce Next route handlers.

- [ ] **Step 4: Trim settings API**

In `src/services/api/settings.ts`, remove wallet fetch functions. If `CanvasSettings.wallet` still exists, import the type:

```ts
import type { CanvasWalletSummary } from "@/services/api/wallet";
```

- [ ] **Step 5: Run partial GREEN**

```powershell
cd E:\admin_go\canvas_front_next
npm run test -- tests/shared/canvas-profile-wallet-recharge.test.ts
```

Expected: API assertions pass; page/menu assertions may still fail until Task 6.

---

### Task 6: Frontend GREEN, pages and menu

**Files:**
- Modify: `canvas_front_next/src/app/(user)/profile/page.tsx`
- Modify: `canvas_front_next/src/app/(user)/wallet/page.tsx`
- Create: `canvas_front_next/src/app/(user)/recharge/page.tsx`
- Modify: `canvas_front_next/src/features/rbac/canvas-permissions.ts`
- Modify: `canvas_front_next/src/components/layout/user-status-actions.tsx`

- [ ] **Step 1: Add `/recharge` registry item**

In `canvas-permissions.ts`, import `CreditCard` and add:

```ts
{ slug: "recharge", path: "/recharge", label: "充值", icon: CreditCard, showInTopNav: false },
```

- [ ] **Step 2: Add account menu item**

In `user-status-actions.tsx`, after wallet item add:

```tsx
...(hasCanvasRoute(routePaths, "/recharge") && can("canvas_recharge_add") ? [{ key: "recharge", label: <Link href="/recharge">充值</Link> }] : []),
```

- [ ] **Step 3: Rewrite profile page**

`profile/page.tsx` must use:

```tsx
const token = useUserStore((state) => state.token);
const isReady = useUserStore((state) => state.isReady);
const [profile, setProfile] = useState<CanvasProfileResponse | null>(null);

useEffect(() => {
    if (!isReady || !token) return;
    void fetchProfile(token).then(setProfile);
}, [isReady, token]);

async function saveProfile(values: CanvasProfileUpdatePayload) {
    if (!token) return;
    const nextProfile = await updateProfile(token, values);
    setProfile(nextProfile);
}
```

Render loading with `Spin`; render an Ant Design `Form` after profile loads. Do not keep `user?.username ?? "-"` or `user?.user_id ?? "-"`.

- [ ] **Step 4: Rewrite wallet page**

Import wallet API from `@/services/api/wallet`. Add:

```tsx
const routePaths = useUserStore((state) => state.routePaths);
const showRecharge = hasCanvasRoute(routePaths, "/recharge") && can("canvas_recharge_add");
```

Render summary cards for balance, total recharge, and total consume. Render transaction columns: `transaction_no`, `direction_text`, `amount_text`, `balance_before_text`, `balance_after_text`, `source_type_text`, `remark`, `created_at`. Show `<Link href="/recharge">去充值</Link>` only when `showRecharge` is true.

- [ ] **Step 5: Create recharge page**

`recharge/page.tsx` must call `fetchRechargeInit(token)`, show package cards, and create recharge with:

```tsx
const result = await createRecharge(token, {
    package_code: selectedPackageCode,
    pay_method: "web",
    return_url: `${window.location.origin}/recharge`,
});
if (result.pay_url) window.location.href = result.pay_url;
```

Continue pay must call:

```tsx
const result = await payRecharge(token, id);
if (result.pay_url) window.location.href = result.pay_url;
```

Guard create by `can("canvas_recharge_add")`; guard continue pay by `can("canvas_recharge_pay")`.

- [ ] **Step 6: Run frontend GREEN**

```powershell
cd E:\admin_go\canvas_front_next
npm run test -- tests/shared/canvas-profile-wallet-recharge.test.ts tests/shared/canvas-rbac-shell.test.ts tests/shared/canvas-api-boundary.test.ts
npm run typecheck
```

Expected: PASS.

---

### Task 7: Runtime verification and docs sync

**Files:**
- Modify after runtime passes: `docs/status/current-status.md`, `docs/status/module-matrix.md`, `docs/contracts/admin-api-v1.md`

- [ ] **Step 1: Rebuild/restart backend Docker**

```powershell
cd E:\admin_go\admin_back_go
docker compose -f deploy/docker-first/docker-compose.yml up -d --build
```

Expected: API container healthy.

- [ ] **Step 2: Verify readiness**

```powershell
curl.exe -fsS http://127.0.0.1:8080/health
curl.exe -fsS http://127.0.0.1:8080/ready
```

Expected: `/health` status ok; `/ready` database/redis/token_redis/queue_redis/realtime all up.

- [ ] **Step 3: Verify protected routes are mounted and still protected**

```powershell
curl.exe -i http://127.0.0.1:8080/api/canvas/v1/profile
curl.exe -i http://127.0.0.1:8080/api/canvas/v1/payment/recharges/page-init
```

Expected: HTTP 401 JSON envelope, not 404.

- [ ] **Step 4: Run frontend production build**

```powershell
cd E:\admin_go\canvas_front_next
npm run build
```

Expected: PASS and route list includes `/profile`, `/wallet`, `/recharge`, `/login`.

- [ ] **Step 5: Sync docs only after runtime passes**

Add concrete verified wording to status/contract docs. Use this shape only after all checks pass:

```text
2026-06-01 Canvas profile/wallet/recharge parity verified: Canvas profile uses /api/canvas/v1/profile, wallet uses split /wallet summary/transactions API, /recharge route and account menu entry use backend router plus canvas_recharge_* button codes, live DB has canvas_recharge_page, and backend Docker /health /ready plus Next tests/type/build passed.
```

- [ ] **Step 6: Run governance gates**

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected: both PASS. This plan should not touch `.codex/hooks*`.

---

## Final Acceptance Checklist

- [ ] Backend `GET/PUT /api/canvas/v1/profile` mounted and rejects wrong platform.
- [ ] Live DB contains `canvas_recharge_page` and no Canvas label mojibake.
- [ ] `/profile` no longer depends on `user?.username ??` session fallback.
- [ ] `/wallet` imports wallet API from `src/services/api/wallet.ts`, not settings.
- [ ] `/recharge` exists and uses page-init/create/pay endpoints.
- [ ] Account menu has 个人资料 / 我的钱包 / 充值, gated by `router` + `buttonCodes`.
- [ ] Targeted Go tests pass.
- [ ] Targeted Vitest tests, `npm run typecheck`, and `npm run build` pass.
- [ ] Docker-first backend `/health` and `/ready` pass after rebuild.
- [ ] Root governance gates pass.

## Execution Notes

- Existing root workspace has unrelated dirty docs and prior `canvas_front_next` changes. Before committing, inspect `git -C E:\admin_go status --short`, `git -C E:\admin_go\admin_back_go status --short`, and `git -C E:\admin_go\canvas_front_next status --short`; do not stage unrelated docs.
- If implementing with subagents, assign Task 2/3 to backend and Task 4/5/6 to frontend, then run Task 7 inline for final runtime proof.
- If a RED test passes unexpectedly, stop and inspect whether behavior already exists; do not rewrite passing tests to force failure.
