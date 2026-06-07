# Backend Route Inventory Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate a source-backed backend route inventory artifact for the current Go runtime.

**Architecture:** Add one focused PowerShell exporter that reads Go route source files and explicit route metadata, then writes a Markdown inventory. Keep it as navigation evidence only; smoke/runtime behavior remains higher priority.

**Tech Stack:** PowerShell, Markdown, current `admin_back_go` Go source tree.

---

**Source spec:** `docs/superpowers/specs/2026-06-07-backend-route-inventory-design.md`

### Task 1: Route inventory exporter

**Files:**
- Create: `scripts/export-backend-route-inventory.ps1`
- Create: `docs/knowledge/backend-route-inventory-2026-06-07.md`

- [ ] **Step 1: Add exporter script**

Implement a script that:

```text
1. Reads admin_back_go/internal/module/**/*route*.go
2. Resolves simple const string paths and router.Group(...) prefixes
3. Extracts GET/POST/PUT/PATCH/DELETE/OPTIONS/HEAD/Any route registrations with line numbers
4. Reads permission/operation metadata from admin_back_go/internal/bootstrap/route_meta.go
5. Writes docs/knowledge/backend-route-inventory-YYYY-MM-DD.md
```

- [ ] **Step 2: Generate artifact**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\export-backend-route-inventory.ps1 -OutputDate 2026-06-07
```

Expected: `Wrote docs/knowledge/backend-route-inventory-2026-06-07.md`.

### Task 2: Knowledge/fact-check integration

**Files:**
- Modify: `docs/knowledge/README.md`
- Modify: `docs/knowledge/current-runtime-knowledge.md`
- Modify: `docs/knowledge/runtime-source-map.md`
- Modify: `docs/architecture/02-agent-framework.md`
- Modify: `scripts/check-runtime-doc-facts.ps1`

- [ ] **Step 1: Link the generated artifact**

Add the backend route inventory to knowledge entrypoints and source-map verification text. State clearly that it is source inventory, not endpoint smoke proof.

- [ ] **Step 2: Extend fact checker**

Make `check-runtime-doc-facts.ps1` discover the latest `backend-route-inventory-YYYY-MM-DD.md` and assert that the knowledge docs reference it.

- [ ] **Step 3: Verify**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1 -LiveSchema
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected: all commands pass.
