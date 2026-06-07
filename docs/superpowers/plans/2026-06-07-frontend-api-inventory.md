# Frontend API Inventory Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate a source-backed inventory of Admin Vue and Canvas Next frontend API calls for later frontend/backend contract drift work.

**Architecture:** Keep the exporter read-only against the frontend workspaces. Use PowerShell for repo integration and a small embedded TypeScript AST parser for call extraction, then write one Markdown artifact under `docs/knowledge`.

**Tech Stack:** PowerShell, Node.js, TypeScript compiler API from existing frontend `node_modules`, Markdown.

---

**Source spec:** `docs/superpowers/specs/2026-06-07-frontend-api-inventory-design.md`

### Task 1: Frontend API inventory exporter

**Files:**
- Create: `scripts/export-frontend-api-inventory.ps1`
- Create: `docs/knowledge/frontend-api-inventory-2026-06-07.md`

- [ ] **Step 1: Add exporter script**

The script must:

```text
1. Scan the active Admin Vue and Canvas Next source roots from the spec.
2. Exclude tests and declarations.
3. Parse .ts/.tsx files and Vue <script> blocks.
4. Extract request/apiGet/apiPost/apiPut/apiDelete/axios/fetch call expressions.
5. Resolve literal, const, simple concat, and template URL expressions.
6. Classify exact backend calls separately from external/blob/proxy/wrapper/parametric calls.
7. Refuse silent guessing by keeping unresolved expressions visible.
```

- [ ] **Step 2: Generate artifact**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\export-frontend-api-inventory.ps1 -OutputDate 2026-06-07
```

Expected output includes:

```text
Wrote docs\knowledge\frontend-api-inventory-2026-06-07.md
unresolved_calls=0
```

### Task 2: Knowledge docs integration

**Files:**
- Modify: `docs/knowledge/README.md`
- Modify: `docs/knowledge/current-runtime-knowledge.md`
- Modify: `docs/knowledge/runtime-source-map.md`
- Modify: `docs/architecture/02-agent-framework.md`

- [ ] **Step 1: Link the artifact**

Add `docs/knowledge/frontend-api-inventory-2026-06-07.md` to knowledge entrypoints and source-map verification commands.

- [ ] **Step 2: Clarify truth boundary**

Document that the frontend API inventory is source inventory only. It does not prove served routes, browser runtime behavior, or contract compatibility by itself.

### Task 3: Fact checker integration

**Files:**
- Modify: `scripts/check-runtime-doc-facts.ps1`

- [ ] **Step 1: Discover latest artifact**

Add latest-file discovery for `frontend-api-inventory-YYYY-MM-DD.md`.

- [ ] **Step 2: Assert required facts**

Check that the artifact is referenced by knowledge docs and contains:

```text
GET /api/admin/v1/users/me
GET /api/canvas/v1/users/me
POST /api/canvas/v1/auth/logout
Unresolved frontend API expressions | `0`
```

- [ ] **Step 3: Verify**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1 -LiveSchema
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected: all pass.
