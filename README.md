# admin_go

`admin_go` 是一个 Go + Vue 的后台管理系统工作区。

它不是单一应用仓库，而是一个总控工作区：

```text
E:\admin_go
├─ admin_back_go/      # Go 后端运行时，独立 Git 仓库
├─ admin_front_ts/     # Vue 3 管理后台前端，独立 Git 仓库
├─ docs/               # 契约、架构、部署、测试、当前状态
├─ agents/             # AI agent 分工说明
├─ .codex/             # Codex lifecycle hooks
├─ scripts/            # root 治理检查脚本
└─ AGENTS.md           # agent 冷启动规则
```

如果你是第一次打开这个项目，先看这份 README；如果你要判断“某个模块到底做完没”，不要靠印象，直接看：

```text
docs/status/current-status.md
```

## 这个项目是什么

目标是把后台系统逐步收敛到一套可维护、可验证的 Go/Vue 运行时：

```text
后端：Go + Gin modular monolith
前端：Vue 3 + TypeScript + Vite + Element Plus
数据库：MySQL
缓存 / 会话 / 队列：Redis + Asynq
定时任务：gocron/v2 + DB cron_task
实时能力：WebSocket
对象存储：腾讯云 COS
支付：当前只做支付宝充值收银台切片
AI：provider / agent / conversation / tool / knowledge / run 等后台管理能力
```

项目原则很简单：

```text
当前运行时事实 > smoke/test 证据 > 契约文档 > 架构文档 > 历史计划 > 代码注释
```

不要把 planned 写成 implemented。

## 当前运行时边界

真正会跑的东西在两个子仓里：

| 路径 | 说明 |
| --- | --- |
| `admin_back_go/` | Go API、Worker、队列、定时任务、WebSocket、业务模块 |
| `admin_front_ts/` | Vue 管理后台、路由、页面、API client、i18n |

root 仓库主要负责：

```text
1. 架构和契约文档
2. 当前状态记录
3. smoke / pre-push / governance 规则
4. Codex hooks 和 agent 工作流
5. 跨后端、前端的计划与复盘
```

## 本地启动

### 1. 准备依赖

本地开发通常需要：

```text
Go
Node.js，满足 admin_front_ts/package.json 的 engines
MySQL
Redis
PowerShell
```

后端详细配置看：

```text
docs/deployment/local.md
admin_back_go/README.md
```

### 2. 启动后端 API / Worker

后端本地开发也统一 Docker-first，不再使用 `go run` 启动 API 或 Worker。

`deploy/docker-first/docker-compose.yml` 已经固定开发者默认值，不再需要 Compose `.env`：源码目录 `../..`、运行目录 `./runtime`、导出目录 `./exports`、API 端口 `127.0.0.1:8080`。

首次启动前只确认运行时配置文件：

```text
E:\admin_go\admin_back_go\deploy\docker-first\admin-go.env
```

启动：

```powershell
cd E:\admin_go\admin_back_go\deploy\docker-first
docker compose up -d --build
docker compose ps
```

默认 API 地址仍是：

```text
http://127.0.0.1:8080
```

健康检查：

```text
GET /health
GET /ready
```

职责分工不变：

```text
admin-api    负责 HTTP API / WebSocket
admin-worker 负责队列消费 / 定时任务
```

不要把 cron 和 queue 消费塞进 API 进程里。

### 4. 启动前端

```powershell
cd E:\admin_go\admin_front_ts
npm install
npm run dev
```

前端 API base URL 应指向 Go API：

```text
VITE_GO_API_BASE_URL=http://127.0.0.1:8080
```

## 常用验证

### root 文档 / 治理轻量检查

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

### Codex hooks 检查

```powershell
cd E:\admin_go
powershell -ExecutionPolicy Bypass -File .\scripts\test-codex-hooks.ps1
Get-Content .\.codex\hooks.json -Raw | ConvertFrom-Json | Out-Null
```

修改 `.codex/` 后，在 Codex CLI 里运行：

```text
/hooks
```

然后 review/trust repo-local hooks。

### 后端检查

