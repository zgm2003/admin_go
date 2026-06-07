# Admin Front Upload Demo Source Quality Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the upload demo `ref<any[]>` model with a shared typed media item contract.

**Architecture:** Keep the upload demo page and `UpMediaList` component intact. Add a small colocated `media.ts` type file so the parent page and child component share the same model shape.

**Tech Stack:** Vue 3 `<script setup lang="ts">`, TypeScript, Vitest, vue-tsc, PowerShell governance scripts.

---

## Files

- Modify: `admin_front_ts/src/views/Main/component/upload/index.vue`
- Modify: `admin_front_ts/src/views/Main/component/upload/components/UpMediaList.vue`
- Create: `admin_front_ts/src/views/Main/component/upload/components/media.ts`
- Create: `admin_front_ts/tests/shared/upload/upload-demo-source-quality.test.ts`
- Modify: `scripts/export-admin-front-source-quality-inventory.ps1`
- Modify: `scripts/check-runtime-doc-facts.ps1`
- Create: `docs/knowledge/admin-front-upload-demo-source-quality-review-2026-06-07.md`
- Refresh: `docs/knowledge/admin-front-source-quality-inventory-2026-06-07.md`
- Sync docs: `docs/knowledge/README.md`, `docs/knowledge/current-runtime-knowledge.md`, `docs/knowledge/runtime-source-map.md`, `docs/status/current-status.md`, `docs/status/known-issues.md`

## Steps

- [x] Write RED source guard rejecting `ref<any[]>` in upload demo and requiring a shared `UploadMediaItem` type.
- [x] Run targeted Vitest and confirm the guard fails on the old source.
- [x] Add `components/media.ts` with `UploadMediaItem`.
- [x] Type `imgList` as `ref<UploadMediaItem[]>([])`.
- [x] Make `UpMediaList.vue` use the shared type for props, emits, watcher input, and conversion output.
- [x] Refresh Admin Vue source-quality inventory and confirm counts are `280 files / 7 any / 562 fallback`.
- [x] Add review/spec/plan docs and sync runtime knowledge/status facts.
- [ ] Run targeted Vitest suite, `npm run typecheck`, runtime doc checks, `git diff --check`, and governance check.
