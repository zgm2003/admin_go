# Admin Go Rewrite Long Goal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` for sequential execution. Use `superpowers:subagent-driven-development` only when the user explicitly allows parallel/subagent work. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn `E:\admin_go` into a production-grade Go + Vue admin rewrite baseline: strict RESTful admin/app API boundaries, RBAC-first business migration, full authentication foundation, WebSocket-only realtime infrastructure, distributed-deployment readiness, full-stack TypeScript, test gates, architecture docs, and repeatable smoke verification.

**Architecture:** Keep `admin_back_go` as a Gin modular monolith now, with module boundaries that can later split into services. Backend modules stay `route -> handler -> service -> repository -> model`; realtime endpoints use explicit connection/session boundaries instead of hiding state in handlers. Frontend adapts to the new Go REST/WebSocket contract without legacy fallback pollution. Legacy PHP is a business-fact reference only; it does not define the new architecture.

**Tech Stack:** Go 1.21+ style, Gin, GORM, MySQL, Redis, Asynq, gocron/v2, go-captcha, WebSocket library selected by documented open-source review before implementation, Vue 3, TypeScript, Vite, Element Plus.

**Execution rule:** Work in the current branch only. Do not create a worktree. Do not commit unless the user explicitly asks. Every phase ends with tests, smoke evidence, docs updates, and a short handoff note.

---

## Copyable `/goal` Objective

```text
Goal: Continue the E:\admin_go admin rewrite from the current branch without committing. Maintain a Gin modular monolith backend and Vue 3 TypeScript frontend. Treat code quality, architecture quality, and documentation truthfulness as permanent constraints, not optional cleanup. Preserve strict RESTful routes under /api/admin/v1 and future /api/app/v1; realtime endpoints must use the same admin/app scope boundary, for example /api/admin/v1/realtime/ws. Prefer mature official/open-source packages and their documented components before hand-writing framework code or UI behavior; hand-written wrappers must stay thin and documented. No silent fallback fields, no all-POST new APIs, no any TS, no legacy PHP architecture leakage. Migrate business one narrow slice at a time. For every slice: read AGENTS.md and architecture docs, inspect legacy PHP only for business facts, define/update contract, write failing tests first where practical, implement backend and frontend, update docs, run Go tests/vet, frontend typecheck/lint/build as needed, run smoke, and report changed files plus verification evidence. Current next priorities: finish auth hardening and async login logs, then complete admin core CRUD for auth platform, permissions, roles, users, operation logs, system init dictionaries, captcha UI polish, and realtime/distributed foundation before migrating broader business modules.
```

---

## Non-Negotiable Rules

- [ ] Keep new backend API under `/api/admin/v1/...`; reserve `/api/app/v1/...` for future app system.
- [ ] New API must be RESTful resources: `GET list/detail`, `POST create`, `PUT update`, `PATCH state`, `DELETE delete`. WebSocket upgrade routes are the explicit exception, but their URLs still live under `/api/admin/v1/...` or `/api/app/v1/...`.
- [ ] Official/open-source component first: prefer Gin/go-captcha/Asynq/gocron/Element Plus/Vue ecosystem packages and their documented usage before custom code. If custom wrapping is needed, keep the wrapper thin and explain why.
- [ ] Do not hand-roll captcha visuals when `go-captcha`/`go-captcha-vue` provides a maintained component and style baseline; only adjust layout spacing around it.
- [ ] Do not add compatibility fallback fields. If compatibility exists, name it `legacy adapter` and keep it outside the new contract.
- [ ] Do not introduce `any`, `as any`, or `Record<string, any>` in touched frontend code.
- [ ] Do not let handler access DB/Redis directly.
- [ ] Do not let service depend on `gin.Context`.
- [ ] Do not let repository make business decisions.
- [ ] Do not fake mail/SMS/AI/storage/WebSocket services. If not wired, return explicit configuration errors or dev-mode behavior documented in `.env.example`.
- [ ] Do not broaden scope when one narrow end-to-end flow is not verified. Realtime work must start with one authenticated connect -> subscribe -> heartbeat -> disconnect flow before adding business events.
- [ ] Do not commit.