```powershell
cd E:\admin_go\admin_back_go
$env:GOMAXPROCS='2'
go test -p=1 ./...
go vet -p=1 ./...
powershell -ExecutionPolicy Bypass -File .\scripts\check-contract.ps1
git diff --check
```

### 前端检查

```powershell
cd E:\admin_go\admin_front_ts
$env:NODE_OPTIONS='--max-old-space-size=2048'
npm run typecheck
npm run build
npm run test
git diff --check
```

### Smoke

Smoke 需要本地后端、MySQL、Redis 等依赖真实可用。

```powershell
cd E:\admin_go\admin_back_go
powershell -ExecutionPolicy Bypass -File .\scripts\basic-admin-smoke.ps1 -Account <account> -Password <password>
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account <account> -Password <password>
```

pre-push / governance 通过不等于 smoke 通过。需要证明运行时链路时，必须单独跑 smoke。

## 文档入口

人类常用入口：

| 你想知道 | 看哪里 |
| --- | --- |
| 当前哪些模块已实现 | `docs/status/current-status.md` |
| API 契约 | `docs/contracts/admin-api-v1.md` |
| WebSocket 契约 | `docs/contracts/admin-realtime-v1.md` |
| 本地启动 | `docs/deployment/local.md` |
| 生产部署 | `docs/deployment/production.md` |
| 测试策略 | `docs/testing/test-strategy.md` |
| smoke 覆盖矩阵 | `docs/testing/smoke-matrix.md` |
| pre-push 规则 | `docs/testing/pre-push-gates.md` |
| Go 后端架构 | `admin_back_go/docs/architecture.md` |
| 前端工程细节 | `admin_front_ts/README.md`，如果存在；否则看 `package.json` 和 `src/` |

Agent / Codex 入口：

| 你想知道 | 看哪里 |
| --- | --- |
| agent 总规则 | `AGENTS.md` |
| agent 分工 | `agents/README.md` 和 `agents/*.md` |
| Codex hooks | `docs/architecture/08-codex-hooks.md` |
| Superpowers spec / plan | `docs/superpowers/` |

## 开发规则

核心禁忌：

```text
不搞 all POST 新接口
不在 handler 直连 DB/Redis
不让 service 依赖 gin.Context
不在前端 touched code 引入 any / as any / Record<string, any>
不把历史系统架构搬进 Go
不把 planned 写成 implemented
不跳过验证就说完成
```

新模块默认要求：

```text
后端：route -> handler -> service -> repository -> model；没必要的层不要硬加
前端：标准 CRUD 用 Search + AppTable + AppDialog + useCrudTable
i18n：前后端新增可见文案默认都要做
测试：新行为 / bugfix 默认先写能失败的测试，再写实现
文档：契约、状态、部署、验证命令随代码同步
```

## Git 和提交

root、后端、前端是不同 Git 边界。提交前先确认自己在哪个仓库：

```powershell
git rev-parse --show-toplevel
git status --short
```

如果改的是：

```text
root docs / agents / .codex / scripts  -> 在 E:\admin_go 提交
Go 后端代码                         -> 在 E:\admin_go\admin_back_go 提交
Vue 前端代码                        -> 在 E:\admin_go\admin_front_ts 提交
```

不要把子仓运行时改动误报成 root 仓库已提交。

## 常见问题

### Q: 我应该先读哪个文件？

人类先读：

```text
README.md
docs/status/current-status.md
docs/deployment/local.md
```

Codex / agent 先读：

```text
AGENTS.md
docs/README.md
docs/status/current-status.md
```

### Q: 为什么 README 不列完整模块细节？

因为模块状态变化很快，完整状态必须以 `docs/status/current-status.md` 为准。README 只负责告诉你项目是什么、怎么启动、怎么验证、从哪里继续查。

### Q: 能不能只跑 pre-push 就说功能完成？

不能。pre-push 只做轻量治理检查。功能完成必须有任务对应的测试、contract、smoke 或运行时证据。

### Q: 后端和前端是不是 root 仓库的一部分？

不是。它们是 `E:\admin_go` 工作区下的独立 Git 仓库。root 仓库是总控层。
