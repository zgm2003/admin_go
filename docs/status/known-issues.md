# Known Issues and WIP

状态更新时间：2026-05-30

本文只记录当前已知 bug、失败测试和未闭环 WIP。这里的内容不是 verified change-log；修复完成前不得把它写成 implemented。

## Current open issues

None.

## Recently resolved

### UPLOAD-RUNTIME-001 upload-token full smoke blocked by undecryptable COS secrets

Status: resolved by runtime data repair, not code change.

Evidence:

```text
2026-05-30 live recheck after re-entering the COS upload driver secrets:
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account 15671628271 -Password 123456
passed and reported upload_token_probe=passed, upload_token_code=0, upload_token_provider=cos.
```

Boundary:

```text
The fix was re-entering secrets for the current APP_SECRET-derived secretbox key.
Do not copy old encrypted DB blobs across APP_SECRET changes.
```
