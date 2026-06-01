# Canvas Profile Wallet Recharge Parity Design

日期：2026-06-01
状态：approved for planning；本文件只定义下一切片设计，不代表 runtime 已完成。
范围：`canvas_front_next` 个人资料、我的钱包、充值菜单/页面，以及必要的 `admin_back_go` canvas profile transport 和 canvas RBAC seed。参照 `admin_front_ts` 当前个人资料、钱包和充值契约，但不复制 Vue UI 组件，也不改 admin 系统既有行为。

---

## 需求判断

【需求判断】
是真问题。当前 `canvas_front_next` 的 `/profile` 只读前端 `users/me` session 字段，缺少 admin 个人资料页已有的 profile service、资料编辑字典和安全信息；`/wallet` 只显示 summary + transactions 的最小列表；充值已有后端 canvas recharge transport，但前端没有独立菜单和页面入口。

【核心问题】
要让 Canvas 用户侧的个人资料、钱包、充值使用 `admin_go` 已有 profile / wallet / payment recharge 服务作为事实源，而不是在 Next 前端里用 session 字段或临时 UI 掩盖缺口。

【复杂度检查】
不需要新 `canvas_users`、`canvas_wallets`、`canvas_recharge` 表，不需要 Next BFF，不需要重做 admin payment/recharge 业务。正确做法是补 canvas transport 和 Next 页面/API adapter。

【破坏性分析】
不能破坏现有 `/api/canvas/v1/users/me` bootstrap、登录、Canvas 创作工具导航、admin/Vue 支付菜单、已有 wallet/payment service 语义。新增 `/recharge` 是 Canvas 页面路由，不改变 admin `/payment/recharge`。

---

## 现状证据

- `canvas_front_next/src/app/(user)/profile/page.tsx` 当前只读 `useUserStore().user`，且有 `user?.username ?? "-"` 这类展示兜底；它没有调用 profile service。
- `canvas_front_next/src/app/(user)/wallet/page.tsx` 当前调用 `/api/canvas/v1/wallet/summary` 和 `/api/canvas/v1/wallet/transactions`，但没有充值入口页面。
- `admin_back_go/internal/module/payment/wallet/transport/canvas` 已有 `GET /api/canvas/v1/wallet/summary` 和 `GET /api/canvas/v1/wallet/transactions`。
- `admin_back_go/internal/module/payment/transport/canvas` 已有 `GET/POST /api/canvas/v1/payment/recharges` 与 `POST /:id/pay`。
- `admin_back_go/internal/module/profile/transport/canvas` 当前被架构测试明确禁止存在；这次需求需要把该边界改成允许并实现，因为用户要求个人资料与 admin 系统服务一致。
- `admin_front_ts` 的个人资料契约是 `GET/PUT /api/admin/v1/profile`，安全操作是 `/profile/security/{phone,email,password}`；钱包契约是 `/wallet/summary`、`/wallet/transactions`；充值契约是 `/payment/recharges/*`。

---

## 数据结构

### Profile

Canvas profile 不新增 DTO 结构。后端直接复用 `profile.ProfileResponse`：

```ts
type CanvasProfileResponse = {
  profile: {
    user_id: number
    username: string
    email: string
    avatar: string
    phone: string
    role_id: number
    role_name: string
    address_id: number
    detail_address: string
    sex: number
    birthday: string
    bio: string
    is_self: number
    has_password: boolean
  }
  dict: {
    auth_address_tree: AddressTreeNode[]
    sexArr: Array<{ label: string; value: number }>
    verify_type_arr: Array<{ label: string; value: "password" | "code" }>
  }
}
```

Canvas update 只接受 admin profile 当前已支持的安全字段：`username`、`avatar`、`sex`、`birthday`、`address_id`、`detail_address`、`bio`。不新增 nickname/display_name/avatar_url alias。

### Wallet

Canvas wallet 类型与 admin current-user wallet API 对齐：

