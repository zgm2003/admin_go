# Agent Framework Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish the project-level agent framework before creating the Go backend.

**Architecture:** `Superpowers` defines the development process. `E:\admin_go\agents` defines project-specific agent responsibilities, forbidden actions, required documents, and output evidence. The framework forces open-source-first architecture decisions and step-by-step delivery.

**Tech Stack:** Markdown project governance only. No Go code, no frontend code, no dependency installation in Phase 0.

---

### Task 1: Create root guidance

**Files:**
- Create: `AGENTS.md`

- [x] Define open-source-first project identity.
- [x] Define phase order.
- [x] Define legacy reference boundaries.
- [x] Define required document reading order.

### Task 2: Create architecture rules

**Files:**
- Create: `docs/architecture/00-open-source-first.md`
- Create: `docs/architecture/01-step-by-step-roadmap.md`
- Create: `docs/architecture/02-agent-framework.md`

- [x] Document that architecture must be researched before implemented.
- [x] Document Phase 0 through Phase 6.
- [x] Document Superpowers vs project agents separation.

### Task 3: Create agent role files

**Files:**
- Create: `agents/architect.md`
- Create: `agents/api-contract.md`
- Create: `agents/backend-worker.md`
- Create: `agents/frontend-adapter.md`
- Create: `agents/reviewer.md`

- [x] Define responsibility.
- [x] Define required reading.
- [x] Define allowed actions.
- [x] Define forbidden actions.
- [x] Define output evidence.

### Task 4: Verify Phase 0

**Files:**
- Read all created files.

- [x] Confirm files exist.
- [x] Confirm no Go code was initialized.
- [x] Confirm no frontend code was modified.
- [x] Confirm next phase is open-source research, not implementation.
