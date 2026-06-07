# Admin Front Editor Source Quality Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove wangEditor wrapper `any/as any` and upload URL fallback debt from Admin Vue `Editor.vue`.

**Architecture:** Keep the existing single Vue wrapper and public API unchanged. Replace untyped third-party seams with local narrow TypeScript contracts and fail closed when upload returns an empty URL.

**Tech Stack:** Vue 3.5, `<script setup lang="ts">`, wangEditor, Vitest source guard, vue-tsc.

---

## Files

- Modify: `admin_front_ts/src/views/Main/component/display/components/Editor.vue`
- Create: `admin_front_ts/tests/shared/editor/editor-source-quality.test.ts`
- Create: `docs/knowledge/admin-front-editor-source-quality-review-2026-06-07.md`
- Modify: `docs/knowledge/README.md`
- Modify: `docs/knowledge/current-runtime-knowledge.md`
- Modify: `docs/knowledge/runtime-source-map.md`
- Modify: `docs/status/current-status.md`
- Modify: `docs/status/known-issues.md`
- Modify: `scripts/check-runtime-doc-facts.ps1`
- Modify: `scripts/export-admin-front-source-quality-inventory.ps1`
- Refresh: `docs/knowledge/admin-front-source-quality-inventory-2026-06-07.md`

## Component map

- `Editor.vue`: one wrapper responsibility — register wangEditor plugins, build typed editor config, wire v-model/change, and install COS upload callbacks.
- No child extraction: this slice only types existing seams; splitting would add files without reducing current behavior complexity.

### Task 1: RED source-quality guard

**Files:**
- Create: `admin_front_ts/tests/shared/editor/editor-source-quality.test.ts`

- [ ] **Step 1: Write the failing test**

```ts
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, it } from 'vitest'

const editorPath = 'src/views/Main/component/display/components/Editor.vue'

function stripComments(source: string) {
  return source
    .replace(/<!--([\s\S]*?)-->/g, '')
    .replace(/\/\*([\s\S]*?)\*\//g, '')
    .replace(/\/\/.*$/gm, '')
}

function editorSource() {
  return stripComments(readFileSync(join(process.cwd(), editorPath), 'utf8'))
}

describe('wangEditor wrapper source quality', () => {
  it('does not use any/as-any at the editor boundary', () => {
    const source = editorSource()

    expect(source).not.toMatch(/\bany\b/)
    expect(source).not.toContain('(editorModule as any)')
  })

  it('uses wangEditor exported types instead of dynamic module indexing', () => {
    const source = editorSource()

    expect(source).toContain("import { Boot, type IDomEditor, type IEditorConfig, type IModuleConf } from '@wangeditor/editor'")
    expect(source).toContain('shallowRef<IDomEditor | null>(null)')
    expect(source).toContain('computed<AdminEditorConfig>')
    expect(source).toContain('type EditorAlertType = Parameters<IEditorConfig')
    expect(source).toContain('Boot.registerModule(markdownModule.default)')
  })

  it('types custom upload insert functions and rejects empty uploaded URLs', () => {
    const source = editorSource()

    expect(source).toContain('type ImageInsertFn = (src: string, alt: string, href: string) => void')
    expect(source).toContain('type VideoInsertFn = (src: string, poster: string) => void')
    expect(source).toContain('requireUploadURL(result.url)')
    expect(source).not.toContain('result.url ||')
  })
})
```

- [ ] **Step 2: Run test to verify RED**

Run:

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/editor/editor-source-quality.test.ts
```

Expected: FAIL because current `Editor.vue` contains `any`, `(editorModule as any)`, and `result.url ||`.

### Task 2: GREEN typed editor wrapper

**Files:**
- Modify: `admin_front_ts/src/views/Main/component/display/components/Editor.vue`

- [ ] **Step 1: Replace untyped editor registration**

Use:

```ts
import { Boot, type IDomEditor, type IEditorConfig, type IModuleConf } from '@wangeditor/editor'
```

and:

```ts
type MarkdownModule = { default: Partial<IModuleConf> }
const markdownModule: MarkdownModule = await import('@wangeditor/plugin-md')
Boot.registerModule(markdownModule.default)
```

- [ ] **Step 2: Type props, emits, refs, and computed config**

Use type-based `defineProps`, typed `defineEmits`, `shallowRef<IDomEditor | null>(null)`, and `computed<AdminEditorConfig>`.

- [ ] **Step 3: Type menu upload callbacks**

Add local types:

```ts
type ImageInsertFn = (src: string, alt: string, href: string) => void
type VideoInsertFn = (src: string, poster: string) => void
```

Install callbacks only when absent, preserving user-provided custom upload handlers.

- [ ] **Step 4: Remove upload URL fallback**

Use:

```ts
const uploadURL = requireUploadURL(result.url)
insertFn(uploadURL, '', '')
```

and:

```ts
const uploadURL = requireUploadURL(result.url)
insertFn(uploadURL, '')
```

Expected behavior: an empty URL throws `wangEditor upload returned empty URL`.

- [ ] **Step 5: Run focused test and typecheck**

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/editor/editor-source-quality.test.ts
npm run typecheck
```

Expected: PASS.

### Task 3: Refresh inventory and docs

**Files:**
- Create: `docs/knowledge/admin-front-editor-source-quality-review-2026-06-07.md`
- Modify: `docs/knowledge/README.md`
- Modify: `docs/knowledge/current-runtime-knowledge.md`
- Modify: `docs/knowledge/runtime-source-map.md`
- Modify: `docs/status/current-status.md`
- Modify: `docs/status/known-issues.md`
- Modify: `scripts/check-runtime-doc-facts.ps1`
- Modify: `scripts/export-admin-front-source-quality-inventory.ps1`
- Refresh: `docs/knowledge/admin-front-source-quality-inventory-2026-06-07.md`

- [ ] **Step 1: Refresh source-quality inventory**

```powershell
cd E:\admin_go
powershell -ExecutionPolicy Bypass -File .\scripts\export-admin-front-source-quality-inventory.ps1 -OutputDate 2026-06-07
```

Expected: `as any candidates` becomes `0`; `Editor.vue` no longer contributes `any/as-any/result.url ||` rows.

- [ ] **Step 2: Add review document**

Record evidence: touched file, bad rows removed, exact tests run, and compatibility facts preserved.

- [ ] **Step 3: Sync canonical docs and fact checker**

Add the new review link where DIcon/JsonEditor reviews are listed and update source-quality counts to the regenerated inventory values.

### Task 4: Final verification

- [ ] **Step 1: Runtime docs fact checks**

```powershell
cd E:\admin_go
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1 -LiveSchema
```

Expected: PASS.

- [ ] **Step 2: Diff and governance gates**

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected: PASS.

## Self-review

- Spec coverage: all acceptance bullets are covered by Tasks 1–4.
- Placeholder scan: no TBD/TODO/later placeholders.
- Type consistency: `AdminEditorConfig`, `EditorMenuConfig`, `ImageInsertFn`, `VideoInsertFn`, `IDomEditor`, `IEditorConfig`, and `IModuleConf` are defined before use.
