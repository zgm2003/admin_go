# Infinite Canvas Feature Extraction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract the approved Canvas Next enhancements into `E:\GitDownload\infinite-canvas` in phase order `P0 -> P1 -> P4 -> P2 -> P3` without removing the target project's existing admin, audio, mask editing, public asset library, Seedance, and credits features.

**Architecture:** Treat `E:\GitDownload\infinite-canvas` as the runtime source of truth and port only reusable behavior from `E:\admin_go\canvas_front_next`. Keep the target API surface native: auth under `/api/auth`, model requests under `/api/v1`, and assets under `/api/assets` plus existing admin routes. Lock each feature with focused tests before changing implementation.

**Tech Stack:** Go 1.25, Gin, GORM, Next.js App Router, React 19, TypeScript, Zustand, localforage, axios, Vitest.

---

## Scope Rules

- Work in target repo: `E:\GitDownload\infinite-canvas`.
- Use source repo only as reference: `E:\admin_go\canvas_front_next`.
- Keep target `AGENTS.md` constraints: minimal edits, no unrelated refactors, no broad rewrites.
- Do not delete or downgrade: admin backend, audio nodes, mask editing, Seedance / audio / public asset library, credits.
- Use target-native contracts:
  - Auth: `/api/auth/*`
  - AI runtime: `/api/v1/images/*`, `/api/v1/videos`, `/api/v1/audio/speech`, `/api/v1/chat/completions`
  - Assets: `/api/assets`, `/api/admin/assets`
- Keep phase order: P0, P1, P4, P2, P3.

## File Responsibility Map

### P0 test and safety base

- Modify `E:\GitDownload\infinite-canvas\web\package.json`: add Vitest scripts and dev dependency.
- Modify `E:\GitDownload\infinite-canvas\web\bun.lock`: updated by `bun add -d vitest@^4.1.7`.
- Create `E:\GitDownload\infinite-canvas\web\vitest.config.ts`: alias `@` to `web/src`.
- Create `E:\GitDownload\infinite-canvas\web\src\lib\image-reference-prompt.test.ts`: stable image label behavior.
- Create `E:\GitDownload\infinite-canvas\web\src\lib\image-utils.test.ts`: reject empty data URL and keep valid conversion.
- Create `E:\GitDownload\infinite-canvas\web\src\services\storage-fallback.ts`: strip stale `blob:` fallback when backing storage is missing.
- Create `E:\GitDownload\infinite-canvas\web\src\services\storage-fallback.test.ts`: stale blob fallback behavior.
- Modify `E:\GitDownload\infinite-canvas\web\src\lib\image-utils.ts`: fail closed in `dataUrlToFile`.
- Modify `E:\GitDownload\infinite-canvas\web\src\services\image-storage.ts`: use storage fallback helper.
- Modify `E:\GitDownload\infinite-canvas\web\src\services\file-storage.ts`: use storage fallback helper and revoke media object URLs consistently.

### P1 Canvas text, mentions, resource order, generation context

- Modify `E:\GitDownload\infinite-canvas\web\src\app\(user)\canvas\types.ts`: add `inputOrder?: string[]` to node metadata.
- Modify `E:\GitDownload\infinite-canvas\web\src\app\(user)\canvas\utils\canvas-resource-references.ts`: merge source input ordering with target audio support.
- Create `E:\GitDownload\infinite-canvas\web\src\app\(user)\canvas\utils\canvas-resource-references.test.ts`: image / video / audio / text labeling and ordering.
- Modify `E:\GitDownload\infinite-canvas\web\src\app\(user)\canvas\components\canvas-resource-mention-textarea.tsx`: height chain, highlight metrics, no padding highlight token, preserve portal menu and `onSubmit`.
- Create `E:\GitDownload\infinite-canvas\web\src\app\(user)\canvas\components\canvas-resource-mention-textarea.test.ts`: pure helper and CSS class safety.
- Modify `E:\GitDownload\infinite-canvas\web\src\app\(user)\canvas\components\canvas-node-generation.ts`: composer content source, stable labels from input order, stale token preservation, image hydration guard.
- Create `E:\GitDownload\infinite-canvas\web\src\app\(user)\canvas\components\canvas-node-generation.test.ts`: composer and media reference behavior.

### P4 backend asset persistence

- Modify `E:\GitDownload\infinite-canvas\model\asset.go`: add video type, ownership / visibility, and metadata fields.
- Modify `E:\GitDownload\infinite-canvas\repository\asset.go`: support public plus user-private listing and owner-scoped delete.
- Create or modify `E:\GitDownload\infinite-canvas\repository\asset_test.go`: SQLite tests for visibility and owner delete.
- Modify `E:\GitDownload\infinite-canvas\service\assets.go`: validate asset payloads, user save/delete functions, public admin defaults.
- Create `E:\GitDownload\infinite-canvas\service\assets_test.go`: validation and defaulting.
- Modify `E:\GitDownload\infinite-canvas\handler\assets.go`: add user-authenticated save/delete handlers.
- Modify `E:\GitDownload\infinite-canvas\router\router.go`: add `POST /api/assets` and `DELETE /api/assets/:id` behind `middleware.UserAuth`; keep public `GET /api/assets` and admin routes.
- Modify `E:\GitDownload\infinite-canvas\web\src\services\api\assets.ts`: add create/delete APIs and metadata types.
- Modify `E:\GitDownload\infinite-canvas\web\src\stores\use-asset-store.ts`: persist to backend when a token exists while retaining localforage fallback.

### P2 API envelope and remote generation boundaries

- Create `E:\GitDownload\infinite-canvas\web\src\services\api\error-payload.ts`: strict message and JSON / Blob error parsing helpers.
- Create `E:\GitDownload\infinite-canvas\web\src\services\api\request.test.ts`: strict envelope tests using target routes.
- Modify `E:\GitDownload\infinite-canvas\web\src\services\api\request.ts`: throw `ApiError`, reject empty `msg`, preserve status/code.
- Create `E:\GitDownload\infinite-canvas\web\src\services\api\video.test.ts`: JSON Blob and failed envelope handling.
- Modify `E:\GitDownload\infinite-canvas\web\src\services\api\video.ts`: use strict envelope parsing and async axios error parsing.
- Modify `E:\GitDownload\infinite-canvas\web\src\services\api\image.ts`: use strict API error parsing for target backend envelopes.

### P3 auth/logout behavior

- Modify `E:\GitDownload\infinite-canvas\handler\response.go`: add coded failure helper.
- Modify `E:\GitDownload\infinite-canvas\middleware\admin.go`: return code `401` or `403` for auth failures while keeping JSON envelope.
- Modify `E:\GitDownload\infinite-canvas\handler\auth.go`: add logout handler.
- Modify `E:\GitDownload\infinite-canvas\router\router.go`: add `POST /api/auth/logout` behind `middleware.UserAuth`.
- Modify `E:\GitDownload\infinite-canvas\web\src\services\api\auth.ts`: add logout API.
- Modify `E:\GitDownload\infinite-canvas\web\src\stores\use-user-store.ts`: backend logout before clearing local session.
- Create `E:\GitDownload\infinite-canvas\web\src\stores\use-user-store.test.ts`: logout sequencing.
- Modify `E:\GitDownload\infinite-canvas\web\src\components\layout\user-status-actions.tsx`: use store `logout`.
- Modify `E:\GitDownload\infinite-canvas\web\src\app\(admin)\admin\layout.tsx`: use store `logout`.
- Modify `E:\GitDownload\infinite-canvas\web\src\components\layout\client-root-init.tsx`: listen to auth error event and clear stale session.

### Documentation and verification

- Modify `E:\GitDownload\infinite-canvas\docs\content\docs\backend\api-response.mdx`: document strict frontend error handling and auth codes.
- Modify `E:\GitDownload\infinite-canvas\docs\content\docs\backend\backend-database.mdx`: document new asset columns.
- Modify `E:\GitDownload\infinite-canvas\docs\content\docs\progress\todo.mdx`: remove completed migration items that are actually implemented.
- Modify `E:\GitDownload\infinite-canvas\docs\content\docs\progress\pending-test.mdx`: add user-testable entries for landed changes.

---

## Task 0: Prepare Target Branch and Baseline Evidence

**Files:**
- Read: `E:\GitDownload\infinite-canvas\AGENTS.md`
- Read: `E:\GitDownload\infinite-canvas\web\package.json`
- Read: `E:\GitDownload\infinite-canvas\router\router.go`
- Read: `E:\GitDownload\infinite-canvas\handler\assets.go`
- Read: `E:\GitDownload\infinite-canvas\web\src\app\(user)\canvas\components\canvas-resource-mention-textarea.tsx`
- Read: `E:\GitDownload\infinite-canvas\web\src\app\(user)\canvas\components\canvas-node-generation.ts`

- [ ] **Step 1: Confirm target worktree is clean**

Run:

```powershell
git -C E:\GitDownload\infinite-canvas status --short
```

Expected: no output. If output exists, stop and record the paths before editing.

- [ ] **Step 2: Create isolated branch**

Run:

```powershell
git -C E:\GitDownload\infinite-canvas switch -c feature/infinite-canvas-extraction
```

Expected: branch created. If it already exists, run:

```powershell
git -C E:\GitDownload\infinite-canvas switch feature/infinite-canvas-extraction
```

- [ ] **Step 3: Record current target contracts**

Run:

```powershell
rg -n 'api\.(GET|POST|DELETE)|v1\.POST|admin\.(GET|POST|DELETE)' E:\GitDownload\infinite-canvas\router\router.go
rg -n 'AssetType|type Asset struct|func Assets|func AdminSaveAsset|func dataUrlToFile|function buildNodeGenerationContext' E:\GitDownload\infinite-canvas -g '!web/node_modules'
```

Expected:

- Routes show target-native `/api/auth`, `/api/v1`, `/api/assets`, `/api/admin`.
- `AssetType` only has text/image before P4.
- `dataUrlToFile` accepts empty content before P0.
- `buildNodeGenerationContext` has composer/stale-token gaps before P1.

- [ ] **Step 4: Commit checkpoint only if files changed**

Run:

```powershell
git -C E:\GitDownload\infinite-canvas diff --stat
```

Expected: no diff. Do not commit when no files changed.

---

## Task 1: P0 Vitest Harness

**Files:**
- Modify: `E:\GitDownload\infinite-canvas\web\package.json`
- Modify: `E:\GitDownload\infinite-canvas\web\bun.lock`
- Create: `E:\GitDownload\infinite-canvas\web\vitest.config.ts`
- Create: `E:\GitDownload\infinite-canvas\web\src\lib\image-reference-prompt.test.ts`

- [ ] **Step 1: Write the first frontend test**

Create `E:\GitDownload\infinite-canvas\web\src\lib\image-reference-prompt.test.ts`:

```ts
import { describe, expect, it } from "vitest";

import { buildImageReferencePromptText, imageReferenceLabel } from "./image-reference-prompt";
import type { ReferenceImage } from "@/types/image";

const reference = (id: string): ReferenceImage => ({
    id,
    name: `${id}.png`,
    type: "image/png",
    dataUrl: `data:image/png;base64,${id}`,
});

describe("imageReferenceLabel", () => {
    it("uses one-based Chinese image labels", () => {
        expect(imageReferenceLabel(0)).toBe("图片1");
        expect(imageReferenceLabel(2)).toBe("图片3");
    });
});

describe("buildImageReferencePromptText", () => {
    it("trims and returns the original prompt when no references exist", () => {
        expect(buildImageReferencePromptText("  画一只猫  ", [])).toBe("画一只猫");
    });

    it("prefixes prompts with stable reference labels", () => {
        expect(buildImageReferencePromptText("按照图片1的姿势和图片2的配色生成", [reference("a"), reference("b")])).toBe(
            "参考图片编号：图片1、图片2。请按这些编号理解提示词中的图片引用。\n\n按照图片1的姿势和图片2的配色生成",
        );
    });

    it("does not create client-owned provider or model fields", () => {
        const result = buildImageReferencePromptText("参考图片1", [reference("a")]);
        expect(result).not.toContain("provider");
        expect(result).not.toContain("api_key");
        expect(result).not.toContain("base_url");
        expect(result).not.toContain("model");
    });
});
```