---

## Permanent Quality Doctrine

This project is intended to be portfolio-grade work. Do not trade long-term quality for short-term speed.

- [ ] Code quality is a release gate: simple functions, explicit errors, `context.Context` on blocking Go paths, table-driven tests for service logic, no goroutine without lifecycle ownership, no hidden global state.
- [ ] Architecture quality is a release gate: keep module boundaries clean, use `route -> handler -> service -> repository -> model`, keep `admin-api` HTTP-only, keep `admin-worker` async-only, and split realtime only when measured pressure justifies it.
- [ ] Documentation quality is a release gate: every changed API, cache key, enum, queue task, scheduler job, realtime contract, or deployment rule updates the matching doc in the same task.
- [ ] Verification evidence is mandatory: no “should be fixed” reports. Show the exact test/smoke command and the decisive output.
- [ ] Open-source respect is mandatory: use mature official/open-source packages first, document the choice, and only hand-write code where the package boundary ends.
- [ ] Good taste beats cleverness: remove special cases instead of adding more branches, and stop before abstractions become Java-style ceremony.

---

## Baseline Verification Commands

Run from `E:\admin_go\admin_back_go`:

```powershell
go test ./...
go vet ./...
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\basic-admin-smoke.ps1 -Account 15671628271 -Password 123456
```

Run from `E:\admin_go\admin_front_ts`:

```powershell
npx vue-tsc -b --pretty false
npx eslint src/api/user/users.ts src/components/AppCaptcha/src/AppSlideCaptcha.vue
```

When touching larger frontend areas, also run:

```powershell
npm run build
```

When touching concurrency, cache, queue, session, realtime, or auth policy code, also run from `admin_back_go`:

```powershell
go test -race ./internal/module/auth ./internal/module/session ./internal/platform/taskqueue ./internal/platform/realtime ./internal/jobs
```

---

## Phase 1: Freeze Current Architecture and Contract Reality

**Purpose:** Before more migration, make the current Go/Vue contract explicit so future agents stop guessing.

**Files:**
- Read: `E:/admin_go/AGENTS.md`
- Read: `E:/admin_go/docs/architecture/04-go-backend-framework.md`
- Read: `E:/admin_go/docs/architecture/05-development-quality-rules.md`
- Modify: `E:/admin_go/admin_back_go/docs/architecture.md`
- Modify/Create: `E:/admin_go/docs/contracts/admin-api-v1.md`
- Modify/Create: `E:/admin_go/docs/migration/current-status.md`

- [ ] Record the current endpoint list for Go admin API.
- [ ] Record which endpoints are public: health, ready, captcha, login-config, send-code, login, refresh.
- [ ] Record which endpoints are protected: users/me, users/init, auth-platforms, permissions, roles.
- [ ] Record response format: `{ code, data, msg }`.
- [ ] Record admin/app route namespace decision: `/api/admin/v1` now, `/api/app/v1` reserved.
- [ ] Record current smoke result expectations, including `login_config_types=email,phone,password`.
- [ ] Add a migration status table with columns: module, Go backend status, frontend status, tests, smoke, docs, remaining risk.
- [ ] Run backend baseline tests.
- [ ] Run frontend typecheck.
- [ ] Update the handoff section with exact changed files and verification output.

**Exit criteria:** A new agent can read docs and know exactly what is already migrated and what is not.

---

## Phase 2: Auth Hardening and Login Log Queue

**Purpose:** Auth is the root of admin. Finish it before more CRUD sprawl.

