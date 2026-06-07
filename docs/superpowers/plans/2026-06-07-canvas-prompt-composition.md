# Canvas Prompt Composition Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Improve Canvas prompt composition so text/image resources are named and injected predictably without breaking backend-owned `agent_id` Canvas API contracts.

**Architecture:** Keep prompt rules in focused helpers, not in `canvas-client-page.tsx`. Add image reference prompt wrapping, graph-derived resource references, composer token parsing, and lightweight mention/composer UI. Do not add provider/model/client credential overrides or backend video/audio contracts in this slice.

**Tech Stack:** Next 16, React 19, TypeScript, Ant Design, Vitest, Zustand, existing `/api/canvas/v1/*` axios clients.

---

## Source spec

Approved spec: `E:/admin_go/docs/superpowers/specs/2026-06-07-canvas-prompt-composition-design.md`

## File structure

- Create `E:/admin_go/canvas_front_next/src/lib/image-reference-prompt.ts`: image labels and prompt prefixing.
- Create `E:/admin_go/canvas_front_next/src/lib/image-reference-prompt.test.ts`: helper tests.
- Create `E:/admin_go/canvas_front_next/src/app/(user)/canvas/utils/canvas-resource-references.ts`: nodes/connections to resource references and ordered generation resources.
- Create `E:/admin_go/canvas_front_next/src/app/(user)/canvas/utils/canvas-resource-references.test.ts`: graph utility tests.
- Modify `E:/admin_go/canvas_front_next/src/app/(user)/canvas/types.ts`: add optional `composerContent`.
- Modify `E:/admin_go/canvas_front_next/src/app/(user)/canvas/components/canvas-node-generation.ts`: parse composer tokens and preserve legacy behavior.
- Modify `E:/admin_go/canvas_front_next/src/app/(user)/canvas/components/canvas-node-generation.test.ts`: prompt composition tests.
- Create `E:/admin_go/canvas_front_next/src/app/(user)/canvas/components/canvas-config-composer.tsx`: lightweight config-node token editor.
- Modify `E:/admin_go/canvas_front_next/src/app/(user)/canvas/components/canvas-config-node-panel.tsx`: persist `metadata.composerContent`.
- Create `E:/admin_go/canvas_front_next/src/app/(user)/canvas/components/canvas-resource-mention-textarea.tsx`: textarea with `@` menu and resource label highlighting.
- Modify `E:/admin_go/canvas_front_next/src/app/(user)/canvas/components/canvas-node-prompt-panel.tsx`: use resource mention textarea.
- Modify `E:/admin_go/canvas_front_next/src/app/(user)/canvas/components/canvas-node.tsx`: pass mention references into text editing and show resource label badge.
- Modify `E:/admin_go/canvas_front_next/src/app/(user)/canvas/[id]/canvas-client-page.tsx`: compute/pass resource references.
- Modify `E:/admin_go/canvas_front_next/src/services/api/image.ts`: wrap `requestEdit()` prompt.
- Modify `E:/admin_go/canvas_front_next/src/services/api/image.test.ts`: API prompt and contract tests.
- Create `E:/admin_go/canvas_front_next/tests/shared/canvas-prompt-composition.test.ts`: source guards.

---

### Task 1: Add image reference prompt helper

**Files:**
- Create: `src/lib/image-reference-prompt.ts`
- Create: `src/lib/image-reference-prompt.test.ts`

- [ ] **Step 1: Write the failing helper test**

Create `src/lib/image-reference-prompt.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { buildImageReferencePromptText, imageReferenceLabel } from "./image-reference-prompt";
import type { ReferenceImage } from "@/types/image";

const reference = (id: string): ReferenceImage => ({ id, name: `${id}.png`, type: "image/png", dataUrl: `data:image/png;base64,${id}` });

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

- [ ] **Step 2: Run test to verify it fails**

Run from `E:/admin_go/canvas_front_next`:

```powershell
npm run test -- src/lib/image-reference-prompt.test.ts
```

Expected: FAIL with `Cannot find module './image-reference-prompt'`.

- [ ] **Step 3: Implement the helper**

Create `src/lib/image-reference-prompt.ts`:

```ts
import type { ReferenceImage } from "@/types/image";

export function imageReferenceLabel(index: number) {
    return `图片${index + 1}`;
}

