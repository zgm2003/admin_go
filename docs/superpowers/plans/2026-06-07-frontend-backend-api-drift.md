# Frontend Backend API Drift Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Compare current frontend source API calls against current Go backend route source inventory without guessing runtime behavior.

**Architecture:** Reuse generated Markdown inventories as inputs. Normalize dynamic route segments to `:param`, match frontend exact method/path calls to backend routes, and keep non-exact frontend rows out of exact matching.

**Tech Stack:** PowerShell, Markdown, current `docs/knowledge/backend-route-inventory-YYYY-MM-DD.md`, current `docs/knowledge/frontend-api-inventory-YYYY-MM-DD.md`.

---

**Source spec:** `docs/superpowers/specs/2026-06-07-frontend-backend-api-drift-design.md`

### Task 1: Drift exporter

**Files:**
- Create: `scripts/export-frontend-backend-api-drift.ps1`
- Create: `docs/knowledge/frontend-backend-api-drift-2026-06-07.md`

- [ ] **Step 1: Add exporter script**

The script must:

```text
1. Discover latest backend-route-inventory-YYYY-MM-DD.md.
2. Discover latest frontend-api-inventory-YYYY-MM-DD.md.
3. Parse backend route inventory rows.
4. Parse frontend exact backend API call rows.
5. Normalize dynamic path segments to :param.
6. Treat backend ANY routes as matching concrete frontend methods.
7. Classify frontend calls as route-match, method-mismatch, or no-backend-route.
8. Keep parametric/backend wrapper/blob/external/proxy rows outside exact matching.
9. Write docs/knowledge/frontend-backend-api-drift-YYYY-MM-DD.md.
```

- [ ] **Step 2: Generate artifact**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\export-frontend-backend-api-drift.ps1 -OutputDate 2026-06-07
```

Expected output includes:

```text
frontend_method_mismatch=0
frontend_no_backend_route=0
```

### Task 2: Knowledge docs integration

**Files:**
- Modify: `docs/knowledge/README.md`
- Modify: `docs/knowledge/current-runtime-knowledge.md`
- Modify: `docs/knowledge/runtime-source-map.md`
- Modify: `docs/architecture/02-agent-framework.md`
- Modify: `docs/status/current-status.md`

- [ ] **Step 1: Link the drift report**

Add `docs/knowledge/frontend-backend-api-drift-2026-06-07.md` to knowledge entrypoints and source-map verification commands.

- [ ] **Step 2: Clarify truth boundary**

State that the report compares generated source inventories only. It does not prove served HTTP behavior or browser runtime.

### Task 3: Fact checker integration

**Files:**
- Modify: `scripts/check-runtime-doc-facts.ps1`

- [ ] **Step 1: Discover latest drift artifact**

Add latest-file discovery for `frontend-backend-api-drift-YYYY-MM-DD.md`.

- [ ] **Step 2: Assert required facts**

Check that the artifact:

```text
references latest backend route inventory
references latest frontend API inventory
has frontend-method-mismatch = 0
has frontend-no-backend-route = 0
is referenced by knowledge docs
```

- [ ] **Step 3: Verify**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1 -LiveSchema
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected: all pass.
