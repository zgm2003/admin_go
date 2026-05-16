# Documentation Location Governance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make root docs the canonical home for cross-repo deployment/governance docs while keeping backend runtime architecture close to backend code.

**Architecture:** Use root docs as the index and ownership layer. Move the frontend deployment runbook into root `docs/deployment`, leave a short frontend stub, and make the governance checker block future non-stub frontend deployment docs when it can see the path.

**Tech Stack:** Markdown, PowerShell, Git worktrees.

---

## File Structure

- Create: `docs/superpowers/specs/2026-05-16-documentation-location-governance-design.md` — design record for this slice.
- Create: `docs/deployment/frontend-github-actions-scp.md` — canonical frontend deployment runbook.
- Modify: `docs/README.md` — cold-start map points to the canonical deployment doc and subrepo stub rule.
- Modify: `docs/architecture/07-documentation-governance.md` — add documentation location ownership rules.
- Modify: `scripts/check-agent-governance.ps1` — block non-stub frontend deployment docs.
- Create/Modify in frontend repo: `admin_front_ts/docs/deployment/github-actions-scp.md` — stub pointing to root canonical doc.

### Task 1: Write governance spec and plan

**Files:**
- Create: `docs/superpowers/specs/2026-05-16-documentation-location-governance-design.md`
- Create: `docs/superpowers/plans/2026-05-16-documentation-location-governance.md`

- [ ] **Step 1: Create the spec**

Write the design rules exactly as root-first, not root-only. Explicitly keep `admin_back_go/docs/architecture.md` in the backend repo.

- [ ] **Step 2: Create this plan**

Write this plan with concrete file paths and validation commands.

### Task 2: Move frontend deployment truth to root

**Files:**
- Create: `docs/deployment/frontend-github-actions-scp.md`
- Modify: `docs/README.md`
- Modify in frontend repo: `admin_front_ts/docs/deployment/github-actions-scp.md`

- [ ] **Step 1: Copy the existing frontend deployment runbook into root**

Use the current content from `admin_front_ts/docs/deployment/github-actions-scp.md` and make `docs/deployment/frontend-github-actions-scp.md` the canonical location.

- [ ] **Step 2: Replace the frontend file with a stub**

The stub must contain:

```markdown
# Moved

Canonical doc:
`E:/admin_go/docs/deployment/frontend-github-actions-scp.md`

This frontend repo keeps only this pointer so old links do not break. Deployment truth belongs to the root admin_go docs.
```

- [ ] **Step 3: Update root docs index**

Add `docs/deployment/frontend-github-actions-scp.md` to the cold-start/deployment section and document that frontend deployment docs live in root.

### Task 3: Document location ownership

**Files:**
- Modify: `docs/architecture/07-documentation-governance.md`

- [ ] **Step 1: Add a documentation location section**

State the canonical root docs, allowed subrepo docs, and disallowed child repo active docs.

- [ ] **Step 2: Preserve the backend exception**

Say explicitly that `admin_back_go/docs/architecture.md` remains valid because it is backend runtime architecture.

### Task 4: Enforce the frontend deployment doc rule

**Files:**
- Modify: `scripts/check-agent-governance.ps1`

- [ ] **Step 1: Add a stub detector**

A valid moved stub under `admin_front_ts/docs/deployment/*.md` contains both `Canonical doc:` and `docs/deployment/`.

- [ ] **Step 2: Add the blocking rule**

If a changed path matches `admin_front_ts/docs/deployment/*.md` and the file is not a moved stub, block with a clear message.

- [ ] **Step 3: Keep the checker lightweight**

Do not add DB, Redis, backend, frontend build, or smoke calls.

### Task 5: Verify and commit

**Files:**
- Root repo changed files from Tasks 1-4.
- Frontend repo stub from Task 2.

- [ ] **Step 1: Root validation**

Run:

```powershell
git diff --check -- . ':(exclude)**/node_modules/**'
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode range -Base master -Strict
```

Expected: all exit 0.

- [ ] **Step 2: Frontend validation**

Run in the frontend worktree:

```powershell
git diff --check -- . ':(exclude)**/node_modules/**'
```

Expected: exit 0.

- [ ] **Step 3: Commit root changes**

```powershell
git add docs/README.md docs/architecture/07-documentation-governance.md docs/deployment/frontend-github-actions-scp.md docs/superpowers/specs/2026-05-16-documentation-location-governance-design.md docs/superpowers/plans/2026-05-16-documentation-location-governance.md scripts/check-agent-governance.ps1
git commit -m "docs: centralize documentation location governance"
```

- [ ] **Step 4: Commit frontend stub**

```powershell
git add docs/deployment/github-actions-scp.md
git commit -m "docs: point frontend deployment runbook to root docs"
```