- [ ] **Step 2: Run test to verify harness is missing**

Run:

```powershell
cd E:\GitDownload\infinite-canvas\web
bun run test -- --run src/lib/image-reference-prompt.test.ts
```

Expected: fails because `test` script or Vitest dependency is not installed.

- [ ] **Step 3: Add Vitest dependency and scripts**

Run:

```powershell
cd E:\GitDownload\infinite-canvas\web
bun add -d vitest@^4.1.7
```

Modify `E:\GitDownload\infinite-canvas\web\package.json` scripts to include:

```json
{
  "scripts": {
    "dev": "next dev --webpack -H 0.0.0.0 -p 3000",
    "build": "next build",
    "start": "next start",
    "format": "prettier --write .",
    "format:check": "prettier --check .",
    "test": "vitest",
    "test:run": "vitest run"
  }
}
```

- [ ] **Step 4: Add Vitest alias config**

Create `E:\GitDownload\infinite-canvas\web\vitest.config.ts`:

```ts
import { fileURLToPath } from "node:url";
import { defineConfig } from "vitest/config";

export default defineConfig({
    resolve: {
        alias: {
            "@": fileURLToPath(new URL("./src", import.meta.url)),
        },
    },
});
```

- [ ] **Step 5: Run harness test**

Run:

```powershell
cd E:\GitDownload\infinite-canvas\web
bun run test:run src/lib/image-reference-prompt.test.ts
```

Expected: all tests in `image-reference-prompt.test.ts` pass.

- [ ] **Step 6: Commit P0 harness**

Run:

```powershell
git -C E:\GitDownload\infinite-canvas add web/package.json web/bun.lock web/vitest.config.ts web/src/lib/image-reference-prompt.test.ts
git -C E:\GitDownload\infinite-canvas commit -m "test: add frontend vitest harness"
```

---

## Task 2: P0 Pure Safety Utilities

**Files:**
- Create: `E:\GitDownload\infinite-canvas\web\src\lib\image-utils.test.ts`
- Create: `E:\GitDownload\infinite-canvas\web\src\services\storage-fallback.ts`
- Create: `E:\GitDownload\infinite-canvas\web\src\services\storage-fallback.test.ts`
- Modify: `E:\GitDownload\infinite-canvas\web\src\lib\image-utils.ts`
- Modify: `E:\GitDownload\infinite-canvas\web\src\services\image-storage.ts`
- Modify: `E:\GitDownload\infinite-canvas\web\src\services\file-storage.ts`

- [ ] **Step 1: Write failing data URL tests**

Create `E:\GitDownload\infinite-canvas\web\src\lib\image-utils.test.ts`:

```ts
import { describe, expect, it } from "vitest";

import { dataUrlToFile } from "./image-utils";

describe("dataUrlToFile", () => {
    it("rejects empty reference images instead of creating empty files", () => {
        expect(() => dataUrlToFile({ id: "ref-1", name: "missing.png", type: "image/png", dataUrl: "" })).toThrow("参考图片已丢失");
    });

    it("rejects malformed reference image data", () => {
        expect(() => dataUrlToFile({ id: "ref-1", name: "bad.png", type: "image/png", dataUrl: "not-a-data-url" })).toThrow("参考图片格式无效");
    });

    it("creates a file from a valid data url", async () => {
        const file = dataUrlToFile({ id: "ref-1", name: "reference.png", type: "image/png", dataUrl: "data:image/png;base64,eA==" });

        expect(file.name).toBe("reference.png");
        expect(file.type).toBe("image/png");
        expect(await file.text()).toBe("x");
    });
});
```

- [ ] **Step 2: Write failing storage fallback tests**

Create `E:\GitDownload\infinite-canvas\web\src\services\storage-fallback.test.ts`:

```ts
import { describe, expect, it } from "vitest";

import { resolveMissingStorageFallback } from "./storage-fallback";

describe("resolveMissingStorageFallback", () => {
    it("does not reuse stale blob URLs when local storage is missing", () => {
        expect(resolveMissingStorageFallback("blob:http://localhost/stale")).toBe("");
    });

    it("keeps non-blob fallback URLs", () => {
        expect(resolveMissingStorageFallback("https://example.test/image.png")).toBe("https://example.test/image.png");
        expect(resolveMissingStorageFallback("data:image/png;base64,xxx")).toBe("data:image/png;base64,xxx");
        expect(resolveMissingStorageFallback("")).toBe("");
    });
});
```

- [ ] **Step 3: Run tests to verify failure**

Run:

```powershell
cd E:\GitDownload\infinite-canvas\web
bun run test:run src/lib/image-utils.test.ts src/services/storage-fallback.test.ts
```

Expected:

- `image-utils.test.ts` fails because empty and malformed data URLs currently create empty files.
- `storage-fallback.test.ts` fails because `storage-fallback.ts` does not exist.

- [ ] **Step 4: Add storage fallback helper**

Create `E:\GitDownload\infinite-canvas\web\src\services\storage-fallback.ts`:

```ts
export function resolveMissingStorageFallback(fallback = "") {
    return fallback.startsWith("blob:") ? "" : fallback;
}
```

- [ ] **Step 5: Fail closed in dataUrlToFile**

Modify `dataUrlToFile` in `E:\GitDownload\infinite-canvas\web\src\lib\image-utils.ts`:

```ts
export function dataUrlToFile(image: ReferenceImage) {
    if (!image.dataUrl) throw new Error("参考图片已丢失，无法继续生成");
    const [header, content] = image.dataUrl.split(",", 2);
    if (!header.startsWith("data:") || !content) throw new Error("参考图片格式无效，无法继续生成");
    const mimeType = header.match(/data:(.*?);base64/)?.[1] || image.type || "image/png";
    const binary = atob(content);
    const bytes = new Uint8Array(binary.length);
    for (let index = 0; index < binary.length; index += 1) {
        bytes[index] = binary.charCodeAt(index);
    }
    return new File([bytes], image.name || "reference.png", { type: mimeType });
}
```

- [ ] **Step 6: Use storage fallback for images**

Modify imports and missing-blob branch in `E:\GitDownload\infinite-canvas\web\src\services\image-storage.ts`:

```ts
import { resolveMissingStorageFallback } from "@/services/storage-fallback";
```

```ts
export async function resolveImageUrl(storageKey?: string, fallback = "") {
    if (!storageKey) return fallback;
    const cached = objectUrls.get(storageKey);
    if (cached) return cached;
    const blob = await store.getItem<Blob>(storageKey);
    if (!blob) return resolveMissingStorageFallback(fallback);
    const url = URL.createObjectURL(blob);
    objectUrls.set(storageKey, url);
    return url;
}
```

- [ ] **Step 7: Use storage fallback for media**

Modify imports and missing-blob branch in `E:\GitDownload\infinite-canvas\web\src\services\file-storage.ts`:

```ts
import { resolveMissingStorageFallback } from "@/services/storage-fallback";
```

```ts
export async function resolveMediaUrl(storageKey?: string, fallback = "") {
    if (!storageKey) return fallback;
    const cached = objectUrls.get(storageKey);
    if (cached) return cached;
    const blob = await store.getItem<Blob>(storageKey);
    if (!blob) return resolveMissingStorageFallback(fallback);
    const url = URL.createObjectURL(blob);
    objectUrls.set(storageKey, url);
    return url;
}
```

Also change `cleanupUnusedMedia` to reuse `deleteStoredMedia`:

```ts
export async function cleanupUnusedMedia(usedData: unknown) {
    const usedKeys = collectMediaStorageKeys(usedData);
    const unused: string[] = [];
    await store.iterate((_value, key) => {
        if (!usedKeys.has(key)) unused.push(key);
    });
    await deleteStoredMedia(unused);
}
```

- [ ] **Step 8: Run P0 tests**

Run:

```powershell
cd E:\GitDownload\infinite-canvas\web
bun run test:run src/lib/image-reference-prompt.test.ts src/lib/image-utils.test.ts src/services/storage-fallback.test.ts
```

Expected: all P0 tests pass.

- [ ] **Step 9: Commit P0 safety utilities**

Run:

```powershell
git -C E:\GitDownload\infinite-canvas add web/src/lib/image-utils.ts web/src/lib/image-utils.test.ts web/src/services/storage-fallback.ts web/src/services/storage-fallback.test.ts web/src/services/image-storage.ts web/src/services/file-storage.ts
git -C E:\GitDownload\infinite-canvas commit -m "fix: fail closed for missing local media"
```

---

## Task 3: P1 Mention Textarea Height and Highlight Metrics

**Files:**
- Modify: `E:\GitDownload\infinite-canvas\web\src\app\(user)\canvas\components\canvas-resource-mention-textarea.tsx`
- Create: `E:\GitDownload\infinite-canvas\web\src\app\(user)\canvas\components\canvas-resource-mention-textarea.test.ts`

- [ ] **Step 1: Write failing helper tests**

Create `E:\GitDownload\infinite-canvas\web\src\app\(user)\canvas\components\canvas-resource-mention-textarea.test.ts`:

```ts
import { describe, expect, it } from "vitest";

import { DEFAULT_MENTION_CONTAINER_CLASS_NAME, findMentionHighlightLabels, mentionHighlightMetricsFromComputedStyle, MENTION_HIGHLIGHT_MARK_CLASS_NAME } from "./canvas-resource-mention-textarea";

describe("CanvasResourceMentionTextarea helpers", () => {
    it("keeps the default wrapper in the flex height chain", () => {
        expect(DEFAULT_MENTION_CONTAINER_CLASS_NAME).toContain("flex");
        expect(DEFAULT_MENTION_CONTAINER_CLASS_NAME).toContain("h-full");
        expect(DEFAULT_MENTION_CONTAINER_CLASS_NAME).toContain("min-h-0");
    });

    it("only highlights labels that are present in the value", () => {
        expect(findMentionHighlightLabels("参考图片1和音频1", ["图片1", "视频1", "音频1"])).toEqual(["图片1", "音频1"]);
    });

    it("does not add padding to highlight marks because padding shifts textarea caret metrics", () => {
        expect(MENTION_HIGHLIGHT_MARK_CLASS_NAME).not.toContain("px-");
        expect(MENTION_HIGHLIGHT_MARK_CLASS_NAME).not.toContain("py-");
    });

    it("copies textarea text metrics to the highlight overlay", () => {
        const metrics = mentionHighlightMetricsFromComputedStyle({
            fontFamily: "Arial",
            fontSize: "14px",
            fontWeight: "400",
            lineHeight: "20px",
            letterSpacing: "0px",
            textAlign: "left",
            textTransform: "none",
            textIndent: "0px",
            textRendering: "auto",
            wordSpacing: "0px",
            tabSize: "4",
            paddingTop: "8px",
            paddingRight: "10px",
            paddingBottom: "8px",
            paddingLeft: "10px",
            borderTopWidth: "1px",
            borderRightWidth: "1px",
            borderBottomWidth: "1px",
            borderLeftWidth: "1px",
            boxSizing: "border-box",
        });

        expect(metrics).toMatchObject({
            fontSize: "14px",
            lineHeight: "20px",
            paddingTop: "8px",
            boxSizing: "border-box",
        });
    });
});
```

- [ ] **Step 2: Run test to verify failure**

Run:

```powershell
cd E:\GitDownload\infinite-canvas\web
bun run test:run "src/app/(user)/canvas/components/canvas-resource-mention-textarea.test.ts"
```

Expected: fails because the helper exports do not exist and the current highlight class uses padding.

