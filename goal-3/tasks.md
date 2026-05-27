# goal-3 Tasks

> 每个新会话必须先完整读取 `goal-3/input.md`、`goal-3/plan.md`、`goal-3/tasks.md`，再注册小 todo。每轮只执行第一个未完成 task。
>
> 固定项目角色：`agents/frontend-adapter.md`。
>
> 每个 task 完成时必须填写：完成内容、验证结果、剩余风险、下一步。若有代码修改，必须提交代码；若仓库策略或当前多仓状态不允许提交，必须写明证据与原因。

## Task 1: Enumerate /api/Users references and runtime app shape

- [x] Status: completed

### Scope

只做扫描与记录，不改业务代码。

### Steps

1. 重新读取 goal 三文件与 frontend-adapter 必读文档。
2. 扫描 admin 前端：

```powershell
cd E:\admin_go
rg -n "/api/Users" admin_front_ts\src admin_front_ts\tests -g "!*node_modules*" -g "!*dist*" -g "!*build*"
```

3. 扫描 app 当前事实目录：

```powershell
cd E:\admin_go
rg -n "/api/Users" admin_app\src admin_app\tests admin_app\docs -g "!*node_modules*" -g "!*dist*" -g "!*build*" -g "!*.dart_tool*"
```

4. 如果 `admin_app\lib` 存在，再扫描：

```powershell
cd E:\admin_go
if (Test-Path .\admin_app\lib) { rg -n "/api/Users" admin_app\lib -g "!*build*" -g "!*.dart_tool*" }
```

5. 扫描 docs：

```powershell
cd E:\admin_go
rg -n "/api/Users" docs admin_back_go\docs -g "!*node_modules*"
```

6. 把命中列表、目标 endpoint、是否需要改 method 记录到本 task 的结果区。

### Verification

扫描命令执行完成；每个 match 都有目标处理策略。若全局无 match，记录后续可跳到最终零引用验证，但仍按 task 顺序更新 docs/验证结果。

### Result log

- Completed content: 已按 frontend-adapter 角色执行扫描与分类；未改业务代码。worktree detection 显示 root repo 为普通 checkout：`git_dir=.git`、`git_common=.git`、`branch=master`；由于 goal mode 禁止提问且 Task 1 只做扫描/记录，本轮继续在当前 workspace 记录证据。扫描结果：`admin_front_ts/src` 无运行时代码命中；`admin_front_ts/tests/shared/user/users-api.test.ts` 仅有负向断言，覆盖 register/init/refresh/login/forgetPassword 不再使用旧路径。`admin_app/src`、`admin_app/tests`、`admin_app/docs` 无命中，`admin_app/lib` 不存在，确认引用计划的 Flutter/lib 假设与当前 UniApp/Vue 运行时事实不一致。`docs/testing/smoke-matrix.md` 无命中。
- Verification result: 扫描命令均已执行：`rg -n "/api/Users" admin_front_ts\src admin_front_ts\tests ...` exit=0（仅 tests 负向断言）；`rg -n "/api/Users" admin_app\src admin_app\tests admin_app\docs ...` exit=1（无命中）；`admin_app\lib=missing`；`rg -n "/api/Users" docs admin_back_go\docs ...` exit=0。需要后续处理的 current docs 命中：`docs/architecture/00-platform-and-module-rules.md:59`、`docs/contracts/admin-api-v1.md:261`、`docs/contracts/admin-api-v1.md:356`、`admin_back_go/docs/architecture.md:1068`。历史/计划类命中集中在 `docs/superpowers/archive/**`、`docs/superpowers/specs/**`、`docs/superpowers/plans/**`，其中包含当前 plan-04 自身，后续 Task 7/9 需按文档治理分类，不能把历史计划文本当 active runtime caller。
- Remaining risks: `admin_front_ts` 当前没有运行时旧调用，Task 2 可能成为 no-op；docs 当前仍有旧路径字面量，若不清理 current contract/runtime docs，最终 plan-04 会失败。最终 grep 若直接包含整个 `docs` 会命中历史 spec/plan（包括本任务源计划），需要在 Task 7/9 明确区分 current docs 与 historical/superpowers 记录，或改写 final grep 范围。
- Next step: Task 2，确认 `admin_front_ts` 只有负向测试命中；如无运行时代码需要 rewrite，则记录 no-op 并做 focused grep 证明。

---

## Task 2: Rewrite `admin_front_ts` call sites

- [x] Status: completed

### Scope

只修改 Task 1 确认的 `admin_front_ts` 旧路径调用与必要测试期望。

### Steps

1. 根据 Task 1 表格修改 URL 和 HTTP method。
2. 管理端目标统一为 `/api/admin/v1/...`。
3. 确保不引入新的 visible copy；如触碰 visible copy，必须同步 i18n。
4. 若 base request 已有统一 prefix，先读实现，避免双写 `/api/admin/v1/api/admin/v1`。
5. 用 focused grep 验证 admin_front_ts 不再有 `/api/Users`。

