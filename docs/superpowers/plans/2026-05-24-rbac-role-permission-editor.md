# RBAC Role Permission Editor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把角色权限编辑器、`users/init` 权限响应、后端 `PermissionCheck` 统一到真实 `DIR / PAGE / BUTTON` 模型：`PAGE = 页面访问`，`BUTTON = 页面动作`，对前端公开的 `buttonCodes` 只包含 BUTTON code。

**Architecture:** MySQL `permissions` / `role_permissions` 仍是权限真相源，Redis 只做性能缓存。因为项目未上线，本计划不做旧缓存兼容：直接拆出内部 `RouteAccessCodes` / route access grant cache，`PermissionCheck` 使用 `PAGE code + BUTTON code`，前端 `buttonCodes` 只用于按钮显隐。角色授权 UI 不创建 `view` / “查看”虚拟 BUTTON。

**Tech Stack:** Go 1.x modular monolith, table-driven Go tests, Gin route metadata, Redis route access grant cache, Vue 3 Composition API with `<script setup lang="ts">`, Pinia, vue-i18n, Vitest, `vue-tsc`, Markdown contracts/governance docs.

---

## Scope Check

In scope:

```text
1. role_permissions 只保存真实 PAGE/BUTTON；DIR 只作为 permissions 定义树分组。
2. BUTTON 授权继续由 Go service 自动补父 PAGE。
3. users/init.buttonCodes 改成 BUTTON-only。
4. PermissionCheck 改用内部 RouteAccessCodes：PAGE code + BUTTON code。
5. Redis 权限缓存直接重命名为 route access grant cache，不保留旧 button grant key。
6. 角色编辑器文案从“查看/页面查看”改为“页面访问”。
7. 文档、单测、前端测试、治理检查同步。
```

Out of scope:

```text
1. 不引入 Casbin。
2. 不改 users.role_id 单角色模型。
3. 不引入数据权限。
4. 不创建 view / xxx_view / 查看 虚拟 BUTTON。
5. 不重写整套前端 router/menu。
```

关键旧实现待重构点：

```text
admin_back_go/internal/module/permission/service.go 当前把 PAGE/BUTTON 的 code 都放进 ButtonCodes。
admin_back_go/internal/bootstrap/route_meta.go 当前让 GET/read route 使用 PAGE code，例如 payment_config_list。
这不是兼容旧语义；这是 clean cut 的重构顺序：公开 ButtonCodes 改成 BUTTON-only 的同时，PermissionCheck 必须切到内部 RouteAccessCodes。
```

## File Structure

Backend RBAC context:

```text
Modify: admin_back_go/internal/module/permission/model.go
Modify: admin_back_go/internal/module/permission/service.go
Modify: admin_back_go/internal/module/permission/service_test.go
Modify: admin_back_go/internal/module/permission/cache.go
```

Backend route permission check:

```text
Modify: admin_back_go/internal/bootstrap/app.go
Modify: admin_back_go/internal/bootstrap/permission_checker.go
Modify: admin_back_go/internal/bootstrap/permission_checker_test.go
Modify: admin_back_go/internal/module/user/service.go
Modify: admin_back_go/internal/module/user/service_test.go
Modify: admin_back_go/internal/module/role/service.go
Modify: admin_back_go/internal/module/role/service_test.go
Modify: admin_back_go/internal/module/permission/management_service_test.go
Modify: admin_back_go/scripts/full-admin-smoke.ps1
```

Frontend role editor:

```text
Modify: admin_front_ts/src/views/Main/permission/role/index.vue
Modify: admin_front_ts/src/i18n/locales/zh-CN.ts
Modify: admin_front_ts/src/i18n/locales/en-US.ts
Modify: admin_front_ts/tests/shared/permission/role-matrix.test.ts
Modify: admin_front_ts/tests/shared/permission/role-matrix-ui.test.ts
```

Docs:

```text
Modify: docs/superpowers/specs/2026-05-24-rbac-role-permission-editor-design.md
Modify: docs/contracts/admin-api-v1.md
Modify: docs/architecture/04-go-backend-framework.md
Modify: admin_back_go/docs/architecture.md
Modify: docs/status/current-status.md only after tests pass
Read/required DB audit: live permissions table for _view/view BUTTON residue
```

Vue component map:

```text
role/index.vue
  责任：API init/list/save、active platform、form.permission_id、submit payload 编排。
  约束：route-level composition surface，不拥有矩阵行细节。

RolePermissionMatrix.vue
  责任：展示 PAGE access checkbox + BUTTON action checkbox，emit update:modelValue。
  约束：props down / events up，不发 API，不直接读 store。

role-matrix.ts
  责任：纯函数转换 permission_tree、toggle PAGE/BUTTON、计算组权限 id。
  约束：无 Vue state、无 API、用 Vitest 覆盖行为。
```

---

### Task 0: Audit view-button residue before refactor

**Files:**
- Read: live MySQL `permissions` / `role_permissions`
- Read: `admin_back_go/database/migrations/*`
- Read: `admin.sql` if present

- [ ] **Step 1: Search tracked SQL for view-style button codes**

Run:

```powershell
cd E:\admin_go
rg -n "(_view|page_view|code.*view|view')" admin_back_go\database admin.sql -S
```

Expected in current repo: no active permission seed/migration rows for `view` / `_view` BUTTON codes.

- [ ] **Step 2: Audit live DB for view-style BUTTON residue**

Run against the current local MySQL target:

