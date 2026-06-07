# Admin Front Download Demo Error Source Quality Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove catch-any and fallback error messages from the Admin download demo page.

**Architecture:** Keep the page single-file demo. Add a small local error-message guard and a Vitest source-quality guard.

**Tech Stack:** Vue 3 `<script setup lang="ts">`, TypeScript, Vitest, vue-tsc.

---

## Files

- Modify: `admin_front_ts/src/views/Main/component/download/index.vue`
- Create: `admin_front_ts/tests/shared/download-manager/download-demo-source-quality.test.ts`
- Refresh: `docs/knowledge/admin-front-source-quality-inventory-2026-06-07.md`
- Modify: `scripts/export-admin-front-source-quality-inventory.ps1`
- Modify: `scripts/check-runtime-doc-facts.ps1`
- Sync docs: `docs/knowledge/current-runtime-knowledge.md`, `docs/knowledge/runtime-source-map.md`, `docs/status/current-status.md`, `docs/status/known-issues.md`

## Steps

- [x] Write RED source guard rejecting `catch (error: any)` and `error.message || '下载失败'` in `src/views/Main/component/download/index.vue`.
- [x] Run targeted Vitest and confirm the guard fails on current source.
- [x] Add `requireDownloadDemoErrorMessage(error: unknown): string` and use it in simple/progress/batch download catches.
- [x] Replace optional filename `|| undefined` with explicit `optionalDownloadFilename()`.
- [x] Update the embedded best-practice code sample from `any`/fallback to `unknown`/required message.
- [x] Refresh Admin source-quality inventory and sync doc fact counts.
- [ ] Run targeted Vitest, `npm run typecheck`, runtime doc checks, `git diff --check`, and governance check.
