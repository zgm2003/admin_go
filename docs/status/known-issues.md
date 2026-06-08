# Known Issues and WIP

状态更新时间：2026-06-08

本文只记录当前已知 bug、失败测试和未闭环 WIP。这里的内容不是 verified change-log；修复完成前不得把它写成 implemented。

## Current open issues

No current open issue is tracked in this file after the 2026-06-08 Admin AI interaction retirement. Do not treat this as “all quality debt closed”; `any/as any/catch(error: any)/direct external HTTP` candidates are currently zero, while the remaining `513` fallback rows stay in `docs/knowledge/admin-front-source-quality-inventory-2026-06-08.md` as review inventory.

## Recently resolved

### ADMIN-FRONT-HARDENING-014 AI image payload source-quality debt

Status: superseded on 2026-06-08 by Admin AI interaction retirement. The 2026-06-07 AI image create-task optional payload cleanup was valid for the then-active Admin image playground, but the Admin image API/UI/test surface is now retired instead of kept as an Admin feature.

Evidence:

```text
admin_front_ts/src/api/ai/images.ts is absent.
admin_front_ts/tests/shared/ai/admin-ai-interaction-retirement.test.ts guards the retired Admin AI interaction surface.
docs/knowledge/admin-front-ai-image-payload-source-quality-review-2026-06-07.md records the source decision and inventory result.
docs/knowledge/admin-front-source-quality-inventory-2026-06-08.md now reports 274 source files and 513 fallback candidates after removing Admin 图片工作台/素材管理 source.
```

Boundary:

```text
This closes the historical Admin image create-task optional payload debt by retiring the Admin interaction surface. Canvas image generation remains under Canvas runtime ownership; this does not close the remaining Admin Vue fallback inventory.
```

### ADMIN-FRONT-HARDENING-013 Demo any source-quality debt

Status: resolved on 2026-06-07 as a form/display/ParticleBackground demo any cleanup.

Evidence:

```text
admin_front_ts/src/views/Main/component/form/index.vue uses SearchFormModel, IconSelectExpose, MockRemoteSelectParams, and RemoteListFetchMethod instead of any.
admin_front_ts/src/views/Main/component/display/index.vue documents passthrough column props as Record<string, unknown>.
admin_front_ts/src/views/Main/component/effect/components/ParticleBackground.vue defines Particle and PointerPosition and no longer uses particles: any[], mouse: any, window.devicePixelRatio || 1, or Math.sqrt(...) || 1.
admin_front_ts/tests/shared/form/form-demo-source-quality.test.ts guards the form demo source shape.
admin_front_ts/tests/shared/display/display-demo-source-quality.test.ts guards the display demo source shape.
admin_front_ts/tests/shared/effect/particle-background-source-quality.test.ts guards the ParticleBackground source shape.
docs/knowledge/admin-front-demo-any-source-quality-review-2026-06-07.md records the source decision and inventory result.
docs/knowledge/admin-front-source-quality-inventory-2026-06-07.md now reports source files scanned = 280, any candidates = 0, as any candidates = 0, catch(error: any) candidates = 0, fallback candidates = 555, and direct external HTTP candidates = 0.
```

Boundary:

```text
This closes only the currently tracked Admin Vue any/as-any/catch-any/direct-external inventory rows. It does not close the remaining fallback candidates.
```

### ADMIN-FRONT-HARDENING-012 Upload demo media-list source-quality debt

Status: resolved on 2026-06-07 as an upload demo media-list typing cleanup.

Evidence:

```text
admin_front_ts/src/views/Main/component/upload/components/media.ts defines UploadMediaItem.
admin_front_ts/src/views/Main/component/upload/index.vue uses ref<UploadMediaItem[]>([]).
admin_front_ts/src/views/Main/component/upload/index.vue no longer contains ref<any[]>.
admin_front_ts/src/views/Main/component/upload/components/UpMediaList.vue uses UploadMediaItem for props, emits, watcher input, and conversion output.
admin_front_ts/tests/shared/upload/upload-demo-source-quality.test.ts guards the source shape.
docs/knowledge/admin-front-upload-demo-source-quality-review-2026-06-07.md records the source decision and inventory result.
docs/knowledge/admin-front-source-quality-inventory-2026-06-07.md now reports source files scanned = 280, any candidates = 7, as any candidates = 0, catch(error: any) candidates = 0, fallback candidates = 562, and upload/index.vue with no configured source-quality finding.
```