export function buildImageReferencePromptText(prompt: string, references: ReferenceImage[]) {
    const text = prompt.trim();
    if (!references.length) return text;
    const labels = references.map((_, index) => imageReferenceLabel(index));
    return `参考图片编号：${labels.join("、")}。请按这些编号理解提示词中的图片引用。\n\n${text}`;
}
```

- [ ] **Step 4: Run test to verify it passes**

```powershell
npm run test -- src/lib/image-reference-prompt.test.ts
```

Expected: PASS.

- [ ] **Step 5: Commit frontend helper**

```powershell
git add src/lib/image-reference-prompt.ts src/lib/image-reference-prompt.test.ts
git commit -m "feat: add canvas image reference prompt helper"
```

---

### Task 2: Add resource reference graph utility

**Files:**
- Create: `src/app/(user)/canvas/utils/canvas-resource-references.ts`
- Create: `src/app/(user)/canvas/utils/canvas-resource-references.test.ts`

- [ ] **Step 1: Write the failing graph utility test**

Create `src/app/(user)/canvas/utils/canvas-resource-references.test.ts`:

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
    node("config-a", CanvasNodeType.Config, { inputOrder: ["text-a", "image-a"] }),
];
const connections: CanvasConnection[] = [
    { id: "c1", fromNodeId: "image-a", toNodeId: "config-a" },
    { id: "c2", fromNodeId: "text-a", toNodeId: "config-a" },
    { id: "c3", fromNodeId: "video-a", toNodeId: "config-a" },
];

describe("canvas resource references", () => {
    it("labels resources without adding unsupported audio resources", () => {
        expect(buildCanvasResourceReferences(nodes, connections).map((item) => [item.nodeId, item.kind, item.label, item.active])).toEqual([
            ["image-a", "image", "图片1", false],
            ["text-a", "text", "文本1", false],
            ["video-a", "video", "视频1", false],
        ]);
    });

    it("marks resources active when they feed the current config node", () => {
        expect(buildNodeMentionReferences(nodes[3]!, nodes, connections).map((item) => [item.nodeId, item.active])).toEqual([
            ["text-a", true],
            ["image-a", true],
            ["video-a", true],
        ]);
    });

    it("uses inputOrder for generation resource ordering", () => {
        expect(getGenerationResourceNodes("config-a", nodes, connections).map((item) => item.id)).toEqual(["text-a", "image-a", "video-a"]);
    });
});
```

- [ ] **Step 2: Run test to verify it fails**

```powershell
npm run test -- "src/app/(user)/canvas/utils/canvas-resource-references.test.ts"
```

Expected: FAIL with `Cannot find module './canvas-resource-references'`.

- [ ] **Step 3: Implement graph utility**

Create `src/app/(user)/canvas/utils/canvas-resource-references.ts`:

```ts
import { imageReferenceLabel } from "@/lib/image-reference-prompt";
import { CanvasNodeType, type CanvasConnection, type CanvasNodeData } from "../types";

export type CanvasResourceKind = "image" | "video" | "text";
export type CanvasResourceReference = { id: string; nodeId: string; kind: CanvasResourceKind; label: string; title: string; previewUrl?: string; text?: string; active: boolean };

export function buildCanvasResourceReferences(nodes: CanvasNodeData[], connections: CanvasConnection[], contextNodeId?: string | null) {
    const contextNodes = contextNodeId ? getMentionResourceNodes(contextNodeId, nodes, connections) : [];
    const activeByNodeId = new Map(labelResourceNodes(contextNodes, true).map((reference) => [reference.nodeId, reference]));
    return labelResourceNodes(nodes.filter(isResourceNode), false).map((reference) => activeByNodeId.get(reference.nodeId) || reference);
}

export function buildNodeMentionReferences(node: CanvasNodeData, nodes: CanvasNodeData[], connections: CanvasConnection[]) {
    return labelResourceNodes(getMentionResourceNodes(node.id, nodes, connections), true);
}

export function getMentionResourceNodes(nodeId: string, nodes: CanvasNodeData[], connections: CanvasConnection[]) {
    const configInputs = getConnectedConfigResourceNodes(nodeId, nodes, connections);
    if (configInputs.length) return configInputs;
    const ownInputs = getContextResourceNodes(nodeId, nodes, connections);
    if (ownInputs.length) return ownInputs;
    const self = nodes.find((item) => item.id === nodeId);
    return self && isResourceNode(self) ? [self] : [];
}

export function getGenerationResourceNodes(nodeId: string, nodes: CanvasNodeData[], connections: CanvasConnection[]) {
    const configInputs = getConnectedConfigResourceNodes(nodeId, nodes, connections);
    if (configInputs.length) return configInputs;
    return getContextResourceNodes(nodeId, nodes, connections);
}

function getContextResourceNodes(nodeId: string, nodes: CanvasNodeData[], connections: CanvasConnection[]) {
    const target = nodes.find((node) => node.id === nodeId);
    const upstreamNodes = connections.filter((connection) => connection.toNodeId === nodeId).map((connection) => nodes.find((node) => node.id === connection.fromNodeId)).filter((node): node is CanvasNodeData => Boolean(node && isResourceNode(node)));
    const order = target?.metadata?.inputOrder || [];
    return [...order.map((id) => upstreamNodes.find((node) => node.id === id)).filter((node): node is CanvasNodeData => Boolean(node)), ...upstreamNodes.filter((node) => !order.includes(node.id))];
}

function getConnectedConfigResourceNodes(nodeId: string, nodes: CanvasNodeData[], connections: CanvasConnection[]) {
    const configConnection = connections.find((connection) => connection.fromNodeId === nodeId && nodes.find((node) => node.id === connection.toNodeId)?.type === CanvasNodeType.Config);
    if (!configConnection) return [];
    return getContextResourceNodes(configConnection.toNodeId, nodes, connections).filter((node) => node.id !== nodeId);
}

function labelResourceNodes(nodes: CanvasNodeData[], active: boolean) {
    const counts: Record<CanvasResourceKind, number> = { image: 0, video: 0, text: 0 };
    return nodes.flatMap((node): CanvasResourceReference[] => {
        const kind = resourceKind(node);
        if (!kind) return [];
        const index = counts[kind]++;
        const label = kind === "image" ? imageReferenceLabel(index) : kind === "video" ? `视频${index + 1}` : `文本${index + 1}`;
        return [{ id: node.id, nodeId: node.id, kind, label, title: node.title || label, previewUrl: node.metadata?.content, text: node.type === CanvasNodeType.Text ? node.metadata?.content || node.metadata?.prompt : undefined, active }];
    });
}

function isResourceNode(node: CanvasNodeData) { return Boolean(resourceKind(node)); }
function resourceKind(node: CanvasNodeData): CanvasResourceKind | null {
    if (node.type === CanvasNodeType.Image && node.metadata?.content) return "image";
    if (node.type === CanvasNodeType.Video && node.metadata?.content) return "video";
    if (node.type === CanvasNodeType.Text && (node.metadata?.content || node.metadata?.prompt)) return "text";
    return null;
}
```

