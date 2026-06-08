# Admin Front Source Quality Inventory Snapshot

Generated at: 2026-06-08 23:25:12 +08:00

This is a regex source inventory, not type-aware semantic proof. It is meant to expose current Admin Vue quality debt shape before narrow refactors; it is not a claim that every row is a bug.

## Source summary

| Fact | Count |
| --- | --- |
| Source files scanned | `274` |
| Findings found | `511` |
| any candidates | `0` |
| as any candidates | `0` |
| Record<string, any> candidates | `0` |
| catch(error: any) candidates | `0` |
| logical-or fallback candidates | `320` |
| nullish-coalescing fallback candidates | `125` |
| optional-chain fallback candidates | `66` |
| fallback candidates | `511` |
| direct external HTTP candidates | `0` |

## Priority evidence

| Source | Current evidence |
| --- | --- |
| `admin_front_ts/src/views/Layout/components/Header/index.vue` | no regex finding in configured categories; keep only if another generated inventory owns this evidence |
| `admin_front_ts/src/views/Layout/components/Header/components/SearchDialog.vue` | L125 `logical-or-fallback` `item.label.toLowerCase().includes(query) \|\| item.path.toLowerCase().includes(query)`<br>L146 `logical-or-fallback` `if ((e.ctrlKey \|\| e.metaKey) && e.code === 'KeyK') {` |
| `admin_front_ts/src/views/Login/composables/useForgotPassword.ts` | L92 `logical-or-fallback` `if (!forgotForm.account \|\| !forgotForm.code) return ElMessage.warning(t('forgotPassword.validation.fullInfoRequired'))`<br>L97 `logical-or-fallback` `if (!forgotForm.newPassword \|\| !forgotForm.confirmPassword) return ElMessage.warning(t('forgotPassword.validation.passwordRequired'))`<br>L101 `logical-or-fallback` `if (pwd.length < 6 \|\| pwd.length > 128) return ElMessage.warning(t('forgotPassword.validation.passwordLength'))` |
| `admin_front_ts/src/components/JsonEditor/src/index.vue` | no regex finding in configured categories; keep only if another generated inventory owns this evidence |
| `admin_front_ts/src/components/DIcon/src/index.vue` | L51 `nullish-fallback` `if (epIconCache.has(name)) return epIconCache.get(name) ?? null`<br>L60 `nullish-fallback` `const value = comp ?? null`<br>L71 `logical-or-fallback` `if (!iconName \|\| isIconify.value) {`<br>L77 `nullish-fallback` `resolvedEpIcon.value = epIconCache.get(iconName) ?? null` |
| `admin_front_ts/src/views/Main/component/display/components/Editor.vue` | no regex finding in configured categories; keep only if another generated inventory owns this evidence |
| `admin_front_ts/src/components/DownloadManager/src/download.ts` | no regex finding in configured categories; keep only if another generated inventory owns this evidence |
| `admin_front_ts/src/views/Main/component/download/index.vue` | no regex finding in configured categories; keep only if another generated inventory owns this evidence |
| `admin_front_ts/src/views/Main/test/index.vue` | no regex finding in configured categories; keep only if another generated inventory owns this evidence |
| `admin_front_ts/src/hooks/web/useValidator.ts` | L28 `logical-or-fallback` `if (val.length < min \|\| val.length > max) {` |
| `admin_front_ts/src/views/Main/component/upload/index.vue` | no regex finding in configured categories; keep only if another generated inventory owns this evidence |
| `admin_front_ts/src/views/Main/component/form/index.vue` | no regex finding in configured categories; keep only if another generated inventory owns this evidence |
| `admin_front_ts/src/views/Main/component/display/index.vue` | no regex finding in configured categories; keep only if another generated inventory owns this evidence |
| `admin_front_ts/src/views/Main/component/effect/components/ParticleBackground.vue` | L102 `logical-or-fallback` `if (mouse.x === null \|\| mouse.y === null) {` |

## Top files by finding count

| Source | Findings |
| --- | ---: |
| `admin_front_ts/src/views/Main/ai/chat/index.vue` | `38` |
| `admin_front_ts/src/views/Main/ai/agents/components/AgentKnowledgeDialog/index.vue` | `15` |
| `admin_front_ts/src/views/Main/system/mail/components/MailLogPanel.vue` | `14` |
| `admin_front_ts/src/views/Main/ai/chat/components/MessageInput/index.vue` | `13` |
| `admin_front_ts/src/views/Main/system/sms/components/SmsLogPanel.vue` | `13` |
| `admin_front_ts/src/views/Main/ai/providers/index.vue` | `12` |
| `admin_front_ts/src/views/Main/ai/agents/index.vue` | `11` |
| `admin_front_ts/src/components/DownloadManager/src/index.vue` | `10` |
| `admin_front_ts/src/views/Main/ai/knowledge/components/RetrievalTestDialog/index.vue` | `10` |
| `admin_front_ts/src/views/Main/personal/components/Security/index.vue` | `10` |
| `admin_front_ts/src/views/Main/system/mail/components/MailConfigPanel.vue` | `10` |
| `admin_front_ts/src/views/Main/system/sms/components/SmsConfigPanel.vue` | `10` |
| `admin_front_ts/src/components/Search/src/index.vue` | `9` |
| `admin_front_ts/src/views/Login/composables/useLoginForm.ts` | `9` |
| `admin_front_ts/src/views/Main/ai/chat/composables/useConversationSessions.ts` | `9` |
| `admin_front_ts/src/views/Main/permission/role/role-matrix.ts` | `8` |
| `admin_front_ts/src/views/Main/system/mail/components/MailTemplatePanel.vue` | `8` |
| `admin_front_ts/src/views/Main/system/sms/components/SmsTemplatePanel.vue` | `8` |
| `admin_front_ts/src/components/RemoteSelect/src/index.vue` | `7` |
| `admin_front_ts/src/views/Main/system/exportTask/index.vue` | `7` |

## Findings by kind

| Kind | Count |
| --- | ---: |
| `logical-or-fallback` | `320` |
| `nullish-fallback` | `125` |
| `optional-chain-fallback` | `66` |

## Full findings

