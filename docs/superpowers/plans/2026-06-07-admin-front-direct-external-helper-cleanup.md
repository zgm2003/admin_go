# Admin Front Direct External Helper Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close `ADMIN-FRONT-HARDENING-003` by deleting the unused direct external random-image helper and guarding against reintroduction.

**Architecture:** Treat the helper as dead source, not an API contract. Add a Vitest source guard, delete the module, regenerate source inventories, and update knowledge/status/fact checks.

**Tech Stack:** Vue 3 source tree, Vitest, PowerShell generated inventories, Markdown knowledge docs.

---

### Task 1: Prove active usage and write RED guard

**Files:**
- Create: `admin_front_ts/tests/shared/api/no-direct-external-helper.test.ts`

- [ ] Search `admin_front_ts/src` and `admin_front_ts/tests` for `getRondomImage`, `getRandomImage`, `btstu`, `sjbz`, and `api/tools`.
- [ ] Add a Vitest guard that expects `src/api/tools.ts` to be absent and rejects `api.btstu.cn` in Admin Vue source.
- [ ] Run `npm run test -- tests/shared/api/no-direct-external-helper.test.ts` and confirm RED while `src/api/tools.ts` still exists.

### Task 2: Delete dead helper and verify GREEN

**Files:**
- Delete: `admin_front_ts/src/api/tools.ts`

- [ ] Delete `src/api/tools.ts`.
- [ ] Run `npm run test -- tests/shared/api/no-direct-external-helper.test.ts` and confirm the guard passes.

### Task 3: Regenerate inventories and sync docs

**Files:**
- Modify generated: `docs/knowledge/admin-front-source-quality-inventory-2026-06-07.md`
- Modify generated: `docs/knowledge/frontend-api-inventory-2026-06-07.md`
- Modify generated: `docs/knowledge/frontend-backend-api-drift-2026-06-07.md`
- Modify generated: `docs/knowledge/api-source-only-route-review-2026-06-07.md`
- Modify generated: `docs/knowledge/full-stack-module-map-2026-06-07.md`
- Create: `docs/knowledge/admin-front-direct-external-helper-review-2026-06-07.md`
- Modify: `docs/status/current-status.md`
- Modify: `docs/status/known-issues.md`
- Modify: `docs/knowledge/current-runtime-knowledge.md`
- Modify: `docs/knowledge/runtime-source-map.md`
- Modify: `scripts/check-runtime-doc-facts.ps1`

- [ ] Run source-quality and API inventory exporters.
- [ ] Update docs to record `direct external HTTP candidates = 0`, `frontend API calls = 274`, and `external HTTP calls = 3`.
- [ ] Update fact guard to reject the retired host/path and require the new source guard.

### Task 4: Verification

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/api/no-direct-external-helper.test.ts
npm run typecheck

cd E:\admin_go
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1 -LiveSchema
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```
