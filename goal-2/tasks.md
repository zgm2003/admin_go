# Goal Tasks: Plan 02 Auth Transport Pattern + `/api/Users` Backend Cleanup

规则：每个新会话先完整读取 `input.md`、`plan.md`、`tasks.md`，列出小 todo 并注册；每轮只执行第一个未完成 task。每个 task 收尾必须基于实际命令/检查证据，不得口头声称 100% 有信心。

## Task G0: Goal 初始化

- [x] 创建 goal 目录与三份文件。
- [x] 保存用户原始输入到 `input.md`。
- [x] 写入执行计划、风险、验证、回滚与默认假设。
- [x] 写入可逐项验证的任务清单。

记录：
- 动作：初始化本 goal 的 `input.md` / `plan.md` / `tasks.md`。
- 验证：本轮只创建 goal 文件，不修改业务代码。
- 剩余风险：尚未执行 plan-02 的 pre-flight；当前 backend/frontend baseline 未验证。
- 下一步：自动推进后执行 Task 1。

---

## Task 1: Pre-flight checks before code change

- [x] 完整读取 `goal-*/input.md`、`goal-*/plan.md`、`goal-*/tasks.md`。
- [x] 注册本轮小 todo。
- [x] 运行 frontend `/api/Users` pre-flight grep：

```powershell
cd E:\admin_go
rg -n "/api/Users" admin_front_ts\src admin_front_ts\tests admin_app\lib admin_app\test -g "!*node_modules*" -g "!*dist*" -g "!*build*"
```

- [x] 如果 `admin_app\lib` / `admin_app\test` 不存在，记录该事实，并补充现有路径 grep：`admin_app\src` / `admin_app\tests`。
- [x] 运行 backend baseline：

```powershell
cd E:\admin_go\admin_back_go
go build ./...
go test ./internal/module/auth ./internal/module/user ./internal/server -count=1
```

完成记录预留：
- 动作：完成 plan-02 pre-flight。读取 goal 三文件并注册本轮 todo；按原 plan 跑 frontend `/api/Users` grep；发现 `admin_app\lib` 与 `admin_app\test` 不存在后，补充现有 `admin_app\src` / `admin_app\tests` grep；另外补充 production source-only grep 区分真实 caller 与测试里的 negative assertion；运行 backend baseline build/test。
- 验证：
  - `rg -n "/api/Users" admin_front_ts\src admin_front_ts\tests admin_app\lib admin_app\test -g "!*node_modules*" -g "!*dist*" -g "!*build*"`：`original_exit=2`；输出只来自 `admin_front_ts\tests\shared\user\users-api.test.ts` 的 `expect(...).not.toContain(...)` negative assertions；并报 `admin_app\lib` / `admin_app\test` 不存在。
  - 路径存在性：`admin_front_ts\src=True`、`admin_front_ts\tests=True`、`admin_app\lib=False`、`admin_app\test=False`、`admin_app\src=True`、`admin_app\tests=True`。
  - `rg -n "/api/Users" admin_front_ts\src admin_front_ts\tests admin_app\src admin_app\tests -g "!*node_modules*" -g "!*dist*" -g "!*build*"`：`supplemental_exit=0`；同样只命中 `admin_front_ts\tests\shared\user\users-api.test.ts` 的 negative assertions。
  - `rg -n "/api/Users" admin_front_ts\src admin_app\src -g "!*node_modules*" -g "!*dist*" -g "!*build*"`：`source_exit=1`，无 production source matches。
  - `cd E:\admin_go\admin_back_go; go build ./...`：exit 0。
  - `go test ./internal/module/auth ./internal/module/user ./internal/server -count=1`：exit 0；`auth` / `user` / `server` 三包均 `ok`。
- 剩余风险：原 plan 的 grep 命令期待完全空输出，但当前测试文件保留了 `/api/Users` negative assertion 字符串；它们不是生产 caller，不阻塞 backend 删除，但后续 Task 7 最终 grep 若仍按包含 tests 的路径执行，会再次命中这些 guard 字符串，需要按实际语义记录或在 plan-04/frontend 测试中清理这些 literal。
- 下一步：Task 2 新增 RED architecture guard；本轮无业务代码修改，未提交代码。