```ts
type CanvasWalletSummary = {
  balance_cents: number
  balance_text: string
  total_recharge_cents: number
  total_recharge_text: string
  total_consume_cents: number
  total_consume_text: string
}

type CanvasWalletTransaction = {
  id: number
  transaction_no: string
  direction: "in" | "out"
  direction_text: string
  amount_cents: number
  amount_text: string
  balance_before_cents: number
  balance_before_text: string
  balance_after_cents: number
  balance_after_text: string
  source_type: "recharge" | "ai_generate" | "ai_refund"
  source_type_text: string
  source_id: number
  remark: string
  created_at: string
}
```

不接受 `total_recharge_cents?` 这类可选兜底；如果后端缺字段，应让 type/test 暴露，而不是前端吞掉。

### Recharge

Canvas recharge 复用 payment recharge response：

```ts
type CanvasRechargeInit = {
  wallet: CanvasWalletSummary
  packages: RechargePackageItem[]
  payment_method: RechargePaymentMethod
  dict: { status_arr: DictOption<RechargeStatus>[] }
  recent: RechargeListItem[]
}
```

创建充值：`POST /api/canvas/v1/payment/recharges`，body 只包含：

```ts
{
  package_code: string
  pay_method: "web" | "h5"
  return_url: string
}
```

---

## 路由和权限

### Canvas 页面路由

保留现有页面：

```text
/profile   个人资料
/wallet    我的钱包
```

新增页面：

```text
/recharge  充值
```

新增 PAGE permission：

```text
canvas_recharge_page
path=/recharge
component=recharge
show_menu=2
sort=80
```

现有 BUTTON permissions 继续复用：

```text
canvas_wallet_read
canvas_recharge_add
canvas_recharge_pay
```

账号下拉菜单展示规则：

```text
个人资料：hasCanvasRoute(routePaths, "/profile")
我的钱包：hasCanvasRoute(routePaths, "/wallet") && can("canvas_wallet_read")
充值：hasCanvasRoute(routePaths, "/recharge") && can("canvas_recharge_add")
```

不把充值加入顶部创作工具栏。顶部栏继续只放 Canvas、图片、视频、提示词、素材这类创作工具。

---

## 后端设计

### 新增 canvas profile transport

创建：

```text
admin_back_go/internal/module/profile/transport/canvas/route.go
admin_back_go/internal/module/profile/transport/canvas/handler.go
admin_back_go/internal/module/profile/transport/canvas/request.go
admin_back_go/internal/module/profile/transport/canvas/handler_test.go
```

暴露：

```text
GET /api/canvas/v1/profile
PUT /api/canvas/v1/profile
```

实现原则：

- 复用 `profile.AppService` 或与 app profile 同级的最小接口。
- `AuthIdentity.Platform` 必须是 `canvas`，否则 401。
- `Profile(ctx, identity.UserID, identity.UserID)` 直接返回 profile service 结果。
- `PUT` 复用 `profile.UpdateProfileInput`，成功后返回最新 profile，避免前端保存后再猜本地状态。
- 本切片不做 `/profile/security/*`，因为验证码/密码安全页牵涉独立交互；个人资料先对齐基础资料和字典服务。

### migration

新增 migration：

```text
admin_back_go/database/migrations/20260601_canvas_profile_wallet_recharge_menu.sql
```

作用：

- upsert `canvas_recharge_page`。
- 将 `canvas_recharge_add`、`canvas_recharge_pay` 的 parent 指向 recharge page。
- 保留 `canvas_wallet_read` 挂在 wallet page。
- 给 active roles 授予新的 canvas PAGE permission。
- 同步修正 `auth_platforms.canvas` 和 canvas labels，避免之前 mojibake 复发。

---

## 前端设计

### API adapter

拆出/新增：

```text
canvas_front_next/src/services/api/profile.ts
canvas_front_next/src/services/api/wallet.ts
canvas_front_next/src/services/api/recharge.ts
```

保留 `settings.ts` 只负责 `/api/canvas/v1/settings`，不继续混 wallet API。

### `/profile`

`src/app/(user)/profile/page.tsx` 改为服务驱动页面：

