# Token/session env 收口设计

日期：2026-05-20
状态：draft
范围：`admin_back_go` 认证 token/session Redis 基础设施配置、Docker-first env 模板、认证/session 文档和测试

## 目标

这次只做 **token/session env cleanup**，不重做登录、JWT、refresh token、用户会话管理、`auth_platforms` 认证策略 UI，也不旋转现有 `APP_SECRET`。

要达到的结果：

1. Docker-first env 只保留认证/session 启动必须由部署者提供或选择的项。
2. `TOKEN_REDIS_PREFIX`、`TOKEN_SESSION_CACHE_TTL`、`TOKEN_SINGLE_SESSION_POINTER_TTL` 改为代码内置默认值。
3. `APP_SECRET` 和 `TOKEN_REDIS_DB` 保留 env，不迁入 `system_settings`。
4. 不新增系统设置 key，不新增 SQL/migration。
5. 不改变业务 token/session 策略：access/refresh token TTL、单端登录策略、最大会话数继续由 `auth_platforms` 表管理。

## Linus 三问

1. 这是真问题吗？
   - 是。当前 Docker-first env 暴露 5 个认证/session 相关项，其中 3 个是 Redis key/cache 实现细节。普通部署用户看到 `TOKEN_SESSION_CACHE_TTL`、`TOKEN_SINGLE_SESSION_POINTER_TTL` 容易误以为它们是业务 token 有效期或单端登录开关，误调后会影响缓存命中、会话指针一致性和排障体验。
2. 有更简单的做法吗？
   - 有。保留 `APP_SECRET` 和 `TOKEN_REDIS_DB`；把 Redis namespace 和 cache TTL 收回代码常量。不新增后台配置、不新增 DB 读取路径。
3. 会破坏已有前端、接口、登录和权限吗？
   - 不应该。登录接口、refresh/logout、`users/me`、用户会话列表/踢下线、RBAC、前端 token 存储和权限路由都不变；只改变 3 个基础设施默认值来源。

## 当前事实

Docker-first env 当前暴露：

```env
APP_SECRET=CHANGE_ME_AT_LEAST_64_RANDOM_CHARS
TOKEN_REDIS_PREFIX=token:
TOKEN_REDIS_DB=2
TOKEN_SESSION_CACHE_TTL=30m
TOKEN_SINGLE_SESSION_POINTER_TTL=720h
```

当前代码读取位置：

- `APP_SECRET`：`internal/config.Load()` 读入 `Config.App.Secret`，`ValidateRuntimeSecrets` 校验非空/非弱值/长度，后续用于派生 JWT signing、refresh token pepper、secretbox、session-cache key。
- `TOKEN_REDIS_DB`：`internal/config.Load()` 读入 `Config.Token.RedisDB`，`bootstrap.NewResources` 用同一 Redis 地址/密码打开独立 TokenRedis DB。
- `TOKEN_REDIS_PREFIX`：生成 `token:session:<session_id>`、`token:cur_sess:<platform>:<user_id>` 等 Redis key。
- `TOKEN_SESSION_CACHE_TTL`：session cache-aside TTL；MySQL 命中后回写 Redis，Redis 命中后续期。
- `TOKEN_SINGLE_SESSION_POINTER_TTL`：单端登录当前 session pointer 的 Redis TTL。

这些键可以分成两类：

| env key | 当前含义 | 判断 | 目标 |
| --- | --- | --- | --- |
| `APP_SECRET` | 部署级根密钥，派生 JWT/refresh pepper/secretbox/session-cache key | 绝不能入库；DB 里的加密 secret 反而依赖它解密 | 保留 env |
| `TOKEN_REDIS_DB` | token/session 专用 Redis DB | 部署级 Redis 隔离选择；与 Redis 实例/DB 编号有关 | 保留 env |
| `TOKEN_REDIS_PREFIX` | token/session Redis key namespace | 代码命名空间；Docker-first 默认不需要用户改 | 内置 `token:` |
| `TOKEN_SESSION_CACHE_TTL` | Redis session cache TTL | cache-aside 实现细节，不是 access token TTL | 内置 `30m` |
| `TOKEN_SINGLE_SESSION_POINTER_TTL` | 单端登录 pointer TTL | pointer 缓存窗口，不是单端登录业务开关 | 内置 `720h` |

Live DB 现状说明：

- `system_settings` 当前有 `auth.captcha.*`、`auth.verify_code.ttl_minutes`、`upload.token.ttl_minutes` 等业务策略项，没有 token/session Redis cache 配置。
- `auth_platforms` 已经管理业务认证策略，例如 `access_ttl`、`refresh_ttl`、`single_session`、`max_sessions`、`login_types`、`captcha_type`。
- 因此本切片不是“把已有系统设置补接线”，而是把不该暴露的 env 收回代码默认。

## 选型

### 方案 A：把 3 个 Redis/cache 项迁到 `system_settings`

不推荐。

原因：