This project uses `is_del = 2` / `CommonNo` for normal rows.

```sql
SELECT id, code, name
FROM permissions
WHERE is_del = 2
  AND type = 3
  AND (code LIKE '%\_view' ESCAPE '\\' OR code = 'view' OR code LIKE '%page_view%');
```

Expected: `0 rows`.

- [ ] **Step 3: Clean view-style BUTTON residue if Step 2 is non-zero**

Skip this step only when Step 2 returns `0 rows`.

Run this clean-cut cleanup against the same live DB. Project is not online, so do not preserve old virtual `view` BUTTON rows and do not add compatibility code.

```sql
START TRANSACTION;

CREATE TEMPORARY TABLE tmp_rbac_view_button_ids AS
SELECT id
FROM permissions
WHERE is_del = 2
  AND type = 3
  AND (code LIKE '%\_view' ESCAPE '\\' OR code = 'view' OR code LIKE '%page_view%');

DELETE rp
FROM role_permissions rp
JOIN tmp_rbac_view_button_ids v ON v.id = rp.permission_id;

DELETE p
FROM permissions p
JOIN tmp_rbac_view_button_ids v ON v.id = p.id;

SELECT COUNT(*) AS remaining_view_button_rows
FROM permissions
WHERE is_del = 2
  AND type = 3
  AND (code LIKE '%\_view' ESCAPE '\\' OR code = 'view' OR code LIKE '%page_view%');

COMMIT;
```

Expected: `remaining_view_button_rows = 0`.

- [ ] **Step 4: Record result in implementation handoff**

If Step 1 and Step 2 are clean, final implementation handoff should say:

```text
view/xxx_view BUTTON residue audit: clean; no migration needed.
```

If Step 2 found rows and they were removed, final implementation handoff must include the exact SQL/script and row count.

### Task 1: Backend role normalization guard tests

**Files:**
- Modify: `admin_back_go/internal/module/role/service_test.go`
- Read: `admin_back_go/internal/module/role/service.go`

- [ ] **Step 1: Add table-driven normalization tests**

Append this test near `TestServiceListNormalizesRolePermissionIDsWithPageParents`:

```go
func TestNormalizeAssignablePermissionIDsKeepsOnlyActivePageAndButtonGrants(t *testing.T) {
	const disabledStatus = 2
	permissions := []permission.Permission{
		{ID: 1, Type: permission.TypeDir, ParentID: permission.RootParentID, Status: permission.StatusActive, IsDel: permission.CommonNo},
		{ID: 2, Type: permission.TypePage, ParentID: 1, Status: permission.StatusActive, IsDel: permission.CommonNo},
		{ID: 3, Type: permission.TypeButton, ParentID: 2, Status: permission.StatusActive, IsDel: permission.CommonNo},
		{ID: 4, Type: permission.TypePage, ParentID: 1, Status: disabledStatus, IsDel: permission.CommonNo},
		{ID: 5, Type: permission.TypeButton, ParentID: 4, Status: permission.StatusActive, IsDel: permission.CommonNo},
		{ID: 6, Type: permission.TypePage, ParentID: 1, Status: permission.StatusActive, IsDel: permission.CommonYes},
		{ID: 7, Type: permission.TypeButton, ParentID: 6, Status: permission.StatusActive, IsDel: permission.CommonNo},
	}

	tests := []struct {
		name string
		ids  []int64
		want []int64
	}{
		{name: "page only keeps page", ids: []int64{2}, want: []int64{2}},
		{name: "button implies parent page", ids: []int64{3}, want: []int64{2, 3}},
		{name: "dir is ignored", ids: []int64{1}, want: []int64{}},
		{name: "dir mixed with page and button is not persisted", ids: []int64{1, 3, 2}, want: []int64{2, 3}},
		{name: "disabled page and child button are ignored", ids: []int64{4, 5}, want: []int64{}},
		{name: "deleted page and child button are ignored", ids: []int64{6, 7}, want: []int64{}},
		{name: "unknown and duplicate ids are removed", ids: []int64{999, 3, 3, 2}, want: []int64{2, 3}},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := normalizeAssignablePermissionIDs(tt.ids, permissions)
			if !reflect.DeepEqual(got, tt.want) {
				t.Fatalf("normalizeAssignablePermissionIDs(%#v) = %#v, want %#v", tt.ids, got, tt.want)
			}
		})
	}
}
```

- [ ] **Step 2: Run role tests**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/role -run "TestNormalizeAssignablePermissionIDsKeepsOnlyActivePageAndButtonGrants|TestServiceListNormalizesRolePermissionIDsWithPageParents|TestServiceCreateSyncsNormalizedPermissionsInTransaction" -count=1
```

Expected before implementation: FAIL. Current `normalizeAssignablePermissionIDs` saves a BUTTON before checking whether its parent PAGE is active, so the disabled/deleted parent subtests expose the bug.

- [ ] **Step 3: Patch normalization**

Update the `permission.TypeButton` branch in `normalizeAssignablePermissionIDs` so a BUTTON is saved only when its parent PAGE exists in the active assignable permission map:

```go
case permission.TypeButton:
	parent, ok := permissionMap[row.ParentID]
	if ok && parent.Type == permission.TypePage {
		result[parent.ID] = struct{}{}
		result[id] = struct{}{}
	}
```

Do not save orphan BUTTON grants whose parent PAGE is not active/assignable.

- [ ] **Step 4: Run role package verification**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/role -count=1
go test -race ./internal/module/role -count=1
```

