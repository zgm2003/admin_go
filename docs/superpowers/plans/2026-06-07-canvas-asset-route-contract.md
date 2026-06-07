# Canvas Asset Route Contract Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:test-driven-development for code behavior changes and superpowers:verification-before-completion before reporting completion. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close `CANVAS-DOC-002` by proving `/asset-library` is a dead Canvas Next page and keeping `/assets` as the only top-level Canvas asset route.

**Architecture:** Route access stays backend-router driven. The frontend registry provides labels/icons for canonical backend paths only; no route aliases or permission fallback logic are introduced. The backend public asset API remains `/api/canvas/v1/assets` and is used by the in-canvas asset picker.

**Tech Stack:** Next.js/React/TypeScript/Vitest, Go seed/live MySQL evidence, Markdown knowledge/status/contracts, PowerShell fact checker.

---

### Task 1: Root-cause evidence

- [ ] Read `docs/status/known-issues.md` `CANVAS-DOC-002`.
- [ ] Search Canvas Next source for `/asset-library` and `/assets`.
- [ ] Query live MySQL Canvas permission rows for `/assets`, `/asset-library`, and asset codes.
- [ ] Confirm `canvas_front_next/src/features/rbac/canvas-permissions.ts` contains `/assets` and no `/asset-library`.
- [ ] Decide one outcome.

Expected decision:

```text
/asset-library is a dead page.
/assets is the canonical top-level Canvas asset page route.
```

### Task 2: Red guard

- [ ] Modify `canvas_front_next/tests/shared/canvas-rbac-shell.test.ts` to require that `src/app/(user)/asset-library/page.tsx` does not exist and that source registry text does not contain `/asset-library`.
- [ ] Move the protected asset API caller assertion from the deleted page to `src/app/(user)/canvas/components/asset-picker-modal.tsx`.
- [ ] Run:

```powershell
cd E:\admin_go\canvas_front_next
npm run test -- tests/shared/canvas-rbac-shell.test.ts
```

Expected before implementation:

```text
FAIL because src/app/(user)/asset-library/page.tsx still exists.
```

### Task 3: Minimal frontend fix

- [ ] Delete `canvas_front_next/src/app/(user)/asset-library/page.tsx`.
- [ ] Do not add `redirect()`, alias routes, or extra `hasCanvasRoute()` fallback logic.
- [ ] Do not change `canvas_front_next/src/app/(user)/assets/page.tsx`.
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

### Task 4: Knowledge, inventory, and status sync

- [ ] Add `docs/knowledge/canvas-asset-route-contract-review-2026-06-07.md`.
- [ ] Update `docs/knowledge/README.md`.
- [ ] Update `docs/knowledge/current-runtime-knowledge.md`.
- [ ] Update `docs/knowledge/runtime-source-map.md`.
- [ ] Regenerate affected generated inventories:

```powershell
cd E:\admin_go
powershell -ExecutionPolicy Bypass -File .\scripts\export-runtime-inventory.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\export-frontend-api-inventory.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\export-frontend-backend-api-drift.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\export-full-stack-module-map.ps1 -OutputDate 2026-06-07
```

- [ ] Move `CANVAS-DOC-002` from open to resolved in `docs/status/known-issues.md`.
- [ ] Update `docs/status/current-status.md` latest status pointer.

### Task 5: Fact guard and verification

- [ ] Extend `scripts/check-runtime-doc-facts.ps1` to guard:
  - review artifact is indexed;
  - Canvas route registry contains `/assets` and not `/asset-library`;
  - `src/app/(user)/asset-library/page.tsx` is absent;
  - source docs/inventory no longer list `(user)/asset-library`;
  - `-LiveSchema` verifies active `/assets` and no active `/asset-library` Canvas PAGE.
- [ ] Run:

```powershell
cd E:\admin_go
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1 -LiveSchema
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```
