# Canvas Front Next 集成设计 Spec

日期：2026-05-31
状态：本轮实现已完成并通过 Task 12 验证；后端全量测试、Next test/typecheck/build、live DB 查询、full-admin-smoke 和 root governance gates 已通过。
范围：新增 `canvas_front_next` Next.js 前端，并把 `E:\GitDownload\infinite-canvas` 的可用业务能力接入 `admin_go` Go 后端。当前不改 `admin_front_ts` 的支付菜单；支付/钱包能力按已完成的 admin 基线复用。

---

## 0. 一句话结论

别把 `infinite-canvas` 的后端搬过来当第二套系统。正确做法是：

```text
canvas_front_next 只做 Next.js 前端
admin_back_go 负责 auth / RBAC / wallet / AI provider / billing / prompt library / asset library
```

新增 auth platform：

```text
code: canvas
name: 无限画布
```

余额只认 `user_wallets.balance_cents`，扣费只走 `ai_billing_records` + `wallet_transactions`。原项目的 `users`、`credit_logs`、`settings` 全部不迁入。

---

## 1. Linus 三问

### 1.1 这是真问题吗？

是。`infinite-canvas` 当前有自己的登录、用户积分、系统设置、AI 渠道、后台管理。直接保留就是两套用户、两套钱、两套配置。后面任何商业化产品都会被这坨东西拖死。

### 1.2 更简单的方法是什么？

砍掉重复系统，只留下画布业务本身：

```text
登录 -> admin_go auth platform = canvas
权限 -> admin_go RBAC platform = canvas
余额 -> admin_go wallet
AI 配置 -> admin_go AI provider + agent + billing rules
提示词/素材公共库 -> admin_go canvas module
画布项目本地存储 -> 先保留 localForage，不急着造云同步表
```

### 1.3 会破坏什么吗？

会，主要是这几类：

- 如果保留 `credit_logs`，钱包事实源就被破坏。
- 如果保留原 `settings`，AI provider 和 agent 配置会分叉。
- 如果 canvas 前端继续允许用户填 API key，本系统的渠道、计费、审计全废。
- 如果先造 `canvas_projects` 云同步表，却没有当前产品需求，就是垃圾字段和垃圾表。
- 如果 Grok 被做成单独“渠道商配置”，会和现有 `ai_providers` 重复。

---

## 2. 当前调研事实

### 2.1 `E:\GitDownload\infinite-canvas` 后端

当前后端是 Go/Gin/GORM。迁移模型只有五类：

```text
users
credit_logs
prompts
assets
settings
```

当前路由核心：

```text
POST /api/auth/register
POST /api/auth/login
GET  /api/auth/me
POST /api/v1/chat/completions
POST /api/v1/images/generations
POST /api/v1/images/edits
POST /api/v1/videos
GET  /api/v1/videos/:id
GET  /api/v1/videos/:id/content
GET/POST/DELETE /api/admin/users|credit-logs|prompts|assets|settings
```

### 2.2 `infinite-canvas` 前端

`web/package.json` 当前已经是新栈：

```text
Next 16.2.3
React 19.2.5
Ant Design 6
Tailwind CSS 4
Zustand 5
TanStack Query 5
Vitest 4
```

`canvas_front_next` 应基于这套前端重开项目；实施当天如果 `create-next-app` 生成版本更高，以官方脚手架锁定版本为准，但不要为了追版本重写业务。

### 2.3 原项目真正要保留的业务

要保留：

```text
无限画布 UI / 交互
文本/图片/视频生成体验
提示词公共库
素材公共库
本地画布项目 localForage + 导入导出
```

不保留：

```text
原 users
原 credit_logs
原 settings
原 admin 后台
原用户手动配置渠道/API key 的 local/custom channel 模式
原积分文案和积分余额事实源
```

---

## 3. 架构选择

### 3.1 推荐方案：Next 前端 + admin_go 后端

```text
canvas_front_next -> /api/canvas/v1/* -> admin_back_go
```

优点：

- 只有一套 auth/session/RBAC。
- 只有一套钱包余额和账务流水。
- AI provider、agent、billing rule 都复用当前 admin 配置。
- 原 Go 后端不用长期运维。

### 3.2 拒绝方案：保留 infinite-canvas 后端做微服务

