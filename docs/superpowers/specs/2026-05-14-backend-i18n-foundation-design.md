# Backend I18n Foundation Design

日期：2026-05-14
状态：draft for review
范围：`admin_back_go` 后端 i18n 基建、外层错误响应、`admin_front_ts` 请求语言头、根目录 contract/docs

## 目标

把后端 i18n 从“几乎没有”盘活成一个可分阶段收口的基础能力：

```text
前端语言选择 -> HTTP Accept-Language -> Gin i18n middleware -> app error key -> localized response.msg
```

第一刀只做外层基础，不翻译全系统。成功标准是：

```text
响应结构不变：{ code, data, msg }
错误码不变：0 / 100 / 401 / 403 / 404 / 500
HTTP status 不因 i18n 改变
zh-CN 默认行为不破坏现有前端
en-US 请求能看到外层错误英文 msg
后续模块可以按一个模块一个 catalog 文件慢慢收尾
```

## Linus 三问

### 1. 这是真问题吗？

是。当前前端已经有 `vue-i18n`，语言存在 `lang` Cookie；但公共请求头没有把语言传给后端。后端 `response.Error` 又直接把 `apperror.Error.Message` 塞进 `msg`，AuthToken / PermissionCheck / service 错误大量硬编码中文。系统模块越来越多，继续用裸字符串会导致：

```text
重复中文散落各模块
英文 UI 遇到中文后端错误
后续 AI 修改大上下文时容易误改业务语义
无法用测试证明 zh-CN/en-US key 对齐
```

### 2. 有更简单的方法吗？

有。不要搞数据库翻译表，不要让后端接管前端 UI 文案，不要一次性翻译全系统。

最小方案：

```text
使用官方 gin-contrib/i18n middleware
只把 app error 增加内部 message_id
response 层统一翻译 msg
老 fallback 中文继续存在，避免未迁移模块炸掉
catalog 按语言 + 模块拆文件，逐模块迁移
```

### 3. 会破坏什么吗？

设计上不破坏 userspace：

```text
不新增 response 字段
不删除 msg
不改变 code/data/http status
不改变前端当前的中文默认体验
不改变 permission/auth/session 的业务判断
不改 DB schema
```

唯一前端变更是公共请求头新增 `Accept-Language`。这要求后端 CORS 默认允许该 header。

## 官方库取舍

采用：

```text
github.com/gin-contrib/i18n v1.3.0
github.com/nicksnyder/go-i18n/v2/i18n
```

官方能力：

```text
router.Use(ginI18n.Localize(...))
WithBundle 配置 RootPath / AcceptLanguage / DefaultLanguage / FallbackLanguages / FormatBundleFile / UnmarshalFunc
WithGetLngHandle 自定义当前请求语言来源
MustGetMessage / GetMessage 从 gin.Context 取翻译
```

不直接用默认配置。原因：默认 root path 指向测试数据，默认语言不是本项目的 `zh-CN`，且默认文件结构是一种语言一个文件。当前项目模块多，必须支持“一个语言下多个模块文件”。

项目做一个很薄的 `internal/i18n` 包：

```text
internal/i18n                 # 项目 i18n 装配和 helper
internal/i18n/locales/zh-CN   # 中文模块 catalog
internal/i18n/locales/en-US   # 英文模块 catalog
```

仍然用官方 middleware；项目只提供自定义 `Loader` 把一个语言目录下的多个 yaml 文件合并成官方 bundle 需要的 bytes。

## 语言选择规则

请求语言来源：

```text
1. Accept-Language header
2. 空或不支持 -> zh-CN
```

第一期不使用 query 参数，不使用用户资料语言字段，不从 DB 读取。理由：这是后台管理系统，不需要在 API 里引入第三个语言真相源；前端已经用 Cookie 管理当前语言。

支持语言固定：

```text
zh-CN
en-US
```

匹配规则：

```text
zh / zh-CN / zh;q=... -> zh-CN
en / en-US / en;q=... -> en-US
其他 -> zh-CN
```

## Error model

当前：

```go
type Error struct {
    Code       int
    HTTPStatus int
    Message    string
    Cause      error
}
```

新增内部 i18n 字段：

