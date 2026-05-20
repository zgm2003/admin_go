# Upload Runtime env 收口设计

日期：2026-05-20
状态：draft
范围：`admin_back_go` 上传运行时、COS STS signer、Docker-first env 模板、系统设置 seed、相关文档和测试

## 目标

这次只做 **upload runtime env cleanup**，不重做上传配置 CRUD，不引入 OSS，不改前端上传页面结构。

要达到的结果：

1. Docker-first env 不再暴露上传运行时内部开关和实现细节。
2. 后台上传配置表继续作为 COS bucket、密钥、上传地域、写入端点、访问域名的唯一事实源。
3. `UPLOAD_TOKEN_TTL` 迁到 `system_settings`，让“临时上传凭证有效期”可在后台调整。
4. `UPLOAD_KEY_RANDOM_BYTES` 代码内置，不让用户配置对象 key 随机字节数。
5. `COS_STS_ENABLED` 删除，不再出现“后台 COS 已启用但 env 总开关没开导致不可用”的双事实源。
6. `COS_STS_ENDPOINT` / `COS_STS_REGION` 代码内置，避免用户把 STS API region 和 COS bucket region 混在一起。

## Linus 三问

1. 这是真问题吗？
   - 是。当前 env 里同时暴露 `UPLOAD_*` 和 `COS_STS_*`，而上传配置页已经维护真实 COS 配置。用户看到两个 region、两个启用概念会误配。
2. 有更简单的做法吗？
   - 有。只收上传运行时这一组 env：TTL 进系统设置，随机字节和 STS API 参数内置，上传配置表保持不变。
3. 会破坏已有前端、接口、登录和权限吗？
   - 不应该。`POST /api/admin/v1/upload-tokens` 的请求/响应契约不变，前端仍用 `cos-js-sdk-v5` 直传，上传配置页面字段不变。

## 当前事实

### 上传配置表已经保存业务上传事实

上传配置模块的 driver model 已经保存：

- `secret_id_enc`
- `secret_key_enc`
- `bucket`
- `region`
- `appid`
- `endpoint`
- `bucket_domain`

这些字段对应后台页面“编辑上传驱动”里的：

- SecretId
- SecretKey
- Bucket
- Region
- APPID
- COS 写入端点
- 访问域名

运行时签发上传 token 时，`uploadtoken.Service` 从 enabled upload setting 读取 driver/rule，解密 SecretId/SecretKey，然后把表里的 `Bucket` / `Region` / `AppID` 传给 COS STS signer。

### 当前 env 仍暴露上传运行时内部项

Docker-first env 当前还有：

```env
UPLOAD_TOKEN_TTL=15m
UPLOAD_KEY_RANDOM_BYTES=8
COS_STS_ENABLED=false
COS_STS_ENDPOINT=sts.tencentcloudapi.com
COS_STS_REGION=ap-guangzhou
```

这些键的问题不同：

| env key | 当前含义 | 问题 | 目标 |
| --- | --- | --- | --- |
| `UPLOAD_TOKEN_TTL` | 临时上传凭证有效期 | 业务策略，不该只能改 env | 迁到 `system_settings.upload.token.ttl_minutes` |
| `UPLOAD_KEY_RANDOM_BYTES` | 对象 key 随机后缀字节数 | 实现细节，用户不该配 | 内置常量，默认 8 bytes |
| `COS_STS_ENABLED` | 是否创建真实 STS signer | 和后台“启用上传设置”形成双开关 | 删除，signer 默认可用，是否能签由 enabled upload config 决定 |
| `COS_STS_ENDPOINT` | 腾讯云 STS API endpoint | 基本固定，且不是 COS bucket endpoint | 内置 `sts.tencentcloudapi.com` |
| `COS_STS_REGION` | 腾讯云 STS API request region / `X-TC-Region` | 容易和 bucket region 混淆 | 内置 `ap-guangzhou`，不展示给用户 |

### 两个 region 必须区分

本项目里有两个不同概念：

1. `upload_config.region`
   - 来源：上传配置表/后台上传配置页面。
   - 示例：`ap-nanjing`。
   - 含义：COS bucket 所在地域。
   - 用途：前端直传 `cos.putObject`、COS object read/write bucket URL、STS policy resource 中的 `qcs::cos:<bucket-region>:...`。
   - 必须继续由用户配置。