| Kind | Source | Line | Snippet |
| --- | --- | ---: | --- |
| `logical-or-fallback` | `admin_front_ts/src/api/ai/agents.ts` | `170` | `if (!Number.isInteger(id) \|\| id <= 0) throw new Error(`${label} must be a positive integer`)` |
| `nullish-fallback` | `admin_front_ts/src/api/ai/agents.ts` | `193` | `status: params.status ?? 1,` |
| `nullish-fallback` | `admin_front_ts/src/api/ai/agents.ts` | `242` | `const id = positiveID(params.id ?? 0, 'AI agent id')` |
| `logical-or-fallback` | `admin_front_ts/src/api/ai/chat.ts` | `23` | `if (!Number.isInteger(value) \|\| value <= 0) throw new Error(`${label} must be a positive integer`)` |
| `logical-or-fallback` | `admin_front_ts/src/api/ai/conversations.ts` | `61` | `if (!Number.isInteger(id) \|\| id <= 0) throw new Error('AI conversation id must be a positive integer')` |
| `logical-or-fallback` | `admin_front_ts/src/api/ai/knowledge.ts` | `202` | `if (!Number.isInteger(id) \|\| id <= 0) throw new Error(`${label} must be a positive integer`)` |
| `nullish-fallback` | `admin_front_ts/src/api/ai/knowledge.ts` | `264` | `const id = positiveID(params.id ?? 0, 'AI knowledge base id')` |
| `nullish-fallback` | `admin_front_ts/src/api/ai/knowledge.ts` | `272` | `const createDocument = (params: AiKnowledgeDocumentMutationParams) => request.post<AiKnowledgeCreateResponse, AiKnowledgeDocumentMutationBody>(`${ADMIN_API_PREFIX}/ai-knowledge-bases/${positiveID(params.knowledge_base_id ?? 0, 'AI knowledge base id')}/documents`, documentBody(params))` |
| `nullish-fallback` | `admin_front_ts/src/api/ai/knowledge.ts` | `274` | `const id = positiveID(params.id ?? 0, 'AI knowledge document id')` |
| `logical-or-fallback` | `admin_front_ts/src/api/ai/messages.ts` | `77` | `if (!Number.isInteger(id) \|\| id <= 0) throw new Error(`${label} must be a positive integer`)` |
| `logical-or-fallback` | `admin_front_ts/src/api/ai/prompts.ts` | `73` | `if (!Number.isInteger(id) \|\| id <= 0) throw new Error(`${label} must be a positive integer`)` |
| `logical-or-fallback` | `admin_front_ts/src/api/ai/providers.ts` | `147` | `if (!Number.isInteger(id) \|\| id <= 0) throw new Error(`${label} must be a positive integer`)` |
| `nullish-fallback` | `admin_front_ts/src/api/ai/providers.ts` | `162` | `const driver = params.driver ?? params.engine_type ?? 'openai'` |
| `nullish-fallback` | `admin_front_ts/src/api/ai/providers.ts` | `167` | `base_url: params.base_url ?? '',` |
| `nullish-fallback` | `admin_front_ts/src/api/ai/providers.ts` | `176` | `const driver = params.driver ?? params.engine_type ?? 'openai'` |
| `nullish-fallback` | `admin_front_ts/src/api/ai/providers.ts` | `180` | `base_url: params.base_url ?? '',` |
| `nullish-fallback` | `admin_front_ts/src/api/ai/providers.ts` | `200` | `const id = positiveID(params.id ?? 0, 'AI provider id')` |
| `logical-or-fallback` | `admin_front_ts/src/api/ai/runs.ts` | `247` | `if (!Number.isInteger(id) \|\| id <= 0) throw new Error('AI run id must be a positive integer')` |
| `logical-or-fallback` | `admin_front_ts/src/api/ai/runs.ts` | `287` | `return value === 'admin' \|\| value === 'app' \|\| value === 'canvas'` |
| `logical-or-fallback` | `admin_front_ts/src/api/ai/runs.ts` | `300` | `if (!response.dict \|\| typeof response.dict !== 'object') {` |
| `logical-or-fallback` | `admin_front_ts/src/api/ai/tools.ts` | `118` | `if (!Number.isInteger(id) \|\| id <= 0) throw new Error(`${label} must be a positive integer`)` |
| `nullish-fallback` | `admin_front_ts/src/api/ai/tools.ts` | `150` | `code_hint: params.code_hint ?? '',` |
| `nullish-fallback` | `admin_front_ts/src/api/ai/tools.ts` | `162` | `const id = positiveID(params.id ?? 0, 'AI tool id')` |
| `logical-or-fallback` | `admin_front_ts/src/api/payment/config.ts` | `89` | `if (!Number.isInteger(value) \|\| value <= 0) throw new Error('payment config id must be positive')` |
| `nullish-fallback` | `admin_front_ts/src/api/payment/config.ts` | `97` | `update: (payload: PaymentConfigMutationPayload) => request.put<void, PaymentConfigMutationPayload>(`${ADMIN_API_PREFIX}/payment/configs/${positiveID(payload.id ?? 0)}`, payload),` |
| `logical-or-fallback` | `admin_front_ts/src/api/payment/recharges.ts` | `89` | `if (!Number.isInteger(value) \|\| value <= 0) throw new Error('payment recharge id must be positive')` |
| `logical-or-fallback` | `admin_front_ts/src/api/permission/authPlatform.ts` | `110` | `if (typeof value !== 'number' \|\| !Number.isInteger(value) \|\| value <= 0) {` |
| `logical-or-fallback` | `admin_front_ts/src/api/permission/role.ts` | `51` | `if (typeof value !== 'number' \|\| !Number.isInteger(value) \|\| value <= 0) {` |
| `logical-or-fallback` | `admin_front_ts/src/api/system/clientVersion.ts` | `118` | `if (typeof id !== 'number' \|\| !Number.isInteger(id) \|\| id <= 0) {` |
| `logical-or-fallback` | `admin_front_ts/src/api/system/clientVersion.ts` | `128` | `if (id.length !== 1 \|\| singleID === undefined) {` |
| `logical-or-fallback` | `admin_front_ts/src/api/system/exportTask.ts` | `42` | `if (typeof value !== 'number' \|\| !Number.isInteger(value) \|\| value <= 0) {` |
| `logical-or-fallback` | `admin_front_ts/src/api/system/log.ts` | `53` | `keyword: keyword \|\| undefined,` |
| `logical-or-fallback` | `admin_front_ts/src/api/system/log.ts` | `54` | `level: level \|\| undefined,` |
| `logical-or-fallback` | `admin_front_ts/src/api/system/mail.ts` | `160` | `if (typeof id !== 'number' \|\| !Number.isInteger(id) \|\| id <= 0) {` |
| `logical-or-fallback` | `admin_front_ts/src/api/system/notification.ts` | `112` | `if (typeof value !== 'number' \|\| !Number.isInteger(value) \|\| value <= 0) {` |
| `logical-or-fallback` | `admin_front_ts/src/api/system/notificationTask.ts` | `97` | `if (typeof id !== 'number' \|\| !Number.isInteger(id) \|\| id <= 0) {` |
| `logical-or-fallback` | `admin_front_ts/src/api/system/operationLog.ts` | `30` | `if (!Array.isArray(date) \|\| date.length < 2) {` |
| `logical-or-fallback` | `admin_front_ts/src/api/system/operationLog.ts` | `37` | `if (!normalizedStart \|\| !normalizedEnd) {` |
| `logical-or-fallback` | `admin_front_ts/src/api/system/operationLog.ts` | `80` | `if (typeof value !== 'number' \|\| !Number.isInteger(value) \|\| value <= 0) {` |
| `logical-or-fallback` | `admin_front_ts/src/api/system/setting.ts` | `95` | `if (typeof value !== 'number' \|\| !Number.isInteger(value) \|\| value <= 0) {` |
| `logical-or-fallback` | `admin_front_ts/src/api/system/sms.ts` | `155` | `if (typeof id !== 'number' \|\| !Number.isInteger(id) \|\| id <= 0) {` |
| `logical-or-fallback` | `admin_front_ts/src/api/system/uploadConfig.ts` | `259` | `if (typeof value !== 'number' \|\| !Number.isInteger(value) \|\| value <= 0) {` |
| `logical-or-fallback` | `admin_front_ts/src/api/user/users.ts` | `50` | `if (typeof value !== 'number' \|\| !Number.isInteger(value) \|\| value <= 0) {` |
| `logical-or-fallback` | `admin_front_ts/src/components/AppCaptcha/src/AppCaptchaOverlay.vue` | `40` | `if (!props.challenge \|\| props.loading \|\| props.verifying) return` |
| `nullish-fallback` | `admin_front_ts/src/components/AppDialog/src/dialog.ts` | `28` | `return toCssLength(mobileWidth) ?? DEFAULT_APP_DIALOG_MOBILE_WIDTH` |
| `nullish-fallback` | `admin_front_ts/src/components/AppDialog/src/dialog.ts` | `31` | `return toCssLength(width) ?? DEFAULT_APP_DIALOG_WIDTH` |
| `nullish-fallback` | `admin_front_ts/src/components/AppDialog/src/dialog.ts` | `65` | `return draggable ?? !isMobile` |
| `nullish-fallback` | `admin_front_ts/src/components/DIcon/src/index.vue` | `51` | `if (epIconCache.has(name)) return epIconCache.get(name) ?? null` |
| `nullish-fallback` | `admin_front_ts/src/components/DIcon/src/index.vue` | `60` | `const value = comp ?? null` |
| `logical-or-fallback` | `admin_front_ts/src/components/DIcon/src/index.vue` | `71` | `if (!iconName \|\| isIconify.value) {` |
| `nullish-fallback` | `admin_front_ts/src/components/DIcon/src/index.vue` | `77` | `resolvedEpIcon.value = epIconCache.get(iconName) ?? null` |
| `logical-or-fallback` | `admin_front_ts/src/components/DownloadManager/src/index.vue` | `55` | `<el-icon v-else-if="item.status === 'failed' \|\| (item.status === 'downloading' && item.downloaded === 0)" class="error" :size="24">` |
| `logical-or-fallback` | `admin_front_ts/src/components/DownloadManager/src/index.vue` | `68` | `<div v-if="item.status === 'downloading' \|\| item.status === 'paused'" class="progress-wrapper">` |
| `logical-or-fallback` | `admin_front_ts/src/components/DownloadManager/src/index.vue` | `79` | `<div v-if="item.status !== 'downloading' \|\| item.downloaded === 0" class="status-message">` |
| `logical-or-fallback` | `admin_front_ts/src/components/DownloadManager/src/index.vue` | `83` | `<span v-else-if="item.status === 'failed' \|\| (item.status === 'downloading' && item.downloaded === 0)" class="error-text">` |
| `logical-or-fallback` | `admin_front_ts/src/components/DownloadManager/src/index.vue` | `84` | `{{ item.error \|\| t('download.failed') }}` |
| `logical-or-fallback` | `admin_front_ts/src/components/DownloadManager/src/index.vue` | `128` | `v-if="item.status === 'failed' \|\| item.status === 'cancelled' \|\| (item.status === 'downloading' && item.downloaded === 0)"` |
| `logical-or-fallback` | `admin_front_ts/src/components/DownloadManager/src/index.vue` | `184` | `return downloads.value.some(d => d.status === 'downloading' \|\| d.status === 'pending')` |
| `logical-or-fallback` | `admin_front_ts/src/components/DownloadManager/src/index.vue` | `195` | `return ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt'].includes(ext \|\| '')` |
| `logical-or-fallback` | `admin_front_ts/src/components/DownloadManager/src/index.vue` | `200` | `return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg', 'bmp'].includes(ext \|\| '')` |
| `logical-or-fallback` | `admin_front_ts/src/components/DownloadManager/src/index.vue` | `205` | `return ['mp4', 'avi', 'mkv', 'mov', 'wmv', 'flv', 'webm'].includes(ext \|\| '')` |
| `nullish-fallback` | `admin_front_ts/src/components/EmojiPicker/src/index.vue` | `55` | `const activeCategory = computed(() => emojiCategories[activeTab.value] ?? defaultCategory)` |
| `logical-or-fallback` | `admin_front_ts/src/components/MarkdownRenderer/src/index.vue` | `89` | `return md.render(props.content \|\| '')` |
| `logical-or-fallback` | `admin_front_ts/src/components/MarkdownRenderer/src/index.vue` | `98` | `const code = decodeURIComponent(target.dataset.code \|\| '')` |
| `logical-or-fallback` | `admin_front_ts/src/components/NotificationRuntime/src/index.vue` | `52` | `type: data.notification_type \|\| 'info',` |
| `logical-or-fallback` | `admin_front_ts/src/components/RemoteSelect/src/index.vue` | `49` | `if (!value \|\| !Array.isArray(value.list)) {` |
| `logical-or-fallback` | `admin_front_ts/src/components/RemoteSelect/src/index.vue` | `53` | `if (!value.page \|\| typeof value.page.total !== 'number') {` |
| `logical-or-fallback` | `admin_front_ts/src/components/RemoteSelect/src/index.vue` | `159` | `return typeof value === 'string' \|\| typeof value === 'number' ? String(value) : ''` |
| `logical-or-fallback` | `admin_front_ts/src/components/RemoteSelect/src/index.vue` | `164` | `if (typeof value === 'string' \|\| typeof value === 'number') {` |
| `nullish-fallback` | `admin_front_ts/src/components/RemoteSelect/src/index.vue` | `168` | `return String(value ?? '')` |
| `logical-or-fallback` | `admin_front_ts/src/components/RemoteSelect/src/index.vue` | `200` | `(error.message === remoteSelectContractErrors.list \|\|` |
| `logical-or-fallback` | `admin_front_ts/src/components/RemoteSelect/src/index.vue` | `217` | `if (loading.value \|\| loadingMore.value \|\| !hasMore.value) {` |
| `logical-or-fallback` | `admin_front_ts/src/components/Search/src/index.vue` | `80` | `if (typeof value === 'string' \|\| typeof value === 'number' \|\| value === null \|\| value === undefined) {` |
| `logical-or-fallback` | `admin_front_ts/src/components/Search/src/index.vue` | `95` | `if (typeof value === 'string' \|\| typeof value === 'number' \|\| value === null \|\| value === undefined) {` |
| `logical-or-fallback` | `admin_front_ts/src/components/Search/src/index.vue` | `99` | `if (isStringArray(value) \|\| isNumberArray(value)) {` |
| `logical-or-fallback` | `admin_front_ts/src/components/Search/src/index.vue` | `134` | `const minCount = computed(() => Math.max(1, Number(props.collapseCount \|\| 1)))` |
| `logical-or-fallback` | `admin_front_ts/src/components/Search/src/index.vue` | `136` | `const showToggle = computed(() => wrapped.value \|\| collapsed.value)` |
| `nullish-fallback` | `admin_front_ts/src/components/Search/src/index.vue` | `174` | `return typeof width === 'string' ? width : `${width ?? fallback}px`` |
| `logical-or-fallback` | `admin_front_ts/src/components/Search/src/index.vue` | `260` | `:label-field="field.labelField \|\| 'label'"` |
| `logical-or-fallback` | `admin_front_ts/src/components/Search/src/index.vue` | `261` | `:value-field="field.valueField \|\| 'value'"` |
| `logical-or-fallback` | `admin_front_ts/src/components/Search/src/index.vue` | `262` | `:keyword-field="field.keywordField \|\| 'keyword'"` |
| `logical-or-fallback` | `admin_front_ts/src/components/SendCode/src/index.vue` | `49` | `return !props.account \|\| timer.value > 0 \|\| props.sendDisabled` |
| `logical-or-fallback` | `admin_front_ts/src/components/SendCode/src/index.vue` | `93` | `const useMobileLayout = computed(() => props.mobile \|\| isMobile.value)` |
| `logical-or-fallback` | `admin_front_ts/src/components/SendCode/src/index.vue` | `103` | `:placeholder="placeholder \|\| t('personal.security.codePlaceholder')"` |
| `nullish-fallback` | `admin_front_ts/src/components/Table/src/index.vue` | `65` | `return { align: 'center', prop: prop ?? key, ...rest }` |
| `logical-or-fallback` | `admin_front_ts/src/components/Table/src/index.vue` | `88` | `const onRowClick = (row: Row) => { if (!props.selectable \|\| props.rowClickSelect === false) return; tableRef.value?.toggleRowSelection(row) }` |
| `optional-chain-fallback` | `admin_front_ts/src/components/Table/src/index.vue` | `88` | `const onRowClick = (row: Row) => { if (!props.selectable \|\| props.rowClickSelect === false) return; tableRef.value?.toggleRowSelection(row) }` |
| `logical-or-fallback` | `admin_front_ts/src/components/Table/src/index.vue` | `113` | `<ElTableColumn v-for="col in visibleColumns" :key="getColumnKey(col)" :label="col.label" :show-overflow-tooltip="(col.overflowTooltip ?? props.autoOverflowTooltip) && (!!col.width \|\| !!col.minWidth)" v-bind="getColumnBindings(col)">` |
| `nullish-fallback` | `admin_front_ts/src/components/Table/src/index.vue` | `113` | `<ElTableColumn v-for="col in visibleColumns" :key="getColumnKey(col)" :label="col.label" :show-overflow-tooltip="(col.overflowTooltip ?? props.autoOverflowTooltip) && (!!col.width \|\| !!col.minWidth)" v-bind="getColumnBindings(col)">` |
| `nullish-fallback` | `admin_front_ts/src/components/Table/src/types.ts` | `30` | `const key = column.key ?? column.prop` |
| `logical-or-fallback` | `admin_front_ts/src/components/Table/src/types.ts` | `32` | `if (typeof key !== 'string' \|\| key.trim() === '') {` |
| `nullish-fallback` | `admin_front_ts/src/components/Table/src/types.ts` | `40` | `return column.prop ?? tableColumnKey<Row>(column)` |
| `nullish-fallback` | `admin_front_ts/src/components/Table/src/useTable.ts` | `57` | `...(unref(searchForm) ?? {}),` |
| `logical-or-fallback` | `admin_front_ts/src/components/TauriManager/src/index.vue` | `35` | `return value === 'windows-x86_64' \|\| value === 'darwin-x86_64' ? value : ''` |
| `nullish-fallback` | `admin_front_ts/src/components/TauriManager/src/index.vue` | `56` | `contentLength.value = event.data.contentLength ?? 0` |
| `logical-or-fallback` | `admin_front_ts/src/components/UpFile/src/index.vue` | `67` | `:disabled="disabled \|\| uploading"` |
| `logical-or-fallback` | `admin_front_ts/src/components/UpFile/src/index.vue` | `75` | `<span class="file-name">{{ fileName \|\| '已上传文件' }}</span>` |
| `logical-or-fallback` | `admin_front_ts/src/components/UpMedia/src/index.vue` | `24` | `const defaultFolder = computed(() => props.folderName \|\| (props.type === 'video' ? 'videos' : 'images'))` |
| `logical-or-fallback` | `admin_front_ts/src/hooks/useExportSubmit.ts` | `18` | `ElNotification.success({ message: data.message \|\| t('common.export.submitted') })` |
| `logical-or-fallback` | `admin_front_ts/src/hooks/useNetworkStatus.ts` | `28` | `if (!lastOfflineAt.value \|\| isOnline.value) {` |
| `nullish-fallback` | `admin_front_ts/src/hooks/useWebSocket.ts` | `68` | `ws: computed(() => consumerHandle?.getSnapshot().ws ?? null),` |
| `optional-chain-fallback` | `admin_front_ts/src/hooks/useWebSocket.ts` | `68` | `ws: computed(() => consumerHandle?.getSnapshot().ws ?? null),` |
| `logical-or-fallback` | `admin_front_ts/src/hooks/web/useValidator.ts` | `28` | `if (val.length < min \|\| val.length > max) {` |
| `nullish-fallback` | `admin_front_ts/src/hooks/web/useWatermark.ts` | `38` | `const width = options.width ?? 300` |
| `nullish-fallback` | `admin_front_ts/src/hooks/web/useWatermark.ts` | `39` | `const height = options.height ?? 240` |
| `nullish-fallback` | `admin_front_ts/src/hooks/web/useWatermark.ts` | `45` | `cans.rotate(((options.rotate ?? -20) * Math.PI) / 180)` |
| `nullish-fallback` | `admin_front_ts/src/hooks/web/useWatermark.ts` | `46` | `cans.font = `${options.fontSize ?? 15}px ${options.font ?? 'Vedana'}`` |
| `nullish-fallback` | `admin_front_ts/src/hooks/web/useWatermark.ts` | `47` | `cans.fillStyle = options.color ?? 'rgba(0, 0, 0, 0.15)'` |
| `nullish-fallback` | `admin_front_ts/src/hooks/web/useWatermark.ts` | `59` | `div.style.zIndex = (options.zIndex ?? 100000000).toString()` |
| `logical-or-fallback` | `admin_front_ts/src/i18n/index.ts` | `10` | `locale: Cookies.get('lang') \|\| 'zh-CN',` |
| `logical-or-fallback` | `admin_front_ts/src/lib/http/auth-session.ts` | `97` | `if (originalRequest.url?.includes(REFRESH_PATH) \|\| originalRequest._retry) {` |
| `optional-chain-fallback` | `admin_front_ts/src/lib/http/auth-session.ts` | `97` | `if (originalRequest.url?.includes(REFRESH_PATH) \|\| originalRequest._retry) {` |
| `logical-or-fallback` | `admin_front_ts/src/lib/http/client.ts` | `122` | `if (typeof data !== 'object' \|\| data === null \|\| !('msg' in data)) {` |
| `logical-or-fallback` | `admin_front_ts/src/lib/http/headers.ts` | `14` | `if (value === undefined \|\| value === null \|\| value === '') {` |
| `nullish-fallback` | `admin_front_ts/src/lib/http/headers.ts` | `25` | `...(config.headers ?? {}),` |
| `logical-or-fallback` | `admin_front_ts/src/lib/navigation/notification-link.ts` | `11` | `if (link === legacyPrefix \|\| link.startsWith(`${legacyPrefix}?`)) {` |
| `nullish-fallback` | `admin_front_ts/src/lib/realtime/websocket-client.ts` | `104` | `const maxReconnectAttempts = Math.max(...Array.from(consumers).map((consumer) => consumer.maxReconnectAttempts ?? 10), 10)` |
| `nullish-fallback` | `admin_front_ts/src/lib/realtime/websocket-client.ts` | `105` | `const reconnectInterval = Math.min(...Array.from(consumers).map((consumer) => consumer.reconnectInterval ?? 3000), 3000)` |
| `logical-or-fallback` | `admin_front_ts/src/lib/realtime/websocket-client.ts` | `151` | `if (!isRecord(raw) \|\| typeof raw.type !== 'string') {` |
| `logical-or-fallback` | `admin_front_ts/src/lib/realtime/websocket-client.ts` | `198` | `if (sharedWs?.readyState === WebSocket.OPEN \|\| sharedWs?.readyState === WebSocket.CONNECTING) {` |
| `optional-chain-fallback` | `admin_front_ts/src/lib/realtime/websocket-client.ts` | `198` | `if (sharedWs?.readyState === WebSocket.OPEN \|\| sharedWs?.readyState === WebSocket.CONNECTING) {` |
| `logical-or-fallback` | `admin_front_ts/src/lib/upload/uploadClient.ts` | `119` | `file_name: params.fileName \|\| 'file',` |
| `logical-or-fallback` | `admin_front_ts/src/lib/upload/uploadClient.ts` | `120` | `file_size: params.fileSize \|\| 1,` |
| `logical-or-fallback` | `admin_front_ts/src/lib/upload/uploadClient.ts` | `121` | `file_kind: params.fileKind \|\| 'file',` |
| `logical-or-fallback` | `admin_front_ts/src/lib/upload/url.ts` | `8` | `let domain = (bucketDomain \|\| fallbackDomain).trim().replace(/\/+$/, '')` |
| `logical-or-fallback` | `admin_front_ts/src/platform/tauri/env.ts` | `21` | `return state.minimized \|\| !state.focused \|\| !state.visible` |
| `logical-or-fallback` | `admin_front_ts/src/router/guard-helpers.ts` | `4` | `return routeName === 'login' \|\| routeName === '404'` |
| `logical-or-fallback` | `admin_front_ts/src/router/guard-helpers.ts` | `37` | `const target = currentRoute?.fullPath \|\| currentRoute?.path \|\| ''` |
| `optional-chain-fallback` | `admin_front_ts/src/router/guard-helpers.ts` | `37` | `const target = currentRoute?.fullPath \|\| currentRoute?.path \|\| ''` |
| `logical-or-fallback` | `admin_front_ts/src/router/guards.ts` | `30` | `const menuId = (to.meta.menuId as string) \|\| ''` |
| `logical-or-fallback` | `admin_front_ts/src/router/runtime-route-tree.ts` | `9` | `const meta = { ...(route.meta \|\| {}) } as RouteMeta` |
| `nullish-fallback` | `admin_front_ts/src/router/runtime-route-tree.ts` | `18` | `pageLayout: meta.pageLayout ?? 'card',` |
| `logical-or-fallback` | `admin_front_ts/src/router/view-registry.ts` | `7` | `if (!viewKey \|\| typeof viewKey !== 'string') {` |
| `logical-or-fallback` | `admin_front_ts/src/store/menu.ts` | `48` | `selectedMenu: localStorage.getItem('selectedMenu') \|\| '0',` |
| `logical-or-fallback` | `admin_front_ts/src/store/menu.ts` | `50` | `systemColor: localStorage.getItem('systemColor') \|\| LIGHT_SYSTEM_DEFAULT,` |
| `logical-or-fallback` | `admin_front_ts/src/store/menu.ts` | `57` | `transitionName: localStorage.getItem('transitionName') \|\| 'fade',` |
| `logical-or-fallback` | `admin_front_ts/src/store/menu.ts` | `58` | `layoutMode: (localStorage.getItem('layoutMode') as 'single' \| 'double') \|\| 'single',` |
| `logical-or-fallback` | `admin_front_ts/src/store/tauri.ts` | `27` | `if (val === 'minimize' \|\| val === 'exit') return val` |
| `logical-or-fallback` | `admin_front_ts/src/store/tauri.ts` | `67` | `if (!isTauri() \|\| this._closeHandlerReady) return` |
| `logical-or-fallback` | `admin_front_ts/src/views/Error/DeadPage.vue` | `15` | `value: route.meta.deadRoutePath \|\| route.path,` |
| `logical-or-fallback` | `admin_front_ts/src/views/Error/DeadPage.vue` | `19` | `value: route.meta.deadViewKey \|\| '-',` |
| `nullish-fallback` | `admin_front_ts/src/views/Layout/components/Aside/components/MenuItem.vue` | `42` | `const hasChildren = computed(() => (props.item.children?.length ?? 0) > 0)` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Layout/components/Aside/components/MenuItem.vue` | `42` | `const hasChildren = computed(() => (props.item.children?.length ?? 0) > 0)` |
| `logical-or-fallback` | `admin_front_ts/src/views/Layout/components/Aside/components/MenuItem.vue` | `43` | `const isVisible = computed(() => !props.item.show_menu \|\| props.item.show_menu === 1)` |
| `logical-or-fallback` | `admin_front_ts/src/views/Layout/components/Aside/index.vue` | `26` | `<span class="user-name">{{ userStore.username \|\| defaultUserName }}</span>` |
| `logical-or-fallback` | `admin_front_ts/src/views/Layout/components/Aside/index.vue` | `27` | `<span class="user-role">{{ userStore.role_name \|\| defaultRoleName }}</span>` |
| `logical-or-fallback` | `admin_front_ts/src/views/Layout/components/Header/components/SearchDialog.vue` | `125` | `item.label.toLowerCase().includes(query) \|\| item.path.toLowerCase().includes(query)` |
| `logical-or-fallback` | `admin_front_ts/src/views/Layout/components/Header/components/SearchDialog.vue` | `146` | `if ((e.ctrlKey \|\| e.metaKey) && e.code === 'KeyK') {` |
| `nullish-fallback` | `admin_front_ts/src/views/Layout/components/Header/components/SettingDrawer.vue` | `151` | `const closeActionValue = ref<string>(tauriStore.closeAction ?? 'ask')` |
| `nullish-fallback` | `admin_front_ts/src/views/Layout/components/Header/components/SettingDrawer.vue` | `156` | `closeActionValue.value = tauriStore.closeAction ?? 'ask'` |
| `nullish-fallback` | `admin_front_ts/src/views/Layout/components/TabTag/index.vue` | `71` | `const reduceMotion = window.matchMedia?.('(prefers-reduced-motion: reduce)')?.matches ?? false` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Layout/components/TabTag/index.vue` | `71` | `const reduceMotion = window.matchMedia?.('(prefers-reduced-motion: reduce)')?.matches ?? false` |
| `logical-or-fallback` | `admin_front_ts/src/views/Layout/components/TabTag/index.vue` | `82` | `const delta = e.deltaY \|\| -e.detail` |
| `nullish-fallback` | `admin_front_ts/src/views/Layout/utils/menuLabel.ts` | `5` | `const noHash = path.split('#')[0] ?? ''` |
| `nullish-fallback` | `admin_front_ts/src/views/Layout/utils/menuLabel.ts` | `6` | `const noQuery = noHash.split('?')[0] ?? ''` |
| `logical-or-fallback` | `admin_front_ts/src/views/Layout/utils/menuLabel.ts` | `27` | `return item.label \|\| ''` |
| `nullish-fallback` | `admin_front_ts/src/views/Layout/utils/page-layout.ts` | `6` | `return meta?.pageLayout ?? 'card'` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Layout/utils/page-layout.ts` | `6` | `return meta?.pageLayout ?? 'card'` |
| `logical-or-fallback` | `admin_front_ts/src/views/Login/components/ForgotPasswordDialog.vue` | `72` | `:disabled="countdown > 0 \|\| isSendingCode"` |
| `nullish-fallback` | `admin_front_ts/src/views/Login/components/LoginFormCard.vue` | `65` | `const activeTypeConfig = computed(() => typeConfig.value[props.activeType] ?? typeConfig.value.password)` |
| `nullish-fallback` | `admin_front_ts/src/views/Login/components/LoginFormCard.vue` | `85` | `props.registerSendCode?.(sendCodeRef.value ?? null)` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Login/components/LoginFormCard.vue` | `85` | `props.registerSendCode?.(sendCodeRef.value ?? null)` |
| `logical-or-fallback` | `admin_front_ts/src/views/Login/composables/useForgotPassword.ts` | `92` | `if (!forgotForm.account \|\| !forgotForm.code) return ElMessage.warning(t('forgotPassword.validation.fullInfoRequired'))` |
| `logical-or-fallback` | `admin_front_ts/src/views/Login/composables/useForgotPassword.ts` | `97` | `if (!forgotForm.newPassword \|\| !forgotForm.confirmPassword) return ElMessage.warning(t('forgotPassword.validation.passwordRequired'))` |
| `logical-or-fallback` | `admin_front_ts/src/views/Login/composables/useForgotPassword.ts` | `101` | `if (pwd.length < 6 \|\| pwd.length > 128) return ElMessage.warning(t('forgotPassword.validation.passwordLength'))` |
| `logical-or-fallback` | `admin_front_ts/src/views/Login/composables/useLoginForm.ts` | `100` | `return types[0]?.value \|\| 'password'` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Login/composables/useLoginForm.ts` | `100` | `return types[0]?.value \|\| 'password'` |
| `logical-or-fallback` | `admin_front_ts/src/views/Login/composables/useLoginForm.ts` | `104` | `if (!hasRememberedAccount.value \|\| !loginForm.login_account) return null` |
| `nullish-fallback` | `admin_front_ts/src/views/Login/composables/useLoginForm.ts` | `130` | `const nextType = rememberedType ?? resolveActiveType(types)` |
| `logical-or-fallback` | `admin_front_ts/src/views/Login/composables/useLoginForm.ts` | `158` | `if (!challenge \|\| !hasCompletedCaptcha.value) {` |
| `logical-or-fallback` | `admin_front_ts/src/views/Login/composables/useLoginForm.ts` | `269` | `await router.replace(redirect \|\| '/home')` |
| `logical-or-fallback` | `admin_front_ts/src/views/Login/composables/useLoginForm.ts` | `293` | `loginForm.login_account = localStorage.getItem(LOGIN_ACCOUNT_KEY) \|\| ''` |
| `logical-or-fallback` | `admin_front_ts/src/views/Login/composables/useLoginForm.ts` | `299` | `if (cachedType === 'password' \|\| cachedType === 'email' \|\| cachedType === 'phone') {` |
| `nullish-fallback` | `admin_front_ts/src/views/Login/composables/useLoginForm.ts` | `312` | `formRef.value = instance ?? undefined` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/ai/agents/components/AgentKnowledgeDialog/index.vue` | `42` | `const agentName = computed(() => props.agent?.name ?? '-')` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/ai/agents/components/AgentKnowledgeDialog/index.vue` | `42` | `const agentName = computed(() => props.agent?.name ?? '-')` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/ai/agents/components/AgentKnowledgeDialog/index.vue` | `47` | `knowledge_base_id: option?.value ?? 0,` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/ai/agents/components/AgentKnowledgeDialog/index.vue` | `47` | `knowledge_base_id: option?.value ?? 0,` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/ai/agents/components/AgentKnowledgeDialog/index.vue` | `48` | `knowledge_base_name: option?.label ?? '',` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/ai/agents/components/AgentKnowledgeDialog/index.vue` | `48` | `knowledge_base_name: option?.label ?? '',` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/ai/agents/components/AgentKnowledgeDialog/index.vue` | `49` | `top_k: option?.default_top_k ?? 5,` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/ai/agents/components/AgentKnowledgeDialog/index.vue` | `49` | `top_k: option?.default_top_k ?? 5,` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/ai/agents/components/AgentKnowledgeDialog/index.vue` | `50` | `min_score: option?.default_min_score ?? 0.1,` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/ai/agents/components/AgentKnowledgeDialog/index.vue` | `50` | `min_score: option?.default_min_score ?? 0.1,` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/ai/agents/components/AgentKnowledgeDialog/index.vue` | `51` | `max_context_chars: option?.default_max_context_chars ?? 6000,` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/ai/agents/components/AgentKnowledgeDialog/index.vue` | `51` | `max_context_chars: option?.default_max_context_chars ?? 6000,` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/agents/components/AgentKnowledgeDialog/index.vue` | `62` | `return selectOptions.value.filter((item) => !selected.has(item.value) \|\| item.value === bindings.value[index]?.knowledge_base_id)` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/ai/agents/components/AgentKnowledgeDialog/index.vue` | `62` | `return selectOptions.value.filter((item) => !selected.has(item.value) \|\| item.value === bindings.value[index]?.knowledge_base_id)` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/agents/components/AgentKnowledgeDialog/index.vue` | `68` | `if (!binding \|\| !option) return` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/ai/agents/components/AgentToolDialog/index.vue` | `37` | `const agentName = computed(() => props.agent?.name ?? '-')` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/ai/agents/components/AgentToolDialog/index.vue` | `37` | `const agentName = computed(() => props.agent?.name ?? '-')` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/agents/index.vue` | `150` | `label: model.display_name \|\| model.model_id,` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/ai/agents/index.vue` | `162` | `const list = grouped.get(model.provider_id) ?? []` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/agents/index.vue` | `163` | `list.push({ label: model.display_name \|\| model.model_id, value: model.model_id })` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/ai/agents/index.vue` | `169` | `children: grouped.get(provider.value) ?? [],` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/ai/agents/index.vue` | `193` | `system_prompt: row.system_prompt ?? '',` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/ai/agents/index.vue` | `194` | `avatar: row.avatar ?? '',` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/agents/index.vue` | `225` | `if (!providerID \|\| !modelID) {` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/agents/index.vue` | `275` | `<el-avatar :src="row.avatar \|\| undefined" :size="36">{{ row.name?.charAt(0) \|\| '?' }}</el-avatar>` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/ai/agents/index.vue` | `275` | `<el-avatar :src="row.avatar \|\| undefined" :size="36">{{ row.name?.charAt(0) \|\| '?' }}</el-avatar>` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/agents/index.vue` | `278` | `<el-text>{{ row.model_display_name \|\| row.model_id }}</el-text>` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/agents/index.vue` | `284` | `<el-tag :type="row.status === CommonEnum.YES ? 'success' : 'danger'">{{ row.status_name \|\| row.status }}</el-tag>` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/chat/components/AgentList/index.vue` | `59` | `:src="agent.avatar \|\| undefined"` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/chat/components/AgentList/index.vue` | `62` | `{{ agent.name?.charAt(0) \|\| '?' }}` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/ai/chat/components/AgentList/index.vue` | `62` | `{{ agent.name?.charAt(0) \|\| '?' }}` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/chat/components/ConversationDrawer/index.vue` | `99` | `const d = new Date(conv.last_message_at \|\| '')` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/chat/components/ConversationDrawer/index.vue` | `190` | `<span class="conv-title">{{ conv.title \|\| t('aiChat.untitled') }}</span>` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/chat/components/ConversationList/index.vue` | `33` | `(conversation) => conversation.last_message_at \|\| conversation.updated_at,` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/chat/components/ConversationList/index.vue` | `45` | `if (!wrap \|\| props.loadingMore \|\| !props.hasMore) return` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/chat/components/ConversationList/index.vue` | `85` | `<span class="conversation-title">{{ conversation.title \|\| t('aiChat.untitled') }}</span>` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/chat/components/ConversationList/index.vue` | `86` | `<span class="conversation-time">{{ conversation.last_message_at \|\| conversation.updated_at }}</span>` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/chat/components/MessageInput/index.vue` | `95` | `const hasCustomParams = computed(() => runtimeTemperature.value !== null \|\| runtimeMaxTokens.value !== null \|\| runtimeMaxHistory.value !== null)` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/chat/components/MessageInput/index.vue` | `143` | `const SpeechRecognition = win.SpeechRecognition \|\| win.webkitSpeechRecognition` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/chat/components/MessageInput/index.vue` | `365` | `if (props.sending \|\| props.disabled) return` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/chat/components/MessageInput/index.vue` | `430` | `<el-button v-if="supportsImage" text class="toolbar-btn" :disabled="sending \|\| disabled \|\| isImageLimitReached \|\| isRecording" @click="handleUploadClick" :title="t('aiChat.uploadImage')">` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/chat/components/MessageInput/index.vue` | `434` | `<el-button text class="toolbar-btn voice-btn" :class="{ 'is-recording': isRecording }" :disabled="sending \|\| disabled" @click="toggleVoiceInput" :title="t('aiChat.voiceInput')">` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/chat/components/MessageInput/index.vue` | `440` | `<el-button text class="toolbar-btn" :disabled="sending \|\| disabled \|\| isRecording" :title="t('aiChat.insertEmoji')">` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/chat/components/MessageInput/index.vue` | `447` | `<el-button text class="toolbar-btn" :class="{ 'params-active': hasCustomParams }" :disabled="sending \|\| disabled" @click="showParamsPanel = !showParamsPanel" :title="t('aiChat.runtimeParams')">` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/ai/chat/components/MessageInput/index.vue` | `470` | `<el-slider :model-value="runtimeTemperature ?? 1" @update:model-value="(v: number \| number[]) => runtimeTemperature = v as number" :min="0" :max="2" :step="0.1" :show-tooltip="false" size="small" />` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/ai/chat/components/MessageInput/index.vue` | `479` | `<el-slider :model-value="runtimeMaxTokens ?? 4096" @update:model-value="(v: number \| number[]) => runtimeMaxTokens = v as number" :min="256" :max="32768" :step="256" :show-tooltip="false" size="small" />` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/ai/chat/components/MessageInput/index.vue` | `489` | `<el-slider :model-value="runtimeMaxHistory ?? 20" @update:model-value="(v: number \| number[]) => runtimeMaxHistory = v as number" :min="1" :max="50" :step="1" :show-tooltip="false" size="small" />` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/chat/components/MessageInput/index.vue` | `503` | `<span class="error-text">{{ att.error \|\| t('aiChat.uploadFailed') }}</span>` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/chat/components/MessageInput/index.vue` | `521` | `:disabled="sending \|\| disabled \|\| isRecording"` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/chat/components/MessageInput/index.vue` | `550` | `:disabled="(!inputText.trim() && pendingAttachments.every((item) => item.status !== 'done')) \|\| sending \|\| disabled \|\| isRecording"` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/ai/chat/components/MessageList/index.vue` | `26` | `return message.meta_json?.attachments ?? []` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/ai/chat/components/MessageList/index.vue` | `26` | `return message.meta_json?.attachments ?? []` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/chat/components/MessageList/index.vue` | `46` | `:key="`${message.id}-${message.request_id \|\| ''}`"` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/chat/composables/useConversations.ts` | `50` | `if (!currentAgentId.value \|\| !hasMore.value \|\| loadingMore.value) return` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/chat/composables/useConversations.ts` | `57` | `before_id: nextId.value \|\| undefined,` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/chat/composables/useConversationSessions.ts` | `64` | `const activeStreams = computed(() => Array.from(sessions.value.values()).filter((session) => session.isStreaming \|\| session.sending).length)` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/chat/composables/useConversationSessions.ts` | `79` | `if (session?.isStreaming \|\| session?.sending \|\| session?.pendingRequestId) break` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/ai/chat/composables/useConversationSessions.ts` | `79` | `if (session?.isStreaming \|\| session?.sending \|\| session?.pendingRequestId) break` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/ai/chat/composables/useConversationSessions.ts` | `88` | `...(current ?? createSession(conversationId)),` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/chat/composables/useConversationSessions.ts` | `105` | `if (current.isStreaming \|\| current.sending) return` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/chat/composables/useConversationSessions.ts` | `236` | `content: current.streamingContent \|\| message.content,` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/chat/composables/useConversationSessions.ts` | `296` | `content: message.content \|\| messageText,` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/ai/chat/composables/useConversationSessions.ts` | `320` | `return current?.canceledRequestIds.includes(requestId) ?? false` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/ai/chat/composables/useConversationSessions.ts` | `320` | `return current?.canceledRequestIds.includes(requestId) ?? false` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/chat/composables/useConversationSocket.ts` | `34` | `if (conversationId === null \|\| requestId === null \|\| userMessageId === null \|\| agentId === null) return null` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/chat/composables/useConversationSocket.ts` | `42` | `if (conversationId === null \|\| requestId === null \|\| delta === null) return null` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/chat/composables/useConversationSocket.ts` | `50` | `if (conversationId === null \|\| requestId === null \|\| assistantMessageId === null) return null` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/chat/composables/useConversationSocket.ts` | `58` | `if (conversationId === null \|\| requestId === null \|\| msg === null) return null` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/ai/chat/index.vue` | `69` | `const messages = computed(() => currentSession.value?.messages ?? [])` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/ai/chat/index.vue` | `69` | `const messages = computed(() => currentSession.value?.messages ?? [])` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/ai/chat/index.vue` | `70` | `const messagesLoading = computed(() => currentSession.value?.loadingMessages ?? false)` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/ai/chat/index.vue` | `70` | `const messagesLoading = computed(() => currentSession.value?.loadingMessages ?? false)` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/ai/chat/index.vue` | `71` | `const messagesLoadingMore = computed(() => currentSession.value?.loadingMoreMessages ?? false)` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/ai/chat/index.vue` | `71` | `const messagesLoadingMore = computed(() => currentSession.value?.loadingMoreMessages ?? false)` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/ai/chat/index.vue` | `72` | `const messagesHasMore = computed(() => currentSession.value?.hasMoreMessages ?? false)` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/ai/chat/index.vue` | `72` | `const messagesHasMore = computed(() => currentSession.value?.hasMoreMessages ?? false)` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/ai/chat/index.vue` | `73` | `const sending = computed(() => currentSession.value?.sending ?? false)` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/ai/chat/index.vue` | `73` | `const sending = computed(() => currentSession.value?.sending ?? false)` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/ai/chat/index.vue` | `74` | `const isStreaming = computed(() => currentSession.value?.isStreaming ?? false)` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/ai/chat/index.vue` | `74` | `const isStreaming = computed(() => currentSession.value?.isStreaming ?? false)` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/ai/chat/index.vue` | `75` | `const activeRequestId = computed(() => currentSession.value?.pendingRequestId ?? '')` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/ai/chat/index.vue` | `75` | `const activeRequestId = computed(() => currentSession.value?.pendingRequestId ?? '')` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/chat/index.vue` | `100` | `if (session.messages.length > 0 \|\| session.isStreaming \|\| session.sending) return` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/chat/index.vue` | `117` | `if (!session \|\| session.loadingMoreMessages \|\| !session.hasMoreMessages) return` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/ai/chat/index.vue` | `120` | `const oldHeight = wrap?.scrollHeight ?? 0` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/ai/chat/index.vue` | `120` | `const oldHeight = wrap?.scrollHeight ?? 0` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/chat/index.vue` | `125` | `before_id: session.nextMessageId \|\| undefined,` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/ai/chat/index.vue` | `130` | `const newHeight = wrap?.scrollHeight ?? 0` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/ai/chat/index.vue` | `130` | `const newHeight = wrap?.scrollHeight ?? 0` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/ai/chat/index.vue` | `153` | `const nextConversation = savedConversation ?? conversations.value[0]` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/ai/chat/index.vue` | `169` | `currentConversationId.value = selectedConversationByAgent.value.get(agent.id) ?? null` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/chat/index.vue` | `206` | `if (!conversation \|\| !selectedAgent.value) return` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/chat/index.vue` | `209` | `title: conversation.title \|\| firstTitle(content),` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/chat/index.vue` | `220` | `if (!agentId \|\| !agent) throw new Error(t('aiChat.selectAgentFirst'))` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/ai/chat/index.vue` | `224` | `const created = conversations.value.find((item) => item.id === conversationId) ?? {` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/chat/index.vue` | `268` | `if (!conversationId \|\| !requestId) return` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/chat/index.vue` | `287` | `renameTitle.value = conversation.title \|\| ''` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/chat/index.vue` | `340` | `v-show="!isMobile \|\| !selectedAgentId"` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/chat/index.vue` | `347` | `<main v-show="!isMobile \|\| selectedAgentId" class="main-area">` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/chat/index.vue` | `353` | `<span class="header-title">{{ currentConversation?.title \|\| selectedAgent?.name \|\| t('aiChat.welcome') }}</span>` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/ai/chat/index.vue` | `353` | `<span class="header-title">{{ currentConversation?.title \|\| selectedAgent?.name \|\| t('aiChat.welcome') }}</span>` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/chat/index.vue` | `367` | `{{ selectedAgent?.name?.charAt(0) \|\| '?' }}` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/ai/chat/index.vue` | `367` | `{{ selectedAgent?.name?.charAt(0) \|\| '?' }}` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/chat/index.vue` | `370` | `<p class="welcome-tip">{{ selectedAgent?.description \|\| t('aiChat.welcomeTip') }}</p>` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/ai/chat/index.vue` | `370` | `<p class="welcome-tip">{{ selectedAgent?.description \|\| t('aiChat.welcomeTip') }}</p>` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/chat/index.vue` | `392` | `v-if="messages.length > 0 \|\| messagesLoading"` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/knowledge/components/KnowledgeBaseCard/index.vue` | `56` | `{{ row.status_name \|\| row.status }}` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/knowledge/components/KnowledgeBaseCard/index.vue` | `61` | `{{ row.description \|\| t('aiKnowledge.nav.noDescription') }}` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/knowledge/components/KnowledgeBaseList/index.vue` | `59` | `const hasFilters = computed(() => Boolean(searchForm.value.name \|\| searchForm.value.status))` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/knowledge/components/KnowledgeChunkDialog/index.vue` | `63` | `<template #header>{{ t('aiKnowledge.document.chunks') }} - {{ document?.title \|\| '-' }}</template>` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/ai/knowledge/components/KnowledgeChunkDialog/index.vue` | `63` | `<template #header>{{ t('aiKnowledge.document.chunks') }} - {{ document?.title \|\| '-' }}</template>` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/knowledge/components/KnowledgeDocumentFormDialog/index.vue` | `97` | `if (!formRef.value \|\| !props.knowledgeBase) {` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/ai/knowledge/components/KnowledgeDocumentHero/index.vue` | `21` | `() => props.knowledgeBase?.name ?? t('aiKnowledge.document.selectBase')` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/ai/knowledge/components/KnowledgeDocumentHero/index.vue` | `21` | `() => props.knowledgeBase?.name ?? t('aiKnowledge.document.selectBase')` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/knowledge/components/KnowledgeDocumentHero/index.vue` | `56` | `{{ knowledgeBase ? (knowledgeBase.description \|\| knowledgeBase.code) : t('aiKnowledge.document.selectBaseTip') }}` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/knowledge/components/KnowledgeDocumentHero/index.vue` | `66` | `{{ knowledgeBase.status_name \|\| knowledgeBase.status }}` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/knowledge/components/KnowledgeDocumentPanel/index.vue` | `229` | `{{ row.source_type_name \|\| row.source_type }}` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/knowledge/components/KnowledgeDocumentPanel/index.vue` | `234` | `{{ row.index_status_name \|\| row.index_status }}` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/knowledge/components/KnowledgeDocumentPanel/index.vue` | `239` | `{{ row.status_name \|\| row.status }}` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/ai/knowledge/components/RetrievalTestDialog/index.vue` | `44` | `const selectedHits = computed(() => result.value?.hits.filter((hit) => hit.status === 1) ?? [])` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/ai/knowledge/components/RetrievalTestDialog/index.vue` | `44` | `const selectedHits = computed(() => result.value?.hits.filter((hit) => hit.status === 1) ?? [])` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/ai/knowledge/components/RetrievalTestDialog/index.vue` | `49` | `top_k: props.knowledgeBase?.default_top_k ?? 5,` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/ai/knowledge/components/RetrievalTestDialog/index.vue` | `49` | `top_k: props.knowledgeBase?.default_top_k ?? 5,` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/ai/knowledge/components/RetrievalTestDialog/index.vue` | `50` | `min_score: props.knowledgeBase?.default_min_score ?? 0.1,` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/ai/knowledge/components/RetrievalTestDialog/index.vue` | `50` | `min_score: props.knowledgeBase?.default_min_score ?? 0.1,` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/ai/knowledge/components/RetrievalTestDialog/index.vue` | `51` | `max_context_chars: props.knowledgeBase?.default_max_context_chars ?? 6000,` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/ai/knowledge/components/RetrievalTestDialog/index.vue` | `51` | `max_context_chars: props.knowledgeBase?.default_max_context_chars ?? 6000,` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/knowledge/components/RetrievalTestDialog/index.vue` | `98` | `<template #header>{{ t('aiKnowledge.retrieval.title') }} - {{ knowledgeBase?.name \|\| '-' }}</template>` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/ai/knowledge/components/RetrievalTestDialog/index.vue` | `98` | `<template #header>{{ t('aiKnowledge.retrieval.title') }} - {{ knowledgeBase?.name \|\| '-' }}</template>` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/providers/components/ProviderFormDialog.vue` | `42` | `label: model.display_name \|\| model.model_id,` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/providers/components/ProviderFormDialog.vue` | `80` | `form.model_display_names[option.model_id] = option.display_name \|\| option.model_id` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/providers/components/ProviderModelList.vue` | `12` | `return model.display_name \|\| model.model_id` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/ai/providers/composables/useProviderForm.ts` | `45` | `form.model_ids = [...(next?.model_ids ?? [])]` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/ai/providers/composables/useProviderForm.ts` | `45` | `form.model_ids = [...(next?.model_ids ?? [])]` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/ai/providers/composables/useProviderForm.ts` | `46` | `form.model_display_names = { ...(next?.model_display_names ?? {}) }` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/ai/providers/composables/useProviderForm.ts` | `46` | `form.model_display_names = { ...(next?.model_display_names ?? {}) }` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/ai/providers/index.vue` | `85` | `return row.models ?? []` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/ai/providers/index.vue` | `100` | `driver: row.driver ?? row.engine_type,` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/providers/index.vue` | `104` | `model_display_names: Object.fromEntries(models.map((model) => [model.model_id, model.display_name \|\| model.model_id])),` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/providers/index.vue` | `113` | `ElNotification.success({ message: result.message \|\| t('aiProviders.testDone') })` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/providers/index.vue` | `151` | `<el-tag>{{ row.driver_name \|\| row.engine_type_name \|\| row.engine_type }}</el-tag>` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/providers/index.vue` | `154` | `<el-text>{{ row.base_url \|\| row.base_url_effective \|\| 'https://api.openai.com/v1' }}</el-text>` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/providers/index.vue` | `157` | `<el-text>{{ row.api_key_masked \|\| '-' }}</el-text>` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/providers/index.vue` | `164` | `<el-tag :type="stateTagType(row.health_status)">{{ row.health_status \|\| 'unknown' }}</el-tag>` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/providers/index.vue` | `166` | `<el-tag v-else :type="stateTagType(row.health_status)">{{ row.health_status \|\| 'unknown' }}</el-tag>` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/providers/index.vue` | `170` | `<el-tag :type="stateTagType(row.last_model_sync_status)">{{ row.last_model_sync_status \|\| 'unknown' }}</el-tag>` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/providers/index.vue` | `172` | `<el-tag v-else :type="stateTagType(row.last_model_sync_status)">{{ row.last_model_sync_status \|\| 'unknown' }}</el-tag>` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/providers/index.vue` | `175` | `<el-tag :type="row.status === 1 ? 'success' : 'danger'">{{ row.status_name \|\| row.status }}</el-tag>` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/runs/components/RunList/index.vue` | `67` | `if (!(error instanceof Error) \|\| error.message.trim() === '') {` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/runs/components/RunList/index.vue` | `204` | `Boolean(meta.run_request_id \|\| meta.provider_request_id)` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/runs/components/RunList/index.vue` | `211` | `if (value === null \|\| value === undefined) return '-'` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/runs/components/RunList/index.vue` | `376` | `<el-tag size="small" :type="eventTagType(detailData.status)">{{ event.event_type_name \|\| event.event_type }}</el-tag>` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/runs/components/RunList/index.vue` | `402` | `<el-tag size="small" :type="knowledgeRetrievalTagType(retrieval.status)">{{ retrieval.status_name \|\| retrieval.status }}</el-tag>` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/runs/components/RunList/index.vue` | `441` | `<span class="tool-call-name">{{ call.tool_name \|\| call.tool_code }}</span>` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/ai/runs/components/RunStats/index.vue` | `64` | `date_start: date_start ?? '',` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/ai/runs/components/RunStats/index.vue` | `65` | `date_end: date_end ?? '',` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/tools/components/ToolFormDialog/index.vue` | `87` | `if (!parsed \|\| typeof parsed !== 'object' \|\| Array.isArray(parsed)) {` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/tools/components/ToolList/index.vue` | `109` | `<el-tag :type="riskTagType(row.risk_level)">{{ row.risk_level_name \|\| row.risk_level }}</el-tag>` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/ai/tools/components/ToolList/index.vue` | `115` | `<el-tag :type="row.status === CommonEnum.YES ? 'success' : 'danger'">{{ row.status_name \|\| row.status }}</el-tag>` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/component/effect/components/ParticleBackground.vue` | `102` | `if (mouse.x === null \|\| mouse.y === null) {` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/component/upload/components/UpMediaList.vue` | `64` | `dialogUrl.value = file.url \|\| ''` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/component/upload/components/UpMediaList.vue` | `70` | `if (!item.url \|\| typeof item.uid !== 'number') {` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/home/components/HomeNotificationsPanel.vue` | `30` | `const relativeFormatter = computed(() => new Intl.RelativeTimeFormat(navigator.language \|\| 'zh-CN', { numeric: 'auto' }))` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/home/composables/useHomeDashboard.ts` | `46` | `if (target === undefined \|\| target === '') {` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/notification/index.vue` | `67` | `const getTypeColor = (type: number) => NotificationTypeColorMap[type] \|\| 'info'` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/payment/config/composables/usePaymentConfigPage.ts` | `199` | `ElNotification.success({ message: result.message \|\| t('paymentConfig.messages.alipayTestPassed') })` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/payment/config/composables/usePaymentConfigPage.ts` | `259` | `if (value.startsWith('http://') \|\| value.startsWith('https://')) {` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/payment/ledger/index.vue` | `58` | `date_start: dateStart \|\| '',` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/payment/ledger/index.vue` | `59` | `date_end: dateEnd \|\| '',` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/payment/recharge/components/RechargeCheckoutPanel.vue` | `57` | `<span>{{ props.selectedPackage?.amount_text \|\| t('paymentRecharge.checkout.selectPackage') }}</span>` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/payment/recharge/components/RechargeCheckoutPanel.vue` | `57` | `<span>{{ props.selectedPackage?.amount_text \|\| t('paymentRecharge.checkout.selectPackage') }}</span>` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/payment/recharge/composables/usePaymentRechargePage.ts` | `55` | `date_start: dateStart \|\| '',` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/payment/recharge/composables/usePaymentRechargePage.ts` | `56` | `date_end: dateEnd \|\| '',` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/payment/recharge/composables/usePaymentRechargePage.ts` | `67` | `const amount = selectedPackage.value?.amount_cents ?? 0` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/payment/recharge/composables/usePaymentRechargePage.ts` | `67` | `const amount = selectedPackage.value?.amount_cents ?? 0` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/payment/recharge/composables/usePaymentRechargePage.ts` | `150` | `return row.status === 'pending' \|\| row.status === 'failed' \|\| (row.status === 'paying' && row.pay_url !== '')` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/permission/authPlatform/index.vue` | `168` | `return loginTypeLabelMap.value.get(val) ?? ''` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/permission/authPlatform/index.vue` | `180` | `return captchaTypeLabelMap.value.get(val) ?? ''` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/permission/permission/components/IconSelect.vue` | `150` | `return icon.split(':')[1] \|\| icon` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/permission/permission/components/IconSelect.vue` | `160` | `return category?.color \|\| '#909399'` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/permission/permission/components/IconSelect.vue` | `160` | `return category?.color \|\| '#909399'` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/permission/permission/components/PermissionDefinitionDialog.vue` | `29` | `const isMenuType = computed(() => form.value.type === PermissionTypeEnum.DIR \|\| form.value.type === PermissionTypeEnum.PAGE)` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/permission/permission/components/PermissionDefinitionDialog.vue` | `37` | `if (value === '' \|\| Number(value) < 1) {` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/permission/permission/composables/usePermissionDefinitionPage.ts` | `66` | `return rows.flatMap((row) => [row, ...flattenRows(row.children ?? [])])` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/permission/permission/composables/usePermissionDefinitionPage.ts` | `72` | `&& (row.path.trim() === '' \|\| row.component.trim() === '')` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/permission/permission/composables/usePermissionDefinitionPage.ts` | `159` | `activePlatform.value = platformOptions.value[0]?.value ?? PlatformEnum.ADMIN` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/permission/permission/composables/usePermissionDefinitionPage.ts` | `159` | `activePlatform.value = platformOptions.value[0]?.value ?? PlatformEnum.ADMIN` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/permission/role/components/RolePermissionMatrix.vue` | `125` | `groupRuntimeStateMap.value.get(group.groupId) ?? emptyGroupRuntimeState` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/permission/role/components/RolePermissionMatrix.vue` | `129` | `rowRuntimeStateMap.value.get(rowKey(row)) ?? emptyRowRuntimeState` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/permission/role/index.vue` | `50` | `if (node.type === PermissionTypeEnum.PAGE \|\| node.type === PermissionTypeEnum.BUTTON) {` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/permission/role/index.vue` | `69` | `activePlatform.value = platformOptions.value[0]?.value ?? PlatformEnum.ADMIN` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/permission/role/index.vue` | `69` | `activePlatform.value = platformOptions.value[0]?.value ?? PlatformEnum.ADMIN` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/permission/role/index.vue` | `132` | `const addedPermissionLabels = computed(() => permissionDiff.value.added.map((id) => permissionLabelMap.value.get(id) ?? `#${id}`))` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/permission/role/index.vue` | `133` | `const removedPermissionLabels = computed(() => permissionDiff.value.removed.map((id) => permissionLabelMap.value.get(id) ?? `#${id}`))` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/permission/role/role-matrix.ts` | `46` | `actions: (item.children ?? [])` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/permission/role/role-matrix.ts` | `48` | `.map((child) => ({ id: child.value, code: String(child.code ?? ''), label: child.label })),` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/permission/role/role-matrix.ts` | `58` | `actions: [{ id: item.value, code: String(item.code ?? ''), label: item.label }],` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/permission/role/role-matrix.ts` | `68` | `const rootPagesLabel = options.rootPagesLabel ?? 'Ungrouped Pages'` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/permission/role/role-matrix.ts` | `69` | `const rootButtonsLabel = options.rootButtonsLabel ?? 'Root Buttons'` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/permission/role/role-matrix.ts` | `89` | `const group = currentGroup ?? {` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/permission/role/role-matrix.ts` | `105` | `const group = currentGroup ?? ensureSyntheticGroup(ROOT_PAGES_GROUP_ID, rootPagesLabel)` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/permission/role/role-matrix.ts` | `111` | `const group = currentGroup ?? ensureSyntheticGroup(ROOT_BUTTONS_GROUP_ID, rootButtonsLabel)` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/personal/components/BaseInfo/index.vue` | `40` | `username: source.username?.trim?.() \|\| source.username,` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/personal/components/BaseInfo/index.vue` | `40` | `username: source.username?.trim?.() \|\| source.username,` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/personal/components/BaseInfo/index.vue` | `42` | `birthday: source.birthday \|\| null,` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/personal/components/LoginLog/index.vue` | `27` | `logList.value = data.list \|\| []` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/personal/components/Security/index.vue` | `29` | `if (!phoneForm.value.phone \|\| !phoneForm.value.code) {` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/personal/components/Security/index.vue` | `49` | `if (!emailForm.value.email \|\| !emailForm.value.code) {` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/personal/components/Security/index.vue` | `77` | `const passwordAccount = computed(() => props.userinfo.email \|\| props.userinfo.phone)` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/personal/components/Security/index.vue` | `92` | `if (!canUsePasswordVerify.value \|\| !canUseCodeVerify.value) {` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/personal/components/Security/index.vue` | `102` | `if (!passwordForm.value.new_password \|\| !passwordForm.value.confirm_password) {` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/personal/components/Security/index.vue` | `165` | `<div class="item-value" v-if="!isMobile">{{ userinfo.phone \|\| t('personal.security.notBound') }}</div>` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/personal/components/Security/index.vue` | `167` | `<div class="item-value-mobile" v-if="isMobile">{{ userinfo.phone \|\| t('personal.security.notBound') }}</div>` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/personal/components/Security/index.vue` | `198` | `<div class="item-value" v-if="!isMobile">{{ userinfo.email \|\| t('personal.security.notBound') }}</div>` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/personal/components/Security/index.vue` | `200` | `<div class="item-value-mobile" v-if="isMobile">{{ userinfo.email \|\| t('personal.security.notBound') }}</div>` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/personal/components/Security/index.vue` | `262` | `{{ t('personal.security.codeSendTo') }} {{ userinfo.email \|\| userinfo.phone }}` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/personal/components/UserInfo/index.vue` | `47` | `<div class="value">{{ userinfo.email \|\| t('personal.notSet') }}</div>` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/personal/components/UserInfo/index.vue` | `52` | `<div class="value">{{ userinfo.phone \|\| t('personal.notSet') }}</div>` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/personal/components/UserInfo/index.vue` | `78` | `<div class="value">{{ userinfo.bio \|\| t('personal.noBio') }}</div>` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/personal/index.vue` | `26` | `return queryUserID \|\| String(userStore.user_id)` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/personal/index.vue` | `54` | `addressTree.value = data.dict.auth_address_tree \|\| []` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/personal/index.vue` | `55` | `sexArr.value = data.dict.sexArr \|\| []` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/personal/index.vue` | `56` | `verifyTypeArr.value = data.dict.verify_type_arr \|\| []` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/personal/wallet/index.vue` | `39` | `date_start: dateStart \|\| '',` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/personal/wallet/index.vue` | `40` | `date_end: dateEnd \|\| '',` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/system/clientVersion/index.vue` | `150` | `const lastSegment = url.pathname.split('/').filter(Boolean).pop() ?? ''` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/clientVersion/index.vue` | `169` | `ClientVersionApi.updateJson({ platform: searchForm.value.platform \|\| 'windows-x86_64' }).then((res) => {` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/clientVersion/index.vue` | `217` | `{{ platformMap.get(row.platform) \|\| row.platform }}` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/system/cronTask/composables/useCronTaskLogs.ts` | `23` | `const [startDate, endDate] = params.date ?? []` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/system/cronTask/composables/useCronTaskLogs.ts` | `28` | `task_id: Number(params.task_id ?? 0),` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/system/cronTask/index.vue` | `142` | `const logStatusType = (status: number) => LOG_STATUS_TYPE[status] ?? 'info'` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/cronTask/index.vue` | `143` | `const displayTaskType = (row: CronTaskItem) => row.handler \|\| '-'` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/cronTask/index.vue` | `163` | `<el-tag size="small" type="info">{{ row.cron_readable \|\| row.cron }}</el-tag>` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/exportTask/index.vue` | `23` | `if (raw === undefined \|\| raw === null) return null` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/exportTask/index.vue` | `25` | `if (val === '1' \|\| val === 'pending' \|\| val === 'processing') return 1` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/exportTask/index.vue` | `26` | `if (val === '2' \|\| val === 'success' \|\| val === 'completed' \|\| val === 'done') return 2` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/exportTask/index.vue` | `27` | `if (val === '3' \|\| val === 'failed' \|\| val === 'fail' \|\| val === 'error') return 3` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/system/exportTask/index.vue` | `44` | `searchForm.value.status = data[0]?.value ?? ''` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/system/exportTask/index.vue` | `44` | `searchForm.value.status = data[0]?.value ?? ''` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/exportTask/index.vue` | `102` | `return ({1: 'warning', 2: 'success', 3: 'danger'} as const)[status as 1 \| 2 \| 3] \|\| 'info'` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/log/components/SystemLogToolbar.vue` | `44` | `<strong>{{ currentFile?.name \|\| '-' }}</strong>` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/system/log/components/SystemLogToolbar.vue` | `44` | `<strong>{{ currentFile?.name \|\| '-' }}</strong>` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/log/components/SystemLogToolbar.vue` | `117` | `:disabled="!hasActiveFilter \|\| loading"` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/log/composables/useSystemLog.ts` | `38` | `\|\| line.level === 'CRITICAL'` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/log/composables/useSystemLog.ts` | `39` | `\|\| line.content.includes('Exception')` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/log/composables/useSystemLog.ts` | `40` | `\|\| line.content.includes('Stack trace')` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/log/composables/useSystemLog.ts` | `95` | `return matched \|\| null` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/log/composables/useSystemLog.ts` | `104` | `const hasActiveFilter = computed(() => Boolean(keyword.value.trim() \|\| level.value))` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/log/composables/useSystemLog.ts` | `151` | `if (!selectedFile.value \|\| !selectedExists) {` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/log/composables/useSystemLog.ts` | `182` | `if (typeof navigator === 'undefined' \|\| !navigator.clipboard) {` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/log/index.vue` | `37` | `{{ log.selectedFile.value \|\| t('systemLog.sidebar.title') }}` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/log/index.vue` | `41` | `v-show="!isMobile \|\| showSidebar"` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/mail/components/MailConfigPanel.vue` | `62` | `form.region = row.region \|\| dict.value.default_region` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/mail/components/MailConfigPanel.vue` | `63` | `form.endpoint = row.endpoint \|\| dict.value.default_endpoint` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/mail/components/MailConfigPanel.vue` | `68` | `form.verify_code_ttl_minutes = row.verify_code_ttl_minutes \|\| dict.value.default_ttl_minutes` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/mail/components/MailConfigPanel.vue` | `112` | `if (!testForm.to_email \|\| !testForm.template_scene) {` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/mail/components/MailConfigPanel.vue` | `158` | `<el-input v-model="form.secret_id" show-password clearable :placeholder="isConfigured ? config?.secret_id_hint \|\| t('mail.config.secretKeep') : ''" />` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/system/mail/components/MailConfigPanel.vue` | `158` | `<el-input v-model="form.secret_id" show-password clearable :placeholder="isConfigured ? config?.secret_id_hint \|\| t('mail.config.secretKeep') : ''" />` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/mail/components/MailConfigPanel.vue` | `163` | `<el-input v-model="form.secret_key" show-password clearable :placeholder="isConfigured ? config?.secret_key_hint \|\| t('mail.config.secretKeep') : ''" />` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/system/mail/components/MailConfigPanel.vue` | `163` | `<el-input v-model="form.secret_key" show-password clearable :placeholder="isConfigured ? config?.secret_key_hint \|\| t('mail.config.secretKeep') : ''" />` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/mail/components/MailConfigPanel.vue` | `254` | `<el-descriptions-item :label="t('mail.config.lastTestAt')">{{ config.last_test_at \|\| '-' }}</el-descriptions-item>` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/mail/components/MailConfigPanel.vue` | `255` | `<el-descriptions-item :label="t('mail.config.lastTestError')">{{ config.last_test_error \|\| '-' }}</el-descriptions-item>` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/system/mail/components/MailLogPanel.vue` | `53` | `created_at_start: start ?? '',` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/system/mail/components/MailLogPanel.vue` | `54` | `created_at_end: end ?? '',` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/mail/components/MailLogPanel.vue` | `126` | `return dict.value.mail_log_scene_arr.find((item) => item.value === scene)?.label \|\| scene` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/system/mail/components/MailLogPanel.vue` | `126` | `return dict.value.mail_log_scene_arr.find((item) => item.value === scene)?.label \|\| scene` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/mail/components/MailLogPanel.vue` | `130` | `return dict.value.mail_log_status_arr.find((item) => item.value === status)?.label \|\| String(status)` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/system/mail/components/MailLogPanel.vue` | `130` | `return dict.value.mail_log_status_arr.find((item) => item.value === status)?.label \|\| String(status)` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/mail/components/MailLogPanel.vue` | `223` | `<el-descriptions-item :label="t('mail.log.subject')">{{ detail.subject \|\| '-' }}</el-descriptions-item>` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/mail/components/MailLogPanel.vue` | `228` | `<el-descriptions-item :label="t('mail.log.requestId')">{{ detail.tencent_request_id \|\| '-' }}</el-descriptions-item>` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/mail/components/MailLogPanel.vue` | `229` | `<el-descriptions-item :label="t('mail.log.messageId')">{{ detail.tencent_message_id \|\| '-' }}</el-descriptions-item>` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/mail/components/MailLogPanel.vue` | `230` | `<el-descriptions-item :label="t('mail.log.errorCode')">{{ detail.error_code \|\| '-' }}</el-descriptions-item>` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/mail/components/MailLogPanel.vue` | `231` | `<el-descriptions-item :label="t('mail.log.errorMessage')">{{ detail.error_message \|\| '-' }}</el-descriptions-item>` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/mail/components/MailLogPanel.vue` | `232` | `<el-descriptions-item :label="t('mail.log.sentAt')">{{ detail.sent_at \|\| '-' }}</el-descriptions-item>` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/mail/components/MailLogPanel.vue` | `233` | `<el-descriptions-item :label="t('mail.common.createdAt')">{{ detail.created_at \|\| '-' }}</el-descriptions-item>` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/mail/components/MailLogPanel.vue` | `239` | `<el-descriptions-item :label="t('mail.log.templateName')">{{ detail.template.name \|\| '-' }}</el-descriptions-item>` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/mail/components/MailTemplatePanel.vue` | `71` | `return dict.value.common_status_arr.find((item) => item.value === status)?.label \|\| String(status)` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/system/mail/components/MailTemplatePanel.vue` | `71` | `return dict.value.common_status_arr.find((item) => item.value === status)?.label \|\| String(status)` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/mail/components/MailTemplatePanel.vue` | `75` | `return dict.value.mail_scene_arr.find((item) => item.value === scene)?.label \|\| scene` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/system/mail/components/MailTemplatePanel.vue` | `75` | `return dict.value.mail_scene_arr.find((item) => item.value === scene)?.label \|\| scene` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/system/mail/components/MailTemplatePanel.vue` | `136` | `rows.push({ key, value: sampleVariables[key] ?? '' })` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/mail/components/MailTemplatePanel.vue` | `191` | `if (!form.tencent_template_id \|\| !Number.isInteger(form.tencent_template_id) \|\| form.tencent_template_id <= 0) {` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/mail/components/MailTemplatePanel.vue` | `198` | `if (variables.length !== 2 \|\| variables[0] !== 'code' \|\| variables[1] !== 'ttl_minutes') {` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/mail/components/MailTemplatePanel.vue` | `203` | `if (sampleKeys.length !== 2 \|\| sampleKeys[0] !== 'code' \|\| sampleKeys[1] !== 'ttl_minutes') {` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/system/notificationTask/index.vue` | `42` | `searchForm.value.status = data[0]?.value ?? ''` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/system/notificationTask/index.vue` | `42` | `searchForm.value.status = data[0]?.value ?? ''` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/notificationTask/index.vue` | `98` | `return ({1: 'warning', 2: 'primary', 3: 'success', 4: 'danger'} as const)[status as 1 \| 2 \| 3 \| 4] \|\| 'info'` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/notificationTask/index.vue` | `102` | `return ({1: 'info', 2: 'success', 3: 'warning', 4: 'danger'} as const)[type as 1 \| 2 \| 3 \| 4] \|\| 'info'` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/operationLog/index.vue` | `188` | `<pre class="payload-panel__body">{{ formatOperationLogPayload(detailRow.request_data, 'request') \|\| '-' }}</pre>` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/operationLog/index.vue` | `195` | `<pre class="payload-panel__body">{{ formatOperationLogPayload(detailRow.response_data, 'response') \|\| '-' }}</pre>` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/operationLog/utils/payload.ts` | `72` | `if (!parsed.ok) return parsed.value \|\| mergedLabels.empty` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/operationLog/utils/payload.ts` | `87` | `if (payload === null \|\| payload === undefined \|\| payload === '') {` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/operationLog/utils/payload.ts` | `102` | `if (value === null \|\| value === undefined) return ''` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/system/setting/index.vue` | `81` | `return jsonEditorRef.value?.validate() ?? true` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/system/setting/index.vue` | `81` | `return jsonEditorRef.value?.validate() ?? true` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/sms/components/SmsConfigPanel.vue` | `63` | `form.region = row.region \|\| dict.value.default_region` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/sms/components/SmsConfigPanel.vue` | `64` | `form.endpoint = row.endpoint \|\| dict.value.default_endpoint` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/sms/components/SmsConfigPanel.vue` | `66` | `form.verify_code_ttl_minutes = row.verify_code_ttl_minutes \|\| dict.value.default_ttl_minutes` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/sms/components/SmsConfigPanel.vue` | `110` | `if (!testForm.to_phone \|\| !testForm.template_scene) {` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/sms/components/SmsConfigPanel.vue` | `156` | `<el-input v-model="form.secret_id" show-password clearable :placeholder="isConfigured ? config?.secret_id_hint \|\| t('sms.config.secretKeep') : ''" />` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/system/sms/components/SmsConfigPanel.vue` | `156` | `<el-input v-model="form.secret_id" show-password clearable :placeholder="isConfigured ? config?.secret_id_hint \|\| t('sms.config.secretKeep') : ''" />` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/sms/components/SmsConfigPanel.vue` | `161` | `<el-input v-model="form.secret_key" show-password clearable :placeholder="isConfigured ? config?.secret_key_hint \|\| t('sms.config.secretKeep') : ''" />` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/system/sms/components/SmsConfigPanel.vue` | `161` | `<el-input v-model="form.secret_key" show-password clearable :placeholder="isConfigured ? config?.secret_key_hint \|\| t('sms.config.secretKeep') : ''" />` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/sms/components/SmsConfigPanel.vue` | `246` | `<el-descriptions-item :label="t('sms.config.lastTestAt')">{{ config.last_test_at \|\| '-' }}</el-descriptions-item>` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/sms/components/SmsConfigPanel.vue` | `247` | `<el-descriptions-item :label="t('sms.config.lastTestError')">{{ config.last_test_error \|\| '-' }}</el-descriptions-item>` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/system/sms/components/SmsLogPanel.vue` | `53` | `created_at_start: start ?? '',` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/system/sms/components/SmsLogPanel.vue` | `54` | `created_at_end: end ?? '',` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/sms/components/SmsLogPanel.vue` | `126` | `return dict.value.sms_log_scene_arr.find((item) => item.value === scene)?.label \|\| scene` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/system/sms/components/SmsLogPanel.vue` | `126` | `return dict.value.sms_log_scene_arr.find((item) => item.value === scene)?.label \|\| scene` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/sms/components/SmsLogPanel.vue` | `130` | `return dict.value.sms_log_status_arr.find((item) => item.value === status)?.label \|\| String(status)` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/system/sms/components/SmsLogPanel.vue` | `130` | `return dict.value.sms_log_status_arr.find((item) => item.value === status)?.label \|\| String(status)` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/sms/components/SmsLogPanel.vue` | `228` | `<el-descriptions-item :label="t('sms.log.requestId')">{{ detail.tencent_request_id \|\| '-' }}</el-descriptions-item>` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/sms/components/SmsLogPanel.vue` | `229` | `<el-descriptions-item :label="t('sms.log.serialNo')">{{ detail.tencent_serial_no \|\| '-' }}</el-descriptions-item>` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/sms/components/SmsLogPanel.vue` | `230` | `<el-descriptions-item :label="t('sms.log.errorCode')">{{ detail.error_code \|\| '-' }}</el-descriptions-item>` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/sms/components/SmsLogPanel.vue` | `231` | `<el-descriptions-item :label="t('sms.log.errorMessage')">{{ detail.error_message \|\| '-' }}</el-descriptions-item>` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/sms/components/SmsLogPanel.vue` | `232` | `<el-descriptions-item :label="t('sms.log.sentAt')">{{ detail.sent_at \|\| '-' }}</el-descriptions-item>` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/sms/components/SmsLogPanel.vue` | `233` | `<el-descriptions-item :label="t('sms.common.createdAt')">{{ detail.created_at \|\| '-' }}</el-descriptions-item>` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/sms/components/SmsLogPanel.vue` | `239` | `<el-descriptions-item :label="t('sms.log.templateName')">{{ detail.template.name \|\| '-' }}</el-descriptions-item>` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/sms/components/SmsTemplatePanel.vue` | `69` | `return dict.value.common_status_arr.find((item) => item.value === status)?.label \|\| String(status)` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/system/sms/components/SmsTemplatePanel.vue` | `69` | `return dict.value.common_status_arr.find((item) => item.value === status)?.label \|\| String(status)` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/sms/components/SmsTemplatePanel.vue` | `73` | `return dict.value.sms_scene_arr.find((item) => item.value === scene)?.label \|\| scene` |
| `optional-chain-fallback` | `admin_front_ts/src/views/Main/system/sms/components/SmsTemplatePanel.vue` | `73` | `return dict.value.sms_scene_arr.find((item) => item.value === scene)?.label \|\| scene` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/system/sms/components/SmsTemplatePanel.vue` | `132` | `rows.push({ key, value: sampleVariables[key] ?? '' })` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/sms/components/SmsTemplatePanel.vue` | `188` | `if (!templateID \|\| !/^\d+$/.test(templateID)) {` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/sms/components/SmsTemplatePanel.vue` | `195` | `if (variables.length !== 2 \|\| variables[0] !== 'code' \|\| variables[1] !== 'ttl_minutes') {` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/sms/components/SmsTemplatePanel.vue` | `200` | `if (sampleKeys.length !== 2 \|\| sampleKeys[0] !== 'code' \|\| sampleKeys[1] !== 'ttl_minutes') {` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/system/uploadConfig/components/UploadDriver/index.vue` | `165` | `appid: row.appid ?? '',` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/system/uploadConfig/components/UploadDriver/index.vue` | `166` | `endpoint: row.endpoint ?? '',` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/system/uploadConfig/components/UploadDriver/index.vue` | `167` | `bucket_domain: row.bucket_domain ?? ''` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/uploadConfig/components/UploadRule/index.vue` | `72` | `if (!Number.isFinite(v) \|\| v < 1 \|\| v > 10240) callback(new Error(t('upload.rule.form.max_size_mb') + t('common.required')))` |
| `nullish-fallback` | `admin_front_ts/src/views/Main/system/uploadConfig/components/UploadSetting/index.vue` | `145` | `remark: row.remark ?? ''` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/system/uploadConfig/components/UploadSetting/index.vue` | `172` | `if (typeof value !== 'number' \|\| !Number.isInteger(value) \|\| value <= 0) {` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/user/userManager/components/SessionList/index.vue` | `26` | `platformArr.value = data.dict.platformArr \|\| []` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/user/userManager/components/UserList/index.vue` | `117` | `avatar: current.avatar \|\| '',` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/user/userManager/components/UserList/index.vue` | `124` | `bio: current.bio \|\| '',` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/user/userManager/components/UserList/index.vue` | `302` | `<el-avatar :src="row.avatar \|\| undefined" />` |
| `logical-or-fallback` | `admin_front_ts/src/views/Main/user/usersLoginLog/index.vue` | `154` | `<ElText truncated>{{ row.reason \|\| '-' }}</ElText>` |

## Scanner boundary

```text
Included: admin_front_ts/src/**/*.ts and admin_front_ts/src/**/*.vue.
Excluded: *.d.ts, tests/specs, and generated directories.
Comment handling: line and block comments are stripped before scanning while preserving line numbers.
Detection: any, as any, Record<string, any>, catch(...: any), ||, ??, optional chaining with fallback on the same line, and direct axios external HTTP calls.
Not proof: regex rows require owner review before refactor; existing debt does not fail build by itself.
```

## Verification command

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\export-admin-front-source-quality-inventory.ps1 -OutputDate 2026-06-08
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1 -LiveSchema
```
