# 验证码 TTL 渠道归属收口设计

日期：2026-05-27
更新：2026-05-29
状态：approved；Go/Vue implementation landed；2026-05-29 live DB migration 已验证，basic smoke 已通过；full smoke 已覆盖 mail/sms read probes 后在既有 upload-token 配置处阻断，不能记为 full-smoke pass
范围：`admin_back_go` 的验证码 TTL 运行时策略、`mail_configs` / `sms_configs` 配置归属、`system_settings.auth.verify_code.ttl_minutes` 退场、`admin_front_ts` 邮件/短信配置页文案和契约测试、根 repo contract/status/smoke 文档。
项目角色：architect
执行角色：backend-worker 为主；触碰前端文案时由 frontend-adapter 或执行者按 frontend 规则完成最小变更。

## 目标

把验证码有效期从全局 `system_settings.auth.verify_code.ttl_minutes` 收回到真正拥有发送能力的渠道配置：

1. 邮件验证码 TTL 归属 `mail_configs.verify_code_ttl_minutes`。
2. 短信验证码 TTL 归属 `sms_configs.verify_code_ttl_minutes`。
3. 系统设置页不再暴露 `auth.verify_code.ttl_minutes`。
4. 邮件管理和短信管理互不覆盖 TTL。
5. `auth/send-code` 仍按账号类型写 Redis code，只是 TTL 改为按渠道读取。

这次只修 TTL 归属，不把手机号验证码接入真实短信发送。当前手机号验证码仍保持固定 `123456`，但 Redis 过期时间要按短信渠道 TTL 读取。

## 2026-05-29 架构重构后的修订点

旧设计方向没错，但实现细节必须按当前 multi-platform boundary 重写：

- HTTP 表面已经迁到 `internal/module/{capability}/transport/{platform}`。邮件/短信配置 request binding 归 `mail/transport/admin/request.go` 与 `sms/transport/admin/request.go`，service/model/repository 仍在 capability root。
- `internal/shared` 已经接管 `apperror` / `response` / `i18n` / `enum` / `validate` / `dict` / `setting`。但验证码 TTL 不再是 system setting；实现后不能继续让 `shared/setting` 持有 `auth.verify_code.ttl_minutes` 的运行时读写 API。
- 旧 spec 说 mail/sms 各自定义 `verifyCodeTTLSettingKey` 已经过时。2026-05-27 baseline 是 mail/sms 通过 `sharedsetting.SaveAuthVerifyCodeTTLMinutes` 写同一个全局 key，auth 通过 `SystemSettingVerifyCodePolicyProvider` 读取这个 key。
- 2026-05-27 architecture guard 还在要求 mail/sms/auth 使用 `sharedsetting.AuthVerifyCodeTTL*`。实现时必须把这个 guard 反过来：禁止 verify-code TTL 再走 `shared/setting` 或 `system_settings`。
- `auth/send-code` 同时服务 admin/app transport。改的是 auth service 的 TTL policy 选择，不改现有 admin/app URL、response shape、Redis key namespace、登录/绑定/忘记密码场景。

## 2026-05-27 实施前事实

- `docs/status/current-status.md` 当时记录邮件和短信共享 `system_settings.auth.verify_code.ttl_minutes`。
- `docs/contracts/admin-api-v1.md` 当时写明 `PUT /mail/config` 和 `PUT /sms/config` 都把 `verify_code_ttl_minutes` 保存到 `system_settings.auth.verify_code.ttl_minutes`。
- `admin_back_go/internal/module/mail/service.go` 与 `admin_back_go/internal/module/sms/service.go` 当时通过 `sharedsetting.SaveAuthVerifyCodeTTLMinutes` 写全局 key。
- `admin_back_go/internal/module/auth/verify_code_policy.go` 当时通过 `SystemSettingVerifyCodePolicyProvider` 读取全局 key。
- `mail_configs` / `sms_configs` 当时模型没有 TTL 字段。

结论：这不是 UI 展示问题，而是配置事实源归属错误。实施前邮件、短信、系统设置三个入口在改同一条全局值；2026-05-29 实现后，TTL 已按渠道回到 `mail_configs.verify_code_ttl_minutes` / `sms_configs.verify_code_ttl_minutes`，旧全局 key 退场。

## Linus 三问

1. 这是个真问题吗？
   - 是。两个独立渠道的配置页互相覆盖同一条 TTL，用户无法得到“邮件 TTL”和“短信 TTL”两个独立结果。
2. 有更简单的做法吗？
   - 最小正确做法是给两个渠道配置表各加一个字段，迁移旧全局值，删除全局读写路径。不新增验证码专页，不引入 provider framework。
3. 会破坏已有登录、权限、菜单和前端路由吗？
   - 不应该破坏。API 字段名 `verify_code_ttl_minutes` 保持不变；变的是字段落库位置和 auth TTL 读取来源。必须用 Go tests、前端 contract tests、contract/status 文档和 smoke read gate 覆盖。

## 方案比较

### 方案 A：渠道配置表分别持有 TTL（采用）

