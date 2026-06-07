# Admin Front Dev Test Download Error Source Quality Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the remaining dev test page download catch-any and implicit fallback error handling.

**Architecture:** Keep the route-level dev test SFC as the composition surface. Add local typed helpers for error-message and optional filename rules, then lock the source shape with Vitest and runtime-doc fact checks.

**Tech Stack:** Vue 3 `<script setup lang="ts">`, TypeScript, Vitest, vue-tsc, PowerShell governance scripts.

---

## Files

- Modify: `admin_front_ts/src/views/Main/test/index.vue`
- Create: `admin_front_ts/tests/shared/download-manager/dev-test-download-source-quality.test.ts`
- Modify: `scripts/export-admin-front-source-quality-inventory.ps1`
- Modify: `scripts/check-runtime-doc-facts.ps1`
- Create: `docs/knowledge/admin-front-dev-test-download-source-quality-review-2026-06-07.md`
- Refresh: `docs/knowledge/admin-front-source-quality-inventory-2026-06-07.md`
- Sync docs: `docs/knowledge/README.md`, `docs/knowledge/current-runtime-knowledge.md`, `docs/knowledge/runtime-source-map.md`, `docs/status/current-status.md`, `docs/status/known-issues.md`

## Steps

- [x] Write RED source guard rejecting `catch (error: any)`, `error.message || t('devTest.downloadFailed'...)`, and `testFilename.value || undefined` in `src/views/Main/test/index.vue`.
- [x] Run targeted Vitest and confirm the guard fails on the old source.
- [x] Add `requireDevTestDownloadErrorMessage(error: unknown): string` to reject non-Error and empty-message failures.
- [x] Add `optionalDownloadFilename(filename: string): string | undefined` to make the optional filename rule explicit.
- [x] Use both helpers in progress and batch download flows; batch errors now show the real message and stop.
- [x] Add the dev test page to source-quality priority evidence and refresh the inventory.
- [x] Add review/spec/plan docs and sync runtime knowledge/status facts.
- [ ] Run targeted Vitest suite, `npm run typecheck`, runtime doc checks, `git diff --check`, and governance check.
