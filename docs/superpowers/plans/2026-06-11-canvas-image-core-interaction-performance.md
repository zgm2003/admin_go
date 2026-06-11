# Canvas Image Core Interaction Performance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Canvas image generation deterministic and fast for the two core user nodes: text nodes and image nodes.

**Architecture:** Centralize generation context in pure helpers, then make UI and generation calls consume the same helper output. The first slice fixes behavior (`connection = context`, image self/upstream merge, target does not drift), and the second slice reduces needless context work for large canvases without changing the backend contract.

**Tech Stack:** Next 16.2.3, React 19.2.5, TypeScript, Vitest, Zustand, Ant Design, Canvas `/api/canvas/v1/ai/images*` with backend-owned `agent_id`.

---

## Source spec and boundaries

Spec: `E:/admin_go/docs/superpowers/specs/2026-06-11-canvas-image-core-interaction-performance-design.md`

Main workspace: `E:/admin_go/canvas_front_next`

Project role: `frontend-adapter`

Preserve the current dirty WIP in `canvas_front_next`; do not reset or overwrite it:

```text
src/app/(user)/canvas/components/canvas-composer-layout.test.ts
src/app/(user)/canvas/components/canvas-node-prompt-panel.tsx
src/app/(user)/canvas/components/canvas-resource-mention-textarea.test.ts
src/app/(user)/canvas/components/canvas-resource-mention-textarea.tsx
src/app/(user)/canvas/components/infinite-canvas.tsx
src/app/(user)/canvas/utils/canvas-merge-import.test.ts
src/app/(user)/canvas/utils/canvas-merge-import.ts
```

## File structure

### Create

- `E:/admin_go/canvas_front_next/src/app/(user)/canvas/utils/canvas-interaction-target.ts` — target resolution rules.
- `E:/admin_go/canvas_front_next/src/app/(user)/canvas/utils/canvas-interaction-target.test.ts` — target priority tests.
- `E:/admin_go/canvas_front_next/src/app/(user)/canvas/components/canvas-generation-context-summary.tsx` — presentational summary for connected text/images.
- `E:/admin_go/canvas_front_next/src/app/(user)/canvas/components/canvas-generation-context-summary.test.tsx` — server-rendered summary tests.
- `E:/admin_go/canvas_front_next/tests/shared/canvas-image-core-interaction-performance.test.ts` — source guards for page-level integration constraints.

### Modify

- `E:/admin_go/canvas_front_next/src/app/(user)/canvas/components/canvas-node-generation.ts` — image context builder, composer auto-inclusion, image de-duplication.
- `E:/admin_go/canvas_front_next/src/app/(user)/canvas/components/canvas-node-generation.test.ts` — RED tests for context behavior.
- `E:/admin_go/canvas_front_next/src/app/(user)/canvas/utils/canvas-resource-references.ts` — connection graph helper with compatible public APIs.
- `E:/admin_go/canvas_front_next/src/app/(user)/canvas/utils/canvas-resource-references.test.ts` — graph/order tests.
- `E:/admin_go/canvas_front_next/src/app/(user)/canvas/components/canvas-node-prompt-panel.tsx` — render context summary.
- `E:/admin_go/canvas_front_next/src/app/(user)/canvas/components/canvas-config-node-panel.tsx` — render context summary.
- `E:/admin_go/canvas_front_next/src/app/(user)/canvas/[id]/canvas-client-page.tsx` — target helper, image context helper, lazy mention refs.

---

## Task 0: WIP safety checkpoint

**Files:**
- Inspect only: `E:/admin_go/canvas_front_next`

- [ ] **Step 1: Capture current child-repo WIP before editing**

Run:

```powershell
cd E:/admin_go/canvas_front_next
git status --short
git diff --stat
```

Expected: output includes the seven existing WIP files listed in this plan. Keep that output in implementation notes.

- [ ] **Step 2: Confirm root repo status**

Run:

```powershell
cd E:/admin_go
git status --short
```

Expected: root repo is clean unless a later task intentionally changes docs.

---

## Task 1: Context builder RED tests for connection-as-context

**Files:**
- Modify: `E:/admin_go/canvas_front_next/src/app/(user)/canvas/components/canvas-node-generation.test.ts`
- Modify later: `E:/admin_go/canvas_front_next/src/app/(user)/canvas/components/canvas-node-generation.ts`

- [ ] **Step 1: Add failing tests**

Update the import:

```ts
import { buildImageGenerationContext, buildNodeGenerationContext, generationReferenceUrls, hydrateReferenceImages } from "./canvas-node-generation";
```

Append these tests inside `describe("buildNodeGenerationContext", () => { ... })`:

```ts
it("uses connected inputs when config composer content has no explicit @ tokens", () => {
    const config = node("config-a", CanvasNodeType.Config, { composerContent: "生成电影感角色海报", inputOrder: ["text-a", "image-a"] });
    const { nodes, connections } = connectToConfig(config);

    const context = buildNodeGenerationContext("config-a", nodes, connections, "ignored");

    expect(context.prompt).toBe("生成电影感角色海报\n\n一段构图说明");
    expect(context.referenceImages.map((image) => image.id)).toEqual(["image-a"]);
    expect(context.textCount).toBe(1);
    expect(context.imageCount).toBe(1);
});

it("keeps connected text even when composer @ tokens select only images", () => {
    const config = node("config-a", CanvasNodeType.Config, { composerContent: "参考 @[node:image-a] 的色彩", inputOrder: ["image-a", "text-a"] });
    const { nodes, connections } = connectToConfig(config);

    const context = buildNodeGenerationContext("config-a", nodes, connections, "ignored");

    expect(context.prompt).toBe("参考 图片1 的色彩\n\n【文本1】\n一段构图说明");
    expect(context.referenceImages.map((image) => image.id)).toEqual(["image-a"]);
    expect(context.textCount).toBe(1);
    expect(context.imageCount).toBe(1);
});
```

Append this top-level block at the end of the file:

```ts
describe("buildImageGenerationContext", () => {
    it("merges a target image with connected text and upstream images", () => {
        const target = node("image-target", CanvasNodeType.Image, { content: "data:image/png;base64,target", mimeType: "image/png" });
        const upstreamImage = node("image-upstream", CanvasNodeType.Image, { content: "data:image/png;base64,upstream", mimeType: "image/png" });
        const upstreamText = node("text-upstream", CanvasNodeType.Text, { content: "把人物放在黄昏街道" });
        const nodes = [target, upstreamImage, upstreamText];
        const connections: CanvasConnection[] = [
            { id: "c1", fromNodeId: "image-upstream", toNodeId: "image-target" },
            { id: "c2", fromNodeId: "text-upstream", toNodeId: "image-target" },
        ];

        const context = buildImageGenerationContext({ nodeId: "image-target", nodes, connections, prompt: "改成电影感", includeSelfImage: true });

        expect(context.prompt).toBe("改成电影感\n\n把人物放在黄昏街道");
        expect(context.referenceImages.map((image) => image.id)).toEqual(["image-target", "image-upstream"]);
        expect(context.selfImageCount).toBe(1);
        expect(context.upstreamImageCount).toBe(1);
        expect(context.upstreamTextCount).toBe(1);
        expect(context.summary).toEqual({ mode: "image-to-image", labels: ["自身图片", "图片1", "文本1"] });
    });

    it("deduplicates the target image when it is also connected through another path", () => {
        const target = node("image-target", CanvasNodeType.Image, { content: "data:image/png;base64,target", mimeType: "image/png" });
        const nodes = [target];
        const connections: CanvasConnection[] = [{ id: "c1", fromNodeId: "image-target", toNodeId: "image-target" }];

        const context = buildImageGenerationContext({ nodeId: "image-target", nodes, connections, prompt: "继续细化", includeSelfImage: true });

        expect(context.referenceImages.map((image) => image.id)).toEqual(["image-target"]);
        expect(context.imageCount).toBe(1);
    });
});
```

- [ ] **Step 2: Run the tests to verify RED**

Run:

```powershell
cd E:/admin_go/canvas_front_next
npm run test -- "src/app/(user)/canvas/components/canvas-node-generation.test.ts"
```

Expected: FAIL. The first failure should mention `buildImageGenerationContext` is not exported or composer content without `@` returns no connected inputs.

---

## Task 2: Implement context builder GREEN

**Files:**
- Modify: `E:/admin_go/canvas_front_next/src/app/(user)/canvas/components/canvas-node-generation.ts`
- Test: `E:/admin_go/canvas_front_next/src/app/(user)/canvas/components/canvas-node-generation.test.ts`

- [ ] **Step 1: Add image context types**

Add these exported types after `NodeGenerationContext`:

```ts
export type ImageGenerationContextSummary = {
    mode: "text-to-image" | "image-to-image";
    labels: string[];
};

export type ImageGenerationContext = NodeGenerationContext & {
    selfImageCount: number;
    upstreamImageCount: number;
    upstreamTextCount: number;
    summary: ImageGenerationContextSummary;
};

export type BuildImageGenerationContextInput = {
    nodeId: string;
    nodes: CanvasNodeData[];
    connections: CanvasConnection[];
    prompt: string;
    includeSelfImage: boolean;
};
```

- [ ] **Step 2: Add shared assembly helpers**

Replace the non-composer body in `buildNodeGenerationContext()` with `return buildInputsGenerationContext(inputs, prompt);`, then add:

```ts
function buildInputsGenerationContext(inputs: NodeGenerationInput[], prompt: string): NodeGenerationContext {
    const textBlocks = inputs.map((input) => input.text).filter((text): text is string => Boolean(text));
    const referenceImages = inputs.map((input) => input.image).filter((image): image is ReferenceImage => Boolean(image));
    const referenceVideos = inputs.map((input) => input.video).filter((video): video is ReferenceVideo => Boolean(video));
    const referenceAudios = inputs.map((input) => input.audio).filter((audio): audio is ReferenceAudio => Boolean(audio));

    return {
        prompt: appendTextBlocks(prompt, textBlocks),
        referenceImages,
        referenceVideos,
        referenceAudios,
        textCount: textBlocks.length,
        imageCount: referenceImages.length,
        videoCount: referenceVideos.length,
        audioCount: referenceAudios.length,
    };
}

function appendTextBlocks(prompt: string, textBlocks: string[]) {
    const cleanedPrompt = prompt.trim();
    const cleanedText = textBlocks.map((text) => text.trim()).filter(Boolean);
    if (!cleanedText.length) return cleanedPrompt;
    return cleanedPrompt ? `${cleanedPrompt}\n\n${cleanedText.join("\n\n")}` : cleanedText.join("\n\n");
}
```