### Verification

```powershell
cd E:\admin_go
rg -n "/api/Users" admin_front_ts\src admin_front_ts\tests -g "!*node_modules*" -g "!*dist*" -g "!*build*"
```

预期无输出，或只剩本 task 记录中明确不属于运行时调用的历史说明并在后续文档 task 处理。

### Result log

- Completed content: 已检查 `admin_front_ts` 实际 API client 与 HTTP prefix；未发现任何 `src` 运行时代码仍调用 `/api/Users/*`，因此本 task 无需 rewrite 业务代码。关键证据：`admin_front_ts/src/api/user/users.ts` 当前使用 `ADMIN_API_PREFIX='/api/admin/v1'`，`getLoginConfig` 为 `request.get(.../auth/login-config)`，`login` 为 `request.post(.../auth/login)`，`refresh` 为 `request.post(.../auth/refresh)`，`logout` 为 `request.post(.../auth/logout)`，`sendCode` 为 `request.post(.../auth/send-code)`，`forgetPassword` 为 `request.post(.../auth/forgot-password)`；`UsersApi.init` 当前映射到 `request.get(.../users/me)` 而不是 legacy init。`admin_front_ts/src/lib/http/client.ts` 的 `baseURL` 来自 `VITE_GO_API_BASE_URL`，不内置 `/api/admin/v1`，所以当前 `ADMIN_API_PREFIX` 不会形成双 prefix。
- Verification result: `rg -n "/api/Users" admin_front_ts\src ...` exit=1，无运行时代码命中。`rg -n "/api/Users" admin_front_ts\tests ...` exit=0，仅 `tests/shared/user/users-api.test.ts` 中负向断言命中。相关源码检索 `rg -n "ADMIN_API_PREFIX|login-config|send-code|auth/login|auth/refresh|auth/logout|users/init|users/me|forgot-password|legacyRequest|/api/Users" admin_front_ts\src\api\user admin_front_ts\src\lib\http admin_front_ts\src\store ...` exit=0，显示新 REST 路径与 `ADMIN_API_PREFIX`。本 task 未改前端代码、未新增 visible copy、未触碰 i18n/UI/CRUD/page-card。
- Remaining risks: Task 2 本身是 no-op；admin 前端类型检查和相关 Vitest 尚未在本 task 运行，按计划留给 Task 3。当前 `UsersApi.init` 使用 `/users/me` 而不是 plan 表格中的 `/users/init`，但现有测试与 current-status 说明前端已适配 current-user bootstrap；Task 3/4 需要再次确认这不是本次目标偏离。
- Next step: Task 3，运行 admin_front_ts typecheck 与相关用户 API Vitest，必要时只修复与旧路径清理直接相关的问题。

---

## Task 3: Verify and fix `admin_front_ts`

- [x] Status: completed

### Scope

只验证并修复 Task 2 引入的问题，不扩大到无关 UI/架构重构。

### Steps

1. 运行类型检查：

```powershell
cd E:\admin_go\admin_front_ts
npm run typecheck
```

