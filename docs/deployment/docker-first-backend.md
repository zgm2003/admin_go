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

MySQL/Redis 可以也推荐用宝塔 Docker 管，但必须属于独立的 `admin-go-state` 项目。后端 Compose 不内置 MySQL/Redis；状态项目的 Docker 边界见 `docs/deployment/docker-first-state.md`。


## 部署目录规则

`admin_back_go/deploy/docker-first/` 是可提交的部署资产目录，只保留：

```text
docker-compose.yml
compose.env.example
admin-go.env.example
README.md
```

不要在这个目录里放真实 `.env`、`admin-go.env`、`runtime/`、`exports/`。真实运行文件属于服务器 Compose 工作目录：

```text
/www/docker/admin-go-backend/.env
/www/docker/admin-go-backend/admin-go.env
/www/docker/admin-go-backend/runtime/
/www/docker/admin-go-backend/exports/
```

本地如果只是验证 Compose 结构，使用 `compose.env.example` / `admin-go.env.example` 做只读 config 校验，不在 deploy 目录生成真实 env。

## 0. Linus 三问

```text
1. 真问题：需要把第一台机器跑成可验证的后端入口，不是设计 Kubernetes。
2. 更简单做法：一个镜像，两个容器，外置 MySQL/Redis，宝塔反代。
3. 不破坏什么：前端继续访问 https://www.zgm2003.cn/api/admin/v1 和 wss://www.zgm2003.cn/api/admin/v1/realtime/ws。
```

## 1. 服务器目录

在第一台机器 `118.126.104.244` 上：

```bash
mkdir -p /www/project
mkdir -p /www/docker/admin-go-backend/runtime/logs
mkdir -p /www/docker/admin-go-backend/runtime/payment/certs/alipay
mkdir -p /www/docker/admin-go-backend/exports
```

拉后端代码：

```bash
cd /www/project
git clone -b master https://github.com/zgm2003/admin_back_go.git admin_back_go
```

如果已经 clone：

```bash
cd /www/project/admin_back_go
git fetch origin master
git reset --hard origin/master
```

## 2. 写生产 env

复制模板：

```bash
cp /www/project/admin_back_go/deploy/docker-first/admin-go.env.example /www/docker/admin-go-backend/admin-go.env
chmod 600 /www/docker/admin-go-backend/admin-go.env
```

编辑：

```bash
vim /www/docker/admin-go-backend/admin-go.env
```

必须改掉这些值。这里的 `DB_PRIVATE_IP` / `REDIS_PRIVATE_IP` 指机器 C 的内网 IP；如果机器之间没有可互通内网，才临时使用机器 C 公网 IP，并且安全组/防火墙只放行机器 A / B 的源 IP。

```env
MYSQL_DSN=admin_user:CHANGE_ME@tcp(DB_PRIVATE_IP:3306)/admin?charset=utf8mb4&parseTime=True&loc=Local
REDIS_ADDR=REDIS_PRIVATE_IP:6379
REDIS_PASSWORD=
# 至少 64 位随机字符串；所有 admin-api/admin-worker 节点必须一致
APP_SECRET=CHANGE_ME_AT_LEAST_64_RANDOM_CHARS
```

第一台机器固定：

```env
APP_ENV=production
HTTP_ADDR=:8080
PAYMENT_CERT_BASE_DIR=/app
REALTIME_PUBLISHER=redis
CORS_ALLOW_ORIGINS=https://zgm2003.cn
```

验证码：

手机号验证码固定 `123456`，不接短信，不受 env 控制；邮箱验证码走腾讯云 SES。真实用户上线如果不开放手机号登录，在 `auth_platforms.login_types` 关闭 `phone`。验证码有效期不是 env；它来自 DB 配置 `system_settings.auth.verify_code.ttl_minutes`，默认 seed 为 5 分钟，可在 `/system/mail` 的“验证码公共配置”里修改。Redis namespace `auth:verify_code:` 由代码内置，不通过 env 配置。验证码模板变量必须且只能包含 `code` / `ttl_minutes`。

## 3. 支付证书目录

这里说的是支付宝/支付业务证书，不是 HTTPS SSL 证书。

放置规则很简单：

```text
HTTPS SSL 证书：放宝塔 Nginx，也就是机器 A 的 www.zgm2003.cn 站点配置里。
支付业务证书：放运行 Go 后端的机器上，也就是机器 A 和机器 B 都要放。
数据库机器 C：不跑后端就不需要支付证书。
```

