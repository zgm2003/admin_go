# goal-3 Plan

## 原始需求

见 `input.md`：执行 `docs/superpowers/plans/2026-05-27-multi-platform-04-frontend-legacy-cleanup.md`，并且本次改动涉及架构重构，质量必须好。

## 已注册上下文

- Thread goal: active；objective 为用户原始输入。
- Superpowers: 已读取 `using-superpowers` 与 `writing-plans`；引用计划本身要求执行时使用 `superpowers:subagent-driven-development` 或 `superpowers:executing-plans`。
- Project agent role: 本 goal 固定只采用 `agents/frontend-adapter.md` 角色，不作为全能 agent。
- 冷启动必读已完成：`AGENTS.md`、`docs/status/current-status.md`、`docs/architecture/00-open-source-first.md`、`01-step-by-step-roadmap.md`、`02-agent-framework.md`、`03-technology-decision.md`、`04-go-backend-framework.md`、`05-development-quality-rules.md`、`07-documentation-governance.md`、`08-codex-hooks.md`、`docs/testing/pre-push-gates.md`、`agents/frontend-adapter.md`。

## 需求拆解

目标是移除前端与前端可见文档里的旧 `/api/Users/*` 路径引用，确保后续后端删除旧路由时不会导致前端调用 404。

必须覆盖：

1. `admin_front_ts` 当前 Vue admin 前端。
2. `admin_app` 当前运行时事实。
3. `docs/contracts/admin-api-v1.md` 与 `docs/testing/smoke-matrix.md` 中如存在的旧路径。
4. `admin_back_go/docs` 中如存在面向前端契约或 smoke 的旧路径引用。
5. 最终全局验证 `admin_front_ts`、`admin_app`、root docs、backend docs 不再出现 `/api/Users`。

旧路径到新路径的目标映射：

| Legacy path | Admin target | App target |
| --- | --- | --- |
| `/api/Users/getLoginConfig` | `GET /api/admin/v1/auth/login-config` | `GET /api/app/v1/auth/login-config` |
| `/api/Users/sendCode` | `POST /api/admin/v1/auth/send-code` | `POST /api/app/v1/auth/send-code` |
| `/api/Users/login` | `POST /api/admin/v1/auth/login` | `POST /api/app/v1/auth/login` |
| `/api/Users/refresh` | `POST /api/admin/v1/auth/refresh` | 暂不猜测；仅在实际 app 代码存在 refresh 调用并且 contract/runtime 证明时处理 |
| `/api/Users/logout` | `POST /api/admin/v1/auth/logout` | `POST /api/app/v1/auth/logout` |
| `/api/Users/init` | `GET /api/admin/v1/users/init` | 不适用，app 不使用 admin RBAC init |

## 运行时事实与计划偏差处理

引用计划文件写了 `admin_app/lib`、Dart、Flutter、`flutter analyze`，但当前工作树证据显示：

- `admin_app` 是 UniApp/Vue3/TypeScript 项目。
- `admin_app` 实际目录为 `src`、`tests`、`package.json`，没有 Flutter `lib` 作为主要运行时入口。
- `admin_app/package.json` 提供 `npm run type-check`、`npm run test`、`npm run build:h5`。

因此执行时必须以当前运行时事实为准：

- 仍完成“移除 app 前端旧 `/api/Users/*` 调用”的需求。
- 不新建、不迁移、不猜测 Flutter 结构。
- 扫描 `admin_app/src`、`admin_app/tests`、`admin_app/docs`；若 `admin_app/lib` 不存在，记录为计划假设过期。
- 验证使用 UniApp/Vue 命令，而不是 Flutter 命令。

## Linus 三问

1. 这是个真问题吗？是。后端计划删除旧 `/api/Users/*` 路由，前端残留旧调用会导致登录、验证码、logout、init 等链路 404。
2. 有更简单做法吗？有：只做 URL/method 和契约文档清理，不重做 UI、不重写 store、不新增 backend endpoint。
3. 会破坏已有前端、接口、登录和权限吗？风险存在，尤其是 `getLoginConfig` 与 `init` 的 GET/POST 差异、baseURL 是否已经带 `/api/admin/v1`、app 与 admin 平台前缀差异。必须通过 grep、类型检查、单测、构建和零引用验证控制风险。

## 边界与禁止项

本 goal 只做 plan-04 前端 legacy cleanup：

- 不改后端 Go 路由、handler、service、middleware。
- 不改权限模型，不迁移 RBAC，不改变登录 payload 字段，除非实际新契约要求且测试证明。
- 不重做 UI，不调整视觉，不做页面重构。
- 不把旧接口兼容逻辑扩散到业务页面。
- 不新增 `/api/Users/*` deprecated 文档；本项目新口径不以 legacy/compat 作为主叙事。
- 不修改生产配置、密钥、认证策略、支付等高风险内容。

## 执行策略

每个新会话先完整读取：

```text
goal-3/input.md
goal-3/plan.md
goal-3/tasks.md
```

然后列出小 todo 并用内置计划工具注册。每轮只执行 `tasks.md` 中第一个未完成 task。任务结束前必须基于实际证据自查，不得口头声称有信心。

首选执行方式：按 `executing-plans` 思路逐 task 推进；如果后续出现可安全并行且互不共享状态的任务，再考虑 subagent，但 goal 规则仍要求每轮只完成一个 task。

## 验证方式

按任务逐步验证，最终至少需要：

```powershell
cd E:\admin_go
rg -n "/api/Users" admin_front_ts\src admin_front_ts\tests admin_app\src admin_app\tests admin_app\docs docs admin_back_go\docs -g "!*node_modules*" -g "!*dist*" -g "!*build*" -g "!*.dart_tool*"
```

预期：无输出。

`admin_front_ts` 触碰后验证：

```powershell
cd E:\admin_go\admin_front_ts
npm run typecheck
npm run test -- <touched tests or relevant api/store tests>
npm run build
```

`admin_app` 触碰后验证：

```powershell
cd E:\admin_go\admin_app
npm run type-check
npm run test -- <touched tests or relevant auth/api tests>
npm run build:h5
```

治理验证：

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

如本地依赖或工具链异常，必须记录具体命令、错误、是否为本次改动引入，以及替代验证证据。

## 回滚方案

- 每个 task 做最小 diff；如某一步验证失败且无法在当前 task 内修复，优先回退该 task 的相关文件，而不是跨模块扩大修复。
- 业务代码修改可用 `git diff` 定位后手动反向补丁；禁止 destructive hard reset 或 broad clean。
- 文档修改可按 diff 反向恢复。
- 如果发现引用计划与运行时事实冲突，以 live worktree/current-status/contract 为准，先记录冲突，再执行不依赖冲突假设的清理。

## 默认假设

- 当前 workspace `E:\admin_go` 是 root governance repo。
- `admin_front_ts` 与 `admin_app` 是独立运行时前端 repo。
- 新 `/api/admin/v1/*` 与 `/api/app/v1/*` endpoint 已存在，本 goal 不负责新增。
- 当前 app 是 UniApp/Vue，不是 Flutter；若后续扫描发现 Flutter 代码也存在，再只按实际残留引用处理。
- 如果 grep 没有发现某一端引用，则该端不做代码改动，只保留零引用验证。
