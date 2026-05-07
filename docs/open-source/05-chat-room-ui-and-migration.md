# Chat Room Migration Open Source Research

状态：research，尚未进入实现。
调研日期：2026-05-07。

## Linus 三问

```text
1. 这是个真问题吗？是。当前聊天室是核心路径，但仍是 legacyRequest + 全 POST + any/Record<any> + 旧 PHP Chat/GatewayWorker 事件名。
2. 有更简单的做法吗？有。不要找一个大 SDK 全吞业务，先把 UI 壳和业务契约分开；能用成熟 Vue/Element Plus 组件补 UI，就别重写每个气泡和输入框。
3. 会破坏什么吗？会。聊天涉及联系人、会话、消息历史、附件、群管理、未读和 Go WebSocket envelope；直接套第三方 SDK 会破坏我们已有账号、RBAC、上传、历史数据和实时通道。
```

## Current Project Facts

### Frontend reality

```text
admin_front_ts/src/views/Main/chat/index.vue
admin_front_ts/src/views/Main/chat/components/*
admin_front_ts/src/store/chat.ts
admin_front_ts/src/api/chat/index.ts
```

当前前端已经有完整页面骨架：会话列表、联系人列表、消息窗口、消息输入、群侧栏、好友选择。但 API 层仍然是旧风格：

```text
BASE = /api/admin/Chat
legacyRequest.post(...)
conversationList/createPrivate/createGroup/deleteConversation/togglePin
messageList/sendMessage/markRead/recallMessage
groupInfo/groupUpdate/groupInvite/groupKick/groupLeave/groupTransfer/setAdmin
contactList/contactAdd/contactConfirm/contactDelete
typing/onlineStatus
```

明显坏味道：

```text
params?: any
meta_json: Record<string, any>
all POST action paths
store 直接消费旧事件名 chat_message/chat_typing/chat_contact_deleted
```

### Legacy backend reality

旧 PHP 事实源在：

```text
E:/admin/admin_back/routes/admin.php
E:/admin/admin_back/routes/app.php
E:/admin/admin_back/app/module/Chat/*
E:/admin/admin_back/app/dep/Chat/*
E:/admin/admin_back/app/service/Chat/ChatService.php
E:/admin/admin_back/app/enum/ChatEnum.php
```

它提供业务事实，不提供 Go 新架构规则。当前功能包括：

```text
private/group conversations
contacts pending/confirmed/delete
participants owner/admin/member and active/left/kicked
messages text/image/file/system
unread/read receipt
typing
online status
recall
group invite/kick/leave/transfer/admin
GatewayWorker push events
```

当前数据库表仍是旧表：

```text
chat_contacts
chat_conversations
chat_messages
chat_participants
```

本次只读 DB 检查到当前样本量很小：contacts=2, conversations=1, messages=1, participants=2。别把样本量小误判成业务简单。

### Go realtime reality

Go 侧已经有 admin WebSocket baseline：

```text
GET /api/admin/v1/realtime/ws
versioned envelope: { type, request_id?, data }
implemented: realtime.connected.v1 / ping / pong / subscribe / notification.created.v1
```

关键约束：新聊天实时事件必须走 `docs/contracts/admin-realtime-v1.md` 的 envelope，不要继续把旧 `chat_message` 裸事件名当新契约。

## Candidate Matrix