可以短期作为对照运行，但不能长期作为 runtime。原因很简单：它自带 `users/settings/credit_logs`，天然会和本系统冲突。要把它改成纯业务微服务，删掉的东西比留下的还多，不如直接把能力落进 `admin_back_go`。

### 3.3 不做 BFF 代理偷懒

`canvas_front_next` 不应该写一堆 Next Route Handler 去代理老后端。认证、计费、provider 调用都必须在 Go 后端闭环；Next 只做前端渲染和少量 server action/route 适配，不保存密钥，不碰钱包。

---

## 4. Auth / RBAC 设计

### 4.1 auth platform

新增 `auth_platforms` 行：

```text
code = canvas
name = 无限画布
login_types = password/email/sms 按当前系统能力选择
captcha_type = slide
allow_register = 1 或按产品要求配置
status = 1
is_del = 2
```

`admin` 和 `app` 的登录本质已经是同一套核心逻辑。`canvas` 也是同样逻辑，不复制认证服务。

### 4.2 HTTP 入口

新增 canvas transport，路径统一：

```text
GET  /api/canvas/v1/auth/login-config
GET  /api/canvas/v1/auth/captcha
POST /api/canvas/v1/auth/send-code
POST /api/canvas/v1/auth/login
GET  /api/canvas/v1/users/me
POST /api/canvas/v1/auth/logout
```

实现要求：

```text
优先复用 internal/module/auth/transport/app 的 Prefix+Platform 注册模式
内部复用 auth session service
token platform 必须是 canvas
不得调用 admin transport handler
必须补 /api/canvas/v1/auth/* skip paths 和 /api/canvas/v1/* 默认 platform=canvas
登录页必须先读 login-config；登录方式、slide captcha、allow_register 都以后端为准
登录页必须按 login_type_arr 渲染 email/phone/password 登录方式；email/phone 调 `/api/canvas/v1/auth/send-code` 后用 code 登录；password 点击登录后再弹 slide captcha，不把验证码常驻嵌进表单
allow_register 只控制验证码登录自动开户，不代表 Canvas 有独立注册页；不得臆造 /api/canvas/v1/auth/register
```

### 4.3 RBAC

Canvas 平台权限是 `permissions.platform = canvas`，不是塞进 admin 菜单。

第一版只需要这些能力级权限：

```text
canvas_access
canvas_prompt_read
canvas_asset_read
canvas_ai_text_generate
canvas_ai_image_generate
canvas_ai_video_generate
canvas_wallet_read
canvas_recharge_add
canvas_recharge_pay
```

不要为每个按钮造 20 个权限。canvas 前端没有 admin 左侧菜单，权限只用于 API gate 和功能开关。

---

## 5. AI 配置和 Grok/xAI 决策

### 5.1 三个 canvas 场景

已在支付整改中进入 AI 计费场景选项：

```text
canvas_text_generate
canvas_image_generate
canvas_video_generate
```

这些价格配置属于：

```text
AI 管理 -> 智能体配置 -> 场景计费
```

不属于支付管理，也不属于 canvas 前端用户设置。

### 5.2 agent 绑定

每个 canvas 场景从现有 `ai_agents.scenes_json` 中选择启用 agent：

```text
无限画布-文本 -> canvas_text_generate
无限画布-生图 -> canvas_image_generate
无限画布-视频 -> canvas_video_generate
```

前端只拿“可用能力”和模型展示名，不拿 provider key、base_url、系统提示词明文。

### 5.3 Grok/xAI 不新增渠道商表

不新增 `grok_configs`、`xai_channels`、`canvas_model_channels`。

如果 Grok/xAI 当前接口可按 OpenAI-compatible 调用，就在现有表里配置：

```text
ai_providers.name = xAI / Grok
ai_providers.engine_type = openai
ai_providers.driver = openai
ai_provider_models.model_id = grok-...
```

如果视频接口和现有 OpenAI-compatible 图片/聊天不一致，只在 `internal/infra/ai` 增加窄的 video adapter 方法，不增加新配置表。表不为供应商膨胀，代码 adapter 可以为真实差异存在。

---

## 6. 钱包和 AI 计费接入

### 6.1 唯一余额

Canvas 前端所有“积分/余额”展示都来自钱包：

```text
GET /api/canvas/v1/wallet/summary
GET /api/canvas/v1/wallet/transactions
```

文案可以叫“余额”或“点数”，但 DB 只有：