- [ ] **Step 3: Add metric helpers and safe class names**

Modify imports in `canvas-resource-mention-textarea.tsx`:

```ts
import { forwardRef, useLayoutEffect, useMemo, useRef, useState } from "react";
```

Add this helper block above the component:

```ts
const MENTION_HIGHLIGHT_METRIC_KEYS = [
    "fontFamily",
    "fontSize",
    "fontWeight",
    "lineHeight",
    "letterSpacing",
    "textAlign",
    "textTransform",
    "textIndent",
    "textRendering",
    "wordSpacing",
    "tabSize",
    "paddingTop",
    "paddingRight",
    "paddingBottom",
    "paddingLeft",
    "borderTopWidth",
    "borderRightWidth",
    "borderBottomWidth",
    "borderLeftWidth",
    "boxSizing",
] as const;

type MentionHighlightMetricKey = (typeof MENTION_HIGHLIGHT_METRIC_KEYS)[number];

export const MENTION_HIGHLIGHT_MARK_CLASS_NAME = "rounded bg-blue-500/15 text-blue-600 dark:text-blue-300";
export const DEFAULT_MENTION_CONTAINER_CLASS_NAME = "relative flex h-full min-h-0 w-full";

export function findMentionHighlightLabels(value: string, labels: string[]) {
    if (!value) return [];
    return labels.filter((label) => label.length > 0 && value.includes(label));
}

export function mentionHighlightMetricsFromComputedStyle(style: Pick<CSSStyleDeclaration, MentionHighlightMetricKey>) {
    const metrics: Record<string, string> = {};
    for (const key of MENTION_HIGHLIGHT_METRIC_KEYS) {
        const value = style[key];
        if (value) metrics[key] = value;
    }
    return metrics as CSSProperties;
}

function sameMentionHighlightMetrics(current: CSSProperties, next: CSSProperties) {
    return MENTION_HIGHLIGHT_METRIC_KEYS.every((key) => current[key] === next[key]);
}
```

- [ ] **Step 4: Replace highlight state logic**

Inside the component, add:

```ts
const [highlightMetrics, setHighlightMetrics] = useState<CSSProperties>({});
const activeReferences = useMemo(() => references.filter((item) => item.active), [references]);
const labels = useMemo(() => Array.from(new Set(activeReferences.map((item) => item.label))).sort((a, b) => b.length - a.length), [activeReferences]);
const highlightLabels = useMemo(() => findMentionHighlightLabels(value, labels), [labels, value]);
const shouldShowHighlight = highlightLabels.length > 0;
```

Use `activeReferences` in candidate filtering:

```ts
const candidates = useMemo(() => {
    if (!mention) return [];
    const query = mention.query.trim().toLowerCase();
    if (!query) return activeReferences;
    return activeReferences.filter((item) => `${item.label} ${item.title} ${item.kind} ${item.text || ""}`.toLowerCase().includes(query));
}, [activeReferences, mention]);
```

Add layout effect:

```ts
useLayoutEffect(() => {
    if (!shouldShowHighlight) {
        setHighlightMetrics((current) => (Object.keys(current).length ? {} : current));
        return;
    }
    const textarea = textareaRef.current;
    if (!textarea) return;
    const next = mentionHighlightMetricsFromComputedStyle(window.getComputedStyle(textarea));
    setHighlightMetrics((current) => (sameMentionHighlightMetrics(current, next) ? current : next));
}, [className, shouldShowHighlight, style, value]);
```

- [ ] **Step 5: Fix wrapper and highlight render**

Change the wrapper opening tag to:

```tsx
<div className={containerClassName ?? DEFAULT_MENTION_CONTAINER_CLASS_NAME}>
```

Change merged textarea style to:

```ts
const transparentTextStyle: CSSProperties = shouldShowHighlight ? { color: "transparent", background: "transparent", caretColor: style?.color ?? theme.node.text } : {};
const highlightStyle: CSSProperties = { ...style, ...highlightMetrics, color: theme.node.text };
```

Change overlay render to:

```tsx
{shouldShowHighlight ? <MentionHighlight value={value} labels={highlightLabels} className={className} style={highlightStyle} /> : null}
```

Change textarea style to:

```tsx
style={{ ...style, ...transparentTextStyle }}
```

Add this highlight component and keep the existing portal menu:

```tsx
function MentionHighlight({ value, labels, className, style }: { value: string; labels: string[]; className?: string; style?: CSSProperties }) {
    if (!labels.length) return null;
    const pattern = new RegExp(`(${labels.map(escapeRegExp).join("|")})`, "g");
    return (
        <div className={`${className ?? ""} pointer-events-none absolute inset-0 overflow-hidden whitespace-pre-wrap break-words`} style={style} aria-hidden="true">
            {value.split(pattern).map((part, index) =>
                labels.includes(part) ? (
                    <mark key={`${part}-${index}`} className={MENTION_HIGHLIGHT_MARK_CLASS_NAME}>
                        {part}
                    </mark>
                ) : (
                    <span key={`${part}-${index}`}>{part}</span>
                ),
            )}
        </div>
    );
}
```

Remove the old `MentionHighlightText` function after the new `MentionHighlight` is in place.

- [ ] **Step 6: Run mention tests**

Run:

```powershell
cd E:\GitDownload\infinite-canvas\web
bun run test:run "src/app/(user)/canvas/components/canvas-resource-mention-textarea.test.ts"
```

Expected: all tests pass.

- [ ] **Step 7: Commit P1 mention textarea**

Run:

```powershell
git -C E:\GitDownload\infinite-canvas add "web/src/app/(user)/canvas/components/canvas-resource-mention-textarea.tsx" "web/src/app/(user)/canvas/components/canvas-resource-mention-textarea.test.ts"
git -C E:\GitDownload\infinite-canvas commit -m "fix: stabilize canvas mention textarea layout"
```

---

## Task 4: P1 Resource Ordering and Composer Preservation

**Files:**
- Modify: `E:\GitDownload\infinite-canvas\web\src\app\(user)\canvas\types.ts`
- Modify: `E:\GitDownload\infinite-canvas\web\src\app\(user)\canvas\utils\canvas-resource-references.ts`
- Create: `E:\GitDownload\infinite-canvas\web\src\app\(user)\canvas\utils\canvas-resource-references.test.ts`
- Modify: `E:\GitDownload\infinite-canvas\web\src\app\(user)\canvas\components\canvas-node-generation.ts`
- Create: `E:\GitDownload\infinite-canvas\web\src\app\(user)\canvas\components\canvas-node-generation.test.ts`

- [ ] **Step 1: Write resource ordering tests with audio preserved**

Create `E:\GitDownload\infinite-canvas\web\src\app\(user)\canvas\utils\canvas-resource-references.test.ts`:

```ts
import { describe, expect, it } from "vitest";

import { buildCanvasResourceReferences, buildNodeMentionReferences, getGenerationResourceNodes } from "./canvas-resource-references";
import { CanvasNodeType, type CanvasConnection, type CanvasNodeData } from "../types";

function node(id: string, type: CanvasNodeType, metadata: CanvasNodeData["metadata"] = {}): CanvasNodeData {
    return { id, type, title: id, position: { x: 0, y: 0 }, width: 100, height: 100, metadata };
}

const nodes: CanvasNodeData[] = [
    node("image-a", CanvasNodeType.Image, { content: "data:image/png;base64,a", mimeType: "image/png" }),
    node("text-a", CanvasNodeType.Text, { content: "一段构图说明" }),
    node("video-a", CanvasNodeType.Video, { content: "blob:http://localhost/video" }),
    node("audio-a", CanvasNodeType.Audio, { content: "blob:http://localhost/audio", mimeType: "audio/mpeg" }),
    node("config-a", CanvasNodeType.Config, { inputOrder: ["audio-a", "text-a", "image-a"] }),
];

const connections: CanvasConnection[] = [
    { id: "c1", fromNodeId: "image-a", toNodeId: "config-a" },
    { id: "c2", fromNodeId: "text-a", toNodeId: "config-a" },
    { id: "c3", fromNodeId: "video-a", toNodeId: "config-a" },
    { id: "c4", fromNodeId: "audio-a", toNodeId: "config-a" },
];

describe("canvas resource references", () => {
    it("labels images, videos, audio, and text without dropping target audio support", () => {
        expect(buildCanvasResourceReferences(nodes, connections).map((item) => [item.nodeId, item.kind, item.label, item.active])).toEqual([
            ["image-a", "image", "图片1", false],
            ["text-a", "text", "文本1", false],
            ["video-a", "video", "视频1", false],
            ["audio-a", "audio", "音频1", false],
        ]);
    });

    it("marks resources active using the config node input order", () => {
        expect(buildNodeMentionReferences(nodes[4]!, nodes, connections).map((item) => [item.nodeId, item.kind, item.label, item.active])).toEqual([
            ["audio-a", "audio", "音频1", true],
            ["text-a", "text", "文本1", true],
            ["image-a", "image", "图片1", true],
            ["video-a", "video", "视频1", true],
        ]);
    });

    it("uses inputOrder for generation resource ordering", () => {
        expect(getGenerationResourceNodes("config-a", nodes, connections).map((item) => item.id)).toEqual(["audio-a", "text-a", "image-a", "video-a"]);
    });
});
```

- [ ] **Step 2: Write composer generation tests**

Create `E:\GitDownload\infinite-canvas\web\src\app\(user)\canvas\components\canvas-node-generation.test.ts`:

