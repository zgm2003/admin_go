# Admin Front DIcon Source Quality Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove `DIcon` Element Plus dynamic-icon `as any` access while preserving the public icon rendering contract.

**Architecture:** Keep `DIcon` as one focused shared Vue component. Type the imported Element Plus icon module directly, add a small key guard for runtime string icon names, and cover the source shape with a targeted Vitest guard before production changes.

**Tech Stack:** Vue 3 Composition API, TypeScript, Element Plus icons, Iconify, Vitest, PowerShell generated docs.

---

### Task 1: RED guard

**Files:**
- Create: `admin_front_ts/tests/shared/icon/dicon-source-quality.test.ts`

- [x] **Step 1: Add DIcon source-quality guard**

Create `admin_front_ts/tests/shared/icon/dicon-source-quality.test.ts`:

```ts
import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'

const diconPath = 'src/components/DIcon/src/index.vue'

describe('DIcon source quality', () => {
  const source = readFileSync(join(process.cwd(), diconPath), 'utf8')

  it('does not index the Element Plus icon module through any', () => {
    expect(source).not.toContain('(mod as any)')
    expect(source).not.toContain('as unknown as Promise<Record<string, Component>>')
    expect(source).not.toContain('Record<string, Component>')
  })

  it('narrows runtime icon names through an explicit module key guard', () => {
    expect(source).toContain("type ElementPlusIconsModule = typeof import('@element-plus/icons-vue')")
    expect(source).toContain('type ElementPlusIconName = keyof ElementPlusIconsModule')
    expect(source).toContain('function hasElementPlusIcon(')
    expect(source).toContain('name is ElementPlusIconName')
    expect(source).toContain('hasElementPlusIcon(mod, name) ? mod[name] : undefined')
  })
})
```

- [x] **Step 2: Run RED**

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/icon/dicon-source-quality.test.ts
```

Expected: FAIL because `DIcon` still contains `(mod as any)` and does not have the typed module key guard.

### Task 2: GREEN implementation

**Files:**
- Modify: `admin_front_ts/src/components/DIcon/src/index.vue`

- [x] **Step 1: Type the Element Plus icon module**

In `DIcon`, replace the `Record<string, Component>` module promise with:

```ts
type ElementPlusIconsModule = typeof import('@element-plus/icons-vue')
type ElementPlusIconName = keyof ElementPlusIconsModule

let epIconsModulePromise: Promise<ElementPlusIconsModule> | null = null
const epIconCache = new Map<string, Component | null>()

function hasElementPlusIcon(
  mod: ElementPlusIconsModule,
  name: string
): name is ElementPlusIconName {
  return Object.prototype.hasOwnProperty.call(mod, name)
}
```

- [x] **Step 2: Remove any-based indexing**

Update `resolveElementPlusIcon()` to import and index through the guard:

```ts
async function resolveElementPlusIcon(name: string): Promise<Component | null> {
  if (!name) return null
  if (epIconCache.has(name)) return epIconCache.get(name) ?? null

  if (!epIconsModulePromise) {
    epIconsModulePromise = import('@element-plus/icons-vue')
  }

  try {
    const mod = await epIconsModulePromise
    const comp = hasElementPlusIcon(mod, name) ? mod[name] : undefined
    const value = comp ?? null
    epIconCache.set(name, value)
    return value
  } catch {
    epIconCache.set(name, null)
    return null
  }
}
```

- [x] **Step 3: Run GREEN**

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/icon/dicon-source-quality.test.ts
```

Expected: PASS.

### Task 3: Inventory/docs/fact sync

**Files:**
- Modify generated: `docs/knowledge/admin-front-source-quality-inventory-2026-06-07.md`
- Create: `docs/knowledge/admin-front-dicon-source-quality-review-2026-06-07.md`
- Modify: `docs/knowledge/README.md`
- Modify: `docs/knowledge/current-runtime-knowledge.md`
- Modify: `docs/knowledge/runtime-source-map.md`
- Modify: `docs/status/current-status.md`
- Modify: `docs/status/known-issues.md`
- Modify: `scripts/export-admin-front-source-quality-inventory.ps1`
- Modify: `scripts/check-runtime-doc-facts.ps1`

- [x] **Step 1: Regenerate Admin front source-quality inventory**

Add `admin_front_ts/src/components/DIcon/src/index.vue` to exporter priority files, then run:

```powershell
cd E:\admin_go
powershell -ExecutionPolicy Bypass -File .\scripts\export-admin-front-source-quality-inventory.ps1 -OutputDate 2026-06-07
```

Expected: inventory count drops by the removed `any/as-any` row, while remaining DIcon null-state fallback rows stay visible if still detected.

- [x] **Step 2: Add DIcon review artifact**

Create `docs/knowledge/admin-front-dicon-source-quality-review-2026-06-07.md` with these facts:

```text
DIcon Element Plus dynamic-module as-any debt has been closed.
Source owner = admin_front_ts/src/components/DIcon/src/index.vue.
Guard = admin_front_ts/tests/shared/icon/dicon-source-quality.test.ts.
Boundary = this only closes DIcon dynamic-module any/as-any debt; missing icon null-state fallback remains explicit and the wangEditor/DownloadManager rows remain open.
```

- [x] **Step 3: Sync runtime docs and fact checker**

Update `docs/knowledge/README.md`, `docs/knowledge/current-runtime-knowledge.md`, `docs/knowledge/runtime-source-map.md`, `docs/status/current-status.md`, `docs/status/known-issues.md`, and `scripts/check-runtime-doc-facts.ps1` so they reference the DIcon review artifact and current inventory counts.

### Task 4: Final verification

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/icon/dicon-source-quality.test.ts
npm run typecheck

cd E:\admin_go
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1 -LiveSchema
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```
