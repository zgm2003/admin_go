# Docs Governance Working Review - 2026-05-29

状态：working review，供提交前审阅使用。
范围：root docs governance、Superpowers 文档维护、status 分层、module 分组明细、backend Docker-first 文档口径，以及当前 dirty workspace 中的 frontend TTL/i18n 相关改动。

本文件不是 runtime truth；runtime truth 仍按：

```text
live runtime / smoke / served API / process config
> docs/status/current-status.md
> docs/status/module-matrix.md
> contracts / architecture / testing docs
> docs/superpowers/specs|plans|reviews
> docs/superpowers/archive
```

## Linus 三问

1. 这是真问题吗？是。当前 workspace 同时有 root docs、backend docs、frontend tests/i18n 改动；不先归类，后续提交和验收会混账。
2. 有更简单的方法吗？有。只做审阅清单，不引入新流程、不改业务代码、不重跑昂贵 runtime。
3. 会破坏 userspace 吗？不会。本轮是文档/审阅元数据；不能把它当 runtime 验证。

## Current dirty workspace map

### Root governance / docs

```text
AGENTS.md
agents/README.md
docs/README.md
docs/architecture/00-platform-and-module-rules.md
docs/architecture/02-agent-framework.md
docs/architecture/04-go-backend-framework.md
docs/architecture/05-development-quality-rules.md
docs/architecture/06-realtime-and-distributed-boundary.md
docs/architecture/07-documentation-governance.md
docs/contracts/admin-api-v1.md
docs/contracts/admin-realtime-v1.md
docs/deployment/docker-first-backend.md
docs/deployment/local.md
docs/deployment/production.md
docs/testing/smoke-matrix.md
docs/testing/test-strategy.md
```

Review focus:

- `docs/README.md` is now the canonical cold-start index; other docs should link to it instead of copying full lists.
- `docs/testing/test-strategy.md` owns full validation gates; root README only points to it.
- Realtime docs must keep current AI cancel truth: REST cancel, WebSocket only publishes `start/delta/completed/failed`.
- Docker-first docs must keep backend-only / Baota Docker / no frontend-in-Docker scope.

### Status truth split

```text
docs/status/current-status.md
docs/status/module-matrix.md
docs/status/archive/2026-05-runtime-change-log.md
```

Review focus:

- `current-status.md` should stay small: current key facts, verification gaps, pointers.
- `module-matrix.md` is now a grouped module index, not a giant Markdown table.
- `archive/2026-05-runtime-change-log.md` is historical evidence only; it must not override current-status or module-matrix.
- Phase 2 remains smoke-pending unless both basic and full admin smoke pass.

### Superpowers docs

```text
docs/superpowers/README.md
docs/superpowers/archive/backend-bootstrap/README.md
docs/superpowers/plans/2026-05-28-multi-platform-phase2-execution-map.md
docs/superpowers/plans/2026-05-29-channel-specific-verify-code-ttl.md
docs/superpowers/plans/2026-05-29-multi-platform-16-wallet-payment-aggregation.md
docs/superpowers/plans/2026-05-29-multi-platform-17-phase2-closure-review.md
docs/superpowers/plans/2026-05-29-transport-admin-alias-cleanup.md
docs/superpowers/specs/2026-05-27-channel-specific-verify-code-ttl-design.md
docs/superpowers/specs/2026-05-27-multi-platform-backend-boundary-design.md
```

Review focus:

- `docs/superpowers/README.md` is the root index for specs/plans/reviews/archive.
- Superpowers docs are design/execution provenance, not runtime truth.
- Old plan wording that says current-status module row now maps to module-matrix section.
- Active plans may mention future conditional closure, but current default must stay smoke-pending.

### Backend docs / Docker-first assets

```text
admin_back_go/deploy/docker-first/README.md
admin_back_go/deploy/docker-first/admin-go.env.example
admin_back_go/docs/architecture.md
admin_back_go/internal/module/README.md
```

Review focus:

- `internal/module/README.md` should describe capability root + `transport/{platform}`; no root HTTP surface.
- Backend architecture should describe current module topology without turning docs into a second status source.
- Docker env template must warn that `127.0.0.1` inside container means container itself.
- Production runbook remains root `docs/deployment/docker-first-backend.md`; deploy assets remain under `admin_back_go/deploy/docker-first`.