```go
type Error struct {
    Code         int
    HTTPStatus   int
    Message      string
    MessageID    string
    TemplateData map[string]any
    Cause        error
}
```

保留 `Message` 作为 fallback。未迁移模块继续返回中文；已迁移模块使用 key constructor：

```go
apperror.UnauthorizedKey("auth.token.missing", nil, "缺少Token")
apperror.ForbiddenKey("permission.api.denied", nil, "无接口权限")
apperror.BadRequestKey("common.request.invalid", nil, "参数错误")
```

`response.ErrorWithData` 做唯一翻译出口：

```text
err.MessageID 为空 -> 返回 err.Message
err.MessageID 非空且翻译成功 -> 返回翻译
err.MessageID 非空但翻译失败 -> 返回 err.Message
```

这让模块迁移可以一个一个做，不会因为缺 key 导致 panic。

## Catalog 结构

文件结构：

```text
admin_back_go/internal/i18n/locales/zh-CN/common.yaml
admin_back_go/internal/i18n/locales/zh-CN/auth.yaml
admin_back_go/internal/i18n/locales/zh-CN/permission.yaml
admin_back_go/internal/i18n/locales/en-US/common.yaml
admin_back_go/internal/i18n/locales/en-US/auth.yaml
admin_back_go/internal/i18n/locales/en-US/permission.yaml
```

第一刀 key：

```yaml
# common.yaml
common.internal_error: 系统错误
common.request.invalid: 参数错误

# auth.yaml
auth.token.missing: 缺少Token
auth.token.invalid_format: Token格式错误
auth.token.invalid_or_expired: Token无效或已过期
auth.token.authenticator_missing: Token认证未配置

# permission.yaml
permission.checker_missing: 权限检查未配置
permission.api.denied: 无接口权限
permission.code_missing: 权限标识未配置
```

英文对应 key 必须完全一致。测试负责强制 key set 对齐。

## Middleware 顺序

推荐顺序：

```text
Recovery
RequestID
AccessLog
CORS
i18n Localize
AuthToken
PermissionCheck
OperationLog
Handler
```

原因：

```text
CORS 仍然先处理浏览器边界
i18n 必须在 AuthToken 之前，否则缺 Token 这类外层错误无法翻译
OperationLog 不需要参与语言判断
```

## Frontend contract

`admin_front_ts` 公共 header 增加：

```http
Accept-Language: zh-CN | en-US
```

来源仍然是 `Cookies.get('lang') || 'zh-CN'`，和现有 `vue-i18n` 保持同一个真相源。

## Module rollout strategy

本 spec 只覆盖 foundation。后续按模块收口，顺序固定：

```text
1. auth / captcha / session / RBAC outer shell
2. user / profile / user-session / export-task
3. system setting / operation log / system log / upload / client version
4. notification / mail
5. payment
6. AI / realtime
```

每个模块的迁移规则：

```text
一次只迁一个 module
新增该 module 的 zh-CN/en-US catalog 文件
只把 service/handler 的 public app error 改成 keyed error
DB 枚举 label 暂时保持 label 字段不变，下一刀再给 dict 增 i18n_key
模块测试至少覆盖一个 zh-CN fallback 和一个 en-US localized response
```

## Out of scope

```text
不做数据库翻译管理
不翻译历史 operation log 已落库内容
不翻译 DB 里用户输入的 title/name/remark/content
不改变 dict response shape
不新增 response.message_id 字段
不做用户偏好语言字段
不翻译 AI provider 原始错误正文
不在第一刀迁移 payment/AI/mail 全部业务错误
```

## Verification

第一刀完成后必须跑：

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/i18n ./internal/apperror ./internal/response ./internal/middleware ./internal/server

go test ./...

cd E:/admin_go/admin_front_ts
npm run test -- tests/shared/http-language-header.test.ts
npm run typecheck

cd E:/admin_go
git diff --check
```

如果当前工作区还有别的未提交功能改动，不能把它们混进本 i18n 提交。

## Self-review

```text
无 DB schema 变更，避免把 i18n 做成配置系统。
response shape 不变，避免破坏前端 request client。
第一刀只翻译外层错误，范围足够窄。
使用官方 gin-contrib/i18n，但通过项目 Loader 支持模块文件，避免巨型 catalog。
后续模块迁移有固定顺序和测试口径。
```
