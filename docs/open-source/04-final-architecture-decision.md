# Architecture Decision Checkpoint

## Status

Draft checkpoint, not final implementation approval.

## Decisions already fixed

```text
Main backend language: Go
Go runtime direction: Gin-based admin API
AI integration: Python sidecar only when needed for AI ecosystem
Frontend: keep current admin_front_ts, adapt later through contract
Delivery: phase-gated, step by step
```

## Decisions not fixed yet

```text
Exact RBAC table design
Whether to use Casbin or a smaller explicit permission checker
Whether GORM is final or replaced by sqlc/ent after research
Exact OpenAPI response schema
Exact frontend menu/route payload
Whether generator/scaffold tools are allowed after core is stable
```

## Current recommended architecture direction

```text
apps are already split physically:
E:\admin_go\admin_back_go
E:\admin_go\admin_front_ts
```

Back-end direction:

```text
Gin HTTP server
simple module boundaries
route -> handler -> service -> repository -> model
RBAC-first core
WebSocket realtime and async jobs treated as first-class Go use cases later
```

Frontend direction:

```text
Keep Vue 3 + Element Plus frontend
No visual rewrite
Replace API boundary gradually after OpenAPI exists
```

Agent direction:

```text
Architect Agent: finish source-level comparison
API Contract Agent: write OpenAPI only after RBAC model decision
Backend Worker Agent: blocked until OpenAPI and minimal skeleton plan
Frontend Adapter Agent: blocked until OpenAPI
Reviewer Agent: checks every phase for scope creep
```

## Next required work

Before Go initialization, Architect Agent must produce:

```text
1. Source-level comparison of gin-vue-admin RBAC/menu/API permission
2. Source-level comparison of go-admin-team RBAC/menu/API permission
3. Short rejection/adoption table for RuoYi-style frontend permission model
4. Final Phase 2 skeleton decision
```

## Stop condition

If a proposed implementation cannot point back to a researched open-source pattern, do not implement it.
