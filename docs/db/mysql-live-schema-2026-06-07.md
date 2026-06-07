# MySQL Live Schema Snapshot

Verified at: 2026-06-08 06:10:27 +08:00

Truth source: live MySQL `DATABASE() = admin` on `127.0.0.1:3307`. Passwords and secrets are intentionally not recorded here.

This snapshot is generated from `information_schema`, per-table `COUNT(*)`, and `mysqldump --no-data`. Do not replace it with migration-file inference.

## Summary

| Item | Value |
| --- | --- |
| Database | `admin` |
| Base tables | 57 |
| Full DDL artifact | `docs/db/mysql-live-schema-2026-06-07.sql` |

## Table inventory

| Table | Rows checked by COUNT(*) | Engine | Collation | Comment |
| --- | ---: | --- | --- | --- |
| `address` | 3244 | InnoDB | utf8mb4_0900_ai_ci | 区域表 |
| `ai_agent_knowledge_bases` | 1 | InnoDB | utf8mb4_0900_ai_ci | AI智能体知识库绑定 |
| `ai_agent_tools` | 2 | InnoDB | utf8mb4_0900_ai_ci | AI智能体工具绑定 |
| `ai_agents` | 7 | InnoDB | utf8mb4_0900_ai_ci | AI agent mappings |
| `ai_assets` | 0 | InnoDB | utf8mb4_unicode_ci | AI素材库 |
| `ai_conversations` | 0 | InnoDB | utf8mb4_0900_ai_ci | AI会话 |
| `ai_image_files` | 2 | InnoDB | utf8mb4_unicode_ci |  |
| `ai_image_tasks` | 1 | InnoDB | utf8mb4_unicode_ci |  |
| `ai_knowledge_bases` | 1 | InnoDB | utf8mb4_0900_ai_ci | AI知识库 |
| `ai_knowledge_chunks` | 6 | InnoDB | utf8mb4_0900_ai_ci | AI知识库分块 |
| `ai_knowledge_documents` | 6 | InnoDB | utf8mb4_0900_ai_ci | AI知识库文档 |
| `ai_knowledge_retrieval_hits` | 0 | InnoDB | utf8mb4_0900_ai_ci | AI知识库检索命中 |
| `ai_knowledge_retrievals` | 0 | InnoDB | utf8mb4_0900_ai_ci | AI知识库检索记录 |
| `ai_messages` | 0 | InnoDB | utf8mb4_0900_ai_ci | AI消息 |
| `ai_prompts` | 1356 | InnoDB | utf8mb4_unicode_ci | AI提示词库 |
| `ai_provider_models` | 4 | InnoDB | utf8mb4_0900_ai_ci | AI provider enabled model catalog |
| `ai_providers` | 2 | InnoDB | utf8mb4_0900_ai_ci | AI engine connection configs |
| `ai_run_events` | 4 | InnoDB | utf8mb4_0900_ai_ci | AI运行监控事件 |
| `ai_runs` | 2 | InnoDB | utf8mb4_0900_ai_ci | AI运行监控记录 |
| `ai_text_tasks` | 0 | InnoDB | utf8mb4_0900_ai_ci | AI文本生成任务 |
| `ai_tool_calls` | 0 | InnoDB | utf8mb4_0900_ai_ci | AI工具调用记录 |
| `ai_tools` | 1 | InnoDB | utf8mb4_0900_ai_ci | AI工具定义 |
| `auth_platforms` | 3 | InnoDB | utf8mb4_0900_ai_ci | 认证平台管理 |
| `canvas_assets` | 0 | InnoDB | utf8mb4_unicode_ci | 无限画布素材公共库 |
| `canvas_prompts` | 1356 | InnoDB | utf8mb4_unicode_ci | 无限画布提示词公共库 |
| `canvas_video_tasks` | 0 | InnoDB | utf8mb4_unicode_ci | 无限画布视频生成任务 |
| `client_versions` | 8 | InnoDB | utf8mb4_0900_ai_ci | 客户端版本管理 |
| `cron_task` | 11 | InnoDB | utf8mb4_0900_ai_ci | 定时任务配置表 |
| `cron_task_log` | 94330 | InnoDB | utf8mb4_0900_ai_ci | 定时任务执行日志表 |
| `export_tasks` | 120 | InnoDB | utf8mb4_0900_ai_ci | 导出任务记录 |
| `mail_configs` | 1 | InnoDB | utf8mb4_0900_ai_ci |  |
| `mail_logs` | 6 | InnoDB | utf8mb4_0900_ai_ci |  |
| `mail_templates` | 4 | InnoDB | utf8mb4_0900_ai_ci |  |
| `notification_task` | 19 | InnoDB | utf8mb4_0900_ai_ci |  |
| `notifications` | 3085 | InnoDB | utf8mb4_0900_ai_ci | 用户通知表 |
| `operation_logs` | 2501 | InnoDB | utf8mb4_0900_ai_ci | 操作日志表 |
| `payment_callback_events` | 0 | InnoDB | utf8mb4_unicode_ci |  |
| `payment_configs` | 1 | InnoDB | utf8mb4_unicode_ci |  |
| `payment_orders` | 19 | InnoDB | utf8mb4_unicode_ci |  |
| `payment_recharge_packages` | 8 | InnoDB | utf8mb4_unicode_ci |  |
| `payment_recharges` | 19 | InnoDB | utf8mb4_unicode_ci |  |
| `permissions` | 341 | InnoDB | utf8mb4_0900_ai_ci | 菜单权限表 |
| `role_permissions` | 437 | InnoDB | utf8mb4_0900_ai_ci | role permission pivot |
| `roles` | 2 | InnoDB | utf8mb4_0900_ai_ci | 角色 |
| `sms_configs` | 1 | InnoDB | utf8mb4_0900_ai_ci |  |
| `sms_logs` | 0 | InnoDB | utf8mb4_0900_ai_ci |  |
| `sms_templates` | 0 | InnoDB | utf8mb4_0900_ai_ci |  |
| `system_settings` | 9 | InnoDB | utf8mb4_0900_ai_ci | 系统设置（key-value） |
| `upload_driver` | 53 | InnoDB | utf8mb4_0900_ai_ci |  |
| `upload_rule` | 53 | InnoDB | utf8mb4_0900_ai_ci |  |
| `upload_setting` | 55 | InnoDB | utf8mb4_0900_ai_ci | 上传设置：驱动+规则组合与启用状态 |
| `user_profiles` | 4 | InnoDB | utf8mb4_0900_ai_ci | 用户资料表 |
| `user_sessions` | 247 | InnoDB | utf8mb4_0900_ai_ci | 用户会话表 |
| `user_wallets` | 2 | InnoDB | utf8mb4_unicode_ci |  |
| `users` | 4 | InnoDB | utf8mb4_0900_ai_ci | 用户表 |
| `users_login_log` | 326 | InnoDB | utf8mb4_0900_ai_ci | 登录日志 |
| `wallet_transactions` | 3 | InnoDB | utf8mb4_unicode_ci |  |

## Foreign keys observed

| Table | Constraint | Column | References |
| --- | --- | --- | --- |
| `ai_agent_tools` | `fk_ai_agent_tools_agent` | `agent_id` | `ai_agents.id` |
| `ai_agent_tools` | `fk_ai_agent_tools_tool` | `tool_id` | `ai_tools.id` |
| `ai_messages` | `fk_ai_messages_conversation` | `conversation_id` | `ai_conversations.id` |
| `ai_run_events` | `fk_ai_run_events_run` | `run_id` | `ai_runs.id` |
| `ai_runs` | `fk_ai_runs_assistant_message` | `assistant_message_id` | `ai_messages.id` |
| `ai_runs` | `fk_ai_runs_conversation` | `conversation_id` | `ai_conversations.id` |
| `ai_runs` | `fk_ai_runs_user_message` | `user_message_id` | `ai_messages.id` |
| `ai_tool_calls` | `fk_ai_tool_calls_run` | `run_id` | `ai_runs.id` |
| `ai_tool_calls` | `fk_ai_tool_calls_tool` | `tool_id` | `ai_tools.id` |
| `payment_orders` | `fk_payment_order_config` | `config_id` | `payment_configs.id` |
| `payment_recharges` | `fk_payment_recharge_order` | `payment_order_id` | `payment_orders.id` |

## Columns by table

### `address`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `int unsigned` | NO | PRI | NULL | auto_increment | Region id |
| 2 | `parent_id` | `int unsigned` | NO | MUL | 0 |  | parent region id; 0 means root |
| 3 | `code` | `varchar(255)` | YES | UNI | NULL |  | 区划编码 |
| 4 | `name` | `varchar(255)` | YES |  | NULL |  | 区划名称 |
| 5 | `is_del` | `tinyint unsigned` | NO |  | 2 |  | soft delete: 1 deleted 2 normal |
| 6 | `created_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED | Created time |
| 7 | `updated_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED on update CURRENT_TIMESTAMP | Updated time |

Indexes:
- `idx_address_parent` (non-unique, BTREE): `parent_id`
- `PRIMARY` (unique, BTREE): `id`
- `uniq_address_code` (unique, BTREE): `code`

### `ai_agent_knowledge_bases`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `bigint unsigned` | NO | PRI | NULL | auto_increment | 绑定ID |
| 2 | `agent_id` | `bigint unsigned` | NO | MUL | NULL |  | ai_agents.id |
| 3 | `knowledge_base_id` | `bigint unsigned` | NO | MUL | NULL |  | ai_knowledge_bases.id |
| 4 | `top_k` | `int unsigned` | NO |  | 5 |  | 本智能体对此知识库召回条数 |
| 5 | `min_score` | `decimal(8,4)` | NO |  | 0.1000 |  | 本智能体对此知识库最低命中分 |
| 6 | `max_context_chars` | `int unsigned` | NO |  | 6000 |  | 本智能体对此知识库最大注入字符数 |
| 7 | `status` | `tinyint unsigned` | NO |  | 1 |  | 1启用 2禁用；运行时只加载启用绑定 |
| 8 | `is_del` | `tinyint unsigned` | NO |  | 2 |  | 1删除 2正常 |
| 9 | `created_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED | 创建时间 |
| 10 | `updated_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED on update CURRENT_TIMESTAMP | 更新时间 |

Indexes:
- `idx_ai_agent_knowledge_agent` (non-unique, BTREE): `agent_id`, `status`, `is_del`
- `idx_ai_agent_knowledge_base` (non-unique, BTREE): `knowledge_base_id`, `status`, `is_del`
- `PRIMARY` (unique, BTREE): `id`
- `uk_ai_agent_knowledge_base` (unique, BTREE): `agent_id`, `knowledge_base_id`, `is_del`

### `ai_agent_tools`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `bigint unsigned` | NO | PRI | NULL | auto_increment | 绑定ID |
| 2 | `agent_id` | `bigint unsigned` | NO | MUL | NULL |  | ai_agents.id |
| 3 | `tool_id` | `bigint unsigned` | NO | MUL | NULL |  | ai_tools.id |
| 4 | `status` | `tinyint unsigned` | NO |  | 1 |  | 1启用 2禁用；运行时只加载启用绑定 |
| 5 | `created_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED | 创建时间 |
| 6 | `updated_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED on update CURRENT_TIMESTAMP | 更新时间 |

Indexes:
- `idx_ai_agent_tools_agent_status` (non-unique, BTREE): `agent_id`, `status`, `id`
- `idx_ai_agent_tools_tool_status` (non-unique, BTREE): `tool_id`, `status`, `id`
- `PRIMARY` (unique, BTREE): `id`
- `uk_ai_agent_tools_agent_tool` (unique, BTREE): `agent_id`, `tool_id`