**Files:**
- Modify: `E:/admin_go/admin_back_go/internal/module/auth/service.go`
- Modify: `E:/admin_go/admin_back_go/internal/module/auth/repository.go`
- Modify/Create: `E:/admin_go/admin_back_go/internal/module/auth/jobs.go`
- Modify: `E:/admin_go/admin_back_go/internal/jobs/noop.go` or create `internal/jobs/registry.go` only when needed
- Modify: `E:/admin_go/admin_back_go/internal/bootstrap/worker.go`
- Modify: `E:/admin_go/admin_back_go/internal/module/auth/service_test.go`
- Modify: `E:/admin_go/admin_back_go/scripts/basic-admin-smoke.ps1`
- Modify: `E:/admin_go/admin_back_go/docs/architecture.md`

- [x] Write a failing test proving successful login enqueues `auth:login-log:v1` or writes synchronously when queue producer is absent by explicit policy.
- [x] Write a failing test proving failed password/code attempts are logged with reason: `wrong_password` or `invalid_code`.
- [x] Add a project-owned task payload type in `internal/module/auth/jobs.go`.
- [x] Register the worker handler so login log writing can run in `admin-worker`.
- [x] Keep task type versioned: `auth:login-log:v1`.
- [x] Use `critical` queue lane for login log tasks.
- [x] Ensure login success never fails only because async log enqueue fails; log enqueue error is best-effort but visible in server logs.
- [x] Keep repository write path reusable by both sync fallback and queue consumer.
- [x] Extend smoke summary to include login log row existence for the test account and current timestamp window.
- [x] Document sync-vs-queue behavior and failure policy.
- [x] Run `go test ./internal/module/auth ./internal/jobs ./internal/bootstrap`.
- [x] Run `go test ./...` and `go vet ./...`.
- [x] Run `basic-admin-smoke.ps1`.

**Exit criteria:** Auth has password/code login, automatic registration, session creation, logout/refresh, and login log path with explicit async boundary.

---

## Phase 3: Auth Platform Management Polish

**Purpose:** The authentication platform page is core configuration, not a side page.

**Files:**
- Backend: `E:/admin_go/admin_back_go/internal/module/authplatform/*`
- Frontend: `E:/admin_go/admin_front_ts/src/api/permission/authPlatform.ts`
- Frontend view path: locate current auth platform Vue page before editing with `rg "authPlatform|认证平台" src/views src/router src/api`.
- Docs: `E:/admin_go/admin_back_go/docs/architecture.md`

- [x] Verify `captcha_type` is present in init dict, list, create, update, status flows.
- [x] Verify `login_types` ordering in auth platform dict remains enum order: email, phone, password.
- [x] Write backend tests for create/update rejecting unsupported `captcha_type`.
- [x] Write backend tests for create/update normalizing `login_types` to enum order.
- [x] Ensure frontend form uses typed union for `captcha_type` and `login_types`.
- [x] Verify login captcha popup uses the official `go-captcha-vue` component/style as the inner verifier instead of a hand-made slider.
- [x] Fix captcha container spacing to match the official visual baseline: enough outer padding around the image/slider/card, no cramped top/right edges, and no extra confirm/cancel buttons inside the verifier.
- [x] Keep captcha as a reusable public component, but keep its responsibility narrow: render verifier, emit success/failure/close/refresh events, and let the caller decide the business action.
- [x] Remove frontend fallback labels if any are found for auth platform enum display.
- [x] Ensure page uses `request` to Go API, not `legacyRequest`.
- [x] Run backend authplatform tests.
- [x] Run frontend `vue-tsc`.
- [x] Run targeted eslint for touched auth platform files.
- [x] Update docs with the final auth platform contract.

**Exit criteria:** Admin can configure platform login methods and captcha policy through Go API without legacy fallback.

---

## Phase 4: RBAC Read/Write Full Closure

**Purpose:** Admin value is RBAC. Finish permission, role, users/init, and permission check as a closed loop.

**Files:**
- Backend: `E:/admin_go/admin_back_go/internal/module/permission/*`
- Backend: `E:/admin_go/admin_back_go/internal/module/role/*`
- Backend: `E:/admin_go/admin_back_go/internal/module/user/*`
- Backend: `E:/admin_go/admin_back_go/internal/middleware/*permission*`
- Frontend API: `E:/admin_go/admin_front_ts/src/api/permission/*`
- Frontend route/menu stores: locate with `rg "buttonCodes|router|permissions|users/init|users/me" src`.
- Docs: `E:/admin_go/docs/contracts/admin-api-v1.md`

