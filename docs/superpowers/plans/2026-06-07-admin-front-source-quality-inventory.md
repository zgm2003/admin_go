# Admin Front Source Quality Inventory Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate and guard an Admin Vue source-quality inventory for current `any/as any/fallback` debt.

**Architecture:** A PowerShell exporter scans current `admin_front_ts/src` source files and emits a Markdown artifact. `check-runtime-doc-facts.ps1` discovers the latest artifact and verifies key counts/references so docs cannot drift.

**Tech Stack:** PowerShell, Markdown artifacts, Vitest only for existing frontend guard checks, root runtime fact checker.

---

### Task 1: Add missing-artifact guard first

**Files:**
- Modify: `scripts/check-runtime-doc-facts.ps1`

- [ ] Add latest `admin-front-source-quality-inventory-YYYY-MM-DD.md` discovery.
- [ ] Require docs to reference the artifact.
- [ ] Verify summary counts and priority files once the artifact exists.
- [ ] Run `powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1` and expect failure before the artifact is generated.

### Task 2: Implement exporter

**Files:**
- Create: `scripts/export-admin-front-source-quality-inventory.ps1`

- [ ] Enumerate `admin_front_ts/src/**/*.ts` and `*.vue`.
- [ ] Exclude `.d.ts`.
- [ ] Strip comments before scanning.
- [ ] Detect `any`, `as any`, `Record<string, any>`, `catch(error: any)`, `||`, `??`, and `?.` combined with fallback.
- [ ] Emit summary, top files, priority evidence, and full findings.

### Task 3: Generate artifact

**Files:**
- Create: `docs/knowledge/admin-front-source-quality-inventory-2026-06-07.md`

- [ ] Run `powershell -ExecutionPolicy Bypass -File .\scripts\export-admin-front-source-quality-inventory.ps1 -OutputDate 2026-06-07`.
- [ ] Confirm the artifact contains priority files and current counts.

### Task 4: Sync docs

**Files:**
- Modify: `docs/knowledge/README.md`
- Modify: `docs/knowledge/current-runtime-knowledge.md`
- Modify: `docs/knowledge/runtime-source-map.md`
- Modify: `docs/architecture/02-agent-framework.md`
- Modify: `docs/status/current-status.md`
- Modify: `docs/status/known-issues.md`

- [ ] Add artifact entry and refresh command.
- [ ] State that this is inventory, not proof all debt is fixed.
- [ ] Keep `ADMIN-FRONT-HARDENING-002` and `003` open.

### Task 5: Verify

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\export-admin-front-source-quality-inventory.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1 -LiveSchema
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```
