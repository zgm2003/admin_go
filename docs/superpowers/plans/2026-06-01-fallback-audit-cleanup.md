# Fallback Audit and Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove silent fallback behavior from API/DTO/auth/RBAC boundaries first, then sweep remaining frontend fallbacks by explicit module batches.

**Architecture:** Contract owners fail closed. HTTP envelope parsing owns envelope validation; user store consumes the exact RBAC DTO; Canvas API helpers send exactly what callers provide. Later batches must add guards before touching page state.

**Tech Stack:** Vue 3 + Pinia + Vitest, Next.js/React + Vitest, Go architecture tests, PowerShell governance checks.

---

## Current scan

```text
active TS/Vue/Canvas files with fallback-like tokens: 239
|| count: 1094
?? count: 176
?. count: 681
```

This is not a request to delete all 1951 tokens. It is a request to remove contract-hiding fallbacks first and classify the rest.

## File map

Batch 1 already touched:

- Modify: `admin_front_ts/src/lib/http/envelope.ts`
- Modify: `admin_front_ts/src/lib/http/client.ts`
- Modify: `admin_front_ts/src/lib/http/auth-session.ts`
- Modify: `admin_front_ts/src/types/user.ts`
- Modify: `admin_front_ts/src/store/menu.ts`
- Modify: `admin_front_ts/src/store/user.ts`
- Modify: `admin_front_ts/tests/shared/http/envelope.test.ts`
- Modify: `admin_front_ts/tests/shared/user/users-api.test.ts`
- Modify: `canvas_front_next/src/services/api/request.ts`
- Modify: `canvas_front_next/src/services/api/request.test.ts`

Next batches:

- Modify/Test: `canvas_front_next/src/services/api/image.ts`
- Modify/Test: `canvas_front_next/src/services/api/video.ts`
- Modify/Test: `canvas_front_next/src/services/api/error-payload.ts`
- Modify/Test: `canvas_front_next/src/app/(user)/canvas/[id]/canvas-client-page.tsx`
- Modify/Test: `canvas_front_next/src/app/(user)/image/page.tsx`
- Modify/Test: `canvas_front_next/src/app/(user)/video/page.tsx`
- Modify/Test: selected admin feature tests under `admin_front_ts/tests/shared/**`

---

## Task 1: Contract boundary cleanup

**Status:** completed in this working tree.

- [x] **Step 1: RED admin envelope guard**

Test file: `admin_front_ts/tests/shared/http/envelope.test.ts`

Required behavior:

```ts
expect(requireApiMessage({ code: 100, msg: '权限不足', data: null })).toBe('权限不足')
expect(() => requireApiMessage({ code: 100, msg: '', data: null })).toThrow('api envelope msg must be a non-empty string')
```