| Candidate | Source | License | Current package facts | Fits our stack | Good parts | Reject / risk |
| --- | --- | --- | --- | --- | --- | --- |
| Element Plus X (`vue-element-plus-x`) | https://github.com/element-plus-x/Element-Plus-X / https://v2.element-plus-x.com | MIT | npm latest checked 2026-05-07: 2.0.0, modified 2026-04-20; peer `vue ^3.5.17`, `element-plus ^2.9.7`; GitHub pushed 2026-04-29, ~1.3k stars | Strong fit: Vue 3 + Element Plus, same visual system | `Conversations`, `Bubble`, `BubbleList`, `XSender`, `Attachments`, `FilesCard`; slots/theme variables; conversation lazy load; message virtual list support through `virtua` | AI-oriented component kit, not a complete IM business SDK; package peer Element Plus is newer than our current 2.13.0 is OK, but it also brings `@vueuse/core ^13` while repo uses ^11, must test install/build before adopting |
| vue-advanced-chat | https://github.com/advanced-chat/vue-advanced-chat / https://advanced-chat.github.io/vue-advanced-chat | MIT | npm latest checked 2026-05-07: 2.1.2, modified 2025-12-19; GitHub pushed 2026-03-10, ~2k stars | Medium fit: backend agnostic, Vue compatible, but delivered as web component with its own UI contract | Full chat-room shell: rooms, messages, files, voice, emojis, replies, edits, deleted/typing/seen/system UI; event API for pagination/send/actions | Too much foreign UI/state contract. It wants `Room`/`Message` schema and web-component registration. Replacing our page with it would force a big adapter and make Element Plus style consistency worse |
| vue3-beautiful-chat | https://github.com/Sitronik/vue3-beautiful-chat | MIT | npm latest checked 2026-05-07: 3.4.2, modified 2025-01-30; ~130 stars | Weak fit | Simple backend-agnostic floating/intercom-style chat view; text/emoji/file/typing/pagination | It is a launcher/widget, not an admin core chat room. No conversation/contacts/group management shell. Too small for this module |
| TencentCloud chat-uikit-vue | https://github.com/TencentCloud/chat-uikit-vue | Apache-2.0 repo, npm package says ISC | npm latest checked 2026-05-07: 3.0.2, modified 2026-04-07; depends on Tencent Chat UIKit engine, TUILogin, SDKAppID/userSig | Poor fit unless product decides to outsource IM to Tencent Cloud | Very complete: conversation/chat/contact/group/search/message types/audio/video | SDK-bound. Requires Tencent Cloud Chat login/userSig and engine store. Would duplicate or bypass our Go REST/WebSocket/upload/RBAC. Also emoji copyright notice. Do not adopt for self-hosted admin rewrite |
| ant-design-x-vue | https://github.com/wzc520pyfm/ant-design-x-vue | MIT | npm latest checked 2026-05-07: 1.6.0, modified 2026-01-05; peer ant-design-vue >=4 | Reject for current stack | AI chat UI ideas similar to Element Plus X | Requires Ant Design Vue. Bringing a second design system into an Element Plus admin is bad taste |
```

## Recommendation

推荐方案：**Element Plus X as local UI primitives + our own Chat domain + Go REST/WebSocket contract**。

不要做：

```text
不要直接引入 TencentCloud Chat UIKit 来替换我们的业务。
不要直接用 vue3-beautiful-chat 这种客服悬浮窗糊核心聊天室。
不要把 vue-advanced-chat 一把梭成唯一页面，除非我们愿意接受它的 Room/Message/事件模型成为前端事实源。
```

要做：

```text
1. 先定义 Go chat REST contract 和 realtime event contract。
2. 前端保留 `src/views/Main/chat` 的业务页面边界，但拆掉 legacy API/any/旧事件名。
3. UI 层优先用 Element Plus X 的 Conversations/BubbleList/XSender/Attachments/FilesCard 做局部替换。
4. 业务状态仍由 Pinia/composables 管，组件只收 typed props、吐 typed emits。
```

这比直接套一个完整 SDK更简单，也更不容易破坏现有系统。

## Proposed Target Architecture

### Backend module boundary

建议 Go 模块名保持单数业务域：

```text
admin_back_go/internal/module/chat
  route.go
  handler.go
  request.go
  service.go
  repository.go
  model.go
  dto.go
  errors.go
```

调用链仍是：

```text
route -> handler -> service -> repository -> model
```

实时发布不要让 chat service 直接碰 WebSocket session。只允许依赖 `platform/realtime.Publisher`：

```text
chat service writes DB / unread facts
chat service publishes chat.*.v1 publication best-effort
platform/realtime delivers to user topics
```

### REST endpoints draft

这只是下一步 contract agent 要正式写的草案：

```text
GET    /api/admin/v1/chat/conversations
POST   /api/admin/v1/chat/conversations/private
POST   /api/admin/v1/chat/conversations/groups
DELETE /api/admin/v1/chat/conversations/:id
PATCH  /api/admin/v1/chat/conversations/:id/pin

