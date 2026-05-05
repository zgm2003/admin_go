# Realtime Browser Auth + Go Refresh Base Fix Plan

> REQUIRED SUB-SKILL: superpowers:systematic-debugging. This is a bug-fix slice; root cause must be proven before patching.

## Task 1: Frontend WebSocket loopback normalization

Files:

- `admin_front_ts/src/lib/realtime/websocket-client.ts`
- `admin_front_ts/src/api/system/queueMonitor.ts`
- create `admin_front_ts/src/lib/network/loopback.ts`
- create `admin_front_ts/tests/realtime-websocket-url.test.ts`

Steps:

- [ ] Extract a small loopback-host helper.
- [ ] Normalize explicit `VITE_WEB_SOCKET_URL` when both target host and browser host are loopback.
- [ ] Normalize derived WebSocket URL from `VITE_GO_API_BASE_URL` the same way.
- [ ] Keep non-loopback production URLs untouched.
- [ ] Add Vitest coverage for explicit URL and derived URL behavior.

## Task 2: Frontend refresh baseURL

Files:

- `admin_front_ts/src/lib/http/client.ts`

Steps:

- [ ] Change Go API client's refresh baseURL from legacy baseURL to Go API baseURL.
- [ ] Keep legacy client unchanged.
- [ ] Do not add fallback to legacy refresh.

## Task 3: Backend CORS proof for Go refresh

Files:

- `admin_back_go/internal/server/router_test.go`

Steps:

- [ ] Add a test proving `POST /api/admin/v1/auth/refresh` served by Go includes CORS headers for `http://127.0.0.1:5173`.
- [ ] Keep refresh endpoint public and protected by body refresh token, not access-token middleware.

## Task 4: Docs sync

Files:

- `docs/contracts/admin-realtime-v1.md`
- `docs/architecture/06-realtime-and-distributed-boundary.md`

Steps:

- [ ] Document local loopback normalization.
- [ ] Document future app WebSocket path as planned, not implemented.
- [ ] Document refresh must use Go base URL for Go API.

## Task 5: Verification and commits

Commands:

Backend:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/server ./internal/middleware ./internal/module/realtime ./internal/platform/realtime
go test ./...
go vet ./...
git diff --check
```

Frontend:

```powershell
cd E:\admin_go\admin_front_ts
npx vitest run tests/realtime-websocket-url.test.ts
npx vue-tsc -b --pretty false
npx eslint src/lib/realtime/websocket-client.ts src/lib/http/client.ts src/api/system/queueMonitor.ts tests/realtime-websocket-url.test.ts
git diff --check
```

Root:

```powershell
cd E:\admin_go
git diff --check
```

Commits:

- backend: `test(realtime): prove refresh CORS headers`
- frontend: `fix(realtime): normalize websocket host and Go refresh base`
- root docs: `docs(realtime): document browser auth and refresh base`

