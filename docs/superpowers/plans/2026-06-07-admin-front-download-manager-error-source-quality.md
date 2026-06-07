# Admin Front DownloadManager Error Source Quality Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove DownloadManager `catch-any` and Web fetch silent direct-open fallback.

**Architecture:** Keep the existing download manager API. Add one focused pure helper module for `unknown` error narrowing, then wire Tauri/Web catch blocks through it.

**Tech Stack:** Vue 3.5, TypeScript, Vitest source/utility guard, vue-tsc.

---

## Files

- Create: `admin_front_ts/src/components/DownloadManager/src/errors.ts`
- Modify: `admin_front_ts/src/components/DownloadManager/src/download.ts`
- Create: `admin_front_ts/tests/shared/download-manager/download-manager-source-quality.test.ts`
- Create: `docs/knowledge/admin-front-download-manager-source-quality-review-2026-06-07.md`
- Modify: `docs/knowledge/README.md`
- Modify: `docs/knowledge/current-runtime-knowledge.md`
- Modify: `docs/knowledge/runtime-source-map.md`
- Modify: `docs/status/current-status.md`
- Modify: `docs/status/known-issues.md`
- Modify: `scripts/export-admin-front-source-quality-inventory.ps1`
- Modify: `scripts/check-runtime-doc-facts.ps1`
- Refresh: `docs/knowledge/admin-front-source-quality-inventory-2026-06-07.md`

## Component map

- `download.ts`: keeps download orchestration and browser/Tauri side effects.
- `errors.ts`: owns error classification only; no DOM, no Tauri, no i18n import.
- Source guard test: locks the no-`any`/no-silent-fallback boundary.

### Task 1: RED source-quality guard

- [ ] Create `tests/shared/download-manager/download-manager-source-quality.test.ts` asserting `download.ts` has no `catch (...: any)`, imports the helpers, and does not call `window.open(url, '_blank')` in the Web fetch catch path.
- [ ] Run `npm run test -- tests/shared/download-manager/download-manager-source-quality.test.ts`; expected RED on current `catch any`/missing helper.

### Task 2: GREEN helper and wiring

- [ ] Add `errors.ts` with `isDownloadUserCancelled()` and `requireDownloadError()`.
- [ ] Change both `downloadFile` catch blocks to `catch (error: unknown)`.
- [ ] Keep user-cancel return only for the explicit user-cancelled error.
- [ ] Remove Web fetch catch `window.open(url, '_blank')`; log and throw the narrowed error.
- [ ] Run targeted test and `npm run typecheck`; expected PASS.

### Task 3: Inventory and docs

- [ ] Refresh source-quality inventory.
- [ ] Add review doc with exact scope and counts.
- [ ] Sync knowledge/status/runtime-source-map/fact-checker references.

### Task 4: Final gates

- [ ] Run targeted Vitest and typecheck.
- [ ] Run runtime-doc fact checks, including `-LiveSchema`.
- [ ] Run `git diff --check` and root governance.
