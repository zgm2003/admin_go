# Admin Front Forgot Password Error Source Quality Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Remove forgot-password `catch any` and `error?.message || fallback` debt while preserving the existing dialog flow.

**Architecture:** Keep `useForgotPassword.ts` as the composable owner. Replace fallback-based catch blocks with an `unknown` error helper that fails closed on non-Error or empty Error messages. Add a Vitest guard and refresh the source-quality inventory.

**Tech Stack:** Vue 3 Composition API, TypeScript, Vitest, PowerShell generated docs.

---

### Task 1: RED guard

**Files:**
- Create: `admin_front_ts/tests/shared/user/forgot-password-source-quality.test.ts`

- [x] Add a source guard rejecting `catch (error: any)` and `error?.message ||` in `useForgotPassword.ts`.
- [x] Add behavior checks proving empty Error messages reject instead of displaying `sendFailed` / `resetFailed`.
- [x] Run `npm run test -- tests/shared/user/forgot-password-source-quality.test.ts` and confirm RED.

### Task 2: Fail-closed error helper

**Files:**
- Modify: `admin_front_ts/src/views/Login/composables/useForgotPassword.ts`

- [x] Add `requireRequestErrorMessage(error: unknown, operation: 'send code' | 'reset')`.
- [x] Change both catch blocks to `catch (error: unknown)`.
- [x] Display only `requireRequestErrorMessage(...)` in `ElMessage.error`.
- [x] Use `shallowRef` for touched primitive local state; keep `forgotForm` as `reactive`.
- [x] Run the targeted test and confirm GREEN.

### Task 3: Inventory/docs/fact sync

**Files:**
- Modify generated: `docs/knowledge/admin-front-source-quality-inventory-2026-06-07.md`
- Create: `docs/knowledge/admin-front-forgot-password-error-source-quality-review-2026-06-07.md`
- Modify: `docs/knowledge/README.md`
- Modify: `docs/knowledge/current-runtime-knowledge.md`
- Modify: `docs/knowledge/runtime-source-map.md`
- Modify: `docs/status/current-status.md`
- Modify: `docs/status/known-issues.md`
- Modify: `scripts/check-runtime-doc-facts.ps1`

- [x] Regenerate source-quality inventory.
- [x] Record `any candidates = 32`, `fallback candidates = 597`, and the remaining `useForgotPassword.ts` logical-or validation rows.
- [x] Add fact checker assertions for the review artifact and source guard.

### Task 4: Verification

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/user/forgot-password-source-quality.test.ts
npm run typecheck

cd E:\admin_go
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1 -LiveSchema
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```
