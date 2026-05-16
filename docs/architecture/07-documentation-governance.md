# Documentation Governance

## Purpose

This document defines how `E:\admin_go` keeps documentation honest while the Go/Vue runtime evolves. It is a governance rule, not a product roadmap and not a replacement for runtime verification.

The point is simple: stop letting old plans, comments, or pretty architecture prose override what the system actually does.

## Truth-source order

When evidence conflicts, use this exact order:

```text
live runtime > smoke / test output > served API > process config > docs/status/current-status.md > docs/contracts > architecture docs > spec/plan docs > comments
```

Rules:

```text
live runtime behavior wins over checked-in intent.
smoke / test output must include the command and result, not a vague claim.
served API means the endpoint, payload, status code, and response shape actually observed.
process config means the effective environment, startup flags, enabled middleware, routes, queues, and workers.
docs/status/current-status.md records verified runtime facts only.
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
| deprecated | Still present, but no longer the preferred path. | Replacement path and compatibility note. |
| historical | Kept for provenance or archaeology. | Archive pointer; not active runtime truth. |

`current-status` is for verified runtime facts only. Do not move a plan into `implemented` because a spec was approved, a file was created, or a task checkbox was ticked.

## Docs sync matrix

| Change | Docs to check | Rule |
| --- | --- | --- |
| Backend API route, handler, request, response, auth, permission | `docs/contracts/admin-api-v1.md`, `docs/status/current-status.md`, relevant architecture docs, `docs/testing/smoke-matrix.md` | Update only when runtime behavior is verified. |
| Realtime/WebSocket behavior | `docs/contracts/admin-realtime-v1.md`, `docs/status/current-status.md`, realtime architecture docs, `docs/testing/smoke-matrix.md` | Served message shape beats planned contract text. |
| Queue, cron, worker, async side effect | `docs/status/current-status.md`, queue/scheduler architecture docs, smoke/test docs | Record idempotency, retry, and verification boundary. |
| Frontend route, menu, permission, API adapter | `docs/status/current-status.md`, API contract if the public shape changed, frontend/runtime docs | Do not document a route as usable until the served UI/API path works. |
| Database schema or seed baseline | `docs/status/current-status.md`, architecture docs, smoke/test docs | Schema text alone is not runtime proof. |
| Governance or agent workflow | `AGENTS.md`, `agents/README.md`, `docs/README.md`, this document, `docs/testing/pre-push-gates.md` | Keep onboarding paths discoverable and numbered paths stable. |
| Spec/plan changes only | The relevant spec/plan | Spec/plan history does not override `current-status`. |

## Verification matrix

| Evidence type | Acceptable proof | Not enough |
| --- | --- | --- |
| Runtime behavior | Command, request, browser/runtime observation, log, or smoke output showing the decisive branch. | “Looks implemented” from source only. |
| API contract | Served endpoint and payload match, or contract checker output. | Contract file changed without live or test evidence. |
| Smoke | Exact smoke command and result. | Pre-push hook pass. |
| Documentation-only change | `git diff --check` plus path/reference sanity. | No whitespace check. |
| Governance check | `git diff --check` and the governance checker when present. | Auto-fixing files silently. |

Hook/checker do not auto-fix files. They report drift and fail only on defined blocking rules. A human must decide the documentation correction.

## Archive policy

`docs/superpowers/archive/**` is historical. It may explain why a decision was made, but it does not override the current truth-source order.

Rules:

```text
active spec/plan docs live under docs/superpowers/specs or docs/superpowers/plans.
archived specs/plans are read only when provenance matters or the user asks for archaeology.
spec/plan history does not override current-status.
old paths must not be resurrected as current onboarding paths without verification.
```

## Documentation location ownership

This workspace uses root-first documentation, not root-only documentation.

Canonical root docs:

```text
docs/status/current-status.md
docs/contracts/*
docs/testing/*
docs/deployment/*
docs/architecture/*
docs/superpowers/specs/*
docs/superpowers/plans/*
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
