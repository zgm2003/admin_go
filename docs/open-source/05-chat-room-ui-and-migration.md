# Chat Room Migration Open Source Research

状态：historical research only. Admin chat room was removed from current admin scope on 2026-05-07 by product decision.

## Decision on 2026-05-07

The admin system no longer ships a standalone staff chat room. This is a real deletion, not a hidden menu:

```text
admin_front_ts/src/views/Main/chat         removed
admin_front_ts/src/api/chat                removed
admin_front_ts/src/store/chat.ts           removed
admin_front_ts/tests/shared/chat           removed
admin_back_go/internal/module/chat         removed
/api/admin/v1/chat...                      removed
chat menu permission/grants                removed by migration
chat_messages/chat_participants/chat_contacts/chat_conversations dropped by migration
```

AI chat is not part of this deletion. Keep:

```text
admin_front_ts/src/views/Main/ai/chat
admin_front_ts/src/api/ai/chat.ts
ai_chat_images
```

## Historical research summary

The 2026-05-07 UI research compared Element Plus X, vue-advanced-chat, vue3-beautiful-chat, TencentCloud chat-uikit-vue, and ant-design-x-vue. The practical conclusion before deletion was already that no third-party chat-room UI gave enough value for this admin rewrite:

```text
Element Plus X: same design family but AI-oriented, visual win was not enough.
vue-advanced-chat: complete but imposes its own room/message contract.
vue3-beautiful-chat: floating support widget, not an admin core chat room.
TencentCloud chat-uikit-vue: SDK/userSig bound, would bypass our Go/RBAC/upload/runtime boundary.
ant-design-x-vue: wrong design system for this Element Plus admin.
```

This file remains only as a record of that investigation. It is not an implementation plan and must not be used to reintroduce admin chat without a new product decision.
