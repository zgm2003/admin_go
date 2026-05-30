# Documentation Governance

## Purpose

This document defines how `E:\admin_go` keeps documentation honest while the Go/Vue runtime evolves. It is a governance rule, not a product roadmap and not a replacement for runtime verification.

The point is simple: stop letting old plans, comments, or pretty architecture prose override what the system actually does.

## Truth-source order

When evidence conflicts, use this exact order:

```text
live runtime > smoke / test output > served API > process config > docs/status/current-status.md + docs/status/module-matrix.md + docs/status/known-issues.md > docs/contracts > architecture docs > spec/plan docs > comments
```

Rules:

```text
live runtime behavior wins over checked-in intent.
smoke / test output must include the command and result, not a vague claim.
served API means the endpoint, payload, status code, and response shape actually observed.
process config means the effective environment, startup flags, enabled middleware, routes, queues, and workers.
docs/status/current-status.md is the current status entry; docs/status/module-matrix.md records per-module verified runtime facts; docs/status/known-issues.md records current bug/WIP evidence that must not be treated as verified.
docs/contracts records intended public API/realtime shape, but it must be corrected when served API proves drift.
architecture docs define boundaries and decisions, but they do not prove implementation.
spec/plan docs record design and execution history only.
comments are last; stale comments do not overrule working code.
```

## Status taxonomy

Use these words strictly:

| Status | Meaning | Required evidence |
| --- | --- | --- |
| implemented | The runtime behavior exists and was verified. | Code path plus command/output, smoke/test, served API, or runtime inspection. |
| partially implemented | Some runtime behavior exists, but the chain is incomplete. | What works, what is missing, and how it was checked. |
| planned | The work is designed or scheduled, but not live. | Spec/plan reference only. Planned is not implemented. |
| known issue / WIP | A bug, failing test, dirty follow-up, or unfinished patch is known but not closed. | Evidence, failure command/output, affected files, and the required decision before code changes. |
| deprecated | Still present, but no longer the preferred path. | Replacement path and compatibility note. |
| historical | Kept for provenance or archaeology. | Archive pointer; not active runtime truth. |

`current-status` is for verified runtime facts only. Do not move a plan into `implemented` because a spec was approved, a file was created, or a task checkbox was ticked.

`known-issues` is the parking lot for current red lights. It exists to stop chat-only bug evidence from being lost, not to bless WIP as done. When a known issue is fixed and verified, move the relevant facts back into `current-status` / `module-matrix` / contracts as needed and remove or close the issue entry.

## Docs sync matrix

| Change | Docs to check | Rule |
| --- | --- | --- |
| Backend API route, handler, request, response, auth, permission | `docs/contracts/admin-api-v1.md`, `docs/status/current-status.md`, `docs/status/module-matrix.md`, relevant architecture docs, `docs/testing/smoke-matrix.md` | Update only when runtime behavior is verified. |
| Realtime/WebSocket behavior | `docs/contracts/admin-realtime-v1.md`, `docs/status/current-status.md`, `docs/status/module-matrix.md`, realtime architecture docs, `docs/testing/smoke-matrix.md` | Served message shape beats planned contract text. |
| Queue, cron, worker, async side effect | `docs/status/current-status.md`, `docs/status/module-matrix.md`, queue/scheduler architecture docs, smoke/test docs | Record idempotency, retry, and verification boundary. |
| Frontend route, menu, permission, API adapter | `docs/status/current-status.md`, `docs/status/module-matrix.md`, API contract if the public shape changed, frontend/runtime docs | Do not document a route as usable until the served UI/API path works. |
| Database schema or seed baseline | `docs/status/current-status.md`, `docs/status/module-matrix.md`, architecture docs, smoke/test docs | Schema text alone is not runtime proof. |
| Known bug, failing test, dirty WIP, or unfinished follow-up | `docs/status/known-issues.md`; update `docs/status/current-status.md` only with a short pointer if it affects current verification gaps | Do not write it as implemented/verified until the fix is committed and the relevant tests or runtime checks pass. |
| Governance or agent workflow | `docs/README.md`, this document, `docs/testing/pre-push-gates.md`; `AGENTS.md` / `agents/README.md` only keep short references and role boundaries | Cold-start/onboarding list has one owner: `docs/README.md`. Do not maintain parallel reading lists. |
| Codex lifecycle hook behavior | `docs/architecture/08-codex-hooks.md`; `.codex/hooks.json` / `.codex/hooks/*.ps1` / `scripts/test-codex-hooks.ps1` when hook implementation changes; `docs/testing/pre-push-gates.md` | Hooks are conversation-time governance only; they must not be documented as runtime proof or smoke evidence. |
| Spec/plan changes only | The relevant spec/plan | Spec/plan history does not override `current-status`. |