### `ai_agents`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `bigint unsigned` | NO | PRI | NULL | auto_increment |  |
| 2 | `provider_id` | `bigint unsigned` | NO | MUL | NULL |  |  |
| 3 | `name` | `varchar(128)` | NO |  | NULL |  |  |
| 4 | `model_id` | `varchar(191)` | NO |  |  |  |  |
| 5 | `model_display_name` | `varchar(191)` | NO |  |  |  |  |
| 6 | `scenes_json` | `json` | YES |  | NULL |  |  |
| 7 | `system_prompt` | `text` | YES |  | NULL |  |  |
| 8 | `avatar` | `varchar(512)` | NO |  |  |  |  |
| 9 | `status` | `tinyint unsigned` | NO |  | 1 |  |  |
| 10 | `is_del` | `tinyint unsigned` | NO |  | 2 |  |  |
| 11 | `created_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED |  |
| 12 | `updated_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED on update CURRENT_TIMESTAMP |  |

Indexes:
- `idx_ai_agents_model` (non-unique, BTREE): `provider_id`, `model_id`, `status`, `is_del`
- `idx_ai_agents_provider` (non-unique, BTREE): `provider_id`, `status`, `is_del`
- `PRIMARY` (unique, BTREE): `id`

### `ai_assets`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `bigint unsigned` | NO | PRI | NULL | auto_increment |  |
| 2 | `slug` | `varchar(191)` | NO | UNI | NULL |  |  |
| 3 | `type` | `varchar(16)` | NO | MUL | NULL |  |  |
| 4 | `category` | `varchar(191)` | NO |  |  |  |  |
| 5 | `title` | `varchar(191)` | NO |  | NULL |  |  |
| 6 | `cover_url` | `varchar(1024)` | NO |  |  |  |  |
| 7 | `description` | `varchar(512)` | NO |  |  |  |  |
| 8 | `content` | `text` | YES |  | NULL |  |  |
| 9 | `url` | `varchar(1024)` | NO |  |  |  |  |
| 10 | `tags_json` | `json` | YES |  | NULL |  |  |
| 11 | `status` | `tinyint` | NO | MUL | 1 |  |  |
| 12 | `is_del` | `tinyint` | NO |  | 2 |  |  |
| 13 | `created_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED |  |
| 14 | `updated_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED on update CURRENT_TIMESTAMP |  |

Indexes:
- `idx_ai_assets_status_updated` (non-unique, BTREE): `status`, `is_del`, `updated_at`, `id`
- `idx_ai_assets_type_status` (non-unique, BTREE): `type`, `status`, `is_del`, `updated_at`, `id`
- `PRIMARY` (unique, BTREE): `id`
- `uk_ai_assets_slug` (unique, BTREE): `slug`

### `ai_conversations`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `int unsigned` | NO | PRI | NULL | auto_increment | 会话ID |
| 2 | `user_id` | `int unsigned` | NO | MUL | NULL |  | 当前用户ID |
| 3 | `agent_id` | `int unsigned` | NO |  | NULL |  | ai_agents.id |
| 4 | `title` | `varchar(100)` | NO |  |  |  | 会话标题 |
| 5 | `last_message_at` | `datetime` | YES |  | NULL |  | 上次对话时间 |
| 6 | `is_del` | `tinyint unsigned` | NO |  | 2 |  | 1删除 2正常 |
| 7 | `created_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED | 创建时间 |
| 8 | `updated_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED on update CURRENT_TIMESTAMP | 更新时间 |

Indexes:
- `idx_ai_conversations_user_agent_del_last_message` (non-unique, BTREE): `user_id`, `agent_id`, `is_del`, `last_message_at`, `id`
- `PRIMARY` (unique, BTREE): `id`