Boundary:

```text
This only closes upload demo media-list typing debt. It does not close UpMediaList fallback rows or the remaining general Admin Vue any/fallback inventory rows.
```

### ADMIN-FRONT-HARDENING-011 useValidator source-quality debt

Status: resolved on 2026-06-07 as a validator input typing and message fallback cleanup.

Evidence:

```text
admin_front_ts/src/hooks/web/useValidator.ts defines ValidatorValue = string and LengthRange.
admin_front_ts/src/hooks/web/useValidator.ts owns resolveValidatorMessage(message, fallback).
admin_front_ts/src/hooks/web/useValidator.ts no longer contains val: any or message || fallback rows.
admin_front_ts/tests/shared/validator/use-validator-source-quality.test.ts guards the source shape.
docs/knowledge/admin-front-validator-source-quality-review-2026-06-07.md records the source decision and inventory result.
docs/knowledge/admin-front-source-quality-inventory-2026-06-07.md now reports any candidates = 7, as any candidates = 0, catch(error: any) candidates = 0, fallback candidates = 562, and useValidator.ts with only a validation predicate logical-or row.
```

Boundary:

```text
This only closes useValidator validator input typing and message fallback debt. It does not close the remaining general Admin Vue any/fallback inventory rows.
```

### ADMIN-FRONT-HARDENING-010 Dev test download error source-quality debt

Status: resolved on 2026-06-07 as a dev test download catch-any and fallback-message cleanup.

Evidence:

```text
admin_front_ts/src/views/Main/test/index.vue catches download failures as unknown.
admin_front_ts/src/views/Main/test/index.vue owns requireDevTestDownloadErrorMessage() and optionalDownloadFilename().
admin_front_ts/src/views/Main/test/index.vue no longer contains catch (error: any), error.message || t('devTest.downloadFailed'), or testFilename.value || undefined.
admin_front_ts/tests/shared/download-manager/dev-test-download-source-quality.test.ts guards the source shape.
docs/knowledge/admin-front-dev-test-download-source-quality-review-2026-06-07.md records the source decision and inventory result.
docs/knowledge/admin-front-source-quality-inventory-2026-06-07.md now reports any candidates = 7, as any candidates = 0, catch(error: any) candidates = 0, fallback candidates = 562, and dev test download with no configured source-quality finding.
```

Boundary:

```text
This only closes the dev test page download error-handling slice. It does not close the remaining general Admin Vue any/fallback inventory rows.
```

### ADMIN-FRONT-HARDENING-009 DownloadManager error source-quality debt

Status: resolved on 2026-06-07 as a DownloadManager catch-any and failed-download fallback cleanup.

Evidence:

```text
admin_front_ts/src/components/DownloadManager/src/download.ts catches downloadFile failures as unknown.
admin_front_ts/src/components/DownloadManager/src/errors.ts owns isDownloadUserCancelled() and requireDownloadError().
admin_front_ts/src/components/DownloadManager/src/download.ts no longer contains catch (error: any), catch (err: any), Web fetch catch window.open(url, '_blank') fallback, or filename logical-or fallback chains.
admin_front_ts/tests/shared/download-manager/download-manager-source-quality.test.ts guards the source shape and helper behavior.
docs/knowledge/admin-front-download-manager-source-quality-review-2026-06-07.md records the source decision and inventory result.
docs/knowledge/admin-front-source-quality-inventory-2026-06-07.md now reports any candidates = 7, as any candidates = 0, catch(error: any) candidates = 0, fallback candidates = 562, and DownloadManager/download.ts with no configured source-quality finding.
```

Boundary:

```text
This only closes DownloadManager download.ts catch-any, failed-download silent fallback, and filename fallback debt. The later dev test download cleanup closed the remaining catch-any inventory row; general Admin Vue `any` and fallback rows remain review debt.
```

### ADMIN-FRONT-HARDENING-008 wangEditor wrapper source-quality debt

Status: resolved on 2026-06-07 as a wangEditor wrapper typing and upload URL fail-closed cleanup.

Evidence:

```text
admin_front_ts/src/views/Main/component/display/components/Editor.vue imports typed Boot, IDomEditor, IEditorConfig, and IModuleConf from @wangeditor/editor.
admin_front_ts/src/views/Main/component/display/components/Editor.vue uses shallowRef<IDomEditor | null>(null), computed<AdminEditorConfig>, and typed image/video insert functions.
admin_front_ts/src/views/Main/component/display/components/Editor.vue no longer contains any, (editorModule as any), or result.url || upload URL fallback.
admin_front_ts/tests/shared/editor/editor-source-quality.test.ts guards the source shape.
docs/knowledge/admin-front-editor-source-quality-review-2026-06-07.md records the source decision and inventory result.
docs/knowledge/admin-front-source-quality-inventory-2026-06-07.md now reports any candidates = 7, as any candidates = 0, catch(error: any) candidates = 0, fallback candidates = 562 after the later upload demo cleanup, and Editor.vue with no configured source-quality finding.
```

Boundary:

```text
This only closes wangEditor wrapper any/as-any and upload URL fallback debt. It does not close later DownloadManager work or general Admin Vue source-quality rows.
```

### ADMIN-FRONT-HARDENING-007 DIcon dynamic-module source-quality debt

Status: resolved on 2026-06-07 as a DIcon Element Plus dynamic-module typing cleanup.

Evidence:

```text
admin_front_ts/src/components/DIcon/src/index.vue types the dynamic module as typeof import('@element-plus/icons-vue').
admin_front_ts/src/components/DIcon/src/index.vue narrows runtime icon names through hasElementPlusIcon(...): name is ElementPlusIconName before module indexing.
admin_front_ts/src/components/DIcon/src/index.vue no longer contains (mod as any), as unknown as Promise<Record<string, Component>>, or Record<string, Component>.
admin_front_ts/tests/shared/icon/dicon-source-quality.test.ts guards the source shape.
docs/knowledge/admin-front-dicon-source-quality-review-2026-06-07.md records the source decision and inventory result.
docs/knowledge/admin-front-source-quality-inventory-2026-06-07.md now reports any candidates = 7, as any candidates = 0, catch(error: any) candidates = 0, fallback candidates = 562 after the later upload demo cleanup, and DIcon/index.vue with only explicit missing-icon/null-state fallback rows.
```

Boundary:

```text
This only closes DIcon dynamic-module any/as-any debt. It does not close general Admin Vue source-quality rows.
```

### ADMIN-FRONT-HARDENING-006 JsonEditor parse-error source-quality debt

Status: resolved on 2026-06-07 as a JsonEditor parse-error and touched-i18n cleanup.

Evidence:

```text
admin_front_ts/src/components/JsonEditor/src/json.ts owns parseJsonEditorValue(), formatJsonEditorValue(), and requireJsonParseErrorMessage().
admin_front_ts/src/components/JsonEditor/src/index.vue catches unknown, uses jsonEditor.* i18n keys, and no longer contains catch (e: any), e?.message ||, modelValue.value || '{}', or raw visible Chinese.
admin_front_ts/tests/shared/json-editor/json-editor-source-quality.test.ts guards source shape, helper behavior, and empty-editor compatibility.
admin_front_ts/tests/shared/i18n/no-visible-chinese.test.ts now includes src/components/JsonEditor/src/index.vue.
docs/knowledge/admin-front-json-editor-source-quality-review-2026-06-07.md records the source decision and inventory result.
docs/knowledge/admin-front-source-quality-inventory-2026-06-07.md now reports any candidates = 7, as any candidates = 0, catch(error: any) candidates = 0, fallback candidates = 562 after the later upload demo cleanup, and JsonEditor/index.vue with no configured source-quality finding.
```

Boundary:

```text
This only closes JsonEditor parse-error, empty-editor-rule, and touched visible-Chinese debt. It does not close demo component, system setting parent-ref fallback, or general Admin Vue source-quality rows.
```

### ADMIN-FRONT-HARDENING-005 Forgot-password request-error fallback debt

Status: resolved on 2026-06-07 as a forgot-password request-error fail-closed cleanup.

Evidence:

```text
admin_front_ts/src/views/Login/composables/useForgotPassword.ts catches unknown and calls requireRequestErrorMessage(...) for send-code and reset.
admin_front_ts/tests/shared/user/forgot-password-source-quality.test.ts rejects catch (error: any), rejects error?.message || fallback, and verifies empty Error.message is not replaced with sendFailed/resetFailed.
docs/knowledge/admin-front-forgot-password-error-source-quality-review-2026-06-07.md records the source decision and inventory result.
docs/knowledge/admin-front-source-quality-inventory-2026-06-07.md now reports any candidates = 7, fallback candidates = 562 after the later upload demo cleanup, and useForgotPassword.ts only has validation predicate logical-or rows.
```