- [ ] **Step 4: Run utility tests**

```powershell
npm run test -- "src/app/(user)/canvas/utils/canvas-resource-references.test.ts"
```

Expected: PASS.

- [ ] **Step 5: Commit graph utility**

```powershell
git add "src/app/(user)/canvas/utils/canvas-resource-references.ts" "src/app/(user)/canvas/utils/canvas-resource-references.test.ts"
git commit -m "feat: add canvas resource reference utility"
```

---

### Task 3: Implement composer-aware generation context

**Files:**
- Modify: `src/app/(user)/canvas/types.ts`
- Modify: `src/app/(user)/canvas/components/canvas-node-generation.ts`
- Modify: `src/app/(user)/canvas/components/canvas-node-generation.test.ts`

- [ ] **Step 1: Replace generation tests with composer coverage**

Replace `src/app/(user)/canvas/components/canvas-node-generation.test.ts` with tests that keep existing hydrate coverage and add these four cases:

```ts
it("keeps legacy upstream text and image behavior when composerContent is absent", () => {
    const nodes = [node("text-1", CanvasNodeType.Text, { content: "写实电影感" }), node("image-1", CanvasNodeType.Image, { content: "data:image/png;base64,aaa", mimeType: "image/png" }), node("config-1", CanvasNodeType.Config)];
    const connections = [{ id: "c1", fromNodeId: "text-1", toNodeId: "config-1" }, { id: "c2", fromNodeId: "image-1", toNodeId: "config-1" }];
    const context = buildNodeGenerationContext("config-1", nodes, connections, "生成一张海报");
    expect(context.prompt).toBe("生成一张海报\n\n写实电影感");
    expect(context.referenceImages.map((image) => image.id)).toEqual(["image-1"]);
});

it("turns composer image and text tokens into stable labels and references", () => {
    const nodes = [node("image-1", CanvasNodeType.Image, { content: "data:image/png;base64,aaa", mimeType: "image/png" }), node("text-1", CanvasNodeType.Text, { content: "低饱和蓝色调" }), node("config-1", CanvasNodeType.Config, { composerContent: "参考 @[node:image-1]，色彩要求 @[node:text-1]" })];
    const connections = [{ id: "c1", fromNodeId: "image-1", toNodeId: "config-1" }, { id: "c2", fromNodeId: "text-1", toNodeId: "config-1" }];
    const context = buildNodeGenerationContext("config-1", nodes, connections, "ignored legacy prompt");
    expect(context.prompt).toBe("参考 图片1，色彩要求 【文本1】\n\n【文本1】\n低饱和蓝色调");
    expect(context.referenceImages.map((image) => image.id)).toEqual(["image-1"]);
});

it("preserves stale composer tokens instead of deleting user input", () => {
    const context = buildNodeGenerationContext("config-1", [node("config-1", CanvasNodeType.Config, { composerContent: "保留 @[node:missing]" })], [], "ignored");
    expect(context.prompt).toBe("保留 @[node:missing]");
    expect(context.referenceImages).toEqual([]);
});

it("uses inputOrder to assign composer labels", () => {
    const nodes = [node("image-a", CanvasNodeType.Image, { content: "data:image/png;base64,a" }), node("image-b", CanvasNodeType.Image, { content: "data:image/png;base64,b" }), node("config-1", CanvasNodeType.Config, { inputOrder: ["image-b", "image-a"], composerContent: "先看 @[node:image-b] 再看 @[node:image-a]" })];
    const connections = [{ id: "c1", fromNodeId: "image-a", toNodeId: "config-1" }, { id: "c2", fromNodeId: "image-b", toNodeId: "config-1" }];
    const context = buildNodeGenerationContext("config-1", nodes, connections, "ignored");
    expect(context.prompt).toBe("先看 图片1 再看 图片2");
    expect(context.referenceImages.map((image) => image.id)).toEqual(["image-b", "image-a"]);
});
```

The test file must define the local helper:

```ts
function node(id: string, type: CanvasNodeType, metadata: CanvasNodeData["metadata"] = {}): CanvasNodeData {
    return { id, type, title: id, position: { x: 0, y: 0 }, width: 100, height: 100, metadata };
}
```

- [ ] **Step 2: Run tests to verify failure**

```powershell
npm run test -- "src/app/(user)/canvas/components/canvas-node-generation.test.ts"
```

Expected: FAIL because composer parsing is missing.

- [ ] **Step 3: Add `composerContent` type**

In `src/app/(user)/canvas/types.ts`, add this field immediately after `content?: string;`:

```ts
composerContent?: string;
```

- [ ] **Step 4: Replace generation transform**

In `src/app/(user)/canvas/components/canvas-node-generation.ts`, import helpers:

```ts
import { imageReferenceLabel } from "@/lib/image-reference-prompt";
import { getGenerationResourceNodes } from "../utils/canvas-resource-references";
```

Update `NodeGenerationContext`:

```ts
export type NodeGenerationContext = { prompt: string; referenceImages: ReferenceImage[]; textCount: number; imageCount: number; videoCount: number };
export type NodeGenerationInput = { nodeId: string; type: "text" | "image" | "video"; title: string; text?: string; image?: ReferenceImage; previewUrl?: string };
```

Replace `buildNodeGenerationContext()` and `buildNodeGenerationInputs()` with:

```ts
export function buildNodeGenerationContext(nodeId: string, nodes: CanvasNodeData[], connections: CanvasConnection[], prompt: string): NodeGenerationContext {
    const inputs = buildNodeGenerationInputs(nodeId, nodes, connections);
    const sourceNode = nodes.find((node) => node.id === nodeId);
    const composerContent = sourceNode?.type === CanvasNodeType.Config ? sourceNode.metadata?.composerContent?.trim() || "" : "";
    if (composerContent) return buildComposerGenerationContext(inputs, composerContent);

    const upstreamText = inputs.map((input) => input.text).filter(Boolean).join("\n\n");
    const referenceImages = inputs.map((input) => input.image).filter((image): image is ReferenceImage => Boolean(image));
    return { prompt: upstreamText ? `${prompt}\n\n${upstreamText}` : prompt, referenceImages, textCount: inputs.filter((input) => input.type === "text").length, imageCount: referenceImages.length, videoCount: inputs.filter((input) => input.type === "video").length };
}

function buildComposerGenerationContext(inputs: NodeGenerationInput[], prompt: string): NodeGenerationContext {
    const inputByNodeId = new Map(inputs.map((input) => [input.nodeId, input]));
    const selectedInputs: NodeGenerationInput[] = [];
    const labelByNodeId = new Map<string, string>();
    const textBlocks: string[] = [];
    const counts = { image: 0, video: 0, text: 0 };
    let hasToken = false;
    let lastIndex = 0;
    let nextPrompt = "";

    for (const match of prompt.matchAll(/@\[node:([^\]]+)\]/g)) {
        if (match.index === undefined) continue;
        hasToken = true;
        nextPrompt += prompt.slice(lastIndex, match.index);
        const token = match[0];
        const input = inputByNodeId.get(match[1] || "");
        if (!input) {
            nextPrompt += token;
            lastIndex = match.index + token.length;
            continue;
        }
        let label = labelByNodeId.get(input.nodeId);
        if (!label) {
            label = input.type === "image" ? imageReferenceLabel(counts.image++) : input.type === "video" ? `视频${++counts.video}` : `文本${++counts.text}`;
            labelByNodeId.set(input.nodeId, label);
            if (input.type === "text") textBlocks.push(`【${label}】\n${input.text || ""}`);
            else selectedInputs.push(input);
        }
        nextPrompt += input.type === "text" ? `【${label}】` : label;
        lastIndex = match.index + token.length;
    }

    nextPrompt += prompt.slice(lastIndex);
    if (textBlocks.length) nextPrompt = `${nextPrompt.trim()}\n\n${textBlocks.join("\n\n")}`;
    const referenceImages = selectedInputs.map((input) => input.image).filter((image): image is ReferenceImage => Boolean(image));
    return hasToken ? { prompt: nextPrompt, referenceImages, textCount: counts.text, imageCount: referenceImages.length, videoCount: selectedInputs.filter((input) => input.type === "video").length } : { prompt, referenceImages: [], textCount: 0, imageCount: 0, videoCount: 0 };
}

export function buildNodeGenerationInputs(nodeId: string, nodes: CanvasNodeData[], connections: CanvasConnection[]): NodeGenerationInput[] {
    return getGenerationResourceNodes(nodeId, nodes, connections).flatMap((node): NodeGenerationInput[] => {
        const image = readReferenceImage(node);
        if (image) return [{ nodeId: node.id, type: "image", title: node.title, image, previewUrl: image.dataUrl }];
        if (node.type === CanvasNodeType.Video && node.metadata?.content) return [{ nodeId: node.id, type: "video", title: node.title, previewUrl: node.metadata.content }];
        const text = readNodeTextInput(node);
        if (text) return [{ nodeId: node.id, type: "text", title: node.title, text }];
        return [];
    });
}
```