### `ai_image_files`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `bigint unsigned` | NO | PRI | NULL | auto_increment |  |
| 2 | `task_id` | `bigint unsigned` | NO | MUL | NULL |  |  |
| 3 | `role` | `varchar(16)` | NO |  | NULL |  | input/mask/output |
| 4 | `sort_order` | `int` | NO |  | 0 |  |  |
| 5 | `storage_provider` | `varchar(32)` | NO |  |  |  |  |
| 6 | `storage_key` | `varchar(512)` | NO |  |  |  |  |
| 7 | `storage_url` | `varchar(1000)` | NO |  |  |  |  |
| 8 | `mime_type` | `varchar(64)` | NO |  |  |  |  |
| 9 | `width` | `int` | NO |  | 0 |  |  |
| 10 | `height` | `int` | NO |  | 0 |  |  |
| 11 | `size_bytes` | `bigint` | NO |  | 0 |  |  |
| 12 | `related_file_id` | `bigint unsigned` | YES | MUL | NULL |  |  |
| 13 | `revised_prompt` | `text` | YES |  | NULL |  |  |
| 14 | `created_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED |  |

Indexes:
- `idx_ai_image_files_related` (non-unique, BTREE): `related_file_id`
- `idx_ai_image_files_task_role_sort` (non-unique, BTREE): `task_id`, `role`, `sort_order`
- `PRIMARY` (unique, BTREE): `id`

### `ai_image_tasks`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `bigint unsigned` | NO | PRI | NULL | auto_increment |  |
| 2 | `platform` | `varchar(32)` | NO | MUL | NULL |  |  |
| 3 | `user_id` | `bigint unsigned` | NO |  | NULL |  |  |
| 4 | `agent_id` | `bigint unsigned` | NO | MUL | NULL |  |  |
| 5 | `agent_name_snapshot` | `varchar(128)` | NO |  |  |  |  |
| 6 | `provider_id_snapshot` | `bigint unsigned` | NO |  | 0 |  |  |
| 7 | `provider_name_snapshot` | `varchar(128)` | NO |  |  |  |  |
| 8 | `model_id_snapshot` | `varchar(128)` | NO |  |  |  |  |
| 9 | `model_display_name_snapshot` | `varchar(128)` | NO |  |  |  |  |
| 10 | `prompt` | `text` | NO |  | NULL |  |  |
| 11 | `size` | `varchar(32)` | NO |  | 1024x1024 |  |  |
| 12 | `quality` | `varchar(16)` | NO |  | auto |  |  |
| 13 | `output_format` | `varchar(16)` | NO |  | png |  |  |
| 14 | `output_compression` | `int` | YES |  | NULL |  |  |
| 15 | `moderation` | `varchar(16)` | NO |  | auto |  |  |
| 16 | `n` | `int` | NO |  | 1 |  |  |
| 17 | `status` | `varchar(16)` | NO |  | pending |  |  |
| 18 | `error_message` | `varchar(1000)` | NO |  |  |  |  |
| 19 | `actual_params_json` | `json` | YES |  | NULL |  |  |
| 20 | `raw_response_json` | `json` | YES |  | NULL |  |  |
| 21 | `is_favorite` | `tinyint` | NO |  | 2 |  |  |
| 22 | `finished_at` | `datetime` | YES |  | NULL |  |  |
| 23 | `elapsed_ms` | `int` | NO |  | 0 |  |  |
| 24 | `created_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED |  |
| 25 | `updated_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED on update CURRENT_TIMESTAMP |  |

Indexes:
- `idx_ai_image_tasks_agent_created` (non-unique, BTREE): `agent_id`, `created_at`
- `idx_ai_image_tasks_platform_status_created` (non-unique, BTREE): `platform`, `status`, `created_at`
- `idx_ai_image_tasks_platform_user_created` (non-unique, BTREE): `platform`, `user_id`, `created_at`
- `PRIMARY` (unique, BTREE): `id`

### `ai_knowledge_bases`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `bigint unsigned` | NO | PRI | NULL | auto_increment | 知识库ID |
| 2 | `name` | `varchar(128)` | NO |  | NULL |  | 知识库名称，列表、绑定、监控展示 |
| 3 | `code` | `varchar(128)` | NO | MUL | NULL |  | 知识库唯一编码，用于种子幂等和人工识别 |
| 4 | `description` | `varchar(1024)` | NO |  |  |  | 知识库说明，管理页展示和智能体绑定时辅助选择 |
| 5 | `chunk_size_chars` | `int unsigned` | NO |  | 1200 |  | 默认分块字符数，重建文档分块时使用 |
| 6 | `chunk_overlap_chars` | `int unsigned` | NO |  | 120 |  | 默认分块重叠字符数，重建文档分块时使用 |
| 7 | `default_top_k` | `int unsigned` | NO |  | 5 |  | 检索测试和智能体绑定默认召回条数 |
| 8 | `default_min_score` | `decimal(8,4)` | NO |  | 0.1000 |  | 检索测试和智能体绑定默认最低分 |
| 9 | `default_max_context_chars` | `int unsigned` | NO |  | 6000 |  | 检索测试和智能体绑定默认上下文字符预算 |
| 10 | `status` | `tinyint unsigned` | NO | MUL | 1 |  | 1启用 2禁用；运行时只读取启用知识库 |
| 11 | `is_del` | `tinyint unsigned` | NO |  | 2 |  | 1删除 2正常；所有查询默认 is_del=2 |
| 12 | `created_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED | 创建时间 |
| 13 | `updated_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED on update CURRENT_TIMESTAMP | 更新时间 |

Indexes:
- `idx_ai_knowledge_bases_status` (non-unique, BTREE): `status`, `is_del`, `updated_at`
- `PRIMARY` (unique, BTREE): `id`
- `uk_ai_knowledge_bases_code` (unique, BTREE): `code`, `is_del`

### `ai_knowledge_chunks`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `bigint unsigned` | NO | PRI | NULL | auto_increment | 分块ID |
| 2 | `knowledge_base_id` | `bigint unsigned` | NO | MUL | NULL |  | ai_knowledge_bases.id，检索时直接过滤 |
| 3 | `document_id` | `bigint unsigned` | NO | MUL | NULL |  | ai_knowledge_documents.id |
| 4 | `chunk_index` | `int unsigned` | NO |  | NULL |  | 同一文档内分块序号，从1开始 |
| 5 | `title` | `varchar(191)` | NO |  |  |  | 分块标题，默认继承文档标题 |
| 6 | `content` | `text` | NO |  | NULL |  | 分块内容，检索和上下文注入使用 |
| 7 | `content_chars` | `int unsigned` | NO |  | 0 |  | 分块字符数，用于 max_context_chars 预算 |
| 8 | `status` | `tinyint unsigned` | NO |  | 1 |  | 1启用 2禁用；运行时只读取启用分块 |
| 9 | `is_del` | `tinyint unsigned` | NO |  | 2 |  | 1删除 2正常 |
| 10 | `created_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED | 创建时间 |
| 11 | `updated_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED on update CURRENT_TIMESTAMP | 更新时间 |

Indexes:
- `idx_ai_knowledge_chunks_base` (non-unique, BTREE): `knowledge_base_id`, `status`, `is_del`, `id`
- `idx_ai_knowledge_chunks_document` (non-unique, BTREE): `document_id`, `status`, `is_del`
- `PRIMARY` (unique, BTREE): `id`
- `uk_ai_knowledge_chunks_doc_index` (unique, BTREE): `document_id`, `chunk_index`, `is_del`

### `ai_knowledge_documents`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `bigint unsigned` | NO | PRI | NULL | auto_increment | 文档ID |
| 2 | `knowledge_base_id` | `bigint unsigned` | NO | MUL | NULL |  | ai_knowledge_bases.id |
| 3 | `title` | `varchar(191)` | NO |  | NULL |  | 文档标题，列表、分块、监控展示 |
| 4 | `source_type` | `varchar(32)` | NO |  | text |  | 来源类型：text/markdown/file；第一版写 text/markdown |
| 5 | `source_ref` | `varchar(512)` | NO |  |  |  | 来源标识，如 docs/architecture/04-go-backend-framework.md 或上传文件URL；与 knowledge_base_id、is_del 组成同来源幂等唯一键 |
| 6 | `content` | `longtext` | NO |  | NULL |  | 文档原文，编辑和重建分块使用 |
| 7 | `index_status` | `varchar(16)` | NO | MUL | pending |  | pending/indexing/indexed/failed；分块状态展示和运行过滤 |
| 8 | `error_message` | `varchar(1024)` | NO |  |  |  | 分块失败原因，管理页展示 |
| 9 | `last_indexed_at` | `datetime` | YES |  | NULL |  | 最近成功重建分块时间 |
| 10 | `status` | `tinyint unsigned` | NO |  | 1 |  | 1启用 2禁用；运行时只读取启用文档 |
| 11 | `is_del` | `tinyint unsigned` | NO |  | 2 |  | 1删除 2正常 |
| 12 | `created_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED | 创建时间 |
| 13 | `updated_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED on update CURRENT_TIMESTAMP | 更新时间 |

Indexes:
- `idx_ai_knowledge_documents_base` (non-unique, BTREE): `knowledge_base_id`, `status`, `is_del`, `updated_at`
- `idx_ai_knowledge_documents_index` (non-unique, BTREE): `index_status`, `is_del`
- `PRIMARY` (unique, BTREE): `id`
- `uk_ai_knowledge_documents_source` (unique, BTREE): `knowledge_base_id`, `source_ref`, `is_del`

### `ai_knowledge_retrieval_hits`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `bigint unsigned` | NO | PRI | NULL | auto_increment | 命中ID |
| 2 | `retrieval_id` | `bigint unsigned` | NO | MUL | NULL |  | ai_knowledge_retrievals.id |
| 3 | `knowledge_base_id` | `bigint unsigned` | NO |  | NULL |  | 命中知识库ID |
| 4 | `knowledge_base_name` | `varchar(128)` | NO |  | NULL |  | 命中时知识库名称快照 |
| 5 | `document_id` | `bigint unsigned` | NO |  | NULL |  | 命中文档ID |
| 6 | `document_title` | `varchar(191)` | NO |  | NULL |  | 命中时文档标题快照 |
| 7 | `chunk_id` | `bigint unsigned` | NO | MUL | NULL |  | 命中分块ID |
| 8 | `chunk_index` | `int unsigned` | NO |  | NULL |  | 命中分块序号快照 |
| 9 | `score` | `decimal(10,6)` | NO |  | 0.000000 |  | 检索评分 |
| 10 | `rank_no` | `int unsigned` | NO |  | NULL |  | 本次检索排序，从1开始 |
| 11 | `content_snapshot` | `text` | NO |  | NULL |  | 命中内容快照，运行监控和问题复盘使用 |
| 12 | `status` | `tinyint unsigned` | NO |  | 1 |  | 1进入上下文 2跳过 |
| 13 | `skip_reason` | `varchar(64)` | NO |  |  |  | 跳过原因：low_score/context_limit |
| 14 | `is_del` | `tinyint unsigned` | NO |  | 2 |  | 1删除 2正常 |
| 15 | `created_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED | 创建时间 |
| 16 | `updated_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED on update CURRENT_TIMESTAMP | 更新时间 |

Indexes:
- `idx_ai_knowledge_hits_chunk` (non-unique, BTREE): `chunk_id`, `is_del`
- `idx_ai_knowledge_hits_retrieval` (non-unique, BTREE): `retrieval_id`, `status`, `rank_no`
- `PRIMARY` (unique, BTREE): `id`

### `ai_knowledge_retrievals`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `bigint unsigned` | NO | PRI | NULL | auto_increment | 检索ID |
| 2 | `run_id` | `bigint unsigned` | NO | MUL | NULL |  | ai_runs.id |
| 3 | `query` | `text` | NO |  | NULL |  | 本轮检索查询文本，通常为用户消息正文 |
| 4 | `status` | `varchar(16)` | NO | MUL | NULL |  | success/failed/skipped |
| 5 | `total_hits` | `int unsigned` | NO |  | 0 |  | 原始命中数量 |
| 6 | `selected_hits` | `int unsigned` | NO |  | 0 |  | 进入上下文的命中数量 |
| 7 | `duration_ms` | `int unsigned` | YES |  | NULL |  | 检索耗时毫秒 |
| 8 | `error_message` | `varchar(1024)` | NO |  |  |  | 失败原因 |
| 9 | `is_del` | `tinyint unsigned` | NO |  | 2 |  | 1删除 2正常；运行监控默认只读正常记录 |
| 10 | `created_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED | 创建时间 |
| 11 | `updated_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED on update CURRENT_TIMESTAMP | 更新时间 |

Indexes:
- `idx_ai_knowledge_retrievals_run` (non-unique, BTREE): `run_id`, `is_del`, `created_at`
- `idx_ai_knowledge_retrievals_status` (non-unique, BTREE): `status`, `is_del`, `created_at`
- `PRIMARY` (unique, BTREE): `id`

### `ai_messages`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `bigint unsigned` | NO | PRI | NULL | auto_increment | 消息ID |
| 2 | `conversation_id` | `int unsigned` | NO | MUL | NULL |  | ai_conversations.id |
| 3 | `role` | `tinyint unsigned` | NO |  | NULL |  | 1用户 2助手 |
| 4 | `content_type` | `varchar(32)` | NO |  | text |  | 内容类型，MVP只写text |
| 5 | `content` | `longtext` | NO |  | NULL |  | 消息内容 |
| 6 | `meta_json` | `json` | YES |  | NULL |  | 消息扩展元数据：attachments/runtime_params/blocks/feedback |
| 7 | `is_del` | `tinyint unsigned` | NO |  | 2 |  | 1删除 2正常 |
| 8 | `created_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED | 创建时间 |
| 9 | `updated_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED on update CURRENT_TIMESTAMP | 更新时间 |

Indexes:
- `idx_ai_messages_conversation_del_id` (non-unique, BTREE): `conversation_id`, `is_del`, `id`
- `PRIMARY` (unique, BTREE): `id`

### `ai_prompts`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `bigint unsigned` | NO | PRI | NULL | auto_increment |  |
| 2 | `slug` | `varchar(191)` | NO | UNI | NULL |  |  |
| 3 | `category` | `varchar(191)` | NO | MUL |  |  |  |
| 4 | `title` | `varchar(191)` | NO |  | NULL |  |  |
| 5 | `cover_url` | `varchar(1024)` | NO |  |  |  |  |
| 6 | `prompt` | `text` | NO |  | NULL |  |  |
| 7 | `preview` | `varchar(512)` | NO |  |  |  |  |
| 8 | `tags_json` | `json` | YES |  | NULL |  |  |
| 9 | `source_url` | `varchar(1024)` | NO |  |  |  |  |
| 10 | `status` | `tinyint` | NO | MUL | 1 |  |  |
| 11 | `is_del` | `tinyint` | NO |  | 2 |  |  |
| 12 | `created_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED |  |
| 13 | `updated_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED on update CURRENT_TIMESTAMP |  |

Indexes:
- `idx_ai_prompts_category_status` (non-unique, BTREE): `category`, `status`, `is_del`, `updated_at`, `id`
- `idx_ai_prompts_status_updated` (non-unique, BTREE): `status`, `is_del`, `updated_at`, `id`
- `PRIMARY` (unique, BTREE): `id`
- `uk_ai_prompts_slug` (unique, BTREE): `slug`

### `ai_provider_models`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `bigint unsigned` | NO | PRI | NULL | auto_increment |  |
| 2 | `provider_id` | `bigint unsigned` | NO | MUL | NULL |  |  |
| 3 | `model_id` | `varchar(191)` | NO |  | NULL |  |  |
| 4 | `display_name` | `varchar(191)` | NO |  |  |  |  |
| 5 | `status` | `tinyint unsigned` | NO |  | 1 |  |  |
| 6 | `created_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED |  |
| 7 | `updated_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED on update CURRENT_TIMESTAMP |  |

Indexes:
- `idx_ai_provider_models_provider_status` (non-unique, BTREE): `provider_id`, `status`
- `PRIMARY` (unique, BTREE): `id`
- `uk_ai_provider_models_provider_model` (unique, BTREE): `provider_id`, `model_id`

### `ai_providers`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `bigint unsigned` | NO | PRI | NULL | auto_increment |  |
| 2 | `name` | `varchar(128)` | NO |  | NULL |  |  |
| 3 | `engine_type` | `varchar(32)` | NO | MUL | NULL |  |  |
| 4 | `base_url` | `varchar(512)` | NO |  |  |  |  |
| 5 | `api_key_enc` | `text` | YES |  | NULL |  |  |
| 6 | `api_key_hint` | `varchar(32)` | NO |  |  |  |  |
| 7 | `health_status` | `varchar(32)` | NO |  | unknown |  |  |
| 8 | `last_checked_at` | `datetime` | YES |  | NULL |  |  |
| 9 | `last_check_error` | `varchar(1024)` | NO |  |  |  |  |
| 10 | `last_model_sync_at` | `datetime` | YES |  | NULL |  |  |
| 11 | `last_model_sync_status` | `varchar(32)` | NO |  | unknown |  |  |
| 12 | `last_model_sync_error` | `varchar(1024)` | NO |  |  |  |  |
| 13 | `status` | `tinyint unsigned` | NO | MUL | 1 |  |  |
| 14 | `is_del` | `tinyint unsigned` | NO |  | 2 |  |  |
| 15 | `created_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED |  |
| 16 | `updated_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED on update CURRENT_TIMESTAMP |  |

Indexes:
- `idx_ai_providers_status` (non-unique, BTREE): `status`, `is_del`
- `PRIMARY` (unique, BTREE): `id`
- `uk_ai_providers_type_name` (unique, BTREE): `engine_type`, `name`, `is_del`

### `ai_run_events`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `bigint unsigned` | NO | PRI | NULL | auto_increment | 事件ID |
| 2 | `run_id` | `bigint unsigned` | NO | MUL | NULL |  | ai_runs.id |
| 3 | `seq` | `int unsigned` | NO |  | NULL |  | 同一run内事件序号 |
| 4 | `event_type` | `varchar(32)` | NO | MUL | NULL |  | start/completed/failed/canceled/timeout |
| 5 | `message` | `varchar(1024)` | NO |  |  |  | 事件说明或错误原因 |
| 6 | `created_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED | 事件时间 |

Indexes:
- `idx_ai_run_events_run_id` (non-unique, BTREE): `run_id`, `id`
- `idx_ai_run_events_type_created` (non-unique, BTREE): `event_type`, `created_at`, `id`
- `PRIMARY` (unique, BTREE): `id`
- `uk_ai_run_events_run_seq` (unique, BTREE): `run_id`, `seq`

