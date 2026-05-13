# Admin Mail Tencent SES Design

日期：2026-05-13  
范围：`admin_back_go` 邮件管理、腾讯云 SES 发信、邮箱验证码真实发送、`admin_front_ts` 系统菜单入口  
状态：design for review

## Linus 三问

### 1. 这是个真问题，还是臆想出来的？

是真问题。

当前登录页已经暴露邮箱验证码登录、找回密码、绑定邮箱这些用户路径；但 Go 后端的 `auth/send-code` 在 `VERIFY_CODE_DEV_MODE=false` 时直接返回“邮件验证码服务未配置”。这不是“未来优化”，这是已经摆在用户路径上的缺口。

更关键的是，验证码已经被 `RedisCodeStore` 管起来了，登录/找回密码/绑定邮箱都依赖这条链路。如果真实邮件不接，系统永远停在 demo 模式。

### 2. 有更简单的做法吗？

有。只接腾讯云邮件推送 SES API，不做自建邮件服务器，不做多供应商抽象，不把 SMTP、营销邮件、批量投递、回调统计一起塞进来。

最小但正确的路线：

```text
系统管理 -> 邮件管理
  Tab 1: 邮件配置       # 腾讯云 SecretId/SecretKey、region、发件人
  Tab 2: 邮件模板       # 本系统场景 -> 腾讯云 SES TemplateID 映射
  Tab 3: 发送日志       # 请求结果、错误码、RequestId，不保存正文和验证码
```

业务发送路径只需要一个接口：

```text
auth.SendCode -> mail.SendVerifyCode -> Tencent SES SendEmail -> Redis code store
```

### 3. 会破坏什么吗？

不能破坏这些：

```text
POST /api/admin/v1/auth/send-code 响应结构不变；
VERIFY_CODE_DEV_MODE=true 时仍能本地返回测试验证码；
短信验证码仍明确报“短信验证码服务未配置”，本 slice 不碰短信；
登录、refresh、RBAC、菜单、WebSocket 不因邮件模块改变；
APP_SECRET 仍是唯一根密钥，腾讯云密钥不放 .env、不明文出库。
```

可以接受这些变化：

```text
VERIFY_CODE_DEV_MODE=false 后，邮箱验证码必须依赖邮件配置和模板；
没有配置或模板时，邮箱验证码明确失败，不再假装成功；
邮件管理新增系统菜单、权限、表、API、前端页面和 smoke 探针。
```

## 当前项目事实

### 运行时事实

```text
admin_back_go/internal/module/auth/service.go
  SendCode 校验 account/scene 后：
    DevMode=true  -> 生成测试 code，写 Redis，返回“验证码发送成功(测试:xxxxxx)”
    DevMode=false -> email 直接报“邮件验证码服务未配置”
                 -> phone 直接报“短信验证码服务未配置”

admin_back_go/internal/module/auth/code_store.go
  Redis key = VERIFY_CODE_REDIS_PREFIX + account_type + ':' + scene + ':' + md5(account)

admin_back_go/internal/config/config.go
  VerifyCodeConfig 只有 TTL / RedisPrefix / DevMode / DevCode
```

### 配置事实

真实本地 `.env` 已收口到一个根密钥：

```env
APP_SECRET=...
VERIFY_CODE_TTL=5m
VERIFY_CODE_REDIS_PREFIX=auth:verify_code:
VERIFY_CODE_DEV_MODE=true
VERIFY_CODE_DEV_CODE=123456
```

邮件密钥不应回到 `.env`。腾讯云 `SecretId` / `SecretKey` 是后台业务配置，必须入库加密，使用现有 `APP_SECRET -> secretbox` 派生 key。

### 开源 / 官方来源

本设计采用腾讯云官方 SES API 与 Go SDK 路线：

```text
腾讯云 SES 产品文档：
https://cloud.tencent.com/document/product/1288/47445

腾讯云 SES SendEmail API：
https://cloud.tencent.com/document/api/1288/51034

腾讯云 SES SMTP 指南，仅作为不采用 SMTP 的对照：
https://cloud.tencent.com/document/product/1288/65749

Go SDK 包路径：
github.com/tencentcloud/tencentcloud-sdk-go/tencentcloud/ses/v20201002
```

关键取舍：腾讯云 SES 普通路径按模板发送；所以本系统的“邮件模板”第一期不编辑 HTML 正文，而是维护本地业务场景到腾讯云 `TemplateID` 的映射和变量约束。这样不跟腾讯云审核、模板状态和发信规则打架。