2. 当前 env 的 `COS_STS_REGION`
   - 来源：env。
   - 示例：`ap-guangzhou`。
   - 含义：腾讯云 STS API 请求 region / SDK `CredentialOptions.Region` / `X-TC-Region`。
   - 不是 bucket region，不参与前端上传 bucket 地域。
   - 不应该暴露给普通部署用户。

## 选型

### 方案 A：只迁 `UPLOAD_TOKEN_TTL`，其余保留 env

优点：

- 改动最小。

缺点：

- env 仍然很长。
- `COS_STS_ENABLED` 仍会让后台启用配置失效。
- `COS_STS_REGION` 继续误导用户，以为它要和 bucket region 一致。

不推荐。

### 方案 B：upload runtime env 一次收口（推荐）

内容：

- `UPLOAD_TOKEN_TTL` -> `system_settings.upload.token.ttl_minutes`
- `UPLOAD_KEY_RANDOM_BYTES` -> 代码常量 `8`
- `COS_STS_ENABLED` -> 删除
- `COS_STS_ENDPOINT` -> 代码默认常量
- `COS_STS_REGION` -> 代码默认常量

优点：

- env 明显变短。
- 上传配置表成为唯一的上传事实源。
- 后台启用 COS 后即可请求临时凭证，不再受隐藏 env 总开关阻断。
- 用户不再看到容易混淆的 STS region。

缺点：

- 如果未来需要私有化 STS endpoint 或特殊 STS region，需要发版或另做专门配置，不再靠 env 热改。

推荐采用。

### 方案 C：把 `COS_STS_ENDPOINT` / `COS_STS_REGION` 放入上传配置表

不采用。

原因：

- 它们不是 bucket 配置，也不是访问域名或写入端点。
- 放进上传配置页面会让用户以为每个 bucket 都有一套 STS endpoint/region。
- 当前项目只支持腾讯云 COS，STS API endpoint/region 作为 provider 实现细节更适合内置在 `platform/storage/cos`。

### 方案 D：把所有上传项都放入 `system_settings`

不采用。

原因：

- SecretId/SecretKey/Bucket/Region/APPID 已经有专门的上传配置表和加密逻辑。
- `system_settings` 不能变成密钥或 provider 配置 dumping ground。
- 本次只把真正的业务策略 `upload.token.ttl_minutes` 放入系统设置。

## 推荐设计

### 1. 系统设置新增 upload token TTL

新增系统设置 key：

```text
upload.token.ttl_minutes
```

默认值：

```text
15
```

value_type：

```text
2  -- number
```

备注：

```text
上传临时凭证有效期分钟数
```

读取规则：

- 正数分钟才有效。
- 缺失、禁用、非数字、<=0 时使用代码默认 15 分钟。
- 不在 env 里继续保留 `UPLOAD_TOKEN_TTL`。

边界：

- 该 TTL 只控制浏览器直传 COS 的临时凭证有效期。
- 不控制文件下载有效期。
- 不控制服务端 COS object writer/reader 超时。
- 不控制 Redis token/session TTL。

### 2. 对象 key 随机字节数内置

`UPLOAD_KEY_RANDOM_BYTES` 删除。

代码常量：

```text
defaultUploadTokenKeyRandomBytes = 8
```

理由：

- 它只是 object key 随机后缀强度。
- 不是后台业务配置。
- 用户改小会增加同毫秒碰撞风险，改大也没有可见产品价值。

### 3. 删除 COS STS env 总开关

`COS_STS_ENABLED` 删除。

实现后：

- bootstrap 默认创建真实 `storagecos.NewSigner(...)`。
- 上传 token 是否能签发由 enabled upload setting + COS driver + 有效 SecretId/SecretKey/Bucket/Region/APPID 决定。
- 如果没有启用上传配置，继续返回“未配置有效上传设置”。
- 如果上传配置启用但腾讯云 STS 请求失败，继续返回“COS 临时凭证签发失败”。

需要同步调整：

- full smoke 中“`COS_STS_ENABLED=false` 时跳过 upload token shape probe”的口径要改掉。
- 文档中“真实上传需要 enabled COS setting + `COS_STS_ENABLED=true`”要改成“真实上传需要 enabled COS upload setting + 有效腾讯云凭据”。

### 4. STS endpoint/region 内置在 COS platform 层

`COS_STS_ENDPOINT` 删除。