- [x] Confirm `Users/init` returns `permissions`, `router`, `buttonCodes`, and `quick_entry` with stable field names.
- [x] Confirm `show_menu` only affects menu visibility, not page permission truth.
- [x] Confirm `BUTTON` permission implies page access only through service logic, not frontend guessing.
- [x] Add tests for permission tree building with DIR/PAGE/BUTTON.
- [x] Add tests for role permission sync: grant page, grant button, remove button, remove page.
- [x] Add tests for cache invalidation when role permissions change.
- [x] Add tests for `PermissionCheck` fail-closed when user missing, role missing, cache error, or permission service error.
- [x] Ensure super admin behavior is explicit. If current model uses role permissions only, document that no hidden bypass exists.
- [x] Ensure frontend button permission reads only `buttonCodes`, not route meta hacks.
- [x] Ensure menu add/edit/delete pages call RESTful Go APIs.
- [x] Run RBAC smoke: create temporary DIR/PAGE/BUTTON, grant to test role if needed, verify init result, delete cleanup.
- [x] Update architecture docs with RBAC truth table.

**Exit criteria:** Menu, route, button, API permission, cache, and role mutation form one verified loop.

---

## Phase 5: Users Core Management Migration

**Purpose:** Let admin system manage users normally through Go, enough for real usage.

**Files:**
- Backend create/modify: `E:/admin_go/admin_back_go/internal/module/user/request.go`
- Backend create/modify: `E:/admin_go/admin_back_go/internal/module/user/dto.go`
- Backend modify: `E:/admin_go/admin_back_go/internal/module/user/handler.go`
- Backend modify: `E:/admin_go/admin_back_go/internal/module/user/service.go`
- Backend modify: `E:/admin_go/admin_back_go/internal/module/user/repository.go`
- Frontend: `E:/admin_go/admin_front_ts/src/api/user/users.ts`
- Frontend: locate users list page with `rg "UsersList|用户管理|users/list" src/views src/api`.

- [x] Map legacy `UsersList/init`, `UsersList/list`, `edit`, `batchEdit`, `del`, `export` to RESTful Go endpoints. Export is explicitly documented as remaining legacy adapter until Go export-task migration lands.
- [x] Define Go endpoints: `GET /api/admin/v1/users`, `PUT /api/admin/v1/users/:id`, `PATCH /api/admin/v1/users/:id/status`, `DELETE /api/admin/v1/users/:id`.
- [x] Keep `GET /api/admin/v1/users/init` for current user bootstrap; do not overload it for list-page init.
- [x] Create separate endpoint if page init dictionaries are needed: `GET /api/admin/v1/user-management/init` or better `GET /api/admin/v1/users/page-init`; choose one and document it.
- [x] Add request structs with binding tags; service does business validation.
- [x] Add repository queries with prefix search where indexes can help.
- [x] Avoid accepting duplicate alias fields such as `address` and `address_id` in new APIs.
- [x] Frontend API layer translates only the new contract.
- [x] Run backend tests for list filters, update, delete constraints.
- [x] Run frontend typecheck and targeted lint.
- [x] Add smoke for list and one harmless update/readback if safe. Current smoke covers page-init/list; update/readback is intentionally skipped because it would mutate the real test account.

**Exit criteria:** Users page can load, filter, edit safe fields, change status, and delete according to Go contract.

---

## Phase 6: Operation Log and Audit Contract

**Purpose:** Admin changes must be traceable. This is not optional decoration.

**Files:**
- Backend: `E:/admin_go/admin_back_go/internal/module/operationlog/*`
- Backend: `E:/admin_go/admin_back_go/internal/middleware/operation_log*`
- Backend: `E:/admin_go/admin_back_go/internal/bootstrap/*operation*` or existing route-rule registration
- Frontend: locate operation log API/page with `rg "OperationLog|operationLog|操作日志" src`.

