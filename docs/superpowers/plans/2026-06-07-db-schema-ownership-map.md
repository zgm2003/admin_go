# DB Schema Ownership Map Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Map every live MySQL table to current Go source model/reference ownership without guessing from migrations.

**Architecture:** Use the latest generated live schema artifact as the table truth source, scan current Go source for model/table references, and emit a Markdown ownership map under `docs/knowledge`.

**Tech Stack:** PowerShell, Markdown, current live MySQL schema artifact, current Go source tree.

---

**Source spec:** `docs/superpowers/specs/2026-06-07-db-schema-ownership-map-design.md`

### Task 1: Ownership map exporter

**Files:**
- Create: `scripts/export-db-schema-ownership-map.ps1`
- Create: `docs/knowledge/db-schema-ownership-map-2026-06-07.md`

- [ ] **Step 1: Add exporter script**

The script must:

```text
1. Discover latest docs/db/mysql-live-schema-YYYY-MM-DD.md and matching .sql.
2. Parse the live schema table inventory.
3. Scan non-test Go source under admin_back_go/internal/module, internal/shared, and internal/infra.
4. Exclude transport packages from table ownership inference.
5. Extract TableName() string model ownership.
6. Extract explicit .Table("...") calls.
7. Record exact table-name references without assigning fake ownership.
8. Write docs/knowledge/db-schema-ownership-map-YYYY-MM-DD.md.
```

- [ ] **Step 2: Generate artifact**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\export-db-schema-ownership-map.ps1 -OutputDate 2026-06-07
```

Expected output includes:

```text
live_tables=56
```

### Task 2: Knowledge docs integration

**Files:**
- Modify: `docs/knowledge/README.md`
- Modify: `docs/knowledge/current-runtime-knowledge.md`
- Modify: `docs/knowledge/runtime-source-map.md`
- Modify: `docs/architecture/02-agent-framework.md`
- Modify: `docs/status/current-status.md`

- [ ] **Step 1: Link the ownership map**

Add `docs/knowledge/db-schema-ownership-map-2026-06-07.md` to knowledge entrypoints and verification commands.

- [ ] **Step 2: Preserve truth boundary**

State that live MySQL schema remains the truth source; Go source only explains ownership/reference evidence.

### Task 3: Fact checker integration

**Files:**
- Modify: `scripts/check-runtime-doc-facts.ps1`

- [ ] **Step 1: Discover latest ownership map**

Add latest-file discovery for `db-schema-ownership-map-YYYY-MM-DD.md`.

- [ ] **Step 2: Assert required facts**

Check that the artifact:

```text
references latest live schema markdown and SQL artifacts
has Live tables reviewed = latest schema Base tables
contains users, permissions, ai_agents, canvas_prompts, payment_recharges
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