Keep `buildNodeChatMessages()`, `hydrateNodeGenerationContext()`, `hydrateReferenceImages()`, `readNodeTextInput()`, and `readReferenceImage()` in the file. Delete the old local `getOrderedUpstreamNodes()` because `getGenerationResourceNodes()` owns ordering now.

- [ ] **Step 5: Run generation and utility tests**

```powershell
npm run test -- "src/app/(user)/canvas/components/canvas-node-generation.test.ts" "src/app/(user)/canvas/utils/canvas-resource-references.test.ts"
```

Expected: PASS.

- [ ] **Step 6: Commit generation transform**

```powershell
git add "src/app/(user)/canvas/types.ts" "src/app/(user)/canvas/components/canvas-node-generation.ts" "src/app/(user)/canvas/components/canvas-node-generation.test.ts"
git commit -m "feat: compose canvas prompts from resource tokens"
```

---

### Task 4: Wrap image edit prompts with reference labels

**Files:**
- Modify: `src/services/api/image.ts`
- Modify: `src/services/api/image.test.ts`

- [ ] **Step 1: Update failing API test expectations**

In `src/services/api/image.test.ts`, update the existing `requestEdit` test to assert:

```ts
const body = vi.mocked(axios.post).mock.calls[0]?.[1] as FormData;
expect(body.get("agent_id")).toBe("8");
expect(body.get("prompt")).toBe("参考图片编号：图片1。请按这些编号理解提示词中的图片引用。\n\n照着参考图生成");
expect(body.get("model")).toBeNull();
expect(body.get("provider")).toBeNull();
expect(body.get("api_key")).toBeNull();
expect(body.get("base_url")).toBeNull();
expect(body.getAll("image")).toHaveLength(1);
```

- [ ] **Step 2: Run image API test to verify failure**

```powershell
npm run test -- src/services/api/image.test.ts
```

Expected: FAIL because prompt is still raw.

- [ ] **Step 3: Implement request prompt wrapping**

In `src/services/api/image.ts`, add:

```ts
import { buildImageReferencePromptText } from "@/lib/image-reference-prompt";
```

Inside `requestEdit()`, replace `formData.set("prompt", prompt);` with:

```ts
const requestPrompt = buildImageReferencePromptText(prompt, references);
formData.set("prompt", requestPrompt);
```

Do not add `model`, `provider`, `api_key`, or `base_url` to FormData.

- [ ] **Step 4: Run tests**

```powershell
npm run test -- src/services/api/image.test.ts src/lib/image-reference-prompt.test.ts
```

Expected: PASS.

- [ ] **Step 5: Commit image API wrapping**

```powershell
git add src/services/api/image.ts src/services/api/image.test.ts
git commit -m "feat: label canvas image edit references"
```

---

### Task 5: Add config node composer UI

**Files:**
- Create: `src/app/(user)/canvas/components/canvas-config-composer.tsx`
- Modify: `src/app/(user)/canvas/components/canvas-config-node-panel.tsx`
- Create/Modify: `tests/shared/canvas-prompt-composition.test.ts`

- [ ] **Step 1: Write failing source guard for config composer**

Create `tests/shared/canvas-prompt-composition.test.ts`:

```ts
import { describe, expect, test } from "vitest";
import { readFileSync } from "node:fs";
import { join } from "node:path";

function source(path: string) { return readFileSync(join(process.cwd(), path), "utf8"); }

describe("canvas prompt composition source wiring", () => {
    test("config node panel owns composerContent editing", () => {
        const panel = source("src/app/(user)/canvas/components/canvas-config-node-panel.tsx");
        expect(panel).toContain("CanvasConfigComposer");
        expect(panel).toContain("composerContent");
        expect(panel).toContain("onConfigChange(node.id, { composerContent");
    });
});
```

- [ ] **Step 2: Run source guard to verify failure**

```powershell
npm run test -- tests/shared/canvas-prompt-composition.test.ts
```

Expected: FAIL because composer UI is not wired.

- [ ] **Step 3: Create lightweight config composer**

Create `src/app/(user)/canvas/components/canvas-config-composer.tsx`:

```tsx
"use client";

import { Button, Input } from "antd";
import { FileText, Image as ImageIcon, Video } from "lucide-react";
import type { NodeGenerationInput } from "./canvas-node-generation";

type CanvasConfigComposerProps = { value: string; inputs: NodeGenerationInput[]; onChange: (value: string) => void };

export function CanvasConfigComposer({ value, inputs, onChange }: CanvasConfigComposerProps) {
    const insertToken = (input: NodeGenerationInput) => {
        const token = `@[node:${input.nodeId}]`;
        onChange(`${value}${value.trim() ? " " : ""}${token}`);
    };
    return (
        <div className="cursor-default rounded-xl border border-dashed border-white/20 p-2" onMouseDown={(event) => event.stopPropagation()} onPointerDown={(event) => event.stopPropagation()}>
            <div className="mb-2 flex items-center justify-between gap-2"><span className="text-xs font-semibold">组装提示词</span><span className="text-[11px] opacity-55">点击资源插入引用</span></div>
            <Input.TextArea className="thin-scrollbar !resize-none !text-xs !leading-5" value={value} rows={3} placeholder="输入提示词，点击下方资源插入 @[node:id] 引用" onChange={(event) => onChange(event.target.value)} onWheel={(event) => event.stopPropagation()} />
            {inputs.length ? <div className="mt-2 flex flex-wrap gap-1.5">{inputs.map((input, index) => <Button key={input.nodeId} size="small" className="!h-7 !rounded-md !px-2 !text-[11px]" icon={<InputIcon type={input.type} />} onClick={() => insertToken(input)}>{labelForInput(input, index)}</Button>)}</div> : <div className="mt-2 text-[11px] opacity-50">连接文本或图片节点后可插入引用</div>}
        </div>
    );
}

function InputIcon({ type }: { type: NodeGenerationInput["type"] }) {
    if (type === "image") return <ImageIcon className="size-3" />;
    if (type === "video") return <Video className="size-3" />;
    return <FileText className="size-3" />;
}

function labelForInput(input: NodeGenerationInput, index: number) {
    if (input.type === "image") return `图片${index + 1}`;
    if (input.type === "video") return `视频${index + 1}`;
    return `文本${index + 1}`;
}
```

