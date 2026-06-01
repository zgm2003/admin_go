# Fallback Audit and Cleanup Design

## Linus 三问

1. **真问题还是假问题？**
   真问题。当前 Go/Vue/Canvas 已经进入多平台契约期，`??`、`||`、`?.`、alias DTO 和空对象兜底会把后端契约漂移、迁移漏执行、字段误删都吞掉。

2. **有更简单的做法吗？**
   有。不要全项目机械替换。按数据边界分层：先清 API/DTO/auth/RBAC 这些契约边界，再清页面状态，再处理纯 UI 输入归一化。

3. **会破坏已有前端、接口、登录和权限吗？**
   会，如果把合法业务规则也删掉。因此每一批必须先写 RED guard，确认当前确实在隐藏契约问题，再最小实现。

4. **为什么这个状态会出现？**
   之前为了“先跑起来”在前端和 HTTP client 里补默认值，导致数据 owner 不清楚。现在三端 `users/me` DTO 已统一，继续兜底就是架构债。

## 需求判断

这是值得做的治理，但不能当格式化任务做。`||` 在 Go 里大量是布尔校验，不是兜底；`?.` 在用户输入、DOM/axios error、可选 UI 配置里可能是合法边界。真正要禁止的是：

- API envelope 明明规定有 `msg`，前端却用本地文案替代。
- HTTP error interceptor 收到标准 API envelope 时，不能把空 `msg` 替换成 axios message 或本地 i18n message。
- DTO 明明规定有字段，前端类型却写成 optional，然后用 `?.` / `?? []` 继续渲染。
- 请求 helper 明明由调用方决定 body/params，却自动补 `{}` 或改成 `undefined`。
- 多平台字段明明统一，却用 alias 兼容 `user_id/userId/id`、`buttonCodes/button_codes`。

## 数据结构原则

### 1. API envelope

后端响应 envelope 是：

```text
code
msg
data
```

如果 `code != 0`，`msg` 必须是非空字符串。前端 HTTP client 不能发明 `"请求失败"` 来掩盖后端错误 catalog 缺失。

### 2. Current-user DTO

三端 `users/me` 当前用户 DTO 是：

```text
user_id
username
avatar
role_name
permissions
router
buttonCodes
```

前端不能接受 alias 或 optional shape。权限菜单里的 `children` 由后端 `json:"children"` 明确返回，前端类型不应写 `children?`。

### 3. Request helper

HTTP helper 不拥有业务默认值。调用方传什么 body/params，helper 就发送什么；要过滤空查询参数，调用方必须显式调用 `compactApiParams`。

## 扫描事实

2026-06-01 对 active TS/Vue/Canvas source 只读扫描：

```text
matched files: 239
|| count: 1094
?? count: 176
?. count: 681
```

热点主要集中在：

```text
canvas_front_next/src/app/(user)/canvas/[id]/canvas-client-page.tsx
canvas_front_next/src/app/(user)/image/page.tsx
canvas_front_next/src/app/(user)/video/page.tsx
canvas_front_next/src/services/api/video.ts
canvas_front_next/src/services/api/image.ts
admin_front_ts/src/lib/http/client.ts
admin_front_ts/src/lib/http/auth-session.ts
admin_front_ts/src/store/user.ts
admin_front_ts/src/types/user.ts
```

## 分批策略

### Batch 1: 契约边界

先清：

- `admin_front_ts/src/lib/http/envelope.ts`
- `admin_front_ts/src/lib/http/client.ts`
- `admin_front_ts/src/lib/http/auth-session.ts`
- `admin_front_ts/src/types/user.ts`
- `admin_front_ts/src/store/user.ts`
- `canvas_front_next/src/services/api/request.ts`

目标：API envelope、current-user/RBAC、Canvas request helper 不再静默兜底。

### Batch 2: Canvas AI API

再清：

- `canvas_front_next/src/services/api/image.ts`
- `canvas_front_next/src/services/api/video.ts`
- `canvas_front_next/src/services/api/error-payload.ts`

目标：AI image/video 的错误 envelope、模型选择、尺寸/质量参数只能来自明确配置或明确输入规则，不能从多个字段猜。

### Batch 3: Canvas page state

再拆：

- `canvas_front_next/src/app/(user)/canvas/[id]/canvas-client-page.tsx`
- `canvas_front_next/src/app/(user)/image/page.tsx`
- `canvas_front_next/src/app/(user)/video/page.tsx`

目标：页面状态巨大文件里的 `||`/`?.` 按 state machine 收敛。这里必须先拆小函数或 composable，否则直接替换只会制造新 bug。

### Batch 4: Admin feature pages

最后按模块清：

- AI chat/run/provider/agent 页面
- system mail/sms/upload/export 页面
- reusable table/search/remote-select 组件

目标：只保留明确业务默认值，删除接口契约兜底和旧字段兼容。

## 非目标

- 不机械删除所有 `||`。布尔条件、范围校验、合法空输入过滤不是这刀的敌人。
- 不把所有 UI 默认文案删掉。网络断开、浏览器 API 不可用、用户未输入属于合法边界。
- 不一次性重写 Canvas 大页面。先加 guard，再拆函数，再改行为。

## 已完成的首批治理

- Admin HTTP envelope 新增 `requireApiMessage`，错误 envelope `msg` 为空时 fail closed。
- Admin HTTP error interceptor 对标准 API envelope 复用 `requireApiMessage`；本地 `Unauthorized` / `Request failed` 只用于非 envelope 的传输失败。
- Admin current-user permission tree 前端类型要求 `children`，store 遍历不再用 `children?.`。
- Canvas request helper 不再使用 `params ||`、`body ?? {}`、`payload.msg ||`。
