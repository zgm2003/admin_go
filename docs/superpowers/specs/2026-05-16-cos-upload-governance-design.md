# COS-only Upload Governance Design

Status: approved design direction, docs-only
Date: 2026-05-16
Scope: `admin_back_go`, `admin_front_ts`, upload config DB/runtime, upload-token client upload, server-side COS upload

## Why this exists

Upload is core infrastructure. The current project already runs as COS-only in the real upload paths, but the configuration surface still pretends there are multiple drivers. That is bad taste: it creates fake choices, weakens validation, and makes failures harder to explain.

Linus three questions:

```text
1. Is this a real problem? Yes. Runtime is COS-only, but UI/API still expose OSS.
2. Is there a simpler way? Yes. Make Tencent COS the only upload backend for now.
3. What can this break? Active upload uses COS; disabled OSS rows are not active runtime. Preserve soft-delete semantics and do not drop storage columns yet.
```

## Decision

Use **Tencent Cloud COS only** for upload V1.

No OSS, S3, Qiniu, local disk, MinIO, or generic cloud-driver abstraction in this phase. Future providers must be introduced by a new design/spec after there is a real product need.

The accepted implementation direction is the hard-convergence option:

```text
A. Hard converge to COS-only.
```

Meaning:

- Backend enum/dict/validation exposes only `cos`.
- Frontend type/options/form expose only `cos`.
- Runtime rejects any non-COS upload config with a clear error.
- Existing OSS config rows are removed from active runtime via soft delete / disabled state, not by unsafe physical deletion.
- Documentation, contracts, tests, and copy all say COS-only.

## Non-goals

Do not implement these in this slice:

- Alibaba OSS runtime.
- S3-compatible abstraction.
- Multi-cloud driver plugin architecture.
- Local disk upload runtime.
- Browser-side provider selection.
- Cross-cloud migration tooling.
- COS object deletion UI or garbage collection.
- Resumable upload UI beyond what COS SDK already provides.

## Authoritative concepts

### Upload config fields

`upload_driver` remains the runtime config table for now, but only COS rows are valid active config.

Required COS fields:

```text
driver          = cos
secret_id_enc   = encrypted Tencent SecretId
secret_key_enc  = encrypted Tencent SecretKey
bucket          = COS bucket name, for example zgm-1314542588
region          = COS region, for example ap-nanjing
appid           = Tencent appid, for example 1314542588
```

Optional COS fields:

```text
endpoint        = COS write endpoint override; advanced field; normally empty
bucket_domain   = access domain; bare domain only, for example cos.zgm2003.cn
```

Hard rule:

```text
bucket_domain must be stored as a bare host. Do not store http:// or https://.
```

The final public URL is constructed by runtime code:

```text
https://{bucket_domain}/{key}
```

If `bucket_domain` is empty, fall back to Tencent's COS host:

```text
https://{bucket}.cos.{region}.myqcloud.com/{key}
```

### Folder and file policy

Only backend-owned folder names are valid. Current allowed folders stay in backend enum until a separate cleanup decides otherwise:

```text
avatars
images
videos
cover_images
ai-agents
ai_chat_images
releases
tauri_updater
exports
reconcile_reports
```

The frontend may request a folder and file metadata, but it must not choose the final COS object key.

## Upload flow 1: client token upload

Use this for user/browser-originated files:

```text
avatar images
manual image upload
AI reference images
AI mask images
ordinary frontend attachments
```

Flow:

```text
1. Frontend validates local file shape enough for UX.
2. Frontend calls Go upload-token API with folder, file_name, file_size, and file_kind.
3. Backend validates folder, extension, size, active COS config, and file kind.
4. Backend generates the COS key.
5. Backend signs a Tencent COS temporary credential scoped to that exact key.
6. Frontend uploads the file to COS with cos-js-sdk-v5.
7. Frontend constructs the public URL from returned config + key.
8. Frontend sends key/url to the owning business API.
9. Business API persists key/url in its own table.
```