如果启用支付宝，通过 `/payment/config` 上传后，机器 A 和机器 B 都必须能读到这里的私有证书文件：

```text
/www/docker/admin-go-backend/runtime/payment/certs/alipay/<config_code>/<sha256>.crt
```

容器内对应：

```text
/app/runtime/payment/certs/alipay/<config_code>/<sha256>.crt
```

所以 env 使用：

```env
PAYMENT_CERT_BASE_DIR=/app
```

如果暂时不用支付，也先保留空目录。不要把历史目录塞进生产 env。

证书跟着后端运行节点走，不跟着 MySQL/Redis 状态节点走。也就是说：A 有后端就放 A，B 有后端就放 B，C 只跑数据库/Redis 就不放。多后端节点要用共享卷或部署同步，不能只让上传节点有证书。

## 3.1 系统日志跟着后端节点走

当前系统日志是后端本机文件日志，不是存在 MySQL/Redis 里的集中日志。

每台后端机器都有自己的日志目录：

```text
机器 A：/www/docker/admin-go-backend/runtime/logs/admin-api.log
机器 A：/www/docker/admin-go-backend/runtime/logs/admin-worker.log
机器 B：/www/docker/admin-go-backend/runtime/logs/admin-api.log
机器 B：/www/docker/admin-go-backend/runtime/logs/admin-worker.log
```

容器内对应：

```text
/app/runtime/logs/admin-api.log
/app/runtime/logs/admin-worker.log
```

所以后台“系统日志”接口读取的是**当前处理这个请求的后端节点本地日志**。如果 `www.zgm2003.cn` 后面同时负载均衡到 A / B，那么你在页面里看到的系统日志可能一会儿是 A 的，一会儿是 B 的。

第一阶段简单做法：

```text
1. 系统日志页面先只作为当前节点运行日志查看。
2. 真要查全量日志，分别 SSH 到 A / B 看 /www/docker/admin-go-backend/runtime/logs。
3. 等正式需要统一日志，再上 Loki/ELK/腾讯云 CLS，不要现在自造一套日志平台。
```

注意区分：

```text
系统运行日志：跟着后端节点走，A/B 各一份。
操作审计日志：写 MySQL，跟着机器 C 的数据库走，是全局一致的。
```

## 4. 启动 Docker Compose

进入部署目录：

```bash
mkdir -p /www/docker/admin-go-backend
cp /www/project/admin_back_go/deploy/docker-first/docker-compose.yml /www/docker/admin-go-backend/docker-compose.yml
cp /www/project/admin_back_go/deploy/docker-first/compose.env.example /www/docker/admin-go-backend/.env
cd /www/docker/admin-go-backend
```

复制 `/www/docker/admin-go-backend/.env` 后按需调整 `ADMIN_BACK_GO_DIR`、`ADMIN_GO_ENV_FILE`、挂载目录和端口。`.env` 是 Docker Compose 项目变量，不是后端业务运行配置；后端业务配置仍在 `/www/docker/admin-go-backend/admin-go.env`。

确保挂载目录能被容器内 `app` 用户写入：

```bash
chown -R 10001:10001 /www/docker/admin-go-backend/runtime /www/docker/admin-go-backend/exports
```

如果使用宝塔 Docker 面板创建 Compose 项目，后端应用项目命名为 `admin-go-backend`，Compose 工作目录使用 `/www/docker/admin-go-backend`，Compose 文件使用 `/www/docker/admin-go-backend/docker-compose.yml`。项目环境变量可以来自 `/www/docker/admin-go-backend/.env`，至少包含 `ADMIN_BACK_GO_DIR=/www/project/admin_back_go` 和 `ADMIN_GO_ENV_FILE=./admin-go.env`。宝塔 Docker 负责启动、停止、重启、查看容器日志；宝塔 Nginx 仍负责 SSL 和反向代理。

MySQL/Redis 即便也用 Docker，也放在独立的 `admin-go-state` 项目，不写进后端 Compose。

启动：

```bash
docker compose up -d --build
```

看状态：

```bash
docker compose ps
docker compose logs -f admin-api
docker compose logs -f admin-worker
```

本机验证：

```bash
curl -fsS http://127.0.0.1:8080/health
curl -fsS http://127.0.0.1:8080/ready
```

