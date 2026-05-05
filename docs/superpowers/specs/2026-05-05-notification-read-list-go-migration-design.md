# Notification Read/List Go Migration Design

状态：approved for current slice
日期：2026-05-05

## Linus 三问

```text
1. 真问题：通知中心和首页通知卡片仍通过 legacyRequest 调旧 PHP `/api/admin/Notification/*`，而 realtime 已切到 Go WebSocket，业务读路径还没进入 Go，前后端 contract 不闭环。
2. 更简单方法：先只迁当前用户通知 read/list/unread/delete，不做通知任务发布、不做 Redis fan-out、不做聊天/AI/支付。后端复用 Gin + GORM + 项目 enum/dict/validate，前端复用现有 AppTable/Search/useCrudTable/Element Plus，不引入新组件库。
3. 会破坏什么：不能改变通知表业务语义；不能把 legacy 全 POST 搬进 Go；不能让用户读取/修改别人的通知；不能把 WebSocket business push 冒充已实现；不能给普通 JSON API 加 cookie fallback。
```

## Goal

迁移当前用户通知中心最小闭环：

```text
GET init dict -> GET list -> GET unread-count -> PATCH mark read -> DELETE own notifications
```

前端调用从 legacy PHP 切到 Go REST：

```text
/api/admin/v1/notifications
```

## Scope

### Included

- `GET /api/admin/v1/notifications/init` 返回通知类型、级别、已读状态字典。
- `GET /api/admin/v1/notifications` 返回当前登录用户、当前 platform 可见通知列表。
- `GET /api/admin/v1/notifications/unread-count` 返回当前用户未读数量。
- `PATCH /api/admin/v1/notifications/:id/read` 标记单条自己的未读通知为已读。
- `PATCH /api/admin/v1/notifications/read` 标记批量或全部自己的未读通知为已读。
- `DELETE /api/admin/v1/notifications/:id` 删除单条自己的通知。
- `DELETE /api/admin/v1/notifications` 删除批量自己的通知，请求体为 `{ "ids": [1,2] }`。
- 前端 `NotificationApi` 改用 Go `request`，不再使用 `legacyRequest`。
- 首页通知卡片继续读同一个 `NotificationApi`；WebSocket 刷新事件名改为 `notification.created.v1`。
- 文档、smoke matrix、current-status 同步。

### Excluded

- 不迁 `notification_task` 发布任务页面。
- 不实现通知创建服务和 WebSocket 推送业务事件。
- 不实现 Redis Pub/Sub / Streams fan-out。
- 不做 AI/chat/payment/wallet。
- 不改系统通知 UI 大视觉，只修明显类型/contract 问题。

## Legacy facts

旧 PHP 事实源：

```text
notifications 表：user_id/title/content/type/level/link/platform/is_read/is_del/created_at/updated_at
NotificationEnum：type 1普通 2成功 3警告 4错误；level 1普通 2紧急；is_read 1已读 2未读
可见范围：user_id = 当前用户，platform = 当前 platform 或 all，is_del = 2
列表筛选：type/level/is_read/keyword(title prefix)，id desc 分页
```

当前数据库 `notifications` 约 3000 行，已有索引 `idx_user_platform_del_id` 实际列为 `(user_id,is_del,id)`。本切片先不强行改表：当前 per-user 查询足够，且新增索引应在有真实慢查询或 notification_task 迁移时一起评估。若后续通知量上涨，再增加 `user_id/platform/is_del/is_read/id` 方向的索引迁移。

## Backend design

目录：

```text
internal/module/notification
  model.go       # GORM table mapping only
  dto.go         # service input/output
  request.go     # Gin binding request
  repository.go  # DB query/update ownership
  service.go     # user/platform ownership and enum validation
  handler.go     # HTTP binding + identity extraction
  route.go       # /api/admin/v1/notifications REST routes
```

边界：

```text
route -> handler -> service -> repository -> model
```

规则：

- handler 只读取 `middleware.GetAuthIdentity(c)`，不查 DB。
- service 不依赖 `gin.Context`。
- repository 不做业务决策，只保证查询条件不漏 `user_id/platform/is_del`。
- mark read/delete 都必须带 user_id ownership 条件。
- 当前用户通知不加 RBAC button permission；这类似个人资料读取，是登录用户自己的资源。
- notification delete/read 暂不记 operation log；它不是后台管理配置变更，后续如要审计再显式加 route metadata。

## Frontend design

- `src/api/system/notification.ts` 改为 typed Go client。
- 页面保留 `Search + AppTable + useCrudTable`，因为当前页面已经足够，不引入新组件。
- 去掉 `data as unknown as NotificationInitResponse` 这种无意义转换。
- API 层负责把 `useCrudTable` 的 `{ id }` 形状转换成 Go REST 路径/请求体；这不是后端 fallback 字段。
- WebSocket 刷新订阅切到 `notification.created.v1`，旧 `notification` 仅作为 legacy chat/AI 未迁部分暂存，不再给通知中心使用。

## API contract

```text
GET /api/admin/v1/notifications/init
GET /api/admin/v1/notifications?current_page=1&page_size=20&keyword=&type=&level=&is_read=
GET /api/admin/v1/notifications/unread-count
PATCH /api/admin/v1/notifications/:id/read
PATCH /api/admin/v1/notifications/read        body: { "ids": [1,2] } or {}
DELETE /api/admin/v1/notifications/:id
DELETE /api/admin/v1/notifications            body: { "ids": [1,2] }
```

统一响应仍是：

```json
{ "code": 0, "data": {}, "msg": "ok" }
```

## Testing

Backend:

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/module/notification ./internal/server ./internal/bootstrap
go test -p=1 ./...
go vet -p=1 ./...
```

Frontend:

```powershell
cd E:/admin_go/admin_front_ts
npx vue-tsc -b --pretty false
npx eslint src/api/system/notification.ts src/views/Main/notification/index.vue src/views/Main/home/composables/useHomeDashboard.ts src/components/NotificationRuntime/src/index.vue
```

Smoke:

```text
full smoke 增加只读/低风险探测：init/list/unread-count。写探针可选：如果当前测试账号存在未读通知，则标记单条已读再清理不可逆，不适合 smoke；因此默认不做写探针，避免改变真实用户通知状态。
```

## Next slice

本切片完成后再评估：

```text
notification_task publish/list + Asynq slow lane + notification.created.v1 local publish
```

这才是通知发布和 WebSocket 业务事件，不要和本切片混在一起。