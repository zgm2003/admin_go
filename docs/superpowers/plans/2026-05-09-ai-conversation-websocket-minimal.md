# AI Conversation WebSocket Minimal MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** 重构 AI 对话为最小 conversation-first、WebSocket-only MVP，只把对话业务落在 `ai_conversations` 和 `ai_messages` 两张表上。

**Architecture:** 后端保留供应商配置和智能体配置边界；`aiconversation` 负责会话，`aimessage` 负责消息列表和发送入口，`aichat` 只保留内部纯文本回复执行器和 WebSocket event builder。前端使用共享 WebSocket 和 `conversation_id` 维度 session cache；不再使用 SSE、streamable polling、run id、tool、RAG、附件、反馈、编辑、取消。

**Tech Stack:** Go + Gin + GORM + taskqueue + realtime Publisher；Vue 3 + TypeScript + Composition API + Element Plus；MySQL 8.

---

## Execution Status

状态：implemented in this pass. Backend unit/vet, contract check, frontend Vitest/vue-tsc/build, active-source residue scan, and schema focused scan were run. Full smoke remains a separate local-runtime gate because it depends on running services and configured smoke account/provider.

## Scope Lock

当前只执行“对话”这一层，顺序固定为：

```text
供应商配置 -> 智能体配置 -> 对话 -> 运行监控 -> 工具 -> RAG
```

本切片业务表只允许：

```text
ai_conversations
ai_messages
```

本切片不重构 `ai_runs` / `ai_run_events`，不把 `run_id` 暴露给前端对话页。token / cost / latency 归运行监控切片处理，不进入 `ai_messages`。

命名固定：

```text
表名：ai_conversations, ai_messages
Go package：aiconversation, aimessage；aichat 只做内部回复执行器
REST：/api/admin/v1/ai-conversations, /api/admin/v1/ai-conversations/:id/messages
WebSocket：ai.response.start.v1, ai.response.delta.v1, ai.response.completed.v1, ai.response.failed.v1
菜单 path：/ai/chat
菜单 code：ai_chat
前端 i18n key：ai_chat
任务名：ai:conversation-reply:v1
```

禁止继续作为前端主路径：

```text
/api/admin/v1/ai-chat/runs
/api/admin/v1/ai-chat/runs/:run_id/events
/api/admin/v1/ai-chat/runs/:run_id/cancel
/api/admin/v1/ai-chat/messages
```

---

## File Structure

### Backend

```text
admin_back_go/database/migrations/20260509_ai_conversation_message_mvp.sql
  - 重构 ai_conversations / ai_messages 两张业务表字段和索引

admin_back_go/internal/module/aiconversation/*
  - 会话模型、DTO、请求、仓储、服务、handler、route、测试

admin_back_go/internal/module/aimessage/*
  - 消息模型、DTO、请求、仓储、服务、handler、route、测试

admin_back_go/internal/module/aichat/events.go
admin_back_go/internal/module/aichat/jobs.go
admin_back_go/internal/module/aichat/service.go
admin_back_go/internal/module/aichat/repository.go
  - conversation-scoped reply executor；不暴露 runs REST

admin_back_go/internal/bootstrap/app.go
admin_back_go/internal/bootstrap/worker.go
admin_back_go/internal/bootstrap/route_meta_test.go
  - 注入新服务、注册新路由、注册 ai:conversation-reply:v1、删除旧 runs 路由元数据
```

### Frontend

```text
admin_front_ts/src/api/ai/conversations.ts
admin_front_ts/src/api/ai/messages.ts
admin_front_ts/src/api/ai/chat.ts

admin_front_ts/src/views/Main/ai/chat/index.vue
admin_front_ts/src/views/Main/ai/chat/components/AgentList/index.vue
admin_front_ts/src/views/Main/ai/chat/components/ConversationList/index.vue
admin_front_ts/src/views/Main/ai/chat/components/MessageList/index.vue
admin_front_ts/src/views/Main/ai/chat/components/MessageInput/index.vue

admin_front_ts/src/views/Main/ai/chat/composables/useAgents.ts
admin_front_ts/src/views/Main/ai/chat/composables/useConversations.ts
admin_front_ts/src/views/Main/ai/chat/composables/useConversationSessions.ts
admin_front_ts/src/views/Main/ai/chat/composables/useConversationSocket.ts
admin_front_ts/src/views/Main/ai/chat/composables/types.ts
admin_front_ts/src/views/Main/ai/chat/composables/index.ts
```

