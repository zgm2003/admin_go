# Verify Code Template Variables and Dynamic TTL Design

日期：2026-05-14
状态：accepted for implementation
范围：`admin_back_go` 验证码 TTL 配置、邮件验证码发送、邮件模板 HTML、`admin_front_ts` 邮件配置页

## 你这次真正要表达的产品规则

1. `app_name` 不再是验证码模板变量。
   - 邮件已经有 `mail_configs.from_name`，也就是页面里的“发件名称”。
   - 它真实进入 Tencent SES `FromEmailAddress`，用于收件箱显示名。
   - 所以模板正文不需要再传一个重复的 `app_name`。

2. 验证码模板变量只保留两个：

```text
code
ttl_minutes
```

3. `ttl_minutes` 必须动态配置，不能再从 env 读取。
   - env 是启动配置，改了要重启，属于死数据。
   - 验证码有效期是业务配置，应该在数据库里，可后台修改。
   - 邮件和未来短信共用同一个验证码 TTL，不允许邮件一套、短信一套。

4. 现在先把验证码 TTL 放在“邮件配置”页面里展示和保存。
   - 这是 UI 入口选择，不代表 TTL 属于邮件。
   - 产品概念叫“验证码公共配置”。
   - 下一步短信配置页面也复用同一个 TTL。

## Linus 三问

### 1. 这是真问题吗？

是。实施前旧代码里 `mail.SendVerifyCode` 仍然构造了额外的 app-name 模板数据：

```go
map[string]string{
  "code": code,
  "ttl_minutes": ttlMinutes(ttl),
  // old extra app-name key
}
```

同时 HTML 模板也大量使用旧 app-name 占位符。这和现在确定的产品规则冲突。

### 2. 有更简单的方法吗？

有：

```text
from_name 继续只做邮件发件显示名；
验证码模板变量只剩 code / ttl_minutes；
ttl_minutes 从数据库里的验证码公共配置读取；
邮件配置页只是暂时承载这个公共配置入口。
```

不新增品牌配置，不把 app_name 换个名字继续塞回模板。

### 3. 会破坏什么吗？

会影响三处，需要一次性收口：

```text
腾讯云模板变量：要从 app_name/code/ttl_minutes 改成 code/ttl_minutes
本地 HTML 模板：要删除旧 app-name 占位符
数据库 mail_templates.variables_json / sample_variables_json：要和新变量保持一致
```

如果腾讯云线上模板还没改，后端先切到两个变量会导致发送失败。所以实施顺序必须是：先改本地模板和后台变量规则，再更新腾讯云模板并审核，最后切运行时变量。

## 推荐方案

### 数据库配置

使用现有 `system_settings` 存验证码公共 TTL，不新增 env。

新增/seed 一条系统配置：

```text
setting_key   = auth.verify_code.ttl_minutes
setting_value = 5
value_type    = number
status        = 1
is_del        = 2
remark        = 验证码有效期分钟数，邮件和短信共用
```

理由：

```text
这是公共验证码策略，不是 mail_configs 字段。
未来短信配置直接复用，不需要从 mail_configs 读一个邮件表里的字段。
现有 system_settings 已经有 DB + Redis cache invalidation 机制，没必要为一个 TTL 再造表。
```

### 后端运行时

新增一个小的验证码配置读取边界，例如：

```go
type VerifyCodePolicyProvider interface {
    VerifyCodeTTL(ctx context.Context) (time.Duration, *apperror.Error)
}
```

`auth.Service.SendCode` 改成：

```text
读取 DB TTL
生成/确定 code
Redis Set 使用 DB TTL
邮箱发送时把同一个 TTL 传给 mail.SendVerifyCode
```

删除运行时对：

```text
legacy verify-code TTL env
APP_NAME
```

的验证码业务依赖。

`APP_SECRET`、DB、Redis 这些基础设施 env 继续保留；业务可变值不放 env。

### 邮件服务

`mail.SendVerifyCode` 只构造：

```json
{
  "code": "654321",
  "ttl_minutes": "5"
}
```

删除：

```text
app_name
old default app-name constant
```

邮件模板变量校验规则改成严格两个变量：

```text
code
ttl_minutes
```

不是“至少包含”，而是验证码模板就只允许这两个。多一个 `app_name` 或别的变量，后台保存模板时直接拒绝，避免运行时 Tencent SES 变量对不上。

