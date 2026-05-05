# Frontend Realtime Go WebSocket Contract Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking. Do not create a worktree. Do not commit.

**Goal:** Switch the Vue realtime runtime from legacy PHP WebSocket to the Go `/api/admin/v1/realtime/ws` contract and make browser WebSocket authentication work without query-string access tokens.

**Architecture:** Keep Go as Gin modular monolith and Vue as typed frontend. Reuse existing path-scoped `AuthToken` cookie token fallback only for the WebSocket GET path; keep regular JSON API on Authorization headers. Frontend keeps a small singleton WebSocket client and emits project envelopes through the existing message bus.

**Tech Stack:** Go 1.21+, Gin, gorilla/websocket already selected, Vue 3, TypeScript, Vite, Vitest.

---

## Task 1: Backend WebSocket browser auth boundary

**Files:**
- Modify: `admin_back_go/internal/module/realtime/route.go`
- Modify: `admin_back_go/internal/server/router.go`
- Modify: `admin_back_go/internal/server/router_test.go`

- [x] Add exported `WSPath` in `internal/module/realtime/route.go` and register route from that constant.
- [x] Add `realtime.WSPath` to `CookieTokenPath.PathPrefixes` in `internal/server/router.go`.
- [x] Add server test proving browser-style WebSocket can authenticate with only `access_token` cookie and platform defaults to `admin`.
- [x] Run `go test ./internal/server ./internal/middleware ./internal/module/realtime ./internal/platform/realtime`.

## Task 2: Frontend realtime client contract

**Files:**
- Modify: `admin_front_ts/src/lib/realtime/message-bus.ts`
- Modify: `admin_front_ts/src/lib/realtime/websocket-client.ts`
- Modify: `admin_front_ts/src/hooks/useWebSocket.ts`
- Modify: `admin_front_ts/.env.development`
- Modify: `admin_front_ts/src/vite-env.d.ts`
- Modify: `admin_front_ts/tests/shared/realtime/websocket-client.test.ts`
- Modify: `admin_front_ts/tests/shared/realtime/message-bus.test.ts` if event type assertions need updating

- [x] Replace legacy message type names with versioned realtime envelope names while preserving generic string support for not-yet-migrated business events.
- [x] Add pure `buildWebSocketURL(apiBaseURL, explicitURL)` helper with tests.
- [x] Remove `Cookies` import and `legacyRequest.post('/api/admin/WebSocket/bind')` from websocket client.
- [x] Replace `isBound/clientId` with `isReady` based on `realtime.connected.v1`.
- [x] Send project envelopes with `type/request_id/data` only; no unversioned `ping/pong` frames.
- [x] Auto-subscribe to identity topics from connected payload: `user:<id>` and `platform:<platform>`.
- [x] Update `useWebSocket` return shape to expose `isReady` and remove `bindUser`.
- [x] Change `.env.development` `VITE_WEB_SOCKET_URL` to the Go path.
- [x] Run targeted Vitest for realtime tests.

## Task 3: Contract and architecture docs

**Files:**
- Modify: `docs/contracts/admin-realtime-v1.md`
- Modify: `docs/migration/current-status.md`
- Modify: `docs/testing/smoke-matrix.md`
- Modify: `admin_back_go/docs/architecture.md`

- [x] Document path-scoped cookie auth for browser WebSocket and explicitly say it is not global API cookie fallback.
- [x] Document frontend runtime status as adapted baseline, but keep Redis fan-out/business notifications/AI streaming planned.
- [x] Document that ticket auth remains planned for cross-domain/gateway cases; access token query string remains forbidden.
- [x] Document frontend test coverage for Go WebSocket URL/envelope cleanup.

## Task 4: Verification gates

**Files:**
- All touched files.

- [x] Run backend targeted tests from Task 1.
- [x] Run frontend targeted realtime tests.
- [x] Run `npx vue-tsc -b --pretty false`.
- [x] Run targeted eslint on touched frontend source files.
- [x] Run `git diff --check -- . ':!runtime/**' ':!.tmp/**'`.
- [x] If time/memory allows, run `go test -p=1 ./...` and `go vet -p=1 ./...` from `admin_back_go`.