新增：

- `mail_configs.verify_code_ttl_minutes`
- `sms_configs.verify_code_ttl_minutes`

邮件配置页保存邮件 TTL，短信配置页保存短信 TTL。`auth.SendCode` 按账号类型读取对应渠道 TTL。

优点：

- 与用户心智一致：邮件管理管邮件，短信管理管短信。
- 互不覆盖。
- 保留现有 API 字段名，前端改动小。
- `system_settings` 不再变成跨模块垃圾桶。
- 符合当前 `module/{capability}/transport/{platform}` 边界。

缺点：

- 需要一次 schema migration。
- auth policy 需要按账号类型读取渠道 TTL。
- 需要改掉旧 `shared/setting` architecture guard。

### 方案 B：只隐藏 system settings 里的全局 key（拒绝）

原因：

- 只能解决“系统设置页看得到”的表象。
- 邮件配置和短信配置仍然会互相覆盖同一个全局值。
- 以后排障更隐蔽。

### 方案 C：把验证码 TTL 放到 auth_platforms（拒绝）

原因：

- `auth_platforms` 管登录方式、captcha、token/session 策略，不拥有 Tencent SES/SMS 模板变量。
- 邮件和短信发送页已经有各自配置入口，用户明确期望按渠道配置。
- 按平台配置会引出 admin/app 不同 TTL 语义，不是这次真实问题。

## 推荐设计

### 1. 数据模型

新增 migration，使用当前 migrations 里已有的 `information_schema` + prepared statement 风格保证可重复执行：

```sql
ALTER TABLE `mail_configs`
  ADD COLUMN `verify_code_ttl_minutes` INT UNSIGNED NOT NULL DEFAULT 5 AFTER `reply_to`;

ALTER TABLE `sms_configs`
  ADD COLUMN `verify_code_ttl_minutes` INT UNSIGNED NOT NULL DEFAULT 5 AFTER `endpoint`;
```

迁移规则：

1. 读取旧 `system_settings.auth.verify_code.ttl_minutes`。
2. 如果旧值是 1-60 的整数，则在新增列时回填到现有 `mail_configs` 和 `sms_configs` active rows。
3. 如果旧值缺失、禁用、非法，回填默认 5。
4. 重复执行 migration 时不能覆盖用户后来在渠道配置里改过的 TTL；只能修正非法值。
5. 最后把 `auth.verify_code.ttl_minutes` 禁用并软删除，保证系统设置列表不再展示它。

模型同步：

```go
type Config struct {
    // existing fields
    VerifyCodeTTLMinutes int `gorm:"column:verify_code_ttl_minutes"`
}
```

### 2. 邮件模块

`mail.Config` 增加 `VerifyCodeTTLMinutes int`。

`mail.SaveConfig`：

- 继续校验 TTL 1-60。
- 把 TTL 写入 `mail_configs.verify_code_ttl_minutes`。
- 不再写 `system_settings`。
- 不再依赖 `sharedsetting.SaveAuthVerifyCodeTTLMinutes` / `AuthVerifyCodeTTLMinutesOrDefault`。
- `Repository` 不再暴露 `SettingByKey` / `SaveSetting` / `InvalidateSettingCache` 这组 system-setting 方法。

`mail.Config()`：

- 已配置时返回 `row.VerifyCodeTTLMinutes`。
- 未配置时返回默认 5。

新增供 auth policy 使用的小方法：

```go
VerifyCodeTTL(ctx context.Context) (time.Duration, *apperror.Error)
```

规则：未创建邮件配置行时返回默认 5；已配置但 TTL 非法时返回配置错误。邮件 sender 凭证缺失仍由发送链路显式失败，不能被 TTL 默认值掩盖。

### 3. 短信模块

`sms.Config` 增加 `VerifyCodeTTLMinutes int`。

`sms.SaveConfig`、`sms.Config()` 与邮件模块同理。

`sms.TestSend` 使用短信配置自己的 TTL 填充模板变量 `ttl_minutes`。

新增供 auth policy 使用的小方法：

```go
VerifyCodeTTL(ctx context.Context) (time.Duration, *apperror.Error)
```

规则：未创建短信配置行时返回默认 5。这样不会破坏当前手机号固定 `123456` 的登录/绑定流程；真实 SMS provider 凭证缺失不等于 TTL 策略缺失。

### 4. Auth 运行时

把实施前无参策略：

```go
VerifyCodeTTL(ctx context.Context) (time.Duration, *apperror.Error)
```

改成按账号类型读取：

```go
VerifyCodeTTL(ctx context.Context, accountType string) (time.Duration, *apperror.Error)
```

`auth.SendCode` 在识别 `accountType` 后调用：

```go
ttl, appErr := s.verifyCodeTTL(ctx, accountType)
```

推荐实现：

```go
type ChannelVerifyCodePolicyProvider struct {
    email VerifyCodeTTLProvider
    phone VerifyCodeTTLProvider
}
```

