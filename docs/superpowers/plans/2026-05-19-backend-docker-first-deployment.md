# Backend Docker-first Deployment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert the backend deployment documentation and deploy assets to a Baota Docker-first shape while leaving the frontend static deployment path unchanged.

**Architecture:** The Go backend remains a Gin modular monolith packaged as one Docker image and run as two containers: `admin-api` and `admin-worker`. Baota Docker/Docker Compose owns backend container lifecycle; Baota Nginx owns SSL, domain routing, and WebSocket reverse proxy. MySQL/Redis may also run in Docker, but as a separate `admin-go-state` project with its own lifecycle, data volumes, backup policy, and migration runbook.

**Tech Stack:** Go 1.26 backend, Dockerfile multi-stage build, Docker Compose, Baota Docker, Baota Nginx/OpenResty, MySQL, Redis, PowerShell validation scripts.

---

## File Structure

- Rename: `docs/deployment/first-node-baota-docker.md` -> `docs/deployment/docker-first-backend.md`
  - Canonical root runbook for Baota Docker-first backend deployment.
- Modify: `docs/deployment/production.md`
  - Keep architecture boundaries, point production operators to `docker-first-backend.md` for the concrete runbook.
- Modify: `docs/deployment/local.md`
  - Make local backend development Docker-first; remove `.env + go run` as a supported startup path.
- Create: `docs/deployment/docker-first-state.md`
  - State-service boundary doc for MySQL/Redis Docker usage, lifecycle isolation, backup/connection rules, and the explicit SQL-migration deferral.
- Create: `admin_back_go/deploy/docker-first/docker-compose.yml`
  - Canonical backend Compose file for Baota Docker.
- Create: `admin_back_go/deploy/docker-first/compose.env.example`
  - Canonical Docker Compose project env template for paths, ports, and build context.
- Create: `admin_back_go/deploy/docker-first/admin-go.env.example`
  - Canonical backend runtime env template for Baota Docker Compose.
- Create: `admin_back_go/deploy/docker-first/README.md`
  - Backend-repo-local operator guide for the same Docker-first deployment.
- Modify: `admin_back_go/README.md`
  - Update references from `deploy/first-node` to `deploy/docker-first` and explain that repo `.env` is not the production deployment entry.
- Delete: `admin_back_go/deploy/first-node/`
  - Remove the old transition directory so there is only one backend Docker entry.
- Rule: do not keep real `.env`, `admin-go.env`, `runtime/`, or `exports/` inside `admin_back_go/deploy/docker-first/`.

---

### Task 1: Rename root deployment runbook to Docker-first

**Files:**
- Rename: `docs/deployment/first-node-baota-docker.md` -> `docs/deployment/docker-first-backend.md`
- Modify: `docs/deployment/docker-first-backend.md`

- [ ] **Step 1: Rename the runbook**

Run:

```powershell
Move-Item -Path 'docs\deployment\first-node-baota-docker.md' -Destination 'docs\deployment\docker-first-backend.md'
```

Expected: `docs/deployment/docker-first-backend.md` exists and `docs/deployment/first-node-baota-docker.md` no longer exists.

- [ ] **Step 2: Update the title and status block**

At the top of `docs/deployment/docker-first-backend.md`, replace the current first section with:

````markdown
# Backend Docker-first Deployment with Baota Docker

状态：后端生产部署 canonical runbook。前端仍按现有静态站点方式部署；本文只负责 `admin_back_go` 的 Docker-first 后端部署。

当前生产入口分工：

```text
zgm2003.cn       前端静态站点，由 GitHub CI / 宝塔静态目录发布
www.zgm2003.cn   后端 API / WebSocket 入口，宝塔 Nginx 反代到本机或内网 admin-api 容器
```

宝塔 Docker 项目分工：

```text
admin-go-state    MySQL + Redis，状态服务，独立生命周期
admin-go-backend  admin-api + admin-worker，应用服务，可随代码发布重建
```

