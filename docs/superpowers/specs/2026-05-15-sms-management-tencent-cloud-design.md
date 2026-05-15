# Admin SMS Tencent Cloud SMS Design

日期：2026-05-15  
状态：待评审  
范围：`admin_back_go` 短信管理、腾讯云短信发送、短信模板/配置/日志、`admin_front_ts` 系统菜单入口

## Linus 三问

### 1. 这是真问题，还是臆想出来的？

是真问题。当前项目里手机号验证码还是固定 `123456`，短信发送并没有真正接入；但项目已经明确要走 Go/Vue runtime，后续只会越来越依赖一个干净的短信边界。

### 2. 有更简单的做法吗？

有。只做腾讯云短信 `SendSms` 发送与管理，不做短信签名/模板申请流，不做 webhook，不做重试队列，不做多供应商抽象。

### 3. 会破坏什么吗？

不会改现有 `auth/send-code` 行为，不会把短信塞进 `auth`，也不会动邮件模块。短信是单独切片。

## 当前事实

### 运行时事实

- 邮件管理已经是当前可用的完整参考实现：`internal/module/mail` + `internal/platform/mail/tencentcloudses`。
- `auth/send-code` 现在对手机号仍是固定验证码 `123456`，没有短信发送。
- 验证码有效期已经沉到 `system_settings.auth.verify_code.ttl_minutes`，邮件和未来短信共用。

### 官方依据

- 腾讯云短信发送：`SendSms`
  - https://cloud.tencent.com/document/product/382/55981
- 腾讯云短信模板申请：`AddSmsTemplate`
  - https://cloud.tencent.com/document/product/382/55974
- 腾讯云短信签名申请：`AddSmsSign`
  - https://cloud.tencent.com/document/product/382/55971

结论很简单：`SendSms` 是运行时发送；`AddSmsTemplate` / `AddSmsSign` 是审核型管理接口。第一期不把审核流做进后台。

## 方案比较

### 方案 A：独立 `sms` 管理模块（推荐）

```text
系统管理 -> 短信管理
  Tab 1: 短信配置
  Tab 2: 短信模板
  Tab 3: 发送日志
```

只管理已审核的腾讯云短信资源映射，后台负责发送、测试、审计。

### 方案 B：短信管理 + 立刻接入 auth

把手机号验证码发送也切到短信。

问题是范围会变大，auth、风控、验证码策略、运营配置会一起动，不适合现在这一步。

### 方案 C：把签名/模板申请也做进后台

看起来完整，实际上是把审核流程、资质限制、图片材料、状态流全塞进来。

这会让第一版失控，没必要。

## 推荐设计

### 1. 后端边界

新增：

```text
admin_back_go/internal/module/sms
admin_back_go/internal/platform/sms/tencentcloudsms
```

职责和邮件模块一样干净：

- `module/sms`：配置、模板、日志、测试发送、审计编排
- `platform/sms/tencentcloudsms`：唯一允许 import 腾讯云短信 SDK 的地方
- `auth`：暂时不接入短信 sender，手机号验证码继续固定 `123456`

以后如果要把 `auth/send-code` 切到短信，只需要依赖一个很小的 sender 接口，不需要反过来污染短信模块。

### 2. 业务范围

第一期只做**国内验证码短信**，不做国际/港澳台短信，不做营销短信，不做群发。

模板场景沿用当前验证码场景里和手机号有关的那部分：

```text
login
forget
bind_phone
change_password
```

`bind_email` 不属于短信场景，别硬塞。

### 3. 腾讯云调用边界

发送链路只走 `SendSms`，核心参数是：

- `SmsSdkAppId`
- `SignName`
- `TemplateId`
- `PhoneNumberSet`
- `TemplateParamSet`

`region` / `endpoint` 只用于创建 SDK client，默认值要有，但不进业务逻辑。

### 4. 共享验证码策略

`ttl_minutes` 继续来自 `system_settings.auth.verify_code.ttl_minutes`。

短信模板仍然是验证码模板，不新增第二套 TTL，不新增 brand/app-name 字段。

## 数据模型

### `sms_configs`

| 字段 | 用途 |
|---|---|
| `id` | 主键 |
| `config_key` | 当前配置行标识，默认 `default`，用于唯一配置与软删恢复 |
| `secret_id_enc` | 加密保存腾讯云 `SecretId` |
| `secret_id_hint` | 前端只显示 hint，不回传密文 |
| `secret_key_enc` | 加密保存腾讯云 `SecretKey` |
| `secret_key_hint` | 前端只显示 hint，不回传密文 |
| `sms_sdk_app_id` | `SendSms` 必填 |
| `sign_name` | `SendSms` 必填签名 |
| `region` | SDK client region |
| `endpoint` | SDK HTTP endpoint，默认 `sms.tencentcloudapi.com` |
| `status` | 启用/禁用当前配置 |
| `last_test_at` | 最近一次测试发送时间 |
| `last_test_error` | 最近一次测试失败原因 |
| `is_del` | 软删除 |
| `created_at` | 创建时间 |
| `updated_at` | 更新时间 |

### `sms_templates`

