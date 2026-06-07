# Canvas Reference Feature Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the recent frontend-closable Canvas features from `E:/GitDownload/infinite-canvas` into `E:/admin_go/canvas_front_next` with the same interaction and styling.

**Architecture:** Treat the reference project as the UI source for same-name Canvas features, but keep target backend contracts authoritative. Implement only image preview, image toolbar configuration, reverse prompt, local upscale, and superResolve empty modal in this batch; leave mask/audio/video multipart to separate backend-contract specs.

**Tech Stack:** Next 16, React 19, TypeScript, Ant Design, Tailwind classes, lucide-react, Vitest, existing Canvas stores and `/api/canvas/v1/*` clients.

---

## Source spec

`E:/admin_go/docs/superpowers/specs/2026-06-07-canvas-reference-feature-parity-design.md`

## File map

- Create `E:/admin_go/canvas_front_next/tests/shared/canvas-reference-feature-parity.test.ts`
- Create `E:/admin_go/canvas_front_next/src/app/(user)/canvas/components/canvas-image-toolbar-tools.tsx`
- Create `E:/admin_go/canvas_front_next/src/app/(user)/canvas/components/canvas-image-toolbar-tools.test.tsx`
- Create `E:/admin_go/canvas_front_next/src/app/(user)/canvas/components/canvas-image-toolbar-settings-modal.tsx`
- Modify `E:/admin_go/canvas_front_next/src/app/(user)/canvas/components/canvas-node-hover-toolbar.tsx`
- Modify `E:/admin_go/canvas_front_next/src/app/(user)/canvas/components/canvas-node.tsx`
- Modify `E:/admin_go/canvas_front_next/src/app/(user)/canvas/utils/canvas-image-data.ts`
- Create `E:/admin_go/canvas_front_next/src/app/(user)/canvas/utils/canvas-image-data.test.ts`
- Create `E:/admin_go/canvas_front_next/src/app/(user)/canvas/components/canvas-node-upscale-dialog.tsx`
- Modify `E:/admin_go/canvas_front_next/src/app/(user)/canvas/[id]/canvas-client-page.tsx`

## Hard boundaries

- Do not add `CanvasNodeType.Audio`.
- Do not add `maskEdit` to the target toolbar definitions.
- Do not add browser-side `provider`, `model`, `api_key`, or `base_url`.
- Do not use `any`, `as any`, or `Record<string, any>`.
- For same-name UI, copy reference structure/classes first; only adapt for target project missing audio/mask contracts.

---

### Task 1: Add red source guard for reference feature parity

**Files:**
- Create `tests/shared/canvas-reference-feature-parity.test.ts`

- [ ] **Step 1: Write the failing guard**

Create the test with these assertions:

```ts
import { describe, expect, test } from "vitest";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

function source(path: string) {
    return readFileSync(join(process.cwd(), path), "utf8");
}

function exists(path: string) {
    return existsSync(join(process.cwd(), path));
}

describe("canvas reference feature parity", () => {
    test("image toolbar uses reference split components", () => {
        expect(exists("src/app/(user)/canvas/components/canvas-image-toolbar-tools.tsx")).toBe(true);
        expect(exists("src/app/(user)/canvas/components/canvas-image-toolbar-settings-modal.tsx")).toBe(true);

        const hover = source("src/app/(user)/canvas/components/canvas-node-hover-toolbar.tsx");
        expect(hover).toContain("buildImageToolbarTools");
        expect(hover).toContain("IMAGE_QUICK_TOOLS_STORAGE_KEY");
        expect(hover).toContain("ImageToolSettingsModal");
        expect(hover).toContain("useCopyText");
        expect(hover).toContain("Ellipsis");
        expect(hover).not.toContain("function IconAction");
        expect(hover).not.toContain("function ToolbarDivider");
        expect(hover).not.toMatch(/hasImage \? <ToolbarAction[\s\S]*裁剪并生成新节点/);
        expect(hover).not.toContain("CanvasNodeType.Audio");
    });

    test("unsupported reference features stay out of this frontend batch", () => {
        const client = source("src/app/(user)/canvas/[id]/canvas-client-page.tsx");
        expect(client).not.toContain("CanvasNodeMaskEditDialog");
        expect(client).not.toContain("maskEditImageNode");

        const tools = source("src/app/(user)/canvas/components/canvas-image-toolbar-tools.tsx");
        expect(tools).not.toContain("maskEdit");
        expect(tools).not.toContain("Brush");
    });

    test("reference closable features are wired", () => {
        const node = source("src/app/(user)/canvas/components/canvas-node.tsx");
        const client = source("src/app/(user)/canvas/[id]/canvas-client-page.tsx");
        expect(node).toContain("onViewImage");
        expect(node).toContain("data.type === CanvasNodeType.Image && hasImageContent");
        expect(client).toContain("IMAGE_PROMPT_REVERSE_PRESET");
        expect(client).toContain("createImageReversePromptNodes");
        expect(client).toContain("CanvasNodeUpscaleDialog");
        expect(client).toContain("upscaleImageNode");
        expect(client).toContain("AI 超分");
    });
});
```