这不是微服务改造。后端仍是 Gin modular monolith，只是把运行进程固定为 Docker 管理的两个容器：

```text
admin-api      HTTP + WebSocket，第一台后端默认暴露 127.0.0.1:8080
admin-worker   队列消费者 + 定时任务，不暴露公网端口
```
````

Expected: 文档第一屏明确 `Docker-first`、`Baota Docker`、`frontend unchanged`、`admin-go-state/admin-go-backend lifecycle split`。

- [ ] **Step 3: Replace deployment asset paths**

In `docs/deployment/docker-first-backend.md`, replace every occurrence:

```text
/www/project/admin_back_go/deploy/first-node/docker-compose.yml
/www/project/admin_back_go/deploy/first-node/admin-go.env.example
```

with:

```text
/www/project/admin_back_go/deploy/docker-first/docker-compose.yml
/www/project/admin_back_go/deploy/docker-first/admin-go.env.example
```

Expected: the runbook points only to `deploy/docker-first` for backend deploy assets.

- [ ] **Step 4: Add Baota Docker UI wording near the Compose startup section**

Under the section that starts Docker Compose, add this paragraph before the shell command:

```markdown
如果使用宝塔 Docker 面板创建 Compose 项目，后端应用项目命名为 `admin-go-backend`，Compose 工作目录使用 `/www/docker/admin-go-backend`，Compose 文件使用 `/www/docker/admin-go-backend/docker-compose.yml`。项目环境变量至少配置 `ADMIN_BACK_GO_DIR=/www/project/admin_back_go` 和 `ADMIN_GO_ENV_FILE=/www/docker/admin-go-backend/admin-go.env`。宝塔 Docker 负责启动、停止、重启、查看容器日志；宝塔 Nginx 仍负责 SSL 和反向代理。MySQL/Redis 即便也用 Docker，也放在独立的 `admin-go-state` 项目，不写进后端 Compose。
```

Expected: runbook supports both shell `docker compose` and Baota Docker UI without mentioning 1Panel.

- [ ] **Step 5: Add database migration deferral wording**

In `docs/deployment/docker-first-backend.md`, add a `## 数据库初始化和迁移` section before rollback:

```markdown
## 数据库初始化和迁移

Docker-first 只负责后端进程编排，不替代数据库初始化和迁移。首次部署新 MySQL、升级已有 MySQL、补菜单/权限/系统设置 seed 时，必须走单独的 SQL/migration runbook。

本切片不把迁移 SQL 写进 `admin-api` / `admin-worker` 启动流程。迁移是显式步骤，应用启动是显式步骤；后续单独设计 baseline schema、seed 数据、菜单/权限、system_settings 默认值和幂等迁移顺序。
```

Expected: backend Docker-first runbook does not imply that `docker compose up` creates or migrates the database.

- [ ] **Step 6: Commit root runbook rename**

Run:

```powershell
git add docs/deployment/docker-first-backend.md
git add -u docs/deployment
git commit -m "docs: rename backend deployment runbook to docker-first"
```

Expected: commit succeeds with only root deployment doc rename/update staged.

---

### Task 2: Create canonical backend Docker-first deploy assets

**Files:**
- Create: `admin_back_go/deploy/docker-first/docker-compose.yml`
- Create: `admin_back_go/deploy/docker-first/compose.env.example`
- Create: `admin_back_go/deploy/docker-first/admin-go.env.example`
- Create: `admin_back_go/deploy/docker-first/README.md`

- [ ] **Step 1: Create the Docker-first deploy directory**

Run:

```powershell
New-Item -ItemType Directory -Force -Path 'admin_back_go\deploy\docker-first'
Copy-Item 'admin_back_go\deploy\first-node\docker-compose.yml' 'admin_back_go\deploy\docker-first\docker-compose.yml'
Copy-Item 'admin_back_go\deploy\first-node\admin-go.env.example' 'admin_back_go\deploy\docker-first\admin-go.env.example'
Set-Content -Path 'admin_back_go\deploy\docker-first\compose.env.example' -Encoding UTF8 -Value @'
# Docker Compose project variables for Baota Docker / docker compose.
# Copy to /www/docker/admin-go-backend/.env on the server.
# This file is read by docker compose itself; backend runtime config lives in admin-go.env.

ADMIN_BACK_GO_DIR=/www/project/admin_back_go
ADMIN_GO_ENV_FILE=./admin-go.env
ADMIN_GO_RUNTIME_DIR=./runtime
ADMIN_GO_EXPORTS_DIR=./exports
ADMIN_API_HOST_BIND=127.0.0.1
ADMIN_API_HOST_PORT=8080
'@
```

Expected: the new directory contains `docker-compose.yml`, `compose.env.example`, and `admin-go.env.example`.

- [ ] **Step 2: Update the Compose project name**

In `admin_back_go/deploy/docker-first/docker-compose.yml`, set the first line to:

```yaml
name: admin-go-backend
```

Expected: Baota Docker displays the backend project as `admin-go-backend` instead of the old first-node name.

- [ ] **Step 3: Update backend Compose default host directories**

In `admin_back_go/deploy/docker-first/docker-compose.yml`, replace the volume defaults with:

```yaml
    volumes:
      - ${ADMIN_GO_RUNTIME_DIR:-/www/docker/admin-go-backend/runtime}:/app/runtime
      - ${ADMIN_GO_EXPORTS_DIR:-/www/docker/admin-go-backend/exports}:/app/exports
```

Apply the same two volume defaults under both `admin-api` and `admin-worker`.

Expected: backend runtime files live under `/www/docker/admin-go-backend/`, not under the old generic `/www/docker/admin-go/`.

- [ ] **Step 4: Keep the service contract unchanged**

Verify `admin_back_go/deploy/docker-first/docker-compose.yml` still contains these exact service boundaries:

```yaml
services:
  admin-api:
    command: ["/app/admin-api"]
    ports:
      - "${ADMIN_API_HOST_BIND:-127.0.0.1}:${ADMIN_API_HOST_PORT:-8080}:8080"
  admin-worker:
    command: ["/app/admin-worker"]
```

Expected: `admin-api` is the only exposed service; `admin-worker` remains private.

- [ ] **Step 5: Fix the payment cert comment in the env template**

In `admin_back_go/deploy/docker-first/admin-go.env.example`, replace the payment cert comment block with:

```env
# Payment business certs follow backend runtime nodes, not the MySQL/Redis state node.
# Mount host /www/docker/admin-go-backend/runtime to container /app/runtime on every backend node.
# Cert files are stored under /app/runtime/payment/certs/alipay/<config_code>/<sha256>.crt.
PAYMENT_CERT_BASE_DIR=/app
```

Expected: the comment matches the actual volume mount `/www/docker/admin-go-backend/runtime:/app/runtime`.

- [ ] **Step 6: Create backend deploy README**

Create `admin_back_go/deploy/docker-first/README.md` with this content:

````markdown
# Backend Docker-first Deploy Assets

This directory is the canonical Docker-first deployment entry for `admin_back_go`.

## Scope

- Runs one backend image as two containers: `admin-api` and `admin-worker`.
- Does not deploy the Vue frontend.
- Does not create MySQL or Redis by default.
- Designed for Baota Docker / Docker Compose.

## Server paths

```text
/www/project/admin_back_go        # backend source checkout
/www/docker/admin-go-backend              # compose working directory
/www/docker/admin-go-backend/.env          # docker compose project env
/www/docker/admin-go-backend/admin-go.env # production runtime env file
/www/docker/admin-go-backend/runtime      # mounted to /app/runtime
/www/docker/admin-go-backend/exports      # mounted to /app/exports
```

## Start

