# Admin Front useValidator Source Quality Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove `useValidator.ts` validator input `any` and implicit `message || fallback` handling without changing the composable API.

**Architecture:** Keep `useValidator` as the existing composable boundary. Add narrow local types and a message resolver, then lock the source shape with Vitest and runtime-doc fact checks.

**Tech Stack:** Vue 3 Composition API composable, TypeScript, Vitest, vue-tsc, PowerShell governance scripts.

---

## Files

- Modify: `admin_front_ts/src/hooks/web/useValidator.ts`
- Create: `admin_front_ts/tests/shared/validator/use-validator-source-quality.test.ts`
- Modify: `scripts/export-admin-front-source-quality-inventory.ps1`
- Modify: `scripts/check-runtime-doc-facts.ps1`
- Create: `docs/knowledge/admin-front-validator-source-quality-review-2026-06-07.md`
- Refresh: `docs/knowledge/admin-front-source-quality-inventory-2026-06-07.md`
- Sync docs: `docs/knowledge/README.md`, `docs/knowledge/current-runtime-knowledge.md`, `docs/knowledge/runtime-source-map.md`, `docs/status/current-status.md`, `docs/status/known-issues.md`

## Steps

- [x] Write RED source guard rejecting `val: any` and `message ||` in `src/hooks/web/useValidator.ts`.
- [x] Run targeted Vitest and confirm the guard fails on the old source.
- [x] Add `ValidatorValue = string` and `LengthRange` to make validator inputs explicit.
- [x] Add `resolveValidatorMessage(message, fallback)` so only `undefined` uses the fallback text.
- [x] Replace validator `val: any` parameters and `message || t(...)` calls.
- [x] Refresh Admin Vue source-quality inventory and confirm counts are `7 any / 562 fallback`.
- [x] Add review/spec/plan docs and sync runtime knowledge/status facts.
- [ ] Run targeted Vitest suite, `npm run typecheck`, runtime doc checks, `git diff --check`, and governance check.