Expected: PASS.

---

### Task 2: Split public ButtonCodes from internal RouteAccessCodes

**Files:**
- Modify: `admin_back_go/internal/module/permission/model.go`
- Modify: `admin_back_go/internal/module/permission/service.go`
- Modify: `admin_back_go/internal/module/permission/service_test.go`

- [ ] **Step 1: Replace the current PAGE-code-as-button test**

In `admin_back_go/internal/module/permission/service_test.go`, replace `TestServiceBuildContextPageCodeIsButtonGrantForReadOnlyRoutes` with:

```go
func TestServiceBuildContextPageCodeIsRouteAccessCodeButNotButtonCode(t *testing.T) {
	repo := &fakeRepository{
		grantedIDs: []int64{2},
		perms: []Permission{
			{ID: 1, Name: "支付管理", ParentID: 0, Type: TypeDir, Platform: "admin", Path: "/payment", Sort: 1, ShowMenu: CommonYes},
			{ID: 2, Name: "支付配置", ParentID: 1, Type: TypePage, Platform: "admin", Path: "/payment/config", Component: "payment/config", Code: "payment_config_list", Sort: 2, ShowMenu: CommonYes},
		},
	}
	svc := NewService(repo, []string{"admin"})

	got, appErr := svc.BuildContextByRole(context.Background(), 7, "admin")

	if appErr != nil {
		t.Fatalf("expected no app error, got %v", appErr)
	}
	if len(got.ButtonCodes) != 0 {
		t.Fatalf("PAGE code must not leak into public buttonCodes, got %#v", got.ButtonCodes)
	}
	if !reflect.DeepEqual(got.RouteAccessCodes, []string{"payment_config_list"}) {
		t.Fatalf("PAGE code must remain available for PermissionCheck, got %#v", got.RouteAccessCodes)
	}
	if len(got.Router) != 1 || got.Router[0].Path != "/payment/config" {
		t.Fatalf("expected page route to remain, got %#v", got.Router)
	}
	if got.Router[0].ViewKey != "payment/config" {
		t.Fatalf("payment route view key must not include /index, got %#v", got.Router[0])
	}
}
```

- [ ] **Step 2: Update BUTTON grant context test**

In `TestServiceBuildContextAddsAncestorMenusRoutesAndButtonCodes`, make the PAGE fixture carry a page-access code:

```go
{ID: 2, Name: "用户管理", ParentID: 1, Type: TypePage, Platform: "admin", Path: "/user", Component: "user/index", Code: "user_list", Sort: 10, ShowMenu: 1},
```

Then assert both outputs:

```go
if !reflect.DeepEqual(got.ButtonCodes, []string{"user_add"}) {
	t.Fatalf("buttonCodes mismatch: %#v", got.ButtonCodes)
}
if !reflect.DeepEqual(got.RouteAccessCodes, []string{"user_list", "user_add"}) {
	t.Fatalf("routeAccessCodes must include PAGE code and BUTTON code, got %#v", got.RouteAccessCodes)
}
```

- [ ] **Step 3: Verify failing tests before implementation**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/permission -run "TestServiceBuildContextPageCodeIsRouteAccessCodeButNotButtonCode|TestServiceBuildContextAddsAncestorMenusRoutesAndButtonCodes" -count=1
```

Expected before implementation: FAIL because `Context.RouteAccessCodes` does not exist and PAGE code still enters `ButtonCodes`.

- [ ] **Step 4: Add RouteAccessCodes to permission.Context**

In `admin_back_go/internal/module/permission/model.go`, change:

```go
type Context struct {
	Permissions []MenuItem  `json:"permissions"`
	Router      []RouteItem `json:"router"`
	ButtonCodes []string    `json:"buttonCodes"`
}
```

to:

```go
type Context struct {
	Permissions      []MenuItem  `json:"permissions"`
	Router           []RouteItem `json:"router"`
	ButtonCodes      []string    `json:"buttonCodes"`
	RouteAccessCodes []string    `json:"-"`
}
```

- [ ] **Step 5: Update buildContext to produce two code sets**

In `admin_back_go/internal/module/permission/service.go`, inside `buildContext`, initialize:

```go
buttonCodes := make([]string, 0)
routeAccessCodes := make([]string, 0)
seenButton := map[string]struct{}{}
seenRouteAccess := map[string]struct{}{}

appendUniqueCode := func(target *[]string, seen map[string]struct{}, code string) {
	code = strings.TrimSpace(code)
	if code == "" {
		return
	}
	if _, ok := seen[code]; ok {
		return
	}
	seen[code] = struct{}{}
	*target = append(*target, code)
}
```

Replace the old `(TypePage || TypeButton)` block with:

```go
switch permission.Type {
case TypePage:
	appendUniqueCode(&routeAccessCodes, seenRouteAccess, permission.Code)
case TypeButton:
	appendUniqueCode(&buttonCodes, seenButton, permission.Code)
	appendUniqueCode(&routeAccessCodes, seenRouteAccess, permission.Code)
}
```

Return:

```go
return Context{
	Permissions:      buildPermissionTree(menus),
	Router:           router,
	ButtonCodes:      buttonCodes,
	RouteAccessCodes: routeAccessCodes,
}
```

- [ ] **Step 6: Run permission tests**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/permission -count=1
go test -race ./internal/module/permission -count=1
```

Expected: PASS.

---

### Task 3: Replace button grant cache with route access grant cache

