# Admin Auth Foundation v2 and APP_SECRET Design

日期：2026-05-13  
范围：`admin_back_go` 登录态、双令牌、密钥配置、secretbox、JWT access token 基础设计  
状态：design for review

## Linus 三问

### 1. 这是个真问题，还是臆想出来的？

是真问题。

当前系统已经有登录、session、refresh、踢下线、单点登录、最大会话数、Redis session cache、用户会话管理、WebSocket cookie token upgrade 等真实运行路径。继续在 `TOKEN_PEPPER`、`VAULT_KEY` 两个 env 上各自扩展，会让后续 JWT、OAuth2/OIDC、分布式 session、secret rotation 全部变成特殊情况。

更糟的是，当前本地 `.env` 里 `TOKEN_PEPPER` 和 `VAULT_KEY` 填的是同一段值。表面上是“一个密钥”，实际是两个配置项复用同一段 raw secret。这个味道不好：配置复杂度没降下来，密码学用途又混在一起。

本次要解决的真问题是：

```text
单 admin 系统只让部署者维护一个根密钥；
代码内部按用途派生不同 key；
把 access token 明确升级为 JWT codec；
保留 refresh token opaque + user_sessions 真相源；
一次性丢掉未上线阶段的旧 token/session 兼容负担。
```

### 2. 有更简单的做法吗？

有。不要上完整 OAuth2 server，不要引入 gin JWT middleware 接管认证，不要同时长期支持 opaque access 和 JWT access 两套登录态。

最简单、干净、能扩展的方案是：

```text
APP_SECRET 是唯一 root secret；
internal/platform/secretkey 负责 HKDF 派生；
JWT 只做 access token 编码格式；
refresh token 继续 opaque random；
user_sessions 仍是登录态真相源；
Redis 仍只做 cache/revoke/single-session pointer；
AuthToken middleware 仍由项目控制，不交给第三方黑盒。
```

### 3. 会破坏什么吗？

会，且本设计明确接受这些破坏。

项目没上线，可以一次性清干净：

```text
旧 access token 全部失效；
旧 refresh token 全部失效；
旧 Redis token/session key 可清空；
旧 user_sessions active rows 可视为失效或重建；
如果删除 VAULT_KEY 并切换 secretbox 派生 key，旧数据库密文字段会无法解密。
```

这不是 bug，是本次地基重打的成本。

但不能破坏这些对外契约：

```text
前端仍拿 access_token / refresh_token 字段；
前端仍用 Authorization: Bearer <access_token>；
刷新接口仍提交 refresh_token；
用户会话列表仍不返回 token hash；
RBAC、菜单、操作日志、WebSocket envelope 不因为 token 格式变化而变。
```

## 当前证据

### 当前 env 事实

当前真实配置读取点：

```text
admin_back_go/internal/config/config.go
  TokenConfig.Pepper       <- TOKEN_PEPPER
  SecretboxConfig.Key      <- VAULT_KEY

admin_back_go/.env
  TOKEN_PEPPER=...
  VAULT_KEY=...
```

当前 `.env` 里二者填的是同一段值。这说明用户的真实需求不是“两种密钥”，而是“一个系统只维护一条根密钥”。

### 当前 token 事实

当前 access/refresh 都是 opaque random token：

```text
internal/module/session/service.go
  签发 access_token 和 refresh_token
  HashToken(token, pepper)
  写入 user_sessions.access_token_hash / refresh_token_hash

internal/module/session/token.go
  sha256(token + "|" + pepper)
```

影响：

```text
TOKEN_PEPPER 改变只会让旧 token hash 不再匹配。
这会让旧登录全部失效，但不会破坏业务数据。
```

### 当前 secretbox 事实

当前敏感业务配置用 `secretbox` 加密：

```text
internal/platform/secretbox/secretbox.go
  key -> sha256 -> AES-GCM key

调用方包括：
  ai_providers.api_key_enc
  upload_driver.secret_id_enc / secret_key_enc
  payment_channels.private_key_enc
  client version manifest COS secret
  export task COS secret
```

影响：

```text
VAULT_KEY 改变会导致旧密文无法解密。
如果数据库里已有必须保留的 AI key、上传配置、支付私钥，要么迁移密文，要么重新录入。
```

本次用户已明确项目未上线、可随意折腾、单 admin 系统、不做 SaaS。本设计按“纯净重来”处理，不做 legacy vault 兼容窗口。

## 目标

