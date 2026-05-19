# Backend Docker-first Deployment Design

状态：spec draft for backend deployment refactor。本文只定义后端部署口径；前端保持现有静态部署方式，不纳入本切片改造。

## 背景和结论

用户明确选择：不用 1Panel，后端部署统一走宝塔 Docker。前端继续 `admin_front_ts` 构建静态资源并由宝塔/Nginx 提供服务。后端从“传统 `.env` + 裸机进程/混合 runbook”收口为 Docker-first：用同一个 Go 后端镜像运行 `admin-api` 和 `admin-worker` 两个容器，由宝塔 Docker/Compose 管理生命周期，由宝塔 Nginx 反代到 `admin-api`。

MySQL/Redis 可以也推荐用 Docker，但必须作为独立的状态服务项目管理。也就是说，宝塔 Docker 里拆成 `admin-go-backend` 和 `admin-go-state` 两个生命周期：后端应用可以频繁重建，数据库和 Redis 不能跟随后端发布一起 `down`。

这不是微服务改造。后端仍是 Gin modular monolith，只是部署形态固定为容器化多进程。

## 目标

1. 把后端生产部署事实源改成 Docker-first / 宝塔 Docker-first。
2. 把旧文档名 `first-node-baota-docker.md` 收口为带 `docker-first` 的 canonical runbook。
3. 保留前端现有静态部署方式，不强推前端 Docker。
4. 保留后端环境变量读取能力，但不再把仓库根 `.env` 当生产部署入口。
5. 保留当前 `admin-api` / `admin-worker` 分进程边界、`/health` / `/ready` 验证边界、MySQL/Redis 外部依赖边界。
6. 明确 MySQL/Redis 即使 Docker 化，也必须作为 `admin-go-state` 独立项目，不和 `admin-go-backend` 共享发布生命周期。
7. 明确数据库初始化、表数据 seed、迁移 SQL 是后续独立设计，不在本切片直接落 SQL。

## 非目标

- 不引入 1Panel。
- 不引入 Kubernetes、TKE、TCR 或托管容器平台。
- 不把前端塞进后端 Compose。
- 不拆 Go 后端模块为微服务。
- 不在本切片改业务 API、RBAC、数据库 schema、队列任务语义。
- 不第一刀删除 `config.LoadDotEnv()`；它只作为本地兼容入口保留，生产文档不再依赖它。
- 不在本切片编写或执行迁移 SQL，不设计具体表数据 seed 内容。
- 不让 `admin-api` / `admin-worker` 容器启动时自动改库。

## 当前事实

- `admin_back_go/Dockerfile` 已能构建 `admin-api` 和 `admin-worker` 两个二进制。
- `admin_back_go/deploy/docker-first/docker-compose.yml` 是当前 canonical 双服务容器形态：`admin-api` 暴露 8080，`admin-worker` 不暴露公网端口。
- `admin_back_go/deploy/docker-first/compose.env.example` 和 `admin-go.env.example` 分别负责 Compose 项目变量和后端运行配置模板。
- `admin_back_go/deploy/first-node/` 是旧过渡目录，确认无 active 文档依赖后应删除，避免和 Docker-first canonical 入口并存。
- `docs/deployment/production.md` 仍有偏传统进程/环境变量部署的表述，需要降级为架构边界或指向 Docker-first runbook。
- `docs/deployment/local.md` 仍以 `.env + go run` 作为默认本地启动方式，需要明确这是开发兼容路径，不是生产路径。

## 目标部署拓扑

```text
前端：
  admin_front_ts build -> dist -> 宝塔/Nginx 静态站点

后端应用项目 admin-go-backend：
  宝塔 Docker / Docker Compose
    admin-api      HTTP + WebSocket，绑定 127.0.0.1:8080 或内网 IP:8080
    admin-worker   Asynq consumer + scheduler，不暴露公网端口

状态服务项目 admin-go-state：
  宝塔 Docker / Docker Compose，独立生命周期
    MySQL          source of truth，独立数据卷和备份策略
    Redis          token/session/cache/captcha/queue/realtime fan-out，独立数据卷/密码策略

入口：
  宝塔 Nginx / OpenResty
    https://www.zgm2003.cn -> admin-api
```

