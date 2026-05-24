# RBAC Role Permission Editor Design

日期：2026-05-24
状态：draft for review，不提交 commit
范围：只讨论后台角色管理里的权限授权模型和编辑器交互；不改当前 `users.role_id` 单角色模型，不引入多角色、数据权限、Casbin、超级管理员绕过或新的权限表。

## 1. 结论

角色管理的授权模型固定采用真实 `PAGE / BUTTON` 授权，不引入“查看 / view”虚拟按钮权限。

一句话规则：

```text
DIR 是权限定义树的分组节点，可存在于 permissions 表，但不写入 role_permissions。
PAGE 表示页面访问、动态路由和菜单页面权限。
BUTTON 表示页面内动作权限。
role_permissions 只保存 PAGE/BUTTON permission_id。
选择 BUTTON 后，Go service 自动补齐父 PAGE。
buttonCodes 永远只包含 BUTTON code。
Redis route access grant cache 只做性能加速，不是权限真相源。
```

UI 可以展示“页面访问”，但它必须映射真实 `PAGE permission_id`，不能变成一个 `xxx_view` / `view` / “查看” BUTTON。

## 2. Linus 三问

### 2.1 这是真问题吗？

是。角色授权页面如果把页面访问和按钮动作混成“查看按钮”，后续会持续污染：

```text
buttonCodes 语义
Redis route access grant cache
API route permission
角色权限回显
前端按钮显隐
菜单/路由访问判断
```

当前项目已经有清晰的 RBAC 运行时契约：`DIR/PAGE/BUTTON`、`users/init` 返回 `permissions/router/buttonCodes`、`role_permissions` 保存 `PAGE/BUTTON`。角色编辑器必须贴合这个契约，而不是为了 UI 直观额外创造“查看”按钮。

### 2.2 更简单的做法是什么？

不新造权限类型，不新增 `view` code，不新增虚拟节点入库。

最简单模型：

```text
页面能不能进：看 PAGE
按钮能不能点：看 BUTTON
目录是否展示：由 PAGE/BUTTON 向上推导 DIR
```

UI 只负责把这个模型讲清楚：

```text
页面访问 = PAGE
页面动作 = BUTTON
菜单/目录分组 = DIR
```

### 2.3 会破坏什么吗？

不能破坏：

```text
登录和 users/init bootstrap
后端 PermissionCheck fail-closed
role_permissions 现有 PAGE/BUTTON 数据
buttonCodes 只用于按钮显隐的前端语义
Redis route access grant cache miss/error 回源计算
角色授权变更后的缓存失效
当前 basic/full smoke 的 RBAC loop
```

## 3. 当前事实源

当前项目事实源：

```text
docs/status/current-status.md
docs/contracts/admin-api-v1.md
docs/architecture/04-go-backend-framework.md
admin_back_go/docs/architecture.md
admin_back_go/internal/module/permission
admin_back_go/internal/module/role
admin_front_ts/src/views/Main/permission/role
```

关键运行时契约：

```text
users.role_id 单角色模型，第一阶段不改多角色。
permissions.type = DIR / PAGE / BUTTON。
role_permissions 只保存 PAGE/BUTTON。
提交 BUTTON 时 Go service 自动补父 PAGE。
提交 DIR 会被忽略，DIR 只由 PAGE/BUTTON 计算上下文时带出。
users/init 返回 permissions + router + buttonCodes + quick_entry。
buttonCodes 只驱动按钮显隐。
```

后端文档当前也明确：

```text
MySQL 的 users.role_id / roles / permissions / role_permissions 是权限真相源。
Redis 只做 route access grant 缓存。
PAGE 授权会让 permissions tree + router 包含该 PAGE，buttonCodes 不增加。
BUTTON 授权会自动包含父 PAGE 和祖先 DIR，buttonCodes 包含 BUTTON code。
```

## 3.1 当前旧实现待重构点

需要在实现计划里显式处理一个旧实现问题：当前 Go runtime 里 `buildContext` 会把 `PAGE/BUTTON` 上非空 `code` 都放进 `buttonCodes`，而部分 GET/read route metadata 也复用了 PAGE code 做 `PermissionCheck`，例如 `payment_config_list`、`payment_order_list`、`wallet_transaction_list`。