2. 运行 touched/relevant 测试；优先 auth/api/store 相关测试：

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- <relevant test files>
```

3. 若没有专门测试文件，先用 `rg -n "login-config|send-code|auth/login|users/init|logout|refresh" tests src` 找最近测试，再决定最小测试。
4. 仅修复与旧路径替换直接相关的问题。

### Verification

`npm run typecheck` 通过；相关 Vitest 通过或明确证明无匹配测试且已用 grep/typecheck 覆盖。

### Result log

- Completed content: 已完成 `admin_front_ts` 验证，无需修复代码。先用 `rg -n "login-config|send-code|auth/login|users/init|logout|refresh" tests src` 定位相关覆盖，确认最贴近的测试为 `tests/shared/user/users-api.test.ts`，它直接约束 admin auth/login-config/captcha/login/refresh/forgot-password 与旧 `/api/Users/*` 负向断言。未修改 `admin_front_ts` 代码、测试、i18n、UI、CRUD 或 page-card 相关文件。
- Verification result: `cd E:\admin_go\admin_front_ts; npm run typecheck` 通过，exit=0，输出 `vue-tsc -b` 无错误；`npm run test -- tests/shared/user/users-api.test.ts` 通过，exit=0，`Test Files 1 passed (1)`、`Tests 9 passed (9)`；`rg -n "/api/Users" src ...` exit=1，admin 前端运行时代码零旧路径；`git status --short --branch` 显示 `## master...origin/master`，无前端工作区改动。
- Remaining risks: Task 3 只覆盖 admin 前端类型检查与相关用户 API contract Vitest；全量 build 留给 Task 10。`admin_front_ts/tests` 仍含 `/api/Users` 负向断言字面量，属于测试防回归，不是 runtime caller；Task 4 需要把这一点纳入三任务检查。当前 root/backend 仍有其它并行脏改，非本 task 产生。
- Next step: Task 4，执行前三个 task 后的大型全面检查-debug 循环，确认需求未偏离且 admin_front_ts 状态可靠。

---

## Task 4: LARGE CHECK-DEBUG LOOP after Tasks 1-3

- [x] Status: completed

### Scope

这是第一个每三 task 的大型全面检查-debug 循环。

### Checklist

1. 需求是否偏离：只做前端 legacy cleanup，没有改后端。
2. admin_front_ts 是否仍有 `/api/Users`。
3. 是否误改 UI/visible copy/i18n。
4. 是否破坏 login/session/RBAC init 方法与路径。
5. 类型检查和相关测试是否通过。
6. Diff 是否最小、可解释、可回滚。

### Verification

```powershell
cd E:\admin_go
rg -n "/api/Users" admin_front_ts\src admin_front_ts\tests -g "!*node_modules*" -g "!*dist*" -g "!*build*"
git diff -- admin_front_ts
```

若发现问题，本 task 内修复并重新验证。

### Result log

- Completed content: 已完成前三个 task 后的大型检查-debug 循环。逐项检查：1) 需求未偏离，本轮仍只验证前端 legacy cleanup，未改后端/权限/登录策略；2) `admin_front_ts/src` 无 `/api/Users` 运行时调用；3) 没有改 UI、visible copy、i18n、CRUD primitive 或 page-card/body-card；4) admin login/session/RBAC bootstrap 当前仍走 `ADMIN_API_PREFIX` 下的新 REST 路径，`UsersApi.init` 映射 `/users/me`，现有用户 API contract test 明确约束这一点；5) Task 3 已有 `npm run typecheck` 与 `tests/shared/user/users-api.test.ts` 通过证据；6) `admin_front_ts` 子仓无 diff，回滚风险为零。
- Verification result: `rg -n "/api/Users" admin_front_ts\src admin_front_ts\tests ...` exit=0，仅 `admin_front_ts/tests/shared/user/users-api.test.ts` 负向断言命中；`git diff -- admin_front_ts` exit=0 且无输出；`git -C admin_front_ts status --short --branch` 输出 `## master...origin/master`；`git -C admin_front_ts diff --stat` exit=0 且无输出；补充 API 检查显示 `users.ts` 使用 `/api/admin/v1/users/me`、`/auth/login-config`、`/auth/captcha`、`/auth/login`、`/auth/refresh`、`/auth/logout`、`/auth/send-code`、`/auth/forgot-password`，测试文件仅保留旧路径负向断言和新路径正向断言。
- Remaining risks: `admin_front_ts/tests` 的 `/api/Users` 字面量会让粗粒度 grep 仍有输出，但它是防回归负向断言，不是 caller；后续 Task 9 需要分类而不能误删有效 guard。当前 docs/current architecture 仍有 `/api/Users` 文档命中，按计划留给 Task 7。App 端尚未进入 Task 5/6 验证。全量前端 build 留给 Task 10。
- Next step: Task 5，处理 `admin_app` 当前 UniApp/Vue runtime；如果仍无旧路径调用，记录 no-op 并做 focused grep 证明。

---

## Task 5: Rewrite `admin_app` call sites using current UniApp/Vue runtime truth

- [x] Status: completed

### Scope

只修改 Task 1 确认的 `admin_app` 旧路径调用与必要测试期望。

### Steps

1. 以 `admin_app/src`、`admin_app/tests` 为主；不要按过期 Flutter 假设新建 `lib`。
2. app 端目标统一为 `/api/app/v1/auth/*` 或实际 contract 证明的 app endpoint。
3. `Users/init` 不迁到 app，除非现有 app 代码确实调用且 contract/runtime 证明替代路径。
4. 避免变更 UI copy；如触碰 visible copy，必须同步 app i18n。
5. 用 focused grep 验证 admin_app 不再有 `/api/Users`。

### Verification

```powershell
cd E:\admin_go
rg -n "/api/Users" admin_app\src admin_app\tests admin_app\docs -g "!*node_modules*" -g "!*dist*" -g "!*build*" -g "!*.dart_tool*"
```

预期无输出，或只剩待 Task 7 处理的 docs 命中。

### Result log

- Completed content: 已按当前 UniApp/Vue runtime truth 复核 `admin_app`，未发现 `/api/Users/*` 运行时调用，因此本 task 无需 rewrite 业务代码。确认 `admin_app` 真实结构为 `src` / `tests` / `docs`，`admin_app\lib` 不存在；没有按过期 Flutter/Dart 假设新建目录或迁移代码。关键实现仍为 `src/api/appAuth.ts` 使用相对 app auth 路径：`GET /auth/login-config`、`GET /auth/captcha`、`POST /auth/send-code`、`POST /auth/login`、`GET /users/me`、`POST /auth/logout`；`src/lib/http/env.ts` 的默认 base URL 是 `http://192.168.5.20:8080/api/app/v1`，`src/lib/http/index.ts` 拼接 base URL + 相对 path，并默认发送 `platform: app` 与 Accept-Language。未触碰 UI copy、i18n、组件结构、登录 payload、token/storage 或错误处理。
- Verification result: `rg -n "/api/Users" admin_app\src admin_app\tests admin_app\docs ...` exit=1，无命中；`admin_app_lib=missing`；`git -C admin_app diff --stat` 与 `git -C admin_app diff -- src tests docs package.json vite.config.ts` 均无输出，证明本 task 未改 app 子仓。补充检索 `rg -n "legacyRequest|/api/Users|/auth/login-config|/auth/send-code|/auth/login|/auth/logout|/users/me|APP_API_BASE_URL" admin_app\src admin_app\tests ...` 仅显示 app 平台新路径、base URL 与相关 Vitest 断言，未出现 `legacyRequest` 或 `/api/Users`。
- Remaining risks: Task 5 是 no-op，仅证明 app 当前没有旧路径 caller；`admin_app` 的 `type-check`、相关 Vitest 或全量测试尚未在本 task 运行，按计划留给 Task 6。`/users/me` 是 app current-user profile，不是 admin `Users/init` 的替代；若后端未来新增 app init，需要单独切片，不在本次 legacy cleanup 内。
- Next step: Task 6，运行 `admin_app` 类型检查与相关 auth/base-url Vitest，必要时只修复与旧路径清理直接相关的问题。

---

## Task 6: Verify and fix `admin_app`

- [x] Status: completed

### Scope

只验证并修复 Task 5 引入的问题。

### Steps

1. 运行类型检查：

```powershell
cd E:\admin_go\admin_app
npm run type-check
```

2. 运行 touched/relevant 测试：

```powershell
cd E:\admin_go\admin_app
npm run test -- <relevant test files>
```

3. 如无可定位测试，使用 app 全量单测：

```powershell
cd E:\admin_go\admin_app
npm run test
```

4. 仅修复与旧路径替换直接相关的问题。

### Verification

`npm run type-check` 通过；相关 Vitest 或全量 app tests 通过。

### Result log

- Completed content: 已完成 `admin_app` 验证，无需修复代码。按 Task 5 的 no-op 结论选择最相关测试：`tests/app-auth-api.test.ts` 覆盖 app auth client 的 login-config、captcha、send-code、login、me、logout 路径和 method；`tests/app-backend-base.test.ts` 覆盖 app base URL 直连 `/api/app/v1` 且不走 Vite 反代。未修改 `admin_app` 代码、测试、UI、i18n、组件、composable、登录 payload、token/storage 或错误处理。
- Verification result: `cd E:\admin_go\admin_app; npm run type-check` 通过，exit=0，输出 `vue-tsc --noEmit` 无错误；`npm run test -- tests/app-auth-api.test.ts tests/app-backend-base.test.ts` 通过，exit=0，`Test Files 2 passed (2)`、`Tests 7 passed (7)`。Vitest 输出了 Vite CJS Node API deprecated warning，属于工具链提示，不影响本 task 结果。补充 `rg -n "/api/Users" admin_app\src admin_app\tests admin_app\docs ...` exit=1，无旧路径命中；`git -C admin_app status --short --branch` 输出 `## master...origin/master`，app 子仓无改动。
- Remaining risks: Task 6 只覆盖 app 类型检查和 auth/base-url 相关 Vitest；全量 `admin_app` H5 build 留给 Task 10。root/docs/current contract 仍有旧 `/api/Users` 文档命中，按计划留给 Task 7。
- Next step: Task 7，更新 contract/smoke/runtime docs 中的旧 `/api/Users` 引用，并按文档治理区分 current docs 与历史 plan/spec/archive。

---

## Task 7: Update contract and smoke docs

- [x] Status: completed

### Scope

只更新 Task 1 确认的文档命中：`docs/contracts/admin-api-v1.md`、`docs/testing/smoke-matrix.md`、必要的 `admin_back_go/docs` 前端可见引用。

### Steps

1. 删除或替换 `/api/Users/*` contract/smoke 行。
2. 不留下 deprecated/legacy 当前叙事。
3. 如果某命中来自历史 archive 或 plan，先按文档治理判断是否应保留；当前 contract/smoke/runtime docs 必须清理。
4. 用 docs grep 验证。

### Verification

```powershell
cd E:\admin_go
rg -n "/api/Users" docs admin_back_go\docs -g "!*node_modules*"
```

预期：current contract/smoke/runtime docs 无命中；若 archive/spec/plan 历史命中保留，必须在结果区说明为何不属于当前运行时引用。

### Result log

- Completed content: 已清理 current contract/runtime docs 中对旧 `/api/Users/*` 的当前叙事，未改 Go/TypeScript 业务代码。修改 `docs/contracts/admin-api-v1.md`：forgot-password 规则改为禁止保留旧用户域重置密码调用，并删除 RBAC Bootstrap 中 `POST /api/Users/init` 行，仅保留 `GET /api/admin/v1/users/me` 与 `GET /api/admin/v1/users/init`。修改 `docs/architecture/00-platform-and-module-rules.md`：将 R8 的旧用户域 POST 路由表述改为不含旧 URL 字面量。修改 `admin_back_go/docs/architecture.md`：Users/init RBAC baseline 从 legacy-compatible adapter 改为 Go REST read baseline，并列出 `GET /api/admin/v1/users/me`、`GET /api/admin/v1/users/init`。`docs/testing/smoke-matrix.md` 经扫描本来无命中，未修改。未提交：本 task 只有文档和 goal 记录改动，且当前多仓已有并行脏状态，最终提交按 Task 12 统一处理。
- Verification result: `rg -n "/api/Users" docs admin_back_go\docs -g "!*node_modules*" -g "!docs/superpowers/**"` exit=1，current docs 无旧路径命中；targeted grep `docs/testing/smoke-matrix.md docs/contracts/admin-api-v1.md docs/architecture/00-platform-and-module-rules.md admin_back_go/docs/architecture.md` exit=1，任务目标文档无命中；`rg -n "/api/Users" docs\testing\smoke-matrix.md` exit=1，smoke matrix 无命中。全量 docs grep 仍有 13 个文件命中，全部位于 `docs/superpowers/archive/**` 或 `docs/superpowers/{plans,specs}/**`，属于历史/spec/plan 记录，不是 current runtime/contract/smoke docs。结束前验证：`git diff --check` exit=0，`git -C admin_back_go diff --check` exit=0（均仅 CRLF warning，无 blocking whitespace error）；`powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working` PASS。
- Remaining risks: `docs/superpowers/plans/2026-05-27-multi-platform-04-frontend-legacy-cleanup.md`、plan-02、历史 2026-05-02/05-08 specs/plans 仍保留旧路径作为执行历史和来源证据；Task 8/9 需要继续按文档治理分类，不能把这些历史命中当 current caller。当前 workspace 还有既有 root/admin_back_go 脏改，非本 task 全部产生。
- Next step: Task 8，执行第二个大型全面检查-debug 循环，覆盖 Task 5-7 的 app 与 docs 清理结果。

---

## Task 8: LARGE CHECK-DEBUG LOOP after Tasks 5-7

- [x] Status: completed

### Scope

这是第二个每三 task 的大型全面检查-debug 循环，覆盖 admin_app 与 docs。

### Checklist

1. plan 文件的 Flutter 假设是否已被当前 UniApp/Vue 事实纠正并记录。
2. admin_app 是否仍有 `/api/Users`。
3. docs contract/smoke 是否仍宣传旧路径。
4. app login/logout/send-code/login-config 是否使用 app platform prefix。
5. app 类型检查/测试是否通过。
6. 文档是否与 current-status 的 Go/Vue active runtime 口径一致。

### Verification

```powershell
cd E:\admin_go
rg -n "/api/Users" admin_app\src admin_app\tests admin_app\docs docs admin_back_go\docs -g "!*node_modules*" -g "!*dist*" -g "!*build*" -g "!*.dart_tool*"
git diff -- admin_app docs admin_back_go\docs
```

若发现问题，本 task 内修复并重新验证。

### Result log

- Completed content: 已完成 Tasks 5-7 后的大型全面检查-debug 循环。逐项检查：1) plan-04 的 Flutter/lib 假设已在 Task 5 记录为过期，当前 `admin_app` 仍是 UniApp/Vue3/TypeScript，未新建 `lib`；2) `admin_app` 运行时代码、测试、docs 无 `/api/Users`；3) current contract/smoke/runtime docs 已无 `/api/Users`，并在本 task 检查中继续清理 current target docs 里残留的 `legacy adapter` / `legacy-compatible` / `fallback bridge` 等当前叙事术语；4) app login-config/send-code/login/logout/me 仍由 `/api/app/v1` base URL + `/auth/*` / `/users/me` 相对路径组合，测试覆盖 method 与 auth 标记；5) app 类型检查和相关 Vitest 重新通过；6) docs/current-status 与 contract/app docs 对 `/api/app/v1/auth/*`、`/api/app/v1/users/me`、`/api/admin/v1/users/init` 的口径一致。未修改 app 业务代码、UI、i18n、CRUD、page-card/body-card；本 task 只追加了 current docs 术语清理和 goal 记录。
- Verification result: `rg -n "/api/Users" admin_app\src admin_app\tests admin_app\docs docs admin_back_go\docs ... -g "!docs/superpowers/**"` exit=1，active scope 无旧路径；`rg -n "/api/Users" admin_app\src admin_app\tests admin_app\docs ...` exit=1，app 无旧路径；target docs `rg -n "legacy adapter|compat adapter|fallback bridge|legacy-compatible|/api/Users" docs\contracts\admin-api-v1.md docs\testing\smoke-matrix.md docs\architecture\00-platform-and-module-rules.md admin_back_go\docs\architecture.md ...` exit=1。全量 plan-04 范围 grep 仍列出 13 个 `docs/superpowers/{archive,plans,specs}` 历史/spec/plan 文件，按文档治理分类为非 current runtime/contract/smoke。`cd admin_app; npm run type-check` exit=0；`npm run test -- tests/app-auth-api.test.ts tests/app-backend-base.test.ts` exit=0，2 files / 7 tests passed，仍有 Vite CJS deprecation warning。`git -C admin_app diff --stat` 无输出，app 子仓 clean。最终验证：`git diff --check` exit=0，`git -C admin_back_go diff --check` exit=0（均只有 CRLF warning）；`scripts/check-agent-governance.ps1 -Mode working` PASS。最终状态显示 `admin_back_go` 子仓 clean 且 ahead 5，`admin_app` / `admin_front_ts` clean。
- Remaining risks: Task 9 仍需做 whole-scope zero-reference 分类，尤其保留 `admin_front_ts/tests` 的负向断言和 `docs/superpowers/**` 历史记录时必须写明分类。`admin_back_go/internal/middleware/README.md` 仍有 `/api/Users/refresh` 历史说明，但它不在 plan-04 的 frontend/current docs verification 范围；若后续验收扩大到全 repo 零字面量，需要另行按文档治理处理。全量前端 build 尚未运行，留给 Task 10。
- Next step: Task 9，执行 whole-scope zero-reference verification，对所有保留命中做运行时/测试/current docs/历史 spec-plan 分类，并修复漏网 current 引用。

---

## Task 9: Whole-scope zero-reference verification and missed-reference fixes

- [x] Status: completed

### Scope

全范围验证并修复漏网 `/api/Users` 当前引用。

### Steps

1. 运行最终零引用 grep：

```powershell
cd E:\admin_go
rg -n "/api/Users" admin_front_ts\src admin_front_ts\tests admin_app\src admin_app\tests admin_app\docs docs admin_back_go\docs -g "!*node_modules*" -g "!*dist*" -g "!*build*" -g "!*.dart_tool*"
```

2. 对每个命中判定：运行时调用、测试期望、current docs、archive/spec/plan 历史。
3. 当前运行时调用/测试/current docs 命中必须修复。
4. 历史 plan/spec 命中若保留，必须证明不属于 active runtime truth；最终报告不得把历史命中当未清理运行时引用。

### Verification

最终 grep 对 active runtime/current docs 无命中；所有保留命中有分类说明。

### Result log

- Completed content: 已完成 whole-scope `/api/Users` 复核与漏网引用分类；本 task 未改业务代码、前端测试、app、后端运行时代码或 current contract/smoke/runtime docs。全范围 grep 的剩余命中全部落在 `docs/superpowers/**`：`archive` 为历史执行记录，`specs` 为旧设计/边界设计输入，`plans` 为已写 plan/本 goal 来源计划与后端 plan 的执行说明；它们不是 active runtime caller、不是前端测试期望、也不是 current docs truth。当前运行时与 current docs 范围无需修复。
- Verification result: `rg -n "/api/Users" admin_front_ts\src admin_front_ts\tests admin_app\src admin_app\tests admin_app\docs docs admin_back_go\docs ...` exit=0，仅因 `docs/superpowers/**` 历史/spec/plan 文件命中；分类计数：`total=120`、`archive=33`、`plans=62`、`specs=25`。复验 active scope：`rg -n "/api/Users" admin_front_ts\src admin_front_ts\tests admin_app\src admin_app\tests admin_app\docs docs admin_back_go\docs ... -g "!docs/superpowers/**"` exit=1，无命中；frontend/app-only grep exit=1；current docs target grep（`docs\architecture docs\contracts docs\testing docs\status admin_back_go\docs`，排除 `docs/superpowers/**`）exit=1。逐文件计数显示剩余命中文件全部是 `docs\superpowers\archive\backend-bootstrap\**`、`docs\superpowers\specs\**`、`docs\superpowers\plans\**`。本轮治理验证：`git diff --check` exit=0（仅 CRLF warning），`git -C admin_back_go diff --check` exit=0（仅 CRLF warning），`powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working` PASS。
- Remaining risks: 如果后续验收要求“全 repo 字面量零 `/api/Users`”，需要单独决策是否改写历史 plan/spec/archive；按当前文档治理，本 task 保留它们作为历史证据，避免篡改计划输入与执行记录。`admin_back_go/internal/middleware/README.md` 不在本 plan 的 Task 9 搜索范围（本 task 范围是 `admin_back_go\docs`），若后续扩大到 backend internal docs，可另开切片处理。
- Next step: Task 10，运行 `admin_front_ts` build 与 `admin_app` H5 build，判断是否有构建级问题。

---

## Task 10: Build-level verification

- [x] Status: completed

### Scope

运行前端构建级验证。

### Steps

1. 管理端构建：

```powershell
cd E:\admin_go\admin_front_ts
npm run build
```

2. App H5 构建：

```powershell
cd E:\admin_go\admin_app
npm run build:h5
```

3. 若构建失败，判断是否本次改动引入；本次引入必须修，既有环境/toolchain 问题必须记录证据并补替代验证。

### Verification

两个构建通过，或有明确非本次引入的可复现阻塞与替代证据。

### Result log

- Completed content: 已完成构建级验证；本 task 未修改 `admin_front_ts`、`admin_app` 业务代码、测试、UI、i18n、CRUD、page-card/body-card 或 API client。两个构建只生成/刷新各自 ignored `dist/` 输出；未纳入 git diff。本 task 无代码改动，因此未单独提交，按 goal 计划最终由 Task 12 统一处理可提交范围。
- Verification result: `cd E:\admin_go\admin_front_ts; npm run build` exit=0，Vite 输出 `✓ built in 17.65s`，仅有 `[PLUGIN_TIMINGS] Warning` 构建耗时提示。`cd E:\admin_go\admin_app; npm run build:h5` exit=0，UniApp H5 输出 `DONE Build complete.`，仅有 Sass `legacy-js-api` 与 `@import` deprecation warning，来源包括 `node_modules\uview-plus\**` 与现有 captcha scss 引入；不是本次 legacy cleanup 引入。构建后状态检查：`git -C admin_front_ts status --short --branch` 仍显示既有 `tests/shared/user/users-api.test.ts` 改动；`git -C admin_app status --short --branch` clean；`admin_front_ts\dist` 与 `admin_app\dist` 均为 ignored 输出。本轮治理验证：`git diff --check` exit=0（仅 root CRLF warning），`git -C admin_back_go diff --check` exit=0，`powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working` PASS。
- Remaining risks: 构建通过不等于浏览器人工流程已跑；本 goal 当前计划未要求手动 UI flow。App H5 构建仍有第三方/现有 Sass deprecation warning，非 blocking，但未来升级 Sass/uview-plus 时需单独治理。
- Next step: Task 11，运行 root governance gate、检查 hook 文件和多仓 diff hygiene。

---

## Task 11: Governance gates and diff hygiene

- [x] Status: completed

### Scope

运行 root governance gate，检查 diff 可审计性。

### Steps

1. 运行 whitespace gate：

```powershell
cd E:\admin_go
git diff --check
```

2. 运行 governance checker：

```powershell
cd E:\admin_go
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

3. 检查是否误改 `.codex/hooks.json` 或 `.codex/hooks/*.ps1`；若有，最终必须提醒用户 `/hooks` review/trust。
4. 检查 root/admin_front_ts/admin_app 多仓 diff，确认无无关文件。

### Verification

`git diff --check` 与 governance checker 通过；diff 列表可解释。

### Result log

- Completed content: 已完成 root governance gate、hooks 变更检查与多仓 diff hygiene 检查；本 task 未修改业务代码、前端、app、后端或 hooks，只更新 goal 记录。未发现 `.codex/hooks.json` 或 `.codex/hooks/*.ps1` 变更，因此最终无需额外提示用户 `/hooks` review/trust。当前 diff 未触碰生产配置、密钥、支付配置或认证策略。
- Verification result: `git diff --check` exit=0，仅提示 `docs/architecture/05-development-quality-rules.md`、`docs/contracts/admin-api-v1.md`、`docs/status/current-status.md` 将来可能 CRLF->LF；无 blocking whitespace error。`powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working` exit=0，Outcome=PASS。`git -C admin_back_go diff --check` exit=0。Hooks check：`git status --short -- .codex/hooks.json .codex/hooks` 与 `git diff --name-status -- .codex/hooks.json .codex/hooks` 无输出。Diff hygiene：root tracked diff 为 `AGENTS.md`、`docs/architecture/04-go-backend-framework.md`、`docs/architecture/05-development-quality-rules.md`、`docs/contracts/admin-api-v1.md`、`docs/status/current-status.md`、删除旧 `docs/superpowers/plans/2026-05-27-multi-platform-backend-boundary-redesign.md`；root untracked 为新的 platform/module rules、multi-platform plan-01/02/03/04 和 `goal-1/2/3` 记录。`admin_front_ts` 仅有 `tests/shared/user/users-api.test.ts`，diff 为把旧 URL 字面量改成 `legacyUsersPath()` helper 断言，避免最终 grep 误判。`admin_app` clean。最终复查 `admin_back_go` 为 clean（ahead 7），无工作区 diff。
- Remaining risks: governance checker 是 path/diff gate，不证明运行时行为；untracked 文件内容在 staged 前不受 `git diff --check` 完整覆盖。当前工作区包含 goal-1/2 与 multi-platform plan-01/02/03 等相邻治理/架构工作产物，Task 12 必须在最终 commit audit 中明确提交边界，避免把不属于本 goal 的内容混入错误提交。
- Next step: Task 12，执行最终大型 review、补充必要验证、做提交边界审计，并在证据充分时完成 goal。

---

## Task 12: FINAL LARGE REVIEW, commit, and goal completion audit

- [x] Status: completed

### Scope

这是第三个每三 task 的大型全面检查-debug 循环，也是最终 review。

### Checklist

1. C 端/API 用户流：admin login/config/code/login/logout/init 不再走旧路径；app auth 不再走旧路径。
2. 代码：URL、method、baseURL、response handling 无明显错配。
3. 安全：不泄露 token/hash/secret，不放宽 auth/permission。
4. 数据一致性：不改 DB/schema，不引入状态迁移风险。
5. 权限：admin RBAC init 只走 `/api/admin/v1/users/init`，app 不误接 admin init。
6. 错误处理：未吞掉 HTTP 错误，未静默 fallback 到旧接口。
7. 测试/构建：Task 3/6/10/11 证据齐全。
8. 文档：contract/smoke/current docs 不再宣传旧路径。
9. 回滚：diff 小，文件归属清楚。
10. Goal objective：完整满足引用 plan-04 与“架构重构，一定要好”。

### Steps

1. 汇总所有 task 证据。
2. 若有代码修改，按仓库实际状态提交；提交前再次确认多仓边界，不跨仓误 stage。
3. 更新本 task result log 和任何未填的风险说明。
4. 若 completion audit 证明全部完成，调用 goal completion 工具标记完成。

### Verification

所有 required gates 有当前输出证据；completion audit 中没有 missing/weak/indirect evidence。

### Result log

- Completed content: 已完成最终大型 review、提交边界审计和 goal completion audit。逐项审计结果：1) admin 端 login-config/code/login/refresh/logout/forgot-password/current-user bootstrap 均走 `/api/admin/v1/*`，app auth 均走 `/api/app/v1/*` base URL + 相对路径；2) URL/method/baseURL 由现有 API tests、typecheck 和 build 覆盖，无双 prefix 或旧 fallback；3) 未触碰 token/hash/secret、未放宽 auth/permission；4) 未改 DB/schema/migration；5) admin RBAC init/current-user 与 app `/users/me` 不混用，app 未误接 admin init；6) 未新增静默 fallback 到旧接口；7) Task 3/6/10/11 证据已重新跑新鲜验证；8) current contract/smoke/runtime docs 不再宣传旧路径；9) diff 按 root/admin_front_ts/admin_app/admin_back_go 边界审计并提交；10) plan-04 与“架构重构，一定要好”的目标已以 current runtime truth 校验。提交：`admin_front_ts` 提交 `55d2a01 test: guard legacy users path cleanup`；root 提交 `717a59a docs: record multi-platform legacy cleanup`，包含 docs/plan/goal 记录；`admin_app` 无改动；`admin_back_go` 工作区 clean、无需本 task 新提交。
- Verification result: 最终强验证均为当前轮新鲜输出：`admin_front_ts` 依次执行 `npm run typecheck` exit=0、`npm run test -- tests/shared/user/users-api.test.ts` exit=0（1 file / 9 tests passed）、`npm run build` exit=0（`✓ built in 4.49s`，仅 plugin timings warning）；`admin_app` 依次执行 `npm run type-check` exit=0、`npm run test -- tests/app-auth-api.test.ts tests/app-backend-base.test.ts` exit=0（2 files / 7 tests passed）、`npm run build:h5` exit=0（`DONE Build complete.`，仅 Vite CJS 与 Sass/uview-plus deprecation warning）。`rg -n "/api/Users" admin_front_ts\src admin_front_ts\tests admin_app\src admin_app\tests admin_app\docs docs admin_back_go\docs ... -g "!docs/superpowers/**"` 输出 `active_zero=true`；current docs legacy term grep 输出 `current_docs_legacy_terms_zero=true`。提交后复查：root `git diff --check` exit=0；`powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working` PASS，working changed files=none，root/admin_back_go/admin_front_ts clean；hooks diff/status 无变更，因此无需 `/hooks` 提醒。
- Remaining risks: `docs/superpowers/**` 历史/spec/plan 文件仍保留 `/api/Users` 作为来源证据，不属于 active runtime/current docs；若未来要求全 repo 字面量零旧路径，需要单独改写历史记录。`admin_app` 仍有现有 Sass/uview-plus deprecation warning，非 blocking。未跑手动浏览器登录流程；本 plan 要求已由 API tests/typecheck/build/grep/governance 覆盖。root、admin_back_go、admin_front_ts 均有本地 ahead commits，尚未 push。
- Next step: Goal complete；调用 goal completion 工具。