```bash
mkdir -p /www/docker/admin-go-backend/runtime /www/docker/admin-go-backend/exports
cp /www/project/admin_back_go/deploy/docker-first/docker-compose.yml /www/docker/admin-go-backend/docker-compose.yml
cp /www/project/admin_back_go/deploy/docker-first/compose.env.example /www/docker/admin-go-backend/.env
cp /www/project/admin_back_go/deploy/docker-first/admin-go.env.example /www/docker/admin-go-backend/admin-go.env
chmod 600 /www/docker/admin-go-backend/.env /www/docker/admin-go-backend/admin-go.env
chown -R 10001:10001 /www/docker/admin-go-backend/runtime /www/docker/admin-go-backend/exports
cd /www/docker/admin-go-backend
docker compose up -d --build
```

## Validate

```bash
docker compose ps
curl -fsS http://127.0.0.1:8080/health
curl -fsS http://127.0.0.1:8080/ready
```

`/health` only proves the process is alive. `/ready` proves MySQL, Redis, token Redis, queue Redis, and realtime configuration are usable.
````

Expected: backend repo has a self-contained Docker-first deploy entry.

- [ ] **Step 7: Validate the new Compose file**

Run:

```powershell
$env:ADMIN_BACK_GO_DIR=(Resolve-Path 'admin_back_go').Path
$env:ADMIN_GO_ENV_FILE=(Resolve-Path 'admin_back_go\deploy\docker-first\admin-go.env.example').Path
docker compose -f admin_back_go\deploy\docker-first\docker-compose.yml config --quiet
```

Expected: command exits `0` with no output.

- [ ] **Step 8: Commit backend deploy assets**

Run:

```powershell
git -C admin_back_go add deploy/docker-first/docker-compose.yml deploy/docker-first/compose.env.example deploy/docker-first/admin-go.env.example deploy/docker-first/README.md
git -C admin_back_go commit -m "docs: add docker-first backend deploy assets"
```

Expected: backend repo commit succeeds.

---

### Task 3: Create state-service Docker boundary doc

**Files:**
- Create: `docs/deployment/docker-first-state.md`

- [ ] **Step 1: Create the state-service deployment doc**

Create `docs/deployment/docker-first-state.md` with this content:

````markdown
# Docker-first State Services with Baota Docker

状态：MySQL/Redis 状态服务边界说明。本文只定义状态服务 Docker 生命周期、目录、备份和连接边界；具体 schema、seed 数据、菜单权限和 migration SQL 后续单独设计。

## Project split

```text
admin-go-state
  mysql
  redis

admin-go-backend
  admin-api
  admin-worker
```

MySQL/Redis 可以用宝塔 Docker 管，但必须作为 `admin-go-state` 独立项目。它可以和后端在同一台机器，也可以放在独立状态节点；关键是不要和 `admin-go-backend` 共享 Compose 生命周期。

## Why split lifecycle

```text
应用可重建，状态要保护。
```

后端发布会频繁执行 `up -d --build`、`restart`、回滚。MySQL/Redis 承载数据，不允许因为后端发布误触 `down -v`、删除数据卷、重启数据库或清空 Redis。

## Server directories

```text
/www/docker/admin-go-state/mysql   # MySQL data/config/backup mount root
/www/docker/admin-go-state/redis   # Redis data/config mount root
/www/docker/admin-go-backend       # backend compose working directory
```

## Production rules

```text
1. MySQL/Redis 镜像固定版本，不使用 latest。
2. MySQL 数据必须有备份/恢复步骤。
3. Redis 设置密码，不暴露公网端口。
4. MySQL/Redis 端口只绑定本机或内网，公网必须由安全组/防火墙拒绝。
5. 后端通过 Docker network、宿主本地端口或内网 IP 连接 state。
6. 后端 Compose 不包含 mysql/redis 服务。
```

## Migration boundary