### 邮件配置页

在“腾讯云 SES 配置”卡片中加一个小区域：

```text
验证码公共配置
  验证码有效期（分钟）  [ 5 ]
```

保存时同时保存：

```text
mail_configs：SecretId / SecretKey / Region / Endpoint / from_email / from_name / reply_to / status
system_settings.auth.verify_code.ttl_minutes：验证码有效期分钟数
```

页面说明：

```text
发件名称：用于邮件收件箱显示，例如 智域云阁 <manager@email.zgm2003.cn>
验证码有效期：邮件和短信验证码共用，模板变量 ttl_minutes 自动取这个值
```

### 模板 HTML

四份模板全部删除旧 app-name 占位符，只保留：

```text
{{code}}
{{ttl_minutes}}
```

标题和正文改成不依赖 app name，例如：

```text
登录验证码
您好，您正在登录后台管理系统。请在页面输入以下验证码：
验证码有效期为 {{ttl_minutes}} 分钟。
```

四份文件：

```text
docs/mail-templates/tencent-ses/login-code.html
docs/mail-templates/tencent-ses/forget-password-code.html
docs/mail-templates/tencent-ses/bind-email-code.html
docs/mail-templates/tencent-ses/change-password-code.html
```

### 数据迁移

新增 migration 做两件事：

1. seed `system_settings.auth.verify_code.ttl_minutes = 5`。
2. 把现有四个邮件模板变量改成：

```json
["code", "ttl_minutes"]
```

示例变量改成：

```json
{"code":"123456","ttl_minutes":"5"}
```

不改 `tencent_template_id`，因为用户在腾讯云重新审核后会手动更新或沿用新 ID。

## API 影响

### Mail page-init/config

需要让邮件配置页拿到当前 TTL。

推荐两种实现，优先第一种：

#### 推荐：复用 mail config 接口

`GET /api/admin/v1/mail/config` response 增加：

```ts
verify_code_ttl_minutes: number
```

`PUT /api/admin/v1/mail/config` body 增加：

```ts
verify_code_ttl_minutes: number
```

优点：页面保存按钮简单，用户不会感知两个后端接口。

#### 备选：独立验证码配置接口

```text
GET /api/admin/v1/verify-code/config
PUT /api/admin/v1/verify-code/config
```

优点：概念更纯。缺点：这次要新增路由/权限/前端调用，切片更大。

本轮建议先用 mail config 接口承载，但后端内部不要把值存到 mail_configs，仍然写 `system_settings`。

## 测试要求

### Go

新增/调整测试：

```text
mail.SendVerifyCode 只发送 code / ttl_minutes，不再发送 app_name
保存邮件模板时拒绝 app_name，要求变量严格等于 code + ttl_minutes
auth.SendCode 使用 DB TTL 写 Redis，并把同一个 TTL 传给邮件发送器
mail config 保存时同时 upsert system_settings.auth.verify_code.ttl_minutes
system setting 缺失/禁用/非法值时返回明确错误
```

验证命令：

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/module/auth ./internal/module/mail ./internal/module/systemsetting ./internal/config ./internal/bootstrap
go test ./...
go vet ./...
go test -race ./internal/module/auth ./internal/module/mail
```

### Vue

新增/调整测试：

```text
MailConfigPanel 显示 verify_code_ttl_minutes
MailTemplatePanel 默认变量只有 code / ttl_minutes
前端 contract 不再出现 app_name 模板变量
```

验证命令：

```powershell
cd E:/admin_go/admin_front_ts
npm run test -- tests/shared/system/mail-api.test.ts
npx vue-tsc -b --pretty false
```

## 不做的事

```text
不做短信发送实现；短信是下一切片
不新增 app_name / brand_name / system_name 配置
不把 from_name 当模板变量传入正文
不让每个模板单独配置 TTL
不继续保留 legacy verify-code TTL env / APP_NAME 这类业务 env
```

## 验收标准

```text
全仓搜不到验证码模板变量 app_name
四份本地 HTML 模板只含 code / ttl_minutes
新建/编辑邮件模板时变量不是 code + ttl_minutes 就失败
邮件发送 TemplateData 只有 code / ttl_minutes
验证码 Redis TTL 来自数据库配置
邮件配置页能看到并保存验证码有效期分钟数
后续短信配置能复用同一个 TTL，不需要重新设计
```
