# Current User `users/me` Contract, RBAC, and QuickEntry Removal Design

状态：draft for implementation。本文只固化设计和审查结论，不代表实现已完成。

## 0. Linus 三问

```text
1. 这是真问题吗？
   是。current-user bootstrap 是三端基础契约，不该同时存在 users/init、profile-owned users/me、admin-only quick_entry 特例。

2. 有更简单做法吗？
   有。只保留 GET /api/{admin,app,canvas}/v1/users/me，三端返回同一个 DTO。
   QuickEntry 没有真实价值，删掉功能、接口、前端、表，特殊情况直接消失。

3. 会破坏什么？
   会破坏仍调用 users/init 或 quick-entry 的代码、smoke、测试、文档和数据库表依赖。
   这是主动契约收口，必须一次性改掉引用点，不能保留 alias、空数组、null 或兼容字段。
```

## 1. 需求分析

### 【需求判断】

是真问题。

`/api/admin/v1/users/me` 的返回方向是对的：它是当前登录用户 bootstrap，不只是个人资料。错误是项目又引入了三个特殊情况：

```text
/users/init 作为 bootstrap 旧别名
app/canvas users/me 不归 user module 统一拥有
admin 独有 quick_entry 让三端 DTO 分叉
```

QuickEntry 本身不是核心业务能力，保留它只会制造 DTO 特例、profile/user 边界特例、表特例和前端首页特例。正确处理不是继续维护特例，而是删除。

### 【核心问题】

真正要解决的是 current-user bootstrap 的数据结构和模块归属：

```text
GET /api/admin/v1/users/me
GET /api/app/v1/users/me
GET /api/canvas/v1/users/me
```

三端只允许返回同一个 DTO：

```ts
interface CurrentUserMeResponse {
  user_id: number
  username: string
  avatar: string
  role_name: string
  permissions: PermissionMenuItem[]
  router: DynamicRouteItem[]
  buttonCodes: string[]
}
```

平台差异只来自 `platform` 下的权限数据：

```text
admin  : admin PAGE/BUTTON/menu/router
app    : app PAGE/BUTTON/router
canvas : canvas PAGE/BUTTON/router
```

### 【复杂度检查】

不接受这些“兼容”复杂度：

```text
users/init -> users/me fallback
quick_entry: []
quickEntry alias
app/canvas 返回 id/nickname/display_name/avatar_url
permissionCodes / permission_codes / button_codes alias
profile transport 继续挂 /users/me
service/presenter 用 ?? 或 || 补 contract 字段
```

### 【破坏性分析】

必须同步改：

```text
后端 route、presenter、service/repository/model、bootstrap wiring、i18n、smoke、route golden、architecture tests
数据库 users_quick_entry 表
admin 前端 quick-entry API、store、types、首页组件、i18n、测试
canvas 前端 AuthUser contract 和边界测试
docs/contracts、docs/architecture、docs/testing、admin_back_go/docs/architecture.md
```

## 2. Target REST contract

### 2.1 Canonical endpoints

只保留：

```text
GET /api/admin/v1/users/me
GET /api/app/v1/users/me
GET /api/canvas/v1/users/me
```

必须不存在：

```text
GET /api/admin/v1/users/init
GET /api/app/v1/users/init
GET /api/canvas/v1/users/init
PUT /api/admin/v1/users/me/quick-entries
```

`page-init` 仍是页面字典类接口名，不属于 current-user bootstrap：

```text
GET /api/admin/v1/users/page-init
GET /api/admin/v1/permissions/page-init
```

### 2.2 Stable field names

允许字段：

```text
user_id
username
avatar
role_name
permissions
router
buttonCodes
```

禁止字段：

```text
quick_entry
quickEntry
id
nickname
display_name
avatar_url
permissionCodes
permission_codes
button_codes
```

三端 DTO 完全一致。Admin 不再因为 QuickEntry 多一个字段。

## 3. Backend module boundary

`users/me` 全部归属 user module：

```text
admin_back_go/internal/module/user/transport/admin
admin_back_go/internal/module/user/transport/app
admin_back_go/internal/module/user/transport/canvas
```

Profile 只负责 profile read/write 和账号资料相关能力，不再拥有 current-user bootstrap，也不再拥有 QuickEntry：

```text
admin_back_go/internal/module/profile/transport/admin   # profile/security only
admin_back_go/internal/module/profile/transport/app     # GET/PUT /api/app/v1/profile
```