1. `admin_back_go` 只暴露一个根密钥配置：`APP_SECRET`。
2. 内部通过 HKDF-SHA256 派生用途密钥，禁止 raw secret 在不同用途间直接复用。
3. Access token 升级为 JWT，但 JWT 只作为 codec，不接管 session 真相源。
4. Refresh token 保持 opaque random，支持 refresh rotation 和 session policy。
5. `user_sessions` 继续作为登录态、踢下线、单点登录、最大会话数、平台/device/IP policy 的真相源。
6. Redis 继续作为缓存和撤销辅助，不作为唯一登录态真相源。
7. 当前未上线阶段允许破坏旧 token/session 和旧密文兼容，换取长期简单性。
8. 为后续 OAuth2/OIDC、分布式部署、密钥轮换留下干净接口，但不在本 slice 实现完整 OAuth2/OIDC。

## 非目标

本次不做：

```text
不实现 OAuth2 authorization server；
不实现 OIDC discovery / JWKS endpoint；
不接入第三方登录；
不采用 gin JWT middleware 接管 AuthToken；
不采用 cookie session package 替代 user_sessions；
不做多租户/tenant secret；
不支持长期双 access token 格式；
不做旧 VAULT_KEY 密文自动迁移；
不改变前端登录接口字段名；
不改变 RBAC/menu/operation-log contract。
```

## 推荐方案

### 1. 配置收口

新的运行时配置：

```env
# Application root secret. Single admin deployment only.
# Used only as root material; code derives purpose-specific keys internally.
APP_SECRET=change_me_to_at_least_64_random_chars
```

删除或废弃：

```env
TOKEN_PEPPER=
VAULT_KEY=
```

规则：

```text
本项目新 runtime 必须配置 APP_SECRET；
APP_SECRET 为空或明显默认值，API/worker 启动失败；
TOKEN_PEPPER 和 VAULT_KEY 不再作为新配置入口；
.env.example、deployment docs、contract docs 全部改成 APP_SECRET；
如果本地 .env 还残留 TOKEN_PEPPER/VAULT_KEY，代码不依赖它们。
```

### 2. 内部密钥派生

新增内部平台包建议命名：

```text
internal/platform/secretkey
```

职责：

```text
读取 config.App.Secret；
校验 root secret 安全性；
使用 HKDF-SHA256 派生用途 key；
向各模块返回用途明确的 []byte/string，不泄露 root secret；
提供测试向量，保证同一 APP_SECRET 派生结果稳定。
```

派生标签固定：

```text
admin_go:secretbox:v1
admin_go:token-pepper:v1
admin_go:jwt-signing:v1
admin_go:session-cache:v1
```

建议实现语义：

```text
secretbox key: 32 bytes，供 AES-GCM 使用；
token pepper: hex/base64 string，供 refresh token hash 使用；
jwt signing key: 32 bytes，供 HS256 或 HS512 JWT 签名使用；
session-cache key: 预留给后续 Redis payload 签名或加密，不在本 slice 强制启用。
```

为什么不是一段 raw secret 到处用：

```text
用户只维护一个 APP_SECRET；
代码内部每个用途都有独立派生 key；
未来某个用途换算法，不污染其他用途；
审计时能看懂 key 的边界。
```

### 3. Secretbox v2

`secretbox` 从“接收 raw VAULT_KEY string 并 sha256”改为“接收 32-byte purpose key”。

新边界：

```text
secretbox.New(key []byte)
secretbox 不知道 APP_SECRET；
secretbox 不读 env；
secretbox 不负责 HKDF；
bootstrap 负责把派生后的 secretbox key 注入进去。
```

旧密文策略：

```text
本设计不兼容旧 VAULT_KEY 密文；
开发库里的 AI key、上传 secret、支付私钥需要重新录入；
如果后续发现必须保留真实密文，另开一次性 migration spec，不污染主路径。
```

错误信息也要改干净：

```text
旧：secretbox: VAULT_KEY is not configured
新：secretbox: key is not configured
```

### 4. Access token codec

新增 AccessTokenCodec 抽象，避免 AuthToken middleware 和 session service 直接绑死 JWT 库：

```go
type AccessTokenClaims struct {
    SessionID int64
    UserID    int64
    Platform  string
    DeviceID  string
    IssuedAt  time.Time
    ExpiresAt time.Time
}

type AccessTokenCodec interface {
    Issue(AccessTokenClaims) (string, error)
    Parse(token string) (AccessTokenClaims, error)
}
```

首个实现：

```text
internal/platform/token/jwtcodec
library: github.com/golang-jwt/jwt/v5
algorithm: HS256 or HS512, key from HKDF(APP_SECRET, "admin_go:jwt-signing:v1")
```

