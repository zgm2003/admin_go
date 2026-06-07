# Backend Route Contract Drift Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate a source-backed contract drift report that compares current Go backend route inventory with current contract/status/knowledge docs.

**Architecture:** Reuse the generated backend route inventory as the source of route truth, then scan current Markdown docs for exact and prefix references. Keep the result as evidence/navigation, not as a blocking API compatibility verdict.

**Tech Stack:** PowerShell, Markdown, current `docs/knowledge/backend-route-inventory-YYYY-MM-DD.md`.

---

**Source spec:** `docs/superpowers/specs/2026-06-07-backend-route-contract-drift-design.md`

### Task 1: Drift exporter

**Files:**
- Create: `scripts/export-backend-route-contract-drift.ps1`
- Create: `docs/knowledge/backend-route-contract-drift-2026-06-07.md`

- [ ] **Step 1: Add exporter script**

The script must:

```text
1. Discover the latest backend-route-inventory-YYYY-MM-DD.md
2. Parse route table rows
3. Scan docs/contracts/*.md for exact path and resource-prefix references
4. Scan docs/status/*.md and docs/knowledge/*.md for exact source-doc references
5. Write docs/knowledge/backend-route-contract-drift-YYYY-MM-DD.md
```

- [ ] **Step 2: Generate artifact**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\export-backend-route-contract-drift.ps1 -OutputDate 2026-06-07
```

Expected: writes the drift report and prints route count.

### Task 2: Knowledge and fact checker integration

**Files:**
- Modify: `docs/knowledge/README.md`
- Modify: `docs/knowledge/current-runtime-knowledge.md`
- Modify: `docs/knowledge/runtime-source-map.md`
- Modify: `scripts/check-runtime-doc-facts.ps1`

- [ ] **Step 1: Link report**

Add the drift report to knowledge entrypoints and refresh commands.

- [ ] **Step 2: Guard report freshness**

Extend runtime fact checker so it discovers latest `backend-route-contract-drift-YYYY-MM-DD.md`, checks knowledge references, and compares the drift report route count with the backend route inventory count.

- [ ] **Step 3: Verify**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1 -LiveSchema
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected: all pass.

