# Production Deployment Baseline

状态：生产部署边界说明。具体后端生产 runbook 以 `docs/deployment/docker-first-backend.md` 为准；MySQL/Redis Docker 边界以 `docs/deployment/docker-first-state.md` 为准；前端仍保持现有静态站点部署方式。

当前项目生产域名映射：

```text
FRONTEND_DOMAIN=zgm2003.cn
API_DOMAIN=www.zgm2003.cn
```

也就是说：浏览器打开 `https://zgm2003.cn`，REST API 走 `https://www.zgm2003.cn/api/admin/v1/...`，生产 WebSocket 默认走 `wss://zgm2003.cn/api/admin/v1/realtime/ws` 并由前端站点精确反代到 Go 后端。

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
2. 按 worker 节点能力调整 QUEUE_CONCURRENCY
3. 单独部署 low/AI worker
4. 真需要时再拆独立服务
```

## 后端容器运行配置

生产配置由宝塔 Docker / Docker Compose 注入到容器运行时，不再推荐把仓库工作树里的 `.env` 作为生产入口。

最少必须明确配置：

```text
APP_ENV=production
HTTP_ADDR=:8080
MYSQL_DSN=<user:pass@tcp(host:3306)/db?...>
REDIS_ADDR=<host:6379>
REDIS_PASSWORD=<secret if any>
APP_SECRET=<code minimum 32 chars; production should use 64+ random chars>
TOKEN_REDIS_DB=2
QUEUE_ENABLED=true
QUEUE_REDIS_DB=3
QUEUE_CONCURRENCY=10
REALTIME_ENABLED=true
REALTIME_PUBLISHER=redis
CORS_ALLOW_ORIGINS=https://zgm2003.cn
```

规则：

```text
APP_SECRET 变更会让现有 access/refresh token、Redis session cache、以及已加密的 AI/upload/payment secret 全部失效；变更前按 auth-foundation-v2 reset runbook 处理。
手机号验证码固定 123456，不接短信，不受 env 控制；邮箱验证码必须走邮件管理配置的腾讯云 SES。生产如果不开放手机号登录，在 auth_platforms.login_types 关闭 phone。
验证码有效期不是 env；邮件渠道来自 `mail_configs.verify_code_ttl_minutes`，短信/手机号渠道来自 `sms_configs.verify_code_ttl_minutes`，默认 5 分钟，可分别在 `/system/mail` 和 `/system/sms` 修改。Redis namespace `auth:verify_code:` 由代码内置，不通过 env 配置。验证码模板变量必须且只能包含 `code` / `ttl_minutes`。
Queue lane 名称、lane 权重、默认 retry/timeout 和 worker shutdown timeout 是 Go 代码内置默认值；生产 env 只调 QUEUE_ENABLED、QUEUE_REDIS_DB、QUEUE_CONCURRENCY。
REALTIME_PUBLISHER 支持 local/noop/redis；生产 Docker-first 默认用 redis，因为 worker -> api、以及多 admin-api 副本的 `notification.created.v1` fan-out 不能靠本机内存。local 只适合单进程/不依赖 worker fan-out 的降级部署，前提是你明确接受跨进程 realtime 不成立。
Realtime Redis Pub/Sub channel、25s heartbeat、每连接 16 条 send buffer 是 Go 代码内置默认值，不通过 env 或 system_settings 配置。
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
2. 备份 /www/docker/admin-go-backend/admin-go.env
3. 记录当前 admin_back_go commit
4. 重新构建并启动 admin-api/admin-worker 容器
5. 先验证 /ready，再切换或保留宝塔 Nginx 反代
6. worker 滚动替换，避免 in-flight task 被硬杀
```

失败回滚：

```text
回退 admin_back_go commit
恢复 /www/docker/admin-go-backend/admin-go.env
重新构建并启动 admin-api/admin-worker 容器
确认 /ready 和 full smoke 的核心链路
```

## Payment runtime certs

生产发布不能依赖历史目录。支付宝证书通过后台 `/payment/config` 页面上传，Go 后端把文件写入私有本地目录：

```text
runtime/payment/certs/alipay/<config_code>/<sha256>.crt
```

后端容器运行配置必须显式配置：

```text
PAYMENT_CERT_BASE_DIR=/app
```

发布 gate：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-payment-certs.ps1 -DisallowLegacyRoot
```

该 gate 只允许输出 path/bytes/sha256。不要把证书正文、私钥明文、`payment_configs.private_key_enc` 导出到日志、CI artifact 或 git。

生产运行事实源固定为：

```text
payment_configs.private_key_enc
payment_configs.app_cert_path
payment_configs.platform_cert_path
payment_configs.root_cert_path
```

多后端节点时，本地证书目录必须用共享卷或部署同步保证每个 admin-api/admin-worker 节点都能解析同一批相对路径；否则启用/测试可能只在上传节点成功。