Rules:

- One upload token is for one object key.
- Token TTL defaults to current runtime config, currently 15 minutes unless changed by env.
- Temporary credential policy must only allow the intended object path.
- Frontend must not receive permanent SecretId/SecretKey.
- Frontend must not mutate object keys after token issuance.
- Upload success does not mean business persistence success; the business API owns the final DB write.

## Upload flow 2: server-side COS upload

Use this for backend-produced artifacts:

```text
export files
AI generated image archives
server-generated reports
Tauri update manifests and packages
batch job artifacts
```

Flow:

```text
1. Backend business job generates bytes or a stream.
2. Backend loads the enabled COS config.
3. Backend writes the object with the Tencent COS Go SDK boundary.
4. Backend constructs the public URL using the same URL contract.
5. Backend persists the result in the owning business table.
6. Backend marks the job success or failed with a concrete error.
```

Rules:

- All blocking COS operations must accept `context.Context`.
- No unowned goroutines are allowed inside upload logic.
- Worker concurrency is controlled by the existing queue/runtime, not by ad-hoc goroutines in upload code.
- A business task must not write multiple contradictory final URLs.
- On upload failure, persist a failure state or return a localized backend error; do not swallow the error.

## Object key naming

The key is a contract, not a UI detail.

### Client uploads

Current shape is preserved:

```text
{folder}/{yyyy}/{mm}/{dd}/{timestamp_ms}-{random_hex}-{safe_original_name}
```

Example:

```text
avatars/2026/05/16/1778908976527-38c0d8de1f10e877-3.png
```

Rules:

- `folder` must be from backend enum.
- `safe_original_name` is the basename only, not a path.
- Random suffix is backend-generated.
- Filename and extension are normalized before validation.

### Server exports

Current export shape is preserved:

```text
exports/{yyyyMMdd}/{kind}_{yyyyMMdd_HHmmss}_{task_id}.xlsx
```

### AI generated images

Current AI image shape is preserved:

```text
ai-images/{yyyy}/{mm}/{dd}/{task_id}-{index}-{random_hex}.{ext}
```

## Concurrency and size rules

### Client-side concurrency

For V1, the frontend should treat uploads as bounded work:

```text
single file upload = one token + one COS object
multi-file upload = at most 3 concurrent uploads per component/session
```

No silent infinite retry. User-triggered retry is allowed.

If the COS SDK switches from simple upload to advanced/sliced upload, that remains an SDK detail. Business code still owns only token request, key, URL, and persistence.

### Server-side concurrency

For server-side uploads:

```text
queue worker controls job concurrency
COS SDK call uses the request/job context
upload package does not start background goroutines
service returns wrapped errors with context
```

If a future large-file path needs bounded parallelism, it must live behind a small Go interface and have table-driven tests plus cancellation coverage.

## Error semantics

Errors must be explicit and product-readable.

Required messages / meanings:

```text
No enabled COS config:
  当前未配置腾讯云 COS 上传

Non-COS config selected or encountered:
  当前仅支持腾讯云 COS，请重新配置 COS

bucket_domain contains scheme:
  访问域名请填写裸域名，例如 cos.example.com

Token signing failed:
  COS 临时凭证签发失败

Server upload failed:
  COS 文件上传失败

Object uploaded but cannot be opened through custom domain:
  检查自定义域名 CNAME、HTTPS 证书和 DNS 生效状态
```

For API responses, use localized backend error keys, not raw SDK text as the only user-facing message.

## Backend change set

Expected backend implementation scope:

1. `internal/enum/upload.go`
   - Remove `UploadDriverOSS` from active enum/dict.
   - Keep only `UploadDriverCOS` in `UploadDrivers` and labels.