GET    /api/admin/v1/chat/conversations/:id/messages
POST   /api/admin/v1/chat/conversations/:id/messages
PATCH  /api/admin/v1/chat/messages/:id/recall
PATCH  /api/admin/v1/chat/conversations/:id/read

GET    /api/admin/v1/chat/contacts
POST   /api/admin/v1/chat/contacts/:user_id/requests
PATCH  /api/admin/v1/chat/contacts/:user_id/confirm
DELETE /api/admin/v1/chat/contacts/:user_id

GET    /api/admin/v1/chat/conversations/:id/group
PUT    /api/admin/v1/chat/conversations/:id/group
POST   /api/admin/v1/chat/conversations/:id/group/members
DELETE /api/admin/v1/chat/conversations/:id/group/members/:user_id
PATCH  /api/admin/v1/chat/conversations/:id/group/owner
PATCH  /api/admin/v1/chat/conversations/:id/group/admins/:user_id

POST   /api/admin/v1/chat/conversations/:id/typing
GET    /api/admin/v1/chat/contacts/online-status?user_ids=1,2
```

### Realtime event draft

旧事件名不要继续扩散。新事件建议全部版本化：

```text
chat.message.created.v1
chat.message.recalled.v1
chat.conversation.updated.v1
chat.conversation.removed.v1
chat.typing.v1
chat.read.v1
chat.presence.updated.v1
chat.contact.requested.v1
chat.contact.confirmed.v1
chat.contact.rejected.v1
chat.contact.deleted.v1
chat.group.updated.v1
```

每个事件 payload 必须是对象，并带足够定位信息：

```text
conversation_id
message_id where applicable
actor_user_id
target_user_id where applicable
occurred_at
```

### Frontend component map

保留业务外壳，换掉脆弱 UI 原件：

```text
ChatPage.vue
  - 只负责布局：aside tab + main panel + mobile switch

components/ConversationPanel.vue
  - 用 Element Plus X Conversations 渲染会话列表
  - props: conversations, activeConversationId, loading
  - emits: select, toggle-pin, remove

components/MessageTimeline.vue
  - 用 Element Plus X BubbleList/Bubble 渲染消息
  - props: messages, currentUserId, hasMore, loadingMore
  - emits: load-more, recall, copy, download

components/MessageComposer.vue
  - 用 XSender + Attachments/FilesCard 或保留项目 EmojiPicker/上传 runtime
  - props: disabled, sending, pendingAttachments
  - emits: send-text, send-attachments, typing, remove-attachment

components/ContactPanel.vue
  - 先保留现有 ContactList，后续再用 Conversations 风格统一

components/GroupDrawer.vue
  - 先保留 GroupSidebar 行为，UI 逐步压缩，不和消息 timeline 混在一起

