# Backend Fallback Audit 2026-06-01

## Outcome

本次只处理 Go 后端里最明确的契约兜底，不把布尔条件、分页默认值、运行时默认配置一刀切删除。

已处理：

- AI provider API 不再接受/返回 `driver` / `driver_name` 这组 `engine_type` 的兼容别名。
- AI provider create/update/model-options 必须使用规范字段 `engine_type`，空值不再静默归一为 `openai`。
- AI provider list 的空 `engine_type` 查询条件保持为空，不再由 service 默认改成 `openai`。
- AI provider DTO 不再把 DB 里的空 `health_status` / `last_model_sync_status` 静默改成 `unknown`；读到非法 `engine_type`、health/model-sync status、common status 或 model status 时 fail closed，暴露数据异常。
- Upload config DTO / setting dict 不再把历史非 COS driver 渲染成空 label 或 bucket-name fallback；active 读路径遇到未知 driver fail closed。
- Mail/SMS runtime `VerifyCodeTTL` 不再在配置行缺失时静默返回 5 分钟；page-init 的默认 TTL 只作为后台表单种子，运行时缺配置显式失败。

保留：

- config / scheduler / token / logging 里的 code-owned defaults：这些是运行时配置默认，不是接口契约兜底。
- `base_url_effective`：当前表示 OpenAI 默认 endpoint 的显式派生字段；后续如果前端不再需要，可单独删。
- health/model-sync 的 `unknown` 初始状态：创建供应商时写入状态机初始值；从 DB 读出时不再用 `emptyAs(..., unknown)` 伪装历史脏数据。
- mail/sms region/endpoint defaults：只在 create/update/page-init 边界作为腾讯云 provider-owned 默认值，不作为运行时缺配置兜底。

## Scan snapshot

Production Go scan under `admin_back_go/internal`:

```text
fallback_word: 82
default_word: 488
empty_as/nonEmpty/driver-normalizer-like helpers: 17
unknown_literal: 9
blank_default_assign: 67
```

Top hotspots:

```text
admin_back_go/internal/config/config.go
admin_back_go/internal/module/ai/knowledge/service.go
admin_back_go/internal/module/sms/service.go
admin_back_go/internal/module/mail/service.go
admin_back_go/internal/infra/ai/openaicompat/client.go
admin_back_go/internal/module/ai/provider/service.go
admin_back_go/internal/module/ai/image/service.go
```

## Classification

```text
config defaults          keep: code-owned runtime defaults
pagination defaults      keep: API query behavior
state-machine defaults   keep if written on create, audit if invented on read
compat aliases           delete: hide contract drift
empty-to-provider guess   delete at API boundary
infra SDK defaults        audit separately: may be valid constructor defaults
```

## Verification

Targeted RED/GREEN:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/ai/provider -count=1
go test ./internal/module/ai/provider ./internal/server ./internal/shared/i18n -count=1
```

The first targeted run failed before implementation because blank `engine_type` defaulted to `openai` and provider DTO still exposed driver aliases. It passes after the fix.

Second targeted RED/GREEN:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/ai/provider -count=1 -run TestListRejectsInvalidStoredProviderStateInsteadOfInventingDTOFallback
go test ./internal/module/ai/provider -count=1
```

The RED run proved list DTO previously returned a normal-looking response when stored `engine_type` was blank, health/model-sync status was blank, provider status was invalid, or provider model status was invalid. It now returns an explicit internal data error instead of inventing labels/defaults.

Additional RED/GREEN:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/uploadconfig -count=1 -run 'TestDriverListRejectsUnknownStoredDriverInsteadOfBlankLabel|TestSettingPageInitRejectsUnknownStoredDriverInsteadOfOptionFallback|TestSettingListRejectsUnknownStoredDriverInsteadOfBucketFallback'
go test ./internal/module/uploadconfig -count=1
go test ./internal/module/mail ./internal/module/sms -count=1 -run 'TestServiceVerifyCodeTTLRejectsMissingConfig|TestVerifyCodeTTLRejectsMissingSmsConfig'
```

The uploadconfig RED run proved active non-COS stored drivers were previously returned as blank labels or bucket-name labels. The mail/sms RED run proved runtime TTL previously used `5m` when config rows were missing.

Live DB guard before the second fix:

```sql
SELECT COUNT(*) AS bad_status_rows
FROM ai_providers
WHERE health_status='' OR health_status IS NULL
   OR last_model_sync_status='' OR last_model_sync_status IS NULL;

SELECT COUNT(*) AS bad_provider_rows
FROM ai_providers
WHERE engine_type NOT IN ('openai')
   OR status NOT IN (1,2)
   OR health_status NOT IN ('unknown','ok','failed')
   OR last_model_sync_status NOT IN ('unknown','ok','failed');

SELECT COUNT(*) AS bad_model_rows
FROM ai_provider_models
WHERE status NOT IN (1,2);
```

All three counts were `0` on local live MySQL (`127.0.0.1:3307/admin`), so the fail-closed change does not mask a known local data migration gap.

## Next backend candidates

Do not batch these blindly:

- `internal/infra/ai/openaicompat/client.go`: `nonEmpty(input.BaseURL, c.baseURL)` and default base URL need an infra-client-specific decision.
- `internal/module/ai/image/service.go`: image defaults are business defaults; only remove if request contract requires explicit size/quality/format.
- `internal/module/mail/service.go` / `internal/module/sms/service.go`: `sample_variables_json = null`, zero required timestamps, and log rows with missing templates still need separate read-side decisions.
- `internal/module/ai/chat/service.go`: empty upstream answer, unknown history roles, and invalid current-message `meta_json` need a separate TDD pass.
- `internal/module/ai/image/service.go`: unknown task status and invalid `actual_params_json` need a separate TDD pass.