**Files:**
- Modify: `admin_back_go/internal/module/permission/model.go`
- Modify: `admin_back_go/internal/module/permission/service.go`
- Modify: `admin_back_go/internal/module/permission/cache.go`
- Modify: `admin_back_go/internal/bootstrap/app.go`
- Modify: `admin_back_go/internal/bootstrap/permission_checker.go`
- Modify: `admin_back_go/internal/bootstrap/permission_checker_test.go`
- Modify: `admin_back_go/internal/module/user/service.go`
- Modify: `admin_back_go/internal/module/user/service_test.go`
- Modify: `admin_back_go/internal/module/role/service.go`
- Modify: `admin_back_go/internal/module/role/service_test.go`
- Modify: `admin_back_go/internal/module/permission/management_service_test.go`
- Modify: `admin_back_go/scripts/full-admin-smoke.ps1`

- [ ] **Step 1: Rename cache key schema**

In `admin_back_go/internal/module/permission/model.go`, replace:

```go
ButtonCacheKeySchema = "rbac_page_grants"
```

with:

```go
RouteAccessCacheKeySchema = "rbac_route_access_grants"
```

In `admin_back_go/internal/module/permission/service.go`, replace `ButtonCacheKey` with:

```go
func RouteAccessCacheKey(userID int64, platform string) string {
	return fmt.Sprintf("auth_perm_uid_%d_%s_%s", userID, platform, RouteAccessCacheKeySchema)
}
```

Remove or stop using `ButtonCacheKey`. Because the project is not online, do not keep old key compatibility.

- [ ] **Step 2: Rename Redis cache wrapper comments**

In `admin_back_go/internal/module/permission/cache.go`, rename the concrete type and constructor directly:

```go
RedisButtonGrantCache -> RedisRouteAccessGrantCache
NewRedisButtonGrantCache -> NewRedisRouteAccessGrantCache
```

Use this wording:

```go
// RedisRouteAccessGrantCache stores computed RBAC route access grant codes by user and platform.
// The cached value may contain PAGE codes and BUTTON codes; it is not the public users/init buttonCodes contract.
```

- [ ] **Step 3: Add PermissionChecker tests for PAGE and BUTTON route access**

In `admin_back_go/internal/bootstrap/permission_checker_test.go`, add:

```go
func TestPermissionCheckerAllowsPageRouteAccessCode(t *testing.T) {
	checker := PermissionCheckerFor(
		&fakePermissionUserRepository{user: &user.User{ID: 12, RoleID: 3}, role: &user.Role{ID: 3}},
		&fakePermissionContextBuilder{ctx: permission.Context{ButtonCodes: []string{}, RouteAccessCodes: []string{"payment_config_list"}}},
		nil,
		0,
	)

	appErr := checker(context.Background(), middleware.PermissionInput{UserID: 12, Platform: "admin", Code: "payment_config_list"})

	if appErr != nil {
		t.Fatalf("expected PAGE route access code to pass PermissionCheck, got %#v", appErr)
	}
}

func TestPermissionCheckerAllowsButtonRouteAccessCode(t *testing.T) {
	checker := PermissionCheckerFor(
		&fakePermissionUserRepository{user: &user.User{ID: 12, RoleID: 3}, role: &user.Role{ID: 3}},
		&fakePermissionContextBuilder{ctx: permission.Context{ButtonCodes: []string{"payment_config_edit"}, RouteAccessCodes: []string{"payment_config_list", "payment_config_edit"}}},
		nil,
		0,
	)

	appErr := checker(context.Background(), middleware.PermissionInput{UserID: 12, Platform: "admin", Code: "payment_config_edit"})

	if appErr != nil {
		t.Fatalf("expected BUTTON route access code to pass PermissionCheck, got %#v", appErr)
	}
}
```

Update existing cache tests to expect the new key:

```go
auth_perm_uid_12_admin_rbac_route_access_grants
```

Also update existing `permission_checker_test.go` fixtures in the same pass:

```text
fakePermissionButtonCache -> fakePermissionRouteAccessCache
permissionButtonCache -> permissionRouteAccessCache
Context{ButtonCodes: ...} used by PermissionChecker tests -> Context{RouteAccessCodes: ...}
TestPermissionCheckerAllowsOwnedButtonCode -> TestPermissionCheckerAllowsOwnedRouteAccessCode
TestPermissionCheckerDeniesMissingButtonCode -> TestPermissionCheckerDeniesMissingRouteAccessCode
TestPermissionCheckerAllowsCachedButtonCodeWithoutBuildingContext -> TestPermissionCheckerAllowsCachedRouteAccessCodeWithoutBuildingContext
TestPermissionCheckerBuildsAndCachesButtonCodesOnCacheMiss -> TestPermissionCheckerBuildsAndCachesRouteAccessCodesOnCacheMiss
```

The old key assertions currently appear in three places and all must change:

```text
permission_checker_test.go line ~170 getKey/setKey
permission_checker_test.go line ~216 getKey
permission_checker_test.go line ~242 setKey
```

- [ ] **Step 4: Update PermissionCheckerFor**

In `admin_back_go/internal/bootstrap/permission_checker.go`, replace button-code cache variables with route access variables:

```go
cacheKey := permission.RouteAccessCacheKey(currentUser.ID, input.Platform)
routeAccessCodes, hit := cachedRouteAccessCodes(ctx, cache, cacheKey)
if !hit {
	permissionContext, appErr := builder.BuildContextByRole(ctx, currentUser.RoleID, input.Platform)
	if appErr != nil {
		return appErr
	}
	routeAccessCodes = permissionContext.RouteAccessCodes
	if cache != nil {
		_ = cache.Set(ctx, cacheKey, routeAccessCodes, cacheTTL)
	}
}

for _, ownedCode := range routeAccessCodes {
	if ownedCode == code {
		return nil
	}
}
return apperror.ForbiddenKey("permission.api.denied", nil, "无接口权限")
```

Rename helper:

```go
func cachedRouteAccessCodes(ctx context.Context, cache permissionRouteAccessCache, key string) ([]string, bool) {
	if cache == nil {
		return nil, false
	}
	values, hit, err := cache.Get(ctx, key)
	if err != nil {
		return nil, false
	}
	return values, hit
}
```

Rename the local interface; this is not optional because the project is not online and stale button naming is misleading:

```go
type permissionRouteAccessCache interface {
	Get(ctx context.Context, key string) ([]string, bool, error)
	Set(ctx context.Context, key string, values []string, ttl time.Duration) error
}
```

- [ ] **Step 5: Update users/init cache write**

In `admin_back_go/internal/module/user/service.go`, cache `perm.RouteAccessCodes` but return `perm.ButtonCodes`:

```go
if s.routeAccessCache != nil {
	_ = s.routeAccessCache.Set(ctx, permission.RouteAccessCacheKey(currentUser.ID, input.Platform), perm.RouteAccessCodes, s.routeAccessCacheTTL)
}
```

Keep response:

```go
ButtonCodes: perm.ButtonCodes,
```

Rename the user service cache contract and fields in the same task; this is not optional:

```go
defaultButtonCacheTTL      -> defaultRouteAccessCacheTTL
ButtonCache                -> RouteAccessGrantCache
buttonCache                -> routeAccessCache
buttonCacheTTL             -> routeAccessCacheTTL
invalidateUserButtonCache  -> invalidateUserRouteAccessCache
```

Update constructor parameter names, fake test type names, and failure messages to match route access semantics.

- [ ] **Step 6: Update invalidation sites**

Replace every invalidation call:

```go
permission.ButtonCacheKey(userID, platform)
```

with:

```go
permission.RouteAccessCacheKey(userID, platform)
```

Expected files include:

```text
admin_back_go/internal/bootstrap/app.go
admin_back_go/internal/module/role/service.go
admin_back_go/internal/module/user/service.go
admin_back_go/internal/module/permission/service.go
admin_back_go/scripts/full-admin-smoke.ps1
```

In `admin_back_go/internal/bootstrap/app.go`, update the wire-up from:

```go
buttonGrantCache := permission.NewRedisButtonGrantCache(resources.Redis)
```

to:

```go
routeAccessGrantCache := permission.NewRedisRouteAccessGrantCache(resources.Redis)
```

Pass `routeAccessGrantCache` into permission, role, and user services.

In `admin_back_go/scripts/full-admin-smoke.ps1`, rename `Clear-UserButtonCache` to `Clear-UserRouteAccessCache` and update the embedded Go key format to:

```go
key := fmt.Sprintf("auth_perm_uid_%d_%s_rbac_route_access_grants", userID, os.Args[2])
```

Update test assertions from:

```text
auth_perm_uid_101_admin_rbac_page_grants
```

to:

```text
auth_perm_uid_101_admin_rbac_route_access_grants
```

Update these specific tests and assertions:

```text
admin_back_go/internal/module/permission/service_test.go
  TestButtonCacheKey -> TestRouteAccessCacheKey
  ButtonCacheKey(12, "admin") -> RouteAccessCacheKey(12, "admin")
  want "auth_perm_uid_12_admin_rbac_route_access_grants"

admin_back_go/internal/bootstrap/permission_checker_test.go
  update old cache.getKey/cache.setKey assertions:
  - line ~170 in TestPermissionCheckerFallsBackToPermissionBuilderWhenCacheGetFails
  - line ~216 in TestPermissionCheckerAllowsCachedButtonCodeWithoutBuildingContext
  - line ~242 in TestPermissionCheckerBuildsAndCachesButtonCodesOnCacheMiss
  Rename test/fake names from Button to RouteAccess where touched.

admin_back_go/internal/module/user/service_test.go
  update line ~274 admin init cache assertion to auth_perm_uid_1_admin_rbac_route_access_grants
  update line ~695 app role-change invalidation assertion to auth_perm_uid_9_app_rbac_route_access_grants
  rename fakeButtonCache -> fakeRouteAccessGrantCache.

admin_back_go/internal/module/role/service_test.go
  update TestServiceUpdateInvalidatesBoundUserButtonCaches four expected invalidation keys for users 101/102 admin/app to rbac_route_access_grants.

admin_back_go/internal/module/permission/management_service_test.go
  update exact old rbac_page_grants assertions:
  - lines ~330-331 in TestServiceUpdateInvalidatesUsersGrantedChangedPermissionSubtree
  - line ~357 in TestServiceDeleteInvalidatesUsersBeforeRolePermissionLinksAreDeleted
  - line ~379 in TestServiceChangeStatusInvalidatesUsersGrantedChangedPermissionSubtree
```

- [ ] **Step 7: Update user service tests**

In `admin_back_go/internal/module/user/service_test.go`, make the successful init fixture explicit:

```go
builder := &fakePermissionBuilder{ctx: permission.Context{
	Permissions:      []permission.MenuItem{{Index: "/user", Label: "用户管理"}},
	Router:           []permission.RouteItem{{Path: "/user", ViewKey: "user/index"}},
	ButtonCodes:      []string{"user_add"},
	RouteAccessCodes: []string{"user_list", "user_add"},
}}
```

Keep the response assertion BUTTON-only:

```go
if !reflect.DeepEqual(got.ButtonCodes, []string{"user_add"}) || len(got.Permissions) != 1 || len(got.Router) != 1 {
	t.Fatalf("unexpected init response: %#v", got)
}
```

Update the cache assertion:

```go
if cache.key != "auth_perm_uid_1_admin_rbac_route_access_grants" || !reflect.DeepEqual(cache.values, []string{"user_list", "user_add"}) || cache.ttl != 30*time.Minute {
	t.Fatalf("unexpected route access cache write: key=%s values=%#v ttl=%s", cache.key, cache.values, cache.ttl)
}
```

- [ ] **Step 8: Run backend route access tests**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/bootstrap ./internal/module/user ./internal/module/permission ./internal/module/role -count=1
go test -race ./internal/bootstrap ./internal/module/user ./internal/module/permission ./internal/module/role -count=1
```

Expected: PASS.

---

### Task 4: Frontend role matrix wording and PAGE access contract

**Files:**
- Modify: `admin_front_ts/src/views/Main/permission/role/index.vue`
- Modify: `admin_front_ts/src/i18n/locales/zh-CN.ts`
- Modify: `admin_front_ts/src/i18n/locales/en-US.ts`
- Modify: `admin_front_ts/tests/shared/permission/role-matrix.test.ts`
- Modify: `admin_front_ts/tests/shared/permission/role-matrix-ui.test.ts`

- [ ] **Step 1: Add wording guard test**

In `admin_front_ts/tests/shared/permission/role-matrix-ui.test.ts`, add a test using the existing file-read helpers or this pattern:

```ts
it('uses PAGE access wording instead of generic view wording', () => {
  const rolePage = readFileSync(resolve(repoRoot, 'src/views/Main/permission/role/index.vue'), 'utf-8')
  const zhCN = readFileSync(resolve(repoRoot, 'src/i18n/locales/zh-CN.ts'), 'utf-8')
  const enUS = readFileSync(resolve(repoRoot, 'src/i18n/locales/en-US.ts'), 'utf-8')

  expect(rolePage).toContain(":page-access-label=\"t('role.permissionMatrix.pageAccess')\"")
  expect(rolePage).not.toContain(":page-access-label=\"t('common.actions.view')\"")
  expect(zhCN).toContain("pageAccess: '页面访问'")
  expect(zhCN).not.toContain('页面查看')
  expect(enUS).toContain("pageAccess: 'Page access'")
})
```

- [ ] **Step 2: Run the failing frontend wording test**

Run:

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/permission/role-matrix-ui.test.ts
```

Expected before implementation: FAIL.

- [ ] **Step 3: Update role page label**

In `admin_front_ts/src/views/Main/permission/role/index.vue`, change:

```vue
:page-access-label="t('common.actions.view')"
```

to:

```vue
:page-access-label="t('role.permissionMatrix.pageAccess')"
```

- [ ] **Step 4: Update zh-CN copy**

In `admin_front_ts/src/i18n/locales/zh-CN.ts`, change `role.permissionMatrix` to:

```ts
permissionMatrix: {
  helper: '目录只负责分组展示；入库只保存页面访问和页面动作。勾选动作会自动拥有页面访问。',
  selected: '已选',
  pages: '页面',
  actions: '动作',
  pageAccess: '页面访问',
  clearGroup: '清空本组',
  clearPlatform: '清空当前平台',
  emptyActions: '无动作，仅控制页面访问'
},
```

- [ ] **Step 5: Update en-US copy**

In `admin_front_ts/src/i18n/locales/en-US.ts`, change `role.permissionMatrix` to:

```ts
permissionMatrix: {
  helper: 'Directories are display groups only; only page access and page actions are persisted. Selecting an action grants page access automatically.',
  selected: 'Selected',
  pages: 'Pages',
  actions: 'Actions',
  pageAccess: 'Page access',
  clearGroup: 'Clear Group',
  clearPlatform: 'Clear Current Platform',
  emptyActions: 'No actions; controls page access only'
},
```

- [ ] **Step 6: Add or verify matrix behavior tests**

In `admin_front_ts/tests/shared/permission/role-matrix.test.ts`, ensure assertions cover these three behaviors. Adjust fixture shape to match actual exported types:

```ts
it('selecting an action includes the parent PAGE permission id', () => {
  const row = createMatrixRow({ pagePermissionId: 20, actions: [{ id: 21, label: 'Edit' }] })
  const selected = toggleMatrixRowAction([], row, 21, true)
  expect(selected.sort((a, b) => a - b)).toEqual([20, 21])
})

it('selecting PAGE only does not select all action ids', () => {
  const row = createMatrixRow({ pagePermissionId: 20, actions: [{ id: 21, label: 'Edit' }, { id: 22, label: 'Delete' }] })
  const selected = toggleMatrixPage([], row, true)
  expect(selected.sort((a, b) => a - b)).toEqual([20])
})

it('clearing PAGE also clears action ids on that page', () => {
  const row = createMatrixRow({ pagePermissionId: 20, actions: [{ id: 21, label: 'Edit' }, { id: 22, label: 'Delete' }] })
  const selected = toggleMatrixPage([20, 21, 22, 99], row, false)
  expect(selected.sort((a, b) => a - b)).toEqual([99])
})
```

