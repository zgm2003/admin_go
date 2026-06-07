# Full-stack Module Map Design

Date: 2026-06-07

## Problem

The current knowledge base has separate source inventories for backend routes, frontend API calls, and live MySQL table ownership. That is useful, but Codex still has to manually join three artifacts before touching a module.

That manual join is bad taste:

- It invites guessed ownership.
- It hides backend routes that only appear as frontend gaps.
- It makes DB tables look separate from the Go capability that owns them.
- It forces every future agent to repeat the same source navigation work.

## Goal

Generate a module-level full-stack map from current artifacts:

```text
backend route inventory
frontend API inventory
live DB schema ownership map
API source-only route review
```

The output must answer, per capability:

```text
Which platforms expose routes?
How many backend routes exist?
Which exact frontend API calls hit this capability?
Which live MySQL tables are owned by this capability?
Which source-only route review categories remain?
```

## Non-goals

```text
No runtime smoke proof.
No migration history.
No route guessing.
No fallback ownership inference when a frontend call cannot match a backend route.
No rewriting Go/Vue/Next code.
```

## Data rules

Truth order for this artifact:

```text
1. latest live MySQL schema ownership artifact
2. latest backend route source inventory
3. latest frontend API source inventory
4. latest API source-only route review
```

Frontend calls must map to backend capability through method + normalized route path. If an exact backend-prefixed frontend call cannot be matched to a backend route inventory row, the exporter must fail instead of assigning it to "unknown".

## Expected artifact

```text
docs/knowledge/full-stack-module-map-YYYY-MM-DD.md
scripts/export-full-stack-module-map.ps1
```

The artifact is a navigation and ownership map. It is not served-route proof and must say so explicitly.