```ts
import { describe, expect, it } from "vitest";

import { buildNodeGenerationContext, hydrateReferenceImages } from "./canvas-node-generation";
import { CanvasNodeType, type CanvasConnection, type CanvasNodeData } from "../types";
import type { ReferenceImage } from "@/types/image";

const reference = (image: Partial<ReferenceImage> = {}): ReferenceImage => ({
    id: "image-1",
    name: "reference.png",
    type: "image/png",
    dataUrl: "blob:http://localhost/stale",
    storageKey: "image:missing",
    ...image,
});

function node(id: string, type: CanvasNodeType, metadata: CanvasNodeData["metadata"] = {}): CanvasNodeData {
    return { id, type, title: id, position: { x: 0, y: 0 }, width: 100, height: 100, metadata };
}

const baseNodes: CanvasNodeData[] = [
    node("image-a", CanvasNodeType.Image, { content: "data:image/png;base64,a", mimeType: "image/png" }),
    node("text-a", CanvasNodeType.Text, { content: "一段构图说明" }),
    node("video-a", CanvasNodeType.Video, { content: "blob:http://localhost/video", mimeType: "video/mp4" }),
    node("audio-a", CanvasNodeType.Audio, { content: "blob:http://localhost/audio", mimeType: "audio/mpeg" }),
];

const connectToConfig = (config: CanvasNodeData): { nodes: CanvasNodeData[]; connections: CanvasConnection[] } => ({
    nodes: [...baseNodes, config],
    connections: [
        { id: "c1", fromNodeId: "image-a", toNodeId: config.id },
        { id: "c2", fromNodeId: "text-a", toNodeId: config.id },
        { id: "c3", fromNodeId: "video-a", toNodeId: config.id },
        { id: "c4", fromNodeId: "audio-a", toNodeId: config.id },
    ],
});

describe("buildNodeGenerationContext", () => {
    it("keeps upstream text, image, video, and audio references without composer content", () => {
        const config = node("config-a", CanvasNodeType.Config, { inputOrder: ["text-a", "image-a", "video-a", "audio-a"] });
        const { nodes, connections } = connectToConfig(config);

        const context = buildNodeGenerationContext("config-a", nodes, connections, "生成一张海报");

        expect(context.prompt).toBe("生成一张海报\n\n一段构图说明");
        expect(context.referenceImages.map((image) => image.id)).toEqual(["image-a"]);
        expect(context.referenceVideos.map((video) => video.id)).toEqual(["video-a"]);
        expect(context.referenceAudios.map((audio) => audio.id)).toEqual(["audio-a"]);
        expect(context.textCount).toBe(1);
        expect(context.imageCount).toBe(1);
        expect(context.videoCount).toBe(1);
        expect(context.audioCount).toBe(1);
    });

    it("uses config composer content instead of caller fallback prompt", () => {
        const config = node("config-a", CanvasNodeType.Config, {
            composerContent: "按照 @[node:image-a] 的姿势生成",
            prompt: "旧提示词不应该额外拼接",
        });
        const { nodes, connections } = connectToConfig(config);

        const context = buildNodeGenerationContext("config-a", nodes, connections, "调用方旧提示词");

        expect(context.prompt).toBe("按照 图片1 的姿势生成");
        expect(context.referenceImages.map((image) => image.id)).toEqual(["image-a"]);
    });

    it("turns text tokens into labeled text blocks", () => {
        const config = node("config-a", CanvasNodeType.Config, { composerContent: "参考 @[node:text-a] 改写成短句" });
        const { nodes, connections } = connectToConfig(config);

        const context = buildNodeGenerationContext("config-a", nodes, connections, "ignored");

        expect(context.prompt).toBe("参考 【文本1】 改写成短句\n\n【文本1】\n一段构图说明");
        expect(context.referenceImages).toEqual([]);
        expect(context.textCount).toBe(1);
    });

    it("keeps stale node tokens instead of deleting user content", () => {
        const config = node("config-a", CanvasNodeType.Config, { composerContent: "保留 @[node:missing] 并参考 @[node:image-a]" });
        const { nodes, connections } = connectToConfig(config);

        const context = buildNodeGenerationContext("config-a", nodes, connections, "ignored");

        expect(context.prompt).toBe("保留 @[node:missing] 并参考 图片1");
        expect(context.referenceImages.map((image) => image.id)).toEqual(["image-a"]);
    });

    it("uses inputOrder for stable image labels", () => {
        const imageB = node("image-b", CanvasNodeType.Image, { content: "data:image/png;base64,b", mimeType: "image/png" });
        const config = node("config-a", CanvasNodeType.Config, { composerContent: "先看 @[node:image-a] 再看 @[node:image-b]", inputOrder: ["image-b", "image-a"] });
        const nodes = [baseNodes[0]!, imageB, config];
        const connections: CanvasConnection[] = [
            { id: "c1", fromNodeId: "image-a", toNodeId: "config-a" },
            { id: "c2", fromNodeId: "image-b", toNodeId: "config-a" },
        ];

        const context = buildNodeGenerationContext("config-a", nodes, connections, "ignored");

        expect(context.prompt).toBe("先看 图片2 再看 图片1");
        expect(context.referenceImages.map((image) => image.id)).toEqual(["image-a", "image-b"]);
    });

    it("turns video and audio tokens into prompt labels without image references", () => {
        const config = node("config-a", CanvasNodeType.Config, { composerContent: "延续 @[node:video-a] 的运镜和 @[node:audio-a] 的节奏" });
        const { nodes, connections } = connectToConfig(config);

        const context = buildNodeGenerationContext("config-a", nodes, connections, "ignored");

        expect(context.prompt).toBe("延续 视频1 的运镜和 音频1 的节奏");
        expect(context.referenceImages).toEqual([]);
        expect(context.referenceVideos.map((video) => video.id)).toEqual(["video-a"]);
        expect(context.referenceAudios.map((audio) => audio.id)).toEqual(["audio-a"]);
    });
});

describe("hydrateReferenceImages", () => {
    it("rejects missing reference images instead of returning empty data urls", async () => {
        await expect(hydrateReferenceImages([reference()], async () => "")).rejects.toThrow("参考图片已丢失");
    });

    it("keeps hydrated reference images when a data url is available", async () => {
        const hydrated = await hydrateReferenceImages([reference()], async () => "data:image/png;base64,xxx");

        expect(hydrated).toEqual([{ ...reference(), dataUrl: "data:image/png;base64,xxx" }]);
    });
});
```

- [ ] **Step 3: Run tests to verify failure**

Run:

```powershell
cd E:\GitDownload\infinite-canvas\web
bun run test:run "src/app/(user)/canvas/utils/canvas-resource-references.test.ts" "src/app/(user)/canvas/components/canvas-node-generation.test.ts"
```

Expected:

- Resource ordering test fails because `inputOrder` is not applied.
- Composer tests fail because composer content is not used, stale tokens are dropped, and `hydrateReferenceImages` is not exported.

- [ ] **Step 4: Add inputOrder type**

Modify `CanvasNodeMetadata` in `E:\GitDownload\infinite-canvas\web\src\app\(user)\canvas\types.ts`:

```ts
export type CanvasNodeMetadata = {
    content?: string;
    composerContent?: string;
    prompt?: string;
    inputOrder?: string[];
    status?: CanvasNodeStatus;
```

Keep the rest of the existing metadata fields unchanged.

- [ ] **Step 5: Apply inputOrder without removing audio**

Replace `getContextResourceNodes` in `canvas-resource-references.ts`:

```ts
function getContextResourceNodes(nodeId: string, nodes: CanvasNodeData[], connections: CanvasConnection[]) {
    const target = nodes.find((node) => node.id === nodeId);
    const upstreamNodes = connections
        .filter((connection) => connection.toNodeId === nodeId)
        .map((connection) => nodes.find((node) => node.id === connection.fromNodeId))
        .filter((node): node is CanvasNodeData => Boolean(node && isResourceNode(node)));
    const order = target?.metadata?.inputOrder ?? [];
    return [
        ...order.map((id) => upstreamNodes.find((node) => node.id === id)).filter((node): node is CanvasNodeData => Boolean(node)),
        ...upstreamNodes.filter((node) => !order.includes(node.id)),
    ];
}
```

Keep `CanvasResourceKind = "image" | "video" | "audio" | "text"` and keep `seedanceReferenceLabel("audio", index)`.

- [ ] **Step 6: Fix composer generation source and labels**

In `buildNodeGenerationContext`, replace the composer branch with:

```ts
const composerContent = sourceNode?.type === CanvasNodeType.Config ? sourceNode.metadata?.composerContent : undefined;
if (composerContent?.trim()) return buildComposerGenerationContext(inputs, composerContent);
```

Replace `buildComposerGenerationContext` with:

```ts
function buildComposerGenerationContext(inputs: NodeGenerationInput[], prompt: string): NodeGenerationContext {
    const inputByNodeId = new Map(inputs.map((input) => [input.nodeId, input]));
    const labelByNodeId = buildGenerationLabels(inputs);
    const selectedNodeIds = new Set<string>();
    const selectedInputs: NodeGenerationInput[] = [];
    const textBlocks: string[] = [];
    let hasToken = false;
    let lastIndex = 0;
    let nextPrompt = "";
    let textCount = 0;

    for (const match of prompt.matchAll(/@\[node:([^\]]+)\]/g)) {
        if (match.index === undefined) continue;
        hasToken = true;
        nextPrompt += prompt.slice(lastIndex, match.index);
        const input = inputByNodeId.get(match[1]);
        const label = input ? labelByNodeId.get(input.nodeId) : undefined;
        if (!input || !label) {
            nextPrompt += match[0];
            lastIndex = match.index + match[0].length;
            continue;
        }

        if (!selectedNodeIds.has(input.nodeId)) {
            selectedNodeIds.add(input.nodeId);
            if (input.type === "text") {
                textCount += 1;
                textBlocks.push(`【${label}】\n${input.text || ""}`);
            } else {
                selectedInputs.push(input);
            }
        }
        nextPrompt += input.type === "text" ? `【${label}】` : label;
        lastIndex = match.index + match[0].length;
    }

    nextPrompt += prompt.slice(lastIndex);
    if (!hasToken) {
        return {
            prompt,
            referenceImages: [],
            referenceVideos: [],
            referenceAudios: [],
            textCount: 0,
            imageCount: 0,
            videoCount: 0,
            audioCount: 0,
        };
    }
    if (textBlocks.length) nextPrompt = `${nextPrompt.trim()}\n\n${textBlocks.join("\n\n")}`;
    const referenceImages = selectedInputs.map((input) => input.image).filter((image): image is ReferenceImage => Boolean(image));
    const referenceVideos = selectedInputs.map((input) => input.video).filter((video): video is ReferenceVideo => Boolean(video));
    const referenceAudios = selectedInputs.map((input) => input.audio).filter((audio): audio is ReferenceAudio => Boolean(audio));
    return {
        prompt: nextPrompt,
        referenceImages,
        referenceVideos,
        referenceAudios,
        textCount,
        imageCount: referenceImages.length,
        videoCount: referenceVideos.length,
        audioCount: referenceAudios.length,
    };
}
```

Add:

```ts
function buildGenerationLabels(inputs: NodeGenerationInput[]) {
    const counts: { [Kind in NodeGenerationInput["type"]]: number } = { image: 0, video: 0, audio: 0, text: 0 };
    const labels = new Map<string, string>();
    inputs.forEach((input) => {
        labels.set(input.nodeId, generationLabel(input.type, counts[input.type]));
        counts[input.type] += 1;
    });
    return labels;
}
```

- [ ] **Step 7: Add image hydration guard export**

Modify `hydrateNodeGenerationContext` and add `hydrateReferenceImages`:

```ts
export async function hydrateNodeGenerationContext(context: NodeGenerationContext) {
    const { imageToDataUrl } = await import("@/services/image-storage");
    return { ...context, referenceImages: await hydrateReferenceImages(context.referenceImages, imageToDataUrl) };
}

export async function hydrateReferenceImages(referenceImages: ReferenceImage[], imageToDataUrl: (image: ReferenceImage) => Promise<string>) {
    return Promise.all(
        referenceImages.map(async (image) => {
            const dataUrl = await imageToDataUrl(image);
            if (!dataUrl) throw new Error("参考图片已丢失，无法继续生成");
            return { ...image, dataUrl };
        }),
    );
}
```

- [ ] **Step 8: Run P1 tests**

Run:

```powershell
cd E:\GitDownload\infinite-canvas\web
bun run test:run "src/app/(user)/canvas/utils/canvas-resource-references.test.ts" "src/app/(user)/canvas/components/canvas-node-generation.test.ts" "src/app/(user)/canvas/components/canvas-resource-mention-textarea.test.ts"
```

Expected: all P1 tests pass.

- [ ] **Step 9: Commit P1 resource behavior**

Run:

```powershell
git -C E:\GitDownload\infinite-canvas add "web/src/app/(user)/canvas/types.ts" "web/src/app/(user)/canvas/utils/canvas-resource-references.ts" "web/src/app/(user)/canvas/utils/canvas-resource-references.test.ts" "web/src/app/(user)/canvas/components/canvas-node-generation.ts" "web/src/app/(user)/canvas/components/canvas-node-generation.test.ts"
git -C E:\GitDownload\infinite-canvas commit -m "feat: preserve canvas resource references"
```

---

## Task 5: P4 Backend Asset Model and Routes

**Files:**
- Modify: `E:\GitDownload\infinite-canvas\model\asset.go`
- Modify: `E:\GitDownload\infinite-canvas\repository\asset.go`
- Create: `E:\GitDownload\infinite-canvas\repository\asset_test.go`
- Modify: `E:\GitDownload\infinite-canvas\service\assets.go`
- Create: `E:\GitDownload\infinite-canvas\service\assets_test.go`
- Modify: `E:\GitDownload\infinite-canvas\handler\assets.go`
- Modify: `E:\GitDownload\infinite-canvas\router\router.go`

- [ ] **Step 1: Write service validation tests**

Create `E:\GitDownload\infinite-canvas\service\assets_test.go`:

```go
package service

import (
	"strings"
	"testing"

	"github.com/basketikun/infinite-canvas/model"
)

func TestNormalizeAssetForSaveDefaultsPublicText(t *testing.T) {
	item, err := normalizeAssetForSave(model.Asset{Title: "Prompt", Content: "hello"}, "2026-06-09T00:00:00Z")
	if err != nil {
		t.Fatal(err)
	}
	if item.Type != model.AssetTypeText {
		t.Fatalf("Type = %q", item.Type)
	}
	if item.Visibility != model.AssetVisibilityPublic {
		t.Fatalf("Visibility = %q", item.Visibility)
	}
	if item.CreatedAt != "2026-06-09T00:00:00Z" || item.UpdatedAt != "2026-06-09T00:00:00Z" {
		t.Fatalf("timestamps not defaulted: %#v", item)
	}
}

func TestNormalizeAssetForSaveRejectsImageWithoutURL(t *testing.T) {
	_, err := normalizeAssetForSave(model.Asset{Title: "Image", Type: model.AssetTypeImage}, "2026-06-09T00:00:00Z")
	if err == nil || !strings.Contains(err.Error(), "图片素材需要 url") {
		t.Fatalf("err = %v", err)
	}
}

func TestNormalizeAssetForSaveAcceptsVideoMetadata(t *testing.T) {
	item, err := normalizeAssetForSave(model.Asset{
		Title:      "Video",
		Type:       model.AssetTypeVideo,
		URL:        "https://example.test/video.mp4",
		MimeType:   "video/mp4",
		Bytes:      120,
		Width:      1280,
		Height:     720,
		DurationMs: 6000,
	}, "2026-06-09T00:00:00Z")
	if err != nil {
		t.Fatal(err)
	}
	if item.CoverURL != "https://example.test/video.mp4" {
		t.Fatalf("CoverURL = %q", item.CoverURL)
	}
}
```

- [ ] **Step 2: Write repository visibility tests**

Create `E:\GitDownload\infinite-canvas\repository\asset_test.go`:

```go
package repository

import (
	"sync"
	"testing"

	"github.com/basketikun/infinite-canvas/config"
	"github.com/basketikun/infinite-canvas/model"
)

func resetTestDB(t *testing.T) {
	t.Helper()
	previousConfig := config.Cfg
	previousDB := db
	previousOnce := dbOnce
	previousErr := dbErr
	t.Cleanup(func() {
		config.Cfg = previousConfig
		db = previousDB
		dbOnce = previousOnce
		dbErr = previousErr
	})
	config.Cfg = config.Config{StorageDriver: "sqlite", DatabaseDSN: ":memory:"}
	db = nil
	dbOnce = sync.Once{}
	dbErr = nil
	if _, err := DB(); err != nil {
		t.Fatal(err)
	}
}

func TestListAssetsForUserShowsPublicAndOwnPrivate(t *testing.T) {
	resetTestDB(t)
	_, _ = SaveAsset(model.Asset{ID: "public", Title: "Public", Type: model.AssetTypeText, Visibility: model.AssetVisibilityPublic, CreatedAt: "1", UpdatedAt: "1"})
	_, _ = SaveAsset(model.Asset{ID: "own", Title: "Own", Type: model.AssetTypeText, OwnerID: "u1", Visibility: model.AssetVisibilityPrivate, CreatedAt: "2", UpdatedAt: "2"})
	_, _ = SaveAsset(model.Asset{ID: "other", Title: "Other", Type: model.AssetTypeText, OwnerID: "u2", Visibility: model.AssetVisibilityPrivate, CreatedAt: "3", UpdatedAt: "3"})

	items, _, err := ListAssetsForUser(model.Query{PageSize: 20}, "u1")
	if err != nil {
		t.Fatal(err)
	}
	got := []string{}
	for _, item := range items {
		got = append(got, item.ID)
	}
	want := []string{"own", "public"}
	if len(got) != len(want) || got[0] != want[0] || got[1] != want[1] {
		t.Fatalf("items = %#v, want %#v", got, want)
	}
}

func TestDeleteUserAssetOnlyDeletesOwnerAsset(t *testing.T) {
	resetTestDB(t)
	_, _ = SaveAsset(model.Asset{ID: "own", Title: "Own", Type: model.AssetTypeText, OwnerID: "u1", Visibility: model.AssetVisibilityPrivate, CreatedAt: "1", UpdatedAt: "1"})
	_, _ = SaveAsset(model.Asset{ID: "other", Title: "Other", Type: model.AssetTypeText, OwnerID: "u2", Visibility: model.AssetVisibilityPrivate, CreatedAt: "2", UpdatedAt: "2"})

	if err := DeleteUserAsset("other", "u1"); err == nil {
		t.Fatal("expected owner-scoped delete to fail")
	}
	if err := DeleteUserAsset("own", "u1"); err != nil {
		t.Fatal(err)
	}
}
```

- [ ] **Step 3: Run backend tests to verify failure**

Run:

```powershell
cd E:\GitDownload\infinite-canvas
go test ./service ./repository
```

Expected: fails because the new model constants and functions do not exist.

- [ ] **Step 4: Extend asset model**

Modify `E:\GitDownload\infinite-canvas\model\asset.go`:

```go
type AssetType string

const (
	AssetTypeText  AssetType = "text"
	AssetTypeImage AssetType = "image"
	AssetTypeVideo AssetType = "video"
)

type AssetVisibility string

const (
	AssetVisibilityPublic  AssetVisibility = "public"
	AssetVisibilityPrivate AssetVisibility = "private"
)

type Asset struct {
	ID          string          `json:"id" gorm:"primaryKey"`
	OwnerID     string          `json:"ownerId,omitempty" gorm:"index"`
	Visibility  AssetVisibility `json:"visibility"`
	Title       string          `json:"title"`
	Type        AssetType       `json:"type"`
	CoverURL    string          `json:"coverUrl"`
	Tags        []string        `json:"tags" gorm:"serializer:json"`
	Category    string          `json:"category"`
	Description string          `json:"description"`
	Content     string          `json:"content,omitempty" gorm:"type:text"`
	URL         string          `json:"url,omitempty"`
	MimeType    string          `json:"mimeType,omitempty"`
	Bytes       int64           `json:"bytes,omitempty"`
	Width       int             `json:"width,omitempty"`
	Height      int             `json:"height,omitempty"`
	DurationMs  int             `json:"durationMs,omitempty"`
	CreatedAt   string          `json:"createdAt"`
	UpdatedAt   string          `json:"updatedAt"`
}
```

Keep `AssetList` unchanged.

- [ ] **Step 5: Add repository user filters and owner delete**

In `E:\GitDownload\infinite-canvas\repository\asset.go`, add:

```go
func ListAssetsForUser(q model.Query, userID string) ([]model.Asset, int64, error) {
	db, err := DB()
	if err != nil {
		return nil, 0, err
	}
	q.Normalize()
	tx := applyAssetVisibility(applyAssetFilters(db.Model(&model.Asset{}), q), userID)

	var total int64
	if err := tx.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	var items []model.Asset
	err = tx.Order("updated_at desc").Offset(q.Offset()).Limit(q.PageSize).Find(&items).Error
	return items, total, err
}

func DeleteUserAsset(id string, userID string) error {
	db, err := DB()
	if err != nil {
		return err
	}
	result := db.Delete(&model.Asset{}, "id = ? AND owner_id = ?", id, userID)
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return errors.New("素材不存在或无权删除")
	}
	return nil
}

func applyAssetVisibility(tx *gorm.DB, userID string) *gorm.DB {
	if userID == "" {
		return tx.Where("visibility = ? OR visibility = ''", model.AssetVisibilityPublic)
	}
	return tx.Where("visibility = ? OR visibility = '' OR owner_id = ?", model.AssetVisibilityPublic, userID)
}
```

Change existing `ListAssets` to call `ListAssetsForUser(q, "")` or keep its current body and apply `applyAssetVisibility(tx, "")`; either way unauthenticated users must only see public/legacy assets.

- [ ] **Step 6: Add service validation and user operations**

Modify `E:\GitDownload\infinite-canvas\service\assets.go` with helper and user functions:

```go
func SaveUserAsset(userID string, item model.Asset) (model.Asset, error) {
	item.OwnerID = userID
	item.Visibility = model.AssetVisibilityPrivate
	return SaveAsset(item)
}

func DeleteUserAsset(userID string, id string) error {
	return repository.DeleteUserAsset(id, userID)
}

func normalizeAssetForSave(item model.Asset, now string) (model.Asset, error) {
	if item.Type == "" {
		item.Type = model.AssetTypeText
	}
	if item.Visibility == "" {
		item.Visibility = model.AssetVisibilityPublic
	}
	if item.ID == "" {
		item.ID = newID("asset")
		item.CreatedAt = now
	}
	if item.CreatedAt == "" {
		item.CreatedAt = now
	}
	item.UpdatedAt = now
	if item.Title == "" {
		return item, errors.New("素材标题不能为空")
	}
	if item.Type == model.AssetTypeImage && item.URL == "" {
		return item, errors.New("图片素材需要 url")
	}
	if item.Type == model.AssetTypeVideo && item.URL == "" {
		return item, errors.New("视频素材需要 url")
	}
	if item.CoverURL == "" {
		item.CoverURL = assetCoverURL(item)
	}
	return item, nil
}
```

Add `errors` import and change `SaveAsset` to use the helper:

```go
func SaveAsset(item model.Asset) (model.Asset, error) {
	normalized, err := normalizeAssetForSave(item, time.Now().Format(time.RFC3339))
	if err != nil {
		return model.Asset{}, err
	}
	return repository.SaveAsset(normalized)
}
```

Update cover logic:

```go
func assetCoverURL(item model.Asset) string {
	if item.CoverURL != "" {
		return item.CoverURL
	}
	if item.Type == model.AssetTypeImage || item.Type == model.AssetTypeVideo {
		return item.URL
	}
	return ""
}
```

- [ ] **Step 7: Add user asset handlers**

In `E:\GitDownload\infinite-canvas\handler\assets.go`, add:

```go
func SaveAsset(w http.ResponseWriter, r *http.Request) {
	user, ok := service.UserFromContext(r.Context())
	if !ok {
		Fail(w, "请先登录")
		return
	}
	var item model.Asset
	_ = json.NewDecoder(r.Body).Decode(&item)
	result, err := service.SaveUserAsset(user.ID, item)
	if err != nil {
		FailError(w, err)
		return
	}
	OK(w, result)
}

func DeleteAsset(w http.ResponseWriter, r *http.Request, id string) {
	user, ok := service.UserFromContext(r.Context())
	if !ok {
		Fail(w, "请先登录")
		return
	}
	if err := service.DeleteUserAsset(user.ID, id); err != nil {
		FailError(w, err)
		return
	}
	OK(w, true)
}
```

Change `Assets` to include authenticated user private assets when optional auth succeeds:

```go
func Assets(w http.ResponseWriter, r *http.Request) {
	userID := ""
	if user, ok := service.UserFromContext(r.Context()); ok {
		userID = user.ID
	}
	result, err := service.ListAssetsForUser(parseQuery(r), userID)
	if err != nil {
		FailError(w, err)
		return
	}
	OK(w, result)
}
```

Add service wrapper:

```go
func ListAssetsForUser(q model.Query, userID string) (model.AssetList, error) {
	items, total, err := repository.ListAssetsForUser(q, userID)
	if err != nil {
		return model.AssetList{}, err
	}
	tags, err := repository.ListAssetTags(q)
	if err != nil {
		return model.AssetList{}, err
	}
	return model.AssetList{Items: items, Tags: tags, Total: int(total)}, nil
}
```

- [ ] **Step 8: Add target-native user asset routes**

Modify `E:\GitDownload\infinite-canvas\router\router.go` near the existing public asset route:

```go
api.GET("/assets", middleware.OptionalAuth, gin.WrapF(handler.Assets))
api.POST("/assets", middleware.UserAuth, gin.WrapF(handler.SaveAsset))
api.DELETE("/assets/:id", middleware.UserAuth, func(c *gin.Context) {
	handler.DeleteAsset(c.Writer, c.Request, c.Param("id"))
})
```