- [ ] **Step 2: Verify red**

Run:

```powershell
cd E:\admin_go\canvas_front_next
npm run test -- tests/shared/canvas-reference-feature-parity.test.ts
```

Expected: FAIL because toolbar split files do not exist yet.

---

### Task 2: Add image toolbar tool definitions

**Files:**
- Create `src/app/(user)/canvas/components/canvas-image-toolbar-tools.tsx`
- Create `src/app/(user)/canvas/components/canvas-image-toolbar-tools.test.tsx`

- [ ] **Step 1: Add unit tests**

Test default IDs, unknown ID filtering, old array config, and handler invocation:

```ts
expect(defaultImageQuickToolIds).toEqual([
    "info", "delete", "saveAsset", "download", "edit",
    "copyPrompt", "reversePrompt", "replace", "crop", "upscale", "view",
]);
expect(normalizeImageQuickToolIds(["info", "maskEdit", "view"])).toEqual(["info", "view"]);
expect(readImageQuickToolsConfig(["info", "view"])).toEqual({ ids: ["info", "view"], showLabels: true });
```

- [ ] **Step 2: Verify red**

```powershell
npm run test -- "src/app/(user)/canvas/components/canvas-image-toolbar-tools.test.tsx"
```

Expected: FAIL because the module does not exist.

- [ ] **Step 3: Implement `canvas-image-toolbar-tools.tsx`**

Copy reference `canvas-image-toolbar-tools.tsx`, then adapt:

```text
remove maskEdit from ImageNodeActionToolId
remove Brush import
remove onMaskEdit from ImageToolHandlers
keep IMAGE_QUICK_TOOLS_STORAGE_KEY = canvas-image-quick-tools-v5
keep reversePrompt / upscale / superResolve / angle / view definitions
```

Default visible list must be:

```text
info, delete, saveAsset, download, edit, copyPrompt, reversePrompt, replace, crop, upscale, view
```

- [ ] **Step 4: Verify green**

```powershell
npm run test -- "src/app/(user)/canvas/components/canvas-image-toolbar-tools.test.tsx"
```

Expected: PASS.

---

### Task 3: Copy reference toolbar settings modal

**Files:**
- Create `src/app/(user)/canvas/components/canvas-image-toolbar-settings-modal.tsx`

- [ ] **Step 1: Copy reference modal**

```powershell
Copy-Item -LiteralPath 'E:\GitDownload\infinite-canvas\web\src\app\(user)\canvas\components\canvas-image-toolbar-settings-modal.tsx' -Destination 'E:\admin_go\canvas_front_next\src\app\(user)\canvas\components\canvas-image-toolbar-settings-modal.tsx'
```

- [ ] **Step 2: Verify source guard still red only on wiring**

```powershell
npm run test -- tests/shared/canvas-reference-feature-parity.test.ts
```

Expected: still FAIL because hover/client/node wiring is not done.

---

### Task 4: Refactor hover toolbar to data-driven reference UI

**Files:**
- Modify `src/app/(user)/canvas/components/canvas-node-hover-toolbar.tsx`