### `ai_runs`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `bigint unsigned` | NO | PRI | NULL | auto_increment | 运行ID |
| 2 | `platform` | `varchar(32)` | NO | MUL | NULL |  |  |
| 3 | `modality` | `varchar(32)` | NO |  | NULL |  |  |
| 4 | `source_type` | `varchar(64)` | NO | MUL | NULL |  |  |
| 5 | `source_id` | `bigint unsigned` | NO |  | NULL |  |  |
| 6 | `conversation_id` | `int unsigned` | YES | MUL | NULL |  | ai_conversations.id; chat rows only |
| 7 | `request_id` | `varchar(64)` | NO |  | NULL |  | 客户端本轮请求ID |
| 8 | `user_message_id` | `bigint unsigned` | YES | UNI | NULL |  | 本轮用户消息ID; chat rows only |
| 9 | `assistant_message_id` | `bigint unsigned` | YES | MUL | NULL |  | 完成后写入的助手消息ID; chat rows only |
| 10 | `user_id` | `int unsigned` | NO | MUL | NULL |  | 发起用户ID |
| 11 | `agent_id` | `bigint unsigned` | NO | MUL | NULL |  | ai_agents.id |
| 12 | `provider_id` | `bigint unsigned` | NO | MUL | NULL |  | ai_providers.id |
| 13 | `model_id` | `varchar(191)` | NO |  | NULL |  | 实际调用模型ID |
| 14 | `model_display_name` | `varchar(191)` | NO |  |  |  | 实际调用模型展示名 |
| 15 | `input_snapshot` | `mediumtext` | NO |  | NULL |  |  |
| 16 | `status` | `varchar(16)` | NO | MUL | NULL |  | queued/running/success/failed/canceled/timeout |
| 17 | `prompt_tokens` | `int unsigned` | NO |  | 0 |  | 输入token |
| 18 | `completion_tokens` | `int unsigned` | NO |  | 0 |  | 输出token |
| 19 | `total_tokens` | `int unsigned` | NO |  | 0 |  | 总token |
| 20 | `usage_status` | `varchar(16)` | NO |  | NULL |  |  |
| 21 | `duration_ms` | `int unsigned` | YES |  | NULL |  | 运行耗时毫秒，终态后写入 |
| 22 | `error_message` | `varchar(1024)` | NO |  |  |  | 失败/取消/超时原因 |
| 23 | `started_at` | `datetime` | YES |  | NULL |  | 开始调用模型时间 |
| 24 | `finished_at` | `datetime` | YES |  | NULL |  | 进入终态时间 |
| 25 | `created_at` | `datetime` | NO | MUL | CURRENT_TIMESTAMP | DEFAULT_GENERATED | 创建时间 |
| 26 | `updated_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED on update CURRENT_TIMESTAMP | 更新时间 |

Indexes:
- `fk_ai_runs_assistant_message` (non-unique, BTREE): `assistant_message_id`
- `idx_ai_runs_agent_created` (non-unique, BTREE): `agent_id`, `created_at`, `id`
- `idx_ai_runs_conversation_created` (non-unique, BTREE): `conversation_id`, `created_at`, `id`
- `idx_ai_runs_created` (non-unique, BTREE): `created_at`, `id`
- `idx_ai_runs_platform_modality_created` (non-unique, BTREE): `platform`, `modality`, `created_at`, `id`
- `idx_ai_runs_provider_created` (non-unique, BTREE): `provider_id`, `created_at`, `id`
- `idx_ai_runs_source` (non-unique, BTREE): `source_type`, `source_id`, `created_at`, `id`
- `idx_ai_runs_status_created` (non-unique, BTREE): `status`, `created_at`, `id`
- `idx_ai_runs_user_created` (non-unique, BTREE): `user_id`, `created_at`, `id`
- `PRIMARY` (unique, BTREE): `id`
- `uk_ai_runs_conversation_request` (unique, BTREE): `conversation_id`, `request_id`
- `uk_ai_runs_source_request` (unique, BTREE): `source_type`, `source_id`, `request_id`
- `uk_ai_runs_user_message` (unique, BTREE): `user_message_id`

### `ai_text_tasks`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `bigint unsigned` | NO | PRI | NULL | auto_increment |  |
| 2 | `platform` | `varchar(32)` | NO |  | NULL |  |  |
| 3 | `user_id` | `bigint unsigned` | NO | MUL | NULL |  |  |
| 4 | `agent_id` | `bigint unsigned` | NO |  | NULL |  |  |
| 5 | `provider_id` | `bigint unsigned` | NO |  | NULL |  |  |
| 6 | `model_id` | `varchar(191)` | NO |  | NULL |  |  |
| 7 | `prompt` | `mediumtext` | NO |  | NULL |  |  |
| 8 | `answer` | `mediumtext` | YES |  | NULL |  |  |
| 9 | `status` | `varchar(16)` | NO | MUL | NULL |  |  |
| 10 | `error_message` | `varchar(1024)` | YES |  | NULL |  |  |
| 11 | `started_at` | `datetime` | YES |  | NULL |  |  |
| 12 | `finished_at` | `datetime` | YES |  | NULL |  |  |
| 13 | `elapsed_ms` | `int unsigned` | NO |  | NULL |  |  |
| 14 | `created_at` | `datetime` | NO |  | NULL |  |  |
| 15 | `updated_at` | `datetime` | NO |  | NULL |  |  |

Indexes:
- `idx_ai_text_tasks_status_created` (non-unique, BTREE): `status`, `created_at`, `id`
- `idx_ai_text_tasks_user_created` (non-unique, BTREE): `user_id`, `created_at`, `id`
- `PRIMARY` (unique, BTREE): `id`

### `ai_tool_calls`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `bigint unsigned` | NO | PRI | NULL | auto_increment | 工具调用ID |
| 2 | `run_id` | `bigint unsigned` | NO | MUL | NULL |  | ai_runs.id |
| 3 | `tool_id` | `bigint unsigned` | NO | MUL | NULL |  | ai_tools.id |
| 4 | `tool_code` | `varchar(128)` | NO |  | NULL |  | 调用时工具编码快照 |
| 5 | `tool_name` | `varchar(128)` | NO |  | NULL |  | 调用时工具名称快照 |
| 6 | `call_id` | `varchar(128)` | YES |  | NULL |  | 模型返回的tool_call_id/call_id，用于回传工具结果 |
| 7 | `status` | `varchar(16)` | NO | MUL | NULL |  | running/success/failed/timeout |
| 8 | `arguments_json` | `json` | NO |  | NULL |  | 模型传入参数 |
| 9 | `result_json` | `json` | YES |  | NULL |  | 工具返回结果 |
| 10 | `error_message` | `varchar(1024)` | NO |  |  |  | 失败或超时原因 |
| 11 | `duration_ms` | `int unsigned` | YES |  | NULL |  | 执行耗时毫秒，终态后写入 |
| 12 | `started_at` | `datetime` | NO |  | NULL |  | 开始执行时间 |
| 13 | `finished_at` | `datetime` | YES |  | NULL |  | 结束时间 |
| 14 | `created_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED | 创建时间 |
| 15 | `updated_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED on update CURRENT_TIMESTAMP | 更新时间 |

Indexes:
- `idx_ai_tool_calls_run_id` (non-unique, BTREE): `run_id`, `id`
- `idx_ai_tool_calls_status_created` (non-unique, BTREE): `status`, `created_at`, `id`
- `idx_ai_tool_calls_tool_created` (non-unique, BTREE): `tool_id`, `created_at`, `id`
- `PRIMARY` (unique, BTREE): `id`
- `uk_ai_tool_calls_run_call` (unique, BTREE): `run_id`, `call_id`

### `ai_tools`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `bigint unsigned` | NO | PRI | NULL | auto_increment | 工具ID |
| 2 | `name` | `varchar(128)` | NO |  | NULL |  | 工具名称，管理页和运行监控展示 |
| 3 | `code` | `varchar(128)` | NO | UNI | NULL |  | 工具唯一编码，传给模型作为function name |
| 4 | `description` | `varchar(1024)` | NO |  |  |  | 工具说明，传给模型作为function description |
| 5 | `parameters_json` | `json` | NO |  | NULL |  | 工具参数JSON Schema，传给模型并用于入参校验 |
| 6 | `result_schema_json` | `json` | NO |  | NULL |  | 工具返回JSON Schema，用于结果校验和运行监控展示 |
| 7 | `risk_level` | `varchar(16)` | NO |  | NULL |  | 风险等级：low/medium/high |
| 8 | `timeout_ms` | `int unsigned` | NO |  | 3000 |  | 执行超时毫秒，运行时context timeout |
| 9 | `status` | `tinyint unsigned` | NO | MUL | 1 |  | 1启用 2禁用 |
| 10 | `is_del` | `tinyint unsigned` | NO |  | 2 |  | 1删除 2正常 |
| 11 | `created_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED | 创建时间 |
| 12 | `updated_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED on update CURRENT_TIMESTAMP | 更新时间 |

Indexes:
- `idx_ai_tools_status_del` (non-unique, BTREE): `status`, `is_del`, `id`
- `PRIMARY` (unique, BTREE): `id`
- `uk_ai_tools_code` (unique, BTREE): `code`

### `auth_platforms`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `int unsigned` | NO | PRI | NULL | auto_increment |  |
| 2 | `code` | `varchar(50)` | NO | UNI | NULL |  | 平台标识（如 admin, app） |
| 3 | `name` | `varchar(100)` | NO |  | NULL |  | 平台名称 |
| 4 | `login_types` | `json` | NO |  | NULL |  | 允许的登录方式 ["password","email","phone"] |
| 5 | `captcha_type` | `varchar(30)` | NO |  | slide |  | 验证码类型: slide |
| 6 | `access_ttl` | `int unsigned` | NO |  | 14400 |  | access_token 有效期（秒） |
| 7 | `refresh_ttl` | `int unsigned` | NO |  | 1209600 |  | refresh_token 有效期（秒） |
| 8 | `bind_platform` | `tinyint unsigned` | NO |  | 1 |  | 绑定平台 1=是 2=否 |
| 9 | `bind_device` | `tinyint unsigned` | NO |  | 2 |  | 绑定设备 1=是 2=否 |
| 10 | `bind_ip` | `tinyint unsigned` | NO |  | 2 |  | 绑定IP 1=是 2=否 |
| 11 | `single_session` | `tinyint unsigned` | NO |  | 2 |  | 单端登录 1=是 2=否 |
| 12 | `max_sessions` | `int unsigned` | NO |  | 5 |  | 最大会话数（0=不限） |
| 13 | `allow_register` | `tinyint unsigned` | NO |  | 2 |  | 允许注册 1=是 2=否 |
| 14 | `status` | `tinyint unsigned` | NO | MUL | 1 |  | 状态 1=启用 2=禁用 |
| 15 | `is_del` | `tinyint unsigned` | NO |  | 2 |  | 软删除 1=已删 2=正常 |
| 16 | `created_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED |  |
| 17 | `updated_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED on update CURRENT_TIMESTAMP |  |

Indexes:
- `idx_status_del` (non-unique, BTREE): `status`, `is_del`
- `PRIMARY` (unique, BTREE): `id`
- `uk_code` (unique, BTREE): `code`

### `canvas_assets`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `bigint unsigned` | NO | PRI | NULL | auto_increment |  |
| 2 | `slug` | `varchar(191)` | NO | UNI | NULL |  |  |
| 3 | `type` | `varchar(16)` | NO | MUL | NULL |  |  |
| 4 | `category` | `varchar(191)` | NO |  |  |  |  |
| 5 | `title` | `varchar(191)` | NO |  | NULL |  |  |
| 6 | `cover_url` | `varchar(1024)` | NO |  |  |  |  |
| 7 | `description` | `varchar(512)` | NO |  |  |  |  |
| 8 | `content` | `text` | YES |  | NULL |  |  |
| 9 | `url` | `varchar(1024)` | NO |  |  |  |  |
| 10 | `tags_json` | `json` | YES |  | NULL |  |  |
| 11 | `status` | `tinyint` | NO | MUL | 1 |  |  |
| 12 | `is_del` | `tinyint` | NO |  | 2 |  |  |
| 13 | `created_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED |  |
| 14 | `updated_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED on update CURRENT_TIMESTAMP |  |

Indexes:
- `idx_canvas_assets_status_updated` (non-unique, BTREE): `status`, `is_del`, `updated_at`, `id`
- `idx_canvas_assets_type_status` (non-unique, BTREE): `type`, `status`, `is_del`, `updated_at`, `id`
- `PRIMARY` (unique, BTREE): `id`
- `uk_canvas_assets_slug` (unique, BTREE): `slug`

### `canvas_prompts`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `bigint unsigned` | NO | PRI | NULL | auto_increment |  |
| 2 | `slug` | `varchar(191)` | NO | UNI | NULL |  |  |
| 3 | `category` | `varchar(191)` | NO | MUL |  |  |  |
| 4 | `title` | `varchar(191)` | NO |  | NULL |  |  |
| 5 | `cover_url` | `varchar(1024)` | NO |  |  |  |  |
| 6 | `prompt` | `text` | NO |  | NULL |  |  |
| 7 | `preview` | `varchar(512)` | NO |  |  |  |  |
| 8 | `tags_json` | `json` | YES |  | NULL |  |  |
| 9 | `source_url` | `varchar(1024)` | NO |  |  |  |  |
| 10 | `status` | `tinyint` | NO | MUL | 1 |  |  |
| 11 | `is_del` | `tinyint` | NO |  | 2 |  |  |
| 12 | `created_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED |  |
| 13 | `updated_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED on update CURRENT_TIMESTAMP |  |

Indexes:
- `idx_canvas_prompts_category_status` (non-unique, BTREE): `category`, `status`, `is_del`, `updated_at`, `id`
- `idx_canvas_prompts_status_updated` (non-unique, BTREE): `status`, `is_del`, `updated_at`, `id`
- `PRIMARY` (unique, BTREE): `id`
- `uk_canvas_prompts_slug` (unique, BTREE): `slug`

### `canvas_video_tasks`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `bigint unsigned` | NO | PRI | NULL | auto_increment |  |
| 2 | `user_id` | `bigint unsigned` | NO | MUL | NULL |  |  |
| 3 | `agent_id` | `bigint unsigned` | NO |  | NULL |  |  |
| 4 | `provider_id` | `bigint unsigned` | NO | MUL | 0 |  |  |
| 5 | `model_id` | `varchar(191)` | NO |  |  |  |  |
| 6 | `prompt` | `text` | NO |  | NULL |  |  |
| 7 | `duration_seconds` | `int` | NO |  | 0 |  |  |
| 8 | `size` | `varchar(64)` | NO |  |  |  |  |
| 9 | `resolution_name` | `varchar(64)` | NO |  |  |  |  |
| 10 | `provider_task_id` | `varchar(191)` | NO |  |  |  |  |
| 11 | `status` | `varchar(32)` | NO |  | pending |  |  |
| 12 | `error_message` | `varchar(1024)` | NO |  |  |  |  |
| 13 | `is_del` | `tinyint` | NO |  | 2 |  |  |
| 14 | `created_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED |  |
| 15 | `updated_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED on update CURRENT_TIMESTAMP |  |
| 16 | `finished_at` | `datetime` | YES |  | NULL |  |  |

Indexes:
- `idx_canvas_video_tasks_provider_task` (non-unique, BTREE): `provider_id`, `provider_task_id`
- `idx_canvas_video_tasks_user_status` (non-unique, BTREE): `user_id`, `status`, `is_del`, `created_at`, `id`
- `PRIMARY` (unique, BTREE): `id`

### `client_versions`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `int unsigned` | NO | PRI | NULL | auto_increment |  |
| 2 | `version` | `varchar(20)` | NO | MUL | NULL |  | 版本号 |
| 3 | `notes` | `text` | YES |  | NULL |  | 更新说明 |
| 4 | `file_url` | `varchar(500)` | NO |  | NULL |  | 文件地址 |
| 5 | `signature` | `text` | NO |  | NULL |  | 签名 |
| 6 | `platform` | `varchar(50)` | NO | MUL | windows-x86_64 |  | 平台 |
| 7 | `file_size` | `int unsigned` | YES |  | NULL |  | 文件大小(字节) |
| 8 | `is_latest` | `tinyint unsigned` | NO |  | 2 |  |  |
| 9 | `force_update` | `tinyint unsigned` | NO | MUL | 2 |  |  |
| 10 | `is_del` | `tinyint unsigned` | NO |  | 2 |  | soft delete: 1 deleted 2 normal |
| 11 | `created_at` | `datetime` | NO | MUL | CURRENT_TIMESTAMP | DEFAULT_GENERATED |  |
| 12 | `updated_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED on update CURRENT_TIMESTAMP |  |

