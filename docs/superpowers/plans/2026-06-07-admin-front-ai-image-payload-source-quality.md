# Admin Front AI Image Payload Source Quality Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace AI image create-task optional payload logical-or fallbacks with explicit normalization.

**Architecture:** Keep the Admin Vue API adapter as the owner of browser-to-Go payload normalization. Do not change page components, backend routes, or public payload types.

**Tech Stack:** TypeScript API adapter, Vitest source guard, vue-tsc, source-quality inventory.

---

## Files

- Modify: `admin_front_ts/src/api/ai/images.ts`
- Modify: `admin_front_ts/tests/shared/ai/ai-image-api.test.ts`
- Modify: `scripts/export-admin-front-source-quality-inventory.ps1`
- Refresh: `docs/knowledge/admin-front-source-quality-inventory-2026-06-07.md`
- Create: `docs/knowledge/admin-front-ai-image-payload-source-quality-review-2026-06-07.md`
- Create: `docs/superpowers/specs/2026-06-07-admin-front-ai-image-payload-source-quality-design.md`
- Create: `docs/superpowers/plans/2026-06-07-admin-front-ai-image-payload-source-quality.md`
- Sync: current runtime knowledge, runtime source map, status, known issues, quality runway, runtime fact checker

## Steps

- [x] Add RED source guard rejecting `payload.* || undefined` and truthy mask ID checks in `images.ts`.
- [x] Confirm RED with `npm run test -- tests/shared/ai/ai-image-api.test.ts`.
- [x] Add `optionalImageEnum(...)` and `optionalPositiveID(...)`.
- [x] Update `normalizeTaskPayload(...)` to use explicit normalization.
- [x] Confirm GREEN with targeted Vitest and `npm run typecheck`.
- [x] Refresh Admin Vue source-quality inventory and confirm fallback count is `555`.
- [x] Sync docs/checker and run root gates.
