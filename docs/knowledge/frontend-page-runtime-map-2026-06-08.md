# Frontend Page Runtime Map

Date: 2026-06-08

This is the page-to-runtime reverse map for Admin Vue and Canvas Next. It maps page source to backend capability, API surface, permission/button codes, and DB ownership. It is a handoff map; exact route/API counts still come from generated inventories and live MySQL.

## Summary

| Fact | Count |
| --- | ---: |
| Admin Vue pages mapped | `32` |
| Canvas Next pages mapped | `9` |
| Total pages mapped | `41` |

## Page map

| Frontend | Route | Page source | Backend capability | API surface | Permission / button codes | DB/runtime ownership | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `admin_front_ts` | `/ai/agents` | `admin_front_ts/src/views/Main/ai/agents/index.vue` | `ai/agent` | GET/POST/PUT/PATCH/DELETE /api/admin/v1/ai-agents* | ai_agent_add, ai_agent_edit, ai_agent_test, ai_agent_status, ai_agent_del, ai_agent_binding_add | ai_agents, ai_provider_models, ai_providers, ai_agent_tools, ai_agent_knowledge_bases | active Admin AI management |
| `admin_front_ts` | `/ai/chat` | `admin_front_ts/src/views/Main/ai/chat/index.vue` | `ai/chat, ai/conversation, ai/message` | /api/admin/v1/ai-conversations*, /api/admin/v1/ai-conversations/:id/messages/cancel | PAGE only / no page-specific button code in current live permission rows | ai_conversations, ai_messages, ai_runs, ai_run_events | admin AI chat console; realtime events use WS boundary |
| `admin_front_ts` | `/ai/knowledge` | `admin_front_ts/src/views/Main/ai/knowledge/index.vue` | `ai/knowledge` | /api/admin/v1/ai-knowledge-bases*, /documents*, /retrieval-test, /reindex | ai_knowledge_add, ai_knowledge_edit, ai_knowledge_del, ai_knowledge_status, ai_knowledge_document_add/edit/del/status, ai_knowledge_retrieval_test, ai_knowledge_reindex | ai_knowledge_bases, ai_knowledge_documents, ai_knowledge_chunks, ai_knowledge_retrievals, ai_knowledge_retrieval_hits | knowledge-base CRUD and retrieval review |
| `admin_front_ts` | `/ai/prompts` | `admin_front_ts/src/views/Main/ai/prompts/index.vue` | `ai/prompt` | /api/admin/v1/ai-prompts* | PAGE only in current live permission rows | ai_prompts | Admin owns prompts; Canvas uses canvas prompt surface |
| `admin_front_ts` | `/ai/providers` | `admin_front_ts/src/views/Main/ai/providers/index.vue` | `ai/provider` | /api/admin/v1/ai-providers* | ai_provider_add, ai_provider_edit, ai_provider_test, ai_provider_status, ai_provider_del | ai_providers, ai_provider_models | provider config and model sync |
| `admin_front_ts` | `/ai/runs` | `admin_front_ts/src/views/Main/ai/runs/index.vue` | `ai/run` | /api/admin/v1/ai-runs* | PAGE only / monitor actions are API-owned | ai_runs, ai_run_events, ai_knowledge_retrievals, ai_tool_calls | provider-attempt monitor; ai_runs no longer owns source polymorphism |
| `admin_front_ts` | `/ai/tools` | `admin_front_ts/src/views/Main/ai/tools/index.vue` | `ai/tool` | /api/admin/v1/ai-tools* | ai_tool_add, ai_tool_edit, ai_tool_status, ai_tool_del, ai_tool_generate | ai_tools | tool registry and AI generation helper |
| `admin_front_ts` | `/home` | `admin_front_ts/src/views/Main/home/index.vue` | `dashboard/home` | dashboard/bootstrap local state and navigation links | root dashboard PAGE | users/me payload, notifications summary | home is shell/dashboard; do not invent backend-only owner |
| `admin_front_ts` | `/notification` | `admin_front_ts/src/views/Main/notification/index.vue` | `notification` | /api/admin/v1/notifications* | personal notification PAGE; batch read/delete through notification API | notifications | personal notifications and realtime fan-out target |
| `admin_front_ts` | `/payment/config` | `admin_front_ts/src/views/Main/payment/config/index.vue` | `payment` | /api/admin/v1/payment/configs* | payment_config_add, payment_config_edit, payment_config_status, payment_config_del, payment_config_upload_cert, payment_config_test | payment_configs | payment provider config and cert upload |
| `admin_front_ts` | `/payment/ledger` | `admin_front_ts/src/views/Main/payment/ledger/index.vue` | `payment/wallet` | /api/admin/v1/wallet/transactions or ledger APIs | wallet_ledger_list is soft-deleted in live rows; current page source still exists | wallet_transactions, wallets | treat as retained source/page until product owner retires or reactivates route |
| `admin_front_ts` | `/payment/recharge` | `admin_front_ts/src/views/Main/payment/recharge/index.vue` | `payment` | /api/admin/v1/payment/recharges* | payment_recharge_list, payment_recharge_add, payment_recharge_pay; sync/close are soft-deleted | payment_recharges, payment_configs, wallets, wallet_transactions | Admin recharge management |
| `admin_front_ts` | `/payment/wallets` | `admin_front_ts/src/views/Main/payment/wallets/index.vue` | `payment/wallet` | /api/admin/v1/payment/wallets*, /api/admin/v1/wallet/* | payment_wallets page source; wallet_user_list is soft-deleted in live rows | wallets, wallet_transactions, users | Admin user wallet view |
| `admin_front_ts` | `/permission/authPlatform` | `admin_front_ts/src/views/Main/permission/authPlatform/index.vue` | `auth_platform` | /api/admin/v1/auth-platforms* | permission_authPlatform_add, permission_authPlatform_edit, permission_authPlatform_del, permission_authPlatform_status | auth_platforms | login method/session/register policy |
| `admin_front_ts` | `/permission/permission` | `admin_front_ts/src/views/Main/permission/permission/index.vue` | `permission` | /api/admin/v1/permissions* | permission_permission_add, permission_permission_edit, permission_permission_del, permission_permission_status | permissions | menu/route/button source of truth |
| `admin_front_ts` | `/permission/role` | `admin_front_ts/src/views/Main/permission/role/index.vue` | `role` | /api/admin/v1/roles* | permission_role_add, permission_role_edit, permission_role_del, permission_role_setDefault | roles, role_permissions | RBAC role management |
| `admin_front_ts` | `/personal` | `admin_front_ts/src/views/Main/personal/index.vue` | `profile/user` | /api/admin/v1/profile*, /api/admin/v1/profile/security/* | personal PAGE; profile actions are user-owned | users, user_auth_identities, login_logs | current admin profile and security settings |
| `admin_front_ts` | `/personal/wallet` | `admin_front_ts/src/views/Main/personal/wallet/index.vue` | `payment/wallet` | /api/admin/v1/wallet/summary, /wallet/transactions | personal wallet PAGE | wallets, wallet_transactions | personal wallet center, links to recharge |
| `admin_front_ts` | `/profile/wallet` | `admin_front_ts/src/views/Main/profile/wallet/index.vue` | `payment/wallet` | /api/admin/v1/wallet/summary, /wallet/transactions | profile wallet PAGE | wallets, wallet_transactions | legacy/alternate personal wallet source; verify route before exposing |
| `admin_front_ts` | `/system/clientVersion` | `admin_front_ts/src/views/Main/system/clientVersion/index.vue` | `clientversion` | /api/admin/v1/client-versions* | system_clientVersion_add, system_clientVersion_edit, system_clientVersion_setLatest, system_clientVersion_forceUpdate, system_clientVersion_del | client_versions | desktop/app version publishing |
| `admin_front_ts` | `/system/cronTask` | `admin_front_ts/src/views/Main/system/cronTask/index.vue` | `crontask` | /api/admin/v1/cron-tasks* | devTools_cronTask_add/edit/del/status/logs | cron_task, cron_task_log | scheduler admin |
| `admin_front_ts` | `/system/exportTask` | `admin_front_ts/src/views/Main/system/exportTask/index.vue` | `export` | /api/admin/v1/export-tasks* | PAGE only / export actions through export API | export_tasks | async export task list/download |
| `admin_front_ts` | `/system/log` | `admin_front_ts/src/views/Main/system/log/index.vue` | `log/runtime` | /api/admin/v1/logs* | system_log_files, system_log_content | runtime log files, not DB-owned | Docker/runtime log viewer |
| `admin_front_ts` | `/system/mail` | `admin_front_ts/src/views/Main/system/mail/index.vue` | `mail` | /api/admin/v1/mail* | system_mail_configEdit/configDel/test/templateAdd/templateEdit/templateStatus/templateDel/logDel | mail_configs, mail_templates, mail_logs | mail config/templates/logs |
| `admin_front_ts` | `/system/notificationTask` | `admin_front_ts/src/views/Main/system/notificationTask/index.vue` | `notification/task` | /api/admin/v1/notification-tasks* | system_notificationTask_add, system_notificationTask_cancel, system_notificationTask_del | notification_task, notifications | scheduled/queued notifications |
| `admin_front_ts` | `/system/operationLog` | `admin_front_ts/src/views/Main/system/operationLog/index.vue` | `operationlog` | /api/admin/v1/operation-logs* | devTools_operationLog_del | operation_logs | audit log list/delete |
| `admin_front_ts` | `/system/queueMonitor` | `admin_front_ts/src/views/Main/system/queueMonitor/index.vue` | `queuemonitor` | /api/admin/v1/queue-monitor*, /queue-monitor-ui/*path | devTools_queueMonitor_list | Redis/Asynq runtime, no DB table owner | backend admin tooling endpoint; iframe/auth-cookie path |
| `admin_front_ts` | `/system/setting` | `admin_front_ts/src/views/Main/system/setting/index.vue` | `setting` | /api/admin/v1/system-settings* | system_setting_add/edit/del/status | system_settings | generic settings; avoid using it for values with owner configs |
| `admin_front_ts` | `/system/sms` | `admin_front_ts/src/views/Main/system/sms/index.vue` | `sms` | /api/admin/v1/sms* | system_sms_configEdit/configDel/test/templateAdd/templateEdit/templateStatus/templateDel/logDel | sms_configs, sms_templates, sms_logs | SMS config/templates/logs |
| `admin_front_ts` | `/system/uploadConfig` | `admin_front_ts/src/views/Main/system/uploadConfig/index.vue` | `uploadconfig` | /api/admin/v1/upload-drivers*, /upload-rules*, /upload-settings* | system_uploadConfig_driverAdd/Edit/Del, ruleAdd/Edit/Del, settingAdd/Edit/Del/Status | upload_drivers, upload_rules, upload_settings, system_settings.upload.token.ttl_minutes | upload config is runtime owner for upload token provider |
| `admin_front_ts` | `/user/userManager` | `admin_front_ts/src/views/Main/user/userManager/index.vue` | `user` | /api/admin/v1/users*, PATCH /users/:id/status | user_userManager_edit, user_userManager_del, user_userManager_kick, user_userManager_batchEdit, user_userManager_export | users, roles, user_auth_identities, login_logs | user list/status/session actions |
| `admin_front_ts` | `/user/usersLoginLog` | `admin_front_ts/src/views/Main/user/usersLoginLog/index.vue` | `user/loginlog` | /api/admin/v1/users/login-logs* | PAGE only in current live rows | login_logs, users | login audit list |
| `canvas_front_next` | `/login` | `canvas_front_next/src/app/(auth)/login/page.tsx` | `auth/canvas` | /api/canvas/v1/auth/login-config, /send-code, /login | public auth page; no PAGE permission required | auth_platforms, users, user_auth_identities, login_logs | login method comes from backend config |
| `canvas_front_next` | `/` | `canvas_front_next/src/app/(user)/page.tsx` | `canvas shell/user` | GET /api/canvas/v1/users/me, /settings | canvas_page + canvas_access | permissions, users, ai_agents | authenticated shell bootstrap |
| `canvas_front_next` | `/assets` | `canvas_front_next/src/app/(user)/assets/page.tsx` | `ai/asset` | GET/POST/DELETE /api/canvas/v1/assets* | canvas_assets_page, canvas_asset_read | ai_assets | current-user-owned assets; no public library |
| `canvas_front_next` | `/canvas` | `canvas_front_next/src/app/(user)/canvas/page.tsx` | `ai/chat, canvas` | /api/canvas/v1/ai/chat, /settings | canvas_page, canvas_access | ai_agents, ai_conversations, ai_messages, ai_runs | text/chat generation submits agent_id only |
| `canvas_front_next` | `/canvas/:id` | `canvas_front_next/src/app/(user)/canvas/[id]/page.tsx` | `ai/chat, canvas` | /api/canvas/v1/ai/chat, /settings, conversation detail state | canvas_page, canvas_access | ai_agents, ai_conversations, ai_messages, ai_runs | dynamic conversation canvas page; same provider/model guard as `/canvas` |
| `canvas_front_next` | `/image` | `canvas_front_next/src/app/(user)/image/page.tsx` | `ai/image` | /api/canvas/v1/ai/images*, /settings | canvas_image_page, canvas_ai_image_generate | ai_image_tasks, ai_image_files, ai_agents | free image generation; no billing debit |
| `canvas_front_next` | `/profile` | `canvas_front_next/src/app/(user)/profile/page.tsx` | `profile/canvas` | GET/PUT /api/canvas/v1/profile, logout via auth store | canvas_profile_page | users, user_auth_identities | profile transport does not own users/me bootstrap |
| `canvas_front_next` | `/prompts` | `canvas_front_next/src/app/(user)/prompts/page.tsx` | `ai/prompt` | GET /api/canvas/v1/prompts* | canvas_prompts_page, canvas_prompt_read | ai_prompts | Canvas prompt browsing; legacy canvas_prompts table retired |
| `canvas_front_next` | `/video` | `canvas_front_next/src/app/(user)/video/page.tsx` | `ai/video` | /api/canvas/v1/ai/videos*, /settings | canvas_video_page, canvas_ai_video_generate | canvas_video_tasks, ai_runs, ai_agents | video generation binds provider run on canvas_video_tasks.run_id |

## Guardrails

```text
Do not map a page to a table by name similarity alone; use live schema ownership and service/repository source.
Do not treat soft-deleted live permission rows as active UI just because source files still exist.
Do not reintroduce Canvas /asset-library or canvas_ai_text_generate; both are documented dead drift.
If a page source exists but no active permission row exists, mark it retained/source-present instead of inventing a permission.
```