第一阶段推荐 MySQL/Redis 与后端容器解耦。单机试运行可以把 MySQL/Redis 放在同一台机器，甚至同样用宝塔 Docker 管；但它们必须属于独立的 `admin-go-state` 项目。后端 Compose 不默认内置 MySQL/Redis，避免用户误以为重启后端项目会管理数据库生命周期。

## 状态服务 Docker 策略

推荐但不强制：

```text
admin-go-state
  mysql
  redis

admin-go-backend
  admin-api
  admin-worker
```

核心原则：

```text
应用可重建，状态要保护。
```

允许的部署方式：

```text
1. 同一台服务器：宝塔 Docker 同时管理 admin-go-state 和 admin-go-backend 两个项目。
2. 多台服务器：状态节点单独跑 MySQL/Redis，后端节点通过内网地址连接。
3. 临时本地开发：使用已有本机 MySQL/Redis，只要 /ready 能准确暴露依赖状态。
```

禁止作为生产默认：

```text
admin-go-backend compose 同时包含 admin-api、admin-worker、mysql、redis。
```

原因不是网络隔离，而是生命周期隔离。后端发布经常需要 `up -d --build`、`restart`、回滚；MySQL/Redis 是状态服务，不能被后端发布节奏牵连，更不能因为误用 `down -v` 删除数据库卷。

如果 MySQL/Redis 也用 Docker，后续状态项目 runbook 必须明确：

```text
固定镜像版本，不用 latest
数据目录放 /www/docker/admin-go-state/
MySQL 必须有备份/恢复步骤
Redis 设置密码，不暴露公网端口
后端通过 Docker network 或宿主本地端口连接 state
```

## 配置策略

生产配置来源改成：

```text
宝塔 Docker Compose 项目环境变量 / env_file
或宝塔 Docker UI 管理的容器环境变量
或服务器上的 /www/docker/admin-go-backend/.env + /www/docker/admin-go-backend/admin-go.env
```

明确不再推荐：

```text
/www/project/admin_back_go/.env
仓库工作树里的生产 .env
裸机 systemd 读取 repo .env
```

Docker-first 有两类 env：`compose.env.example` 生成 `/www/docker/admin-go-backend/.env`，给 Docker Compose 解析路径、端口、构建上下文；`admin-go.env.example` 生成 `/www/docker/admin-go-backend/admin-go.env`，给后端容器进程读取业务运行配置。部署资产目录不保存真实 `.env` 或 `admin-go.env`；真实运行 env 只在服务器 Compose 工作目录或本地临时目录生成。后端代码仍读取 `os.Getenv`。Docker-first 不是“没有环境变量”，而是“环境变量由容器运行时注入，不由仓库工作树根 `.env` 文件承担生产入口”。

必须稳定的生产配置：

```text
APP_SECRET
MYSQL_DSN
REDIS_ADDR
REDIS_PASSWORD
TOKEN_REDIS_DB
QUEUE_REDIS_DB
REALTIME_PUBLISHER
CORS_ALLOW_ORIGINS
PAYMENT_CERT_BASE_DIR
SCHEDULER_ENABLED
```

## 文件和目录约定

推荐新增 canonical backend deploy 目录：

```text
admin_back_go/deploy/docker-first/
  docker-compose.yml
  compose.env.example
  admin-go.env.example
  README.md
```

推荐 root canonical runbook：

```text
docs/deployment/docker-first-backend.md
docs/deployment/docker-first-state.md
```

`docker-first-backend.md` 负责 `admin-api` / `admin-worker`；`docker-first-state.md` 只负责 MySQL/Redis 的 Docker 生命周期、目录、备份和连接边界，不负责本次迁移 SQL 细节。

旧路径处理策略：

```text
docs/deployment/first-node-baota-docker.md -> 重命名为 docker-first-backend.md
admin_back_go/deploy/first-node/ -> 删除，不保留第二套活动入口
```