Indexes:
- `idx_created_at` (non-unique, BTREE): `created_at`
- `idx_force_update` (non-unique, BTREE): `force_update`
- `idx_platform_latest` (non-unique, BTREE): `platform`, `is_latest`
- `PRIMARY` (unique, BTREE): `id`
- `uk_version_platform_del` (unique, BTREE): `version`, `platform`, `is_del`

### `cron_task`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `bigint unsigned` | NO | PRI | NULL | auto_increment |  |
| 2 | `name` | `varchar(50)` | NO | UNI | NULL |  | 任务标识（唯一） |
| 3 | `title` | `varchar(100)` | NO |  | NULL |  | 任务名称 |
| 4 | `description` | `varchar(255)` | NO |  |  |  | 任务描述 |
| 5 | `cron` | `varchar(50)` | NO |  | NULL |  | Cron表达式 |
| 6 | `cron_readable` | `varchar(100)` | NO |  |  |  | Cron可读描述 |
| 7 | `handler` | `varchar(255)` | NO |  | NULL |  | 处理类 |
| 8 | `status` | `tinyint unsigned` | NO | MUL | 1 |  |  |
| 9 | `is_del` | `tinyint unsigned` | NO |  | 2 |  |  |
| 10 | `created_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED | 创建时间 |
| 11 | `updated_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED on update CURRENT_TIMESTAMP | 更新时间 |

Indexes:
- `idx_status_del` (non-unique, BTREE): `status`, `is_del`
- `PRIMARY` (unique, BTREE): `id`
- `uniq_cron_task_name` (unique, BTREE): `name`

### `cron_task_log`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `bigint unsigned` | NO | PRI | NULL | auto_increment |  |
| 2 | `task_id` | `bigint unsigned` | NO | MUL | NULL |  | 任务ID |
| 3 | `task_name` | `varchar(50)` | NO | MUL | NULL |  | 任务标识 |
| 4 | `start_time` | `datetime(3)` | NO |  | NULL |  | 开始时间 |
| 5 | `end_time` | `datetime(3)` | YES |  | NULL |  | 结束时间 |
| 6 | `duration_ms` | `int unsigned` | YES |  | NULL |  | 执行耗时(毫秒) |
| 7 | `status` | `tinyint unsigned` | NO |  | 1 |  |  |
| 8 | `result` | `text` | YES |  | NULL |  | 执行结果 |
| 9 | `error_msg` | `text` | YES |  | NULL |  | 错误信息 |
| 10 | `is_del` | `tinyint unsigned` | NO |  | 2 |  | soft delete: 1 deleted 2 normal |
| 11 | `created_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED | 创建时间 |
| 12 | `updated_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED on update CURRENT_TIMESTAMP | 更新时间 |

Indexes:
- `idx_name_del_id` (non-unique, BTREE): `task_name`, `is_del`
- `idx_task_del_id` (non-unique, BTREE): `task_id`, `is_del`
- `PRIMARY` (unique, BTREE): `id`