采用 `golang-jwt/jwt/v5` 作为 codec library，不采用 gin middleware。

JWT claims 最小化：

```text
sub: user id
sid: session id
platform: admin/app
device_id: request device id
iat / exp / nbf
iss: admin_go
```

禁止塞入：

```text
role list
permission list
menu
password/version hash
API key
tenant id
任何前端可变授权事实
```

理由：权限、角色、菜单都应该从服务端事实源读取。JWT 只证明“这个 access token 是我们签的、属于哪个 session、什么时候过期”。

### 5. Refresh token 仍是 opaque

Refresh token 不改成 JWT。

规则：

```text
refresh_token 仍为 crypto/rand 生成的随机串；
数据库只存 refresh_token_hash；
hash 使用派生出来的 token pepper；
refresh 时执行 rotation：旧 refresh hash 失效，新 access JWT + 新 refresh opaque 写回；
logout/revoke/kick 仍按 user_sessions 修改 revoked_at 并清 Redis cache。
```

这不是“两套协议混乱”，而是成熟双令牌模型：

```text
access token: 短生命周期、可自校验签名、减少缓存查验成本；
refresh token: 长生命周期、高价值、必须服务端可撤销、只存 hash。
```

### 6. Session 真相源不变

`user_sessions` 继续是登录态事实源。

JWT parse 通过后仍要校验 session 状态：

```text
session id 存在；
user id 匹配；
platform 匹配；
revoked_at 为空；
access_expires_at / refresh_expires_at 未过期；
session policy 仍有效。
```

性能路径：

```text
AuthToken middleware parse JWT -> 得到 sid/user/platform；
Session Authenticator 先查 Redis session snapshot；
Redis miss 再查 MySQL user_sessions + user 状态；
撤销/踢下线/refresh rotation 主动删旧 cache。
```

这保持了当前项目已有能力：

```text
单点登录；
最大会话数；
踢下线；
用户会话列表；
当前会话保护；
WebSocket upgrade 鉴权；
分布式多 API 节点共享 Redis/MySQL。
```

### 7. Redis key 和缓存策略

保留当前 Redis DB 和 prefix 配置：

```env
TOKEN_REDIS_PREFIX=token:
TOKEN_REDIS_DB=2
TOKEN_SESSION_CACHE_TTL=30m
TOKEN_SINGLE_SESSION_POINTER_TTL=720h
```

但缓存 key 从 access token hash 过渡为 session-oriented key：

```text
token:session:<sid>
token:user-platform-device:<user_id>:<platform>:<device_id>
```

原因：JWT access token 每次 refresh 会变，session id 才是稳定主体。缓存围绕 session，而不是围绕 access raw token，可以减少特殊情况。

如果实现阶段为了降低改动，可以先保留 access hash cache，但最终目标是 session key。

### 8. OAuth2/OIDC 预留边界

本次不实现 OAuth2/OIDC，但要把将来扩展位置留对：

```text
AccessTokenCodec 是 token 格式边界；
SessionService 是登录态生命周期边界；
AuthToken middleware 是 bearer/cookie 提取边界；
IdentityProvider 后续可作为登录入口，不替代 user_sessions；
OAuth2 callback 成功后，仍创建 user_sessions 并签发本系统双令牌。
```

未来接第三方登录时，不允许第三方 access token 直接成为本系统 admin access token。

## API contract 影响

对前端保持字段不变：

```json
{
  "access_token": "jwt string",
  "refresh_token": "opaque random string",
  "token_type": "Bearer",
  "expires_in": 7200
}
```

刷新接口不变：

```http
POST /api/admin/v1/auth/refresh
Content-Type: application/json

{"refresh_token":"..."}
```

请求鉴权不变：

```http
Authorization: Bearer <access_token>
```

WebSocket cookie token 兼容策略：

```text
仍只允许显式 GET/HEAD upgrade path 使用 cookie access_token；
cookie 里放的是 JWT access token；
AuthToken middleware 不扩大 cookie 鉴权范围。
```

错误语义建议：

```text
JWT 签名错误 / 格式错误 -> 401 token无效
JWT exp 过期 -> 401 token已过期
session revoked/missing -> 401 登录已失效
permission denied -> 403 无权限
```

## Open-source 取舍

采用：

```text
github.com/golang-jwt/jwt/v5
  只作为 JWT encode/decode library。

golang.org/x/crypto/hkdf
  用于 APP_SECRET 派生用途密钥。
```

不采用：

