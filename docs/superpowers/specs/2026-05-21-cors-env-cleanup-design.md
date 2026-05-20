# CORS env 收口设计

日期：2026-05-21
状态：draft
范围：`admin_back_go` CORS 配置、WebSocket Origin 白名单复用、Docker-first env 模板、相关文档和测试

## 目标

这次只做 **CORS env cleanup**，不重做认证、前端部署、网关/Nginx 配置、WebSocket 协议，也不把 CORS 做成后台可编辑页面。

要达到的结果：

1. Docker-first env 只保留部署者必须按域名/环境填写的 CORS 项。
2. `CORS_ALLOW_HEADERS`、`CORS_ALLOW_CREDENTIALS`、`CORS_MAX_AGE` 改为代码内置默认值。
3. `CORS_ALLOW_ORIGINS` 继续保留 env，不迁入 `system_settings`。
4. 不新增 SQL/migration，不新增系统设置 key。
5. 保持当前默认行为不变：本地开发 origin 默认允许，允许认证凭证，预检缓存 `12h`，常用前端请求头继续允许。
6. 保持 WebSocket Origin 校验继续复用同一份 CORS origin 白名单。

## Linus 三问

1. 这是真问题吗？
   - 是。当前 Docker-first env 暴露 4 个 CORS 项，其中 3 个是协议层固定策略，不是普通部署用户应该日常调整的业务配置。它们让 env 变长，也容易让用户误以为每次部署都要理解和调整浏览器 CORS 细节。
2. 有更简单的做法吗？
   - 有。只保留 `CORS_ALLOW_ORIGINS`，因为它确实跟部署域名相关；headers、credentials、max age 由代码默认值和测试守住。
3. 会破坏已有前端、接口、登录和权限吗？
   - 不应该。认证 token、RBAC、API 路由、前端请求封装都不变；只改变 3 个 CORS 默认值来源。需要重点验证 OPTIONS 预检、带 `Authorization/platform/device-id/X-Request-Id` 的跨域请求，以及 WebSocket Origin 校验。

## 当前事实

Docker-first env 当前暴露：

```env
CORS_ALLOW_ORIGINS=http://localhost:5173,http://127.0.0.1:5173,https://zgm2003.cn
CORS_ALLOW_HEADERS=Origin,Content-Type,Accept,Authorization,platform,device-id,X-Trace-Id,X-Request-Id
CORS_ALLOW_CREDENTIALS=true
CORS_MAX_AGE=12h
```

当前代码读取位置：

- `internal/config.Load()` 先构造 `DefaultCORSConfig()`，再读取 `CORS_ALLOW_ORIGINS`、`CORS_ALLOW_HEADERS`、`CORS_ALLOW_CREDENTIALS`、`CORS_MAX_AGE` 覆盖默认值。
- `internal/server/router.go` 把 `cfg.CORS` 传给 `middleware.CORS`，最终使用 `github.com/gin-contrib/cors`。
- `internal/bootstrap/app.go` 创建 realtime stack 时把 `cfg.CORS.AllowOrigins` 传给 WebSocket Origin 校验。
- `DefaultCORSConfig()` 当前默认：
  - origins：`http://localhost:5173`、`http://127.0.0.1:5173`
  - methods：`GET, POST, PUT, PATCH, DELETE, OPTIONS`
  - headers：`Origin, Content-Type, Accept, Accept-Language, Authorization, platform, device-id, X-Trace-Id, X-Request-Id`
  - expose headers：`X-Request-Id`
  - credentials：`true`
  - max age：`12h`

这 4 个 env 可以分成两类：

| env key | 当前含义 | 判断 | 目标 |
| --- | --- | --- | --- |
| `CORS_ALLOW_ORIGINS` | 允许访问 API 的浏览器 origin 白名单；WebSocket Origin 也复用它 | 部署域名/环境相关，生产必须显式配置 | 保留 env |
| `CORS_ALLOW_HEADERS` | 允许跨域请求携带的请求头 | 前后端 API 协议固定能力，不是业务配置 | 内置默认 headers |
| `CORS_ALLOW_CREDENTIALS` | 是否允许跨域携带凭证 | 当前认证和前端请求模型的固定策略 | 内置 `true` |
| `CORS_MAX_AGE` | 浏览器预检缓存时长 | 技术默认值，普通用户不该日常调整 | 内置 `12h` |

## 选型

### 方案 A：全部迁到 `system_settings`

不推荐。

原因：

- CORS 是浏览器访问 API 的入口安全边界，不是后台业务策略。
- 如果 CORS 配错，后台系统设置页面本身可能打不开，形成“需要进后台修 CORS，但 CORS 阻止进入后台”的自锁。
- WebSocket Origin 也复用同一份 origin 白名单；DB 配置会让启动期和 realtime 栈初始化更复杂。
- `system_settings` 更适合验证码 TTL、上传 token TTL 等业务可调策略，不适合 API 网关级跨域边界。

### 方案 B：继续保留 4 个 env

不采用。

原因：