```text
user_wallets
wallet_transactions
```

### 6.2 充值

Canvas 用户充值走 payment 模块的 canvas transport：

```text
GET  /api/canvas/v1/payment/recharges/page-init
GET  /api/canvas/v1/payment/recharges
POST /api/canvas/v1/payment/recharges
POST /api/canvas/v1/payment/recharges/:id/pay
```

不暴露手动同步和关闭：

```text
不做 /sync
不做 /close
不让用户替系统擦屁股
```

### 6.3 扣费

生成前预扣：

```text
文本：scene=canvas_text_generate, unit=request, unit_count=1
图片：scene=canvas_image_generate, unit=image, unit_count=n
视频：scene=canvas_video_generate, unit=second, unit_count=duration_seconds
```

每次生成创建 `ai_billing_records(platform=canvas)`，钱包流水：

```text
支出：wallet_transactions(direction=out, source_type=ai_generate, source_id=ai_billing_records.id)
退款：wallet_transactions(direction=in, source_type=ai_refund, source_id=ai_billing_records.id)
```

`ai_billing_records` 继续不加 `is_del`。账务事实不能软删除。

---

## 7. Canvas 业务表

第一版只引入当前原项目公共库会用到的表。

### 7.1 `canvas_prompts`

```text
id bigint unsigned pk
slug varchar(191) unique
category varchar(191)
title varchar(191)
cover_url varchar(1024)
prompt text
preview varchar(512)
tags_json json
source_url varchar(1024)
status tinyint      1 enabled / 2 disabled
is_del tinyint      1 deleted / 2 active
created_at datetime
updated_at datetime
```

索引：

```text
uk_canvas_prompts_slug(slug)
idx_canvas_prompts_category_status(category, status, is_del, updated_at, id)
idx_canvas_prompts_status_updated(status, is_del, updated_at, id)
```

### 7.2 `canvas_assets`

```text
id bigint unsigned pk
slug varchar(191) unique
type varchar(16)      text / image
category varchar(191)
title varchar(191)
cover_url varchar(1024)
description varchar(512)
content text          text asset 用
url varchar(1024)     image asset 用
tags_json json
status tinyint
is_del tinyint
created_at datetime
updated_at datetime
```

索引：

```text
uk_canvas_assets_slug(slug)
idx_canvas_assets_type_status(type, status, is_del, updated_at, id)
idx_canvas_assets_status_updated(status, is_del, updated_at, id)
```

### 7.3 不建这些表

```text
canvas_users
canvas_credit_logs
canvas_settings
canvas_model_channels
canvas_projects
canvas_wallets
```

理由：

- 用户、余额、配置都有现成事实源。
- 画布项目当前原前端用 localForage，本轮不做跨设备云同步。
- 如果以后明确要云同步，再单独 spec `canvas_projects`，不要现在预埋。

---

## 8. Canvas API

### 8.1 Public/user API

```text
GET  /api/canvas/v1/settings
GET  /api/canvas/v1/prompts
GET  /api/canvas/v1/assets
GET  /api/canvas/v1/wallet/summary
GET  /api/canvas/v1/wallet/transactions

POST /api/canvas/v1/ai/chat/completions
POST /api/canvas/v1/ai/images/generations
POST /api/canvas/v1/ai/images/edits
POST /api/canvas/v1/ai/videos
GET  /api/canvas/v1/ai/videos/:id
GET  /api/canvas/v1/ai/videos/:id/content
```

`settings` 只返回前端需要的公开能力：

```text
allow_register display snapshot only; login/register policy must still read auth/login-config
available_scenes
available_models display only
billing_rule price snapshot for UI display
wallet summary optional
```

不返回：

```text
api_key
base_url
provider raw config
admin-only settings
```

### 8.2 Admin 管理 API

如果要继续管理提示词/素材公共库，放到 admin 后台的新模块。本文只定义接口边界；当前执行计划第一轮不做 `admin_front_ts` Canvas CRUD 页面，Vue 管理页应作为单独窄切片按 Search + AppTable + AppDialog + useCrudTable、i18n、route metadata 和菜单迁移落地：