- [ ] **Step 3: Change composer logic to auto-include connected inputs**

Replace the tail of `buildComposerGenerationContext()` from `nextPrompt += prompt.slice(lastIndex);` through its return with:

```ts
    nextPrompt += prompt.slice(lastIndex);

    if (!hasToken) return buildInputsGenerationContext(inputs, prompt);

    const remainingInputs = inputs.filter((input) => !selectedNodeIds.has(input.nodeId));
    remainingInputs.forEach((input) => {
        selectedNodeIds.add(input.nodeId);
        if (input.type === "text") {
            textCount += 1;
            const label = labelByNodeId.get(input.nodeId) ?? `文本${textCount}`;
            textBlocks.push(`【${label}】\n${input.text}`);
            return;
        }
        selectedInputs.push(input);
    });

    if (textBlocks.length) nextPrompt = `${nextPrompt.trim()}\n\n${textBlocks.join("\n\n")}`;
    const selectedImages = dedupeReferenceImages(selectedInputs.map((input) => input.image).filter((image): image is ReferenceImage => Boolean(image)));
    const selectedVideos = selectedInputs.map((input) => input.video).filter((video): video is ReferenceVideo => Boolean(video));
    const selectedAudios = selectedInputs.map((input) => input.audio).filter((audio): audio is ReferenceAudio => Boolean(audio));
    return {
        prompt: nextPrompt.trim(),
        referenceImages: selectedImages,
        referenceVideos: selectedVideos,
        referenceAudios: selectedAudios,
        textCount,
        imageCount: selectedImages.length,
        videoCount: selectedVideos.length,
        audioCount: selectedAudios.length,
    };
```

Add this helper:

```ts
function dedupeReferenceImages(images: ReferenceImage[]) {
    const seen = new Set<string>();
    return images.filter((image) => {
        const key = image.id || image.storageKey || image.dataUrl;
        if (seen.has(key)) return false;
        seen.add(key);
        return true;
    });
}
```

- [ ] **Step 4: Add `buildImageGenerationContext()`**

Add after `buildNodeGenerationInputs()`:

```ts
export function buildImageGenerationContext({ nodeId, nodes, connections, prompt, includeSelfImage }: BuildImageGenerationContextInput): ImageGenerationContext {
    const baseContext = buildNodeGenerationContext(nodeId, nodes, connections, prompt);
    const sourceNode = nodes.find((node) => node.id === nodeId);
    const selfImage = includeSelfImage && sourceNode ? readReferenceImage(sourceNode) : null;
    const mergedImages = dedupeReferenceImages([...(selfImage ? [selfImage] : []), ...baseContext.referenceImages]);
    const upstreamImageCount = mergedImages.filter((image) => image.id !== sourceNode?.id).length;
    const selfImageCount = selfImage && mergedImages.some((image) => image.id === selfImage.id) ? 1 : 0;
    const labels = buildImageContextLabels({ textCount: baseContext.textCount, selfImageCount, upstreamImageCount });

    return {
        ...baseContext,
        referenceImages: mergedImages,
        imageCount: mergedImages.length,
        selfImageCount,
        upstreamImageCount,
        upstreamTextCount: baseContext.textCount,
        summary: {
            mode: mergedImages.length ? "image-to-image" : "text-to-image",
            labels,
        },
    };
}

function buildImageContextLabels({ textCount, selfImageCount, upstreamImageCount }: { textCount: number; selfImageCount: number; upstreamImageCount: number }) {
    const labels: string[] = [];
    if (selfImageCount) labels.push("自身图片");
    for (let index = 0; index < upstreamImageCount; index += 1) labels.push(imageReferenceLabel(index));
    for (let index = 0; index < textCount; index += 1) labels.push(`文本${index + 1}`);
    return labels;
}
```

- [ ] **Step 5: Run GREEN tests**

Run:

```powershell
cd E:/admin_go/canvas_front_next
npm run test -- "src/app/(user)/canvas/components/canvas-node-generation.test.ts"
```

Expected: PASS.

- [ ] **Step 6: Commit tests and implementation**

Run:

```powershell
cd E:/admin_go/canvas_front_next
git add "src/app/(user)/canvas/components/canvas-node-generation.ts" "src/app/(user)/canvas/components/canvas-node-generation.test.ts"
git commit -m "feat(canvas): merge connected inputs for image generation"
```

If unrelated child-repo WIP should remain uncommitted, commit only these two paths.

---

## Task 3: Explicit target helper RED/GREEN

**Files:**
- Create: `E:/admin_go/canvas_front_next/src/app/(user)/canvas/utils/canvas-interaction-target.ts`
- Create: `E:/admin_go/canvas_front_next/src/app/(user)/canvas/utils/canvas-interaction-target.test.ts`

- [ ] **Step 1: Write failing target priority tests**