这说明当前实现把两个语义混在了同一个字段里：

```text
前端按钮显隐：应该只读 BUTTON code。
后端 API 放行：需要能识别 PAGE 访问 code + BUTTON action code。
```

这不是要兼容旧语义，而是重构顺序问题：不能只改公开 `buttonCodes`，还必须同步把 `PermissionCheck` 切到内部 route access grant。正确 clean cut 方式是：

```text
Context.ButtonCodes / users/init.buttonCodes：只暴露 BUTTON code，给前端按钮显隐用。
后端内部 route/API grant codes：包含 PAGE code + BUTTON code，只给 PermissionCheck 和 Redis route grant cache 用。
项目未上线，不保留旧 button grant cache 命名；本轮直接改成 route access grant cache，避免继续误导。
```

这不等于新增“查看/view” BUTTON；PAGE code 仍然属于 PAGE 访问语义，不能作为页面内动作返回给前端。

## 4. Codex + Claude 讨论结论

### 4.1 一致结论

Codex 和 Claude reviewer 对核心判断一致：

```text
采用 PAGE/BUTTON 真实授权模型。
不引入“查看/view”虚拟 BUTTON。
UI 展示“页面访问”可以，但提交值必须是 PAGE permission_id。
BUTTON 只表达页面内动作能力。
buttonCodes 只返回 BUTTON code。
Redis route access grant cache 只做性能加速。
```

### 4.2 Claude reviewer 修正点

需要避免一句有歧义的话：

```text
DIR 不入库
```

这句话不精确。正确写法是：

```text
DIR 可作为 permissions 定义树节点入库，但不作为 role_permissions 授权记录入库。
```

原因：

```text
permissions 表仍然管理 DIR/PAGE/BUTTON 三类定义节点。
DIR 负责菜单/权限树分组。
角色授权表 role_permissions 只保存 PAGE/BUTTON，不保存 DIR。
```

## 5. 不采用的方案

### 5.1 不采用：每个页面新增“查看”按钮权限

这种方案表面直观，但长期会制造歧义。

坏味道：

```text
PAGE 已经表示页面访问，又新增 view BUTTON 表示查看。
buttonCodes 可能混入 view code。
后端需要判断 view 到底是 PAGE 还是 BUTTON。
角色回显、全选、半选和 diff 会多一层虚拟含义。
权限文案会让人误以为“页面访问”也是按钮动作。
```

如果落成真实 `xxx_view` BUTTON，以后每个页面都会多一个无业务动作的按钮权限，权限树节点数膨胀，缓存和 UI 计算都变复杂。

### 5.2 不采用：纯 Cascader 只选叶子

纯 Cascader 适合简单分类选择，不适合复杂权限授权。

问题：

```text
页面有按钮时，PAGE 不是树的叶子，但 PAGE 仍然需要可单独授权。
页面无按钮时，PAGE 是可授权终点。
DIR 半选只是展示状态，不应提交。
Cascader 的叶子选择语义容易把 PAGE 和 BUTTON 混在一起解释。
```

可以借鉴 Cascader 的分层展示，但不建议用“只能选自然叶子”的组件语义硬套 RBAC。

### 5.3 不采用：前端自己补父级作为唯一真相

前端可以做联动展示，但不能成为权限归一化真相源。

必须以后端为准：

```text
前端可以在选 BUTTON 时视觉上点亮父 PAGE。
提交时可以带 PAGE + BUTTON，也可以只带 BUTTON。
Go service 必须自动补父 PAGE。
历史脏数据只有 BUTTON 时，users/init 仍要能推导 PAGE 和 DIR。
```

## 6. 推荐 UI 形态

推荐保留“平台 tab + 分组矩阵/树形授权面板”，而不是回退成单个 Cascader。

结构：

```text
平台：admin / app

DIR：用户
  PAGE：用户管理
    [页面访问]  [编辑] [删除] [踢下线] [批量编辑] [导出]

  PAGE：登录日志
    [页面访问]  无按钮，仅控制页面访问

DIR：权限管理
  PAGE：角色管理
    [页面访问]  [新增] [编辑] [删除] [设为默认]
```

