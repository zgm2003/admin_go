# AI Live Schema Snapshot (MySQL MCP)

Date: 2026-05-10
Truth source: MySQL MCP against `DATABASE() = admin`.

This file is the handoff snapshot for AI schema cleanup. Do not infer live AI tables from `admin.sql`; `admin.sql` was a stale legacy dump and its AI DDL was removed after MCP verification.

## Current live `ai_%` table count

16 tables.

## Current live tables and columns

| Table | Rows observed | Columns |
| --- | ---: | --- |
| `ai_agent_knowledge_bases` | 1 | `id`, `agent_id`, `knowledge_base_id`, `top_k`, `min_score`, `max_context_chars`, `status`, `is_del`, `created_at`, `updated_at` |
| `ai_agent_tools` | 2 | `id`, `agent_id`, `tool_id`, `status`, `created_at`, `updated_at` |
| `ai_agents` | 5 | `id`, `provider_id`, `name`, `model_id`, `model_display_name`, `scenes_json`, `system_prompt`, `avatar`, `status`, `is_del`, `created_at`, `updated_at` |
| `ai_conversations` | 0 | `id`, `user_id`, `agent_id`, `title`, `last_message_at`, `is_del`, `created_at`, `updated_at` |
| `ai_knowledge_bases` | 1 | `id`, `name`, `code`, `description`, `chunk_size_chars`, `chunk_overlap_chars`, `default_top_k`, `default_min_score`, `default_max_context_chars`, `status`, `is_del`, `created_at`, `updated_at` |
| `ai_knowledge_chunks` | 6 | `id`, `knowledge_base_id`, `document_id`, `chunk_index`, `title`, `content`, `content_chars`, `status`, `is_del`, `created_at`, `updated_at` |
| `ai_knowledge_documents` | 6 | `id`, `knowledge_base_id`, `title`, `source_type`, `source_ref`, `content`, `index_status`, `error_message`, `last_indexed_at`, `status`, `is_del`, `created_at`, `updated_at` |
| `ai_knowledge_retrieval_hits` | 12 | `id`, `retrieval_id`, `knowledge_base_id`, `knowledge_base_name`, `document_id`, `document_title`, `chunk_id`, `chunk_index`, `score`, `rank_no`, `content_snapshot`, `status`, `skip_reason`, `is_del`, `created_at`, `updated_at` |
| `ai_knowledge_retrievals` | 2 | `id`, `run_id`, `query`, `status`, `total_hits`, `selected_hits`, `duration_ms`, `error_message`, `is_del`, `created_at`, `updated_at` |
| `ai_messages` | 19 | `id`, `conversation_id`, `role`, `content_type`, `content`, `meta_json`, `is_del`, `created_at`, `updated_at` |
| `ai_provider_models` | 2 | `id`, `provider_id`, `model_id`, `display_name`, `status`, `created_at`, `updated_at` |
| `ai_providers` | 1 | `id`, `name`, `engine_type`, `base_url`, `api_key_enc`, `api_key_hint`, `health_status`, `last_checked_at`, `last_check_error`, `last_model_sync_at`, `last_model_sync_status`, `last_model_sync_error`, `status`, `is_del`, `created_at`, `updated_at` |
| `ai_run_events` | 8 | `id`, `run_id`, `seq`, `event_type`, `message`, `created_at` |
| `ai_runs` | 4 | `id`, `conversation_id`, `request_id`, `user_message_id`, `assistant_message_id`, `user_id`, `agent_id`, `provider_id`, `model_id`, `model_display_name`, `status`, `prompt_tokens`, `completion_tokens`, `total_tokens`, `duration_ms`, `error_message`, `started_at`, `finished_at`, `created_at`, `updated_at` |
| `ai_tool_calls` | 0 | `id`, `run_id`, `tool_id`, `tool_code`, `tool_name`, `call_id`, `status`, `arguments_json`, `result_json`, `error_message`, `duration_ms`, `started_at`, `finished_at`, `created_at`, `updated_at` |
| `ai_tools` | 1 | `id`, `name`, `code`, `description`, `parameters_json`, `result_schema_json`, `risk_level`, `timeout_ms`, `status`, `is_del`, `created_at`, `updated_at` |

## Retired tables verified absent by MySQL MCP

`ai_agent_scenes`, `ai_assistant_tools`, `ai_models`, `ai_prompt`, `ai_prompts`, `ai_run_steps`, `ai_usage_daily`, `ai_apps`, `ai_app_bindings`, `ai_knowledge_maps`, `ai_tool_maps`, `ai_engine_connections`.

## Stale permissions found by MySQL MCP before cleanup

These were active (`is_del = 2`) before the cleanup migration:

- `ai_knowledge_sync`
- `ai_knowledge_document_refresh`
- `ai_agent_binding_del`

They are not used by current route metadata or frontend guards. The cleanup migration is `admin_back_go/database/migrations/20260510_ai_prune_stale_permissions.sql`.
