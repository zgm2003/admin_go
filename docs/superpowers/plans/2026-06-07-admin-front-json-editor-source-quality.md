# Admin Front JsonEditor Source Quality Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove JsonEditor `catch any`, optional-chain error fallback, implicit empty JSON fallback, and touched visible-Chinese debt without changing its public component contract.

**Architecture:** Keep `JsonEditor.vue` as the UI owner and add a small pure `json.ts` helper for parse/format/error-message rules. Use TDD source/utility guards before production code, then refresh generated source-quality docs and fact checks.

**Tech Stack:** Vue 3 Composition API, TypeScript, vue-i18n, Element Plus, Vitest, PowerShell generated docs.

---

### Task 1: RED guard

**Files:**
- Create: `admin_front_ts/tests/shared/json-editor/json-editor-source-quality.test.ts`
- Modify: `admin_front_ts/tests/shared/i18n/no-visible-chinese.test.ts`

- [x] **Step 1: Add JsonEditor source/utility guard**

Create `admin_front_ts/tests/shared/json-editor/json-editor-source-quality.test.ts` with checks that reject `catch (e: any)`, reject `e?.message ||`, reject `modelValue.value || '{}'`, require `catch (error: unknown)`, require `parseJsonEditorValue(modelValue.value)`, require `requireJsonParseErrorMessage(error)`, require `jsonEditor.*` i18n keys, and verify the planned helper rejects non-Error/empty-message failures.

- [x] **Step 2: Add visible-Chinese guard coverage**

Add `src/components/JsonEditor/src/index.vue` to the `guardedFiles` list in `admin_front_ts/tests/shared/i18n/no-visible-chinese.test.ts`.

- [x] **Step 3: Run RED**

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/json-editor/json-editor-source-quality.test.ts tests/shared/i18n/no-visible-chinese.test.ts
```

Expected: FAIL because JsonEditor still has `catch any`, fallback messages, raw Chinese, and no helper module.

### Task 2: GREEN implementation

**Files:**
- Create: `admin_front_ts/src/components/JsonEditor/src/json.ts`
- Modify: `admin_front_ts/src/components/JsonEditor/src/index.vue`
- Modify: `admin_front_ts/src/i18n/locales/zh-CN.ts`
- Modify: `admin_front_ts/src/i18n/locales/en-US.ts`

- [x] **Step 1: Add pure JSON helper**

Create `json.ts` with:

```ts
const EMPTY_JSON_OBJECT_SOURCE = '{}'

export function jsonEditorParseSource(value: string): string {
  if (value.trim().length === 0) return EMPTY_JSON_OBJECT_SOURCE
  return value
}

export function parseJsonEditorValue(value: string): unknown {
  return JSON.parse(jsonEditorParseSource(value))
}

export function formatJsonEditorValue(value: string): string {
  return JSON.stringify(parseJsonEditorValue(value), null, 2)
}

export function requireJsonParseErrorMessage(error: unknown): string {
  if (!(error instanceof Error)) {
    throw new Error('json editor parse failed with non-Error reason')
  }

  const message = error.message.trim()
  if (message.length === 0) {
    throw new Error('json editor parse error message must be non-empty')
  }

  return message
}
```

- [x] **Step 2: Update component**

Use the helper in `index.vue`, replace both parse catches with `catch (error: unknown)`, format valid JSON via `formatJsonEditorValue`, call `t('jsonEditor.invalidJson', { message })`, call `t('jsonEditor.formatted')`, and render buttons with `t('jsonEditor.format')` / `t('jsonEditor.validate')`. Keep the exposed `validate()` method.

- [x] **Step 3: Add i18n keys**

Add `jsonEditor` keys to both locale files:

```ts
jsonEditor: {
  invalidJson: 'JSON 格式错误：{message}',
  formatted: '已格式化 JSON',
  format: '格式化',
  validate: '校验'
}
```

```ts
jsonEditor: {
  invalidJson: 'Invalid JSON: {message}',
  formatted: 'JSON formatted',
  format: 'Format',
  validate: 'Validate'
}
```

- [x] **Step 4: Run GREEN**

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/json-editor/json-editor-source-quality.test.ts tests/shared/i18n/no-visible-chinese.test.ts
```

Expected: PASS.

### Task 3: Inventory/docs/fact sync

**Files:**
- Modify generated: `docs/knowledge/admin-front-source-quality-inventory-2026-06-07.md`
- Create: `docs/knowledge/admin-front-json-editor-source-quality-review-2026-06-07.md`
- Modify: `docs/knowledge/README.md`
- Modify: `docs/knowledge/current-runtime-knowledge.md`
- Modify: `docs/knowledge/runtime-source-map.md`
- Modify: `docs/status/current-status.md`
- Modify: `docs/status/known-issues.md`
- Modify: `scripts/check-runtime-doc-facts.ps1`

- [x] Regenerate Admin front source-quality inventory.
- [x] Record new `any`, `catch-any`, and `fallback` counts.
- [x] Add fact checker assertions for JsonEditor source, tests, review artifact, docs references, and resolved known-issue status.

### Task 4: Final verification

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/json-editor/json-editor-source-quality.test.ts tests/shared/i18n/no-visible-chinese.test.ts
npm run typecheck

cd E:\admin_go
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1 -LiveSchema
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```
