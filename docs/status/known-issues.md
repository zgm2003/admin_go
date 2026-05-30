# Known Issues and WIP

状态更新时间：2026-05-30

本文只记录当前已知 bug、失败测试和未闭环 WIP。这里的内容不是 verified change-log；修复完成前不得把它写成 implemented。

## Current open issues

### AI-FE-001 canceled chat stream can accept late WebSocket events after a later stream completes

Status: evidence recorded; production code change needs user confirmation.

Evidence:

```text
admin_front_ts/src/views/Main/ai/chat/composables/useConversationSessions.ts records canceled request ids in cancel(), but appendDelta()/complete()/fail() only reject a different request id while pendingRequestId is non-empty.
complete() clears canceledRequestIds, so a late event from an older canceled request can arrive after a later request completed and pendingRequestId is already empty.
The existing ai-chat-cancel-state test covers terminal-state cancel behavior, but not old canceled stream events arriving after another stream completes.
```

Required minimal proof/fix boundary:

```text
Add a failing Vitest case in admin_front_ts/tests/shared/ai/ai-chat-cancel-state.test.ts:
begin request A, cancel A, begin/complete request B, then deliver late A delta/completed and assert B's assistant message is unchanged.
After user confirmation, fix the request guard so terminal or late events only apply to the matching in-flight/last assistant request.
```

### PAY-FE-003 recharge auto-sync marks failed rows as already synced for the whole page session

Status: evidence recorded; production code change needs user confirmation.

Evidence:

```text
admin_front_ts/src/views/Main/payment/recharge/composables/usePaymentRechargePage.ts adds a paying recharge id to autoSyncedRechargeIDs before PaymentRechargeApi.sync() resolves.
The catch branch only shows a warning and does not remove the id, so transient sync failures suppress automatic retry until page reload or manual sync.
The current payment-recharge-page test checks the permission guard and three-item cap, but not retry-after-failure behavior.
```

Required minimal proof/fix boundary:

```text
Add a failing frontend test around autoSyncVisiblePayingRecharges: mock the first sync call to reject, call auto sync twice, and assert the second call retries the same recharge id.
After user confirmation, remove the id from autoSyncedRechargeIDs on sync failure or mark it only after a successful sync.
```

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
