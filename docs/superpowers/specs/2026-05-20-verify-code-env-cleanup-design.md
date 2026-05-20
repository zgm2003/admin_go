# Verify Code env 残留清理与前缀内置设计

日期：2026-05-20
状态：draft
范围：`admin_back_go` 的 auth verify-code 运行时配置、Docker-first env 模板、相关配置测试与状态文档

## 目标

这次只做 **verify_code env 清理**，不重新迁移 TTL，也不扩展到其他模块。

要达到的结果：

1. `VERIFY_CODE_TTL` 从 Docker-first env 和 env example 中删除，避免用户误以为改 env 会影响验证码有效期。
2. `VERIFY_CODE_REDIS_PREFIX` 不再暴露为 env，统一内置为代码常量 `auth:verify_code:`。
3. `auth.verify_code.ttl_minutes` 继续作为验证码有效期的唯一业务配置来源。
4. 邮件验证码、短信验证码、用户安全验证码共用同一个 Redis key 规则，行为不变。
5. env 继续收短，只保留部署拓扑、连接、密钥和真正需要按环境变更的参数。

## 当前事实

- `auth.verify_code.ttl_minutes` 已经存在于 `system_settings`，默认值为 `5`。
- 邮件模块和短信模块已经通过系统设置读写这个共享 TTL。
- `auth/send-code` 运行时已经通过 `VerifyCodePolicyProvider` 从 `system_settings.auth.verify_code.ttl_minutes` 读取 TTL。
- `admin-go.env` 和 `admin-go.env.example` 仍保留 `VERIFY_CODE_TTL=5m`，但当前配置结构已经没有读取该值。
- `VERIFY_CODE_REDIS_PREFIX=auth:verify_code:` 仍由 `config.VerifyCode.RedisPrefix` 从 env 读取，再注入 auth/user 服务。
- `auth:verify_code:` 是缓存命名空间，不是业务策略；它和 captcha 的 `captcha:slide:` 一样适合代码内置。

## 选型

### 方案 A：只清理残留 TTL，保留 prefix env

优点：

- 改动最小。

缺点：

- env 仍暴露实现命名空间。
- 用户会继续看到一个基本不该改的内部参数。
- 和刚完成的 captcha prefix 内置口径不一致。

### 方案 B：删除残留 TTL，并内置 prefix（推荐）

优点：

- 语义最干净：TTL 是业务策略，进系统设置；prefix 是实现常量，进代码。
- env 明显变短。
- 和 captcha 模块的新口径一致。
- 对外 API、登录流程、邮件/短信配置页都不需要变化。

缺点：

- 如果未来真要变更 Redis 命名空间，需要发版或做一次数据迁移，而不是改 env。

### 方案 C：把 prefix 也做成 system setting

不采用。

原因：

- Redis key namespace 不是后台运营配置。
- 后台可改会引入缓存孤岛和验证码突然失效问题。
- 对普通用户没有价值。

## 推荐设计

### 1. TTL 保持现状

验证码有效期继续使用：

- `auth.verify_code.ttl_minutes`

默认值：

- `5`

备注：

- `验证码有效期分钟数，邮件和短信共用`

实现阶段不新增 TTL migration。只需要确保 env、文档和测试不再暗示 `VERIFY_CODE_TTL` 有效。

### 2. Redis prefix 内置

将 `auth:verify_code:` 作为 auth 模块代码常量使用。

预期结果：

- `config.VerifyCodeConfig` 可以删除。
- `Load()` 不再读取 `VERIFY_CODE_REDIS_PREFIX`。
- bootstrap 不再从 `cfg.VerifyCode.RedisPrefix` 注入 prefix。
- auth service 和 user service 继续使用同一个内置 prefix。

### 3. Docker-first env 收口

从以下文件删除：

- `admin_back_go/deploy/docker-first/admin-go.env`
- `admin_back_go/deploy/docker-first/admin-go.env.example`

删除键：

- `VERIFY_CODE_TTL`
- `VERIFY_CODE_REDIS_PREFIX`

### 4. 行为保持

不改变以下行为：

- `POST /api/admin/v1/auth/send-code`
- 邮箱验证码发送
- 手机验证码固定 `123456` 的当前策略
- 忘记密码、验证码登录、绑定/换绑邮箱/手机号、验证码改密
- `system_settings.auth.verify_code.ttl_minutes`
- 邮件/短信配置页里的共享验证码有效期字段

## 迁移范围

### 需要改

- `admin_back_go/internal/config/config.go`
- `admin_back_go/internal/config/config_test.go`
- `admin_back_go/internal/bootstrap/app.go`
- `admin_back_go/internal/module/auth/*`
- `admin_back_go/internal/module/user/*`
- `admin_back_go/deploy/docker-first/admin-go.env`
- `admin_back_go/deploy/docker-first/admin-go.env.example`
- `docs/status/current-status.md`
- 相关部署文档中若仍出现 `VERIFY_CODE_TTL` / `VERIFY_CODE_REDIS_PREFIX`，同步删除或改写

### 不改

- `auth.verify_code.ttl_minutes` 的 key 名和值域
- `database/migrations/20260514_verify_code_ttl_policy.sql`
- 邮件模块配置表结构
- 短信模块配置表结构
- 前端系统设置页结构
- 前端邮件/短信页面结构
- CAPTCHA 模块
- token/session 配置

## 验证标准

实施后至少满足：

1. `admin-go.env` 和 `admin-go.env.example` 不再出现 `VERIFY_CODE_TTL` / `VERIFY_CODE_REDIS_PREFIX`。
2. 代码中不再通过 env 读取 `VERIFY_CODE_REDIS_PREFIX`。
3. `auth.verify_code.ttl_minutes` 仍是唯一的验证码 TTL 业务配置来源。
4. 发送验证码时 Redis key 仍保持 `auth:verify_code:<account_type>:<scene>:<hash>` 规则。
5. 用户安全模块校验验证码时和 auth 发送验证码使用同一套 key 规则。
6. 现有验证码登录、忘记密码、账户安全验证码测试继续通过。

## 测试要求

实现阶段至少跑：

- `go test -count=1 ./internal/module/auth ./internal/module/user ./internal/bootstrap ./internal/config`
- `go test -count=1 ./internal/module/mail ./internal/module/sms`
- `git diff --check`
- `powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working`

如果同时重启 Docker 后端，再补：

- `docker compose config --quiet`
- `/health`
- `/ready`
- 一次 `auth/send-code` 或相关 smoke

## 风险

- 老部署如果依赖自定义 `VERIFY_CODE_REDIS_PREFIX`，升级后会回到内置 `auth:verify_code:`；当前 Docker-first env 使用默认值，不涉及数据迁移。
- 删除 `VERIFY_CODE_TTL` 后，仍要通过系统设置改验证码有效期；文档必须写清楚，避免用户继续找 env。
- prefix 内置后不支持运行时热改，这是有意设计，用来避免缓存命名空间被误改。