- [ ] Define explicit operation rules per route in code, not annotations/reflection.
- [ ] Verify operation log runs after permission check.
- [ ] Verify failed requests are logged only for configured routes and include status/success fields.
- [ ] Add tests for create/update/delete route operation logs.
- [ ] Migrate operation log list/init API to Go REST.
- [ ] Ensure sensitive fields are masked in operation payloads; never log passwords, captcha answers, tokens, refresh tokens.
- [ ] Add docs section: OperationLog rule registration policy.
- [ ] Run backend middleware/module tests.
- [ ] Run frontend typecheck/lint.

**Exit criteria:** Mutating admin operations have predictable audit logs without leaking secrets.

---

## Phase 7: Frontend API Layer Cleanup

**Purpose:** Stop legacy spread and make frontend a typed client of Go.

**Files:**
- `E:/admin_go/admin_front_ts/src/api/**`
- `E:/admin_go/admin_front_ts/src/types/**`
- `E:/admin_go/admin_front_ts/src/lib/http/**`

- [ ] Create a migration inventory of every `legacyRequest` usage.
- [ ] Mark each usage as: keep legacy for unmigrated PHP module, migrate now, or remove dead call.
- [ ] Ensure new Go APIs use `request`, not wrappers named `goRequest`.
- [ ] Ensure all new request/response types are explicit interfaces or discriminated unions.
- [ ] Remove `any` in touched files.
- [ ] For shared Vue components touched during migration, prefer official component APIs and documented slots/props/events over custom DOM reimplementation.
- [ ] For `AppSlideCaptcha` or captcha dialog changes, preserve the official verifier behavior and adjust only wrapper sizing, padding, z-index, and event wiring.
- [ ] For each migrated module, update the corresponding `src/types/*` file first.
- [ ] Then update `src/api/*`.
- [ ] Then update view/composable consumption.
- [ ] Run `npx vue-tsc -b --pretty false` after each module migration.
- [ ] Run targeted eslint after each touched area.
- [ ] Run `npm run build` after a batch of 3 to 5 frontend modules.

**Exit criteria:** Frontend API layer clearly shows what is migrated to Go and what remains legacy.

---

## Phase 8: Queue, Scheduler, and Worker Production Readiness

**Purpose:** Prepare async jobs and cron without turning admin-api into a garbage worker host.

**Files:**
- `E:/admin_go/admin_back_go/cmd/admin-worker/main.go`
- `E:/admin_go/admin_back_go/internal/bootstrap/worker.go`
- `E:/admin_go/admin_back_go/internal/platform/taskqueue/*`
- `E:/admin_go/admin_back_go/internal/platform/scheduler/*`
- `E:/admin_go/admin_back_go/internal/jobs/*`
- `E:/admin_go/admin_back_go/docs/architecture.md`

- [x] Verify `admin-api` never consumes queue and never runs cron.
- [x] Verify `admin-worker` owns Asynq server and gocron scheduler.
- [x] Define queue lane policy: critical/default/low.
- [x] Define task naming policy: `module:action:v1`.
- [x] Add a registry test proving handlers are registered and unknown task types fail visibly.
- [x] Add scheduler test proving scheduled jobs enqueue tasks instead of running business directly.
- [x] Add worker config docs for concurrency, retry, timeout, and Redis DB.
- [x] Add a local command section for running worker.
- [x] Run `go test ./internal/platform/taskqueue ./internal/platform/scheduler ./internal/jobs ./internal/bootstrap`.
- [ ] Run race tests for queue/job packages when job handlers start mutating shared state.
  - Current Windows host is blocked by missing `gcc`: `cgo: C compiler "gcc" not found`.

**Exit criteria:** Async architecture is documented, testable, and separate from HTTP lifecycle.

---

## Phase 9: OpenAPI or Contract Documentation Gate

**Purpose:** Stop front/back guessing before business migration grows.