- Docker-first env 继续变长，违背“只让部署用户改必要项”的方向。
- `CORS_ALLOW_HEADERS`、`CORS_ALLOW_CREDENTIALS`、`CORS_MAX_AGE` 对普通部署者没有业务意义。
- headers 作为 env 还可能落后于代码真实需求，例如当前代码默认已经包含 `Accept-Language`，但 Docker-first env 示例没有包含它。

### 方案 C：只保留 `CORS_ALLOW_ORIGINS`，其余代码内置（推荐）

内容：

Docker-first env 保留：

```env
CORS_ALLOW_ORIGINS=https://zgm2003.cn
```

代码内置：

```text
AllowHeaders = Origin,Content-Type,Accept,Accept-Language,Authorization,platform,device-id,X-Trace-Id,X-Request-Id
AllowCredentials = true
MaxAge = 12h
```

优点：

- env 一次减少 3 个键。
- 保留真正部署相关的 origin 白名单。
- 默认行为不变。
- 不新增 DB/system_settings 依赖。
- headers 默认值由测试跟 API 请求头需求一起维护，避免 env 示例漏字段。

缺点：

- 极少数高级部署如果确实要改 CORS headers 或 max age，不能再只改 Docker-first env；应另开“高级 CORS policy”设计，而不是在普通 Docker-first env 里继续暴露。

推荐采用。

## 推荐设计

### 1. Docker-first env 只保留 CORS origin 白名单

最终 Docker-first env 的 CORS 部分变为：

```env
# Comma-separated browser origins allowed to call the API and open WebSocket connections.
# Keep production domains explicit. Local dev origins are code defaults when this env is omitted.
CORS_ALLOW_ORIGINS=https://zgm2003.cn
```

删除：

```env
CORS_ALLOW_HEADERS=Origin,Content-Type,Accept,Authorization,platform,device-id,X-Trace-Id,X-Request-Id
CORS_ALLOW_CREDENTIALS=true
CORS_MAX_AGE=12h
```

说明：

- 生产部署必须显式填写真实前端 origin，例如 `https://zgm2003.cn`。
- 本地 ignored 的 `admin-go.env` 可以临时包含 `http://localhost:5173,http://127.0.0.1:5173`，用于本机前后端联调。
- 如果完全不设置 `CORS_ALLOW_ORIGINS`，代码默认只允许 Vite 本地开发 origin `http://localhost:5173` 和 `http://127.0.0.1:5173`；这只是开发默认，不等于生产推荐。

### 2. CORS headers / credentials / max age 代码内置

`internal/config.Load()` 目标只读取：

```text
CORS_ALLOW_ORIGINS
```

不再读取：

```text
CORS_ALLOW_HEADERS
CORS_ALLOW_CREDENTIALS
CORS_MAX_AGE
```

即使旧部署残留这些 env，代码也应该忽略，避免残留 env 继续改变行为。

内置默认保持：

```text
AllowMethods     = GET,POST,PUT,PATCH,DELETE,OPTIONS
AllowHeaders     = Origin,Content-Type,Accept,Accept-Language,Authorization,platform,device-id,X-Trace-Id,X-Request-Id
ExposeHeaders    = X-Request-Id
AllowCredentials = true
MaxAge           = 12h
```

### 3. 不进 `system_settings`

本切片不新增：

```text
cors.allow_origins
cors.allow_headers
cors.allow_credentials
cors.max_age
```

理由：

- CORS 是入口安全边界，应该由部署配置/代码默认控制。
- 后台可编辑 CORS 容易自锁后台访问。
- `system_settings` 读取依赖 DB；CORS middleware 和 WebSocket Origin 校验属于更早的请求入口层，不应为了这些固定默认值增加 DB 依赖。

### 4. WebSocket Origin 继续复用 `CORS_ALLOW_ORIGINS`

不改变 realtime/WebSocket 设计：

- `cfg.CORS.AllowOrigins` 继续传入 realtime stack。
- 浏览器 WebSocket Origin 校验与 HTTP CORS origin 白名单保持一致。
- 空 Origin / 同 host upgrade 的既有行为不在本切片调整。

这点很重要：`CORS_ALLOW_ORIGINS` 保留 env，不只是 HTTP CORS，也是 WebSocket 浏览器来源白名单。

### 5. 运行时行为不变

不改：

- API 路由和认证中间件顺序。
- JWT / refresh token / session 逻辑。
- 前端请求头约定：`Authorization`、`platform`、`device-id`、`X-Trace-Id`、`X-Request-Id`、`Accept-Language`。
- `OPTIONS` 预检响应语义。
- `Access-Control-Allow-Credentials: true` 默认策略。
- `Access-Control-Max-Age: 43200` 等价于 `12h`。
- WebSocket Origin 白名单来源。

## 测试设计

### 单元测试

更新 `internal/config` 测试：