- `TOKEN_REDIS_PREFIX` 是 key 命名空间，不是业务配置；后台用户改错后旧 session cache 和新 session cache 会分裂。
- `TOKEN_SESSION_CACHE_TTL` 是 cache-aside TTL，不是 token 生命周期；放到系统设置页会强化误解。
- `TOKEN_SINGLE_SESSION_POINTER_TTL` 是单端登录 Redis pointer 的保留窗口；真正单端登录策略已经在 `auth_platforms.single_session`。
- Session authenticator 位于认证中间件关键路径，运行期从 DB 读这些实现参数会增加复杂度和失败面。

### 方案 B：继续保留全部 5 个 env

不采用。

原因：

- Docker-first env 继续变长，违背“用户只改必要部署项”的方向。
- 其中 3 个默认值对普通部署者没有产品意义。
- 误调风险大于收益：尤其是把 cache TTL 当成 token TTL、把 pointer TTL 当成单端登录开关。

### 方案 C：只保留部署级必要项，其余代码内置（推荐）

内容：

Docker-first env 保留：

```env
APP_SECRET=CHANGE_ME_AT_LEAST_64_RANDOM_CHARS
TOKEN_REDIS_DB=2
```

代码内置：

```text
DefaultTokenRedisPrefix = "token:"
DefaultTokenSessionCacheTTL = 30m
DefaultTokenSingleSessionPointerTTL = 720h
```

优点：

- env 一次减少 3 个键。
- 默认行为不变。
- 不新增 DB/system_settings 依赖。
- 业务认证策略和基础设施实现细节边界更清楚。

缺点：

- 极少数高级部署如果多个环境共享同一个 Redis DB，不能再单独通过 env 改 prefix；Docker-first 推荐做法应该是隔离 Redis DB/实例，而不是暴露 key namespace。

推荐采用。

## 推荐设计

### 1. Docker-first env 只保留两个 token/session 项

最终 Docker-first env 的认证/session 基础设施部分变为：

```env
# Code derives JWT signing, refresh-token pepper, secretbox, and session-cache keys internally.
APP_SECRET=CHANGE_ME_AT_LEAST_64_RANDOM_CHARS
TOKEN_REDIS_DB=2
```

删除：

```env
TOKEN_REDIS_PREFIX=token:
TOKEN_SESSION_CACHE_TTL=30m
TOKEN_SINGLE_SESSION_POINTER_TTL=720h
```

说明：

- `APP_SECRET` 不是系统设置，不能入库。变更它会导致 access/refresh token、Redis session cache、业务密钥解密全部受影响，需要单独 runbook。
- `TOKEN_REDIS_DB` 是部署拓扑/隔离项，保留给 Docker-first 用户按 Redis DB 编号选择。
- 本切片不调整 `REDIS_ADDR`、`REDIS_PASSWORD`、`REDIS_DB`。

### 2. token/session Redis policy 代码内置

建议在 `internal/config` 集中定义默认值，避免散写：

```text
DefaultTokenRedisPrefix = "token:"
DefaultTokenSessionCacheTTL = 30 * time.Minute
DefaultTokenSingleSessionPointerTTL = 30 * 24 * time.Hour
```

注意：

- `config.Load()` 不再读取 `TOKEN_REDIS_PREFIX`、`TOKEN_SESSION_CACHE_TTL`、`TOKEN_SINGLE_SESSION_POINTER_TTL`。
- 即使旧部署残留这些 env，代码也应该忽略，避免残留 env 继续改变行为。
- 直接构造 `config.TokenConfig{}` 或测试构造 path 时，bootstrap/session authenticator 仍要归一化到同一组默认值，不能出现散落 fallback。
- `session.NewAuthenticator` 可以保留防御性 fallback，但 fallback 值必须引用统一默认常量。

### 3. 不进 `system_settings`

本切片不新增：

```text
auth.token.redis_prefix
auth.token.session_cache_ttl
auth.token.single_session_pointer_ttl
```

理由：

- 这三个值是认证缓存实现参数，不是后台运营策略。
- `system_settings` 适合验证码 TTL、上传 token TTL 等业务可调策略。
- 认证中间件关键路径不应为了 Redis key/cache 默认值增加 DB 配置依赖。

### 4. 业务认证策略继续由 `auth_platforms` 管理

不改：

- `auth_platforms.access_ttl`
- `auth_platforms.refresh_ttl`
- `auth_platforms.single_session`
- `auth_platforms.max_sessions`
- `auth_platforms.bind_platform`
- `auth_platforms.bind_device`
- `auth_platforms.bind_ip`
- `auth_platforms.login_types`
- `auth_platforms.captcha_type`

说明：

- `TOKEN_SESSION_CACHE_TTL=30m` 不是 access token TTL。
- `TOKEN_SINGLE_SESSION_POINTER_TTL=720h` 不是是否单端登录。
- access/refresh token 生命周期继续来自具体平台策略，登录和 refresh 都必须经过 `auth_platforms`。

### 5. 运行时行为不变

不改：

