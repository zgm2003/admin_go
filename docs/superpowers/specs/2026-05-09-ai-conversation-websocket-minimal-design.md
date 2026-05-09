# AI Conversation WebSocket Minimal MVP Design

> 目标：把 AI 对话收敛成一个最小、可续连、WebSocket-only 的聊天切片；只保留会话、消息、发送、历史回放，不碰工具、RAG、运行监控。

## 1. 现在的问题

当前 chat 线太重了：

- 运行态被 `ai_runs` / `ai_run_events` 绑死
- 前端还在做 SSE / streamable 回退
- 会话切换是按 agent 维度缓存，不是真正的 conversation 维度
- 消息编辑、反馈、附件、取消、工具状态都在 MVP 之外

这次只做一件事：**把 AI 对话改成 conversation-first + WebSocket-first 的最小 MVP**。

## 2. 范围

### In

- 聊天能力只允许 `scene=chat` 的智能体
- 会话列表、会话创建、会话删除、会话详情
- 会话消息列表
- 发送纯文本消息
- assistant 回复通过现有 admin WebSocket 推送
- 切换会话不中断，切回后恢复当前会话的缓存状态

### Out

- SSE / streamable HTTP
- tool / RAG / 图片 / 文件附件
- 消息编辑 / 反馈 / 删除 / 批量删除
- 取消生成
- 运行监控 UI
- 运行监控表重构和监控页面
- `ai_runs` / `ai_run_events` 不作为本阶段业务表，不做前端状态源，不暴露给对话页面；token / cost / latency 后续只进 `ai_runs`，不进 `ai_messages`

## 3. 表设计

### `ai_conversations`

| column | type | rule |
| --- | --- | --- |
| `id` | `int unsigned PK auto_increment` | 会话主键 |
| `user_id` | `int unsigned not null` | 当前用户归属 |
| `agent_id` | `int unsigned not null` | 绑定 `ai_agents.id`，只能是 `scene=chat` 且启用的智能体 |
| `title` | `varchar(100) not null default ''` | 会话标题；首条用户消息后自动生成 |
| `last_message_at` | `datetime null` | 上次对话时间；用于排序和列表展示 |
| `is_del` | `tinyint unsigned not null default 2` | 2=正常，1=删除 |
| `created_at` | `datetime not null default current_timestamp` | 创建时间 |
| `updated_at` | `datetime not null default current_timestamp on update current_timestamp` | 行更新时间 |

索引：

- `idx_ai_conversations_user_agent_del_last_message (user_id, agent_id, is_del, last_message_at, id)`

行为：

- 列表按 `last_message_at desc, id desc` 排序，空值排后
- 列表展示时间直接用 `last_message_at`
- 每次用户消息入库或 assistant 消息完成入库，都同步更新该会话的 `last_message_at`
- 删除是软删除，统一把 `is_del` 置为 `1`
- 删除会话时同事务把该会话下消息也标记为删除，避免悬挂数据
- 列表/详情/消息查询都只看 `is_del = 2`

### `ai_messages`

| column | type | rule |
| --- | --- | --- |
| `id` | `bigint unsigned PK auto_increment` | 消息主键 |
| `conversation_id` | `int unsigned not null` | 外键到 `ai_conversations.id` |
| `role` | `tinyint unsigned not null` | 1=user, 2=assistant |
| `content_type` | `varchar(32) not null default 'text'` | 当前 MVP 只写 `text` |
| `content` | `longtext not null` | 纯文本内容 |
| `is_del` | `tinyint unsigned not null default 2` | 2=正常，1=删除 |
| `created_at` | `datetime not null default current_timestamp` | 写入时间 |
| `updated_at` | `datetime not null default current_timestamp on update current_timestamp` | 行更新时间 |

索引：

- `idx_ai_messages_conversation_del_id (conversation_id, is_del, id)`

行为：