- mount 后用 token 调 `fetchProfile(token)`。
- 展示基本资料表单：头像 URL、用户名、性别、生日、地址、详细地址、简介。
- 保存时 `updateProfile(token, payload)`，用服务返回的新 profile 替换页面状态。
- 不使用 `user?.x ?? "-"` 作为业务兜底；加载前显示 Spin，加载成功后按后端数据渲染。
- 安全资料只显示邮箱/手机号/是否设置密码，不在本切片实现绑定/改密。

### `/wallet`

`src/app/(user)/wallet/page.tsx` 改为和 admin 个人钱包一致的结构：

- summary 三卡：余额、累计充值、累计消费。
- 资金明细表：流水号、方向、金额、变动前、变动后、来源、备注、时间。
- 显示“去充值”按钮，只有 `hasCanvasRoute("/recharge") && can("canvas_recharge_add")` 时可见。

### `/recharge`

新增：

```text
canvas_front_next/src/app/(user)/recharge/page.tsx
```

页面职责：

- 调 `fetchRechargeInit(token)`。
- 展示套餐卡片、支付方式、当前余额和最近充值记录。
- `can("canvas_recharge_add")` 才能创建充值。
- `can("canvas_recharge_pay")` 才能继续支付 pending/paying 记录。
- 创建充值 body 的 `return_url` 用当前 `window.location.origin + "/recharge"`，不让用户自由输入。
- 有 `pay_url` 时用 `window.location.href = pay_url` 或新窗口打开，保持最小实现。

---

## 测试策略

### RED/GREEN 顺序

1. 后端先写 profile canvas transport 测试，确认当前没有 route 会失败。
2. 后端再写 migration/static architecture 测试，确认缺 `canvas_recharge_page` 会失败。
3. 前端写 shared boundary tests，确认 profile 仍读 store、wallet 仍混 settings API、recharge page 缺失会失败。
4. 最小实现后跑 targeted tests。

### 必跑验证

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/profile/transport/canvas ./internal/module/payment/transport/canvas ./internal/module/payment/wallet/transport/canvas ./internal/architecture -count=1

cd E:\admin_go\canvas_front_next
npm run test -- tests/shared/canvas-profile-wallet-recharge.test.ts tests/shared/canvas-rbac-shell.test.ts tests/shared/canvas-api-boundary.test.ts
npm run typecheck
npm run build

cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

### live DB 验证

迁移应用后必须查 live MySQL：

```sql
SELECT code,path,name,parent_id,show_menu FROM permissions WHERE platform='canvas' AND code IN ('canvas_profile_page','canvas_wallet_page','canvas_recharge_page','canvas_wallet_read','canvas_recharge_add','canvas_recharge_pay') ORDER BY sort,id;
SELECT COUNT(*) AS mojibake_count FROM permissions WHERE platform='canvas' AND name REGEXP '[Ãæç]';
```

---

## 非目标

- 不新增 Canvas 独立用户、钱包、充值表。
- 不实现云端 canvas_projects 同步。
- 不改 admin_front_ts 的支付/钱包页面。
- 不把充值放进顶部创作工具导航。
- 不在 Next Route Handler 里代理 profile/wallet/recharge。
- 不给缺失字段写 silent fallback。
- 不实现绑定邮箱、绑定手机号、修改密码；这些作为后续 security slice。

---

## 验收标准

- `/profile` 调用 `/api/canvas/v1/profile`，不再只展示 `users/me` session 字段。
- `/wallet` 调用 wallet API service，summary 字段完整且不可选。
- `/recharge` 页面存在，并调用 `/api/canvas/v1/payment/recharges/page-init`、create、pay。
- 账号下拉包含 `个人资料 / 我的钱包 / 充值`，均受 backend router + buttonCodes 控制。
- live DB 有 `canvas_recharge_page`，且 canvas permission label 无乱码。
- 后端 Docker rebuild 后 `/health`、`/ready` 通过；无 token 请求 canvas protected route 仍 401。

---

## 自检

- 没有占位符。
- 没有新增表设计。
- 没有把 PAGE/BUTTON 权限混用。
- 个人资料安全修改被明确排除，避免把验证码/密码流程混进本切片。
- 计划可以拆成后端 profile、DB/RBAC、前端 API/page、验证四个可回滚任务。