- JWT claims 结构和签发逻辑。
- refresh token 生成、hash、轮换和 logout/revoke 流程。
- `user_sessions` 表结构和查询条件。
- Redis key 实际默认前缀：仍是 `token:`。
- session cache TTL：仍是 `30m`。
- single-session pointer TTL：仍是 `720h`。
- 用户会话列表/踢下线 API 和前端页面。
- RBAC、permission middleware、`users/me`。

### 6. APP_SECRET 只做文档澄清，不在本切片旋转

本地 `APP_SECRET` 示例需要继续表达“生产必须使用随机长字符串”。

建议文档口径：

```text
APP_SECRET is deployment root secret and must stay in env or secret manager.
Do not store APP_SECRET in database/system_settings.
Changing APP_SECRET requires the auth-foundation reset runbook.
```

如果要把示例值从 `CHANGE_ME_AT_LEAST_64_RANDOM_CHARS` 改成更明确的 `CHANGE_ME_TO_64_PLUS_RANDOM_CHARS`，可以在实现时一并调整 env example 文案；但不强制修改用户本地 ignored env。

## 迁移范围

### 需要改

后端仓 `admin_back_go`：

- `internal/config/config.go`
- `internal/config/config_test.go`
- `internal/module/session/service.go`
- `internal/module/session/*_test.go` 如直接写死默认值需要对齐常量
- `internal/bootstrap/*_test.go` 如直接构造 `TokenConfig` 需要对齐归一化
- `deploy/docker-first/admin-go.env.example`
- 本地 ignored 的 `deploy/docker-first/admin-go.env` 如果存在
- `docs/architecture.md`
- `README.md` 中 active env 列表和 token/session 配置说明

根仓 `admin_go`：

- `docs/status/current-status.md` 如 token/session env 口径有摘要
- `docs/testing/smoke-matrix.md` 如列出 Docker-first env guard
- `docs/contracts/admin-api-v1.md` 如描述 auth/session 配置来源

### 不需要改

- 前端代码。
- DB migration / seed。
- `system_settings` 页面。
- `auth_platforms` 表结构和管理接口。
- JWT / refresh token / user session API contract。
- Docker compose service 拓扑。

## 测试计划

后端最小验证：

```powershell
cd E:\admin_go\admin_back_go
go test -count=1 ./internal/config ./internal/module/session ./internal/bootstrap
go test -count=1 ./internal/module/auth ./internal/module/authplatform ./internal/middleware
go vet ./internal/config ./internal/module/session ./internal/bootstrap
```

Docker/deploy 验证：

```powershell
cd E:\admin_go\admin_back_go\deploy\docker-first
docker compose config --quiet
```

文档/env guard：

```powershell
cd E:\admin_go\admin_back_go
rg -n "TOKEN_REDIS_PREFIX|TOKEN_SESSION_CACHE_TTL|TOKEN_SINGLE_SESSION_POINTER_TTL" deploy docs README.md --glob '!**/*.map'
```

预期：

- `deploy/docker-first/admin-go.env.example` 不再出现三个已删除 key。
- active docs 不再把三个 key 列为用户需要配置的 Docker-first env。
- 代码测试可保留对默认常量名称/行为的断言。

运行时 smoke：

```powershell
cd E:\admin_go\admin_back_go\deploy\docker-first
docker compose up -d --build admin-api admin-worker
Invoke-WebRequest -UseBasicParsing http://127.0.0.1:8080/health
Invoke-WebRequest -UseBasicParsing http://127.0.0.1:8080/ready
```

可选认证 smoke：

- 登录成功拿到 access/refresh token。
- `GET /api/admin/v1/users/me` 成功。
- refresh 成功。
- logout/revoke 后旧 session 不再可用。

## 风险和回滚

风险：

1. 如果某个测试或构造 path 依赖空 `TokenConfig`，可能出现默认值归一化遗漏。
2. 如果文档没有同步，用户可能继续在本地 env 加旧 key，以为仍生效。
3. 如果有人之前用非默认 `TOKEN_REDIS_PREFIX`，改成忽略 env 后，旧 Redis cache 不再命中；但 MySQL `user_sessions` 仍是真相源，正常请求会重新回写默认 prefix cache。

回滚：

- 恢复 `config.Load()` 对三个 env 的读取。
- 恢复 Docker-first env example 三个 key。
- 不涉及 DB 回滚。

## 验收标准

1. Docker-first env 删除 `TOKEN_REDIS_PREFIX`、`TOKEN_SESSION_CACHE_TTL`、`TOKEN_SINGLE_SESSION_POINTER_TTL`。
2. 旧 env 残留时不影响运行时默认值。
3. 默认 Redis key prefix 仍为 `token:`，session cache TTL 仍为 `30m`，single-session pointer TTL 仍为 `720h`。
4. `APP_SECRET` 和 `TOKEN_REDIS_DB` 仍保留 env。
5. 不新增 `system_settings` 行，不新增 migration。
6. 后端相关测试、`docker compose config --quiet`、治理检查通过。