## 目标

1. 新增系统菜单“邮件管理”，放在“系统管理”下。
2. 只接入腾讯云 SES API 发信。
3. 腾讯云密钥入库加密，响应只返回 hint，不返回明文或密文。
4. 管理邮件配置、业务模板映射、发送日志。
5. `auth.SendCode` 在 `VERIFY_CODE_DEV_MODE=false` 且账号是邮箱时，真实发送验证码邮件。
6. 邮件发送链路可测试、可审计、可定位腾讯云错误码和 RequestId。
7. 保留 dev mode 本地开发能力，不让开发环境必须打真实邮件。
8. 为后续回调/重试/队列留下干净边界，但不在第一期实现。

## 非目标

本次不做：

```text
不做短信；
不做 SMTP；
不做自建 Postfix/Exim；
不做多邮件供应商配置；
不做营销邮件、群发、订阅退订；
不做腾讯云模板创建/审核管理；
不做回调 webhook 统计；
不做邮件打开率/点击率；
不做异步队列重试平台；
不把腾讯云 SecretId/SecretKey 写进 .env；
不在日志里保存邮件正文、验证码明文、TemplateData 全量内容。
```

## 推荐方案

### 1. 菜单与前端入口

菜单位置：

```text
系统管理
  └─ 邮件管理
```

菜单元数据：

```text
中文：邮件管理
英文：Mail
path: /system/mail
component: system/mail
i18n_key: menu.system_mail
PAGE permission code: system_mail
```

页面结构：

```text
/system/mail
  Tab: 邮件配置
  Tab: 邮件模板
  Tab: 发送日志
```

第一期不拆 3 个菜单。拆菜单只会制造权限、路由、面包屑和页面状态复杂度；一个页面三段业务足够清楚。

### 2. 后端模块边界

新增模块：

```text
admin_back_go/internal/module/mail
  route.go          # REST route
  handler.go        # HTTP 入参/出参
  service.go        # 配置、模板、日志、验证码发送编排
  repository.go     # GORM 查询
  model.go          # mail_configs / mail_templates / mail_logs
  dto.go            # service DTO
  request.go        # Gin binding request
  errors.go         # 模块错误

admin_back_go/internal/platform/mail/tencentcloudses
  client.go         # 只封装腾讯云 SES SDK SendEmail
```

边界规则：

```text
module/mail 懂业务 scene/template/log；
platform/mail/tencentcloudses 只懂腾讯云 API，不懂登录、验证码、用户；
auth.Service 不直接 import 腾讯云 SDK，也不 import module/mail 具体类型；
auth.Service 只依赖一个很窄的验证码邮件发送接口；
service 不依赖 gin.Context；
repository 不写业务决策；
日志写入由 mail service 统一做。
```

### 3. 数据库设计

#### mail_configs

单 admin 系统只需要一个默认邮件配置。表用复数名保持项目风格，API 是 singleton。

