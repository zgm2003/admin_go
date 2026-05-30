# Known Issues and WIP

状态更新时间：2026-05-30

本文只记录当前已知 bug、失败测试和未闭环 WIP。这里的内容不是 verified change-log；修复完成前不得把它写成 implemented。

## Current open issues

### UPLOAD-RUNTIME-001 upload-token full smoke blocked by undecryptable COS secrets

Status: open runtime deploy/data issue; code fix not proven necessary.

Evidence:

```text
docs/status/current-status.md records the current full-admin-smoke failure point as upload-token returning `上传密钥不可用`.
docs/testing/smoke-matrix.md records the same failure as an enabled COS upload setting whose encrypted secrets cannot be decrypted with the current Docker-first APP_SECRET-derived secretbox key.
docs/status/module-matrix.md states enabled COS settings with undecryptable secrets are real failures, not skip cases.
```

Current boundary:

```text
Do not mark full smoke as passed until upload driver secrets are re-entered for the current APP_SECRET.
Do not copy old encrypted DB blobs across APP_SECRET changes.
If a later live check shows the setting has been re-entered, rerun full-admin-smoke before moving this issue to resolved.
```

Latest local recheck:

```text
2026-05-30 later recheck: Docker Desktop daemon was unavailable at dockerDesktopLinuxEngine, and 127.0.0.1:3307 refused MySQL connections. Docker readiness/full smoke were therefore not rerun; this issue remains open.
```
