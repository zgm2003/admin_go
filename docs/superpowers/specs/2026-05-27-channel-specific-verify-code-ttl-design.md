# 验证码 TTL 渠道归属收口设计

日期：2026-05-27
状态：draft
范围：`admin_back_go` 的验证码 TTL 运行时策略、`mail_configs` / `sms_configs` 配置归属、`system_settings.auth.verify_code.ttl_minutes` 退场、`admin_front_ts` 邮件/短信配置页文案和契约测试、根 repo contract/status/smoke 文档。
项目角色：architect

## 目标

把验证码有效期从全局 `system_settings.auth.verify_code.ttl_minutes` 收回到真正拥有发送能力的渠道模块：

1. 邮件验证码 TTL 归属 `mail_configs.verify_code_ttl_minutes`。
2. 短信验证码 TTL 归属 `sms_configs.verify_code_ttl_minutes`。
3. 系统设置页不再暴露 `auth.verify_code.ttl_minutes`。
4. 邮件管理和短信管理互不覆盖 TTL。
5. `auth/send-code` 仍按账号类型写 Redis code，只是 TTL 改为按渠道读取。

这次只修 TTL 归属，不把手机号验证码接入真实短信发送。当前手机号验证码仍保持固定 `123456`，但 Redis 过期时间要按短信渠道 TTL 读取。

## 当前事实

- `docs/status/current-status.md` 明确记录邮件和短信当前共享 `system_settings.auth.verify_code.ttl_minutes`。
- `docs/contracts/admin-api-v1.md` 也写明 `PUT /mail/config` 和 `PUT /sms/config` 都把 `verify_code_ttl_minutes` 保存到 `system_settings.auth.verify_code.ttl_minutes`。
- `admin_back_go/internal/module/mail/service.go` 和 `admin_back_go/internal/module/sms/service.go` 都定义同一个 `verifyCodeTTLSettingKey = "auth.verify_code.ttl_minutes"`，并在保存配置时写 `system_settings`。
- `admin_back_go/internal/module/auth/verify_code_policy.go` 通过 `SystemSettingVerifyCodePolicyProvider` 读取这个全局 key。
- live DB 验证：`system_settings` 里存在 `auth.verify_code.ttl_minutes=5`，而 `mail_configs` / `sms_configs` 当前没有任何 TTL 字段。

结论：这不是 UI 展示问题，而是配置事实源归属错误。现在邮件、短信、系统设置三个入口在改同一条全局值。

## Linus 三问

1. 这是个真问题吗？
   - 是。两个独立渠道的配置页互相覆盖同一条 TTL，用户无法得到“邮件 TTL”和“短信 TTL”两个独立结果。
2. 有更简单的做法吗？
   - 最小正确做法是加两个渠道字段，迁移旧全局值，删除全局写入路径。不需要新增专页或新模块。
3. 会破坏已有登录、权限、菜单和前端路由吗？
   - 不应该破坏。API 字段名 `verify_code_ttl_minutes` 可保持不变；变的是字段落库位置和 auth TTL 读取来源。需要用 Go tests、前端 contract tests、contract/status 文档和 smoke 读 gate 覆盖。

## 方案比较

### 方案 A：渠道配置表分别持有 TTL（推荐）

新增：

- `mail_configs.verify_code_ttl_minutes`
- `sms_configs.verify_code_ttl_minutes`

邮件配置页保存邮件 TTL，短信配置页保存短信 TTL。`auth.SendCode` 按账号类型读取对应渠道 TTL。

优点：

- 与用户心智一致：邮件管理管邮件，短信管理管短信。
- 互不覆盖。
- 保留现有 API 字段名，前端改动小。
- `system_settings` 不再变成跨模块垃圾桶。

缺点：

- 需要一次 schema migration。
- auth policy 需要改成按账号类型读取渠道 TTL。

### 方案 B：只隐藏 system settings 里的全局 key

不采用。

原因：

- 只能解决“系统设置页看得到”的表象。
- 邮件配置和短信配置仍然会互相覆盖同一个全局值。
- 以后排障更隐蔽。

### 方案 C：把验证码 TTL 放到 auth_platforms

不采用。

原因：