Run:

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/http/envelope.test.ts tests/shared/user/users-api.test.ts
```

Expected before implementation: FAIL because `requireApiMessage` does not exist.

- [x] **Step 2: GREEN admin envelope**

Implementation file: `admin_front_ts/src/lib/http/envelope.ts`

Required function:

```ts
export function requireApiMessage(value: Pick<ApiEnvelope<unknown>, 'msg'>): string {
  if (typeof value.msg !== 'string') {
    throw new Error('api envelope msg must be a non-empty string')
  }

  const message = value.msg.trim()
  if (!message) {
    throw new Error('api envelope msg must be a non-empty string')
  }

  return message
}
```

Use it in:

```text
admin_front_ts/src/lib/http/client.ts
admin_front_ts/src/lib/http/auth-session.ts
```

- [x] **Step 3: RED current-user permission tree guard**

Test file: `admin_front_ts/tests/shared/user/users-api.test.ts`

Required behavior:

```ts
expect(typeSource).toContain('children: PermissionMenuItem[]')
expect(storeSource).not.toContain('children?.')
```

Expected before implementation: FAIL because `PermissionMenuItem.children` is optional and store uses optional chaining.

- [x] **Step 4: GREEN current-user permission tree**

Implementation files:

```text
admin_front_ts/src/types/user.ts
admin_front_ts/src/store/user.ts
admin_front_ts/src/store/menu.ts
```

Required shape:

```ts
export interface PermissionMenuItem {
  index: string
  label: string
  path: string
  icon: string
  i18n_key: string
  show_menu: number
  sort: number
  parent_id: number
  children: PermissionMenuItem[]
}
```

`HOME_MENU_ITEM` must provide the same fields explicitly, including `children: []`.

- [x] **Step 5: RED Canvas request helper guard**

Test file: `canvas_front_next/src/services/api/request.test.ts`

Required behavior:

```ts
await expect(apiGet('/api/canvas/v1/users/me')).rejects.toThrow('api envelope msg must be a non-empty string')
expect(source).not.toContain('payload.msg ||')
expect(source).not.toContain('body ?? {}')
expect(source).not.toContain('params ||')
```

Run:

```powershell
cd E:\admin_go\canvas_front_next
npm run test -- src/services/api/request.test.ts
```

Expected before implementation: FAIL because request helper invents defaults.

- [x] **Step 6: GREEN Canvas request helper**

Implementation file: `canvas_front_next/src/services/api/request.ts`

Rules:

```text
serializeApiParams(undefined) returns empty URLSearchParams explicitly
apiGet forwards params as received
apiPost requires and forwards body as received
error envelope msg is required by requireApiMessage
```

---

## Task 2: Canvas AI API cleanup

**Status:** completed in this working tree.

- [x] **Step 1: Add RED tests for image/video envelope message**

Files:

```text
canvas_front_next/src/services/api/image.test.ts
canvas_front_next/src/services/api/video.test.ts
```

Required assertions:

```ts
await expect(requestGeneration(config, prompt)).rejects.toThrow('api envelope msg must be a non-empty string')
await expect(requestVideoGeneration(config, prompt)).rejects.toThrow('api envelope msg must be a non-empty string')
```

Mock axios responses with `code !== 0` and `msg: ''`.

- [x] **Step 2: Move shared message validation**

Create or modify:

```text
canvas_front_next/src/services/api/error-payload.ts
```

Required function:

```ts
export function requireApiMessage(payload: { msg?: unknown }) {
  if (typeof payload.msg !== 'string') throw new Error('api envelope msg must be a non-empty string')
  const message = payload.msg.trim()
  if (!message) throw new Error('api envelope msg must be a non-empty string')
  return message
}
```

- [x] **Step 3: Replace `payload.msg ||` in image/video**

Files:

```text
canvas_front_next/src/services/api/image.ts
canvas_front_next/src/services/api/video.ts
```

Replace code like:

```ts
throw new Error(payload.msg || '请求失败')
```

with:

```ts
throw new Error(requireApiMessage(payload))
```

- [x] **Step 4: Verify Canvas API tests**

Run:

```powershell
cd E:\admin_go\canvas_front_next
npm run test -- src/services/api/request.test.ts src/services/api/image.test.ts src/services/api/video.test.ts
npm run typecheck
```

Expected: PASS.

---

## Task 2.5: Admin RemoteSelect response contract

**Status:** completed in this working tree.

- [x] **Step 1: Add RED RemoteSelect response guard**

Create:

```text
admin_front_ts/tests/shared/table/remote-select-contract.test.ts
```

Required assertions:

```ts
expect(normalizeRemoteSelectResponse({ list: [{ id: 1 }], page: { total: 1 } })).toEqual({
  list: [{ id: 1 }],
  total: 1,
})
expect(() => normalizeRemoteSelectResponse({ page: { total: 1 } })).toThrow('remote select response list must be an array')
expect(() => normalizeRemoteSelectResponse({ list: [] })).toThrow('remote select response page.total must be a number')
```

Also assert source does not contain:

```text
response.list ?? []
response.total ?? 0
page?.total ??
```

- [x] **Step 2: Implement fail-closed normalizer**

Modify:

```text
admin_front_ts/src/components/RemoteSelect/src/index.vue
```

The component must require the standard paginated response:

```text
{ list: unknown[], page: { total: number } }
```

Do not keep a top-level `total` fallback.

- [x] **Step 3: Verify**

Run:

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/table/remote-select-contract.test.ts
npm run typecheck
```

Expected: PASS.

---

## Task 2.6: Admin auth refresh envelope contract

**Status:** completed in this working tree.

- [x] **Step 1: Add RED auth-session refresh guard**

Create:

```text
admin_front_ts/tests/shared/http/auth-session.test.ts
```

Required behavior:

```ts
await expect(manager.handle401({ url: '/api/admin/v1/users/me' })).rejects.toThrow(
  'api envelope msg must be a non-empty string'
)
expect(notify).not.toHaveBeenCalledWith('网络错误，请重新登录')
```

Mock refresh response:

```ts
{ code: 100, msg: '', data: null }
```

- [x] **Step 2: Implement fail-closed refresh handling**

Modify:

```text
admin_front_ts/src/lib/http/auth-session.ts
```

Rules:

```text
No refresh token keeps the session-expired message.
Network/axios refresh failure keeps the network-error message.
Malformed API envelope msg propagates the contract error and does not become a network error.
```

- [x] **Step 3: Verify**

Run:

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/http/envelope.test.ts tests/shared/http/auth-session.test.ts tests/shared/user/users-api.test.ts
npm run typecheck
```

Expected: PASS.

---

## Task 2.7: Admin HTTP error-interceptor envelope contract

**Status:** completed in this working tree after review sweep.

- [x] **Step 1: Add RED client error-interceptor guards**

Create:

```text
admin_front_ts/tests/shared/http/client-error-contract.test.ts
```

Required behavior:

```ts
await expect(fulfilled401EnvelopeWithEmptyMsg).rejects.toThrow('api envelope msg must be a non-empty string')
await expect(rejected500EnvelopeWithEmptyMsg).rejects.toThrow('api envelope msg must be a non-empty string')
await expect(rejected401EnvelopeWithEmptyMsg).rejects.toThrow('api envelope msg must be a non-empty string')
```

Also extend:

```text
admin_front_ts/tests/shared/http/auth-session.test.ts
```

Required behavior:

```ts
await expect(manager.handle401(refreshRequestConfig, '')).rejects.toThrow(
  'api envelope msg must be a non-empty string'
)
```

Expected before implementation: FAIL because the client replaced empty API envelope messages with local `Unauthorized` / axios fallback messages.

- [x] **Step 2: GREEN HTTP error-interceptor fail-closed behavior**

Modify:

```text
admin_front_ts/src/lib/http/client.ts
admin_front_ts/src/lib/http/auth-session.ts
```

Rules:

```text
If response data is a standard API envelope, msg must pass requireApiMessage before auth refresh or user notification.
HTTP/Axios fallback messages are allowed only for non-envelope transport failures.
Auth-session may use the local session-expired message only when no server message was provided; an empty provided message is malformed.
```

- [x] **Step 3: Verify**

Run:

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/http/client-error-contract.test.ts tests/shared/http/auth-session.test.ts tests/shared/http/envelope.test.ts
```

Expected: PASS.

---

## Task 3: Canvas page-state fallback decomposition

- [ ] **Step 1: Create a focused audit list**

Run:

```powershell
cd E:\admin_go
rg -n "\?\?|\|\||\?\." canvas_front_next/src/app/(user)/canvas/[id]/canvas-client-page.tsx canvas_front_next/src/app/(user)/image/page.tsx canvas_front_next/src/app/(user)/video/page.tsx
```

Classify each line as one of:

```text
contract-hiding
business-default
browser-boundary
empty-user-input
boolean-condition
```

- [ ] **Step 2: Only fix contract-hiding lines**

Do not change boolean conditions or user-input emptiness checks. For every contract-hiding line, write a test first.

- [ ] **Step 3: Verify Canvas page tests/build**

Run:

```powershell
cd E:\admin_go\canvas_front_next
npm run test
npm run typecheck
npm run build
```

Expected: PASS.

---

## Task 4: Admin feature fallback batches

- [ ] **Step 1: Batch by module, not by regex**

Start with one module at a time:

```text
admin_front_ts/src/views/Main/ai/*
admin_front_ts/src/views/Main/system/*
admin_front_ts/src/components/*
```

- [ ] **Step 2: For every changed fallback, prove owner**

Before deleting a fallback, identify:

```text
data owner
expected non-empty contract
test that fails on current fallback
```

- [ ] **Step 3: Verify admin frontend**

Run:

```powershell
cd E:\admin_go\admin_front_ts
npm run typecheck
npm run test
npm run build
```

Expected: PASS.

---

## Final verification

Run after each batch:

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

If `.codex/hooks.json` or `.codex/hooks/*.ps1` changes, stop and ask the user to review/trust hooks with `/hooks`.
