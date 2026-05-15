# Payment Config Rebuild V1 Design

日期：2026-05-15  
状态：draft for review  
范围：第一版只重做支付宝支付配置；不做钱包、退款、提现、对账、微信、支付订单重构。

## 1. 结论

这次不是继续修补旧 `payment channel` 页面，而是把支付配置按当前真实产品目标重做成一个干净的支付宝配置切片。

第一版只落地：

```text
支付配置表重构
支付宝证书私有上传
支付宝配置 CRUD
配置启用前校验
配置测试
菜单和权限编码重构
前端支付配置页重做
合同、状态文档、smoke 守卫同步
```

不落地：

```text
钱包
充值入账
支付订单重构
退款
提现
分账
对账
微信支付
商品/套餐/会员等上层业务
```

钱包以后单独做，不能在支付配置表里预留钱包字段。字段如果第一版不用，就不要建。

## 2. Linus 三问

### 2.1 这是真问题吗？

是。当前支付配置仍叫 `channel`，表拆成 `payment_channels` + `payment_channel_configs`，但当前产品只做支付宝。现有字段里有明显坏味道：

```text
provider       # 当前永远 alipay，表名已能表达，不应入库
sign_type      # 当前固定 RSA2，代码常量即可
merchant_id    # 当前支付链路没有真实使用
extra_config   # 未使用的 JSON 垃圾桶
```

前端还要求用户手填服务器证书路径。这不是产品能力，是运维事故入口。

### 2.2 更简单的方法是什么？

第一版只做一个专门的支付宝配置表：

```text
payment_configs
```

一张表表达一个真实概念。私钥加密入库，证书上传到后端私有目录，配置启用/测试时做本地校验。

### 2.3 会破坏什么吗？

会破坏旧支付菜单和权限编码。这次允许破坏，但必须可控：

```text
/payment/channel -> /payment/config
payment_channel_* -> payment_config_*
旧 payment_channels/payment_channel_configs 不再作为 active runtime 表
旧 payment_order/event 菜单暂时从菜单隐藏或退役，等后续支付订单 slice 重做
```

不能破坏登录、RBAC、动态菜单、operation log 脱敏和现有非支付模块。

## 3. 当前运行事实

Live DB 当前 active payment 表只有：

```text
payment_channels
payment_channel_configs
payment_orders
payment_events
```

当前菜单权限存在：

```text
DIR  payment              支付管理
PAGE payment_channel_list /payment/channel
PAGE payment_order_list   /payment/order
PAGE payment_event_list   /payment/event
BTN  payment_channel_add/edit/status/del
BTN  payment_order_close
```

当前 Go runtime 证据：

```text
admin_back_go/internal/module/payment
admin_back_go/internal/platform/payment/alipay
admin_front_ts/src/api/payment/channel.ts
admin_front_ts/src/views/Main/payment/channel
```

当前合同仍写 `payment_channels, payment_channel_configs, payment_orders, payment_events`。本 slice 完成后，支付配置合同必须改成 `payment_configs`。

## 4. 第一版表设计

### 4.1 新表：payment_configs

