# Full-stack Module Map Snapshot

Generated at: 2026-06-09 19:25:05 +08:00

Backend route inventory: `docs/knowledge/backend-route-inventory-2026-06-08.md`
Frontend API inventory: `docs/knowledge/frontend-api-inventory-2026-06-08.md`
DB schema ownership map: `docs/knowledge/db-schema-ownership-map-2026-06-08.md`
API source-only route review: `docs/knowledge/api-source-only-route-review-2026-06-08.md`
Live schema artifact: `docs/db/mysql-live-schema-2026-06-08.md` / `docs/db/mysql-live-schema-2026-06-08.sql`

This artifact joins current source inventories into a module-level navigation map. It is not served-route smoke, not browser runtime proof, and not migration history. If a frontend exact backend API call cannot be joined to backend route inventory, this exporter fails instead of assigning a fallback owner.

## Summary

| Fact | Value |
| --- | --- |
| Backend route inventory artifact | `docs/knowledge/backend-route-inventory-2026-06-08.md` |
| Frontend API inventory artifact | `docs/knowledge/frontend-api-inventory-2026-06-08.md` |
| DB schema ownership artifact | `docs/knowledge/db-schema-ownership-map-2026-06-08.md` |
| API source-only review artifact | `docs/knowledge/api-source-only-route-review-2026-06-08.md` |
| Backend route registrations joined | `287` |
| Frontend exact backend API calls assigned | `266` |
| Unassigned frontend exact backend API calls | `0` |
| Live DB tables mapped | `55` |
| Live schema-only tables | `0` |
| Source-only routes reviewed | `19` |
| Owner-decision-required routes | `0` |
| Capabilities in joined map | `38` |

## Platform route and frontend-call summary

| Surface / workspace | Count |
| --- | ---: |
| backend surface `admin` routes | `246` |
| backend surface `app` routes | `9` |
| backend surface `callback` routes | `1` |
| backend surface `canvas` routes | `31` |
| frontend `admin_front_ts` exact backend calls | `240` |
| frontend `canvas_front_next` exact backend calls | `26` |

## Module map