Docker 启动 MySQL 不等于数据库初始化完成。首次部署和升级仍需要单独 SQL/migration runbook：

```text
创建 database / user / 权限
导入 baseline SQL
执行 migration SQL
校验菜单、权限、system_settings、基础配置表数据
```

本切片不设计具体 SQL。迁移是显式步骤，应用启动是显式步骤；不要让 `admin-api` 或 `admin-worker` 容器启动时自动改库。
````

Expected: state-service doc explicitly recommends Docker for MySQL/Redis while keeping it lifecycle-isolated from backend.

- [ ] **Step 2: Commit state-service doc**

Run:

```powershell
git add docs/deployment/docker-first-state.md
git commit -m "docs: define docker-first state service boundary"
```

Expected: root repo commit succeeds.

---

### Task 4: Update production/local docs to demote traditional env deployment

**Files:**
- Modify: `docs/deployment/production.md`
- Modify: `docs/deployment/local.md`

- [ ] **Step 1: Update production deployment status**

In `docs/deployment/production.md`, replace the status paragraph with:

```markdown
状态：生产部署边界说明。具体后端生产 runbook 以 `docs/deployment/docker-first-backend.md` 为准；MySQL/Redis Docker 边界以 `docs/deployment/docker-first-state.md` 为准；前端仍保持现有静态站点部署方式。
```

Expected: `production.md` no longer reads like the concrete backend deployment runbook.

- [ ] **Step 2: Replace the environment variable heading**

In `docs/deployment/production.md`, rename:

```markdown
## 环境变量
```

To:

```markdown
## 后端容器运行配置
```

Then add this sentence below the heading:

```markdown
生产配置由宝塔 Docker / Docker Compose 注入到容器运行时，不再推荐把仓库工作树里的 `.env` 作为生产入口。
```

Expected: the document keeps required config keys while making Docker runtime ownership explicit.

- [ ] **Step 3: Update rollback wording**

In `docs/deployment/production.md`, replace the rollback sequence with:

```text
1. 备份 MySQL
2. 备份 /www/docker/admin-go-backend/admin-go.env
3. 记录当前 admin_back_go commit
4. 重新构建并启动 admin-api/admin-worker 容器
5. 先验证 /ready，再切换或保留宝塔 Nginx 反代
6. worker 滚动替换，避免 in-flight task 被硬杀
```

Expected: rollback reflects Docker Compose instead of binary replacement.

- [ ] **Step 4: Mark local .env as compatibility path**

In `docs/deployment/local.md`, replace the `## 后端启动` introductory lines with:

```markdown
## 后端本地启动

后端本地开发统一 Docker-first，不再允许 `.env + go run` 启动 `admin-api` / `admin-worker`。
```

Expected: local docs do not imply `.env` is the production path.

- [ ] **Step 5: Commit root deployment doc updates**

Run:

```powershell
git add docs/deployment/production.md docs/deployment/local.md
git commit -m "docs: make backend production deployment docker-first"
```

Expected: root repo commit succeeds.

---

### Task 5: Update backend README references and remove old first-node path

**Files:**
- Modify: `admin_back_go/README.md`
- Modify: `admin_back_go/.gitignore`
- Delete: `admin_back_go/deploy/first-node/`
- Cleanup: remove any real `.env`, `admin-go.env`, `runtime/`, or `exports/` from `admin_back_go/deploy/docker-first/`

- [ ] **Step 1: Replace backend README deploy path references**

In `admin_back_go/README.md`, replace occurrences of:

```text
deploy/first-node
```

with:

```text
deploy/docker-first
```

Expected: backend README points to the canonical deploy assets.

- [ ] **Step 2: Add Docker-first production note near the deployment section**

Add this paragraph near the backend deployment section in `admin_back_go/README.md`:

```markdown
Backend deployment and local backend development are Docker-first. Use `deploy/docker-first/docker-compose.yml` with Baota Docker or `docker compose`; do not use repository-root `.env` / `.env.example`, and do not start `admin-api` or `admin-worker` with `go run`.
```