| 字段 | 用途 |
|---|---|
| `id` | 主键 |
| `scene` | 业务场景，和验证码场景字典对齐 |
| `name` | 模板名称，给人看 |
| `tencent_template_id` | 腾讯云模板 ID，发送时真正使用 |
| `variables_json` | 模板变量白名单，运行时校验 |
| `sample_variables_json` | 样例变量，测试发送与列表展示 |
| `status` | 启用/禁用模板 |
| `is_del` | 软删除 |
| `created_at` | 创建时间 |
| `updated_at` | 更新时间 |

验证码模板变量只允许：

```text
code
ttl_minutes
```

### `sms_logs`

| 字段 | 用途 |
|---|---|
| `id` | 主键 |
| `scene` | 发送场景 |
| `template_id` | 本次发送使用的模板 |
| `to_phone` | 收件手机号 |
| `status` | pending / success / failed |
| `tencent_request_id` | 腾讯云请求 ID |
| `tencent_serial_no` | 腾讯云短信流水号 |
| `tencent_fee` | 腾讯云返回的计费条数 |
| `error_code` | 失败码 |
| `error_message` | 失败原因 |
| `duration_ms` | 发送耗时 |
| `sent_at` | 成功发送时间 |
| `is_del` | 软删除 |
| `created_at` | 创建时间 |
| `updated_at` | 更新时间 |

日志只记录事实，不记录短信正文、不记录验证码明文、不记录完整模板参数。

## 发送流程

### 配置保存

1. SecretId / SecretKey 只在后端加密保存。
2. 前端只拿 hint。
3. `sms_sdk_app_id`、`sign_name`、`region`、`endpoint` 都参与真实发送。
4. 配置禁用时，测试发送与真实发送都应明确失败，不做假成功。

### 模板保存

1. `scene` 唯一。
2. 保存软删除场景时恢复旧行，不重复造 row。
3. 变量只接受验证码模板的固定两项。
4. `sample_variables_json` 必须与变量列表完全一致。

### 测试发送

1. 前端输入手机号和场景。
2. 后端读取启用配置。
3. 后端读取启用模板。
4. 后端读取共享 `ttl_minutes`。
5. 后端把手机号校验/归一化成国内短信可用格式。
6. 后端按模板变量组装 `TemplateParamSet`。
7. 调用腾讯云 `SendSms`。
8. 写 `sms_logs`，保存 request id / serial no / `tencent_fee` / duration / status。

### 实际发送

第一期不接 `auth`，但模块要把发送函数做成可复用边界，后续 `auth` 切短信时直接依赖这个 sender 接口即可。

## HTTP API

```text
GET    /api/admin/v1/sms/page-init
GET    /api/admin/v1/sms/config
PUT    /api/admin/v1/sms/config
DELETE /api/admin/v1/sms/config
POST   /api/admin/v1/sms/test

GET    /api/admin/v1/sms/templates
POST   /api/admin/v1/sms/templates
PUT    /api/admin/v1/sms/templates/:id
PATCH  /api/admin/v1/sms/templates/:id/status
DELETE /api/admin/v1/sms/templates/:id

GET    /api/admin/v1/sms/logs
GET    /api/admin/v1/sms/logs/:id
DELETE /api/admin/v1/sms/logs/:id
DELETE /api/admin/v1/sms/logs
```

`page-init` 返回：

- 状态字典
- 短信场景字典
- 地域字典
- 默认 `region` / `endpoint`

## 前端设计

### 路由与菜单

- 路由前缀：`/system/sms`
- 菜单名：`短信管理`
- 权限码前缀：`system_sms_*`

### 页面结构

继续沿用现有邮件页的组件习惯：

- `Search`
- `useCrudTable`
- `AppTable`
- `AppDialog`

#### 配置页

展示：

- SecretId / SecretKey hint
- `sms_sdk_app_id`
- `sign_name`
- `region`
- `endpoint`
- 状态
- 测试发送区

`region` 用后台字典渲染，默认 `ap-guangzhou`。

#### 模板页

表格列建议：

- 场景
- 模板名称
- 腾讯云模板 ID
- 变量列表
- 状态
- 更新时间
- 操作

弹窗里只做必要字段，不加多余杂项。

#### 日志页

表格列建议：

- 场景
- 收件手机号
- 模板名称
- 状态
- RequestId
- SerialNo
- 耗时
- 创建时间

详情里展示模板摘要，但不展示正文和模板参数明文。

## 非目标

- 不做短信签名申请
- 不做短信模板申请
- 不做 webhook / 回执订阅
- 不做重试队列
- 不做多供应商抽象
- 不做营销短信
- 不做国际/港澳台短信
- 不改 `auth/send-code` 现在的手机固定验证码行为

## 验证建议

后端：

```text
go test ./internal/module/sms ./internal/platform/sms/tencentcloudsms ./internal/module/auth
go test ./...
```

前端：

```text
npm run test -- tests/shared/system/sms-api.test.ts
npx vue-tsc -b --pretty false
```

如果后面要落地，再补路由/权限 smoke 与数据库迁移验证。

## 结论

短信管理第一版就应该是：

**独立模块 + 腾讯云发送 + 配置/模板/日志 + 验证码场景收口 + 共享 TTL + 不碰 auth。**

这才是像样的设计，不是把一堆字段堆上去装完整。