Boundary:

```text
This only closes forgot-password request-error handling debt. It does not close other Login or general Admin Vue source-quality rows.
```

### ADMIN-FRONT-HARDENING-004 Header breadcrumb route-walk source-quality debt

Status: resolved on 2026-06-07 as a typed breadcrumb route-walk cleanup.

Evidence:

```text
admin_front_ts/src/views/Layout/components/Header/index.vue now uses PermissionMenuItem in findBreadcrumbPath() and getBreadcrumbLabel().
admin_front_ts/tests/layout/header-source-quality.test.ts rejects Header any/as any and the retired getPath(...) || [] fallback.
docs/knowledge/admin-front-header-breadcrumb-source-quality-review-2026-06-07.md records the source decision and inventory result.
docs/knowledge/admin-front-source-quality-inventory-2026-06-07.md now reports Header/index.vue with no configured source-quality finding.
```

Boundary:

```text
This only closes Header breadcrumb route-walk debt. It does not close SearchDialog logical-or conditions or the remaining Admin Vue source-quality inventory.
```

### ADMIN-FRONT-HARDENING-003 Direct axios external helper owner decision

Status: resolved on 2026-06-07 as an unused dead helper deletion.

Evidence:

```text
Source search for getRondomImage/getRandomImage/btstu/sjbz/api/tools under admin_front_ts/src and admin_front_ts/tests found no active caller outside the helper file before deletion.
admin_front_ts/src/api/tools.ts was deleted instead of being promoted to a fake owner contract.
admin_front_ts/tests/shared/api/no-direct-external-helper.test.ts guards that the retired helper file stays absent and Admin Vue source does not call api.btstu.cn.
docs/knowledge/admin-front-direct-external-helper-review-2026-06-07.md records the source decision and deletion evidence.
docs/knowledge/admin-front-source-quality-inventory-2026-06-07.md now reports direct external HTTP candidates = 0.
docs/knowledge/frontend-api-inventory-2026-06-07.md no longer contains https://api.btstu.cn/sjbz/api.php.
```

Boundary:

```text
This only closes the direct external random-image helper. It does not close the remaining Admin Vue any/fallback inventory; catch-any is currently zero after later narrow cleanups.
If a future random/background image feature is required, define an explicit owner and contract; do not reintroduce a browser-side external fallback helper.
```

### API-DRIFT-001 Source-only API routes with owner decision still required

Status: resolved on 2026-06-07 after the Admin AI agent test frontend contract call.

Evidence:

```text
docs/knowledge/frontend-backend-api-drift-2026-06-07.md reports 258 exact frontend backend API calls, 258 route-match, 0 method-mismatch, and 0 no-backend-route.
docs/knowledge/api-source-only-route-review-2026-06-07.md classifies the 19 remaining backend admin/canvas source-only routes:
runtime/system = 4
admin queue monitor = 3
retained Canvas payment/wallet = 6
Admin uploadConfig parametric helper covered = 6
owner-decision-required = 0
docs/knowledge/admin-ai-agent-test-contract-review-2026-06-07.md records the final owner decision closure.
```

Boundary:

```text
Resolved does not mean every source-only row is frontend debt. Runtime/system, queue monitor, retained Canvas payment/wallet, and parametric upload helper rows remain documented classifications.
If a new unknown source-only route appears, it must default to owner-decision-required instead of being hidden as backend-only.
```

### API-DRIFT-001 Admin AI agent test owner decision

Status: resolved on 2026-06-07 as an active Admin Vue frontend contract call.

Evidence:

```text
docs/knowledge/admin-ai-agent-test-contract-review-2026-06-07.md records the source decision and frontend/backend evidence.
admin_front_ts/src/api/ai/agents.ts exports AiAgentApi.test and calls POST /api/admin/v1/ai-agents/:id/test.
admin_front_ts/src/views/Main/ai/agents/index.vue renders the test action only for enabled rows under ai_agent_test.
admin_front_ts/tests/shared/ai/ai-agent-api.test.ts guards the test route wrapper and page wiring.
docs/knowledge/api-source-only-route-review-2026-06-07.md now reports 0 owner-decision-required rows and no ai-agents/:id/test row.
```