Create `canvas-interaction-target.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { resolveCanvasInteractionTarget } from "./canvas-interaction-target";

describe("resolveCanvasInteractionTarget", () => {
    it("uses explicit node id first", () => {
        expect(resolveCanvasInteractionTarget({ explicitNodeId: "button-node", dialogNodeId: "panel-node", selectedNodeIds: ["selected-node"], hoveredNodeId: "hover-node" })).toBe("button-node");
    });

    it("uses dialog node before selected and hovered nodes", () => {
        expect(resolveCanvasInteractionTarget({ dialogNodeId: "panel-node", selectedNodeIds: ["selected-node"], hoveredNodeId: "hover-node" })).toBe("panel-node");
    });

    it("uses a single selected node before hover", () => {
        expect(resolveCanvasInteractionTarget({ selectedNodeIds: ["selected-node"], hoveredNodeId: "hover-node" })).toBe("selected-node");
    });

    it("ignores hover when multiple nodes are selected", () => {
        expect(resolveCanvasInteractionTarget({ selectedNodeIds: ["a", "b"], hoveredNodeId: "hover-node" })).toBeNull();
    });

    it("uses hover only when allowed and no stronger target exists", () => {
        expect(resolveCanvasInteractionTarget({ selectedNodeIds: [], hoveredNodeId: "hover-node", includeHover: true })).toBe("hover-node");
    });
});
```

- [ ] **Step 2: Run RED**

Run:

```powershell
cd E:/admin_go/canvas_front_next
npm run test -- "src/app/(user)/canvas/utils/canvas-interaction-target.test.ts"
```

Expected: FAIL with module not found for `./canvas-interaction-target`.

- [ ] **Step 3: Implement helper**

Create `canvas-interaction-target.ts`:

```ts
export type CanvasInteractionTargetInput = {
    explicitNodeId?: string | null;
    dialogNodeId?: string | null;
    selectedNodeIds?: Iterable<string> | null;
    hoveredNodeId?: string | null;
    includeHover?: boolean;
};

export function resolveCanvasInteractionTarget({ explicitNodeId, dialogNodeId, selectedNodeIds, hoveredNodeId, includeHover = false }: CanvasInteractionTargetInput) {
    if (explicitNodeId) return explicitNodeId;
    if (dialogNodeId) return dialogNodeId;
    const selected = selectedNodeIds ? Array.from(selectedNodeIds) : [];
    if (selected.length === 1) return selected[0] ?? null;
    if (selected.length > 1) return null;
    return includeHover ? hoveredNodeId || null : null;
}
```

- [ ] **Step 4: Run GREEN**

Run:

```powershell
cd E:/admin_go/canvas_front_next
npm run test -- "src/app/(user)/canvas/utils/canvas-interaction-target.test.ts"
```

Expected: PASS.

- [ ] **Step 5: Commit helper**

Run:

```powershell
cd E:/admin_go/canvas_front_next
git add "src/app/(user)/canvas/utils/canvas-interaction-target.ts" "src/app/(user)/canvas/utils/canvas-interaction-target.test.ts"
git commit -m "feat(canvas): resolve interaction target priority"
```

---

## Task 4: Integrate image context and target helper into Canvas page

**Files:**
- Modify: `E:/admin_go/canvas_front_next/src/app/(user)/canvas/[id]/canvas-client-page.tsx`
- Create: `E:/admin_go/canvas_front_next/tests/shared/canvas-image-core-interaction-performance.test.ts`

- [ ] **Step 1: Write failing source guards**

Create `tests/shared/canvas-image-core-interaction-performance.test.ts`:

```ts
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

function source(path: string) {
    return readFileSync(join(process.cwd(), path), "utf8");
}

describe("Canvas image core interaction integration", () => {
    it("uses the image generation context helper instead of replacing upstream references with the source image", () => {
        const page = source("src/app/(user)/canvas/[id]/canvas-client-page.tsx");
        expect(page).toContain("buildImageGenerationContext");
        expect(page).not.toContain("sourceReference.length ? sourceReference : generationContext.referenceImages");
    });

    it("uses resolved interaction target priority instead of hover-first active node selection", () => {
        const page = source("src/app/(user)/canvas/[id]/canvas-client-page.tsx");
        expect(page).toContain("resolveCanvasInteractionTarget");
        expect(page).not.toContain("hoveredNodeId || (selectedNodeIds.size === 1");
    });

    it("limits mention reference computation to relevant nodes", () => {
        const page = source("src/app/(user)/canvas/[id]/canvas-client-page.tsx");
        expect(page).toContain("mentionReferenceNodeIds");
        expect(page).not.toContain("nodes.forEach((node) => map.set(node.id, buildNodeMentionReferences(node, nodes, connections)))");
    });
});
```

- [ ] **Step 2: Run guards to verify RED**

Run:

```powershell
cd E:/admin_go/canvas_front_next
npm run test -- "tests/shared/canvas-image-core-interaction-performance.test.ts"
```

Expected: FAIL because page integration has not changed.

- [ ] **Step 3: Update page imports**

Replace the generation import with:

```ts
import { buildImageGenerationContext, buildNodeChatMessages, buildNodeGenerationContext, buildNodeGenerationInputs, generationReferenceUrls, hydrateNodeGenerationContext, type ImageGenerationContextSummary, type NodeGenerationInput } from "../components/canvas-node-generation";
```

Add:

```ts
import { resolveCanvasInteractionTarget } from "../utils/canvas-interaction-target";
```

- [ ] **Step 4: Replace hover-first active node selection**

Replace:

```ts
const hasMultipleSelectedNodes = selectedNodeIds.size > 1;
const activeNodeId = hasMultipleSelectedNodes ? null : hoveredNodeId || (selectedNodeIds.size === 1 ? Array.from(selectedNodeIds)[0] : null);
```

with:

```ts
const hasMultipleSelectedNodes = selectedNodeIds.size > 1;
const activeNodeId = resolveCanvasInteractionTarget({ dialogNodeId, selectedNodeIds, hoveredNodeId, includeHover: true });
```

- [ ] **Step 5: Use image context before hydration**

Inside `handleGenerateNode`, replace the context-builder call with:

```ts
const requestedPrompt = editingTextNode ? `请根据要求修改以下文本。\n\n原文：\n${sourceTextContent}\n\n修改要求：\n${prompt}` : prompt;
const rawContext =
    mode === "image"
        ? buildImageGenerationContext({ nodeId, nodes: nodesRef.current, connections: connectionsRef.current, prompt: requestedPrompt, includeSelfImage: true })
        : buildNodeGenerationContext(nodeId, nodesRef.current, connectionsRef.current, requestedPrompt);
generationContext = await hydrateNodeGenerationContext(rawContext);
```

- [ ] **Step 6: Remove source-reference replacement**

In the image branch, replace the `sourceReference` block and `referenceImages` assignment with:

```ts
const referenceImages = generationContext.referenceImages;
```

- [ ] **Step 7: Limit mention refs to relevant nodes**

Replace the current `mentionReferencesByNodeId` memo with:

```ts
const mentionReferenceNodeIds = useMemo(() => {
    const ids = new Set<string>();
    visibleNodes.forEach((node) => ids.add(node.id));
    if (dialogNodeId) ids.add(dialogNodeId);
    if (editingNodeId) ids.add(editingNodeId);
    const targetId = resolveCanvasInteractionTarget({ dialogNodeId, selectedNodeIds, hoveredNodeId, includeHover: true });
    if (targetId) ids.add(targetId);
    return ids;
}, [dialogNodeId, editingNodeId, hoveredNodeId, selectedNodeIds, visibleNodes]);

const mentionReferencesByNodeId = useMemo(() => {
    const map = new Map<string, ReturnType<typeof buildNodeMentionReferences>>();
    mentionReferenceNodeIds.forEach((nodeId) => {
        const node = nodeById.get(nodeId);
        if (node) map.set(node.id, buildNodeMentionReferences(node, nodes, connections));
    });
    return map;
}, [connections, mentionReferenceNodeIds, nodeById, nodes]);
```

- [ ] **Step 8: Run integration tests**

Run:

```powershell
cd E:/admin_go/canvas_front_next
npm run test -- "tests/shared/canvas-image-core-interaction-performance.test.ts" "src/app/(user)/canvas/components/canvas-node-generation.test.ts" "src/app/(user)/canvas/utils/canvas-interaction-target.test.ts"
```

Expected: PASS.

- [ ] **Step 9: Commit integration**

Run:

```powershell
cd E:/admin_go/canvas_front_next
git add "src/app/(user)/canvas/[id]/canvas-client-page.tsx" "tests/shared/canvas-image-core-interaction-performance.test.ts"
git commit -m "feat(canvas): use explicit image generation context"
```

---

## Task 5: Add connection indexes without changing public resource APIs

**Files:**
- Modify: `E:/admin_go/canvas_front_next/src/app/(user)/canvas/utils/canvas-resource-references.ts`
- Modify: `E:/admin_go/canvas_front_next/src/app/(user)/canvas/utils/canvas-resource-references.test.ts`

- [ ] **Step 1: Add failing graph tests**

Update the import:

```ts
import { buildCanvasResourceGraph, buildCanvasResourceReferences, buildNodeMentionReferences, getGenerationResourceNodes } from "./canvas-resource-references";
```

Append:

```ts
it("builds a reusable connection index for incoming and outgoing lookups", () => {
    const { incomingByNodeId, outgoingByNodeId, nodeById } = buildCanvasResourceGraph(nodes, connections);
    expect(nodeById.get("config-a")?.id).toBe("config-a");
    expect(incomingByNodeId.get("config-a")?.map((connection) => connection.id)).toEqual(["c1", "c2", "c3", "c4"]);
    expect(outgoingByNodeId.get("image-a")?.map((connection) => connection.id)).toEqual(["c1"]);
});

it("keeps generation resource ordering when using the graph helper", () => {
    const graph = buildCanvasResourceGraph(nodes, connections);
    expect(getGenerationResourceNodes("config-a", nodes, connections, graph).map((item) => item.id)).toEqual(["text-a", "image-a", "audio-a", "video-a"]);
});
```

- [ ] **Step 2: Run RED**

Run:

```powershell
cd E:/admin_go/canvas_front_next
npm run test -- "src/app/(user)/canvas/utils/canvas-resource-references.test.ts"
```

Expected: FAIL because graph helper is not exported.

- [ ] **Step 3: Implement graph helper and optional graph parameter**

Add after `CanvasResourceReference`:

```ts
export type CanvasResourceGraph = {
    nodeById: Map<string, CanvasNodeData>;
    incomingByNodeId: Map<string, CanvasConnection[]>;
    outgoingByNodeId: Map<string, CanvasConnection[]>;
};

export function buildCanvasResourceGraph(nodes: CanvasNodeData[], connections: CanvasConnection[]): CanvasResourceGraph {
    const nodeById = new Map(nodes.map((node) => [node.id, node]));
    const incomingByNodeId = new Map<string, CanvasConnection[]>();
    const outgoingByNodeId = new Map<string, CanvasConnection[]>();

    connections.forEach((connection) => {
        incomingByNodeId.set(connection.toNodeId, [...(incomingByNodeId.get(connection.toNodeId) ?? []), connection]);
        outgoingByNodeId.set(connection.fromNodeId, [...(outgoingByNodeId.get(connection.fromNodeId) ?? []), connection]);
    });

    return { nodeById, incomingByNodeId, outgoingByNodeId };
}
```

Update public functions to accept an optional graph:

```ts
export function getGenerationResourceNodes(nodeId: string, nodes: CanvasNodeData[], connections: CanvasConnection[], graph = buildCanvasResourceGraph(nodes, connections)) {
    const configInputs = getConnectedConfigResourceNodes(nodeId, nodes, connections, graph);
    if (configInputs.length) return configInputs;
    return getContextResourceNodes(nodeId, nodes, connections, graph);
}
```

Apply the same optional `graph = buildCanvasResourceGraph(nodes, connections)` pattern to `buildCanvasResourceReferences`, `buildNodeMentionReferences`, and `getMentionResourceNodes`.

Replace private lookup bodies with graph-based lookups:

```ts
function getContextResourceNodes(nodeId: string, nodes: CanvasNodeData[], connections: CanvasConnection[], graph: CanvasResourceGraph) {
    const target = graph.nodeById.get(nodeId);
    const upstreamNodes = (graph.incomingByNodeId.get(nodeId) ?? [])
        .map((connection) => graph.nodeById.get(connection.fromNodeId))
        .filter((node): node is CanvasNodeData => Boolean(node && isResourceNode(node)));
    const order = target?.metadata?.inputOrder ?? [];
    return [
        ...order.map((id) => upstreamNodes.find((node) => node.id === id)).filter((node): node is CanvasNodeData => Boolean(node)),
        ...upstreamNodes.filter((node) => !order.includes(node.id)),
    ];
}

function getConnectedConfigResourceNodes(nodeId: string, nodes: CanvasNodeData[], connections: CanvasConnection[], graph: CanvasResourceGraph) {
    const configConnection = (graph.outgoingByNodeId.get(nodeId) ?? []).find((connection) => graph.nodeById.get(connection.toNodeId)?.type === CanvasNodeType.Config);
    if (!configConnection) return [];
    return getContextResourceNodes(configConnection.toNodeId, nodes, connections, graph).filter((node) => node.id !== nodeId);
}
```

- [ ] **Step 4: Wire graph helper into Canvas page**

In `canvas-client-page.tsx`, update import:

```ts
import { buildCanvasResourceGraph, buildCanvasResourceReferences, buildNodeMentionReferences } from "../utils/canvas-resource-references";
```

Add after `nodeById`:

```ts
const resourceGraph = useMemo(() => buildCanvasResourceGraph(nodes, connections), [connections, nodes]);
```

Update calls:

```ts
const canvasResourceReferences = useMemo(() => buildCanvasResourceReferences(nodes, connections, resourceContextNodeId, resourceGraph), [connections, nodes, resourceContextNodeId, resourceGraph]);
```

and:

```ts
if (node) map.set(node.id, buildNodeMentionReferences(node, nodes, connections, resourceGraph));
```

- [ ] **Step 5: Run tests**

Run:

```powershell
cd E:/admin_go/canvas_front_next
npm run test -- "src/app/(user)/canvas/utils/canvas-resource-references.test.ts" "src/app/(user)/canvas/components/canvas-node-generation.test.ts" "tests/shared/canvas-image-core-interaction-performance.test.ts"
```

Expected: PASS.

- [ ] **Step 6: Commit graph performance slice**

Run:

```powershell
cd E:/admin_go/canvas_front_next
git add "src/app/(user)/canvas/utils/canvas-resource-references.ts" "src/app/(user)/canvas/utils/canvas-resource-references.test.ts" "src/app/(user)/canvas/[id]/canvas-client-page.tsx"
git commit -m "perf(canvas): index resource connections"
```

---

## Task 6: Add context summary UI

**Files:**
- Create: `E:/admin_go/canvas_front_next/src/app/(user)/canvas/components/canvas-generation-context-summary.tsx`
- Create: `E:/admin_go/canvas_front_next/src/app/(user)/canvas/components/canvas-generation-context-summary.test.tsx`
- Modify: `E:/admin_go/canvas_front_next/src/app/(user)/canvas/components/canvas-node-prompt-panel.tsx`
- Modify: `E:/admin_go/canvas_front_next/src/app/(user)/canvas/components/canvas-config-node-panel.tsx`
- Modify: `E:/admin_go/canvas_front_next/src/app/(user)/canvas/[id]/canvas-client-page.tsx`

