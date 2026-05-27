# Goal Plan: Plan 02 Auth Transport Pattern + `/api/Users` Backend Cleanup

## 原始目标

见 `input.md`。目标指向 `docs/superpowers/plans/2026-05-27-multi-platform-02-auth-transport.md`，并强调“本次改动涉及到了架构重构，一定要好”。

## 已读取上下文

- `AGENTS.md`
- `docs/status/current-status.md`
- `docs/architecture/00-open-source-first.md`
- `docs/architecture/01-step-by-step-roadmap.md`
- `docs/architecture/02-agent-framework.md`
- `docs/architecture/03-technology-decision.md`
- `docs/architecture/04-go-backend-framework.md`
- `docs/architecture/05-development-quality-rules.md`
- `docs/architecture/07-documentation-governance.md`
- `docs/architecture/08-codex-hooks.md`
- `docs/testing/pre-push-gates.md`
- `agents/backend-worker.md`
- `docs/superpowers/plans/2026-05-27-multi-platform-02-auth-transport.md`

## 本 goal 的项目角色

只采用 `agents/backend-worker.md` 作为本 goal 主角色。

原因：plan-02 是 Go backend auth transport 边界重构，主要修改 `admin_back_go` 的 auth/user/middleware/server/architecture tests。除 plan 要求的根治理检查外，不以 frontend-adapter、architect、reviewer 等角色并行越权执行。

## Superpowers / 执行方式

- 使用 `superpowers:using-superpowers` 进行技能约束检查。
- 使用 `superpowers:executing-plans` 执行既有 plan。
- 使用 `superpowers:test-driven-development`：先落 RED architecture guard，再迁移生产代码。
- 使用 `superpowers:verification-before-completion`：每个 task 收尾必须有当前轮实际验证证据。
- 未使用 subagent-driven-development：本仓库 goal 模式要求每轮只执行一个 task，且项目要求只选一个 agent 角色；本 goal 优先顺序执行，不并行发散。

## 需求拆解

本 goal 必须完整满足 plan-02，而不是只做一个兼容补丁：

1. 建立 `internal/module/auth/transport/{admin,app}` 作为多平台 module 过渡参考模式。
2. admin/app HTTP surface 从 auth module root 移入 transport 子包。
3. 删除 Go runtime 中 `/api/Users/*` legacy POST routes，包括 auth routes、user legacy init route、auth-token whitelist。
4. 新增静态 architecture guard，保护 auth transport shape、禁止 `/api/Users`、禁止 root/platform-prefixed auth HTTP files 回潮。
5. `internal/server/router.go` 必须通过新的 transport `Register` 入口装配 admin/app auth。
6. handler tests 必须搬迁并改包名/import，不迁移旧 `/api/Users/*` route 测试。
7. focused backend tests、full backend tests、frontend legacy grep、root governance gates 必须有当前运行证据。
8. 不在本 goal 内做 plan-01 docs、plan-03 module consolidation、plan-04 frontend cleanup、shared/dict、AI 聚合、infra rename 等外延工作。

## 默认假设

- 当前工作区 `E:\admin_go` 是 root governance repo；`admin_back_go` 是 backend runtime repo；`admin_front_ts` 是 frontend runtime repo。
- 当前用户授权本 goal 对 challenge/workspace 内代码和测试进行必要修改，但不授权重启本机、抢 Windows 焦点、改生产密钥或删除重要数据。
- 如 frontend grep 发现 `/api/Users` 调用，按原 plan 停止 backend 删除并记录 blocker；不得盲删 backend route 破坏前端。
- 如 baseline backend tests 已红，先把 baseline 作为 blocker/前置修复记录，不在坏基线上做大重构。
- 本 goal 不自动 push，除非用户后续明确要求；但每个有代码改动的 task 收尾要按 goal 规则提交本地 commit。

## 风险点

- 大规模移动 Go package 容易引入 import cycle、测试 helper 包名错、未导出接口错。
- 删除 `/api/Users/*` 可能破坏仍未迁移的 frontend/admin_app 调用；必须先 grep。
- `auth` root 下的 DTO/service 合约不能误搬到 transport，否则会把平台表达和业务服务合约混在一起。
- `platform` 在业务语义中代表入口维度，`internal/platform` 仍是当前外部资源适配目录；不得在本 plan 顺手 rename infra。
- 当前 root repo 已有未跟踪 sibling plan 文件和一个 deleted old plan；不得把无关文件混入 backend commit。
- hooks/governance 检测会提示要求 `git diff --check` 和 `scripts/check-agent-governance.ps1 -Mode working`，最终 gate 必跑。

## 执行方案

按 `tasks.md` 每轮只做第一个未完成 task：

1. Pre-flight：frontend `/api/Users` grep + backend baseline build/test。
2. TDD RED：新增 architecture guard，验证失败原因符合预期。
3. Move admin auth transport：迁移 admin route/handler/request/test，删除 root admin HTTP files，focused test。
4. 大型检查-debug循环 A。
5. Move app auth transport：迁移 app route/handler/request/presenter/test，删除 platform-prefixed files，focused test。
6. Rewire router + remove `/api/Users` runtime：server/user/middleware/tests，focused route/middleware/user tests。
7. 大型检查-debug循环 B。
8. Boundary guard GREEN：architecture guard、forbidden pattern grep、required files、focused package tests。
9. Final verification：focused tests、full backend tests、frontend grep、root governance gates、final handoff statement。
10. 最终最大 review + 修缮 + goal complete。

## 验证方式

最小验证由每个 task 自己定义；最终 goal 完成前至少要有：

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture ./internal/module/auth ./internal/module/auth/transport/admin ./internal/module/auth/transport/app ./internal/module/user ./internal/server ./internal/middleware -count=1
go test ./... -count=1

cd E:\admin_go
rg -n "/api/Users" admin_front_ts\src admin_front_ts\tests admin_app\src admin_app\tests -g "!*node_modules*" -g "!*dist*"
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

其中 pre-flight grep 采用 plan 原路径：

```powershell
rg -n "/api/Users" admin_front_ts\src admin_front_ts\tests admin_app\lib admin_app\test -g "!*node_modules*" -g "!*dist*" -g "!*build*"
```

如果路径不存在，要记录实际输出并补充用现有 `admin_app\src` / `admin_app\tests` 重新 grep；不能把路径错误当成无调用证明。

## 回滚方案

- 每个 task 控制为小 commit；若后续 task 出错，优先按 task commit 回滚，而不是手工大面积改回。
- TDD guard 若过严导致误杀，先回到 guard 需求，调整测试覆盖到 plan 明确范围，不删除已证明有效的 runtime 保护。
- 迁移失败时，可临时保留旧 root files 作为中间状态，但 task 不能标完；最终必须满足 guard 的 removed-file 约束。
- 删除 `/api/Users/*` 前若 frontend/preflight 存在调用，停止本 plan 的删除任务，记录阻塞证据，等待 plan-04 或协调改动。

## 完成标准

- `tasks.md` 所有 task 均标记完成并写入动作、验证、剩余风险、下一步。
- 计划文件中的 explicit checks 均有当前状态证据。
- `go test ./... -count=1` 至少执行过；若存在非触碰区域失败，必须记录包名和原因，不能声称 full backend green。
- root governance gates 已跑且结果记录。
- 最终回复包含 plan-02 要求的 handoff scope statement。
- 符合 goal tool 完成审计后，调用 `update_goal(status="complete")`。