### `export_tasks`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `int unsigned` | NO | PRI | NULL | auto_increment |  |
| 2 | `user_id` | `int unsigned` | NO | MUL | NULL |  | 创建用户ID |
| 3 | `platform` | `varchar(32)` | NO |  | admin |  | 平台入口 |
| 4 | `title` | `varchar(100)` | NO |  | NULL |  | 任务标题 |
| 5 | `kind` | `varchar(64)` | NO |  | user_list |  | 导出类型 |
| 6 | `file_name` | `varchar(255)` | YES |  | NULL |  | 文件名 |
| 7 | `file_url` | `varchar(500)` | YES |  | NULL |  | 文件下载URL |
| 8 | `object_key` | `varchar(500)` | YES |  | NULL |  | COS object key |
| 9 | `file_size` | `int unsigned` | YES |  | NULL |  | 文件大小（字节） |
| 10 | `row_count` | `int unsigned` | YES |  | NULL |  | 数据行数 |
| 11 | `status` | `tinyint unsigned` | NO |  | 1 |  | 1处理中 2成功 3失败 |
| 12 | `error_msg` | `varchar(500)` | YES |  | NULL |  | 失败原因 |
| 13 | `expire_at` | `datetime` | YES | MUL | NULL |  | 过期时间（定时任务清理） |
| 14 | `is_del` | `tinyint unsigned` | NO |  | 2 |  | 2正常 1删除 |
| 15 | `created_at` | `datetime` | NO | MUL | CURRENT_TIMESTAMP | DEFAULT_GENERATED |  |
| 16 | `updated_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED on update CURRENT_TIMESTAMP |  |

Indexes:
- `idx_created` (non-unique, BTREE): `created_at`
- `idx_expire` (non-unique, BTREE): `expire_at`
- `idx_export_tasks_user_platform_kind` (non-unique, BTREE): `user_id`, `platform`, `kind`, `is_del`
- `idx_export_tasks_user_platform_status` (non-unique, BTREE): `user_id`, `platform`, `status`, `is_del`
- `idx_user_status` (non-unique, BTREE): `user_id`, `status`, `is_del`
- `PRIMARY` (unique, BTREE): `id`

### `mail_configs`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `bigint unsigned` | NO | PRI | NULL | auto_increment |  |
| 2 | `config_key` | `varchar(32)` | NO | UNI | default |  |  |
| 3 | `secret_id_enc` | `text` | NO |  | NULL |  |  |
| 4 | `secret_id_hint` | `varchar(64)` | NO |  |  |  |  |
| 5 | `secret_key_enc` | `text` | NO |  | NULL |  |  |
| 6 | `secret_key_hint` | `varchar(64)` | NO |  |  |  |  |
| 7 | `region` | `varchar(64)` | NO |  | ap-guangzhou |  |  |
| 8 | `endpoint` | `varchar(128)` | NO |  | ses.tencentcloudapi.com |  |  |
| 9 | `from_email` | `varchar(255)` | NO |  | NULL |  |  |
| 10 | `from_name` | `varchar(100)` | NO |  |  |  |  |
| 11 | `reply_to` | `varchar(255)` | NO |  |  |  |  |
| 12 | `verify_code_ttl_minutes` | `int unsigned` | NO |  | 5 |  |  |
| 13 | `status` | `tinyint unsigned` | NO | MUL | 2 |  |  |
| 14 | `is_del` | `tinyint unsigned` | NO |  | 2 |  |  |
| 15 | `last_test_at` | `datetime` | YES |  | NULL |  |  |
| 16 | `last_test_error` | `varchar(500)` | NO |  |  |  |  |
| 17 | `created_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED |  |
| 18 | `updated_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED on update CURRENT_TIMESTAMP |  |

Indexes:
- `idx_mail_configs_status_del` (non-unique, BTREE): `status`, `is_del`
- `PRIMARY` (unique, BTREE): `id`
- `uk_mail_configs_config_key` (unique, BTREE): `config_key`

### `mail_logs`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `bigint unsigned` | NO | PRI | NULL | auto_increment |  |
| 2 | `scene` | `varchar(32)` | NO |  | NULL |  |  |
| 3 | `template_id` | `bigint unsigned` | YES |  | NULL |  |  |
| 4 | `to_email` | `varchar(255)` | NO |  | NULL |  |  |
| 5 | `subject` | `varchar(200)` | NO |  |  |  |  |
| 6 | `tencent_request_id` | `varchar(128)` | NO |  |  |  |  |
| 7 | `tencent_message_id` | `varchar(128)` | NO |  |  |  |  |
| 8 | `status` | `tinyint unsigned` | NO |  | NULL |  |  |
| 9 | `is_del` | `tinyint unsigned` | NO | MUL | 2 |  |  |
| 10 | `error_code` | `varchar(128)` | NO |  |  |  |  |
| 11 | `error_message` | `varchar(500)` | NO |  |  |  |  |
| 12 | `duration_ms` | `bigint unsigned` | NO |  | 0 |  |  |
| 13 | `sent_at` | `datetime` | YES |  | NULL |  |  |
| 14 | `created_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED |  |
| 15 | `updated_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED on update CURRENT_TIMESTAMP |  |

Indexes:
- `idx_mail_logs_scene_created` (non-unique, BTREE): `is_del`, `scene`, `created_at`
- `idx_mail_logs_status_created` (non-unique, BTREE): `is_del`, `status`, `created_at`
- `idx_mail_logs_to_email_created` (non-unique, BTREE): `is_del`, `to_email`, `created_at`
- `PRIMARY` (unique, BTREE): `id`

### `mail_templates`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `bigint unsigned` | NO | PRI | NULL | auto_increment |  |
| 2 | `scene` | `varchar(32)` | NO | UNI | NULL |  |  |
| 3 | `name` | `varchar(100)` | NO |  | NULL |  |  |
| 4 | `subject` | `varchar(200)` | NO |  | NULL |  |  |
| 5 | `tencent_template_id` | `bigint unsigned` | NO |  | NULL |  |  |
| 6 | `variables_json` | `json` | NO |  | NULL |  |  |
| 7 | `sample_variables_json` | `json` | NO |  | NULL |  |  |
| 8 | `status` | `tinyint unsigned` | NO | MUL | 1 |  |  |
| 9 | `is_del` | `tinyint unsigned` | NO |  | 2 |  |  |
| 10 | `created_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED |  |
| 11 | `updated_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED on update CURRENT_TIMESTAMP |  |

Indexes:
- `idx_mail_templates_status_del` (non-unique, BTREE): `status`, `is_del`
- `PRIMARY` (unique, BTREE): `id`
- `uk_mail_templates_scene` (unique, BTREE): `scene`

### `notification_task`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `int unsigned` | NO | PRI | NULL | auto_increment |  |
| 2 | `title` | `varchar(100)` | NO |  | NULL |  | 标题 |
| 3 | `content` | `mediumtext` | YES |  | NULL |  | 内容 |
| 4 | `type` | `tinyint unsigned` | NO |  | 1 |  | type: 1 info 2 success 3 warning 4 error |
| 5 | `level` | `tinyint unsigned` | NO |  | 1 |  | level: 1 normal 2 urgent |
| 6 | `link` | `varchar(500)` | YES |  |  |  | 跳转链接 |
| 7 | `platform` | `varchar(10)` | NO |  | all |  | 平台 all/admin/app |
| 8 | `target_type` | `tinyint unsigned` | NO |  | 1 |  | target type: 1 all 2 users 3 roles |
| 9 | `target_ids` | `json` | YES |  | NULL |  | 目标ID列表 |
| 10 | `status` | `tinyint unsigned` | NO | MUL | 1 |  |  |
| 11 | `total_count` | `int unsigned` | NO |  | 0 |  | 目标用户数 |
| 12 | `sent_count` | `int unsigned` | NO |  | 0 |  | 已发送数 |
| 13 | `send_at` | `datetime` | YES |  | NULL |  | 定时发送时间（空=立即发送） |
| 14 | `error_msg` | `varchar(500)` | YES |  | NULL |  | 错误信息 |
| 15 | `created_by` | `int unsigned` | NO |  | NULL |  | Creator user id |
| 16 | `is_del` | `tinyint unsigned` | NO |  | 2 |  | soft delete: 1 deleted 2 normal |
| 17 | `created_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED |  |
| 18 | `updated_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED on update CURRENT_TIMESTAMP |  |

Indexes:
- `idx_status_del_send` (non-unique, BTREE): `status`, `is_del`, `send_at`
- `PRIMARY` (unique, BTREE): `id`

### `notifications`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `int unsigned` | NO | PRI | NULL | auto_increment |  |
| 2 | `user_id` | `int unsigned` | NO | MUL | NULL |  | 接收用户ID |
| 3 | `title` | `varchar(100)` | NO |  | NULL |  | 标题 |
| 4 | `content` | `varchar(500)` | YES |  |  |  | 内容 |
| 5 | `type` | `tinyint unsigned` | NO |  | 1 |  | type: 1 normal 2 success 3 warning 4 error |
| 6 | `level` | `tinyint unsigned` | NO |  | 1 |  | level: 1 normal 2 urgent |
| 7 | `link` | `varchar(200)` | YES |  |  |  | 跳转路由 |
| 8 | `platform` | `varchar(10)` | NO |  | all |  | 平台 all/admin/app |
| 9 | `is_read` | `tinyint unsigned` | NO |  | 2 |  | 1 read 2 unread |
| 10 | `is_del` | `tinyint unsigned` | NO |  | 2 |  |  |
| 11 | `created_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED |  |
| 12 | `updated_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED on update CURRENT_TIMESTAMP |  |

Indexes:
- `idx_user_platform_del_id` (non-unique, BTREE): `user_id`, `is_del`, `id`
- `PRIMARY` (unique, BTREE): `id`

### `operation_logs`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `bigint unsigned` | NO | PRI | NULL | auto_increment | 主键 |
| 2 | `user_id` | `int unsigned` | NO | MUL | 0 |  |  |
| 3 | `action` | `varchar(255)` | NO | MUL |  |  | 操作行为/接口名称 |
| 4 | `request_data` | `text` | YES |  | NULL |  | 请求入参 |
| 5 | `response_data` | `text` | YES |  | NULL |  | 响应出参 |
| 6 | `is_del` | `tinyint unsigned` | NO | MUL | 2 |  | 2正常 1删除 |
| 7 | `is_success` | `tinyint unsigned` | NO |  | 1 |  | 1 success 2 fail |
| 8 | `created_at` | `datetime` | NO | MUL | CURRENT_TIMESTAMP | DEFAULT_GENERATED | 创建时间 |
| 9 | `updated_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED on update CURRENT_TIMESTAMP | 更新时间 |

Indexes:
- `idx_action` (non-unique, BTREE): `action`
- `idx_created_at` (non-unique, BTREE): `created_at`
- `idx_del_created_id` (non-unique, BTREE): `is_del`, `created_at`, `id`
- `idx_user_id` (non-unique, BTREE): `user_id`
- `PRIMARY` (unique, BTREE): `id`

### `payment_callback_events`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `bigint` | NO | PRI | NULL | auto_increment |  |
| 2 | `provider` | `varchar(32)` | NO | MUL | alipay |  |  |
| 3 | `notify_id` | `varchar(128)` | NO |  |  |  |  |
| 4 | `out_trade_no` | `varchar(64)` | NO |  |  |  |  |
| 5 | `trade_no` | `varchar(64)` | NO |  |  |  |  |
| 6 | `trade_status` | `varchar(32)` | NO |  |  |  |  |
| 7 | `app_id` | `varchar(64)` | NO |  |  |  |  |
| 8 | `total_amount_cents` | `bigint` | NO |  | 0 |  |  |
| 9 | `signature_valid` | `tinyint` | NO |  | 2 |  |  |
| 10 | `process_status` | `varchar(16)` | NO | MUL | pending |  |  |
| 11 | `process_message` | `varchar(512)` | NO |  |  |  |  |
| 12 | `raw_payload_json` | `json` | YES |  | NULL |  |  |
| 13 | `received_at` | `datetime` | NO |  | NULL |  |  |
| 14 | `processed_at` | `datetime` | YES |  | NULL |  |  |
| 15 | `is_del` | `tinyint` | NO |  | 2 |  |  |
| 16 | `created_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED |  |
| 17 | `updated_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED on update CURRENT_TIMESTAMP |  |

Indexes:
- `idx_payment_callback_events_notify_id` (non-unique, BTREE): `provider`, `notify_id`
- `idx_payment_callback_events_out_trade_no` (non-unique, BTREE): `provider`, `out_trade_no`
- `idx_payment_callback_events_status_time` (non-unique, BTREE): `process_status`, `received_at`
- `PRIMARY` (unique, BTREE): `id`

### `payment_configs`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `bigint` | NO | PRI | NULL | auto_increment |  |
| 2 | `provider` | `varchar(32)` | NO | MUL | alipay |  |  |
| 3 | `code` | `varchar(64)` | NO | UNI | NULL |  |  |
| 4 | `name` | `varchar(128)` | NO |  | NULL |  |  |
| 5 | `app_id` | `varchar(64)` | NO |  | NULL |  |  |
| 6 | `private_key_enc` | `text` | NO |  | NULL |  |  |
| 7 | `private_key_hint` | `varchar(64)` | NO |  |  |  |  |
| 8 | `app_cert_path` | `varchar(512)` | NO |  |  |  |  |
| 9 | `platform_cert_path` | `varchar(512)` | NO |  |  |  |  |
| 10 | `root_cert_path` | `varchar(512)` | NO |  |  |  |  |
| 11 | `notify_url` | `varchar(512)` | NO |  |  |  |  |
| 12 | `environment` | `varchar(16)` | NO | MUL | sandbox |  |  |
| 13 | `enabled_methods_json` | `json` | NO |  | NULL |  |  |
| 14 | `sort` | `int` | NO |  | 100 |  |  |
| 15 | `status` | `tinyint` | NO |  | 2 |  |  |
| 16 | `remark` | `varchar(255)` | NO |  |  |  |  |
| 17 | `is_del` | `tinyint` | NO |  | 2 |  |  |
| 18 | `created_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED |  |
| 19 | `updated_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED on update CURRENT_TIMESTAMP |  |

Indexes:
- `idx_payment_configs_environment` (non-unique, BTREE): `environment`, `is_del`
- `idx_payment_configs_provider_status` (non-unique, BTREE): `provider`, `status`, `is_del`
- `idx_payment_configs_provider_status_sort` (non-unique, BTREE): `provider`, `status`, `is_del`, `sort`, `id`
- `PRIMARY` (unique, BTREE): `id`
- `uk_payment_configs_code` (unique, BTREE): `code`

### `payment_orders`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `bigint` | NO | PRI | NULL | auto_increment |  |
| 2 | `order_no` | `varchar(64)` | NO | UNI | NULL |  |  |
| 3 | `config_id` | `bigint` | NO | MUL | NULL |  |  |
| 4 | `config_code` | `varchar(64)` | NO |  | NULL |  |  |
| 5 | `provider` | `varchar(32)` | NO | MUL | alipay |  |  |
| 6 | `pay_method` | `varchar(16)` | NO |  | NULL |  |  |
| 7 | `subject` | `varchar(128)` | NO |  | NULL |  |  |
| 8 | `amount_cents` | `bigint` | NO |  | NULL |  |  |
| 9 | `status` | `varchar(16)` | NO | MUL | NULL |  |  |
| 10 | `pay_url` | `varchar(2048)` | NO |  |  |  |  |
| 11 | `return_url` | `varchar(512)` | NO |  |  |  |  |
| 12 | `alipay_trade_no` | `varchar(64)` | NO |  |  |  |  |
| 13 | `expired_at` | `datetime` | NO |  | NULL |  |  |
| 14 | `paid_at` | `datetime` | YES |  | NULL |  |  |
| 15 | `closed_at` | `datetime` | YES |  | NULL |  |  |
| 16 | `failure_reason` | `varchar(255)` | NO |  |  |  |  |
| 17 | `is_del` | `tinyint` | NO | MUL | 2 |  |  |
| 18 | `created_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED |  |
| 19 | `updated_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED on update CURRENT_TIMESTAMP |  |

Indexes:
- `idx_payment_order_config_created` (non-unique, BTREE): `config_id`, `created_at`, `is_del`
- `idx_payment_order_status_created` (non-unique, BTREE): `is_del`, `status`, `created_at`
- `idx_payment_orders_provider_status_expired` (non-unique, BTREE): `provider`, `status`, `is_del`, `expired_at`, `id`
- `idx_payment_orders_status_updated` (non-unique, BTREE): `status`, `is_del`, `updated_at`, `id`
- `PRIMARY` (unique, BTREE): `id`
- `uk_payment_order_no` (unique, BTREE): `order_no`