```sql
CREATE TABLE `payment_configs` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `provider` VARCHAR(32) NOT NULL DEFAULT 'alipay',
  `code` VARCHAR(64) NOT NULL,
  `name` VARCHAR(128) NOT NULL,
  `app_id` VARCHAR(64) NOT NULL,
  `private_key_enc` TEXT NOT NULL,
  `private_key_hint` VARCHAR(64) NOT NULL DEFAULT '',
  `app_cert_path` VARCHAR(512) NOT NULL DEFAULT '',
  `platform_cert_path` VARCHAR(512) NOT NULL DEFAULT '',
  `root_cert_path` VARCHAR(512) NOT NULL DEFAULT '',
  `notify_url` VARCHAR(512) NOT NULL DEFAULT '',
  `return_url` VARCHAR(512) NOT NULL DEFAULT '',
  `environment` VARCHAR(16) NOT NULL DEFAULT 'sandbox',
  `enabled_methods_json` JSON NOT NULL,
  `status` TINYINT NOT NULL DEFAULT 2,
  `remark` VARCHAR(255) NOT NULL DEFAULT '',
  `is_del` TINYINT NOT NULL DEFAULT 2,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_payment_configs_code` (`code`),
  KEY `idx_payment_configs_provider_status` (`provider`, `status`, `is_del`),
  KEY `idx_payment_configs_environment` (`environment`, `is_del`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

项目约定：

```text
is_del: 1 deleted, 2 normal
status: 1 enabled, 2 disabled
environment: sandbox, production
enabled_methods_json: ["web", "h5"]
```

### 4.2 每个字段为什么存在

| 字段 | 第一版用途 | 不用时处理 |
| --- | --- | --- |
| id | 后台 CRUD 主键、RBAC 操作对象 | 必用 |
| provider | 支付供应商，当前固定 alipay，用于筛选/展示/测试分发 | 必用，不支持其他值 |
| code | 稳定编码、证书目录名、后续订单引用候选 | 创建后不可改 |
| name | 后台展示、选择配置 | 必用 |
| app_id | 支付宝 SDK 初始化 | 必用 |
| private_key_enc | 支付宝签名私钥，secretbox 加密 | 必用 |
| private_key_hint | 前端展示私钥是否已配置，不泄漏明文 | 必用 |
| app_cert_path | SetCertSnByPath 应用公钥证书 | 必用 |
| platform_cert_path | 回调验签和 SetCertSnByPath 支付宝公钥证书 | 必用 |
| root_cert_path | SetCertSnByPath 根证书 | 必用 |
| notify_url | 支付宝异步通知地址 | 必用 |
| return_url | web/h5 同步返回地址 | 必用，可为空字符串 |
| environment | 沙箱/正式环境切换 | 必用 |
| enabled_methods_json | web/h5 支付方式开关 | 必用 |
| status | 是否允许作为支付配置使用 | 必用 |
| remark | 后台备注 | 必用，可为空字符串 |
| is_del | 软删基础字段 | 必用 |
| created_at | 创建时间基础字段 | 必用 |
| updated_at | 更新时间基础字段 | 必用 |

明确不建：

```text
provider      # 表就是 alipay config
sign_type     # 固定 RSA2，代码常量
merchant_id   # 第一版没有真实行为
extra_config  # 垃圾桶字段，禁止
created_by / updated_by # 当前支付配置没有用户审计消费；operation log 已记录操作者
cert_content  # 证书正文不入库
cert_url      # 证书不暴露公网 URL
```

### 4.3 旧表处理

本 slice 把旧 `payment_channels`、`payment_channel_configs`、`payment_orders`、`payment_events` 从 live DB 和 active runtime 移除。

迁移策略：

```text
1. 创建 payment_configs。
2. 从 payment_channels + payment_channel_configs 迁移 provider=alipay 且 is_del=2 的配置。
3. code/name/status/supported_methods/private_key/certs/notify/return/environment 做确定性映射。
4. 迁移后执行 `20260515_payment_config_only_cleanup.sql`，删除旧 payment_channel/payment_order/payment_event 权限、旧 payment 订单 cron 行，并 drop 旧 payment channel/order/event 表。
5. 执行前备份旧表和旧权限到 `.tmp/payment-config-only-cleanup-backup-*.json`，后续支付订单 slice 从新 spec 重新建表，不继承旧表结构。
```

注意：这不是保留旧设计。旧表只在 rebuild migration 里作为迁移来源；cleanup 后 live DB 只保留 `payment_configs`。

## 5. 证书上传设计

### 5.1 上传入口

```text
POST /api/admin/v1/payment/certificates
```

入参：

```text
cert_type: app_cert | alipay_cert | alipay_root_cert
config_code: payment_configs.code，新增表单未保存时可用前端当前 code
file: .crt / .pem 文本证书文件
```

返回：

```json
{
  "path": "runtime/payment/certs/alipay/alipay_default/<sha256>.crt",
  "file_name": "appCertPublicKey.crt",
  "sha256": "...",
  "size": 1234
}
```

### 5.2 存储规则

证书保存到后端私有目录：

```text
runtime/payment/certs/alipay/<config_code>/<sha256>.crt
```

规则：

```text
只存相对路径到 DB
不走 COS
不走通用 upload token
不生成公网 URL
不提供下载接口
API 和 worker 分开部署时，该目录必须是共享 volume
```

### 5.3 安全规则

```text
只允许 payment_config_upload_cert 权限上传
文件大小限制，例如 64KB
只接受 PEM/CRT 文本证书
拒绝空文件、二进制大文件、路径穿越文件名
operation log 不记录证书正文
响应不返回证书正文
```

## 6. API 设计

### 6.1 支付配置 CRUD

```text
GET    /api/admin/v1/payment/configs/page-init
GET    /api/admin/v1/payment/configs
POST   /api/admin/v1/payment/configs
PUT    /api/admin/v1/payment/configs/:id
PATCH  /api/admin/v1/payment/configs/:id/status
DELETE /api/admin/v1/payment/configs/:id
```

### 6.2 证书和测试

```text
POST   /api/admin/v1/payment/certificates
POST   /api/admin/v1/payment/configs/:id/test
```

`test` 第一版只做本地可确定校验：

```text
解密私钥成功
私钥非空且格式可解析
三个证书路径存在、可读、非目录
SetCertSnByPath 成功
environment 合法
enabled_methods_json 至少包含 web 或 h5
notify_url 非空且 http/https
```

不在第一版测试真实扣款，不调用真实支付宝下单。

## 7. 权限和菜单重构

### 7.1 菜单

保留根目录：

```text
DIR 支付管理
code: payment
path: empty
component: empty
i18n_key: menu.payment
```

新增/替换页面：

```text
PAGE 支付配置
path: /payment/config
component: payment/config
code: payment_config_list
i18n_key: menu.payment.config
show_menu: 1
```

第一版隐藏或退役旧页面：

```text
/payment/channel
/payment/order
/payment/event
```

订单和事件等后续支付能力 slice 重做后再重新进入菜单。

### 7.2 按钮权限编码

```text
payment_config_list
payment_config_add
payment_config_edit
payment_config_status
payment_config_del
payment_config_upload_cert
payment_config_test
```

旧编码退役：

```text
payment_channel_list
payment_channel_add
payment_channel_edit
payment_channel_status
payment_channel_del
payment_order_list
payment_order_close
payment_event_list
```

### 7.3 角色授权迁移

为了不破坏现有管理员可见性：

```text
已有 payment_channel_list 授权 -> payment_config_list
已有 payment_channel_add 授权 -> payment_config_add + payment_config_upload_cert + payment_config_test
已有 payment_channel_edit 授权 -> payment_config_edit + payment_config_upload_cert + payment_config_test
已有 payment_channel_status 授权 -> payment_config_status
已有 payment_channel_del 授权 -> payment_config_del
```

超级管理员仍按现有 RBAC 规则拿全部权限。

## 8. 后端模块设计

仍在 `internal/module/payment`，但命名收口：

```text
Config model
ConfigHandler / config request DTO
ConfigService
ConfigRepository
CertificateUploadService 或 service 内独立方法
```

调用方向保持：

```text
route -> handler -> service -> repository -> model
```

支付宝 SDK 仍只能在：

```text
internal/platform/payment/alipay
```

业务 service 只能通过明确接口调用，不直接 import 第三方 SDK。

## 9. 前端设计

### 9.1 文件

```text
admin_front_ts/src/api/payment/config.ts
admin_front_ts/src/views/Main/payment/config/index.vue
admin_front_ts/src/views/Main/payment/config/composables/usePaymentConfigPage.ts
```

旧文件退役：

```text
src/api/payment/channel.ts
src/views/Main/payment/channel/*
```

### 9.2 页面结构

页面名：支付配置。

表单分组：

```text
基础信息：code、name、environment、status、enabled_methods_json、remark
支付宝参数：app_id、app_private_key、notify_url、return_url
证书上传：app_cert、alipay_cert、alipay_root_cert
操作：保存、启用/禁用、测试配置
```

展示规则：

```text
私钥只显示 private_key_hint
编辑时私钥留空表示不修改
证书显示相对路径/文件名，不展示正文
上传证书后把返回 path 写入表单对应字段
```

## 10. 验证策略

后端最小验证：

```powershell
cd E:\admin_go\admin_back_go
$env:GOMAXPROCS='2'
go test -p=1 ./internal/module/payment ./internal/platform/payment ./internal/bootstrap ./internal/server
powershell -ExecutionPolicy Bypass -File .\scripts\check-contract.ps1
git diff --check
```

前端最小验证：

```powershell
cd E:\admin_go\admin_front_ts
$env:NODE_OPTIONS='--max-old-space-size=2048'
npx vitest run tests/shared/payment/payment-config-api.test.ts
npx vue-tsc -b --pretty false
npx eslint src/api/payment/config.ts src/views/Main/payment/config --ext .ts,.vue
git diff --check
```

Smoke 更新：

```text
full-admin-smoke.ps1 改为探测 /payment/config 菜单、payment_config_* 权限、configs page-init/list/test shape。
默认 smoke 不上传真实证书、不调用真实支付宝下单。
```

## 11. 文档同步

必须同步：

```text
docs/contracts/admin-api-v1.md
docs/status/current-status.md
docs/testing/smoke-matrix.md
admin_back_go/docs/architecture.md
```

旧 `payment channel` 说法必须从 active docs 里退掉。可以作为历史计划保留，但不能继续指导冷启动。

## 12. 后续 slice

第一版完成后，后续按顺序做：

```text
1. payment order v1：基于 payment_configs 创建本地支付订单并拉起支付宝 web/h5
2. payment notify v1：支付宝回调验签、幂等事件、订单状态推进
3. wallet recharge v1：用户钱包、充值单、支付成功入账
```

仍然不做退款、提现、对账、微信，除非另开 spec。

## 13. Spec 自检

- 无未完成项。
- 每个新表字段都有第一版用途。
- 第一版只做支付宝支付配置，不把钱包和订单混进来。
- 旧表只作为迁移来源，cleanup 后 live DB 只保留支付配置表。
- 菜单、权限、API、前端文件名都从 channel 收口到 config。
