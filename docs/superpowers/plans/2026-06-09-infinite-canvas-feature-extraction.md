# Canvas Front Next Feature Backport Implementation Plan

状态：corrected active plan
日期：2026-06-09
目标项目：`E:\admin_go\canvas_front_next`
必要联动：`E:\admin_go\admin_back_go`、`E:\admin_go\admin_front_ts`
对照来源：`E:\GitDownload\infinite-canvas`

## 纠偏硬规则

- 本计划只改 admin_go 三仓和 root docs。
- `E:\GitDownload\infinite-canvas` 只读对照；除非用户明确要求，禁止修改、提交或合并它。
- 不迁移来源项目的 `/api/auth/*`、`/api/v1/*`、`/api/assets`、独立后台、JWT/session、DB 表结构。
- 所有能力必须映射到 admin_go 当前契约：Canvas `/api/canvas/v1/*`、Admin `/api/admin/v1/*`、Go `internal/module/{capability}/transport/{platform}`。
- 每次只做一个窄切片；代码变更默认 TDD，先失败测试，再最小实现，再 typecheck/test。

## C0：三仓差异审计（已完成，只读）

结论摘要：

- `canvas_front_next` 已有 Vitest、ZIP 导入导出、Canvas assets 持久化、auth/logout、strict API envelope、inputOrder/stale token、图片/视频/文本资源引用。
- 来源项目值得借鉴的主要是：音频资源链路、Seedance 视频高级参数、参考媒体上传、当前画布合并导入、导入/素材 fail-closed。
- `admin_back_go` 需要后续考虑：参考媒体上传 provider URL、`ai_assets` audio 类型、asset tags 聚合/筛选、Seedance/火山方舟 Agent Plan 视频路径、上游错误友好化。
- `admin_front_ts` 不恢复 Admin 素材库；完整音频生成若做，需要新增 Admin agent scene / provider 管理契约。

## C1：Canvas 音频资源引用基础（本轮切片）

### 目标

让 `canvas_front_next` 识别音频为 Canvas 资源引用类型：编号、composer token、生成上下文、配置摘要和基础节点渲染都完整；不做完整音频生成/上传/后端联动。

### 文件

- `E:\admin_go\canvas_front_next\src\types\media.ts`
- `E:\admin_go\canvas_front_next\src\app\(user)\canvas\types.ts`
- `E:\admin_go\canvas_front_next\src\app\(user)\canvas\constants.ts`
- `E:\admin_go\canvas_front_next\src\app\(user)\canvas\utils\canvas-resource-references.ts`
- `E:\admin_go\canvas_front_next\src\app\(user)\canvas\utils\canvas-resource-references.test.ts`
- `E:\admin_go\canvas_front_next\src\app\(user)\canvas\components\canvas-node-generation.ts`
- `E:\admin_go\canvas_front_next\src\app\(user)\canvas\components\canvas-node-generation.test.ts`
- `E:\admin_go\canvas_front_next\src\app\(user)\canvas\components\canvas-config-composer.tsx`
- `E:\admin_go\canvas_front_next\src\app\(user)\canvas\components\canvas-config-composer.test.tsx`
- `E:\admin_go\canvas_front_next\src\app\(user)\canvas\components\canvas-config-node-panel.tsx`
- `E:\admin_go\canvas_front_next\src\app\(user)\canvas\components\canvas-node.tsx`
- `E:\admin_go\canvas_front_next\src\app\(user)\canvas\[id]\canvas-client-page.tsx`

### TDD steps

- [x] Add failing tests for audio resource labels and ordered references.
- [x] Add failing tests for `@[node:<audio>]` composer token -> `音频1` and `NodeGenerationContext.referenceAudios/audioCount`.
- [x] Add failing composer label test proving audio is not text fallback (`文本NaN`).
- [x] Implement `CanvasNodeType.Audio`, `CanvasGenerationMode = "audio"`, metadata fields and `ReferenceAudio` type.
- [x] Add audio to resource kind/label/order logic.
- [x] Add audio to node generation inputs/context/composer labels.
- [x] Add audio to config composer labels and preview icon.
- [x] Add audio default node spec and node renderer coverage for typecheck completeness.
- [x] Add audio to config input summary.

### Verification commands