删除 canvas profile transport，除非未来有真实 canvas profile route；本切片不保留空模块。

服务层收口：

```go
Init(ctx, InitInput{UserID, Platform}) -> InitResponse
```

本切片不强制重命名 service 方法，避免把契约修复扩成无意义大重构。但 DTO 内必须删除 QuickEntry，repository/model/service 不得再读取 `users_quick_entry`。

## 4. QuickEntry deletion design

### 4.1 Backend deletion

删除或清理：

```text
user DTO 中 QuickEntry 字段
user model/repository/service 中 users_quick_entry 读取
profile quickentry dto/model/repository/service/test
PUT /api/admin/v1/users/me/quick-entries
router Dependencies.UserQuickEntryService
bootstrap profile.NewQuickEntryService wiring
i18n userquickentry.*
smoke quick-entry round-trip
route golden quick-entries route
architecture quick-entry ownership guard
```

### 4.2 Database deletion

新增 migration：

```text
admin_back_go/database/migrations/20260601_drop_users_quick_entry.sql
```

内容只做一件事：

```sql
DROP TABLE IF EXISTS `users_quick_entry`;
```

并加 active-runtime guard，确保后端、脚本、前端和 active docs 不再引用：

```text
users_quick_entry
quick_entry
quickEntry
QuickEntry
quick-entries
usersQuickEntry
HomeQuickEntry
UserQuickEntryService
```

允许 spec/plan 中解释删除原因；不允许运行时代码依赖这些名字。

### 4.3 Admin frontend deletion

删除：

```text
admin_front_ts/src/api/user/usersQuickEntry.ts
admin_front_ts/src/views/Main/home/components/HomeQuickEntryPanel.vue
admin_front_ts/src/views/Main/home/components/HomeQuickEntryManagerDialog.vue
admin_front_ts/src/store/user.ts 中 quickEntry 状态
admin_front_ts/src/types/user.ts 中 QuickEntryItem / quick_entry
admin_front_ts/src/i18n/locales/* 中 quickEntry 文案
admin_front_ts/tests 中 quick-entry expectations
```

首页保留真实有用的面板，例如通知、统计、待办。不要为了删除 QuickEntry 重做 dashboard。

### 4.4 Canvas frontend cleanup

Canvas `AuthUser` 与三端 DTO 对齐，不包含 QuickEntry 或 alias 字段：

```ts
export type AuthUser = {
  user_id: number
  username: string
  avatar: string
  role_name: string
  permissions: CanvasMenuItem[]
  router: CanvasBackendRoute[]
  buttonCodes: string[]
}
```

## 5. Canvas RBAC migration truth

Canvas 不是“只有按钮”。Canvas 必须有 PAGE 和 BUTTON：

```text
PAGE   决定页面/路由是否可进入
BUTTON 决定页面内动作是否可执行
```

`admin_back_go/database/migrations/20260531_canvas_front_next_integration.sql` 必须保证：

```text
auth_platforms.code = canvas 存在并启用
permissions.platform = canvas 至少包含 PAGE rows
permissions.platform = canvas 包含 BUTTON rows
BUTTON parent_id 指向对应 PAGE
默认 canvas 用户角色拥有必要 PAGE/BUTTON grant
孤儿 canvas BUTTON 被清理或归档
```

目标 PAGE：

```text
canvas_page
canvas_image_page
canvas_video_page
canvas_prompts_page
canvas_assets_page
canvas_profile_page
canvas_wallet_page
```

目标 BUTTON：

```text
canvas_access
canvas_prompt_read
canvas_asset_read
canvas_ai_image_generate
canvas_ai_video_generate
canvas_wallet_read
canvas_recharge_add
canvas_recharge_pay
```

验证必须查 live DB：

```sql
SELECT COUNT(*) FROM permissions WHERE platform='canvas' AND type=2 AND is_del=2;
SELECT COUNT(*) FROM permissions WHERE platform='canvas' AND type=3 AND parent_id > 0 AND is_del=2;
SELECT COUNT(*) FROM role_permissions rp JOIN permissions p ON p.id=rp.permission_id
WHERE p.platform='canvas' AND p.type IN (2,3) AND rp.is_del=2 AND p.is_del=2;
```

## 6. No fallback audit rule

本切片强制治理 current-user/auth/RBAC/QuickEntry 相关 fallback 和 alias。