内置默认：

```text
sts.tencentcloudapi.com
```

`COS_STS_REGION` 删除。

内置默认：

```text
ap-guangzhou
```

实现位置：

- `internal/platform/storage/cos/signer.go`

语义：

- 这些是 Tencent STS API 的调用参数。
- 不进入上传配置表。
- 不进入系统设置。
- 不影响上传配置表里的 `region`。

### 5. `UploadTokenConfig` 收窄

当前 `config.Config.UploadToken` 可以删除或极度收窄。

推荐实现方向：

- 删除 `UploadTokenConfig` / `COSSTSConfig` env 结构。
- upload token service 通过 policy provider 读取 TTL。
- signer 的 endpoint/region 使用 `storagecos.NewSigner(storagecos.Config{})` 默认值。
- object reader/writer 不再使用 `cfg.UploadToken.COS.Enabled` 控制启用；它们默认启用，真实可用性仍由 upload config repository 返回的 COS 配置决定。

如果为了最小改动保留内部 options，也必须保证它不再从 env 读取上述五个键。

### 6. 保持上传配置页面不变

不改前端上传配置页面字段：

- 驱动：腾讯云 COS
- SecretId
- SecretKey
- Bucket
- Region
- APPID
- COS 写入端点（可留空）
- 访问域名

其中 `Region` 继续指 COS bucket region，例如 `ap-nanjing`。

不新增：

- STS Endpoint 输入框
- STS Region 输入框
- STS Enabled 开关
- Key random bytes 输入框

## 迁移范围

### 需要改

后端仓 `admin_back_go`：

- `internal/config/config.go`
- `internal/config/config_test.go`
- `internal/bootstrap/app.go`
- `internal/bootstrap/worker.go`
- `internal/module/uploadtoken/service.go`
- `internal/module/uploadtoken/service_test.go`
- `internal/platform/storage/cos/signer.go` 和相关测试（如需让默认常量更明确）
- 新增或复用上传 token policy provider，读取 `system_settings.upload.token.ttl_minutes`
- 新增 migration：seed `system_settings.upload.token.ttl_minutes`
- `deploy/docker-first/admin-go.env.example`
- 本地 ignored 的 `deploy/docker-first/admin-go.env` 如果存在，也同步删除这五个键
- `README.md`

根仓 `admin_go`：

- `docs/status/current-status.md`
- `docs/testing/smoke-matrix.md`
- `docs/contracts/admin-api-v1.md`
- `docs/deployment/docker-first-backend.md`
- 相关 Superpowers plan

前端仓 `admin_front_ts`：

- 默认不改。
- 只有当系统设置页需要专门文案或可见入口时才改；本切片不新增专门上传 token TTL UI。

### 不改

- 上传配置表结构。
- 上传驱动 CRUD API。
- 上传规则 CRUD API。
- 上传设置启用事务。
- 前端 `src/lib/upload/uploadClient.ts` 的直传协议。
- `POST /api/admin/v1/upload-tokens` 的请求/响应字段。
- COS object writer/reader 的 Bucket/Region/Endpoint 输入语义。
- AI 图片、客户端版本、导出任务等服务端 COS 上传业务契约。
- OSS optional extension，不恢复、不引入。

## 数据迁移

新增 migration 示例：

```sql
SET NAMES utf8mb4;

INSERT INTO `system_settings` (`setting_key`, `setting_value`, `value_type`, `remark`, `status`, `is_del`)
VALUES
  ('upload.token.ttl_minutes', '15', 2, CONVERT(UNHEX('E4B88AE4BCA0E4B8B4E697B6E587ADE8AF81E69C89E69588E69C9FE58886E9929FE695B0') USING utf8mb4), 1, 2)
ON DUPLICATE KEY UPDATE
  `setting_value` = CASE
    WHEN `setting_value` IS NULL OR TRIM(`setting_value`) = '' THEN VALUES(`setting_value`)
    ELSE `setting_value`
  END,
  `value_type` = 2,
  `remark` = VALUES(`remark`),
  `status` = 1,
  `is_del` = 2,
  `updated_at` = CURRENT_TIMESTAMP;
```

说明：

- 使用 `CONVERT(UNHEX(...))` 是为了避免 Windows/客户端编码导致中文 remark 乱码。
- 已存在且非空的 `setting_value` 不覆盖，保护用户现场配置。
- `status` / `is_del` 会恢复为启用和正常，保证策略可读。