### Frontend TTL/i18n/test dirty files

```text
admin_front_ts/src/i18n/locales/en-US.ts
admin_front_ts/src/i18n/locales/zh-CN.ts
admin_front_ts/tests/shared/system/mail-api.test.ts
admin_front_ts/tests/shared/system/sms-api.test.ts
```

Review focus:

- These are not docs-only changes; before frontend merge/push, run the relevant Vitest and type checks in `admin_front_ts`.
- They appear tied to channel-specific verify-code TTL contract/i18n work; do not hide them inside a docs-only commit.

## Current verification evidence

Fresh checks already run in this workspace after the module-matrix regrouping:

```powershell
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
git -C admin_back_go diff --check
```

Observed result:

```text
git diff --check: exit 0; CRLF warnings only
check-agent-governance.ps1 -Mode working: PASS, no blocking governance violations
git -C admin_back_go diff --check: exit 0; CRLF warnings only
```

Extra local checks for untracked docs:

```text
manual whitespace check passed for untracked docs
module-matrix structure check passed: groups=9, modules=35, unique_modules=35
```

Frontend targeted verification for the dirty mail/sms TTL copy/tests was run after this review file was created:

```powershell
cd E:\admin_go\admin_front_ts
npx vitest run tests/shared/system/mail-api.test.ts tests/shared/system/sms-api.test.ts --maxWorkers=1
npx vue-tsc -b --pretty false
```

Observed result:

```text
Vitest: 2 test files passed, 17 tests passed
vue-tsc: exit 0
```

## Not verified by this review

Do not claim these from this file:

- Go tests pass.
- Vue production build passes.
- Basic or full admin smoke passes.
- Docker runtime is currently healthy.
- Live DB schema matches docs.
- Third-party provider tests pass.

## Exact current-state commit slicing audit

本节最初是 dirty workspace 的精确覆盖图；后续执行已按这些 slice 精确暂存，未使用 blanket add。最终覆盖检查结果：

```text
root: changed=29, covered=29, missing=[], extra=[]
backend: changed=4, covered=4, missing=[], extra=[]
frontend: changed=4, covered=4, missing=[], extra=[]
```

Final staged state after blocker fixes:

```text
root: staged=29, unstaged=0
backend: staged=4, unstaged=0
frontend: staged=4, unstaged=0
```

Additional blockers fixed during final review:

- Root realtime/deployment docs no longer list implemented AI conversation event envelopes as planned, no longer default production realtime publisher to `local`, and no longer claim Docker-first local runtime has full smoke verification.
- Root channel-specific TTL spec now labels the shared `system_settings.auth.verify_code.ttl_minutes` notes as the 2026-05-27 baseline, not current runtime fact.
- Backend Docker-first env template no longer defaults production container runtime to `127.0.0.1` MySQL/Redis, and backend architecture docs now point HTTP request binding to `transport/{platform}/request.go`.

Fresh final checks after exact staging:

```text
git diff --cached --check: pass
git diff --check: pass
check-agent-governance.ps1 -Mode working: pass
git -C admin_back_go diff --cached --check: pass
git -C admin_back_go diff --check: pass
git -C admin_front_ts diff --cached --check: pass
git -C admin_front_ts diff --check: pass
frontend targeted Vitest: 2 files passed, 17 tests passed
frontend vue-tsc: exit 0
```

### Slice 1: root governance/status/Superpowers docs

Commit message candidate:

```text
docs: split runtime status truth and formalize governance docs
```

Stage from `E:\admin_go`:

```powershell
git add -- AGENTS.md agents/README.md docs/README.md `
  docs/architecture/00-platform-and-module-rules.md `
  docs/architecture/02-agent-framework.md `
  docs/architecture/04-go-backend-framework.md `
  docs/architecture/05-development-quality-rules.md `
  docs/architecture/07-documentation-governance.md `
  docs/status/current-status.md `
  docs/status/module-matrix.md `
  docs/status/archive/2026-05-runtime-change-log.md `
  docs/superpowers/README.md `
  docs/superpowers/archive/backend-bootstrap/README.md `
  docs/superpowers/plans/2026-05-28-multi-platform-phase2-execution-map.md `
  docs/superpowers/plans/2026-05-29-multi-platform-16-wallet-payment-aggregation.md `
  docs/superpowers/plans/2026-05-29-multi-platform-17-phase2-closure-review.md `
  docs/superpowers/plans/2026-05-29-transport-admin-alias-cleanup.md `
  docs/superpowers/specs/2026-05-27-multi-platform-backend-boundary-design.md `
  docs/superpowers/reviews/2026-05-29-docs-governance-working-review.md `
  docs/testing/test-strategy.md
