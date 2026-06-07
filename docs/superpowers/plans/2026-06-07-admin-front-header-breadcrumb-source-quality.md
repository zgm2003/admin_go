# Admin Front Header Breadcrumb Source Quality Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove Header breadcrumb route-walk `any` and logical-or fallback debt while preserving current layout behavior.

**Architecture:** Keep `Header/index.vue` as the existing layout composition surface. Use `PermissionMenuItem` for breadcrumb nodes and explicit `null` handling for route lookup misses. Add a Vitest source guard and refresh the Admin Vue source-quality inventory.

**Tech Stack:** Vue 3 `<script setup lang="ts">`, Pinia source types, Vitest source guard, PowerShell generated docs.

---

### Task 1: RED guard

**Files:**
- Create: `admin_front_ts/tests/layout/header-source-quality.test.ts`

- [ ] Add a guard that rejects `any` / `as any` in `src/views/Layout/components/Header/index.vue`.
- [ ] Add a guard that rejects `return getPath(userStore.permissions, selectedIndex) || []` and `if (!selectedIndex || selectedIndex === ...)`.
- [ ] Run `npm run test -- tests/layout/header-source-quality.test.ts` and confirm RED against the old Header code.

### Task 2: Typed breadcrumb route walk

**Files:**
- Modify: `admin_front_ts/src/views/Layout/components/Header/index.vue`

- [ ] Import `PermissionMenuItem` from `@/types/user`.
- [ ] Replace local primitive `ref` calls with `shallowRef`.
- [ ] Add `findBreadcrumbPath(items: PermissionMenuItem[], target: string): PermissionMenuItem[] | null`.
- [ ] Return matched paths only after `matchedPath !== null`; otherwise return `[]` explicitly.
- [ ] Type `getBreadcrumbLabel(item: PermissionMenuItem)`.
- [ ] Run `npm run test -- tests/layout/header-source-quality.test.ts` and confirm GREEN.

### Task 3: Inventory/docs/fact sync

**Files:**
- Modify generated: `docs/knowledge/admin-front-source-quality-inventory-2026-06-07.md`
- Create: `docs/knowledge/admin-front-header-breadcrumb-source-quality-review-2026-06-07.md`
- Modify: `docs/knowledge/README.md`
- Modify: `docs/knowledge/current-runtime-knowledge.md`
- Modify: `docs/knowledge/runtime-source-map.md`
- Modify: `docs/status/current-status.md`
- Modify: `scripts/check-runtime-doc-facts.ps1`

- [ ] Run `powershell -ExecutionPolicy Bypass -File .\scripts\export-admin-front-source-quality-inventory.ps1 -OutputDate 2026-06-07`.
- [ ] Record that `Header/index.vue` has no configured source-quality finding, while remaining debt still exists.
- [ ] Add fact checker assertions for the review artifact and Header guard.

### Task 4: Verification

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/layout/header-source-quality.test.ts
npm run typecheck

cd E:\admin_go
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1 -LiveSchema
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```