| Capability | Backend surfaces / routes | Frontend exact backend calls | Live DB tables by model owner | Source-only review categories | Notes |
| --- | --- | --- | --- | --- | --- |
| `ai/agent` | `admin=10` | `admin_front_ts=10` | `ai_agents`, `ai_provider_models`, `ai_providers` |  |  |
| `ai/asset` | `canvas=4` | `canvas_front_next=4` | `ai_assets` |  |  |
| `ai/audio` | `canvas=1` | `canvas_front_next=1` |  |  | no live DB model-owner table |
| `ai/chat` | `canvas=1` | `canvas_front_next=1` | `ai_agents`, `ai_conversations`, `ai_messages`, `ai_providers`, `ai_run_events`, `ai_runs` |  |  |
| `ai/conversation` | `admin=5` | `admin_front_ts=5` | `ai_conversations` |  |  |
| `ai/image` | `canvas=5` | `canvas_front_next=6` | `ai_image_files`, `ai_image_tasks` |  |  |
| `ai/knowledge` | `admin=18` | `admin_front_ts=18` | `ai_agent_knowledge_bases`, `ai_knowledge_bases`, `ai_knowledge_chunks`, `ai_knowledge_documents`, `ai_knowledge_retrieval_hits`, `ai_knowledge_retrievals` |  |  |
| `ai/message` | `admin=3` | `admin_front_ts=3` | `ai_conversations`, `ai_messages` |  |  |
| `ai/prompt` | `admin=8`, `canvas=1` | `admin_front_ts=8`, `canvas_front_next=1` | `ai_prompts` |  |  |
| `ai/provider` | `admin=12` | `admin_front_ts=12` | `ai_provider_models`, `ai_providers` |  |  |
| `ai/run` | `admin=7` | `admin_front_ts=7` | `ai_run_events`, `ai_runs` |  |  |
| `ai/text` |  |  | `ai_text_tasks` |  | no backend route in current route inventory; no exact frontend backend call assigned |
| `ai/tool` | `admin=10` | `admin_front_ts=10` | `ai_agent_tools`, `ai_agents`, `ai_tool_calls`, `ai_tools` |  |  |
| `ai/video` | `canvas=3` | `canvas_front_next=3` | `canvas_video_tasks` |  |  |
| `auth` | `admin=14`, `app=5`, `canvas=6` | `admin_front_ts=15`, `canvas_front_next=6` | `roles`, `user_sessions`, `users`, `users_login_log` |  |  |
| `auth_platform` | `admin=7` | `admin_front_ts=7` | `auth_platforms` |  |  |
| `canvas` | `canvas=1` | `canvas_front_next=1` |  |  | no live DB model-owner table |
| `clientversion` | `admin=9` | `admin_front_ts=9` | `client_versions` |  |  |
| `crontask` | `admin=8` | `admin_front_ts=8` | `cron_task`, `cron_task_log` |  |  |
| `export` | `admin=4` | `admin_front_ts=4` | `export_tasks` |  |  |
| `mail` | `admin=14` | `admin_front_ts=18` | `mail_configs`, `mail_logs`, `mail_templates` |  |  |
| `notification` | `admin=13` | `admin_front_ts=14` | `notifications` |  |  |
| `notification/task` |  |  | `notification_task`, `notifications` |  | no backend route in current route inventory; no exact frontend backend call assigned |
| `operationlog` | `admin=4` | `admin_front_ts=4` | `operation_logs`, `users` |  |  |
| `payment` | `admin=13`, `callback=1`, `canvas=4` | `admin_front_ts=13` | `payment_callback_events`, `payment_configs`, `payment_orders`, `payment_recharge_packages`, `payment_recharges`, `user_wallets`, `wallet_transactions` | `retained-canvas-payment-wallet-domain=4` |  |
| `payment/wallet` | `admin=6`, `canvas=2` | `admin_front_ts=6` | `user_wallets`, `wallet_transactions` | `retained-canvas-payment-wallet-domain=2` |  |
| `permission` | `admin=7` | `admin_front_ts=7` | `permissions`, `role_permissions` |  |  |
| `profile` | `admin=5`, `app=2`, `canvas=2` | `admin_front_ts=5`, `canvas_front_next=2` |  |  | no live DB model-owner table |
| `queuemonitor` | `admin=4` | `admin_front_ts=1` |  | `admin-queue-monitor-endpoint=3` | no live DB model-owner table |
| `realtime` | `admin=1` |  |  | `runtime-system-endpoint=1` | no exact frontend backend call assigned; no live DB model-owner table |
| `role` | `admin=7` | `admin_front_ts=7` | `role_permissions`, `roles`, `users` |  |  |
| `sms` | `admin=14` | `admin_front_ts=15` | `sms_configs`, `sms_logs`, `sms_templates` |  |  |
| `system` | `admin=3` |  |  | `runtime-system-endpoint=3` | no exact frontend backend call assigned; no live DB model-owner table |
| `systemlog` | `admin=3` | `admin_front_ts=3` |  |  | no live DB model-owner table |
| `systemsetting` | `admin=7` | `admin_front_ts=7` | `system_settings` |  |  |
| `uploadconfig` | `admin=19` | `admin_front_ts=13` | `upload_driver`, `upload_rule`, `upload_setting` | `frontend-parametric-helper-covered=6` |  |
| `uploadtoken` | `admin=1`, `app=1` | `admin_front_ts=1` |  |  | no live DB model-owner table |
| `user` | `admin=10`, `app=1`, `canvas=1` | `admin_front_ts=10`, `canvas_front_next=1` | `address`, `roles`, `user_profiles`, `users` |  |  |

## Frontend join invariant

Every `admin-prefix` / `canvas-prefix` frontend call from the frontend API inventory must map to a backend route inventory row by method and normalized path parameters. This prevents hidden `unknown capability` fallback.

```text
exact frontend backend calls = 266
assigned frontend backend calls = 266
unassigned frontend backend calls = 0
```

## Verification command

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\export-full-stack-module-map.ps1 -OutputDate 2026-06-08
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1 -LiveSchema
```