**Files:**
- Create/modify: `E:/admin_go/docs/contracts/admin-api-v1.md`
- Optional create: `E:/admin_go/admin_back_go/api/openapi.yaml`
- Optional script: `E:/admin_go/admin_back_go/scripts/check-contract.ps1`

- [x] Decide whether current contract source is Markdown first or OpenAPI YAML first.
- [x] For each Go resource, document method, path, auth requirement, request, response, error cases.
- [x] Include dictionary/init endpoints and their enum source.
- [x] Include examples for login-config, send-code, login, users/init, permission create, role update.
- [x] Add a contract review checklist to docs.
- [x] Add a lightweight check that fails if docs mention `/api/admin/Xxx/list` as a new Go API.
- [x] Require every migrated module to update contract docs before frontend adaptation.

**Exit criteria:** The API contract is readable by frontend, backend, and agent workers without source spelunking.

---

## Phase 10: Test Strategy and Quality Gates

**Purpose:** Full-scale rewrite needs cheap tests, smoke tests, and heavier gates.

**Files:**
- `E:/admin_go/admin_back_go/scripts/basic-admin-smoke.ps1`
- Create: `E:/admin_go/admin_back_go/scripts/full-admin-smoke.ps1`
- Create: `E:/admin_go/docs/testing/test-strategy.md`
- Create: `E:/admin_go/docs/testing/smoke-matrix.md`

- [x] Keep `basic-admin-smoke.ps1` fast: auth, users/init, RBAC create/delete, logout.
- [x] Create `full-admin-smoke.ps1` for slower checks: auth platform, role, permission, users list, operation log, queue health.
- [x] Full smoke must clean up every temporary row it creates.
- [x] Full smoke must print JSON summary only at the end.
- [x] Failures must preserve logs under `.tmp/`.
- [x] Add backend unit test policy: service logic gets table-driven tests; repository tests only when DB behavior is important.
- [x] Add frontend test policy: typecheck first, then targeted component/composable tests where logic is non-trivial.
- [x] Add `go test -race` policy for session, auth, queue, scheduler, WebSocket, AI streaming, and worker code.
- [x] Document which commands are mandatory before claiming completion.

**Exit criteria:** There is a clear difference between quick validation, full validation, and release validation.

---

## Phase 11: Realtime Foundation: WebSocket, AI Streaming, and Distributed Boundary

**Purpose:** Make realtime a first-class admin-system foundation, not an afterthought bolted onto login or AI. Prepare WebSocket notifications, WebSocket AI streaming, and future multi-node deployment without turning Go handlers into PHP-style blocking endpoints. SSE is intentionally not part of the new contract.

**Files:**
- Create: `E:/admin_go/docs/architecture/06-realtime-and-distributed-boundary.md`
- Modify/Create: `E:/admin_go/docs/contracts/admin-realtime-v1.md`
- Future backend package: `E:/admin_go/admin_back_go/internal/module/realtime/*`
- Future platform package: `E:/admin_go/admin_back_go/internal/platform/realtime/*`
- Future backend package: `E:/admin_go/admin_back_go/internal/module/ai/*`
- Future platform package: `E:/admin_go/admin_back_go/internal/platform/ai/*`
- Future command only if traffic requires: `E:/admin_go/admin_back_go/cmd/admin-realtime/main.go`

- [x] Document the realtime split: REST handles state changes; WebSocket handles bidirectional admin events, notifications, progress output, and AI token/audio/event streaming.
- [x] Document route namespaces before implementation: admin WebSocket upgrade starts at `GET /api/admin/v1/realtime/ws`; future app WebSocket starts at `GET /api/app/v1/realtime/ws`.
- [x] Select the WebSocket library only after a short open-source review. Record candidates, maintenance status, API shape, cancellation support, compression support, and why the chosen library fits Gin and tests.
  - Decision: use `github.com/gorilla/websocket` first because Gin official docs demonstrate this integration and it is the most familiar/stable baseline. Keep wrapper thin; do not hand-write WebSocket protocol.