---

## Task 2: Add RED architecture guard for auth transport boundary

- [x] 完整读取 goal 三文件并注册本轮小 todo。
- [x] 创建 `admin_back_go/internal/architecture/multiplatform_boundary_test.go`。
- [x] 测试覆盖：required transport files exist、old root auth HTTP files removed、Go internal 不含 `/api/Users`、auth 下无 `platform_` / `app_` / `admin_` prefixed files。
- [x] 运行 RED：

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture -run 'TestAuthTransportBoundaryShape|TestNoLegacyUsersRoutesInGoRuntime|TestAuthTransportHasNoPlatformPrefixedFiles' -count=1
```

- [x] 确认失败原因是缺少新 transport files 和/或 legacy `/api/Users` offenders，而不是语法错误或 helper 错误。
- [x] 如有代码修改，提交 backend commit。

完成记录预留：
- 动作：新增 `admin_back_go/internal/architecture/multiplatform_boundary_test.go` RED architecture guard。首次运行发现 guard 自身含 `/api/Users` literal 会被自扫描误报，已把待查前缀改为运行时拼接 `"/api/" + "Users"`，并用 `rg` 证明测试文件本身不再含该 literal。
- 验证：
  - `gofmt -w .\internal\architecture\multiplatform_boundary_test.go` 已执行。
  - `rg -n "/api/Users" .\internal\architecture\multiplatform_boundary_test.go`：`self_rg_exit=1`，guard 文件自身不再污染后续 forbidden-pattern grep。
  - `go test ./internal/architecture -run 'TestAuthTransportBoundaryShape|TestNoLegacyUsersRoutesInGoRuntime|TestAuthTransportHasNoPlatformPrefixedFiles' -count=1`：`red_test_exit=1`，按预期 FAIL。
  - RED 失败点：missing `internal/module/auth/transport/admin/route.go`；legacy Users route offenders 为 `internal/middleware/auth_token.go`, `internal/module/auth/route.go`, `internal/module/user/handler_test.go`, `internal/module/user/route.go`；platform-prefixed offenders 为 `internal/module/auth/platform_dto.go`, `platform_handler.go`, `platform_handler_test.go`, `platform_route.go`。
  - `git diff --check` in `admin_back_go`：exit 0。
  - backend commit：`e3e807e test: add auth transport boundary guard`。
- 剩余风险：backend `internal/architecture` 当前按 RED 设计失败；这是 Task 2 的预期中间态。后续 Task 3-6 必须迁移/删除旧文件并让该 guard 变 GREEN。
- 下一步：Task 3 只迁移 admin auth HTTP surface 到 `transport/admin`，不触碰 app/platform 或 router cleanup。

---

## Task 3: Move admin auth HTTP surface to `transport/admin`

- [x] 完整读取 goal 三文件并注册本轮小 todo。
- [x] 创建 `admin_back_go/internal/module/auth/transport/admin/`。
- [x] 从 old admin auth HTTP files 迁移 `request.go`、`handler.go`、`route.go`、`presenter.go`。
- [x] 搬迁 `handler_test.go` 到 `transport/admin/handler_test.go`，改 package/import/type alias。
- [x] 删除 root admin HTTP files：`route.go`、`handler.go`、`handler_test.go`、`request.go`。
- [x] 运行：

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/auth/transport/admin -count=1
```

- [x] 如有代码修改，提交 backend commit。

