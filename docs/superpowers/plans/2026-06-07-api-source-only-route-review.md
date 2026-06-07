# API Source-only Route Review Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Classify backend admin/canvas source-only routes so the API drift backlog contains only real owner decisions.

**Architecture:** Reuse the generated frontend/backend API drift artifact as input. Apply explicit project classification rules and keep unknowns fail-open into `owner-decision-required` instead of hiding them.

**Tech Stack:** PowerShell, Markdown, current `docs/knowledge/frontend-backend-api-drift-YYYY-MM-DD.md`.

---

**Source spec:** `docs/superpowers/specs/2026-06-07-api-source-only-route-review-design.md`

### Task 1: Source-only review exporter

**Files:**
- Create: `scripts/export-api-source-only-route-review.ps1`
- Create: `docs/knowledge/api-source-only-route-review-2026-06-07.md`

- [ ] **Step 1: Add exporter script**

The script must:

```text
1. Discover latest frontend-backend-api-drift-YYYY-MM-DD.md.
2. Parse the "Backend admin/canvas routes not referenced by exact frontend calls" table.
3. Classify runtime/system endpoints.
4. Classify queue monitor endpoints.
5. Classify retained Canvas payment/wallet domain endpoints.
6. Classify Admin uploadConfig DELETE routes covered by frontend parametric helper.
7. Classify everything unknown as owner-decision-required.
8. Write docs/knowledge/api-source-only-route-review-YYYY-MM-DD.md.
```

- [ ] **Step 2: Generate artifact**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\export-api-source-only-route-review.ps1 -OutputDate 2026-06-07
```

Expected output includes:

```text
source_only_routes=19
owner_decision_required=0
```

### Task 2: Knowledge docs integration

**Files:**
- Modify: `docs/knowledge/README.md`
- Modify: `docs/knowledge/current-runtime-knowledge.md`
- Modify: `docs/knowledge/runtime-source-map.md`
- Modify: `docs/architecture/02-agent-framework.md`
- Modify: `docs/status/current-status.md`
- Modify: `docs/status/known-issues.md`

- [ ] **Step 1: Link the review artifact**

Add `docs/knowledge/api-source-only-route-review-2026-06-07.md` to knowledge entrypoints and verification commands.

- [ ] **Step 2: Narrow API-DRIFT-001**

Update `API-DRIFT-001` so it no longer treats all source-only rows as equally unresolved. Keep the issue closed when owner-decision-required routes are `0`.

### Task 3: Fact checker integration

**Files:**
- Modify: `scripts/check-runtime-doc-facts.ps1`

- [ ] **Step 1: Discover latest review artifact**

Add latest-file discovery for `api-source-only-route-review-YYYY-MM-DD.md`.

- [ ] **Step 2: Assert required facts**

Check that the artifact:

```text
references latest frontend/backend API drift artifact
has Source-only routes reviewed = 19
has Owner-decision-required routes = 0
does not contain POST /api/admin/v1/ai-agents/:id/test after Admin AI agent test is wired from the frontend
does not contain PATCH /api/admin/v1/users/:id/status after Admin user status is wired from the frontend
does not contain POST /api/canvas/v1/auth/logout after Canvas logout is wired from the frontend
```

- [ ] **Step 3: Verify**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1 -LiveSchema
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected: all pass.