Expected: README distinguishes local `.env` from production Docker runtime config.

- [ ] **Step 3: Remove the old first-node directory**

Run:

```powershell
git -C admin_back_go rm -r deploy/first-node
```

Expected: `admin_back_go/deploy/` contains only `docker-first` for backend Docker deployment assets.

- [ ] **Step 4: Remove accidental real env/runtime files from deploy assets**

Delete these if they exist under `deploy/docker-first/`:

```text
.env
admin-go.env
runtime/
exports/
```

Expected: the deploy directory contains only committed deploy assets and templates.

- [ ] **Step 5: Commit backend cleanup updates**

Run:

```powershell
git -C admin_back_go add README.md .gitignore deploy/docker-first/README.md
git -C admin_back_go add -u deploy/first-node
git -C admin_back_go commit -m "docs: keep only docker-first deploy entry"
```

Expected: backend repo commit succeeds; deploy directory has no real `.env` or `admin-go.env`.

---

### Task 6: Update root references and governance checks

**Files:**
- Modify references found by search under `docs/`, `README.md`, and `AGENTS.md` only when they point to the old runbook path.

- [ ] **Step 1: Search for old deployment references**

Run:

```powershell
rg -n "first-node-baota-docker|deploy/first-node|first-node" README.md AGENTS.md docs admin_back_go/README.md admin_back_go/deploy -g '!**/.git/**'
```

Expected: every remaining hit is either intentionally historical or updated to `docker-first`.

- [ ] **Step 2: Update old canonical references**

For references that describe the active backend deployment path, replace with:

```text
docs/deployment/docker-first-backend.md
admin_back_go/deploy/docker-first/
```

Expected: active docs consistently call the backend path Docker-first.

- [ ] **Step 3: Run root docs validation**

Run:

```powershell
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1
```

Expected: `git diff --check` exits `0`; governance checker exits `0` or prints only accepted docs-governance messages.

- [ ] **Step 4: Run backend Compose validation again**

Run:

```powershell
$env:ADMIN_BACK_GO_DIR=(Resolve-Path 'admin_back_go').Path
$env:ADMIN_GO_ENV_FILE=(Resolve-Path 'admin_back_go\deploy\docker-first\admin-go.env.example').Path
docker compose -f admin_back_go\deploy\docker-first\docker-compose.yml config --quiet
```

Expected: command exits `0` with no output.

- [ ] **Step 5: Verify backend Compose does not own state services**

Run:

```powershell
rg -n "^  (mysql|redis):" admin_back_go\deploy\docker-first\docker-compose.yml
if ($LASTEXITCODE -eq 1) { "backend_compose_state_services_absent" }
```

Expected: output includes `backend_compose_state_services_absent`; there are no `mysql` or `redis` services in the backend Compose file.

- [ ] **Step 6: Commit final reference cleanup**

Run:

```powershell
git add README.md AGENTS.md docs
git commit -m "docs: align references with backend docker-first deployment"
```

Expected: root repo commit succeeds if there were root reference changes. If no root reference changes remain, skip this commit and record that search found no active stale references.

---

## Self-review Checklist

- Spec coverage: backend Docker-first, Baota Docker, frontend unchanged, no 1Panel, state/backend lifecycle split, SQL migration deferral, doc rename, Compose assets, env policy, validation all map to tasks above.
- Placeholder scan: this plan contains no unfinished-marker wording and no unspecified implementation step.
- Type/path consistency: canonical backend runbook path is `docs/deployment/docker-first-backend.md`; canonical state runbook path is `docs/deployment/docker-first-state.md`; canonical backend deploy dir is `admin_back_go/deploy/docker-first/`; service names remain `admin-api` and `admin-worker`.
- Verification path: root docs checks plus backend `docker compose config --quiet` are included before completion claims.