Blocking：

```text
API response normalization 用 ?? / || 补字段
权限、路由、用户身份、token、role、buttonCodes 用 fallback
admin/app/canvas 字段互相 alias
quick_entry / quickEntry 保留为空数组或 null
```

Allowed only with explicit business reason：

```text
UI 空态展示，例如“暂无数据”
浏览器能力探测，例如 visualViewport 与 window 尺寸差异
新建根权限 parent_id=0 这种业务默认值
外部输入 validate 后的显式拒绝或归一化
```

## 7. Implementation strategy

### Phase 1: Spec/plan first

```text
更新本 spec
更新 implementation plan
自查 spec/plan 不再说 admin 保留 quick_entry
```

### Phase 2: RED guards

```text
后端架构测试禁止 users/init 和 QuickEntry active 引用
server route test 断言 /users/init 与 /quick-entries 不挂载
admin/app/canvas users/me tests 禁止 QuickEntry 和 alias 字段
frontend tests 禁止 quick-entry API/store/type/component 残留
migration guard 要求 drop users_quick_entry
```

### Phase 3: Backend removal

```text
删除 QuickEntry DTO/model/repository/service/route/deps/bootstrap/i18n/smoke 引用
补齐 user transport app/canvas
profile transport 不再挂 users/me
admin users/me 与 app/canvas users/me 走同一基础 DTO
```

### Phase 4: DB and frontend removal

```text
新增 drop users_quick_entry migration
删除 admin frontend QuickEntry API/store/types/components/i18n/tests
Canvas AuthUser 保持统一 DTO
```

### Phase 5: Canvas RBAC and verification

```text
确认 20260531_canvas_front_next_integration.sql seed PAGE/BUTTON/grants
执行 live DB migration 和 checker
跑 backend/frontend/canvas targeted tests
最后跑 full tests、build、diff/governance gates
```

## 8. Verification gates

Backend targeted：

```powershell
cd E:\admin_go\admin_back_go
go test -count=1 -p=1 ./internal/architecture ./internal/server ./internal/module/user ./internal/module/profile ./internal/module/auth
```

Backend full：

```powershell
cd E:\admin_go\admin_back_go
go test -count=1 -p=1 ./...
```

Frontend targeted：

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/user/users-api.test.ts tests/shared/home/home-dashboard.test.ts

cd E:\admin_go\canvas_front_next
npm run test -- tests/shared/canvas-auth-boundary.test.ts
```

Frontend full：

```powershell
cd E:\admin_go\admin_front_ts
npm run typecheck
npm run test
npm run build

cd E:\admin_go\canvas_front_next
npm run test
npm run typecheck
npm run build
```

DB/runtime：

```powershell
cd E:\admin_go\admin_back_go
Get-Content -Raw .\database\migrations\20260531_canvas_front_next_integration.sql | docker exec -i -e MYSQL_PWD=admin_go_local admin-go-state-mysql mysql --protocol=socket -uroot --database=admin
Get-Content -Raw .\database\migrations\20260601_drop_users_quick_entry.sql | docker exec -i -e MYSQL_PWD=admin_go_local admin-go-state-mysql mysql --protocol=socket -uroot --database=admin
powershell -ExecutionPolicy Bypass -File .\scripts\check-canvas-rbac.ps1
```

Root governance：

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

## 9. Out of scope

本切片不做：

```text
重做整个 RBAC 模型
重写登录/session/token
重构所有 profile CRUD
重做 dashboard
统一全仓所有历史 UI fallback
新增平台
新增菜单系统
```

## 10. 代码分析结论

### 【数据结构】

QuickEntry 是坏数据结构：它让一个 bootstrap DTO 在 admin 平台分叉，且价值不足以支付表、接口、store、组件和测试成本。删除后数据结构更好。

### 【特殊情况】

`users/init`、admin-only `quick_entry`、profile-owned `/users/me` 都是特殊情况。能消灭，不要隔离。

### 【复杂度】

统一 DTO 后 presenter 不需要 alias，不需要 fallback，不需要平台 if 分支决定字段集。

### 【兼容性】

这是新系统契约修正。会影响 quick-entry 调用方，所以必须删除所有 active 引用并让测试明确失败，而不是保留兼容路径。

### 【结论】

值得做，而且必须先做。否则三个平台都会继续围绕错误契约堆业务。