- [ ] **Step 4: Wire composer into config panel**

In `src/app/(user)/canvas/components/canvas-config-node-panel.tsx`, add:

```ts
import { CanvasConfigComposer } from "./canvas-config-composer";
```

Insert before the input chips block:

```tsx
<div className="mb-2" onMouseDown={(event) => event.stopPropagation()} onPointerDown={(event) => event.stopPropagation()}>
    <CanvasConfigComposer value={node.metadata?.composerContent || ""} inputs={inputs} onChange={(composerContent) => onConfigChange(node.id, { composerContent })} />
</div>
```

Keep preview modal, text editing, and `inputOrder` controls unchanged.

- [ ] **Step 5: Run guard and typecheck**

```powershell
npm run test -- tests/shared/canvas-prompt-composition.test.ts
npm run typecheck
```

Expected: PASS.

- [ ] **Step 6: Commit composer UI**

```powershell
git add "src/app/(user)/canvas/components/canvas-config-composer.tsx" "src/app/(user)/canvas/components/canvas-config-node-panel.tsx" tests/shared/canvas-prompt-composition.test.ts
git commit -m "feat: add canvas config prompt composer"
```

---

### Task 6: Add resource mention textarea and page wiring

**Files:**
- Create: `src/app/(user)/canvas/components/canvas-resource-mention-textarea.tsx`
- Modify: `src/app/(user)/canvas/components/canvas-node-prompt-panel.tsx`
- Modify: `src/app/(user)/canvas/components/canvas-node.tsx`
- Modify: `src/app/(user)/canvas/[id]/canvas-client-page.tsx`
- Modify: `tests/shared/canvas-prompt-composition.test.ts`

- [ ] **Step 1: Extend source guard for mention wiring**

Append to `tests/shared/canvas-prompt-composition.test.ts` inside the existing `describe`:

```ts
test("ordinary prompt inputs use resource mention wiring", () => {
    const promptPanel = source("src/app/(user)/canvas/components/canvas-node-prompt-panel.tsx");
    const node = source("src/app/(user)/canvas/components/canvas-node.tsx");
    const clientPage = source("src/app/(user)/canvas/[id]/canvas-client-page.tsx");
    expect(promptPanel).toContain("CanvasResourceMentionTextarea");
    expect(promptPanel).toContain("mentionReferences");
    expect(promptPanel).not.toMatch(/<Input\.TextArea[\s\S]*value=\{prompt\}/);
    expect(node).toContain("mentionReferences");
    expect(node).toContain("ResourceLabelBadge");
    expect(clientPage).toContain("buildCanvasResourceReferences");
    expect(clientPage).toContain("buildNodeMentionReferences");
    expect(clientPage).toContain("mentionReferences={mentionReferencesByNodeId.get");
});
```

- [ ] **Step 2: Run guard to verify failure**

```powershell
npm run test -- tests/shared/canvas-prompt-composition.test.ts
```

Expected: FAIL because mention wiring is not present.

- [ ] **Step 3: Create mention textarea component**

Create `src/app/(user)/canvas/components/canvas-resource-mention-textarea.tsx`:

```tsx
"use client";

import { forwardRef, useMemo, useRef, useState, type CSSProperties, type KeyboardEvent, type TextareaHTMLAttributes } from "react";
import { FileText, Image as ImageIcon, Video } from "lucide-react";
import type { CanvasResourceReference } from "../utils/canvas-resource-references";

type Props = Omit<TextareaHTMLAttributes<HTMLTextAreaElement>, "onChange" | "value"> & { value: string; references: CanvasResourceReference[]; onChange: (value: string) => void; containerClassName?: string };
type MentionState = { query: string; start: number; end: number };

export const CanvasResourceMentionTextarea = forwardRef<HTMLTextAreaElement, Props>(function CanvasResourceMentionTextarea({ value, references, onChange, onKeyDown, className, containerClassName, style, ...props }, forwardedRef) {
    const localRef = useRef<HTMLTextAreaElement | null>(null);
    const [mention, setMention] = useState<MentionState | null>(null);
    const [activeIndex, setActiveIndex] = useState(0);
    const activeReferences = useMemo(() => references.filter((item) => item.active), [references]);
    const labels = useMemo(() => Array.from(new Set(activeReferences.map((item) => item.label))).sort((a, b) => b.length - a.length), [activeReferences]);
    const candidates = useMemo(() => !mention ? [] : activeReferences.filter((item) => !mention.query.trim() || `${item.label} ${item.title} ${item.text || ""}`.toLowerCase().includes(mention.query.trim().toLowerCase())), [activeReferences, mention]);
    const setRef = (node: HTMLTextAreaElement | null) => { localRef.current = node; if (typeof forwardedRef === "function") forwardedRef(node); else if (forwardedRef) forwardedRef.current = node; };
    const syncMention = (nextValue: string, cursor: number) => { const match = /(^|\s)@([^\s@]*)$/.exec(nextValue.slice(0, cursor)); if (!match || !activeReferences.length) return setMention(null); setMention({ query: match[2] || "", start: cursor - (match[2] || "").length - 1, end: cursor }); setActiveIndex(0); };
    const updateValue = (nextValue: string, cursor?: number) => { onChange(nextValue); if (typeof cursor === "number") requestAnimationFrame(() => localRef.current?.setSelectionRange(cursor, cursor)); };
    const insertReference = (reference: CanvasResourceReference) => { if (!mention) return; const text = `${reference.label} `; updateValue(`${value.slice(0, mention.start)}${text}${value.slice(mention.end)}`, mention.start + text.length); setMention(null); };
    const handleKeyDown = (event: KeyboardEvent<HTMLTextAreaElement>) => { if (mention && candidates.length) { if (event.key === "ArrowDown") { event.preventDefault(); setActiveIndex((index) => (index + 1) % candidates.length); return; } if (event.key === "ArrowUp") { event.preventDefault(); setActiveIndex((index) => (index - 1 + candidates.length) % candidates.length); return; } if (event.key === "Enter" || event.key === "Tab") { event.preventDefault(); insertReference(candidates[Math.min(activeIndex, candidates.length - 1)]!); return; } if (event.key === "Escape") { event.preventDefault(); setMention(null); return; } } onKeyDown?.(event); };
    return <div className={containerClassName || "relative min-h-0"}>{labels.length ? <MentionHighlight value={value || props.placeholder?.toString() || ""} labels={labels} className={className} style={style} /> : null}<textarea {...props} ref={setRef} value={value} className={className} style={{ ...style, ...(labels.length ? { color: "transparent", background: "transparent", caretColor: style?.color || "currentColor" } : {}) }} onChange={(event) => { updateValue(event.target.value); syncMention(event.target.value, event.target.selectionStart); }} onSelect={(event) => syncMention(event.currentTarget.value, event.currentTarget.selectionStart)} onKeyDown={handleKeyDown} />{mention && candidates.length ? <div className="absolute left-2 top-full z-[90] mt-1 max-h-56 w-64 overflow-y-auto rounded-xl border border-black/10 bg-white p-1 text-xs shadow-2xl dark:border-white/10 dark:bg-stone-900">{candidates.map((reference, index) => <button key={reference.id} type="button" className={`flex w-full min-w-0 items-center gap-2 rounded-lg px-2 py-1.5 text-left ${index === activeIndex ? "bg-blue-500 text-white" : "hover:bg-black/5 dark:hover:bg-white/10"}`} onMouseDown={(event) => { event.preventDefault(); insertReference(reference); }}><ReferenceIcon reference={reference} /><span className="min-w-0 flex-1"><span className="block font-medium">{reference.label}</span><span className="block truncate opacity-70">{reference.text || reference.title}</span></span></button>)}</div> : null}</div>;
});

function MentionHighlight({ value, labels, className, style }: { value: string; labels: string[]; className?: string; style?: CSSProperties }) {
    const pattern = new RegExp(`(${labels.map((label) => label.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")).join("|")})`, "g");
    return <div className={`${className || ""} pointer-events-none absolute inset-0 overflow-hidden whitespace-pre-wrap break-words`} style={style} aria-hidden="true">{value.split(pattern).map((part, index) => labels.includes(part) ? <mark key={`${part}-${index}`} className="rounded bg-blue-500/15 px-0.5 text-blue-600 dark:text-blue-300">{part}</mark> : <span key={`${part}-${index}`}>{part}</span>)}</div>;
}

function ReferenceIcon({ reference }: { reference: CanvasResourceReference }) {
    if (reference.kind === "image" && reference.previewUrl) return <img src={reference.previewUrl} alt="" className="size-8 rounded object-cover" />;
    if (reference.kind === "video" && reference.previewUrl) return <video src={reference.previewUrl} className="size-8 rounded bg-black object-cover" muted preload="metadata" />;
    const Icon = reference.kind === "image" ? ImageIcon : reference.kind === "video" ? Video : FileText;
    return <Icon className="size-4" />;
}
```

- [ ] **Step 4: Wire into prompt panel, node, and client page**

Apply these exact interface changes:

```ts
// canvas-node-prompt-panel.tsx
import { CanvasResourceMentionTextarea } from "./canvas-resource-mention-textarea";
import type { CanvasResourceReference } from "../utils/canvas-resource-references";
// add prop: mentionReferences?: CanvasResourceReference[]
// function args: mentionReferences = []
```

Replace the prompt Ant Design textarea block with:

```tsx
<CanvasResourceMentionTextarea value={prompt} references={mentionReferences} onChange={updatePrompt} rows={4} placeholder={promptPlaceholder(mode, hasImageContent, hasTextContent)} className="thin-scrollbar !w-full !resize-none rounded-xl border px-3 py-2 text-sm leading-6 outline-none" style={{ background: theme.node.fill, borderColor: theme.node.stroke, color: theme.node.text }} onKeyDown={(event) => { if ((event.metaKey || event.ctrlKey) && event.key === "Enter") runGenerate(); }} />
```

In `canvas-node.tsx`, add `resourceLabel?: CanvasResourceReference` and `mentionReferences?: CanvasResourceReference[]` to props, pass `mentionReferences` into `NodeContent`, replace text edit `<textarea>` with `CanvasResourceMentionTextarea`, and add:

```tsx
{resourceLabel ? <ResourceLabelBadge reference={resourceLabel} /> : null}
```

Add helper:

```tsx
function ResourceLabelBadge({ reference }: { reference: CanvasResourceReference }) {
    return <span className={`pointer-events-none absolute right-2 top-2 z-30 rounded-md px-1.5 py-0.5 text-[10px] font-medium ${reference.active ? "bg-[#2f80ff] text-white shadow-sm" : "bg-black/35 text-white/75"}`}>{reference.label}</span>;
}
```

In `canvas-client-page.tsx`, import and compute references:

```ts
import { buildCanvasResourceReferences, buildNodeMentionReferences } from "../utils/canvas-resource-references";

const resourceContextNodeId = dialogNodeId || activeNodeId;
const canvasResourceReferences = useMemo(() => buildCanvasResourceReferences(nodes, connections, resourceContextNodeId), [connections, nodes, resourceContextNodeId]);
const resourceReferenceByNodeId = useMemo(() => new Map(canvasResourceReferences.map((reference) => [reference.nodeId, reference])), [canvasResourceReferences]);
const mentionReferencesByNodeId = useMemo(() => { const map = new Map<string, ReturnType<typeof buildNodeMentionReferences>>(); nodes.forEach((node) => map.set(node.id, buildNodeMentionReferences(node, nodes, connections))); return map; }, [connections, nodes]);
```

Pass props:

```tsx
resourceLabel={resourceReferenceByNodeId.get(node.id)}
mentionReferences={mentionReferencesByNodeId.get(node.id) || []}
```

and to `CanvasNodePromptPanel`:

```tsx
mentionReferences={mentionReferencesByNodeId.get(panelNode.id) || []}
```

- [ ] **Step 5: Run guard and typecheck**

```powershell
npm run test -- tests/shared/canvas-prompt-composition.test.ts
npm run typecheck
```

Expected: PASS.

- [ ] **Step 6: Commit mention UI wiring**

```powershell
git add "src/app/(user)/canvas/components/canvas-resource-mention-textarea.tsx" "src/app/(user)/canvas/components/canvas-node-prompt-panel.tsx" "src/app/(user)/canvas/components/canvas-node.tsx" "src/app/(user)/canvas/[id]/canvas-client-page.tsx" tests/shared/canvas-prompt-composition.test.ts
git commit -m "feat: wire canvas prompt resource mentions"
```

---

### Task 7: Verify frontend slice

**Files:** no planned edits.

- [ ] **Step 1: Run targeted prompt tests**

```powershell
npm run test -- src/lib/image-reference-prompt.test.ts "src/app/(user)/canvas/utils/canvas-resource-references.test.ts" "src/app/(user)/canvas/components/canvas-node-generation.test.ts" src/services/api/image.test.ts tests/shared/canvas-prompt-composition.test.ts
```

Expected: PASS.

- [ ] **Step 2: Run nearby regression tests**

```powershell
npm run test -- "src/app/(user)/canvas/[id]/hydrate-canvas-images.test.ts" "src/app/(user)/canvas/[id]/running-node-state.test.ts" tests/shared/canvas-api-boundary.test.ts tests/shared/canvas-free-generation.test.ts
```

Expected: PASS.

- [ ] **Step 3: Run typecheck**

```powershell
npm run typecheck
```

Expected: PASS.

- [ ] **Step 4: Check frontend git status**

```powershell
git status --short
```

Expected: clean after task commits.

---

### Task 8: Root governance and final report

**Files:** update root docs only if implementation changes documented runtime facts.

- [ ] **Step 1: Run root whitespace check**

From `E:/admin_go`:

```powershell
git diff --check
```

Expected: no output and exit code 0.

- [ ] **Step 2: Run root governance check**

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected: `PASS: no blocking governance violations found.`

- [ ] **Step 3: Final implementation report**

Use this structure:

```text
Outcome
Changed files
Verification
Known risks
Next step
```

Mention explicitly: video/audio reference backends remain out of scope, and no browser-side provider/model credential override was introduced.