- [x] Define the initial WebSocket contract: authenticate before upgrade or during the first message, bind user/session/platform, subscribe only to authorized topics, send heartbeat/pong, and cleanly close on auth expiry.
- [x] Define message envelope before code: `{"type":"notification.created.v1","request_id":"...","data":{...}}`; every event type is versioned.
- [x] Define topic rules: no arbitrary user-supplied topic names; allowed topics are built from server-side user ID, role/platform, or explicit permission scope.
- [x] Define distributed broadcast strategy: local connection manager first, Redis Pub/Sub or Redis Streams for multi-node fan-out later, no in-memory-only assumption in public contracts.
- [x] Define backpressure behavior: bounded send queues per connection, slow-client drop policy, metrics/logging for dropped messages, no unbounded goroutines.
- [x] Define graceful shutdown: stop accepting new upgrades, notify clients, drain bounded queues, close within timeout, and let load balancer retry.
- [x] Document current choice: `admin-api` may host initial WebSocket because Go handles many I/O goroutines well, but this is not permission to run CPU-heavy work in handlers.
- [x] Document the explicit no-SSE decision: no new `/sse` or `text/event-stream` API; AI streaming uses WebSocket message envelopes.
- [x] Document AI work split: Go manages auth/RBAC/session/streaming boundary; Python sidecar only when model ecosystem needs it.
- [x] Define WebSocket event format for AI streaming before implementing any AI stream endpoint.
- [x] Define cancellation endpoint contract before implementing long-running AI calls.
- [x] Define queue handoff for slow AI post-processing.
- [x] Define when to split `cmd/admin-realtime`: connection count, memory/fd pressure, deploy isolation, separate scaling need, or independent release cadence.
- [x] Add test plan for WebSocket connect/auth/heartbeat/disconnect, unauthorized subscribe rejection, slow-client backpressure, AI stream cancellation, and multi-node fan-out simulation.

**Exit criteria:** Realtime has one narrow verified foundation path and a distributed-safe contract before any notification, dashboard, or AI business stream depends on it.

---

## Phase 12: Business Module Migration Factory

**Purpose:** Every legacy PHP module migrates with the same repeatable method.

**Per-module workflow:**

- [ ] Pick one module only.
- [ ] Read legacy PHP controller/module/dep/validate/model for business facts.
- [ ] Read live DB table columns and indexes.
- [ ] Record legacy API mapping in `docs/migration/<module>.md`.
- [ ] Define new RESTful endpoints in `docs/contracts/admin-api-v1.md`.
- [ ] Write backend request/dto/service/repository tests first.
- [ ] Implement backend module under `internal/module/<module>`.
- [ ] Register routes under `/api/admin/v1/<resource>`.
- [ ] Register permission and operation log metadata if protected/mutating.
- [ ] Update frontend types.
- [ ] Update frontend API client.
- [ ] Update views/composables without adding fallback fields.
- [ ] Run backend tests.
- [ ] Run frontend typecheck/lint.
- [ ] Add or extend smoke coverage.
- [ ] Update migration status table.
- [ ] Report exact changed files and verification output.

**Recommended module order after admin core:**

1. Upload settings and upload driver
2. System settings
3. Notification read/list basics
4. Export tasks
5. Queue monitor read-only
6. Pay channel/recharge read paths
7. Pay write paths after contract review
8. AI model/tool config read/write
9. AI chat/WebSocket stream only after Phase 11

**Exit criteria:** Business migration is boring, repeatable, and audited.

---

## Phase 13: Documentation Governance

**Purpose:** Docs must stay true to runtime, not become a museum.

**Files:**
- `E:/admin_go/AGENTS.md`
- `E:/admin_go/docs/architecture/*.md`
- `E:/admin_go/docs/contracts/*.md`
- `E:/admin_go/docs/migration/*.md`
- `E:/admin_go/admin_back_go/docs/architecture.md`