1. 默认 CORS 只包含本地开发 origins `http://localhost:5173` 和 `http://127.0.0.1:5173`，不包含 `5174`。
2. 默认 allowed headers 仍包含：
   - `Origin`
   - `Content-Type`
   - `Accept`
   - `Accept-Language`
   - `Authorization`
   - `platform`
   - `device-id`
   - `X-Trace-Id`
   - `X-Request-Id`
3. 默认 `AllowCredentials=true`。
4. 默认 `MaxAge=12h`。
5. `CORS_ALLOW_ORIGINS` env 仍可覆盖 origin 白名单。
6. 旧 env `CORS_ALLOW_HEADERS`、`CORS_ALLOW_CREDENTIALS`、`CORS_MAX_AGE` 被忽略，不能改变默认 headers/credentials/max age。

更新 `internal/middleware` 或现有 router 测试：

1. 允许白名单 origin 的 OPTIONS 预检。
2. 预检响应包含代码内置 headers。
3. 非白名单 origin 不应得到允许响应。

### Docker/runtime 验证

实现后至少执行：

```powershell
cd E:\admin_go\admin_back_go
go test -count=1 ./internal/config ./internal/middleware ./internal/server ./internal/bootstrap

go vet ./internal/config ./internal/middleware ./internal/server ./internal/bootstrap
```

Docker-first 验证：

```powershell
cd E:\admin_go\admin_back_go\deploy\docker-first
docker compose config --quiet
docker compose up -d --build admin-api admin-worker
docker compose ps
curl.exe -sS http://127.0.0.1:8080/health
curl.exe -sS http://127.0.0.1:8080/ready
```

CORS 预检 smoke：

```powershell
curl.exe -i -X OPTIONS "http://127.0.0.1:8080/api/v1/auth/login" `
  -H "Origin: http://localhost:5173" `
  -H "Access-Control-Request-Method: POST" `
  -H "Access-Control-Request-Headers: authorization,platform,device-id,x-request-id,accept-language"
```

期望看到：

```text
Access-Control-Allow-Origin: http://localhost:5173
Access-Control-Allow-Credentials: true
Access-Control-Allow-Headers: ...Accept-Language...Authorization...platform...device-id...X-Request-Id...
Access-Control-Max-Age: 43200
```

治理验证：

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

### 不做的测试

- 不做浏览器兼容性矩阵。
- 不做 Nginx/宝塔面板 CORS 注入测试；本切片只负责 Go API 自身 CORS middleware。
- 不做登录账号 smoke，除非当前环境提供 `SMOKE_LOGIN_ACCOUNT` / `SMOKE_LOGIN_PASSWORD`。

## 文档同步

需要同步：

- `admin_back_go/deploy/docker-first/admin-go.env.example`
- 本地 ignored `admin_back_go/deploy/docker-first/admin-go.env`
- `admin_back_go/README.md`
- `admin_back_go/docs/architecture.md`
- `docs/contracts/admin-api-v1.md` 如其中列了 CORS env 契约
- `docs/status/current-status.md` 如其中列了 Docker-first env 当前事实

文档口径：

```text
CORS_ALLOW_ORIGINS is the only Docker-first CORS env.
CORS headers, credentials, exposed headers, and max age are code-owned defaults.
Do not store CORS policy in system_settings.
```

## 风险与回滚

风险：

1. 某个前端新增请求头但代码默认 headers 没加，会导致预检失败。
   - 缓解：headers 默认值由 config/middleware 测试守住；新增前端请求头时同步 `DefaultCORSConfig()`。
2. 生产 env 如果只写 `https://zgm2003.cn`，本机 `localhost:5173` 不再允许。
   - 缓解：这是预期行为；本地联调在 ignored `admin-go.env` 加 localhost origins，或不设置 `CORS_ALLOW_ORIGINS` 使用代码开发默认。
3. 旧部署残留 `CORS_ALLOW_HEADERS` 等 env 后行为不再受它们影响。
   - 缓解：这正是收口目标；文档明确旧 env 已废弃。

回滚方式：

- 恢复 `config.Load()` 对 `CORS_ALLOW_HEADERS`、`CORS_ALLOW_CREDENTIALS`、`CORS_MAX_AGE` 的读取。
- 恢复 Docker-first env example 中删除的 3 个 key。
- 回滚相关测试和文档。

## 完成标准

- Docker-first env/example 中只剩 `CORS_ALLOW_ORIGINS` 一个 CORS key。
- 代码不再读取 `CORS_ALLOW_HEADERS`、`CORS_ALLOW_CREDENTIALS`、`CORS_MAX_AGE`。
- 旧 3 个 CORS env 即使存在也不能改变运行时 CORS headers/credentials/max age。
- `DefaultCORSConfig()` 仍包含 `Accept-Language`、`Authorization`、`platform`、`device-id`、`X-Trace-Id`、`X-Request-Id`。
- HTTP CORS middleware 和 WebSocket Origin 仍使用同一份 origin 白名单。
- 单元测试、go vet、Docker compose config、health/ready、CORS OPTIONS smoke、治理检查通过。
- 不新增 SQL/migration，不新增 `system_settings`。