2. `internal/module/uploadconfig`
   - Driver init returns COS only.
   - Create/update rejects any non-COS driver.
   - Remove OSS-only required `role_arn` validation path.
   - Validate `bucket_domain` as host-only: no `http://`, no `https://`, no path.
   - Keep `endpoint` as advanced optional write endpoint.

3. `internal/module/uploadtoken`
   - Keep COS-only runtime rejection.
   - Ensure returned `bucket_domain` is host-only.
   - Keep one-token-one-key signing.

4. `internal/module/exporttask`, `internal/module/aiimage`, client-version publisher paths
   - Keep COS-only server upload.
   - Reuse one public URL contract.
   - Do not add new provider branches.

5. Migration / data cleanup
   - Soft-delete or disable existing OSS upload settings and drivers.
   - Do not physically drop columns or historical rows in this slice.
   - Keep active COS config untouched except for normalizing `bucket_domain` to host-only.

## Frontend change set

Expected frontend implementation scope:

1. `src/api/system/uploadConfig.ts`
   - Change `UploadDriverType` to `'cos'` only.
   - Query normalization only accepts `cos`.

2. Upload driver page
   - Remove OSS option and OSS field branch.
   - Make driver fixed/default COS or a disabled COS-only select.
   - Preserve COS fields: SecretId, SecretKey, bucket, region, appid, endpoint, bucket_domain.
   - Copy says bucket domain is a bare domain, not a URL.

3. Shared upload client
   - Keep `Provider = 'cos'`.
   - Keep URL builder adding `https://` when domain has no scheme.
   - Consider tightening tests so config form rejects schemes while URL builder still tolerates legacy values defensively.

4. UX copy
   - Remove "OSS unsupported" from normal configuration path.
   - If a stale API response returns non-COS, show "当前仅支持腾讯云 COS".

## Tests and verification

Backend focused tests:

```text
internal/enum upload driver dict returns COS only
uploadconfig create/update rejects oss
uploadconfig rejects bucket_domain with scheme/path
uploadtoken rejects non-COS enabled config
public COS URL builder adds https:// to bare bucket_domain
server upload paths keep COS-only behavior
```

Frontend focused tests:

```text
upload config API type/source no longer accepts oss
upload driver page no longer renders OSS branch
copy says bucket_domain is bare domain
upload URL builder keeps no-scheme contract
```

Minimum verification commands after implementation:

```powershell
# backend
cd E:\admin_go\admin_back_go
go test ./internal/enum ./internal/module/uploadconfig ./internal/module/uploadtoken ./internal/module/exporttask ./internal/module/aiimage ./internal/platform/storage/cos

# frontend
cd E:\admin_go\admin_front_ts
npx vitest run tests/shared/system/upload-client-url.test.ts tests/shared/system/upload-config-copy.test.ts
$env:NODE_OPTIONS='--max-old-space-size=2048'
npx vue-tsc -b --pretty false
```

Pre-push level check still follows the project rule: `git diff --check` plus changed-file evidence. Full smoke is optional unless the implementation touches runtime contracts beyond upload configuration.

## Documentation updates after implementation

Update these docs after code lands:

```text
docs/status/current-status.md
docs/contracts/admin-api-v1.md
docs/testing/smoke-matrix.md, if upload smoke wording changes
```

The docs must say:

```text
upload runtime is Tencent COS-only
OSS is not an active or selectable runtime
bucket_domain is a bare host
client token upload and server upload share the same public URL contract
```

## Official references

Tencent Cloud COS references used for this design:

- Temporary credential / STS client upload pattern: https://cloud.tencent.com/document/product/436/14048
- COS Go SDK object upload: https://cloud.tencent.com/document/product/436/65644
- COS object upload modes and large-object boundary: https://cloud.tencent.com/document/product/436/6233
- COS custom origin domain, CNAME, HTTPS certificate behavior: https://cloud.tencent.com/document/product/436/11142

## Approval checkpoint

This spec is ready for implementation planning after review.

Implementation should not begin until this spec is accepted and a separate plan is written.