If no `createMatrixRow` helper exists, define a local helper with the exact `RoleMatrixRow` shape from `role-matrix.ts`.

- [ ] **Step 7: Run frontend focused checks**

Run:

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/permission/role-matrix.test.ts tests/shared/permission/role-matrix-ui.test.ts
npm run test -- tests/shared/i18n/literal-i18n-keys.test.ts tests/shared/i18n/no-visible-chinese.test.ts
npx vue-tsc -b --pretty false
```

Expected: PASS.

---

### Task 5: Documentation sync

**Files:**
- Modify: `docs/contracts/admin-api-v1.md`
- Modify: `docs/architecture/04-go-backend-framework.md`
- Modify: `admin_back_go/docs/architecture.md`
- Modify: `docs/status/current-status.md`

- [ ] **Step 1: Update RBAC Bootstrap contract**

In `docs/contracts/admin-api-v1.md`, update the RBAC bootstrap rules to:

```text
permissions/router/buttonCodes/quick_entry 是稳定字段名，不加兜底别名。
show_menu 只控制菜单显示，不影响 router 页面权限真相。
PAGE 授权让 permissions tree + router 包含该 PAGE；PAGE code 可进入后端内部 RouteAccessCodes，但不返回到 users/init.buttonCodes。
BUTTON 授权由 Go service 自动带出父 PAGE 和祖先 DIR；buttonCodes 只包含 BUTTON code。
前端按钮显隐只读 buttonCodes；API 放行只由 PermissionCheck 使用内部 RouteAccessCodes 判断。
```

- [ ] **Step 2: Update role mutation notes**

In `docs/contracts/admin-api-v1.md`, update role notes to:

```text
role_permissions 只保存 PAGE/BUTTON。
提交 BUTTON 时 Go service 自动补父 PAGE。
提交 DIR 会被归一化忽略；DIR 可存在于 permissions 定义树，但不作为 role_permissions 授权记录保存。
不创建 view/查看 虚拟 BUTTON；角色编辑器里的“页面访问”映射真实 PAGE permission_id。
```

- [ ] **Step 3: Update backend architecture truth table**

In `admin_back_go/docs/architecture.md`, update RBAC truth table rows:

```markdown
| PAGE 授权 | `permissions` tree + `router` 都包含该 PAGE；PAGE code 可进入内部 `RouteAccessCodes`；`buttonCodes` 不增加 | 动态路由来自 `router`，按钮显隐不能读 PAGE code |
| BUTTON 授权 | service 自动包含父 PAGE 和祖先 DIR；内部 `RouteAccessCodes` 包含 BUTTON code；`buttonCodes` 只包含 BUTTON code | 按钮显隐只读 `userStore.can(code)`，也就是 `buttonCodes` |
| PermissionCheck cache hit | 先验证 user 和 role 存在，再用 Redis route access grant codes 判断 PAGE/BUTTON route metadata code | 前端不参与 API 放行 |
```

Also replace all old cache-key wording in `admin_back_go/docs/architecture.md`:

```text
auth_perm_uid_{userId}_{platform}_rbac_page_grants -> auth_perm_uid_{userId}_{platform}_rbac_route_access_grants
RBAC button cache -> RBAC route access grant cache
```

Current old-key occurrences are around lines ~1083, ~1100, ~1128, and ~1191.

- [ ] **Step 4: Update root backend framework doc**

In `docs/architecture/04-go-backend-framework.md`, add:

```markdown
### RBAC RouteAccessCodes 与 buttonCodes 分离

`users/init.buttonCodes` 是前端按钮显隐契约，只能包含 BUTTON code。后端 `PermissionCheck` 使用内部 `RouteAccessCodes` 判断 route metadata code；`RouteAccessCodes` 可包含 PAGE code 和 BUTTON code。不要为了读接口创建 `view` / `查看` BUTTON，也不要把 PAGE code 暴露成前端按钮能力。
```

- [ ] **Step 5: Update current status after tests pass**

In `docs/status/current-status.md`, update only the RBAC bootstrap row or RBAC loop paragraph:

```text
users/init exposes BUTTON-only buttonCodes; PermissionCheck uses internal RouteAccessCodes so PAGE read routes remain protected without leaking PAGE code into frontend button visibility.
```

- [ ] **Step 6: Run docs wording scan**

Run:

```powershell
cd E:\admin_go
rg -n "页面查看|view 虚拟|buttonCodes.*PAGE|PAGE code.*buttonCodes|RouteAccessCodes|route access" docs\contracts docs\architecture admin_back_go\docs\architecture.md docs\status -S
```

Expected:

```text
No remaining role/RBAC wording that says 页面查看.
No wording saying PAGE code is returned in public buttonCodes.
Expected RouteAccessCodes / route access matches in updated docs.
```

---

### Task 6: Final verification

**Files:**
- Read: root diff and sub-repo diffs

- [ ] **Step 1: Backend focused tests**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/permission ./internal/module/role ./internal/module/user ./internal/bootstrap ./internal/server -count=1
```

Expected: PASS.

- [ ] **Step 2: Backend race tests**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test -race ./internal/module/permission ./internal/module/role ./internal/module/user ./internal/bootstrap -count=1
```

Expected: PASS.

- [ ] **Step 3: Frontend checks**

Run:

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/permission/role-matrix.test.ts tests/shared/permission/role-matrix-ui.test.ts
npm run test -- tests/shared/i18n/literal-i18n-keys.test.ts tests/shared/i18n/no-visible-chinese.test.ts
npx vue-tsc -b --pretty false
```