Keep existing admin asset routes unchanged.

- [ ] **Step 9: Run backend asset tests**

Run:

```powershell
cd E:\GitDownload\infinite-canvas
go test ./service ./repository
```

Expected: tests pass.

- [ ] **Step 10: Commit P4 backend assets**

Run:

```powershell
git -C E:\GitDownload\infinite-canvas add model/asset.go repository/asset.go repository/asset_test.go service/assets.go service/assets_test.go handler/assets.go router/router.go
git -C E:\GitDownload\infinite-canvas commit -m "feat: add user asset persistence"
```

---

## Task 6: P4 Frontend Asset Persistence

**Files:**
- Modify: `E:\GitDownload\infinite-canvas\web\src\services\api\assets.ts`
- Modify: `E:\GitDownload\infinite-canvas\web\src\stores\use-asset-store.ts`
- Create: `E:\GitDownload\infinite-canvas\web\src\services\api\assets.test.ts`

- [ ] **Step 1: Write API path tests**

Create `E:\GitDownload\infinite-canvas\web\src\services\api\assets.test.ts`:

```ts
import { beforeEach, describe, expect, it, vi } from "vitest";

const apiGet = vi.fn();
const apiPost = vi.fn();
const apiDelete = vi.fn();

vi.mock("@/services/api/request", () => ({
    apiGet,
    apiPost,
    apiDelete,
    compactApiParams: (params: Record<string, unknown>) => params,
}));

describe("asset APIs", () => {
    beforeEach(() => {
        vi.clearAllMocks();
    });

    it("fetches assets from the target native assets route", async () => {
        apiGet.mockResolvedValueOnce({ items: [], tags: [], total: 0 });
        const { fetchAssetLibrary } = await import("./assets");

        await fetchAssetLibrary({ keyword: "cat" });

        expect(apiGet).toHaveBeenCalledWith("/api/assets", { keyword: "cat" });
    });

    it("creates user assets on the user assets route", async () => {
        apiPost.mockResolvedValueOnce({ id: "asset-1" });
        const { createAsset } = await import("./assets");

        await createAsset({ title: "Video", type: "video", url: "https://example.test/v.mp4" }, "token-a");

        expect(apiPost).toHaveBeenCalledWith("/api/assets", { title: "Video", type: "video", url: "https://example.test/v.mp4" }, "token-a");
    });

    it("deletes user assets on the user assets route", async () => {
        apiDelete.mockResolvedValueOnce(true);
        const { deleteAsset } = await import("./assets");

        await deleteAsset("asset-1", "token-a");

        expect(apiDelete).toHaveBeenCalledWith("/api/assets/asset-1", "token-a");
    });
});
```

- [ ] **Step 2: Run API tests to verify failure**

Run:

```powershell
cd E:\GitDownload\infinite-canvas\web
bun run test:run src/services/api/assets.test.ts
```

Expected: fails because `createAsset` and `deleteAsset` do not exist.

- [ ] **Step 3: Add asset API functions**

Modify `E:\GitDownload\infinite-canvas\web\src\services\api\assets.ts`:

```ts
import { apiDelete, apiGet, apiPost, compactApiParams } from "@/services/api/request";
```

Extend item type:

```ts
export type AssetLibraryItem = {
    id: string;
    ownerId?: string;
    visibility?: "public" | "private";
    title: string;
    type: "text" | "image" | "video";
    coverUrl: string;
    tags: string[];
    category: string;
    description: string;
    content: string;
    url: string;
    mimeType?: string;
    bytes?: number;
    width?: number;
    height?: number;
    durationMs?: number;
    createdAt: string;
    updatedAt: string;
};
```

Add payload and functions:

```ts
export type SaveAssetPayload = Partial<Omit<AssetLibraryItem, "id" | "createdAt" | "updatedAt">> & {
    title: string;
    type: AssetLibraryItem["type"];
};

export async function createAsset(payload: SaveAssetPayload, token: string) {
    return apiPost<AssetLibraryItem>("/api/assets", payload, token);
}

export async function deleteAsset(id: string, token: string) {
    return apiDelete<boolean>(`/api/assets/${encodeURIComponent(id)}`, token);
}
```

- [ ] **Step 4: Add backend persistence to asset store**

Modify imports in `E:\GitDownload\infinite-canvas\web\src\stores\use-asset-store.ts`:

```ts
import { createAsset, deleteAsset } from "@/services/api/assets";
import { useUserStore } from "@/stores/use-user-store";
```

In `addAsset`, after local state update, trigger backend save when token exists:

```ts
const token = useUserStore.getState().token;
if (token) {
    void createAsset(createAssetToLibraryPayload({ ...asset, id, createdAt: now, updatedAt: now } as Asset), token);
}
```

Use this helper in the same file:

```ts
function createAssetToLibraryPayload(asset: Asset) {
    if (asset.kind === "text") {
        return {
            title: asset.title,
            type: "text" as const,
            coverUrl: asset.coverUrl,
            tags: asset.tags,
            category: asset.source || "",
            description: asset.note || "",
            content: asset.data.content,
        };
    }
    if (asset.kind === "image") {
        return {
            title: asset.title,
            type: "image" as const,
            coverUrl: asset.coverUrl,
            tags: asset.tags,
            category: asset.source || "",
            description: asset.note || "",
            url: asset.data.dataUrl,
            mimeType: asset.data.mimeType,
            bytes: asset.data.bytes,
            width: asset.data.width,
            height: asset.data.height,
        };
    }
    return {
        title: asset.title,
        type: "video" as const,
        coverUrl: asset.coverUrl,
        tags: asset.tags,
        category: asset.source || "",
        description: asset.note || "",
        url: asset.data.url,
        mimeType: asset.data.mimeType,
        bytes: asset.data.bytes,
        width: asset.data.width,
        height: asset.data.height,
    };
}
```

Use the exact helper name in `addAsset`:

```ts
void createAsset(createAssetToLibraryPayload({ ...asset, id, createdAt: now, updatedAt: now } as Asset), token);
```

In `removeAsset`, after local cleanup:

```ts
const token = useUserStore.getState().token;
if (token) void deleteAsset(id, token);
```

This keeps localforage as the fallback and does not block UI on backend persistence.

- [ ] **Step 5: Run asset frontend tests**

Run:

```powershell
cd E:\GitDownload\infinite-canvas\web
bun run test:run src/services/api/assets.test.ts
```

Expected: asset API tests pass.

- [ ] **Step 6: Commit P4 frontend assets**

Run:

```powershell
git -C E:\GitDownload\infinite-canvas add web/src/services/api/assets.ts web/src/services/api/assets.test.ts web/src/stores/use-asset-store.ts
git -C E:\GitDownload\infinite-canvas commit -m "feat: persist user assets from canvas"
```

---

## Task 7: P2 API Envelope and Error Boundaries

**Files:**
- Create: `E:\GitDownload\infinite-canvas\web\src\services\api\error-payload.ts`
- Create: `E:\GitDownload\infinite-canvas\web\src\services\api\request.test.ts`
- Modify: `E:\GitDownload\infinite-canvas\web\src\services\api\request.ts`

- [ ] **Step 1: Write strict request tests**

Create `E:\GitDownload\infinite-canvas\web\src\services\api\request.test.ts`:

```ts
import { beforeEach, describe, expect, it, vi } from "vitest";
import axios from "axios";

import { readFileSync } from "node:fs";
import { join } from "node:path";

import { ApiError, apiGet, apiPost } from "./request";

vi.mock("axios", () => ({
    default: {
        request: vi.fn(),
    },
}));

describe("apiRequest target envelope handling", () => {
    beforeEach(() => {
        vi.clearAllMocks();
    });

    it("preserves 401 status and backend message", async () => {
        vi.mocked(axios.request).mockResolvedValueOnce({
            status: 200,
            data: { code: 401, data: null, msg: "请先登录" },
        });

        await expect(apiGet("/api/auth/me")).rejects.toMatchObject({
            name: "ApiError",
            status: 401,
            code: 401,
            message: "请先登录",
        });
    });

    it("preserves 403 status and backend message", async () => {
        vi.mocked(axios.request).mockResolvedValueOnce({
            status: 403,
            data: { code: 403, data: null, msg: "无权访问" },
        });

        const promise = apiGet("/api/assets");

        await expect(promise).rejects.toBeInstanceOf(ApiError);
        await expect(promise).rejects.toMatchObject({
            status: 403,
            code: 403,
            message: "无权访问",
        });
    });

    it("fails closed when an error envelope has an empty msg instead of inventing a fallback", async () => {
        vi.mocked(axios.request).mockResolvedValueOnce({
            status: 200,
            data: { code: 100, data: null, msg: "" },
        });

        await expect(apiGet("/api/auth/me")).rejects.toThrow("api envelope msg must be a non-empty string");
    });

    it("keeps request helpers free of silent fallback expressions", () => {
        const source = readFileSync(join(process.cwd(), "src", "services", "api", "request.ts"), "utf8");

        expect(source).not.toContain("payload.msg ||");
        expect(source).not.toContain("body ?? {}");
        expect(source).not.toContain("params ||");
    });

    it("posts exactly the caller supplied body", async () => {
        const body = { username: "demo", password: "secret" };
        vi.mocked(axios.request).mockResolvedValueOnce({
            status: 200,
            data: { code: 0, data: {}, msg: "ok" },
        });

        await apiPost<Record<string, never>>("/api/auth/login", body);

        expect(vi.mocked(axios.request).mock.calls[0]?.[0]).toMatchObject({ data: body });
    });
});
```

- [ ] **Step 2: Run request tests to verify failure**

Run:

```powershell
cd E:\GitDownload\infinite-canvas\web
bun run test:run src/services/api/request.test.ts
```

Expected: fails because `ApiError` is missing and request code still has silent fallbacks.

- [ ] **Step 3: Add strict payload helpers**

Create `E:\GitDownload\infinite-canvas\web\src\services\api\error-payload.ts`:

```ts
export type ApiErrorPayload = { error?: { message?: string }; msg?: string; code?: number };

const EMPTY_API_MESSAGE_ERROR = "api envelope msg must be a non-empty string";

export function parseErrorPayload(data: unknown): ApiErrorPayload | null {
    if (!data) return null;
    if (typeof data === "string") {
        try {
            return JSON.parse(data) as ApiErrorPayload;
        } catch {
            return null;
        }
    }
    return typeof data === "object" ? (data as ApiErrorPayload) : null;
}

export async function parseErrorPayloadAsync(data: unknown): Promise<ApiErrorPayload | null> {
    if (typeof Blob !== "undefined" && data instanceof Blob) {
        return parseErrorPayload(await data.text());
    }
    return parseErrorPayload(data);
}

export function requireApiMessage(payload: Pick<ApiErrorPayload, "msg">): string {
    if (typeof payload.msg !== "string") throw new Error(EMPTY_API_MESSAGE_ERROR);
    const message = payload.msg.trim();
    if (!message) throw new Error(EMPTY_API_MESSAGE_ERROR);
    return message;
}
```

- [ ] **Step 4: Update request.ts**

Modify imports:

```ts
import axios from "axios";
import { requireApiMessage } from "./error-payload";
```

Add exports:

```ts
export const AUTH_ERROR_EVENT = "infinite-canvas-auth-error";

export type AuthErrorDetail = {
    status: number;
    message: string;
};

export class ApiError extends Error {
    status: number;
    code: number;

    constructor(message: string, status: number, code: number) {
        super(message);
        this.name = "ApiError";
        this.status = status;
        this.code = code;
    }
}

export function shouldNotifyAuthError(status: number) {
    return status === 401 || status === 403;
}

export function notifyAuthError(status: number, message: string) {
    if (!shouldNotifyAuthError(status)) return;
    if (typeof window === "undefined") return;
    window.dispatchEvent(new CustomEvent<AuthErrorDetail>(AUTH_ERROR_EVENT, { detail: { status, message } }));
}
```