## Verification matrix

| Evidence type | Acceptable proof | Not enough |
| --- | --- | --- |
| Runtime behavior | Command, request, browser/runtime observation, log, or smoke output showing the decisive branch. | “Looks implemented” from source only. |
| API contract | Served endpoint and payload match, or contract checker output. | Contract file changed without live or test evidence. |
| Smoke | Exact smoke command and result. | Pre-push hook pass. |
| Documentation-only change | `git diff --check` plus `scripts/check-agent-governance.ps1 -Mode working` and path/reference sanity. | No whitespace check. |
| Governance check | `git diff --check` and the governance checker when present. | Auto-fixing files silently. |
| Codex hook behavior | `scripts/test-codex-hooks.ps1` output when hook scripts exist plus `/hooks` review/trust note when hook config changed. | Assuming Codex loaded changed hooks without review. |

Hook/checker do not auto-fix files. They report drift and fail only on defined blocking rules. A human must decide the documentation correction.

## Archive policy

`docs/superpowers/archive/**` and `docs/status/archive/**` are historical. They may explain why a decision was made or preserve old verification evidence, but they do not override the current truth-source order.

Rules:

```text
active spec/plan docs live under docs/superpowers/specs or docs/superpowers/plans.
active review docs live under docs/superpowers/reviews.
archived specs/plans are read only when provenance matters or the user asks for archaeology.
spec/plan history does not override current-status.
old paths must not be resurrected as current onboarding paths without verification.
old cold-start, verification, or status-entry docs must become stubs or archive pointers once they stop being canonical.
archive docs must not keep complete active reading lists, mandatory gates, or current status matrices.
```

## Documentation location ownership

This workspace uses root-first documentation, not root-only documentation.

Canonical root docs:

```text
docs/status/current-status.md
docs/status/module-matrix.md
docs/status/known-issues.md
docs/status/archive/*
docs/contracts/*
docs/testing/*
docs/deployment/*
docs/architecture/*
docs/superpowers/specs/*
docs/superpowers/plans/*
docs/superpowers/reviews/*
docs/superpowers/archive/*
```

Allowed subrepo docs:

```text
admin_back_go/docs/architecture.md
```

That file stays next to Go runtime code because it records backend runtime architecture. Moving it to root would create longer edit loops without improving truth.

Frontend deployment docs are different. Deployment is a workspace/release concern, so the canonical frontend deploy runbook lives at:

```text
docs/deployment/frontend-github-actions-scp.md
```

The old frontend path may exist only as a moved stub:

```text
admin_front_ts/docs/deployment/github-actions-scp.md
```

Rules:

```text
do not add active spec/plan docs under admin_back_go/docs/superpowers or admin_front_ts/docs/superpowers.
do not keep long-lived deployment runbooks under admin_front_ts/docs/deployment.
frontend deployment stubs must point to the canonical root docs/deployment path.
root docs index subrepo docs; subrepo docs must not become a second current-status, contract, smoke, or deployment truth source.
```

## Multi-repo rules

`E:\admin_go` is the governance/root workspace. `admin_back_go` and `admin_front_ts` are separate runtime repos.

Rules:

```text
root docs can describe cross-repo policy, but cannot pretend a backend/frontend change happened.
backend runtime changes must be verified in admin_back_go.
frontend runtime changes must be verified in admin_front_ts.
reports must state which repo changed.
do not auto-stage, auto-commit, auto-revert, or auto-fix files across repos.
pre-push governance must not require DB/Redis/backend/frontend to be online.
```

## What this doc does not control

This document does not define business API fields, RBAC semantics, database migrations, queue payloads, UI design, release approval, or smoke coverage. Those belong to contracts, runtime docs, module specs, and smoke/test docs.

It also does not make planned work real. If runtime evidence is missing, the status is still `planned` or `partially implemented`.