```sql
CREATE TABLE mail_configs (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  config_key VARCHAR(32) NOT NULL DEFAULT 'default',
  secret_id_enc TEXT NOT NULL,
  secret_id_hint VARCHAR(64) NOT NULL DEFAULT '',
  secret_key_enc TEXT NOT NULL,
  secret_key_hint VARCHAR(64) NOT NULL DEFAULT '',
  region VARCHAR(64) NOT NULL DEFAULT 'ap-guangzhou',
  endpoint VARCHAR(128) NOT NULL DEFAULT 'ses.tencentcloudapi.com',
  from_email VARCHAR(255) NOT NULL,
  from_name VARCHAR(100) NOT NULL DEFAULT '',
  reply_to VARCHAR(255) NOT NULL DEFAULT '',
  status TINYINT UNSIGNED NOT NULL DEFAULT 2,
  last_test_at DATETIME NULL,
  last_test_error VARCHAR(500) NOT NULL DEFAULT '',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_mail_configs_config_key (config_key),
  KEY idx_mail_configs_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

字段规则：

```text
config_key 固定 default，避免用 id=1 这种魔法约定；
secret_id_enc / secret_key_enc 使用 secretbox 加密；
secret_id_hint / secret_key_hint 使用 secretbox.Hint 展示末 4 位；
status: 1=启用，2=禁用；
不提供删除配置接口，配置只能更新或禁用；
endpoint 是腾讯云 API endpoint，不是多 provider 抽象。
```

#### mail_templates

本系统不编辑腾讯云 HTML 模板正文。它只维护业务场景到腾讯云 `TemplateID` 的映射。

```sql
CREATE TABLE mail_templates (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  scene VARCHAR(32) NOT NULL,
  name VARCHAR(100) NOT NULL,
  subject VARCHAR(200) NOT NULL,
  tencent_template_id BIGINT UNSIGNED NOT NULL,
  variables_json JSON NOT NULL,
  sample_variables_json JSON NOT NULL,
  status TINYINT UNSIGNED NOT NULL DEFAULT 1,
  is_del TINYINT UNSIGNED NOT NULL DEFAULT 2,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_mail_templates_scene (scene),
  KEY idx_mail_templates_status_del (status, is_del)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

第一期允许的邮箱场景：

```text
login            # 邮箱验证码登录
forget           # 找回密码
bind_email       # 绑定/换绑邮箱
change_password  # 验证码改密，账号为邮箱时
```

字段规则：

```text
scene 与现有 enum.VerifyCodeScene 保持一致，不自创 forgot_password；
tencent_template_id 是腾讯云 SES 模板 ID；
variables_json 例如 ["code", "ttl_minutes", "app_name"]；
sample_variables_json 用于测试发送，例如 {"code":"123456","ttl_minutes":"5","app_name":"admin_go"}；
删除动作只把 is_del=1；重新新增同 scene 时恢复并覆盖旧行，避免同一场景出现多个活跃模板。
```

#### mail_logs

日志只记录投递事实，不记录正文和验证码。

```sql
CREATE TABLE mail_logs (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  scene VARCHAR(32) NOT NULL,
  template_id BIGINT UNSIGNED NULL,
  to_email VARCHAR(255) NOT NULL,
  subject VARCHAR(200) NOT NULL DEFAULT '',
  tencent_request_id VARCHAR(128) NOT NULL DEFAULT '',
  tencent_message_id VARCHAR(128) NOT NULL DEFAULT '',
  status TINYINT UNSIGNED NOT NULL,
  error_code VARCHAR(128) NOT NULL DEFAULT '',
  error_message VARCHAR(500) NOT NULL DEFAULT '',
  duration_ms BIGINT UNSIGNED NOT NULL DEFAULT 0,
  sent_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_mail_logs_scene_created (scene, created_at),
  KEY idx_mail_logs_status_created (status, created_at),
  KEY idx_mail_logs_to_email_created (to_email, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

状态枚举：

```text
1 = pending
2 = success
3 = failed
```

日志规则：

```text
不保存邮件正文；
不保存验证码 code；
不保存 TemplateData 原文；
错误信息最多 500 字符；
列表默认按 created_at DESC；
日志保留策略第一期不做自动清理，后续可以挂 cron。
```

## API 契约

统一前缀：

```text
/api/admin/v1
```

### page-init

```text
GET /api/admin/v1/mail/page-init
Auth: bearer token
```

Response data：

```ts
interface MailPageInitResponse {
  common_status_arr: Array<{ label: string; value: 1 | 2 }>
  mail_scene_arr: Array<{ label: string; value: 'login' | 'forget' | 'bind_email' | 'change_password' }>
  mail_log_scene_arr: Array<{ label: string; value: 'login' | 'forget' | 'bind_email' | 'change_password' | 'test' }>
  mail_log_status_arr: Array<{ label: string; value: 1 | 2 | 3 }>
  default_region: 'ap-guangzhou'
  default_endpoint: 'ses.tencentcloudapi.com'
}
```

### config

```text
GET /api/admin/v1/mail/config
PUT /api/admin/v1/mail/config
POST /api/admin/v1/mail/test
```

`GET /mail/config` response：

```ts
interface MailConfigResponse {
  id: number | null
  configured: boolean
  secret_id_hint: string
  secret_key_hint: string
  region: string
  endpoint: string
  from_email: string
  from_name: string
  reply_to: string
  status: 1 | 2
  last_test_at: string | null
  last_test_error: string
}
```

`PUT /mail/config` body：

```ts
interface SaveMailConfigBody {
  secret_id?: string      // 新增必填；编辑留空表示保留旧密钥
  secret_key?: string     // 新增必填；编辑留空表示保留旧密钥
  region: string
  endpoint?: string
  from_email: string
  from_name?: string
  reply_to?: string
  status: 1 | 2
}
```

`POST /mail/test` body：

```ts
interface TestMailBody {
  to_email: string
  template_scene: 'login' | 'forget' | 'bind_email' | 'change_password'
}
```

规则：测试发送真实邮件，使用目标模板的 `sample_variables_json`，写一条 `scene=test` 的发送日志。

### templates

```text
GET    /api/admin/v1/mail/templates
POST   /api/admin/v1/mail/templates
PUT    /api/admin/v1/mail/templates/:id
PATCH  /api/admin/v1/mail/templates/:id/status
DELETE /api/admin/v1/mail/templates/:id
```

模板 DTO：

```ts
interface MailTemplateDTO {
  id: number
  scene: 'login' | 'forget' | 'bind_email' | 'change_password'
  name: string
  subject: string
  tencent_template_id: number
  variables: string[]
  sample_variables: Record<string, string>
  status: 1 | 2
  created_at: string
  updated_at: string
}
```

规则：

```text
同一 scene 只能有一条模板；
variables 必须是非空字符串数组；
sample_variables 必须覆盖 variables 里的所有 key；
启用前不调用腾讯云校验模板是否已审核，但 test send 会暴露腾讯云错误码。
```

### logs

```text
GET /api/admin/v1/mail/logs
GET /api/admin/v1/mail/logs/:id
```

查询参数：

```ts
interface MailLogQuery {
  page?: number
  page_size?: number
  scene?: 'login' | 'forget' | 'bind_email' | 'change_password' | 'test'
  status?: 1 | 2 | 3
  to_email?: string
  created_at_start?: string
  created_at_end?: string
}
```

列表项：

```ts
interface MailLogItem {
  id: number
  scene: string
  template_id: number | null
  to_email: string
  subject: string
  status: 1 | 2 | 3
  tencent_request_id: string
  error_code: string
  error_message: string
  duration_ms: number
  sent_at: string | null
  created_at: string
}
```

## 权限设计

PAGE：

```text
system_mail
```

BUTTON：

```text
system_mail_configEdit
system_mail_test
system_mail_templateAdd
system_mail_templateEdit
system_mail_templateStatus
system_mail_templateDel
```

权限规则：

```text
GET page-init/config/templates/logs 只需要 bearer token + 页面可见；
PUT config 需要 system_mail_configEdit；
POST test 需要 system_mail_test；
POST/PUT/PATCH/DELETE template 使用对应 system_mail_template*；
发送日志只读，不设置删除按钮；
route_meta.go 必须显式注册所有 mutation 权限和 OperationLog 元数据。
```

## 发送链路

### auth.SendCode 分支

```text
if VERIFY_CODE_DEV_MODE=true:
  保持现状：生成 dev code -> 写 Redis -> 返回测试消息

if VERIFY_CODE_DEV_MODE=false and account is phone:
  返回“短信验证码服务未配置”

if VERIFY_CODE_DEV_MODE=false and account is email:
  生成随机 6 位 code
  写 Redis
  调用 mail.SendVerifyCode
  成功：返回 ok
  失败：best-effort 删除 Redis code，写 failed log，返回“邮件验证码发送失败”
```

为什么先写 Redis 再发邮件：

```text
如果先发邮件再写 Redis，用户可能收到一个无法使用的验证码；
如果先写 Redis 再发邮件，发信失败可删除 Redis，最坏只是删除失败留下一个用户没收到的 code；
对用户体验和安全边界，前者更糟。
```

### 验证码邮件发送接口

`auth` 只依赖自己包内定义的小接口，避免 `auth -> mail` 类型依赖：

```go
type VerifyCodeMailSender interface {
    SendVerifyCode(ctx context.Context, scene string, toEmail string, code string, ttl time.Duration) *apperror.Error
}
```

`mail.Service` 实现同名方法，`bootstrap` 注入接口。这样依赖方向是：

```text
bootstrap -> auth service + mail service
auth service -> VerifyCodeMailSender interface
mail service -> repository + tencentcloudses client
```

### 腾讯云 SES SendEmail 映射

腾讯云 API 字段映射：

```text
FromEmailAddress = from_name + <from_email>
Destination      = []string{to_email}
Subject          = mail_templates.subject
TemplateID       = mail_templates.tencent_template_id
TemplateData     = JSON string built from code / ttl_minutes / app_name
ReplyToAddresses = reply_to when configured
TriggerType      = 1
```

超时：

```text
SES API 调用默认 10s 超时；
不新建 goroutine；
不做无限 retry；
腾讯云返回错误直接映射到 mail_logs.error_code/error_message。
```

## 前端设计

文件边界：

```text
admin_front_ts/src/api/system/mail.ts
admin_front_ts/src/views/Main/system/mail/index.vue
admin_front_ts/src/i18n/locales/zh-CN.ts
admin_front_ts/src/i18n/locales/en-US.ts
```

规则：

```text
Vue 3 + <script setup lang="ts">；
API 层定义明确 DTO，不用 any / Record<string, any>；
表单中 SecretId/SecretKey 编辑时默认留空，placeholder 显示 hint；
点击保存时，空 secret 字段表示保留旧值；
模板变量用字符串 tag 输入，不让用户写任意 JSON；
sample_variables 用变量表格编辑，保证 key 全覆盖；
日志详情不展示正文和验证码。
```

## 配置与 env

保留现有 env：

```env
VERIFY_CODE_TTL=5m
VERIFY_CODE_REDIS_PREFIX=auth:verify_code:
VERIFY_CODE_DEV_MODE=true
VERIFY_CODE_DEV_CODE=123456
```

不新增这些 env：

```env
TENCENTCLOUD_SECRET_ID=
TENCENTCLOUD_SECRET_KEY=
MAIL_SECRET_ID=
MAIL_SECRET_KEY=
SMTP_PASSWORD=
```

上线切换步骤：

```text
1. 后台录入邮件配置；
2. 后台录入登录/找回/绑定邮箱/改密场景的腾讯云模板 ID；
3. 点“发送测试邮件”确认腾讯云配置、发件地址、模板审核都正确；
4. 把 VERIFY_CODE_DEV_MODE=false；
5. 重启 admin-api；
6. 走邮箱验证码登录 smoke。
```

## 错误处理

明确失败，不搞静默兜底：

```text
未配置邮件：邮件配置未配置
配置禁用：邮件配置未启用
模板缺失：邮件模板未配置
模板禁用：邮件模板未启用
密钥解密失败：邮件密钥解密失败
腾讯云失败：邮件验证码发送失败
Redis 写入失败：验证码缓存写入失败
```

`auth/send-code` 对外仍返回统一响应；错误 `msg` 是上面的业务文本。

## 测试与验证

后端测试：

```text
go test ./internal/module/mail
go test ./internal/module/auth
go test ./internal/platform/mail/tencentcloudses
go test ./internal/bootstrap ./internal/server
```

必须覆盖：

```text
secret_id/secret_key 加密、hint、编辑留空保留旧密钥；
模板变量校验和 sample_variables 覆盖；
mail.SendVerifyCode 缺配置/缺模板/禁用场景失败；
Tencent client fake 成功/失败都写日志；
auth.SendCode dev mode 保持现状；
auth.SendCode real email 分支写 Redis、调用 sender；
auth.SendCode real email 发送失败时 best-effort 删除 Redis；
phone real mode 仍返回短信未配置。
```

前端验证：

```text
mail API Vitest contract test；
Vue SFC parse/build check；
邮件配置表单 secret hint/留空保留逻辑；
模板变量和 sample_variables 校验；
按钮权限 v-if 使用 system_mail_*。
```

Smoke：

```text
full-admin-smoke.ps1 增加只读探针：
  GET /api/admin/v1/mail/page-init
  GET /api/admin/v1/mail/config
  GET /api/admin/v1/mail/templates
  GET /api/admin/v1/mail/logs

真实发信 smoke 默认不跑，必须显式传参或设置开关，避免 CI/本地误发邮件。
```

Contract gate：

```text
admin_back_go/docs/architecture.md 记录 mail 模块边界；
docs/contracts/admin-api-v1.md 记录 Mail Management contract；
docs/migration/current-status.md 只在实现和验证完成后写 implemented；
docs/testing/smoke-matrix.md 增加邮件管理 read probes。
```

## 实施切片建议

本 spec 通过后，plan 按 5 个切片写：

```text
1. DB migration + seed menu/permissions；
2. backend mail module + Tencent SES platform client；
3. auth.SendCode 接入 MailSender；
4. frontend /system/mail 页面和 typed API；
5. docs + smoke + contract verification。
```

不把 UI、腾讯 SDK、auth 分支、DB 菜单、smoke 一坨提交。每一步都可回滚。

## 自检

```text
无多供应商抽象；
无 SMTP；
无自建邮件服务器；
无正文/验证码日志泄漏；
无邮件密钥 env；
不破坏现有 send-code 响应结构；
不改变短信现状；
腾讯云模板规则已反映到本地模板设计；
权限 code 与系统菜单风格一致；
实现前仍需要用户 review 本 spec，然后再写 plan。
```