- [ ] Keep root docs for workspace-wide decisions.
- [ ] Keep `admin_back_go/docs/architecture.md` for backend runtime architecture.
- [ ] Keep contracts in `docs/contracts`.
- [ ] Keep per-module migration notes in `docs/migration`.
- [ ] Any changed API requires contract doc update in the same task.
- [ ] Any changed architecture boundary requires architecture doc update in the same task.
- [ ] Any changed smoke/test command requires testing docs update in the same task.
- [ ] Do not document planned behavior as already implemented.
- [ ] Use status labels: implemented, partially implemented, planned, intentionally not supported.

**Exit criteria:** Docs are part of the Definition of Done, not cleanup.

---

## Phase 14: Release, Distributed Deployment, and Runtime Baseline

**Purpose:** Prepare local/dev/prod runtime and future horizontal deployment without pretending it is already microservices. The first target is a clean modular monolith that can run multiple `admin-api` replicas, one or more `admin-worker` processes, and later a separate `admin-realtime` process when traffic justifies it.

**Files:**
- `E:/admin_go/admin_back_go/.env.example`
- Create: `E:/admin_go/docs/deployment/local.md`
- Create: `E:/admin_go/docs/deployment/production.md`
- Create: `E:/admin_go/docs/deployment/distributed-readiness.md`
- Optional: `E:/admin_go/docker-compose.yml`
- Optional: `E:/admin_go/admin_back_go/Dockerfile`

- [ ] Document local startup for MySQL, Redis, admin-api, admin-worker, frontend.
- [ ] Document required env vars and Redis DB separation.
- [ ] Document port conflicts and how to check/stop port 8080 listeners.
- [ ] Document production process separation: `admin-api`, `admin-worker`, and future `admin-realtime`.
- [ ] Document stateless API rule: `admin-api` replicas must not rely on process memory for sessions, captcha, RBAC cache, login code, or realtime broadcast state.
- [ ] Document Redis responsibilities: session/token storage, RBAC cache invalidation, queue broker, scheduler locks if needed, and future WebSocket fan-out channel/stream.
- [ ] Document MySQL responsibilities: source of truth only; no polling loops in request handlers.
- [ ] Document load balancer rules: REST can be round-robin; WebSocket may use sticky sessions only as an operational optimization, not as a correctness requirement.
- [ ] Document graceful shutdown for `admin-api`, `admin-worker`, and future `admin-realtime`.
- [ ] Document config needed for multiple replicas: node ID, public base URL, CORS origins, trusted proxies, Redis namespace, queue concurrency, and realtime limits.
- [ ] Document log format and request ID propagation.
- [ ] Document CORS settings for frontend domains.
- [ ] Document captcha dev mode must be disabled in production after real sender exists.
- [ ] Add health/readiness explanation.
- [ ] Add backup and rollback notes for migrations.

**Exit criteria:** Another developer can run and deploy the system without asking what each process does.

---

## Phase 15: Final Full Verification Gate Before Calling It Stable

Run from `E:/admin_go/admin_back_go`:

```powershell
go test ./...
go vet ./...
go test -race ./internal/module/auth ./internal/module/session ./internal/platform/taskqueue ./internal/platform/scheduler ./internal/platform/realtime ./internal/jobs
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\basic-admin-smoke.ps1 -Account 15671628271 -Password 123456
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account 15671628271 -Password 123456
```

Run from `E:/admin_go/admin_front_ts`:

```powershell
npx vue-tsc -b --pretty false
npm run build
```

Then produce a final report:

```text
Outcome:
Changed files:
Backend verification:
Frontend verification:
Smoke summary:
Known remaining legacy modules:
Known risks:
Next recommended module:
```

---

## Current Next Step Recommendation

Start with **Phase 11 implementation: minimal authenticated WebSocket connect + heartbeat foundation**.

Reason:

```text
Phase 11 WebSocket-only direction is documented: SSE is intentionally excluded, admin/app routes are fixed, message envelope/topic/backpressure/distributed boundaries are defined, and AI streaming uses WebSocket events. 下一步才开始写最小实现：authenticated connect -> connected event -> ping/pong -> disconnect cleanup。
```