- [ ] **Step 1: Update imports**

Use the reference imports, but do not import `Music2` or audio:

```ts
import { App, Modal, Segmented, Tooltip } from "antd";
import { Download, Ellipsis, FolderPlus, Image as ImageIcon, Info, MessageSquare, Minus, Pencil, Plus, RefreshCw, Settings2, Trash2, Upload, Video } from "lucide-react";
import { useCopyText } from "@/hooks/use-copy-text";
import { ImageToolSettingsModal, type ImageToolbarSettingsTool } from "./canvas-image-toolbar-settings-modal";
import { IMAGE_QUICK_TOOLS_STORAGE_KEY, buildImageToolbarTools, defaultImageQuickToolIds, readImageQuickToolsConfig, type ImageQuickToolId } from "./canvas-image-toolbar-tools";
```

- [ ] **Step 2: Add toolbar config state**

Add reference state for `quickImageToolIds`, `showImageToolLabels`, draft IDs, draft label switch, and `imageToolSettingsOpen`.

- [ ] **Step 3: Build toolbar arrays**

Replace hardcoded image JSX with:

```text
baseToolbarTools = info/delete
nodeToolbarTools = retry/save/download/edit/text/config/upload/video + imageTools
imageTools = buildImageToolbarTools(node, handlers)
toolbarTools = image node filtered by quickImageToolIds, non-image unfiltered
```

Config node action must call `onToggleDialog(node)`, not `onInfo(node)`.

- [ ] **Step 4: Replace button component**

Use a single `ToolbarAction` with `showLabel`, reference tooltip style, and no `IconAction` / `ToolbarDivider`.

- [ ] **Step 5: Render more button and settings modal**

Add `更多` button with `Ellipsis`, `配置快捷工具`, and `ImageToolSettingsModal`.

- [ ] **Step 6: Verify targeted**

```powershell
npm run test -- tests/shared/canvas-reference-feature-parity.test.ts
npm run typecheck
```

Expected: source guard still waits for node/client wiring; typecheck may fail for missing new props until Task 6.

---

### Task 5: Add image double-click preview to CanvasNode

**Files:**
- Modify `src/app/(user)/canvas/components/canvas-node.tsx`

- [ ] **Step 1: Add prop**

Add:

```ts
onViewImage?: (node: CanvasNodeData) => void;
```

- [ ] **Step 2: Update double-click branch**

Inside node wrapper `onDoubleClick`, keep batch first, then image preview, then text edit:

```ts
if (isBatchRoot) {
    event.stopPropagation();
    onToggleBatch?.(data.id);
    return;
}
if (data.type === CanvasNodeType.Image && hasImageContent) {
    event.stopPropagation();
    onViewImage?.(data);
    return;
}
if (data.type !== CanvasNodeType.Text) return;
event.stopPropagation();
setIsEditingContent(true);
```

- [ ] **Step 3: Pass prop from client page**

In `<CanvasNode />`:

```tsx
onViewImage={(node) => setPreviewNodeId(node.id)}
```

---

### Task 6: Wire reverse prompt

**Files:**
- Modify `src/app/(user)/canvas/[id]/canvas-client-page.tsx`
- Modify `src/app/(user)/canvas/components/canvas-node-hover-toolbar.tsx`

- [ ] **Step 1: Add `IMAGE_PROMPT_REVERSE_PRESET`**

Copy the exact reference preset text from `E:/GitDownload/infinite-canvas/web/src/app/(user)/canvas/[id]/canvas-client-page.tsx`.

- [ ] **Step 2: Add `createImageReversePromptNodes`**

Copy reference behavior, but keep target project types:

```text
source image empty -> message.warning("图片节点为空，无法反推提示词")
create Text node at right side
create Config node further right
composerContent = 参考图片：@[node:<imageId>]\n任务说明：@[node:<textNodeId>]
connect image -> config and text -> config
select config and open dialog
```

- [ ] **Step 3: Pass toolbar prop**

```tsx
onReversePrompt={createImageReversePromptNodes}
```

