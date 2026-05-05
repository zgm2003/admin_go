# Account Security Design Spec

状态：planned for current slice
日期：2026-05-05

## Linus 三问

```text
1. 真问题：个人资料安全区的手机号、邮箱、密码仍走 PHP legacyRequest，Go/Vue 新项目的 profile 闭环不完整。
2. 更简单方法：不新建大 auth 模块，不做管理员代改密码，只在 user/profile 模块补当前登录用户自己的安全写接口。
3. 会破坏什么：不能改表结构；不能改登录/Users/init/RBAC；不能把验证码或密码明文写进日志；不能让真实 smoke 改掉测试账号密码、手机号、邮箱。
```

## Scope

本切片只迁移当前登录后台用户的账号安全设置：

```text
PUT /api/admin/v1/profile/security/password
PUT /api/admin/v1/profile/security/email
PUT /api/admin/v1/profile/security/phone
```

保留已有读接口：

```text
GET /api/admin/v1/profile
```

`GET /profile` 已返回 `email`、`phone`、`has_password`、`verify_type_arr`，安全页不额外新增 GET，避免重复接口。

## Non-goals

```text
不做管理员替别人改密码。
不做登录密码找回；forgetPassword 仍是后续 auth slice。
不新增表，不改 users 表结构。
不新增 session 踢下线能力；改密后是否撤销其他 session 标记为 planned。
不新增专属 send-code 接口；本切片继续复用 POST /api/admin/v1/auth/send-code，但安全写接口必须认证并消费验证码。
不做真实短信/邮件 sender；当前 dev code 规则继续沿用 auth 模块。
```

## Architecture

账号安全放在 `internal/module/user`，因为当前个人资料页面、`GET /profile`、用户表字段都已经归属 user/profile 模块。验证码缓存能力继续复用 auth 模块的 `CodeStore`，但 user service 不依赖 `auth.Service`，只依赖一个很小的 `VerifyCodeStore` 接口和公共 key helper。

调用链保持：

```text
route -> handler -> service -> repository -> model
```

边界：

```text
handler：只解析 token identity + JSON body。
service：校验当前用户、校验密码/验证码、判重、生成 bcrypt hash、决定写哪些字段。
repository：只查 users、判重、更新 users 字段。
auth code store：只读/删验证码 key，不知道业务规则。
```

## API Contract

### Update password

```text
PUT /api/admin/v1/profile/security/password
Auth: bearer token
Permission: only login identity; no user-manager button permission
OperationLog: module=profile_security, action=update_password, title=修改登录密码
```

Body：

```ts
type UpdatePasswordBody =
  | {
      verify_type: 'password'
      old_password: string
      new_password: string
      confirm_password: string
    }
  | {
      verify_type: 'code'
      account: string
      code: string
      new_password: string
      confirm_password: string
    }
```

规则：

```text
new_password 和 confirm_password 必须一致。
新密码长度 6-128。
verify_type=password 时，当前用户必须已有密码，old_password 必须正确。
verify_type=code 时，account 必须等于当前用户已绑定的 email 或 phone，并用 change_password 场景消费验证码。
密码写入 users.password，使用 bcrypt，并保存为 $2y$ 前缀以维持旧 PHP bcrypt 习惯。
```

### Update email

```text
PUT /api/admin/v1/profile/security/email
Auth: bearer token
Permission: only login identity
OperationLog: module=profile_security, action=update_email, title=绑定或换绑邮箱
```

Body：

```ts
interface UpdateEmailBody {
  email: string
  code: string
}
```

规则：

```text
email 必须是合法邮箱。
验证码使用 bind_email 场景，account=email，成功后消费。
email 不能被其他未删除用户占用。
更新 users.email。
```

### Update phone

```text
PUT /api/admin/v1/profile/security/phone
Auth: bearer token
Permission: only login identity
OperationLog: module=profile_security, action=update_phone, title=绑定或换绑手机号
```

Body：

```ts
interface UpdatePhoneBody {
  phone: string
  code: string
}
```

规则：

```text
phone 必须匹配 ^1[3-9]\d{9}$。
验证码使用 bind_phone 场景，account=phone，成功后消费。
phone 不能被其他未删除用户占用。
更新 users.phone。
```

## Enum / Dict / Validate

`verify_type_arr` 不能继续由 user service 私有硬编码。新增：

```text
internal/enum/user.go: VerifyTypePassword, VerifyTypeCode, IsUserVerifyType
internal/dict/dict.go: UserVerifyTypeOptions()
internal/validate/user.go: user_verify_type validator tag
```

`ProfileResponse.dict.verify_type_arr` 从 dict 派生。

## Frontend

`src/views/Main/personal/components/Security/index.vue` 保持现有单组件，不为了这次迁移拆 UI。原因：当前组件职责仍然单一（个人资料安全设置）且没有复用需求；拆 composable 会扩大 diff。

必须改：

```text
UsersApi.updatePhone -> PUT /api/admin/v1/profile/security/phone
UsersApi.updateEmail -> PUT /api/admin/v1/profile/security/email
UsersApi.updatePassword -> PUT /api/admin/v1/profile/security/password
```

密码验证码模式前端必须传 `account: passwordAccount`，让后端显式校验账号属于当前用户，不让后端猜。

## Error Policy

```text
参数错误：统一返回 code=100。
用户不存在：404。
验证码错误或过期：验证码错误或已失效。
重复手机号/邮箱：手机号已被绑定 / 邮箱已被绑定。
旧密码错误：旧密码错误。
未绑定邮箱或手机号却用验证码改密：请先绑定邮箱或手机号。
验证码缓存未配置或 Redis 失败：明确内部错误，不 fallback 成成功。
```

## Operation Log

三条安全写接口都要显式 route metadata。安全字段由已有 operationlog sanitizer mask：

```text
password, old_password, new_password, confirm_password, code, token, captcha_answer
```

如果 sanitizer 缺字段，必须补测试，不允许日志泄漏。

## Tests

后端单元测试：

```text
UpdatePasswordWithOldPassword writes bcrypt hash and validates old password.
UpdatePasswordWithCode consumes change_password code for owned email/phone account.
UpdateEmail consumes bind_email code and rejects duplicate email.
UpdatePhone consumes bind_phone code and rejects duplicate phone.
Profile dict verify_type_arr comes from enum/dict order.
Handler security routes bind current identity and reject legacy/invalid payloads.
Route metadata includes operation logs and no permission rule for self security routes.
```

前端验证：

```text
vue-tsc for touched TS/Vue files.
eslint targeted files.
No any / as any / Record<string, any> in touched code.
```

Smoke：

```text
full-admin-smoke 只做失败探针，不修改真实账号安全数据：
- wrong old password returns code=100
- invalid email code returns code=100
- invalid phone code returns code=100
```

## Risks

```text
公共 auth/send-code 目前是 public，绑定场景验证码也能发。写接口仍然必须登录态并验证账号归属/目标账号，第一版可接受；后续可做 profile/security/*/code 登录态专属发送接口。
改密后不踢其他 session 是安全欠账，但需要 session manager 增强，不能塞进本切片。
```