Files to remove from active UI:

```text
admin_front_ts/src/views/Main/ai/chat/components/ConversationDrawer/index.vue
admin_front_ts/src/views/Main/ai/chat/components/ToolCallStatus.vue
admin_front_ts/src/views/Main/ai/chat/composables/useStreamChat.ts
admin_front_ts/src/views/Main/ai/chat/composables/useChatSessionManager.ts
```

### Docs / Tests

```text
docs/contracts/admin-api-v1.md
docs/contracts/admin-realtime-v1.md
docs/migration/current-status.md
docs/testing/smoke-matrix.md
docs/superpowers/specs/2026-05-09-ai-conversation-websocket-minimal-design.md

admin_back_go/internal/module/aiconversation/service_test.go
admin_back_go/internal/module/aimessage/service_test.go
admin_back_go/internal/module/aichat/events_test.go
admin_front_ts/tests/shared/ai/ai-conversation-api.test.ts
admin_front_ts/tests/shared/ai/ai-message-api.test.ts
admin_front_ts/tests/shared/http/ai-stream-contract.test.ts
admin_front_ts/tests/shared/http/ai-conversation-websocket-contract.test.ts
```

---

## Task 1: Schema MVP for `ai_conversations` and `ai_messages`

**Files:**
- Create: `admin_back_go/database/migrations/20260509_ai_conversation_message_mvp.sql`
- Modify: `admin.sql`

- [x] **Step 1: Write target SQL**

Create `admin_back_go/database/migrations/20260509_ai_conversation_message_mvp.sql`:

```sql
DROP TABLE IF EXISTS `ai_messages`;
DROP TABLE IF EXISTS `ai_conversations`;

CREATE TABLE `ai_conversations` (
  `id` int unsigned NOT NULL AUTO_INCREMENT COMMENT '会话ID',
  `user_id` int unsigned NOT NULL COMMENT '当前用户ID',
  `agent_id` int unsigned NOT NULL COMMENT 'ai_agents.id',
  `title` varchar(100) NOT NULL DEFAULT '' COMMENT '会话标题',
  `last_message_at` datetime NULL DEFAULT NULL COMMENT '上次对话时间',
  `is_del` tinyint unsigned NOT NULL DEFAULT 2 COMMENT '1删除 2正常',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_ai_conversations_user_agent_del_last_message` (`user_id`, `agent_id`, `is_del`, `last_message_at`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='AI会话';

CREATE TABLE `ai_messages` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT COMMENT '消息ID',
  `conversation_id` int unsigned NOT NULL COMMENT 'ai_conversations.id',
  `role` tinyint unsigned NOT NULL COMMENT '1用户 2助手',
  `content_type` varchar(32) NOT NULL DEFAULT 'text' COMMENT '内容类型，MVP只写text',
  `content` longtext NOT NULL COMMENT '消息内容',
  `is_del` tinyint unsigned NOT NULL DEFAULT 2 COMMENT '1删除 2正常',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_ai_messages_conversation_del_id` (`conversation_id`, `is_del`, `id`),
  CONSTRAINT `fk_ai_messages_conversation` FOREIGN KEY (`conversation_id`) REFERENCES `ai_conversations` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='AI消息';
```

- [x] **Step 2: Update `admin.sql`**

Only replace `ai_conversations` and `ai_messages` definitions. Do not edit provider, agent, run, tool, or RAG/knowledge table definitions in this task.

- [x] **Step 3: Verify removed columns are gone**

Run:

```powershell
cd E:/admin_go
rg -n "engine_conversation_id|token_input|token_output|engine_message_id|meta_json|ai_messages.*user_id|ai_conversations.*status" admin.sql admin_back_go/database/migrations/20260509_ai_conversation_message_mvp.sql
```

Expected: no matches.

---

## Task 2: Backend Conversation API Minimal CRUD

**Files:**
- Modify: `admin_back_go/internal/module/aiconversation/model.go`
- Modify: `admin_back_go/internal/module/aiconversation/dto.go`
- Modify: `admin_back_go/internal/module/aiconversation/request.go`
- Modify: `admin_back_go/internal/module/aiconversation/repository.go`
- Modify: `admin_back_go/internal/module/aiconversation/service.go`
- Modify: `admin_back_go/internal/module/aiconversation/handler.go`
- Modify: `admin_back_go/internal/module/aiconversation/route.go`
- Modify: `admin_back_go/internal/module/aiconversation/service_test.go`

- [x] **Step 1: Replace model fields**

`Conversation` must contain only:

```go
type Conversation struct {
	ID            int64      `gorm:"column:id;primaryKey"`
	UserID        int64      `gorm:"column:user_id"`
	AgentID       int64      `gorm:"column:agent_id"`
	Title         string     `gorm:"column:title"`
	LastMessageAt *time.Time `gorm:"column:last_message_at"`
	IsDel         int        `gorm:"column:is_del"`
	CreatedAt     time.Time  `gorm:"column:created_at"`
	UpdatedAt     time.Time  `gorm:"column:updated_at"`
}
```

- [x] **Step 2: Replace request DTOs**

Keep only:

```go
type listRequest struct {
	AgentID  *int64 `form:"agent_id" binding:"omitempty,min=1"`
	BeforeID int64  `form:"before_id" binding:"omitempty,min=1"`
	Limit    int    `form:"limit" binding:"omitempty,min=1,max=100"`
}

type createRequest struct {
	AgentID int64  `json:"agent_id" binding:"required,min=1"`
	Title   string `json:"title" binding:"omitempty,max=100"`
}
```

No `status`, `archive`, `rename`, `current_page`, or `page_size`.

- [x] **Step 3: Replace response DTOs**

Expose:

```go
type ConversationItem struct {
	ID            int64  `json:"id"`
	AgentID       int64  `json:"agent_id"`
	AgentName     string `json:"agent_name"`
	Title         string `json:"title"`
	LastMessageAt string `json:"last_message_at"`
	UpdatedAt     string `json:"updated_at"`
}

type ConversationDetail struct {
	ID            int64  `json:"id"`
	AgentID       int64  `json:"agent_id"`
	AgentName     string `json:"agent_name"`
	Title         string `json:"title"`
	LastMessageAt string `json:"last_message_at"`
	CreatedAt     string `json:"created_at"`
	UpdatedAt     string `json:"updated_at"`
}

type ListResponse struct {
	List    []ConversationItem `json:"list"`
	NextID  int64              `json:"next_id"`
	HasMore bool               `json:"has_more"`
}

type CreateResponse struct {
	ID int64 `json:"id"`
}
```

Do not expose `user_id`, `status`, or `is_del`.

- [x] **Step 4: Repository list uses cursor and `last_message_at`**

Query rules:

```sql
WHERE c.user_id = ? AND c.is_del = 2
AND optional c.agent_id = ?
AND optional c.id < before_id
ORDER BY c.last_message_at IS NULL ASC, c.last_message_at DESC, c.id DESC
LIMIT limit + 1
```

Keep agent name join:

```sql
LEFT JOIN ai_agents a ON a.id = c.agent_id AND a.is_del = 2
```

- [x] **Step 5: Delete is soft delete with message cleanup**

Delete must run one transaction:

```go
tx.Table("ai_conversations").
	Where("id = ? AND user_id = ? AND is_del = ?", id, userID, enum.CommonNo).
	Update("is_del", enum.CommonYes)

tx.Table("ai_messages").
	Where("conversation_id = ? AND is_del = ?", id, enum.CommonNo).
	Update("is_del", enum.CommonYes)
```

- [x] **Step 6: Routes expose only MVP endpoints**

`route.go` registers only:

```go
group := router.Group("/api/admin/v1/ai-conversations")
group.GET("", handler.List)
group.GET("/:id", handler.Detail)
group.POST("", handler.Create)
group.DELETE("/:id", handler.Delete)
```

Remove PUT title and PATCH status routes.

- [x] **Step 7: Run focused tests**

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/module/aiconversation
```

Expected: PASS.

---

## Task 3: Backend Message API and Send Entry

**Files:**
- Modify: `admin_back_go/internal/module/aimessage/model.go`
- Modify: `admin_back_go/internal/module/aimessage/dto.go`
- Modify: `admin_back_go/internal/module/aimessage/request.go`
- Modify: `admin_back_go/internal/module/aimessage/repository.go`
- Modify: `admin_back_go/internal/module/aimessage/service.go`
- Modify: `admin_back_go/internal/module/aimessage/handler.go`
- Modify: `admin_back_go/internal/module/aimessage/route.go`
- Modify: `admin_back_go/internal/module/aimessage/service_test.go`

- [x] **Step 1: Replace model fields**

`Message` must contain only:

```go
type Message struct {
	ID             int64     `gorm:"column:id;primaryKey"`
	ConversationID int64     `gorm:"column:conversation_id"`
	Role           int       `gorm:"column:role"`
	ContentType    string    `gorm:"column:content_type"`
	Content        string    `gorm:"column:content"`
	IsDel          int       `gorm:"column:is_del"`
	CreatedAt      time.Time `gorm:"column:created_at"`
	UpdatedAt      time.Time `gorm:"column:updated_at"`
}
```

No `user_id`, `run_id`, `meta_json`, `token_*`, `engine_message_id`, or `status`.

- [x] **Step 2: Request DTOs**

```go
type listRequest struct {
	BeforeID int64 `form:"before_id" binding:"omitempty,min=1"`
	Limit    int   `form:"limit" binding:"omitempty,min=1,max=100"`
}

type sendRequest struct {
	Content   string `json:"content" binding:"required,max=20000"`
	RequestID string `json:"request_id" binding:"required,max=80"`
}
```

- [x] **Step 3: Response DTOs**

```go
type MessageItem struct {
	ID          int64  `json:"id"`
	Role        int    `json:"role"`
	ContentType string `json:"content_type"`
	Content     string `json:"content"`
	CreatedAt   string `json:"created_at"`
	UpdatedAt   string `json:"updated_at"`
}

type ListResponse struct {
	List    []MessageItem `json:"list"`
	NextID  int64         `json:"next_id"`
	HasMore bool          `json:"has_more"`
}

type SendResponse struct {
	ConversationID int64  `json:"conversation_id"`
	UserMessageID  int64  `json:"user_message_id"`
	RequestID      string `json:"request_id"`
}
```

- [x] **Step 4: Repository writes user message and bumps conversation**

The write transaction must:

```text
1. insert ai_messages role=1 content_type=text is_del=2
2. update ai_conversations.last_message_at
3. set title only when current title is empty and first user message exists
```

- [x] **Step 5: Message list is cursor-based**

Query rules:

```sql
SELECT m.id, m.role, m.content_type, m.content, m.created_at, m.updated_at
FROM ai_messages m
JOIN ai_conversations c ON c.id = m.conversation_id AND c.user_id = ? AND c.is_del = 2
WHERE m.conversation_id = ? AND m.is_del = 2
AND optional m.id < before_id
ORDER BY m.id DESC
LIMIT limit + 1
```

Return chronological order to the UI after cursor fetch.

- [x] **Step 6: Routes expose list and send only**

```go
router.GET("/api/admin/v1/ai-conversations/:id/messages", handler.List)
router.POST("/api/admin/v1/ai-conversations/:id/messages", handler.Send)
```

Remove edit, feedback, single delete, and batch delete routes from active registration.

- [x] **Step 7: Validate chat-scene agent**

Before sending, reject if:

```text
conversation is not owned by current user
conversation.is_del != 2
agent disabled
agent scenes_json does not contain "chat"
```

Non-chat agent error:

```text
该智能体不支持对话场景
```

- [x] **Step 8: Run focused tests**

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/module/aimessage
```

Expected: PASS.

---

## Task 4: Conversation-Scoped WebSocket Reply Runtime

**Files:**
- Modify: `admin_back_go/internal/module/aichat/events.go`
- Modify: `admin_back_go/internal/module/aichat/jobs.go`
- Modify: `admin_back_go/internal/module/aichat/service.go`
- Modify: `admin_back_go/internal/module/aichat/repository.go`
- Modify: `admin_back_go/internal/module/aichat/route.go`
- Modify: `admin_back_go/internal/module/aichat/events_test.go`
- Modify: `admin_back_go/internal/bootstrap/app.go`
- Modify: `admin_back_go/internal/bootstrap/worker.go`
- Modify: `admin_back_go/internal/bootstrap/route_meta_test.go`

- [x] **Step 1: Event payloads remove `run_id`**

Use these payloads:

```go
type StartPayload struct {
	ConversationID int64  `json:"conversation_id"`
	RequestID      string `json:"request_id"`
	UserMessageID  int64  `json:"user_message_id"`
	AgentID        int64  `json:"agent_id"`
}

type DeltaPayload struct {
	ConversationID int64  `json:"conversation_id"`
	RequestID      string `json:"request_id"`
	Delta          string `json:"delta"`
}

type CompletedPayload struct {
	ConversationID     int64  `json:"conversation_id"`
	RequestID          string `json:"request_id"`
	AssistantMessageID int64  `json:"assistant_message_id"`
}

type FailedPayload struct {
	ConversationID int64  `json:"conversation_id"`
	RequestID      string `json:"request_id"`
	Msg            string `json:"msg"`
}
```

Keep only:

```go
const (
	EventAIResponseStart = "ai.response.start.v1"
	EventAIResponseDelta = "ai.response.delta.v1"
	EventAIResponseCompleted = "ai.response.completed.v1"
	EventAIResponseFailed = "ai.response.failed.v1"
)
```

- [x] **Step 2: Register conversation reply task**

`jobs.go` task name:

```go
const ConversationReplyTaskName = "ai:conversation-reply:v1"
```

Payload:

```go
type ConversationReplyPayload struct {
	ConversationID int64  `json:"conversation_id"`
	UserID         int64  `json:"user_id"`
	AgentID        int64  `json:"agent_id"`
	UserMessageID  int64  `json:"user_message_id"`
	RequestID      string `json:"request_id"`
}
```

- [x] **Step 3: Executor uses plain text history**

Executor reads:

```text
agent provider/model/system_prompt
latest ai_messages where conversation_id = ? and is_del = 2 order by id desc limit 20
```

Do not pass tool config, knowledge map, attachments, run monitor fields, or provider-side conversation id.

- [x] **Step 4: Persist one assistant final message**

On completion insert:

```go
Message{
	ConversationID: input.ConversationID,
	Role: enum.AIMessageRoleAssistant,
	ContentType: "text",
	Content: result.Answer,
	IsDel: enum.CommonNo,
}
```

Then update `ai_conversations.last_message_at`.

- [x] **Step 5: Publish WebSocket by current user**

Every event uses:

```go
publisher.Publish(ctx, platformrealtime.Publication{
	Platform: enum.PlatformAdmin,
	UserID: input.UserID,
	Envelope: envelope,
})
```

Payload must contain `conversation_id` and `request_id`; it must not contain `run_id`.

- [x] **Step 6: Remove public runs routes**

`aichat/route.go` must not mount any `/api/admin/v1/ai-chat/*` route for this page.

- [x] **Step 7: Update bootstrap route meta**

Route meta should contain:

```go
{http.MethodGet, "/api/admin/v1/ai-conversations"},
{http.MethodGet, "/api/admin/v1/ai-conversations/:id"},
{http.MethodPost, "/api/admin/v1/ai-conversations"},
{http.MethodDelete, "/api/admin/v1/ai-conversations/:id"},
{http.MethodGet, "/api/admin/v1/ai-conversations/:id/messages"},
{http.MethodPost, "/api/admin/v1/ai-conversations/:id/messages"},
```

No ai-chat runs route entries.

- [x] **Step 8: Run backend checks**

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/module/aichat ./internal/module/aimessage ./internal/module/aiconversation ./internal/bootstrap
go vet ./...
```

Expected: PASS.

---

## Task 5: Frontend API Without Runs or Streamable Polling

**Files:**
- Modify: `admin_front_ts/src/api/ai/conversations.ts`
- Modify: `admin_front_ts/src/api/ai/messages.ts`
- Modify: `admin_front_ts/src/api/ai/chat.ts`
- Modify: `admin_front_ts/tests/shared/ai/ai-conversation-api.test.ts`
- Modify: `admin_front_ts/tests/shared/ai/ai-message-api.test.ts`
- Modify: `admin_front_ts/tests/shared/http/ai-stream-contract.test.ts`

- [x] **Step 1: Conversation API only has list/detail/add/del**

`conversations.ts` exports only:

```ts
AiConversationApi.list
AiConversationApi.detail
AiConversationApi.add
AiConversationApi.del
```

No `edit`, `status`, `archive`, `current_page`, or `page_size`.

- [x] **Step 2: Message API has list and send only**

`messages.ts` exports only:

```ts
AiMessageApi.list
AiMessageApi.send
```

`AiMessageItem` fields:

```ts
id
role
content_type
content
created_at
updated_at
```

No `MessageBlock`, `Attachment`, `editContent`, `feedback`, or `del`.

- [x] **Step 3: Chat API only provides WS constants and request id**

`chat.ts` keeps:

```ts
export const AI_RESPONSE_EVENTS = {
  start: 'ai.response.start.v1',
  delta: 'ai.response.delta.v1',
  completed: 'ai.response.completed.v1',
  failed: 'ai.response.failed.v1',
} as const

export function createAiRequestId() {
  return `ai-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 10)}`
}
```

No `/ai-chat/runs`, `streamPost`, `EventSource`, streamable polling, or cancel API.

- [x] **Step 4: Update API tests**

Tests must assert no active source contains:

```text
/ai-chat/runs
EventSource
streamPost
feedback
editContent
```

Run:

```powershell
cd E:/admin_go/admin_front_ts
npm run test -- tests/shared/ai/ai-conversation-api.test.ts tests/shared/ai/ai-message-api.test.ts tests/shared/http/ai-stream-contract.test.ts
```

Expected: PASS.

---

## Task 6: Frontend Conversation UI and Session Cache

**Files:**
- Modify: `admin_front_ts/src/views/Main/ai/chat/index.vue`
- Modify: `admin_front_ts/src/views/Main/ai/chat/components/AgentList/index.vue`
- Modify: `admin_front_ts/src/views/Main/ai/chat/components/ConversationList/index.vue`
- Modify: `admin_front_ts/src/views/Main/ai/chat/components/MessageList/index.vue`
- Modify: `admin_front_ts/src/views/Main/ai/chat/components/MessageInput/index.vue`
- Create: `admin_front_ts/src/views/Main/ai/chat/composables/useConversationSessions.ts`
- Create: `admin_front_ts/src/views/Main/ai/chat/composables/useConversationSocket.ts`
- Modify: `admin_front_ts/src/views/Main/ai/chat/composables/useAgents.ts`
- Modify: `admin_front_ts/src/views/Main/ai/chat/composables/useConversations.ts`
- Modify: `admin_front_ts/src/views/Main/ai/chat/composables/types.ts`
- Modify: `admin_front_ts/src/views/Main/ai/chat/composables/index.ts`
- Delete: `admin_front_ts/src/views/Main/ai/chat/components/ConversationDrawer/index.vue`
- Delete: `admin_front_ts/src/views/Main/ai/chat/components/ToolCallStatus.vue`
- Delete: `admin_front_ts/src/views/Main/ai/chat/composables/useStreamChat.ts`
- Delete: `admin_front_ts/src/views/Main/ai/chat/composables/useChatSessionManager.ts`

- [x] **Step 1: Define minimal UI types**

```ts
export interface Conversation {
  id: number
  agent_id: number
  agent_name: string
  title: string
  last_message_at: string
  updated_at: string
}

export interface Message {
  id: number | string
  role: 1 | 2
  content_type: 'text'
  content: string
  created_at: string
  updated_at: string
  pending?: boolean
  request_id?: string
}
```

- [x] **Step 2: Cache sessions by `conversation_id`**

`useConversationSessions.ts` stores:

```ts
interface ConversationSession {
  conversationId: number
  messages: Message[]
  loading: boolean
  hasMore: boolean
  nextId: number
  pendingRequestId: string
  streamingContent: string
  streamingMessageId: string
  updatedAt: number
}
```

Rules:

```text
key = conversation_id
LRU max = 8
do not evict sessions with pendingRequestId
switching active conversation never clears another session
```

- [x] **Step 3: Dispatch WebSocket events by `conversation_id`**

`useConversationSocket.ts` subscribes to:

```text
ai.response.start.v1
ai.response.delta.v1
ai.response.completed.v1
ai.response.failed.v1
```

Dispatch by `message.data.conversation_id`. Do not dispatch by `agent_id` or `run_id`.

- [x] **Step 4: Send flow**

`index.vue` send flow:

```text
1. if no selected conversation, create one with selected agent_id
2. generate request_id
3. add local user bubble and pending assistant bubble to that conversation session
4. POST /ai-conversations/:id/messages
5. confirm user_message_id from response
6. WebSocket updates pending assistant bubble
```

- [x] **Step 5: Remove non-MVP UI**

Remove UI for:

```text
history drawer
archive / unarchive
rename dialog
attachments
feedback
edit
regenerate
stop / cancel
tool call status
markdown/code block special actions
```

Keep only:

```text
agent list
conversation list
message list
message input
```

- [x] **Step 6: Conversation list displays `last_message_at`**

Row display:

```vue
<div class="conversation-title">{{ item.title || '新会话' }}</div>
<div class="conversation-time">{{ item.last_message_at || item.updated_at }}</div>
```

- [x] **Step 7: Run frontend checks**

```powershell
cd E:/admin_go/admin_front_ts
npm run test -- tests/shared/http/ai-conversation-websocket-contract.test.ts
npx vue-tsc --noEmit
npm run build:check
```

Expected: PASS.

---

## Task 7: Menu Naming, Contracts, Smoke Matrix

**Files:**
- Modify: `docs/contracts/admin-api-v1.md`
- Modify: `docs/contracts/admin-realtime-v1.md`
- Modify: `docs/migration/current-status.md`
- Modify: `docs/testing/smoke-matrix.md`
- Modify: `admin_front_ts/src/i18n/locales/zh-CN.ts`
- Modify: `admin_front_ts/src/i18n/locales/en-US.ts`
- Modify if current seed owns AI menu ordering: `admin_back_go/database/migrations/*.sql`

- [x] **Step 1: Lock AI menu names**

Naming contract:

```text
供应商配置 code: ai_providers path: /ai/providers
智能体配置 code: ai_agents path: /ai/agents
对话 code: ai_chat path: /ai/chat
运行监控 code: ai_runs path: /ai/runs
工具 code: ai_tools path: /ai/tools
RAG code: ai_rag path: /ai/rag
```

This slice touches only `ai_chat`. If current runtime still has `ai_knowledge`, do not rename it here; RAG naming belongs to the RAG slice.

- [x] **Step 2: Update Admin API contract**

Active routes:

```text
GET    /api/admin/v1/ai-conversations
GET    /api/admin/v1/ai-conversations/:id
POST   /api/admin/v1/ai-conversations
DELETE /api/admin/v1/ai-conversations/:id
GET    /api/admin/v1/ai-conversations/:id/messages
POST   /api/admin/v1/ai-conversations/:id/messages
```

Removed from active conversation path:

```text
/api/admin/v1/ai-chat/runs
/api/admin/v1/ai-chat/runs/:run_id/events
/api/admin/v1/ai-chat/runs/:run_id/cancel
/api/admin/v1/ai-chat/messages
```

- [x] **Step 3: Update realtime contract**

AI conversation events are WebSocket-only and conversation-scoped:

```text
conversation_id + request_id
no run_id
no SSE
no EventSource
no streamable HTTP fallback
```

- [x] **Step 4: Update current status and smoke matrix**

Current status wording:

```text
AI conversation MVP implemented: ai_conversations and ai_messages are the only business tables in this slice; frontend uses WebSocket-only conversation_id session cache; run monitor is the next slice.
```

Smoke matrix should probe read routes by default and only send messages when provider probe flags are enabled.

---

## Task 8: Final Verification Gate

**Files:**
- No new files

- [x] **Step 1: Backend verification**

```powershell
cd E:/admin_go/admin_back_go
go test ./...
go vet ./...
powershell -ExecutionPolicy Bypass -File .\scripts\check-contract.ps1
```

Expected: all pass.

- [x] **Step 2: Frontend verification**

```powershell
cd E:/admin_go/admin_front_ts
npm run test -- tests/shared/ai/ai-conversation-api.test.ts tests/shared/ai/ai-message-api.test.ts tests/shared/http/ai-stream-contract.test.ts tests/shared/http/ai-conversation-websocket-contract.test.ts
npx vue-tsc --noEmit
npm run build:check
```

Expected: all pass.

- [x] **Step 3: Active source residue scan**

```powershell
cd E:/admin_go
rg -n "EventSource|text/event-stream|streamPost|streamable|/ai-chat/runs|ai.response.cancel.v1|feedback|editContent|ConversationDrawer|ToolCallStatus|useStreamChat|useChatSessionManager" admin_front_ts/src admin_front_ts/tests/shared/http admin_back_go/internal/module/aichat admin_back_go/internal/module/aimessage admin_back_go/internal/module/aiconversation
```

Expected: no active-source matches except tests or docs that explicitly assert removed behavior.

- [x] **Step 4: Schema residue scan**

```powershell
cd E:/admin_go
rg -n "engine_conversation_id|engine_message_id|token_input|token_output|meta_json|ai_messages.*run_id|ai_messages.*user_id|ai_conversations.*status" admin.sql admin_back_go/database/migrations/20260509_ai_conversation_message_mvp.sql admin_back_go/internal/module/aiconversation admin_back_go/internal/module/aimessage
```

Expected: no matches.

- [ ] **Step 5: Full smoke when local runtime is ready** — not run in this pass; local runtime smoke is intentionally credentials/process gated

```powershell
cd E:/admin_go/admin_back_go
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account 15671628271 -Password 123456
```

Expected: PASS. Default smoke must not trigger a successful provider mutation unless probe flags are set.

- [x] **Step 6: Final status check**

```powershell
git -C E:/admin_go status --short
git -C E:/admin_go/admin_back_go status --short
git -C E:/admin_go/admin_front_ts status --short
```

Expected: only intentional files remain, or all repos are clean after commits.

---

## Self-Review Checklist

- [x] Schema, routes, WebSocket, frontend cache, naming, docs, verification are covered.
- [x] No task implements tool, RAG, or run monitor UI.
- [x] No frontend route depends on `run_id`.
- [x] No `ai_messages` token/cost/latency fields are introduced.
- [x] `last_message_at` is preserved and used for list ordering/display.
- [x] Menu code for conversation remains `ai_chat`.
- [x] WebSocket payloads are scoped by `conversation_id + request_id`.
