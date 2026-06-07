# DB Schema Ownership Map Snapshot

Generated at: 2026-06-07 19:25:23 +08:00

Live schema artifact: `docs/db/mysql-live-schema-2026-06-07.md` / `docs/db/mysql-live-schema-2026-06-07.sql`

This artifact starts from the live MySQL schema snapshot and maps each table to current Go source model/table references. It is a source ownership map, not a migration history and not proof that every code path is exercised at runtime.

## Summary

| Fact | Value |
| --- | --- |
| Live schema artifact | `docs/db/mysql-live-schema-2026-06-07.md` |
| Live schema SQL artifact | `docs/db/mysql-live-schema-2026-06-07.sql` |
| Live tables reviewed | `55` |
| Go source files scanned | `265` |
| go-model | `55` |

## Tables without Go model ownership

| Table | Rows | Coverage | Reference owners | Comment |
| --- | ---: | --- | --- | --- |

## Table ownership map

| Table | Rows | Coverage | Model owner candidates | Reference owners | Model sources | Comment |
| --- | ---: | --- | --- | --- | --- | --- |
| `address` | `3244` | `go-model` | `user` | `user` | `user:admin_back_go/internal/module/user/model.go` | 区域表 |
| `ai_agent_knowledge_bases` | `1` | `go-model` | `ai/knowledge` | `ai/knowledge` | `ai/knowledge:admin_back_go/internal/module/ai/knowledge/model.go` | AI智能体知识库绑定 |
| `ai_agent_tools` | `2` | `go-model` | `ai/tool` | `ai/tool` | `ai/tool:admin_back_go/internal/module/ai/tool/model.go` | AI智能体工具绑定 |
| `ai_agents` | `7` | `go-model` | `ai/agent`, `ai/chat`, `ai/tool` | `ai/agent`, `ai/chat`, `ai/conversation`, `ai/image`, `ai/message`, `ai/run`, `ai/tool`, `ai/video`, `canvas` | `ai/agent:admin_back_go/internal/module/ai/agent/model.go`<br>`ai/chat:admin_back_go/internal/module/ai/chat/model.go`<br>`ai/tool:admin_back_go/internal/module/ai/tool/model.go` | AI agent mappings |
| `ai_conversations` | `0` | `go-model` | `ai/chat`, `ai/conversation`, `ai/message` | `ai/chat`, `ai/conversation`, `ai/message`, `ai/run` | `ai/chat:admin_back_go/internal/module/ai/chat/model.go`<br>`ai/conversation:admin_back_go/internal/module/ai/conversation/model.go`<br>`ai/message:admin_back_go/internal/module/ai/message/model.go` | AI会话 |
| `ai_image_files` | `0` | `go-model` | `ai/image` | `ai/image` | `ai/image:admin_back_go/internal/module/ai/image/model.go` |  |
| `ai_image_tasks` | `0` | `go-model` | `ai/image` | `ai/image` | `ai/image:admin_back_go/internal/module/ai/image/model.go` |  |
| `ai_knowledge_bases` | `1` | `go-model` | `ai/knowledge` | `ai/knowledge` | `ai/knowledge:admin_back_go/internal/module/ai/knowledge/model.go` | AI知识库 |
| `ai_knowledge_chunks` | `6` | `go-model` | `ai/knowledge` | `ai/knowledge` | `ai/knowledge:admin_back_go/internal/module/ai/knowledge/model.go` | AI知识库分块 |
| `ai_knowledge_documents` | `6` | `go-model` | `ai/knowledge` | `ai/knowledge` | `ai/knowledge:admin_back_go/internal/module/ai/knowledge/model.go` | AI知识库文档 |
| `ai_knowledge_retrieval_hits` | `0` | `go-model` | `ai/knowledge` | `ai/knowledge`, `ai/run` | `ai/knowledge:admin_back_go/internal/module/ai/knowledge/model.go` | AI知识库检索命中 |
| `ai_knowledge_retrievals` | `0` | `go-model` | `ai/knowledge` | `ai/knowledge`, `ai/run` | `ai/knowledge:admin_back_go/internal/module/ai/knowledge/model.go` | AI知识库检索记录 |
| `ai_messages` | `0` | `go-model` | `ai/chat`, `ai/message` | `ai/chat`, `ai/conversation`, `ai/message`, `ai/run` | `ai/chat:admin_back_go/internal/module/ai/chat/model.go`<br>`ai/message:admin_back_go/internal/module/ai/message/model.go` | AI消息 |
| `ai_provider_models` | `4` | `go-model` | `ai/agent`, `ai/provider` | `ai/agent`, `ai/image`, `ai/provider`, `canvas` | `ai/agent:admin_back_go/internal/module/ai/agent/model.go`<br>`ai/provider:admin_back_go/internal/module/ai/provider/model.go` | AI provider enabled model catalog |
| `ai_providers` | `2` | `go-model` | `ai/agent`, `ai/chat`, `ai/provider` | `ai/agent`, `ai/chat`, `ai/image`, `ai/provider`, `ai/run`, `ai/tool`, `ai/video`, `canvas` | `ai/agent:admin_back_go/internal/module/ai/agent/model.go`<br>`ai/chat:admin_back_go/internal/module/ai/chat/model.go`<br>`ai/provider:admin_back_go/internal/module/ai/provider/model.go` | AI engine connection configs |
| `ai_run_events` | `0` | `go-model` | `ai/chat`, `ai/run` | `ai/chat`, `ai/run` | `ai/chat:admin_back_go/internal/module/ai/chat/model.go`<br>`ai/run:admin_back_go/internal/module/ai/run/model.go` | AI运行监控事件 |
| `ai_runs` | `0` | `go-model` | `ai/chat`, `ai/run` | `ai/chat`, `ai/run` | `ai/chat:admin_back_go/internal/module/ai/chat/model.go`<br>`ai/run:admin_back_go/internal/module/ai/run/model.go` | AI运行监控记录 |
| `ai_text_tasks` | `0` | `go-model` | `ai/text` | `ai/text` | `ai/text:admin_back_go/internal/module/ai/text/store.go` | AI文本生成任务 |
| `ai_tool_calls` | `0` | `go-model` | `ai/tool` | `ai/run`, `ai/tool` | `ai/tool:admin_back_go/internal/module/ai/tool/model.go` | AI工具调用记录 |
| `ai_tools` | `1` | `go-model` | `ai/tool` | `ai/tool` | `ai/tool:admin_back_go/internal/module/ai/tool/model.go` | AI工具定义 |
| `auth_platforms` | `3` | `go-model` | `auth_platform` | `auth_platform` | `auth_platform:admin_back_go/internal/module/auth_platform/service.go` | 认证平台管理 |
| `canvas_assets` | `0` | `go-model` | `canvas` | `canvas` | `canvas:admin_back_go/internal/module/canvas/model.go` | 无限画布素材公共库 |
| `canvas_prompts` | `1356` | `go-model` | `canvas` | `canvas` | `canvas:admin_back_go/internal/module/canvas/model.go` | 无限画布提示词公共库 |
| `canvas_video_tasks` | `0` | `go-model` | `ai/video` | `ai/video` | `ai/video:admin_back_go/internal/module/ai/video/model.go` | 无限画布视频生成任务 |
| `client_versions` | `8` | `go-model` | `clientversion` | `clientversion` | `clientversion:admin_back_go/internal/module/clientversion/model.go` | 客户端版本管理 |
| `cron_task` | `11` | `go-model` | `crontask` | `crontask` | `crontask:admin_back_go/internal/module/crontask/model.go` | 定时任务配置表 |
| `cron_task_log` | `92585` | `go-model` | `crontask` | `crontask` | `crontask:admin_back_go/internal/module/crontask/model.go` | 定时任务执行日志表 |
| `export_tasks` | `120` | `go-model` | `export` | `export` | `export:admin_back_go/internal/module/export/model.go` | 导出任务记录 |
| `mail_configs` | `1` | `go-model` | `mail` | `mail` | `mail:admin_back_go/internal/module/mail/model.go` |  |
| `mail_logs` | `6` | `go-model` | `mail` | `mail` | `mail:admin_back_go/internal/module/mail/model.go` |  |
| `mail_templates` | `4` | `go-model` | `mail` | `mail` | `mail:admin_back_go/internal/module/mail/model.go` |  |
| `notification_task` | `19` | `go-model` | `notification/task` | `notification/task` | `notification/task:admin_back_go/internal/module/notification/task/model.go` |  |
| `notifications` | `3085` | `go-model` | `notification`, `notification/task` | `notification`, `notification/task` | `notification:admin_back_go/internal/module/notification/model.go`<br>`notification/task:admin_back_go/internal/module/notification/task/model.go` | 用户通知表 |
| `operation_logs` | `2418` | `go-model` | `operationlog` | `operationlog` | `operationlog:admin_back_go/internal/module/operationlog/model.go` | 操作日志表 |
| `payment_callback_events` | `0` | `go-model` | `payment` | `payment` | `payment:admin_back_go/internal/module/payment/callback_model.go` |  |
| `payment_configs` | `1` | `go-model` | `payment` | `payment` | `payment:admin_back_go/internal/module/payment/model.go` |  |
| `payment_orders` | `19` | `go-model` | `payment` | `payment` | `payment:admin_back_go/internal/module/payment/order_model.go` |  |
| `payment_recharge_packages` | `8` | `go-model` | `payment` | `payment` | `payment:admin_back_go/internal/module/payment/package_model.go` |  |
| `payment_recharges` | `19` | `go-model` | `payment` | `payment` | `payment:admin_back_go/internal/module/payment/recharge_model.go` |  |
| `permissions` | `314` | `go-model` | `permission` | `permission`, `role`, `user` | `permission:admin_back_go/internal/module/permission/model.go`<br>`permission:admin_back_go/internal/module/permission/repository.go` | 菜单权限表 |
| `role_permissions` | `409` | `go-model` | `permission`, `role` | `permission`, `role` | `permission:admin_back_go/internal/module/permission/model.go`<br>`role:admin_back_go/internal/module/role/model.go` | role permission pivot |
| `roles` | `2` | `go-model` | `auth`, `role`, `user` | `auth`, `role`, `user` | `auth:admin_back_go/internal/module/auth/model.go`<br>`role:admin_back_go/internal/module/role/model.go`<br>`user:admin_back_go/internal/module/user/model.go` | 角色 |
| `sms_configs` | `1` | `go-model` | `sms` | `sms` | `sms:admin_back_go/internal/module/sms/model.go` |  |
| `sms_logs` | `0` | `go-model` | `sms` | `sms` | `sms:admin_back_go/internal/module/sms/model.go` |  |
| `sms_templates` | `0` | `go-model` | `sms` | `sms` | `sms:admin_back_go/internal/module/sms/model.go` |  |
| `system_settings` | `9` | `go-model` | `systemsetting` | `auth`, `systemsetting` | `systemsetting:admin_back_go/internal/module/systemsetting/model.go` | 系统设置（key-value） |
| `upload_driver` | `50` | `go-model` | `uploadconfig` | `ai/image`, `clientversion`, `export`, `shared/validate`, `uploadconfig`, `uploadtoken` | `uploadconfig:admin_back_go/internal/module/uploadconfig/model.go` |  |
| `upload_rule` | `50` | `go-model` | `uploadconfig` | `ai/image`, `clientversion`, `export`, `uploadconfig`, `uploadtoken` | `uploadconfig:admin_back_go/internal/module/uploadconfig/model.go` |  |
| `upload_setting` | `52` | `go-model` | `uploadconfig` | `ai/image`, `clientversion`, `export`, `uploadconfig`, `uploadtoken` | `uploadconfig:admin_back_go/internal/module/uploadconfig/model.go` | 上传设置：驱动+规则组合与启用状态 |
| `user_profiles` | `4` | `go-model` | `user` | `auth`, `user` | `user:admin_back_go/internal/module/user/model.go` | 用户资料表 |
| `user_sessions` | `230` | `go-model` | `auth` | `auth` | `auth:admin_back_go/internal/module/auth/session.go` | 用户会话表 |
| `user_wallets` | `2` | `go-model` | `payment`, `payment/wallet` | `payment`, `payment/wallet` | `payment:admin_back_go/internal/module/payment/wallet_model.go`<br>`payment/wallet:admin_back_go/internal/module/payment/wallet/model.go` |  |
| `users` | `4` | `go-model` | `auth`, `operationlog`, `role`, `user` | `ai/run`, `ai/tool`, `auth`, `notification/task`, `operationlog`, `payment/wallet`, `permission`, `role`, `user` | `auth:admin_back_go/internal/module/auth/model.go`<br>`operationlog:admin_back_go/internal/module/operationlog/model.go`<br>`role:admin_back_go/internal/module/role/model.go`<br>`user:admin_back_go/internal/module/user/model.go` | 用户表 |
| `users_login_log` | `309` | `go-model` | `auth` | `auth` | `auth:admin_back_go/internal/module/auth/loginlog.go`<br>`auth:admin_back_go/internal/module/auth/model.go` | 登录日志 |
| `wallet_transactions` | `3` | `go-model` | `payment`, `payment/wallet` | `payment`, `payment/wallet` | `payment:admin_back_go/internal/module/payment/wallet_model.go`<br>`payment/wallet:admin_back_go/internal/module/payment/wallet/model.go` |  |

## Verification command

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\export-db-schema-ownership-map.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1 -LiveSchema
```