交互规则：

```text
DIR：只分组，只做展开/收起/本组全选/清空，不作为授权项提交。
PAGE：展示为“页面访问”，实际提交 PAGE permission_id。
BUTTON：展示为页面内动作，实际提交 BUTTON permission_id。
选 BUTTON：UI 可自动点亮 PAGE，后端也必须自动补 PAGE。
取消 PAGE：应取消该页所有 BUTTON，避免“按钮可见但页面不可进”的编辑态误导。
只选 PAGE：页面可访问，buttonCodes 不增加该页任何 BUTTON。
页面无 BUTTON：仍可选 PAGE，表示只读/日志类页面访问。
```

文案建议：

```text
用“页面访问”，不用“查看”。
用“页面动作”，不用“按钮权限”泛化页面访问。
用“已选 / 页面 / 动作”统计，不把 DIR 计入授权数量。
```

## 7. 数据流

### 7.1 角色保存

输入：

```text
permission_id: number[]
```

允许输入：

```text
PAGE permission_id
BUTTON permission_id
```

不允许成为最终授权记录：

```text
DIR permission_id
虚拟 view permission_id
UI-only node
```

服务端归一化：

```text
输入 PAGE -> 保存 PAGE
输入 BUTTON -> 保存 BUTTON + 父 PAGE
输入 DIR -> 忽略或拒绝；当前契约是提交 DIR 会被忽略
去重、排序、过滤已删除/禁用权限
```

最终 `role_permissions`：

```text
只存在 PAGE/BUTTON。
不存在 DIR。
不存在 view 虚拟 BUTTON。
```

### 7.2 users/init

运行时初始化输出：

```text
permissions: PAGE + 必要祖先 DIR 形成的菜单树
router: PAGE 形成的动态路由
buttonCodes: BUTTON code 数组
quick_entry: 当前用户快捷入口
```

注意：

```text
buttonCodes 不包含 PAGE code。
buttonCodes 不包含 DIR code。
buttonCodes 不包含 view 虚拟 code。
```

### 7.3 PermissionCheck

后端 API 权限检查：

```text
route metadata 明确声明需要哪个 BUTTON code。
PermissionCheck 先验证 user/role。
优先读 Redis route access grant cache。
cache miss/error 时回源构建 RBAC context。
构建失败或没有权限时拒绝，不能放行。
```

## 8. 性能判断

性能目标不是“前端少一个组件”，而是减少无意义权限节点和无意义计算。

推荐方案性能更稳：

```text
不为每个 PAGE 额外创建 view BUTTON，节点数量更少。
role_permissions 只保存真实 PAGE/BUTTON，授权 diff 更简单。
buttonCodes 只含 BUTTON，前端 can(code) 判断保持 O(1) Set 查询。
Redis 只缓存 route access grants，缓存语义稳定。
users/init 按 PAGE/BUTTON 推导 DIR，不需要处理虚拟权限。
```

前端性能建议：

```text
把 selectedIds 转成 computed Set，避免模板里反复 includes。
分组折叠后不渲染表格体。
统计信息从 selected Set + group rows 派生。
不要把权限树深拷贝成多份状态源。
权限节点数量继续增长时，再考虑虚拟列表或分页展开；当前不提前复杂化。
```

后端性能建议：

```text
角色保存时一次性归一化 PAGE/BUTTON。
users/init 构建权限上下文后写入 route access grant cache，best-effort。
角色权限变更后清理绑定用户所有平台的 route access grant cache。
cache 只是性能边界，不能替代 DB 真相源。
```

## 9. 后续实现边界

### 9.1 Backend Worker 后续任务

需要确认或补强：

```text
role normalizeMutation 过滤 DIR，保存 BUTTON 时补父 PAGE。
role list 回显 permission_id 时只返回 PAGE/BUTTON。
users/init 的 buttonCodes 只来自 BUTTON。
PermissionCheck cache miss/error 能回源计算。
角色授权变更清理绑定用户 admin/app route access grant cache。
```

不做：

```text
不新增 view 权限码。
不新增权限类型。
不引入多角色。
不引入 Casbin。
不把 Redis 变成权限真相源。
```