composables/useChatMessages.ts
composables/useChatConversations.ts
composables/useChatRealtime.ts
api/chat/*.ts typed REST clients
```

### Data flow

```text
Go REST -> typed api/chat client -> Pinia/composables -> Element Plus X props
Go WebSocket envelope -> useChatRealtime -> store mutation -> UI props update
UI event -> typed action -> REST -> store update -> best-effort realtime reconcile
```

单向流动。组件不直接知道 REST path，也不直接知道 WebSocket topic。


## Frontend Performance Guardrails

聊天室是常驻高频页面，性能约束直接进入设计，不等实现后再补救。

组件库采用规则：

```text
只允许从 vue-element-plus-x 按需导入具体组件。
禁止 app.use(ElementPlusX) 全量注册。
禁止在 main.ts 引入 vue-element-plus-x 全量样式。
禁止为了一个聊天室把 ant-design-vue / 腾讯 IM SDK 这类第二套体系塞进主包。
```

推荐导入形态：

```ts
import { Conversations, BubbleList, Bubble, XSender, Attachments, FilesCard } from 'vue-element-plus-x'
```

当前落地口径更严格：`MessageInput` 第一刀只用 `XSender`，并采用 `vue-element-plus-x/es/XSender/index.js` 子路径导入，避免默认入口把所有组件都拉进当前懒加载链路。该子路径缺少包内 types export，前端用一个窄 `.d.ts` 声明补齐类型，不能把它扩成 `declare module 'vue-element-plus-x/*'` 这种无边界兜底。

如果后续发现 `unplugin-vue-components` 能稳定解析 `vue-element-plus-x`，也只能配置库级 resolver 做按需组件解析；不能改成全量插件安装。

Vite 分包约束：

```text
vue-element-plus-x 必须独立 chunk，例如 chat-ui 或 element-plus-x。
聊天室 route/component 尽量 lazy load，避免登录/home 首屏吃聊天 UI 包。
build:analyze 必须看 stats.html，记录新增 chunk size/gzip size。
```

当前验证事实：`vite.config.ts` 已把 `vue-element-plus-x`、`x-sender`、`virtua` 放入 `chat-ui` code-splitting group；`npm run build:analyze` 生成 `dist/stats.html`，最新输出 `chat-ui-DINOs_FR.js` 447.06 kB / gzip 130.30 kB 与 `chat-ui-D4UfQT96.css` 35.94 kB / gzip 5.89 kB。`MessageList -> BubbleList/Bubble` 后新增局部 chunk：`MessageList-Fg2ZzZ-p.js` 5.20 kB / gzip 2.51 kB、`MessageList-ybUkjXrC.css` 4.86 kB / gzip 1.26 kB、`MessageBubbleContent-B12Wxq2X.js` 1.33 kB / gzip 0.74 kB、`MessageContextMenu-B7euiBN0.js` 1.09 kB / gzip 0.65 kB。体积上涨来自 BubbleList/Bubble/virtua 链路，仍被限制在聊天懒加载 chunk 内；禁止改成全量 `ElementPlusX` 安装。

验证命令至少包括：

```powershell
cd E:/admin_go/admin_front_ts
npm run build:check
npm run build:analyze
```

性能验收口径：

```text
首屏核心 vendor 不被聊天组件污染。
聊天 UI chunk 可解释、可缓存、不过度膨胀。
消息列表必须用分页/虚拟列表/边界加载，不能一次渲染全量历史消息。
图片和附件预览按需加载，不能把大预览逻辑塞进初始消息列表。
```

## Migration Phases

### Phase A: Contract and adapter first

产物：

```text
docs/contracts/admin-api-v1.md chat section
admin-realtime-v1.md chat event section
api/chat typed DTO draft
```

规则：不改 UI，不接新依赖。先消灭“前后端互猜”。

### Phase B: Go backend minimal private chat

最小闭环：

```text
conversation list
private create only when confirmed contact
message list
send text message
mark read
chat.message.created.v1 publication
```

不先做语音、转发、搜索、E2EE、机器人。那些是后话。

### Phase C: Frontend API switch with existing UI

先让现有 UI 走 Go REST + versioned realtime。这样能证明业务没坏。

### Phase D: UI primitive replacement

逐步引入 `vue-element-plus-x`，局部替换：

```text
MessageInput -> XSender done as first UI primitive slice
MessageInput composer boundary split done: ComposerToolbar / PendingAttachmentList / InputStatusFooter / useChatPendingAttachments / useChatVoiceInput
ConversationList -> Conversations done as second UI primitive slice
MessageList -> BubbleList/Bubble done as third UI primitive slice
MessageInput attachment cards -> Attachments/FilesCard where useful
```

这一步要跑 `vue-tsc`、targeted Vitest、真实浏览器截图。

当前 ConversationList 收口事实：

```text
ConversationList/index.vue 只保留 store 编排、Conversations props 映射、选择和菜单命令分发。
ConversationListItemContent.vue 负责会话行头像、标题、时间、预览、未读和置顶视觉。
选中会话由 ConversationList 调用 chatStore.selectConversation；父页面只处理移动端面板切换，避免双调用。
```

当前 MessageInput 收口事实：

```text
MessageInput/index.vue 只保留 XSender 编排、发送路径和上传入口。
ComposerToolbar.vue 负责图片/文件/语音/Emoji 工具栏。
PendingAttachmentList.vue 负责待发送附件预览和移除事件。
InputStatusFooter.vue 负责录音/上传/发送状态栏。
useChatPendingAttachments.ts 负责 previewUrl 创建、移除、drain 和 revoke。
useChatVoiceInput.ts 负责 Web Speech API 生命周期。
```

当前 MessageList 收口事实：

```text
MessageList/index.vue 只保留 store 编排、BubbleList list 映射、上滑分页、滚动暴露和复制/撤回动作。
MessageBubbleContent.vue 只负责 text/image/file 消息体展示，不访问 chatStore 或 ChatRoomApi。
MessageContextMenu.vue 只负责右键菜单展示、外部点击关闭和 copy/recall 事件上抛。
message-list.css 承载 BubbleList/Bubble 局部样式，避免主 SFC 继续膨胀。
分页仍调用 chatStore.loadMoreMessages()，完成后显式调用 bubbleListRef.loadMoreTopComplete()。
滚动仍由当前组件基于 currentMessages.length 和 currentConversation.id 调用 bubbleListRef.scrollToBottom()，不把业务滚动策略交给组件库。
BubbleList 使用 :virtual=\"true\"、item-key=\"id\"、item-type=\"itemType\"；system-message/chat-message 通过 #item 自定义渲染。
```

### Phase E: Group/contact polish

群管理、联系人、搜索、附件预览、撤回 UI 等继续收口。

## Decision

Accepted for design direction：

```text
Element Plus X as UI primitives only.
Our Go chat REST/WebSocket/domain model remains the source of truth.
```

Rejected：

```text
TencentCloud chat-uikit-vue as full replacement
vue3-beautiful-chat as core chat room
ant-design-x-vue because it imports another design system
```

Revisit later：

```text
vue-advanced-chat if Element Plus X BubbleList/XSender prove insufficient for message timeline/input.
```

## Verification Already Done

```text
npm view vue-element-plus-x version/license/deps/time
npm view vue-advanced-chat version/license/deps/time
npm view vue3-beautiful-chat version/license/deps/time
npm view @tencentcloud/chat-uikit-vue version/license/deps/time
browser opened vue-advanced-chat demo
browser opened Element Plus X docs and Conversations page
read current chat frontend API/store/components
read legacy PHP chat routes/modules/service/enum
read Go realtime contract and frontend websocket client
read-only DB schema/sample counts for chat_* tables
npm run test -- tests/shared/chat/chat-input-composition.test.ts tests/shared/chat/chat-input-element-plus-x.test.ts tests/shared/chat/chat-api-contract.test.ts tests/shared/build/vite-config.test.ts
npm run test -- tests/shared/chat/chat-message-list-element-plus-x.test.ts tests/shared/chat/chat-conversation-list-element-plus-x.test.ts tests/shared/chat/chat-input-composition.test.ts tests/shared/chat/chat-input-element-plus-x.test.ts tests/shared/chat/chat-api-contract.test.ts tests/shared/build/vite-config.test.ts
npx vue-tsc -b
npx eslint src/views/Main/chat/components/MessageList/index.vue src/views/Main/chat/components/MessageList/MessageBubbleContent.vue src/views/Main/chat/components/MessageList/MessageContextMenu.vue src/types/vue-element-plus-x-es.d.ts tests/shared/chat/chat-message-list-element-plus-x.test.ts
npx eslint src/views/Main/chat/components/MessageInput/index.vue src/views/Main/chat/components/MessageInput/ComposerToolbar.vue src/views/Main/chat/components/MessageInput/PendingAttachmentList.vue src/views/Main/chat/components/MessageInput/InputStatusFooter.vue src/views/Main/chat/components/MessageInput/useChatPendingAttachments.ts src/views/Main/chat/components/MessageInput/useChatVoiceInput.ts tests/shared/chat/chat-input-composition.test.ts tests/shared/chat/chat-input-element-plus-x.test.ts
npm run build:analyze
```

## Next Step

下一刀不要继续扩大 `MessageList`。优先用浏览器真实看一遍会话列表、消息 timeline、发送框三件套；如果视觉和滚动没问题，再评估 `MessageInput` attachment cards 是否值得接 Element Plus X `Attachments/FilesCard`。上传事实仍由项目 shared upload client 和 Go chat message contract 管。