删除旧目录的原因：当前 active docs 已指向 `deploy/docker-first/`，继续保留 `first-node` 会让宝塔 Docker 项目名和 env 模板入口产生歧义。

## 卷和持久化

后端容器只持久化运行时私有文件，不持久化数据库：

```text
/www/docker/admin-go-backend/runtime -> /app/runtime
/www/docker/admin-go-backend/exports -> /app/exports
```

`runtime` 承载：

```text
runtime/logs/admin-api.log
runtime/logs/admin-worker.log
runtime/payment/certs/alipay/<config_code>/<sha256>.crt
```

多后端节点时，支付证书目录必须通过共享卷或部署同步保证每个 `admin-api` / `admin-worker` 节点都能读到同一批相对路径。

## 宝塔 Docker 操作口径

宝塔只承担容器生命周期和日志入口：

```text
创建 Compose 项目
选择 /www/docker/admin-go-backend 作为 Compose 工作目录
使用 docker-compose.yml
配置 ADMIN_BACK_GO_DIR=/www/project/admin_back_go
配置 ADMIN_GO_ENV_FILE=/www/docker/admin-go-backend/admin-go.env
启动 admin-api / admin-worker
查看容器日志和健康状态
```

宝塔 Nginx 仍负责：

```text
SSL 证书
域名绑定
反向代理
WebSocket Upgrade header
```

## 数据库初始化和迁移 SQL 策略

Docker-first 只解决运行时进程编排，不替代数据库初始化和迁移。首次部署新 MySQL 或升级已有 MySQL 时，仍然需要单独处理：

```text
创建 database / user / 权限
导入 baseline SQL
执行后续 migration SQL
校验菜单、权限、system_settings、基础配置表数据
```

但本切片不设计具体 SQL。后续需要单独做一个“数据库初始化与迁移设计”切片，按当前运行时真实表结构和产品需求设计：

```text
baseline schema
必需 seed 数据
菜单/权限/角色授权
system_settings 默认值
幂等迁移顺序
失败回滚和备份策略
```

当前原则：

```text
迁移是显式步骤，应用启动是显式步骤。
```

不在 `admin-api` / `admin-worker` 启动时自动改库，避免多副本同时启动抢迁移、容器重启重复改库、失败半截但服务状态不清楚。

## 验证标准

本切片完成后必须能证明：

```text
docker compose config 通过
backend compose 不包含 mysql/redis 服务
admin-api 容器 healthcheck 通过
curl http://127.0.0.1:8080/health 返回 200
curl http://127.0.0.1:8080/ready 能区分 MySQL/Redis/queue/realtime 状态
宝塔 Nginx 反代文档仍指向 admin-api
前端部署文档没有被改成 Docker-only
状态服务文档明确 MySQL/Redis 是独立项目，不跟随后端 compose 生命周期
迁移 SQL 被明确标记为后续独立设计，不伪装成已完成
```

本地文档/配置验证至少执行：

```powershell
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1
$env:ADMIN_BACK_GO_DIR=(Resolve-Path 'admin_back_go').Path
$env:ADMIN_GO_ENV_FILE=(Resolve-Path 'admin_back_go\deploy\docker-first\admin-go.env.example').Path
docker compose -f admin_back_go\deploy\docker-first\docker-compose.yml config --quiet
```

## 风险和约束

- 如果某台旧服务器仍手工引用 `deploy/first-node/`，升级时必须先改成 `deploy/docker-first/`，因为旧目录不再保留第二套 Compose。
- 如果 MySQL/Redis 也由宝塔 Docker 管理，必须明确它们是 `admin-go-state` 状态服务，不跟随后端 Compose 随意 `down -v`。
- 如果后续迁移 SQL 设计不到位，Docker 部署只能证明容器启动，不能证明业务表、菜单、权限和系统配置完整。
- 如果 `APP_SECRET` 变化，登录态和已加密 secret 会失效，必须继续引用 auth reset runbook。
- 如果多 worker 同时启用 scheduler，需要保留 Redis lock 和幂等边界说明。