```text
GET    /api/admin/v1/canvas/prompts/page-init
GET    /api/admin/v1/canvas/prompts
POST   /api/admin/v1/canvas/prompts
PUT    /api/admin/v1/canvas/prompts/:id
PATCH  /api/admin/v1/canvas/prompts/:id/status
DELETE /api/admin/v1/canvas/prompts/:id

GET    /api/admin/v1/canvas/assets/page-init
GET    /api/admin/v1/canvas/assets
POST   /api/admin/v1/canvas/assets
PUT    /api/admin/v1/canvas/assets/:id
PATCH  /api/admin/v1/canvas/assets/:id/status
DELETE /api/admin/v1/canvas/assets/:id
```

菜单：

```text
AI 管理 或 内容管理 下增加：Canvas 提示词 / Canvas 素材
```

不新增“Canvas 管理”一级菜单，除非后续 canvas 模块变成多个管理页面。本轮若只落 backend API，不得声称 admin Vue 管理页面已实现。

---

## 9. `canvas_front_next` 改造边界

### 9.1 保留

```text
App Router 页面结构
画布交互组件
localForage 画布项目存储
导入/导出
Zustand UI 状态
图片/视频/文本生成 UX
```

### 9.2 删除/替换

```text
/api/auth/* old client -> /api/canvas/v1/auth/*
/api/v1/* old AI proxy -> /api/canvas/v1/ai/*
/api/settings old settings -> /api/canvas/v1/settings
credits UI -> wallet balance UI
用户 API key / custom channel 设置 -> 删除
/admin/* 页面 -> 删除，不迁到 canvas_front_next
```

### 9.3 前端安全边界

```text
不在浏览器保存 provider API key
不允许用户自定义 base_url
不暴露 admin token
不复用 admin_front_ts 路由
canvas token 的 platform 必须是 canvas
```

---

## 10. 分阶段路线

### Phase 0：合同测试和事实锁定

- 后端 architecture test 锁死：不得出现 `canvas_credit_logs`、`canvas_settings`、`canvas_users`。
- 前端测试锁死：不得调用旧 `/api/auth`、旧 `/api/v1`、旧 credits API。

### Phase 1：auth platform + canvas auth transport

- 新增 `auth_platforms.canvas` migration。
- 新增 `/api/canvas/v1/auth/*` 和 `/users/me`。
- RBAC platform 增加 `canvas` 权限上下文。

### Phase 2：钱包/充值 canvas transport

- 新增 `/api/canvas/v1/wallet/*`。
- 新增 `/api/canvas/v1/payment/recharges*`。
- 复用 payment/wallet service，不复制代码。

### Phase 3：canvas prompts/assets backend

- 新增 `internal/module/canvas`。
- 新增 `canvas_prompts`、`canvas_assets`。
- 后台 CRUD + canvas public list。

### Phase 4：AI generation + billing

- 文本/图片/视频生成统一走 `ai_billing_records(platform=canvas)`。
- 余额不足不调用 provider。
- provider 创建失败或视频最终失败，幂等退款。

### Phase 5：`canvas_front_next`

- 从 `E:\GitDownload\infinite-canvas\web` 迁出前端。
- 删除旧 auth/settings/credits/admin 页面。
- 接入 `/api/canvas/v1/*`。
- UI 显示钱包余额和充值入口。

### Phase 6：smoke 和 live DB

- auth 登录、钱包、充值、文本/图/视频扣费、失败退款、提示词/素材列表全链路 smoke。
- live DB 验证没有 canvas 重复表。

---

## 11. 验收标准

```text
canvas_front_next 能用 canvas 平台登录/注册/读取当前用户
canvas_front_next 不再出现原积分 API 和 credit_logs 文案
canvas_front_next 不允许用户配置 API key/base_url
生成文本/图片/视频前会按 ai_billing_rules 预扣钱包余额
余额不足不会调用 provider
失败会按 ai_billing_records 幂等退款
Grok/xAI 作为 ai_providers 的 openai-compatible 配置使用，不新增供应商表
数据库只新增当前使用的 canvas_prompts/canvas_assets 和必要 auth/RBAC seed
不新增 canvas_users/canvas_credit_logs/canvas_settings/canvas_projects
```

---

## 12. Spec 自检

- 没有第二套用户、积分、钱包、设置表。
- 没有把价格配置塞进支付菜单。
- 没有把 Grok 做成独立配置体系。
- 没有为云同步预建 `canvas_projects`。
- 所有新增表都有当前 API 调用方。
- `canvas_front_next` 是新前端，不是老后端微服务壳。