- 只保存最终落库消息，不存 stream partial
- 不保留 `run_id / user_id / meta_json / token / engine_message_id / status`
- `content_type` 只做基础消息类型区分，MVP 只落 `text`
- 消息历史分页走 cursor，不走 offset page
- 消息的 token / cost / latency 统计只写 `ai_runs`

### 这次要砍掉的旧列

`ai_conversations` 里不再需要：

- `status`
- `engine_conversation_id`

`ai_messages` 里不再需要：

- `run_id`
- `user_id`
- `engine_message_id`
- `token_input`
- `token_output`
- `meta_json`
- `status`

### 命名规范

- 表名固定：`ai_conversations`、`ai_messages`
- Go package 固定：`aiconversation`、`aimessage`；对话发送逻辑允许放在 `aichat`，但不能重新引入 `/ai-chat/runs` 作为前端主路径
- REST resource 固定：`/api/admin/v1/ai-conversations`、`/api/admin/v1/ai-conversations/:id/messages`
- 前端 API 文件固定：`src/api/ai/conversations.ts`、`src/api/ai/messages.ts`、`src/api/ai/chat.ts`
- 菜单 path 固定：`/ai/chat`
- 菜单 permission code 固定：`ai_chat`
- 本阶段不新增 `ai_run_*` 菜单 code，不改运行监控菜单 code；运行监控下一步单独重构

## 4. API / WebSocket 合同

### 会话

```text
GET    /api/admin/v1/ai-conversations
GET    /api/admin/v1/ai-conversations/:id
POST   /api/admin/v1/ai-conversations
DELETE /api/admin/v1/ai-conversations/:id
```

最小字段：

- 列表项：`id`、`agent_id`、`agent_name`、`title`、`last_message_at`、`updated_at`
- 详情：`id`、`agent_id`、`agent_name`、`title`、`last_message_at`、`created_at`、`updated_at`
- 创建请求：`agent_id`，可选 `title`
- 创建响应：`id`
- 列表/详情都不返回 `user_id`、`status`、`is_del`

### 消息

```text
GET    /api/admin/v1/ai-conversations/:id/messages?before_id=&limit=
POST   /api/admin/v1/ai-conversations/:id/messages
```

最小字段：

- 列表项：`id`、`role`、`content_type`、`content`、`created_at`、`updated_at`
- 发送请求：`content`、`request_id`
- 发送响应：`conversation_id`、`user_message_id`、`request_id`
- 不返回 `meta_json`、`run_id`、`user_id`

`POST /messages` 请求体：

```json
{
  "content": "你好",
  "request_id": "client-generated-uuid"
}
```

响应只返回最小确认：

```json
{
  "conversation_id": 1,
  "user_message_id": 99,
  "request_id": "client-generated-uuid"
}
```

assistant 真正回复不走响应体，走 WebSocket。

### WebSocket

复用现有 `/api/admin/v1/realtime/ws`。

AI 对话继续使用 `ai.response.*.v1` envelope，但 payload 改成 **conversation-scoped**，不再依赖 `run_id`：

- `ai.response.start.v1`
- `ai.response.delta.v1`
- `ai.response.completed.v1`
- `ai.response.failed.v1`

最小字段：

- `start`：`conversation_id`、`request_id`、`user_message_id`、`agent_id`
- `delta`：`conversation_id`、`request_id`、`delta`
- `completed`：`conversation_id`、`request_id`、`assistant_message_id`
- `failed`：`conversation_id`、`request_id`、`msg`
- 所有事件都不带 `run_id`

delta 示例：

```json
{
  "conversation_id": 1,
  "request_id": "client-generated-uuid",
  "delta": "..."
}
```

### 被移出 active chat slice 的旧接口

- `/api/admin/v1/ai-chat/runs`
- `/api/admin/v1/ai-chat/runs/:run_id/events`
- `/api/admin/v1/ai-chat/runs/:run_id/cancel`
- `/api/admin/v1/ai-chat/messages`
- `ai-messages` 的 edit/feedback/delete/batch-delete

