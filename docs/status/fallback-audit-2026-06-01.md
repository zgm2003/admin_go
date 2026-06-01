# Fallback Audit 2026-06-01

## Outcome

Started the fallback cleanup as a contract-boundary sweep, not a blind regex replacement.

首批已处理：

- Admin HTTP envelope: `msg` is required for error envelopes; frontend no longer invents `http.requestFailed` for a malformed backend envelope.
- Admin HTTP error interceptor: standard API envelopes from HTTP error responses must also carry a non-empty `msg`; axios/local fallback messages are only for non-envelope transport failures.
- Admin auth refresh: a malformed refresh envelope no longer falls through to the generic network-error message.
- Admin current-user/RBAC type: `PermissionMenuItem.children` is required; user store traversal no longer uses `children?.`.
- Admin RemoteSelect: remote list responses must be `{ list, page: { total } }`; missing `list` or `page.total` now fails closed instead of rendering an empty dropdown.
- Canvas API request helper: no `params ||`, `body ?? {}`, or `payload.msg ||` in the shared request helper.
- Canvas image/video API: no `payload.msg || ...` or `responseData?.msg || ...` error-message fallback in AI image/video request paths.

## Scan snapshot

Command:

```powershell
cd E:\admin_go
python inline scan over admin_front_ts/src and canvas_front_next/src for ??, ||, ?.
```

Result:

```text
files: 239
||: 1094
??: 176
?.: 681
```

Top hotspots:

```text
canvas_front_next/src/app/(user)/canvas/[id]/canvas-client-page.tsx
canvas_front_next/src/app/(user)/canvas/components/canvas-node.tsx
canvas_front_next/src/app/(user)/image/page.tsx
canvas_front_next/src/app/(user)/video/page.tsx
admin_front_ts/src/views/Main/ai/chat/index.vue
canvas_front_next/src/services/api/video.ts
canvas_front_next/src/services/api/image.ts
```

## Classification rule

Do not mechanically delete every token. Classify first:

```text
contract-hiding       delete or fail closed
business-default      keep only if owner and rule are explicit
browser-boundary      keep if browser/runtime API may legitimately be missing
empty-user-input      keep only for user-entered optional form/search values
boolean-condition     not a fallback cleanup target
```

## Verification so far

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/http/envelope.test.ts tests/shared/user/users-api.test.ts
npm run test -- tests/shared/http/envelope.test.ts tests/shared/http/auth-session.test.ts tests/shared/user/users-api.test.ts tests/shared/table/remote-select-contract.test.ts
npm run test -- tests/shared/http/client-error-contract.test.ts tests/shared/http/auth-session.test.ts tests/shared/http/envelope.test.ts
npm run typecheck

cd E:\admin_go\canvas_front_next
npm run test -- src/services/api/request.test.ts
npm run test -- src/services/api/request.test.ts src/services/api/image.test.ts src/services/api/video.test.ts
npm run typecheck
```

These pass after RED/GREEN.

## Next batch

Public admin frontend components remain the next highest-leverage batch:

```text
admin_front_ts/src/components/Table/src/index.vue
admin_front_ts/src/components/Search/src/index.vue
```

`RemoteSelect` is already done. Next candidates are AppTable column key/prop fallbacks and Search select/options defaults, each with tests first.

Canvas page-state cleanup should come after API/component boundaries because `canvas-client-page.tsx`, image page, and video page mix legacy localforage data, browser refs, and business defaults. Treat that as a separate narrow batch.