其中 `mail.Service` 和 `sms.Service` 都通过同名方法满足 `VerifyCodeTTLProvider`。`auth` 只依赖小接口，不 import mail/sms，不 import Tencent SDK，也不直接调用渠道发送细节。

缺失 email/phone provider 是 bootstrap 配置错误，应该返回 internal error，不要静默使用默认 TTL。默认 5 只用于“渠道配置行未创建”的业务状态。

Bootstrap 改为：

```go
auth.WithVerifyCodePolicyProvider(
    auth.NewChannelVerifyCodePolicyProvider(mailService, smsService),
)
```

保留 `VerifyCodeOptions.TTL` 作为测试/兜底构造选项，但生产 bootstrap 不再注入 system-setting provider。

### 5. shared/setting 边界

实现后：

- `shared/setting` 继续拥有 `auth.captcha.ttl_minutes` 和 `upload.token.ttl_minutes` 这类 system settings。
- `shared/setting` 不再拥有 verify-code TTL 的运行时读写函数。
- 删除或重写相关测试：旧 `AuthVerifyCodeTTLMinutes*` / `SaveAuthVerifyCodeTTLMinutes` 测试不再成立。
- architecture guard 应该禁止 `auth.verify_code.ttl_minutes` 重新出现在 mail/sms/auth 运行时代码里。

不为了“少改一行”把渠道 TTL 验证继续塞在 `shared/setting`。那是坏名字、坏边界。

### 6. 前端

现有 API 字段名保持：

```ts
verify_code_ttl_minutes: number
```

只改文案含义：

- 邮件页：`邮件验证码有效期；模板变量 ttl_minutes 自动取这个值。`
- 短信页：`短信验证码有效期；模板变量 ttl_minutes 自动取这个值。`

英文同步改成 channel-specific 文案。

不能再写“邮件和短信共用”。

### 7. 文档

实施并验证后更新：

- `docs/status/current-status.md`
- `docs/contracts/admin-api-v1.md`
- `admin_back_go/docs/architecture.md`
- `docs/testing/smoke-matrix.md`
- 相关部署文档中提到 `auth.verify_code.ttl_minutes` 的段落

注意：spec/plan 本身不代表 runtime 已实现。`current-status` 只能在代码、测试或 smoke 验证后更新为新事实。

## 非目标

这次不做：

- 手机号验证码真实发送接入 SMS。
- 新增系统设置分类/隐藏规则框架。
- 新增验证码专页。
- 改验证码 Redis key namespace。
- 改 `auth_platforms.login_types`、captcha 或 token TTL 规则。
- 改邮件/短信模板变量集合，仍然只能是 `code` / `ttl_minutes`。
- 新增多 provider 邮件/短信抽象。

## 验收标准

实施完成后必须满足：

1. live schema 有 `mail_configs.verify_code_ttl_minutes` 和 `sms_configs.verify_code_ttl_minutes`。
2. live `system_settings` 不再有 active `auth.verify_code.ttl_minutes`。
3. 保存邮件配置不会改短信 TTL。
4. 保存短信配置不会改邮件 TTL。
5. email send-code 的 Redis TTL 来自邮件配置。
6. phone send-code 的 Redis TTL 来自短信配置；手机号仍固定 `123456`。
7. 邮件/短信 test-send 的模板变量 `ttl_minutes` 分别来自各自渠道配置。
8. 前端和 contract 不再出现“邮件和短信共用”描述。
9. 目标 Go tests、前端 contract tests、`git diff --check` 和 governance check 通过。

## 测试要求

后端至少跑：

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture -count=1
go test ./internal/module/mail ./internal/module/sms ./internal/module/auth ./internal/bootstrap ./internal/server -count=1
go test ./... -count=1
go build ./...
```

前端至少跑：

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/system/mail-api.test.ts tests/shared/system/sms-api.test.ts
npx vue-tsc -b --pretty false
```

根 repo docs/gate 至少跑：

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

如果实现阶段同步更新 smoke，则再跑对应 smoke read gate 或记录为何本轮不跑真实发送。

## 风险

- migration 必须保留旧全局值回填，避免用户原来设置的 TTL 丢失。
- 旧后端二进制如果仍通过 `SystemSettingVerifyCodePolicyProvider` 读取全局 TTL，而 migration 已把 key 软删除，会出现读不到 TTL。部署必须先准备代码和 migration，并在同一发布窗口内完成迁移与 backend 重启。
- 当前 phone code 仍固定 `123456`，短信 TTL 生效只影响 Redis code 过期，不代表真实短信已接入。
- 文档更新必须等运行时验证后再把 `current-status` 改为 implemented 新事实。

## Self-review

- 未发现未明确的实施项。
- 范围只覆盖验证码 TTL 归属，不扩大到真实短信发送。
- 设计已按 2026-05-29 multi-platform boundary 修订：HTTP 表面在 `transport/{platform}`，业务规则在 service，运行时技术资源不回流 module。
- 旧 `shared/setting` 细节已纠正：verify-code TTL 不再作为 system setting 运行时策略。
- 运行时读取路径、迁移路径、前端文案、文档验证都有明确边界。
