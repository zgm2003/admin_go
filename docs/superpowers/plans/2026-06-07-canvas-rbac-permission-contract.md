# Canvas RBAC Permission Contract Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:test-driven-development for code behavior changes and superpowers:verification-before-completion before reporting completion. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close `CANVAS-DOC-001` by proving `canvas_ai_text_generate` is dead frontend RBAC type drift and guarding the active Canvas BUTTON contract.

**Architecture:** Keep Canvas text runtime controlled by `canvas_text_generate` agent scenes, not by a separate frontend BUTTON code. Preserve existing Canvas chat/text route behavior and remove only the stale permission type from the canonical Canvas Next RBAC registry.

**Tech Stack:** Next.js/React/TypeScript/Vitest, Go migration/route metadata source review, live MySQL `permissions` query, Markdown knowledge/status/contracts, PowerShell fact checker.

---

### Task 1: Root-cause evidence

- [ ] Read `docs/status/known-issues.md` `CANVAS-DOC-001`.
- [ ] Search `canvas_front_next/src` for `canvas_ai_text_generate`.
- [ ] Search Go migrations and route metadata for `canvas_ai_text_generate`.
- [ ] Query live MySQL `permissions` for Canvas generation BUTTON rows.
- [ ] Decide one outcome: active BUTTON code or dead frontend type drift.

Expected decision for this slice:

```text
canvas_ai_text_generate is dead frontend type drift.
Live MySQL row, if present, is a soft-deleted orphan.
```

### Task 2: Red guard

- [ ] Modify `canvas_front_next/tests/shared/canvas-rbac-shell.test.ts` to reject `canvas_ai_text_generate`.
- [ ] Run:

```powershell
cd E:\admin_go\canvas_front_next
npm run test -- tests/shared/canvas-rbac-shell.test.ts
```

Expected before implementation:

```text
FAIL because src/features/rbac/canvas-permissions.ts still contains canvas_ai_text_generate
```

### Task 3: Minimal frontend fix

- [ ] Remove only `canvas_ai_text_generate` from `canvas_front_next/src/features/rbac/canvas-permissions.ts`.
- [ ] Do not add `can("canvas_ai_text_generate")`.
- [ ] Do not change generation URLs or request bodies.
- [ ] Re-run:

```powershell
cd E:\admin_go\canvas_front_next
npm run test -- tests/shared/canvas-rbac-shell.test.ts
npm run typecheck
```

Expected:

```text
RBAC shell test passes.
TypeScript typecheck passes.
```

### Task 4: Knowledge and status sync

- [ ] Add `docs/knowledge/canvas-rbac-permission-contract-review-2026-06-07.md`.
- [ ] Update `docs/knowledge/README.md`.
- [ ] Update `docs/knowledge/current-runtime-knowledge.md`.
- [ ] Update `docs/knowledge/runtime-source-map.md`.
- [ ] Move `CANVAS-DOC-001` from open to resolved in `docs/status/known-issues.md`.
- [ ] Update `docs/status/current-status.md` latest status pointer.

### Task 5: Fact guard and verification

- [ ] Extend `scripts/check-runtime-doc-facts.ps1` to guard:
  - review artifact is indexed;
  - frontend source does not reintroduce `canvas_ai_text_generate`;
  - contract active BUTTON row list excludes `canvas_ai_text_generate`;
  - `-LiveSchema` verifies `canvas_ai_text_generate` is absent or a soft-deleted orphan.
- [ ] Run:

```powershell
cd E:\admin_go
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1 -LiveSchema
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```