- `auth_platforms` 管登录方式、captcha、token/session 策略，不拥有 Tencent SES/SMS 模板变量。
- 邮件和短信发送页已经有各自配置入口，用户明确期望按渠道配置。
- 按平台配置会引出 admin/app 不同 TTL 语义，不是这次真实问题。

## 推荐设计

### 1. 数据模型

新增 migration：

```sql
ALTER TABLE `mail_configs`
  ADD COLUMN `verify_code_ttl_minutes` INT UNSIGNED NOT NULL DEFAULT 5 AFTER `reply_to`;

ALTER TABLE `sms_configs`
  ADD COLUMN `verify_code_ttl_minutes` INT UNSIGNED NOT NULL DEFAULT 5 AFTER `endpoint`;
```

迁移规则：

1. 读取旧 `system_settings.auth.verify_code.ttl_minutes`。
2. 如果旧值是 1-60 的整数，则回填到现有 `mail_configs` 和 `sms_configs` active rows。
3. 如果旧值缺失、禁用、非法，回填默认 5。
4. 最后把 `auth.verify_code.ttl_minutes` 软删除或禁用，保证系统设置列表不再展示它。

### 2. 邮件模块

`mail.Config` 增加 `VerifyCodeTTLMinutes int`。

`mail.SaveConfig`：

- 继续校验 TTL 1-60。
- 把 TTL 写入 `mail_configs.verify_code_ttl_minutes`。
- 不再写 `system_settings`。
- 不再依赖 `systemsetting.SettingByKey` / `SaveSetting` / `InvalidateSettingCache`。

`mail.Config()`：

- 已配置时返回 `row.VerifyCodeTTLMinutes`。
- 未配置时返回默认 5。

新增/保留一个小方法供 auth policy 使用：

```go
VerifyCodeTTL(ctx context.Context) (time.Duration, *apperror.Error)
```

规则：未配置邮件服务时返回默认 5；已配置但 TTL 非法时返回配置错误。

### 3. 短信模块

`sms.Config` 增加 `VerifyCodeTTLMinutes int`。

`sms.SaveConfig`、`sms.Config()` 与邮件模块同理。

`sms.TestSend` 使用短信配置自己的 TTL 填充模板变量 `ttl_minutes`。

新增/保留一个小方法供 auth policy 使用：

```go
VerifyCodeTTL(ctx context.Context) (time.Duration, *apperror.Error)
```

规则：未配置短信服务时返回默认 5。这样不会破坏当前手机号固定 `123456` 的登录/绑定流程。

### 4. Auth 运行时

把当前无参策略：

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

其中 `mail.Service` 和 `sms.Service` 都通过同名方法满足 `VerifyCodeTTLProvider`。`auth` 只依赖小接口，不 import Tencent SDK，也不直接调用具体发送实现之外的渠道细节。

Bootstrap 改为：

```go
auth.WithVerifyCodePolicyProvider(
    auth.NewChannelVerifyCodePolicyProvider(mailService, smsService),
)
```

### 5. 前端

现有 API 字段名保持：

```ts
verify_code_ttl_minutes: number
```

只改文案含义：

- 邮件页：`邮件验证码有效期；模板变量 ttl_minutes 自动取这个值。`
- 短信页：`短信验证码有效期；模板变量 ttl_minutes 自动取这个值。`

不能再写“邮件和短信共用”。

### 6. 文档

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
go test ./internal/module/mail ./internal/module/sms ./internal/module/auth ./internal/bootstrap ./internal/server -count=1
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
- `system_settings` 软删后，旧后端二进制如果还在运行会读不到 TTL；部署时必须先发代码再确认 migration/重启顺序，或在本地一次性完成并重启 backend。
- 当前 phone code 仍固定 `123456`，短信 TTL 生效只影响 Redis code 过期，不代表真实短信已接入。
- 文档更新必须等运行时验证后再把 `current-status` 改为 implemented 新事实。

## Self-review

- 占位扫描通过，未发现未明确的实施项。
- 范围只覆盖验证码 TTL 归属，不扩大到真实短信发送。
- 设计与用户要求一致：系统设置删除全局 TTL，邮件和短信单独配置。
- 运行时读取路径、迁移路径、前端文案、文档验证都有明确边界。