完成记录预留：
- 动作：把 admin auth HTTP surface 从 `internal/module/auth` root 迁入 `internal/module/auth/transport/admin`；`route.go` 暴露 `Register` 且只保留 `/api/admin/v1/auth/*`，不再注册 legacy `/api/Users/*`；`handler.go` / `handler_test.go` 改为 `package admin` 并用 `authmodule` 引用 root auth service DTO；新增 `presenter.go` 占位以满足 route/handler/request/presenter 四文件约定；将 `SessionService` 保留在 auth root `service.go` 作为跨 transport 服务契约；为临时保留的 app/platform root 文件补回 `SendCodeRequest` 与 `captchaAnswerFromRequest` 以便 Task 4 前仍可编译。
- 验证：
  - `gofmt` 已覆盖 `service.go`、`platform_dto.go`、`platform_handler.go` 和 `transport/admin/*.go`。
  - `go test ./internal/module/auth/transport/admin -count=1`：exit 0，`ok admin_back_go/internal/module/auth/transport/admin 0.264s`。
  - `go test ./internal/module/auth -run '^$' -count=1`：exit 0，root auth package 编译通过。
  - root admin HTTP files existence：`route.go=False`、`handler.go=False`、`handler_test.go=False`、`request.go=False`。
  - admin transport files existence：`route.go=True`、`handler.go=True`、`handler_test.go=True`、`request.go=True`、`presenter.go=True`。
  - `git diff --check` in `admin_back_go`：exit 0。
  - backend commit：`e2d3442 refactor: move admin auth transport`。
- 剩余风险：本轮只完成 admin transport；`platform_*` app auth 文件仍在 root，server router 仍调用旧 `auth.RegisterRoutes`，architecture guard 仍会失败，需后续 Task 4/5/6 继续收口。
- 下一步：执行 Checkpoint A 大型全面检查-debug循环，然后再进入 Task 4。

---

## Checkpoint A after Task 3: 大型全面检查-debug循环

必须检查并记录：
- [x] 需求是否偏离：是否只完成 plan-02 backend auth transport，不碰 plan-01/03/04。
- [x] 代码是否有 bug：admin transport imports/package/type alias 是否干净。
- [x] 类型检查/测试：至少 `go test ./internal/module/auth/transport/admin -count=1`。
- [x] 构建影响：如可行，运行受影响 package build/test。
- [x] 安全性：未扩大 public whitelist，未新增绕过 auth 的路径。
- [x] 数据一致性：无 DB/migration 改动。
- [x] 文档同步：本 task 不写 current-status 为 implemented。
- [x] 回滚方案：可通过本 task commit revert 回滚。

完成记录预留：
- 动作：执行 Task 3 后的大型全面检查-debug循环；检查当前 backend/root git 状态；发现 `internal/server/router.go` 仍调用已删除的 `auth.RegisterRoutes` 会导致 server package 编译失败，按 root cause 将 admin auth 装配改为 `auth/transport/admin.Register`，app/platform 装配暂不扩大到本轮；提交 backend commit `d31cc6d fix: wire admin auth transport in router`。
- 验证：
  - `git diff -- internal/server/router.go` 曾显示仅新增 `authadmin "admin_back_go/internal/module/auth/transport/admin"` import，并把 `auth.RegisterRoutes(router, deps.AuthService)` 改为 `authadmin.Register(router, deps.AuthService)`；`auth.RegisterPlatformRoutes(...)` 仍保留给 Task 4/5。
  - `go test ./internal/module/auth/transport/admin -count=1`：exit 0，`ok admin_back_go/internal/module/auth/transport/admin 0.420s`。
  - `go test ./internal/module/auth -run '^$' -count=1`：exit 0，root auth package compile 通过。
  - `go test ./internal/server -run '^$' -count=1`：exit 0，server package compile 通过。
  - `go test ./internal/architecture -run 'TestAuthTransportBoundaryShape|TestNoLegacyUsersRoutesInGoRuntime|TestAuthTransportHasNoPlatformPrefixedFiles' -count=1`：exit 1，仍按预期 RED；剩余失败为缺少 `transport/app/route.go`、`/api/Users` 仍在 `internal/middleware/auth_token.go` / `internal/module/user/{route.go,handler_test.go}`、`platform_*` auth root files 仍在。
  - `rg -n "/api/Users" internal/module/auth internal/module/user internal/middleware internal/server -g "*.go"`：exit 0；命中仅为 Task 4/5 预期剩余的 user/middleware legacy references，未命中 admin auth transport。
  - `git diff --check` in `admin_back_go`：exit 0。
- 剩余风险：architecture guard 仍红是计划内中间态，不能声称 plan-02 完成；app auth surface、router app 装配、user legacy init route、auth-token whitelist 仍需 Task 4/5/6 收口。根仓库已有无关治理/plan 文件改动与 goal 目录，未纳入 backend commit。
- 下一步：Task 4 迁移 app auth HTTP surface 到 `transport/app`，删除 `platform_*` root files。

