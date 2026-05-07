# Local Development Runtime

状态：implemented baseline, smoke verified。本文只写当前运行事实，不把 planned 写成 implemented。

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

## 后端启动

```powershell
cd E:\admin_go\admin_back_go
Copy-Item .env.example .env  # 仅首次；真实密码不要提交

go run ./cmd/admin-api
```

另开一个终端启动 worker：

```powershell
cd E:\admin_go\admin_back_go
go run ./cmd/admin-worker
```

如果 8080 被占用：

```powershell
netstat -ano | Select-String ':8080\s+.*LISTENING'
Stop-Process -Id <PID> -Force
```

或者临时改：

```powershell
$env:HTTP_ADDR=':18081'
go run ./cmd/admin-api
```

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

当前 `.env.example` 默认：

```text
REDIS_DB=0          # 普通缓存、验证码、verify code
TOKEN_REDIS_DB=2    # token/session
QUEUE_REDIS_DB=3    # Asynq queue broker / asynqmon
```

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
REALTIME_HEARTBEAT_INTERVAL=25s
REALTIME_SEND_BUFFER=16
```

当前只支持：

```text
local
noop
redis
```

`redis` fan-out 已实现，主要用于 `notification.created.v1` 的跨进程推送。默认本地 smoke 仍用 `local/noop`；`REALTIME_PUBLISHER=redis` 只有在你确实要测分布式 fan-out 时才启用，别再把它写成 planned。

## 本地验证

轻量：

```powershell
cd E:\admin_go\admin_back_go
go test -p=1 ./internal/bootstrap ./internal/module/system ./internal/platform/taskqueue ./internal/module/realtime ./internal/platform/realtime
powershell -ExecutionPolicy Bypass -File .\scripts\basic-admin-smoke.ps1 -Account <account> -Password <password>
```

完整：

```powershell
go test -p=1 ./...
go vet -p=1 ./...
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account <account> -Password <password>
```

## Payment runtime certs

支付证书属于 Go runtime，不再依赖 `E:/admin/admin_back`。本地首次配置或 PHP teardown 前必须执行：

```powershell
cd E:\admin_go\admin_back_go
powershell -ExecutionPolicy Bypass -File .\scripts\migrate-payment-certs.ps1 `
  -SourceRoot E:/admin/admin_back `
  -TargetRoot E:/admin_go/admin_back_go
```

`.env` 必须保持：

```text
PAYMENT_CERT_BASE_DIR=E:/admin_go/admin_back_go
LEGACY_ADMIN_BACK_ROOT=
```

验证只能输出 path/bytes/sha256，不输出证书正文或私钥：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-payment-certs.ps1 -DisallowLegacyRoot
```

`runtime/cert/alipay/*.crt` 是部署文件，已被 `.gitignore` 的 `runtime/` 排除；私钥不落文件，仍只存在于 `pay_channel.app_private_key_enc`。