### `payment_recharge_packages`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `bigint` | NO | PRI | NULL | auto_increment |  |
| 2 | `code` | `varchar(64)` | NO | UNI | NULL |  |  |
| 3 | `name` | `varchar(128)` | NO |  | NULL |  |  |
| 4 | `amount_cents` | `bigint` | NO |  | NULL |  |  |
| 5 | `badge` | `varchar(32)` | NO |  |  |  |  |
| 6 | `sort` | `int` | NO |  | 100 |  |  |
| 7 | `status` | `tinyint` | NO | MUL | 1 |  |  |
| 8 | `is_del` | `tinyint` | NO |  | 2 |  |  |
| 9 | `created_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED |  |
| 10 | `updated_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED on update CURRENT_TIMESTAMP |  |

Indexes:
- `idx_payment_recharge_package_status_sort` (non-unique, BTREE): `status`, `is_del`, `sort`, `id`
- `PRIMARY` (unique, BTREE): `id`
- `uk_payment_recharge_package_code` (unique, BTREE): `code`

### `payment_recharges`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `bigint` | NO | PRI | NULL | auto_increment |  |
| 2 | `recharge_no` | `varchar(64)` | NO | UNI | NULL |  |  |
| 3 | `user_id` | `bigint` | NO | MUL | NULL |  |  |
| 4 | `package_code` | `varchar(64)` | NO |  | NULL |  |  |
| 5 | `package_name` | `varchar(128)` | NO |  | NULL |  |  |
| 6 | `amount_cents` | `bigint` | NO |  | NULL |  |  |
| 7 | `payment_order_id` | `bigint` | NO | UNI | NULL |  |  |
| 8 | `status` | `varchar(16)` | NO |  | NULL |  |  |
| 9 | `paid_at` | `datetime` | YES |  | NULL |  |  |
| 10 | `credited_at` | `datetime` | YES |  | NULL |  |  |
| 11 | `failure_reason` | `varchar(255)` | NO |  |  |  |  |
| 12 | `is_del` | `tinyint` | NO | MUL | 2 |  |  |
| 13 | `created_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED |  |
| 14 | `updated_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED on update CURRENT_TIMESTAMP |  |

Indexes:
- `idx_payment_recharge_created` (non-unique, BTREE): `is_del`, `created_at`
- `idx_payment_recharge_user_status_created` (non-unique, BTREE): `user_id`, `is_del`, `status`, `created_at`
- `PRIMARY` (unique, BTREE): `id`
- `uk_payment_recharge_no` (unique, BTREE): `recharge_no`
- `uk_payment_recharge_order` (unique, BTREE): `payment_order_id`

### `permissions`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `int unsigned` | NO | PRI | NULL | auto_increment |  |
| 2 | `name` | `varchar(50)` | NO |  |  |  | 权限名 |
| 3 | `path` | `varchar(255)` | YES |  |  |  | 路由 |
| 4 | `icon` | `varchar(100)` | YES |  |  |  | 图标 |
| 5 | `parent_id` | `int unsigned` | NO | MUL | 0 |  | parent permission id; 0 means root |
| 6 | `component` | `varchar(255)` | YES |  | NULL |  | 组件路径 |
| 7 | `platform` | `varchar(10)` | NO | MUL | admin |  | 平台：admin=PC后台, app=H5/APP |
| 8 | `type` | `tinyint unsigned` | NO |  | 1 |  | type: 1 dir 2 page 3 button |
| 9 | `sort` | `int unsigned` | NO |  | 0 |  | 排序 |
| 10 | `code` | `varchar(100)` | YES |  | NULL |  | 权限标识 |
| 11 | `i18n_key` | `varchar(128)` | NO |  |  |  | i18n键 |
| 12 | `show_menu` | `tinyint unsigned` | NO |  | 1 |  | show menu: 1 yes 2 no |
| 13 | `status` | `tinyint unsigned` | NO |  | 1 |  |  |
| 14 | `is_del` | `tinyint unsigned` | NO | MUL | 2 |  |  |
| 15 | `created_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED |  |
| 16 | `updated_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED on update CURRENT_TIMESTAMP |  |

Indexes:
- `idx_permissions_parent_sort` (non-unique, BTREE): `parent_id`, `sort`
- `idx_permissions_platform` (non-unique, BTREE): `platform`
- `idx_permissions_status_del_platform_type` (non-unique, BTREE): `is_del`, `status`, `platform`, `type`
- `PRIMARY` (unique, BTREE): `id`
- `uk_permissions_platform_code` (unique, BTREE): `platform`, `code`

### `role_permissions`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `int unsigned` | NO | PRI | NULL | auto_increment |  |
| 2 | `role_id` | `int unsigned` | NO | MUL | NULL |  | role.id |
| 3 | `permission_id` | `int unsigned` | NO | MUL | NULL |  | permission.id |
| 4 | `is_del` | `tinyint unsigned` | NO |  | 2 |  |  |
| 5 | `created_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED |  |
| 6 | `updated_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED on update CURRENT_TIMESTAMP |  |

Indexes:
- `idx_role_permissions_permission_del_role` (non-unique, BTREE): `permission_id`, `is_del`, `role_id`
- `PRIMARY` (unique, BTREE): `id`
- `uniq_role_permission` (unique, BTREE): `role_id`, `permission_id`

### `roles`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `int unsigned` | NO | PRI | NULL | auto_increment |  |
| 2 | `name` | `varchar(50)` | NO | UNI |  |  | role name |
| 3 | `is_default` | `tinyint unsigned` | NO | MUL | 2 |  |  |
| 4 | `is_del` | `tinyint unsigned` | NO |  | 2 |  |  |
| 5 | `created_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED | 创建时间 |
| 6 | `updated_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED on update CURRENT_TIMESTAMP | 更新时间 |

Indexes:
- `idx_roles_default_del` (non-unique, BTREE): `is_default`, `is_del`
- `PRIMARY` (unique, BTREE): `id`
- `uk_roles_name` (unique, BTREE): `name`

### `sms_configs`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `bigint unsigned` | NO | PRI | NULL | auto_increment |  |
| 2 | `config_key` | `varchar(32)` | NO | UNI | default |  |  |
| 3 | `secret_id_enc` | `text` | NO |  | NULL |  |  |
| 4 | `secret_id_hint` | `varchar(64)` | NO |  |  |  |  |
| 5 | `secret_key_enc` | `text` | NO |  | NULL |  |  |
| 6 | `secret_key_hint` | `varchar(64)` | NO |  |  |  |  |
| 7 | `sms_sdk_app_id` | `varchar(32)` | NO |  |  |  |  |
| 8 | `sign_name` | `varchar(128)` | NO |  |  |  |  |
| 9 | `region` | `varchar(64)` | NO |  | ap-guangzhou |  |  |
| 10 | `endpoint` | `varchar(128)` | NO |  | sms.tencentcloudapi.com |  |  |
| 11 | `verify_code_ttl_minutes` | `int unsigned` | NO |  | 5 |  |  |
| 12 | `status` | `tinyint unsigned` | NO | MUL | 2 |  |  |
| 13 | `last_test_at` | `datetime` | YES |  | NULL |  |  |
| 14 | `last_test_error` | `varchar(500)` | NO |  |  |  |  |
| 15 | `is_del` | `tinyint unsigned` | NO |  | 2 |  |  |
| 16 | `created_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED |  |
| 17 | `updated_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED on update CURRENT_TIMESTAMP |  |

Indexes:
- `idx_sms_configs_status_del` (non-unique, BTREE): `status`, `is_del`
- `PRIMARY` (unique, BTREE): `id`
- `uk_sms_configs_config_key` (unique, BTREE): `config_key`

### `sms_logs`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `bigint unsigned` | NO | PRI | NULL | auto_increment |  |
| 2 | `scene` | `varchar(32)` | NO |  | NULL |  |  |
| 3 | `template_id` | `bigint unsigned` | YES |  | NULL |  |  |
| 4 | `to_phone` | `varchar(32)` | NO |  | NULL |  |  |
| 5 | `status` | `tinyint unsigned` | NO |  | NULL |  |  |
| 6 | `tencent_request_id` | `varchar(128)` | NO |  |  |  |  |
| 7 | `tencent_serial_no` | `varchar(128)` | NO |  |  |  |  |
| 8 | `tencent_fee` | `bigint unsigned` | NO |  | 0 |  |  |
| 9 | `error_code` | `varchar(128)` | NO |  |  |  |  |
| 10 | `error_message` | `varchar(500)` | NO |  |  |  |  |
| 11 | `duration_ms` | `bigint unsigned` | NO |  | 0 |  |  |
| 12 | `sent_at` | `datetime` | YES |  | NULL |  |  |
| 13 | `is_del` | `tinyint unsigned` | NO | MUL | 2 |  |  |
| 14 | `created_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED |  |
| 15 | `updated_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED on update CURRENT_TIMESTAMP |  |

Indexes:
- `idx_sms_logs_scene_created` (non-unique, BTREE): `is_del`, `scene`, `created_at`
- `idx_sms_logs_status_created` (non-unique, BTREE): `is_del`, `status`, `created_at`
- `idx_sms_logs_to_phone_created` (non-unique, BTREE): `is_del`, `to_phone`, `created_at`
- `PRIMARY` (unique, BTREE): `id`

### `sms_templates`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `bigint unsigned` | NO | PRI | NULL | auto_increment |  |
| 2 | `scene` | `varchar(32)` | NO | UNI | NULL |  |  |
| 3 | `name` | `varchar(100)` | NO |  | NULL |  |  |
| 4 | `tencent_template_id` | `varchar(32)` | NO |  | NULL |  |  |
| 5 | `variables_json` | `json` | NO |  | NULL |  |  |
| 6 | `sample_variables_json` | `json` | NO |  | NULL |  |  |
| 7 | `status` | `tinyint unsigned` | NO | MUL | 1 |  |  |
| 8 | `is_del` | `tinyint unsigned` | NO |  | 2 |  |  |
| 9 | `created_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED |  |
| 10 | `updated_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED on update CURRENT_TIMESTAMP |  |

Indexes:
- `idx_sms_templates_status_del` (non-unique, BTREE): `status`, `is_del`
- `PRIMARY` (unique, BTREE): `id`
- `uk_sms_templates_scene` (unique, BTREE): `scene`

### `system_settings`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `bigint unsigned` | NO | PRI | NULL | auto_increment |  |
| 2 | `setting_key` | `varchar(100)` | NO | UNI | NULL |  | 配置键：如 user.default_avatar |
| 3 | `setting_value` | `text` | NO |  | NULL |  | 配置值（字符串/JSON字符串均可） |
| 4 | `value_type` | `tinyint unsigned` | NO |  | 1 |  |  |
| 5 | `remark` | `varchar(255)` | NO |  |  |  | 备注说明 |
| 6 | `status` | `tinyint unsigned` | NO | MUL | 1 |  |  |
| 7 | `is_del` | `tinyint unsigned` | NO |  | 2 |  |  |
| 8 | `created_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED | 创建时间 |
| 9 | `updated_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED on update CURRENT_TIMESTAMP | 更新时间 |

Indexes:
- `idx_status_del` (non-unique, BTREE): `status`, `is_del`
- `PRIMARY` (unique, BTREE): `id`
- `uniq_setting_key` (unique, BTREE): `setting_key`