Boundary:

```text
This only closes the Admin AI agent test owner decision. It does not classify runtime/system, queue-monitor, Canvas payment/wallet, or parametric upload helper source-only rows as bugs.
Do not move agent test through provider test, and do not accept provider/model/API key overrides from the browser for this action.
```

### API-DRIFT-001 Admin user status owner decision

Status: resolved on 2026-06-07 as an active Admin Vue frontend contract call.

Evidence:

```text
docs/knowledge/admin-user-status-contract-review-2026-06-07.md records the source decision and frontend/backend evidence.
admin_front_ts/src/api/user/users.ts exports UsersListApi.changeStatus and calls PATCH /api/admin/v1/users/:id/status.
admin_front_ts/src/views/Main/user/userManager/components/UserList/index.vue renders status and calls toggleStatus(row, CommonEnum.YES|NO) under user_userManager_edit.
admin_front_ts/tests/shared/user/user-list.test.ts guards the status route wrapper and page wiring.
docs/knowledge/api-source-only-route-review-2026-06-07.md now reports 0 owner-decision-required rows and no users/:id/status row.
```

Boundary:

```text
This only closes the Admin user status owner decision. Admin AI agent test was closed later in the same API-DRIFT-001 sequence.
Do not move user status mutation into batchEdit/profile update; the dedicated status route is the active contract.
```

### API-DRIFT-001 Canvas auth logout owner decision

Status: resolved on 2026-06-07 as an active Canvas frontend contract call.

Evidence:

```text
docs/knowledge/canvas-auth-logout-contract-review-2026-06-07.md records the source decision and frontend/backend evidence.
canvas_front_next/src/services/api/auth.ts exports logout(token) and calls POST /api/canvas/v1/auth/logout.
canvas_front_next/src/stores/use-user-store.ts uses async logout() to revoke backend session before clearSession().
canvas_front_next/src/components/layout/user-status-actions.tsx account menu uses store logout(), not clearSession().
docs/knowledge/api-source-only-route-review-2026-06-07.md no longer contains the Canvas auth/logout row; API-DRIFT-001 is now resolved after the later Admin user status and Admin AI agent test closures.
```

Boundary:

```text
This only closes the Canvas auth/logout owner decision. Admin user status and Admin AI agent test were closed later in the same API-DRIFT-001 sequence.
Backend logout failure preserves the local browser session; do not add best-effort local cleanup after revoke failure.
```

### CANVAS-DOC-002 Canvas asset route alias ambiguity

Status: resolved on 2026-06-07 as a dead Canvas Next page cleanup.

Evidence:

```text
docs/knowledge/canvas-asset-route-contract-review-2026-06-07.md records live MySQL/source evidence: canvas_assets_page is active at /assets and there is no active /asset-library Canvas PAGE.
canvas_front_next/src/app/(user)/asset-library/page.tsx was removed.
canvas_front_next/tests/shared/canvas-rbac-shell.test.ts explicitly rejects the dead asset-library page and keeps the active asset API caller guard on asset-picker-modal.tsx.
docs/knowledge/runtime-inventory-2026-06-07.md lists (user)/assets and no (user)/asset-library route.
```

Boundary:

```text
This only closes the top-level Canvas asset route ambiguity. It does not rewrite /assets "我的素材", and it does not change GET /api/canvas/v1/assets.
```

### CANVAS-DOC-001 Canvas RBAC text-generation permission drift

Status: resolved on 2026-06-07 as a dead frontend permission type drift cleanup.

Evidence:

```text
docs/knowledge/canvas-rbac-permission-contract-review-2026-06-07.md records live MySQL/source evidence: canvas_ai_text_generate is a soft-deleted orphan row, not an active Canvas BUTTON code.
canvas_front_next/src/features/rbac/canvas-permissions.ts no longer defines canvas_ai_text_generate.
canvas_front_next/tests/shared/canvas-rbac-shell.test.ts explicitly rejects canvas_ai_text_generate from the canonical Canvas RBAC registry.
docs/contracts/admin-api-v1.md lists active Canvas BUTTON rows without canvas_ai_text_generate.
```

Boundary:

```text
This only closes the text-generation RBAC permission-code drift. It does not change Canvas AI text generation URL, agent scene, provider/model dispatch, or the separate asset route cleanup recorded under CANVAS-DOC-002.
```

### CANVAS-DOC-003 Canvas AI request model field semantics

Status: resolved on 2026-06-07 as an agent_id-only request contract guard fix.

Evidence:

```text
docs/knowledge/canvas-ai-request-contract-review-2026-06-07.md records Canvas chat/image/video active request shapes and forbidden request fields: model/provider/api_key/base_url.
admin_back_go/internal/module/ai/chat/transport/canvas/request.go and admin_back_go/internal/module/ai/video/transport/canvas/request.go no longer expose json:"model".
admin_back_go/internal/module/ai/internal/canvasrequest/json.go rejects model/provider/api_key/base_url before chat/video services are called.
admin_back_go/internal/module/ai/chat/transport/canvas/handler_test.go and admin_back_go/internal/module/ai/video/transport/canvas/handler_test.go verify override rejection and empty HTTP-boundary ModelID.
canvas_front_next/src/services/api/image.test.ts and canvas_front_next/src/services/api/video.test.ts verify the active frontend clients do not send model overrides.
```

Boundary:

```text
This only closes Canvas AI request model-field semantics. It does not change the separate asset route cleanup recorded under CANVAS-DOC-002.
```

### ADMIN-FRONT-HARDENING-002 Layout SearchDialog typed route-walk gap

Status: resolved on 2026-06-07 as a typed route-search guard fix.

Evidence:

```text
admin_front_ts/tests/layout/search-dialog-source-quality.test.ts guards src/views/Layout/components/Header/components/SearchDialog.vue against any/as any.
admin_front_ts/src/views/Layout/components/Header/components/SearchDialog.vue now walks PermissionMenuItem data through SearchMenuNode/SearchResultItem types instead of icon?: any, nodes: any[], or userStore.permissions as any[].
docs/knowledge/admin-front-source-quality-inventory-2026-06-07.md now records this file only for remaining logical-or fallback review evidence, not any/as any route walking.
npm run test -- tests/layout/search-dialog-source-quality.test.ts passed.
npm run typecheck passed.
```

Boundary:

```text
This only closes the Layout SearchDialog route-walk type debt. It does not claim all Admin Vue any/fallback or direct external HTTP debt is closed.
```

### ADMIN-FRONT-HARDENING-001 TableActions i18n guard gap

Status: resolved on 2026-06-07 as a shared-component i18n guard fix.

Evidence:

```text
admin_front_ts/tests/shared/i18n/no-visible-chinese.test.ts now guards src/components/Table/src/components/TableActions.vue.
admin_front_ts/src/components/Table/src/components/TableActions.vue uses vue-i18n key common.actions.refresh instead of raw visible text “刷新”.
npm run test -- tests/shared/i18n/no-visible-chinese.test.ts passed.
```

Boundary:

```text
This only closes the TableActions visible-text guard gap. It does not claim all Admin Vue any/fallback or CRUD primitive exceptions are closed.
```

### CANVAS-DOC-004 Canvas wallet/recharge backend route retention wording

Status: resolved as documentation boundary on 2026-06-07; not a route smoke claim.

Evidence:

```text
docs/contracts/admin-api-v1.md now lists the exact retained Canvas payment/wallet基础域 routes and states they are not Canvas AI free-generation dependencies.
docs/knowledge/backend-route-contract-drift-2026-06-07.md now reports 280 contract-exact rows, 0 source-docs-only rows, and 0 undocumented-exact rows after regeneration.
```

Boundary:

```text
This closes the wording drift only. It does not claim a fresh Canvas payment/wallet smoke run, and it does not reintroduce wallet/recharge UI, AI billing, balance debit, or recharge actions into Canvas free-generation.
```

### UPLOAD-RUNTIME-001 upload-token full smoke blocked by undecryptable COS secrets

Status: resolved by runtime data repair, not code change.

Evidence:

```text
2026-05-30 live recheck after re-entering the COS upload driver secrets:
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account 15671628271 -Password 123456
passed and reported upload_token_probe=passed, upload_token_code=0, upload_token_provider=cos.
```

Boundary:

```text
The fix was re-entering secrets for the current APP_SECRET-derived secretbox key.
Do not copy old encrypted DB blobs across APP_SECRET changes.
```
