# Admin Front DownloadManager Filename Source Quality Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace DownloadManager filename logical-or fallbacks with explicit filename derivation helpers.

**Architecture:** Keep `download.ts` as the DownloadManager implementation file. Add small pure helpers near the Tauri imports, then use them in Tauri default path, Tauri savePath filename, and Web blob filename derivation.

**Tech Stack:** Vue 3 Admin frontend, TypeScript, Vitest source guard, vue-tsc, PowerShell runtime-doc governance.

---

## Files

- Modify: `admin_front_ts/src/components/DownloadManager/src/download.ts`
- Modify: `admin_front_ts/tests/shared/download-manager/download-manager-source-quality.test.ts`
- Refresh: `docs/knowledge/admin-front-source-quality-inventory-2026-06-07.md`
- Modify: `docs/knowledge/admin-front-download-manager-source-quality-review-2026-06-07.md`
- Sync: `docs/knowledge/current-runtime-knowledge.md`, `docs/knowledge/runtime-source-map.md`, `docs/status/current-status.md`, `docs/status/known-issues.md`
- Modify: `scripts/check-runtime-doc-facts.ps1`

## Steps

- [x] Write RED guard in `download-manager-source-quality.test.ts` rejecting the existing filename `||` expressions.
- [x] Run targeted Vitest and confirm the guard fails on missing explicit helpers.
- [x] Add `DEFAULT_DOWNLOAD_FILENAME`, `filenameFromURL`, `resolveSuggestedDownloadFilename`, and `resolveSavePathFilename`.
- [x] Replace Tauri suggested filename, savePath filename, and Web `link.download` derivation with those helpers.
- [x] Run targeted Vitest and confirm the guard passes.
- [x] Refresh Admin source-quality inventory.
- [ ] Sync documentation/fact-checker counts to fallback candidates = 562 and DownloadManager priority evidence = no configured finding.
- [ ] Run targeted Vitest suite, `npm run typecheck`, runtime doc facts, `git diff --check`, and governance check.