```text
gin JWT middleware
  因为它会接管 AuthToken 主链路，破坏 user_sessions / RBAC / OperationLog 边界。

gin sessions / cookie session
  因为 admin 登录态必须服务端可撤销、可踢下线、可列会话。

完整 OAuth2 server package
  因为当前真需求不是给第三方客户端授权，而是先把 admin 登录地基打干净。
```

## 数据与迁移策略

由于项目未上线，本次采用破坏性清理策略：

```text
1. 部署前配置 APP_SECRET。
2. 清理 Redis token/session cache。
3. 旧 user_sessions active rows 不再保证可用，可删除或让其自然失效。
4. 旧 secretbox 密文不迁移；需要的 AI/upload/payment secret 重新在后台录入。
```

建议提供可选 SQL / runbook，而不是自动隐藏迁移：

```sql
UPDATE user_sessions SET revoked_at = NOW() WHERE revoked_at IS NULL;
```

不要在启动时偷偷改数据库。启动逻辑只校验配置，不做隐式数据迁移。

## 实现边界建议

后续 plan 应拆成这些小步，不要一坨改完：

```text
1. Config: 新增 APP_SECRET，删除 TOKEN_PEPPER/VAULT_KEY 读取依赖。
2. secretkey: 实现 HKDF 派生和测试向量。
3. secretbox: 改为注入派生 key，更新错误和测试。
4. jwtcodec: 引入 golang-jwt/jwt/v5，签发/解析最小 claims。
5. session service: login/refresh 签发 JWT access + opaque refresh。
6. authenticator: parse JWT，按 sid/user/platform 校验 user_sessions 和 Redis cache。
7. Redis/cache: 明确 session-oriented key，清理旧 access hash 思维。
8. docs/env: .env、.env.example、deployment、contract、architecture 全部同步。
9. verification: go test/vet/contract/basic smoke/full smoke。
```

如果某一步导致 scope 失控，应先停下，不要硬塞到一个 commit 里。

## 验收标准

### 配置验收

```text
.env 只需要 APP_SECRET 一个根密钥；
.env.example 不再要求 TOKEN_PEPPER/VAULT_KEY；
APP_SECRET 缺失或默认值时 API/worker 启动失败；
错误信息指向 APP_SECRET，不再提示 VAULT_KEY/TOKEN_PEPPER。
```

### Token 验收

```text
登录返回 access_token 是 JWT 格式；
登录返回 refresh_token 仍是 opaque random；
数据库不存 access token 明文，不存 refresh token 明文；
refresh 后旧 refresh token 不可再次使用；
logout/revoke/kick 使对应 session 的 JWT access token 失效；
JWT 里不包含角色、权限、菜单或任何 secret。
```

### Session 验收

```text
用户会话列表可正常显示；
当前会话不能被自己误踢；
单点登录和最大会话数策略继续生效；
Redis miss 时能从 MySQL 恢复 session snapshot；
多 API 节点共享 MySQL/Redis 时行为一致。
```

### Secretbox 验收

```text
AI provider API key 写入后可解密使用；
上传配置 secret 写入后可签发 STS；
支付私钥写入后可创建支付请求；
响应、OperationLog、smoke 输出不泄露 plaintext 或 encrypted secret。
```

### 文档验收

```text
docs/contracts/admin-api-v1.md 同步 access token 为 JWT、refresh token 为 opaque；
docs/deployment/production.md 同步 APP_SECRET；
docs/architecture/06-admin-middleware-selection.md 同步 Auth Foundation v2 方向；
README / .env.example 不再教用户配置两个密钥。
```

## 验证命令

后续实现完成前，至少运行：

```powershell
cd E:/admin_go/admin_back_go
go mod tidy -diff
go test ./...
go vet ./...
powershell -ExecutionPolicy Bypass -File .\scripts\check-contract.ps1
git diff --check
```

触碰登录态和 middleware 后，还必须运行：

```powershell
cd E:/admin_go
powershell -ExecutionPolicy Bypass -File .\scripts\basic-admin-smoke.ps1 -Account 15671628271 -Password 123456
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account 15671628271 -Password 123456
```

没有这些证据，不准说完成。

## 设计结论

最终路线：

```text
一个配置密钥：APP_SECRET
多用途内部派生：HKDF-SHA256
access token：JWT
refresh token：opaque random
session 真相源：user_sessions
缓存/撤销/单点指针：Redis
认证入口：项目 AuthToken middleware，不交给第三方黑盒
```

这比 `VAULT_KEY` + `TOKEN_PEPPER` 两个配置项填同一个值更干净，也比“直接上 gin JWT middleware”更符合当前 admin 系统的真实能力。