## 行为保持

不改变：

- `POST /api/admin/v1/upload-tokens` route。
- bearer token current-user upload capability。
- 不记录 OperationLog 的规则。
- COS-only runtime。
- STS policy 只授权当前生成 object key。
- 返回 `provider/bucket/region/key/upload_path/bucket_domain/credentials/start_time/expired_time/rule` 的响应形状。
- 上传配置里的 `bucket_domain` 裸域名规则。

行为变化：

- 删除 `COS_STS_ENABLED=false` 后，只要后台存在 enabled COS upload setting 且凭据有效，上传 token 会实际请求腾讯云 STS。
- 没有 enabled upload setting 时仍不会请求腾讯云。
- 开发/测试环境如果没有真实腾讯云凭据，upload token shape smoke 不能再靠 env disabled 自动跳过；应改为“无 enabled upload setting 则验证明确错误，有 enabled setting 才做 token shape 或 credential-gated 验证”。

## 错误处理

保留现有错误语义：

- 未配置有效上传设置：`uploadtoken.setting_missing`
- 非 COS runtime：`uploadtoken.cos_runtime_disabled`
- 上传密钥不可用：`uploadtoken.secret_unavailable`
- 上传配置不完整：`uploadtoken.config_incomplete`
- COS 临时凭证签发失败：`uploadtoken.cos_sign_failed`

`uploadtoken.cos_sts_disabled` 的处理：

- 删除 env 总开关后，正常运行时不应再触发。
- 测试里可保留 `DisabledSigner` 用于单元测试 signer disabled 分支。
- 对外文档不再把它作为部署配置分支说明。

## 测试要求

实现阶段至少跑：

```powershell
cd E:\admin_go\admin_back_go
go test -count=1 ./internal/config ./internal/bootstrap ./internal/module/uploadtoken ./internal/module/uploadconfig ./internal/platform/storage/cos
```

如改到服务端 COS 上传启用逻辑，再补：

```powershell
go test -count=1 ./internal/module/exporttask ./internal/module/clientversion ./internal/module/aiimage
```

根仓治理：

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

如用户要求 Docker runtime fresh verification，再补：

```powershell
cd E:\admin_go\admin_back_go\deploy\docker-first
docker compose config --quiet
docker compose up -d --build admin-api admin-worker
```

然后验证：

- `/health`
- `/ready`
- 上传配置页面能打开
- 无 enabled upload setting 时 upload token 返回明确配置错误
- 有真实 COS setting 时 upload token 返回临时凭证 shape

## 文档要求

需要把以下口径统一：

1. env 只保留部署拓扑、连接、密钥、日志、队列、实时、CORS 等真正环境参数。
2. 上传 token TTL 来自 `system_settings.upload.token.ttl_minutes`。
3. COS bucket、SecretId、SecretKey、Region、APPID、endpoint、bucket_domain 来自后台上传配置。
4. Tencent STS API endpoint/region 是代码内置实现细节，不是用户部署配置。
5. 不再要求 `COS_STS_ENABLED=true`。

## 风险

- 删除 `COS_STS_ENABLED` 后，如果某个环境配置了 enabled COS upload setting 但凭据是假的，请求 upload token 会尝试访问腾讯云并失败；这是正确暴露配置错误，不再静默跳过。
- 如果未来真的需要私有 STS endpoint 或多云/专线特殊 region，需要新增专门设计，不应提前把实现细节放回 env。
- `upload.token.ttl_minutes` 如果被用户设置过小，前端上传大文件可能在上传中途凭证过期；服务端需只接受正数，文档建议保持默认 15 分钟。
- 本切片不做真实文件上传 smoke；真实上传仍依赖用户腾讯云凭据、bucket CORS 和网络环境。

## 审阅清单

请重点确认：

1. 是否接受删除 `COS_STS_ENABLED`，让 enabled upload setting 成为唯一启用事实源。
2. 是否接受 `COS_STS_ENDPOINT` / `COS_STS_REGION` 完全内置，不进上传配置表，也不进系统设置。
3. 是否接受只把 `UPLOAD_TOKEN_TTL` 放入系统设置，而 `UPLOAD_KEY_RANDOM_BYTES` 内置。
4. 是否保持前端上传配置页面不新增 STS 字段。