判断：

```text
/health 200：只说明进程活着
/ready 200：MySQL、Redis、token redis、queue redis、realtime 配置都可用
```

如果 `/health` 通但 `/ready` 不通，不要改 Nginx，先看 env、MySQL、Redis。

## 5. 宝塔配置 www.zgm2003.cn

宝塔新建站点：

```text
域名：www.zgm2003.cn
类型：纯静态即可
SSL：开启
```

然后在该站点 Nginx 配置里加入反代：

```nginx
location / {
    proxy_pass http://127.0.0.1:8080;

    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Request-Id $request_id;

    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $connection_upgrade;

    proxy_connect_timeout 30s;
    proxy_send_timeout 3600s;
    proxy_read_timeout 3600s;
}
```

如果 Nginx 测试报：

```text
unknown "connection_upgrade" variable
```

在 http 级别补一次：

```nginx
map $http_upgrade $connection_upgrade {
    default upgrade;
    '' close;
}
```

宝塔通常已经有 `/www/server/panel/vhost/nginx/0.websocket.conf`，不要重复加两份。

重载：

```bash
nginx -t && nginx -s reload
```

## 6. 公网验证

后端入口：

```bash
curl -i https://www.zgm2003.cn/health
curl -i https://www.zgm2003.cn/ready
curl -i https://www.zgm2003.cn/api/admin/v1/auth/login-config
```

前端到后端路径：

```text
浏览器 https://zgm2003.cn
  -> 前端静态资源
  -> API https://www.zgm2003.cn/api/admin/v1/...
  -> WebSocket wss://www.zgm2003.cn/api/admin/v1/realtime/ws
```

如果 `https://www.zgm2003.cn/api/...` 返回前端 `index.html`，说明 www 站点还被配成了前端静态站，反代没接管。

## 7. 第二台后端加入时怎么改

第一阶段先这样：

```text
www.zgm2003.cn -> 118.126.104.244 Nginx -> 127.0.0.1:8080 admin-api
```

第二台后端 B 跑起来后，B 的 Docker 端口不能只绑定 `127.0.0.1`，否则机器 A 的 Nginx 访问不到 B。B 启动时要显式绑定内网地址或 `0.0.0.0`，并用安全组/防火墙只允许机器 A 访问 B 的 8080：

```bash
ADMIN_BACK_GO_DIR=/www/project/admin_back_go \
ADMIN_GO_ENV_FILE=/www/docker/admin-go-backend/admin-go.env \
ADMIN_API_HOST_BIND=0.0.0.0 \
ADMIN_API_HOST_PORT=8080 \
docker compose up -d --build
```

然后把机器 A 的宝塔 Nginx 改成 upstream：

```nginx
upstream admin_go_api {
    server 127.0.0.1:8080;
    server 第二台后端内网IP:8080;
}

location / {
    proxy_pass http://admin_go_api;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Request-Id $request_id;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $connection_upgrade;
    proxy_read_timeout 3600s;
}
```

`admin-worker` 的 scheduler 第一阶段只开一组。建议先让 A 或 B 其中一台保持：

```env
SCHEDULER_ENABLED=true
```

另一台先设为：

```env
SCHEDULER_ENABLED=false
```

等确认 Redis lock 和任务幂等都没问题，再考虑多 worker 节点同时开 scheduler。

## 8. 数据库初始化和迁移

Docker-first 只负责后端进程编排，不替代数据库初始化和迁移。首次部署新 MySQL、升级已有 MySQL、补菜单/权限/系统设置 seed 时，必须走单独的 SQL/migration runbook。

本切片不把迁移 SQL 写进 `admin-api` / `admin-worker` 启动流程。迁移是显式步骤，应用启动是显式步骤；后续单独设计 baseline schema、seed 数据、菜单/权限、`system_settings` 默认值和幂等迁移顺序。

当前原则：

```text
Docker 管应用进程。
admin-go-state 管 MySQL/Redis 生命周期。
SQL migration 管数据库结构和基础数据。
```

## 9. 回滚

记录旧版本：

```bash
cd /www/project/admin_back_go
git rev-parse --short HEAD
```

回滚代码：

```bash
cd /www/project/admin_back_go
git fetch origin master
git reset --hard <旧commit>
cd /www/docker/admin-go-backend
docker compose up -d --build
curl -fsS http://127.0.0.1:8080/ready
```