### 9.2 Frontend Adapter 后续任务

需要调整：

```text
角色权限编辑器文案从“查看”改为“页面访问”。
PAGE 勾选实际提交 PAGE id。
BUTTON 勾选实际提交 BUTTON id。
DIR 只用于分组、展开、组内全选/清空，不作为最终授权项提交。
按钮显隐继续只用 userStore.can(code)，code 来自 buttonCodes。
```

组件边界建议：

```text
RolePermissionMatrix.vue：纯展示和交互事件，不拥有 API。
role-matrix.ts：负责把 permission_tree 转换为分组/行/action 模型。
role/index.vue：负责 init/list/form/diff/submit 编排。
```

如果后续改代码，仍遵守 Vue 3 Composition API、`<script setup lang="ts">`、明确 props/emits、最小状态源、computed 派生统计。

## 10. 最小验收点

### 10.1 文档验收

```text
文档明确 PAGE=页面访问、BUTTON=页面动作、DIR=定义树分组。
文档不再说“DIR 不入库”，只说“DIR 不入 role_permissions”。
文档明确不新增 view 虚拟 BUTTON。
```

### 10.2 后端验收

```text
提交 [PAGE] -> role_permissions 保存 PAGE。
提交 [BUTTON] -> role_permissions 保存 BUTTON + 父 PAGE。
提交 [DIR] -> role_permissions 不保存 DIR。
users/init router 包含 PAGE。
users/init buttonCodes 只包含 BUTTON code。
角色授权变更后相关用户 route access grant cache 被清理。
```

建议测试：

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/role ./internal/module/permission ./internal/bootstrap -count=1
```

### 10.3 前端验收

```text
角色编辑器显示“页面访问”，不显示“查看”作为按钮权限。
选 BUTTON 后该 PAGE 视觉上处于已授权/半选合理状态。
只选 PAGE 后提交 payload 包含 PAGE id，不包含任何 BUTTON id。
取消 PAGE 会清掉该页 BUTTON。
buttonCodes 仍只驱动 userStore.can(code)。
```

建议测试：

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/permission
npx vue-tsc -b --pretty false
```

### 10.4 Smoke 验收

RBAC smoke 继续覆盖：

```text
login -> AuthToken -> users/me -> users/init
permission create DIR/PAGE/BUTTON
role update grants PAGE/BUTTON
users/init returns temporary router + BUTTON-only buttonCodes
role restore
permission subtree delete
logout
```

建议命令：

```powershell
cd E:\admin_go\admin_back_go
powershell -ExecutionPolicy Bypass -File .\scripts\basic-admin-smoke.ps1 -Account 15671628271 -Password 123456
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account 15671628271 -Password 123456
```

## 11. Clean-cut 迁移策略

项目未上线，不做兼容保留。当前项目不应该产生新的 `view` 虚拟权限；落地前只做一次审计，确认是否存在历史误造的 `view` / `xxx_view` BUTTON。

审计规则：

```sql
SELECT id, code, name
FROM permissions
WHERE is_del = 2
  AND type = 3
  AND (code LIKE '%\_view' ESCAPE '\\' OR code = 'view' OR code LIKE '%page_view%');
```

处理规则：

```text
只是 UI 文案：改成“页面访问”，数据仍用 PAGE id。
审计 0 行：记录 verified clean，不写 migration。
审计非 0 行：直接删除相关 role_permissions 和 permissions 误造 BUTTON，不保留兼容路径。
```

任何 permission/menu 变更后，必须清理或等待 RBAC route access grant cache，否则 Redis 旧授权可能遮住 DB 真相。

## 12. Exit Criteria

```text
角色授权页面里，用户能清楚区分“页面访问”和“页面动作”。
没有“查看”虚拟 BUTTON 进入 permissions/role_permissions/buttonCodes。
只授 PAGE 能进入页面但没有按钮。
授 BUTTON 自动拥有父 PAGE。
DIR 只作为 permissions 定义树分组，不作为 role_permissions 授权记录。
后端、前端、缓存、smoke 对 PAGE/BUTTON/DIR 的解释一致。
```
