# Local Development Runtime

状态：implemented Docker-first baseline；当前 Docker-first readiness 只以 `/health` 和 `/ready` 为准，smoke 当前状态见 `docs/testing/smoke-matrix.md`。本文只写当前运行事实，不把 planned 写成 implemented。

## 进程边界

本地开发至少三条进程：

```text
admin-api     # Go HTTP API：REST + 第一阶段 WebSocket upgrade
admin-worker  # Asynq consumer + gocron scheduler；不提供 HTTP
frontend      # Vue/Vite admin 前端
```

规则：

```text
admin-api 不消费队列，不跑 cron。
admin-worker 不暴露 REST，不处理浏览器请求。
WebSocket 当前由 admin-api 承载；连接数/内存/fd 压力上来后再拆 cmd/admin-realtime。
```

## 后端本地启动

后端本地开发统一 Docker-first，不再使用仓库根 `.env + go run` 启动 `admin-api` / `admin-worker`。

`admin_back_go/deploy/docker-first/docker-compose.yml` 已经固定开发者默认值，不再需要 Compose `.env`：

```text
源码目录:   ../..
运行配置:   ./admin-go.env
运行目录:   ./runtime -> /app/runtime
导出目录:   ./exports -> /app/exports
API 端口:   127.0.0.1:8080 -> container 8080
```

首次准备：

```powershell
cd E:\admin_go\admin_back_go\deploy\docker-first
New-Item -ItemType Directory -Force -Path runtime\logs, exports
```

确认 `admin-go.env` 至少设置：

```env
MYSQL_DSN=你的 MySQL DSN
REDIS_ADDR=host.docker.internal:6380
APP_SECRET=本地长随机字符串，至少 32 位
CORS_ALLOW_ORIGINS=http://localhost:5173,http://127.0.0.1:5173,http://192.168.5.20:5173
```

上面的 `192.168.5.20` 只是当前开发机的 LAN 示例；换电脑或换网段必须替换成实际 H5 origin。`admin_app`
默认 API base 是本机 `http://127.0.0.1:8080/api/app/v1`，LAN 真机调试必须通过
`VITE_APP_API_BASE_URL` 覆盖为当前手机可访问的 Go backend 地址。

启动后端：

```powershell
cd E:\admin_go\admin_back_go\deploy\docker-first
docker compose up -d --build
docker compose ps
```

验证 Docker-first 当前运行时只看宿主 `127.0.0.1:8080` 的 `/health` 和 `/ready`：

```powershell
curl.exe http://127.0.0.1:8080/health
curl.exe http://127.0.0.1:8080/ready
```

如果宿主 `8080` 被占用，直接改 `docker-compose.yml` 的 `ports` 行，例如改成 `127.0.0.1:18081:8080`，不要为了端口再引入 Compose `.env`。

局域网真机调试时，再把 `ports` 行按需改成 `0.0.0.0:8080:8080`，并确认防火墙和 `CORS_ALLOW_ORIGINS` 覆盖当前 H5/LAN dev origin。

## 前端启动

```powershell
cd E:\admin_go\admin_front_ts
npm run dev
```

前端访问 Go API 的 base URL 必须指向 admin-api，例如：

```text
VITE_GO_API_BASE_URL=http://127.0.0.1:8080
```

队列监控 iframe/new-window 必须使用 Go API origin 的绝对 URL：

```text
http://127.0.0.1:8080/api/admin/v1/queue-monitor-ui
```

不能用前端相对路径 `/api/admin/v1/queue-monitor-ui`，否则会落到 Vite SPA 自己的 404。

## Redis DB 分工

当前 `deploy/docker-first/admin-go.env.example` 默认：

```text
REDIS_DB=0          # 普通缓存、验证码、verify code
TOKEN_REDIS_DB=2    # token/session
QUEUE_REDIS_DB=3    # Asynq queue broker / asynqmon
```

本地 Docker-first 只需要保留 `QUEUE_ENABLED`、`QUEUE_REDIS_DB`、`QUEUE_CONCURRENCY`。Queue lane 名称、权重、默认 retry/timeout 和 worker shutdown timeout 都是 Go 代码默认值，不通过本地 env 调。

`/ready` 会分别检查：

```text
redis
 token_redis
queue_redis
```

queue 启用但 `REDIS_ADDR` 为空时，`queue_redis` 必须 down；这是配置错误，不是可静默跳过的状态。

## Realtime 本地配置

```text
REALTIME_ENABLED=true
REALTIME_PUBLISHER=local
```

Realtime Redis Pub/Sub channel、heartbeat interval 25s、每连接 send buffer 16 都是 Go 代码内置默认值，不通过 env 或 system_settings 配置。

当前只支持：

```text
local
noop
redis
```

`redis` fan-out 已实现，主要用于 `notification.created.v1` 的跨进程推送。本地 Docker smoke 可以用 `local/noop`；`REALTIME_PUBLISHER=redis` 只有在你确实要测分布式 fan-out 时才启用，别再把它写成 planned。

## 本地验证

轻量：

```powershell
cd E:\admin_go\admin_back_go
go test -p=1 ./internal/bootstrap ./internal/module/system ./internal/infra/taskqueue ./internal/module/realtime ./internal/infra/realtime
powershell -ExecutionPolicy Bypass -File .\scripts\basic-admin-smoke.ps1 -Account <account> -Password <password>
```

注意：smoke 脚本默认启动临时后端/worker 进程，basic 默认 `127.0.0.1:18080`，full 默认 `127.0.0.1:18081`；它们不是上面 Docker-first 的 `127.0.0.1:8080` readiness 验证。

完整：

```powershell
go test -p=1 ./...
go vet -p=1 ./...
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account <account> -Password <password>
```

## Payment runtime certs

支付证书属于 Go runtime，不再依赖 `E:/admin/admin_back`。本地首次配置或 PHP teardown 前必须执行：

本地支付宝证书不再从历史目录迁移。进入后台 `/payment/config` 页面后，用“证书上传”分别上传：

```text
应用公钥证书：app_cert
支付宝公钥证书：alipay_cert
支付宝根证书：alipay_root_cert
```

支付证书根目录必须是本地文件系统目录，不是 URL：

```text
PAYMENT_CERT_BASE_DIR=E:/admin_go/admin_back_go
```

上传后服务端只保存私有相对路径，形如：

```text
runtime/payment/certs/alipay/<config_code>/<sha256>.crt
```

验证只能输出 path/bytes/sha256，不输出证书正文或私钥：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-payment-certs.ps1 -DisallowLegacyRoot
```

支付配置运行事实源是 `payment_configs`。私钥字段只允许以 `private_key_enc` 加密保存，API、日志、smoke 和前端类型都不能返回私钥明文或密文。