### `upload_driver`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `int unsigned` | NO | PRI | NULL | auto_increment |  |
| 2 | `driver` | `varchar(20)` | NO | MUL | NULL |  | cos / oss / s3 / qiniu 等 |
| 3 | `secret_id_enc` | `text` | YES |  | NULL |  |  |
| 4 | `secret_id_hint` | `varchar(20)` | YES |  | NULL |  |  |
| 5 | `secret_key_enc` | `text` | YES |  | NULL |  |  |
| 6 | `secret_key_hint` | `varchar(20)` | YES |  | NULL |  |  |
| 7 | `bucket` | `varchar(255)` | NO |  | NULL |  |  |
| 8 | `region` | `varchar(100)` | NO |  | NULL |  |  |
| 9 | `appid` | `varchar(100)` | YES |  | NULL |  | COS 特有 |
| 10 | `endpoint` | `varchar(255)` | YES |  | NULL |  | OSS/S3/AP custom domain |
| 11 | `bucket_domain` | `varchar(255)` | YES |  | NULL |  | 返回给前端用于访问的域名（可配 CDN） |
| 12 | `role_arn` | `varchar(255)` | YES |  | NULL |  | OSS AssumeRole / AWS role arn |
| 13 | `is_del` | `tinyint unsigned` | NO |  | 2 |  |  |
| 14 | `created_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED | 创建时间 |
| 15 | `updated_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED on update CURRENT_TIMESTAMP | 更新时间 |

Indexes:
- `PRIMARY` (unique, BTREE): `id`
- `uniq_driver_bucket` (unique, BTREE): `driver`, `bucket`

### `upload_rule`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `int unsigned` | NO | PRI | NULL | auto_increment |  |
| 2 | `title` | `varchar(50)` | NO |  |  |  | 规则标题 |
| 3 | `max_size_mb` | `int unsigned` | NO |  | 5 |  | 最大 MB |
| 4 | `image_exts` | `json` | NO |  | NULL |  | 允许的图片扩展名 |
| 5 | `file_exts` | `json` | NO |  | NULL |  | 允许的通用文件扩展名 |
| 6 | `is_del` | `tinyint unsigned` | NO |  | 2 |  |  |
| 7 | `created_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED | 创建时间 |
| 8 | `updated_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED on update CURRENT_TIMESTAMP | 更新时间 |

Indexes:
- `PRIMARY` (unique, BTREE): `id`

### `upload_setting`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `int unsigned` | NO | PRI | NULL | auto_increment |  |
| 2 | `driver_id` | `int unsigned` | NO | MUL | NULL |  |  |
| 3 | `rule_id` | `int unsigned` | NO | MUL | NULL |  |  |
| 4 | `status` | `tinyint unsigned` | NO | MUL | 2 |  |  |
| 5 | `is_del` | `tinyint unsigned` | NO |  | 2 |  |  |
| 6 | `remark` | `varchar(255)` | NO |  |  |  | 备注 |
| 7 | `created_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED |  |
| 8 | `updated_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED on update CURRENT_TIMESTAMP |  |

Indexes:
- `idx_rule` (non-unique, BTREE): `rule_id`
- `idx_status` (non-unique, BTREE): `status`
- `PRIMARY` (unique, BTREE): `id`
- `uniq_driver_rule` (unique, BTREE): `driver_id`, `rule_id`

### `user_profiles`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `user_id` | `int unsigned` | NO | PRI | NULL |  |  |
| 2 | `avatar` | `varchar(255)` | NO |  | https://zgm-1314542588.cos.ap-nanjing.myqcloud.com/defaultAvatar%2Favatar.jpg |  | 头像 |
| 3 | `bio` | `text` | YES |  | NULL |  | 个人简介 |
| 4 | `sex` | `tinyint unsigned` | NO |  | 0 |  | sex: 0 unknown 1 male 2 female |
| 5 | `birthday` | `date` | YES |  | NULL |  | 生日 |
| 6 | `address_id` | `int unsigned` | YES |  | NULL |  | 地址ID |
| 7 | `detail_address` | `varchar(255)` | NO |  |  |  | 详细地址 |
| 8 | `is_del` | `tinyint unsigned` | NO |  | 2 |  | soft delete: 1 deleted 2 normal |
| 9 | `created_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED | 创建时间 |
| 10 | `updated_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED on update CURRENT_TIMESTAMP | 更新时间 |

Indexes:
- `PRIMARY` (unique, BTREE): `user_id`

### `user_sessions`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `bigint unsigned` | NO | PRI | NULL | auto_increment |  |
| 2 | `user_id` | `int unsigned` | NO | MUL | NULL |  |  |
| 3 | `access_token_hash` | `char(64)` | NO | UNI | NULL |  | access token sha256 |
| 4 | `refresh_token_hash` | `char(64)` | NO | UNI | NULL |  | refresh token sha256 |
| 5 | `platform` | `varchar(20)` | NO |  |  |  | pc/h5/app/mini |
| 6 | `device_id` | `varchar(64)` | NO |  |  |  | 设备标识(前端生成uuid即可) |
| 7 | `ip` | `varchar(64)` | NO |  |  |  | 登录IP |
| 8 | `ua` | `varchar(255)` | YES |  | NULL |  | User-Agent |
| 9 | `last_seen_at` | `datetime` | YES |  | NULL |  | 最后活跃时间 |
| 10 | `expires_at` | `datetime` | NO | MUL | NULL |  | access过期时间 |
| 11 | `refresh_expires_at` | `datetime` | NO | MUL | NULL |  | refresh过期时间 |
| 12 | `revoked_at` | `datetime` | YES |  | NULL |  | 注销/踢下线时间 |
| 13 | `is_del` | `tinyint unsigned` | NO | MUL | 2 |  | 2 normal 1 deleted |
| 14 | `created_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED |  |
| 15 | `updated_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED on update CURRENT_TIMESTAMP |  |

Indexes:
- `idx_active_stats` (non-unique, BTREE): `is_del`, `revoked_at`, `expires_at`, `platform`
- `idx_expires_at` (non-unique, BTREE): `expires_at`
- `idx_refresh_expires_at` (non-unique, BTREE): `refresh_expires_at`
- `idx_user_platform` (non-unique, BTREE): `user_id`, `platform`
- `PRIMARY` (unique, BTREE): `id`
- `uniq_access_hash` (unique, BTREE): `access_token_hash`
- `uniq_refresh_hash` (unique, BTREE): `refresh_token_hash`

### `user_wallets`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `bigint` | NO | PRI | NULL | auto_increment |  |
| 2 | `user_id` | `bigint` | NO | UNI | NULL |  |  |
| 3 | `balance_cents` | `bigint` | NO |  | 0 |  |  |
| 4 | `total_recharge_cents` | `bigint` | NO |  | 0 |  |  |
| 5 | `total_consume_cents` | `bigint` | NO |  | 0 |  | 累计消费金额，单位分 |
| 6 | `is_del` | `tinyint` | NO | MUL | 2 |  |  |
| 7 | `created_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED |  |
| 8 | `updated_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED on update CURRENT_TIMESTAMP |  |

Indexes:
- `idx_user_wallet_isdel` (non-unique, BTREE): `is_del`
- `idx_user_wallet_updated` (non-unique, BTREE): `is_del`, `updated_at`, `id`
- `PRIMARY` (unique, BTREE): `id`
- `uk_user_wallet_user` (unique, BTREE): `user_id`

### `users`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `int unsigned` | NO | PRI | NULL | auto_increment |  |
| 2 | `role_id` | `int unsigned` | NO | MUL | 1 |  |  |
| 3 | `username` | `varchar(50)` | NO |  |  |  | 用户名 |
| 4 | `email` | `varchar(255)` | YES | UNI | NULL |  | 邮箱 |
| 5 | `password` | `varchar(255)` | YES |  | NULL |  | 密码(可空: 首次第三方/邮箱免密创建) |
| 6 | `phone` | `varchar(20)` | YES | UNI | NULL |  | 手机号 |
| 7 | `status` | `tinyint unsigned` | NO |  | 1 |  |  |
| 8 | `is_del` | `tinyint unsigned` | NO | MUL | 2 |  |  |
| 9 | `created_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED |  |
| 10 | `updated_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED on update CURRENT_TIMESTAMP |  |

Indexes:
- `idx_users_active` (non-unique, BTREE): `is_del`, `status`
- `idx_users_role_del` (non-unique, BTREE): `role_id`, `is_del`
- `PRIMARY` (unique, BTREE): `id`
- `uniq_users_email` (unique, BTREE): `email`
- `uniq_users_phone` (unique, BTREE): `phone`

### `users_login_log`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `bigint unsigned` | NO | PRI | NULL | auto_increment |  |
| 2 | `user_id` | `int unsigned` | YES | MUL | NULL |  |  |
| 3 | `login_account` | `varchar(120)` | NO | MUL |  |  | 登录账号 |
| 4 | `login_type` | `varchar(20)` | NO |  | email |  | 登录类型 |
| 5 | `platform` | `varchar(20)` | NO |  |  |  | 平台 |
| 6 | `ip` | `varchar(64)` | NO | MUL |  |  | IP地址 |
| 7 | `ua` | `varchar(512)` | YES |  | NULL |  | User-Agent |
| 8 | `is_success` | `tinyint unsigned` | NO |  | 2 |  | 1 success 2 fail |
| 9 | `reason` | `varchar(50)` | NO |  |  |  | 失败原因 |
| 10 | `is_del` | `tinyint unsigned` | NO |  | 2 |  | soft delete: 1 deleted 2 normal |
| 11 | `created_at` | `datetime` | NO | MUL | CURRENT_TIMESTAMP | DEFAULT_GENERATED | 创建时间 |
| 12 | `updated_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED on update CURRENT_TIMESTAMP | updated at |

Indexes:
- `idx_account_created` (non-unique, BTREE): `login_account`, `created_at`
- `idx_created` (non-unique, BTREE): `created_at`
- `idx_ip_created` (non-unique, BTREE): `ip`, `created_at`
- `idx_user_created` (non-unique, BTREE): `user_id`, `created_at`
- `PRIMARY` (unique, BTREE): `id`

### `wallet_transactions`

| # | Column | Type | Null | Key | Default | Extra | Comment |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `id` | `bigint` | NO | PRI | NULL | auto_increment |  |
| 2 | `transaction_no` | `varchar(64)` | NO | UNI | NULL |  |  |
| 3 | `wallet_id` | `bigint` | NO | MUL | NULL |  |  |
| 4 | `user_id` | `bigint` | NO | MUL | NULL |  |  |
| 5 | `direction` | `varchar(16)` | NO | MUL | NULL |  |  |
| 6 | `amount_cents` | `bigint` | NO |  | NULL |  |  |
| 7 | `balance_before_cents` | `bigint` | NO |  | NULL |  |  |
| 8 | `balance_after_cents` | `bigint` | NO |  | NULL |  |  |
| 9 | `source_type` | `varchar(32)` | NO | MUL | NULL |  |  |
| 10 | `source_id` | `bigint` | NO |  | NULL |  |  |
| 11 | `remark` | `varchar(255)` | NO |  |  |  |  |
| 12 | `is_del` | `tinyint` | NO | MUL | 2 |  |  |
| 13 | `created_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED |  |
| 14 | `updated_at` | `datetime` | NO |  | CURRENT_TIMESTAMP | DEFAULT_GENERATED on update CURRENT_TIMESTAMP |  |

Indexes:
- `idx_wallet_transaction_user_created` (non-unique, BTREE): `user_id`, `is_del`, `created_at`
- `idx_wallet_transaction_wallet_created` (non-unique, BTREE): `wallet_id`, `is_del`, `created_at`
- `idx_wallet_tx_admin_created` (non-unique, BTREE): `is_del`, `created_at`, `id`
- `idx_wallet_tx_admin_direction_created` (non-unique, BTREE): `direction`, `is_del`, `created_at`, `id`
- `idx_wallet_tx_admin_source_created` (non-unique, BTREE): `source_type`, `is_del`, `created_at`, `id`
- `PRIMARY` (unique, BTREE): `id`
- `uk_wallet_transaction_no` (unique, BTREE): `transaction_no`
- `uk_wallet_transaction_source` (unique, BTREE): `source_type`, `source_id`