---

## Task 4: Move app auth HTTP surface to `transport/app`

- [x] 完整读取 goal 三文件并注册本轮小 todo。
- [x] 创建 `admin_back_go/internal/module/auth/transport/app/`。
- [x] 从 old platform HTTP files 迁移 `request.go`、`handler.go`、`route.go`、`presenter.go`。
- [x] 重命名 platform-prefixed symbols：`PlatformHandler` -> `Handler`、`PlatformRouteOptions` -> `RouteOptions` 等。
- [x] 搬迁 `platform_handler_test.go` 到 `transport/app/handler_test.go`，改 package/import/type alias。
- [x] 删除 `platform_route.go`、`platform_handler.go`、`platform_handler_test.go`、`platform_dto.go`。
- [x] 运行：

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/auth/transport/app -count=1
```

- [x] 如有代码修改，提交 backend commit。

完成记录预留：
- 动作：把 app auth HTTP surface 从 `internal/module/auth/platform_*` 迁入 `internal/module/auth/transport/app`；新增/迁移 `route.go`、`handler.go`、`handler_test.go`、`request.go`、`presenter.go`；将 `PlatformRouteOptions`/`PlatformHandler`/`Platform*Service` 等 root/platform-prefixed 符号收敛为 app transport 内的 `RouteOptions`/`Handler`/`CaptchaService`/`UserInitService`；删除 root `platform_route.go`、`platform_handler.go`、`platform_handler_test.go`、`platform_dto.go`；为避免删除 root 注册入口后 server 包编译断裂，同步把 app auth 装配改为 `auth/transport/app.Register`。
- 验证：
  - TDD RED：`go test ./internal/module/auth/transport/app -count=1` 在创建 app transport 前 exit 1，失败原因为目录不存在。
  - `go test ./internal/module/auth/transport/app -count=1`：exit 0，`ok admin_back_go/internal/module/auth/transport/app 0.132s`。
  - `go test ./internal/module/auth -run '^$' -count=1`：exit 0，root auth package compile 通过。
  - `go test ./internal/server -run '^$' -count=1`：exit 0，server package 在 app router rewire 后 compile 通过。
  - `go test ./internal/architecture -run 'TestAuthTransportBoundaryShape|TestNoLegacyUsersRoutesInGoRuntime|TestAuthTransportHasNoPlatformPrefixedFiles' -count=1`：exit 1，按预期只剩 `TestNoLegacyUsersRoutesInGoRuntime` 红；shape 和 platform-prefixed file 约束已通过，剩余 legacy offenders 为 `internal/middleware/auth_token.go`、`internal/module/user/handler_test.go`、`internal/module/user/route.go`。
  - `rg -n "RegisterPlatformRoutes|PlatformRouteOptions|PlatformHandler|NewPlatformHandler|PlatformCaptchaService|PlatformUserInitService|platform_handler|platform_route|platform_dto" internal/module/auth internal/server/router.go -g "*.go"`：exit 1，无匹配。
  - `git diff --check` in `admin_back_go`：exit 0。
  - backend commit：`5e86c1c refactor: move app auth transport`。
- 剩余风险：architecture guard 仍红是计划内中间态；`/api/Users` legacy references 仍在 user route/test 与 auth-token whitelist，必须由 Task 5 删除；Task 5 的 router transport 装配项已因本轮保持编译而提前达成，下一轮仍需重新验证并记录。
- 下一步：Task 5 删除 `/api/Users/*` Go runtime：user legacy init route、auth-token whitelist、相关 user/server tests。

---

## Task 5: Rewire router and remove `/api/Users/*` runtime

- [x] 完整读取 goal 三文件并注册本轮小 todo。
- [x] `internal/server/router.go` 改用 `auth/transport/admin.Register` 和 `auth/transport/app.Register`。
- [x] `internal/module/user/route.go` 删除 `/api/Users/init` legacy route。
- [x] `internal/middleware/auth_token.go` 删除 `/api/Users/*` public whitelist。
- [x] `internal/module/user/handler_test.go` 删除 legacy init route assertions。
- [x] `internal/server/router_test.go` 新增 legacy routes not registered assertion。
- [x] 运行 focused tests：

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/server ./internal/middleware ./internal/module/user -run 'TestLegacyUsersRoutesAreNotRegistered|TestAuth|TestApp|TestUser|TestPublic' -count=1
```

- [x] 如果 regex 漏掉本地测试名，运行 Task 6/7 的 full package set。
- [x] 如有代码修改，提交 backend commit。

完成记录预留：
- 动作：确认 `router.go` 已使用 `auth/transport/admin.Register` 和 `auth/transport/app.Register`；新增 server 级 `TestLegacyUsersRoutesAreNotRegistered`；新增 middleware whitelist 保护测试；删除 `internal/module/user/route.go` 的 `/api/Users/init` legacy route；删除 `DefaultAuthSkipPaths` 中 `/api/Users/*` 旧 public whitelist；把 user handler tests 从 legacy POST init 改为 REST `GET /api/admin/v1/users/init` / `/me` 对比；同步更新 backend `docs/architecture.md` 中 Users/init 口径，避免文档继续把 `/api/Users/init` 写成当前接口。
- 验证：
  - TDD RED：`go test ./internal/server -run TestLegacyUsersRoutesAreNotRegistered -count=1` 在删 route 前 exit 1，失败点为 `POST /api/Users/init` 返回 200。
  - TDD RED：`go test ./internal/middleware -run TestAuthTokenDefaultSkipPathsExcludeLegacyUsersRoutes -count=1` 在删 whitelist 前 exit 1，失败点为 legacy Users path 仍 public。
  - `go test ./internal/server ./internal/middleware ./internal/module/user -run 'TestLegacyUsersRoutesAreNotRegistered|TestAuth|TestApp|TestUser|TestPublic' -count=1`：exit 0，三包均 `ok`。
  - `rg -n "/api/Users" internal/module/auth internal/module/user internal/middleware internal/server -g "*.go"`：exit 1，无 legacy literal 残留。
  - `rg -n "authadmin|authapp|auth\.RegisterRoutes|RegisterPlatformRoutes|PlatformRouteOptions" internal/server/router.go`：exit 0，仅命中 `authadmin`/`authapp` import 与 `Register` 调用；未命中旧 root 注册入口。
  - `git diff --check` in `admin_back_go`：exit 0。
  - backend commit：`98a2c6a refactor: remove legacy users routes`。
- 剩余风险：本轮没有执行 Task 6 的完整 architecture guard 和 focused package set；虽然 `/api/Users` grep 已清空，仍需下一轮按 Task 6 正式让 boundary guard GREEN 并检查 forbidden auth patterns。`docs/architecture.md` 本轮随 runtime truth 小幅同步，但 root docs/current-status 仍按 plan 由后续最终 gate/plan-01 处理。
- 下一步：Task 6 运行 architecture guard、forbidden pattern grep、required transport files 检查和 focused package tests。

---

## Task 6: Make boundary guard GREEN

- [x] 完整读取 goal 三文件并注册本轮小 todo。
- [x] 运行 architecture guard：

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture -count=1
```

- [x] 检查 forbidden auth patterns：

```powershell
rg -n "RegisterPlatformRoutes|platform_handler|platform_route|platform_dto|/api/Users|auth\.RegisterRoutes" internal
Get-ChildItem .\internal\module\auth -File | Where-Object { $_.Name -in @('route.go','handler.go','request.go','handler_test.go') -or $_.Name -like 'platform_*' -or $_.Name -like 'app_*' -or $_.Name -like 'admin_*' }
```

- [x] 检查 required transport files 八个/十个 required paths 均存在；如 plan step 与 architecture guard 数量不一致，按 guard 的十个 auth transport files 记录并修正任务说明。
- [x] 运行 focused package tests：

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture ./internal/module/auth ./internal/module/auth/transport/admin ./internal/module/auth/transport/app ./internal/module/user ./internal/server ./internal/middleware -count=1
```

- [x] 如有代码修改，提交 backend commit。

完成记录预留：
- 动作：正式运行 boundary guard 并让其 GREEN；执行 forbidden pattern grep 时发现两个非 runtime 污染点：architecture guard 自身保存 `platform_*` 旧文件路径 literal、`internal/middleware/README.md` 仍记录旧 `POST /api/Users/refresh`，按 root cause 修正为运行时拼接旧文件名并更新 middleware README 的 app auth public routes；未修改业务 runtime。
- 验证：
  - `go test ./internal/architecture -count=1`：exit 0，`ok admin_back_go/internal/architecture 0.422s`。
  - `rg -n "RegisterPlatformRoutes|platform_handler|platform_route|platform_dto|/api/Users|auth\.RegisterRoutes" internal`：修正后 exit 1，无 forbidden pattern 命中。
  - `Get-ChildItem .\internal\module\auth -File | Where-Object { ... }`：`offender_count=0`。
  - required auth transport files：10/10 存在，`missing_count=0`，包括 admin/app 各 `route.go`、`handler.go`、`handler_test.go`、`request.go`、`presenter.go`。
  - `go test ./internal/architecture ./internal/module/auth ./internal/module/auth/transport/admin ./internal/module/auth/transport/app ./internal/module/user ./internal/server ./internal/middleware -count=1`：exit 0，七个 package 均 `ok`。
  - `git diff --check` in `admin_back_go`：exit 0。
  - backend commit：`74e8c82 test: harden auth transport boundary guard`。
- 剩余风险：本轮没有执行 Checkpoint B 的综合 debug loop，也没有执行 Task 7 full backend `go test ./...`、frontend legacy grep、root governance final gate；这些仍是后续任务。`internal/middleware/README.md` 已同步 public auth route 列表，但 root docs/current-status 的最终同步仍按 Task 7/8 处理。
- 下一步：Checkpoint B after Task 6 大型全面检查-debug循环。

---

## Checkpoint B after Task 6: 大型全面检查-debug循环

必须检查并记录：
- [x] 需求是否偏离：plan-02 范围仍未扩散到 plan-03 module consolidation。
- [x] 代码 bug：route registration、middleware whitelist、handler tests、architecture guard 是否一致。
- [x] 类型检查/构建：focused package tests 当前轮是否通过。
- [x] 测试覆盖：RED guard 是否已变 GREEN；legacy route not registered 是否覆盖 auth+user 六条旧路径。
- [x] UI/UX：不做 UI 改动；frontend grep 是破坏性删除的安全证据。
- [x] 安全性：旧 public routes 已删除；新 admin/app auth paths 保持原公开登录语义。
- [x] 数据一致性：无 DB/migration 改动。
- [x] 文档同步：如 runtime 已改，只在最终验证后再同步必要 status/contract；本 plan 原文说 root docs 由 plan-01 owning，默认不改 root docs。
- [x] 回滚方案：各 backend commits 可逐 task revert。

完成记录预留：
- 动作：执行 Task 6 后综合 debug loop；用 `git show e3e807e^:internal/module/auth/route.go` / `user/route.go` 回看旧 runtime，确认旧 auth routes 为 `POST /api/Users/getLoginConfig|sendCode|login|refresh|logout`，旧 user route 为 `POST /api/Users/init`；发现现有 `TestLegacyUsersRoutesAreNotRegistered` 覆盖缺口：`getLoginConfig` 方法写成 GET 且漏掉 `logout`，已修正为覆盖 auth+user 六条旧 POST routes；提交 backend commit `7075171 test: cover retired users legacy routes`。
- 验证：
  - `git status --short --branch` in `admin_back_go`：起始 clean，`master...origin/master [ahead 6]`；收尾 clean，`ahead 7`。
  - `go test ./internal/server -run TestLegacyUsersRoutesAreNotRegistered -count=1`：exit 0，legacy route coverage test 通过。
  - `go test ./internal/architecture ./internal/module/auth ./internal/module/auth/transport/admin ./internal/module/auth/transport/app ./internal/module/user ./internal/server ./internal/middleware -count=1`：exit 0，七个 focused packages 均 `ok`。
  - `rg -n "RegisterPlatformRoutes|platform_handler|platform_route|platform_dto|/api/Users|auth\.RegisterRoutes" internal`：exit 1，无 forbidden pattern。
  - `git diff --check` in `admin_back_go`：exit 0。
  - `rg -n "/api/Users" admin_front_ts\src admin_app\src -g "!*node_modules*" -g "!*dist*" -g "!*build*"`：exit 1，frontend production source 无 legacy caller。
  - `git -C admin_front_ts status --short --branch`：显示 `tests/shared/user/users-api.test.ts` 有既有工作区改动；本轮未改前端。
  - root `git diff --check`：exit 0。
  - root `powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working`：PASS。
- 剩余风险：还未执行 Task 7 的 full backend `go test ./...`、最终 frontend grep（包含 tests/admin_app tests）、最终 root governance gate与 handoff statement；root 工作区仍有 plan/docs/goal 相关未提交改动，`admin_front_ts/tests/shared/user/users-api.test.ts` 也有既有改动，需在 Task 7/8 按最终验证语义处理。
- 下一步：Task 7 Final verification gate for plan-02。

---

## Task 7: Final verification gate for plan-02

- [ ] 完整读取 goal 三文件并注册本轮小 todo。
- [ ] 运行 backend focused tests：

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture ./internal/module/auth ./internal/module/auth/transport/admin ./internal/module/auth/transport/app ./internal/module/user ./internal/server ./internal/middleware -count=1
```

- [ ] 运行 backend full tests：

```powershell
cd E:\admin_go\admin_back_go
go test ./... -count=1
```

- [ ] 运行 frontend deleted legacy grep：

```powershell
cd E:\admin_go
rg -n "/api/Users" admin_front_ts\src admin_front_ts\tests admin_app\src admin_app\tests -g "!*node_modules*" -g "!*dist*"
```

- [ ] 运行 root governance gates：

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

- [ ] 准备 plan 要求 handoff scope statement：

```text
Completed in plan-02: auth transport reorg (transport/{admin,app}) + /api/Users backend removal + boundary architecture guard.
Not executed in plan-02: captcha/session/usersession/userloginlog merge (plan-03), governance docs (plan-01), frontend legacy cleanup (plan-04), shared/dict, smaller module shells, AI aggregation, internal/platform -> internal/infra rename.
Plan-03 must execute next to fully complete spec §12.1.
```

- [ ] 如有最终修复性代码修改，提交 backend/root 对应 commit。

完成记录预留：
- 动作：
- 验证：
- 剩余风险：
- 下一步：

---

## Task 8: Final largest review, repair, and goal completion

- [ ] 完整读取 goal 三文件并注册本轮小 todo。
- [ ] 从 C 端/API 行为、代码边界、安全性、权限、错误处理、测试、构建、文档、回滚角度做最终审计。
- [ ] 对所有 explicit requirements 建立完成证据矩阵，不用窄检查证明宽范围。
- [ ] 若发现高风险问题，修缮并重新运行相关测试；若有代码修改，提交对应 commit。
- [ ] 更新 `tasks.md` 最终记录。
- [ ] 调用 goal tool 标记 complete。

完成记录预留：
- 动作：
- 验证：
- 剩余风险：
- 下一步：

---

## Final Checkpoint: 最终最大 review

必须覆盖并记录：
- [ ] C 端/API：admin/app auth 路径仍正确，legacy `/api/Users/*` 确认 404/unregistered。
- [ ] 代码：transport/admin 与 transport/app package 边界清晰；root auth 只保留 service/dto/repository/model/code/jobs 等跨平台合约。
- [ ] 安全：public whitelist 只保留新登录路径；删除旧路径不创建绕过。
- [ ] 权限：RBAC/PermissionCheck 不因 auth route 移动改变语义。
- [ ] 错误处理：apperror/response/i18n 路径不退化。
- [ ] 测试：RED->GREEN guard、focused tests、full backend tests 有证据。
- [ ] 构建：`go build ./...` 或 `go test ./...` 覆盖编译。
- [ ] 文档：不把 planned 写成 implemented；如根 docs 未改，说明 plan-01 owns docs。
- [ ] 回滚：记录 task commits/revert 路径。
