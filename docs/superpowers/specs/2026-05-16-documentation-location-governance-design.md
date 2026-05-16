# Documentation Location Governance Design

## Outcome

Make `E:/admin_go/docs` the canonical entry point for cross-repo documentation without pretending every runtime note belongs in the root repo.

This is a root-first layout, not a root-only layout.

## Problem

Agents need one stable cold-start path. Today the root docs already own status, contracts, architecture, deployment, and Superpowers specs/plans, but one frontend deployment runbook still lives only under `admin_front_ts/docs/deployment`. That creates two bad outcomes:

1. Deployment knowledge is hidden in a runtime subrepo.
2. Future agents may add long-lived docs wherever they happen to be working.

The fix is not to move every child doc into root. `admin_back_go/docs/architecture.md` is intentionally close to Go runtime code and remains valid. The fix is to document ownership and move cross-repo deployment docs to root.

## Rules

### Canonical root docs

These live under `E:/admin_go/docs`:

- `docs/status/current-status.md`
- `docs/contracts/*`
- `docs/testing/*`
- `docs/deployment/*`
- `docs/architecture/*`
- `docs/superpowers/specs/*`
- `docs/superpowers/plans/*`
- `docs/superpowers/archive/*`

### Allowed subrepo docs

Subrepo docs are allowed only when they are close to runtime code and not a second truth source:

- `admin_back_go/docs/architecture.md` remains the backend runtime architecture document.
- `admin_front_ts/docs/**` may keep short stubs that point to canonical root docs, or frontend-repo-local workflow notes that do not define cross-repo deployment, API, status, contract, or agent governance truth.

### Disallowed subrepo docs

Do not add active specs/plans or long-lived deployment runbooks under child repos:

- `admin_back_go/docs/superpowers/specs/*`
- `admin_back_go/docs/superpowers/plans/*`
- `admin_front_ts/docs/deployment/*.md` with real deployment content instead of a stub

## Migration in this slice

Move the frontend GitHub Actions + SCP deployment runbook from:

```text
admin_front_ts/docs/deployment/github-actions-scp.md
```

to:

```text
docs/deployment/frontend-github-actions-scp.md
```

Then replace the old frontend file with a stub that links to the canonical root doc.

## Checker behavior

`scripts/check-agent-governance.ps1` should make the rule visible:

- Keep blocking active backend-local Superpowers specs/plans.
- Block non-stub frontend deployment docs when the path is visible to the checker.
- Treat stubs as valid if they contain `Canonical doc:` and the canonical root path.
- Keep the gate lightweight: git/path/content checks only, no DB, Redis, backend process, frontend build, or smoke.

## Non-goals

- Do not move `admin_back_go/docs/architecture.md`.
- Do not split backend architecture in this slice.
- Do not introduce frontend build or backend smoke requirements for documentation-only changes.
- Do not change deployment workflow behavior.
