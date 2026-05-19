# Admin Go Workspace Docs

这是 `E:\admin_go` 的 **Codex 冷启动入口**，也是 Go/Vue admin 新项目的总控文档入口。

目标不是写漂亮文档，而是让一个全新的 Codex 进仓库后，不依赖聊天记录，也能判断：

```text
现在项目是什么
必须先读哪些文件
哪些已经实现
哪些只是 planned
禁止做什么
该跑哪些验证
下一步应该做什么
```

## 冷启动阅读顺序

新 Codex 必须按这个顺序读：

```text
1. AGENTS.md
2. docs/README.md
3. docs/status/current-status.md
4. docs/architecture/00-open-source-first.md
5. docs/architecture/01-step-by-step-roadmap.md
6. docs/architecture/02-agent-framework.md
7. docs/architecture/03-technology-decision.md
8. docs/architecture/04-go-backend-framework.md
9. docs/architecture/05-development-quality-rules.md
10. docs/architecture/07-documentation-governance.md
11. docs/architecture/08-codex-hooks.md (本治理计划 Task 2 新增)
12. docs/contracts/admin-api-v1.md
13. docs/contracts/admin-realtime-v1.md
14. docs/testing/test-strategy.md
15. docs/testing/pre-push-gates.md
16. docs/testing/smoke-matrix.md
17. docs/deployment/local.md
18. docs/deployment/production.md
19. docs/deployment/distributed-readiness.md
20. docs/deployment/frontend-github-actions-scp.md
```

按任务再读：

```text
agents/*.md                              # agent 分工
docs/open-source/*.md                    # 开源调研和取舍
docs/deployment/*.md                     # 本地、生产、分布式 readiness、前端发布运行边界
docs/superpowers/plans/*.md              # 只读与当前任务直接相关的 spec/plan；不要扫全部旧计划
docs/superpowers/archive/**/*.md         # 已归档历史计划，只能在用户明确要求考古时读取，不覆盖 current-status
admin_back_go/docs/architecture.md       # Go 后端运行时架构
admin_back_go/scripts/*.ps1              # smoke/contract 脚本
```

## 仓库边界

`E:\admin_go` 是 meta repo / 总控仓库，只跟踪：

```text
AGENTS.md
agents/
docs/
  superpowers/          # spec/plan 总入口；后端子仓不再保存独立 superpowers 计划
.codex/                 # Codex lifecycle hooks 配置落地后由 root repo 跟踪
```

不跟踪：

```text
admin_back_go/    # Go 后端，独立 Git 仓库
admin_front_ts/   # Vue 前端，独立 Git 仓库
.tmp*/            # 本地 smoke / runtime scratch
```

Codex hooks 落地后位于 root `.codex/`，只服务 Codex 会话生命周期。hook 配置变更后，在 Codex CLI 内用 `/hooks review/trust`。

## 当前真实状态

看这里，不要猜：

```text
docs/status/current-status.md
```

规则：

```text
implemented = 已经有代码和验证证据
partially implemented = 有骨架或部分链路，文档必须写清缺口
planned = 只计划，不许说成已完成
历史 plan/spec 里的早期阶段限制只表示当时任务背景；如果和 current-status 冲突，以 current-status + runtime docs 为准。
```

文档与运行时冲突时：

```text
live runtime behavior > smoke output > served assets/API > process config > docs > comments
```

## 运行时边界

当前 active runtime 是：

```text
admin_back_go    # Go backend runtime
admin_front_ts   # Vue frontend runtime
```

历史项目默认不是冷启动事实源。只有用户明确要求考古，或当前 Go/Vue 运行时证据缺失且必须追溯来源时，才允许作为辅助输入：

```text
业务事实来源
字段/权限/流程考古
rollback provenance
```

禁止把历史系统当作当前运行依赖，禁止把旧 all POST action path 带进新的 Go REST 契约。

所有 Superpowers spec/plan 统一归总控 `docs/superpowers`；部署、契约、状态、测试和跨仓治理文档统一归总控 `docs`。

子仓文档只保留贴近代码的运行时说明或旧链接 stub：

```text
admin_back_go/docs/architecture.md                     # Go 后端运行时架构，合法
admin_front_ts/docs/deployment/github-actions-scp.md   # 旧链接 stub，真实部署文档在 root docs/deployment
```

不准在 `admin_front_ts/docs/deployment` 继续维护第二份长期部署 runbook。

## 当前工程方向

```text
后端：Go + Gin modular monolith
前端：Vue 3 + TypeScript
API：/api/admin/v1/...，未来 /api/app/v1/...
Realtime：WebSocket-only，不新增 SSE
异步：admin-worker + Asynq + gocron/v2；队列监控优先用官方 asynqmon 只读 UI
认证/RBAC：core 已成型；后续是 Go/Vue runtime 的模块演进、产品补齐和 hardening
```

## 不可破坏规则

```text
不搞 all POST 新接口
不加 silent fallback 字段
不在 handler 直连 DB/Redis
不让 service 依赖 gin.Context
不在前端 touched code 引入 any / as any / Record<string, any>
不把历史系统架构搬进 Go
不把 planned 写成 implemented
不跳过验证就说完成
```

## 常用验证命令

后端：

```powershell
cd E:\admin_go\admin_back_go
$env:GOMAXPROCS='2'
go test -p=1 ./...
go vet -p=1 ./...
powershell -ExecutionPolicy Bypass -File .\scripts\check-contract.ps1
git diff --check
```

后端 smoke：

```powershell
cd E:\admin_go\admin_back_go
powershell -ExecutionPolicy Bypass -File .\scripts\basic-admin-smoke.ps1 -Account <account> -Password <password>
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account <account> -Password <password>
```

前端：

```powershell
cd E:\admin_go\admin_front_ts
$env:NODE_OPTIONS='--max-old-space-size=2048'
npx vue-tsc -b --pretty false
npx eslint <touched-files>
npx vitest run <target-test>
git diff --check
```

说明：

```text
Windows 上 go test ./... 默认并发可能吃内存；优先用 GOMAXPROCS=2 + -p=1。
race detector 需要 gcc；如果报 cgo: C compiler "gcc" not found，不准声称 race 通过。
前端 build 较重，除非发布门禁或触碰大范围构建配置，否则优先 targeted typecheck/lint/test。
```

## 结束任务时必须更新

每次完成一个阶段，至少检查：

```text
docs/status/current-status.md
docs/contracts/*.md
docs/architecture/*.md
docs/testing/*.md
admin_back_go/docs/architecture.md
```

最终汇报必须包含：

```text
Outcome
Changed files
Verification
Known risks
Next step
```