```powershell
cd E:\admin_go\canvas_front_next
npm test -- "src/app/(user)/canvas/utils/canvas-resource-references.test.ts" "src/app/(user)/canvas/components/canvas-node-generation.test.ts" "src/app/(user)/canvas/components/canvas-config-composer.test.tsx" tests/shared/canvas-reference-feature-parity.test.ts
npm run typecheck
```

### Non-goals for C1

- 不新增工具栏创建音频入口。
- 不新增音频上传/拖拽恢复链路。
- 不新增后端 audio generation。
- 不新增 Admin `canvas_audio_generate` 场景。

## C2：Canvas 参考媒体上传与视频高级参数（部分落地：C2-A 第一刀）

### 目标

把来源项目更完整的视频/参考媒体能力映射到 admin_go Canvas API 和 Go backend。

### C2-A 第一刀已落地边界

- 仅迁移来源项目中适合当前契约的 `generate_audio` / `watermark` 两个布尔参数。
- `canvas_front_next` 视频设置、视频 API、Canvas 节点局部视频设置、视频页日志保存/恢复已接入这两个开关。
- Go Canvas video transport/service/OpenAI-compatible adapter 只做显式字段透传；未把字段写入 DB，也未新增 provider/model/API key/base URL 浏览器覆盖能力。
- 不包含参考视频/参考音频上传，不新增 `/api/v1/media/references`，不包含完整 Seedance/火山 Agent Plan path routing，不改 `E:\GitDownload\infinite-canvas`。

### 前置决策

- 明确后端 DTO：参考视频/音频如何上传、返回什么 provider 可访问 URL。
- 明确 Seedance 参数：`generate_audio` / `watermark` 已完成 C2-A 最小透传；ratio/resolution/duration 策略、参考媒体和完整 Seedance/火山路径仍待产品化决策。
- 明确上游错误映射：敏感内容、privacy reference video 等错误如何进入 i18n catalog。

### 预期文件

- Canvas 前端 video API / settings popover / tests。
- Go `internal/module/ai/video/transport/canvas` request/handler/service tests。
- 必要时 storage/COS helper 和 i18n catalog。

### C2-A 验证状态

- [x] `canvas_front_next` targeted Vitest：`src/services/api/video.test.ts`、`tests/shared/canvas-video-advanced-settings.test.ts`。
- [x] `canvas_front_next` `npm run typecheck`。
- [x] `admin_back_go` focused Go tests：`./internal/module/ai/video`、`./internal/module/ai/video/transport/canvas`、`./internal/infra/ai/openaicompat`。
- [ ] 参考视频/参考音频上传、完整 Seedance 参数策略和 live provider 成功 smoke 仍是后续切片。

## C3：当前画布合并导入（部分落地：第一刀）

### 目标

编辑页支持把 zip 节点包追加到当前画布，服务 Cine Make 分阶段工作流。

### 第一刀已落地边界

- `canvas_front_next` 编辑页已接入“合并画布”入口：ZIP 节点包导入后追加到当前项目，不把来源包作为新项目打开。
- 画布库导入路径不在本切片改动，仍保持“导入画布 = 新建项目”的既有行为。
- 第一刀只覆盖前端本地 ZIP parse/asset restore/current-project merge/store wiring；不触碰 `E:\GitDownload\infinite-canvas`，不新增 backend/Admin/API/schema 迁移。
- 仍不把 C3 写成整体完成：浏览器手工 Cine Make 全流程、云端项目同步、素材 ownership remap、C4 级素材/导入产品化校验都留给后续切片。

### 关键要求

- 画布库导入仍然新建项目。
- 编辑页 merge import 只更新当前项目。
- ID remap、connection remap、右侧放置。
- 已锁定人物/场景/风格主图不被覆盖。
- 稳定 anchor metadata 优先；缺锚点不乱连。
- 坏 zip/缺文件 fail-closed。

### 验证状态

- [x] Pure merge util tests：重复 ID、连接 remap、右侧放置、锚点复用、缺锚点 warning。
- [x] Import parse tests：缺 `projects.json`、缺 blob、坏 schema、size mismatch。
- [x] Targeted wiring guard：编辑页 merge import 走当前项目追加路径，不调用 `importProject(`。
- [x] `npm run typecheck`。
- [ ] 浏览器手工验证完整 Cine Make 分阶段导入体验。

## C4：素材/导入严格校验（部分落地：C4-A / C4-B）