- [ ] **Step 1: Write failing summary tests**

Create `canvas-generation-context-summary.test.tsx`:

```tsx
import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import { CanvasGenerationContextSummary } from "./canvas-generation-context-summary";

describe("CanvasGenerationContextSummary", () => {
    it("shows text and reference image counts with connected-context guidance", () => {
        const html = renderToStaticMarkup(createElement(CanvasGenerationContextSummary, { textCount: 1, imageCount: 2, mode: "image-to-image", labels: ["自身图片", "图片1", "文本1"] }));
        expect(html).toContain("文本 1 个");
        expect(html).toContain("参考图 2 张");
        expect(html).toContain("图生图");
        expect(html).toContain("连接会自动生效");
        expect(html).toContain("自身图片");
    });

    it("renders an empty-state hint when there are no connected inputs", () => {
        const html = renderToStaticMarkup(createElement(CanvasGenerationContextSummary, { textCount: 0, imageCount: 0, mode: "text-to-image", labels: [] }));
        expect(html).toContain("未连接文字或图片");
        expect(html).toContain("文生图");
    });
});
```

- [ ] **Step 2: Run RED**

Run:

```powershell
cd E:/admin_go/canvas_front_next
npm run test -- "src/app/(user)/canvas/components/canvas-generation-context-summary.test.tsx"
```

Expected: FAIL because component file does not exist.

- [ ] **Step 3: Implement summary component**

Create `canvas-generation-context-summary.tsx`:

```tsx
import { Image as ImageIcon, Link2, Type } from "lucide-react";
import type { ImageGenerationContextSummary } from "./canvas-node-generation";

export type CanvasGenerationContextSummaryProps = ImageGenerationContextSummary & {
    textCount: number;
    imageCount: number;
};

export function CanvasGenerationContextSummary({ textCount, imageCount, mode, labels }: CanvasGenerationContextSummaryProps) {
    const modeLabel = mode === "image-to-image" ? "图生图" : "文生图";
    return (
        <div className="mb-2 rounded-xl border border-black/10 bg-black/[0.03] px-3 py-2 text-[11px] leading-5 text-current/75 dark:border-white/10 dark:bg-white/[0.04]">
            <div className="flex flex-wrap items-center gap-2">
                <span className="inline-flex items-center gap-1 font-medium"><Link2 className="size-3" />连接会自动生效</span>
                <span className="inline-flex items-center gap-1"><Type className="size-3" />文本 {textCount} 个</span>
                <span className="inline-flex items-center gap-1"><ImageIcon className="size-3" />参考图 {imageCount} 张</span>
                <span className="rounded-full bg-black/10 px-1.5 py-0.5 dark:bg-white/10">{modeLabel}</span>
            </div>
            <div className="mt-1 truncate opacity-70">{labels.length ? `来源：${labels.join("、")}` : "未连接文字或图片，输入提示词后按文生图生成"}</div>
        </div>
    );
}
```

- [ ] **Step 4: Add panel props and render summary**

In `canvas-node-prompt-panel.tsx`, import:

```ts
import { CanvasGenerationContextSummary } from "./canvas-generation-context-summary";
import type { ImageGenerationContextSummary } from "./canvas-node-generation";
```

Add prop:

```ts
generationSummary?: (ImageGenerationContextSummary & { textCount: number; imageCount: number }) | null;
```

Include `generationSummary = null` in function arguments and render above `CanvasResourceMentionTextarea`:

```tsx
{generationSummary ? <CanvasGenerationContextSummary {...generationSummary} /> : null}
```

In `canvas-config-node-panel.tsx`, add the same import/prop and render after the input chips row:

```tsx
{generationSummary ? <CanvasGenerationContextSummary {...generationSummary} /> : null}
```

- [ ] **Step 5: Compute summaries in Canvas page**

Add this memo near `configInputsById`:

```ts
const imageGenerationSummaryById = useMemo(() => {
    const map = new Map<string, ImageGenerationContextSummary & { textCount: number; imageCount: number }>();
    const addSummary = (node: CanvasNodeData) => {
        if (node.type !== CanvasNodeType.Image && node.type !== CanvasNodeType.Config) return;
        const prompt = node.metadata?.composerContent ?? node.metadata?.prompt ?? "";
        const context = buildImageGenerationContext({ nodeId: node.id, nodes, connections, prompt, includeSelfImage: node.type === CanvasNodeType.Image });
        map.set(node.id, { ...context.summary, textCount: context.upstreamTextCount, imageCount: context.imageCount });
    };
    visibleNodes.forEach(addSummary);
    const dialogNode = dialogNodeId ? nodeById.get(dialogNodeId) : null;
    if (dialogNode && !map.has(dialogNode.id)) addSummary(dialogNode);
    return map;
}, [connections, dialogNodeId, nodeById, nodes, visibleNodes]);
```

Pass to both panel components:

```tsx
generationSummary={imageGenerationSummaryById.get(contentNode.id) ?? null}
```

and:

```tsx
generationSummary={imageGenerationSummaryById.get(panelNode.id) ?? null}
```

- [ ] **Step 6: Run summary and integration tests**

Run:

```powershell
cd E:/admin_go/canvas_front_next
npm run test -- "src/app/(user)/canvas/components/canvas-generation-context-summary.test.tsx" "src/app/(user)/canvas/components/canvas-composer-layout.test.ts" "tests/shared/canvas-image-core-interaction-performance.test.ts"
```

Expected: PASS.

- [ ] **Step 7: Commit summary UI**

Run:

```powershell
cd E:/admin_go/canvas_front_next
git add "src/app/(user)/canvas/components/canvas-generation-context-summary.tsx" "src/app/(user)/canvas/components/canvas-generation-context-summary.test.tsx" "src/app/(user)/canvas/components/canvas-node-prompt-panel.tsx" "src/app/(user)/canvas/components/canvas-config-node-panel.tsx" "src/app/(user)/canvas/[id]/canvas-client-page.tsx"
git commit -m "feat(canvas): show image generation context summary"
```

---

## Task 7: Full targeted verification

**Files:**
- Verify: `E:/admin_go/canvas_front_next`
- Verify: `E:/admin_go`

- [ ] **Step 1: Run Canvas targeted tests**

Run:

```powershell
cd E:/admin_go/canvas_front_next
npm run test -- "src/app/(user)/canvas/components/canvas-node-generation.test.ts" "src/app/(user)/canvas/utils/canvas-resource-references.test.ts" "src/app/(user)/canvas/utils/canvas-interaction-target.test.ts" "src/app/(user)/canvas/components/canvas-generation-context-summary.test.tsx" "tests/shared/canvas-image-core-interaction-performance.test.ts"
```

Expected: all listed Vitest files PASS.

- [ ] **Step 2: Run WIP-adjacent tests**

Run:

```powershell
cd E:/admin_go/canvas_front_next
npm run test -- "src/app/(user)/canvas/components/canvas-composer-layout.test.ts" "src/app/(user)/canvas/components/canvas-resource-mention-textarea.test.ts" "src/app/(user)/canvas/utils/canvas-merge-import.test.ts"
```

Expected: PASS, preserving cursor/wheel/merge-anchor WIP behavior.

- [ ] **Step 3: Run typecheck**

Run:

```powershell
cd E:/admin_go/canvas_front_next
npm run typecheck
```

Expected: exit code 0.

- [ ] **Step 4: Run root governance**

Run:

```powershell
cd E:/admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected: `git diff --check` passes. Governance may report warnings if child-repo runtime files are changed without root status docs; review those warnings before final reporting.

- [ ] **Step 5: Review final child-repo diff**

Run:

```powershell
cd E:/admin_go/canvas_front_next
git diff --stat
git status --short
```

Expected: changed files match this plan plus pre-existing WIP. No unrelated files appear.

---

## Task 8: Documentation closeout after implementation evidence exists

**Files:**
- Modify after tests pass: `E:/admin_go/docs/status/current-status.md` or `E:/admin_go/docs/status/known-issues.md`

- [ ] **Step 1: Choose status destination from evidence**

Use this rule:

```text
All targeted tests and typecheck pass -> current-status verified entry.
Any required test or typecheck still fails -> known-issues verification gap entry.
```

- [ ] **Step 2: Add verified status entry if all gates pass**

Insert this entry near the top of `docs/status/current-status.md`:

```markdown
2026-06-11 Canvas image core interaction first slice verified locally: `canvas_front_next` now treats connected text/image nodes as default image-generation context, keeps explicit `@` references as ordering/precision controls instead of a requirement, merges an existing target image with upstream image/text references without dropping either side, resolves generation targets with dialog/selection priority over hover, and avoids rebuilding mention references for every offscreen node. Targeted Canvas generation-context/resource-reference/interaction-target/summary/source-guard Vitest, WIP-adjacent cursor/wheel/merge tests, Canvas typecheck, diff checks, and root governance passed. This does not delete Config/Video/Audio nodes, does not add new Go backend routes, and does not change the `/api/canvas/v1/ai/images*` request contract.
```

- [ ] **Step 3: Add verification gap if gates fail**

If verification is incomplete, add a `CANVAS-IMAGE-CORE-INTERACTION verification gap` entry to `docs/status/known-issues.md`. The entry must include the failed command copied exactly from Task 7 or Step 4 below, the exit code, and up to 20 decisive failure lines from the terminal output. Do not commit a generic template. The boundary text must say:

```text
Do not claim the Canvas image core interaction slice as implemented until the failing command is green. The WIP preserves existing cursor/wheel/merge-anchor changes and must not be flattened into a verified status entry.
```

- [ ] **Step 4: Run docs checks**

Run:

```powershell
cd E:/admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected: exit code 0.

- [ ] **Step 5: Commit root docs if changed**

Run:

```powershell
cd E:/admin_go
git add docs/status/current-status.md docs/status/known-issues.md
git commit -m "docs: record canvas image core interaction verification"
```

Only commit files that actually changed.