```

Review note:

- This slice is docs/governance only.
- It should not claim Go/Vue runtime behavior or smoke completion.
- It intentionally keeps Phase 2 smoke-pending.

### Slice 2: root runtime contract/deployment docs

Commit message candidate:

```text
docs: align realtime and docker-first verification boundaries
```

Stage from `E:\admin_go`:

```powershell
git add -- docs/architecture/06-realtime-and-distributed-boundary.md `
  docs/contracts/admin-realtime-v1.md `
  docs/deployment/docker-first-backend.md `
  docs/deployment/local.md `
  docs/deployment/production.md `
  docs/testing/smoke-matrix.md
```

Review note:

- This slice updates contracts/deployment/testing docs only.
- It must preserve: AI cancel via REST, WebSocket events limited to `start/delta/completed/failed`, Docker readiness separate from smoke.
- It still does not prove Docker health or admin smoke.

### Slice 3: root channel-specific verify-code TTL docs

Commit message candidate:

```text
docs: record channel-specific verify-code ttl boundary
```

Stage from `E:\admin_go`:

```powershell
git add -- docs/contracts/admin-api-v1.md `
  docs/superpowers/specs/2026-05-27-channel-specific-verify-code-ttl-design.md `
  docs/superpowers/plans/2026-05-29-channel-specific-verify-code-ttl.md
```

Review note:

- This slice pairs with the frontend TTL copy/test slice, but it lives in the root repo.
- It should not claim full smoke passed; current evidence says full smoke stopped at the existing upload-token probe failure.

### Slice 4: backend docs / Docker-first assets

Commit message candidate for `admin_back_go`:

```text
docs: align module boundary and docker-first assets
```

Stage from `E:\admin_go\admin_back_go`:

```powershell
git add -- deploy/docker-first/README.md `
  deploy/docker-first/admin-go.env.example `
  docs/architecture.md `
  internal/module/README.md
```

Review note:

- This is backend repository docs/assets only.
- It keeps frontend out of Docker-first backend deployment.
- It must not claim backend tests, `/health`, or `/ready` unless those are freshly run.

### Slice 5: frontend channel-specific TTL copy/tests

Commit message candidate for `admin_front_ts`:

```text
frontend: clarify channel-specific verify-code ttl copy
```

Stage from `E:\admin_go\admin_front_ts`:

```powershell
git add -- src/i18n/locales/en-US.ts `
  src/i18n/locales/zh-CN.ts `
  tests/shared/system/mail-api.test.ts `
  tests/shared/system/sms-api.test.ts
```

Verification already run for this slice:

```powershell
npx vitest run tests/shared/system/mail-api.test.ts tests/shared/system/sms-api.test.ts --maxWorkers=1
npx vue-tsc -b --pretty false
```

Observed result:

```text
Vitest: 2 test files passed, 17 tests passed
vue-tsc: exit 0
```

Review note:

- This is not a docs-only slice.
- If it waits across many edits, rerun the two frontend commands before commit/push.
- Vue production build remains unverified.

### Do not use blanket add yet

Avoid this until the slice owner intentionally accepts every dirty path:

```powershell
git add .
git -C admin_back_go add .
git -C admin_front_ts add .
```

The current workspace has separate root, backend, and frontend repos. A root docs commit cannot include backend/frontend repository changes unless those repos are committed separately.

## Before push checklist

Minimum docs/governance gate:

```powershell
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
git -C admin_back_go diff --check
git -C admin_front_ts diff --check
```

If keeping frontend TTL/i18n changes in the same push, keep this targeted frontend verification evidence fresh:

```powershell
cd E:\admin_go\admin_front_ts
npx vitest run tests/shared/system/mail-api.test.ts tests/shared/system/sms-api.test.ts --maxWorkers=1
npx vue-tsc -b --pretty false
```

If claiming runtime stability, add backend/runtime verification from `docs/testing/test-strategy.md`; docs-only gates are not enough.