Expected: PASS.

- [ ] **Step 4: Optional live smoke**

Run only if backend stack is already up or executor is ready to start it through Docker-first docs:

```powershell
cd E:\admin_go\admin_back_go
powershell -ExecutionPolicy Bypass -File .\scripts\basic-admin-smoke.ps1 -Account 15671628271 -Password 123456
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account 15671628271 -Password 123456
```

Expected: PASS, including:

```text
login -> AuthToken -> users/me -> users/init
permission create DIR/PAGE/BUTTON
role update grants PAGE/BUTTON
users/init returns temporary router + BUTTON-only buttonCodes
role restore
permission subtree delete
logout
```

`full-admin-smoke.ps1` must clear `auth_perm_uid_<userId>_<platform>_rbac_route_access_grants` through `Clear-UserRouteAccessCache`; the old `rbac_page_grants` key must not appear in the script.

- [ ] **Step 5: Clear stale route access cache only for live verification**

If live browser/smoke sees stale permissions after changing grants, clear the exact user/platform key:

```powershell
redis-cli -h 127.0.0.1 -p 6380 DEL auth_perm_uid_<userId>_admin_rbac_route_access_grants
redis-cli -h 127.0.0.1 -p 6380 DEL auth_perm_uid_<userId>_app_rbac_route_access_grants
```

Do not clear unrelated Redis keys.

- [ ] **Step 6: Root governance checks**

Run:

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected: both PASS.

- [ ] **Step 7: Diff review**

Run:

```powershell
cd E:\admin_go
git diff --stat
git diff -- docs/superpowers/specs/2026-05-24-rbac-role-permission-editor-design.md docs/superpowers/plans/2026-05-24-rbac-role-permission-editor.md docs/contracts/admin-api-v1.md docs/architecture/04-go-backend-framework.md docs/status/current-status.md
cd E:\admin_go\admin_back_go
git diff -- internal/module/permission/model.go internal/module/permission/service.go internal/module/permission/service_test.go internal/module/permission/cache.go internal/module/permission/management_service_test.go internal/bootstrap/app.go internal/bootstrap/permission_checker.go internal/bootstrap/permission_checker_test.go internal/module/user/service.go internal/module/user/service_test.go internal/module/role/service.go internal/module/role/service_test.go scripts/full-admin-smoke.ps1 docs/architecture.md
cd E:\admin_go\admin_front_ts
git diff -- src/views/Main/permission/role/index.vue src/i18n/locales/zh-CN.ts src/i18n/locales/en-US.ts tests/shared/permission/role-matrix.test.ts tests/shared/permission/role-matrix-ui.test.ts
```

Expected: diff only covers RBAC context split, role editor wording/tests, and docs.

---

## Commit Guidance

Commit only after each task verification passes, and do not include unrelated dirty files.

Suggested commits:

```powershell
git add admin_back_go/internal/module/role/service_test.go admin_back_go/internal/module/role/service.go
git commit -m "test: guard role permission normalization"

git add admin_back_go/internal/module/permission/model.go admin_back_go/internal/module/permission/service.go admin_back_go/internal/module/permission/service_test.go admin_back_go/internal/module/permission/cache.go admin_back_go/internal/module/permission/management_service_test.go admin_back_go/internal/bootstrap/app.go admin_back_go/internal/bootstrap/permission_checker.go admin_back_go/internal/bootstrap/permission_checker_test.go admin_back_go/internal/module/user/service.go admin_back_go/internal/module/user/service_test.go admin_back_go/internal/module/role/service.go admin_back_go/internal/module/role/service_test.go admin_back_go/scripts/full-admin-smoke.ps1
git commit -m "fix: split rbac route access from button codes"

git add admin_front_ts/src/views/Main/permission/role/index.vue admin_front_ts/src/i18n/locales/zh-CN.ts admin_front_ts/src/i18n/locales/en-US.ts admin_front_ts/tests/shared/permission/role-matrix.test.ts admin_front_ts/tests/shared/permission/role-matrix-ui.test.ts
git commit -m "fix: clarify role page access permissions"

git add docs/contracts/admin-api-v1.md docs/architecture/04-go-backend-framework.md docs/status/current-status.md admin_back_go/docs/architecture.md docs/superpowers/specs/2026-05-24-rbac-role-permission-editor-design.md docs/superpowers/plans/2026-05-24-rbac-role-permission-editor.md
git commit -m "docs: document rbac page access model"
```

## Self-Review Checklist

- [ ] `DIR` 文案是“不写入 role_permissions”，不是“不入库”。
- [ ] 没有新增 `view` / `xxx_view` / “查看”虚拟 BUTTON。
- [ ] `role_permissions` 只保存 active PAGE/BUTTON。
- [ ] BUTTON 授权自动补父 PAGE。
- [ ] `users/init.buttonCodes` 只包含 BUTTON code。
- [ ] `PermissionCheck` 使用内部 `RouteAccessCodes`，PAGE read routes 不会 403。
- [ ] Redis route access grant cache 是性能缓存，不是权限真相源。
- [ ] 前端角色编辑器显示“页面访问”，映射真实 PAGE id。
- [ ] `userStore.can(code)` 仍是 BUTTON-only 显隐 helper。
- [ ] Go tests、race tests、Vitest、`vue-tsc`、`git diff --check`、governance check 都有通过证据。