- [ ] **Step 4: Verify**

```powershell
npm run test -- tests/shared/canvas-reference-feature-parity.test.ts
npm run typecheck
```

Expected: only upscale/superResolve gaps remain if earlier tasks are correct.

---

### Task 7: Add local upscale and superResolve empty modal

**Files:**
- Modify `src/app/(user)/canvas/utils/canvas-image-data.ts`
- Create `src/app/(user)/canvas/utils/canvas-image-data.test.ts`
- Create `src/app/(user)/canvas/components/canvas-node-upscale-dialog.tsx`
- Modify `src/app/(user)/canvas/[id]/canvas-client-page.tsx`

- [ ] **Step 1: Add upscale size tests**

Cover:

```ts
expect(resolveUpscaleSize(800, 600, 2048)).toEqual({ width: 2048, height: 1536 });
expect(resolveUpscaleSize(600, 900, 2048)).toEqual({ width: 1365, height: 2048 });
expect(resolveUpscaleSize(0, 0, 0)).toEqual({ width: 1, height: 1 });
```

- [ ] **Step 2: Verify red**

```powershell
npm run test -- "src/app/(user)/canvas/utils/canvas-image-data.test.ts"
```

Expected: FAIL because upscale exports do not exist.

- [ ] **Step 3: Copy upscale helpers**

From reference `canvas-image-data.ts`, copy:

```text
ImageUpscaleAlgorithm
MAX_UPSCALE_LONG_EDGE
ImageUpscaleParams
upscaleDataUrl
resolveUpscaleSize
drawStepUpscale
drawResize
drawResizeCanvas
```

Do not change existing `cropDataUrl` and `transformAngleDataUrl` behavior.

- [ ] **Step 4: Copy upscale dialog**

```powershell
Copy-Item -LiteralPath 'E:\GitDownload\infinite-canvas\web\src\app\(user)\canvas\components\canvas-node-upscale-dialog.tsx' -Destination 'E:\admin_go\canvas_front_next\src\app\(user)\canvas\components\canvas-node-upscale-dialog.tsx'
```

- [ ] **Step 5: Wire client page**

Add:

```text
upscaleNodeId
superResolveNodeId
upscaleImageNode
CanvasNodeUpscaleDialog
Modal title="AI 超分" with "暂未实现"
```

Pass toolbar props:

```tsx
onUpscale={(node) => setUpscaleNodeId(node.id)}
onSuperResolve={(node) => setSuperResolveNodeId(node.id)}
```

- [ ] **Step 6: Verify targeted**

```powershell
npm run test -- tests/shared/canvas-reference-feature-parity.test.ts
npm run test -- "src/app/(user)/canvas/components/canvas-image-toolbar-tools.test.tsx"
npm run test -- "src/app/(user)/canvas/utils/canvas-image-data.test.ts"
npm run typecheck
```

Expected: all PASS.

---

### Task 8: Full verification and handoff

**Files:**
- No new implementation files.

- [ ] **Step 1: Full Canvas Next test**

```powershell
cd E:\admin_go\canvas_front_next
npm run test
```

Expected: all tests PASS.

- [ ] **Step 2: Typecheck**

```powershell
npm run typecheck
```

Expected: PASS.

- [ ] **Step 3: Diff check in Canvas Next**

```powershell
git diff --check
git status --short --branch
```

Expected: no whitespace errors; working tree state understood.

- [ ] **Step 4: Root docs/governance check**

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected: no whitespace errors; governance PASS.

## Known follow-ups

- `Canvas mask edit backend contract` spec: needed before exposing局部编辑 as a real target-project feature.
- `Canvas audio node/agent contract` spec: only after backend settings/auth/RBAC/API are defined.
- `Canvas video/audio multipart reference input` spec: only after backend transport and task storage are explicit.

## Execution choice

Plan complete and saved to `E:/admin_go/docs/superpowers/plans/2026-06-07-canvas-reference-feature-parity.md`.

Recommended execution: **Subagent-Driven** for Tasks 1-7, because source guard, toolbar split, node preview, reverse prompt, and upscale wiring are separable.