### 目标

增强 `/api/canvas/v1/assets` 和 ZIP 导入的数据质量，不恢复公共素材库。

### C4-A 第一刀已落地边界

- 只覆盖 `canvas_front_next` 的素材 ZIP 导入/导出 parser。
- `readAssetPackage` 现在先完整校验 `assets.json` schema、image/video metadata、storageKey/mime/bytes 一致性、声明 blob 存在性、ZIP entry size，再写入 localforage。
- `exportAssets` 现在只把 text asset 和实际打包到 ZIP 的 media asset 写入 manifest，避免导出“资产声明存在但 blob 缺失”的不自洽包。
- 仍保留素材页导入走 `addAsset(withoutImportedAssetSlug(...))`，导入后通过 Canvas backend create 新资产，不复用导出包旧 id/createdAt/updatedAt/metadata.slug。
- 不包含后端 `/api/canvas/v1/assets` payload metadata 强校验，不包含 audio backend asset type，不恢复 public asset library / Admin 素材库。

### C4-B 第一刀已落地边界

- 只覆盖 `admin_back_go` 的 Canvas `/api/canvas/v1/assets` image/video create/update service 校验。
- `internal/module/ai/asset` 现在要求 image/video asset 有非空 `url`，`content` 必须是严格 JSON object，并包含 storage-backed `storageKey`、正数 `width` / `height` / `bytes`、匹配类型的 `mimeType`。
- `storageKey` 支持当前后端 COS object key（如 `ai-images/...`）和带路径的 typed key（如 `image:task/...` / `video:task/...`），但拒绝浏览器本地短 key（如 `image:localBrowserOnly`）和类型错配 key。
- `content` 顶层未知字段会拒绝；允许 `metadata` 子对象承载前端业务元数据，但不让 provider/model/api key 等顶层字段静默进入媒体契约。
- 不新增 DB metadata columns，不新增 `audio` asset type，不恢复 public asset library / Admin 素材库。

### 关键要求

- image/video metadata 明确校验；audio asset type 需等后端/Admin/Canvas 契约单独确认。
- tags 筛选/聚合如果做，先定后端 contract。
- 导入素材生成当前用户资产，不复用导出包旧 id/slug。

### C4-A 验证状态

- [x] RED：素材 ZIP 测试先证明旧 parser 对坏 schema、缺 blob、bytes mismatch、metadata mismatch、孤儿 file 不 fail-closed。
- [x] `readAssetPackage` fail-closed：缺 `assets.json`、坏 schema、缺 blob、blob size mismatch、media asset 无声明 file、孤儿 file、image/video metadata/mime/storageKey 不合法均拒绝，且坏包不部分写入 blob store。
- [x] `exportAssets` 自洽 manifest：缺 blob 的 media asset 不进入导出 manifest。
- [x] `npm test -- "src/app/(user)/assets/asset-transfer.test.ts" "tests/shared/ai-asset-backend-persistence.test.ts" "src/app/(user)/canvas/utils/canvas-import.test.ts"`。
- [x] `npm run typecheck`。

### C4-B 验证状态

- [x] RED：Go service test 先证明旧 `ai/asset` service 会接受坏 image/video metadata。
- [x] `internal/module/ai/asset` fail-closed：缺/坏 `content` JSON、缺 `storageKey`、裸 storage key、浏览器本地短 key、类型错配 storage key、错误 mime、非正数 width/height/bytes、未知顶层 metadata 字段均拒绝且不进 repository。
- [x] 保持合法 media asset 可创建；Canvas transport 测试样例更新为带完整 media `content`。
- [x] `go test ./internal/module/ai/asset ./internal/module/ai/asset/transport/canvas -count=1 -p=1`。

## C5：Admin/后端产品化补齐（待做）

仅在产品契约确认后做：

- 完整音频生成：后端 `ai_assets` audio 类型、`canvas_audio_generate` agent scene、Admin Vue agent/provider 配置、Canvas UI。
- 视频高级参数：Admin provider/agent 策略管理，Canvas 仅提交后端允许字段。

## 收口验证

每轮代码切片至少：

```powershell
cd E:\admin_go\canvas_front_next
npm test -- <targeted tests>
npm run typecheck
```

root docs/governance：

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

如果触碰 backend route/schema/contracts，再补 Go test、contract drift 和 runtime doc fact check。