Change `apiPost` signature and data handling:

```ts
export async function apiPost<T>(url: string, body: unknown, token?: string) {
    return apiRequest<T>({
        url,
        method: "POST",
        data: body,
        headers: {
            "Content-Type": "application/json",
            ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
    });
}
```

Change `apiGet` params:

```ts
params,
```

Change error envelope branch:

```ts
if (response.status < 200 || response.status >= 300 || payload.code !== 0) {
    const message = requireApiMessage(payload);
    const status = response.status >= 200 && response.status < 300 ? payload.code : response.status;
    notifyAuthError(status, message);
    throw new ApiError(message, status, payload.code);
}
```

- [ ] **Step 5: Fix zero-argument posts**

Search:

```powershell
rg -n 'apiPost<|apiPost\(' E:\GitDownload\infinite-canvas\web\src
```

For every call that passed no body, pass `{}` explicitly. Example:

```ts
await apiPost<boolean>("/api/auth/logout", {}, token);
```

Expected: request test no longer finds `body ?? {}`.

- [ ] **Step 6: Run request tests**

Run:

```powershell
cd E:\GitDownload\infinite-canvas\web
bun run test:run src/services/api/request.test.ts
```

Expected: request tests pass.

- [ ] **Step 7: Commit P2 request envelope**

Run:

```powershell
git -C E:\GitDownload\infinite-canvas add web/src/services/api/error-payload.ts web/src/services/api/request.ts web/src/services/api/request.test.ts
git -C E:\GitDownload\infinite-canvas commit -m "fix: enforce strict api envelopes"
```

---

## Task 8: P2 Video and Image Error Parsing

**Files:**
- Modify: `E:\GitDownload\infinite-canvas\web\src\services\api\video.ts`
- Create: `E:\GitDownload\infinite-canvas\web\src\services\api\video.test.ts`
- Modify: `E:\GitDownload\infinite-canvas\web\src\services\api\image.ts`

- [ ] **Step 1: Write video error tests**

Create `E:\GitDownload\infinite-canvas\web\src\services\api\video.test.ts`:

```ts
import { beforeEach, describe, expect, it, vi } from "vitest";
import axios from "axios";

import { requestVideoGeneration } from "./video";
import type { AiConfig } from "@/stores/use-config-store";

vi.mock("axios", () => ({
    default: {
        post: vi.fn(),
        get: vi.fn(),
        isAxiosError: (error: unknown) => Boolean(error && typeof error === "object" && "isAxiosError" in error),
    },
}));

vi.mock("@/stores/use-user-store", () => ({
    useUserStore: {
        getState: () => ({ token: "token-a", hydrateUser: vi.fn() }),
    },
}));

const config: AiConfig = {
    channelMode: "remote",
    baseUrl: "",
    apiKey: "",
    model: "grok-imagine-video",
    imageModel: "gpt-image-2",
    videoModel: "grok-imagine-video",
    textModel: "gpt-5.5",
    audioModel: "gpt-4o-mini-tts",
    audioVoice: "alloy",
    audioFormat: "mp3",
    audioSpeed: "1",
    audioInstructions: "",
    videoSeconds: "6",
    vquality: "720",
    videoGenerateAudio: "true",
    videoWatermark: "false",
    systemPrompt: "",
    models: [],
    imageModels: [],
    videoModels: [],
    textModels: [],
    audioModels: [],
    quality: "auto",
    size: "auto",
    count: "1",
    canvasImageCount: "3",
};

describe("requestVideoGeneration errors", () => {
    beforeEach(() => {
        vi.clearAllMocks();
    });

    it("stops before polling when create task returns a failed envelope", async () => {
        vi.mocked(axios.post).mockResolvedValueOnce({ data: { code: 100, data: null, msg: "创建失败" } });

        await expect(requestVideoGeneration(config, "生成视频")).rejects.toThrow("创建失败");
        expect(axios.get).not.toHaveBeenCalled();
    });

    it("rejects empty backend messages instead of inventing a fallback", async () => {
        vi.mocked(axios.post).mockResolvedValueOnce({ data: { code: 100, data: null, msg: "" } });

        await expect(requestVideoGeneration(config, "生成视频")).rejects.toThrow("api envelope msg must be a non-empty string");
    });

    it("reads JSON blob error messages", async () => {
        vi.mocked(axios.post).mockResolvedValueOnce({ data: { id: "task-1", status: "completed" } });
        vi.mocked(axios.get)
            .mockResolvedValueOnce({ data: { id: "task-1", status: "completed" } })
            .mockResolvedValueOnce({ data: new Blob([JSON.stringify({ code: 1, msg: "下载失败" })], { type: "application/json" }) });

        await expect(requestVideoGeneration(config, "生成视频")).rejects.toThrow("下载失败");
    });
});
```

- [ ] **Step 2: Run video tests to verify failure**

Run:

```powershell
cd E:\GitDownload\infinite-canvas\web
bun run test:run src/services/api/video.test.ts
```

Expected: empty message and Blob JSON tests fail.

- [ ] **Step 3: Use strict helpers in video.ts**

Modify imports:

```ts
import { parseErrorPayloadAsync, requireApiMessage } from "@/services/api/error-payload";
```

Change `unwrapEnvelope`:

```ts
function unwrapEnvelope<T>(payload: ApiEnvelope<T>, emptyMessage: string): T {
    if (!payload) throw new Error(emptyMessage);
    if (typeof payload === "object" && "code" in payload && typeof payload.code === "number") {
        if (payload.code !== 0) throw new Error(requireApiMessage(payload));
        if (!payload.data) throw new Error(emptyMessage);
        return payload.data;
    }
    return payload as T;
}
```

Change catch blocks from:

```ts
throw new Error(readAxiosError(error, "视频生成失败"));
```

to:

```ts
throw new Error(await readAxiosError(error, "视频生成失败"));
```

Do the same for Seedance catch.

Change `readAxiosError`:

```ts
async function readAxiosError(error: unknown, fallback: string) {
    if (axios.isAxiosError(error)) {
        const responseData = await parseErrorPayloadAsync(error.response?.data);
        return responseData?.msg?.trim() || responseData?.error?.message || statusMessage(error.response?.status, fallback);
    }
    return error instanceof Error ? error.message : fallback;
}
```

Change `assertVideoBlob`:

```ts
async function assertVideoBlob(blob: Blob) {
    if (!blob.type.includes("json")) return;
    const payload = await parseErrorPayloadAsync(blob);
    if (!payload) return;
    if (typeof payload.code === "number" && payload.code !== 0) throw new Error(requireApiMessage(payload));
    if (payload.error?.message) throw new Error(payload.error.message);
}
```

- [ ] **Step 4: Use strict helpers in image.ts**

Modify imports:

```ts
import { parseErrorPayload, requireApiMessage } from "@/services/api/error-payload";
```

Change `parseImagePayload` error branch:

```ts
if (typeof payload.code === "number" && payload.code !== 0) {
    throw new Error(requireApiMessage(payload));
}
```

Change `readAxiosError`:

```ts
function readAxiosError(error: unknown, fallback: string) {
    if (axios.isAxiosError(error)) {
        const responseData = parseErrorPayload(error.response?.data);
        return responseData?.msg?.trim() || responseData?.error?.message || readStatusError(error.response?.status, fallback);
    }
    return error instanceof Error ? error.message : fallback;
}
```

For `requestImageQuestion`, when parsing response text as JSON envelope, use `requireApiMessage(payload)` for non-zero code.

- [ ] **Step 5: Run P2 tests**

Run:

```powershell
cd E:\GitDownload\infinite-canvas\web
bun run test:run src/services/api/request.test.ts src/services/api/video.test.ts
```

Expected: P2 tests pass.

- [ ] **Step 6: Commit P2 generation error parsing**

Run:

```powershell
git -C E:\GitDownload\infinite-canvas add web/src/services/api/video.ts web/src/services/api/video.test.ts web/src/services/api/image.ts
git -C E:\GitDownload\infinite-canvas commit -m "fix: surface generation api errors"
```

---

## Task 9: P3 Backend Auth Codes and Logout Route

**Files:**
- Modify: `E:\GitDownload\infinite-canvas\handler\response.go`
- Modify: `E:\GitDownload\infinite-canvas\middleware\admin.go`
- Modify: `E:\GitDownload\infinite-canvas\handler\auth.go`
- Modify: `E:\GitDownload\infinite-canvas\router\router.go`

- [ ] **Step 1: Add coded failure helper**

Modify `E:\GitDownload\infinite-canvas\handler\response.go`:

```go
func FailCode(w http.ResponseWriter, code int, msg string) {
	writeJSON(w, response{Code: code, Data: nil, Msg: msg})
}
```

Keep existing `Fail` unchanged.

- [ ] **Step 2: Return auth-specific codes in middleware**

Modify `AdminAuth`:

```go
func AdminAuth(c *gin.Context) {
	user, ok := authUser(c)
	if !ok {
		handler.FailCode(c.Writer, http.StatusUnauthorized, "请先登录")
		c.Abort()
		return
	}
	if user.Role != model.UserRoleAdmin {
		handler.FailCode(c.Writer, http.StatusForbidden, "权限不足")
		c.Abort()
		return
	}
	c.Request = c.Request.WithContext(service.WithUser(c.Request.Context(), user))
	c.Next()
}
```

Modify `UserAuth`:

```go
func UserAuth(c *gin.Context) {
	user, ok := authUser(c)
	if !ok {
		handler.FailCode(c.Writer, http.StatusUnauthorized, "请先登录")
		c.Abort()
		return
	}
	if user.Role == model.UserRoleGuest {
		handler.FailCode(c.Writer, http.StatusForbidden, "权限不足")
		c.Abort()
		return
	}
	c.Request = c.Request.WithContext(service.WithUser(c.Request.Context(), user))
	c.Next()
}
```

- [ ] **Step 3: Add logout handler**

Add to `E:\GitDownload\infinite-canvas\handler\auth.go`:

```go
func Logout(w http.ResponseWriter, r *http.Request) {
	OK(w, true)
}
```

This is intentionally a target-native no-op because current target sessions are JWT-like bearer tokens without a server-side revocation table.

- [ ] **Step 4: Add logout route**

Modify `E:\GitDownload\infinite-canvas\router\router.go` near auth routes:

```go
api.POST("/auth/logout", middleware.UserAuth, gin.WrapF(handler.Logout))
```

- [ ] **Step 5: Run backend auth-related tests**

Run:

```powershell
cd E:\GitDownload\infinite-canvas
go test ./handler ./service
```

Expected: existing handler and service tests pass.

- [ ] **Step 6: Commit backend auth codes**

Run:

```powershell
git -C E:\GitDownload\infinite-canvas add handler/response.go middleware/admin.go handler/auth.go router/router.go
git -C E:\GitDownload\infinite-canvas commit -m "feat: add auth logout contract"
```

---

## Task 10: P3 Frontend Logout and Auth Error Handling

**Files:**
- Modify: `E:\GitDownload\infinite-canvas\web\src\services\api\auth.ts`
- Modify: `E:\GitDownload\infinite-canvas\web\src\stores\use-user-store.ts`
- Create: `E:\GitDownload\infinite-canvas\web\src\stores\use-user-store.test.ts`
- Modify: `E:\GitDownload\infinite-canvas\web\src\components\layout\user-status-actions.tsx`
- Modify: `E:\GitDownload\infinite-canvas\web\src\app\(admin)\admin\layout.tsx`
- Modify: `E:\GitDownload\infinite-canvas\web\src\components\layout\client-root-init.tsx`

- [ ] **Step 1: Write logout sequencing tests**

