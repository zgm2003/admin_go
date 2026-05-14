# Production Deployment Baseline

状态：planned deployment guide for implemented modular monolith baseline。本文不是 Kubernetes 教程，只固定当前项目不能走歪的运行边界。

## 进程模型

生产第一阶段部署这些进程：

```text
admin-api       # 可多副本；REST + 当前 WebSocket upgrade
admin-worker    # 一个或多个；消费 Asynq queue + scheduler
frontend static # Vue build 产物，由 Nginx/CDN 服务
```

未来满足条件再拆：

```text
admin-realtime  # WebSocket-only，只有连接数/发布节奏/扩容隔离需要时才拆
```

禁止：

```text
在 admin-api 里顺手启动 worker 或 cron
让 worker 暴露管理 REST
用内存 session/captcha/RBAC cache 当正确性来源
把 WebSocket sticky session 当正确性依赖
```

## admin-api

`admin-api` 必须尽量无状态：

```text
session/token      -> Redis token DB
captcha/verifyCode -> Redis normal DB
RBAC cache         -> Redis normal DB，cache miss/error 回源 MySQL
queue broker       -> Redis queue DB，admin-api 只投递，不消费
realtime manager   -> 当前本机连接表；public contract 不假设单机
```

Health/readiness：

```text
/health 只证明进程活着，不访问外部依赖
/ready 访问 MySQL、Redis、TokenRedis、QueueRedis，并检查 realtime config
```

负载均衡：

```text
REST 可以 round-robin
WebSocket 可用 sticky session 作为优化，但不能依赖 sticky 保证业务正确性
Nginx 必须保留 Upgrade / Connection header
```

## admin-worker

`admin-worker` 是异步边界：

```text
Asynq server owns queue consumption
gocron scheduler only enqueues tasks
handler must be idempotent
Asynq is at-least-once, not exactly-once
```

队列 lane：

```text
critical # 登录日志、权限缓存刷新、短任务
default  # 普通业务异步任务
low      # 慢任务、导入导出、AI 后处理
```

扩容优先级：

```text
1. 增加 admin-worker 进程数量
2. 调整 QUEUE_CONCURRENCY 和 lane 权重
3. 单独部署 low/AI worker
4. 真需要时再拆独立服务
```

## 环境变量

最少必须明确配置：

```text
APP_ENV=production
HTTP_ADDR=:8080
MYSQL_DSN=<user:pass@tcp(host:3306)/db?...>
REDIS_ADDR=<host:6379>
REDIS_PASSWORD=<secret if any>
APP_SECRET=<at least 64 random chars>
TOKEN_REDIS_DB=2
QUEUE_ENABLED=true
QUEUE_REDIS_DB=3
REALTIME_ENABLED=true
REALTIME_PUBLISHER=local
CORS_ALLOW_ORIGINS=https://admin.example.com
VERIFY_CODE_TTL=5m
VERIFY_CODE_REDIS_PREFIX=auth:verify_code:
```

规则：

```text
APP_SECRET 变更会让现有 access/refresh token、Redis session cache、以及已加密的 AI/upload/payment secret 全部失效；变更前按 auth-foundation-v2 reset runbook 处理。
手机号验证码固定 123456，不接短信，不受 env 控制；邮箱验证码必须走邮件管理配置的腾讯云 SES。生产如果不开放手机号登录，在 auth_platforms.login_types 关闭 phone。
REALTIME_PUBLISHER 支持 local/noop/redis；redis 是 `notification.created.v1` 的跨进程 fan-out 选项，前提是 Redis 正常可用。
```

## 日志和请求 ID

当前 API 已有：

```text
X-Request-Id / X-Trace-Id 入口透传或生成
JSON slog
AccessLog middleware
```

生产要求：

```text
反向代理保留 X-Request-Id
应用日志进入集中日志系统
不要记录 password、captcha_answer、access_token、refresh_token
```

## 回滚

第一阶段没有自动迁移器。生产变更按以下顺序：

```text
1. 备份 MySQL
2. 备份/记录当前 env
3. 发布 admin-api/admin-worker 二进制
4. 先启动一套新 admin-api 验证 /ready
5. 再切流量
6. worker 最后滚动替换，避免 in-flight task 被硬杀
```

失败回滚：

```text
回退二进制
恢复 env
重启 admin-api/admin-worker
确认 /ready 和 full smoke 的核心链路
```

## Payment runtime certs

生产发布不能依赖 legacy PHP 目录。支付证书必须随 Go backend runtime 部署到：

```text
admin_back_go/runtime/cert/alipay/appPublicCert.crt
admin_back_go/runtime/cert/alipay/alipayPublicCert.crt
admin_back_go/runtime/cert/alipay/alipayRootCert.crt
```

生产 env 必须显式配置：

```text
PAYMENT_CERT_BASE_DIR=/path/to/admin_back_go
LEGACY_ADMIN_BACK_ROOT=
PAYMENT_ALIPAY_TIMEOUT=10s
PAYMENT_NOTIFY_LOCK_TTL=30s
PAYMENT_ATTEMPT_LOCK_TTL=30s
```

发布 gate：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-payment-certs.ps1 -DisallowLegacyRoot
```

该 gate 只允许输出 path/bytes/sha256。不要把证书正文、私钥明文或 `payment_channel_configs.private_key_enc` 导出到日志、CI artifact 或 git。

生产运行事实源固定为新 payment 域：

```text
payment_channels
payment_channel_configs.private_key_enc
payment_channel_configs.app_cert_path
payment_channel_configs.alipay_cert_path
payment_channel_configs.alipay_root_cert_path
```

不要回退读取旧渠道表。
