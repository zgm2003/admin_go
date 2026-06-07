# Frontend API Inventory Snapshot

Generated at: 2026-06-07 06:57:34 +08:00

This artifact is generated from current frontend source. It is a source inventory, not served-route smoke and not browser runtime proof. It intentionally resolves only literal strings, same-file constants, simple string/template concatenation, and the shared admin API prefix. Computed URLs are classified instead of guessed.

## Source summary

| Fact | Count |
| --- | --- |
| Source files scanned | `315` |
| Frontend API calls found | `274` |
| Admin frontend backend API calls | `239` |
| Canvas frontend backend API calls | `19` |
| App backend API calls | `0` |
| External HTTP helper calls | `3` |
| Dynamic blob/download URL calls | `4` |
| Wrapper/proxy infrastructure calls | `7` |
| Parametric backend admin helper calls | `2` |
| Calls under /api/admin/v1 | `239` |
| Calls under /api/canvas/v1 | `19` |
| Backend /api calls outside known prefixes | `0` |
| Frontend calls outside known backend prefixes | `16` |
| Unresolved frontend API expressions | `0` |

## Backend API calls under known prefixes

| Project | Source | Line | Client | Method path | Raw URL expression | Kind |
| --- | --- | ---: | --- | --- | --- | --- |
| `admin_front_ts` | `admin_front_ts/src/api/ai/agents.ts` | `231` | `request.get` | `GET /api/admin/v1/ai-agents/options` | ``${ADMIN_API_PREFIX}/ai-agents/options`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/agents.ts` | `236` | `request.delete` | `DELETE /api/admin/v1/ai-agents/:param` | ``${ADMIN_API_PREFIX}/ai-agents/${id}`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/agents.ts` | `239` | `request.get` | `GET /api/admin/v1/ai-agents/page-init` | ``${ADMIN_API_PREFIX}/ai-agents/page-init`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/agents.ts` | `240` | `request.post` | `POST /api/admin/v1/ai-agents` | ``${ADMIN_API_PREFIX}/ai-agents`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/agents.ts` | `243` | `request.put` | `PUT /api/admin/v1/ai-agents/:param` | ``${ADMIN_API_PREFIX}/ai-agents/${id}`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/agents.ts` | `245` | `request.patch` | `PATCH /api/admin/v1/ai-agents/:param/status` | ``${ADMIN_API_PREFIX}/ai-agents/${positiveID(params.id, 'AI agent id')}/status`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/agents.ts` | `253` | `request.get` | `GET /api/admin/v1/ai-agents` | ``${ADMIN_API_PREFIX}/ai-agents`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/agents.ts` | `255` | `request.get` | `GET /api/admin/v1/ai-agents/provider-models/:param` | ``${ADMIN_API_PREFIX}/ai-agents/provider-models/${positiveID(params.provider_id, 'AI provider id')}`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/agents.ts` | `256` | `request.get` | `GET /api/admin/v1/ai-agents/:param` | ``${ADMIN_API_PREFIX}/ai-agents/${positiveID(params.id, 'AI agent id')}`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/agents.ts` | `257` | `request.get` | `GET /api/admin/v1/ai-agents/:param/tools` | ``${ADMIN_API_PREFIX}/ai-agents/${positiveID(params.agent_id, 'AI agent id')}/tools`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/agents.ts` | `258` | `request.put` | `PUT /api/admin/v1/ai-agents/:param/tools` | ``${ADMIN_API_PREFIX}/ai-agents/${positiveID(params.agent_id, 'AI agent id')}/tools`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/agents.ts` | `259` | `request.get` | `GET /api/admin/v1/ai-agents/:param/knowledge-bases` | ``${ADMIN_API_PREFIX}/ai-agents/${positiveID(params.agent_id, 'AI agent id')}/knowledge-bases`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/agents.ts` | `260` | `request.put` | `PUT /api/admin/v1/ai-agents/:param/knowledge-bases` | ``${ADMIN_API_PREFIX}/ai-agents/${positiveID(params.agent_id, 'AI agent id')}/knowledge-bases`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/agents.ts` | `264` | `request.post` | `POST /api/admin/v1/ai-agents/:param/test` | ``${ADMIN_API_PREFIX}/ai-agents/${positiveID(params.id, 'AI agent id')}/test`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/chat.ts` | `28` | `request.post` | `POST /api/admin/v1/ai-conversations/:param/messages/cancel` | ``${ADMIN_API_PREFIX}/ai-conversations/${positiveID(params.conversation_id, 'conversation id')}/messages/cancel`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/conversations.ts` | `66` | `request.delete` | `DELETE /api/admin/v1/ai-conversations/:param` | ``${ADMIN_API_PREFIX}/ai-conversations/${id}`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/conversations.ts` | `69` | `request.post` | `POST /api/admin/v1/ai-conversations` | ``${ADMIN_API_PREFIX}/ai-conversations`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/conversations.ts` | `70` | `request.put` | `PUT /api/admin/v1/ai-conversations/:param` | ``${ADMIN_API_PREFIX}/ai-conversations/${positiveID(params.id)}`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/conversations.ts` | `77` | `request.get` | `GET /api/admin/v1/ai-conversations` | ``${ADMIN_API_PREFIX}/ai-conversations`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/conversations.ts` | `78` | `request.get` | `GET /api/admin/v1/ai-conversations/:param` | ``${ADMIN_API_PREFIX}/ai-conversations/${positiveID(params.id)}`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/images.ts` | `161` | `request.delete` | `DELETE /api/admin/v1/ai-images/:param` | ``${BASE}/${id}`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/images.ts` | `164` | `request.get` | `GET /api/admin/v1/ai-images/page-init` | ``${BASE}/page-init`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/images.ts` | `165` | `request.post` | `POST /api/admin/v1/ai-images/assets` | ``${BASE}/assets`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/images.ts` | `166` | `request.post` | `POST /api/admin/v1/ai-images` | `BASE` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/images.ts` | `174` | `request.get` | `GET /api/admin/v1/ai-images` | `BASE` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/images.ts` | `175` | `request.get` | `GET /api/admin/v1/ai-images/:param` | ``${BASE}/${positiveID(params.id, 'AI image task id')}`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/images.ts` | `178` | `request.patch` | `PATCH /api/admin/v1/ai-images/:param/favorite` | ``${BASE}/${positiveID(params.id, 'AI image task id')}/favorite`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/knowledge.ts` | `258` | `request.delete` | `DELETE /api/admin/v1/ai-knowledge-bases/:param` | ``${ADMIN_API_PREFIX}/ai-knowledge-bases/${positiveID(id, 'AI knowledge base id')}`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/knowledge.ts` | `261` | `request.get` | `GET /api/admin/v1/ai-knowledge-bases/page-init` | ``${ADMIN_API_PREFIX}/ai-knowledge-bases/page-init`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/knowledge.ts` | `262` | `request.post` | `POST /api/admin/v1/ai-knowledge-bases` | ``${ADMIN_API_PREFIX}/ai-knowledge-bases`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/knowledge.ts` | `265` | `request.put` | `PUT /api/admin/v1/ai-knowledge-bases/:param` | ``${ADMIN_API_PREFIX}/ai-knowledge-bases/${id}`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/knowledge.ts` | `267` | `request.patch` | `PATCH /api/admin/v1/ai-knowledge-bases/:param/status` | ``${ADMIN_API_PREFIX}/ai-knowledge-bases/${positiveID(params.id, 'AI knowledge base id')}/status`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/knowledge.ts` | `272` | `request.post` | `POST /api/admin/v1/ai-knowledge-bases/:param/documents` | ``${ADMIN_API_PREFIX}/ai-knowledge-bases/${positiveID(params.knowledge_base_id ?? 0, 'AI knowledge base id')}/documents`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/knowledge.ts` | `275` | `request.put` | `PUT /api/admin/v1/ai-knowledge-documents/:param` | ``${ADMIN_API_PREFIX}/ai-knowledge-documents/${id}`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/knowledge.ts` | `280` | `request.get` | `GET /api/admin/v1/ai-knowledge-bases` | ``${ADMIN_API_PREFIX}/ai-knowledge-bases`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/knowledge.ts` | `281` | `request.get` | `GET /api/admin/v1/ai-knowledge-bases/:param` | ``${ADMIN_API_PREFIX}/ai-knowledge-bases/${positiveID(params.id, 'AI knowledge base id')}`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/knowledge.ts` | `287` | `request.get` | `GET /api/admin/v1/ai-knowledge-bases/:param/documents` | ``${ADMIN_API_PREFIX}/ai-knowledge-bases/${positiveID(params.knowledge_base_id, 'AI knowledge base id')}/documents`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/knowledge.ts` | `288` | `request.get` | `GET /api/admin/v1/ai-knowledge-documents/:param` | ``${ADMIN_API_PREFIX}/ai-knowledge-documents/${positiveID(params.id, 'AI knowledge document id')}`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/knowledge.ts` | `293` | `request.patch` | `PATCH /api/admin/v1/ai-knowledge-documents/:param/status` | ``${ADMIN_API_PREFIX}/ai-knowledge-documents/${positiveID(params.id, 'AI knowledge document id')}/status`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/knowledge.ts` | `294` | `request.delete` | `DELETE /api/admin/v1/ai-knowledge-documents/:param` | ``${ADMIN_API_PREFIX}/ai-knowledge-documents/${positiveID(params.id, 'AI knowledge document id')}`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/knowledge.ts` | `295` | `request.post` | `POST /api/admin/v1/ai-knowledge-documents/:param/reindex` | ``${ADMIN_API_PREFIX}/ai-knowledge-documents/${positiveID(params.id, 'AI knowledge document id')}/reindex`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/knowledge.ts` | `296` | `request.get` | `GET /api/admin/v1/ai-knowledge-documents/:param/chunks` | ``${ADMIN_API_PREFIX}/ai-knowledge-documents/${positiveID(params.id, 'AI knowledge document id')}/chunks`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/knowledge.ts` | `297` | `request.post` | `POST /api/admin/v1/ai-knowledge-bases/:param/retrieval-tests` | ``${ADMIN_API_PREFIX}/ai-knowledge-bases/${positiveID(params.knowledge_base_id, 'AI knowledge base id')}/retrieval-tests`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/messages.ts` | `89` | `request.get` | `GET /api/admin/v1/ai-conversations/:param/messages` | ``${ADMIN_API_PREFIX}/ai-conversations/${positiveID(params.conversation_id, 'conversation id')}/messages`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/messages.ts` | `90` | `request.post` | `POST /api/admin/v1/ai-conversations/:param/messages` | ``${ADMIN_API_PREFIX}/ai-conversations/${positiveID(params.conversation_id, 'conversation id')}/messages`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/providers.ts` | `194` | `request.delete` | `DELETE /api/admin/v1/ai-providers/:param` | ``${ADMIN_API_PREFIX}/ai-providers/${id}`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/providers.ts` | `197` | `request.get` | `GET /api/admin/v1/ai-providers/page-init` | ``${ADMIN_API_PREFIX}/ai-providers/page-init`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/providers.ts` | `198` | `request.post` | `POST /api/admin/v1/ai-providers` | ``${ADMIN_API_PREFIX}/ai-providers`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/providers.ts` | `201` | `request.put` | `PUT /api/admin/v1/ai-providers/:param` | ``${ADMIN_API_PREFIX}/ai-providers/${id}`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/providers.ts` | `203` | `request.patch` | `PATCH /api/admin/v1/ai-providers/:param/status` | ``${ADMIN_API_PREFIX}/ai-providers/${positiveID(params.id, 'AI provider id')}/status`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/providers.ts` | `211` | `request.get` | `GET /api/admin/v1/ai-providers` | ``${ADMIN_API_PREFIX}/ai-providers`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/providers.ts` | `212` | `request.post` | `POST /api/admin/v1/ai-providers/model-options` | ``${ADMIN_API_PREFIX}/ai-providers/model-options`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/providers.ts` | `213` | `request.post` | `POST /api/admin/v1/ai-providers/:param/model-options` | ``${ADMIN_API_PREFIX}/ai-providers/${positiveID(params.id, 'AI provider id')}/model-options`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/providers.ts` | `217` | `request.post` | `POST /api/admin/v1/ai-providers/:param/test` | ``${ADMIN_API_PREFIX}/ai-providers/${positiveID(params.id, 'AI provider id')}/test`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/providers.ts` | `218` | `request.post` | `POST /api/admin/v1/ai-providers/:param/sync-models` | ``${ADMIN_API_PREFIX}/ai-providers/${positiveID(params.id, 'AI provider id')}/sync-models`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/providers.ts` | `219` | `request.get` | `GET /api/admin/v1/ai-providers/:param/models` | ``${ADMIN_API_PREFIX}/ai-providers/${positiveID(params.id, 'AI provider id')}/models`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/providers.ts` | `222` | `request.put` | `PUT /api/admin/v1/ai-providers/:param/models` | ``${ADMIN_API_PREFIX}/ai-providers/${id}/models`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/runs.ts` | `274` | `request.get` | `GET /api/admin/v1/ai-runs/page-init` | ``${ADMIN_API_PREFIX}/ai-runs/page-init`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/runs.ts` | `278` | `request.get` | `GET /api/admin/v1/ai-runs` | ``${ADMIN_API_PREFIX}/ai-runs`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/runs.ts` | `279` | `request.get` | `GET /api/admin/v1/ai-runs/:param` | ``${ADMIN_API_PREFIX}/ai-runs/${positiveID(params.id)}`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/runs.ts` | `280` | `request.get` | `GET /api/admin/v1/ai-runs/stats` | ``${ADMIN_API_PREFIX}/ai-runs/stats`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/runs.ts` | `281` | `request.get` | `GET /api/admin/v1/ai-runs/stats/by-date` | ``${ADMIN_API_PREFIX}/ai-runs/stats/by-date`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/runs.ts` | `282` | `request.get` | `GET /api/admin/v1/ai-runs/stats/by-agent` | ``${ADMIN_API_PREFIX}/ai-runs/stats/by-agent`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/runs.ts` | `283` | `request.get` | `GET /api/admin/v1/ai-runs/stats/by-user` | ``${ADMIN_API_PREFIX}/ai-runs/stats/by-user`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/tools.ts` | `155` | `request.delete` | `DELETE /api/admin/v1/ai-tools/:param` | ``${ADMIN_API_PREFIX}/ai-tools/${id}`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/tools.ts` | `158` | `request.get` | `GET /api/admin/v1/ai-tools/page-init` | ``${ADMIN_API_PREFIX}/ai-tools/page-init`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/tools.ts` | `159` | `request.get` | `GET /api/admin/v1/ai-tools/generate/page-init` | ``${ADMIN_API_PREFIX}/ai-tools/generate/page-init`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/tools.ts` | `160` | `request.post` | `POST /api/admin/v1/ai-tools` | ``${ADMIN_API_PREFIX}/ai-tools`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/tools.ts` | `163` | `request.put` | `PUT /api/admin/v1/ai-tools/:param` | ``${ADMIN_API_PREFIX}/ai-tools/${id}`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/tools.ts` | `165` | `request.patch` | `PATCH /api/admin/v1/ai-tools/:param/status` | ``${ADMIN_API_PREFIX}/ai-tools/${positiveID(params.id, 'AI tool id')}/status`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/tools.ts` | `174` | `request.post` | `POST /api/admin/v1/ai-tools/generate-draft` | ``${ADMIN_API_PREFIX}/ai-tools/generate-draft`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/ai/tools.ts` | `175` | `request.get` | `GET /api/admin/v1/ai-tools` | ``${ADMIN_API_PREFIX}/ai-tools`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/payment/config.ts` | `94` | `request.get` | `GET /api/admin/v1/payment/configs/page-init` | ``${ADMIN_API_PREFIX}/payment/configs/page-init`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/payment/config.ts` | `95` | `request.get` | `GET /api/admin/v1/payment/configs` | ``${ADMIN_API_PREFIX}/payment/configs`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/payment/config.ts` | `96` | `request.post` | `POST /api/admin/v1/payment/configs` | ``${ADMIN_API_PREFIX}/payment/configs`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/payment/config.ts` | `97` | `request.put` | `PUT /api/admin/v1/payment/configs/:param` | ``${ADMIN_API_PREFIX}/payment/configs/${positiveID(payload.id ?? 0)}`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/payment/config.ts` | `98` | `request.patch` | `PATCH /api/admin/v1/payment/configs/:param/status` | ``${ADMIN_API_PREFIX}/payment/configs/${positiveID(id)}/status`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/payment/config.ts` | `99` | `request.delete` | `DELETE /api/admin/v1/payment/configs/:param` | ``${ADMIN_API_PREFIX}/payment/configs/${positiveID(id)}`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/payment/config.ts` | `100` | `request.post` | `POST /api/admin/v1/payment/certificates` | ``${ADMIN_API_PREFIX}/payment/certificates`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/payment/config.ts` | `101` | `request.post` | `POST /api/admin/v1/payment/configs/:param/test` | ``${ADMIN_API_PREFIX}/payment/configs/${positiveID(id)}/test`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/payment/recharges.ts` | `94` | `request.get` | `GET /api/admin/v1/payment/recharges/page-init` | ``${ADMIN_API_PREFIX}/payment/recharges/page-init`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/payment/recharges.ts` | `95` | `request.get` | `GET /api/admin/v1/payment/recharges` | ``${ADMIN_API_PREFIX}/payment/recharges`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/payment/recharges.ts` | `96` | `request.get` | `GET /api/admin/v1/payment/recharges/:param` | ``${ADMIN_API_PREFIX}/payment/recharges/${positiveID(id)}`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/payment/recharges.ts` | `97` | `request.post` | `POST /api/admin/v1/payment/recharges` | ``${ADMIN_API_PREFIX}/payment/recharges`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/payment/recharges.ts` | `98` | `request.post` | `POST /api/admin/v1/payment/recharges/:param/pay` | ``${ADMIN_API_PREFIX}/payment/recharges/${positiveID(id)}/pay`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/permission/authPlatform.ts` | `123` | `request.get` | `GET /api/admin/v1/auth-platforms/page-init` | ``${ADMIN_API_PREFIX}/auth-platforms/page-init`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/permission/authPlatform.ts` | `124` | `request.post` | `POST /api/admin/v1/auth-platforms` | ``${ADMIN_API_PREFIX}/auth-platforms`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/permission/authPlatform.ts` | `127` | `request.put` | `PUT /api/admin/v1/auth-platforms/:param` | ``${ADMIN_API_PREFIX}/auth-platforms/${id}`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/permission/authPlatform.ts` | `129` | `request.delete` | `DELETE /api/admin/v1/auth-platforms/:param` | ``${ADMIN_API_PREFIX}/auth-platforms/${normalizeAuthPlatformIDs(params.id)[0]}`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/permission/authPlatform.ts` | `133` | `request.delete` | `DELETE /api/admin/v1/auth-platforms` | ``${ADMIN_API_PREFIX}/auth-platforms`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/permission/authPlatform.ts` | `137` | `request.patch` | `PATCH /api/admin/v1/auth-platforms/:param/status` | ``${ADMIN_API_PREFIX}/auth-platforms/${params.id}/status`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/permission/authPlatform.ts` | `142` | `request.get` | `GET /api/admin/v1/auth-platforms` | ``${ADMIN_API_PREFIX}/auth-platforms`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/permission/permission.ts` | `88` | `request.get` | `GET /api/admin/v1/permissions/page-init` | ``${ADMIN_API_PREFIX}/permissions/page-init`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/permission/permission.ts` | `89` | `request.post` | `POST /api/admin/v1/permissions` | ``${ADMIN_API_PREFIX}/permissions`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/permission/permission.ts` | `92` | `request.put` | `PUT /api/admin/v1/permissions/:param` | ``${ADMIN_API_PREFIX}/permissions/${id}`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/permission/permission.ts` | `94` | `request.delete` | `DELETE /api/admin/v1/permissions/:param` | ``${ADMIN_API_PREFIX}/permissions/${params.id}`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/permission/permission.ts` | `95` | `request.delete` | `DELETE /api/admin/v1/permissions` | ``${ADMIN_API_PREFIX}/permissions`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/permission/permission.ts` | `98` | `request.patch` | `PATCH /api/admin/v1/permissions/:param/status` | ``${ADMIN_API_PREFIX}/permissions/${params.id}/status`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/permission/permission.ts` | `103` | `request.get` | `GET /api/admin/v1/permissions` | ``${ADMIN_API_PREFIX}/permissions`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/permission/role.ts` | `64` | `request.get` | `GET /api/admin/v1/roles/page-init` | ``${ADMIN_API_PREFIX}/roles/page-init`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/permission/role.ts` | `65` | `request.post` | `POST /api/admin/v1/roles` | ``${ADMIN_API_PREFIX}/roles`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/permission/role.ts` | `68` | `request.put` | `PUT /api/admin/v1/roles/:param` | ``${ADMIN_API_PREFIX}/roles/${id}`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/permission/role.ts` | `70` | `request.delete` | `DELETE /api/admin/v1/roles/:param` | ``${ADMIN_API_PREFIX}/roles/${normalizeRoleIDs(params.id)[0]}`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/permission/role.ts` | `74` | `request.delete` | `DELETE /api/admin/v1/roles` | ``${ADMIN_API_PREFIX}/roles`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/permission/role.ts` | `79` | `request.get` | `GET /api/admin/v1/roles` | ``${ADMIN_API_PREFIX}/roles`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/permission/role.ts` | `85` | `request.patch` | `PATCH /api/admin/v1/roles/:param/default` | ``${ADMIN_API_PREFIX}/roles/${params.id}/default`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/clientVersion.ts` | `140` | `request.get` | `GET /api/admin/v1/client-versions/page-init` | ``${BASE}/page-init`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/clientVersion.ts` | `141` | `request.get` | `GET /api/admin/v1/client-versions` | `BASE` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/clientVersion.ts` | `142` | `request.post` | `POST /api/admin/v1/client-versions` | `BASE` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/clientVersion.ts` | `143` | `request.put` | `PUT /api/admin/v1/client-versions/:param` | ``${BASE}/${assertPositiveID(params.id, 'client version id')}`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/clientVersion.ts` | `144` | `request.patch` | `PATCH /api/admin/v1/client-versions/:param/latest` | ``${BASE}/${assertPositiveID(params.id, 'client version id')}/latest`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/clientVersion.ts` | `145` | `request.delete` | `DELETE /api/admin/v1/client-versions/:param` | ``${BASE}/${assertSingleID(params.id)}`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/clientVersion.ts` | `146` | `request.get` | `GET /api/admin/v1/client-versions/update-json` | ``${BASE}/update-json`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/clientVersion.ts` | `147` | `request.patch` | `PATCH /api/admin/v1/client-versions/:param/force-update` | ``${BASE}/${assertPositiveID(params.id, 'client version id')}/force-update`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/clientVersion.ts` | `148` | `request.get` | `GET /api/admin/v1/client-versions/current-check` | ``${BASE}/current-check`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/cronTask.ts` | `76` | `request.get` | `GET /api/admin/v1/cron-tasks/page-init` | ``${ADMIN_API_PREFIX}/cron-tasks/page-init`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/cronTask.ts` | `77` | `request.post` | `POST /api/admin/v1/cron-tasks` | ``${ADMIN_API_PREFIX}/cron-tasks`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/cronTask.ts` | `78` | `request.put` | `PUT /api/admin/v1/cron-tasks/:param` | ``${ADMIN_API_PREFIX}/cron-tasks/${params.id}`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/cronTask.ts` | `79` | `request.delete` | `DELETE /api/admin/v1/cron-tasks/:param` | ``${ADMIN_API_PREFIX}/cron-tasks/${params.id}`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/cronTask.ts` | `80` | `request.delete` | `DELETE /api/admin/v1/cron-tasks` | ``${ADMIN_API_PREFIX}/cron-tasks`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/cronTask.ts` | `81` | `request.patch` | `PATCH /api/admin/v1/cron-tasks/:param/status` | ``${ADMIN_API_PREFIX}/cron-tasks/${params.id}/status`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/cronTask.ts` | `85` | `request.get` | `GET /api/admin/v1/cron-tasks` | ``${ADMIN_API_PREFIX}/cron-tasks`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/cronTask.ts` | `91` | `request.get` | `GET /api/admin/v1/cron-tasks/:param/logs` | ``${ADMIN_API_PREFIX}/cron-tasks/${params.task_id}/logs`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/exportTask.ts` | `57` | `request.get` | `GET /api/admin/v1/export-tasks/status-count` | ``${ADMIN_API_PREFIX}/export-tasks/status-count`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/exportTask.ts` | `60` | `request.get` | `GET /api/admin/v1/export-tasks` | ``${ADMIN_API_PREFIX}/export-tasks`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/exportTask.ts` | `68` | `request.delete` | `DELETE /api/admin/v1/export-tasks/:param` | ``${ADMIN_API_PREFIX}/export-tasks/${firstID}`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/exportTask.ts` | `73` | `request.delete` | `DELETE /api/admin/v1/export-tasks` | ``${ADMIN_API_PREFIX}/export-tasks`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/log.ts` | `46` | `request.get` | `GET /api/admin/v1/system-logs/page-init` | ``${BASE}/page-init`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/log.ts` | `50` | `request.get` | `GET /api/admin/v1/system-logs/files` | ``${BASE}/files`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/log.ts` | `51` | `request.get` | `GET /api/admin/v1/system-logs/files/:param/lines` | ``${BASE}/files/${encodeURIComponent(filename)}/lines`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/mail.ts` | `211` | `request.delete` | `DELETE /api/admin/v1/mail/logs/:param` | ``${BASE}/logs/${ids[0]}`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/mail.ts` | `213` | `request.delete` | `DELETE /api/admin/v1/mail/logs` | ``${BASE}/logs`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/mail.ts` | `217` | `request.get` | `GET /api/admin/v1/mail/page-init` | ``${BASE}/page-init`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/mail.ts` | `218` | `request.get` | `GET /api/admin/v1/mail/config` | ``${BASE}/config`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/mail.ts` | `219` | `request.put` | `PUT /api/admin/v1/mail/config` | ``${BASE}/config`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/mail.ts` | `220` | `request.delete` | `DELETE /api/admin/v1/mail/config` | ``${BASE}/config`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/mail.ts` | `221` | `request.post` | `POST /api/admin/v1/mail/test` | ``${BASE}/test`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/mail.ts` | `222` | `request.get` | `GET /api/admin/v1/mail/templates` | ``${BASE}/templates`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/mail.ts` | `223` | `request.post` | `POST /api/admin/v1/mail/templates` | ``${BASE}/templates`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/mail.ts` | `224` | `request.post` | `POST /api/admin/v1/mail/templates` | ``${BASE}/templates`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/mail.ts` | `225` | `request.put` | `PUT /api/admin/v1/mail/templates/:param` | ``${BASE}/templates/${assertPositiveID(id, 'mail template id')}`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/mail.ts` | `226` | `request.put` | `PUT /api/admin/v1/mail/templates/:param` | ``${BASE}/templates/${assertPositiveID(id, 'mail template id')}`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/mail.ts` | `227` | `request.patch` | `PATCH /api/admin/v1/mail/templates/:param/status` | ``${BASE}/templates/${assertPositiveID(id, 'mail template id')}/status`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/mail.ts` | `228` | `request.patch` | `PATCH /api/admin/v1/mail/templates/:param/status` | ``${BASE}/templates/${assertPositiveID(id, 'mail template id')}/status`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/mail.ts` | `229` | `request.delete` | `DELETE /api/admin/v1/mail/templates/:param` | ``${BASE}/templates/${assertPositiveID(id, 'mail template id')}`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/mail.ts` | `230` | `request.get` | `GET /api/admin/v1/mail/logs` | ``${BASE}/logs`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/mail.ts` | `231` | `request.get` | `GET /api/admin/v1/mail/logs/:param` | ``${BASE}/logs/${assertPositiveID(id, 'mail log id')}`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/mail.ts` | `232` | `request.delete` | `DELETE /api/admin/v1/mail/logs/:param` | ``${BASE}/logs/${assertPositiveID(id, 'mail log id')}`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/notification.ts` | `125` | `request.get` | `GET /api/admin/v1/notifications/page-init` | ``${ADMIN_API_PREFIX}/notifications/page-init`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/notification.ts` | `126` | `request.delete` | `DELETE /api/admin/v1/notifications/:param` | ``${ADMIN_API_PREFIX}/notifications/${normalizeNotificationIDs(params.id)[0]}`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/notification.ts` | `129` | `request.delete` | `DELETE /api/admin/v1/notifications` | ``${ADMIN_API_PREFIX}/notifications`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/notification.ts` | `137` | `request.get` | `GET /api/admin/v1/notifications` | ``${ADMIN_API_PREFIX}/notifications`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/notification.ts` | `140` | `request.get` | `GET /api/admin/v1/notifications/unread-count` | ``${ADMIN_API_PREFIX}/notifications/unread-count`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/notification.ts` | `145` | `request.patch` | `PATCH /api/admin/v1/notifications/read` | ``${ADMIN_API_PREFIX}/notifications/read`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/notification.ts` | `150` | `request.patch` | `PATCH /api/admin/v1/notifications/:param/read` | ``${ADMIN_API_PREFIX}/notifications/${ids[0]}/read`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/notification.ts` | `154` | `request.patch` | `PATCH /api/admin/v1/notifications/read` | ``${ADMIN_API_PREFIX}/notifications/read`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/notificationTask.ts` | `105` | `request.get` | `GET /api/admin/v1/notification-tasks/page-init` | ``${BASE}/page-init`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/notificationTask.ts` | `107` | `request.post` | `POST /api/admin/v1/notification-tasks` | `BASE` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/notificationTask.ts` | `108` | `request.delete` | `DELETE /api/admin/v1/notification-tasks/:param` | ``${BASE}/${normalizeTaskID(params.id)}`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/notificationTask.ts` | `113` | `request.get` | `GET /api/admin/v1/notification-tasks/status-count` | ``${BASE}/status-count`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/notificationTask.ts` | `115` | `request.get` | `GET /api/admin/v1/notification-tasks` | `BASE` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/notificationTask.ts` | `118` | `request.patch` | `PATCH /api/admin/v1/notification-tasks/:param/cancel` | ``${BASE}/${normalizeTaskID(params.id)}/cancel`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/operationLog.ts` | `95` | `request.get` | `GET /api/admin/v1/operation-logs/page-init` | ``${BASE}/page-init`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/operationLog.ts` | `96` | `request.delete` | `DELETE /api/admin/v1/operation-logs/:param` | ``${BASE}/${normalizeIds(params.id)[0]}`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/operationLog.ts` | `97` | `request.delete` | `DELETE /api/admin/v1/operation-logs` | `BASE` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/operationLog.ts` | `102` | `request.get` | `GET /api/admin/v1/operation-logs` | `BASE` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/queueMonitor.ts` | `10` | `service.head` | `HEAD /api/admin/v1/queue-monitor-ui` | `ADMIN_QUEUE_MONITOR_UI_PATH` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/setting.ts` | `110` | `request.get` | `GET /api/admin/v1/system-settings/page-init` | ``${BASE}/page-init`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/setting.ts` | `111` | `request.post` | `POST /api/admin/v1/system-settings` | `BASE` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/setting.ts` | `114` | `request.put` | `PUT /api/admin/v1/system-settings/:param` | ``${BASE}/${id}`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/setting.ts` | `116` | `request.delete` | `DELETE /api/admin/v1/system-settings/:param` | ``${BASE}/${normalizeSystemSettingIDs(params.id)[0]}`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/setting.ts` | `119` | `request.delete` | `DELETE /api/admin/v1/system-settings` | `BASE` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/setting.ts` | `123` | `request.patch` | `PATCH /api/admin/v1/system-settings/:param/status` | ``${BASE}/${normalizeSystemSettingIDs(params.id)[0]}/status`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/setting.ts` | `128` | `request.get` | `GET /api/admin/v1/system-settings` | `BASE` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/sms.ts` | `206` | `request.delete` | `DELETE /api/admin/v1/sms/logs/:param` | ``${BASE}/logs/${ids[0]}`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/sms.ts` | `208` | `request.delete` | `DELETE /api/admin/v1/sms/logs` | ``${BASE}/logs`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/sms.ts` | `212` | `request.get` | `GET /api/admin/v1/sms/page-init` | ``${BASE}/page-init`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/sms.ts` | `213` | `request.get` | `GET /api/admin/v1/sms/config` | ``${BASE}/config`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/sms.ts` | `214` | `request.put` | `PUT /api/admin/v1/sms/config` | ``${BASE}/config`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/sms.ts` | `215` | `request.delete` | `DELETE /api/admin/v1/sms/config` | ``${BASE}/config`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/sms.ts` | `216` | `request.post` | `POST /api/admin/v1/sms/test` | ``${BASE}/test`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/sms.ts` | `217` | `request.get` | `GET /api/admin/v1/sms/templates` | ``${BASE}/templates`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/sms.ts` | `218` | `request.post` | `POST /api/admin/v1/sms/templates` | ``${BASE}/templates`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/sms.ts` | `219` | `request.put` | `PUT /api/admin/v1/sms/templates/:param` | ``${BASE}/templates/${assertPositiveID(id, 'sms template id')}`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/sms.ts` | `220` | `request.patch` | `PATCH /api/admin/v1/sms/templates/:param/status` | ``${BASE}/templates/${assertPositiveID(id, 'sms template id')}/status`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/sms.ts` | `221` | `request.delete` | `DELETE /api/admin/v1/sms/templates/:param` | ``${BASE}/templates/${assertPositiveID(id, 'sms template id')}`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/sms.ts` | `222` | `request.get` | `GET /api/admin/v1/sms/logs` | ``${BASE}/logs`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/sms.ts` | `223` | `request.get` | `GET /api/admin/v1/sms/logs/:param` | ``${BASE}/logs/${assertPositiveID(id, 'sms log id')}`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/sms.ts` | `224` | `request.delete` | `DELETE /api/admin/v1/sms/logs/:param` | ``${BASE}/logs/${assertPositiveID(id, 'sms log id')}`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/uploadConfig.ts` | `282` | `request.get` | `GET /api/admin/v1/upload-drivers/page-init` | ``${DRIVER_BASE}/page-init`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/uploadConfig.ts` | `283` | `request.post` | `POST /api/admin/v1/upload-drivers` | `DRIVER_BASE` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/uploadConfig.ts` | `286` | `request.put` | `PUT /api/admin/v1/upload-drivers/:param` | ``${DRIVER_BASE}/${id}`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/uploadConfig.ts` | `293` | `request.get` | `GET /api/admin/v1/upload-drivers` | `DRIVER_BASE` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/uploadConfig.ts` | `300` | `request.get` | `GET /api/admin/v1/upload-rules/page-init` | ``${RULE_BASE}/page-init`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/uploadConfig.ts` | `301` | `request.post` | `POST /api/admin/v1/upload-rules` | `RULE_BASE` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/uploadConfig.ts` | `304` | `request.put` | `PUT /api/admin/v1/upload-rules/:param` | ``${RULE_BASE}/${id}`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/uploadConfig.ts` | `311` | `request.get` | `GET /api/admin/v1/upload-rules` | `RULE_BASE` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/uploadConfig.ts` | `318` | `request.get` | `GET /api/admin/v1/upload-settings/page-init` | ``${SETTING_BASE}/page-init`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/uploadConfig.ts` | `319` | `request.post` | `POST /api/admin/v1/upload-settings` | `SETTING_BASE` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/uploadConfig.ts` | `322` | `request.put` | `PUT /api/admin/v1/upload-settings/:param` | ``${SETTING_BASE}/${id}`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/uploadConfig.ts` | `329` | `request.patch` | `PATCH /api/admin/v1/upload-settings/:param/status` | ``${SETTING_BASE}/${ids[0]}/status`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/uploadConfig.ts` | `334` | `request.get` | `GET /api/admin/v1/upload-settings` | `SETTING_BASE` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/system/uploadToken.ts` | `42` | `request.post` | `POST /api/admin/v1/upload-tokens` | `BASE` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/user/users.ts` | `122` | `request.get` | `GET /api/admin/v1/users/me` | ``${ADMIN_API_PREFIX}/users/me`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/user/users.ts` | `128` | `request.get` | `GET /api/admin/v1/auth/login-config` | ``${ADMIN_API_PREFIX}/auth/login-config`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/user/users.ts` | `131` | `request.get` | `GET /api/admin/v1/auth/captcha` | ``${ADMIN_API_PREFIX}/auth/captcha`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/user/users.ts` | `134` | `request.post` | `POST /api/admin/v1/auth/login` | ``${ADMIN_API_PREFIX}/auth/login`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/user/users.ts` | `137` | `request.post` | `POST /api/admin/v1/auth/refresh` | ``${ADMIN_API_PREFIX}/auth/refresh`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/user/users.ts` | `140` | `request.post` | `POST /api/admin/v1/auth/logout` | ``${ADMIN_API_PREFIX}/auth/logout`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/user/users.ts` | `143` | `request.post` | `POST /api/admin/v1/auth/send-code` | ``${ADMIN_API_PREFIX}/auth/send-code`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/user/users.ts` | `146` | `request.post` | `POST /api/admin/v1/auth/forgot-password` | ``${ADMIN_API_PREFIX}/auth/forgot-password`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/user/users.ts` | `152` | `request.get` | `GET /api/admin/v1/users/:param/profile` | ``${ADMIN_API_PREFIX}/users/${userID}/profile`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/user/users.ts` | `154` | `request.get` | `GET /api/admin/v1/profile` | ``${ADMIN_API_PREFIX}/profile`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/user/users.ts` | `158` | `request.put` | `PUT /api/admin/v1/profile` | ``${ADMIN_API_PREFIX}/profile`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/user/users.ts` | `161` | `request.put` | `PUT /api/admin/v1/profile/security/phone` | ``${ADMIN_API_PREFIX}/profile/security/phone`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/user/users.ts` | `164` | `request.put` | `PUT /api/admin/v1/profile/security/email` | ``${ADMIN_API_PREFIX}/profile/security/email`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/user/users.ts` | `167` | `request.put` | `PUT /api/admin/v1/profile/security/password` | ``${ADMIN_API_PREFIX}/profile/security/password`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/user/users.ts` | `172` | `request.get` | `GET /api/admin/v1/users/page-init` | ``${ADMIN_API_PREFIX}/users/page-init`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/user/users.ts` | `175` | `request.get` | `GET /api/admin/v1/users` | ``${ADMIN_API_PREFIX}/users`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/user/users.ts` | `179` | `request.put` | `PUT /api/admin/v1/users/:param` | ``${ADMIN_API_PREFIX}/users/${id}`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/user/users.ts` | `183` | `request.patch` | `PATCH /api/admin/v1/users` | ``${ADMIN_API_PREFIX}/users`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/user/users.ts` | `188` | `request.patch` | `PATCH /api/admin/v1/users/:param/status` | ``${ADMIN_API_PREFIX}/users/${ids[0]}/status`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/user/users.ts` | `194` | `request.delete` | `DELETE /api/admin/v1/users/:param` | ``${ADMIN_API_PREFIX}/users/${ids[0]}`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/user/users.ts` | `197` | `request.delete` | `DELETE /api/admin/v1/users` | ``${ADMIN_API_PREFIX}/users`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/user/users.ts` | `201` | `request.post` | `POST /api/admin/v1/users/export` | ``${ADMIN_API_PREFIX}/users/export`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/user/users.ts` | `206` | `request.get` | `GET /api/admin/v1/user-sessions/page-init` | ``${ADMIN_API_PREFIX}/user-sessions/page-init`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/user/users.ts` | `209` | `request.get` | `GET /api/admin/v1/user-sessions` | ``${ADMIN_API_PREFIX}/user-sessions`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/user/users.ts` | `212` | `request.get` | `GET /api/admin/v1/user-sessions/stats` | ``${ADMIN_API_PREFIX}/user-sessions/stats`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/user/users.ts` | `215` | `request.patch` | `PATCH /api/admin/v1/user-sessions/:param/revoke` | ``${ADMIN_API_PREFIX}/user-sessions/${params.id}/revoke`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/user/users.ts` | `219` | `request.patch` | `PATCH /api/admin/v1/user-sessions/revoke` | ``${ADMIN_API_PREFIX}/user-sessions/revoke`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/user/usersLoginLog.ts` | `45` | `request.get` | `GET /api/admin/v1/users/login-logs/page-init` | ``${ADMIN_API_PREFIX}/users/login-logs/page-init`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/user/usersLoginLog.ts` | `48` | `request.get` | `GET /api/admin/v1/users/login-logs` | ``${ADMIN_API_PREFIX}/users/login-logs`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/wallet/index.ts` | `82` | `request.get` | `GET /api/admin/v1/wallet/summary` | ``${ADMIN_API_PREFIX}/wallet/summary`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/wallet/index.ts` | `83` | `request.get` | `GET /api/admin/v1/wallet/transactions` | ``${ADMIN_API_PREFIX}/wallet/transactions`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/wallet/index.ts` | `84` | `request.get` | `GET /api/admin/v1/payment/wallets/page-init` | ``${ADMIN_API_PREFIX}/payment/wallets/page-init`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/wallet/index.ts` | `85` | `request.get` | `GET /api/admin/v1/payment/wallets` | ``${ADMIN_API_PREFIX}/payment/wallets`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/wallet/index.ts` | `86` | `request.get` | `GET /api/admin/v1/payment/ledger/page-init` | ``${ADMIN_API_PREFIX}/payment/ledger/page-init`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/api/wallet/index.ts` | `87` | `request.get` | `GET /api/admin/v1/payment/ledger` | ``${ADMIN_API_PREFIX}/payment/ledger`` | `admin-prefix` |
| `admin_front_ts` | `admin_front_ts/src/lib/http/auth-session.ts` | `77` | `axios.post` | `POST /api/admin/v1/auth/refresh` | ``${baseURL}${REFRESH_PATH}`` | `admin-prefix` |
| `canvas_front_next` | `canvas_front_next/src/services/api/assets.ts` | `51` | `apiGet` | `GET /api/canvas/v1/assets` | `"/api/canvas/v1/assets"` | `canvas-prefix` |
| `canvas_front_next` | `canvas_front_next/src/services/api/auth.ts` | `107` | `apiPost` | `POST /api/canvas/v1/auth/login` | `"/api/canvas/v1/auth/login"` | `canvas-prefix` |
| `canvas_front_next` | `canvas_front_next/src/services/api/auth.ts` | `112` | `apiPost` | `POST /api/canvas/v1/auth/refresh` | `"/api/canvas/v1/auth/refresh"` | `canvas-prefix` |
| `canvas_front_next` | `canvas_front_next/src/services/api/auth.ts` | `117` | `apiPost` | `POST /api/canvas/v1/auth/logout` | `"/api/canvas/v1/auth/logout"` | `canvas-prefix` |
| `canvas_front_next` | `canvas_front_next/src/services/api/auth.ts` | `121` | `apiPost` | `POST /api/canvas/v1/auth/send-code` | `"/api/canvas/v1/auth/send-code"` | `canvas-prefix` |
| `canvas_front_next` | `canvas_front_next/src/services/api/auth.ts` | `125` | `apiGet` | `GET /api/canvas/v1/auth/login-config` | `"/api/canvas/v1/auth/login-config"` | `canvas-prefix` |
| `canvas_front_next` | `canvas_front_next/src/services/api/auth.ts` | `129` | `apiGet` | `GET /api/canvas/v1/auth/captcha` | `"/api/canvas/v1/auth/captcha"` | `canvas-prefix` |
| `canvas_front_next` | `canvas_front_next/src/services/api/auth.ts` | `133` | `apiGet` | `GET /api/canvas/v1/users/me` | `"/api/canvas/v1/users/me"` | `canvas-prefix` |
| `canvas_front_next` | `canvas_front_next/src/services/api/image.ts` | `178` | `axios.post` | `POST /api/canvas/v1/ai/images/generations` | `CANVAS_IMAGE_GENERATION_URL` | `canvas-prefix` |
| `canvas_front_next` | `canvas_front_next/src/services/api/image.ts` | `196` | `axios.get` | `GET /api/canvas/v1/ai/images/:param` | ``${CANVAS_IMAGE_TASK_URL}/${taskID}`` | `canvas-prefix` |
| `canvas_front_next` | `canvas_front_next/src/services/api/image.ts` | `224` | `axios.post` | `POST /api/canvas/v1/ai/images/edits` | `CANVAS_IMAGE_EDIT_URL` | `canvas-prefix` |
| `canvas_front_next` | `canvas_front_next/src/services/api/image.ts` | `238` | `axios.post` | `POST /api/canvas/v1/ai/chat/completions` | `CANVAS_CHAT_URL` | `canvas-prefix` |
| `canvas_front_next` | `canvas_front_next/src/services/api/profile.ts` | `53` | `apiGet` | `GET /api/canvas/v1/profile` | `"/api/canvas/v1/profile"` | `canvas-prefix` |
| `canvas_front_next` | `canvas_front_next/src/services/api/profile.ts` | `57` | `apiPut` | `PUT /api/canvas/v1/profile` | `"/api/canvas/v1/profile"` | `canvas-prefix` |
| `canvas_front_next` | `canvas_front_next/src/services/api/prompts.ts` | `44` | `apiGet` | `GET /api/canvas/v1/prompts` | `"/api/canvas/v1/prompts"` | `canvas-prefix` |
| `canvas_front_next` | `canvas_front_next/src/services/api/settings.ts` | `24` | `apiGet` | `GET /api/canvas/v1/settings` | `"/api/canvas/v1/settings"` | `canvas-prefix` |
| `canvas_front_next` | `canvas_front_next/src/services/api/video.ts` | `41` | `axios.post` | `POST /api/canvas/v1/ai/videos` | `CANVAS_VIDEO_URL` | `canvas-prefix` |
| `canvas_front_next` | `canvas_front_next/src/services/api/video.ts` | `45` | `axios.get` | `GET /api/canvas/v1/ai/videos/:param` | ``${CANVAS_VIDEO_URL}/${created.id}`` | `canvas-prefix` |
| `canvas_front_next` | `canvas_front_next/src/services/api/video.ts` | `51` | `axios.get` | `GET /api/canvas/v1/ai/videos/:param/content` | ``${CANVAS_VIDEO_URL}/${created.id}/content`` | `canvas-prefix` |

## Non-backend and infrastructure calls

External/blob/dynamic/proxy/parametric rows are kept separate so they do not become false backend contract drift.

| Project | Source | Line | Client | Method path | Raw URL expression | Classification |
| --- | --- | ---: | --- | --- | --- | --- |
| `admin_front_ts` | `admin_front_ts/src/api/system/uploadConfig.ts` | `275` | `request.delete` | `DELETE :param/:param` | ``${base}/${ids[0]}`` | `backend-admin-parametric` |
| `admin_front_ts` | `admin_front_ts/src/api/system/uploadConfig.ts` | `279` | `request.delete` | `DELETE` | `base` | `backend-admin-parametric` |
| `admin_front_ts` | `admin_front_ts/src/components/DownloadManager/src/download.ts` | `247` | `fetch` | `GET` | `url` | `blob/download` |
| `canvas_front_next` | `canvas_front_next/src/app/(user)/canvas/components/asset-picker-modal.tsx` | `181` | `axios.get` | `GET` | `url` | `blob/download` |
| `canvas_front_next` | `canvas_front_next/src/services/file-storage.ts` | `83` | `axios.get` | `GET` | `url` | `blob/download` |
| `canvas_front_next` | `canvas_front_next/src/services/image-storage.ts` | `97` | `axios.get` | `GET` | `url` | `blob/download` |
| `canvas_front_next` | `canvas_front_next/src/hooks/use-version-check.ts` | `42` | `axios.get` | `GET https://raw.githubusercontent.com/basketikun/infinite-canvas/main/VERSION` | `latestVersionUrl` | `external` |
| `canvas_front_next` | `canvas_front_next/src/hooks/use-version-check.ts` | `55` | `axios.get` | `GET https://raw.githubusercontent.com/basketikun/infinite-canvas/main/VERSION` | `latestVersionUrl` | `external` |
| `canvas_front_next` | `canvas_front_next/src/hooks/use-version-check.ts` | `55` | `axios.get` | `GET https://raw.githubusercontent.com/basketikun/infinite-canvas/main/CHANGELOG.md` | `latestChangelogUrl` | `external` |
| `canvas_front_next` | `canvas_front_next/src/app/api/[...path]/route.ts` | `52` | `axios.request` | `ANY :param/api/:param:param` | `target` | `next-proxy` |
| `admin_front_ts` | `admin_front_ts/src/lib/http/client.ts` | `98` | `service.get` | `GET` | `url` | `wrapper-internal` |
| `admin_front_ts` | `admin_front_ts/src/lib/http/client.ts` | `101` | `service.post` | `POST` | `url` | `wrapper-internal` |
| `admin_front_ts` | `admin_front_ts/src/lib/http/client.ts` | `104` | `service.put` | `PUT` | `url` | `wrapper-internal` |
| `admin_front_ts` | `admin_front_ts/src/lib/http/client.ts` | `107` | `service.patch` | `PATCH` | `url` | `wrapper-internal` |
| `admin_front_ts` | `admin_front_ts/src/lib/http/client.ts` | `110` | `service.delete` | `DELETE` | `url` | `wrapper-internal` |
| `canvas_front_next` | `canvas_front_next/src/services/api/request.ts` | `96` | `axios.request` | `ANY` | `config.url` | `wrapper-internal` |

## Parser boundary

```text
Included: .ts, .tsx, and Vue <script> blocks under active Admin Vue and Canvas Next source roots.
Excluded: *.test.ts, *.test.tsx, and *.d.ts files.
Resolved: literal strings, simple consts, simple binary string concat, template strings with known consts, and dynamic path segments as :param.
Not guessed: arbitrary runtime URL variables, blob download URLs, Next proxy targetUrl, wrapper config.url, and parametric helper base paths.
```

## Verification command

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\export-frontend-api-inventory.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1 -LiveSchema
```