Create `E:\GitDownload\infinite-canvas\web\src\stores\use-user-store.test.ts`:

```ts
import { beforeEach, describe, expect, it, vi } from "vitest";

const authUser = {
    id: "user-1",
    username: "demo",
    displayName: "Demo",
    avatarUrl: "",
    role: "user",
    credits: 10,
    createdAt: "2026-06-09T00:00:00Z",
    updatedAt: "2026-06-09T00:00:00Z",
};

describe("useUserStore logout", () => {
    beforeEach(() => {
        vi.resetModules();
        vi.restoreAllMocks();
    });

    it("revokes the backend session before clearing local session", async () => {
        const logoutSession = vi.fn().mockResolvedValue(true);

        vi.doMock("@/services/api/auth", () => ({
            AUTH_TOKEN_KEY: "infinite-canvas-auth-token-v1",
            fetchCurrentUser: vi.fn(),
            login: vi.fn(),
            register: vi.fn(),
            logout: logoutSession,
        }));

        const { useUserStore } = await import("./use-user-store");
        useUserStore.setState({ token: "token-a", user: authUser, isReady: true });

        await useUserStore.getState().logout();

        expect(logoutSession).toHaveBeenCalledWith("token-a");
        expect(useUserStore.getState()).toMatchObject({
            token: "",
            user: null,
            isReady: true,
            isLoading: false,
        });
    });

    it("keeps the browser session when backend logout fails", async () => {
        const logoutSession = vi.fn().mockRejectedValue(new Error("logout failed"));

        vi.doMock("@/services/api/auth", () => ({
            AUTH_TOKEN_KEY: "infinite-canvas-auth-token-v1",
            fetchCurrentUser: vi.fn(),
            login: vi.fn(),
            register: vi.fn(),
            logout: logoutSession,
        }));

        const { useUserStore } = await import("./use-user-store");
        useUserStore.setState({ token: "token-a", user: authUser, isReady: true, isLoading: false });

        await expect(useUserStore.getState().logout()).rejects.toThrow("logout failed");
        expect(useUserStore.getState()).toMatchObject({
            token: "token-a",
            user: authUser,
            isReady: true,
            isLoading: false,
        });
    });
});
```

- [ ] **Step 2: Run logout tests to verify failure**

Run:

```powershell
cd E:\GitDownload\infinite-canvas\web
bun run test:run src/stores/use-user-store.test.ts
```

Expected: fails because the store has no `logout` action and auth API has no logout function.

- [ ] **Step 3: Add auth API logout**

Modify `E:\GitDownload\infinite-canvas\web\src\services\api\auth.ts`:

```ts
export async function logout(token: string) {
    return apiPost<boolean>("/api/auth/logout", {}, token);
}
```

- [ ] **Step 4: Add store logout action**

Modify import:

```ts
import { AUTH_TOKEN_KEY, fetchCurrentUser, login, logout, register, type AuthPayload, type AuthUser } from "@/services/api/auth";
```

Extend `UserStore`:

```ts
logout: () => Promise<void>;
```

Add action:

```ts
logout: async () => {
    const token = get().token;
    if (!token) {
        set({ token: "", user: null, isReady: true, isLoading: false });
        return;
    }
    set({ isLoading: true });
    try {
        await logout(token);
        set({ token: "", user: null, isReady: true, isLoading: false });
    } catch (error) {
        set({ isLoading: false });
        throw error;
    }
},
```

Keep `clearSession` for forced local cleanup after auth errors.

- [ ] **Step 5: Use logout in user menu and admin layout**

In `E:\GitDownload\infinite-canvas\web\src\components\layout\user-status-actions.tsx`, change:

```ts
const logout = useUserStore((state) => state.clearSession);
```

to:

```ts
const logout = useUserStore((state) => state.logout);
```

In `E:\GitDownload\infinite-canvas\web\src\app\(admin)\admin\layout.tsx`, change:

```ts
const logout = useUserStore((state) => state.clearSession);
```

to:

```ts
const logout = useUserStore((state) => state.logout);
```

- [ ] **Step 6: Listen to auth error event**

Modify imports in `E:\GitDownload\infinite-canvas\web\src\components\layout\client-root-init.tsx`:

```ts
import { AUTH_ERROR_EVENT, type AuthErrorDetail } from "@/services/api/request";
```

Add store action:

```ts
const clearSession = useUserStore((state) => state.clearSession);
```

Add effect:

```tsx
useEffect(() => {
    const listener = (event: Event) => {
        const detail = (event as CustomEvent<AuthErrorDetail>).detail;
        clearSession();
        if (!isLoginPage) message.error(detail?.message || "登录状态已失效，请重新登录");
    };
    window.addEventListener(AUTH_ERROR_EVENT, listener);
    return () => window.removeEventListener(AUTH_ERROR_EVENT, listener);
}, [clearSession, isLoginPage, message]);
```

- [ ] **Step 7: Run P3 frontend tests**

Run:

```powershell
cd E:\GitDownload\infinite-canvas\web
bun run test:run src/stores/use-user-store.test.ts src/services/api/request.test.ts
```

Expected: logout and request tests pass.

- [ ] **Step 8: Commit P3 frontend auth**

Run:

```powershell
git -C E:\GitDownload\infinite-canvas add web/src/services/api/auth.ts web/src/stores/use-user-store.ts web/src/stores/use-user-store.test.ts web/src/components/layout/user-status-actions.tsx "web/src/app/(admin)/admin/layout.tsx" web/src/components/layout/client-root-init.tsx
git -C E:\GitDownload\infinite-canvas commit -m "feat: call backend logout before clearing session"
```

---

## Task 11: Documentation Updates

**Files:**
- Modify: `E:\GitDownload\infinite-canvas\docs\content\docs\backend\api-response.mdx`
- Modify: `E:\GitDownload\infinite-canvas\docs\content\docs\backend\backend-database.mdx`
- Modify: `E:\GitDownload\infinite-canvas\docs\content\docs\progress\todo.mdx`
- Modify: `E:\GitDownload\infinite-canvas\docs\content\docs\progress\pending-test.mdx`

- [ ] **Step 1: Update API response docs**

In `api-response.mdx`, add after the frontend handling paragraph:

```md
鉴权失败仍使用统一 JSON 包裹。需要登录时 `code` 为 `401`，权限不足时 `code` 为 `403`；前端请求层会把这两类响应转换为认证错误事件，并清理失效的本地登录态。

前端不再为失败响应编造兜底消息。后端失败响应的 `msg` 必须是非空字符串；如果为空，前端会按接口契约错误处理。
```

- [ ] **Step 2: Update database docs for assets**

In the `assets` table section of `backend-database.mdx`, update the field table to include:

```md
| `owner_id` | string | 用户私有素材所属用户 ID，公开素材为空 |
| `visibility` | string | 可见性：`public`、`private`；历史空值按公开素材处理 |
| `mime_type` | string | 媒体 MIME |
| `bytes` | number | 媒体大小 |
| `width` | number | 图片或视频宽度 |
| `height` | number | 图片或视频高度 |
| `duration_ms` | number | 视频时长，毫秒 |
```

Keep the existing public asset library description and mention that admin-created assets default to public.

- [ ] **Step 3: Update progress docs**

In `pending-test.mdx`, add a concise bullet group:

```md
- Canvas 增强迁移：文本节点和生成配置输入的 `@资源` 高亮应保持完整高度，`图片1`、`视频1`、`音频1`、`文本1` 编号按当前输入顺序稳定显示；删除或失效的旧节点 token 会保留在用户文本中。
- 素材持久化增强：登录用户保存“我的素材”时会同时尝试写入后端 `/api/assets`，未登录或后端失败时仍保留本地素材；公开素材库和管理后台素材功能保持可用。
- API 与登录行为增强：失败响应必须带非空 `msg`，401/403 会清理失效登录态；点击退出登录会先请求 `/api/auth/logout`，成功后再清理本地 session。
```

In `todo.mdx`, only remove items that are fully implemented by this plan. If a listed item still needs real browser or provider verification, keep it in `pending-test.mdx` rather than deleting it.

- [ ] **Step 4: Commit documentation**

Run:

```powershell
git -C E:\GitDownload\infinite-canvas add docs/content/docs/backend/api-response.mdx docs/content/docs/backend/backend-database.mdx docs/content/docs/progress/todo.mdx docs/content/docs/progress/pending-test.mdx
git -C E:\GitDownload\infinite-canvas commit -m "docs: document canvas extraction changes"
```

---

## Task 12: Final Verification and Handoff

**Files:**
- Verify: `E:\GitDownload\infinite-canvas`
- Verify: `E:\admin_go`

- [ ] **Step 1: Run targeted frontend tests**

Run:

```powershell
cd E:\GitDownload\infinite-canvas\web
bun run test:run src/lib/image-reference-prompt.test.ts src/lib/image-utils.test.ts src/services/storage-fallback.test.ts "src/app/(user)/canvas/components/canvas-resource-mention-textarea.test.ts" "src/app/(user)/canvas/utils/canvas-resource-references.test.ts" "src/app/(user)/canvas/components/canvas-node-generation.test.ts" src/services/api/assets.test.ts src/services/api/request.test.ts src/services/api/video.test.ts src/stores/use-user-store.test.ts
```

Expected: all targeted frontend tests pass.

- [ ] **Step 2: Run targeted backend tests**

Run:

```powershell
cd E:\GitDownload\infinite-canvas
go test ./handler ./service ./repository
```

Expected: all targeted backend tests pass.

- [ ] **Step 3: Verify no target route drift**

Run:

```powershell
rg -n 'canvas/v1|agent_id|login-config|slide captcha|RBAC' E:\GitDownload\infinite-canvas -g '!web/node_modules'
```

Expected: no newly introduced implementation dependency on source-only auth, RBAC, captcha, or agent contracts. Existing documentation mentions should be reviewed manually if any appear.

- [ ] **Step 4: Verify target git diff is cleanly formatted**

Run:

```powershell
git -C E:\GitDownload\infinite-canvas diff --check
git -C E:\GitDownload\infinite-canvas status --short
```

Expected:

- `diff --check` has no whitespace errors.
- `status --short` is clean after commits, or contains only intentionally uncommitted files explicitly listed in the handoff.

- [ ] **Step 5: Verify admin_go governance for plan-only repo change**

Run from `E:\admin_go`:

```powershell
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected: both pass.

- [ ] **Step 6: Final handoff summary**

Report:

- Commits created in `E:\GitDownload\infinite-canvas`.
- Targeted frontend and backend test commands with pass/fail result.
- Any browser-only checks left in `pending-test.mdx`.
- Explicit note that target-native `/api/auth`, `/api/v1`, `/api/assets`, and `/api/admin/assets` contracts were preserved.

---

## Self-Review

### Spec coverage

- P0 Vitest and pure safety utilities are covered by Tasks 1 and 2.
- P1 mention textarea height, `@资源` highlight, resource labels, input order, composer source, stale token preservation, and audio preservation are covered by Tasks 3 and 4.
- P4 asset backend and frontend persistence is covered by Tasks 5 and 6.
- P2 strict API envelope and video/image error boundaries are covered by Tasks 7 and 8.
- P3 logout and auth state behavior is covered by Tasks 9 and 10.
- Target docs and final verification are covered by Tasks 11 and 12.

### Placeholder scan

- No open-ended placeholders are required for implementation.
- Every code-changing task names exact files and gives concrete code blocks or commands.
- The plan avoids source-only admin auth, RBAC, captcha, and hosted agent contracts as target dependencies.

### Type consistency

- Frontend asset API uses target `type: "text" | "image" | "video"` and does not remove audio node support.
- Canvas resource types keep `audio` in node references and generation context.
- Backend asset visibility uses `public` / `private`; admin assets default public, user assets default private.
- Request errors use `ApiError`, `AUTH_ERROR_EVENT`, and strict `requireApiMessage` consistently.