这些留给后续运行监控或直接废弃，不再是本次对话 MVP 的主路径。

## 5. 运行流

1. 页面只加载 `scene=chat` 的启用智能体
2. 用户选智能体后加载该智能体的会话列表
3. 用户打开某个会话，消息列表按 cursor 拉最近一页
4. 用户发送文本时，前端生成 `request_id`
5. 如果当前没有会话，前端先创建新会话，再把这条消息发进去
6. 后端创建 user message，更新会话 `title/updated_at/last_message_at`
7. 后端把 chat 任务交给 worker 或受控后台执行器
8. worker 读取该会话最近 N 条消息 + agent system_prompt
9. worker 调用 `internal/platform/ai` 的纯文本聊天边界，不传 tool / rag / 附件输入
10. worker 通过 admin WebSocket 发送 start / delta / completed / failed
11. 完成时只落一条 assistant message，并更新会话 `last_message_at`

## 6. 前端组件边界

### 视图层

- `src/views/Main/ai/chat/index.vue`
  - 只做页面编排
  - 维护 selected agent / selected conversation
  - 不做流式拼接逻辑

### 组件

- `AgentList`
  - 只显示 chat-scene agents
- `ConversationList`
  - 只显示当前 agent 的会话，并展示 `last_message_at`
- `MessageList`
  - 只渲染 `content_type` 为 `text` 的 bubble 和 pending assistant bubble
- `MessageInput`
  - 只保留文本输入和发送

### composables

- `useAgents()`
  - 只负责 chat-scene agent 列表和选中态
- `useConversations()`
  - 只负责会话列表 / 创建 / 删除 / 选择
- `useConversationSessions()`
  - 以 `conversation_id` 为 key 缓存 messages、pending request、streaming text
  - 用 LRU 防止缓存无限长
- `useConversationSocket()`
  - 只订阅 shared WebSocket，不新开连接
  - 把 `ai.response.*.v1` 分发到对应 conversation session

### 明确删除

- `ConversationDrawer`
- `ConversationList` 里所有 archive / rename / search history 重 UI
- `useStreamChat`
- `useChatSessionManager` 的 agent-keyed 模式
- 附件上传、代码块复制、Markdown、反馈、编辑、取消按钮

## 7. 性能 / 续连规则

- 会话缓存按 `conversation_id`，不是按 agent
- 活跃会话和后台会话都可以继续收 WebSocket delta
- 切会话只切 UI，不取消后台任务
- 消息历史走 cursor，不走 offset 大分页
- 前端仅对 active conversation 做滚动和局部渲染
- 同一 conversation 的 in-flight 状态要能恢复；切回时先看缓存，不强制重拉
- `request_id` 用于去重和事件归属，避免多次连接/重放造成重复渲染
- 所有会话/消息查询都默认过滤 `is_del = 2`

## 8. AI 适配边界

这次 chat slice 只拿：

- agent 的 `provider_id`
- agent 的 `model_id`
- agent 的 `system_prompt`
- 最近消息历史

不拿：

- tool 配置
- knowledge / RAG 输入
- run monitor 字段；`ai_runs` 下一步运行监控再重构
- provider-side conversation id 作为前端状态真相源

## 9. 验收标准

- `ai_conversations` 只有 `id/user_id/agent_id/title/last_message_at/is_del/created_at/updated_at`
- `ai_messages` 只有 `id/conversation_id/role/content_type/content/is_del/created_at/updated_at`
- 前端没有 SSE / streamable / runs poll
- 会话切换期间，后台流式回复不中断
- 切回同一会话时能继续看到同一条 pending 回复
- 发送接口没有多余字段，纯文本即可
- 没有 tool / RAG / attach / feedback / edit / cancel UI
- 现有 WebSocket 基线仍能连接、ping/pong
- 本阶段业务重构只落在 `ai_conversations` / `ai_messages` 这两张表；运行监控下一步再做
