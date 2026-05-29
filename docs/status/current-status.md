# Admin Go/Vue Runtime Current Status

状态更新时间：2026-05-29

本文是当前运行时事实入口，只放最新关键事实、验证缺口和跳转。详细 per-module 分组明细已经分层到 `docs/status/module-matrix.md`；历史变更记录已经归档到 `docs/status/archive/2026-05-runtime-change-log.md`。

不要把 planned 写成 implemented。文档与运行时冲突时，以 live runtime、smoke/test output、served API 和 process config 为准。

## Current status layers

```text
docs/status/current-status.md                         # 当前入口：关键事实、验证缺口、读法
docs/status/module-matrix.md                          # 当前明细：per-module Go/Vue runtime status
docs/status/archive/2026-05-runtime-change-log.md     # 历史证据：2026-05 verified change log
```

## Current runtime truth

- 架构方向：new-system-first / multi-platform-first。后端目标是一套核心能力服务 admin / app / openapi / merchant 等多个前端或平台入口。
- 当前 backend boundary truth 是 `internal/module/{capability}/transport/{platform}` + `internal/shared` + `internal/infra`；active exceptions 是产品范围决定，不是架构漂移。
- Admin behavior preservation 仍是验收标准：现有 admin URLs、DB 表名、permission codes、i18n keys、route metadata、operation log rules、queue task types、payment callback/finalizer 行为、frontend typed API contracts 不得被重构破坏。
- Future app/openapi/merchant/miniapp work 必须在现有 capability 下增加 `transport/{platform}`，不要创建平台前缀业务模块。
- Channel-specific verify-code TTL 已落地：email TTL 归 `mail_configs.verify_code_ttl_minutes`，SMS TTL 归 `sms_configs.verify_code_ttl_minutes`；旧 `system_settings.auth.verify_code.ttl_minutes` 已在本地 live MySQL check 中软删除。
- Realtime 当前是 admin WebSocket + notification fan-out + AI conversation events；AI cancel 是 REST `POST /api/admin/v1/ai-conversations/:id/messages/cancel`，WebSocket 只发 `ai.response.start/delta/completed/failed.v1`。
- Queue / scheduler 当前已有 Redis-backed scheduler lock；worker hot reload 和 DB+queue outbox 仍是 planned。

## Current verification gaps

- 2026-05-29 channel-specific verify-code TTL 切片：basic admin smoke 已通过；full smoke 到达 mail/sms read probes 且 HTTP 200，随后停在既有 upload-token probe 的 `上传密钥不可用`，所以不能记录 full smoke 通过。
- 2026-05-27 multi-platform Phase 2 已通过 code/docs/frontend gates after Plans 11-17；但 final admin smoke 仍 pending，不能把 spec 标记为完全 closed。
- Docker-first readiness 和 smoke 是两条验证链：Docker runtime 用 `127.0.0.1:8080 /health /ready`；smoke 脚本默认临时端口是 basic `127.0.0.1:18080`、full `127.0.0.1:18081`。

## Latest verified change-log pointers

详细变更记录看 `docs/status/archive/2026-05-runtime-change-log.md`。近期关键批次：

```text
2026-05-29 multi-platform backend boundary Phase 2 closure
2026-05-29 transport admin alias cleanup
2026-05-29 wallet payment aggregation
2026-05-28 infra runtime layer rename
2026-05-28 final transport boundary guard
2026-05-28 admin transport shell waves
2026-05-28 AI/small-module/shared aggregation waves
2026-05-27 multi-platform architecture direction snapshot
```

## Current module details

详细 per-module 状态看：

```text
docs/status/module-matrix.md
```

## Current verified RBAC loop

```text
login -> AuthToken -> users/me -> users/init
permission create DIR/PAGE/BUTTON
role update grants PAGE/BUTTON
users/init returns temporary router + BUTTON-only buttonCodes
role restore
permission subtree delete
users page-init + users list
logout
```

Verification command:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\basic-admin-smoke.ps1 -Account 15671628271 -Password 123456
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account 15671628271 -Password 123456
```
